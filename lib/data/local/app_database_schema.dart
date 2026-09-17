part of 'app_database.dart';

Future<void> _createSchema(DatabaseExecutor db) async {
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
