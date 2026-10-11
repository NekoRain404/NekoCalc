import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**提交回执上屏的那一段接线。**
///
///       `CalculatorSubmitResult` 只留令牌，八句话住在 `CalculatorStrings` 里，由
///       `calculatorSubmitMessage` 在呈现边缘取；那处唯一的嘴上屏口是
///       `calculator_key_dispatch.dart` 里 `equals` 那个 `case` 的 `SnackBar`。组合器本身由
///       `test/domain/calculator_submit_result_test.dart` 单独钉住（八个结局逐条渲染），文案表由
///       `calculator_strings_test.dart` 钉住——**两处都证明不了「屏幕真的用了它」**。
///
///       这一条量的就是那根线：英文作用域挂上去，按 `=` 让那条 `SnackBar` 真的弹出来，屏幕上的
///       字必须是英文。少了它，「组合器改了、屏幕上那处没接上」（或接成了设置里的语言、漏掉
///       作用域里当场生效的那一张）会原样留在真实应用里，而所有测试全绿——与
///       `notes_page_test.dart` 那条「空标题笔记存进库的是英文兜底」同一个形状。
///
///       **空表达式是最容易确定性触发的那一格**（`emptyExpression`）：它不经过引擎往返、不带
///       载荷，`needsAttention` 为真，所以一次按键就有一条 `SnackBar`；成功那一格要等引擎
///       （`flutter test` 里是假引擎），对这条接线证明不了更多。
///
///       **设置里写着中文**（`AppSettings` 不传 `languageCode`，默认 `'zh'`），作用域里是英文：
///       屏幕上的字必须跟着**作用域**走——那正是 `app.dart` 里当场生效的那一份。
/// English: **the wiring that puts a submit receipt on screen.**
///
///          `CalculatorSubmitResult` keeps the token only; the eight sentences live in
///          `CalculatorStrings` and are fetched at the presentation edge by
///          `calculatorSubmitMessage`, whose one mouth to the screen is the `SnackBar` in
///          `calculator_key_dispatch.dart`'s `equals` case. The composer itself is pinned on its own in
///          `test/domain/calculator_submit_result_test.dart` (all eight outcomes rendered) and the copy
///          tables in `calculator_strings_test.dart` — **neither can prove "the screen really used
///          it"**.
///
///          What this measures is that wire: with an English scope installed, pressing `=` must raise
///          that `SnackBar` with English words on it. Without it, "the composer was fixed but the site
///          was never wired" (or is wired to the settings' language instead of the scope's
///          immediately effective one) would survive in the real app with every test green — the same
///          shape as `notes_page_test.dart`'s "a blank-titled note stores the English fallback" test.
///
///          **The empty expression is the easiest outcome to trigger deterministically**
///          (`emptyExpression`): no engine round trip, no payload, `needsAttention` is true, so one key
///          press yields a `SnackBar`. The success outcome waits on the engine (`flutter test` runs a
///          fake one) and would prove nothing more about this wire.
///
///          **The settings still say Chinese** (`AppSettings` without a `languageCode` defaults to
///          `'zh'`) while the scope says English: the words on screen must follow the **scope** — the
///          one live in `app.dart`.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('英文界面：按等号提交空表达式的回执是英文', (tester) async {
    await tester.pumpWidget(_testApp(language: AppLanguage.en));
    await tester.pumpAndSettle();

    // 中文：`✓` 是等号键的键面（键位表里 `equals` 那一格的基准标签）。空表达式提交后
    //       `needsAttention` 为真，屏幕上就该有那条 `SnackBar`。
    // English: `✓` is the equals key's face (the base label of the `equals` cell in the key table).
    //          Submitting an empty expression has `needsAttention` true, so that `SnackBar` belongs on
    //          screen.
    await tester.tap(find.text('✓').first);
    await tester.pumpAndSettle();

    expect(find.text('Enter an expression before calculating'), findsOneWidget,
        reason: '屏幕上没有这句英文回执——组合器与屏幕之间那根线断了，或者取的不是作用域里那张表');
    expect(find.text('请输入表达式后再计算'), findsNothing,
        reason: '英文界面上还在报中文——那正是提交路径这一轮要消灭的那件事');

    // 中文：让 SnackBar 自己走完（4 秒），测试结束时不留挂着的定时器。
    // English: let the SnackBar run out (4 seconds) so no timer is left pending at the end.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('默认（中文）界面：同一个动作报的还是原来那句话', (tester) async {
    // 中文：没有作用域时回落到中文——这是仓库那条「默认态与接入前逐字节相同」在屏幕上的一份证据。
    // English: with no scope the language falls back to Chinese — one piece of on-screen evidence for
    //          this repository's "the default state stays byte-identical" rule.
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('✓').first);
    await tester.pumpAndSettle();

    expect(find.text('请输入表达式后再计算'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}

/// 中文：被测主屏，与 `calculator_page_test.dart` / `calculator_paste_summary_test.dart` 里那两份
///       同形（同一组设置：不恢复状态、不自动存历史、无触感），只多一个可选的语言作用域。
///       **作用域装在 `builder:` 上**——与 `app.dart` 逐字同一个挂点（`builder` 的 child 就是
///       Navigator）。回执那句话由页面自己的 context 取（`CalculatorStrings.of`），它就在这条
///       作用域之下；照 `app.dart` 的挂法装，这条测试量的才是真实应用里的那条路径。
/// English: The screen under test, the same shape as the two in `calculator_page_test.dart` /
///          `calculator_paste_summary_test.dart` (same settings: no state restore, no auto-save, no
///          haptics) plus an optional language scope. **The scope sits on `builder:`** — the very hook
///          `app.dart` uses (`builder`'s child *is* the Navigator). The receipt's words are fetched
///          from the page's own context (`CalculatorStrings.of`), which sits below this scope; mounting
///          it the way `app.dart` does is what makes this test measure the real app's path.
Widget _testApp({AppLanguage? language}) {
  return MaterialApp(
    theme: ThemeData.light(),
    builder: language == null
        ? null
        : (context, child) =>
            AppLanguageScope(language: language, child: child!),
    home: Scaffold(
      body: CalculatorPage(
        db: _FakeDatabase(),
        onOpenSettings: () {},
        settings: const AppSettings(
          haptics: false,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: false,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
          groupThousands: false,
        ),
      ),
    ),
  );
}

class _FakeDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
