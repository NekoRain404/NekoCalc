import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/application/controllers/expression_selection.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

void main() {
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

  test('keypad input replaces the selected expression range', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(2, 4));
    controller.input('9');

    expect(controller.expression, '1294');
    expect(controller.selection, const ExpressionSelection.collapsed(3));
    expect(controller.cursorIndex, 3);

    controller.dispose();
  });

  test('operator input replaces a selection at the start of the expression',
      () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12');
    controller.setSelection(const ExpressionSelection(0, 1));
    controller.input('+');

    expect(controller.expression, '+2');
    expect(controller.selection, const ExpressionSelection.collapsed(1));

    controller.dispose();
  });

  test('backspace deletes the selected expression range', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('sqrt(81)+2');
    controller.setSelection(const ExpressionSelection(4, 8));
    controller.backspace();

    expect(controller.expression, 'sqrt+2');
    expect(controller.selection, const ExpressionSelection.collapsed(4));
    expect(controller.cursorIndex, 4);

    controller.dispose();
  });

  test('undo and redo restore the expression selection', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(2, 4));
    controller.input('9');
    controller.undo();

    expect(controller.expression, '12+34');
    expect(controller.selection, const ExpressionSelection(2, 4));

    controller.redo();

    expect(controller.expression, '1294');
    expect(controller.selection, const ExpressionSelection.collapsed(3));

    controller.dispose();
  });

  test('cursor movement collapses a selection at the requested edge', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('123456');
    controller.setSelection(const ExpressionSelection(2, 5));
    controller.moveCursorLeft();

    expect(controller.selection, const ExpressionSelection.collapsed(2));

    controller.setSelection(const ExpressionSelection(2, 5));
    controller.moveCursorRight();

    expect(controller.selection, const ExpressionSelection.collapsed(5));

    controller.dispose();
  });

  test('block cursor movement follows expression boundaries', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+sqrt(81)+345');
    controller.cursorIndex = 11;
    controller.moveCursorByBlockBackward();
    expect(controller.selection, const ExpressionSelection.collapsed(3));

    controller.cursorIndex = 0;
    controller.moveCursorByBlockForward();
    expect(controller.selection, const ExpressionSelection.collapsed(2));

    controller.cursorIndex = 3;
    controller.moveCursorByBlockForward();
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  test('block cursor movement keeps leading literals separate from functions',
      () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('2sqrt(9)');
    controller.moveCursorByBlockBackward();
    expect(controller.selection, const ExpressionSelection.collapsed(1));

    controller.moveCursorByBlockForward();
    expect(controller.selection, const ExpressionSelection.collapsed(8));

    controller.dispose();
  });

  test('block cursor movement collapses selections at directional edges', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+sqrt(81)+345');
    controller.setSelection(const ExpressionSelection(3, 11));
    controller.moveCursorByBlockBackward();
    expect(controller.selection, const ExpressionSelection.collapsed(3));

    controller.setSelection(const ExpressionSelection(3, 11));
    controller.moveCursorByBlockForward();
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  test('select all selects the full expression', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+sqrt(81)+345');
    controller.cursorIndex = 4;
    controller.selectAll();

    expect(controller.selection, const ExpressionSelection(0, 15));

    controller.dispose();
  });

  test('restores persisted selection bounds and keeps a legacy cursor',
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
        'calculator_cursor': '5',
        'calculator_selection_start': '1',
        'calculator_selection_end': '4',
      });
    final controller = _controller(db);

    await controller.reloadSettingsAndRestore();

    expect(controller.selection, const ExpressionSelection(1, 4));
    expect(controller.cursorIndex, 4);

    controller.setSelection(const ExpressionSelection(2, 5));
    await Future<void>.delayed(Duration.zero);

    expect(db.savedSettings['calculator_selection_start'], '2');
    expect(db.savedSettings['calculator_selection_end'], '5');
    expect(db.savedSettings['calculator_cursor'], '5');

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

  test('unary functions wrap the selected operand', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(3, 5));
    controller.applyUnaryFunction('sqrt');

    expect(controller.expression, '12+sqrt(34)');
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  test('binary functions replace the selected operand without dropping it', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(3, 5));
    controller.applyBinaryFunction('root');

    expect(controller.expression, '12+root(34,)');
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  test('binary functions keep a suffix outside the selected operand call', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34+56');
    controller.setSelection(const ExpressionSelection(3, 5));
    controller.applyBinaryFunction('root');

    expect(controller.expression, '12+root(34,)+56');
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  test('sign toggle replaces the selected operand', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(3, 5));
    controller.input('+/-');

    expect(controller.expression, '12+(-34)');
    expect(controller.selection, const ExpressionSelection.collapsed(8));

    controller.dispose();
  });

  test('percent replaces the selected operand', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(3, 5));
    controller.input('%');

    expect(controller.expression, '12+(34/100)');
    expect(controller.selection, const ExpressionSelection.collapsed(11));

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
