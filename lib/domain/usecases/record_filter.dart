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
