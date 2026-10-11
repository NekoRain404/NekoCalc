import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/app_settings.dart';
import '../../../application/update/github_release_checker.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/platform/app_link_channel.dart';
import '../../../core/platform/app_haptics.dart';
import '../../../core/platform/backup_file_channel.dart';
import '../../../core/utils/backup_snapshot_validator.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/data_backup_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/app_language.dart';
import '../../../shared/presentation/app_chrome.dart';
import '../../../shared/presentation/calc_theme.dart';

// 中文：文案表刻意**不是** `part`：它是独立库，测试可以直接 import 它，不必把整棵设置页控件树
//       拖进来；它也因此可以有自己的 import。（Dart 要求 import 全部排在 part 之前。）
// English: The string table is deliberately **not** a `part`: as a standalone library the tests can
//          import it directly without dragging in the whole settings widget tree, and it can carry
//          imports of its own. (Dart requires every import to precede the part directives.)
import 'settings_backup_messages.dart';
import 'settings_backup_strings.dart';
import 'settings_backup_text.dart';
import 'settings_strings.dart';
import 'update_check_message.dart';

part 'settings_dialogs.dart';
part 'settings_backup_widgets.dart';
part 'settings_tiles.dart';

/// 中文：设置页负责展示偏好项、持久化设置，以及备份导入导出入口。
/// English: Settings screen for preferences, persistence, and backup import/export entry points.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.db,
    this.onThemeModeChanged,
    this.onThemeChanged,
    this.onLanguageChanged,
    this.onDataImported,
    this.updateChecker,
    this.appLinkOpener,
    super.key,
  });

  final AppDatabase db;
  final ValueChanged<String>? onThemeModeChanged;

  /// 中文：配色与语言的实时回调，收到的是**持久化令牌**（`CalcTheme.id` / `AppLanguage.code`），
  ///       不是屏幕上的标签。设置页自己已经落库，这里只是让外壳立刻跟着换。
  /// English: Live callbacks for the palette and the language. Each receives a **persisted token**
  ///          (`CalcTheme.id` / `AppLanguage.code`), never an on-screen label; the page has already
  ///          saved it, this only makes the shell follow immediately.
  final ValueChanged<String>? onThemeChanged;
  final ValueChanged<String>? onLanguageChanged;

  final Future<void> Function()? onDataImported;
  final GithubReleaseChecker? updateChecker;
  final AppLinkOpener? appLinkOpener;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _haptics = true;
  String _hapticStrength = AppHaptics.medium;
  bool _restoreState = true;
  bool _autoSave = true;

  // 中文：下面六个字段全部是**持久化令牌**（`SettingsTokens` / `CalcTheme.id` / `AppLanguage.code`），
  //       不是屏幕上显示的那句话。显示走 `SettingsStrings` 的 `*Label` 方法，两者绝不合并：
  //       令牌一被翻译，用户库里已经存好的值立刻对不上，而 `fromMap` 的 `??` 回退只会静默变成
  //       默认值，不会有任何报错。
  // English: All six fields below hold **persisted tokens** (`SettingsTokens` / `CalcTheme.id` /
  //          `AppLanguage.code`), never the text on screen. Rendering goes through `SettingsStrings`'
  //          `*Label` methods and the two are never merged: translate a token and the value already in
  //          the user's database stops matching, where `fromMap`'s `??` fallbacks turn it into the
  //          default silently, with no error anywhere.
  String _themeMode = SettingsTokens.themeModeSystem;
  String _themeId = SettingsTokens.defaultThemeId;
  String _languageCode = SettingsTokens.defaultLanguageCode;
  String _angleMode = SettingsTokens.angleModeRadians;
  String _digits = SettingsTokens.digits6;
  bool _groupThousands = false;
  // 中文：`_percentageMode` 与上面六个一样是**持久化令牌**（`'direct'` / `'relative'`，ASCII），
  //       屏幕上的那句「直接」/「相对」由 `SettingsStrings.percentageModeLabel` 换出来。
  // English: `_percentageMode`, like the six above, holds a **persisted token** (`'direct'` /
  //          `'relative'`, ASCII); the words "直接"/"相对" on screen come from
  //          `SettingsStrings.percentageModeLabel`.
  String _expressionDisplay = SettingsTokens.expressionDisplaySymbols;
  String _percentageMode = SettingsTokens.defaultPercentageMode;
  bool _backupBusy = false;
  bool _updateBusy = false;
  BackupPreview? _localBackupPreview;
  late final DataBackupRepository _backupRepository =
      DataBackupRepository(widget.db);
  late final SettingsRepository _settingsRepository =
      SettingsRepository(widget.db);
  late final GithubReleaseChecker _updateChecker =
      widget.updateChecker ?? GithubReleaseChecker();
  late final AppLinkOpener _appLinkOpener =
      widget.appLinkOpener ?? const AppLinkChannel();
  final Set<String> _locallyEditedSettingKeys = {};
  int _backupPreviewLoadToken = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLocalBackupPreview();
  }

  Future<void> _loadSettings({bool preserveLocalEdits = true}) async {
    final settings = await _settingsRepository.load();
    if (!mounted) return;
    setState(() {
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('haptics')) {
        _haptics = settings['haptics'] != 'false';
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('haptic_strength')) {
        _hapticStrength = settings['haptic_strength'] ?? AppHaptics.medium;
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('restore_state')) {
        _restoreState = settings['restore_state'] != 'false';
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('auto_save')) {
        _autoSave = settings['auto_save'] != 'false';
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('theme_mode')) {
        _themeMode = settings['theme_mode'] ?? _themeMode;
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('theme_id')) {
        _themeId = settings['theme_id'] ?? _themeId;
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('language')) {
        _languageCode = settings['language'] ?? _languageCode;
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('angle_mode')) {
        _angleMode = settings['angle_mode'] ?? _angleMode;
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('digits')) {
        _digits = settings['digits'] ?? _digits;
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('group_thousands')) {
        _groupThousands = settings['group_thousands'] == 'true';
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('expression_display')) {
        // 中文：**旧值迁移**——`'函数表达式'` 是历史令牌，读到时升级成 `'数学表达式'`。
        //       两个字面量都直接来 `SettingsTokens`，因为它们是存储格式，不是可以翻译的文案。
        // English: **Legacy migration** — `'函数表达式'` is a historical token and is upgraded to
        //          `'数学表达式'` on read. Both literals come straight from `SettingsTokens`, being
        //          storage format rather than translatable copy.
        _expressionDisplay =
            settings['expression_display'] ==
                    SettingsTokens.expressionDisplayFunctionLegacy
                ? SettingsTokens.expressionDisplayMath
                : settings['expression_display'] ?? _expressionDisplay;
      }
      if (!preserveLocalEdits ||
          !_locallyEditedSettingKeys.contains('percentage_mode')) {
        // 中文：认不出的值回落到 `'direct'`（= `AppSettings.fromMap` 的同一条判据），
        //       所以界面上显示的永远是两个变体之一，而不是一个待迁移的令牌。
        // English: unrecognised values fall back to `'direct'` (the same judgement
        //          `AppSettings.fromMap` makes), so the screen always shows one of the two variants
        //          rather than a pending migration token.
        _percentageMode =
            settings['percentage_mode'] == SettingsTokens.percentageRelative
                ? SettingsTokens.percentageRelative
                : SettingsTokens.defaultPercentageMode;
      }
    });
  }

  Future<void> _loadLocalBackupPreview() async {
    final token = ++_backupPreviewLoadToken;
    try {
      final preview = await _backupRepository.currentPreview();
      if (!mounted || token != _backupPreviewLoadToken) return;
      setState(() => _localBackupPreview = preview);
    } catch (_) {
      if (!mounted || token != _backupPreviewLoadToken) return;
      setState(() => _localBackupPreview = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 中文：文案一律经这张表取，控件里不留界面字面量——这是"后续迁移是机械的"的样板：
    //       加一种语言只动 `settings_strings.dart` 与 `AppLanguage`，本文件一个字不用改。
    // English: All copy comes through this table; the widgets keep no UI literals of their own. That
    //          is the template the later migrations follow: adding a language touches only
    //          `settings_strings.dart` and `AppLanguage`, and not one line of this file.
    final s = SettingsStrings.of(context);
    final bs = SettingsBackupStrings.of(context);
    return Scaffold(
      body: SafeArea(
        // 中文：**整页一次性建出来，不用 `ListView` 的按需构建。** 这一页是固定的二十来行，
        //       `ListView` 省下的构建成本可以忽略；而它带来的后果是**屏幕外的那几行不在控件树里**，
        //       于是「默认态还能找到这句话吗」这类测试实际上问的是「这句话落在视口 + cacheExtent
        //       之内吗」——**加一行新设置就能让一条与文案无关的断言变红**
        //       （实测：百分比计算那一行加进来，`settings_appearance_selection_test.dart` 的
        //       「默认态与接入前逐字节相同」当场找不到「触感反馈」）。那一页的每一句话本来就该
        //       真的在树里，这条断言也才真的是在问文案。
        // English: **the whole page is built, so no `ListView` laziness.** It is a fixed score of rows
        //          and the build cost `ListView` saves is negligible, while its consequence is that
        //          **rows below the fold are not in the widget tree** — so a test asking "can this
        //          sentence still be found in the default state" is really asking "does it fall inside
        //          the viewport plus cacheExtent", and **one added setting turns a copy-unrelated
        //          assertion red** (measured: adding the percentage-calculation row made
        //          `settings_appearance_selection_test.dart`'s "default state is byte-identical" stop
        //          finding 触感反馈). Every sentence on this page belongs in the tree, and only then is
        //          that assertion about copy.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconToolButton(
                      icon: Icons.arrow_back_ios_new,
                      tooltip: s.backTooltip,
                      onTap: () => Navigator.pop(context)),
                  Expanded(child: Center(child: PageTitle(s.pageTitle))),
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: 20),
              SectionTitle(s.sectionAppearance),
              SettingsGroup(
                children: [
                  SettingsTile(
                      icon: Icons.contrast,
                      title: s.themeModeTileTitle,
                      value: s.themeModeLabel(_themeMode),
                      onTap: _cycleTheme),
                  SettingsTile(
                      icon: Icons.palette_outlined,
                      title: s.themeTileTitle,
                      value: s.themeLabel(_themeId),
                      onTap: _cycleCalcTheme),
                  SettingsTile(
                      icon: Icons.translate,
                      title: s.languageTileTitle,
                      value: AppLanguage.fromCode(_languageCode).label,
                      onTap: _cycleLanguage),
                  SettingsTile(
                      icon: Icons.architecture,
                      title: s.angleModeTileTitle,
                      value: s.angleModeLabel(_angleMode),
                      onTap: _cycleAngleMode),
                  SettingsTile(
                      icon: Icons.pin,
                      title: s.numberFormatTileTitle,
                      // 中文：示例数字刻意不翻译——它演示的就是分组符号本身。
                      // English: The sample number is deliberately not translated; the grouping
                      //          separator is the thing it demonstrates.
                      value: _groupThousands ? '1,234.56' : '1234.56',
                      onTap: _toggleThousandsGrouping),
                  SettingsTile(
                      icon: Icons.more_horiz,
                      title: s.decimalPlacesTileTitle,
                      value: s.digitsLabel(_digits),
                      onTap: () => _cycleDigits()),
                  SettingsTile(
                      icon: Icons.functions,
                      title: s.expressionDisplayTileTitle,
                      value: s.expressionDisplayLabel(_expressionDisplay),
                      onTap: _cycleExpressionDisplay),
                  SettingsTile(
                      icon: Icons.percent,
                      title: s.percentageModeTileTitle,
                      value: s.percentageModeLabel(_percentageMode),
                      onTap: _cyclePercentageMode),
                ],
              ),
              const SizedBox(height: 18),
              SectionTitle(s.sectionExperience),
              SettingsGroup(
                children: [
                  SwitchTile(
                      icon: Icons.touch_app_outlined,
                      title: s.hapticsTileTitle,
                      value: _haptics,
                      onChanged: (value) => _setBool('haptics', value)),
                  SettingsTile(
                      icon: Icons.vibration,
                      title: s.hapticStrengthTileTitle,
                      value: _haptics
                          ? s.hapticStrengthLabel(_hapticStrength)
                          : s.hapticsOffLabel,
                      onTap: _haptics ? _cycleHapticStrength : null),
                  SwitchTile(
                      icon: Icons.history,
                      title: s.restoreStateTileTitle,
                      value: _restoreState,
                      onChanged: (value) => _setBool('restore_state', value)),
                  SwitchTile(
                      icon: Icons.save_outlined,
                      title: s.autoSaveHistoryTileTitle,
                      value: _autoSave,
                      onChanged: (value) => _setBool('auto_save', value)),
                ],
              ),
              const SizedBox(height: 18),
              SectionTitle(s.sectionData),
              SettingsGroup(
                children: [
                  _DataSummaryTile(
                    preview: _localBackupPreview,
                    busy: _backupBusy,
                    onRefresh: _backupBusy ? null : _loadLocalBackupPreview,
                  ),
                  SettingsTile(
                      icon: Icons.ios_share_outlined,
                      title: s.exportBackupTitle,
                      value: _backupBusy
                          ? s.processing
                          : (_localBackupPreview == null
                              ? s.saveFile
                              : bs.backupTotalRecords(
                                  _localBackupPreview!.totalRows)),
                      onTap: _backupBusy ? null : _exportBackup),
                  SettingsTile(
                      icon: Icons.restore_page_outlined,
                      title: s.importBackupTitle,
                      value: _backupBusy ? s.processing : s.chooseFile,
                      onTap: _backupBusy ? null : _importBackup),
                ],
              ),
              const SizedBox(height: 18),
              SectionTitle(s.sectionAbout),
              SettingsGroup(
                children: [
                  SettingsTile(
                      icon: Icons.info_outline,
                      title: s.aboutTileTitle,
                      value: AppInfo.version,
                      onTap: _showAbout),
                  SettingsTile(
                      icon: Icons.system_update_alt,
                      title: s.checkUpdateTitle,
                      // 中文：`GitHub Releases` 是产品名，不是文案，不翻译。
                      // English: `GitHub Releases` is a product name, not copy; left untranslated.
                      value: _updateBusy ? s.checking : 'GitHub Releases',
                      onTap: _updateBusy ? null : _checkForUpdate),
                  SettingsTile(
                      icon: Icons.help_outline,
                      title: s.helpFeedbackTitle,
                      value: s.helpFeedbackValue,
                      onTap: _showHelpAndFeedback),
                  SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: s.privacyPolicyTitle,
                      value: '',
                      onTap: () =>
                          _showInfo(s.privacyPolicyTitle, s.privacyPolicyBody)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 中文：下面每个 `_cycle*` 都只做两件事：把**持久化令牌**换到下一个，然后原样写库。
  //       屏幕上那句标签由 `build` 经 `SettingsStrings` 取得，循环里一个字面量都不出现——
  //       这正是"切换语言不改动持久化值"的结构性保证：令牌根本不经过语言表。
  // English: Every `_cycle*` below does exactly two things: advance a **persisted token** and write it
  //          to storage unchanged. The on-screen label is produced by `build` through
  //          `SettingsStrings`, so no literal appears in the cycle at all. That is the structural
  //          guarantee behind "switching language never moves a persisted value": the tokens never
  //          pass through the language table.
  void _cycleTheme() {
    _feedback();
    _locallyEditedSettingKeys.add('theme_mode');
    setState(() {
      _themeMode = switch (_themeMode) {
        SettingsTokens.themeModeSystem => SettingsTokens.themeModeLight,
        SettingsTokens.themeModeLight => SettingsTokens.themeModeDark,
        _ => SettingsTokens.themeModeSystem,
      };
    });
    _settingsRepository.set('theme_mode', _themeMode);
    widget.onThemeModeChanged?.call(_themeMode);
  }

  void _cycleCalcTheme() {
    _feedback();
    _locallyEditedSettingKeys.add('theme_id');
    setState(() {
      final index = CalcTheme.all.indexWhere((theme) => theme.id == _themeId);
      // 中文：认不出的 id（删掉的主题、手改过的库）当作"还没选过"，下一次落到第一套，
      //       而不是原地不动——`indexWhere` 的 -1 会让 `(_themeId + 1) % 3` 变成 0，正好如此。
      // English: An unrecognised id (a removed theme, a hand-edited database) counts as "nothing
      //          chosen yet" and advances to the first theme rather than standing still —
      //          `indexWhere`'s -1 makes `(index + 1) % 3` land on 0, exactly as wanted.
      _themeId = CalcTheme.all[(index + 1) % CalcTheme.all.length].id;
    });
    _settingsRepository.set('theme_id', _themeId);
    widget.onThemeChanged?.call(_themeId);
  }

  void _cycleLanguage() {
    _feedback();
    _locallyEditedSettingKeys.add('language');
    setState(() {
      final index =
          AppLanguage.values.indexWhere((item) => item.code == _languageCode);
      _languageCode =
          AppLanguage.values[(index + 1) % AppLanguage.values.length].code;
    });
    _settingsRepository.set('language', _languageCode);
    widget.onLanguageChanged?.call(_languageCode);
  }

  void _cycleAngleMode() {
    _feedback();
    _locallyEditedSettingKeys.add('angle_mode');
    setState(() {
      _angleMode = _angleMode == SettingsTokens.angleModeRadians
          ? SettingsTokens.angleModeDegrees
          : SettingsTokens.angleModeRadians;
    });
    _settingsRepository.set('angle_mode', _angleMode);
  }

  void _cycleDigits() {
    _feedback();
    _locallyEditedSettingKeys.add('digits');
    setState(() {
      _digits = switch (_digits) {
        SettingsTokens.digits4 => SettingsTokens.digits6,
        SettingsTokens.digits6 => SettingsTokens.digits8,
        _ => SettingsTokens.digits4,
      };
    });
    _settingsRepository.set('digits', _digits);
  }

  void _toggleThousandsGrouping() {
    _feedback();
    _locallyEditedSettingKeys.add('group_thousands');
    setState(() => _groupThousands = !_groupThousands);
    _settingsRepository.set('group_thousands', _groupThousands.toString());
  }

  void _cycleExpressionDisplay() {
    _feedback();
    _locallyEditedSettingKeys.add('expression_display');
    setState(() {
      _expressionDisplay =
          _expressionDisplay == SettingsTokens.expressionDisplaySymbols
              ? SettingsTokens.expressionDisplayMath
              : SettingsTokens.expressionDisplaySymbols;
    });
    _settingsRepository.set('expression_display', _expressionDisplay);
  }

  void _cyclePercentageMode() {
    _feedback();
    _locallyEditedSettingKeys.add('percentage_mode');
    setState(() {
      _percentageMode = _percentageMode == SettingsTokens.percentageDirect
          ? SettingsTokens.percentageRelative
          : SettingsTokens.percentageDirect;
    });
    _settingsRepository.set('percentage_mode', _percentageMode);
  }

  void _cycleHapticStrength() {
    _locallyEditedSettingKeys.add('haptic_strength');
    setState(() {
      _hapticStrength = switch (_hapticStrength) {
        AppHaptics.light => AppHaptics.medium,
        AppHaptics.medium => AppHaptics.strong,
        _ => AppHaptics.light,
      };
    });
    _settingsRepository.set('haptic_strength', _hapticStrength);
    _feedback();
  }

  void _setBool(String key, bool value) {
    final feedbackAfterChange = key == 'haptics' && value;
    if (!feedbackAfterChange) _feedback();
    _locallyEditedSettingKeys.add(key);
    setState(() {
      switch (key) {
        case 'haptics':
          _haptics = value;
        case 'restore_state':
          _restoreState = value;
        case 'auto_save':
          _autoSave = value;
      }
    });
    _settingsRepository.set(key, value.toString());
    if (feedbackAfterChange) _feedback();
  }

  void _feedback() {
    AppHaptics.tap(enabled: _haptics, strength: _hapticStrength);
  }

  Future<void> _checkForUpdate() async {
    if (_updateBusy) return;
    _feedback();
    setState(() => _updateBusy = true);
    final result = await _updateChecker.check(currentVersion: AppInfo.version);
    if (!mounted) return;
    setState(() => _updateBusy = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final s = SettingsStrings.of(dialogContext);
        final release = result.release;
        final actionLabel = switch (result.status) {
          UpdateCheckStatus.updateAvailable => s.viewRelease,
          UpdateCheckStatus.upToDate => s.viewReleaseNotes,
          UpdateCheckStatus.unavailable => s.openReleasesPage,
        };
        final actionUrl = release?.url ?? GithubReleaseChecker.releasesPageUrl;
        final icon = switch (result.status) {
          UpdateCheckStatus.updateAvailable => Icons.new_releases_outlined,
          UpdateCheckStatus.upToDate => Icons.verified_outlined,
          UpdateCheckStatus.unavailable => Icons.cloud_off_outlined,
        };
        return AlertDialog(
          title: Text(s.checkUpdateTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  // 中文：那句话由呈现层按令牌取（`update_check_message.dart`）——取表的语言就是
                  //       对话框所在屏幕的语言。
                  // English: the sentence is read at the presentation edge from the token
                  //          (`update_check_message.dart`) — the table's language is the language of the
                  //          screen the dialog sits on.
                  Expanded(child: Text(updateCheckMessage(result, s))),
                ],
              ),
              const SizedBox(height: 12),
              Text(s.currentVersion(AppInfo.version),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (release != null)
                Text(s.remoteVersion(release.version),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(s.close),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final opened = await _openExternalUrl(actionUrl);
                if (opened && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportBackup() async {
    // 中文：文件选择器和备份生成都可能较慢，防止用户重复打开导出流程。
    // English: Export generation and the file picker may be slow, so prevent duplicate export flows.
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final export = await _backupRepository.exportBackup();
      final saved = await BackupFileChannel.exportJson(
        fileName: export.fileName,
        content: export.content,
      );
      if (!mounted) return;
      if (saved) {
        _backupPreviewLoadToken++;
        await _loadLocalBackupPreview();
        if (!mounted) return;
        final s = SettingsStrings.of(context);
        final bs = SettingsBackupStrings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // 中文：回执与详情那两句由呈现边缘按结果取（`settings_backup_text.dart`）。
            // English: the receipt and its detail are read at the presentation edge from the result
            //          (`settings_backup_text.dart`).
            content: Text(backupExportSuccessMessage(export, bs)),
            action: SnackBarAction(
              label: s.details,
              onPressed: () =>
                  _showInfo(s.exportBackupTitle, backupExportDetail(export, bs)),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showInfo(
            SettingsStrings.of(context).exportFailedTitle, error.toString());
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _importBackup() async {
    // 中文：导入会替换整库，必须保证同一时间只有一个恢复流程。
    // English: Import replaces the whole database, so only one restore flow may run at a time.
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final json = await BackupFileChannel.importJson();
      if (json == null) return;
      if (!mounted) return;
      final preview = _backupRepository.previewJson(json);
      final localPreview = await _backupRepository.currentPreview();
      if (!mounted) return;
      _backupPreviewLoadToken++;
      setState(() => _localBackupPreview = localPreview);
      final mergePlan = _backupRepository.buildImportPlan(
        source: preview,
        local: localPreview,
        replaceExisting: false,
      );
      final replacePlan = _backupRepository.buildImportPlan(
        source: preview,
        local: localPreview,
        replaceExisting: true,
      );
      final canReplace = preview.totalRows > 0;
      final mode = await showDialog<_BackupImportMode>(
        context: context,
        builder: (dialogContext) {
          final s = SettingsStrings.of(dialogContext);
          return AlertDialog(
            title: Text(s.importBackupTitle),
            content: SingleChildScrollView(
              child: _BackupImportPrompt(
                source: preview,
                local: localPreview,
                mergePlan: mergePlan,
                replacePlan: replacePlan,
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(s.cancel)),
              TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, _BackupImportMode.merge),
                  child: Text(s.importMerge)),
              FilledButton(
                  onPressed: canReplace
                      ? () => Navigator.pop(
                          dialogContext, _BackupImportMode.replace)
                      : null,
                  child: Text(s.importReplace)),
            ],
          );
        },
      );
      if (mode == null) return;
      final report = await _backupRepository.importJson(
        json,
        replaceExisting: mode == _BackupImportMode.replace,
      );
      _locallyEditedSettingKeys.clear();
      await _loadSettings(preserveLocalEdits: false);
      if (!mounted) return;
      _backupPreviewLoadToken++;
      setState(() => _localBackupPreview = report.after);
      final onDataImported = widget.onDataImported;
      if (onDataImported != null) await onDataImported();
      if (!mounted) return;
      final s = SettingsStrings.of(context);
      final bs = SettingsBackupStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        // 中文：模式词与结果那句按令牌/读数在呈现边缘取（`settings_backup_text.dart`）。
        // English: the mode word and the result sentence are read at the presentation edge from the
        //          token/readings (`settings_backup_text.dart`).
        content: Text(s.importDone(
          backupReportModeLabel(report, bs),
          backupReportResultLabel(report, bs),
        )),
        action: SnackBarAction(
          label: s.details,
          onPressed: () =>
              _showInfo(s.importResultTitle, _formatBackupImportReport(report)),
        ),
      ));
      // 中文：导入会把配色与语言一并从备份里换掉，所以这两个实时回调也要重发一次——
      //       只发 `onThemeModeChanged` 的话，恢复了一份英文 / 薰衣草雾的备份后，界面要等退出
      //       设置页才跟着变。
      // English: An import replaces the palette and the language along with everything else, so both
      //          live callbacks are re-fired here. Re-firing only `onThemeModeChanged` would leave an
      //          English / Lavender Mist backup restored but not shown until the page pops.
      widget.onThemeModeChanged?.call(_themeMode);
      widget.onThemeChanged?.call(_themeId);
      widget.onLanguageChanged?.call(_languageCode);
    } catch (error) {
      if (mounted) {
        _showInfo(
          SettingsStrings.of(context).importFailedTitle,
          // 中文：失败详情由呈现边缘取（`settings_backup_messages.dart`）——被拒绝的覆盖恢复印的是
          //       文案表里那句话，其余异常仍是技术串。
          // English: the failure detail is read at the presentation edge
          //          (`settings_backup_messages.dart`) — a rejected replace prints the copy table's
          //          sentence, every other exception stays a technical string.
          backupImportFailureMessage(error, SettingsBackupStrings.of(context)),
        );
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  String _formatBackupImportReport(BackupImportReport report) {
    final s = SettingsStrings.of(context);
    final bs = SettingsBackupStrings.of(context);
    final deltas = [
      for (final item in report.tableReports)
        s.reportTableRow(
          // 中文：行首那格是标签，按表名（键）在呈现边缘查（`backupTableLabel`）。
          // English: the leading cell is the label, looked up from the table name (key) at the
          //          presentation edge (`backupTableLabel`).
          backupTableLabel(item.name, bs),
          item.source,
          item.before,
          item.after,
          _formatDelta(item.delta),
          item.hasSkippedRows ? s.reportSkipped(item.skipped) : '',
        ),
    ].join('\n');
    return [
      // 中文：四句都在呈现边缘取（`settings_backup_text.dart`）——模式词、结果句、三处总计。
      // English: all four come from the presentation edge (`settings_backup_text.dart`) — the mode
      //          word, the result sentence and the three totals.
      s.reportMode(backupReportModeLabel(report, bs)),
      s.reportResult(backupReportResultLabel(report, bs)),
      s.reportSource(bs.backupTotalRecords(report.source.totalRows)),
      s.reportBefore(bs.backupTotalRecords(report.before.totalRows)),
      s.reportAfter(bs.backupTotalRecords(report.after.totalRows)),
      '',
      deltas,
    ].join('\n');
  }

  String _formatDelta(int value) {
    if (value > 0) return '+$value';
    return value.toString();
  }
}
