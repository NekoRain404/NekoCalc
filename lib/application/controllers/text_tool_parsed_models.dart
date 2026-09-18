part of 'text_tool_controller.dart';

/// 中文：本文件里的解析结果模型。**它们大多不带语言**——`_ParsedColor.red`、`_TextLineStats.lines`
///       是数据，不是句子。带语言的只有两处，都做成**接表的方法**而不是就地写中文的 getter：
///       `_ParsedUuid.versionLabel(strings)` 与 `_ParsedUuid.variantLabel(strings)`。
///
///       **还剩两处中文留在原地**：`_ParsedInteger.description` 与 `_ParsedBase64.description`。
///       它们属于编解码组（进制、Base64/校验和），那一组整组共用 `_ParsedByteInput` /
///       `_ParsedInteger` 的描述符机制，要连同描述符一起改，本轮没动——**已知残留**，
///       不是漏翻。
/// English: The parse-result models in this file. **Most carry no language** —
///          `_ParsedColor.red` and `_TextLineStats.lines` are data, not sentences. Only two places
///          carry any, and both are **methods that take a table** rather than getters writing Chinese
///          in place: `_ParsedUuid.versionLabel(strings)` and `_ParsedUuid.variantLabel(strings)`.
///
///          **Two places are still Chinese in place**: `_ParsedInteger.description` and
///          `_ParsedBase64.description`. They belong to the codec group (bases, Base64/checksums),
///          which shares the `_ParsedByteInput` / `_ParsedInteger` descriptor machinery and has to be
///          changed together with it, so it was left alone this round — a **known remainder**, not a
///          missed translation.
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

  /// 中文：版本那一行的说法。**这里取 `TextToolTextStrings` 而不是就地写中文**：整段详情会被
  ///       复制进笔记，`版本: 4（随机）` 和 `Version: 4 (random)` 是同一件事的两种说法。
  ///       版本号本身是数据（UUID 里第 13 个十六进制位），只有那句话走表。
  /// English: The wording of the version line. **It reads `TextToolTextStrings` rather than writing
  ///          Chinese in place**: the whole detail block is copied into notes, and `版本: 4（随机）`
  ///          and `Version: 4 (random)` are two ways of saying the same thing. The version number
  ///          itself is data (the 13th hex digit of the UUID); only the sentence goes through the
  ///          table.
  String versionLabel(TextToolTextStrings strings) {
    final version = int.parse(hex[12], radix: 16);
    return switch (version) {
      1 => strings.uuidVersion1,
      2 => strings.uuidVersion2,
      3 => strings.uuidVersion3,
      4 => strings.uuidVersion4,
      5 => strings.uuidVersion5,
      6 => strings.uuidVersion6,
      7 => strings.uuidVersion7,
      8 => strings.uuidVersion8,
      _ => strings.uuidVersionOther(version),
    };
  }

  /// 中文：变体那一行的说法，理由同 [versionLabel]。`RFC 4122 / RFC 9562` 是规范号、
  ///       不是译文，两种语言下逐字节相同。
  /// English: The wording of the variant line, for the same reason as [versionLabel].
  ///          `RFC 4122 / RFC 9562` is a specification number rather than a translation, so it is
  ///          byte-identical in both languages.
  String variantLabel(TextToolTextStrings strings) {
    final value = int.parse(hex[16], radix: 16);
    if ((value & 0x8) == 0) return strings.uuidVariantNcs;
    if ((value & 0xc) == 0x8) return strings.uuidVariantRfc;
    if ((value & 0xe) == 0xc) return strings.uuidVariantMicrosoft;
    return strings.uuidVariantFuture;
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
