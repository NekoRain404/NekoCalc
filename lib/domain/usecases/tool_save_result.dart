enum ToolSaveTarget {
  history,
  note,
}

enum ToolSaveStatus {
  saved,
  inputInvalid,
  noResult,
  notWritten,
  failed,
}

class ToolSaveResult {
  const ToolSaveResult({
    required this.target,
    required this.status,
    required this.message,
    this.recordId,
    this.errorMessage,
  });

  factory ToolSaveResult.savedHistory(int historyId) {
    return ToolSaveResult(
      target: ToolSaveTarget.history,
      status: ToolSaveStatus.saved,
      message: '结果已保存到历史记录',
      recordId: historyId,
    );
  }

  factory ToolSaveResult.savedNote(int noteId) {
    return ToolSaveResult(
      target: ToolSaveTarget.note,
      status: ToolSaveStatus.saved,
      message: '已保存到笔记',
      recordId: noteId,
    );
  }

  ToolSaveResult.inputInvalid({
    required ToolSaveTarget target,
    required String summary,
  }) : this(
          target: target,
          status: ToolSaveStatus.inputInvalid,
          message: summary.trim().isEmpty ? '请先修正输入参数' : '请先修正输入参数：$summary',
        );

  ToolSaveResult.noResult(ToolSaveTarget target)
      : this(
          target: target,
          status: ToolSaveStatus.noResult,
          message: '没有可保存的计算结果',
        );

  ToolSaveResult.notWritten(ToolSaveTarget target)
      : this(
          target: target,
          status: ToolSaveStatus.notWritten,
          message:
              target == ToolSaveTarget.history ? '历史记录没有写入，请重试' : '笔记没有写入，请重试',
        );

  ToolSaveResult.failed({
    required ToolSaveTarget target,
    required Object error,
  }) : this(
          target: target,
          status: ToolSaveStatus.failed,
          message: target == ToolSaveTarget.history
              ? '保存历史失败：$error'
              : '保存笔记失败：$error',
          errorMessage: error.toString(),
        );

  final ToolSaveTarget target;
  final ToolSaveStatus status;
  final String message;
  final int? recordId;
  final String? errorMessage;

  bool get saved => status == ToolSaveStatus.saved;

  bool get needsAttention => !saved;
}
