import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

/// 中文：**显示面板上那一格进制读数**（`CalculatorDisplay.baseReadout`）的排版契约。
///       它是纯文本 `Text`——不是拿来排版的公式，所以不存在 `\text{}` 那种降级；这里要证的是
///       另外两件事：
///
///       1. **没有读数时一格都不多**：状态行与从前逐像素相同（调用方传空串，这一格整个不存在）；
///       2. **有读数时它永远放得下**：读数再长也不让状态行报 RenderFlex 溢出——它是 `Flexible`，
///          内容超了由自己按省略号收窄（截断看得见，不是把像素裁掉）。
///
/// English: **the base read-out cell on the display panel** (`CalculatorDisplay.baseReadout`) and its
///          layout contract. It is plain `Text` — not a formula to typeset, so the `\text{}`
///          degradation class does not apply. What is proved here is two other things: (1) **with no
///          read-out not one cell is added** — the status row is pixel-for-pixel what it was (the
///          caller passes an empty string and the cell does not exist at all); (2) **with a read-out
///          it always fits** — however long it is, the status row never reports a RenderFlex
///          overflow, because the cell is a `Flexible` and narrows itself with a visible ellipsis
///          rather than having pixels clipped.
void main() {
  testWidgets('没有读数时：状态行不画这一格', (tester) async {
    await tester.pumpWidget(_host(baseReadout: ''));
    await tester.pumpAndSettle();

    expect(find.text('HEX 64'), findsNothing);
    expect(find.text('DEG'), findsOneWidget, reason: '状态行本来那两格照旧');
    expect(tester.takeException(), isNull);
  });

  testWidgets('有读数时：它是一段纯文本，字面就是那串数字', (tester) async {
    await tester.pumpWidget(_host(baseReadout: 'HEX 64'));
    await tester.pumpAndSettle();

    final chip = find.text('HEX 64');
    expect(chip, findsOneWidget);
    // 中文：读数落在状态行上，**不是**结果行——结果行仍然是那一个十进制结果。
    expect(find.text('100'), findsWidgets);
    expect(
      find.descendant(of: find.byType(CalculatorDisplay), matching: chip),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('与角度 chip、记忆徽标同时在场：三格都在，不溢出', (tester) async {
    await tester.pumpWidget(_host(baseReadout: 'BIN 1100100', hasMemory: true));
    await tester.pumpAndSettle();

    expect(find.text('DEG'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('BIN 1100100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('读数很长：收窄自己，不撑破状态行', (tester) async {
    // 中文：320dp 宽 + 抽屉按钮 + 角度 chip + 记忆徽标 + 一个 40 字的读数 + `More...`——
    //       最挤的一种组合。溢出会在这里报 RenderFlex 异常，而不是在真机上「看起来有点怪」。
    // English: 320dp wide with the drawer button, the angle chip, the memory badge, a forty-character
    //          read-out and `More...` — the tightest combination there is. An overflow reports a
    //          RenderFlex exception here rather than "looking a bit odd" on a device.
    await tester.pumpWidget(_host(
      baseReadout: 'HEX FFF88A3290D55F4F4741D86B1EA28020A3FD1B2',
      hasMemory: true,
      onMore: () {},
      onOpenDrawer: () {},
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '状态行溢出');
    // 中文：`Text` 里仍是完整那串（截断发生在画的时候，不是把字符串悄悄改短），并且开了省略号。
    final text = tester.widget<Text>(find.textContaining('HEX FFF88A'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}

Widget _host({
  required String baseReadout,
  bool hasMemory = false,
  VoidCallback? onMore,
  VoidCallback? onOpenDrawer,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          height: 176,
          child: CalculatorDisplay(
            expression: '100',
            result: '100',
            resultDecimal: '100',
            hasError: false,
            statusTitle: '结果可继续使用',
            statusMessage: '继续使用会把 100 写回表达式。',
            cursorIndex: 3,
            angleMode: 'DEG',
            hasMemory: hasMemory,
            baseReadout: baseReadout,
            colors: CalcTheme.roseCream.display,
            naturalDisplay: true,
            onMore: onMore,
            onOpenDrawer: onOpenDrawer,
          ),
        ),
      ),
    ),
  );
}
