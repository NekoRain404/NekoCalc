import '../../core/math/result_text_rules.dart';
import 'dart:convert';

import '../../core/math/math_result.dart';
import '../../core/utils/number_formatter.dart';

enum CalculatorPasteStatus {
  empty,
  plainExpression,
  calculatorReport,
}

class CalculatorPasteResult {
  const CalculatorPasteResult({
    required this.status,
    required this.expression,
    this.fromCurrentValue = false,
    this.angleMode,
    this.memoryValue,
  });

  const CalculatorPasteResult.empty()
      : status = CalculatorPasteStatus.empty,
        expression = '',
        fromCurrentValue = false,
        angleMode = null,
        memoryValue = null;

  factory CalculatorPasteResult.fromText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const CalculatorPasteResult.empty();
    final fromReport = _looksLikeCalculatorReport(trimmed);
    final labeledExpression =
        _labeledValue(trimmed, const ['表达式', 'expression']);
    final currentValue = _labeledValue(trimmed, const ['当前值', 'current value']);
    // 中文：报告在显示文本不是可解析十进制时（精确形式 `4√2`）会额外写一行十进制，粘贴时它优先。
    // English: When the report's display text is not a parseable decimal (an exact form such as
    //          `4√2`) it carries an extra decimal line, and that line wins on paste.
    final decimalValue = _labeledValue(trimmed, const ['十进制', 'decimal']);
    final restoredCurrentValue = labeledExpression == null &&
        (currentValue != null || decimalValue != null);
    final expression = labeledExpression ??
        _currentValueExpression(
          decimalValue: decimalValue,
          displayValue: currentValue,
          text: trimmed,
          fromReport: fromReport,
        );
    return CalculatorPasteResult(
      status: fromReport
          ? CalculatorPasteStatus.calculatorReport
          : CalculatorPasteStatus.plainExpression,
      expression: expression.trim(),
      fromCurrentValue: restoredCurrentValue,
      angleMode: _angleModeFromText(trimmed),
      memoryValue: _memoryValueFromText(trimmed),
    );
  }

  final CalculatorPasteStatus status;
  final String expression;
  final bool fromCurrentValue;
  final String? angleMode;
  final double? memoryValue;

  bool get hasExpression => expression.trim().isNotEmpty;

  bool get fromReport => status == CalculatorPasteStatus.calculatorReport;

  String get summary {
    final parts = <String>[
      if (!hasExpression && angleMode != null && memoryValue != null)
        '已恢复角度模式和记忆值'
      else if (!hasExpression && angleMode != null)
        '已恢复角度模式'
      else if (!hasExpression && memoryValue != null)
        '已恢复记忆值'
      else if (!hasExpression)
        '剪贴板里没有识别到表达式'
      else if (fromReport)
        fromCurrentValue ? '已从计算详情恢复当前值' : '已从计算详情提取表达式'
      else
        '已粘贴表达式',
    ];
    if (angleMode != null) {
      parts.add('角度模式 ${angleMode == 'DEG' ? 'DEG' : 'RAD'}');
    }
    if (memoryValue != null) parts.add('记忆值 ${formatNumber(memoryValue!)}');
    return parts.join(' · ');
  }

  /// 中文：当前值的取值顺序——报告里的十进制行优先，其次是人类可读的当前值行，最后才是纯文本剪贴板
  ///       里第一行「看起来像表达式」的内容。两条报告行都**必须能解析成一个有限数**才算数，实现
  ///       就是 [_parserSafeCurrentValue]。
  ///
  ///       每一行各自的情形，逐条写清楚（这是 3c 评审第 2 项的交付物）：
  ///
  ///       1. 报告里有 `十进制:` 行且可解析 → 用它。精确形式（`4√2`）的报告正是这一种：控制器在
  ///          显示文本不是十进制时会额外写这一行，粘贴靠它往返。
  ///       2. 没有可用的 `十进制:` 行（没有这一行，或者这一行解析不出来），而 `当前值` 行可解析
  ///          → 用 `当前值` 行。**旧求值器产出的报告都是这一种**：显示形态本身就是十进制形态
  ///          （`displayTextIsParseable` 为真），`1,234.5` → `1234.5`，复制粘贴的往返靠的就是它。
  ///       3. 两条都不可用（例如报告只有 `当前值: 4√2`，或者 `当前值: not-a-number`）→
  ///          **什么都不恢复**：宁可空手而归，也不把显示文本解析成数字，更不会用失败解析出的 0
  ///          去冒充一个值。这种情况**仍然是静默的**——摘要保持 `剪贴板里没有识别到表达式`，
  ///          没有额外的提示（3c 评审建议过一条「当前值无法恢复」的摘要，但那会改掉已被钉住的
  ///          摘要文本，见下），这是接受的裁决，不是未处理的缺口。
  ///
  ///       行为被两处测试钉住，所以这里只写规则、不改行为：
  ///       `test/domain/calculator_result_split_test.dart` 的
  ///       `pasting a report without a decimal line behaves as before` 要求第 2 种情形成立；
  ///       `test/domain/calculator_paste_result_test.dart` 的
  ///       `unusable current value report keeps the unrecognized summary` 把第 3 种情形的摘要文本
  ///       钉在 `剪贴板里没有识别到表达式`。
  ///
  /// English: The order current values are taken in — the report's decimal line first, then the
  ///          human-readable current-value line, and finally the first expression-like line of a
  ///          plain-text clipboard. Both report lines count only if they parse into a finite number,
  ///          which is what [_parserSafeCurrentValue] enforces.
  ///
  ///          The cases, spelled out one by one (this comment is the deliverable for finding 2 of the
  ///          3c review):
  ///
  ///          1. The report has a parseable `十进制:` line → it wins. A report for an exact form
  ///             (`4√2`) is exactly this case: the controller writes that line when the display text
  ///             is not itself a decimal, and the paste round trip rides on it.
  ///          2. No usable `十进制:` line (absent, or unparseable), and the current-value line
  ///             parses → the current-value line is used. *Every report the legacy evaluator
  ///             produces is this case*: the display form is itself the decimal form
  ///             (`displayTextIsParseable` is true), `1,234.5` becomes `1234.5`, and the copy/paste
  ///             round trip depends on it.
  ///          3. Neither is usable (the report carries only `当前值: 4√2`, or `当前值: not-a-number`)
  ///             → *nothing is restored*: it goes home empty-handed rather than parsing display
  ///             text, and never passes off a failed parse's 0 as a value. This case is **still
  ///             silent** — the summary stays `剪贴板里没有识别到表达式` with no extra hint. (The 3c
  ///             review suggested a "current value could not be restored" summary; that would change
  ///             summary text pinned by a test, see below.) That is an accepted ruling, not an
  ///             unhandled gap.
  ///
  ///          The behaviour is pinned by two tests, so this states the rule without changing it:
  ///          `pasting a report without a decimal line behaves as before` in
  ///          `test/domain/calculator_result_split_test.dart` requires case 2 to hold, and
  ///          `unusable current value report keeps the unrecognized summary` in
  ///          `test/domain/calculator_paste_result_test.dart` pins case 3's summary text to
  ///          剪贴板里没有识别到表达式.
  static String _currentValueExpression({
    required String? decimalValue,
    required String? displayValue,
    required String text,
    required bool fromReport,
  }) {
    final decimal =
        decimalValue == null ? '' : _parserSafeCurrentValue(decimalValue);
    if (decimal.isNotEmpty) return decimal;
    // 中文：情形 2 与 3 的分界——`当前值` 行可解析就用，不可解析就什么都不恢复（见上面的 3）。
    // English: The line between cases 2 and 3 — a parseable current-value line is used, an
    //          unparseable one restores nothing (see case 3 above).
    if (displayValue != null) return _parserSafeCurrentValue(displayValue);
    return fromReport ? '' : _firstExpressionLikeLine(text);
  }

  /// 中文：报告里的一行数字文本，能不能安全地写回表达式。判定用
  ///       [MathResult.decimalValueOf]——与提交路径、记忆寄存器**同一处实现**。
  ///
  ///       以前的判据是「`double.tryParse` 成功且 `isFinite`」，于是 `9.303768583076e-603`
  ///       会被接受，理由是它解析成了一个**有限的** `0.0`。**「解析成功」不等于「值保住了」**：
  ///       那个 0.0 是下溢，粘回来的是一个比原值小 10^600 倍的数——正是修复轮 1 在提交路径上
  ///       修掉的那类静默错值，只是这里没修。`decimalValueOf` 对下溢返回 null，于是这一行被拒，
  ///       粘贴什么都不恢复（fail-closed，与「当前值不是数字」同一条路）。
  ///
  /// English: Whether a numeric line from a report is safe to write back into the expression. The
  ///          judgement is [MathResult.decimalValueOf] — the *same implementation* the submit path
  ///          and the memory register use.
  ///
  ///          The old test was "`double.tryParse` succeeds and `isFinite`", which accepted
  ///          `9.303768583076e-603` on the grounds that it parses into a *finite* `0.0`.
  ///          "It parsed" is not "the value survived": that 0.0 is an underflow, and pasting it
  ///          back yields a number 10^600 times smaller — the same silent wrong value fix round 1
  ///          eliminated on the submit path, only not here. `decimalValueOf` returns null for
  ///          underflow, so the line is refused and the paste restores nothing (fail-closed, the
  ///          same route as "the current value is not a number").
  static String _parserSafeCurrentValue(String raw) {
    var normalized = raw.replaceAll(',', '').trim();
    if (normalized.startsWith('-.')) {
      normalized = '-0${normalized.substring(1)}';
    } else if (normalized.startsWith('.')) {
      normalized = '0$normalized';
    }
    return decimalValueOf(normalized) == null ? '' : normalized;
  }

  static String? _labeledValue(String text, List<String> labels) {
    final escaped = labels.map(RegExp.escape).join('|');
    final pattern = RegExp(
      '^\\s*(?:$escaped)\\s*[:：]\\s*(.+?)\\s*\$',
      caseSensitive: false,
      multiLine: true,
    );
    return pattern.firstMatch(text)?.group(1)?.trim();
  }

  static String _firstExpressionLikeLine(String text) {
    final lines = const LineSplitter()
        .convert(text)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    for (final line in lines) {
      final normalized = line.toLowerCase();
      if (normalized.startsWith('当前值') ||
          normalized.startsWith('current value') ||
          normalized.startsWith('十进制') ||
          normalized.startsWith('decimal') ||
          normalized.startsWith('结果') ||
          normalized.startsWith('result') ||
          normalized.startsWith('状态') ||
          normalized.startsWith('status') ||
          normalized.startsWith('角度模式') ||
          normalized.startsWith('angle mode') ||
          normalized.startsWith('记忆值') ||
          normalized.startsWith('memory') ||
          normalized.startsWith('错误') ||
          normalized.startsWith('error')) {
        continue;
      }
      return line;
    }
    return '';
  }

  static String? _angleModeFromText(String text) {
    final raw = _labeledValue(text, const ['角度模式', 'angle mode']);
    if (raw == null) return null;
    final normalized = raw.toLowerCase();
    if (normalized.contains('deg') || raw.contains('角度')) return 'DEG';
    if (normalized.contains('rad') || raw.contains('弧度')) return 'RAD';
    return null;
  }

  /// 中文：报告里 `记忆值:` 那一行 → 寄存器的数值。判定用 [MathResult.decimalValueOf]——与
  ///       提交路径、当前值那一行**同一处实现**。
  ///
  ///       旧的判据是「`double.tryParse` 成功且 `isFinite`」：`记忆值: 9.303768583076e-603`
  ///       解析出来是一个**有限的** `0.0`，于是被收下，寄存器从 7.0 静默变成 0.0——正是本轮在
  ///       别处修掉的那个错误。只有外来报告能构造出这一行（App 自己的报告写的是
  ///       `formatNumber(memoryValue)`），但这不改变它是错的。
  /// English: The report's `记忆值:` line into the register's value. The judgement is
  ///          [MathResult.decimalValueOf] — the *same implementation* the submit path and the
  ///          current-value line use.
  ///
  ///          The old test was "`double.tryParse` succeeds and `isFinite`": `记忆值:
  ///          9.303768583076e-603` parses into a *finite* `0.0`, so it was taken and the register
  ///          went from 7.0 to 0.0 without a word — the very error this round fixed elsewhere. Only
  ///          a foreign report can build that line (this app's own reports write
  ///          `formatNumber(memoryValue)`), but that does not make it right.
  static double? _memoryValueFromText(String text) {
    final raw = _labeledValue(text, const ['记忆值', 'memory', 'memory value']);
    if (raw == null) return null;
    return decimalValueOf(raw.replaceAll(',', '').trim());
  }

  static bool _looksLikeCalculatorReport(String text) {
    return _labeledValue(text, const ['表达式', 'expression']) != null ||
        _labeledValue(text, const ['当前值', 'current value']) != null ||
        _labeledValue(text, const ['十进制', 'decimal']) != null ||
        _labeledValue(text, const ['结果', 'result']) != null ||
        _labeledValue(text, const ['角度模式', 'angle mode']) != null ||
        _labeledValue(text, const ['记忆值', 'memory', 'memory value']) != null;
  }
}
