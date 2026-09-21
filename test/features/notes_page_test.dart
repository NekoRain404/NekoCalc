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

  _wiringTests();

  testWidgets('external reload clears stale selection and reloads records',
      (tester) async {
    final db = _FakeNotesDatabase(
      historyItems: [
        HistoryItem(
          id: 1,
          expression: '2+3',
          result: '5',
          resultKind: HistoryResultKind.number,
          createdAt: DateTime(2026, 6, 9, 10),
        ),
      ],
    );

    await tester.pumpWidget(_testApp(NotesPage(db: db, toolResultLabel: _identityLabel)));
    await tester.pumpAndSettle();

    expect(find.text('2+3'), findsOneWidget);

    await tester.longPress(find.text('2+3'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsOneWidget);

    db.historyItems = const [];
    await tester.pumpWidget(_testApp(NotesPage(db: db, reloadToken: 1, toolResultLabel: _identityLabel)));
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
          resultKind: HistoryResultKind.number,
          createdAt: DateTime(2026, 6, 9, 10),
        ),
        HistoryItem(
          id: 2,
          expression: 'sqrt(9)',
          result: '3',
          resultKind: HistoryResultKind.number,
          createdAt: DateTime(2026, 6, 9, 11),
        ),
      ],
    );

    await tester.pumpWidget(_testApp(NotesPage(db: db, toolResultLabel: _identityLabel)));
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
          resultKind: HistoryResultKind.number,
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

    await tester.pumpWidget(_testApp(NotesPage(db: db, toolResultLabel: _identityLabel)));
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

  testWidgets('formula tab can load later pages when its first page is empty',
      (tester) async {
    final notes = List.generate(
      101,
      (index) => NoteItem(
        id: index + 1,
        title: index == 100 ? '目标公式' : '普通笔记 ${index + 1}',
        description: '',
        body: index == 100 ? 'x = y' : '普通内容',
        createdAt: DateTime(2026, 6, 9, 9),
        updatedAt: DateTime(2026, 6, 9, 9),
      ),
    );
    final db = _FakeNotesDatabase(noteItems: notes);

    await tester.pumpWidget(_testApp(NotesPage(db: db, toolResultLabel: _identityLabel)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('公式').first);
    await tester.pumpAndSettle();

    expect(find.text('暂无个人笔记。'), findsOneWidget);
    expect(find.text('加载更多笔记'), findsOneWidget);

    await tester.tap(find.text('加载更多笔记'));
    await tester.pumpAndSettle();

    expect(find.text('目标公式'), findsOneWidget);
  });

  testWidgets('tab changes clear active selection', (tester) async {
    final db = _FakeNotesDatabase(
      historyItems: [
        HistoryItem(
          id: 1,
          expression: '2+3',
          result: '5',
          resultKind: HistoryResultKind.number,
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

    await tester.pumpWidget(_testApp(NotesPage(db: db, toolResultLabel: _identityLabel)));
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
          resultKind: HistoryResultKind.number,
          createdAt: DateTime(2026, 6, 9, 10),
        ),
        HistoryItem(
          id: 2,
          expression: 'sqrt(9)',
          result: '3',
          resultKind: HistoryResultKind.number,
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

    await tester.pumpWidget(_testApp(NotesPage(db: db, toolResultLabel: _identityLabel)));
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
          resultKind: HistoryResultKind.number,
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

    await tester.pumpWidget(_testApp(NotesPage(db: db, toolResultLabel: _identityLabel)));
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
          resultKind: HistoryResultKind.number,
          createdAt: DateTime(2026, 6, 9, 10),
        ),
        HistoryItem(
          id: 2,
          expression: 'sqrt(9)',
          result: '3',
          resultKind: HistoryResultKind.number,
          createdAt: DateTime(2026, 6, 9, 11),
        ),
      ],
    );

    await tester.pumpWidget(_testApp(NotesPage(db: db, toolResultLabel: _identityLabel)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'sqrt');
    await tester.pump(const Duration(milliseconds: 20));

    await tester.pumpWidget(_testApp(NotesPage(db: db, reloadToken: 1, toolResultLabel: _identityLabel)));
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

    await tester.pumpWidget(_testApp(NotesPage(db: db, toolResultLabel: _identityLabel)));
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

    await tester.pumpWidget(_testApp(NotesPage(db: db, toolResultLabel: _identityLabel)));
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

/// 中文：笔记页的测试不验证工具标签的英文重渲染（那由 `history_result_kind_test.dart`
///       专门盯），所以这里把"查表"实现成原样返回——中文界面下生产实现也是这个行为。
/// English: the notes page tests do not exercise the English re-rendering of tool labels (a dedicated
///          `history_result_kind_test.dart` watches that), so the lookup here is the identity — which
///          is exactly what the production implementation does in the Chinese interface.
String _identityLabel(String label) => label;

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
    String? tag,
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
    NoteSort sort = NoteSort.updatedNewest,
  }) async {
    noteLoads++;
    return noteItems.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<List<String>> noteTags({
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
  }) async {
    return noteItems
        .expand((item) => item.tags)
        .toSet()
        .toList(growable: false);
  }

  @override
  Future<int> addNote(String title, String body,
      {String description = '', List<String> tags = const []}) async {
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
    HistoryResultKind? resultKind,
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
      resultKind: classifyHistoryResult(toolId: toolId, result: result),
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

/// 中文：**外壳递进来的那条查表真的落到了历史那一行上。** 单元测试
///       （`history_result_display_test.dart`）量的是"给定查表，这一行怎么画"；这一条量的是
///       "笔记页确实用了递进来的那条查表"——把 `NotesPage.toolResultLabel` 换成一张假表，屏幕
///       上的字就得跟着变。少了它，"注入了但没接上"这种改法不会被任何测试挡住。
/// English: **the lookup the shell hands in really reaches the history row.** The unit tests
///          (`history_result_display_test.dart`) measure "given a lookup, how is this row drawn";
///          this measures "the notes page actually uses the lookup it was handed" — swap
///          `NotesPage.toolResultLabel` for a fake table and the on-screen text must follow. Without
///          it, "injected but not wired" would slip past every test.
void _wiringTests() {
  testWidgets('工具行的标签由 NotesPage.toolResultLabel 决定（注入被接上了）', (tester) async {
    final db = _FakeNotesDatabase(
      historyItems: [
        HistoryItem(
          id: 1,
          expression: '电流=2A, 电阻=5Ω',
          result: '电压 V: 20V',
          resultKind: HistoryResultKind.tool,
          toolId: 'ohms_law',
          createdAt: DateTime(2026, 6, 9, 10),
        ),
      ],
    );

    // 中文：假查表把 `电压 V` 映射成一个一眼认得出的记号——只可能来自这条注入。
    // English: the fake table maps `电压 V` to a marker recognisable at a glance — it can only have
    //          come from this injection.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NotesPage(
          db: db,
          toolResultLabel: (label) => label == '电压 V' ? 'FAKE_VOLT' : label,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('FAKE_VOLT: 20V'), findsOneWidget);
    // 中文：存的那一份没动——页面上不该出现原始标签拼出来的那一串。
    // English: the stored copy did not move — the original label's spelling must not appear.
    expect(find.text('电压 V: 20V'), findsNothing);
  });
}
