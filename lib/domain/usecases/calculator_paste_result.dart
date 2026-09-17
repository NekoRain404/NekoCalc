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
  /// English: The order current values are taken in — the report's decimal line first (an exact form
  ///          cannot be written back into the expression, so it is the only usable one), then the
  ///          human-readable current-value line, and finally the first expression-like line of a
  ///          plain-text clipboard.
  static String _currentValueExpression({
    required String? decimalValue,
    required String? displayValue,
    required String text,
    required bool fromReport,
  }) {
    final decimal =
        decimalValue == null ? '' : _parserSafeCurrentValue(decimalValue);
    if (decimal.isNotEmpty) return decimal;
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
