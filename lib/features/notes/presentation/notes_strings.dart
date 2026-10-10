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
///       2. **应用层自己产出的字**：`NotesController` 的 `error`（异常的技术串）、`summary.label`、
///          `searchSuggestions()` / `searchExamples()`（搜索示例是**拿去搜的词**，与内容探针同一类），
///          以及导出 / 复制正文那一套标签（`'表达式:'`、`'结果:'`…——它们是**剪贴板往返的格式**，
///          由 `notes_clipboard_import.dart` 的解析器读回）。这些今天仍是中文——**这是已知的残留**，
///          不是漏翻。
///
///       **已经搬进来的**：导入与删除的回执。`NotesClipboardImportPlan` / `…Result` /
///       `NotesDeleteResult` 从前自己拼那几句中文并直接上屏（`SnackBar` 与导入对话框），现在领域层
///       只给令牌（`NotesImportPlanStatus` / `NotesImportReceiptStatus` / `NotesDeleteStatus`），
///       字在这儿，由 `notes_receipt_message.dart` 在**呈现边缘**取。
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
///             (an exception's technical string), `summary.label`, `searchSuggestions()` /
///             `searchExamples()` (a search example is a **word you search with**, the same category as
///             a content probe), and the labels of the export / copy body (`'表达式:'`, `'结果:'` … —
///             they are the **clipboard round-trip format** read back by `notes_clipboard_import.dart`'s
///             parser). Those are still Chinese today — a **known remainder**, not a missed
///             translation.
///
///          **What has moved in**: the import and delete receipts. `NotesClipboardImportPlan` /
///          `…Result` / `NotesDeleteResult` used to compose those Chinese sentences themselves and
///          print them straight (`SnackBar`, the import dialog); the domain layer now hands over only
///          the tokens (`NotesImportPlanStatus` / `NotesImportReceiptStatus` / `NotesDeleteStatus`),
///          the words live here, and `notes_receipt_message.dart` reads them **at the presentation
///          edge**.
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
  );
}
