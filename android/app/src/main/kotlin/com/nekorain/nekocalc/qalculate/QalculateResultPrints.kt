package com.nekorain.nekocalc.qalculate

import com.jherkenhoff.libqalculate.AutomaticApproximation
import com.jherkenhoff.libqalculate.AutomaticFractionFormat
import com.jherkenhoff.libqalculate.Calculator
import com.jherkenhoff.libqalculate.EvaluationOptions
import com.jherkenhoff.libqalculate.MathStructure
import com.jherkenhoff.libqalculate.PrintOptions
import com.jherkenhoff.libqalculate.libqalculateConstants

/**
 * 中文：**同一个已求值结构的几种印法，加上两个打给引擎的小工具。** 它们原来住在
 *       `QalculateEngine.kt` 的求值函数体里（那一段是整条流水线里最长的一块），本轮按
 *       「**这一步做什么**」搬出来：选项怎么定（`QalculateOptions.kt`）、结果是什么形状
 *       （`QalculateResultKind.kt`）、**一个已经求出来的结构怎么印成应用要的那几种写法**——
 *       三块各自回答一件事。
 *
 *       **这条缝为什么在这里。** 精确形态（`latex`）、分数（`fraction`）与带分数（`mixed`）是
 *       **同一次求值的三次打印**：同一个 `evaluated` 对象、同一组 LaTeX 选项，只差 `PrintOptions`
 *       上一个字段；它们与「算了几次」「要不要回落旧解析器」无关，只与「这一份结构印成什么样」
 *       有关。`renderOneShot` 与 `drainMessages` 同理：一个只做一次一步式调用、一个只收消息队列，
 *       都不读本类的任何字段。
 *
 *       **平台通道上过去的东西一个字节都没变。** 搬的只是函数体：`evaluateOnEngine` 里那几个
 *       `val` 仍旧由同一次调用、同一组参数算出同一个字符串，`mapOf(...)` 的键与值一个字未动；
 *       唯一的改动是 `private fun` 变成同包可见的 `internal fun`（与 2026-09 那两次拆分同一做法），
 *       以及 `PRINT_TIMEOUT_MS` 从 `private` 变成 `internal`（它现在两边都要用；`TAG` 与
 *       `WORD_OPERATOR_TO` 这类**公开名字**仍旧留在伴生对象上，一个字没有动）。
 *
 * English: **the several spellings of one evaluated structure, plus two small helpers that talk to
 *          the engine.** They used to live inside `QalculateEngine.kt`'s evaluation function (the
 *          longest block in the pipeline); this round moved them along the "**what does this step
 *          do**" seam: how the options are set (`QalculateOptions.kt`), what shape a result is
 *          (`QalculateResultKind.kt`), and **how an already-evaluated structure prints into the
 *          spellings the app wants** — three blocks, each answering one thing.
 *
 *          **Why the seam is here.** The exact form (`latex`), the fraction (`fraction`) and the
 *          mixed number (`mixed`) are **three prints of one evaluation**: the same `evaluated`
 *          object, the same LaTeX options, differing in one `PrintOptions` field. They have nothing
 *          to do with "how many times did we evaluate" or "should we fall back to the legacy
 *          parser" — only with "what does this structure print as". `renderOneShot` and
 *          `drainMessages` are the same story: one makes a single one-shot call, the other drains a
 *          message queue, and neither reads a field of the class.
 *
 *          **Not one byte of what crosses the platform channel changed.** Only function bodies
 *          moved: the `val`s in `evaluateOnEngine` are still produced by the same call with the same
 *          arguments yielding the same string, and `mapOf(...)`'s keys and values did not change by
 *          one character. The only edits are `private fun` becoming package-visible `internal fun`
 *          (what the two 2026-09 splits did) and `PRINT_TIMEOUT_MS` going from `private` to
 *          `internal` (both sides need it now); **public names** such as `TAG` and
 *          `WORD_OPERATOR_TO` stay on the companion object, untouched.
 */

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
internal fun printExactLatex(engine: Calculator, evaluated: MathStructure): String =
    engine.print(
        evaluated,
        QalculateEngine.PRINT_TIMEOUT_MS,
        printOptions(latex = true),
        true,
        0,
        libqalculateConstants.TAG_TYPE_LATEX,
    )

    // 中文：**分数的写法**（HiPER 的 `d/c` 那一颗键要的东西）：同一个 `evaluated`、同一组
    //       LaTeX 选项、只把 `number_fraction_format` 从 `FRACTION_DECIMAL` 换成
    //       `FRACTION_FRACTIONAL`。它们与 `latex` 是**同一个结构的两次打印**，所以两份的值
    //       逐字节相同（理由与实测见 `printOptions` 的注释）——这不是一次新的求值，因此
    //       `rand()` 不会在这里被抽第二次。
    //
    //       为什么它不是「白烧 CPU 的第二份 `dual`」（那一份在下面被删掉了）：`dual` 是
    //       **没人读**的终端格式，而这一份是 `d/c` 那颗键的全部内容——`\frac{1}{3}` 排得出来，
    //       `\num{0.3333333333333333}` 排不出来，所以没有它 `1/3` 永远只是一个十进制数。
    //       Dart 侧读出 `''`（引擎缺席、旧解析器上屏）时那颗键就是空操作，见
    //       `MathResult.fractionTex`。
    // English: **the fraction spelling** (what HiPER's `d/c` key is for): the same `evaluated`,
    //          the same LaTeX options, with `number_fraction_format` switched from
    //          `FRACTION_DECIMAL` to `FRACTION_FRACTIONAL`. It and `latex` are **two prints of
    //          one structure**, so the two carry the identical value (the reason and the
    //          measurements are on `printOptions`) — this is not another evaluation, so `rand()`
    //          is not drawn a second time here.
    //
    //          Why it is not "a second `dual` burning CPU" (that one was deleted just below):
    //          `dual` was a **terminal format nobody read**, whereas this one *is* the whole
    //          content of the `d/c` key — `\frac{1}{3}` typesets and `\num{0.3333333333333333}`
    //          does not, so without it `1/3` can never be anything but a decimal. When Dart
    //          reads `''` (engine absent, legacy parser on screen) that key is a no-op; see
    //          `MathResult.fractionTex`.
internal fun printFractionLatex(engine: Calculator, evaluated: MathStructure): String =
    engine.print(
        evaluated,
        QalculateEngine.PRINT_TIMEOUT_MS,
        printOptions(latex = true, fractional = true),
        true,
        0,
        libqalculateConstants.TAG_TYPE_LATEX,
    )

    // 中文：**带分数的写法**（HiPER 结果格式菜单里 `Mixed number` 那一格要的东西）：
    //       同一个 `evaluated`、同一组 LaTeX 选项、只把 `number_fraction_format` 换成
    //       `FRACTION_COMBINED`——`10/4` 印成 `2 + \frac{1}{2}`、`100/7` 印成
    //       `14 + \frac{2}{7}`（宿主 qalc 5.12.0 实测，与本 AAR 同版本、同一组选项）。
    //       它是 **`PrintOptions` 上的第三个取值**，与 `latex`/`fraction` 一样是**同一个结构的
    //       又一次打印**，所以三份的值严格相等，`rand()` 也不会被抽第二次。
    //       `FRACTION_COMBINED` 就是库自己文档里那一句 "Display as an integer and a
    //       fraction (ex. 3 + 1/2)"（`includes.h:353`），与 HiPER 帮助里
    //       `solution.step.CONVERT_RESULT_TO_MIXED_NUMBER.desc` 的 "written as a whole part
    //       and a proper fraction" 是同一件事。
    //       **认不出来的形状照样丢**：`12345.6789` 在 `FRACTION_COMBINED` 下会印成
    //       `\num[...]{12345} + \frac{6789}{\num[...]{10000}}`（宿主实测），里面有 `\num`——
    //       Dart 侧那条既有的「排不出来就不算」的大门会把它整格拦掉，与非法分数写法同路。
    // English: **the mixed-number spelling** (what HiPER's `Mixed number` cell in the result
    //          format menu is for): the same `evaluated`, the same LaTeX options, with
    //          `number_fraction_format` switched to `FRACTION_COMBINED` — `10/4` prints
    //          `2 + \frac{1}{2}` and `100/7` prints `14 + \frac{2}{7}` (host `qalc` 5.12.0,
    //          the version this AAR bundles and the same options). It is a **third value of one
    //          `PrintOptions` field**, so like `latex`/`fraction` it is another print of **one
    //          structure**: all three carry strictly equal values and `rand()` is not drawn a
    //          second time. `FRACTION_COMBINED` is the library's own "Display as an integer and
    //          a fraction (ex. 3 + 1/2)" (`includes.h:353`), the same thing HiPER's help calls
    //          "written as a whole part and a proper fraction"
    //          (`solution.step.CONVERT_RESULT_TO_MIXED_NUMBER.desc`).
    //          **An unrecognised shape is dropped just the same**: under `FRACTION_COMBINED`,
    //          `12345.6789` prints as `\num[...]{12345} + \frac{6789}{\num[...]{10000}}`
    //          (host-measured) — it holds `\num`, which the existing "does it typeset" gate on
    //          the Dart side throws the whole cell out for, exactly as with a fraction spelling.
internal fun printCombinedLatex(engine: Calculator, evaluated: MathStructure): String =
    engine.print(
        evaluated,
        QalculateEngine.PRINT_TIMEOUT_MS,
        printOptions(latex = true, combined = true),
        true,
        0,
        libqalculateConstants.TAG_TYPE_LATEX,
    )

/**
 * 中文：一步式求值——**只**给带结尾 `to <命令>` 的表达式用（见调用点那段注释）。`calculateAndPrint`
 *       自己会处理结尾的 to/where 命令和进制换算，代价是它在内部重新解析、重新求值一次。
 * English: one-shot evaluation — used **only** for expressions ending in a `to <command>` (see the
 *          note at the call site). `calculateAndPrint` handles trailing to/where commands and base
 *          conversion itself; the price is that it parses and evaluates the string again.
 */
internal fun renderOneShot(
    engine: Calculator,
    expression: String,
    evaluation: EvaluationOptions,
    options: PrintOptions,
): String = engine.calculateAndPrint(
    expression,
    QalculateEngine.PRINT_TIMEOUT_MS,
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
 * 中文：libqalculate 不抛异常，警告与错误进的是消息队列。这串文本是判断
 *       「表达式为什么没算出来」的唯一线索，所以跟着结果一起带回去。
 * English: libqalculate does not throw — warnings and errors land in a message queue. That
 *          text is the only clue to why an expression did not evaluate, so it travels back
 *          alongside the result.
 */

internal fun drainMessages(engine: Calculator): String {
    val collected = mutableListOf<String>()
    var current = engine.message()
    while (current != null) {
        collected += "${current.type()}: ${current.message()}"
        current = engine.nextMessage()
    }
    engine.clearMessages()
    return collected.joinToString(" | ")
}
