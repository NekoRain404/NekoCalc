package com.nekorain.nekocalc.qalculate

import com.jherkenhoff.libqalculate.AngleUnit
import com.jherkenhoff.libqalculate.ApproximationMode
import com.jherkenhoff.libqalculate.DigitGrouping
import com.jherkenhoff.libqalculate.EvaluationOptions
import com.jherkenhoff.libqalculate.IntervalDisplay
import com.jherkenhoff.libqalculate.MixedUnitsConversion
import com.jherkenhoff.libqalculate.NumberFractionFormat
import com.jherkenhoff.libqalculate.PrintOptions

/**
 * 中文：交给引擎的两组选项，加上 `angleMode` 字符串到 [AngleUnit] 的换算。它们原来住在
 *       `QalculateEngine` 里，2026-09 那次拆分只是把这一段逐行搬出来（那个文件要回到 800 行以内）。
 *       内容一个字没改：只有 `private fun` 变成同包可见的 `internal fun`，因为
 *       `QalculateResultKind.kt` 里的 `conversionLanded` 也要用 `evaluationOptions`。
 *
 * English: The two option sets this bridge hands the engine, plus the `angleMode` string's
 *          translation into an [AngleUnit]. They used to live inside `QalculateEngine`; the
 *          2026-09 split moved them out line for line (that file had to come back under 800
 *          lines). Nothing inside them changed: only `private fun` became package-visible
 *          `internal fun`, because `conversionLanded` in `QalculateResultKind.kt` needs
 *          `evaluationOptions` too.
 */

/**
 * 中文：Dart 侧只发 `DEG` / `RAD`（来自 `AppSettings.angleMode`）。别的值按弧度处理——弧度
 *       是 `AppSettings.fallback` 的默认模式，也是 libqalculate 自己的默认角度单位。
 * English: Dart only sends `DEG` / `RAD` (from `AppSettings.angleMode`). Anything else is read
 *          as radians — `AppSettings.fallback`'s default mode, and libqalculate's own default
 *          angle unit.
 */
internal fun angleUnitFor(angleMode: String): AngleUnit =
    if (angleMode.equals("DEG", ignoreCase = true)) {
        AngleUnit.ANGLE_UNIT_DEGREES
    } else {
        AngleUnit.ANGLE_UNIT_RADIANS
    }

internal fun evaluationOptions(
    approximation: ApproximationMode,
    angleUnit: AngleUnit,
): EvaluationOptions = EvaluationOptions().apply {
    setApproximation(approximation)
    setAllow_complex(true)
    // 中文：**混合单位关掉。** 不设的话继承 C++ 默认值 `MIXED_UNITS_CONVERSION_DEFAULT`
    //       （`Calculator.cc:72` 的构造函数），于是一次换算会被拆成好几个单位相加：
    //       `5 km to mi` 印成 `3 mi + 188 yd + 2.393700787 in`（宿主 qalc 5.12.0 实测，
    //       与本 AAR 同版本）。用户要的是**一个数一个单位**。关掉之后同一串是
    //       `3.106855961186670 mi`。
    //
    //       **这一条对没有单位的结果可证是空操作**：`calculate()` 里三处
    //       `if(eo.mixed_units_conversion != MIXED_UNITS_CONVERSION_NONE)` 全在单位分支内
    //       （`Calculator-calculate.cc:3988` 的 `bool b_units = mstruct.containsType(STRUCT_UNIT, true);`
    //       之后：`:3992` 的 `if(b_units)`、`:4030` 的 `else if(b_units)`、以及
    //       `autoConvert` 开头 `:47` 的 `if(!morig.containsType(STRUCT_UNIT, true)) return;`），
    //       没有一个无单位的结果进得去。宿主实测同一批无单位输入（`2+2`、`1/0`、`sqrt(2)` …）
    //       在两种取值下逐字节相同。
    // English: **Mixed units off.** Left unset it inherits the C++ default
    //          `MIXED_UNITS_CONVERSION_DEFAULT` (the constructor at `Calculator.cc:72`), and one
    //          conversion is then split into several units added together: `5 km to mi` prints as
    //          `3 mi + 188 yd + 2.393700787 in` (host qalc 5.12.0, the same version as this AAR).
    //          What the user asked for is **one number with one unit**; with it off the same input
    //          prints `3.106855961186670 mi`.
    //
    //          **This is provably a no-op for unit-less results**: all three
    //          `if(eo.mixed_units_conversion != MIXED_UNITS_CONVERSION_NONE)` sites in
    //          `calculate()` sit inside unit branches (after
    //          `bool b_units = mstruct.containsType(STRUCT_UNIT, true);` at
    //          `Calculator-calculate.cc:3988`: the `if(b_units)` at `:3992`, the `else if(b_units)`
    //          at `:4030`, and `autoConvert`'s `if(!morig.containsType(STRUCT_UNIT, true)) return;`
    //          at `:47`), and no unit-less result can enter any of them. Measured on the host: the
    //          same battery of unit-less inputs (`2+2`, `1/0`, `sqrt(2)`, …) is byte-for-byte
    //          identical under both values.
    setMixed_units_conversion(MixedUnitsConversion.MIXED_UNITS_CONVERSION_NONE)
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

internal fun printOptions(latex: Boolean, machineReadable: Boolean = false): PrintOptions = PrintOptions().apply {
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

// 中文：取值来自 libqalculate/includes.h 的 UNICODE_SIGNS_* 匿名枚举，SWIG 没有导出成 Java 常量。
// English: values from the UNICODE_SIGNS_* anonymous enum in libqalculate/includes.h;
//          SWIG does not export them as Java constants.
private const val UNICODE_SIGNS_OFF = 0
private const val UNICODE_SIGNS_ON = 1
