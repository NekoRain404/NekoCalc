import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/models/note_item.dart';
import 'package:nekocalc/domain/usecases/record_filter.dart';

void main() {
  final now = DateTime(2026, 5, 12);

  test('classifies tool history by tool id', () {
    final item = HistoryItem(
      id: 1,
      expression: 'R=10, I=2',
      result: '电压 V: 20V',
      toolId: 'ohms_law',
      createdAt: now,
    );

    expect(matchesHistoryRecord(item, RecordTab.tools), isTrue);
  });

  test('classifies formula notes by content', () {
    final item = NoteItem(
      id: 1,
      title: '二次方程公式',
      description: '公式推导',
      body: 'x = (-b ± sqrt(b² - 4ac)) / 2a',
      createdAt: now,
      updatedAt: now,
    );

    expect(matchesNoteRecord(item, RecordTab.formulas), isTrue);
    expect(matchesNoteRecord(item, RecordTab.tools), isFalse);
  });
}
