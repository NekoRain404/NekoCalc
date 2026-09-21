import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 中文：**v6 → v7 迁移真的跑一次。** 仓库里 1598 条测试全用假库，迁移路径一行都没被跑过；
///       `result_kind` 是这轮唯一会碰用户已有数据的改动，所以这条测试用**真的 SQLite**（系统
///       `libsqlite3`，经 `sqflite_common_ffi`）建一个 v6 库、塞进两种行、升到 v7，再读回来。
///
///       **这条测试只在开发机上跑得动**（需要系统 `libsqlite3.so`），CI 上没有它就不会跑这条文件。
///       它验证的是迁移**逻辑**，不是平台行为——真机上的 sqflite 走的是同一段 `onUpgrade`。
/// English: **the v6 → v7 migration actually runs once.** All 1598 tests in the repository use fake
///          databases and the migration path was never executed; `result_kind` is the only change this
///          round that touches a user's existing data, so this test builds a v6 database with **real
///          SQLite** (the system `libsqlite3`, through `sqflite_common_ffi`), inserts both kinds of
///          row, upgrades to v7, and reads them back.
///
///          **It only runs on a development machine** (it needs the system `libsqlite3.so`); where that
///          is absent this file simply will not run. What it verifies is the migration **logic**, not
///          platform behaviour — on a device sqflite runs the same `onUpgrade`.
void main() {
  var ffiAvailable = false;

  setUpAll(() async {
    // 中文：先探一次原生库。`sqflite_common_ffi` 在 Linux 上要系统 `libsqlite3.so`，开发机有、
    //       某些 CI 镜像没有。探不到就**跳过**这几条，而不是把一个缺原生库的环境判成失败。
    // English: probe the native library once. On Linux `sqflite_common_ffi` needs the system
    //          `libsqlite3.so`, which a development machine has and some CI images do not. When it is
    //          missing, **skip** these cases rather than failing an environment that lacks a native
    //          library.
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final probe = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await probe.close();
      ffiAvailable = true;
    } catch (_) {
      ffiAvailable = false;
    }
  });

  late String dbPath;

  setUp(() async {
    if (!ffiAvailable) return;
    await AppDatabase.instance.closeForTest();
    final dir = await databaseFactory.getDatabasesPath();
    dbPath = p.join(dir, 'nekocalc.db');
    if (await databaseFactory.databaseExists(dbPath)) {
      await databaseFactory.deleteDatabase(dbPath);
    }
  });

  tearDown(() async {
    if (!ffiAvailable) return;
    await AppDatabase.instance.closeForTest();
  });

  /// 中文：缺原生库时跳过，并留下可见的说明。
  /// English: skips when the native library is missing, leaving a visible note.
  void requireFfi() {
    if (ffiAvailable) return;
    markTestSkipped('系统缺少 libsqlite3，跳过真实迁移测试');
  }

  _writePathTests(requireFfi);

  /// 中文：建一个**没有 `result_kind`** 的 v6 库——就是升级前用户手里的形状。
  /// English: builds a v6 database **without `result_kind`** — the shape a user had before the upgrade.
  Future<void> createV6() async {
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE calculation_history(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              expression TEXT NOT NULL,
              result TEXT NOT NULL,
              tool_id TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE notes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              body TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              tags TEXT NOT NULL DEFAULT '',
              is_pinned INTEGER NOT NULL DEFAULT 0,
              is_archived INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE favorite_tools(
              tool_id TEXT PRIMARY KEY,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE recent_tools(
              tool_id TEXT PRIMARY KEY,
              used_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE app_settings(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    return db.close();
  }

  test('v6 行在升级时按分类器回填：计算器 → number，工具 → tool', () async {
    requireFfi();
    await createV6();
    final v6 = await databaseFactory.openDatabase(dbPath);
    await v6.insert('calculation_history', {
      'expression': '2+3',
      'result': '5',
      'tool_id': null,
      'created_at': 1000,
    });
    await v6.insert('calculation_history', {
      'expression': '电流=2A, 电阻=5Ω',
      'result': '电压 V: 20V',
      'tool_id': 'ohms_law',
      'created_at': 2000,
    });
    await v6.close();

    // 中文：走真实的 `AppDatabase`——`database` getter 触发 `onUpgrade(6, 7)`。
    // English: go through the real `AppDatabase` — the `database` getter triggers `onUpgrade(6, 7)`.
    final db = await AppDatabase.instance.database;

    final columns = await db.rawQuery('PRAGMA table_info(calculation_history)');
    expect(columns.any((column) => column['name'] == 'result_kind'), isTrue,
        reason: '升级后应有 result_kind 列');

    final rows = await db.query('calculation_history', orderBy: 'id');
    expect(rows, hasLength(2));
    expect(rows[0]['result'], '5');
    expect(rows[0]['result_kind'], 'number');
    expect(rows[1]['result'], '电压 V: 20V');
    expect(rows[1]['result_kind'], 'tool');
  });

  test('迁移后读路径把回填值读进 HistoryItem.resultKind', () async {
    requireFfi();
    await createV6();
    final v6 = await databaseFactory.openDatabase(dbPath);
    await v6.insert('calculation_history', {
      'expression': '2+3',
      'result': '5',
      'tool_id': null,
      'created_at': 1000,
    });
    await v6.insert('calculation_history', {
      'expression': '电流=2A, 电阻=5Ω',
      'result': '电压 V: 20V',
      'tool_id': 'ohms_law',
      'created_at': 2000,
    });
    await v6.close();

    final items = await AppDatabase.instance.history();
    // 中文：`history()` 按 `created_at DESC` 排——工具那行（2000）在计算器那行（1000）之前。
    // English: `history()` orders by `created_at DESC` — the tool row (2000) precedes the calculator
    //          row (1000).
    expect(items.map((item) => item.resultKind), [
      HistoryResultKind.tool,
      HistoryResultKind.number,
    ]);
  });

  test('重复升级是幂等的：第二次打开不报错、回填值不变', () async {
    requireFfi();
    await createV6();
    final v6 = await databaseFactory.openDatabase(dbPath);
    await v6.insert('calculation_history', {
      'expression': '2+3',
      'result': '5',
      'tool_id': null,
      'created_at': 1000,
    });
    await v6.close();

    final first = await AppDatabase.instance.history();
    expect(first.single.resultKind, HistoryResultKind.number);

    // 中文：第二次打开时库已是 v7，`onUpgrade` 不会再跑；这里只是确认没有把值改坏。
    // English: on the second open the database is already v7 and `onUpgrade` does not run again; this
    //          only confirms nothing got clobbered.
    final second = await AppDatabase.instance.history();
    expect(second.single.resultKind, HistoryResultKind.number);
  });
}

/// 中文：**写路径与备份往返，也在真库上跑一遍。** 上面三条量迁移；这几条量"新库从头建起来之后，
///       三种 kind 真的能存进去、读回来、导出再导入仍然对"。
/// English: **the write path and the backup round trip, also on a real database.** The three cases above
///          measure the migration; these measure "once a new database is built from scratch, all three
///          kinds really store, read back, and survive export-then-import".
void _writePathTests(void Function() requireFfi) {
  test('addHistory 派生：计算器→number，工具行→tool，显式 opaque 不被形状覆盖', () async {
    requireFfi();
    final db = AppDatabase.instance;
    await db.addHistory(expression: '2+3', result: '5');
    await db.addHistory(
        expression: '电流=2A, 电阻=5Ω', result: '电压 V: 20V', toolId: 'ohms_law');
    // 中文：形状像 `标签: 值`，但调用方显式说是 opaque——必须存 opaque。
    // English: the shape looks like `label: value`, but the caller explicitly says opaque — opaque must
    //          be stored.
    await db.addHistory(
        expression: 'x',
        result: '拟合: y=2x',
        toolId: 'data_fit',
        resultKind: HistoryResultKind.opaque);

    final items = await db.history();
    // 中文：`history()` 按时间倒序，后写的在前。
    // English: `history()` is newest-first.
    expect(items.map((item) => item.resultKind), [
      HistoryResultKind.opaque,
      HistoryResultKind.tool,
      HistoryResultKind.number,
    ]);
  });

  test('导出→导入往返：result_kind 原样回来，opaque 不被重分类', () async {
    requireFfi();
    final db = AppDatabase.instance;
    await db.addHistory(expression: '2+3', result: '5');
    await db.addHistory(
        expression: 'x',
        result: '拟合: y=2x',
        toolId: 'data_fit',
        resultKind: HistoryResultKind.opaque);

    final snapshot = await db.exportSnapshot();
    final historyRows = snapshot['tables']! as Map;
    final rows = (historyRows['calculation_history'] as List)
        .cast<Map<String, Object?>>();
    expect(rows.map((row) => row['result_kind']), containsAll(['number', 'opaque']));

    // 中文：清空再导入，读回来的 kind 与导出前一致。
    // English: clear, import, and read back — the kinds match the export.
    await db.importSnapshot(snapshot, replaceExisting: true);
    final items = await db.history();
    expect(items.map((item) => item.resultKind).toSet(),
        {HistoryResultKind.number, HistoryResultKind.opaque});
  });
}
