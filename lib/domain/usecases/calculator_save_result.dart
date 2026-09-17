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
  const CalculatorSaveNoteResult({
    required this.status,
    required this.message,
    this.noteId,
    this.errorMessage,
  });

  factory CalculatorSaveNoteResult.saved(int noteId) {
    return CalculatorSaveNoteResult(
      status: CalculatorSaveNoteStatus.saved,
      message: '已保存到笔记',
      noteId: noteId,
    );
  }

  const CalculatorSaveNoteResult.emptyExpression()
      : status = CalculatorSaveNoteStatus.emptyExpression,
        message = '请输入有效表达式后再保存',
        noteId = null,
        errorMessage = null;

  CalculatorSaveNoteResult.invalidExpression(String errorMessage)
      : status = CalculatorSaveNoteStatus.invalidExpression,
        message = '表达式需要修正：$errorMessage',
        noteId = null,
        errorMessage = errorMessage;

  const CalculatorSaveNoteResult.notWritten()
      : status = CalculatorSaveNoteStatus.notWritten,
        message = '笔记没有写入，请重试',
        noteId = null,
        errorMessage = null;

  /// 中文：保存期间表达式变了（或控制器已销毁），这次结果没有落地，也**没有**写笔记。提示文案与
  ///       [notWritten] 同一个意思——对用户来说「再按一次」就是对的做法，而原因（一次引擎往返
  ///       被更新的输入取代）不是他需要看见的东西。
  /// English: The expression changed during the save (or the controller was disposed), so this
  ///          result did not land and **no** note was written. The message says what
  ///          [notWritten] says — pressing the button again is the right thing to do, and the cause
  ///          (an engine round trip overtaken by newer input) is not something the user needs to see.
  const CalculatorSaveNoteResult.superseded()
      : status = CalculatorSaveNoteStatus.superseded,
        message = '笔记没有写入，请重试',
        noteId = null,
        errorMessage = null;

  CalculatorSaveNoteResult.failed(Object error)
      : status = CalculatorSaveNoteStatus.failed,
        message = '保存笔记失败：$error',
        noteId = null,
        errorMessage = error.toString();

  final CalculatorSaveNoteStatus status;
  final String message;
  final int? noteId;
  final String? errorMessage;

  bool get saved => status == CalculatorSaveNoteStatus.saved;
}
