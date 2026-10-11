import 'package:intl/intl.dart';

/// 中文：**这一条笔记草稿的标题与描述属于哪一家**（与 [NotesImportPlanStatus] 同一条理由：领域对象
///       活得比界面长，界面那张按语言切的表够不着它）。
///
///       两格与 `NotesStrings` 里那几格一一对应，由 `notesNoteDraftTitle` /
///       `notesNoteDraftDescription`（`notes_import_draft_message.dart`）的穷尽 `switch` 接上。
///
///       **从前的三句话是在这里拼好的**：`'剪贴板笔记 · …'`、`'从剪贴板导入的文本'`，以及导出块
///       没有标题时的 `'导入笔记'`——于是英文界面下存进库的仍是中文（`docs/verification.md` §5m
///       把这三条记成具名欠账）。现在这里只留令牌与载荷，句子在**保存边缘**按当时的语言取；形状与
///       §5l 定下的那三句（`untitledNote` / `historyNoteTitle` / `historyNoteDescription`）逐字
///       同一条：标题是用户数据（可编辑、进备份、可搜索），所以冻结在创建那一刻的语言里，而不是
///       留一个显示时的令牌。
/// English: **which family this note draft's title and description belong to** (the same reasoning as
///          [NotesImportPlanStatus]: a domain object outlives the UI and a language-keyed interface
///          table cannot reach it).
///
///          The two values correspond one for one with cells in `NotesStrings`, wired up by the
///          exhaustive `switch`es in `notesNoteDraftTitle` / `notesNoteDraftDescription`
///          (`notes_import_draft_message.dart`).
///
///          **Those three sentences used to be composed right here**: `'剪贴板笔记 · …'`,
///          `'从剪贴板导入的文本'`, and the `'导入笔记'` fallback for a block with no title — so an
///          English interface still stored Chinese (`docs/verification.md` §5m records the three as a
///          named debt). What is left is the token and the payload; the sentence is fetched **at the
///          save edge** in the language of that moment, character for character the shape §5l settled
///          for `untitledNote` / `historyNoteTitle` / `historyNoteDescription`: a title is user data
///          (editable, exported in backups, searchable), so it freezes in the language of creation
///          rather than leaving a display-time token behind.
enum NotesNoteDraftWording {
  /// 中文：导出块里解析出来的笔记：标题与描述是**用户数据**，原样写进库；标题为空时取表里的兜底格。
  /// English: a note parsed out of an export block: title and description are **the user's own words**,
  ///          written into the database as they are; an empty title takes the table's fallback cell.
  parsed,

  /// 中文：剪贴板纯文本：标题是表里的「剪贴板笔记 · 首行」，描述是表里那一格。
  /// English: clipboard plain text: the title is the table's "clipboard note · first line" and the
  ///          description is the table's own cell.
  clipboard,
}

class NotesNoteImportDraft {
  const NotesNoteImportDraft({
    required this.wording,
    required this.title,
    required this.description,
    required this.body,
  });

  /// 中文：这一条草稿的标题与描述属于哪一家（见 [NotesNoteDraftWording]）。
  /// English: which family this draft's title and description belong to (see [NotesNoteDraftWording]).
  final NotesNoteDraftWording wording;

  /// 中文：**载荷，不是成品句子。** [NotesNoteDraftWording.parsed] 时是用户写下的标题（可能为空）；
  ///       [NotesNoteDraftWording.clipboard] 时是粘贴文本里第一行非空内容（可能为空 = 没有这样一行，
  ///       两个空都对应表里各自的兜底格）。两种情形都由 `notesNoteDraftTitle` 在保存边缘接上表里的
  ///       句子——剪贴板那一支还要按迁移前那条规则截到 24 个字符。
  /// English: **payload, not a finished sentence.** Under [NotesNoteDraftWording.parsed] it is the title
  ///          the user wrote (possibly empty); under [NotesNoteDraftWording.clipboard] the first
  ///          non-empty line of the pasted text (possibly empty = no such line; either emptiness maps to
  ///          its own fallback cell in the table). Both are joined to the table's sentence by
  ///          `notesNoteDraftTitle` at the save edge — the clipboard branch also truncates to 24
  ///          characters, the rule from before the move.
  final String title;

  /// 中文：**载荷。** [NotesNoteDraftWording.parsed] 时是用户写下的描述（可能为空）；
  ///       [NotesNoteDraftWording.clipboard] 时不用（描述由表里那一格给）。
  /// English: **payload.** Under [NotesNoteDraftWording.parsed] the description the user wrote
  ///          (possibly empty); unused under [NotesNoteDraftWording.clipboard] (the table's cell
  ///          supplies the description).
  final String description;

  final String body;
}

class NotesHistoryImportDraft {
  const NotesHistoryImportDraft({
    required this.expression,
    required this.result,
    required this.toolId,
    required this.createdAt,
    required this.sourceTimeLabel,
  });

  final String expression;
  final String result;
  final String? toolId;
  final DateTime? createdAt;
  final String? sourceTimeLabel;
}

/// 中文：**导入对话框里的一行预览说的是哪一条草稿。** 一棵密封树、两个子类——与
///       [NotesNoteDraftWording] 同一条理由：从前这一行的标题与描述是在这里拼好的中文
///       （`previewTitle` / `previewDescription`：`'计算历史 · …'`、`'工具 … · 原时间 …'`），
///       英文界面下那一行照样是中文。现在这里只留**那条草稿本身**（令牌与载荷都在草稿上），标题与
///       描述由 `notesImportPreviewTitle` / `notesImportPreviewDescription` 在**呈现边缘**按对话框
///       当下的语言取。密封树让"多一种草稿"在那两处 `switch` 编译不过，而不是静默少印一行。
/// English: **which draft one preview row of the import dialog is about.** A sealed tree with two
///          subclasses — the same reasoning as [NotesNoteDraftWording]: this row's title and
///          description used to be composed here in Chinese (`previewTitle` / `previewDescription`:
///          `'计算历史 · …'`, `'工具 … · 原时间 …'`), and an English interface still showed Chinese.
///          What stays here is **the draft itself** (its token and payloads); the title and description
///          are fetched **at the presentation edge** by `notesImportPreviewTitle` /
///          `notesImportPreviewDescription` in the language the dialog is currently showing. The sealed
///          tree makes "one more kind of draft" break those two `switch`es at compile time rather than
///          quietly dropping a row.
sealed class NotesClipboardImportPreview {
  const NotesClipboardImportPreview();
}

class NotesNoteImportPreview extends NotesClipboardImportPreview {
  const NotesNoteImportPreview(this.draft);

  final NotesNoteImportDraft draft;
}

class NotesHistoryImportPreview extends NotesClipboardImportPreview {
  const NotesHistoryImportPreview(this.draft);

  final NotesHistoryImportDraft draft;
}

/// 中文：**这一次剪贴板导入计划说的是哪件事——它既是判据，也是呈现层取那句话用的令牌。**
///
///       三格与 `NotesStrings` 里的三格一一对应（`importClipboardEmpty` / `importNothingRecognised` /
///       `importWillImport`），由 `notesImportPlanSummary(plan, strings)` 那个穷尽 `switch` 接上；
///       计数（[NotesClipboardImportPlan.historyCount] / `noteCount` / `skippedBlockCount`）是
///       **载荷**，留在计划上由呈现层拼进句子。
///
///       **这三句话从前是在这里拼的**（`get summary`，直接印在导入对话框与 `SnackBar` 上）：
///       领域对象活得比界面长，界面那张按语言切的文案表够不着它，所以英文界面下它照样是中文——
///       `docs/verification.md` §5i 记着这条层次性缺陷。形状照的是已经转过的两条路径
///       （`CalculatorSubmitStatus` + `calculatorSubmitMessage`、`CalculatorSaveNoteStatus` +
///       `calculatorSaveNoteMessage`）。
///
///       **判据与文案是同一个字段**：这一格回答「计划属于哪一种」，句子由它决定，两者不可能对不上。
/// English: **which thing this clipboard-import plan says — a verdict, and the token the presentation
///          layer resolves the sentence with.**
///
///          The three values correspond one for one with three cells in `NotesStrings`
///          (`importClipboardEmpty` / `importNothingRecognised` / `importWillImport`), wired up by the
///          exhaustive `switch` in `notesImportPlanSummary(plan, strings)`; the counts
///          ([NotesClipboardImportPlan.historyCount] / `noteCount` / `skippedBlockCount`) are
///          **payload** and stay on the plan for the presentation layer to splice into the sentence.
///
///          **Those three sentences used to be composed right here** (`get summary`, printed straight
///          into the import dialog and a `SnackBar`): a domain object outlives the UI and a
///          language-keyed copy table cannot reach it, so an English interface still printed Chinese —
///          the layering defect recorded in `docs/verification.md` §5i. The shape is the one the two
///          converted paths already use (`CalculatorSubmitStatus` + `calculatorSubmitMessage`,
///          `CalculatorSaveNoteStatus` + `calculatorSaveNoteMessage`).
///
///          **Verdict and wording are one field**: this value answers "which kind of plan is this", the
///          sentence follows from it, so the two cannot disagree.
enum NotesImportPlanStatus {
  clipboardEmpty,
  nothingRecognised,
  willImport,
}

/// 中文：**这一次导入回执的头部说的是哪件事**（真的写进去了东西 / 一条都没写）。
///
///       两格与 `NotesStrings` 的 `imported` / `importNothingNew` 一一对应，由
///       `notesImportMessage(result, strings)` 的穷尽 `switch` 接上；「跳过 N 段无法识别内容」与
///       「未写入 N 条」两根尾巴是载荷，由那个函数按计数拼上去。与 [NotesImportPlanStatus] 同一条
///       理由：从前这两句话也是在这里拼的（`get importedMessage`）。
/// English: **which thing this import receipt's head says** (something really was written / not one
///          record).
///
///          The two values correspond one for one with `NotesStrings`'s `imported` /
///          `importNothingNew`, wired up by the exhaustive `switch` in
///          `notesImportMessage(result, strings)`; the "skipped N unrecognised blocks" and
///          "N not written" tails are payload, appended by that function from the counts. The same
///          reasoning as [NotesImportPlanStatus]: those two sentences used to be composed here too
///          (`get importedMessage`).
enum NotesImportReceiptStatus {
  imported,
  nothingNew,
}

class NotesClipboardImportPlan {
  const NotesClipboardImportPlan({
    required this.noteDrafts,
    required this.historyDrafts,
    required this.skippedBlockCount,
    required this.fromBatchExport,
    required this.sourceTextEmpty,
  });

  final List<NotesNoteImportDraft> noteDrafts;
  final List<NotesHistoryImportDraft> historyDrafts;
  final int skippedBlockCount;
  final bool fromBatchExport;
  final bool sourceTextEmpty;

  int get noteCount => noteDrafts.length;

  int get historyCount => historyDrafts.length;

  int get totalCount => noteCount + historyCount;

  bool get canImport => totalCount > 0;

  /// 中文：导入对话框那几行预览**说的是哪几条草稿**——顺序与迁移前一致（先历史、后笔记）。
  ///       句子不在这里拼：这一格只回答"这一行是哪条草稿"，字由呈现边缘按语言取（见
  ///       [NotesClipboardImportPreview]）。
  /// English: **which drafts the import dialog's preview rows are about** — the same order as before
  ///          the move (histories first, then notes). The sentences are not composed here: this getter
  ///          answers only "which draft is this row", and the words are fetched at the presentation
  ///          edge in the active language (see [NotesClipboardImportPreview]).
  List<NotesClipboardImportPreview> get previews => [
        ...historyDrafts.map(NotesHistoryImportPreview.new),
        ...noteDrafts.map(NotesNoteImportPreview.new),
      ];

  /// 中文：**这个计划属于三种结局里的哪一种**（见 [NotesImportPlanStatus]）。顺序是判据的一部分：
  ///       「剪贴板是空的」压过「没认出可导入的东西」——从前的 `if (sourceTextEmpty)` 就写在前头，
  ///       这一格把那个优先级写成一张表，将来多一种结局时呈现层那个 `switch` 编译不过。
  /// English: **which of the three outcomes this plan is** (see [NotesImportPlanStatus]). The order is
  ///          part of the verdict: "the clipboard is empty" outranks "nothing importable was
  ///          recognised" — the old `if (sourceTextEmpty)` stood first — and this value writes that
  ///          precedence down as a table, so adding an outcome breaks the presentation `switch` at
  ///          compile time.
  NotesImportPlanStatus get status {
    if (sourceTextEmpty) return NotesImportPlanStatus.clipboardEmpty;
    if (!canImport) return NotesImportPlanStatus.nothingRecognised;
    return NotesImportPlanStatus.willImport;
  }
}

class NotesClipboardImportResult {
  const NotesClipboardImportResult({
    required this.plan,
    required this.historyIds,
    required this.noteIds,
    this.skippedHistoryWrites = 0,
    this.skippedNoteWrites = 0,
  });

  factory NotesClipboardImportResult.empty(NotesClipboardImportPlan plan) {
    return NotesClipboardImportResult(
      plan: plan,
      historyIds: const [],
      noteIds: const [],
    );
  }

  final NotesClipboardImportPlan plan;
  final List<int> historyIds;
  final List<int> noteIds;
  final int skippedHistoryWrites;
  final int skippedNoteWrites;

  int get historyCount => historyIds.length;

  int get noteCount => noteIds.length;

  int get totalCount => historyCount + noteCount;

  int get skippedWriteCount => skippedHistoryWrites + skippedNoteWrites;

  bool get hasImportedRecords => totalCount > 0;

  /// 中文：**这一次导入的头部结局**：`imported`（真的写进去了东西）与 `nothingNew`（一条都没写）。
  ///       从前这里是 `get importedMessage`，那两句话就住在这个文件里、直接印在 `SnackBar` 上。
  /// English: **the head outcome of this import**: `imported` (something really was written) and
  ///          `nothingNew` (not one record). This used to be `get importedMessage`, whose sentences
  ///          lived in this very file and were printed straight into a `SnackBar`.
  NotesImportReceiptStatus get receiptStatus => hasImportedRecords
      ? NotesImportReceiptStatus.imported
      : NotesImportReceiptStatus.nothingNew;
}

NotesClipboardImportPlan buildNotesClipboardImportPlan(String text) {
  final normalized = _normalizeNewlines(text).trim();
  if (normalized.isEmpty) {
    return const NotesClipboardImportPlan(
      noteDrafts: [],
      historyDrafts: [],
      skippedBlockCount: 0,
      fromBatchExport: false,
      sourceTextEmpty: true,
    );
  }

  final blocks = _splitExportBlocks(normalized);
  final fromBatchExport = blocks
      .any((block) => _firstOrNull(_nonEmptyLines(block)) == _batchHeader);
  final noteDrafts = <NotesNoteImportDraft>[];
  final historyDrafts = <NotesHistoryImportDraft>[];
  var skippedBlockCount = 0;

  for (final block in blocks) {
    final lines = _nonEmptyLines(block);
    if (lines.isEmpty) continue;
    if (lines.first == _batchHeader) continue;

    final noteDraft = _parseNoteBlock(block);
    if (noteDraft != null) {
      noteDrafts.add(noteDraft);
      continue;
    }

    final historyDraft = _parseHistoryBlock(block);
    if (historyDraft != null) {
      historyDrafts.add(historyDraft);
      continue;
    }

    skippedBlockCount++;
  }

  if (noteDrafts.isEmpty && historyDrafts.isEmpty && !fromBatchExport) {
    noteDrafts.add(_plainTextDraft(normalized));
    skippedBlockCount = 0;
  }

  return NotesClipboardImportPlan(
    noteDrafts: noteDrafts,
    historyDrafts: historyDrafts,
    skippedBlockCount: skippedBlockCount,
    fromBatchExport: fromBatchExport,
    sourceTextEmpty: false,
  );
}

const _batchHeader = 'NekoCalc 批量导出';
final DateFormat _exportDateFormat = DateFormat('yyyy/MM/dd HH:mm');

String _normalizeNewlines(String value) {
  return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

List<String> _splitExportBlocks(String value) {
  return value
      .split(RegExp(r'\n\s*---\s*\n'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty)
      .toList(growable: false);
}

List<String> _nonEmptyLines(String value) {
  return value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

NotesNoteImportDraft? _parseNoteBlock(String block) {
  final lines = _normalizeNewlines(block).split('\n');
  final firstContentIndex = _firstNonEmptyLineIndex(lines);
  if (firstContentIndex == null ||
      !lines[firstContentIndex].trimLeft().startsWith('笔记:')) {
    return null;
  }

  final title = _afterLabel(lines[firstContentIndex], '笔记:').trim();
  var description = '';
  var index = firstContentIndex + 1;

  while (index < lines.length) {
    final trimmed = lines[index].trim();
    if (trimmed.isEmpty) {
      index++;
      break;
    }
    if (trimmed.startsWith('描述:')) {
      description = _afterLabel(trimmed, '描述:').trim();
      index++;
      continue;
    }
    if (trimmed.startsWith('创建时间:') || trimmed.startsWith('更新时间:')) {
      index++;
      continue;
    }
    break;
  }

  return NotesNoteImportDraft(
    // 中文：**标题为空时不再在这里兜底**：`'导入笔记'` 那句话是给用户看的，改由保存边缘按语言取
    //       （见 [NotesNoteDraftWording]）。这里留下的是用户写下的原文（可能是空串）。
    // English: **an empty title is no longer patched up here**: that `'导入笔记'` sentence is
    //          user-facing, so the save edge fetches it in the active language (see
    //          [NotesNoteDraftWording]). What stays is what the user wrote (possibly an empty string).
    wording: NotesNoteDraftWording.parsed,
    title: title,
    description: description,
    body: lines.skip(index).join('\n').trim(),
  );
}

NotesHistoryImportDraft? _parseHistoryBlock(String block) {
  final lines = _nonEmptyLines(block);
  if (lines.isEmpty) return null;

  final header = lines.first;
  final isToolHistory = header.startsWith('工具历史:');
  final isCalculationHistory = header == '计算历史';
  if (!isToolHistory && !isCalculationHistory) return null;

  final expression = _labeledValue(lines, '表达式:');
  final result = _labeledValue(lines, '结果:');
  if (expression == null ||
      expression.isEmpty ||
      result == null ||
      result.isEmpty) {
    return null;
  }

  final sourceTimeLabel = _labeledValue(lines, '时间:');
  return NotesHistoryImportDraft(
    expression: expression,
    result: result,
    toolId: isToolHistory ? _afterLabel(header, '工具历史:').trim() : null,
    createdAt: _parseExportDate(sourceTimeLabel),
    sourceTimeLabel: sourceTimeLabel == null || sourceTimeLabel.isEmpty
        ? null
        : sourceTimeLabel,
  );
}

NotesNoteImportDraft _plainTextDraft(String text) {
  // 中文：**这里只剩载荷**：首行原文与正文。标题那句话（`'剪贴板笔记 · …'`）、没有首行时的兜底
  //       （`'剪贴板内容'`）与 24 个字符的截断都由保存边缘按语言取（见 [NotesNoteDraftWording] 与
  //       `notesNoteDraftTitle`）。首行取不到时留空串——`_nonEmptyLines` 不会给出空串，所以空串
  //       在这里只可能是"没有首行"。
  // English: **only the payload is left here**: the first line and the body. The title sentence
  //          (`'剪贴板笔记 · …'`), the fallback for a missing first line (`'剪贴板内容'`) and the
  //          24-character truncation are all fetched at the save edge in the active language (see
  //          [NotesNoteDraftWording] and `notesNoteDraftTitle`). A missing first line becomes an empty
  //          string — `_nonEmptyLines` never yields an empty one, so emptiness can only mean "no first
  //          line".
  return NotesNoteImportDraft(
    wording: NotesNoteDraftWording.clipboard,
    title: _firstOrNull(_nonEmptyLines(text)) ?? '',
    description: '',
    body: text.trim(),
  );
}

DateTime? _parseExportDate(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return _exportDateFormat.parseStrict(value);
  } on FormatException {
    return null;
  }
}

T? _firstOrNull<T>(List<T> values) {
  return values.isEmpty ? null : values.first;
}

int? _firstNonEmptyLineIndex(List<String> lines) {
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim().isNotEmpty) return i;
  }
  return null;
}

String _afterLabel(String line, String label) {
  return line.trimLeft().substring(label.length).trim();
}

String? _labeledValue(List<String> lines, String label) {
  for (final line in lines) {
    if (line.startsWith(label)) return _afterLabel(line, label);
  }
  return null;
}
