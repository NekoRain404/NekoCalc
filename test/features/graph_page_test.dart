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
