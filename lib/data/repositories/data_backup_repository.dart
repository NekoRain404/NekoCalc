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
        BackupTableCount(
          name: tableName,
          label: backupTableLabels[tableName] ?? tableName,
          count: expectedFor(tableName),
        ),
    ];
  }

  int get expectedTotal => expected.values.fold(0, (sum, count) => sum + count);

  String get expectedTotalLabel => '$expectedTotal 条记录';

  String get modeLabel => replaceExisting ? '覆盖恢复' : '合并导入';

  String get totalLabel =>
      replaceExisting ? expectedTotalLabel : '最多 $expectedTotalLabel';

  String get summary {
    return tableCounts
        .map((item) =>
            '${item.label} ${item.count} (${_formatDelta(deltaFor(item.name))})')
        .join(' · ');
  }

  List<BackupImportImpact> get impacts {
    if (replaceExisting) return _replaceImpacts();
    return _mergeImpacts();
  }

  List<BackupImportImpact> _replaceImpacts() {
    final destructiveTables = [
      for (final tableName in backupTableNames)
        if (beforeFor(tableName) > 0 && sourceFor(tableName) == 0)
          BackupImportImpact.deleteTable(
            _tableLabel(tableName),
            beforeFor(tableName),
          ),
    ];
    final reducedTables = [
      for (final tableName in backupTableNames)
        if (deltaFor(tableName) < 0 && sourceFor(tableName) > 0)
          BackupImportImpact.reduceTable(
            _tableLabel(tableName),
            -deltaFor(tableName),
          ),
    ];
    final replacedTables = [
      for (final tableName in backupTableNames)
        if (sourceFor(tableName) > 0 && beforeFor(tableName) > 0)
          _tableLabel(tableName),
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
    // 中文：载荷项（「历史 +3」）在这里拼——表名是内容，`+N` 是记号；整句话、连接符与尾巴由呈现层
    //       拼（`backupImportImpactMessage`）。这与迁移前的分工一致：这一格本来就是给句子备料的。
    // English: the payload items ("历史 +3") are composed here — a table name is content and `+N` is
    //          notation; the sentence, the joining separator and the tail are put together by the
    //          presentation layer (`backupImportImpactMessage`). That is the same split as before the
    //          move: this cell always prepared the ingredients for the sentence.
    final addedTables = [
      for (final tableName in backupTableNames)
        if (sourceFor(tableName) > 0)
          '${_tableLabel(tableName)} +${sourceFor(tableName)}',
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

/// 中文：表名 → 给人看的标签（`backupTableLabels` 认不出时退回表名本身）。迁移前这条查表散在
///       四处，是重复的；翻成令牌那几格之后仍要它，且只在这一族里用。
/// English: table name → human-facing label (falling back to the name itself when
///          `backupTableLabels` does not know it). Before the move this lookup was repeated in four
///          places; the token cells still need it, and it is used by this family only.
String _tableLabel(String tableName) =>
    backupTableLabels[tableName] ?? tableName;

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
///       `backupImportImpactMessage(impact, strings)` 那个穷尽 `switch` 接上；表名标签、条数与
///       上限是**载荷**，留在影响上由呈现层拼进句子（多张表时那个连接符也跟着语言走，
///       `backupTableListSeparator`）。
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
///          `settings_backup_messages.dart`; the table labels, counts and limits are **payload** and
///          stay on the impact for the presentation layer to splice in (with several tables, the
///          joining separator follows the language too — `backupTableListSeparator`).
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
///       **`labels` 是载荷项本身**：覆盖恢复那几个表名、或合并时「历史 +3」这样的备料项，
///       连接符由呈现层按语言拼（`backupTableListSeparator`）。
/// English: **one import impact: the verdict plus its payload, with no user-facing sentence.**
///
///          The unnamed constructor is private, the ten named ones each carry their own payload, and
///          they hard-code `severity` and `icon` on the spot — so "the token says A while the colour
///          says B" has nowhere to land. The presentation layer reads the payloads with `!` (see
///          `settings_backup_messages.dart`), so a public unnamed constructor would leave a road where
///          the token says `deleteTable` while the table name is null — the same reasoning as
///          `CalculatorSubmitResult`.
///
///          **`labels` are payload items themselves**: the table names to be overwritten, or merge
///          ingredients such as "历史 +3"; the joining separator is put in by the presentation layer,
///          per language (`backupTableListSeparator`).
class BackupImportImpact {
  const BackupImportImpact._({
    required this.kind,
    required this.severity,
    required this.icon,
    this.label,
    this.count,
    this.labels = const [],
    this.limit,
  });

  const BackupImportImpact.deleteTable(String label, int count)
      : this._(
          kind: BackupImportImpactKind.deleteTable,
          severity: BackupImportImpactSeverity.danger,
          icon: BackupImportImpactIcon.delete,
          label: label,
          count: count,
        );

  const BackupImportImpact.reduceTable(String label, int count)
      : this._(
          kind: BackupImportImpactKind.reduceTable,
          severity: BackupImportImpactSeverity.warning,
          icon: BackupImportImpactIcon.replace,
          label: label,
          count: count,
        );

  const BackupImportImpact.emptySource()
      : this._(
          kind: BackupImportImpactKind.emptySource,
          severity: BackupImportImpactSeverity.danger,
          icon: BackupImportImpactIcon.blocked,
        );

  const BackupImportImpact.overwriteTables(List<String> labels)
      : this._(
          kind: BackupImportImpactKind.overwriteTables,
          severity: BackupImportImpactSeverity.warning,
          icon: BackupImportImpactIcon.replace,
          labels: labels,
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

  const BackupImportImpact.mergeAddsTables(List<String> labels)
      : this._(
          kind: BackupImportImpactKind.mergeAddsTables,
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.merge,
          labels: labels,
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

  /// 中文：`deleteTable` / `reduceTable` 的载荷：表名标签与条数。
  /// English: the payload of `deleteTable` / `reduceTable`: the table label and the count.
  final String? label;
  final int? count;

  /// 中文：`overwriteTables` / `mergeAddsTables` 的载荷：要连接起来的那些项。
  /// English: the payload of `overwriteTables` / `mergeAddsTables`: the items to join.
  final List<String> labels;

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
          label: backupTableLabels[tableName] ?? tableName,
          source: sourceFor(tableName),
          before: beforeFor(tableName),
          after: afterFor(tableName),
          delta: deltaFor(tableName),
          skipped: skippedFor(tableName),
        ),
    ];
  }

  String get modeLabel => replaceExisting ? '覆盖恢复' : '合并导入';

  String get resultLabel {
    final sourceRows = source.totalRows;
    final positiveDelta = tableReports.fold<int>(
      0,
      (sum, report) => sum + math.max(0, report.delta),
    );
    final skipped = tableReports.fold<int>(
      0,
      (sum, report) => sum + report.skipped,
    );
    if (replaceExisting) {
      if (skipped == 0) return '已恢复 $sourceRows 条记录';
      return '已恢复 ${sourceRows - skipped} 条记录，跳过 $skipped 条';
    }
    if (skipped == 0) return '已合并 $positiveDelta 条记录';
    return '已合并 $positiveDelta 条记录，跳过或裁剪 $skipped 条';
  }

  String get summary {
    final deltas = [
      for (final item in tableReports)
        '${item.label} ${item.after} (${_formatDelta(item.delta)}${item.skipped > 0 ? ', 跳过 ${item.skipped}' : ''})',
    ];
    return deltas.join(' · ');
  }

  static String _formatDelta(int value) {
    if (value > 0) return '+$value';
    return value.toString();
  }
}

class BackupImportTableReport {
  const BackupImportTableReport({
    required this.name,
    required this.label,
    required this.source,
    required this.before,
    required this.after,
    required this.delta,
    required this.skipped,
  });

  final String name;
  final String label;
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

  String get successMessage => '备份已保存：${preview.totalLabel}';

  String get detail {
    return [
      fileName,
      '',
      '版本：${preview.appVersion ?? '未知'}',
      '导出时间：${preview.exportedAt ?? '本机当前'}',
      '总计：${preview.totalLabel}',
      preview.summary,
    ].join('\n');
  }
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

String _formatDelta(int value) {
  if (value > 0) return '+$value';
  return value.toString();
}
