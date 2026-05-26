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

  test('parses valid json backup content', () {
    final source = jsonEncode({
      'schema': 1,
      'tables': {
        for (final tableName in backupTableNames) tableName: <Object?>[],
      },
    });

    expect(parseBackupSnapshot(source)['schema'], 1);
  });

  test('creates a useful backup preview', () {
    final source = jsonEncode({
      'schema': 1,
      'exported_at': '2026-05-26T09:00:00.000',
      'metadata': {'app_version': 'v1.1.0'},
      'tables': {
        'calculation_history': [{}, {}],
        'notes': [{}],
        'favorite_tools': [],
        'recent_tools': [{}, {}, {}],
        'app_settings': [{}],
      },
    });

    final preview = previewBackupSnapshot(source);
    expect(preview.appVersion, 'v1.1.0');
    expect(preview.totalRows, 7);
    expect(preview.summary, contains('历史 2'));
    expect(preview.summary, contains('笔记 1'));
  });
}
