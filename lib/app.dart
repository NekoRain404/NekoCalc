import 'package:flutter/material.dart';

import 'application/app_settings.dart';
import 'core/constants/app_info.dart';
import 'data/local/app_database.dart';
import 'data/repositories/settings_repository.dart';
import 'shared/presentation/app_shell.dart';
import 'shared/presentation/app_theme.dart';

class NekoCalcApp extends StatefulWidget {
  const NekoCalcApp({super.key});

  @override
  State<NekoCalcApp> createState() => _NekoCalcAppState();
}

class _NekoCalcAppState extends State<NekoCalcApp> {
  final AppDatabase _db = AppDatabase.instance;
  late final SettingsRepository _settingsRepository = SettingsRepository(_db);
  ThemeMode _themeMode = ThemeMode.system;
  AppSettings _settings = AppSettings.fallback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted) _loadTheme();
      });
    });
  }

  Future<void> _loadTheme() async {
    final settings = AppSettings.fromMap(await _settingsRepository.load());
    if (mounted) {
      setState(() {
        _settings = settings;
        _themeMode = _themeModeFromLabel(settings.themeModeLabel);
      });
    }
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
    final settings = AppSettings.fromMap(await _settingsRepository.load());
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _themeMode = _themeModeFromLabel(settings.themeModeLabel);
    });
  }
}
