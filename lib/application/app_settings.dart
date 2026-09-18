/// 中文：写进 `app_settings` 表的**持久化令牌**——它们同时也是 `fromMap` 认识的旧值，
///       所以是「存储格式」而不是「界面标签」。改动这里等于改存储格式，会让已经在用户库里
///       的值对不上，而 `fromMap` 的 `??` 回退不会报错，只会静默变成默认值。
///       **界面显示的那句话在别处**（设置页的语言表 `SettingsStrings`）；两边在中文下取值相同，
///       是巧合，不是同一件事——`settings_tokens_test.dart` 钉住了这一点。
/// English: **Persisted tokens** written into the `app_settings` table. They are also the legacy
///          values `fromMap` recognises, so this is a *storage format*, not a set of UI labels.
///          Changing one changes that format: values already in a user's database stop matching, and
///          `fromMap`'s `??` fallbacks raise nothing — they just silently become the default.
///          **The string shown on screen lives elsewhere** (the settings page's `SettingsStrings`
///          tables); that the two coincide in Chinese is a coincidence, not an identity, and
///          `settings_tokens_test.dart` pins the distinction.
class SettingsTokens {
  const SettingsTokens._();

  static const String themeModeSystem = '跟随系统';
  static const String themeModeLight = '浅色';
  static const String themeModeDark = '深色';

  static const String angleModeRadians = '弧度';
  static const String angleModeDegrees = '角度';

  static const String digits4 = '4 位';
  static const String digits6 = '6 位';
  static const String digits8 = '8 位';

  static const String expressionDisplaySymbols = '数学符号';
  static const String expressionDisplayMath = '数学表达式';

  /// 中文：`expression_display` 的**旧值**。它只作为迁移来源存在，今天的界面不再写它。
  /// English: Legacy `expression_display` value; it survives only as a migration source.
  static const String expressionDisplayFunctionLegacy = '函数表达式';

  /// 中文：`theme_id` 与 `language` 的默认值。两者都是 ASCII 稳定标识，不是标签。
  /// English: Defaults for `theme_id` and `language`: stable ASCII identifiers, not labels.
  ///       与 `CalcTheme.fallback.id` / `AppLanguage.zh.code` 的一致性由测试钉住，不靠 import
  ///       ——`app_settings.dart` 不依赖 Flutter，才能在纯 Dart 测试里跑。
  ///       Their agreement with `CalcTheme.fallback.id` / `AppLanguage.zh.code` is pinned by a test
  ///       rather than an import, so this file stays Flutter-free and testable in plain Dart.
  static const String defaultThemeId = 'roseCream';
  static const String defaultLanguageCode = 'zh';
}

class AppSettings {
  const AppSettings({
    required this.haptics,
    required this.hapticStrength,
    required this.restoreState,
    required this.autoSaveHistory,
    required this.angleMode,
    required this.precision,
    required this.themeModeLabel,
    required this.expressionDisplayMode,
    this.groupThousands = false,
    this.themeId = SettingsTokens.defaultThemeId,
    this.languageCode = SettingsTokens.defaultLanguageCode,
  });

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(
      haptics: map['haptics'] != 'false',
      hapticStrength: map['haptic_strength'] ?? '标准',
      restoreState: map['restore_state'] != 'false',
      autoSaveHistory: map['auto_save'] != 'false',
      angleMode: map['angle_mode'] == SettingsTokens.angleModeDegrees
          ? 'DEG'
          : 'RAD',
      precision: switch (map['digits']) {
        SettingsTokens.digits4 => 4,
        SettingsTokens.digits8 => 8,
        _ => 6,
      },
      themeModeLabel: map['theme_mode'] ?? SettingsTokens.themeModeSystem,
      expressionDisplayMode:
          map['expression_display'] == SettingsTokens.expressionDisplayFunctionLegacy
              ? SettingsTokens.expressionDisplayMath
              : map['expression_display'] ?? SettingsTokens.expressionDisplaySymbols,
      groupThousands: map['group_thousands'] == 'true',
      themeId: map['theme_id'] ?? SettingsTokens.defaultThemeId,
      languageCode: map['language'] ?? SettingsTokens.defaultLanguageCode,
    );
  }

  static const fallback = AppSettings(
    haptics: true,
    hapticStrength: '标准',
    restoreState: true,
    autoSaveHistory: true,
    angleMode: 'RAD',
    precision: 6,
    themeModeLabel: SettingsTokens.themeModeSystem,
    expressionDisplayMode: SettingsTokens.expressionDisplaySymbols,
    groupThousands: false,
  );

  final bool haptics;
  final String hapticStrength;
  final bool restoreState;
  final bool autoSaveHistory;
  final String angleMode;
  final int precision;
  final String themeModeLabel;
  final String expressionDisplayMode;
  final bool groupThousands;

  /// 中文：用户选中的 `CalcTheme.id`（`'roseCream'` / `'lavenderMist'` / `'peachSugar'`）。
  ///       **不是标签**：翻译界面时不许跟着翻，`CalcTheme.resolve` 认不出就回落到默认主题。
  /// English: The chosen `CalcTheme.id` (`'roseCream'` / `'lavenderMist'` / `'peachSugar'`).
  ///          **Not a label** — it must not be translated along with the interface; `CalcTheme.resolve`
  ///          falls back to the default theme for anything it does not recognise.
  final String themeId;

  /// 中文：用户选中的界面语言代码（`'zh'` / `'en'`）。同样是稳定标识，不是语言的自称。
  /// English: Chosen UI language code (`'zh'` / `'en'`) — again a stable identifier, not an endonym.
  final String languageCode;

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.haptics == haptics &&
        other.hapticStrength == hapticStrength &&
        other.restoreState == restoreState &&
        other.autoSaveHistory == autoSaveHistory &&
        other.angleMode == angleMode &&
        other.precision == precision &&
        other.themeModeLabel == themeModeLabel &&
        other.expressionDisplayMode == expressionDisplayMode &&
        other.groupThousands == groupThousands &&
        other.themeId == themeId &&
        other.languageCode == languageCode;
  }

  @override
  int get hashCode => Object.hash(
      haptics,
      hapticStrength,
      restoreState,
      autoSaveHistory,
      angleMode,
      precision,
      themeModeLabel,
      expressionDisplayMode,
      groupThousands,
      themeId,
      languageCode);
}
