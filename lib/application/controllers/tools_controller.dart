import '../../data/local/app_database.dart';
import '../../domain/entities/tool_definition.dart';
import '../../domain/usecases/tool_catalog.dart';

class ToolsController {
  ToolsController({required this.db});

  final AppDatabase db;

  Future<ToolsState> load() async {
    final favoriteIds = await db.favoriteToolIds();
    final recentIds = await db.recentToolIds();
    return ToolsState(favoriteIds: favoriteIds, recentIds: recentIds);
  }

  Future<void> markRecent(ToolDefinition tool) => db.markRecent(tool.id);

  Future<void> setFavorite(ToolDefinition tool, bool favorite) {
    return db.setFavorite(tool.id, favorite);
  }

  List<ToolDefinition> search(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return toolCatalog;
    return toolCatalog
        .where((tool) => '${tool.title}${tool.description}${tool.category.title}${tool.group}'.contains(normalized))
        .toList();
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
