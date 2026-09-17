import 'package:flutter/foundation.dart';

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
  ///       - [isDisplayable] 问的是「**能不能显示**」。矩阵、复数、解集、精确形式都没有有限十进制，
  ///         但它们是引擎算出来的**值**，恰恰是这个应用引入引擎的理由。
  ///
  ///       它判的是 [displayText]——也就是**结果行上会出现的那个字符串**——而不是 [decimalText]：
  ///       适配层对非数字答案**故意**不写 `decimalText`（那正是这个类存在的意义），所以拿
  ///       `decimalText` 去判「能不能显示」会让矩阵和复数永远为假。
  ///
  ///       两个判据分开，正是 [MathResult] 拆成三个字段的本意；把它们合成一个，就等于「有十进制
  ///       才配显示」——那会让矩阵与复数永远上不了屏。
  /// English: **Displayable** — whether what the engine produced this time may go on the result line.
  ///          It is a **second judgement, not the same one** as [hasFiniteDecimal]:
  ///
  ///          - [hasFiniteDecimal] asks "**can this be used as a number**" (what `Ans`/`last`/memory/
  ///            continue-with/history de-duplication/paste round-trip need);
  ///          - [isDisplayable] asks "**can this be shown**". A matrix, a complex number, a solution
  ///            set or an exact form has no finite decimal, yet each is a *value* the engine
  ///            computed — which is the whole reason this app took the engine on.
  ///
  ///          It judges [displayText] — the string that would appear on the result line — rather than
  ///          [decimalText]: the adapter **deliberately** leaves `decimalText` empty for a non-numeric
  ///          answer (that is what this class is for), so asking `decimalText` "may this be shown"
  ///          would answer no for every matrix and every complex number.
  ///
  ///          Keeping the two apart is what the three-field split of [MathResult] was for; merging
  ///          them says "only what has a decimal deserves to be shown", which would keep matrices and
  ///          complex numbers off the screen forever.
  bool get isDisplayable => textIsDisplayable(displayText);

  /// 中文：一段文本能不能显示（[isDisplayable] 用它判 [displayText]）。**只拒绝两类**，都在字符串层面判：
  ///
  ///       1. **真正非有限的字面量**：`∞` / `-∞` / `+∞` / `infinity` / `-infinity` / `NaN`
  ///          （`ln(0)` 实测印成 `-infinity`）。
  ///       2. **引擎没算、把式子原样退回来的那种形态**：整个文本就是一个「数字 运算符 数字」。
  ///          `1/0` 实测印成 `1 / 0`、`0/0` 印成 `0 / 0`、`2/0` 印成 `2 / 0`——引擎拒绝做这次除法，
  ///          于是把算式本身退回来。**这不是「取消检查」，是换一个检查**：它仍然拦着那三种形态，
  ///          而矩阵（`[1  2; 3  4]`）、复数（`1 + 2i`）、符号结果（`2x`）一个都不受影响，
  ///          因为它们身上没有「两个数字之间夹一个运算符」这个形状。
  ///
  ///       **空串为假**：没有十进制形态的失败回执不该被当成可显示的结果（那是 [EngineReply] 的
  ///       `ok: false` 那一类，由调用方处理）。
  ///
  ///       实现**只有这一处**，与 [decimalValueOf] / [hasFiniteDecimal] 放在一起——这个类已经挪过
  ///       三次，再散开必然重演。
  /// English: Whether a piece of text may be displayed ([isDisplayable] uses it on [displayText]). The two things it rejects are judged at the
  ///          string level:
  ///
  ///          1. **genuinely non-finite literals**: `∞` / `-∞` / `+∞` / `infinity` / `-infinity` /
  ///             `NaN` (`ln(0)` prints as `-infinity`, measured).
  ///          2. **an arithmetic the engine did not perform and handed straight back**: the whole
  ///             text is one `number <operator> number`. `1/0` prints as `1 / 0`, `0/0` as `0 / 0`
  ///             and `2/0` as `2 / 0` (all measured) — the engine refuses the division and returns the
  ///             expression itself. This is **swapping the check, not deleting it**: those three
  ///             shapes stay off the screen, while a matrix (`[1  2; 3  4]`), a complex number
  ///             (`1 + 2i`) and a symbolic result (`2x`) are untouched, because none of them has a
  ///             number on both sides of an operator.
  ///
  ///          An **empty string is not displayable**: a failure receipt with no result is not a
  ///          result (that is [EngineReply]'s `ok: false` family, the caller's business).
  ///
  ///          This is the **only** implementation, and it lives beside [decimalValueOf] /
  ///          [hasFiniteDecimal] — this class has moved three times already, and a second copy would
  ///          only start the same drift again.
  static bool textIsDisplayable(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (_displayNonFiniteLiteral.hasMatch(_withoutSign(trimmed))) return false;
    return !_unperformedArithmetic.hasMatch(trimmed);
  }

  /// 中文：`[符号]非有限字面量`。与 [_nonFiniteLiteral] 分开是免得两处的含义被读成一处：
  ///       [_nonFiniteLiteral] 是「`double.tryParse` 认得但不是有限数」，这里还多接受 `∞` 这两个
  ///       字符（`double.tryParse` 根本不认它，但 `PrintOptions.use_unicode_signs` 开着时引擎会印）。
  /// English: `[sign]non-finite literal`. Kept apart from [_nonFiniteLiteral] so the two meanings are
  ///          not read as one: that one covers what `double.tryParse` accepts but is not finite,
  ///          while this also accepts the `∞` character (which `double.tryParse` rejects outright but
  ///          the engine prints when `PrintOptions.use_unicode_signs` is on).
  static final RegExp _displayNonFiniteLiteral =
      RegExp(r'^(infinity|nan|∞)$', caseSensitive: false);

  /// 中文：去掉一个前导正负号，供 [_displayNonFiniteLiteral] 判。
  /// English: strips one leading sign for [_displayNonFiniteLiteral].
  static String _withoutSign(String text) =>
      text.startsWith('+') || text.startsWith('-') ? text.substring(1) : text;

  /// 中文：`数字 运算符 数字`——引擎退回来的一次未做运算。数字允许小数与科学计数法，
  ///       两边都必须是纯数字：`1 + 2i` 的右边不是纯数字，`2x` 也是，所以它们不受影响。
  /// English: `number operator number` — one arithmetic operation the engine handed back unperformed.
  ///          Numbers may be decimal or scientific, and both sides must be *pure* numbers: the right
  ///          side of `1 + 2i` is not, and neither is `2x`, so those are unaffected.
  static final RegExp _unperformedArithmetic = RegExp(
    r'^[+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?'
    r'\s*[+\-*/^]\s*'
    r'[+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$',
  );

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
        other.decimalText == decimalText;
  }

  @override
  int get hashCode => Object.hash(displayText, displayTex, decimalText);

  @override
  String toString() {
    return 'MathResult(displayText: $displayText, displayTex: $displayTex, '
        'decimalText: $decimalText)';
  }
}
