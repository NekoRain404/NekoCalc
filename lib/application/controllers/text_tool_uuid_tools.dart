part of 'text_tool_controller.dart';

extension _TextToolUuidTools on TextToolController {
  TextToolOutput _uuid(String input) {
    final parsed = input.isEmpty ? _generateUuidV4() : _parseUuid(input);
    return TextToolOutput(
      parsed.standard,
      [
        '标准: ${parsed.standard}',
        '大写: ${parsed.standard.toUpperCase()}',
        '无连字符: ${parsed.hex}',
        'URN: urn:uuid:${parsed.standard}',
        '版本: ${parsed.versionLabel}',
        'Variant: ${parsed.variantLabel}',
      ].join('\n'),
      insights: [
        parsed.generated ? '已离线生成随机 UUID v4。' : '输入 UUID 有效，已标准化。',
        if (!parsed.generated && parsed.sourceDescription != null)
          '已从${parsed.sourceDescription}中提取 UUID。',
        if (!parsed.generated && parsed.normalizedInput != parsed.standard)
          '输入已规范为小写 8-4-4-4-12 格式。',
      ],
    );
  }

  _ParsedUuid _generateUuidV4() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return _ParsedUuid(hex: hex, generated: true, normalizedInput: '');
  }

  _ParsedUuid _parseUuid(String input) {
    final extracted = _extractUuidInput(input);
    var normalized = extracted.value.trim().toLowerCase();
    if (normalized.startsWith('urn:uuid:')) {
      normalized = normalized.substring('urn:uuid:'.length);
    }
    if (normalized.startsWith('{') && normalized.endsWith('}')) {
      normalized = normalized.substring(1, normalized.length - 1);
    }
    final hex = normalized.replaceAll('-', '');
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(hex)) {
      throw const FormatException(
          '请输入有效 UUID，例如 550e8400-e29b-41d4-a716-446655440000');
    }
    final standard = _formatUuid(hex);
    final canonicalPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );
    if (normalized.contains('-') && !canonicalPattern.hasMatch(normalized)) {
      throw const FormatException('UUID 连字符位置应为 8-4-4-4-12。');
    }
    return _ParsedUuid(
      hex: hex,
      generated: false,
      normalizedInput: normalized,
      standardOverride: standard,
      sourceDescription: extracted.description,
    );
  }

  _UuidInputCandidate _extractUuidInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const _UuidInputCandidate('');

    try {
      final decoded = json.decode(trimmed);
      final found = _findUuidInJson(decoded);
      if (found != null) return _UuidInputCandidate(found, 'JSON 字段');
    } catch (_) {
      // Not JSON; continue with text extraction.
    }

    final guid = RegExp(
      r'''\b(?:guid|uuid)\s*\(\s*["']?([^"')]+)["']?\s*\)''',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (guid != null) {
      return _UuidInputCandidate(guid.group(1)!, 'Guid/UUID 调用');
    }

    final labeled = RegExp(
      r'''\b(?:guid|uuid|id)\s*[:=]\s*["']?([^"'\s,;]+)''',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (labeled != null) return _UuidInputCandidate(labeled.group(1)!, '标签文本');

    final bytes = _uuidHexFromByteArray(trimmed);
    if (bytes != null) return _UuidInputCandidate(bytes, '字节数组');

    return _UuidInputCandidate(trimmed);
  }

  String? _findUuidInJson(Object? value) {
    const preferredKeys = {'uuid', 'guid', 'id'};
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        if (!preferredKeys.contains(key)) continue;
        final candidate = entry.value;
        if (candidate is String) return candidate;
      }
      for (final child in value.values) {
        final found = _findUuidInJson(child);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findUuidInJson(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _uuidHexFromByteArray(String input) {
    final matches = RegExp(r'(?:0x|\\x)([0-9a-fA-F]{2})')
        .allMatches(input)
        .map((match) => match.group(1)!)
        .toList();
    if (matches.length != 16) return null;
    return matches.join().toLowerCase();
  }

  String _formatUuid(String hex) {
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
