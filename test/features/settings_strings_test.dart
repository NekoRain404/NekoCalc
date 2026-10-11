import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/features/settings/presentation/settings_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

/// 中文：设置页文案表的三条护栏。
///       1) 中文表的「令牌标签」必须与 `SettingsTokens` **逐字节相同**——这是"默认态不变"的
///          具体要求：默认语言是中文，所以设置页上每个字都得和接入多语言之前一模一样。
///       2) 英文表里不许出现汉字——漏翻一条就是英文界面里蹦出一句中文，肉眼容易漏，扫描不会。
///       3) 设置页的源码里（除了这张表本身）不许再留中文字符串字面量——这条是**面向未来**的：
///          以后往设置页加文案时，忘记走表就会被这条测试挡住。它扫的是源码文本，不依赖任何
///          反射，所以新增字段不需要同时改测试。
/// English: Three guard rails for the settings copy table.
///          1) The Chinese table's token labels must be **byte-identical** to `SettingsTokens` — the
///             concrete form of "the default state does not change": the default language is Chinese,
///             so every word on the page must read exactly as it did before i18n existed.
///          2) The English table must contain no CJK characters — a missed translation drops a Chinese
///             sentence into the English UI, easy to miss by eye and impossible to miss by scan.
///          3) No Chinese string literal may remain in the settings page's sources other than this
///             table. This one faces **forward**: the next person adding copy to the settings page is
///             stopped here if they forget the table. It scans source text rather than reflecting over
///             fields, so adding a field does not also require editing this test.
void main() {
  final zh = SettingsStrings.forLanguage(AppLanguage.zh);
  final en = SettingsStrings.forLanguage(AppLanguage.en);

  test('中文表的令牌标签与 SettingsTokens 逐字节相同', () {
    // 中文：左边是**给人看的标签**，右边是**存进库的令牌**。中文下两者相等，英文下必须不等——
    //       相等是巧合，不是同一个东西；把它们合并成一个常量，翻译一改就会静默改掉存储格式。
    // English: The left side is a **human-facing label**, the right side a **stored token**. They are
    //          equal in Chinese and must differ in English: the equality is a coincidence, not an
    //          identity. Merging them into one constant would let a translation edit silence the
    //          storage format.
    expect(zh.themeModeSystemLabel, '跟随系统');
    expect(zh.themeModeLightLabel, '浅色');
    expect(zh.themeModeDarkLabel, '深色');
    expect(zh.angleRadiansLabel, '弧度');
    expect(zh.angleDegreesLabel, '角度');
    expect(zh.digits4Label, '4 位');
    expect(zh.digits6Label, '6 位');
    expect(zh.digits8Label, '8 位');
    expect(zh.expressionSymbolsLabel, '数学符号');
    expect(zh.expressionMathLabel, '数学表达式');
    expect(zh.hapticsOffLabel, '关闭');
    expect(zh.hapticLightLabel, '轻');
    expect(zh.hapticStandardLabel, '标准');
    expect(zh.hapticStrongLabel, '强');

    // 中文：`percentage_mode` 的两个令牌是 **ASCII**（`'direct'` / `'relative'`），所以它属于
    //       「标签与令牌本来就不等」的那一类（与主题名同形）——这里钉的是标签本身，
    //       以及**令牌绝不会被当标签显示出去**。
    // English: the two `percentage_mode` tokens are **ASCII** (`'direct'` / `'relative'`), so this one
    //          belongs to the "label never equalled the token" family (the same shape as theme names);
    //          what is pinned here is the labels themselves, and that **a token is never rendered as a
    //          label**.
    expect(zh.percentageDirectLabel, '直接');
    expect(zh.percentageRelativeLabel, '相对');
    expect(en.percentageDirectLabel, 'Direct');
    expect(en.percentageRelativeLabel, 'Relative');
    expect(
        en.percentageModeLabel(SettingsTokens.percentageRelative), 'Relative');
    expect(zh.percentageModeLabel('库里没见过的值'), '直接',
        reason: '认不出就回落到默认那一侧，而不是把令牌原样显示出去');

    // 中文：而英文侧真的换了，否则上面那些"相等"只是把令牌抄了一遍。
    // English: And the English side really differs, otherwise the equalities above would just be the
    //          tokens copied out again.
    for (final pair in <List<String>>[
      [zh.themeModeSystemLabel, en.themeModeSystemLabel],
      [zh.themeModeLightLabel, en.themeModeLightLabel],
      [zh.themeModeDarkLabel, en.themeModeDarkLabel],
      [zh.angleRadiansLabel, en.angleRadiansLabel],
      [zh.angleDegreesLabel, en.angleDegreesLabel],
      [zh.digits4Label, en.digits4Label],
      [zh.digits6Label, en.digits6Label],
      [zh.digits8Label, en.digits8Label],
      [zh.expressionSymbolsLabel, en.expressionSymbolsLabel],
      [zh.expressionMathLabel, en.expressionMathLabel],
      [zh.hapticsOffLabel, en.hapticsOffLabel],
      [zh.hapticStandardLabel, en.hapticStandardLabel],
    ]) {
      expect(pair[0], isNot(pair[1]), reason: '「${pair[0]}」在英文表里没换');
    }
  });

  test('令牌映射认得出每一个被持久化的值', () {
    expect(zh.themeModeLabel('跟随系统'), '跟随系统');
    expect(zh.themeModeLabel('浅色'), '浅色');
    expect(zh.themeModeLabel('深色'), '深色');
    expect(zh.themeModeLabel('库里没见过的值'), '跟随系统',
        reason: '认不出就回落到默认那格，而不是把令牌原样显示出去');

    expect(zh.angleModeLabel('弧度'), '弧度');
    expect(zh.angleModeLabel('角度'), '角度');
    expect(zh.angleModeLabel('弧度 '), '弧度', reason: '带空格的值同样认不出，回落到弧度');

    expect(zh.digitsLabel('4 位'), '4 位');
    expect(zh.digitsLabel('6 位'), '6 位');
    expect(zh.digitsLabel('8 位'), '8 位');

    expect(zh.expressionDisplayLabel('数学符号'), '数学符号');
    expect(zh.expressionDisplayLabel('数学表达式'), '数学表达式');
    expect(zh.expressionDisplayLabel('函数表达式'), '数学表达式',
        reason: '旧值即使漏过了 fromMap 的迁移，也不该把令牌本身显示给用户');

    expect(zh.hapticStrengthLabel('轻'), '轻');
    expect(zh.hapticStrengthLabel('标准'), '标准');
    expect(zh.hapticStrengthLabel('强'), '强');
  });

  test('主题配色的中文名与 CalcTheme.name 逐套相同', () {
    // 中文：**这一条是"主题配色那一行在英文界面下仍是中文"这个缺陷的到期日。** 从前那一行读的是
    //       `CalcTheme.resolve(id).name`，而 `name` 是中文常量，于是英文界面上那一格永远写着
    //       「玫瑰奶霜」。现在名字住在这张表里，中文侧必须与 `CalcTheme.name` **逐字节相同**
    //       （默认态不变），而这一条是逐套主题走的：**任何一套认不出来、或者 `CalcTheme` 里新增了
    //       一套而这里没加名字，都会红**——漏一套时那一行会静默显示成玫瑰奶霜，屏幕上没有提示。
    // English: **This is the expiry assertion for "the colour-theme row stays Chinese in an English
    //          interface"**: that row used to read `CalcTheme.resolve(id).name`, and `name` is a Chinese
    //          constant, so the cell read 「玫瑰奶霜」 in English too. The names now live in this table
    //          and the Chinese side must be **byte-identical** to `CalcTheme.name` (the default state
    //          does not change). The loop walks every theme: **an unrecognised theme, or a `CalcTheme`
    //          added without a name here, goes red** — a missing one would silently render Rose Cream
    //          with nothing on screen to say so.
    for (final theme in CalcTheme.all) {
      expect(zh.themeLabel(theme.id), theme.name,
          reason: '${theme.id} 的中文名与 CalcTheme.name 不一致');
    }
    expect(zh.themeRoseCreamLabel, '玫瑰奶霜');
    expect(zh.themeLavenderMistLabel, '薰衣草雾');
    expect(zh.themePeachSugarLabel, '蜜桃砂糖');

    // 中文：**`id` 是持久化令牌，一个字节都不许翻译**；英文侧换的只是屏幕上那三个名字。
    // English: **the `id` is a persisted token and must not be translated by one byte**; what changes
    //          on the English side is only the three names on screen.
    expect(const <String>['roseCream', 'lavenderMist', 'peachSugar'],
        CalcTheme.all.map((theme) => theme.id).toList());
    expect(en.themeRoseCreamLabel, 'Rose Cream');
    expect(zh.themeLabel('库里没见过的主题'), '玫瑰奶霜',
        reason: '认不出就回落到默认那一套，而不是把 id 原样显示出去');
  });

  test('带参数的文案把参数放进去了', () {
    expect(zh.importDone('合并导入', '完成'), '合并导入完成：完成');
    expect(en.importDone('Merge', 'done'), 'Merge finished: done');
    expect(zh.reportMode('合并导入'), '模式：合并导入');
    expect(en.reportMode('Merge'), 'Mode: Merge');
    expect(zh.reportSkipped(3), contains('3'));
    expect(en.reportSkipped(3), contains('3'));
    expect(zh.reportTableRow('历史', 1, 2, 3, '+1', ''), contains('历史：文件 1'));
    expect(en.reportTableRow('History', 1, 2, 3, '+1', ''),
        contains('History: file 1'));
    expect(zh.backupPreviewSummary('v1', 'now', '3 行', '摘要'),
        '版本：v1\n时间：now\n总计：3 行\n摘要');
    expect(en.backupPreviewSummary('v1', 'now', '3 rows', 'summary'),
        'Version: v1\nExported: now\nTotal: 3 rows\nsummary');
    expect(zh.backupPlanRow(1, 2, 3), '本机 1 · 文件 2 · 导入后 3');
    expect(en.backupPlanRow(1, 2, 3), 'device 1 · file 2 · after 3');
    expect(zh.currentVersion('v1'), '当前版本：v1');
    expect(en.currentVersion('v1'), 'Current version: v1');
    expect(zh.diagnosticPlatform('android'), '平台：android');
    expect(en.diagnosticPlatform('android'), 'Platform: android');
  });

  test('语言自称是 endonym，且 fromCode 只认 code', () {
    // 中文：`label` 刻意不翻译：选择器要在当前语言还没换过去时指出另一个语言。
    // English: `label` is deliberately untranslated: the picker must name another language while the
    //          current one is still in effect.
    expect(AppLanguage.zh.label, '中文');
    expect(AppLanguage.en.label, 'English');

    expect(AppLanguage.fromCode('zh'), AppLanguage.zh);
    expect(AppLanguage.fromCode('en'), AppLanguage.en);
    expect(AppLanguage.fromCode(null), AppLanguage.zh);
    expect(AppLanguage.fromCode(''), AppLanguage.zh);
    expect(AppLanguage.fromCode('中文'), AppLanguage.zh,
        reason: '拿自称当 code 会悄悄落到中文——中文那侧看不出问题，英文那侧才显形');
    expect(AppLanguage.fromCode('English'), AppLanguage.zh);
    expect(AppLanguage.fromCode('en-US'), AppLanguage.zh,
        reason: '目前只认精确的 code；带地区的标签不在支持范围内，回落到默认');
  });

  test('英文表里没有汉字', () {
    // 中文：逐字段扫描英文表。改成反射就得不依赖 Flutter 的镜像，得不偿失；这里选择显式列举
    //       有文案的字段——加字段时若忘了补进这张清单，下面那条源码扫描仍然兜得住。
    // English: Scans the English table field by field. Reflection would mean mirrors, unavailable
    //          under Flutter; so the fields carrying copy are listed explicitly. If a new field is
    //          missed here, the source scan below still catches it.
    final copy = <String, String>{
      'backTooltip': en.backTooltip,
      'pageTitle': en.pageTitle,
      'sectionAppearance': en.sectionAppearance,
      'sectionExperience': en.sectionExperience,
      'sectionData': en.sectionData,
      'sectionAbout': en.sectionAbout,
      'themeModeTileTitle': en.themeModeTileTitle,
      'themeTileTitle': en.themeTileTitle,
      'languageTileTitle': en.languageTileTitle,
      'angleModeTileTitle': en.angleModeTileTitle,
      'numberFormatTileTitle': en.numberFormatTileTitle,
      'decimalPlacesTileTitle': en.decimalPlacesTileTitle,
      'expressionDisplayTileTitle': en.expressionDisplayTileTitle,
      'hapticsTileTitle': en.hapticsTileTitle,
      'hapticStrengthTileTitle': en.hapticStrengthTileTitle,
      'restoreStateTileTitle': en.restoreStateTileTitle,
      'autoSaveHistoryTileTitle': en.autoSaveHistoryTileTitle,
      'localDataTitle': en.localDataTitle,
      'counting': en.counting,
      'refreshDataStats': en.refreshDataStats,
      'exportBackupTitle': en.exportBackupTitle,
      'importBackupTitle': en.importBackupTitle,
      'saveFile': en.saveFile,
      'chooseFile': en.chooseFile,
      'processing': en.processing,
      'details': en.details,
      'exportFailedTitle': en.exportFailedTitle,
      'importFailedTitle': en.importFailedTitle,
      'importResultTitle': en.importResultTitle,
      'cancel': en.cancel,
      'importMerge': en.importMerge,
      'importReplace': en.importReplace,
      'importWarning': en.importWarning,
      'backupFileTitle': en.backupFileTitle,
      'localCurrentTitle': en.localCurrentTitle,
      'backupWarningsTitle': en.backupWarningsTitle,
      'unknownValue': en.unknownValue,
      'aboutTileTitle': en.aboutTileTitle,
      'checkUpdateTitle': en.checkUpdateTitle,
      'checking': en.checking,
      'helpFeedbackTitle': en.helpFeedbackTitle,
      'helpFeedbackValue': en.helpFeedbackValue,
      'privacyPolicyTitle': en.privacyPolicyTitle,
      'privacyPolicyBody': en.privacyPolicyBody,
      'viewRelease': en.viewRelease,
      'viewReleaseNotes': en.viewReleaseNotes,
      'openReleasesPage': en.openReleasesPage,
      'close': en.close,
      'done': en.done,
      'gotIt': en.gotIt,
      'aboutTagline': en.aboutTagline,
      'aboutChipScience': en.aboutChipScience,
      'aboutChipEngineering': en.aboutChipEngineering,
      'aboutChipGraph': en.aboutChipGraph,
      'aboutChipSqlite': en.aboutChipSqlite,
      'aboutPrivacyNote': en.aboutPrivacyNote,
      'channelName': en.channelName,
      'openSourceTitle': en.openSourceTitle,
      'openSourceBody': en.openSourceBody,
      'openSourceAction': en.openSourceAction,
      'helpIntro': en.helpIntro,
      'diagnosticReportTitle': en.diagnosticReportTitle,
      'copyReport': en.copyReport,
      'submitIssue': en.submitIssue,
      'reportCopied': en.reportCopied,
      'diagnosticHeading': en.diagnosticHeading,
      'diagnosticPrompt': en.diagnosticPrompt,
      'linkOpenFailed': en.linkOpenFailed,
      'themeModeSystemLabel': en.themeModeSystemLabel,
      'themeModeLightLabel': en.themeModeLightLabel,
      'themeModeDarkLabel': en.themeModeDarkLabel,
      'angleRadiansLabel': en.angleRadiansLabel,
      'angleDegreesLabel': en.angleDegreesLabel,
      'digits4Label': en.digits4Label,
      'digits6Label': en.digits6Label,
      'digits8Label': en.digits8Label,
      'expressionSymbolsLabel': en.expressionSymbolsLabel,
      'expressionMathLabel': en.expressionMathLabel,
      'percentageModeTileTitle': en.percentageModeTileTitle,
      'percentageDirectLabel': en.percentageDirectLabel,
      'percentageRelativeLabel': en.percentageRelativeLabel,
      'hapticsOffLabel': en.hapticsOffLabel,
      'hapticLightLabel': en.hapticLightLabel,
      'hapticStandardLabel': en.hapticStandardLabel,
      'hapticStrongLabel': en.hapticStrongLabel,
      'themeRoseCreamLabel': en.themeRoseCreamLabel,
      'themeLavenderMistLabel': en.themeLavenderMistLabel,
      'themePeachSugarLabel': en.themePeachSugarLabel,
    };
    for (final entry in copy.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} 是空的');
      expect(_containsCjk(entry.value), isFalse,
          reason: '${entry.key} 英文表里还有汉字：${entry.value}');
    }
    // 中文：中文侧同样不许有空串——空串在屏幕上是"这一格什么都没有"，最难发现的一类漏翻。
    // English: The Chinese side must hold no empty string either: on screen it renders as a blank
    //          cell, the hardest kind of missing copy to notice.
    expect(zh.pageTitle.trim(), isNotEmpty);
    expect(zh.privacyPolicyBody.trim(), isNotEmpty);
  });

  test('设置页源码里除了文案表再没有中文字符串字面量', () {
    final directory = Directory('lib/features/settings/presentation');
    expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    final offenders = <String>[];
    for (final entity in directory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // 中文：文案表自己就是汉字住的地方，跳过它（设置页现在有两张表：原来那张与备份那一族
      //       单独的 `settings_backup_strings.dart`——两张都按同一套理由跳出）。
      // English: The tables are where the Chinese is *supposed* to live; skip them (the settings page
      //          now has two: the original and the backup family's own
      //          `settings_backup_strings.dart` — both step out for the same reason).
      final fileName = entity.uri.pathSegments.last;
      if (fileName == 'settings_strings.dart' ||
          fileName == 'settings_backup_strings.dart') {
        continue;
      }
      final source = stripComments(entity.readAsStringSync());
      for (final literal in stringLiterals(source)) {
        if (containsWideOrFullwidth(literal)) {
          offenders.add('${entity.path}: $literal');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: '这些界面字面量还没走 SettingsStrings：\n${offenders.join('\n')}');
  });
}

/// 中文：CJK 统一表意文字区（含扩展 A）。够用了：本项目的界面文案都落在这里。
/// English: The CJK Unified Ideographs block (plus Extension A) — enough, since this project's UI
///          copy lives there.
bool _containsCjk(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}
