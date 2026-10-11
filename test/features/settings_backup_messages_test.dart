import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/backup_snapshot_validator.dart';
import 'package:nekocalc/data/repositories/data_backup_repository.dart';
import 'package:nekocalc/features/settings/presentation/settings_backup_messages.dart';
import 'package:nekocalc/features/settings/presentation/settings_backup_strings.dart';
import 'package:nekocalc/features/settings/presentation/settings_backup_text.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**「这条提示 / 这条影响说的是哪件事」与「屏幕上那句话」分家之后，两边都还对得上。**
///
///       `BackupPreviewWarning`（校验器）与 `BackupImportImpact`（数据层）原先自己拼那些中文并直接
///       上屏（设置页「备份提示」块印 `warning.message`，导入对话框的影响清单印 `impact.message`），
///       于是英文界面下印的仍是中文——领域对象活得比界面长，界面那张按语言切的表够不着它
///       （`docs/verification.md` §5i）。这一轮把那些句子移进备份文案表，产出层只留令牌
///       （[BackupPreviewWarningKind] 八格、[BackupImportImpactKind] 十格），由
///       `settings_backup_messages.dart` 在呈现边缘取。
///
///       **第六刀补上的两件**：覆盖恢复被拒时异常里那枚 ASCII 令牌
///       [emptyBackupReplaceErrorToken]（`backupImportFailureMessage` 把它换成文案表
///       `backupImpactEmptySource` 那一格——与导入对话框那条阻止提示同一句），以及五个**表名标签**
///       （键是数据、留在校验器的 `backupTableNames` 里，词搬进
///       `SettingsBackupStrings.backupTableLabels`，由 `settings_backup_text.dart` 的
///       `backupTableLabel` 在呈现边缘查）。所以旧句子里夹着的表名如今也是查出来的。这份测试是那两次
///       改动的锁，五段各管一件事：
///
///       1. **令牌与它那句话一一对应**（两张 `legacy*Sentences` 对照表与一张 `legacyTableLabels`
///          表名→标签对照表）：十八种结局逐条渲染，中文侧必须与迁移前源码里那句话**逐字节相同**；
///          两个方向都查（枚举里每一格都有对照表条目，对照表里每一条都命中一个真的枚举值）。这就是
///          「产出方漏写令牌」与「令牌多出来」的唯一防线——两样都不会抛，只会静默少一句或错一句。
///          表名标签同法：五个键的中文标签逐字节钉住，与 `backupTableNames` 两个方向对齐，认不出的
///          键回落到键本身。
///       2. **回执真的跟着语言走**：同一批结果递英文表，渲染出来的既不是那句中文、也不含宽/全角
///          字符（载荷这一轮起是**表名（键）与计数**，本来就是 ASCII 数据；标签是查出来的，所以这条
///          尺子连标签一起量——英文表漏一格中文标签就会在这里现形）。多张表那句的**连接符**
///          （「、」对 `, `）也在这里被量到。
///       3. **载荷真的拼进句子**：换一个表名（键）/ 条数 / 上限 / 版本号 / 年龄，句子里那半截必须
///          跟着换；年龄切成「年 / 个月 / 天」的三条边界（365、30 两侧）逐条钉住。
///       4. **判据没变**：提示的 `severity`、影响的 `severity` 与 `icon` 与迁移前一致（它们现在由
///          命名构造当场写死或由穷尽 `switch` 派生，迁移一个字都没动它们）。
///       5. **源码里那句话只有一份**：校验器**被转换的那一段**一个宽/全角字面量都不许有（它还有
///          **有意留下**的 `FormatException` 技术串，所以那一份只量一段），数据层**整份文件**都不许
///          有（它的文案这一轮连标签一起搬空了），且迁移前那些句子在那两个文件里一个字都不许留。
///          **翻转的那一条**：从前的「唯一有意留下的句子」（`emptyBackupReplaceErrorMessage`）与五个
///          表名标签如今都搬走了——它们在**校验器整份文件**里连一个字面量都不许留，改钉那枚 ASCII
///          令牌与它到文案表那一格的接线（`backupImportFailureMessage`，两种语言各查一次，外加一枚
///          非令牌异常原样穿过）。
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
///          (`docs/verification.md` §5i). This round moved those sentences into the backup table
///          (`SettingsBackupStrings`),
///          leaving the producing layers with only the tokens ([BackupPreviewWarningKind], eight values;
///          [BackupImportImpactKind], ten), resolved at the presentation edge by
///          `settings_backup_messages.dart`.
///
///          **What the sixth slice added**: the ASCII token [emptyBackupReplaceErrorToken] carried by
///          the exception that rejects an empty replace (`backupImportFailureMessage` swaps it for the
///          copy table's `backupImpactEmptySource` cell — the same sentence as the import dialog's
///          blocking notice), and the five **table labels** (the keys are data and stay in the
///          validator's `backupTableNames`, the words moved into
///          `SettingsBackupStrings.backupTableLabels` and are looked up at the presentation edge by
///          `backupTableLabel` in `settings_backup_text.dart`). So the table names inside those old
///          sentences are looked up now too. This test is those changes' lock, in five parts:
///
///          1. **Token and sentence correspond one to one** (two `legacy*Sentences` tables and one
///             `legacyTableLabels` name → label table): all eighteen outcomes rendered, the Chinese side
///             **byte-identical** to the sentence in the source before the change, checked in both
///             directions (every enum value has a table entry, every entry hits a real enum value). This
///             is the only defence against "a producer forgot the token" and "a token appeared from
///             nowhere" — neither throws, they only silently drop or swap a sentence. The table labels
///             get the same treatment: the five Chinese labels pinned byte for byte, lined up with
///             `backupTableNames` in both directions, and an unrecognised key falling back to the key
///             itself.
///          2. **The receipt really follows the language**: the same results with the English table
///             render neither the Chinese sentence nor any wide/fullwidth character (the payloads are
///             now the **table names (keys) and counts**, ASCII data by nature, while the labels are
///             looked up — so this ruler measures the labels too, and an English label left in Chinese
///             surfaces right here). The multi-table **separator** ("、" against ", ") is measured here
///             as well.
///          3. **The payloads really splice into the sentence**: a different table name (key), count,
///             limit, version or age moves that half of the sentence; the age split into years / months
///             / days is pinned on both sides of its 365 and 30 day boundaries.
///          4. **The verdicts have not moved**: the notices' `severity` and the impacts' `severity` and
///             `icon` read as they did (they are now hard-coded by the named constructors or derived by
///             an exhaustive `switch`; the move did not touch them by one character).
///          5. **The sentence exists once in the source**: the validator's **converted stretch** must
///             hold **not one wide/fullwidth literal** (it still carries the deliberately left
///             `FormatException` technical strings, which is why that one is measured stretch by
///             stretch) while the **whole repository file** must hold none (its copy, labels included,
///             moved out this round), and the pre-move sentences must not survive anywhere in either
///             file. **The line this round flips**: the one-time "sentence deliberately left"
///             (`emptyBackupReplaceErrorMessage`) and the five table labels are gone — **not one
///             literal** of theirs may survive anywhere in the validator; what is pinned instead is the
///             ASCII token and its wiring to the copy table's cell (`backupImportFailureMessage`,
///             checked in both languages, plus a non-token exception passing through untouched).
///
///          **The byte-identity is measured, not asserted**: the two tables are copies of those
///          `message:` lines in the two files before the change, deliberately written out in the test.
///          **Do not bring them up to date with new copy.**
void main() {
  final zh = SettingsBackupStrings.forLanguage(AppLanguage.zh);
  final en = SettingsBackupStrings.forLanguage(AppLanguage.en);

  /// 中文：**迁移前那八句提示本身**（结局 → 它从前印什么）。这张表**故意写在测试里**、不从
  ///       `SettingsBackupStrings` 生成：它的全部价值就在于它是**旧知识的一份抄本**。载荷取一组固定
  ///       值（`'not-a-date'`、400 天、100 天、`v1.0.0` / `v1.1.0`），句子里的其余部分因此逐字节
  ///       可比。**不要拿它去追新文案。**
  /// English: **the eight notices from before the change** (outcome → what it used to print). This
  ///          table is **deliberately written in the test** rather than generated from
  ///          `SettingsBackupStrings`: its whole value is being **a copy of the old knowledge**. The payloads
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

  /// 中文：**迁移前那五个表名标签本身**（键 → 它从前印什么）——它们是迁移前校验器
  ///       `backupTableLabels` 那张表的抄本，这一轮（第六刀）搬进
  ///       `SettingsBackupStrings.backupTableLabels`；键是数据、留在 `backupTableNames` 里。
  ///       **不要拿它去追新文案。**
  /// English: **the five table labels from before the change** (key → what it used to print) — copies
  ///          of the validator's pre-move `backupTableLabels` table, which moved into
  ///          `SettingsBackupStrings.backupTableLabels` this round (the sixth slice); the keys are data
  ///          and stay in `backupTableNames`. **Do not bring it up to date with new copy.**
  const legacyTableLabels = <String, String>{
    'calculation_history': '历史',
    'notes': '笔记',
    'favorite_tools': '收藏',
    'recent_tools': '最近工具',
    'app_settings': '设置',
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

    // 中文：**表名标签也逐字节相同、两个方向都对齐 `backupTableNames`**：五个键的中文标签是迁移前
    //       校验器那张表的抄本；缺一格就有一位用户读到 "notes" 那样的键，多一格就是"标签被删了、
    //       词留着"。呈现边缘那条查表（`backupTableLabel`）也逐条量一次——旧句子里的表名正是走它。
    // English: **the table labels are byte-identical too, and both directions line up with
    //          `backupTableNames`**: the five Chinese labels are copies of the validator's pre-move
    //          table; one missing means a user reads a key such as "notes", one extra means "the key
    //          was deleted, the word stayed". The presentation edge's lookup (`backupTableLabel`) is
    //          measured entry by entry as well — that is the road the table names in those old
    //          sentences take.
    for (final entry in legacyTableLabels.entries) {
      expect(zh.backupTableLabels[entry.key], entry.value,
          reason: '${entry.key} 的中文标签与迁移前那个词不同了');
      expect(backupTableLabel(entry.key, zh), entry.value,
          reason: '${entry.key} 经呈现边缘查出来的标签与迁移前不同了');
    }
    expect(zh.backupTableLabels.keys.toSet(), backupTableNames.toSet(),
        reason: '中文标签表与 backupTableNames 对不上：'
            '${zh.backupTableLabels.keys.toSet().difference(backupTableNames.toSet())}');

    // 中文：**认不出的键回落到键本身**——迁移前 `backupTableLabels[name] ?? name` 的那只手。
    // English: **an unrecognised key falls back to the key itself** — the hand of the pre-move
    //          `backupTableLabels[name] ?? name`.
    expect(backupTableLabel('custom_table', zh), 'custom_table',
        reason: '认不出的表名应当原样印出来');
  });

  test('同一个令牌在英文表下不给中文：回执跟着语言走', () {
    // 中文：**载荷是表名（键）与计数**——本来就是 ASCII 的数据；标签由表查，所以量英文回执时
    //       连标签一起量（英文标签里漏一个宽/全角字就是这里现形）。十八种结局都过一遍。
    // English: **the payloads are table names (keys) and counts** — ASCII data by nature; the labels
    //          are looked up, so measuring the English receipts measures the labels too (one wide or
    //          fullwidth character in an English label surfaces right here). All eighteen outcomes go
    //          through.
    final warningMessages = [
      for (final kind in BackupPreviewWarningKind.values)
        backupPreviewWarningMessage(_warningFor(kind), en),
    ];
    final impactMessages = [
      for (final kind in BackupImportImpactKind.values)
        backupImportImpactMessage(_impactFor(kind), en),
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
        backupImportImpactMessage(_impactFor(kind), en),
        isNot(backupImportImpactMessage(_impactFor(kind), zh)),
        reason: '${kind.name} 在两种语言下印同一句话',
      );
    }
    // 中文：**英文表的表名标签也跟着语言走**：同一批键，标签既不是中文那个词、也不含宽/全角字符。
    // English: **the English table's labels follow the language too**: the same keys give labels that
    //          are neither the Chinese word nor hold a wide/fullwidth character.
    expect(en.backupTableLabels.keys.toSet(), backupTableNames.toSet(),
        reason: '英文标签表与 backupTableNames 对不上：'
            '${en.backupTableLabels.keys.toSet().difference(backupTableNames.toSet())}');
    for (final entry in legacyTableLabels.entries) {
      final label = en.backupTableLabels[entry.key];
      expect(label, isNotNull, reason: '英文标签表缺 ${entry.key}');
      expect(containsWideOrFullwidth(label!), isFalse,
          reason: '英文标签里还有宽/全角字符：$label');
      expect(label, isNot(entry.value),
          reason: '${entry.key} 在两种语言下印同一个标签');
    }
    // 中文：**多张表那句的连接符也跟着语言走、标签也一起查**：同一个影响、同一组真键，中文连接用
    //       「、」、标签查出中文；英文连接用 `, `、标签查出英文——连接符与标签是这两句话里按语言变
    //       的那两格。
    // English: **the multi-table separator follows the language too, and the labels are looked up with
    //          it**: the same impact with the same real keys joins with "、" and Chinese labels in
    //          Chinese, `, ` and English labels in English — the separator and the labels are the two
    //          cells of these sentences that change with the language.
    const overwrite = BackupImportImpact.overwriteTables(
        ['calculation_history', 'app_settings']);
    expect(backupImportImpactMessage(overwrite, zh), '会覆盖本机历史、设置数据');
    expect(
        backupImportImpactMessage(overwrite, en),
        'Overwrites the local History, Settings data');
    expect(backupTableLabel('custom_table', en), 'custom_table',
        reason: '英文表下认不出的表名也应当原样印出来');
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
    const deleteTable = BackupImportImpact.deleteTable('app_settings', 5);
    expect(deleteTable.tableName, 'app_settings');
    expect(deleteTable.count, 5);
    expect(backupImportImpactMessage(deleteTable, zh), '设置 将删除本机 5 条');
    expect(
      backupImportImpactMessage(
          const BackupImportImpact.reduceTable('notes', 2), zh),
      '笔记 将减少 2 条',
    );
    expect(
      backupImportImpactMessage(
          const BackupImportImpact.overwriteTables(
              ['calculation_history', 'app_settings']), zh),
      '会覆盖本机历史、设置数据',
    );
    const mergeAdds = BackupImportImpact.mergeAddsTables([
      BackupTableCount(name: 'calculation_history', count: 1),
      BackupTableCount(name: 'app_settings', count: 2),
    ]);
    expect(mergeAdds.additions.map((item) => item.name),
        ['calculation_history', 'app_settings']);
    expect(mergeAdds.additions.map((item) => item.count), [1, 2]);
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
    //       **校验器只量一段，数据层量整份文件**：校验器还有**有意留下**的界外文案——那批
    //       `FormatException` 技术串，所以它那一段从 `enum BackupPreviewWarningSeverity {` 量到
    //       `Map<String, Object?> parseBackupSnapshot(` 之前；数据层的文案这一轮连标签一起搬空了，
    //       于是整份文件都上尺子（比"只量一段"更严——它本来也没有界外文案了）。**两个端点都必须
    //       找得到、且成对有序**，否则扫的就可能是一段空字符串（那种"全过"最危险）。
    //
    //       两条底线的第二条：迁移前那十八句句子**在两个文件里一个字都不许留**，不管它藏在哪一段；
    //       带载荷的那几格连**半句**（前缀 / 后缀）一起查，免得模板被抄回来。**这一轮翻转的那一条**：
    //       从前的「唯一有意留下的句子」（`emptyBackupReplaceErrorMessage`）与五个表名标签都搬走了，
    //       所以校验器整份文件里连它们的**一个字面量**都不许有；留下的只有那枚 ASCII 令牌，钉它、
    //       以及它到文案表那一格的接线（`backupImportFailureMessage`，两种语言各查一次）。
    // English: **the scan asks "does this stretch hold any human-facing character"**, not "is a whole
    //          sentence identical": any wide/fullwidth literal reappearing in a converted stretch means
    //          somebody copied copy back (or wrote a new sentence), and the copy will not follow the
    //          language. The ruler is **the same one** as the calculator, tools and notes guards
    //          (`containsWideOrFullwidth`).
    //
    //          **The validator is measured stretch by stretch, the repository whole-file**: the
    //          validator still carries deliberately left copy — the `FormatException` technical
    //          strings — so its stretch runs from `enum BackupPreviewWarningSeverity {` up to (but not
    //          including) `Map<String, Object?> parseBackupSnapshot(`; the repository's copy, labels
    //          included, moved out this round, so its whole file goes under the ruler (stricter than
    //          "one stretch" — it no longer has any out-of-scope copy). **Both endpoints must be found,
    //          and in order**, or the scan could be measuring an empty string (the kind of "all pass"
    //          that is the most dangerous).
    //
    //          The second floor: the eighteen pre-move sentences must **not survive anywhere** in the
    //          two files, whatever stretch they hide in; the payload-carrying cells are checked by their
    //          **halves** (prefix / suffix) as well, so a template copied back cannot slip through.
    //          **The line this round flips**: the one-time "sentence deliberately left"
    //          (`emptyBackupReplaceErrorMessage`) and the five table labels are gone, so **not one
    //          literal** of theirs may survive anywhere in the validator; what is left is the ASCII
    //          token, which is pinned together with its wiring to the copy table's cell
    //          (`backupImportFailureMessage`, checked in both languages).
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

    final offenders = <String>[
      ...stringLiterals(validatorSource.substring(warningStart, warningEnd))
          .where(containsWideOrFullwidth)
          .map((literal) => 'backup_snapshot_validator.dart: $literal'),
      ...stringLiterals(repositorySource)
          .where(containsWideOrFullwidth)
          .map((literal) => 'data_backup_repository.dart: $literal'),
    ];
    expect(offenders, isEmpty,
        reason: '这些字面量应当走 SettingsBackupStrings（句子只住在那里）：\n'
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

    // 中文：**这一轮翻转的那一条**：从前「唯一有意留下」的句子（`emptyBackupReplaceErrorMessage`）
    //       与五个表名标签如今都搬走了——校验器整份文件里连它们的**一个字面量**都不许有。尺子是
    //       `stringLiterals` 的**整字面量相等**，不是宽/全角扫描：校验器还留着 `FormatException`
    //       那族中文技术串（有意留下，见 §5i）。留下的只有那枚 ASCII 令牌；异常到那句话的接线由
    //       `backupImportFailureMessage` 负责，下面两种语言各查一次，外加一枚非令牌异常原样穿过。
    // English: **the line this round flips**: the one-time "sentence deliberately left"
    //          (`emptyBackupReplaceErrorMessage`) and the five table labels are gone — **not one
    //          literal** of theirs may survive anywhere in the validator. The ruler is
    //          `stringLiterals`' **whole-literal equality**, not the wide/fullwidth sweep: the
    //          validator still carries the `FormatException` family's Chinese technical strings
    //          (deliberately left, see §5i). What is left is the ASCII token; the wiring from an
    //          exception to that sentence is `backupImportFailureMessage`'s job, checked once per
    //          language below, plus a non-token exception passing through untouched.
    final validatorLiterals = stringLiterals(validatorSource).toList();
    expect(validatorLiterals, contains(emptyBackupReplaceErrorToken),
        reason: '校验器里那枚拒绝空备份的令牌不见了');
    for (final label in legacyTableLabels.values) {
      expect(validatorLiterals, isNot(contains(label)),
          reason: '校验器里还留着搬走的表名标签：$label');
    }
    final emptySourceSentence =
        legacyImpactSentences[BackupImportImpactKind.emptySource]!;
    expect(validatorLiterals, isNot(contains(emptySourceSentence)),
        reason: '校验器里还留着搬走的那句空备份提示');
    expect(zh.backupImpactEmptySource, emptySourceSentence,
        reason: '影响表 emptySource 那格与迁移前那句话分家了');
    expect(
        backupImportFailureMessage(
            const FormatException(emptyBackupReplaceErrorToken), zh),
        emptySourceSentence,
        reason: '被拒绝的覆盖恢复印出来的不是迁移前那一句话');
    final enFailure = backupImportFailureMessage(
        const FormatException(emptyBackupReplaceErrorToken), en);
    expect(enFailure, en.backupImpactEmptySource,
        reason: '英文界面下被拒绝的覆盖恢复没有走英文表');
    expect(containsWideOrFullwidth(enFailure), isFalse,
        reason: '英文失败详情里还有宽/全角字符：$enFailure');
    expect(enFailure, isNot(emptySourceSentence),
        reason: '英文失败详情与中文那句一样');
    const technical = FormatException('notes 第 2 条记录不是有效对象');
    expect(backupImportFailureMessage(technical, zh), technical.toString(),
        reason: '非令牌异常应当原样穿过');
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
///       四个「表 +N」备料项、上限 24 / 500）。表名一律用**真的键**（`backupTableNames` 那一批）——
///       标签由表按语言查，所以中文那一遍量到的还是迁移前那几句话，英文那一遍连标签一起量。
/// English: the fixed payloads of the impact table (the same set the pre-move data-layer tests used:
///          notes 3, history 4, the four-table overwrite list, the four "table +N" ingredients, the
///          24 / 500 limits). The table names are the **real keys** (the `backupTableNames` batch) —
///          the labels are looked up per language, so the Chinese pass still measures the pre-move
///          sentences while the English pass measures the labels with them.
BackupImportImpact _impactFor(BackupImportImpactKind kind) {
  return switch (kind) {
    BackupImportImpactKind.deleteTable =>
      const BackupImportImpact.deleteTable('notes', 3),
    BackupImportImpactKind.reduceTable =>
      const BackupImportImpact.reduceTable('calculation_history', 4),
    BackupImportImpactKind.emptySource =>
      const BackupImportImpact.emptySource(),
    BackupImportImpactKind.overwriteTables =>
      const BackupImportImpact.overwriteTables(
          ['calculation_history', 'favorite_tools', 'recent_tools', 'app_settings']),
    BackupImportImpactKind.replaceKeepsIdentical =>
      const BackupImportImpact.replaceKeepsIdentical(),
    BackupImportImpactKind.mergeEmptySource =>
      const BackupImportImpact.mergeEmptySource(),
    BackupImportImpactKind.mergeAddsTables =>
      const BackupImportImpact.mergeAddsTables(<BackupTableCount>[
        BackupTableCount(name: 'calculation_history', count: 1),
        BackupTableCount(name: 'favorite_tools', count: 1),
        BackupTableCount(name: 'recent_tools', count: 2),
        BackupTableCount(name: 'app_settings', count: 1),
      ]),
    BackupImportImpactKind.mergeUpdatesSettings =>
      const BackupImportImpact.mergeUpdatesSettings(),
    BackupImportImpactKind.mergeKeepsRecentLimit =>
      const BackupImportImpact.mergeKeepsRecentLimit(24),
    BackupImportImpactKind.mergeKeepsHistoryLimit =>
      const BackupImportImpact.mergeKeepsHistoryLimit(500),
  };
}
