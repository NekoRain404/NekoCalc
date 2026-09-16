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
}) =>
    host(CalculatorDisplay(
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
      onMore: onMore,
      onOpenDrawer: onOpenDrawer,
    ));

void main() {
  testWidgets('shows the expression through MathExpressionView', (tester) async {
    await tester.pumpWidget(display());
    expect(find.byType(MathExpressionView), findsOneWidget);
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
    await tester.pumpWidget(display(hasError: true));
    expect(find.text('缺少右括号'), findsOneWidget);
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
