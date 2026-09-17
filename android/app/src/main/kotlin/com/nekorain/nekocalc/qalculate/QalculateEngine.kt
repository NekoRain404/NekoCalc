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
import com.jherkenhoff.libqalculate.MathStructure
import com.jherkenhoff.libqalculate.NumberFractionFormat
import com.jherkenhoff.libqalculate.PrintOptions
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
                return mapOf(
                    "expression" to expression,
                    "normalized" to normalized,
                    "ok" to "false",
                    "error" to "engine_unrecognised_identifier: $unknown",
                    "angleMode" to angleMode,
                )
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
            //          - `arithmetic`: everything else (products, powers, calls, symbolic sums).
            //
            //          The order matters: **carrying a unit outranks the shape**. The result of
            //          `ncr(5,10)` is a vector, yet every element of it carries a unit — the engine
            //          read `n`, `c` and `r` as units and constants. The unit test runs first, so it
            //          never reaches `structured`.
            val kind = when {
                !toStruct.isUndefined() -> KIND_CONVERSION
                evaluated.containsType(StructureType.STRUCT_UNIT, true, true, false) > 0 -> KIND_UNIT
                evaluated.isMatrix() || evaluated.isVector() -> KIND_STRUCTURED
                evaluated.isNumber() -> KIND_NUMBER
                else -> KIND_ARITHMETIC
            }

            // 中文：精确形态先印——它要的是**未近似**的结构（`4√2`），所以必须在下面那一步之前印。
            //       不走 `calculateAndPrint`：它在 TAG_TYPE_LATEX 上会把 "$\displaystyle " 无条件
            //       插入两次（上游 bug），`4√2` 会变成 "$\displaystyle $\displaystyle 4\sqrt{2}$"。
            //       `print()` 不做任何 $ 包裹，调用方拿到裸 LaTeX。
            // English: the exact form is printed first — it wants the **unapproximated** structure
            //          (`4√2`), so it has to happen before the step below. It does not go through
            //          `calculateAndPrint`: on TAG_TYPE_LATEX that inserts "$\displaystyle "
            //          unconditionally twice (an upstream bug), turning `4√2` into
            //          "$\displaystyle $\displaystyle 4\sqrt{2}$". `print()` adds no $ wrapper,
            //          so the caller gets bare LaTeX.
            val latex = engine.print(evaluated, PRINT_TIMEOUT_MS, printOptions(latex = true), true, 0, libqalculateConstants.TAG_TYPE_LATEX)

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

            // 中文：aborted() 会一直锁存到下一次 startControl，所以必须紧跟求值就读，否则它描述的是上一次请求。
            // English: aborted() latches until the next startControl, so it must be read immediately
            //          after the evaluation or it describes a previous request.
            val aborted = engine.aborted()

            mapOf(
                "expression" to expression,
                "normalized" to normalized,
                "ok" to "true",
                "decimal" to decimal,
                "latex" to latex,
                "aborted" to aborted.toString(),
                "messages" to drainMessages(engine),
                "kind" to kind,
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
     * 中文：一步式求值——**只**给带结尾 `to <命令>` 的表达式用（见调用点那段注释）。`calculateAndPrint`
     *       自己会处理结尾的 to/where 命令和进制换算，代价是它在内部重新解析、重新求值一次。
     * English: one-shot evaluation — used **only** for expressions ending in a `to <command>` (see the
     *          note at the call site). `calculateAndPrint` handles trailing to/where commands and base
     *          conversion itself; the price is that it parses and evaluates the string again.
     */
    private fun renderOneShot(
        engine: Calculator,
        expression: String,
        evaluation: EvaluationOptions,
        options: PrintOptions,
    ): String = engine.calculateAndPrint(
        expression,
        PRINT_TIMEOUT_MS,
        evaluation,
        options,
        AutomaticFractionFormat.AUTOMATIC_FRACTION_OFF,
        AutomaticApproximation.AUTOMATIC_APPROXIMATION_SINGLE,
        // 中文：parsed_expression 在 Java 侧是 SWIGTYPE_p_std__string，读不出来，只能传 null。
        // English: parsed_expression is a SWIGTYPE_p_std__string on the Java side — unreadable.
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
        // 中文：**必须显式写这一行。** `ParseOptions::ParseOptions()`（`Calculator.cc:103`）的初始化
        //       列表里**漏掉了 `comma_as_separator`**——结构体里只有它是没初始化的 POD
        //       （`includes.h:722` 的注释写着 "Default: false"，但那个默认值从来没有被真正设上）。
        //       于是每个 `ParseOptions` 的这一个字节是**未初始化内存**，而这个字节恰好决定
        //       `Calculator::unlocalizeExpression` 会不会把用户写的逗号当数字分隔符**删掉**
        //       （`Calculator-parse.cc:1373-1383`：`(dot_type == 1 || po.comma_as_separator)` 成立时
        //       `str.erase(i, 1)`）。
        //
        //       设备实测的后果：`matrix(2,2,1,2,3,4)` 会被解析成 `matrix(221234)`（一个参数、
        //       五位数字），引擎随即报 "You need at least 3 argument"——而 `nCr`/`nPr`/`root`/`gcd`
        //       这些**已经上线**的多实参键走的是同一条路，用户会拿到一个静默的错值。
        //       哪一次调用会中招取决于那一块内存当时的内容，所以它看起来像「第一次调用出错」，
        //       其实是「哪个 ParseOptions 对象恰好带着脏字节」。
        //
        //       写成 `false`（库自己文档写的默认值）：逗号保留，由解析器当实参分隔符用。
        // English: **this line is not optional.** `ParseOptions::ParseOptions()`
        //          (`Calculator.cc:103`) omits `comma_as_separator` from its initializer list — it is
        //          the one POD member of the struct that stays uninitialized (`includes.h:722` calls
        //          "false" its default, but that default is never actually applied). Each
        //          `ParseOptions` therefore carries one byte of **uninitialized memory**, and that
        //          byte decides whether `Calculator::unlocalizeExpression` treats the user's commas
        //          as digit separators and **deletes** them (`Calculator-parse.cc:1373-1383`: when
        //          `(dot_type == 1 || po.comma_as_separator)` holds, `str.erase(i, 1)`).
        //
        //          Measured on a device: `matrix(2,2,1,2,3,4)` parsed as `matrix(221234)` — one
        //          argument, five digits — and the engine then reported "You need at least 3
        //          argument". The already-shipped multi-argument keys (`nCr`, `nPr`, `root`, `gcd`)
        //          travel the same path, so the user gets a silently wrong value. Which call is hit
        //          depends on what that memory happened to hold, which is why it looked like "the
        //          first call misbehaves": really it is "whichever ParseOptions object carries the
        //          dirty byte".
        //
        //          Written as `false` — the default the library documents but forgets to apply:
        //          commas survive and the parser uses them as the argument separator.
        parse_options.setComma_as_separator(false)
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
        //       带分隔符的输出到了 Dart 侧同样是静默的 null。
        // English: Digit grouping is explicitly turned off for the machine-parseable form only.
        //          Leaving it to the default would drift: `5,656.854` is just as silently null on
        //          the Dart side.
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
    /**
     * 中文：表达式里第一个引擎**读不懂**的调用名（没有就返回 null）。
     *
     *       只问「调用」（标识符紧跟左括号）：应用自己的语法里函数调用正是这个形状，而裸标识符
     *       （`x`、`i`、`to`、单位名）由引擎的变量/单位表管，不是同一回事。
     *
     * English: the first **call name** in the expression that the engine's symbol table does not know
     *          (null when there is none).
     *
     *          Only calls (an identifier immediately followed by a bracket) are asked about: that is
     *          exactly what a function call looks like in this app's syntax, while bare identifiers
     *          (`x`, `i`, `to`, unit names) belong to the engine's variable/unit tables and are a
     *          different question. `i(2)` is the deliberate case on that side: it is the implicit
     *          product `2i` (this app's own parser cannot read `i` at all, so the legacy fallback would
     *          answer `Unknown function i`), and it is allowed on purpose rather than by oversight —
     *          the check above accepts a name the engine has as a variable, not only as a function.
     */
    private fun firstCallNameUnknownToEngine(engine: Calculator, expression: String): String? {
        for (match in CALL_NAME.findAll(expression)) {
            val name = match.groupValues[1]
            // 中文：**函数 / 变量 / 单位，三者认一个就算认识。** 这里问的是「引擎能不能读懂这个
            //       名字」，不是「它是不是一个函数」——把后者当前者会误伤 `i(2)`（`i` 是引擎的
            //       变量，`i(2)` 是隐式乘法 `2i`，在本提交之前是可显示的），而 `e(2)`/`pi(2)` 同样
            //       是变量不是函数。
            //       这样放宽**不会**放过应用自己的那几个名字：`ncr`/`npr`/`fact` 在引擎里
            //       三者皆无（量过），`deg`/`rad` 是单位但不影响——应用侧那张词表更严，
            //       它在引擎被问到之前就把这几个名字拦下了（`AppEngineVocabulary.canRead`）。
            // English: **function, variable or unit — any one of the three counts as "recognised".**
            //          The question here is whether the engine can read the name, not whether the name
            //          is a function; treating the latter as the former wrongly rejects `i(2)` (`i` is
            //          one of the engine's variables and `i(2)` is the implicit product `2i`, which was
            //          displayable before this commit), and `e(2)`/`pi(2)` are variables too.
            //          Loosening it this way does **not** let the app's own names through:
            //          `ncr`/`npr`/`fact` are none of the three in the engine (measured), and
            //          `deg`/`rad` being units changes nothing — the app-side vocabulary is stricter
            //          and stops those names before the engine is asked
            //          (`AppEngineVocabulary.canRead`).
            if (engine.getFunction(name) != null) continue
            if (engine.getVariable(name) != null) continue
            if (engine.getUnit(name) != null) continue
            return name
        }
        return null
    }

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
        // 中文：结果形状的取值——Dart 侧 `EngineResultKind` 与它们逐字对应（`"conversion"` 等）。
        // English: the result-shape values — Dart's `EngineResultKind` matches them verbatim.
        const val KIND_CONVERSION = "conversion"
        const val KIND_UNIT = "unit"
        const val KIND_STRUCTURED = "structured"
        const val KIND_NUMBER = "number"
        const val KIND_ARITHMETIC = "arithmetic"

        /** 中文：函数调用的形状（标识符紧跟左括号），与应用自己的语法一致。 */
        private val CALL_NAME = Regex("([A-Za-z][A-Za-z0-9]*)\\s*\\(")

        private const val UNICODE_SIGNS_OFF = 0
        private const val UNICODE_SIGNS_ON = 1
    }
}
