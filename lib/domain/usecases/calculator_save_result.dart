enum CalculatorSaveNoteStatus {
  saved,
  emptyExpression,
  invalidExpression,
  notWritten,
  failed,
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
