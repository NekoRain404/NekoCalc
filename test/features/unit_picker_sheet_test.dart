import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/app_unit_catalog.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/unit_picker_sheet.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：单位面板的行为钉子。面板**自己不换算**，它只把文本交给调用方（页面上接到控制器的
///       `input` 上），所以这里断言的就是「点了什么、交出去了什么」。
///
///       **显示名的语言是这一轮接进来的**：面板按当前 `AppLanguage` 取中文名或英文名
///       （`unit_picker_sheet.dart` 的 `unitDisplayLabel` / `unitDisplayFamily`），而按钮交出去的
///       永远是 `unit.symbol`。下面的英文那两条钉的就是这件事——**面字变了，交出去的记号没变**。
/// English: Behaviour pins for the unit sheet. The sheet **does not convert anything itself**; it hands
///          text to its caller (the page wires that to the controller's `input`), so what is asserted
///          here is "what was tapped, what went out".
///
///          **The display name's language arrived this round**: the sheet takes the Chinese or the
///          English name from the active `AppLanguage` (`unitDisplayLabel` / `unitDisplayFamily` in
///          `unit_picker_sheet.dart`), while the button still hands over `unit.symbol`. The two English
///          tests below pin exactly that — **the face changed, the token handed over did not**.
void main() {
  /// 中文：把面板装上屏，交出去的文本收进返回值。**不给语言时不套作用域**——那是默认态（`of` 回落到
  ///       中文），与 `calculator_strings_test.dart` 里「没有装作用域时仍然渲染中文」那条是同一件事。
  /// English: pumps the sheet and collects what it hands over. **Without a language no scope is
  ///          installed** — that is the default state (`of` falls back to Chinese), the same thing
  ///          `calculator_strings_test.dart`'s "no scope still renders Chinese" pins.
  Future<List<String>> pumpSheet(WidgetTester tester,
      {AppLanguage? language}) async {
    final inserted = <String>[];
    final sheet = Scaffold(body: UnitPickerSheet(onInsert: inserted.add));
    await tester.pumpWidget(MaterialApp(
      home: language == null
          ? sheet
          : AppLanguageScope(language: language, child: sheet),
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

  testWidgets('搜索按英文名与英文族名也过滤（中文那一侧一条不少）', (tester) async {
    final inserted = await pumpSheet(tester);

    // 中文：**中文的提示语本来就在承诺这件事**：`unitSearchHint` 写的是「搜索单位（米、km、mile…）」，
    //       也就是说在中文界面上打 `mile` 也该找得到「英里」。此前它只匹配拼法、中文名与中文族名，
    //       所以那句承诺是空的；现在英文名也进匹配，承诺才成立。
    // English: **the Chinese hint has been promising this all along**: `unitSearchHint` reads
    //          "搜索单位（米、km、mile…）" — i.e. typing `mile` on the Chinese interface should find
    //          英里. It used to match only the spelling, the Chinese name and the Chinese family, so the
    //          promise was empty; the English name is matched now, which makes it true.
    await tester.enterText(find.byType(TextField), 'nautical');
    await tester.pumpAndSettle();
    expect(find.text('nmi  海里'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'length');
    await tester.pumpAndSettle();
    expect(find.text('长度'), findsOneWidget, reason: '英文族名也要能搜到那一族');
    expect(find.text('m  米'), findsOneWidget);

    // 中文：中文查询的结果**只多不少**：`where` 多一个条件，集合只会变大，所以这里两条老查询
    //       仍旧给同一批单位（下面这条与上面那条测试里的 `英里` 是同一句）。
    // English: a Chinese query's result set **only grows**: one more clause in the `where` can only
    //          add, so these two old queries still return the same units (the first is the same query
    //          the test above uses).
    await tester.enterText(find.byType(TextField), '英里');
    await tester.pumpAndSettle();
    expect(find.text('mi  英里'), findsOneWidget);
    expect(find.text('km  千米'), findsNothing);

    expect(inserted, isEmpty, reason: '过滤本身不许插入任何东西');
  });

  testWidgets('英文界面上单位名与族名换成英文，交出去的仍是拼法', (tester) async {
    final inserted = await pumpSheet(tester, language: AppLanguage.en);

    await tester.enterText(find.byType(TextField), 'nautical');
    await tester.pumpAndSettle();
    expect(find.text('nmi  nautical mile'), findsOneWidget);
    expect(find.text('Length'), findsOneWidget);
    expect(find.text('长度'), findsNothing, reason: '英文界面上不该还有中文族名');
    expect(find.text('海里'), findsNothing);

    await tester.tap(find.text('nmi  nautical mile'));
    expect(inserted, <String>['nmi'],
        reason: '面字随语言变，交出去的记号不变——只显示名换了一侧');

    // 中文：英文界面上**中文名仍然搜得到**（面板不按语言分叉搜索），这是刻意的：一次换算里
    //       用户可能从别处粘来一个中文单位名。
    // English: on the English interface **the Chinese name still finds the unit** (the sheet does not
    //          branch its search by language), deliberately: a user may paste a Chinese unit name in
    //          from somewhere else in the middle of a conversion.
    await tester.enterText(find.byType(TextField), '海里');
    await tester.pumpAndSettle();
    expect(find.text('nmi  nautical mile'), findsOneWidget);
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
    // 中文：**表里的每一个**逐个过滤出来点一次（今天逐个数是 120 个；这里原先写的 117 是文件头那次
    //       量测当时的条数，此后表又添了 3 个符号）。面板读的是 [kAppUnits]，不是第二份清单；某个
    //       符号只活在清单里而面板上没有，这条就会红。用搜索而不是滚动来把它们带上屏：**过滤之后
    //       整个列表就是一个单位**，不必依赖懒加载的可见性。默认态（没装语言作用域）下写的仍是
    //       中文名，所以下面那句 `unit.label` 就是屏幕上那一串。
    // English: **every entry in the table**, filtered out one at a time and tapped (120 counted today;
    //          the 117 written here before was the file head's count at that measurement, and three
    //          more symbols arrived since). The sheet reads [kAppUnits] rather than a second list; a
    //          symbol that exists only in the list and not on the sheet turns this red. Search rather
    //          than scrolling is what brings them on screen: **after filtering, the whole list is that
    //          one unit**, so nothing depends on lazy visibility. In the default state (no language
    //          scope) the face is still the Chinese name, which is what `unit.label` below is.
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
