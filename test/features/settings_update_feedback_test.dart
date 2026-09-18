import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/update/github_release_checker.dart';
import 'package:nekocalc/core/platform/app_link_channel.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/settings/presentation/settings_page.dart';

/// 中文：滚到目标再点。设置页加了「主题配色」「语言」两行之后，这两个入口都落到了测试视口
///       （800×600）之下，而 `scrollUntilVisible` 末尾虽然会调 `Scrollable.ensureVisible`，
///       它**不 pump**：紧随其后的 `tap()` 于是拿着滚动前的坐标，点在了屏幕外。
///       这里补一次 pump 让新偏移落成新布局，再点。断言一个字没改。
/// English: Scroll to the target, then tap. After the settings page gained the 「主题配色」 and 「语言」
///          rows both entry points fell below the test viewport (800×600), and although
///          `scrollUntilVisible` ends by calling `Scrollable.ensureVisible`, it never pumps: the
///          `tap()` right after it therefore uses the pre-scroll position and lands off-screen. The
///          extra pump turns the new offset into a new layout before tapping. No assertion changed.
Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300,
      scrollable: find.byType(Scrollable));
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

void main() {
  testWidgets('opens the available GitHub release after an on-demand check',
      (tester) async {
    final links = _FakeAppLinkOpener();
    final client = _FakeReleaseHttpClient(jsonEncode([
      {
        'tag_name': 'v1.2.0-beta.2',
        'html_url':
            'https://github.com/NekoRain404/NekoCalc/releases/tag/v1.2.0-beta.2',
        'prerelease': true,
        'draft': false,
      },
    ]));
    final checker = GithubReleaseChecker(
      client: client,
    );

    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        db: _SettingsDatabase(),
        updateChecker: checker,
        appLinkOpener: links,
      ),
    ));
    await tester.pumpAndSettle();
    expect(client.requests, 0);

    await _scrollToAndTap(tester, find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(client.requests, 1);
    expect(find.text('发现新版本 v1.2.0-beta.2。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '查看发布'));
    await tester.pumpAndSettle();

    expect(links.openedUrls, [
      'https://github.com/NekoRain404/NekoCalc/releases/tag/v1.2.0-beta.2',
    ]);
  });

  testWidgets('copies a diagnostic report and opens a GitHub issue action',
      (tester) async {
    final links = _FakeAppLinkOpener();
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        db: _SettingsDatabase(),
        appLinkOpener: links,
      ),
    ));
    await tester.pumpAndSettle();

    await _scrollToAndTap(tester, find.text('帮助与反馈'));
    await tester.pumpAndSettle();

    expect(find.text('诊断报告'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '复制报告'));
    await tester.pump();
    expect(copiedText, contains('应用：NekoCalc'));
    expect(copiedText, contains('版本：v1.2.0-beta.1'));

    await tester.tap(find.widgetWithText(FilledButton, '提交 GitHub Issue'));
    await tester.pumpAndSettle();
    expect(links.openedUrls, [
      'https://github.com/NekoRain404/NekoCalc/issues/new/choose',
    ]);
  });
}

class _FakeReleaseHttpClient implements ReleaseHttpClient {
  _FakeReleaseHttpClient(this.body);

  final String body;
  int requests = 0;

  @override
  Future<ReleaseHttpResponse> get(Uri uri) async {
    requests++;
    return ReleaseHttpResponse(statusCode: 200, body: body);
  }
}

class _FakeAppLinkOpener implements AppLinkOpener {
  final openedUrls = <String>[];

  @override
  Future<bool> openExternalUrl(String url) async {
    openedUrls.add(url);
    return true;
  }
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
