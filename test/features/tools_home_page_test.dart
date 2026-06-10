import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/tools/presentation/tools_home_page.dart';

void main() {
  testWidgets('stale tools home reload does not overwrite newer state',
      (tester) async {
    final firstFavorites = Completer<Set<String>>();
    final firstRecent = Completer<List<String>>();
    final secondFavorites = Completer<Set<String>>();
    final secondRecent = Completer<List<String>>();
    final db = _QueuedToolUsageDatabase(
      favoriteLoads: [firstFavorites, secondFavorites],
      recentLoads: [secondRecent, firstRecent],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ToolsHomePage(
          db: db,
          settings: AppSettings.fallback,
        ),
      ),
    ));
    await tester.pump();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ToolsHomePage(
          db: db,
          settings: AppSettings.fallback,
          reloadToken: 1,
        ),
      ),
    ));
    await tester.pump();

    secondFavorites.complete({'loan'});
    secondRecent.complete(['data_fit']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('数据拟合图表'), findsWidgets);

    firstFavorites.complete({'json_format'});
    firstRecent.complete(['ohms_law']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('数据拟合图表'), findsWidgets);
    expect(find.text('欧姆定律'), findsNothing);
  });

  testWidgets('recent tools sheet removes a single item', (tester) async {
    final db = _MutableToolUsageDatabase(
      recentIds: ['json_format', 'data_fit'],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ToolsHomePage(
          db: db,
          settings: AppSettings.fallback,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('JSON格式化'), findsWidgets);
    expect(find.text('数据拟合图表'), findsWidgets);

    await tester.tap(find.text('管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移除最近使用').first);
    await tester.pumpAndSettle();

    expect(db.recentIds, ['data_fit']);
    expect(find.text('JSON格式化'), findsNothing);
    expect(find.text('数据拟合图表'), findsWidgets);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('推荐工具'), findsNothing);
    expect(find.text('最近使用'), findsOneWidget);
    expect(find.text('数据拟合图表'), findsWidgets);
  });

  testWidgets('recent tools sheet clears all items', (tester) async {
    final db = _MutableToolUsageDatabase(
      recentIds: ['json_format', 'data_fit'],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ToolsHomePage(
          db: db,
          settings: AppSettings.fallback,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '清空'));
    await tester.pumpAndSettle();

    expect(db.recentIds, isEmpty);
    expect(find.text('最近使用已清空。打开任意工具后会重新记录到这里。'), findsOneWidget);
    expect(find.text('JSON格式化'), findsNothing);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('推荐工具'), findsOneWidget);
  });

  testWidgets('empty search shows typo suggestions that can be applied',
      (tester) async {
    final db = _MutableToolUsageDatabase();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ToolsHomePage(
          db: db,
          settings: AppSettings.fallback,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'jsonn');
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pumpAndSettle();

    expect(find.text('没有找到“jsonn”的匹配工具。'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'json'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'json').first);
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pumpAndSettle();

    expect(find.text('JSON格式化'), findsWidgets);
    expect(find.text('没有找到“jsonn”的匹配工具。'), findsNothing);
  });
}

class _QueuedToolUsageDatabase implements AppDatabase {
  _QueuedToolUsageDatabase({
    required List<Completer<Set<String>>> favoriteLoads,
    required List<Completer<List<String>>> recentLoads,
  })  : _favoriteLoads = List.of(favoriteLoads),
        _recentLoads = List.of(recentLoads);

  final List<Completer<Set<String>>> _favoriteLoads;
  final List<Completer<List<String>>> _recentLoads;

  @override
  Future<Set<String>> favoriteToolIds() {
    if (_favoriteLoads.isEmpty) return Future.value(const {});
    return _favoriteLoads.removeAt(0).future;
  }

  @override
  Future<List<String>> recentToolIds({int limit = 8}) {
    if (_recentLoads.isEmpty) return Future.value(const []);
    return _recentLoads
        .removeAt(0)
        .future
        .then((ids) => ids.take(limit).toList(growable: false));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MutableToolUsageDatabase implements AppDatabase {
  _MutableToolUsageDatabase({
    Set<String> favoriteIds = const {},
    List<String> recentIds = const [],
  })  : favoriteIds = Set<String>.from(favoriteIds),
        recentIds = List<String>.from(recentIds);

  final Set<String> favoriteIds;
  final List<String> recentIds;

  @override
  Future<Set<String>> favoriteToolIds() async {
    return Set<String>.from(favoriteIds);
  }

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async {
    return recentIds.take(limit).toList(growable: false);
  }

  @override
  Future<int> deleteRecentTool(String toolId) async {
    final previousCount = recentIds.length;
    recentIds.removeWhere((id) => id == toolId);
    return previousCount - recentIds.length;
  }

  @override
  Future<int> clearRecentTools() async {
    final count = recentIds.length;
    recentIds.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
