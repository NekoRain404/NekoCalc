import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/ast/tex_emitter.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

// 中文：**键盘上那一颗 `D°M'S` 是输入键。** 一路按 `3` `D°M'S` `3` `0` `D°M'S` `0` `D°M'S` 得到
//       `3°30′0″`，值 3.5（DEG）。厂商原文、它与「把结果转成度分秒」为什么是两颗键、结果那一半
//       现在住在 `x⇔E` 菜单里，都写在 `hiper_keypad_band_key_rows.dart` 那一格上；文法与每一处
//       取值决定在 `lib/core/math/sexagesimal_literal.dart`。
//
//       **这一组钉三件事**：
//       1. **按出来的字符串**（每一步的中间态都断言，因为边打边算会把它们显示给用户）；
//       2. **值**：DEG 下 3.5、RAD 下 0.0610865…——而**两个模式下引擎一次都不被问**
//          （`°` 归一化写成内部名字 `degangle`，翻译器先拒了它）；
//       3. **表达式行排得出来**：整段是一个度分秒字面量节点，TeX 是 `3^\circ\,30'\,0''`，
//          不是降级成 `\text{…}` 的原文块——这正是上一轮「不照搬输入那一半」的第一条理由。
//
// English: **the keypad's `D°M'S` is an entry key.** Pressing `3` `D°M'S` `3` `0` `D°M'S` `0` `D°M'S`
//          gives `3°30′0″`, value 3.5 (DEG). The vendor lines, why it and "convert the result into
//          degrees, minutes and seconds" are two keys, and where the result half lives now (the `x⇔E`
//          menu) are all on that cell in `hiper_keypad_band_key_rows.dart`; the grammar and every value
//          decision are in `lib/core/math/sexagesimal_literal.dart`.
//
//          **Three things are pinned here**:
//          1. **the string the presses build** (every intermediate state is asserted, because
//             as-you-type evaluation shows them to the user);
//          2. **the value**: 3.5 under DEG and 0.0610865… under RAD — and **the engine is asked not
//             once in either mode** (`°` normalises to the internal name `degangle`, which the
//             translator refuses up front);
//          3. **the expression line typesets it**: the whole stretch is one DMS literal node whose TeX
//             is `3^\circ\,30'\,0''`, not a `\text{…}` blob — which is exactly the first reason last
//             round recorded for not copying the entry half.
void main() {
  const channel = MethodChannel('nekocalc/qalculate');

  /// 中文：**记下引擎被问过的每一句表达式。** 期望的不是「一次都没问」——边打边算在
  ///       `数学符号` 下会问引擎，而按到一半的 `3` 是翻译得过去的，所以那一步问过一次是正常的。
  ///       期望的是**含 `°` 的那些状态一次都没被送出去**：`degangle` 没有引擎写法，翻译器在名字层
  ///       之前就拒了它（理由与端到端实测在 `calculator_engine_name_layer_test.dart`）。
  ///       下面那个假的回执（`7`）是配套的探针：万一真有 `°` 的表达式被送出去而屏幕上出现了 7，
  ///       「屏幕上是 3.5」那条断言就会红。
  /// English: **every expression the engine was asked about is recorded.** What is expected is not
  ///          "it was never asked" — as-you-type evaluation does ask the engine under `数学符号`, and a
  ///          half-typed `3` translates fine, so one call at that step is normal. What is expected is
  ///          that **no state holding `°` is ever sent**: `degangle` has no engine spelling and the
  ///          translator refuses it ahead of the name layer (the reasoning and the end-to-end
  ///          measurement are in `calculator_engine_name_layer_test.dart`). The fake receipt (`7`) is
  ///          the probe that goes with it: were a `°` expression really sent and that 7 reached the
  ///          screen, the "3.5 on screen" assertion below would go red.
  final askedExpressions = <String>[];

  setUp(() {
    askedExpressions.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'evaluate') return null;
      final arguments = call.arguments;
      if (arguments is Map) {
        askedExpressions.add('${arguments['expression']}');
      }
      // 中文：回执**故意**给一个与 3.5 无关的数（`7`）：只要引擎被问了、而这个数出现在屏幕上，
      //       下面那条「屏幕上是 3.5」就会红——「引擎一次都没被问」因此是量出来的，不是假定的。
      // English: the receipt is **deliberately** a number unrelated to 3.5 (`7`): if the engine were
      //          asked and that number reached the screen, the "3.5 on screen" assertion below would
      //          go red — so "the engine was never asked" is measured rather than assumed.
      return <String, String>{
        'ok': 'true',
        'aborted': 'false',
        'messages': '',
        'angleMode': 'DEG',
        'decimal': '7',
        'latex': '7',
        'kind': 'number',
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('一路按出 `3°30′0″`：每一步的中间态都读得通，最后是 3.5，引擎一次未被问',
      (tester) async {
    await tester.pumpWidget(_page(angleMode: 'DEG'));
    await tester.pumpAndSettle();

    await _tapKey(tester, '3');
    await _tapKey(tester, "D°M'S");
    expect(_expression(tester), '3°');
    expect(_result(tester), '3',
        reason: '按到一半的 `3°` 就是 3 度——中间态不许是一个错值');

    await _tapKey(tester, '3');
    await _tapKey(tester, '0');
    expect(_expression(tester), '3°30');
    expect(_result(tester), '3.5',
        reason: '`3°30` 读作 3 度 30 分（键盘按出来的中间态，理由在 sexagesimal_literal.dart）');

    await _tapKey(tester, "D°M'S");
    expect(_expression(tester), '3°30′');
    await _tapKey(tester, '0');
    expect(_expression(tester), '3°30′0');
    expect(_result(tester), '3.5');

    await _tapKey(tester, "D°M'S");
    expect(_expression(tester), '3°30′0″');
    expect(_result(tester), '3.5',
        reason: '手册那个例子：`3 D°M′S 30 D°M′S 0 D°M′S` → 3.5');

    // 中文：**引擎一次都没被问。** `degangle` 是应用自己的名字，翻译器在名字层之前就拒了它，
    //       所以这条路上不存在「引擎给另一个数」的可能——上面那个假的回执（7）就是探针。
    // English: **the engine was never asked.** `degangle` is this app's own name and the translator
    //          refuses it ahead of the name layer, so nothing on this road can come from the engine —
    //          the fake receipt above (`7`) is the probe.
    expect(_askedDegangle(askedExpressions), isEmpty,
        reason: '含 `°` 的表达式一次都不送去让引擎猜');
  });

  testWidgets('同一串按键在 RAD 下：表达式的写法不变，读数是那个角度的弧度值', (tester) async {
    await tester.pumpWidget(_page(angleMode: 'RAD'));
    await tester.pumpAndSettle();

    await _tapKey(tester, '3');
    await _tapKey(tester, "D°M'S");
    await _tapKey(tester, '3');
    await _tapKey(tester, '0');
    await _tapKey(tester, "D°M'S");
    await _tapKey(tester, '0');
    await _tapKey(tester, "D°M'S");

    expect(_expression(tester), '3°30′0″');
    expect(double.parse(_result(tester)),
        closeTo(0.061086523819801536, 1e-6),
        reason: '角度数值写在当前角度单位下：RAD 下 `3°30′0″` 是它的弧度值（与 `30°` 同一条规则）');
    expect(_askedDegangle(askedExpressions), isEmpty);
  });

  testWidgets('表达式行把它排成公式：`3^\\circ\\,30\'\\,0\'\'`，不是一段 `\\text{…}` 原文',
      (tester) async {
    await tester.pumpWidget(_page(angleMode: 'DEG'));
    await tester.pumpAndSettle();

    await _tapKey(tester, '3');
    await _tapKey(tester, "D°M'S");
    await _tapKey(tester, '3');
    await _tapKey(tester, '0');
    await _tapKey(tester, "D°M'S");
    await _tapKey(tester, '0');
    await _tapKey(tester, "D°M'S");

    // 中文：表达式行渲染的就是「解析 + 逐单元转 TeX」这两步（`MathExpressionView`），所以这里
    //       用的是同一把尺：整段是**一个**度分秒字面量节点，TeX 是 `3^\circ\,30'\,0''`。
    //       本轮之前它是一整段 `\text{3°30′0″}`——`°` 让整个表达式降级成字面文本。
    // English: the expression line renders exactly "parse, then emit TeX per unit"
    //          (`MathExpressionView`), so the same instrument is used here: the whole stretch is
    //          **one** DMS literal node and the TeX is `3^\circ\,30'\,0''`. Before this round it was
    //          one `\text{3°30′0″}` blob — `°` degraded the entire expression to literal text.
    final units = toDisplayUnits(const ExpressionAstParser().parse(_expression(tester)));
    expect(units.length, 1, reason: '整段是一个显示单元（一个字面量），不是一个错误节点');
    expect(units.single, isA<SexagesimalNode>());
    final tex = const TexEmitter().emit(units.single);
    expect(tex, r"3^\circ\,30'\,0''");
    expect(MathExpressionView.typesetsTex(tex), isTrue,
        reason: '这一段真的排得出来（不是降级成原文）');
    expect(tex, isNot(contains(r'\text')));
  });

  testWidgets('空操作：左边没有数字、或三段都齐了，按下去一个字符都不写', (tester) async {
    await tester.pumpWidget(_page(angleMode: 'DEG'));
    await tester.pumpAndSettle();

    // 中文：空表达式上按一下：什么都不发生（分隔符要分隔的是一个「段」，左边没有段）。
    await _tapKey(tester, "D°M'S");
    expect(_expression(tester), '');
    expect(_result(tester), '0');

    // 中文：`2+` 之后同理（光标左边不是数字）。
    await _tapKey(tester, '2');
    await _tapKey(tester, '+');
    await _tapKey(tester, "D°M'S");
    expect(_expression(tester), '2+');

    // 中文：三段齐全之后再按：没有第四个分隔符。先 `AC`，从一个空表达式开始按。
    await _tapKey(tester, 'AC');
    for (final key in <String>['3', "D°M'S", '3', '0', "D°M'S", '0', "D°M'S"]) {
      await _tapKey(tester, key);
    }
    expect(_expression(tester), '3°30′0″');
    await _tapKey(tester, "D°M'S");
    expect(_expression(tester), '3°30′0″',
        reason: '三个记号都齐了：字面量只有三段，没有第四个分隔符');
  });
}

/// 中文：被送去问引擎的那些表达式里，含 `°`/`degangle` 的那些——**期望它一个都没有**。
/// English: the expressions sent to the engine that hold `°`/`degangle` — **expected to be none**.
List<String> _askedDegangle(List<String> asked) => asked
    .where((expression) =>
        expression.contains('degangle') || expression.contains('°'))
    .toList();

/// 中文：表达式行那段原文——与 `calculator_logxy_angle_key_test.dart` 等用的是同一把尺。
/// English: the expression line's source — the same instrument the other key tests use.
String _expression(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).expression;

/// 中文：结果行此刻那串纯文本读数。
/// English: the plain reading the result line is showing right now.
String _result(WidgetTester tester) =>
    tester.widget<CalculatorDisplay>(find.byType(CalculatorDisplay)).result;

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.descendant(
    of: find.byType(CalculatorKeypad),
    matching: find.text(key, findRichText: true),
  ));
  await tester.pumpAndSettle();
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
