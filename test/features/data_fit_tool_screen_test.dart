import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/usecases/data_fit.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/l10n/app_language.dart';
import 'package:nekocalc/features/tools/presentation/data_fit_tool_screen.dart';

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
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

  testWidgets('装上 AppLanguageScope(en) 之后拟合页整屏没有汉字', (tester) async {
    // 中文：**本轮那句"用英文界面时屏幕上不再有中文"的证据。** 拟合页的字有两个来源——界面自己的
    //       `DataFitStrings` 与领域层那张 `DataFitCopy`——这一条把两者一起按在屏幕上量：
    //       装英文作用域、粘一份**中文报告的原文**（粘进来的输入是中文，这是对的，识别本来就该认它），
    //       然后把渲染树里每一个 `Text` 的字连起来，断言**一个汉字都没有**。
    //       图表的坐标轴标签走 `FitChartPainter` 的画布，不在 `Text` 里，所以这条只覆盖文字节点——
    //       画布上的数只有数字与 `x` / `y`，与语言无关。
    // English: **the evidence for this round's claim that the English interface shows no Chinese.** The
    //          fit screen's words come from two places — the screen's own `DataFitStrings` and the domain
    //          layer's `DataFitCopy` — and this case measures both on screen: it installs the English
    //          scope, pastes **the Chinese report's own text** (Chinese input is correct — recognition is
    //          supposed to accept it), then joins the text of every `Text` in the rendered tree and
    //          asserts **not one Han character**. The chart's axis labels are painted on a canvas rather
    //          than through `Text`, so this covers text nodes only — and the canvas carries nothing but
    //          numbers and `x` / `y`, which are language-neutral.
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

    await tester.pumpWidget(AppLanguageScope(
      language: AppLanguage.en,
      child: MaterialApp(
        home: DataFitToolScreen(
          db: db,
          tool: tool,
          settings: AppSettings.fallback,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Paste'));
    await tester.pumpAndSettle();

    // 中文：**领域层那几句先单独钉住**，因为下面那条"整屏没有汉字"是它们与界面表合起来的效果。
    // English: **the domain layer's sentences are pinned on their own first**, because the
    //          "no Han on the whole screen" assertion below is their effect together with the screen
    //          table.
    expect(find.textContaining('Extracted data from a report'), findsOneWidget);
    expect(find.textContaining('Model Quadratic'), findsOneWidget);
    expect(find.textContaining('Prediction x=4'), findsOneWidget);
    expect(find.text('Quadratic fit'), findsWidgets);

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join('\n');
    final han = RegExp(r'[\u4e00-\u9fff]').firstMatch(rendered);
    expect(rendered.trim(), isNotEmpty, reason: '屏幕上一个字都没读到，这条断言就是空转的');
    expect(han, isNull, reason: '英文界面里还有汉字：${han?.group(0)}');
  });
}

String _fieldText(WidgetTester tester, int index) {
  final field = tester.widget<TextField>(find.byType(TextField).at(index));
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
    HistoryResultKind? resultKind,
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
    List<String> tags = const [],
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
