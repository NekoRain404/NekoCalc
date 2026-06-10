import 'dart:convert';

const backupSchemaVersion = 1;
const emptyBackupReplaceErrorMessage = '空备份不能用于覆盖恢复，请改用合并导入或选择包含记录的备份。';

// 中文：导入前必须确认所有业务表都存在，避免坏备份把本地数据清空。
// English: Validate every business table before import so a damaged backup cannot wipe local data.
const backupTableNames = [
  'calculation_history',
  'notes',
  'favorite_tools',
  'recent_tools',
  'app_settings',
];

const backupTableLabels = {
  'calculation_history': '历史',
  'notes': '笔记',
  'favorite_tools': '收藏',
  'recent_tools': '最近工具',
  'app_settings': '设置',
};

class BackupTableCount {
  const BackupTableCount({
    required this.name,
    required this.label,
    required this.count,
  });

  final String name;
  final String label;
  final int count;
}

class BackupPreview {
  const BackupPreview({
    required this.schema,
    required this.exportedAt,
    required this.appVersion,
    required this.counts,
  });

  final int schema;
  final String? exportedAt;
  final String? appVersion;
  final Map<String, int> counts;

  int get totalRows => counts.values.fold(0, (sum, count) => sum + count);

  List<BackupTableCount> get tableCounts {
    return [
      for (final tableName in backupTableNames)
        BackupTableCount(
          name: tableName,
          label: backupTableLabels[tableName] ?? tableName,
          count: counts[tableName] ?? 0,
        ),
    ];
  }

  String get summary {
    return tableCounts.map((item) => '${item.label} ${item.count}').join(' · ');
  }

  String get totalLabel => '$totalRows 条记录';
}

enum BackupPreviewWarningSeverity { info, warning, danger }

class BackupPreviewWarning {
  const BackupPreviewWarning({
    required this.severity,
    required this.message,
  });

  final BackupPreviewWarningSeverity severity;
  final String message;
}

List<BackupPreviewWarning> buildBackupPreviewWarnings(
  BackupPreview preview, {
  required DateTime now,
  String? currentAppVersion,
}) {
  final warnings = <BackupPreviewWarning>[];
  if (preview.totalRows == 0) {
    warnings.add(const BackupPreviewWarning(
      severity: BackupPreviewWarningSeverity.danger,
      message: '备份文件没有可恢复记录，覆盖恢复会清空本机数据。',
    ));
  }

  final exportedAt = _parseBackupDateTime(preview.exportedAt);
  if (preview.exportedAt == null || preview.exportedAt!.trim().isEmpty) {
    warnings.add(const BackupPreviewWarning(
      severity: BackupPreviewWarningSeverity.info,
      message: '备份缺少导出时间，无法判断文件新旧。',
    ));
  } else if (exportedAt == null) {
    warnings.add(BackupPreviewWarning(
      severity: BackupPreviewWarningSeverity.warning,
      message: '备份导出时间无法识别：${preview.exportedAt}。',
    ));
  } else {
    final age = now.difference(exportedAt);
    if (age < const Duration(days: -1)) {
      warnings.add(const BackupPreviewWarning(
        severity: BackupPreviewWarningSeverity.warning,
        message: '备份导出时间晚于本机时间，请确认设备时间是否正确。',
      ));
    } else if (age >= const Duration(days: 365)) {
      warnings.add(BackupPreviewWarning(
        severity: BackupPreviewWarningSeverity.warning,
        message: '备份距今约 ${_formatAge(age)}，恢复前建议确认内容是否仍然需要。',
      ));
    } else if (age >= const Duration(days: 90)) {
      warnings.add(BackupPreviewWarning(
        severity: BackupPreviewWarningSeverity.info,
        message: '备份距今约 ${_formatAge(age)}。',
      ));
    }
  }

  final version = preview.appVersion?.trim();
  if (version == null || version.isEmpty) {
    warnings.add(const BackupPreviewWarning(
      severity: BackupPreviewWarningSeverity.info,
      message: '备份缺少应用版本信息。',
    ));
  } else if (currentAppVersion != null &&
      currentAppVersion.trim().isNotEmpty &&
      version != currentAppVersion.trim()) {
    warnings.add(BackupPreviewWarning(
      severity: BackupPreviewWarningSeverity.info,
      message: '备份来自 $version，当前应用为 ${currentAppVersion.trim()}。',
    ));
  }

  return warnings;
}

Map<String, Object?> parseBackupSnapshot(String source) {
  final normalizedSource = _stripBom(source).trim();
  if (normalizedSource.isEmpty) {
    throw const FormatException('备份文件为空');
  }
  final decoded = jsonDecode(normalizedSource);
  if (decoded is! Map) {
    throw const FormatException('备份内容不是有效对象');
  }
  final snapshot = decoded.cast<String, Object?>();
  // 中文：解析和结构校验在进入数据库事务前完成，失败时不会触碰 SQLite。
  // English: Parse and validate before opening the database transaction; failures leave SQLite untouched.
  validateBackupSnapshot(snapshot);
  return snapshot;
}

BackupPreview previewBackupSnapshot(String source) {
  final snapshot = parseBackupSnapshot(source);
  final tables = snapshot['tables'] as Map;
  final metadata = snapshot['metadata'];
  final counts = <String, int>{
    for (final tableName in backupTableNames)
      tableName: (tables[tableName] as List).length,
  };
  return BackupPreview(
    schema: snapshot['schema'] as int? ?? backupSchemaVersion,
    exportedAt: snapshot['exported_at']?.toString(),
    appVersion: metadata is Map ? metadata['app_version']?.toString() : null,
    counts: counts,
  );
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
    final rows = tables[tableName] as List;
    for (var index = 0; index < rows.length; index += 1) {
      final row = rows[index];
      if (row is! Map) {
        throw FormatException(
          '${backupTableLabels[tableName] ?? tableName} 第 ${index + 1} 条记录不是有效对象',
        );
      }
      final rowMap = _stringKeyMap(row, tableName, index);
      _validateBackupTableRow(tableName, rowMap, index);
    }
  }
}

void validateBackupReplacementSnapshot(Map<String, Object?> snapshot) {
  validateBackupSnapshot(snapshot);
  if (backupSnapshotTotalRows(snapshot) == 0) {
    throw const FormatException(emptyBackupReplaceErrorMessage);
  }
}

int backupSnapshotTotalRows(Map<String, Object?> snapshot) {
  final tables = snapshot['tables'];
  if (tables is! Map) {
    throw const FormatException('备份数据缺少 tables 字段');
  }
  var totalRows = 0;
  for (final tableName in backupTableNames) {
    final rows = tables[tableName];
    if (rows is! List) {
      throw FormatException('$tableName 不是有效列表');
    }
    totalRows += rows.length;
  }
  return totalRows;
}

Map<String, Object?> _stringKeyMap(Map row, String tableName, int index) {
  final result = <String, Object?>{};
  for (final entry in row.entries) {
    if (entry.key is! String) {
      throw _backupRowFormatException(tableName, index, '包含非字符串字段名');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _validateBackupTableRow(
  String tableName,
  Map<String, Object?> row,
  int index,
) {
  switch (tableName) {
    case 'calculation_history':
      _requireOptionalInt(row, 'id', tableName, index);
      _requireText(row, 'expression', tableName, index);
      _requireText(row, 'result', tableName, index);
      _requireOptionalText(row, 'tool_id', tableName, index);
      _requireInt(row, 'created_at', tableName, index);
      return;
    case 'notes':
      _requireOptionalInt(row, 'id', tableName, index);
      _requireText(row, 'title', tableName, index);
      _requireOptionalText(row, 'description', tableName, index);
      _requireString(row, 'body', tableName, index);
      _requireInt(row, 'created_at', tableName, index);
      _requireOptionalInt(row, 'updated_at', tableName, index);
      return;
    case 'favorite_tools':
      _requireText(row, 'tool_id', tableName, index);
      _requireInt(row, 'created_at', tableName, index);
      return;
    case 'recent_tools':
      _requireText(row, 'tool_id', tableName, index);
      _requireInt(row, 'used_at', tableName, index);
      return;
    case 'app_settings':
      _requireText(row, 'key', tableName, index);
      _requireString(row, 'value', tableName, index);
      _requireInt(row, 'updated_at', tableName, index);
      return;
  }
}

void _requireText(
  Map<String, Object?> row,
  String key,
  String tableName,
  int index,
) {
  final value = row[key];
  if (value is String && value.trim().isNotEmpty) return;
  throw _backupRowFormatException(tableName, index, '$key 必须是非空字符串');
}

void _requireOptionalText(
  Map<String, Object?> row,
  String key,
  String tableName,
  int index,
) {
  if (!row.containsKey(key) || row[key] == null || row[key] is String) return;
  throw _backupRowFormatException(tableName, index, '$key 必须是字符串');
}

void _requireString(
  Map<String, Object?> row,
  String key,
  String tableName,
  int index,
) {
  if (row[key] is String) return;
  throw _backupRowFormatException(tableName, index, '$key 必须是字符串');
}

void _requireInt(
  Map<String, Object?> row,
  String key,
  String tableName,
  int index,
) {
  if (_isIntegerValue(row[key])) return;
  throw _backupRowFormatException(tableName, index, '$key 必须是整数时间戳');
}

void _requireOptionalInt(
  Map<String, Object?> row,
  String key,
  String tableName,
  int index,
) {
  if (!row.containsKey(key) || row[key] == null || _isIntegerValue(row[key])) {
    return;
  }
  throw _backupRowFormatException(tableName, index, '$key 必须是整数');
}

bool _isIntegerValue(Object? value) {
  if (value is int) return true;
  if (value is num && value.isFinite) return value % 1 == 0;
  if (value is String) return int.tryParse(value.trim()) != null;
  return false;
}

FormatException _backupRowFormatException(
  String tableName,
  int index,
  String reason,
) {
  return FormatException(
    '${backupTableLabels[tableName] ?? tableName} 第 ${index + 1} 条记录字段无效：$reason',
  );
}

String _stripBom(String source) {
  return source.startsWith('\uFEFF') ? source.substring(1) : source;
}

DateTime? _parseBackupDateTime(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return DateTime.tryParse(trimmed);
}

String _formatAge(Duration age) {
  final days = age.inDays;
  if (days >= 365) {
    final years = days ~/ 365;
    return '$years 年';
  }
  if (days >= 30) {
    final months = days ~/ 30;
    return '$months 个月';
  }
  return '$days 天';
}
