enum CalculatorSubmitStatus {
  emptyExpression,
  invalidExpression,
  calculated,
  historySaved,
  historySkippedDuplicate,
  historyNotWritten,
  historyFailed,
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

  final CalculatorSubmitStatus status;
  final String message;
  final String? expression;
  final String? result;
  final int? historyId;
  final String? errorMessage;

  bool get submitted =>
      status != CalculatorSubmitStatus.emptyExpression &&
      status != CalculatorSubmitStatus.invalidExpression;

  bool get savedToHistory => status == CalculatorSubmitStatus.historySaved;

  bool get needsAttention =>
      status == CalculatorSubmitStatus.emptyExpression ||
      status == CalculatorSubmitStatus.invalidExpression ||
      status == CalculatorSubmitStatus.historyNotWritten ||
      status == CalculatorSubmitStatus.historyFailed;
}
