import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';
import 'text_tool_codec_strings.dart';
import 'text_tool_data_strings.dart';
import 'text_tool_stats_strings.dart';
import 'text_tool_text_strings.dart';
import 'text_tool_timestamp_strings.dart';
import 'text_tool_web_strings.dart';

// 中文：`TextToolController` 的各个 `part` 文件要看得见这几张表；它们 `part of` 控制器，
//       只继承控制器的 import，所以这里把兄弟表一并转出去，免得每个 part 各写一行 import。
// English: `TextToolController`'s `part` files need to see these tables; being `part of` the
//          controller they inherit only the controller's imports, so the sibling tables are
//          re-exported here rather than each part carrying an import line of its own.
export 'text_tool_codec_strings.dart';
export 'text_tool_data_strings.dart';
export 'text_tool_stats_strings.dart';
export 'text_tool_text_strings.dart';
export 'text_tool_timestamp_strings.dart';
export 'text_tool_web_strings.dart';

/// 中文：文本 / 编程类工具这一族的界面文案表。机制本身（为什么是手写分表而不是 ARB /
///       `gen-l10n`、为什么表是 `static final` 而不是 `const`）与设置页那张表共用一套理由，
///       写在 `settings_strings.dart` 的文件头上，这里不重抄。
///
///       **为什么这一族有七张表而不是一张。** 这一族是控制器产出的**长句**——校核提示、
///       输入识别说明、错误详情——一条就是十几个字，全部塞进一个类会冲破八百行的硬线。
///       按"谁产出这些话"切开之后，每张表一屏看得完：
///       - `TextToolStrings`（本文件）：把七张表并成一个入参的**门面**，外加所有工具共用的
///         输出外壳（状态行、复制正文的标签、兜底错误）。
///       - `TextToolTextStrings`：文本识别组——UUID、JSON、正则、自定义公式。
///       - `TextToolStatsStrings`：文本统计单独一张，它一个工具就产出约五十条长句，
///         并进上一张会把那张推过八百行。
///       - `TextToolDataStrings`：数据组——CSV/JSON 表格、JWT 解码。
///       - `TextToolCodecStrings`：编解码组——Base64/校验和、进制与位运算。
///       - `TextToolWebStrings`：Web 格式组——URL 编解码、query 参数、CSS 颜色。
///       - `TextToolTimestampStrings`：时间戳一张，它一条链上每一层都在产出中文。
///
///       **后三张是后来补上的**（第一轮只到数据组为止）。它们共用
///       `_ParsedByteInput` / `_ParsedInteger` / `_ParsedColor` / `_ParsedQueryInput` /
///       `_ParsedTimestamp` 那套描述符机制，所以是**连同描述符一起**改的：
///       表沿着参数一路递进解析函数，字段里存的是**已经定好的那句话**，
///       控制器只负责挑与拼。每一张的分界（哪些是输入文法、哪些是判据）写在各自文件头上。
///       **`lib/application/controllers/text_tool_*.dart` 现在是 0 条中文界面字面量**，
///       剩下的只有那张豁免表点名的输入文法与判据——`text_tool_strings_test.dart` 里那条
///       扫描断言就是这件事的可执行版本。
///
///       **为什么控制器要接一张表进去，而不是像别处那样就地 `of(context)`。**
///       `TextToolController` 是**纯 Dart**、不持有 `BuildContext`（`text_tool_controller.dart`
///       一行 Flutter 都没 import），它和 `lib/domain` 一样在纯 Dart 测试里跑。所以语言只能
///       顺着参数进来：界面层在 `build` 里取一次 `TextToolStrings.of(context)`，往下传给
///       `calculate`。这与 `DataFitStrings.forLanguage` 给不持上下文的调用方留的那条路是同一件事。
///
///       **本表只装"给人看的字"。** 三样东西刻意不进来，它们是**数据不是界面文案**：
///       1. **输入文法**。`text_tool_regex_tools.dart` 与 `text_tool_custom_formula_tools.dart` 里
///          那些 `r'...|正则|表达式...'` 是**用来解析用户输入的**——它们匹配的是用户可能敲进来的
///          中文标签本身（`公式: a+b`、`flags: g`）。把它们翻了，这些工具就再也读不懂中文输入了。
///       2. **与输入比较的判据**。`text_tool_timestamp_tools.dart` 的 `normalized == '现在'` 与
///          `== '北京时间'`、`text_tool_csv_tools.dart` 的 `first == '单位' || first == '量纲'`
///          是判别式：翻掉它们等于改行为。
///       3. **工具名、类目名、单位名、HiPER 键面**——产品决定保持中文，见 `tools_strings.dart`。
///
///       **`TextToolOutput.hasError` 从"比字符串"改成了真字段。** 它原先靠
///       `primary.trim() == '输入无效' || primary.trim().startsWith('不支持')` 判断，那是把
///       一句**要显示给用户的话**同时当成了判据——英文下这句话会变，判据就永远为假，
///       错误卡会悄悄变成绿色对勾。现在由产出方在构造时写明 `hasError: true`，
///       两个中文短语回到它们本来的身份：只是文案。
/// English: The string tables for the text/programming tool family. The mechanism itself (why
///          hand-written tables rather than ARB / `gen-l10n`, why the tables are `static final`
///          rather than `const`) shares one set of reasons with the settings table and is written on
///          `settings_strings.dart`'s file head; it is not copied again here.
///
///          **Why this family has seven tables rather than one.** These tools produce **long
///          sentences** — insight lines, input-recognition notes, error details — a dozen characters
///          apiece; folding them into one class would cross the hard 800-line limit. Split by *who
///          produces the sentence*, each table stays readable in one screen:
///          - `TextToolStrings` (this file): the **facade** that packs the seven tables into one
///            argument, plus the output chrome every tool shares (status lines, the labels inside
///            the copied report, the fallback error).
///          - `TextToolTextStrings`: the recognition group — UUID, JSON, regex, custom formula.
///          - `TextToolStatsStrings`: text statistics get a table of their own, because that single
///            tool produces about fifty long sentences and folding them into the table above would
///            push it past the 800-line limit.
///          - `TextToolDataStrings`: the data group — CSV/JSON tables and the JWT decoder.
///          - `TextToolCodecStrings`: the codec group — Base64/checksums, bases and bitwise.
///          - `TextToolWebStrings`: the web-format group — URL codec, query parameters, CSS colours.
///          - `TextToolTimestampStrings`: timestamps, whose chain produces Chinese at every layer.
///
///          **The last three arrived later** (the first round stopped at the data group). They share
///          the `_ParsedByteInput` / `_ParsedInteger` / `_ParsedColor` / `_ParsedQueryInput` /
///          `_ParsedTimestamp` descriptor machinery, so they were changed **together with their
///          descriptors**: the table is handed down through the parse functions and the field holds
///          a sentence that is **already settled**, leaving the controller only to pick and join.
///          Each table's own boundaries (what is input grammar, what is a branch condition) are on
///          its own file head. **`lib/application/controllers/text_tool_*.dart` now holds zero
///          Chinese interface literals**, and what remains is only the input grammar and branch
///          conditions the exemption table names — the scanning assertion in
///          `text_tool_strings_test.dart` is that fact's executable form.
///
///          **Why the controller takes a table rather than calling `of(context)` where it needs
///          one.** `TextToolController` is **plain Dart** and holds no `BuildContext`
///          (`text_tool_controller.dart` imports no Flutter at all); like `lib/domain` it runs in
///          plain Dart tests. The language therefore arrives through the parameter list: the screen
///          reads `TextToolStrings.of(context)` once in `build` and hands it down to `calculate`.
///          That is the same route `DataFitStrings.forLanguage` leaves open for callers without a
///          context.
///
///          **This table holds human-facing text only.** Three things deliberately stay out because
///          they are **data, not interface copy**:
///          1. **Input grammar.** The `r'...|正则|表达式...'` patterns in `text_tool_regex_tools.dart`
///             and `text_tool_custom_formula_tools.dart` **parse what the user types** — they match
///             Chinese labels the user may well type (`公式: a+b`, `flags: g`). Translating them would
///             stop those tools reading Chinese input at all.
///          2. **Discriminants compared against input.** `normalized == '现在'` and
///             `== '北京时间'` in `text_tool_timestamp_tools.dart`, and
///             `first == '单位' || first == '量纲'` in `text_tool_csv_tools.dart`, are branch
///             conditions; translating them changes behaviour.
///          3. **Tool names, category names, unit names, HiPER key faces** — a product decision to
///             stay Chinese, see `tools_strings.dart`.
///
///          **`TextToolOutput.hasError` changed from a string comparison to a real field.** It used
///          to be `primary.trim() == '输入无效' || primary.trim().startsWith('不支持')`, which made a
///          **sentence meant for the user** double as a branch condition — in English that sentence
///          changes, the condition is then always false, and the error card quietly turns into a
///          green tick. The producers now say `hasError: true` at construction, and the two Chinese
///          phrases go back to being what they always were: copy.
@immutable
class TextToolStrings {
  const TextToolStrings({
    required this.output,
    required this.text,
    required this.stats,
    required this.data,
    required this.codec,
    required this.web,
    required this.timestamp,
  });

  final TextToolOutputStrings output;
  final TextToolTextStrings text;
  final TextToolStatsStrings stats;
  final TextToolDataStrings data;
  final TextToolCodecStrings codec;
  final TextToolWebStrings web;
  final TextToolTimestampStrings timestamp;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过，
  ///       而不是静默回落到中文。
  /// English: Picks the tables for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here rather than silently falling back to Chinese.
  static TextToolStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。两条路径共用这一个
  ///       switch，不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext`. Both routes share this
  ///          one switch, so they cannot drift apart.
  static TextToolStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => textToolZh,
      AppLanguage.en => textToolEn,
    };
  }

  static final TextToolStrings textToolZh = TextToolStrings(
    output: TextToolOutputStrings.outputZh,
    text: TextToolTextStrings.textZh,
    stats: TextToolStatsStrings.statsZh,
    data: TextToolDataStrings.dataZh,
    codec: TextToolCodecStrings.codecZh,
    web: TextToolWebStrings.webZh,
    timestamp: TextToolTimestampStrings.timestampZh,
  );

  static final TextToolStrings textToolEn = TextToolStrings(
    output: TextToolOutputStrings.outputEn,
    text: TextToolTextStrings.textEn,
    stats: TextToolStatsStrings.statsEn,
    data: TextToolDataStrings.dataEn,
    codec: TextToolCodecStrings.codecEn,
    web: TextToolWebStrings.webEn,
    timestamp: TextToolTimestampStrings.timestampEn,
  );
}

/// 中文：所有文本工具共用的输出外壳——状态卡上那两行、复制出来的报告里的标签、兜底错误。
///       逐条界线见 [TextToolStrings] 的文件头。
/// English: The output chrome every text tool shares — the two lines on the status card, the labels
///          inside the copied report, and the fallback error. For the boundaries see
///          [TextToolStrings]'s file head.
@immutable
class TextToolOutputStrings {
  const TextToolOutputStrings({
    required this.invalidInput,
    required this.unsupportedTool,
    required this.unsupportedToolDetail,
    required this.retryHint,
    required this.statusNeedsFix,
    required this.statusReusable,
    required this.emptySize,
    required this.charCount,
    required this.charLineCount,
    required this.insightCount,
    required this.statusReading,
    required this.copyInput,
    required this.copyStatus,
    required this.copyPrimary,
    required this.copyDetail,
    required this.copyInsights,
    required this.htmlEntityDecoded,
    required this.htmlEntitySupport,
    required this.htmlEntityUnknownKept,
    required this.htmlTextEncoded,
    required this.htmlEscaped,
  });

  /// 中文：兜底错误的主结果。它同时也是**构造时** `hasError: true` 的搭档，见类文档。
  /// English: The primary line of the fallback errors. It is also the partner of
  ///          `hasError: true` at construction; see the class docs.
  final String invalidInput;
  final String unsupportedTool;
  final String unsupportedToolDetail;

  /// 中文：出错且详情为空时的兜底一句；报错那一格也用它做校核提示。
  /// English: The fallback sentence when an error carries no detail; the catch-all also uses it as
  ///          the insight line.
  final String retryHint;

  // —— 状态卡 ——
  final String statusNeedsFix;
  final String statusReusable;
  // —— 主结果 / 详细结果的尺寸说法 ——
  final String emptySize;
  final String Function(int chars) charCount;
  final String Function(int chars, int lines) charLineCount;
  final String Function(int count) insightCount;
  final String Function(String primary, String detail, String insight)
      statusReading;
  // —— 复制出来的报告里的标签 ——
  final String copyInput;
  final String Function(String statusTitle) copyStatus;
  final String copyPrimary;
  final String copyDetail;
  final String copyInsights;
  // —— HTML 实体工具 ——
  final String Function(int changed, int unknown) htmlEntityDecoded;
  final String htmlEntitySupport;
  final String htmlEntityUnknownKept;
  final String htmlTextEncoded;
  final String htmlEscaped;

  static TextToolOutputStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  static TextToolOutputStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => outputZh,
      AppLanguage.en => outputEn,
    };
  }

  static final TextToolOutputStrings outputZh = TextToolOutputStrings(
    invalidInput: '输入无效',
    unsupportedTool: '不支持的文本工具',
    unsupportedToolDetail: '请从工具中心打开已登记的编程与数据工具。',
    retryHint: '请检查输入格式后重试。',
    statusNeedsFix: '输入需要修正',
    statusReusable: '结果可复用',
    emptySize: '为空',
    charCount: (chars) => '$chars 字符',
    charLineCount: (chars, lines) => '$chars 字符/$lines 行',
    insightCount: (count) => '，$count 条校核提示',
    statusReading: (primary, detail, insight) =>
        '主结果 $primary，详细结果 $detail$insight',
    copyInput: '输入:',
    copyStatus: (statusTitle) => '状态: $statusTitle',
    copyPrimary: '主结果:',
    copyDetail: '详细结果:',
    copyInsights: '校核:',
    htmlEntityDecoded: (changed, unknown) =>
        '检测为 HTML 实体文本，已解码 $changed 处实体。\n未知实体: $unknown',
    htmlEntitySupport: '支持常见命名实体、十进制数字实体和十六进制数字实体。',
    htmlEntityUnknownKept: '未知实体已保留原文，避免误改内容。',
    htmlTextEncoded: '检测为普通文本，已编码 HTML 特殊字符。',
    htmlEscaped: '已转义 &、<、>、引号、撇号和不间断空格。',
  );

  static final TextToolOutputStrings outputEn = TextToolOutputStrings(
    invalidInput: 'Invalid input',
    unsupportedTool: 'Unsupported text tool',
    unsupportedToolDetail:
        'Open a registered programming or data tool from the tool centre.',
    retryHint: 'Check the input format and try again.',
    statusNeedsFix: 'Input needs fixing',
    statusReusable: 'Result is reusable',
    emptySize: 'empty',
    charCount: (chars) => '$chars characters',
    charLineCount: (chars, lines) => '$chars characters / $lines lines',
    insightCount: (count) => ', $count check notes',
    statusReading: (primary, detail, insight) =>
        'Primary result $primary, detail $detail$insight',
    copyInput: 'Input:',
    copyStatus: (statusTitle) => 'Status: $statusTitle',
    copyPrimary: 'Primary result:',
    copyDetail: 'Detail:',
    copyInsights: 'Checks:',
    htmlEntityDecoded: (changed, unknown) =>
        'Detected HTML entity text; decoded $changed entities.\nUnknown entities: $unknown',
    htmlEntitySupport:
        'Accepts common named entities, decimal numeric entities and hexadecimal numeric entities.',
    htmlEntityUnknownKept:
        'Unknown entities were kept verbatim so the content is not altered by mistake.',
    htmlTextEncoded:
        'Detected plain text; encoded the HTML special characters.',
    htmlEscaped:
        'Escaped &, <, >, quotes, apostrophes and non-breaking spaces.',
  );
}
