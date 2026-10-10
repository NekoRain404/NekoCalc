/// 中文：**这一次删除 / 清空回执说的是哪件事——它既是判据，也是呈现层取那句话用的令牌。**
///
///       三格与 `NotesStrings` 里的三格一一对应（`deleteNothingRequested` / `deletedRecords` /
///       `deleteNothingDeleted`），由 `notesDeleteMessage(result, strings)` 那个穷尽 `switch` 接上；
///       计数（[NotesDeleteResult.deletedHistoryCount] / `deletedNoteCount` / `missingCount`）是
///       **载荷**，留在结果上由呈现层拼进句子（`'已删除 1 条历史，2 项未找到或已被删除'`）。
///
///       **顺序是判据的一部分**：`nothingRequested`（用户根本没选东西）压过另外两格——从前的
///       `if (requestedCount == 0)` 先判，本枚举把那个优先级写成一张表；`deleted` 与
///       `nothingDeleted` 的区别是「有没有真的删掉东西」，从前由 `hasDeletedRecords` 回答。
///
///       **这句话从前是在这里拼的**（`get message`，直接被 `NotesController` 的六个删除 / 清空方法
///       交出去，在 `notes_page_actions.dart` 的四处 `SnackBar` 上屏）：领域对象活得比界面长，
///       界面那张按语言切的文案表够不着它，所以英文界面下它照样是中文——`docs/verification.md`
///       §5i 记着这条层次性缺陷。形状照的是已经转过的两条路径。
/// English: **which thing this delete / clear receipt says — a verdict, and the token the presentation
///          layer resolves the sentence with.**
///
///          The three values correspond one for one with three cells in `NotesStrings`
///          (`deleteNothingRequested` / `deletedRecords` / `deleteNothingDeleted`), wired up by the
///          exhaustive `switch` in `notesDeleteMessage(result, strings)`; the counts
///          ([NotesDeleteResult.deletedHistoryCount] / `deletedNoteCount` / `missingCount`) are
///          **payload** and stay on the result for the presentation layer to splice into the sentence
///          (`'已删除 1 条历史，2 项未找到或已被删除'`).
///
///          **The order is part of the verdict**: `nothingRequested` (the user selected nothing at all)
///          outranks the other two — the old `if (requestedCount == 0)` stood first, and this enum
///          writes that precedence down as a table; `deleted` against `nothingDeleted` is "did anything
///          really go", which `hasDeletedRecords` used to answer.
///
///          **That sentence used to be composed right here** (`get message`, handed out by
///          `NotesController`'s six delete / clear methods and put on screen by four `SnackBar`s in
///          `notes_page_actions.dart`): a domain object outlives the UI and a language-keyed copy table
///          cannot reach it, so an English interface still printed Chinese — the layering defect
///          recorded in `docs/verification.md` §5i. The shape is the one the two converted paths use.
enum NotesDeleteStatus {
  nothingRequested,
  deleted,
  nothingDeleted,
}

class NotesDeleteResult {
  const NotesDeleteResult({
    required this.requestedHistoryCount,
    required this.requestedNoteCount,
    required this.deletedHistoryCount,
    required this.deletedNoteCount,
  });

  factory NotesDeleteResult.none() => const NotesDeleteResult(
        requestedHistoryCount: 0,
        requestedNoteCount: 0,
        deletedHistoryCount: 0,
        deletedNoteCount: 0,
      );

  final int requestedHistoryCount;
  final int requestedNoteCount;
  final int deletedHistoryCount;
  final int deletedNoteCount;

  int get requestedCount => requestedHistoryCount + requestedNoteCount;

  int get deletedCount => deletedHistoryCount + deletedNoteCount;

  int get missingCount {
    final missingHistory = requestedHistoryCount - deletedHistoryCount;
    final missingNotes = requestedNoteCount - deletedNoteCount;
    return [
      if (missingHistory > 0) missingHistory,
      if (missingNotes > 0) missingNotes,
    ].fold(0, (sum, count) => sum + count);
  }

  bool get hasDeletedRecords => deletedCount > 0;

  /// 中文：**这一次删除 / 清空回执属于三种结局里的哪一种**（见 [NotesDeleteStatus]）。
  /// English: **which of the three outcomes this delete / clear receipt is** (see [NotesDeleteStatus]).
  NotesDeleteStatus get status {
    if (requestedCount == 0) return NotesDeleteStatus.nothingRequested;
    return hasDeletedRecords
        ? NotesDeleteStatus.deleted
        : NotesDeleteStatus.nothingDeleted;
  }
}
