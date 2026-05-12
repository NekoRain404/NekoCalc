import 'dart:convert';

import '../local/app_database.dart';

class DataBackupRepository {
  const DataBackupRepository(this._db);

  final AppDatabase _db;

  Future<String> exportJson() async {
    final snapshot = await _db.exportSnapshot();
    return const JsonEncoder.withIndent('  ').convert(snapshot);
  }

  Future<void> importJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('备份内容不是有效对象');
    }
    await _db.importSnapshot(decoded.cast<String, Object?>());
  }
}
