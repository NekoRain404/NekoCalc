class NotesDeleteResult {
  const NotesDeleteResult({
    required this.requestedHistoryCount,
    required this.requestedNoteCount,
    required this.deletedHistoryCount,
    required this.deletedNoteCount,
  });

  factory NotesDeleteResult.none() => const NotesDeleteResult(
        requestedHistoryCount: 0,
        requestedNoteCount: 0,
        deletedHistoryCount: 0,
        deletedNoteCount: 0,
      );

  final int requestedHistoryCount;
  final int requestedNoteCount;
  final int deletedHistoryCount;
  final int deletedNoteCount;

  int get requestedCount => requestedHistoryCount + requestedNoteCount;

  int get deletedCount => deletedHistoryCount + deletedNoteCount;

  int get missingCount {
    final missingHistory = requestedHistoryCount - deletedHistoryCount;
    final missingNotes = requestedNoteCount - deletedNoteCount;
    return [
      if (missingHistory > 0) missingHistory,
      if (missingNotes > 0) missingNotes,
    ].fold(0, (sum, count) => sum + count);
  }

  bool get hasDeletedRecords => deletedCount > 0;

  String get message {
    if (requestedCount == 0) return '没有选择要删除的记录';
    final parts = <String>[
      hasDeletedRecords ? '已删除 ${_countLabel()}' : '没有删除记录',
    ];
    if (missingCount > 0) {
      parts.add('$missingCount 项未找到或已被删除');
    }
    return parts.join('，');
  }

  String _countLabel() {
    final parts = <String>[
      if (deletedHistoryCount > 0) '$deletedHistoryCount 条历史',
      if (deletedNoteCount > 0) '$deletedNoteCount 条笔记',
    ];
    return parts.join('、');
  }
}
