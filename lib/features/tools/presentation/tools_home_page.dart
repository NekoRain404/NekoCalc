import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/app_settings.dart';
import '../../../application/controllers/tools_controller.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/tool_usage_repository.dart';
import '../../../domain/entities/tool_category.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/recent_tool_action_result.dart';
import '../../../domain/usecases/tool_catalog.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'tool_category_screen.dart';
import 'tool_navigation.dart';
import 'tool_widgets.dart';

/// 中文：工具首页，聚合搜索、最近使用、收藏和分类入口。
/// English: Tools home screen that combines search, recent tools, favorites, and category entry points.
class ToolsHomePage extends StatefulWidget {
  const ToolsHomePage({
    required this.db,
    required this.settings,
    this.reloadToken = 0,
    super.key,
  });

  final AppDatabase db;
  final AppSettings settings;
  final int reloadToken;

  @override
  State<ToolsHomePage> createState() => _ToolsHomePageState();
}

class _ToolsHomePageState extends State<ToolsHomePage> {
  late final ToolsController _controller;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  ToolsState _state = const ToolsState(favoriteIds: {}, recentIds: []);
  String _query = '';
  ToolCategory? _searchCategory;
  Timer? _searchTimer;
  bool _favoriteBusy = false;
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        ToolsController(toolUsageRepository: ToolUsageRepository(widget.db));
    _reload();
  }

  @override
  void didUpdateWidget(covariant ToolsHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final token = ++_reloadToken;
    final state = await _controller.load();
    if (mounted && token == _reloadToken) setState(() => _state = state);
  }

  Future<void> _openTool(ToolDefinition tool) async {
    unawaited(_controller.markRecent(tool).catchError((_) {}));
    if (!mounted) return;
    await openToolDetail(
      context: context,
      db: widget.db,
      tool: tool,
      settings: widget.settings,
    );
    await _reload();
  }

  Future<void> _toggleFavorite(ToolDefinition tool) async {
    // 中文：收藏按钮通常会被连续点击，串行化写入能避免 SQLite 返回顺序覆盖最新 UI 意图。
    // English: Favorite taps can be repeated quickly; serialize writes so SQLite completion order cannot overwrite the latest UI intent.
    if (_favoriteBusy) return;
    _favoriteBusy = true;
    try {
      await _controller.setFavorite(
          tool, !_state.favoriteIds.contains(tool.id));
      await _reload();
    } finally {
      _favoriteBusy = false;
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _setSearchQuery(String value) {
    _searchTimer?.cancel();
    // 中文：搜索结果刷新做短防抖，输入框响应保持即时，列表重建合并执行。
    // English: Debounce result refresh briefly; the text field stays responsive while list rebuilds are coalesced.
    _searchTimer = Timer(const Duration(milliseconds: 70), () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _searchCategory = null;
    });
    _searchFocus.requestFocus();
  }

  void _applySearchExample(String value) {
    _searchTimer?.cancel();
    _searchController.text = value;
    _searchController.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _query = value);
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final recent =
        _state.recentIds.map(toolById).whereType<ToolDefinition>().toList();
    final favorites = toolCatalog
        .where((tool) => _state.favoriteIds.contains(tool.id))
        .toList();
    final hasQuery = _query.trim().isNotEmpty;
    final filtered = hasQuery
        ? _controller.searchTools(_query, category: _searchCategory)
        : const <ToolSearchResult>[];
    final categoryCounts = hasQuery
        ? _controller.searchCategoryCounts(_query)
        : const <ToolCategory, int>{};
    final alternatives = hasQuery && filtered.isEmpty && _searchCategory != null
        ? _controller.searchAlternatives(
            _query,
            excludedCategory: _searchCategory!,
          )
        : const <ToolSearchResult>[];
    final suggestions = hasQuery && filtered.isEmpty
        ? _controller.searchSuggestions(_query, category: _searchCategory)
        : const <ToolSearchSuggestion>[];
    final searchExamples =
        _controller.searchExamples(category: _searchCategory, limit: 6);
    final suggested =
        toolCatalog.where((tool) => tool.featured).take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            const Expanded(child: PageTitle('工具')),
            IconButton(
                onPressed: _searchFocus.requestFocus,
                icon: const Icon(Icons.search)),
          ],
        ),
        TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: _setSearchQuery,
          decoration: const InputDecoration(
            hintText: '搜索工具、公式、单位...',
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
        const SizedBox(height: 18),
        if (hasQuery) ...[
          _searchCategoryBar(categoryCounts),
          const SizedBox(height: 10),
          _searchResultHeader(filtered.length),
          if (filtered.isEmpty)
            ToolSearchEmptyState(
              message: _searchEmptyMessage(),
              suggestions: suggestions
                  .map((suggestion) => suggestion.text)
                  .toList(growable: false),
              examples: searchExamples,
              onQuerySelected: _applySearchExample,
              alternatives: _searchAlternativeTiles(alternatives),
            )
          else
            Card(
              child: Column(
                children: filtered
                    .map((result) => ToolListTile(
                          tool: result.tool,
                          favorite: _state.favoriteIds.contains(result.tool.id),
                          matchLabel: _matchHint(result),
                          onTap: () => _openTool(result.tool),
                          onFavoriteToggle: () => _toggleFavorite(result.tool),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 18),
        ],
        SectionHeader(
            title: recent.isEmpty ? '推荐工具' : '最近使用',
            action: recent.isEmpty ? null : '管理',
            onActionTap: () => _showRecentSheet(recent)),
        HorizontalToolList(
          tools: recent.isEmpty ? suggested : recent,
          onTap: _openTool,
        ),
        const SizedBox(height: 18),
        SectionHeader(
          title: '收藏工具',
          action: favorites.isEmpty ? '添加' : '管理',
          onActionTap: favorites.isEmpty
              ? _searchFocus.requestFocus
              : () => _showToolSheet('收藏工具', favorites, manageFavorites: true),
        ),
        if (favorites.isEmpty)
          const EmptyPanel('还没有收藏工具，点击工具右侧星标即可固定到这里。')
        else
          Card(
            child: Column(
              children: favorites
                  .map((tool) => ToolListTile(
                        tool: tool,
                        favorite: true,
                        onTap: () => _openTool(tool),
                        onFavoriteToggle: () => _toggleFavorite(tool),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 18),
        const SectionTitle('分类'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.85,
          children: ToolCategory.values.map((category) {
            final count =
                toolCatalog.where((tool) => tool.category == category).length;
            return CategoryCard(
              category: category,
              count: count,
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ToolCategoryScreen(
                      db: widget.db,
                      category: category,
                      favoriteIds: _state.favoriteIds,
                      settings: widget.settings),
                ));
                _reload();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _searchResultHeader(int count) {
    final scheme = Theme.of(context).colorScheme;
    final category = _searchCategory;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category == null ? '搜索结果 · $count' : '${category.title} · $count',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          if (category != null)
            TextButton.icon(
              onPressed: () => setState(() => _searchCategory = null),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('全部分类'),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchCategoryBar(Map<ToolCategory, int> counts) {
    final chips = [
      const _SearchCategoryOption(null, '全部'),
      ...ToolCategory.values
          .map((category) => _SearchCategoryOption(category, category.title)),
    ];
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = chips[index];
          final count =
              option.category == null ? total : counts[option.category] ?? 0;
          return ChoiceChip(
            label: Text(count == 0 ? option.label : '${option.label} $count'),
            selected: _searchCategory == option.category,
            onSelected: (_) =>
                setState(() => _searchCategory = option.category),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  String _searchEmptyMessage() {
    final category = _searchCategory;
    return category == null
        ? '没有找到“${_query.trim()}”的匹配工具。'
        : '${category.title}里没有“${_query.trim()}”。';
  }

  List<Widget> _searchAlternativeTiles(List<ToolSearchResult> alternatives) =>
      alternatives
          .map(
            (result) => ToolListTile(
              tool: result.tool,
              favorite: _state.favoriteIds.contains(result.tool.id),
              matchLabel: _matchHint(result),
              onTap: () => _openTool(result.tool),
              onFavoriteToggle: () => _toggleFavorite(result.tool),
            ),
          )
          .toList(growable: false);

  String? _matchHint(ToolSearchResult result) {
    if (result.matchLabel.isEmpty) return null;
    final text = result.matchText.trim();
    if (text.isEmpty) return '命中：${result.matchLabel}';
    return '命中：${result.matchLabel} · $text';
  }

  Future<void> _showToolSheet(String title, List<ToolDefinition> tools,
      {bool manageFavorites = false}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            for (final tool in tools)
              ToolListTile(
                tool: tool,
                favorite: _state.favoriteIds.contains(tool.id),
                onTap: () {
                  Navigator.pop(context);
                  _openTool(tool);
                },
                onFavoriteToggle:
                    manageFavorites ? () => _toggleFavorite(tool) : null,
              ),
          ],
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _showRecentSheet(List<ToolDefinition> tools) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _RecentToolsSheet(
        tools: tools,
        favoriteIds: _state.favoriteIds,
        onOpen: (tool) {
          Navigator.pop(context);
          _openTool(tool);
        },
        onRemove: _removeRecentTool,
        onClear: _clearRecentTools,
      ),
    );
    if (mounted) _reload();
  }

  Future<RecentToolActionResult> _removeRecentTool(
    ToolDefinition tool,
  ) async {
    final result = await _controller.removeRecent(tool);
    if (mounted) {
      if (result.succeeded) {
        setState(() {
          _state = ToolsState(
            favoriteIds: _state.favoriteIds,
            recentIds: _state.recentIds.where((id) => id != tool.id).toList(),
          );
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
        await _reload();
      }
    }
    return result;
  }

  Future<RecentToolActionResult> _clearRecentTools() async {
    final result = await _controller.clearRecent();
    if (mounted) {
      if (result.succeeded) {
        setState(() {
          _state = ToolsState(
            favoriteIds: _state.favoriteIds,
            recentIds: const [],
          );
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
        await _reload();
      }
    }
    return result;
  }
}

class _SearchCategoryOption {
  const _SearchCategoryOption(this.category, this.label);

  final ToolCategory? category;
  final String label;
}

class _RecentToolsSheet extends StatefulWidget {
  const _RecentToolsSheet({
    required this.tools,
    required this.favoriteIds,
    required this.onOpen,
    required this.onRemove,
    required this.onClear,
  });

  final List<ToolDefinition> tools;
  final Set<String> favoriteIds;
  final ValueChanged<ToolDefinition> onOpen;
  final Future<RecentToolActionResult> Function(ToolDefinition tool) onRemove;
  final Future<RecentToolActionResult> Function() onClear;

  @override
  State<_RecentToolsSheet> createState() => _RecentToolsSheetState();
}

class _RecentToolsSheetState extends State<_RecentToolsSheet> {
  late final List<ToolDefinition> _tools = List.of(widget.tools);
  final Set<String> _removingIds = {};
  bool _clearing = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '最近使用',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _tools.isEmpty || _clearing ? null : _clear,
                  icon: _clearing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('清空'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          if (_tools.isEmpty)
            const EmptyPanel('最近使用已清空。打开任意工具后会重新记录到这里。')
          else
            for (final tool in _tools)
              ToolListTile(
                tool: tool,
                favorite: widget.favoriteIds.contains(tool.id),
                onTap: () => widget.onOpen(tool),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.favoriteIds.contains(tool.id))
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                    IconButton(
                      tooltip: '移除最近使用',
                      onPressed: _removingIds.contains(tool.id)
                          ? null
                          : () => _remove(tool),
                      icon: _removingIds.contains(tool.id)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.close,
                              color: scheme.onSurfaceVariant,
                            ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _remove(ToolDefinition tool) async {
    setState(() => _removingIds.add(tool.id));
    final result = await widget.onRemove(tool);
    if (!mounted) return;
    setState(() {
      _removingIds.remove(tool.id);
      if (result.succeeded) _tools.removeWhere((item) => item.id == tool.id);
    });
  }

  Future<void> _clear() async {
    setState(() => _clearing = true);
    final result = await widget.onClear();
    if (!mounted) return;
    setState(() {
      _clearing = false;
      if (result.succeeded) _tools.clear();
    });
  }
}
