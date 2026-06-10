part of 'text_tool_controller.dart';

class _ParsedInteger {
  const _ParsedInteger({
    required this.value,
    required this.radix,
    required this.radixLabel,
    required this.notation,
    required this.token,
  });

  final int value;
  final int radix;
  final String radixLabel;
  final String notation;
  final String token;

  String get description => '输入识别为$radixLabel（$notation）: $token。';
}

class _ParsedBase64 {
  const _ParsedBase64({
    required this.bytes,
    required this.text,
    required this.mimeType,
    required this.fromDataUrl,
    required this.sourceDescription,
    required this.isUrlSafe,
    required this.hadWhitespace,
  });

  final List<int> bytes;
  final String? text;
  final String? mimeType;
  final bool fromDataUrl;
  final String? sourceDescription;
  final bool isUrlSafe;
  final bool hadWhitespace;

  String get variantLabel => isUrlSafe ? 'Base64URL' : 'Base64';

  String get description {
    if (sourceDescription != null) return sourceDescription!;
    return '检测为 $variantLabel 输入，已解码。';
  }
}

class _ExtractedBase64Payload {
  const _ExtractedBase64Payload(this.payload, this.description);

  final String payload;
  final String description;
}

class _ParsedByteInput {
  const _ParsedByteInput({
    required this.bytes,
    required this.mode,
    required this.description,
    required this.cleanedSeparators,
  });

  final List<int> bytes;
  final String mode;
  final String description;
  final bool cleanedSeparators;
}

class _ParsedUuid {
  const _ParsedUuid({
    required this.hex,
    required this.generated,
    required this.normalizedInput,
    this.standardOverride,
    this.sourceDescription,
  });

  final String hex;
  final bool generated;
  final String normalizedInput;
  final String? standardOverride;
  final String? sourceDescription;

  String get standard => standardOverride ?? _standardFromHex(hex);

  String get versionLabel {
    final version = int.parse(hex[12], radix: 16);
    return switch (version) {
      1 => '1（时间/MAC）',
      2 => '2（DCE Security）',
      3 => '3（MD5 namespace）',
      4 => '4（随机）',
      5 => '5（SHA-1 namespace）',
      6 => '6（重排时间）',
      7 => '7（Unix 时间）',
      8 => '8（自定义）',
      _ => '$version（未知/保留）',
    };
  }

  String get variantLabel {
    final value = int.parse(hex[16], radix: 16);
    if ((value & 0x8) == 0) return 'NCS 兼容';
    if ((value & 0xc) == 0x8) return 'RFC 4122 / RFC 9562';
    if ((value & 0xe) == 0xc) return 'Microsoft 兼容';
    return '未来保留';
  }

  static String _standardFromHex(String hex) {
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class _UuidInputCandidate {
  const _UuidInputCandidate(this.value, [this.description]);

  final String value;
  final String? description;
}

class _UrlCodecResult {
  const _UrlCodecResult({
    required this.value,
    required this.mode,
    required this.decodedPlus,
    required this.encodedQuery,
    required this.queryParameterCount,
    required this.percentTripletCount,
    this.sourceDescription,
  });

  final String value;
  final String mode;
  final bool decodedPlus;
  final bool encodedQuery;
  final int queryParameterCount;
  final int percentTripletCount;
  final String? sourceDescription;
}

class _UrlCodecSource {
  const _UrlCodecSource(this.value, this.description);

  final String value;
  final String? description;
}

class _ParsedQueryInput {
  const _ParsedQueryInput({
    required this.params,
    required this.description,
    required this.usedSemicolonSeparators,
    required this.usedLineSeparators,
    this.host,
    this.path,
    this.fragment,
  });

  final Map<String, List<String>> params;
  final String description;
  final String? host;
  final String? path;
  final String? fragment;
  final bool usedSemicolonSeparators;
  final bool usedLineSeparators;
}

class _TextCharacterStats {
  const _TextCharacterStats({
    required this.cjk,
    required this.latin,
    required this.digits,
    required this.whitespace,
    required this.punctuation,
    required this.other,
  });

  final int cjk;
  final int latin;
  final int digits;
  final int whitespace;
  final int punctuation;
  final int other;
}

class _TextLineStats {
  const _TextLineStats({
    required this.lines,
    required this.nonEmptyLines,
    required this.emptyLines,
    required this.longestLine,
    required this.averageNonEmptyLineLength,
    required this.trailingWhitespaceLines,
  });

  final int lines;
  final int nonEmptyLines;
  final int emptyLines;
  final int longestLine;
  final double averageNonEmptyLineLength;
  final int trailingWhitespaceLines;
}

class _ExtractedJwtToken {
  const _ExtractedJwtToken({
    required this.token,
    this.description,
  });

  final String token;
  final String? description;
}

class _ParsedJsonInput {
  const _ParsedJsonInput({
    required this.value,
    required this.jsonLines,
    required this.normalizedJsonLike,
    required this.extractedDescription,
  });

  final Object? value;
  final bool jsonLines;
  final bool normalizedJsonLike;
  final String? extractedDescription;
}

class _ExtractedJsonInput {
  const _ExtractedJsonInput(this.value, this.description);

  final String value;
  final String? description;
}

class _JsonStats {
  const _JsonStats({
    this.objects = 0,
    this.arrays = 0,
    this.scalars = 0,
    this.keys = 0,
    this.nulls = 0,
    this.maxDepth = 0,
  });

  final int objects;
  final int arrays;
  final int scalars;
  final int keys;
  final int nulls;
  final int maxDepth;

  _JsonStats merge(_JsonStats other) {
    return _JsonStats(
      objects: objects + other.objects,
      arrays: arrays + other.arrays,
      scalars: scalars + other.scalars,
      keys: keys + other.keys,
      nulls: nulls + other.nulls,
      maxDepth: math.max(maxDepth, other.maxDepth),
    );
  }
}

class _ParsedCodePointInput {
  const _ParsedCodePointInput({
    required this.text,
    required this.count,
  });

  final String text;
  final int count;
}

class _ParsedTimestamp {
  const _ParsedTimestamp({
    required this.millisecondsSinceEpoch,
    required this.description,
  });

  final int millisecondsSinceEpoch;
  final String description;
}

class _TimestampInputCandidate {
  const _TimestampInputCandidate(this.value, [this.source]);

  final String value;
  final String? source;
}

class _ParsedColor {
  const _ParsedColor({
    required this.red,
    required this.green,
    required this.blue,
    required this.alpha,
    required this.source,
  });

  final int red;
  final int green;
  final int blue;
  final int alpha;
  final String source;
}

class _RegexInputSpec {
  const _RegexInputSpec({
    required this.pattern,
    required this.flags,
    required this.inputFlags,
    required this.text,
    required this.labeledInput,
  });

  final String pattern;
  final String flags;
  final String inputFlags;
  final String text;
  final bool labeledInput;

  String get displayFlags => inputFlags.isEmpty ? 'm' : inputFlags;

  bool get global => inputFlags.contains('g');

  bool get caseInsensitive => flags.contains('i');

  bool get multiLine => flags.isEmpty || flags.contains('m');

  bool get dotAll => flags.contains('s');

  bool get unicode => flags.contains('u');
}

class _DelimitedTable {
  const _DelimitedTable({
    required this.records,
    required this.delimiter,
    required this.quotedCells,
    required this.multilineFields,
    required this.skippedEmptyRows,
    required this.skippedMetadataRows,
    required this.skippedMarkdownSeparatorRows,
    required this.skippedAsciiTableRows,
  });

  final List<List<String>> records;
  final String delimiter;
  final int quotedCells;
  final int multilineFields;
  final int skippedEmptyRows;
  final int skippedMetadataRows;
  final int skippedMarkdownSeparatorRows;
  final int skippedAsciiTableRows;
}
