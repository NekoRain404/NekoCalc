import '../../data/repositories/tool_usage_repository.dart';
import '../../domain/entities/tool_definition.dart';
import '../../domain/usecases/tool_catalog.dart';

class ToolsController {
  ToolsController({required this.toolUsageRepository});

  final ToolUsageRepository toolUsageRepository;

  Future<ToolsState> load() async {
    final favoriteIds = await toolUsageRepository.favoriteIds();
    final recentIds = await toolUsageRepository.recentIds();
    return ToolsState(favoriteIds: favoriteIds, recentIds: recentIds);
  }

  Future<void> markRecent(ToolDefinition tool) =>
      toolUsageRepository.markRecent(tool.id);

  Future<void> setFavorite(ToolDefinition tool, bool favorite) {
    return toolUsageRepository.setFavorite(tool.id, favorite);
  }

  List<ToolDefinition> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return toolCatalog;
    return toolCatalog.where((tool) {
      // 中文：把标题、描述、分类和工具 id 放进同一个索引串，兼顾中英文和技术关键词搜索。
      // English: Search one combined index containing title, description, category, and tool id.
      final haystack =
          '${tool.title}${tool.description}${tool.category.title}${tool.group}${tool.id}'
              .toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }
}

class ToolsState {
  const ToolsState({
    required this.favoriteIds,
    required this.recentIds,
  });

  final Set<String> favoriteIds;
  final List<String> recentIds;
}
