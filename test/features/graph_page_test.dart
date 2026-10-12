import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/graph/models/graph_strings.dart';
import 'package:nekocalc/features/graph/presentation/graph_page.dart';

void main() {
  final zh = GraphStrings.graphZh;
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('delayed graph workspace does not overwrite local viewport edits',
      (tester) async {
    final settingsCompleter = Completer<Map<String, String>>();
    final db = _FakeGraphDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GraphPage(
          db: db,
          restoreState: true,
        ),
      ),
    ));
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放大'));
    await tester.pump(const Duration(milliseconds: 320));

    settingsCompleter.complete({
      graphWorkspaceSettingKey: encodeGraphWorkspace(
        functions: defaultGraphFunctions(),
        viewport: const GraphViewport(
          centerX: 0,
          centerY: 0,
          spanX: 40,
          spanY: 40,
        ),
      ),
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    final savedWorkspace = decodeGraphWorkspace(
      db.savedSettings[graphWorkspaceSettingKey],
      strings: zh,
    );
    expect(savedWorkspace, isNotNull);
    expect(savedWorkspace!.viewport.spanX, closeTo(9, 1e-9));
    expect(savedWorkspace.viewport.spanY, closeTo(9, 1e-9));
    expect(find.text('已恢复上次图形工作区'), findsNothing);
  });

  testWidgets('graph paste restores copied graph data and persists workspace',
      (tester) async {
    const sourceFunction = GraphFunction(
      expression: '2x + 1',
      label: 'y = 2x + 1',
      color: Color(0xFF1677FF),
      visible: false,
    );
    final copiedText = buildGraphCopyText(
      functions: const [sourceFunction],
      viewport: const GraphViewport(centerX: 1, centerY: 2, spanX: 6, spanY: 8),
      markers: const [],
      strings: zh,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return Future.value({'text': copiedText});
      }
      return null;
    });
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeGraphDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GraphPage(
          db: db,
          restoreState: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('粘贴图形数据'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.textContaining('已从图形数据恢复工作区'), findsWidgets);
    final savedWorkspace = decodeGraphWorkspace(
      db.savedSettings[graphWorkspaceSettingKey],
      strings: zh,
    );
    expect(savedWorkspace, isNotNull);
    expect(savedWorkspace!.functions, hasLength(1));
    expect(savedWorkspace.functions.single.expression, '2x + 1');
    expect(savedWorkspace.functions.single.visible, isFalse);
    expect(savedWorkspace.viewport.centerX, 1);
    expect(savedWorkspace.viewport.centerY, 2);
    expect(savedWorkspace.viewport.spanX, 6);
    expect(savedWorkspace.viewport.spanY, 8);
  });

  testWidgets('graph paste creates workspace from plain function text',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return Future.value({
          'text': '''
y = x^2 - 1
sin(x)
表达式: 2x + 1
''',
        });
      }
      return null;
    });
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeGraphDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GraphPage(
          db: db,
          restoreState: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('粘贴图形数据'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.textContaining('已从函数文本创建工作区'), findsWidgets);
    final savedWorkspace = decodeGraphWorkspace(
      db.savedSettings[graphWorkspaceSettingKey],
      strings: zh,
    );
    expect(savedWorkspace, isNotNull);
    expect(savedWorkspace!.functions.map((item) => item.expression), [
      'x^2 - 1',
      'sin(x)',
      '2x + 1',
    ]);
    expect(savedWorkspace.viewport.centerX, defaultGraphViewport.centerX);
    expect(savedWorkspace.viewport.centerY, defaultGraphViewport.centerY);
    expect(savedWorkspace.viewport.spanX, defaultGraphViewport.spanX);
    expect(savedWorkspace.viewport.spanY, defaultGraphViewport.spanY);
  });

  // 中文：**这一条钉住的是"图形页认应用的角度单位"。** 判据用的是同一个 `sin(x)` 在两种单位下
  //       解出来的零点：弧度制在 [-6, 6] 里有 0、±π 三个，角度制只剩 x = 0 一个；两条曲线里的
  //       抛物线在两种单位下都是两个零点，所以总数是 5 与 3。第二段是**换单位**：同一个 State
  //       被更新（不是新建），已经拿在手里的函数必须重盖新单位，否则旧的曲线会留在屏幕上。
  // English: **this pins "the graph page honours the app's angle unit".** The discriminator is the
  //          zeros of one `sin(x)` under both units: radians give three in [-6, 6] (0, ±π), degrees
  //          leave only x = 0; the parabola in the same list contributes two either way, so the totals
  //          are 5 and 3. The second half is **switching the unit**: the same State is updated (not
  //          rebuilt from scratch) and the functions already in hand must be re-stamped, or the old
  //          curve stays on screen.
  testWidgets('角度单位真的到达求值：sin(x) 的零点在 DEG 与 RAD 下不同', (tester) async {
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeGraphDatabase(settingsCompleter);

    Widget page({required String angleMode}) => MaterialApp(
          home: Scaffold(
            body: GraphPage(
              db: db,
              restoreState: false,
              angleMode: angleMode,
            ),
          ),
        );

    await tester.pumpWidget(page(angleMode: 'RAD'));
    await tester.pumpAndSettle();
    await _tapZeros(tester);
    expect(find.textContaining('找到 5 个零点'), findsOneWidget,
        reason: '弧度制下 sin(x) 在 [-6, 6] 里有 0、±π 三个零点，抛物线再贡献两个');

    await tester.pumpWidget(page(angleMode: 'DEG'));
    await tester.pumpAndSettle();
    await _tapZeros(tester);
    expect(find.textContaining('找到 3 个零点'), findsOneWidget,
        reason: '角度制下 sin(x) 在 [-6, 6] 里只剩 x = 0 一个零点');
    expect(find.textContaining('3.141593'), findsNothing,
        reason: 'π 是弧度制下的零点，角度制里它不该出现在任何一个标记上');
  });

  testWidgets('恢复的工作区里的函数也按当前角度单位求值', (tester) async {
    // 中文：工作区（线格式）里只有表达式、可见性与颜色，**没有角度单位**——恢复出来的函数带的是
    //       恢复那一刻设置里的单位。这里存的是弧度制下写出去的 `sin(x)`，用角度制恢复。
    // English: the workspace wire format carries the expression, visibility and colour but **no angle
    //          unit** — a restored function takes the unit from settings at restore time. What is
    //          stored here is a `sin(x)` written under radians; it is restored under degrees.
    final settingsCompleter = Completer<Map<String, String>>()
      ..complete({
        graphWorkspaceSettingKey: encodeGraphWorkspace(
          functions: const [
            GraphFunction(
              expression: 'sin(x)',
              label: 'y = sin(x)',
              color: Color(0xFF1677FF),
            ),
          ],
          viewport: defaultGraphViewport,
        ),
      });
    final db = _FakeGraphDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GraphPage(
          db: db,
          restoreState: true,
          angleMode: 'DEG',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await _tapZeros(tester);

    expect(find.textContaining('找到 1 个零点'), findsOneWidget,
        reason: '角度制下 sin(x) 在 [-6, 6] 里只有 x = 0 一个零点');
  });

  // ——— 缺口 1：函数行菜单（添加 / 编辑 / 隐藏 / 删除）此前没有任何测试驱动过 ———
  // 中文：这一组**驱动真的菜单与真的对话框**（弹出菜单 → 对话框 → 页面重建），断言的是页面
  //       **显示**出来的东西：函数行、状态句、零点个数、标记面板——不是"菜单项能被点到"。
  // English: this group **drives the real menu and the real dialog** (popup menu → dialog → page
  //          rebuild) and asserts what the page **shows**: the function rows, the status sentence, the
  //          zero count, the marker panel — not that a menu item was tappable.
  testWidgets('添加函数：新函数进列表并真的参与求值', (tester) async {
    await _pumpGraphPage(tester);
    expect(find.byType(FunctionRow), findsNWidgets(2));

    await tester.tap(find.byTooltip('添加函数'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'x + 3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('y = x + 3'), findsOneWidget);
    expect(find.byType(FunctionRow), findsNWidgets(3));

    await _scrollStatusIntoView(tester);
    expect(find.text('已添加 y = x + 3'), findsOneWidget);

    await _tapZeros(tester);
    expect(find.textContaining('找到 6 个零点'), findsOneWidget,
        reason: 'x+3 在 x=-3 的零点与 sin 的零点不重合，必须真的多出一个');
  });

  testWidgets('编辑函数：新表达式换掉旧曲线，旧零点随之消失', (tester) async {
    await _pumpGraphPage(tester);

    await tester.tap(find.byTooltip('函数操作').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑函数'));
    await tester.pumpAndSettle();

    expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'sin(x)',
        reason: '编辑对话框要拿当前表达式预填');

    await tester.enterText(find.byType(TextField), 'x + 3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('y = sin(x)'), findsNothing);
    expect(find.text('y = x + 3'), findsOneWidget);
    expect(find.byType(FunctionRow), findsNWidgets(2));

    await _scrollStatusIntoView(tester);
    expect(find.text('已更新 y = x + 3'), findsOneWidget);

    await _tapZeros(tester);
    expect(find.textContaining('找到 3 个零点'), findsOneWidget);
    expect(find.textContaining('3.141593'), findsNothing,
        reason: 'π 是 sin 的零点，旧表达式被换掉后它不该再出现在任何标记上');
  });

  testWidgets('隐藏与显示：隐藏的曲线不再参与求值，解出的标记同时作废', (tester) async {
    await _pumpGraphPage(tester);
    await _tapZeros(tester);
    expect(find.textContaining('找到 5 个零点'), findsOneWidget);
    expect(find.textContaining('零点 1/5'), findsOneWidget);

    await _scrollToTop(tester);
    await tester.tap(find.byTooltip('隐藏').at(0));
    await tester.pumpAndSettle();

    expect(find.byTooltip('显示'), findsOneWidget);
    await _scrollStatusIntoView(tester);
    expect(find.text('已隐藏 y = sin(x)'), findsOneWidget);
    expect(find.textContaining('零点 1/5'), findsNothing,
        reason: '标记是旧曲线上的解，隐藏后必须一起撤掉');

    await _tapZeros(tester);
    expect(find.textContaining('找到 2 个零点'), findsOneWidget,
        reason: '只剩抛物线，它的零点是在 x = 1 与 x = 2');

    await _scrollToTop(tester);
    await tester.tap(find.byTooltip('显示'));
    await tester.pumpAndSettle();
    await _scrollStatusIntoView(tester);
    expect(find.text('已显示 y = sin(x)'), findsOneWidget);

    await _tapZeros(tester);
    expect(find.textContaining('找到 5 个零点'), findsOneWidget,
        reason: '重新显示后 sin 的零点要回来');
  });

  testWidgets('删除函数：行消失、标记作废；只剩一条时删除项被禁用', (tester) async {
    await _pumpGraphPage(tester);

    await tester.tap(find.byTooltip('函数操作').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除函数'));
    await tester.pumpAndSettle();

    expect(find.text('已删除 y = sin(x)'), findsOneWidget);
    expect(find.text('y = sin(x)'), findsNothing);
    expect(find.byType(FunctionRow), findsOneWidget);

    await _tapZeros(tester);
    expect(find.textContaining('找到 2 个零点'), findsOneWidget);

    await _scrollToTop(tester);
    await tester.tap(find.byTooltip('函数操作'));
    await tester.pumpAndSettle();

    final deleteItem = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, '删除函数'));
    expect(deleteItem.enabled, isFalse, reason: '最后一条函数不允许删除');

    await tester.tap(find.text('删除函数'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(30, 30));
    await tester.pumpAndSettle();

    expect(find.byType(FunctionRow), findsOneWidget);
    expect(find.text('已删除 y = x² - 3x + 2'), findsNothing);
  });

  // ——— 缺口 2：无效函数不许把页面弄崩 ———
  testWidgets('对话框拦住无法解析的表达式：不添加、不崩，页面照常工作', (tester) async {
    await _pumpGraphPage(tester);

    await tester.tap(find.byTooltip('添加函数'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sin(');
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.byType(FunctionExpressionDialog), findsOneWidget,
        reason: '无法计算的表达式不许关掉对话框');
    expect(find.text('表达式无法计算，请检查函数名、括号或变量 x'), findsWidgets);
    expect(find.textContaining('已添加'), findsNothing);
    expect(find.byType(FunctionRow), findsNWidgets(2));

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byType(FunctionExpressionDialog), findsNothing);
    await _tapZeros(tester);
    expect(find.textContaining('找到 5 个零点'), findsOneWidget,
        reason: '被拒绝的输入之后，页面仍然照常求值');
    expect(tester.takeException(), isNull);
  });

  testWidgets('定义域残缺的函数能被添加：页面照常渲染、照常解标记，不抛异常', (tester) async {
    // 中文：`sqrt(x - 1)` 在 x < 1 上求不出值——五个探针（-2、-1、0、1、2）里只有两个有效，
    //       仍够对话框放行（判据是"至少一个有效"），于是页面上真的多了一条半截曲线。
    //       判据是这条函数进得了列表、页面照常求值解标记、整个过程没有异常逃出去。
    //
    //       **它测的到此为止——不要读成"它在测分段时丢点那条失败保护"。** 量过：把
    //       `buildGraphPlotSegments` 里的 `inBand` 直接改成 `true`（即整条丢点保护拿掉，
    //       不只是 NaN 那半个条件），这一条**照样全绿**（`+13: All tests passed!`）。原因是
    //       画布对路径里的 NaN/Inf 点不抛异常，所以"不崩"这件事分辨不出保护在不在。
    //       那条保护的证据在 **`test/domain/graph_function_test.dart` 里那条
    //       "builds plot segments that break around discontinuities"**（纯函数级，断言 1/x
    //       被断成 ≥2 段且每个点的坐标有限），不在这里。
    // English: `sqrt(x - 1)` has no value for x < 1 — only two of the five probes (-2, -1, 0, 1, 2)
    //          come back valid, still enough for the dialog to let it through (the rule is "at least
    //          one valid"), so a genuinely half-drawn curve lands on the page. The evidence is that
    //          it reaches the list, the page keeps evaluating and solving markers, and no exception
    //          escapes anywhere along the way.
    //
    //          **That is the whole of what it measures — do not read it as "it measures the
    //          drop-the-point fail-safe in segment building".** Measured: replacing the `inBand`
    //          expression in `buildGraphPlotSegments` with a bare `true` (i.e. removing the whole
    //          drop, not merely its NaN half) leaves this test **green** (`+13: All tests passed!`),
    //          because the canvas does not throw on NaN/Inf points in a path — so "it does not
    //          crash" cannot tell the guard's presence from its absence. The guard's evidence is
    //          the pure-function test **"builds plot segments that break around discontinuities"**
    //          in `test/domain/graph_function_test.dart` (1/x must come out as ≥2 segments with every
    //          point finite); it is not here.
    await _pumpGraphPage(tester);

    await tester.tap(find.byTooltip('添加函数'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sqrt(x - 1)');
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.byType(FunctionRow), findsNWidgets(3));
    await _scrollStatusIntoView(tester);
    expect(find.text('已添加 y = sqrt(x - 1)'), findsOneWidget);

    await _tapZeros(tester);
    expect(find.textContaining('个零点'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ——— 缺口 3：标记的选择此前没有任何测试调用过 ———
  testWidgets('点画布上的标记：选中的是点中的那一个，不是第一个', (tester) async {
    await _pumpGraphPage(tester);
    await _tapZeros(tester);
    expect(find.textContaining('找到 5 个零点'), findsOneWidget);
    expect(find.textContaining('零点 1/5'), findsOneWidget);

    await _scrollToTop(tester);
    final canvas = tester.getRect(_graphCanvas());
    // 中文：默认视窗中心 (0,0)、跨度 12×12；x = 1 是抛物线 x²-3x+2 的零点，在标记表里排第 4。
    // English: the default viewport is centred on (0,0) with a 12×12 span; x = 1 is a zero of the
    //          parabola x²-3x+2 and sits fourth in the marker list.
    await tester.tapAt(canvas.topLeft +
        Offset(
          defaultGraphViewport.toScreenX(1, canvas.size),
          defaultGraphViewport.toScreenY(0, canvas.size),
        ));
    await tester.pumpAndSettle();
    await _scrollStatusIntoView(tester);

    expect(find.textContaining('零点 4/5'), findsOneWidget);
    expect(find.textContaining('x = 1.000000'), findsWidgets);

    await _scrollToTop(tester);
    await tester.tapAt(canvas.topLeft +
        Offset(
          defaultGraphViewport.toScreenX(-3.141592653589793, canvas.size),
          defaultGraphViewport.toScreenY(0, canvas.size),
        ));
    await tester.pumpAndSettle();
    await _scrollStatusIntoView(tester);

    expect(find.textContaining('零点 1/5'), findsOneWidget);
    expect(find.textContaining('x = -3.141593'), findsWidgets);
  });

  testWidgets('上一个/下一个标记按钮：在全部标记里环形切换', (tester) async {
    await _pumpGraphPage(tester);
    await _tapZeros(tester);
    expect(find.textContaining('零点 1/5'), findsOneWidget);

    await tester.tap(find.byTooltip('下一个标记'));
    await tester.pumpAndSettle();
    expect(find.textContaining('零点 2/5'), findsOneWidget);
    expect(find.textContaining('x = 0.000000'), findsWidgets);

    await tester.tap(find.byTooltip('上一个标记'));
    await tester.pumpAndSettle();
    expect(find.textContaining('零点 1/5'), findsOneWidget);

    await tester.tap(find.byTooltip('上一个标记'));
    await tester.pumpAndSettle();
    expect(find.textContaining('零点 5/5'), findsOneWidget,
        reason: '第一个再往前要绕到最后一个');
  });
}

Future<void> _pumpGraphPage(WidgetTester tester) async {
  final settingsCompleter = Completer<Map<String, String>>()..complete({});
  final db = _FakeGraphDatabase(settingsCompleter);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: GraphPage(
        db: db,
        restoreState: false,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// 中文：滚回列表顶部——函数行与画布都在上半部分。
/// English: scroll back to the top of the list, where the function rows and the canvas live.
Future<void> _scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 900));
  await tester.pumpAndSettle();
}

/// 中文：把状态条那句话滚进构建范围。**列表停在顶部时它没有被建出来**——这一条是量出来的
///       （`find.byType(Text)` 在那个偏移下数得到画布为止，状态条与标记面板都不在树里），
///       不是猜的；所以断言状态句之前必须先滚一下，否则断言量到的是"没建"而不是"没写"。
/// English: scrolls the status strip's sentence into the build range. **While the list rests at the
///          top it is not built** — measured (`find.byType(Text)` counts up to the canvas at that
///          offset; the status strip and the marker panel are not in the tree), not guessed. So a
///          status assertion has to scroll first, or it measures "not built" rather than "not written".
Future<void> _scrollStatusIntoView(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -420));
  await tester.pumpAndSettle();
}

/// 中文：画布那块 `CustomPaint`——按 painter 的类型认，避免与 Material 内部可能出现的
///       `CustomPaint` 混在一起。
/// English: the canvas `CustomPaint`, recognised by its painter's type so it cannot be confused with
///          any `CustomPaint` Material might insert.
Finder _graphCanvas() {
  return find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GraphPainter);
}

Future<void> _tapZeros(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -700));
  await tester.pumpAndSettle();
  await tester.tap(find.text('零点'));
  await tester.pumpAndSettle();
}

class _FakeGraphDatabase implements AppDatabase {
  _FakeGraphDatabase(this._settingsCompleter);

  final Completer<Map<String, String>> _settingsCompleter;
  final savedSettings = <String, String>{};

  @override
  Future<Map<String, String>> settings() async {
    return _settingsCompleter.future;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
