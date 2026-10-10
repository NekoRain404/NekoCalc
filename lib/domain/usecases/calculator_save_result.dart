/// 中文：**一次「保存到笔记」的结局，以及它自带的载荷——这里一个字都不给用户看。**
///
///       这个对象原先自己拼那几句话（`'已保存到笔记'`、`'请输入有效表达式后再保存'`、
///       `'表达式需要修正：$errorMessage'`、`'笔记没有写入，请重试'`、`'保存笔记失败：$error'`），
///       而它们真的会上屏：`calculator_page_sheets.dart` 的 `SnackBar` 直接印 `result.message`。
///       **领域对象活得比界面长**，界面那张按语言切的文案表够不着它，所以那几句话在任何界面语言下
///       都是中文——`docs/verification.md` §5i 记着这条层次性缺陷。
///
///       现在的形状是**判断与文案分家**（照的是提交路径那一条，而它也照的是工具结果那条老路：
///       `ToolResult.conclusion` + `toolResultConclusion`）：
///       - **判断是 [status]**（[CalculatorSaveNoteStatus]），六种结局与从前的六句话一一对应；
///         加一种结局时呈现层那个 `switch` 编译不过，而不是静默印一句别的话。
///       - **文案在 `CalculatorStrings` 里**（呈现层那张表），由
///         `calculatorSaveNoteMessage(result, strings)` 在**呈现边缘**取用。
///
///       **两个载荷格为什么还是 `String`**：它们不是这里拼的句子，是**调用方递进来的数据**——
///       `invalidExpression` 接的是控制器经自己的表（`CalculatorControllerStrings`）翻好的出错原因，
///       `failed` 接的是异常的 `toString()`（两种语言里同一个技术串）；`noteId` 是写库回执，屏幕不读。
///       呈现层要把它们拼进句子里（`'表达式需要修正：$errorMessage'`），所以留作载荷。
/// English: **the outcome of one "save to a note", with its payloads — and not one word here is shown
///          to a user.**
///
///          This object used to compose its own sentences (`'已保存到笔记'`,
///          `'请输入有效表达式后再保存'`, `'表达式需要修正：$errorMessage'`, `'笔记没有写入，请重试'`,
///          `'保存笔记失败：$error'`), and they really did reach the screen: the `SnackBar` in
///          `calculator_page_sheets.dart` printed `result.message` straight. **A domain object
///          outlives the UI**, a widget-level strings table cannot reach it, so those sentences were
///          Chinese under every interface language — the layering defect recorded in
///          `docs/verification.md` §5i.
///
///          The shape is now **verdict and wording parted** (copied from the submit path, which itself
///          copied the older tool-result road: `ToolResult.conclusion` + `toolResultConclusion`):
///          - **the verdict is [status]** ([CalculatorSaveNoteStatus]), six outcomes one for one with
///            the six old sentences; adding one breaks the presentation-side `switch` at compile time
///            rather than quietly printing some other sentence.
///          - **the words are in `CalculatorStrings`** (the presentation table), read **at the
///            presentation edge** by `calculatorSaveNoteMessage(result, strings)`.
///
///          **Why the payload slots are still `String`s**: they are not sentences composed here but
///          **data handed in by the caller** — `invalidExpression` receives the controller's reason
///          translated through its own table (`CalculatorControllerStrings`), `failed` an exception's
///          `toString()` (one technical string in either language); `noteId` is the write receipt and
///          is not read by the screen. The presentation edge splices them into a sentence
///          (`'表达式需要修正：$errorMessage'`), so they stay payloads.
library;

/// 中文：**这一次保存是六种结局里的哪一种——它既是判据，也是呈现层取那句话用的令牌。**
///
///       每一格与 `CalculatorStrings` 里的一格一一对应（`saveNoteSaved` … `saveNoteFailed`），由
///       `calculatorSaveNoteMessage` 那个穷尽 `switch` 接上；`invalidExpression` 与 `failed` 另外把
///       [CalculatorSaveNoteResult.errorMessage] 递进句子里。
///
///       **`notWritten` 与 [superseded] 故意共用同一句话**：对用户来说两件事该做的是同一件
///       （再按一次），而原因（一次引擎往返被更新的输入取代）不是他需要看见的东西——所以呈现层
///       那两格指向同一个文案格，将来也不会各自漂。
/// English: **which of the six outcomes this save is — a verdict, and the token the presentation layer
///          resolves the sentence with.**
///
///          Each value corresponds one for one with a cell in `CalculatorStrings`
///          (`saveNoteSaved` … `saveNoteFailed`), wired up by the exhaustive `switch` in
///          `calculatorSaveNoteMessage`; `invalidExpression` and `failed` additionally hand
///          [CalculatorSaveNoteResult.errorMessage] into the sentence.
///
///          **`notWritten` and [superseded] deliberately share one sentence**: the two are the same
///          thing to the user, who should do the same thing either way (press again), and the cause (an
///          engine round trip overtaken by newer input) is not something they need to see — so the two
///          presentation arms point at one copy cell and cannot drift apart later.
enum CalculatorSaveNoteStatus {
  saved,
  emptyExpression,
  invalidExpression,
  notWritten,
  failed,

  /// 中文：这次保存在引擎往返期间被更新的输入取代了——结果没有被采用，笔记也没有写。
  ///       与 [CalculatorSubmitStatus.superseded] 同一条规则：过期的那条时间线上什么都不许落地。
  /// English: This save was overtaken by newer input during the engine round trip, so its result was
  ///          not adopted and no note was written. The same rule as
  ///          [CalculatorSubmitStatus.superseded]: nothing lands from a stale timeline.
  superseded,
}

class CalculatorSaveNoteResult {
  /// 中文：**无名构造是私有的**：`status` 与载荷格必须一起合法（`invalidExpression` 与 `failed`
  ///       各要求一个非空 `errorMessage`），而呈现层读载荷时用的是 `!`。留一个公开的无名构造，
  ///       就等于留一条「令牌说 invalidExpression、载荷却是 null」的路，那条路上屏幕会印出半句话
  ///       （`'表达式需要修正：'`）或者崩掉——两种都不该由调用方决定。
  /// English: **the unnamed constructor is private**: `status` and the payload slots have to be legal
  ///          together (`invalidExpression` and `failed` each require a non-null `errorMessage`), and
  ///          the presentation layer reads the payload with `!`. A public unnamed constructor would
  ///          leave a road where the token says `invalidExpression` while the payload is null — down
  ///          that road the screen prints half a sentence (`'表达式需要修正：'`) or throws, and neither
  ///          is a caller's decision to make.
  const CalculatorSaveNoteResult._({
    required this.status,
    this.noteId,
    this.errorMessage,
  });

  const CalculatorSaveNoteResult.saved(int noteId)
      : this._(
          status: CalculatorSaveNoteStatus.saved,
          noteId: noteId,
        );

  const CalculatorSaveNoteResult.emptyExpression()
      : this._(
          status: CalculatorSaveNoteStatus.emptyExpression,
          noteId: null,
          errorMessage: null,
        );

  CalculatorSaveNoteResult.invalidExpression(String errorMessage)
      : this._(
          status: CalculatorSaveNoteStatus.invalidExpression,
          noteId: null,
          errorMessage: errorMessage,
        );

  const CalculatorSaveNoteResult.notWritten()
      : this._(
          status: CalculatorSaveNoteStatus.notWritten,
          noteId: null,
          errorMessage: null,
        );

  /// 中文：保存期间表达式变了（或控制器已销毁），这次结果没有落地，也**没有**写笔记。屏幕上说的
  ///       与 [notWritten] 是同一句话——对用户来说「再按一次」就是对的做法，而原因（一次引擎往返
  ///       被更新的输入取代）不是他需要看见的东西。
  /// English: The expression changed during the save (or the controller was disposed), so this
  ///          result did not land and **no** note was written. On screen it says what [notWritten]
  ///          says — pressing the button again is the right thing to do, and the cause (an engine
  ///          round trip overtaken by newer input) is not something the user needs to see.
  const CalculatorSaveNoteResult.superseded()
      : this._(
          status: CalculatorSaveNoteStatus.superseded,
          noteId: null,
          errorMessage: null,
        );

  CalculatorSaveNoteResult.failed(Object error)
      : this._(
          status: CalculatorSaveNoteStatus.failed,
          noteId: null,
          errorMessage: error.toString(),
        );

  final CalculatorSaveNoteStatus status;
  final int? noteId;

  /// 中文：递给呈现层的载荷（不是这里拼的句子）：`invalidExpression` 时是控制器翻好的那句出错
  ///       原因，`failed` 时是异常的 `toString()`；两个命名构造保证这两支里它非空。
  /// English: the payload handed to the presentation layer (not a sentence composed here): the
  ///          controller's translated reason for `invalidExpression`, an exception's `toString()` for
  ///          `failed`; the two named constructors guarantee it is non-null in those two branches.
  final String? errorMessage;

  bool get saved => status == CalculatorSaveNoteStatus.saved;
}
