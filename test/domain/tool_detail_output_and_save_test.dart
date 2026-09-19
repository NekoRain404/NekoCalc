import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tool_detail_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_save_result.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_strings.dart';

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
    expect(controller.resultIssueSummary(limit: 2), contains('另有'));
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
    expect(history.message, '结果已保存到历史记录');
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
    expect(history.message, contains('请先修正输入参数'));
    expect(history.message, contains('电阻 R'));
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
    expect(missingHistory.message, '历史记录没有写入，请重试');
    expect(missingNote.status, ToolSaveStatus.notWritten);
    expect(missingNote.message, '笔记没有写入，请重试');

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
    expect(failedHistory.message, contains('保存历史失败'));
    expect(failedNote.status, ToolSaveStatus.failed);
    expect(failedNote.message, contains('保存笔记失败'));
  });
}
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
