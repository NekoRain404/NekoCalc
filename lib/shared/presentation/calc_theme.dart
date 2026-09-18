import 'package:flutter/material.dart';

/// 中文：显示区语义色，表达式、结果、状态指示与错误各有独立色位。
/// English: Semantic colours for the display area; expression, result, status
/// indicator and error each own a distinct slot.
@immutable
class CalcDisplayColors {
  const CalcDisplayColors({
    required this.background,
    required this.expressionFg,
    required this.resultFg,
    required this.statusFg,
    required this.indicatorFg,
    required this.errorFg,
  });

  /// 中文：显示区底色。
  /// English: Display panel background.
  final Color background;

  /// 中文：用户输入表达式的前景色。
  /// English: Foreground for the expression being typed.
  final Color expressionFg;

  /// 中文：计算结果的前景色，通常比表达式更重。
  /// English: Foreground for the computed result, usually heavier than the expression.
  final Color resultFg;

  /// 中文：次要状态文字（角度制、内存标记等）的前景色。
  /// English: Foreground for secondary status text such as angle mode or memory flags.
  final Color statusFg;

  /// 中文：状态指示灯 / 徽标的前景色。
  /// English: Foreground for status indicators and badges.
  final Color indicatorFg;

  /// 中文：错误提示的前景色。
  /// English: Foreground for error messages.
  final Color errorFg;
}

/// 中文：键位语义色，每类按键各自拥有背景与前景，避免直接写死色值。
/// English: Semantic keypad colours; every key category owns a background and
/// foreground pair so widgets never hardcode raw colour values.
@immutable
class CalcKeyColors {
  const CalcKeyColors({
    required this.digitBg,
    required this.digitFg,
    required this.operatorBg,
    required this.operatorFg,
    required this.functionBg,
    required this.functionFg,
    required this.variableBg,
    required this.variableFg,
    required this.modifierBg,
    required this.modifierFg,
    required this.destructiveBg,
    required this.destructiveFg,
    required this.accentBg,
    required this.accentFg,
    required this.shiftLabelFg,
    required this.pillBg,
    required this.pillFg,
  });

  /// 中文：数字键底色与前景色。
  /// English: Digit key background and foreground.
  final Color digitBg;
  final Color digitFg;

  /// 中文：运算符键底色与前景色。
  /// English: Operator key background and foreground.
  final Color operatorBg;
  final Color operatorFg;

  /// 中文：函数键（sin、log 等）底色与前景色。
  /// English: Function key (sin, log, ...) background and foreground.
  final Color functionBg;
  final Color functionFg;

  /// 中文：变量键（x、y、M 等）底色与前景色。
  /// English: Variable key (x, y, M, ...) background and foreground.
  final Color variableBg;
  final Color variableFg;

  /// 中文：模态键（SHIFT 等）底色与前景色。
  /// English: Modifier key (SHIFT, ...) background and foreground.
  final Color modifierBg;
  final Color modifierFg;

  /// 中文：破坏性按键（退格、清空）底色与前景色，必须与模态键可区分。
  /// English: Destructive key (backspace, clear) background and foreground;
  /// must stay distinguishable from the modifier key.
  final Color destructiveBg;
  final Color destructiveFg;

  /// 中文：强调色，用于主操作与选中态。
  /// English: Accent colour for primary actions and selected states.
  final Color accentBg;
  final Color accentFg;

  /// 中文：模态键上小标签（SHIFT 提示）的前景色，比键面文字更淡，在模态键与键位区底色上均可读
  ///       （两处都按 4.5:1 断言，见 `calc_theme_test.dart`；"更淡"指与模态键底色的对比更低）。
  /// English: Foreground for the small label printed on modifier keys; dimmer
  /// than the key glyph and legible on both the modifier key and the keypad panel
  /// (both are asserted at 4.5:1 in `calc_theme_test.dart`; "dimmer" means a
  /// lower contrast against the modifier key's background).
  final Color shiftLabelFg;

  /// 中文：小胶囊 / 切换标签的底色与前景色。
  /// English: Pill and toggle chip background and foreground.
  final Color pillBg;
  final Color pillFg;
}

/// 中文：计算器主题的语义色集合，一套主题含浅色与深色两个变体。
/// English: Semantic colour set for a calculator theme; each theme ships a
/// light and a matching dark variant.
@immutable
class CalcTheme {
  const CalcTheme({
    required this.id,
    required this.name,
    required this.brightness,
    required this.display,
    required this.keys,
    required this.keypadBackground,
  });

  /// 中文：主题标识，浅色与深色变体共用同一个 id。
  /// English: Theme identifier; the light and dark variants share one id.
  final String id;

  /// 中文：主题显示名称。
  /// English: Human readable theme name.
  final String name;

  /// 中文：该变体的明暗属性。
  /// English: Brightness of this variant.
  final Brightness brightness;

  /// 中文：显示区语义色。
  /// English: Display area semantic colours.
  final CalcDisplayColors display;

  /// 中文：键位语义色。
  /// English: Keypad semantic colours.
  final CalcKeyColors keys;

  /// 中文：键位区底色。
  /// English: Keypad panel background.
  final Color keypadBackground;

  /// 中文：同色系的深色变体；深色变体调用时返回自身。
  /// English: Matching dark variant of this theme; a dark variant returns itself.
  CalcTheme get dark => _darkVariants[id] ?? this;

  /// 中文：当前生效的 `CalcTheme`——计算页、侧边抽屉与回归图取色的**唯一**入口。
  ///       明暗取自 `Theme.of(context).brightness`：那是应用自己的主题模式（设置里的
  ///       浅色 / 深色 / 跟随系统，由 `app.dart` 的 `themeMode` 落到 `MaterialApp`）算完之后的
  ///       **实际**明暗。反过来若读平台的 `MediaQuery.platformBrightness`，用户选了浅色而手机开着
  ///       深色模式时两者相反，本页与抽屉就会在其余页面全是浅色时独自变黑。
  ///       配色取自祖先里的 [CalcThemeScope]，由 `app.dart` 按设置里的 `theme_id` 装入；没有
  ///       该祖先时回落到 [fallback]（`roseCream`）。**这是"接上主题选择"的唯一改动点**：
  ///       `grep -rn "CalcTheme.of" lib` 数到 7 个调用点，分布在 4 个文件里——它们一个字都不用改，
  ///       因为选择的读取对调用方不可见。（旧注释写的是"两个调用点"，那是把计算页与抽屉两个**页面**
  ///       当成了调用点；实际调用点数是 7。）
  /// English: The active `CalcTheme` — the **single** entry point for the calculator page's, the
  ///          drawer's and the regression graph's colours. Light/dark comes from
  ///          `Theme.of(context).brightness`: the *effective* brightness after the app's own theme mode
  ///          (浅色 / 深色 / 跟随系统 from the settings, applied to `MaterialApp` by `app.dart`'s
  ///          `themeMode`). Reading the platform's `MediaQuery.platformBrightness` instead disagrees
  ///          whenever 浅色 is chosen on a dark-mode phone, turning this page and the drawer black while
  ///          every other page stays light.
  ///          The palette comes from a [CalcThemeScope] ancestor installed by `app.dart` from the
  ///          stored `theme_id`, falling back to [fallback] (`roseCream`) when there is none. **This is
  ///          the only place "wiring the theme picker" touched**: `grep -rn "CalcTheme.of" lib` finds 7
  ///          call sites across 4 files, and not one of them changed, because reading the choice is
  ///          invisible to the caller. (The old comment said "two call sites" — that counted *pages*
  ///          rather than call sites; the real number is 7.)
  static CalcTheme of(BuildContext context) {
    final base = CalcThemeScope.maybeOf(context) ?? fallback;
    return Theme.of(context).brightness == Brightness.dark ? base.dark : base;
  }

  /// 中文：没有装 [CalcThemeScope] 时用的基准主题。默认态必须与"主题选择接入之前"逐字节相同。
  /// English: Base theme used when no [CalcThemeScope] is installed; the default state must stay
  ///          byte-identical to the one before the theme picker existed.
  static const CalcTheme fallback = roseCream;

  /// 中文：把持久化的 `theme_id` 解成基准（浅色）主题；认不出的 id 一律回落到 [fallback]，
  ///       所以库里存着一个已删主题的名字不会让界面取色崩溃，只会显示默认主题。
  ///       **入参是持久化令牌，不是标签**——不要拿 `CalcTheme.name`（那是给人看的、可翻译的）来喂它。
  /// English: Resolves a persisted `theme_id` to its base (light) theme; anything unrecognised falls
  ///          back to [fallback], so a deleted theme's name left in the database cannot break colour
  ///          resolution — it just renders the default. **The argument is a persisted token, not a
  ///          label**: never feed it `CalcTheme.name`, which is human-facing and translatable.
  static CalcTheme resolve(String? id) {
    for (final theme in all) {
      if (theme.id == id) return theme;
    }
    return fallback;
  }

  /// 中文：玫瑰奶霜，暖玫瑰色系的浅色主题。
  /// English: Rose Cream, a warm rose light theme.
  static const CalcTheme roseCream = CalcTheme(
    id: 'roseCream',
    name: '玫瑰奶霜',
    brightness: Brightness.light,
    display: CalcDisplayColors(
      background: Color(0xFFFFFAF7),
      expressionFg: Color(0xFF4A3B40),
      resultFg: Color(0xFF2B2326),
      statusFg: Color(0xFF7F6A71),
      indicatorFg: Color(0xFFAA5462),
      errorFg: Color(0xFFB23A4A),
    ),
    keys: CalcKeyColors(
      digitBg: Color(0xFFFFF8F4),
      digitFg: Color(0xFF382C30),
      operatorBg: Color(0xFFF4B8AE),
      operatorFg: Color(0xFF4A2A2C),
      functionBg: Color(0xFFEBDCE1),
      functionFg: Color(0xFF3E3138),
      variableBg: Color(0xFFF7E3C5),
      variableFg: Color(0xFF443625),
      modifierBg: Color(0xFF8FC7A8),
      modifierFg: Color(0xFF1F3D2E),
      destructiveBg: Color(0xFFD98A94),
      destructiveFg: Color(0xFF4A2029),
      accentBg: Color(0xFFA04F60),
      accentFg: Color(0xFFFFF6F7),
      shiftLabelFg: Color(0xFF2E4A3A),
      pillBg: Color(0xFFEDDDE1),
      pillFg: Color(0xFF4A3B40),
    ),
    keypadBackground: Color(0xFFF4EAE4),
  );

  /// 中文：薰衣草雾，冷紫罗兰色系的浅色主题；破坏性按键仍用暖色警示，与其它主题语义一致。
  /// English: Lavender Mist, a cool violet light theme; its destructive key
  /// stays warm so the warning semantics match the other themes.
  static const CalcTheme lavenderMist = CalcTheme(
    id: 'lavenderMist',
    name: '薰衣草雾',
    brightness: Brightness.light,
    display: CalcDisplayColors(
      background: Color(0xFFFBFAFF),
      expressionFg: Color(0xFF413C58),
      resultFg: Color(0xFF231F38),
      statusFg: Color(0xFF726C8A),
      indicatorFg: Color(0xFF6C5CB4),
      errorFg: Color(0xFFB03A52),
    ),
    keys: CalcKeyColors(
      digitBg: Color(0xFFF8F7FF),
      digitFg: Color(0xFF2E2A3D),
      operatorBg: Color(0xFFC9BFF0),
      operatorFg: Color(0xFF322A52),
      functionBg: Color(0xFFE4E1F2),
      functionFg: Color(0xFF34304A),
      variableBg: Color(0xFFD4E7EF),
      variableFg: Color(0xFF21333D),
      modifierBg: Color(0xFF8FC7A8),
      modifierFg: Color(0xFF1F3D2E),
      destructiveBg: Color(0xFFE0847E),
      destructiveFg: Color(0xFF4A2317),
      accentBg: Color(0xFF6A55BC),
      accentFg: Color(0xFFF7F4FF),
      shiftLabelFg: Color(0xFF2E4A3A),
      pillBg: Color(0xFFE6E2F5),
      pillFg: Color(0xFF37325A),
    ),
    keypadBackground: Color(0xFFEDEAF8),
  );

  /// 中文：蜜桃砂糖，暖蜜桃色系的浅色主题。
  /// English: Peach Sugar, a warm peach light theme.
  static const CalcTheme peachSugar = CalcTheme(
    id: 'peachSugar',
    name: '蜜桃砂糖',
    brightness: Brightness.light,
    display: CalcDisplayColors(
      background: Color(0xFFFFFBF6),
      expressionFg: Color(0xFF4A3B2E),
      resultFg: Color(0xFF2E241B),
      statusFg: Color(0xFF7D6C5F),
      indicatorFg: Color(0xFF98622F),
      errorFg: Color(0xFFB23A4A),
    ),
    keys: CalcKeyColors(
      digitBg: Color(0xFFFFF9F3),
      digitFg: Color(0xFF3A2F27),
      operatorBg: Color(0xFFF9C6A5),
      operatorFg: Color(0xFF4C2F1C),
      functionBg: Color(0xFFEDE0D6),
      functionFg: Color(0xFF3D322A),
      variableBg: Color(0xFFE6DDF2),
      variableFg: Color(0xFF332A47),
      modifierBg: Color(0xFF8FC7A8),
      modifierFg: Color(0xFF1F3D2E),
      destructiveBg: Color(0xFFE89878),
      destructiveFg: Color(0xFF4A2317),
      accentBg: Color(0xFFD98A5C),
      accentFg: Color(0xFF2B1409),
      shiftLabelFg: Color(0xFF2E4A3A),
      pillBg: Color(0xFFF0DFD2),
      pillFg: Color(0xFF463229),
    ),
    keypadBackground: Color(0xFFF7ECE3),
  );

  /// 中文：内置主题列表，只含浅色变体，深色变体通过 dark 获取。
  /// English: Built-in themes; only light variants are listed, dark variants
  /// are reached through dark.
  static const List<CalcTheme> all = <CalcTheme>[
    roseCream,
    lavenderMist,
    peachSugar,
  ];
}

/// 中文：玫瑰奶霜深色变体，保留玫瑰色相并降低明度。
/// English: Rose Cream dark variant; keeps the rose hue at lower lightness.
const CalcTheme _roseCreamDark = CalcTheme(
  id: 'roseCream',
  name: '玫瑰奶霜 深色',
  brightness: Brightness.dark,
  display: CalcDisplayColors(
    background: Color(0xFF1D191B),
    expressionFg: Color(0xFFF0EDF2),
    resultFg: Color(0xFFFFFFFF),
    statusFg: Color(0xFF9E98A6),
    indicatorFg: Color(0xFFE8A2AC),
    errorFg: Color(0xFFFF8A94),
  ),
  keys: CalcKeyColors(
    digitBg: Color(0xFF2A2528),
    digitFg: Color(0xFFF2ECEF),
    operatorBg: Color(0xFF6E4A50),
    operatorFg: Color(0xFFFBD8D5),
    functionBg: Color(0xFF3A3236),
    functionFg: Color(0xFFEDE4E8),
    variableBg: Color(0xFF453828),
    variableFg: Color(0xFFF0E2CC),
    modifierBg: Color(0xFF33543F),
    modifierFg: Color(0xFFC6E6D2),
    destructiveBg: Color(0xFF6E3038),
    destructiveFg: Color(0xFFF6D5D8),
    accentBg: Color(0xFFC0707E),
    accentFg: Color(0xFF2A1216),
    shiftLabelFg: Color(0xFFB0C9B8),
    pillBg: Color(0xFF3A3038),
    pillFg: Color(0xFFEDE4E8),
  ),
  keypadBackground: Color(0xFF141114),
);

/// 中文：薰衣草雾深色变体，保留紫罗兰色相并降低明度；破坏性按键与浅色变体一致改用暖色警示，
///       不再跟着主题的冷色相走。
/// English: Lavender Mist dark variant; keeps the violet hue at lower lightness, while its
///          destructive key is warm like the light variant's rather than following the theme's
///          cool hue.
const CalcTheme _lavenderMistDark = CalcTheme(
  id: 'lavenderMist',
  name: '薰衣草雾 深色',
  brightness: Brightness.dark,
  display: CalcDisplayColors(
    background: Color(0xFF1A1922),
    expressionFg: Color(0xFFEFEDF7),
    resultFg: Color(0xFFFFFFFF),
    statusFg: Color(0xFF9A94AC),
    indicatorFg: Color(0xFFBDB0F2),
    errorFg: Color(0xFFFF8A9C),
  ),
  keys: CalcKeyColors(
    digitBg: Color(0xFF262433),
    digitFg: Color(0xFFEEECF5),
    operatorBg: Color(0xFF4E4585),
    operatorFg: Color(0xFFDCD5FF),
    functionBg: Color(0xFF33313F),
    functionFg: Color(0xFFE6E3F0),
    variableBg: Color(0xFF2B3D4A),
    variableFg: Color(0xFFD3E6F0),
    modifierBg: Color(0xFF33543F),
    modifierFg: Color(0xFFC6E6D2),
    destructiveBg: Color(0xFF74343C),
    destructiveFg: Color(0xFFF7D3D6),
    accentBg: Color(0xFF8C79D8),
    accentFg: Color(0xFF170F2E),
    shiftLabelFg: Color(0xFFB0C9B8),
    pillBg: Color(0xFF322F44),
    pillFg: Color(0xFFE6E3F0),
  ),
  keypadBackground: Color(0xFF131219),
);

/// 中文：蜜桃砂糖深色变体，保留蜜桃色相并降低明度。
/// English: Peach Sugar dark variant; keeps the peach hue at lower lightness.
const CalcTheme _peachSugarDark = CalcTheme(
  id: 'peachSugar',
  name: '蜜桃砂糖 深色',
  brightness: Brightness.dark,
  display: CalcDisplayColors(
    background: Color(0xFF1E1A17),
    expressionFg: Color(0xFFF5F0EA),
    resultFg: Color(0xFFFFFFFF),
    statusFg: Color(0xFFA99C8F),
    indicatorFg: Color(0xFFF2B58C),
    errorFg: Color(0xFFFF8A94),
  ),
  keys: CalcKeyColors(
    digitBg: Color(0xFF2C2622),
    digitFg: Color(0xFFF4EEE8),
    operatorBg: Color(0xFF7A4E33),
    operatorFg: Color(0xFFFFDCC3),
    functionBg: Color(0xFF3A332C),
    functionFg: Color(0xFFF2E9E1),
    variableBg: Color(0xFF3B3348),
    variableFg: Color(0xFFE0D7F0),
    modifierBg: Color(0xFF33543F),
    modifierFg: Color(0xFFC6E6D2),
    destructiveBg: Color(0xFF7A3F2A),
    destructiveFg: Color(0xFFF9D6C4),
    accentBg: Color(0xFFD98A5C),
    accentFg: Color(0xFF2B1409),
    shiftLabelFg: Color(0xFFB0C9B8),
    pillBg: Color(0xFF3D342B),
    pillFg: Color(0xFFF2E9E1),
  ),
  keypadBackground: Color(0xFF16130F),
);

/// 中文：按主题 id 索引的深色变体表。
/// English: Dark variants indexed by theme id.
const Map<String, CalcTheme> _darkVariants = <String, CalcTheme>{
  'roseCream': _roseCreamDark,
  'lavenderMist': _lavenderMistDark,
  'peachSugar': _peachSugarDark,
};

/// 中文：把用户选中的基准主题送进 `CalcTheme.of` 的载体。`app.dart` 用 `MaterialApp.builder`
///       把它装在 **Navigator 之上**——不是装在 `home:` 里。这一点是必须的：`Navigator.push`
///       压上来的路由（设置页就在其中）与 `home` 是兄弟而非子孙，装在 `home` 里的作用域推上来的
///       页面根本看不见，设置页就会退回默认主题。
///       只装**基准（浅色）**变体，明暗仍由 `CalcTheme.of` 按 `Theme.of(context).brightness` 选，
///       所以"用户选了浅色而手机开着深色"这条既有规则不受影响。
/// English: Carries the chosen base theme into `CalcTheme.of`. `app.dart` installs it with
///          `MaterialApp.builder`, i.e. **above the Navigator** — not inside `home:`, which would be a
///          sibling of every `Navigator.push`ed route (the settings page among them) rather than an
///          ancestor, so a pushed page would silently fall back to the default theme.
///          Only the **base (light)** variant is carried; light/dark is still chosen by `CalcTheme.of`
///          from `Theme.of(context).brightness`, so the existing "浅色 chosen on a dark-mode phone"
///          rule is untouched.
class CalcThemeScope extends InheritedWidget {
  const CalcThemeScope({
    required this.base,
    required super.child,
    super.key,
  });

  /// 中文：基准（浅色）变体，见 [CalcTheme.resolve]。
  /// English: The base (light) variant; see [CalcTheme.resolve].
  final CalcTheme base;

  /// 中文：取不到作用域时返回 `null`，由 [CalcTheme.of] 回落到默认主题——这样单独渲染
  ///       `CalculatorPage` / `AppDrawer` 的既有测试不必套一层作用域。
  /// English: `null` when there is no scope, letting [CalcTheme.of] fall back to the default theme, so
  ///          the existing tests that render `CalculatorPage` / `AppDrawer` on their own need no wrapper.
  static CalcTheme? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CalcThemeScope>()?.base;
  }

  @override
  bool updateShouldNotify(CalcThemeScope oldWidget) {
    // 中文：主题都是 `const` 规范实例，`identical` 就够；这里刻意不比较色值，避免在热路径上
    //       逐字段比 30 多个 `Color`。
    // English: Themes are canonical `const` instances, so `identical` suffices; this deliberately does
    //          not compare colours field by field on a hot path.
    return !identical(oldWidget.base, base);
  }
}
