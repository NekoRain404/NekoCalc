import 'package:flutter/material.dart';

import 'application/app_settings.dart';
import 'core/constants/app_info.dart';
import 'data/local/app_database.dart';
import 'data/repositories/settings_repository.dart';
import 'l10n/app_language.dart';
import 'shared/presentation/app_shell.dart';
import 'shared/presentation/app_theme.dart';
import 'shared/presentation/calc_theme.dart';

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

  /// 中文：用户选中的基准主题。存进来前先经 `CalcTheme.resolve` 归一化——库里留着一个已删主题的
  ///       id 时，屏幕上必须是默认主题，而不是抛错或空白。
  /// English: The chosen base theme, normalised through `CalcTheme.resolve` before it is stored: a
  ///          deleted theme's id left in the database must render as the default theme rather than
  ///          throwing or leaving the screen blank.
  CalcTheme _calcTheme = CalcTheme.fallback;

  /// 中文：用户选中的界面语言，同样先归一化。
  /// English: The chosen UI language, also normalised first.
  AppLanguage _language = AppLanguage.fallback;

  AppSettings _settings = AppSettings.fallback;
  int _settingsLoadToken = 0;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  /// 中文：把一份刚落库的设置并进界面状态。三个派生值（明暗 / 配色 / 语言）与 `_settings` 一起
  ///       做变化判定，任一不同都要重建——只看 `_settings` 会漏掉"设置没变但归一化结果变了"
  ///       这类情况，反过来只看派生值又会漏掉设置页自己读的那几项。
  /// English: Folds a freshly loaded settings record into the UI state. The three derived values
  ///          (light/dark, palette, language) take part in the changed-check alongside `_settings`;
  ///          any difference rebuilds. Watching `_settings` alone would miss "settings unchanged but
  ///          a normalised value moved", and watching only the derived values would miss the items the
  ///          settings page reads itself.
  bool _applySettings(AppSettings settings) {
    final themeMode = _themeModeFromLabel(settings.themeModeLabel);
    final calcTheme = CalcTheme.resolve(settings.themeId);
    final language = AppLanguage.fromCode(settings.languageCode);
    if (settings == _settings &&
        themeMode == _themeMode &&
        identical(calcTheme, _calcTheme) &&
        language == _language) {
      return false;
    }
    setState(() {
      _settings = settings;
      _themeMode = themeMode;
      _calcTheme = calcTheme;
      _language = language;
    });
    return true;
  }

  Future<void> _loadTheme() async {
    final token = ++_settingsLoadToken;
    final settings = AppSettings.fromMap(await _settingsRepository.load());
    // 中文：设置没有变化时跳过整棵 MaterialApp 重建，减少启动和返回设置页的抖动。
    // English: Skip rebuilding the whole MaterialApp when settings are unchanged.
    if (!mounted || token != _settingsLoadToken) return;
    _applySettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppInfo.name,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      // 中文：两个作用域装在 **Navigator 之上**（`builder` 的 child 就是 Navigator），而不是装在
      //       `home:` 里。这是必须的：`Navigator.push` 压上来的路由——设置页正是其中之一——与
      //       `home` 是兄弟而非子孙，装在 `home` 里的作用域它们看不见，主题与语言的选择会在设置页
      //       自己身上失效（选完语言，设置页仍是旧语言）。`builder` 在这里是唯一正确的挂点。
      // English: Both scopes go **above the Navigator** (the `builder`'s child *is* the Navigator),
      //          not inside `home:`. That is required: a `Navigator.push`ed route — the settings page
      //          is one — is a sibling of `home`, not a descendant, so a scope inside `home` is
      //          invisible to it and the theme and language choices would fail on the very page that
      //          makes them (pick a language and the page would stay in the old one). `builder` is the
      //          only correct hook here.
      builder: (context, child) => AppLanguageScope(
        language: _language,
        child: CalcThemeScope(base: _calcTheme, child: child!),
      ),
      home: AppShell(
        db: _db,
        settings: _settings,
        onSettingsChanged: _reloadSettings,
        onThemeModeChanged: (label) =>
            setState(() => _themeMode = _themeModeFromLabel(label)),
        // 中文：主题与语言要**当场**生效：设置页是压在外壳上的路由，用户点完就看着它，等页面退出
        //       再刷新等于选择器没有反馈。两项都只是把内存里的选择换掉，落库由设置页自己完成。
        // English: Theme and language take effect **immediately**: the settings page is a route on top
        //          of the shell, so the user is looking at it right after tapping, and deferring the
        //          refresh until the page pops would leave the picker with no feedback. Both callbacks
        //          only swap the in-memory choice; the settings page persists it itself.
        onThemeChanged: (id) =>
            setState(() => _calcTheme = CalcTheme.resolve(id)),
        onLanguageChanged: (code) =>
            setState(() => _language = AppLanguage.fromCode(code)),
      ),
    );
  }

  /// 中文：`theme_mode` 是**持久化令牌**（`SettingsTokens`），不是标签。写成可翻译的字面量
  ///       会让这个 switch 在英文界面下全部落到 `ThemeMode.system`，而 `_applySettings` 的变化判定
  ///       仍认为"什么都没变"——静默失效，没有报错。
  /// English: `theme_mode` holds **persisted tokens** (`SettingsTokens`), not labels. Hard-coding
  ///          translatable literals here would make every arm fall through to `ThemeMode.system` in an
  ///          English UI while `_applySettings`' changed-check still reported "nothing changed" —
  ///          a silent failure with no error.
  ThemeMode _themeModeFromLabel(String? label) {
    return switch (label) {
      SettingsTokens.themeModeLight => ThemeMode.light,
      SettingsTokens.themeModeDark => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> _reloadSettings() async {
    final token = ++_settingsLoadToken;
    final settings = AppSettings.fromMap(await _settingsRepository.load());
    // 中文：设置页关闭后只在真实变化时刷新，避免页面栈回退时多余重绘。
    // English: Refresh after settings only when values changed to avoid unnecessary repaints.
    if (!mounted || token != _settingsLoadToken) return;
    _applySettings(settings);
  }
}
