import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/controllers/tools_controller.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/tool_usage_repository.dart';
import '../../../domain/entities/tool_category.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/tool_catalog.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'tool_category_screen.dart';
import 'tool_navigation.dart';
import 'tool_widgets.dart';

/// 中文：工具首页，聚合搜索、最近使用、收藏和分类入口。
/// English: Tools home screen that combines search, recent tools, favorites, and category entry points.
class ToolsHomePage extends StatefulWidget {
  const ToolsHomePage({required this.db, super.key});

  final AppDatabase db;

  @override
  State<ToolsHomePage> createState() => _ToolsHomePageState();
}

class _ToolsHomePageState extends State<ToolsHomePage> {
  late final ToolsController _controller;
  final FocusNode _searchFocus = FocusNode();
  ToolsState _state = const ToolsState(favoriteIds: {}, recentIds: []);
  String _query = '';
  Timer? _searchTimer;
  bool _favoriteBusy = false;

  @override
  void initState() {
    super.initState();
    _controller =
        ToolsController(toolUsageRepository: ToolUsageRepository(widget.db));
    _reload();
  }

  Future<void> _reload() async {
    final state = await _controller.load();
    if (mounted) setState(() => _state = state);
  }

  Future<void> _openTool(ToolDefinition tool) async {
    unawaited(_controller.markRecent(tool).catchError((_) {}));
    if (!mounted) return;
    await openToolDetail(context: context, db: widget.db, tool: tool);
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

  @override
  Widget build(BuildContext context) {
    final recent =
        _state.recentIds.map(toolById).whereType<ToolDefinition>().toList();
    final favorites = toolCatalog
        .where((tool) => _state.favoriteIds.contains(tool.id))
        .toList();
    final hasQuery = _query.trim().isNotEmpty;
    final filtered =
        hasQuery ? _controller.search(_query) : const <ToolDefinition>[];

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
          focusNode: _searchFocus,
          onChanged: _setSearchQuery,
          decoration: const InputDecoration(
              hintText: '搜索工具、公式、单位...', prefixIcon: Icon(Icons.search)),
        ),
        const SizedBox(height: 18),
        if (hasQuery) ...[
          const SectionTitle('搜索结果'),
          if (filtered.isEmpty)
            const EmptyPanel('没有找到匹配的工具。')
          else
            Card(
              child: Column(
                children: filtered
                    .map((tool) => ToolListTile(
                          tool: tool,
                          favorite: _state.favoriteIds.contains(tool.id),
                          onTap: () => _openTool(tool),
                          onFavoriteToggle: () => _toggleFavorite(tool),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 18),
        ],
        SectionHeader(
            title: '最近使用',
            action: recent.isEmpty ? null : '更多',
            onActionTap: () => _showToolSheet('最近使用', recent)),
        HorizontalToolList(
          tools: recent.isEmpty
              ? toolCatalog.where((tool) => tool.featured).take(4).toList()
              : recent,
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
                      favoriteIds: _state.favoriteIds),
                ));
                _reload();
              },
            );
          }).toList(),
        ),
      ],
    );
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
}
