import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget pad({
  KeypadModifier modifier = KeypadModifier.none,
  ValueChanged<String>? onKey,
  VoidCallback? onToggleShift,
  VoidCallback? onToggleHyp,
}) =>
    host(CalculatorKeypad(
      definition: hiperKeypad,
      modifier: modifier,
      modifierActive: modifier != KeypadModifier.none,
      colors: CalcTheme.roseCream.keys,
      background: CalcTheme.roseCream.keypadBackground,
      onKey: onKey ?? (_) {},
      onToggleShift: onToggleShift ?? () {},
      onToggleHyp: onToggleHyp ?? () {},
    ));

void main() {
  testWidgets('renders every enabled key label', (tester) async {
    await tester.pumpWidget(pad());
    for (final row in hiperKeypad.rows) {
      for (final k in row.keys) {
        if (k.base.enabled) {
          expect(find.text(k.base.label), findsWidgets,
              reason: '启用的键 ${k.base.id} 未渲染');
        }
      }
    }
  });

  testWidgets('tapping a digit reports its id', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    await tester.tap(find.text('7').first);
    expect(tapped, ['7']);
  });

  testWidgets('under shift, a main key reports its shift id', (tester) async {
    final tapped = <String>[];
    await tester
        .pumpWidget(pad(modifier: KeypadModifier.shift, onKey: tapped.add));
    await tester.tap(find.text('sin').first);
    expect(tapped, ['asin']);
  });

  testWidgets('under hyp, sin reports sinh', (tester) async {
    final tapped = <String>[];
    await tester
        .pumpWidget(pad(modifier: KeypadModifier.hyp, onKey: tapped.add));
    await tester.tap(find.text('sin').first);
    expect(tapped, ['sinh']);
  });

  testWidgets('disabled main keys report nothing', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    // Σ 是第 3 行的主键且为禁用态；不要拿标签行的文字（如 MTRX）来测，
    // 标签本就不可点，那样会通过但测不到「禁用键不触发」这件事。
    await tester.tap(find.text('Σ').first, warnIfMissed: false);
    await tester.pump();
    expect(tapped, isEmpty);
  });

  testWidgets('shift labels are not tappable', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    await tester.tap(find.text('MTRX').first, warnIfMissed: false);
    await tester.pump();
    expect(tapped, isEmpty);
  });

  testWidgets('tapping SHIFT invokes onToggleShift, not onKey', (tester) async {
    final tapped = <String>[];
    var toggled = 0;
    await tester
        .pumpWidget(pad(onKey: tapped.add, onToggleShift: () => toggled++));
    await tester.tap(find.text('SHIFT').first);
    expect(toggled, 1);
    expect(tapped, isEmpty);
  });

  testWidgets('band labels highlight while a modifier is latched',
      (tester) async {
    await tester.pumpWidget(pad(modifier: KeypadModifier.none));
    final idle = tester.widget<Text>(find.text('sin⁻¹')).style?.color;
    await tester.pumpWidget(pad(modifier: KeypadModifier.shift));
    final latched = tester.widget<Text>(find.text('sin⁻¹')).style?.color;
    expect(latched, isNot(idle), reason: 'SHIFT 锁定后标签带必须给出可见反馈');
  });

  testWidgets('pill buttons are tappable and report ids', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    await tester.tap(find.text('BIN').first);
    expect(tapped, ['baseBin']);
  });

  testWidgets('no key paints a hardcoded colour from the theme',
      (tester) async {
    const theme = CalcTheme.lavenderMist;
    await tester.pumpWidget(host(CalculatorKeypad(
      definition: hiperKeypad,
      modifier: KeypadModifier.none,
      colors: theme.keys,
      background: theme.keypadBackground,
      onKey: (_) {},
      onToggleShift: () {},
      onToggleHyp: () {},
    )));
    // 数字键底应为该主题的 digitBg
    final digit = tester.widget<Container>(
      find
          .ancestor(of: find.text('7').first, matching: find.byType(Container))
          .first,
    );
    expect((digit.decoration as BoxDecoration).color, theme.keys.digitBg);
  });

  testWidgets('does not overflow at 320, 360 and 412 dp', (tester) async {
    for (final w in [320.0, 360.0, 412.0]) {
      tester.view.physicalSize = Size(w, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(pad());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '宽度 $w 下溢出');
    }
  });
}
