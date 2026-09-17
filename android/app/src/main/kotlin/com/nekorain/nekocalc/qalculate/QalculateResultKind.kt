package com.nekorain.nekocalc.qalculate

import com.jherkenhoff.libqalculate.AngleUnit
import com.jherkenhoff.libqalculate.ApproximationMode
import com.jherkenhoff.libqalculate.AutoPostConversion
import com.jherkenhoff.libqalculate.Calculator
import com.jherkenhoff.libqalculate.MathStructure
import com.jherkenhoff.libqalculate.MixedUnitsConversion
import com.jherkenhoff.libqalculate.StructureType

/**
 * 中文：**这个结果是什么形状**，以及**这个输入引擎读不读得懂**——三个判据加一道调用名守卫。
 *       它们原来住在 `QalculateEngine` 里，2026-09 那次拆分只是逐行搬出来（内容一个字没改）：
 *       `private fun` 变成同包可见的 `internal fun`（唯一调用方是 `QalculateEngine` 的求值路径），
 *       而 `WORD_OPERATOR_TO` 仍旧留在 `QalculateEngine` 的伴生对象上（那是个公开名字，不能动），
 *       所以这里唯一新增的是一个限定符：`QalculateEngine.WORD_OPERATOR_TO`。
 *
 * English: **what shape this result is**, and **whether the engine can read this input** — three
 *          predicates and one call-name guard. They used to live inside `QalculateEngine`; the
 *          2026-09 split moved them here line for line (nothing inside them changed): `private fun`
 *          became package-visible `internal fun` (the evaluation path in `QalculateEngine` is their
 *          only caller), while `WORD_OPERATOR_TO` stays on `QalculateEngine`'s companion object
 *          (it is a public name and may not move), so the one genuinely new thing here is the
 *          qualifier: `QalculateEngine.WORD_OPERATOR_TO`.
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
internal fun firstCallNameUnknownToEngine(engine: Calculator, expression: String): String? {
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
        // 中文：**换算关键字 `to` 不是调用名，跳过它。**
        //
        //       这一条是**真机上抓到的**：`5 km to mi` 在设备上回的是
        //       `engine_error: engine_unrecognised_identifier: to`，于是整条表达式被丢掉、回落到
        //       旧解析器（它读不了单位），屏幕上是「存在无法识别的内容」——**是应用自己的守卫
        //       拒绝了应用自己的翻译器写出来的字符串**。
        //
        //       怎么发生的：`to` 是**词运算符**，翻译器把它写成 `((((5)*(km))) to (mi))`（两侧
        //       必须有空格，见 `engine_expression.dart` 的 `_wordOperator`：不带空格引擎会把它读成
        //       `t`·`o` 的乘积）。而 CALL_NAME 的正则允许名字与 `(` 之间有空白，于是 `to (mi)`
        //       看起来就是一个叫 `to` 的调用——而引擎的符号表里三者皆无，判据于是拒绝。
        //
        //       **为什么跳过它是安全的**：这一段代码问的是「表达式里有没有引擎读不懂的**调用**」，
        //       而 `to` 从来不是这个应用能写出来的调用——用户敲 `to(2)` 时，翻译层的封闭词表
        //       （`AppEngineVocabulary.engineNameFor`，表外的名字一律拒绝）在**桥看到它之前**就
        //       把整个表达式判成不可翻译，引擎根本不会被问到。所以这里唯一可能出现的 `to (`
        //       就是翻译器自己的换算写法。
        //
        //       这里只写一个单词，是因为**能够出现在调用位置上的词只有翻译器写出来的运算符**，
        //       而翻译器今天只写 `to`（`_binaryOperators` 里唯一的字母运算符）。那张表在 Dart 侧，
        //       加第二个词运算符时也要在这里加一行——Dart 侧有一条测试盯着写出去的形状（见
        //       `test/domain/unit_conversion_expression_test.dart` 里那条用**这个正则原文**扫
        //       译文的测试），它会在漏加时先红。
        //
        // English: **the conversion keyword `to` is not a call name — skip it.**
        //
        //          This was caught **on a real device**: `5 km to mi` came back as
        //          `engine_error: engine_unrecognised_identifier: to`, so the whole expression was
        //          thrown away and the legacy parser (which cannot read units) answered — the screen
        //          said "unrecognised content". **The app's own guard was rejecting the string the
        //          app's own translator wrote.**
        //
        //          How: `to` is a **word operator**, and the translation writes it as
        //          `((((5)*(km))) to (mi))` (the spaces are required — see `_wordOperator` in
        //          `engine_expression.dart`: without them the engine reads `t`·`o` as a product).
        //          CALL_NAME's pattern allows whitespace between a name and `(`, so `to (mi)` looks
        //          like a call to `to` — and the engine's symbol table has none of the three under
        //          that name, so the judgement refuses it.
        //
        //          **Why skipping it is safe**: this block asks "does the expression call anything the
        //          engine cannot read", and `to` is not a call this app can produce — when a user
        //          types `to(2)` the translation's closed table (`AppEngineVocabulary.engineNameFor`,
        //          which refuses every name outside it) judges the whole expression untranslatable
        //          **before the bridge ever sees it**, so the engine is never asked. The only `to (`
        //          that can appear here is the translator's own conversion.
        //
        //          It is a single word because **the only words that can appear in call position are
        //          the operators the translation writes**, and it writes exactly `to` today (the only
        //          alphabetic entry in `_binaryOperators`). That table lives in Dart, so a second word
        //          operator means a line here too — and a Dart test watching the emitted shape (the
        //          one in `test/domain/unit_conversion_expression_test.dart` that scans the
        //          translation with **this regex, verbatim**) goes red first if that line is missed.
        if (name == QalculateEngine.WORD_OPERATOR_TO) continue
        if (engine.getFunction(name) != null) continue
        if (engine.getVariable(name) != null) continue
        if (engine.getUnit(name) != null) continue
        return name
    }
    return null
}

/**
 * 中文：**用户要了一次换算，那一次换算发生了吗。**
 *
 *       这个判据存在的理由是实测出来的一个**静默错值**：`5 km to kg` 在引擎里
 *       **不报错、不警告、消息队列是空的**（宿主 5.12.0 按桥的调用序列实测），它把输入
 *       **原样退回来**——屏幕上于是出现 `5 km`，看起来像一个答案。`Calculator::convert` 的
 *       每一条失败路径都是 `return mstruct;`（`Calculator-convert.cc`，函数末尾那个 `return
 *   mstruct;`），它**没有给调用方任何失败信号**：没有异常、没有消息、`to_struct` 照样是
 *       我们要的那个目标单位。所以这一层必须自己问一句「换算到底发生了没有」。
 *
 *       问法就是引擎自己在 `test_convert` 附近用的那一个写法（`Calculator-convert.cc`：
 *       `mtest.divide_nocopy(new MathStructure(to_unit, NULL)); mtest.eval(eo2);
 *       if(!mtest.containsType(STRUCT_UNIT))`）：**把结果除以目标再求值**。
 *       - 两个量纲相容 ⇒ 商是一个纯数，单位全部约掉；
 *       - 量纲不相容 ⇒ 商里还剩着单位（`5 km / kg` → `5 m/g`），于是这一次换算没有发生。
 *
 *       求这一次商时**两个自动换算都关掉**（`mixed_units_conversion` 与 `auto_post_conversion`）：
 *       这一问题问的是「量纲相不相容」，而那两个开关会**自己引入单位**（把商重新最优化成别的
 *       单位），让答案取决于显示策略而不是量纲。
 *
 *       **只在结果带单位时才问。** 结果里没有单位，就不存在「换算没发生」这种情形能被误判的
 *       余地（`5 to kg` 的结果是 `5 kg`，带单位，照问；`100 to hex` 的目标不是单位，商里也不会
 *       有单位）。宿主实测的 30 个换算样本：22 个应当成功的全部判「发生了」（`5 km to mi`、
 *       `0.1 m to cm`、`5 m/s to km/h`、`1 J to N*m`、`5 N to kg*m/s^2`、`1 m^2 to cm^2` …），
 *       8 个量纲不相容的全部判「没发生」（`5 km to kg`、`5 km to s`、`5 s to m`、`5 m to m^2`、
 *       `5 J to N`、`0 C to F` …）。
 *
 * English: **A conversion was asked for — did it happen.**
 *
 *          This test exists because of a measured **silent wrong value**: in the engine
 *          `5 km to kg` **does not error, does not warn, and leaves the message queue empty**
 *          (host 5.12.0, through the bridge's call sequence); it hands the input **back
 *          unchanged**, so `5 km` appears on screen looking like an answer. Every failure path in
 *          `Calculator::convert` is `return mstruct;` (`Calculator-convert.cc`, the `return mstruct;`
 *          at the end of the function) — it gives the caller **no failure signal at all**: no
 *          exception, no message, and `to_struct` still holds the target unit we asked for. So this
 *          layer has to ask "did the conversion actually happen".
 *
 *          The question is asked exactly the way the engine asks it itself around `test_convert`
 *          (`Calculator-convert.cc`: `mtest.divide_nocopy(new MathStructure(to_unit, NULL));
 *          mtest.eval(eo2); if(!mtest.containsType(STRUCT_UNIT))`): **divide the result by the
 *          target and evaluate**.
 *          - commensurable ⇒ the quotient is a plain number, every unit cancels;
 *          - not commensurable ⇒ units survive (`5 km / kg` → `5 m/g`), so the conversion did not
 *            happen.
 *
 *          Both automatic conversions are turned **off** for that quotient
 *          (`mixed_units_conversion` and `auto_post_conversion`): the question is about
 *          commensurability, and those two switches **introduce units of their own** (re-optimising
 *          the quotient into some other unit), which would make the answer depend on display policy
 *          instead of dimensions.
 *
 *          **It is only asked when the result carries a unit.** With no unit in the result there is
 *          no room for a misjudged "the conversion did not happen" (`5 to kg` yields `5 kg`, which
 *          carries a unit, so it is asked; `100 to hex`'s target is not a unit, and no unit shows up
 *          in the quotient either). Measured on the host over 30 conversion samples: all 22 that
 *          ought to succeed are judged "happened" (`5 km to mi`, `0.1 m to cm`, `5 m/s to km/h`,
 *          `1 J to N*m`, `5 N to kg*m/s^2`, `1 m^2 to cm^2`, …) and all 8 incommensurable ones are
 *          judged "did not happen" (`5 km to kg`, `5 km to s`, `5 s to m`, `5 m to m^2`, `5 J to N`,
 *          `0 C to F`, …).
 */
internal fun conversionLanded(
    engine: Calculator,
    result: MathStructure,
    target: MathStructure,
    angleUnit: AngleUnit,
): Boolean {
    if (result.containsType(StructureType.STRUCT_UNIT, true, true, false) <= 0) return true
    val quotient = MathStructure(result)
    quotient.divide(target)
    val options = evaluationOptions(ApproximationMode.APPROXIMATION_APPROXIMATE, angleUnit).apply {
        setAuto_post_conversion(AutoPostConversion.POST_CONVERSION_NONE)
        setMixed_units_conversion(MixedUnitsConversion.MIXED_UNITS_CONVERSION_NONE)
    }
    val evaluatedQuotient = engine.calculate(quotient, options)
    return evaluatedQuotient.containsType(StructureType.STRUCT_UNIT, true, true, false) <= 0
}

/**
 * 中文：**这是一个「量」吗**——一个（或几个）数字与单位的乘积，此外什么都没有：
 *       `5 km`（数 × 单位）、`9.8 m/s^2`（数 × 单位 × 单位的负幂）、`3 m^2`（数 × 单位的幂）。
 *
 *       判据里**没有**「加法」这一支，所以「引擎算不出来的加法」自然落选：`5 km + 3 s` 是一个
 *       Addition，它既不是单位、也不是单位的幂、也不是「每一项都是数或单位」的乘积，于是它
 *       仍旧报 `unit`（不显示）。同理，任何带变量或函数的结果（`x km`、`sin(x) m`）也不是量。
 *
 *       **为什么这个判据可以放行而 `unit` 不行**（两侧都是量出来的）：
 *       - 输入是闭的：翻译层只放行应用词表里的名字与**本单位表**里的 117 个符号，别的一律拒绝
 *         （`engine_expression.dart` 的白名单 + `AppEngineVocabulary`），所以一个带单位的结果，
 *         它的单位只可能来自用户从面板插进去的那几个；
 *       - 「引擎把我们的某个名字读成单位」这条老路被量过：把应用词表的**全部**名字
 *         （49 个函数名 + 常量 + `x`/`y`/`i`）+ 单位表 117 个符号逐个问过引擎「`1 <名字>`
 *         的结果带不带单位」，**除单位表自己之外只有两个命中**：`min`（引擎读成分钟）与
 *         `inf`（读成 `'f' in`）——而这两个都到不了引擎：`min` 是应用函数、作为裸变量被词表
 *         拒绝，`inf` 由翻译写成 `infinity`。`e` 实测**不**带单位（引擎读的是欧拉常数）。
 *         量测程序与完整输出在步骤 6 修复轮的报告里。
 *
 *       所以判据是**结构性的**（「这个结果是不是一个量」），而不是一张「哪些单位可以显示」的
 *       清单——后者是开放面，本仓库已经在那上面栽过几次。
 *
 * English: **is this a "quantity"** — a product of numbers and units, and nothing else: `5 km`
 *          (a number times a unit), `9.8 m/s^2` (a number, a unit and a unit's negative power),
 *          `3 m^2` (a number and a power of a unit).
 *
 *          There is deliberately **no addition branch**, so "an addition the engine could not
 *          evaluate" fails it: `5 km + 3 s` is an Addition — not a unit, not a power of one, and
 *          not a product whose every child is a number or a unit — so it still reports `unit` (do
 *          not display). For the same reason anything carrying a variable or a function (`x km`,
 *          `sin(x) m`) is not a quantity.
 *
 *          **Why this verdict may pass where `unit` may not** (both halves measured):
 *          - the input is closed: the translation lets through only names from the app's vocabulary
 *            and the 117 symbols of the app's own unit table, refusing everything else
 *            (`engine_expression.dart`'s whitelists plus `AppEngineVocabulary`), so the units in a
 *            unit-carrying result can only be ones the user inserted from the sheet;
 *          - the old path — "the engine reads one of our names as a unit" — was measured: every name
 *            in the app vocabulary (49 function names plus the constants plus `x`/`y`/`i`) and all
 *            117 unit symbols were asked, one by one, whether `1 <name>` carries a unit, and
 *            **only two matched outside the unit table itself**: `min` (the engine reads a minute)
 *            and `inf` (read as `'f' in`) — and neither reaches the engine: `min` is an app function
 *            and is refused as a bare variable by the vocabulary, while `inf` is written `infinity`
 *            by the translation. `e` measures **no unit** (the engine reads Euler's constant). The
 *            measuring program and its full output are in the step 6 fix-round report.
 *
 *          So the test is **structural** ("is this result a quantity") rather than a list of "which
 *          units may be displayed" — the latter is an open surface, and this repository has been
 *          burned by those more than once.
 */
internal fun isPlainQuantity(m: MathStructure): Boolean = when {
    m.isNumber() -> true
    m.isUnit() -> true
    m.isPower() -> isPlainQuantity(m.base())
    m.isMultiplication() -> {
        var all = true
        var i: Long = 1
        while (all && i <= m.size()) {
            all = isPlainQuantity(m.getChild(i))
            i++
        }
        all
    }
    else -> false
}

/** 中文：函数调用的形状（标识符紧跟左括号），与应用自己的语法一致。 */
private val CALL_NAME = Regex("([A-Za-z][A-Za-z0-9]*)\\s*\\(")
