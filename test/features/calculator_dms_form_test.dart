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

// 中文：`D°M'S` 那一颗键——结果行的**度分秒写法**（HiPER 的 `DMS` 那一格）。与 `d/c`/`x⇔E`
//       同一个形状，也分两层钉：
//
//       - **纯逻辑**（[ResultPresentation]）：这一格什么时候存在、按下去走到哪里、请求的形态不成立时
//         回落到哪里。这一层不碰组件，所以每一条边界都能单独钉住。
//       - **端到端**：从键盘按键开始，经过真实的控制器、真实的 `QalculateMathEngine`、被替换掉的
//         平台通道，到结果行上排出来的那一段。钉的是「主屏有没有把字段传下去、有没有把动作接上」。
//
//       回执里的数字与字符串全部是**实测**的引擎输出（宿主 `qalc` 5.12.0，与 App 里同一个
//       libqalculate 版本、同一组 PrintOptions：`fractions off`、`approximation approximate`、
//       `precision 16`，再加 `base sexagesimal`）：
//
//       | 输入            | `decimal`              | `dms`（度分秒印法）                |
//       |-----------------|------------------------|------------------------------------|
//       | `12.5822`       | `12.5822`              | `12°34′55.92″`                     |
//       | `1/3`           | `0.3333333333333333`   | `0°20′0″`                          |
//       | `-12.5822`      | `−12.5822`             | `−12°34′55.92″`（U+2212 减号）      |
//       | `2+2`           | `4`                    | `4°0′0″`                           |
//       | `sqrt(8)`（精确）| `2.828427124746190`    | `2°0′0″ × √(2°0′0″)` ← 判不过形状    |
//       | `2^2000`        | `1.148130695274255E602`| 同一串 ← 判不过形状（进制回落成十进制）|
//
//       最后两行是本文件里最重要的一对：它们是这台引擎上**真的会印出来**的两串，而它们都不是度分秒，
//       所以那一格必须整格不存在——`dms` 这一路上没有「差不多能排」这一档。
//
// English: The `D°M'S` key — the result line's **degrees-minutes-seconds spelling** (HiPER's `DMS`
//          cell). The same shape as `d/c`/`x⇔E`, pinned at the same two levels:
//
//          - **pure logic** ([ResultPresentation]): when this cell exists, where a press lands, and
//            where a requested form that does not hold falls back. This layer touches no widget, so
//            every boundary can be pinned on its own.
//          - **end to end**: from a keypad key, through the real controller, the real
//            `QalculateMathEngine` and a replaced platform channel, to the stretch typeset on the
//            result line. This pins what a widget-level test cannot — whether the screen passes the
//            fields down and wires the actions up.
//
//          Every number and string in the receipts is **measured** engine output (host `qalc` 5.12.0,
//          the app's libqalculate version and PrintOptions: `fractions off`, `approximation
//          approximate`, `precision 16`, plus `base sexagesimal`):
//
//          | input             | `decimal`               | `dms`                             |
//          |-------------------|-------------------------|-----------------------------------|
//          | `12.5822`         | `12.5822`               | `12°34′55.92″`                    |
//          | `1/3`             | `0.3333333333333333`    | `0°20′0″`                         |
//          | `-12.5822`        | `−12.5822`              | `−12°34′55.92″` (U+2212 minus)    |
//          | `2+2`             | `4`                     | `4°0′0″`                          |
//          | `sqrt(8)` (exact) | `2.828427124746190`     | `2°0′0″ × √(2°0′0″)` ← fails shape |
//          | `2^2000`          | `1.148130695274255E602` | the same string ← fails shape     |
//
//          The last two rows are the most important pair in this file: both are strings this engine
//          really does print, neither is degrees-minutes-seconds, and the cell therefore has to be
//          absent entirely — there is no "close enough to typeset" step on the `dms` path.
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
        'angleMode': 'DEG',
        ...payload,
      };
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ResultPresentation：度分秒那一格什么时候存在', () {
    // 中文：这一组用的都是**实测真的印出来过**的串（见文件头那张表）。
    // English: every string in this group is one the engine really printed (see the table above).

    test('`12.5822` 在 DEG 下：那一格存在，TeX 由引擎那一串改写而来', () {
      final p = ResultPresentation.of(
        resultTex: r'\num{12.5822}',
        fractionTex: r'\frac{62911}{5000}',
        resultDecimal: '12.5822',
        naturalDisplay: true,
        dmsText: '12°34′55.92″',
        degreesMode: true,
      );

      expect(p.hasDms, isTrue);
      // 中文：**数字一个都不是 Dart 算的**：三个十进制段原样搬过来，只在中间插上记号。
      // English: **not one digit is computed in Dart**: the three decimal sections come across as
      //          they are, with marks inserted between them.
      expect(p.dmsTex, r"12^\circ\,34'\,55.92''");
      expect(p.resolve(ResultForm.dms), ResultForm.dms);
      expect(p.texFor(ResultForm.dms), r"12^\circ\,34'\,55.92''");
      expect(p.showsApproximation(ResultForm.dms), isFalse,
          reason: '`≈` 那一半只属于默认形态');
    });

    test('同一份结果在 RAD 下：那一格不存在，键是空操作', () {
      final p = ResultPresentation.of(
        resultTex: r'\num{12.5822}',
        fractionTex: r'\frac{62911}{5000}',
        resultDecimal: '12.5822',
        naturalDisplay: true,
        dmsText: '12°34′55.92″',
        degreesMode: false,
      );

      // 中文：**这是这条路上唯一的模式判据，而且它在 Dart 侧**：`°` 是一句「这个数是若干度」的
      //       断言，RAD 模式下那个数是弧度，写成度分秒就是换了一个单位——那是改结果行的含义，
      //       不是换一种写法。引擎那一串照样送上来（原生侧不管角度模式），画不画由这里决定。
      // English: **the only mode test on this path, and it lives on the Dart side**: `°` is the claim
      //          "this number is so many degrees", and under RAD that number is radians, so writing
      //          it as DMS changes the unit — that changes what the result line means rather than
      //          spelling it differently. The engine's string still arrives (the native side does not
      //          look at the angle mode); whether it is drawn is decided here.
      expect(p.hasDms, isFalse);
      expect(p.dmsTex, isEmpty);
      expect(p.resolve(ResultForm.dms), ResultForm.auto);
      expect(p.toggleDms(ResultForm.auto), ResultForm.auto);
      expect(p.texFor(ResultForm.auto), isEmpty,
          reason: '这一份结果的精确印法是排不出来的 `\\num{…}`，所以默认那一行整行纯文本——'
              '加这颗键之前就是这样，RAD 下也没有变');
    });

    test('形状判不过的引擎串：整格不存在（三种都是实测真的会印出来的串）', () {
      const rejected = <String>[
        '2°0′0″ × √(2°0′0″)', // 精确结构上的无理数
        '[1°0′0″  2°0′0″; 3°0′0″  4°0′0″]', // 矩阵
        '1°0′0″ / 0°0′0″', // 无穷
        '1.148130695274255E602', // 超出 double 量程，进制回落成十进制
        '0°20′0', // 只有两段
        '12°34.932′', // `sexa2` 那一档（引擎的另一种印法，不是三段）
        '12o34\'55.92"', // unicode 关掉时的拼法：度符号是字母 `o`
        '0°20′0″x', // 尾巴上多一个字符
      ];

      for (final text in rejected) {
        final p = ResultPresentation.of(
          resultTex: '',
          fractionTex: '',
          resultDecimal: '4',
          naturalDisplay: true,
          dmsText: text,
          degreesMode: true,
        );

        expect(p.hasDms, isFalse, reason: '`$text` 不是度分秒，这一格必须整格不存在');
        expect(p.toggleDms(ResultForm.auto), ResultForm.auto,
            reason: '`$text`：拿不准时宁可没有这一格，也不印一串读不出来的东西');
      }
    });

    test('首尾空白不影响形状（原生侧与引擎桥都 trim 过，这里再兜一次）', () {
      final p = ResultPresentation.of(
        resultTex: '',
        fractionTex: '',
        resultDecimal: '12.5822',
        naturalDisplay: true,
        dmsText: ' 12°34′55.92″ ',
        degreesMode: true,
      );

      expect(p.dmsTex, r"12^\circ\,34'\,55.92''");
    });

    test('U+2212 减号换成 ASCII `-`，与洗十进制那一份同一条规矩', () {
      final p = ResultPresentation.of(
        resultTex: '',
        fractionTex: '',
        resultDecimal: '-12.5822',
        naturalDisplay: true,
        dmsText: '−12°34′55.92″',
        degreesMode: true,
      );

      expect(p.dmsTex, r"-12^\circ\,34'\,55.92''");
    });

    test("`D°M'S` 按下去是「度分秒 ⇄ 默认」，再按一次回到原来那一行", () {
      final p = ResultPresentation.of(
        resultTex: r'2\times \sqrt{2}',
        fractionTex: r'2\times \sqrt{2}',
        resultDecimal: '2.828427124746190',
        naturalDisplay: true,
        dmsText: '2°49′42.33764908628435″',
        degreesMode: true,
      );

      expect(p.toggleDms(ResultForm.auto), ResultForm.dms);
      expect(p.toggleDms(ResultForm.dms), ResultForm.auto);
      // 中文：从别的形态按 D°M'S 也是直接换到度分秒——它是一次开关，不是循环里的一格。
      // English: pressing `D°M'S` from another form switches straight to DMS — it is a toggle, not a
      //          cell in the cycle.
      expect(p.toggleDms(ResultForm.exact), ResultForm.dms);
      expect(p.toggleDms(ResultForm.decimal), ResultForm.dms);
    });

    test('规则 3：`x⇔E` 的循环一个格子都没变——`dms` 不在里面', () {
      // 中文：同一份结果，给不给度分秒那一格，`cycle`/`next` 必须逐项相同。这条是**加法**那条
      //       硬规矩的可测形式：`x⇔E` 按出来的每一步与接这颗键之前逐字节一致。
      // English: for one result, the `cycle`/`next` results must be identical whether or not the DMS
      //          cell exists. This is the testable form of the "addition only" rule: every step
      //          `x⇔E` takes is byte-for-byte what it was before this key existed.
      final withoutKey = ResultPresentation.of(
        resultTex: r'2\times \sqrt{2}',
        fractionTex: r'2\times \sqrt{2}',
        resultDecimal: '2.828427124746190',
        naturalDisplay: true,
      );
      final withKey = ResultPresentation.of(
        resultTex: r'2\times \sqrt{2}',
        fractionTex: r'2\times \sqrt{2}',
        resultDecimal: '2.828427124746190',
        naturalDisplay: true,
        dmsText: '2°49′42.33764908628435″',
        degreesMode: true,
      );

      expect(withKey.cycle, withoutKey.cycle);
      expect(withKey.next(ResultForm.auto), withoutKey.next(ResultForm.auto));
      expect(withKey.next(ResultForm.exact), withoutKey.next(ResultForm.exact));
      expect(withKey.cycle, isNot(contains(ResultForm.dms)),
          reason: '`dms` 进循环就等于改了 `x⇔E` 的行为');
      // 中文：从度分秒那一格按 `x⇔E`，走的是「当前形态不在循环里 → 循环的第一个」这条既有规则。
      // English: pressing `x⇔E` while on the DMS cell takes the existing "current form is not in the
      //          cycle → the cycle's first entry" rule.
      expect(withKey.next(ResultForm.dms), withKey.cycle.first);
    });

    test('自然排版关掉时这一格也排不出来（与其余几格同一条既有门槛）', () {
      final p = ResultPresentation.of(
        resultTex: r'2\times \sqrt{2}',
        fractionTex: r'2\times \sqrt{2}',
        resultDecimal: '2.828427124746190',
        naturalDisplay: false,
        dmsText: '2°49′42.33764908628435″',
        degreesMode: true,
      );

      expect(p.hasDms, isFalse);
    });
  });

  group("端到端：`D°M'S` 把结果换成度分秒写法", () {
    testWidgets('DEG 下按一下：结果行排出度分秒，数字真的换了，再按一次回到原来那一行', (tester) async {
      // 中文：`12.5822` 那一行 —— `decimal`/`latex`/`dms` 三串都是宿主实测的引擎输出。
      // English: the `12.5822` row — all three strings are host-measured engine output.
      reply(<String, String>{
        'decimal': '12.5822',
        'latex': r'\num{12.5822}',
        'fraction': r'\frac{62911}{5000}',
        'dms': '12°34′55.92″',
        'kind': 'number',
      });

      await tester.pumpWidget(_page(angleMode: 'DEG'));
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '2', '.', '5', '8', '2', '2']);
      await tester.pumpAndSettle();

      // 中文：**按之前**：精确印法 `\num{…}` 排不出来，结果行是一行纯文本读数。
      // English: **before the press**: the exact print `\num{…}` does not typeset, and the result
      //          line is a plain reading.
      expect(_typesetResult(), findsNothing);
      expect(_display(tester).result, '12.5822');
      expect(_display(tester).resultDecimal, '12.5822');

      await _tapKey(tester, "D°M'S");

      // 中文：**排出来了**，而且不是降级成字面文本：树里是一棵真的公式（`flutter_math_fork` 的
      //       `Math`），`\circ` 这些记号一个字符都不许作为文本出现。同时——这一颗是**格式键**——
      //       数字必须真的换了：原来那行纯文本读数不再出现在结果行上。
      // English: **it typeset**, and not by degrading to literal text: the tree holds a real formula
      //          (`flutter_math_fork`'s `Math`) and none of the `\circ` markup may appear on screen as
      //          text. And — this is a **format** key — the digits really changed: the plain reading
      //          the line had is no longer drawn on the result line.
      expect(_typesetResult(), findsOneWidget);
      expect(tester.widget<MathExpressionView>(_typesetResult()).tex,
          r"12^\circ\,34'\,55.92''");
      expect(
        find.descendant(of: _typesetResult(), matching: find.byType(Math)),
        findsOneWidget,
        reason: '真排出来了：树里是一棵公式，不是一段原文',
      );
      expect(find.textContaining(r'\circ'), findsNothing);
      expect(find.textContaining(r'\text'), findsNothing,
          reason: '引擎的 LaTeX 那一份是 `\\text{12o34\'55.92"}`，那一段不许上屏');
      expect(_display(tester).resultDecimal, '12.5822',
          reason: '值一个字节都没动——度分秒只是同一个数的另一种写法');

      await _tapKey(tester, "D°M'S");

      // 中文：再按一次回到原来那一行，与按之前逐字符相同。
      // English: a second press returns to the line it had, character for character.
      expect(_typesetResult(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CalculatorDisplay),
          matching: find.text('12.5822'),
        ),
        findsOneWidget,
      );
      expect(_display(tester).resultDecimal, '12.5822');
    });

    testWidgets('RAD 下按一下：屏幕上什么都不变（老实的空操作，不是假装换了点什么）', (tester) async {
      // 中文：原生侧照样把 `dms` 送上来（它不管角度模式），画不画由 Dart 侧那一处判据决定。
      // English: the native side sends `dms` regardless (it does not look at the angle mode); whether
      //          it is drawn is decided by the one judgement on the Dart side.
      reply(<String, String>{
        'decimal': '12.5822',
        'latex': r'\num{12.5822}',
        'fraction': r'\frac{62911}{5000}',
        'dms': '12°34′55.92″',
        'kind': 'number',
      });

      await tester.pumpWidget(_page(angleMode: 'RAD'));
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '2', '.', '5', '8', '2', '2']);
      await tester.pumpAndSettle();

      expect(_display(tester).resultDmsText, '12°34′55.92″',
          reason: '字段确实传到了显示区——不画它是因为角度模式，不是因为没收到');

      await _tapKey(tester, "D°M'S");

      expect(tester.takeException(), isNull);
      expect(_typesetResult(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CalculatorDisplay),
          matching: find.text('12.5822'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('引擎没答上来（旧解析器上屏）：空操作，也不去猜一个', (tester) async {
      // 中文：回执里没有 `dms` 字段——原生侧版本不匹配就是这一种，旧解析器上屏也是这一种。
      // English: the receipt has no `dms` field — a native version mismatch, or the legacy parser on
      //          screen; they are the same case here.
      reply(<String, String>{'decimal': '12.5822', 'latex': r'\num{12.5822}'});

      await tester.pumpWidget(_page(angleMode: 'DEG'));
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '2', '.', '5', '8', '2', '2']);
      await tester.pumpAndSettle();

      expect(_display(tester).resultDmsText, isEmpty);

      await _tapKey(tester, "D°M'S");

      expect(tester.takeException(), isNull);
      expect(_typesetResult(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CalculatorDisplay),
          matching: find.text('12.5822'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('值路径不受影响：`Ans` 拿到的仍是十进制形态，不是度分秒', (tester) async {
      reply(<String, String>{
        'decimal': '12.5822',
        'latex': r'\num{12.5822}',
        'fraction': r'\frac{62911}{5000}',
        'dms': '12°34′55.92″',
        'kind': 'number',
      });

      await tester.pumpWidget(_page(angleMode: 'DEG'));
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '2', '.', '5', '8', '2', '2']);
      await tester.pumpAndSettle();

      await _tapKey(tester, "D°M'S");
      expect(tester.widget<MathExpressionView>(_typesetResult()).tex,
          r"12^\circ\,34'\,55.92''");

      await _typeKeys(tester, <String>['Ans']);
      await tester.pumpAndSettle();

      final appended = _display(tester).expression;
      expect(appended, endsWith('12.5822'),
          reason: '`Ans` 送进表达式的是十进制形态，不是度分秒那一串');
      expect(appended, isNot(contains('°')),
          reason: '写法绝不进表达式——那一串不是应用语法里的数');
    });
  });
}

/// 中文：结果行里那一个**直入 TeX** 的排版视图（与 `calculator_result_form_test.dart` 同一把尺）。
/// English: The one TeX-driven typesetting view in the result line (the same instrument as
///          `calculator_result_form_test.dart`).
Finder _typesetResult() => find.byWidgetPredicate(
      (widget) => widget is MathExpressionView && widget.tex.isNotEmpty,
    );

CalculatorDisplay _display(WidgetTester tester) =>
    tester.widget<CalculatorDisplay>(find.byType(CalculatorDisplay));

/// 中文：按一颗键。**限定在键盘里**：键面文字在显示区里也可能出现（`Ans` 之后的表达式行、结果
///       行），不限定范围的 `find.text` 会先命中那一个。
/// English: Press a key. **Scoped to the keypad**: faces can also appear in the display band (the
///          expression line after `Ans`, the result line), and an unscoped `find.text` would hit that
///          one first.
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

Widget _page({required String angleMode}) => MaterialApp(
      home: Scaffold(
        body: CalculatorPage(
          db: _FakeDatabase(),
          onOpenSettings: () {},
          settings: AppSettings(
            haptics: false,
            hapticStrength: '标准',
            restoreState: false,
            autoSaveHistory: false,
            angleMode: angleMode,
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
