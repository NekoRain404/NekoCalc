import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget display({
  String expression = '1+2',
  String result = '3',
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
    // 中文：176dp 下限 + 1.45 倍字体缩放——按真实 Android 字体度量，此时内容确实放不下。
    //       组件必须把错误行裁掉，而不是抛 RenderFlex 溢出（debug 红屏、release 悄悄切字）。
    // English: The 176dp floor plus a 1.45× font scale — under real Android font metrics the
    //          content genuinely does not fit. The widget must clip the error line instead of
    //          throwing a RenderFlex overflow (a red screen in debug, silently cut text in
    //          release).
    await tester.pumpWidget(
        display(width: 320, height: 176, scale: 1.45, hasError: true));
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
