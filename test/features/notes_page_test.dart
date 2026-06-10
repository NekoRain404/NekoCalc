import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/models/note_item.dart';
import 'package:nekocalc/features/notes/presentation/notes_page.dart';

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('external reload clears stale selection and reloads records',
      (tester) async {
    final db = _FakeNotesDatabase(
      historyItems: [
        HistoryItem(
          id: 1,
          expression: '2+3',
          result: '5',
          createdAt: DateTime(2026, 6, 9, 10),
        ),
      ],
    );

    await tester.pumpWidget(_testApp(NotesPage(db: db)));
    await tester.pumpAndSettle();

    expect(find.text('2+3'), findsOneWidget);

    await tester.longPress(find.text('2+3'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsOneWidget);

    db.historyItems = const [];
    await tester.pumpWidget(_testApp(NotesPage(db: db, reloadToken: 1)));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsNothing);
    expect(find.text('2+3'), findsNothing);
    expect(find.text('暂无历史记录。'), findsOneWidget);
  });

  testWidgets('search changes clear active selection', (tester) async {
    final db = _FakeNotesDatabase(
      historyItems: [
        HistoryItem(
          id: 1,
          expression: '2+3',
          result: '5',
          createdAt: DateTime(2026, 6, 9, 10),
        ),
        HistoryItem(
          id: 2,
          expression: 'sqrt(9)',
          result: '3',
          createdAt: DateTime(2026, 6, 9, 11),
        ),
      ],
    );

    await tester.pumpWidget(_testApp(NotesPage(db: db)));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('2+3'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 项'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'sqrt');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsNothing);
    expect(find.text('sqrt(9)'), findsOneWidget);
    expect(find.text('2+3'), findsNothing);
  });

  testWidgets('empty search offers record typo suggestions', (tester) async {
    final db = _FakeNotesDatabase(
      historyItems: [
        HistoryItem(
          id: 1,
          expression: 'sqrt(9)',
          result: '3',
          createdAt: DateTime(2026, 6, 9, 11),
        ),
      ],
      noteItems: [
        NoteItem(
          id: 7,
          title: '实验记录',
          description: '电路校核',
          body: 'V = I * R',
          createdAt: DateTime(2026, 6, 9, 9),
          updatedAt: DateTime(2026, 6, 9, 9, 30),
        ),
      ],
    );

    await tester.pumpWidget(_testApp(NotesPage(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'sqqrt');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.text('当前筛选下没有历史记录。'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'sqrt'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'sqrt').first);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.text('sqrt(9)'), findsOneWidget);
    expect(find.text('当前筛选下没有历史记录。'), findsNothing);
  });

  testWidgets('tab changes clear active selection', (tester) async {
    final db = _FakeNotesDatabase(
      historyItems: [
        HistoryItem(
          id: 1,
          expression: '2+3',
          result: '5',
          createdAt: DateTime(2026, 6, 9, 10),
        ),
      ],
      noteItems: [
        NoteItem(
          id: 7,
          title: '实验记录',
          description: '电路校核',
          body: 'V = I * R',
          createdAt: DateTime(2026, 6, 9, 9),
          updatedAt: DateTime(2026, 6, 9, 9, 30),
        ),
      ],
    );

    await tester.pumpWidget(_testApp(NotesPage(db: db)));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('2+3'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 项'), findsOneWidget);

    await tester.tap(find.text('笔记').first);
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsNothing);
    expect(find.text('实验记录'), findsOneWidget);
    expect(find.text('2+3'), findsNothing);
  });

  testWidgets('select visible toggles current visible selection',
      (tester) async {
    final db = _FakeNotesDatabase(
      historyItems: [
        HistoryItem(
          id: 1,
          expression: '2+3',
          result: '5',
          createdAt: DateTime(2026, 6, 9, 10),
        ),
        HistoryItem(
          id: 2,
          expression: 'sqrt(9)',
          result: '3',
          createdAt: DateTime(2026, 6, 9, 11),
        ),
      ],
      noteItems: [
        NoteItem(
          id: 7,
          title: '实验记录',
          description: '电路校核',
          body: 'V = I * R',
          createdAt: DateTime(2026, 6, 9, 9),
          updatedAt: DateTime(2026, 6, 9, 9, 30),
        ),
      ],
    );

    await tester.pumpWidget(_testApp(NotesPage(db: db)));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('2+3'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 项'), findsOneWidget);

    await tester.tap(find.byTooltip('选择当前列表'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 3 项'), findsOneWidget);

    await tester.tap(find.byTooltip('选择当前列表'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 3 项'), findsNothing);
    expect(find.text('已选择 1 项'), findsNothing);
    expect(find.byTooltip('新增笔记'), findsOneWidget);
  });

  testWidgets('deleting mixed selection reloads records once', (tester) async {
    final db = _FakeNotesDatabase(
      historyItems: [
        HistoryItem(
          id: 1,
          expression: '2+3',
          result: '5',
          createdAt: DateTime(2026, 6, 9, 10),
        ),
      ],
      noteItems: [
        NoteItem(
          id: 7,
          title: '实验记录',
          description: '电路校核',
          body: 'V = I * R',
          createdAt: DateTime(2026, 6, 9, 9),
          updatedAt: DateTime(2026, 6, 9, 9, 30),
        ),
      ],
    );

    await tester.pumpWidget(_testApp(NotesPage(db: db)));
    await tester.pumpAndSettle();
    expect(db.historyLoads, 1);
    expect(db.noteLoads, 1);

    await tester.longPress(find.text('2+3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('选择当前列表'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 2 项'), findsOneWidget);

    await tester.tap(find.byTooltip('删除所选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(db.deletedHistoryIds, [1]);
    expect(db.deletedNoteIds, [7]);
    expect(db.historyLoads, 2);
    expect(db.noteLoads, 2);
    expect(find.text('2+3'), findsNothing);
    expect(find.text('实验记录'), findsNothing);
    expect(find.text('已删除 1 条历史、1 条笔记'), findsOneWidget);
  });

  testWidgets('external reload cancels pending debounced search',
      (tester) async {
    final db = _FakeNotesDatabase(
      historyItems: [
        HistoryItem(
          id: 1,
          expression: '2+3',
          result: '5',
          createdAt: DateTime(2026, 6, 9, 10),
        ),
        HistoryItem(
          id: 2,
          expression: 'sqrt(9)',
          result: '3',
          createdAt: DateTime(2026, 6, 9, 11),
        ),
      ],
    );

    await tester.pumpWidget(_testApp(NotesPage(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'sqrt');
    await tester.pump(const Duration(milliseconds: 20));

    await tester.pumpWidget(_testApp(NotesPage(db: db, reloadToken: 1)));
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();

    expect(find.text('2+3'), findsOneWidget);
    expect(find.text('sqrt(9)'), findsOneWidget);
    expect(find.textContaining('搜索“sqrt”'), findsNothing);
  });

  testWidgets('clipboard import previews and creates history plus notes',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return Future.value({
          'text': '''
NekoCalc 批量导出
历史: 1 条
笔记: 1 条

---

计算历史
表达式: 2+3
结果: 5
时间: 2026/06/08 09:30

---

笔记: 实验记录
描述: 电路校核
创建时间: 2026/06/07 18:00
更新时间: 2026/06/08 08:20

V = I * R
''',
        });
      }
      return null;
    });
    final db = _FakeNotesDatabase();

    await tester.pumpWidget(_testApp(NotesPage(db: db)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('从剪贴板导入'));
    await tester.pumpAndSettle();

    expect(find.text('从剪贴板导入'), findsOneWidget);
    expect(find.text('将导入 1 条历史、1 条笔记'), findsOneWidget);
    expect(find.text('计算历史 · 2+3'), findsOneWidget);
    expect(find.text('实验记录'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await tester.pumpAndSettle();

    expect(db.createdHistory, hasLength(1));
    expect(db.createdHistory.single.expression, '2+3');
    expect(db.createdHistory.single.result, '5');
    expect(db.createdHistory.single.createdAt, DateTime(2026, 6, 8, 9, 30));
    expect(db.createdNotes, hasLength(1));
    expect(db.createdNotes.single.title, '实验记录');
    expect(find.text('2+3'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('V = I * R'), findsOneWidget);
    expect(find.text('已导入 1 条历史、1 条笔记'), findsOneWidget);
  });

  testWidgets('clipboard import snackbar reports skipped repository writes',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return Future.value({
          'text': '''
NekoCalc 批量导出
历史: 1 条
笔记: 1 条

---

计算历史
表达式: 2+3
结果: 5

---

笔记: 实验记录

V = I * R
''',
        });
      }
      return null;
    });
    final db = _FakeNotesDatabase(zeroNextHistoryWrite: true);

    await tester.pumpWidget(_testApp(NotesPage(db: db)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('从剪贴板导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await tester.pumpAndSettle();

    expect(db.createdHistory, isEmpty);
    expect(db.createdNotes, hasLength(1));
    expect(find.text('2+3'), findsNothing);
    expect(find.text('V = I * R'), findsOneWidget);
    expect(find.text('已导入 1 条笔记，未写入 1 条'), findsOneWidget);
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

class _FakeNotesDatabase implements AppDatabase {
  _FakeNotesDatabase({
    List<HistoryItem> historyItems = const [],
    List<NoteItem> noteItems = const [],
    this.zeroNextHistoryWrite = false,
  })  : historyItems = List<HistoryItem>.from(historyItems),
        noteItems = List<NoteItem>.from(noteItems);

  List<HistoryItem> historyItems;
  List<NoteItem> noteItems;
  bool zeroNextHistoryWrite;
  int historyLoads = 0;
  int noteLoads = 0;
  int _nextHistoryId = 50;
  int _nextNoteId = 100;
  final List<int> deletedHistoryIds = [];
  final List<int> deletedNoteIds = [];
  final List<_CreatedHistory> createdHistory = [];
  final List<_CreatedNote> createdNotes = [];

  @override
  Future<List<HistoryItem>> history({
    int limit = 50,
    int offset = 0,
    String? query,
    String? toolId,
  }) async {
    historyLoads++;
    return historyItems;
  }

  @override
  Future<List<NoteItem>> notes({
    int limit = 200,
    int offset = 0,
    String? query,
  }) async {
    noteLoads++;
    return noteItems;
  }

  @override
  Future<int> addNote(String title, String body,
      {String description = ''}) async {
    final id = _nextNoteId++;
    createdNotes.add(_CreatedNote(
      title: title,
      description: description,
      body: body,
    ));
    final now = DateTime(2026, 6, 10, 9, id % 60);
    noteItems.add(NoteItem(
      id: id,
      title: title,
      description: description,
      body: body,
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  @override
  Future<int> addHistory({
    required String expression,
    required String result,
    String? toolId,
    DateTime? createdAt,
  }) async {
    if (zeroNextHistoryWrite) {
      zeroNextHistoryWrite = false;
      return 0;
    }
    final id = _nextHistoryId++;
    final timestamp = createdAt ?? DateTime(2026, 6, 10, 8, id % 60);
    createdHistory.add(_CreatedHistory(
      expression: expression,
      result: result,
      toolId: toolId,
      createdAt: timestamp,
    ));
    historyItems.add(HistoryItem(
      id: id,
      expression: expression,
      result: result,
      toolId: toolId,
      createdAt: timestamp,
    ));
    return id;
  }

  @override
  Future<int> deleteHistoryItems(Iterable<int> ids) async {
    final normalized = ids.toList(growable: false);
    deletedHistoryIds.addAll(normalized);
    final before = historyItems.length;
    historyItems.removeWhere((item) => normalized.contains(item.id));
    return before - historyItems.length;
  }

  @override
  Future<int> deleteNotes(Iterable<int> ids) async {
    final normalized = ids.toList(growable: false);
    deletedNoteIds.addAll(normalized);
    final before = noteItems.length;
    noteItems.removeWhere((item) => normalized.contains(item.id));
    return before - noteItems.length;
  }

  @override
  Future<int> deleteHistory(int id) => deleteHistoryItems([id]);

  @override
  Future<int> deleteNote(int id) => deleteNotes([id]);

  @override
  Future<int> clearHistory() async {
    final deleted = historyItems.length;
    historyItems.clear();
    return deleted;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CreatedHistory {
  const _CreatedHistory({
    required this.expression,
    required this.result,
    required this.toolId,
    required this.createdAt,
  });

  final String expression;
  final String result;
  final String? toolId;
  final DateTime createdAt;
}

class _CreatedNote {
  const _CreatedNote({
    required this.title,
    required this.description,
    required this.body,
  });

  final String title;
  final String description;
  final String body;
}
