import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/platform/app_haptics.dart';
import 'package:nekocalc/l10n/app_language.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

/// 中文：本文件钉住**存储格式**。设置里有一批字段，它们的**值本身**是中文（`'跟随系统'`、
///       `'浅色'`、`'4 位'`、`'数学符号'`…），被写进 `app_settings` 表、被 `==` 比较、
///       被 `fromMap` 按字面值迁移。它们**不是标签**：界面翻译成英文时，这些话照翻，
///       但存进库里的那几个字节一个都不许动。翻错了不会有任何报错——`fromMap` 的 `??` 回退
///       只会静默变成默认值——所以只能靠测试钉住。
/// English: This file pins the **storage format**. Some settings fields have Chinese *values*
///          (`'跟随系统'`, `'浅色'`, `'4 位'`, `'数学符号'`, …) that are written to the `app_settings`
///          table, compared with `==`, and migrated by `fromMap` on their literal text. They are
///          **not labels**: translating the interface turns those labels English, but not one byte of
///          what is stored may move. A wrong translation raises nothing — `fromMap`'s `??` fallbacks
///          turn it into the default silently — so only tests can hold the line.
void main() {
  group('持久化令牌逐字节不变 / persisted tokens stay byte-identical', () {
    test('中文令牌原样读回（含空格的那几个）', () {
      final settings = AppSettings.fromMap(const {
        'haptics': 'true',
        'haptic_strength': AppHaptics.medium,
        'restore_state': 'true',
        'auto_save': 'true',
        'theme_mode': '跟随系统',
        'angle_mode': '弧度',
        'digits': '6 位',
        'expression_display': '数学符号',
        'group_thousands': 'false',
        'theme_id': 'roseCream',
        'language': 'zh',
      });

      // 中文：`'4 位'` / `'6 位'` / `'8 位'` 里那个空格也是格式的一部分。
      // English: The space inside `'4 位'` / `'6 位'` / `'8 位'` is part of the format too.
      expect(settings.themeModeLabel, '跟随系统');
      expect(settings.hapticStrength, '标准');
      expect(AppSettings.fromMap(const {'digits': '4 位'}).precision, 4);
      expect(AppSettings.fromMap(const {'digits': '8 位'}).precision, 8);
      expect(AppSettings.fromMap(const {'digits': '6 位'}).precision, 6);
      expect(settings.angleMode, 'RAD');
      expect(
        AppSettings.fromMap(const {'angle_mode': '角度'}).angleMode,
        'DEG',
      );
      expect(settings.expressionDisplayMode, '数学符号');
      expect(
        AppSettings.fromMap(const {'expression_display': '数学表达式'})
            .expressionDisplayMode,
        '数学表达式',
      );
    });

    test('旧值 `函数表达式` 的迁移仍然认得', () {
      // 中文：这是本项目最容易被"顺手清理"掉的一行——它按中文字面值比较，翻译界面时极像
      //       "该跟着一起翻"的候选。它必须是迁移来源，不是界面文案。
      // English: This is the line most likely to be "cleaned up" by accident: it compares Chinese
      //          literal text, which makes it look exactly like something that should be translated
      //          along with the UI. It is a migration source, not copy.
      expect(
        AppSettings.fromMap(const {'expression_display': '函数表达式'})
            .expressionDisplayMode,
        '数学表达式',
      );
    });

    test('缺省与坏值都回落到默认令牌', () {
      final empty = AppSettings.fromMap(const {});
      expect(empty.themeModeLabel, SettingsTokens.themeModeSystem);
      expect(empty.expressionDisplayMode, SettingsTokens.expressionDisplaySymbols);
      expect(empty.themeId, SettingsTokens.defaultThemeId);
      expect(empty.languageCode, SettingsTokens.defaultLanguageCode);

      // 中文：库里存着已删主题 / 未知语言时不抛错，回落到默认值。
      // English: A deleted theme or unknown language in the database must not throw; it falls back.
      expect(
        AppSettings.fromMap(const {'theme_id': '已删除的主题'}).themeId,
        '已删除的主题',
        reason: 'fromMap 原样带回，交给 CalcTheme.resolve / AppLanguage.fromCode 归一化',
      );
      expect(CalcTheme.resolve('已删除的主题'), CalcTheme.roseCream);
      expect(AppLanguage.fromCode('已删除的语言'), AppLanguage.zh);
    });

    test('AppSettings 相等性与 hashCode 认得出新字段', () {
      const base = AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: true,
        autoSaveHistory: true,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: SettingsTokens.themeModeSystem,
        expressionDisplayMode: SettingsTokens.expressionDisplaySymbols,
      );
      const otherTheme = AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: true,
        autoSaveHistory: true,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: SettingsTokens.themeModeSystem,
        expressionDisplayMode: SettingsTokens.expressionDisplaySymbols,
        themeId: 'lavenderMist',
      );
      const otherLanguage = AppSettings(
        haptics: true,
        hapticStrength: '标准',
        restoreState: true,
        autoSaveHistory: true,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: SettingsTokens.themeModeSystem,
        expressionDisplayMode: SettingsTokens.expressionDisplaySymbols,
        languageCode: 'en',
      );

      // 中文：`app.dart` 的"设置没变就不重建"依赖 `==`；新字段漏进 `==` 会让换主题后
      //       MaterialApp 整棵树不重建，界面停在旧配色。
      // English: `app.dart`'s "skip the rebuild when nothing changed" rests on `==`; a new field
      //          missing from it would leave the whole MaterialApp stale after a theme change.
      expect(base == otherTheme, isFalse);
      expect(base == otherLanguage, isFalse);
      expect(
        base ==
            AppSettings.fromMap(const {
              'theme_mode': SettingsTokens.themeModeSystem,
              'digits': SettingsTokens.digits6,
              'expression_display': SettingsTokens.expressionDisplaySymbols,
            }),
        isTrue,
      );
      expect(base.hashCode == otherTheme.hashCode, isFalse);
      expect(base.hashCode == otherLanguage.hashCode, isFalse);
    });

    test('默认令牌与主题表 / 语言表里的规范值一致', () {
      // 中文：`app_settings.dart` 刻意不 import Flutter（要能在纯 Dart 测试里跑），所以那边
      //       写的是字面量。这条测试就是那份字面量与真实常量之间的桥——两边一旦分叉，这里先红。
      // English: `app_settings.dart` deliberately imports no Flutter so it can run under plain Dart,
      //          which is why it spells the defaults as literals. This test is the bridge between
      //          those literals and the real constants; if the two ever drift, this goes red first.
      expect(SettingsTokens.defaultThemeId, CalcTheme.fallback.id);
      expect(SettingsTokens.defaultThemeId, CalcTheme.all.first.id);
      expect(SettingsTokens.defaultLanguageCode, AppLanguage.fallback.code);
      expect(AppLanguage.fallback, AppLanguage.zh);
    });
  });
}
