import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/recent_tool_action_result.dart';

void main() {
  test('remove result distinguishes removed and missing tools', () {
    final removed = RecentToolActionResult.remove(
      toolTitle: 'JSON格式化',
      affectedCount: 1,
    );
    final missing = RecentToolActionResult.remove(
      toolTitle: 'JSON格式化',
      affectedCount: 0,
    );

    expect(removed.status, RecentToolActionStatus.removed);
    expect(removed.changed, isTrue);
    expect(removed.message, contains('JSON格式化'));
    expect(missing.status, RecentToolActionStatus.notFound);
    expect(missing.succeeded, isTrue);
    expect(missing.changed, isFalse);
  });

  test('clear result reports affected count or empty list', () {
    final cleared = RecentToolActionResult.clear(affectedCount: 3);
    final empty = RecentToolActionResult.clear(affectedCount: 0);

    expect(cleared.status, RecentToolActionStatus.cleared);
    expect(cleared.changed, isTrue);
    expect(cleared.message, contains('3'));
    expect(empty.status, RecentToolActionStatus.alreadyEmpty);
    expect(empty.succeeded, isTrue);
    expect(empty.changed, isFalse);
  });

  test('failed result keeps action and error detail', () {
    final result = RecentToolActionResult.failed(
      action: RecentToolAction.clear,
      error: StateError('db locked'),
    );

    expect(result.status, RecentToolActionStatus.failed);
    expect(result.succeeded, isFalse);
    expect(result.needsAttention, isTrue);
    expect(result.errorMessage, contains('db locked'));
  });
}
