import '../../../domain/usecases/recent_tool_action_result.dart';
import 'tools_strings.dart';

/// 中文：**最近使用回执的翻译处——领域层给令牌，这里给字。**
///
///       `RecentToolActionResult` 从前自己拼那五句话并直接上屏（`tools_home_page.dart` 里两个
///       `SnackBar` 印 `result.message`），于是英文界面下它照样印中文：领域对象活得比界面长，
///       界面那张按语言切的表够不着它（`docs/verification.md` §5i）。现在那五句话住在
///       [ToolsStrings] 里，由这个函数在**呈现边缘**按令牌取——取表的语言就是屏幕的语言。
///
///       **形状照的是已经转过的四条路径**：`calculatorSubmitMessage(result, strings)`、
///       `calculatorSaveNoteMessage(result, strings)`、`toolSaveMessage(result, strings)` 与
///       `notesImportMessage(result, strings)`（令牌在领域层，字在呈现层的表里）。
///
///       **表与令牌都由调用方给**，所以这个文件里一个中文字面量都没有——它因此落在
///       `tools_source_guard_test.dart` 那条"工具子树源码里除了各文案表再没有中文字符串字面量"的
///       扫描范围里，而不是像 `tools_strings.dart` 那样被跳过。
///
///       **加一种结局时这里编译不过**：`switch` 穷尽 [RecentToolActionStatus]。
/// English: **where a recently-used receipt is translated — the domain hands over the token, this hands
///          over the words.**
///
///          `RecentToolActionResult` used to compose those five sentences itself and print them
///          straight (two `SnackBar`s in `tools_home_page.dart` printed `result.message`), so an
///          English interface still printed Chinese: a domain object outlives the UI and a
///          language-keyed interface table cannot reach it (`docs/verification.md` §5i). Those
///          sentences now live in [ToolsStrings], fetched **at the presentation edge** by this
///          function, keyed by the token — the language of the table is the language on screen.
///
///          **The shape is copied from the four converted paths**:
///          `calculatorSubmitMessage(result, strings)`, `calculatorSaveNoteMessage(result, strings)`,
///          `toolSaveMessage(result, strings)` and `notesImportMessage(result, strings)` (token in the
///          domain layer, words in the presentation layer's table).
///
///          **Both the table and the token arrive as arguments**, so this file holds not one Chinese
///          literal — which puts it inside `tools_source_guard_test.dart`'s sweep ("no Chinese string
///          literal in the tools subtree other than the copy tables") rather than on the skip list
///          `tools_strings.dart` sits on.
///
///          **Adding an outcome breaks this at compile time**: the `switch` exhausts
///          [RecentToolActionStatus].
String recentToolActionMessage(
  RecentToolActionResult result,
  ToolsStrings strings,
) {
  return switch (result.status) {
    RecentToolActionStatus.removed =>
      strings.recentToolRemoved(result.toolTitle!),
    RecentToolActionStatus.notFound => strings.recentToolNotFound,
    RecentToolActionStatus.cleared =>
      strings.recentToolsCleared(result.affectedCount),
    RecentToolActionStatus.alreadyEmpty => strings.recentToolsAlreadyEmpty,
    // 中文：`failed` 是唯一需要第二个判据的一格：印「移除失败」还是「清空失败」由当时那条动作决定
    //       （`RecentToolAction`）。两个 `!` 不是偷懒——错误串由 `failed` 构造路径保证非空，见领域文件。
    // English: `failed` is the one cell needing a second verdict: whether it reads "remove failed" or
    //          "clear failed" is decided by the action that ran (`RecentToolAction`). The two `!`s are
    //          not laziness — the failed constructor guarantees a non-null error string (see the
    //          domain file).
    RecentToolActionStatus.failed => result.action == RecentToolAction.remove
        ? strings.recentToolRemoveFailed(result.errorMessage!)
        : strings.recentToolClearFailed(result.errorMessage!),
  };
}
