import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/backup_snapshot_validator.dart';
import 'package:nekocalc/data/repositories/data_backup_repository.dart';
import 'package:nekocalc/features/settings/presentation/settings_backup_messages.dart';
import 'package:nekocalc/features/settings/presentation/settings_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**「这条提示 / 这条影响说的是哪件事」与「屏幕上那句话」分家之后，两边都还对得上。**
///
///       `BackupPreviewWarning`（校验器）与 `BackupImportImpact`（数据层）原先自己拼那些中文并直接
///       上屏（设置页「备份提示」块印 `warning.message`，导入对话框的影响清单印 `impact.message`），
///       于是英文界面下印的仍是中文——领域对象活得比界面长，界面那张按语言切的表够不着它
///       （`docs/verification.md` §5i）。这一轮把那些句子移进 `SettingsStrings`，产出层只留令牌
///       （[BackupPreviewWarningKind] 八格、[BackupImportImpactKind] 十格），由
///       `settings_backup_messages.dart` 在呈现边缘取。这份测试是那次改动的锁，五段各管一件事：
///
///       1. **令牌与它那句话一一对应**（两张 `legacy*Sentences` 对照表）：十八种结局逐条渲染，中文侧
///          必须与迁移前源码里那句话**逐字节相同**；两个方向都查（枚举里每一格都有对照表条目，
///          对照表里每一条都命中一个真的枚举值）。这就是「产出方漏写令牌」与「令牌多出来」的唯一
///          防线——两样都不会抛，只会静默少一句或错一句。
///       2. **回执真的跟着语言走**：同一批结果递英文表，渲染出来的既不是那句中文、也不含宽/全角
///          字符（载荷用 ASCII，因为载荷是调用方递进来的、本来就跟着调用方的语言）。多张表那句的
///          **连接符**（「、」对 `, `）也在这里被量到。
///       3. **载荷真的拼进句子**：换表名 / 条数 / 上限 / 版本号 / 年龄，句子里那半截必须跟着换；
///          年龄切成「年 / 个月 / 天」的三条边界（365、30 两侧）逐条钉住。
///       4. **判据没变**：提示的 `severity`、影响的 `severity` 与 `icon` 与迁移前一致（它们现在由
///          命名构造当场写死或由穷尽 `switch` 派生，迁移一个字都没动它们）。
///       5. **源码里那句话只有一份**：两个产出文件里**被转换的那一段**一个宽/全角字面量都不许有
///          （下面那段说明为什么两个文件各自只量一段——两处都还有**有意留下**的界外文案），且迁移前
///          那些句子在那两段所属的整个文件里一个字都不许留；唯一有意留下的那一句
///          （`emptyBackupReplaceErrorMessage`）单独钉住、不让它悄悄多出第二个住处。
///
///       **中文逐字节相同是被测试量出来的，不是被声明的**：两张对照表就是迁移前那两个文件里那些
///       `message:` 的抄本，故意写死在测试里。**不要拿它们去追新文案。**
/// English: **once "which thing this notice / impact is about" has parted from "the sentence on
///          screen", the two still line up.**
///
///          `BackupPreviewWarning` (the validator) and `BackupImportImpact` (the data layer) used to
///          compose those Chinese sentences themselves and print them straight (the settings page's
///          "Backup warnings" block printed `warning.message` and the import dialog's impact list
///          printed `impact.message`), so an English interface still printed Chinese — a domain object
///          outlives the UI and a language-keyed interface table cannot reach it
///          (`docs/verification.md` §5i). This round moved those sentences into `SettingsStrings`,
///          leaving the producing layers with only the tokens ([BackupPreviewWarningKind], eight values;
///          [BackupImportImpactKind], ten), resolved at the presentation edge by
///          `settings_backup_messages.dart`. This test is that change's lock, in five parts:
///
///          1. **Token and sentence correspond one to one** (two `legacy*Sentences` tables): all eighteen
///             outcomes rendered, the Chinese side **byte-identical** to the sentence in the source
///             before the change, checked in both directions (every enum value has a table entry, every
///             entry hits a real enum value). This is the only defence against "a producer forgot the
///             token" and "a token appeared from nowhere" — neither throws, they only silently drop or
///             swap a sentence.
///          2. **The receipt really follows the language**: the same results with the English table
///             render neither the Chinese sentence nor any wide/fullwidth character (payloads are ASCII
///             here, because a payload is handed in by the caller and already follows the caller's
///             language). The multi-table **separator** ("、" against ", ") is measured here as well.
///          3. **The payloads really splice into the sentence**: a different table name, count, limit,
///             version or age moves that half of the sentence; the age split into years / months / days
///             is pinned on both sides of its 365 and 30 day boundaries.
///          4. **The verdicts have not moved**: the notices' `severity` and the impacts' `severity` and
///             `icon` read as they did (they are now hard-coded by the named constructors or derived by
///             an exhaustive `switch`; the move did not touch them by one character).
///          5. **The sentence exists once in the source**: **the converted stretch** of each producing
///             file must hold **not one wide/fullwidth literal** (the note under part 5 explains why each
///             file is measured stretch by stretch — both still carry copy that was deliberately left
///             out of scope), and the pre-move sentences must not survive anywhere in either file. The
///             one sentence deliberately left (`emptyBackupReplaceErrorMessage`) is pinned by itself so
///             it cannot quietly acquire a second home.
///
///          **The byte-identity is measured, not asserted**: the two tables are copies of those
///          `message:` lines in the two files before the change, deliberately written out in the test.
///          **Do not bring them up to date with new copy.**
void main() {
  final zh = SettingsStrings.forLanguage(AppLanguage.zh);
  final en = SettingsStrings.forLanguage(AppLanguage.en);

  /// 中文：**迁移前那八句提示本身**（结局 → 它从前印什么）。这张表**故意写在测试里**、不从
  ///       `SettingsStrings` 生成：它的全部价值就在于它是**旧知识的一份抄本**。载荷取一组固定
  ///       值（`'not-a-date'`、400 天、100 天、`v1.0.0` / `v1.1.0`），句子里的其余部分因此逐字节
  ///       可比。**不要拿它去追新文案。**
  /// English: **the eight notices from before the change** (outcome → what it used to print). This
  ///          table is **deliberately written in the test** rather than generated from
  ///          `SettingsStrings`: its whole value is being **a copy of the old knowledge**. The payloads
  ///          take one fixed set (`'not-a-date'`, 400 days, 100 days, `v1.0.0` / `v1.1.0`), so the rest
  ///          of the sentence is byte-comparable. **Do not bring it up to date with new copy.**
  const legacyWarningSentences = <BackupPreviewWarningKind, String>{
    BackupPreviewWarningKind.noRecoverableRecords:
        '备份文件没有可恢复记录，覆盖恢复会清空本机数据。',
    BackupPreviewWarningKind.missingExportedAt: '备份缺少导出时间，无法判断文件新旧。',
    BackupPreviewWarningKind.unrecognisedExportedAt:
        '备份导出时间无法识别：not-a-date。',
    BackupPreviewWarningKind.exportedAtInFuture:
        '备份导出时间晚于本机时间，请确认设备时间是否正确。',
    BackupPreviewWarningKind.olderThanYear:
        '备份距今约 1 年，恢复前建议确认内容是否仍然需要。',
    BackupPreviewWarningKind.olderThanNinetyDays: '备份距今约 3 个月。',
    BackupPreviewWarningKind.missingAppVersion: '备份缺少应用版本信息。',
    BackupPreviewWarningKind.appVersionMismatch:
        '备份来自 v1.0.0，当前应用为 v1.1.0。',
  };

  /// 中文：**迁移前那十句影响本身**（结局 → 它从前印什么）。载荷取一组固定值（表名标签、
  ///       条数、上限 24 / 500、四个「表 +N」备料项），与迁移前数据层测试里那些断言同一组。
  ///       **不要拿它去追新文案。**
  /// English: **the ten impacts from before the change** (outcome → what it used to print). The payloads
  ///          take one fixed set (table labels, counts, the 24 / 500 limits, the four "table +N"
  ///          ingredients), the same set the pre-move data-layer tests asserted on. **Do not bring it
  ///          up to date with new copy.**
  const legacyImpactSentences = <BackupImportImpactKind, String>{
    BackupImportImpactKind.deleteTable: '笔记 将删除本机 3 条',
    BackupImportImpactKind.reduceTable: '历史 将减少 4 条',
    BackupImportImpactKind.emptySource: '空备份不能用于覆盖恢复，请改用合并导入或选择包含记录的备份。',
    BackupImportImpactKind.overwriteTables: '会覆盖本机历史、收藏、最近工具、设置数据',
    BackupImportImpactKind.replaceKeepsIdentical: '覆盖后本机数据将与备份文件一致',
    BackupImportImpactKind.mergeEmptySource: '备份为空，合并导入不会改变本机数据',
    BackupImportImpactKind.mergeAddsTables:
        '会保留本机数据，并尝试加入 历史 +1、收藏 +1、最近工具 +2、设置 +1',
    BackupImportImpactKind.mergeUpdatesSettings: '设置项可能按备份内容更新',
    BackupImportImpactKind.mergeKeepsRecentLimit: '最近工具只保留最新 24 条',
    BackupImportImpactKind.mergeKeepsHistoryLimit: '历史记录合并后仍会保留最近 500 条',
  };

  test('每个结局一句回执：令牌与那句话一一对应', () {
    // 中文：**中文侧逐字节相同**。断言写成一整张表逐条比，不抽查——抽查漏掉的那一条正好是将来
    //       会漂的那一条，而漂了不会有任何东西抛。
    // English: **the Chinese side is byte-identical.** The assertions walk the whole table rather than
    //          sampling: the entry a spot check skips is the one that drifts, and a drift throws
    //          nothing.
    for (final entry in legacyWarningSentences.entries) {
      expect(
        backupPreviewWarningMessage(_warningFor(entry.key), zh),
        entry.value,
        reason: '${entry.key.name} 的提示与迁移前那句话不同了',
      );
    }
    for (final entry in legacyImpactSentences.entries) {
      expect(
        backupImportImpactMessage(_impactFor(entry.key), zh),
        entry.value,
        reason: '${entry.key.name} 的影响与迁移前那句话不同了',
      );
    }

    // 中文：**两个方向。** 枚举里每一格都要有对照表条目（漏了就是"令牌多出来"），对照表里每一条
    //       都要命中一个真的枚举值（多一条就是"令牌被删了、文案留着"）。
    // English: **both directions.** Every enum value needs a table entry (a missing one means "a token
    //          appeared from nowhere"), and every table entry has to hit a real enum value (an extra one
    //          means "the token was deleted, the copy stayed").
    expect(legacyWarningSentences.keys.toSet(),
        BackupPreviewWarningKind.values.toSet(),
        reason: '提示令牌与旧文案对照表对不上：'
            '${legacyWarningSentences.keys.toSet().difference(BackupPreviewWarningKind.values.toSet())}');
    expect(
        legacyImpactSentences.keys.toSet(), BackupImportImpactKind.values.toSet(),
        reason: '影响令牌与旧文案对照表对不上：'
            '${legacyImpactSentences.keys.toSet().difference(BackupImportImpactKind.values.toSet())}');
  });

  test('同一个令牌在英文表下不给中文：回执跟着语言走', () {
    // 中文：**载荷用 ASCII**：表名、条数与版本号是调用方递进来的数据、本来就跟着调用方的语言，
    //       所以这里量的是**句子**那一层，不是载荷那一层。十八种结局都过一遍。
    // English: **the payloads are ASCII here**: table names, counts and version numbers are data handed
    //          in by the caller and already follow the caller's language, so what is measured here is
    //          the **sentence** layer, not the payload layer. All eighteen outcomes go through.
    final warningMessages = [
      for (final kind in BackupPreviewWarningKind.values)
        backupPreviewWarningMessage(_warningFor(kind), en),
    ];
    final impactMessages = [
      for (final kind in BackupImportImpactKind.values)
        backupImportImpactMessage(_asciiImpactFor(kind), en),
    ];
    for (final message in [...warningMessages, ...impactMessages]) {
      expect(containsWideOrFullwidth(message), isFalse,
          reason: '英文回执里还有宽/全角字符：$message');
      expect(message, isNot(contains('。')));
    }
    // 中文：**英文表不是中文表抄两遍**：每一种结局在两种语言下都不同。
    // English: **the English table is not the Chinese one copied twice**: every outcome differs between
    //          the two languages.
    for (final kind in BackupPreviewWarningKind.values) {
      expect(
        backupPreviewWarningMessage(_warningFor(kind), en),
        isNot(backupPreviewWarningMessage(_warningFor(kind), zh)),
        reason: '${kind.name} 在两种语言下印同一句话',
      );
    }
    for (final kind in BackupImportImpactKind.values) {
      expect(
        backupImportImpactMessage(_asciiImpactFor(kind), en),
        isNot(backupImportImpactMessage(_asciiImpactFor(kind), zh)),
        reason: '${kind.name} 在两种语言下印同一句话',
      );
    }
    // 中文：**多张表那句的连接符也跟着语言走**：同一个影响、同一组 ASCII 表名，中文用「、」、
    //       英文用 `, `——连接符不是装饰，它是这两句话里唯一按语言变的那一格。
    // English: **the multi-table separator follows the language too**: the same impact with the same
    //          ASCII table names joins with "、" in Chinese and ", " in English — the separator is not
    //          decoration, it is the one cell of these sentences that changes with the language.
    const overwrite = BackupImportImpact.overwriteTables(['History', 'Settings']);
    expect(backupImportImpactMessage(overwrite, zh), '会覆盖本机History、Settings数据');
    expect(
        backupImportImpactMessage(overwrite, en),
        'Overwrites the local History, Settings data');
  });

  test('载荷真的拼进句子：换一个表名、条数、上限、版本或年龄，句子就跟着换', () {
    // 中文：**年龄那根尾巴切成「年 / 个月 / 天」的规则逐条钉住**：365 与 30 两条边界两侧各量一次
    //       （迁移前 `_formatAge` 就是 `~/ 365`、`~/ 30`、其余取天；只量一侧的话，一个永远取年的
    //       实现也能过）。
    // English: **the age tail's years / months / days split is pinned boundary by boundary**: both sides
    //          of the 365 and 30 day cuts are measured (the pre-move `_formatAge` was `~/ 365`,
    //          `~/ 30`, the rest days; with only one side measured, an implementation that always says
    //          years would pass).
    expect(
      backupPreviewWarningMessage(
          BackupPreviewWarning.olderThanYear(const Duration(days: 365)), zh),
      '备份距今约 1 年，恢复前建议确认内容是否仍然需要。',
    );
    expect(
      backupPreviewWarningMessage(
          BackupPreviewWarning.olderThanYear(const Duration(days: 730)), zh),
      '备份距今约 2 年，恢复前建议确认内容是否仍然需要。',
    );
    expect(
      backupPreviewWarningMessage(
          BackupPreviewWarning.olderThanNinetyDays(const Duration(days: 364)), zh),
      '备份距今约 12 个月。',
    );
    expect(
      backupPreviewWarningMessage(
          BackupPreviewWarning.olderThanNinetyDays(const Duration(days: 30)), zh),
      '备份距今约 1 个月。',
    );
    expect(
      backupPreviewWarningMessage(
          BackupPreviewWarning.olderThanNinetyDays(const Duration(days: 29)), zh),
      '备份距今约 29 天。',
    );

    // 中文：其余两个带载荷的提示格：换一个导出时间串 / 一对版本号，句子里那半截跟着换，
    //       且载荷原样留在警告上（未 trim，与迁移前那句一致）。
    // English: the other two payload-carrying notices: a different export-time string or version pair
    //          moves that half of the sentence, and the payload stays on the warning as-is (untrimmed,
    //          as the pre-move sentence had it).
    final unrecognised =
        BackupPreviewWarning.unrecognisedExportedAt('2026-13-45');
    expect(unrecognised.exportedAt, '2026-13-45');
    expect(
      backupPreviewWarningMessage(unrecognised, zh),
      '备份导出时间无法识别：2026-13-45。',
    );
    final mismatch = BackupPreviewWarning.appVersionMismatch(
      version: 'v2.0.0',
      currentVersion: 'v2.1.0',
    );
    expect(mismatch.version, 'v2.0.0');
    expect(mismatch.currentVersion, 'v2.1.0');
    expect(
      backupPreviewWarningMessage(mismatch, zh),
      '备份来自 v2.0.0，当前应用为 v2.1.0。',
    );

    // 中文：**影响那十格的载荷**：表名、条数、上限与「表 +N」备料项都真的进句子；多张表那句的
    //       项数与顺序跟着载荷走。
    // English: **the ten impacts' payloads**: table names, counts, limits and the "table +N"
    //          ingredients really reach the sentence; the multi-table cells' item count and order
    //          follow the payload.
    const deleteTable = BackupImportImpact.deleteTable('设置', 5);
    expect(deleteTable.label, '设置');
    expect(deleteTable.count, 5);
    expect(backupImportImpactMessage(deleteTable, zh), '设置 将删除本机 5 条');
    expect(
      backupImportImpactMessage(
          const BackupImportImpact.reduceTable('笔记', 2), zh),
      '笔记 将减少 2 条',
    );
    expect(
      backupImportImpactMessage(
          const BackupImportImpact.overwriteTables(['历史', '设置']), zh),
      '会覆盖本机历史、设置数据',
    );
    const mergeAdds =
        BackupImportImpact.mergeAddsTables(['历史 +1', '设置 +2']);
    expect(mergeAdds.labels, ['历史 +1', '设置 +2']);
    expect(
      backupImportImpactMessage(mergeAdds, zh),
      '会保留本机数据，并尝试加入 历史 +1、设置 +2',
    );
    const keepsRecent = BackupImportImpact.mergeKeepsRecentLimit(30);
    expect(keepsRecent.limit, 30);
    expect(
        backupImportImpactMessage(keepsRecent, zh), '最近工具只保留最新 30 条');
    expect(
      backupImportImpactMessage(
          const BackupImportImpact.mergeKeepsHistoryLimit(100), zh),
      '历史记录合并后仍会保留最近 100 条',
    );
  });

  test('结局那几档判据没有跟着文案一起动', () {
    // 中文：**八格提示各自的严重档是判据**（设置页那块提示框按它取色与图标），逐格钉住；它是从
    //       令牌**派生**的（穷尽 `switch`），所以「令牌说 A、颜色却是 B」没有落点。
    // English: **each of the eight notices' severity is a verdict** (the settings page's notice block
    //          reads it for colour and icon), pinned cell by cell; it is **derived** from the token (an
    //          exhaustive `switch`), so "the token says A while the colour says B" has nowhere to land.
    const expectedWarningSeverities =
        <BackupPreviewWarningKind, BackupPreviewWarningSeverity>{
      BackupPreviewWarningKind.noRecoverableRecords:
          BackupPreviewWarningSeverity.danger,
      BackupPreviewWarningKind.missingExportedAt:
          BackupPreviewWarningSeverity.info,
      BackupPreviewWarningKind.unrecognisedExportedAt:
          BackupPreviewWarningSeverity.warning,
      BackupPreviewWarningKind.exportedAtInFuture:
          BackupPreviewWarningSeverity.warning,
      BackupPreviewWarningKind.olderThanYear:
          BackupPreviewWarningSeverity.warning,
      BackupPreviewWarningKind.olderThanNinetyDays:
          BackupPreviewWarningSeverity.info,
      BackupPreviewWarningKind.missingAppVersion:
          BackupPreviewWarningSeverity.info,
      BackupPreviewWarningKind.appVersionMismatch:
          BackupPreviewWarningSeverity.info,
    };
    for (final kind in BackupPreviewWarningKind.values) {
      expect(_warningFor(kind).severity, expectedWarningSeverities[kind],
          reason: '${kind.name} 的严重档与迁移前不同了');
    }

    // 中文：**十格影响的严重档与图标同样是判据**（清单里每行的颜色与图标），逐格钉住；它们由命名
    //       构造当场写死，所以与令牌不可能对不上。
    // English: **the ten impacts' severity and icon are verdicts too** (each list row's colour and
    //          icon), pinned cell by cell; the named constructors hard-code them, so they cannot
    //          disagree with the token.
    const expectedImpactStyles = <BackupImportImpactKind,
        (BackupImportImpactSeverity, BackupImportImpactIcon)>{
      BackupImportImpactKind.deleteTable: (
        BackupImportImpactSeverity.danger,
        BackupImportImpactIcon.delete
      ),
      BackupImportImpactKind.reduceTable: (
        BackupImportImpactSeverity.warning,
        BackupImportImpactIcon.replace
      ),
      BackupImportImpactKind.emptySource: (
        BackupImportImpactSeverity.danger,
        BackupImportImpactIcon.blocked
      ),
      BackupImportImpactKind.overwriteTables: (
        BackupImportImpactSeverity.warning,
        BackupImportImpactIcon.replace
      ),
      BackupImportImpactKind.replaceKeepsIdentical: (
        BackupImportImpactSeverity.info,
        BackupImportImpactIcon.replace
      ),
      BackupImportImpactKind.mergeEmptySource: (
        BackupImportImpactSeverity.info,
        BackupImportImpactIcon.merge
      ),
      BackupImportImpactKind.mergeAddsTables: (
        BackupImportImpactSeverity.info,
        BackupImportImpactIcon.merge
      ),
      BackupImportImpactKind.mergeUpdatesSettings: (
        BackupImportImpactSeverity.warning,
        BackupImportImpactIcon.settings
      ),
      BackupImportImpactKind.mergeKeepsRecentLimit: (
        BackupImportImpactSeverity.info,
        BackupImportImpactIcon.tools
      ),
      BackupImportImpactKind.mergeKeepsHistoryLimit: (
        BackupImportImpactSeverity.info,
        BackupImportImpactIcon.history
      ),
    };
    for (final kind in BackupImportImpactKind.values) {
      final impact = _impactFor(kind);
      expect(impact.severity, expectedImpactStyles[kind]!.$1,
          reason: '${kind.name} 的严重档与迁移前不同了');
      expect(impact.icon, expectedImpactStyles[kind]!.$2,
          reason: '${kind.name} 的图标与迁移前不同了');
    }
  });

  test('源码里那句话只有一份：两个产出文件被转换的那段一个宽/全角字面量都没有', () {
    // 中文：**扫的是"这一段里有没有给人看的字"**，不是"有没有整句相同"：被转换的那一段里再出现
    //       任何一个宽/全角字面量，都说明有人把文案抄了回来（或者新写了一句），而抄回来的那一份
    //       不会跟着语言走。尺子与计算器、工具、笔记那几条护栏**同一把**（`containsWideOrFullwidth`）。
    //
    //       **两个文件各自只量一段**，不是整个文件：它们都还有**有意留下**的界外文案——
    //       校验器里那批 `FormatException` 句子与 `backupTableLabels`（表名标签是内容，今天仍是
    //       中文）、`BackupPreview.summary` / `totalLabel`，数据层里 `BackupImportPlan.modeLabel` /
    //       `summary` / `totalLabel` 与 `BackupImportReport` 那一族（`docs/verification.md` §5i 记着
    //       这批还没转）。所以校验器那一段从 `enum BackupPreviewWarningSeverity {` 量到
    //       `Map<String, Object?> parseBackupSnapshot(` 之前，数据层那一段从
    //       `List<BackupImportImpact> get impacts {` 量到 `class BackupImportReport {` 之前——
    //       **四个端点都必须找得到、且各自成对有序**，否则扫的就可能是一段空字符串（那种"全过"
    //       最危险）。
    //
    //       两条底线的第二条：迁移前那十八句句子**在两个文件里一个字都不许留**，不管它藏在哪一段；
    //       带载荷的那几格连**半句**（前缀 / 后缀）一起查，免得模板被抄回来。**唯一有意留下的一句**
    //       是 `emptyBackupReplaceErrorMessage`（校验器里那个常量，覆盖恢复被拒时的异常仍用它）——
    //       它单独钉住：既证明它还在、也证明它与影响表的 `emptySource` 那格**逐字节相同**，将来谁
    //       想改其中一份都会先撞上这条。
    // English: **the scan asks "does this stretch hold any human-facing character"**, not "is a whole
    //          sentence identical": any wide/fullwidth literal reappearing in a converted stretch means
    //          somebody copied copy back (or wrote a new sentence), and the copy will not follow the
    //          language. The ruler is **the same one** as the calculator, tools and notes guards
    //          (`containsWideOrFullwidth`).
    //
    //          **Each file is measured stretch by stretch**, not whole: both still carry copy that was
    //          **deliberately left** out of scope — in the validator the `FormatException` sentences and
    //          `backupTableLabels` (a table label is content and is Chinese today), plus
    //          `BackupPreview.summary` / `totalLabel`; in the data layer
    //          `BackupImportPlan.modeLabel` / `summary` / `totalLabel` and the `BackupImportReport`
    //          family (`docs/verification.md` §5i records that these have not been converted). So the
    //          validator's stretch runs from `enum BackupPreviewWarningSeverity {` up to (but not
    //          including) `Map<String, Object?> parseBackupSnapshot(`, and the data layer's from
    //          `List<BackupImportImpact> get impacts {` up to (but not including)
    //          `class BackupImportReport {` — **all four endpoints must be found, each pair in order**,
    //          or the scan could be measuring an empty string (the kind of "all pass" that is the most
    //          dangerous).
    //
    //          The second floor: the eighteen pre-move sentences must **not survive anywhere** in the
    //          two files, whatever stretch they hide in; the payload-carrying cells are checked by their
    //          **halves** (prefix / suffix) as well, so a template copied back cannot slip through. The
    //          **one sentence deliberately left** is `emptyBackupReplaceErrorMessage` (the constant in
    //          the validator, still used by the exception that rejects a replace import) — it is pinned
    //          by itself: that it is still there, and that it is **byte-identical** to the impact
    //          table's `emptySource` cell, so whoever tries to change either side hits this line first.
    final validatorFile = File('lib/core/utils/backup_snapshot_validator.dart');
    final repositoryFile =
        File('lib/data/repositories/data_backup_repository.dart');
    expect(validatorFile.existsSync() && repositoryFile.existsSync(), isTrue,
        reason: '测试的工作目录应当是包的根目录');

    final validatorSource = stripComments(validatorFile.readAsStringSync());
    final repositorySource = stripComments(repositoryFile.readAsStringSync());

    const warningStartMarker = 'enum BackupPreviewWarningSeverity {';
    const warningEndMarker = 'Map<String, Object?> parseBackupSnapshot(';
    final warningStart = validatorSource.indexOf(warningStartMarker);
    final warningEnd = validatorSource.indexOf(warningEndMarker);
    expect(warningStart, isNot(-1), reason: '找不到提示族的起点：$warningStartMarker');
    expect(warningEnd, isNot(-1), reason: '找不到提示族的终点：$warningEndMarker');
    expect(warningEnd, greaterThan(warningStart), reason: '提示族那一段的两个端点顺序反了');

    const impactStartMarker = 'List<BackupImportImpact> get impacts {';
    const impactEndMarker = 'class BackupImportReport {';
    final impactStart = repositorySource.indexOf(impactStartMarker);
    final impactEnd = repositorySource.indexOf(impactEndMarker);
    expect(impactStart, isNot(-1), reason: '找不到影响族的起点：$impactStartMarker');
    expect(impactEnd, isNot(-1), reason: '找不到影响族的终点：$impactEndMarker');
    expect(impactEnd, greaterThan(impactStart), reason: '影响族那一段的两个端点顺序反了');

    final offenders = <String>[
      ...stringLiterals(validatorSource.substring(warningStart, warningEnd))
          .where(containsWideOrFullwidth)
          .map((literal) => 'backup_snapshot_validator.dart: $literal'),
      ...stringLiterals(repositorySource.substring(impactStart, impactEnd))
          .where(containsWideOrFullwidth)
          .map((literal) => 'data_backup_repository.dart: $literal'),
    ];
    expect(offenders, isEmpty,
        reason: '这些字面量应当走 SettingsStrings（句子只住在那里）：\n'
            '${offenders.join('\n')}');

    // 中文：**旧句子一个字都不许留**（整份文件，含注释被剥掉后的正文）。载荷那几格连半句一起查。
    // English: **not one word of the old sentences may stay** (the whole file, comments stripped). The
    //          payload-carrying cells are checked by their halves as well.
    const legacyWarningFragments = <String>[
      '备份导出时间无法识别：',
      '备份距今约 ',
      '，恢复前建议确认内容是否仍然需要。',
      '备份来自 ',
      '，当前应用为 ',
    ];
    const legacyImpactFragments = <String>[
      ' 将删除本机 ',
      ' 将减少 ',
      '会覆盖本机',
      '会保留本机数据，并尝试加入 ',
      '最近工具只保留最新 ',
      '历史记录合并后仍会保留最近 ',
    ];
    for (final sentence in legacyWarningSentences.values) {
      expect(validatorSource.contains(sentence), isFalse,
          reason: '校验器里还留着旧的提示句：$sentence');
    }
    for (final sentence in legacyImpactSentences.values) {
      expect(repositorySource.contains(sentence), isFalse,
          reason: '数据层里还留着旧的影响句：$sentence');
    }
    for (final fragment in legacyWarningFragments) {
      expect(validatorSource.contains(fragment), isFalse,
          reason: '校验器里还留着旧提示句的半截：$fragment');
    }
    for (final fragment in legacyImpactFragments) {
      expect(repositorySource.contains(fragment), isFalse,
          reason: '数据层里还留着旧影响句的半截：$fragment');
    }

    // 中文：**唯一有意留下的那一句**：覆盖恢复被拒的异常仍从校验器这个常量取字（界外，见 §5i），
    //       它必须还在，且与影响表 `emptySource` 那格逐字节相同——设置页那条「空备份不能用于覆盖
    //       恢复…」的提示正是走后者，两边一分家，屏幕上与异常里就会各说各话。
    // English: **the one sentence deliberately left**: the exception that rejects a replace import still
    //          takes its words from this validator constant (out of scope, see §5i); it must still be
    //          there, and byte-identical to the impact table's `emptySource` cell — the settings page's
    //          "an empty backup cannot be used for replace…" notice goes through the latter, and the day
    //          the two part ways the screen and the exception would tell different stories.
    expect(validatorSource.contains(emptyBackupReplaceErrorMessage), isTrue,
        reason: '校验器里那个仍被拒绝导入异常使用的常量不见了');
    expect(zh.backupImpactEmptySource, emptyBackupReplaceErrorMessage,
        reason: '影响表 emptySource 那格与校验器常量分家了');
  });
}

/// 中文：提示对照表里的固定载荷（`'not-a-date'`、400 天、100 天、`v1.0.0` / `v1.1.0`）。
/// English: the fixed payloads of the warning table (`'not-a-date'`, 400 days, 100 days, `v1.0.0` /
///          `v1.1.0`).
BackupPreviewWarning _warningFor(BackupPreviewWarningKind kind) {
  return switch (kind) {
    BackupPreviewWarningKind.noRecoverableRecords =>
      const BackupPreviewWarning.noRecoverableRecords(),
    BackupPreviewWarningKind.missingExportedAt =>
      const BackupPreviewWarning.missingExportedAt(),
    BackupPreviewWarningKind.unrecognisedExportedAt =>
      BackupPreviewWarning.unrecognisedExportedAt('not-a-date'),
    BackupPreviewWarningKind.exportedAtInFuture =>
      const BackupPreviewWarning.exportedAtInFuture(),
    BackupPreviewWarningKind.olderThanYear =>
      BackupPreviewWarning.olderThanYear(const Duration(days: 400)),
    BackupPreviewWarningKind.olderThanNinetyDays =>
      BackupPreviewWarning.olderThanNinetyDays(const Duration(days: 100)),
    BackupPreviewWarningKind.missingAppVersion =>
      const BackupPreviewWarning.missingAppVersion(),
    BackupPreviewWarningKind.appVersionMismatch =>
      BackupPreviewWarning.appVersionMismatch(
        version: 'v1.0.0',
        currentVersion: 'v1.1.0',
      ),
  };
}

/// 中文：影响对照表里的固定载荷（与迁移前数据层测试同一组：笔记 3、历史 4、四张表的覆盖清单、
///       四个「表 +N」备料项、上限 24 / 500）。
/// English: the fixed payloads of the impact table (the same set the pre-move data-layer tests used:
///          notes 3, history 4, the four-table overwrite list, the four "table +N" ingredients, the
///          24 / 500 limits).
BackupImportImpact _impactFor(BackupImportImpactKind kind) {
  return switch (kind) {
    BackupImportImpactKind.deleteTable =>
      const BackupImportImpact.deleteTable('笔记', 3),
    BackupImportImpactKind.reduceTable =>
      const BackupImportImpact.reduceTable('历史', 4),
    BackupImportImpactKind.emptySource =>
      const BackupImportImpact.emptySource(),
    BackupImportImpactKind.overwriteTables =>
      const BackupImportImpact.overwriteTables(['历史', '收藏', '最近工具', '设置']),
    BackupImportImpactKind.replaceKeepsIdentical =>
      const BackupImportImpact.replaceKeepsIdentical(),
    BackupImportImpactKind.mergeEmptySource =>
      const BackupImportImpact.mergeEmptySource(),
    BackupImportImpactKind.mergeAddsTables => const BackupImportImpact
        .mergeAddsTables(['历史 +1', '收藏 +1', '最近工具 +2', '设置 +1']),
    BackupImportImpactKind.mergeUpdatesSettings =>
      const BackupImportImpact.mergeUpdatesSettings(),
    BackupImportImpactKind.mergeKeepsRecentLimit =>
      const BackupImportImpact.mergeKeepsRecentLimit(24),
    BackupImportImpactKind.mergeKeepsHistoryLimit =>
      const BackupImportImpact.mergeKeepsHistoryLimit(500),
  };
}

/// 中文：同一批令牌、**ASCII 载荷**——英文那一遍专用（载荷跟着调用方的语言走，这里量的是句子）。
/// English: the same tokens with **ASCII payloads** — for the English pass only (a payload follows the
///          caller's language; what is measured here is the sentence).
BackupImportImpact _asciiImpactFor(BackupImportImpactKind kind) {
  return switch (kind) {
    BackupImportImpactKind.deleteTable =>
      const BackupImportImpact.deleteTable('Notes', 3),
    BackupImportImpactKind.reduceTable =>
      const BackupImportImpact.reduceTable('History', 4),
    BackupImportImpactKind.emptySource =>
      const BackupImportImpact.emptySource(),
    BackupImportImpactKind.overwriteTables => const BackupImportImpact
        .overwriteTables(['History', 'Favorites', 'Recent', 'Settings']),
    BackupImportImpactKind.replaceKeepsIdentical =>
      const BackupImportImpact.replaceKeepsIdentical(),
    BackupImportImpactKind.mergeEmptySource =>
      const BackupImportImpact.mergeEmptySource(),
    BackupImportImpactKind.mergeAddsTables => const BackupImportImpact
        .mergeAddsTables(['History +1', 'Recent +2', 'Settings +1']),
    BackupImportImpactKind.mergeUpdatesSettings =>
      const BackupImportImpact.mergeUpdatesSettings(),
    BackupImportImpactKind.mergeKeepsRecentLimit =>
      const BackupImportImpact.mergeKeepsRecentLimit(24),
    BackupImportImpactKind.mergeKeepsHistoryLimit =>
      const BackupImportImpact.mergeKeepsHistoryLimit(500),
  };
}
