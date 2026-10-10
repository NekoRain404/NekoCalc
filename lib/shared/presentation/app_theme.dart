import 'package:flutter/material.dart';

import 'calc_theme.dart';

/// 中文：全应用的 Material 主题，**由选中的 [CalcTheme] 纯函数式派生**，本文件不含任何色值字面量。
///       历史：这里曾把玫瑰奶霜的色值手抄成字面量——于是用户切到薰衣草雾 / 蜜桃砂糖时，只有计算器
///       换了色，设置、工具、笔记、回归图仍是玫瑰奶霜，整个应用又变回"两个应用"。抄一份色值等于把
///       真源复制成两份，两份必然漂移；现在的修法是每个 Material 角色**指向** `calc_theme.dart` 里
///       的语义令牌，切主题时全应用一起走。
///       明暗：浅色由 `base` 派生，深色由 `base.dark` 派生（见 [CalcTheme.dark]），所以
///       `AppTheme.dark(t)` 与计算页在深色模式下看到的 [CalcTheme.of] 是**同一份**调色板。
///       未列在角色表里的 Material 角色一律交给 `ColorScheme.fromSeed` 从同一个种子推导——
///       需要一个本表没提到的颜色时，**不要**在下面写死字面量，先想清楚它对应哪个语义令牌。
/// English: The app-wide Material theme, **derived as a pure function of the selected [CalcTheme]**;
///          this file holds no colour literal of its own. History: it used to hand-copy Rose Cream's
///          values as literals, so switching to Lavender Mist / Peach Sugar re-themed only the
///          calculator while settings, tools, notes and the graph stayed Rose Cream — the app looked
///          like two apps again. A copied palette is a second source of truth and the two drift; now
///          every Material role **points at** a semantic token in `calc_theme.dart`, so one switch
///          moves the whole app together.
///          Light/dark: the light variant derives from `base` and the dark one from `base.dark` (see
///          [CalcTheme.dark]), so `AppTheme.dark(t)` shows the same palette the calculator gets from
///          [CalcTheme.of] in dark mode.
///          Any Material role not in the table goes through `ColorScheme.fromSeed` on the same seed —
///          when you need a colour the table does not mention, **do not** add a literal below; first
///          decide which semantic token it means.
class AppTheme {
  const AppTheme._();

  /// 中文：浅色主题，取自基准（浅色）变体。
  /// English: The light theme, taken from the base (light) variant.
  static ThemeData light(CalcTheme base) => _build(base);

  /// 中文：深色主题，取自**深色**变体——不是简单把浅色反相，而是 `calc_theme.dart` 里那套
  ///       逐令牌手调的深色值。
  /// English: The dark theme, taken from the **dark** variant — not a naive inversion of the light
  ///          one but the per-token hand-tuned dark values in `calc_theme.dart`.
  static ThemeData dark(CalcTheme base) => _build(base.dark);

  /// 中文：角色表。左侧 Material 角色，右侧语义令牌，理由写在各自那一行上。
  /// English: The role table. Material role on the left, semantic token on the right; the reason sits
  ///          on each line.
  static ThemeData _build(CalcTheme t) {
    final scheme = ColorScheme.fromSeed(
      // 中文：种子取强调色：设置页的开关、各种选中态都从它派生。
      // English: The seed is the accent; the settings page's switches and every selected state derive
      //          from it.
      seedColor: t.display.indicatorFg,
      brightness: t.brightness,
      // 中文：强调色（主页的 "More…"、DEG / 徽标）配它自己的前景。
      // English: The accent (the home page's "More…", DEG / badges) with its own foreground.
      primary: t.display.indicatorFg,
      onPrimary: t.keys.accentFg,
      primaryContainer: t.keys.pillBg,
      onPrimaryContainer: t.keys.pillFg,
      // 中文：次级是强调键的底色；它在自己底上写字，所以前景也取强调键前景，不是 `onSecondary` 的默认。
      // English: Secondary is the accent key's background, and it writes on itself, so the foreground
      //          is the accent key's too rather than whatever `onSecondary` would default to.
      secondary: t.keys.accentBg,
      onSecondary: t.keys.accentFg,
      secondaryContainer: t.keys.variableBg,
      onSecondaryContainer: t.keys.variableFg,
      // 中文：警示等级沿用计算页的错误色，与 `scheme.error` 同值。
      // English: Warning severity reuses the calculator's error colour, same as `scheme.error`.
      tertiary: t.display.errorFg,
      error: t.display.errorFg,
      surface: t.display.background,
      onSurface: t.keys.functionFg,
      onSurfaceVariant: t.display.statusFg,
      // 中文：静止态描边一律走函数键底色那一格——它在深浅两套里都与画布差一档、又不抢眼。
      // English: Every resting border takes the function key's background slot: in both light and
      //          dark it sits one step off the canvas without shouting.
      outlineVariant: t.keys.functionBg,
    );
    return ThemeData(
      useMaterial3: true,
      // 中文：键位区底色，即应用的"画布"。
      // English: The keypad panel colour, i.e. the app's canvas.
      scaffoldBackgroundColor: t.keypadBackground,
      colorScheme: scheme,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        // 中文：指示器是选中态的"胶囊"，与 `TabPill` 一样走 `primaryContainer` 那一格。
        // English: The indicator is the selected-state pill, so it takes the same slot as
        //          `TabPill`: `primaryContainer`.
        indicatorColor: t.keys.pillBg,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          // 中文：底上的一条发丝线。
          // English: A hairline on the surface.
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          // 中文：聚焦态才升到 primary；与静止态描边拉开差别，用户一眼看到光标在哪个框里。
          // English: Only the focused state rises to `primary`, so the cursor's field is obvious at a
          //          glance against the resting borders.
          borderSide: BorderSide(color: scheme.primary, width: 1.3),
        ),
      ),
    );
  }
}
