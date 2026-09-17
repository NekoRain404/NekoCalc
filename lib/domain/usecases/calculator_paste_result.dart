import 'dart:convert';

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

  /// 中文：当前值的取值顺序——报告里的十进制行（精确形式写不回表达式，只能用它）优先，其次是人类
  ///       可读的当前值行，最后才是纯文本剪贴板里第一行「看起来像表达式」的内容。
  ///
  ///       **`当前值` 行是显示形态，不是数字**：它只在本身已经是一个可解析、有限的十进制时才被
  ///       采用（[_parserSafeCurrentValue] 不是数字就返回空串）。旧求值器下显示形态就是十进制形态
  ///       ——`MathResult.decimalTextOf(displayText)` 就是它自己——复制粘贴的往返靠的正是这一条；
  ///       而精确形式（`4√2`）没有十进制形态，于是粘贴什么都不恢复：**宁可空手而归，也不把显示
  ///       文本解析成数字**，更不会用失败解析出的 0 去冒充一个值。
  ///
  ///       这一条是 3c 评审第 2 项的处置。评审给的两条可选补救（摘要里说明「当前值无法恢复」）
  ///       都会改变已定型的行为：`test/domain/calculator_result_split_test.dart` 的
  ///       `pasting a report without a decimal line behaves as before` 把守「显示形态即十进制形态
  ///       时必须照旧恢复」，而工作区里 `test/domain/calculator_paste_result_test.dart` 的
  ///       `unusable current value report keeps the unrecognized summary` 把摘要文本钉在了
  ///       「剪贴板里没有识别到表达式」。所以这里保持行为不变，把规则写在代码里。
  ///
  /// English: The order current values are taken in — the report's decimal line first (an exact form
  ///          cannot be written back into the expression, so it is the only usable one), then the
  ///          human-readable current-value line, and finally the first expression-like line of a
  ///          plain-text clipboard.
  ///
  ///          The current-value line is *display text, not a number*: it is only taken when it is
  ///          itself a parseable, finite decimal ([_parserSafeCurrentValue] returns an empty string
  ///          otherwise). Under the legacy evaluator the display form *is* the decimal form —
  ///          `MathResult.decimalTextOf(displayText)` is the display text itself — and that is what
  ///          keeps the copy/paste round trip working; an exact form (`4√2`) has no decimal form, so
  ///          the paste restores nothing: it goes home empty-handed rather than parsing display text,
  ///          and never passes off a failed parse's 0 as a value.
  ///
  ///          This is how finding 2 of the 3c review is handled. Both remedies the review offered
  ///          (a summary saying the current value could not be restored) would change settled
  ///          behaviour: `pasting a report without a decimal line behaves as before` in
  ///          `test/domain/calculator_result_split_test.dart` pins that a display form which *is* a
  ///          decimal must still be restored, and `unusable current value report keeps the
  ///          unrecognized summary` in the working tree's `test/domain/calculator_paste_result_test.dart`
  ///          pins the summary text to 剪贴板里没有识别到表达式. So behaviour stays as it is and the
  ///          rule lives here in the code.
  static String _currentValueExpression({
    required String? decimalValue,
    required String? displayValue,
    required String text,
    required bool fromReport,
  }) {
    final decimal =
        decimalValue == null ? '' : _parserSafeCurrentValue(decimalValue);
    if (decimal.isNotEmpty) return decimal;
    // 中文：`当前值` 行是**显示形态**，只有它本身已经是一个（可解析、有限的）十进制时才可以用。
    //       旧求值器下显示形态就是十进制形态，复制粘贴的往返靠的正是这一条；而像 `4√2` 这样没有
    //       十进制形态的精确形式，[_parserSafeCurrentValue] 会 fail-closed 地返回空串——粘贴宁可
    //       什么都不恢复，也不把显示文本解析成数字（`currentValueMissingDecimal` 会说明原因，
    //       免得它看起来像一次静默的空操作）。
    // English: The current-value line is *display text* and is used only when it is itself a
    //          (parseable, finite) decimal. Under the legacy evaluator the display form *is* the
    //          decimal form, and that is what keeps the copy/paste round trip working; an exact form
    //          with no decimal form, such as `4√2`, makes [_parserSafeCurrentValue] return an empty
    //          string — a paste restores nothing rather than parsing display text (and
    //          `currentValueMissingDecimal` says why, so it does not look like a silent no-op).
    if (displayValue != null) return _parserSafeCurrentValue(displayValue);
    return fromReport ? '' : _firstExpressionLikeLine(text);
  }

  static String _parserSafeCurrentValue(String raw) {
    var normalized = raw.replaceAll(',', '').trim();
    if (normalized.startsWith('-.')) {
      normalized = '-0${normalized.substring(1)}';
    } else if (normalized.startsWith('.')) {
      normalized = '0$normalized';
    }
    final value = double.tryParse(normalized);
    return value != null && value.isFinite ? normalized : '';
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

  static double? _memoryValueFromText(String text) {
    final raw = _labeledValue(text, const ['记忆值', 'memory', 'memory value']);
    if (raw == null) return null;
    final value = double.tryParse(raw.replaceAll(',', '').trim());
    return value != null && value.isFinite ? value : null;
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
