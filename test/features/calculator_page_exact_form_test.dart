import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

// 中文：**端到端**：从主屏的按键开始，经过真实的控制器、真实的 `QalculateMathEngine`、被替换掉的
//       平台通道，一直到结果行上排出来的精确形式。这一步的交付物是「引擎最大的能力对用户可见」，
//       而「可见」只有在主屏上才量得出来——组件级的测试能钉住结果行的两种形态，钉不住「主屏有没有
//       把那两个字段传下去」。
//
//       回执里的数字是**实测**出来的引擎输出（`qalc` 5.12.0，与 App 里同一个 libqalculate 版本、
//       同一组 PrintOptions）：`sqrt(8)` → 十进制 `2.828427124746190`、LaTeX `2\times \sqrt{2}`。
//       精度 6 位小数下的显示形态是 `2.828427`。
//
//       除了这一次引擎问答，按键路径是**真的**：`√x` 再 `8` 打出的表达式是 `sqrt(8)`——**不要**再按
//       一次 `)`：`√x` 自己就补出了整对括号，再按一次得到的是 `sqrt(8))`（实测），那是一个解析不了的
//       表达式，按本轮的判据引擎根本不会被问到。这个文件的旧版本把这一步写成「`√x` 再 `8` 再 `)`」，
//       而循环里从来没有那个 `)`——修复轮 8 改了文件头（错的是文件头那一方，见下面循环上的注释）。
// English: **End to end**: from a keypad key on the main screen, through the real controller, the real
//          `QalculateMathEngine` and a replaced platform channel, to the exact form typeset on the
//          result line. This step's deliverable is "the engine's headline capability is visible to the
//          user", and "visible" can only be measured on the screen — a widget-level test pins the two
//          shapes of the result line but not whether the screen passes those two fields down.
//
//          The numbers in the receipt are **measured** engine output (`qalc` 5.12.0, the same
//          libqalculate version and PrintOptions the app carries): `sqrt(8)` → decimal
//          `2.828427124746190`, LaTeX `2\times \sqrt{2}`. At six decimal places the display form is
//          `2.828427`.
//
//          Apart from that one engine exchange the keystrokes are **real**: `√x` and `8` produce the
//          expression `sqrt(8)` — **do not** press `)` as well: `√x` writes the whole bracket pair and a
//          second `)` gives `sqrt(8))` (measured), an expression that does not parse and that, by this
//          round's criterion, is never even asked of the engine. The old version of this file said
//          "`√x`, `8` and `)`" in the header while the loop never pressed that `)` — fix round 8 changed
//          the header, since the header was the wrong side (see the comment over the loop).
void main() {
  const channel = MethodChannel('nekocalc/qalculate');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'evaluate') return null;
      return <String, String>{
        'ok': 'true',
        'decimal': '2.828427124746190',
        'latex': r'2\times \sqrt{2}',
        'aborted': 'false',
        'messages': '',
        'angleMode': 'RAD',
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // 中文：测试名跟着循环走（修复轮 8 的 nit）：按的是 `√x` 与 `8`，**没有** `)`——`√x` 自己就把括号
  //       补全了，名字里那个 `)` 是旧版本留下的、与循环不符的说法。
  // English: the test name follows the loop (fix round 8's nit): the keys are `√x` and `8`, with **no**
  //          `)` — `√x` closes the pair itself, and the `)` in the old name was a leftover that did not
  //          match the loop.
  testWidgets('按 √x 8 之后，结果行给出「排版好的精确形式 + 近似值」', (tester) async {
    await tester.pumpWidget(MaterialApp(
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
            groupThousands: false,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 中文：只按 `√x` 与 `8`——**不要**再按 `)`：`√x` 自己就补出了整对括号（步骤 5 的前置条件），
    //       再按一次右括号得到的是 `sqrt(8))`，那是一个解析不了的表达式，按本轮的判据引擎
    //       根本不会被问到。这一条测的是「精确形式上屏」，那需要一个**成立**的表达式。
    // English: only `√x` and `8` — do **not** press `)` as well: `√x` already writes the whole
    //          bracket pair (step 5's precondition), so a second `)` yields `sqrt(8))`, an
    //          expression that does not parse, and by this round's criterion the engine is never
    //          asked about those. This test is about the exact form reaching the screen, which
    //          needs an expression that holds up.
    for (final key in <String>['√x', '8']) {
      await tester.tap(find.text(key, findRichText: true).first);
      await tester.pump();
    }
    // 中文：边打边算的引擎跟进是 120ms 的防抖——`pumpAndSettle` 把它推完，不需要按等号。
    // English: the as-you-type engine follow-up is a 120 ms debounce; `pumpAndSettle` runs it out,
    //          and `=` is never pressed.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 中文：**结果行**里那一个直入 TeX 的排版视图。表达式行也有一个 `MathExpressionView`，但它
    //       永远不带 TeX。
    // English: the one TeX-driven typesetting view in the **result line**. The expression line has a
    //          `MathExpressionView` too, but it never carries TeX.
    final typeset = find.byWidgetPredicate(
      (widget) => widget is MathExpressionView && widget.tex.isNotEmpty,
    );
    expect(typeset, findsOneWidget);
    expect(
      tester.widget<MathExpressionView>(typeset).expression,
      '2.828427',
      reason: '结果行的纯文本形态仍然是按精度取整后的那一份',
    );
    expect(find.text('≈'), findsOneWidget);
    expect(find.text('2.828427'), findsOneWidget);
    // 中文：精确形式那一半没有以纯文本出现，说明它真的排出来了（退回纯文本就会多一个 Text）。
    // English: the exact half does not also appear as plain text, which means it really did typeset
    //          (a fallback would add a second `Text`).
    expect(find.text('2.828427124746190'), findsNothing);
  });

  testWidgets('打 `√(2x)·8`：结果行只有排出来的精确形式，没有 `≈` 那一半', (tester) async {
    // 中文：**真机上量到的那一行。** 它曾经是
    //       `= 8 × √2 × √x ≈ 11.31370849898476 * sqrt(x)`——右半边是引擎那串 ASCII 印法，而它
    //       **不是近似值**：`11.31370849898476 * sqrt(x)` 是同一个式子的另一种印法。
    //       回执按**实测**配（宿主 libqalculate 5.12.0，同一组 PrintOptions）：`sqrt(2x)*8` →
    //       十进制 `11.31370849898476 * sqrt(x)`、LaTeX `8\times \sqrt{2}\times \sqrt{x}`、种类
    //       `symbolic`。左边那一半仍然要排出来（这里是同一个渲染器自己的解析器），右边那一半按
    //       十进制形态缺席（符号结果没有十进制形态，实测）整个不出现。
    // English: **the line as measured on a device.** It used to read
    //          `= 8 × √2 × √x ≈ 11.31370849898476 * sqrt(x)` — the right half the engine's ASCII
    //          spelling, which **is not an approximation**: `11.31370849898476 * sqrt(x)` is the same
    //          expression spelled differently. The receipt is **measured** (host libqalculate 5.12.0,
    //          the same PrintOptions): `sqrt(2x)*8` → decimal `11.31370849898476 * sqrt(x)`, LaTeX
    //          `8\times \sqrt{2}\times \sqrt{x}`, kind `symbolic`. The left half still has to typeset
    //          (the renderer's own parser answers that here); the right half is dropped entirely
    //          because there is no decimal form — a symbolic result has none, measured.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'evaluate') return null;
      return <String, String>{
        'ok': 'true',
        'decimal': '11.31370849898476 * sqrt(x)',
        'latex': r'8\times \sqrt{2}\times \sqrt{x}',
        'aborted': 'false',
        'messages': '',
        'angleMode': 'RAD',
        'kind': 'symbolic',
      };
    });

    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();
    // 中文：**键盘上没有字母键**，`x` 只能从内联编辑器进去——这正是用户在设备上打这一串的路径。
    // English: **the keypad has no letter keys**, so `x` can only get in through the inline editor —
    //          which is how this expression gets typed on a device.
    await _typeExpression(tester, 'sqrt(2x)*8');

    expect(tester.takeException(), isNull);
    final typeset = find.byWidgetPredicate(
      (widget) => widget is MathExpressionView && widget.tex.isNotEmpty,
    );
    expect(typeset, findsOneWidget,
        reason: '精确形式仍然要排出来，不能因为去掉了 `≈` 就退回纯文本');
    expect(
      tester.widget<MathExpressionView>(typeset).tex,
      r'8\times \sqrt{2}\times \sqrt{x}',
    );
    expect(find.text('≈'), findsNothing, reason: '符号结果没有近似值可给');
    // 中文：引擎那串 ASCII 印法一个字都不该在结果行上——缺陷里的右半边就是它。
    // English: not one character of the engine's ASCII spelling belongs on the result line — that
    //          spelling is the defect's right half.
    expect(
      find.descendant(
        of: find.byType(CalculatorDisplay),
        matching: find.textContaining('11.31370849898476'),
      ),
      findsNothing,
    );
  });

  testWidgets('打 `log(100)`：结果行仍然是 `= 2`，不排版也不加 `≈`', (tester) async {
    // 中文：**不许回退的那一档。** `log(100)` 是应用自己的语言答得了的输入（`canRead` 为假），
    //       所以引擎这一份不算、旧解析器给 `2`：结果行没有精确形式，整行就是一个纯文本的
    //       `= 2`——接入引擎之前是什么样，现在还是什么样。回执给的是引擎**真机上量到的**答案
    //       `4.605170185988091`（自然对数，见 `calculator_engine_display_gate_test.dart`），
    //       屏幕必须显示 `2`。
    // English: **the case that must not regress.** `log(100)` is an input this app's own language can
    //          answer (`canRead` is false), so the engine's answer does not count and the legacy
    //          parser supplies `2`: the result line has no exact form and is a plain-text `= 2` —
    //          what it was before the engine existed. The receipt carries the engine's
    //          **device-measured** answer, `4.605170185988091` (the natural logarithm; see
    //          `calculator_engine_display_gate_test.dart`), and the screen must show `2`.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'evaluate') return null;
      return <String, String>{
        'ok': 'true',
        'decimal': '4.605170185988091',
        'latex': r'4.605170185988091',
        'aborted': 'false',
        'messages': '',
        'angleMode': 'RAD',
      };
    });

    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();
    // 中文：**按键必须限定在键盘里。** `log` 在表达式行上排成 `log₁₀`，那个下标本身就是两个字面
    //       为 `1`、`0` 的文本节点——不限定范围的 `find.text('1')` 会先命中它，点下去等于点表达式行，
    //       内联编辑器被打开，结果行整块从树里消失（实测：`display=0 textfield=1`）。
    // English: **the taps must stay inside the keypad.** `log` typesets as `log₁₀` on the expression
    //          line, and that subscript *is* two text nodes reading `1` and `0` — an unscoped
    //          `find.text('1')` hits one of those first, tapping it is tapping the expression line,
    //          the inline editor opens and the whole result row leaves the tree (measured:
    //          `display=0 textfield=1`).
    for (final key in <String>['log₁₀', '1', '0', '0']) {
      await tester.tap(find.descendant(
        of: find.byType(CalculatorKeypad),
        matching: find.text(key, findRichText: true),
      ));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is MathExpressionView && widget.tex.isNotEmpty,
      ),
      findsNothing,
    );
    expect(find.text('≈'), findsNothing);
    // 中文：结果行上的那个 `2`——键盘上另有一颗 `2` 键，所以这条断言限定在显示面板里。
    // English: the `2` **on the result line** — the keypad has a `2` key of its own, so this
    //          assertion stays inside the display panel.
    expect(
      find.descendant(
        of: find.byType(CalculatorDisplay),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(CalculatorDisplay),
        matching: find.textContaining('4.605170185988091'),
      ),
      findsNothing,
      reason: '引擎的答案（自然对数）不许上屏',
    );
  });
}

/// 中文：被测主屏——与前一条同样的设置（精度 6、自然排版开），只是表达式从内联编辑器里打进去。
/// English: The screen under test — the same settings as the test above (precision 6, natural
///          typesetting on); the expression just goes in through the inline editor.
Widget _page() => MaterialApp(
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
            groupThousands: false,
          ),
        ),
      ),
    );

/// 中文：把一段带字母的表达式打进主屏（`More...` → 编辑表达式 → 输入 → 失焦）。键盘上没有字母
///       键，含变量的表达式只能走这条路。
/// English: Types an expression carrying letters into the screen (`More...` → 编辑表达式 → type →
///          unfocus). The keypad has no letter keys, so anything with a variable goes through here.
Future<void> _typeExpression(WidgetTester tester, String expression) async {
  await tester.tap(find.text('More...'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('编辑表达式'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), expression);
  FocusManager.instance.primaryFocus!.unfocus();
  await tester.pumpAndSettle();
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
