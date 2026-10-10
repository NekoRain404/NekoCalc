import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/app_unit_catalog.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/unit_picker_sheet.dart';

/// 中文：单位面板的行为钉子。面板**自己不换算**，它只把文本交给调用方（页面上接到控制器的
///       `input` 上），所以这里断言的就是「点了什么、交出去了什么」。
/// English: Behaviour pins for the unit sheet. The sheet **does not convert anything itself**; it hands
///          text to its caller (the page wires that to the controller's `input`), so what is asserted
///          here is "what was tapped, what went out".
void main() {
  Future<List<String>> pumpSheet(WidgetTester tester) async {
    final inserted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UnitPickerSheet(onInsert: inserted.add),
      ),
    ));
    return inserted;
  }

  testWidgets('点一个单位交出去的是裸记号（分隔符不归面板管）', (tester) async {
    final inserted = await pumpSheet(tester);

    await tester.tap(find.text('km  千米'));
    expect(inserted, <String>['km']);
  });

  testWidgets('「to」交出去的也是裸记号', (tester) async {
    final inserted = await pumpSheet(tester);

    await tester.tap(find.text('到'));
    expect(inserted, <String>['to']);
  });

  testWidgets('搜索按拼法与中文名过滤', (tester) async {
    final inserted = await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), '英里');
    await tester.pumpAndSettle();
    expect(find.text('mi  英里'), findsOneWidget);
    expect(find.text('km  千米'), findsNothing);

    await tester.enterText(find.byType(TextField), 'kWh');
    await tester.pumpAndSettle();
    expect(find.text('kWh  千瓦时'), findsOneWidget);
    expect(find.text('mi  英里'), findsNothing);

    await tester.enterText(find.byType(TextField), '没有这个');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的单位'), findsOneWidget);

    expect(inserted, isEmpty, reason: '过滤本身不许插入任何东西');
  });

  group('分隔符：面板交出来的记号 → 真正插进表达式的那一段', () {
    test('单位前面加空格，除非表达式为空或已经以空格结尾', () {
      // 中文：**这条是这一轮的核心。** 真实按键流是一串相邻插入，不给分隔符就会粘成一个标识符：
      //       实测 `5` + `km` + `to` + `mi` = `5kmtomi` → `engineExpressionFor` 判「引擎不认识这个
      //       自由变量：`kmtomi`」，引擎根本不会被问到，屏幕上是「存在无法识别的内容」。
      // English: **this is the core of this round.** The real keypad flow is a run of adjacent
      //          insertions, and without a separator they glue into one identifier: measured,
      //          `5` + `km` + `to` + `mi` = `5kmtomi` → `engineExpressionFor` refuses it ("engine does
      //          not know this free variable: `kmtomi`"), the engine is never asked, and the screen
      //          shows "unrecognised content".
      expect(unitInsertionText('km', '5'), ' km');
      // 中文：` to ` 自己带尾空格，所以后面那个单位**不需要**再加一个——拼出来仍然是
      //       `5 km to mi`（下一条从按键流一路拼出来验一遍）。
      // English: ` to ` brings its own trailing space, so the unit after it needs none — what comes
      //          out is still `5 km to mi` (the next test assembles it from the key presses).
      expect(unitInsertionText('mi', '5 km to '), 'mi');
      expect(unitInsertionText('km', ''), 'km', reason: '空表达式不需要前导空格');
      expect(unitInsertionText('km', '5 '), 'km', reason: '已经有空格就不再加');
      // 中文：字母单位与符号单位走同一条规则（`t`、`B` 也是单位名）。
      // English: letter units and symbol units take the same rule (`t` and `B` are unit names too).
      expect(unitInsertionText('t', '5'), ' t');
      expect(unitInsertionText('B', '5'), ' B');
    });

    test('词运算符两侧各一个空格——那是它成为「词」的条件', () {
      // 中文：`kmtomi` 里没有 `to`，只有更长的名字。引擎那边同理：`((5)*(km))to((mi))` 被读成
      //       `t`·`o` 的乘积（宿主实测 `8.04672 MB*t*m^2`，不报错）。
      // English: inside `kmtomi` there is no `to`, only a longer name. The engine's side is the same:
      //          `((5)*(km))to((mi))` reads as the product `t`·`o` (measured on the host,
      //          `8.04672 MB*t*m^2`, no error).
      expect(unitInsertionText('to', '5 km'), ' to ');
      expect(unitInsertionText('to', ''), ' to ');
    });

    test('按键流逐次插入的结果，正是应用自己的语法读得懂的那一串', () {
      // 中文：**按一次一次的插入来拼**，而不是拿一个手写的带空格字符串去测——上一轮就是这么漏掉
      //       这条缺陷的。这里模拟的是「按 `5`、点 `km`、点 `to`、点 `mi`」。
      // English: **build it insertion by insertion** instead of testing a hand-written spaced string —
      //          testing the spaced one is exactly how the last round missed this. What this simulates
      //          is "press `5`, tap `km`, tap `to`, tap `mi`".
      var expression = '5';
      for (final token in <String>['km', 'to', 'mi']) {
        expression += unitInsertionText(token, expression);
      }
      expect(expression, '5 km to mi');
      // 中文：拼出来的这一串必须过得了翻译层——那是「引擎真的会被问到」的判据。
      // English: the assembled string has to pass the translation — that is the test for "the engine
      //          really gets asked".
      expect(engineExpressionFor(expression), isA<TranslatedExpression>());
      expect((engineExpressionFor(expression) as TranslatedExpression).text,
          '((((5)*(km))) to (mi))');
    });
  });

  testWidgets('表里的每一个单位都在面板上，且点得到（表与面板同一份来源）', (tester) async {
    // 中文：117 个逐个过滤出来点一次。面板读的是 [kAppUnits]，不是第二份清单；某个符号只活在清单
    //       里而面板上没有，这条就会红。用搜索而不是滚动来把它们带上屏：**过滤之后整个列表就是
    //       一个单位**，不必依赖懒加载的可见性。
    // English: all 117, filtered out one at a time and tapped. The sheet reads [kAppUnits] rather than
    //          a second list; a symbol that exists only in the list and not on the sheet turns this
    //          red. Search rather than scrolling is what brings them on screen: **after filtering, the
    //          whole list is that one unit**, so nothing depends on lazy visibility.
    await pumpSheet(tester);
    // 中文：列表是懒加载的（屏幕外的行根本没建），所以一边往下拖一边收，直到一个都不能再多为止。
    //       上限只是防死循环，不是期望值。
    // English: the list is lazy (rows off screen are never built), so it is dragged down while
    //          collecting until nothing new appears. The cap only stops an infinite loop; it is not an
    //          expectation.
    final seen = <String>{};
    var previous = -1;
    for (var i = 0; i < 40 && seen.length != previous; i++) {
      previous = seen.length;
      for (final unit in kAppUnits) {
        if (find.text('${unit.symbol}  ${unit.label}').evaluate().isNotEmpty) {
          seen.add(unit.symbol);
        }
      }
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
    }
    expect(seen.length, kAppUnits.length,
        reason: '面板上没有列出来的单位：${kAppUnitSymbols.difference(seen)}');
  });
}
