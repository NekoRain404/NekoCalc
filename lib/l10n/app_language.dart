import 'package:flutter/widgets.dart';

/// 中文：界面语言。`code` 是**持久化令牌**（写进 `app_settings.language`，`'zh'` / `'en'`），
///       `label` 是语言自称（endonym）——它刻意**不随界面语言变化**：选择器要在一个还没生效的语言里
///       指出另一个语言，把 "English" 翻成"英语"对只看得懂英文的用户是反向的。所以这一条不是漏翻。
/// English: A UI language. `code` is the **persisted token** (written to `app_settings.language` as
///          `'zh'` / `'en'`); `label` is the endonym, deliberately **not** translated with the
///          interface: a picker has to name another language while the current one is still in effect,
///          and rendering "English" as "英语" is backwards for the user who only reads English. This is
///          an intentional exemption, not a missed translation.
enum AppLanguage {
  zh('zh', '中文'),
  en('en', 'English');

  const AppLanguage(this.code, this.label);

  /// 中文：持久化令牌，同时是 BCP-47 的语言子标签。
  /// English: Persisted token; also the BCP-47 language subtag.
  final String code;

  /// 中文：语言自称，见类文档。**不参与翻译**。
  /// English: Endonym; see the class docs. **Never translated.**
  final String label;

  /// 中文：没有选择时用的语言，也是"默认态与接入前逐字节相同"所要求的那一种。
  /// English: Language used when nothing is chosen, and the one the "default state stays
  ///          byte-identical" rule requires.
  static const AppLanguage fallback = AppLanguage.zh;

  /// 中文：把持久化的语言代码解成枚举；认不出的代码回落到 [fallback]，不会抛也不会变成 `null`。
  ///       **入参是持久化令牌，不是 `label`**——把 `'中文'` 喂进来会拿到 fallback，恰好也是中文，
  ///       所以这种错误在中文下不会显形；`app_language_test.dart` 用英文那侧钉住了它。
  /// English: Resolves a persisted language code; anything unrecognised falls back to [fallback]
  ///          instead of throwing or returning `null`. **The argument is a persisted token, not a
  ///          `label`** — feeding it `'中文'` yields the fallback, which happens to be Chinese too, so
  ///          that mistake is invisible from Chinese; `app_language_test.dart` pins it from the English
  ///          side.
  static AppLanguage fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return fallback;
  }

  /// 中文：当前界面语言——`AppLanguageScope` 是它唯一的来源，没有作用域时用 [fallback]。
  ///       与 `CalcTheme.of` 同一套做法：**调用方只问"现在是什么语言"，不管它从哪来**。
  /// English: The active UI language, sourced only from an `AppLanguageScope`, with [fallback] when
  ///          there is none. Same shape as `CalcTheme.of`: callers ask *what* the language is, never
  ///          *where* it came from.
  static AppLanguage of(BuildContext context) {
    return AppLanguageScope.maybeOf(context) ?? fallback;
  }
}

/// 中文：把当前界面语言送进 `AppLanguage.of` 的载体。安装位置与理由同 `CalcThemeScope`：
///       `app.dart` 用 `MaterialApp.builder` 装在 **Navigator 之上**，否则 `Navigator.push`
///       压上来的设置页看不见它，语言选择器就永远停在旧语言。
/// English: Carries the active UI language into `AppLanguage.of`. Installed the same way and for the
///          same reason as `CalcThemeScope`: `app.dart` uses `MaterialApp.builder` to place it **above
///          the Navigator**, otherwise a `Navigator.push`ed settings page cannot see it and the
///          language picker would stay stuck on the old language.
class AppLanguageScope extends InheritedWidget {
  const AppLanguageScope({
    required this.language,
    required super.child,
    super.key,
  });

  final AppLanguage language;

  /// 中文：没有作用域时返回 `null`，由 [AppLanguage.of] 回落到中文——既有的
  ///       `MaterialApp(home: SettingsPage(db: db))` 测试因此不必套一层作用域。
  /// English: `null` without a scope, so `AppLanguage.of` falls back to Chinese and the existing
  ///          `MaterialApp(home: SettingsPage(db: db))` tests need no wrapper.
  static AppLanguage? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLanguageScope>()?.language;
  }

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) {
    return oldWidget.language != language;
  }
}
