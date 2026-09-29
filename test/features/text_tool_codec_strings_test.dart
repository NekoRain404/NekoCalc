import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';

/// 中文：编解码组那张表的第 1、2 条护栏——**逐条写出中文原文，再两侧比一遍**。
///       第 3 条（源码扫描）与两条屏幕用例在 `text_tool_strings_test.dart` 里，那一份带着扫描器，
///       这一份不需要再抄一遍：扫描器扫的是**文件**，而这里多出来的只是**表条目**。
///       文件头的完整理由见 `text_tool_strings.dart`。
/// English: Clauses 1 and 2 of the guard rails for the codec table — **every Chinese entry written
///          out, then both sides compared**. Clause 3 (the source scan) and the two screen cases live
///          in `text_tool_strings_test.dart`, which carries the scanner; this file does not need a
///          second copy of it, because the scanner scans **files** while what is new here is only
///          **table entries**. The full reasoning is on `text_tool_strings.dart`'s file head.
void main() {
  final codecZh = TextToolStrings.textToolZh.codec;
  final codecEn = TextToolStrings.textToolEn.codec;

  test('编解码组中文表与迁移前源码里那些字逐字节相同', () {
    // —— 字节输入的模式与识别说明 ——
    expect(codecZh.modeUtf8Text, 'UTF-8 文本');
    expect(codecZh.modeBase64Bytes, 'Base64 字节');
    expect(codecZh.modeHexBytes, '十六进制字节');
    expect(codecZh.modeDecimalBytes, '十进制字节');
    expect(codecZh.utf8BytesAssumed, '输入按 UTF-8 文本字节计算。');
    expect(codecZh.hexByteSequence, '输入识别为十六进制字节序列。');
    expect(codecZh.decimalByteList, '输入识别为十进制字节列表。');
    expect(codecZh.hexByteArrayFromCode(3), '输入识别为代码中的十六进制字节数组，共 3 bytes。');
    expect(codecZh.decimalByteArrayFromCode(3), '输入识别为代码中的十进制字节数组，共 3 bytes。');
    expect(codecZh.inputMode('十六进制字节'), '输入模式: 十六进制字节');
    expect(codecZh.hexBytesNeedEvenDigits, '十六进制字节需要偶数个数字。');
    expect(codecZh.decimalByteOutOfRange(300), '十进制字节超出 0-255 范围: 300');
    // —— Base64 的输出与提取来源 ——
    expect(codecZh.fromMarkdownFence, '已从 Markdown 代码块中提取 Base64 payload 解码。');
    expect(codecZh.fromPemBlock, '已从 PEM 块中提取 Base64 payload 解码。');
    expect(codecZh.fromLabeledText, '已从带标签文本中提取 Base64 payload 解码。');
    expect(codecZh.dataUrlDecoded, '检测为 data URL Base64 输入，已提取 payload 解码。');
    expect(codecZh.decodedInput('Base64URL'), '检测为 Base64URL 输入，已解码。');
    expect(codecZh.utf8TextLength(3), 'UTF-8 文本长度: 3 字符');
    expect(codecZh.binaryContentNote, '二进制内容，无法按 UTF-8 文本完整显示。');
    expect(codecZh.byteCount(3), '字节数: 3');
    expect(codecZh.hexPreviewTruncated, 'HEX 仅展示前 64 bytes。');
    expect(codecZh.lengthBytes(3), '长度: 3 bytes');
    expect(codecZh.formatLabel('Base64URL'), '格式: Base64URL');
    expect(codecZh.standardBase64('QQ=='), '标准 Base64: QQ==');
    // —— 校核提示 ——
    expect(codecZh.whitespaceIgnored, '已忽略输入中的空白和换行。');
    expect(codecZh.byteListSeparatorsIgnored, '已忽略字节列表中的空白、括号或分隔符。');
    expect(codecZh.urlSafeAlphabet, '已识别 URL-safe 字符集，详情同时给出标准 Base64。');
    expect(codecZh.dataUrlRebuilt, '详情中已重建可复制的 data URL。');
    expect(codecZh.binaryPreferred, '结果更适合作为二进制数据保存或继续复制 HEX。');
    expect(codecZh.plainTextEncoded, '检测为普通文本，已编码为标准 Base64。');
    expect(codecZh.utf8ByteLabel(3), 'UTF-8 字节: 3');
    expect(codecZh.standardBase64Reuse, '复制主结果可直接用于标准 Base64 解码场景。');
    expect(codecZh.urlSafeAndDataUrl, '详情同时提供 URL-safe 写法和 text/plain data URL。');
    // —— 进制：基名与写法名 ——
    expect(codecZh.radixBinary, '二进制');
    expect(codecZh.radixOctal, '八进制');
    expect(codecZh.radixDecimal, '十进制');
    expect(codecZh.radixHexadecimal, '十六进制');
    expect(codecZh.notationPlainDigits, '数字');
    expect(codecZh.notationProgrammingConstant, '编程语言常量');
    expect(codecZh.notationHexPrefix0x, '0x 前缀');
    expect(codecZh.notationHexPrefixHash, '# 前缀');
    expect(codecZh.notationHexPrefixDollar, r'$ 前缀');
    expect(codecZh.notationHexSuffixH, 'h 后缀');
    expect(codecZh.notationBinaryPrefix0b, '0b 前缀');
    expect(codecZh.notationBinarySuffixB, 'b 后缀');
    expect(codecZh.notationOctalPrefix0o, '0o 前缀');
    expect(codecZh.notationOctalSuffixO, 'o 后缀');
    expect(codecZh.notationDecimalSuffixD, 'd 后缀');
    expect(codecZh.typeSuffix('UL'), 'UL 类型后缀');
    expect(codecZh.notationWithSuffix('0x 前缀', 'UL 类型后缀'), '0x 前缀，UL 类型后缀');
    expect(
        codecZh.integerRecognised('十六进制', '0x 前缀', '0xFF'), '输入识别为十六进制（0x 前缀）: 0xFF。');
    // —— 进制与位运算的输出 ——
    // 中文：**第五行是这一轮新加的罗马数字。** 两个分支都要钉：有写法的那一支与
    //       `null`（规范范围之外）的那一支。
    // English: **the fifth line is this round's Roman numerals.** Both branches are pinned: the one
    //          with a spelling and the `null` one (outside the canonical range).
    expect(codecZh.baseLines('1010', '12', '10', 'A', 'X', null),
        '二进制: 1010\n八进制: 12\n十进制: 10\n十六进制: A\n罗马数字: X');
    expect(codecZh.baseLines('0', '0', '0', '0', null, null),
        '二进制: 0\n八进制: 0\n十进制: 0\n十六进制: 0\n'
        '罗马数字: 这个数没有规范写法（规范范围 1..3999）');
    // 中文：**第六行是"用户点名的那个进制"**，只有写了 `base <n>` 才有，所以两个分支都要钉。
    // English: **the sixth line is "the base the user named"**, present only with `base <n>`, so both
    //          branches are pinned.
    expect(codecZh.baseLines('1010', '12', '10', 'A', 'X', '7 进制: 13'),
        endsWith('罗马数字: X\n7 进制: 13'));
    expect(codecZh.baseLines('1', '1', '1', '1', 'I', null),
        endsWith('罗马数字: I'));
    expect(codecZh.significantBits(4), '有效位数: 4 bit。');
    expect(codecZh.bitLengthAB(4, 8), 'A 位数: 4 bit，B 位数: 8 bit。');
    expect(codecZh.recognisedAB('十进制', '十六进制'), 'A 识别为十进制，B 识别为十六进制。');
    expect(codecZh.extraIntegersIgnored, '检测到多个整数，已使用前两个。');
    expect(codecZh.negativeShownAsSigned, '负数按数学符号展示；位运算会使用整数补码语义。');
    expect(codecZh.negativeBitwiseTwosComplement, '负数位运算使用整数补码语义。');
    // —— 进制的错误 ——
    expect(codecZh.integerNeeded, '请输入整数');
    expect(codecZh.twoIntegersNeeded, '请输入两个整数，例如 12 5 或 A=0xF0 B=0b1010');
    expect(codecZh.invalidThousandsSeparator, '整数千位分隔符格式不正确');
    expect(codecZh.invalidIntegerFormat('xyz'), '整数格式无效: xyz');
  });

  test('编解码组的英文侧都没有汉字、没有空串，而且真的换了', () {
    final pairs = <String, List<String>>{
      'modeUtf8Text': [codecZh.modeUtf8Text, codecEn.modeUtf8Text],
      'modeBase64Bytes': [codecZh.modeBase64Bytes, codecEn.modeBase64Bytes],
      'modeHexBytes': [codecZh.modeHexBytes, codecEn.modeHexBytes],
      'modeDecimalBytes': [codecZh.modeDecimalBytes, codecEn.modeDecimalBytes],
      'utf8BytesAssumed': [codecZh.utf8BytesAssumed, codecEn.utf8BytesAssumed],
      'hexByteSequence': [codecZh.hexByteSequence, codecEn.hexByteSequence],
      'decimalByteList': [codecZh.decimalByteList, codecEn.decimalByteList],
      'hexByteArrayFromCode': [
        codecZh.hexByteArrayFromCode(3),
        codecEn.hexByteArrayFromCode(3)
      ],
      'decimalByteArrayFromCode': [
        codecZh.decimalByteArrayFromCode(3),
        codecEn.decimalByteArrayFromCode(3)
      ],
      'inputMode': [codecZh.inputMode('X'), codecEn.inputMode('X')],
      'hexBytesNeedEvenDigits': [
        codecZh.hexBytesNeedEvenDigits,
        codecEn.hexBytesNeedEvenDigits
      ],
      'decimalByteOutOfRange': [
        codecZh.decimalByteOutOfRange(300),
        codecEn.decimalByteOutOfRange(300)
      ],
      'fromMarkdownFence': [codecZh.fromMarkdownFence, codecEn.fromMarkdownFence],
      'fromPemBlock': [codecZh.fromPemBlock, codecEn.fromPemBlock],
      'fromLabeledText': [codecZh.fromLabeledText, codecEn.fromLabeledText],
      'dataUrlDecoded': [codecZh.dataUrlDecoded, codecEn.dataUrlDecoded],
      'decodedInput': [
        codecZh.decodedInput('Base64'),
        codecEn.decodedInput('Base64')
      ],
      'utf8TextLength': [
        codecZh.utf8TextLength(3),
        codecEn.utf8TextLength(3)
      ],
      'binaryContentNote': [codecZh.binaryContentNote, codecEn.binaryContentNote],
      'byteCount': [codecZh.byteCount(3), codecEn.byteCount(3)],
      'hexPreviewTruncated': [
        codecZh.hexPreviewTruncated,
        codecEn.hexPreviewTruncated
      ],
      'lengthBytes': [codecZh.lengthBytes(3), codecEn.lengthBytes(3)],
      'formatLabel': [
        codecZh.formatLabel('Base64'),
        codecEn.formatLabel('Base64')
      ],
      'standardBase64': [
        codecZh.standardBase64('QQ=='),
        codecEn.standardBase64('QQ==')
      ],
      'whitespaceIgnored': [codecZh.whitespaceIgnored, codecEn.whitespaceIgnored],
      'byteListSeparatorsIgnored': [
        codecZh.byteListSeparatorsIgnored,
        codecEn.byteListSeparatorsIgnored
      ],
      'urlSafeAlphabet': [codecZh.urlSafeAlphabet, codecEn.urlSafeAlphabet],
      'dataUrlRebuilt': [codecZh.dataUrlRebuilt, codecEn.dataUrlRebuilt],
      'binaryPreferred': [codecZh.binaryPreferred, codecEn.binaryPreferred],
      'plainTextEncoded': [codecZh.plainTextEncoded, codecEn.plainTextEncoded],
      'utf8ByteLabel': [codecZh.utf8ByteLabel(3), codecEn.utf8ByteLabel(3)],
      'standardBase64Reuse': [
        codecZh.standardBase64Reuse,
        codecEn.standardBase64Reuse
      ],
      'urlSafeAndDataUrl': [codecZh.urlSafeAndDataUrl, codecEn.urlSafeAndDataUrl],
      'radixBinary': [codecZh.radixBinary, codecEn.radixBinary],
      'radixOctal': [codecZh.radixOctal, codecEn.radixOctal],
      'radixDecimal': [codecZh.radixDecimal, codecEn.radixDecimal],
      'radixHexadecimal': [codecZh.radixHexadecimal, codecEn.radixHexadecimal],
      'notationPlainDigits': [
        codecZh.notationPlainDigits,
        codecEn.notationPlainDigits
      ],
      'notationProgrammingConstant': [
        codecZh.notationProgrammingConstant,
        codecEn.notationProgrammingConstant
      ],
      'notationHexPrefix0x': [
        codecZh.notationHexPrefix0x,
        codecEn.notationHexPrefix0x
      ],
      'notationHexPrefixHash': [
        codecZh.notationHexPrefixHash,
        codecEn.notationHexPrefixHash
      ],
      'notationHexPrefixDollar': [
        codecZh.notationHexPrefixDollar,
        codecEn.notationHexPrefixDollar
      ],
      'notationHexSuffixH': [
        codecZh.notationHexSuffixH,
        codecEn.notationHexSuffixH
      ],
      'notationBinaryPrefix0b': [
        codecZh.notationBinaryPrefix0b,
        codecEn.notationBinaryPrefix0b
      ],
      'notationBinarySuffixB': [
        codecZh.notationBinarySuffixB,
        codecEn.notationBinarySuffixB
      ],
      'notationOctalPrefix0o': [
        codecZh.notationOctalPrefix0o,
        codecEn.notationOctalPrefix0o
      ],
      'notationOctalSuffixO': [
        codecZh.notationOctalSuffixO,
        codecEn.notationOctalSuffixO
      ],
      'notationDecimalSuffixD': [
        codecZh.notationDecimalSuffixD,
        codecEn.notationDecimalSuffixD
      ],
      'typeSuffix': [codecZh.typeSuffix('UL'), codecEn.typeSuffix('UL')],
      'notationWithSuffix': [
        codecZh.notationWithSuffix('0x 前缀', 'UL 类型后缀'),
        codecEn.notationWithSuffix('0x prefix', 'UL type suffix')
      ],
      'integerRecognised': [
        codecZh.integerRecognised('十六进制', '0x 前缀', '0xFF'),
        codecEn.integerRecognised('hexadecimal', '0x prefix', '0xFF')
      ],
      'baseLines': [
        codecZh.baseLines('1010', '12', '10', 'A', 'X', null),
        codecEn.baseLines('1010', '12', '10', 'A', 'X', null),
        codecZh.baseLines('0', '0', '0', '0', null, null),
        codecEn.baseLines('0', '0', '0', '0', null, null),
        codecZh.baseLines('1', '1', '1', '1', 'I', '7 进制: 13'),
        codecEn.baseLines('1', '1', '1', '1', 'I', 'Base 7: 13')
      ],
      'significantBits': [
        codecZh.significantBits(4),
        codecEn.significantBits(4)
      ],
      'bitLengthAB': [codecZh.bitLengthAB(4, 8), codecEn.bitLengthAB(4, 8)],
      'recognisedAB': [
        codecZh.recognisedAB('十进制', '十六进制'),
        codecEn.recognisedAB('Decimal', 'Hexadecimal')
      ],
      'extraIntegersIgnored': [
        codecZh.extraIntegersIgnored,
        codecEn.extraIntegersIgnored
      ],
      'negativeShownAsSigned': [
        codecZh.negativeShownAsSigned,
        codecEn.negativeShownAsSigned
      ],
      'negativeBitwiseTwosComplement': [
        codecZh.negativeBitwiseTwosComplement,
        codecEn.negativeBitwiseTwosComplement
      ],
      'integerNeeded': [codecZh.integerNeeded, codecEn.integerNeeded],
      'twoIntegersNeeded': [
        codecZh.twoIntegersNeeded,
        codecEn.twoIntegersNeeded
      ],
      'invalidThousandsSeparator': [
        codecZh.invalidThousandsSeparator,
        codecEn.invalidThousandsSeparator
      ],
      'invalidIntegerFormat': [
        codecZh.invalidIntegerFormat('xyz'),
        codecEn.invalidIntegerFormat('xyz')
      ],
    };

    for (final entry in pairs.entries) {
      expect(entry.value[0].trim(), isNotEmpty, reason: '${entry.key} 中文侧是空的');
      expect(entry.value[1].trim(), isNotEmpty, reason: '${entry.key} 英文侧是空的');
      expect(_containsCjk(entry.value[1]), isFalse,
          reason: '${entry.key} 英文侧还有汉字：${entry.value[1]}');
      expect(entry.value[0], isNot(entry.value[1]),
          reason: '「${entry.value[0]}」在英文表里没换');
    }
    // 中文：**编解码组没有"两侧相同"的条目。** `0x 前缀` / `Base64` 这些 ASCII 片段两侧都是
    //       ASCII，但连着的汉字（`前缀` / `格式: ` / `类型后缀`）都得换，所以整格仍然不同。
    // English: **Nothing in the codec table is identical on both sides.** The ASCII fragments such
    //          as `0x ` and `Base64` are ASCII in both, but the Chinese attached to them
    //          (「前缀」, 「格式: 」, 「类型后缀」) always changes, so every slot still differs.
    expect(pairs.length, 62,
        reason: '编解码组 62 条（Base64/校验和 33 + 进制与位运算 29），漏一条这里就会少一条');
  });
}

/// 中文：CJK 统一表意文字区（含扩展 A）。够用了：本项目的界面文案都落在这里。
/// English: The CJK Unified Ideographs block (plus Extension A) — enough, since this project's UI
///          copy lives there.
bool _containsCjk(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}
