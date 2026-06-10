import '../local/app_database.dart';
import '../models/history_item.dart';

class HistoryRepository {
  const HistoryRepository(this._db);

  final AppDatabase _db;

  Future<int> saveCalculation({
    required String expression,
    required String result,
    DateTime? createdAt,
  }) {
    return _db.addHistory(
        expression: expression, result: result, createdAt: createdAt);
  }

  Future<int> saveToolResult({
    required String toolId,
    required String expression,
    required String result,
    DateTime? createdAt,
  }) {
    return _db.addHistory(
        expression: expression,
        result: result,
        toolId: toolId,
        createdAt: createdAt);
  }

  Future<List<HistoryItem>> list({
    int limit = 50,
    int offset = 0,
    String? query,
    String? toolId,
  }) {
    return _db.history(
        limit: limit, offset: offset, query: query, toolId: toolId);
  }

  Future<int> count({String? query, String? toolId}) {
    return _db.historyCount(query: query, toolId: toolId);
  }

  Future<int> delete(int id) => _db.deleteHistory(id);

  Future<int> deleteMany(Iterable<int> ids) => _db.deleteHistoryItems(ids);

  Future<int> clear() => _db.clearHistory();
}
