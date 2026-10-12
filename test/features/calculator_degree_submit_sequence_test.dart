import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**一条完整的手上动作：按 `DRG`、打 `sin(90)`、按等号——屏幕上的那个数必须是 1。**
///
///       **它补的是哪一格。** 「`DRG` 键会翻档位」与「引擎收到的是哪一个档位」各自被证明过
///       （`calculator_drg_matrix_band_keys_test.dart` 的横带、`calculator_engine_submit_test.dart`
///       的那个角度参数），但**没有任何一条测试把这两半接起来走一遍**。§5r 在图形页上量到的
///       真缺陷正是这个形状——档位在界面上写着、算的时候没人看它，两边各自都对，合起来是错的。
///
///       所以这一条只走用户那条路：`DRG` 按在键面上、`sin(90)` 一个键一个键打进去、`✓` 按下去，
///       然后断言**结果行上的那个数**是 1，并且弧度制的那个答案 `0.893997` **一个字都不在屏幕上**。
///       后半句是这条测试的判据：没有它，「屏幕上出现了一个数」与「屏幕上出现的是对的数」分不开。
///
///       **最后一段是正反两面。** 再按一次 `DRG`（回到 RAD）、再按一次等号：同一个表达式这时必须
///       给出弧度制的 `0.893997`。没有这一半，一个「不管什么档位都印 1」的实现也能让上面全绿。
///
///       **每次提交要等的那 5 秒是真的**：`flutter test` 里没有原生引擎，提交路径先问它一次，
///       控制器自己的上限 `engineTimeout`（5 秒）到点才回落到旧解析器——真机上没有原生侧时走的
///       是同一条路（DEG 由应用自己那一侧解释，所以这条测的正是这条回落路）。
/// English: **one complete hand action: press `DRG`, type `sin(90)`, press equals — the number on
///          screen must be 1.**
///
///          **The cell this fills.** "The `DRG` key flips the mode" and "the engine receives the
///          right angle unit" were each proven on their own (`calculator_drg_matrix_band_keys_test.dart`'s
///          band, `calculator_engine_submit_test.dart`'s angle argument), but **no test joins the two
///          halves into one run**. The real defect §5r measured on the graph page has exactly this
///          shape — the mode was written on the interface and nobody read it when computing; each half
///          was right, the pair was wrong.
///
///          So this case walks only the user's road: `DRG` pressed on its key face, `sin(90)` entered
///          key by key, `✓` pressed, and then asserts **the number on the result line** is 1 and that
///          the radian answer `0.893997` is **not a character of it anywhere on screen**. The second
///          half is this test's criterion: without it, "a number appeared" and "the right number
///          appeared" are indistinguishable.
///
///          **The last section is both sides.** Press `DRG` again (back to RAD) and equals again: the
///          same expression must now give the radian `0.893997`. Without that half, an implementation
///          that prints 1 under any mode would keep everything above green.
///
///          **The five seconds each submit waits are real**: there is no native engine under
///          `flutter test` and the submit path asks it first; the controller's own cap
///          `engineTimeout` (5 s) releases it into the legacy parser — the same road a device without
///          a native side takes, and the legacy side is what interprets DEG, so that is exactly the
///          road being measured.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('DRG → sin(90) → 等号：结果行上是 1；切回 RAD 再按一次是 0.893997', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();
    expect(find.text('RAD'), findsOneWidget, reason: '起始档位来自设置（RAD）');

    // 中文：第一下是那颗模式键的真身。它不往表达式里插东西，所以那一行仍是空的。
    // English: the first press is the mode key itself. It inserts nothing, so the expression line
    //          is still empty.
    await _tapKey(tester, 'DRG');
    expect(find.text('DEG'), findsOneWidget,
        reason: '按了 DRG，屏幕上的档位记号必须是 DEG——用户看得见的那一半');
    expect(_displayedExpression(tester), '');

    await _tapKey(tester, '9');
    await _tapKey(tester, '0');
    await _tapKey(tester, 'sin');
    expect(_displayedExpression(tester), 'sin(90)',
        reason: '`sin` 包住光标前那个值：`90` 进去，出来的是 `sin(90)`');

    await _tapKey(tester, '✓');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    _expectResultOnScreen(tester, '1');
    expect(
      find.descendant(
        of: find.byType(CalculatorDisplay),
        matching: find.textContaining('0.893997'),
      ),
      findsNothing,
      reason: '`0.893997` 是弧度制下的答案——它出现在屏幕上，就说明这一次算的时候没看档位',
    );

    // 中文：**反面。** 同一个表达式、同一条路径，档位换回 RAD，答案就必须跟着换。
    // English: **the other side.** Same expression, same road, the mode back to RAD — the answer
    //          must follow.
    await _tapKey(tester, 'DRG');
    expect(find.text('RAD'), findsOneWidget);
    await _tapKey(tester, '✓');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    _expectResultOnScreen(tester, '0.893997');
    expect(
      find.descendant(
        of: find.byType(CalculatorDisplay),
        matching: find.text('1'),
      ),
      findsNothing,
      reason: 'RAD 下屏幕上的结果不该还是 DEG 的那个 1',
    );
  });
}

/// 中文：**结果行上的那个数**——键盘上有同名的数字键，所以查找限定在显示面板里。
/// English: **the number on the result line** — the keypad carries same-named digit keys, so the
///          lookup stays inside the display panel.
void _expectResultOnScreen(WidgetTester tester, String result) {
  expect(
    find.descendant(
      of: find.byType(CalculatorDisplay),
      matching: find.text(result),
    ),
    findsOneWidget,
    reason: '结果 $result 必须真的画在显示面板里',
  );
}

Future<void> _tapKey(WidgetTester tester, String face) async {
  await tester.tap(find.descendant(
    of: find.byType(CalculatorKeypad),
    matching: find.text(face, findRichText: true),
  ));
  await tester.pumpAndSettle();
}

String _displayedExpression(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).expression;

Widget _page() {
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
