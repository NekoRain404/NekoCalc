part of 'app_database.dart';

Future<void> _trimHistory(DatabaseExecutor db) {
  // 中文：历史保留最近 500 条，限制 SQLite 增长并保持笔记页查询轻量。
  // English: Keep the latest 500 history rows to limit database growth and keep notes queries light.
  return db.rawDelete(
    '''
    DELETE FROM calculation_history
    WHERE id NOT IN (
      SELECT id FROM calculation_history
      ORDER BY created_at DESC, id DESC
      LIMIT ?
    )
    ''',
    [AppDatabase.maxHistoryRows],
  );
}

Future<void> _trimRecentTools(DatabaseExecutor db) {
  return db.rawDelete(
    '''
    DELETE FROM recent_tools
    WHERE tool_id NOT IN (
      SELECT tool_id FROM recent_tools
      ORDER BY used_at DESC
      LIMIT ?
    )
    ''',
    [AppDatabase.maxRecentToolRows],
  );
}

String? _normalizeRequired(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String? _normalizeOptional(String? value) {
  if (value == null) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

void _appendTextSearch({
  required List<String> clauses,
  required List<Object?> args,
  required List<String> columns,
  required String? query,
}) {
  final tokens = query
      ?.trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens == null || tokens.isEmpty) return;
  // 中文：转义 LIKE 通配符，用户搜索 % 或 _ 时按普通字符处理。
  // English: Escape LIKE wildcards so user-entered % and _ are treated as literal characters.
  for (final token in tokens) {
    final pattern = '%${_escapeLike(token)}%';
    clauses.add(
        '(${columns.map((column) => '$column LIKE ? ESCAPE "\\"').join(' OR ')})');
    args.addAll(List<Object?>.filled(columns.length, pattern));
  }
}

void _appendNoteOrganizationFilter({
  required List<String> clauses,
  required List<Object?> args,
  required String? tag,
  required NoteArchiveFilter archiveFilter,
}) {
  switch (archiveFilter) {
    case NoteArchiveFilter.active:
      clauses.add('is_archived = 0');
    case NoteArchiveFilter.archived:
      clauses.add('is_archived = 1');
    case NoteArchiveFilter.all:
      break;
  }
  final normalizedTag = tag?.trim().replaceAll('|', '');
  if (normalizedTag == null || normalizedTag.isEmpty) return;
  clauses.add('tags LIKE ? ESCAPE "\\"');
  args.add('%|${_escapeLike(normalizedTag)}|%');
}

String _noteOrderBy(NoteSort sort) {
  return switch (sort) {
    NoteSort.updatedNewest =>
      'is_pinned DESC, updated_at DESC, created_at DESC, id DESC',
    NoteSort.updatedOldest =>
      'is_pinned DESC, updated_at ASC, created_at ASC, id ASC',
    NoteSort.titleAscending =>
      'is_pinned DESC, title COLLATE NOCASE ASC, updated_at DESC, id DESC',
  };
}

String _escapeLike(String value) {
  return value
      // 中文：**这里故意不写 `r'\'`**（以反斜杠结尾的 raw 字符串）——源码扫描那把尺子
      //       （`test/shared/source_scan.dart`）把 `\` 当成"转义下一个字符"，读到它会把结束引号
      //       一起吃掉，从这里开始整段代码被当成一个字符串——**这个文件里的一句中文兜底正是
      //       这样从护栏下面溜过去的**。转义写法与 raw 写法取值逐字节相同（已实测），
      //       `%` 与 `_` 那两行的 raw 写法不含这个形状，照旧。
      // English: **`r'\'` (a raw string ending in a backslash) is deliberately not written here** — the
      //          source-scan ruler (`test/shared/source_scan.dart`) reads `\` as escaping the next
      //          character, so it swallows the closing quote too and treats a whole block of code as one
      //          string from here on: **that is exactly how a Chinese fallback in this file slipped
      //          under the guard**. The escaped form holds the same bytes as the raw one (measured);
      //          the `%` and `_` lines below do not have that shape and stay as they are.
      .replaceAll('\\', '\\\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

void _restoreRows(
  Batch batch,
  String table,
  Object? rows,
  Map<String, Object?>? Function(Map<String, Object?> row) normalize,
) {
  if (rows == null) return;
  if (rows is! List) throw FormatException('$table 不是有效列表');
  // 中文：恢复时逐行规范化，跳过坏行而不是让单条脏数据破坏整份备份。
  // English: Normalize each restored row and skip invalid rows instead of letting one bad row ruin the backup.
  for (final row in rows) {
    if (row is! Map) continue;
    final normalized = normalize(row.cast<String, Object?>());
    if (normalized == null) continue;
    batch.insert(table, normalized,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

Future<void> _mergeRows(
  DatabaseExecutor db,
  String table,
  Object? rows,
  Map<String, Object?>? Function(Map<String, Object?> row) normalize,
) async {
  if (rows == null) return;
  if (rows is! List) throw FormatException('$table 不是有效列表');
  for (final row in rows) {
    if (row is! Map) continue;
    final normalized = normalize(row.cast<String, Object?>());
    if (normalized == null) continue;
    switch (table) {
      case 'calculation_history':
        await _mergeHistoryRow(db, normalized);
      case 'notes':
        await _mergeNoteRow(db, normalized);
      default:
        await db.insert(
          table,
          Map<String, Object?>.from(normalized)..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
    }
  }
}

Future<void> _mergeHistoryRow(
  DatabaseExecutor db,
  Map<String, Object?> row,
) async {
  final existing = await db.query(
    'calculation_history',
    columns: const ['id'],
    where:
        'expression = ? AND result = ? AND IFNULL(tool_id, "") = ? AND created_at = ?',
    whereArgs: [
      row['expression'],
      row['result'],
      row['tool_id'] ?? '',
      row['created_at'],
    ],
    limit: 1,
  );
  if (existing.isNotEmpty) return;
  await db.insert(
    'calculation_history',
    Map<String, Object?>.from(row)..remove('id'),
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
}

Future<void> _mergeNoteRow(
  DatabaseExecutor db,
  Map<String, Object?> row,
) async {
  final existing = await db.query(
    'notes',
    columns: const ['id'],
    where: 'title = ? AND description = ? AND body = ? AND created_at = ?',
    whereArgs: [
      row['title'],
      row['description'],
      row['body'],
      row['created_at'],
    ],
    limit: 1,
  );
  if (existing.isNotEmpty) return;
  await db.insert(
    'notes',
    Map<String, Object?>.from(row)..remove('id'),
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
}

Map<String, Object?>? _normalizeHistoryRow(Map<String, Object?> row) {
  final expression = _normalizeRequired(row['expression']?.toString() ?? '');
  final result = _normalizeRequired(row['result']?.toString() ?? '');
  final createdAt = _readInt(row['created_at']);
  if (expression == null || result == null || createdAt == null) return null;
  final toolId = _normalizeOptional(row['tool_id']?.toString());
  // 中文：**老备份没有 `result_kind` 这一列**——按分类器补上。空串与"列不在"同义（都是"还没
  //       分类"），与 [HistoryItem.fromMap] 的读路径判据一致；显式的 `opaque` 不会被覆盖。
  // English: **an old backup has no `result_kind` column** — fill it in via the classifier. An empty
  //          string means the same as an absent column ("not classified yet"), matching
  //          [HistoryItem.fromMap]'s read path; an explicit `opaque` is not overwritten.
  final rawKind = row['result_kind']?.toString();
  final kind = (rawKind == null || rawKind.isEmpty)
      ? classifyHistoryResult(toolId: toolId, result: result)
      : historyResultKindFromStorage(rawKind);
  return {
    if (_readInt(row['id']) != null) 'id': _readInt(row['id']),
    'expression': expression,
    'result': result,
    'result_kind': historyResultKindToStorage(kind),
    'tool_id': toolId,
    'created_at': createdAt,
  };
}

Map<String, Object?>? _normalizeNoteRow(Map<String, Object?> row) {
  final title = _normalizeRequired(row['title']?.toString() ?? '') ?? _untitledNoteMark;
  final createdAt =
      _readInt(row['created_at']) ?? DateTime.now().millisecondsSinceEpoch;
  return {
    if (_readInt(row['id']) != null) 'id': _readInt(row['id']),
    'title': title,
    'description': row['description']?.toString().trim() ?? '',
    'body': row['body']?.toString().trim() ?? '',
    'created_at': createdAt,
    'updated_at': _readInt(row['updated_at']) ?? createdAt,
    'tags': noteTagsToStorage(
        noteTagsFromStorage(row['tags']?.toString().trim() ?? '')),
    'is_pinned': _readInt(row['is_pinned']) == 1 ? 1 : 0,
    'is_archived': _readInt(row['is_archived']) == 1 ? 1 : 0,
  };
}

Map<String, Object?>? _normalizeFavoriteToolRow(
    Map<String, Object?> row) {
  final toolId = _normalizeRequired(row['tool_id']?.toString() ?? '');
  if (toolId == null) return null;
  return {
    'tool_id': toolId,
    'created_at':
        _readInt(row['created_at']) ?? DateTime.now().millisecondsSinceEpoch,
  };
}

Map<String, Object?>? _normalizeRecentToolRow(
    Map<String, Object?> row) {
  final toolId = _normalizeRequired(row['tool_id']?.toString() ?? '');
  if (toolId == null) return null;
  return {
    'tool_id': toolId,
    'used_at':
        _readInt(row['used_at']) ?? DateTime.now().millisecondsSinceEpoch,
  };
}

Map<String, Object?>? _normalizeSettingRow(Map<String, Object?> row) {
  final key = _normalizeRequired(row['key']?.toString() ?? '');
  if (key == null) return null;
  return {
    'key': key,
    'value': row['value']?.toString() ?? '',
    'updated_at':
        _readInt(row['updated_at']) ?? DateTime.now().millisecondsSinceEpoch,
  };
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
