import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget pad({
  KeypadModifier modifier = KeypadModifier.none,
  bool? modifierActive,
  CalcTheme theme = CalcTheme.roseCream,
  ValueChanged<String>? onKey,
}) =>
    host(CalculatorKeypad(
      definition: hiperKeypad,
      modifier: modifier,
      // 默认不传：留给 CalculatorKeypad 自己推导（`modifier != none`），
      // 这正是「调用方漏传」的那条路径。
      modifierActive: modifierActive,
      colors: theme.keys,
      background: theme.keypadBackground,
      onKey: onKey ?? (_) {},
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
    // 中文：`📷` 是第 2 行（`KeypadRow` 计）的主键且为禁用态，且键面文字在整块键盘上只出现一次；
    //       不要拿某个标签行的文字来测，标签本就不可点，那样会通过但测不到「禁用键不触发」这件事。
    //       （Σ 曾经是这里的样本，它在上一步被点亮了，样本因此换成仍禁用的 `📷`。）
    // English: `📷` is a disabled main key on row 2 (`KeypadRow` counting) whose face text occurs
    //          exactly once on the whole keypad; do not use a label-band text, which is not
    //          tappable anyway — that would pass while testing nothing. (Σ used to be the sample
    //          here and was lit up in the previous step, so the sample moved to the still-disabled
    //          `📷`.)
    await tester.tap(find.text('📷').first, warnIfMissed: false);
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

  // 中文：`SHIFT`/`hyp` 过去走两个专属回调（`onToggleShift`/`onToggleHyp`），于是「这两个 id 是
  //       什么」被写在了渲染层和主屏两处。现在渲染层不认识任何 id：修饰键与别的键一样上报自己的 id，
  //       由上层决定那是切换修饰态。这两条钉住新契约，并守住「渲染层不懂 id」这件事。
  // English: `SHIFT`/`hyp` used to route through two dedicated callbacks (`onToggleShift` /
  //          `onToggleHyp`, now gone), which wrote those two ids down in both the rendering layer and
  //          the screen. The renderer now knows no ids: the modifier keys report their own id like every
  //          other key and the screen decides that means "flip the modifier". These two pin that
  //          contract and that the renderer knows no ids.
  testWidgets('tapping SHIFT reports the id through onKey', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    await tester.tap(find.text('SHIFT').first);
    expect(tapped, ['shift']);
  });

  testWidgets('tapping hyp reports the id through onKey', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    await tester.tap(find.text('hyp').first);
    expect(tapped, ['hyp']);
  });

  testWidgets('band labels highlight while a modifier is latched',
      (tester) async {
    const theme = CalcTheme.roseCream;
    await tester.pumpWidget(pad(modifier: KeypadModifier.none, theme: theme));
    final idle = tester.widget<Text>(find.text('sin⁻¹')).style?.color;
    expect(idle, theme.keys.shiftLabelFg, reason: '空闲时是普通提示色');

    await tester.pumpWidget(pad(modifier: KeypadModifier.shift, theme: theme));
    final latched = tester.widget<Text>(find.text('sin⁻¹')).style?.color;
    expect(latched, isNot(idle), reason: 'SHIFT 锁定后标签带必须给出可见反馈');
    expect(latched, theme.keys.accentFg, reason: '高亮文字必须取主题的 accentFg，不能是别的色值');
    final chip = tester.widget<Container>(
      find
          .ancestor(of: find.text('sin⁻¹'), matching: find.byType(Container))
          .first,
    );
    expect((chip.decoration as BoxDecoration).color, theme.keys.accentBg,
        reason: '高亮底必须取主题的 accentBg');
    final shiftKey = tester.widget<Container>(
      find
          .ancestor(
              of: find.text('SHIFT').first, matching: find.byType(Container))
          .first,
    );
    expect((shiftKey.decoration as BoxDecoration).color, theme.keys.accentBg,
        reason: '锁定的修饰键自身同样取 accentBg');

    // 省略 modifierActive 时按 modifier 推导（上面那次 pump 走的就是这条路）；
    // 显式传入则优先，供 hyp 在上层是独立状态位的形状使用。
    await tester.pumpWidget(pad(modifierActive: true, theme: theme));
    expect(tester.widget<Text>(find.text('sin⁻¹')).style?.color,
        theme.keys.accentFg,
        reason: '显式 modifierActive 必须能单独点亮标签带');
  });

  testWidgets('pill buttons are tappable and report ids', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(pad(onKey: tapped.add));
    await tester.tap(find.text('▸BIN').first);
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
    )));
    // 数字键底应为该主题的 digitBg
    final digit = tester.widget<Container>(
      find
          .ancestor(of: find.text('7').first, matching: find.byType(Container))
          .first,
    );
    expect((digit.decoration as BoxDecoration).color, theme.keys.digitBg);
    // 胶囊按钮（标签行里的实体键）的底色同样必须来自主题
    final pill = tester.widget<Container>(
      find
          .ancestor(
              of: find.text('▸BIN').first, matching: find.byType(Container))
          .first,
    );
    expect((pill.decoration as ShapeDecoration).color, theme.keys.pillBg,
        reason: '胶囊按钮底必须是主题的 pillBg');
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
