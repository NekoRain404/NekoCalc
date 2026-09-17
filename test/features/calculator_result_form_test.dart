import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/result_form.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

// 中文：`x⇔E` 与 `d/c` 两颗结果格式键。分两层钉：
//
//       - **纯逻辑**（[ResultPresentation]）：哪几种形态存在、按下去走到哪一种、请求的形态在结果上
//         不成立时回落到哪里。这一层不碰组件，所以每一条边界都能单独钉住。
//       - **端到端**：从键盘按键开始，经过真实的控制器、真实的 `QalculateMathEngine`、被替换掉的
//         平台通道，到结果行上排出来的那一段。这一层钉的是「主屏有没有把字段传下去、有没有把动作
//         接上」——组件级测试钉不住那两件事。
//
//       回执里的数字与 LaTeX 全部是**实测**的引擎输出（`qalc` 5.12.0，与 App 里同一个 libqalculate
//       版本、同一组 PrintOptions）：
//
//       | 输入      | `decimal`              | `latex`（精确）                  | `fraction`（分数）    |
//       |-----------|------------------------|----------------------------------|-----------------------|
//       | `1/3`     | `0.3333333333333333`   | `\num{0.3333333333333333}`       | `\frac{1}{3}`         |
//       | `sqrt(8)` | `2.828427124746190`    | `2\times \sqrt{2}`               | `2\times \sqrt{2}`    |
//       | `2+2`     | `4`                    | `4`                              | `4`                   |
//
//       三行的形状本身就是这条设计的全部理由：**`1/3` 的精确印法是一个十进制数**（引擎的分数格式
//       被钉在 `FRACTION_DECIMAL`），所以没有分数那一份时 `1/3` 在屏幕上永远只是 `0.333333`；
//       而 `\sqrt{8}` 的分数印法与精确印法**逐字符相同**（无理数没有分数线可画），所以那一格对它
//       不存在。`2+2` 两份都等于那串十进制，于是它只有一种画法。
//
// English: The two result-format keys, `x⇔E` and `d/c`, pinned at two levels:
//
//          - **pure logic** ([ResultPresentation]): which forms exist, where a press lands, and where
//            a requested form that this result does not have falls back. This layer touches no widget,
//            so every boundary can be pinned on its own.
//          - **end to end**: from a keypad key, through the real controller, the real
//            `QalculateMathEngine` and a replaced platform channel, to the stretch typeset on the
//            result line. This layer pins what a widget-level test cannot — whether the screen passes
//            the fields down and whether it wires the actions up.
//
//          Every number and LaTeX string here is **measured** engine output (`qalc` 5.12.0, the same
//          libqalculate version and PrintOptions the app carries):
//
//          | input     | `decimal`              | `latex` (exact)            | `fraction`         |
//          |-----------|------------------------|----------------------------|--------------------|
//          | `1/3`     | `0.3333333333333333`   | `\num{0.3333333333333333}` | `\frac{1}{3}`      |
//          | `sqrt(8)` | `2.828427124746190`    | `2\times \sqrt{2}`         | `2\times \sqrt{2}` |
//          | `2+2`     | `4`                    | `4`                        | `4`                |
//
//          Those three rows are the whole reason for this design: **`1/3`'s exact print is a decimal**
//          (the engine's fraction format is pinned to `FRACTION_DECIMAL`), so without the fraction
//          render `1/3` can never be anything but `0.333333` on screen; `\sqrt{8}`'s fraction print is
//          **character for character** its exact print (an irrational has no fraction bar to draw), so
//          that cell does not exist for it; and `2+2` has both equal to that decimal, so it has one
//          drawing only.
void main() {
  const channel = MethodChannel('nekocalc/qalculate');

  void reply(Map<String, String> payload) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'evaluate') return null;
      return <String, String>{
        'ok': 'true',
        'aborted': 'false',
        'messages': '',
        'angleMode': 'RAD',
        ...payload,
      };
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ResultPresentation：哪几种形态存在', () {
    test('`√8`：精确写法排得出来，分数写法与它逐字符相同，于是那一格不存在', () {
      final p = ResultPresentation.of(
        resultTex: r'2\times \sqrt{2}',
        fractionTex: r'2\times \sqrt{2}',
        resultDecimal: '2.828427124746190',
        naturalDisplay: true,
      );

      expect(p.exactTex, r'2\times \sqrt{2}');
      expect(p.fractionTex, isEmpty,
          reason: '与精确写法逐字符相同的分数写法多一格没有意义');
      expect(p.cycle, <ResultForm>[ResultForm.exact, ResultForm.decimal]);
    });

    test('`1/3`：精确印法是排不出来的 `\\num{…}`，分数写法是唯一另一种画法', () {
      final p = ResultPresentation.of(
        resultTex: r'\num{0.3333333333333333}',
        fractionTex: r'\frac{1}{3}',
        resultDecimal: '0.3333333333333333',
        naturalDisplay: true,
      );

      expect(p.exactTex, isEmpty, reason: '`\\num{…}` 排不出来，所以没有精确形态');
      expect(p.fractionTex, r'\frac{1}{3}');
      // 中文：十进制形态画出来与默认形态**逐字符相同**（都是 `0.333333`），所以它被合并掉——
      //       循环里不会出现一次「按下去什么都没变」。
      // English: the decimal form draws **character for character** the same as the default one
      //          (both `0.333333`), so it is merged away and the cycle contains no press that
      //          changes nothing.
      expect(p.cycle, <ResultForm>[ResultForm.fraction]);
      expect(p.resolve(ResultForm.decimal), ResultForm.auto,
          reason: '在 `1/3` 上请求十进制形态本来就不改变画面，回落到 auto');
    });

    test('`2+2`：两种写法都等于那串十进制，所以只有一种画法', () {
      final p = ResultPresentation.of(
        resultTex: '4',
        fractionTex: '4',
        resultDecimal: '4',
        naturalDisplay: true,
      );

      expect(p.cycle, isEmpty);
      expect(p.next(ResultForm.auto), ResultForm.auto, reason: '没有第二种画法，按下去不该动');
      expect(p.toggleStandard(ResultForm.auto), ResultForm.auto);
    });

    test('自然排版关掉时一种形态都排不出来，两颗键都是空操作', () {
      final p = ResultPresentation.of(
        resultTex: r'2\times \sqrt{2}',
        fractionTex: r'\frac{1}{3}',
        resultDecimal: '2.828427124746190',
        naturalDisplay: false,
      );

      expect(p.exactTex, isEmpty);
      expect(p.fractionTex, isEmpty);
      expect(p.cycle, isEmpty);
    });

    test('请求的形态这一份结果没有时一律回落到 auto——这是这条路的 fail-closed', () {
      final p = ResultPresentation.of(
        resultTex: r'2\times \sqrt{2}',
        fractionTex: r'2\times \sqrt{2}',
        resultDecimal: '2.828427124746190',
        naturalDisplay: true,
      );

      expect(p.resolve(ResultForm.fraction), ResultForm.auto,
          reason: '换了一份结果之后，上一份选的形态不许留下来把这一份画成空白');
      expect(p.resolve(ResultForm.decimal), ResultForm.decimal);
      expect(p.resolve(ResultForm.auto), ResultForm.auto);
    });

    test('循环：auto → exact → decimal → auto', () {
      final p = ResultPresentation.of(
        resultTex: r'2\times \sqrt{2}',
        fractionTex: r'2\times \sqrt{2}',
        resultDecimal: '2.828427124746190',
        naturalDisplay: true,
      );

      final first = p.next(ResultForm.auto);
      expect(first, ResultForm.exact);
      final second = p.next(first);
      expect(second, ResultForm.decimal);
      expect(p.next(second), ResultForm.auto, reason: '走完一圈回到默认形态');
    });

    test('`d/c` 优先切分数，没有分数时退回精确写法（`√8`），两者都没有时空操作', () {
      final rational = ResultPresentation.of(
        resultTex: r'\num{0.3333333333333333}',
        fractionTex: r'\frac{1}{3}',
        resultDecimal: '0.3333333333333333',
        naturalDisplay: true,
      );
      expect(rational.toggleStandard(ResultForm.auto), ResultForm.fraction);
      expect(rational.toggleStandard(ResultForm.fraction), ResultForm.auto);

      final irrational = ResultPresentation.of(
        resultTex: r'2\times \sqrt{2}',
        fractionTex: r'2\times \sqrt{2}',
        resultDecimal: '2.828427124746190',
        naturalDisplay: true,
      );
      expect(irrational.toggleStandard(ResultForm.auto), ResultForm.exact,
          reason: '无理数没有分数写法，标准写法就是它排出来的精确形式');
    });

    test('`≈` 那一半只在默认形态上画，而且仍要满足既有的那条不变式', () {
      final p = ResultPresentation.of(
        resultTex: r'2\times \sqrt{2}',
        fractionTex: r'2\times \sqrt{2}',
        resultDecimal: '2.828427124746190',
        naturalDisplay: true,
      );

      expect(p.showsApproximation(ResultForm.auto), isTrue);
      expect(p.showsApproximation(ResultForm.exact), isFalse);
      expect(p.showsApproximation(ResultForm.decimal), isFalse);
      expect(p.texFor(ResultForm.auto), r'2\times \sqrt{2}');
      expect(p.texFor(ResultForm.decimal), isEmpty);
    });
  });

  group('端到端：`d/c` 把结果换成分数写法', () {
    testWidgets('`1/3` 按 `d/c` 排出 `\\frac{1}{3}`，再按一次回到十进制读数', (tester) async {
      reply(<String, String>{
        'decimal': '0.3333333333333333',
        'latex': r'\num{0.3333333333333333}',
        'fraction': r'\frac{1}{3}',
        'kind': 'number',
      });

      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '÷', '3']);
      await tester.pumpAndSettle();

      // 中文：**按 `d/c` 之前**：精确印法 `\num{…}` 排不出来，所以结果行是纯文本 `= 0.333333`。
      // English: **before `d/c`**: the exact print `\num{…}` does not typeset, so the result line is
      //          the plain text `= 0.333333`.
      expect(_typesetResult(), findsNothing);
      expect(_display(tester).resultDecimal, '0.3333333333333333');

      await _tapKey(tester, 'd/c');

      // 中文：**排出来了**，而且不是降级成字面文本：`typesetResult` 找的就是那一个直入 TeX 的
      //       `MathExpressionView`，它的 `tex` 非空；再往下问一层——渲染出来的是一棵真的公式树
      //       （`flutter_math_fork` 的 `Math`），而不是退化成 `Text` 的原文。同时 `\frac`/`\num`
      //       这些宏一个字符都不许作为文本出现在屏幕上。
      // English: **it typeset**, and it did not degrade to literal text: `typesetResult` finds the one
      //          TeX-driven `MathExpressionView` and its `tex` is non-empty; one layer further down,
      //          what was rendered is a real formula tree (`flutter_math_fork`'s `Math`) rather than a
      //          `Text` holding the source. And not one character of the `\frac`/`\num` macros may
      //          appear on screen as text.
      expect(_typesetResult(), findsOneWidget);
      expect(tester.widget<MathExpressionView>(_typesetResult()).tex, r'\frac{1}{3}');
      expect(
        find.descendant(
          of: _typesetResult(),
          matching: find.byType(Math),
        ),
        findsOneWidget,
        reason: '真排出来了：树里是一棵公式，不是一段原文',
      );
      expect(find.textContaining(r'\frac'), findsNothing);
      expect(find.textContaining(r'\num'), findsNothing);
      // 中文：**值一个字节都没动**——分数那一份只是同一个结构的另一种写法。
      // English: **the value did not move by a byte** — the fraction is the same structure spelled
      //          differently.
      expect(_display(tester).resultDecimal, '0.3333333333333333');
      expect(_display(tester).result, '0.333333');

      await _tapKey(tester, 'd/c');

      // 中文：再按一次回到十进制读数，与按之前那一行逐字符相同。
      // English: a second press returns to the decimal reading, character for character the line from
      //          before.
      expect(_typesetResult(), findsNothing);
      expect(_display(tester).resultDecimal, '0.3333333333333333');
      expect(
        find.descendant(
          of: find.byType(CalculatorDisplay),
          matching: find.text('0.333333'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('值路径不受影响：`Ans` 拿到的仍是十进制形态，不是分数', (tester) async {
      reply(<String, String>{
        'decimal': '0.3333333333333333',
        'latex': r'\num{0.3333333333333333}',
        'fraction': r'\frac{1}{3}',
        'kind': 'number',
      });

      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '÷', '3']);
      await tester.pumpAndSettle();

      await _tapKey(tester, 'd/c');
      // 中文：屏幕上这时是排出来的 `\frac{1}{3}`。`Ans` 仍必须送进**十进制形态**——形态是画法，
      //       不是值；送分数进去等于把一段 LaTeX 写进表达式。
      // English: the screen now shows the typeset `\frac{1}{3}`. `Ans` must still insert the **decimal
      //          form** — a form is a drawing, not a value, and inserting the fraction would write a
      //          piece of LaTeX into the expression.
      expect(tester.widget<MathExpressionView>(_typesetResult()).tex, r'\frac{1}{3}');

      await _typeKeys(tester, <String>['Ans']);
      await tester.pumpAndSettle();

      final appended = _display(tester).expression;
      expect(appended, endsWith('0.3333333333333333'),
          reason: '`Ans` 送进表达式的是十进制形态');
      expect(appended, isNot(contains(r'\frac')),
          reason: '形态绝不进表达式——那会把一段 LaTeX 写进去');
    });
  });

  group('端到端：`x⇔E` 循环结果行的形态', () {
    testWidgets('`√8`：默认 → 精确 → 十进制 → 默认', (tester) async {
      reply(<String, String>{
        'decimal': '2.828427124746190',
        'latex': r'2\times \sqrt{2}',
        'fraction': r'2\times \sqrt{2}',
        'kind': 'number',
      });

      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['√x', '8']);
      await tester.pumpAndSettle();

      // 1. 默认：精确形式 + `≈` 读数。
      expect(tester.widget<MathExpressionView>(_typesetResult()).tex, r'2\times \sqrt{2}');
      expect(find.text('≈'), findsOneWidget);

      // 2. 精确形态：只剩排出来的那一段，`≈` 那一半整个不出现。
      await _tapKey(tester, 'x⇔E');
      expect(tester.widget<MathExpressionView>(_typesetResult()).tex, r'2\times \sqrt{2}');
      expect(find.text('≈'), findsNothing);

      // 3. 十进制形态：一段都不排，整行就是读数。
      await _tapKey(tester, 'x⇔E');
      expect(_typesetResult(), findsNothing);
      expect(find.text('≈'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CalculatorDisplay),
          matching: find.text('2.828427'),
        ),
        findsOneWidget,
      );

      // 4. 回到默认——与第 1 步逐字符相同的画面。
      await _tapKey(tester, 'x⇔E');
      expect(tester.widget<MathExpressionView>(_typesetResult()).tex, r'2\times \sqrt{2}');
      expect(find.text('≈'), findsOneWidget);
    });

    testWidgets('`2+2`：只有一种画法，两颗键按下去都不改变屏幕', (tester) async {
      reply(<String, String>{
        'decimal': '4',
        'latex': '4',
        'fraction': '4',
        'kind': 'number',
      });

      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['2', '+', '2']);
      await tester.pumpAndSettle();

      expect(_typesetResult(), findsNothing);
      for (final key in <String>['x⇔E', 'd/c', 'x⇔E', 'd/c']) {
        await _tapKey(tester, key);
        expect(_typesetResult(), findsNothing,
            reason: '$key 之后仍然是纯文本读数：这一份结果没有第二种画法');
        expect(
          find.descendant(
            of: find.byType(CalculatorDisplay),
            matching: find.text('4'),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('引擎没答上来（旧解析器上屏）：两颗键都是空操作，那一行一个字节不变', (tester) async {
      // 中文：回执里没有 `fraction` 字段——原生侧版本不匹配就是这一种，旧解析器上屏也是这一种。
      reply(<String, String>{'decimal': '0.3333333333333333'});

      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '÷', '3']);
      await tester.pumpAndSettle();

      expect(_display(tester).resultFractionTex, isEmpty);
      expect(_typesetResult(), findsNothing);

      for (final key in <String>['d/c', 'x⇔E']) {
        await _tapKey(tester, key);
        expect(tester.takeException(), isNull);
        expect(_typesetResult(), findsNothing, reason: '$key 没有分数可给，也不许去猜一个');
        expect(
          find.descendant(
            of: find.byType(CalculatorDisplay),
            matching: find.text('0.333333'),
          ),
          findsOneWidget,
        );
      }
    });
  });
}

/// 中文：结果行里那一个**直入 TeX** 的排版视图。表达式行也有一个 `MathExpressionView`，但它永远
///       不带 TeX，所以「带 tex 的那些」正好就是结果行排出来的那一段。
/// English: The one TeX-driven typesetting view in the result line. The expression line has a
///          `MathExpressionView` too, but it never carries TeX, so "those with a tex" are exactly the
///          stretch the result line typeset.
Finder _typesetResult() => find.byWidgetPredicate(
      (widget) => widget is MathExpressionView && widget.tex.isNotEmpty,
    );

CalculatorDisplay _display(WidgetTester tester) =>
    tester.widget<CalculatorDisplay>(find.byType(CalculatorDisplay));

/// 中文：按一颗键。**限定在键盘里**：`d/c`、`x⇔E` 这些键面文字在显示区里也可能出现（`Ans` 之后
///       的表达式行、结果行），不限定范围的 `find.text` 会先命中那一个。
/// English: Press a key. **Scoped to the keypad**: faces like `d/c` and `x⇔E` can also appear in the
///          display band (the expression line after `Ans`, the result line), and an unscoped
///          `find.text` would hit that one first.
Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.descendant(
    of: find.byType(CalculatorKeypad),
    matching: find.text(key, findRichText: true),
  ));
  await tester.pumpAndSettle();
}

Future<void> _typeKeys(WidgetTester tester, List<String> keys) async {
  for (final key in keys) {
    await tester.tap(find.descendant(
      of: find.byType(CalculatorKeypad),
      matching: find.text(key, findRichText: true),
    ));
    await tester.pump();
  }
}

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

class _FakeDatabase implements AppDatabase {
  final Map<String, String> savedSettings = <String, String>{};

  @override
  Future<Map<String, String>> settings() async =>
      Map<String, String>.from(savedSettings);

  @override
  Future<void> setSettings(Map<String, String> values) async {
    savedSettings.addAll(values);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
