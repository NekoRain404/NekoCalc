import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：引擎接进**提交路径**（按下等号）之后的控制器行为。全部用测试替身跑，不需要设备、
///       不需要引擎；引擎的失败路径（答不出来、抛异常）在这里是主要考点，因为那是用户唯一会
///       看到的差别。
///
/// English: Controller behaviour once an engine is on the *submit path* (pressed =). Everything runs
///          against a double — no device, no engine. The failure paths (no answer, thrown
///          exception) are the main subject here, because they are the only difference a user can
///          ever see.
void main() {
  /// 中文：引擎给出的十六位有效数字的十进制形态，以及它对应的、按用户设置取整后的显示形态。
  ///       `sqrt(32)` 在 16 位有效数字下是 `5.656854249492381`，6 位小数下显示 `5.656854`——
  ///       与旧解析器今天给出的显示完全一致，这正是「引擎负责算得准，Dart 负责显示」的意思。
  /// English: The 16-significant-digit decimal the engine hands over, and the display form it rounds
  ///          to at the user's setting. `sqrt(32)` is `5.656854249492381` at 16 significant digits
  ///          and displays as `5.656854` at 6 decimal places — character-for-character what the
  ///          legacy parser shows today, which is what "the engine computes, Dart displays" means.
  const engineDecimal = '5.656854249492381';
  const engineDisplay = '5.656854';
  const engineTex = r'4\sqrt{2}';

  EngineReply sqrt32Reply() => EngineReply.success(
        const MathResult(
          displayText: engineDecimal,
          displayTex: engineTex,
          decimalText: engineDecimal,
        ),
      );

  test('the submit path displays the engine result', () async {
    final engine = _FakeMathEngine(sqrt32Reply());
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sqrt(32)');
    final submitted = await controller.submit();

    expect(engine.calls, hasLength(1));
    expect(controller.hasError, isFalse);
    expect(controller.result, engineDisplay);
    expect(controller.resultTex, engineTex);
    expect(controller.resultDecimal, engineDecimal);
    expect(submitted.submitted, isTrue);
    expect(submitted.result, engineDisplay);

    controller.dispose();
  });

  test(
      'display rounding of an engine result stays in Dart, at the user precision',
      () async {
    // 中文：引擎给的是未取整的 16 位有效数字；屏幕上的形态仍然由 `formatNumber` 按
    //       `AppSettings.precision`（小数位数）与千分位设置决定——取整只有一处实现。
    // English: The engine hands over an unrounded 16-significant-digit value; what reaches the
    //          screen still comes from `formatNumber` at `AppSettings.precision` (decimal places)
    //          and the grouping setting — rounding has exactly one implementation.
    for (final (precision, digits, expected) in const [
      (4, '4 位', '5.6569'),
      (6, '6 位', '5.656854'),
      (8, '8 位', '5.65685425'),
    ]) {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(sqrt32Reply()),
        settings: _settings(precision: precision, digits: digits),
      );

      controller.setExpression('sqrt(32)');
      await controller.submit();

      expect(controller.result, expected, reason: 'precision $precision');
      expect(controller.resultDecimal, engineDecimal,
          reason: 'the decimal form stays unrounded');
      controller.dispose();
    }

    // 中文：千分位也照旧由 Dart 侧决定，引擎的十进制形态不受影响。
    // English: Grouping stays Dart's decision too, and never touches the decimal form.
    final grouped = _controller(
      _FakeDatabase(),
      engine: _FakeMathEngine(
        EngineReply.success(
          const MathResult(
            displayText: '1234567.5',
            decimalText: '1234567.5',
          ),
        ),
      ),
      settings: _settings(groupThousands: true),
    );
    grouped.setExpression('1234567.5');
    await grouped.submit();
    expect(grouped.result, '1,234,567.5');
    expect(grouped.resultDecimal, '1234567.5');
    grouped.dispose();
  });

  test('the engine is asked with the angle mode the controller is in',
      () async {
    final engine = _FakeMathEngine(
      EngineReply.success(const MathResult(displayText: '1', decimalText: '1')),
    );
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sin(90)');
    await controller.submit();
    expect(engine.calls.last.angleMode, 'RAD');

    controller.setAngleMode('DEG');
    controller.setExpression('sin(90)');
    await controller.submit();
    expect(engine.calls.last.angleMode, 'DEG');

    // 中文：这正是裁决 3 要防的那条矛盾——同一个 `sin(90)`，DEG 下是 1、RAD 下不是。角度模式
    //       不过去的话，提交路径（引擎默认角度单位）与边打边算（读 AppSettings）会互相矛盾。
    // English: This is the contradiction ruling 3 exists to prevent — the same `sin(90)` is 1 in
    //          DEG and something else in RAD. Without the mode, the submit path (the engine's
    //          default angle unit) and as-you-type (which reads AppSettings) contradict each other.
    expect(engine.calls.map((call) => call.angleMode), ['RAD', 'DEG']);

    controller.dispose();
  });

  test('the engine is asked with ans and last already resolved', () async {
    // 中文：引擎不认识 `Ans`/`last`，问它之前必须先换成十进制数值，否则它会把 `ans` 当成未知变量。
    // English: The engine does not know `Ans`/`last`, so they must be substituted before it is
    //          asked; otherwise it would treat `ans` as an unknown variable.
    final engine = _FakeMathEngine(
      EngineReply.success(
          const MathResult(displayText: '42', decimalText: '42')),
    );
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('6*7');
    await controller.submit();

    controller.setExpression('ans + 1');
    await controller.submit();

    expect(engine.calls.map((call) => call.expression), ['6*7', '42 + 1']);

    controller.dispose();
  });

  test('a failing engine falls back to the legacy parser, unchanged', () async {
    final engine = _FakeMathEngine(
      EngineReply.failure('missing_plugin: no native side'),
    );
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sqrt(32)');
    final submitted = await controller.submit();

    expect(engine.calls, hasLength(1));
    expect(controller.hasError, isFalse);
    expect(controller.result, engineDisplay);
    // 中文：回落之后拿到的**就是今天那条路**的结果——显示文本同时也是十进制形态、没有 LaTeX。
    //       注意十进制形态因此是取整后的 `5.656854`，与引擎那份未取整的不同：这不是缺陷，
    //       是两条路径各自的性质，而回落存在的意义就是「用户看不到差别」。
    // English: After falling back, the result is exactly what today's path produces — the display
    //          text doubles as the decimal form and there is no LaTeX. Note the decimal form is
    //          therefore the rounded `5.656854`, unlike the engine's unrounded one: that is not a
    //          defect but a property of each path, and the point of the fallback is that the user
    //          cannot tell them apart.
    expect(controller.resultDecimal, engineDisplay);
    expect(controller.resultTex, isEmpty);
    expect(submitted.result, engineDisplay);

    // 中文：DEG 模式下也一样（旧解析器读 `AppSettings.angleMode`）。
    // English: The same holds in DEG mode (the legacy parser reads `AppSettings.angleMode`).
    controller.setAngleMode('DEG');
    controller.setExpression('sin(90)');
    await controller.submit();
    expect(controller.result, '1');

    controller.dispose();
  });

  test('an engine that throws falls back instead of crashing', () async {
    for (final thrown in <Object>[
      MissingPluginException('No implementation found for method evaluate'),
      PlatformException(code: 'invalid_angle_mode', message: '缺少 angleMode 参数'),
    ]) {
      final engine = _FakeMathEngine(null, throwOnEvaluate: thrown);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2+3');
      final submitted = await controller.submit();

      expect(controller.result, '5', reason: '$thrown');
      expect(controller.hasError, isFalse, reason: '$thrown');
      expect(submitted.submitted, isTrue, reason: '$thrown');
      controller.dispose();
    }
  });

  test('an engine reply that is not a finite decimal falls back', () async {
    // 中文：没有十进制形态（精确形式）、以及解析出来不是有限数（溢出成 infinity）的两种回执
    //       都不算答案：前者没有可以喂给数值消费者的东西，后者放上屏幕就是一个看起来像结果的
    //       `无效`，而今天这里是一条明明白白的错误。
    // English: Both receipts without a usable answer fall back — one has no decimal form (an exact
    //          form), and one parses to a non-finite number (overflowing to infinity). Displaying
    //          the latter would put a result-looking `无效` on screen where today there is a plain
    //          error.
    final exactForm = _controller(
      _FakeDatabase(),
      engine: _FakeMathEngine(
        EngineReply.success(
          const MathResult(displayText: r'4\sqrt{2}', displayTex: r'4\sqrt{2}'),
        ),
      ),
    );
    exactForm.setExpression('sqrt(32)');
    await exactForm.submit();
    expect(exactForm.result, engineDisplay);
    expect(exactForm.resultTex, isEmpty);
    exactForm.dispose();

    final overflowing = _controller(
      _FakeDatabase(),
      engine: _FakeMathEngine(
        EngineReply.success(
          const MathResult(displayText: '1e400', decimalText: '1e400'),
        ),
      ),
    );
    overflowing.setExpression('1/0');
    await overflowing.submit();
    expect(overflowing.hasError, isTrue);
    expect(overflowing.errorMessage, '结果不是有限数值');
    expect(overflowing.result, '结果不是有限数值');
    expect(overflowing.resultDecimal, isEmpty);
    overflowing.dispose();
  });

  test('the engine result feeds Ans, last and the memory register', () async {
    final engine = _FakeMathEngine(sqrt32Reply());
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sqrt(32)');
    await controller.submit();

    // 中文：数值消费者拿到的必须是引擎那份**未取整**的十进制值，而不是屏幕上的 `5.656854`。
    // English: Numeric consumers must get the engine's *unrounded* decimal value, not the
    //          `5.656854` that reaches the screen.
    controller.memoryAdd();
    expect(controller.memoryValue, 5.656854249492381);

    controller.continueWithResult();
    expect(controller.expression, engineDecimal);

    controller.dispose();
  });

  test('an engine result is persisted in all three forms', () async {
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
      });
    final controller = _controller(db, engine: _FakeMathEngine(sqrt32Reply()));
    await controller.reloadSettingsAndRestore();

    controller.setExpression('sqrt(32)');
    await controller.submit();
    await Future<void>.delayed(Duration.zero);

    expect(db.savedSettings['calculator_result'], engineDisplay);
    expect(db.savedSettings['calculator_result_tex'], engineTex);
    expect(db.savedSettings['calculator_result_decimal'], engineDecimal);

    controller.dispose();
  });

  test('as-you-type evaluation never asks the engine', () async {
    // 中文：这一步的硬边界——`evaluate()` 一行未动，仍然完全走旧的同步解析器。引擎只在
    //       「按下等号」时被问到，所以边打边算的时序风险（异步结果与输入的竞态）根本不存在。
    // English: This step's hard boundary — `evaluate()` is untouched and still runs entirely on the
    //          legacy synchronous parser. The engine is only consulted on "pressed =", so the timing
    //          risk of live evaluation (an async result racing the next keystroke) cannot arise.
    final engine = _FakeMathEngine(sqrt32Reply());
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sqrt(32)');
    controller.evaluate();

    expect(engine.calls, isEmpty);
    expect(controller.result, engineDisplay);
    expect(controller.resultTex, isEmpty);
    expect(controller.resultDecimal, engineDisplay);

    // 中文：按键路径（`input`）同样只触发实时解析，不问引擎。
    // English: The keypad path (`input`) drives live evaluation too, and never asks the engine.
    controller.setExpression('');
    controller.input('6');
    controller.input('*');
    controller.input('7');
    expect(engine.calls, isEmpty);

    controller.dispose();
  });
}

AppSettings _settings({
  int precision = 6,
  String digits = '6 位',
  bool groupThousands = false,
  String angleMode = 'RAD',
}) {
  return AppSettings(
    haptics: true,
    hapticStrength: '标准',
    restoreState: false,
    autoSaveHistory: false,
    angleMode: angleMode,
    precision: precision,
    themeModeLabel: '跟随系统',
    expressionDisplayMode: '数学符号',
    groupThousands: groupThousands,
  );
}

CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
  AppSettings? settings,
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: settings ?? _settings(),
    engine: engine,
  );
}

/// 中文：测试替身。记下每次调用（表达式与角度模式），按配置回执或抛异常——后者用来证明
///       「引擎实现没守住不抛异常的约定」时提交路径仍然回落，而不是崩溃。
/// English: The test double. It records every call (expression and angle mode) and either returns
///          the configured receipt or throws — the latter proves the submit path still falls back
///          when an engine implementation breaks its no-throw promise instead of crashing.
class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply, {this.throwOnEvaluate});

  final EngineReply? reply;
  final Object? throwOnEvaluate;
  final List<({String expression, String angleMode})> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    final thrown = throwOnEvaluate;
    if (thrown != null) throw thrown;
    return reply ?? EngineReply.failure('no reply configured');
  }
}

/// 中文：只需要设置表的最小假数据库，够本文件用到即可。
/// English: A minimal fake database covering only the settings table, which is all this file needs.
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
