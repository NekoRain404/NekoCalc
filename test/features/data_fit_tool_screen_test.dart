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

  testWidgets('复制方程：剪贴板收到的正是屏幕上那条方程', (tester) async {
    // 中文：**这条钉的是「点一下，剪贴板里真的多出屏幕上那条方程」。** 此前这块只有
    //       `data_fit_copy_test.dart` 的**源码扫描**在守：它能证明代码里写着 `Clipboard.setData`，
    //       却证明不了用户点得到，也证明不了写进去的和看到的是同一个东西。
    //       断言把剪贴板里那串**反查回屏幕**——于是它既不是"非空就算过"，也不依赖方程的排版格式。
    // English: **this pins "tap it and the clipboard really gains the equation that is on screen".** Until
    //          now only `data_fit_copy_test.dart`'s **source scan** guarded this: it proves
    //          `Clipboard.setData` exists in the code, but neither that a user can reach it nor that what
    //          lands in the clipboard is what they saw. The assertion looks the clipboard string back up
    //          **on screen**, so it is neither "non-null, therefore fine" nor tied to the equation's exact
    //          formatting.
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments;
        if (args is Map) copied = args['text'] as String?;
      }
      return null;
    });
    final tool = toolCatalog.firstWhere((item) => item.id == 'data_fit');
    final db = _FakeToolDetailDatabase(
      Completer<Map<String, String>>()..complete(const <String, String>{}),
    );

    await tester.pumpWidget(MaterialApp(
      home: DataFitToolScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '1,10\n2,20\n3,30');
    await tester.pump(const Duration(milliseconds: 110));
    // 中文：**先把过渡动画走完再点。** `_animatedResult` 那层是切换动画，动画期间**新旧两个子节点同时挂着**——
    //       实测搜索器会因此找到**两颗**「复制方程」，`tap()` 直接因"找到 2 个"抛异常。**这不是页面把卡画了两遍**
    //       （`_resultCard` 全屏只被放一次，见 `data_fit_tool_screen.dart:353`），是我的测试没等它落定。
    // English: **let the transition finish before tapping.** `_animatedResult` is a switcher animation, and
    //          while it runs **both the outgoing and the incoming child stay mounted** — measured: the finder
    //          then sees **two** 「复制方程」 buttons and `tap()` throws on the ambiguity. **The page is not
    //          drawing the card twice** (`_resultCard` is placed exactly once, `data_fit_tool_screen.dart:353`);
    //          the test simply had not let it settle.
    await tester.pumpAndSettle();

    // 中文：**按标签找，不按图标找**——`Icons.functions` 在这一页上有**两个**（方程一处、另一处复制也有），
    //       实测 `tap()` 会因"找到 2 个"直接抛异常。标签是这颗键自己的名字，图标不是。
    //       页面在这里渲染中文：测试里没有装语言作用域，与隔壁那条"装上 en 作用域之后整屏没有汉字"互为对照。
    // English: **find it by its label, not by its icon** — `Icons.functions` appears **twice** on this page
    //          (the equation and another copy action), and `tap()` throws on an ambiguous finder. The label
    //          is this key's own name; the icon is not. The page renders Chinese here because no language
    //          scope is installed — the mirror image of the neighbouring test, which installs the en scope
    //          and demands no Chinese anywhere.
    // 中文：**先滚到看得见再点。** 默认测试视口是 800×600，而这张卡在输入卡、结果、图表、数据表之后——
    //       不滚的话 `tap()` 会**点空**，日志里留一行 `Warning: A call to tap() … was not hit`，而现象看起来
    //       却是「复制没生效」（剪贴板为空 ✗）。**"什么都没发生"有好几种来源，这一种是视口，不是功能。**
    //       滚动这一步照本文件既有的写法（六处 `scrollUntilVisible`）。
    // English: **scroll it into view first.** The default test surface is 800×600 and this card sits after the
    //          input card, the result, the chart and the data table — tapping without scrolling **misses**, the
    //          log keeps a `Warning: A call to tap() … was not hit` line, and the symptom instead looks like
    //          "copy does not work" (an empty clipboard ✗). **"Nothing happened" has several causes; this one
    //          is the viewport, not the feature.** The scroll follows this file's own idiom (six other uses).
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '复制方程'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '复制方程'));
    await tester.pumpAndSettle();

    expect(copied, isNotNull, reason: '点了「复制方程」，剪贴板一个字节都没收到');
    expect(find.text(copied!), findsOneWidget,
        reason: '写进剪贴板的那串在屏幕上找不到——用户复制的不是他看到的那个东西');
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
