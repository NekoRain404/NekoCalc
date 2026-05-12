import '../local/app_database.dart';

class ToolUsageRepository {
  const ToolUsageRepository(this._db);

  final AppDatabase _db;

  Future<Set<String>> favoriteIds() => _db.favoriteToolIds();

  Future<List<String>> recentIds({int limit = 8}) =>
      _db.recentToolIds(limit: limit);

  Future<void> setFavorite(String toolId, bool favorite) =>
      _db.setFavorite(toolId, favorite);

  Future<void> markRecent(String toolId) => _db.markRecent(toolId);
}
