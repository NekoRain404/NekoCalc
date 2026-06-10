part of 'text_tool_controller.dart';

extension _TextToolBinaryTools on TextToolController {
  TextToolOutput _base64(String input) {
    final decoded = _tryDecodeBase64Input(input);
    if (decoded != null) {
      final text = decoded.text;
      final standard = base64.encode(decoded.bytes);
      final urlSafe = base64UrlEncode(decoded.bytes).replaceAll('=', '');
      return TextToolOutput(
        text ?? '${decoded.bytes.length} bytes',
        [
          if (text != null) 'UTF-8 文本长度: ${text.runes.length} 字符',
          if (text == null) '二进制内容，无法按 UTF-8 文本完整显示。',
          '字节数: ${decoded.bytes.length}',
          'HEX: ${_formatHexPreview(decoded.bytes)}',
          if (decoded.bytes.length > 64) 'HEX 仅展示前 64 bytes。',
          if (decoded.mimeType != null) 'MIME: ${decoded.mimeType}',
          '格式: ${decoded.variantLabel}',
          '标准 Base64: $standard',
          'Base64URL: $urlSafe',
          if (decoded.fromDataUrl)
            'data URL: data:${decoded.mimeType ?? 'application/octet-stream'};base64,$standard',
        ].join('\n'),
        insights: [
          decoded.description,
          if (decoded.hadWhitespace) '已忽略输入中的空白和换行。',
          if (decoded.isUrlSafe) '已识别 URL-safe 字符集，详情同时给出标准 Base64。',
          if (decoded.fromDataUrl) '详情中已重建可复制的 data URL。',
          if (text == null) '结果更适合作为二进制数据保存或继续复制 HEX。',
        ],
      );
    }

    final bytes = utf8.encode(input);
    final encoded = base64.encode(bytes);
    final urlSafe = base64UrlEncode(bytes).replaceAll('=', '');
    return TextToolOutput(
      encoded,
      [
        '检测为普通文本，已编码为标准 Base64。',
        'UTF-8 字节: ${bytes.length}',
        'Base64URL: $urlSafe',
        'data:text/plain: data:text/plain;charset=utf-8;base64,$encoded',
      ].join('\n'),
      insights: const [
        '复制主结果可直接用于标准 Base64 解码场景。',
        '详情同时提供 URL-safe 写法和 text/plain data URL。',
      ],
    );
  }

  TextToolOutput _checksum(String input) {
    final parsed = _parseByteInput(input);
    final bytes = parsed.bytes;
    final sum = bytes.fold<int>(0, (total, byte) => (total + byte) & 0xff);
    final xor = bytes.fold<int>(0, (total, byte) => total ^ byte);
    final lrc = (-bytes.fold<int>(0, (total, byte) => total + byte)) & 0xff;
    return TextToolOutput(
      'SUM8 = 0x${sum.toRadixString(16).toUpperCase().padLeft(2, '0')}',
      [
        '输入模式: ${parsed.mode}',
        '长度: ${bytes.length} bytes',
        'SUM8: $sum (0x${_hexByte(sum)})',
        'XOR8: $xor (0x${_hexByte(xor)})',
        'LRC: $lrc (0x${_hexByte(lrc)})',
        'HEX: ${_formatHexPreview(bytes)}',
        if (bytes.length > 64) 'HEX 仅展示前 64 bytes。',
      ].join('\n'),
      insights: [
        parsed.description,
        if (parsed.cleanedSeparators) '已忽略字节列表中的空白、括号或分隔符。',
      ],
    );
  }

  TextToolOutput _fnvCrc(String input) {
    final parsed = _parseByteInput(input);
    final bytes = parsed.bytes;
    var fnv = 0x811c9dc5;
    var crc = 0xffffffff;
    for (final byte in bytes) {
      fnv ^= byte;
      fnv = (fnv * 0x01000193) & 0xffffffff;
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    crc = crc ^ 0xffffffff;
    return TextToolOutput(
      'CRC32 = ${_hex32(crc)}',
      [
        '输入模式: ${parsed.mode}',
        'FNV-1a 32: ${_hex32(fnv)}',
        'CRC32: ${_hex32(crc)}',
        '长度: ${bytes.length} bytes',
        'HEX: ${_formatHexPreview(bytes)}',
        if (bytes.length > 64) 'HEX 仅展示前 64 bytes。',
      ].join('\n'),
      insights: [
        parsed.description,
        if (parsed.cleanedSeparators) '已忽略字节列表中的空白、括号或分隔符。',
      ],
    );
  }

  _ParsedBase64? _tryDecodeBase64Input(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    String? mimeType;
    var payload = trimmed;
    var fromDataUrl = false;
    String? sourceDescription;
    final dataUrlMatch = RegExp(
      r'^data:([^;,]+)?(?:;charset=[^;,]+)?;base64,(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(trimmed);
    if (dataUrlMatch != null) {
      fromDataUrl = true;
      mimeType = dataUrlMatch.group(1);
      payload = dataUrlMatch.group(2) ?? '';
      sourceDescription = '检测为 data URL Base64 输入，已提取 payload 解码。';
    }
    if (!fromDataUrl) {
      final extracted = _extractBase64Payload(trimmed);
      if (extracted != null) {
        payload = extracted.payload;
        sourceDescription = extracted.description;
      }
    }

    final compact = payload.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return null;
    final hadWhitespace = payload != compact;
    final isUrlSafe = compact.contains('-') || compact.contains('_');
    final hasExplicitMarker = hadWhitespace ||
        compact.contains('=') ||
        RegExp(r'[+/_-]').hasMatch(compact);
    if (!RegExp(r'^[A-Za-z0-9+/=_-]+$').hasMatch(compact)) return null;
    if (compact.length % 4 == 1) return null;
    if (!fromDataUrl &&
        sourceDescription == null &&
        !_looksLikeBase64(compact, isUrlSafe: isUrlSafe)) {
      return null;
    }

    try {
      final normalized =
          isUrlSafe ? base64Url.normalize(compact) : base64.normalize(compact);
      final bytes =
          isUrlSafe ? base64Url.decode(normalized) : base64.decode(normalized);
      if (bytes.isEmpty) return null;
      String? text;
      try {
        text = utf8.decode(bytes);
        if (_containsTooManyControlChars(text)) text = null;
      } on FormatException {
        text = null;
      }
      if (!fromDataUrl && !hasExplicitMarker && text == null) return null;
      return _ParsedBase64(
        bytes: bytes,
        text: text,
        mimeType: mimeType,
        fromDataUrl: fromDataUrl,
        sourceDescription: sourceDescription,
        isUrlSafe: isUrlSafe,
        hadWhitespace: hadWhitespace,
      );
    } on FormatException {
      return null;
    }
  }

  _ExtractedBase64Payload? _extractBase64Payload(String input) {
    final trimmed = input.trim();
    final markdownFence = RegExp(
      r'```(?:base64|b64|pem|text|txt)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (markdownFence != null) {
      return _ExtractedBase64Payload(
        markdownFence.group(1)!,
        '已从 Markdown 代码块中提取 Base64 payload 解码。',
      );
    }

    final pemBlock = RegExp(
      r'-----BEGIN ([^-]+)-----([\s\S]+?)-----END \1-----',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (pemBlock != null) {
      return _ExtractedBase64Payload(
        pemBlock.group(2)!,
        '已从 PEM 块中提取 Base64 payload 解码。',
      );
    }

    final quoted =
        RegExp(r'''^["'`](.+)["'`]$''', dotAll: true).firstMatch(trimmed);
    if (quoted != null) {
      return _ExtractedBase64Payload(
        quoted.group(1)!,
        '已从带标签文本中提取 Base64 payload 解码。',
      );
    }

    final leadingLabel = RegExp(
      r'^(?:base64|b64|payload)\s*[:=,]\s*(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(trimmed);
    if (leadingLabel != null) {
      return _ExtractedBase64Payload(
        _stripPayloadQuotes(leadingLabel.group(1)!),
        '已从带标签文本中提取 Base64 payload 解码。',
      );
    }

    final quotedField = RegExp(
      r'''["']?(?:base64|b64|payload|content)["']?\s*[:=]\s*["']([A-Za-z0-9+/=_\-\s]+)["']''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(trimmed);
    if (quotedField != null) {
      return _ExtractedBase64Payload(
        quotedField.group(1)!,
        '已从带标签文本中提取 Base64 payload 解码。',
      );
    }

    final unquotedField = RegExp(
      r'''(?:^|[\s{[,;])["']?(?:base64|b64|payload|content)["']?\s*[:=]\s*([A-Za-z0-9+/=_-]+)''',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (unquotedField != null) {
      return _ExtractedBase64Payload(
        unquotedField.group(1)!,
        '已从带标签文本中提取 Base64 payload 解码。',
      );
    }
    return null;
  }

  String _stripPayloadQuotes(String input) {
    final trimmed = input.trim();
    final quoted =
        RegExp(r'''^["'`](.+)["'`]$''', dotAll: true).firstMatch(trimmed);
    return quoted?.group(1) ?? trimmed;
  }

  bool _looksLikeBase64(String input, {required bool isUrlSafe}) {
    if (isUrlSafe) return input.length >= 4;
    if (input.length < 8 && !input.endsWith('=')) return false;
    if (!isUrlSafe && !input.contains('=')) {
      final hasBase64OnlyChars = RegExp(r'[+/]').hasMatch(input);
      final hasMixedCase =
          RegExp(r'[a-z]').hasMatch(input) && RegExp(r'[A-Z]').hasMatch(input);
      if (!hasBase64OnlyChars && !hasMixedCase) return false;
    }
    return true;
  }

  bool _containsTooManyControlChars(String text) {
    if (text.isEmpty) return false;
    final controls = text.runes.where((rune) {
      return rune < 0x20 && rune != 0x09 && rune != 0x0a && rune != 0x0d;
    }).length;
    return controls / text.runes.length > 0.05;
  }

  String _formatHexPreview(List<int> bytes) {
    return bytes
        .take(64)
        .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join(' ');
  }

  _ParsedByteInput _parseByteInput(String input) {
    final hex = _tryParseHexByteInput(input);
    if (hex != null) return hex;
    final decimal = _tryParseDecimalByteInput(input);
    if (decimal != null) return decimal;
    final base64Bytes = _tryParseBase64ByteInput(input);
    if (base64Bytes != null) return base64Bytes;
    return _ParsedByteInput(
      bytes: utf8.encode(input),
      mode: 'UTF-8 文本',
      description: '输入按 UTF-8 文本字节计算。',
      cleanedSeparators: false,
    );
  }

  _ParsedByteInput? _tryParseBase64ByteInput(String input) {
    final decoded = _tryDecodeBase64Input(input);
    if (decoded == null) return null;
    return _ParsedByteInput(
      bytes: decoded.bytes,
      mode: 'Base64 字节',
      description: decoded.description,
      cleanedSeparators: decoded.hadWhitespace ||
          decoded.fromDataUrl ||
          decoded.sourceDescription != null,
    );
  }

  _ParsedByteInput? _tryParseHexByteInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final normalizedInput = _normalizeAsciiLike(trimmed);
    final hexTokens = RegExp(
      r'(?:0x|\\x)[0-9a-fA-F]{1,2}|[0-9a-fA-F]{2}h\b',
      caseSensitive: false,
    ).allMatches(normalizedInput).toList();
    if (hexTokens.isNotEmpty) {
      final bytes = <int>[];
      for (final match in hexTokens) {
        if (match.end < normalizedInput.length &&
            RegExp(r'[0-9a-fA-F]').hasMatch(normalizedInput[match.end])) {
          throw const FormatException('十六进制字节需要偶数个数字。');
        }
        final token = match.group(0)!;
        final hex = token
            .replaceAll(RegExp(r'^(?:0x|\\x)', caseSensitive: false), '')
            .replaceAll(RegExp(r'h$', caseSensitive: false), '');
        bytes.add(int.parse(hex, radix: 16));
      }
      return _ParsedByteInput(
        bytes: bytes,
        mode: '十六进制字节',
        description: _hexByteDescription(trimmed, hexTokens.length),
        cleanedSeparators: true,
      );
    }

    if (_looksLikeDecimalByteList(normalizedInput)) return null;

    var normalized = normalizedInput
        .replaceAll(RegExp(r'0x', caseSensitive: false), '')
        .replaceAll(RegExp(r'\\x', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\s,;:，；：_\-]+'), '');
    if (normalized.isEmpty) return null;
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) return null;

    final explicitHex = RegExp(
          r'(^|\s)(?:0x|\\x)[0-9a-fA-F]{1,2}',
          caseSensitive: false,
        ).hasMatch(trimmed) ||
        RegExp(r'[\s,;:，；：_\-]').hasMatch(trimmed);
    if (!explicitHex && (normalized.length < 4 || normalized.length.isOdd)) {
      return null;
    }
    if (normalized.length.isOdd) {
      throw const FormatException('十六进制字节需要偶数个数字。');
    }

    final bytes = <int>[];
    for (var i = 0; i < normalized.length; i += 2) {
      bytes.add(int.parse(normalized.substring(i, i + 2), radix: 16));
    }
    return _ParsedByteInput(
      bytes: bytes,
      mode: '十六进制字节',
      description: '输入识别为十六进制字节序列。',
      cleanedSeparators: normalized.length != trimmed.length,
    );
  }

  String _hexByteDescription(String input, int count) {
    if (RegExp(
            r'\b(?:const\s+)?(?:(?:unsigned\s+)?char|uint8_t|byte)\s+\w*\s*\[|Uint8List',
            caseSensitive: false)
        .hasMatch(input)) {
      return '输入识别为代码中的十六进制字节数组，共 $count bytes。';
    }
    return '输入识别为十六进制字节序列。';
  }

  bool _looksLikeDecimalByteList(String input) {
    final source = _extractByteListBody(input) ?? input;
    if (RegExp(r'[a-fA-FxX\\]').hasMatch(source)) return false;
    if (!RegExp(r'[,\[\]{}()]').hasMatch(input)) return false;
    final tokens = RegExp(r'(?<![.\d])-?\d+(?![.\d])')
        .allMatches(source)
        .map((match) => match.group(0)!)
        .toList();
    if (tokens.length < 2) return false;
    final nonTokenText =
        source.replaceAll(RegExp(r'(?<![.\d])-?\d+(?![.\d])'), '');
    return !RegExp(r'[^,\s;，；\[\]{}()]').hasMatch(nonTokenText);
  }

  String? _extractByteListBody(String input) {
    final brace = RegExp(r'\{([^{}]*)\}').firstMatch(input);
    if (brace != null) return brace.group(1);
    final bracket = RegExp(r'\[([^\[\]]*)\]').firstMatch(input);
    if (bracket != null && RegExp(r'\d').hasMatch(bracket.group(1)!)) {
      return bracket.group(1);
    }
    return null;
  }

  _ParsedByteInput? _tryParseDecimalByteInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final normalized = _normalizeAsciiLike(trimmed);
    final source = _extractByteListBody(normalized) ?? normalized;
    if (RegExp(r'[a-zA-Z\u4e00-\u9fff]').hasMatch(source)) return null;
    if (!RegExp(r'[\s,;，；\[\]{}()]').hasMatch(normalized)) return null;

    final tokens = RegExp(r'(?<![.\d])-?\d+(?![.\d])')
        .allMatches(source)
        .map((match) => match.group(0)!)
        .toList();
    if (tokens.length < 2) return null;
    final nonTokenText =
        source.replaceAll(RegExp(r'(?<![.\d])-?\d+(?![.\d])'), '');
    if (RegExp(r'[^,\s;，；\[\]{}()]').hasMatch(nonTokenText)) return null;

    final bytes = <int>[];
    for (final token in tokens) {
      final value = int.parse(token);
      if (value < 0 || value > 255) {
        throw FormatException('十进制字节超出 0-255 范围: $value');
      }
      bytes.add(value);
    }
    return _ParsedByteInput(
      bytes: bytes,
      mode: '十进制字节',
      description: _decimalByteDescription(trimmed, bytes.length),
      cleanedSeparators: true,
    );
  }

  String _decimalByteDescription(String input, int count) {
    if (RegExp(
            r'\b(?:const\s+)?(?:(?:unsigned\s+)?char|uint8_t|byte|int)\s+\w*\s*\[|Uint8List',
            caseSensitive: false)
        .hasMatch(input)) {
      return '输入识别为代码中的十进制字节数组，共 $count bytes。';
    }
    return '输入识别为十进制字节列表。';
  }

  String _hexByte(int value) {
    return (value & 0xff).toRadixString(16).toUpperCase().padLeft(2, '0');
  }

  String _hex32(int value) =>
      '0x${(value & 0xffffffff).toRadixString(16).toUpperCase().padLeft(8, '0')}';
}
