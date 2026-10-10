import 'package:flutter/widgets.dart';

// 中文：**这张表要认得引擎发出来的令牌**——键写常量名而不是字面量，引擎那边加了令牌、这里忘了配字
//       就会在下面两张表里当场编译不过，而不是等到屏幕上露出 `命中：new_token`。
// English: **This table has to know the engine's tokens** — the keys are the constants rather than
//          literals, so a token added in the engine and left out here fails to compile in the two tables
//          below rather than surfacing as `Matched: new_token` on screen.
import '../../../application/controllers/tool_search_engine.dart';
import '../../../l10n/app_language.dart';

/// 中文：工具首页 / 分类页 / 工具详情页 / 文本工具详情页的界面文案表，**按功能切分**——一张表、
///       表里并排放所有语言。（拟合页单独一张，见 `data_fit_strings.dart` 的文件头。）
///       机制本身（为什么是手写分表而不是 ARB / `gen-l10n`、为什么表是 `static final` 而不是
///       `const`）与设置页那张表共用一套理由，写在 `settings_strings.dart` 的文件头上，这里不重抄。
///
///       **本表只装"给人看的字"。** 两条口径值得写下来：
///       1. **工具的目录数据不进来。** 描述、公式、参数标签、单位
///          （`input.label`、`tool.description`、`result.label`…）全部来自
///          `lib/domain/usecases/tool_catalog*.dart` 与
///          `lib/application/controllers/tool_search_*.dart`，那里的中文以**千条**计
///          （`lib/domain/usecases` 1982 条、`lib/application/controllers` 1393 条去重字面量），
///          是内容数据不是界面文案。本表只翻包在它们外面的壳。
///
///          ⚠️ **这一条原先还把「工具名」与「分类名」列在里面，那句话从 `bbd2d25` 起不再成立**：
///          117 个工具名与 8 个分类名（含 8 条分类说明）现在有**自己的表**——
///          `tool_catalog_strings.dart`，那边的文件头正面写着这条新分界。
///          留这段话是因为**一句话被推翻时该在这里说一声**，免得下一轮的读者照着旧边界去找。
///          （分类说明进表是因为**检索打分**要读它，屏幕上没有读者。）
///       2. **工具页拿到的动态摘要也不进来。** `paste.summary`、
///          `_output.statusTitle` / `statusMessage`、`_detailController.inputErrorSummary()` /
///          `resultIssueSummary()` / `resultHealthSummary()` / `insights` 都是控制器与领域层产出的
///          中文句子，今天仍是中文——**这是已知的残留**，不是漏翻。
///          ⚠️ 这一条原先还把 `result.message` 列在里面。**保存回执（`ToolSaveResult`）本轮已经
///          进表**——它不再是动态摘要，而是领域层给令牌（`ToolSaveStatus` × `ToolSaveTarget`）、
///          本表给字、由 `tool_save_message.dart` 在呈现边缘取，所以那一项从这份名单里删掉了。
///          留这句话是因为**名单短了一项时该说一声**，免得下一页的读者以为它从来不在名单上。
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
///             `tool.description`, `widget.category.title`, `result.label`, …) all
///             come from `lib/domain/usecases/tool_catalog*.dart` and
///             `lib/application/controllers/tool_search_*.dart`, where the Chinese runs into the
///             **thousands** (1982 distinct literals under `lib/domain/usecases`, 1393 under
///             `lib/application/controllers`). That is content data rather than interface copy and not
///             one entry of it was touched this round. This table translates only the shell around it.
///          2. **Dynamic summaries the tool pages receive do not come in either.** `paste.summary`,
///             `_output.statusTitle` / `statusMessage`,
///             `_detailController.inputErrorSummary()` / `resultIssueSummary()` /
///             `resultHealthSummary()` / `insights` are Chinese sentences produced by the controllers
///             and the domain layer, and they are still Chinese today — a **known remainder**, not a
///             missed translation.
///             ⚠️ This item used to list `result.message` too. **The save receipt (`ToolSaveResult`) went
///             into the table this round** — it is no longer a dynamic summary: the domain hands over
///             the tokens (`ToolSaveStatus` × `ToolSaveTarget`), this table holds the words, and
///             `tool_save_message.dart` reads them at the presentation edge, so that item was struck
///             from this list. The note is kept because **a list that loses an item should say so**, so
///             the next reader does not think it was never on it.
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
    required this.searchToolTooltip,
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
    // —— 工具首页：最近使用回执（见下面那一段说明）——
    required this.recentToolRemoved,
    required this.recentToolNotFound,
    required this.recentToolsCleared,
    required this.recentToolsAlreadyEmpty,
    required this.recentToolRemoveFailed,
    required this.recentToolClearFailed,
    // —— 分类页 ——
    required this.searchCategoryHint,
    required this.categoryNoMatch,
    required this.commonTools,
    required this.matchLabels,
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
    // —— 工具详情页：保存回执 ——
    required this.saveHistorySaved,
    required this.saveNoteSaved,
    required this.saveNothingToStore,
    required this.saveHistoryNotWritten,
    required this.saveNoteNotWritten,
    required this.saveHistoryFailed,
    required this.saveNoteFailed,
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

  // —— 工具首页：最近使用回执 ——
  /// 中文：**最近使用那两条动作（移除 / 清空）的五句话。** 它们原先住在领域层
  ///       （`lib/domain/usecases/recent_tool_action_result.dart` 上 `message` 字段当场拼出来的句子），
  ///       由工具首页那两个 `SnackBar` 直接印（`result.message`）。**领域对象活得比界面长**，这张表
  ///       够不着它，所以那几句话在任何界面语言下都是中文——`docs/verification.md` §5i 记着的层次性
  ///       缺陷（提交、保存、笔记三条路径先一步改成了这个形状）。
  ///
  ///       现在领域层只留令牌 `RecentToolActionStatus`（`failed` 那一格另外看 `RecentToolAction`
  ///       决定印「移除」还是「清空」），字在这里，由 `recent_tool_action_message.dart` 的
  ///       `recentToolActionMessage(result, strings)` 在**呈现边缘**取。工具名、条数与错误串是载荷，
  ///       由调用方（领域结果）递进来。
  ///
  ///       **中文逐字节与从前相同**（默认语言是中文），由 `test/domain/recent_tool_action_result_test.dart`
  ///       那份旧文案对照表逐条钉住。两格是函数（错误串是异常的技术串）。
  /// English: **the five sentences of the two recently-used actions (remove / clear).** They used to
  ///          live in the domain layer (composed on the spot into `message` in
  ///          `lib/domain/usecases/recent_tool_action_result.dart`) and were printed straight by the two
  ///          `SnackBar`s on the tools home page (`result.message`). **A domain object outlives the
  ///          UI**, so this table could not reach it and those sentences were Chinese under every
  ///          interface language — the layering defect recorded in `docs/verification.md` §5i, whose
  ///          earlier slices were the submit, save and notes paths.
  ///
  ///          The domain now keeps only the token `RecentToolActionStatus` (the `failed` cell also
  ///          reads `RecentToolAction` to pick the remove or clear wording); the words are here, read
  ///          **at the presentation edge** by `recentToolActionMessage(result, strings)` in
  ///          `recent_tool_action_message.dart`. The tool name, the count and the error string are
  ///          payload handed in by the caller (the domain result).
  ///
  ///          **The Chinese is byte-identical to what it was** (Chinese is the default language),
  ///          pinned entry by entry by the legacy-sentence table in
  ///          `test/domain/recent_tool_action_result_test.dart`. Two cells are functions (the error
  ///          string is an exception's technical string).
  final String Function(String title) recentToolRemoved;
  final String recentToolNotFound;
  final String Function(int count) recentToolsCleared;
  final String recentToolsAlreadyEmpty;
  final String Function(String error) recentToolRemoveFailed;
  final String Function(String error) recentToolClearFailed;

  // —— 分类页 ——
  /// 中文：**搜索按钮的名字。** `IconButton` 的语义标签来自 `tooltip`——
  ///       没有它，那一颗在读屏里就是**一个没有名字的按钮**（实测：它让
  ///       `labeledTapTargetGuideline` 在工具页上不通过）。
  ///       同页其余几颗按钮都有 `tooltip`，**只有它漏了**。
  /// English: **the search button's name.** An `IconButton`'s semantic label comes from its `tooltip` —
  ///          without one that button is **an unnamed button** to a screen reader (measured: it is what
  ///          makes `labeledTapTargetGuideline` fail on the tools page). Every other button on that page has
  ///          a `tooltip`; **this one was missed.**
  final String searchToolTooltip;

  final String Function(String category) searchCategoryHint;
  final String Function(String category, String query) categoryNoMatch;
  final String commonTools;

  /// 中文：**命中令牌 → 界面标签**（`ToolMatchTokens` → 这里的字），只给 [match] / [matchWithText]
  ///       用。它是一张**表**而不是十来个字段，因为这里要的正是"查得到就翻、查不到就透传"这个
  ///       动作；十条各占一个字段的话，透传那一路就没有落点了。
  /// English: **Match token → on-screen label** (`ToolMatchTokens` → the words here), read only by
  ///          [match] / [matchWithText]. It is a **table** rather than a dozen fields because the action
  ///          wanted here is exactly "translate what is in the table, pass through what is not"; with
  ///          ten separate fields the pass-through branch would have nowhere to land.
  final Map<String, String> matchLabels;

  /// 中文：**令牌进，整句出。** 参数就是 `ToolSearchResult.matchLabel` 的原文：在 [matchLabels]
  ///       里查得到就翻成界面上的字，**查不到就逐字照用**。
  ///
  ///       **透传那一路是故意留的第三条路，不是兜底。** `tool.group` 与分类名是**内容**，在自己的层
  ///       （`tool_catalog*.dart` / `ToolCatalogStrings`）已经翻好；这里再动它们一次就是错的，而且
  ///       分类名必须与分类页那行分组标题**字字相同**。所以判据不是"认不出就猜一个英文"，而是
  ///       "不在表里就是内容"——令牌全在 [`ToolMatchTokens`] 里，与内容的名字不可能撞上
  ///       （`tools_match_labels_test.dart` 拿整个目录逐条比过）。
  ///
  ///       引擎没有 `BuildContext`，所以令牌由引擎产出、字在这里落下：两个调用方（工具首页与分类页）
  ///       本来就把 `matchLabel` 交给这两个函数，**调用点一个都没改**。
  /// English: **A token goes in, a whole sentence comes out.** The argument is
  ///          `ToolSearchResult.matchLabel` exactly as it stands: an entry in [matchLabels] becomes the
  ///          words on screen, and **anything not in the table is used character for character**.
  ///
  ///          **That pass-through is a deliberate third branch, not a fallback.** `tool.group` and the
  ///          category names are **content**, already translated at their own layer
  ///          (`tool_catalog*.dart` / `ToolCatalogStrings`); translating them again here would be wrong,
  ///          and the category name has to read **character for character** like the group heading on
  ///          the category screen. So the rule is not "if unrecognised, guess an English word" but "not
  ///          in the table means it is content" — every token lives in [`ToolMatchTokens`] and cannot
  ///          collide with a content name (`tools_match_labels_test.dart` checks that against the whole
  ///          catalogue, entry by entry).
  ///
  ///          The engine has no `BuildContext`, so the engine produces a token and the words land here:
  ///          both callers (tools home and the category screen) already handed `matchLabel` to these two
  ///          functions, so **not one call site changed**.
  final String Function(String token) match;

  /// 中文：与 [match] 同一件事，多带上**命中到的原文**（`ToolSearchResult.matchText`）。令牌那一步
  ///       与 [match] 共用同一张表，两条路不会分叉。
  /// English: The same as [match] with the **matched text** (`ToolSearchResult.matchText`) appended. The
  ///          token step shares [match]'s table, so the two routes cannot drift apart.
  final String Function(String token, String text) matchWithText;
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

  // —— 工具详情页：保存回执 ——
  /// 中文：**保存历史 / 保存笔记那两条路的七句话。** 它们原先住在领域层
  ///       （`lib/domain/usecases/tool_save_result.dart` 上 `message` 字段当场拼出来的句子），
  ///       由工具详情页、文本工具详情页、拟合页三处 `SnackBar` 直接印。**领域对象活得比界面长**，
  ///       这张表够不着它，所以那几句话在任何界面语言下都是中文——`docs/verification.md` §5i 记着
  ///       这条层次性缺陷（提交路径与保存笔记路径先一步改成了这个形状）。
  ///
  ///       现在领域层只留两个令牌（`ToolSaveStatus` × `ToolSaveTarget`），字在这里，由
  ///       `tool_save_message.dart` 的 `toolSaveMessage(result, strings)` 在呈现边缘取。
  ///       **`inputInvalid` 那一种不在这里新开格**：它的两句就是上面那对
  ///       [fixInputsFirst] / [fixInputsFirstWith]（屏幕上本来就是同一句话），呈现层按
  ///       `summary` 去掉空白后是否为空选一格。**中文逐字节与从前相同**（默认语言是中文），由
  ///       `test/domain/tool_save_result_test.dart` 那份旧文案对照表与 `tools_strings_test.dart`
  ///       逐条钉住。
  ///
  ///       两格是函数（`$error` 那个载荷由调用方递进来，是异常的技术串）。
  /// English: **the seven sentences of the save-to-history / save-to-note roads.** They used to live in
  ///          the domain layer (`message`, composed on the spot in
  ///          `lib/domain/usecases/tool_save_result.dart`) and were printed straight by three
  ///          `SnackBar`s — the tool detail screen, the text tool detail screen and the fit screen.
  ///          **A domain object outlives the UI**, so this table could not reach it and those sentences
  ///          were Chinese under every interface language — the layering defect recorded in
  ///          `docs/verification.md` §5i, whose earlier slices were the submit path and the
  ///          save-to-note path.
  ///
  ///          The domain now keeps only the two tokens (`ToolSaveStatus` × `ToolSaveTarget`); the words
  ///          are here, read at the presentation edge by `toolSaveMessage(result, strings)` in
  ///          `tool_save_message.dart`. **`inputInvalid` gets no new cell here**: its two sentences are
  ///          the [fixInputsFirst] / [fixInputsFirstWith] pair above (the same words were already on
  ///          screen), and the presentation layer picks one by whether `summary` is empty after
  ///          trimming. **The Chinese is byte-identical to what it was** (Chinese is the default
  ///          language), pinned by the legacy-sentence table in `test/domain/tool_save_result_test.dart`
  ///          and cell by cell in `tools_strings_test.dart`.
  ///
  ///          Two cells are functions (the `$error` payload comes from the caller and is an exception's
  ///          technical string).
  final String saveHistorySaved;
  final String saveNoteSaved;
  final String saveNothingToStore;
  final String saveHistoryNotWritten;
  final String saveNoteNotWritten;
  final String Function(String error) saveHistoryFailed;
  final String Function(String error) saveNoteFailed;

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

  /// 中文：两张令牌表——`ToolMatchTokens` 的每个常量都得在这里有一条，键写常量名而不是字面量，
  ///       所以引擎那边加一个令牌、这边忘了配字，`tools_match_labels_test.dart` 会红（不是屏幕上
  ///       静默露出 `命中：new_token`）。十条**逐条写出来**，与上面那些字段同一个理由：一行中文
  ///       一行英文并排看得见，是这套机制的本来面目。
  ///
  ///       标签的用词与它们各自那一条**同源**：`公式` 对 `ToolsStrings.formula`（`Formula`）、
  ///       `输入项` 对 `ToolsStrings.inputLabel`（`Input`）——同一个东西在两张表里叫两个名字，
  ///       下一个读者会以为是两个东西。
  /// English: The two token tables. Every constant of `ToolMatchTokens` needs an entry here, keyed by
  ///          the constant rather than by a literal, so adding a token in the engine and forgetting its
  ///          words here goes red in `tools_match_labels_test.dart` instead of quietly printing
  ///          `Matched: new_token` on screen. The ten are **written out one by one** for the same reason
  ///          as the fields above: one line of Chinese beside one line of English is what this mechanism
  ///          looks like.
  ///
  ///          The wording is **taken from the field each label belongs to**: `公式` matches
  ///          `ToolsStrings.formula` (`Formula`) and `输入项` matches `ToolsStrings.inputLabel`
  ///          (`Input`) — one thing going by two names across two tables reads as two things.
  static const Map<String, String> _matchLabelsZh = {
    ToolMatchTokens.title: '标题',
    ToolMatchTokens.toolId: '工具 ID',
    ToolMatchTokens.description: '说明',
    ToolMatchTokens.formula: '公式',
    ToolMatchTokens.explanation: '解释',
    ToolMatchTokens.alias: '别名',
    ToolMatchTokens.input: '输入项',
    ToolMatchTokens.unit: '单位',
    ToolMatchTokens.parameter: '参数',
    ToolMatchTokens.keyword: '关键词',
  };

  static const Map<String, String> _matchLabelsEn = {
    ToolMatchTokens.title: 'Title',
    ToolMatchTokens.toolId: 'Tool ID',
    ToolMatchTokens.description: 'Description',
    ToolMatchTokens.formula: 'Formula',
    ToolMatchTokens.explanation: 'Explanation',
    ToolMatchTokens.alias: 'Alias',
    ToolMatchTokens.input: 'Input',
    ToolMatchTokens.unit: 'Unit',
    ToolMatchTokens.parameter: 'Parameter',
    ToolMatchTokens.keyword: 'Keyword',
  };

  /// 中文：查表那一步，**两个语言各一份、只有一行**：`?? token` 就是透传（理由写在 [match] 上）。
  /// English: The lookup step — one line each, one per language: `?? token` *is* the pass-through (the
  ///          reason is on [match]).
  static String _matchLabelZh(String token) => _matchLabelsZh[token] ?? token;
  static String _matchLabelEn(String token) => _matchLabelsEn[token] ?? token;

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
    searchToolTooltip: '搜索工具',
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
    // 中文：与迁移前领域层那五句话逐字节相同（`failed` 那两格按 `RecentToolAction` 分走）。
    // English: byte-identical to the five sentences in the domain layer before the move (the two
    //          `failed` cells split by `RecentToolAction`).
    recentToolRemoved: (title) => '已从最近使用移除「$title」',
    recentToolNotFound: '这项最近使用已经不存在',
    recentToolsCleared: (count) => '已清空 $count 个最近工具',
    recentToolsAlreadyEmpty: '最近使用已经是空的',
    recentToolRemoveFailed: (error) => '移除最近使用失败：$error',
    recentToolClearFailed: (error) => '清空最近使用失败：$error',
    searchCategoryHint: (category) => '搜索$category工具',
    categoryNoMatch: (category, query) => '$category里没有“$query”。',
    commonTools: '常用工具',
    matchLabels: _matchLabelsZh,
    match: (token) => '命中：${_matchLabelZh(token)}',
    matchWithText: (token, text) => '命中：${_matchLabelZh(token)} · $text',
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
    // 中文：与迁移前领域层那七句话逐字节相同（`inputInvalid` 那一对用的是上面 `fixInputsFirst`
    //       / `fixInputsFirstWith`，屏幕上的字本来就和它们一样）。
    // English: byte-identical to the seven sentences in the domain layer before the move (the
    //          `inputInvalid` pair is the `fixInputsFirst` / `fixInputsFirstWith` pair above, whose
    //          words were already what the screen showed).
    saveHistorySaved: '结果已保存到历史记录',
    saveNoteSaved: '已保存到笔记',
    saveNothingToStore: '没有可保存的计算结果',
    saveHistoryNotWritten: '历史记录没有写入，请重试',
    saveNoteNotWritten: '笔记没有写入，请重试',
    saveHistoryFailed: (error) => '保存历史失败：$error',
    saveNoteFailed: (error) => '保存笔记失败：$error',
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
    searchToolTooltip: 'Search tools',
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
    // 中文：与中文那一份逐条对应，语声与相邻几格一致（短回执、句末不带句号；「移除 / 清空最近使用」
    //       与上面 `removeRecentTooltip`、`recentTools` 同一个说法；引号用 ASCII，宽/全角标点会让
    //       最近使用那条护栏的英文渲染检查变红）。
    // English: one for one with the Chinese side, in the voice of the neighbouring cells (short
    //          receipts without a final period; "remove / clear recently used" as in
    //          `removeRecentTooltip` and `recentTools` above; the quotes stay ASCII because a
    //          wide/fullwidth punctuation mark would turn the recently-used guard's en-rendering check
    //          red).
    recentToolRemoved: (title) => 'Removed "$title" from recently used',
    recentToolNotFound: 'That recently used entry is already gone',
    recentToolsCleared: (count) => 'Cleared $count recently used tools',
    recentToolsAlreadyEmpty: 'Recently used is already empty',
    recentToolRemoveFailed: (error) =>
        'Could not remove from recently used: $error',
    recentToolClearFailed: (error) => 'Could not clear recently used: $error',
    searchCategoryHint: (category) => 'Search $category tools',
    categoryNoMatch: (category, query) => 'Nothing in $category matches “$query”.',
    commonTools: 'Common tools',
    matchLabels: _matchLabelsEn,
    match: (token) => 'Matched: ${_matchLabelEn(token)}',
    matchWithText: (token, text) => 'Matched: ${_matchLabelEn(token)} · $text',
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
    // 中文：与中文那一份逐条对应，语声与相邻几格一致（短回执、句末不带句号；「保存到…」与菜单
    //       那两格 `saveHistory` / `saveNote` 同一个说法）。
    // English: one for one with the Chinese side, in the voice of the neighbouring cells (short
    //          receipts without a final period; "save to…" is worded as in the menu's `saveHistory` /
    //          `saveNote` cells).
    saveHistorySaved: 'Result saved to history',
    saveNoteSaved: 'Saved to a note',
    saveNothingToStore: 'Nothing to save',
    saveHistoryNotWritten: 'The history entry was not written; try again',
    saveNoteNotWritten: 'The note was not written; try again',
    saveHistoryFailed: (error) => 'Saving to history failed: $error',
    saveNoteFailed: (error) => 'Saving to a note failed: $error',
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
