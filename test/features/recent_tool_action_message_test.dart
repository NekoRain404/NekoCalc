import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/tools/presentation/tools_home_page.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**最近使用回执上屏的那一段接线（工具首页那一屏）。**
///
///       `RecentToolActionResult` 只留令牌（`RecentToolActionStatus` × `RecentToolAction`）与载荷，
///       五句话住在 `ToolsStrings` 里，由 `recentToolActionMessage` 在呈现边缘取——工具首页
///       （`tools_home_page.dart`）的两处 `SnackBar` 都这么印。组合器本身由
///       `test/domain/recent_tool_action_result_test.dart` 单独钉住，文案表由
///       `tools_strings_test.dart` 逐格钉住——**两处都证明不了「屏幕真的用了它」**
///       （`docs/verification.md` §5n）。`tools_home_page_test.dart` 里那几条量的是列表状态与
///       「最近使用已清空」那块空面板（`recentEmpty`，不经 `recentToolActionMessage`），
///       **没有一条量过回执那句话**，也没有一条在英文作用域下跑。
///
///       这一条量的就是那根线：英文作用域挂上去，点「移除」与「清空」让那两条 `SnackBar` 真的
///       弹出来，屏幕上的字必须是英文。少了它，「组合器改了、屏幕上那处没接上」（或取的是别的
///       语言那张表）会原样留在真实应用里，而所有测试全绿。
///
///       **「写库抛错」是这条路上唯一会说话的那一格**（`failed`）：`_removeRecentTool` /
///       `_clearRecentTools` 只在 `!result.succeeded` 时弹 `SnackBar`（成功那四格静默改状态），
///       所以让假库抛一个固定的 `StateError('db locked')` 就是最便宜的确定性触发——不经引擎
///       往返，错误串也是我们自己的。
///
///       屏幕跑在 `AppSettings.fallback`（默认态）上，语言只由作用域决定；作用域挂在 `builder:`
///       上，与 `app.dart` 逐字同一个挂点。
/// English: **the wiring that puts a recently-used receipt on screen (the tools home screen).**
///
///          `RecentToolActionResult` keeps only the token (`RecentToolActionStatus` ×
///          `RecentToolAction`) and the payload; the five sentences live in `ToolsStrings` and are
///          fetched at the presentation edge by `recentToolActionMessage` — which is how the tools
///          home screen's (`tools_home_page.dart`) two `SnackBar`s print. The composer itself is pinned
///          on its own in `test/domain/recent_tool_action_result_test.dart` and the copy table cell by
///          cell in `tools_strings_test.dart` — **neither can prove "the screen really used it"**
///          (`docs/verification.md` §5n). What `tools_home_page_test.dart` measures is the list state
///          and the "recently used cleared" empty panel (`recentEmpty`, which does not go through
///          `recentToolActionMessage`); **not one test measures that receipt sentence**, and none runs
///          under an English scope.
///
///          What this measures is that wire: with an English scope installed, tapping Remove and Clear
///          must raise those two `SnackBar`s with English words on them. Without it, "the composer was
///          fixed but the site was never wired" (or is wired to some other language's table) would
///          survive in the real app with every test green.
///
///          **"The write throws" is the one cell on this road that speaks** (`failed`):
///          `_removeRecentTool` / `_clearRecentTools` only show a `SnackBar` when
///          `!result.succeeded` (the four success cells silently change state), so making the fake
///          database throw a fixed `StateError('db locked')` is the cheapest deterministic trigger —
///          no engine round trip, and the error string is ours.
///
///          The screen runs on `AppSettings.fallback` (the default state); the language is decided by
///          the scope alone, mounted on `builder:` — the very hook `app.dart` uses.
void main() {
  testWidgets('英文界面：最近使用的移除与清空回执都是英文', (tester) async {
    await _pumpToolsHome(tester, language: AppLanguage.en);

    await _tapManage(tester, 'Manage');
    await tester.tap(find.byTooltip('Remove from recently used').first);
    await tester.pumpAndSettle();

    expect(find.text('Could not remove from recently used: Bad state: db locked'),
        findsOneWidget,
        reason: '屏幕上没有这句英文回执——组合器与屏幕之间那根线断了，或者取的不是作用域里那张表');
    expect(find.text('移除最近使用失败：Bad state: db locked'), findsNothing,
        reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');

    // 中文：让第一条 SnackBar 自己走完（4 秒），第二条才排得上——`ScaffoldMessenger` 一次只显示一条。
    // English: let the first SnackBar run out (4 seconds) so the second can take its turn —
    //          a `ScaffoldMessenger` shows one at a time.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Could not clear recently used: Bad state: db locked'),
        findsOneWidget,
        reason: '清空那一格没有取作用域里的表');
    expect(find.text('清空最近使用失败：Bad state: db locked'), findsNothing,
        reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('默认（中文）界面：同一个动作报的还是原来那两句话', (tester) async {
    // 中文：没有作用域时回落到中文——这是仓库那条「默认态与接入前逐字节相同」在屏幕上的又一份证据。
    // English: with no scope the language falls back to Chinese — another piece of on-screen evidence
    //          for this repository's "the default state stays byte-identical" rule.
    await _pumpToolsHome(tester);

    await _tapManage(tester, '管理');
    await tester.tap(find.byTooltip('移除最近使用').first);
    await tester.pumpAndSettle();

    expect(find.text('移除最近使用失败：Bad state: db locked'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '清空'));
    await tester.pumpAndSettle();

    expect(find.text('清空最近使用失败：Bad state: db locked'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}

/// 中文：工具首页那一屏，加一个可选的语言作用域。**作用域装在 `builder:` 上**——与 `app.dart`
///       逐字同一个挂点（`builder` 的 child 就是 Navigator）；回执那句话由页面自己的 context 取
///       （`ToolsStrings.of`），它就在这条作用域之下。
/// English: the tools home screen plus an optional language scope. **The scope sits on `builder:`** —
///          the very hook `app.dart` uses (`builder`'s child *is* the Navigator). The receipt's words
///          are fetched from the page's own context (`ToolsStrings.of`), which sits below this scope.
Future<void> _pumpToolsHome(WidgetTester tester, {AppLanguage? language}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    builder: language == null
        ? null
        : (context, child) =>
            AppLanguageScope(language: language, child: child!),
    home: Scaffold(
      body: ToolsHomePage(
        db: _ThrowingToolUsageDatabase(),
        settings: AppSettings.fallback,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// 中文：打开「管理」那块最近使用面板。中英文各一次，调用方把当下的标签递进来。
/// English: opens the Manage (recently used) sheet; the caller passes the label of the moment.
Future<void> _tapManage(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// 中文：最近使用有两个条目（`json_format` / `data_fit`），读与清点照常答，**写回一律抛**——
///       `failed` 是这条路上唯一会说话的结局，也是这条接线唯一有 `SnackBar` 的分支。
/// English: two recently-used entries (`json_format` / `data_fit`); reads answer normally while
///          **every write throws** — `failed` is the one outcome on this road that speaks, and the
///          only branch of this wire that shows a `SnackBar`.
class _ThrowingToolUsageDatabase implements AppDatabase {
  @override
  Future<Set<String>> favoriteToolIds() async => const {};

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async =>
      const ['json_format', 'data_fit'];

  @override
  Future<int> deleteRecentTool(String toolId) async {
    throw StateError('db locked');
  }

  @override
  Future<int> clearRecentTools() async {
    throw StateError('db locked');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
