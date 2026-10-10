import '../../../domain/usecases/calculator_submit_result.dart';
import 'calculator_strings.dart';

/// 中文：**提交回执的翻译处——领域层给令牌，这里给字。**
///
///       `CalculatorSubmitResult` 从前自己拼那八句话并直接上屏（`calculator_key_dispatch.dart` 的
///       `SnackBar` 印 `result.message`），于是英文界面下它照样印中文：领域对象活得比界面长，
///       界面那张按语言切的表够不着它（`docs/verification.md` §5i）。现在那八句话住在
///       [CalculatorStrings] 里，由这个函数在**呈现边缘**按令牌取——取表的语言就是屏幕的语言。
///
///       **形状照的是既有的两条**：`toolResultConclusion(results, label)`（工具结果那条：
///       判据读产出方写下的令牌）与 `CalculatorPasteResult.summaryIn(strings)` /
///       `NumericInputParseResult.issueMessage(strings)`（粘贴与数值输入那两条：字由调用方把表
///       递进来）。这里两者合一：令牌在领域层，字在呈现层的表里。
///
///       **表与令牌都由调用方给**，所以这个文件里一个中文字面量都没有——它因此落在
///       `calculator_strings_test.dart` 第 3 条那条"计算页源码里除了文案表再没有中文字符串
///       字面量"的扫描范围里，而不是像两张表那样被跳过。
///
///       **加一种结局时这里编译不过**：`switch` 穷尽 [CalculatorSubmitStatus]。
/// English: **where a submit receipt is translated — the domain hands over the token, this hands over
///          the words.**
///
///          `CalculatorSubmitResult` used to compose those eight sentences itself and print them
///          straight (`calculator_key_dispatch.dart`'s `SnackBar` printed `result.message`), so an
///          English interface still printed Chinese: a domain object outlives the UI and a
///          language-keyed interface table cannot reach it (`docs/verification.md` §5i). The eight
///          sentences now live in [CalculatorStrings], fetched **at the presentation edge** by this
///          function, keyed by the token — the language of the table is the language on screen.
///
///          **The shape is copied from two existing ones**: `toolResultConclusion(results, label)` (the
///          tool-result path: the judgement reads the token the producer wrote) and
///          `CalculatorPasteResult.summaryIn(strings)` / `NumericInputParseResult.issueMessage(strings)`
///          (the paste and numeric-input paths: the caller hands the table in). This joins the two: the
///          token is in the domain layer, the words are in the presentation layer's table.
///
///          **Both the table and the token arrive as arguments**, so this file holds not one Chinese
///          literal — which puts it inside clause 3 of `calculator_strings_test.dart` ("no Chinese
///          string literal in the calculator page's sources other than the copy tables") rather than on
///          the skip list the two tables sit on.
///
///          **Adding an outcome breaks this at compile time**: the `switch` exhausts
///          [CalculatorSubmitStatus].
String calculatorSubmitMessage(
  CalculatorSubmitResult result,
  CalculatorStrings strings,
) {
  return switch (result.status) {
    CalculatorSubmitStatus.emptyExpression => strings.submitEmptyExpression,
    // 中文：`!` 不是偷懒：`errorMessage` 由构造方保证非空——`invalidExpression` 与
    //       `historyFailed` 两个命名构造是仅有的入口，无名构造是私有的（见那个文件）。
    //       真要是有人绕过去，这里立刻抛，而不是印出半句话「表达式需要修正：」——
    //       这个仓库反复吃过的亏正是"什么都没做"与"做成了"在屏幕上长得一样。
    // English: the `!` is not laziness: the constructor guarantees a non-null `errorMessage` — the
    //          `invalidExpression` and `historyFailed` named constructors are the only ways in and the
    //          unnamed one is private (see that file). Should somebody get around it, this throws at
    //          once rather than printing half a sentence ("表达式需要修正：") — the loss this
    //          repository has eaten repeatedly is exactly "did nothing" and "did it" looking alike on
    //          screen.
    CalculatorSubmitStatus.invalidExpression =>
      strings.submitInvalidExpression(result.errorMessage!),
    CalculatorSubmitStatus.calculated => strings.submitCalculated,
    CalculatorSubmitStatus.historySaved => strings.submitHistorySaved,
    CalculatorSubmitStatus.historySkippedDuplicate =>
      strings.submitHistorySkippedDuplicate,
    CalculatorSubmitStatus.historyNotWritten => strings.submitHistoryNotWritten,
    CalculatorSubmitStatus.historyFailed =>
      strings.submitHistoryFailed(result.errorMessage!),
    CalculatorSubmitStatus.superseded => strings.submitSuperseded,
  };
}
