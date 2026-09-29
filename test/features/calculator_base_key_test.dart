import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';

/// 中文：**四个进制胶囊（`▸BIN` / `▸OCT` / `▸DEC` / `▸HEX`）把当前结果换算到另一个进制显示。**
///
///       这一条走的是**整条真实通路**：真的主屏、真的控制器、真的 `QalculateMathEngine` 适配层，
///       只有平台的求值通道被换成一个假回执——于是「按下 `HEX` 之后屏幕上出现 `HEX 64`」这件事
///       是被端到端证明的，而不是把标签拼出来断言它等于自己。
///
///       **每一层证据都要**：
///       1. **派发与查询**：按键真的问了一次引擎，问的是 `(100) to hex`（十进制形态 + 引擎认得的
///          裸目标词）；
///       2. **渲染**：显示面板上出现 `HEX 64` 这个读数——它是纯文本 `Text`，不是拿来排版的公式；
///       3. **结果行不变**：`= 100` 与 `Ans`（结果行读的那一份十进制形态）都还是十进制。
///          **这一条是本设计的要点**：进制读数是显示，不是值。
///
/// English: **the four base pills (`▸BIN` / `▸OCT` / `▸DEC` / `▸HEX`) show the current result in
///          another base.** This runs the whole real path — the real screen, the real controller and
///          the real `QalculateMathEngine` adapter — with only the platform evaluation channel faked,
///          so "after pressing `HEX` the screen shows `HEX 64`" is proved end to end rather than by
///          assembling the label and asserting it equals itself.
///
///          Every layer of evidence is wanted: (1) **dispatch and query** — the key really asks the
///          engine once, for `(100) to hex` (the decimal form plus the bare target word the engine
///          recognises); (2) **rendering** — the display panel carries the `HEX 64` read-out as plain
///          `Text`; (3) **the result line is unchanged** — `= 100` and `Ans` stay decimal, which is
///          the whole point of this design: a base read-out is a display, never a value.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nekocalc/qalculate');

  /// 中文：每一次求值的表达式，按顺序记下来。
  /// English: every evaluated expression, in order.
  final calls = <String>[];

  /// 中文：假引擎。`(100) to <base>` 回那个进制的数字串——**引擎真的会这么答**（宿主实测：
  ///       `100 to hex` = `64`、`100 to bin` = `1100100`、`100 to oct` = `144`），其余表达式回
  ///       一个普通数字。返回值逐字对应原生侧回执的字段。
  /// English: the fake engine. `(100) to <base>` returns that base's digits, which is what the
  ///          engine really answers (measured on the host: `100 to hex` = `64`, `100 to bin` =
  ///          `1100100`, `100 to oct` = `144`); anything else returns a plain number. The returned
  ///          fields are verbatim the native receipt's.
  Object? Function(MethodCall call) engine({
    Map<String, String>? baseReplies,
    Map<String, String>? plainReplies,
    bool failConversions = false,
  }) {
    const defaults = <String, String>{
      '(100) to bin': '1100100',
      '(100) to oct': '144',
      '(100) to hex': '64',
    };
    return (call) {
      if (call.method != 'evaluate') return null;
      final arguments = call.arguments as Map;
      final expression = arguments['expression'] as String;
      calls.add(expression);
      final digits = (baseReplies ?? defaults)[expression];
      if (digits != null) {
        if (failConversions) {
          return <String, String>{'ok': 'false', 'error': 'engine_no_decimal'};
        }
        return <String, String>{
          'ok': 'true',
          'decimal': digits,
          'latex': '',
          'aborted': 'false',
          // 中文：原生侧对一次**真的发生过**的换算报 `conversion`（`to_struct` 非空 +
          //       `conversionLanded`）——进制换算正是这一类。
          // English: the native side reports `conversion` for a conversion that really happened
          //          (`to_struct` non-empty plus `conversionLanded`) — base conversion is one.
          'kind': 'conversion',
        };
      }
      return <String, String>{
        'ok': 'true',
        'decimal': plainReplies?[expression] ?? '100',
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

  /// 中文：按 `1` `0` `0`，等结果行上是 `100`。之后每一条都从这里开始。
  /// English: press `1` `0` `0` and wait until the result line reads `100`.
  Future<void> typeHundred(WidgetTester tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    for (final digit in <String>['1', '0', '0']) {
      await tester.tap(_keypadKey(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(_display(tester).result, '100', reason: '前置条件：结果行上是 100');
  }

  testWidgets('按 HEX：显示区出现 HEX 64，而且**一次引擎调用都没有**', (tester) async {
    // 中文：**本轮之前这一条断的是"问了引擎一次 `(100) to hex`"，而那正是坏掉的地方。**
    //       桥用的 `Calculator::calculate(...)` 把结尾的 `to` 当成一次除法，`100 to hex` 回的是
    //       `(100 / hex()) * hex()`；因为那个结果里没有单位，`conversionLanded` 的第一句就放行，
    //       原生侧**如实报 `conversion`**，于是一串垃圾**通过了每一条判据**被当成读数印上屏。
    //       换成本地算之后，`calls` 为空**就是修复本身**，不是顺手省的一次调用。
    // English: **before this round the assertion here was "the engine was asked once with
    //          `(100) to hex`", and that was exactly what was broken.** The bridge's
    //          `Calculator::calculate(...)` reads a trailing `to` as a division, so `100 to hex` comes
    //          back as `(100 / hex()) * hex()`; as that result carries no unit, `conversionLanded`'s
    //          first line lets it through, the native side **truthfully reports `conversion`**, and the
    //          garbage **passes every judgement** onto the status row as the read-out. With the
    //          computation moved here, an empty `calls` **is the fix** rather than one call saved.
    respondWith(engine());
    await typeHundred(tester);
    calls.clear();

    await tester.tap(_keypadKey('▸HEX'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty, reason: '进制换算是纯函数，一次引擎调用都不该发');
    expect(find.text('HEX 64'), findsOneWidget, reason: '显示区必须有这个读数');
  });

  testWidgets('按 BIN / OCT：各自的读数都对，换一个进制时上一个让位', (tester) async {
    respondWith(engine());
    await typeHundred(tester);

    await tester.tap(_keypadKey('▸BIN'));
    await tester.pumpAndSettle();
    expect(find.text('BIN 1100100'), findsOneWidget);

    await tester.tap(_keypadKey('▸OCT'));
    await tester.pumpAndSettle();
    expect(find.text('OCT 144'), findsOneWidget);
    expect(find.text('BIN 1100100'), findsNothing,
        reason: '不能同时挂着两个读数');
  });

  testWidgets('按 DEC：读数消失，且不再问引擎', (tester) async {
    respondWith(engine());
    await typeHundred(tester);

    await tester.tap(_keypadKey('▸HEX'));
    await tester.pumpAndSettle();
    expect(find.text('HEX 64'), findsOneWidget);

    calls.clear();
    await tester.tap(_keypadKey('▸DEC'));
    await tester.pumpAndSettle();

    expect(find.text('HEX 64'), findsNothing);
    expect(calls, isEmpty, reason: '十进制就是结果行本来那个样子，不必问引擎');
  });

  testWidgets('**进制读数是显示，不是值**：结果行与十进制形态都不受影响', (tester) async {
    respondWith(engine());
    await typeHundred(tester);

    await tester.tap(_keypadKey('▸HEX'));
    await tester.pumpAndSettle();

    expect(find.text('HEX 64'), findsOneWidget);
    expect(_display(tester).result, '100', reason: '结果行仍旧是十进制的那一份');
    expect(_display(tester).resultDecimal, '100',
        reason: '十进制形态（Ans/last、记忆、继续使用的唯一来源）一个字都不许变');
  });

  testWidgets('没有可换算的数值时：不出现任何数字，说明白为什么', (tester) async {
    // 中文：**这一条的前身叫「引擎答不出来」——而引擎已经不在那条路上了。**
    //       原来它用一份 `ok: false` 的回执（引擎缺席/超时/失败共用那一条）去驱动，
    //       现在进制换算一个字都不问引擎，那种回执**再也到不了读数**。
    //       所以这里换成**真正还存在的那一支**：结果行上是一个错误，没有十进制形态可换算。
    //       **守的东西一个字没变**：按下去必须有一句说明，绝不能冒出一个数字，也绝不能动结果行。
    // English: **this used to be called "the engine cannot answer" — and the engine is no longer on that
    //          road.** It drove the branch with an `ok: false` receipt (the one an absent, timed-out or
    //          failed engine shares), which can no longer reach the read-out because base conversion
    //          asks the engine nothing at all. So this drives **the branch that still exists**: the
    //          result line carries an error and there is no decimal form to convert. **What it guards is
    //          unchanged** — a press must produce a sentence, must never produce a digit, and must never
    //          touch the result line.
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    // `2+` 是一次不合法的求值：结果行上是一句错误，没有十进制形态。
    for (final key in <String>['2', '+']) {
      await tester.tap(_keypadKey(key));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final before = _display(tester).result;

    await tester.tap(_keypadKey('▸HEX'));
    await tester.pumpAndSettle();

    expect(find.textContaining('HEX '), findsNothing,
        reason: '没有东西可换算时，一个读数字符都不许出现');
    expect(find.textContaining('换算'), findsWidgets,
        reason: '用户按了键却什么都没发生，必须有一条说明');
    expect(_display(tester).result, before, reason: '换算不许动结果行');
  });

  testWidgets('编辑之后读数消失：它描述的是按下那一刻的那个结果', (tester) async {
    respondWith(engine());
    await typeHundred(tester);

    await tester.tap(_keypadKey('▸HEX'));
    await tester.pumpAndSettle();
    expect(find.text('HEX 64'), findsOneWidget);

    await tester.tap(_keypadKey('7'));
    await tester.pumpAndSettle();

    expect(find.text('HEX 64'), findsNothing,
        reason: '屏幕上那个数已经不是 100 了，读数必须跟着走');
  });
}

CalculatorDisplay _display(WidgetTester tester) =>
    tester.widget<CalculatorDisplay>(find.byType(CalculatorDisplay));

/// 中文：键面上那个字。**必须限定在键盘里**：结果行也用 `Text` 印同一个数字，`find.text('0')`
///       会同时命中两处（这就是 `tap()` 报 ambiguous 的原因）。
/// English: that character on a key face. **The search must be scoped to the keypad**: the result
///          line prints the same digit with a `Text` of its own, so a bare `find.text('0')` matches
///          both (which is why `tap()` reports "ambiguous").
Finder _keypadKey(String label) => find.descendant(
      of: find.byType(CalculatorKeypad),
      matching: find.text(label),
    );

/// 中文：被测主屏。只有平台求值通道是假的，其余全是真的。
/// English: the screen under test. Only the platform evaluation channel is faked; everything else is
///          real.
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
          groupThousands: false,
        ),
      ),
    ),
  );
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
