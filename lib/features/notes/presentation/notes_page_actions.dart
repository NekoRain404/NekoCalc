part of 'notes_page.dart';

extension _NotesPageActions on _NotesPageState {
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
        tags: draft.tags,
      );
    } finally {
      _savingNote = false;
    }
  }

  Future<void> _showNoteFilters() async {
    final draft = await showModalBottomSheet<_NoteFilterDraft>(
      context: context,
      builder: (context) => _NoteFilterSheet(
        archiveFilter: _controller.noteArchiveFilter,
        sort: _controller.noteSort,
        tag: _controller.noteTag,
        availableTags: _controller.availableNoteTags,
      ),
    );
    if (draft == null) return;
    _clearSelectionForFilterChange();
    _controller.applyNoteFilters(
      archiveFilter: draft.archiveFilter,
      sort: draft.sort,
      tag: draft.tag,
    );
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
              leading: Icon(
                  item.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(item.isPinned ? '取消置顶' : '置顶笔记'),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: Icon(item.isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined),
              title: Text(item.isArchived ? '取消归档' : '归档笔记'),
              onTap: () => Navigator.pop(context, 'archive'),
            ),
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
    if (action == 'pin') {
      await _controller.setNotePinned(item, !item.isPinned);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(item.isPinned ? '已取消置顶' : '已置顶笔记')),
      );
    }
    if (action == 'archive') {
      await _controller.setNoteArchived(item, !item.isArchived);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(item.isArchived ? '已取消归档' : '已归档笔记')),
      );
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
