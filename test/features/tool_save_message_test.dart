import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_detail_screen.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**保存回执上屏的那一段接线（文本工具那一屏）。**
///
///       `ToolSaveResult` 只留两个令牌（`ToolSaveStatus` × `ToolSaveTarget`），七句话住在
///       `ToolsStrings` 里，由 `toolSaveMessage` 在呈现边缘取——三个屏幕共四处 `SnackBar` 都这么印
///       （`text_tool_detail_screen.dart` 的历史与笔记两处、`data_fit_actions.dart` 的两处）。
///       组合器本身由 `test/domain/tool_save_result_test.dart` 单独钉住，文案表由
///       `tools_strings_test.dart` 逐格钉住——**两处都证明不了「屏幕真的用了它」**。默认作用域下
///       那几条中文回执也已经由 `tool_detail_screen_test.dart` / `data_fit_tool_screen_test.dart`
///       钉在屏幕上，缺的正是**作用域那一半**。
///
///       这一条量的就是那根线：英文作用域挂上去，按「保存」与「笔记」让那两条 `SnackBar` 真的弹
///       出来，屏幕上的字必须是英文。少了它，「组合器改了、屏幕上那处没接上」（或取的是别的语言
///       那张表）会原样留在真实应用里，而所有测试全绿——与 `calculator_submit_message_test.dart`
///       那条「按等号提交空表达式的回执是英文」同一个形状。
///
///       **「没写进去」是最容易确定性触发的一格**（`notWritten`）：假库对写回数答 0，不经引擎
///       往返、也不带走载荷，一次点击就有一条 `SnackBar`；成功那一格要真的写进库，对这条接线
///       证明不了更多。
///
///       屏幕跑在 `AppSettings.fallback`（默认态）上，语言只由作用域决定。
/// English: **the wiring that puts a save receipt on screen (the text tool screen).**
///
///          `ToolSaveResult` keeps the two tokens only (`ToolSaveStatus` × `ToolSaveTarget`); the seven
///          sentences live in `ToolsStrings` and are fetched at the presentation edge by
///          `toolSaveMessage`, which is how all four `SnackBar`s print (the text tool screen's history
///          and note sites, and the two in `data_fit_actions.dart`). The composer is pinned on its own
///          in `test/domain/tool_save_result_test.dart` and the copy table cell by cell in
///          `tools_strings_test.dart` — **neither can prove "the screen really used it"**. The Chinese
///          receipts under the default scope are already on screen in `tool_detail_screen_test.dart` /
///          `data_fit_tool_screen_test.dart`; **the scope's half** is the missing one.
///
///          What this measures is that wire: with an English scope installed, tapping Save and Note
///          must raise those two `SnackBar`s with English words on them. Without it, "the composer was
///          fixed but the site was never wired" (or is wired to some other language's table) would
///          survive in the real app with every test green — the same shape as
///          `calculator_submit_message_test.dart`'s "the receipt of submitting an empty expression is
///          English".
///
///          **"Not written" is the easiest outcome to trigger deterministically** (`notWritten`): the
///          fake database answers 0 rows, so there is no engine round trip and no payload, and one tap
///          yields a `SnackBar`. The success outcome needs a real write and would prove nothing more
///          about this wire.
///
///          The screen runs on `AppSettings.fallback` (the default state); the language is decided by
///          the scope alone.
void main() {
  testWidgets('英文界面：文本工具两条保存回执都是英文', (tester) async {
    await _pumpTextTool(tester, language: AppLanguage.en);

    await _tapHistorySave(tester, 'Save');
    // 中文：回执是 `notWritten`（假库答 0 行）——一整个格子的字都来自表，不带载荷。
    // English: the receipt is `notWritten` (the fake answers 0 rows) — the whole cell comes from the
    //          table, carrying no payload.
    expect(find.text('The history entry was not written; try again'), findsOneWidget,
        reason: '屏幕上没有这句英文回执——组合器与屏幕之间那根线断了，或者取的不是作用域里那张表');
    expect(find.text('历史记录没有写入，请重试'), findsNothing,
        reason: '英文界面上还在报中文——那正是保存路径这一轮要消灭的那件事');

    await _tapNoteSave(tester, 'Note');
    expect(find.text('The note was not written; try again'), findsOneWidget,
        reason: '笔记那一格没有取作用域里的表');
    expect(find.text('笔记没有写入，请重试'), findsNothing,
        reason: '英文界面上还在报中文——那正是保存路径这一轮要消灭的那件事');

    // 中文：让最后一条 SnackBar 自己走完（4 秒），测试结束时不留挂着的定时器。
    // English: let the last SnackBar run out (4 seconds) so no timer is left pending at the end.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('默认（中文）界面：同一个动作报的还是原来那两句话', (tester) async {
    // 中文：没有作用域时回落到中文——这是仓库那条「默认态与接入前逐字节相同」在屏幕上的又一份证据。
    // English: with no scope the language falls back to Chinese — another piece of on-screen evidence
    //          for this repository's "the default state stays byte-identical" rule.
    await _pumpTextTool(tester);

    await _tapHistorySave(tester, '保存');
    expect(find.text('历史记录没有写入，请重试'), findsOneWidget);

    await _tapNoteSave(tester, '笔记');
    expect(find.text('笔记没有写入，请重试'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}

/// 中文：被测的那一屏，与 `tool_detail_screen_test.dart` 里那条中文回执用例同一份设置
///       （`AppSettings.fallback`、`base64`、只答 0 行/空设置的假库），只多一个可选的语言作用域。
///       **作用域装在 `builder:` 上**——与 `app.dart` 逐字同一个挂点（`builder` 的 child 就是
///       Navigator）。回执那句话由页面自己的 context 取（`ToolsStrings.of`），它就在这条作用域
///       之下；照 `app.dart` 的挂法装，这条测试量的才是真实应用里的那条路径。
/// English: the screen under test, the same setup as the Chinese-receipt case in
///          `tool_detail_screen_test.dart` (`AppSettings.fallback`, `base64`, a fake that answers
///          0 rows and empty settings) plus an optional language scope. **The scope sits on
///          `builder:`** — the very hook `app.dart` uses (`builder`'s child *is* the Navigator). The
///          receipt's words are fetched from the page's own context (`ToolsStrings.of`), which sits
///          below this scope; mounting it the way `app.dart` does is what makes this test measure the
///          real app's path.
Future<void> _pumpTextTool(WidgetTester tester, {AppLanguage? language}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    builder: language == null
        ? null
        : (context, child) =>
            AppLanguageScope(language: language, child: child!),
    home: TextToolDetailScreen(
      db: _ZeroWriteDatabase(),
      tool: toolCatalog.firstWhere((item) => item.id == 'base64'),
      settings: AppSettings.fallback,
    ),
  ));
  await tester.pumpAndSettle();
}

/// 中文：按「保存」（历史）那颗按钮，与 `tool_detail_screen_test.dart` 里那条中文回执用例同一个
///       动作顺序：先把动作区滚进视野，再点。按钮那一格由 `strings.save` 给字（英文 `Save`、
///       中文 `保存`），所以标签由调用方给。
/// English: taps the Save (history) button in the same order as the Chinese-receipt case in
///          `tool_detail_screen_test.dart`: scroll the action row into view first, then tap. That
///          button's face comes from `strings.save` (English `Save`, Chinese `保存`), so the caller
///          hands the label in.
Future<void> _tapHistorySave(WidgetTester tester, String label) async {
  await tester.drag(find.byType(ListView), const Offset(0, -700));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, label));
  await tester.pumpAndSettle();
}

/// 中文：等上一条 `SnackBar` 走完（4 秒）再滚到「笔记」那颗按钮——两条回执不叠在一起，读数才
///       分得清是哪一条。
/// English: waits out the previous `SnackBar` (4 seconds) before scrolling to the Note button — the
///          two receipts never overlap, so a reading cannot be the wrong one.
Future<void> _tapNoteSave(WidgetTester tester, String label) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.widgetWithText(OutlinedButton, label),
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, label));
  await tester.pumpAndSettle();
}

/// 中文：一个写回数答 0 的库——两次保存都落在 `notWritten` 那一格，正好是回执里**不带载荷**的
///       那一类。`implements` 只列出这条路上真会被读到的成员，其余丢给 `noSuchMethod` 抛错：真被
///       读到说明这一屏比这条测试以为的读得多，那时应当红，而不是悄悄返回空。
/// English: a database that answers 0 rows — both saves land in the `notWritten` cell, exactly the
///          payload-free class of receipt. `implements` lists only the members this road really
///          reaches; everything else falls to `noSuchMethod` and throws — if one is reached, the
///          screen reads more than this test assumed and should go red rather than quietly answer
///          empty.
class _ZeroWriteDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<Set<String>> favoriteToolIds() async => const {};

  @override
  Future<int> addHistory({
    required String expression,
    required String result,
    String? toolId,
    HistoryResultKind? resultKind,
    DateTime? createdAt,
  }) async {
    return 0;
  }

  @override
  Future<int> addNote(
    String title,
    String body, {
    String description = '',
    List<String> tags = const [],
  }) async {
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
