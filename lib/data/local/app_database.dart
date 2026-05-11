import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/history_item.dart';
import '../models/note_item.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      p.join(dbPath, 'nekocalc.db'),
      version: 2,
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
            body TEXT NOT NULL,
            created_at INTEGER NOT NULL
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createSettingsTable(db);
      },
    );
    return _database!;
  }

  static Future<void> _createSettingsTable(Database db) {
    return db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> addHistory({
    required String expression,
    required String result,
    String? toolId,
  }) async {
    final db = await database;
    await db.insert('calculation_history', {
      'expression': expression,
      'result': result,
      'tool_id': toolId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<HistoryItem>> history({int limit = 50}) async {
    final db = await database;
    final rows = await db.query('calculation_history', orderBy: 'created_at DESC', limit: limit);
    return rows.map(HistoryItem.fromMap).toList();
  }

  Future<void> deleteHistory(int id) async {
    final db = await database;
    await db.delete('calculation_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('calculation_history');
  }

  Future<void> addNote(String title, String body) async {
    final db = await database;
    await db.insert('notes', {
      'title': title,
      'body': body,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<NoteItem>> notes() async {
    final db = await database;
    final rows = await db.query('notes', orderBy: 'created_at DESC');
    return rows.map(NoteItem.fromMap).toList();
  }

  Future<void> deleteNote(int id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateNote({
    required int id,
    required String title,
    required String body,
  }) async {
    final db = await database;
    await db.update(
      'notes',
      {'title': title, 'body': body, 'created_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Set<String>> favoriteToolIds() async {
    final db = await database;
    final rows = await db.query('favorite_tools');
    return rows.map((row) => row['tool_id'] as String).toSet();
  }

  Future<void> setFavorite(String toolId, bool favorite) async {
    final db = await database;
    if (favorite) {
      await db.insert(
        'favorite_tools',
        {'tool_id': toolId, 'created_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.delete('favorite_tools', where: 'tool_id = ?', whereArgs: [toolId]);
    }
  }

  Future<void> markRecent(String toolId) async {
    final db = await database;
    await db.insert(
      'recent_tools',
      {'tool_id': toolId, 'used_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> recentToolIds({int limit = 8}) async {
    final db = await database;
    final rows = await db.query('recent_tools', orderBy: 'used_at DESC', limit: limit);
    return rows.map((row) => row['tool_id'] as String).toList();
  }

  Future<Map<String, String>> settings() async {
    final db = await database;
    final rows = await db.query('app_settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
