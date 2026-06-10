import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/backup_snapshot_validator.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/data_backup_repository.dart';

void main() {
  test('export backup packages json preview file name and messages', () async {
    final db = _FakeDatabase({
      'calculation_history': 3,
      'notes': 2,
      'favorite_tools': 1,
      'recent_tools': 4,
      'app_settings': 5,
    });
    final repository = DataBackupRepository(db);

    final result = await repository.exportBackup(
      createdAt: DateTime(2026, 6, 8, 10, 9),
    );
    final decoded = jsonDecode(result.content) as Map<String, Object?>;

    expect(result.fileName, 'nekocalc-backup-20260608-1009.json');
    expect(result.preview.totalRows, 15);
    expect(result.preview.summary, contains('历史 3'));
    expect(result.successMessage, '备份已保存：15 条记录');
    expect(result.detail, contains(result.fileName));
    expect(result.detail, contains('总计：15 条记录'));
    expect(decoded['tables'], isA<Map>());
  });

  test('current preview summarizes local database counts', () async {
    final db = _FakeDatabase({
      'calculation_history': 3,
      'notes': 2,
      'favorite_tools': 1,
      'recent_tools': 4,
      'app_settings': 5,
    });
    final repository = DataBackupRepository(db);

    final preview = await repository.currentPreview();

    expect(preview.totalRows, 15);
    expect(preview.summary, contains('历史 3'));
    expect(preview.summary, contains('设置 5'));
    expect(preview.tableCounts.map((item) => item.label),
        ['历史', '笔记', '收藏', '最近工具', '设置']);
  });

  test('import report compares source before and after counts', () async {
    final db = _FakeDatabase({
      'calculation_history': 2,
      'notes': 1,
      'favorite_tools': 0,
      'recent_tools': 1,
      'app_settings': 3,
    });
    final repository = DataBackupRepository(db);

    final report = await repository.importJson(
      _snapshotJson({
        'calculation_history': 4,
        'notes': 2,
        'favorite_tools': 1,
        'recent_tools': 3,
        'app_settings': 2,
      }),
      replaceExisting: true,
    );

    expect(report.modeLabel, '覆盖恢复');
    expect(report.source.totalRows, 12);
    expect(report.before.totalRows, 7);
    expect(report.after.totalRows, 12);
    expect(report.deltaFor('calculation_history'), 2);
    expect(report.deltaFor('app_settings'), -1);
    expect(report.skippedFor('calculation_history'), 0);
    expect(report.tableReports.first.label, '历史');
    expect(report.tableReports.first.source, 4);
    expect(report.tableReports.first.before, 2);
    expect(report.tableReports.first.after, 4);
    expect(report.tableReports.first.skipped, 0);
    expect(report.resultLabel, '已恢复 12 条记录');
    expect(report.summary, contains('历史 4 (+2)'));
    expect(report.summary, contains('设置 2 (-1)'));
    expect(db.replaceExisting, isTrue);
  });

  test('merge import report allows positive deltas without replacing counts',
      () async {
    final db = _FakeDatabase({
      'calculation_history': 2,
      'notes': 1,
      'favorite_tools': 0,
      'recent_tools': 1,
      'app_settings': 3,
    });
    final repository = DataBackupRepository(db);

    final report = await repository.importJson(
      _snapshotJson({
        'calculation_history': 2,
        'notes': 2,
        'favorite_tools': 1,
        'recent_tools': 1,
        'app_settings': 1,
      }),
      replaceExisting: false,
    );

    expect(report.modeLabel, '合并导入');
    expect(report.before.totalRows, 7);
    expect(report.after.totalRows, 14);
    expect(report.deltaFor('notes'), 2);
    expect(report.deltaFor('app_settings'), 1);
    expect(report.skippedFor('notes'), 0);
    expect(report.resultLabel, '已合并 7 条记录');
    expect(db.replaceExisting, isFalse);
  });

  test('import report exposes merge rows skipped by retention limits',
      () async {
    final db = _FakeDatabase({
      'calculation_history': 490,
      'notes': 1,
      'favorite_tools': 0,
      'recent_tools': 20,
      'app_settings': 0,
    });
    final repository = DataBackupRepository(db);

    final report = await repository.importJson(
      _snapshotJson({
        'calculation_history': 40,
        'notes': 2,
        'favorite_tools': 0,
        'recent_tools': 10,
        'app_settings': 0,
      }),
      replaceExisting: false,
    );

    expect(report.deltaFor('calculation_history'), 10);
    expect(report.skippedFor('calculation_history'), 30);
    expect(report.deltaFor('recent_tools'), 4);
    expect(report.skippedFor('recent_tools'), 6);
    expect(report.resultLabel, '已合并 16 条记录，跳过或裁剪 36 条');
    expect(report.summary, contains('历史 500 (+10, 跳过 30)'));
    expect(report.summary, contains('最近工具 24 (+4, 跳过 6)'));
  });

  test('replace import rejects empty backups before touching database',
      () async {
    final db = _FakeDatabase({
      'calculation_history': 2,
      'notes': 1,
      'favorite_tools': 0,
      'recent_tools': 1,
      'app_settings': 3,
    });
    final repository = DataBackupRepository(db);
    final source = _snapshotJson({
      for (final tableName in backupTableNames) tableName: 0,
    });

    await expectLater(
      repository.importJson(source, replaceExisting: true),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          emptyBackupReplaceErrorMessage,
        ),
      ),
    );

    expect(db.importCallCount, 0);
    expect(db.replaceExisting, isNull);
  });

  test('merge import accepts empty backups without clearing local counts',
      () async {
    final db = _FakeDatabase({
      'calculation_history': 2,
      'notes': 1,
      'favorite_tools': 0,
      'recent_tools': 1,
      'app_settings': 3,
    });
    final repository = DataBackupRepository(db);

    final report = await repository.importJson(
      _snapshotJson({
        for (final tableName in backupTableNames) tableName: 0,
      }),
      replaceExisting: false,
    );

    expect(report.modeLabel, '合并导入');
    expect(report.before.totalRows, 7);
    expect(report.after.totalRows, 7);
    expect(db.importCallCount, 1);
    expect(db.replaceExisting, isFalse);
  });

  test('import plans compare source local and expected table counts', () async {
    final db = _FakeDatabase({
      'calculation_history': 2,
      'notes': 1,
      'favorite_tools': 1,
      'recent_tools': 4,
      'app_settings': 3,
    });
    final repository = DataBackupRepository(db);
    final source = _snapshotJson({
      'calculation_history': 4,
      'notes': 2,
      'favorite_tools': 0,
      'recent_tools': 3,
      'app_settings': 2,
    });

    final replace = await repository.planImport(
      source,
      replaceExisting: true,
    );
    final merge = await repository.planImport(
      source,
      replaceExisting: false,
    );

    expect(replace.modeLabel, '覆盖恢复');
    expect(replace.totalLabel, '11 条记录');
    expect(replace.expectedTotal, 11);
    expect(replace.beforeFor('favorite_tools'), 1);
    expect(replace.sourceFor('favorite_tools'), 0);
    expect(replace.expectedFor('favorite_tools'), 0);
    expect(replace.deltaFor('favorite_tools'), -1);
    expect(replace.summary, contains('收藏 0 (-1)'));

    expect(merge.modeLabel, '合并导入');
    expect(merge.totalLabel, '最多 22 条记录');
    expect(merge.expectedTotal, 22);
    expect(merge.beforeFor('calculation_history'), 2);
    expect(merge.sourceFor('calculation_history'), 4);
    expect(merge.expectedFor('calculation_history'), 6);
    expect(merge.deltaFor('calculation_history'), 4);
    expect(merge.summary, contains('历史 6 (+4)'));
  });

  test('import plans respect capped history and recent tool retention counts',
      () async {
    final db = _FakeDatabase({
      'calculation_history': 490,
      'notes': 1,
      'favorite_tools': 0,
      'recent_tools': 20,
      'app_settings': 0,
    });
    final repository = DataBackupRepository(db);
    final source = _snapshotJson({
      'calculation_history': 40,
      'notes': 2,
      'favorite_tools': 0,
      'recent_tools': 10,
      'app_settings': 0,
    });

    final merge = await repository.planImport(
      source,
      replaceExisting: false,
    );
    final replace = await repository.planImport(
      _snapshotJson({
        'calculation_history': 520,
        'notes': 0,
        'favorite_tools': 0,
        'recent_tools': 30,
        'app_settings': 0,
      }),
      replaceExisting: true,
    );

    expect(
        merge.expectedFor('calculation_history'), AppDatabase.maxHistoryRows);
    expect(merge.deltaFor('calculation_history'), 10);
    expect(merge.expectedFor('recent_tools'), AppDatabase.maxRecentToolRows);
    expect(merge.deltaFor('recent_tools'), 4);
    expect(merge.totalLabel, '最多 527 条记录');
    expect(merge.summary, contains('历史 500 (+10)'));
    expect(merge.summary, contains('最近工具 24 (+4)'));

    expect(
        replace.expectedFor('calculation_history'), AppDatabase.maxHistoryRows);
    expect(replace.expectedFor('recent_tools'), AppDatabase.maxRecentToolRows);
    expect(replace.totalLabel, '524 条记录');
  });

  test('import plans expose actionable merge and replace impacts', () async {
    final db = _FakeDatabase({
      'calculation_history': 5,
      'notes': 3,
      'favorite_tools': 2,
      'recent_tools': 4,
      'app_settings': 3,
    });
    final repository = DataBackupRepository(db);
    final source = _snapshotJson({
      'calculation_history': 1,
      'notes': 0,
      'favorite_tools': 1,
      'recent_tools': 2,
      'app_settings': 1,
    });

    final replace = await repository.planImport(
      source,
      replaceExisting: true,
    );
    final merge = await repository.planImport(
      source,
      replaceExisting: false,
    );

    expect(
      replace.impacts.map((impact) => impact.message),
      containsAll([
        '笔记 将删除本机 3 条',
        '历史 将减少 4 条',
        '会覆盖本机历史、收藏、最近工具、设置数据',
      ]),
    );
    expect(
      replace.impacts
          .where(
              (impact) => impact.severity == BackupImportImpactSeverity.danger)
          .map((impact) => impact.icon),
      contains(BackupImportImpactIcon.delete),
    );

    expect(
      merge.impacts.map((impact) => impact.message),
      containsAll([
        '会保留本机数据，并尝试加入 历史 +1、收藏 +1、最近工具 +2、设置 +1',
        '设置项可能按备份内容更新',
        '最近工具只保留最新 24 条',
        '历史记录合并后仍会保留最近 500 条',
      ]),
    );
  });

  test(
      'empty merge and replace impacts describe safe fallback and blocked replace',
      () async {
    final db = _FakeDatabase({
      'calculation_history': 1,
      'notes': 0,
      'favorite_tools': 0,
      'recent_tools': 0,
      'app_settings': 0,
    });
    final repository = DataBackupRepository(db);
    final source = _snapshotJson({
      for (final tableName in backupTableNames) tableName: 0,
    });

    final replace = await repository.planImport(
      source,
      replaceExisting: true,
    );
    final merge = await repository.planImport(
      source,
      replaceExisting: false,
    );

    expect(replace.impacts.first.message, emptyBackupReplaceErrorMessage);
    expect(replace.impacts.first.severity, BackupImportImpactSeverity.danger);
    expect(merge.impacts.single.message, '备份为空，合并导入不会改变本机数据');
  });

  test('import rejects malformed table rows before touching database',
      () async {
    final db = _FakeDatabase({
      'calculation_history': 2,
      'notes': 1,
      'favorite_tools': 0,
      'recent_tools': 1,
      'app_settings': 3,
    });
    final repository = DataBackupRepository(db);

    final source = jsonEncode({
      'schema': backupSchemaVersion,
      'tables': {
        for (final tableName in backupTableNames)
          tableName: _rowsForTable(tableName, 0),
        'recent_tools': ['bad-row'],
      },
    });

    await expectLater(
      repository.importJson(source),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('最近工具 第 1 条记录不是有效对象'),
        ),
      ),
    );
    expect(db.importCallCount, 0);
    expect(db.replaceExisting, isNull);
  });
}

String _snapshotJson(Map<String, int> counts) {
  return jsonEncode({
    'schema': backupSchemaVersion,
    'exported_at': '2026-06-08T10:00:00.000',
    'metadata': {'app_version': 'v1.1.0'},
    'tables': {
      for (final tableName in backupTableNames)
        tableName: _rowsForTable(tableName, counts[tableName] ?? 0),
    },
  });
}

List<Map<String, Object?>> _rowsForTable(String tableName, int count) {
  return List.generate(count, (index) {
    final id = index + 1;
    final timestamp = 1000 + index;
    return switch (tableName) {
      'calculation_history' => {
          'id': id,
          'expression': '2+$id',
          'result': '${2 + id}',
          'tool_id': null,
          'created_at': timestamp,
        },
      'notes' => {
          'id': id,
          'title': '笔记 $id',
          'description': '描述 $id',
          'body': '内容 $id',
          'created_at': timestamp,
          'updated_at': timestamp + 1,
        },
      'favorite_tools' => {
          'tool_id': 'favorite_tool_$id',
          'created_at': timestamp,
        },
      'recent_tools' => {
          'tool_id': 'recent_tool_$id',
          'used_at': timestamp,
        },
      'app_settings' => {
          'key': 'setting_$id',
          'value': 'value_$id',
          'updated_at': timestamp,
        },
      _ => <String, Object?>{},
    };
  });
}

class _FakeDatabase implements AppDatabase {
  _FakeDatabase(Map<String, int> counts)
      : _counts = Map<String, int>.from(counts);

  final Map<String, int> _counts;
  bool? replaceExisting;
  int importCallCount = 0;

  @override
  Future<Map<String, int>> backupTableCounts() async {
    return Map<String, int>.from(_counts);
  }

  @override
  Future<Map<String, Object?>> exportSnapshot() async {
    return {
      'schema': backupSchemaVersion,
      'exported_at': '2026-06-08T10:00:00.000',
      'metadata': {'app_version': 'v1.1.0'},
      'tables': {
        for (final tableName in backupTableNames)
          tableName: _rowsForTable(tableName, _counts[tableName] ?? 0),
      },
    };
  }

  @override
  Future<void> importSnapshot(
    Map<String, Object?> snapshot, {
    bool replaceExisting = true,
  }) async {
    importCallCount += 1;
    this.replaceExisting = replaceExisting;
    final tables = snapshot['tables'] as Map;
    for (final tableName in backupTableNames) {
      final importedCount = (tables[tableName] as List).length;
      _counts[tableName] = replaceExisting
          ? importedCount
          : (_counts[tableName] ?? 0) + importedCount;
    }
    _counts['calculation_history'] =
        (_counts['calculation_history'] ?? 0).clamp(
      0,
      AppDatabase.maxHistoryRows,
    );
    _counts['recent_tools'] = (_counts['recent_tools'] ?? 0).clamp(
      0,
      AppDatabase.maxRecentToolRows,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
