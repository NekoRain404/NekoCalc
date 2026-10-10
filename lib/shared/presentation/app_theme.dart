import 'package:flutter/material.dart';

/// 中文：全应用的 Material 主题，取色**全部指向**计算器主页的玫瑰奶霜（`CalcTheme.roseCream`）。
///       在此之前这里是一套手工钉死的冷靛蓝/蓝配色（`0xFF5B47FF` / `0xFF1677FF` / `0xFFF8FAFF` …），
///       于是主页是暖色粉彩、其余页面是冷色，整个应用看起来像两个应用。现在每个角色都改写成
///       `calc_theme.dart` 里同名语义令牌的色值——**主页仍是唯一真源**，这里只是把别处的角色指过去。
///       刻意**不**写成 `CalcTheme.roseCream.display.indicatorFg` 之类的引用：`AppTheme` 在
///       `MaterialApp` 建 `ThemeData` 时求值，比 `CalcThemeScope` 更早，且 `CalcTheme` 是 `const`，
///       这里的字面量与之逐字节相等即可；改动色值时两边要一起改。
/// English: The app-wide Material theme; every colour **points at** the calculator home page's Rose
///          Cream palette (`CalcTheme.roseCream`). Before this, the file hand-pinned a cool
///          indigo/blue scheme (`0xFF5B47FF` / `0xFF1677FF` / `0xFFF8FAFF` …), so the home page was
///          warm pastel while every other page was cool — the app looked like two apps. Each role now
///          carries the value of the matching semantic token in `calc_theme.dart`; **the home page
///          stays the single source of truth** and this file only re-points the other roles at it.
///          The values are deliberately literals rather than references like
///          `CalcTheme.roseCream.display.indicatorFg`: `AppTheme` is evaluated while `MaterialApp`
///          builds its `ThemeData`, earlier than `CalcThemeScope`, and `CalcTheme` is `const`, so
///          byte-identical literals are enough — but changing a colour means changing it in both files.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      // 中文：键位区底色，即应用的"画布"。
      // English: The keypad panel colour, i.e. the app's canvas.
      scaffoldBackgroundColor: const Color(0xFFF4EAE4),
      colorScheme: ColorScheme.fromSeed(
        // 中文：种子与 primary 同取强调色（主页的 "More…"、DEG / 徽标）。
        // English: Seed and primary both take the accent (the home page's "More…", DEG / badges).
        seedColor: const Color(0xFFAA5462),
        primary: const Color(0xFFAA5462),
        onPrimary: const Color(0xFFFFF6F7),
        primaryContainer: const Color(0xFFEDDDE1),
        secondary: const Color(0xFFD98A94),
        secondaryContainer: const Color(0xFFF7E3C5),
        // 中文：警示等级沿用主页的错误色，与 `scheme.error` 同值。
        // English: Warning severity reuses the home page's error colour, same as `scheme.error`.
        tertiary: const Color(0xFFB23A4A),
        surface: const Color(0xFFFFFAF7),
        onSurface: const Color(0xFF3E3138),
        onSurfaceVariant: const Color(0xFF7F6A71),
        error: const Color(0xFFB23A4A),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFFFFFAF7),
        // 中文：指示器是选中态的"胶囊"，与 `TabPill` 一样走 `primaryContainer` 那一格。
        // English: The indicator is the selected-state pill, so it takes the same slot as
        //          `TabPill`: `primaryContainer`.
        indicatorColor: Color(0xFFEDDDE1),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFAF7),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          // 中文：暖白底上的一条发丝线。
          // English: A hairline on warm white.
          side: const BorderSide(color: Color(0xFFEBDCE1)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFAF7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEBDCE1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEBDCE1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFAA5462), width: 1.3),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE8A2AC),
      brightness: Brightness.dark,
      primary: const Color(0xFFE8A2AC),
      onPrimary: const Color(0xFF2A1216),
      primaryContainer: const Color(0xFF3A3038),
      secondary: const Color(0xFFC0707E),
      secondaryContainer: const Color(0xFF453828),
      tertiary: const Color(0xFFFF8A94),
      surface: const Color(0xFF1D191B),
      onSurface: const Color(0xFFEDE4E8),
      onSurfaceVariant: const Color(0xFF9E98A6),
      error: const Color(0xFFFF8A94),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF141114),
      colorScheme: scheme,
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF1D191B),
        indicatorColor: Color(0xFF3A3038),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1D191B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF3A3236)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1D191B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3A3236)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3A3236)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE8A2AC), width: 1.3),
        ),
      ),
    );
  }
}
