import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/app_settings.dart';
import '../../../application/controllers/tools_controller.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/tool_usage_repository.dart';
import '../../../domain/entities/tool_category.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'tool_navigation.dart';
import 'tool_widgets.dart';

class ToolCategoryScreen extends StatefulWidget {
  const ToolCategoryScreen({
    required this.db,
    required this.category,
    required this.favoriteIds,
    required this.settings,
    super.key,
  });

  final AppDatabase db;
  final ToolCategory category;
  final Set<String> favoriteIds;
  final AppSettings settings;

  @override
  State<ToolCategoryScreen> createState() => _ToolCategoryScreenState();
}

class _ToolCategoryScreenState extends State<ToolCategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchTimer;
  String _query = '';
  bool _favoriteBusy = false;
  int _favoriteLoadToken = 0;
  late Set<String> _favoriteIds = widget.favoriteIds;
  late final ToolUsageRepository _toolUsageRepository =
      ToolUsageRepository(widget.db);
  late final ToolsController _toolsController =
      ToolsController(toolUsageRepository: _toolUsageRepository);

  Future<void> _openTool(ToolDefinition tool) async {
    unawaited(_toolUsageRepository.markRecent(tool.id).catchError((_) {}));
    if (!mounted) return;
    await openToolDetail(
      context: context,
      db: widget.db,
      tool: tool,
      settings: widget.settings,
    );
    await _reloadFavorites();
  }

  Future<void> _toggleFavorite(ToolDefinition tool) async {
    // 中文：分类页和工具详情页一样串行化收藏切换，避免快速点击造成状态竞态。
    // English: Serialize favorite toggles here too, matching the tool detail page and avoiding state races.
    if (_favoriteBusy) return;
    _favoriteBusy = true;
    _favoriteLoadToken++;
    final next = !_favoriteIds.contains(tool.id);
    try {
      await _toolUsageRepository.setFavorite(tool.id, next);
      await _reloadFavorites();
    } finally {
      _favoriteBusy = false;
    }
  }

  Future<void> _reloadFavorites() async {
    final token = ++_favoriteLoadToken;
    final favorites = await _toolUsageRepository.favoriteIds();
    if (mounted && token == _favoriteLoadToken) {
      setState(() => _favoriteIds = favorites);
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
    // 中文：分类页工具数量较多时，搜索防抖可以合并连续输入造成的列表过滤和布局计算。
    // English: Debouncing category search coalesces filtering and layout work while the user types quickly.
    _searchTimer = Timer(const Duration(milliseconds: 70), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() => _query = '');
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
    final hasQuery = _query.trim().isNotEmpty;
    final results =
        _toolsController.searchTools(_query, category: widget.category);
    final tools = results.map((result) => result.tool).toList();
    final resultById = {
      for (final result in results) result.tool.id: result.matchLabel,
    };
    final grouped = <String, List<ToolDefinition>>{};
    for (final tool in tools) {
      grouped.putIfAbsent(tool.group, () => []).add(tool);
    }
    final alternatives = hasQuery && tools.isEmpty
        ? _toolsController.searchAlternatives(
            _query,
            excludedCategory: widget.category,
          )
        : const <ToolSearchResult>[];
    final suggestions = hasQuery && tools.isEmpty
        ? _toolsController.searchSuggestions(_query, category: widget.category)
        : const <ToolSearchSuggestion>[];
    final searchExamples =
        _toolsController.searchExamples(category: widget.category, limit: 6);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(
              children: [
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new)),
                Expanded(
                    child: Center(child: PageTitle(widget.category.title))),
                IconButton(
                    onPressed: _searchFocus.requestFocus,
                    icon: const Icon(Icons.search)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _setSearchQuery,
              decoration: InputDecoration(
                  hintText: '搜索${widget.category.title}工具',
                  prefixIcon: const Icon(Icons.search),
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
                  )),
            ),
            const SizedBox(height: 16),
            if (hasQuery) ...[
              SectionTitle('搜索结果 · ${tools.length}'),
              if (tools.isEmpty)
                ToolSearchEmptyState(
                  message: '${widget.category.title}里没有“${_query.trim()}”。',
                  suggestions: suggestions
                      .map((suggestion) => suggestion.text)
                      .toList(growable: false),
                  examples: searchExamples,
                  onQuerySelected: _applySearchExample,
                  alternatives: _searchAlternativeTiles(alternatives),
                ),
              const SizedBox(height: 12),
            ],
            if (!hasQuery && tools.any((tool) => tool.featured)) ...[
              SectionHeader(
                  title: '常用工具',
                  action: '更多',
                  onActionTap: _searchFocus.requestFocus),
              HorizontalToolList(
                  tools: tools.where((tool) => tool.featured).toList(),
                  onTap: _openTool),
              const SizedBox(height: 14),
            ],
            ...grouped.entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(entry.key),
                    Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        children: entry.value
                            .map((tool) => ToolListTile(
                                  tool: tool,
                                  favorite: _favoriteIds.contains(tool.id),
                                  matchLabel: _query.trim().isEmpty
                                      ? null
                                      : '命中：${resultById[tool.id]}',
                                  onTap: () => _openTool(tool),
                                  onFavoriteToggle: () => _toggleFavorite(tool),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  List<Widget> _searchAlternativeTiles(List<ToolSearchResult> alternatives) =>
      alternatives
          .map(
            (result) => ToolListTile(
              tool: result.tool,
              favorite: _favoriteIds.contains(result.tool.id),
              matchLabel:
                  result.matchLabel.isEmpty ? null : '命中：${result.matchLabel}',
              onTap: () => _openTool(result.tool),
              onFavoriteToggle: () => _toggleFavorite(result.tool),
            ),
          )
          .toList(growable: false);
}
