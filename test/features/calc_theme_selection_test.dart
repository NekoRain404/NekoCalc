import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

/// 中文：`CalcTheme.of` 是计算页、侧边抽屉与回归图取色的唯一入口，本文件钉住"主题选择接进来了"
///       这件事本身：装没装作用域、明暗还看不看应用自己的模式、认不出的 id 怎么办。
/// English: `CalcTheme.of` is the single colour entry point for the calculator page, the drawer and
///          the regression graph. This file pins "the theme picker is wired in" itself: what happens
///          with and without a scope, whether light/dark still follows the *app's own* mode, and what
///          an unrecognised id does.
void main() {
  /// 中文：把 `CalcTheme.of(context)` 的结果捞出来。用 `Builder` 而不是 `tester.element(...)`，
  ///       是为了让被断言的那个 context 就是控件树里真实的 context。
  /// English: Captures `CalcTheme.of(context)`. A `Builder` rather than `tester.element(...)` so the
  ///          context under test is a real one from the widget tree.
  Future<CalcTheme> resolveTheme(
    WidgetTester tester, {
    CalcTheme? base,
    Brightness appBrightness = Brightness.light,
    Brightness? platformBrightness,
  }) async {
    if (platformBrightness != null) {
      tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }
    late CalcTheme resolved;
    final child = Builder(builder: (context) {
      resolved = CalcTheme.of(context);
      return const SizedBox.shrink();
    });
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode:
          appBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: base == null ? child : CalcThemeScope(base: base, child: child),
    ));
    // 中文：`MaterialApp` 换明暗走的是 `AnimatedTheme`——只 pump 一帧，`Theme.of(context).brightness`
    //       还停在上一套主题上（`ThemeData.lerp` 在 t=0 给的是旧值）。同一个测试里第二次
    //       `pumpWidget` 若不等动画走完，量到的就是上一次的明暗。所以这里必须 settle。
    // English: `MaterialApp` switches light/dark through `AnimatedTheme`; after a single pumped
    //          frame `Theme.of(context).brightness` is still the previous theme (`ThemeData.lerp`
    //          yields the old value at t=0). A second `pumpWidget` in the same test that does not wait
    //          for that animation measures the *previous* brightness. Hence the settle.
    await tester.pumpAndSettle();
    return resolved;
  }

  testWidgets('没有作用域时回落到 roseCream（接入前的老行为）', (tester) async {
    expect(await resolveTheme(tester), CalcTheme.roseCream);
    expect(
      await resolveTheme(tester, appBrightness: Brightness.dark),
      CalcTheme.roseCream.dark,
    );
  });

  testWidgets('装了作用域就取用户选的那一套', (tester) async {
    expect(
      await resolveTheme(tester, base: CalcTheme.lavenderMist),
      CalcTheme.lavenderMist,
    );
    expect(
      await resolveTheme(tester, base: CalcTheme.peachSugar),
      CalcTheme.peachSugar,
    );
    expect(
      await resolveTheme(
        tester,
        base: CalcTheme.lavenderMist,
        appBrightness: Brightness.dark,
      ),
      CalcTheme.lavenderMist.dark,
    );
  });

  testWidgets('明暗跟着应用自己的主题模式，不跟平台亮度', (tester) async {
    // 中文：用户选了浅色、手机开着深色模式——应用自己的模式说了算。这条规则在接入主题选择之前
    //       就存在，本文件只是保证它没被改坏。
    // English: 浅色 chosen while the phone is in dark mode — the app's own mode wins. This rule
    //          predates the theme picker; this only ensures it was not broken.
    final resolved = await resolveTheme(
      tester,
      base: CalcTheme.lavenderMist,
      appBrightness: Brightness.light,
      platformBrightness: Brightness.dark,
    );
    expect(resolved, CalcTheme.lavenderMist);
    expect(resolved, isNot(CalcTheme.lavenderMist.dark));
  });

  testWidgets('Navigator 压上来的路由也看得见作用域', (tester) async {
    // 中文：这条是装法的护栏。作用域若装在 `home:` 里，`Navigator.push` 上来的页面与它是兄弟
    //       而非子孙，取到的就是 `roseCream`——设置页选的配色在设置页自己身上失效。
    // English: This guards the installation point. With the scope inside `home:`, a
    //          `Navigator.push`ed page is its sibling rather than a descendant and resolves to
    //          `roseCream` — the palette chosen on the settings page failing on that very page.
    late CalcTheme inRoute;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.light),
      builder: (context, child) => CalcThemeScope(
        base: CalcTheme.peachSugar,
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (routeContext) {
              inRoute = CalcTheme.of(routeContext);
              return const SizedBox.shrink();
            },
          )),
          child: const Text('push'),
        ),
      ),
    ));
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(inRoute, CalcTheme.peachSugar);
  });

  test('resolve 认得三套主题，认不出就回落到 roseCream', () {
    for (final theme in CalcTheme.all) {
      expect(CalcTheme.resolve(theme.id), same(theme));
    }
    expect(CalcTheme.resolve(null), CalcTheme.roseCream);
    expect(CalcTheme.resolve(''), CalcTheme.roseCream);
    expect(CalcTheme.resolve('nope'), CalcTheme.roseCream);
    // 中文：`name` 是给人看的、可翻译的标签，不是 id。拿它来喂 `resolve` 必须认不出——
    //       这正是"令牌与标签不可互换"在主题这一侧的体现。
    // English: `name` is the human-facing, translatable label, not the id. Feeding it to `resolve`
    //          must fail to match — the theme-side face of "tokens and labels are not interchangeable".
    expect(CalcTheme.resolve(CalcTheme.lavenderMist.name), CalcTheme.roseCream);
  });

  test('三套主题各自有 id 互不相同，且都有深色变体', () {
    final ids = CalcTheme.all.map((theme) => theme.id).toSet();
    expect(ids.length, CalcTheme.all.length);
    expect(ids.length, 3);
    for (final theme in CalcTheme.all) {
      expect(theme.dark.id, theme.id, reason: '深浅变体共用一个 id');
      expect(theme.dark.brightness, Brightness.dark);
      expect(theme.brightness, Brightness.light);
      // 中文：深色变体必须真的是另一套色，否则"选了深色"会静默保持浅色。
      // English: The dark variant must really be a different palette, otherwise "chose dark" would
      //          silently stay light.
      expect(theme.dark.display.background, isNot(theme.display.background));
    }
  });
}
