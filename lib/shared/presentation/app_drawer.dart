import 'package:flutter/material.dart';

import 'calc_theme.dart';

/// 中文：外壳的侧边抽屉，取代原来的底部导航栏。入口固定为 工具 / 笔记 / 历史 / 设置：
///       前三项是页面级目的地，经 `onSelect` 交回外壳处理（外壳与计算页的 `onNavigate` 共用同一套
///       目的地，所以「工具 / 历史」两条路径不会各走各的）；「设置」是独立的设置页路由。
/// English: The shell's navigation drawer, replacing the former bottom navigation bar. Its entries
///          are fixed at 工具 / 笔记 / 历史 / 设置: the first three are page-level destinations handed
///          back through `onSelect` (the shell shares one destination vocabulary with the calculator
///          page's `onNavigate`, so the 工具 and 历史 paths cannot drift apart); 设置 pushes the
///          settings route.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.selectedIndex,
    required this.onSelect,
    required this.onOpenSettings,
    super.key,
  });

  /// 中文：工具页在外壳页面集合里的索引（0 计算、1 工具、2 图形、3 笔记），也是本抽屉「工具」
  ///       入口的目的地编号。
  /// English: The toolbox page's index in the shell's page set (0 calculator, 1 toolbox, 2 graph,
  ///          3 notes) and the destination id of this drawer's 工具 entry.
  static const int toolsDestination = 1;

  /// 中文：笔记页在外壳页面集合里的索引，也是本抽屉「笔记」入口的目的地编号。
  /// English: The notes page's index in the shell's page set and the destination id of this
  ///          drawer's 笔记 entry.
  static const int notesDestination = 3;

  /// 中文：历史入口的目的地编号。历史记录住在笔记页里，所以「历史」与「笔记」指向同一页的不同视图，
  ///       它没有自己的页面索引（页面索引只到 3），因此单独编号——外壳据此把两个入口路由到不同动作，
  ///       而不是让「历史」变成「笔记」的复制品。
  ///       注意：笔记页内部的「历史」筛选目前没有对外入口（`NotesPage` 没有暴露它的 tab），
  ///       外壳只能切页；等笔记页暴露入口后再把这里补成真正的筛选切换。
  /// English: Destination id of the history entry. History lives on the notes page, so 历史 and 笔记
  ///          point at two views of one page; history has no page index of its own (page indices stop
  ///          at 3), hence its own id — the shell routes the two entries to different actions instead
  ///          of making 历史 a duplicate of 笔记. Note: the notes page's inner 「历史」 filter has no
  ///          external entry point yet (`NotesPage` exposes no tab hook), so the shell can only switch
  ///          pages; once such a hook exists this id gains the real filter switch.
  static const int historyDestination = 4;

  /// 中文：外壳当前页的索引，用于高亮对应入口。
  /// English: The shell's current page index, used to highlight the matching entry.
  final int selectedIndex;

  /// 中文：页面级目的地回调，收到 `toolsDestination` / `notesDestination` / `historyDestination`。
  /// English: Page-level destination callback; receives `toolsDestination`, `notesDestination` or
  ///          `historyDestination`.
  final ValueChanged<int> onSelect;

  /// 中文：打开设置页。
  /// English: Opens the settings page.
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = _calcTheme(context);
    return Drawer(
      // 中文：抽屉底色沿用键位区底色，抽屉与主屏是同一片机身，不再是两种色系拼接。
      // English: The drawer borrows the keypad panel's colour so drawer and main screen read as one
      //          body rather than two colour systems bolted together.
      backgroundColor: theme.keypadBackground,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
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
                    destination: notesDestination,
                    icon: Icons.article_outlined,
                    label: '笔记',
                  ),
                  _entry(
                    context,
                    theme,
                    destination: historyDestination,
                    icon: Icons.schedule,
                    label: '历史',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.keys.functionFg.withValues(alpha: 0.2)),
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

  /// 中文：配色一律取自 `CalcTheme`。主题选择还没接进设置页（列为后续工作），所以固定用默认主题
  ///       `roseCream`，只按平台明暗取它的深色变体——与计算页同一套取色方式。
  /// English: Every colour comes from `CalcTheme`. Theme selection is not wired into the settings page
  ///          yet (recorded as follow-up work), so the default theme `roseCream` is used, with its dark
  ///          variant chosen by the platform brightness — the same resolution the calculator page uses.
  CalcTheme _calcTheme(BuildContext context) {
    const theme = CalcTheme.roseCream;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? theme.dark
        : theme;
  }
}
