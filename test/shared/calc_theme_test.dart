import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

void main() {
  // 中文：断言覆盖每个内置主题的浅色与深色变体，避免只测一套变体漏掉跨变体分歧。
  // English: Assertions cover every built-in variant, light and dark, so a
  // divergence in one variant cannot slip past a single-theme test.
  final variants = <CalcTheme>[
    for (final theme in CalcTheme.all) ...<CalcTheme>[theme, theme.dark],
  ];

  group('CalcTheme', () {
    test('exposes three built-in themes with distinct ids', () {
      expect(CalcTheme.all.length, 3);
      final ids = CalcTheme.all.map((t) => t.id).toSet();
      expect(ids.length, 3, reason: '主题 id 必须互不相同');
    });

    test('every theme defines both a light and a dark variant', () {
      final byId = {for (final t in CalcTheme.all) t.id: t};
      expect(byId['roseCream']!.brightness, Brightness.light);
      expect(byId['roseCream']!.dark.brightness, Brightness.dark);
      expect(byId['lavenderMist']!.brightness, Brightness.light);
      expect(byId['lavenderMist']!.dark.brightness, Brightness.dark);
      expect(byId['peachSugar']!.brightness, Brightness.light);
      expect(byId['peachSugar']!.dark.brightness, Brightness.dark);
    });

    test('semantic key colours are distinct within a theme', () {
      for (final t in variants) {
        final bg = <Color>[
          t.keys.digitBg,
          t.keys.operatorBg,
          t.keys.functionBg,
          t.keys.variableBg,
          t.keys.modifierBg,
          t.keys.destructiveBg,
        ];
        expect(bg.toSet().length, bg.length,
            reason: '${t.id}/${t.brightness}: 每类按键的背景色必须可区分，否则语义分类失效');
      }
    });

    test('destructive keys are visually distinct from modifier keys', () {
      for (final t in variants) {
        expect(t.keys.destructiveBg, isNot(t.keys.modifierBg),
            reason: '${t.id}/${t.brightness}: 破坏性操作与模态键不能同色，否则误触风险');
      }
    });

    test('destructive keys use a warm warning hue', () {
      for (final t in variants) {
        final hue = HSVColor.fromColor(t.keys.destructiveBg).hue;
        expect(hue <= 40 || hue >= 330, isTrue,
            reason: '${t.id}/${t.brightness}: 破坏性按键必须是暖色警示，当前色相 $hue 落冷色区间');
      }
    });

    test('shift 小标签与模态键文字可区分，且按注释所述更淡', () {
      for (final t in variants) {
        expect(t.keys.shiftLabelFg, isNot(t.keys.modifierFg),
            reason: '${t.id}/${t.brightness}: shift 小标签与键面文字同色就失去了层次');
        // 中文：`shiftLabelFg` 的文档注释承诺"比键面文字更淡"；更淡 = 与键位底色的对比更低。
        // English: the doc comment on `shiftLabelFg` promises a label dimmer than the key glyph;
        //          dimmer means a lower contrast against the key's own background.
        expect(
          _contrast(t.keys.modifierBg, t.keys.shiftLabelFg),
          lessThan(_contrast(t.keys.modifierBg, t.keys.modifierFg)),
          reason: '${t.id}/${t.brightness}: shift 小标签应当比键面文字更淡',
        );
      }
    });

    test('foreground contrasts with its own background', () {
      // 中文：阈值取 WCAG AA 对正文的 4.5:1。覆盖面是**令牌模型里暴露的每一对前景/背景**，
      //       而不只是界面当前恰好用到的那几对：没被断言的令牌只会在后续改动里悄悄退化
      //       （`shiftLabelFg`、`statusFg`、`indicatorFg` 就是这样跌到 4.5 以下的）。
      //       没有自备底色的前景色，按其文档注释列在它实际会落在的两个底色上。
      // English: The threshold is WCAG AA for body text, 4.5:1. Coverage is **every
      //          foreground/background pair the token model exposes**, not just the few the UI
      //          happens to use right now: an unasserted token only ever rots silently in a later
      //          edit (`shiftLabelFg`, `statusFg` and `indicatorFg` fell below 4.5 exactly that
      //          way). Foregrounds that own no background of their own are listed against each
      //          background their doc comment says they land on.
      for (final t in variants) {
        final pairs = <(String, Color, Color)>[
          ('display.background/expressionFg', t.display.background,
              t.display.expressionFg),
          ('display.background/resultFg', t.display.background, t.display.resultFg),
          ('display.background/statusFg', t.display.background, t.display.statusFg),
          ('display.background/indicatorFg', t.display.background,
              t.display.indicatorFg),
          ('display.background/errorFg', t.display.background, t.display.errorFg),
          ('digitBg/digitFg', t.keys.digitBg, t.keys.digitFg),
          ('operatorBg/operatorFg', t.keys.operatorBg, t.keys.operatorFg),
          ('functionBg/functionFg', t.keys.functionBg, t.keys.functionFg),
          ('variableBg/variableFg', t.keys.variableBg, t.keys.variableFg),
          ('modifierBg/modifierFg', t.keys.modifierBg, t.keys.modifierFg),
          ('destructiveBg/destructiveFg', t.keys.destructiveBg,
              t.keys.destructiveFg),
          ('accentBg/accentFg', t.keys.accentBg, t.keys.accentFg),
          ('pillBg/pillFg', t.keys.pillBg, t.keys.pillFg),
          ('modifierBg/shiftLabelFg', t.keys.modifierBg, t.keys.shiftLabelFg),
          ('keypadBackground/shiftLabelFg', t.keypadBackground,
              t.keys.shiftLabelFg),
        ];
        for (final (label, bg, fg) in pairs) {
          final ratio = _contrast(bg, fg);
          expect(ratio, greaterThanOrEqualTo(_minContrast),
              reason: '${t.id}/${t.brightness} $label: 对比度 $ratio 低于 '
                  '$_minContrast，不可读');
        }
      }
    });
  });
}

/// 中文：正文可读性的下限，取 WCAG AA 对普通字号文本的要求。
/// English: The floor for readable body text, taken from WCAG AA for normal-size text.
const double _minContrast = 4.5;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
