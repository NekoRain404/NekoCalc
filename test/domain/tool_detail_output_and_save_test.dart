import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tool_detail_controller.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_save_result.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_save_message.dart';
import 'package:nekocalc/features/tools/presentation/tools_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：有没有汉字。英文那一侧不许有，中文那一侧必须有——两边的断言都不许空转。
/// English: whether a Han character is present. The English side may not have one and the Chinese
///          side must, so neither assertion can idle.
final RegExp _han = RegExp(r'[㐀-䶿一-鿿豈-﫿]');

void main() {
  test('copy text includes inputs, results, and insights', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    final text = controller.copyText();

    expect(text, startsWith('欧姆定律'));
    expect(text, contains('输入参数:'));
    expect(text, contains('电流'));
    expect(text, contains('电阻'));
    expect(text, contains('计算结果:'));
    expect(text, contains('电压 V'));
    expect(text, contains('结果状态:'));
    expect(text, contains('结果可复用'));
    expect(text, contains('校核:'));
    expect(text, contains('公式: V = I'));
  });

  test('copy text and notes format input values consistently', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValue('current', '0.1+0.2');

    expect(controller.values['current'], closeTo(0.3, 1e-12));
    expect(controller.inputSummary(), contains('电流 I: 0.3A'));
    expect(controller.resultSummary(), contains('电压 V'));
    expect(controller.insightSummary(), contains('结果按理想电阻计算'));
    expect(controller.resultHealthSummary(), contains('个结果可复用'));
    expect(controller.resultHealthSummary(), contains('主结果 电压 V: 66V'));
    expect(controller.copyText(), contains('电流 I: 0.3A'));
    expect(controller.copyText(), isNot(contains('0.30000000000000004')));
    expect(controller.noteBody(), contains('输入参数:'));
    expect(controller.noteBody(), contains('计算结果:'));
    expect(controller.noteBody(), contains('结果状态:'));
    expect(controller.noteBody(), contains('校核:'));
    expect(controller.noteBody(), contains('电流 I: 0.3A'));
    expect(controller.noteBody(), isNot(contains('0.30000000000000004')));

    final primary = controller.primary!;
    final singleText = controller.singleResultCopyText(primary);
    expect(singleText, startsWith('欧姆定律'));
    expect(singleText, contains('电压 V: 66V'));
    expect(singleText, contains('输入参数:'));
    expect(singleText, contains('公式: V = I × R'));
  });

  test('result health reports invalid results without appending units', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'current': '20mA',
      'resistance': '0Ω',
      'tol': '5%',
    });

    expect(controller.hasResultIssues, isTrue);
    expect(controller.issueResults.length, controller.results.length);
    expect(controller.usableResults, isEmpty);
    expect(controller.primaryResultLine(), '电压 V: 无效');
    expect(controller.resultSummary(), contains('功率 P: 无效'));
    expect(controller.resultSummary(), isNot(contains('无效V')));
    expect(controller.resultHealthSummary(), contains('需要检查'));
    // 中文：需要检查那一支只有一个读者（屏幕），所以它**收**标签读法而不是自带一份：
    //       这里递的正是中文屏幕上递的那张表（空表、原样返回）。
    // English: the needs-checking branch has one reader only (the screen), so it **takes** the way to
    //          write a label rather than carrying one: what is handed in here is exactly what the
    //          Chinese screen hands in (the empty table, which returns its argument unchanged).
    expect(
        controller.resultIssueSummary(
            resultLabel: ToolResultLabelStrings.toolResultLabelsZh.label, limit: 2),
        contains('另有'));
    expect(controller.copyText(), contains('结果状态:'));
    expect(controller.copyText(), contains('电压 V'));
    expect(controller.singleResultCopyText(controller.primary!),
        contains('电压 V: 无效'));
  });

  test('input error summary reports labels units and parse messages', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'current': '12 V',
      'resistance': 'bad value',
      'tol': '5%',
    });

    expect(controller.hasInputErrors, isTrue);
    expect(controller.inputErrorSummary(), contains('电流 I（A）: 单位 V 与 A 不匹配'));
    expect(controller.inputErrorSummary(), contains('电阻 R（Ω）: 无法解析数值或表达式'));

    controller.updateValues({
      'current': '10mA',
      'resistance': '4.7kΩ',
      'tol': '5%',
    });

    expect(controller.hasInputErrors, isFalse);
    expect(controller.inputErrorSummary(), isEmpty);
  });

  test('save result and note report actual repository writes', () async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final db = _FakeToolSaveDatabase();
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      toolUsageRepository: ToolUsageRepository(db),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    final history = await controller.saveResult(controller.inputSummary());
    final note = await controller.saveNote();

    expect(history.status, ToolSaveStatus.saved);
    expect(history.saved, isTrue);
    expect(history.recordId, 1);
    expect(_saveReceipt(history), '结果已保存到历史记录');
    expect(note.status, ToolSaveStatus.saved);
    expect(note.recordId, 1);
    expect(db.savedHistory.single['toolId'], 'ohms_law');
    expect(db.savedNotes.single['title'], '欧姆定律');
  });

  test('save result and note report invalid inputs without writing', () async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final db = _FakeToolSaveDatabase();
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      toolUsageRepository: ToolUsageRepository(db),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValue('resistance', 'bad value');
    final history = await controller.saveResult(controller.inputSummary());
    final note = await controller.saveNote();

    expect(history.status, ToolSaveStatus.inputInvalid);
    expect(_saveReceipt(history), contains('请先修正输入参数'));
    expect(_saveReceipt(history), contains('电阻 R'));
    expect(note.status, ToolSaveStatus.inputInvalid);
    expect(db.savedHistory, isEmpty);
    expect(db.savedNotes, isEmpty);
  });

  test('save result and note report not written rows and failures', () async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final db = _FakeToolSaveDatabase(
      zeroNextHistoryWrite: true,
      zeroNextNoteWrite: true,
    );
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      toolUsageRepository: ToolUsageRepository(db),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    final missingHistory =
        await controller.saveResult(controller.inputSummary());
    final missingNote = await controller.saveNote();
    expect(missingHistory.status, ToolSaveStatus.notWritten);
    expect(_saveReceipt(missingHistory), '历史记录没有写入，请重试');
    expect(missingNote.status, ToolSaveStatus.notWritten);
    expect(_saveReceipt(missingNote), '笔记没有写入，请重试');

    final failureDb = _FakeToolSaveDatabase(
      nextHistoryError: StateError('history locked'),
      nextNoteError: StateError('note locked'),
    );
    final failureController = ToolDetailController(
      historyRepository: HistoryRepository(failureDb),
      notesRepository: NotesRepository(failureDb),
      toolUsageRepository: ToolUsageRepository(failureDb),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );
    final failedHistory =
        await failureController.saveResult(failureController.inputSummary());
    final failedNote = await failureController.saveNote();
    expect(failedHistory.status, ToolSaveStatus.failed);
    expect(_saveReceipt(failedHistory), contains('保存历史失败'));
    expect(failedNote.status, ToolSaveStatus.failed);
    expect(_saveReceipt(failedNote), contains('保存笔记失败'));
  });

  test('结果行的两个读者：屏幕侧走标签表，数据侧与拆分前逐字节相同', () async {
    // 中文：**这一条钉的就是拆分本身。** 同一台控制器、同一组输入（`齿轮比` 默认值，主结果
    //       `传动比 i: 2.5`——设备上那一幕），屏幕侧与数据侧各读各的：
    //       · 数据侧（历史 `result`、复制正文、笔记正文）**逐字节与拆分前相同**：界面是英文，
    //         它吐出来的仍然是中文。这不是漏翻，正是"写进库里的字节没动"的样子；
    //       · 屏幕侧只有结果行左边那句话换了：`Ratio i: 2.5`。
    // English: **this is the split itself, pinned.** One controller, one set of inputs (`齿轮比`
    //          defaults, primary result `传动比 i: 2.5` — the frame from the device), each reader on
    //          its own side:
    //          · the stored side (the history `result` column, the copied body, the note body) is
    //            **byte-for-byte what it was before the split**: the interface is English and it still
    //            says Chinese. That is not a missed translation, it is what "the bytes written to the
    //            database did not move" looks like;
    //          · the screen side changes only the words at the left of the result row: `Ratio i: 2.5`.
    final tool = toolCatalog.firstWhere((item) => item.id == 'gear_ratio');
    final db = _FakeToolSaveDatabase();
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      toolUsageRepository: ToolUsageRepository(db),
      tool: tool,
      strings: ToolDetailStrings.toolDetailEn,
    );
    const en = ToolResultLabelStrings.toolResultLabelsEn;
    const zh = ToolResultLabelStrings.toolResultLabelsZh;

    expect(controller.primaryResultLine(), '传动比 i: 2.5');
    expect(controller.resultHealthSummary(),
        '10 results are reusable; primary result 传动比 i: 2.5');
    expect(controller.resultSummary(), startsWith('传动比 i: 2.5'));
    expect(controller.copyText(), contains('传动比 i: 2.5'));
    expect(controller.noteBody(), contains('传动比 i: 2.5'));
    expect(controller.singleResultCopyText(controller.primary!),
        contains('传动比 i: 2.5'));

    // 中文：**真正会落库的两个值**：历史那一行与笔记正文。
    // English: **the two values that really land in the database**: the history row and the note body.
    final history = await controller.saveResult(controller.inputSummary());
    final note = await controller.saveNote();
    expect(history.saved, isTrue);
    expect(note.saved, isTrue);
    expect(db.savedHistory.single['result'], '传动比 i: 2.5');
    expect(db.savedNotes.single['body'], contains('传动比 i: 2.5'));

    expect(controller.resultHealthSummaryForDisplay(en.label),
        '10 results are reusable; primary result Ratio i: 2.5');
    expect(controller.primaryResultLineForDisplay(en.label), 'Ratio i: 2.5');
    expect(_han.hasMatch(controller.resultHealthSummaryForDisplay(en.label)),
        isFalse,
        reason: '英文屏幕上状态卡那句还有汉字');

    // 中文：**中文那一侧逐字节相同**：中文表是空表，查不到就原样返回，所以两个读者吐出同一句话。
    // English: **the Chinese side is byte-identical**: the Chinese table is empty and a miss returns its
    //          argument, so both readers produce the same sentence.
    expect(controller.resultHealthSummaryForDisplay(zh.label),
        controller.resultHealthSummary());
    expect(controller.primaryResultLineForDisplay(zh.label),
        controller.primaryResultLine());
  });

  test('需要检查那几句：屏幕侧一行一行走标签表，中文侧逐字节相同', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
      strings: ToolDetailStrings.toolDetailEn,
    );
    controller.updateValues({
      'current': '20mA',
      'resistance': '0Ω',
      'tol': '5%',
    });
    const en = ToolResultLabelStrings.toolResultLabelsEn;
    const zh = ToolResultLabelStrings.toolResultLabelsZh;
    expect(controller.hasResultIssues, isTrue);

    // 中文：数据侧：复制正文与笔记正文读的还是中文那一句。
    // English: the stored side: the copied body and the note body still read the Chinese sentence.
    expect(controller.resultSummary(), contains('电压 V: 无效'));

    // 中文：屏幕侧：左边那句话换了，值一个字没动。
    //       注意**值**那一侧的汉字（`无效`）不在本轮：它是 `formatNumber` 印的记号，
    //       属于"结果值仍是中文"那条已知残留，不在`result.label`这一格。
    // English: the screen side: the words on the left changed, the value did not move by a character.
    //          Note that the Han on the **value** side (`无效`) is not this round's: it is the marker
    //          `formatNumber` prints, the known remainder "result values are still Chinese", a
    //          different cell from `result.label`.
    final screen = controller.resultIssueSummary(resultLabel: en.label, limit: 0);
    expect(screen, contains('Voltage V: 无效'));
    expect(screen, contains('Power P: 无效'));
    for (final line in screen.split('\n')) {
      final label = line.split(': ').first;
      expect(_han.hasMatch(label), isFalse,
          reason: '英文屏幕上这一行左边那句话还有汉字：$line');
    }

    // 中文：**中文侧逐字节相同**——这一组输入下每一条结果都是"需要检查"（上面那条测试钉着
    //       `issueResults.length == results.length`），所以限长给 0 时它逐字节就是 `resultSummary()`。
    // English: **the Chinese side is byte-identical** — under these inputs every result needs checking
    //          (the test above pins `issueResults.length == results.length`), so with no limit this is
    //          `resultSummary()` byte for byte.
    expect(controller.resultIssueSummary(resultLabel: zh.label, limit: 0),
        controller.resultSummary());
  });
}

/// 中文：**保存回执在呈现边缘渲染**（领域层只给令牌，字在 `ToolsStrings` 里）。这份测试量的是
///       控制器与领域的行为，所以读回执时走与屏幕同一条路：中文表 + `toolSaveMessage`——也正是
///       从前 `result.message` 那句话的出处。
/// English: **the save receipt is rendered at the presentation edge** (the domain layer hands over the
///          token, the words live in `ToolsStrings`). This test measures the controller's and the
///          domain's behaviour, so it reads the receipt the way the screen does: the Chinese table plus
///          `toolSaveMessage` — which is exactly where the old `result.message` came from.
String _saveReceipt(ToolSaveResult result) =>
    toolSaveMessage(result, ToolsStrings.forLanguage(AppLanguage.zh));

class _FakeToolSaveDatabase implements AppDatabase {
  _FakeToolSaveDatabase({
    this.zeroNextHistoryWrite = false,
    this.zeroNextNoteWrite = false,
    this.nextHistoryError,
    this.nextNoteError,
  });

  final savedHistory = <Map<String, String>>[];
  final savedNotes = <Map<String, String>>[];
  bool zeroNextHistoryWrite;
  bool zeroNextNoteWrite;
  Object? nextHistoryError;
  Object? nextNoteError;

  @override
  Future<int> addHistory({
    required String expression,
    required String result,
    String? toolId,
    HistoryResultKind? resultKind,
    DateTime? createdAt,
  }) async {
    final error = nextHistoryError;
    if (error != null) {
      nextHistoryError = null;
      throw error;
    }
    if (zeroNextHistoryWrite) {
      zeroNextHistoryWrite = false;
      return 0;
    }
    savedHistory.add({
      'expression': expression,
      'result': result,
      if (toolId != null) 'toolId': toolId,
    });
    return savedHistory.length;
  }

  @override
  Future<int> addNote(
    String title,
    String body, {
    String description = '',
    List<String> tags = const [],
  }) async {
    final error = nextNoteError;
    if (error != null) {
      nextNoteError = null;
      throw error;
    }
    if (zeroNextNoteWrite) {
      zeroNextNoteWrite = false;
      return 0;
    }
    savedNotes.add({
      'title': title,
      'body': body,
      'description': description,
    });
    return savedNotes.length;
  }

  @override
  Future<Set<String>> favoriteToolIds() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
