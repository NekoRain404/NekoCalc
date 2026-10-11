import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**保存笔记回执上屏的那一段接线（计算器主屏的 `More...` 面板）。**
///
///       `CalculatorSaveNoteResult` 只留令牌（`CalculatorSaveNoteStatus` 七格），那些句子住在
///       `CalculatorStrings` 里，由 `calculatorSaveNoteMessage` 在呈现边缘取；那处唯一的嘴上屏口是
///       `calculator_page_sheets.dart` 里 `_saveNote()` 的那条 `SnackBar`。组合器本身由
///       `test/domain/calculator_save_result_test.dart` 单独钉住、文案表由 `calculator_strings_test.dart`
///       钉住、领域侧的七个结局由 `calculator_controller_persistence_test.dart` 逐条钉住——
///       **三处都证明不了「屏幕真的用了它」**。`calculator_page_test.dart` 里那条只断言「保存笔记」
///       这颗按钮点得到，**从没点下去过**，更没有一条在英文作用域下跑（`docs/verification.md` §5n）。
///
///       这一条量的就是那根线：英文作用域挂上去，真的按一次「保存笔记」让那条 `SnackBar` 弹出来，
///       屏幕上的字必须是英文。少了它，「组合器改了、屏幕上那处没接上」（或接成了设置里的语言、
///       漏掉作用域里当场生效的那一张）会原样留在真实应用里，而所有测试全绿。
///
///       **`notWritten` 是最便宜的确定性触发**：它只需要"表达式算得出、而写库没写成"。
///       表达式由**粘贴一份计算详情**（`当前值: 42`，与 `calculator_page_test.dart` 里那条同形）
///       当场取得——不经键盘；写库那一头由假库的 `addNote` 恒返 0 钉死
///       （`notesRepository.create` 拿到的 id ≤ 0 ⇒ `notWritten`）。
///       代价是这条路上仍要过一次引擎那一步（粘贴进来的 42 在控制器里还没有算过的结果），
///       而假通道没人回话——`engineTimeout` 那 5 秒由**假时钟**推过去（见
///       `_pasteCurrentValueThenSaveNote` 的第 2 条），不是挂钟等待，确定性不受影响。
///       成功那一格要等真的引擎回话，对这条接线证明不了更多。
///
///       **设置里写着中文**（`AppSettings` 不传 `languageCode`，默认 `'zh'`），作用域里是英文：
///       屏幕上的字必须跟着**作用域**走——那正是 `app.dart` 里当场生效的那一份。
/// English: **the wiring that puts a save-note receipt on screen (the calculator's `More...` sheet).**
///
///          `CalculatorSaveNoteResult` keeps the token only (`CalculatorSaveNoteStatus`, seven values);
///          the sentences live in `CalculatorStrings` and are fetched at the presentation edge by
///          `calculatorSaveNoteMessage`, whose one mouth to the screen is the `SnackBar` in
///          `_saveNote()` in `calculator_page_sheets.dart`. The composer itself is pinned on its own in
///          `test/domain/calculator_save_result_test.dart`, the copy tables in
///          `calculator_strings_test.dart`, and the seven outcomes on the domain side in
///          `calculator_controller_persistence_test.dart` — **none of the three can prove "the screen
///          really used it"**. The case in `calculator_page_test.dart` only asserts that the "Save note"
///          button is reachable; **it never presses it**, and not one case runs under an English scope
///          (`docs/verification.md` §5n).
///
///          What this measures is that wire: with an English scope installed, a real press of "Save
///          note" must raise that `SnackBar` with English words on it. Without it, "the composer was
///          fixed but the site was never wired" (or is wired to the settings' language instead of the
///          scope's immediately effective one) would survive in the real app with every test green.
///
///          **`notWritten` is the cheapest outcome to trigger deterministically**: it needs only "the
///          expression evaluates and the write did not land". The expression comes from **pasting a
///          calculation report** (`当前值: 42`, the same shape as the case in
///          `calculator_page_test.dart`) — no keypad — and the write side is pinned by a fake database
///          whose `addNote` always returns 0 (`notesRepository.create` seeing an id ≤ 0 means
///          `notWritten`). The price is that this road still passes the engine step (the pasted 42 has
///          no computed result in the controller yet) and nobody answers on a fake channel — the
///          `engineTimeout` 5 seconds are pushed by the **fake clock** (see item 2 in
///          `_pasteCurrentValueThenSaveNote`), not by waiting on the wall clock, so determinism is
///          untouched. The success outcome waits for a real engine reply and would prove nothing more
///          about this wire.
///
///          **The settings still say Chinese** (`AppSettings` without a `languageCode` defaults to
///          `'zh'`) while the scope says English: the words on screen must follow the **scope** — the
///          one live in `app.dart`.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('英文界面：保存笔记没写成时，回执是英文', (tester) async {
    _installCurrentValueClipboard();

    await _pumpCalculator(tester, language: AppLanguage.en);
    await _pasteCurrentValueThenSaveNote(tester,
        editExpression: 'Edit expression',
        pasteTooltip: 'Paste calculation details',
        saveNote: 'Save note');

    expect(find.text('The note was not written; try again'), findsOneWidget,
        reason: '屏幕上没有这句英文回执——组合器与屏幕之间那根线断了，或者取的不是作用域里那张表');
    expect(find.text('笔记没有写入，请重试'), findsNothing,
        reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');

    // 中文：让 SnackBar 自己走完（4 秒），测试结束时不留挂着的定时器。
    // English: let the SnackBar run out (4 seconds) so no timer is left pending at the end.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('默认（中文）界面：同一个动作报的还是原来那句话', (tester) async {
    // 中文：没有作用域时回落到中文——这是仓库那条「默认态与接入前逐字节相同」在屏幕上的一份证据。
    // English: with no scope the language falls back to Chinese — one piece of on-screen evidence for
    //          this repository's "the default state stays byte-identical" rule.
    _installCurrentValueClipboard();

    await _pumpCalculator(tester);
    await _pasteCurrentValueThenSaveNote(tester,
        editExpression: '编辑表达式',
        pasteTooltip: '粘贴计算详情',
        saveNote: '保存笔记');

    expect(find.text('笔记没有写入，请重试'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}

/// 中文：假平台通道：剪贴板里躺着那份计算详情——`当前值: 42` 会被粘贴成表达式 `42`，
///       于是「保存笔记」那颗按钮真的可用（`canSaveCurrentExpression` 要求表达式算得出）。
/// English: the fake platform channel: the clipboard holds that calculation report — `当前值: 42` pastes
///          as the expression `42`, so the "Save note" button is really usable
///          (`canSaveCurrentExpression` requires an expression that evaluates).
void _installCurrentValueClipboard() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return {
        'text': '''
当前值: 42
状态: 当前值可继续使用
角度模式: 角度 DEG
记忆值: 7.5
''',
      };
    }
    return null;
  });
}

/// 中文：**走真实按钮路径**：`More...` → 「编辑表达式」→ 粘贴那颗按钮 → 等粘贴回执走完 →
///       `More...` → 「保存笔记」。两颗按钮的标签各由调用方按当下的语言递进来。
///
///       两次等待都是必须的，理由各不同：
///       1. 粘贴回执那 5 秒——`ScaffoldMessenger` 一次只显示一条，不走完，保存回执就得排队，
///          屏幕上是旧的那句。
///       2. 保存那一步钟也要推过 `engineTimeout`（5 秒）——`saveToNote()` 里的 `await` 会去问引擎
///          （粘贴进来的 42 还没有算过的结果），而假通道没人回话，**这一格在测试里就是"等超时"**：
///          时钟推过去之后才落回旧解析器算出 42、才轮到写库那一步。这不是挂钟等待，是假时钟，
///          确定性不受影响；`pumpAndSettle` 单独用它推不动这条链（没有新的帧要画，它不动时钟）。
/// English: **the real button path**: `More...` → "Edit expression" → the paste button → wait out the
///          paste receipt → `More...` → "Save note". The caller passes the two labels in the language of
///          the moment.
///
///          Both waits are required, for different reasons:
///          1. those 5 seconds for the paste receipt — a `ScaffoldMessenger` shows one at a time, so
///             without letting it run out the save receipt would queue behind it and the screen would
///             still carry the old sentence;
///          2. the clock must also be pushed past `engineTimeout` (5 seconds) for the save step —
///             `saveToNote()`'s `await` asks the engine (the pasted 42 has no computed result yet) and
///             nobody answers on a fake channel, so **this outcome in a test means "wait for the
///             timeout"**: only once the clock is past it does the legacy parser compute 42 and the
///             write step get its turn. This is fake-clock time, not wall-clock waiting, so
///             determinism is untouched; `pumpAndSettle` alone cannot drive this chain (with no new
///             frames to draw it does not move the clock).
Future<void> _pasteCurrentValueThenSaveNote(
  WidgetTester tester, {
  required String editExpression,
  required String pasteTooltip,
  required String saveNote,
}) async {
  await tester.tap(find.text('More...'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(editExpression));
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip(pasteTooltip));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();

  // 中文：编辑器还拿着焦点，先把焦点放掉再开面板——与 `calculator_page_test.dart` 里那条同形。
  // English: the editor still holds focus; release it before opening the sheet — the same shape as the
  //          case in `calculator_page_test.dart`.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();

  await tester.tap(find.text('More...'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(saveNote));
  await tester.pump();
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// 中文：被测主屏，与 `calculator_submit_message_test.dart` 里那份同形（同一组设置：不恢复状态、
///       不自动存历史、无触感），只多一个可选的语言作用域。**作用域装在 `builder:` 上**——与
///       `app.dart` 逐字同一个挂点（`builder` 的 child 就是 Navigator）。回执那句话由页面自己的
///       context 取（`CalculatorStrings.of`），它就在这条作用域之下。
/// English: the screen under test, the same shape as the one in `calculator_submit_message_test.dart`
///          (same settings: no state restore, no auto-save, no haptics) plus an optional language
///          scope. **The scope sits on `builder:`** — the very hook `app.dart` uses (`builder`'s child
///          *is* the Navigator). The receipt's words are fetched from the page's own context
///          (`CalculatorStrings.of`), which sits below this scope.
Future<void> _pumpCalculator(WidgetTester tester, {AppLanguage? language}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    builder: language == null
        ? null
        : (context, child) =>
            AppLanguageScope(language: language, child: child!),
    home: Scaffold(
      body: CalculatorPage(
        db: _ZeroWriteDatabase(),
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
  ));
  await tester.pumpAndSettle();
}

/// 中文：假库：设置读写作答，**笔记写回恒返 0**——`notesRepository.create` 拿到的 id ≤ 0 就是
///       `notWritten`，这条接线唯一有 `SnackBar` 的那一格里最便宜的一个（不必让写库抛错）。
/// English: the fake database: settings read and write honestly while **every note write returns 0** —
///          an id ≤ 0 out of `notesRepository.create` means `notWritten`, the cheapest of the outcomes
///          that speak on this wire (no need to make the write throw).
class _ZeroWriteDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<int> addNote(String title, String body,
      {String description = '', List<String> tags = const []}) async {
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
