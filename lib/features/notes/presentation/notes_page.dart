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

  void _setSearchQuery(String value) {
    _searchTimer?.cancel();
    // 中文：笔记和历史都在本地列表中过滤，短防抖可减少大量记录时的连续重绘。
    // English: Notes and history are filtered locally; a short debounce reduces repeated repaints on large lists.
    _searchTimer = Timer(
      const Duration(milliseconds: 90),
      () {
        if (!mounted) return;
        _clearSelectionForFilterChange();
        _controller.setQuery(value);
      },
    );
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    _clearSelectionForFilterChange();
    _controller.setQuery('');
  }

  void _applySearchExample(String value) {
    _searchTimer?.cancel();
    _searchController.text = value;
    _searchController.selection = TextSelection.collapsed(offset: value.length);
    _clearSelectionForFilterChange();
    _controller.setQuery(value);
  }

  Future<void> _addNoteDialog() async {
    await _showNoteDialog();
  }

  Future<void> _showNoteDialog({NoteItem? item}) async {
    final draft = await showDialog<_NoteDraft>(
      context: context,
      builder: (context) => _NoteEditorDialog(item: item),
    );
    if (draft == null) return;
    if (_savingNote) return;
    _savingNote = true;
    try {
      await _controller.saveNote(
        item: item,
        title: draft.title,
        description: draft.description,
        body: draft.body,
      );
    } finally {
      _savingNote = false;
    }
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

  Widget _tabPill(NotesTab tab, String label) {
    return GestureDetector(
      onTap: () => _setTab(tab),
      child: TabPill(label: label, selected: _controller.tab == tab),
    );
  }

  void _setTab(NotesTab tab) {
    if (_controller.tab == tab) return;
    _clearSelectionForFilterChange();
    _controller.setTab(tab);
  }

  Widget _header() {
    if (_selectionActive) {
      return Row(
        children: [
          IconToolButton(
              icon: Icons.close, tooltip: '取消选择', onTap: _clearSelection),
          const SizedBox(width: 10),
          Expanded(
            child: Text('已选择 $_selectedCount 项',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          IconToolButton(
              icon: Icons.done_all,
              tooltip: '选择当前列表',
              onTap: _selectVisibleItems),
          const SizedBox(width: 8),
          IconToolButton(
              icon: Icons.copy_outlined, tooltip: '复制所选', onTap: _copySelected),
          const SizedBox(width: 8),
          IconToolButton(
              icon: Icons.delete_outline,
              tooltip: '删除所选',
              onTap: _deleteSelected),
        ],
      );
    }
    return Row(
      children: [
        const Expanded(child: PageTitle('笔记')),
        IconToolButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: '清空历史',
            onTap: _clearHistory),
        const SizedBox(width: 8),
        IconToolButton(
            icon: Icons.content_paste_outlined,
            tooltip: '从剪贴板导入',
            onTap: _importFromClipboard),
        const SizedBox(width: 8),
        IconToolButton(icon: Icons.add, tooltip: '新增笔记', onTap: _addNoteDialog),
      ],
    );
  }

  Widget _historySection() {
    final scheme = Theme.of(context).colorScheme;
    final items = _controller.visibleHistory;
    if (_controller.loading) return const EmptyPanel('正在加载历史记录。');
    if (_controller.error != null) {
      return EmptyPanel('历史读取失败：${_controller.error}');
    }
    if (items.isEmpty) {
      return _emptySearchPanel(
        icon: Icons.schedule,
        message: _controller.query.isEmpty ? '暂无历史记录。' : '当前筛选下没有历史记录。',
        showSearchHelp: _controller.visibleSummary.isEmpty,
      );
    }
    return Column(
      children: items
          .map((item) => Card(
                child: ListTile(
                  onTap: _selectionActive
                      ? () => _toggleHistorySelection(item.id)
                      : () => _showHistoryActions(item),
                  onLongPress: () => _toggleHistorySelection(item.id),
                  leading: _selectionActive
                      ? Checkbox(
                          value: _selectedHistoryIds.contains(item.id),
                          onChanged: (_) => _toggleHistorySelection(item.id),
                        )
                      : Icon(Icons.schedule, color: scheme.primary),
                  title: Text(item.expression,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(item.result,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      IconButton(
                        tooltip: '删除',
                        onPressed: _selectionActive
                            ? null
                            : () => _controller.deleteHistory(item.id),
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _notesSection() {
    final items = _controller.visibleNotes;
    if (_controller.loading) return const EmptyPanel('正在加载笔记。');
    if (_controller.error != null) {
      return EmptyPanel('笔记读取失败：${_controller.error}');
    }
    if (items.isEmpty) {
      return _emptySearchPanel(
        icon: Icons.article_outlined,
        message: _controller.query.isEmpty ? '暂无个人笔记。' : '当前筛选下没有个人笔记。',
        showSearchHelp:
            _controller.visibleSummary.isEmpty && !_controller.showsHistory,
      );
    }
    return Column(
      children: items
          .map((item) => Card(
                child: ListTile(
                  onTap: _selectionActive
                      ? () => _toggleNoteSelection(item.id)
                      : () => _showNoteDialog(item: item),
                  onLongPress: () => _toggleNoteSelection(item.id),
                  leading: _selectionActive
                      ? Checkbox(
                          value: _selectedNoteIds.contains(item.id),
                          onChanged: (_) => _toggleNoteSelection(item.id),
                        )
                      : Icon(_noteIcon(item), color: const Color(0xFF23B45D)),
                  title: Text(item.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 3),
                          child: Text(item.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      Text(item.body,
                          maxLines: item.description.isEmpty ? 2 : 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: '更多',
                    onPressed:
                        _selectionActive ? null : () => _showNoteActions(item),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
              ))
          .toList(),
    );
  }

  IconData _noteIcon(NoteItem item) {
    if (item.title.contains('公式') ||
        item.description.contains('公式') ||
        item.body.contains('=')) {
      return Icons.functions;
    }
    if (item.body.contains('公式：') || item.description.contains('工具')) {
      return Icons.construction;
    }
    return Icons.article_outlined;
  }

  Widget _filterSummary() {
    final scheme = Theme.of(context).colorScheme;
    final summary = _controller.visibleSummary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: softPanel(context: context),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_controller.query.isNotEmpty)
            TextButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('清除'),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptySearchPanel({
    required IconData icon,
    required String message,
    bool showSearchHelp = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    showSearchHelp = showSearchHelp && _controller.query.isNotEmpty;
    final suggestions =
        showSearchHelp ? _controller.searchSuggestions() : const [];
    final examples =
        showSearchHelp ? _controller.searchExamples() : const <String>[];
    final suggestionTexts = suggestions
        .map((suggestion) => suggestion.text.trim().toLowerCase())
        .toSet();
    final visibleExamples = examples
        .where((example) =>
            !suggestionTexts.contains(example.trim().toLowerCase()))
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: softPanel(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (showSearchHelp &&
              (suggestions.isNotEmpty || visibleExamples.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...suggestions.map(
                  (suggestion) => ActionChip(
                    avatar: const Icon(Icons.manage_search, size: 16),
                    label: Text(suggestion.text),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _applySearchExample(suggestion.text),
                  ),
                ),
                ...visibleExamples.map((example) => ActionChip(
                      label: Text(example),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _applySearchExample(example),
                    )),
              ],
            ),
          ],
          if (_controller.query.isEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addNoteDialog,
              icon: const Icon(Icons.add),
              label: const Text('新增笔记'),
            ),
          ],
        ],
      ),
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

  Future<void> _deleteSelected() async {
    if (!_selectionActive) return;
    final historyCount = _selectedHistoryIds.length;
    final noteCount = _selectedNoteIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除所选'),
        content: Text('确认删除 $historyCount 条历史和 $noteCount 条笔记？此操作无法撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true) return;
    final historyIds = _selectedHistoryIds.toList(growable: false);
    final noteIds = _selectedNoteIds.toList(growable: false);
    _clearSelection();
    final result = await _controller.deleteSelected(
        historyIds: historyIds, noteIds: noteIds);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _copySelected() async {
    if (!_selectionActive) return;
    final text = _controller.selectedCopyText(
      historyIds: _selectedHistoryIds,
      noteIds: _selectedNoteIds,
    );
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已复制 $_selectedCount 项')));
  }

  Future<void> _importFromClipboard() async {
    if (_importingClipboard) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final plan = _controller.previewClipboardImport(data?.text ?? '');
    if (!plan.canImport) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(plan.summary)));
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _ClipboardImportDialog(plan: plan),
    );
    if (confirm != true) return;

    _importingClipboard = true;
    try {
      final result = await _controller.importClipboardPlan(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.importedMessage)));
    } finally {
      _importingClipboard = false;
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确认删除全部计算历史？笔记不会受影响。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('清空')),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await _controller.clearHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _showHistoryActions(HistoryItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制结果'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('保存为笔记'),
              onTap: () => Navigator.pop(context, 'note'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除记录'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'copy') {
      await Clipboard.setData(
          ClipboardData(text: _controller.historyCopyText(item)));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已复制历史结果')));
      }
    }
    if (action == 'note') {
      // 中文：历史转笔记也做串行保护，避免同一条历史被快速保存成多条笔记。
      // English: Serialize history-to-note conversion to avoid creating duplicate notes from one history item.
      if (_savingNote) return;
      _savingNote = true;
      try {
        await _controller.saveHistoryAsNote(item);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('已保存到笔记')));
        }
      } finally {
        _savingNote = false;
      }
    }
    if (action == 'delete') {
      final result = await _controller.deleteHistory(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Future<void> _showNoteActions(NoteItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑笔记'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制笔记'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除笔记'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      await _showNoteDialog(item: item);
    }
    if (action == 'copy') {
      await Clipboard.setData(
          ClipboardData(text: _controller.noteCopyText(item)));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制笔记')));
    }
    if (action == 'delete') {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除笔记'),
          content: Text('确认删除“${item.title}”？此操作无法撤销。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除')),
          ],
        ),
      );
      if (confirm == true) {
        final result = await _controller.deleteNote(item.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    }
  }
}

class _ClipboardImportDialog extends StatelessWidget {
  const _ClipboardImportDialog({required this.plan});

  final NotesClipboardImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final previews = plan.previews;
    final previewDrafts = previews.take(5).toList(growable: false);
    final hiddenCount = plan.totalCount - previewDrafts.length;
    return AlertDialog(
      title: const Text('从剪贴板导入'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.summary),
            const SizedBox(height: 12),
            ...previewDrafts.map(
              (draft) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(_sourceIcon(draft.source)),
                title: Text(draft.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: draft.description.isEmpty
                    ? null
                    : Text(draft.description,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (hiddenCount > 0)
              Text('还有 $hiddenCount 条未显示',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导入')),
      ],
    );
  }

  IconData _sourceIcon(NotesImportSource source) {
    return switch (source) {
      NotesImportSource.note => Icons.article_outlined,
      NotesImportSource.history => Icons.schedule,
      NotesImportSource.plainText => Icons.content_paste_outlined,
    };
  }
}

class _NoteDraft {
  const _NoteDraft({
    required this.title,
    required this.description,
    required this.body,
  });

  final String title;
  final String description;
  final String body;
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({this.item});

  final NoteItem? item;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.item?.description ?? '');
    _bodyController = TextEditingController(text: widget.item?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? '新增笔记' : '编辑笔记'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: '描述', hintText: '写清用途、来源或下一步处理'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyController,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(labelText: '内容'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _NoteDraft(
              title: _titleController.text,
              description: _descriptionController.text,
              body: _bodyController.text,
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
