import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/models/note_item.dart';
import 'package:nekocalc/features/notes/presentation/notes_page.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**笔记回执与筛选摘要上屏的那一段接线（笔记页那一屏）。**
///
///       三条路径本轮都已转成「令牌 + 呈现边缘取字」：导入回执与删除回执
///       （`notes_receipt_message.dart`）、筛选摘要条那一句（`notes_summary_message.dart`）、
///       导入预览那一行（`notes_import_draft_message.dart`）。前两条与摘要条的**屏幕**证据都不全：
///       `notes_page_test.dart` 里删除回执（`'已删除 1 条历史、1 条笔记'`）与导入回执
///       （`'已导入 1 条历史、1 条笔记'`）只有**中文**那一条，英文那条（`_wiringTests` 里那次纯文本
///       粘贴）点完「Import」只查了库里写了什么，**从没量过屏幕上的回执**；摘要条那一句
///       （`notesSummaryLabel`）在**两种语言下都没有任何屏幕断言**——`notes_summary_message_test.dart`
///       与 `notes_controller_test.dart` 量的都是单元层。导入预览那一行是唯一一条两种语言都有屏幕证据的
///       （`notes_page_test.dart` 的 `'将导入 1 条历史、1 条笔记'` 与 `'Will import 1 notes'`），
///       所以不在这里重复。
///
///       这一条量的就是那两根线：英文作用域挂上去，从剪贴板真的导入一次、真的删一条，屏幕上的
///       回执与摘要必须是英文，且中文不许在场；默认作用域下同一批动作还得报原来那些中文。
///       少了它，「组合器改了、页面那处没接上」（或取的不是作用域里那张表）会原样留在真实应用里，
///       而所有测试全绿（`docs/verification.md` §5n）。
///
///       **触发用的是一份「一历史 + 一笔记」的批量导出文本**（`notes_page_test.dart` 里那份，
///       逐字相同）：`Clipboard.getData` 由假平台通道当场答，不经引擎往返；导入与删除都是真实的
///       按钮路径，回执由 `ScaffoldMessenger` 弹出。作用域挂在 `builder:` 上，与 `app.dart` 逐字
///       同一个挂点——否则 `showDialog` 压上来的导入与删除确认框看不见它。
/// English: **the wiring that puts note receipts and the filter summary on screen (the notes page).**
///
///          Three paths were converted this round to "token + fetch the words at the presentation
///          edge": the import and delete receipts (`notes_receipt_message.dart`), the filter summary's
///          sentence (`notes_summary_message.dart`) and the import preview row
///          (`notes_import_draft_message.dart`). The first two and the summary lack **on-screen**
///          evidence: in `notes_page_test.dart` the delete receipt (`'已删除 1 条历史、1 条笔记'`) and
///          the import receipt (`'已导入 1 条历史、1 条笔记'`) exist only in **Chinese**, while the
///          English one (the plain-text paste inside `_wiringTests`) checks only what landed in the
///          database after Import and **never measured the receipt on screen**; the summary sentence
///          (`notesSummaryLabel`) has **no on-screen assertion in either language** —
///          `notes_summary_message_test.dart` and `notes_controller_test.dart` both measure the unit
///          layer. The import preview row is the one with on-screen evidence in both languages
///          (`'将导入 1 条历史、1 条笔记'` and `'Will import 1 notes'` in `notes_page_test.dart`), so it
///          is not repeated here.
///
///          What this measures is those two wires: with an English scope installed, a real clipboard
///          import and a real delete must leave English on screen — receipt and summary both — with no
///          Chinese present; under the default scope the same actions must still report the original
///          Chinese. Without it, "the composer was fixed but the site was never wired" (or is wired to
///          some other language's table) would survive in the real app with every test green
///          (`docs/verification.md` §5n).
///
///          **The trigger is a "one history + one note" batch-export text** (the very one in
///          `notes_page_test.dart`, character for character): `Clipboard.getData` is answered on the
///          spot by a fake platform channel — no engine round trip — and both the import and the delete
///          take the real button paths, their receipts raised by the `ScaffoldMessenger`. The scope sits
///          on `builder:`, the very hook `app.dart` uses, or the import and delete confirmation dialogs
///          pushed with `showDialog` would not see it.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('英文界面：导入回执、摘要条与删除回执都是英文', (tester) async {
    _installBatchExportClipboard();
    final db = _NotesDatabase();

    await _pumpNotes(tester, db, language: AppLanguage.en);

    await tester.tap(find.byTooltip('Import from clipboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(find.text('Imported 1 history entries and 1 notes'), findsOneWidget,
        reason: '屏幕上没有这句英文回执——组合器与页面之间那根线断了，或者取的不是作用域里那张表');
    expect(
        find.text('All records, 1 history, 1 notes'), findsOneWidget,
        reason: '摘要条那句没有取作用域里的表（它印的是 `notesSummaryLabel` 拼出来的那一句）');
    expect(find.text('已导入 1 条历史、1 条笔记'), findsNothing,
        reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');
    expect(find.text('全部记录 · 历史 1 · 笔记 1'), findsNothing,
        reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');

    // 中文：让导入回执自己走完（4 秒）——`ScaffoldMessenger` 一次只显示一条，不等它走完，
    //       删除回执就得排队，屏幕上是旧的那句。
    // English: let the import receipt run out (4 seconds) — a `ScaffoldMessenger` shows one at a
    //          time, and without waiting the delete receipt would queue behind the old one.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('2+3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Deleted 1 history entries'), findsOneWidget,
        reason: '删除回执没有取作用域里的表');
    expect(find.text('已删除 1 条历史'), findsNothing,
        reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('默认（中文）界面：同一批动作报的还是原来那三句话', (tester) async {
    // 中文：没有作用域时回落到中文——这是仓库那条「默认态与接入前逐字节相同」在屏幕上的又一份证据。
    // English: with no scope the language falls back to Chinese — another piece of on-screen evidence
    //          for this repository's "the default state stays byte-identical" rule.
    _installBatchExportClipboard();
    final db = _NotesDatabase();

    await _pumpNotes(tester, db);

    await tester.tap(find.byTooltip('从剪贴板导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await tester.pumpAndSettle();

    expect(find.text('已导入 1 条历史、1 条笔记'), findsOneWidget);
    expect(find.text('全部记录 · 历史 1 · 笔记 1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('2+3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除所选'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('已删除 1 条历史'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}

/// 中文：笔记页那一屏，加一个可选的语言作用域。**作用域装在 `builder:` 上**——与 `app.dart`
///       逐字同一个挂点（`builder` 的 child 就是 Navigator）；导入与删除确认框压上来时在它之下，
///       所以取得到作用域里那张表。
/// English: the notes page plus an optional language scope. **The scope sits on `builder:`** — the
///          very hook `app.dart` uses (`builder`'s child *is* the Navigator); the import and delete
///          confirmation dialogs are pushed above it but below the scope, so they see its table.
Future<void> _pumpNotes(
  WidgetTester tester,
  AppDatabase db, {
  AppLanguage? language,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    builder: language == null
        ? null
        : (context, child) =>
            AppLanguageScope(language: language, child: child!),
    home: Scaffold(
      body: NotesPage(
        db: db,
        toolResultLabel: _identityLabel,
        settings: AppSettings.fallback,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// 中文：**外壳递进来的那条查表**——这里量的是回执与摘要，不是历史行的结果归类，所以给恒等函数
///       （与 `notes_page_test.dart` 里那条同形）。
/// English: **the lookup the shell hands in** — what is measured here is the receipts and the summary,
///          not a history row's result classification, so it is the identity (the same shape as the one
///          in `notes_page_test.dart`).
String _identityLabel(String label) => label;

/// 中文：假平台通道：剪贴板里躺着那份「一历史 + 一笔记」的批量导出文本——导入对话框与导入回执
///       都按它来，条数写死在一处，断言才数得确切。
/// English: the fake platform channel: the clipboard holds that "one history + one note" batch export —
///          the import dialog and the import receipt both follow it, the counts written down once so the
///          assertions can be exact.
void _installBatchExportClipboard() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) {
    if (call.method == 'Clipboard.getData') {
      return Future.value({
        'text': '''
NekoCalc 批量导出
历史: 1 条
笔记: 1 条

---

计算历史
表达式: 2+3
结果: 5
时间: 2026/06/08 09:30

---

笔记: 实验记录
描述: 电路校核
创建时间: 2026/06/07 18:00
更新时间: 2026/06/08 08:20

V = I * R
''',
      });
    }
    return null;
  });
}

/// 中文：一张会真的记事的假库：导入写进去的行留在内存里，删除真的删掉——页面刷新后摘要条那两根
///       计数是从这里读出来的，所以它必须跟着动作变。读与写都照实答，只有这个文件用不到的方法
///       落到 `noSuchMethod`。
/// English: a fake database that really keeps books: imported rows stay in memory and deletes really
///          remove them — the summary bar's two counts are read back from here after the page
///          refreshes, so it must follow the actions. Reads and writes answer honestly; only the
///          methods this file never touches fall through to `noSuchMethod`.
class _NotesDatabase implements AppDatabase {
  final List<HistoryItem> historyItems = [];
  final List<NoteItem> noteItems = [];
  int _nextHistoryId = 50;
  int _nextNoteId = 100;

  @override
  Future<List<HistoryItem>> history({
    int limit = 50,
    int offset = 0,
    String? query,
    String? toolId,
  }) async {
    return List<HistoryItem>.from(historyItems);
  }

  @override
  Future<List<NoteItem>> notes({
    int limit = 200,
    int offset = 0,
    String? query,
    String? tag,
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
    NoteSort sort = NoteSort.updatedNewest,
  }) async {
    return noteItems.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<List<String>> noteTags({
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
  }) async {
    return noteItems
        .expand((item) => item.tags)
        .toSet()
        .toList(growable: false);
  }

  @override
  Future<int> addNote(String title, String body,
      {String description = '', List<String> tags = const []}) async {
    final id = _nextNoteId++;
    final now = DateTime(2026, 6, 10, 9, id % 60);
    noteItems.add(NoteItem(
      id: id,
      title: title,
      description: description,
      body: body,
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  @override
  Future<int> addHistory({
    required String expression,
    required String result,
    String? toolId,
    HistoryResultKind? resultKind,
    DateTime? createdAt,
  }) async {
    final id = _nextHistoryId++;
    final timestamp = createdAt ?? DateTime(2026, 6, 10, 8, id % 60);
    historyItems.add(HistoryItem(
      id: id,
      expression: expression,
      result: result,
      resultKind: classifyHistoryResult(toolId: toolId, result: result),
      toolId: toolId,
      createdAt: timestamp,
    ));
    return id;
  }

  @override
  Future<int> deleteHistoryItems(Iterable<int> ids) async {
    final normalized = ids.toList(growable: false);
    final before = historyItems.length;
    historyItems.removeWhere((item) => normalized.contains(item.id));
    return before - historyItems.length;
  }

  @override
  Future<int> deleteNotes(Iterable<int> ids) async {
    final normalized = ids.toList(growable: false);
    final before = noteItems.length;
    noteItems.removeWhere((item) => normalized.contains(item.id));
    return before - noteItems.length;
  }

  @override
  Future<int> deleteHistory(int id) => deleteHistoryItems([id]);

  @override
  Future<int> deleteNote(int id) => deleteNotes([id]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
