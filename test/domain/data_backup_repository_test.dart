import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/backup_snapshot_validator.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/data_backup_repository.dart';
import 'package:nekocalc/features/settings/presentation/settings_backup_messages.dart';
import 'package:nekocalc/features/settings/presentation/settings_backup_strings.dart';
import 'package:nekocalc/features/settings/presentation/settings_backup_text.dart';
import 'package:nekocalc/l10n/app_language.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
    expect(backupPreviewTableSummary(result.preview, _zh), contains('历史 3'));
    expect(backupExportSuccessMessage(result, _zh), '备份已保存：15 条记录');
    expect(backupExportDetail(result, _zh), contains(result.fileName));
    expect(backupExportDetail(result, _zh), contains('总计：15 条记录'));
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
    expect(backupPreviewTableSummary(preview, _zh), contains('历史 3'));
    expect(backupPreviewTableSummary(preview, _zh), contains('设置 5'));
    expect(preview.tableCounts.map((item) => backupTableLabel(item.name, _zh)),
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

    expect(backupReportModeLabel(report, _zh), '覆盖恢复');
    expect(report.source.totalRows, 12);
    expect(report.before.totalRows, 7);
    expect(report.after.totalRows, 12);
    expect(report.deltaFor('calculation_history'), 2);
    expect(report.deltaFor('app_settings'), -1);
    expect(report.skippedFor('calculation_history'), 0);
    expect(backupTableLabel(report.tableReports.first.name, _zh), '历史');
    expect(report.tableReports.first.source, 4);
    expect(report.tableReports.first.before, 2);
    expect(report.tableReports.first.after, 4);
    expect(report.tableReports.first.skipped, 0);
    expect(backupReportResultLabel(report, _zh), '已恢复 12 条记录');
    expect(backupReportSummary(report, _zh), contains('历史 4 (+2)'));
    expect(backupReportSummary(report, _zh), contains('设置 2 (-1)'));
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

    expect(backupReportModeLabel(report, _zh), '合并导入');
    expect(report.before.totalRows, 7);
    expect(report.after.totalRows, 14);
    expect(report.deltaFor('notes'), 2);
    expect(report.deltaFor('app_settings'), 1);
    expect(report.skippedFor('notes'), 0);
    expect(backupReportResultLabel(report, _zh), '已合并 7 条记录');
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
    expect(backupReportResultLabel(report, _zh), '已合并 16 条记录，跳过或裁剪 36 条');
    expect(backupReportSummary(report, _zh), contains('历史 500 (+10, 跳过 30)'));
    expect(backupReportSummary(report, _zh), contains('最近工具 24 (+4, 跳过 6)'));
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

    // 中文：数据层抛的是校验器那枚令牌（不是句子）：用户读到的那句话由呈现边缘的
    //       `backupImportFailureMessage` 按令牌取，对照钉在 `settings_backup_messages_test.dart` 里。
    // English: the data layer throws the validator's token (not a sentence): the words the user reads
    //          are fetched from the token at the presentation edge by `backupImportFailureMessage`,
    //          pinned in `settings_backup_messages_test.dart`.
    await expectLater(
      repository.importJson(source, replaceExisting: true),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          emptyBackupReplaceErrorToken,
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

    expect(backupReportModeLabel(report, _zh), '合并导入');
    expect(report.before.totalRows, 7);
    expect(report.after.totalRows, 7);
    expect(db.importCallCount, 1);
    expect(db.replaceExisting, isFalse);
  });

  // ——— 缺口 4：此前没有任何一条 fixture 让**本机侧从零开始** ———
  // 中文：这一条补的是报告算术那一层（本机 0 条 ⇒ 增量必须等于备份的行数），真库那一层在下面的
  //       `_freshInstallImportTests()` 里，判据是表本身。
  // English: this covers the report arithmetic layer (local zero ⇒ every delta equals the backup's
  //          count); the real-database layer is in `_freshInstallImportTests()` below, where the
  //          criterion is the tables themselves.
  test('新装：本机五张表全空时，覆盖导入后每张表的行数就是备份里的那个数', () async {
    final db = _FakeDatabase({
      for (final tableName in backupTableNames) tableName: 0,
    });
    final repository = DataBackupRepository(db);
    const backupCounts = {
      'calculation_history': 4,
      'notes': 2,
      'favorite_tools': 0,
      'recent_tools': 3,
      'app_settings': 2,
    };

    final report = await repository.importJson(
      _snapshotJson(backupCounts),
      replaceExisting: true,
    );

    expect(report.before.totalRows, 0, reason: '这一侧的前提就是一条本机记录都没有');
    expect(report.after.totalRows, 11);
    for (final tableName in backupTableNames) {
      expect(report.sourceFor(tableName), backupCounts[tableName]);
      expect(report.afterFor(tableName), backupCounts[tableName],
          reason: '$tableName：导入后的行数必须就是备份里的行数，多一行就是幽灵行');
      expect(report.deltaFor(tableName), backupCounts[tableName],
          reason: '本机从零开始，增量就是备份的行数');
      expect(report.skippedFor(tableName), 0, reason: '覆盖导入不裁剪、不跳过任何一行');
    }
    expect(backupReportResultLabel(report, _zh), '已恢复 11 条记录');
    expect(db.replaceExisting, isTrue);
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

    expect(backupPlanModeLabel(replace, _zh), '覆盖恢复');
    expect(backupPlanTotalLabel(replace, _zh), '11 条记录');
    expect(replace.expectedTotal, 11);
    expect(replace.beforeFor('favorite_tools'), 1);
    expect(replace.sourceFor('favorite_tools'), 0);
    expect(replace.expectedFor('favorite_tools'), 0);
    expect(replace.deltaFor('favorite_tools'), -1);
    expect(backupPlanSummary(replace, _zh), contains('收藏 0 (-1)'));

    expect(backupPlanModeLabel(merge, _zh), '合并导入');
    expect(backupPlanTotalLabel(merge, _zh), '最多 22 条记录');
    expect(merge.expectedTotal, 22);
    expect(merge.beforeFor('calculation_history'), 2);
    expect(merge.sourceFor('calculation_history'), 4);
    expect(merge.expectedFor('calculation_history'), 6);
    expect(merge.deltaFor('calculation_history'), 4);
    expect(backupPlanSummary(merge, _zh), contains('历史 6 (+4)'));
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
    expect(backupPlanTotalLabel(merge, _zh), '最多 527 条记录');
    expect(backupPlanSummary(merge, _zh), contains('历史 500 (+10)'));
    expect(backupPlanSummary(merge, _zh), contains('最近工具 24 (+4)'));

    expect(
        replace.expectedFor('calculation_history'), AppDatabase.maxHistoryRows);
    expect(replace.expectedFor('recent_tools'), AppDatabase.maxRecentToolRows);
    expect(backupPlanTotalLabel(replace, _zh), '524 条记录');
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
      replace.impacts.map(_impactText),
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
      merge.impacts.map(_impactText),
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

    expect(_impactText(replace.impacts.first),
        '空备份不能用于覆盖恢复，请改用合并导入或选择包含记录的备份。');
    expect(replace.impacts.first.severity, BackupImportImpactSeverity.danger);
    expect(_impactText(merge.impacts.single), '备份为空，合并导入不会改变本机数据');
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
          contains('recent_tools 第 1 条记录不是有效对象'),
        ),
      ),
    );
    expect(db.importCallCount, 0);
    expect(db.replaceExisting, isNull);
  });

  _freshInstallImportTests();
}

/// 中文：**在一个真的新装的库上做一次导入。** 上面那些用例用的都是假库——假库报回来的行数是假库
///       自己算的，所以"导入之后每张表的行数就是备份的行数"这句话在假库上量不到底。这一组用真的
///       SQLite（系统 `libsqlite3`，经 `sqflite_common_ffi`）：库从**零**建起（`onCreate` 真的跑），
///       走用户那条路（`DataBackupRepository.importJson`：解析 → 校验 → 清空 → 写入 → 重数），最后
///       **直接查表**核对行数与内容。
///
///       **"新装"与"接近全新"这两个前提都是量出来的**，不是假设的：第一条先数一遍五张表（必须全 0），
///       第二条先往五张表各写一行本机数据（必须各 1）。第二条才是"幽灵行"真正的判据——备份里没有的
///       那些本机行（一条收藏、一条最近、一个本机独有的设置项）必须**在这个世界上消失**。
///
///       **为什么这一组能住在这个文件里、不去挤 `app_database_v7_test.dart`**：那里记过一条教训——
///       `AppDatabase` 走的是真库的**默认路径**（`getDatabasesPath()` 下的 `nekocalc.db`），而
///       `flutter test` 按文件并行，第二个用真库的文件会和它抢同一个文件。这一组在 `setUp` 里把 FFI
///       工厂的 databases 路径换成**自己的一次性临时目录**，于是连默认那个文件都不碰；这不是口头
///       保证，下面有一条断言直接量它（库文件落在本组的临时目录里）。
///
///       **缺原生库时跳过**（并留下可见说明），与 `app_database_v7_test.dart` 同一套办法。
/// English: **one import, on a genuinely fresh real database** — the fakes above report counts their own
///          arithmetic produced, so "afterwards each table holds exactly what the backup holds" cannot
///          be settled there. Real SQLite, built from **zero** (`onCreate` really runs), walked through
///          the user's path (`importJson`: parse → validate → clear → write → re-count), with **the
///          tables themselves** queried at the end. Both preconditions are **measured**, not assumed
///          (first case: the five tables must all be 0; second: one local row each), and the second is
///          where "phantom rows" is decided — the local rows the backup lacks must cease to exist. The
///          group lives here rather than in `app_database_v7_test.dart` (which records why a second
///          real-database file would fight it over the default path) because it points the FFI
///          factory's databases path at **its own throwaway directory**; one assertion below measures
///          that. **Skipped when the native library is missing**, as in that file.
void _freshInstallImportTests() {
  group('真实 SQLite：新装上的导入', () {
    var ffiAvailable = false;
    late Directory tempDir;

    setUpAll(() async {
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final probe =
            await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
        await probe.close();
        ffiAvailable = true;
      } catch (_) {
        ffiAvailable = false;
      }
    });

    setUp(() async {
      if (!ffiAvailable) return;
      await AppDatabase.instance.closeForTest();
      tempDir = Directory.systemTemp.createTempSync('nekocalc_fresh_import_');
      // 中文：`DatabaseFactory` 这个公开接口上只有 `setDatabasesPath`（带 `OrNull` 的那个住在
      //       `sqflite_common` 的私有 mixin 里，公开类型够不着）。行为是同一个：把工厂的
      //       databases 路径换成下面这个一次性目录。
      // English: the public `DatabaseFactory` interface only has `setDatabasesPath` (the `OrNull`
      //          variant lives on a private mixin in `sqflite_common` and is not reachable through the
      //          public type). It does the same thing: point the factory's databases path at the
      //          throwaway directory below.
      await databaseFactoryFfi.setDatabasesPath(tempDir.path);
    });

    tearDown(() async {
      if (!ffiAvailable) return;
      await AppDatabase.instance.closeForTest();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// 中文：缺原生库时**跳过**，并留下可见的说明——不把一个缺库的环境判成失败。
    /// English: skips when the native library is missing, leaving a visible note rather than failing
    ///          an environment that lacks it.
    void skipMissingFfi() {
      markTestSkipped('系统缺少 libsqlite3，跳过真实 SQLite 的新装导入测试');
    }

    test('新装（五张表全空）：覆盖导入后每张表的行数就是备份里的那个数', () async {
      if (!ffiAvailable) {
        skipMissingFfi();
        return;
      }
      final db = AppDatabase.instance;

      // 中文：先把库真的开出来（`onCreate` 建表），再数一遍——"新装"这句话的判据。
      expect(
        await db.backupTableCounts(),
        {for (final tableName in backupTableNames) tableName: 0},
        reason: '这一侧的前提是五张表全空，先确认再往下测',
      );
      expect(File(p.join(tempDir.path, 'nekocalc.db')).existsSync(), isTrue,
          reason: '库必须落在本组自己的临时目录里——并行跑的那个文件在用默认路径');

      const backupCounts = {
        'calculation_history': 3,
        'notes': 2,
        'favorite_tools': 0,
        'recent_tools': 2,
        'app_settings': 2,
      };
      final repository = DataBackupRepository(db);
      final report = await repository.importJson(
        _snapshotJson(backupCounts),
        replaceExisting: true,
      );

      expect(report.before.totalRows, 0);
      expect(report.after.totalRows, 9);
      for (final tableName in backupTableNames) {
        expect(report.sourceFor(tableName), backupCounts[tableName]);
        expect(report.afterFor(tableName), backupCounts[tableName],
            reason: '$tableName：导入后的行数必须就是备份里的行数，多一行就是幽灵行');
        expect(report.skippedFor(tableName), 0, reason: '覆盖导入不裁剪、不跳过任何一行');
      }

      // 中文：**表才是判据。** 上面那些数是仓库报的，这里直接查表：行数与内容都要对得上。
      final raw = await db.database;
      for (final tableName in backupTableNames) {
        expect(await raw.query(tableName), hasLength(backupCounts[tableName]!),
            reason: '$tableName 表里的真实行数');
      }
      expect(
        (await raw.query('calculation_history', orderBy: 'id'))
            .map((row) => row['expression']),
        ['2+1', '2+2', '2+3'],
      );
      expect(
        (await raw.query('notes', orderBy: 'id')).map((row) => row['title']),
        ['笔记 1', '笔记 2'],
      );
      expect(await db.favoriteToolIds(), isEmpty);
      expect(await db.recentToolIds(),
          unorderedEquals(<String>['recent_tool_1', 'recent_tool_2']));
      expect(await db.settings(), {
        'setting_1': 'value_1',
        'setting_2': 'value_2',
      });
    });

    test('接近全新（本机每张表各留一行）：覆盖导入把本机残留清干净，不留幽灵行', () async {
      if (!ffiAvailable) {
        skipMissingFfi();
        return;
      }
      final db = AppDatabase.instance;
      await db.addHistory(expression: '1+1', result: '2');
      await db.addNote('本机残留的笔记', '本机');
      await db.setFavorite('ohms_law', true);
      await db.markRecent('ohms_law');
      await db.setSetting('local_only', '本机');

      // 中文：先把"接近全新"这件事本身量一遍。
      expect((await db.backupTableCounts()).values, everyElement(1),
          reason: '这一侧的前提是每张表正好一行本机残留');

      const backupCounts = {
        'calculation_history': 2,
        'notes': 1,
        'favorite_tools': 0,
        'recent_tools': 0,
        'app_settings': 1,
      };
      final repository = DataBackupRepository(db);
      final report = await repository.importJson(
        _snapshotJson(backupCounts),
        replaceExisting: true,
      );

      expect(report.before.totalRows, 5);
      expect(report.after.totalRows, 4);
      for (final tableName in backupTableNames) {
        expect(report.afterFor(tableName), backupCounts[tableName],
            reason: '$tableName：覆盖后应当只剩备份里的那些行');
      }

      // 中文：**本机独有、备份里没有的那些行必须消失**——留下一条就是幽灵行。
      expect(await db.favoriteToolIds(), isEmpty,
          reason: '本机残留的收藏不该活过覆盖导入');
      expect(await db.recentToolIds(), isEmpty,
          reason: '本机残留的"最近使用"不该活过覆盖导入');
      expect(await db.settings(), {'setting_1': 'value_1'},
          reason: '本机独有的设置项不许留下');
      expect((await db.history()).map((item) => item.expression),
          unorderedEquals(<String>['2+1', '2+2']));
      expect((await db.notes()).map((note) => note.title),
          unorderedEquals(<String>['笔记 1']));
    });
  });
}

// 中文：影响条目上的句子不再住在 `BackupImportImpact` 上（领域对象活得比界面长），这里按呈现边缘
//       那条路渲染成中文——下面这些断言量到的还是原来那几句话。
// English: the sentences no longer live on `BackupImportImpact` (a domain object outlives the UI);
//          they are rendered here through the presentation edge in Chinese — the assertions above
//          still measure the very same sentences.
final _zh = SettingsBackupStrings.forLanguage(AppLanguage.zh);

String _impactText(BackupImportImpact impact) {
  return backupImportImpactMessage(impact, _zh);
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
