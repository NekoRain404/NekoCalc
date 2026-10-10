import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/shared/presentation/app_theme.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

void main() {
  // 中文：这组断言守的是一个刚修好的架构缺陷：`AppTheme` 曾把玫瑰奶霜的色值手抄成字面量，
  //       于是用户切到薰衣草雾 / 蜜桃砂糖时只有计算器换了色，设置、工具、笔记、回归图仍是
  //       玫瑰奶霜——"两个应用"换了副面孔回来。修法是让 `AppTheme` 成为选中主题的**纯函数**，
  //       本文件把这条约束钉在测试上：任何一处角色来源被写回字面量，这里先红。
  //       遍历 `CalcTheme.all` 而不是逐个点名：将来新增主题自动纳入守卫。
  // English: These assertions guard a just-fixed architectural defect: `AppTheme` used to hand-copy
  //          Rose Cream's values as literals, so switching to Lavender Mist / Peach Sugar re-themed
  //          only the calculator while settings, tools, notes and the graph stayed Rose Cream — the
  //          "two apps" problem back in a new form. The fix makes `AppTheme` a **pure function** of
  //          the selected theme, and this file pins that down: if any role's source is written back
  //          to a literal, this goes red first. It iterates `CalcTheme.all` instead of naming themes
  //          so a theme added later is covered automatically.
  group('AppTheme follows CalcTheme', () {
    test('浅色角色逐一取自选中主题的语义令牌', () {
      for (final base in CalcTheme.all) {
        final scheme = AppTheme.light(base).colorScheme;
        expect(scheme.primary, base.display.indicatorFg,
            reason: '${base.id}: primary 必须取 display.indicatorFg');
        expect(scheme.surface, base.display.background,
            reason: '${base.id}: surface 必须取 display.background');
        expect(
            AppTheme.light(base).scaffoldBackgroundColor, base.keypadBackground,
            reason: '${base.id}: 画布必须取 keypadBackground');
        expect(scheme.tertiary, base.display.errorFg,
            reason: '${base.id}: tertiary 必须取 display.errorFg');
      }
    });

    test('深色角色取自选中主题的**深色**变体', () {
      for (final base in CalcTheme.all) {
        expect(AppTheme.dark(base).colorScheme.primary, base.dark.display.indicatorFg,
            reason: '${base.id}: 深色 primary 必须取深色变体的 display.indicatorFg');
      }
    });

    test('三个主题派生出**不同**的 primary（防来源被钉死在一套主题上）', () {
      final primaries =
          CalcTheme.all.map((t) => AppTheme.light(t).colorScheme.primary).toSet();
      expect(primaries.length, CalcTheme.all.length,
          reason: '若有主题的 primary 与别的主题相同，多半是派生被错误地钉死在某一套调色板上');
    });
  });

  // 中文：把三套主题派生出的 primary 打出来，不是为了断言，是为了让人**看见**它们确实不同——
  //       切主题时全应用的强调色是跟着走的，而不是三套都落在同一个色值上。
  // English: Prints each theme's derived primary, not to assert but so a human can *see* they differ —
  //          the app-wide accent follows the picker instead of every theme landing on one value.
  test('print derived primaries for the three themes', () {
    for (final base in CalcTheme.all) {
      debugPrint('AppTheme ${base.id}: light=${AppTheme.light(base).colorScheme.primary} '
          'dark=${AppTheme.dark(base).colorScheme.primary}');
    }
  });
}
