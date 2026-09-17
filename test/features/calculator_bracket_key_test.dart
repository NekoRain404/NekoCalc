import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**主屏按键级**的两个缺陷——按的是键位表里那两颗真实的键（`√x`、`)`、`⌫`），
///       走的是真实的主屏、真实的控制器，量的是表达式行上**显示出来的那串原文**与结果行。
///
///       控制器一级的证明在 `test/domain/calculator_bracket_editing_test.dart`；这里补的是
///       「那颗键真的派发到了那条路上」——`)` 与 `⌫` 走的是 `input()`/`backspace()` 的默认派发，
///       而缺陷是在**按键**这一层被报出来的（真机实测：`√x`、`8`、`)`）。
///
/// English: **keypad-level** versions of the two defects — the real keys from the key table (`√x`,
///          `)`, `⌫`) go through the real screen and the real controller, and the assertions read the
///          **expression source actually shown** on the expression line plus the result line.
///
///          The controller-level proof lives in `test/domain/calculator_bracket_editing_test.dart`;
///          what this file adds is "that key really reaches that path" — `)` and `⌫` travel the
///          default dispatch of `input()`/`backspace()` — because the defects were reported at the
///          **keystroke** level (measured on a device: `√x`, `8`, `)`).
void main() {
  testWidgets('主屏按 √x、8、)：表达式行是 sqrt(8)，不是应用自己读不懂的 sqrt(8))', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await _tapKey(tester, '√x');
    await _tapKey(tester, '8');

    // 中文：缺陷的中间态：函数键补出的是整对括号，光标停在括号里。
    // English: the defect's intermediate state — the function key writes the whole pair and the
    //          caret sits inside it.
    expect(_displayedExpression(tester), 'sqrt(8)');

    await _tapKey(tester, ')');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      _displayedExpression(tester),
      'sqrt(8)',
      reason: '再按一次 `)` 不该写出第二颗右括号',
    );
    expect(find.text('存在无法识别的内容'), findsNothing);
    expect(find.text('2.828427'), findsOneWidget);
  });

  testWidgets('主屏按 √x 之后按 ⌫：表达式空掉，不留下删不掉的 )', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await _tapKey(tester, '√x');
    expect(_displayedExpression(tester), 'sqrt()');

    // 中文：缺陷的实测形状：光标在 `sqrt(|)` 里，右边的 `)` 退格够不着——一路删下去会停在
    //       光标 0、屏幕上留一个删不掉的 `)`（唯一出口是长按 AC）。这一下应当把整条调用删掉。
    // English: the defect's measured shape — the caret sits in `sqrt(|)` and the `)` on its right
    //          is out of backspace's reach; deleting onwards stops at caret 0 with an undeletable
    //          `)` (the only way out being a long-press on AC). This press must remove the call.
    await _tapKey(tester, '⌫');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_displayedExpression(tester), isEmpty);
    expect(find.text('存在无法识别的内容'), findsNothing);

    // 中文：按错一颗键之后键盘照常可用（真机上这一步原本卡死）。
    // English: after a key pressed by mistake the keypad still works (on a device this was where
    //          the user got stuck).
    await _tapKey(tester, '9');
    expect(_displayedExpression(tester), '9');
    expect(find.text('9'), findsWidgets);
  });
}

/// 中文：按一颗真实的键。**只在键盘子树里找**——显示区会把 `)` 排成自己的一个单元，
///       在整棵树里找会命中它。
/// English: press one real key. It is looked up **inside the keypad subtree only** — the display
///          panel typesets `)` as a unit of its own, and searching the whole tree would hit that.
Future<void> _tapKey(WidgetTester tester, String label) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(CalculatorKeypad),
          matching: find.text(label, findRichText: true),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// 中文：表达式行上显示的原文。结果行在排得出精确形式时才用 `MathExpressionView`（带 TeX），
///       所以不带 TeX 的那一个是表达式行。
/// English: the source shown on the expression line. The result line only uses a
///          `MathExpressionView` when an exact form typesets (it carries TeX), so the one without
///          TeX is the expression line.
String _displayedExpression(WidgetTester tester) {
  final views = find.byWidgetPredicate(
    (widget) => widget is MathExpressionView && widget.tex.isEmpty,
  );
  expect(views, findsOneWidget);
  return tester.widget<MathExpressionView>(views).expression;
}

Widget _testApp() {
  return MaterialApp(
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
