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
      // 中文：导航从底部栏换成侧边抽屉；无论是计算页自己画的 ☰，还是外壳浮在其余三页上的 ☰，
      //       打开的都是这一个抽屉。
      // English: Navigation moved from the bottom bar to a side drawer; whether it is the calculator's
      //          own ☰ or the one the shell floats over the other three pages, both open this drawer.
      drawer: AppDrawer(
        selectedIndex: _index,
        // 中文：抽屉的四项就是四个页面索引，直接复用切页逻辑，不多一层映射。
        // English: The drawer's four entries are page indices, so they share the page-switching logic
        //          instead of going through another mapping layer.
        onSelect: _selectDestination,
        onOpenSettings: _openSettings,
      ),
      // 中文：Flutter 的抽屉拖拽区默认只有 20dp（`_kEdgeDragWidth`），整条都落在系统返回手势的
      //       区域里，在那个设备上从 x=0 起滑只会退出 App。加宽到 64dp，让大部分拖拽区落在系统
      //       手势区之外；这只是兜底——真正保证回得来的是下面那个看得见的 ☰。
      // English: Flutter's drawer drag strip is only 20dp wide (`_kEdgeDragWidth`), which sits inside
      //          the system back-gesture region — on that device a swipe starting at x=0 just exits the
      //          app. Widened to 64dp so most of the strip lies outside it. This is only a fallback:
      //          the visible ☰ below is what actually guarantees the way back.
      drawerEdgeDragWidth: 64,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, index) {
                return _KeepAlivePage(child: _pageFor(index));
              },
            ),
            // 中文：计算页之外的三页没有自己的 ☰（那三页不归本任务改，笔记页还压着用户的未提交
            //       工作），所以由外壳在它们上面浮一个：否则用户点进「工具」就再也回不到计算页——
            //       拖拽又会被系统返回手势抢走。计算页不渲染它，那里已经有计算页自己的 ☰。
            // English: The three pages other than the calculator have no ☰ of their own (those files are
            //          out of scope here, and the notes page carries the user's uncommitted work), so the
            //          shell floats one over them: without it, tapping 工具 strands the user away from the
            //          calculator with no way back — the drag strip loses to the system back gesture. It is
            //          not rendered on the calculator page, which already has that button.
            if (_index != AppDrawer.calculatorDestination)
              const Positioned(left: 8, top: 8, child: _ShellDrawerButton()),
          ],
        ),
      ),
    );
  }

  /// 中文：计算页的页面级导航（`HISTORY`、`CNST`、`CONV` 与四个进制胶囊）。目的地只有两个：
  ///       `'tools'` 切到工具页；`'history'` 切到笔记页——历史记录住在那一页，用户在那里自己挑
  ///       「历史」胶囊。笔记页内部的筛选没有对外入口（`NotesPage` 未暴露它的 tab），所以这里只
  ///       切页、不另造一条通往筛选的平行路径；等笔记页暴露入口后再把抽屉里的「历史」入口补回来。
  /// English: Page-level navigation from the calculator page (`HISTORY`, `CNST`, `CONV` and the four
  ///          base pills). There are exactly two destinations: `'tools'` switches to the toolbox;
  ///          `'history'` switches to the notes page, where history lives and the user picks the
  ///          「历史」 pill themselves. That page's inner filter has no external entry point
  ///          (`NotesPage` exposes no tab hook), so this switches pages rather than inventing a
  ///          parallel route into the filter; once the page exposes one, a 历史 entry can return to
  ///          the drawer and select it.
  void _navigate(String destination) {
    switch (destination) {
      case 'tools':
        _selectDestination(AppDrawer.toolsDestination);
      case 'history':
        _selectDestination(AppDrawer.notesDestination);
      default:
        // 中文：目的地只有这两个字符串。写错一个字母（'Tools'）不该被静默吞掉，让那颗键悄悄变死，
        //       所以开发期直接断言失败，把拼错的字符串喊出来。
        // English: Only these two destination strings exist. A typo such as 'Tools' must not be swallowed
        //          silently and leave that key dead without a signal, so development fails an assertion
        //          that names the offending string.
        assert(false, '未知的导航目的地 / unknown navigation destination: $destination');
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

/// 中文：外壳浮在非计算页左上角的 ☰，与计算页那个按钮同一个 tooltip，用户与测试都用同一句话找它。
///       配色来自应用主题（`Theme.of(context)`，即那三页自己用的 Material 主题），不写死任何色值；
///       它坐在可滚动的内容之上，所以用填充色按钮而不是一个裸图标，滚动时也看得清。
/// English: The ☰ the shell floats over the top-left of every non-calculator page; it carries the same
///          tooltip as the calculator's button, so users and tests find both by the same words. Its
///          colours come from the app theme (`Theme.of(context)` — the Material theme those three pages
///          themselves use) with no literal values, and it is a filled button rather than a bare icon
///          because page content scrolls underneath it.
class _ShellDrawerButton extends StatelessWidget {
  const _ShellDrawerButton();

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: '打开导航',
      onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
      icon: const Icon(Icons.menu),
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
