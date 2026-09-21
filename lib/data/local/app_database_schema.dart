part of 'app_database.dart';

Future<void> _createSchema(DatabaseExecutor db) async {
  await db.execute('''
        CREATE TABLE calculation_history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          expression TEXT NOT NULL,
          result TEXT NOT NULL,
          result_kind TEXT NOT NULL DEFAULT '',
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
  await _createSettingsTable(db);
  await _createIndexes(db);
}

Future<void> _createSettingsTable(DatabaseExecutor db) {
  return db.execute('''
    CREATE TABLE IF NOT EXISTS app_settings(
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
}

Future<void> _addNoteDescriptionColumn(DatabaseExecutor db) async {
  final columns = await db.rawQuery('PRAGMA table_info(notes)');
  final hasDescription =
      columns.any((column) => column['name'] == 'description');
  if (!hasDescription) {
    await db.execute(
        "ALTER TABLE notes ADD COLUMN description TEXT NOT NULL DEFAULT ''");
  }
}

Future<void> _addNoteUpdatedAtColumn(DatabaseExecutor db) async {
  final columns = await db.rawQuery('PRAGMA table_info(notes)');
  final hasUpdatedAt =
      columns.any((column) => column['name'] == 'updated_at');
  if (!hasUpdatedAt) {
    await db.execute(
        'ALTER TABLE notes ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
    await db.execute(
        'UPDATE notes SET updated_at = created_at WHERE updated_at = 0');
  }
}

/// 中文：给历史表加 `result_kind` 列并**回填既有行**。守卫照 [AppDatabase] 里其他迁移的写法
///       （先 `PRAGMA table_info` 看列在不在），所以重复跑是幂等的。
///
///       **回填用的是与写路径同一个分类器**（[classifyHistoryResult]），不是另抄一份判据：
///       没有 `tool_id` 的旧行是计算器那条中性数值，有 `tool_id` 的是工具那条 `标签: 值`。
///       回填写在 `ALTER TABLE` 之后、同一个事务里——加列时给的默认值是空串，这里把它换成真分类。
/// English: Adds the `result_kind` column to the history table and **backfills existing rows**. The
///          guard follows this file's other migrations (read `PRAGMA table_info` first), so running it
///          twice is idempotent.
///
///          **The backfill uses the same classifier as the write path** ([classifyHistoryResult]),
///          not a second copy of the verdict: an old row with no `tool_id` is the calculator's neutral
///          number, one with a `tool_id` is the tools' `label: value`. The backfill runs right after
///          the `ALTER TABLE`, in the same transaction — the column's default is an empty string and
///          this replaces it with a real classification.
Future<void> _addHistoryResultKindColumn(DatabaseExecutor db) async {
  final columns = await db.rawQuery('PRAGMA table_info(calculation_history)');
  final hasResultKind =
      columns.any((column) => column['name'] == 'result_kind');
  if (hasResultKind) return;
  await db.execute(
      "ALTER TABLE calculation_history ADD COLUMN result_kind TEXT NOT NULL DEFAULT ''");
  // 中文：逐行回填。行数有上限（[AppDatabase.maxHistoryRows]），一次读出来即可。
  // English: Backfill row by row. The row count is capped ([AppDatabase.maxHistoryRows]), so one
  //          read is fine.
  final rows = await db.query('calculation_history',
      columns: const ['id', 'result', 'tool_id']);
  for (final row in rows) {
    final kind = classifyHistoryResult(
      toolId: row['tool_id'] as String?,
      result: row['result'] as String? ?? '',
    );
    await db.update(
      'calculation_history',
      {'result_kind': historyResultKindToStorage(kind)},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
}

Future<void> _addNoteOrganizationColumns(DatabaseExecutor db) async {
  final columns = await db.rawQuery('PRAGMA table_info(notes)');
  final names = columns.map((column) => column['name']).toSet();
  if (!names.contains('tags')) {
    await db.execute(
        "ALTER TABLE notes ADD COLUMN tags TEXT NOT NULL DEFAULT ''");
  }
  if (!names.contains('is_pinned')) {
    await db.execute(
        'ALTER TABLE notes ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0');
  }
  if (!names.contains('is_archived')) {
    await db.execute(
        'ALTER TABLE notes ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0');
  }
}

Future<void> _createIndexes(DatabaseExecutor db) async {
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_history_created_at ON calculation_history(created_at DESC)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_history_tool_created_at ON calculation_history(tool_id, created_at DESC)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes(created_at DESC)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes(updated_at DESC, created_at DESC)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_organized ON notes(is_archived, is_pinned DESC, updated_at DESC, created_at DESC)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recent_tools_used_at ON recent_tools(used_at DESC)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_favorite_tools_created_at ON favorite_tools(created_at DESC)');
}
