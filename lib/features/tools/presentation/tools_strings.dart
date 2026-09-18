import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：工具首页 / 分类页 / 工具详情页 / 文本工具详情页的界面文案表，**按功能切分**——一张表、
///       表里并排放所有语言。（拟合页单独一张，见 `data_fit_strings.dart` 的文件头。）
///       机制本身（为什么是手写分表而不是 ARB / `gen-l10n`、为什么表是 `static final` 而不是
///       `const`）与设置页那张表共用一套理由，写在 `settings_strings.dart` 的文件头上，这里不重抄。
///
///       **本表只装"给人看的字"。** 两条口径值得写下来：
///       1. **工具的目录数据不进来。** 工具名、描述、公式、参数标签、单位、分类名
///          （`widget.tool.title`、`input.label`、`tool.description`、`widget.category.title`、
///          `result.label`、`FitModel.label`…）全部来自 `lib/domain/usecases/tool_catalog*.dart`
///          与 `lib/application/controllers/tool_search_*.dart`，那里的中文以**千条**计
///          （`lib/domain/usecases` 1982 条、`lib/application/controllers` 1393 条去重字面量），
///          是内容数据不是界面文案，本轮一条都没动。本表只翻包在它们外面的壳。
///       2. **工具页拿到的动态摘要也不进来。** `paste.summary`、`result.message`、
///          `_output.statusTitle` / `statusMessage`、`_detailController.inputErrorSummary()` /
///          `resultIssueSummary()` / `resultHealthSummary()` / `insights` 都是控制器与领域层产出的
///          中文句子，今天仍是中文——**这是已知的残留**，不是漏翻。
/// English: The string table for the tools home, category, tool detail and text tool detail screens,
///          **split by feature** — one table holding every language side by side. (The fit screen has
///          its own; see `data_fit_strings.dart`'s file head.) The mechanism itself (why hand-written
///          tables rather than ARB / `gen-l10n`, why the tables are `static final` rather than
///          `const`) shares one set of reasons with the settings table and is written on
///          `settings_strings.dart`'s file head; it is not copied again here.
///
///          **This table holds human-facing text only.** Two boundaries are worth writing down:
///          1. **The tool catalogue does not come in here.** Tool names, descriptions, formulas,
///             parameter labels, units and category names (`widget.tool.title`, `input.label`,
///             `tool.description`, `widget.category.title`, `result.label`, `FitModel.label`, …) all
///             come from `lib/domain/usecases/tool_catalog*.dart` and
///             `lib/application/controllers/tool_search_*.dart`, where the Chinese runs into the
///             **thousands** (1982 distinct literals under `lib/domain/usecases`, 1393 under
///             `lib/application/controllers`). That is content data rather than interface copy and not
///             one entry of it was touched this round. This table translates only the shell around it.
///          2. **Dynamic summaries the tool pages receive do not come in either.** `paste.summary`,
///             `result.message`, `_output.statusTitle` / `statusMessage`,
///             `_detailController.inputErrorSummary()` / `resultIssueSummary()` /
///             `resultHealthSummary()` / `insights` are Chinese sentences produced by the controllers
///             and the domain layer, and they are still Chinese today — a **known remainder**, not a
///             missed translation.
@immutable
class ToolsStrings {
  const ToolsStrings({
    // —— 通用字（多处共用）——
    required this.clear,
    required this.more,
    required this.back,
    required this.reset,
    required this.copy,
    required this.save,
    required this.note,
    required this.paste,
    required this.formula,
    required this.insights,
    required this.resultCopied,
    // —— 工具首页：页头与搜索 ——
    required this.toolsPageTitle,
    required this.toolsSearchHint,
    required this.searchResultsCount,
    required this.allCategories,
    required this.allLabel,
    required this.noMatchAtAll,
    // —— 工具首页：三个分组 ——
    required this.suggestedTools,
    required this.recentTools,
    required this.manage,
    required this.add,
    required this.favoriteTools,
    required this.favoriteEmpty,
    required this.categories,
    required this.clearAll,
    required this.recentEmpty,
    required this.removeRecentTooltip,
    // —— 分类页 ——
    required this.searchCategoryHint,
    required this.categoryNoMatch,
    required this.commonTools,
    required this.match,
    required this.matchWithText,
    // —— 工具卡片与列表项 ——
    required this.toolCount,
    required this.favoriteAdd,
    required this.favoriteRemove,
    required this.otherCategories,
    required this.copyThisItem,
    // —— 工具详情页：菜单与外壳 ——
    required this.pasteInputs,
    required this.copyInputs,
    required this.copyResult,
    required this.saveHistory,
    required this.saveNote,
    required this.resetInputs,
    // —— 工具详情页：参数卡片 ——
    required this.inputParameters,
    required this.noNumericInputs,
    required this.optionalInput,
    required this.decrease,
    required this.increase,
    required this.clearInput,
    required this.restoreDefault,
    // —— 工具详情页：结果与状态 ——
    required this.primaryResult,
    required this.copyPrimaryResult,
    required this.statusInputInvalid,
    required this.statusResultCheck,
    required this.statusResultReusable,
    required this.fixInputsFirst,
    required this.fixInputsFirstWith,
    required this.inputsCopied,
    required this.copiedLabel,
    // —— 文本工具详情页 ——
    required this.formulaAndVariables,
    required this.inputLabel,
    required this.formulaHint,
    required this.primaryResultCopied,
    required this.detailResult,
    required this.copyDetailResult,
    required this.detailResultCopied,
    required this.useAsInput,
    required this.fixInput,
    required this.urlCodecSample,
    required this.textStatsSample,
    // —— 文本工具的逐项输入提示 ——
    required this.hintBaseConvert,
    required this.hintTimestamp,
    required this.hintColorConvert,
    required this.hintBase64,
    required this.hintUrlCodec,
    required this.hintJsonFormat,
    required this.hintAsciiUnicode,
    required this.hintBitwise,
    required this.hintChecksum,
    required this.hintUuid,
    required this.hintJwtDecode,
    required this.hintQueryParams,
    required this.hintHtmlEntities,
    required this.hintRegexTest,
    required this.hintTextStats,
    required this.hintCsvJson,
    required this.hintFnvCrc,
    required this.hintDefault,
  });

  // —— 通用字（多处共用）——
  final String clear;
  final String more;
  final String back;
  final String reset;
  final String copy;
  final String save;
  final String note;
  final String paste;
  final String formula;
  final String insights;
  final String resultCopied;
  // —— 工具首页：页头与搜索 ——
  final String toolsPageTitle;
  final String toolsSearchHint;
  final String Function(int count) searchResultsCount;
  final String allCategories;
  final String allLabel;
  final String Function(String query) noMatchAtAll;
  // —— 工具首页：三个分组 ——
  final String suggestedTools;
  final String recentTools;
  final String manage;
  final String add;
  final String favoriteTools;
  final String favoriteEmpty;
  final String categories;
  final String clearAll;
  final String recentEmpty;
  final String removeRecentTooltip;
  // —— 分类页 ——
  final String Function(String category) searchCategoryHint;
  final String Function(String category, String query) categoryNoMatch;
  final String commonTools;
  final String Function(String label) match;
  final String Function(String label, String text) matchWithText;
  // —— 工具卡片与列表项 ——
  final String Function(int count) toolCount;
  final String favoriteAdd;
  final String favoriteRemove;
  final String otherCategories;
  final String copyThisItem;
  // —— 工具详情页：菜单与外壳 ——
  final String pasteInputs;
  final String copyInputs;
  final String copyResult;
  final String saveHistory;
  final String saveNote;
  final String resetInputs;
  // —— 工具详情页：参数卡片 ——
  final String inputParameters;
  final String noNumericInputs;
  final String Function(String label) optionalInput;
  final String decrease;
  final String increase;
  final String clearInput;
  final String restoreDefault;
  // —— 工具详情页：结果与状态 ——
  final String primaryResult;
  final String copyPrimaryResult;
  final String statusInputInvalid;
  final String statusResultCheck;
  final String statusResultReusable;
  final String fixInputsFirst;
  final String Function(String summary) fixInputsFirstWith;
  final String inputsCopied;
  final String Function(String label) copiedLabel;
  // —— 文本工具详情页 ——
  final String formulaAndVariables;
  final String inputLabel;
  final String formulaHint;
  final String primaryResultCopied;
  final String detailResult;
  final String copyDetailResult;
  final String detailResultCopied;
  final String useAsInput;
  final String Function(String message) fixInput;
  final String urlCodecSample;
  final String textStatsSample;
  // —— 文本工具的逐项输入提示 ——
  final String hintBaseConvert;
  final String hintTimestamp;
  final String hintColorConvert;
  final String hintBase64;
  final String hintUrlCodec;
  final String hintJsonFormat;
  final String hintAsciiUnicode;
  final String hintBitwise;
  final String hintChecksum;
  final String hintUuid;
  final String hintJwtDecode;
  final String hintQueryParams;
  final String hintHtmlEntities;
  final String hintRegexTest;
  final String hintTextStats;
  final String hintCsvJson;
  final String hintFnvCrc;
  final String hintDefault;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过，
  ///       而不是静默回落到中文。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here rather than silently falling back to Chinese.
  static ToolsStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。两条路径共用这一个
  ///       switch，不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext`. Both routes share this
  ///          one switch, so they cannot drift apart.
  static ToolsStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => toolsZh,
      AppLanguage.en => toolsEn,
    };
  }

  static final ToolsStrings toolsZh = ToolsStrings(
    clear: '清除',
    more: '更多',
    back: '返回',
    reset: '重置',
    copy: '复制',
    save: '保存',
    note: '笔记',
    paste: '粘贴',
    formula: '公式',
    insights: '校核',
    resultCopied: '已复制结果',
    toolsPageTitle: '工具',
    toolsSearchHint: '搜索工具、公式、单位...',
    searchResultsCount: (count) => '搜索结果 · $count',
    allCategories: '全部分类',
    allLabel: '全部',
    noMatchAtAll: (query) => '没有找到“$query”的匹配工具。',
    suggestedTools: '推荐工具',
    recentTools: '最近使用',
    manage: '管理',
    add: '添加',
    favoriteTools: '收藏工具',
    favoriteEmpty: '还没有收藏工具，点击工具右侧星标即可固定到这里。',
    categories: '分类',
    clearAll: '清空',
    recentEmpty: '最近使用已清空。打开任意工具后会重新记录到这里。',
    removeRecentTooltip: '移除最近使用',
    searchCategoryHint: (category) => '搜索$category工具',
    categoryNoMatch: (category, query) => '$category里没有“$query”。',
    commonTools: '常用工具',
    match: (label) => '命中：$label',
    matchWithText: (label, text) => '命中：$label · $text',
    toolCount: (count) => '$count 个工具',
    favoriteAdd: '收藏',
    favoriteRemove: '取消收藏',
    otherCategories: '其它分类',
    copyThisItem: '复制此项',
    pasteInputs: '粘贴参数',
    copyInputs: '复制参数',
    copyResult: '复制结果',
    saveHistory: '保存历史',
    saveNote: '保存笔记',
    resetInputs: '重置输入',
    inputParameters: '输入参数',
    noNumericInputs: '该工具无需数字参数，请使用上方结果和操作按钮完成复制、保存或笔记记录。',
    optionalInput: (label) => '$label（可选）',
    decrease: '减小',
    increase: '增大',
    clearInput: '清空',
    restoreDefault: '恢复默认',
    primaryResult: '主结果',
    copyPrimaryResult: '复制主结果',
    statusInputInvalid: '输入需要修正',
    statusResultCheck: '结果需要检查',
    statusResultReusable: '结果可复用',
    fixInputsFirst: '请先修正输入参数',
    fixInputsFirstWith: (summary) => '请先修正输入参数：$summary',
    inputsCopied: '已复制输入参数',
    copiedLabel: (label) => '已复制$label',
    formulaAndVariables: '公式与变量',
    inputLabel: '输入',
    formulaHint: '例如 a * b + sqrt(c)',
    primaryResultCopied: '已复制主结果',
    detailResult: '详细结果',
    copyDetailResult: '复制详细结果',
    detailResultCopied: '已复制详细结果',
    useAsInput: '回填',
    fixInput: (message) => '请先修正输入：$message',
    urlCodecSample: 'NekoCalc 工具箱',
    textStatsSample: 'NekoCalc\n全能计算工具箱',
    hintBaseConvert: '输入 255、0xFF、#FF、FFh、1010b 或 0o755',
    hintTimestamp: '输入秒/毫秒时间戳、1700000000.123s 或 2026年6月8日',
    hintColorConvert: '输入 #5B47FF、rgb(...)、hsl(...) 或 rebeccapurple',
    hintBase64: '输入文本、Base64、Base64URL 或 data URL',
    hintUrlCodec: '输入 URL、query string、普通文本或百分号编码文本',
    hintJsonFormat: '输入 JSON、JSON Lines 或带 BOM 的 JSON 文本',
    hintAsciiUnicode: r'输入字符、U+4E2D、\u4E2D 或 128072',
    hintBitwise: '输入两个整数，例如 12 5、0xFF 0b1010、A=0xF0 B=0b1010',
    hintChecksum: r'输入文本或 DE AD BE EF / \xDE 十六进制字节',
    hintUuid: '留空生成 UUID，或粘贴 UUID 校验/标准化',
    hintJwtDecode: '输入完整 JWT token，离线解码 Header/Payload',
    hintQueryParams: '输入 URL、请求行、片段 query 或 a=1&b=2;b=3',
    hintHtmlEntities: '输入 HTML、命名实体或 &#x4E2D; 数字实体',
    hintRegexTest: '第一行正则，后续行测试文本',
    hintTextStats: '输入要统计的文本，输出字符分类和段落信息',
    hintCsvJson: '首行为表头，支持逗号、Tab、分号、竖线分隔',
    hintFnvCrc: r'输入文本或 31 32 33 十六进制字节',
    hintDefault: '输入内容',
  );

  static final ToolsStrings toolsEn = ToolsStrings(
    clear: 'Clear',
    more: 'More',
    back: 'Back',
    reset: 'Reset',
    copy: 'Copy',
    save: 'Save',
    note: 'Note',
    paste: 'Paste',
    formula: 'Formula',
    insights: 'Checks',
    resultCopied: 'Result copied',
    toolsPageTitle: 'Tools',
    toolsSearchHint: 'Search tools, formulas, units…',
    searchResultsCount: (count) => 'Search results · $count',
    allCategories: 'All categories',
    allLabel: 'All',
    noMatchAtAll: (query) => 'No tool matches “$query”.',
    suggestedTools: 'Suggested tools',
    recentTools: 'Recently used',
    manage: 'Manage',
    add: 'Add',
    favoriteTools: 'Favourite tools',
    favoriteEmpty:
        'No favourite tools yet. Tap the star on the right of a tool to pin it here.',
    categories: 'Categories',
    clearAll: 'Clear',
    recentEmpty:
        'Recently used is empty. Open any tool and it will be listed here again.',
    removeRecentTooltip: 'Remove from recently used',
    searchCategoryHint: (category) => 'Search $category tools',
    categoryNoMatch: (category, query) => 'Nothing in $category matches “$query”.',
    commonTools: 'Common tools',
    match: (label) => 'Matched: $label',
    matchWithText: (label, text) => 'Matched: $label · $text',
    toolCount: (count) => '$count tools',
    favoriteAdd: 'Add to favourites',
    favoriteRemove: 'Remove from favourites',
    otherCategories: 'Other categories',
    copyThisItem: 'Copy this value',
    pasteInputs: 'Paste parameters',
    copyInputs: 'Copy parameters',
    copyResult: 'Copy result',
    saveHistory: 'Save to history',
    saveNote: 'Save to a note',
    resetInputs: 'Reset input',
    inputParameters: 'Input parameters',
    noNumericInputs:
        'This tool takes no numeric parameters; use the result above and the action '
        'buttons to copy, save or note it.',
    optionalInput: (label) => '$label (optional)',
    decrease: 'Decrease',
    increase: 'Increase',
    clearInput: 'Clear',
    restoreDefault: 'Restore default',
    primaryResult: 'Primary result',
    copyPrimaryResult: 'Copy the primary result',
    statusInputInvalid: 'Input needs fixing',
    statusResultCheck: 'Result needs checking',
    statusResultReusable: 'Result can be reused',
    fixInputsFirst: 'Fix the input parameters first',
    fixInputsFirstWith: (summary) => 'Fix the input parameters first: $summary',
    inputsCopied: 'Input parameters copied',
    copiedLabel: (label) => '$label copied',
    formulaAndVariables: 'Formula and variables',
    inputLabel: 'Input',
    formulaHint: 'e.g. a * b + sqrt(c)',
    primaryResultCopied: 'Primary result copied',
    detailResult: 'Detailed result',
    copyDetailResult: 'Copy the detailed result',
    detailResultCopied: 'Detailed result copied',
    useAsInput: 'Use as input',
    fixInput: (message) => 'Fix the input first: $message',
    urlCodecSample: 'NekoCalc toolbox',
    textStatsSample: 'NekoCalc\nAll-in-one calculator toolbox',
    hintBaseConvert: 'Enter 255, 0xFF, #FF, FFh, 1010b or 0o755',
    hintTimestamp:
        'Enter a seconds or milliseconds timestamp, 1700000000.123s or 2026-06-08',
    hintColorConvert: 'Enter #5B47FF, rgb(...), hsl(...) or rebeccapurple',
    hintBase64: 'Enter text, Base64, Base64URL or a data URL',
    hintUrlCodec:
        'Enter a URL, a query string, plain text or percent-encoded text',
    hintJsonFormat: 'Enter JSON, JSON Lines or JSON text with a BOM',
    hintAsciiUnicode: r'Enter a character, U+4E2D, \u4E2D or 128072',
    hintBitwise: 'Enter two integers, e.g. 12 5, 0xFF 0b1010, A=0xF0 B=0b1010',
    hintChecksum: r'Enter text or DE AD BE EF / \xDE hex bytes',
    hintUuid: 'Leave empty to generate a UUID, or paste one to validate or normalise',
    hintJwtDecode: 'Enter a whole JWT token to decode Header/Payload offline',
    hintQueryParams:
        'Enter a URL, a request line, a fragment query or a=1&b=2;b=3',
    hintHtmlEntities:
        'Enter HTML, a named entity, or a numeric entity such as &#x4E2D;',
    hintRegexTest: 'The first line is the pattern; the lines after it are the test text',
    hintTextStats:
        'Enter the text to measure; character classes and paragraph info come out',
    hintCsvJson:
        'The first row is the header; comma, Tab, semicolon and pipe separators work',
    hintFnvCrc: 'Enter text or 31 32 33 hex bytes',
    hintDefault: 'Enter content',
  );
}
