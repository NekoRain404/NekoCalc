import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/local/app_database.dart';
import '../../../shared/presentation/app_chrome.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.db, this.onThemeModeChanged, super.key});

  final AppDatabase db;
  final ValueChanged<String>? onThemeModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _haptics = true;
  bool _restoreState = true;
  bool _autoSave = true;
  String _themeMode = '跟随系统';
  String _angleMode = '弧度';
  String _digits = '6 位';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await widget.db.settings();
    if (!mounted) return;
    setState(() {
      _haptics = settings['haptics'] != 'false';
      _restoreState = settings['restore_state'] != 'false';
      _autoSave = settings['auto_save'] != 'false';
      _themeMode = settings['theme_mode'] ?? _themeMode;
      _angleMode = settings['angle_mode'] ?? _angleMode;
      _digits = settings['digits'] ?? _digits;
    });
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
                IconToolButton(icon: Icons.arrow_back_ios_new, tooltip: '返回', onTap: () => Navigator.pop(context)),
                const Expanded(child: Center(child: PageTitle('设置'))),
                const SizedBox(width: 36),
              ],
            ),
            const SizedBox(height: 20),
            const SectionTitle('外观设置'),
            SettingsGroup(
              children: [
                SettingsTile(icon: Icons.contrast, title: '主题模式', value: _themeMode, onTap: _cycleTheme),
                SettingsTile(icon: Icons.architecture, title: '角度模式', value: _angleMode, onTap: _cycleAngleMode),
                const SettingsTile(icon: Icons.pin, title: '数字格式', value: '1,234.56'),
                SettingsTile(icon: Icons.more_horiz, title: '小数位数', value: _digits, onTap: () => _cycleDigits()),
              ],
            ),
            const SizedBox(height: 18),
            const SectionTitle('使用体验'),
            SettingsGroup(
              children: [
                SwitchTile(icon: Icons.touch_app_outlined, title: '触感反馈', value: _haptics, onChanged: (value) => _setBool('haptics', value)),
                SwitchTile(icon: Icons.history, title: '记住上次状态', value: _restoreState, onChanged: (value) => _setBool('restore_state', value)),
                SwitchTile(icon: Icons.save_outlined, title: '自动保存计算历史', value: _autoSave, onChanged: (value) => _setBool('auto_save', value)),
              ],
            ),
            const SizedBox(height: 18),
            const SectionTitle('关于与其他'),
            SettingsGroup(
              children: [
                SettingsTile(icon: Icons.info_outline, title: '关于 NekoCalc', value: 'v1.0.0-beta.1', onTap: _showAbout),
                SettingsTile(icon: Icons.system_update_alt, title: '检查更新', value: 'Beta 构建', onTap: () => _showInfo('检查更新', '当前为 Beta 预览构建。APK 已由本机 Flutter/Gradle 编译生成。')),
                SettingsTile(icon: Icons.help_outline, title: '帮助与反馈', value: '', onTap: () => _showInfo('帮助与反馈', '计算页用于快速表达式；工具页按分类检索工程工具；图形页可添加函数并分析零点、交点和极值；笔记页管理历史与保存结果。')),
                SettingsTile(icon: Icons.privacy_tip_outlined, title: '隐私政策', value: '', onTap: () => _showInfo('隐私政策', '所有计算历史、收藏工具、设置和笔记当前仅存储在本机 SQLite 数据库，不会上传到网络服务。')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _cycleTheme() {
    _feedback();
    setState(() {
      _themeMode = switch (_themeMode) {
        '跟随系统' => '浅色',
        '浅色' => '深色',
        _ => '跟随系统',
      };
    });
    widget.db.setSetting('theme_mode', _themeMode);
    widget.onThemeModeChanged?.call(_themeMode);
  }

  void _cycleAngleMode() {
    _feedback();
    setState(() => _angleMode = _angleMode == '弧度' ? '角度' : '弧度');
    widget.db.setSetting('angle_mode', _angleMode);
  }

  void _cycleDigits() {
    _feedback();
    setState(() {
      _digits = switch (_digits) {
        '4 位' => '6 位',
        '6 位' => '8 位',
        _ => '4 位',
      };
    });
    widget.db.setSetting('digits', _digits);
  }

  void _setBool(String key, bool value) {
    if (key != 'haptics' || value) _feedback();
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
    widget.db.setSetting(key, value.toString());
  }

  void _feedback() {
    if (_haptics) HapticFeedback.selectionClick();
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
                  colors: [scheme.primaryContainer.withValues(alpha: 0.72), scheme.secondaryContainer.withValues(alpha: 0.58)],
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
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? const []
                          : const [BoxShadow(color: Color(0x1A5B47FF), blurRadius: 24, offset: Offset(0, 10))],
                    ),
                    child: Icon(Icons.calculate_rounded, color: scheme.primary, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text('NekoCalc', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: scheme.onSurface)),
                  const SizedBox(height: 4),
                  Text('v1.0.0-beta.1  Beta 预览版', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
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
                      const Icon(Icons.privacy_tip_outlined, size: 18, color: Color(0xFF23B45D)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('数据当前仅保存在本机 SQLite，不上传网络服务。', style: TextStyle(color: scheme.onSurfaceVariant))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => _showInfo('开源结构', '项目采用 Feature-first + Clean Architecture 简化版：UI、Application、Domain、Data、Core 分层维护。'), child: const Text('架构')),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('完成')),
        ],
      ),
    );
  }

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
        ],
      ),
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
      child: Text(label, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
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
          if (value.isNotEmpty) Text(value, style: TextStyle(color: scheme.onSurfaceVariant)),
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
