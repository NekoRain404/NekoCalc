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
import '../../features/notes/presentation/notes_strings.dart';

typedef NotesTab = RecordTab;

class NotesController extends ChangeNotifier {
  NotesController({
    required this.historyRepository,
    required this.notesRepository,
    required this.strings,
    List<NoteItem> initialNotes = const [],
    List<HistoryItem> initialHistory = const [],
  })  : _notes = initialNotes,
        _history = initialHistory;

  final HistoryRepository historyRepository;
  final NotesRepository notesRepository;

  /// 中文：**写进库的那几句话从这张表来**（标题留空时的兜底、从计算历史保存时的标题与描述）。
  ///       必填、没有中文兜底：忘了递表的调用点编译不过，而不是在英文界面上悄悄存下中文标题——
  ///       这正是这三位原先的毛病（硬编码中文，见 `docs/verification.md` §5l）。
  ///
  ///       **它可以被换掉，而且必须被换掉。** 页面在 `initState` 里按设置的语言代码取一张
  ///       （`NotesStrings.forCode`，与 `ToolDetailController` 同一形状），随后在
  ///       `didChangeDependencies` 里换成作用域中**当场生效**的那一张：用户换语言时 `app.dart`
  ///       只换内存里的 `_language`（不重载设置记录），只按构造时的设置取值会让"设置页还开着、
  ///       底下的笔记页已经该换语言了"这一种停在旧语言上。
  ///
  ///       **只在保存那一刻读，存下去的仍是纯文本。** 标题是用户数据（可编辑、进备份、可搜索），
  ///       所以这里冻结的是"创建时的正确语言"，不是"显示时按当前语言重算"——理由与三个选项的取舍
  ///       在 `docs/verification.md` §5l。
  /// English: **the sentences written into the database come from this table** (the blank-title
  ///          fallback, and the title and description used when saving from a calculation-history
  ///          row). Required, with no Chinese fallback: a call site that forgets it fails to compile
  ///          rather than quietly storing a Chinese title into an English interface — which is
  ///          exactly what these three used to do (hard-coded Chinese, `docs/verification.md` §5l).
  ///
  ///          **It is reassignable, and it has to be.** The page seeds it in `initState` from the
  ///          settings' language code (`NotesStrings.forCode`, the same shape as
  ///          `ToolDetailController`) and then swaps it in `didChangeDependencies` for the scope's
  ///          **immediately effective** table: a language change makes `app.dart` swap only the
  ///          in-memory `_language` (the settings record is not reloaded), so reading the
  ///          construction-time setting alone would leave "the settings page is still open but the
  ///          notes page underneath should already have changed language" stuck in the old one.
  ///
  ///          **It is read at save time only, and what is stored stays plain text.** A title is user
  ///          data (editable, exported in backups, searchable), so what freezes here is "the right
  ///          language at creation", not "recomputed at display time from the current language" — the
  ///          reasoning and the three shapes' costs are in `docs/verification.md` §5l.
  NotesStrings strings;

  List<NoteItem> _notes;
  List<HistoryItem> _history;
  NotesTab _tab = NotesTab.all;
  String _query = '';
  bool _loading = true;
  String? _error;
  int _loadToken = 0;
  bool _disposed = false;
  static const _notePageSize = 100;
  bool _hasMoreNotes = false;
  bool _loadingMoreNotes = false;
  NoteArchiveFilter _noteArchiveFilter = NoteArchiveFilter.active;
  NoteSort _noteSort = NoteSort.updatedNewest;
  String? _noteTag;
  List<String> _availableNoteTags = const [];

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

  bool get hasMoreNotes => _hasMoreNotes;

  bool get loadingMoreNotes => _loadingMoreNotes;

  NoteArchiveFilter get noteArchiveFilter => _noteArchiveFilter;

  NoteSort get noteSort => _noteSort;

  String? get noteTag => _noteTag;

  List<String> get availableNoteTags => _availableNoteTags;

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

  String? get _databaseNoteQuery {
    final value = _query.trim();
    if (value.isEmpty) return null;
    // Dates and engineering symbols are normalized by matchesNoteQuery but
    // cannot be represented faithfully by the raw SQL LIKE search.
    final plainText = RegExp(
      r'^[A-Za-z0-9\u4e00-\u9fff]+(?:\s+[A-Za-z0-9\u4e00-\u9fff]+)*$',
    );
    return plainText.hasMatch(value) ? value : null;
  }

  Future<void> _refresh({required bool showLoading}) async {
    final token = ++_loadToken;
    if (showLoading) {
      _loading = true;
      notifyListeners();
    }
    try {
      final notes = await notesRepository.list(
        limit: _notePageSize,
        query: _databaseNoteQuery,
        tag: _noteTag,
        archiveFilter: _noteArchiveFilter,
        sort: _noteSort,
      );
      final history = await historyRepository.list(limit: 500);
      final availableTags =
          await notesRepository.tags(archiveFilter: _noteArchiveFilter);
      if (_disposed || token != _loadToken) return;
      _notes = notes;
      _hasMoreNotes = notes.length == _notePageSize;
      _availableNoteTags = availableTags;
      _loadingMoreNotes = false;
      _history = history;
      _error = null;
      _loading = false;
      notifyListeners();
    } catch (error) {
      if (_disposed || token != _loadToken) return;
      _error = error.toString();
      _loading = false;
      _loadingMoreNotes = false;
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

  void applyNoteFilters({
    required NoteArchiveFilter archiveFilter,
    required NoteSort sort,
    String? tag,
  }) {
    final normalized = tag?.trim();
    final nextTag =
        normalized == null || normalized.isEmpty ? null : normalized;
    if (_noteArchiveFilter == archiveFilter &&
        _noteSort == sort &&
        _noteTag == nextTag) {
      return;
    }
    _noteArchiveFilter = archiveFilter;
    _noteSort = sort;
    _noteTag = nextTag;
    unawaited(_refresh(showLoading: false));
  }

  Future<void> loadMoreNotes() async {
    if (_loading || _loadingMoreNotes || !_hasMoreNotes) return;
    final token = ++_loadToken;
    _loadingMoreNotes = true;
    notifyListeners();
    try {
      final nextPage = await notesRepository.list(
        limit: _notePageSize,
        offset: _notes.length,
        query: _databaseNoteQuery,
        tag: _noteTag,
        archiveFilter: _noteArchiveFilter,
        sort: _noteSort,
      );
      if (_disposed || token != _loadToken) return;
      final knownIds = _notes.map((item) => item.id).toSet();
      _notes = [
        ..._notes,
        ...nextPage.where((item) => knownIds.add(item.id)),
      ];
      _hasMoreNotes = nextPage.length == _notePageSize;
      _error = null;
    } catch (error) {
      if (_disposed || token != _loadToken) return;
      _error = error.toString();
    } finally {
      if (!_disposed && token == _loadToken) {
        _loadingMoreNotes = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveNote(
      {NoteItem? item,
      required String title,
      required String description,
      required String body,
      List<String> tags = const []}) async {
    final normalizedTitle =
        title.trim().isEmpty ? strings.untitledNote : title.trim();
    final normalizedDescription = description.trim();
    final normalizedBody = body.trim();
    if (item == null) {
      await notesRepository.create(
          title: normalizedTitle,
          body: normalizedBody,
          description: normalizedDescription,
          tags: tags);
    } else {
      await notesRepository.update(
          id: item.id,
          title: normalizedTitle,
          description: normalizedDescription,
          body: normalizedBody,
          tags: tags);
    }
    await _refresh(showLoading: false);
  }

  Future<void> setNotePinned(NoteItem item, bool value) async {
    await notesRepository.setPinned(item.id, value);
    await _refresh(showLoading: false);
  }

  Future<void> setNoteArchived(NoteItem item, bool value) async {
    await notesRepository.setArchived(item.id, value);
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
      title: strings.historyNoteTitle,
      body: historyCopyText(item),
      description: strings.historyNoteDescription(
          DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)),
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
      if (item.tags.isNotEmpty) '标签: ${item.tags.join('、')}',
      if (item.isPinned) '状态: 已置顶',
      if (item.isArchived) '状态: 已归档',
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

  // 中文：**这条摘要从前在这里拼成一句中文**（`label`，直接印在筛选摘要条上）。应用层对象活得
  //       比界面长，界面那张按语言切的表够不着它，于是英文界面下它照样是中文——`docs/verification.md`
  //       §5i 记着这条层次性缺陷。现在留下的只有**令牌与读数**：`tab` 与两根计数，字住在
  //       `NotesStrings` 里，由 `notes_summary_message.dart` 在呈现边缘按语言拼
  //       （`notesSummaryLabel(summary, strings)`）。旧读数（`totalCount` / `hasQuery` / `isEmpty`）
  //       一个都没动，所以哪一种摘要什么时候出现与迁移前完全一致。
  // English: **this summary used to compose a Chinese sentence right here** (`label`, printed straight
  //          onto the filter summary bar). An application-layer object outlives the UI and a
  //          language-keyed interface table cannot reach it, so an English interface still printed
  //          Chinese — the layering defect recorded in `docs/verification.md` §5i. What is left is
  //          **the token and the readings only**: `tab` and the two counts; the words live in
  //          `NotesStrings` and are put together at the presentation edge by `notes_summary_message.dart`
  //          (`notesSummaryLabel(summary, strings)`). Not one old reading (`totalCount` / `hasQuery` /
  //          `isEmpty`) moved, so which summary appears when is exactly what it was.
}
