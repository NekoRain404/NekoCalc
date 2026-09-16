import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/notes/presentation/notes_page.dart';
import 'package:nekocalc/features/tools/presentation/tools_home_page.dart';
import 'package:nekocalc/shared/presentation/app_shell.dart';

Widget _app() => MaterialApp(
      home: AppShell(
        db: _FakeDatabase(),
        settings: const AppSettings(
          haptics: false,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: false,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
        ),
        onSettingsChanged: () async {},
        onThemeModeChanged: (_) {},
      ),
    );

void main() {
  testWidgets('主屏没有底部导航栏', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('点 ☰ 后抽屉出现且含四个入口', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    expect(find.text('工具'), findsWidgets);
    expect(find.text('笔记'), findsWidgets);
    expect(find.text('历史'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('点抽屉里的「笔记」后笔记页可见', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();
    expect(find.text('笔记'), findsWidgets);
  });

  testWidgets('点抽屉里的「历史」后笔记页可见', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史').last);
    await tester.pumpAndSettle();
    expect(find.byType(NotesPage), findsOneWidget);
    expect(find.byType(NotesPage).hitTestable(), findsOneWidget);
  });

  testWidgets('点抽屉里的「工具」后工具页可见', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工具').last);
    await tester.pumpAndSettle();
    expect(find.byType(ToolsHomePage), findsOneWidget);
    expect(find.byType(ToolsHomePage).hitTestable(), findsOneWidget);
  });

  // 中文：Task 4 给计算页留了 `onNavigate`，外壳不接的话 HISTORY / CNST / CONV 与四个进制胶囊
  //       在真实 App 里永远是死的；这组测试守住这条接线。
  // English: Task 4 left `onNavigate` on the calculator page; unless the shell wires it, HISTORY /
  //          CNST / CONV and the four base pills stay dead in the real app. These tests guard it.
  group('计算页的页面级导航接线', () {
    testWidgets('onNavigate 收到 tools 切到工具页', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final page = tester.widget<CalculatorPage>(find.byType(CalculatorPage));
      expect(page.onNavigate, isNotNull, reason: '外壳必须接上 onNavigate');
      page.onNavigate!('tools');
      await tester.pumpAndSettle();
      expect(find.byType(ToolsHomePage), findsOneWidget);
      expect(find.byType(ToolsHomePage).hitTestable(), findsOneWidget);
    });

    testWidgets('onNavigate 收到 history 切到笔记页', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final page = tester.widget<CalculatorPage>(find.byType(CalculatorPage));
      expect(page.onNavigate, isNotNull, reason: '外壳必须接上 onNavigate');
      page.onNavigate!('history');
      await tester.pumpAndSettle();
      expect(find.byType(NotesPage), findsOneWidget);
      expect(find.byType(NotesPage).hitTestable(), findsOneWidget);
    });

    testWidgets('点 CNST 键把主屏切到工具页', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('CNST'), findsOneWidget);
      await tester.tap(find.text('CNST'));
      await tester.pumpAndSettle();
      expect(find.byType(ToolsHomePage), findsOneWidget);
    });

    testWidgets('点 HISTORY 键把主屏切到笔记页', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('HISTORY'), findsOneWidget);
      await tester.tap(find.text('HISTORY'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesPage), findsOneWidget);
    });
  });
}

class _FakeDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  // 中文：工具页首帧会读它自己的收藏与最近使用，导航测试必须让这一步有个空结果，
  //       否则切到工具页时会在 `initState` 里抛 NoSuchMethodError。
  // English: The toolbox page reads its favourites and recents on first frame; the navigation tests
  //          need those to answer empty, otherwise switching to it throws from `initState`.
  @override
  Future<Set<String>> favoriteToolIds() async => const {};

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
