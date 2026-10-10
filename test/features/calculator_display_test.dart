import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget display({
  String expression = '1+2',
  String result = '3',
  String resultTex = '',
  String resultDecimal = '',
  bool hasError = false,
  int? cursorIndex,
  bool naturalDisplay = true,
  VoidCallback? onMore,
  VoidCallback? onOpenDrawer,
  void Function(int sourceOffset)? onTapOffset,
  double? width,
  double? height,
  double scale = 1,
}) {
  Widget child = CalculatorDisplay(
    expression: expression,
    result: result,
    resultTex: resultTex,
    resultDecimal: resultDecimal,
    hasError: hasError,
    statusTitle: hasError ? '表达式需要修正' : '等待输入',
    statusMessage: hasError ? '缺少右括号' : '',
    cursorIndex: cursorIndex,
    angleMode: 'DEG',
    hasMemory: false,
    colors: CalcTheme.roseCream.display,
    naturalDisplay: naturalDisplay,
    onTapOffset: onTapOffset,
    onMore: onMore,
    onOpenDrawer: onOpenDrawer,
  );
  // 中文：只有用例自己点出高度/字号时才套这两层，默认树与之前完全一致。
  // English: The two wrappers appear only when a case asks for a size or a font scale, so the
  //          default tree is exactly the one the earlier cases pump.
  if (scale != 1) {
    child = MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: child,
    );
  }
  if (height != null) {
    child = SizedBox(width: width, height: height, child: child);
  }
  return host(child);
}

void main() {
  testWidgets('shows the expression through MathExpressionView', (tester) async {
    await tester.pumpWidget(display(cursorIndex: 2, onTapOffset: (int _) {}));
    expect(find.byType(MathExpressionView), findsOneWidget);
    // 中文：光标下标与点击回调是下一个任务的文字编辑器赖以工作的两根线。它们只是被原样透传，
    //       丢了也不会有别的用例变红，所以在这里钉成结构断言。
    // English: The caret index and the tap callback are the two wires the next task's inline
    //          editor hangs off. They are passed straight through, so losing either would leave
    //          every other case green — pin them structurally here.
    final MathExpressionView view =
        tester.widget<MathExpressionView>(find.byType(MathExpressionView));
    expect(view.cursorIndex, 2);
    expect(view.onTapOffset, isNotNull,
        reason: 'onTapOffset 必须原样透传，否则点算式定位光标会静默失效');
  });

  testWidgets('shows the angle mode indicator', (tester) async {
    await tester.pumpWidget(display());
    expect(find.text('DEG'), findsOneWidget);
  });

  testWidgets('shows a leading equals sign before the result', (tester) async {
    await tester.pumpWidget(display(result: '3'));
    expect(find.text('='), findsOneWidget);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('shows the error message only when there is an error', (tester) async {
    await tester.pumpWidget(display(hasError: false));
    expect(find.text('缺少右括号'), findsNothing);
    // 中文：这一行才是那个 if 的门闩——上面那句在 statusMessage 为空时恒成立。
    // English: This line is what pins the `if`: the message above holds trivially while the
    //          helper leaves `statusMessage` empty.
    expect(find.text('等待输入'), findsNothing);
    await tester.pumpWidget(display(hasError: true));
    expect(find.text('缺少右括号'), findsOneWidget);
  });

  testWidgets('the error line shows the title as well as the message',
      (tester) async {
    await tester.pumpWidget(display(hasError: true));
    expect(find.text('表达式需要修正'), findsOneWidget,
        reason: '状态标题必须有视觉落点，否则它是死参数');
  });

  testWidgets('a panel too short for the error line clips it instead of overflowing',
      (tester) async {
    // 中文：182dp 下限 + 1.45 倍字体缩放——按真实 Android 字体度量，此时内容确实放不下。
    //       组件必须把错误行裁掉，而不是抛 RenderFlex 溢出（debug 红屏、release 悄悄切字）。
    //       ⚠️ 这条是「**恰在下限**」的用例，所以它跟着下限走（176 → 182）。它断言的是**两个高度
    //       相比**（被裁的这一头 vs 320dp 下的自然高度），所以下限挪了判据依然成立——
    //       182dp 下内容要 100dp、实际内容比这多，照样放不下。
    // English: The 182dp floor plus a 1.45× font scale — under real Android font metrics the
    //          content genuinely does not fit. The widget must clip the error line instead of
    //          throwing a RenderFlex overflow (a red screen in debug, silently cut text in
    //          release).
    //          ⚠️ This is the "**exactly at the floor**" case, so it travels with the floor (176 →
    //          182). What it asserts is **two heights compared** (the clipped end against the
    //          natural height at 320dp), so the judgement survives the move — at 182dp the content
    //          budget is 100dp and the content needs more than that, so it still does not fit.
    await tester.pumpWidget(
        display(width: 320, height: 182, scale: 1.45, hasError: true));
    expect(tester.takeException(), isNull,
        reason: '高度不够时错误行必须裁切，不能溢出报错');

    final double clipped = tester.getRect(find.text('缺少右括号')).height;
    // 中文：同一段文字、同一个字体缩放，只把面板给高，量出它的自然高度作对照。
    // English: Same text and same font scale, only a taller panel — the reference for what that
    //          text naturally needs.
    await tester.pumpWidget(
        display(width: 320, height: 320, scale: 1.45, hasError: true));
    expect(tester.takeException(), isNull);
    final double natural = tester.getRect(find.text('缺少右括号')).height;
    expect(clipped, lessThan(natural), reason: '错误正文真的被压到了自然高度以下');

    // 中文：压缩必须由 ClipRect 兜住，否则多出来的笔画会画到显示面板外面去。
    // English: The `ClipRect` has to catch that compression, or the spare pixels would be painted
    //          outside the panel.
    expect(
      find.ancestor(
        of: find.text('缺少右括号'),
        matching: find.descendant(
          of: find.byType(CalculatorDisplay),
          matching: find.byType(ClipRect),
        ),
      ),
      findsOneWidget,
    );
  });

  // 中文：精确形式上屏引入了**新的高度边界**：纯文本结果是一行，而一个精确形式（堆叠分数、
  //       根号套分数）的高度随字号等比放大，于是结果行成了面板里唯一一个高度不确定的行。
  //       在**当时的**文档下限（176dp，现为 182dp）配合 2 倍文字缩放下，它会把表达式行挤到没有
  //       高度，再高一点整列就报 RenderFlex 溢出——debug 红屏，release 里用户的字被切掉。
  //       这一组钉住结果行**自己可缩**：拿到的是「最多能有多高」的上限，真放不下时由里面的
  //       `FittedBox` 等比缩小，而不是把内容裁掉、也不是把面板的下限调高（后者会波及所有结果）。
  //       ⚠️ 上面那两个 176 是**当时的**下限，不改写成 182：那是在 176 上观测到的事实，
  //       改成 182 就成了一个没量过的说法。（下限抬到 182 的实测与推导写在 `CalculatorDisplay`
  //       的类注释里。）
  // English: the exact form on screen introduces a **new height boundary**: a plain-text result is
  //          one line, while an exact form (a stacked fraction, a radical around a fraction) scales
  //          with the font size, which makes the result row the one row in the panel whose height is
  //          not fixed. At the **then-current** documented minimum (176dp, now 182dp) with a 2× text
  //          scale it squeezes the expression line down to nothing, and a little taller it makes the
  //          whole column report a RenderFlex overflow — a red screen in debug, the user's text cut
  //          off in release.
  //          ⚠️ Those two 176s are the **then-current** floor and are deliberately not rewritten to
  //          182: what was observed was observed at 176, and 182 would be a claim nobody measured.
  //          (The measurement and derivation behind raising the floor to 182 are in
  //          `CalculatorDisplay`'s class comment.)
  //          This group pins that the result row **may shrink**: what it receives is a ceiling, and
  //          when it genuinely does not fit the `FittedBox` inside scales the content down instead of
  //          clipping it or raising the panel's floor (which would affect every result).
  group('最小高度 + 大字体缩放下的精确形式', () {
    // 中文：结果行能拿到的上限。契约里与字体无关的固定部分是状态行 48dp 与上下内边距 18dp、
    //       两条间距 12dp（见类注释），剩下的一半归结果行，另一半归表达式行。
    //       ⚠️ 状态行是 48 不是 40，下限也因此是 182 不是 176——那 8dp 是可达性要来的
    //       （类注释里记了实测：该行两颗可点按钮不足 48dp 时 `androidTapTargetGuideline` 不通过）。
    // English: the ceiling the result row may take. The font-independent chrome is the 48dp status
    //          row, 18dp of vertical padding and 12dp of gaps (see the class comment); the remainder
    //          is split, half to the result row and half to the expression row.
    //          ⚠️ The status row is 48, not 40, and the floor is therefore 182, not 176 — those 8dp
    //          buy accessibility (the class comment records the measurement: the row's two tappable
    //          buttons fail `androidTapTargetGuideline` below 48dp).
    const double panelHeight = 182;
    const double chrome = 48 + 18 + 12;
    const double share = (panelHeight - chrome) / 2;

    testWidgets('高瘦精确形式在 2 倍缩放下不溢出', (tester) async {
      await tester.pumpWidget(display(
        width: 320,
        height: panelHeight,
        scale: 2,
        result: '0.707107',
        resultTex: r'\frac{1}{\sqrt{2}}',
        resultDecimal: '0.7071067811865475',
      ));

      expect(tester.takeException(), isNull,
          reason: '最小高度 + 2 倍缩放下，高瘦精确形式必须缩进面板，而不是撑破整列');
      // 中文：结果行真的画了出来（不是空白），而且表达式行仍然有高度——精确形式不许把它挤没。
      // English: the result row really drew (not blank), and the expression line still has height —
      //          the exact form must not squeeze it away.
      expect(find.byType(MathExpressionView), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(MathExpressionView).first).height,
        greaterThan(0),
        reason: '表达式行被结果行挤到了零高度',
      );
    });

    testWidgets('结果行不会长过它分到的那一份，再高也是自己缩', (tester) async {
      // 中文：这个形式在 2 倍缩放下自然高度约 86dp——远超上面那 53dp。修之前它照单全收，
      //       把表达式行挤到 0 附近；现在它拿到的是上限，多出来的部分由 `FittedBox` 缩掉。
      // English: this form naturally wants about 86dp at a 2× scale — far more than the 53dp above.
      //          Before the fix it simply took it and squeezed the expression line towards zero; now
      //          what it gets is a ceiling, and the excess is scaled away by the `FittedBox`.
      await tester.pumpWidget(display(
        width: 320,
        height: panelHeight,
        scale: 2,
        result: '0.833333',
        resultTex: r'\frac{\frac{\frac{1}{2}}{\frac{3}{4}}}{\frac{5}{6}}',
        resultDecimal: '0.8333333333333334',
      ));

      expect(tester.takeException(), isNull);
      final Rect resultRow = tester.getRect(
        find.ancestor(of: find.text('≈'), matching: find.byType(Align)).first,
      );
      expect(resultRow.height, lessThanOrEqualTo(share + 0.01),
          reason: '结果行超过了它分到的高度：${resultRow.height} > $share');
      expect(resultRow.height, greaterThan(0));
    });

    testWidgets('面板被压到下限以下时，结果行缩下去而不是把整列撑破', (tester) async {
      // 中文：类注释里那条「矮窗口 + 大字体缩放」的路径。100dp 比文档标注的下限（182dp）还矮
      //       82dp，此时固定行本身就不够放——修之前这里报「A RenderFlex overflowed by 22 pixels
      //       on the bottom」（实测），修之后结果行先缩，整列不再溢出。
      // English: the "short window plus a large font scale" route the class comment names. 100dp is
      //          82dp below the documented floor (182dp), so the fixed rows alone no longer fit —
      //          before the fix this reported "A RenderFlex overflowed by 22 pixels on the bottom"
      //          (measured), while afterwards the result row shrinks first and the column no longer
      //          overflows.
      await tester.pumpWidget(display(
        width: 320,
        height: 100,
        result: '0.707107',
        resultTex: r'\frac{1}{\sqrt{2}}',
        resultDecimal: '0.7071067811865475',
      ));

      expect(tester.takeException(), isNull,
          reason: '面板矮于下限时也不许抛出 RenderFlex 溢出');
    });

    testWidgets('放得下的时候，结果行仍按自然高度排布', (tester) async {
      // 中文：可缩不等于会缩。常规字号下结果行的尺寸必须与之前逐像素相同——上限只是上限。
      //       最直接的判据：面板高度从 182dp 变到 230dp 时，这一行的自然高度不变。
      // English: being shrinkable is not the same as shrinking. At ordinary font sizes this row has
      //          to be pixel-for-pixel what it was — the ceiling is only a ceiling. The most direct
      //          check: the row's natural height does not change when the panel goes from 182dp to
      //          230dp.
      Future<double> resultRowHeight(double height) async {
        await tester.pumpWidget(display(
          width: 320,
          height: height,
          result: '0.707107',
          resultTex: r'\frac{1}{\sqrt{2}}',
          resultDecimal: '0.7071067811865475',
        ));
        expect(tester.takeException(), isNull);
        return tester
            .getRect(
              find.ancestor(of: find.text('≈'), matching: find.byType(Align)).first,
            )
            .height;
      }

      final double atFloor = await resultRowHeight(182);
      final double atCeiling = await resultRowHeight(230);
      expect(atFloor, atCeiling,
          reason: '1 倍缩放下结果行不该随面板高度变化——它应当取自然高度');
      expect(atFloor, lessThan(share),
          reason: '这一行在 1 倍缩放下本来就该矮于上限，否则上限的松紧无从谈起');
    });
  });

  testWidgets('More button is tappable when provided', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(display(onMore: () => tapped++));
    await tester.tap(find.text('More...'));
    expect(tapped, 1);
  });

  testWidgets('drawer button carries the tooltip the shell test looks for',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(display(onOpenDrawer: () => opened++));
    await tester.tap(find.byTooltip('打开导航'));
    expect(opened, 1);
  });

  testWidgets('degrades to plain text when naturalDisplay is off', (tester) async {
    await tester.pumpWidget(display(expression: '(a+b)/2', naturalDisplay: false));
    expect(find.text('(a+b)/2'), findsOneWidget);
  });

  testWidgets('renders an empty expression without throwing', (tester) async {
    await tester.pumpWidget(display(expression: '', result: '0'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
