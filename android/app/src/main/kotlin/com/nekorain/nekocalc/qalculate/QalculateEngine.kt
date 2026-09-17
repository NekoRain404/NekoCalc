package com.nekorain.nekocalc.qalculate

import android.util.Log
import com.jherkenhoff.libqalculate.ApproximationMode
import com.jherkenhoff.libqalculate.AutomaticApproximation
import com.jherkenhoff.libqalculate.AutomaticFractionFormat
import com.jherkenhoff.libqalculate.Calculator
import com.jherkenhoff.libqalculate.EvaluationOptions
import com.jherkenhoff.libqalculate.NumberFractionFormat
import com.jherkenhoff.libqalculate.PrintOptions
import com.jherkenhoff.libqalculate.libqalculateConstants
import java.util.concurrent.Callable
import java.util.concurrent.Executors

/**
 * 中文：libqalculate 引擎的宿主，目前只提供一次最小求值，用来在真机上证明引擎真的加载起来了。
 *
 * 线程约束：C++ 引擎没有公开的线程安全承诺（定义表、缓存、消息队列、超时计时器都是可变全局状态）。
 * 因此整个进程只保留一个 [Calculator]，并且只允许 `qalculate-engine` 这一条线程进入它。
 * 参考实现在 Android 主线程上同步求值，同时又有另一个 dispatcher 改同一个引擎——那是真实竞态，
 * 这里刻意不复制。MethodChannel 的回调本来就在主线程上，直接调用引擎会把这段阻塞叠加到掉帧预算上。
 *
 * English: Host for the libqalculate engine. Right now it offers a single minimal evaluation, whose
 * purpose is to prove on a real device that the engine actually loads.
 *
 * Threading: the C++ engine makes no public thread-safety promise (definition tables, caches, the
 * message queue and the timeout timers are all mutable global state). The process therefore keeps
 * exactly one [Calculator], and only the `qalculate-engine` thread may enter it. The reference
 * implementation evaluates synchronously on the Android main thread while another dispatcher
 * mutates the same engine — a real race, deliberately not copied. MethodChannel handlers already
 * run on the main thread, so calling the engine from one would add that blocking to the frame
 * budget.
 */
class QalculateEngine {

    private val engineThread = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "qalculate-engine").apply { isDaemon = true }
    }

    // 中文：全局定义（单位、常数、函数）整个进程只加载一次，`by lazy` 把这份代价推迟到第一次求值。
    //       loadGlobalDefinitions() 的返回值必须记下来：它为 false 时算术照常工作，
    //       但 400 多个单位和所有常数会静默消失。
    // English: Global definitions (units, constants, functions) load once per process; `by lazy`
    //          defers that cost to the first evaluation. The return value of
    //          loadGlobalDefinitions() must be recorded: when it is false, arithmetic still works
    //          but 400-odd units and every constant vanish silently.
    private val calc: Calculator by lazy {
        loadNativeLibrary()
        val instance = Calculator()
        val loaded = instance.loadGlobalDefinitions()
        Log.i(TAG, "loadGlobalDefinitions() = $loaded")
        if (!loaded) {
            Log.w(TAG, "global definitions missing: units and constants will be unavailable")
        }
        instance
    }

    /**
     * 中文：必须由宿主显式加载 libqalculate_swig.so。
     *
     * 这个 AAR 的 classes.jar 里一处 System.loadLibrary 都没有——SWIG 的 %pragma(java)
     * jniclasscode 没有被写进 libqalculate.i，所以生成的 JNI 胶水不会自己加载动态库。
     * 少了这一行，第一次 `Calculator()` 就抛 UnsatisfiedLinkError：
     * 「No implementation found for long ...libqalculateJNI.new_Calculator__SWIG_0()」。
     *
     * 库名来自 libqalculate_swig.so 的 SONAME，不是文件名猜的。它 DT_NEEDED 的
     * libqalculate / libgmp / libmpfr / libiconv / libxml2 / libc++_shared 都在同一个 AAR 里，
     * 链接器会在同一个目录里把它们找齐。
     *
     * English: The host must load libqalculate_swig.so explicitly.
     *
     * There is not a single System.loadLibrary call anywhere in this AAR's classes.jar — SWIG's
     * %pragma(java) jniclasscode never made it into libqalculate.i, so the generated JNI glue does
     * not load the shared library itself. Without this line the first `Calculator()` throws
     * UnsatisfiedLinkError: "No implementation found for long
     * ...libqalculateJNI.new_Calculator__SWIG_0()".
     *
     * The name comes from the SONAME of libqalculate_swig.so rather than from guessing at the file
     * name. Everything it DT_NEEDs — libqalculate / libgmp / libmpfr / libiconv / libxml2 /
     * libc++_shared — ships in the same AAR, so the linker finds them side by side.
     */
    private fun loadNativeLibrary() {
        System.loadLibrary("qalculate_swig")
    }

    /**
     * 中文：求值一次，返回可以直接跨 channel 传回 Dart 的字符串表。
     *       调用线程会阻塞到引擎线程给出答案为止。
     * English: Evaluate once and return a string map that can cross the channel as-is.
     *          The calling thread blocks until the engine thread answers.
     */
    fun evaluate(expression: String): Map<String, String> =
        engineThread.submit(Callable { evaluateOnEngine(expression) }).get()

    /**
     * 中文：把求值排到引擎线程上并在那里回调。channel 用这个入口，Android 主线程因此不必
     *       等引擎——MethodChannel.Result 允许从非主线程完成。
     * English: Queue the evaluation onto the engine thread and call back from there. The channel
     *          uses this entry point so the Android main thread never waits on the engine —
     *          MethodChannel.Result may be completed from a non-main thread.
     */
    fun evaluateAsync(expression: String, onResult: (Map<String, String>) -> Unit) {
        engineThread.execute { onResult(evaluateOnEngine(expression)) }
    }

    private fun evaluateOnEngine(expression: String): Map<String, String> {
        return try {
            val engine = calc
            engine.clearMessages()

            // 中文：TRY_EXACT 用于一步式打印；要不要近似由打印阶段的 AutomaticApproximation 决定。
            // English: TRY_EXACT feeds the one-shot printer; whether to approximate is then decided
            //          at print time by AutomaticApproximation.
            val evaluation = evaluationOptions(ApproximationMode.APPROXIMATION_TRY_EXACT)
            val terminal = printOptions(latex = false)

            // 中文：unlocalizeExpression 把本地化的函数名与符号换成引擎内部写法。
            // English: unlocalizeExpression rewrites localised function names and symbols into the
            //          engine's internal spelling.
            val normalized = engine.unlocalizeExpression(expression, evaluation.parse_options)

            // 中文：十进制那一份明确要求近似（SINGLE = 只显示近似值）。
            //       注意：无理结果不会被印成一个单纯的十进制——libqalculate 把近似值表示成
            //       不确定区间，sqrt(32) 得到的是 interval(5.6568542, 5.6568543)。
            //       这是引擎真实的行为，不是没配对参数：把 EvaluationOptions 换成
            //       APPROXIMATION_APPROXIMATE、或给 PrintOptions 加 max_decimals 上限，
            //       都只是把区间收窄（interval(5.656854, 5.656855)），不会塌缩成一个数。
            //       怎么消费这个区间留给下一步决定。
            // English: the decimal rendering explicitly asks for the approximation (SINGLE = show
            //          only the approximate value). Note that an irrational result does not come
            //          back as a bare decimal — libqalculate represents the approximation as an
            //          uncertainty interval, so sqrt(32) yields interval(5.6568542, 5.6568543).
            //          That is the engine's real behaviour rather than a mis-set option: switching
            //          EvaluationOptions to APPROXIMATION_APPROXIMATE, or capping PrintOptions with
            //          max_decimals, only narrows the interval (interval(5.656854, 5.656855)) —
            //          neither collapses it into a single number. How to consume the interval is
            //          left to the next step.
            val decimal = render(
                engine,
                normalized,
                evaluationOptions(ApproximationMode.APPROXIMATION_APPROXIMATE),
                terminal,
                AutomaticApproximation.AUTOMATIC_APPROXIMATION_SINGLE,
            )
            val dual = render(engine, normalized, evaluation, terminal, AutomaticApproximation.AUTOMATIC_APPROXIMATION_DUAL)

            // 中文：aborted() 会一直锁存到下一次 startControl，所以必须紧跟求值就读，否则它描述的是上一次请求。
            // English: aborted() latches until the next startControl, so it must be read immediately
            //          after the evaluation or it describes a previous request.
            val aborted = engine.aborted()

            // 中文：LaTeX 不走 calculateAndPrint —— 它在 TAG_TYPE_LATEX 上会把 "$\displaystyle "
            //       无条件插入两次（上游 bug），4√2 会变成 "$\displaystyle $\displaystyle 4\sqrt{2}$"。
            //       改走 parse → calculate → print，print() 不做任何 $ 包裹，调用方拿到裸 LaTeX。
            //       注意这里用的是按值返回的 calculate 重载（Calculator.h:460），因此不依赖
            //       SWIG 指针写回的语义，代价是这一步没有超时。
            // English: LaTeX does not go through calculateAndPrint — on the TAG_TYPE_LATEX path it
            //          inserts "$\displaystyle " unconditionally twice (an upstream bug), turning
            //          4√2 into "$\displaystyle $\displaystyle 4\sqrt{2}$". It goes through
            //          parse → calculate → print instead; print() adds no $ wrapper, so the caller
            //          gets bare LaTeX. Note this uses the by-value calculate overload
            //          (Calculator.h:460), so it does not rely on SWIG pointer write-back
            //          semantics — at the cost of having no timeout on this step.
            //
            // 中文：LaTeX 这一步必须用 EXACT。TRY_EXACT 下结构里留下的是近似值，而 libqalculate
            //       把近似值表示成不确定区间，直接 print 出来是 \num{interval(5.6568542,5.6568543)}
            //       ——一个精确形态的反面。EXACT 才让结构里留下 4√2。
            // English: this step must use EXACT. Under TRY_EXACT the structure holds the
            //          approximation, which libqalculate represents as an uncertainty interval, and
            //          printing it yields \num{interval(5.6568542,5.6568543)} — the opposite of an
            //          exact form. EXACT is what leaves 4√2 in the structure.
            val exactEvaluation = evaluationOptions(ApproximationMode.APPROXIMATION_EXACT)
            val parsed = engine.parse(normalized, exactEvaluation.parse_options)
            val evaluated = engine.calculate(parsed, exactEvaluation)
            val latex = engine.print(evaluated, PRINT_TIMEOUT_MS, printOptions(latex = true), true, 0, libqalculateConstants.TAG_TYPE_LATEX)

            mapOf(
                "expression" to expression,
                "normalized" to normalized,
                "ok" to "true",
                "decimal" to decimal,
                "dual" to dual,
                "latex" to latex,
                "aborted" to aborted.toString(),
                "messages" to drainMessages(engine),
            )
        } catch (error: Throwable) {
            // 中文：System.loadLibrary 失败抛的是 Error 而不是 Exception，只有捕获 Throwable
            //       才能把「引擎没加载起来」变成一条可读日志，而不是一次崩溃。
            // English: A failed System.loadLibrary throws an Error, not an Exception. Only catching
            //          Throwable turns "the engine did not load" into a readable log line instead
            //          of a crash.
            Log.e(TAG, "evaluate <$expression> failed", error)
            mapOf(
                "expression" to expression,
                "ok" to "false",
                "error" to (error.message ?: error.toString()),
            )
        }
    }

    /**
     * 中文：一步式求值。calculateAndPrint 自己会处理结尾的 to/where 指令、双解（精确+近似）
     *       和进制换算，所以主路径仍然是它。
     * English: One-shot evaluation. calculateAndPrint handles trailing to/where commands, the
     *          exact+approximate dual result and base conversion on its own, so it stays the
     *          primary path.
     */
    private fun render(
        engine: Calculator,
        expression: String,
        evaluation: EvaluationOptions,
        options: PrintOptions,
        approximation: AutomaticApproximation,
    ): String = engine.calculateAndPrint(
        expression,
        PRINT_TIMEOUT_MS,
        evaluation,
        options,
        AutomaticFractionFormat.AUTOMATIC_FRACTION_OFF,
        approximation,
        // 中文：parsed_expression 在 Java 侧是 SWIGTYPE_p_std__string，读不出来，只能传 null。
        // English: parsed_expression is a SWIGTYPE_p_std__string on the Java side — unreadable.
        //          null is the only legal value.
        null,
        -1,
        // 中文：result_is_comparison 同理，是 SWIGTYPE_p_bool。
        // English: result_is_comparison is the same story — a SWIGTYPE_p_bool.
        null,
        // 中文：format=false。为 true 且 tagtype 是 LATEX 时上游会双插入 $\displaystyle。
        // English: format=false. With true and a LATEX tagtype the upstream code double-inserts
        //          $\displaystyle.
        false,
        0,
        libqalculateConstants.TAG_TYPE_TERMINAL,
    )

    private fun evaluationOptions(approximation: ApproximationMode): EvaluationOptions = EvaluationOptions().apply {
        setApproximation(approximation)
        setAllow_complex(true)
    }

    private fun printOptions(latex: Boolean): PrintOptions = PrintOptions().apply {
        setNumber_fraction_format(NumberFractionFormat.FRACTION_DECIMAL)
        // 中文：C++ 里这是 int 不是 boolean。LaTeX 必须关掉 Unicode 符号，否则拿到的是「√」而不是「\sqrt」。
        // English: an int in C++, not a boolean. Unicode signs must be off for LaTeX, or the output
        //          carries "√" instead of "\sqrt".
        setUse_unicode_signs(if (latex) UNICODE_SIGNS_OFF else UNICODE_SIGNS_ON)
    }

    /**
     * 中文：libqalculate 不抛异常，警告与错误进的是消息队列。这串文本是判断
     *       「表达式为什么没算出来」的唯一线索，所以跟着结果一起带回去。
     * English: libqalculate does not throw — warnings and errors land in a message queue. That
     *          text is the only clue to why an expression did not evaluate, so it travels back
     *          alongside the result.
     */
    private fun drainMessages(engine: Calculator): String {
        val collected = mutableListOf<String>()
        var current = engine.message()
        while (current != null) {
            collected += "${current.type()}: ${current.message()}"
            current = engine.nextMessage()
        }
        engine.clearMessages()
        return collected.joinToString(" | ")
    }

    companion object {
        /** 中文：两侧共用的日志标签，方便 adb logcat 一次抓全。 */
        const val TAG = "NekoCalcQalculate"

        private const val PRINT_TIMEOUT_MS = 2000

        // 中文：取值来自 libqalculate/includes.h 的 UNICODE_SIGNS_* 匿名枚举，SWIG 没有导出成 Java 常量。
        // English: values from the UNICODE_SIGNS_* anonymous enum in libqalculate/includes.h;
        //          SWIG does not export them as Java constants.
        private const val UNICODE_SIGNS_OFF = 0
        private const val UNICODE_SIGNS_ON = 1
    }
}
