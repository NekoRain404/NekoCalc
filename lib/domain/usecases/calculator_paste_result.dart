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
    this.angleMode,
    this.memoryValue,
  });

  const CalculatorPasteResult.empty()
      : status = CalculatorPasteStatus.empty,
        expression = '',
        angleMode = null,
        memoryValue = null;

  factory CalculatorPasteResult.fromText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const CalculatorPasteResult.empty();
    final expression = _labeledValue(trimmed, const ['表达式', 'expression']) ??
        _firstExpressionLikeLine(trimmed);
    final fromReport = _looksLikeCalculatorReport(trimmed);
    return CalculatorPasteResult(
      status: fromReport
          ? CalculatorPasteStatus.calculatorReport
          : CalculatorPasteStatus.plainExpression,
      expression: expression.trim(),
      angleMode: _angleModeFromText(trimmed),
      memoryValue: _memoryValueFromText(trimmed),
    );
  }

  final CalculatorPasteStatus status;
  final String expression;
  final String? angleMode;
  final double? memoryValue;

  bool get hasExpression => expression.trim().isNotEmpty;

  bool get fromReport => status == CalculatorPasteStatus.calculatorReport;

  String get summary {
    if (!hasExpression) return '剪贴板里没有识别到表达式';
    final parts = <String>[fromReport ? '已从计算详情提取表达式' : '已粘贴表达式'];
    if (angleMode != null) {
      parts.add('角度模式 ${angleMode == 'DEG' ? 'DEG' : 'RAD'}');
    }
    if (memoryValue != null) parts.add('记忆值 ${formatNumber(memoryValue!)}');
    return parts.join(' · ');
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
      if (normalized.startsWith('结果') ||
          normalized.startsWith('result') ||
          normalized.startsWith('状态') ||
          normalized.startsWith('角度模式') ||
          normalized.startsWith('记忆值') ||
          normalized.startsWith('错误')) {
        continue;
      }
      return line;
    }
    return lines.first;
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
    return double.tryParse(raw.replaceAll(',', '').trim());
  }

  static bool _looksLikeCalculatorReport(String text) {
    return _labeledValue(text, const ['表达式', 'expression']) != null ||
        _labeledValue(text, const ['结果', 'result']) != null ||
        _labeledValue(text, const ['角度模式', 'angle mode']) != null;
  }
}
