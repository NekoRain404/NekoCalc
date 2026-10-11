import 'dart:convert';
import 'dart:math' as math;

import '../../core/utils/backup_snapshot_validator.dart';
import '../local/app_database.dart';

class BackupImportPlan {
  const BackupImportPlan({
    required this.source,
    required this.local,
    required this.replaceExisting,
    required this.expected,
  });

  final BackupPreview source;
  final BackupPreview local;
  final bool replaceExisting;
  final Map<String, int> expected;

  int beforeFor(String tableName) => local.counts[tableName] ?? 0;

  int sourceFor(String tableName) => source.counts[tableName] ?? 0;

  int expectedFor(String tableName) => expected[tableName] ?? 0;

  int deltaFor(String tableName) =>
      expectedFor(tableName) - beforeFor(tableName);

  List<BackupTableCount> get tableCounts {
    return [
      for (final tableName in backupTableNames)
        BackupTableCount(name: tableName, count: expectedFor(tableName)),
    ];
  }

  int get expectedTotal => expected.values.fold(0, (sum, count) => sum + count);

  // 中文：**`expectedTotalLabel` / `modeLabel` / `totalLabel` / `summary` 从前在这里拼那几句中文**
  //       （直接印在设置页的导入对话框上）。数据对象活得比界面长，界面那张按语言切的表够不着它，
  //       于是英文界面下它照样是中文——`docs/verification.md` §5i 记着这条。现在留下的只有
  //       **载荷**：`replaceExisting`、`expectedTotal` 与每张表的表名（键）/ 条数，字住在
  //       `SettingsBackupStrings` 里，由 `settings_backup_text.dart` 在呈现边缘拼
  //       （`backupPlanModeLabel` / `backupPlanTotalLabel` / `backupPlanSummary`），表名的标签也在
  //       那里查（`backupTableLabel`）。
  // English: **`expectedTotalLabel` / `modeLabel` / `totalLabel` / `summary` used to compose those
  //          Chinese sentences right here** (printed straight onto the settings page's import dialog).
  //          A data object outlives the UI and a language-keyed interface table cannot reach it, so an
  //          English interface still printed Chinese — recorded in `docs/verification.md` §5i. What is
  //          left is **the payload only**: `replaceExisting`, `expectedTotal` and each table's name (the
  //          key) / count; the words live in `SettingsBackupStrings` and are composed at the presentation
  //          edge by `settings_backup_text.dart` (`backupPlanModeLabel` / `backupPlanTotalLabel` /
  //          `backupPlanSummary`), where `backupTableLabel` looks the labels up as well.

  List<BackupImportImpact> get impacts {
    if (replaceExisting) return _replaceImpacts();
    return _mergeImpacts();
  }

  List<BackupImportImpact> _replaceImpacts() {
    // 中文：载荷带的是**表名（键）**，不是标签——标签是词，由呈现层按这个键查
    //       （`backupTableLabel`，`settings_backup_messages.dart` 那两条按令牌取句子的路径）。
    // English: the payloads carry the **table name (the key)**, not a label — a label is copy, looked up
    //          from this key by the presentation layer (`backupTableLabel`, in the two token-keyed paths
    //          of `settings_backup_messages.dart`).
    final destructiveTables = [
      for (final tableName in backupTableNames)
        if (beforeFor(tableName) > 0 && sourceFor(tableName) == 0)
          BackupImportImpact.deleteTable(tableName, beforeFor(tableName)),
    ];
    final reducedTables = [
      for (final tableName in backupTableNames)
        if (deltaFor(tableName) < 0 && sourceFor(tableName) > 0)
          BackupImportImpact.reduceTable(tableName, -deltaFor(tableName)),
    ];
    final replacedTables = [
      for (final tableName in backupTableNames)
        if (sourceFor(tableName) > 0 && beforeFor(tableName) > 0) tableName,
    ];
    return [
      if (source.totalRows == 0) const BackupImportImpact.emptySource(),
      ...destructiveTables,
      ...reducedTables,
      if (replacedTables.isNotEmpty)
        BackupImportImpact.overwriteTables(replacedTables),
      if (destructiveTables.isEmpty &&
          reducedTables.isEmpty &&
          replacedTables.isEmpty &&
          source.totalRows > 0)
        const BackupImportImpact.replaceKeepsIdentical(),
    ];
  }

  List<BackupImportImpact> _mergeImpacts() {
    // 中文：载荷项在这里备料——**表名（键）与条数**；「历史 +3」这句话里的标签与 `+N` 记号都由呈现层
    //       拼（`backupImportImpactMessage`），表名是内容、`+N` 是记号。这与迁移前的分工一致：
    //       这一格本来就是给句子备料的，只是备的料从「标签 + 条数」换成了「键 + 条数」。
    // English: the payload items are prepared here — **the table name (key) and the count**; the label
    //          and the `+N` notation of "历史 +3" are both put together by the presentation layer
    //          (`backupImportImpactMessage`). The split is the same as before the move: this cell always
    //          prepared ingredients for the sentence, only the ingredients became "key + count" instead
    //          of "label + count".
    final addedTables = [
      for (final tableName in backupTableNames)
        if (sourceFor(tableName) > 0)
          BackupTableCount(name: tableName, count: sourceFor(tableName)),
    ];
    return [
      if (source.totalRows == 0)
        const BackupImportImpact.mergeEmptySource()
      else
        BackupImportImpact.mergeAddsTables(addedTables),
      if (sourceFor('app_settings') > 0)
        const BackupImportImpact.mergeUpdatesSettings(),
      if (sourceFor('recent_tools') > 0)
        const BackupImportImpact.mergeKeepsRecentLimit(
            AppDatabase.maxRecentToolRows),
      if (sourceFor('calculation_history') > 0)
        const BackupImportImpact.mergeKeepsHistoryLimit(
            AppDatabase.maxHistoryRows),
    ];
  }
}

/// 中文：**表名 → 标签的查表不在这里**（`_tableLabel` 从前站在这儿）：标签是给人看的词，住在
///       `SettingsBackupStrings.backupTableLabels` 里，由呈现边缘的 `backupTableLabel(tableName,
///       strings)` 查（`settings_backup_text.dart`）——本文件只经手表名（键）。
/// English: **the name → label lookup is not here** (a `_tableLabel` used to stand here): a label is
///          copy, it lives in `SettingsBackupStrings.backupTableLabels` and is looked up at the
///          presentation edge by `backupTableLabel(tableName, strings)`
///          (`settings_backup_text.dart`) — this file only handles table names (keys).

enum BackupImportImpactSeverity { info, warning, danger }

enum BackupImportImpactIcon {
  merge,
  replace,
  delete,
  blocked,
  settings,
  tools,
  history
}

/// 中文：**一条导入影响说的是哪件事——它既是判据，也是呈现层取那句话用的令牌。**
///
///       十格与 `SettingsStrings` 里的十格一一对应（`backupImpactDeleteTable` …
///       `backupImpactMergeKeepsHistoryLimit`），由 `settings_backup_messages.dart` 的
///       `backupImportImpactMessage(impact, strings)` 那个穷尽 `switch` 接上；表名（键）、条数与
///       上限是**载荷**，留在影响上由呈现层拼进句子——表名的标签由 `backupTableLabel` 在那一刻查，
///       多张表时那个连接符也跟着语言走（`backupTableListSeparator`）。
///
///       **这十格从前是在这里拼的句子**（`BackupImportImpact.message`，直接印在设置页导入对话框的
///       影响清单里）：这份清单由数据层产出、活到界面之外，界面那张按语言切的文案表够不着它，所以
///       英文界面下它照样是中文——`docs/verification.md` §5i 记着这条层次性缺陷。
///
///       **十格互斥**，一批一批看：`deleteTable`（本机有、文件没有）与 `reduceTable`（两边都有但变少）
///       的判据里 `sourceFor` 一为零一为正，不会同时命中同一张表；`overwriteTables`（两边都有的那些
///       表）与 `replaceKeepsIdentical`（三张清单全空）由「有没有东西可覆盖」的正反两面分开；
///       `mergeAddsTables` 与 `mergeEmptySource` 由源文件总行数是否为零分开（同一个 `if / else`）；
///       `mergeUpdatesSettings`、`mergeKeepsRecentLimit`、`mergeKeepsHistoryLimit` 三格各自绑定**一个**
///       表名（设置 / 最近工具 / 历史）与「文件里有这张表」这一个条件，三条互不相干，可以同时出现；
///       `emptySource`（覆盖模式 + 空文件）与 `replaceKeepsIdentical` 的第二个合取项
///       `source.totalRows > 0` 互补，覆盖模式里两者必有其一。
/// English: **which thing one import impact says — a verdict, and the token the presentation layer
///          resolves the sentence with.**
///
///          The ten values correspond one for one with ten cells in `SettingsStrings`
///          (`backupImpactDeleteTable` … `backupImpactMergeKeepsHistoryLimit`), wired up by the
///          exhaustive `switch` in `backupImportImpactMessage(impact, strings)` in
///          `settings_backup_messages.dart`; the table names (keys), counts and limits are **payload**
///          and stay on the impact for the presentation layer to splice in — the labels of those names
///          are looked up at that moment by `backupTableLabel`, and with several tables the joining
///          separator follows the language too (`backupTableListSeparator`).
///
///          **These ten used to be sentences composed right here** (`BackupImportImpact.message`,
///          printed straight into the import dialog's impact list on the settings page): the list is
///          produced by the data layer and outlives the UI, a language-keyed interface table cannot
///          reach it, so an English interface still printed Chinese — the layering defect recorded in
///          `docs/verification.md` §5i.
///
///          **The ten are mutually exclusive**, taken batch by batch: `deleteTable` (on this device but
///          not in the file) and `reduceTable` (in both but smaller) have `sourceFor` zero in one and
///          positive in the other, so they cannot both hit the same table; `overwriteTables` (the
///          tables present on both sides) and `replaceKeepsIdentical` (all three lists empty) split the
///          two sides of "is there anything to overwrite"; `mergeAddsTables` against `mergeEmptySource`
///          is decided by whether the source's total row count is zero (one `if / else`);
///          `mergeUpdatesSettings`, `mergeKeepsRecentLimit` and `mergeKeepsHistoryLimit` each bind **one**
///          table name (settings / recent tools / history) to one condition ("the file carries this
///          table"), so the three are independent and may appear together; `emptySource` (replace mode
///          with an empty file) and the second conjunct of `replaceKeepsIdentical`
///          (`source.totalRows > 0`) are complements, so replace mode always yields one of them.
enum BackupImportImpactKind {
  deleteTable,
  reduceTable,
  emptySource,
  overwriteTables,
  replaceKeepsIdentical,
  mergeEmptySource,
  mergeAddsTables,
  mergeUpdatesSettings,
  mergeKeepsRecentLimit,
  mergeKeepsHistoryLimit,
}

/// 中文：**一条导入影响：判据 + 载荷，没有给人看的句子。**
///
///       无名构造是私有的，十条命名构造各带各的载荷，`severity` 与 `icon` 也由它们当场写死——
///       「令牌说 A、颜色却是 B」这种不一致因此没有落点。呈现层读载荷时用的是 `!`
///       （见 `settings_backup_messages.dart`），所以留一条公开的无名构造就是留一条
///       「令牌说 deleteTable、表名却是 null」的路，同 `CalculatorSubmitResult` 那条理由。
///
///       **载荷带的是表名（键）**：覆盖恢复那几个要覆盖的表名、合并时每张表加入多少条
///       （`BackupTableCount`：键 + 条数），连接符与「历史 +3」里那个标签、那个 `+N` 记号都由呈现层
///       拼（`backupTableListSeparator`、`backupTableLabel`）。
/// English: **one import impact: the verdict plus its payload, with no user-facing sentence.**
///
///          The unnamed constructor is private, the ten named ones each carry their own payload, and
///          they hard-code `severity` and `icon` on the spot — so "the token says A while the colour
///          says B" has nowhere to land. The presentation layer reads the payloads with `!` (see
///          `settings_backup_messages.dart`), so a public unnamed constructor would leave a road where
///          the token says `deleteTable` while the table name is null — the same reasoning as
///          `CalculatorSubmitResult`.
///
///          **The payload carries table names (keys)**: the names to be overwritten, or how many rows
///          each table gains on a merge (`BackupTableCount`: key + count). The joining separator, the
///          label inside "历史 +3" and its `+N` notation are all put together by the presentation layer
///          (`backupTableListSeparator`, `backupTableLabel`).
class BackupImportImpact {
  const BackupImportImpact._({
    required this.kind,
    required this.severity,
    required this.icon,
    this.tableName,
    this.count,
    this.tableNames = const [],
    this.additions = const [],
    this.limit,
  });

  const BackupImportImpact.deleteTable(String tableName, int count)
      : this._(
          kind: BackupImportImpactKind.deleteTable,
          severity: BackupImportImpactSeverity.danger,
          icon: BackupImportImpactIcon.delete,
          tableName: tableName,
          count: count,
        );

  const BackupImportImpact.reduceTable(String tableName, int count)
      : this._(
          kind: BackupImportImpactKind.reduceTable,
          severity: BackupImportImpactSeverity.warning,
          icon: BackupImportImpactIcon.replace,
          tableName: tableName,
          count: count,
        );

  const BackupImportImpact.emptySource()
      : this._(
          kind: BackupImportImpactKind.emptySource,
          severity: BackupImportImpactSeverity.danger,
          icon: BackupImportImpactIcon.blocked,
        );

  const BackupImportImpact.overwriteTables(List<String> tableNames)
      : this._(
          kind: BackupImportImpactKind.overwriteTables,
          severity: BackupImportImpactSeverity.warning,
          icon: BackupImportImpactIcon.replace,
          tableNames: tableNames,
        );

  const BackupImportImpact.replaceKeepsIdentical()
      : this._(
          kind: BackupImportImpactKind.replaceKeepsIdentical,
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.replace,
        );

  const BackupImportImpact.mergeEmptySource()
      : this._(
          kind: BackupImportImpactKind.mergeEmptySource,
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.merge,
        );

  const BackupImportImpact.mergeAddsTables(List<BackupTableCount> additions)
      : this._(
          kind: BackupImportImpactKind.mergeAddsTables,
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.merge,
          additions: additions,
        );

  const BackupImportImpact.mergeUpdatesSettings()
      : this._(
          kind: BackupImportImpactKind.mergeUpdatesSettings,
          severity: BackupImportImpactSeverity.warning,
          icon: BackupImportImpactIcon.settings,
        );

  const BackupImportImpact.mergeKeepsRecentLimit(int limit)
      : this._(
          kind: BackupImportImpactKind.mergeKeepsRecentLimit,
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.tools,
          limit: limit,
        );

  const BackupImportImpact.mergeKeepsHistoryLimit(int limit)
      : this._(
          kind: BackupImportImpactKind.mergeKeepsHistoryLimit,
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.history,
          limit: limit,
        );

  final BackupImportImpactKind kind;
  final BackupImportImpactSeverity severity;
  final BackupImportImpactIcon icon;

  /// 中文：`deleteTable` / `reduceTable` 的载荷：表名（键）与条数。标签是词，由呈现层按这个键查
  ///       （`backupTableLabel`）。
  /// English: the payload of `deleteTable` / `reduceTable`: the table name (the key) and the count. The
  ///          label is copy, looked up from this key at the presentation edge (`backupTableLabel`).
  final String? tableName;
  final int? count;

  /// 中文：`overwriteTables` 的载荷：要连接起来的那些表名（键）。
  /// English: the payload of `overwriteTables`: the table names (keys) to join.
  final List<String> tableNames;

  /// 中文：`mergeAddsTables` 的载荷：每张表加入多少条（键 + 条数）；标签与 `+N` 记号由呈现层拼。
  /// English: the payload of `mergeAddsTables`: how many rows each table gains (key + count); the label
  ///          and the `+N` notation are put together by the presentation layer.
  final List<BackupTableCount> additions;

  /// 中文：两个「上限」格的载荷：合并后每张表保留多少条（`AppDatabase` 的两个常量）。
  /// English: the payload of the two "limit" cells: how many rows per table survive a merge (the two
  ///          `AppDatabase` constants).
  final int? limit;
}

class BackupImportReport {
  const BackupImportReport({
    required this.source,
    required this.before,
    required this.after,
    required this.replaceExisting,
  });

  final BackupPreview source;
  final BackupPreview before;
  final BackupPreview after;
  final bool replaceExisting;

  int beforeFor(String tableName) => before.counts[tableName] ?? 0;

  int sourceFor(String tableName) => source.counts[tableName] ?? 0;

  int afterFor(String tableName) => after.counts[tableName] ?? 0;

  int deltaFor(String tableName) {
    return afterFor(tableName) - beforeFor(tableName);
  }

  int skippedFor(String tableName) {
    final sourceCount = sourceFor(tableName);
    if (replaceExisting) {
      return math.max(0, sourceCount - afterFor(tableName));
    }
    final positiveDelta = math.max(0, deltaFor(tableName));
    return math.max(0, sourceCount - positiveDelta);
  }

  List<BackupImportTableReport> get tableReports {
    return [
      for (final tableName in backupTableNames)
        BackupImportTableReport(
          name: tableName,
          source: sourceFor(tableName),
          before: beforeFor(tableName),
          after: afterFor(tableName),
          delta: deltaFor(tableName),
          skipped: skippedFor(tableName),
        ),
    ];
  }

  // 中文：**`modeLabel` / `resultLabel` / `summary` 从前在这里拼那几句中文**（直接印在导入结果的
  //       `SnackBar` 与详情里）。理由同 `BackupImportPlan`：数据对象活得比界面长。现在留下的只有
  //       **载荷**——`replaceExisting`、`source` / `before` / `after` 三份预览与 `tableReports`
  //       的读数（每行带表名键，标签由呈现层查），字住在 `SettingsBackupStrings` 里，由
  //       `settings_backup_text.dart` 在呈现边缘拼
  //       （`backupReportModeLabel` / `backupReportResultLabel` / `backupReportSummary`）。
  // English: **`modeLabel` / `resultLabel` / `summary` used to compose those Chinese sentences right
  //          here** (printed straight into the import result's `SnackBar` and detail). The reason is
  //          the same as `BackupImportPlan`'s: a data object outlives the UI. What is left is **the
  //          payload only** — `replaceExisting`, the three previews `source` / `before` / `after` and
  //          the readings of `tableReports` (each row carries the table key; the label is looked up at
  //          the edge); the words live in `SettingsBackupStrings` and are composed at the presentation
  //          edge by `settings_backup_text.dart` (`backupReportModeLabel` /
  //          `backupReportResultLabel` / `backupReportSummary`).
}

class BackupImportTableReport {
  const BackupImportTableReport({
    required this.name,
    required this.source,
    required this.before,
    required this.after,
    required this.delta,
    required this.skipped,
  });

  /// 中文：表名（键）；标签由呈现层查（`backupTableLabel`）。
  /// English: the table name (the key); the label is looked up at the presentation edge
  ///          (`backupTableLabel`).
  final String name;
  final int source;
  final int before;
  final int after;
  final int delta;
  final int skipped;

  bool get hasSkippedRows => skipped > 0;
}

class BackupExportResult {
  const BackupExportResult({
    required this.fileName,
    required this.content,
    required this.preview,
  });

  final String fileName;
  final String content;
  final BackupPreview preview;
}

class DataBackupRepository {
  const DataBackupRepository(this._db);

  final AppDatabase _db;

  Future<BackupPreview> currentPreview() async {
    return BackupPreview(
      schema: backupSchemaVersion,
      exportedAt: null,
      appVersion: null,
      counts: await _db.backupTableCounts(),
    );
  }

  Future<String> exportJson() async {
    final snapshot = await _db.exportSnapshot();
    return const JsonEncoder.withIndent('  ').convert(snapshot);
  }

  Future<BackupExportResult> exportBackup({DateTime? createdAt}) async {
    final content = await exportJson();
    final preview = previewJson(content);
    return BackupExportResult(
      fileName: _backupFileName(createdAt ?? DateTime.now()),
      content: content,
      preview: preview,
    );
  }

  Future<BackupImportPlan> planImport(
    String source, {
    required bool replaceExisting,
  }) async {
    final sourcePreview = previewBackupSnapshot(source);
    final localPreview = await currentPreview();
    return buildImportPlan(
      source: sourcePreview,
      local: localPreview,
      replaceExisting: replaceExisting,
    );
  }

  Future<BackupImportReport> importJson(
    String source, {
    bool replaceExisting = true,
  }) async {
    // 中文：仓库层只接受已校验快照，避免 UI 层传入半截 JSON 时清库。
    // English: Import only validated snapshots so partial JSON from the UI cannot clear the database.
    final snapshot = parseBackupSnapshot(source);
    final sourcePreview = previewBackupSnapshot(source);
    if (replaceExisting) {
      validateBackupReplacementSnapshot(snapshot);
    }
    final before = await currentPreview();
    await _db.importSnapshot(
      snapshot,
      replaceExisting: replaceExisting,
    );
    final after = await currentPreview();
    return BackupImportReport(
      source: sourcePreview,
      before: before,
      after: after,
      replaceExisting: replaceExisting,
    );
  }

  BackupPreview previewJson(String source) {
    return previewBackupSnapshot(source);
  }

  BackupImportPlan buildImportPlan({
    required BackupPreview source,
    required BackupPreview local,
    required bool replaceExisting,
  }) {
    return BackupImportPlan(
      source: source,
      local: local,
      replaceExisting: replaceExisting,
      expected: {
        for (final tableName in backupTableNames)
          tableName: _expectedImportCount(
            tableName: tableName,
            source: source,
            local: local,
            replaceExisting: replaceExisting,
          ),
      },
    );
  }

  int _expectedImportCount({
    required String tableName,
    required BackupPreview source,
    required BackupPreview local,
    required bool replaceExisting,
  }) {
    final baseCount = replaceExisting
        ? source.counts[tableName] ?? 0
        : (local.counts[tableName] ?? 0) + (source.counts[tableName] ?? 0);
    final limit = switch (tableName) {
      'calculation_history' => AppDatabase.maxHistoryRows,
      'recent_tools' => AppDatabase.maxRecentToolRows,
      _ => null,
    };
    return limit == null ? baseCount : baseCount.clamp(0, limit);
  }

  String _backupFileName(DateTime value) {
    final local = value.toLocal();
    return 'nekocalc-backup-${local.year}${_twoDigits(local.month)}'
        '${_twoDigits(local.day)}-${_twoDigits(local.hour)}'
        '${_twoDigits(local.minute)}.json';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
