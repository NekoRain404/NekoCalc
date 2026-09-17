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
