import 'dart:math' as math;

import '../../../core/utils/backup_snapshot_validator.dart';
import '../../../data/repositories/data_backup_repository.dart';
import 'settings_backup_strings.dart';

/// 中文：**备份预览 / 计划 / 报告 / 导出那几族残余句子的翻译处——数据层给载荷，这里给字。**
///
///       `BackupPreview.summary` / `totalLabel`（校验器）、`BackupImportPlan.modeLabel` /
///       `totalLabel` / `expectedTotalLabel` / `summary`、`BackupImportReport.modeLabel` /
///       `resultLabel` / `summary`与 `BackupExportResult.successMessage` / `detail`（数据层）从前
///       各自拼那几句中文并直接上屏（设置页的本机数据行、导入对话框、导入结果详情、导出回执）。
///       数据对象活得比界面长，界面那张按语言切的表够不着它，于是英文界面下印的仍是中文
///       （`docs/verification.md` §5i）。现在那些句子住在 [SettingsBackupStrings] 里，由这八个函数
///       在**呈现边缘**取——取表的语言就是屏幕的语言。
///
///       **形状照的是已经转过的路径**：`notesSummaryLabel` / `backupPreviewWarningMessage` /
///       `backupImportImpactMessage`（载荷在产出方，字在呈现层的表里）。这一族与
///       `settings_backup_messages.dart` 里那两条**是同一套分工**：那条文件按**令牌**取口语句，
///       这一条把**数字与表名**拼进模板——两处都读同一张表 [SettingsBackupStrings]。
///
///       **数字与表名是载荷，句子形状是这里的事**：表名标签（`backupTableLabels` 的结果）与各种
///       条数留在对象上，连接符（`backupSummarySeparator`）、括号与「跳过」那根尾巴都按语言在这里
///       拼上去。`_formatDelta`（`+N` / `N`）也从数据层搬来这里——它是记号，与语言无关，但和句子
///       拼在一起，留在产出方就还会有人想在那里拼整句。
///
///       **中文逐字节与迁移前相同**：模板、连接符、括号与尾巴都是原来那几行 `return` 的抄本，
///       旧文案对照表（`settings_backup_text_test.dart`）钉着它们。
/// English: **where the preview / plan / report / export families' residual sentences are translated —
///          the data layer hands over the payload, this hands over the words.**
///
///          `BackupPreview.summary` / `totalLabel` (the validator), `BackupImportPlan.modeLabel` /
///          `totalLabel` / `expectedTotalLabel` / `summary`, `BackupImportReport.modeLabel` /
///          `resultLabel` / `summary` and `BackupExportResult.successMessage` / `detail` (the data
///          layer) used to compose those Chinese sentences themselves and print them straight (the
///          settings page's on-device row, the import dialog, the import-result detail, the export
///          receipt). A data object outlives the UI and a language-keyed interface table cannot reach
///          it, so an English interface still printed Chinese (`docs/verification.md` §5i). Those
///          sentences now live in [SettingsBackupStrings], fetched **at the presentation edge** by
///          these eight functions — the language of the table is the language on screen.
///
///          **The shape is copied from the converted paths**: `notesSummaryLabel` /
///          `backupPreviewWarningMessage` / `backupImportImpactMessage` (payload in the producer, words
///          in the presentation layer's table). This family and the two in
///          `settings_backup_messages.dart` **are the same division of labour**: that file resolves
///          whole sentences by **token**, this one splices **numbers and table names** into templates —
///          both read the same table, [SettingsBackupStrings].
///
///          **The numbers and table names are payload, the sentence's shape is this file's business**:
///          the table labels (what `backupTableLabels` yields) and the various counts stay on the
///          objects, and the separator (`backupSummarySeparator`), the brackets and the "skipped" tail
///          are put together here, per language. `_formatDelta` (`+N` / `N`) moved here from the data
///          layer too — it is notation and language-independent, but it sits inside the sentence, and
///          leaving it in the producer would still tempt somebody to build the whole sentence there.
///
///          **The Chinese is byte-identical to what it was**: the templates, separator, brackets and
///          tails are copies of those `return` lines, pinned by the legacy tables in
///          `settings_backup_text_test.dart`.

/// 中文：**一份备份预览里那张表清单的一句话**（`'历史 3 · 笔记 2 · …'`）。
/// English: **one sentence listing a backup preview's tables** (`'历史 3 · 笔记 2 · …'`).
String backupPreviewTableSummary(
  BackupPreview preview,
  SettingsBackupStrings strings,
) {
  return preview.tableCounts
      .map((item) => strings.backupSummaryItem(item.label, item.count))
      .join(strings.backupSummarySeparator);
}

/// 中文：**计划的模式词**（覆盖恢复 / 合并导入），由 `replaceExisting` 选。
/// English: **the plan's mode word** (replace / merge), chosen by `replaceExisting`.
String backupPlanModeLabel(
  BackupImportPlan plan,
  SettingsBackupStrings strings,
) {
  return strings.backupModeLabel(plan.replaceExisting);
}

/// 中文：**计划的总数那一句**——覆盖恢复说「N 条记录」，合并导入说「最多 N 条记录」（`最多` 是
///       语言相关的词，所以整句都在表里）。
/// English: **the plan's total** — replace says "N records", merge says "at most N records" ("at most"
///          is language-dependent, so the whole phrase lives in the table).
String backupPlanTotalLabel(
  BackupImportPlan plan,
  SettingsBackupStrings strings,
) {
  final total = strings.backupTotalRecords(plan.expectedTotal);
  return plan.replaceExisting ? total : strings.backupTotalUpTo(total);
}

/// 中文：**计划里每张表那一句**（`'历史 6 (+4)'`），增量记号由 [_formatDelta] 拼。
/// English: **one plan row per table** (`'历史 6 (+4)'`); the delta notation is composed by
///          [_formatDelta].
String backupPlanSummary(
  BackupImportPlan plan,
  SettingsBackupStrings strings,
) {
  return plan.tableCounts
      .map((item) => strings.backupPlanSummaryItem(
            item.label,
            item.count,
            _formatDelta(plan.deltaFor(item.name)),
          ))
      .join(strings.backupSummarySeparator);
}

/// 中文：**报告的模式词**，与计划那格同一批词（`覆盖恢复` / `合并导入`）。
/// English: **the report's mode word**, the same batch as the plan's (`覆盖恢复` / `合并导入`).
String backupReportModeLabel(
  BackupImportReport report,
  SettingsBackupStrings strings,
) {
  return strings.backupModeLabel(report.replaceExisting);
}

/// 中文：**报告的结果那一句**——条数与「跳过或裁剪」那根尾巴由这里算出来（覆盖恢复看源文件总行数，
///       合并导入看正向增量），迁移前那两个分支的顺序与判据逐字未动。
/// English: **the report's result sentence** — the counts and the "skipped or trimmed" tail are computed
///          here (replace reads the source's total rows, merge the positive deltas); the two branches'
///          order and criteria are untouched, character for character.
String backupReportResultLabel(
  BackupImportReport report,
  SettingsBackupStrings strings,
) {
  final sourceRows = report.source.totalRows;
  final positiveDelta = report.tableReports.fold<int>(
    0,
    (sum, row) => sum + math.max(0, row.delta),
  );
  final skipped = report.tableReports.fold<int>(
    0,
    (sum, row) => sum + row.skipped,
  );
  if (report.replaceExisting) {
    return skipped == 0
        ? strings.backupReportRestored(sourceRows)
        : strings.backupReportRestoredSkipped(sourceRows - skipped, skipped);
  }
  return skipped == 0
      ? strings.backupReportMerged(positiveDelta)
      : strings.backupReportMergedSkipped(positiveDelta, skipped);
}

/// 中文：**报告里每张表那一句**（`'历史 500 (+10, 跳过 30)'`）——括号里的跳过尾巴只在
///       `skipped > 0` 时接上，与迁移前那个三元表达式一致。
/// English: **one report row per table** (`'历史 500 (+10, 跳过 30)'`) — the skipped tail inside the
///          bracket is appended only when `skipped > 0`, exactly as the pre-move conditional did.
String backupReportSummary(
  BackupImportReport report,
  SettingsBackupStrings strings,
) {
  return report.tableReports
      .map((item) => strings.backupReportSummaryItem(
            item.label,
            item.after,
            _formatDelta(item.delta),
            item.skipped > 0
                ? strings.backupReportSkippedTail(item.skipped)
                : '',
          ))
      .join(strings.backupSummarySeparator);
}

/// 中文：**导出成功那条回执**（`'备份已保存：N 条记录'`）。
/// English: **the export receipt** (`'备份已保存：N 条记录'`).
String backupExportSuccessMessage(
  BackupExportResult result,
  SettingsBackupStrings strings,
) {
  return strings.backupExportSaved(
    strings.backupTotalRecords(result.preview.totalRows),
  );
}

/// 中文：**导出详情那份正文**（版本、导出时间、总计加表清单）——换行分隔，最后一段是预览摘要那句。
/// English: **the export detail's body** (version, export time, total plus the table list) — newline
///          separated, with the preview summary as its last block.
String backupExportDetail(
  BackupExportResult result,
  SettingsBackupStrings strings,
) {
  return [
    result.fileName,
    '',
    strings.backupExportVersion(
      result.preview.appVersion ?? strings.backupUnknownVersion,
    ),
    strings.backupExportTime(
      result.preview.exportedAt ?? strings.backupLocalCurrent,
    ),
    strings.backupExportTotal(strings.backupTotalRecords(result.preview.totalRows)),
    backupPreviewTableSummary(result.preview, strings),
  ].join('\n');
}

/// 中文：**增量记号**（`+N` / `N`）——迁移前数据层里那个 `_formatDelta` 的抄本，与语言无关。
/// English: **the delta notation** (`+N` / `N`) — a copy of the `_formatDelta` that used to sit in the
///          data layer; language-independent.
String _formatDelta(int value) {
  if (value > 0) return '+$value';
  return value.toString();
}