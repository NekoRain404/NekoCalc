import '../../../core/utils/backup_snapshot_validator.dart';
import '../../../data/repositories/data_backup_repository.dart';
import 'settings_backup_strings.dart';

/// 中文：**备份提示与导入影响的翻译处——领域 / 数据层给令牌，这里给字。**
///
///       `BackupPreviewWarning.message`（校验器）与 `BackupImportImpact.message`（数据层）从前自己拼
///       那些中文并直接上屏：设置页的「备份提示」块印 `warning.message`，导入对话框的清单印
///       `impact.message`（`settings_backup_widgets.dart`）。于是英文界面下印的仍是中文：
///       **领域对象活得比界面长**，界面那张按语言切的表够不着它（`docs/verification.md` §5i）。
///       现在那些句子住在 [SettingsBackupStrings] 里，由这两个函数在**呈现边缘**按令牌取——取表的语言
///       就是屏幕的语言。
///
///       **形状照的是已经转过的五条路径**：`calculatorSubmitMessage`、`calculatorSaveNoteMessage`、
///       `toolSaveMessage`、`notesImportMessage` 与 `recentToolActionMessage`（令牌在产出层，字在
///       呈现层的表里）。
///
///       **句子怎么拼是这里的事，词是表的事**：令牌只回答「这是哪件事」，年龄（「距今约 1 年」）
///       与多张表的连接符（「、」对 `, `）都按语言在这里拼上去，所以这个文件里**一个中文字面量都没有**
///       ——它因此落在 `settings_strings_test.dart` 那条"设置页源码里除了文案表再没有中文字符串
///       字面量"的扫描范围里，而不是像那张表那样被跳过。
///
///       **加一种结局时这里编译不过**：两个 `switch` 穷尽两个令牌枚举。
/// English: **where a backup notice and an import impact are translated — the domain / data layer hands
///          over the token, this hands over the words.**
///
///          `BackupPreviewWarning.message` (the validator) and `BackupImportImpact.message` (the data
///          layer) used to compose those Chinese sentences themselves and print them straight: the
///          settings page's "Backup warnings" block printed `warning.message` and the import dialog's
///          list printed `impact.message` (`settings_backup_widgets.dart`). An English interface still
///          printed Chinese: **a domain object outlives the UI** and a language-keyed interface table
///          cannot reach it (`docs/verification.md` §5i). Those sentences now live in
///          [SettingsBackupStrings], fetched **at the presentation edge** by these two functions, keyed by
///          the token — the language of the table is the language on screen.
///
///          **The shape is copied from the five converted paths**: `calculatorSubmitMessage`,
///          `calculatorSaveNoteMessage`, `toolSaveMessage`, `notesImportMessage` and
///          `recentToolActionMessage` (token in the producing layer, words in the presentation layer's
///          table).
///
///          **How a sentence is put together is this file's business, the words are the table's**: the
///          token answers only "which thing is this"; the age ("about 1 years old") and the separator
///          between several table names ("、" against ", ") are put together here, per language, so this
///          file holds **not one Chinese literal** — which puts it inside clause 3 of
///          `settings_strings_test.dart` ("no Chinese string literal in the settings page's sources
///          other than the copy table") rather than on the skip list the table itself sits on.
///
///          **Adding an outcome breaks this at compile time**: the two `switch`es exhaust the two token
///          enums.
String backupPreviewWarningMessage(
  BackupPreviewWarning warning,
  SettingsBackupStrings strings,
) {
  return switch (warning.kind) {
    BackupPreviewWarningKind.noRecoverableRecords =>
      strings.backupWarningNoRecoverableRecords,
    BackupPreviewWarningKind.missingExportedAt =>
      strings.backupWarningMissingExportedAt,
    BackupPreviewWarningKind.unrecognisedExportedAt =>
      strings.backupWarningUnrecognisedExportedAt(warning.exportedAt!),
    BackupPreviewWarningKind.exportedAtInFuture =>
      strings.backupWarningExportedAtInFuture,
    BackupPreviewWarningKind.olderThanYear => strings.backupWarningOlderThanYear(
      _backupAgeLabel(warning.age!, strings),
    ),
    BackupPreviewWarningKind.olderThanNinetyDays =>
      strings.backupWarningOlder(_backupAgeLabel(warning.age!, strings)),
    BackupPreviewWarningKind.missingAppVersion =>
      strings.backupWarningMissingAppVersion,
    BackupPreviewWarningKind.appVersionMismatch =>
      strings.backupWarningAppVersionMismatch(
        warning.version!,
        warning.currentVersion!,
      ),
  };
}

/// 中文：**导入影响清单那一句**。多张表那两格拿到的是备好的项（覆盖恢复的表名、合并时
///       「历史 +3」那样的备料项），由这里按 [SettingsBackupStrings.backupTableListSeparator] 连接——
///       连接符跟着语言走，表名本身是内容（今天仍是中文，见 §5i）。
/// English: **one line of the import impact list.** The two multi-table cells receive ready-made items
///          (the table names a replace would overwrite, or merge ingredients such as "历史 +3") and
///          this joins them with [SettingsBackupStrings.backupTableListSeparator] — the separator follows the
///          language while the table names themselves are content (Chinese today, see §5i).
String backupImportImpactMessage(
  BackupImportImpact impact,
  SettingsBackupStrings strings,
) {
  return switch (impact.kind) {
    BackupImportImpactKind.deleteTable =>
      strings.backupImpactDeleteTable(impact.label!, impact.count!),
    BackupImportImpactKind.reduceTable =>
      strings.backupImpactReduceTable(impact.label!, impact.count!),
    BackupImportImpactKind.emptySource => strings.backupImpactEmptySource,
    BackupImportImpactKind.overwriteTables => strings.backupImpactOverwriteTables(
      impact.labels.join(strings.backupTableListSeparator),
    ),
    BackupImportImpactKind.replaceKeepsIdentical =>
      strings.backupImpactReplaceKeepsIdentical,
    BackupImportImpactKind.mergeEmptySource =>
      strings.backupImpactMergeEmptySource,
    BackupImportImpactKind.mergeAddsTables =>
      strings.backupImpactMergeAddsTables(
        impact.labels.join(strings.backupTableListSeparator),
      ),
    BackupImportImpactKind.mergeUpdatesSettings =>
      strings.backupImpactMergeUpdatesSettings,
    BackupImportImpactKind.mergeKeepsRecentLimit =>
      strings.backupImpactMergeKeepsRecentLimit(impact.limit!),
    BackupImportImpactKind.mergeKeepsHistoryLimit =>
      strings.backupImpactMergeKeepsHistoryLimit(impact.limit!),
  };
}

/// 中文：**年龄那一小句怎么切**——`≥365 天` 取年、`≥30 天` 取月、其余取天，与迁移前校验器里那个
///       `_formatAge` 逐字相同。它住在呈现层而不是校验器里：切出来的「1 年」是要给用户看的字，
///       领域层只负责递一个 `Duration`。
/// English: **how the little age phrase splits** — 365 days or more gives years, 30 or more gives
///          months, the rest days, character for character the `_formatAge` that used to sit in the
///          validator. It lives at the presentation edge rather than in the validator: the "1 years"
///          that comes out is copy for a user, and the domain layer only hands over a `Duration`.
String _backupAgeLabel(Duration age, SettingsBackupStrings strings) {
  final days = age.inDays;
  if (days >= 365) return strings.backupAgeYears(days ~/ 365);
  if (days >= 30) return strings.backupAgeMonths(days ~/ 30);
  return strings.backupAgeDays(days);
}
