part of 'text_tool_controller.dart';

extension _TextToolTextStatsTools on TextToolController {
  TextToolOutput _asciiUnicode(String input) {
    final parsed = _tryParseCodePointInput(input);
    if (parsed != null) {
      final stats = _classifyTextRunes(parsed.text);
      return TextToolOutput(
        parsed.text,
        _formatCodePointDetails(parsed.text, includeSummary: true),
        insights: [
          '检测为 Unicode 码点/转义输入，已还原为字符。',
          '解析到 ${parsed.count} 个码点。',
          _codePointStatsInsight(stats),
        ],
      );
    }
    final stats = _classifyTextRunes(input);
    return TextToolOutput(
      '${input.runes.length} 个码点',
      input.isEmpty
          ? '请输入字符'
          : _formatCodePointDetails(input, includeSummary: true),
      insights: [
        'UTF-8 字节: ${utf8.encode(input).length}。',
        if (input.isNotEmpty) _codePointStatsInsight(stats),
        if (input.runes.length > 24) '详情仅展示前 24 个码点。',
      ],
    );
  }

  TextToolOutput _textStats(String input) {
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
      '$visibleChars 字符',
      [
        '字符数: $visibleChars',
        'Unicode 码点: $codePoints',
        '词/片段: $words',
        '英文词: $latinWords',
        '数字片段: $numberTokens',
        '行数: ${lineStats.lines}',
        '非空行: ${lineStats.nonEmptyLines}',
        '空行: ${lineStats.emptyLines}',
        '段落: $paragraphs',
        'UTF-8 字节: $bytes',
        '去空白字符: $nonWhitespace',
        if (nonWhitespaceCodePoints != nonWhitespace)
          '去空白码点: $nonWhitespaceCodePoints',
        '最长行: ${lineStats.longestLine} 字符',
        '平均非空行长: ${lineStats.averageNonEmptyLineLength.toStringAsFixed(2)} 字符',
        if (lineStats.trailingWhitespaceLines > 0)
          '行尾空白: ${lineStats.trailingWhitespaceLines} 行',
        '中文字符: ${charStats.cjk}',
        '拉丁字母: ${charStats.latin}',
        '数字: ${charStats.digits}',
        '空白字符: ${charStats.whitespace}',
        '标点/符号: ${charStats.punctuation}',
        '其他字符: ${charStats.other}',
      ].join('\n'),
      insights: [
        '平均每字符 ${(bytes / (visibleChars == 0 ? 1 : visibleChars)).toStringAsFixed(2)} bytes。',
        if (visibleChars != codePoints) '已按 Unicode 可见字符聚合组合符号和 emoji。',
        if (charStats.cjk > 0 && charStats.latin > 0) '文本包含中英文混排。',
        if (bytes > codePoints) '包含多字节 UTF-8 字符。',
        if (paragraphs > 1) '检测到 $paragraphs 个非空段落。',
        if (lineStats.emptyLines > 0) '包含 ${lineStats.emptyLines} 个空行。',
        if (lineStats.trailingWhitespaceLines > 0)
          '检测到 ${lineStats.trailingWhitespaceLines} 行行尾空白。',
        if (input.trim().isEmpty) '输入为空或仅包含空白字符。',
      ],
    );
  }

  _ParsedCodePointInput? _tryParseCodePointInput(String input) {
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
          throw FormatException('Unicode 码点无效: $token');
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
        throw FormatException('Unicode 码点无效: $part');
      }
      codes.add(code);
    }
    return _ParsedCodePointInput(
      text: String.fromCharCodes(codes),
      count: codes.length,
    );
  }

  String _formatCodePointDetails(String input, {bool includeSummary = false}) {
    final lines = <String>[
      if (includeSummary) ...[
        '可见字符: ${input.characters.length}',
        'Unicode 码点: ${input.runes.length}',
        'UTF-8 字节: ${utf8.encode(input).length}',
        'UTF-16 code units: ${input.codeUnits.length}',
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

  String _codePointStatsInsight(_TextCharacterStats stats) {
    final parts = <String>[
      if (stats.cjk > 0) '中文/汉字 ${stats.cjk}',
      if (stats.latin > 0) '拉丁字母 ${stats.latin}',
      if (stats.digits > 0) '数字 ${stats.digits}',
      if (stats.whitespace > 0) '空白 ${stats.whitespace}',
      if (stats.punctuation > 0) '标点/符号 ${stats.punctuation}',
      if (stats.other > 0) '其他 ${stats.other}',
    ];
    return parts.isEmpty ? '未检测到可分类字符。' : '字符分类: ${parts.join('，')}。';
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
