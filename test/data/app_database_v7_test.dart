import 'dart:io';

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

  /// 中文：本文件**私有**的库目录（见 `setUpAll` 那段说明）。⚠️ 声明必须在使用之前——
  ///       放在 `late String dbPath;` 旁边会报 `referenced_before_declaration`（实测踩过）。
  /// English: this file's **private** database directory (see the note in `setUpAll`). ⚠️ It has to be
  ///          declared before its first use — putting it next to `late String dbPath;` gives
  ///          `referenced_before_declaration` (measured, in this very edit).
  Directory? dbTempDir;

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

    // 中文：**把这个文件用的库目录挪进一次性临时目录。** 此前它用的是**默认路径**
    //       （`<cwd>/.dart_tool/sqflite_common_ffi/databases/nekocalc.db`），而 `--concurrency=16`
    //       下多个测试文件并行——**当时仓库里有 10 个文件引用 `AppDatabase.instance`，其中 9 个没给自己
    //       设目录**，于是在同一个库文件上互相写；本文件 `setUp` 里那句**删库**尤其致命。
    //       实测：三条通道并行跑本文件，**15 遍里红 11 遍**，而每次失败的还是**不同的**测试。
    //       `createTempSync` 每次调用给一个**唯一**目录 ⇒ 每个进程各用各的，撞不上。
    // English: **move this file's database directory into a throwaway temp directory.** Until now it used
    //          the **default path** (`<cwd>/.dart_tool/sqflite_common_ffi/databases/nekocalc.db`), and with
    //          `--concurrency=16` several test files run in parallel — **ten files referenced
    //          `AppDatabase.instance` and nine of them had no directory of their own**, so they wrote to one
    //          database file from several sides; this file's `setUp` **delete** is the worst of it. Measured:
    //          three concurrent channels running this file failed **11 of 15 runs**, and each time the failing
    //          tests were **different**. `createTempSync` hands out a **unique** directory per call, so each
    //          process gets its own and they cannot collide.
    if (ffiAvailable) {
      dbTempDir = Directory.systemTemp.createTempSync('nekocalc_migration_');
      await databaseFactoryFfi.setDatabasesPath(dbTempDir!.path);
    }
  });

  tearDownAll(() async {
    if (!ffiAvailable) return;
    await AppDatabase.instance.closeForTest();
    final dir = dbTempDir;
    if (dir != null && dir.existsSync()) dir.deleteSync(recursive: true);
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
  _settingsPersistenceTests(requireFfi);

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
    // 中文：**三次写入各给一个不同的 `createdAt`——这修掉一条真实的 flake。** 此前三条都用默认的"此刻"，
    //       而那是**毫秒**：三条在同一个毫秒里写完时时间戳**并列**，`history()` 的"按时间倒序"于是成了
    //       **任意顺序**，下面那条断言偶尔倒过来。这条测试要测的是 `result_kind` 的**派生**，顺序只是它的
    //       读法 ⇒ 让排序键**唯一**（负载下实测：15 遍红 3 遍，全是这一条）。
    //       文件里第二条测试（导出→导入往返）不断言顺序（`containsAll` / `.toSet()`），所以它不需要改。
    // English: **distinct `createdAt`s each — this fixes a real flake.** All three used to take the default
    //          "now", which is a **millisecond**: written inside one millisecond they **tie**, "newest-first"
    //          becomes **arbitrary order**, and the assertion below occasionally came back reversed. What this
    //          test is about is the `result_kind` **derivation**; the order is only how it reads it, so the fix
    //          is to make the sort key **unique** (measured under load: 3 of 15 runs red, always this test).
    //          The file's second test (export → import) asserts no order (`containsAll` / `.toSet()`).
    await db.addHistory(
        expression: '2+3',
        result: '5',
        createdAt: DateTime(2026, 6, 8, 9, 30, 0));
    await db.addHistory(
        expression: '电流=2A, 电阻=5Ω',
        result: '电压 V: 20V',
        toolId: 'ohms_law',
        createdAt: DateTime(2026, 6, 8, 9, 30, 1));
    // 中文：形状像 `标签: 值`，但调用方显式说是 opaque——必须存 opaque。
    // English: the shape looks like `label: value`, but the caller explicitly says opaque — opaque must
    //          be stored.
    await db.addHistory(
        expression: 'x',
        result: '拟合: y=2x',
        toolId: 'data_fit',
        resultKind: HistoryResultKind.opaque,
        createdAt: DateTime(2026, 6, 8, 9, 30, 2));

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
/// 中文：**设置也真的写进 `app_settings` 表、并且关库重开仍在——「内存跟着重启活下来」的存储那一半。**
///
///       填的是哪一格：界面侧"记忆键立刻更新"由 `calculator_page_hiper_keypad_test.dart` 用假库钉着，
///       控制器的持久化由 `calculator_controller_persistence_test.dart` 钉着——但**每一处都走内存假库**，
///       "写进真 SQLite 再读回来"这条路从没走过。而"重启之后内存还在"正是发布清单上的一条用户可见行为。
///
///       **判据照 `_toolTableTests` 那条规矩：读访问器之外，直接查表。** 只读 `settings()` 的话，
///       一个把设置留在内存里的实现也能全绿——"真的在表里"这句话的判据只能是表。
/// English: **settings really written into `app_settings` and still there after the connection is dropped —
///          the storage half of "the memory value survives a restart".**
///
///          The cell this fills: the interface side ("memory keys update instantly") is pinned by
///          `calculator_page_hiper_keypad_test.dart` against a fake database, and the controller's
///          persistence by `calculator_controller_persistence_test.dart` — but **every one of them uses an
///          in-memory fake**, so "write into real SQLite and read it back" was never walked. And "the memory
///          value is still there after a restart" is a user-visible line on the release checklist.
///
///          **The criterion follows `_toolTableTests`: besides the accessor, query the table itself.**
///          Reading only `settings()` would keep an implementation that holds settings in memory green — the
///          only criterion for "it really is in the table" is the table.
///
///          ⚠️ **A flake was measured in this file on 2026-10-12.** What is measured, and what is
///          **falsified**, both matter here — two rounds of reasoning were killed by measurement, and each
///          falsification saves the next attempt from re-checking it:
///
///          - **Measured:** running the release checklist's own command (`flutter test --concurrency=16`)
///            failed **twice** on `addHistory 派生：计算器→number，工具行→tool，显式 opaque 不被形状覆盖` — a
///            test in the **migration group**, not this one. A five-run loop was **all green** (0/5), putting
///            the rate near **2 in 14**. Both sightings happened **while other work was running on this
///            machine** (one of them inside the very command that committed and pushed), so **concurrent load
///            is the only pattern measured so far.**
///          - ✗ **Falsified: "the file alone is always green."** It failed **alone** too, on the run where the
///            commit was happening in the same command — so the interference is **not** cross-file, and the
///            isolate argument that pointed at the filesystem settles nothing.
///          - ✗ **Falsified: the two obvious in-file races.** `setUp` **already** closes the singleton
///            **before** deleting the database (`:47`), and `tearDown` closes it again (`:57`); and every
///            test-local handle really is closed (`:142`, `:176`, `:198`, plus `:123`). The file is careful
///            where it looks like it might not be.
///          - **What is left:** the failing assertion is a **derivation** mismatch, i.e. a *write* landing
///            somewhere other than expected. The next attempt should reproduce it **under load** (not by
///            repeating runs on an idle machine) and then bisect **which test's write lands late** — with the
///            timing recorded. Chasing it further on 2026-10-12 was stopped deliberately: three hypotheses
///            had been falsified in a row and the remaining reasoning was being done with too little
///            attention to trust.
///
///          ✅ **RESOLVED the same day — and the cause was none of the three.** Running this file in **three
///          concurrent channels** (a deliberately harsh harness) failed **11 of 15 runs**, and the failing
///          tests were **different** each time — which says "several processes are stepping on one thing",
///          not "one test is flaky". That thing is the **database file**: with `--concurrency=16` several test
///          files run in parallel, **ten files in this repository reference `AppDatabase.instance`** (the
///          default path, `<cwd>/.dart_tool/sqflite_common_ffi/databases/nekocalc.db`), and **nine of them
///          had no directory of their own** — so they read and wrote one database file from several sides,
///          with this file's `setUp` **deleting** it in the middle of everyone's business. ⚠️ This is exactly
///          the shape this file's own documentation predicted ("a second test file that also used the real
///          database … a random red") — the prediction was right, it was just written before the second file
///          existed.
///
///          **The fix** is the isolation already proven in `data_backup_repository_test.dart`: `setUpAll`
///          points the FFI factory at a **throwaway** directory (`createTempSync` hands out a unique one per
///          call, so concurrent processes cannot collide) and `tearDownAll` closes the connection and deletes
///          it. **Evidence, all measured:** the three-channel harness went **11/15 → 3/15**, with the residue
///          confined to a *different* synthetic condition and to a single test; and the release checklist's
///          own command (`--concurrency=16`) under deliberate parallel load went from **~2/14 red to 6/6
///          green**.
///
///          ⚠️ **That isolation was necessary but not sufficient, and the next sighting proved it.** The suite
///          went red again the same afternoon on this very test — and the *isolated* file failed **alone**
///          under load, which killed the "cross-file" reading outright. The residue had a second, entirely
///          different cause: ⚠️ **the test itself asserted a total order on a sort key that is not unique.**
///          It wrote its three rows with the default timestamp — a **millisecond** — so rows written inside one
///          millisecond **tie**, `history()`'s "newest-first" becomes **arbitrary order**, and the assertion
///          occasionally came back reversed. **The fix is to make the key unique, not to loosen the
///          assertion**: the three rows now carry distinct `createdAt`s, because what this test is about is the
///          `result_kind` **derivation**, and the order is only how it reads it. **Evidence:** the three-channel
///          harness finished **15/15 green** (11 red → 3 red → **0 red** across the two fixes), and the release
///          command under parallel load ran **2/2 green**.
///
///          ⚠️ **The lesson worth keeping from this second half is about verification conditions:** the two
///          causes were unrelated, and the first fix's evidence — 6/6 green under load — **looked** like a
///          clean bill of health. **A fix verified under one condition says nothing about the others**, and the
///          condition that mattered here was not the harsher one (three lanes on one file) but the one it
///          actually failed under (the whole suite in parallel). Only a sighting *there*, plus the assertion
///          text rather than its name, settled it.
///
///          ⚠️ **Residual hazard, recorded rather than chased.** The fix above isolates the file that
///          **deletes** the shared database. Others still write to the default path — most clearly
///          `test/domain/notes_controller_test.dart`, which builds repositories over `AppDatabase.instance`
///          and calls `saveNote` (`data_backup_repository_test.dart` is already isolated on its own). Files
///          that only **read** can share a database safely; the **writers** among them cannot, in principle.
///          Today's evidence says it is not biting (the suite ran **2/2 green** under deliberate load, and the
///          three-lane harness **15/15**), so isolating the remaining writers is **hardening, not a fix** —
///          left undone on purpose, and written here so the next person starts from a measured list rather
///          than from "ten files share a database".
///          ⚠️ **2026-10-12 残余隐患，只记录、不顺手改。** 上面的修复隔离的是**删库**那一个文件。仍然写在默认
///          路径上的还有别的——最明确的是 `test/domain/notes_controller_test.dart`（把仓储建在
///          `AppDatabase.instance` 上并调用 `saveNote`；`data_backup_repository_test.dart` 早已自带隔离）。
///          **只读**的文件共用库是安全的；其中的**写者**原则上不是。今天的证据说它没在咬人（负载下 suite
///          **2/2 全绿**、三通道装置 **15/15**），所以隔离剩下的写者属于**加固、不是修复**——故意没做，
///          并写在这里，好让下一个人从一份**量出来的清单**出发，而不是从一句"十个文件共用一个库"。
void _settingsPersistenceTests(void Function() requireFfi) {
  test('设置：写进 app_settings 表、查表可见、关库重开仍在', () async {
    requireFfi();
    final db = AppDatabase.instance;

    await db.setSetting('calculator_memory', '12.5');
    expect((await db.settings())['calculator_memory'], '12.5');

    // 中文：**判据是表**：`settings()` 之外，直接查一次。
    // English: **the table is the criterion**: besides `settings()`, query it directly.
    final rows = await (await db.database).query('app_settings',
        where: 'key = ?', whereArgs: ['calculator_memory']);
    expect(rows.single['value'], '12.5',
        reason: '设置必须真的落在 app_settings 表里，不能只活在内存里');
    expect(rows.single['updated_at'], isA<int>());

    // 中文：**关掉连接、重新打开同一个文件**——「重启之后还在」这句话的判据。
    // English: **drop the connection and reopen the same file** — the criterion for "still there after a
    //          restart".
    await db.closeForTest();
    expect((await db.settings())['calculator_memory'], '12.5',
        reason: '连接关掉再打开，设置必须还在——它得是落在盘上的');
  });
}

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
