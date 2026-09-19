import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
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
  testWidgets('renders every enabled key face: text keys as text, figure keys as a figure',
      (tester) async {
    await tester.pumpWidget(pad());
    var figures = 0;
    for (final row in hiperKeypad.rows) {
      for (final k in row.keys) {
        if (!k.base.enabled) continue;
        if (k.base.icon == null) {
          expect(find.text(k.base.label), findsWidgets,
              reason: '启用的键 ${k.base.id} 未渲染');
        } else {
          // 中文：键面是图形的键**没有自己的字可找**——它们的 `label` 只是名字，数出来之后
          //       在下面按条数核对，免得这一支永远绿。
          // English: a key whose face is a figure has **no text of its own to find** — its `label` is
          //          only a name; they are counted here and checked by that count below, so this arm
          //          can never be vacuously green.
          figures++;
        }
      }
    }
    expect(find.byType(KeyFaceIconView), findsNWidgets(figures),
        reason: '键面是图形的键必须一格一个 `KeyFaceIconView`');
  });

  // 中文：**图形键面**（`KeyFaceIcon` + `KeyFaceIconView`）——本轮新增的那条路，矩阵键是唯一
  //       的使用者。三条：颜色跟着主题走（三套主题 × 明暗全试一遍，渲染层一个色值都不许写死）、
  //       任何屏幕尺寸下都画在自己的格子里且不变形、按下去报的 id 与换画法之前逐字相同。
  // English: **figure faces** (`KeyFaceIcon` + `KeyFaceIconView`) — the road added this round, whose
  //          only user is the matrix key. Three things: the colour follows the theme (all three themes
  //          × light/dark, and the rendering layer may not hardcode a single value); at any screen
  //          size it is drawn inside its own cell and cannot be stretched; and pressing it reports
  //          byte-for-byte the ids it reported before the face changed.
  group('图形键面（矩阵键那一格）', () {
    testWidgets('图形的颜色是键面自己的前景色——六种主题变体各取各的', (tester) async {
      for (final theme in <CalcTheme>[
        ...CalcTheme.all,
        ...CalcTheme.all.map((CalcTheme t) => t.dark),
      ]) {
        await tester.pumpWidget(pad(theme: theme));
        final face =
            tester.widget<KeyFaceIconView>(find.byType(KeyFaceIconView));
        expect(face.icon, KeyFaceIcon.matrix);
        expect(face.color, theme.keys.functionFg,
            reason: '${theme.name} 下图形必须取那一格的键面前景色，'
                '不能是渲染层写死的色值');
      }
    });

    testWidgets('任何屏幕尺寸下图形都画在自己的格子里，且不会被拉变形', (tester) async {
      for (final size in const <Size>[
        Size(320, 800),
        Size(360, 800),
        Size(412, 915),
        Size(360, 520),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(pad());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '尺寸 $size 下溢出');
        final figure = tester.getSize(find.byType(KeyFaceIconView));
        final cell = tester.getSize(find.ancestor(
          of: find.byType(KeyFaceIconView),
          matching: find.byType(InkWell),
        ));
        expect(figure.width, lessThanOrEqualTo(cell.width),
            reason: '$size：图形比格子还宽');
        expect(figure.height, lessThanOrEqualTo(cell.height),
            reason: '$size：图形比格子还高');
        expect(figure.width / figure.height,
            closeTo(KeyFaceIcon.matrix.aspectRatio, 0.01),
            reason: '$size：图形的长宽比必须还是量到的那个（118:86）');
      }
    });

    testWidgets('按图形那颗键：基准报 `ins:matrix`，SHIFT 态报 `openMatrixMenu`', (tester) async {
      final tapped = <String>[];
      final Finder key = find.ancestor(
        of: find.byType(KeyFaceIconView),
        matching: find.byType(InkWell),
      );
      await tester.pumpWidget(pad(onKey: tapped.add));
      await tester.tap(key);
      expect(tapped, <String>['ins:matrix'],
          reason: '键面换了画法，动作 id 一个字节都没变');

      await tester
          .pumpWidget(pad(modifier: KeypadModifier.shift, onKey: tapped.add));
      await tester.tap(key);
      expect(tapped, <String>['ins:matrix', 'openMatrixMenu'],
          reason: 'SHIFT 态下仍是那条 SHIFT id（面板由主屏打开，渲染层不认识它）');
    });
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
