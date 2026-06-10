import 'package:flutter/material.dart';

import 'application/app_settings.dart';
import 'core/constants/app_info.dart';
import 'data/local/app_database.dart';
import 'data/repositories/settings_repository.dart';
import 'shared/presentation/app_shell.dart';
import 'shared/presentation/app_theme.dart';

class NekoCalcApp extends StatefulWidget {
  const NekoCalcApp({super.key, this.db});

  final AppDatabase? db;

  @override
  State<NekoCalcApp> createState() => _NekoCalcAppState();
}

class _NekoCalcAppState extends State<NekoCalcApp> {
  late final AppDatabase _db = widget.db ?? AppDatabase.instance;
  late final SettingsRepository _settingsRepository = SettingsRepository(_db);
  ThemeMode _themeMode = ThemeMode.system;
  AppSettings _settings = AppSettings.fallback;
  int _settingsLoadToken = 0;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final token = ++_settingsLoadToken;
    final settings = AppSettings.fromMap(await _settingsRepository.load());
    final themeMode = _themeModeFromLabel(settings.themeModeLabel);
    // 中文：设置没有变化时跳过整棵 MaterialApp 重建，减少启动和返回设置页的抖动。
    // English: Skip rebuilding the whole MaterialApp when settings are unchanged.
    if (!mounted ||
        token != _settingsLoadToken ||
        (settings == _settings && themeMode == _themeMode)) {
      return;
    }
    setState(() {
      _settings = settings;
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppInfo.name,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: AppShell(
        db: _db,
        settings: _settings,
        onSettingsChanged: _reloadSettings,
        onThemeModeChanged: (label) =>
            setState(() => _themeMode = _themeModeFromLabel(label)),
      ),
    );
  }

  ThemeMode _themeModeFromLabel(String? label) {
    return switch (label) {
      '浅色' => ThemeMode.light,
      '深色' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> _reloadSettings() async {
    final token = ++_settingsLoadToken;
    final settings = AppSettings.fromMap(await _settingsRepository.load());
    final themeMode = _themeModeFromLabel(settings.themeModeLabel);
    // 中文：设置页关闭后只在真实变化时刷新，避免页面栈回退时多余重绘。
    // English: Refresh after settings only when values changed to avoid unnecessary repaints.
    if (!mounted ||
        token != _settingsLoadToken ||
        (settings == _settings && themeMode == _themeMode)) {
      return;
    }
    setState(() {
      _settings = settings;
      _themeMode = themeMode;
    });
  }
}
