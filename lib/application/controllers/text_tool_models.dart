import 'package:characters/characters.dart';

class TextToolDraft {
  const TextToolDraft({
    required this.toolId,
    required this.input,
    required this.formula,
    required this.a,
    required this.b,
    required this.c,
  });

  final String toolId;
  final String input;
  final String formula;
  final String a;
  final String b;
  final String c;
}

class TextToolOutput {
  const TextToolOutput(this.primary, this.detail, {this.insights = const []});

  final String primary;
  final String detail;
  final List<String> insights;

  bool get hasError =>
      primary.trim() == '输入无效' || primary.trim().startsWith('不支持');

  String get statusTitle => hasError ? '输入需要修正' : '结果可复用';

  String get statusMessage {
    if (hasError) {
      final reason = _firstNonEmptyLine(detail);
      return reason.isEmpty ? '请检查输入格式后重试。' : reason;
    }
    final insightText = insights.isEmpty ? '' : '，${insights.length} 条校核提示';
    return '主结果 ${_textSizeLabel(primary)}，详细结果 ${_textSizeLabel(detail)}$insightText';
  }

  String get primaryCopyText => primary;

  String get detailCopyText => detail;

  String copyText({
    required String title,
    required String input,
  }) {
    final normalizedInput = input.trim();
    return [
      title,
      if (normalizedInput.isNotEmpty) ...['输入:', normalizedInput],
      '',
      '状态: $statusTitle',
      statusMessage,
      '',
      '主结果:',
      primary,
      '',
      '详细结果:',
      detail,
      if (insights.isNotEmpty) ...[
        '',
        '校核:',
        ...insights,
      ],
    ].join('\n');
  }

  static String _firstNonEmptyLine(String value) {
    for (final line in value.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String _textSizeLabel(String value) {
    if (value.isEmpty) return '为空';
    final chars = value.characters.length;
    final lines = '\n'.allMatches(value).length + 1;
    if (lines <= 1) return '$chars 字符';
    return '$chars 字符/$lines 行';
  }
}
