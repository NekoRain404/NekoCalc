import 'package:intl/intl.dart';

class NotesNoteImportDraft {
  const NotesNoteImportDraft({
    required this.title,
    required this.description,
    required this.body,
    required this.source,
  });

  final String title;
  final String description;
  final String body;
  final NotesImportSource source;
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

  String get previewTitle {
    final prefix = toolId == null ? '计算历史' : '工具历史';
    return '$prefix · ${_truncateSingleLine(expression, 30)}';
  }

  String get previewDescription {
    final parts = <String>[
      if (toolId != null) '工具 $toolId',
      if (sourceTimeLabel != null) '原时间 $sourceTimeLabel',
    ];
    return parts.join(' · ');
  }
}

class NotesClipboardImportPreview {
  const NotesClipboardImportPreview({
    required this.title,
    required this.description,
    required this.source,
  });

  final String title;
  final String description;
  final NotesImportSource source;
}

enum NotesImportSource {
  note,
  history,
  plainText,
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

  List<NotesClipboardImportPreview> get previews => [
        ...historyDrafts.map(
          (draft) => NotesClipboardImportPreview(
            title: draft.previewTitle,
            description: draft.previewDescription,
            source: NotesImportSource.history,
          ),
        ),
        ...noteDrafts.map(
          (draft) => NotesClipboardImportPreview(
            title: draft.title,
            description: draft.description,
            source: draft.source,
          ),
        ),
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
    title: title.isEmpty ? '导入笔记' : title,
    description: description,
    body: lines.skip(index).join('\n').trim(),
    source: NotesImportSource.note,
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
  final firstLine = _firstOrNull(_nonEmptyLines(text)) ?? '剪贴板内容';
  return NotesNoteImportDraft(
    title: '剪贴板笔记 · ${_truncateSingleLine(firstLine, 24)}',
    description: '从剪贴板导入的文本',
    body: text.trim(),
    source: NotesImportSource.plainText,
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

String _truncateSingleLine(String value, int maxLength) {
  final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.length <= maxLength) return singleLine;
  return '${singleLine.substring(0, maxLength - 1)}...';
}
