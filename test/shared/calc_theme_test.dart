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

    test('foreground contrasts with its own background', () {
      for (final t in variants) {
        for (final pair in [
          (t.keys.digitBg, t.keys.digitFg),
          (t.keys.operatorBg, t.keys.operatorFg),
          (t.keys.functionBg, t.keys.functionFg),
          (t.keys.destructiveBg, t.keys.destructiveFg),
          (t.display.background, t.display.expressionFg),
        ]) {
          final ratio = _contrast(pair.$1, pair.$2);
          expect(ratio, greaterThan(4.5),
              reason: '${t.id}/${t.brightness}: 对比度 $ratio 低于 4.5，不可读');
        }
      }
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
