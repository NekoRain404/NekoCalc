import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/notes_delete_result.dart';

void main() {
  test('delete result summarizes deleted and missing records', () {
    const result = NotesDeleteResult(
      requestedHistoryCount: 2,
      requestedNoteCount: 1,
      deletedHistoryCount: 1,
      deletedNoteCount: 0,
    );

    expect(result.requestedCount, 3);
    expect(result.deletedCount, 1);
    expect(result.missingCount, 2);
    expect(result.hasDeletedRecords, isTrue);
    expect(result.message, '已删除 1 条历史，2 项未找到或已被删除');
  });

  test('empty delete result reports no selected records', () {
    final result = NotesDeleteResult.none();

    expect(result.message, '没有选择要删除的记录');
  });
}
