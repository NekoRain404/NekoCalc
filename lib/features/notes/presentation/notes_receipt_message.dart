import '../../../domain/usecases/notes_clipboard_import.dart';
import '../../../domain/usecases/notes_delete_result.dart';
import 'notes_strings.dart';

/// 中文：**笔记回执的翻译处——领域层给令牌，这里给字。**
///
///       `NotesClipboardImportPlan` / `NotesClipboardImportResult` / `NotesDeleteResult` 从前自己拼
///       那几句中文并直接上屏（导入对话框里的 `plan.summary`、`notes_page_actions.dart` 里四处
///       `SnackBar` 印的 `result.message` / `result.importedMessage`），于是英文界面下印的仍是中文：
///       领域对象活得比界面长，界面那张按语言切的表够不着它（`docs/verification.md` §5i）。现在那些
///       句子住在 [NotesStrings] 里，由这四个函数在**呈现边缘**按令牌取——取表的语言就是屏幕的语言。
///
///       **形状照的是已经转过的两条路径**：`calculatorSubmitMessage(result, strings)` /
///       `calculatorSaveNoteMessage(result, strings)`（令牌在领域层，字在呈现层的表里），而它们照的
///       是更老的两条：`toolResultConclusion(results, label)` 与 `CalculatorPasteResult.summaryIn`。
///
///       **句子怎么拼是这里的事，词是表的事**：令牌只回答「这是哪件事」，可选的两根尾巴
///       （「跳过 N 段无法识别内容」「未写入 N 条」「N 项未找到或已被删除」）按计数拼上去，
///       连词（`clauseSeparator`）也跟着语言走——所以这个文件里**一个中文字面量都没有**，
///       它因此落在 `notes_strings_test.dart` 第 3 条那条"笔记页源码里除了文案表再没有中文字符串
///       字面量"的扫描范围里，而不是像那张表本身那样被跳过。
///
///       **加一种结局时这里编译不过**：三个 `switch` 穷尽三个令牌枚举。
/// English: **where a notes receipt is translated — the domain hands over the token, this hands over
///          the words.**
///
///          `NotesClipboardImportPlan` / `NotesClipboardImportResult` / `NotesDeleteResult` used to
///          compose those Chinese sentences themselves and print them straight (`plan.summary` in the
///          import dialog; `result.message` / `result.importedMessage` in four `SnackBar`s in
///          `notes_page_actions.dart`), so an English interface still printed Chinese: a domain object
///          outlives the UI and a language-keyed interface table cannot reach it
///          (`docs/verification.md` §5i). Those sentences now live in [NotesStrings], fetched **at the
///          presentation edge** by these four functions, keyed by the token — the language of the table
///          is the language on screen.
///
///          **The shape is copied from the two converted paths**: `calculatorSubmitMessage(result,
///          strings)` / `calculatorSaveNoteMessage(result, strings)` (token in the domain, words in the
///          presentation table), which themselves copied two older ones: `toolResultConclusion(results,
///          label)` and `CalculatorPasteResult.summaryIn`.
///
///          **How a sentence is put together is this file's business, the words are the table's**: the
///          token answers only "which thing is this", the optional tails ("skipped N unrecognised
///          blocks", "N not written", "N not found or already deleted") are appended from the counts,
///          and the conjunction (`clauseSeparator`) follows the language too — so this file holds **not
///          one Chinese literal**, which puts it inside clause 3 of `notes_strings_test.dart` ("no
///          Chinese string literal in the notes page's sources other than the copy table") rather than
///          on the skip list the table itself sits on.
///
///          **Adding an outcome breaks this at compile time**: the three `switch`es exhaust the three
///          token enums.
String notesImportPlanSummary(
  NotesClipboardImportPlan plan,
  NotesStrings strings,
) {
  final counts = strings.recordCounts(plan.historyCount, plan.noteCount);
  return switch (plan.status) {
    NotesImportPlanStatus.clipboardEmpty => strings.importClipboardEmpty,
    NotesImportPlanStatus.nothingRecognised => strings.importNothingRecognised,
    NotesImportPlanStatus.willImport => plan.skippedBlockCount > 0
        ? strings.importWillImport(counts) +
            strings.clauseSeparator +
            strings.importSkippedUnrecognised(plan.skippedBlockCount)
        : strings.importWillImport(counts),
  };
}

/// 中文：**计划侧面那句"将会导入什么"的回执**。它与 [notesImportMessage] 是同一个事实在两个时刻上的
///       说法，措辞故意不同（这一条说「跳过 N 段」，结果那条说「跳过 N 段无法识别内容」）——
///       两句都逐字节保留着迁移前的样子，测试钉着它们。
/// English: **the plan-side receipt of "what would be imported"**. It and [notesImportMessage] are the
///          same fact told at two moments, and their wording deliberately differs (this one says
///          "skipping N blocks", the result one says "skipping N unrecognised blocks") — both are kept
///          byte-identical to what they said before the move, and the tests pin them.
String notesImportPlanMessage(
  NotesClipboardImportPlan plan,
  NotesStrings strings,
) {
  final counts = strings.recordCounts(plan.historyCount, plan.noteCount);
  return plan.skippedBlockCount > 0
      ? strings.imported(counts) +
          strings.clauseSeparator +
          strings.importPlanSkipped(plan.skippedBlockCount)
      : strings.imported(counts);
}

/// 中文：**导入做完之后的回执**：头部由令牌决定（导入了东西 / 什么都没导入），尾巴按计数拼——
///       先「跳过 N 段无法识别内容」，后「未写入 N 条」，与迁移前的顺序逐字相同。
/// English: **the receipt after an import has run**: the head comes from the token (something was
///          imported / nothing was), the tails are appended from the counts — first "skipped N
///          unrecognised blocks", then "N not written", the same order as before the move, character
///          for character.
String notesImportMessage(
  NotesClipboardImportResult result,
  NotesStrings strings,
) {
  final counts = strings.recordCounts(result.historyCount, result.noteCount);
  final head = switch (result.receiptStatus) {
    NotesImportReceiptStatus.imported => strings.imported(counts),
    NotesImportReceiptStatus.nothingNew => strings.importNothingNew,
  };
  final parts = <String>[
    head,
    if (result.plan.skippedBlockCount > 0)
      strings.importSkippedUnrecognised(result.plan.skippedBlockCount),
    if (result.skippedWriteCount > 0)
      strings.importSkippedWrites(result.skippedWriteCount),
  ];
  return parts.join(strings.clauseSeparator);
}

/// 中文：**删除 / 清空之后的回执**：头部由令牌决定（根本没选东西 / 删掉了东西 / 什么都没删掉），
///       「N 项未找到或已被删除」那根尾巴按 [NotesDeleteResult.missingCount] 拼上去。计数用的是
///       **真的删掉的条数**（不是请求的条数）——迁移前就是这样。
/// English: **the receipt after a delete / clear**: the head comes from the token (nothing was selected
///          at all / something was deleted / nothing was deleted), and the "N not found or already
///          deleted" tail is appended from [NotesDeleteResult.missingCount]. The counts are the
///          **records really deleted** (not the requested ones) — which is how it was before the move.
String notesDeleteMessage(NotesDeleteResult result, NotesStrings strings) {
  final counts =
      strings.recordCounts(result.deletedHistoryCount, result.deletedNoteCount);
  final head = switch (result.status) {
    NotesDeleteStatus.nothingRequested => strings.deleteNothingRequested,
    NotesDeleteStatus.deleted => strings.deletedRecords(counts),
    NotesDeleteStatus.nothingDeleted => strings.deleteNothingDeleted,
  };
  if (result.missingCount == 0) return head;
  return head +
      strings.clauseSeparator +
      strings.deleteMissing(result.missingCount);
}
