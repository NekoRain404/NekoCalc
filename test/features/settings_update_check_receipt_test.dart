import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/update/github_release_checker.dart';
import 'package:nekocalc/core/platform/app_link_channel.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/settings/presentation/settings_page.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**检查更新回执上屏的那一段接线（设置页那一屏）。**
///
///       `UpdateCheckResult` 只留令牌（`UpdateCheckOutcome` 六格）与载荷，六句话住在
///       `SettingsStrings` 里，由 `updateCheckMessage` 在呈现边缘取——设置页「检查更新」对话框那行
///       正文（`settings_page.dart`）就这么印。组合器本身由 `test/features/update_check_message_test.dart`
///       单独钉住（六格逐条渲染、英文表逐条量、源码扫描），**证明不了「屏幕真的用了它」**；
///       `settings_update_feedback_test.dart` 那条「发现新版本 …」量的是**默认中文**那一半，
///       英文作用域下一条都没有（`docs/verification.md` §5n）。
///
///       这一条量的就是那根线：英文作用域挂上去，点「检查更新」让对话框真的弹出来，屏幕上的字
///       必须是英文。少了它，「组合器改了、对话框那处没接上」（或取的不是作用域里那张表）会原样
///       留在真实应用里，而所有测试全绿。
///
///       **假 HTTP 客户端返回一份公开版本是最容易确定性触发的那一格**（`updateAvailable`）：
///       不经引擎往返，版本号是我们自己写死的那一个，一次点击就有对话框。
///
///       屏幕跑在默认设置上，语言只由作用域决定；作用域挂在 `builder:` 上，与 `app.dart` 逐字
///       同一个挂点——否则 `showDialog` 压上来的对话框看不见它。
/// English: **the wiring that puts an update-check receipt on screen (the settings page).**
///
///          `UpdateCheckResult` keeps only the token (`UpdateCheckOutcome`, six values) and the
///          payload; the six sentences live in `SettingsStrings` and are fetched at the presentation
///          edge by `updateCheckMessage` — which is how the "Check for updates" dialog's body line
///          (`settings_page.dart`) prints. The composer itself is pinned on its own in
///          `test/features/update_check_message_test.dart` (all six rendered, the English table
///          measured, the source swept) — **it cannot prove "the screen really used it"**; the
///          "发现新版本 …" case in `settings_update_feedback_test.dart` measures the **default Chinese**
///          half, and the English scope had not one case (`docs/verification.md` §5n).
///
///          What this measures is that wire: with an English scope installed, tapping "Check for
///          updates" must raise that dialog with English words on it. Without it, "the composer was
///          fixed but the dialog was never wired" (or is wired to some other language's table) would
///          survive in the real app with every test green.
///
///          **A fake HTTP client returning one public release is the easiest outcome to trigger
///          deterministically** (`updateAvailable`): no engine round trip, the version number is one we
///          wrote ourselves, and one tap yields the dialog.
///
///          The screen runs on the default settings; the language is decided by the scope alone,
///          mounted on `builder:` — the very hook `app.dart` uses, or the `showDialog` route would
///          not see it.
void main() {
  testWidgets('英文界面：检查更新的回执是英文', (tester) async {
    final links = _FakeAppLinkOpener();
    final checker = GithubReleaseChecker(client: _FakeReleaseHttpClient());

    await _pumpSettings(tester, checker: checker, links: links,
        language: AppLanguage.en);

    await _scrollToAndTap(tester, find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Version v1.2.0-beta.2 is available.'), findsOneWidget,
        reason: '屏幕上没有这句英文回执——组合器与对话框之间那根线断了，或者取的不是作用域里那张表');
    expect(find.text('发现新版本 v1.2.0-beta.2。'), findsNothing,
        reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');
  });

  testWidgets('默认（中文）界面：同一个动作报的还是原来那句话', (tester) async {
    // 中文：没有作用域时回落到中文——这是仓库那条「默认态与接入前逐字节相同」在屏幕上的又一份证据。
    // English: with no scope the language falls back to Chinese — another piece of on-screen evidence
    //          for this repository's "the default state stays byte-identical" rule.
    final links = _FakeAppLinkOpener();
    final checker = GithubReleaseChecker(client: _FakeReleaseHttpClient());

    await _pumpSettings(tester, checker: checker, links: links);

    await _scrollToAndTap(tester, find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 v1.2.0-beta.2。'), findsOneWidget);
  });
}

/// 中文：设置页那一屏，加一个可选的语言作用域。滚到目标再点：设置页那几节落在测试视口
///       （800×600）之下，`scrollUntilVisible` 末尾不 pump，点会落在滚动前的坐标上。
/// English: the settings page plus an optional language scope. Scroll to the target, then tap: those
///          sections sit below the test viewport (800×600) and `scrollUntilVisible` does not pump at
///          the end, so a bare tap would use the pre-scroll position.
Future<void> _pumpSettings(
  WidgetTester tester, {
  required GithubReleaseChecker checker,
  required AppLinkOpener links,
  AppLanguage? language,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    builder: language == null
        ? null
        : (context, child) =>
            AppLanguageScope(language: language, child: child!),
    home: SettingsPage(
      db: _SettingsDatabase(),
      updateChecker: checker,
      appLinkOpener: links,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300,
      scrollable: find.byType(Scrollable));
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// 中文：一份公开版本的 JSON——`updateAvailable` 那一格。载荷（版本号）写死在测试里。
/// English: one public release's JSON — the `updateAvailable` cell. The payload (the version
///          number) is written out in the test.
class _FakeReleaseHttpClient implements ReleaseHttpClient {
  @override
  Future<ReleaseHttpResponse> get(Uri uri) async {
    return ReleaseHttpResponse(
      statusCode: 200,
      body: jsonEncode([
        {
          'tag_name': 'v1.2.0-beta.2',
          'html_url':
              'https://github.com/NekoRain404/NekoCalc/releases/tag/v1.2.0-beta.2',
          'prerelease': true,
          'draft': false,
        },
      ]),
    );
  }
}

class _FakeAppLinkOpener implements AppLinkOpener {
  @override
  Future<bool> openExternalUrl(String url) async => true;
}

class _SettingsDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {'haptics': 'false'};

  @override
  Future<Map<String, int>> backupTableCounts() async => const {
        'calculation_history': 0,
        'notes': 0,
        'favorite_tools': 0,
        'recent_tools': 0,
        'app_settings': 0,
      };

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
