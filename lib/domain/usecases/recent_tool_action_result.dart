enum RecentToolAction {
  remove,
  clear,
}

enum RecentToolActionStatus {
  removed,
  notFound,
  cleared,
  alreadyEmpty,
  failed,
}

class RecentToolActionResult {
  const RecentToolActionResult({
    required this.action,
    required this.status,
    required this.message,
    required this.affectedCount,
    this.errorMessage,
  });

  factory RecentToolActionResult.remove({
    required String toolTitle,
    required int affectedCount,
  }) {
    final normalizedCount = affectedCount < 0 ? 0 : affectedCount;
    if (normalizedCount == 0) {
      return const RecentToolActionResult(
        action: RecentToolAction.remove,
        status: RecentToolActionStatus.notFound,
        message: '这项最近使用已经不存在',
        affectedCount: 0,
      );
    }
    return RecentToolActionResult(
      action: RecentToolAction.remove,
      status: RecentToolActionStatus.removed,
      message: '已从最近使用移除「$toolTitle」',
      affectedCount: normalizedCount,
    );
  }

  factory RecentToolActionResult.clear({
    required int affectedCount,
  }) {
    final normalizedCount = affectedCount < 0 ? 0 : affectedCount;
    if (normalizedCount == 0) {
      return const RecentToolActionResult(
        action: RecentToolAction.clear,
        status: RecentToolActionStatus.alreadyEmpty,
        message: '最近使用已经是空的',
        affectedCount: 0,
      );
    }
    return RecentToolActionResult(
      action: RecentToolAction.clear,
      status: RecentToolActionStatus.cleared,
      message: '已清空 $normalizedCount 个最近工具',
      affectedCount: normalizedCount,
    );
  }

  RecentToolActionResult.failed({
    required RecentToolAction action,
    required Object error,
  }) : this(
          action: action,
          status: RecentToolActionStatus.failed,
          message: action == RecentToolAction.remove
              ? '移除最近使用失败：$error'
              : '清空最近使用失败：$error',
          affectedCount: 0,
          errorMessage: error.toString(),
        );

  final RecentToolAction action;
  final RecentToolActionStatus status;
  final String message;
  final int affectedCount;
  final String? errorMessage;

  bool get succeeded => status != RecentToolActionStatus.failed;

  bool get changed =>
      status == RecentToolActionStatus.removed ||
      status == RecentToolActionStatus.cleared;

  bool get needsAttention => status == RecentToolActionStatus.failed;
}
