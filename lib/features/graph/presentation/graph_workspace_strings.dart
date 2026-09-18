import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：图形工作区粘贴结果（`graph_workspace_paste.dart`）的界面文案表。
///       机制本身（手写分表、`static final`）与设置页那张表共用一套理由，写在
///       `settings_strings.dart` 的文件头上，这里不重抄。
///
///       **只有六条。** 那一族其余的中文都是**输入文法与判据**，刻意不进来：
///       `line == '图形数据'` / `'函数'` / `'视窗'` / `'标记'` / `'当前标记'` 判的是**用户粘贴进来的
///       文本**，`r'^(?:表达式|函数|function|expr|expression)\s*[:：]…'` 与
///       `(?:~|至|到|-)` 是解析它的形状，`line.contains('隐藏')` 判的是那条函数在源文本里有没有被
///       标成隐藏。把它们翻了，粘贴图形数据就再也读不懂了。
///
///       **为什么这个类有一个"没有上下文时用中文"的入口。** `GraphWorkspacePasteResult.summary`
///       是一个 **getter**，没有 `BuildContext`；它唯一的调用方是
///       `graph_page.dart`，而那个文件是另一位作者的未提交工作，本轮不许动。所以这一轮把表
///       建好、把六条中文搬进来，并留下 [summaryIn] 给下一轮接线——**图形页今天整页仍是中文**
///       （`graph_page.dart` 里还有 51 条），所以默认走中文不会让英文界面比现在更差。
///       下一轮要做的只有一件事：让 `graph_page.dart` 把 `GraphWorkspaceStrings.of(context)`
///       传给 `parseGraphWorkspacePasteText`。
/// English: The copy table for the graph-workspace paste result (`graph_workspace_paste.dart`). The
///          mechanism itself (hand-written tables, `static final`) shares one set of reasons with the
///          settings table and is written on `settings_strings.dart`'s file head; it is not copied
///          again here.
///
///          **Six entries only.** The rest of that family's Chinese is **input grammar and branch
///          conditions** and deliberately stays out: `line == '图形数据'` / `'函数'` / `'视窗'` /
///          `'标记'` / `'当前标记'` compare against **the text the user pasted**, and
///          `r'^(?:表达式|函数|function|expr|expression)\s*[:：]…'` and `(?:~|至|到|-)` describe its
///          shape, while `line.contains('隐藏')` asks whether that function was marked hidden in the
///          source text. Translate them and pasting graph data stops working.
///
///          **Why this class has a "Chinese when there is no context" entry point.**
///          `GraphWorkspacePasteResult.summary` is a **getter** and holds no `BuildContext`; its only
///          caller is `graph_page.dart`, which is another author's uncommitted work and must not be
///          touched this round. So this round builds the table, moves the six Chinese entries in, and
///          leaves [summaryIn] for the next round to wire up — **the graph page is still Chinese end
///          to end today** (51 more literals in `graph_page.dart`), so defaulting to Chinese does not
///          make the English interface any worse than it already is. The next round has one thing to
///          do: have `graph_page.dart` pass `GraphWorkspaceStrings.of(context)` into
///          `parseGraphWorkspacePasteText`.
@immutable
class GraphWorkspaceStrings {
  const GraphWorkspaceStrings({
    required this.noWorkspace,
    required this.fromFunctionText,
    required this.fromCopyText,
    required this.restored,
    required this.functionCount,
    required this.visibleCount,
  });

  /// 中文：剪贴板里什么都没认出来。
  /// English: Nothing in the clipboard was recognised.
  final String noWorkspace;
  final String fromFunctionText;
  final String fromCopyText;
  final String restored;
  final String Function(int count) functionCount;
  final String Function(int count) visibleCount;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`**.
  static GraphWorkspaceStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  static GraphWorkspaceStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => graphWorkspaceZh,
      AppLanguage.en => graphWorkspaceEn,
    };
  }

  static final GraphWorkspaceStrings graphWorkspaceZh = GraphWorkspaceStrings(
    noWorkspace: '剪贴板里没有识别到图形工作区',
    fromFunctionText: '已从函数文本创建工作区',
    fromCopyText: '已从图形数据恢复工作区',
    restored: '已恢复图形工作区',
    functionCount: (count) => '$count 个函数',
    visibleCount: (count) => '$count 个可见',
  );

  static final GraphWorkspaceStrings graphWorkspaceEn = GraphWorkspaceStrings(
    noWorkspace: 'No graph workspace recognised in the clipboard',
    fromFunctionText: 'Workspace created from function text',
    fromCopyText: 'Workspace restored from graph data',
    restored: 'Graph workspace restored',
    functionCount: (count) => '$count functions',
    visibleCount: (count) => '$count visible',
  );
}
