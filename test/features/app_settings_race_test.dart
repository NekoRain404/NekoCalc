import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/app.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('stale startup settings load does not overwrite newer reload',
      (tester) async {
    final startupSettings = Completer<Map<String, String>>();
    final settingsReload = Completer<Map<String, String>>();
    final db = _QueuedAppSettingsDatabase(
      settingsLoads: [startupSettings.future, settingsReload.future],
    );

    await tester.pumpWidget(NekoCalcApp(db: db));
    await tester.pump();
    expect(_materialApp(tester).themeMode, ThemeMode.system);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SettingsTile, '主题模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pump();

    settingsReload.complete(const {'theme_mode': '浅色'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_materialApp(tester).themeMode, ThemeMode.light);

    startupSettings.complete(const {'theme_mode': '深色'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(_materialApp(tester).themeMode, ThemeMode.light);
  });
}

MaterialApp _materialApp(WidgetTester tester) {
  return tester.widget<MaterialApp>(find.byType(MaterialApp));
}

class _QueuedAppSettingsDatabase implements AppDatabase {
  _QueuedAppSettingsDatabase(
      {required List<Future<Map<String, String>>> settingsLoads})
      : _settingsLoads = List.of(settingsLoads);

  final List<Future<Map<String, String>>> _settingsLoads;
  final savedSettings = <String, String>{};

  @override
  Future<Map<String, String>> settings() {
    if (_settingsLoads.isNotEmpty) return _settingsLoads.removeAt(0);
    return Future.value(Map<String, String>.from(savedSettings));
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  Future<Map<String, int>> backupTableCounts() async {
    return const {
      'calculation_history': 0,
      'notes': 0,
      'favorite_tools': 0,
      'recent_tools': 0,
      'app_settings': 0,
    };
  }

  @override
  Future<Set<String>> favoriteToolIds() async {
    return const {};
  }

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async {
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
