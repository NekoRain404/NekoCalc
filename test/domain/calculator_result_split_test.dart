import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/domain/usecases/calculator_paste_result.dart';

/// 中文：结果三形态拆分（displayTex / displayText / decimalText）的回归测试。
/// English: Regression tests for the result split (displayTex / displayText / decimalText).
///
/// 中文：引擎接入之前，控制器只会产出「显示文本即十进制文本」的结果，所以这里用
///       `applyMathResult` 手工装上引擎将来会给出的那种结果（精确形式 + 十进制近似），来验证
///       数值消费者确实只认十进制形态，而显示路径拿到的仍然是人类可读的那一份。
/// English: Until the engine is wired in the controller only ever produces a result whose display
///          text *is* its decimal text, so these tests install the shape the engine will hand over
///          (exact form plus decimal approximation) through `applyMathResult`, then check that
///          numeric consumers really only read the decimal form while the display path keeps
///          receiving the human-readable one.
void main() {
  const exactSqrt32 = MathResult(
    displayText: '4√2',
    displayTex: r'4\times \sqrt{2}',
    decimalText: '5.656854',
  );

  test(
      'exact and decimal forms coexist and the display path reads the display form',
      () {
    final controller = _controller(_FakeDatabase());

    controller.applyMathResult(exactSqrt32);

    // 中文：显示路径（`CalculatorDisplay.result`）拿到的是人读的那一份。
    // English: The display path (`CalculatorDisplay.result`) receives the human-readable one.
    expect(controller.result, '4√2');
    expect(controller.resultTex, r'4\times \sqrt{2}');
    expect(controller.resultDecimal, '5.656854');
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('numeric consumers resolve from the decimal form, not the display form',
      () {
    final controller = _controller(_FakeDatabase());

    controller.applyMathResult(exactSqrt32);

    // 中文：存储器是纯数值消费者——拆分前它会去解析 `4√2`，静默得到 0。
    // English: The memory register is a purely numeric consumer: before the split it parsed `4√2`
    //          and silently got 0.
    controller.memoryAdd();
    expect(controller.memoryValue, 5.656854);

    // 中文：Ans/last 从十进制形态回填表达式。
    // English: Ans/last splice the decimal form back into the expression.
    controller.setExpression('ans + 1');
    controller.evaluate();
    expect(controller.hasError, isFalse);
    expect(controller.result, '6.656854');

    controller.setExpression('last * 2');
    controller.evaluate();
    expect(controller.hasError, isFalse);
    expect(controller.result, '13.313708');

    controller.dispose();
  });

  test(
      'continue with result writes the decimal form back, never the exact form',
      () {
    final controller = _controller(_FakeDatabase());

    controller.applyMathResult(exactSqrt32);
    controller.continueWithResult();

    expect(controller.expression, '5.656854');
    expect(controller.hasError, isFalse);
    expect(controller.result, '5.656854');

    controller.dispose();
  });

  test('an empty decimal form neither throws nor corrupts ans and last', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('6*7');
    controller.evaluate();
    expect(controller.result, '42');

    // 中文：引擎给出精确形式、却没有十进制近似——拆分前这正是静默失效的那条路。
    // English: The engine hands over an exact form with no decimal approximation — the very path
    //          that failed silently before the split.
    controller.applyMathResult(const MathResult(displayText: '4√2'));
    expect(controller.result, '4√2');
    expect(controller.resultDecimal, isEmpty);

    // 中文：数值消费者读不到十进制形态时取 0（与拆分前解析不了显示文本时的取值一致），不抛异常，
    //       也不会把 `4√2` 当成数字。
    // English: With no decimal form a numeric consumer falls back to 0 (what an unparseable display
    //          text yielded before the split), throws nothing, and never treats `4√2` as a number.
    controller.setExpression('');
    expect(controller.memoryAdd, returnsNormally);
    expect(controller.memoryValue, 0);

    // 中文：Ans/last 不再解析回填，模板保持原样，求值给出**错误**而不是一个安静算错的数字。
    // English: Ans/last do not resolve any more; the template stays untouched and evaluating gives
    //          an *error* rather than a quietly wrong number.
    controller.setExpression('ans + 1');
    expect(controller.evaluate, returnsNormally);
    expect(controller.expression, 'ans + 1');
    expect(controller.hasError, isTrue);
    expect(controller.errorMessage, '函数需要括号');
    expect(controller.result, '等待输入');
    expect(controller.resultDecimal, isEmpty);

    controller.dispose();
  });

  test('the display path receives exactly what it received before the split',
      () {
    final controller = _controller(_FakeDatabase());

    // 中文：旧求值器下显示文本与十进制文本同值、没有 LaTeX，屏幕上看到的仍然是拆分前那个字符串。
    //       （显示文本带千分位、十进制文本不带的那种组合由引擎接入后的精确形式产生，见上一条测试；
    //       分组设置本身的行为仍由 `calculator_controller_test.dart` 里既有的用例把守。）
    // English: Under the legacy evaluator the display text and the decimal text hold the same value
    //          and there is no LaTeX, so the string that reaches the screen is the pre-split one.
    //          (The display-with-separators vs decimal-without pair comes from exact forms once the
    //          engine lands — see the test above; the grouping setting's own behaviour stays guarded
    //          by the existing cases in `calculator_controller_test.dart`.)
    controller.setExpression('1234567.5');
    controller.evaluate();
    expect(controller.result, '1234567.5');
    expect(controller.resultDecimal, '1234567.5');
    expect(controller.resultTex, isEmpty);

    controller.setExpression('1/0');
    controller.evaluate();
    expect(controller.result, '等待输入');
    expect(controller.resultDecimal, isEmpty);
    expect(controller.reusableResult, '0');

    controller.dispose();
  });

  test('undo and redo carry all three forms of the result', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('2+3');
    controller.evaluate();
    expect(controller.result, '5');

    controller.applyMathResult(exactSqrt32);
    controller.setExpression('9');
    controller.evaluate();
    expect(controller.result, '9');

    controller.undo();
    expect(controller.result, '4√2');
    expect(controller.resultTex, r'4\times \sqrt{2}');
    expect(controller.resultDecimal, '5.656854');

    controller.redo();
    expect(controller.result, '9');
    expect(controller.resultDecimal, '9');

    controller.dispose();
  });

  test('all three forms are persisted together and restored together',
      () async {
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
      });
    final controller = _controller(db);
    await controller.reloadSettingsAndRestore();

    controller.applyMathResult(exactSqrt32);
    controller.memoryAdd();
    await Future<void>.delayed(Duration.zero);

    expect(db.savedSettings['calculator_result'], '4√2');
    expect(db.savedSettings['calculator_result_tex'], r'4\times \sqrt{2}');
    expect(db.savedSettings['calculator_result_decimal'], '5.656854');
    expect(db.savedSettings['calculator_result'], controller.result);
    expect(
      db.savedSettings['calculator_result_decimal'],
      controller.resultDecimal,
    );

    controller.dispose();
  });

  test('restoring an exact result keeps its decimal form alive', () async {
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
        'calculator_expression': '',
        'calculator_result': '4√2',
        'calculator_result_tex': r'4\times \sqrt{2}',
        'calculator_result_decimal': '5.656854',
        'calculator_angle': 'RAD',
        'calculator_memory': '0',
      });
    final controller = _controller(db);

    await controller.reloadSettingsAndRestore();

    expect(controller.result, '4√2');
    expect(controller.resultTex, r'4\times \sqrt{2}');
    expect(controller.resultDecimal, '5.656854');

    // 中文：重启之后 Ans 依然解析得到，而不会静默失效。
    // English: Ans still resolves after a restart instead of failing silently.
    controller.setExpression('ans + 1');
    controller.evaluate();
    expect(controller.result, '6.656854');

    controller.dispose();
  });

  test('persisted rows written before the split still restore as they did',
      () async {
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
        'calculator_expression': '',
        'calculator_result': '1,234.5',
        'calculator_angle': 'RAD',
        'calculator_memory': '0',
      });
    final controller = _controller(db);

    await controller.reloadSettingsAndRestore();

    // 中文：旧行没有十进制键，按拆分前的做法从显示文本推导，取值完全不变。
    // English: An old row has no decimal key, so it is derived from the display text exactly as
    //          before the split, with an identical value.
    expect(controller.result, '1,234.5');
    expect(controller.resultDecimal, '1234.5');
    expect(controller.resultTex, isEmpty);
    expect(controller.reusableResult, '1234.5');

    controller.dispose();
  });

  test('the report carries a decimal line only when the display form needs one',
      () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('6*7');
    controller.evaluate();
    final legacyReport = controller.copyText();
    expect(legacyReport, contains('结果: 42'));
    expect(legacyReport, isNot(contains('十进制')));

    controller.setExpression('');
    controller.applyMathResult(exactSqrt32);
    final exactReport = controller.copyText();
    expect(exactReport, contains('当前值: 4√2'));
    expect(exactReport, contains('十进制: 5.656854'));

    controller.dispose();
  });

  test('copying an exact result and pasting it back keeps the value', () {
    final source = _controller(_FakeDatabase());
    source.applyMathResult(exactSqrt32);
    final report = source.copyText();
    source.dispose();

    final paste = CalculatorPasteResult.fromText(report);
    expect(paste.fromReport, isTrue);
    expect(paste.fromCurrentValue, isTrue);
    expect(paste.expression, '5.656854');

    final target = _controller(_FakeDatabase());
    target.applyPastedText(report);
    expect(target.expression, '5.656854');
    expect(target.result, '5.656854');
    expect(target.hasError, isFalse);
    target.dispose();
  });

  test('pasting a report without a decimal line behaves as before', () {
    final controller = _controller(_FakeDatabase());

    controller.applyPastedText('''
当前值: 1,234.5
状态: 当前值可继续使用
角度模式: 角度 DEG
记忆值: 12.5
''');

    // 中文：报告里没有十进制行时，粘贴路径与拆分前完全一样：从「当前值」行取。
    // English: Without a decimal line in the report the paste path behaves exactly as before the
    //          split: it takes the current-value line.
    expect(controller.expression, '1234.5');
    expect(controller.result, '1234.5');
    expect(controller.resultDecimal, '1234.5');
    expect(controller.memoryValue, 12.5);

    controller.dispose();
  });

  test('a decimal line wins over a current value line that is also parseable',
      () {
    final paste = CalculatorPasteResult.fromText('''
当前值: 5.6568542
十进制: 5.656854
状态: 当前值可继续使用
''');

    expect(paste.expression, '5.656854');
    expect(paste.fromCurrentValue, isTrue);
  });

  test('a decimal line on its own is report metadata, not a plain expression',
      () {
    final result = CalculatorPasteResult.fromText('十进制: 5.656854');

    expect(result.status, CalculatorPasteStatus.calculatorReport);
    expect(result.expression, '5.656854');
    expect(result.summary, contains('恢复当前值'));
  });

  test('every path that recomputes the result keeps the three forms together',
      () async {
    final db = _FakeDatabase();
    final controller = _controller(db);

    // 中文：等号会用当前唯一的求值器重算一遍；重算之后三形态必须依旧自洽——显示文本与十进制文本
    //       同值、没有 LaTeX，而不是留下上一份结果里的某个形态。
    // English: "=" recomputes with the only evaluator there is; afterwards the three forms have to
    //          stay coherent — display text and decimal text equal, no LaTeX — rather than leaving
    //          one form behind from the previous result.
    controller.applyMathResult(exactSqrt32);
    controller.setExpression('sqrt(32)');
    final submitResult = await controller.submit();
    expect(submitResult.result, '5.656854');
    expect(controller.result, '5.656854');
    expect(controller.resultDecimal, '5.656854');
    expect(controller.resultTex, isEmpty);
    expect(controller.hasError, isFalse);
    expect(submitResult.result, controller.result);

    controller.setExpression('6*7');
    controller.evaluate();
    expect(controller.result, '42');
    expect(controller.resultDecimal, '42');
    expect(controller.resultTex, isEmpty);

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

/// 中文：只需要设置表的最小假数据库，够本文件用到即可。笔记表与历史表一概不声明——`AppDatabase`
///       那两张表的方法签名会被别的任务改动，本文件不碰它们，免得测试跟着签名一起碎。
/// English: A minimal fake database covering only the settings table, which is all this file needs.
///          Nothing for notes or history is declared: those signatures move with other work, and
///          this file does not touch them, so it should not break when they do.
class _FakeDatabase implements AppDatabase {
  final savedSettings = <String, String>{};

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
    return Map<String, String>.from(savedSettings);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
