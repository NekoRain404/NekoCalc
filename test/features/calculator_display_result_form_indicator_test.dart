import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/result_form.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

/// 中文：**状态行上那一盏结果形式灯**（HiPER 的 `EXPR` / `DMS`）。
///
///       它是**显示**：只把已经画出来的那一格念出名字，不产生值、不进结果行、不进控制器。
///       这里要证的是四件事：
///
///       1. **它点在该点的格子上**——精确形态点 `EXPR`、度分秒形态点 `DMS`；
///       2. **它绝不点在不该点的格子上**——默认形态、分数形态、十进制形态一个灯都不点；
///          「`EXPR` 点在一个纯数字上」是这里最要紧的一条（那是 brief 点名的谎）；
///       3. **它跟着 `resolve` 之后的那一格走**——请求了一个这一份结果没有的形态时，
///          灯**不点**（不是点上一个猜的名字，也不是留着上一份结果的灯）；
///       4. **它在状态行上，不在结果行上**——结果行画的一个字符都没变。
///
///       判据不在这里：`ResultForm.indicator`（`result_form.dart`）一处收口，字面与理由都在那里。
/// English: **the result-form lamp on the status row** (HiPER's `EXPR` / `DMS`).
///
///          It is a **display**: it only speaks the name of a cell already drawn, produces no value,
///          enters neither the result line nor the controller. Four things are proved here: (1) it
///          lights on the cells it should — the exact form lights `EXPR`, the DMS form `DMS`; (2) it
///          never lights on the ones it should not — the default, fraction and decimal forms light
///          nothing at all, and "`EXPR` over a plain number" above all, the lie the brief names;
///          (3) it follows the **resolved** cell — requesting a form this result does not have lights
///          **nothing** (not a guessed name, and not the previous result's lamp left burning); and
///          (4) it sits on the status row rather than the result line — not one character of the
///          result line moves.
///
///          The judgement is not here: `ResultForm.indicator` (`result_form.dart`) is the one place,
///          and the words and their reasons live there.
void main() {
  testWidgets('精确形态：状态行点 EXPR', (tester) async {
    await tester.pumpWidget(_host(
      result: '2.828427',
      resultTex: r'2\times \sqrt{2}',
      resultDecimal: '2.828427124746190',
      resultForm: ResultForm.exact,
    ));
    await tester.pumpAndSettle();

    expect(find.text('EXPR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('度分秒形态（DEG）：状态行点 DMS', (tester) async {
    await tester.pumpWidget(_host(
      result: '12.5822',
      resultTex: r'\num{12.5822}',
      resultDecimal: '12.5822',
      resultDmsText: '12°34′55.92″',
      resultForm: ResultForm.dms,
    ));
    await tester.pumpAndSettle();

    expect(find.text('DMS'), findsOneWidget);
    expect(find.text('EXPR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认形态：一格都不点——即使这一份结果有排得出来的精确写法', (tester) async {
    // 中文：**这是「灯跟着格式走、不跟着结果的种类走」最直接的一条。** 同一份 `\sqrt{8}` 的结果，
    //       默认形态画的是「精确写法 + `≈` 读数」，HiPER 五种格式里没有一种是它，所以不点灯；
    //       按一下 `x⇔E` 走到精确形态才点 `EXPR`（上一条）。
    // English: **the most direct proof that the lamp follows the format, not the result's kind.** For
    //          this same `\sqrt{8}` result the default form draws "exact spelling + `≈` reading",
    //          which is none of HiPER's five formats, so nothing lights; one `x⇔E` press reaches the
    //          exact form and `EXPR` lights (the case above).
    await tester.pumpWidget(_host(
      result: '2.828427',
      resultTex: r'2\times \sqrt{2}',
      resultDecimal: '2.828427124746190',
    ));
    await tester.pumpAndSettle();

    expect(find.text('EXPR'), findsNothing, reason: '默认形态不是 HiPER 的 expression 格式');
    expect(find.text('DMS'), findsNothing);
  });

  testWidgets('纯数字的结果：无论请求哪一格都不点 EXPR', (tester) async {
    // 中文：brief 点名的谎——「`EXPR` 点在一个数字上」。这里连**请求**了精确形态都不点：
    //       这一份结果没有那一格，`resolve` 把它落回默认，灯跟着不点（fail-closed）。
    // English: the lie the brief names — "`EXPR` over a number". Not even **requesting** the exact
    //          form lights it: this result has no such cell, `resolve` lands it back on the default,
    //          and the lamp follows (fail-closed).
    for (final form in <ResultForm>[ResultForm.auto, ResultForm.exact]) {
      await tester.pumpWidget(_host(
        result: '4',
        resultDecimal: '4',
        resultForm: form,
      ));
      await tester.pumpAndSettle();

      expect(find.text('EXPR'), findsNothing, reason: '请求的是 $form，而这是一份纯数字结果');
    }
  });

  testWidgets('分数形态不点灯——HiPER 唯一以分数命名的灯是 MIXED，那是带分数', (tester) async {
    // 中文：本应用印的是**假分数**（`10/4` 印成 `\frac{5}{2}`，实测记在 `QalculateOptions.kt:158`），
    //       把 `\frac{5}{2}` 标成 `MIXED` 是一句关于画面上那个东西的假话，所以沉默。
    // English: this app prints an **improper** fraction (`10/4` prints `\frac{5}{2}`, measured in
    //          `QalculateOptions.kt:158`); labelling `\frac{5}{2}` `MIXED` would be a false sentence
    //          about what is on the screen, so it stays silent.
    await tester.pumpWidget(_host(
      result: '2.5',
      resultFractionTex: r'\frac{5}{2}',
      resultDecimal: '2.5',
      resultForm: ResultForm.fraction,
    ));
    await tester.pumpAndSettle();

    expect(find.text('MIXED'), findsNothing);
    expect(find.text('EXPR'), findsNothing);
  });

  testWidgets('十进制形态不点灯——HiPER 那一格本来就没有灯', (tester) async {
    await tester.pumpWidget(_host(
      result: '2.828427',
      resultTex: r'2\times \sqrt{2}',
      resultDecimal: '2.828427124746190',
      resultForm: ResultForm.decimal,
    ));
    await tester.pumpAndSettle();

    expect(find.text('EXPR'), findsNothing, reason: '四盏灯对五种格式，decimal 那一格没有灯');
    expect(find.text('DMS'), findsNothing);
  });

  testWidgets('灯跟着 resolve 后的那一格走：RAD 下请求度分秒形态，不点灯', (tester) async {
    // 中文：引擎那一串照样送上来，但 `°` 在 RAD 下是一句假话（见 `ResultPresentation`），那一格
    //       因此不存在。状态行**不能**照着「引擎给过一串」点灯——那正是「拿种类当形式」的错。
    // English: the engine's string still arrives, but under RAD the `°` in it is a false statement
    //          (see `ResultPresentation`), so the cell does not exist. The status row **must not**
    //          light it just because the engine handed a string over — that is precisely the
    //          "mistaking the kind for the form" error.
    await tester.pumpWidget(_host(
      result: '12.5822',
      resultTex: r'\num{12.5822}',
      resultDecimal: '12.5822',
      resultDmsText: '12°34′55.92″',
      resultForm: ResultForm.dms,
      angleMode: 'RAD',
    ));
    await tester.pumpAndSettle();

    expect(find.text('DMS'), findsNothing, reason: 'RAD 下那一格不存在，灯跟着不点');
  });

  testWidgets('灯在状态行上（与 DEG 同一个 Row），结果行上一个字符都没多', (tester) async {
    await tester.pumpWidget(_host(
      result: '2.828427',
      resultTex: r'2\times \sqrt{2}',
      resultDecimal: '2.828427124746190',
      resultForm: ResultForm.exact,
    ));
    await tester.pumpAndSettle();

    // 中文：角度 chip 在状态行上，这一点是既有的；灯与它同一个 `Row`，所以灯也在状态行上。
    // English: the angle chip is on the status row, which is established; the lamp shares its `Row`,
    //          so the lamp is on the status row too.
    final statusRow =
        find.ancestor(of: find.text('DEG'), matching: find.byType(Row)).first;
    expect(find.descendant(of: statusRow, matching: find.text('EXPR')),
        findsOneWidget);

    // 中文：结果行（`=` 那一个 `Row`）上只有 `=` 与那一段排版，没有 `EXPR`。
    // English: the result line (the `Row` holding `=`) carries only the `=` and the typeset stretch —
    //          no `EXPR`.
    final resultRow =
        find.ancestor(of: find.text('='), matching: find.byType(Row)).first;
    expect(find.descendant(of: resultRow, matching: find.text('EXPR')),
        findsNothing);
  });

  testWidgets('与角度 chip、记忆徽标、进制读数同时在场：320dp 下不溢出', (tester) async {
    await tester.pumpWidget(_host(
      result: '2.828427',
      resultTex: r'2\times \sqrt{2}',
      resultDecimal: '2.828427124746190',
      resultForm: ResultForm.exact,
      hasMemory: true,
      baseReadout: 'HEX FFF88A3290D55F4F4741D86B1EA28020A3FD1B2',
      onMore: () {},
      onOpenDrawer: () {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('DEG'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('EXPR'), findsOneWidget);
    expect(find.textContaining('HEX FFF88A'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '状态行溢出');
    // 中文：放不下时它走的是**进制读数那一条既有契约**——`Text` 里仍是完整的 `EXPR`，截断发生在
    //       画的时候，并且开了省略号。实测：不给它 `Flexible` 时这一组合报
    //       `A RenderFlex overflowed by 30 pixels on the right.`
    // English: when it does not fit it uses **the base read-out's existing contract** — the `Text`
    //          still holds the whole `EXPR`, the cut happens at paint time and the ellipsis is on.
    //          Measured: without the `Flexible` this very combination reports
    //          `A RenderFlex overflowed by 30 pixels on the right.`
    final label = tester.widget<Text>(find.text('EXPR'));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
  });
}

Widget _host({
  required String result,
  required String resultDecimal,
  String resultTex = '',
  String resultFractionTex = '',
  String resultDmsText = '',
  ResultForm resultForm = ResultForm.auto,
  String angleMode = 'DEG',
  bool hasMemory = false,
  String baseReadout = '',
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
            expression: '10/4',
            result: result,
            resultTex: resultTex,
            resultFractionTex: resultFractionTex,
            resultDmsText: resultDmsText,
            resultForm: resultForm,
            resultDecimal: resultDecimal,
            hasError: false,
            statusTitle: '结果可继续使用',
            statusMessage: '继续使用会把结果写回表达式。',
            cursorIndex: 4,
            angleMode: angleMode,
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
