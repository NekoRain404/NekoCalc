/// 中文：**剪贴板导入那几句"生成的字"的翻译处——领域层给令牌与载荷，这里给字。**
///
///       `NotesNoteImportDraft` 与 `NotesClipboardImportPreview` 从前自己拼这几句中文
///       （`'剪贴板笔记 · …'`、`'从剪贴板导入的文本'`、导出块没有标题时的 `'导入笔记'`、
///       `'计算历史 · …'` / `'工具 … · 原时间 …'`），于是英文界面下有两条漏法：**存进库的笔记标题
///       与描述是中文**（`docs/verification.md` §5m 把这三条记成具名欠账），**导入对话框里那一行
///       预览也是中文**。现在字住在 [NotesStrings] 里，由这四个函数在**边缘**按令牌取：
///       前两条在**保存那一刻**取（调用方是 `NotesController`，与 §5l 那三句——`untitledNote` /
///       `historyNoteTitle` / `historyNoteDescription`——同一条路，冻结在创建时的语言里），
///       后两条在**画那一行时**取（调用方是导入对话框，取表的语言就是屏幕的语言）。
///
///       **句子怎么拼是这里的事，词是表的事**：模板与载荷的拼接、两个兜底格（标题为空 / 没有首行）
///       与两条截断（24 / 30 个字符）都在这里，所以这个文件里**一个中文字面量都没有**——它因此落在
///       `notes_strings_test.dart` 第 3 条那条"笔记页源码里除了文案表再没有中文字符串字面量"的
///       扫描范围里，而不是像那张表本身那样被跳过。
///
///       **加一种措辞、加一种草稿都在这里编译不过**：前两个 `switch` 穷尽 [NotesNoteDraftWording]，
///       后两个穷尽那棵密封的 [NotesClipboardImportPreview] 树。
/// English: **where the clipboard import's generated sentences are translated — the domain hands over
///          the token and the payload, this hands over the words.**
///
///          `NotesNoteImportDraft` and `NotesClipboardImportPreview` used to compose these Chinese
///          sentences themselves (`'剪贴板笔记 · …'`, `'从剪贴板导入的文本'`, the `'导入笔记'` fallback
///          for an export block with no title, `'计算历史 · …'` / `'工具 … · 原时间 …'`), which leaked
///          two ways under an English interface: **the note title and description written into the
///          database were Chinese** (`docs/verification.md` §5m records the three as a named debt) and
///          **so was the preview row in the import dialog**. The words now live in [NotesStrings] and
///          these four functions fetch them **at the edge**, keyed by the token: the first two at **the
///          moment of saving** (called by `NotesController`, the same road as §5l's three —
///          `untitledNote` / `historyNoteTitle` / `historyNoteDescription` — freezing in the language
///          of creation), the last two **when the row is painted** (called by the import dialog, whose
///          table is the language on screen).
///
///          **How a sentence is put together is this file's business, the words are the table's**: the
///          template-to-payload splices, the two fallback cells (empty title / no first line) and the
///          two truncations (24 / 30 characters) all live here, so this file holds **not one Chinese
///          literal** — which puts it inside clause 3 of `notes_strings_test.dart` ("no Chinese string
///          literal in the notes page's sources other than the copy table") rather than on the skip
///          list the table itself sits on.
///
///          **Adding a wording or a kind of draft breaks the build here**: the first two `switch`es
///          exhaust [NotesNoteDraftWording], the last two exhaust the sealed
///          [NotesClipboardImportPreview] tree.
library;

import '../../../domain/usecases/notes_clipboard_import.dart';
import 'notes_strings.dart';

/// 中文：**一条笔记草稿要写进库的标题。** 两支：用户写下的标题为空时取表里的兜底格；剪贴板那一支
///       把首行截到 **24** 个字符接进「剪贴板笔记 · …」那句里（没有首行时取表里另一格）。
///       两条规则都逐字节搬自迁移前的 `_plainTextDraft` / `_parseNoteBlock`。
/// English: **the title one note draft is to write into the database.** Two branches: an empty
///          user-written title takes the table's fallback cell; the clipboard branch truncates the
///          first line to **24** characters and splices it into the "clipboard note · …" sentence (a
///          missing first line takes the table's other cell). Both rules are copied byte for byte from
///          the pre-move `_plainTextDraft` / `_parseNoteBlock`.
String notesNoteDraftTitle(NotesNoteImportDraft draft, NotesStrings strings) {
  return switch (draft.wording) {
    NotesNoteDraftWording.parsed =>
      draft.title.isEmpty ? strings.importedNoteTitle : draft.title,
    NotesNoteDraftWording.clipboard => strings.clipboardNoteTitle(
        draft.title.isEmpty
            ? strings.clipboardNoteBlankFirstLine
            : _truncateSingleLine(draft.title, 24),
      ),
  };
}

/// 中文：**一条笔记草稿要写进库的描述。** 用户写下的原样过去（可能为空 = 不存描述）；剪贴板那一支
///       取表里那一格。
/// English: **the description one note draft is to write into the database.** What the user wrote goes
///          through as it is (possibly empty = no description is stored); the clipboard branch takes
///          the table's cell.
String notesNoteDraftDescription(NotesNoteImportDraft draft, NotesStrings strings) {
  return switch (draft.wording) {
    NotesNoteDraftWording.parsed => draft.description,
    NotesNoteDraftWording.clipboard => strings.clipboardNoteDescription,
  };
}

/// 中文：**导入对话框里一行预览的标题。** 笔记那一行与**将要存进库的那一份**逐字相同（走上面那个
///       函数，所以预览与保存不会说两句话）；历史那一行的前缀由 `toolId` 是否为空决定
///       （`null` = 计算历史，否则工具历史），表达式截到 **30** 个字符——与迁移前的 `previewTitle`
///       逐字节相同。
/// English: **the title of one preview row in the import dialog.** A note row is character-for-character
///          what **will be written into the database** (it goes through the function above, so preview
///          and save cannot say two different things); a history row's prefix is decided by whether
///          `toolId` is null (null = calculation history, otherwise tool history) and its expression is
///          truncated to **30** characters — byte-identical to the pre-move `previewTitle`.
String notesImportPreviewTitle(
  NotesClipboardImportPreview preview,
  NotesStrings strings,
) {
  return switch (preview) {
    NotesNoteImportPreview(:final draft) => notesNoteDraftTitle(draft, strings),
    NotesHistoryImportPreview(:final draft) => draft.toolId == null
        ? strings.historyPreviewTitle(_truncateSingleLine(draft.expression, 30))
        : strings.toolHistoryPreviewTitle(_truncateSingleLine(draft.expression, 30)),
  };
}

/// 中文：**导入对话框里一行预览的描述。** 笔记那一行同样与将要存进库的描述逐字相同；历史那一行由
///       表里那一格按 `toolId` 与源时间标签拼（两者都可以缺，空串 = 不画副标题）——与迁移前的
///       `previewDescription` 逐字节相同。
/// English: **the description of one preview row in the import dialog.** A note row is again
///          character-for-character the description that will be stored; a history row is assembled by
///          the table's cell from `toolId` and the source time label (either may be absent; the empty
///          string = no subtitle is drawn) — byte-identical to the pre-move `previewDescription`.
String notesImportPreviewDescription(
  NotesClipboardImportPreview preview,
  NotesStrings strings,
) {
  return switch (preview) {
    NotesNoteImportPreview(:final draft) => notesNoteDraftDescription(draft, strings),
    NotesHistoryImportPreview(:final draft) =>
      strings.historyPreviewDescription(draft.toolId, draft.sourceTimeLabel),
  };
}

/// 中文：**截断规则本身**（迁移前住在 `notes_clipboard_import.dart` 里，逐字节搬过来）：先把空白
///       折成一个空格、去掉两端，超过 [maxLength] 时截到 `maxLength - 1` 个字符再接 `...`——
///       所以超长时最长是 `maxLength + 2` 个字符。**中文侧一个字都不许动**：它决定的是存进库的
///       标题（24）与对话框那一行（30），测试钉着这两条。
/// English: **the truncation rule itself** (it lived in `notes_clipboard_import.dart` before the move
///          and is copied over byte for byte): whitespace collapses to single spaces and the ends are
///          trimmed; over [maxLength] it cuts to `maxLength - 1` characters and appends `...` — so an
///          over-long value ends up at most `maxLength + 2` characters. **Not one character of the
///          Chinese side may move**: it decides the stored title (24) and the dialog row (30), and the
///          tests pin both.
String _truncateSingleLine(String value, int maxLength) {
  final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.length <= maxLength) return singleLine;
  return '${singleLine.substring(0, maxLength - 1)}...';
}
