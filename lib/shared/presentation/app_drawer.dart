import 'package:flutter/material.dart';

import 'calc_theme.dart';

/// 中文：外壳的侧边抽屉，取代原来的底部导航栏。它按页顺序列出**全部**可达页面——计算 / 工具 /
///       图形 / 笔记——外加底部的设置：底部栏没了以后，任何一页都不能因为「抽屉里没有它」而变成
///       死路（键盘区不响应翻页，走进去就出不来的页面等于把 App 卡死）。
///       「设置」不是页面集合里的一页（是压在栈上的路由），所以单独放在底部分隔线下方。
/// English: The shell's navigation drawer, replacing the former bottom navigation bar. It lists every
///          reachable page in page order — 计算 / 工具 / 图形 / 笔记 — plus 设置 at the bottom: with
///          the bottom bar gone, no page may become a dead end just because the drawer forgot it (the
///          keypad refuses page swipes, so a page you cannot leave bricks the app). 设置 is not one of
///          the pages (it is a route pushed on top), so it sits alone below the divider.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.selectedIndex,
    required this.onSelect,
    required this.onOpenSettings,
    super.key,
  });

  /// 中文：四个页面在 `AppShell` 页面集合里的索引，同时就是本抽屉对应入口的目的地编号。
  /// English: The four pages' indices in the shell's page set — which are also the destination ids of
  ///          the matching drawer entries.
  static const int calculatorDestination = 0;
  static const int toolsDestination = 1;
  static const int graphDestination = 2;
  static const int notesDestination = 3;

  /// 中文：外壳当前页的索引，用于高亮对应入口。
  /// English: The shell's current page index, used to highlight the matching entry.
  final int selectedIndex;

  /// 中文：页面级目的地回调，收到上面四个页面索引之一。
  /// English: Page-level destination callback; receives one of the four page indices above.
  final ValueChanged<int> onSelect;

  /// 中文：打开设置页。
  /// English: Opens the settings page.
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    return Drawer(
      // 中文：抽屉底色沿用键位区底色，抽屉与主屏是同一片机身，不再是两种色系拼接。
      // English: The drawer borrows the keypad panel's colour so drawer and main screen read as one
      //          body rather than two colour systems bolted together.
      backgroundColor: theme.keypadBackground,
      // 中文：五项都在同一个滚动视图里——「设置」如果留在滚动区之外，大字号 + 矮屏（横屏）时这一列
      //       就会溢出；放进列表后它能跟着滚。
      // English: All five entries live in one scroll view — were 设置 left outside the scrollable, the
      //          column would overflow at large text scale on a short (landscape) screen; inside the
      //          list it scrolls with the rest.
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _entry(
              context,
              theme,
              destination: calculatorDestination,
              icon: Icons.calculate_outlined,
              label: '计算',
            ),
            _entry(
              context,
              theme,
              destination: toolsDestination,
              icon: Icons.construction_outlined,
              label: '工具',
            ),
            _entry(
              context,
              theme,
              destination: graphDestination,
              icon: Icons.show_chart_outlined,
              label: '图形',
            ),
            _entry(
              context,
              theme,
              destination: notesDestination,
              icon: Icons.article_outlined,
              label: '笔记',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Divider(
                height: 1,
                color: theme.keys.functionFg.withValues(alpha: 0.2),
              ),
            ),
            _settingsEntry(context, theme),
          ],
        ),
      ),
    );
  }

  /// 中文：导航区的一项。选中态用强调色，未选中沿用函数键的键面配色——两对颜色都是主题里配好对比度的。
  /// English: One navigation entry: the selected one takes the accent pair, the others the function
  ///          key's surface pair — both pairs ship with their own contrast in the theme.
  Widget _entry(
    BuildContext context,
    CalcTheme theme, {
    required int destination,
    required IconData icon,
    required String label,
  }) {
    final selected = selectedIndex == destination;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        selected: selected,
        onTap: () => _close(context, () => onSelect(destination)),
        leading: Icon(icon),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        iconColor: theme.keys.functionFg,
        textColor: theme.keys.functionFg,
        selectedColor: theme.keys.accentFg,
        tileColor: theme.keys.functionBg,
        selectedTileColor: theme.keys.accentBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  /// 中文：设置入口。它不是页面集合里的一页（是压在栈上的路由），所以永不处于选中态。
  /// English: The settings entry is not one of the pages (it is a route pushed on top), so it is
  ///          never selected.
  Widget _settingsEntry(BuildContext context, CalcTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: ListTile(
        onTap: () => _close(context, onOpenSettings),
        leading: const Icon(Icons.settings_outlined),
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.w700)),
        iconColor: theme.keys.functionFg,
        textColor: theme.keys.functionFg,
        tileColor: theme.keys.functionBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  /// 中文：先关抽屉再执行动作，否则抽屉会停在切过去的页面上。
  /// English: Close the drawer before running the action, otherwise it lingers over the new page.
  void _close(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }
}
