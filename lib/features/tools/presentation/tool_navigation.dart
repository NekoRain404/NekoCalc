import 'package:flutter/material.dart';

import '../../../application/app_settings.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/tool_capabilities.dart';
import 'data_fit_tool_screen.dart';
import 'text_tool_detail_screen.dart';
import 'tool_detail_screen.dart';

/// 中文：**点开一个工具之后的唯一一条路由。** 三个终点，按工具自己的性质分：
///       `data_fit` 走它自己那屏、文本工具走 `TextToolDetailScreen`、其余走 `ToolDetailScreen`；
///       而 [ToolCapabilities.opensUnitSheet] 那一类（今天是 `unit_convert`）**不推路由**——
///       它的终点不在这棵子树里，在计算页那个单位面板上（`CalculatorPage._openUnitSheet`，
///       也就是键盘 `CONV` 打开的那一个，**只有那一份**）。
///
///       为什么把请求交出去而不是在这里 `push`：面板属于计算页，`showModalBottomSheet` 用的是
///       **提出请求的那个 context 的 Navigator**，而工具页与计算页共享外壳的那一个 Navigator——
///       在这里弹，弹出来的面板会悬在工具页上，插进去的记号却落在看不见的计算页表达式里。
///       所以这一类请求由外壳接住：它既认得工具页也认得计算页，先回到计算页，再让那一页弹面板。
///
///       [onOpenUnitSheet] 为空时这一类工具**是惰性的**——与 `CalculatorPage.onNavigate` 为空时
///       那几颗键是惰性的一样：**不虚构一个目标**，独立渲染工具页的既有测试不必新增参数。
///       真实 App 里由 `AppShell` 接上，接不上的话那张卡就是死的（`_pageFor` 的注释里写着同一句）。
/// English: **the one route a tool takes when opened.** Three destinations, decided by the tool's own
///          properties: `data_fit` gets its own screen, text tools get `TextToolDetailScreen`, the rest
///          get `ToolDetailScreen`; and the [ToolCapabilities.opensUnitSheet] class (today
///          `unit_convert`) **pushes no route** — its destination is not in this subtree but on the
///          calculator page's unit sheet (`CalculatorPage._openUnitSheet`, the one the keypad's `CONV`
///          opens, and **the only copy**).
///
///          Why the request is handed out rather than pushed here: the sheet belongs to the calculator
///          page, and `showModalBottomSheet` uses **the Navigator of the context that asks** — the tools
///          pages and the calculator share the shell's one Navigator, so a sheet raised here would hang
///          over the tools page while the tokens it inserts land in an expression the user cannot see.
///          The shell catches this class of request instead: it knows both pages, so it returns to the
///          calculator first and lets that page raise the sheet.
///
///          With no [onOpenUnitSheet] this class of tool **is inert** — exactly as `CalculatorPage`'s
///          keys are inert with no `onNavigate`: **no destination is invented**, and the existing tests
///          that render the tools pages on their own need no new argument. The real app wires it in
///          `AppShell`; without that wiring the card would be dead (the same sentence as `_pageFor`'s).
Future<void> openToolDetail({
  required BuildContext context,
  required AppDatabase db,
  required ToolDefinition tool,
  required AppSettings settings,
  VoidCallback? onOpenUnitSheet,
}) {
  if (tool.opensUnitSheet) {
    onOpenUnitSheet?.call();
    return Future<void>.value();
  }
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) {
        if (tool.id == 'data_fit') {
          return DataFitToolScreen(db: db, tool: tool, settings: settings);
        }
        return tool.usesTextDetail
            ? TextToolDetailScreen(db: db, tool: tool, settings: settings)
            : ToolDetailScreen(db: db, tool: tool, settings: settings);
      },
    ),
  );
}
