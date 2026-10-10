/// 中文：**一次提交的结局，以及它自带的载荷——这里一个字都不给用户看。**
///
///       这个对象原先自己拼那八句话（`'请输入表达式后再计算'`、`'已计算并保存到历史'`、
///       `'已计算，但保存历史失败：$error'`…），而它们真的会上屏：`calculator_key_dispatch.dart`
///       的 `SnackBar` 直接印 `result.message`。**领域对象活得比界面长**，界面那张按语言切的文案表
///       够不着它，所以那八句话在任何界面语言下都是中文——`docs/verification.md` §5i 记着这条
///       层次性缺陷。
///
///       现在的形状是**判断与文案分家**：
///       - **判断是 [status]**（[CalculatorSubmitStatus]），八种结局与从前的八句话一一对应；
///         加一种结局时呈现层那个 `switch` 编译不过，而不是静默印一句别的话。
///       - **文案在 `CalculatorStrings` 里**（呈现层那张表，两种语言并排、缺一种编译不过），
///         由 `calculatorSubmitMessage(result, strings)` 在**呈现边缘**取用。形状照的是既有的
///         两条：工具结果那条（`ToolResult.conclusion` + `toolResultConclusion`）与粘贴回执那条
///         （`CalculatorPasteResult.summaryIn`）。
///
///       **两个载荷格为什么还是 `String`**：它们不是这里拼的句子，是**调用方递进来的数据**。
///       `errorMessage` 由控制器经它自己的表（`CalculatorControllerStrings`）翻好再递进来，
///       或者是一句异常的 `toString()`（两种语言里同一个技术串）。它们已经跟着语言走，
///       并且要让呈现层拼进句子里（`'表达式需要修正：$errorMessage'`），所以留作载荷。
/// English: **the outcome of one submit, with its payloads — and not one word here is shown to a
///          user.**
///
///          This object used to compose its own eight sentences (`'请输入表达式后再计算'`,
///          `'已计算并保存到历史'`, `'已计算，但保存历史失败：$error'` …), and they really did reach
///          the screen: the `SnackBar` in `calculator_key_dispatch.dart` printed `result.message`
///          straight. **A domain object outlives the UI**, a widget-level strings table cannot reach
///          it, so those eight sentences were Chinese under every interface language — the layering
///          defect recorded in `docs/verification.md` §5i.
///
///          The shape is now **verdict and wording parted**:
///          - **the verdict is [status]** ([CalculatorSubmitStatus]), eight outcomes one for one with
///            the eight old sentences; adding one breaks the presentation-side `switch` at compile
///            time rather than quietly printing some other sentence.
///          - **the words are in `CalculatorStrings`** (the presentation table, both languages side by
///            side with a missing one a compile error), read **at the presentation edge** by
///            `calculatorSubmitMessage(result, strings)`. The shape is copied from two existing ones:
///            the tool-result path (`ToolResult.conclusion` + `toolResultConclusion`) and the paste
///            receipt (`CalculatorPasteResult.summaryIn`).
///
///          **Why the two payload slots are still `String`s**: they are not sentences composed here
///          but **data handed in by the caller**. `errorMessage` is translated by the controller
///          through its own table (`CalculatorControllerStrings`) before it arrives, or is an
///          exception's `toString()` (one technical string in either language). They already follow
///          the language and have to be spliced into a sentence at the presentation edge
///          (`'表达式需要修正：$errorMessage'`), so they stay payloads.
library;

/// 中文：**这一次提交是八种结局里的哪一种——它既是判据，也是呈现层取那句话用的令牌。**
///
///       每一格与 `CalculatorStrings` 里的一格一一对应（`submitEmptyExpression` …
///       `submitSuperseded`），由 `calculatorSubmitMessage` 那个穷尽 `switch` 接上；两个
///       `needsAttention` 为真的载荷格（`invalidExpression` / `historyFailed`）另外把
///       [CalculatorSubmitResult.errorMessage] 递进句子里。
///
///       **与 `CalculatorSubmitResult.submitted` / `savedToHistory` / `needsAttention` 的分工**：
///       那三个 getter 回答的是「这次提交算不算数、要不要打扰用户」，是**行为**判据；
///       这一格回答的是「回执说的是哪一件事」，是**文案**判据。两者都由这一个字段回答，
///       所以它们不可能对不上。
/// English: **which of the eight outcomes this submit is — a verdict, and the token the presentation
///          layer resolves the sentence with.**
///
///          Each value corresponds one for one with a cell in `CalculatorStrings`
///          (`submitEmptyExpression` … `submitSuperseded`), wired up by the exhaustive `switch` in
///          `calculatorSubmitMessage`; the two payload-bearing outcomes whose `needsAttention` is true
///          (`invalidExpression` / `historyFailed`) additionally hand
///          [CalculatorSubmitResult.errorMessage] into the sentence.
///
///          **How it divides work with `CalculatorSubmitResult.submitted` / `savedToHistory` /
///          `needsAttention`**: those three getters answer "does this submit count, and does it
///          disturb the user" — **behaviour** verdicts; this value answers "which thing the receipt is
///          about" — the **copy** verdict. One field answers both, so the two cannot disagree.
enum CalculatorSubmitStatus {
  emptyExpression,
  invalidExpression,
  calculated,
  historySaved,
  historySkippedDuplicate,
  historyNotWritten,
  historyFailed,

  /// 中文：这一次提交在引擎往返期间被更新的输入取代了，结果没有被采用（状态、Ans/last、
  ///       持久化与历史都没有被碰）。
  /// English: This submit was overtaken by newer input during the engine round trip, so its result
  ///          was not adopted (state, Ans/last, persistence and history were all left alone).
  superseded,
}

class CalculatorSubmitResult {
  /// 中文：**无名构造是私有的**：`status` 与两个载荷格必须一起合法（`invalidExpression` 与
  ///       `historyFailed` 各要求一个非空 `errorMessage`），而呈现层读载荷时用的是 `!`。
  ///       留一个公开的无名构造，就等于留一条「令牌说 invalidExpression、载荷却是 null」的路，
  ///       那条路上屏幕会印出半句话（`'表达式需要修正：'`）或者崩掉——两种都不该由调用方决定。
  /// English: **the unnamed constructor is private**: `status` and the two payload slots have to be
  ///          legal together (`invalidExpression` and `historyFailed` each require a non-null
  ///          `errorMessage`), and the presentation layer reads the payload with `!`. A public unnamed
  ///          constructor would leave a road where the token says `invalidExpression` while the payload
  ///          is null — down that road the screen prints half a sentence (`'表达式需要修正：'`) or
  ///          throws, and neither is a caller's decision to make.
  const CalculatorSubmitResult._({
    required this.status,
    this.expression,
    this.result,
    this.historyId,
    this.errorMessage,
  });

  const CalculatorSubmitResult.emptyExpression()
      : this._(
          status: CalculatorSubmitStatus.emptyExpression,
          expression: null,
          result: null,
          historyId: null,
          errorMessage: null,
        );

  CalculatorSubmitResult.invalidExpression(String errorMessage)
      : this._(
          status: CalculatorSubmitStatus.invalidExpression,
          expression: null,
          result: null,
          historyId: null,
          errorMessage: errorMessage,
        );

  const CalculatorSubmitResult.calculated({
    required String expression,
    required String result,
  }) : this._(
          status: CalculatorSubmitStatus.calculated,
          expression: expression,
          result: result,
        );

  const CalculatorSubmitResult.historySaved({
    required String expression,
    required String result,
    required int historyId,
  }) : this._(
          status: CalculatorSubmitStatus.historySaved,
          expression: expression,
          result: result,
          historyId: historyId,
        );

  const CalculatorSubmitResult.historySkippedDuplicate({
    required String expression,
    required String result,
  }) : this._(
          status: CalculatorSubmitStatus.historySkippedDuplicate,
          expression: expression,
          result: result,
        );

  const CalculatorSubmitResult.historyNotWritten({
    required String expression,
    required String result,
  }) : this._(
          status: CalculatorSubmitStatus.historyNotWritten,
          expression: expression,
          result: result,
        );

  CalculatorSubmitResult.historyFailed({
    required String expression,
    required String result,
    required Object error,
  }) : this._(
          status: CalculatorSubmitStatus.historyFailed,
          expression: expression,
          result: result,
          errorMessage: error.toString(),
        );

  /// 中文：这一次提交的结果**没有**被采用——引擎回包到达时用户已经改了输入，或者控制器已经
  ///       销毁。它既没有计算结果可以展示，也没有历史可以保存，所以不打扰用户（[needsAttention]
  ///       为假）：屏幕上已经是更新那条边打边算的结果，那才是正确的显示。
  /// English: This submit's result was *not* adopted — the engine reply landed after the user had
  ///          edited, or after the controller was disposed. There is no calculation to show and no
  ///          history to save, so the user is not disturbed ([needsAttention] is false): the newer
  ///          as-you-type result is already on screen, and that is the correct display.
  const CalculatorSubmitResult.superseded()
      : this._(
          status: CalculatorSubmitStatus.superseded,
          expression: null,
          result: null,
          historyId: null,
          errorMessage: null,
        );

  final CalculatorSubmitStatus status;
  final String? expression;
  final String? result;
  final int? historyId;

  /// 中文：递给呈现层的载荷（不是这里拼的句子）：`invalidExpression` 时是控制器翻好的那句
  ///       出错原因，`historyFailed` 时是异常的 `toString()`；两个命名构造保证这两支里它非空。
  /// English: the payload handed to the presentation layer (not a sentence composed here): the
  ///          controller's translated reason for `invalidExpression`, an exception's `toString()` for
  ///          `historyFailed`; the two named constructors guarantee it is non-null in those two
  ///          branches.
  final String? errorMessage;

  /// 中文：这一次提交是否有结果被采用。`superseded` 不算——它的结果被丢掉了，历史也没有写。
  ///       （写成正向列举而不是「不是空表达式也不是无效表达式」，是因为新状态默认属于哪一边必须
  ///       有人明说，否则它会被一个语法上的否定悄悄归到「已提交」那边。）
  /// English: Whether this submit adopted a result. `superseded` does not count — its result was
  ///          dropped and no history was written. (This is a positive list rather than "not empty
  ///          and not invalid" because a new status has to be placed on a side deliberately, or a
  ///          syntactic negation quietly files it under "submitted".)
  bool get submitted =>
      status == CalculatorSubmitStatus.calculated ||
      status == CalculatorSubmitStatus.historySaved ||
      status == CalculatorSubmitStatus.historySkippedDuplicate ||
      status == CalculatorSubmitStatus.historyNotWritten ||
      status == CalculatorSubmitStatus.historyFailed;

  bool get savedToHistory => status == CalculatorSubmitStatus.historySaved;

  bool get needsAttention =>
      status == CalculatorSubmitStatus.emptyExpression ||
      status == CalculatorSubmitStatus.invalidExpression ||
      status == CalculatorSubmitStatus.historyNotWritten ||
      status == CalculatorSubmitStatus.historyFailed;
}
