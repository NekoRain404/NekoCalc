import '../../data/repositories/tool_usage_repository.dart';
import '../../domain/entities/tool_category.dart';
import '../../domain/entities/tool_definition.dart';
import '../../domain/usecases/recent_tool_action_result.dart';

import '../../domain/usecases/tool_catalog.dart';
import 'tool_search_engine.dart';
export 'tool_search_engine.dart';

class ToolsController {
  ToolsController({required this.toolUsageRepository});

  final ToolUsageRepository toolUsageRepository;
  static const int recentDisplayLimit = 8;
  static const int _recentLoadLimit = 24;

  Future<ToolsState> load() async {
    final availableToolIds = toolCatalog.map((tool) => tool.id).toSet();
    final favoriteIds = (await toolUsageRepository.favoriteIds())
        .where(availableToolIds.contains)
        .toSet();
    final recentIds = _normalizeRecentIds(
      await toolUsageRepository.recentIds(limit: _recentLoadLimit),
      availableToolIds: availableToolIds,
    );
    return ToolsState(favoriteIds: favoriteIds, recentIds: recentIds);
  }

  Future<void> markRecent(ToolDefinition tool) =>
      toolUsageRepository.markRecent(tool.id);

  Future<RecentToolActionResult> removeRecent(ToolDefinition tool) async {
    try {
      final affectedCount = await toolUsageRepository.removeRecent(tool.id);
      return RecentToolActionResult.remove(
        toolTitle: tool.title,
        affectedCount: affectedCount,
      );
    } catch (error) {
      return RecentToolActionResult.failed(
        action: RecentToolAction.remove,
        error: error,
      );
    }
  }

  Future<RecentToolActionResult> clearRecent() async {
    try {
      final affectedCount = await toolUsageRepository.clearRecent();
      return RecentToolActionResult.clear(affectedCount: affectedCount);
    } catch (error) {
      return RecentToolActionResult.failed(
        action: RecentToolAction.clear,
        error: error,
      );
    }
  }

  Future<void> setFavorite(ToolDefinition tool, bool favorite) {
    return toolUsageRepository.setFavorite(tool.id, favorite);
  }



  List<ToolDefinition> search(String query, {ToolCategory? category}) {
    return ToolSearch.searchTools(query, category: category)
        .map((result) => result.tool)
        .toList(growable: false);
  }

  List<ToolSearchResult> searchTools(String query, {ToolCategory? category}) {
    return ToolSearch.searchTools(query, category: category);
  }

  Map<ToolCategory, int> searchCategoryCounts(String query) {
    return ToolSearch.searchCategoryCounts(query);
  }

  List<ToolSearchResult> searchAlternatives(
    String query, {
    required ToolCategory excludedCategory,
    int limit = 4,
  }) {
    return ToolSearch.searchAlternatives(
      query,
      excludedCategory: excludedCategory,
      limit: limit,
    );
  }

  List<ToolSearchSuggestion> searchSuggestions(
    String query, {
    ToolCategory? category,
    int limit = 4,
  }) {
    return ToolSearch.searchSuggestions(
      query,
      category: category,
      limit: limit,
    );
  }

  List<String> searchExamples({ToolCategory? category, int limit = 6}) {
    return ToolSearch.searchExamples(category: category, limit: limit);
  }

  List<String> _normalizeRecentIds(
    List<String> ids, {
    required Set<String> availableToolIds,
  }) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final id in ids) {
      if (!availableToolIds.contains(id) || !seen.add(id)) continue;
      normalized.add(id);
      if (normalized.length == recentDisplayLimit) break;
    }
    return normalized;
  }
}
