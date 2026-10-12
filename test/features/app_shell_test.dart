import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/models/note_item.dart';
import 'package:nekocalc/domain/entities/tool_category.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/unit_picker_sheet.dart';
import 'package:nekocalc/features/graph/presentation/graph_page.dart';
import 'package:nekocalc/features/notes/presentation/notes_page.dart';
import 'package:nekocalc/features/tools/presentation/tool_category_screen.dart';
import 'package:nekocalc/features/tools/presentation/tool_widgets.dart';
import 'package:nekocalc/features/tools/presentation/tools_home_page.dart';
import 'package:nekocalc/shared/presentation/app_shell.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

const AppSettings _radSettings = AppSettings(
  haptics: false,
  hapticStrength: '标准',
  restoreState: false,
  autoSaveHistory: false,
  angleMode: 'RAD',
  precision: 6,
  themeModeLabel: '跟随系统',
  expressionDisplayMode: '数学符号',
);

/// 中文：只把角度单位换成角度制的一份设置——用来量"设置里的角度单位到不到得了图形页"。
/// English: the same settings with only the angle unit changed to degrees — used to measure whether
///          the angle unit in settings reaches the graph page.
const AppSettings _degSettings = AppSettings(
  haptics: false,
  hapticStrength: '标准',
  restoreState: false,
  autoSaveHistory: false,
  angleMode: 'DEG',
  precision: 6,
  themeModeLabel: '跟随系统',
  expressionDisplayMode: '数学符号',
);

Widget _app({ThemeMode? themeMode, AppSettings settings = _radSettings}) =>
    MaterialApp(
      // 中文：`themeMode` 用来区分「应用自己的明暗」与「平台亮度」——`app.dart` 正是用 `themeMode`
      //       把设置里的浅色/深色/跟随系统落到 `MaterialApp` 上的。
      // English: `themeMode` separates the app's own light/dark from the platform's brightness — it is
      //          what `app.dart` uses to apply the 浅色/深色/跟随系统 setting to `MaterialApp`.
      theme: ThemeData.light(),
      darkTheme: themeMode == null ? null : ThemeData.dark(),
      themeMode: themeMode ?? ThemeMode.system,
      home: AppShell(
        db: _FakeDatabase(),
        settings: settings,
        onSettingsChanged: () async {},
        onThemeModeChanged: (_) {},
      ),
    );

void main() {
  testWidgets('主屏没有底部导航栏', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('点 ☰ 后抽屉出现且含五个入口', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    // 中文：四页都必须有入口——键盘区不响应翻页，抽屉漏掉哪一页，那一页就是死路。
    // English: All four pages need an entry — the keypad refuses page swipes, so any page the drawer
    //          omits becomes a dead end.
    expect(find.text('计算'), findsWidgets);
    expect(find.text('工具'), findsWidgets);
    expect(find.text('图形'), findsWidgets);
    expect(find.text('笔记'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('点抽屉里的「笔记」后笔记页可见', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();
    // 中文：与相邻几条一致——用页面类型断言，「笔记」两个字抽屉里也有，靠文案证明不了切页。
    // English: consistent with its siblings — assert the page type; 「笔记」 also appears in the drawer,
    //          so a text finder proves nothing about which page is showing.
    expect(find.byType(NotesPage), findsOneWidget);
    expect(find.byType(NotesPage).hitTestable(), findsOneWidget);
  });

  testWidgets('计算页上只有一个 ☰', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    // 中文：计算页自己的 ☰ + 外壳给其它页浮的那个，同时出现就是两个按钮；这里钉住只有一个。
    // English: the calculator's own ☰ plus the one the shell floats over the other pages would be two
    //          buttons at once — this pins the single one.
    expect(find.byTooltip('打开导航'), findsOneWidget);
  });

  // 中文：抽屉与计算页共用同一套明暗判定（`CalcTheme.of`）：明暗要跟着**应用自己的**主题模式走，
  //       而不是平台亮度——用户选了浅色、手机却是深色模式时两者相反，按平台取色会让抽屉与主屏独自
  //       变黑，与其余页面分家。
  // English: The drawer and the calculator page share one light/dark decision (`CalcTheme.of`): it has
  //          to follow the **app's own** theme mode rather than the platform's brightness — with 浅色
  //          chosen on a dark-mode phone the two disagree, and resolving from the platform turns the
  //          drawer and the main screen black on their own, apart from every other page.
  testWidgets('应用选浅色、平台是深色时抽屉用浅色主题', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(_app(themeMode: ThemeMode.light));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Drawer>(find.byType(Drawer)).backgroundColor,
      CalcTheme.roseCream.keypadBackground,
      reason: '应用处于浅色模式，抽屉必须取浅色主题，即使平台报的是深色',
    );
    expect(tester.widget<Drawer>(find.byType(Drawer)).backgroundColor,
        isNot(CalcTheme.roseCream.dark.keypadBackground));
  });

  testWidgets('点抽屉里的「工具」后工具页可见', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工具').last);
    await tester.pumpAndSettle();
    expect(find.byType(ToolsHomePage), findsOneWidget);
    expect(find.byType(ToolsHomePage).hitTestable(), findsOneWidget);
  });

  testWidgets('点抽屉里的「图形」后图形页可见', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图形').last);
    await tester.pumpAndSettle();
    expect(find.byType(GraphPage), findsOneWidget);
    expect(find.byType(GraphPage).hitTestable(), findsOneWidget);
  });

  // 中文：**设置里的角度单位必须走到图形页的求值里。** 只看"页面上有个 `angleMode` 参数"是循环
  //       论证；这里量的是屏幕上读得出来的那个数：同一批默认函数（`sin(x)` 与一条抛物线）按下
  //       「零点」，弧度制给 5 个（sin 的 0、±π 加抛物线两个），角度制给 3 个（sin 只剩 x = 0）。
  //       `sin(x)` 是两种单位下都画得出来的曲线，差别只在解出来的零点上。
  // English: **the angle unit in settings has to reach the graph page's evaluation.** Checking that the
  //          page widget carries an `angleMode` argument would be circular; what is measured here is a
  //          number readable off the screen: press 零点 on the same default functions (`sin(x)` plus a
  //          parabola) and radians give 5 zeros (sin's 0, ±π and the parabola's two) while degrees give
  //          3 (sin keeps only x = 0). `sin(x)` plots under both units; only the solved zeros differ.
  testWidgets('设置里的角度制真的到达图形页：零点按度解', (tester) async {
    await tester.pumpWidget(_app(settings: _degSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图形').last);
    await tester.pumpAndSettle();
    expect(find.byType(GraphPage).hitTestable(), findsOneWidget);

    final graphList = find.descendant(
        of: find.byType(GraphPage), matching: find.byType(ListView));
    await tester.drag(graphList, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('零点'));
    await tester.pumpAndSettle();

    expect(find.textContaining('找到 3 个零点'), findsOneWidget,
        reason: '角度制下 sin(x) 在 [-6, 6] 里只剩 x = 0 一个零点');
    expect(find.textContaining('3.141593'), findsNothing,
        reason: 'π 是弧度制下的零点，设置选了角度制就不该出现');
  });

  // 中文：底部栏消失后最容易出的事故——走进「工具」再回不到计算页，App 就废了。这条测试只允许用
  //       屏幕上看得见、点得着的东西回程（☰），不借助拖拽手势：设备上那条拖拽会被系统返回手势抢走。
  // English: The accident the missing bottom bar invites — walk into 工具 and never get back to the
  //          calculator — bricks the app. This test may only use what is visible and tappable on screen
  //          (the ☰), not the drag gesture, which the system back gesture steals on a real device.
  testWidgets('离开计算页后靠屏上的 ☰ 能回到计算页', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工具').last);
    await tester.pumpAndSettle();
    expect(find.byType(ToolsHomePage).hitTestable(), findsOneWidget);

    // 中文：非计算页上，外壳浮出的 ☰ 必须是唯一可见的打开抽屉入口。
    // English: away from the calculator, the shell's floating ☰ must be the one visible way in.
    expect(find.byTooltip('打开导航').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('计算').last);
    await tester.pumpAndSettle();
    expect(find.byType(CalculatorPage), findsOneWidget);
    expect(find.byType(CalculatorPage).hitTestable(), findsOneWidget);
    expect(find.text('CNST'), findsOneWidget);
  });

  // 中文：外壳浮出的 ☰ 曾经压在笔记页多选态的「取消选择」上（Material 的 48dp 命中区越界所致），
  //       点「取消选择」反而打开了抽屉。这条测试按用户看到的行为断言：点了就要真的取消选择。
  // English: the shell's floating ☰ used to sit on top of the notes page's multi-select 「取消选择」
  //          (Material's 48dp tap target reaching out of bounds), so tapping 取消选择 opened the drawer
  //          instead. This asserts the user-visible behaviour: tapping it really cancels the selection.
  testWidgets('笔记页多选态的「取消选择」真的取消选择（没被外壳的 ☰ 抢走）', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();

    // 长按一条历史记录进入多选态。
    await tester.longPress(find.text('1+1'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 项'), findsOneWidget);

    await tester.tap(find.byTooltip('取消选择'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 项'), findsNothing, reason: '「取消选择」必须真的取消选择');
    expect(find.byType(Drawer), findsNothing, reason: '「取消选择」不该打开抽屉');
  });

  testWidgets('图形页与笔记页上也有 ☰ 可以回到计算页', (tester) async {
    for (final label in const ['图形', '笔记']) {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('打开导航'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();

      expect(find.byTooltip('打开导航').hitTestable(), findsOneWidget,
          reason: '$label 页上没有可见的 ☰');
      await tester.tap(find.byTooltip('打开导航'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('计算').last);
      await tester.pumpAndSettle();
      expect(find.byType(CalculatorPage).hitTestable(), findsOneWidget,
          reason: '从 $label 页回不到计算页');
    }
  });

  // 中文：Task 4 给计算页留了 `onNavigate`，外壳不接的话 HISTORY / CNST / CONV 与四个进制胶囊
  //       在真实 App 里永远是死的；这组测试守住这条接线。
  // English: Task 4 left `onNavigate` on the calculator page; unless the shell wires it, HISTORY /
  //          CNST / CONV and the four base pills stay dead in the real app. These tests guard it.
  group('计算页的页面级导航接线', () {
    testWidgets('onNavigate 收到 tools 切到工具页', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final page = tester.widget<CalculatorPage>(find.byType(CalculatorPage));
      expect(page.onNavigate, isNotNull, reason: '外壳必须接上 onNavigate');
      page.onNavigate!('tools');
      await tester.pumpAndSettle();
      expect(find.byType(ToolsHomePage), findsOneWidget);
      expect(find.byType(ToolsHomePage).hitTestable(), findsOneWidget);
    });

    testWidgets('onNavigate 收到 history 切到笔记页', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final page = tester.widget<CalculatorPage>(find.byType(CalculatorPage));
      expect(page.onNavigate, isNotNull, reason: '外壳必须接上 onNavigate');
      page.onNavigate!('history');
      await tester.pumpAndSettle();
      expect(find.byType(NotesPage), findsOneWidget);
      expect(find.byType(NotesPage).hitTestable(), findsOneWidget);
    });

    testWidgets('点 CNST 键把主屏切到工具页', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('CNST'), findsOneWidget);
      await tester.tap(find.text('CNST'));
      await tester.pumpAndSettle();
      expect(find.byType(ToolsHomePage), findsOneWidget);
    });

    testWidgets('点 HISTORY 键把主屏切到笔记页', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('HISTORY'), findsOneWidget);
      await tester.tap(find.text('HISTORY'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesPage), findsOneWidget);
    });
  });

  // 中文：**`unit_convert` 那张卡必须落在键盘 `CONV` 打开的那一张面板上——同一张，不是第二份
  //       实现。** 这张卡本身没有工具页：外壳把它接住（`AppShell._openUnitSheet`），先收掉工具
  //       那一路推出来的路由、切回计算页，再走计算页自己的 `_openUnitSheet()`——与 `CONV` 键
  //       走的是同一个方法。这条测试从工具首页一路点到卡片，量的是"到的是那张面板，插进去的单位
  //       真的进了表达式"。
  // English: **the `unit_convert` card must land on the very sheet the keypad's `CONV` opens — the same
  //          one, not a second implementation.** The card has no tool page of its own: the shell catches
  //          it (`AppShell._openUnitSheet`), pops the routes the tools path pushed, switches back to the
  //          calculator page and calls that page's own `_openUnitSheet()` — the same method the `CONV`
  //          key calls. This test walks from the tools home to the card and measures "the sheet it lands
  //          on, and that a tapped unit really reaches the expression".
  group('单位换算那张卡打开 CONV 面板', () {
    testWidgets('从工具首页 → 单位换算分类 → 卡片，落到同一张面板，插进去的单位进了表达式',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('打开导航'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('工具').last);
      await tester.pumpAndSettle();
      expect(find.byType(ToolsHomePage).hitTestable(), findsOneWidget);

      // 中文：首页那张分类卡按 `category` 认，不按文字认——「单位换算」这四个字在首页上不止一处
      //       （分类卡与"建议工具"里那张 featured 的卡同名）；分类网格在首屏之下，先滚到看得见。
      // English: the category card on the home is found by `category`, not by text — 「单位换算」 occurs
      //          more than once there (the category card and the featured tool card in the suggested
      //          strip share the name); the categories grid sits below the first screen, so it is
      //          scrolled into view first.
      final unitsCategory = find.byWidgetPredicate(
          (widget) => widget is CategoryCard && widget.category == ToolCategory.units);
      await tester.ensureVisible(unitsCategory);
      await tester.pumpAndSettle();
      await tester.tap(unitsCategory);
      await tester.pumpAndSettle();
      expect(find.byType(ToolCategoryScreen), findsOneWidget);

      // 中文：分类页上那张卡片按 `tool.id` 认，理由同上（页头与卡片同名）。
      // English: the card on the category page is found by `tool.id`, for the same reason (the page head
      //          and the card share the name).
      final unitCard = find.byWidgetPredicate(
          (widget) => widget is ToolListTile && widget.tool.id == 'unit_convert');
      await tester.ensureVisible(unitCard);
      await tester.pumpAndSettle();
      await tester.tap(unitCard);
      await tester.pumpAndSettle();

      expect(find.byType(UnitPickerSheet), findsOneWidget,
          reason: '这张卡必须打开 `CONV` 那张面板（同一个 `UnitPickerSheet`）');
      expect(find.byType(ToolCategoryScreen), findsNothing,
          reason: '工具那一路的路由要被收掉，面板是浮在计算页上的');
      expect(find.text('CONV'), findsOneWidget,
          reason: '面板底下应当是计算页的键盘');

      await tester.tap(find.text('km  千米'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<MathExpressionView>(
                find.byType(MathExpressionView).first)
            .expression,
        'km',
        reason: '面板里点出来的单位要真的进计算页的表达式',
      );
      expect(find.byType(CalculatorPage).hitTestable(), findsOneWidget,
          reason: '关掉面板后停在计算页');
    });
  });
}

class _FakeDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  // 中文：工具页首帧会读它自己的收藏与最近使用，导航测试必须让这一步有个空结果，
  //       否则切到工具页时会在 `initState` 里抛 NoSuchMethodError。
  // English: The toolbox page reads its favourites and recents on first frame; the navigation tests
  //          need those to answer empty, otherwise switching to it throws from `initState`.
  @override
  Future<Set<String>> favoriteToolIds() async => const {};

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async => const [];

  // 中文：分类页点任意一张卡都会先记一条"最近使用"（`_openTool` 里那行 `markRecent`），
  //       `unit_convert` 那张卡也不例外——它虽然不开工具页，但这行统计照记。这里答空即可；
  //       不答的话 `noSuchMethod` 会同步抛出，把点击本身打断（当初正是这么红的）。
  // English: tapping any card on a category page records a "recently used" entry first (the
  //          `markRecent` line in `_openTool`), and the `unit_convert` card is no exception — it
  //          records it even though it opens no tool page. Answering with nothing is enough; without
  //          this the `noSuchMethod` fallback throws synchronously and breaks the tap itself (which is
  //          exactly how this went red).
  @override
  Future<void> markRecent(String toolId) async {}

  // 中文：笔记页的整轮刷新是一个 try——`notes` / `history` / `noteTags` 有一个抛异常，页面就只剩
  //       错误面板，连一条可长按的记录都没有。所以这三条都要答得出来，历史里给一条记录。
  // English: the notes page refreshes in one try — if any of `notes` / `history` / `noteTags` throws,
  //          the page shows only an error panel and there is no row left to long-press. All three must
  //          answer, with one history record to select.
  @override
  Future<List<HistoryItem>> history({
    int limit = 50,
    int offset = 0,
    String? query,
    String? toolId,
  }) async =>
      [HistoryItem(
          id: 1,
          expression: '1+1',
          result: '2',
          resultKind: HistoryResultKind.number,
          createdAt: DateTime(2026, 9, 17, 9, 30))];

  @override
  Future<List<NoteItem>> notes({
    int limit = 200,
    int offset = 0,
    String? query,
    String? tag,
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
    NoteSort sort = NoteSort.updatedNewest,
  }) async =>
      const [];

  @override
  Future<List<String>> noteTags({
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
