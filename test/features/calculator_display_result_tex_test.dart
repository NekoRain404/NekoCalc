import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

// 中文：结果行的**两种形态**（步骤 4）。左边是输入，右边是屏幕上该出现什么：
//
//       - 精确形式排得出来、又不是同一个数的另一种写法 → `= <排版> ≈ <十进制>`；
//       - 其余四种情形（没有 LaTeX、LaTeX 排不出来、LaTeX 就是那串十进制、自然排版关掉）
//         → `= <十进制>`，纯文本，一字不差就是接入引擎之前的那一行。
//
//       这里用的 LaTeX 全部是**实测**出来的引擎输出（`qalc` 5.12.0，与 App 里那个
//       libqalculate 同一个版本、同一组 PrintOptions）：`2\times \sqrt{2}` 排得出来，
//       `\num{0.3333333333333333}` 排不出来。
// English: The result line's **two shapes** (step 4). On the left the input, on the right what
//          should appear on screen:
//
//          - the exact form typesets and is not the same number written differently →
//            `= <typeset> ≈ <decimal>`;
//          - the other four cases (no LaTeX, LaTeX that does not typeset, LaTeX that *is* that
//            decimal, natural typesetting switched off) → `= <decimal>`, plain text, character for
//            character the line that existed before the engine was wired in.
//
//          Every LaTeX string here is **measured** engine output (`qalc` 5.12.0 — the same version
//          and the same PrintOptions as the libqalculate inside the app): `2\times \sqrt{2}`
//          typesets, `\num{0.3333333333333333}` does not.
Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget display({
  String expression = 'sqrt(8)',
  String result = '2.828427',
  String resultTex = '',
  String resultDecimal = '',
  bool naturalDisplay = true,
}) {
  return host(CalculatorDisplay(
    expression: expression,
    result: result,
    resultTex: resultTex,
    resultDecimal: resultDecimal,
    hasError: false,
    statusTitle: '等待输入',
    statusMessage: '',
    cursorIndex: null,
    angleMode: 'DEG',
    hasMemory: false,
    colors: CalcTheme.roseCream.display,
    naturalDisplay: naturalDisplay,
  ));
}

/// 中文：结果行里那一个**直入 TeX** 的排版视图。表达式行也有一个 `MathExpressionView`，但它
///       永远不带 TeX，所以「带 tex 的那些」正好就是结果行排出来的精确形式。
/// English: The one typesetting view in the result line that takes **TeX directly**. The expression
///          line has a `MathExpressionView` too, but it never carries TeX, so "those with a tex"
///          are exactly the exact form the result line typeset.
Finder typesetResult() => find.byWidgetPredicate(
      (widget) => widget is MathExpressionView && widget.tex.isNotEmpty,
    );

void main() {
  testWidgets('精确形式排得出来时，结果行是「排版 + ≈ 近似值」', (tester) async {
    await tester.pumpWidget(display(
      result: '2.828427',
      resultTex: r'2\times \sqrt{2}',
      resultDecimal: '2.828427124746190',
    ));

    expect(tester.takeException(), isNull);
    expect(typesetResult(), findsOneWidget);
    expect(find.text('≈'), findsOneWidget);
    // 中文：近似值仍然是一个普通 `Text`——取整由控制器按精度设置做完，结果行只负责显示它。
    //       而「只有一个」同时证明精确形式那一段**真的排出来了**：它一旦退回纯文本，屏幕上就会
    //       出现第二个 `Text('2.828427')`。
    // English: the approximation is still a plain `Text` — rounding is done by the controller at
    //          the user's precision and the result line only shows it. "Exactly one" also proves the
    //          exact fragment really **did** typeset: had it degraded to plain text, a second
    //          `Text('2.828427')` would be on screen.
    expect(find.text('2.828427'), findsOneWidget);
    // 中文：精确形式那一半**不再**以纯文本出现（否则就是把同一行写了两遍）。
    // English: the exact half does **not** also appear as plain text (that would write the same
    //          line twice).
    expect(find.text('2.828427124746190'), findsNothing);
  });

  testWidgets('精确形式排不出来时退回十进制读数，不显示空白也不显示乱码', (tester) async {
    // 中文：`\num{…}` 是引擎对「带千分位的长数字」的印法，flutter_math_fork 不认它——真机上
    //       `1/3`、`2^2000` 这类结果走的正是这一条。
    // English: `\num{…}` is how the engine prints a long number carrying grouping separators, and
    //          flutter_math_fork rejects it — on a device this is the route `1/3` and `2^2000`
    //          take.
    await tester.pumpWidget(display(
      result: '0.333333',
      resultTex: r'\num{0.3333333333333333}',
      resultDecimal: '0.3333333333333333',
    ));

    expect(tester.takeException(), isNull);
    expect(typesetResult(), findsNothing);
    expect(find.text('≈'), findsNothing);
    expect(find.text('0.333333'), findsOneWidget);
    // 中文：TeX 本身一个字都不该出现在屏幕上——「不许乱码」正是这一条。
    // English: not one character of the TeX itself may reach the screen — that is precisely the
    //          "never garbled" half of the requirement.
    expect(find.textContaining(r'\num'), findsNothing);
  });

  testWidgets('精确形式就是那串十进制时，不再排一遍、也不加 ≈', (tester) async {
    // 中文：引擎对普通数字印出来的 LaTeX **就是那串十进制**（实测：`2+2` → `4`、`1/2` → `0.5`）。
    //       左边已经是这个数，再来一个 `≈ 4` 只是把同一个数写两遍。
    // English: for an ordinary number the engine's LaTeX **is** that decimal (measured: `2+2` →
    //          `4`, `1/2` → `0.5`). The left side is already that number, and a `≈ 4` beside it
    //          would just write the same number twice.
    await tester.pumpWidget(display(
      expression: '2+2',
      result: '4',
      resultTex: '4',
      resultDecimal: '4',
    ));

    expect(tester.takeException(), isNull);
    expect(typesetResult(), findsNothing);
    expect(find.text('≈'), findsNothing);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('自然排版关掉时结果行整行纯文本，精确形式不出现', (tester) async {
    // 中文：表达式行与结果行读同一个开关——关掉它，两行一起退回纯文本，结果行是接入引擎之前
    //       的那一行。精确形式在这条分支上不显示是**有意的**：屏幕上的数学排版被关掉了。
    // English: the expression line and the result line read the same switch — flipping it sends
    //          both lines back to plain text, and the result line is the one that existed before
    //          the engine. Not showing the exact form on this branch is deliberate: maths
    //          typesetting is switched off on this screen.
    await tester.pumpWidget(display(
      result: '2.828427',
      resultTex: r'2\times \sqrt{2}',
      resultDecimal: '2.828427124746190',
      naturalDisplay: false,
    ));

    expect(tester.takeException(), isNull);
    expect(typesetResult(), findsNothing);
    expect(find.text('≈'), findsNothing);
    expect(find.text('2.828427'), findsOneWidget);
  });

  testWidgets('没有引擎的 LaTeX 时结果行与接入引擎之前逐字符相同', (tester) async {
    await tester.pumpWidget(display(result: '5.656854', expression: 'sqrt(32)'));

    expect(tester.takeException(), isNull);
    expect(typesetResult(), findsNothing);
    expect(find.text('≈'), findsNothing);
    expect(find.text('='), findsOneWidget);
    expect(find.text('5.656854'), findsOneWidget);
  });
}
