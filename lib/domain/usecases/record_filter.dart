import '../../data/models/history_item.dart';
import '../../data/models/note_item.dart';

enum RecordTab { all, notes, history, formulas, tools }

bool matchesHistoryRecord(HistoryItem item, RecordTab tab) {
  if (tab == RecordTab.tools) {
    return item.toolId != null ||
        item.expression.contains('=') ||
        item.result.contains(':');
  }
  if (tab == RecordTab.formulas) {
    return item.expression.contains('sin') ||
        item.expression.contains('sqrt') ||
        item.expression.contains('公式');
  }
  return true;
}

bool matchesNoteRecord(NoteItem item, RecordTab tab) {
  if (tab == RecordTab.tools) {
    return item.body.contains('公式：') ||
        item.description.contains('工具') ||
        item.title.contains('计算');
  }
  if (tab == RecordTab.formulas) {
    return item.title.contains('公式') ||
        item.description.contains('公式') ||
        item.body.contains('=');
  }
  return true;
}

bool matchesHistoryQuery(HistoryItem item, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return item.expression.toLowerCase().contains(normalized) ||
      item.result.toLowerCase().contains(normalized) ||
      (item.toolId?.toLowerCase().contains(normalized) ?? false);
}

bool matchesNoteQuery(NoteItem item, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return item.title.toLowerCase().contains(normalized) ||
      item.description.toLowerCase().contains(normalized) ||
      item.body.toLowerCase().contains(normalized);
}
