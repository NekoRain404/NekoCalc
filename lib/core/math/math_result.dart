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

  /// 中文：十进制形态解析出的数值；没有十进制形态时为 null。调用方**不得**退回 [displayText]。
  /// English: The value behind the decimal form, or null when there is none. Callers must *not* fall
  ///          back to [displayText].
  double? get decimalValue =>
      decimalText.isEmpty ? null : double.tryParse(decimalText);

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
