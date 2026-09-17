import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';

import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**回归图在控制器这一侧的那一半**：点从数据集哪一次读法来、曲线怎么问引擎要、以及画不出来
///       的那三种原因各自给什么。
///
///       这一组最要紧的一条是：**取样问引擎的那一串是有形状的**
///       （`replace(<那条拟合调用>,x,<一个十进制字面量>)`），而且**曲线上的每一个数都是引擎给的**。
///       它不是「拿引擎印出来的函数自己算」——那条路在这一轮被量出来并否掉了（理由与实测在
///       `CalculatorController.regressionCurveFor` 上：引擎印的是显示文本，`quadraticfit` 印成
///       `x²`）。
///
///       第二条要紧的是**失败一律关上**：一个取样点答不出来就整条曲线不画——不是「用剩下的点连一条」。
///       用剩下的点连出来的折线看起来**完整**，而它有一段是错的，那正是硬性边界 4 说的
///       「一个错的图比没有图更坏」。
///
/// English: **the controller-side half of the regression graph**: which reading of the dataset the
///          points come from, how the curve is asked of the engine, and what each of the three reasons
///          it cannot be drawn gives back.
///
///          The most important item here is that **the string written for the engine has a shape**
///          (`replace(<that fit call>,x,<one decimal literal>)`) and that **every number on the curve
///          is the engine's**. It is not "take the function the engine printed and evaluate it here"
///          — that route was measured this round and rejected (the reasons and the measurements are on
///          `CalculatorController.regressionCurveFor`: what the engine prints is display text, and
///          `quadraticfit` prints `x²`).
///
///          The second is that **every failure fails closed**: one sample that does not come back
///          means no curve at all — not "join the remaining points". A polyline through the points
///          that are left **looks complete** while one stretch of it is wrong, which is exactly hard
///          boundary 4's "a wrong picture is worse than a missing one".
void main() {
  group('点：数据集的两行读法', () {
    test('四个值读成两对：(x, y) 是 (前一半, 后一半) 按位置配起来的', () async {
      final controller = _controller(_ScriptedEngine(_plainNumbers));
      await _fill(controller, const <String>['1', '2', '10', '20']);

      final points = controller.regressionGraphPoints;
      expect(points.length, 2);
      expect(points[0], (x: 1.0, y: 10.0));
      expect(points[1], (x: 2.0, y: 20.0));

      controller.dispose();
    });

    test('读不成两行时没有点——空、奇数个、只有一对，三种都不画', () async {
      final controller = _controller(_ScriptedEngine(_plainNumbers));
      expect(controller.regressionGraphPoints, isEmpty, reason: '空数据集');

      await _fill(controller, const <String>['1', '2', '10']);
      expect(controller.regressionGraphPoints, isEmpty, reason: '奇数个值（3 个）读不成两行');

      await _fill(controller, const <String>['1', '10']);
      expect(controller.regressionGraphPoints, isEmpty,
          reason: '只有一对——下限与两变量那三格是同一条（kMinRegressionPairs）');

      controller.dispose();
    });
  });

  group('曲线：逐点问引擎，一个点一发调用', () {
    test('每一个取样点都是一条 replace(拟合调用,x,十进制) 查询，值是引擎给的', () async {
      final engine = _ScriptedEngine(_plainNumbers, curveY: (x) => 100 * x);
      final controller = _controller(engine);
      await _fill(controller, const <String>['1', '2', '10', '20']);

      final outcome = await controller.regressionCurveFor(
        'linearfit',
        xMin: 0,
        xMax: 2,
      );
      final curve = outcome.curve;
      expect(curve, isNotNull, reason: '引擎答得出来时必须给出曲线');
      expect(curve!.function, 'linearfit');
      expect(curve.xs.length, kRegressionGraphCurveSamples);
      expect(curve.ys.length, kRegressionGraphCurveSamples);
      expect(curve.ys.first, 0.0);
      expect(curve.ys.last, 200.0);

      final queries = engine.calls.where((c) => c.startsWith('replace(')).toList();
      expect(queries.length, kRegressionGraphCurveSamples,
          reason: '一个取样点一发调用——不是把整条曲线塞进一个 matrix(…) 拿回来（那条路要一份向量的判据）');
      expect(
        queries.first,
        'replace(linearfit(matrix(1,2,1,2),matrix(1,2,10,20)),x,0)',
        reason: '拟合调用是**过了翻译层的那一份**，与那一格插进表达式走的是同一条路',
      );
      expect(queries.last,
          'replace(linearfit(matrix(1,2,1,2),matrix(1,2,10,20)),x,2)');

      controller.dispose();
    });

    test('取样位置是窗口里等距的、两端都取到', () async {
      final engine = _ScriptedEngine(_plainNumbers, curveY: (x) => x);
      final controller = _controller(engine);
      await _fill(controller, const <String>['1', '2', '10', '20']);

      final outcome = await controller.regressionCurveFor(
        'linearfit',
        xMin: -1,
        xMax: 3,
      );
      final xs = outcome.curve!.xs;
      expect(xs.first, -1.0, reason: '左边那个端点要在窗口的边上');
      expect(xs.last, 3.0, reason: '右边那个端点要在窗口的边上');
      expect(xs, orderedEquals(<double>[for (var i = 0; i < xs.length; i++) -1 + 4 * i / (xs.length - 1)]));

      controller.dispose();
    });

    test('三条拟合各问自己的那一条调用——quadraticfit 与 cubicfit 的调用不同', () async {
      final engine = _ScriptedEngine(_plainNumbers, curveY: (x) => x);
      final controller = _controller(engine);
      await _fill(controller, const <String>['1', '2', '3', '4', '1', '4', '9', '16']);

      await controller.regressionCurveFor('quadraticfit', xMin: 0, xMax: 1);
      await controller.regressionCurveFor('cubicfit', xMin: 0, xMax: 1);

      final queries = engine.calls.where((c) => c.startsWith('replace(')).toList();
      expect(queries.first, startsWith('replace(quadraticfit(matrix(1,4,1,2,3,4),matrix(1,4,1,4,9,16)),x,'));
      expect(queries[kRegressionGraphCurveSamples],
          startsWith('replace(cubicfit(matrix(1,4,1,2,3,4),matrix(1,4,1,4,9,16)),x,'));

      controller.dispose();
    });
  });

  group('画不出来：三条路各自关上，而且各自有话说', () {
    test('对数不够时不问引擎——那句话由控制器给，而且说出要几对、现在几对', () async {
      final engine = _ScriptedEngine(_plainNumbers, curveY: (x) => x);
      final controller = _controller(engine);
      await _fill(controller, const <String>['1', '2', '10', '20']);

      final outcome = await controller.regressionCurveFor(
        'cubicfit',
        xMin: 0,
        xMax: 2,
      );
      expect(outcome.curve, isNull);
      expect(engine.calls.where((c) => c.startsWith('replace(')), isEmpty,
          reason: '对数不够时引擎**一发都不发**（判据在 fitCall 上，与那一格的亮灭是同一条）');
      expect(outcome.refusal, 'cubicfit 的曲线没画：它要 4 对值，数据集现在有 2 对（4 个值）');

      controller.dispose();
    });

    test('某一个取样点答不出来时整条曲线不画——不是「用剩下的点连一条」', () async {
      var seen = 0;
      final engine = _ScriptedEngine(_plainNumbers, curveY: (x) {
        seen++;
        return seen == 5 ? null : 2 * x;
      });
      final controller = _controller(engine);
      await _fill(controller, const <String>['1', '2', '10', '20']);

      final outcome = await controller.regressionCurveFor(
        'linearfit',
        xMin: 0,
        xMax: 2,
      );

      expect(outcome.curve, isNull, reason: '一个点答不出来 = 没有曲线');
      expect(outcome.refusal, isNotNull);
      expect(outcome.refusal, contains('引擎没有给出'));

      controller.dispose();
    });

    test('引擎完全没有时也不画曲线（引擎缺席 = 没有那条线，不是一条猜的）', () async {
      final controller = _controller(_ScriptedEngine(_plainNumbers));
      await _fill(controller, const <String>['1', '2', '10', '20']);

      final outcome = await controller.regressionCurveFor(
        'linearfit',
        xMin: 0,
        xMax: 2,
      );
      expect(outcome.curve, isNull);
      expect(outcome.refusal, isNotNull);
      expect(controller.regressionGraphPoints.length, 2,
          reason: '曲线画不出来，点照样在——那是数据里的事实');

      controller.dispose();
    });

    test('取样期间数据集被改过时整条曲线不画——两条曲线与点不能来自两个时刻', () async {
      final gate = Completer<void>();
      var calls = 0;
      final engine = _GateEngine(gate, () {
        calls++;
        return calls == 3;
      });
      final controller = _controller(engine);
      await _fill(controller, const <String>['1', '2', '10', '20']);

      final pending = controller.regressionCurveFor('linearfit', xMin: 0, xMax: 2);
      await pumpEventQueue();
      controller.clearDataset();
      gate.complete();

      final outcome = await pending;
      expect(outcome.curve, isNull, reason: '数据集变了，曲线不能画');
      expect(outcome.refusal, contains('数据集变过'));

      controller.dispose();
    });
  });

  group('读数：图面板上那一行没有尾巴上那条调用', () {
    test('它给出下限与个数，但不给「按下去会插进去的调用」——那个面板什么都不插', () async {
      final controller = _controller(_ScriptedEngine(_plainNumbers));
      await _fill(controller, const <String>['1', '2', '10', '20']);

      final reading = controller.regressionGraphFitReading;
      expect(reading, contains('linearfit 要 2 对'));
      expect(reading, contains('quadraticfit 要 3 对'));
      expect(reading, contains('cubicfit 要 4 对'));
      expect(reading, contains('当前有 4 个值'));
      expect(reading, isNot(contains('→')),
          reason: '不带那条「会插进去的调用」：图面板里没有东西可插');
      expect(controller.fitStatusMessage, contains('→'),
          reason: '而 STAT 面板那一行照旧带着它（本次没有动它的行为）');

      controller.dispose();
    });
  });
}

/// 中文：**那一串直白的数**——引擎对 `1`/`2`/`10`/`20` 各自回它自己。
/// English: **the run of plain numbers** — the engine answers `1`/`2`/`10`/`20` with themselves.
String? _plainNumbers(String expression) {
  const plain = <String>{'1', '2', '3', '4', '10', '20', '9', '16'};
  return plain.contains(expression) ? expression : null;
}

Future<void> _fill(CalculatorController controller, List<String> values) async {
  controller.clearDataset();
  for (final value in values) {
    controller.setExpression(value);
    await controller.submit();
    final added = controller.addDatasetValue();
    expect(added, isNull, reason: '`$value` 应该加得进数据集：$added');
  }
}

CalculatorController _controller(MathEngine engine) {
  return CalculatorController(
    historyRepository: HistoryRepository(_FakeDatabase()),
    notesRepository: NotesRepository(_FakeDatabase()),
    settingsRepository: SettingsRepository(_FakeDatabase()),
    settings: const AppSettings(
      haptics: false,
      hapticStrength: '标准',
      restoreState: false,
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

/// 中文：一个按表达式回话的假引擎。`answerFor` 返回 null 就是「这一次没有引擎答案」。
///
///       [curveY] 是**那条曲线在这个 x 上的值**——测试自己算，于是「图上的每一个数都是引擎给的」
///       这件事在测试里是**可核对的**：曲线上的值必须逐点等于它。
///
/// English: a fake engine that answers by expression. A null from `answerFor` is "no engine answer
///          this time".
///
///          [curveY] is **the curve's value at that x** — the test computes it, so "every number on
///          the plot is the engine's" is **checkable** here: the curve's values must equal it point by
///          point.
class _ScriptedEngine implements MathEngine {
  _ScriptedEngine(this.answerFor, {this.curveY});

  final String? Function(String expression) answerFor;
  final double? Function(double x)? curveY;

  final List<String> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add(expression);
    final replace = RegExp(r'^replace\((.+),x,([-0-9.]+)\)$').firstMatch(expression);
    if (replace != null) {
      final x = double.tryParse(replace.group(2)!);
      final y = x == null ? null : curveY?.call(x);
      if (y == null) return EngineReply.failure('no_curve_value');
      return EngineReply.success(_numberResponse(y.toStringAsFixed(10)));
    }
    final decimal = answerFor(expression);
    if (decimal == null) return EngineReply.failure('no_script');
    return EngineReply.success(_numberResponse(decimal));
  }
}

/// 中文：一个在第 [failAt]-th 次 `replace(…)` 调用上**卡住**的引擎（要等 `gate` 放行）。用来把
///       「取样期间数据集被改过」那一段窗口撑开。
/// English: an engine that **hangs** on the [failAt]-th `replace(…)` call (until `gate` releases).
///          It holds the "dataset was edited during sampling" window open.
class _GateEngine implements MathEngine {
  _GateEngine(this.gate, this.isGatedCall);

  final Completer<void> gate;
  final bool Function() isGatedCall;

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    if (expression.startsWith('replace(')) {
      if (isGatedCall()) await gate.future;
      return EngineReply.success(_numberResponse('1'));
    }
    return EngineReply.success(_numberResponse(expression));
  }
}

MathResult _numberResponse(String decimal) => MathResult(
      displayText: decimal,
      displayTex: '',
      decimalText: decimal,
      resultKind: EngineResultKind.number,
    );

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
