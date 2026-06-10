import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/notes_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/models/note_item.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';

void main() {
  final history = HistoryItem(
    id: 7,
    expression: '2+3',
    result: '5',
    createdAt: DateTime(2026, 6, 8, 9, 30),
  );
  final toolHistory = HistoryItem(
    id: 8,
    expression: '电流=2A, 电阻=5Ω',
    result: '电压: 10V',
    toolId: 'ohms_law',
    createdAt: DateTime(2026, 6, 8, 10, 15),
  );
  final note = NoteItem(
    id: 3,
    title: '实验记录',
    description: '电路校核',
    body: 'V = I * R',
    createdAt: DateTime(2026, 6, 7, 18, 0),
    updatedAt: DateTime(2026, 6, 8, 8, 20),
  );

  test('formats history and notes for copy and note export', () {
    final controller = _controller(history: [history], notes: [note]);

    expect(controller.historyCopyText(history), contains('计算历史'));
    expect(controller.historyCopyText(history), contains('表达式: 2+3'));
    expect(controller.historyCopyText(history), contains('结果: 5'));
    expect(
        controller.historyCopyText(history), contains('时间: 2026/06/08 09:30'));

    final noteText = controller.noteCopyText(note);
    expect(noteText, contains('笔记: 实验记录'));
    expect(noteText, contains('描述: 电路校核'));
    expect(noteText, contains('创建时间: 2026/06/07 18:00'));
    expect(noteText, contains('更新时间: 2026/06/08 08:20'));
    expect(noteText, contains('V = I * R'));

    controller.dispose();
  });

  test('combines selected history and notes with separators', () {
    final controller = _controller(
      history: [history, toolHistory],
      notes: [note],
    );

    final text = controller.selectedCopyText(
      historyIds: [8],
      noteIds: [3],
    );

    expect(text, startsWith('NekoCalc 批量导出'));
    expect(text, contains('历史: 1 条'));
    expect(text, contains('笔记: 1 条'));
    expect(text, contains('时间范围: 2026/06/08 08:20 ~ 2026/06/08 10:15'));
    expect(text, contains('工具历史: ohms_law'));
    expect(text, contains('表达式: 电流=2A, 电阻=5Ω'));
    expect(text, contains('---'));
    expect(text, contains('笔记: 实验记录'));
    expect(text, isNot(contains('表达式: 2+3')));

    controller.dispose();
  });

  test('visible lists respect formulas and tools tabs for both record types',
      () {
    final controller = _controller(
      history: [history, toolHistory],
      notes: [note],
    );

    controller.setTab(NotesTab.formulas);
    expect(controller.showsHistory, isTrue);
    expect(controller.showsNotes, isTrue);
    expect(controller.visibleHistory.map((item) => item.id), isEmpty);
    expect(controller.visibleNotes.map((item) => item.id), [3]);

    controller.setTab(NotesTab.tools);
    expect(controller.visibleHistory.map((item) => item.id), [8]);
    expect(controller.visibleNotes.map((item) => item.id), isEmpty);

    controller.dispose();
  });

  test('visible summary reports tab query and filtered counts', () {
    final controller = _controller(
      history: [history, toolHistory],
      notes: [note],
    );

    expect(controller.visibleSummary.label, '全部记录 · 历史 2 · 笔记 1');

    controller.setQuery('Ω');
    expect(controller.visibleSummary.query, 'Ω');
    expect(controller.visibleSummary.historyCount, 1);
    expect(controller.visibleSummary.noteCount, 0);
    expect(controller.visibleSummary.label, '搜索“Ω” · 历史 1');

    controller.setTab(NotesTab.notes);
    expect(controller.showsHistory, isFalse);
    expect(controller.visibleSummary.label, '搜索“Ω” · 无匹配');

    controller.dispose();
  });

  test('search examples follow the active notes tab', () {
    final controller = _controller();

    expect(controller.searchExamples(), contains('公式'));

    controller.setTab(NotesTab.history);
    expect(controller.searchExamples(limit: 3), hasLength(3));
    expect(controller.searchExamples(), contains('ohms_law'));
    expect(controller.searchExamples(), isNot(contains('实验')));

    controller.setTab(NotesTab.notes);
    expect(controller.searchExamples(), contains('实验'));
    expect(controller.searchExamples(), isNot(contains('ohms_law')));

    controller.dispose();
  });

  test('delete selected records refreshes once after both repositories finish',
      () async {
    final db = _FakeNotesControllerDatabase(
      historyItems: [history],
      noteItems: [note],
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      initialHistory: [history],
      initialNotes: [note],
    );

    final result =
        await controller.deleteSelected(historyIds: [7], noteIds: [3]);

    expect(db.deletedHistoryIds, [7]);
    expect(db.deletedNoteIds, [3]);
    expect(db.historyLoads, 1);
    expect(db.noteLoads, 1);
    expect(result.deletedHistoryCount, 1);
    expect(result.deletedNoteCount, 1);
    expect(result.missingCount, 0);
    expect(result.message, '已删除 1 条历史、1 条笔记');
    expect(controller.visibleHistory, isEmpty);
    expect(controller.visibleNotes, isEmpty);

    controller.dispose();
  });

  test('delete result reports selected records that were already gone',
      () async {
    final db = _FakeNotesControllerDatabase(
      historyItems: [history],
      noteItems: [note],
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      initialHistory: [history],
      initialNotes: [note],
    );

    final result = await controller.deleteSelected(
      historyIds: [7, 999],
      noteIds: [404],
    );

    expect(result.requestedHistoryCount, 2);
    expect(result.requestedNoteCount, 1);
    expect(result.deletedHistoryCount, 1);
    expect(result.deletedNoteCount, 0);
    expect(result.missingCount, 2);
    expect(result.message, '已删除 1 条历史，2 项未找到或已被删除');
    expect(controller.visibleHistory, isEmpty);
    expect(controller.visibleNotes.map((item) => item.id), [3]);

    controller.dispose();
  });

  test(
      'imports clipboard export drafts as history and notes then refreshes once',
      () async {
    final db = _FakeNotesControllerDatabase(
      historyItems: const [],
      noteItems: const [],
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
    );
    final plan = controller.previewClipboardImport('''
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
''');

    final result = await controller.importClipboardPlan(plan);

    expect(db.createdHistory, hasLength(1));
    expect(db.createdHistory.single.expression, '2+3');
    expect(db.createdHistory.single.result, '5');
    expect(db.createdHistory.single.toolId, isNull);
    expect(db.createdHistory.single.createdAt, DateTime(2026, 6, 8, 9, 30));
    expect(db.createdNotes, hasLength(1));
    expect(db.createdNotes.single.title, '实验记录');
    expect(db.createdNotes.single.description, '电路校核');
    expect(db.createdNotes.single.body, 'V = I * R');
    expect(db.historyLoads, 1);
    expect(db.noteLoads, 1);
    expect(result.historyIds, [50]);
    expect(result.noteIds, [100]);
    expect(result.importedMessage, '已导入 1 条历史、1 条笔记');
    expect(controller.visibleHistory.map((item) => item.expression), ['2+3']);
    expect(controller.visibleNotes.map((item) => item.title), ['实验记录']);

    controller.dispose();
  });

  test('clipboard import result reports records skipped by repositories',
      () async {
    final db = _FakeNotesControllerDatabase(
      historyItems: const [],
      noteItems: const [],
      zeroNextHistoryWrite: true,
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
    );
    final plan = controller.previewClipboardImport('''
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

V = I * R
''');

    final result = await controller.importClipboardPlan(plan);

    expect(result.historyIds, isEmpty);
    expect(result.noteIds, [100]);
    expect(result.skippedHistoryWrites, 1);
    expect(result.skippedNoteWrites, 0);
    expect(result.importedMessage, '已导入 1 条笔记，未写入 1 条');
    expect(controller.visibleHistory, isEmpty);
    expect(controller.visibleNotes.map((item) => item.title), ['实验记录']);

    controller.dispose();
  });
}

NotesController _controller({
  List<HistoryItem> history = const [],
  List<NoteItem> notes = const [],
}) {
  return NotesController(
    historyRepository: HistoryRepository(AppDatabase.instance),
    notesRepository: NotesRepository(AppDatabase.instance),
    initialHistory: history,
    initialNotes: notes,
  );
}

class _FakeNotesControllerDatabase implements AppDatabase {
  _FakeNotesControllerDatabase({
    required List<HistoryItem> historyItems,
    required List<NoteItem> noteItems,
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
