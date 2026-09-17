import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/regression_graph_sheet.dart';

/// 中文：**回归图那一侧的界面证据**——入口、图上画了什么、以及**画不出来时不画线**。
///
///       这里走的是**真实的交互路径**：`STAT` 那颗键从键位表里查出来（不是写死 id），数据集是
///       一个一个算到屏幕上加进去的，图那一格真的被按下去。求值通道被换成一个假引擎（与
///       `calculator_base_key_test.dart` 同一个做法），于是**曲线的每一个答案都在测试手里**：
///       那条线性拟合的假引擎回 `10x`，而测试断言图上读到的 y 正好是 `10 × x` 逐个相等——所以
///       「引擎给的数原样上了图」是可核对的，不是「有一条线就算过」。
///
///       三条**画不出来**的路各有一条测试：
///       1. 对数不够（`cubicfit` 在 2 对上）—— 点照画，线上没有，读数说出还差几对；
///       2. 引擎答不出来（假引擎对 `replace(…)` 回失败）—— 同上；
///       3. 读不成两行（空 / 奇数 / 一对）—— 入口那颗键**是灰的**（按下去只会打开一张空面板）。
///
/// English: **the UI evidence for the regression graph** — its entrance, what the plot draws, and
///          **that nothing is drawn when it cannot be**.
///
///          This walks the **real interaction path**: the `STAT` key is looked up **in the key table**
///          (not a hardcoded id), the dataset values are computed onto the screen and added one at a
///          time, and the graph cell is really pressed. The evaluation channel is swapped for a fake
///          engine (the device `calculator_base_key_test.dart` uses), so **every answer on the curve is
///          in the test's hands**: that fake engine answers the linear fit with `10x`, and the test
///          asserts the y values read off the plot are `10 × x` one for one — so "the engine's numbers
///          reach the plot unchanged" is checkable, not merely "a line was drawn".
///
///          The three **cannot-be-drawn** routes each have a test:
///          1. too few pairs (`cubicfit` on 2 pairs) — the points are still drawn, there is no line, and
///             the reading says how many more pairs are needed;
///          2. the engine does not answer (the fake engine fails every `replace(…)`) — the same;
///          3. the dataset cannot be read as two rows (empty / odd / one pair) — the entrance key
///             itself **is grey** (pressing it would only open an empty sheet).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nekocalc/qalculate');

  final calls = <String>[];

  /// 中文：假引擎。普通算式回它自己（于是数据集里那串数就是打进去的那串），`replace(…)` 回
  ///       [slope] × x——也就是那条线性拟合的真解。**逐字对应原生侧回执的字段**。
  /// English: the fake engine. Plain expressions answer with themselves (so the dataset holds exactly
  ///          the digits typed), and `replace(…)` answers [slope] × x — the true solution of that
  ///          linear fit. The returned fields are verbatim the native receipt's.
  Object? Function(MethodCall call) engine({
    double slope = 10,
    bool failCurve = false,
  }) {
    return (call) {
      if (call.method != 'evaluate') return null;
      final expression = (call.arguments as Map)['expression'] as String;
      calls.add(expression);
      final body = RegExp(r'^replace\((.+),x,([-0-9.]+)\)$').firstMatch(expression);
      if (body != null) {
        if (failCurve) {
          return <String, String>{'ok': 'false', 'error': 'engine_no_decimal'};
        }
        final x = double.tryParse(body.group(2)!);
        if (x == null) return <String, String>{'ok': 'false', 'error': 'bad_literal'};
        return <String, String>{
          'ok': 'true',
          'decimal': (slope * x).toStringAsFixed(6),
          'latex': '',
          'aborted': 'false',
          'kind': 'number',
        };
      }
      return <String, String>{
        'ok': 'true',
        'decimal': expression,
        'latex': '',
        'aborted': 'false',
        'kind': 'number',
      };
    };
  }

  void respondWith(Object? Function(MethodCall call) fn) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => fn(call));
  }

  setUp(calls.clear);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('STAT 面板上有回归图的入口；读不成两行时那颗键是灰的', (tester) async {
    respondWith(engine());
    await _pumpPage(tester);

    // 中文：空数据集 → 那颗键是灰的（按下去只会打开一张没有东西可画的面板）。
    // English: an empty dataset → that key is grey (pressing it would open a sheet with nothing in
    //          it).
    _openStatistics(tester);
    await tester.pumpAndSettle();
    expect(_graphButton(tester).onPressed, isNull, reason: '没有两行读法时图上无从画起');

    await _closeSheet(tester);
    await _addValues(tester, const <String>['1', '2', '10', '20']);

    _openStatistics(tester);
    await tester.pumpAndSettle();
    expect(_graphButton(tester).onPressed, isNotNull, reason: '两对值起就该能画');
  });

  testWidgets('打开回归图：画出数据集里的点，并画出引擎给的曲线', (tester) async {
    respondWith(engine());
    await _pumpPage(tester);
    await _addValues(tester, const <String>['1', '2', '10', '20']);

    await _openRegressionGraph(tester);

    final painter = _painter(tester);
    expect(painter.points.length, 2, reason: '两对值就是两个点');
    expect(painter.points[0], (x: 1.0, y: 10.0));
    expect(painter.points[1], (x: 2.0, y: 20.0));

    expect(painter.drawsCurve, isTrue, reason: '引擎答得出来时必须有曲线');
    expect(painter.curveXs.length, kRegressionGraphCurveSamples);
    // 中文：**图上读到的每一个 y 都是假引擎给的那个数**——线性拟合的真解是 `10x`。
    // English: **every y read off the plot is the number the fake engine gave** — the linear fit's
    //          true answer is `10x`.
    for (var i = 0; i < painter.curveXs.length; i++) {
      expect(painter.curveYs[i], closeTo(10 * painter.curveXs[i], 1e-6));
    }

    // 中文：问引擎的那一串是 `replace(<拟合调用>,x,<数>)`——**不是**把引擎印出来的函数拿回来自己求值。
    //       窗口是点的 x 范围两边各留 15%（`regressionGraphXWindow`）：两对 x=1,2 → [0.85, 2.15]。
    // English: the string asked of the engine is `replace(<fit call>,x,<number>)` — **not** the
    //          engine's printed function taken back and evaluated here. The window pads the points' x
    //          range by 15% either side (`regressionGraphXWindow`): the two pairs x=1,2 → [0.85, 2.15].
    final queries = calls.where((c) => c.startsWith('replace(')).toList();
    expect(queries.length, kRegressionGraphCurveSamples);
    expect(queries.first,
        'replace(linearfit(matrix(1,2,1,2),matrix(1,2,10,20)),x,0.85)');
    expect(queries.last,
        'replace(linearfit(matrix(1,2,1,2),matrix(1,2,10,20)),x,2.15)');
    expect(find.textContaining('linearfit 的曲线'), findsOneWidget);
  });

  testWidgets('对数不够：点照画，曲线上没有，读数说出还差几对', (tester) async {
    respondWith(engine());
    await _pumpPage(tester);
    await _addValues(tester, const <String>['1', '2', '10', '20']);

    await _openRegressionGraph(tester);
    expect(_painter(tester).drawsCurve, isTrue, reason: '先确认默认那条画得出来');

    // 中文：**按 `cubicfit`**（它要 4 对，现在只有 2 对）。这一格是亮的，按下去是一件有用的事：
    //       点还在，读数说出还差几对。
    // English: **press `cubicfit`** (it needs 4 pairs and there are 2). That cell is lit and pressing
    //          it does something useful: the points stay and the reading says how many more pairs are
    //          needed.
    await tester.tap(find.text('cubicfit'));
    await tester.pumpAndSettle();

    expect(_painter(tester).drawsCurve, isFalse,
        reason: '对数不够时**一根线都不画**——画一条看起来权威的错曲线比没有线坏得多');
    expect(_painter(tester).points.length, 2, reason: '点照旧——那是数据里的事实');
    expect(find.text('cubicfit 的曲线没画：它要 4 对值，数据集现在有 2 对（4 个值）'),
        findsOneWidget);
    expect(calls.where((c) => c.contains('cubicfit')), isEmpty,
        reason: '对数不够时引擎**一发都不发**（判据在 fitCall 上，与那一格插不插东西是同一条）');
  });

  testWidgets('引擎答不出来：点照画，曲线上没有，而且说得出原因', (tester) async {
    respondWith(engine(failCurve: true));
    await _pumpPage(tester);
    await _addValues(tester, const <String>['1', '2', '10', '20']);

    await _openRegressionGraph(tester);

    expect(_painter(tester).drawsCurve, isFalse, reason: '引擎答不出来 = 没有那条线');
    expect(_painter(tester).points.length, 2, reason: '点不依赖引擎');
    expect(find.textContaining('曲线没画：引擎没有给出'), findsOneWidget);
  });

  testWidgets('先发的那一条回来晚了也不会上屏——连点两下只认最后按的那一格', (tester) async {
    // 中文：**这一条测的是一个真的竞态**，所以它必须把「先发的那一发还在飞」这件事构造出来：
    //       假引擎把第一条 `quadraticfit` 的查询**卡住**，等用户按完 `cubicfit` 再放行。没有那个
    //       「只认最后一发」的序号，后回来的 `quadraticfit` 会把屏幕上选中的 `cubicfit` 的读数与图
    //       一起盖掉——而屏幕上高亮的是后者。
    // English: **this tests a real race**, so it has to construct "the earlier request is still in
    //          flight": the fake engine **holds** the first `quadraticfit` query until the user has
    //          pressed `cubicfit`. Without the "only the last request counts" counter, the late
    //          `quadraticfit` would overwrite both the reading and the plot of the `cubicfit` that is
    //          highlighted on screen.
    final gate = Completer<void>();
    var held = false;
    respondWith((call) {
      if (call.method != 'evaluate') return null;
      final expression = (call.arguments as Map)['expression'] as String;
      calls.add(expression);
      if (expression.contains('quadraticfit') && !held) {
        held = true;
        return gate.future.then((_) => <String, String>{
              'ok': 'true',
              'decimal': '1',
              'latex': '',
              'aborted': 'false',
              'kind': 'number',
            });
      }
      final body = RegExp(r'^replace\((.+),x,([-0-9.]+)\)$').firstMatch(expression);
      if (body != null) {
        final x = double.tryParse(body.group(2)!) ?? 0;
        return <String, String>{
          'ok': 'true',
          'decimal': (10 * x).toStringAsFixed(6),
          'latex': '',
          'aborted': 'false',
          'kind': 'number',
        };
      }
      return <String, String>{
        'ok': 'true',
        'decimal': expression,
        'latex': '',
        'aborted': 'false',
        'kind': 'number',
      };
    });
    await _pumpPage(tester);
    await _addValues(tester, const <String>['1', '2', '3', '10', '20', '30']);

    await _openRegressionGraph(tester);
    await tester.tap(find.text('quadraticfit'));
    await tester.pump();
    await tester.tap(find.text('cubicfit'));
    await tester.pumpAndSettle();

    expect(find.text('cubicfit 的曲线没画：它要 4 对值，数据集现在有 3 对（6 个值）'),
        findsOneWidget);
    expect(_painter(tester).drawsCurve, isFalse);

    // 中文：放行那一发**先发的**——它回来时已经过期了，屏幕上一个字符都不该动。
    // English: release the **earlier** request — by the time it lands it is stale and not one
    //          character on screen may move.
    gate.complete();
    await tester.pumpAndSettle();

    expect(_painter(tester).drawsCurve, isFalse,
        reason: '后到的那一发属于一个已经被换掉的选择，它不许上屏');
    expect(find.text('cubicfit 的曲线没画：它要 4 对值，数据集现在有 3 对（6 个值）'),
        findsOneWidget);
  });

  group('两条窗口的算式（纯函数，图上那一片由它们定）', () {
    test('x 窗口是点的 x 范围两边各留 15%——曲线的有无不影响它', () {
      const points = <({double x, double y})>[(x: 1, y: 10), (x: 3, y: 30)];
      final window = regressionGraphXWindow(points);
      expect(window.xMin, closeTo(0.7, 1e-9));
      expect(window.xMax, closeTo(3.3, 1e-9));
    });

    test('x 全相同时给一个宽 1 的窗口，不是宽 0（宽 0 画不出东西）', () {
      const points = <({double x, double y})>[(x: 5, y: 1), (x: 5, y: 2)];
      final window = regressionGraphXWindow(points);
      expect(window.xMax - window.xMin, closeTo(1, 1e-9));
    });

    test('y 窗口把曲线的取样值也算进去——三次拟合会在两个点之间探出数据的范围', () {
      const points = <({double x, double y})>[(x: 1, y: 10), (x: 2, y: 20)];
      final withoutCurve = regressionGraphYWindow(points, const <double>[]);
      final withCurve = regressionGraphYWindow(points, const <double>[1000]);

      expect(withCurve.yMax, greaterThan(1000),
          reason: '曲线探得比数据高时窗口必须跟着长——裁掉那一段在屏幕上看起来就像曲线断了');
      expect(withCurve.yMax, greaterThan(withoutCurve.yMax));
    });

    test('y 窗口里的非有限值被跳过，不会把窗口变成 NaN', () {
      const points = <({double x, double y})>[(x: 1, y: 10), (x: 2, y: 20)];
      final window =
          regressionGraphYWindow(points, const <double>[double.nan, 15, double.infinity]);
      expect(window.yMin.isFinite, isTrue);
      expect(window.yMax.isFinite, isTrue);
      expect(window.yMin, lessThan(10));
      expect(window.yMax, greaterThan(20));
    });
  });
}

/// 中文：图上那一个 `CustomPaint` 的画笔——断言全在它身上（画了什么，不是有没有一个控件）。
/// English: the painter of the plot's one `CustomPaint` — every assertion is on it (what is painted,
///          not whether some widget exists).
RegressionGraphPainter _painter(WidgetTester tester) {
  final paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
        (widget) => widget.painter is RegressionGraphPainter,
      );
  return paint.painter! as RegressionGraphPainter;
}

TextButton _graphButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, '回归图…'));

Future<void> _openRegressionGraph(WidgetTester tester) async {
  _openStatistics(tester);
  await tester.pumpAndSettle();
  await tester.tap(find.text('回归图…'));
  await tester.pumpAndSettle();
  expect(find.byType(RegressionGraphSheet), findsOneWidget);
}

void _openStatistics(WidgetTester tester) {
  tester
      .widget<CalculatorKeypad>(find.byType(CalculatorKeypad))
      .onKey(_cellByFace('STAT'));
}

Future<void> _press(WidgetTester tester, String id) async {
  tester.widget<CalculatorKeypad>(find.byType(CalculatorKeypad)).onKey(id);
  await tester.pumpAndSettle();
}

/// 中文：先按 `AC` 清掉表达式，再打进 [digits]，然后提交——于是屏幕上那个结果就是这一串。
/// English: press `AC` first to clear the expression, type [digits], then submit — so the result on
///          screen is exactly that run of digits.
Future<void> _type(WidgetTester tester, String digits) async {
  await _press(tester, 'clear');
  for (final digit in digits.split('')) {
    await _press(tester, digit);
  }
  await _press(tester, 'equals');
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

Future<void> _openDatasetSheet(WidgetTester tester) async {
  _openStatistics(tester);
  await tester.pumpAndSettle();
  await tester.tap(find.text('数据集…'));
  await tester.pumpAndSettle();
}

/// 中文：逐个把 [values] 算到屏幕上、加进数据集、再回主屏。
/// English: put each of [values] on screen, add it to the dataset and return to the main screen.
Future<void> _addValues(WidgetTester tester, List<String> values) async {
  for (final value in values) {
    await _type(tester, value);
    await _openDatasetSheet(tester);
    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();
    await _closeSheet(tester);
  }
}

String _cellByFace(String face) {
  for (final row in hiperKeypad.rows) {
    for (final key in row.keys) {
      if (key.base.label == face) return key.base.id;
    }
    for (final label in row.labels) {
      if (label is InlineKey && label.key.base.label == face) {
        return label.key.base.id;
      }
    }
  }
  throw StateError('键位表里没有「$face」这一格');
}

Widget _testApp() {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: CalculatorPage(
        db: _FakeDatabase(),
        onOpenSettings: () {},
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
      ),
    ),
  );
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(_testApp());
  await tester.pumpAndSettle();
}

class _FakeDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
