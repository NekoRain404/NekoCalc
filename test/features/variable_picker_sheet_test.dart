import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/ast/tex_emitter.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/variable_picker_sheet.dart';

/// 中文：**`X`/`Y` 两颗键点亮之后的三层证据**，与上一轮 Σ/Π/∫ 那七颗键用的是同一套：
///
///       1. **派发**——按键（或面板上的按钮）落进表达式，文本是预期的样子；
///       2. **排版**——这段表达式经 `ExpressionAstParser` + `TexEmitter` 之后没有降级成字面文本
///          （产物里没有 `\text{…}`），而且渲染器自己的解析器认它；
///       3. **渲染**——真把组件树建出来：表达式那一行底下找不到承载降级文本的那个 `Text`。
///
///       另外还有一条这一步独有的：**绑了值的 `2x` 在屏幕上是一个数**（`8`），而不是那个
///       「看起来完全合理」的 `24`——本页用的是真的 `QalculateMathEngine`，在 `flutter test` 里
///       它没有原生侧，于是这一发必然回落旧解析器，屏幕上那个数只可能是旧解析器算的。
/// English: **the three layers of evidence for the newly lit `X`/`Y` keys**, the same set the seven
///          Σ/Π/∫ keys got last round:
///
///          1. **dispatch** — the press (or the sheet's button) reaches the expression and the text is
///             what it should be;
///          2. **typesetting** — run through `ExpressionAstParser` + `TexEmitter`, the output holds no
///             `\text{…}` (no degradation to literal text) and the renderer's own parser accepts it;
///          3. **rendering** — the widget tree is really built: no `Text` carrying the fallback text
///             exists under the expression line.
///
///          Plus one this step owns: **`2x` with a bound value is a number on screen** (`8`) rather than
///          the perfectly plausible `24`. This page uses the real `QalculateMathEngine`, which has no
///          native side under `flutter test`, so that call necessarily falls back to the legacy parser
///          — the number on screen can only have been computed by it.
void main() {
  group('Y 键：一下把 y 插进表达式', () {
    testWidgets('派发 / 排版 / 渲染三层证据', (tester) async {
      await _pumpPage(tester);
      _press(tester, 'ins:y');
      await tester.pump(const Duration(milliseconds: 250));

      expect(_displayedExpression(tester), 'y');
      expect(_literalTextFragment('y'), isFalse,
          reason: '`y` 被当成了字面文本：'
              '${const TexEmitter().emit(const ExpressionAstParser().parse('y'))}');
      expect(MathExpressionView.typesetsTex(_tex('y')), isTrue);
      expect(_tex('y'), 'y', reason: '变量要按数学斜体排，不是 \\text{y}');
      expect(
        find.descendant(
          of: find.byType(MathExpressionView),
          matching: find.text('y'),
        ),
        findsNothing,
        reason: '`y` 画成了字面文本而不是公式',
      );
    });
  });

  group('X 键：打开变量面板', () {
    testWidgets('按下去打开的是变量面板，不是插一段文本', (tester) async {
      await _pumpPage(tester);
      expect(find.byType(VariablePickerSheet), findsNothing);

      _press(tester, 'openVariables');
      await tester.pumpAndSettle();

      expect(find.byType(VariablePickerSheet), findsOneWidget);
      expect(_displayedExpression(tester), isEmpty,
          reason: '打开面板本身不往表达式里写任何东西');
    });

    testWidgets('面板上的「插入 x」把 x 插进表达式，排版正确', (tester) async {
      await _pumpPage(tester);
      _press(tester, 'openVariables');
      await tester.pumpAndSettle();

      await tester.tap(find.text('插入 x'));
      await tester.pumpAndSettle();

      expect(_displayedExpression(tester), 'x');
      expect(_literalTextFragment('x'), isFalse);
      expect(_tex('x'), 'x', reason: '变量要按数学斜体排，不是 \\text{x}');
      expect(MathExpressionView.typesetsTex(_tex('x')), isTrue);
    });

    testWidgets('没有可存的数值时「存入当前值」是灰的，有可存的值时是亮的', (tester) async {
      await _pumpPage(tester);

      // 中文：表达式为空时屏幕上是 `MathResult.zero`（十进制 `0`），**可以**存——先看这一头。
      // English: an empty expression leaves `MathResult.zero` (decimal `0`), which *is* storable —
      //          look at that end first.
      _press(tester, 'openVariables');
      await tester.pumpAndSettle();
      expect(_assignButtons(tester), everyElement(isNotNull));
      expect(find.text('当前值 0'), findsOneWidget);

      // 中文：`(` 让两条路都答不出来（引擎没有原生侧、旧解析器缺右括号），结果因此没有十进制形态，
      //       按钮跟着置灰。**看得见的拒绝**——不是按下去没反应。
      // English: `(` leaves neither path able to answer (the engine has no native side, and the legacy
      //          parser is missing a bracket), so the result has no decimal form and the button goes
      //          dark. **A visible refusal** rather than a dead button.
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      _press(tester, 'clear');
      _press(tester, '(');
      await tester.pump(const Duration(milliseconds: 250));
      _press(tester, 'openVariables');
      await tester.pumpAndSettle();

      expect(_assignButtons(tester), everyElement(isNull));
      expect(find.textContaining('当前没有可存入的数值'), findsOneWidget);

      // 中文：未赋值的变量没有东西可清除。
      // English: an unbound variable has nothing to clear.
      expect(find.text('清除'), findsNWidgets(2));
      expect(_clearButtons(tester), everyElement(isNull));
    });
  });

  group('绑了值的变量：屏幕上是一个数', () {
    testWidgets('`2x`（x=4）在结果行上是 8，不是 24', (tester) async {
      await _pumpPage(tester);

      // 中文：先按出一个 4，把它存进 x。走的是真实按键流：数字键 → `X` → 「存入当前值」。
      // English: press a 4 and store it into x, through the real flow: digit key → `X` → "store
      //          current value".
      _press(tester, '4');
      await tester.pump(const Duration(milliseconds: 250));
      _press(tester, 'openVariables');
      await tester.pumpAndSettle();
      await tester.tap(find.text('存入当前值').first);
      await tester.pumpAndSettle();

      expect(find.text('= 4'), findsOneWidget, reason: '面板上的读数要跟着变');
      expect(find.text('未赋值'), findsOneWidget, reason: 'y 还没赋值');

      // 中文：关掉面板，清空，再按 `2` 和面板里的「插入 x」——表达式成了 `2x`。
      // English: close the sheet, clear, then press `2` and the sheet's "insert x" — the expression
      //          becomes `2x`.
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      _press(tester, 'clear');
      _press(tester, '2');
      await tester.pump(const Duration(milliseconds: 250));
      _press(tester, 'openVariables');
      await tester.pumpAndSettle();
      await tester.tap(find.text('插入 x'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));

      expect(_displayedExpression(tester), '2x');
      expect(_inDisplay(find.text('= 8')), findsNothing);
      expect(_inDisplay(find.text('8')), findsOneWidget,
          reason: '结果行上应该是一个数');
      expect(_inDisplay(find.text('24')), findsNothing,
          reason: '把 `x` 直接换成 `4` 会得到 24——那正是这一步最危险的错值');
    });

    testWidgets('解绑之后同一条 `2x` 回到符号式（屏幕上是 `2x` 而不是数）', (tester) async {
      await _pumpPage(tester);

      _press(tester, '4');
      await tester.pump(const Duration(milliseconds: 250));
      _press(tester, 'openVariables');
      await tester.pumpAndSettle();
      await tester.tap(find.text('存入当前值').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除').first);
      await tester.pumpAndSettle();

      expect(find.text('未赋值'), findsNWidgets(2));

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      _press(tester, 'clear');
      _press(tester, '2');
      await tester.pump(const Duration(milliseconds: 250));
      _press(tester, 'openVariables');
      await tester.pumpAndSettle();
      await tester.tap(find.text('插入 x'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));

      expect(_displayedExpression(tester), '2x');
      // 中文：没有原生侧，引擎这一发答不出来；旧解析器读不懂 `2x`，于是结果行上**不是**一个数，
      //       而是那个应用一向给出的错误（`Unexpected token` → 「存在无法识别的内容」）。这一条钉的
      //       是「解绑之后不许再拿绑定时的值去算」。
      // English: with no native side the engine cannot answer, and the legacy parser cannot read
      //          `2x`, so the result line is **not** a number but the error this app has always given
      //          for that input (`Unexpected token` → "存在无法识别的内容"). This pins "after
      //          unbinding, the old value must not still be used".
      expect(_inDisplay(find.text('8')), findsNothing);
      expect(_inDisplay(find.text('存在无法识别的内容')), findsOneWidget);
    });
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(_testApp());
  await tester.pump();
}

void _press(WidgetTester tester, String key) {
  tester.widget<CalculatorKeypad>(find.byType(CalculatorKeypad)).onKey(key);
}

String _tex(String expression) =>
    const TexEmitter().emit(const ExpressionAstParser().parse(expression));

String _displayedExpression(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).expression;

/// 中文：面板上那两个「存入当前值」按钮的 `onPressed`（`x` 一行、`y` 一行）。置灰与否是**看得见的
///       判断**，所以要按按钮本身断言，而不是按面板上那句话。
/// English: the two "store current value" buttons' `onPressed` (one row for `x`, one for `y`). Whether
///          they are greyed out is a **visible judgement**, so the assertion is on the buttons
///          themselves rather than on the sentence above them.
Iterable<VoidCallback?> _assignButtons(WidgetTester tester) => tester
    .widgetList<TextButton>(
        find.ancestor(of: find.text('存入当前值'), matching: find.byType(TextButton)))
    .map((button) => button.onPressed);

Iterable<VoidCallback?> _clearButtons(WidgetTester tester) => tester
    .widgetList<TextButton>(
        find.ancestor(of: find.text('清除'), matching: find.byType(TextButton)))
    .map((button) => button.onPressed);

/// 中文：把一次查找限制在**显示区**里。键盘上也有写着 `8`、`24` 的键面文字，不限定范围的话
///       `find.text('8')` 会把数字键一起找出来。
/// English: confines a lookup to the **display panel**. The keypad's faces carry `8` and `24` too, so
///          an unqualified `find.text('8')` would collect the digit key along with the result.
Finder _inDisplay(Finder matching) => find.descendant(
      of: find.byType(CalculatorDisplay),
      matching: matching,
    );

bool _literalTextFragment(String expression) =>
    _tex(expression).contains(r'\text{');

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
