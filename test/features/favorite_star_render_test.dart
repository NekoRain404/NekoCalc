import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/tools/presentation/tool_widgets.dart';
import 'package:nekocalc/features/tools/presentation/tools_home_page.dart';
import 'package:nekocalc/shared/presentation/app_theme.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

/// 中文：**收藏星画的是那个语义色。**
///
///       钉的是 §5t 那条决定 ✓：收藏星用**语义色**（`favoriteStarColor` = 琥珀 ✓），而不是每套调色板
///       各给一个主题色 ✓。**为什么渲染 `lavenderMist`** ✓：琥珀在玫瑰奶霜里本来就不突兀 ✓，
///       这条决定的**唯一考验**是它在冷调主题里看着像不像"另一样东西" ✗ —— 而那一看**已经做过** ✓
///       （2026-10-12：读作"被标记出来的重点" ✓，见 `docs/verification.md` §5t）。
///
///       ⚠️ **出图那一步不入断言** ✓（图能给人看，不能给程序判 ✓）；断言是 `color == favoriteStarColor` ✓。
///
///       ⚠️ **四次尝试留下的四条经验，都写在这里：**
///       ① 假 `AppDatabase` 必须实现页面经 `ToolUsageRepository` await 的**全部六个**方法 ✓；
///       ② 结束前**卸载页面**（主屏有 70 ms 搜索防抖计时器 ✓）；
///       ③ **不能用 `pumpAndSettle`**（其文档禁止在有计时器挂着时调用 ✓），改两次有界 pump ✓；
///       ④ ⚠️ **出图那半必须放进 `tester.runAsync`** ✓ —— `toImage` / `toByteData` 是 `dart:ui` 的
///          future，留在假时钟里会把之后的收尾卡死（前三次都是这个形状：**图写出来了、然后挂住、连
///          `--timeout` 都不响** ✓）。
/// English: **the favourite star is drawn in that semantic colour.**
///
///          It pins §5t's decision: a **semantic** colour (`favoriteStarColor` = amber), not a per-palette
///          theme colour. It renders `lavenderMist` because amber is unremarkable in Rose Cream — the only test
///          of that decision is a cool palette, and that look has already been taken (§5t).
///
///          ⚠️ **The PNG step is not an assertion.** ⚠️ **Four lessons from four attempts:** (1) the fake must
///          implement all **six** methods the page awaits; (2) **unmount the page** before finishing; (3)
///          **never `pumpAndSettle`** here — its own documentation forbids it while a timer is pending; (4)
///          **the image half must run inside `tester.runAsync`** — `toImage` / `toByteData` are `dart:ui`
///          futures, and leaving them in the fake clock wedges teardown afterwards (the previous three attempts
///          all had that shape: **the PNG was written, then it hung, and not even `--timeout` fired**).
void main() {
  testWidgets('收藏星在紫罗兰主题里画的仍是那个语义色（并出图一张供人看）', (tester) async {
    final db = _StarDatabase(favorites: {'ohms_law'});
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        theme: AppTheme.light(CalcTheme.lavenderMist),
        home: Scaffold(
          body: ToolsHomePage(db: db, settings: AppSettings.fallback),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final stars = find.byIcon(Icons.star);
    expect(stars, findsWidgets, reason: '屏上一个收藏星都没有，这条测试的前提就不成立');
    for (final icon in tester.widgetList<Icon>(stars)) {
      expect(icon.color, favoriteStarColor,
          reason: '收藏星必须画 `favoriteStarColor`（语义琥珀）——被某套调色板的主题色替换掉，'
              '就等于 §5t 那条决定被悄悄推翻了');
    }

    // 中文：**出图那半放进 `runAsync`** ✓（见文件头第 ④ 条）——`dart:ui` 的 future 要留在假时钟之外。
    //       写到 /tmp，不进仓库；出图**不入断言** ✓。
    // English: **the image half goes inside `runAsync`** (note ④) — `dart:ui` futures belong outside the fake
    //          clock. Written to /tmp, not into the repository; the PNG is **not** an assertion.
    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/nekocalc_lavender_favourite.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

/// 中文：**六个方法全实现** ✓（页面经 `ToolUsageRepository` await 的就是这六个 ✓）；
///       其余交给 `noSuchMethod`——本仓库既有写法 ✓。
/// English: **all six methods** — the set the page awaits through `ToolUsageRepository`;
///          `noSuchMethod` covers the rest, as elsewhere in this repository.
class _StarDatabase implements AppDatabase {
  _StarDatabase({required this.favorites});

  final Set<String> favorites;

  @override
  Future<Set<String>> favoriteToolIds() async => favorites;

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async => const [];

  @override
  Future<int> setFavorite(String toolId, bool favorite) async => 1;

  @override
  Future<int> markRecent(String toolId) async => 1;

  @override
  Future<int> deleteRecentTool(String toolId) async => 1;

  @override
  Future<int> clearRecentTools() async => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
