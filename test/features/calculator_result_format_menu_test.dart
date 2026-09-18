import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_strings.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/result_form.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/result_format_sheet.dart';
import 'package:nekocalc/l10n/app_language.dart';

// 中文：**`x⇔E` 打开的「Select Result Format」菜单。** 这个文件钉三件事：
//
//       1. **菜单的形状与它每一项的来源**：第 0 项是本应用自己那一行，其后六项是 HiPER 自己的
//          `rfMenu.*`，名字与顺序都照抄厂商的字符串表。
//       2. **每一格今天做不做得出**（以及做不出的那一项的**到期日**断言）。
//       3. **形式切换只改显示、永不改值**——同一个结果切遍几种写法，`decimalText` 与它解析出的
//          数值一个字节都不动。
//       4. **灰着的那几格说不说实话**（本轮补上）。引擎没有参与这一份结果时（`表达式显示` =
//          `数学表达式` 之下边打边算根本不问引擎），那几格灰着**不是**因为这一份结果画不出来，
//          所以每一格要写明本应用这一侧的原因，而菜单标题那句「灰掉的那一项是这一份结果画不出来
//          的」必须消失。**按 `=` 提交不走这条 kill switch**——这一条也是本轮量出来的（见
//          「`数学表达式` 下按 `=`」那一条），它决定理由那一行该说哪一句。
//
//       厂商的原文（`/tmp/hiper_en.po`，本机取回，逐行引用）：
//
//       ```
//       msgctxt "rfMenu.title"       msgid "Select Result Format"
//       msgctxt "rfMenu.decimal"     msgid "Decimal <tabt:%0>"
//       msgctxt "rfMenu.expression"  msgid "Expression <tabt:%0>"
//       msgctxt "rfMenu.fraction"    msgid "Fraction <tabt:%0>"
//       msgctxt "rfMenu.mixedNumber" msgid "Mixed number <tabt:%0>"
//       msgctxt "rfMenu.dms"         msgid "Degrees, mins, secs <tabt:%0>"
//       msgctxt "rfMenu.polar"       msgid "Polar coordinates <tabt:%0>"
//       ```
//
//       厂商 FAQ（`https://hiperlabs.eu/help.html`，与 `/tmp/hiperhelp.txt` 逐字相同）：
//       "To convert a result between the two forms, press the `x⇔E` key. **It opens the Select Result
//       Format menu**, where you choose `Polar coordinates` for the polar form, or `Decimal` (or
//       `Expression`) to get back to the rectangular form."
//       手册 v12.0（`/tmp/hipercalc-manual.txt`）："press `x⇔E` and **choose** one of the following
//       formats"；帮助文本给出的六种写法例子是 `4.505` / `2√3/5` / `11 2/7` / `4°30′20″` / `7∠45`。
//
// English: **The "Select Result Format" menu `x⇔E` opens.** This file pins three things: the menu's
//          shape and where each entry comes from; what each cell can do today (with the **expiry**
//          assertions for the one it cannot); and **form switching changes the display and never the
//          value** — switching one result through several spellings leaves `decimalText` and the number
//          it parses to untouched; and **whether the grey cells tell the truth** (added this round):
//          with the engine taking no part in this result (under `表达式显示` = `数学表达式` as-you-type
//          never asks it) those cells are grey **not** because the result cannot be drawn that way, so
//          each one has to state the app-side reason and the old subtitle has to be gone. **`=` does
//          not go through that kill switch** — also measured this round (see the "`数学表达式` 下按 `=`"
//          case), and it decides which sentence the reason line gets. The vendor's strings are quoted
//          above.
void main() {
  const channel = MethodChannel('nekocalc/qalculate');

  // 中文：菜单里那两行"给人看的字"现在住在 `CalculatorStrings` 里（第 0 项的名字与那两条理由），
  //       六项 HiPER 原文仍写在表里。这里按**默认语言**取一次，下面各处只是读同一份结构。
  // English: the two human-facing lines in the menu (entry 0's name and both notes) now live in
  //          `CalculatorStrings`, while the six HiPER strings stay written out in the table. This
  //          takes the **default language's** table once; every assertion below just reads it.
  final cells =
      resultFormatCells(CalculatorStrings.forLanguage(AppLanguage.zh));

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

  group('菜单的形状与来源', () {
    test('七项：第 0 项是本应用自己那一行，其后六项是 HiPER 的原文与顺序', () {
      expect(
        cells.map((cell) => cell.label).toList(),
        <String>[
          '默认',
          'Decimal',
          'Expression',
          'Fraction',
          'Mixed number',
          'Degrees, mins, secs',
          'Polar coordinates',
        ],
        reason: '前六项的六个名字就是 `rfMenu.*` 的原文，顺序就是它们在字符串表里的顺序',
      );
      // 中文：**七项对应六个 `ResultForm`** —— 第 0 项与 `Decimal` 不是同一件事：前者是本应用
      //       自己那一行（精确写法 + `≈` 读数，HiPER 没有这一格），后者是「只要那串十进制读数」。
      expect(cells.first.form, ResultForm.auto);
      expect(cells.first.label, '默认', reason: '它必须在名字上就说清自己不是 HiPER 的菜单项');
      expect(cells.first.note, isNotEmpty,
          reason: '「本应用自己的一行」这句话要写在那一行上，不能只写在代码注释里');
    });

    test('到期日：本应用今天给不出 `Polar coordinates`——那一项没有形态，枚举里也没有这一格', () {
      final polar = cells.last;
      expect(polar.label, 'Polar coordinates');
      // 中文：**这一条就是那一项禁用的到期日。** 今天它成立，因为：
      //       （一）引擎的极坐标是 `EvaluationOptions.complex_number_form`，由
      //       `Calculator-calculate.cc:2195` 在**求值中途**调用 `complexToPolarForm` 变换结构——
      //       它不是 `PrintOptions` 上的开关，用它意味着换一组求值选项再求一次值，而本应用所有
      //       「写法」都建立在「同一个已求值结构的又一次打印」上（`MathResult` 那四个形态字段）；
      //       （二）它印出来的是 `5.656854249(cos(45.00000000) + i × sin(45.00000000))`（宿主
      //       `qalc` 5.12.0 实测，`-set "cplxform polar" "4+4i"`），而 HiPER 那一格是 `r∠45`
      //       （手册 p.11），`∠` 本应用的两个解析器都读不了。
      //       **哪一天本应用有了一个只改写法的极坐标印法，这一条会红**——那时这一项该点亮，
      //       而不是让一条过期的禁用悄悄留着（与 `∠`、`MTRX` 那两格同一个做法）。
      // English: **This is that entry's expiry assertion.** It holds today because the engine's polar
      //          form is an `EvaluationOptions` field that `Calculator-calculate.cc:2195` applies
      //          *during evaluation* (`complexToPolarForm`) — not a `PrintOptions` switch — so using it
      //          would mean evaluating again under different options, while every "spelling" in this app
      //          rests on "one more print of one evaluated structure" (the four form fields of
      //          `MathResult`); and because what it prints is
      //          `5.656854249(cos(45.00000000) + i × sin(45.00000000))` (host `qalc` 5.12.0,
      //          `-set "cplxform polar" "4+4i"`), while HiPER's cell is `r∠45`. **The day this app gains
      //          a polar spelling that changes the writing only, this goes red** — that entry should then
      //          light up rather than an expired refusal quietly staying put.
      expect(polar.form, isNull, reason: '本应用今天没有任何一格可以落到这一项上');
      expect(polar.note, contains('极坐标'), reason: '禁用要在屏幕上说得出理由，不能是一条按下去没反应的行');
      expect(
        ResultForm.values.map((form) => form.name).toList(),
        isNot(contains('polar')),
        reason: '给枚举添一个永远画不出来的值，会让每一处 switch 都多一条走不到的分支',
      );
      // 中文：**六项对六格**（第 0 项与 `Decimal` 共用不了同一格，所以是 7 项对 6 格 + 1 个画不出的）。
      // English: six `ResultForm`s behind seven rows — the extra row is the one this app cannot draw.
      expect(ResultForm.values.length, 6);
      expect(cells.where((c) => c.form != null).length, 6);
    });

    test('其他六项今天都落得到形态上，而且形态互不相同', () {
      final forms = cells
          .where((cell) => cell.form != null)
          .map((cell) => cell.form!)
          .toList();
      expect(forms.toSet().length, forms.length,
          reason: '两项落到同一格就会出现「点哪一项都一样」的两个入口');
      expect(forms.toSet(), <ResultForm>{
        ResultForm.auto,
        ResultForm.decimal,
        ResultForm.exact,
        ResultForm.fraction,
        ResultForm.mixed,
        ResultForm.dms,
      });
    });

    test('`MIXED` 这一盏灯只点在带分数那一格上——它是那四盏里唯一以分数命名的一盏', () {
      expect(ResultForm.mixed.indicator, 'MIXED');
      expect(ResultForm.fraction.indicator, isEmpty,
          reason: '`\\frac{5}{2}` 是假分数，给它挂 MIXED 才是关于画面那句话的假话');
      expect(ResultForm.exact.indicator, 'EXPR');
      expect(ResultForm.dms.indicator, 'DMS');
      expect(ResultForm.decimal.indicator, isEmpty);
      expect(ResultForm.auto.indicator, isEmpty);
    });
  });

  // 中文：**灰着的那几格说不说实话。** 引擎没有参与这一份结果时（边打边算在 `表达式显示` =
  //       `数学表达式` 下根本不问引擎），`10÷4` 的分数写法**存在**——它就是 `5/2`，只是本应用没有
  //       问过。所以那几格灰着时**不许**说成「这一份结果画不出来」，而要说成本应用这边的事。
  // English: **whether those grey cells tell the truth.** While the engine took no part in this result
  //          (under `表达式显示` = `数学表达式` as-you-type never asks it) `10÷4`'s fraction spelling
  //          **exists** — it *is* `5/2`, the app simply never asked. So a grey cell there must **not**
  //          be described as "this result cannot be drawn that way", but as something on the app's side.
  group('灰着的那几格为什么灰（`ResultPresentation.gapFor`）', () {
    test('引擎没参与这一份结果：四格写的是「本应用没有它的写法」，另两格一个字都不说', () {
      // 中文：旧解析器上屏的样子——一个十进制读数，四份引擎写法一份都没有。
      // English: what the legacy parser puts on screen — a decimal reading and not one of the four
      //          engine spellings.
      final p = ResultPresentation.of(
        resultTex: '',
        fractionTex: '',
        resultDecimal: '2.5',
        naturalDisplay: true,
        engineTookPart: false,
      );

      for (final form in <ResultForm>[
        ResultForm.exact,
        ResultForm.fraction,
        ResultForm.mixed,
        ResultForm.dms,
      ]) {
        expect(p.canDraw(form), isFalse);
        expect(p.gapFor(form), ResultCellGap.engineNotAsked,
            reason: '$form 灰着的原因是「本应用还没拿到引擎的写法」，不是「这一份结果画不出来」');
      }
      // 中文：`默认` 恒存在；`Decimal` 那一格画的是那串读数本身，与引擎在不在无关。
      // English: `默认` always exists; the `Decimal` cell draws that reading itself and does not care
      //          whether the engine is there.
      expect(p.gapFor(ResultForm.auto), ResultCellGap.none);
      expect(p.gapFor(ResultForm.decimal), ResultCellGap.none);
    });

    test('引擎答了而这一格仍然没有：一个理由都不编', () {
      final p = ResultPresentation.of(
        resultTex: r'\num{0.3333333333333333}',
        fractionTex: r'\frac{1}{3}',
        resultDecimal: '0.3333333333333333',
        naturalDisplay: true,
        mixedTex: r'\frac{1}{3}',
      );

      expect(p.canDraw(ResultForm.exact), isFalse);
      expect(p.gapFor(ResultForm.exact), ResultCellGap.none,
          reason: '`\\num{…}` 排不出来是这一格自己的门槛，与引擎有没有参与无关——不许说成「没问过引擎」');
      expect(p.canDraw(ResultForm.mixed), isFalse);
      expect(p.gapFor(ResultForm.mixed), ResultCellGap.none,
          reason: '带分数与分数逐字符相同——这一份结果本来就没有这一格，标题那句在这里是真话');
    });

    test('`表达式显示` = `数学表达式`：原因是那个设置，而且它排在「引擎没参与」之前', () {
      // 中文：**这一份结果上四份写法全都在**——按 `=` 提交时引擎答了（提交路径**不看** kill
      //       switch），只是 `naturalDisplay` 为假、`_accepted` 一道都不收。所以这里的正确说法是
      //       「本应用今天印不出这一格」，不是「本应用没有它的写法」。
      // English: **all four spellings are on this result** — the `=` submit asked the engine (the
      //          submit path does **not** look at the kill switch); `naturalDisplay` is false, so
      //          `_accepted` takes none of them. The right sentence here is therefore "this app cannot
      //          print that cell today", not "this app does not have its spelling".
      final p = ResultPresentation.of(
        resultTex: '2.5',
        fractionTex: r'\frac{5}{2}',
        resultDecimal: '2.5',
        naturalDisplay: false,
        mixedTex: r'2 + \frac{1}{2}',
        dmsText: '2°30′0″',
        degreesMode: true,
        engineTookPart: true,
      );

      for (final form in <ResultForm>[
        ResultForm.exact,
        ResultForm.fraction,
        ResultForm.mixed,
        ResultForm.dms,
      ]) {
        expect(p.canDraw(form), isFalse, reason: '自然排版关掉时整行纯文本，一种写法都不排');
        expect(p.gapFor(form), ResultCellGap.typesettingOff);
      }
    });
  });

  group('带分数那一格（`Mixed number`）', () {
    test('`10/4`：引擎的 `FRACTION_COMBINED` 印法收得下，而且与分数那一格不同', () {
      final p = ResultPresentation.of(
        resultTex: '2.5',
        fractionTex: r'\frac{5}{2}',
        resultDecimal: '2.5',
        naturalDisplay: true,
        mixedTex: r'2 + \frac{1}{2}',
      );

      expect(p.mixedTex, r'2 + \frac{1}{2}',
          reason: '宿主 qalc 5.12.0 实测：`-set "fr mixed" "10/4"` → `2 + 1/2`');
      expect(p.hasMixed, isTrue);
      expect(p.canDraw(ResultForm.mixed), isTrue);
      expect(p.resolve(ResultForm.mixed), ResultForm.mixed);
      expect(p.texFor(ResultForm.mixed), r'2 + \frac{1}{2}');
      expect(p.texFor(ResultForm.fraction), r'\frac{5}{2}',
          reason: '两格画的是两个不同的东西：假分数与带分数');
      expect(MathExpressionView.typesetsTex(p.mixedTex), isTrue,
          reason: '排不出来就不该收——`_accepted` 的门槛');
    });

    test('`1/3`：带分数与分数逐字符相同，所以不多占一格', () {
      final p = ResultPresentation.of(
        resultTex: r'\num{0.3333333333333333}',
        fractionTex: r'\frac{1}{3}',
        resultDecimal: '0.3333333333333333',
        naturalDisplay: true,
        mixedTex: r'\frac{1}{3}',
      );

      expect(p.fractionTex, r'\frac{1}{3}');
      expect(p.mixedTex, isEmpty, reason: '同一个数的同一种写法不该占两格——`1/3` 没有整数部分');
      expect(p.canDraw(ResultForm.mixed), isFalse);
      expect(p.resolve(ResultForm.mixed), ResultForm.auto,
          reason: '这一份结果没有这一格，请求它只能回落——fail-closed 没有被放宽');
    });

    test('`12345.6789`：`FRACTION_COMBINED` 印出来带 `\\num{…}`，排不出来，整格不要', () {
      final p = ResultPresentation.of(
        resultTex: r'\num{12345.6789}',
        fractionTex: r'\frac{\num{123456789}}{\num{10000}}',
        resultDecimal: '12345.6789',
        naturalDisplay: true,
        mixedTex:
            r'\num[parse-numbers=true]{12345} + \frac{6789}{\num[parse-numbers=true]{10000}}',
      );

      expect(p.mixedTex, isEmpty,
          reason: '`\\num{…}` 排不出来——与分数那一格同一条 fail-closed');
      expect(p.canDraw(ResultForm.mixed), isFalse);
    });

    test('自然排版关掉时一格都收不下——带分数也走同一套门槛', () {
      final p = ResultPresentation.of(
        resultTex: '2.5',
        fractionTex: r'\frac{5}{2}',
        resultDecimal: '2.5',
        naturalDisplay: false,
        mixedTex: r'2 + \frac{1}{2}',
      );

      expect(p.mixedTex, isEmpty);
      expect(p.fractionTex, isEmpty);
      expect(p.cycle, isEmpty);
    });
  });

  group('端到端：菜单', () {
    testWidgets('不按 `x⇔E` 时屏幕上没有面板——默认态与从前逐字符相同', (tester) async {
      reply(<String, String>{
        'decimal': '2.5',
        'latex': '2.5',
        'fraction': r'\frac{5}{2}',
        'mixed': r'2 + \frac{1}{2}',
        'kind': 'number',
      });

      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '0', '÷', '4']);
      await tester.pumpAndSettle();

      expect(find.byType(ResultFormatSheet), findsNothing);
      expect(_display(tester).resultForm, ResultForm.auto,
          reason: '初始态恒为 auto，与接菜单之前一致');
      expect(
        find.descendant(
          of: find.byType(CalculatorDisplay),
          matching: find.text('2.5'),
        ),
        findsOneWidget,
        reason: '默认那一行就是那串十进制读数（精确印法 `2.5` 与它相同，被合并掉了）',
      );
      expect(find.text('EXPR'), findsNothing);
      expect(find.text('MIXED'), findsNothing);
      expect(find.text('DMS'), findsNothing);
    });

    testWidgets('切遍五种写法：`decimalText` 与数值一个字节都不动', (tester) async {
      reply(<String, String>{
        'decimal': '2.5',
        'latex': '2.5',
        'fraction': r'\frac{5}{2}',
        'mixed': r'2 + \frac{1}{2}',
        'kind': 'number',
      });

      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '0', '÷', '4']);
      await tester.pumpAndSettle();

      // 中文：**切形态只改显示**这条不变式的可执行形式。每换一种写法，都当场读一遍十进制形态与
      //       它解析出的数，两样都必须与切换之前逐字节相同——`Ans`/`last`、记忆寄存器、继续使用
      //       与历史读的就是这一个字段。
      // English: the executable form of "switching form changes the display only". After every
      //          spelling change both the decimal form and the number it parses to are read back and
      //          must be byte-identical to before — that field is what `Ans`/`last`, the memory
      //          register, continue-with and history read.
      expect(_display(tester).resultDecimal, '2.5');
      expect(MathResult.decimalValueOf(_display(tester).resultDecimal), 2.5);

      // 中文：**这一份结果有哪几格**：`2.5` 的精确印法就是那串十进制（被合并掉），所以「Expression」
      //       这一项对它不存在——下面**只点存在的那些**，另外单独断言 `Expression` 是灰的。
      // English: **which cells this result has**: `2.5`'s exact print *is* that decimal (merged away),
      //          so the `Expression` entry does not exist for it — the loop below picks only the ones
      //          that do, and `Expression` being grey is asserted separately.
      await _tapKey(tester, 'x⇔E');
      expect(_menuTile(tester, 'Expression').enabled, isFalse,
          reason: '精确印法与读数逐字符相同 → 没有这一格，菜单里那一项于是点不动');
      await _pickInMenu(tester, 'Fraction');

      for (final label in <String>[
        'Mixed number',
        'Decimal',
        'Fraction',
        '默认',
      ]) {
        await _tapKey(tester, 'x⇔E');
        await _pickInMenu(tester, label);

        expect(_display(tester).resultDecimal, '2.5',
            reason: '选了「$label」之后十进制形态动了');
        expect(MathResult.decimalValueOf(_display(tester).resultDecimal), 2.5,
            reason: '选了「$label」之后数值动了');
        expect(_display(tester).result, '2.5', reason: '选了「$label」之后结果行的读数动了');
      }
    });

    testWidgets('面板里选一项，与按 `d/c` / `D°M\'S` 落到同一个状态——两个入口，一个状态',
        (tester) async {
      reply(<String, String>{
        'decimal': '2.5',
        'latex': '2.5',
        'fraction': r'\frac{5}{2}',
        'mixed': r'2 + \frac{1}{2}',
        // 中文：度分秒那一串是**近似结构**上的印法（`2.5` 在 DEG 下就是 2°30′），与上面的十进制
        //       逐位相等——它只在 DEG 下存在，所以这个文件的角度模式是 DEG。
        // English: the DMS string is the **approximated** structure's print (`2.5` under DEG is
        //          2°30′), digit for digit equal to the decimal above. It exists only under DEG, which
        //          is why this file's angle mode is DEG.
        'dms': "2°30′0″",
        'kind': 'number',
      });

      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '0', '÷', '4']);
      await tester.pumpAndSettle();

      // 中文：**`d/c` 走一趟**：分数写法。
      await _tapKey(tester, 'd/c');
      expect(tester.widget<MathExpressionView>(_typesetResult()).tex,
          r'\frac{5}{2}');
      expect(_display(tester).resultForm, ResultForm.fraction);
      // 中文：**再按一次回到默认**——那一颗键是老实的开关，`x⇔E` 换成菜单没有动它。
      await _tapKey(tester, 'd/c');
      expect(_display(tester).resultForm, ResultForm.auto);

      // 中文：**菜单里选同一格**，落到**同一个** `ResultForm`：两个入口、一个状态，而且动作的
      //       id 仍然只有一套（`fractionForm` 只在键位表上出现一次，见逐格快照与
      //       「键的 id 全局唯一」那两条测试）。
      // English: **the same cell picked from the menu** lands on **the same** `ResultForm`: two
      //          entrances, one state, and the action still has exactly one id (`fractionForm` appears
      //          once in the key table — see the cell-by-cell snapshot and the "key ids are globally
      //          unique" test).
      await _tapKey(tester, 'x⇔E');
      await _pickInMenu(tester, 'Fraction');
      expect(_display(tester).resultForm, ResultForm.fraction);
      expect(tester.widget<MathExpressionView>(_typesetResult()).tex,
          r'\frac{5}{2}');

      // 中文：**`D°M'S` 仍然工作**：DEG 之下一份度分秒写法，按一下换过去、再按一下回来。
      // English: **`D°M'S` still works**: one DMS spelling under DEG, toggled over and back.
      await _tapKey(tester, "D°M'S");
      expect(_display(tester).resultForm, ResultForm.dms);
      expect(tester.widget<MathExpressionView>(_typesetResult()).tex,
          r"2^\circ\,30'\,0''");
      expect(find.text('DMS'), findsOneWidget);
      expect(_display(tester).resultDecimal, '2.5');
      await _tapKey(tester, "D°M'S");
      expect(_display(tester).resultForm, ResultForm.auto);
    });

    testWidgets('`数学表达式` 之下那四格灰着，而且每一格自己写明了「本应用今天印不出这一格」', (tester) async {
      reply(<String, String>{
        'decimal': '2.5',
        'latex': '2.5',
        'fraction': r'\frac{5}{2}',
        'mixed': r'2 + \frac{1}{2}',
        'dms': "2°30′0″",
        'kind': 'number',
      });

      await tester.pumpWidget(_page(expressionDisplay: '数学表达式'));
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '0', '÷', '4']);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // 中文：**边打边算在这个设置下不问引擎**（kill switch），所以结果上一个引擎写法都没有。
      // English: **as-you-type does not ask the engine under this setting** (the kill switch), so the
      //          result carries none of the engine's spellings.
      expect(_display(tester).resultFractionTex, isEmpty);

      await _tapKey(tester, 'x⇔E');

      // 中文：**从前那句假话必须走了。** 它把「本应用没有问过引擎」说成了「这一份结果画不出来」
      //       ——`10÷4` 就是 `5/2`。
      // English: **the old false sentence has to be gone.** It turned "this app never asked the
      //          engine" into "this result cannot be drawn that way" — and `10÷4` *is* `5/2`.
      expect(find.text('结果行的写法。灰掉的那一项是这一份结果画不出来的'), findsNothing,
          reason: '引擎没参与时这句话是假的：这一份结果画得出 5/2，只是本应用没有问过');
      expect(
        find.text('结果行的写法。灰掉的项按不下去：不是这一份结果没有这一格，就是本应用今天印不出这一格'),
        findsOneWidget,
      );

      for (final label in <String>[
        'Expression',
        'Fraction',
        'Mixed number',
        'Degrees, mins, secs',
      ]) {
        final tile = _menuTile(tester, label);
        expect(tile.enabled, isFalse);
        // 中文：**先断言那一行小字在**——「灰得一句话都没有」正是从前那个缺陷，这一条红了就是它。
        // English: **assert the small line is there first** — "grey without a word" is the defect this
        //          round fixes, and this assertion going red is exactly that.
        expect(tile.subtitle, isNotNull,
            reason: '$label 灰着时必须写出理由，不能像从前那样一声不吭');
        final note = (tile.subtitle! as Text).data!;
        expect(note, contains('印不出'), reason: '$label 那一行要说的是本应用印不出这一格');
        expect(note, contains('表达式显示'), reason: '$label 那一行要点出是哪个设置把写法关掉的');
        expect(note, contains('数学表达式'), reason: '$label：那一句要指名道姓');
      }

      // 中文：**亮着的两格一句话都不多说**——理由只属于灰着的那几格。
      // English: **the two live cells say nothing extra** — reasons belong to the grey ones only.
      expect(_menuTile(tester, '默认').enabled, isTrue);
      expect(_menuTile(tester, 'Decimal').enabled, isTrue);
      expect(_menuTile(tester, 'Decimal').subtitle, isNull);
    });

    testWidgets('`数学表达式` 下按 `=`：引擎答了、写法就在结果上，那几格照旧灰着且不赖引擎', (tester) async {
      reply(<String, String>{
        'decimal': '2.5',
        'latex': '2.5',
        'fraction': r'\frac{5}{2}',
        'mixed': r'2 + \frac{1}{2}',
        'dms': "2°30′0″",
        'kind': 'number',
      });

      await tester.pumpWidget(_page(expressionDisplay: '数学表达式'));
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '0', '÷', '4']);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await _tapKey(tester, '✓');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // 中文：**`=` 那条路不看 kill switch。** 这一点是本轮量出来的：同一份设置、同一个表达式，
      //       按 `=` 之后结果上四份引擎写法**都在**（`fractionTex` 就是 `\frac{5}{2}`）。所以那几格
      //       灰着的原因**不是**「引擎没参与」，而是这个设置让结果行一格写法都不排——理由那一行
      //       必须说对，否则就是把一句假话换成了另一句。
      // English: **the `=` path does not look at the kill switch.** Measured this round: same setting,
      //          same expression, and after `=` all four engine spellings **are** on the result
      //          (`fractionTex` *is* `\frac{5}{2}`). So those grey cells are grey because this setting
      //          makes the result line typeset nothing — **not** because "the engine took no part". The
      //          reason line has to get that right, or one false sentence has merely been swapped for
      //          another.
      expect(_display(tester).resultFractionTex, r'\frac{5}{2}');
      expect(_display(tester).resultMixedTex, r'2 + \frac{1}{2}');

      await _tapKey(tester, 'x⇔E');
      final fraction = _menuTile(tester, 'Fraction');
      expect(fraction.enabled, isFalse, reason: '写法就在结果上，屏幕上照样不排它——灰的是本应用这一侧');
      expect(fraction.subtitle, isNotNull, reason: '这一格灰着，它自己那一行要写明为什么');
      final note = (fraction.subtitle! as Text).data!;
      expect(note, contains('表达式显示'));
      expect(note, isNot(contains('不是引擎算的')),
          reason: '引擎这一次**算过了**：不许把这一格灰着的原因推给它');
      // 中文：**值路径一个字节没动**——绕这一圈只改了屏幕上说不说得清，没碰过任何数。
      // English: **the value path has not moved a byte** — this whole round is about what the screen
      //          says, and it touched no number.
      expect(_display(tester).resultDecimal, '2.5');
    });

    testWidgets('灰掉的那一项（`Polar coordinates`）按下去什么都不做：不关面板、不改状态',
        (tester) async {
      reply(<String, String>{
        'decimal': '2.5',
        'latex': '2.5',
        'fraction': r'\frac{5}{2}',
        'mixed': r'2 + \frac{1}{2}',
        'kind': 'number',
      });

      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      await _typeKeys(tester, <String>['1', '0', '÷', '4']);
      await tester.pumpAndSettle();

      await _tapKey(tester, 'x⇔E');
      expect(_menuTile(tester, 'Polar coordinates').enabled, isFalse);
      // 中文：`ListTile` 的 `onTap` 为 null 时整行不响应，`tester.tap` 会打不中——这正是「看得见的
      //       拒绝」在控件层面的样子。这里量的是它的后果：面板还在，形态没动。
      // English: with `ListTile.onTap` null the whole row is inert, so `tester.tap` cannot land on it —
      //          that is what "a visible refusal" looks like at the widget level. What is measured here
      //          is the consequence: the sheet is still there and the form has not moved.
      await tester.tap(
        find.descendant(
          of: find.byType(ResultFormatSheet),
          matching: find.text('Polar coordinates'),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResultFormatSheet), findsOneWidget);
      expect(_display(tester).resultForm, ResultForm.auto);
      expect(find.text('POLAR'), findsNothing);
    });
  });
}

ListTile _menuTile(WidgetTester tester, String label) =>
    tester.widget<ListTile>(
      find.ancestor(
        of: find.descendant(
          of: find.byType(ResultFormatSheet),
          matching: find.text(label),
        ),
        matching: find.byType(ListTile),
      ),
    );

Future<void> _pickInMenu(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(ResultFormatSheet),
    matching: find.text(label),
  ));
  await tester.pumpAndSettle();
  expect(find.byType(ResultFormatSheet), findsNothing, reason: '选完一项面板该关掉');
}

Finder _typesetResult() => find.byWidgetPredicate(
      (widget) => widget is MathExpressionView && widget.tex.isNotEmpty,
    );

CalculatorDisplay _display(WidgetTester tester) =>
    tester.widget<CalculatorDisplay>(find.byType(CalculatorDisplay));

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

/// 中文：主屏，`表达式显示` 可换——**它同时是 kill switch**（`kEngineBackedLiveExpressionDisplay`：
///       `数学符号` 才让边打边算问引擎）。默认值与既有那些用例逐字符相同。
/// English: the screen, with `表达式显示` switchable — **it is also the kill switch**
///          (`kEngineBackedLiveExpressionDisplay`: only `数学符号` lets as-you-type ask the engine).
///          The default is character-for-character what the existing cases used.
Widget _page({String expressionDisplay = '数学符号'}) => MaterialApp(
      home: Scaffold(
        body: CalculatorPage(
          db: _FakeDatabase(),
          onOpenSettings: () {},
          settings: AppSettings(
            haptics: false,
            hapticStrength: '标准',
            restoreState: false,
            autoSaveHistory: false,
            angleMode: 'DEG',
            precision: 6,
            themeModeLabel: '跟随系统',
            expressionDisplayMode: expressionDisplay,
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
