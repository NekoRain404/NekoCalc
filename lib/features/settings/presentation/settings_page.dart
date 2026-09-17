import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/update/github_release_checker.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/platform/app_link_channel.dart';
import '../../../core/platform/app_haptics.dart';
import '../../../core/platform/backup_file_channel.dart';
import '../../../core/utils/backup_snapshot_validator.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/data_backup_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/presentation/app_chrome.dart';

part 'settings_dialogs.dart';
part 'settings_backup_widgets.dart';
part 'settings_tiles.dart';

/// 中文：设置页负责展示偏好项、持久化设置，以及备份导入导出入口。
/// English: Settings screen for preferences, persistence, and backup import/export entry points.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.db,
    this.onThemeModeChanged,
    this.onDataImported,
    this.updateChecker,
    this.appLinkOpener,
    super.key,
  });

  final AppDatabase db;
  final ValueChanged<String>? onThemeModeChanged;
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
  String _themeMode = '跟随系统';
  String _angleMode = '弧度';
  String _digits = '6 位';
  bool _groupThousands = false;
  String _expressionDisplay = '数学符号';
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
        _expressionDisplay = settings['expression_display'] == '函数表达式'
            ? '数学表达式'
            : settings['expression_display'] ?? _expressionDisplay;
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
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(
              children: [
                IconToolButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: '返回',
                    onTap: () => Navigator.pop(context)),
                const Expanded(child: Center(child: PageTitle('设置'))),
                const SizedBox(width: 36),
              ],
            ),
            const SizedBox(height: 20),
            const SectionTitle('外观设置'),
            SettingsGroup(
              children: [
                SettingsTile(
                    icon: Icons.contrast,
                    title: '主题模式',
                    value: _themeMode,
                    onTap: _cycleTheme),
                SettingsTile(
                    icon: Icons.architecture,
                    title: '角度模式',
                    value: _angleMode,
                    onTap: _cycleAngleMode),
                SettingsTile(
                    icon: Icons.pin,
                    title: '数字格式',
                    value: _groupThousands ? '1,234.56' : '1234.56',
                    onTap: _toggleThousandsGrouping),
                SettingsTile(
                    icon: Icons.more_horiz,
                    title: '小数位数',
                    value: _digits,
                    onTap: () => _cycleDigits()),
                SettingsTile(
                    icon: Icons.functions,
                    title: '表达式显示',
                    value: _expressionDisplay,
                    onTap: _cycleExpressionDisplay),
              ],
            ),
            const SizedBox(height: 18),
            const SectionTitle('使用体验'),
            SettingsGroup(
              children: [
                SwitchTile(
                    icon: Icons.touch_app_outlined,
                    title: '触感反馈',
                    value: _haptics,
                    onChanged: (value) => _setBool('haptics', value)),
                SettingsTile(
                    icon: Icons.vibration,
                    title: '触感强度',
                    value: _haptics ? _hapticStrength : '关闭',
                    onTap: _haptics ? _cycleHapticStrength : null),
                SwitchTile(
                    icon: Icons.history,
                    title: '记住上次状态',
                    value: _restoreState,
                    onChanged: (value) => _setBool('restore_state', value)),
                SwitchTile(
                    icon: Icons.save_outlined,
                    title: '自动保存计算历史',
                    value: _autoSave,
                    onChanged: (value) => _setBool('auto_save', value)),
              ],
            ),
            const SizedBox(height: 18),
            const SectionTitle('数据管理'),
            SettingsGroup(
              children: [
                _DataSummaryTile(
                  preview: _localBackupPreview,
                  busy: _backupBusy,
                  onRefresh: _backupBusy ? null : _loadLocalBackupPreview,
                ),
                SettingsTile(
                    icon: Icons.ios_share_outlined,
                    title: '导出备份',
                    value: _backupBusy
                        ? '处理中'
                        : _localBackupPreview?.totalLabel ?? '保存文件',
                    onTap: _backupBusy ? null : _exportBackup),
                SettingsTile(
                    icon: Icons.restore_page_outlined,
                    title: '导入恢复',
                    value: _backupBusy ? '处理中' : '选择文件',
                    onTap: _backupBusy ? null : _importBackup),
              ],
            ),
            const SizedBox(height: 18),
            const SectionTitle('关于与其他'),
            SettingsGroup(
              children: [
                SettingsTile(
                    icon: Icons.info_outline,
                    title: '关于 ${AppInfo.name}',
                    value: AppInfo.version,
                    onTap: _showAbout),
                SettingsTile(
                    icon: Icons.system_update_alt,
                    title: '检查更新',
                    value: _updateBusy ? '正在检查' : 'GitHub Releases',
                    onTap: _updateBusy ? null : _checkForUpdate),
                SettingsTile(
                    icon: Icons.help_outline,
                    title: '帮助与反馈',
                    value: '诊断报告与 GitHub Issue',
                    onTap: _showHelpAndFeedback),
                SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: '隐私政策',
                    value: '',
                    onTap: () => _showInfo('隐私政策',
                        '所有计算历史、收藏工具、设置和笔记当前仅存储在本机 SQLite 数据库，不会上传到网络服务。')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _cycleTheme() {
    _feedback();
    _locallyEditedSettingKeys.add('theme_mode');
    setState(() {
      _themeMode = switch (_themeMode) {
        '跟随系统' => '浅色',
        '浅色' => '深色',
        _ => '跟随系统',
      };
    });
    _settingsRepository.set('theme_mode', _themeMode);
    widget.onThemeModeChanged?.call(_themeMode);
  }

  void _cycleAngleMode() {
    _feedback();
    _locallyEditedSettingKeys.add('angle_mode');
    setState(() => _angleMode = _angleMode == '弧度' ? '角度' : '弧度');
    _settingsRepository.set('angle_mode', _angleMode);
  }

  void _cycleDigits() {
    _feedback();
    _locallyEditedSettingKeys.add('digits');
    setState(() {
      _digits = switch (_digits) {
        '4 位' => '6 位',
        '6 位' => '8 位',
        _ => '4 位',
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
      _expressionDisplay = _expressionDisplay == '数学符号' ? '数学表达式' : '数学符号';
    });
    _settingsRepository.set('expression_display', _expressionDisplay);
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
        final release = result.release;
        final actionLabel = switch (result.status) {
          UpdateCheckStatus.updateAvailable => '查看发布',
          UpdateCheckStatus.upToDate => '查看发布说明',
          UpdateCheckStatus.unavailable => '打开发布页',
        };
        final actionUrl = release?.url ?? GithubReleaseChecker.releasesPageUrl;
        final icon = switch (result.status) {
          UpdateCheckStatus.updateAvailable => Icons.new_releases_outlined,
          UpdateCheckStatus.upToDate => Icons.verified_outlined,
          UpdateCheckStatus.unavailable => Icons.cloud_off_outlined,
        };
        return AlertDialog(
          title: const Text('检查更新'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result.message)),
                ],
              ),
              const SizedBox(height: 12),
              Text('当前版本：${AppInfo.version}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (release != null)
                Text('线上版本：${release.version}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(export.successMessage),
            action: SnackBarAction(
              label: '详情',
              onPressed: () => _showInfo('导出备份', export.detail),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showInfo('导出失败', error.toString());
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
        builder: (context) => AlertDialog(
          title: const Text('导入恢复'),
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
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            TextButton(
                onPressed: () =>
                    Navigator.pop(context, _BackupImportMode.merge),
                child: const Text('合并导入')),
            FilledButton(
                onPressed: canReplace
                    ? () => Navigator.pop(context, _BackupImportMode.replace)
                    : null,
                child: const Text('覆盖恢复')),
          ],
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${report.modeLabel}完成：${report.resultLabel}'),
        action: SnackBarAction(
          label: '详情',
          onPressed: () => _showInfo('导入结果', _formatBackupImportReport(report)),
        ),
      ));
      widget.onThemeModeChanged?.call(_themeMode);
    } catch (error) {
      if (mounted) _showInfo('导入失败', error.toString());
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  String _formatBackupImportReport(BackupImportReport report) {
    final deltas = [
      for (final item in report.tableReports)
        '${item.label}：文件 ${item.source}，导入前 ${item.before}，导入后 ${item.after}，变化 ${_formatDelta(item.delta)}'
            '${item.hasSkippedRows ? '，跳过/裁剪 ${item.skipped}' : ''}',
    ].join('\n');
    return [
      '模式：${report.modeLabel}',
      '结果：${report.resultLabel}',
      '导入文件：${report.source.totalLabel}',
      '导入前：${report.before.totalLabel}',
      '导入后：${report.after.totalLabel}',
      '',
      deltas,
    ].join('\n');
  }

  String _formatDelta(int value) {
    if (value > 0) return '+$value';
    return value.toString();
  }

}
