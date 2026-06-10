import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/domain/usecases/calculator_save_result.dart';
import 'package:nekocalc/domain/usecases/calculator_submit_result.dart';

void main() {
  test('copy text includes expression result angle mode and memory', () {
    final db = _FakeDatabase();
    final controller = _controller(db);

    controller.setExpression('6×7');
    controller.evaluate();
    controller.memoryAdd();

    final text = controller.copyText();

    expect(text, contains('表达式: 6×7'));
    expect(text, contains('结果: 42'));
    expect(text, contains('状态: 结果可继续使用'));
    expect(text, contains('继续使用会把 42 写回表达式'));
    expect(text, contains('角度模式: 弧度 RAD'));
    expect(text, contains('记忆值: 42'));

    controller.dispose();
  });

  test('continue with result reuses parser friendly value', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('1000+23');
    controller.evaluate();
    expect(controller.canContinueWithResult, isTrue);
    expect(controller.canSaveCurrentExpression, isTrue);
    expect(controller.resultStatusTitle, '结果可继续使用');
    controller.continueWithResult();

    expect(controller.expression, '1023');
    expect(controller.cursorIndex, 4);
    expect(controller.result, '1023');

    controller.dispose();
  });

  test('result status distinguishes empty current value and invalid input',
      () async {
    final db = _FakeDatabase();
    final controller = _controller(db);

    expect(controller.canContinueWithResult, isTrue);
    expect(controller.canSaveCurrentExpression, isFalse);
    expect(controller.resultStatusTitle, '当前值可继续使用');
    expect(controller.resultStatusMessage, contains('当前值 0'));
    expect(controller.copyText(), contains('状态: 当前值可继续使用'));

    controller.setExpression('1/0');
    controller.evaluate();

    expect(controller.canContinueWithResult, isFalse);
    expect(controller.canSaveCurrentExpression, isFalse);
    expect(controller.resultStatusTitle, '表达式需要修正');
    expect(controller.resultStatusMessage, '结果不是有限数值');
    expect(controller.copyText(), contains('状态: 表达式需要修正'));
    expect(controller.copyText(), contains('错误: 结果不是有限数值'));

    final expressionBefore = controller.expression;
    controller.continueWithResult();
    expect(controller.expression, expressionBefore);
    final saveResult = await controller.saveToNote();
    expect(saveResult.saved, isFalse);
    expect(saveResult.status, CalculatorSaveNoteStatus.invalidExpression);
    expect(db.savedNotes, isEmpty);

    controller.dispose();
  });

  test('evaluates programming radix literals in calculator expressions', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('0xFF + 0b1010 + 0o10');
    controller.evaluate();

    expect(controller.result, '273');
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('evaluates decimal literals with numeric separators', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('1_000 + 2_500.5');
    controller.evaluate();

    expect(controller.result, '3500.5');
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('evaluates calculator style bare function calls', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('sqrt 9 + log 100');
    controller.evaluate();

    expect(controller.result, '5');
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('evaluates pasted expressions with trailing result annotations', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('表达式: 6×7\n结果: 42');
    controller.evaluate();

    expect(controller.result, '42');
    expect(controller.hasError, isFalse);

    controller.setExpression('sqrt(81) = 9');
    controller.evaluate();

    expect(controller.result, '9');
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('applies pasted calculator reports with angle mode and memory', () {
    final controller = _controller(_FakeDatabase());

    final paste = controller.applyPastedText('''
表达式: sin(90)
结果: 1
状态: 结果可继续使用
角度模式: 角度 DEG
记忆值: 12.5
''');

    expect(paste.fromReport, isTrue);
    expect(paste.summary, contains('已从计算详情提取表达式'));
    expect(paste.summary, contains('角度模式 DEG'));
    expect(paste.summary, contains('记忆值 12.5'));
    expect(controller.expression, 'sin(90)');
    expect(controller.angleMode, 'DEG');
    expect(controller.memoryValue, 12.5);
    expect(controller.result, '1');
    expect(controller.hasError, isFalse);
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect(controller.expression, isEmpty);
    expect(controller.angleMode, 'RAD');
    expect(controller.memoryValue, 0);

    controller.dispose();
  });

  test('applies plain pasted calculator expressions without report metadata',
      () {
    final controller = _controller(_FakeDatabase());

    final paste = controller.applyPastedText('sqrt(81) + 1');

    expect(paste.fromReport, isFalse);
    expect(paste.summary, '已粘贴表达式');
    expect(controller.expression, 'sqrt(81) + 1');
    expect(controller.result, '10');

    controller.dispose();
  });

  test('reuses previous result with ans and last aliases', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('6*7');
    controller.evaluate();
    expect(controller.result, '42');

    controller.setExpression('ans + 8');
    controller.evaluate();
    expect(controller.result, '50');

    controller.setExpression('last / 5');
    controller.evaluate();
    expect(controller.result, '10');

    controller.dispose();
  });

  test('keeps ans stable while editing the current expression', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('5');
    controller.evaluate();
    controller.setExpression('ans+1');
    controller.evaluate();
    expect(controller.result, '6');

    controller.setExpression('ans+2');
    controller.evaluate();
    expect(controller.result, '7');

    controller.setExpression('10');
    controller.evaluate();
    controller.setExpression('ans+1');
    controller.evaluate();
    expect(controller.result, '11');

    controller.dispose();
  });

  test('wraps negative ans values before substitution', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('-5');
    controller.evaluate();
    controller.setExpression('ans^2 + last');
    controller.evaluate();

    expect(controller.result, '20');
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('evaluates exponent precedence with prefix minus', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('-2^2 + 2^-2');
    controller.evaluate();

    expect(controller.result, '-3.75');
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('undo and redo restore expression result cursor and memory', () {
    final controller = _controller(_FakeDatabase());

    controller.input('1');
    controller.input('+');
    controller.input('2');
    controller.evaluate();
    expect(controller.expression, '1+2');
    expect(controller.result, '3');
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect(controller.expression, '1+');
    expect(controller.canRedo, isTrue);

    controller.redo();
    expect(controller.expression, '1+2');
    expect(controller.result, '3');

    controller.memoryAdd();
    expect(controller.memoryValue, 3);
    controller.undo();
    expect(controller.memoryValue, 0);
    controller.redo();
    expect(controller.memoryValue, 3);

    controller.clear();
    expect(controller.expression, isEmpty);
    controller.undo();
    expect(controller.expression, '1+2');
    expect(controller.memoryValue, 3);

    controller.dispose();
  });

  test('reload settings after import restores calculator state', () async {
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'auto_save': 'false',
        'angle_mode': '弧度',
        'digits': '4 位',
        'calculator_expression': '1/3',
        'calculator_result': 'stale',
        'calculator_angle': 'DEG',
        'calculator_memory': '12.5',
        'calculator_cursor': '1',
      });
    final controller = _controller(db);

    controller.setExpression('9+9');
    expect(controller.canUndo, isTrue);

    await controller.reloadSettingsAndRestore();

    expect(controller.expression, '1/3');
    expect(controller.cursorIndex, 1);
    expect(controller.result, '0.3333');
    expect(controller.angleMode, 'DEG');
    expect(controller.memoryValue, 12.5);
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);

    controller.dispose();
  });

  test('delayed restore does not overwrite local calculator edits', () async {
    final settingsCompleter = Completer<Map<String, String>>();
    final db = _FakeDatabase(settingsCompleter: settingsCompleter);
    final controller = _controller(
      db,
      settings: const AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: true,
        autoSaveHistory: false,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    );

    final restore = controller.reloadSettingsAndRestore();
    controller.setExpression('9+9');
    expect(controller.expression, '9+9');

    settingsCompleter.complete(const {
      'restore_state': 'true',
      'auto_save': 'false',
      'angle_mode': '弧度',
      'digits': '6 位',
      'calculator_expression': '1+1',
      'calculator_result': '2',
      'calculator_angle': 'RAD',
      'calculator_memory': '5',
      'calculator_cursor': '1',
    });
    await restore;

    expect(controller.expression, '9+9');
    expect(controller.result, '18');
    expect(controller.cursorIndex, 3);
    expect(controller.memoryValue, 0);

    controller.dispose();
  });

  test('stale calculator restore request cannot overwrite newer restore',
      () async {
    final firstSettings = Completer<Map<String, String>>();
    final secondSettings = Completer<Map<String, String>>();
    final db = _FakeDatabase(settingsLoads: [firstSettings, secondSettings]);
    final controller = _controller(
      db,
      settings: const AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: true,
        autoSaveHistory: false,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    );

    final firstRestore = controller.reloadSettingsAndRestore();
    final secondRestore = controller.reloadSettingsAndRestore();

    secondSettings.complete(const {
      'restore_state': 'true',
      'auto_save': 'false',
      'angle_mode': '弧度',
      'digits': '6 位',
      'calculator_expression': '3+4',
      'calculator_result': '7',
      'calculator_angle': 'RAD',
      'calculator_memory': '2',
      'calculator_cursor': '3',
    });
    await secondRestore;
    expect(controller.expression, '3+4');
    expect(controller.result, '7');

    firstSettings.complete(const {
      'restore_state': 'true',
      'auto_save': 'false',
      'angle_mode': '弧度',
      'digits': '6 位',
      'calculator_expression': '1+1',
      'calculator_result': '2',
      'calculator_angle': 'RAD',
      'calculator_memory': '9',
      'calculator_cursor': '1',
    });
    await firstRestore;

    expect(controller.expression, '3+4');
    expect(controller.result, '7');
    expect(controller.memoryValue, 2);

    controller.dispose();
  });

  test('restore clamps stale calculator cursor and cursor moves persist',
      () async {
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'auto_save': 'false',
        'angle_mode': '弧度',
        'digits': '6 位',
        'calculator_expression': '12+34',
        'calculator_result': '46',
        'calculator_angle': 'RAD',
        'calculator_memory': '0',
        'calculator_cursor': '999',
      });
    final controller = _controller(db);

    await controller.reloadSettingsAndRestore();
    expect(controller.cursorIndex, 5);

    controller.moveCursorLeft();
    await Future<void>.delayed(Duration.zero);
    expect(controller.cursorIndex, 4);
    expect(db.savedSettings['calculator_cursor'], '4');

    controller.moveCursorToStart();
    await Future<void>.delayed(Duration.zero);
    expect(db.savedSettings['calculator_cursor'], '0');

    controller.moveCursorToEnd();
    await Future<void>.delayed(Duration.zero);
    expect(db.savedSettings['calculator_cursor'], '5');

    controller.dispose();
  });

  test('live edits persist restorable expression result and cursor', () async {
    final db = _FakeDatabase();
    final controller = _controller(
      db,
      settings: const AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: true,
        autoSaveHistory: false,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    );

    controller.input('1');
    controller.input('+');
    controller.input('2');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(db.savedSettings['calculator_expression'], '1+2');
    expect(db.savedSettings['calculator_result'], '3');
    expect(db.savedSettings['calculator_cursor'], '3');

    controller.clear();
    await Future<void>.delayed(Duration.zero);

    expect(db.savedSettings['calculator_expression'], '');
    expect(db.savedSettings['calculator_result'], '0');
    expect(db.savedSettings['calculator_cursor'], '0');

    controller.dispose();
  });

  test('reload settings after import applies preferences when restore is off',
      () async {
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'false',
        'angle_mode': '角度',
        'digits': '4 位',
      });
    final controller = _controller(db);

    controller.setExpression('1/3');
    await controller.reloadSettingsAndRestore();

    expect(controller.expression, '1/3');
    expect(controller.result, '0.3333');
    expect(controller.angleMode, 'DEG');
    expect(controller.canUndo, isFalse);

    controller.dispose();
  });

  test('new edits clear redo stack', () {
    final controller = _controller(_FakeDatabase());

    controller.input('9');
    controller.input('×');
    controller.input('9');
    controller.undo();
    expect(controller.canRedo, isTrue);

    controller.input('8');
    expect(controller.expression, '9×8');
    expect(controller.canRedo, isFalse);

    controller.dispose();
  });

  test('toggle sign targets the current value instead of whole expression', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('1+2');
    controller.input('+/-');
    expect(controller.expression, '1+(-2)');
    controller.evaluate();
    expect(controller.result, '-1');

    controller.input('+/-');
    expect(controller.expression, '1+2');
    controller.evaluate();
    expect(controller.result, '3');

    controller.input('+');
    controller.input('+/-');
    expect(controller.expression, '1+2+-');
    controller.input('5');
    controller.evaluate();
    expect(controller.result, '-2');

    controller.dispose();
  });

  test('toggle sign respects cursor position and wrapped values', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.moveCursorLeft();
    controller.moveCursorLeft();
    controller.input('+/-');
    expect(controller.expression, '12+-34');
    expect(controller.cursorIndex, 4);

    controller.input('+/-');
    expect(controller.expression, '12+34');
    expect(controller.cursorIndex, 3);

    controller.moveCursorLeft();
    controller.input('+/-');
    expect(controller.expression, '-12+34');
    expect(controller.cursorIndex, 3);

    controller.setExpression('sqrt(9)+2');
    controller.moveCursorLeft();
    controller.moveCursorLeft();
    controller.input('+/-');
    expect(controller.expression, '-sqrt(9)+2');
    controller.evaluate();
    expect(controller.result, '-1');

    controller.input('+/-');
    expect(controller.expression, 'sqrt(9)+2');

    controller.dispose();
  });

  test('save note recalculates stale result and stores audit details',
      () async {
    final db = _FakeDatabase();
    final controller = _controller(db);

    controller.setExpression('8*9');
    final result = await controller.saveToNote();

    expect(result.saved, isTrue);
    expect(result.status, CalculatorSaveNoteStatus.saved);
    expect(result.noteId, 1);
    expect(result.message, '已保存到笔记');
    expect(db.savedNotes, hasLength(1));
    expect(db.savedNotes.single.title, '计算结果');
    expect(db.savedNotes.single.body, contains('表达式: 8*9'));
    expect(db.savedNotes.single.body, contains('结果: 72'));
    expect(db.savedNotes.single.body, contains('保存时间:'));
    expect(db.savedNotes.single.description, contains('弧度 RAD'));

    controller.dispose();
  });

  test('save note rejects empty or invalid expressions', () async {
    final db = _FakeDatabase();
    final controller = _controller(db);

    final empty = await controller.saveToNote();
    expect(empty.saved, isFalse);
    expect(empty.status, CalculatorSaveNoteStatus.emptyExpression);
    expect(empty.message, '请输入有效表达式后再保存');
    controller.setExpression('1+');
    final invalid = await controller.saveToNote();
    expect(invalid.saved, isFalse);
    expect(invalid.status, CalculatorSaveNoteStatus.invalidExpression);
    expect(invalid.message, '表达式需要修正：需要输入数字');

    expect(db.savedNotes, isEmpty);
    expect(controller.hasError, isTrue);
    expect(controller.errorMessage, isNotNull);

    controller.dispose();
  });

  test('save note reports repository writes that do not create a row',
      () async {
    final db = _FakeDatabase(zeroNextNoteWrite: true);
    final controller = _controller(db);

    controller.setExpression('8*9');
    final result = await controller.saveToNote();

    expect(result.saved, isFalse);
    expect(result.status, CalculatorSaveNoteStatus.notWritten);
    expect(result.message, '笔记没有写入，请重试');
    expect(db.savedNotes, isEmpty);

    controller.dispose();
  });

  test('non finite results are treated as calculation errors', () async {
    final db = _FakeDatabase();
    final controller = _controller(
      db,
      settings: const AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: false,
        autoSaveHistory: true,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    );

    controller.setExpression('1/0');
    controller.evaluate();

    expect(controller.result, '等待输入');
    expect(controller.hasError, isTrue);
    expect(controller.errorMessage, '结果不是有限数值');
    expect(controller.reusableResult, '0');

    final submitResult = await controller.submit();
    expect(submitResult.submitted, isFalse);
    expect(submitResult.status, CalculatorSubmitStatus.invalidExpression);
    expect(submitResult.message, '表达式需要修正：结果不是有限数值');
    expect(controller.result, '结果不是有限数值');
    expect(db.savedHistory, isEmpty);

    expect((await controller.saveToNote()).saved, isFalse);
    expect(db.savedNotes, isEmpty);

    controller.dispose();
  });

  test('auto save skips equivalent submitted expressions', () async {
    final db = _FakeDatabase();
    final controller = _controller(
      db,
      settings: const AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: false,
        autoSaveHistory: true,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    );

    controller.setExpression('6×7');
    final first = await controller.submit();
    expect(first.submitted, isTrue);
    expect(first.savedToHistory, isTrue);
    expect(first.historyId, 1);
    controller.setExpression('6*7');
    final second = await controller.submit();
    expect(second.submitted, isTrue);
    expect(second.status, CalculatorSubmitStatus.historySkippedDuplicate);

    expect(db.savedHistory, hasLength(1));
    expect(db.savedHistory.single.expression, '6×7');
    expect(db.savedHistory.single.result, '42');

    controller.dispose();
  });

  test('auto save keeps angle dependent submissions separate', () async {
    final db = _FakeDatabase();
    final controller = _controller(
      db,
      settings: const AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: false,
        autoSaveHistory: true,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    );

    controller.setAngleMode('DEG');
    controller.setExpression('sin(90)');
    final degree = await controller.submit();
    expect(degree.status, CalculatorSubmitStatus.historySaved);
    controller.setAngleMode('RAD');
    controller.setExpression('sin(90)');
    final radian = await controller.submit();
    expect(radian.status, CalculatorSubmitStatus.historySaved);

    expect(db.savedHistory, hasLength(2));
    expect(db.savedHistory.map((item) => item.expression), [
      'sin(90)',
      'sin(90)',
    ]);
    expect(db.savedHistory.map((item) => item.result), [
      '1',
      '0.893997',
    ]);

    controller.dispose();
  });

  test('submit reports calculated result when auto save is disabled', () async {
    final db = _FakeDatabase();
    final controller = _controller(db);

    controller.setExpression('2+3');
    final result = await controller.submit();

    expect(result.status, CalculatorSubmitStatus.calculated);
    expect(result.submitted, isTrue);
    expect(result.savedToHistory, isFalse);
    expect(result.expression, '2+3');
    expect(result.result, '5');
    expect(db.savedHistory, isEmpty);

    controller.dispose();
  });

  test('submit reports history writes that do not create a row', () async {
    final db = _FakeDatabase(zeroNextHistoryWrite: true);
    final controller = _controller(
      db,
      settings: const AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: false,
        autoSaveHistory: true,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    );

    controller.setExpression('9+1');
    final result = await controller.submit();

    expect(result.status, CalculatorSubmitStatus.historyNotWritten);
    expect(result.submitted, isTrue);
    expect(result.needsAttention, isTrue);
    expect(result.message, '已计算，但历史没有写入，请重试');
    expect(db.savedHistory, isEmpty);

    controller.dispose();
  });

  test('submit reports history save failures and allows retry', () async {
    final db = _FakeDatabase(nextHistoryError: StateError('db locked'));
    final controller = _controller(
      db,
      settings: const AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: false,
        autoSaveHistory: true,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    );

    controller.setExpression('4*5');
    final failed = await controller.submit();
    expect(failed.status, CalculatorSubmitStatus.historyFailed);
    expect(failed.needsAttention, isTrue);
    expect(failed.message, contains('保存历史失败'));
    expect(db.savedHistory, isEmpty);

    final retried = await controller.submit();
    expect(retried.status, CalculatorSubmitStatus.historySaved);
    expect(db.savedHistory, hasLength(1));

    controller.dispose();
  });
}

CalculatorController _controller(
  _FakeDatabase db, {
  AppSettings settings = const AppSettings(
    haptics: true,
    hapticStrength: '标准',
    restoreState: false,
    autoSaveHistory: false,
    angleMode: 'RAD',
    precision: 6,
    themeModeLabel: '跟随系统',
    expressionDisplayMode: '数学符号',
  ),
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: settings,
  );
}

class _SavedNote {
  const _SavedNote({
    required this.title,
    required this.body,
    required this.description,
  });

  final String title;
  final String body;
  final String description;
}

class _FakeDatabase implements AppDatabase {
  _FakeDatabase({
    Completer<Map<String, String>>? settingsCompleter,
    List<Completer<Map<String, String>>>? settingsLoads,
    this.zeroNextNoteWrite = false,
    this.zeroNextHistoryWrite = false,
    this.nextHistoryError,
  })  : _settingsCompleter = settingsCompleter,
        _settingsLoads = List.of(settingsLoads ?? const []);

  final savedNotes = <_SavedNote>[];
  final savedHistory = <({String expression, String result, String toolId})>[];
  final savedSettings = <String, String>{};
  bool zeroNextNoteWrite;
  bool zeroNextHistoryWrite;
  Object? nextHistoryError;
  final Completer<Map<String, String>>? _settingsCompleter;
  final List<Completer<Map<String, String>>> _settingsLoads;

  @override
  Future<int> addHistory({
    required String expression,
    required String result,
    String? toolId,
    DateTime? createdAt,
  }) async {
    final historyError = nextHistoryError;
    if (historyError != null) {
      nextHistoryError = null;
      throw historyError;
    }
    if (zeroNextHistoryWrite) {
      zeroNextHistoryWrite = false;
      return 0;
    }
    savedHistory
        .add((expression: expression, result: result, toolId: toolId ?? ''));
    return savedHistory.length;
  }

  @override
  Future<int> addNote(String title, String body,
      {String description = ''}) async {
    if (zeroNextNoteWrite) {
      zeroNextNoteWrite = false;
      return 0;
    }
    savedNotes
        .add(_SavedNote(title: title, body: body, description: description));
    return savedNotes.length;
  }

  @override
  Future<void> setSettings(Map<String, String> values) async {
    savedSettings.addAll(values);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  Future<Map<String, String>> settings() async {
    if (_settingsLoads.isNotEmpty) {
      return _settingsLoads.removeAt(0).future;
    }
    final settingsCompleter = _settingsCompleter;
    if (settingsCompleter != null) return settingsCompleter.future;
    return Map<String, String>.from(savedSettings);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
