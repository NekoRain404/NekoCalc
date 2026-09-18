part of 'text_tool_controller.dart';

extension _TextToolJsonTools on TextToolController {
  TextToolOutput _jsonFormat(TextToolTextStrings strings, String input) {
    final parsed = _parseJsonInput(strings, input);
    const encoder = JsonEncoder.withIndent('  ');
    return TextToolOutput(
      parsed.jsonLines ? strings.jsonLinesValid : strings.jsonValid,
      encoder.convert(parsed.value),
      insights: _jsonInsights(
        strings,
        parsed.value,
        jsonLines: parsed.jsonLines,
        normalizedJsonLike: parsed.normalizedJsonLike,
        extractedDescription: parsed.extractedDescription,
      ),
    );
  }

  _ParsedJsonInput _parseJsonInput(TextToolTextStrings strings, String input) {
    final extracted =
        _extractJsonInput(strings, input.replaceFirst('\ufeff', ''));
    final normalized = extracted.value.trim();
    if (normalized.isEmpty) throw FormatException(strings.jsonEmpty);
    try {
      final decoded = json.decode(normalized);
      final decodedString = _tryParseJsonStringValue(
        strings,
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
        strings,
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
    TextToolTextStrings strings,
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
      extractedDescription:
          _jsonStringSourceDescription(strings, sourceDescription),
    );
  }

  _ParsedJsonInput? _tryParseEmbeddedJsonString(
    TextToolTextStrings strings,
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
        extractedDescription:
            _jsonStringSourceDescription(strings, sourceDescription),
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

  String _jsonStringSourceDescription(
    TextToolTextStrings strings,
    String? sourceDescription,
  ) {
    return sourceDescription == null
        ? strings.jsonEscapedString
        : strings.jsonEscapedStringIn(sourceDescription);
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

  _ExtractedJsonInput _extractJsonInput(
      TextToolTextStrings strings, String input) {
    final trimmed = input.trim();
    final fence = RegExp(
      r'```(?:json|jsonc|javascript|js)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (fence != null) {
      return _ExtractedJsonInput(
          fence.group(1)!.trim(), strings.jsonSourceMarkdownFence);
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return _ExtractedJsonInput(trimmed, null);
    }

    if (_looksLikeJsonLinesPaste(trimmed)) {
      return _ExtractedJsonInput(trimmed, null);
    }

    final candidate = _extractBalancedJsonCandidate(trimmed);
    if (candidate != null) {
      return _ExtractedJsonInput(candidate, strings.jsonSourcePastedText);
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
    TextToolTextStrings strings,
    Object? decoded, {
    required bool jsonLines,
    required bool normalizedJsonLike,
    required String? extractedDescription,
  }) {
    final stats = _collectJsonStats(decoded);
    return [
      if (extractedDescription != null)
        strings.jsonExtractedFrom(extractedDescription),
      if (jsonLines) strings.jsonLinesConverted,
      if (normalizedJsonLike) strings.jsonJsStyleNormalized,
      switch (decoded) {
        Map() => strings.jsonTopLevelObject(decoded.length),
        List() => strings.jsonTopLevelArray(decoded.length),
        String() => strings.jsonTopLevelString,
        num() => strings.jsonTopLevelNumber,
        bool() => strings.jsonTopLevelBoolean,
        null => strings.jsonTopLevelNull,
        _ => strings.jsonTopLevelOther('${decoded.runtimeType}'),
      },
      strings.jsonStructure(stats.objects, stats.arrays, stats.scalars),
      strings.jsonKeysAndDepth(stats.keys, stats.maxDepth),
      if (stats.nulls > 0) strings.jsonNullCount(stats.nulls),
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
