import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：文本统计 / 码点（`text_stats` 与 `ascii_unicode` 两个工具）的界面文案表。
///       **为什么单独一张**、**为什么控制器要接表进来**、以及**哪些中文刻意不翻**，
///       三条理由都写在 `text_tool_strings.dart` 的文件头上，这里不重抄。
///
///       **为什么它自己一张**：这两个工具共用一份逐行统计的正文——字符数、码点、行数、空白、
///       字符分类……一条一项，合起来约五十条。并进 `TextToolTextStrings` 会把那一张推过
///       八百行的硬线（这正是工具子树当初从一张表拆成两张的同一条理由）。
///
///       **逐行统计的正文是"给人看的字"，即使它长得像表格。** 它整段被复制进笔记和剪贴板，
///       所以每一行都要翻；反过来，`RegExp(r'[\w一-龥]+')` 里那个 `一-龥`
///       是**转义**、不是汉字，它定义的是"什么算一个词"，与语言无关，留在控制器里。
/// English: The copy table for text statistics and code points (the `text_stats` and
///          `ascii_unicode` tools). **Why it is a table of its own**, **why the controller takes a
///          table as an argument**, and **which Chinese is deliberately left untranslated** are all
///          written on `text_tool_strings.dart`'s file head and not copied again here.
///
///          **Why it gets a table to itself**: the two tools share one block of per-line statistics —
///          characters, code points, lines, whitespace, character classes — one item per line, about
///          fifty in total. Folding them into `TextToolTextStrings` would push that table past the
///          hard 800-line limit, exactly the reason the tools subtree was split from one table into
///          two in the first place.
///
///          **The per-line statistics block is human-facing copy even though it looks like a
///          table.** The whole block gets copied into a note or the clipboard, so every line needs
///          translating. Conversely the `一-龥` inside
///          `RegExp(r'[\w一-龥]+')` is an **escape**, not Chinese text: it defines what
///          counts as a word and has nothing to do with the interface language, so it stays in the
///          controller.
@immutable
class TextToolStatsStrings {
  const TextToolStatsStrings({
    // —— 码点输入的还原 ——
    required this.codePointInputDetected,
    required this.codePointParsed,
    required this.codePointPrimary,
    required this.enterCharacters,
    required this.utf8ByteInsight,
    required this.detailFirst24,
    required this.invalidCodePoint,
    // —— 逐行统计的正文 ——
    required this.primaryCharCount,
    required this.detailCharCount,
    required this.codePointsLabel,
    required this.detailWordFragments,
    required this.detailLatinWords,
    required this.detailNumberTokens,
    required this.detailLines,
    required this.detailNonEmptyLines,
    required this.detailEmptyLines,
    required this.detailParagraphs,
    required this.utf8BytesLabel,
    required this.detailNonWhitespaceChars,
    required this.detailNonWhitespaceCodePoints,
    required this.detailLongestLine,
    required this.detailAverageLineLength,
    required this.detailTrailingWhitespaceLines,
    required this.detailCjk,
    required this.detailLatin,
    required this.detailDigits,
    required this.detailWhitespace,
    required this.detailPunctuation,
    required this.detailOther,
    // —— 校核提示 ——
    required this.insightBytesPerChar,
    required this.insightGraphemeAggregated,
    required this.insightMixedScript,
    required this.insightMultiByte,
    required this.insightParagraphs,
    required this.insightEmptyLines,
    required this.insightTrailingWhitespace,
    required this.insightAllWhitespace,
    // —— 码点详情的表头 ——
    required this.summaryVisibleChars,
    required this.summaryUtf16Units,
    // —— 字符分类 ——
    required this.classCjk,
    required this.classLatin,
    required this.classDigits,
    required this.classWhitespace,
    required this.classPunctuation,
    required this.classOther,
    required this.classNone,
    required this.classSummary,
  });

  // —— 码点输入的还原 ——
  final String codePointInputDetected;
  final String Function(int count) codePointParsed;
  final String Function(int count) codePointPrimary;
  final String enterCharacters;
  final String Function(int bytes) utf8ByteInsight;
  final String detailFirst24;

  /// 中文：`FormatException` 的正文，见 `TextToolTextStrings.uuidInvalid` 上的说明。
  /// English: The body of a `FormatException`; see the note on
  ///          `TextToolTextStrings.uuidInvalid`.
  final String Function(String token) invalidCodePoint;

  // —— 逐行统计的正文 ——
  final String Function(int count) primaryCharCount;
  final String Function(int count) detailCharCount;
  final String Function(int count) codePointsLabel;
  final String Function(int count) detailWordFragments;
  final String Function(int count) detailLatinWords;
  final String Function(int count) detailNumberTokens;
  final String Function(int count) detailLines;
  final String Function(int count) detailNonEmptyLines;
  final String Function(int count) detailEmptyLines;
  final String Function(int count) detailParagraphs;
  final String Function(int count) utf8BytesLabel;
  final String Function(int count) detailNonWhitespaceChars;
  final String Function(int count) detailNonWhitespaceCodePoints;
  final String Function(int count) detailLongestLine;
  final String Function(String length) detailAverageLineLength;
  final String Function(int count) detailTrailingWhitespaceLines;
  final String Function(int count) detailCjk;
  final String Function(int count) detailLatin;
  final String Function(int count) detailDigits;
  final String Function(int count) detailWhitespace;
  final String Function(int count) detailPunctuation;
  final String Function(int count) detailOther;

  // —— 校核提示 ——
  final String Function(String value) insightBytesPerChar;
  final String insightGraphemeAggregated;
  final String insightMixedScript;
  final String insightMultiByte;
  final String Function(int count) insightParagraphs;
  final String Function(int count) insightEmptyLines;
  final String Function(int count) insightTrailingWhitespace;
  final String insightAllWhitespace;

  // —— 码点详情的表头 ——
  final String Function(int count) summaryVisibleChars;
  final String Function(int count) summaryUtf16Units;

  // —— 字符分类 ——
  final String Function(int count) classCjk;
  final String Function(int count) classLatin;
  final String Function(int count) classDigits;
  final String Function(int count) classWhitespace;
  final String Function(int count) classPunctuation;
  final String Function(int count) classOther;
  final String classNone;

  /// 中文：分类那一行的收尾。分隔符住在闭包里，因为中文用「，」、英文用「, 」——
  ///       它属于这句话，不属于拼接处。
  /// English: The tail of the classification line. The separator lives inside the closure because
  ///          Chinese uses `，` and English uses `, ` — it belongs to the sentence, not to the
  ///          call site.
  final String Function(List<String> parts) classSummary;

  static TextToolStatsStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  static TextToolStatsStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => statsZh,
      AppLanguage.en => statsEn,
    };
  }

  static final TextToolStatsStrings statsZh = TextToolStatsStrings(
    codePointInputDetected: '检测为 Unicode 码点/转义输入，已还原为字符。',
    codePointParsed: (count) => '解析到 $count 个码点。',
    codePointPrimary: (count) => '$count 个码点',
    enterCharacters: '请输入字符',
    utf8ByteInsight: (bytes) => 'UTF-8 字节: $bytes。',
    detailFirst24: '详情仅展示前 24 个码点。',
    invalidCodePoint: (token) => 'Unicode 码点无效: $token',
    primaryCharCount: (count) => '$count 字符',
    detailCharCount: (count) => '字符数: $count',
    codePointsLabel: (count) => 'Unicode 码点: $count',
    detailWordFragments: (count) => '词/片段: $count',
    detailLatinWords: (count) => '英文词: $count',
    detailNumberTokens: (count) => '数字片段: $count',
    detailLines: (count) => '行数: $count',
    detailNonEmptyLines: (count) => '非空行: $count',
    detailEmptyLines: (count) => '空行: $count',
    detailParagraphs: (count) => '段落: $count',
    utf8BytesLabel: (count) => 'UTF-8 字节: $count',
    detailNonWhitespaceChars: (count) => '去空白字符: $count',
    detailNonWhitespaceCodePoints: (count) => '去空白码点: $count',
    detailLongestLine: (count) => '最长行: $count 字符',
    detailAverageLineLength: (length) => '平均非空行长: $length 字符',
    detailTrailingWhitespaceLines: (count) => '行尾空白: $count 行',
    detailCjk: (count) => '中文字符: $count',
    detailLatin: (count) => '拉丁字母: $count',
    detailDigits: (count) => '数字: $count',
    detailWhitespace: (count) => '空白字符: $count',
    detailPunctuation: (count) => '标点/符号: $count',
    detailOther: (count) => '其他字符: $count',
    insightBytesPerChar: (value) => '平均每字符 $value bytes。',
    insightGraphemeAggregated: '已按 Unicode 可见字符聚合组合符号和 emoji。',
    insightMixedScript: '文本包含中英文混排。',
    insightMultiByte: '包含多字节 UTF-8 字符。',
    insightParagraphs: (count) => '检测到 $count 个非空段落。',
    insightEmptyLines: (count) => '包含 $count 个空行。',
    insightTrailingWhitespace: (count) => '检测到 $count 行行尾空白。',
    insightAllWhitespace: '输入为空或仅包含空白字符。',
    summaryVisibleChars: (count) => '可见字符: $count',
    summaryUtf16Units: (count) => 'UTF-16 code units: $count',
    classCjk: (count) => '中文/汉字 $count',
    classLatin: (count) => '拉丁字母 $count',
    classDigits: (count) => '数字 $count',
    classWhitespace: (count) => '空白 $count',
    classPunctuation: (count) => '标点/符号 $count',
    classOther: (count) => '其他 $count',
    classNone: '未检测到可分类字符。',
    classSummary: (parts) => '字符分类: ${parts.join('，')}。',
  );

  static final TextToolStatsStrings statsEn = TextToolStatsStrings(
    codePointInputDetected:
        'Recognised Unicode code-point or escape input and restored the characters.',
    codePointParsed: (count) => 'Parsed $count code points.',
    codePointPrimary: (count) => '$count code points',
    enterCharacters: 'Enter some characters',
    utf8ByteInsight: (bytes) => 'UTF-8 bytes: $bytes.',
    detailFirst24: 'The detail shows the first 24 code points only.',
    invalidCodePoint: (token) => 'Invalid Unicode code point: $token',
    primaryCharCount: (count) => '$count characters',
    detailCharCount: (count) => 'Characters: $count',
    codePointsLabel: (count) => 'Unicode code points: $count',
    detailWordFragments: (count) => 'Words/fragments: $count',
    detailLatinWords: (count) => 'Latin words: $count',
    detailNumberTokens: (count) => 'Number fragments: $count',
    detailLines: (count) => 'Lines: $count',
    detailNonEmptyLines: (count) => 'Non-empty lines: $count',
    detailEmptyLines: (count) => 'Empty lines: $count',
    detailParagraphs: (count) => 'Paragraphs: $count',
    utf8BytesLabel: (count) => 'UTF-8 bytes: $count',
    detailNonWhitespaceChars: (count) =>
        'Characters without whitespace: $count',
    detailNonWhitespaceCodePoints: (count) =>
        'Code points without whitespace: $count',
    detailLongestLine: (count) => 'Longest line: $count characters',
    detailAverageLineLength: (length) =>
        'Average non-empty line: $length characters',
    detailTrailingWhitespaceLines: (count) =>
        'Lines with trailing whitespace: $count',
    detailCjk: (count) => 'CJK characters: $count',
    detailLatin: (count) => 'Latin letters: $count',
    detailDigits: (count) => 'Digits: $count',
    detailWhitespace: (count) => 'Whitespace characters: $count',
    detailPunctuation: (count) => 'Punctuation/symbols: $count',
    detailOther: (count) => 'Other characters: $count',
    insightBytesPerChar: (value) => 'Averaging $value bytes per character.',
    insightGraphemeAggregated:
        'Combining marks and emoji were grouped by Unicode visible character.',
    insightMixedScript: 'The text mixes Chinese and Latin script.',
    insightMultiByte: 'Contains multi-byte UTF-8 characters.',
    insightParagraphs: (count) => 'Found $count non-empty paragraphs.',
    insightEmptyLines: (count) => 'Contains $count empty lines.',
    insightTrailingWhitespace: (count) =>
        'Found $count lines with trailing whitespace.',
    insightAllWhitespace: 'The input is empty or contains only whitespace.',
    summaryVisibleChars: (count) => 'Visible characters: $count',
    summaryUtf16Units: (count) => 'UTF-16 code units: $count',
    classCjk: (count) => 'Chinese/Han $count',
    classLatin: (count) => 'Latin letters $count',
    classDigits: (count) => 'Digits $count',
    classWhitespace: (count) => 'Whitespace $count',
    classPunctuation: (count) => 'Punctuation/symbols $count',
    classOther: (count) => 'Other $count',
    classNone: 'No classifiable characters found.',
    classSummary: (parts) => 'Character classes: ${parts.join(', ')}.',
  );
}
