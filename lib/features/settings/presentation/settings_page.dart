import 'package:flutter/material.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/platform/app_haptics.dart';
import '../../../core/platform/backup_file_channel.dart';
import '../../../core/utils/backup_snapshot_validator.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/data_backup_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/presentation/app_chrome.dart';

/// 中文：设置页负责展示偏好项、持久化设置，以及备份导入导出入口。
/// English: Settings screen for preferences, persistence, and backup import/export entry points.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.db,
    this.onThemeModeChanged,
    this.onDataImported,
    super.key,
  });

  final AppDatabase db;
  final ValueChanged<String>? onThemeModeChanged;
  final Future<void> Function()? onDataImported;

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
  String _expressionDisplay = '数学符号';
  bool _backupBusy = false;
  BackupPreview? _localBackupPreview;
  late final DataBackupRepository _backupRepository =
      DataBackupRepository(widget.db);
  late final SettingsRepository _settingsRepository =
      SettingsRepository(widget.db);
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
                const SettingsTile(
                    icon: Icons.pin, title: '数字格式', value: '1,234.56'),
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
                    value: AppInfo.updateLabel,
                    onTap: () => _showInfo('检查更新',
                        '${AppInfo.channel}。APK 已由本机 Flutter/Gradle 编译生成。')),
                SettingsTile(
                    icon: Icons.help_outline,
                    title: '帮助与反馈',
                    value: '',
                    onTap: () => _showInfo('帮助与反馈',
                        '计算页用于快速表达式；工具页按分类检索工程工具；图形页可添加函数并分析零点、交点和极值；笔记页管理历史与保存结果。')),
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

  void _showAbout() {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: 0.72),
                    scheme.secondaryContainer.withValues(alpha: 0.58)
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.24)),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? const []
                          : const [
                              BoxShadow(
                                  color: Color(0x1A5B47FF),
                                  blurRadius: 24,
                                  offset: Offset(0, 10))
                            ],
                    ),
                    child: Icon(Icons.calculate_rounded,
                        color: scheme.primary, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(AppInfo.name,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface)),
                  const SizedBox(height: 4),
                  Text('${AppInfo.version}  ${AppInfo.channel}',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('个人全能计算工作台，覆盖科学计算、工程工具、单位换算、函数图形和计算笔记。'),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AboutChip('科学计算'),
                      _AboutChip('工程工具'),
                      _AboutChip('函数图形'),
                      _AboutChip('SQLite 本地记录'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined,
                          size: 18, color: Color(0xFF23B45D)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('数据当前仅保存在本机 SQLite，不上传网络服务。',
                              style:
                                  TextStyle(color: scheme.onSurfaceVariant))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => _showInfo('开源结构',
                  '项目采用 Feature-first + Clean Architecture 简化版：UI、Application、Domain、Data、Core 分层维护。'),
              child: const Text('架构')),
          FilledButton(
              onPressed: () => Navigator.pop(context), child: const Text('完成')),
        ],
      ),
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

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了')),
        ],
      ),
    );
  }
}

enum _BackupImportMode { merge, replace }

class _BackupImportPrompt extends StatelessWidget {
  const _BackupImportPrompt({
    required this.source,
    required this.local,
    required this.mergePlan,
    required this.replacePlan,
  });

  final BackupPreview source;
  final BackupPreview local;
  final BackupImportPlan mergePlan;
  final BackupImportPlan replacePlan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warnings = buildBackupPreviewWarnings(
      source,
      now: DateTime.now(),
      currentAppVersion: AppInfo.version,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackupPreviewBlock(title: '备份文件', preview: source),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            _BackupWarningsBlock(warnings: warnings),
          ],
          const SizedBox(height: 12),
          _BackupPreviewBlock(title: '本机当前', preview: local),
          const SizedBox(height: 12),
          _BackupPlanBlock(plan: mergePlan),
          const SizedBox(height: 10),
          _BackupPlanBlock(
            plan: replacePlan,
            blockedMessage: replacePlan.source.totalRows == 0
                ? emptyBackupReplaceErrorMessage
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.security_outlined,
                  color: scheme.onSurfaceVariant, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '请确认文件来自可信备份。覆盖恢复会先清空本机数据；合并导入会保留本机数据，但设置和同一工具记录可能被备份内容更新。',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackupPreviewBlock extends StatelessWidget {
  const _BackupPreviewBlock({
    required this.title,
    required this.preview,
  });

  final String title;
  final BackupPreview preview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          '版本：${preview.appVersion ?? '未知'}\n'
          '时间：${preview.exportedAt ?? '本机当前'}\n'
          '总计：${preview.totalLabel}\n'
          '${preview.summary}',
          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
        ),
      ],
    );
  }
}

class _BackupWarningsBlock extends StatelessWidget {
  const _BackupWarningsBlock({required this.warnings});

  final List<BackupPreviewWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highestSeverity = warnings.fold<BackupPreviewWarningSeverity>(
      BackupPreviewWarningSeverity.info,
      (current, warning) =>
          warning.severity.index > current.index ? warning.severity : current,
    );
    final color = switch (highestSeverity) {
      BackupPreviewWarningSeverity.danger => scheme.error,
      BackupPreviewWarningSeverity.warning => scheme.tertiary,
      BackupPreviewWarningSeverity.info => scheme.primary,
    };
    final icon = switch (highestSeverity) {
      BackupPreviewWarningSeverity.danger => Icons.error_outline,
      BackupPreviewWarningSeverity.warning => Icons.warning_amber_outlined,
      BackupPreviewWarningSeverity.info => Icons.info_outline,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text('备份提示',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                warning.message,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackupPlanBlock extends StatelessWidget {
  const _BackupPlanBlock({
    required this.plan,
    this.blockedMessage,
  });

  final BackupImportPlan plan;
  final String? blockedMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = plan.replaceExisting ? scheme.error : scheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                plan.replaceExisting
                    ? Icons.warning_amber_outlined
                    : Icons.merge_type_outlined,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${plan.modeLabel}后预计 ${plan.totalLabel}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in plan.tableCounts) ...[
            _BackupPlanRow(
              label: item.label,
              before: plan.beforeFor(item.name),
              source: plan.sourceFor(item.name),
              expected: plan.expectedFor(item.name),
              delta: plan.deltaFor(item.name),
            ),
            if (item.name != backupTableNames.last) const SizedBox(height: 4),
          ],
          if (plan.impacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _BackupImpactList(impacts: plan.impacts),
          ],
          if (blockedMessage case final message?) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block_outlined, color: scheme.error, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: scheme.error,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BackupImpactList extends StatelessWidget {
  const _BackupImpactList({required this.impacts});

  final List<BackupImportImpact> impacts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final impact in impacts) ...[
          _BackupImpactRow(impact: impact),
          if (impact != impacts.last) const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _BackupImpactRow extends StatelessWidget {
  const _BackupImpactRow({required this.impact});

  final BackupImportImpact impact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (impact.severity) {
      BackupImportImpactSeverity.danger => scheme.error,
      BackupImportImpactSeverity.warning => scheme.tertiary,
      BackupImportImpactSeverity.info => scheme.onSurfaceVariant,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_impactIcon(impact.icon), color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            impact.message,
            style: TextStyle(
              color: color,
              fontSize: 12,
              height: 1.3,
              fontWeight: impact.severity == BackupImportImpactSeverity.info
                  ? FontWeight.w600
                  : FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  IconData _impactIcon(BackupImportImpactIcon icon) {
    return switch (icon) {
      BackupImportImpactIcon.merge => Icons.merge_type_outlined,
      BackupImportImpactIcon.replace => Icons.change_circle_outlined,
      BackupImportImpactIcon.delete => Icons.delete_outline,
      BackupImportImpactIcon.blocked => Icons.block_outlined,
      BackupImportImpactIcon.settings => Icons.tune_outlined,
      BackupImportImpactIcon.tools => Icons.construction_outlined,
      BackupImportImpactIcon.history => Icons.history,
    };
  }
}

class _BackupPlanRow extends StatelessWidget {
  const _BackupPlanRow({
    required this.label,
    required this.before,
    required this.source,
    required this.expected,
    required this.delta,
  });

  final String label;
  final int before;
  final int source;
  final int expected;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final deltaText = delta > 0 ? '+$delta' : delta.toString();
    final deltaColor = delta < 0
        ? scheme.error
        : delta > 0
            ? scheme.primary
            : scheme.onSurfaceVariant;
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(
            '本机 $before · 文件 $source · 导入后 $expected',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(deltaText,
            style: TextStyle(color: deltaColor, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _AboutChip extends StatelessWidget {
  const _AboutChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Text(label,
          style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12)),
    );
  }
}

class _DataSummaryTile extends StatelessWidget {
  const _DataSummaryTile({
    required this.preview,
    required this.busy,
    required this.onRefresh,
  });

  final BackupPreview? preview;
  final bool busy;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = preview;
    return ListTile(
      leading: Icon(Icons.storage_outlined, color: scheme.primary),
      title: const Text('本机数据', style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: current == null
          ? Text('统计中', style: TextStyle(color: scheme.onSurfaceVariant))
          : Text(
              current.summary,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current != null)
            Text(current.totalLabel,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '刷新数据统计',
            onPressed: onRefresh,
            icon: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: scheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(value, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class SwitchTile extends StatelessWidget {
  const SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: scheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
