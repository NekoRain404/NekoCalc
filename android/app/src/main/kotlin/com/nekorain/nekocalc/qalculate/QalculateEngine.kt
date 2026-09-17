package com.nekorain.nekocalc.qalculate

import android.util.Log
import com.jherkenhoff.libqalculate.AngleUnit
import com.jherkenhoff.libqalculate.ApproximationMode
import com.jherkenhoff.libqalculate.AutomaticApproximation
import com.jherkenhoff.libqalculate.AutomaticFractionFormat
import com.jherkenhoff.libqalculate.Calculator
import com.jherkenhoff.libqalculate.DigitGrouping
import com.jherkenhoff.libqalculate.EvaluationOptions
import com.jherkenhoff.libqalculate.IntervalDisplay
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
        // 中文：精度提到 16 位**有效数字**。默认的 8 位会让 `decimal` 在 Dart 侧取整之前就已经失真：
        //       `1000000/3` 在 8 位下是 `333333.33`，用户把设置调到 8 位小数时显示成
        //       `333333.33000000`——凭空多出六位假的零。16 位有效数字在整个 double 量程内都足够
        //       喂给显示取整，MPFR 算这个几乎不花钱。
        //
        //       注意：这里管的是**算得多准**，不是**显示成什么样**。AppSettings.precision 的语义是
        //       小数位数（4/6/8），与有效数字不是同一个轴，取整仍然留在 Dart 的 formatNumber 里，
        //       否则会悄悄改掉用户现有设置的含义。
        // English: Precision is raised to 16 *significant digits*. The default 8 corrupts `decimal`
        //          before Dart ever rounds it for display: `1000000/3` is `333333.33` at 8 digits,
        //          and with the user's 8-decimal-place setting that displays as `333333.33000000` —
        //          six fabricated zeros. Sixteen significant digits feed display rounding across the
        //          whole double range, and MPFR barely notices the cost.
        //
        //          Note what this does *not* own: it decides how accurately the engine computes, not
        //          how the result is shown. AppSettings.precision is a count of decimal places
        //          (4/6/8), which is a different axis, so rounding stays in Dart's formatNumber —
        //          moving it here would silently change what the user's existing setting means.
        instance.setPrecision(ENGINE_PRECISION)
        // 中文：小数点钉成 `.`，与 App 自己的表达式语法一致。不钉的话，逗号小数分隔符的语言环境下
        //       `decimal` 会印成 `5,656854`——Dart 侧如果把逗号当千分位剥掉，就得到一个**静默的
        //       错值** `5656854`。这一行是那道保险的第一层（第二层在 Dart 侧的按位置剥逗号，
        //       两层都对不上时 fail-closed）。
        //
        //       `useDecimalPoint(boolean)` 在打包进 App 的那个 AAR 里确实存在（`javap` 核对过：
        //       Calculator 上另有 `useDecimalPoint()` 与 `useDecimalComma()`）。
        // English: The decimal point is pinned to `.`, matching the app's own expression syntax.
        //          Without it, a comma-decimal locale prints `decimal` as `5,656854` — and a Dart
        //          side that strips the comma as a grouping separator ends up with the *silently
        //          wrong* `5656854`. This is the first layer of that guard (the second is the
        //          positional comma rule on the Dart side; when both say no it fails closed).
        //
        //          `useDecimalPoint(boolean)` really does exist in the AAR packaged into the app
        //          (verified with `javap`; Calculator also carries `useDecimalPoint()` and
        //          `useDecimalComma()`).
        instance.useDecimalPoint(true)
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
    fun evaluate(expression: String, angleMode: String): Map<String, String> =
        engineThread.submit(Callable { evaluateOnEngine(expression, angleMode) }).get()

    /**
     * 中文：把求值排到引擎线程上并在那里回调。channel 用这个入口，Android 主线程因此不必
     *       等引擎——MethodChannel.Result 允许从非主线程完成。
     * English: Queue the evaluation onto the engine thread and call back from there. The channel
     *          uses this entry point so the Android main thread never waits on the engine —
     *          MethodChannel.Result may be completed from a non-main thread.
     */
    fun evaluateAsync(
        expression: String,
        angleMode: String,
        onResult: (Map<String, String>) -> Unit,
    ) {
        engineThread.execute { onResult(evaluateOnEngine(expression, angleMode)) }
    }

    private fun evaluateOnEngine(expression: String, angleMode: String): Map<String, String> {
        return try {
            val engine = calc
            engine.clearMessages()

            // 中文：角度单位落在 ParseOptions 上（不在 Calculator 上），而且解析与求值都要它：
            //       `sin(30)` 在 DEG 与 RAD 下是两个不同的数。三处 EvaluationOptions 都经过
            //       evaluationOptions()，所以传进来的模式会同时到达 unlocalizeExpression 的
            //       parse_options 与 calculate/calculateAndPrint 的求值选项。
            // English: The angle unit lives on ParseOptions (not on Calculator), and both parsing
            //          and evaluation need it: `sin(30)` is a different number in DEG and RAD. All
            //          three EvaluationOptions go through evaluationOptions(), so the mode reaches
            //          the parse_options used by unlocalizeExpression as well as the evaluation
            //          options used by calculate/calculateAndPrint.
            val angleUnit = angleUnitFor(angleMode)

            // 中文：TRY_EXACT 用于一步式打印；要不要近似由打印阶段的 AutomaticApproximation 决定。
            // English: TRY_EXACT feeds the one-shot printer; whether to approximate is then decided
            //          at print time by AutomaticApproximation.
            val evaluation = evaluationOptions(ApproximationMode.APPROXIMATION_TRY_EXACT, angleUnit)
            val terminal = printOptions(latex = false)
            // 中文：`decimal` 的契约是「机器可解析」——Dart 侧要把它 `double.tryParse` 成数字，
            //       再按用户设置取整显示。所以这一份必须关掉 Unicode 符号与千分位：
            //       `5,656.854` 与 `−5.6`（U+2212）都不是 `double.tryParse` 认的数字，而它失败
            //       时**不抛异常**，只返回 null——记忆寄存器静默加 0、Ans/last 静默失效。
            // English: `decimal`'s contract is "machine-parseable" — Dart parses it with
            //          `double.tryParse` and then rounds it for display at the user's setting. So
            //          this one must have Unicode signs and digit grouping off: `5,656.854` and
            //          `−5.6` (U+2212) are not numbers `double.tryParse` accepts, and it fails by
            //          returning null *without throwing* — the memory register silently adds 0 and
            //          Ans/last silently stop resolving.
            val machineReadable = printOptions(latex = false, machineReadable = true)

            // 中文：unlocalizeExpression 把本地化的函数名与符号换成引擎内部写法。
            // English: unlocalizeExpression rewrites localised function names and symbols into the
            //          engine's internal spelling.
            val normalized = engine.unlocalizeExpression(expression, evaluation.parse_options)

            // 中文：十进制那一份明确要求近似（SINGLE = 只显示近似值）。
            //       近似值在引擎内部就是一个区间（Number 用 MPFR 的上下界对表示），
            //       但「怎么印区间」由 PrintOptions.interval_display 决定，与求值无关。
            //       这正是上一轮找错了抽屉的地方：APPROXIMATION_APPROXIMATE 和
            //       AUTOMATIC_APPROXIMATION_SINGLE 属于求值/近似，max_decimals 只把区间收窄；
            //       真正管这件事的是 INTERVAL_DISPLAY_MIDPOINT —— 打印区间中点那一个普通十进制数。
            //       见 Number.cc:11970（打印路径）与 includes.h:398-407（枚举）。
            // English: the decimal rendering explicitly asks for the approximation (SINGLE = show
            //          only the approximate value). Inside the engine an inexact value *is* an
            //          interval — a Number of type FLOAT stores an MPFR low/high bound pair — but
            //          how that interval is *printed* is PrintOptions.interval_display, which has
            //          nothing to do with evaluation. That is the drawer the previous attempt
            //          looked in the wrong place for: APPROXIMATION_APPROXIMATE and
            //          AUTOMATIC_APPROXIMATION_SINGLE belong to evaluation/approximation, and
            //          max_decimals only narrows the interval. INTERVAL_DISPLAY_MIDPOINT is what
            //          prints the interval's midpoint as a plain decimal. See Number.cc:11970 for
            //          the print path and includes.h:398-407 for the enum.
            val decimal = render(
                engine,
                normalized,
                evaluationOptions(ApproximationMode.APPROXIMATION_APPROXIMATE, angleUnit),
                machineReadable,
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
            // 中文：LaTeX 这一步必须用 EXACT。TRY_EXACT 下结构里留下的是近似值，印出来就是一个
            //       十进制数——精确形态的反面。EXACT 才让结构里留下 4√2。
            //       （interval_display = MIDPOINT 之后这里不再出现 \num{interval(…)}；那个宏
            //       flutter_math_fork 也不认。但「印出 5.6568542」同样不是我们想要的精确形态，
            //       EXACT 依然是必需的。）
            // English: this step must use EXACT. Under TRY_EXACT the structure holds the
            //          approximation, and printing it yields a decimal — the opposite of an exact
            //          form. EXACT is what leaves 4√2 in the structure. (With
            //          interval_display = MIDPOINT, \num{interval(…)} no longer appears here — that
            //          macro is one flutter_math_fork rejects anyway — but "5.6568542" is just as
            //          far from the exact form we want, so EXACT is still required.)
            val exactEvaluation = evaluationOptions(ApproximationMode.APPROXIMATION_EXACT, angleUnit)
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
                "angleMode" to angleMode,
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

    /**
     * 中文：Dart 侧只发 `DEG` / `RAD`（来自 `AppSettings.angleMode`）。别的值按弧度处理——弧度
     *       是 `AppSettings.fallback` 的默认模式，也是 libqalculate 自己的默认角度单位。
     * English: Dart only sends `DEG` / `RAD` (from `AppSettings.angleMode`). Anything else is read
     *          as radians — `AppSettings.fallback`'s default mode, and libqalculate's own default
     *          angle unit.
     */
    private fun angleUnitFor(angleMode: String): AngleUnit =
        if (angleMode.equals("DEG", ignoreCase = true)) {
            AngleUnit.ANGLE_UNIT_DEGREES
        } else {
            AngleUnit.ANGLE_UNIT_RADIANS
        }

    private fun evaluationOptions(
        approximation: ApproximationMode,
        angleUnit: AngleUnit,
    ): EvaluationOptions = EvaluationOptions().apply {
        setApproximation(approximation)
        setAllow_complex(true)
        // 中文：角度单位不在 EvaluationOptions 自己身上，而是在它的 `parse_options` 成员里——角度
        //       单位本来就属于解析选项，所以 `sin` 的自变量按哪种单位解释由这里决定。
        //       `getParse_options()` 返回的是**同一个 C++ 对象**的非拥有代理（SWIG 生成的是
        //       `new ParseOptions(ptr, false)`，已从字节码核对），所以在这里设值就是设在本次求值
        //       的选项上，而不是设在一个会被丢掉的副本上。
        // English: The angle unit is not on EvaluationOptions itself but on its `parse_options`
        //          member — the unit belongs to the parse options by design, and it is what decides
        //          how a `sin` argument is read. `getParse_options()` returns a *non-owning* proxy
        //          to the same C++ object (SWIG emits `new ParseOptions(ptr, false)`; verified in
        //          the bytecode), so setting it here sets it on this evaluation's options rather
        //          than on a copy that would be thrown away.
        parse_options.setAngle_unit(angleUnit)
    }

    private fun printOptions(latex: Boolean, machineReadable: Boolean = false): PrintOptions = PrintOptions().apply {
        setNumber_fraction_format(NumberFractionFormat.FRACTION_DECIMAL)
        // 中文：C++ 里这是 int 不是 boolean。LaTeX 必须关掉 Unicode 符号，否则拿到的是「√」而不是「\sqrt」。
        //       机器可解析的那一份（`decimal`）同样要关：开着的时候负号是 `−`(U+2212)，Dart 侧
        //       `double.tryParse` 直接返回 null。
        // English: an int in C++, not a boolean. Unicode signs must be off for LaTeX, or the output
        //          carries "√" instead of "\sqrt". The machine-parseable one (`decimal`) needs them
        //          off too: with them on a negative number prints `−`(U+2212), which Dart's
        //          `double.tryParse` rejects outright.
        setUse_unicode_signs(if (latex || machineReadable) UNICODE_SIGNS_OFF else UNICODE_SIGNS_ON)
        // 中文：千分位只对机器可解析的那一份显式关掉。默认值不写进代码是会漂的：`5,656.854` 这种
        //       带分隔符的输出到了 Dart 侧同样是静默的 null。人类可读的那几份（dual）保持原样。
        // English: Digit grouping is explicitly turned off for the machine-parseable form only.
        //          Leaving it to the default would drift: `5,656.854` is just as silently null on
        //          the Dart side. The human-readable forms (`dual`) keep whatever the default is.
        if (machineReadable) setDigit_grouping(DigitGrouping.DIGIT_GROUPING_NONE)
        // 中文：把区间印成中点，而不是 interval(下界, 上界)。这是「无理结果只有一个十进制数」的
        //       唯一开关，且只影响显示——Number 里的上下界原封不动，精确形态那一份照旧由
        //       APPROXIMATION_EXACT 保留。
        //       值取自已确认可由 SWIG 访问的 IntervalDisplay 枚举类。
        // English: print an interval as its midpoint rather than interval(lower, upper). This is the
        //          one switch that makes an irrational result a single decimal, and it is display
        //          only — the low/high bounds inside the Number are untouched, and the exact form is
        //          still preserved by APPROXIMATION_EXACT on its own path. The value comes from the
        //          IntervalDisplay enum class, confirmed reachable through SWIG.
        setInterval_display(IntervalDisplay.INTERVAL_DISPLAY_MIDPOINT)
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

        // 中文：有效数字位数，不是小数位数。见 `calc` 上的注释：默认的 8 位会让 Dart 侧的显示取整
        //       拿到一个已经失真的数。
        // English: significant digits, not decimal places. See the comment on `calc`: the default 8
        //          hands Dart's display rounding a number that is already wrong.
        private const val ENGINE_PRECISION = 16

        // 中文：取值来自 libqalculate/includes.h 的 UNICODE_SIGNS_* 匿名枚举，SWIG 没有导出成 Java 常量。
        // English: values from the UNICODE_SIGNS_* anonymous enum in libqalculate/includes.h;
        //          SWIG does not export them as Java constants.
        private const val UNICODE_SIGNS_OFF = 0
        private const val UNICODE_SIGNS_ON = 1
    }
}
