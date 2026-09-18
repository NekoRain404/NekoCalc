import 'package:flutter/widgets.dart';

import '../../l10n/app_language.dart';

/// 中文：外壳与抽屉（`lib/shared/presentation`）的界面文案表，**按功能切分**——一张表、表里并排放
///       所有语言。机制本身（为什么是手写分表而不是 ARB / `gen-l10n`、为什么表是 `static final`
///       而不是 `const`）与设置页那张表共用一套理由，写在 `settings_strings.dart` 的文件头上，
///       这里不重抄。
///
///       **加一种语言要动几个文件**：这个文件（加一份 `SharedStrings` 表 + `of` 里加一个分支，
///       `forLanguage` 的 switch 必须穷尽 `AppLanguage`，由分析器检查）+ `AppLanguage` 里加一个
///       枚举值。
///
///       **本表只装"给人看的字"。** 同一个目录下有三类中文字面量**故意不进来**，各自有各自的理由：
///       1. **调试断言的那句话**（`app_shell.dart` 里 `assert` 的第二参数）。它是写给开发者看的，
///          用户永远看不到，形状与 `calculator_key_dispatch.dart` 里那句逐字相同。
///       2. **`CalcTheme.name` 的六个主题名**（`calc_theme.dart`）。它们是 `const`，进不了这张
///          （`static final`）表；而屏幕上那三个名字自上一轮起由
///          `SettingsStrings.themeLabel(themeId)` 提供（中文侧与它们逐字节相同，由
///          `settings_strings_test.dart` 逐套主题钉住）。所以它们**不再上屏**，只作为那条断言的
///          参照物留着——是**已知的残留**，不是漏翻。
///       3. **持久化令牌**（`CalcTheme.id` 的 `roseCream` / `lavenderMist` / `peachSugar`）。
///          它们住在 `calc_theme.dart` 与 `SettingsTokens` 里，是存进库的格式不是屏幕上的字，
///          而且本来就不含汉字。
/// English: The string table for the shell and drawer (`lib/shared/presentation`), **split by
///          feature** — one table holding every language side by side. The mechanism itself (why
///          hand-written tables rather than ARB / `gen-l10n`) shares one set of reasons with the
///          settings table and is written on `settings_strings.dart`'s file head; it is not copied
///          again here. Unlike those two tables this one has no parameterised copy, so its fields are
///          plain `String`s and the tables are `const` — the `static final` the other tables need is
///          forced by their closures, and a closure is not a constant expression.
///
///          **Adding a language touches**: this file (one more `SharedStrings` table plus one more
///          branch in `of`, whose switch over `AppLanguage` the analyzer checks for exhaustiveness)
///          and `AppLanguage` (one more enum value).
///
///          **This table holds human-facing text only.** Three kinds of Chinese literal in the same
///          directory are **deliberately absent**, each for its own reason:
///          1. **The debug assertion's sentence** (the second argument of the `assert` in
///             `app_shell.dart`). It is written for developers and never reaches a user; its shape is
///             item-for-item the one in `calculator_key_dispatch.dart`.
///          2. **The six `CalcTheme.name` theme names** (`calc_theme.dart`). They are `const` and
///             cannot come from this (`static final`) table, and since the previous round the three
///             on-screen names come from `SettingsStrings.themeLabel(themeId)` (their Chinese side is
///             byte-identical to these, pinned theme by theme in `settings_strings_test.dart`). So
///             they **no longer reach the screen**; they survive only as that assertion's reference —
///             a **known remainder**, not a missed translation.
///          3. **Persisted tokens** (`CalcTheme.id`'s `roseCream` / `lavenderMist` / `peachSugar`).
///             They live in `calc_theme.dart` and `SettingsTokens`: storage format rather than
///             on-screen text, and they hold no CJK anyway.
@immutable
class SharedStrings {
  const SharedStrings({
    // —— 外壳 ☰ 与抽屉 ——
    required this.openNavigationTooltip,
    required this.navCalculator,
    required this.navTools,
    required this.navGraph,
    required this.navNotes,
    required this.navSettings,
  });

  // —— 外壳 ☰ 与抽屉 ——
  final String openNavigationTooltip;
  final String navCalculator;
  final String navTools;
  final String navGraph;
  final String navNotes;
  final String navSettings;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过，
  ///       而不是静默回落到中文。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here rather than silently falling back to Chinese.
  static SharedStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。两条路径共用这一个
  ///       switch，不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext`. Both routes share this
  ///          one switch, so they cannot drift apart.
  static SharedStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => sharedZh,
      AppLanguage.en => sharedEn,
    };
  }

  static const SharedStrings sharedZh = SharedStrings(
    openNavigationTooltip: '打开导航',
    navCalculator: '计算',
    navTools: '工具',
    navGraph: '图形',
    navNotes: '笔记',
    navSettings: '设置',
  );

  static const SharedStrings sharedEn = SharedStrings(
    openNavigationTooltip: 'Open navigation',
    navCalculator: 'Calculator',
    navTools: 'Tools',
    navGraph: 'Graph',
    navNotes: 'Notes',
    navSettings: 'Settings',
  );
}
