part of 'text_tool_controller.dart';

extension _TextToolTextStatsTools on TextToolController {
  TextToolOutput _asciiUnicode(TextToolStatsStrings strings, String input) {
    final parsed = _tryParseCodePointInput(strings, input);
    if (parsed != null) {
      final stats = _classifyTextRunes(parsed.text);
      return TextToolOutput(
        parsed.text,
        _formatCodePointDetails(strings, parsed.text, includeSummary: true),
        insights: [
          strings.codePointInputDetected,
          strings.codePointParsed(parsed.count),
          _codePointStatsInsight(strings, stats),
        ],
      );
    }
    final stats = _classifyTextRunes(input);
    return TextToolOutput(
      strings.codePointPrimary(input.runes.length),
      input.isEmpty
          ? strings.enterCharacters
          : _formatCodePointDetails(strings, input, includeSummary: true),
      insights: [
        strings.utf8ByteInsight(utf8.encode(input).length),
        if (input.isNotEmpty) _codePointStatsInsight(strings, stats),
        if (input.runes.length > 24) strings.detailFirst24,
      ],
    );
  }

  TextToolOutput _textStats(TextToolStatsStrings strings, String input) {
    final visibleChars = input.characters.length;
    final codePoints = input.runes.length;
    final words = RegExp(r'[\w\u4e00-\u9fa5]+').allMatches(input).length;
    final lineStats = _analyzeTextLines(input);
    final bytes = utf8.encode(input).length;
    final nonWhitespace =
        input.replaceAll(RegExp(r'\s+'), '').characters.length;
    final nonWhitespaceCodePoints =
        input.replaceAll(RegExp(r'\s+'), '').runes.length;
    final paragraphs = _countParagraphs(input);
    final charStats = _classifyTextRunes(input);
    final latinWords = _countLatinWords(input);
    final numberTokens = _countNumberTokens(input);
    return TextToolOutput(
      strings.primaryCharCount(visibleChars),
      [
        strings.detailCharCount(visibleChars),
        strings.codePointsLabel(codePoints),
        strings.detailWordFragments(words),
        strings.detailLatinWords(latinWords),
        strings.detailNumberTokens(numberTokens),
        strings.detailLines(lineStats.lines),
        strings.detailNonEmptyLines(lineStats.nonEmptyLines),
        strings.detailEmptyLines(lineStats.emptyLines),
        strings.detailParagraphs(paragraphs),
        strings.utf8BytesLabel(bytes),
        strings.detailNonWhitespaceChars(nonWhitespace),
        if (nonWhitespaceCodePoints != nonWhitespace)
          strings.detailNonWhitespaceCodePoints(nonWhitespaceCodePoints),
        strings.detailLongestLine(lineStats.longestLine),
        strings.detailAverageLineLength(
            lineStats.averageNonEmptyLineLength.toStringAsFixed(2)),
        if (lineStats.trailingWhitespaceLines > 0)
          strings
              .detailTrailingWhitespaceLines(lineStats.trailingWhitespaceLines),
        strings.detailCjk(charStats.cjk),
        strings.detailLatin(charStats.latin),
        strings.detailDigits(charStats.digits),
        strings.detailWhitespace(charStats.whitespace),
        strings.detailPunctuation(charStats.punctuation),
        strings.detailOther(charStats.other),
      ].join('\n'),
      insights: [
        strings.insightBytesPerChar(
            (bytes / (visibleChars == 0 ? 1 : visibleChars))
                .toStringAsFixed(2)),
        if (visibleChars != codePoints) strings.insightGraphemeAggregated,
        if (charStats.cjk > 0 && charStats.latin > 0)
          strings.insightMixedScript,
        if (bytes > codePoints) strings.insightMultiByte,
        if (paragraphs > 1) strings.insightParagraphs(paragraphs),
        if (lineStats.emptyLines > 0)
          strings.insightEmptyLines(lineStats.emptyLines),
        if (lineStats.trailingWhitespaceLines > 0)
          strings.insightTrailingWhitespace(lineStats.trailingWhitespaceLines),
        if (input.trim().isEmpty) strings.insightAllWhitespace,
      ],
    );
  }

  /// 中文：`strings` 只为两条 `FormatException` 的正文而来——「Unicode 码点无效: …」是给人看的
  ///       一句话，会被兜底那条接住显示在详情里。识别**是不是**码点输入的那套正则与判据
  ///       （`U+` / `0x` / `&#x` / `\u` 前缀、逗号分隔的十进制串）一个字符都没动。
  /// English: `strings` is here only for the body of two `FormatException`s — "Invalid Unicode code
  ///          point: …" is a sentence for the reader, caught by the fallback and shown in the detail
  ///          pane. The patterns and conditions that decide *whether* the input is code points
  ///          (`U+` / `0x` / `&#x` / `\u` prefixes, comma-separated decimal runs) are untouched.
  _ParsedCodePointInput? _tryParseCodePointInput(
    TextToolStatsStrings strings,
    String input,
  ) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final matches = RegExp(
      r'(?:U\+|u\+|0x|\\u\{|\\u|\\x|&#x|&#)([0-9a-fA-F]+)\}?;?',
    ).allMatches(trimmed).toList();
    final codes = <int>[];
    if (matches.isNotEmpty) {
      var consumed = trimmed;
      for (final match in matches) {
        final token = match.group(0)!;
        final digits = match.group(1)!;
        final radix = token.startsWith('&#') && !token.startsWith('&#x')
            ? 10
            : token.startsWith(r'\x')
                ? 16
                : 16;
        final code = int.tryParse(digits, radix: radix);
        if (code == null || _safeCodePoint(code) == null) {
          throw FormatException(strings.invalidCodePoint(token));
        }
        codes.add(code);
        consumed = consumed.replaceFirst(token, ' ');
      }
      if (consumed.trim().replaceAll(RegExp(r'[\s,;，；]+'), '').isNotEmpty) {
        return null;
      }
      return _ParsedCodePointInput(
        text: String.fromCharCodes(codes),
        count: codes.length,
      );
    }

    final parts = trimmed
        .split(RegExp(r'[\s,;，；]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty ||
        !parts.every((part) => RegExp(r'^\d+$').hasMatch(part))) {
      return null;
    }
    if (parts.length == 1 && int.parse(parts.single) < 32) return null;
    for (final part in parts) {
      final code = int.parse(part);
      if (_safeCodePoint(code) == null) {
        throw FormatException(strings.invalidCodePoint(part));
      }
      codes.add(code);
    }
    return _ParsedCodePointInput(
      text: String.fromCharCodes(codes),
      count: codes.length,
    );
  }

  String _formatCodePointDetails(
    TextToolStatsStrings strings,
    String input, {
    bool includeSummary = false,
  }) {
    final lines = <String>[
      if (includeSummary) ...[
        strings.summaryVisibleChars(input.characters.length),
        strings.codePointsLabel(input.runes.length),
        strings.utf8BytesLabel(utf8.encode(input).length),
        strings.summaryUtf16Units(input.codeUnits.length),
      ],
      ...input.runes.take(24).map((code) {
        final char = String.fromCharCode(code);
        final hex = code.toRadixString(16).toUpperCase().padLeft(4, '0');
        final utf16 = char.codeUnits
            .map((unit) => unit.toRadixString(16).toUpperCase().padLeft(4, '0'))
            .join(' ');
        final bytes = utf8
            .encode(char)
            .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
            .join(' ');
        final htmlDecimal = '&#$code;';
        final htmlHex = '&#x$hex;';
        return '$char  dec:$code  U+$hex  \\u{${hex.toLowerCase()}}  UTF-16:$utf16  UTF-32:$hex  UTF-8:$bytes  HTML:$htmlDecimal/$htmlHex';
      }),
    ];
    return lines.join('\n');
  }

  String _codePointStatsInsight(
    TextToolStatsStrings strings,
    _TextCharacterStats stats,
  ) {
    final parts = <String>[
      if (stats.cjk > 0) strings.classCjk(stats.cjk),
      if (stats.latin > 0) strings.classLatin(stats.latin),
      if (stats.digits > 0) strings.classDigits(stats.digits),
      if (stats.whitespace > 0) strings.classWhitespace(stats.whitespace),
      if (stats.punctuation > 0) strings.classPunctuation(stats.punctuation),
      if (stats.other > 0) strings.classOther(stats.other),
    ];
    return parts.isEmpty ? strings.classNone : strings.classSummary(parts);
  }

  _TextCharacterStats _classifyTextRunes(String input) {
    var cjk = 0;
    var latin = 0;
    var digits = 0;
    var whitespace = 0;
    var punctuation = 0;
    var other = 0;
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'\s').hasMatch(char)) {
        whitespace++;
      } else if (_isCjkRune(rune)) {
        cjk++;
      } else if (RegExp(r'[A-Za-z]').hasMatch(char)) {
        latin++;
      } else if (RegExp(r'[0-9]').hasMatch(char)) {
        digits++;
      } else if (RegExp(r'[\p{P}\p{S}]', unicode: true).hasMatch(char)) {
        punctuation++;
      } else {
        other++;
      }
    }
    return _TextCharacterStats(
      cjk: cjk,
      latin: latin,
      digits: digits,
      whitespace: whitespace,
      punctuation: punctuation,
      other: other,
    );
  }

  bool _isCjkRune(int rune) {
    return (rune >= 0x3400 && rune <= 0x4dbf) ||
        (rune >= 0x4e00 && rune <= 0x9fff) ||
        (rune >= 0xf900 && rune <= 0xfaff) ||
        (rune >= 0x20000 && rune <= 0x2ebef);
  }

  int _countParagraphs(String input) {
    if (input.trim().isEmpty) return 0;
    return input
        .split(RegExp(r'(?:\r?\n){2,}'))
        .where((part) => part.trim().isNotEmpty)
        .length;
  }

  int _countLatinWords(String input) {
    return RegExp(r"[A-Za-z]+(?:[’'\-][A-Za-z]+)*").allMatches(input).length;
  }

  int _countNumberTokens(String input) {
    return RegExp(r'[+-]?\d+(?:[.,]\d+)*').allMatches(input).length;
  }

  _TextLineStats _analyzeTextLines(String input) {
    if (input.isEmpty) {
      return const _TextLineStats(
        lines: 0,
        nonEmptyLines: 0,
        emptyLines: 0,
        longestLine: 0,
        averageNonEmptyLineLength: 0,
        trailingWhitespaceLines: 0,
      );
    }
    final lines = const LineSplitter().convert(input);
    var nonEmptyLines = 0;
    var emptyLines = 0;
    var longestLine = 0;
    var nonEmptyLineCharacters = 0;
    var trailingWhitespaceLines = 0;

    for (final line in lines) {
      final length = line.characters.length;
      longestLine = math.max(longestLine, length);
      if (line.trim().isEmpty) {
        emptyLines++;
      } else {
        nonEmptyLines++;
        nonEmptyLineCharacters += length;
      }
      if (RegExp(r'[ \t\u00a0\u3000]+$').hasMatch(line)) {
        trailingWhitespaceLines++;
      }
    }

    return _TextLineStats(
      lines: lines.length,
      nonEmptyLines: nonEmptyLines,
      emptyLines: emptyLines,
      longestLine: longestLine,
      averageNonEmptyLineLength:
          nonEmptyLines == 0 ? 0 : nonEmptyLineCharacters / nonEmptyLines,
      trailingWhitespaceLines: trailingWhitespaceLines,
    );
  }
}
