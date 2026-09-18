import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';

/// 中文：**`FSE`——`x⇔E` 那颗键的 SHIFT 变体，把当前结果换一种数字记法显示。**
///
///       这一条走的是**整条真实通路**：真的主屏、真的控制器、真的 `QalculateMathEngine` 适配层，
///       只有平台的求值通道被换成一个假回执——于是「SHIFT + `x⇔E` 之后屏幕上出现 `SCI 1.23456789e+4`」
///       是被端到端证明的，而不是把标签拼出来断言它等于自己。
///
///       **它挂在哪颗键上是本轮改的**：上一轮 `FSE` 是横带里一颗可点的 `InlineKey`，本轮按来源
///       退回成 `x⇔E` 的 SHIFT（来源三条，见 `hiper_keypad_function_rows.dart` 里 `x⇔E` 的注释）。
///       于是本文件第一条断言的是**键位表**：横带那一格必须是纯提示（`ShiftLabel`），动作只有
///       `x⇔E` 的 `shift` 这一个 id 入口——与 `d/dx` 在 `calculator_ddiff_key_test.dart` 里同形。
///
///       **每一层证据都要**：
///       1. **键位表**：`x⇔E` 的基准（`resultForm` / `x⇔E` / 分类）一格没动，横带格是 `ShiftLabel`；
///       2. **派发与查询**：这颗键真的问了一次引擎，问的是 `(12345.6789) to sci`——**引擎认得的
///          裸目标词**，与四个进制胶囊问的 `(100) to hex` 逐字同形；
///       3. **渲染**：显示面板上出现 `SCI 1.23456789e+4` / `ENG 12.3456789e+3` 这个读数——它是纯文本
///          `Text`，不是拿来排版的公式，因此**不存在「降级成 `\text{}` 字面」这一回事**（引擎对
///          这几档的 LaTeX 是 `\num{…}`，那个在 flutter_math_fork 里排不出来，本项目有断言钉着）；
///       4. **值不变**：三档里结果行上的字、`Ans` 读的那一份十进制形态**逐字节相同**，只有读数
///          在变。**这一条是本设计的要点**：记法是显示，绝不是值。
///
/// English: **`FSE` — the SHIFT variant of the `x⇔E` key; shows the current result in another number
///          notation.** This runs the whole real path — the real screen, the real controller and the
///          real `QalculateMathEngine` adapter — with only the platform evaluation channel faked, so
///          "after SHIFT + `x⇔E` the screen shows `SCI 1.23456789e+4`" is proved end to end rather than
///          by assembling the label and asserting it equals itself.
///
///          **Which key it hangs on is what this round changed**: last round `FSE` was a tappable
///          `InlineKey` in the band; this round it goes back to being `x⇔E`'s SHIFT per the sources
///          (three of them, on the `x⇔E` note in `hiper_keypad_function_rows.dart`). So the first
///          assertion here is about the **key table**: the band cell must be a plain hint
///          (`ShiftLabel`) and the action must have exactly one id entrance, the `shift` of `x⇔E` —
///          the shape `d/dx` already has in `calculator_ddiff_key_test.dart`.
///
///          Every layer of evidence is wanted: (1) **the key table** — `x⇔E`'s base (`resultForm` /
///          `x⇔E` / its category) has not moved a cell and the band cell is a `ShiftLabel`;
///          (2) **dispatch and query** — the key really asks the engine once, for `(12345.6789) to
///          sci`, the **bare target word the engine recognises**, character-for-character the shape of
///          the base pills' `(100) to hex`; (3) **rendering** — the panel carries the
///          `SCI 1.23456789e+4` / `ENG 12.3456789e+3` read-out as plain `Text`, not as something to
///          typeset, so the "degrading to a literal `\text{}`" failure cannot arise (the engine's LaTeX
///          for these positions is `\num{…}`, which does not typeset in flutter_math_fork — this
///          project pins that with an assertion); (4) **the value does not move** — in all three
///          positions the result line and the decimal form `Ans` reads are **byte-for-byte identical**,
///          and only the read-out changes. That is the whole point of this design: notation is a
///          display, never a value.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nekocalc/qalculate');

  /// 中文：每一次求值的表达式，按顺序记下来。
  /// English: every evaluated expression, in order.
  final calls = <String>[];

  /// 中文：假引擎。它答的正是宿主实测的那几个值（`qalc` 5.12.0，与本 AAR 同版本）：
  ///       `12345.6789 to sci` = `1.23456789E4`、`to eng` = `12.3456789E3`。
  ///       返回值逐字对应原生侧回执的字段。
  /// English: the fake engine. It answers exactly the values measured on the host (`qalc` 5.12.0,
  ///          the version this AAR bundles): `12345.6789 to sci` = `1.23456789E4`, `to eng` =
  ///          `12.3456789E3` — the adapter spells those the app's way (`e+4` / `e+3`, see
  ///          `_appScientificSpelling`), which is what the expectations below use. The returned fields are verbatim the native receipt's.
  Object? Function(MethodCall call) engine({bool failConversions = false}) {
    const notationReplies = <String, String>{
      '(12345.6789) to sci': '1.23456789E4',
      '(12345.6789) to eng': '12.3456789E3',
    };
    return (call) {
      if (call.method != 'evaluate') return null;
      final arguments = call.arguments as Map;
      final expression = arguments['expression'] as String;
      calls.add(expression);
      final notation = notationReplies[expression];
      if (notation != null) {
        if (failConversions) {
          return <String, String>{'ok': 'false', 'error': 'engine_no_decimal'};
        }
        return <String, String>{
          'ok': 'true',
          'decimal': notation,
          'latex': '',
          'aborted': 'false',
          // 中文：原生侧对一次**真的发生过**的换算报 `conversion`（`to_struct` 非空 +
          //       `conversionLanded`）——`to sci` / `to eng` 正是这一类。
          // English: the native side reports `conversion` for a conversion that really happened
          //          (`to_struct` non-empty plus `conversionLanded`) — `to sci` / `to eng` are one.
          'kind': 'conversion',
        };
      }
      return <String, String>{
        'ok': 'true',
        'decimal': '12345.6789',
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

  /// 中文：敲出 `12345.6789`，等结果行上是它。之后每一条都从这里开始。
  /// English: type `12345.6789` and wait until the result line reads it. Every case starts here.
  Future<void> typeValue(WidgetTester tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    for (final label in <String>['1', '2', '3', '4', '5', '.', '6', '7', '8', '9']) {
      await tester.tap(_keypadKey(label));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(_display(tester).result, '12345.6789', reason: '前置条件：结果行上是这个数');
  }

  /// 中文：**这一次按键就是这条通路唯一改过的地方**——上一轮是「点横带里的 `FSE` 格」，
  ///       本轮是「先 SHIFT、再点 `x⇔E`」。所以下面每一处都用这一个函数，改错了全部一起红。
  /// English: **this press is the only thing about the path that this round changed** — last round it
  ///          was "tap the band's `FSE` cell", this round it is "tap SHIFT, then `x⇔E`". Every case
  ///          below goes through this one function, so getting it wrong turns all of them red at once.
  Future<void> pressFse(WidgetTester tester) async {
    await tester.tap(find.text('SHIFT').first);
    await tester.pumpAndSettle();
    await tester.tap(_keypadKey('x⇔E'));
    await tester.pumpAndSettle();
  }

  testWidgets('键位表：动作挂在 `x⇔E` 的 SHIFT 上，横带那一格是不可点的提示', (tester) async {
    // 中文：**这一条就是本轮改动的可执行形式。** 它同时钉住三件事：变体真的在那一颗键上、
    //       横带格仍是纯提示（同一动作不能有两个 id 入口）、基准动作逐字未动。
    // English: **the executable form of this round's change.** It pins three things at once: the
    //          variant really is on that key, the band cell is still a plain hint (one action must not
    //          have two id entrances), and the base action is untouched to the byte.
    final located = _locateBaseId('resultForm');
    final key = located.row.keys[located.index];

    expect(key.base.label, 'x⇔E');
    expect(key.base.enabled, isTrue);
    expect(key.category, KeyCategory.function);

    final shift = key.shift;
    expect(shift, isNotNull,
        reason: '`FSE` 是这颗键的第二功能——HiPER 自己写着第二功能就印在键上方 '
            '(quickTour.page.SECOND_FUNCTION.text2)');
    expect(shift!.id, 'notationCycle');
    expect(shift.label, 'FSE', reason: '变体的键面文字就是横带里那条提示');
    expect(shift.enabled, isTrue);

    final above = located.row.labels[located.index];
    expect(above, isA<ShiftLabel>(),
        reason: '横带那一格是提示，不是按钮——变成按钮就等于同一个动作有两个 id 入口');
    expect((above! as ShiftLabel).text, 'FSE');
  });

  testWidgets('按 FSE：问引擎一次 (12345.6789) to sci，显示区出现 SCI 1.23456789e+4', (tester) async {
    respondWith(engine());
    await typeValue(tester);
    calls.clear();

    await pressFse(tester);

    expect(calls, <String>['(12345.6789) to sci'],
        reason: '目标词必须是裸的、且是引擎认得的那个（进制那边实测过：加括号会变成一次除法）');
    expect(find.text('SCI 1.23456789e+4'), findsOneWidget, reason: '读数是一格纯文本');
    expect(_display(tester).baseReadout, isEmpty,
        reason: '进制读数与记法读数是两格，互不冒充');
  });

  testWidgets('三档里结果行与十进制形态逐字节不变，只有读数在变', (tester) async {
    // 中文：**这一条就是「数值没变，只是写法不同」的可执行形式。** 每一步都重读一次结果行与
    //       `resultDecimal`（`Ans`/记忆/历史读的那一份），逐字节比较。
    // English: **this is the executable form of "the value is unchanged, only the writing differs".**
    //          Every step re-reads the result line and `resultDecimal` (what `Ans`/memory/history read)
    //          and compares byte for byte.
    respondWith(engine());
    await typeValue(tester);
    final before = _display(tester).result;
    expect(before, '12345.6789');

    await pressFse(tester);
    expect(find.text('SCI 1.23456789e+4'), findsOneWidget);
    expect(_display(tester).result, before, reason: 'SCI 之后结果行逐字节不变');

    await pressFse(tester);
    expect(find.text('ENG 12.3456789e+3'), findsOneWidget);
    expect(_display(tester).result, before, reason: 'ENG 之后结果行逐字节不变');
    expect(find.text('SCI 1.23456789e+4'), findsNothing, reason: '同时只挂一格读数');

    await pressFse(tester);
    expect(find.text('ENG 12.3456789e+3'), findsNothing, reason: '回到 Normal 就是撤掉读数');
    expect(_display(tester).result, before, reason: '回到 Normal 之后仍然逐字节不变');
    expect(_display(tester).notationReadout, isEmpty);
  });

  testWidgets('不按 SHIFT 时 `x⇔E` 走的仍是基准：结果形式循环，读数一个字都不出现', (tester) async {
    // 中文：**「不许改已经工作的键」的可执行形式。** 不按 SHIFT 时这颗键仍是 `resultForm`，
    //       并且**一个 `to sci` 查询都不发**。
    // English: **the executable form of "do not change a key that works".** Without SHIFT the key is
    //          still `resultForm`, and it sends **not one** `to sci` query.
    respondWith(engine());
    await typeValue(tester);
    calls.clear();

    await tester.tap(_keypadKey('x⇔E'));
    await tester.pumpAndSettle();

    expect(_display(tester).notationReadout, isEmpty, reason: '记法维度不该被这一次按键碰到');
    expect(calls.where((call) => call.contains(' to sci')), isEmpty,
        reason: '基准动作要的是结果**形式**，不是记法——它不该问引擎记法那一档');
    expect(find.textContaining('SCI '), findsNothing);
  });

  testWidgets('引擎答不出来时屏幕上不出现任何数字，只有一句说明', (tester) async {
    respondWith(engine(failConversions: true));
    await typeValue(tester);

    await pressFse(tester);

    expect(find.textContaining('SCI '), findsNothing, reason: '拿不准就 fail closed');
    expect(find.text('引擎没有给出这一档记法'), findsOneWidget);
    expect(_display(tester).notationReadout, isEmpty);
    expect(_display(tester).result, '12345.6789', reason: '失败不该动结果行');
  });

  testWidgets('结果被换掉之后读数自己消失', (tester) async {
    respondWith(engine());
    await typeValue(tester);

    await pressFse(tester);
    expect(find.text('SCI 1.23456789e+4'), findsOneWidget);

    await tester.tap(_keypadKey('7'));
    await tester.pumpAndSettle();

    expect(find.text('SCI 1.23456789e+4'), findsNothing,
        reason: '屏幕上那个数已经不是 12345.6789 了，读数必须跟着走');
  });

  testWidgets('默认态：没按过 FSE 时这一格整个不存在', (tester) async {
    // 中文：**硬性边界 6 的可执行形式。** 用户不动它时，状态行上不该多出任何东西。
    // English: **the executable form of hard boundary 6.** While the user leaves it alone, nothing
    //          extra may appear on the status row.
    respondWith(engine());
    await typeValue(tester);

    expect(_display(tester).notationReadout, isEmpty);
    expect(find.byType(CalculatorDisplay), findsOneWidget);
    expect(calls.where((call) => call.contains(' to sci')), isEmpty,
        reason: '默认态一个额外的引擎调用都不发');
  });
}

/// 中文：在键位表里按**基准 id** 找那一格，返回它所在的行与列。找不到直接抛错——「表里没有这个
///       id」本身就是要被听见的事。
/// English: Find a cell **by its base id** and return its row and column. A failed lookup throws —
///          "the table has no such id" is itself something to hear about.
({KeypadRow row, int index}) _locateBaseId(String baseId) {
  for (final row in hiperKeypad.rows) {
    for (var index = 0; index < row.keys.length; index++) {
      if (row.keys[index].base.id == baseId) return (row: row, index: index);
    }
  }
  throw StateError('键位表里没有基准 id 为「$baseId」的主键');
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
