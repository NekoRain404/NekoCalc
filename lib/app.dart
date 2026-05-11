import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'application/app_settings.dart';
import 'data/local/app_database.dart';
import 'features/calculator/presentation/calculator_page.dart';
import 'features/graph/presentation/graph_page.dart';
import 'features/notes/presentation/notes_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/tools/presentation/tools_home_page.dart';
import 'shared/presentation/app_theme.dart';

class NekoCalcApp extends StatefulWidget {
  const NekoCalcApp({super.key});

  @override
  State<NekoCalcApp> createState() => _NekoCalcAppState();
}

class _NekoCalcAppState extends State<NekoCalcApp> {
  final AppDatabase _db = AppDatabase.instance;
  ThemeMode _themeMode = ThemeMode.system;
  AppSettings _settings = AppSettings.fallback;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final settings = AppSettings.fromMap(await _db.settings());
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
      title: 'NekoCalc',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: AppStartup(
        child: AppShell(
          db: _db,
          settings: _settings,
          onSettingsChanged: _reloadSettings,
          onThemeModeChanged: (label) => setState(() => _themeMode = _themeModeFromLabel(label)),
        ),
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
    final settings = AppSettings.fromMap(await _db.settings());
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _themeMode = _themeModeFromLabel(settings.themeModeLabel);
    });
  }
}

class AppStartup extends StatefulWidget {
  const AppStartup({required this.child, super.key});

  final Widget child;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: const Interval(0.15, 1, curve: Curves.easeOut));
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 1450), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _done ? widget.child : _splash(context),
    );
  }

  Widget _splash(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        key: const ValueKey('splash'),
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark ? const [Color(0xFF0F121A), Color(0xFF1B1A30)] : const [Color(0xFFF8FAFF), Color(0xFFEDEBFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: scheme.primary.withValues(alpha: dark ? 0.36 : 0.24)),
                        boxShadow: dark ? const [] : const [BoxShadow(color: Color(0x225B47FF), blurRadius: 32, offset: Offset(0, 14))],
                      ),
                      child: Icon(Icons.calculate_rounded, color: scheme.primary, size: 46),
                    ),
                    const SizedBox(height: 18),
                    Text('NekoCalc', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: scheme.onSurface)),
                    const SizedBox(height: 8),
                    Text('全能计算工具箱', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 26),
                    const SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 4)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.db,
    required this.settings,
    required this.onSettingsChanged,
    required this.onThemeModeChanged,
    super.key,
  });

  final AppDatabase db;
  final AppSettings settings;
  final Future<void> Function() onSettingsChanged;
  final ValueChanged<String> onThemeModeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restoreNavigationIndex();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.restoreState != widget.settings.restoreState && widget.settings.restoreState) {
      _restoreNavigationIndex();
    }
  }

  Future<void> _restoreNavigationIndex() async {
    if (!widget.settings.restoreState) return;
    final settings = await widget.db.settings();
    final restored = int.tryParse(settings['nav_index'] ?? '');
    if (!mounted || restored == null || restored < 0 || restored > 3) return;
    setState(() => _index = restored);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(_fadeRoute(SettingsPage(db: widget.db, onThemeModeChanged: widget.onThemeModeChanged)));
    await widget.onSettingsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CalculatorPage(db: widget.db, onOpenSettings: _openSettings, settings: widget.settings),
      ToolsHomePage(db: widget.db),
      const GraphPage(),
      NotesPage(db: widget.db),
    ];

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 70,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: '计算',
          ),
          NavigationDestination(
            icon: Icon(Icons.construction_outlined),
            selectedIcon: Icon(Icons.construction),
            label: '工具',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: '图形',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: '笔记',
          ),
        ],
      ),
    );
  }

  void _selectDestination(int value) {
    if (value == _index) return;
    if (widget.settings.haptics) HapticFeedback.selectionClick();
    setState(() => _index = value);
    if (widget.settings.restoreState) {
      widget.db.setSetting('nav_index', value.toString());
    }
  }

  PageRouteBuilder<void> _fadeRoute(Widget page) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
    );
  }
}
