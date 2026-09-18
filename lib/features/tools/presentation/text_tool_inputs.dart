/// 中文：**每个文本工具「起手就有什么」与「这个框提示什么」。** 两张按工具 id 查的表，原来长在
///       `text_tool_detail_screen.dart` 里（`_defaultInput` 与 `_hintText` 两个私有方法），本轮
///       按「**这份知识属于谁**」搬出来：它们是**关于工具的内容**（某个工具打开时该填哪一串、该
///       提示哪一句），不是那个屏幕的逻辑——屏幕只问这两张表要字符串，然后把它放进输入框与
///       `hintText`。表里没有一行代码读屏、读控制器或读 `BuildContext`：文案表由调用方传进来
///       （`ToolsStrings.forLanguage` 的那一份），所以这里连语言都不知道。
///
///       **为什么 `defaultInputFor` 里有两个例子来自文案表**（`url_codec` 与 `text_stats`）：那两个
///       工具的示例文本本身就是界面文案（`示例数据` 那一类），必须跟着界面语言走；其余十六个是
///       记号或英文示例，与语言无关。判据与理由没有动，只是换了住址。
///
///       **搬的只是位置**：两张表的键、每一行的值、`_ => ''` 与 `_ => strings.hintDefault` 两个兜底
///       逐字相同；`timestamp` 那一行仍然读当下时间（所以每次调用都要重新查表，不能缓存）。
///
/// English: **what each text tool starts with and what its field hints.** Two tables keyed by tool id,
///          moved out of `text_tool_detail_screen.dart` (the private `_defaultInput` and `_hintText`)
///          along the "**whose knowledge is this**" seam: they are **content about the tools** (which
///          string a given tool opens with, which sentence it hints), not that screen's logic — the
///          screen asks these tables for a string and puts it in the field and its `hintText`. Nothing
///          here reads a screen, a controller or a `BuildContext`: the copy table arrives as an
///          argument (`ToolsStrings.forLanguage`'s instance), so this file does not even know the
///          language.
///
///          **Why two of `defaultInputFor`'s samples come from the copy table** (`url_codec` and
///          `text_stats`): those two tools' sample text *is* interface copy (the "sample data" class)
///          and has to follow the interface language, while the other sixteen are marks or English
///          samples and do not. The judgement and its reasons did not change — only the address.
///
///          **Only the position moved**: both tables' keys, every row's value, and the two fallbacks
///          (`_ => ''` and `_ => strings.hintDefault`) are character for character what they were; the
///          `timestamp` row still reads the current clock (so the table must be consulted afresh on
///          every call, never cached).
library;

import 'tools_strings.dart';

/// 中文：这个工具打开时输入框里先放什么。空串表示放空。
/// English: what this tool's field starts with when it opens; an empty string means it opens empty.
String defaultInputFor(String id, ToolsStrings strings) {
  return switch (id) {
    'base_convert' => '0xFF',
    'timestamp' => (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
    'color_convert' => '#5B47FF',
    'base64' => 'NekoCalc',
    'url_codec' => strings.urlCodecSample,
    'json_format' =>
      '{"name":"NekoCalc","tools":["calculator","units","notes"]}',
    'ascii_unicode' => 'NekoCalc',
    'bitwise' => '12 5',
    'checksum' => 'NekoCalc',
    'uuid' => '',
    'jwt_decode' =>
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJOZWtvQ2FsYyIsImV4cCI6MTg5MzQ1NjAwMH0.signature',
    'query_params' => 'https://example.com/#/tools?tab=text&id=query_params',
    'html_entities' => '<div class="name">NekoCalc & Tools</div>',
    'regex_test' => r'\d+\nNekoCalc 2026 build 42',
    'text_stats' => strings.textStatsSample,
    'csv_json' => 'name,category\nNekoCalc,calculator\nGraph,tool',
    'fnv_crc' => 'NekoCalc',
    _ => '',
  };
}

/// 中文：这个工具输入框下方的提示。没有专属提示的工具走 `hintDefault`。
/// English: the hint under this tool's field; tools without one of their own get `hintDefault`.
String hintTextFor(String id, ToolsStrings strings) {
  return switch (id) {
    'base_convert' => strings.hintBaseConvert,
    'timestamp' => strings.hintTimestamp,
    'color_convert' => strings.hintColorConvert,
    'base64' => strings.hintBase64,
    'url_codec' => strings.hintUrlCodec,
    'json_format' => strings.hintJsonFormat,
    'ascii_unicode' => strings.hintAsciiUnicode,
    'bitwise' => strings.hintBitwise,
    'checksum' => strings.hintChecksum,
    'uuid' => strings.hintUuid,
    'jwt_decode' => strings.hintJwtDecode,
    'query_params' => strings.hintQueryParams,
    'html_entities' => strings.hintHtmlEntities,
    'regex_test' => strings.hintRegexTest,
    'text_stats' => strings.hintTextStats,
    'csv_json' => strings.hintCsvJson,
    'fnv_crc' => strings.hintFnvCrc,
    _ => strings.hintDefault,
  };
}
