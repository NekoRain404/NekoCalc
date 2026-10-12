import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 中文：**颜色度量的唯一一份实现**（`cie76` 与 WCAG 对比度）。
///
///       ⚠️ **它为什么是共享文件而不是各测试各抄一份** ✓：这仓库的规矩是"**一个判据只留一个拼法**" ✓——
///       抄两份，就是让两份在各次改动里**各自漂移** ✓，而漂移出来的两个数**都自称是同一件事** ✗。
///       实测（2026-10-12）：`calc_theme_test.dart` 里那份 `_contrast` 与我在拟合图那条里另写的那份，
///       公式相同但**互不知情** ✓ —— 第三次要用它时，才把它提出来 ✓。
///
///       ⚠️ **而尺子本身要能被校准** ✓：`cie76` 有 `fit_chart_series_contrast_test.dart` 里那条
///       校准测试（重算画笔注释里那个 38.1 ✓）—— 一把没有校准点的尺子，量出来的数没有意义 ✓。
/// English: **the single implementation of the colour metrics** (CIE76 and the WCAG contrast ratio).
///
///          ⚠️ **Why a shared file rather than a copy per test:** this repository's rule is one judgement, one
///          spelling. Copies drift apart, and both then claim to be the same measurement. Measured on
///          2026-10-12: `calc_theme_test.dart`'s `_contrast` and the one I wrote separately for the fit-chart
///          test held the same formula and knew nothing of each other — the third use is what promoted it here.
///
///          ⚠️ **And the ruler has to be calibratable:** `cie76` is calibrated by
///          `fit_chart_series_contrast_test.dart`, which recomputes the 38.1 recorded in the painter's comment.
///          A ruler with no calibration point measures nothing.

/// 中文：CIE76 的 ΔE（sRGB → XYZ(D65) → Lab）。
/// English: CIE76 ΔE (sRGB → XYZ(D65) → Lab).
double cie76(Color a, Color b) {
  final la = _lab(a);
  final lb = _lab(b);
  final dl = la[0] - lb[0];
  final da = la[1] - lb[1];
  final db = la[2] - lb[2];
  return math.sqrt(dl * dl + da * da + db * db);
}

/// 中文：WCAG 对比度（`(亮+0.05)/(暗+0.05)`，与 `calc_theme_test.dart` 里那套同一公式 ✓）。
/// English: the WCAG contrast ratio — the same formula `calc_theme_test.dart` uses.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

List<double> _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  final r = lin(c.r);
  final g = lin(c.g);
  final b = lin(c.b);
  // sRGB → XYZ, D65
  final x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047;
  final y = (r * 0.2126729 + g * 0.7151522 + b * 0.0721750);
  final z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3) as double : (7.787 * t + 16 / 116);
  final fx = f(x);
  final fy = f(y);
  final fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}
