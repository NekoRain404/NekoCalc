import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：**备份这一族的界面文案表**——设置页「数据管理」那一块与它弹出来的导入 / 导出 / 报告
///       对话框要的每一句话。机制本身（为什么手写分表、为什么 `static final`）与设置页那张表共用
///       一套理由，写在 `settings_strings.dart` 的文件头上，这里不重抄。
///
///       **为什么另一张表而不是塞进 `SettingsStrings`**：那张表本轮已经 799 行，贴着仓库的单文件
///       800 行硬线；把这一族在这里落位，是为了让每一次迁移都还能在限额内完成，而不是把限额顶穿。
///       两张表同属设置页（`settings_page.dart` 与它的 part `settings_backup_widgets.dart` 各取所
///       需），取表的语言都是屏幕的语言。
///
///       **本表装三批东西，来历不同**：
///       1. **警告与影响那一族**（`backupWarning*` / `backupAge*` / `backupImpact*` /
///          `backupTableListSeparator`）——第三、四刀从 `BackupPreviewWarning.message` 与
///          `BackupImportImpact.message` 搬来，由 `settings_backup_messages.dart` 按令牌取。
///       2. **第四刀这一批残余**——`BackupPreview.summary` / `totalLabel`、`BackupImportPlan` 与
///          `BackupImportReport` 的模式 / 总数 / 摘要、`BackupExportResult.successMessage` / `detail`。
///          句子怎么拼（连接符、括号、尾巴）由呈现边缘做，词在这里。
///       3. **第六刀这一批**：`backupTableLabels`（表名 → 标签）从校验器那张同名表搬来——键是
///          `backupTableNames` 那一批、是数据，仍留在校验器里；标签是给人看的词，住在这里，由
///          `settings_backup_text.dart` 的 `backupTableLabel(name, strings)` 在呈现边缘查。校验器里
///          那个 `emptyBackupReplaceErrorMessage` 常量（「空备份不能用于覆盖恢复…」）本轮取消，
///          只留一枚令牌 `emptyBackupReplaceErrorToken`：那句话本来就只有这里这一格（
///          `backupImpactEmptySource`），被拒导入的失败详情由 `settings_backup_messages.dart` 的
///          `backupImportFailureMessage(error, strings)` 按令牌取同一格。
///
///       **没进来的一样**（有意留下，见 `docs/verification.md` §5i）：校验器里那批 `FormatException`
///       的正文是**异常的技术串**（与 `NotesController.error` 同一类，只在导入失败的诊断详情里
///       `error.toString()` 露一次面），要逐条翻得先给它们一套异常分类，那是另一件事。
/// English: **the copy table for the backup family** — every sentence the settings page's
///          "Data" section and the import / export / report dialogs it opens need. The mechanism
///          itself (why hand-written tables, why `static final`) shares one set of reasons with the
///          settings table and is written on `settings_strings.dart`'s file head; it is not copied
///          again here.
///
///          **Why a second table rather than folding into `SettingsStrings`**: that table sits at 799
///          lines this round, against the repository's hard 800-line-per-file cap; landing this family
///          here is what lets the migration still finish under the limit instead of pushing through it.
///          Both tables belong to the settings page (`settings_page.dart` and its part
///          `settings_backup_widgets.dart` each take what they need), and both take their language from
///          the screen.
///
///          **This table holds three batches of different origin**:
///          1. **The warnings and impacts family** (`backupWarning*` / `backupAge*` / `backupImpact*` /
///             `backupTableListSeparator`) — moved by the third and fourth slices out of
///             `BackupPreviewWarning.message` and `BackupImportImpact.message`, read by token in
///             `settings_backup_messages.dart`.
///          2. **The fourth slice's residuals** — `BackupPreview.summary` / `totalLabel`, the mode /
///             total / summary of `BackupImportPlan` and `BackupImportReport`, `BackupExportResult.successMessage`
///             / `detail`. How a sentence is put together (separators, brackets, tails) is the
///             presentation edge's business; the words are here.
///          3. **The sixth slice's batch**: `backupTableLabels` (table name → label) moved here from the
///             validator's map of the same name — the keys are the `backupTableNames` batch, which is
///             data and stays in the validator; the labels are copy and live here, looked up at the
///             presentation edge by `backupTableLabel(name, strings)` in `settings_backup_text.dart`.
///             The validator's `emptyBackupReplaceErrorMessage` constant ("an empty backup cannot be
///             used for replace…") is gone this round, leaving a token
///             `emptyBackupReplaceErrorToken`: that sentence only ever had one home here
///             (`backupImpactEmptySource`), and the failure detail of a rejected import fetches the
///             same cell by token through `backupImportFailureMessage(error, strings)` in
///             `settings_backup_messages.dart`.
///
///          **One thing deliberately absent** (see `docs/verification.md` §5i): the validator's
///          `FormatException` bodies are **an exception's technical string** (the same category as
///          `NotesController.error`, surfacing only once as `error.toString()` in the import failure's
///          diagnostic detail), and translating them one by one would first need a taxonomy of
///          exceptions — a different job.
@immutable
class SettingsBackupStrings {
  const SettingsBackupStrings({
    // —— 预览 / 计划 / 报告 / 导出：本轮的残余（句子由呈现边缘拼）——
    required this.backupUnknownVersion,
    required this.backupLocalCurrent,
    required this.backupTotalRecords,
    required this.backupTotalUpTo,
    required this.backupModeLabel,
    required this.backupSummaryItem,
    required this.backupSummarySeparator,
    required this.backupPlanSummaryItem,
    required this.backupReportSummaryItem,
    required this.backupReportSkippedTail,
    required this.backupReportRestored,
    required this.backupReportRestoredSkipped,
    required this.backupReportMerged,
    required this.backupReportMergedSkipped,
    required this.backupExportSaved,
    required this.backupExportVersion,
    required this.backupExportTime,
    required this.backupExportTotal,
    // —— 警告与影响：前三刀搬来的令牌落点 ——
    required this.backupWarningNoRecoverableRecords,
    required this.backupWarningMissingExportedAt,
    required this.backupWarningUnrecognisedExportedAt,
    required this.backupWarningExportedAtInFuture,
    required this.backupWarningOlderThanYear,
    required this.backupWarningOlder,
    required this.backupWarningMissingAppVersion,
    required this.backupWarningAppVersionMismatch,
    required this.backupAgeYears,
    required this.backupAgeMonths,
    required this.backupAgeDays,
    required this.backupImpactDeleteTable,
    required this.backupImpactReduceTable,
    required this.backupImpactEmptySource,
    required this.backupImpactOverwriteTables,
    required this.backupImpactReplaceKeepsIdentical,
    required this.backupImpactMergeEmptySource,
    required this.backupImpactMergeAddsTables,
    required this.backupImpactMergeUpdatesSettings,
    required this.backupImpactMergeKeepsRecentLimit,
    required this.backupImpactMergeKeepsHistoryLimit,
    required this.backupTableListSeparator,
    // —— 表名标签：键（数据）在校验器里，词在这里 ——
    required this.backupTableLabels,
  });

  // —— 预览 / 计划 / 报告 / 导出 ——
  /// 中文：导出版本缺失时的兜底（与设置页 `localCurrentTitle` / `unknownValue` 同一批词，本轮随
  ///       这一族移到这里，因为只有备份屏用它们）。
  /// English: the fallback when the export's version is missing (the same words as the settings page's
  ///          `localCurrentTitle` / `unknownValue`; they moved here with this family because only the
  ///          backup screens use them).
  final String backupUnknownVersion;
  final String backupLocalCurrent;

  /// 中文：`'$n 条记录'`——`BackupPreview.totalLabel` 与 `BackupImportPlan.expectedTotalLabel` 从前
  ///       各自拼的那半句。
  /// English: `'$n 条记录'` — the half-sentence `BackupPreview.totalLabel` and
  ///          `BackupImportPlan.expectedTotalLabel` each used to build.
  final String Function(int total) backupTotalRecords;

  /// 中文：`'最多 $total'`——`BackupImportPlan.totalLabel` 合并导入那一支的前缀。
  /// English: `'最多 $total'` — the prefix of `BackupImportPlan.totalLabel`'s merge branch.
  final String Function(String total) backupTotalUpTo;

  /// 中文：覆盖恢复 / 合并导入，两格由 `bool replaceExisting` 选。
  /// English: replace / merge, chosen by `bool replaceExisting`.
  final String Function(bool replaceExisting) backupModeLabel;

  /// 中文：预览摘要里的一项 `'$label $count'`；计划与报告各自多一段括号，见下两格。
  /// English: one item of the preview summary, `'$label $count'`; the plan and the report add a
  ///          bracketed stretch each, see the next two cells.
  final String Function(String label, int count) backupSummaryItem;
  final String backupSummarySeparator;
  final String Function(String label, int count, String delta)
      backupPlanSummaryItem;
  final String Function(String label, int after, String delta, String skippedTail)
      backupReportSummaryItem;

  /// 中文：报告每行括号里的跳过尾巴 `', 跳过 $n'`（ASCII 逗号，与迁移前逐字节相同）。
  /// English: the skipped tail inside each report row's bracket, `', 跳过 $n'` (ASCII comma, byte-for-
  ///          byte as before the move).
  final String Function(int skipped) backupReportSkippedTail;

  final String Function(int rows) backupReportRestored;
  final String Function(int rows, int skipped) backupReportRestoredSkipped;
  final String Function(int rows) backupReportMerged;
  final String Function(int rows, int skipped) backupReportMergedSkipped;

  final String Function(String total) backupExportSaved;
  final String Function(String version) backupExportVersion;
  final String Function(String exportedAt) backupExportTime;
  final String Function(String total) backupExportTotal;

  // —— 警告与影响（前三刀的令牌落点，见 `settings_backup_messages.dart`）——
  final String backupWarningNoRecoverableRecords;
  final String backupWarningMissingExportedAt;
  final String Function(String exportedAt) backupWarningUnrecognisedExportedAt;
  final String backupWarningExportedAtInFuture;
  final String Function(String ageLabel) backupWarningOlderThanYear;
  final String Function(String ageLabel) backupWarningOlder;
  final String backupWarningMissingAppVersion;
  final String Function(String version, String currentVersion)
      backupWarningAppVersionMismatch;
  final String Function(int years) backupAgeYears;
  final String Function(int months) backupAgeMonths;
  final String Function(int days) backupAgeDays;
  final String Function(String label, int count) backupImpactDeleteTable;
  final String Function(String label, int count) backupImpactReduceTable;
  final String backupImpactEmptySource;
  final String Function(String tables) backupImpactOverwriteTables;
  final String backupImpactReplaceKeepsIdentical;
  final String backupImpactMergeEmptySource;
  final String Function(String tables) backupImpactMergeAddsTables;
  final String backupImpactMergeUpdatesSettings;
  final String Function(int count) backupImpactMergeKeepsRecentLimit;
  final String Function(int count) backupImpactMergeKeepsHistoryLimit;
  final String backupTableListSeparator;

  /// 中文：**表名（键）→ 给人看的标签**——键是 `backupTableNames` 那一批（数据，留在校验器里），
  ///       标签是词，住在这里；由 `settings_backup_text.dart` 的 `backupTableLabel(tableName, strings)`
  ///       在呈现边缘查，认不出回落到表名本身（与迁移前 `backupTableLabels[tableName] ?? tableName`
  ///       同一次查表）。
  /// English: **table name (the key) → the human-facing label** — the keys are the `backupTableNames`
  ///          batch (data, kept in the validator), the labels are words and live here; looked up at the
  ///          presentation edge by `backupTableLabel(tableName, strings)` in
  ///          `settings_backup_text.dart`, falling back to the name itself (the same
  ///          `backupTableLabels[tableName] ?? tableName` lookup as before the move).
  final Map<String, String> backupTableLabels;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过，
  ///       而不是静默回落到中文。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here rather than silently falling back to Chinese.
  static SettingsBackupStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。
  /// English: The same dispatch as [of], for callers without a `BuildContext`.
  static SettingsBackupStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => backupZh,
      AppLanguage.en => backupEn,
    };
  }

  static final SettingsBackupStrings backupZh = SettingsBackupStrings(
    backupUnknownVersion: '未知',
    backupLocalCurrent: '本机当前',
    backupTotalRecords: (total) => '$total 条记录',
    backupTotalUpTo: (total) => '最多 $total',
    backupModeLabel: (replaceExisting) => replaceExisting ? '覆盖恢复' : '合并导入',
    backupSummaryItem: (label, count) => '$label $count',
    backupSummarySeparator: ' · ',
    backupPlanSummaryItem: (label, count, delta) => '$label $count ($delta)',
    backupReportSummaryItem: (label, after, delta, skippedTail) =>
        '$label $after ($delta$skippedTail)',
    backupReportSkippedTail: (skipped) => ', 跳过 $skipped',
    backupReportRestored: (rows) => '已恢复 $rows 条记录',
    backupReportRestoredSkipped: (rows, skipped) =>
        '已恢复 $rows 条记录，跳过 $skipped 条',
    backupReportMerged: (rows) => '已合并 $rows 条记录',
    backupReportMergedSkipped: (rows, skipped) =>
        '已合并 $rows 条记录，跳过或裁剪 $skipped 条',
    backupExportSaved: (total) => '备份已保存：$total',
    backupExportVersion: (version) => '版本：$version',
    backupExportTime: (exportedAt) => '导出时间：$exportedAt',
    backupExportTotal: (total) => '总计：$total',
    backupWarningNoRecoverableRecords: '备份文件没有可恢复记录，覆盖恢复会清空本机数据。',
    backupWarningMissingExportedAt: '备份缺少导出时间，无法判断文件新旧。',
    backupWarningUnrecognisedExportedAt: (exportedAt) => '备份导出时间无法识别：$exportedAt。',
    backupWarningExportedAtInFuture: '备份导出时间晚于本机时间，请确认设备时间是否正确。',
    backupWarningOlderThanYear: (ageLabel) => '备份距今约 $ageLabel，恢复前建议确认内容是否仍然需要。',
    backupWarningOlder: (ageLabel) => '备份距今约 $ageLabel。',
    backupWarningMissingAppVersion: '备份缺少应用版本信息。',
    backupWarningAppVersionMismatch: (version, currentVersion) =>
        '备份来自 $version，当前应用为 $currentVersion。',
    backupAgeYears: (years) => '$years 年',
    backupAgeMonths: (months) => '$months 个月',
    backupAgeDays: (days) => '$days 天',
    backupImpactDeleteTable: (label, count) => '$label 将删除本机 $count 条',
    backupImpactReduceTable: (label, count) => '$label 将减少 $count 条',
    backupImpactEmptySource: '空备份不能用于覆盖恢复，请改用合并导入或选择包含记录的备份。',
    backupImpactOverwriteTables: (tables) => '会覆盖本机$tables数据',
    backupImpactReplaceKeepsIdentical: '覆盖后本机数据将与备份文件一致',
    backupImpactMergeEmptySource: '备份为空，合并导入不会改变本机数据',
    backupImpactMergeAddsTables: (tables) => '会保留本机数据，并尝试加入 $tables',
    backupImpactMergeUpdatesSettings: '设置项可能按备份内容更新',
    backupImpactMergeKeepsRecentLimit: (count) => '最近工具只保留最新 $count 条',
    backupImpactMergeKeepsHistoryLimit: (count) => '历史记录合并后仍会保留最近 $count 条',
    backupTableListSeparator: '、',
    backupTableLabels: const {
      'calculation_history': '历史',
      'notes': '笔记',
      'favorite_tools': '收藏',
      'recent_tools': '最近工具',
      'app_settings': '设置',
    },
  );

  static final SettingsBackupStrings backupEn = SettingsBackupStrings(
    backupUnknownVersion: 'Unknown',
    backupLocalCurrent: 'On this device',
    backupTotalRecords: (total) => total == 1 ? '1 record' : '$total records',
    backupTotalUpTo: (total) => 'at most $total',
    backupModeLabel: (replaceExisting) => replaceExisting ? 'Replace' : 'Merge',
    backupSummaryItem: (label, count) => '$label $count',
    backupSummarySeparator: ' · ',
    backupPlanSummaryItem: (label, count, delta) => '$label $count ($delta)',
    backupReportSummaryItem: (label, after, delta, skippedTail) =>
        '$label $after ($delta$skippedTail)',
    backupReportSkippedTail: (skipped) => ', skipped $skipped',
    backupReportRestored: (rows) =>
        rows == 1 ? 'Restored 1 record' : 'Restored $rows records',
    backupReportRestoredSkipped: (rows, skipped) =>
        'Restored $rows records, skipped $skipped',
    backupReportMerged: (rows) =>
        rows == 1 ? 'Merged 1 record' : 'Merged $rows records',
    backupReportMergedSkipped: (rows, skipped) =>
        'Merged $rows records, skipped or trimmed $skipped',
    backupExportSaved: (total) => 'Backup saved: $total',
    backupExportVersion: (version) => 'Version: $version',
    backupExportTime: (exportedAt) => 'Exported: $exportedAt',
    backupExportTotal: (total) => 'Total: $total',
    backupWarningNoRecoverableRecords:
        'This backup holds no records to restore; a replace import would wipe this device.',
    backupWarningMissingExportedAt: 'The backup has no export time, so its age cannot be judged.',
    backupWarningUnrecognisedExportedAt: (exportedAt) =>
        'The backup export time is not recognised: $exportedAt.',
    backupWarningExportedAtInFuture:
        'The backup was exported after this device clock; check that the device time is right.',
    backupWarningOlderThanYear: (ageLabel) =>
        'The backup is about $ageLabel old; check that its contents are still wanted before restoring.',
    backupWarningOlder: (ageLabel) => 'The backup is about $ageLabel old.',
    backupWarningMissingAppVersion: 'The backup carries no app version.',
    backupWarningAppVersionMismatch: (version, currentVersion) =>
        'The backup came from $version; this app is $currentVersion.',
    backupAgeYears: (years) => years == 1 ? '1 year' : '$years years',
    backupAgeMonths: (months) => months == 1 ? '1 month' : '$months months',
    backupAgeDays: (days) => days == 1 ? '1 day' : '$days days',
    backupImpactDeleteTable: (label, count) =>
        '$label: $count records will be deleted here',
    backupImpactReduceTable: (label, count) => '$label: $count records fewer',
    backupImpactEmptySource:
        'An empty backup cannot be used for replace; merge it or pick a backup with records.',
    backupImpactOverwriteTables: (tables) => 'Overwrites the local $tables data',
    backupImpactReplaceKeepsIdentical:
        'After replacing, this device will match the backup file',
    backupImpactMergeEmptySource:
        'The backup is empty; merging changes nothing on this device',
    backupImpactMergeAddsTables: (tables) =>
        'Keeps local data and tries to add $tables',
    backupImpactMergeUpdatesSettings: 'Settings may be updated from the backup',
    backupImpactMergeKeepsRecentLimit: (count) =>
        'Recently used keeps only the newest $count',
    backupImpactMergeKeepsHistoryLimit: (count) =>
        'History keeps only the newest $count after merging',
    backupTableListSeparator: ', ',
    backupTableLabels: const {
      'calculation_history': 'History',
      'notes': 'Notes',
      'favorite_tools': 'Favorites',
      'recent_tools': 'Recently used',
      'app_settings': 'Settings',
    },
  );
}