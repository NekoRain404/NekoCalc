import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/backup_snapshot_validator.dart';

void main() {
  // 中文：备份校验测试确保坏文件在进入数据库事务前被拦截。
  // English: Backup validation tests ensure bad files are rejected before database transactions.
  test('accepts a complete backup snapshot', () {
    final snapshot = {
      'schema': 1,
      'tables': {
        for (final tableName in backupTableNames) tableName: <Object?>[],
      },
    };

    expect(() => validateBackupSnapshot(snapshot), returnsNormally);
  });

  test('rejects missing tables before database import', () {
    final snapshot = {
      'schema': 1,
      'tables': {
        'notes': <Object?>[],
      },
    };

    expect(
      () => validateBackupSnapshot(snapshot),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects unsupported schema versions', () {
    final snapshot = {
      'schema': 99,
      'tables': {
        for (final tableName in backupTableNames) tableName: <Object?>[],
      },
    };

    expect(
      () => validateBackupSnapshot(snapshot),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects table rows that are not json objects', () {
    final snapshot = {
      'schema': 1,
      'tables': {
        for (final tableName in backupTableNames) tableName: <Object?>[],
        'notes': [
          _noteRow(1),
          'bad-row',
        ],
      },
    };

    expect(
      () => validateBackupSnapshot(snapshot),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('笔记 第 2 条记录不是有效对象'),
        ),
      ),
    );
  });

  test('rejects table rows with invalid field types before import', () {
    final snapshot = {
      'schema': 1,
      'tables': {
        for (final tableName in backupTableNames) tableName: <Object?>[],
        'app_settings': [
          {'key': 'theme_mode', 'value': 42, 'updated_at': 1000},
        ],
      },
    };

    expect(
      () => validateBackupSnapshot(snapshot),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('设置 第 1 条记录字段无效：value 必须是字符串'),
        ),
      ),
    );
  });

  test('parses valid json backup content', () {
    final source = jsonEncode({
      'schema': 1,
      'tables': {
        for (final tableName in backupTableNames) tableName: <Object?>[],
      },
    });

    expect(parseBackupSnapshot(source)['schema'], 1);
  });

  test('parses backup content with byte order mark', () {
    final source = '\uFEFF${jsonEncode({
          'schema': 1,
          'tables': {
            for (final tableName in backupTableNames) tableName: <Object?>[],
          },
        })}';

    expect(parseBackupSnapshot(source)['schema'], 1);
  });

  test('creates a useful backup preview', () {
    final source = jsonEncode({
      'schema': 1,
      'exported_at': '2026-05-26T09:00:00.000',
      'metadata': {'app_version': 'v1.1.0'},
      'tables': {
        'calculation_history': [_historyRow(1), _historyRow(2)],
        'notes': [_noteRow(1)],
        'favorite_tools': [],
        'recent_tools': [
          _recentToolRow('ohms_law', 1),
          _recentToolRow('data_fit', 2),
          _recentToolRow('json_format', 3),
        ],
        'app_settings': [_settingRow('theme_mode', '跟随系统')],
      },
    });

    final preview = previewBackupSnapshot(source);
    expect(preview.appVersion, 'v1.1.0');
    expect(preview.totalRows, 7);
    expect(preview.summary, contains('历史 2'));
    expect(preview.summary, contains('笔记 1'));
  });

  test('rejects empty snapshots for replacement imports', () {
    final emptySnapshot = {
      'schema': 1,
      'tables': {
        for (final tableName in backupTableNames) tableName: <Object?>[],
      },
    };
    final nonEmptySnapshot = {
      'schema': 1,
      'tables': {
        for (final tableName in backupTableNames) tableName: <Object?>[],
        'notes': [_noteRow(1)],
      },
    };

    expect(backupSnapshotTotalRows(emptySnapshot), 0);
    expect(
      () => validateBackupReplacementSnapshot(emptySnapshot),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          emptyBackupReplaceErrorMessage,
        ),
      ),
    );
    expect(backupSnapshotTotalRows(nonEmptySnapshot), 1);
    expect(
      () => validateBackupReplacementSnapshot(nonEmptySnapshot),
      returnsNormally,
    );
  });

  test('builds backup preview warnings from metadata and age', () {
    final emptyOldBackup = BackupPreview(
      schema: backupSchemaVersion,
      exportedAt: '2025-01-01T00:00:00.000',
      appVersion: 'v1.0.0',
      counts: {for (final tableName in backupTableNames) tableName: 0},
    );
    final futureBackup = BackupPreview(
      schema: backupSchemaVersion,
      exportedAt: '2026-06-12T00:00:00.000',
      appVersion: 'v1.1.0',
      counts: {
        for (final tableName in backupTableNames)
          tableName: tableName == 'notes' ? 1 : 0,
      },
    );
    final missingMetadata = BackupPreview(
      schema: backupSchemaVersion,
      exportedAt: null,
      appVersion: null,
      counts: {
        for (final tableName in backupTableNames)
          tableName: tableName == 'notes' ? 1 : 0,
      },
    );

    final oldWarnings = buildBackupPreviewWarnings(
      emptyOldBackup,
      now: DateTime(2026, 6, 9),
      currentAppVersion: 'v1.1.0',
    );
    final futureWarnings = buildBackupPreviewWarnings(
      futureBackup,
      now: DateTime(2026, 6, 9),
      currentAppVersion: 'v1.1.0',
    );
    final missingWarnings = buildBackupPreviewWarnings(
      missingMetadata,
      now: DateTime(2026, 6, 9),
      currentAppVersion: 'v1.1.0',
    );

    expect(
      oldWarnings.map((warning) => warning.message).join('\n'),
      contains('没有可恢复记录'),
    );
    expect(
      oldWarnings.map((warning) => warning.message).join('\n'),
      contains('距今约 1 年'),
    );
    expect(
      oldWarnings.map((warning) => warning.message).join('\n'),
      contains('备份来自 v1.0.0'),
    );
    expect(
      oldWarnings
          .firstWhere((warning) => warning.message.contains('没有可恢复记录'))
          .severity,
      BackupPreviewWarningSeverity.danger,
    );
    expect(
      futureWarnings.map((warning) => warning.message).join('\n'),
      contains('晚于本机时间'),
    );
    expect(
      missingWarnings.map((warning) => warning.message).join('\n'),
      contains('缺少导出时间'),
    );
    expect(
      missingWarnings.map((warning) => warning.message).join('\n'),
      contains('缺少应用版本信息'),
    );
  });
}

Map<String, Object?> _historyRow(int id) {
  return {
    'id': id,
    'expression': '2+$id',
    'result': '${2 + id}',
    'tool_id': null,
    'created_at': 1000 + id,
  };
}

Map<String, Object?> _noteRow(int id) {
  return {
    'id': id,
    'title': '笔记 $id',
    'description': '描述 $id',
    'body': '内容 $id',
    'created_at': 2000 + id,
    'updated_at': 3000 + id,
  };
}

Map<String, Object?> _recentToolRow(String toolId, int index) {
  return {
    'tool_id': toolId,
    'used_at': 4000 + index,
  };
}

Map<String, Object?> _settingRow(String key, String value) {
  return {
    'key': key,
    'value': value,
    'updated_at': 5000,
  };
}
