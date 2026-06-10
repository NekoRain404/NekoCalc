import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/models/note_item.dart';
import 'package:nekocalc/domain/usecases/record_filter.dart';
import 'package:nekocalc/domain/usecases/record_search_suggestions.dart';

void main() {
  test('suggestions recover typos from visible history and notes', () {
    final history = [
      HistoryItem(
        id: 1,
        expression: 'sqrt(9)',
        result: '3',
        createdAt: DateTime(2026, 6, 9, 10),
      ),
      HistoryItem(
        id: 2,
        expression: '电流=2A, 电阻=5Ω',
        result: '电压: 10V',
        toolId: 'ohms_law',
        createdAt: DateTime(2026, 6, 9, 11),
      ),
    ];
    final notes = [
      NoteItem(
        id: 7,
        title: '实验记录',
        description: '电路校核',
        body: 'V = I * R',
        createdAt: DateTime(2026, 6, 9, 9),
        updatedAt: DateTime(2026, 6, 9, 9, 30),
      ),
    ];

    final sqrtSuggestions = buildRecordSearchSuggestions(
      query: 'sqqrt',
      history: history,
      notes: notes,
    );
    final scopedSuggestions = buildRecordSearchSuggestions(
      query: 'ohms lqw',
      history: history,
      notes: notes,
      tab: RecordTab.tools,
    );

    expect(sqrtSuggestions.map((item) => item.text), contains('sqrt'));
    expect(scopedSuggestions.map((item) => item.text), contains('ohms law'));
  });

  test('suggestions are empty for short queries and real matches', () {
    final history = [
      HistoryItem(
        id: 1,
        expression: 'sqrt(9)',
        result: '3',
        createdAt: DateTime(2026, 6, 9, 10),
      ),
    ];

    expect(
      buildRecordSearchSuggestions(
        query: 'sq',
        history: history,
        notes: const [],
      ),
      isEmpty,
    );
    expect(
      buildRecordSearchSuggestions(
        query: 'sqrt',
        history: history,
        notes: const [],
      ),
      isEmpty,
    );
  });
}
