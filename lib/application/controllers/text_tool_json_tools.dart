part of 'text_tool_controller.dart';

extension _TextToolJsonTools on TextToolController {
  TextToolOutput _jsonFormat(String input) {
    final parsed = _parseJsonInput(input);
    const encoder = JsonEncoder.withIndent('  ');
    return TextToolOutput(
      parsed.jsonLines ? 'JSON Lines 有效' : 'JSON 有效',
      encoder.convert(parsed.value),
      insights: _jsonInsights(
        parsed.value,
        jsonLines: parsed.jsonLines,
        normalizedJsonLike: parsed.normalizedJsonLike,
        extractedDescription: parsed.extractedDescription,
      ),
    );
  }

  _ParsedJsonInput _parseJsonInput(String input) {
    final extracted = _extractJsonInput(input.replaceFirst('\ufeff', ''));
    final normalized = extracted.value.trim();
    if (normalized.isEmpty) throw const FormatException('请输入 JSON 文本');
    try {
      final decoded = json.decode(normalized);
      final decodedString = _tryParseJsonStringValue(
        decoded,
        extracted.description,
      );
      if (decodedString != null) return decodedString;
      return _ParsedJsonInput(
        value: decoded,
        jsonLines: false,
        normalizedJsonLike: false,
        extractedDescription: extracted.description,
      );
    } on FormatException catch (firstError) {
      final embeddedString = _tryParseEmbeddedJsonString(
        normalized,
        extracted.description,
      );
      if (embeddedString != null) return embeddedString;

      final lines = const LineSplitter()
          .convert(normalized)
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.length >= 2) {
        final parsedLines = _tryParseJsonLines(lines);
        if (parsedLines != null) {
          return _ParsedJsonInput(
            value: parsedLines.$1,
            jsonLines: true,
            normalizedJsonLike: parsedLines.$2,
            extractedDescription: extracted.description,
          );
        }
      }

      final jsonLike = _normalizeJsonLikeInput(normalized);
      if (jsonLike == normalized) rethrow;
      try {
        return _ParsedJsonInput(
          value: json.decode(jsonLike),
          jsonLines: false,
          normalizedJsonLike: true,
          extractedDescription: extracted.description,
        );
      } on FormatException {
        throw firstError;
      }
    }
  }

  (List<Object?>, bool)? _tryParseJsonLines(List<String> lines) {
    final records = <Object?>[];
    var normalizedJsonLike = false;
    for (final line in lines) {
      final candidate = _normalizeJsonLineCandidate(line);
      if (candidate == null) continue;
      try {
        records.add(json.decode(candidate));
      } on FormatException {
        final normalized = _normalizeJsonLikeInput(candidate);
        if (normalized == candidate) return null;
        try {
          records.add(json.decode(normalized));
          normalizedJsonLike = true;
        } on FormatException {
          return null;
        }
      }
    }
    if (records.length < 2) return null;
    return (records, normalizedJsonLike);
  }

  String? _normalizeJsonLineCandidate(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) return null;
    final withoutComments = _stripJsonLikeComments(trimmed).trim();
    if (withoutComments.isEmpty) return null;
    if (withoutComments.startsWith('#')) return null;
    final candidate =
        withoutComments.startsWith('{') || withoutComments.startsWith('[')
            ? withoutComments
            : _extractBalancedJsonCandidate(withoutComments);
    if (candidate == null) return null;
    return candidate.replaceFirst(RegExp(r',\s*$'), '');
  }

  _ParsedJsonInput? _tryParseJsonStringValue(
    Object? decoded,
    String? sourceDescription,
  ) {
    if (decoded is! String) return null;
    final parsed = _tryDecodeJsonObjectText(decoded);
    if (parsed == null) return null;
    return _ParsedJsonInput(
      value: parsed.$1,
      jsonLines: false,
      normalizedJsonLike: parsed.$2,
      extractedDescription: _jsonStringSourceDescription(sourceDescription),
    );
  }

  _ParsedJsonInput? _tryParseEmbeddedJsonString(
    String input,
    String? sourceDescription,
  ) {
    for (final candidate in _quotedStringCandidates(input)) {
      final parsed = _tryDecodeJsonObjectText(candidate);
      if (parsed == null) continue;
      return _ParsedJsonInput(
        value: parsed.$1,
        jsonLines: false,
        normalizedJsonLike: parsed.$2,
        extractedDescription: _jsonStringSourceDescription(sourceDescription),
      );
    }
    return null;
  }

  (Object?, bool)? _tryDecodeJsonObjectText(String input) {
    final trimmed = input.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
    try {
      return (json.decode(trimmed), false);
    } on FormatException {
      final normalized = _normalizeJsonLikeInput(trimmed);
      if (normalized == trimmed) return null;
      try {
        return (json.decode(normalized), true);
      } on FormatException {
        return null;
      }
    }
  }

  String _jsonStringSourceDescription(String? sourceDescription) {
    return sourceDescription == null
        ? '转义 JSON 字符串'
        : '$sourceDescription中的转义 JSON 字符串';
  }

  List<String> _quotedStringCandidates(String input) {
    final candidates = <String>[];
    for (var i = 0; i < input.length; i++) {
      final quote = input[i];
      if (quote != '"' && quote != "'" && quote != '`') continue;
      var escaping = false;
      for (var j = i + 1; j < input.length; j++) {
        final char = input[j];
        if (escaping) {
          escaping = false;
          continue;
        }
        if (char == r'\') {
          escaping = true;
          continue;
        }
        if (char != quote) continue;

        final raw = input.substring(i, j + 1);
        final body = input.substring(i + 1, j);
        if (quote == '"') {
          try {
            final decoded = json.decode(raw);
            if (decoded is String) candidates.add(decoded);
          } catch (_) {
            candidates.add(_unescapePastedQuotedString(body));
          }
        } else {
          candidates.add(_unescapePastedQuotedString(body));
        }
        i = j;
        break;
      }
    }
    return candidates;
  }

  String _unescapePastedQuotedString(String input) {
    final buffer = StringBuffer();
    var escaping = false;
    for (final codePoint in input.runes) {
      final char = String.fromCharCode(codePoint);
      if (!escaping) {
        if (char == r'\') {
          escaping = true;
        } else {
          buffer.write(char);
        }
        continue;
      }
      switch (char) {
        case 'n':
          buffer.write('\n');
          break;
        case 'r':
          buffer.write('\r');
          break;
        case 't':
          buffer.write('\t');
          break;
        case 'b':
          buffer.write('\b');
          break;
        case 'f':
          buffer.write('\f');
          break;
        default:
          buffer.write(char);
      }
      escaping = false;
    }
    if (escaping) buffer.write(r'\');
    return buffer.toString();
  }

  _ExtractedJsonInput _extractJsonInput(String input) {
    final trimmed = input.trim();
    final fence = RegExp(
      r'```(?:json|jsonc|javascript|js)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (fence != null) {
      return _ExtractedJsonInput(fence.group(1)!.trim(), 'Markdown 代码块');
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return _ExtractedJsonInput(trimmed, null);
    }

    if (_looksLikeJsonLinesPaste(trimmed)) {
      return _ExtractedJsonInput(trimmed, null);
    }

    final candidate = _extractBalancedJsonCandidate(trimmed);
    if (candidate != null) {
      return _ExtractedJsonInput(candidate, '粘贴文本');
    }
    return _ExtractedJsonInput(trimmed, null);
  }

  bool _looksLikeJsonLinesPaste(String input) {
    final lines = const LineSplitter()
        .convert(input)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2) return false;
    var records = 0;
    for (final line in lines) {
      final candidate = _normalizeJsonLineCandidate(line);
      if (candidate == null) continue;
      records++;
    }
    return records >= 2;
  }

  String? _extractBalancedJsonCandidate(String input) {
    var inString = false;
    var quote = '';
    var escaping = false;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (inString) {
        if (escaping) {
          escaping = false;
        } else if (char == r'\') {
          escaping = true;
        } else if (char == quote) {
          inString = false;
          quote = '';
        }
        continue;
      }
      if (char == '"' || char == "'" || char == '`') {
        inString = true;
        quote = char;
        continue;
      }
      if (char != '{' && char != '[') continue;
      final candidate = _balancedJsonSlice(input, i);
      if (candidate == null) continue;
      final tail = input.substring(i + candidate.length).trimLeft();
      if (!_isAllowedJsonCandidateTail(tail)) continue;
      return candidate;
    }
    return null;
  }

  bool _isAllowedJsonCandidateTail(String tail) {
    if (tail.isEmpty || tail.startsWith(';') || tail.startsWith(',')) {
      return true;
    }
    return RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]*\s*[=:]').hasMatch(tail);
  }

  String? _balancedJsonSlice(String input, int start) {
    final stack = <String>[];
    var inString = false;
    var quote = '';
    var escaping = false;

    for (var i = start; i < input.length; i++) {
      final char = input[i];
      if (inString) {
        if (escaping) {
          escaping = false;
        } else if (char == r'\') {
          escaping = true;
        } else if (char == quote) {
          inString = false;
          quote = '';
        }
        continue;
      }

      if (char == '"' || char == "'") {
        inString = true;
        quote = char;
        continue;
      }
      if (char == '{') {
        stack.add('}');
      } else if (char == '[') {
        stack.add(']');
      } else if (char == '}' || char == ']') {
        if (stack.isEmpty || stack.removeLast() != char) return null;
        if (stack.isEmpty) return input.substring(start, i + 1);
      }
    }
    return null;
  }

  String _normalizeJsonLikeInput(String input) {
    var output = _stripJsonLikeComments(input);
    output = output.replaceAllMapped(
      RegExp(r'([,{]\s*)([A-Za-z_$][A-Za-z0-9_$-]*)\s*:'),
      (match) => '${match.group(1)}"${match.group(2)}":',
    );
    output = output.replaceAllMapped(
      RegExp(r"'((?:\\.|[^'\\])*)'"),
      (match) {
        final decoded = match.group(1)!.replaceAll(r"\'", "'");
        return json.encode(decoded);
      },
    );
    output = output.replaceAllMapped(
      RegExp(r',\s*([}\]])'),
      (match) => match.group(1)!,
    );
    return output.trim();
  }

  String _stripJsonLikeComments(String input) {
    final buffer = StringBuffer();
    var inString = false;
    var quote = '';
    var escaping = false;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final next = i + 1 < input.length ? input[i + 1] : '';
      if (inString) {
        buffer.write(char);
        if (escaping) {
          escaping = false;
        } else if (char == r'\') {
          escaping = true;
        } else if (char == quote) {
          inString = false;
          quote = '';
        }
        continue;
      }
      if (char == '"' || char == "'") {
        inString = true;
        quote = char;
        buffer.write(char);
        continue;
      }
      if (char == '/' && next == '/') {
        while (i < input.length && input[i] != '\n') {
          i++;
        }
        if (i < input.length) buffer.write('\n');
        continue;
      }
      if (char == '/' && next == '*') {
        i += 2;
        while (
            i + 1 < input.length && !(input[i] == '*' && input[i + 1] == '/')) {
          i++;
        }
        i++;
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  List<String> _jsonInsights(
    Object? decoded, {
    required bool jsonLines,
    required bool normalizedJsonLike,
    required String? extractedDescription,
  }) {
    final stats = _collectJsonStats(decoded);
    return [
      if (extractedDescription != null) '已从$extractedDescription中提取 JSON。',
      if (jsonLines) '输入识别为 JSON Lines / NDJSON，已转换为数组。',
      if (normalizedJsonLike) '已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。',
      switch (decoded) {
        Map() => '顶层类型: Object，键数量: ${decoded.length}。',
        List() => '顶层类型: Array，元素数量: ${decoded.length}。',
        String() => '顶层类型: String。',
        num() => '顶层类型: Number。',
        bool() => '顶层类型: Boolean。',
        null => '顶层类型: Null。',
        _ => '顶层类型: ${decoded.runtimeType}。',
      },
      '结构: Object ${stats.objects}，Array ${stats.arrays}，标量 ${stats.scalars}。',
      '总键数: ${stats.keys}，最大深度: ${stats.maxDepth}。',
      if (stats.nulls > 0) '包含 null 值: ${stats.nulls}。',
    ];
  }

  _JsonStats _collectJsonStats(Object? value, [int depth = 1]) {
    if (value is Map) {
      var stats = _JsonStats(objects: 1, keys: value.length, maxDepth: depth);
      for (final child in value.values) {
        stats = stats.merge(_collectJsonStats(child, depth + 1));
      }
      return stats;
    }
    if (value is List) {
      var stats = _JsonStats(arrays: 1, maxDepth: depth);
      for (final child in value) {
        stats = stats.merge(_collectJsonStats(child, depth + 1));
      }
      return stats;
    }
    return _JsonStats(
      scalars: 1,
      nulls: value == null ? 1 : 0,
      maxDepth: depth,
    );
  }
}
