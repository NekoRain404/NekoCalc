part of 'text_tool_controller.dart';

/// 中文：本文件里的解析结果模型。**它们大多不带语言**——`_ParsedColor.red`、`_TextLineStats.lines`
///       是数据，不是句子。带语言的做成**接表的方法**而不是就地写中文的 getter：
///       `_ParsedUuid.versionLabel(strings)` / `variantLabel(strings)`、
///       `_ParsedInteger.description(strings)`、`_ParsedBase64.description(strings)`。
///       理由是同一条：句子是给人看的，数据（几进制、第几个字节、版本号）留在字段里。
///
///       **描述符里那几格（`_ParsedByteInput.mode` / `description`、`_ParsedQueryInput.description`、
///       `_ParsedTimestamp.description`、`_ParsedColor.source`、`_ParsedInteger.radixLabel` /
///       `notation`）存的是"已经定好的那句话"，不是一个键。** 表顺着参数一路递进解析函数，
///       解析函数做完选择就把选中的那一句写进字段。这么做是因为同一格里的话要**拼**——
///       `_ParsedInteger.description` 把基名、写法名、token 三段接成一句，
///       `_timestampDescription` 把识别说明与来源接成两句——拼法本身也住在表里。
///
///       **`_ParsedInteger` 与 `_ParsedBase64` 的 `description` 从 getter 改成了方法**，
///       与 `_ParsedUuid.versionLabel` 同形；`_ParsedUuid.variantLabel` 反过来留在
///       `_ParsedBase64.variantLabel` 那样的 getter 形态也可以——它返回的是 ASCII
///       （`Base64` / `Base64URL`），两种语言下逐字节相同，没有可翻的字。
/// English: The parse-result models in this file. **Most carry no language** —
///          `_ParsedColor.red` and `_TextLineStats.lines` are data, not sentences. Where language is
///          carried it is a **method that takes a table** rather than a getter writing Chinese in
///          place: `_ParsedUuid.versionLabel(strings)` / `variantLabel(strings)`,
///          `_ParsedInteger.description(strings)` and `_ParsedBase64.description(strings)`. The
///          reason is always the same: the sentence is for the reader, the data (which base, which
///          byte, which version) stays in the fields.
///
///          **The descriptor slots (`_ParsedByteInput.mode` / `description`,
///          `_ParsedQueryInput.description`, `_ParsedTimestamp.description`, `_ParsedColor.source`,
///          `_ParsedInteger.radixLabel` / `notation`) hold a sentence that is already settled, not a
///          key.** The table is handed down through the parse functions, and a parse function writes
///          the sentence it chose into the field. That is so because the sentences in one slot get
///          **joined**: `_ParsedInteger.description` joins the base name, the notation name and the
///          token into one line, and `_timestampDescription` joins the recognition note with the
///          provenance — and the way they are joined lives in the table too.
///
///          **The `description` of `_ParsedInteger` and `_ParsedBase64` changed from getters into
///          methods**, the same shape as `_ParsedUuid.versionLabel`. A getter like
///          `_ParsedBase64.variantLabel` can stay a getter because it returns ASCII (`Base64` /
///          `Base64URL`), byte-identical in both languages, with no words to translate.
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

  /// 中文：基名与写法名在**解析时**就已按当前语言定好（`_parseIntDetailed` 从表里取），
  ///       所以这里存的是句子成分而不是键。`token` 是用户原文，一个字都不动。
  /// English: The base name and the notation name are settled **at parse time** in the active
  ///          language (`_parseIntDetailed` reads them from the table), so what is stored here are
  ///          sentence parts rather than keys. `token` is the user's own text and is left untouched.
  final String radixLabel;
  final String notation;
  final String token;

  /// 中文：把三段拼成 `输入识别为十六进制（0x 前缀）: 0xFF。`。**拼法住在表里**——
  ///       中英文之间括号、末尾句号与语序都不一样。
  /// English: Joins the three parts into `Recognised hexadecimal (0x prefix): 0xFF.`. **The way
  ///          they are joined lives in the table** — brackets, the closing full stop and the word
  ///          order all differ between the two languages.
  String description(TextToolCodecStrings strings) {
    return strings.integerRecognised(radixLabel, notation, token);
  }
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

  /// 中文：**留在 getter，不进表**——它返回的是 `Base64` / `Base64URL`，两种语言下逐字节相同。
  ///       它不是"漏翻的格"，是本来就没有要翻的字。
  /// English: **Stays a getter and stays out of the table** — it returns `Base64` / `Base64URL`,
  ///          byte-identical in both languages. It is not a slot that was missed; there is simply
  ///          nothing in it to translate.
  String get variantLabel => isUrlSafe ? 'Base64URL' : 'Base64';

  /// 中文：有来源说明就用来源说明（那一句在 `_extractBase64Payload` 里已经按语言定好），
  ///       否则现拼兜底那一句。兜底那一句的拼法在表里。
  /// English: Uses the source note when there is one (settled in the active language back in
  ///          `_extractBase64Payload`), otherwise builds the fallback sentence, whose shape lives in
  ///          the table.
  String description(TextToolCodecStrings strings) {
    if (sourceDescription != null) return sourceDescription!;
    return strings.decodedInput(variantLabel);
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
