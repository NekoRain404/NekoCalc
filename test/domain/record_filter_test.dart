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

  test('matches note query against description', () {
    final item = NoteItem(
      id: 2,
      title: '实验记录',
      description: '包含数据拟合和误差分析',
      body: 'y = ax + b',
      createdAt: now,
      updatedAt: now,
    );

    expect(matchesNoteQuery(item, '数据拟合'), isTrue);
    expect(matchesNoteQuery(item, '误差'), isTrue);
    expect(matchesNoteQuery(item, '不存在'), isFalse);
  });

  test('matches record queries by multiple tokens and dates', () {
    final history = HistoryItem(
      id: 3,
      expression: '电流=2A, 电阻=5Ω',
      result: '电压: 10V',
      toolId: 'ohms_law',
      createdAt: DateTime(2026, 5, 12, 9, 30),
    );
    final note = NoteItem(
      id: 4,
      title: '实验记录',
      description: '电路校核',
      body: '误差分析和数据拟合',
      createdAt: DateTime(2026, 5, 11, 18),
      updatedAt: DateTime(2026, 5, 12, 8, 20),
    );

    expect(matchesHistoryQuery(history, 'ohms 电压 2026-05-12'), isTrue);
    expect(matchesHistoryQuery(history, '电流,09:30'), isTrue);
    expect(matchesHistoryQuery(history, 'ohms 不存在'), isFalse);

    expect(matchesNoteQuery(note, '实验 误差 20260512'), isTrue);
    expect(matchesNoteQuery(note, '电路；08:20'), isTrue);
    expect(matchesNoteQuery(note, '实验 09:30'), isFalse);
  });

  test('matches pasted reports and normalized symbols in queries', () {
    final history = HistoryItem(
      id: 5,
      expression: '电流=2A, 电阻=5Ω',
      result: '电压: 10V',
      toolId: 'ohms_law',
      createdAt: DateTime(2026, 5, 12, 9, 30),
    );
    final note = NoteItem(
      id: 6,
      title: '圆周率估算',
      description: '公式记录',
      body: '2π + √9 = 9.283185',
      createdAt: DateTime(2026, 5, 11, 18),
      updatedAt: DateTime(2026, 5, 12, 8, 20),
    );

    expect(
      matchesHistoryQuery(
        history,
        '''
工具历史: ohms_law
表达式: 电阻=5ohm
结果: 电压
时间: 2026年5月12日
''',
      ),
      isTrue,
    );
    expect(matchesHistoryQuery(history, '电流＝２a 5ohm'), isTrue);

    expect(matchesNoteQuery(note, '公式: 2pi sqrt9'), isTrue);
    expect(matchesNoteQuery(note, '圆周率 2026年5月12日'), isTrue);
  });
}
