import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：Web 格式组的界面文案表——URL 编解码、query 参数、CSS 颜色三个工具的长句。
///       **为什么控制器要接表进来**、以及**哪些中文刻意不翻**，两条理由都写在
///       `text_tool_strings.dart` 的文件头上，这里不重抄。
///
///       **为什么这三个工具住一张表。** 它们的共同点不是"都碰 URL"，而是**描述符的形状一样**：
///       每个都在解析阶段定一个「这次算哪一种」的标签，再把标签插进两三句模板里——
///       URL 编解码是 `mode`（`完整 URL` / `相对 URL` / `query string` / `URL 组件`）与
///       `sourceDescription`（`curl 命令` / `HTTP 请求行`），query 参数是
///       `_ParsedQueryInput.description` 一整句（十八种来路），颜色是 `_ParsedColor.source`
///       （二十一种识别分支）。三条链子的改法完全一样：**把表顺着参数递进解析函数**，
///       让字段里存的是已经定好的那句话，控制器只负责挑和拼。
///
///       **本表刻意不翻的两条，都是输入文法，翻掉就再也读不懂中文输入：**
///       - `text_tool_color_tools.dart` 的 `r'(?:\b(?:hex|color|colour)|颜色|色值)\s*[:=]\s*…'`：
///         它解析的是用户敲的 `色值: 5B47FF` 这种**带中文标签的**色值写法。
///       - 同一文件的 `r'(?:\b(?:hex|color|colour)|颜色|色值)\s*[:=]'`：`_hexColorSource`
///         用它判断"用户是不是写了标签"，好挑哪一句识别说明——**它同时是文法与判据**。
///
///       **本表里没有别的判据。** 三个工具的 `mode` / `description` / `source` 三个字段
///       只被插进输出，反向不参与任何 `==` / `switch` / map key。`query string` 与
///       `URL 组件` 里的 ASCII 片段本来就跨语言相同，它们照样进表——表管的是"这一格由谁供给"，
///       不是"这一格里有没有汉字"。
/// English: The copy table for the web-format group — the URL codec, query parameters and CSS
///          colours. **Why the controller takes a table as an argument** and **which Chinese is
///          deliberately left untranslated** are both written on `text_tool_strings.dart`'s file head
///          and not copied again here.
///
///          **Why these three tools share a table.** What they have in common is not "they all touch
///          URLs" but that **their descriptors have the same shape**: each one settles a "which kind
///          is this" label while parsing and then interpolates that label into two or three sentence
///          templates — the URL codec has `mode` (`full URL` / `relative URL` / `query string` /
///          `URL component`) and `sourceDescription` (`curl command` / `HTTP request line`), query
///          parameters have one whole `_ParsedQueryInput.description` (eighteen provenances), and
///          colours have `_ParsedColor.source` (twenty-one recognition branches). All three chains
///          change the same way: **hand the table down through the parse functions** so the field
///          holds a sentence that is already settled and the controller only picks and joins.
///
///          **Two things deliberately untranslated here, both input grammar — translate either and
///          Chinese input stops being understood:**
///          - `r'(?:\b(?:hex|color|colour)|颜色|色值)\s*[:=]\s*…'` in `text_tool_color_tools.dart`
///            parses **Chinese-labelled** colour spellings the user types, such as `色值: 5B47FF`.
///          - `r'(?:\b(?:hex|color|colour)|颜色|色值)\s*[:=]'` in the same file lets `_hexColorSource`
///            tell whether the user wrote a label, so as to pick which recognition note to emit — it
///            is **both grammar and branch condition**.
///
///          **No other branch conditions live here.** The `mode` / `description` / `source` fields of
///          all three tools are only ever interpolated into the output and never branch in an `==`, a
///          `switch` or a map key. The ASCII fragments inside `query string` and `URL 组件` are the
///          same in both languages and still go through the table: a table decides **who supplies
///          this slot**, not whether the slot happens to contain Chinese.
@immutable
class TextToolWebStrings {
  const TextToolWebStrings({
    // —— URL 编解码：模式与来源 ——
    required this.modeFullUrl,
    required this.modeRelativeUrl,
    required this.modeQueryString,
    required this.modeUrlComponent,
    required this.sourceCurlCommand,
    required this.sourceHttpRequestLine,
    // —— URL 编解码：正文各行 ——
    required this.modeLabel,
    required this.originalLength,
    required this.resultLength,
    required this.lengthDelta,
    required this.queryParameterCount,
    required this.percentTripletCount,
    // —— URL 编解码：校核提示 ——
    required this.extractedFrom,
    required this.decodedByMode,
    required this.encodedByMode,
    required this.plusAsSpace,
    required this.queryCountEstimated,
    required this.queryKeysEncoded,
    // —— URL 编解码：错误 ——
    required this.invalidPercentEncoding,
    // —— query 参数：正文 ——
    required this.noParameters,
    required this.noParametersDetail,
    required this.parameterCount,
    required this.hostLine,
    required this.pathLine,
    required this.fragmentLine,
    required this.parsedSummary,
    required this.repeatedKeys,
    // —— query 参数：校核提示 ——
    required this.semicolonSeparators,
    required this.lineSeparators,
    // —— query 参数：输入识别 ——
    required this.emptyInput,
    required this.inputFullUrlInRequestLine,
    required this.inputFullUrl,
    required this.inputRequestLine,
    required this.inputRelativeUrl,
    required this.inputQueryStringOrForm,
    required this.inputUrlFragmentQuery,
    required this.inputCurlFormFields,
    required this.inputCurlNoQueryFound,
    required this.inputCurlMergedUrlQueryAndGet,
    required this.inputCurlMergedUrlQueryAndData,
    required this.inputCurlMergedUrlQuery,
    required this.inputCurlGetMergedData,
    required this.inputCurlMergedQueryAndData,
    required this.inputCurlUrl,
    required this.inputCurlFullUrl,
    required this.inputCurlRelativeUrl,
    // —— 颜色：输入识别 ——
    required this.namedColor,
    required this.rgbaColor,
    required this.rgbColor,
    required this.hslaColor,
    required this.hslColor,
    required this.flutterColor,
    required this.argbHexValue,
    required this.rgbHexValue,
    required this.labelledHexValue,
    required this.shortHex3,
    required this.shortHex6,
    required this.argbHex4,
    required this.argbHex8,
    required this.labelledRgb,
    required this.labelledRgba,
    required this.argbChannelList,
    required this.rgbaChannelList,
    required this.rgbChannelList,
    // —— 颜色：校核提示与错误 ——
    required this.alphaInsight,
    required this.colorValueNeeded,
    required this.colorInputNeeded,
  });

  // —— URL 编解码：模式与来源 ——
  final String modeFullUrl;
  final String modeRelativeUrl;

  /// 中文：原文就是 ASCII（`query string`），**两种语言下逐字节相同**——它照样是一件"由表供给
  ///       的格子"，只是这件格子的两个语言侧恰好一样。`text_tool_*_strings_test.dart` 里有一份
  ///       `identicalByDesign` 名单点出它，免得被当成漏翻。
  /// English: The original is already ASCII (`query string`) and is **byte-identical in both
  ///          languages** — it is still a slot supplied by the table, it just happens to read the
  ///          same on both sides. An `identicalByDesign` list in `text_tool_*_strings_test.dart`
  ///          names it so it is not mistaken for a missed translation.
  final String modeQueryString;
  final String modeUrlComponent;
  final String sourceCurlCommand;
  final String sourceHttpRequestLine;

  // —— URL 编解码：正文各行 ——
  final String Function(String mode) modeLabel;
  final String Function(int length) originalLength;
  final String Function(int length) resultLength;
  final String Function(String delta) lengthDelta;
  final String Function(int count) queryParameterCount;
  final String Function(int count) percentTripletCount;

  // —— URL 编解码：校核提示 ——
  final String Function(String source) extractedFrom;
  final String Function(String mode) decodedByMode;
  final String Function(String mode) encodedByMode;
  final String plusAsSpace;
  final String queryCountEstimated;
  final String queryKeysEncoded;

  // —— URL 编解码：错误 ——
  final String invalidPercentEncoding;

  // —— query 参数：正文 ——
  final String noParameters;
  final String noParametersDetail;
  final String Function(int count) parameterCount;
  final String Function(String host) hostLine;
  final String Function(String path) pathLine;
  final String Function(String fragment) fragmentLine;
  final String Function(int values, int keys) parsedSummary;
  final String Function(String keys) repeatedKeys;

  // —— query 参数：校核提示 ——
  final String semicolonSeparators;
  final String lineSeparators;

  // —— query 参数：输入识别 ——
  final String emptyInput;
  final String inputFullUrlInRequestLine;
  final String inputFullUrl;
  final String inputRequestLine;
  final String inputRelativeUrl;
  final String inputQueryStringOrForm;
  final String inputUrlFragmentQuery;
  final String inputCurlFormFields;
  final String inputCurlNoQueryFound;
  final String inputCurlMergedUrlQueryAndGet;
  final String inputCurlMergedUrlQueryAndData;
  final String inputCurlMergedUrlQuery;
  final String inputCurlGetMergedData;
  final String inputCurlMergedQueryAndData;
  final String inputCurlUrl;
  final String inputCurlFullUrl;
  final String inputCurlRelativeUrl;

  // —— 颜色：输入识别 ——
  final String Function(String name) namedColor;
  final String rgbaColor;
  final String rgbColor;
  final String hslaColor;
  final String hslColor;
  final String flutterColor;
  final String argbHexValue;
  final String rgbHexValue;
  final String labelledHexValue;
  final String shortHex3;
  final String shortHex6;
  final String argbHex4;
  final String argbHex8;
  final String labelledRgb;
  final String labelledRgba;
  final String argbChannelList;
  final String rgbaChannelList;
  final String rgbChannelList;

  // —— 颜色：校核提示与错误 ——
  final String alphaInsight;
  final String colorValueNeeded;
  final String colorInputNeeded;

  static TextToolWebStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  static TextToolWebStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => webZh,
      AppLanguage.en => webEn,
    };
  }

  static final TextToolWebStrings webZh = TextToolWebStrings(
    modeFullUrl: '完整 URL',
    modeRelativeUrl: '相对 URL',
    modeQueryString: 'query string',
    modeUrlComponent: 'URL 组件',
    sourceCurlCommand: 'curl 命令',
    sourceHttpRequestLine: 'HTTP 请求行',
    modeLabel: (mode) => '模式: $mode',
    originalLength: (length) => '原长度: $length',
    resultLength: (length) => '结果长度: $length',
    lengthDelta: (delta) => '长度变化: $delta',
    queryParameterCount: (count) => 'Query 参数: $count 个',
    percentTripletCount: (count) => '百分号编码片段: $count 个',
    extractedFrom: (source) => '已从$source中提取 URL。',
    decodedByMode: (mode) => '检测到百分号编码，已按$mode解码。',
    encodedByMode: (mode) => '未检测到百分号编码，已按$mode编码。',
    plusAsSpace: 'Query 中的 + 已按空格处理。',
    queryCountEstimated: 'Query 参数数量按 & 分隔估算，重复键未在此处合并。',
    queryKeysEncoded: '已保留 URL 结构，仅编码 query 键和值。',
    invalidPercentEncoding: 'URL 百分号编码不完整或无效。',
    noParameters: '无参数',
    noParametersDetail: '没有解析到 query 参数。',
    parameterCount: (count) => '$count 个参数',
    hostLine: (host) => '主机: $host',
    pathLine: (path) => '路径: $path',
    fragmentLine: (fragment) => '片段: $fragment',
    parsedSummary: (values, keys) => '已解析 $values 个 query 参数，$keys 个唯一键。',
    repeatedKeys: (keys) => '重复键: $keys。',
    semicolonSeparators: '已兼容分号分隔的表单参数。',
    lineSeparators: '已兼容换行分隔的表单参数。',
    emptyInput: '输入为空。',
    inputFullUrlInRequestLine: '输入识别为 HTTP 请求行中的完整 URL。',
    inputFullUrl: '输入识别为完整 URL。',
    inputRequestLine: '输入识别为 HTTP 请求行。',
    inputRelativeUrl: '输入识别为相对 URL。',
    inputQueryStringOrForm: '输入识别为 query string / 表单正文。',
    inputUrlFragmentQuery: '输入识别为 URL 片段中的 query。',
    inputCurlFormFields: '输入识别为 curl 命令中的表单参数。',
    inputCurlNoQueryFound: '输入识别为 curl 命令，但未找到 URL query 或表单参数。',
    inputCurlMergedUrlQueryAndGet:
        '输入识别为 curl 命令，已合并 --url-query 与 -G/--get 参数。',
    inputCurlMergedUrlQueryAndData:
        '输入识别为 curl 命令，已合并 --url-query 与 -d/--data 表单参数。',
    inputCurlMergedUrlQuery: '输入识别为 curl 命令，已合并 --url-query 参数。',
    inputCurlGetMergedData:
        '输入识别为 curl -G/--get 命令，已将 --data 参数合并为 URL query。',
    inputCurlMergedQueryAndData:
        '输入识别为 curl 命令，已合并 URL query 与 -d/--data 表单参数。',
    inputCurlUrl: '输入识别为 curl 命令中的 URL。',
    inputCurlFullUrl: '输入识别为 curl 命令中的完整 URL。',
    inputCurlRelativeUrl: '输入识别为 curl 命令中的相对 URL。',
    namedColor: (name) => '输入识别为 CSS 命名颜色 $name。',
    rgbaColor: '输入识别为 RGBA 颜色。',
    rgbColor: '输入识别为 RGB 颜色。',
    hslaColor: '输入识别为 HSLA 颜色。',
    hslColor: '输入识别为 HSL 颜色。',
    flutterColor: '输入识别为 Flutter/Android Color(0xAARRGGBB) 色值。',
    argbHexValue: '输入识别为 0xAARRGGBB 色值。',
    rgbHexValue: '输入识别为 0xRRGGBB 色值。',
    labelledHexValue: '输入识别为带标签 HEX 色值。',
    shortHex3: '输入识别为 3 位 HEX 颜色。',
    shortHex6: '输入识别为 6 位 HEX 颜色。',
    argbHex4: '输入识别为 4 位 ARGB HEX 颜色。',
    argbHex8: '输入识别为 ARGB HEX 颜色。',
    labelledRgb: '输入识别为标签式 RGB 颜色。',
    labelledRgba: '输入识别为标签式 RGBA 颜色。',
    argbChannelList: '输入识别为 ARGB 通道列表。',
    rgbaChannelList: '输入识别为 RGBA 通道列表。',
    rgbChannelList: '输入识别为 RGB 通道列表。',
    alphaInsight: '包含透明度，复制到不支持 alpha 的场景时请使用 HEX RGB。',
    colorValueNeeded: '请输入颜色值',
    colorInputNeeded:
        '请输入 HEX、RGB、RGBA、HSL、Color(0xAARRGGBB) 或 CSS 命名色，例如 #5B47FF、rgb(91,71,255)、hsl(250 100% 60%)',
  );

  static final TextToolWebStrings webEn = TextToolWebStrings(
    modeFullUrl: 'Full URL',
    modeRelativeUrl: 'Relative URL',
    modeQueryString: 'query string',
    modeUrlComponent: 'URL component',
    sourceCurlCommand: 'curl command',
    sourceHttpRequestLine: 'HTTP request line',
    modeLabel: (mode) => 'Mode: $mode',
    originalLength: (length) => 'Original length: $length',
    resultLength: (length) => 'Result length: $length',
    lengthDelta: (delta) => 'Length change: $delta',
    queryParameterCount: (count) => 'Query parameters: $count',
    percentTripletCount: (count) => 'Percent-encoded triplets: $count',
    extractedFrom: (source) => 'Extracted the URL from $source.',
    decodedByMode: (mode) => 'Percent encoding found; decoded as $mode.',
    encodedByMode: (mode) => 'No percent encoding found; encoded as $mode.',
    plusAsSpace: 'The + in the query was treated as a space.',
    queryCountEstimated:
        'The query parameter count is estimated by splitting on &; repeated keys are not merged here.',
    queryKeysEncoded:
        'The URL structure was kept; only the query keys and values were encoded.',
    invalidPercentEncoding: 'The URL percent encoding is incomplete or invalid.',
    noParameters: 'No parameters',
    noParametersDetail: 'No query parameters were parsed.',
    parameterCount: (count) => '$count parameters',
    hostLine: (host) => 'Host: $host',
    pathLine: (path) => 'Path: $path',
    fragmentLine: (fragment) => 'Fragment: $fragment',
    parsedSummary: (values, keys) =>
        'Parsed $values query parameters across $keys unique keys.',
    repeatedKeys: (keys) => 'Repeated keys: $keys.',
    semicolonSeparators: 'Semicolon-separated form parameters are supported.',
    lineSeparators: 'Line-break-separated form parameters are supported.',
    emptyInput: 'The input is empty.',
    inputFullUrlInRequestLine:
        'Recognised a full URL inside an HTTP request line.',
    inputFullUrl: 'Recognised a full URL.',
    inputRequestLine: 'Recognised an HTTP request line.',
    inputRelativeUrl: 'Recognised a relative URL.',
    inputQueryStringOrForm:
        'Recognised a query string / form body.',
    inputUrlFragmentQuery: 'Recognised a query inside a URL fragment.',
    inputCurlFormFields: 'Recognised form parameters inside a curl command.',
    inputCurlNoQueryFound:
        'Recognised a curl command, but found no URL query or form parameters.',
    inputCurlMergedUrlQueryAndGet:
        'Recognised a curl command and merged the --url-query and -G/--get parameters.',
    inputCurlMergedUrlQueryAndData:
        'Recognised a curl command and merged the --url-query and -d/--data form parameters.',
    inputCurlMergedUrlQuery:
        'Recognised a curl command and merged the --url-query parameters.',
    inputCurlGetMergedData:
        'Recognised a curl -G/--get command and merged the --data parameters into the URL query.',
    inputCurlMergedQueryAndData:
        'Recognised a curl command and merged the URL query with the -d/--data form parameters.',
    inputCurlUrl: 'Recognised the URL inside a curl command.',
    inputCurlFullUrl: 'Recognised the full URL inside a curl command.',
    inputCurlRelativeUrl: 'Recognised the relative URL inside a curl command.',
    namedColor: (name) => 'Recognised a CSS named colour $name.',
    rgbaColor: 'Recognised an RGBA colour.',
    rgbColor: 'Recognised an RGB colour.',
    hslaColor: 'Recognised an HSLA colour.',
    hslColor: 'Recognised an HSL colour.',
    flutterColor:
        'Recognised a Flutter/Android Color(0xAARRGGBB) value.',
    argbHexValue: 'Recognised a 0xAARRGGBB value.',
    rgbHexValue: 'Recognised a 0xRRGGBB value.',
    labelledHexValue: 'Recognised a labelled HEX value.',
    shortHex3: 'Recognised a 3-digit HEX colour.',
    shortHex6: 'Recognised a 6-digit HEX colour.',
    argbHex4: 'Recognised a 4-digit ARGB HEX colour.',
    argbHex8: 'Recognised an ARGB HEX colour.',
    labelledRgb: 'Recognised a labelled RGB colour.',
    labelledRgba: 'Recognised a labelled RGBA colour.',
    argbChannelList: 'Recognised an ARGB channel list.',
    rgbaChannelList: 'Recognised an RGBA channel list.',
    rgbChannelList: 'Recognised an RGB channel list.',
    alphaInsight:
        'The colour carries transparency; use the HEX RGB form where alpha is not supported.',
    colorValueNeeded: 'Enter a colour value',
    colorInputNeeded:
        'Enter HEX, RGB, RGBA, HSL, Color(0xAARRGGBB) or a CSS named colour, for example #5B47FF, rgb(91,71,255), hsl(250 100% 60%)',
  );
}
