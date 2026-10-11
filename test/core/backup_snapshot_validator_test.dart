import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/backup_snapshot_validator.dart';
import 'package:nekocalc/features/settings/presentation/settings_backup_messages.dart';
import 'package:nekocalc/features/settings/presentation/settings_backup_strings.dart';
import 'package:nekocalc/features/settings/presentation/settings_backup_text.dart';
import 'package:nekocalc/l10n/app_language.dart';

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
          // 中文：技术串里点的是**表名（键）**——表名标签这一轮搬进了文案表，异常这条诊断路径够不着它
          //       （见 `settings_backup_strings.dart` 的文件头）。
          // English: the technical string names the **table key** — the table labels moved into the copy
          //          table this round and this diagnostic path cannot reach it (see
          //          `settings_backup_strings.dart`'s file head).
          contains('notes 第 2 条记录不是有效对象'),
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
          contains('app_settings 第 1 条记录字段无效：value 必须是字符串'),
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
    expect(backupPreviewTableSummary(preview, _zh), contains('历史 2'));
    expect(backupPreviewTableSummary(preview, _zh), contains('笔记 1'));
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
    // 中文：抛的是那枚 **ASCII 令牌**，不是句子——用户读到的那句话住在 `SettingsBackupStrings` 的
    //       `backupImpactEmptySource` 里，由 `backupImportFailureMessage` 在呈现边缘按令牌取；那条
    //       接线与迁移前那句话的逐字节对照钉在 `settings_backup_messages_test.dart` 里。
    // English: what is thrown is the **ASCII token**, not the sentence — the words the user reads live in
    //          `SettingsBackupStrings`'s `backupImpactEmptySource` and are fetched at the presentation
    //          edge by `backupImportFailureMessage`; that wiring, and its byte-for-byte copy of the
    //          pre-move sentence, are pinned in `settings_backup_messages_test.dart`.
    expect(
      () => validateBackupReplacementSnapshot(emptySnapshot),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          emptyBackupReplaceErrorToken,
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
      oldWarnings.map(_warningText).join('\n'),
      contains('没有可恢复记录'),
    );
    expect(
      oldWarnings.map(_warningText).join('\n'),
      contains('距今约 1 年'),
    );
    expect(
      oldWarnings.map(_warningText).join('\n'),
      contains('备份来自 v1.0.0'),
    );
    expect(
      oldWarnings
          .firstWhere((warning) => _warningText(warning).contains('没有可恢复记录'))
          .severity,
      BackupPreviewWarningSeverity.danger,
    );
    expect(
      futureWarnings.map(_warningText).join('\n'),
      contains('晚于本机时间'),
    );
    expect(
      missingWarnings.map(_warningText).join('\n'),
      contains('缺少导出时间'),
    );
    expect(
      missingWarnings.map(_warningText).join('\n'),
      contains('缺少应用版本信息'),
    );
  });
}

// 中文：警告上的句子不再住在 `BackupPreviewWarning` 上（领域对象活得比界面长），这里按呈现边缘
//       那条路渲染成中文——下面这些断言量到的还是原来那几句话。
// English: the sentences no longer live on `BackupPreviewWarning` (a domain object outlives the UI);
//          they are rendered here through the presentation edge in Chinese — the assertions below
//          still measure the very same sentences.
final _zh = SettingsBackupStrings.forLanguage(AppLanguage.zh);

String _warningText(BackupPreviewWarning warning) {
  return backupPreviewWarningMessage(warning, _zh);
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
