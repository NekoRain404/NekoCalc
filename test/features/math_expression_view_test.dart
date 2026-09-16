import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

// 中文：MathExpressionView 的行为契约——自然排版不抛异常、纯文本分支必须是单个 Text、
//       点击片段回报的偏移落在输入串之内。
// English: The behavioural contract of MathExpressionView: natural typesetting never throws, the
//          plain-text branch is a single Text, and a tapped fragment reports an offset inside
//          the input string.
Widget host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('renders a simple expression without throwing', (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(expression: '1+2')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a fraction expression naturally', (tester) async {
    await tester
        .pumpWidget(host(const MathExpressionView(expression: '(a+b)/2')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MathExpressionView), findsOneWidget);
  });

  testWidgets('falls back to plain text when natural display is off',
      (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(
      expression: '(a+b)/2',
      naturalDisplay: false,
    )));
    await tester.pumpAndSettle();
    expect(find.text('(a+b)/2'), findsOneWidget);
  });

  testWidgets('renders incomplete input without throwing', (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(expression: 'sin(')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an empty expression without throwing', (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(expression: '')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // 中文：解析、发射、排版三层都承诺"永不抛异常"，而本组件是它们对外的最后一层，这句话只有在
  //       这里才真的可观测。500 层括号会撑爆朴素的递归下降，因此它同时钉住深度上限与
  //       整段退化：退化后整条表达式仍是**一个**片段，而且这个片段真的画了出来。
  // English: All three layers — parse, emit, typeset — promise never to throw, and this widget is
  //          their outermost one, so that promise is only truly observable here. 500 nested
  //          parentheses would blow a naive recursive descent, so this pins the depth cap and the
  //          whole-string degradation together: after degrading the expression is still **one**
  //          fragment, and that fragment actually rendered.
  testWidgets('renders pathologically deep nesting without throwing', (tester) async {
    final source = '${'(' * 500}1${')' * 500}';
    await tester.pumpWidget(host(MathExpressionView(expression: source)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final fragment = find.descendant(
      of: find.byType(MathExpressionView),
      matching: find.byType(GestureDetector),
    );
    expect(fragment, findsOneWidget);
    expect(tester.getSize(fragment).width, greaterThan(0));
  });

  testWidgets('tapping a fragment reports a source offset inside the input',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(host(MathExpressionView(
      expression: '1+2',
      onTapOffset: (o) => tapped = o,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MathExpressionView));
    await tester.pumpAndSettle();
    expect(tapped, isNotNull);
    expect(tapped, inInclusiveRange(0, 3));
  });

  testWidgets('does not report taps when onTapOffset is null', (tester) async {
    await tester.pumpWidget(host(const MathExpressionView(expression: '1+2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MathExpressionView));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // 中文：光标是组件内唯一的 Container，因此可以按类型定位；用位置而不是类型来断言，
  //       是因为真正要守住的行为是"光标落在下标对应的那个片段边界上"。
  // English: The cursor is the only Container inside the widget, so it can be located by type.
  //          The assertions are about position rather than type because the behaviour worth
  //          protecting is "the cursor sits on the fragment boundary the index refers to".
  group('光标', () {
    Finder cursorIn(WidgetTester tester) => find.descendant(
          of: find.byType(MathExpressionView),
          matching: find.byType(Container),
        );

    Finder fragmentIn(WidgetTester tester, int index) => find
        .descendant(
          of: find.byType(MathExpressionView),
          matching: find.byType(GestureDetector),
        )
        .at(index);

    testWidgets('没有给下标时完全不画光标', (tester) async {
      await tester.pumpWidget(host(const MathExpressionView(expression: '1+2')));
      await tester.pumpAndSettle();
      expect(cursorIn(tester), findsNothing);
    });

    testWidgets('下标 0 的光标落在整条算式之前', (tester) async {
      await tester.pumpWidget(host(const MathExpressionView(
        expression: '1+2',
        cursorIndex: 0,
      )));
      await tester.pumpAndSettle();
      expect(cursorIn(tester), findsOneWidget);
      expect(
        tester.getCenter(cursorIn(tester)).dx,
        lessThan(tester.getCenter(fragmentIn(tester, 0)).dx),
      );
    });

    testWidgets('光标落在下标所指的片段边界上', (tester) async {
      // 中文：`1+2` 的三个片段区间是 0-1、1-2、2-3，因此下标 1 应落在 `1` 与 `+` 之间。
      // English: The three fragments of `1+2` span 0-1, 1-2 and 2-3, so index 1 belongs between
      //          `1` and `+`.
      await tester.pumpWidget(host(const MathExpressionView(
        expression: '1+2',
        cursorIndex: 1,
      )));
      await tester.pumpAndSettle();
      expect(cursorIn(tester), findsOneWidget);
      final cursorX = tester.getCenter(cursorIn(tester)).dx;
      expect(cursorX, greaterThan(tester.getCenter(fragmentIn(tester, 0)).dx));
      expect(cursorX, lessThan(tester.getCenter(fragmentIn(tester, 1)).dx));
    });

    testWidgets('下标等于长度时光标落在末尾', (tester) async {
      await tester.pumpWidget(host(const MathExpressionView(
        expression: '1+2',
        cursorIndex: 3,
      )));
      await tester.pumpAndSettle();
      expect(cursorIn(tester), findsOneWidget);
      expect(
        tester.getCenter(cursorIn(tester)).dx,
        greaterThan(tester.getCenter(fragmentIn(tester, 2)).dx),
      );
    });
  });

  // 中文：`onErrorFallback` 会把渲染失败的片段换成 `Text(原文)`，而"没有抛异常"对失败与成功
  //       同样成立。两者合起来意味着：只要引擎将来拒收其中某个写法，上面那些测试会继续全绿，
  //       而根号、百分号、绝对值已经悄悄退回原始文本——那恰恰是这一层要防的事，且 TeX 的字符串
  //       比对（tex_emitter_test）也看不出来。下面逐条断言这些写法真的排版了。
  // English: `onErrorFallback` swaps a failed fragment for `Text(source)`, and "no exception was
  //          thrown" holds for failure and success alike. Together those mean that a future engine
  //          rejecting one of these spellings would leave the tests above green while radicals,
  //          percent and absolute value quietly degraded to raw text - exactly what this layer
  //          exists to prevent, and something the emitter's string equality tests cannot see
  //          either. Each case below asserts the spelling genuinely typesets.
  group('片段真的排版了，而不是退回纯文本', () {
    // 中文：左边是输入，右边是它应当产出的 TeX——右边只用于测试名，便于失败时定位。
    //       每条都是单一显示单元，因此恰有一个片段。
    // English: Input on the left, the TeX it should produce on the right - the right side only
    //          labels the test so a failure is easy to locate. Every case is a single display
    //          unit, hence exactly one fragment.
    const risky = <String, String>{
      '(a+b)/2': r'\frac{a+b}{2}',
      'sqrt(x)': r'\sqrt{x}',
      'root(3,x)': r'\sqrt[3]{x}',
      'abs(x)': r'\left|x\right|',
      '50%': r'50\%',
      'log(x)': r'\log_{10}\left(x\right)',
      'sin(': r'\text{sin(}',
      'pi': r'\pi',
      'x^2': r'x^{2}',
      '1_000': r'1\_000',
      '2x': '2x',
      'mod(7,3)': r'\operatorname{mod}{\left(7, 3\right)}',
      // 中文：并置乘法把两个片段的 TeX 直接拼起来，于是"常量接字母"这一**形状**会拼出
      //       `\pix` 这类不存在的控制词（TeX 的控制词贪婪吃字母），引擎拒收后整个片段退回纯文本。
      //       前两类只覆盖单个写法，这里补上形状本身——写死一张清单挡不住它。
      // English: Juxtaposition concatenates the two fragments' TeX, so the *shape* "constant then a
      //          letter-initial operand" produces an undefined control word such as `\pix` (TeX
      //          control words eat letters greedily); the engine rejects it and the entire fragment
      //          degrades to plain text. The two groups above only cover individual spellings, so
      //          the shape itself is covered here — a hand-picked list cannot hold it back.
      'pi x': r'\pi{x}',
      'sin(pi x)': r'\sin\left(\pi{x}\right)',
      'pi x^2': r'\pi{x^{2}}',
      'root(1,2,3)': r'\operatorname{root}{\left(1, 2, 3\right)}',
    };

    for (final entry in risky.entries) {
      testWidgets('${entry.value} 排版成功', (tester) async {
        await tester.pumpWidget(
          host(MathExpressionView(expression: entry.key)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // 中文：一旦退回纯文本，该片段覆盖的原文就会作为一个 Text 出现在树里。
        //       find.text 默认不匹配独立的 RichText，所以排版成功的数学不会误命中这里。
        // English: On fallback the fragment's source text appears as a Text. `find.text` ignores
        //          standalone RichText by default, so correctly typeset maths cannot match here.
        expect(find.text(entry.key), findsNothing);
        final fragment = find.descendant(
          of: find.byType(MathExpressionView),
          matching: find.byType(GestureDetector),
        );
        expect(fragment, findsOneWidget);
        expect(tester.getSize(fragment).width, greaterThan(0));
      });
    }
  });
}
