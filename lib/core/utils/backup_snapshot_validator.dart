import 'dart:convert';

const backupSchemaVersion = 1;

// 中文：导入前必须确认所有业务表都存在，避免坏备份把本地数据清空。
// English: Validate every business table before import so a damaged backup cannot wipe local data.
const backupTableNames = [
  'calculation_history',
  'notes',
  'favorite_tools',
  'recent_tools',
  'app_settings',
];

Map<String, Object?> parseBackupSnapshot(String source) {
  if (source.trim().isEmpty) {
    throw const FormatException('备份文件为空');
  }
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('备份内容不是有效对象');
  }
  final snapshot = decoded.cast<String, Object?>();
  // 中文：解析和结构校验在进入数据库事务前完成，失败时不会触碰 SQLite。
  // English: Parse and validate before opening the database transaction; failures leave SQLite untouched.
  validateBackupSnapshot(snapshot);
  return snapshot;
}

void validateBackupSnapshot(Map<String, Object?> snapshot) {
  final schema = snapshot['schema'];
  if (schema != null && schema != backupSchemaVersion) {
    throw FormatException('不支持的备份版本：$schema');
  }
  final tables = snapshot['tables'];
  if (tables is! Map) {
    throw const FormatException('备份数据缺少 tables 字段');
  }
  for (final tableName in backupTableNames) {
    if (!tables.containsKey(tableName)) {
      throw FormatException('备份数据缺少 $tableName 表');
    }
    if (tables[tableName] is! List) {
      throw FormatException('$tableName 不是有效列表');
    }
  }
}
