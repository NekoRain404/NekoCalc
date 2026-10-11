import 'package:flutter/material.dart';

import '../../application/app_settings.dart';
import '../../data/local/app_database.dart';
import '../../features/calculator/presentation/calculator_page.dart';
import '../../features/graph/presentation/graph_page.dart';
import '../../features/notes/presentation/notes_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/tools/presentation/tool_result_label_strings.dart';
import '../../features/tools/presentation/tools_home_page.dart';
import 'app_drawer.dart';
import 'shared_strings.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.db,
    required this.settings,
    required this.onSettingsChanged,
    required this.onThemeModeChanged,
    this.onThemeChanged,
    this.onLanguageChanged,
    super.key,
  });

  final AppDatabase db;
  final AppSettings settings;
  final Future<void> Function() onSettingsChanged;
  final ValueChanged<String> onThemeModeChanged;

  /// 中文：配色选择（`CalcTheme.id`）与语言选择（`AppLanguage.code`）的实时回调，转交给设置页。
  ///       可选：不接时设置页仍会正常落库，只是要等退出设置页后由 `onSettingsChanged` 一次性刷新。
  ///       单独渲染 `AppShell` 的既有测试因此不必新增参数。
  /// English: Live callbacks for the palette (`CalcTheme.id`) and language (`AppLanguage.code`)
  ///          choices, forwarded to the settings page. Optional: without them the page still persists
  ///          both, they just only take effect when the page pops and `onSettingsChanged` refreshes.
  ///          The existing tests that render `AppShell` on its own therefore need no new arguments.
  final ValueChanged<String>? onThemeChanged;
  final ValueChanged<String>? onLanguageChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

/// 中文：外壳浮在左上角的 ☰ 占掉的高度——按钮 40 + 上边距 8 + 下边距 8。非计算页的内容整体
///       下移这么多，自己那一行起点就在 ☰ 下方。
/// English: Height taken by the shell's floating ☰ — 40 button + 8 above + 8 below. Non-calculator
///          pages are shifted down by it so their first row starts below the button.
const double _shellDrawerButtonBand = 56;

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _calculatorReloadToken = 0;
  int _calculatorOpenUnitsToken = 0;
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
      onThemeChanged: widget.onThemeChanged,
      onLanguageChanged: widget.onLanguageChanged,
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
                final page = _pageFor(context, index);
                return _KeepAlivePage(
                  // 中文：非计算页整体下移 _shellDrawerButtonBand，让出 ☰ 的那条带子。三页都在
                  //       (16,16) 起笔，其中笔记页多选态的「取消选择」（36×36，落在 (16,16)-(52,52)）
                  //       最靠上，所以以它为准留出余量：内容从 y=56 起，与 ☰ 的下沿（y=48）差 8dp，
                  //       再叠上页面自己的 16dp 内边距，实际间距 24dp。计算页不缩进——它的显示区
                  //       与键盘竖排本来就有高度下限，缩进会挤压键盘。
                  // English: Non-calculator pages are shifted down by _shellDrawerButtonBand to give the
                  //          ☰ its own band. All three start their content at (16,16); the notes page's
                  //          multi-select 「取消选择」 (36×36 at (16,16)-(52,52)) is the topmost control,
                  //          so it sets the margin: content starts at y=56, 8dp below the ☰'s bottom edge
                  //          (y=48), and the page's own 16dp padding brings the real gap to 24dp. The
                  //          calculator page is not inset — its display band and keypad already have
                  //          height floors, and an inset would squeeze the keypad.
                  child: index == AppDrawer.calculatorDestination
                      ? page
                      : Padding(
                          padding:
                              const EdgeInsets.only(top: _shellDrawerButtonBand),
                          child: page,
                        ),
                );
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
  ///       `'tools'` 切到工具页；`'history'` 切到笔记页——历史记录住在那一页。
  ///       **`HISTORY` 键的已知缺口（刻意保留）**：它只切页，**不**替用户选中笔记页的「历史」胶囊，
  ///       落点就是笔记页的默认筛选。原因有两层：`NotesPage` 没有暴露它的 tab（没有对外入口，
  ///       见 `notes_page.dart`），而那个文件上压着用户尚未提交的工作，本分支不得改动它。
  ///       所以这里不另造一条通往筛选的平行路径；等笔记页给出入口，再让 `'history'` 顺带选中胶囊，
  ///       并把抽屉入口独立出来（抽屉现在只有四个页面入口，没有单独的「历史」，与计划书原来的
  ///       四项清单不同——见计划书的完成标准）。
  /// English: Page-level navigation from the calculator page (`HISTORY`, `CNST`, `CONV` and the four
  ///          base pills). There are exactly two destinations: `'tools'` switches to the toolbox and
  ///          `'history'` switches to the notes page, where history lives.
  ///          **Known, deliberate gap on the `HISTORY` key**: it only switches pages — it does *not*
  ///          select the notes page's 「历史」 pill for the user, so the landing view is that page's
  ///          default filter. Two reasons: `NotesPage` exposes no tab hook (see `notes_page.dart`), and
  ///          that file carries the user's own uncommitted work, which this branch must not touch. So no
  ///          parallel route into the filter is invented here; once the page exposes one, `'history'` can
  ///          also select the pill and the drawer can gain a 历史 entry of its own (the drawer today has
  ///          only the four page entries and no separate 历史 — unlike the four-item list the plan first
  ///          specified; see the plan's completion criteria).
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

  Widget _pageFor(BuildContext context, int index) {
    return switch (index) {
      // 中文：外壳必须接上 `onNavigate`（它在计算页是可选的、默认惰性）：不接的话 `HISTORY`/`CNST`/
      //       `CONV` 与四个进制胶囊在真实 App 里永远是死的。`HISTORY` 落到笔记页但不会替用户选中
      //       那页的「历史」胶囊——原因见 `_navigate` 的注释。
      // English: The shell must wire `onNavigate` (it is optional and inert by default on the
      //          calculator page): without it `HISTORY`/`CNST`/`CONV` and the four base pills stay dead
      //          in the real app. `HISTORY` lands on the notes page but does not select that page's
      //          「历史」 pill for the user — see `_navigate` for why.
      0 => CalculatorPage(
          db: widget.db,
          onOpenSettings: _openSettings,
          settings: widget.settings,
          reloadToken: _calculatorReloadToken,
          openUnitsToken: _calculatorOpenUnitsToken,
          onNavigate: _navigate),
      1 => ToolsHomePage(
          db: widget.db,
          settings: widget.settings,
          reloadToken: _toolsReloadToken,
          // 中文：目录里 `unit_convert` 那张卡的终点在本页而不是在工具子树里，见 `_openUnitSheet`
          //       与 `tool_navigation.dart`。
          // English: the destination of the catalogue's `unit_convert` card is this page rather than
          //          the tools subtree — see `_openUnitSheet` and `tool_navigation.dart`.
          onOpenUnitSheet: _openUnitSheet),
      2 => GraphPage(
          db: widget.db,
          restoreState: widget.settings.restoreState,
          reloadToken: _graphReloadToken),
      3 => NotesPage(
          db: widget.db,
          reloadToken: _notesReloadToken,
          // 中文：工具标签的英文表住在本子树里，笔记页读不到它（features 之间不互相 import）。
          //       外壳是唯一同时认得两边的地方，所以由它把这条查表能力递下去。中文界面下
          //       `ToolResultLabelStrings.of` 是空表、查不到就原样返回，这一格一个字节不动。
          // English: the tools' English label table lives in that subtree and the notes page cannot
          //          read it (features do not import one another). The shell is the only place that
          //          knows both, so it hands this lookup down. In the Chinese interface
          //          `ToolResultLabelStrings.of` is empty and a miss returns its argument, so this
          //          cell does not move by a byte.
          toolResultLabel:
              ToolResultLabelStrings.of(context).label),
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

  /// 中文：**工具目录里 `unit_convert` 那张卡的落点：回计算页，把单位面板弹出来。**
  ///
  ///       三件事，各有一条理由：
  ///         · **先弹掉压在外壳上的路由**（分类页是从工具首页推上来的）。面板由计算页提出，
  ///           而全 App 只有外壳这一个 Navigator——不先回到外壳，面板会盖在分类页上，
  ///           插进表达式里的记号却落在用户看不见的计算页里。
  ///         · **切到计算页并 +1 那个令牌**（`CalculatorPage.openUnitsToken`）。计数而不是布尔：
  ///           连点两次也要弹两次，而值没变的重建不该再弹一次。
  ///         · **面板本身一次都不在这里提**。它由计算页的 `_openUnitSheet()` 打开——
  ///           与键盘 `CONV` 是同一个方法。**外壳只负责把用户送到那一页**，
  ///           所以这里没有第二份 `showModalBottomSheet`、没有第二份单位表。
  /// English: **where the catalogue's `unit_convert` card lands: back to the calculator, with the unit
  ///          sheet raised.**
  ///
  ///          Three moves, one reason each:
  ///            · **pop whatever covers the shell first** (the category page is pushed from the tools
  ///              home). The sheet is raised by the calculator page and the app has exactly one
  ///              Navigator — without returning to the shell the sheet would hang over the category page
  ///              while the tokens it inserts land in an expression the user cannot see.
  ///            · **switch to the calculator and bump that token** (`CalculatorPage.openUnitsToken`). A
  ///              counter rather than a boolean: two taps in a row must raise it twice, while a rebuild
  ///              that does not change the value must not raise it again.
  ///            · **the sheet itself is never raised here.** The calculator page's `_openUnitSheet()`
  ///              opens it — the same method the keypad's `CONV` calls. **The shell only gets the user to
  ///              that page**, so there is no second `showModalBottomSheet` and no second unit table.
  void _openUnitSheet() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    setState(() {
      _index = AppDrawer.calculatorDestination;
      _calculatorOpenUnitsToken++;
    });
    _pageController.animateToPage(
      AppDrawer.calculatorDestination,
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
///       它画在一条专用带子上——非计算页的内容被整体下移 `_shellDrawerButtonBand`，所以按钮下方
///       没有内容滚过（该带子之前的说法「页面内容会在其下滚动」已不成立），用填充色按钮是为了与
///       裸图标相比有明确的边界，浅色主题下也看得清。
///       点击范围收窄成 40×40（与计算页状态行的 ☰ 同一做法）：Material 默认把命中区补到 48×48，
///       那个看不见的 48 方块会越界压住页面自己的控件——笔记页多选态的「取消选择」就落在里面。
/// English: The ☰ the shell floats over the top-left of every non-calculator page; it carries the same
///          tooltip as the calculator's button, so users and tests find both by the same words. Its
///          colours come from the app theme (`Theme.of(context)` — the Material theme those three pages
///          themselves use) with no literal values, and it is a filled rather than bare icon because
///          that gives it a visible edge on a light theme. It does **not** sit over scrolling content:
///          the non-calculator pages are inset by `_shellDrawerButtonBand`, which reserved the band for
///          it (the band was added after that claim, so the earlier "content scrolls underneath" no
///          longer holds). Its hit area is narrowed to 40×40 (the same move the calculator's status-row
///          ☰ makes): Material pads the target out to 48×48 by default, and that invisible 48 box
///          reaches into the page's own controls — the notes page's multi-select 「取消选择」 used to sit
///          inside it.
class _ShellDrawerButton extends StatelessWidget {
  const _ShellDrawerButton();

  /// 中文：按钮边长，与计算页状态行的 ☰ 同尺寸。
  /// English: Button edge, the same size as the calculator status row's ☰.
  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: SharedStrings.of(context).openNavigationTooltip,
      onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
      icon: const Icon(Icons.menu),
      iconSize: 20,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: _size, height: _size),
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
