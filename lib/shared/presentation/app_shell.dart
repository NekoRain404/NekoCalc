import 'package:flutter/material.dart';

import '../../application/app_settings.dart';
import '../../data/local/app_database.dart';
import '../../features/calculator/presentation/calculator_page.dart';
import '../../features/graph/presentation/graph_page.dart';
import '../../features/notes/presentation/notes_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/tools/presentation/tools_home_page.dart';

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
  int _calculatorReloadToken = 0;
  int _notesReloadToken = 0;
  int _toolsReloadToken = 0;
  int _graphReloadToken = 0;
  late final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(_fadeRoute(SettingsPage(
      db: widget.db,
      onThemeModeChanged: widget.onThemeModeChanged,
      onDataImported: _handleDataImported,
    )));
    await widget.onSettingsChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          itemBuilder: (context, index) {
            return _KeepAlivePage(child: _pageFor(index));
          },
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

  Widget _pageFor(int index) {
    return switch (index) {
      0 => CalculatorPage(
          db: widget.db,
          onOpenSettings: _openSettings,
          settings: widget.settings,
          reloadToken: _calculatorReloadToken),
      1 => ToolsHomePage(
          db: widget.db,
          settings: widget.settings,
          reloadToken: _toolsReloadToken),
      2 => GraphPage(
          db: widget.db,
          restoreState: widget.settings.restoreState,
          reloadToken: _graphReloadToken),
      3 => NotesPage(db: widget.db, reloadToken: _notesReloadToken),
      _ => const SizedBox.shrink(),
    };
  }

  void _selectDestination(int value) {
    if (value == _index) return;
    setState(() {
      _index = value;
      if (value == 3) _notesReloadToken++;
    });
    _pageController.animateToPage(
      value,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleDataImported() async {
    await widget.onSettingsChanged();
    if (!mounted) return;
    setState(() {
      _calculatorReloadToken++;
      _notesReloadToken++;
      _toolsReloadToken++;
      _graphReloadToken++;
    });
  }

  PageRouteBuilder<void> _fadeRoute(Widget page) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                    .animate(animation),
            child: child,
          ),
        );
      },
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}
