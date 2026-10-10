import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/notes_delete_result.dart';
import 'package:nekocalc/features/notes/presentation/notes_receipt_message.dart';
import 'package:nekocalc/features/notes/presentation/notes_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：领域层只给令牌，句子在呈现边缘取——所以断言先把中文表取出来再逐条比。这里那两句中文是
///       迁移前 `NotesDeleteResult.message` 的抄本（逐字节相同另由 `notes_receipt_message_test.dart`
///       那张对照表与源码扫描一起钉住）。
/// English: The domain layer hands over tokens only and the sentences are fetched at the presentation
///          edge — so the assertions take the Chinese table first and compare one by one. The two
///          Chinese strings here are copies of `NotesDeleteResult.message` from before the move
///          (byte-identity is pinned separately by the table and the source scan in
///          `notes_receipt_message_test.dart`).
void main() {
  final zh = NotesStrings.forLanguage(AppLanguage.zh);

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
    expect(result.status, NotesDeleteStatus.deleted);
    expect(notesDeleteMessage(result, zh), '已删除 1 条历史，2 项未找到或已被删除');
  });

  test('empty delete result reports no selected records', () {
    final result = NotesDeleteResult.none();

    expect(result.status, NotesDeleteStatus.nothingRequested);
    expect(notesDeleteMessage(result, zh), '没有选择要删除的记录');
  });
}
