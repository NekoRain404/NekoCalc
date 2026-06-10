import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/graph/presentation/graph_page.dart';

void main() {
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
