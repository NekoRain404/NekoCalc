import '../../../domain/usecases/tool_save_result.dart';
import 'tools_strings.dart';

/// 中文：**工具保存回执的翻译处——领域层给令牌，这里给字。**
///
///       `ToolSaveResult` 从前自己拼那几句话并直接上屏（工具详情页、文本工具详情页、拟合页三处
///       `SnackBar` 都印 `result.message`），于是英文界面下它照样印中文：领域对象活得比界面长，
///       界面那张按语言切的表够不着它（`docs/verification.md` §5i）。现在那几句话住在
///       [ToolsStrings] 里，由这个函数在**呈现边缘**按令牌取——取表的语言就是屏幕的语言。
///       形状与 `calculatorSubmitMessage` / `calculatorSaveNoteMessage` / `toolResultConclusion`
///       同一套：令牌在领域层，字在呈现层的表里。
///
///       **令牌是一对已有的枚举**（[ToolSaveStatus] × [ToolSaveTarget]）：同一句话在两个去处上
///       写法不同的那三种（`saved` / `notWritten` / `failed`）由内层 `switch` 分派，两个
///       `switch` 都穷尽各自的枚举，加结局或加去处都在这里编译不过。`noResult` 与
///       `inputInvalid` 与去处无关，所以不套内层。
///
///       **`inputInvalid` 的句子形状（要不要那个冒号）在这里判**：判据是 `summary` 去掉空白后
///       是否为空，与领域层从前那位一个字都相同——**这是文案的形状，不是结局**，所以跟着字走。
///
///       **表与令牌都由调用方给**，所以这个文件里一个中文字面量都没有。
/// English: **where a tool-save receipt is translated — the domain hands over the token, this hands
///          over the words.**
///
///          `ToolSaveResult` used to compose those sentences itself and print them straight (three
///          `SnackBar`s — the tool detail screen, the text tool detail screen and the fit screen — all
///          printed `result.message`), so an English interface still printed Chinese: a domain object
///          outlives the UI and a language-keyed interface table cannot reach it
///          (`docs/verification.md` §5i). The sentences now live in [ToolsStrings], fetched **at the
///          presentation edge** by this function, keyed by the token — the language of the table is the
///          language on screen. The shape is the one `calculatorSubmitMessage` /
///          `calculatorSaveNoteMessage` / `toolResultConclusion` share: the token in the domain layer,
///          the words in the presentation layer's table.
///
///          **The token is a pair of enums that already existed** ([ToolSaveStatus] × [ToolSaveTarget]):
///          the three whose sentence differs per destination (`saved` / `notWritten` / `failed`) are
///          dispatched by the inner `switch`, and both `switch`es exhaust their enum — adding an outcome
///          or a destination breaks the build here. `noResult` and `inputInvalid` do not depend on the
///          destination, so they take no inner switch.
///
///          **The shape of the `inputInvalid` sentence (whether the colon is there) is decided here**:
///          the rule is whether `summary` is empty after trimming, character for character the one the
///          domain layer used — **this is the shape of the wording, not the outcome**, so it follows the
///          words.
///
///          **Both the table and the token arrive as arguments**, so this file holds not one Chinese
///          literal.
String toolSaveMessage(ToolSaveResult result, ToolsStrings strings) {
  return switch (result.status) {
    ToolSaveStatus.saved => switch (result.target) {
        ToolSaveTarget.history => strings.saveHistorySaved,
        ToolSaveTarget.note => strings.saveNoteSaved,
      },
    // 中文：`!` 不是偷懒：`summary` 由 `ToolSaveResult.inputInvalid` 这个命名构造保证非空，
    //       无名构造是私有的（见那个文件）。真要是有人绕过去，这里立刻抛，而不是印出半句话
    //       「请先修正输入参数：」。
    // English: the `!` is not laziness: the `ToolSaveResult.inputInvalid` named constructor guarantees
    //          a non-null `summary` and the unnamed one is private (see that file). Should somebody get
    //          around it, this throws at once rather than printing half a sentence
    //          ("请先修正输入参数：").
    ToolSaveStatus.inputInvalid => result.summary!.trim().isEmpty
        ? strings.fixInputsFirst
        : strings.fixInputsFirstWith(result.summary!),
    ToolSaveStatus.noResult => strings.saveNothingToStore,
    ToolSaveStatus.notWritten => switch (result.target) {
        ToolSaveTarget.history => strings.saveHistoryNotWritten,
        ToolSaveTarget.note => strings.saveNoteNotWritten,
      },
    ToolSaveStatus.failed => switch (result.target) {
        ToolSaveTarget.history => strings.saveHistoryFailed(result.errorMessage!),
        ToolSaveTarget.note => strings.saveNoteFailed(result.errorMessage!),
      },
  };
}
