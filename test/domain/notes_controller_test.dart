import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/notes_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/models/note_item.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/features/notes/presentation/notes_receipt_message.dart';
import 'package:nekocalc/features/notes/presentation/notes_strings.dart';
import 'package:nekocalc/features/notes/presentation/notes_summary_message.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

void main() {
  // 中文：领域层只给令牌，回执的句子在呈现边缘取——所以这几条断言把中文表带进来渲染。
  // English: The domain layer hands over tokens only and the receipt sentences are fetched at the
  //          presentation edge — so these assertions render through the Chinese table.
  final strings = NotesStrings.forLanguage(AppLanguage.zh);
  final history = HistoryItem(
    id: 7,
    expression: '2+3',
    result: '5',
    resultKind: HistoryResultKind.number,
    createdAt: DateTime(2026, 6, 8, 9, 30),
  );
  final toolHistory = HistoryItem(
    id: 8,
    expression: '电流=2A, 电阻=5Ω',
    result: '电压: 10V',
    resultKind: HistoryResultKind.tool,
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

    // 中文：那句摘要的句子住在文案表里、由呈现边缘拼（`notes_summary_message.dart`），所以这里把
    //       中文表带进来渲染——量到的还是迁移前那句话。
    // English: the summary sentence lives in the copy table and is composed at the presentation edge
    //          (`notes_summary_message.dart`), so it is rendered here through the Chinese table — the
    //          assertions still measure the pre-move sentence.
    expect(notesSummaryLabel(controller.visibleSummary, strings),
        '全部记录 · 历史 2 · 笔记 1');

    controller.setQuery('Ω');
    expect(controller.visibleSummary.query, 'Ω');
    expect(controller.visibleSummary.historyCount, 1);
    expect(controller.visibleSummary.noteCount, 0);
    expect(notesSummaryLabel(controller.visibleSummary, strings), '搜索“Ω” · 历史 1');

    controller.setTab(NotesTab.notes);
    expect(controller.showsHistory, isFalse);
    expect(notesSummaryLabel(controller.visibleSummary, strings), '搜索“Ω” · 无匹配');

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

  test('loads the first note page instead of reading every matching note',
      () async {
    final db = _FakeNotesControllerDatabase(
      historyItems: const [],
      noteItems: List.generate(
        151,
        (index) => NoteItem(
          id: index + 1,
          title: '笔记 ${index + 1}',
          description: '',
          body: '内容 ${index + 1}',
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      ),
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      strings: NotesStrings.forLanguage(AppLanguage.zh),
    );

    await controller.load();

    expect(controller.visibleNotes, hasLength(100));
    expect(db.noteLimits, [100]);
    controller.dispose();
  });

  test('loads the next note page on demand without losing prior notes',
      () async {
    final db = _FakeNotesControllerDatabase(
      historyItems: const [],
      noteItems: List.generate(
        151,
        (index) => NoteItem(
          id: index + 1,
          title: '笔记 ${index + 1}',
          description: '',
          body: '内容 ${index + 1}',
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      ),
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      strings: NotesStrings.forLanguage(AppLanguage.zh),
    );

    await controller.load();
    await controller.loadMoreNotes();

    expect(controller.visibleNotes, hasLength(151));
    expect(controller.hasMoreNotes, isFalse);
    expect(db.noteLimits, [100, 100]);
    controller.dispose();
  });

  test('applies archive and tag filters before loading notes', () async {
    final active = NoteItem(
      id: 1,
      title: '进行中的校核',
      description: '',
      body: '待处理',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
      tags: const ['实验'],
    );
    final archived = active.copyWith(
      title: '已完成的校核',
      tags: const ['归档'],
      isArchived: true,
    );
    final db = _FakeNotesControllerDatabase(
      historyItems: const [],
      noteItems: [active, archived],
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      strings: NotesStrings.forLanguage(AppLanguage.zh),
    );

    controller.applyNoteFilters(
      archiveFilter: NoteArchiveFilter.archived,
      sort: NoteSort.updatedNewest,
      tag: '归档',
    );
    await controller.load();

    expect(controller.visibleNotes.map((item) => item.title), ['已完成的校核']);
    expect(controller.availableNoteTags, ['归档']);
    controller.dispose();
  });

  test('keeps date queries out of SQL prefiltering and matches note dates',
      () async {
    final datedNote = NoteItem(
      id: 31,
      title: note.title,
      description: note.description,
      body: note.body,
      createdAt: DateTime(2026, 6, 8, 12),
      updatedAt: DateTime(2026, 6, 8, 12),
    );
    final db = _FakeNotesControllerDatabase(
      historyItems: const [],
      noteItems: [datedNote],
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      strings: NotesStrings.forLanguage(AppLanguage.zh),
    );

    controller.setQuery('2026/06/08');
    await Future<void>.delayed(Duration.zero);

    expect(db.noteQueries.last, isNull);
    expect(controller.visibleNotes.map((item) => item.id), [31]);
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
      strings: NotesStrings.forLanguage(AppLanguage.zh),
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
    expect(notesDeleteMessage(result, strings), '已删除 1 条历史、1 条笔记');
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
      strings: NotesStrings.forLanguage(AppLanguage.zh),
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
    expect(notesDeleteMessage(result, strings), '已删除 1 条历史，2 项未找到或已被删除');
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
      strings: NotesStrings.forLanguage(AppLanguage.zh),
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
    expect(notesImportMessage(result, strings), '已导入 1 条历史、1 条笔记');
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
      strings: NotesStrings.forLanguage(AppLanguage.zh),
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
    expect(notesImportMessage(result, strings), '已导入 1 条笔记，未写入 1 条');
    expect(controller.visibleHistory, isEmpty);
    expect(controller.visibleNotes.map((item) => item.title), ['实验记录']);

    controller.dispose();
  });

  test('中文表下保存笔记：空标题兜底与历史标题/描述逐字节等于迁移前那三句',
      () async {
    // 中文：**中文侧一个字节都不许动。** 这三句从前硬编码在控制器里（`'未命名笔记'`、
    //       `'历史结果'`、`'由计算历史保存，时间 …'`），现在从 `strings` 取；默认语言是中文，
    //       所以存进库的那一份必须与迁移前逐字节相同。量的是**真的写进库的那份**（假库把
    //       `addNote` 收到的参数原样记下来），不是屏幕上的一句话。
    // English: **not one byte of the Chinese side may move.** These three used to be hard-coded in
    //          the controller (`'未命名笔记'`, `'历史结果'`, `'由计算历史保存，时间 …'`) and now come
    //          from `strings`; the default language is Chinese, so what lands in the database must be
    //          byte-identical to what it was. What is measured is **what was really written** (the
    //          fake records the arguments `addNote` received), not a sentence on screen.
    final db = _FakeNotesControllerDatabase(
      historyItems: [history],
      noteItems: const [],
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      strings: NotesStrings.forLanguage(AppLanguage.zh),
    );

    await controller.saveNote(title: '   ', description: '', body: '正文');
    await controller.saveHistoryAsNote(history);

    expect(db.createdNotes.map((item) => item.title), ['未命名笔记', '历史结果']);
    expect(db.createdNotes.first.body, '正文');
    expect(db.createdNotes.last.description, '由计算历史保存，时间 2026/06/08 09:30');
    controller.dispose();
  });

  test('英文表下保存笔记：存下去的是英文标题与描述（这条量的是修复本身）', () async {
    // 中文：**这就是那个缺陷。** 换语言后控制器仍按中文拼标题，英文用户得到中文名字的笔记；
    //       修复的判据是：同一个保存路径、换成英文表，**写进库的**标题与描述是英文，且整条
    //       记录里没有一个宽/全角字符（尺子与其他护栏同一把）。
    // English: **this is the defect itself.** With the language switched, the controller still
    //          composed Chinese titles, so an English user got notes named in Chinese; the fix's
    //          criterion is: the same save path with the English table, and the title and description
    //          **written into the database** are English — with not one wide/fullwidth character in
    //          the whole record (the same ruler as the other guards).
    final db = _FakeNotesControllerDatabase(
      historyItems: [history],
      noteItems: const [],
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      strings: NotesStrings.forLanguage(AppLanguage.en),
    );

    await controller.saveNote(title: '  ', description: '', body: 'body');
    await controller.saveHistoryAsNote(history);

    expect(
        db.createdNotes.map((item) => item.title).toList(), ['Untitled note', 'History result']);
    expect(db.createdNotes.last.description,
        'Saved from calculation history at 2026/06/08 09:30');
    // 中文：**量的是这两格，不含正文。** 历史笔记的正文是 `historyCopyText` 拼的**剪贴板往返格式**
    //       （`'计算历史'`、`'表达式: '`…），它故意保持中文——跟着界面语言翻掉，粘贴就不再认得自己
    //       写出来的导出文本（理由在 `notes_strings.dart` 的文件头）。所以下面的断言只走标题与描述。
    // English: **what is measured is these two cells, not the body.** A history note's body is the
    //          **clipboard round-trip format** composed by `historyCopyText` (`'计算历史'`,
    //          `'表达式: '` …), deliberately kept Chinese — translate it with the interface and a paste
    //          would no longer recognise the export this app itself wrote (see `notes_strings.dart`'s
    //          head). So the assertions below walk the title and the description only.
    for (final note in db.createdNotes) {
      final composed = '${note.title}${note.description}';
      expect(containsWideOrFullwidth(composed), isFalse,
          reason: '英文表下存进库的标题或描述里还有宽/全角字符：$composed');
    }
    controller.dispose();
  });
}

NotesController _controller({
  List<HistoryItem> history = const [],
  List<NoteItem> notes = const [],
  NotesStrings? strings,
}) {
  return NotesController(
    historyRepository: HistoryRepository(AppDatabase.instance),
    notesRepository: NotesRepository(AppDatabase.instance),
    // 中文：默认递中文表（这些既有断言量的是迁移前那句中文）；要量英文侧就显式递英文表。
    // English: the Chinese table by default (those existing assertions measure the pre-move Chinese);
    //          pass the English table explicitly to measure the English side.
    strings: strings ?? NotesStrings.forLanguage(AppLanguage.zh),
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
  final List<int> noteLimits = [];
  final List<String?> noteQueries = [];
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
    noteLimits.add(limit);
    noteQueries.add(query);
    var items = noteItems.where((item) {
      return switch (archiveFilter) {
        NoteArchiveFilter.active => !item.isArchived,
        NoteArchiveFilter.archived => item.isArchived,
        NoteArchiveFilter.all => true,
      };
    });
    if (tag != null && tag.isNotEmpty) {
      items = items.where((item) => item.tags.contains(tag));
    }
    return items.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<List<String>> noteTags({
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
  }) async {
    return noteItems
        .where((item) => switch (archiveFilter) {
              NoteArchiveFilter.active => !item.isArchived,
              NoteArchiveFilter.archived => item.isArchived,
              NoteArchiveFilter.all => true,
            })
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
      tags: tags,
    ));
    final now = DateTime(2026, 6, 10, 9, id % 60);
    noteItems.add(NoteItem(
      id: id,
      title: title,
      description: description,
      body: body,
      createdAt: now,
      updatedAt: now,
      tags: tags,
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
    required this.tags,
  });

  final String title;
  final String description;
  final String body;
  final List<String> tags;
}
