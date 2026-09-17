import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
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
