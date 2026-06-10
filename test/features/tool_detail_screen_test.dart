import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/application/controllers/tool_detail_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/usecases/data_fit.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/data_fit_tool_screen.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_detail_screen.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_screen.dart';

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('delayed tool draft does not overwrite local edits',
      (tester) async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final settingsCompleter = Completer<Map<String, String>>();
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: ToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pump();

    final currentField = _toolInput(tool.id, 'current');
    expect(currentField, findsOneWidget);
    await tester.enterText(currentField, '99 mA');
    await tester.pump(const Duration(milliseconds: 80));

    settingsCompleter.complete({
      ToolDetailController.draftSettingKey(tool.id):
          ToolDetailController.encodeDraft(
        tool: tool,
        rawValues: {
          'current': '10 mA',
          'resistance': '4.7kΩ',
          'tol': '1%',
        },
      ),
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_toolInputText(tester, tool.id, 'current'), '99 mA');
    expect(_toolInputText(tester, tool.id, 'resistance'), '4.7kΩ');
    expect(_toolInputText(tester, tool.id, 'tol'), '1%');
  });

  testWidgets('tool paste fills matching numeric inputs and saves draft',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return Future.value({
          'text': '''
参数\t读数
电流 I\t10 mA
电阻 R\t4.7kΩ ±5%
电阻公差\t1%
''',
        });
      }
      return null;
    });
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: ToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('粘贴参数'));
    await tester.pumpAndSettle();

    expect(_toolInputText(tester, tool.id, 'current'), '10 mA');
    expect(_toolInputText(tester, tool.id, 'resistance'), '4.7kΩ ±5%');
    expect(_toolInputText(tester, tool.id, 'tol'), '1%');
    expect(find.text('47'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 280));
    final draft = ToolDetailController.decodeDraft(
      tool: tool,
      raw: db.savedSettings[ToolDetailController.draftSettingKey(tool.id)],
    );
    expect(draft, isNotNull);
    expect(draft!['current'], '10 mA');
    expect(draft['resistance'], '4.7kΩ ±5%');
    expect(draft['tol'], '1%');
  });

  testWidgets('tool paste reports skipped and duplicate pasted parameters',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return Future.value({
          'text': '''
电流 I: 10 mA
电流 I: 25 mA
电压 V: 12 V
未知参数: 123
5
''',
        });
      }
      return null;
    });
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: ToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('粘贴参数'));
    await tester.pumpAndSettle();

    expect(_toolInputText(tester, tool.id, 'current'), '25 mA');
    expect(_toolInputText(tester, tool.id, 'voltage'), '12 V');
    expect(find.textContaining('已应用 2 个参数'), findsOneWidget);
    expect(find.textContaining('重复字段已取最后值：电流 I'), findsOneWidget);
    expect(find.textContaining('跳过 1 条歧义值'), findsOneWidget);
    expect(find.textContaining('忽略 1 条未匹配值'), findsOneWidget);
  });

  testWidgets('tool paste reports applied fields that still need correction',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return Future.value({
          'text': '''
电流 I: 10 mA
电阻 R: 12 V
未知参数: 123
''',
        });
      }
      return null;
    });
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: ToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('粘贴参数'));
    await tester.pumpAndSettle();

    expect(_toolInputText(tester, tool.id, 'current'), '10 mA');
    expect(_toolInputText(tester, tool.id, 'resistance'), '12 V');
    expect(find.text('2.2'), findsOneWidget);
    expect(find.textContaining('已应用 1 个参数'), findsOneWidget);
    expect(find.textContaining('需修正：电阻 R'), findsOneWidget);
    expect(find.textContaining('忽略 1 条未匹配值'), findsOneWidget);
    expect(find.textContaining('单位 V 与 Ω 不匹配'), findsWidgets);
  });

  testWidgets('tool copied inputs can be parsed back as pasted parameters',
      (tester) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments;
        if (args is Map) copiedText = args['text'] as String?;
      }
      return null;
    });
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: ToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(_toolInput(tool.id, 'current'), '10 mA');
    await tester.enterText(_toolInput(tool.id, 'resistance'), '4.7kΩ ±5%');
    await tester.enterText(_toolInput(tool.id, 'tol'), '1%');
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.byTooltip('复制参数'));
    await tester.pumpAndSettle();

    expect(copiedText, isNotNull);
    expect(copiedText, contains('输入参数:'));
    expect(copiedText, contains('电流 I: 0.01A'));
    expect(copiedText, contains('电阻 R: 4700Ω'));
    final parsed = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: copiedText!,
    );
    expect(parsed, {
      'current': '0.01A',
      'resistance': '4700Ω',
      'tol': '1%',
    });
  });

  testWidgets('delayed text tool draft only fills untouched fields',
      (tester) async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'custom_formula');
    final settingsCompleter = Completer<Map<String, String>>();
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: TextToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'a + b');
    await tester.pump(const Duration(milliseconds: 90));

    settingsCompleter.complete({
      TextToolController.draftSettingKey(tool.id):
          TextToolController.encodeDraft(
        const TextToolDraft(
          toolId: 'custom_formula',
          input: 'draft input',
          formula: 'a * b + c',
          a: '9',
          b: '8',
          c: '7',
        ),
      ),
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(_fieldText(tester, 0), 'a + b');
    expect(_fieldText(tester, 1), '9');
    expect(_fieldText(tester, 2), '8');
    expect(_fieldText(tester, 3), '7');
  });

  testWidgets('delayed data fit draft preserves edited data', (tester) async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'data_fit');
    final settingsCompleter = Completer<Map<String, String>>();
    final db = _FakeToolDetailDatabase(settingsCompleter);
    const localData = '1,10\n2,20\n3,30';

    await tester.pumpWidget(MaterialApp(
      home: DataFitToolScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, localData);
    await tester.pump(const Duration(milliseconds: 110));

    settingsCompleter.complete({
      dataFitDraftSettingKey(tool.id): encodeDataFitDraft(
        const DataFitDraft(
          toolId: 'data_fit',
          data: '1,1\n2,4\n3,9',
          prediction: '4',
          model: FitModel.quadratic,
          selectedSeriesIndex: 0,
        ),
      ),
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(_fieldText(tester, 0), localData);
    final savedDraft = decodeDataFitDraft(
      toolId: tool.id,
      raw: db.savedSettings[dataFitDraftSettingKey(tool.id)],
    );
    expect(savedDraft, isNotNull);
    expect(savedDraft!.data, localData);
    expect(savedDraft.prediction, '4');
    expect(savedDraft.model, FitModel.quadratic);
  });

  testWidgets('data fit paste restores copied report data model and prediction',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return Future.value({
          'text': '''
数据拟合
数据组: y1
二次拟合
y = x² + 0x + 0
R²=1, RMSE=0

预测: x=4, y=16

数据:
x,y
1,1
2,4
3,9
''',
        });
      }
      return null;
    });
    final tool = toolCatalog.firstWhere((item) => item.id == 'data_fit');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: DataFitToolScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('粘贴'));
    await tester.pumpAndSettle();

    expect(_dataFitFieldText(tester, tool.id, 'data'), 'x,y\n1,1\n2,4\n3,9');
    expect(find.textContaining('已从报告提取数据'), findsOneWidget);
    expect(find.textContaining('模型 二次'), findsOneWidget);
    expect(find.textContaining('预测 x=4'), findsOneWidget);
    expect(find.text('二次拟合'), findsWidgets);
    await tester.scrollUntilVisible(
      _dataFitField(tool.id, 'prediction'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(_dataFitFieldText(tester, tool.id, 'prediction'), '4');
    expect(find.textContaining('y=16'), findsWidgets);
  });

  testWidgets('invalid data fit result is not saved to history or notes',
      (tester) async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'data_fit');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: DataFitToolScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'bad data');
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '保存'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入至少两行有效数据'), findsWidgets);
    expect(db.savedToolHistory, isEmpty);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '笔记'));
    await tester.pumpAndSettle();
    expect(db.savedNotes, isEmpty);
  });

  testWidgets('data fit save reports write failures without creating records',
      (tester) async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'data_fit');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(
      settingsCompleter,
      zeroNextHistoryWrite: true,
      zeroNextNoteWrite: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: DataFitToolScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '保存'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('历史记录没有写入，请重试'), findsOneWidget);
    expect(db.savedToolHistory, isEmpty);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '笔记'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '笔记'));
    await tester.pumpAndSettle();
    expect(find.text('笔记没有写入，请重试'), findsOneWidget);
    expect(db.savedNotes, isEmpty);
  });

  testWidgets('data fit save reports database exceptions', (tester) async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'data_fit');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(
      settingsCompleter,
      nextHistoryError: StateError('history locked'),
      nextNoteError: StateError('note locked'),
    );

    await tester.pumpWidget(MaterialApp(
      home: DataFitToolScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '保存'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存历史失败'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '笔记'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '笔记'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存笔记失败'), findsOneWidget);
  });

  testWidgets('slow text tool paste completion is ignored after page pop',
      (tester) async {
    final clipboardCompleter = Completer<Map<String, Object?>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return clipboardCompleter.future;
      }
      return null;
    });
    final tool = toolCatalog.firstWhere((item) => item.id == 'base64');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: TextToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('粘贴'));
    await tester.pump();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    clipboardCompleter.complete({'text': 'late clipboard'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
  });

  testWidgets('custom formula paste fills formula and variables',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return Future.value({
          'text': '''
formula: a^2 + sqrt(b) - c
a = 4
b = 81
c = 3
''',
        });
      }
      return null;
    });
    final tool = toolCatalog.firstWhere((item) => item.id == 'custom_formula');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: TextToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('粘贴'));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 0), 'a^2 + sqrt(b) - c');
    expect(_fieldText(tester, 1), '4');
    expect(_fieldText(tester, 2), '81');
    expect(_fieldText(tester, 3), '3');
    expect(find.text('22'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 320));
    final draft = TextToolController.decodeDraft(
      toolId: tool.id,
      raw: db.savedSettings[TextToolController.draftSettingKey(tool.id)],
    );
    expect(draft, isNotNull);
    expect(draft!.input, contains('formula: a^2 + sqrt(b) - c'));
    expect(draft.formula, 'a^2 + sqrt(b) - c');
    expect(draft.a, '4');
    expect(draft.b, '81');
    expect(draft.c, '3');
  });

  testWidgets('slow data fit paste completion is ignored after page pop',
      (tester) async {
    final clipboardCompleter = Completer<Map<String, Object?>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') {
        return clipboardCompleter.future;
      }
      return null;
    });
    final tool = toolCatalog.firstWhere((item) => item.id == 'data_fit');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: DataFitToolScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('粘贴'));
    await tester.pump();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    clipboardCompleter.complete({'text': '1,2\n2,4'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
  });

  testWidgets('text tool save reports write failures without creating records',
      (tester) async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'base64');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(
      settingsCompleter,
      zeroNextHistoryWrite: true,
      zeroNextNoteWrite: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: TextToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('历史记录没有写入，请重试'), findsOneWidget);
    expect(db.savedToolHistory, isEmpty);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '笔记'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '笔记'));
    await tester.pumpAndSettle();
    expect(find.text('笔记没有写入，请重试'), findsOneWidget);
    expect(db.savedNotes, isEmpty);
  });

  testWidgets('text tool save reports database exceptions', (tester) async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'base64');
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeToolDetailDatabase(
      settingsCompleter,
      nextHistoryError: StateError('history locked'),
      nextNoteError: StateError('note locked'),
    );

    await tester.pumpWidget(MaterialApp(
      home: TextToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存历史失败'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '笔记'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '笔记'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存笔记失败'), findsOneWidget);
  });
}

String _fieldText(WidgetTester tester, int index) {
  final field = tester.widget<TextField>(find.byType(TextField).at(index));
  return field.controller?.text ?? '';
}

Finder _toolInput(String toolId, String inputKey) {
  return find.byKey(ValueKey('tool-input-$toolId-$inputKey'));
}

String _toolInputText(WidgetTester tester, String toolId, String inputKey) {
  final field = tester.widget<TextField>(_toolInput(toolId, inputKey));
  return field.controller?.text ?? '';
}

Finder _dataFitField(String toolId, String fieldKey) {
  return find.byKey(ValueKey('data-fit-$toolId-$fieldKey'));
}

String _dataFitFieldText(
  WidgetTester tester,
  String toolId,
  String fieldKey,
) {
  final field = tester.widget<TextField>(_dataFitField(toolId, fieldKey));
  return field.controller?.text ?? '';
}

class _FakeToolDetailDatabase implements AppDatabase {
  _FakeToolDetailDatabase(
    this._settingsCompleter, {
    this.zeroNextHistoryWrite = false,
    this.zeroNextNoteWrite = false,
    this.nextHistoryError,
    this.nextNoteError,
  });

  final Completer<Map<String, String>> _settingsCompleter;
  final savedSettings = <String, String>{};
  final savedToolHistory = <Map<String, String>>[];
  final savedNotes = <Map<String, String>>[];
  bool zeroNextHistoryWrite;
  bool zeroNextNoteWrite;
  Object? nextHistoryError;
  Object? nextNoteError;

  @override
  Future<Map<String, String>> settings() async {
    return _settingsCompleter.future;
  }

  @override
  Future<Set<String>> favoriteToolIds() async {
    return const {};
  }

  @override
  Future<void> setSettings(Map<String, String> values) async {
    savedSettings.addAll(values);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  Future<int> addHistory({
    required String expression,
    required String result,
    String? toolId,
    DateTime? createdAt,
  }) async {
    final error = nextHistoryError;
    if (error != null) {
      nextHistoryError = null;
      throw error;
    }
    if (zeroNextHistoryWrite) {
      zeroNextHistoryWrite = false;
      return 0;
    }
    savedToolHistory.add({
      'expression': expression,
      'result': result,
      if (toolId != null) 'toolId': toolId,
    });
    return savedToolHistory.length;
  }

  @override
  Future<int> addNote(
    String title,
    String body, {
    String description = '',
  }) async {
    final error = nextNoteError;
    if (error != null) {
      nextNoteError = null;
      throw error;
    }
    if (zeroNextNoteWrite) {
      zeroNextNoteWrite = false;
      return 0;
    }
    savedNotes.add({
      'title': title,
      'body': body,
      'description': description,
    });
    return savedNotes.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
