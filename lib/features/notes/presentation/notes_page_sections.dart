part of 'notes_page.dart';

extension _NotesPageSections on _NotesPageState {
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

  /// 中文：**一行历史结果怎么画。** 见顶层函数 [historyResultText]。
  /// English: **how one history result is drawn.** See the top-level [historyResultText].
  String _historyResultText(HistoryItem item) {
    return historyResultText(item, widget.toolResultLabel);
  }

  Widget _header() {
    final strings = NotesStrings.of(context);
    if (_selectionActive) {
      return Row(
        children: [
          IconToolButton(
              icon: Icons.close,
              tooltip: strings.cancelSelection,
              onTap: _clearSelection),
          const SizedBox(width: 10),
          Expanded(
            child: Text(strings.selectedCount(_selectedCount),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          IconToolButton(
              icon: Icons.done_all,
              tooltip: strings.selectVisible,
              onTap: _selectVisibleItems),
          const SizedBox(width: 8),
          IconToolButton(
              icon: Icons.copy_outlined,
              tooltip: strings.copySelected,
              onTap: _copySelected),
          const SizedBox(width: 8),
          IconToolButton(
              icon: Icons.delete_outline,
              tooltip: strings.deleteSelected,
              onTap: _deleteSelected),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: PageTitle(strings.pageTitle)),
        if (_controller.showsNotes) ...[
          IconToolButton(
            icon: Icons.tune,
            tooltip: strings.noteFilterTitle,
            onTap: _showNoteFilters,
          ),
          const SizedBox(width: 8),
        ],
        IconToolButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: strings.clearHistory,
            onTap: _clearHistory),
        const SizedBox(width: 8),
        IconToolButton(
            icon: Icons.content_paste_outlined,
            tooltip: strings.clipboardImportTitle,
            onTap: _importFromClipboard),
        const SizedBox(width: 8),
        IconToolButton(
            icon: Icons.add, tooltip: strings.newNote, onTap: _addNoteDialog),
      ],
    );
  }

  Widget _historySection() {
    final strings = NotesStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final items = _controller.visibleHistory;
    if (_controller.loading) return EmptyPanel(strings.loadingHistory);
    if (_controller.error != null) {
      return EmptyPanel(strings.historyLoadFailed('${_controller.error}'));
    }
    if (items.isEmpty) {
      return _emptySearchPanel(
        icon: Icons.schedule,
        message: _controller.query.isEmpty
            ? strings.historyEmpty
            : strings.historyEmptyFiltered,
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
                      Text(_historyResultText(item),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      IconButton(
                        tooltip: strings.delete,
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
    final strings = NotesStrings.of(context);
    final items = _controller.visibleNotes;
    if (_controller.loading) return EmptyPanel(strings.loadingNotes);
    if (_controller.error != null) {
      return EmptyPanel(strings.notesLoadFailed('${_controller.error}'));
    }
    if (items.isEmpty) {
      return Column(
        children: [
          _emptySearchPanel(
            icon: Icons.article_outlined,
            message: _controller.query.isEmpty
                ? strings.notesEmpty
                : strings.notesEmptyFiltered,
            showSearchHelp:
                _controller.visibleSummary.isEmpty && !_controller.showsHistory,
          ),
          if (_controller.hasMoreNotes || _controller.loadingMoreNotes)
            _loadMoreNotesButton(),
        ],
      );
    }
    return Column(
      children: [
        ...items.map((item) => Card(
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
                    : Icon(_noteIcon(item),
                        color: Theme.of(context).colorScheme.primary),
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
                    if (item.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.tags.map((tag) => '#$tag').join('  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  tooltip: strings.moreTooltip,
                  onPressed:
                      _selectionActive ? null : () => _showNoteActions(item),
                  icon: const Icon(Icons.more_horiz),
                ),
              ),
            )),
        if (_controller.hasMoreNotes || _controller.loadingMoreNotes)
          _loadMoreNotesButton(),
      ],
    );
  }

  Widget _loadMoreNotesButton() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
          onPressed:
              _controller.loadingMoreNotes ? null : _controller.loadMoreNotes,
          icon: _controller.loadingMoreNotes
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          label: Text(_controller.loadingMoreNotes
              ? NotesStrings.of(context).loadingMoreNotes
              : NotesStrings.of(context).loadMoreNotes),
        ),
      );

  IconData _noteIcon(NoteItem item) {
    if (item.isPinned) return Icons.push_pin_outlined;
    if (item.isArchived) return Icons.inventory_2_outlined;
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
    final strings = NotesStrings.of(context);
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
              label: Text(strings.clearSearchTooltip),
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
    final strings = NotesStrings.of(context);
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
              label: Text(strings.newNote),
            ),
          ],
        ],
      ),
    );
  }
}
