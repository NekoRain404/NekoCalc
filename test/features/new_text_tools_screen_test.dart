import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_detail_screen.dart';

/// 中文：**三个新工具在界面上真的点得到。**
///
///       ⚠️ **这一组补的是一层别的测试够不着的洞。** 那三个工具：
///
///       - **控制器层**有测试（`toolId` → `TextToolController.calculate` → 断言输出）；
///       - **注册**有护栏（目录表、名字表、描述表、字段表、两张源码白名单）；
///       - **源码可达性**有护栏（`math_reachability_test.dart`）。
///
///       而**注册链上任何一环漏了**（目录条目、`textToolIds`、分派 `switch`），
///       上面那些照样全绿——**因为没有一条测试是从"用户点进去"那一步开始的。**
///
///       **这不是假想的风险**：本会话我写 `arithmetic_steps` 时**写完就忘了接出去**，
///       放了一整轮才被一条手写的 `grep` 发现。源码层那条护栏现在挡得住那种；
///       **而"注册了但屏幕上什么都没有"这一种，只有从屏幕出发才测得到。**
///
///       每条的做法：用 id 拿到工具 → 建 `TextToolDetailScreen` → 输入 → **断言结果出现在屏幕上**。
///       `db` 用一个只有 `getSettings` 有意义的替身（其余 `noSuchMethod` 兜住），
///       与 `tool_detail_screen_test.dart` 里那个替身同形但**只留这里用得上的那一件**。
/// English: **the three new tools can actually be reached on screen.**
///
///          ⚠️ **This fills a hole nothing else reaches.** Those tools have controller-level tests and are
///          covered by the registration guards plus the source-reachability guard — **but if any link in
///          the registration chain is missing** (catalogue entry, `textToolIds`, the dispatch `switch`),
///          all of those stay green, **because no test starts from "the user opened it".**
///
///          **That is not a hypothetical risk**: this session I wrote `arithmetic_steps` and **forgot to
///          wire it up**, and it sat a whole round until a hand-written `grep` found it. The source-level
///          guard now stops that kind; **"registered but nothing on screen" is only visible from the
///          screen.**
class _SettingsOnlyDatabase implements AppDatabase {
  final Completer<Map<String, String>> _completer =
      Completer<Map<String, String>>()..complete(const {});

  /// 中文：屏幕启动时要读一次设置（草稿那一类）。这里给一份空的——
  ///       **本组测的是"结果有没有出现在屏幕上"，不是草稿。**
  /// English: the screen reads the settings once on start (drafts and the like). An empty map here —
  ///          **what this group measures is "did the result appear on screen", not drafts.**
  @override
  Future<Map<String, String>> settings() => _completer.future;

  /// 中文：屏幕还会顺手写点东西（草稿一类），它们的返回类型是 `Future<void>`——
  ///       替身给一个已经完成的 future，而不是 `null`（`null` 不是那个类型）。
  /// English: the screen also writes things along the way (drafts and such) with a `Future<void>` return;
  ///          the double hands back a completed future rather than `null`, which is not that type.
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Future<void> _openAndType(WidgetTester tester, String toolId, String input) async {
  final tool = toolCatalog.firstWhere((item) => item.id == toolId);
  await tester.pumpWidget(MaterialApp(
    home: TextToolDetailScreen(
      db: _SettingsOnlyDatabase(),
      tool: tool,
      settings: AppSettings.fallback,
    ),
  ));
  await tester.pump();
  await tester.enterText(find.byType(TextField).first, input);
  await tester.pump(const Duration(milliseconds: 320));
}

void main() {
  testWidgets('get → 质因数分解：屏幕上出现 `2^6 × 3 × 643`', (tester) async {
    await _openAndType(tester, 'prime_factor', '123456');
    expect(find.textContaining('2^6 × 3 × 643'), findsWidgets,
        reason: '工具注册了却点不到，就是这一条红——而别的测试都够不着这一步');
  });

  testWidgets('get → 求导分步：屏幕上出现法则与结果', (tester) async {
    await _openAndType(tester, 'derive_steps', 'x^2');
    expect(find.textContaining('2·x'), findsWidgets);
  });

  testWidgets('get → 算术分步：屏幕上出现每一步', (tester) async {
    await _openAndType(tester, 'arithmetic_steps', '1 + 2 * 3');
    expect(find.textContaining('1 + 6'), findsWidgets);
  });
}
