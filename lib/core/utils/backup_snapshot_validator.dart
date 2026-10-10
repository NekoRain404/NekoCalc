import 'dart:convert';

const backupSchemaVersion = 1;
const emptyBackupReplaceErrorMessage = '空备份不能用于覆盖恢复，请改用合并导入或选择包含记录的备份。';

// 中文：导入前必须确认所有业务表都存在，避免坏备份把本地数据清空。
// English: Validate every business table before import so a damaged backup cannot wipe local data.
const backupTableNames = [
  'calculation_history',
  'notes',
  'favorite_tools',
  'recent_tools',
  'app_settings',
];

const backupTableLabels = {
  'calculation_history': '历史',
  'notes': '笔记',
  'favorite_tools': '收藏',
  'recent_tools': '最近工具',
  'app_settings': '设置',
};

class BackupTableCount {
  const BackupTableCount({
    required this.name,
    required this.label,
    required this.count,
  });

  final String name;
  final String label;
  final int count;
}

class BackupPreview {
  const BackupPreview({
    required this.schema,
    required this.exportedAt,
    required this.appVersion,
    required this.counts,
  });

  final int schema;
  final String? exportedAt;
  final String? appVersion;
  final Map<String, int> counts;

  int get totalRows => counts.values.fold(0, (sum, count) => sum + count);

  List<BackupTableCount> get tableCounts {
    return [
      for (final tableName in backupTableNames)
        BackupTableCount(
          name: tableName,
          label: backupTableLabels[tableName] ?? tableName,
          count: counts[tableName] ?? 0,
        ),
    ];
  }

  String get summary {
    return tableCounts.map((item) => '${item.label} ${item.count}').join(' · ');
  }

  String get totalLabel => '$totalRows 条记录';
}

enum BackupPreviewWarningSeverity { info, warning, danger }

/// 中文：**导入前那一条提示说的是哪件事——它既是判据，也是呈现层取那句话用的令牌。**
///
///       八格与 `SettingsStrings` 里的八格一一对应（`backupWarningNoRecoverableRecords` …
///       `backupWarningAppVersionMismatch`），由 `settings_backup_messages.dart` 的
///       `backupPreviewWarningMessage(warning, strings)` 那个穷尽 `switch` 接上。年龄、
///       导出时间与版本号是**载荷**，留在警告上由呈现层拼进句子（「距今约 1 年」那根尾巴里的
///       年/个月/天也在表里，见 `backupAgeYears` 等三格）。
///
///       **这八格从前是在这里拼的句子**（`BackupPreviewWarning.message`，直接印在设置页的
///       「备份提示」块里）：领域对象活得比界面长，界面那张按语言切的文案表够不着它，所以英文界面下
///       它照样是中文——`docs/verification.md` §5i 记着这条层次性缺陷。
///
///       **八格互斥**，理由逐个写下来（这批的排他性不都是"一个字段的两个值"那么显然）：
///       `noRecoverableRecords` 由总行数为零独占；`missingExportedAt`（字段缺失或空白）与
///       `unrecognisedExportedAt`（字段在、但解析不出时间）由那个 `if / else if` 的先后分开，
///       两者的 `else` 分支才轮到三个年龄格；`exportedAtInFuture`（早于本机一天以上）、
///       `olderThanYear`（≥365 天）与 `olderThanNinetyDays`（≥90 天且 <365 天）是同一串年龄闸的
///       三段，边界一个不重叠——365 那一格先判，90 那一格因此永远收不到 ≥365 的年龄，
///       「距今约 1 年，建议确认」与「距今约 3 个月」不会同时出现；`missingAppVersion`
///       （字段缺失或空白）与 `appVersionMismatch`（在、且与本机不同）同理由先后分开。
/// English: **which thing one pre-import notice says — a verdict, and the token the presentation layer
///          resolves the sentence with.**
///
///          The eight values correspond one for one with eight cells in `SettingsStrings`
///          (`backupWarningNoRecoverableRecords` … `backupWarningAppVersionMismatch`), wired up by the
///          exhaustive `switch` in `backupPreviewWarningMessage(warning, strings)` in
///          `settings_backup_messages.dart`. The age, the export time and the version numbers are
///          **payload** and stay on the warning for the presentation layer to splice into the sentence
///          (the years/months/days of the "about N old" tail live in the table too — cells such as
///          `backupAgeYears`).
///
///          **These eight used to be sentences composed right here** (`BackupPreviewWarning.message`,
///          printed straight into the settings page's "Backup warnings" block): a domain object
///          outlives the UI and a language-keyed copy table cannot reach it, so an English interface
///          still printed Chinese — the layering defect recorded in `docs/verification.md` §5i.
///
///          **The eight are mutually exclusive**, and each reason is written out because the
///          exclusivity here is not always the obvious "two values of one field":
///          `noRecoverableRecords` is held by a total row count of zero; `missingExportedAt` (the field
///          is absent or blank) and `unrecognisedExportedAt` (the field is there but will not parse)
///          are separated by the order of that `if / else if`, and only their `else` reaches the three
///          age cells; `exportedAtInFuture` (more than a day ahead of this device), `olderThanYear`
///          (365 days or more) and `olderThanNinetyDays` (90 days or more but under 365) are three
///          stretches of one age gate whose boundaries do not overlap — the 365 cell is tested first,
///          so the 90-day cell can never receive an age of 365 or more and "about 1 year old, check it"
///          and "about 3 months old" cannot both appear; `missingAppVersion` (absent or blank) against
///          `appVersionMismatch` (present and different from this device) splits the same way.
enum BackupPreviewWarningKind {
  noRecoverableRecords,
  missingExportedAt,
  unrecognisedExportedAt,
  exportedAtInFuture,
  olderThanYear,
  olderThanNinetyDays,
  missingAppVersion,
  appVersionMismatch,
}

/// 中文：**一条导入前提示：判据 + 载荷，没有给人看的句子。**
///
///       无名构造是私有的，八条命名构造各带各的载荷：`unrecognisedExportedAt` 要求非空导出时间串、
///       两个年龄格要求一个 `Duration`、`appVersionMismatch` 要求两个非空版本号，而呈现层读载荷时
///       用的是 `!`（见 `settings_backup_messages.dart`）。留一条公开的无名构造，就等于留一条
///       「令牌说 olderThanYear、年龄却是 null」的路，那条路上屏幕会印出半句话或者崩掉——同
///       `CalculatorSubmitResult` 与 `RecentToolActionResult` 那两条理由。
///
///       **`severity` 是派生出来的**，不是第二个字段：八格各自对应哪一档在下面的穷尽 `switch` 里
///       写死，所以「令牌说 A、颜色却是 B」这种不一致没有落点。设置页那块提示框仍按它取色与图标。
/// English: **one pre-import notice: the verdict plus its payload, with no user-facing sentence.**
///
///          The unnamed constructor is private and the eight named ones each carry their own payload:
///          `unrecognisedExportedAt` requires a non-null export-time string, the two age cells require a
///          `Duration`, `appVersionMismatch` requires two non-null version numbers, and the presentation
///          layer reads those payloads with `!` (see `settings_backup_messages.dart`). A public unnamed
///          constructor would leave a road where the token says `olderThanYear` while the age is null —
///          down that road the screen prints half a sentence or throws, the same reasoning as
///          `CalculatorSubmitResult` and `RecentToolActionResult`.
///
///          **`severity` is derived**, not a second field: which of the three levels each of the eight
///          kinds carries is written out in the exhaustive `switch` below, so "the token says A while
///          the colour says B" has nowhere to land. The settings page's notice block still reads it for
///          colour and icon.
class BackupPreviewWarning {
  const BackupPreviewWarning._({
    required this.kind,
    this.age,
    this.exportedAt,
    this.version,
    this.currentVersion,
  });

  const BackupPreviewWarning.noRecoverableRecords()
      : this._(kind: BackupPreviewWarningKind.noRecoverableRecords);

  const BackupPreviewWarning.missingExportedAt()
      : this._(kind: BackupPreviewWarningKind.missingExportedAt);

  BackupPreviewWarning.unrecognisedExportedAt(String exportedAt)
      : this._(
          kind: BackupPreviewWarningKind.unrecognisedExportedAt,
          exportedAt: exportedAt,
        );

  const BackupPreviewWarning.exportedAtInFuture()
      : this._(kind: BackupPreviewWarningKind.exportedAtInFuture);

  BackupPreviewWarning.olderThanYear(Duration age)
      : this._(kind: BackupPreviewWarningKind.olderThanYear, age: age);

  BackupPreviewWarning.olderThanNinetyDays(Duration age)
      : this._(kind: BackupPreviewWarningKind.olderThanNinetyDays, age: age);

  const BackupPreviewWarning.missingAppVersion()
      : this._(kind: BackupPreviewWarningKind.missingAppVersion);

  BackupPreviewWarning.appVersionMismatch({
    required String version,
    required String currentVersion,
  }) : this._(
          kind: BackupPreviewWarningKind.appVersionMismatch,
          version: version,
          currentVersion: currentVersion,
        );

  final BackupPreviewWarningKind kind;

  /// 中文：`olderThanYear` / `olderThanNinetyDays` 的载荷：备份比 `now` 老了多少。
  ///       年/个月/天那三句话在表里，切分由呈现层做（`_backupAgeLabel`）。
  /// English: the payload of `olderThanYear` / `olderThanNinetyDays`: how much older than `now` the
  ///          backup is. The years/months/days wording lives in the table and the split is made at the
  ///          presentation edge (`_backupAgeLabel`).
  final Duration? age;

  /// 中文：`unrecognisedExportedAt` 的载荷：文件里那个原样的时间串（未 trim，与迁移前那句一致）。
  /// English: the payload of `unrecognisedExportedAt`: the export-time string exactly as the file
  ///          carries it (untrimmed, as the pre-move sentence had it).
  final String? exportedAt;

  final String? version;
  final String? currentVersion;

  BackupPreviewWarningSeverity get severity => switch (kind) {
        BackupPreviewWarningKind.noRecoverableRecords =>
          BackupPreviewWarningSeverity.danger,
        BackupPreviewWarningKind.unrecognisedExportedAt ||
        BackupPreviewWarningKind.exportedAtInFuture ||
        BackupPreviewWarningKind.olderThanYear =>
          BackupPreviewWarningSeverity.warning,
        BackupPreviewWarningKind.missingExportedAt ||
        BackupPreviewWarningKind.olderThanNinetyDays ||
        BackupPreviewWarningKind.missingAppVersion ||
        BackupPreviewWarningKind.appVersionMismatch =>
          BackupPreviewWarningSeverity.info,
      };
}

/// 中文：**导入前的提示清单——只报「属于哪一种」与载荷，一个字都不给用户看。**
///
///       它从前在这里拼那八句中文（`'备份文件没有可恢复记录，覆盖恢复会清空本机数据。'`、
///       `'备份距今约 1 年，恢复前建议确认内容是否仍然需要。'` …）并直接印在设置页的「备份提示」块里，
///       于是英文界面下印的仍是中文（`docs/verification.md` §5i）。现在字住在 `SettingsStrings` 里，
///       由 `settings_backup_messages.dart` 在呈现边缘按令牌取；年龄只在结果上留一个 `Duration`，
///       年/个月/天怎么切、那句话怎么写，都是呈现层的事。
///
///       分支顺序与判据**逐字未动**（`totalRows == 0` 先判；导出时间缺失 → 解析失败 → 三个年龄闸；
///       版本缺失 → 版本不同），所以哪一条提示在什么时候出现与迁移前完全一致。
/// English: **the pre-import notice list — it reports only "which kind" plus payloads, and not one word
///          is shown to a user.**
///
///          It used to compose those eight Chinese sentences right here
///          (`'备份文件没有可恢复记录，覆盖恢复会清空本机数据。'`,
///          `'备份距今约 1 年，恢复前建议确认内容是否仍然需要。'` …) and print them straight into the
///          settings page's "Backup warnings" block, so an English interface still printed Chinese
///          (`docs/verification.md` §5i). The words now live in `SettingsStrings`, read at the
///          presentation edge by `settings_backup_messages.dart`; the age stays on the result as a
///          `Duration`, and how it splits into years/months/days and how the sentence reads are the
///          presentation layer's business.
///
///          The branch order and the criteria are **untouched, character for character**
///          (`totalRows == 0` first; missing export time → unparsable → the three age gates; missing
///          version → different version), so which notice appears when is exactly what it was.
List<BackupPreviewWarning> buildBackupPreviewWarnings(
  BackupPreview preview, {
  required DateTime now,
  String? currentAppVersion,
}) {
  final warnings = <BackupPreviewWarning>[];
  if (preview.totalRows == 0) {
    warnings.add(const BackupPreviewWarning.noRecoverableRecords());
  }

  final exportedAt = _parseBackupDateTime(preview.exportedAt);
  if (preview.exportedAt == null || preview.exportedAt!.trim().isEmpty) {
    warnings.add(const BackupPreviewWarning.missingExportedAt());
  } else if (exportedAt == null) {
    warnings.add(
      BackupPreviewWarning.unrecognisedExportedAt(preview.exportedAt!),
    );
  } else {
    final age = now.difference(exportedAt);
    if (age < const Duration(days: -1)) {
      warnings.add(const BackupPreviewWarning.exportedAtInFuture());
    } else if (age >= const Duration(days: 365)) {
      warnings.add(BackupPreviewWarning.olderThanYear(age));
    } else if (age >= const Duration(days: 90)) {
      warnings.add(BackupPreviewWarning.olderThanNinetyDays(age));
    }
  }

  final version = preview.appVersion?.trim();
  if (version == null || version.isEmpty) {
    warnings.add(const BackupPreviewWarning.missingAppVersion());
  } else if (currentAppVersion != null &&
      currentAppVersion.trim().isNotEmpty &&
      version != currentAppVersion.trim()) {
    warnings.add(BackupPreviewWarning.appVersionMismatch(
      version: version,
      currentVersion: currentAppVersion.trim(),
    ));
  }

  return warnings;
}

Map<String, Object?> parseBackupSnapshot(String source) {
  final normalizedSource = _stripBom(source).trim();
  if (normalizedSource.isEmpty) {
    throw const FormatException('备份文件为空');
  }
  final decoded = jsonDecode(normalizedSource);
  if (decoded is! Map) {
    throw const FormatException('备份内容不是有效对象');
  }
  final snapshot = decoded.cast<String, Object?>();
  // 中文：解析和结构校验在进入数据库事务前完成，失败时不会触碰 SQLite。
  // English: Parse and validate before opening the database transaction; failures leave SQLite untouched.
  validateBackupSnapshot(snapshot);
  return snapshot;
}

BackupPreview previewBackupSnapshot(String source) {
  final snapshot = parseBackupSnapshot(source);
  final tables = snapshot['tables'] as Map;
  final metadata = snapshot['metadata'];
  final counts = <String, int>{
    for (final tableName in backupTableNames)
      tableName: (tables[tableName] as List).length,
  };
  return BackupPreview(
    schema: snapshot['schema'] as int? ?? backupSchemaVersion,
    exportedAt: snapshot['exported_at']?.toString(),
    appVersion: metadata is Map ? metadata['app_version']?.toString() : null,
    counts: counts,
  );
}

void validateBackupSnapshot(Map<String, Object?> snapshot) {
  final schema = snapshot['schema'];
  if (schema != null && schema != backupSchemaVersion) {
    throw FormatException('不支持的备份版本：$schema');
  }
  final tables = snapshot['tables'];
  if (tables is! Map) {
    throw const FormatException('备份数据缺少 tables 字段');
  }
  for (final tableName in backupTableNames) {
    if (!tables.containsKey(tableName)) {
      throw FormatException('备份数据缺少 $tableName 表');
    }
    if (tables[tableName] is! List) {
      throw FormatException('$tableName 不是有效列表');
    }
    final rows = tables[tableName] as List;
    for (var index = 0; index < rows.length; index += 1) {
      final row = rows[index];
      if (row is! Map) {
        throw FormatException(
          '${backupTableLabels[tableName] ?? tableName} 第 ${index + 1} 条记录不是有效对象',
        );
      }
      final rowMap = _stringKeyMap(row, tableName, index);
      _validateBackupTableRow(tableName, rowMap, index);
    }
  }
}

void validateBackupReplacementSnapshot(Map<String, Object?> snapshot) {
  validateBackupSnapshot(snapshot);
  if (backupSnapshotTotalRows(snapshot) == 0) {
    throw const FormatException(emptyBackupReplaceErrorMessage);
  }
}

int backupSnapshotTotalRows(Map<String, Object?> snapshot) {
  final tables = snapshot['tables'];
  if (tables is! Map) {
    throw const FormatException('备份数据缺少 tables 字段');
  }
  var totalRows = 0;
  for (final tableName in backupTableNames) {
    final rows = tables[tableName];
    if (rows is! List) {
      throw FormatException('$tableName 不是有效列表');
    }
    totalRows += rows.length;
  }
  return totalRows;
}

Map<String, Object?> _stringKeyMap(Map row, String tableName, int index) {
  final result = <String, Object?>{};
  for (final entry in row.entries) {
    if (entry.key is! String) {
      throw _backupRowFormatException(tableName, index, '包含非字符串字段名');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _validateBackupTableRow(
  String tableName,
  Map<String, Object?> row,
  int index,
) {
  switch (tableName) {
    case 'calculation_history':
      _requireOptionalInt(row, 'id', tableName, index);
      _requireText(row, 'expression', tableName, index);
      _requireText(row, 'result', tableName, index);
      // 中文：**可选**——老备份没有这一列，导入时由 `_normalizeHistoryRow` 按分类器补。
      // English: **optional** — an old backup lacks this column; import fills it via
      //          `_normalizeHistoryRow`.
      _requireOptionalText(row, 'result_kind', tableName, index);
      _requireOptionalText(row, 'tool_id', tableName, index);
      _requireInt(row, 'created_at', tableName, index);
      return;
    case 'notes':
      _requireOptionalInt(row, 'id', tableName, index);
      _requireText(row, 'title', tableName, index);
      _requireOptionalText(row, 'description', tableName, index);
      _requireString(row, 'body', tableName, index);
      _requireInt(row, 'created_at', tableName, index);
      _requireOptionalInt(row, 'updated_at', tableName, index);
      return;
    case 'favorite_tools':
      _requireText(row, 'tool_id', tableName, index);
      _requireInt(row, 'created_at', tableName, index);
      return;
    case 'recent_tools':
      _requireText(row, 'tool_id', tableName, index);
      _requireInt(row, 'used_at', tableName, index);
      return;
    case 'app_settings':
      _requireText(row, 'key', tableName, index);
      _requireString(row, 'value', tableName, index);
      _requireInt(row, 'updated_at', tableName, index);
      return;
  }
}

void _requireText(
  Map<String, Object?> row,
  String key,
  String tableName,
  int index,
) {
  final value = row[key];
  if (value is String && value.trim().isNotEmpty) return;
  throw _backupRowFormatException(tableName, index, '$key 必须是非空字符串');
}

void _requireOptionalText(
  Map<String, Object?> row,
  String key,
  String tableName,
  int index,
) {
  if (!row.containsKey(key) || row[key] == null || row[key] is String) return;
  throw _backupRowFormatException(tableName, index, '$key 必须是字符串');
}

void _requireString(
  Map<String, Object?> row,
  String key,
  String tableName,
  int index,
) {
  if (row[key] is String) return;
  throw _backupRowFormatException(tableName, index, '$key 必须是字符串');
}

void _requireInt(
  Map<String, Object?> row,
  String key,
  String tableName,
  int index,
) {
  if (_isIntegerValue(row[key])) return;
  throw _backupRowFormatException(tableName, index, '$key 必须是整数时间戳');
}

void _requireOptionalInt(
  Map<String, Object?> row,
  String key,
  String tableName,
  int index,
) {
  if (!row.containsKey(key) || row[key] == null || _isIntegerValue(row[key])) {
    return;
  }
  throw _backupRowFormatException(tableName, index, '$key 必须是整数');
}

bool _isIntegerValue(Object? value) {
  if (value is int) return true;
  if (value is num && value.isFinite) return value % 1 == 0;
  if (value is String) return int.tryParse(value.trim()) != null;
  return false;
}

FormatException _backupRowFormatException(
  String tableName,
  int index,
  String reason,
) {
  return FormatException(
    '${backupTableLabels[tableName] ?? tableName} 第 ${index + 1} 条记录字段无效：$reason',
  );
}

String _stripBom(String source) {
  return source.startsWith('\uFEFF') ? source.substring(1) : source;
}

DateTime? _parseBackupDateTime(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return DateTime.tryParse(trimmed);
}
