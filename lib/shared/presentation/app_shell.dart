import 'package:flutter/material.dart';

import '../../application/app_settings.dart';
import '../../data/local/app_database.dart';
import '../../features/calculator/presentation/calculator_page.dart';
import '../../features/graph/presentation/graph_page.dart';
import '../../features/notes/presentation/notes_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/tools/presentation/tools_home_page.dart';
import 'app_drawer.dart';

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
      // 中文：导航从底部栏换成侧边抽屉；主屏左上角的 ☰（由计算页渲染）打开的就是它。
      // English: Navigation moved from the bottom bar to a side drawer; the ☰ rendered by the
      //          calculator page opens exactly this one.
      drawer: AppDrawer(
        selectedIndex: _index,
        onSelect: _openDestination,
        onOpenSettings: _openSettings,
      ),
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
    );
  }

  /// 中文：抽屉入口的目的地。编号与 `AppDrawer` 共用，避免抽屉与计算页各立一套映射。
  /// English: Destinations from the drawer, using `AppDrawer`'s ids so the drawer and the calculator
  ///          page cannot drift into two different mappings.
  void _openDestination(int destination) {
    switch (destination) {
      case AppDrawer.toolsDestination:
        _selectDestination(AppDrawer.toolsDestination);
      case AppDrawer.notesDestination:
        _selectDestination(AppDrawer.notesDestination);
      case AppDrawer.historyDestination:
        _navigate('history');
    }
  }

  /// 中文：计算页的页面级导航（`HISTORY`、`CNST`、`CONV` 与四个进制胶囊）。目的地只有两个：
  ///       `'tools'` 切到工具页；`'history'` 切到笔记页——历史记录住在那一页。
  ///       笔记页内部的「历史」筛选没有对外入口（`NotesPage` 未暴露它的 tab），所以这里只切页、
  ///       不另造一条通往筛选的平行路径；等笔记页暴露入口后在此补上。
  /// English: Page-level navigation from the calculator page (`HISTORY`, `CNST`, `CONV` and the four
  ///          base pills). There are exactly two destinations: `'tools'` switches to the toolbox;
  ///          `'history'` switches to the notes page, where history lives. That page's inner 「历史」
  ///          filter has no external entry point (`NotesPage` exposes no tab hook), so this switches
  ///          pages rather than inventing a parallel route into the filter; it gains the filter once
  ///          the page exposes one.
  void _navigate(String destination) {
    switch (destination) {
      case 'tools':
        _selectDestination(AppDrawer.toolsDestination);
      case 'history':
        _selectDestination(AppDrawer.notesDestination);
    }
  }

  Widget _pageFor(int index) {
    return switch (index) {
      0 => CalculatorPage(
          db: widget.db,
          onOpenSettings: _openSettings,
          settings: widget.settings,
          reloadToken: _calculatorReloadToken,
          onNavigate: _navigate),
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
