import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/entities/tool_category.dart';
import 'package:nekocalc/features/tools/presentation/tool_category_screen.dart';

void main() {
  testWidgets('category empty search offers typo suggestions', (tester) async {
    final db = _QueuedCategoryDatabase(
      favoriteLoads: const [],
      favoriteWrites: const [],
    );
    const settings = AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: false,
      autoSaveHistory: true,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    );

    await tester.pumpWidget(MaterialApp(
      home: ToolCategoryScreen(
        db: db,
        category: ToolCategory.electronics,
        favoriteIds: const {},
        settings: settings,
      ),
    ));

    await tester.enterText(find.byType(TextField), 'volatge');
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('${ToolCategory.electronics.title}里没有“volatge”。'),
      findsOneWidget,
    );
    expect(find.widgetWithIcon(ActionChip, Icons.manage_search), findsWidgets);

    await tester.tap(find.text('voltage').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('搜索结果 · 0'), findsNothing);
    expect(find.text('欧姆定律'), findsOneWidget);
  });

  testWidgets('stale category favorite reload does not overwrite newer toggle',
      (tester) async {
    final staleReload = Completer<Set<String>>();
    final toggleWrite = Completer<void>();
    final toggleReload = Completer<Set<String>>();
    final db = _QueuedCategoryDatabase(
      favoriteLoads: [
        Future.value(const <String>{}),
        staleReload.future,
        toggleReload.future,
      ],
      favoriteWrites: [toggleWrite.future],
    );
    const settings = AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: false,
      autoSaveHistory: true,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    );

    await tester.pumpWidget(MaterialApp(
      home: ToolCategoryScreen(
        db: db,
        category: ToolCategory.electronics,
        favoriteIds: const {},
        settings: settings,
      ),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '欧姆');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('欧姆定律'));
    await tester.pumpAndSettle();
    expect(find.text('欧姆定律'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('收藏').first);
    await tester.pump();

    staleReload.complete(const {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    toggleWrite.complete();
    await tester.pump();
    toggleReload.complete({'ohms_law'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final ohmsLawTile = find.ancestor(
      of: find.text('欧姆定律'),
      matching: find.byType(ListTile),
    );
    final favoriteButton = tester.widget<IconButton>(
      find.descendant(
        of: ohmsLawTile,
        matching: find.byType(IconButton),
      ),
    );
    final favoriteIcon = favoriteButton.icon as Icon;
    expect(favoriteIcon.icon, Icons.star);
    expect(favoriteIcon.color, Colors.amber);
  });
}

class _QueuedCategoryDatabase implements AppDatabase {
  _QueuedCategoryDatabase({
    required List<Future<Set<String>>> favoriteLoads,
    required List<Future<void>> favoriteWrites,
  })  : _favoriteLoads = List.of(favoriteLoads),
        _favoriteWrites = List.of(favoriteWrites);

  final List<Future<Set<String>>> _favoriteLoads;
  final List<Future<void>> _favoriteWrites;

  @override
  Future<Set<String>> favoriteToolIds() {
    if (_favoriteLoads.isEmpty) return Future.value(const {});
    return _favoriteLoads.removeAt(0);
  }

  @override
  Future<void> setFavorite(String toolId, bool favorite) {
    if (_favoriteWrites.isEmpty) return Future.value();
    return _favoriteWrites.removeAt(0);
  }

  @override
  Future<void> markRecent(String toolId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
