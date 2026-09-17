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

  /// 中文：结果带单位。**应用自己的语言里没有单位**——见 [MathResult.isDisplayable]。
  /// English: the result carries a unit. **This app's language has no units** — see
  ///          [MathResult.isDisplayable].
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
    this.decimalText = '',
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
  ///       - [EngineResultKind.unit]：**应用自己的语法里没有单位名**——它只认两个单位式后缀：
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
  ///       - [EngineResultKind.arithmetic]：乘积、幂、函数调用、符号和——**应用的语言表达得了**，
  ///         所以旧解析器才是权威：它要么给出一个值（那就它说了算），要么明确拒绝，而它的拒绝
  ///         就是这个应用对这一行的答案。`1 / 0`、`mod(2; 0)`、`root(2; 0)`、`x / 0`、`2x`、
  ///         `x^2 + 1`、`sin(x rad)` 全落在这一支。
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
  ///          - [EngineResultKind.arithmetic]: products, powers, calls, symbolic sums — **this app's
  ///            language can express these**, so the legacy parser is the authority: it either
  ///            produces a value (and that value wins) or refuses, and its refusal is this app's
  ///            answer for that line. `1 / 0`, `mod(2; 0)`, `root(2; 0)`, `x / 0`, `2x`, `x^2 + 1`
  ///            and `sin(x rad)` all land here.
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

  /// 中文：可以安全写回表达式、或用作去重键的文本：十进制优先，缺失时退回显示文本（去掉千分位），
  ///       与拆分之前 `result.replaceAll(',', '')` 的结果逐字节一致。
  /// English: Text that is safe to write back into the expression, or to key a de-duplication on:
  ///          the decimal form first, the display text (grouping stripped) when it is missing —
  ///          byte-for-byte what `result.replaceAll(',', '')` produced before the split.
  String get reusableText =>
      decimalText.isNotEmpty ? decimalText : displayText.replaceAll(',', '');

  /// 中文：显示文本本身是否已经是可解析的十进制。为假时报告才会额外写一行十进制，好让复制粘贴
  ///       的往返在精确形式上仍然成立。
  /// English: Whether the display text is itself a parseable decimal. When it is not, the report
  ///          writes an extra decimal line so the copy/paste round-trip still holds for exact forms.
  bool get displayTextIsParseable => decimalTextOf(displayText).isNotEmpty;

  /// 中文：是否带 LaTeX 形态——结果行据此决定排版还是退化成纯文本。
  /// English: Whether a LaTeX form is present — the result line decides between typesetting and
  ///          degrading to plain text with this.
  bool get hasTex => displayTex.trim().isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is MathResult &&
        other.displayText == displayText &&
        other.displayTex == displayTex &&
        other.decimalText == decimalText &&
        other.resultKind == resultKind;
  }

  @override
  int get hashCode =>
      Object.hash(displayText, displayTex, decimalText, resultKind);

  @override
  String toString() {
    return 'MathResult(displayText: $displayText, displayTex: $displayTex, '
        'decimalText: $decimalText, resultKind: ${resultKind.name})';
  }
}
