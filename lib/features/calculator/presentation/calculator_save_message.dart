import '../../../domain/usecases/calculator_save_result.dart';
import 'calculator_strings.dart';

/// 中文：**保存笔记回执的翻译处——领域层给令牌，这里给字。**
///
///       `CalculatorSaveNoteResult` 从前自己拼那几句话并直接上屏（`calculator_page_sheets.dart` 的
///       `SnackBar` 印 `result.message`），于是英文界面下它照样印中文：领域对象活得比界面长，
///       界面那张按语言切的表够不着它（`docs/verification.md` §5i）。现在那几句话住在
///       [CalculatorStrings] 里，由这个函数在**呈现边缘**按令牌取——取表的语言就是屏幕的语言。
///       形状与 `calculatorSubmitMessage` 逐条相同（那一条照的是工具结果那条老路）。
///
///       **表与令牌都由调用方给**，所以这个文件里一个中文字面量都没有。
///
///       **加一种结局时这里编译不过**：`switch` 穷尽 [CalculatorSaveNoteStatus]。
/// English: **where a save-to-note receipt is translated — the domain hands over the token, this hands
///          over the words.**
///
///          `CalculatorSaveNoteResult` used to compose those sentences itself and print them straight
///          (`calculator_page_sheets.dart`'s `SnackBar` printed `result.message`), so an English
///          interface still printed Chinese: a domain object outlives the UI and a language-keyed
///          interface table cannot reach it (`docs/verification.md` §5i). The sentences now live in
///          [CalculatorStrings], fetched **at the presentation edge** by this function, keyed by the
///          token — the language of the table is the language on screen. The shape is item-for-item
///          `calculatorSubmitMessage`'s (which in turn copied the older tool-result road).
///
///          **Both the table and the token arrive as arguments**, so this file holds not one Chinese
///          literal.
///
///          **Adding an outcome breaks this at compile time**: the `switch` exhausts
///          [CalculatorSaveNoteStatus].
String calculatorSaveNoteMessage(
  CalculatorSaveNoteResult result,
  CalculatorStrings strings,
) {
  return switch (result.status) {
    CalculatorSaveNoteStatus.saved => strings.saveNoteSaved,
    CalculatorSaveNoteStatus.emptyExpression => strings.saveNoteEmptyExpression,
    // 中文：`!` 不是偷懒：`errorMessage` 由构造方保证非空——`invalidExpression` 与 `failed` 两个
    //       命名构造是仅有的入口，无名构造是私有的（见那个文件）。真要是有人绕过去，这里立刻抛，
    //       而不是印出半句话「表达式需要修正：」。
    // English: the `!` is not laziness: the constructor guarantees a non-null `errorMessage` — the
    //          `invalidExpression` and `failed` named constructors are the only ways in and the unnamed
    //          one is private (see that file). Should somebody get around it, this throws at once
    //          rather than printing half a sentence ("表达式需要修正：").
    CalculatorSaveNoteStatus.invalidExpression =>
      strings.saveNoteInvalidExpression(result.errorMessage!),
    // 中文：**两条令牌、一格文案。** `superseded` 与 `notWritten` 在屏幕上是同一句话（理由写在
    //       领域层那一格上），所以指着同一格——将来改文案也只改一处，两条路不会各自漂。
    // English: **two tokens, one copy cell.** `superseded` and `notWritten` are the same sentence on
    //          screen (the reason is on that value in the domain layer), so they point at one cell —
    //          a future copy edit touches one place and the two routes cannot drift apart.
    CalculatorSaveNoteStatus.notWritten => strings.saveNoteNotWritten,
    CalculatorSaveNoteStatus.superseded => strings.saveNoteNotWritten,
    CalculatorSaveNoteStatus.failed =>
      strings.saveNoteFailed(result.errorMessage!),
  };
}
