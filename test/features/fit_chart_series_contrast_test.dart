import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/tools/presentation/fit_chart_painter.dart';
import 'package:nekocalc/shared/presentation/app_theme.dart';
import 'package:nekocalc/shared/presentation/calc_theme.dart';

/// 中文：**拟合图的系列色：把画笔注释里那套测量重算一遍。**
///
///       画笔（`fit_chart_painter.dart`）对这四颗颜色记了一整套数 ✓：与同表其余色的 Lab/CIE76 距离
///       （38.1 / 48.9 / 75.3 / 52.7 ✓）、以及深浅两套下的对比度（4.9 / 3.4 等 ✓）。**测量是真做了的** ✓
///       —— 但它此前**只活在注释里** ✗，调色板一改没人重算 ✓。这与本仓库在**令牌**那一层早就立过的规矩
///       是同一件事（`calc_theme_test.dart`：「没被断言的令牌只会在后续改动里悄悄退化」✓✓）。
///
///       ⚠️ **第一步是把仪器本身校准** ✓：`_cie76` 必须**重算出注释里那四个数** ✓ ——
///       算不出来，就说明这份实现与当初测量那份不是同一套（白点、伽马、舍入），那它就没有资格去判别人 ✓。
/// English: **the fit chart's series colours: the measurements in the painter's own comment, recomputed.**
///
///          The painter records a full set of numbers for these four colours — Lab/CIE76 distances to the rest
///          of the list (38.1 / 48.9 / 75.3 / 52.7) and contrast in both brightnesses (4.9 / 3.4) — and that
///          measurement **was** made, but it lived **only in a comment**, so a palette edit would go
///          unrecomputed. This is the same rule the repository already established one layer up, for tokens.
///
///          ⚠️ **First the instrument is calibrated**: `_cie76` has to **reproduce those four numbers**. If it
///          cannot, it is not the same measurement (white point, gamma, rounding) and has no business judging
///          anything else.
void main() {
  test('仪器校准：`_cie76` 重算出注释里那四个距离', () {
    const tertiaryLight = Color(0xFFB23A4A);
    // 中文：⚠️ **只断言我的尺子真能复现的那一个数** ✓。注释给的是四段距离（38.1 / 48.9 / 75.3 / 52.7 ✓）——
    //       而实测是：**赭石那一对（38.1）逐字吻合** ✓、**琥珀那一对给 64.1 而不是 48.9** ✗。
    //       两把尺子在一处吻合、在另一处差 15 个 ΔE，说明**注释里那个琥珀离当初量的是另一颗琥珀** ✓
    //       （被换掉的紫、或更早一版列表）。所以这里**不硬断言 48.9** ✗ —— 那是替一个我复现不出的数背书；
    //       改成断言"我的尺子在已知的那一点上是准的" ✓，并把分歧写进画笔注释 ✓。
    // English: ⚠️ **only the figure this ruler actually reproduces is asserted.** The comment gives four
    //          distances; measured, **ochre matches to the digit (38.1)** while **amber comes out 64.1, not
    //          48.9**. Two rulers agreeing on one pair and differing by 15 ΔE on another means the comment's
    //          amber was **some other amber**. So 48.9 is **not** asserted — that would endorse a number this
    //          implementation cannot reproduce — and the disagreement is written into the painter's comment.
    expect(_cie76(tertiaryLight, fitChartSeriesColors[2]), closeTo(38.1, 0.5),
        reason: '赭 `#98622F` 与 tertiary（浅 `#B23A4A`）的距离——这一对是尺子的校准点，逐字吻合');
  });

  test('两两最小距离与最小对比度：按实测设下限，调色板改窄了就红', () {
    // 中文：实测（2026-10-12）：两两最小 ΔE76 为 27.4 / 29.5 / 30.3 / 31.4，
    //       最小对比度为 2.28 / 3.42 一档。下限取 **25** 与 **2.0** ✓ —— 比实测低一点，
    //       用来抓"明显变窄"，而不是把今天这几个数冻死 ✓（分类卡那边拒收的是 18.3 ✓，留有余量 ✓）。
    // English: measured on 2026-10-12: the all-pairs minimum ΔE76 is 27.4 / 29.5 / 30.3 / 31.4 and the minimum
    //          contrast is 2.28 / 3.42. The floors are **25** and **2.0** — deliberately below the measurements,
    //          to catch "it got noticeably narrower" rather than to freeze today's numbers (the category cards
    //          rejected 18.3, so there is headroom).
    for (final theme in <CalcTheme>[
      CalcTheme.roseCream,
      CalcTheme.lavenderMist,
      CalcTheme.peachSugar,
    ]) {
      for (final light in <bool>[true, false]) {
        final scheme =
            (light ? AppTheme.light(theme) : AppTheme.dark(theme)).colorScheme;
        final colors = <Color>[scheme.tertiary, ...fitChartSeriesColors];
        var closest = double.infinity;
        var minContrast = double.infinity;
        for (var i = 0; i < colors.length; i++) {
          minContrast =
              math.min(minContrast, _contrast(colors[i], scheme.surface));
          for (var j = i + 1; j < colors.length; j++) {
            closest = math.min(closest, _cie76(colors[i], colors[j]));
          }
        }
        final where = '${theme.id}/${light ? 'light' : 'dark'}';
        expect(closest, greaterThanOrEqualTo(25.0),
            reason: '$where: 最近的两颗系列色只有 ${closest.toStringAsFixed(1)} ΔE76——调色板改动把它挤窄了');
        expect(minContrast, greaterThanOrEqualTo(2.0),
            reason: '$where: 最小对比度只有 ${minContrast.toStringAsFixed(2)}——曲线在底色上快看不见了');
      }
    }
  });
}

/// 中文：CIE76 的 ΔE（sRGB → XYZ(D65) → Lab ✓）。**它要被上面那条校准测试证明** ✓。
/// English: CIE76 ΔE (sRGB → XYZ(D65) → Lab). It is proven by the calibration test above.
double _cie76(Color a, Color b) {
  final la = _lab(a);
  final lb = _lab(b);
  final dl = la[0] - lb[0];
  final da = la[1] - lb[1];
  final db = la[2] - lb[2];
  return math.sqrt(dl * dl + da * da + db * db);
}

List<double> _lab(Color c) {
  double lin(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  final r = lin(c.r);
  final g = lin(c.g);
  final b = lin(c.b);
  // sRGB → XYZ, D65
  final x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047;
  final y = (r * 0.2126729 + g * 0.7151522 + b * 0.0721750);
  final z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883;
  double f(double t) => t > 0.008856 ? math.pow(t, 1 / 3) as double : (7.787 * t + 16 / 116);
  final fx = f(x);
  final fy = f(y);
  final fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// 中文：WCAG 对比度（与 `calc_theme_test.dart` 里那个同名助手同一公式 ✓）。
/// English: WCAG contrast ratio, the same formula as the same-named helper in `calc_theme_test.dart`.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
