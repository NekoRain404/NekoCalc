import 'package:characters/characters.dart';

import '../../features/tools/presentation/text_tool_strings.dart';

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

/// 中文：一次文本工具求值的结果。**语言不是它的字段**：它自己不认字，屏幕上的字全靠调用方
///       把 [TextToolOutputStrings] 递进来——`TextToolController` 是纯 Dart、不持
///       `BuildContext`，语言只能顺着参数走，理由见 `text_tool_strings.dart` 的文件头。
/// English: The result of one text-tool evaluation. **The language is not one of its fields**: it
///          knows no words itself, and every word shown comes from the [TextToolOutputStrings] the
///          caller passes in — `TextToolController` is plain Dart and holds no `BuildContext`, so the
///          language can only travel through the parameter list; see `text_tool_strings.dart`'s file
///          head.
class TextToolOutput {
  const TextToolOutput(
    this.primary,
    this.detail, {
    this.insights = const [],
    this.hasError = false,
  });

  final String primary;
  final String detail;
  final List<String> insights;

  /// 中文：这次输出是不是一条错误。**它是一个真字段，不是比出来的。** 原先它是
  ///       `primary.trim() == '输入无效' || primary.trim().startsWith('不支持')`——把一句
  ///       **要显示给用户的话**同时当成了判据。那句中文在英文界面下会变成 `Invalid input`，
  ///       判据随即永远为假：错误卡会悄悄换成绿色对勾，`_saveHistory` 会把一条错误当成结果
  ///       存进历史。默认 `false`，只有兜底那两条在构造时写明 `hasError: true`。
  /// English: Whether this output is an error. **It is a real field, not something compared into
  ///          existence.** It used to be
  ///          `primary.trim() == '输入无效' || primary.trim().startsWith('不支持')` — a **sentence
  ///          meant for the user** doubling as a branch condition. In an English interface that
  ///          Chinese sentence becomes `Invalid input`, the condition is then always false, and the
  ///          error card quietly turns into a green tick while `_saveHistory` writes an error into
  ///          history as if it were a result. Defaults to `false`; only the two fallbacks say
  ///          `hasError: true` at construction.
  final bool hasError;

  String statusTitle(TextToolOutputStrings strings) {
    return hasError ? strings.statusNeedsFix : strings.statusReusable;
  }

  String statusMessage(TextToolOutputStrings strings) {
    if (hasError) {
      final reason = _firstNonEmptyLine(detail);
      return reason.isEmpty ? strings.retryHint : reason;
    }
    final insightText =
        insights.isEmpty ? '' : strings.insightCount(insights.length);
    return strings.statusReading(
      _textSizeLabel(strings, primary),
      _textSizeLabel(strings, detail),
      insightText,
    );
  }

  String get primaryCopyText => primary;

  String get detailCopyText => detail;

  String copyText({
    required TextToolOutputStrings strings,
    required String title,
    required String input,
  }) {
    final normalizedInput = input.trim();
    return [
      title,
      if (normalizedInput.isNotEmpty) ...[strings.copyInput, normalizedInput],
      '',
      strings.copyStatus(statusTitle(strings)),
      statusMessage(strings),
      '',
      strings.copyPrimary,
      primary,
      '',
      strings.copyDetail,
      detail,
      if (insights.isNotEmpty) ...[
        '',
        strings.copyInsights,
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

  static String _textSizeLabel(TextToolOutputStrings strings, String value) {
    if (value.isEmpty) return strings.emptySize;
    final chars = value.characters.length;
    final lines = '\n'.allMatches(value).length + 1;
    if (lines <= 1) return strings.charCount(chars);
    return strings.charLineCount(chars, lines);
  }
}
