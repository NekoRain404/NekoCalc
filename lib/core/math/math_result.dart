import 'package:flutter/foundation.dart';

/// 中文：**引擎这次给出的答案是什么形状**——由原生侧用引擎自己的 `MathStructure` 判据回答
///       （`isMatrix`/`isVector`/`isNumber`/`containsType(STRUCT_UNIT…)`），以及引擎自己做没做过一次
///       换算（`to_struct`）。**没有一个字是从印出来的文本猜的。**
///
///       [`MathResult.isDisplayable`] 用它决定「这个答案配不配放到结果行上」：矩阵/复数/解集配，
///       其余不配——理由见那个 getter 上的长注释。
/// English: **What shape the engine's answer has** — answered by the native side with the engine's own
///          `MathStructure` predicates (`isMatrix`/`isVector`/`isNumber`/`containsType(STRUCT_UNIT…)`),
///          plus whether the engine performed a conversion (`to_struct`). **Not one word of it is
///          guessed from the printed text.**
///
///          [`MathResult.isDisplayable`] uses it to decide whether the answer belongs on the result
///          line: matrices, complex numbers and solution sets do, everything else does not — see the
///          long note on that getter.
enum EngineResultKind {
  /// 中文：不是引擎给的（旧解析器、占位文本、错误文案）。形状这一层对它不生效——它没有形状，
  ///       也从来不经过这道判据。
  /// English: not from the engine (the legacy parser, a placeholder, an error message). The shape
  ///          layer does not apply to it: it has no shape and never reaches this judgement.
  notFromEngine,

  /// 中文：引擎做了一次换算（`to`、`->`、`→` …）。用户明确要的，所以照收。
  /// English: the engine performed a conversion (`to`, `->`, `→`, …). The user asked for it.
  conversion,

  /// 中文：**一个量**：一个（或几个）数字与单位的乘积（`5 km`、`9.8 m/s^2`、`3 m^2`）。原生侧用
  ///       `MathStructure` 判出来的（`QalculateEngine.isPlainQuantity`）：结果里除了数字、单位、
  ///       单位的幂之外**什么都没有**——没有加法（`5 km + 3 s` 算不出来，引擎把它原样退回来，
  ///       它不是量）、没有变量、没有函数。
  ///
  ///       **这一支放行的理由与 [unit] 拒绝的理由是同一条的两面，而且两侧都量过**：
  ///       - 应用自己的语法**现在有单位了**（`CONV` 面板那块封闭表，117 个符号），所以「带单位的
  ///         答案不可能来自这个语法」那句话不再成立；
  ///       - 输入是闭的：翻译层只放行词表里的名字与单位表里的符号，于是带单位的结果里那些单位
  ///         只可能来自用户插进去的那几个；
  ///       - 「引擎把我们的某个名字读成单位」这条老路量过了：词表全部名字 + 常数 + `x`/`y`/`i`
  ///         逐个问过引擎，除单位表自己之外只有 `min` 与 `inf` 命中，而两者都到不了引擎
  ///         （`min` 作为裸变量被词表拒绝，`inf` 由翻译写成 `infinity`）。
  ///       **判据是结构性的**（「这是不是一个量」），不是「哪些单位可以显示」的清单。
  ///
  /// English: **a quantity**: a product of numbers and units (`5 km`, `9.8 m/s^2`, `3 m^2`). Judged
  ///          natively from the `MathStructure` (`QalculateEngine.isPlainQuantity`): the result holds
  ///          **nothing but** numbers, units and powers of units — no addition (`5 km + 3 s` cannot be
  ///          evaluated, the engine hands it back, and it is not a quantity), no variable, no function.
  ///
  ///          **Why this branch passes is the other face of why [unit] refuses, and both halves are
  ///          measured**:
  ///          - this app's syntax **has units now** (the closed table behind the `CONV` sheet, 117
  ///            symbols), so "an answer carrying a unit cannot have come from this syntax" no longer
  ///            holds;
  ///          - the input is closed: the translation lets through only vocabulary names and unit-table
  ///            symbols, so the units in a unit-carrying result can only be ones the user inserted;
  ///          - the old path — "the engine reads one of our names as a unit" — was measured: every
  ///            vocabulary name, constant and `x`/`y`/`i` was asked of the engine, and outside the unit
  ///            table only `min` and `inf` matched, neither of which reaches the engine (`min` is
  ///            refused as a bare variable, `inf` is written `infinity` by the translation).
  ///          **The test is structural** ("is this a quantity"), not a list of displayable units.
  quantity,

  /// 中文：带单位，但**不是一个量**：算不出来的加法（`5 km + 3 s` 被原样退回来）、带变量或函数的
  ///       结果（`x km`）、以及「引擎把我们的某个标识符读成了单位」那一类。一律不显示。
  /// English: carries a unit but is **not a quantity**: an unevaluated addition (`5 km + 3 s` handed
  ///          straight back), a result carrying a variable or a function (`x km`), and the class where
  ///          the engine read one of our identifiers as a unit. Not displayed.
  unit,

  /// 中文：**用户要了一次换算，而引擎没做。** 原生侧判出来的（`QalculateEngine.conversionLanded`）：
  ///       把结果除以目标单位再求值，商里还剩着单位就说明两者量纲不相容。
  ///
  ///       这一支存在的理由是实测：`5 km to kg` 在引擎里**不报错、不警告、消息队列是空的**，
  ///       它把输入原样退回来（`5 km`），于是屏幕上出现一个看起来像答案的错值。
  ///       `Calculator::convert` 的每条失败路径都是 `return mstruct;`，没有任何失败信号。
  ///       所以「引擎做没做这次换算」只能由原生侧自己问，而「这一支配不配显示」由
  ///       [MathResult.isDisplayable] 一处回答（与 [unit] 同一条理由的两个入口：一个是
  ///       「结果带了应用没有的单位」，一个是「用户要的换算没发生」）。
  /// English: **a conversion was asked for and the engine did not perform it.** Judged on the native
  ///          side (`QalculateEngine.conversionLanded`): divide the result by the target unit and
  ///          evaluate it — if units survive the quotient, the two are not commensurable.
  ///
  ///          Measured reason for this branch: in the engine `5 km to kg` **does not error, does not
  ///          warn and leaves the message queue empty**; it hands the input back unchanged (`5 km`),
  ///          which puts a wrong value that looks like an answer on the screen. Every failure path in
  ///          `Calculator::convert` is `return mstruct;` and carries no failure signal at all. So "did
  ///          the engine do this conversion" can only be asked natively, while "may this branch be
  ///          displayed" is answered in one place ([MathResult.isDisplayable]) — two entrances to the
  ///          same reason as [unit]: "the result carries a unit this app does not have" and "the
  ///          conversion the user asked for did not happen".
  unitMismatch,

  /// 中文：矩阵 / 向量（解集也是向量）。
  /// English: a matrix or a vector (a solution set is a vector).
  structured,

  /// 中文：引擎的 Number——复数走这一支（实数在 Dart 侧已经是十进制了）。
  /// English: the engine's Number — complex numbers land here (a real number is already a decimal by
  ///          the time Dart sees it).
  number,

  /// 中文：**一个符号式子**——结果里有引擎的变量符号（`STRUCT_VARIABLE`），而且引擎这一次
  ///       **一句话都没说**（消息队列是空的）。两条都由原生侧用引擎自己的判据回答
  ///       （`QalculateEngine.KIND_SYMBOLIC`），一个字都没从印出来的文本上猜。
  ///
  ///       **它与 [arithmetic] 的差别就是「引擎算没算」。** 两支都是「其余一切」（乘积、幂、
  ///       函数调用、符号和），但 [arithmetic] 里还住着引擎**做不了**那个运算、把它**原样退回来**
  ///       的情形：`1/0`、`x/0`、`0/0`、`2/0`、`0^(-1)`、`1/(x-x)`（实测都排一句
  ///       `Division by zero.`），以及 `0^0`（实测队列是空的，但结果里没有变量）。引擎把运算退回
  ///       来时**不抛异常、不返回失败**，所以「它做没做」只能由这两条引擎自己的事实回答——这正是
  ///       它与 [conversion]／[unitMismatch] 同一类的理由：不由 Dart 猜。
  ///
  ///       **放行的理由，与 [arithmetic] 拒绝的理由是同一条的两面。** [arithmetic] 拒绝是因为
  ///       「应用自己的语言表达得了这些，所以旧解析器才是权威：它要么给出一个值（那就它说了算），
  ///       要么明确拒绝」。而那句话说不动一个**含变量的答案**：应用自己的语法**根本没有变量**
  ///       （量过：`ExpressionParser` 里没有变量绑定，`x` 报「Function x needs (」，`2x` 报
  ///       「Unexpected token at 1」）——它对这类输入的「拒绝」说的是语法，不是数学。于是引擎
  ///       这一份就是这一行唯一的答案。
  ///
  ///       **它不承诺这个结果配得上屏幕。** 两道应用侧的判据仍然拦在前面，都不在这支里：
  ///       - `_selectEngineResult` 先问 [AppEngineVocabulary.canRead]（词表说引擎读不了这个输入时，
  ///         答案一律不算）；
  ///       - 再问**应用自己的语言表达不表达得了这个输入**：表达得了时，旧解析器依旧是权威，
  ///         这一次的答案不算（见 `_selectEngineResult`）。实测的实例是 `pi!`：引擎把它读成
  ///         `factorial(pi)`（`pi` 在引擎里是一个变量，量过——它的**精确**印法是
  ///         `\operatorname{factorial}(\pi )`，十进制那一份是 `factorial(3.141592653589793)`，
  ///         因为十进制走的是近似求值），于是这一支判 `symbolic`；而应用自己的语言答得了
  ///         `pi!`（`pi` 是它的常量、`!` 是它的后缀），它给的是一句错误——屏幕上因此是那句话，
  ///         放宽前后一字未变。（`pi` 单独一个**不**在这里：它的十进制形态是有限的
  ///         `3.141592653589793`，由 tier 2 直接采用。）
  ///
  ///       （[quantity] 与 [unit] 那两支的划分是同一个思路的另一半：那边判的是「带单位的结果
  ///       是不是一个量」，这里判的是「不带单位的结果是不是一个符号式子」。）
  /// English: **a symbolic form** — the result holds one of the engine's variable symbols
  ///          (`STRUCT_VARIABLE`) and the engine said **not one word** this time (its message queue
  ///          is empty). Both are answered natively from the engine's own predicates
  ///          (`QalculateEngine.KIND_SYMBOLIC`); not a word is guessed from the printed text.
  ///
  ///          **Its difference from [arithmetic] is exactly "did the engine compute".** Both are
  ///          "everything else" (products, powers, calls, symbolic sums), but [arithmetic] also holds
  ///          the case where the engine **could not** do the operation and **handed it back
  ///          unchanged**: `1/0`, `x/0`, `0/0`, `2/0`, `0^(-1)`, `1/(x-x)` (all measured queueing
  ///          `Division by zero.`) and `0^0` (measured silent, but its result holds no variable). The
  ///          engine neither throws nor signals failure when it hands an operation back, so "did it do
  ///          it" can only be answered by these two facts of its own — which is why this branch has
  ///          the same kind of reason as [conversion] / [unitMismatch]: nothing is guessed in Dart.
  ///
  ///          **Why it passes is the other face of why [arithmetic] refuses.** [arithmetic] refuses
  ///          because "this app's language can express these, so the legacy parser is the authority:
  ///          it either produces a value (and that value wins) or refuses". That sentence has no hold
  ///          on an answer **containing a variable**: this app's own syntax **has no variables at all**
  ///          (measured: `ExpressionParser` binds none — `x` reports "Function x needs (" and `2x`
  ///          "Unexpected token at 1"), so its "refusal" for such an input is a statement about the
  ///          syntax, not about the mathematics. The engine's answer is then the only answer for that
  ///          line.
  ///
  ///          **It promises nothing about the screen.** Two app-side judgements still stand in front
  ///          of it, neither of them in this branch:
  ///          - `_selectEngineResult` asks [AppEngineVocabulary.canRead] first (when the vocabulary
  ///            says the engine cannot read this input, no answer of its counts);
  ///          - then it asks whether **this app's own language can express the input**: when it can,
  ///            the legacy parser is still the authority and this answer does not count (see
  ///            `_selectEngineResult`). The measured instance is `pi!`: the engine reads it as
  ///            `factorial(pi)` (`pi` is one of its variables, measured — its **exact** print is
  ///            `\operatorname{factorial}(\pi )` and its decimal half is
  ///            `factorial(3.141592653589793)`, since the decimal goes through the approximating
  ///            evaluation), so it lands here; while this app's own language *can* answer `pi!`
  ///            (`pi` is one of its constants and `!` one of its postfixes) and answers it with an
  ///            error — which is what the screen shows, unchanged by the relaxation. (`pi` on its own
  ///            is **not** here: its decimal form is the finite `3.141592653589793`, taken directly
  ///            by tier 2.)
  ///
  ///          (The [quantity] / [unit] split is the other half of the same idea: that one judges
  ///          "is a unit-carrying result a quantity", this one judges "is a unit-free result a
  ///          symbolic form".)
  symbolic,

  /// 中文：其余一切：乘积、幂、函数调用、符号和。这些**应用自己的语言表达得了**，所以旧解析器才是权威。
  /// English: everything else: products, powers, calls, symbolic sums. **This app's language can
  ///          express these**, so the legacy parser is the authority for them.
  arithmetic,
}

/// 中文：一次求值的结果，把「给人看的形态」「给排版看的形态」「给机器算的形态」分开保存。
/// English: One evaluation result, keeping the human-readable form, the typeset form and the
///          machine-parseable form apart.
///
/// 中文：这个类型存在的唯一理由是**消除静默失败**。一旦精确引擎接入，[displayText] 会是 `4√2`
///       这样的精确形式，对它做 `double.tryParse` 只会静默返回 null——`Ans`、`last`、记忆寄存器
///       和「继续使用」于是悄悄失效，没有任何异常。把十进制形态单独存一份，数值消费者就永远不必
///       去解析人类可读的那一份：读 [decimalText]，读不到就当作「这一次没有十进制形态」。
/// English: This type exists to remove a silent failure. Once the exact engine lands, [displayText]
///          is an exact form such as `4√2`, and `double.tryParse` over it returns null without
///          complaining — `Ans`, `last`, the memory register and continue-with-result then stop
///          working with nothing thrown. Keeping the decimal form separate means numeric consumers
///          never parse the human-readable one: they read [decimalText], and an empty one means
///          "this evaluation has no decimal form", not "parse the display text instead".
///
/// 中文：三者互不替代。分不清时记住这条：**[decimalText] 是唯一允许被解析成数字的字段**。
/// English: The three do not substitute for one another. When in doubt remember this: [decimalText]
///          is the only field that may ever be parsed into a number.
@immutable
class MathResult {
  const MathResult({
    required this.displayText,
    this.displayTex = '',
    this.fractionTex = '',
    this.mixedTex = '',
    this.dmsText = '',
    this.decimalText = '',
    this.quantityText = '',
    this.resultKind = EngineResultKind.notFromEngine,
  });

  /// 中文：旧求值器的产物——显示文本本身就是十进制文本（去掉千分位之后），并且没有 LaTeX。
  ///       引擎接入之前，控制器的每一次求值都走这里，因此行为与拆分之前逐字节一致。
  /// English: What the legacy evaluator produces — the display text *is* the decimal text once the
  ///          grouping separators are gone, and there is no LaTeX. Until the engine is wired in
  ///          every controller evaluation goes through here, so behaviour is byte-for-byte what it
  ///          was before the split.
  factory MathResult.legacy(String displayText) {
    return MathResult(
      displayText: displayText,
      decimalText: decimalTextOf(displayText),
    );
  }

  /// 中文：零值——控制器的初始状态、清空之后的结果，以及空表达式的结果。
  /// English: The zero result — the controller's initial state, what `clear()` leaves behind, and
  ///          the result of an empty expression.
  static const MathResult zero = MathResult(displayText: '0', decimalText: '0');

  /// 中文：等待输入的占位结果，`evaluate()` 失败时用它，不带十进制形态。
  /// English: The "waiting for input" placeholder, used when `evaluate()` fails; it carries no
  ///          decimal form on purpose.
  static const MathResult pending = MathResult(displayText: '等待输入');

  /// 中文：给人读的文本（`4√2` 或 `5.6568542`）。结果行、复制、笔记、历史都读它。
  /// English: What a human reads (`4√2`, or `5.6568542`). The result line, copy, notes and history
  ///          all read this.
  final String displayText;

  /// 中文：LaTeX 形态，不含 `$` 定界符；引擎缺席时为空串。**不要**把它喂给任何数值消费者。
  /// English: The LaTeX form without `$` delimiters; empty while no engine is involved. Never feed
  ///          it to a numeric consumer.
  final String displayTex;

  /// 中文：**同一个值的分数写法**（HiPER 的 `d/c` 那一颗键要的东西），不含 `$` 定界符。
  ///
  ///       它与 [displayTex] 是**同一个已求值结构的两次打印**，唯一的差别是
  ///       `number_fraction_format`（`FRACTION_FRACTIONAL` 对 `FRACTION_DECIMAL`），所以两者的值
  ///       严格相等——理由与实测在 `printOptions` 上。实测的差别：`1/3` 是 `\frac{1}{3}` 对
  ///       `\num{0.3333333333333333}`，`10/4` 是 `\frac{5}{2}` 对 `2.5`；无理数两者相同
  ///       （`\sqrt{8}` 都是 `2\times \sqrt{2}`）。
  ///
  ///       空串表示「这一次没有分数写法」——引擎缺席、旧解析器上屏、或原生侧版本不匹配都会是空串。
  ///       **它不是错误**，调用方照常工作：那一颗键于是是空操作，而不是去猜一个分数。
  ///       与 [displayTex] 一样，**它绝不能被喂给任何数值消费者**。
  /// English: **the fraction spelling of the same value** (what HiPER's `d/c` key is for), without
  ///          `$` delimiters.
  ///
  ///          It and [displayTex] are **two prints of one evaluated structure**, differing only in
  ///          `number_fraction_format` (`FRACTION_FRACTIONAL` against `FRACTION_DECIMAL`), so the two
  ///          carry strictly equal values — the reason and the measurements are on `printOptions`.
  ///          Measured difference: `1/3` is `\frac{1}{3}` against `\num{0.3333333333333333}`, `10/4`
  ///          is `\frac{5}{2}` against `2.5`; for an irrational the two agree (`\sqrt{8}` is
  ///          `2\times \sqrt{2}` either way).
  ///
  ///          An empty string means "no fraction spelling this time" — an absent engine, the legacy
  ///          parser on screen, or a native side that does not send the field. **It is not an
  ///          error**, and callers keep working: that key is then a no-op rather than inventing a
  ///          fraction. Like [displayTex] it must **never** be fed to a numeric consumer.
  final String fractionTex;

  /// 中文：**同一个值的带分数写法**（HiPER 结果格式菜单里 `Mixed number` 那一格），不含 `$` 定界符。
  ///
  ///       它与 [displayTex]、[fractionTex] 是**同一个已求值结构的三次打印**，唯一的差别是
  ///       `number_fraction_format` 取了第三个值（`FRACTION_COMBINED`，库自己的注释：
  ///       "Display as an integer and a fraction (ex. 3 + 1/2)"），所以三者的值严格相等——理由与实测
  ///       在 `printOptions` 上。实测的差别：`10/4` 是 `2 + \frac{1}{2}`（假分数那一份是
  ///       `\frac{5}{2}`）、`100/7` 是 `14 + \frac{2}{7}`、`1/3` 三者同值 `\frac{1}{3}`。
  ///       **注意引擎把它印成一个加法**（`2 + \frac{1}{2}`），不是 HiPER 那种并排的 `2 1/2`：
  ///       值一样、意思一样（一个整数部分加一个真分数），写法不同。
  ///
  ///       空串表示「这一次没有带分数写法」——引擎缺席、旧解析器上屏、原生侧版本不匹配、或者这一份
  ///       结果在 `FRACTION_COMBINED` 下印出来的是排不出来的 `\num{…}`（`12345.6789` 实测就是）。
  ///       **它不是错误**，调用方照常工作：那一格于是不存在，而不是去猜一个。
  ///       与 [displayTex] 一样，**它绝不能被喂给任何数值消费者**。
  /// English: **the same value's mixed-number spelling** (HiPER's `Mixed number` cell in the result
  ///          format menu), without `$` delimiters.
  ///
  ///          It and [displayTex]/[fractionTex] are **three prints of one evaluated structure**,
  ///          differing only in a third value of `number_fraction_format` (`FRACTION_COMBINED`; the
  ///          library's own note reads "Display as an integer and a fraction (ex. 3 + 1/2)"), so all
  ///          three carry strictly equal values — the reason and the measurements are on
  ///          `printOptions`. Measured differences: `10/4` is `2 + \frac{1}{2}` (the improper-fraction
  ///          print is `\frac{5}{2}`), `100/7` is `14 + \frac{2}{7}`, and `1/3` is `\frac{1}{3}` in all
  ///          three. **Note the engine prints it as an addition** (`2 + \frac{1}{2}`), not as HiPER's
  ///          juxtaposed `2 1/2`: the value is the same and so is the meaning (a whole part and a
  ///          proper fraction), the spelling is not.
  ///
  ///          An empty string means "no mixed-number spelling this time" — an absent engine, the
  ///          legacy parser on screen, a native side that does not send the field, or a result whose
  ///          `FRACTION_COMBINED` print is an untypesettable `\num{…}` (`12345.6789` is the measured
  ///          case). **It is not an error**, and callers keep working: the cell then does not exist
  ///          rather than one being guessed. Like [displayTex] it must **never** be fed to a numeric
  ///          consumer.
  final String mixedTex;

  /// 中文：**同一个值的度分秒写法**（HiPER 的 `DMS` 那一格：`12°34′55.92″`），**不是 TeX**——
  ///       它是引擎终端印法的原文，`°`/`′`/`″` 是真字符，不含 `$` 定界符，也不含任何排版记号。
  ///
  ///       它与 [decimalText] 描述的是**同一个数**：两份打印来自**同一个 `approximated` 结构**
  ///       （见 `QalculateEngine`），所以度分秒那一串的位数虽多，值却逐位等于十进制那一份。
  ///       它**必须**来自近似结构，这是实测的：精确结构上度数分秒会把**每个数**都印成度分秒
  ///       （`sqrt(8)` → `2°0′0″ × √(2°0′0″)`），只有近似结构上才是「一个实数的度分秒写法」。
  ///
  ///       它与 [fractionTex] 一样是**写法**、不是值，所以：空串表示「这一次没有度分秒写法」
  ///       （引擎缺席、旧解析器上屏、换算那一支、原生侧版本不匹配），**不是错误**——调用方照常
  ///       工作，那一颗键于是是空操作。**它绝不能被喂给任何数值消费者**：这一串里没有一个是
  ///       十进制数，`double.tryParse` 读它返回 null 而不抛异常，正是这个类型要消灭的那类静默失败。
  ///
  ///       认形状（`°`/`′`/`″` 三段、段内是十进制数）这一步不在这里做：它属于「这一份结果画不画得
  ///       出度分秒那一格」，只有一处判断，在 `ResultPresentation`。这里只负责把引擎的原文带上来。
  /// English: **the same value's degrees-minutes-seconds spelling** (HiPER's `DMS` cell:
  ///          `12°34′55.92″`), and **not TeX** — it is the engine's terminal render verbatim, with
  ///          real `°`/`′`/`″` characters, no `$` delimiters and no typesetting markup.
  ///
  ///          It describes **the same number** as [decimalText]: the two renders come from the **same
  ///          `approximated` structure** (see `QalculateEngine`), so however many digits the DMS
  ///          string carries, its value equals the decimal one digit for digit. It **has to** come
  ///          from the approximated structure, and that is measured: on the exact structure a DMS
  ///          render turns **every** number into degrees-minutes-seconds
  ///          (`sqrt(8)` → `2°0′0″ × √(2°0′0″)`), and only on the approximated one is it "the DMS
  ///          spelling of one real number".
  ///
  ///          Like [fractionTex] it is a **spelling**, not a value, so: an empty string means "no DMS
  ///          spelling this time" (an absent engine, the legacy parser on screen, the conversion
  ///          branch, a native side that does not send the field) and **is not an error** — callers
  ///          keep working and that key is a no-op. **It must never be fed to a numeric consumer**:
  ///          there is no decimal number in this string, `double.tryParse` returns null without
  ///          throwing, and that silent failure is the class this type exists to delete.
  ///
  ///          The shape check (`°`/`′`/`″` in three sections, decimal numbers inside them) is not
  ///          done here: it belongs to "can this result draw the DMS cell at all", which is judged in
  ///          exactly one place, `ResultPresentation`. This field only carries the engine's text up.
  final String dmsText;

  /// 中文：引擎这次答案的形状，以及它做没做过换算——原生侧用引擎自己的判据填。旧解析器与
  ///       占位文本是 [EngineResultKind.notFromEngine]。**只有 [isDisplayable] 读它**：它是
  ///       「能不能显示」这道判据的输入之一，不是给别的消费者看的。
  /// English: the shape of the engine's answer, and whether it performed a conversion — filled in by
  ///          the native side from the engine's own predicates. The legacy parser and placeholders use
  ///          [EngineResultKind.notFromEngine]. **Only [isDisplayable] reads it**: it is one of the
  ///          inputs to the "may this be displayed" judgement, not something other consumers look at.
  final EngineResultKind resultKind;

  /// 中文：十进制形态——**唯一**允许被数值消费者解析的形态（Ans/last、记忆、继续使用、历史去重、
  ///       粘贴回填）。空串表示「没有可解析的十进制表示」，这不是错误，调用方必须照常工作。
  /// English: The decimal form — the *only* one numeric consumers may parse (Ans/last, memory,
  ///          continue-with-result, history de-duplication, paste round-trip). An empty string means
  ///          "no parseable decimal form"; it is not an error and callers must keep working.
  final String decimalText;

  /// 中文：**带单位结果的引擎原文**（数字 + 单位，**未取整**的那一份）——显示文本按用户的小数位数
  ///       取整（`quantity_display.dart`）之后仍然留在手上的那一份。[reusableText] 的第二个来源，
  ///       别的消费者一个都不读它。为什么非有它不可（[displayText] 是画出来的、[decimalText] 对一个量
  ///       必须是空串）写在那个文件里，这里只写契约：
  ///
  ///       空串 = 「这一次没有这一份原文」（普通数值、矩阵、复数、符号式、错误文案、旧解析器的结果），
  ///       **不是错误**。与 [decimalText] 同一条铁律：**绝不能喂给数值消费者**——它带着单位，
  ///       `double.tryParse` 读它返回 null 而不抛异常，正是这个类型要消灭的那类静默失败。
  /// English: **the engine's own text of a unit-carrying result** (number plus unit, the **unrounded**
  ///          one) — what is still in hand after the display text was rounded to the user's decimal
  ///          places (`quantity_display.dart`). [reusableText]'s second source; no other consumer reads
  ///          it. Why it has to exist ([displayText] is what is drawn, [decimalText] must stay empty for
  ///          a quantity) is written in that file; the contract is here:
  ///
  ///          An empty string means "no such text this time" (ordinary numbers, matrices, complex
  ///          numbers, symbolic forms, error messages, the legacy parser's results) and **is not an
  ///          error**. Same iron rule as [decimalText]'s: **never feed it to a numeric consumer** — it
  ///          carries a unit, `double.tryParse` returns null without throwing, and that silent failure
  ///          is the class this type exists to delete.
  final String quantityText;

  /// 中文：从一段显示文本里提取十进制形态：去掉千分位与首尾空白，`double.tryParse` 不接受就返回
  ///       空串。旧求值器的显示文本正是从这里变成十进制形态的，也是全应用唯一一处「把显示文本当
  ///       数字看」的地方。
  /// English: Extract the decimal form from a piece of display text: strip grouping separators and
  ///          surrounding whitespace, and return an empty string when `double.tryParse` rejects it.
  ///          This is how the legacy evaluator's display text becomes a decimal form, and the one
  ///          place in the app where display text is looked at as a number at all.
  static String decimalTextOf(String value) {
    final normalized = value.replaceAll(',', '').trim();
    if (double.tryParse(normalized) == null) return '';
    return normalized;
  }

  /// 中文：十进制形态解析出的数值；**放不进一个有限 double 时为 null**（没有十进制形态时同样是
  ///       null）。调用方**不得**退回 [displayText]，拿到 null 时要显式处理「这一次存不下」，
  ///       而不是拿一个错值继续算。
  ///
  ///       这里不能只看 `double` 的 `isFinite`，因为 `double.tryParse` 在量程两端都会骗人：
  ///
  ///       - **溢出**：`1e602` 是一个完全正确的有限结果（精确引擎正是为这类结果而存在），
  ///         但 `double.tryParse` 返回 `Infinity`。把它当「不是有限数」就等于扔掉引擎的正确答案。
  ///       - **下溢**：`1e-602` 返回 **`0.0`**，`isFinite` 为真——于是 `Ans`、`last`、记忆寄存器
  ///         全都拿到 0。不抛异常、不报错，给一个错值。这是最坏的一种。
  ///
  ///       所以下溢也在字符串层面挡掉：解析出 0、但数字部分明明有非零数字，就不是 0，是「存不下」。
  ///       要问「引擎给的是不是一个有限数」，用 [hasFiniteDecimal]（字符串层面），不要用这里。
  /// English: The value behind the decimal form, or null when it does not fit in a finite double
  ///          (and also null when there is no decimal form). Callers must *not* fall back to
  ///          [displayText]; a null means "this one cannot be stored", which callers handle
  ///          explicitly rather than continuing with a wrong value.
  ///
  ///          The `double`'s own `isFinite` cannot be the only test, because `double.tryParse` lies
  ///          at both ends of the range:
  ///
  ///          - **Overflow**: `1e602` is a perfectly correct finite result (an exact engine exists
  ///            precisely for results like it), yet `double.tryParse` returns `Infinity`. Treating
  ///            that as "not finite" throws the engine's right answer away.
  ///          - **Underflow**: `1e-602` returns **`0.0`** and `isFinite` is true — so `Ans`, `last`
  ///            and the memory register all take 0. Nothing throws, nothing complains, and the
  ///            value is wrong. That is the worst of the two.
  ///
  ///          Underflow is therefore caught at the string level as well: a parsed 0 from text whose
  ///          digits contain a non-zero digit is not zero, it is "cannot be stored". To ask whether
  ///          the engine produced a finite number, use [hasFiniteDecimal] — that one is answered at
  ///          the string level, not here.
  double? get decimalValue => decimalValueOf(decimalText);

  /// 中文：**一段十进制文本 → 一个可用的 double**，放不下时给 null。这是全应用唯一的实现，
  ///       提交路径、粘贴路径与任何要 double 的消费者都从这里过——写第二份的话，两份迟早会漂移
  ///       （这正是修复轮 2 要收的那个尾：守卫在提交路径上修好了，消费者的表达式分支却没有）。
  ///
  ///       判定按上面的顺序：空 → null；不是数 → null；不是有限（溢出成 `Infinity`、`NaN`）→ null；
  ///       解析出 0 而数字部分有非零数字（下溢）→ null。**它绝不返回 `Infinity`，也绝不返回一个
  ///       静默下溢的 0。**
  /// English: **A piece of decimal text into a usable double**, or null when it does not fit. This is
  ///          the app's single implementation: the submit path, the paste path and any consumer that
  ///          needs a double all come through here — a second copy would eventually drift, which is
  ///          exactly the tail fix round 2 is collecting (the guard was fixed on the submit path
  ///          while a consumer's expression branch kept the old rule).
  ///
  ///          The order is as above: empty → null; not a number → null; not finite (overflowed to
  ///          `Infinity`, or `NaN`) → null; parsed 0 whose significand contains a non-zero digit
  ///          (underflow) → null. It **never returns `Infinity`, and never a silently underflowed
  ///          0**.
  static double? decimalValueOf(String decimalText) {
    if (decimalText.trim().isEmpty) return null;
    final parsed = double.tryParse(decimalText);
    if (parsed == null) return null;
    final value = usableDouble(parsed);
    if (value == null) return null;
    if (value == 0 && _hasNonZeroDigit(decimalText)) return null;
    return value;
  }

  /// 中文：**可显示**——引擎这一次给出的东西能不能放到结果行上。它与 [hasFiniteDecimal] 是**两个
  ///       判据，不是同一个**：
  ///
  ///       - [hasFiniteDecimal] 问的是「**能不能当数字用**」（`Ans`/`last`/记忆/继续使用/历史去重/
  ///         粘贴回填要的是这个）；
  ///       - [isDisplayable] 问的是「**能不能显示**」：引擎的答案要么是十进制（`ln(0)` 那种
  ///         非有限字面量除外），要么是**应用自己的语言表达不了的那种值**。
  ///
  ///       判据分两层，第一层看**文本**（[textIsDisplayable]：非有限字面量不算数），第二层看**形状**
  ///       （[resultKind]，由引擎自己的判据回答）。第二层的每一支各有理由，合起来是**穷尽**的
  ///       ——它是引擎结果空间的一个划分，不是一张举例清单：
  ///
  ///       - [EngineResultKind.structured]（矩阵 / 向量 / 解集）与 [EngineResultKind.number]
  ///         （复数）：**类型本身**是应用的语言表达不了的。这正是这一步放宽这道判据的理由——
  ///         矩阵、复数、解集在放宽之前被整条丢掉。
  ///       - [EngineResultKind.conversion]：用户明确要求了一次换算，引擎自己确认做过了
  ///         （`to_struct`）。带单位但用户要的，收。
  ///       - [EngineResultKind.quantity]：**一个量**（数 × 单位）。放行的理由与 [EngineResultKind.unit]
  ///         拒绝的理由是同一条的两面，且两侧都量过（见那一支的注释）：应用自己的语法**现在有单位
  ///         了**，而输入是闭的，所以一个量里的单位只可能来自用户从面板插进去的那几个。
  ///       - [EngineResultKind.unit]：**带单位但不是一个量**——算不出来的加法（`5 km + 3 s` 被原样
  ///         退回来）、带变量或函数的结果（`x km`）。
  ///         曾经它还是「应用自己的语法里没有单位名」那条理由的落点：那时的语法只认两个单位式后缀：
  ///         `°`（`ExpressionParser` 把它改写成 `rad(...)`，`expression_parser.dart:487`）与
  ///         `%`（百分号，同样是固定算术，`:599`），两者都由旧解析器按自己的算术处理。
  ///         所以一个带**具名单位**的引擎答案不可能来自这个语法表达得出的东西——除非用户用
  ///         `to`/`->` 明确要求了换算，而那一条由上面的 [EngineResultKind.conversion] 接住。
  ///         剩下的只可能是「引擎把我们的某个标识符读成了单位」（`fact(-1)` → `-10 aa*t`，
  ///         `ncr(5,10)` → 一串 `n'r' km/us`），那正是「把垃圾读成合理的形状」。
  ///       - [EngineResultKind.unitMismatch]：用户要了一次换算，而引擎**没做**——它把输入原样退回
  ///         来（`5 km to kg` 给 `5 km`，实测无消息、无异常）。拒绝它的理由与 [EngineResultKind.unit]
  ///         是同一条：屏幕上的那个文本不是这次求值的答案。**它不能并进
  ///         [EngineResultKind.conversion]**：那一个是「用户要的换算发生了」，这一个是「没发生」，
  ///         而两者在引擎那边**都是 `to_struct` 非空**（换算失败时目标单位照样被写进 `to_struct`），
  ///         只有在原生侧问过「结果除以目标之后还剩不剩单位」才分得开。
  ///       - [EngineResultKind.symbolic]：**一个符号式子**（结果里有变量，且引擎没话要说）。放行的
  ///         理由与 [EngineResultKind.arithmetic] 拒绝的理由是同一条的两面，见那一支的注释：
  ///         应用的语法里**没有变量**，所以旧解析器对一个含变量的输入没有发言权。它**不是**
  ///         「引擎没算」那一类——引擎做不了的运算由消息队列与「结果里有没有变量」两条引擎自己的
  ///         事实挡在 [EngineResultKind.arithmetic] 里（`1/0`、`x/0`、`0^0`）。
  ///       - [EngineResultKind.arithmetic]：乘积、幂、函数调用、符号和——**应用的语言表达得了**，
  ///         所以旧解析器才是权威：它要么给出一个值（那就它说了算），要么明确拒绝，而它的拒绝
  ///         就是这个应用对这一行的答案。`1 / 0`、`mod(2; 0)`、`root(2; 0)`、`x / 0`、`0^0`
  ///         全落在这一支。
  ///         （`2x`、`x^2 + 1` 曾经也在这里，`sin(x rad)` 也在——前两者现在是
  ///         [EngineResultKind.symbolic]；`sin(x rad)` 仍旧不显示，但**不在**这一支：引擎把
  ///         `rad` 当一个单位，它的种类是 [EngineResultKind.unit]，见那一支。）
  ///       - [EngineResultKind.notFromEngine]：旧解析器与占位文本，形状这一层对它们不适用。
  ///
  ///       为什么「带单位」压过形状：`ncr(5,10)` 的结果**是**一个向量，只是每一项都带单位——
  ///       按形状它就漏进去了。
  ///
  ///       **这条规则顶掉了一条旧的举例清单**（它只匹配「数字 运算符 数字」，于是 `i/0`、
  ///       `(1+i)/0`、`matrix(...)/0`、`2 mod 0`、`root(2,0)`、`x/0` 全都漏了过去——而 `i` 与
  ///       `MTRX` 正是那一步点亮的键）。新规则不看算式长什么样，只看**引擎这次给出的是哪一类值**。
  /// English: **Displayable** — whether what the engine produced this time may go on the result line.
  ///          A **second judgement, not the same one** as [hasFiniteDecimal]:
  ///
  ///          - [hasFiniteDecimal] asks "**can this be used as a number**" (what `Ans`/`last`/memory/
  ///            continue-with/history de-duplication/paste round-trip need);
  ///          - [isDisplayable] asks "**can this be shown**": the engine's answer is either a decimal
  ///            (bar the non-finite literals like `ln(0)`) or **a value this app's own language cannot
  ///            express**.
  ///
  ///          Two layers: the first reads the **text** ([textIsDisplayable] — a non-finite literal
  ///          does not count), the second reads the **shape** ([resultKind], answered by the engine's
  ///          own predicates). The four branches of the second layer each have a reason, and together
  ///          they are **exhaustive** — it is a partition of the engine's result space, not a list of
  ///          examples:
  ///
  ///          - [EngineResultKind.structured] (matrices / vectors / solution sets) and
  ///            [EngineResultKind.number] (complex numbers): their **type itself** cannot be expressed
  ///            in this app's language. That is exactly why this judgement was relaxed — matrices,
  ///            complex numbers and solution sets were being thrown away whole.
  ///          - [EngineResultKind.conversion]: the user explicitly asked for a conversion and the
  ///            engine confirms it performed one (`to_struct`). Unit-carrying because it was asked for.
  ///          - [EngineResultKind.unit]: **this app's syntax has no unit *names*** — it recognises
  ///            exactly two unit-ish postfix shorthands, `°` (which `ExpressionParser` rewrites to
  ///            `rad(...)`, `expression_parser.dart:487`) and `%` (percent, likewise fixed arithmetic,
  ///            `:599`), and both are handled by the legacy parser as its own arithmetic. So an answer
  ///            carrying a *named* unit (`aa`, `t`, `km/us`, `n'r'`) cannot have come from anything
  ///            this syntax expresses — unless the user asked for a conversion, which the
  ///            [EngineResultKind.conversion] branch above catches. What is left is the engine reading
  ///            one of our identifiers as a unit (`fact(-1)` → `-10 aa*t`, `ncr(5,10)` → a list of
  ///            `n'r' km/us`), which is precisely "garbage read into a plausible shape".
  ///          - [EngineResultKind.unitMismatch]: a conversion was asked for and the engine did **not**
  ///            do it — it hands the input back unchanged (`5 km to kg` gives `5 km`; measured: no
  ///            message, no exception). It is refused for the same reason as
  ///            [EngineResultKind.unit]: what is on screen is not this evaluation's answer. **It
  ///            cannot be folded into [EngineResultKind.conversion]**: that one means "the conversion
  ///            the user asked for happened" and this one means "it did not", while on the engine's
  ///            side **both have a defined `to_struct`** (a failed conversion still writes the target
  ///            unit into it) — they separate only after the native side asks whether any units are
  ///            left once the result is divided by the target.
  ///          - [EngineResultKind.symbolic]: **a symbolic form** (the result holds a variable and the
  ///            engine had nothing to say). It passes for the other face of the reason
  ///            [EngineResultKind.arithmetic] refuses — see that branch: this app's syntax has **no
  ///            variables**, so the legacy parser has no standing on an input containing one. It is
  ///            **not** the "the engine did not compute" class: operations the engine cannot do are
  ///            held in [EngineResultKind.arithmetic] by two facts of its own (the message queue and
  ///            whether the result holds a variable — `1/0`, `x/0`, `0^0`).
  ///          - [EngineResultKind.arithmetic]: products, powers, calls, symbolic sums — **this app's
  ///            language can express these**, so the legacy parser is the authority: it either
  ///            produces a value (and that value wins) or refuses, and its refusal is this app's
  ///            answer for that line. `1 / 0`, `mod(2; 0)`, `root(2; 0)`, `x / 0` and `0^0` all land
  ///            here. (`2x` and `x^2 + 1` used to be here and are now
  ///            [EngineResultKind.symbolic]; `sin(x rad)` is still not displayed but is **not** in
  ///            this branch — the engine treats `rad` as a unit, so its kind is
  ///            [EngineResultKind.unit], see that branch.)
  ///          - [EngineResultKind.notFromEngine]: the legacy parser and placeholders; the shape layer
  ///            does not apply to them.
  ///
  ///          Why "carries a unit" outranks the shape: the result of `ncr(5,10)` **is** a vector, only
  ///          every element of it carries a unit — by shape alone it would slip through.
  ///
  ///          **This rule replaces a list of examples** (the old one matched only `number operator
  ///          number`, so `i/0`, `(1+i)/0`, `matrix(...)/0`, `2 mod 0`, `root(2,0)` and `x/0` all got
  ///          through — and `i` and `MTRX` are exactly the keys that step lit up). The new rule does
  ///          not look at what the arithmetic looks like; it looks at **which kind of value the engine
  ///          produced this time**.
  bool get isDisplayable {
    if (!textIsDisplayable(displayText)) return false;
    return switch (resultKind) {
      EngineResultKind.notFromEngine => true,
      EngineResultKind.conversion => true,
      EngineResultKind.structured => true,
      EngineResultKind.number => true,
      EngineResultKind.quantity => true,
      EngineResultKind.symbolic => true,
      EngineResultKind.unit => false,
      EngineResultKind.unitMismatch => false,
      EngineResultKind.arithmetic => false,
    };
  }

  /// 中文：一段文本能不能显示（[isDisplayable] 用它判 [displayText]）。**只拒绝两类**，都在字符串层面判：
  ///
  ///       1. **真正非有限的字面量**：`∞` / `-∞` / `+∞` / `infinity` / `-infinity` / `NaN`
  ///          （`ln(0)` 实测印成 `-infinity`）。这一条**不能省**：`-infinity` 在引擎那里是一个
  ///          Number，形状那一层会把它当 [EngineResultKind.number] 放行。
  ///
  ///       **空串为假**：没有十进制形态的失败回执不该被当成可显示的结果（那是 [EngineReply] 的
  ///       `ok: false` 那一类，由调用方处理）。
  ///
  ///       它**曾经还有第二条**：整个文本是「数字 运算符 数字」就当成「引擎没算」。那是一条举例
  ///       清单，只匹配一种写法，实测漏掉了 `i/0`、`(1+i)/0`、`matrix(...)/0`、`2 mod 0`、
  ///       `root(2,0)`、`x/0`。现在这一类由 [resultKind] 的
  ///       [EngineResultKind.arithmetic] 从**结构上**挡住（引擎自己说这个结果是乘积/幂/函数调用），
  ///       不再看算式长什么样——所以那第二条被删掉了，而不是又补了几个例子。
  ///
  ///       实现**只有这一处**，与 [decimalValueOf] / [hasFiniteDecimal] 放在一起——这个类已经挪过
  ///       三次，再散开必然重演。
  /// English: Whether a piece of text may be displayed ([isDisplayable] uses it on [displayText]). The two things it rejects are judged at the
  ///          string level:
  ///
  ///          1. **genuinely non-finite literals**: `∞` / `-∞` / `+∞` / `infinity` / `-infinity` /
  ///             `NaN` (`ln(0)` prints as `-infinity`, measured).
  ///             measured). This clause **cannot be dropped**: `-infinity` is a Number on the engine's
  ///             side, and the shape layer would wave it through as [EngineResultKind.number].
  ///
  ///          An **empty string is not displayable**: a failure receipt with no result is not a
  ///          result (that is [EngineReply]'s `ok: false` family, the caller's business).
  ///
  ///          It **used to be** a match of "the whole string equals `∞`/`infinity`/`NaN`", so a
  ///          non-finite value *nested inside an expression* (`infinity*i`) was displayed anyway.
  ///          Scanning by position covers that class, and the judgement is still about finiteness
  ///          rather than about a few examples.
  ///
  ///          This is the **only** implementation, and it lives beside [decimalValueOf] /
  ///          [hasFiniteDecimal] — this class has moved three times already, and a second copy would
  ///          only start the same drift again.
  static bool textIsDisplayable(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return !_nonFiniteToken.hasMatch(trimmed);
  }

  /// 中文：表示非有限值的记号，**在文本的任意位置**匹配（前后不能是标识符字符，免得撞上
  ///       `info`、`nanny` 这类名字）。两个拼法是 IEEE-754 那两类非有限值在**本桥的输出字母表**里的
  ///       唯一写法（符号位由 `+`/`-` 表示，不在这个记号里）。
  /// English: the tokens denoting a non-finite value, matched **anywhere in the text** (no identifier
  ///          character on either side, so `info` or `nanny` cannot collide). The two spellings are the
  ///          only ones IEEE-754's two non-finite kinds take in **this bridge's output alphabet** (the
  ///          sign is a separate `+`/`-`; `∞` is the same value's other spelling).
  static final RegExp _nonFiniteToken =
      RegExp(r'(?<![A-Za-z_])(?:infinity|nan|∞)(?![A-Za-z_])', caseSensitive: false);


  /// 中文：一个**已经算出来的** double 能不能交给消费者：`Infinity` / `NaN` 不能，其余（包括真正的 0）
  ///       都能。它判不了下溢——`double.tryParse('9.3e-603')` 给的是 `0.0`，一个 double 自己说不清
  ///       它是「真的是 0」还是「小到装不下」——所以**凡手里有文本的地方一律先走 [decimalValueOf]**，
  ///       只有拿到的是一个算出来的 double 时才用它。
  /// English: Whether an *already computed* double may be handed to a consumer: `Infinity` / `NaN`
  ///          may not, everything else (a genuine 0 included) may. It cannot detect underflow —
  ///          `double.tryParse('9.3e-603')` yields `0.0`, and a double cannot say whether that is
  ///          "really zero" or "too small to store" — so **anywhere text is available, go through
  ///          [decimalValueOf] first**; use this only for a double that was computed.
  static double? usableDouble(double value) => value.isFinite ? value : null;

  /// 中文：十进制形态是不是一个**有限数**——在字符串层面判定，不借 double 的量程。
  ///       `1e602` 超出 double 上限却完全有限，所以为真；`Infinity` / `NaN` 这类字面量为假；
  ///       空串为假。提交路径用它决定要不要采用引擎的答案。
  /// English: Whether the decimal form is a *finite number* — decided at the string level, without
  ///          borrowing the double range. `1e602` overflows a double yet is perfectly finite, so it
  ///          is true; the `Infinity` / `NaN` literals are false; an empty string is false. The
  ///          submit path uses this to decide whether to take the engine's answer.
  bool get hasFiniteDecimal => decimalTextIsFinite(decimalText);

  /// 中文：一段文本是不是一个有限数。见 [hasFiniteDecimal]。
  ///
  ///       先 trim 再判：`double.tryParse` 自己会跳过首尾空白，而下面那个字面量正则不会，
  ///       于是 `' Infinity '` 会被判成有限数——这是等着被踩的坑（适配层先 trim 过，所以今天
  ///       走不到，但下一个调用方未必）。
  /// English: Whether a piece of text is a finite number. See [hasFiniteDecimal].
  ///
  ///          Trims first: `double.tryParse` skips surrounding whitespace on its own while the
  ///          literal regex below does not, so `' Infinity '` used to come back as a finite number —
  ///          a trap waiting to be stepped on (the adapter trims before calling, so it is
  ///          unreachable today, but the next caller need not).
  static bool decimalTextIsFinite(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (double.tryParse(trimmed) == null) return false;
    return !_nonFiniteLiteral.hasMatch(trimmed);
  }

  /// 中文：`double.tryParse` 认得、但**不是有限数**的那两个字面量（大小写放宽只是兜底）。
  /// English: The two literals `double.tryParse` accepts that are *not* finite numbers (the loose
  ///          casing is only a backstop).
  static final RegExp _nonFiniteLiteral =
      RegExp(r'^[+-]?(infinity|nan)$', caseSensitive: false);

  /// 中文：数字部分里有没有非零数字（指数部分不算，`0e-999` 仍然是零）。用来识别下溢。
  /// English: Whether the significand contains a non-zero digit (the exponent does not count —
  ///          `0e-999` is still zero). Used to recognise underflow.
  static bool _hasNonZeroDigit(String value) {
    final significand = value.split(RegExp('[eE]')).first;
    return RegExp('[1-9]').hasMatch(significand);
  }

  /// 中文：可以安全写回表达式、或用作去重键的文本：十进制优先，其次是**带单位结果的原文**
  ///       （[quantityText]，同样是未取整的那一份），两者都没有时才退回显示文本（去掉千分位），
  ///       与拆分之前 `result.replaceAll(',', '')` 的结果逐字节一致。
  ///
  ///       **第二顺位是这一轮加的，它不是放宽，是把既有的意图补全**：`decimalText` 排第一的理由是
  ///       「写回的必须是**未取整**的那一份」（`5.656854` 是画出来的，写回去的是
  ///       `5.656854249492380`）。一个量的未取整原文是 [quantityText]，而 [displayText] 自本轮起
  ///       取过整——少了这一顺位，「继续使用」就会写回一个位数更少的数。它在别的结果上恒为空串，
  ///       所以其余每一种输入写回去的仍是原来那一串，逐字节相同。
  /// English: Text that is safe to write back into the expression, or to key a de-duplication on: the
  ///          decimal form first, then a **unit-carrying result's own text** ([quantityText], likewise
  ///          the unrounded one), and only when neither exists the display text (grouping stripped) —
  ///          byte-for-byte what `result.replaceAll(',', '')` produced before the split.
  ///
  ///          **The second rank is new this round; not a relaxation but the completion of an
  ///          intention already recorded**: `decimalText` ranks first because what gets written back
  ///          must be the **unrounded** half (`5.656854` is drawn, `5.656854249492380` is written
  ///          back). A quantity's unrounded text is [quantityText], and [displayText] is rounded as of
  ///          this round — without the rank, "continue with result" would write a number with fewer
  ///          digits. It is empty elsewhere, so every other input writes back what it used to.
  String get reusableText => decimalText.isNotEmpty
      ? decimalText
      : (quantityText.isNotEmpty
          ? quantityText
          : displayText.replaceAll(',', ''));

  /// 中文：显示文本本身是否已经是可解析的十进制。为假时报告才会额外写一行十进制，好让复制粘贴
  ///       的往返在精确形式上仍然成立。
  /// English: Whether the display text is itself a parseable decimal. When it is not, the report
  ///          writes an extra decimal line so the copy/paste round-trip still holds for exact forms.
  bool get displayTextIsParseable => decimalTextOf(displayText).isNotEmpty;

  /// 中文：是否带 LaTeX 形态——结果行据此决定排版还是退化成纯文本。
  /// English: Whether a LaTeX form is present — the result line decides between typesetting and
  ///          degrading to plain text with this.
  bool get hasTex => displayTex.trim().isNotEmpty;

  /// 中文：是否带分数写法。与 [hasTex] 同一条判据、同一个位置——**不另写一份**（写第二份就会漂）。
  ///       它只回答「有没有」，排不排得出来仍由渲染器自己的 `typesetsTex` 回答。
  /// English: Whether a fraction spelling is present. The same judgement in the same place as
  ///          [hasTex] — **not a second copy** (a second copy would drift). It only answers "is
  ///          there one"; whether it typesets is still the renderer's own `typesetsTex`.
  bool get hasFractionTex => fractionTex.trim().isNotEmpty;

  /// 中文：是否带**带分数写法**。与 [hasTex]、[hasFractionTex] 同一条判据、同一个位置——同样
  ///       **不另写一份**。它只回答「有没有」；排不排得出来仍由渲染器自己的 `typesetsTex` 回答。
  /// English: Whether a **mixed-number spelling** is present. The same judgement in the same place as
  ///          [hasTex] and [hasFractionTex] — likewise **not a second copy**. It only answers "is
  ///          there one"; whether it typesets is still the renderer's own `typesetsTex`.
  bool get hasMixedTex => mixedTex.trim().isNotEmpty;

  /// 中文：是否带度分秒写法。与 [hasTex]、[hasFractionTex] 同一条判据、同一个位置——同样**不另写
  ///       一份**。它只回答「有没有」；这一串**画不画得出**（形状对不对、这一份结果配不配印它）仍由
  ///       `ResultPresentation` 一处回答——判据在那里，不在这里。
  /// English: Whether a DMS spelling is present. The same judgement in the same place as [hasTex] and
  ///          [hasFractionTex], and likewise **not a second copy**. It answers only "is there one";
  ///          whether the string can be **drawn** (does it have the right shape, and should this
  ///          result print it at all) is still answered in one place, `ResultPresentation` — the
  ///          judgement lives there, not here.
  bool get hasDmsText => dmsText.trim().isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is MathResult &&
        other.displayText == displayText &&
        other.displayTex == displayTex &&
        other.fractionTex == fractionTex &&
        other.mixedTex == mixedTex &&
        other.dmsText == dmsText &&
        other.decimalText == decimalText &&
        // 中文：`quantityText` 也进相等与哈希——`reusableText` 读它，两份「画出来一样」的结果若在这一
        //       格上不同，写回表达式的就是两个不同的数（`==` 说它们一样就成了那个谎）。
        // English: `quantityText` takes part in equality and hashing too — `reusableText` reads it,
        //          and two results that "draw the same" while differing here would write back two
        //          different numbers into the expression (`==` calling them equal would be that lie).
        other.quantityText == quantityText &&
        other.resultKind == resultKind;
  }

  @override
  int get hashCode => Object.hash(displayText, displayTex, fractionTex, mixedTex,
      dmsText, decimalText, quantityText, resultKind);

  @override
  String toString() {
    return 'MathResult(displayText: $displayText, displayTex: $displayTex, '
        'fractionTex: $fractionTex, mixedTex: $mixedTex, dmsText: $dmsText, '
        'decimalText: $decimalText, quantityText: $quantityText, '
        'resultKind: ${resultKind.name})';
  }
}
