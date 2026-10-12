import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/application/controllers/tool_detail_controller.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_detail_screen.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_screen.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_field_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

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

  testWidgets('打字也会让结果上屏：10 mA / 4.7kΩ → 屏幕上出现 47', (tester) async {
    // 中文：**这条补的是审计 §5r 第 2.3 条的欠账。** 那条说：打字驱动重算有测试，但**没有一条**断言
    //       结果真的**上了屏** ✗。同文件里唯一能断言"屏幕上有结果"的测试走的是**粘贴**（`find.text('47')`）✓，
    //       所以这里走**输入**，可观察量照它那条 ✓——`findsOneWidget` 意味着屏幕上**恰好一个** 47 ✓
    //       （主结果框与结果卡不会各印一个 ✓）。
    //
    //       ⚠️ **它证明什么、不证明什么，写清楚**：它证明"打字 → 结果上屏"这条路通 ✓；
    //       它**不**把断言**限定**在主结果框那一格内 ✗——那个抓手（框内复制按钮的 tooltip）在我早先的一版里
    //       `find.byTooltip` 命中 0 个 ✗，**原因没查明** ✓，而我不拿一个没查清的抓手去写断言 ✗。
    // English: **this pays the debt audit §5r item 2.3 recorded.** That item said typed input driving recompute
    //          has tests, but **nothing** asserted the result had actually **reached the screen** ✗. The only
    //          test in this file that asserts "a result is on screen" goes through **paste**
    //          (`find.text('47')`) ✓, so this one goes through **typing**, with the same observable —
    //          `findsOneWidget` means there is **exactly one** 47 on screen ✓ (the primary box and the result
    //          card do not each print one ✓).
    //
    //          ⚠️ **What it proves, and what it does not, stated plainly:** it proves the "typing → the result
    //          reaches the screen" road works ✓. It does **not** scope the assertion to the primary box's own
    //          cell ✗ — and a later measurement narrowed why: `copyPrimaryResult` lives in **one** table only
    //          (`tools_strings.dart`, zh `'复制主结果'`) and `_primaryResult` reads exactly that table, so the
    //          literal was right — **the box itself was not rendered.** ⚠️ And `findsOneWidget` is what says so:
    //          if the primary box were drawing the value too there would be **two** 47s on screen, not one. So
    //          with these inputs (`ohms_law`, `10 mA`, `4.7kΩ`) the 47 here comes from the **result card**, and
    //          this screen has **no primary** — while the domain-level integration test does read
    //          `primary?.value == '47'` from the same tool, which means it drives the controller differently.
    //          That difference is a real open question, recorded rather than papered over.
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final db = _FakeToolDetailDatabase(
        Completer<Map<String, String>>()..complete(const <String, String>{}));

    await tester.pumpWidget(MaterialApp(
      home: ToolDetailScreen(
        db: db,
        tool: tool,
        settings: AppSettings.fallback,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(_toolInput(tool.id, 'current'), '10 mA');
    await tester.enterText(_toolInput(tool.id, 'resistance'), '4.7kΩ');
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('47'), findsOneWidget,
        reason: '打了 10 mA / 4.7kΩ，屏幕上应当出现 47（粘贴那条测试就是这么断言的）');

    // 中文：**顺手量掉那个悬着的问题**：主结果框到底渲不渲染？它的复制按钮（框内、`'复制主结果'`）
    //       在**这条已绿测试的确切环境**里找得到 ⇒ **框渲染了** ✓✓。
    //
    //       ⚠️ 这条线索上我推错过两次，两次都留在这里，因为错法比结论更值得记：
    //       ① 我先按"屏幕上恰好一个 47"推出"框没渲染" ✗ —— 但**框很可能渲染的是带单位的形式**（`47 V`），
    //          于是 `find.text('47')` 的精确匹配只命中结果卡 ✓；**一个 47 与"框存在"并不矛盾** ✓。
    //       ② 于是我把"框存在"当成了被测事实 ✓ —— 一量，它确实存在 ✓。
    //       剩下的**假设**（未量 ✓）：我早先那版失败在**它自己的环境**上，最可能是 `scrollUntilVisible` 与
    //       **惰性列表**相互作用——滚出视口就被卸载 ⇒ `Bad state: No element` ✓。**事实与假设，写法上分开。**
    // English: **and measure the open question while we are here**: does the primary box render at all? Its copy
    //          button (inside the box, `'复制主结果'`) **is findable in this already-green test's exact setup**
    //          ⇒ **the box does render** ✓✓.
    //
    //          ⚠️ I got this thread wrong twice, and both mistakes stay here because the way they were wrong is
    //          worth more than the answer:
    //          (1) from "exactly one 47 on screen" I concluded "the box does not render" ✗ — but the box most
    //              likely renders the value **with its unit** (`47 V`), so an exact `find.text('47')` only ever
    //              hits the result card ✓; **one 47 does not contradict the box existing** ✓.
    //          (2) so I then treated "the box exists" as the thing to be tested ✓ — and one measurement said it
    //              does ✓.
    //          What remains a **hypothesis** (not measured ✓): that my earlier failure lay in **that version's
    //          own setup**, most likely `scrollUntilVisible` interacting with a **lazy list** — scrolled out of
    //          the viewport means unbuilt, hence `Bad state: No element` ✓. **Facts and hypotheses are written
    //          differently, on purpose.**
    expect(find.byTooltip('复制主结果'), findsOneWidget,
        reason: '主结果框应当在场（它的复制按钮就在框内）');
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

  testWidgets('状态卡那一支：参数有错那句话两种语言各是各的，中文侧与改动前逐字节相同',
      (tester) async {
    // 中文：**这一条钉的是本轮那一格。** 参数有错时状态卡显示的那一句是
    //       `标签（单位）: 判据写下的那句话`，左边两格都该走 `ToolFieldStrings`——而"屏幕真的把那
    //       两个读法递进控制器了"只有**从渲染树上读**才算数：忘了递，渲染出来就是目录里那条中文，
    //       下面「屏幕上有这一句」的断言当场变红（本轮的红证据就是这么做的：把状态卡那一支改回
    //       不带参数的读法，这一条当场红）。
    //
    //       **中文侧量的是"没动"**：中文表是空表、查不到原样返回，所以屏幕侧这一句与默认读法
    //       （也就是改动前的那一句）逐字节相同，而屏幕上渲染的正是它。
    //       **英文侧量的是"改了"**：那一句不再是中文，且左边那两格一个汉字都没有。
    //       **第三格（判据写下的那句话）不在这条里**——本条只量左边两格。那一格后来单独钉了一条：
    //       目录给参数声明的那个单位现在也过表了（`numeric_input_strings.dart` 的文件头），
    //       **`Unit L does not match 万元` 已经不成立**，见下面「单位不匹配那一整行」那条。
    // English: **this pins this round's cell.** The sentence the status card shows when an input is
    //          invalid is `label (unit): the sentence the verdict wrote`, and its first two cells should
    //          go through `ToolFieldStrings` — but "the screen really hands those two readers to the
    //          controller" only counts when it is **read off the render tree**: if they are not handed
    //          in, what renders is the catalogue's Chinese and the "this sentence is on screen"
    //          assertion below goes red on the spot (that is exactly how this round's red proof was
    //          taken: put the status card's branch back to the no-argument reading and this test fails).
    //
    //          **The Chinese side measures "did not move"**: the Chinese table is empty and a miss comes
    //          back unchanged, so the screen's sentence is byte-for-byte the default reading — which is
    //          the pre-change sentence — and that is what renders.
    //          **The English side measures "moved"**: the sentence is no longer Chinese, and neither of
    //          its first two cells holds a Han character.
    //          **The third cell (the sentence the verdict wrote) is not in this test** — this one
    //          measures only the two left cells. That cell got its own test later: the unit the
    //          catalogue declares for the parameter now goes through a table too
    //          (`numeric_input_strings.dart`'s head), so **`Unit L does not match 万元` no longer holds**;
    //          see "单位不匹配那一整行" below.
    final zhController = _controllerFor('ohms_law', ToolDetailStrings.toolDetailZh)
      ..updateValues({'resistance': 'bad value'});
    final zhRaw = zhController.inputErrorSummary();
    final zhDisplay = zhController.inputErrorSummary(
      inputLabel: ToolFieldStrings.toolFieldsZh.inputLabel,
      inputUnit: ToolFieldStrings.toolFieldsZh.inputUnit,
    );
    expect(zhDisplay, zhRaw, reason: '中文屏幕侧与改动前那一句不是逐字节相同');
    expect(zhDisplay, '电阻 R（Ω）: 无法解析数值或表达式');
    expect(await _pumpInvalidInput(tester, AppLanguage.zh, 'ohms_law', 'resistance'),
        contains(zhDisplay),
        reason: '中文状态卡上没有渲染出那一句');

    final enController = _controllerFor('ohms_law', ToolDetailStrings.toolDetailEn)
      ..updateValues({'resistance': 'bad value'});
    const enTable = ToolFieldStrings.toolFieldsEn;
    final enDisplay = enController.inputErrorSummary(
      inputLabel: enTable.inputLabel,
      inputUnit: enTable.inputUnit,
    );
    expect(enDisplay, isNot(zhDisplay),
        reason: '两种语言必须是两句不同的话，否则这条断言在空转');
    final enTexts =
        await _pumpInvalidInput(tester, AppLanguage.en, 'ohms_law', 'resistance');
    expect(enTexts, contains(enDisplay),
        reason: '英文状态卡上那一句不是显示层算出来的那一句');
    expect(enTexts, isNot(contains(zhDisplay)),
        reason: '英文状态卡上还是改动前那一句中文');
    for (final line in enDisplay.split('\n')) {
      final label = line.split(': ').first;
      expect(_han.hasMatch(label), isFalse, reason: '英文那一行左边那句还有汉字：$line');
    }
  });

  testWidgets('英文状态卡上「单位不匹配」那一整行也一个汉字都没有了', (tester) async {
    // 中文：**这一条钉的是本轮关掉的那个残留。** 上一条量的是「左边两格」（标签与单位），
    //       而冒号右边那句里还留着目录给参数声明的那个单位——**`loan` 的 `amount` 单位是 `万元`**，
    //       所以英文界面上那一行原本是 `Unit V does not match 万元`。
    //
    //       **上一条量不到它**：它打进 `ohms_law` 的是一句读不出来的话，落的是 `unparsable` 那一支，
    //       根本走不到不匹配。所以要另起一条、换一个**单位是中文**的工具、打进一个**单位对不上**的值。
    //       `5V` 对 `万元`：`V` 是认得的单位，换不过去，于是判据写下 `unitMismatch`。
    // English: **this pins the remainder this round closed.** The test above measures the two left cells
    //          (label and unit), while the sentence right of the colon still held the unit the catalogue
    //          declares for the parameter — **`loan`'s `amount` is denominated in `万元`**, so an English
    //          screen used to read `Unit V does not match 万元`.
    //
    //          **The test above cannot see it**: what it types into `ohms_law` is an unreadable phrase,
    //          which lands in the `unparsable` branch and never reaches a mismatch. So this needs its own
    //          case, a tool whose **unit is Chinese**, and a value whose **unit does not fit**. `5V`
    //          against `万元`: `V` is a known unit, it will not convert, and the verdict writes
    //          `unitMismatch`.
    final texts = await _pumpInvalidInput(tester, AppLanguage.en, 'loan', 'amount',
        value: '5V');
    final mismatchLines =
        texts.where((line) => line.contains('does not match')).toList();
    expect(mismatchLines, isNotEmpty,
        reason: '英文状态卡上没有渲染出那条不匹配的消息；屏幕上只有：$texts');
    for (final line in mismatchLines) {
      expect(_han.hasMatch(line), isFalse, reason: '英文那一行还有汉字：$line');
    }
    expect(mismatchLines.join(' '), contains('10k ¥'),
        reason: '目录给参数声明的那个单位没有过表');
  });
}

String _fieldText(WidgetTester tester, int index) {
  final field = tester.widget<TextField>(find.byType(TextField).at(index));
  return field.controller?.text ?? '';
}

Finder _toolInput(String toolId, String inputKey) {
  return find.byKey(ValueKey('tool-input-$toolId-$inputKey'));
}

/// 中文：**汉字**（含扩展 A 与兼容区）。英文那一侧不许有它；`Ω`、`℃`、`·`、`μ` 这些**记号**
///       不在此列，它们本来就该在。
/// English: **Han characters** (extension A and the compatibility block included). The English side may
///          not hold one; **notation** such as `Ω`, `℃`, `·` and `μ` is not in this class and is supposed
///          to be there.
final RegExp _han = RegExp(r'[㐀-䶿一-鿿豈-﫿]');

/// 中文：渲染一屏详情页，往 [inputKey] 那一格敲一个读不出来的值，等过防抖，再把**整棵树上的
///       `Text` 原文**交回去。**交回一整列而不是"我预期的那个"**：这样「屏幕上有这一句」与
///       「屏幕上没有那一句」两条断言量的是同一棵树，不会因为找法不同而互相兜底。
///       参数有错时那两句分别由 `ToolDetailStrings`（判据写下的那句话）与 `ToolFieldStrings`
///       （标签与单位）拼出来，两条来源都在表里，所以返回的列里两边的效果都能看到。
/// English: renders one detail screen, types a value the parser cannot read into [inputKey]'s field, lets
///          the debounce fire, and hands back **every `Text`'s data on the whole tree**. **A whole list
///          rather than "the one I expect"**: that way the "this sentence is on screen" and "that
///          sentence is not on screen" assertions measure the same tree and cannot cover for each other
///          through different lookup tricks. When an input is invalid the two sentences come from
///          `ToolDetailStrings` (the sentence the verdict wrote) and `ToolFieldStrings` (the label and the
///          unit), both tabled, so the returned list shows the effect of each.
Future<List<String>> _pumpInvalidInput(WidgetTester tester, AppLanguage language,
    String toolId, String inputKey,
    {String value = 'bad value'}) async {
  final tool = toolCatalog.firstWhere((item) => item.id == toolId);
  final settingsCompleter = Completer<Map<String, String>>()..complete({});
  // 中文：**先换一棵空树再渲染这一屏。** 同一个元素位置上第二次 `pumpWidget` 不会重跑 `initState`，
  //       State（连同它手里那台控制器与上一轮那组 `_inputErrors`）会留下来——上一轮是中文，
  //       留下来的错误句就是中文的；而且输入框里已经是同一个坏值，`enterText` 写同一个字串不会
  //       触发监听、防抖也就不会重算。两件事都会让第二次的读数其实是第一次的。
  // English: **swap in an empty tree before rendering this screen.** A second `pumpWidget` at the same
  //          element position does not run `initState` again, so the State survives — with the controller
  //          it holds and the previous round's `_inputErrors`, which were computed in the other language;
  //          and the field already holds the same bad value, so `enterText` with an identical string fires
  //          no listener and the debounce never recomputes. Either one would make the second reading be
  //          the first one's.
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pump();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AppLanguageScope(
        language: language,
        child: ToolDetailScreen(
          db: _FakeToolDetailDatabase(settingsCompleter),
          tool: tool,
          settings: AppSettings.fallback,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.enterText(_toolInput(toolId, inputKey), value);
  // 中文：输入框到控制器之间有 60ms 防抖（`_scheduleInputUpdate`），等过它这一格才会真的报错。
  // English: there is a 60ms debounce between the field and the controller
  //          (`_scheduleInputUpdate`), and the error only appears once it has fired.
  await tester.pump(const Duration(milliseconds: 80));
  await tester.pump();
  return [
    for (final element in find.byType(Text).evaluate())
      (element.widget as Text).data ?? '',
  ];
}

/// 中文：造一台与屏幕无关、只用来算"这一句该长什么样"的控制器——屏幕自己那一台藏在 State 里。
///       这一条路不落库，所以仓库用一台空设置的表就够。
/// English: a controller built outside the screen, used only to work out "what this sentence should look
///          like" — the screen keeps its own inside its State. This route does not write to the database,
///          so an empty-settings store is enough for the repositories.
ToolDetailController _controllerFor(String toolId, ToolDetailStrings strings) {
  return ToolDetailController(
    historyRepository:
        HistoryRepository(_FakeToolDetailDatabase(Completer()..complete({}))),
    notesRepository:
        NotesRepository(_FakeToolDetailDatabase(Completer()..complete({}))),
    toolUsageRepository:
        ToolUsageRepository(_FakeToolDetailDatabase(Completer()..complete({}))),
    tool: toolCatalog.firstWhere((item) => item.id == toolId),
    strings: strings,
  );
}

String _toolInputText(WidgetTester tester, String toolId, String inputKey) {
  final field = tester.widget<TextField>(_toolInput(toolId, inputKey));
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
