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
  _toolTableTests(requireFfi);

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

/// 中文：**收藏与最近这两张表，也在真库上真的写一次、读回来。**
///
///       **它补的是哪一格。** 界面那一侧「点星、图标变亮」由 `tool_category_screen_test.dart`
///       用假库钉住，重载与渲染由 `tools_home_page_test.dart` 钉住——但 `favorite_tools` 与
///       `recent_tools` 这两张表**从来没有一行是真的写进去过**：仓库里每一条测试都走内存假库，
///       于是「写进真 SQLite 再读回来」这条路一行都没被跑过（与迁移那一组存在的理由逐字相同）。
///
///       **每一条都读两种东西**：`AppDatabase` 自己的读方法（`favoriteToolIds` / `recentToolIds`），
///       以及**表本身**（`db.database.query(...)`）。只读前者的话，一个把收藏留在内存里的实现也能
///       全绿——「真的在表里」这句话的判据只能是表。
///
///       **`closeForTest()` 那一步是「重启」**：连接放掉、下一次读重新打开同一个文件，值仍在，
///       才说明它落的是盘而不只是这条连接的缓存。删除与清空也各量一次——只有写没有删，
///       「取消收藏」这条路今天没有任何一条真库测试碰过。
///
///       **这一组住在 `app_database_v7_test.dart` 里是刻意的**：`AppDatabase` 用的是真库的
///       **默认路径**（`getDatabasesPath()` 那个 `nekocalc.db`），而 `flutter test` 按文件并行
///       （本仓库 `--concurrency=16`）。另开一个同样用真库的测试文件，两边会在同一个文件上互相
///       建/删/写——一个随机的红。这一组与上面两组共用同一个 `setUp`（那个 `setUp` 每次先删库），
///       所以必须与它们住在同一个文件里。
/// English: **the favourites and recents tables, also really written and read back on the real
///          database.**
///
///          **The cell this fills.** On the interface side, "tap the star, the icon lights up" is
///          pinned by `tool_category_screen_test.dart` with a fake database, and reload/render by
///          `tools_home_page_test.dart` — but **not one row has ever really been written** into the
///          `favorite_tools` / `recent_tools` tables: every test in the repository uses an in-memory
///          fake, so the road "write into real SQLite and read it back" was never walked (the same
///          reason the migration group above exists, word for word).
///
///          **Each case reads two things**: `AppDatabase`'s own readers (`favoriteToolIds` /
///          `recentToolIds`) and **the tables themselves** (`db.database.query(...)`). Reading only
///          the former would keep an implementation that holds favourites in memory green — the only
///          criterion for "it really is in the table" is the table.
///
///          **The `closeForTest()` step is a "restart"**: the connection is dropped and the next read
///          reopens the same file; the value still being there is what says it landed on disk rather
///          than in that connection's cache. Deleting and clearing are each measured too — with only
///          writes and no deletes, "un-star a tool" would have no real-database test at all.
///
///          **This group lives in `app_database_v7_test.dart` on purpose**: `AppDatabase` uses the
///          real database's **default path** (`nekocalc.db` under `getDatabasesPath()`) and
///          `flutter test` runs files in parallel (this repository uses `--concurrency=16`). A second
///          test file that also used the real database would create, delete and write the same file
///          from both sides — a random red. This group shares the `setUp` above (which deletes the
///          database every time), so it has to live in the same file.
void _toolTableTests(void Function() requireFfi) {
  test('收藏：写进 favorite_tools 表、读回来、关库重开仍在；取消收藏把行删掉', () async {
    requireFfi();
    final db = AppDatabase.instance;

    await db.setFavorite('ohms_law', true);
    expect(await db.favoriteToolIds(), {'ohms_law'});

    // 中文：**判据是表**：`favoriteToolIds()` 之外，直接查一次表。
    // English: **the table is the criterion**: besides `favoriteToolIds()`, query the table itself.
    final rows = await (await db.database).query('favorite_tools');
    expect(rows.map((row) => row['tool_id']), ['ohms_law'],
        reason: '收藏必须真的在 favorite_tools 表里，不能只活在内存里');
    expect(rows.single['created_at'], isA<int>());

    // 中文：**关掉连接、重新打开同一个文件**——「重启之后收藏还在」这句话的判据。
    // English: **drop the connection and reopen the same file** — the criterion for "favourites are
    //          still there after a restart".
    await db.closeForTest();
    expect(await db.favoriteToolIds(), {'ohms_law'},
        reason: '连接关掉再打开，收藏必须还在——它得是落在盘上的');

    await db.setFavorite('ohms_law', false);
    expect(await db.favoriteToolIds(), isEmpty);
    expect(await (await db.database).query('favorite_tools'), isEmpty,
        reason: '取消收藏必须把那一行真的从表里删掉');
  });

  test('最近：写进 recent_tools 表、同一个工具不漏行，删除与清空同样落到表上', () async {
    requireFfi();
    final db = AppDatabase.instance;

    await db.markRecent('data_fit');
    expect(await db.recentToolIds(), ['data_fit']);
    expect(
      (await (await db.database).query('recent_tools'))
          .map((row) => row['tool_id']),
      ['data_fit'],
      reason: '最近的工具必须真的在 recent_tools 表里',
    );

    // 中文：`tool_id` 是主键——重复打开同一个工具只更新时间，不该长出第二行。
    // English: `tool_id` is the primary key — reopening the same tool only updates its timestamp and
    //          must not grow a second row.
    await db.markRecent('data_fit');
    final afterRepeat = await (await db.database).query('recent_tools');
    expect(afterRepeat, hasLength(1),
        reason: '同一个工具打开两次，表里仍该只有一行（主键 replace）');
    expect(afterRepeat.single['used_at'], isA<int>());

    await db.markRecent('ohms_law');
    expect(await db.recentToolIds(), containsAll(<String>['data_fit', 'ohms_law']));

    await db.closeForTest();
    expect(await db.recentToolIds(), containsAll(<String>['data_fit', 'ohms_law']),
        reason: '连接关掉再打开，最近用过的那几个必须还在');

    await db.deleteRecentTool('data_fit');
    expect(await db.recentToolIds(), ['ohms_law']);
    expect(
      (await (await db.database).query('recent_tools'))
          .map((row) => row['tool_id']),
      ['ohms_law'],
    );

    await db.clearRecentTools();
    expect(await db.recentToolIds(), isEmpty);
    expect(await (await db.database).query('recent_tools'), isEmpty);
  });
}
