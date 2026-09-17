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
  const CalculatorSubmitResult({
    required this.status,
    required this.message,
    this.expression,
    this.result,
    this.historyId,
    this.errorMessage,
  });

  const CalculatorSubmitResult.emptyExpression()
      : status = CalculatorSubmitStatus.emptyExpression,
        message = '请输入表达式后再计算',
        expression = null,
        result = null,
        historyId = null,
        errorMessage = null;

  CalculatorSubmitResult.invalidExpression(String errorMessage)
      : status = CalculatorSubmitStatus.invalidExpression,
        message = '表达式需要修正：$errorMessage',
        expression = null,
        result = null,
        historyId = null,
        errorMessage = errorMessage;

  const CalculatorSubmitResult.calculated({
    required String expression,
    required String result,
  }) : this(
          status: CalculatorSubmitStatus.calculated,
          message: '已计算结果',
          expression: expression,
          result: result,
        );

  const CalculatorSubmitResult.historySaved({
    required String expression,
    required String result,
    required int historyId,
  }) : this(
          status: CalculatorSubmitStatus.historySaved,
          message: '已计算并保存到历史',
          expression: expression,
          result: result,
          historyId: historyId,
        );

  const CalculatorSubmitResult.historySkippedDuplicate({
    required String expression,
    required String result,
  }) : this(
          status: CalculatorSubmitStatus.historySkippedDuplicate,
          message: '已计算，重复历史已跳过',
          expression: expression,
          result: result,
        );

  const CalculatorSubmitResult.historyNotWritten({
    required String expression,
    required String result,
  }) : this(
          status: CalculatorSubmitStatus.historyNotWritten,
          message: '已计算，但历史没有写入，请重试',
          expression: expression,
          result: result,
        );

  CalculatorSubmitResult.historyFailed({
    required String expression,
    required String result,
    required Object error,
  }) : this(
          status: CalculatorSubmitStatus.historyFailed,
          message: '已计算，但保存历史失败：$error',
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
      : status = CalculatorSubmitStatus.superseded,
        message = '输入已更新，本次计算结果未采用',
        expression = null,
        result = null,
        historyId = null,
        errorMessage = null;

  final CalculatorSubmitStatus status;
  final String message;
  final String? expression;
  final String? result;
  final int? historyId;
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
