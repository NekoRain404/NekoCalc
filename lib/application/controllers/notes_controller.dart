import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../data/models/history_item.dart';
import '../../data/models/note_item.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../domain/usecases/notes_clipboard_import.dart';
import '../../domain/usecases/notes_delete_result.dart';
import '../../domain/usecases/record_filter.dart';
import '../../domain/usecases/record_search_suggestions.dart';

typedef NotesTab = RecordTab;

class NotesController extends ChangeNotifier {
  NotesController({
    required this.historyRepository,
    required this.notesRepository,
    List<NoteItem> initialNotes = const [],
    List<HistoryItem> initialHistory = const [],
  })  : _notes = initialNotes,
        _history = initialHistory;

  final HistoryRepository historyRepository;
  final NotesRepository notesRepository;

  List<NoteItem> _notes;
  List<HistoryItem> _history;
  NotesTab _tab = NotesTab.all;
  String _query = '';
  bool _loading = true;
  String? _error;
  int _loadToken = 0;
  bool _disposed = false;

  List<NoteItem> get notes => _notes
      .where(_matchesNote)
      .where((item) => matchesNoteQuery(item, _query))
      .toList(growable: false);

  List<HistoryItem> get history => _history
      .where(_matchesHistory)
      .where((item) => matchesHistoryQuery(item, _query))
      .toList(growable: false);

  List<HistoryItem> get visibleHistory =>
      showsHistory ? history : const <HistoryItem>[];

  List<NoteItem> get visibleNotes => showsNotes ? notes : const <NoteItem>[];

  NotesTab get tab => _tab;

  String get query => _query;

  bool get loading => _loading;

  String? get error => _error;

  bool get showsHistory => _tab != NotesTab.notes;

  bool get showsNotes => _tab != NotesTab.history;

  NotesVisibleSummary get visibleSummary => NotesVisibleSummary(
        tab: _tab,
        query: _query,
        historyCount: visibleHistory.length,
        noteCount: visibleNotes.length,
      );

  List<String> searchExamples({NotesTab? tab, int limit = 5}) {
    final examples = _searchExamplesByTab[tab ?? _tab] ?? _searchExamples;
    return examples.take(limit).toList(growable: false);
  }

  List<RecordSearchSuggestion> searchSuggestions({int limit = 4}) {
    if (_query.isEmpty) return const [];
    if (visibleSummary.totalCount > 0) return const [];
    return buildRecordSearchSuggestions(
      query: _query,
      history: _history,
      notes: _notes,
      tab: _tab,
      limit: limit,
    );
  }

  String historyCopyText(HistoryItem item) {
    return _historyReport(item).join('\n');
  }

  String noteCopyText(NoteItem item) {
    return _noteReport(item).join('\n');
  }

  String selectedCopyText({
    required Iterable<int> historyIds,
    required Iterable<int> noteIds,
  }) {
    final selectedHistoryIds = historyIds.toSet();
    final selectedNoteIds = noteIds.toSet();
    final selectedHistory = _history
        .where((item) => selectedHistoryIds.contains(item.id))
        .toList(growable: false);
    final selectedNotes = _notes
        .where((item) => selectedNoteIds.contains(item.id))
        .toList(growable: false);
    final blocks = <String>[
      if (selectedHistory.isNotEmpty || selectedNotes.isNotEmpty)
        _selectionSummary(selectedHistory, selectedNotes).join('\n'),
      ...selectedHistory.map((item) => _historyReport(item).join('\n')),
      ...selectedNotes.map((item) => _noteReport(item).join('\n')),
    ];
    return blocks.join('\n\n---\n\n');
  }

  NotesClipboardImportPlan previewClipboardImport(String text) {
    return buildNotesClipboardImportPlan(text);
  }

  Future<NotesClipboardImportResult> importClipboardPlan(
    NotesClipboardImportPlan plan,
  ) async {
    if (!plan.canImport) return NotesClipboardImportResult.empty(plan);
    final historyIds = <int>[];
    final noteIds = <int>[];
    var skippedHistoryWrites = 0;
    var skippedNoteWrites = 0;
    for (final draft in plan.historyDrafts) {
      final toolId = draft.toolId;
      final id = toolId == null || toolId.isEmpty
          ? await historyRepository.saveCalculation(
              expression: draft.expression,
              result: draft.result,
              createdAt: draft.createdAt,
            )
          : await historyRepository.saveToolResult(
              toolId: toolId,
              expression: draft.expression,
              result: draft.result,
              createdAt: draft.createdAt,
            );
      if (id > 0) {
        historyIds.add(id);
      } else {
        skippedHistoryWrites++;
      }
    }
    for (final draft in plan.noteDrafts) {
      final id = await notesRepository.create(
        title: draft.title,
        description: draft.description,
        body: draft.body,
      );
      if (id > 0) {
        noteIds.add(id);
      } else {
        skippedNoteWrites++;
      }
    }
    await _refresh(showLoading: false);
    return NotesClipboardImportResult(
      plan: plan,
      historyIds: historyIds,
      noteIds: noteIds,
      skippedHistoryWrites: skippedHistoryWrites,
      skippedNoteWrites: skippedNoteWrites,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() => _refresh(showLoading: true);

  Future<void> _refresh({required bool showLoading}) async {
    final token = ++_loadToken;
    if (showLoading) {
      _loading = true;
      notifyListeners();
    }
    try {
      final notes = await notesRepository.list(limit: 1000);
      final history = await historyRepository.list(limit: 500);
      if (_disposed || token != _loadToken) return;
      _notes = notes;
      _history = history;
      _error = null;
      _loading = false;
      notifyListeners();
    } catch (error) {
      if (_disposed || token != _loadToken) return;
      _error = error.toString();
      _loading = false;
      notifyListeners();
    }
  }

  void setTab(NotesTab value) {
    if (_tab == value) return;
    _tab = value;
    notifyListeners();
  }

  void setQuery(String value) {
    final next = value.trim();
    if (_query == next) return;
    _query = next;
    notifyListeners();
    unawaited(_refresh(showLoading: false));
  }

  Future<void> saveNote(
      {NoteItem? item,
      required String title,
      required String description,
      required String body}) async {
    final normalizedTitle = title.trim().isEmpty ? '未命名笔记' : title.trim();
    final normalizedDescription = description.trim();
    final normalizedBody = body.trim();
    if (item == null) {
      await notesRepository.create(
          title: normalizedTitle,
          body: normalizedBody,
          description: normalizedDescription);
    } else {
      await notesRepository.update(
          id: item.id,
          title: normalizedTitle,
          description: normalizedDescription,
          body: normalizedBody);
    }
    await _refresh(showLoading: false);
  }

  Future<NotesDeleteResult> deleteNote(int id) async {
    final deleted = await notesRepository.delete(id);
    await _refresh(showLoading: false);
    return NotesDeleteResult(
      requestedHistoryCount: 0,
      requestedNoteCount: 1,
      deletedHistoryCount: 0,
      deletedNoteCount: deleted,
    );
  }

  Future<NotesDeleteResult> deleteNotes(Iterable<int> ids) async {
    final noteIdList = ids.toSet().toList(growable: false);
    if (noteIdList.isEmpty) return NotesDeleteResult.none();
    final deleted = await notesRepository.deleteMany(noteIdList);
    await _refresh(showLoading: false);
    return NotesDeleteResult(
      requestedHistoryCount: 0,
      requestedNoteCount: noteIdList.length,
      deletedHistoryCount: 0,
      deletedNoteCount: deleted,
    );
  }

  Future<NotesDeleteResult> deleteSelected({
    required Iterable<int> historyIds,
    required Iterable<int> noteIds,
  }) async {
    final historyIdList = historyIds.toSet().toList(growable: false);
    final noteIdList = noteIds.toSet().toList(growable: false);
    if (historyIdList.isEmpty && noteIdList.isEmpty) {
      return NotesDeleteResult.none();
    }
    var deletedHistory = 0;
    var deletedNotes = 0;
    if (historyIdList.isNotEmpty) {
      deletedHistory = await historyRepository.deleteMany(historyIdList);
    }
    if (noteIdList.isNotEmpty) {
      deletedNotes = await notesRepository.deleteMany(noteIdList);
    }
    await _refresh(showLoading: false);
    return NotesDeleteResult(
      requestedHistoryCount: historyIdList.length,
      requestedNoteCount: noteIdList.length,
      deletedHistoryCount: deletedHistory,
      deletedNoteCount: deletedNotes,
    );
  }

  Future<NotesDeleteResult> deleteHistory(int id) async {
    final deleted = await historyRepository.delete(id);
    await _refresh(showLoading: false);
    return NotesDeleteResult(
      requestedHistoryCount: 1,
      requestedNoteCount: 0,
      deletedHistoryCount: deleted,
      deletedNoteCount: 0,
    );
  }

  Future<NotesDeleteResult> deleteHistoryItems(Iterable<int> ids) async {
    final historyIdList = ids.toSet().toList(growable: false);
    if (historyIdList.isEmpty) return NotesDeleteResult.none();
    final deleted = await historyRepository.deleteMany(historyIdList);
    await _refresh(showLoading: false);
    return NotesDeleteResult(
      requestedHistoryCount: historyIdList.length,
      requestedNoteCount: 0,
      deletedHistoryCount: deleted,
      deletedNoteCount: 0,
    );
  }

  Future<NotesDeleteResult> clearHistory() async {
    final requested = _history.length;
    final deleted = await historyRepository.clear();
    await _refresh(showLoading: false);
    return NotesDeleteResult(
      requestedHistoryCount: requested,
      requestedNoteCount: 0,
      deletedHistoryCount: deleted,
      deletedNoteCount: 0,
    );
  }

  Future<void> saveHistoryAsNote(HistoryItem item) async {
    await notesRepository.create(
      title: '历史结果',
      body: historyCopyText(item),
      description:
          '由计算历史保存，时间 ${DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)}',
    );
    await _refresh(showLoading: false);
  }

  List<String> _historyReport(HistoryItem item) {
    return [
      if (item.toolId == null) '计算历史' else '工具历史: ${item.toolId}',
      '表达式: ${item.expression}',
      '结果: ${item.result}',
      '时间: ${DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)}',
    ];
  }

  List<String> _selectionSummary(
    List<HistoryItem> history,
    List<NoteItem> notes,
  ) {
    final dates = <DateTime>[
      for (final item in history) item.createdAt,
      for (final item in notes) item.updatedAt,
    ]..sort();
    final range = dates.isEmpty
        ? null
        : dates.length == 1
            ? DateFormat('yyyy/MM/dd HH:mm').format(dates.single)
            : '${DateFormat('yyyy/MM/dd HH:mm').format(dates.first)} ~ ${DateFormat('yyyy/MM/dd HH:mm').format(dates.last)}';
    return [
      'NekoCalc 批量导出',
      '历史: ${history.length} 条',
      '笔记: ${notes.length} 条',
      if (range != null) '时间范围: $range',
    ];
  }

  List<String> _noteReport(NoteItem item) {
    return [
      '笔记: ${item.title}',
      if (item.description.isNotEmpty) '描述: ${item.description}',
      '创建时间: ${DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)}',
      '更新时间: ${DateFormat('yyyy/MM/dd HH:mm').format(item.updatedAt)}',
      '',
      item.body,
    ];
  }

  bool _matchesHistory(HistoryItem item) {
    return matchesHistoryRecord(item, _tab);
  }

  bool _matchesNote(NoteItem item) {
    return matchesNoteRecord(item, _tab);
  }

  static const List<String> _searchExamples = [
    '公式',
    '工具',
    '2026/06/08',
    'Ω',
    '结果',
  ];

  static const Map<NotesTab, List<String>> _searchExamplesByTab = {
    NotesTab.all: _searchExamples,
    NotesTab.notes: [
      '实验',
      '公式',
      '电路',
      '待处理',
      '保存',
    ],
    NotesTab.history: [
      'sin',
      'sqrt',
      '2026/06/08',
      '结果',
      'ohms_law',
    ],
    NotesTab.formulas: [
      'sin',
      'sqrt',
      'V = I * R',
      'π',
      '公式',
    ],
    NotesTab.tools: [
      'ohms_law',
      '电压',
      'Ω',
      '工具',
      '结果:',
    ],
  };
}

class NotesVisibleSummary {
  const NotesVisibleSummary({
    required this.tab,
    required this.query,
    required this.historyCount,
    required this.noteCount,
  });

  final NotesTab tab;
  final String query;
  final int historyCount;
  final int noteCount;

  int get totalCount => historyCount + noteCount;

  bool get hasQuery => query.isNotEmpty;

  bool get isEmpty => totalCount == 0;

  String get label {
    final prefix = hasQuery ? '搜索“$query”' : _tabLabel(tab);
    if (totalCount == 0) return '$prefix · 无匹配';
    final parts = <String>[
      if (historyCount > 0) '历史 $historyCount',
      if (noteCount > 0) '笔记 $noteCount',
    ];
    return '$prefix · ${parts.join(' · ')}';
  }

  static String _tabLabel(NotesTab tab) {
    return switch (tab) {
      NotesTab.all => '全部记录',
      NotesTab.notes => '笔记',
      NotesTab.history => '历史',
      NotesTab.formulas => '公式',
      NotesTab.tools => '工具',
    };
  }
}
