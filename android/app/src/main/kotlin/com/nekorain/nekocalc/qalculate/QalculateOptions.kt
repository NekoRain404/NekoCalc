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

/**
 * 中文：一组打印选项。[fractional] 只对 `latex` 那一份有意义、[sexagesimal] 只对**度分秒那一份**
 *       有意义，理由见下面 `printOptions` 上的注释。
 * English: One set of print options. [fractional] only means anything for the `latex` render and
 *          [sexagesimal] only for **the degrees-minutes-seconds one**; see the note on
 *          `printOptions` below.
 */
internal fun printOptions(
    latex: Boolean,
    machineReadable: Boolean = false,
    fractional: Boolean = false,
    sexagesimal: Boolean = false,
): PrintOptions = PrintOptions().apply {
    // 中文：**这一格决定有理数印成小数还是印成带分数线的分数**，而它现在是两档：
    //
    //       - 默认（`fractional = false`）是 `FRACTION_DECIMAL`：`1/3` 印成 `\num{0.3333333333333333}`。
    //         这一档是**所有既有行为的基线**——`latex` 那一份从引擎接入起就一直是它，一个字节不改。
    //       - `fractional = true` 是 `FRACTION_FRACTIONAL`：同一个 `1/3` 印成 `\frac{1}{3}`，
    //         `10/4` 印成 `\frac{5}{2}`（假分数，正是 HiPER `d/c` 那一颗键的形态）。
    //
    //       **两档印的是同一个值**，因为它们是**同一个已经求过值的结构**（`QalculateEngine` 里那句
    //       `print(evaluated, …)`）的两种写法，中间没有任何一次重新求值。宿主实测（`qalc` 5.12.0，
    //       与本 AAR 同版本）：`0.333333` → `\frac{333333}{1000000}`、`0.1+0.2` → `\frac{3}{10}`、
    //       `pi/4` → `\pi / 4`、`\sqrt{2}/2` → `1 / \sqrt{2}`——**全部严格相等**，没有一条是近似。
    //       引擎在值上从不四舍五入成另一个分数，它只是换一种写法。
    //
    // English: **this one field decides whether a rational prints as a decimal or as a fraction with a
    //          bar**, and it now has two settings:
    //
    //          - the default (`fractional = false`) is `FRACTION_DECIMAL`: `1/3` prints as
    //            `\num{0.3333333333333333}`. That setting is **the baseline for every existing
    //            behaviour** — the `latex` render has used it since the engine landed, unchanged.
    //          - `fractional = true` is `FRACTION_FRACTIONAL`: the same `1/3` prints `\frac{1}{3}` and
    //            `10/4` prints `\frac{5}{2}` (an improper fraction — exactly the shape HiPER's `d/c`
    //            key is for).
    //
    //          **Both settings print the same value**, because they are two spellings of **one already
    //          evaluated structure** (the `print(evaluated, …)` call in `QalculateEngine`) with no
    //          re-evaluation in between. Measured on the host (`qalc` 5.12.0, the version this AAR
    //          bundles): `0.333333` → `\frac{333333}{1000000}`, `0.1+0.2` → `\frac{3}{10}`, `pi/4` →
    //          `\pi / 4`, `\sqrt{2}/2` → `1 / \sqrt{2}` — **every one of them exactly equal**, none of
    //          them an approximation. The engine never rounds a value into a different fraction; it
    //          only changes how it is written.
    setNumber_fraction_format(
        if (fractional) NumberFractionFormat.FRACTION_FRACTIONAL
        else NumberFractionFormat.FRACTION_DECIMAL
    )
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
    // 中文：**度分秒那一份**（HiPER 的 `DMS` 指示器、`BaseDisplayResult` 里的那一种写法）：
    //       同一个数印成 `12°34′55.92″`。它只改**写法**，不改值——与 `fractional` 对称，
    //       而且用的是**同一个已求值结构**。
    //
    //       **这一格是 `base`，不是「60 这个数」**——这两个东西在这里不是同一个字段，实测能分开：
    //       - `printops.base = BASE_SEXAGESIMAL`（= 60，`includes.h:314`）才是度分秒。库里那条分支
    //         判的就是它：`if((BASE_IS_SEXAGESIMAL(po.base) || po.base == BASE_TIME) && isReal())`
    //         （`Number.cc:11254`），随后按 60 进制分三节印，`°`/`′`/`″` 三个符号在
    //         `Number.cc:11351-11360`（unicode 开着时用真正的 `°`，关着时是字母 `o`）。
    //         `to sexagesimal` 与 qalc 的 `-s "base sexagesimal"` 设的就是这一个值
    //         （`Calculator-calculate.cc:1964`、`qalc.cc:1425`+`:1474`），宿主实测
    //         `12.5822` → `12°34′55.92″`。
    //       - 而**「把 base 设成 60」会掉进另一个字段**：qalc 的 `-b 60` 与 `-s "base 60"` 因为 60
    //         不在 `[2, 36]` 里，走的是 `v = BASE_CUSTOM` + `setCustomOutputBase(60)`
    //         （`qalc.cc:1462-1467`），印出来是**位置记数法的 60 进制**：同一个 `12.5822` 印成
    //         `C.YttC`（宿主实测）——**不是一个错值，是另一种完全不同的格式**。
    //         这正是「printOptions 会静静忽略掉你要的格式」那一类坑：值合法、调用成功、屏幕上是
    //         别的东西。所以这里写的是 `BASE_SEXAGESIMAL` 这个语义常量，而不是字面量 60 的巧合。
    //
    //       千分位在这一份上显式关掉：印出来的那一串会被 Dart 侧整体认形状（见 `MathResult.dmsText`），
    //       里面任何一个分隔符都会让整串判不出来。默认值本来就是 `DIGIT_GROUPING_NONE`
    //       （`Calculator.cc:52` 的构造函数），写出来是不让它将来漂。
    //
    //       它**不改 AppSettings.precision 的含义**：`precision` 仍然是「小数位数」，由 Dart 的
    //       `formatNumber` 管十进制那一份；度分秒这一份的位数由引擎自己的精度（16 位有效数字，
    //       见 `QalculateEngine`）决定，与前几份一样是**引擎对这个值的印法**。
    //
    // English: **the degrees-minutes-seconds spelling** (HiPER's `DMS` indicator; one of the
    //          `BaseDisplayResult` spellings): the same number printed as `12°34′55.92″`. Like
    //          `fractional` it changes the *spelling* only, never the value, and it does so from
    //          **one already evaluated structure**.
    //
    //          **This cell is `base`, not "the number 60"** — and here those are not the same field.
    //          Measured, they come apart:
    //          - `printops.base = BASE_SEXAGESIMAL` (= 60, `includes.h:314`) is the DMS one. The
    //            library's own branch tests exactly it:
    //            `if((BASE_IS_SEXAGESIMAL(po.base) || po.base == BASE_TIME) && isReal())`
    //            (`Number.cc:11254`), then prints three base-60 sections with `°`/`′`/`″`
    //            (`Number.cc:11351-11360`; a real `°` while unicode signs are on, the letter `o`
    //            otherwise). `to sexagesimal` and qalc's `-s "base sexagesimal"` set this one value
    //            (`Calculator-calculate.cc:1964`, `qalc.cc:1425` + `:1474`); measured on the host,
    //            `12.5822` → `12°34′55.92″`.
    //          - **"set the base to 60" lands in a different field.** qalc's `-b 60` and
    //            `-s "base 60"` fall outside `[2, 36]`, so they take the `v = BASE_CUSTOM` +
    //            `setCustomOutputBase(60)` route (`qalc.cc:1462-1467`) and print **positional
    //            base-60**: the same `12.5822` comes out `C.YttC` (measured on the host) — not a
    //            wrong value, a completely different format. That is the "printOptions quietly
    //            ignores the format you asked for" trap: a legal value, a successful call, and
    //            something else on screen. So what is written here is the semantic constant
    //            `BASE_SEXAGESIMAL`, not a literal 60 that happens to coincide.
    //
    //          Digit grouping is explicitly off for this render: the whole string is shape-checked on
    //          the Dart side (see `MathResult.dmsText`), and any separator inside it would make the
    //          whole thing unreadable. The default already is `DIGIT_GROUPING_NONE`
    //          (`Calculator.cc:52`'s constructor); it is written out so it cannot drift.
    //
    //          It does **not** change what `AppSettings.precision` means: `precision` stays "decimal
    //          places" and governs the decimal render through Dart's `formatNumber`, while the DMS
    //          render's digit count comes from the engine's own precision (16 significant digits, see
    //          `QalculateEngine`) — as with the other renders, this is *the engine's way of printing
    //          this value*.
    if (sexagesimal) {
        setBase(BASE_SEXAGESIMAL)
        setDigit_grouping(DigitGrouping.DIGIT_GROUPING_NONE)
    }
}

// 中文：取值来自 libqalculate/includes.h 的 UNICODE_SIGNS_* / BASE_* 匿名枚举，SWIG 没有导出成
//       Java 常量。`BASE_SEXAGESIMAL` 的字面量来源是 `includes.h:314`，而它的**含义**见上面
//       `printOptions` 那一段：同一个数是位置记数法的 60 进制、还是度分秒，靠的是这个字段的取值，
//       不是「60」这个数本身。
// English: values from the UNICODE_SIGNS_* / BASE_* anonymous enums in libqalculate/includes.h;
//          SWIG does not export them as Java constants. `BASE_SEXAGESIMAL`'s literal comes from
//          `includes.h:314`, and what it *means* is the note on `printOptions` above: whether the
//          same number prints as positional base-60 or as degrees-minutes-seconds depends on the
//          value of this field, not on the number 60.
private const val UNICODE_SIGNS_OFF = 0
private const val UNICODE_SIGNS_ON = 1
private const val BASE_SEXAGESIMAL = 60
