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

  String get summary {
    if (sourceTextEmpty) return '剪贴板没有文本内容';
    if (!canImport) return '未识别到可导入的笔记或历史导出';
    final parts = <String>['将导入 ${_countLabel()}'];
    if (skippedBlockCount > 0) parts.add('跳过 $skippedBlockCount 段无法识别内容');
    return parts.join('，');
  }

  String get importedMessage {
    final parts = <String>['已导入 ${_countLabel()}'];
    if (skippedBlockCount > 0) parts.add('跳过 $skippedBlockCount 段');
    return parts.join('，');
  }

  String _countLabel() {
    final parts = <String>[
      if (historyCount > 0) '$historyCount 条历史',
      if (noteCount > 0) '$noteCount 条笔记',
    ];
    return parts.join('、');
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

  String get importedMessage {
    final parts = <String>[
      hasImportedRecords ? '已导入 ${_countLabel()}' : '没有导入新内容',
    ];
    if (plan.skippedBlockCount > 0) {
      parts.add('跳过 ${plan.skippedBlockCount} 段无法识别内容');
    }
    if (skippedWriteCount > 0) {
      parts.add('未写入 $skippedWriteCount 条');
    }
    return parts.join('，');
  }

  String _countLabel() {
    final parts = <String>[
      if (historyCount > 0) '$historyCount 条历史',
      if (noteCount > 0) '$noteCount 条笔记',
    ];
    return parts.join('、');
  }
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
