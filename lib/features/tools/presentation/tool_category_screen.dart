import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../data/repositories/tool_usage_repository.dart';
import '../../../domain/entities/tool_category.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/tool_catalog.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'tool_navigation.dart';
import 'tool_widgets.dart';

class ToolCategoryScreen extends StatefulWidget {
  const ToolCategoryScreen({
    required this.db,
    required this.category,
    required this.favoriteIds,
    super.key,
  });

  final AppDatabase db;
  final ToolCategory category;
  final Set<String> favoriteIds;

  @override
  State<ToolCategoryScreen> createState() => _ToolCategoryScreenState();
}

class _ToolCategoryScreenState extends State<ToolCategoryScreen> {
  final FocusNode _searchFocus = FocusNode();
  String _query = '';
  late Set<String> _favoriteIds = widget.favoriteIds;
  late final ToolUsageRepository _toolUsageRepository =
      ToolUsageRepository(widget.db);

  Future<void> _openTool(ToolDefinition tool) async {
    unawaited(_toolUsageRepository.markRecent(tool.id).catchError((_) {}));
    if (!mounted) return;
    await openToolDetail(context: context, db: widget.db, tool: tool);
    final favorites = await _toolUsageRepository.favoriteIds();
    if (mounted) setState(() => _favoriteIds = favorites);
  }

  Future<void> _toggleFavorite(ToolDefinition tool) async {
    final next = !_favoriteIds.contains(tool.id);
    await _toolUsageRepository.setFavorite(tool.id, next);
    final favorites = await _toolUsageRepository.favoriteIds();
    if (mounted) setState(() => _favoriteIds = favorites);
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = toolCatalog
        .where((tool) => tool.category == widget.category)
        .where((tool) =>
            _query.isEmpty ||
            '${tool.title}${tool.description}'.contains(_query))
        .toList();
    final grouped = <String, List<ToolDefinition>>{};
    for (final tool in tools) {
      grouped.putIfAbsent(tool.group, () => []).add(tool);
    }

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
              focusNode: _searchFocus,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                  hintText: '搜索${widget.category.title}工具',
                  prefixIcon: const Icon(Icons.search)),
            ),
            const SizedBox(height: 16),
            if (tools.any((tool) => tool.featured)) ...[
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
}
