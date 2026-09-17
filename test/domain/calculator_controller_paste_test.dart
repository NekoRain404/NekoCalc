import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/domain/usecases/calculator_save_result.dart';

void main() {
  test(
      'pasting a current value report restores a valid expression and metadata',
      () {
    final controller = _controller(_FakeDatabase());

    controller.applyPastedText('''
当前值: 42
状态: 当前值可继续使用
角度模式: 角度 DEG
记忆值: 7.5
''');

    expect(controller.expression, '42');
    expect(controller.result, '42');
    expect(controller.angleMode, 'DEG');
    expect(controller.memoryValue, 7.5);
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('pasting a leading decimal current value uses parser-safe syntax', () {
    final controller = _controller(_FakeDatabase());

    controller.applyPastedText('当前值: -.5');

    expect(controller.expression, '-0.5');
    expect(controller.result, '-0.5');
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('metadata-only paste preserves the existing expression', () {
    final controller = _controller(_FakeDatabase());
    controller.setExpression('2+2');
    controller.evaluate();

    controller.applyPastedText('''
角度模式: 角度 DEG
记忆值: 12.5
''');

    expect(controller.expression, '2+2');
    expect(controller.result, '4');
    expect(controller.angleMode, 'DEG');
    expect(controller.memoryValue, 12.5);

    controller.dispose();
  });

  test('memory-only reports preserve the expression and restore memory', () {
    final controller = _controller(_FakeDatabase());
    controller.setExpression('2+2');
    controller.evaluate();

    controller.applyPastedText('memory: 7.5');

    expect(controller.expression, '2+2');
    expect(controller.result, '4');
    expect(controller.memoryValue, 7.5);

    controller.dispose();
  });

  test('non-finite pasted memory metadata preserves persisted memory',
      () async {
    final db = _FakeDatabase();
    final controller = _controller(
      db,
      settings: const AppSettings(
        haptics: true,
        hapticStrength: '标准',
        angleMode: 'RAD',
        restoreState: true,
        autoSaveHistory: false,
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    );
    controller.setExpression('7.5');
    controller.evaluate();
    controller.memoryAdd();
    await Future<void>.delayed(Duration.zero);

    controller.applyPastedText('memory: NaN');
    controller.applyPastedText('memory: Infinity');
    await Future<void>.delayed(Duration.zero);

    expect(controller.memoryValue, 7.5);
    expect(db.savedSettings['calculator_memory'], '7.5');

    controller.dispose();
  });

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
  })  : _settingsCompleter = settingsCompleter,
        _settingsLoads = List.of(settingsLoads ?? const []);

  final savedNotes = <_SavedNote>[];
  final savedHistory = <({String expression, String result, String toolId})>[];
  final savedSettings = <String, String>{};
  bool zeroNextNoteWrite = false;
  bool zeroNextHistoryWrite = false;
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
      {String description = '', List<String> tags = const []}) async {
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
