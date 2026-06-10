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
          BackupImportImpact(
            severity: BackupImportImpactSeverity.danger,
            icon: BackupImportImpactIcon.delete,
            message:
                '${backupTableLabels[tableName] ?? tableName} 将删除本机 ${beforeFor(tableName)} 条',
          ),
    ];
    final reducedTables = [
      for (final tableName in backupTableNames)
        if (deltaFor(tableName) < 0 && sourceFor(tableName) > 0)
          BackupImportImpact(
            severity: BackupImportImpactSeverity.warning,
            icon: BackupImportImpactIcon.replace,
            message:
                '${backupTableLabels[tableName] ?? tableName} 将减少 ${-deltaFor(tableName)} 条',
          ),
    ];
    final replacedTables = [
      for (final tableName in backupTableNames)
        if (sourceFor(tableName) > 0 && beforeFor(tableName) > 0)
          backupTableLabels[tableName] ?? tableName,
    ];
    return [
      if (source.totalRows == 0)
        const BackupImportImpact(
          severity: BackupImportImpactSeverity.danger,
          icon: BackupImportImpactIcon.blocked,
          message: emptyBackupReplaceErrorMessage,
        ),
      ...destructiveTables,
      ...reducedTables,
      if (replacedTables.isNotEmpty)
        BackupImportImpact(
          severity: BackupImportImpactSeverity.warning,
          icon: BackupImportImpactIcon.replace,
          message: '会覆盖本机${replacedTables.join('、')}数据',
        ),
      if (destructiveTables.isEmpty &&
          reducedTables.isEmpty &&
          replacedTables.isEmpty &&
          source.totalRows > 0)
        const BackupImportImpact(
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.replace,
          message: '覆盖后本机数据将与备份文件一致',
        ),
    ];
  }

  List<BackupImportImpact> _mergeImpacts() {
    final addedTables = [
      for (final tableName in backupTableNames)
        if (sourceFor(tableName) > 0)
          '${backupTableLabels[tableName] ?? tableName} +${sourceFor(tableName)}',
    ];
    return [
      if (source.totalRows == 0)
        const BackupImportImpact(
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.merge,
          message: '备份为空，合并导入不会改变本机数据',
        )
      else
        BackupImportImpact(
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.merge,
          message: '会保留本机数据，并尝试加入 ${addedTables.join('、')}',
        ),
      if (sourceFor('app_settings') > 0)
        const BackupImportImpact(
          severity: BackupImportImpactSeverity.warning,
          icon: BackupImportImpactIcon.settings,
          message: '设置项可能按备份内容更新',
        ),
      if (sourceFor('recent_tools') > 0)
        const BackupImportImpact(
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.tools,
          message: '最近工具只保留最新 ${AppDatabase.maxRecentToolRows} 条',
        ),
      if (sourceFor('calculation_history') > 0)
        const BackupImportImpact(
          severity: BackupImportImpactSeverity.info,
          icon: BackupImportImpactIcon.history,
          message: '历史记录合并后仍会保留最近 ${AppDatabase.maxHistoryRows} 条',
        ),
    ];
  }
}

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

class BackupImportImpact {
  const BackupImportImpact({
    required this.severity,
    required this.icon,
    required this.message,
  });

  final BackupImportImpactSeverity severity;
  final BackupImportImpactIcon icon;
  final String message;
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
