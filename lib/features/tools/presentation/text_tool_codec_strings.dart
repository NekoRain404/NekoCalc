import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：编解码组的界面文案表——Base64/校验和、进制与位运算四个工具的长句。
///       **为什么控制器要接表进来**、以及**哪些中文刻意不翻**，两条理由都写在
///       `text_tool_strings.dart` 的文件头上，这里不重抄。
///
///       **这一组为什么连描述符一起改。** 这四个工具的描述文字不是就地写出的一句话，而是
///       一层层拼出来的：`_parseByteInput` 先认出输入是哪一种字节写法（`mode`），再让
///       `_hexByteDescription` / `_decimalByteDescription` 按输入里有没有 `uint8_t[]`
///       之类挑一句**识别说明**；进制那边 `_parseIntDetailed` 先定 `radixLabel`（几进制），
///       再定 `notation`（`0x 前缀` / `h 后缀` / `编程语言常量` …），最后
///       `_ParsedInteger.description` 把三段拼成 `输入识别为十六进制（0x 前缀）: 0xFF。`。
///       所以翻的不是散落的几句，是这条链上每一层的产出——表在语言之间切换时，
///       拼出来的整句也跟着换，而**拼法本身**（哪个在前、用什么括号、末尾有没有句号）
///       住在表里，不在控制器里。
///
///       **`_ParsedInteger.description` 与 `_ParsedBase64.description` 从 getter 改成
///       接表的方法**（`description(strings)`），理由与 `_ParsedUuid.versionLabel(strings)`
///       完全相同：句子是给人看的，数据（几进制、第几个字节）留在字段里。
///
///       **本表里没有判据。** 编解码组一条中文字面量都没有用在 `==` / `switch` / map key 上：
///       `mode`、`radixLabel`、`notation` 三者只被插进输出，反向不参与任何分支。
///       唯一像"判据"的地方是 `_integerTokenPattern`（十六进制字面量怎么算一个 token），
///       它是纯 ASCII 的正则，本来就不涉及语言。
/// English: The copy table for the codec group — Base64/checksums, bases and bitwise operations.
///          **Why the controller takes a table as an argument** and **which Chinese is deliberately
///          left untranslated** are both written on `text_tool_strings.dart`'s file head and not
///          copied again here.
///
///          **Why this group changes together with its descriptors.** These four tools do not write
///          their notes on the spot; the notes are assembled layer by layer. `_parseByteInput` first
///          works out which byte spelling the input is (`mode`), then `_hexByteDescription` /
///          `_decimalByteDescription` pick a **recognition note** by looking for `uint8_t[]` and
///          friends in the input. On the integer side `_parseIntDetailed` settles `radixLabel`
///          (which base) and `notation` (`0x prefix` / `h suffix` / `programming-language constant`
///          …), and `_ParsedInteger.description` then joins the three pieces into
///          `Recognised hexadecimal (0x prefix): 0xFF.`. So what gets translated is not a handful of
///          loose sentences but every layer's output along that chain — and **the way the pieces are
///          joined** (which comes first, which brackets, whether a full stop follows) lives in the
///          table rather than in the controller.
///
///          **`_ParsedInteger.description` and `_ParsedBase64.description` changed from getters into
///          methods that take the table** (`description(strings)`), for exactly the reason
///          `_ParsedUuid.versionLabel(strings)` did: the sentence is for the reader, the data (which
///          base, which byte) stays in the fields.
///
///          **This table holds no branch conditions.** Not one Chinese literal in the codec group is
///          used in an `==`, a `switch` or as a map key: `mode`, `radixLabel` and `notation` are
///          interpolated into the output and never branch on the way back. The one thing that looks
///          like a condition is `_integerTokenPattern` (what counts as one hexadecimal token), and
///          that is a plain ASCII regular expression which has nothing to do with language.
@immutable
class TextToolCodecStrings {
  const TextToolCodecStrings({
    // —— 字节输入的模式与识别说明 ——
    required this.modeUtf8Text,
    required this.modeBase64Bytes,
    required this.modeHexBytes,
    required this.modeDecimalBytes,
    required this.utf8BytesAssumed,
    required this.hexByteSequence,
    required this.decimalByteList,
    required this.hexByteArrayFromCode,
    required this.decimalByteArrayFromCode,
    required this.inputMode,
    required this.hexBytesNeedEvenDigits,
    required this.decimalByteOutOfRange,
    // —— Base64 的输出与提取来源 ——
    required this.fromMarkdownFence,
    required this.fromPemBlock,
    required this.fromLabeledText,
    required this.dataUrlDecoded,
    required this.decodedInput,
    required this.utf8TextLength,
    required this.binaryContentNote,
    required this.byteCount,
    required this.hexPreviewTruncated,
    required this.lengthBytes,
    required this.formatLabel,
    required this.standardBase64,
    // —— 校核提示 ——
    required this.whitespaceIgnored,
    required this.byteListSeparatorsIgnored,
    required this.urlSafeAlphabet,
    required this.dataUrlRebuilt,
    required this.binaryPreferred,
    required this.plainTextEncoded,
    required this.utf8ByteLabel,
    required this.standardBase64Reuse,
    required this.urlSafeAndDataUrl,
    // —— 进制：基名与写法名 ——
    required this.radixBinary,
    required this.radixOctal,
    required this.radixDecimal,
    required this.radixHexadecimal,
    required this.notationPlainDigits,
    required this.notationProgrammingConstant,
    required this.notationHexPrefix0x,
    required this.notationHexPrefixHash,
    required this.notationHexPrefixDollar,
    required this.notationHexSuffixH,
    required this.notationBinaryPrefix0b,
    required this.notationBinarySuffixB,
    required this.notationOctalPrefix0o,
    required this.notationOctalSuffixO,
    required this.notationDecimalSuffixD,
    required this.typeSuffix,
    required this.notationWithSuffix,
    required this.integerRecognised,
    // —— 进制与位运算的输出 ——
    required this.baseLines,
    required this.arbitraryBaseLine,
    required this.arbitraryBaseOutOfRange,
    required this.significantBits,
    required this.bitLengthAB,
    required this.recognisedAB,
    required this.extraIntegersIgnored,
    required this.negativeShownAsSigned,
    required this.negativeBitwiseTwosComplement,
    // —— 进制的错误 ——
    required this.integerNeeded,
    required this.twoIntegersNeeded,
    required this.invalidThousandsSeparator,
    required this.invalidIntegerFormat,
  });

  // —— 字节输入的模式与识别说明 ——
  final String modeUtf8Text;
  final String modeBase64Bytes;
  final String modeHexBytes;
  final String modeDecimalBytes;

  /// 中文：输入里既没有前缀也没有分隔符，按 UTF-8 文本字节算时那一句。
  /// English: The line used when the input has neither a prefix nor a separator and is counted as
  ///          UTF-8 text bytes.
  final String utf8BytesAssumed;
  final String hexByteSequence;
  final String decimalByteList;
  final String Function(int count) hexByteArrayFromCode;
  final String Function(int count) decimalByteArrayFromCode;

  /// 中文：`输入模式: …` 那一行的标签，值由上面四条之一给。
  /// English: The label of the `Input mode: …` line; the value comes from one of the four above.
  final String Function(String mode) inputMode;
  final String hexBytesNeedEvenDigits;
  final String Function(int value) decimalByteOutOfRange;

  // —— Base64 的输出与提取来源 ——
  final String fromMarkdownFence;
  final String fromPemBlock;
  final String fromLabeledText;
  final String dataUrlDecoded;

  /// 中文：没有更具体的来源说明时的兜底，`$variant` 是 `Base64` 或 `Base64URL`（ASCII）。
  /// English: The fallback when no more specific source note exists; `$variant` is `Base64` or
  ///          `Base64URL` (ASCII).
  final String Function(String variant) decodedInput;
  final String Function(int count) utf8TextLength;
  final String binaryContentNote;
  final String Function(int count) byteCount;
  final String hexPreviewTruncated;
  final String Function(int count) lengthBytes;

  /// 中文：`格式: Base64URL` 那一行的标签。**值本身是 ASCII，不进表**——`Base64` /
  ///       `Base64URL` 在两种语言下逐字节相同。
  /// English: The label of the `Format: Base64URL` line. **The value itself is ASCII and stays out
  ///          of the table** — `Base64` / `Base64URL` are byte-identical in both languages.
  final String Function(String variant) formatLabel;
  final String Function(String value) standardBase64;

  // —— 校核提示 ——
  final String whitespaceIgnored;
  final String byteListSeparatorsIgnored;
  final String urlSafeAlphabet;
  final String dataUrlRebuilt;
  final String binaryPreferred;
  final String plainTextEncoded;
  final String Function(int count) utf8ByteLabel;
  final String standardBase64Reuse;
  final String urlSafeAndDataUrl;

  // —— 进制：基名与写法名 ——
  final String radixBinary;
  final String radixOctal;
  final String radixDecimal;
  final String radixHexadecimal;

  /// 中文：既没有前缀也没有后缀时的写法名。原文是「数字」。
  /// English: The notation name when there is neither a prefix nor a suffix. The original reads
  ///          「数字」.
  final String notationPlainDigits;

  /// 中文：`Integer.MAX_VALUE` 这类常量的写法名。
  /// English: The notation name for constants such as `Integer.MAX_VALUE`.
  final String notationProgrammingConstant;
  final String notationHexPrefix0x;
  final String notationHexPrefixHash;
  final String notationHexPrefixDollar;
  final String notationHexSuffixH;
  final String notationBinaryPrefix0b;
  final String notationBinarySuffixB;
  final String notationOctalPrefix0o;
  final String notationOctalSuffixO;
  final String notationDecimalSuffixD;

  /// 中文：`UL` / `LLU` 这类后缀的说法。**后缀名本身是 ASCII**，只有「类型后缀」三个字走表。
  /// English: The wording for a suffix such as `UL` / `LLU`. **The suffix itself is ASCII**; only
  ///          the words 「类型后缀」 go through the table.
  final String Function(String name) typeSuffix;

  /// 中文：写法名与类型后缀同时出现时的连接。中文用「，」、英文用「, 」——**分隔符住在表里**，
  ///       因为它本身就是要翻译的东西的一部分。
  /// English: The join used when a notation name and a type suffix both appear. Chinese uses 「，」
  ///          and English uses 「, 」 — **the separator lives in the table** because it is part of
  ///          what is being translated.
  final String Function(String notation, String suffix) notationWithSuffix;

  /// 中文：`输入识别为十六进制（0x 前缀）: 0xFF。` 整句，三段都由调用方先取好。
  /// English: The whole `Recognised hexadecimal (0x prefix): 0xFF.` sentence; the caller resolves
  ///          all three pieces first.
  final String Function(String radixLabel, String notation, String token)
      integerRecognised;

  // —— 进制与位运算的输出 ——
  /// 中文：四种进制 + **罗马数字**那五行。第五个参数是 `null` 时印"没有规范写法"——
  ///       判据在 [toRoman] 那一处（`1..3999` 之外回 `null`），**这句话不重做那个判断**。
  /// English: the five lines — four bases plus **Roman numerals**. A `null` fifth argument prints "no
  ///          canonical spelling"; the judgement lives in [toRoman] (outside `1..3999` it returns
  ///          `null`) and **this sentence does not redo it**.
  final String Function(String binary, String octal, String decimal, String hex,
      String? roman, String? extraBase) baseLines;
  /// 中文：**任意进制那一行**（输入里写了 `base <n>` 时才出现）。`n` 单独印出来是因为
  ///       屏幕上没有别的记号能说明这一行是几进制。
  /// English: **the arbitrary-base line** (present only when the input says `base <n>`). The `n` is
  ///          printed because nothing else on screen would say which base this line is.
  final String Function(int radix, String digits) arbitraryBaseLine;

  /// 中文：`base <n>` 里的 `n` 不在 `2..36` 时说的话。**如实拒绝**，不回退成别的进制。
  /// English: said when the `n` in `base <n>` is outside `2..36`. **An honest refusal** — it does not
  ///          fall back to another base.
  final String arbitraryBaseOutOfRange;

  final String Function(int bits) significantBits;
  final String Function(int a, int b) bitLengthAB;
  final String Function(String a, String b) recognisedAB;
  final String extraIntegersIgnored;
  final String negativeShownAsSigned;
  final String negativeBitwiseTwosComplement;

  // —— 进制的错误 ——
  final String integerNeeded;
  final String twoIntegersNeeded;
  final String invalidThousandsSeparator;
  final String Function(String input) invalidIntegerFormat;

  static TextToolCodecStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  static TextToolCodecStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => codecZh,
      AppLanguage.en => codecEn,
    };
  }

  static final TextToolCodecStrings codecZh = TextToolCodecStrings(
    modeUtf8Text: 'UTF-8 文本',
    modeBase64Bytes: 'Base64 字节',
    modeHexBytes: '十六进制字节',
    modeDecimalBytes: '十进制字节',
    utf8BytesAssumed: '输入按 UTF-8 文本字节计算。',
    hexByteSequence: '输入识别为十六进制字节序列。',
    decimalByteList: '输入识别为十进制字节列表。',
    hexByteArrayFromCode: (count) => '输入识别为代码中的十六进制字节数组，共 $count bytes。',
    decimalByteArrayFromCode: (count) => '输入识别为代码中的十进制字节数组，共 $count bytes。',
    inputMode: (mode) => '输入模式: $mode',
    hexBytesNeedEvenDigits: '十六进制字节需要偶数个数字。',
    decimalByteOutOfRange: (value) => '十进制字节超出 0-255 范围: $value',
    fromMarkdownFence: '已从 Markdown 代码块中提取 Base64 payload 解码。',
    fromPemBlock: '已从 PEM 块中提取 Base64 payload 解码。',
    fromLabeledText: '已从带标签文本中提取 Base64 payload 解码。',
    dataUrlDecoded: '检测为 data URL Base64 输入，已提取 payload 解码。',
    decodedInput: (variant) => '检测为 $variant 输入，已解码。',
    utf8TextLength: (count) => 'UTF-8 文本长度: $count 字符',
    binaryContentNote: '二进制内容，无法按 UTF-8 文本完整显示。',
    byteCount: (count) => '字节数: $count',
    hexPreviewTruncated: 'HEX 仅展示前 64 bytes。',
    lengthBytes: (count) => '长度: $count bytes',
    formatLabel: (variant) => '格式: $variant',
    standardBase64: (value) => '标准 Base64: $value',
    whitespaceIgnored: '已忽略输入中的空白和换行。',
    byteListSeparatorsIgnored: '已忽略字节列表中的空白、括号或分隔符。',
    urlSafeAlphabet: '已识别 URL-safe 字符集，详情同时给出标准 Base64。',
    dataUrlRebuilt: '详情中已重建可复制的 data URL。',
    binaryPreferred: '结果更适合作为二进制数据保存或继续复制 HEX。',
    plainTextEncoded: '检测为普通文本，已编码为标准 Base64。',
    utf8ByteLabel: (count) => 'UTF-8 字节: $count',
    standardBase64Reuse: '复制主结果可直接用于标准 Base64 解码场景。',
    urlSafeAndDataUrl: '详情同时提供 URL-safe 写法和 text/plain data URL。',
    radixBinary: '二进制',
    radixOctal: '八进制',
    radixDecimal: '十进制',
    radixHexadecimal: '十六进制',
    notationPlainDigits: '数字',
    notationProgrammingConstant: '编程语言常量',
    notationHexPrefix0x: '0x 前缀',
    notationHexPrefixHash: '# 前缀',
    notationHexPrefixDollar: r'$ 前缀',
    notationHexSuffixH: 'h 后缀',
    notationBinaryPrefix0b: '0b 前缀',
    notationBinarySuffixB: 'b 后缀',
    notationOctalPrefix0o: '0o 前缀',
    notationOctalSuffixO: 'o 后缀',
    notationDecimalSuffixD: 'd 后缀',
    typeSuffix: (name) => '$name 类型后缀',
    notationWithSuffix: (notation, suffix) => '$notation，$suffix',
    integerRecognised: (radixLabel, notation, token) =>
        '输入识别为$radixLabel（$notation）: $token。',
    baseLines: (binary, octal, decimal, hex, roman, extraBase) =>
        '二进制: $binary\n八进制: $octal\n十进制: $decimal\n十六进制: $hex\n'
        '罗马数字: ${roman ?? '这个数没有规范写法（规范范围 1..3999）'}'
        '${extraBase == null ? '' : '\n$extraBase'}',
    arbitraryBaseLine: (radix, digits) => '$radix 进制: $digits',
    arbitraryBaseOutOfRange: '目标进制要在 2 到 36 之间',
    significantBits: (bits) => '有效位数: $bits bit。',
    bitLengthAB: (a, b) => 'A 位数: $a bit，B 位数: $b bit。',
    recognisedAB: (a, b) => 'A 识别为$a，B 识别为$b。',
    extraIntegersIgnored: '检测到多个整数，已使用前两个。',
    negativeShownAsSigned: '负数按数学符号展示；位运算会使用整数补码语义。',
    negativeBitwiseTwosComplement: '负数位运算使用整数补码语义。',
    integerNeeded: '请输入整数',
    twoIntegersNeeded: '请输入两个整数，例如 12 5 或 A=0xF0 B=0b1010',
    invalidThousandsSeparator: '整数千位分隔符格式不正确',
    invalidIntegerFormat: (input) => '整数格式无效: $input',
  );

  static final TextToolCodecStrings codecEn = TextToolCodecStrings(
    modeUtf8Text: 'UTF-8 text',
    modeBase64Bytes: 'Base64 bytes',
    modeHexBytes: 'Hexadecimal bytes',
    modeDecimalBytes: 'Decimal bytes',
    utf8BytesAssumed: 'The input was counted as UTF-8 text bytes.',
    hexByteSequence: 'Recognised a hexadecimal byte sequence.',
    decimalByteList: 'Recognised a decimal byte list.',
    hexByteArrayFromCode: (count) =>
        'Recognised a hexadecimal byte array in code, $count bytes.',
    decimalByteArrayFromCode: (count) =>
        'Recognised a decimal byte array in code, $count bytes.',
    inputMode: (mode) => 'Input mode: $mode',
    hexBytesNeedEvenDigits:
        'Hexadecimal bytes need an even number of digits.',
    decimalByteOutOfRange: (value) =>
        'Decimal byte outside the 0-255 range: $value',
    fromMarkdownFence:
        'Extracted the Base64 payload from a Markdown code fence and decoded it.',
    fromPemBlock:
        'Extracted the Base64 payload from a PEM block and decoded it.',
    fromLabeledText:
        'Extracted the Base64 payload from labelled text and decoded it.',
    dataUrlDecoded:
        'Detected a data URL Base64 input; extracted the payload and decoded it.',
    decodedInput: (variant) => 'Detected $variant input and decoded it.',
    utf8TextLength: (count) => 'UTF-8 text length: $count characters',
    binaryContentNote:
        'Binary content; it cannot be shown in full as UTF-8 text.',
    byteCount: (count) => 'Bytes: $count',
    hexPreviewTruncated: 'HEX shows only the first 64 bytes.',
    lengthBytes: (count) => 'Length: $count bytes',
    formatLabel: (variant) => 'Format: $variant',
    standardBase64: (value) => 'Standard Base64: $value',
    whitespaceIgnored: 'Whitespace and line breaks in the input were ignored.',
    byteListSeparatorsIgnored:
        'Whitespace, brackets or separators in the byte list were ignored.',
    urlSafeAlphabet:
        'URL-safe alphabet detected; the detail also gives standard Base64.',
    dataUrlRebuilt: 'A copyable data URL was rebuilt in the detail.',
    binaryPreferred:
        'The result is better kept as binary data, or copied on as HEX.',
    plainTextEncoded: 'Detected plain text; encoded it as standard Base64.',
    utf8ByteLabel: (count) => 'UTF-8 bytes: $count',
    standardBase64Reuse:
        'The primary result can be copied straight into a standard Base64 decoder.',
    urlSafeAndDataUrl:
        'The detail also gives the URL-safe spelling and a text/plain data URL.',
    radixBinary: 'Binary',
    radixOctal: 'Octal',
    radixDecimal: 'Decimal',
    radixHexadecimal: 'Hexadecimal',
    notationPlainDigits: 'plain digits',
    notationProgrammingConstant: 'programming-language constant',
    notationHexPrefix0x: '0x prefix',
    notationHexPrefixHash: '# prefix',
    notationHexPrefixDollar: r'$ prefix',
    notationHexSuffixH: 'h suffix',
    notationBinaryPrefix0b: '0b prefix',
    notationBinarySuffixB: 'b suffix',
    notationOctalPrefix0o: '0o prefix',
    notationOctalSuffixO: 'o suffix',
    notationDecimalSuffixD: 'd suffix',
    typeSuffix: (name) => '$name type suffix',
    notationWithSuffix: (notation, suffix) => '$notation, $suffix',
    integerRecognised: (radixLabel, notation, token) =>
        'Recognised $radixLabel ($notation): $token.',
    baseLines: (binary, octal, decimal, hex, roman, extraBase) =>
        'Binary: $binary\nOctal: $octal\nDecimal: $decimal\nHexadecimal: $hex\n'
        'Roman: ${roman ?? 'this number has no canonical spelling (range 1..3999)'}'
        '${extraBase == null ? '' : '\n$extraBase'}',
    arbitraryBaseLine: (radix, digits) => 'Base $radix: $digits',
    arbitraryBaseOutOfRange: 'The target base must be between 2 and 36',
    significantBits: (bits) => 'Significant bits: $bits bit.',
    bitLengthAB: (a, b) => 'A has $a bit, B has $b bit.',
    recognisedAB: (a, b) => 'A recognised as $a, B recognised as $b.',
    extraIntegersIgnored:
        'More than two integers were found; the first two were used.',
    negativeShownAsSigned:
        'Negative values are shown with their mathematical sign; bitwise operations use two\'s-complement semantics.',
    negativeBitwiseTwosComplement:
        'Negative operands make the bitwise operations use two\'s-complement semantics.',
    integerNeeded: 'Enter an integer',
    twoIntegersNeeded:
        'Enter two integers, for example 12 5 or A=0xF0 B=0b1010',
    invalidThousandsSeparator:
        'The thousands separators are not grouped correctly',
    invalidIntegerFormat: (input) => 'Invalid integer format: $input',
  );
}
