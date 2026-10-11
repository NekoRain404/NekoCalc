import '../../../application/controllers/notes_controller.dart';
import 'notes_strings.dart';

/// 中文：**筛选摘要条那句的翻译处——控制器给令牌，这里给字。**
///
///       `NotesVisibleSummary.label` 从前自己在应用层拼那句中文（`'全部记录 · 历史 2 · 笔记 1'`、
///       `'搜索“Ω” · 无匹配'`）并直接印在笔记页筛选摘要条上，于是英文界面下印的仍是中文：
///       **应用层对象活得比界面长**，界面那张按语言切的表够不着它（`docs/verification.md` §5i）。
///       现在那句住在 [NotesStrings] 里，由 [notesSummaryLabel] 在**呈现边缘**按令牌取——取表的语言
///       就是屏幕的语言。
///
///       **形状照的是已经转过的六条路径**：`notesImportMessage`、`notesDeleteMessage`、
///       `calculatorSubmitMessage`、`calculatorSaveNoteMessage`、`toolSaveMessage`、
///       `backupPreviewWarningMessage`（令牌在产出层，字在呈现层的表里）。
///
///       **令牌是 `NotesTab`（= `RecordTab`）与两个派生读数，不另造一个枚举**：那句的头由
///       `tab` 决定（五格标签，穷尽 `switch` 写在这里，加一个标签会编译不过），有查询字时换成
///       「搜索“…”」那一格；尾巴由 `totalCount == 0`（无匹配）与两个计数是否存在决定。
///       旧读数一个都没动，所以哪一种摘要什么时候出现与迁移前完全一致。
///
///       **句子怎么拼是这里的事，词是表的事**：头、两根计数尾巴与那个「·」连接符都按语言在
///       这里拼上去，所以这个文件里**一个中文字面量都没有**——它因此落在 `notes_strings_test.dart`
///       第 3 条那条"笔记页源码里除了文案表再没有中文字符串字面量"的扫描范围里，而不是像那张表
///       本身那样被跳过。
/// English: **where the filter summary's sentence is translated — the controller hands over the token,
///          this hands over the words.**
///
///          `NotesVisibleSummary.label` used to compose that Chinese sentence itself in the application
///          layer (`'全部记录 · 历史 2 · 笔记 1'`, `'搜索“Ω” · 无匹配'`) and print it straight onto the
///          notes page's filter summary bar, so an English interface still printed Chinese: **an
///          application-layer object outlives the UI** and a language-keyed interface table cannot reach
///          it (`docs/verification.md` §5i). That sentence now lives in [NotesStrings], fetched **at the
///          presentation edge** by [notesSummaryLabel], keyed by the token — the language of the table is
///          the language on screen.
///
///          **The shape is copied from the six converted paths**: `notesImportMessage`,
///          `notesDeleteMessage`, `calculatorSubmitMessage`, `calculatorSaveNoteMessage`,
///          `toolSaveMessage`, `backupPreviewWarningMessage` (token in the producing layer, words in the
///          presentation layer's table).
///
///          **The token is `NotesTab` (= `RecordTab`) plus two derived readings, with no new enum
///          invented**: the head is decided by `tab` (the five labels, an exhaustive `switch` written
///          out here, so adding a tab breaks the build), replaced by the "Searching “…”" cell when
///          there is a query; the tail is decided by `totalCount == 0` (no match) and by which of the
///          two counts is present. Not one old reading moved, so which summary appears when is exactly
///          what it was.
///
///          **How a sentence is put together is this file's business, the words are the table's**: the
///          head, the two count tails and the "·" separator are joined here, per language, so this file
///          holds **not one Chinese literal** — which puts it inside clause 3 of `notes_strings_test.dart`
///          ("no Chinese string literal in the notes page's sources other than the copy table") rather
///          than on the skip list the table itself sits on.
String notesSummaryLabel(NotesVisibleSummary summary, NotesStrings strings) {
  final head = summary.hasQuery
      ? strings.summarySearching(summary.query)
      : _summaryTabLabel(summary.tab, strings);
  if (summary.totalCount == 0) {
    return head + strings.summaryPartsSeparator + strings.summaryNoMatch;
  }
  final parts = <String>[
    if (summary.historyCount > 0)
      strings.summaryHistoryCount(summary.historyCount),
    if (summary.noteCount > 0) strings.summaryNoteCount(summary.noteCount),
  ];
  return head +
      strings.summaryPartsSeparator +
      parts.join(strings.summaryPartsSeparator);
}

/// 中文：**一句摘要的辖域标签**——五格穷尽 [NotesTab]，加一个标签这里编译不过，而不是静默少一句。
/// English: **the scope label of one summary** — the five cells exhaust [NotesTab], so adding a tab
///          breaks the build here rather than silently dropping a sentence.
String _summaryTabLabel(NotesTab tab, NotesStrings strings) {
  return switch (tab) {
    NotesTab.all => strings.summaryTabAll,
    NotesTab.notes => strings.summaryTabNotes,
    NotesTab.history => strings.summaryTabHistory,
    NotesTab.formulas => strings.summaryTabFormulas,
    NotesTab.tools => strings.summaryTabTools,
  };
}