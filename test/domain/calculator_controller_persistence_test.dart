import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/domain/usecases/calculator_save_result.dart';
import 'package:nekocalc/domain/usecases/calculator_submit_result.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_strings.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_submit_message.dart';
import 'package:nekocalc/l10n/app_language.dart';

void main() {
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

  test('uses the persisted thousands grouping setting for calculator output',
      () {
    final db = _FakeDatabase();
    final controller = _controller(
      db,
      settings: const AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: false,
        autoSaveHistory: false,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
        groupThousands: true,
      ),
    );

    controller.setExpression('1234567.5');
    controller.evaluate();

    expect(controller.result, '1,234,567.5');
    controller.memoryAdd();
    controller.memoryRecall();
    expect(controller.expression, '1234567.5');
    expect(controller.result, '1,234,567.5');
    expect(controller.hasError, isFalse);

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
    // 中文：回执那句话说在呈现边缘（`calculatorSubmitMessage` 按令牌取表），所以这里量的是
    //       「中文表 + 这个令牌」印出来的那句话——与迁移前 `result.message` 逐字节相同。
    // English: the receipt sentence is rendered at the presentation edge
    //          (`calculatorSubmitMessage` looks the table up by token), so what is measured here is
    //          what "the Chinese table + this token" prints — byte-identical to the old
    //          `result.message`.
    expect(_receipt(submitResult), '表达式需要修正：结果不是有限数值');
    expect(controller.result, '结果不是有限数值');
    expect(db.savedHistory, isEmpty);

    expect((await controller.saveToNote()).saved, isFalse);
    expect(db.savedNotes, isEmpty);

    controller.dispose();
  });

  test('DEG 下的三角奇点与 `log(0)` 落在同一句话上', () async {
    // 中文：**这是设备上量到的那一条。** DEG 下 `tan(90)` 没有值（参考实现 `qalc -set "angle deg"`
    //       把算式原样印回来，等于拒绝），而旧解析器在修好之前给的是一个**有限**的
    //       1.6331239353195370e16——一个不存在的值被答成了看起来像答案的数。修好之后它落在**同一句
    //       话**上，而不是一句新文案：下游那道非有限闸（`_calculateResult` 里的 `!value.isFinite`）
    //       本来就产这句话，`log(0)`/`1/0` 走的也是它。
    // English: **The row measured on the device.** Under DEG `tan(90)` has no value (the reference,
    //          `qalc -set "angle deg"`, prints the expression back — a refusal), while the legacy
    //          parser used to answer a **finite** 1.6331239353195370e16: a value that does not exist,
    //          answered with something shaped like an answer. After the fix it lands on the **same
    //          sentence** rather than on new wording — the downstream non-finite gate (`!value.isFinite`
    //          in `_calculateResult`) already produced it, and `log(0)`/`1/0` go through it too.
    for (final source in <String>[
      'tan(90)', 'tan(270)', 'tan(-90)', 'sec(90)', 'csc(180)', 'cot(180)',
      'cot(0)', 'log(0)', '1/0',
    ]) {
      final db = _FakeDatabase();
      final controller = _controller(
        db,
        settings: const AppSettings(
          haptics: true,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: true,
          angleMode: 'DEG',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
        ),
      );

      controller.setExpression(source);
      controller.evaluate();

      expect(controller.result, '等待输入', reason: source);
      expect(controller.hasError, isTrue, reason: source);
      expect(controller.errorMessage, '结果不是有限数值', reason: source);

      final submitResult = await controller.submit();
      expect(submitResult.submitted, isFalse, reason: source);
      expect(submitResult.status, CalculatorSubmitStatus.invalidExpression,
          reason: source);
      expect(_receipt(submitResult), '表达式需要修正：结果不是有限数值', reason: source);
      expect(controller.result, '结果不是有限数值', reason: source);
      expect(db.savedHistory, isEmpty, reason: source);

      controller.dispose();
    }
  });

  test('同一个 `tan(90)` 在 RAD 下照算——两种模式的判据不同', () {
    // 中文：**这条是上一条的反例，也是「不许改 RAD」那道要求的护栏。** 弧度制里 `tan(90)` 是一个
    //       普通的数（−1.9952…），奇点判据不适用于它；RAD 真正的奇点 π/2 不是可判定的实参。
    // English: **The counter-example to the row above, and the guard for "do not touch RAD".** In
    //          radians `tan(90)` is an ordinary number (−1.9952…) and the pole judgement does not
    //          apply to it; RAD's real poles (π/2) are not decidable arguments.
    final db = _FakeDatabase();
    final controller = _controller(db);

    controller.setExpression('tan(90)');
    controller.evaluate();

    expect(controller.hasError, isFalse);
    expect(controller.resultDecimal, startsWith('-1.9952'));

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
    expect(_receipt(result), '已计算，但历史没有写入，请重试');
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
    expect(_receipt(failed), contains('保存历史失败'));
    expect(db.savedHistory, isEmpty);

    final retried = await controller.submit();
    expect(retried.status, CalculatorSubmitStatus.historySaved);
    expect(db.savedHistory, hasLength(1));

    controller.dispose();
  });
}

/// 中文：**提交回执在呈现边缘渲染**（领域层只给令牌，字在 `CalculatorStrings` 里）。
///       这份测试量的是控制器与领域的行为，所以读回执时走与屏幕同一条路：中文表 +
///       `calculatorSubmitMessage`——也正是从前 `result.message` 那句话的出处。
/// English: **the submit receipt is rendered at the presentation edge** (the domain layer hands over
///          the token, the words live in `CalculatorStrings`). This test measures the controller's and
///          the domain's behaviour, so it reads the receipt the way the screen does: the Chinese table
///          plus `calculatorSubmitMessage` — which is exactly where the old `result.message` came from.
String _receipt(CalculatorSubmitResult result) => calculatorSubmitMessage(
    result, CalculatorStrings.forLanguage(AppLanguage.zh));

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
    HistoryResultKind? resultKind,
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
