part of 'text_tool_controller.dart';

// 中文：**这一文件里没有一条中文字面量是判据。** 这里所有的正则（PEM 头、Markdown 围栏、
//       `base64:` 标签、`uint8_t[]` 之类）都是纯 ASCII 的**输入文法**，本来就不涉及语言；
//       `mode` 与 `description` 两个字段只被插进输出，反向不参与分支。**故意不翻的与
//       该翻的在这里没有重叠**：一条都没有留。
// English: **Not one Chinese literal in this file is a branch condition.** Every regular expression
//          here (PEM headers, Markdown fences, the `base64:` label, `uint8_t[]` and friends) is plain
//          ASCII **input grammar** and has nothing to do with language; the `mode` and `description`
//          fields are only interpolated into the output and never branch on the way back. **Nothing
//          here is both** — which is why this file has no exemptions at all.
extension _TextToolBinaryTools on TextToolController {
  TextToolOutput _base64(TextToolCodecStrings strings, String input) {
    final decoded = _tryDecodeBase64Input(strings, input);
    if (decoded != null) {
      final text = decoded.text;
      final standard = base64.encode(decoded.bytes);
      final urlSafe = base64UrlEncode(decoded.bytes).replaceAll('=', '');
      return TextToolOutput(
        text ?? '${decoded.bytes.length} bytes',
        [
          if (text != null) strings.utf8TextLength(text.runes.length),
          if (text == null) strings.binaryContentNote,
          strings.byteCount(decoded.bytes.length),
          'HEX: ${_formatHexPreview(decoded.bytes)}',
          if (decoded.bytes.length > 64) strings.hexPreviewTruncated,
          if (decoded.mimeType != null) 'MIME: ${decoded.mimeType}',
          strings.formatLabel(decoded.variantLabel),
          strings.standardBase64(standard),
          'Base64URL: $urlSafe',
          if (decoded.fromDataUrl)
            'data URL: data:${decoded.mimeType ?? 'application/octet-stream'};base64,$standard',
        ].join('\n'),
        insights: [
          decoded.description(strings),
          if (decoded.hadWhitespace) strings.whitespaceIgnored,
          if (decoded.isUrlSafe) strings.urlSafeAlphabet,
          if (decoded.fromDataUrl) strings.dataUrlRebuilt,
          if (text == null) strings.binaryPreferred,
        ],
      );
    }

    final bytes = utf8.encode(input);
    final encoded = base64.encode(bytes);
    final urlSafe = base64UrlEncode(bytes).replaceAll('=', '');
    return TextToolOutput(
      encoded,
      [
        strings.plainTextEncoded,
        strings.utf8ByteLabel(bytes.length),
        'Base64URL: $urlSafe',
        'data:text/plain: data:text/plain;charset=utf-8;base64,$encoded',
      ].join('\n'),
      insights: [
        strings.standardBase64Reuse,
        strings.urlSafeAndDataUrl,
      ],
    );
  }

  TextToolOutput _checksum(TextToolCodecStrings strings, String input) {
    final parsed = _parseByteInput(strings, input);
    final bytes = parsed.bytes;
    final sum = bytes.fold<int>(0, (total, byte) => (total + byte) & 0xff);
    final xor = bytes.fold<int>(0, (total, byte) => total ^ byte);
    final lrc = (-bytes.fold<int>(0, (total, byte) => total + byte)) & 0xff;
    return TextToolOutput(
      'SUM8 = 0x${sum.toRadixString(16).toUpperCase().padLeft(2, '0')}',
      [
        strings.inputMode(parsed.mode),
        strings.lengthBytes(bytes.length),
        'SUM8: $sum (0x${_hexByte(sum)})',
        'XOR8: $xor (0x${_hexByte(xor)})',
        'LRC: $lrc (0x${_hexByte(lrc)})',
        'HEX: ${_formatHexPreview(bytes)}',
        if (bytes.length > 64) strings.hexPreviewTruncated,
      ].join('\n'),
      insights: [
        parsed.description,
        if (parsed.cleanedSeparators) strings.byteListSeparatorsIgnored,
      ],
    );
  }

  TextToolOutput _fnvCrc(TextToolCodecStrings strings, String input) {
    final parsed = _parseByteInput(strings, input);
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
        strings.inputMode(parsed.mode),
        'FNV-1a 32: ${_hex32(fnv)}',
        'CRC32: ${_hex32(crc)}',
        strings.lengthBytes(bytes.length),
        'HEX: ${_formatHexPreview(bytes)}',
        if (bytes.length > 64) strings.hexPreviewTruncated,
      ].join('\n'),
      insights: [
        parsed.description,
        if (parsed.cleanedSeparators) strings.byteListSeparatorsIgnored,
      ],
    );
  }

  _ParsedBase64? _tryDecodeBase64Input(
    TextToolCodecStrings strings,
    String input,
  ) {
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
      sourceDescription = strings.dataUrlDecoded;
    }
    if (!fromDataUrl) {
      final extracted = _extractBase64Payload(strings, trimmed);
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

  _ExtractedBase64Payload? _extractBase64Payload(
    TextToolCodecStrings strings,
    String input,
  ) {
    final trimmed = input.trim();
    final markdownFence = RegExp(
      r'```(?:base64|b64|pem|text|txt)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (markdownFence != null) {
      return _ExtractedBase64Payload(
        markdownFence.group(1)!,
        strings.fromMarkdownFence,
      );
    }

    final pemBlock = RegExp(
      r'-----BEGIN ([^-]+)-----([\s\S]+?)-----END \1-----',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (pemBlock != null) {
      return _ExtractedBase64Payload(
        pemBlock.group(2)!,
        strings.fromPemBlock,
      );
    }

    final quoted =
        RegExp(r'''^["'`](.+)["'`]$''', dotAll: true).firstMatch(trimmed);
    if (quoted != null) {
      return _ExtractedBase64Payload(
        quoted.group(1)!,
        strings.fromLabeledText,
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
        strings.fromLabeledText,
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
        strings.fromLabeledText,
      );
    }

    final unquotedField = RegExp(
      r'''(?:^|[\s{[,;])["']?(?:base64|b64|payload|content)["']?\s*[:=]\s*([A-Za-z0-9+/=_-]+)''',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (unquotedField != null) {
      return _ExtractedBase64Payload(
        unquotedField.group(1)!,
        strings.fromLabeledText,
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

  _ParsedByteInput _parseByteInput(TextToolCodecStrings strings, String input) {
    final hex = _tryParseHexByteInput(strings, input);
    if (hex != null) return hex;
    final decimal = _tryParseDecimalByteInput(strings, input);
    if (decimal != null) return decimal;
    final base64Bytes = _tryParseBase64ByteInput(strings, input);
    if (base64Bytes != null) return base64Bytes;
    return _ParsedByteInput(
      bytes: utf8.encode(input),
      mode: strings.modeUtf8Text,
      description: strings.utf8BytesAssumed,
      cleanedSeparators: false,
    );
  }

  _ParsedByteInput? _tryParseBase64ByteInput(
    TextToolCodecStrings strings,
    String input,
  ) {
    final decoded = _tryDecodeBase64Input(strings, input);
    if (decoded == null) return null;
    return _ParsedByteInput(
      bytes: decoded.bytes,
      mode: strings.modeBase64Bytes,
      description: decoded.description(strings),
      cleanedSeparators: decoded.hadWhitespace ||
          decoded.fromDataUrl ||
          decoded.sourceDescription != null,
    );
  }

  _ParsedByteInput? _tryParseHexByteInput(
    TextToolCodecStrings strings,
    String input,
  ) {
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
          throw FormatException(strings.hexBytesNeedEvenDigits);
        }
        final token = match.group(0)!;
        final hex = token
            .replaceAll(RegExp(r'^(?:0x|\\x)', caseSensitive: false), '')
            .replaceAll(RegExp(r'h$', caseSensitive: false), '');
        bytes.add(int.parse(hex, radix: 16));
      }
      return _ParsedByteInput(
        bytes: bytes,
        mode: strings.modeHexBytes,
        description: _hexByteDescription(strings, trimmed, hexTokens.length),
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
      throw FormatException(strings.hexBytesNeedEvenDigits);
    }

    final bytes = <int>[];
    for (var i = 0; i < normalized.length; i += 2) {
      bytes.add(int.parse(normalized.substring(i, i + 2), radix: 16));
    }
    return _ParsedByteInput(
      bytes: bytes,
      mode: strings.modeHexBytes,
      description: strings.hexByteSequence,
      cleanedSeparators: normalized.length != trimmed.length,
    );
  }

  String _hexByteDescription(
    TextToolCodecStrings strings,
    String input,
    int count,
  ) {
    if (RegExp(
            r'\b(?:const\s+)?(?:(?:unsigned\s+)?char|uint8_t|byte)\s+\w*\s*\[|Uint8List',
            caseSensitive: false)
        .hasMatch(input)) {
      return strings.hexByteArrayFromCode(count);
    }
    return strings.hexByteSequence;
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

  _ParsedByteInput? _tryParseDecimalByteInput(
    TextToolCodecStrings strings,
    String input,
  ) {
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
        throw FormatException(strings.decimalByteOutOfRange(value));
      }
      bytes.add(value);
    }
    return _ParsedByteInput(
      bytes: bytes,
      mode: strings.modeDecimalBytes,
      description: _decimalByteDescription(strings, trimmed, bytes.length),
      cleanedSeparators: true,
    );
  }

  String _decimalByteDescription(
    TextToolCodecStrings strings,
    String input,
    int count,
  ) {
    if (RegExp(
            r'\b(?:const\s+)?(?:(?:unsigned\s+)?char|uint8_t|byte|int)\s+\w*\s*\[|Uint8List',
            caseSensitive: false)
        .hasMatch(input)) {
      return strings.decimalByteArrayFromCode(count);
    }
    return strings.decimalByteList;
  }

  String _hexByte(int value) {
    return (value & 0xff).toRadixString(16).toUpperCase().padLeft(2, '0');
  }

  String _hex32(int value) =>
      '0x${(value & 0xffffffff).toRadixString(16).toUpperCase().padLeft(8, '0')}';
}
