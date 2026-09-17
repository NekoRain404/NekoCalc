import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**变量与上一轮刚放行的符号结果之间的那条边界。**
///
///       `2x` 在 `x` 没绑值的时候是**符号式**（引擎印 `2x` 回来，上一轮放行的那个形状）；`x` 一旦
///       绑了值，同一条文本就是**算术**。这一条界线画错的后果不是报错，而是屏幕上出现一个**看起来
///       完全合理的数**——这个项目为此已经花了很多轮，所以下面每一组都对着一个具体的走法。
///
///       两边的证据都能在 `flutter test` 里跑：喂给引擎的那一串由假引擎记下来（`engine.calls`），
///       屏幕上的结果由控制器给出，而回落那一条走的是真的旧解析器。
/// English: **the boundary between the variables and the symbolic results the previous round admitted.**
///
///          `2x` is **symbolic** while `x` holds no value (the engine prints `2x` back — the shape the
///          last round let through); the moment `x` is bound, the very same text is **arithmetic**.
///          Getting that line wrong does not produce an error, it produces a number that looks
///          perfectly reasonable — a defect class this project has spent many rounds on, so every group
///          below aims at one concrete route.
///
///          Both halves are reachable under `flutter test`: the string handed to the engine is recorded
///          by the fake engine (`engine.calls`), the result on screen comes from the controller, and the
///          fallback group runs the real legacy parser.
void main() {
  group('没绑值：`2x` 仍然是符号式（上一轮放行的那个形状不许变）', () {
    test('提交 `2x` 时引擎收到的是含自由变量 `x` 的那一串', () async {
      final engine = _FakeMathEngine(
        const _Reply('2x', tex: '2x', kind: EngineResultKind.symbolic).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2x');
      await controller.submit();

      expect(engine.calls.single.expression, '((2)*(x))',
          reason: '没绑值时一个字符都不该动——这是加法，不是改法');
      expect(controller.result, '2x');
      expect(controller.resultDecimal, isEmpty);
      expect(controller.hasError, isFalse);

      controller.dispose();
    });
  });

  group('绑了值：同一条 `2x` 变成算术', () {
    test('绑了 x=4 之后，引擎收到的字符串里没有 `x`，而是一个数', () async {
      final engine = _FakeMathEngine(
        const _Reply('4', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('4');
      await controller.submit();
      expect(controller.assignVariable('x'), isTrue);
      expect(controller.variableValue('x'), '4');

      engine.calls.clear();
      controller.setExpression('2x');
      await controller.submit();

      expect(engine.calls.single.expression, '((2)*((4)))',
          reason: '变量由应用侧替换，引擎从来看不见 `x`');
      expect(controller.result, '4');
      expect(controller.resultDecimal, '4');

      controller.dispose();
    });

    test('替换物带括号：`2x`（x=4）在**旧解析器**上也是 8，不是 24', () async {
      // 中文：这一条是整步里最容易造出错值的地方——把 `x` 直接换成 `4` 会得到 `24`。
      //       引擎这一发故意让它失败，于是屏幕上的数只能来自旧解析器。
      // English: this is the one place in the whole step that can manufacture a wrong value —
      //          replacing `x` with a bare `4` yields `24`. The engine call is made to fail on
      //          purpose, so the number on screen can only have come from the legacy parser.
      final engine = _FakeMathEngine(_failure);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('4');
      await controller.submit();
      controller.assignVariable('x');

      engine.reply = _failure;
      controller.setExpression('2x');
      final submitted = await controller.submit();

      expect(submitted.submitted, isTrue);
      expect(controller.result, '8');
      expect(controller.resultDecimal, '8');
      expect(controller.result, isNot('24'));

      controller.dispose();
    });

    test('解绑之后 `2x` 又是符号式', () async {
      final engine = _FakeMathEngine(
        const _Reply('4', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('4');
      await controller.submit();
      controller.assignVariable('x');
      controller.clearVariable('x');
      expect(controller.variableValue('x'), isNull);

      engine.reply =
          const _Reply('2x', tex: '2x', kind: EngineResultKind.symbolic).reply;
      engine.calls.clear();
      controller.setExpression('2x');
      await controller.submit();

      expect(engine.calls.single.expression, '((2)*(x))');
      expect(controller.result, '2x');

      controller.dispose();
    });

    test('改绑之后屏幕上那条表达式**立刻**用新值重算', () async {
      // 中文：绑定的对象可能正是屏幕上那条表达式里用到的变量，所以存下去之后必须重新求值一次
      //       （`assignVariable` 里的 `evaluate()`，与 [setAngleMode] 同一形状）。少了它，屏幕
      //       留着用旧值算出来的 9，而用户刚刚改成 9 的那个变量已经不在那一条时间线上。
      // English: what gets bound may be a variable the expression on screen uses, so storing has to
      //          evaluate again (the `evaluate()` in `assignVariable`, the same shape as
      //          [setAngleMode]). Without it the screen keeps the 9 computed from the old value, while
      //          the variable the user just set to 9 is on a different timeline.
      final engine = _FakeMathEngine(
        const _Reply('4', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('4');
      await controller.submit();
      controller.assignVariable('x');

      engine.reply = _failure;
      controller.setExpression('x+5');
      await controller.submit();
      expect(controller.result, '9');

      controller.assignVariable('x');
      expect(controller.variableValue('x'), '9');
      expect(controller.result, '14');

      controller.dispose();
    });

    test('只有一个变量绑了值时，另一个仍然是自由的', () async {
      final engine = _FakeMathEngine(
        const _Reply('4', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('4');
      await controller.submit();
      controller.assignVariable('x');

      engine.calls.clear();
      controller.setExpression('x+y');
      await controller.submit();

      expect(engine.calls.single.expression, '(((4))+(y))');
      expect(controller.result, '4');

      controller.dispose();
    });
  });

  group('引擎自己绑定变量的调用：绑了 x 之后仍然一字不变', () {
    test('`sum(x,1,10,x)` 送出去的是原来那一串', () async {
      final engine = _FakeMathEngine(
        const _Reply('4', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('4');
      await controller.submit();
      controller.assignVariable('x');

      for (final source in <String>[
        'sum(x,1,10,x)',
        'integrate(x^2,0,1,x)',
      ]) {
        engine.calls.clear();
        engine.reply =
            const _Reply('55', kind: EngineResultKind.number).reply;
        controller.setExpression(source);
        await controller.submit();
        expect(engine.calls.single.expression, isNot(contains('(4)')),
            reason: '$source 里的 x 是那个调用自己的变量，不是用户的 x');
      }

      controller.dispose();
    });
  });

  group('数值消费者的口径：存不进去的东西不许进去', () {
    test('符号结果没有可存的值——存入被拒绝', () async {
      final engine = _FakeMathEngine(
        const _Reply('2x', tex: '2x', kind: EngineResultKind.symbolic).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2x');
      await controller.submit();

      expect(controller.storableVariableValue, isNull);
      expect(controller.assignVariable('x'), isFalse);
      expect(controller.variableValue('x'), isNull,
          reason: '一次被拒绝的存入不该留下任何痕迹');

      controller.dispose();
    });

    test('带单位的结果没有可存的值', () async {
      final engine = _FakeMathEngine(
        const _Reply('5 km', kind: EngineResultKind.quantity).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('5 km');
      await controller.submit();

      expect(controller.storableVariableValue, isNull);
      expect(controller.assignVariable('x'), isFalse);

      controller.dispose();
    });

    test('下溢的值存不进去（`2^-2000` 的十进制是 `0.0`，那是个静默的错值）', () async {
      final engine = _FakeMathEngine(
        const _Reply('9.3e-603', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2^-2000');
      await controller.submit();

      expect(controller.storableVariableValue, isNull);
      expect(controller.assignVariable('x'), isFalse);

      controller.dispose();
    });

    test('变量名不在闭集里时拒绝', () async {
      final engine = _FakeMathEngine(
        const _Reply('4', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('4');
      await controller.submit();

      for (final name in <String>['z', 'ans', 'km', '']) {
        expect(controller.assignVariable(name), isFalse, reason: name);
      }
      expect(controller.variableValue('z'), isNull);

      controller.dispose();
    });

    test('绑了值的变量进了 `Ans` 的口径：十进制形态仍然只有一条', () async {
      final engine = _FakeMathEngine(
        const _Reply('4', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('4');
      await controller.submit();
      controller.assignVariable('x');

      engine.reply = _failure;
      controller.setExpression('2x');
      await controller.submit();

      // 中文：回落出来的这个 8 是**有限十进制**，于是它照样进 `_lastFiniteResult`——变量没有为
      //       数值消费者开第二条口径。
      // English: the 8 the fallback produced is a **finite decimal**, so it still enters
      //          `_lastFiniteResult` — the variable opened no second currency for numeric consumers.
      expect(controller.resultDecimal, '8');

      controller.dispose();
    });
  });

  group('撤销与落盘', () {
    test('撤销一次绑定，变量回到未赋值', () async {
      final engine = _FakeMathEngine(
        const _Reply('4', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('4');
      await controller.submit();
      controller.assignVariable('x');
      expect(controller.variableValue('x'), '4');

      controller.undo();
      expect(controller.variableValue('x'), isNull);

      controller.dispose();
    });

    test('落盘写两个键，未赋值时写空串', () async {
      final database = _FakeDatabase();
      final engine = _FakeMathEngine(
        const _Reply('4', kind: EngineResultKind.number).reply,
      );
      final controller =
          _controller(database, engine: engine, restoreState: true);

      controller.setExpression('4');
      await controller.submit();
      controller.assignVariable('x');
      await Future<void>.delayed(Duration.zero);

      expect(database.savedSettings['calculator_variable_x'], '4');
      expect(database.savedSettings['calculator_variable_y'], '');

      controller.dispose();
    });

    test('恢复：磁盘上的值要过「能不能当数字用」那一关', () async {
      final database = _FakeDatabase();
      database.savedSettings
        ..['calculator_variable_x'] = '9.3e-603'
        ..['calculator_variable_y'] = '5';
      final controller = _controller(
        database,
        engine: _FakeMathEngine(_failure),
        restoreState: true,
      );

      await controller.restoreIfEnabled();

      expect(controller.variableValue('x'), isNull,
          reason: '下溢的值不许从磁盘上恢复回来');
      expect(controller.variableValue('y'), '5');

      controller.dispose();
    });
  });
}

/// 中文：一条按实测形状配好的回执（十进制只在**是有限数**时才写，与 `QalculateMathEngine` 同规矩）。
/// English: one receipt shaped like a measurement (the decimal is written only when it **is** a finite
///          number, the same rule `QalculateMathEngine` follows).
class _Reply {
  const _Reply(this.displayText, {this.tex = '', this.kind = EngineResultKind.number});

  final String displayText;
  final String tex;
  final EngineResultKind kind;

  EngineReply get reply => EngineReply.success(MathResult(
        displayText: displayText,
        displayTex: tex,
        decimalText:
            MathResult.decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      ));
}

final EngineReply _failure = EngineReply.failure('engine unavailable');

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  EngineReply reply;

  final List<({String expression, String angleMode})> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    return reply;
  }
}

CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
  bool restoreState = false,
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: restoreState,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    ),
    engine: engine,
    liveEvaluationDelay: const Duration(minutes: 10),
    liveEngineFollowUpDelay: const Duration(minutes: 10),
  );
}

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
  Future<Map<String, String>> settings() async =>
      Map<String, String>.from(savedSettings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
