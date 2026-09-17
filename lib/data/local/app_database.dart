import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_info.dart';
import '../../core/utils/backup_snapshot_validator.dart';
import '../models/history_item.dart';
import '../models/note_item.dart';

part 'app_database_rows.dart';
part 'app_database_schema.dart';

/// 中文：应用唯一 SQLite 入口，集中管理 schema、迁移、查询、备份和恢复。
/// English: Single SQLite entry point for schema, migrations, queries, backup, and restore.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const maxHistoryRows = 500;
  static const maxRecentToolRows = 24;
  static const _historyDuplicateWindow = Duration(seconds: 2);
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      p.join(dbPath, 'nekocalc.db'),
      version: 6,
      onConfigure: (db) async {
        // 中文：WAL 和 NORMAL synchronous 在移动端读写体验与安全性之间取得平衡。
        // English: WAL plus NORMAL synchronous balances mobile write responsiveness and data safety.
        await db.rawQuery('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.rawQuery('PRAGMA synchronous = NORMAL');
        await db.rawQuery('PRAGMA temp_store = MEMORY');
        await db.rawQuery('PRAGMA busy_timeout = 3000');
      },
      onCreate: (db, version) async {
        await db.transaction((txn) async {
          await _createSchema(txn);
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createSettingsTable(db);
        if (oldVersion < 3) await _addNoteDescriptionColumn(db);
        if (oldVersion < 5) await _addNoteUpdatedAtColumn(db);
        if (oldVersion < 6) await _addNoteOrganizationColumns(db);
        if (oldVersion < 5) await _createIndexes(db);
        if (oldVersion < 6) await _createIndexes(db);
      },
    );
    return _database!;
  }

  Future<int> addHistory({
    required String expression,
    required String result,
    String? toolId,
    DateTime? createdAt,
  }) async {
    final db = await database;
    final normalizedExpression = _normalizeRequired(expression);
    final normalizedResult = _normalizeRequired(result);
    final normalizedToolId = _normalizeOptional(toolId);
    if (normalizedExpression == null || normalizedResult == null) return 0;

    return db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timestamp = createdAt?.millisecondsSinceEpoch ?? now;
      final duplicateSince = timestamp - _historyDuplicateWindow.inMilliseconds;
      final duplicateUntil = timestamp + _historyDuplicateWindow.inMilliseconds;
      // 中文：数据库层再做一次短窗口去重，防止 UI 防重入遗漏或多入口重复保存。
      // English: Database-level short-window deduplication catches duplicate saves from any entry point.
      final existing = await txn.query(
        'calculation_history',
        columns: ['id'],
        where:
            'expression = ? AND result = ? AND IFNULL(tool_id, "") = ? AND created_at BETWEEN ? AND ?',
        whereArgs: [
          normalizedExpression,
          normalizedResult,
          normalizedToolId ?? '',
          duplicateSince,
          duplicateUntil,
        ],
        limit: 1,
      );
      if (existing.isNotEmpty) return existing.first['id'] as int;

      return txn.insert('calculation_history', {
        'expression': normalizedExpression,
        'result': normalizedResult,
        'tool_id': normalizedToolId,
        'created_at': timestamp,
      }).then((id) async {
        await _trimHistory(txn);
        return id;
      });
    });
  }

  Future<List<HistoryItem>> history(
      {int limit = 50, int offset = 0, String? query, String? toolId}) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    final normalizedToolId = _normalizeOptional(toolId);
    if (normalizedToolId != null) {
      clauses.add('tool_id = ?');
      args.add(normalizedToolId);
    }
    _appendTextSearch(
      clauses: clauses,
      args: args,
      columns: const ['expression', 'result'],
      query: query,
    );
    final rows = await db.query(
      'calculation_history',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit.clamp(1, 500),
      offset: offset < 0 ? 0 : offset,
    );
    return rows.map(HistoryItem.fromMap).toList();
  }

  Future<int> deleteHistory(int id) async {
    final db = await database;
    return db.delete('calculation_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteHistoryItems(Iterable<int> ids) async {
    final normalized = ids.toSet().toList(growable: false);
    if (normalized.isEmpty) return 0;
    final db = await database;
    return db.delete(
      'calculation_history',
      where: 'id IN (${List.filled(normalized.length, '?').join(',')})',
      whereArgs: normalized,
    );
  }

  Future<int> clearHistory() async {
    final db = await database;
    return db.delete('calculation_history');
  }

  Future<int> historyCount({String? query, String? toolId}) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    final normalizedToolId = _normalizeOptional(toolId);
    if (normalizedToolId != null) {
      clauses.add('tool_id = ?');
      args.add(normalizedToolId);
    }
    _appendTextSearch(
      clauses: clauses,
      args: args,
      columns: const ['expression', 'result'],
      query: query,
    );
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM calculation_history${clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}'}',
      args,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> addNote(String title, String body,
      {String description = '', List<String> tags = const []}) async {
    final db = await database;
    final normalizedTitle = _normalizeRequired(title) ?? '未命名笔记';
    final normalizedBody = body.trim();
    final normalizedDescription = description.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('notes', {
      'title': normalizedTitle,
      'description': normalizedDescription,
      'body': normalizedBody,
      'created_at': now,
      'updated_at': now,
      'tags': noteTagsToStorage(tags),
      'is_pinned': 0,
      'is_archived': 0,
    });
  }

  Future<List<NoteItem>> notes({
    int limit = 200,
    int offset = 0,
    String? query,
    String? tag,
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
    NoteSort sort = NoteSort.updatedNewest,
  }) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    // 中文：笔记搜索覆盖标题、描述和正文，保证描述字段不是“只展示不可搜索”。
    // English: Note search covers title, description, and body so the description field is searchable.
    _appendTextSearch(
      clauses: clauses,
      args: args,
      columns: const ['title', 'description', 'body'],
      query: query,
    );
    _appendNoteOrganizationFilter(
      clauses: clauses,
      args: args,
      tag: tag,
      archiveFilter: archiveFilter,
    );
    final rows = await db.query(
      'notes',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: _noteOrderBy(sort),
      limit: limit.clamp(1, 1000),
      offset: offset < 0 ? 0 : offset,
    );
    return rows.map(NoteItem.fromMap).toList();
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteNotes(Iterable<int> ids) async {
    final normalized = ids.toSet().toList(growable: false);
    if (normalized.isEmpty) return 0;
    final db = await database;
    return db.delete(
      'notes',
      where: 'id IN (${List.filled(normalized.length, '?').join(',')})',
      whereArgs: normalized,
    );
  }

  Future<int> noteCount({
    String? query,
    String? tag,
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
  }) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    _appendTextSearch(
      clauses: clauses,
      args: args,
      columns: const ['title', 'description', 'body'],
      query: query,
    );
    _appendNoteOrganizationFilter(
      clauses: clauses,
      args: args,
      tag: tag,
      archiveFilter: archiveFilter,
    );
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM notes${clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}'}',
      args,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<List<String>> noteTags({
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
  }) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    _appendNoteOrganizationFilter(
      clauses: clauses,
      args: args,
      tag: null,
      archiveFilter: archiveFilter,
    );
    final rows = await db.query(
      'notes',
      columns: const ['tags'],
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
    );
    final tags = normalizeNoteTags(
      rows.expand((row) => noteTagsFromStorage(row['tags'] as String? ?? '')),
    )..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    return tags;
  }

  Future<void> updateNote({
    required int id,
    required String title,
    required String description,
    required String body,
    List<String> tags = const [],
  }) async {
    final db = await database;
    final normalizedTitle = _normalizeRequired(title) ?? '未命名笔记';
    await db.update(
      'notes',
      {
        'title': normalizedTitle,
        'description': description.trim(),
        'body': body.trim(),
        'tags': noteTagsToStorage(tags),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setNotePinned(int id, bool value) async {
    final db = await database;
    await db.update(
      'notes',
      {
        'is_pinned': value ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setNoteArchived(int id, bool value) async {
    final db = await database;
    await db.update(
      'notes',
      {
        'is_archived': value ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Set<String>> favoriteToolIds() async {
    final db = await database;
    final rows = await db.query('favorite_tools', orderBy: 'created_at DESC');
    return rows.map((row) => row['tool_id'] as String).toSet();
  }

  Future<void> setFavorite(String toolId, bool favorite) async {
    final db = await database;
    if (favorite) {
      await db.insert(
        'favorite_tools',
        {
          'tool_id': toolId,
          'created_at': DateTime.now().millisecondsSinceEpoch
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db
          .delete('favorite_tools', where: 'tool_id = ?', whereArgs: [toolId]);
    }
  }

  Future<void> markRecent(String toolId) async {
    final db = await database;
    final normalizedToolId = _normalizeRequired(toolId);
    if (normalizedToolId == null) return;
    await db.transaction((txn) async {
      // 中文：最近工具用 tool_id 主键 replace，重复打开同一工具只更新时间。
      // English: Recent tools use tool_id as primary key with replace, so reopening a tool only updates its timestamp.
      await txn.insert(
        'recent_tools',
        {
          'tool_id': normalizedToolId,
          'used_at': DateTime.now().millisecondsSinceEpoch
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _trimRecentTools(txn);
    });
  }

  Future<List<String>> recentToolIds({int limit = 8}) async {
    final db = await database;
    final rows =
        await db.query('recent_tools', orderBy: 'used_at DESC', limit: limit);
    return rows.map((row) => row['tool_id'] as String).toList();
  }

  Future<int> deleteRecentTool(String toolId) async {
    final db = await database;
    final normalizedToolId = _normalizeRequired(toolId);
    if (normalizedToolId == null) return 0;
    return db.delete(
      'recent_tools',
      where: 'tool_id = ?',
      whereArgs: [normalizedToolId],
    );
  }

  Future<int> clearRecentTools() async {
    final db = await database;
    return db.delete('recent_tools');
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
    final normalizedKey = _normalizeRequired(key);
    if (normalizedKey == null) return;
    await db.insert(
      'app_settings',
      {
        'key': normalizedKey,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setSettings(Map<String, String> values) async {
    if (values.isEmpty) return;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      // 中文：设置项批量写入，避免连续切换设置时产生多次事务开销。
      // English: Settings are written in one batch to avoid repeated transaction overhead during preference changes.
      final batch = txn.batch();
      for (final entry in values.entries) {
        final normalizedKey = _normalizeRequired(entry.key);
        if (normalizedKey == null) continue;
        batch.insert(
          'app_settings',
          {'key': normalizedKey, 'value': entry.value, 'updated_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Map<String, int>> backupTableCounts() async {
    final db = await database;
    final counts = <String, int>{};
    for (final tableName in backupTableNames) {
      final rows =
          await db.rawQuery('SELECT COUNT(*) AS count FROM $tableName');
      counts[tableName] = Sqflite.firstIntValue(rows) ?? 0;
    }
    return counts;
  }

  Future<Map<String, Object?>> exportSnapshot() async {
    final db = await database;
    // 中文：导出使用稳定排序，便于比较备份文件，也方便以后做增量迁移。
    // English: Stable ordering makes backup files comparable and prepares for future migration tooling.
    return {
      'schema': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'metadata': {
        'app': AppInfo.name,
        'app_version': AppInfo.version,
        'format': 'nekocalc.sqlite.snapshot',
        'format_version': 1,
      },
      'tables': {
        'calculation_history': await db.query('calculation_history',
            orderBy: 'created_at ASC, id ASC'),
        'notes': await db.query('notes', orderBy: 'created_at ASC, id ASC'),
        'favorite_tools':
            await db.query('favorite_tools', orderBy: 'created_at ASC'),
        'recent_tools': await db.query('recent_tools', orderBy: 'used_at ASC'),
        'app_settings': await db.query('app_settings', orderBy: 'key ASC'),
      },
    };
  }

  Future<void> importSnapshot(
    Map<String, Object?> snapshot, {
    bool replaceExisting = true,
  }) async {
    // 中文：二次校验用于保护直接调用 importSnapshot 的代码路径。
    // English: Validate again to protect callers that bypass the repository parser.
    if (replaceExisting) {
      validateBackupReplacementSnapshot(snapshot);
    } else {
      validateBackupSnapshot(snapshot);
    }
    final tables = snapshot['tables'];
    if (tables is! Map) {
      throw const FormatException('备份数据缺少 tables 字段');
    }
    final db = await database;
    await db.transaction((txn) async {
      if (replaceExisting) {
        // 中文：通过单个事务完成“清空再恢复”，失败时 SQLite 会回滚到导入前状态。
        // English: Clear-and-restore runs in one transaction so SQLite rolls back to the pre-import state on failure.
        await txn.delete('calculation_history');
        await txn.delete('notes');
        await txn.delete('favorite_tools');
        await txn.delete('recent_tools');
        await txn.delete('app_settings');

        final batch = txn.batch();
        _restoreRows(batch, 'calculation_history',
            tables['calculation_history'], _normalizeHistoryRow);
        _restoreRows(batch, 'notes', tables['notes'], _normalizeNoteRow);
        _restoreRows(batch, 'favorite_tools', tables['favorite_tools'],
            _normalizeFavoriteToolRow);
        _restoreRows(batch, 'recent_tools', tables['recent_tools'],
            _normalizeRecentToolRow);
        _restoreRows(batch, 'app_settings', tables['app_settings'],
            _normalizeSettingRow);
        await batch.commit(noResult: true);
      } else {
        await _mergeRows(txn, 'calculation_history',
            tables['calculation_history'], _normalizeHistoryRow);
        await _mergeRows(txn, 'notes', tables['notes'], _normalizeNoteRow);
        await _mergeRows(txn, 'favorite_tools', tables['favorite_tools'],
            _normalizeFavoriteToolRow);
        await _mergeRows(txn, 'recent_tools', tables['recent_tools'],
            _normalizeRecentToolRow);
        await _mergeRows(
            txn, 'app_settings', tables['app_settings'], _normalizeSettingRow);
      }
      await _trimHistory(txn);
      await _trimRecentTools(txn);
    });
  }

}
