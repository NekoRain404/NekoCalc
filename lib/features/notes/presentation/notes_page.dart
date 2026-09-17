import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../application/controllers/notes_controller.dart';
import '../../../data/local/app_database.dart';
import '../../../data/models/history_item.dart';
import '../../../data/models/note_item.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../domain/usecases/notes_clipboard_import.dart';
import '../../../shared/presentation/app_chrome.dart';

part 'notes_page_sections.dart';
part 'notes_page_actions.dart';
part 'notes_page_dialogs.dart';

/// 中文：笔记与历史页面，统一展示计算历史、工具结果和用户笔记。
/// English: Notes and history screen for calculation history, tool results, and user notes.
class NotesPage extends StatefulWidget {
  const NotesPage({required this.db, this.reloadToken = 0, super.key});

  final AppDatabase db;
  final int reloadToken;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final NotesController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  bool _savingNote = false;
  bool _importingClipboard = false;
  final Set<int> _selectedHistoryIds = {};
  final Set<int> _selectedNoteIds = {};

  bool get _selectionActive =>
      _selectedHistoryIds.isNotEmpty || _selectedNoteIds.isNotEmpty;

  int get _selectedCount =>
      _selectedHistoryIds.length + _selectedNoteIds.length;

  @override
  void initState() {
    super.initState();
    _controller = NotesController(
      historyRepository: HistoryRepository(widget.db),
      notesRepository: NotesRepository(widget.db),
    )..addListener(_onControllerChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _resetTransientStateAfterExternalReload();
      _controller.load();
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        _header(),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: _setSearchQuery,
          decoration: const InputDecoration(
            hintText: '搜索笔记、历史、公式...',
            prefixIcon: Icon(Icons.search),
          ).copyWith(
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  tooltip: '清除',
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _tabPill(NotesTab.all, '全部'),
              _tabPill(NotesTab.notes, '笔记'),
              _tabPill(NotesTab.history, '历史'),
              _tabPill(NotesTab.formulas, '公式'),
              _tabPill(NotesTab.tools, '工具'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _filterSummary(),
        const SizedBox(height: 16),
        if (_controller.showsHistory) ...[
          const SectionTitle('计算历史'),
          _historySection(),
          const SizedBox(height: 14),
        ],
        if (_controller.showsNotes) ...[
          const SectionTitle('个人笔记'),
          _notesSection(),
        ],
      ],
    );
  }

  void _toggleHistorySelection(int id) {
    setState(() {
      if (!_selectedHistoryIds.add(id)) _selectedHistoryIds.remove(id);
    });
  }

  void _toggleNoteSelection(int id) {
    setState(() {
      if (!_selectedNoteIds.add(id)) _selectedNoteIds.remove(id);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedHistoryIds.clear();
      _selectedNoteIds.clear();
    });
  }

  void _resetTransientStateAfterExternalReload() {
    _searchTimer?.cancel();
    _searchController.clear();
    _controller.setQuery('');
    if (!_selectionActive) return;
    setState(() {
      _selectedHistoryIds.clear();
      _selectedNoteIds.clear();
    });
  }

  void _clearSelectionForFilterChange() {
    if (!_selectionActive) return;
    setState(() {
      _selectedHistoryIds.clear();
      _selectedNoteIds.clear();
    });
  }

  void _selectVisibleItems() {
    setState(() {
      final visibleHistoryIds = _controller.showsHistory
          ? _controller.visibleHistory.map((item) => item.id).toSet()
          : const <int>{};
      final visibleNoteIds = _controller.showsNotes
          ? _controller.visibleNotes.map((item) => item.id).toSet()
          : const <int>{};
      final allVisibleSelected =
          visibleHistoryIds.every(_selectedHistoryIds.contains) &&
              visibleNoteIds.every(_selectedNoteIds.contains) &&
              (visibleHistoryIds.isNotEmpty || visibleNoteIds.isNotEmpty);

      if (allVisibleSelected) {
        _selectedHistoryIds.removeAll(visibleHistoryIds);
        _selectedNoteIds.removeAll(visibleNoteIds);
      } else {
        _selectedHistoryIds.addAll(visibleHistoryIds);
        _selectedNoteIds.addAll(visibleNoteIds);
      }
    });
  }
}
