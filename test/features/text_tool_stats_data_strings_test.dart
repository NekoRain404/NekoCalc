import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';

/// 中文：统计组与数据组两张表的第 1、2 条护栏——**逐条写出中文原文，再两侧比一遍**。
///       第 3 条（源码扫描）与两条屏幕用例在 `text_tool_strings_test.dart` 里，那一份带着扫描器，
///       这一份不需要再抄一遍：扫描器扫的是**文件**，而这里多出来的只是**表条目**。
///       文件头的完整理由见 `text_tool_strings.dart`。
/// English: Clauses 1 and 2 of the guard rails for the statistics and data tables — **every Chinese
///          entry written out, then both sides compared**. Clause 3 (the source scan) and the two
///          screen cases live in `text_tool_strings_test.dart`, which carries the scanner; this file
///          does not need a second copy of it, because the scanner scans **files** while what is new
///          here is only **table entries**. The full reasoning is on `text_tool_strings.dart`'s file
///          head.
void main() {
  final statsZh = TextToolStrings.textToolZh.stats;
  final statsEn = TextToolStrings.textToolEn.stats;
  final dataZh = TextToolStrings.textToolZh.data;
  final dataEn = TextToolStrings.textToolEn.data;

  test('统计组中文表与迁移前源码里那些字逐字节相同', () {
    expect(statsZh.codePointInputDetected, '检测为 Unicode 码点/转义输入，已还原为字符。');
    expect(statsZh.codePointParsed(2), '解析到 2 个码点。');
    expect(statsZh.codePointPrimary(3), '3 个码点');
    expect(statsZh.enterCharacters, '请输入字符');
    expect(statsZh.utf8ByteInsight(8), 'UTF-8 字节: 8。');
    expect(statsZh.detailFirst24, '详情仅展示前 24 个码点。');
    expect(statsZh.invalidCodePoint('U+ZZ'), 'Unicode 码点无效: U+ZZ');
    expect(statsZh.primaryCharCount(24), '24 字符');
    expect(statsZh.detailCharCount(24), '字符数: 24');
    expect(statsZh.codePointsLabel(24), 'Unicode 码点: 24');
    expect(statsZh.detailWordFragments(3), '词/片段: 3');
    expect(statsZh.detailLatinWords(2), '英文词: 2');
    expect(statsZh.detailNumberTokens(1), '数字片段: 1');
    expect(statsZh.detailLines(2), '行数: 2');
    expect(statsZh.detailNonEmptyLines(2), '非空行: 2');
    expect(statsZh.detailEmptyLines(0), '空行: 0');
    expect(statsZh.detailParagraphs(1), '段落: 1');
    expect(statsZh.utf8BytesLabel(8), 'UTF-8 字节: 8');
    expect(statsZh.detailNonWhitespaceChars(8), '去空白字符: 8');
    expect(statsZh.detailNonWhitespaceCodePoints(8), '去空白码点: 8');
    expect(statsZh.detailLongestLine(8), '最长行: 8 字符');
    expect(statsZh.detailAverageLineLength('8.00'), '平均非空行长: 8.00 字符');
    expect(statsZh.detailTrailingWhitespaceLines(1), '行尾空白: 1 行');
    expect(statsZh.detailCjk(3), '中文字符: 3');
    expect(statsZh.detailLatin(2), '拉丁字母: 2');
    expect(statsZh.detailDigits(1), '数字: 1');
    expect(statsZh.detailWhitespace(0), '空白字符: 0');
    expect(statsZh.detailPunctuation(0), '标点/符号: 0');
    expect(statsZh.detailOther(0), '其他字符: 0');
    expect(statsZh.insightBytesPerChar('1.00'), '平均每字符 1.00 bytes。');
    expect(statsZh.insightGraphemeAggregated, '已按 Unicode 可见字符聚合组合符号和 emoji。');
    expect(statsZh.insightMixedScript, '文本包含中英文混排。');
    expect(statsZh.insightMultiByte, '包含多字节 UTF-8 字符。');
    expect(statsZh.insightParagraphs(2), '检测到 2 个非空段落。');
    expect(statsZh.insightEmptyLines(1), '包含 1 个空行。');
    expect(statsZh.insightTrailingWhitespace(1), '检测到 1 行行尾空白。');
    expect(statsZh.insightAllWhitespace, '输入为空或仅包含空白字符。');
    expect(statsZh.summaryVisibleChars(3), '可见字符: 3');
    expect(statsZh.summaryUtf16Units(3), 'UTF-16 code units: 3');
    expect(statsZh.classCjk(3), '中文/汉字 3');
    expect(statsZh.classLatin(2), '拉丁字母 2');
    expect(statsZh.classDigits(1), '数字 1');
    expect(statsZh.classWhitespace(0), '空白 0');
    expect(statsZh.classPunctuation(0), '标点/符号 0');
    expect(statsZh.classOther(0), '其他 0');
    expect(statsZh.classNone, '未检测到可分类字符。');
    expect(
        statsZh.classSummary(['中文/汉字 3', '拉丁字母 2']), '字符分类: 中文/汉字 3，拉丁字母 2。');
  });

  test('数据组中文表与迁移前源码里那些字逐字节相同', () {
    // —— CSV ——
    expect(dataZh.csvNeedHeaderAndRow, '至少需要表头和一行数据。');
    expect(dataZh.rowCount(3), '3 行');
    expect(dataZh.csvDelimiterAndColumns('逗号', 2), '分隔符: 逗号，列数: 2。');
    expect(dataZh.delimiterComma, '逗号');
    expect(dataZh.delimiterSemicolon, '分号');
    expect(dataZh.delimiterPipe, '竖线');
    expect(dataZh.csvQuotedCells(2), '已处理 2 个带引号字段。');
    expect(dataZh.csvMultilineFields(1), '已保留 1 个包含换行的字段。');
    expect(dataZh.csvSkippedEmptyRows(1), '已跳过 1 个空行。');
    expect(dataZh.csvSkippedMetadataRows(2), '已跳过 2 行 CSV 元数据或注释。');
    expect(dataZh.csvSkippedMarkdownRows(1), '已跳过 1 行 Markdown 表格分隔线。');
    expect(dataZh.csvSkippedAsciiTableRows(1), '已跳过 1 行 SQL/ASCII 表格边框或尾行。');
    expect(dataZh.csvInconsistentRows('3, 5'), '第 3, 5 行列数与表头不一致。');
    expect(dataZh.csvJsonNeedsValue, 'JSON 转 CSV 至少需要一个对象或标量值。');
    expect(dataZh.csvFromJson, '输入识别为 JSON，已转换为 CSV。');
    expect(dataZh.csvJsonLinesConverted, '输入识别为 JSON Lines / NDJSON，已按多行记录转换。');
    expect(dataZh.csvColumnCount(2), '列数: 2。');
    expect(dataZh.csvTopLevelArray(3), '顶层数组元素: 3。');
    expect(dataZh.csvTopLevelObject, '顶层对象已作为 1 行数据处理。');
    expect(dataZh.csvNestedFlattened, '嵌套对象已展开为点号列名。');
    expect(dataZh.csvNestedAsText, '嵌套对象/数组已按 JSON 文本写入单元格。');
    expect(dataZh.csvUnclosedQuote, 'CSV 引号未闭合。');
    // —— JWT ——
    expect(dataZh.jwtNeedHeaderPayload, '请输入 JWT，至少包含 header.payload');
    expect(dataZh.jwtParsed, 'JWT 已解析');
    expect(dataZh.jwtSignatureSegment('32 chars'), '签名段: 32 chars');
    expect(dataZh.jwtSignatureNone, '无');
    expect(dataZh.jwtNotJsonObject('header'), 'JWT header 必须是 JSON object');
    expect(dataZh.jwtEmpty, '请输入 JWT');
    expect(dataZh.jwtFromBearer, '已从 Bearer/Authorization 文本中提取 JWT。');
    expect(dataZh.jwtFromTokenField, '已从 token 字段中提取 JWT。');
    expect(dataZh.jwtFromPastedText, '已从粘贴文本中提取 JWT。');
    expect(dataZh.jwtFromJsonField, '已从 JSON 字段中提取 JWT。');
    expect(dataZh.jwtFromCookie, '已从 Cookie 字段中提取 JWT。');
    expect(dataZh.jwtFromUrlQuery, '已从 URL query 参数中提取 JWT。');
    expect(dataZh.jwtHasSignature, '包含签名段，但未在本地校验签名。');
    expect(dataZh.jwtNoSignature, '缺少签名段，仅能查看内容。');
    expect(dataZh.jwtAlgorithm('HS256'), '算法 alg: HS256。');
    expect(dataZh.jwtType('JWT'), '类型 typ: JWT。');
    expect(dataZh.jwtAlgNone, 'alg=none，Token 不包含加密签名。');
    expect(dataZh.jwtKeyId('k1'), '包含密钥 ID kid: k1。');
    expect(dataZh.jwtExpired, 'Token 已过期。');
    expect(dataZh.jwtNotExpired, 'Token 尚未过期。');
    expect(dataZh.jwtNoExpiry, '缺少过期时间 exp。');
    expect(dataZh.jwtNotYetValid, 'Token 尚未生效。');
    expect(dataZh.jwtNbfReached, 'Token 已到 nbf 生效时间。');
    expect(dataZh.jwtHasIssuedAt, '包含签发时间 iat。');
    expect(dataZh.jwtHasAudience, '包含受众 aud。');
    expect(dataZh.jwtHasIssuer, '包含签发者 iss。');
    expect(dataZh.jwtHasSubject, '包含主题 sub。');
  });

  test('两张表的英文侧都没有汉字、没有空串，而且真的换了', () {
    final pairs = <String, List<String>>{
      // —— 统计组 ——
      'codePointInputDetected': [
        statsZh.codePointInputDetected,
        statsEn.codePointInputDetected
      ],
      'codePointParsed': [
        statsZh.codePointParsed(2),
        statsEn.codePointParsed(2)
      ],
      'codePointPrimary': [
        statsZh.codePointPrimary(3),
        statsEn.codePointPrimary(3)
      ],
      'enterCharacters': [statsZh.enterCharacters, statsEn.enterCharacters],
      'utf8ByteInsight': [
        statsZh.utf8ByteInsight(8),
        statsEn.utf8ByteInsight(8)
      ],
      'detailFirst24': [statsZh.detailFirst24, statsEn.detailFirst24],
      'invalidCodePoint': [
        statsZh.invalidCodePoint('X'),
        statsEn.invalidCodePoint('X')
      ],
      'primaryCharCount': [
        statsZh.primaryCharCount(24),
        statsEn.primaryCharCount(24)
      ],
      'detailCharCount': [
        statsZh.detailCharCount(24),
        statsEn.detailCharCount(24)
      ],
      'codePointsLabel': [
        statsZh.codePointsLabel(24),
        statsEn.codePointsLabel(24)
      ],
      'detailWordFragments': [
        statsZh.detailWordFragments(3),
        statsEn.detailWordFragments(3)
      ],
      'detailLatinWords': [
        statsZh.detailLatinWords(2),
        statsEn.detailLatinWords(2)
      ],
      'detailNumberTokens': [
        statsZh.detailNumberTokens(1),
        statsEn.detailNumberTokens(1)
      ],
      'detailLines': [statsZh.detailLines(2), statsEn.detailLines(2)],
      'detailNonEmptyLines': [
        statsZh.detailNonEmptyLines(2),
        statsEn.detailNonEmptyLines(2)
      ],
      'detailEmptyLines': [
        statsZh.detailEmptyLines(0),
        statsEn.detailEmptyLines(0)
      ],
      'detailParagraphs': [
        statsZh.detailParagraphs(1),
        statsEn.detailParagraphs(1)
      ],
      'utf8BytesLabel': [statsZh.utf8BytesLabel(8), statsEn.utf8BytesLabel(8)],
      'detailNonWhitespaceChars': [
        statsZh.detailNonWhitespaceChars(8),
        statsEn.detailNonWhitespaceChars(8)
      ],
      'detailNonWhitespaceCodePoints': [
        statsZh.detailNonWhitespaceCodePoints(8),
        statsEn.detailNonWhitespaceCodePoints(8)
      ],
      'detailLongestLine': [
        statsZh.detailLongestLine(8),
        statsEn.detailLongestLine(8)
      ],
      'detailAverageLineLength': [
        statsZh.detailAverageLineLength('8.00'),
        statsEn.detailAverageLineLength('8.00')
      ],
      'detailTrailingWhitespaceLines': [
        statsZh.detailTrailingWhitespaceLines(1),
        statsEn.detailTrailingWhitespaceLines(1)
      ],
      'detailCjk': [statsZh.detailCjk(3), statsEn.detailCjk(3)],
      'detailLatin': [statsZh.detailLatin(2), statsEn.detailLatin(2)],
      'detailDigits': [statsZh.detailDigits(1), statsEn.detailDigits(1)],
      'detailWhitespace': [
        statsZh.detailWhitespace(0),
        statsEn.detailWhitespace(0)
      ],
      'detailPunctuation': [
        statsZh.detailPunctuation(0),
        statsEn.detailPunctuation(0)
      ],
      'detailOther': [statsZh.detailOther(0), statsEn.detailOther(0)],
      'insightBytesPerChar': [
        statsZh.insightBytesPerChar('1.00'),
        statsEn.insightBytesPerChar('1.00')
      ],
      'insightGraphemeAggregated': [
        statsZh.insightGraphemeAggregated,
        statsEn.insightGraphemeAggregated
      ],
      'insightMixedScript': [
        statsZh.insightMixedScript,
        statsEn.insightMixedScript
      ],
      'insightMultiByte': [statsZh.insightMultiByte, statsEn.insightMultiByte],
      'insightParagraphs': [
        statsZh.insightParagraphs(2),
        statsEn.insightParagraphs(2)
      ],
      'insightEmptyLines': [
        statsZh.insightEmptyLines(1),
        statsEn.insightEmptyLines(1)
      ],
      'insightTrailingWhitespace': [
        statsZh.insightTrailingWhitespace(1),
        statsEn.insightTrailingWhitespace(1)
      ],
      'insightAllWhitespace': [
        statsZh.insightAllWhitespace,
        statsEn.insightAllWhitespace
      ],
      'summaryVisibleChars': [
        statsZh.summaryVisibleChars(3),
        statsEn.summaryVisibleChars(3)
      ],
      'summaryUtf16Units': [
        statsZh.summaryUtf16Units(3),
        statsEn.summaryUtf16Units(3)
      ],
      'classCjk': [statsZh.classCjk(3), statsEn.classCjk(3)],
      'classLatin': [statsZh.classLatin(2), statsEn.classLatin(2)],
      'classDigits': [statsZh.classDigits(1), statsEn.classDigits(1)],
      'classWhitespace': [
        statsZh.classWhitespace(0),
        statsEn.classWhitespace(0)
      ],
      'classPunctuation': [
        statsZh.classPunctuation(0),
        statsEn.classPunctuation(0)
      ],
      'classOther': [statsZh.classOther(0), statsEn.classOther(0)],
      'classNone': [statsZh.classNone, statsEn.classNone],
      'classSummary': [
        statsZh.classSummary(['a', 'b']),
        statsEn.classSummary(['a', 'b'])
      ],
      // —— 数据组：CSV ——
      'csvNeedHeaderAndRow': [
        dataZh.csvNeedHeaderAndRow,
        dataEn.csvNeedHeaderAndRow
      ],
      'rowCount': [dataZh.rowCount(3), dataEn.rowCount(3)],
      'csvDelimiterAndColumns': [
        dataZh.csvDelimiterAndColumns('X', 2),
        dataEn.csvDelimiterAndColumns('X', 2)
      ],
      'delimiterComma': [dataZh.delimiterComma, dataEn.delimiterComma],
      'delimiterSemicolon': [
        dataZh.delimiterSemicolon,
        dataEn.delimiterSemicolon
      ],
      'delimiterPipe': [dataZh.delimiterPipe, dataEn.delimiterPipe],
      'csvQuotedCells': [dataZh.csvQuotedCells(2), dataEn.csvQuotedCells(2)],
      'csvMultilineFields': [
        dataZh.csvMultilineFields(1),
        dataEn.csvMultilineFields(1)
      ],
      'csvSkippedEmptyRows': [
        dataZh.csvSkippedEmptyRows(1),
        dataEn.csvSkippedEmptyRows(1)
      ],
      'csvSkippedMetadataRows': [
        dataZh.csvSkippedMetadataRows(2),
        dataEn.csvSkippedMetadataRows(2)
      ],
      'csvSkippedMarkdownRows': [
        dataZh.csvSkippedMarkdownRows(1),
        dataEn.csvSkippedMarkdownRows(1)
      ],
      'csvSkippedAsciiTableRows': [
        dataZh.csvSkippedAsciiTableRows(1),
        dataEn.csvSkippedAsciiTableRows(1)
      ],
      'csvInconsistentRows': [
        dataZh.csvInconsistentRows('3'),
        dataEn.csvInconsistentRows('3')
      ],
      'csvJsonNeedsValue': [dataZh.csvJsonNeedsValue, dataEn.csvJsonNeedsValue],
      'csvFromJson': [dataZh.csvFromJson, dataEn.csvFromJson],
      'csvJsonLinesConverted': [
        dataZh.csvJsonLinesConverted,
        dataEn.csvJsonLinesConverted
      ],
      'csvColumnCount': [dataZh.csvColumnCount(2), dataEn.csvColumnCount(2)],
      'csvTopLevelArray': [
        dataZh.csvTopLevelArray(3),
        dataEn.csvTopLevelArray(3)
      ],
      'csvTopLevelObject': [dataZh.csvTopLevelObject, dataEn.csvTopLevelObject],
      'csvNestedFlattened': [
        dataZh.csvNestedFlattened,
        dataEn.csvNestedFlattened
      ],
      'csvNestedAsText': [dataZh.csvNestedAsText, dataEn.csvNestedAsText],
      'csvUnclosedQuote': [dataZh.csvUnclosedQuote, dataEn.csvUnclosedQuote],
      // —— 数据组：JWT ——
      'jwtNeedHeaderPayload': [
        dataZh.jwtNeedHeaderPayload,
        dataEn.jwtNeedHeaderPayload
      ],
      'jwtParsed': [dataZh.jwtParsed, dataEn.jwtParsed],
      'jwtSignatureSegment': [
        dataZh.jwtSignatureSegment('32 chars'),
        dataEn.jwtSignatureSegment('32 chars')
      ],
      'jwtSignatureNone': [dataZh.jwtSignatureNone, dataEn.jwtSignatureNone],
      'jwtNotJsonObject': [
        dataZh.jwtNotJsonObject('header'),
        dataEn.jwtNotJsonObject('header')
      ],
      'jwtEmpty': [dataZh.jwtEmpty, dataEn.jwtEmpty],
      'jwtFromBearer': [dataZh.jwtFromBearer, dataEn.jwtFromBearer],
      'jwtFromTokenField': [dataZh.jwtFromTokenField, dataEn.jwtFromTokenField],
      'jwtFromPastedText': [dataZh.jwtFromPastedText, dataEn.jwtFromPastedText],
      'jwtFromJsonField': [dataZh.jwtFromJsonField, dataEn.jwtFromJsonField],
      'jwtFromCookie': [dataZh.jwtFromCookie, dataEn.jwtFromCookie],
      'jwtFromUrlQuery': [dataZh.jwtFromUrlQuery, dataEn.jwtFromUrlQuery],
      'jwtHasSignature': [dataZh.jwtHasSignature, dataEn.jwtHasSignature],
      'jwtNoSignature': [dataZh.jwtNoSignature, dataEn.jwtNoSignature],
      'jwtAlgorithm': [
        dataZh.jwtAlgorithm('HS256'),
        dataEn.jwtAlgorithm('HS256')
      ],
      'jwtType': [dataZh.jwtType('JWT'), dataEn.jwtType('JWT')],
      'jwtAlgNone': [dataZh.jwtAlgNone, dataEn.jwtAlgNone],
      'jwtKeyId': [dataZh.jwtKeyId('k1'), dataEn.jwtKeyId('k1')],
      'jwtExpired': [dataZh.jwtExpired, dataEn.jwtExpired],
      'jwtNotExpired': [dataZh.jwtNotExpired, dataEn.jwtNotExpired],
      'jwtNoExpiry': [dataZh.jwtNoExpiry, dataEn.jwtNoExpiry],
      'jwtNotYetValid': [dataZh.jwtNotYetValid, dataEn.jwtNotYetValid],
      'jwtNbfReached': [dataZh.jwtNbfReached, dataEn.jwtNbfReached],
      'jwtHasIssuedAt': [dataZh.jwtHasIssuedAt, dataEn.jwtHasIssuedAt],
      'jwtHasAudience': [dataZh.jwtHasAudience, dataEn.jwtHasAudience],
      'jwtHasIssuer': [dataZh.jwtHasIssuer, dataEn.jwtHasIssuer],
      'jwtHasSubject': [dataZh.jwtHasSubject, dataEn.jwtHasSubject],
    };

    // 中文：**这一条两侧逐字节相同，是故意的，不是漏翻。** `UTF-16 code units` 本来就是
    //       ASCII——原文写的就是 `'UTF-16 code units: ${count}'`，中文界面下它也是这几个英文字。
    //       它照样要过"没有空串、没有汉字"两关，只是不过"真的换了"那一关。
    // English: **This one is byte-identical on both sides on purpose, not from a missed
    //          translation.** `UTF-16 code units` was ASCII to begin with — the original read
    //          `'UTF-16 code units: ${count}'`, so those English words already appeared in the
    //          Chinese interface. It still faces the "no empty string, no CJK" checks; it just does
    //          not face the "really changed" one.
    const identicalByDesign = <String>{'summaryUtf16Units'};

    for (final entry in pairs.entries) {
      expect(entry.value[0].trim(), isNotEmpty, reason: '${entry.key} 中文侧是空的');
      expect(entry.value[1].trim(), isNotEmpty, reason: '${entry.key} 英文侧是空的');
      expect(_containsCjk(entry.value[1]), isFalse,
          reason: '${entry.key} 英文侧还有汉字：${entry.value[1]}');
      if (identicalByDesign.contains(entry.key)) {
        expect(entry.value[0], entry.value[1],
            reason: '${entry.key} 被列进了"两侧相同"名单，那就该真的相同');
        continue;
      }
      expect(entry.value[0], isNot(entry.value[1]),
          reason: '「${entry.value[0]}」在英文表里没换');
    }
    expect(identicalByDesign.length, 1, reason: '这张名单不该悄悄变长');
    expect(pairs.length, 96,
        reason: '统计组 47 条 + 数据组 49 条（CSV 22 + JWT 27），漏一条这里就会少一条');
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
