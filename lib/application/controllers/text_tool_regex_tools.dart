part of 'text_tool_controller.dart';

extension _TextToolRegexTools on TextToolController {
  TextToolOutput _regexTest(String input) {
    final lines = const LineSplitter().convert(input);
    if (lines.length < 2) throw const FormatException('第一行输入正则，后续行输入测试文本。');
    final spec = _parseRegexInput(lines);
    final regex = RegExp(
      spec.pattern,
      multiLine: spec.multiLine,
      caseSensitive: !spec.caseInsensitive,
      dotAll: spec.dotAll,
      unicode: spec.unicode,
    );
    final text = spec.text;
    final matches = regex.allMatches(text).toList();
    final detail = matches.take(50).map(_formatRegexMatch).join('\n');
    return TextToolOutput(
      '${matches.length} 个匹配',
      detail.isEmpty ? '没有匹配项' : detail,
      insights: [
        'Flags: ${spec.displayFlags}',
        if (spec.labeledInput) '已识别 pattern/text 标签格式。',
        if (spec.global) '已兼容 g/global 标志；本工具默认列出所有匹配。',
        if (matches.length > 50) '仅展示前 50 个匹配项。',
        if (matches.isEmpty) '当前正则没有命中测试文本。',
        if (spec.pattern.isEmpty) '正则为空，会匹配所有位置。',
        if (matches.any((match) => match.groupCount > 0))
          '包含捕获组，详情中已列出 group 值。',
      ],
    );
  }

  _RegexInputSpec _parseRegexInput(List<String> lines) {
    final labeled = _parseLabeledRegexInput(lines);
    if (labeled != null) return labeled;

    var patternLine = lines.first.trim();
    var flags = '';
    var textStart = 1;
    final slash = _parseSlashRegexPattern(patternLine);
    if (slash.$2.isNotEmpty || slash.$1 != patternLine) {
      patternLine = slash.$1;
      flags = slash.$2;
    } else if (lines.length >= 3 &&
        RegExp(r'^(?:flags?|模式)\s*[:=]\s*([a-zA-Z]+)\s*$', caseSensitive: false)
            .hasMatch(lines[1].trim())) {
      final match = RegExp(r'^(?:flags?|模式)\s*[:=]\s*([a-zA-Z]+)\s*$',
              caseSensitive: false)
          .firstMatch(lines[1].trim())!;
      flags = match.group(1)!;
      textStart = 2;
    }
    final normalizedFlags = flags.toLowerCase();
    if (normalizedFlags.contains(RegExp(r'[^gimsu]'))) {
      throw const FormatException('正则 flags 仅支持 g、i、m、s、u');
    }
    final effectiveFlags =
        normalizedFlags.replaceAll('g', '').split('').toSet().join();
    return _RegexInputSpec(
      pattern: patternLine,
      flags: effectiveFlags.isEmpty ? 'm' : effectiveFlags,
      inputFlags: normalizedFlags,
      text: lines.skip(textStart).join('\n'),
      labeledInput: false,
    );
  }

  _RegexInputSpec? _parseLabeledRegexInput(List<String> lines) {
    String? pattern;
    String? flags;
    var textLines = <String>[];
    var readingText = false;

    for (final line in lines) {
      final patternMatch = RegExp(
        r'^\s*(?:pattern|regex|regexp|正则|表达式)\s*[:=]\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (patternMatch != null) {
        pattern = patternMatch.group(1) ?? '';
        readingText = false;
        continue;
      }

      final flagsMatch = RegExp(
        r'^\s*(?:flags?|模式)\s*[:=]\s*([a-zA-Z]+)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      if (flagsMatch != null) {
        flags = flagsMatch.group(1)!;
        readingText = false;
        continue;
      }

      final textMatch = RegExp(
        r'^\s*(?:text|input|sample|测试文本|文本)\s*[:=]\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (textMatch != null) {
        textLines = [textMatch.group(1) ?? ''];
        readingText = true;
        continue;
      }

      if (readingText) textLines.add(line);
    }

    if (pattern == null || textLines.isEmpty) return null;
    final parsedPattern = _parseSlashRegexPattern(pattern.trim());
    final mergedFlags = flags ?? parsedPattern.$2;
    final normalizedFlags = mergedFlags.toLowerCase();
    if (normalizedFlags.contains(RegExp(r'[^gimsu]'))) {
      throw const FormatException('正则 flags 仅支持 g、i、m、s、u');
    }
    final effectiveFlags =
        normalizedFlags.replaceAll('g', '').split('').toSet().join();
    return _RegexInputSpec(
      pattern: parsedPattern.$1,
      flags: effectiveFlags.isEmpty ? 'm' : effectiveFlags,
      inputFlags: normalizedFlags,
      text: textLines.join('\n'),
      labeledInput: true,
    );
  }

  (String, String) _parseSlashRegexPattern(String pattern) {
    final slash = RegExp(r'^/(.*)/([a-zA-Z]*)$').firstMatch(pattern);
    if (slash == null) return (pattern, '');
    return (slash.group(1)!, slash.group(2)!);
  }

  String _formatRegexMatch(RegExpMatch match) {
    final lines = <String>[
      '[${match.start}, ${match.end}) ${match.group(0)}',
    ];
    for (var i = 1; i <= match.groupCount; i++) {
      lines.add('  group $i: ${match.group(i) ?? 'null'}');
    }
    final names = match.groupNames.toList()..sort();
    for (final name in names) {
      lines.add('  $name: ${match.namedGroup(name) ?? 'null'}');
    }
    return lines.join('\n');
  }
}
