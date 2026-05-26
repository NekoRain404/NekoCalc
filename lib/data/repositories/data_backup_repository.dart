import 'dart:convert';

import '../../core/utils/backup_snapshot_validator.dart';
import '../local/app_database.dart';

class DataBackupRepository {
  const DataBackupRepository(this._db);

  final AppDatabase _db;

  Future<String> exportJson() async {
    final snapshot = await _db.exportSnapshot();
    return const JsonEncoder.withIndent('  ').convert(snapshot);
  }

  Future<void> importJson(String source) async {
    // 中文：仓库层只接受已校验快照，避免 UI 层传入半截 JSON 时清库。
    // English: Import only validated snapshots so partial JSON from the UI cannot clear the database.
    await _db.importSnapshot(parseBackupSnapshot(source));
  }

  BackupPreview previewJson(String source) {
    return previewBackupSnapshot(source);
  }
}
