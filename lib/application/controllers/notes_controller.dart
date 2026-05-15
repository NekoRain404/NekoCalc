import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../data/models/history_item.dart';
import '../../data/models/note_item.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../domain/usecases/record_filter.dart';

typedef NotesTab = RecordTab;

class NotesController extends ChangeNotifier {
  NotesController({
    required this.historyRepository,
    required this.notesRepository,
  });

  final HistoryRepository historyRepository;
  final NotesRepository notesRepository;

  List<NoteItem> _notes = const [];
  List<HistoryItem> _history = const [];
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

  NotesTab get tab => _tab;

  String get query => _query;

  bool get loading => _loading;

  String? get error => _error;

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

  Future<void> deleteNote(int id) async {
    await notesRepository.delete(id);
    await _refresh(showLoading: false);
  }

  Future<void> deleteHistory(int id) async {
    await historyRepository.delete(id);
    await _refresh(showLoading: false);
  }

  Future<void> clearHistory() async {
    await historyRepository.clear();
    await _refresh(showLoading: false);
  }

  Future<void> saveHistoryAsNote(HistoryItem item) async {
    await notesRepository.create(
      title: '历史结果',
      body: '${item.expression}\n${item.result}',
      description:
          '由计算历史保存，时间 ${DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)}',
    );
    await _refresh(showLoading: false);
  }

  bool _matchesHistory(HistoryItem item) {
    return matchesHistoryRecord(item, _tab);
  }

  bool _matchesNote(NoteItem item) {
    return matchesNoteRecord(item, _tab);
  }
}
