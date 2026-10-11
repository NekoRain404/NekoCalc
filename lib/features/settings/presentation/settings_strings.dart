import 'package:flutter/widgets.dart';

import '../../../application/app_settings.dart';
import '../../../core/platform/app_haptics.dart';
import '../../../l10n/app_language.dart';

/// 中文：设置页的界面文案表，**按功能切分**——一个功能一张表、表里并排放所有语言。
///       这是本项目对「手写分表」机制的具体落地，理由见 `.superpowers/backup/i18n-theme-report.md`：
///       ARB + `flutter gen-l10n` 在 Flutter 3.44 里只有一个 `arb-dir`（无法按功能切成多组），
///       且 `synthetic-package` 已废弃、生成物必须落在 `lib/` 下——本项目的 3825 条去重中文字面量
///       按 Flutter 自己那张生成表（13274 条消息 / 46986 行）的比例会生成约 1.3 万行，触到单文件
///       800 行的硬线。手写分表则天然按功能切，每张表自己一屏看得完。
///
///       **加一种语言要动几个文件**：这个文件（加一份 `SettingsStrings` 表 + `of` 里加一个分支），
///       加上 `AppLanguage` 里加一个枚举值。`of` 用的是对枚举的 switch 表达式——**穷尽性由分析器
///       检查**，所以加语言时编译器会点着名字让你改，而不是静默回落到中文。
///       表是 `static final` 而不是 `const`：带参数的文案存成闭包，而闭包不是常量表达式，
///       `const` 构造会直接编译不过。换成占位符模板可以换回 `const`，但那样就没有编译期的
///       参数个数与类型检查了，代价更大。
///
///       **本表只装"给人看的标签"。** 持久化令牌（`'跟随系统'`、`'浅色'`、`'4 位'`…）住在
///       `SettingsTokens` 里，`*Label` 方法负责令牌→标签的转换。中文下两者取值相同，那是巧合；
///       英文下必须不同，`settings_strings_test.dart` 两侧都钉住了。
/// English: The settings page's string table, **split by feature** — one table per feature, holding
///          every language side by side. This is how this project realises the hand-written-tables
///          mechanism; the reasoning is in `.superpowers/backup/i18n-theme-report.md`: in Flutter 3.44
///          ARB + `flutter gen-l10n` accepts a single `arb-dir` (so ARB files cannot be grouped per
///          feature), `synthetic-package` is deprecated and the generated code must land under `lib/`,
///          and this project's 3825 distinct Chinese literals would generate roughly 13k lines at the
///          ratio of Flutter's own generated table (13274 messages / 46986 lines) — past the hard
///          800-line-per-file limit. Hand-written tables split by construction, each one readable in a
///          single screen.
///
///          **Adding a language touches**: this file (one more `SettingsStrings` table plus one more
///          branch in `of`) and `AppLanguage` (one more enum value). `of` switches over the enum, and
///          the analyzer **checks that switch for exhaustiveness**, so adding a language makes the
///          compiler name the files to edit instead of silently falling back to Chinese.
///          The tables are `static final` rather than `const` because parameterised copy is held as
///          closures, and a closure is not a constant expression, so a `const` constructor simply does
///          not compile. Placeholder templates would allow `const`, at the cost of losing compile-time
///          arity and type checking on those arguments — a worse trade.
///
///          **This table holds human-facing labels only.** The persisted tokens (`'跟随系统'`,
///          `'浅色'`, `'4 位'`, …) live in `SettingsTokens`, and the `*Label` methods convert a token to
///          a label. That the two coincide in Chinese is a coincidence; in English they must differ,
///          and `settings_strings_test.dart` pins both sides.
@immutable
class SettingsStrings {
  const SettingsStrings({
    // —— 页面骨架 ——
    required this.backTooltip,
    required this.pageTitle,
    required this.sectionAppearance,
    required this.sectionExperience,
    required this.sectionData,
    required this.sectionAbout,
    // —— 外观设置 ——
    required this.themeModeTileTitle,
    required this.themeTileTitle,
    required this.languageTileTitle,
    required this.angleModeTileTitle,
    required this.numberFormatTileTitle,
    required this.decimalPlacesTileTitle,
    required this.expressionDisplayTileTitle,
    required this.percentageModeTileTitle,
    // —— 使用体验 ——
    required this.hapticsTileTitle,
    required this.hapticStrengthTileTitle,
    required this.restoreStateTileTitle,
    required this.autoSaveHistoryTileTitle,
    // —— 数据管理 ——
    required this.localDataTitle,
    required this.counting,
    required this.refreshDataStats,
    required this.exportBackupTitle,
    required this.importBackupTitle,
    required this.saveFile,
    required this.chooseFile,
    required this.processing,
    required this.details,
    required this.exportFailedTitle,
    required this.importFailedTitle,
    required this.importResultTitle,
    required this.cancel,
    required this.importMerge,
    required this.importReplace,
    required this.importWarning,
    required this.backupFileTitle,
    required this.localCurrentTitle,
    required this.backupWarningsTitle,
    required this.unknownValue,
    required this.importDone,
    required this.reportMode,
    required this.reportResult,
    required this.reportSource,
    required this.reportBefore,
    required this.reportAfter,
    required this.reportTableRow,
    required this.reportSkipped,
    required this.backupPreviewSummary,
    required this.backupPlanHeadline,
    required this.backupPlanRow,
    // —— 关于与其他 ——
    required this.aboutTileTitle,
    required this.checkUpdateTitle,
    required this.checking,
    required this.helpFeedbackTitle,
    required this.helpFeedbackValue,
    required this.privacyPolicyTitle,
    required this.privacyPolicyBody,
    required this.currentVersion,
    required this.remoteVersion,
    required this.viewRelease,
    required this.viewReleaseNotes,
    required this.openReleasesPage,
    required this.close,
    required this.done,
    required this.gotIt,
    required this.aboutTagline,
    required this.aboutChipScience,
    required this.aboutChipEngineering,
    required this.aboutChipGraph,
    required this.aboutChipSqlite,
    required this.aboutPrivacyNote,
    required this.openSourceTitle,
    required this.openSourceBody,
    required this.openSourceAction,
    required this.helpIntro,
    required this.diagnosticReportTitle,
    required this.copyReport,
    required this.submitIssue,
    required this.reportCopied,
    required this.diagnosticHeading,
    required this.diagnosticApp,
    required this.diagnosticVersion,
    required this.diagnosticChannel,
    required this.diagnosticPlatform,
    required this.diagnosticGeneratedAt,
    required this.diagnosticPrompt,
    required this.linkOpenFailed,
    required this.updateAvailable,
    required this.updateUpToDate,
    required this.updateVersionUnreadable,
    required this.updateHttpError,
    required this.updateNoReleasesFound,
    required this.updateNetworkUnreachable,
    // —— 令牌 → 标签（见类文档）——
    required this.themeModeSystemLabel,
    required this.themeModeLightLabel,
    required this.themeModeDarkLabel,
    required this.angleRadiansLabel,
    required this.angleDegreesLabel,
    required this.digits4Label,
    required this.digits6Label,
    required this.digits8Label,
    required this.expressionSymbolsLabel,
    required this.expressionMathLabel,
    required this.percentageDirectLabel,
    required this.percentageRelativeLabel,
    required this.hapticsOffLabel,
    required this.hapticLightLabel,
    required this.hapticStandardLabel,
    required this.hapticStrongLabel,
    required this.themeRoseCreamLabel,
    required this.themeLavenderMistLabel,
    required this.themePeachSugarLabel,
  });

  // —— 页面骨架 ——
  final String backTooltip;
  final String pageTitle;
  final String sectionAppearance;
  final String sectionExperience;
  final String sectionData;
  final String sectionAbout;

  // —— 外观设置 ——
  final String themeModeTileTitle;
  final String themeTileTitle;
  final String languageTileTitle;
  final String angleModeTileTitle;
  final String numberFormatTileTitle;
  final String decimalPlacesTileTitle;
  final String expressionDisplayTileTitle;
  final String percentageModeTileTitle;

  // —— 使用体验 ——
  final String hapticsTileTitle;
  final String hapticStrengthTileTitle;
  final String restoreStateTileTitle;
  final String autoSaveHistoryTileTitle;

  // —— 数据管理 ——
  final String localDataTitle;
  final String counting;
  final String refreshDataStats;
  final String exportBackupTitle;
  final String importBackupTitle;
  final String saveFile;
  final String chooseFile;
  final String processing;
  final String details;
  final String exportFailedTitle;
  final String importFailedTitle;
  final String importResultTitle;
  final String cancel;
  final String importMerge;
  final String importReplace;
  final String importWarning;
  final String backupFileTitle;
  final String localCurrentTitle;
  final String backupWarningsTitle;
  final String unknownValue;
  final String Function(String modeLabel, String resultLabel) importDone;
  final String Function(String modeLabel) reportMode;
  final String Function(String resultLabel) reportResult;
  final String Function(String totalLabel) reportSource;
  final String Function(String totalLabel) reportBefore;
  final String Function(String totalLabel) reportAfter;
  final String Function(String label, int source, int before, int after,
      String delta, String skippedTail) reportTableRow;
  final String Function(int skipped) reportSkipped;
  final String Function(
          String version, String exportedAt, String total, String summary)
      backupPreviewSummary;
  final String Function(String modeLabel, String totalLabel) backupPlanHeadline;
  final String Function(int before, int source, int expected) backupPlanRow;

  // 中文：备份警告与导入影响那一族（八条提示、三个年龄单位、十句话与连接符）**连同本轮新搬来的
  //       残留**都住在 `settings_backup_strings.dart` 的 `SettingsBackupStrings` 里——两张表同属
  //       设置页，分表是为了绕开本文件贴着的那条 800 行硬线，见那张表的文件头。
  // English: the backup-warnings and import-impacts family (eight notices, three age units, ten
  //          sentences and their separator), **together with this round's residuals**, live in
  //          `settings_backup_strings.dart`'s `SettingsBackupStrings` — both tables belong to the
  //          settings page, and the split is what clears this file's 800-line cap; see that table's
  //          file head.

  // —— 关于与其他 ——
  final String aboutTileTitle;
  final String checkUpdateTitle;
  final String checking;
  final String helpFeedbackTitle;
  final String helpFeedbackValue;
  final String privacyPolicyTitle;
  final String privacyPolicyBody;
  final String Function(String version) currentVersion;
  final String Function(String version) remoteVersion;
  final String viewRelease;
  final String viewReleaseNotes;
  final String openReleasesPage;
  final String close;
  final String done;
  final String gotIt;
  final String aboutTagline;
  final String aboutChipScience;
  final String aboutChipEngineering;
  final String aboutChipGraph;
  final String aboutChipSqlite;
  final String aboutPrivacyNote;
  final String openSourceTitle;
  final String openSourceBody;
  final String openSourceAction;
  final String helpIntro;
  final String diagnosticReportTitle;
  final String copyReport;
  final String submitIssue;
  final String reportCopied;
  final String diagnosticHeading;
  final String Function(String appName) diagnosticApp;
  final String Function(String version) diagnosticVersion;
  final String Function(String channel) diagnosticChannel;
  final String Function(String platform) diagnosticPlatform;
  final String Function(String timestamp) diagnosticGeneratedAt;
  final String diagnosticPrompt;
  final String linkOpenFailed;

  /// 中文：**检查更新的六句回执。** 原先由检查器的 `UpdateCheckResult.message` 当场拼出并直接上屏——
  ///       结果对象从检查器活到对话框，英文界面下印的仍是中文（§5i）；现在只留令牌 `UpdateCheckOutcome`
  ///       与载荷（发布版本、HTTP 状态码），字在这里，由 `update_check_message.dart` 在呈现边缘取——
  ///       对话框的按钮与图标仍按派生的 `UpdateCheckStatus` 选。**中文逐字节与从前相同**（对照表钉住）。
  /// English: **the six update-check receipts**, once composed by `UpdateCheckResult.message`; the result
  ///          travels from the checker to the dialog, so an English interface still printed Chinese
  ///          (§5i). The checker keeps only `UpdateCheckOutcome` + payloads, read at the edge by
  ///          `update_check_message.dart`; the button and icon still pick from the derived
  ///          `UpdateCheckStatus`. **The Chinese is byte-identical to what it was.**
  final String Function(String version) updateAvailable;
  final String updateUpToDate;
  final String updateVersionUnreadable;
  final String Function(int statusCode) updateHttpError;
  final String updateNoReleasesFound;
  final String updateNetworkUnreachable;
  // —— 令牌 → 标签 ——
  final String themeModeSystemLabel;
  final String themeModeLightLabel;
  final String themeModeDarkLabel;
  final String angleRadiansLabel;
  final String angleDegreesLabel;
  final String digits4Label;
  final String digits6Label;
  final String digits8Label;
  final String expressionSymbolsLabel;
  final String expressionMathLabel;
  final String percentageDirectLabel;
  final String percentageRelativeLabel;
  final String hapticsOffLabel;
  final String hapticLightLabel;
  final String hapticStandardLabel;
  final String hapticStrongLabel;
  final String themeRoseCreamLabel;
  final String themeLavenderMistLabel;
  final String themePeachSugarLabel;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过，
  ///       而不是静默回落到中文，这正是"加语言是机械的"所依赖的那条保证。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here rather than silently falling back to Chinese —
  ///          that guarantee is what makes adding one mechanical.
  static SettingsStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方（如 `_diagnosticReport` 里
  ///       拼字符串的工具函数）使用。两条路径共用这一个 switch，不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext` (string builders such as
  ///          `_diagnosticReport`). Both routes share this one switch, so they cannot drift apart.
  static SettingsStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => settingsZh,
      AppLanguage.en => settingsEn,
    };
  }

  static final SettingsStrings settingsZh = SettingsStrings(
    backTooltip: '返回',
    pageTitle: '设置',
    sectionAppearance: '外观设置',
    sectionExperience: '使用体验',
    sectionData: '数据管理',
    sectionAbout: '关于与其他',
    themeModeTileTitle: '主题模式',
    themeTileTitle: '主题配色',
    languageTileTitle: '语言',
    angleModeTileTitle: '角度模式',
    numberFormatTileTitle: '数字格式',
    decimalPlacesTileTitle: '小数位数',
    expressionDisplayTileTitle: '表达式显示',
    percentageModeTileTitle: '百分比计算',
    hapticsTileTitle: '触感反馈',
    hapticStrengthTileTitle: '触感强度',
    restoreStateTileTitle: '记住上次状态',
    autoSaveHistoryTileTitle: '自动保存计算历史',
    localDataTitle: '本机数据',
    counting: '统计中',
    refreshDataStats: '刷新数据统计',
    exportBackupTitle: '导出备份',
    importBackupTitle: '导入恢复',
    saveFile: '保存文件',
    chooseFile: '选择文件',
    processing: '处理中',
    details: '详情',
    exportFailedTitle: '导出失败',
    importFailedTitle: '导入失败',
    importResultTitle: '导入结果',
    cancel: '取消',
    importMerge: '合并导入',
    importReplace: '覆盖恢复',
    importWarning: '请确认文件来自可信备份。覆盖恢复会先清空本机数据；合并导入会保留本机数据，但设置和同一工具记录可能被备份内容更新。',
    backupFileTitle: '备份文件',
    localCurrentTitle: '本机当前',
    backupWarningsTitle: '备份提示',
    unknownValue: '未知',
    importDone: (modeLabel, resultLabel) => '$modeLabel完成：$resultLabel',
    reportMode: (modeLabel) => '模式：$modeLabel',
    reportResult: (resultLabel) => '结果：$resultLabel',
    reportSource: (totalLabel) => '导入文件：$totalLabel',
    reportBefore: (totalLabel) => '导入前：$totalLabel',
    reportAfter: (totalLabel) => '导入后：$totalLabel',
    reportTableRow: (label, source, before, after, delta, skippedTail) =>
        '$label：文件 $source，导入前 $before，导入后 $after，变化 $delta$skippedTail',
    reportSkipped: (skipped) => '，跳过/裁剪 $skipped',
    backupPreviewSummary: (version, exportedAt, total, summary) =>
        '版本：$version\n时间：$exportedAt\n总计：$total\n$summary',
    backupPlanHeadline: (modeLabel, totalLabel) => '$modeLabel后预计 $totalLabel',
    backupPlanRow: (before, source, expected) =>
        '本机 $before · 文件 $source · 导入后 $expected',
    aboutTileTitle: '关于 NekoCalc',
    checkUpdateTitle: '检查更新',
    checking: '正在检查',
    helpFeedbackTitle: '帮助与反馈',
    helpFeedbackValue: '诊断报告与 GitHub Issue',
    privacyPolicyTitle: '隐私政策',
    privacyPolicyBody: '所有计算历史、收藏工具、设置和笔记当前仅存储在本机 SQLite 数据库，不会上传到网络服务。',
    currentVersion: (version) => '当前版本：$version',
    remoteVersion: (version) => '线上版本：$version',
    viewRelease: '查看发布',
    viewReleaseNotes: '查看发布说明',
    openReleasesPage: '打开发布页',
    close: '关闭',
    done: '完成',
    gotIt: '知道了',
    aboutTagline: '个人全能计算工作台，覆盖科学计算、工程工具、单位换算、函数图形和计算笔记。',
    aboutChipScience: '科学计算',
    aboutChipEngineering: '工程工具',
    aboutChipGraph: '函数图形',
    aboutChipSqlite: 'SQLite 本地记录',
    aboutPrivacyNote: '数据当前仅保存在本机 SQLite，不上传网络服务。',
    openSourceTitle: '开源结构',
    openSourceBody:
        '项目采用 Feature-first + Clean Architecture 简化版：UI、Application、Domain、Data、Core 分层维护。',
    openSourceAction: '架构',
    helpIntro: '计算页用于快速表达式；工具页可按分类检索工程工具；图形页用于函数分析；笔记页可保存计算结果和工程记录。',
    diagnosticReportTitle: '诊断报告',
    copyReport: '复制报告',
    submitIssue: '提交 GitHub Issue',
    reportCopied: '诊断报告已复制',
    diagnosticHeading: 'NekoCalc 诊断报告',
    diagnosticApp: (appName) => '应用：$appName',
    diagnosticVersion: (version) => '版本：$version',
    diagnosticChannel: (channel) => '发布通道：$channel',
    diagnosticPlatform: (platform) => '平台：$platform',
    diagnosticGeneratedAt: (timestamp) => '生成时间：$timestamp',
    diagnosticPrompt: '请补充：问题发生步骤、预期结果、实际结果；不要粘贴个人敏感数据。',
    linkOpenFailed: '无法打开链接，请稍后重试',
    updateAvailable: (version) => '发现新版本 $version。',
    updateUpToDate: '当前已是最新版本。',
    updateVersionUnreadable: '当前版本号无法识别。',
    updateHttpError: (statusCode) => 'GitHub 返回了 HTTP $statusCode，请稍后再试。',
    updateNoReleasesFound: '未找到可用的公开发布版本。',
    updateNetworkUnreachable: '无法连接 GitHub，请检查网络后重试。',
    themeModeSystemLabel: '跟随系统',
    themeModeLightLabel: '浅色',
    themeModeDarkLabel: '深色',
    angleRadiansLabel: '弧度',
    angleDegreesLabel: '角度',
    digits4Label: '4 位',
    digits6Label: '6 位',
    digits8Label: '8 位',
    expressionSymbolsLabel: '数学符号',
    expressionMathLabel: '数学表达式',
    // 中文：两个变体的名字取自厂商手册那一节的标题词（Direct / Relative）。**令牌是 ASCII**
    //       （`'direct'` / `'relative'`），所以中文标签与它本来就不相等——与主题名同一类。
    // English: the two variant names come from the vendor manual's own section headings
    //          (Direct / Relative). The **tokens are ASCII** (`'direct'` / `'relative'`), so the
    //          Chinese labels never equalled them — the same kind of thing as theme names.
    percentageDirectLabel: '直接',
    percentageRelativeLabel: '相对',
    hapticsOffLabel: '关闭',
    hapticLightLabel: '轻',
    hapticStandardLabel: '标准',
    hapticStrongLabel: '强',
    themeRoseCreamLabel: '玫瑰奶霜',
    themeLavenderMistLabel: '薰衣草雾',
    themePeachSugarLabel: '蜜桃砂糖',
  );

  static final SettingsStrings settingsEn = SettingsStrings(
    backTooltip: 'Back',
    pageTitle: 'Settings',
    sectionAppearance: 'Appearance',
    sectionExperience: 'Interaction',
    sectionData: 'Data',
    sectionAbout: 'About',
    themeModeTileTitle: 'Theme mode',
    themeTileTitle: 'Colour theme',
    languageTileTitle: 'Language',
    angleModeTileTitle: 'Angle mode',
    numberFormatTileTitle: 'Number format',
    decimalPlacesTileTitle: 'Decimal places',
    expressionDisplayTileTitle: 'Expression display',
    percentageModeTileTitle: 'Percentage calculation',
    hapticsTileTitle: 'Haptics',
    hapticStrengthTileTitle: 'Haptic strength',
    restoreStateTileTitle: 'Restore last state',
    autoSaveHistoryTileTitle: 'Auto-save history',
    localDataTitle: 'On this device',
    counting: 'Counting',
    refreshDataStats: 'Refresh counts',
    exportBackupTitle: 'Export backup',
    importBackupTitle: 'Import backup',
    saveFile: 'Save file',
    chooseFile: 'Choose file',
    processing: 'Working',
    details: 'Details',
    exportFailedTitle: 'Export failed',
    importFailedTitle: 'Import failed',
    importResultTitle: 'Import result',
    cancel: 'Cancel',
    importMerge: 'Merge',
    importReplace: 'Replace',
    importWarning:
        'Make sure the file comes from a backup you trust. Replace wipes this device first; merge keeps '
        'local data, but settings and records for the same tool may be overwritten by the backup.',
    backupFileTitle: 'Backup file',
    localCurrentTitle: 'On this device',
    backupWarningsTitle: 'Backup warnings',
    unknownValue: 'Unknown',
    importDone: (modeLabel, resultLabel) => '$modeLabel finished: $resultLabel',
    reportMode: (modeLabel) => 'Mode: $modeLabel',
    reportResult: (resultLabel) => 'Result: $resultLabel',
    reportSource: (totalLabel) => 'Imported file: $totalLabel',
    reportBefore: (totalLabel) => 'Before: $totalLabel',
    reportAfter: (totalLabel) => 'After: $totalLabel',
    reportTableRow: (label, source, before, after, delta, skippedTail) =>
        '$label: file $source, before $before, after $after, change $delta$skippedTail',
    reportSkipped: (skipped) => ', skipped/trimmed $skipped',
    backupPreviewSummary: (version, exportedAt, total, summary) =>
        'Version: $version\nExported: $exportedAt\nTotal: $total\n$summary',
    backupPlanHeadline: (modeLabel, totalLabel) =>
        '$modeLabel would leave $totalLabel',
    backupPlanRow: (before, source, expected) =>
        'device $before · file $source · after $expected',
    aboutTileTitle: 'About NekoCalc',
    checkUpdateTitle: 'Check for updates',
    checking: 'Checking',
    helpFeedbackTitle: 'Help & feedback',
    helpFeedbackValue: 'Diagnostics and GitHub issues',
    privacyPolicyTitle: 'Privacy policy',
    privacyPolicyBody:
        'Calculation history, favourite tools, settings and notes are stored only in the local SQLite '
        'database on this device. Nothing is uploaded to a network service.',
    currentVersion: (version) => 'Current version: $version',
    remoteVersion: (version) => 'Latest version: $version',
    viewRelease: 'View release',
    viewReleaseNotes: 'View release notes',
    openReleasesPage: 'Open releases page',
    close: 'Close',
    done: 'Done',
    gotIt: 'Got it',
    aboutTagline:
        'An all-in-one calculation workbench: scientific calculation, engineering tools, unit '
        'conversion, function graphs and calculation notes.',
    aboutChipScience: 'Scientific',
    aboutChipEngineering: 'Engineering',
    aboutChipGraph: 'Graphs',
    aboutChipSqlite: 'Local SQLite',
    aboutPrivacyNote:
        'Data is stored only in the local SQLite database and is never uploaded.',
    openSourceTitle: 'Open source layout',
    openSourceBody:
        'Feature-first with a simplified Clean Architecture: UI, Application, Domain, Data and Core '
        'layers maintained separately.',
    openSourceAction: 'Architecture',
    helpIntro:
        'The calculator page is for quick expressions; the tools page browses engineering tools by '
        'category; the graph page analyses functions; the notes page keeps results and engineering '
        'records.',
    diagnosticReportTitle: 'Diagnostic report',
    copyReport: 'Copy report',
    submitIssue: 'File a GitHub issue',
    reportCopied: 'Diagnostic report copied',
    diagnosticHeading: 'NekoCalc diagnostic report',
    diagnosticApp: (appName) => 'App: $appName',
    diagnosticVersion: (version) => 'Version: $version',
    diagnosticChannel: (channel) => 'Release channel: $channel',
    diagnosticPlatform: (platform) => 'Platform: $platform',
    diagnosticGeneratedAt: (timestamp) => 'Generated at: $timestamp',
    diagnosticPrompt:
        'Please add: steps to reproduce, expected result, actual result. Do not paste personal data.',
    linkOpenFailed: 'Could not open the link. Please try again later.',
    updateAvailable: (version) => 'Version $version is available.',
    updateUpToDate: 'This is the newest version.',
    updateVersionUnreadable: 'The current version number is not recognised.',
    updateHttpError: (statusCode) => 'GitHub returned HTTP $statusCode; try again later.',
    updateNoReleasesFound: 'No public release was found.',
    updateNetworkUnreachable: 'Could not reach GitHub; check the network and try again.',
    themeModeSystemLabel: 'Follow system',
    themeModeLightLabel: 'Light',
    themeModeDarkLabel: 'Dark',
    angleRadiansLabel: 'Radians',
    angleDegreesLabel: 'Degrees',
    digits4Label: '4 digits',
    digits6Label: '6 digits',
    digits8Label: '8 digits',
    expressionSymbolsLabel: 'Symbols',
    expressionMathLabel: 'Math expression',
    percentageDirectLabel: 'Direct',
    percentageRelativeLabel: 'Relative',
    hapticsOffLabel: 'Off',
    hapticLightLabel: 'Light',
    hapticStandardLabel: 'Standard',
    hapticStrongLabel: 'Strong',
    themeRoseCreamLabel: 'Rose Cream',
    themeLavenderMistLabel: 'Lavender Mist',
    themePeachSugarLabel: 'Peach Sugar',
  );
}

/// 中文：**令牌 → 标签**的转换，全程只经 `SettingsTokens` 的常量与本表比对，不写新的字面量。
///       把这些方法挂成 `SettingsStrings` 的扩展而不是类的成员，是为了让"表"和"映射"在文件里
///       各占一段、互不穿插——表里任何一处改动都不该牵动映射。
/// English: **Token → label** conversion. Every comparison goes through a `SettingsTokens` constant;
///          no new literal is introduced here. They are an extension rather than members so the tables
///          and the mapping stay in two separate blocks — editing a table should never touch the map.
extension SettingsTokenLabels on SettingsStrings {
  /// 中文：主题模式。**入参是持久化的 `theme_mode` 值**，出参才是屏幕上那句话。
  /// English: Theme mode. **The argument is the stored `theme_mode` value**; only the result is
  ///          user-facing text.
  String themeModeLabel(String token) {
    return switch (token) {
      SettingsTokens.themeModeLight => themeModeLightLabel,
      SettingsTokens.themeModeDark => themeModeDarkLabel,
      _ => themeModeSystemLabel,
    };
  }

  /// 中文：角度模式。
  /// English: Angle mode.
  String angleModeLabel(String token) {
    return token == SettingsTokens.angleModeDegrees
        ? angleDegreesLabel
        : angleRadiansLabel;
  }

  /// 中文：小数位数。认不出的值原样返回——它本来就是个待迁移的令牌，不该被换成"6 位"。
  /// English: Decimal places. Unrecognised values pass through unchanged: the value is a pending
  ///          migration target, not something to be rewritten as "6 位".
  String digitsLabel(String token) {
    return switch (token) {
      SettingsTokens.digits4 => digits4Label,
      SettingsTokens.digits8 => digits8Label,
      SettingsTokens.digits6 => digits6Label,
      _ => token,
    };
  }

  /// 中文：表达式显示模式。历史值 `'函数表达式'` 在 `fromMap` 里已迁移成 `'数学表达式'`，
  ///       这里再挡一道，免得迁移前写下的值被显示成令牌本身。
  /// English: Expression display mode. The legacy `'函数表达式'` is already migrated to
  ///          `'数学表达式'` by `fromMap`; this guards again so a value written before that migration
  ///          never renders as its own token.
  String expressionDisplayLabel(String token) {
    return switch (token) {
      SettingsTokens.expressionDisplayMath => expressionMathLabel,
      SettingsTokens.expressionDisplayFunctionLegacy => expressionMathLabel,
      _ => expressionSymbolsLabel,
    };
  }

  /// 中文：`%` 的两种读法。认不出的值（手工改库、备份来自别处）显示成 **direct** 的标签——
  ///       与 `AppSettings.fromMap` 和设置页的读法一致：这一项只有两个变体，其余一律按默认读，
  ///       而不是把令牌本身印到屏幕上。
  /// English: the two readings of `%`. An unrecognised value (a hand-edited database, a backup from
  ///          elsewhere) renders as the **direct** label — matching `AppSettings.fromMap` and the
  ///          settings page's own read: this one has exactly two variants, everything else reads as
  ///          the default, rather than printing the token on screen.
  String percentageModeLabel(String token) {
    return token == SettingsTokens.percentageRelative
        ? percentageRelativeLabel
        : percentageDirectLabel;
  }

  /// 中文：触感强度。令牌就是 `AppHaptics` 上的三个常量，直接引用它们而不是重抄一遍字面量——
  ///       重抄的副本一旦和 `AppHaptics` 脱钩，设置页会把 `'标准'` 显示成默认值而毫无提示。
  /// English: Haptic strength. The tokens *are* the three constants on `AppHaptics`; they are
  ///          referenced rather than re-typed, because a re-typed copy that drifts from `AppHaptics`
  ///          would make the page render `'标准'` as the default with no signal at all.
  String hapticStrengthLabel(String token) {
    return switch (token) {
      AppHaptics.light => hapticLightLabel,
      AppHaptics.strong => hapticStrongLabel,
      _ => hapticStandardLabel,
    };
  }

  /// 中文：主题配色。**入参是持久化的 `theme_id`**（`roseCream` / `lavenderMist` / `peachSugar`），
  ///       出参才是屏幕上那三个名字；`id` 一个字节都不许翻译，它是存储格式。
  ///
  ///       三个 id 在这里是**字面量**，不是 `CalcTheme.lavenderMist.id`——`switch` 的分支要求常量
  ///       表达式，而属性访问不是（`const_eval_property_access`，实测）。抄一遍字面量的风险是
  ///       "某一格永远走不到、悄悄回落到玫瑰奶霜"，所以这条风险由测试承担：
  ///       `settings_strings_test.dart` 里那条 `for (final theme in CalcTheme.all)` 逐套主题断言
  ///       `themeLabel(theme.id) == theme.name`，**任何一套主题认不出来（或者 `CalcTheme` 里新增
  ///       了一套没在这里加名字）都会红**。这比引用常量更强：常量引用只挡拼写，挡不住漏一套。
  /// English: Colour theme. **The argument is the stored `theme_id`** (`roseCream` / `lavenderMist` /
  ///          `peachSugar`); only the result is user-facing, and the `id` must never be translated —
  ///          it is storage format.
  ///
  ///          The three ids are **literals** here rather than `CalcTheme.lavenderMist.id`, because a
  ///          `switch` case demands a constant expression and a property access is not one
  ///          (`const_eval_property_access`, measured). Re-typing a literal risks a case that can never
  ///          be reached quietly falling back to Rose Cream, so that risk is carried by a test: the
  ///          `for (final theme in CalcTheme.all)` loop in `settings_strings_test.dart` asserts
  ///          `themeLabel(theme.id) == theme.name` for every theme, so **any unrecognised theme — or a
  ///          newly added `CalcTheme` with no name here — goes red**. That is stronger than referencing
  ///          the constants: a reference guards spelling, not a missing theme.
  String themeLabel(String themeId) {
    return switch (themeId) {
      'lavenderMist' => themeLavenderMistLabel,
      'peachSugar' => themePeachSugarLabel,
      _ => themeRoseCreamLabel,
    };
  }
}
