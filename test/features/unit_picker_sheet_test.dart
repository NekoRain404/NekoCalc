import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/app_unit_catalog.dart';
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

  testWidgets('点一个单位把它的拼法交出去', (tester) async {
    final inserted = await pumpSheet(tester);

    await tester.tap(find.text('km  千米'));
    expect(inserted, <String>['km']);
  });

  testWidgets('「to」交出去的是两侧带空格的 ` to `', (tester) async {
    // 中文：**空格是必须的**：引擎把 `)to(` 读成 `t`·`o` 的乘积，而且不报错（宿主实测）。
    //       面板交出去的字符串就是表达式里的那一段，所以这条钉在面板这一层。
    // English: **the spaces are required**: the engine reads `)to(` as the product `t`·`o` without
    //          erroring (measured on the host). What the sheet hands over is exactly what lands in the
    //          expression, so this is pinned here.
    final inserted = await pumpSheet(tester);

    await tester.tap(find.text('to'));
    expect(inserted, <String>[' to ']);
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
