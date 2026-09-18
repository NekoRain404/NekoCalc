import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_detail_screen.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：文本工具那一族四条护栏里的前三条，外加两条屏幕用例；形状与设置页 / 计算页 / 工具子树
///       那几套护栏相同。
///       1) 中文表的每一条都要与翻译前源码里那一句**逐字节相同**——默认语言是中文，所以屏幕上
///          每一个字都得和接入多语言之前一模一样。逐条写出来而不是抽查几条：这一份就是"默认态
///          不变"的**证据本身**。
///       2) 英文表里不许出现汉字、也不许出现空串，而且要真的与中文不同。
///       3) `lib/application/controllers/text_tool_*.dart` 里不许再留中文字符串字面量，
///          **除了下面那张豁免表列出的几条**——它们不是界面文案，是输入文法与判据。
///       统计组与数据组两张表的第 1、2 条在 `text_tool_stats_data_strings_test.dart` 里，
///       按同一形状写的（那一份不需要再抄一遍扫描器）。
/// English: The first three of the text-tool family's four guard rails, plus two screen cases; the
///          same shape as the guards for the settings page, the calculator and the tools subtree.
///          (1) Every Chinese entry must be **byte-identical** to the sentence in the source before
///          translation — the default language is Chinese, so every character on screen has to read
///          exactly as it did before i18n existed. Written out one by one rather than sampled: this
///          list **is** the evidence for "the default state does not change". (2) The English table
///          must hold no CJK, no empty string, and really differ from the Chinese. (3) No Chinese
///          string literal may remain in `lib/application/controllers/text_tool_*.dart` **except the
///          handful listed in the exemption table below** — those are not interface copy but input
///          grammar and branch conditions. Clauses 1 and 2 for the statistics and data tables live
///          in `text_tool_stats_data_strings_test.dart`, written to the same shape (that file needs
///          no second copy of the scanner).
void main() {
  final outputZh = TextToolStrings.textToolZh.output;
  final outputEn = TextToolStrings.textToolEn.output;
  final textZh = TextToolStrings.textToolZh.text;
  final textEn = TextToolStrings.textToolEn.text;

  test('文本工具中文表与迁移前源码里那些字逐字节相同（门面 / 输出外壳）', () {
    expect(outputZh.invalidInput, '输入无效');
    expect(outputZh.unsupportedTool, '不支持的文本工具');
    expect(outputZh.unsupportedToolDetail, '请从工具中心打开已登记的编程与数据工具。');
    expect(outputZh.retryHint, '请检查输入格式后重试。');
    expect(outputZh.statusNeedsFix, '输入需要修正');
    expect(outputZh.statusReusable, '结果可复用');
    expect(outputZh.emptySize, '为空');
    expect(outputZh.charCount(12), '12 字符');
    expect(outputZh.charLineCount(12, 3), '12 字符/3 行');
    expect(outputZh.insightCount(2), '，2 条校核提示');
    expect(outputZh.statusReading('12 字符', '20 字符', '，2 条校核提示'),
        '主结果 12 字符，详细结果 20 字符，2 条校核提示');
    expect(outputZh.copyInput, '输入:');
    expect(outputZh.copyStatus('结果可复用'), '状态: 结果可复用');
    expect(outputZh.copyPrimary, '主结果:');
    expect(outputZh.copyDetail, '详细结果:');
    expect(outputZh.copyInsights, '校核:');
    expect(
        outputZh.htmlEntityDecoded(2, 1), '检测为 HTML 实体文本，已解码 2 处实体。\n未知实体: 1');
    expect(outputZh.htmlEntitySupport, '支持常见命名实体、十进制数字实体和十六进制数字实体。');
    expect(outputZh.htmlEntityUnknownKept, '未知实体已保留原文，避免误改内容。');
    expect(outputZh.htmlTextEncoded, '检测为普通文本，已编码 HTML 特殊字符。');
    expect(outputZh.htmlEscaped, '已转义 &、<、>、引号、撇号和不间断空格。');
  });

  test('文本工具中文表与迁移前源码里那些字逐字节相同（识别组）', () {
    // —— UUID ——
    expect(textZh.uuidStandard('X'), '标准: X');
    expect(textZh.uuidUppercase('X'), '大写: X');
    expect(textZh.uuidNoHyphens('ff'), '无连字符: ff');
    expect(textZh.uuidVersionLine('4（随机）'), '版本: 4（随机）');
    expect(textZh.uuidVariantLine('NCS 兼容'), 'Variant: NCS 兼容');
    expect(textZh.uuidGenerated, '已离线生成随机 UUID v4。');
    expect(textZh.uuidValid, '输入 UUID 有效，已标准化。');
    expect(textZh.uuidExtractedFrom('JSON 字段'), '已从JSON 字段中提取 UUID。');
    expect(textZh.uuidNormalized, '输入已规范为小写 8-4-4-4-12 格式。');
    expect(textZh.uuidInvalid,
        '请输入有效 UUID，例如 550e8400-e29b-41d4-a716-446655440000');
    expect(textZh.uuidHyphens, 'UUID 连字符位置应为 8-4-4-4-12。');
    expect(textZh.uuidSourceJsonField, 'JSON 字段');
    expect(textZh.uuidSourceGuidCall, 'Guid/UUID 调用');
    expect(textZh.uuidSourceLabelText, '标签文本');
    expect(textZh.uuidSourceByteArray, '字节数组');
    expect(textZh.uuidVersion1, '1（时间/MAC）');
    expect(textZh.uuidVersion2, '2（DCE Security）');
    expect(textZh.uuidVersion3, '3（MD5 namespace）');
    expect(textZh.uuidVersion4, '4（随机）');
    expect(textZh.uuidVersion5, '5（SHA-1 namespace）');
    expect(textZh.uuidVersion6, '6（重排时间）');
    expect(textZh.uuidVersion7, '7（Unix 时间）');
    expect(textZh.uuidVersion8, '8（自定义）');
    expect(textZh.uuidVersionOther(9), '9（未知/保留）');
    expect(textZh.uuidVariantNcs, 'NCS 兼容');
    expect(textZh.uuidVariantRfc, 'RFC 4122 / RFC 9562');
    expect(textZh.uuidVariantMicrosoft, 'Microsoft 兼容');
    expect(textZh.uuidVariantFuture, '未来保留');
    // —— JSON ——
    expect(textZh.jsonLinesValid, 'JSON Lines 有效');
    expect(textZh.jsonValid, 'JSON 有效');
    expect(textZh.jsonEmpty, '请输入 JSON 文本');
    expect(textZh.jsonEscapedString, '转义 JSON 字符串');
    expect(textZh.jsonEscapedStringIn('Markdown 代码块'),
        'Markdown 代码块中的转义 JSON 字符串');
    expect(textZh.jsonSourceMarkdownFence, 'Markdown 代码块');
    expect(textZh.jsonSourcePastedText, '粘贴文本');
    expect(textZh.jsonExtractedFrom('粘贴文本'), '已从粘贴文本中提取 JSON。');
    expect(textZh.jsonLinesConverted, '输入识别为 JSON Lines / NDJSON，已转换为数组。');
    expect(textZh.jsonJsStyleNormalized, '已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。');
    expect(textZh.jsonTopLevelObject(2), '顶层类型: Object，键数量: 2。');
    expect(textZh.jsonTopLevelArray(2), '顶层类型: Array，元素数量: 2。');
    expect(textZh.jsonTopLevelString, '顶层类型: String。');
    expect(textZh.jsonTopLevelNumber, '顶层类型: Number。');
    expect(textZh.jsonTopLevelBoolean, '顶层类型: Boolean。');
    expect(textZh.jsonTopLevelNull, '顶层类型: Null。');
    expect(textZh.jsonTopLevelOther('Foo'), '顶层类型: Foo。');
    expect(textZh.jsonStructure(1, 2, 3), '结构: Object 1，Array 2，标量 3。');
    expect(textZh.jsonKeysAndDepth(4, 2), '总键数: 4，最大深度: 2。');
    expect(textZh.jsonNullCount(1), '包含 null 值: 1。');
    // —— 正则 ——
    expect(textZh.regexNeedTwoLines, '第一行输入正则，后续行输入测试文本。');
    expect(textZh.regexMatchCount(3), '3 个匹配');
    expect(textZh.regexNoMatches, '没有匹配项');
    expect(textZh.regexLabeledInput, '已识别 pattern/text 标签格式。');
    expect(textZh.regexGlobalFlag, '已兼容 g/global 标志；本工具默认列出所有匹配。');
    expect(textZh.regexFirst50, '仅展示前 50 个匹配项。');
    expect(textZh.regexNoHit, '当前正则没有命中测试文本。');
    expect(textZh.regexEmptyPattern, '正则为空，会匹配所有位置。');
    expect(textZh.regexHasGroups, '包含捕获组，详情中已列出 group 值。');
    expect(textZh.regexFlagsUnsupported, '正则 flags 仅支持 g、i、m、s、u');
    // —— 自定义公式 ——
    expect(textZh.formulaEmpty, '请输入公式，例如 a * b + c');
    expect(textZh.formulaNotFinite, '公式结果不是有限数值，请检查除零、对数或开方范围。');
    expect(textZh.formulaMissingVariables('a, b'), '公式包含未赋值变量: a, b');
    expect(textZh.formulaLabel('a + b'), '公式: a + b');
    expect(textZh.formulaExpanded('1 + 2'), '展开公式: 1 + 2');
    expect(textZh.formulaVariables, '变量:');
    expect(textZh.formulaVariableLine('a', '1', '输入文本 "1"'),
        '  a = 1  来源: 输入文本 "1"');
    expect(textZh.formulaExtracted, '已从输入文本中提取公式。');
    expect(textZh.formulaExtractedVariables('a, b'), '已从输入文本中提取变量: a, b。');
    expect(textZh.formulaUsedVariables('[a, b]'), '公式使用变量: [a, b].');
    expect(textZh.formulaUnusedVariables('c'), '未使用变量: c。');
    expect(textZh.formulaAngleNote, '表达式按角度制解析三角函数，支持常量 pi/e 和常用数学函数。');
    expect(textZh.formulaVariableError('a', '输入无效'), '变量 a: 输入无效');
    expect(textZh.formulaSourceInput('1'), '输入文本 "1"');
    expect(textZh.formulaSourceField('1'), '变量框 "1"');
  });

  test('两张表的英文侧都没有汉字、没有空串，而且真的换了', () {
    final pairs = <String, List<String>>{
      // —— 门面 / 输出外壳 ——
      'invalidInput': [outputZh.invalidInput, outputEn.invalidInput],
      'unsupportedTool': [outputZh.unsupportedTool, outputEn.unsupportedTool],
      'unsupportedToolDetail': [
        outputZh.unsupportedToolDetail,
        outputEn.unsupportedToolDetail
      ],
      'retryHint': [outputZh.retryHint, outputEn.retryHint],
      'statusNeedsFix': [outputZh.statusNeedsFix, outputEn.statusNeedsFix],
      'statusReusable': [outputZh.statusReusable, outputEn.statusReusable],
      'emptySize': [outputZh.emptySize, outputEn.emptySize],
      'charCount': [outputZh.charCount(12), outputEn.charCount(12)],
      'charLineCount': [
        outputZh.charLineCount(12, 3),
        outputEn.charLineCount(12, 3)
      ],
      'insightCount': [outputZh.insightCount(2), outputEn.insightCount(2)],
      'statusReading': [
        outputZh.statusReading('a', 'b', 'c'),
        outputEn.statusReading('a', 'b', 'c')
      ],
      'copyInput': [outputZh.copyInput, outputEn.copyInput],
      'copyStatus': [
        outputZh.copyStatus('结果可复用'),
        outputEn.copyStatus('Reusable')
      ],
      'copyPrimary': [outputZh.copyPrimary, outputEn.copyPrimary],
      'copyDetail': [outputZh.copyDetail, outputEn.copyDetail],
      'copyInsights': [outputZh.copyInsights, outputEn.copyInsights],
      'htmlEntityDecoded': [
        outputZh.htmlEntityDecoded(2, 1),
        outputEn.htmlEntityDecoded(2, 1)
      ],
      'htmlEntitySupport': [
        outputZh.htmlEntitySupport,
        outputEn.htmlEntitySupport
      ],
      'htmlEntityUnknownKept': [
        outputZh.htmlEntityUnknownKept,
        outputEn.htmlEntityUnknownKept
      ],
      'htmlTextEncoded': [outputZh.htmlTextEncoded, outputEn.htmlTextEncoded],
      'htmlEscaped': [outputZh.htmlEscaped, outputEn.htmlEscaped],
      // —— UUID ——
      'uuidStandard': [textZh.uuidStandard('X'), textEn.uuidStandard('X')],
      'uuidUppercase': [textZh.uuidUppercase('X'), textEn.uuidUppercase('X')],
      'uuidNoHyphens': [textZh.uuidNoHyphens('X'), textEn.uuidNoHyphens('X')],
      'uuidVersionLine': [
        textZh.uuidVersionLine('X'),
        textEn.uuidVersionLine('X')
      ],
      // 中文：这一条的外框 `Variant: ` 两侧逐字节相同（它本来就是 ASCII），换掉的是**里面那个
      //       词**——所以这一对比的是"拿各自语言的说法拼出来的整行"，也就是运行时真正发生的事。
      // English: this one's frame, `Variant: `, is byte-identical on both sides (it was ASCII to
      //          begin with); what changes is the **word inside**. So this pair compares the whole
      //          line composed from each language's own label — what actually happens at runtime.
      'uuidVariantLine': [
        textZh.uuidVariantLine(textZh.uuidVariantFuture),
        textEn.uuidVariantLine(textEn.uuidVariantFuture)
      ],
      'uuidGenerated': [textZh.uuidGenerated, textEn.uuidGenerated],
      'uuidValid': [textZh.uuidValid, textEn.uuidValid],
      'uuidExtractedFrom': [
        textZh.uuidExtractedFrom('X'),
        textEn.uuidExtractedFrom('X')
      ],
      'uuidNormalized': [textZh.uuidNormalized, textEn.uuidNormalized],
      'uuidInvalid': [textZh.uuidInvalid, textEn.uuidInvalid],
      'uuidHyphens': [textZh.uuidHyphens, textEn.uuidHyphens],
      'uuidSourceJsonField': [
        textZh.uuidSourceJsonField,
        textEn.uuidSourceJsonField
      ],
      'uuidSourceGuidCall': [
        textZh.uuidSourceGuidCall,
        textEn.uuidSourceGuidCall
      ],
      'uuidSourceLabelText': [
        textZh.uuidSourceLabelText,
        textEn.uuidSourceLabelText
      ],
      'uuidSourceByteArray': [
        textZh.uuidSourceByteArray,
        textEn.uuidSourceByteArray
      ],
      'uuidVersion1': [textZh.uuidVersion1, textEn.uuidVersion1],
      'uuidVersion2': [textZh.uuidVersion2, textEn.uuidVersion2],
      'uuidVersion3': [textZh.uuidVersion3, textEn.uuidVersion3],
      'uuidVersion4': [textZh.uuidVersion4, textEn.uuidVersion4],
      'uuidVersion5': [textZh.uuidVersion5, textEn.uuidVersion5],
      'uuidVersion6': [textZh.uuidVersion6, textEn.uuidVersion6],
      'uuidVersion7': [textZh.uuidVersion7, textEn.uuidVersion7],
      'uuidVersion8': [textZh.uuidVersion8, textEn.uuidVersion8],
      'uuidVersionOther': [
        textZh.uuidVersionOther(9),
        textEn.uuidVersionOther(9)
      ],
      'uuidVariantNcs': [textZh.uuidVariantNcs, textEn.uuidVariantNcs],
      'uuidVariantRfc': [textZh.uuidVariantRfc, textEn.uuidVariantRfc],
      'uuidVariantMicrosoft': [
        textZh.uuidVariantMicrosoft,
        textEn.uuidVariantMicrosoft
      ],
      'uuidVariantFuture': [textZh.uuidVariantFuture, textEn.uuidVariantFuture],
      // —— JSON ——
      'jsonLinesValid': [textZh.jsonLinesValid, textEn.jsonLinesValid],
      'jsonValid': [textZh.jsonValid, textEn.jsonValid],
      'jsonEmpty': [textZh.jsonEmpty, textEn.jsonEmpty],
      'jsonEscapedString': [textZh.jsonEscapedString, textEn.jsonEscapedString],
      'jsonEscapedStringIn': [
        textZh.jsonEscapedStringIn('X'),
        textEn.jsonEscapedStringIn('X')
      ],
      'jsonSourceMarkdownFence': [
        textZh.jsonSourceMarkdownFence,
        textEn.jsonSourceMarkdownFence
      ],
      'jsonSourcePastedText': [
        textZh.jsonSourcePastedText,
        textEn.jsonSourcePastedText
      ],
      'jsonExtractedFrom': [
        textZh.jsonExtractedFrom('X'),
        textEn.jsonExtractedFrom('X')
      ],
      'jsonLinesConverted': [
        textZh.jsonLinesConverted,
        textEn.jsonLinesConverted
      ],
      'jsonJsStyleNormalized': [
        textZh.jsonJsStyleNormalized,
        textEn.jsonJsStyleNormalized
      ],
      'jsonTopLevelObject': [
        textZh.jsonTopLevelObject(2),
        textEn.jsonTopLevelObject(2)
      ],
      'jsonTopLevelArray': [
        textZh.jsonTopLevelArray(2),
        textEn.jsonTopLevelArray(2)
      ],
      'jsonTopLevelString': [
        textZh.jsonTopLevelString,
        textEn.jsonTopLevelString
      ],
      'jsonTopLevelNumber': [
        textZh.jsonTopLevelNumber,
        textEn.jsonTopLevelNumber
      ],
      'jsonTopLevelBoolean': [
        textZh.jsonTopLevelBoolean,
        textEn.jsonTopLevelBoolean
      ],
      'jsonTopLevelNull': [textZh.jsonTopLevelNull, textEn.jsonTopLevelNull],
      'jsonTopLevelOther': [
        textZh.jsonTopLevelOther('Foo'),
        textEn.jsonTopLevelOther('Foo')
      ],
      'jsonStructure': [
        textZh.jsonStructure(1, 2, 3),
        textEn.jsonStructure(1, 2, 3)
      ],
      'jsonKeysAndDepth': [
        textZh.jsonKeysAndDepth(4, 2),
        textEn.jsonKeysAndDepth(4, 2)
      ],
      'jsonNullCount': [textZh.jsonNullCount(1), textEn.jsonNullCount(1)],
      // —— 正则 ——
      'regexNeedTwoLines': [textZh.regexNeedTwoLines, textEn.regexNeedTwoLines],
      'regexMatchCount': [textZh.regexMatchCount(3), textEn.regexMatchCount(3)],
      'regexNoMatches': [textZh.regexNoMatches, textEn.regexNoMatches],
      'regexLabeledInput': [textZh.regexLabeledInput, textEn.regexLabeledInput],
      'regexGlobalFlag': [textZh.regexGlobalFlag, textEn.regexGlobalFlag],
      'regexFirst50': [textZh.regexFirst50, textEn.regexFirst50],
      'regexNoHit': [textZh.regexNoHit, textEn.regexNoHit],
      'regexEmptyPattern': [textZh.regexEmptyPattern, textEn.regexEmptyPattern],
      'regexHasGroups': [textZh.regexHasGroups, textEn.regexHasGroups],
      'regexFlagsUnsupported': [
        textZh.regexFlagsUnsupported,
        textEn.regexFlagsUnsupported
      ],
      // —— 自定义公式 ——
      'formulaEmpty': [textZh.formulaEmpty, textEn.formulaEmpty],
      'formulaNotFinite': [textZh.formulaNotFinite, textEn.formulaNotFinite],
      'formulaMissingVariables': [
        textZh.formulaMissingVariables('a'),
        textEn.formulaMissingVariables('a')
      ],
      'formulaLabel': [textZh.formulaLabel('f'), textEn.formulaLabel('f')],
      'formulaExpanded': [
        textZh.formulaExpanded('e'),
        textEn.formulaExpanded('e')
      ],
      'formulaVariables': [textZh.formulaVariables, textEn.formulaVariables],
      'formulaVariableLine': [
        textZh.formulaVariableLine('a', '1', 's'),
        textEn.formulaVariableLine('a', '1', 's')
      ],
      'formulaExtracted': [textZh.formulaExtracted, textEn.formulaExtracted],
      'formulaExtractedVariables': [
        textZh.formulaExtractedVariables('a'),
        textEn.formulaExtractedVariables('a')
      ],
      'formulaUsedVariables': [
        textZh.formulaUsedVariables('[a]'),
        textEn.formulaUsedVariables('[a]')
      ],
      'formulaUnusedVariables': [
        textZh.formulaUnusedVariables('a'),
        textEn.formulaUnusedVariables('a')
      ],
      'formulaAngleNote': [textZh.formulaAngleNote, textEn.formulaAngleNote],
      'formulaVariableError': [
        textZh.formulaVariableError('a', 'e'),
        textEn.formulaVariableError('a', 'e')
      ],
      'formulaSourceInput': [
        textZh.formulaSourceInput('r'),
        textEn.formulaSourceInput('r')
      ],
      'formulaSourceField': [
        textZh.formulaSourceField('r'),
        textEn.formulaSourceField('r')
      ],
    };

    // 中文：**这一条两侧逐字节相同，是故意的，不是漏翻。** `RFC 4122 / RFC 9562` 是规范版本号，
    //       不是译文，`_ParsedUuid.variantLabel` 上的注释已写明。它照样要过"没有空串、没有汉字"
    //       两关，只是不过"真的换了"那一关。
    // English: **This one is byte-identical on both sides on purpose, not from a missed
    //          translation.** `RFC 4122 / RFC 9562` is a specification number rather than prose, as
    //          the note on `_ParsedUuid.variantLabel` says. It still faces the "no empty string, no
    //          CJK" checks; it just does not face the "really changed" one.
    const identicalByDesign = <String>{'uuidVariantRfc'};

    // 中文：中文侧不许有空串——空串在屏幕上是"这一格什么都没有"，最难发现的一类漏翻。
    // English: the Chinese side must hold no empty string either: on screen it renders as a blank
    //          cell, the hardest kind of missing copy to notice.
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
    expect(pairs.length, 94, reason: '门面与输出外壳 21 条 + 识别组 73 条，漏一条这里就会少一条');
  });

  test('文本工具源码里除四张文案表外只剩输入文法与判据那几条中文', () {
    final directory = Directory('lib/application/controllers');
    expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    // 中文：**这份豁免表就是本轮"哪些中文刻意不翻"的可执行版本**，一条一条都带理由。
    //       它们不是界面文案：翻掉任何一条都会改变行为，而不是改变语言。
    // English: **This exemption table is the executable version of "which Chinese is deliberately
    //          left alone".** Every entry carries its reason. None of them is interface copy:
    //          translating any one changes behaviour rather than language.
    const exemptions = <String, String>{
      // —— 输入文法：匹配用户可能敲进来的中文标签 ——
      r"^\s*(formula|expr|expression|公式|表达式|算式|[abc])\s*[:：=]\s*(.+?)\s*$":
          '自定义公式：解析 `公式: …` 这类中文标签的输入文法',
      r"^\s*(formula|expr|expression|公式|表达式|算式|[abc])\s*[:：=]":
          '自定义公式：同一套标签的"是不是赋值行"判据',
      r'^(?:flags?|模式)\s*[:=]\s*([a-zA-Z]+)\s*$': '正则：解析 `模式: gi` 这类中文标签的输入文法',
      r'^\s*(?:flags?|模式)\s*[:=]\s*([a-zA-Z]+)\s*$': '正则：同上，带前导空白的那一支',
      r'^\s*(?:pattern|regex|regexp|正则|表达式)\s*[:=]\s*(.*)$':
          '正则：解析 `正则: …` 这类中文标签的输入文法',
      r'^\s*(?:text|input|sample|测试文本|文本)\s*[:=]\s*(.*)$':
          '正则：解析 `测试文本: …` 这类中文标签的输入文法',
      // —— 与输入比较的判据 ——
      '公式': '自定义公式：`normalized == \'公式\'` 之一，比的是用户输入',
      '表达式': '自定义公式：同上',
      '算式': '自定义公式：同上',
      '单位': 'CSV：`first == \'单位\'`，比的是用户粘贴表格的首格',
      '量纲': 'CSV：同上',
      // —— 颜色：两条**输入文法**，第二条还兼作判据 ——
      r'(?:\b(?:hex|color|colour)|颜色|色值)\s*[:=]\s*([0-9a-fA-F]{3,8})\b':
          '颜色：解析用户敲的 `色值: 5B47FF` 这类带中文标签的色值',
      r'(?:\b(?:hex|color|colour)|颜色|色值)\s*[:=]':
          '颜色：`_hexColorSource` 用它判断"用户写没写标签"，好挑哪一句识别说明——既是文法也是判据',
      // —— 时间戳：五条输入文法 ——
      r'(?:timestamp|time|date|datetime|created_at|updated_at|expires_at|过期时间|时间|日期)\s*[:=]\s*["“”]?((?:mon|tue|wed|thu|fri|sat|sun)[a-z]*,\s*[^\n\r"”]+)':
          '时间戳：从带中文标签的文本里抠出 RFC 风格日期时间的输入文法',
      r'(?:timestamp|time|date|datetime|created_at|updated_at|expires_at|过期时间|时间|日期)\s*[:=]\s*["“”]?([^",，\n\r]+)':
          '时间戳：同上，宽的那一支',
      r'(?:北京时间|中国标准时间|东八区)':
          '时间戳：把用户输入里的中文时区标签改写成 +08:00',
      r'^([+-]?\d+(?:\.\d+)?)\s*(ns|纳秒|us|µs|μs|微秒|ms|毫秒|s|sec|秒)$':
          '时间戳：解析 `100 毫秒` 这类带中文单位词的时间戳',
      r'^(\d{4})[年/-](\d{1,2})[月/-](\d{1,2})(?:日)?(?:\s+(\d{1,2})(?:[时:：](\d{1,2})(?:[分:：](\d{1,2}))?)?(?:秒)?)?$':
          '时间戳：解析 `2026年6月8日 9:30` 这类中文日期写法',
      // —— 时间戳：与输入比较的判据 ——
      '现在': '时间戳：`normalized == \'现在\'`，比的是用户输入的说法',
      '北京时间': '时间戳：`normalized == \'北京时间\' || …`，同上',
      '中国标准时间': '时间戳：同上',
      '东八区': '时间戳：同上',
      '纳秒': '时间戳：`unit == \'纳秒\'`，比的是用户输入里的单位词（不是要显示的句子）',
      '微秒': '时间戳：`unit == \'微秒\'`，同上',
      '毫秒': '时间戳：`unit == \'毫秒\'`，同上',
    };

    // 中文：**这一族现在整族都在名单上。** 名单从"已迁移"改成"全部"，是因为本轮把最后六个文件
    //       （编解码组四个 + 时间戳 + 颜色所在的 Web 格式组）连同描述符一起改完了。
    //       **换成全量名单而不是拆掉名单**：`text_tool_*.dart` 是本族的边界，边界里每一个文件
    //       都点名，新加一个文件时这里就会红——那正是我们希望它红的时候。
    // English: **the whole family is on this list now.** It changed from "migrated so far" to "all of
    //          them" because this round finished the last six files (the four codec ones, timestamps,
    //          and the web-format group the colour tool lives in) together with their descriptors.
    //          **A full list rather than no list**: `text_tool_*.dart` is this family's boundary, every
    //          file inside it is named, and adding a new file turns this red — which is exactly when
    //          we want it red.
    const migrated = <String>{
      'text_tool_binary_tools.dart',
      'text_tool_color_tools.dart',
      'text_tool_controller.dart',
      'text_tool_csv_tools.dart',
      'text_tool_custom_formula_tools.dart',
      'text_tool_html_entities.dart',
      'text_tool_integer_tools.dart',
      'text_tool_json_tools.dart',
      'text_tool_jwt_tools.dart',
      'text_tool_models.dart',
      'text_tool_parsed_models.dart',
      'text_tool_regex_tools.dart',
      'text_tool_shared_text.dart',
      'text_tool_text_stats_tools.dart',
      'text_tool_timestamp_tools.dart',
      'text_tool_url_codec_tools.dart',
      'text_tool_url_query_tools.dart',
      'text_tool_uuid_tools.dart',
    };

    final offenders = <String>[];
    final seen = <String>{};
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      // 中文：**扫的是 `text_tool_*.dart` 这一族，一个不漏。** 族外的文件
      //       （`tool_search_*` 的双语搜索索引、`tool_detail_*` 另一个工具面的控制器、
      //       `notes_controller.dart` 另一位作者的未提交工作）根本不看。
      // English: **the scan covers the `text_tool_*.dart` family and nothing else.** Files outside it
      //          (`tool_search_*`, the bilingual search index; `tool_detail_*`, another tool screen's
      //          controller; `notes_controller.dart`, another author's uncommitted work) are not
      //          looked at.
      if (!name.startsWith('text_tool_')) continue;
      seen.add(name);
      final source = _stripComments(entity.readAsStringSync());
      for (final literal in _stringLiterals(source)) {
        if (!_containsCjk(literal)) continue;
        if (exemptions.containsKey(literal)) continue;
        offenders.add('${entity.path}: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason: '这些界面字面量还没走 TextToolStrings 那七张表：\n${offenders.join('\n')}');
    expect(exemptions.length, 25, reason: '豁免表变短或变长都要在这里说一声');
    expect(seen, migrated,
        reason: '本族文件多了或少了：目录里是 $seen，名单里是 $migrated——'
            '新加一个 `text_tool_*.dart` 时这里会红，那时请把它也搬进文案表');
  });

  testWidgets('没有装作用域时文本工具页仍渲染中文（默认态不变）', (tester) async {
    await tester.pumpWidget(_app(TextToolDetailScreen(
      db: const _EmptyDatabase(),
      tool: toolById('text_stats')!,
      settings: AppSettings.fallback,
    )));
    await tester.pump();
    expect(find.text('输入'), findsOneWidget);
    expect(find.text('主结果'), findsOneWidget);
    expect(find.text('详细结果'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 中文：**这一条钉的是"屏幕真的把表递下去了"。** 控制器那一侧的护栏是"漏传就编译不过"，
  //       但编译得过也可能是某个调用点写死了一份中文——所以这里从屏幕那一端起，装英文作用域，
  //       断言主结果与详情**真的是英文**：长句出自控制器，它们换成英文就证明表走到了控制器。
  // English: **this pins that the screen really does pass the table down.** The controller's own
  //          guard is "forget it and it does not compile", but compiling does not rule out a call
  //          site hard-coding Chinese — so this starts from the screen, installs the English scope,
  //          and asserts the primary result and detail **really are English**: those long sentences
  //          come from the controller, so their switching proves the table reached it.
  testWidgets('装上 AppLanguageScope(en) 之后文本工具页的长句也是英文', (tester) async {
    await tester.pumpWidget(_app(
      TextToolDetailScreen(
        db: const _EmptyDatabase(),
        tool: toolById('text_stats')!,
        settings: AppSettings.fallback,
      ),
      language: AppLanguage.en,
    ));
    await tester.pump();
    expect(find.text('Primary result'), findsOneWidget);
    expect(find.text('Detailed result'), findsOneWidget);
    expect(find.textContaining('Characters: '), findsWidgets);

    // 中文：**只看控制器喂出来那两块**（主结果与详情，两个 `SelectableText`），不整屏扫汉字——
    //       屏幕上还剩中文，而且**应该**剩：工具名与工具描述来自 `tool_catalog`，
    //       "工具名保持中文"是记录在案的产品决定，不是漏翻。整屏扫会把那条决定当成失败。
    // English: **only the two panes the controller feeds** (primary result and detail, both
    //          `SelectableText`) are checked, rather than sweeping the whole screen for CJK: Chinese
    //          does remain on screen and **should** — the tool name and description come from
    //          `tool_catalog`, and "tool names stay Chinese" is a recorded product decision rather
    //          than a missed translation. A whole-screen sweep would fail on that decision.
    final panes =
        tester.widgetList<SelectableText>(find.byType(SelectableText));
    expect(panes, isNotEmpty, reason: '主结果与详情都应当是 SelectableText');
    for (final pane in panes) {
      expect(_containsCjk(pane.data ?? ''), isFalse,
          reason: '控制器喂出来的那一格还有汉字：${pane.data}');
    }
    expect(tester.takeException(), isNull);
  });

  test('装了英文作用域之后控制器产出的长句也是英文', () {
    const controller = TextToolController();
    final en = TextToolStrings.forLanguage(AppLanguage.en);
    final output = controller.calculate(
      toolId: 'text_stats',
      strings: en,
      input: 'NekoCalc',
    );
    expect(output.primary, '8 characters');
    expect(output.statusTitle(en.output), 'Result is reusable');
    expect(output.statusMessage(en.output), contains('Primary result'));
    expect(_containsCjk(output.detail), isFalse,
        reason: '详情里不该再有汉字：${output.detail}');
  });
}

Widget _app(Widget home, {AppLanguage? language}) => MaterialApp(
      home: Scaffold(
        body: language == null
            ? home
            : AppLanguageScope(language: language, child: home),
      ),
    );

/// 中文：一份什么都答"空"的库；护栏测试只关心首帧那几个字，不关心草稿与保存。
/// English: A database that answers empty to everything; the guard tests care about the first
///          frame's copy, not about drafts or saving.
class _EmptyDatabase implements AppDatabase {
  const _EmptyDatabase();

  /// 中文：`implements` 只列出真会被调用的那几个；其余的交给 `noSuchMethod` 抛错——真被调到
  ///       说明页面比这份假库以为的读得多，那时应当红，而不是悄悄返回空。
  /// English: `implements` lists only the members actually reached; everything else falls to
  ///          `noSuchMethod` and throws — if one of them is reached, the page reads more than this
  ///          fake assumed and the test should go red rather than quietly answer empty.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}
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

/// 中文：去掉 `//` 与 `/* */` 注释，**但保留字符串字面量原样**——注释里会出现引号
///       （本项目的中文注释就常写 `'关闭'`），先按引号整体跳过，注释才不会被截错。
/// English: Strips `//` and `/* */` comments while **copying string literals verbatim**: this
///          project's Chinese comments quote literals such as `'关闭'`, so quotes are skipped as whole
///          units first; otherwise the comment stripper would cut in the wrong place.
String _stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch == "'" || ch == '"') {
      final quote = ch;
      // 中文：三引号原样成块跳过。
      // English: Triple quotes are skipped as a block.
      final triple = source.startsWith(quote * 3, i);
      final delimiter = triple ? quote * 3 : quote;
      out.write(delimiter);
      i += delimiter.length;
      while (i < source.length) {
        if (source[i] == r'\') {
          out.write(source.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (source.startsWith(delimiter, i)) {
          out.write(delimiter);
          i += delimiter.length;
          break;
        }
        out.write(source[i]);
        i++;
      }
      continue;
    }
    if (ch == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (ch == '/' && i + 1 < source.length && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < source.length &&
          !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}

/// 中文：取出源码里所有单/双引号字符串字面量的内容。
/// English: Extracts the contents of every single- and double-quoted string literal in the source.
Iterable<String> _stringLiterals(String source) sync* {
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch != "'" && ch != '"') {
      i++;
      continue;
    }
    final quote = ch;
    final triple = source.startsWith(quote * 3, i);
    final delimiter = triple ? quote * 3 : quote;
    i += delimiter.length;
    final buffer = StringBuffer();
    while (i < source.length) {
      if (source[i] == r'\') {
        buffer.write(source.substring(i, i + 2));
        i += 2;
        continue;
      }
      if (source.startsWith(delimiter, i)) {
        i += delimiter.length;
        break;
      }
      buffer.write(source[i]);
      i++;
    }
    yield buffer.toString();
  }
}
