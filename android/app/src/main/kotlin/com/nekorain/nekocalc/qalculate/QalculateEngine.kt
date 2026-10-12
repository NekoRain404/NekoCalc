package com.nekorain.nekocalc.qalculate

import android.util.Log
import com.jherkenhoff.libqalculate.AngleUnit
import com.jherkenhoff.libqalculate.ApproximationMode
import com.jherkenhoff.libqalculate.AutoPostConversion
import com.jherkenhoff.libqalculate.Calculator
import com.jherkenhoff.libqalculate.DigitGrouping
import com.jherkenhoff.libqalculate.IntervalDisplay
import com.jherkenhoff.libqalculate.MathStructure
import com.jherkenhoff.libqalculate.MixedUnitsConversion
import com.jherkenhoff.libqalculate.NumberFractionFormat
import com.jherkenhoff.libqalculate.StructureType
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
 *
 * 中文：两组选项（求值/解析与打印）挪到了同包的 `QalculateOptions.kt`，结果形状的判据挪到了
 *       `QalculateResultKind.kt`。那次拆分只是搬家：内容逐行未改，只有 `private fun` 变成
 *       同包可见的 `internal fun`。
 * English: The two option sets (evaluation/parse and print) moved to `QalculateOptions.kt` in this
 *          package, and the result-shape predicates to `QalculateResultKind.kt`. That split was a
 *          move: every line came across unchanged, only `private fun` became package-visible
 *          `internal fun`.
 */
class QalculateEngine(
    // 中文：必须由宿主显式加载 libqalculate_swig.so。
    //
    // 这个 AAR 的 classes.jar 里一处 System.loadLibrary 都没有——SWIG 的 %pragma(java)
    // jniclasscode 没有被写进 libqalculate.i，所以生成的 JNI 胶水不会自己加载动态库。
    // 少了这一行，第一次 `Calculator()` 就抛 UnsatisfiedLinkError：
    // 「No implementation found for long ...libqalculateJNI.new_Calculator__SWIG_0()」。
    //
    // 库名来自 libqalculate_swig.so 的 SONAME，不是文件名猜的。它 DT_NEEDED 的
    // libqalculate / libgmp / libmpfr / libiconv / libxml2 / libc++_shared 都在同一个 AAR 里，
    // 链接器会在同一个目录里把它们找齐。
    //
    // **它做成构造参数只为测试**：宿主 JVM 上没有那个 `.so`，`System.loadLibrary` 在那里必然抛
    // `UnsatisfiedLinkError`，于是求值路径在单元测试里一步都走不动（`src/test` 里那份 JNI 替身
    // 接得住 AAR 自己的胶水，接不住 JDK 这一句）。生产调用方用的是默认值，行为一字未改；
    // 默认值与注入值的差别**只到这一行为止**——下面所有东西（`Calculator`、全局定义、回执）
    // 两条路完全一样。
    //
    // English: The host must load libqalculate_swig.so explicitly.
    //
    // There is not a single System.loadLibrary call anywhere in this AAR's classes.jar — SWIG's
    // %pragma(java) jniclasscode never made it into libqalculate.i, so the generated JNI glue does
    // not load the shared library itself. Without this line the first `Calculator()` throws
    // UnsatisfiedLinkError: "No implementation found for long
    // ...libqalculateJNI.new_Calculator__SWIG_0()".
    //
    // The name comes from the SONAME of libqalculate_swig.so rather than from guessing at the file
    // name. Everything it DT_NEEDs — libqalculate / libgmp / libmpfr / libiconv / libxml2 /
    // libc++_shared — ships in the same AAR, so the linker finds them side by side.
    //
    // **It is a constructor parameter for tests only**: a host JVM has no such `.so`, so
    // `System.loadLibrary` always throws `UnsatisfiedLinkError` there and the evaluation path cannot
    // take a single step under a unit test (the JNI double under `src/test` catches the AAR's own
    // glue, not this JDK call). Production passes the default and its behaviour is unchanged; the
    // two differ **only up to this line** — everything below (`Calculator`, the global definitions,
    // the receipt) is identical on both roads.
    private val loadNativeLibrary: () -> Unit = { System.loadLibrary("qalculate_swig") },
) {

    private val engineThread = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "qalculate-engine").apply { isDaemon = true }
    }

    /**
     * 中文：**`loadGlobalDefinitions()` 的结果——回执里那条事实的来源。** 它在第一次求值时被写一次
     *       （下面 `calc` 里那一行），此后只读，读写都只在引擎线程上。
     *
     *       §5o 记下的缺陷正是「只写进 logcat、不带出这一层」：为 false 时算术照常工作，但 400 多个
     *       单位与所有常数静默消失，而同一条输入会被引擎读成**别的东西**——Dart 分不出「引擎没有
     *       单位」与「引擎给了一个答案」。现在它跟着每一份回执走（`definitionsLoaded`），调用方据此
     *       拒绝这台引擎的答案（回落旧解析器），而不是把错值当真值。
     *
     *       初值 `false` 的含义是**「还没加载过」，不是「加载失败」**：真正的加载发生在第一次求值里，
     *       而带这个字段的两条出口（调用名守卫、求值成功）都在加载**之后**才读它。异常出口（catch
     *       那份 map）故意不带这个字段：那条路上回执已经是一份失败，「加载成没成」改变不了什么。
     *
     * English: **the result of `loadGlobalDefinitions()`, the source of the receipt's fact.** It is
     *          written once, by the first evaluation (the line inside `calc` below), and only read
     *          afterwards; both happen on the engine thread alone.
     *
     *          §5o recorded the defect as exactly "written to logcat and never carried out of this
     *          layer": when it is false arithmetic still works but 400-odd units and every constant
     *          vanish silently, and the same input gets read as **something else** — Dart could not
     *          tell "the engine has no units" from "the engine gave an answer". It now travels with
     *          every receipt (`definitionsLoaded`) so the caller refuses this engine's answers and
     *          falls back to the legacy parser instead of taking a wrong value for a right one.
     *
     *          The initial `false` means **"not loaded yet", not "failed to load"**: the real load
     *          happens inside the first evaluation, and the two exits that carry the field (the
     *          call-name guard and the successful map) read it only after that. The exceptional exit
     *          (the catch map) deliberately carries no such field: on that road the receipt is
     *          already a failure and "did the load succeed" changes nothing.
     */
    private var globalDefinitionsLoaded = false

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
        // 中文：记进回执那一份事实（见字段上的注释）——logcat 只留给人看，这里才是要带出去的那一份。
        // English: recorded into the receipt's fact (see the field's note) — logcat stays for human
        //          eyes; this is the copy that travels.
        globalDefinitionsLoaded = loaded
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

            // 中文：**这台引擎到底有没有单位与常数**——回执里那条事实，在这里读一次、下面两条出口
            //       （调用名守卫与求值成功那份 map）共用同一个键值对，两条路因此说不了两句话。
            //       局部值本身是 `val`：一次求值里它不会变，加载就在上一行发生。
            // English: **does this engine have its units and constants** — the receipt's fact, read
            //          once here and shared by the two exits below (the call-name guard and the
            //          successful map), so the two cannot say different things. The local is a
            //          `val`: it cannot change within one evaluation, and the load happened on the
            //          line above.
            val definitionsLoadedEntry = "definitionsLoaded" to globalDefinitionsLoaded.toString()

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
            //       这一份只用来拿 `parse_options`（角度单位就在里面，见下面那一段），`decimal`
            //       自己另建一份明确要求近似的求值选项。
            // English: TRY_EXACT feeds the one-shot printer; whether to approximate is then decided
            //          at print time by AutomaticApproximation. This instance is only used for its
            //          `parse_options` (the angle unit lives there, see the block below), while
            //          `decimal` builds its own options that explicitly ask for the approximation.
            val evaluation = evaluationOptions(ApproximationMode.APPROXIMATION_TRY_EXACT, angleUnit)
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

            // 中文：**引擎读得懂这个输入吗。** 引擎不认识一个函数名时不会拒绝它，而是把那个词拆成
            //       它认识的符号（`npr` → `n·p·r`），于是它的答案描述的是**另一件事**——而且有时
            //       还是一个矩阵，只按结果形状判会放它上屏。判据放在这里、问的是**引擎自己的符号表**：
            //       表达式里每一个调用名，引擎的 `getFunction` 都得认得。
            //
            //       这是 Dart 侧那张应用词表的**引擎侧那一半**：词表管「属于应用词汇的名字」，
            //       这里管**所有**调用名（用户在编辑器里敲进来的名字也在内）——两边是同一条规则的
            //       两个入口，谁都不会把对方的拒绝放宽。不认识时按 `ok=false` 回，调用方按
            //       「这一次没有引擎答案」处理（回落旧解析器 = 硬性边界 1）。
            // English: **can the engine read this input.** When the engine does not know a function
            //          name it does not reject it — it takes the word apart into symbols it does know
            //          (`npr` → `n·p·r`), so its answer is about **something else**; and some of those
            //          answers are matrices, which a shape-only rule would put on the screen. The test
            //          lives here and asks the **engine's own symbol table**: every call name in the
            //          expression must be one `getFunction` recognises.
            //
            //          This is the **engine-side half** of the app-side vocabulary in Dart: that table
            //          covers "names that belong to the app's vocabulary", this covers **every** call
            //          name (including ones typed into the editor) — two entrances to the same rule,
            //          and neither can relax the other's rejection. An unrecognised one comes back as
            //          `ok=false`, so the caller treats it as "no engine answer this time" (fall back
            //          to the legacy parser = hard boundary 1).
            firstCallNameUnknownToEngine(engine, normalized)?.let { unknown ->
                // 中文：这条出口**尤其**要带 `definitionsLoaded`：定义没加载时引擎的符号表是空的，
                //       于是每一个调用名都不认识——「无法识别的标识符」正是缺定义的**后果**，Dart 侧
                //       靠这个字段才认得出根因（见 `engine_definitions_unloaded` 那条判据）。
                // English: this exit **especially** carries `definitionsLoaded`: with no definitions
                //          loaded the engine's symbol table is empty, so every call name is unknown —
                //          "unrecognised identifier" is the *consequence* of the missing definitions,
                //          and only this field lets Dart name the root cause (see the
                //          `engine_definitions_unloaded` rule).
                return mapOf(
                    "expression" to expression,
                    "normalized" to normalized,
                    "ok" to "false",
                    "error" to "engine_unrecognised_identifier: $unknown",
                    "angleMode" to angleMode,
                ) + definitionsLoadedEntry
            }

            // 中文：**一次求值，两次打印。** 这是整个调用里唯一会算的地方，因此带随机性的函数
            //       （`rand()`）只抽一次样，`decimal` 与 `latex` 描述的是同一个值。
            //
            //       以前这里是**两次独立求值**：`decimal` 走 `calculateAndPrint(字符串, …)`、
            //       `latex` 走 `parse` + `calculate` + `print`。于是 `rand()` 的两个形态是两次独立的
            //       随机——设备实测 `decimal=0.4889249895812834` 而
            //       `latex=\num{0.5484658763631625}`，同一行上的「精确形式」与「近似值」来自两个
            //       不同的数。`calculateAndPrint` 还是一次调用里就改掉引擎逗号解释的那个入口
            //       （见 `evaluationOptions` 里那一段），于是它之后的所有解析都换了一种逗号解释。
            //
            //       字符串重载（`Calculator.h:441`）自己处理结尾的 `to`/`where` 指令，所以丢掉
            //       `calculateAndPrint` 不损失那部分能力——后者自己的文档就说它多出来的职责正是
            //       「处理结尾的 to-命令」。
            // English: **one evaluation, two printings.** This is the only place in the call that
            //          computes anything, so a function carrying randomness (`rand()`) draws exactly
            //          once and `decimal` and `latex` describe the same value.
            //
            //          This used to be **two independent evaluations**: `decimal` went through
            //          `calculateAndPrint(string, …)` and `latex` through `parse` + `calculate` +
            //          `print`. So `rand()`'s two forms were two independent draws — measured on a
            //          device as `decimal=0.4889249895812834` against
            //          `latex=\num{0.5484658763631625}` — the "exact form" and the "approximation"
            //          on one line came from two different numbers. `calculateAndPrint` is also the
            //          entry point that rewrites the engine's comma interpretation inside a single
            //          call (see the note in `evaluationOptions`), after which every later parse
            //          interprets commas differently.
            //
            //          The string overload (`Calculator.h:441`) handles trailing `to`/`where`
            //          commands itself, so dropping `calculateAndPrint` loses none of that — its own
            //          documentation says handling ending "to"-commands is what it adds.
            // 中文：`to_struct` 是**引擎自己**的「这个输入里有没有换算」的答案：`calculate` 会在
            //       结尾的 to-命令（`to`、`->`、`→`、`−>` 以及 dingbats——引擎自己的
            //       `separateToExpression`，`Calculator-calculate.cc:3596`）真的做了一次换算时，
            //       把换算结果写回这个结构。Dart/Kotlin 侧**不判断**哪些写法算「到」——那种清单
            //       已经错过一次（`100 -> hex` 曾经被漏掉），这里让引擎说了算。
            // English: `to_struct` is **the engine's own** answer to "does this input contain a
            //          conversion": `calculate` writes the conversion's result back into it when a
            //          trailing to-command (`to`, `->`, `→`, `−>` and the dingbats — the engine's own
            //          `separateToExpression`, `Calculator-calculate.cc:3596`) really converted
            //          something. Neither Dart nor Kotlin decides which spellings count as "to" —
            //          such a list has already been wrong once (`100 -> hex` was missed); the engine
            //          decides here.
            val parsedStruct = MathStructure()
            val toStruct = MathStructure()
            val evaluated = engine.calculate(
                normalized,
                evaluationOptions(ApproximationMode.APPROXIMATION_EXACT, angleUnit),
                parsedStruct,
                toStruct,
                true,
            )
            // 中文：**这个结果是什么形状**——全部由引擎自己的判据回答，没有一个字是从印出来的
            //       文本猜的（Dart 侧据此决定「能不能显示」，见 `MathResult.isDisplayable`）：
            //
            //       - `conversion`：引擎做了一次换算（上面那个 `to_struct`）；
            //       - `unit`：结果带单位（`containsType(STRUCT_UNIT, 递归, …)`）；
            //       - `structured`：矩阵 / 向量（解集也是向量）；
            //       - `number`：引擎的 Number（复数走这一支——实数在 Dart 侧就已经是十进制了）；
            //       - `symbolic`：结果里有变量符号，而引擎一句话都没说（见 `KIND_SYMBOLIC`）；
            //       - `arithmetic`：其余一切（乘积、幂、函数调用、符号和）。
            //
            //       顺序有意义：**带单位压过形状**。`ncr(5,10)` 的结果是一个向量（`isVector()` 为真）
            //       但它每一项都带着单位——引擎把 `n`/`c`/`r` 读成了单位与常量。带单位的判据先跑，
            //       它就落不进 `structured`。
            // English: **what shape this result is** — answered entirely by the engine's own
            //          predicates, not one word of it guessed from the printed text (Dart uses it to
            //          decide "may this be displayed"; see `MathResult.isDisplayable`):
            //
            //          - `conversion`: the engine performed a conversion (the `to_struct` above);
            //          - `unit`: the result carries a unit (`containsType(STRUCT_UNIT, recursive, …)`);
            //          - `structured`: a matrix or a vector (a solution set is a vector);
            //          - `number`: the engine's Number (complex numbers land here — a real number is
            //            already a decimal by the time Dart sees it);
            //          - `symbolic`: the result holds a variable symbol and the engine said nothing
            //            (see `KIND_SYMBOLIC`);
            //          - `arithmetic`: everything else (products, powers, calls, symbolic sums).
            //
            //          The order matters: **carrying a unit outranks the shape**. The result of
            //          `ncr(5,10)` is a vector, yet every element of it carries a unit — the engine
            //          read `n`, `c` and `r` as units and constants. The unit test runs first, so it
            //          never reaches `structured`.
            // 中文：**aborted 必须紧跟求值就读**——它锁存到下一次 `startControl`，而下面每一次
            //       `print`/`calculate`（含 `conversionLanded` 里那一次）都会 `startControl`，
            //       把这个锁存重置成**那一次**调用的状态。以前这一行在两次 print 之后，读到的其实
            //       已经不是主求值的那一次了；这一步新增了一次 `calculate`，所以把它挪到它注释一直
            //       声称的位置上。
            // English: **aborted must be read immediately after the evaluation** — it latches until the
            //          next `startControl`, and every `print`/`calculate` below (including the one in
            //          `conversionLanded`) calls `startControl` and resets that latch to *that* call's
            //          state. This line used to sit after two prints, so what it read was no longer the
            //          main evaluation; this step adds one more `calculate`, so it moves to the place its
            //          own comment always claimed.
            val aborted = engine.aborted()
            // 中文：**引擎这一次有没有话要说。** 在同一个位置、同一个理由下读（见上面那一段）：
            //       `message()` 只是看一眼队首，**不弹出**，所以下面 `drainMessages` 照旧能把它收全；
            //       而每一个 `print`/`calculate` 都可能往队列里排东西，所以这一眼必须紧挨着主求值。
            //
            //       它服务的是下面那个 `symbolic` 分支：引擎**做不了**一个运算时不会抛异常，它把
            //       那个运算原样退回来，再往消息队列里排一句（实测：`1/0`、`x/0`、`0/0`、`2/0`、
            //       `0^(-1)`、`1/(x-x)` 全部排 `Division by zero.`，而 `2x`、`x^2+1`、`x+y`、
            //       `sqrt(x)`、`2/x`、`x^2*y^2` 一条都没有）。于是「队列空不空」就是引擎自己的
            //       「我算出来了」与「我没算」的判据——与 `aborted`、`to_struct` 同一类：由引擎回答，
            //       不从这里印出来的文本上猜。
            // English: **did the engine have anything to say this time.** Read here for the same
            //          reason as the line above: `message()` only looks at the head of the queue and
            //          does **not** pop it, so `drainMessages` below still collects everything; and
            //          every `print`/`calculate` can queue something, so this look has to sit right
            //          beside the main evaluation.
            //
            //          It serves the `symbolic` branch below: when the engine **cannot** perform an
            //          operation it does not throw — it hands the operation back and queues a line
            //          (measured: `1/0`, `x/0`, `0/0`, `2/0`, `0^(-1)`, `1/(x-x)` all queue
            //          `Division by zero.`, while `2x`, `x^2+1`, `x+y`, `sqrt(x)`, `2/x`, `x^2*y^2`
            //          queue nothing). So "is the queue empty" is the engine's own statement of "I
            //          computed it" versus "I did not" — the same kind of answer as `aborted` and
            //          `to_struct`: the engine answers it, nothing here is guessed from printed text.
            val silent = engine.message() == null

            // 中文：**这个结果是什么形状**——全部由引擎自己的判据回答，没有一个字是从印出来的
            //       文本猜的（Dart 侧据此决定「能不能显示」，见 `MathResult.isDisplayable`）：
            //
            //       - `conversion`：引擎做了一次换算（上面那个 `to_struct`）；
            //       - `unit_mismatch`：用户要了一次换算，而**那一次换算没有发生**（见
            //         `conversionLanded` 的注释）；
            //       - `unit`：结果带单位（`containsType(STRUCT_UNIT, 递归, …)`）；
            //       - `structured`：矩阵 / 向量（解集也是向量）；
            //       - `number`：引擎的 Number（复数走这一支——实数在 Dart 侧就已经是十进制了）；
            //       - `symbolic`：结果里有变量符号，而引擎一句话都没说（见 `KIND_SYMBOLIC`）；
            //       - `arithmetic`：其余一切（乘积、幂、函数调用、符号和）。
            //
            //       顺序有意义：**带单位压过形状**。`ncr(5,10)` 的结果是一个向量（`isVector()` 为真）
            //       但它每一项都带着单位——引擎把 `n`/`c`/`r` 读成了单位与常量。带单位的判据先跑，
            //       它就落不进 `structured`。
            // English: **what shape this result is** — answered entirely by the engine's own
            //          predicates, not one word of it guessed from the printed text (Dart uses it to
            //          decide "may this be displayed"; see `MathResult.isDisplayable`):
            //
            //          - `conversion`: the engine performed a conversion (the `to_struct` above);
            //          - `unit_mismatch`: a conversion was asked for and **did not happen** (see
            //            `conversionLanded`);
            //          - `unit`: the result carries a unit (`containsType(STRUCT_UNIT, recursive, …)`);
            //          - `structured`: a matrix or a vector (a solution set is a vector);
            //          - `number`: the engine's Number (complex numbers land here — a real number is
            //            already a decimal by the time Dart sees it);
            //          - `symbolic`: the result holds a variable symbol and the engine said nothing
            //            (see `KIND_SYMBOLIC`);
            //          - `arithmetic`: everything else (products, powers, calls, symbolic sums).
            //
            //          The order matters: **carrying a unit outranks the shape**. The result of
            //          `ncr(5,10)` is a vector, yet every element of it carries a unit — the engine
            //          read `n`, `c` and `r` as units and constants. The unit test runs first, so it
            //          never reaches `structured`.
            val kind = when {
                !toStruct.isUndefined() && !conversionLanded(engine, evaluated, toStruct, angleUnit) ->
                    KIND_UNIT_MISMATCH
                !toStruct.isUndefined() -> KIND_CONVERSION
                evaluated.containsType(StructureType.STRUCT_UNIT, true, true, false) > 0 ->
                    if (isPlainQuantity(evaluated)) KIND_QUANTITY else KIND_UNIT
                evaluated.isMatrix() || evaluated.isVector() -> KIND_STRUCTURED
                evaluated.isNumber() -> KIND_NUMBER
                silent && evaluated.containsType(StructureType.STRUCT_VARIABLE, true, true, false) > 0 ->
                    KIND_SYMBOLIC
                else -> KIND_ARITHMETIC
            }

            // 中文：十进制那一半由**同一个结构**再算一次得到，不是重新解析字符串：`evaluated` 里
            //       已经是一个求过值的数（`rand()` 的那次抽样已经发生），再算一次只是把它近似成
            //       十进制。宿主实测（同版本库、同一串调用）：`4 * sqrt(2)` 的精确结构印成
            //       `5.656854249492380`，而 `rand()` 的两个形态**逐字节相同**。
            //       近似值在引擎内部是一个区间（Number 用 MPFR 的上下界对表示），但「怎么印区间」
            //       由 `PrintOptions.interval_display` 决定，与求值无关：真正管这件事的是
            //       INTERVAL_DISPLAY_MIDPOINT —— 打印区间中点那一个普通十进制数。
            //       见 Number.cc:11970（打印路径）与 includes.h:398-407（枚举）。
            // English: the decimal half comes from evaluating **the same structure** again rather
            //          than re-parsing the string: `evaluated` already holds an evaluated value
            //          (`rand()`'s draw has happened), so this step only approximates it. Measured on
            //          the host (same library version, same call sequence): the exact structure
            //          `4 * sqrt(2)` prints as `5.656854249492380`, and `rand()`'s two forms are
            //          **byte-for-byte identical**. Inside the engine an inexact value *is* an
            //          interval — a Number of type FLOAT stores an MPFR low/high bound pair — but how
            //          that interval is *printed* is `PrintOptions.interval_display`, which has
            //          nothing to do with evaluation: INTERVAL_DISPLAY_MIDPOINT is what prints its
            //          midpoint as a plain decimal. See Number.cc:11970 for the print path and
            //          includes.h:398-407 for the enum.
            // 中文：**例外只有一条，而且它由引擎自己的答案决定**：引擎做了一次换算（`kind` 是
            //       `conversion`）时，十进制仍旧走 `calculateAndPrint` 那条一步式老路。
            //       理由是实测的：`1.5° to arcmin` 两种走法都对（`90 arcmin`），但
            //       `100 to hex` / `100 -> hex` / `100 → hex` 只有一步式那条路给出 `64`——
            //       `to hex`/`to binary`/`to factors` 这一族是 `calculateAndPrint` 独家负责的
            //       （它的文档就写着这一条）。
            //
            //       判据从「字符串里有没有 ` to `」改成「引擎有没有真的换算」之后，覆盖面**与引擎
            //       自身的规则逐条相同**——`->`/`→`/`−>`/dingbats 全都在内，因为判断就是引擎在
            //       `separateToExpression` 里做的，而不是这里猜的。
            //
            //       代价：这类表达式会被算两次，随机函数与换算同时出现时两个形态仍可能对不上——
            //       那是一个既打不出来、也没有意义的组合。键位表里没有任何东西能产生换算，所以
            //       **这条例外覆盖不到任何一颗键**：用户按出来的每一个表达式都走单次求值。
            // English: **there is exactly one exception, and the engine's own answer decides it**: when
            //          the engine performed a conversion (`kind == conversion`) the decimal still
            //          travels the one-shot `calculateAndPrint` path. Measured: `1.5° to arcmin` is
            //          right either way (`90 arcmin`), but `100 to hex`, `100 -> hex` and `100 → hex`
            //          only give `64` through the one-shot path — `to hex`/`to binary`/`to factors`
            //          and friends are `calculateAndPrint`'s own job (its documentation says so).
            //
            //          Moving the test from "does the string contain ` to `" to "did the engine really
            //          convert" makes its coverage **identical to the engine's own rule** — `->`,
            //          `→`, `−>` and the dingbats included, because the decision is made by
            //          `separateToExpression` inside the engine rather than guessed here.
            //
            //          The price: such expressions are evaluated twice, and a random function combined
            //          with a conversion could still disagree between its two forms — a combination
            //          that cannot be typed and means nothing. Nothing on the keypad produces a
            //          conversion, so **this exception covers no key at all**: everything the user can
            //          press runs the single evaluation above.
            // 中文：**三种写法由 `QalculateResultPrints.kt` 印**——同一次求值的三次打印（同一个
            //       `evaluated`、同一组选项，只差 `PrintOptions` 上一个字段）。本轮只是把印法搬了
            //       出去，每一份写法的理由与实测跟着它自己的函数一起走。
            // English: **the three spellings are printed by `QalculateResultPrints.kt`** — three prints
            //          of one evaluation (the same `evaluated`, the same options, differing in one
            //          `PrintOptions` field). This round only moved the printing out; each spelling's
            //          reasoning and measurements travelled with its own function.
            val latex = printExactLatex(engine, evaluated)
            val fractionLatex = printFractionLatex(engine, evaluated)
            val mixedLatex = printCombinedLatex(engine, evaluated)

            // 中文：**度分秒的写法**（HiPER 的 `D°M'S` 那一颗键要的东西）。它印的是**同一个
            //       `approximated` 结构**——也就是上面那一步刚刚算出来的、十进制那一份用的那个对象
            //       ——所以两者的值严格相等，`rand()` 也不会因为多印一份而多抽一次样。它必须是
            //       近似之后那一个结构，理由也是实测的：**精确结构印出来的是每个数的度分秒**，
            //       而不是整个结果的度分秒——`sqrt(8)` 在精确结构下是
            //       `2°0′0″ × √(2°0′0″)`，`matrix(2,2,1,2,3,4)` 是 `[1°0′0″  2°0′0″; …]`，
            //       `pi` 干脆是 `π`（宿主实测，同版本库、同一组选项）。近似结构上这三条分别是
            //       `2°49′42.33764908628435″`、`3°8′29.73355292325566″` 与一个正常的度分秒数——
            //       度分秒本来就是**一个实数的写法**，而「一个实数」正是近似之后的那一个。
            //
            //       **换算那一支（`KIND_CONVERSION`）不印这一份**：那条路的十进制来自
            //       `renderOneShot` 的一步式调用，手里没有结构；而且换算的结果是**带单位的量**，
            //       对它印度分秒会把单位里的每个数都印成度分秒（`90 arcmin` 会成
            //       `90°0′0″ arcmin`）。Dart 侧读到空串就是「这一次没有度分秒写法」，那一颗键
            //       于是是空操作——与引擎缺席走同一条路，不猜。
            //
            //       LaTeX 那一份**不能用**：同一个数在 `TAG_TYPE_LATEX` 下印成
            //       `\text{12o34'55.92"}`（宿主实测），是一段字面文本、度符号还是个字母 `o`。
            //       所以这一份走 `TAG_TYPE_TERMINAL` + unicode 开着（`°`/`′`/`″` 是真字符），
            //       Dart 侧再把它拼成能排版的 TeX（见 `ResultPresentation`）。
            //
            // English: **the degrees-minutes-seconds spelling** (what HiPER's `D°M'S` key is for).
            //          It prints **the same `approximated` structure** — the very object the decimal
            //          render above just used — so the two carry strictly equal values and `rand()` is
            //          not drawn a second time for it. It has to be the approximated structure, for a
            //          measured reason: **on the exact structure each number inside prints as DMS**
            //          rather than the result as a whole — `sqrt(8)` comes out
            //          `2°0′0″ × √(2°0′0″)`, `matrix(2,2,1,2,3,4)` comes out
            //          `[1°0′0″  2°0′0″; …]`, and `pi` comes out as plain `π` (host-measured, same
            //          library version and options). On the approximated structure those three are
            //          `2°49′42.33764908628435″`, `3°8′29.73355292325566″` and an ordinary DMS number —
            //          and DMS is by definition **a way of writing one real number**, which is exactly
            //          what the approximation is.
            //
            //          **The conversion branch (`KIND_CONVERSION`) does not print it**: that path's
            //          decimal comes from the one-shot `renderOneShot` call, which leaves no structure
            //          behind, and a conversion's answer is a **unit-carrying quantity** whose every
            //          inner number would print as DMS (`90 arcmin` would become
            //          `90°0′0″ arcmin`). An empty string on the Dart side means "no DMS spelling this
            //          time" and makes that key a no-op — the same route as an absent engine, never a
            //          guess.
            //
            //          The LaTeX render **cannot** be used here: the same number prints as
            //          `\text{12o34'55.92"}` under `TAG_TYPE_LATEX` (host-measured) — a literal text
            //          blob whose degree sign is the letter `o`. So this one goes through
            //          `TAG_TYPE_TERMINAL` with unicode signs on (`°`/`′`/`″` are real characters),
            //          and Dart assembles it into typesettable TeX (see `ResultPresentation`).
            var dmsText = ""
            val decimal = if (kind == KIND_CONVERSION) {
                renderOneShot(
                    engine,
                    normalized,
                    evaluationOptions(ApproximationMode.APPROXIMATION_APPROXIMATE, angleUnit),
                    machineReadable,
                )
            } else {
                val approximated = engine.calculate(
                    evaluated,
                    evaluationOptions(ApproximationMode.APPROXIMATION_APPROXIMATE, angleUnit),
                )
                dmsText = engine.print(
                    approximated,
                    PRINT_TIMEOUT_MS,
                    printOptions(latex = false, sexagesimal = true),
                    false,
                    0,
                    libqalculateConstants.TAG_TYPE_TERMINAL,
                )
                engine.print(
                    approximated,
                    PRINT_TIMEOUT_MS,
                    machineReadable,
                    false,
                    0,
                    libqalculateConstants.TAG_TYPE_TERMINAL,
                )
            }

            // 中文：**曾经**还有第三份渲染：`dual`（`AUTOMATIC_APPROXIMATION_DUAL` +
            //       `TAG_TYPE_TERMINAL`），形状是 `4 ⋅ √(2) ≈ 5.6568542`。它占这次调用约三分之一的
            //       原生工作量，而 Dart 侧从不读它——精确形式那一半由 `latex` 承担（而且是**能排版
            //       的那一种**写法），近似值那一半由 `decimal` 承担（而且是机器可解析的那一种）。
            //       于是它被删掉了，而不是留着当装饰：一个每次都算、没人读的字段就是白烧的 CPU。
            //
            //       为什么它的信息没有被丢掉：`dual` 是**终端格式**，`4 * sqrt(2)` 这种字符串既不能
            //       排版，又不是数字——它不能替代 `latex`（后者才排得出根号），也不能替代 `decimal`
            //       （后者才 `double.tryParse` 得动）。精确形式在设备上显示成 `2√2 ≈ 2.828427`
            //       用的正是 `latex` + `decimal` 这两份。
            // English: There **used** to be a third rendering here: `dual`
            //          (`AUTOMATIC_APPROXIMATION_DUAL` + `TAG_TYPE_TERMINAL`), shaped like
            //          `4 ⋅ √(2) ≈ 5.6568542`. It cost roughly a third of this call's native work and
            //          the Dart side never read it — the exact half is carried by `latex` (in the
            //          spelling that can actually be typeset) and the approximate half by `decimal`
            //          (in the spelling that is machine-parseable). It is gone rather than kept as
            //          decoration: a field computed on every call that nobody reads is CPU burnt for
            //          nothing.
            //
            //          Nothing is lost by that: `dual` is **terminal format** — `4 * sqrt(2)` is
            //          neither typesettable nor a number, so it can replace neither `latex` (the one
            //          that renders a radical) nor `decimal` (the one `double.tryParse` can read).
            //          What the device shows as `2√2 ≈ 2.828427` is exactly these two.

            mapOf(
                "expression" to expression,
                "normalized" to normalized,
                "ok" to "true",
                "decimal" to decimal,
                "latex" to latex,
                "fraction" to fractionLatex,
                "mixed" to mixedLatex,
                "dms" to dmsText,
                "aborted" to aborted.toString(),
                "messages" to drainMessages(engine),
                "kind" to kind,
                "angleMode" to angleMode,
            ) + definitionsLoadedEntry
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

    companion object {
        /** 中文：两侧共用的日志标签，方便 adb logcat 一次抓全。 */
        const val TAG = "NekoCalcQalculate"

        internal const val PRINT_TIMEOUT_MS = 2000

        // 中文：有效数字位数，不是小数位数。见 `calc` 上的注释：默认的 8 位会让 Dart 侧的显示取整
        //       拿到一个已经失真的数。
        // English: significant digits, not decimal places. See the comment on `calc`: the default 8
        //          hands Dart's display rounding a number that is already wrong.
        private const val ENGINE_PRECISION = 16

        // 中文：结果形状的取值——Dart 侧 `EngineResultKind` 与它们逐字对应（`"conversion"` 等）。
        // English: the result-shape values — Dart's `EngineResultKind` matches them verbatim.
        const val KIND_CONVERSION = "conversion"

        /** 中文：要了换算而换算没发生（见 [conversionLanded]）。Dart 侧一律不显示。 */
        const val KIND_UNIT_MISMATCH = "unit_mismatch"

        /** 中文：**一个量**（数 × 单位，见 [isPlainQuantity]）。Dart 侧显示它。 */
        const val KIND_QUANTITY = "quantity"

        /** 中文：带单位但**不是一个量**（算不出来的加法、带变量或函数的结果、引擎把我们的名字读成单位）。不显示。 */
        const val KIND_UNIT = "unit"
        const val KIND_STRUCTURED = "structured"
        const val KIND_NUMBER = "number"

        /**
         * 中文：**一个符号式子**——结果里含引擎的变量符号（`STRUCT_VARIABLE`），而且引擎这一次
         *       **一句话都没说**（消息队列是空的）。两条都是引擎自己的判据，一个字都没从印出来的
         *       文本上猜。
         *
         *       **它与 [KIND_ARITHMETIC] 的差别就是「引擎算没算」。** 两者都是「其余一切」（乘积、
         *       幂、函数调用、符号和），但 `arithmetic` 里还住着引擎**没做**那个运算、把它原样退回来
         *       的情形（`1/0`、`x/0`、`0^0`）——那些会排消息，或者结果里没有变量。引擎把运算退回来
         *       时不抛异常、不返回失败，所以「它做没做」只能由这两条引擎自己的事实回答。
         *
         *       **它不保证这个结果配得上屏幕**：那仍由 Dart 侧 `MathResult.isDisplayable` 一处回答，
         *       而且那里还有一道应用侧的判据（应用自己的语言表达得了这个输入时，旧解析器依旧是权威，
         *       见 `_selectEngineResult`）。实测的那个实例是 `pi!`：引擎把它读成
         *       `factorial(pi)`（`pi` 在引擎里是一个变量，量过），于是这一支判 `symbolic`——而屏
         *       幕上今天与放宽之后都是旧解析器那句「阶乘只支持 0 到 170 的整数」。
         *       （`pi` 单独一个**不**在这里：它的十进制形态是有限的 `3.141592653589793`，
         *       由上面那条 tier 2 直接采用。）
         * English: **a symbolic form** — the result holds one of the engine's variable symbols
         *          (`STRUCT_VARIABLE`) and the engine said **not one word** this time (its message
         *          queue is empty). Both are the engine's own predicates; not a word is guessed from
         *          the printed text.
         *
         *          **Its difference from [KIND_ARITHMETIC] is exactly "did the engine compute".** Both
         *          are "everything else" (products, powers, calls, symbolic sums), but `arithmetic` also
         *          holds the case where the engine **could not** do the operation and handed it back
         *          (`1/0`, `x/0`, `0^0`) — those queue a message, or carry no variable. The engine
         *          neither throws nor signals failure when it hands an operation back, so "did it do it"
         *          can only be answered by these two facts of its own.
         *
         *          **It does not promise this result belongs on screen**: that is still answered in one
         *          place, Dart's `MathResult.isDisplayable`, which also applies an app-side judgement
         *          (when this app's own language can express the input, the legacy parser stays the
         *          authority — see `_selectEngineResult`). The measured instance is `pi!`: the engine
         *          reads it as `factorial(pi)` (`pi` is one of its variables, measured), so it lands
         *          here — while the screen, today and after the relaxation, shows the legacy parser's
         *          "阶乘只支持 0 到 170 的整数". (`pi` on its own is **not** here: its decimal form is
         *          the finite `3.141592653589793`, which tier 2 above takes directly.)
         */
        const val KIND_SYMBOLIC = "symbolic"

        const val KIND_ARITHMETIC = "arithmetic"

        /**
         * 中文：翻译器写出来的**词运算符**（换算关键字）。它看起来像调用（`to (mi)`），但不是——
         *       见 [firstCallNameUnknownToEngine] 里那一段。Dart 侧的 `_binaryOperators` 是那张表的
         *       真源；这里加第二个词时那边也要加。
         * English: the **word operator** (conversion keyword) the translation writes. It looks like a
         *          call (`to (mi)`) and is not one — see the note in [firstCallNameUnknownToEngine].
         *          `_binaryOperators` on the Dart side is that table's source of truth; a second word
         *          there means a second one here.
         */
        const val WORD_OPERATOR_TO = "to"

    }
}
