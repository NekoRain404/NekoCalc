import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/backup_snapshot_validator.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/settings/presentation/settings_page.dart';

void main() {
  const backupChannel = MethodChannel('nekocalc/backup_file');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backupChannel, null);
  });

  testWidgets('empty backup import disables destructive replace action',
      (tester) async {
    final db = _FakeSettingsDatabase({
      'calculation_history': 2,
      'notes': 1,
      'favorite_tools': 0,
      'recent_tools': 1,
      'app_settings': 3,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backupChannel, (call) async {
      if (call.method == 'importJson') {
        return _snapshotJson({
          for (final tableName in backupTableNames) tableName: 0,
        });
      }
      return null;
    });

    await tester.pumpWidget(MaterialApp(home: SettingsPage(db: db)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('导入恢复'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.drag(find.byType(Scrollable), const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入恢复'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(emptyBackupReplaceErrorMessage), findsWidgets);
    final replaceButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '覆盖恢复'),
    );
    expect(replaceButton.onPressed, isNull);

    await tester.tap(find.widgetWithText(TextButton, '合并导入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(db.importCallCount, 1);
    expect(db.replaceExisting, isFalse);
    expect(db.counts['calculation_history'], 2);
    expect(db.counts['notes'], 1);
  });

  testWidgets('replace import preview shows destructive table impacts',
      (tester) async {
    final db = _FakeSettingsDatabase({
      'calculation_history': 4,
      'notes': 2,
      'favorite_tools': 1,
      'recent_tools': 1,
      'app_settings': 2,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backupChannel, (call) async {
      if (call.method == 'importJson') {
        return _snapshotJson({
          'calculation_history': 1,
          'notes': 0,
          'favorite_tools': 0,
          'recent_tools': 1,
          'app_settings': 1,
        });
      }
      return null;
    });

    await tester.pumpWidget(MaterialApp(home: SettingsPage(db: db)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('导入恢复'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.drag(find.byType(Scrollable), const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入恢复'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('笔记 将删除本机 2 条'), findsOneWidget);
    expect(find.text('收藏 将删除本机 1 条'), findsOneWidget);
    expect(find.text('历史 将减少 3 条'), findsOneWidget);
    expect(find.text('会覆盖本机历史、最近工具、设置数据'), findsOneWidget);
    expect(
      find.textContaining('会保留本机数据，并尝试加入 历史 +1、最近工具 +1、设置 +1'),
      findsOneWidget,
    );
  });

  testWidgets('merge import result reports retained and skipped backup rows',
      (tester) async {
    final db = _FakeSettingsDatabase({
      'calculation_history': 490,
      'notes': 1,
      'favorite_tools': 0,
      'recent_tools': 20,
      'app_settings': 0,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backupChannel, (call) async {
      if (call.method == 'importJson') {
        return _snapshotJson({
          'calculation_history': 40,
          'notes': 2,
          'favorite_tools': 0,
          'recent_tools': 10,
          'app_settings': 0,
        });
      }
      return null;
    });

    await tester.pumpWidget(MaterialApp(home: SettingsPage(db: db)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('导入恢复'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.drag(find.byType(Scrollable), const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入恢复'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(TextButton, '合并导入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('合并导入完成：已合并 16 条记录，跳过或裁剪 36 条'), findsOneWidget);
    await tester.tap(find.text('详情'));
    await tester.pumpAndSettle();

    expect(find.textContaining('结果：已合并 16 条记录，跳过或裁剪 36 条'), findsOneWidget);
    expect(find.textContaining('历史：文件 40，导入前 490，导入后 500，变化 +10，跳过/裁剪 30'),
        findsOneWidget);
    expect(find.textContaining('最近工具：文件 10，导入前 20，导入后 24，变化 +4，跳过/裁剪 6'),
        findsOneWidget);
  });

  testWidgets('delayed settings load does not overwrite local toggle',
      (tester) async {
    final settingsCompleter = Completer<Map<String, String>>();
    final db = _FakeSettingsDatabase(
      {
        'calculation_history': 0,
        'notes': 0,
        'favorite_tools': 0,
        'recent_tools': 0,
        'app_settings': 0,
      },
      settingsCompleter: settingsCompleter,
    );

    await tester.pumpWidget(MaterialApp(home: SettingsPage(db: db)));
    await tester.pump();

    await tester.tap(find.widgetWithText(SwitchTile, '记住上次状态'));
    await tester.pump();
    expect(db.savedSettings['restore_state'], 'false');

    settingsCompleter.complete(const {
      'haptics': 'true',
      'restore_state': 'true',
      'auto_save': 'true',
      'theme_mode': '跟随系统',
      'angle_mode': '弧度',
      'digits': '6 位',
      'expression_display': '数学符号',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final restoreTile = tester.widget<SwitchTile>(
      find.widgetWithText(SwitchTile, '记住上次状态'),
    );
    expect(restoreTile.value, isFalse);
    expect(db.savedSettings['restore_state'], 'false');
  });

  testWidgets('stale local backup preview does not overwrite refresh',
      (tester) async {
    final firstCounts = Completer<Map<String, int>>();
    final secondCounts = Completer<Map<String, int>>();
    final db = _FakeSettingsDatabase(
      {
        'calculation_history': 0,
        'notes': 0,
        'favorite_tools': 0,
        'recent_tools': 0,
        'app_settings': 0,
      },
      backupCountLoads: [firstCounts, secondCounts],
    );

    await tester.pumpWidget(MaterialApp(home: SettingsPage(db: db)));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('本机数据'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('刷新数据统计'));
    await tester.pump();

    secondCounts.complete({
      'calculation_history': 3,
      'notes': 2,
      'favorite_tools': 0,
      'recent_tools': 0,
      'app_settings': 0,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('5 条记录'), findsWidgets);

    firstCounts.complete({
      'calculation_history': 20,
      'notes': 0,
      'favorite_tools': 0,
      'recent_tools': 0,
      'app_settings': 0,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('5 条记录'), findsWidgets);
    expect(find.text('20 条记录'), findsNothing);
  });

  testWidgets('backup import applies restored settings to current UI',
      (tester) async {
    String? themeMode;
    final db = _FakeSettingsDatabase({
      'calculation_history': 1,
      'notes': 1,
      'favorite_tools': 0,
      'recent_tools': 0,
      'app_settings': 3,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backupChannel, (call) async {
      if (call.method == 'importJson') {
        return _snapshotJson({
          for (final tableName in backupTableNames)
            tableName: tableName == 'app_settings' ? 4 : 0,
        });
      }
      return null;
    });

    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        db: db,
        onThemeModeChanged: (value) => themeMode = value,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('6 位'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('导入恢复'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.drag(find.byType(Scrollable), const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入恢复'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(FilledButton, '覆盖恢复'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(db.importCallCount, 1);
    expect(db.replaceExisting, isTrue);
    expect(themeMode, '深色');
    await tester.scrollUntilVisible(
      find.text('外观设置'),
      -300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('深色'), findsOneWidget);
    expect(find.text('8 位'), findsOneWidget);
    expect(find.text('角度'), findsOneWidget);
  });
}

String _snapshotJson(Map<String, int> counts) {
  return jsonEncode({
    'schema': backupSchemaVersion,
    'exported_at': '2026-06-08T10:00:00.000',
    'metadata': {'app_version': 'v1.1.0'},
    'tables': {
      for (final tableName in backupTableNames)
        tableName: _rowsForTable(tableName, counts[tableName] ?? 0),
    },
  });
}

List<Map<String, Object?>> _rowsForTable(String tableName, int count) {
  return List.generate(count, (index) {
    final id = index + 1;
    final timestamp = 1000 + index;
    return switch (tableName) {
      'calculation_history' => {
          'id': id,
          'expression': '2+$id',
          'result': '${2 + id}',
          'tool_id': null,
          'created_at': timestamp,
        },
      'notes' => {
          'id': id,
          'title': '笔记 $id',
          'description': '描述 $id',
          'body': '内容 $id',
          'created_at': timestamp,
          'updated_at': timestamp + 1,
        },
      'favorite_tools' => {
          'tool_id': 'favorite_tool_$id',
          'created_at': timestamp,
        },
      'recent_tools' => {
          'tool_id': 'recent_tool_$id',
          'used_at': timestamp,
        },
      'app_settings' => {
          'key': _settingKeyForIndex(id),
          'value': _settingValueForIndex(id),
          'updated_at': timestamp,
        },
      _ => <String, Object?>{},
    };
  });
}

String _settingKeyForIndex(int id) {
  return switch (id) {
    1 => 'theme_mode',
    2 => 'digits',
    3 => 'angle_mode',
    4 => 'expression_display',
    _ => 'setting_$id',
  };
}

String _settingValueForIndex(int id) {
  return switch (id) {
    1 => '深色',
    2 => '8 位',
    3 => '角度',
    4 => '数学表达式',
    _ => 'value_$id',
  };
}

class _FakeSettingsDatabase implements AppDatabase {
  _FakeSettingsDatabase(
    Map<String, int> counts, {
    Completer<Map<String, String>>? settingsCompleter,
    List<Completer<Map<String, int>>>? backupCountLoads,
  })  : counts = Map<String, int>.from(counts),
        _backupCountLoads = List.of(backupCountLoads ?? const []),
        _settingsCompleter = settingsCompleter;

  final Map<String, int> counts;
  final Completer<Map<String, String>>? _settingsCompleter;
  final List<Completer<Map<String, int>>> _backupCountLoads;
  final savedSettings = <String, String>{};
  final importedSettings = <String, String>{};
  bool? replaceExisting;
  int importCallCount = 0;

  @override
  Future<Map<String, String>> settings() async {
    final settingsCompleter = _settingsCompleter;
    if (settingsCompleter != null) return settingsCompleter.future;
    if (importedSettings.isNotEmpty) {
      return Map<String, String>.from(importedSettings);
    }
    return const {
      'haptics': 'false',
      'restore_state': 'true',
      'auto_save': 'true',
      'theme_mode': '跟随系统',
      'angle_mode': '弧度',
      'digits': '6 位',
      'expression_display': '数学符号',
    };
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  Future<Map<String, int>> backupTableCounts() async {
    if (_backupCountLoads.isNotEmpty) {
      return _backupCountLoads.removeAt(0).future;
    }
    return Map<String, int>.from(counts);
  }

  @override
  Future<void> importSnapshot(
    Map<String, Object?> snapshot, {
    bool replaceExisting = true,
  }) async {
    importCallCount += 1;
    this.replaceExisting = replaceExisting;
    final tables = snapshot['tables'] as Map;
    for (final tableName in backupTableNames) {
      final importedCount = (tables[tableName] as List).length;
      counts[tableName] = replaceExisting
          ? importedCount
          : (counts[tableName] ?? 0) + importedCount;
    }
    counts['calculation_history'] = (counts['calculation_history'] ?? 0).clamp(
      0,
      AppDatabase.maxHistoryRows,
    );
    counts['recent_tools'] = (counts['recent_tools'] ?? 0).clamp(
      0,
      AppDatabase.maxRecentToolRows,
    );
    final settingsRows = tables['app_settings'] as List;
    if (replaceExisting) importedSettings.clear();
    for (final row in settingsRows.cast<Map>()) {
      importedSettings[row['key'] as String] = row['value'] as String;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
