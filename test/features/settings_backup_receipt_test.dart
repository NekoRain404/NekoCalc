import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/constants/app_info.dart';
import 'package:nekocalc/core/utils/backup_snapshot_validator.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/settings/presentation/settings_page.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**备份提示与导入影响上屏的那一段接线（设置页的导入恢复对话框）。**
///
///       校验器只留令牌（`BackupPreviewWarningKind` 八格），数据层只留令牌
///       （`BackupImportImpactKind` 十格）与载荷（表名、条数、上限），那些句子住在
///       `SettingsBackupStrings` 里，由 `backupPreviewWarningMessage` /
///       `backupImportImpactMessage` 在呈现边缘取——设置页导入对话框的「备份提示」块与影响清单
///       （`settings_backup_widgets.dart` 那两处）就这么印。组合器本身由
///       `test/features/settings_backup_messages_test.dart` 单独钉住（两种语言逐格渲染、源码扫描），
///       **证明不了「屏幕真的用了它」**。`settings_page_test.dart` 里那几条量的是**默认中文**的
///       影响清单（`'笔记 将删除本机 2 条'` 等）与阻止提示，英文作用域下一条都没有
///       （`docs/verification.md` §5n）。
///
///       这一条量的就是那根线：英文作用域挂上去，真的把导入对话框弹出来，屏幕上的字必须是英文，
///       且中文不许在场。少了它，「组合器改了、对话框那两处没接上」（或取的不是作用域里那张表）
///       会原样留在真实应用里，而所有测试全绿。
///
///       **一份「空备份」是最便宜的确定性触发**：假通道在 `importJson` 上回一份结构合法、各表零行、
///       导出时间就在一小时前、`app_version` 与本机一致的快照——不经文件选择器与引擎往返，
///       八格提示里只有 `noRecoverableRecords` 那一格会亮，十格影响里只有 `emptySource`
///       与 `mergeEmptySource` 两格会亮（见 `buildBackupPreviewWarnings` 与
///       `BackupImportPlan.impacts` 的判据）。
///
///       屏幕跑在默认设置上，语言只由作用域决定；作用域挂在 `builder:` 上，与 `app.dart` 逐字
///       同一个挂点——否则 `showDialog` 压上来的对话框看不见它。
/// English: **the wiring that puts backup notices and import impacts on screen (the settings page's
///          import dialog).**
///
///          The validator keeps only tokens (`BackupPreviewWarningKind`, eight values) and so does the
///          data layer (`BackupImportImpactKind`, ten values) plus payloads (table names, counts,
///          limits); the sentences live in `SettingsBackupStrings` and are fetched at the presentation
///          edge by `backupPreviewWarningMessage` / `backupImportImpactMessage` — which is how the
///          import dialog's "Backup warnings" block and impact list (`settings_backup_widgets.dart`,
///          those two sites) print. The composers themselves are pinned on their own in
///          `test/features/settings_backup_messages_test.dart` (both languages rendered cell by cell,
///          the sources swept) — **neither can prove "the screen really used it"**. What
///          `settings_page_test.dart` measures is the **default Chinese** impact list
///          (`'笔记 将删除本机 2 条'` and friends) and the blocking notice; the English scope had not one
///          case (`docs/verification.md` §5n).
///
///          What this measures is that wire: with an English scope installed, the import dialog must
///          come up with English words on it and no Chinese anywhere. Without it, "the composer was
///          fixed but the dialog was never wired" (or is wired to some other language's table) would
///          survive in the real app with every test green.
///
///          **An "empty backup" is the cheapest deterministic trigger**: the fake channel answers
///          `importJson` with a structurally valid snapshot whose tables all hold zero rows, exported
///          an hour ago, `app_version` matching this device — no file picker, no engine round trip. Of
///          the eight notices only `noRecoverableRecords` lights up, and of the ten impacts only
///          `emptySource` and `mergeEmptySource` do (see the criteria in `buildBackupPreviewWarnings`
///          and `BackupImportPlan.impacts`).
///
///          The screen runs on the default settings; the language is decided by the scope alone,
///          mounted on `builder:` — the very hook `app.dart` uses, or the `showDialog` route would not
///          see it.
void main() {
  const backupChannel = MethodChannel('nekocalc/backup_file');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backupChannel, null);
  });

  testWidgets('英文界面：备份提示与导入影响都是英文', (tester) async {
    _installEmptyBackupImport(backupChannel);

    await _pumpSettings(tester, language: AppLanguage.en);
    await _openImportDialog(tester, 'Import backup');

    expect(
        find.text(
            'This backup holds no records to restore; a replace import would wipe this device.'),
        findsOneWidget,
        reason: '屏幕上没有这句英文提示——组合器与对话框之间那根线断了，或者取的不是作用域里那张表');
    // 中文：这一句在屏幕上出现**两次**：覆盖方案影响清单里那一行（走
    //       `backupImportImpactMessage`）与方案块底下那条阻止提示（`blockedMessage` 那处直接取表）。
    //       数到 2 是有意的：只数「至少一次」的话，组合器那处退回中文时另一次仍会让断言发绿。
    // English: this sentence is on screen **twice**: the row in the replace plan's impact list (through
    //          `backupImportImpactMessage`) and the blocking notice under that plan block (which reads
    //          the table cell directly). Counting 2 is deliberate: a bare "at least one" would stay
    //          green if the composer site fell back to Chinese.
    expect(
        find.text(
            'An empty backup cannot be used for replace; merge it or pick a backup with records.'),
        findsNWidgets(2),
        reason: '两处里至少有一处没有取作用域里的表');
    expect(
        find.text(
            'The backup is empty; merging changes nothing on this device'),
        findsOneWidget,
        reason: '合并方案那一格没有取作用域里的表');

    expect(find.text('备份文件没有可恢复记录，覆盖恢复会清空本机数据。'), findsNothing,
        reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');
    expect(find.text('空备份不能用于覆盖恢复，请改用合并导入或选择包含记录的备份。'), findsNothing,
        reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');
    expect(find.text('备份为空，合并导入不会改变本机数据'), findsNothing,
        reason: '英文界面上还在报中文——那正是这一轮要消灭的那件事');
  });

  testWidgets('默认（中文）界面：同一个对话框报的还是原来那三句话', (tester) async {
    // 中文：没有作用域时回落到中文——这是仓库那条「默认态与接入前逐字节相同」在屏幕上的又一份证据。
    // English: with no scope the language falls back to Chinese — another piece of on-screen evidence
    //          for this repository's "the default state stays byte-identical" rule.
    _installEmptyBackupImport(backupChannel);

    await _pumpSettings(tester);
    await _openImportDialog(tester, '导入恢复');

    expect(find.text('备份文件没有可恢复记录，覆盖恢复会清空本机数据。'), findsOneWidget);
    expect(find.text('空备份不能用于覆盖恢复，请改用合并导入或选择包含记录的备份。'),
        findsNWidgets(2));
    expect(find.text('备份为空，合并导入不会改变本机数据'), findsOneWidget);
  });
}

/// 中文：假通道：`importJson` 回一份「空备份」——各表零行、导出时间一小时前、应用版本与本机一致，
///       于是提示只亮 `noRecoverableRecords` 一格、影响只亮 `emptySource` 与 `mergeEmptySource` 两格。
///       导出时间用**相对时间**而不是写死的日期：写死的话，跑得越晚越会多亮一格「距今很久」的提示，
///       断言就随日历漂了。
/// English: the fake channel: `importJson` answers with an "empty backup" — every table zero rows,
///          exported an hour ago, app version matching this device, so exactly the `noRecoverableRecords`
///          notice and the `emptySource` / `mergeEmptySource` impacts light up. The export time is
///          **relative**, not a hard-coded date: a fixed date would light up an extra "long ago" notice
///          the later the suite runs, and the assertion would drift with the calendar.
void _installEmptyBackupImport(MethodChannel channel) {
  final exportedAt =
      DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'importJson') {
      return jsonEncode({
        'schema': backupSchemaVersion,
        'exported_at': exportedAt,
        'metadata': {'app_version': AppInfo.version},
        'tables': {
          for (final tableName in backupTableNames) tableName: <Object?>[],
        },
      });
    }
    return null;
  });
}

/// 中文：设置页那一屏，加一个可选的语言作用域。**作用域装在 `builder:` 上**——与 `app.dart`
///       逐字同一个挂点（`builder` 的 child 就是 Navigator）；导入对话框压上来时在它之下，
///       所以取得到作用域里那两张表。
/// English: the settings page plus an optional language scope. **The scope sits on `builder:`** — the
///          very hook `app.dart` uses (`builder`'s child *is* the Navigator); the import dialog is
///          pushed above it but below the scope, so it sees the scope's two tables.
Future<void> _pumpSettings(WidgetTester tester, {AppLanguage? language}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    builder: language == null
        ? null
        : (context, child) =>
            AppLanguageScope(language: language, child: child!),
    home: SettingsPage(db: _EmptyDatabase()),
  ));
  await tester.pumpAndSettle();
}

/// 中文：滚到「导入恢复」再点。设置页那几节落在测试视口（800×600）之下，`scrollUntilVisible`
///       末尾不 pump，最后那一下轻拖把按钮带离视口边缘，点才落得到控件上——这几步与
///       `settings_page_test.dart` 里那次导入逐字相同。
/// English: scroll to the import button, then tap. Those sections sit below the test viewport
///          (800×600) and `scrollUntilVisible` does not pump at the end; the small drag takes the
///          button off the viewport edge so the tap lands on the control — the very steps
///          `settings_page_test.dart` uses for its import.
Future<void> _openImportDialog(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 300,
      scrollable: find.byType(Scrollable));
  await tester.drag(find.byType(Scrollable), const Offset(0, -80));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// 中文：本机各表都是零行——与那份空备份对称，于是覆盖方案的清单里只剩 `emptySource` 一行，
///       断言数得到确切的份数。
/// English: every local table is empty — symmetric with that empty backup, so the replace plan's list
///          holds nothing but the `emptySource` row and the assertion can count exact occurrences.
class _EmptyDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {
        'theme_mode': '跟随系统',
        'angle_mode': '弧度',
        'digits': '6 位',
        'expression_display': '数学符号',
      };

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<Map<String, int>> backupTableCounts() async =>
      {for (final tableName in backupTableNames) tableName: 0};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
