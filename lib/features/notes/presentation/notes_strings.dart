import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：笔记页的界面文案表，**按功能切分**——一张表、表里并排放所有语言。机制本身（为什么是手写
///       分表而不是 ARB / `gen-l10n`、为什么表是 `static final` 而不是 `const`）与设置页那张表
///       共用一套理由，写在 `settings_strings.dart` 的文件头上，这里不重抄。
///
///       **加一种语言要动几个文件**：这个文件（加一份 `NotesStrings` 表 + `of` 里加一个分支，
///       `forLanguage` 的 switch 必须穷尽 `AppLanguage`，由分析器检查）+ `AppLanguage` 里加一个
///       枚举值。
///
///       **本表只装"给人看的字"。** 有两类中文字面量**故意不进来**：
///       1. **内容探针**（`notes_page_sections.dart` 里按笔记标题/正文挑图标用的 `contains('公式')`
///          / `contains('公式：')` / `contains('工具')`）。它们不是屏幕上印的字，而是**拿用户的
///          笔记内容去比**——用户自己写的「公式」两个字。跟着界面语言翻掉，中文界面下那些图标
///          立刻全变回默认，而且不会有任何报错。它们是数据分类，不是文案。
///       2. **应用层自己产出的字**：`NotesController` 的 `error`（异常的技术串）、
///          `searchSuggestions()` / `searchExamples()`（搜索示例是**拿去搜的词**，与内容探针同一类），
///          以及导出 / 复制正文那一套标签（`'表达式:'`、`'结果:'`…——它们是**剪贴板往返的格式**，
///          由 `notes_clipboard_import.dart` 的解析器读回）。这些今天仍是中文——**这是已知的残留**，
///          不是漏翻。（`summary.label` 从前也在这个名单里，第五刀之后它搬到了
///          `notes_summary_message.dart`，名单已按实测改正。）
///
///       **已经搬进来的**：导入与删除的回执。`NotesClipboardImportPlan` / `…Result` /
///       `NotesDeleteResult` 从前自己拼那几句中文并直接上屏（`SnackBar` 与导入对话框），现在领域层
///       只给令牌（`NotesImportPlanStatus` / `NotesImportReceiptStatus` / `NotesDeleteStatus`），
///       字在这儿，由 `notes_receipt_message.dart` 在**呈现边缘**取。
///
///       **保存时生成、写进库的那三句也搬进来了**（`untitledNote` / `historyNoteTitle` /
///       `historyNoteDescription`，见各自字段上的注释）：它们从前硬编码在 `NotesController` 里，
///       于是英文界面存进去的仍是中文标题。与上面两条不同，这三句是**用户数据**——冻结在保存那一刻
///       的语言里，之后不跟着界面变；这是 `docs/verification.md` §5l 记下的那个决策（三个选项里
///       选的是"在正确的创建语言里冻结"，不是把标题换成显示时令牌）。
/// English: The notes page's string table, **split by feature** — one table holding every language
///          side by side. The mechanism itself (why hand-written tables rather than ARB / `gen-l10n`,
///          why the tables are `static final` rather than `const`) shares one set of reasons with the
///          settings table and is written on `settings_strings.dart`'s file head; it is not copied
///          again here.
///
///          **Adding a language touches**: this file (one more `NotesStrings` table plus one more
///          branch in `of`, whose switch over `AppLanguage` the analyzer checks for exhaustiveness)
///          and `AppLanguage` (one more enum value).
///
///          **This table holds human-facing text only.** Two kinds of Chinese literal are
///          **deliberately absent**:
///          1. **Content probes** (the `contains('公式')` / `contains('公式：')` /
///             `contains('工具')` in `notes_page_sections.dart` that pick a note's icon). They are not
///             printed anywhere; they are compared against **the user's own note text** — the two
///             characters 「公式」 the user typed. Translating them with the interface would flip every
///             such icon back to the default in a Chinese interface, with no error anywhere. They are
///             data classification, not copy.
///          2. **Application-layer text the controller produces itself**: `NotesController`'s `error`
///             (an exception's technical string), `searchSuggestions()` / `searchExamples()` (a search
///             example is a **word you search with**, the same category as a content probe), and the
///             labels of the export / copy body (`'表达式:'`, `'结果:'` … — they are the **clipboard
///             round-trip format** read back by `notes_clipboard_import.dart`'s parser). Those are
///             still Chinese today — a **known remainder**, not a missed translation.
///             (`summary.label` used to stand in this list too; the fifth slice moved it to
///             `notes_summary_message.dart`, and the list has been corrected against measurement.)
///
///          **What has moved in**: the import and delete receipts. `NotesClipboardImportPlan` /
///          `…Result` / `NotesDeleteResult` used to compose those Chinese sentences themselves and
///          print them straight (`SnackBar`, the import dialog); the domain layer now hands over only
///          the tokens (`NotesImportPlanStatus` / `NotesImportReceiptStatus` / `NotesDeleteStatus`),
///          the words live here, and `notes_receipt_message.dart` reads them **at the presentation
///          edge**.
///
///          **The three sentences generated at save time and written into the database moved in as
///          well** (`untitledNote` / `historyNoteTitle` / `historyNoteDescription`, each documented on
///          its field): they used to be hard-coded in `NotesController`, so an English interface
///          stored Chinese titles. Unlike the two kinds above, these three are **user data** — frozen
///          in the language of the moment they were saved, never following the interface afterwards.
///          That is the decision recorded in `docs/verification.md` §5l (of the three shapes, the one
///          chosen is "freeze in the right creation language", not "turn the title into a
///          display-time token").
@immutable
class NotesStrings {
  const NotesStrings({
    // —— 页头、搜索与胶囊 ——
    required this.pageTitle,
    required this.searchHint,
    required this.clearSearchTooltip,
    required this.tabAll,
    required this.tabNotes,
    required this.tabHistory,
    required this.tabFormulas,
    required this.tabTools,
    required this.historySectionTitle,
    required this.notesSectionTitle,
    // —— 多选态 ——
    required this.cancelSelection,
    required this.selectedCount,
    required this.selectVisible,
    required this.copySelected,
    required this.deleteSelected,
    required this.deleteSelectedConfirm,
    required this.copiedItems,
    // —— 历史：单条动作与清空 ——
    required this.copyResult,
    required this.saveAsNote,
    required this.deleteHistoryEntry,
    required this.deleteHistoryTooltip,
    required this.historyResultCopied,
    required this.savedToNotes,
    required this.clearHistory,
    required this.clearHistoryConfirm,
    // —— 笔记：单条动作 ——
    required this.pinNote,
    required this.unpinNote,
    required this.pinned,
    required this.unpinned,
    required this.archiveNote,
    required this.unarchiveNote,
    required this.archived,
    required this.unarchived,
    required this.editNote,
    required this.copyNote,
    required this.noteCopied,
    required this.deleteNote,
    required this.deleteNoteConfirm,
    required this.moreTooltip,
    // —— 删除确认（共用）——
    required this.cancel,
    required this.delete,
    required this.clear,
    // —— 剪贴板导入 ——
    required this.clipboardImportTitle,
    required this.importButton,
    required this.hiddenCount,
    // —— 导入 / 删除回执（领域层只给令牌，字在这里）——
    required this.importClipboardEmpty,
    required this.importNothingRecognised,
    required this.importWillImport,
    required this.imported,
    required this.importNothingNew,
    required this.importSkippedUnrecognised,
    required this.importPlanSkipped,
    required this.importSkippedWrites,
    required this.recordCounts,
    required this.clauseSeparator,
    required this.deleteNothingRequested,
    required this.deletedRecords,
    required this.deleteNothingDeleted,
    required this.deleteMissing,
    // —— 笔记编辑器 ——
    required this.newNote,
    required this.fieldTitle,
    required this.fieldDescription,
    required this.fieldDescriptionHint,
    required this.fieldBody,
    required this.tagLabel,
    required this.fieldTagsHint,
    required this.save,
    // —— 筛选面板 ——
    required this.noteFilterTitle,
    required this.archiveFilterLabel,
    required this.archiveActive,
    required this.archiveArchived,
    required this.archiveAll,
    required this.sortLabel,
    required this.sortUpdatedNewest,
    required this.sortUpdatedOldest,
    required this.sortTitleAscending,
    required this.allTags,
    required this.apply,
    // —— 空态与加载 ——
    required this.loadingHistory,
    required this.historyLoadFailed,
    required this.historyEmpty,
    required this.historyEmptyFiltered,
    required this.loadingNotes,
    required this.notesLoadFailed,
    required this.notesEmpty,
    required this.notesEmptyFiltered,
    required this.loadingMoreNotes,
    required this.loadMoreNotes,
    // —— 筛选摘要条（迁移前住在 `NotesController.visibleSummary` 的 `label` 里）——
    required this.summaryTabAll,
    required this.summaryTabNotes,
    required this.summaryTabHistory,
    required this.summaryTabFormulas,
    required this.summaryTabTools,
    required this.summarySearching,
    required this.summaryNoMatch,
    required this.summaryHistoryCount,
    required this.summaryNoteCount,
    required this.summaryPartsSeparator,
    // —— 保存时生成、写进库的笔记标题与描述 ——
    required this.untitledNote,
    required this.historyNoteTitle,
    required this.historyNoteDescription,
  });

  // —— 页头、搜索与胶囊 ——
  final String pageTitle;
  final String searchHint;
  final String clearSearchTooltip;
  final String tabAll;
  final String tabNotes;
  final String tabHistory;
  final String tabFormulas;
  final String tabTools;
  final String historySectionTitle;
  final String notesSectionTitle;

  // —— 多选态 ——
  final String cancelSelection;
  final String Function(int count) selectedCount;
  final String selectVisible;
  final String copySelected;
  final String deleteSelected;
  final String Function(int historyCount, int noteCount) deleteSelectedConfirm;
  final String Function(int count) copiedItems;

  // —— 历史：单条动作与清空 ——
  final String copyResult;
  final String saveAsNote;
  final String deleteHistoryEntry;
  final String deleteHistoryTooltip;
  final String historyResultCopied;
  final String savedToNotes;
  final String clearHistory;
  final String clearHistoryConfirm;

  // —— 笔记：单条动作 ——
  final String pinNote;
  final String unpinNote;
  final String pinned;
  final String unpinned;
  final String archiveNote;
  final String unarchiveNote;
  final String archived;
  final String unarchived;
  final String editNote;
  final String copyNote;
  final String noteCopied;
  final String deleteNote;
  final String Function(String title) deleteNoteConfirm;
  final String moreTooltip;

  // —— 删除确认（共用）——
  final String cancel;
  final String delete;
  final String clear;

  // —— 剪贴板导入 ——
  final String clipboardImportTitle;
  final String importButton;
  final String Function(int count) hiddenCount;

  // —— 导入 / 删除回执 ——
  // 中文：这十四格是**领域层那些回执令牌的落点**（`NotesImportPlanStatus` /
  //       `NotesImportReceiptStatus` / `NotesDeleteStatus`，见 `notes_receipt_message.dart`）。
  //       「计数」与「跳过 N 段」这类可选的尾巴是**载荷**，各自一格，由呈现边缘按存在与否拼上去。
  // English: these fourteen cells are **where the domain layer's receipt tokens land**
  //          (`NotesImportPlanStatus` / `NotesImportReceiptStatus` / `NotesDeleteStatus`, see
  //          `notes_receipt_message.dart`). The optional tails ("counts", "skipped N blocks") are
  //          **payload**, one cell each, spliced in at the presentation edge when they are present.
  final String importClipboardEmpty;
  final String importNothingRecognised;
  final String Function(String counts) importWillImport;
  final String Function(String counts) imported;
  final String importNothingNew;
  final String Function(int count) importSkippedUnrecognised;
  final String Function(int count) importPlanSkipped;
  final String Function(int count) importSkippedWrites;
  final String Function(int historyCount, int noteCount) recordCounts;
  final String clauseSeparator;
  final String deleteNothingRequested;
  final String Function(String counts) deletedRecords;
  final String deleteNothingDeleted;
  final String Function(int count) deleteMissing;

  // —— 笔记编辑器 ——
  final String newNote;
  final String fieldTitle;
  final String fieldDescription;
  final String fieldDescriptionHint;
  final String fieldBody;
  final String tagLabel;
  final String fieldTagsHint;
  final String save;

  // —— 筛选面板 ——
  final String noteFilterTitle;
  final String archiveFilterLabel;
  final String archiveActive;
  final String archiveArchived;
  final String archiveAll;
  final String sortLabel;
  final String sortUpdatedNewest;
  final String sortUpdatedOldest;
  final String sortTitleAscending;
  final String allTags;
  final String apply;

  // —— 空态与加载 ——
  final String loadingHistory;
  final String Function(String error) historyLoadFailed;
  final String historyEmpty;
  final String historyEmptyFiltered;
  final String loadingNotes;
  final String Function(String error) notesLoadFailed;
  final String notesEmpty;
  final String notesEmptyFiltered;
  final String loadingMoreNotes;
  final String loadMoreNotes;

  // —— 筛选摘要条 ——
  // 中文：这十格是**筛选摘要那条 `label` 的落点**：它的头（五个标签、搜索那一句）与两根计数
  //       尾巴由呈现层（`notes_summary_message.dart`）按 `NotesVisibleSummary` 的令牌拼起来，
  //       「·」那根连接符也跟着语言走。中文侧逐字节等于迁移前 `NotesVisibleSummary.label` 里那句。
  // English: these ten cells are **where the filter summary's `label` lands**: its head (the five tab
  //          labels, the search phrase) and the two count tails are put together at the presentation
  //          edge (`notes_summary_message.dart`) from `NotesVisibleSummary`'s token, and the "·"
  //          separator follows the language too. The Chinese side is byte-identical to the sentence
  //          `NotesVisibleSummary.label` used to build.
  final String summaryTabAll;
  final String summaryTabNotes;
  final String summaryTabHistory;
  final String summaryTabFormulas;
  final String summaryTabTools;
  final String Function(String query) summarySearching;
  final String summaryNoMatch;
  final String Function(int count) summaryHistoryCount;
  final String Function(int count) summaryNoteCount;
  final String summaryPartsSeparator;

  // —— 保存时生成、写进库的笔记标题与描述 ——
  // 中文：这三格与上面所有格都不同：**它们不是画在屏幕上的字，而是写进 `notes` 表的字**。标题留空
  //       时存的是 [untitledNote]；从一条计算历史保存笔记时，标题是 [historyNoteTitle]、描述是
  //       [historyNoteDescription]（时间戳是**载荷**，由调用方格式化后递进来，所以那一格的模板
  //       只含一句不变的话）。**生成的那一刻按当时的界面语言冻结**，之后不再跟着界面变——标题是
  //       用户数据（可编辑、会被导出进备份、可被搜索），跟着语言变的"名字"比冻结在创建时的语言更
  //       糟。三种形状的取舍与理由写在 `docs/verification.md` §5l；迁移前这三句硬编码在
  //       `NotesController` 里，所以英文界面下存进去的仍是中文。
  //
  //       调用方是 `NotesController`：它必填地持有一张 [NotesStrings]（与
  //       `ToolDetailController.strings` 同一形状），页面在 `initState` 里按设置的语言代码取
  //       （[forCode]），再在 `didChangeDependencies` 里换成作用域中**当场生效**的那张。
  // English: These three cells differ from every cell above: **they are not painted on screen, they are
  //          written into the `notes` table.** A blank title stores [untitledNote]; saving a note from
  //          a calculation-history row stores [historyNoteTitle] as the title and
  //          [historyNoteDescription] as the description (the timestamp is **payload**, formatted by the
  //          caller, so the cell's template holds one unchanging sentence). **They freeze at the moment
  //          of creation in the then-active interface language** and never follow the interface again —
  //          a title is user data (editable, exported in backups, searchable), and a name that changes
  //          under the user with the language is worse than one frozen in the language of creation. The
  //          three shapes and their costs are in `docs/verification.md` §5l; before the move these three
  //          sentences were hard-coded in `NotesController`, so an English interface stored Chinese.
  //
  //          The caller is `NotesController`: it holds a [NotesStrings] as a required field (the same
  //          shape as `ToolDetailController.strings`), which the page seeds from the settings' language
  //          code ([forCode]) in `initState` and then swaps in `didChangeDependencies` for the scope's
  //          **immediately effective** one.
  final String untitledNote;
  final String historyNoteTitle;
  final String Function(String timestamp) historyNoteDescription;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过，
  ///       而不是静默回落到中文。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here rather than silently falling back to Chinese.
  static NotesStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。两条路径共用这一个
  ///       switch，不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext`. Both routes share this
  ///          one switch, so they cannot drift apart.
  static NotesStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => notesZh,
      AppLanguage.en => notesEn,
    };
  }

  /// 中文：按**持久化语言代码**取表（`AppSettings.languageCode` 那个值），与
  ///       `ToolDetailStrings.forCode` / `CalculatorControllerStrings.forCode` 同一条路：
  ///       认不出的代码由 `AppLanguage.fromCode` 回落到中文，那是语言解析的既有约定。
  ///       存在的理由与详情页那条一模一样：笔记页在 `initState` 里造控制器，而那一刻**还不许查
  ///       `BuildContext`**，所以先按设置里的代码取一张，随后由 `didChangeDependencies` 用作用域里
  ///       **当场生效**的那张覆盖掉（`app.dart` 的 `onLanguageChanged` 只换内存里的 `_language`，
  ///       不重载设置记录，只看设置会漏掉"设置页还开着、底下的笔记页已经该换语言了"这一种）。
  /// English: Looks the table up by **persisted language code** (the value in
  ///          `AppSettings.languageCode`), the same route as `ToolDetailStrings.forCode` /
  ///          `CalculatorControllerStrings.forCode`: an unrecognised code falls back to Chinese inside
  ///          `AppLanguage.fromCode`, which is the existing language-resolution convention. It exists
  ///          for exactly the reason the detail screen's does: the notes page builds its controller in
  ///          `initState`, where a `BuildContext` **may not be queried**, so construction takes the
  ///          code from settings and `didChangeDependencies` then overwrites it with the scope's
  ///          **immediately effective** table (`app.dart`'s `onLanguageChanged` swaps only the
  ///          in-memory `_language` without reloading the settings record, so watching settings alone
  ///          would miss "the settings page is still open but the notes page underneath should already
  ///          have changed language").
  static NotesStrings forCode(String? code) {
    return forLanguage(AppLanguage.fromCode(code));
  }

  static final NotesStrings notesZh = NotesStrings(
    pageTitle: '笔记',
    searchHint: '搜索笔记、历史、公式...',
    clearSearchTooltip: '清除',
    tabAll: '全部',
    tabNotes: '笔记',
    tabHistory: '历史',
    tabFormulas: '公式',
    tabTools: '工具',
    historySectionTitle: '计算历史',
    notesSectionTitle: '个人笔记',
    cancelSelection: '取消选择',
    selectedCount: (count) => '已选择 $count 项',
    selectVisible: '选择当前列表',
    copySelected: '复制所选',
    deleteSelected: '删除所选',
    deleteSelectedConfirm: (historyCount, noteCount) =>
        '确认删除 $historyCount 条历史和 $noteCount 条笔记？此操作无法撤销。',
    copiedItems: (count) => '已复制 $count 项',
    copyResult: '复制结果',
    saveAsNote: '保存为笔记',
    deleteHistoryEntry: '删除记录',
    deleteHistoryTooltip: '删除',
    historyResultCopied: '已复制历史结果',
    savedToNotes: '已保存到笔记',
    clearHistory: '清空历史',
    clearHistoryConfirm: '确认删除全部计算历史？笔记不会受影响。',
    pinNote: '置顶笔记',
    unpinNote: '取消置顶',
    pinned: '已置顶笔记',
    unpinned: '已取消置顶',
    archiveNote: '归档笔记',
    unarchiveNote: '取消归档',
    archived: '已归档笔记',
    unarchived: '已取消归档',
    editNote: '编辑笔记',
    copyNote: '复制笔记',
    noteCopied: '已复制笔记',
    deleteNote: '删除笔记',
    deleteNoteConfirm: (title) => '确认删除“$title”？此操作无法撤销。',
    moreTooltip: '更多',
    cancel: '取消',
    delete: '删除',
    clear: '清空',
    clipboardImportTitle: '从剪贴板导入',
    importButton: '导入',
    hiddenCount: (count) => '还有 $count 条未显示',
    importClipboardEmpty: '剪贴板没有文本内容',
    importNothingRecognised: '未识别到可导入的笔记或历史导出',
    importWillImport: (counts) => '将导入 $counts',
    imported: (counts) => '已导入 $counts',
    importNothingNew: '没有导入新内容',
    importSkippedUnrecognised: (count) => '跳过 $count 段无法识别内容',
    importPlanSkipped: (count) => '跳过 $count 段',
    importSkippedWrites: (count) => '未写入 $count 条',
    recordCounts: (historyCount, noteCount) => [
      if (historyCount > 0) '$historyCount 条历史',
      if (noteCount > 0) '$noteCount 条笔记',
    ].join('、'),
    clauseSeparator: '，',
    deleteNothingRequested: '没有选择要删除的记录',
    deletedRecords: (counts) => '已删除 $counts',
    deleteNothingDeleted: '没有删除记录',
    deleteMissing: (count) => '$count 项未找到或已被删除',
    newNote: '新增笔记',
    fieldTitle: '标题',
    fieldDescription: '描述',
    fieldDescriptionHint: '写清用途、来源或下一步处理',
    fieldBody: '内容',
    tagLabel: '标签',
    fieldTagsHint: '用逗号分隔，例如：实验, 待处理',
    save: '保存',
    noteFilterTitle: '笔记筛选',
    archiveFilterLabel: '状态',
    archiveActive: '未归档',
    archiveArchived: '已归档',
    archiveAll: '全部状态',
    sortLabel: '排序',
    sortUpdatedNewest: '最近更新',
    sortUpdatedOldest: '最早更新',
    sortTitleAscending: '标题 A-Z',
    allTags: '全部标签',
    apply: '应用',
    loadingHistory: '正在加载历史记录。',
    historyLoadFailed: (error) => '历史读取失败：$error',
    historyEmpty: '暂无历史记录。',
    historyEmptyFiltered: '当前筛选下没有历史记录。',
    loadingNotes: '正在加载笔记。',
    notesLoadFailed: (error) => '笔记读取失败：$error',
    notesEmpty: '暂无个人笔记。',
    notesEmptyFiltered: '当前筛选下没有个人笔记。',
    loadingMoreNotes: '正在加载',
    loadMoreNotes: '加载更多笔记',
    summaryTabAll: '全部记录',
    summaryTabNotes: '笔记',
    summaryTabHistory: '历史',
    summaryTabFormulas: '公式',
    summaryTabTools: '工具',
    summarySearching: (query) => '搜索“$query”',
    summaryNoMatch: '无匹配',
    summaryHistoryCount: (count) => '历史 $count',
    summaryNoteCount: (count) => '笔记 $count',
    summaryPartsSeparator: ' · ',
    untitledNote: '未命名笔记',
    historyNoteTitle: '历史结果',
    historyNoteDescription: (timestamp) => '由计算历史保存，时间 $timestamp',
  );

  static final NotesStrings notesEn = NotesStrings(
    pageTitle: 'Notes',
    searchHint: 'Search notes, history, formulas…',
    clearSearchTooltip: 'Clear',
    tabAll: 'All',
    tabNotes: 'Notes',
    tabHistory: 'History',
    tabFormulas: 'Formulas',
    tabTools: 'Tools',
    historySectionTitle: 'Calculation history',
    notesSectionTitle: 'Personal notes',
    cancelSelection: 'Cancel selection',
    selectedCount: (count) => '$count selected',
    selectVisible: 'Select everything listed',
    copySelected: 'Copy selected',
    deleteSelected: 'Delete selected',
    deleteSelectedConfirm: (historyCount, noteCount) =>
        'Delete $historyCount history entries and $noteCount notes? This cannot '
        'be undone.',
    copiedItems: (count) => 'Copied $count items',
    copyResult: 'Copy result',
    saveAsNote: 'Save as note',
    deleteHistoryEntry: 'Delete entry',
    deleteHistoryTooltip: 'Delete',
    historyResultCopied: 'History result copied',
    savedToNotes: 'Saved to notes',
    clearHistory: 'Clear history',
    clearHistoryConfirm:
        'Delete the entire calculation history? Notes are not affected.',
    pinNote: 'Pin note',
    unpinNote: 'Unpin note',
    pinned: 'Note pinned',
    unpinned: 'Note unpinned',
    archiveNote: 'Archive note',
    unarchiveNote: 'Unarchive note',
    archived: 'Note archived',
    unarchived: 'Note unarchived',
    editNote: 'Edit note',
    copyNote: 'Copy note',
    noteCopied: 'Note copied',
    deleteNote: 'Delete note',
    deleteNoteConfirm: (title) => 'Delete “$title”? This cannot be undone.',
    moreTooltip: 'More',
    cancel: 'Cancel',
    delete: 'Delete',
    clear: 'Clear',
    clipboardImportTitle: 'Import from clipboard',
    importButton: 'Import',
    hiddenCount: (count) => '$count more not shown',
    importClipboardEmpty: 'The clipboard has no text',
    importNothingRecognised: 'No notes or history exports were recognised',
    importWillImport: (counts) => 'Will import $counts',
    imported: (counts) => 'Imported $counts',
    importNothingNew: 'Nothing new was imported',
    importSkippedUnrecognised: (count) => 'skipping $count unrecognised blocks',
    importPlanSkipped: (count) => 'skipping $count blocks',
    importSkippedWrites: (count) => '$count not written',
    recordCounts: (historyCount, noteCount) => [
      if (historyCount > 0) '$historyCount history entries',
      if (noteCount > 0) '$noteCount notes',
    ].join(' and '),
    clauseSeparator: ', ',
    deleteNothingRequested: 'No records were selected',
    deletedRecords: (counts) => 'Deleted $counts',
    deleteNothingDeleted: 'Nothing was deleted',
    deleteMissing: (count) => '$count not found or already deleted',
    newNote: 'New note',
    fieldTitle: 'Title',
    fieldDescription: 'Description',
    fieldDescriptionHint: 'What it is for, where it came from, what comes next',
    fieldBody: 'Body',
    tagLabel: 'Tags',
    fieldTagsHint: 'Comma separated, e.g. experiment, todo',
    save: 'Save',
    noteFilterTitle: 'Note filters',
    archiveFilterLabel: 'Status',
    archiveActive: 'Active',
    archiveArchived: 'Archived',
    archiveAll: 'Any status',
    sortLabel: 'Sort',
    sortUpdatedNewest: 'Recently updated',
    sortUpdatedOldest: 'Least recently updated',
    sortTitleAscending: 'Title A-Z',
    allTags: 'All tags',
    apply: 'Apply',
    loadingHistory: 'Loading history…',
    historyLoadFailed: (error) => 'Could not load history: $error',
    historyEmpty: 'No history yet.',
    historyEmptyFiltered: 'No history matches the current filter.',
    loadingNotes: 'Loading notes…',
    notesLoadFailed: (error) => 'Could not load notes: $error',
    notesEmpty: 'No personal notes yet.',
    notesEmptyFiltered: 'No notes match the current filter.',
    loadingMoreNotes: 'Loading',
    loadMoreNotes: 'Load more notes',
    summaryTabAll: 'All records',
    summaryTabNotes: 'Notes',
    summaryTabHistory: 'History',
    summaryTabFormulas: 'Formulas',
    summaryTabTools: 'Tools',
    summarySearching: (query) => 'Searching "$query"',
    summaryNoMatch: 'no matches',
    summaryHistoryCount: (count) => '$count history',
    summaryNoteCount: (count) => '$count notes',
    // 中文：⚠️ **这一格原本照抄了中文的 `' · '`**，而 `notes_summary_message_test.dart` 明确断言
    //       "英文摘要里还留着中文分隔符"⇒ 套件红。**测试对、代码错。** 英文按本仓既有惯例取 `', '`
    //       （`calculator_controller_strings.dart:490` 的 `listSeparator`、`settings_backup_strings.dart:300`
    //       的 `backupTableListSeparator` 都是 `', '`，中文对应 `'、'`）。
    // English: ⚠️ **this cell originally copied the Chinese `' · '`**, and
    //          `notes_summary_message_test.dart` asserts flatly that an English summary keeps no Chinese
    //          separator ⇒ the suite went red. **The test was right and the code was wrong.** English now
    //          follows the repo's own convention, `', '` (both `listSeparator` at
    //          `calculator_controller_strings.dart:490` and `backupTableListSeparator` at
    //          `settings_backup_strings.dart:300` are `', '` against a Chinese `'、'`).
    summaryPartsSeparator: ', ',
    untitledNote: 'Untitled note',
    historyNoteTitle: 'History result',
    historyNoteDescription: (timestamp) =>
        'Saved from calculation history at $timestamp',
  );
}
