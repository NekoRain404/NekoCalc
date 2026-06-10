import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/notes_clipboard_import.dart';

void main() {
  test('parses batch export notes and histories into separate drafts', () {
    final plan = buildNotesClipboardImportPlan('''
NekoCalc 批量导出
历史: 1 条
笔记: 1 条
时间范围: 2026/06/08 08:20 ~ 2026/06/08 10:15

---

工具历史: ohms_law
表达式: 电流=2A, 电阻=5Ω
结果: 电压: 10V
时间: 2026/06/08 10:15

---

笔记: 实验记录
描述: 电路校核
创建时间: 2026/06/07 18:00
更新时间: 2026/06/08 08:20

V = I * R
''');

    expect(plan.fromBatchExport, isTrue);
    expect(plan.canImport, isTrue);
    expect(plan.skippedBlockCount, 0);
    expect(plan.summary, '将导入 1 条历史、1 条笔记');
    expect(plan.historyDrafts, hasLength(1));
    expect(plan.historyDrafts.single.expression, '电流=2A, 电阻=5Ω');
    expect(plan.historyDrafts.single.result, '电压: 10V');
    expect(plan.historyDrafts.single.toolId, 'ohms_law');
    expect(
      plan.historyDrafts.single.createdAt,
      DateTime(2026, 6, 8, 10, 15),
    );
    expect(plan.historyDrafts.single.previewTitle, '工具历史 · 电流=2A, 电阻=5Ω');
    expect(
        plan.historyDrafts.single.previewDescription, contains('工具 ohms_law'));
    expect(plan.historyDrafts.single.previewDescription,
        contains('原时间 2026/06/08 10:15'));
    expect(plan.noteDrafts, hasLength(1));
    expect(plan.noteDrafts.single.source, NotesImportSource.note);
    expect(plan.noteDrafts.single.title, '实验记录');
    expect(plan.noteDrafts.single.description, '电路校核');
    expect(plan.noteDrafts.single.body, 'V = I * R');
  });

  test('plain text falls back to a clipboard note draft', () {
    final plan = buildNotesClipboardImportPlan('''
临时想法
下一步检查单位换算
''');

    expect(plan.fromBatchExport, isFalse);
    expect(plan.canImport, isTrue);
    expect(plan.historyDrafts, isEmpty);
    expect(plan.noteDrafts, hasLength(1));
    expect(plan.noteDrafts.single.source, NotesImportSource.plainText);
    expect(plan.noteDrafts.single.title, '剪贴板笔记 · 临时想法');
    expect(plan.noteDrafts.single.description, '从剪贴板导入的文本');
    expect(plan.noteDrafts.single.body, '临时想法\n下一步检查单位换算');
  });

  test('empty clipboard returns a non importable plan', () {
    final plan = buildNotesClipboardImportPlan('   \n  ');

    expect(plan.canImport, isFalse);
    expect(plan.sourceTextEmpty, isTrue);
    expect(plan.summary, '剪贴板没有文本内容');
  });

  test('batch export reports unrecognized blocks without importing them', () {
    final plan = buildNotesClipboardImportPlan('''
NekoCalc 批量导出
历史: 1 条
笔记: 0 条

---

无法识别的块
foo bar

---

计算历史
表达式: 2+3
结果: 5
时间: 2026/06/08 09:30
''');

    expect(plan.canImport, isTrue);
    expect(plan.skippedBlockCount, 1);
    expect(plan.summary, '将导入 1 条历史，跳过 1 段无法识别内容');
    expect(plan.importedMessage, '已导入 1 条历史，跳过 1 段');
    expect(plan.historyDrafts.single.expression, '2+3');
    expect(plan.historyDrafts.single.result, '5');
    expect(plan.historyDrafts.single.previewTitle, '计算历史 · 2+3');
  });

  test('import result summarizes actual written records and skipped writes',
      () {
    final plan = buildNotesClipboardImportPlan('''
NekoCalc 批量导出
历史: 1 条
笔记: 1 条

---

计算历史
表达式: 2+3
结果: 5

---

无法识别
''');

    final result = NotesClipboardImportResult(
      plan: plan,
      historyIds: const [10],
      noteIds: const [],
      skippedNoteWrites: 1,
    );

    expect(result.historyCount, 1);
    expect(result.noteCount, 0);
    expect(result.totalCount, 1);
    expect(result.skippedWriteCount, 1);
    expect(result.importedMessage, '已导入 1 条历史，跳过 1 段无法识别内容，未写入 1 条');
  });
}
