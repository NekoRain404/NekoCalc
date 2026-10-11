import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/notes_clipboard_import.dart';
import 'package:nekocalc/features/notes/presentation/notes_import_draft_message.dart';
import 'package:nekocalc/features/notes/presentation/notes_receipt_message.dart';
import 'package:nekocalc/features/notes/presentation/notes_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：领域层只给令牌，句子在呈现边缘取——所以这里的断言先把中文表取出来，再逐条比。
///       **这些中文字符串是迁移前那几句的抄本**（逐字节相同由这里与
///       `notes_receipt_message_test.dart` 两张表一起钉住）。剪贴板导入那几句也一样：草稿现在只
///       带措辞令牌与载荷（首行原文、表达式原文），句子的取处在
///       `notes_import_draft_message.dart`——所以下面凡是比那几句的地方，都改从那里取。
///       **迁移前钉着的那几个值一个没改**：`'剪贴板笔记 · 临时想法'`、`'从剪贴板导入的文本'`、
///       `'计算历史 · 2+3'`、`'工具历史 · …'` 仍是逐字节同样的字符串，只是换了拼装处。
/// English: The domain layer hands over tokens only and the sentences are fetched at the presentation
///          edge — so these assertions take the Chinese table first and then compare one by one. **These
///          Chinese strings are copies of the sentences from before the move** (byte-identity is pinned
///          by this file and by the table in `notes_receipt_message_test.dart` together). The clipboard
///          import's sentences are the same story: a draft now carries only a wording token and
///          payloads (the first line as written, the expression as written) and the sentences are
///          fetched in `notes_import_draft_message.dart` — so every comparison of those sentences below
///          now goes through it. **Not one of the values pinned before the move changed**:
///          `'剪贴板笔记 · 临时想法'`, `'从剪贴板导入的文本'`, `'计算历史 · 2+3'`, `'工具历史 · …'` are the
///          same strings byte for byte, only the assembly point moved.
void main() {
  final zh = NotesStrings.forLanguage(AppLanguage.zh);
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
    expect(notesImportPlanSummary(plan, zh), '将导入 1 条历史、1 条笔记');
    expect(plan.historyDrafts, hasLength(1));
    expect(plan.historyDrafts.single.expression, '电流=2A, 电阻=5Ω');
    expect(plan.historyDrafts.single.result, '电压: 10V');
    expect(plan.historyDrafts.single.toolId, 'ohms_law');
    expect(
      plan.historyDrafts.single.createdAt,
      DateTime(2026, 6, 8, 10, 15),
    );
    expect(
      notesImportPreviewTitle(
          NotesHistoryImportPreview(plan.historyDrafts.single), zh),
      '工具历史 · 电流=2A, 电阻=5Ω',
    );
    final historyDescription = notesImportPreviewDescription(
        NotesHistoryImportPreview(plan.historyDrafts.single), zh);
    expect(historyDescription, contains('工具 ohms_law'));
    expect(historyDescription, contains('原时间 2026/06/08 10:15'));
    expect(plan.noteDrafts, hasLength(1));
    expect(plan.noteDrafts.single.wording, NotesNoteDraftWording.parsed);
    expect(plan.noteDrafts.single.title, '实验记录');
    expect(plan.noteDrafts.single.description, '电路校核');
    expect(plan.noteDrafts.single.body, 'V = I * R');
    // 中文：用户写了标题就原样过去——**没有前缀、没有截断**（迁移前就没有），保存边缘只是转一道。
    // English: a user-written title goes through as it is — **no prefix, no truncation** (there was none
    //          before the move either); the save edge only passes it along.
    expect(notesNoteDraftTitle(plan.noteDrafts.single, zh), '实验记录');
    expect(notesNoteDraftDescription(plan.noteDrafts.single, zh), '电路校核');
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
    expect(plan.noteDrafts.single.wording, NotesNoteDraftWording.clipboard);
    // 中文：**迁移前那条钉子原样保留**——同一句话、同一个字节，只是现在从保存边缘拼：
    //       载荷是首行原文 `'临时想法'`，句子由 `notes_import_draft_message.dart` 按表拼出来。
    // English: **the pin from before the move is kept as it was** — the same sentence, the same bytes,
    //          only now assembled at the save edge: the payload is the first line as written
    //          (`'临时想法'`) and the sentence is put together from the table by
    //          `notes_import_draft_message.dart`.
    expect(plan.noteDrafts.single.title, '临时想法');
    expect(notesNoteDraftTitle(plan.noteDrafts.single, zh), '剪贴板笔记 · 临时想法');
    expect(notesNoteDraftDescription(plan.noteDrafts.single, zh), '从剪贴板导入的文本');
    expect(plan.noteDrafts.single.body, '临时想法\n下一步检查单位换算');
  });

  test('empty clipboard returns a non importable plan', () {
    final plan = buildNotesClipboardImportPlan('   \n  ');

    expect(plan.canImport, isFalse);
    expect(plan.sourceTextEmpty, isTrue);
    expect(notesImportPlanSummary(plan, zh), '剪贴板没有文本内容');
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
    expect(notesImportPlanSummary(plan, zh), '将导入 1 条历史，跳过 1 段无法识别内容');
    expect(notesImportPlanMessage(plan, zh), '已导入 1 条历史，跳过 1 段');
    expect(plan.historyDrafts.single.expression, '2+3');
    expect(plan.historyDrafts.single.result, '5');
    expect(
      notesImportPreviewTitle(
          NotesHistoryImportPreview(plan.historyDrafts.single), zh),
      '计算历史 · 2+3',
    );
  });

  test('generated titles and descriptions: truncation, fallbacks, and the '
      'English side all come from the table', () {
    // 中文：**这一条是那笔具名欠账的判据。** 三件事一起钉：
    //       1) 迁移前的两条截断规则逐字节保留（标题 24、预览行 30，空白折成一个空格，尾巴 `...`）；
    //       2) 两个兜底格逐字节保留（没有首行 → `'剪贴板内容'`；导出块没有标题 → `'导入笔记'`）；
    //       3) **英文表下存进库的标题与描述是英文**——这就是"英文界面不再印中文"的证明。
    // English: **this is the criterion for that named debt.** It pins three things at once:
    //          1) the two truncations from before the move survive byte for byte (title 24, preview row
    //             30, whitespace folded to single spaces, `...` tail);
    //          2) the two fallbacks survive byte for byte (no first line -> `'剪贴板内容'`; an export
    //             block with no title -> `'导入笔记'`);
    //          3) **under the English table the title and description written into the database are
    //             English** — which is the proof that an English interface no longer prints Chinese.
    final en = NotesStrings.forLanguage(AppLanguage.en);

    final longPlan = buildNotesClipboardImportPlan('ABCDEFGHIJKLMNOPQRSTUVWXYZ\nbody');
    final longDraft = longPlan.noteDrafts.single;
    expect(longDraft.wording, NotesNoteDraftWording.clipboard);
    expect(longDraft.title, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    expect(notesNoteDraftTitle(longDraft, zh),
        '剪贴板笔记 · ABCDEFGHIJKLMNOPQRSTUVW...');
    expect(notesNoteDraftTitle(longDraft, en),
        'Clipboard note: ABCDEFGHIJKLMNOPQRSTUVW...');

    final spacedPlan =
        buildNotesClipboardImportPlan('临时   想法\n下一步检查单位换算');
    expect(notesNoteDraftTitle(spacedPlan.noteDrafts.single, zh),
        '剪贴板笔记 · 临时 想法');

    const blankClipboardDraft = NotesNoteImportDraft(
      wording: NotesNoteDraftWording.clipboard,
      title: '',
      description: '',
      body: '',
    );
    expect(notesNoteDraftTitle(blankClipboardDraft, zh), '剪贴板笔记 · 剪贴板内容');
    expect(notesNoteDraftTitle(blankClipboardDraft, en),
        'Clipboard note: Clipboard content');
    expect(notesNoteDraftDescription(blankClipboardDraft, en),
        'Text imported from the clipboard');

    final untitledPlan = buildNotesClipboardImportPlan('''
NekoCalc 批量导出
笔记: 1 条

---

笔记:
描述:
创建时间: 2026/06/07 18:00
更新时间: 2026/06/08 08:20

V = I * R
''');
    final untitledDraft = untitledPlan.noteDrafts.single;
    expect(untitledDraft.wording, NotesNoteDraftWording.parsed);
    expect(untitledDraft.title, isEmpty);
    expect(notesNoteDraftTitle(untitledDraft, zh), '导入笔记');
    expect(notesNoteDraftTitle(untitledDraft, en), 'Imported note');
    // 中文：用户没写描述时，库里那一格仍是空串（**没有兜底句**，迁移前也没有）。
    // English: with no user-written description that database cell stays the empty string (**there is no
    //          fallback sentence**, and there was none before the move either).
    expect(notesNoteDraftDescription(untitledDraft, en), isEmpty);

    final longHistoryPlan = buildNotesClipboardImportPlan('''
NekoCalc 批量导出
历史: 1 条

---

计算历史
表达式: 1234567890123456789012345678901234567890
结果: 42
''');
    final longHistory = NotesHistoryImportPreview(longHistoryPlan.historyDrafts.single);
    expect(notesImportPreviewTitle(longHistory, zh),
        '计算历史 · 12345678901234567890123456789...');
    expect(notesImportPreviewTitle(longHistory, en),
        'Calculation history: 12345678901234567890123456789...');
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
    expect(notesImportMessage(result, zh), '已导入 1 条历史，跳过 1 段无法识别内容，未写入 1 条');
  });
}
