import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';

/// 中文：Web 格式组那张表的第 1、2 条护栏——**逐条写出中文原文，再两侧比一遍**。
///       第 3 条（源码扫描）与两条屏幕用例在 `text_tool_strings_test.dart` 里，那一份带着扫描器，
///       这一份不需要再抄一遍：扫描器扫的是**文件**，而这里多出来的只是**表条目**。
///       文件头的完整理由见 `text_tool_strings.dart`。
/// English: Clauses 1 and 2 of the guard rails for the web-format table — **every Chinese entry
///          written out, then both sides compared**. Clause 3 (the source scan) and the two screen
///          cases live in `text_tool_strings_test.dart`, which carries the scanner; this file does not
///          need a second copy of it, because the scanner scans **files** while what is new here is
///          only **table entries**. The full reasoning is on `text_tool_strings.dart`'s file head.
void main() {
  final webZh = TextToolStrings.textToolZh.web;
  final webEn = TextToolStrings.textToolEn.web;

  test('Web 格式组中文表与迁移前源码里那些字逐字节相同', () {
    // —— URL 编解码：模式与来源 ——
    expect(webZh.modeFullUrl, '完整 URL');
    expect(webZh.modeRelativeUrl, '相对 URL');
    expect(webZh.modeQueryString, 'query string');
    expect(webZh.modeUrlComponent, 'URL 组件');
    expect(webZh.sourceCurlCommand, 'curl 命令');
    expect(webZh.sourceHttpRequestLine, 'HTTP 请求行');
    // —— URL 编解码：正文各行 ——
    expect(webZh.modeLabel('完整 URL'), '模式: 完整 URL');
    expect(webZh.originalLength(12), '原长度: 12');
    expect(webZh.resultLength(12), '结果长度: 12');
    expect(webZh.lengthDelta('+3'), '长度变化: +3');
    expect(webZh.queryParameterCount(2), 'Query 参数: 2 个');
    expect(webZh.percentTripletCount(2), '百分号编码片段: 2 个');
    // —— URL 编解码：校核提示 ——
    expect(webZh.extractedFrom('curl 命令'), '已从curl 命令中提取 URL。');
    expect(webZh.decodedByMode('完整 URL'), '检测到百分号编码，已按完整 URL解码。');
    expect(webZh.encodedByMode('完整 URL'), '未检测到百分号编码，已按完整 URL编码。');
    expect(webZh.plusAsSpace, 'Query 中的 + 已按空格处理。');
    expect(webZh.queryCountEstimated, 'Query 参数数量按 & 分隔估算，重复键未在此处合并。');
    expect(webZh.queryKeysEncoded, '已保留 URL 结构，仅编码 query 键和值。');
    // —— URL 编解码：错误 ——
    expect(webZh.invalidPercentEncoding, 'URL 百分号编码不完整或无效。');
    // —— query 参数：正文 ——
    expect(webZh.noParameters, '无参数');
    expect(webZh.noParametersDetail, '没有解析到 query 参数。');
    expect(webZh.parameterCount(2), '2 个参数');
    expect(webZh.hostLine('example.com'), '主机: example.com');
    expect(webZh.pathLine('/a'), '路径: /a');
    expect(webZh.fragmentLine('top'), '片段: top');
    expect(webZh.parsedSummary(2, 2), '已解析 2 个 query 参数，2 个唯一键。');
    expect(webZh.repeatedKeys('a(2)'), '重复键: a(2)。');
    // —— query 参数：校核提示 ——
    expect(webZh.semicolonSeparators, '已兼容分号分隔的表单参数。');
    expect(webZh.lineSeparators, '已兼容换行分隔的表单参数。');
    // —— query 参数：输入识别 ——
    expect(webZh.emptyInput, '输入为空。');
    expect(webZh.inputFullUrlInRequestLine, '输入识别为 HTTP 请求行中的完整 URL。');
    expect(webZh.inputFullUrl, '输入识别为完整 URL。');
    expect(webZh.inputRequestLine, '输入识别为 HTTP 请求行。');
    expect(webZh.inputRelativeUrl, '输入识别为相对 URL。');
    expect(webZh.inputQueryStringOrForm, '输入识别为 query string / 表单正文。');
    expect(webZh.inputUrlFragmentQuery, '输入识别为 URL 片段中的 query。');
    expect(webZh.inputCurlFormFields, '输入识别为 curl 命令中的表单参数。');
    expect(webZh.inputCurlNoQueryFound, '输入识别为 curl 命令，但未找到 URL query 或表单参数。');
    expect(webZh.inputCurlMergedUrlQueryAndGet,
        '输入识别为 curl 命令，已合并 --url-query 与 -G/--get 参数。');
    expect(webZh.inputCurlMergedUrlQueryAndData,
        '输入识别为 curl 命令，已合并 --url-query 与 -d/--data 表单参数。');
    expect(webZh.inputCurlMergedUrlQuery, '输入识别为 curl 命令，已合并 --url-query 参数。');
    expect(webZh.inputCurlGetMergedData,
        '输入识别为 curl -G/--get 命令，已将 --data 参数合并为 URL query。');
    expect(webZh.inputCurlMergedQueryAndData,
        '输入识别为 curl 命令，已合并 URL query 与 -d/--data 表单参数。');
    expect(webZh.inputCurlUrl, '输入识别为 curl 命令中的 URL。');
    expect(webZh.inputCurlFullUrl, '输入识别为 curl 命令中的完整 URL。');
    expect(webZh.inputCurlRelativeUrl, '输入识别为 curl 命令中的相对 URL。');
    // —— 颜色：输入识别 ——
    expect(webZh.namedColor('rebeccapurple'), '输入识别为 CSS 命名颜色 rebeccapurple。');
    expect(webZh.rgbaColor, '输入识别为 RGBA 颜色。');
    expect(webZh.rgbColor, '输入识别为 RGB 颜色。');
    expect(webZh.hslaColor, '输入识别为 HSLA 颜色。');
    expect(webZh.hslColor, '输入识别为 HSL 颜色。');
    expect(webZh.flutterColor, '输入识别为 Flutter/Android Color(0xAARRGGBB) 色值。');
    expect(webZh.argbHexValue, '输入识别为 0xAARRGGBB 色值。');
    expect(webZh.rgbHexValue, '输入识别为 0xRRGGBB 色值。');
    expect(webZh.labelledHexValue, '输入识别为带标签 HEX 色值。');
    expect(webZh.shortHex3, '输入识别为 3 位 HEX 颜色。');
    expect(webZh.shortHex6, '输入识别为 6 位 HEX 颜色。');
    expect(webZh.argbHex4, '输入识别为 4 位 ARGB HEX 颜色。');
    expect(webZh.argbHex8, '输入识别为 ARGB HEX 颜色。');
    expect(webZh.labelledRgb, '输入识别为标签式 RGB 颜色。');
    expect(webZh.labelledRgba, '输入识别为标签式 RGBA 颜色。');
    expect(webZh.argbChannelList, '输入识别为 ARGB 通道列表。');
    expect(webZh.rgbaChannelList, '输入识别为 RGBA 通道列表。');
    expect(webZh.rgbChannelList, '输入识别为 RGB 通道列表。');
    // —— 颜色：校核提示与错误 ——
    expect(webZh.alphaInsight, '包含透明度，复制到不支持 alpha 的场景时请使用 HEX RGB。');
    expect(webZh.colorValueNeeded, '请输入颜色值');
    expect(webZh.colorInputNeeded,
        '请输入 HEX、RGB、RGBA、HSL、Color(0xAARRGGBB) 或 CSS 命名色，例如 #5B47FF、rgb(91,71,255)、hsl(250 100% 60%)');
  });

  test('Web 格式组的英文侧都没有汉字、没有空串，而且真的换了', () {
    final pairs = <String, List<String>>{
      // —— URL 编解码 ——
      'modeFullUrl': [webZh.modeFullUrl, webEn.modeFullUrl],
      'modeRelativeUrl': [webZh.modeRelativeUrl, webEn.modeRelativeUrl],
      'modeUrlComponent': [webZh.modeUrlComponent, webEn.modeUrlComponent],
      'sourceCurlCommand': [webZh.sourceCurlCommand, webEn.sourceCurlCommand],
      'sourceHttpRequestLine': [
        webZh.sourceHttpRequestLine,
        webEn.sourceHttpRequestLine
      ],
      'modeLabel': [webZh.modeLabel('X'), webEn.modeLabel('X')],
      'originalLength': [
        webZh.originalLength(12),
        webEn.originalLength(12)
      ],
      'resultLength': [webZh.resultLength(12), webEn.resultLength(12)],
      'lengthDelta': [webZh.lengthDelta('+3'), webEn.lengthDelta('+3')],
      'queryParameterCount': [
        webZh.queryParameterCount(2),
        webEn.queryParameterCount(2)
      ],
      'percentTripletCount': [
        webZh.percentTripletCount(2),
        webEn.percentTripletCount(2)
      ],
      'extractedFrom': [
        webZh.extractedFrom('X'),
        webEn.extractedFrom('X')
      ],
      'decodedByMode': [
        webZh.decodedByMode('X'),
        webEn.decodedByMode('X')
      ],
      'encodedByMode': [
        webZh.encodedByMode('X'),
        webEn.encodedByMode('X')
      ],
      'plusAsSpace': [webZh.plusAsSpace, webEn.plusAsSpace],
      'queryCountEstimated': [
        webZh.queryCountEstimated,
        webEn.queryCountEstimated
      ],
      'queryKeysEncoded': [webZh.queryKeysEncoded, webEn.queryKeysEncoded],
      'invalidPercentEncoding': [
        webZh.invalidPercentEncoding,
        webEn.invalidPercentEncoding
      ],
      // —— query 参数 ——
      'noParameters': [webZh.noParameters, webEn.noParameters],
      'noParametersDetail': [
        webZh.noParametersDetail,
        webEn.noParametersDetail
      ],
      'parameterCount': [
        webZh.parameterCount(2),
        webEn.parameterCount(2)
      ],
      'hostLine': [webZh.hostLine('h'), webEn.hostLine('h')],
      'pathLine': [webZh.pathLine('p'), webEn.pathLine('p')],
      'fragmentLine': [webZh.fragmentLine('f'), webEn.fragmentLine('f')],
      'parsedSummary': [
        webZh.parsedSummary(2, 2),
        webEn.parsedSummary(2, 2)
      ],
      'repeatedKeys': [webZh.repeatedKeys('a'), webEn.repeatedKeys('a')],
      'semicolonSeparators': [
        webZh.semicolonSeparators,
        webEn.semicolonSeparators
      ],
      'lineSeparators': [webZh.lineSeparators, webEn.lineSeparators],
      'emptyInput': [webZh.emptyInput, webEn.emptyInput],
      'inputFullUrlInRequestLine': [
        webZh.inputFullUrlInRequestLine,
        webEn.inputFullUrlInRequestLine
      ],
      'inputFullUrl': [webZh.inputFullUrl, webEn.inputFullUrl],
      'inputRequestLine': [webZh.inputRequestLine, webEn.inputRequestLine],
      'inputRelativeUrl': [webZh.inputRelativeUrl, webEn.inputRelativeUrl],
      'inputQueryStringOrForm': [
        webZh.inputQueryStringOrForm,
        webEn.inputQueryStringOrForm
      ],
      'inputUrlFragmentQuery': [
        webZh.inputUrlFragmentQuery,
        webEn.inputUrlFragmentQuery
      ],
      'inputCurlFormFields': [
        webZh.inputCurlFormFields,
        webEn.inputCurlFormFields
      ],
      'inputCurlNoQueryFound': [
        webZh.inputCurlNoQueryFound,
        webEn.inputCurlNoQueryFound
      ],
      'inputCurlMergedUrlQueryAndGet': [
        webZh.inputCurlMergedUrlQueryAndGet,
        webEn.inputCurlMergedUrlQueryAndGet
      ],
      'inputCurlMergedUrlQueryAndData': [
        webZh.inputCurlMergedUrlQueryAndData,
        webEn.inputCurlMergedUrlQueryAndData
      ],
      'inputCurlMergedUrlQuery': [
        webZh.inputCurlMergedUrlQuery,
        webEn.inputCurlMergedUrlQuery
      ],
      'inputCurlGetMergedData': [
        webZh.inputCurlGetMergedData,
        webEn.inputCurlGetMergedData
      ],
      'inputCurlMergedQueryAndData': [
        webZh.inputCurlMergedQueryAndData,
        webEn.inputCurlMergedQueryAndData
      ],
      'inputCurlUrl': [webZh.inputCurlUrl, webEn.inputCurlUrl],
      'inputCurlFullUrl': [webZh.inputCurlFullUrl, webEn.inputCurlFullUrl],
      'inputCurlRelativeUrl': [
        webZh.inputCurlRelativeUrl,
        webEn.inputCurlRelativeUrl
      ],
      // —— 颜色 ——
      'namedColor': [webZh.namedColor('red'), webEn.namedColor('red')],
      'rgbaColor': [webZh.rgbaColor, webEn.rgbaColor],
      'rgbColor': [webZh.rgbColor, webEn.rgbColor],
      'hslaColor': [webZh.hslaColor, webEn.hslaColor],
      'hslColor': [webZh.hslColor, webEn.hslColor],
      'flutterColor': [webZh.flutterColor, webEn.flutterColor],
      'argbHexValue': [webZh.argbHexValue, webEn.argbHexValue],
      'rgbHexValue': [webZh.rgbHexValue, webEn.rgbHexValue],
      'labelledHexValue': [webZh.labelledHexValue, webEn.labelledHexValue],
      'shortHex3': [webZh.shortHex3, webEn.shortHex3],
      'shortHex6': [webZh.shortHex6, webEn.shortHex6],
      'argbHex4': [webZh.argbHex4, webEn.argbHex4],
      'argbHex8': [webZh.argbHex8, webEn.argbHex8],
      'labelledRgb': [webZh.labelledRgb, webEn.labelledRgb],
      'labelledRgba': [webZh.labelledRgba, webEn.labelledRgba],
      'argbChannelList': [webZh.argbChannelList, webEn.argbChannelList],
      'rgbaChannelList': [webZh.rgbaChannelList, webEn.rgbaChannelList],
      'rgbChannelList': [webZh.rgbChannelList, webEn.rgbChannelList],
      'alphaInsight': [webZh.alphaInsight, webEn.alphaInsight],
      'colorValueNeeded': [webZh.colorValueNeeded, webEn.colorValueNeeded],
      'colorInputNeeded': [webZh.colorInputNeeded, webEn.colorInputNeeded],
    };

    // 中文：**`modeQueryString` 这一条两侧逐字节相同，是故意的，不是漏翻。** 原文写的就是
    //       `'query string'`——中文界面下它也是这几个英文字母，因为那是这个格式的**名字**，
    //       不是一句要翻译的话。它照样要过"没有空串、没有汉字"两关，只是不过"真的换了"那一关。
    // English: **`modeQueryString` is byte-identical on both sides on purpose, not from a missed
    //          translation.** The original read `'query string'` — those English words already
    //          appeared in the Chinese interface, because that is the format's **name** rather than a
    //          sentence to translate. It still faces the "no empty string, no CJK" checks; it just
    //          does not face the "really changed" one.
    const identicalByDesign = <String>{'modeQueryString'};

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
    // 中文：`modeQueryString` 不在 `pairs` 里（它两侧相同，过不了最后那一关），单独比。
    // English: `modeQueryString` is not in `pairs` (it is identical on both sides and would fail the
    //          final check); it is compared on its own here.
    expect(webZh.modeQueryString, 'query string');
    expect(webEn.modeQueryString, webZh.modeQueryString);
    expect(identicalByDesign.length, 1, reason: '这张名单不该悄悄变长');
    expect(pairs.length, 66,
        reason: 'Web 格式组 67 个字段（URL 编解码 19 + query 参数 27 + 颜色 21），'
            '减掉不在 `pairs` 里的 `modeQueryString` 是 66，漏一条这里就会少一条');
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
