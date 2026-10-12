import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/utils/number_formatter.dart';

import '../../../domain/usecases/data_fit.dart';

/// 中文：**拟合图的系列色** —— 这四颗字面量，加上每个调色板自己的 `tertiary` 作为第一色。
///
///       它为什么是**具名常量**而不是写在 `_seriesColor` 里的临时表 ✓：这些是**量过的**决定 ✓，
///       而量过的决定该有名字、也该能被**重算** ✓（`test/features/fit_chart_series_contrast_test.dart`
///       会把下面这些数重算一遍 ✓✓）。留在函数里的字面量只会随调色板漂移而没人发现 ✗ ——
///       这正是本仓库在**令牌**那一层已经立过的规矩（`calc_theme_test.dart`：
///       「没被断言的令牌只会在后续改动里悄悄退化」✓✓）。
///
///       第四色原是冷紫 `#8B5CF6`（色相 258°），在暖奶油画布上是最后一块冷色孤岛——与分类卡那批同类冲突。
///       换成 `peachSugar.display.indicatorFg`（赭 `#98622F`，逐字节相同；分类卡 `science` 丢掉同一个紫时
///       用的也是这个令牌）。Lab 里 CIE76 量过与同表其余色的距离：tertiary（浅色 `#B23A4A`）38.1、
///       琥珀 48.9、绿 75.3、红 52.7——最近的一对仍有 38，比被换掉的紫离 tertiary 的距离（浅色下 20 上下）宽。
///       深浅两套下的对比度 4.9 / 3.4，与表内既有的绿 2.6 / 6.4、琥珀 2.3 / 7.4 同一条带里，
///       没有靠看不清换暖色。
/// English: **the fit chart's series colours** — these four literals plus each palette's own `tertiary` as the
///          first one. Named rather than inline because they are **measured** decisions, and a measured decision
///          deserves a name and the chance to be **recomputed** (`fit_chart_series_contrast_test.dart` does
///          exactly that). A literal left inside a function only drifts with the palette, unnoticed — the rule
///          this repository already established one layer up, for tokens (`calc_theme_test.dart`: "an unasserted
///          token only ever rots silently in a later edit").
///
///          The fourth colour used to be a cool violet `#8B5CF6` (hue 258°) — the last cool island on the warm
///          canvas, the clash the category cards already fixed. It became `peachSugar.display.indicatorFg`
///          (ochre `#98622F`, byte-for-byte the token the `science` card took when it dropped that same violet).
///          Measured in Lab with CIE76 — ⚠️ **and 2026-10-12 split one sentence into the two questions it was
///          actually answering**, because a recomputation disagreed with part of it:
///          ① **Distance from `tertiary` to each of the four** (light `#B23A4A`): 38.1 ochre, 48.9 amber,
///             75.3 green, 52.7 red — **min 38.1**, wider than the violet it replaces. ✅ A fresh
///             implementation reproduces **ochre's 38.1 exactly**; ⚠️ it gives **64.1 for amber** and **109.0
///             for green** instead of 48.9 / 75.3, so **two of the four figures are about earlier colours** —
///             this comment records a moment, and the list has changed since (ochre itself was swapped in
///             later). They are left as written rather than quietly corrected; the reproducible one is the
///             calibration point the test asserts.
///          ② **All pairs among the five** — the question this sentence used to *read* like it answered, and
///             never did: the closest pair is **27.4** (measured across all three palettes: 27.4 / 29.5 / 30.3 /
///             31.4). ⚠️ Still clear of the **18.3** the category cards rejected as too close, so the series
///             stay tellable apart — but **"the closest pair sits at 38" was only ever true of ①** ✗.
///          Contrast in the two brightnesses is 4.9 / 3.4, and a fresh measurement gives a **minimum of 2.28**
///          across palettes and brightnesses — inside the band the existing green (2.6 / 6.4) and amber
///          (2.3 / 7.4) already occupy, so the warmth is not bought with illegibility.
///          ⚠️ Both halves are recomputed by `test/features/fit_chart_series_contrast_test.dart`, so a palette
///          edit that narrows them now fails a test instead of editing this comment.
const List<Color> fitChartSeriesColors = <Color>[
  Color(0xFFFF8A00),
  Color(0xFF23B45D),
  Color(0xFF98622F),
  Color(0xFFFF4D5E),
];

class FitChartPainter extends CustomPainter {
  const FitChartPainter({
    required this.result,
    required this.series,
    required this.selectedSeriesIndex,
    required this.residualAlerts,
    required this.scheme,
    required this.legendFitSuffix,
  });

  final FitResult result;
  final List<DataSeries> series;
  final int selectedSeriesIndex;
  final List<FitResidualPoint> residualAlerts;
  final ColorScheme scheme;

  /// 中文：图例里跟在选中数据组名字后面的那句后缀（`DataFitStrings.legendFitSuffix`）。
  ///       画笔不持有 `BuildContext`，所以文案由调用方传进来；它同时进了 [shouldRepaint]，
  ///       否则切成英文之后图例不会重画。
  /// English: The suffix the legend appends to the selected series' name
  ///          (`DataFitStrings.legendFitSuffix`). A painter holds no `BuildContext`, so the caller
  ///          passes the copy in; it is also part of [shouldRepaint], without which the legend would
  ///          not be repainted after switching to English.
  final String legendFitSuffix;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = EdgeInsets.fromLTRB(52, 22, 20, 42);
    final dark = scheme.brightness == Brightness.dark;
    final backgroundColor = scheme.surface;
    final plotColor = scheme.surface;
    final labelColor = scheme.onSurface;
    final mutedLabelColor = scheme.onSurfaceVariant;
    final gridColor =
        scheme.outlineVariant.withValues(alpha: dark ? 0.52 : 0.62);
    final borderColor = scheme.outlineVariant;
    final labelBackground =
        scheme.surface.withValues(alpha: dark ? 0.92 : 0.96);
    final legendBackground =
        scheme.surface.withValues(alpha: dark ? 0.94 : 0.97);
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );
    final allPoints = [
      for (final item in series) ...item.points,
      ...result.predictions,
    ];
    // 中文：坐标范围同时纳入原始点和预测点，保证拟合曲线不会被裁掉。
    // English: Axis bounds include both raw points and predictions so the fitted curve is not clipped.
    final minX = allPoints.map((p) => p.x).reduce(math.min);
    final maxX = allPoints.map((p) => p.x).reduce(math.max);
    final minY = allPoints.map((p) => p.y).reduce(math.min);
    final maxY = allPoints.map((p) => p.y).reduce(math.max);
    final xRange = (maxX - minX).abs() < 1e-9 ? 1.0 : maxX - minX;
    final yRange = (maxY - minY).abs() < 1e-9 ? 1.0 : maxY - minY;

    Offset map(DataPoint p) {
      final x = plot.left + (p.x - minX) / xRange * plot.width;
      final y = plot.bottom - (p.y - minY) / yRange * plot.height;
      return Offset(x, y);
    }

    final chartBackground = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, chartBackground);

    final plotBackground = Paint()..color = plotColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(plot, const Radius.circular(8)),
      plotBackground,
    );

    final axisPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.4;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.65;
    final zeroAxisPaint = Paint()
      ..color = scheme.primary.withValues(alpha: dark ? 0.86 : 0.68)
      ..strokeWidth = 1.3;
    final lineShadowPaint = Paint()
      ..color = scheme.primary.withValues(alpha: 0.28)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePaint = Paint()
      ..color = scheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i <= 5; i++) {
      // 中文：固定 5 等分网格，移动端上标签密度稳定，避免小屏拥挤。
      // English: A fixed five-step grid keeps label density stable and avoids crowding on phones.
      final xValue = minX + xRange * i / 5;
      final yValue = minY + yRange * i / 5;
      final x = plot.left + plot.width * i / 5;
      final y = plot.bottom - plot.height * i / 5;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _drawLabel(canvas, Offset(x - 14, plot.bottom + 7),
          formatNumber(xValue, precision: 3), scheme,
          color: mutedLabelColor, backgroundColor: labelBackground);
      _drawLabel(
          canvas, Offset(6, y - 7), formatNumber(yValue, precision: 3), scheme,
          color: mutedLabelColor, backgroundColor: labelBackground);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(plot, const Radius.circular(8)),
      axisPaint,
    );
    if (minX <= 0 && maxX >= 0) {
      final zeroX = plot.left + (0 - minX) / xRange * plot.width;
      canvas.drawLine(
          Offset(zeroX, plot.top), Offset(zeroX, plot.bottom), zeroAxisPaint);
    }
    if (minY <= 0 && maxY >= 0) {
      final zeroY = plot.bottom - (0 - minY) / yRange * plot.height;
      canvas.drawLine(
          Offset(plot.left, zeroY), Offset(plot.right, zeroY), zeroAxisPaint);
    }

    final lineMinX = result.points.map((p) => p.x).reduce(math.min);
    final lineMaxX = result.points.map((p) => p.x).reduce(math.max);
    // 中文：拟合曲线只在样本 x 范围内绘制，避免外推线误导用户。
    // English: Draw the fit only across the sampled x-range to avoid misleading extrapolation.
    final linePoints = _sampleFit(lineMinX, lineMaxX);
    final path = Path();
    for (var i = 0; i < linePoints.length; i++) {
      final offset = map(linePoints[i]);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(path, lineShadowPaint);
    canvas.drawPath(path, linePaint);

    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final selected = seriesIndex == selectedSeriesIndex;
      final paint = Paint()
        ..color = _seriesColor(seriesIndex, selected)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = selected ? scheme.onSurface : scheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.7 : 1;
      final haloPaint = Paint()
        ..color = _seriesColor(seriesIndex, selected).withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      for (var pointIndex = 0;
          pointIndex < series[seriesIndex].points.length;
          pointIndex++) {
        final point = series[seriesIndex].points[pointIndex];
        final offset = map(point);
        final isAlert = selected && _isResidualAlertPoint(point);
        if (selected) canvas.drawCircle(offset, 7.4, haloPaint);
        if (isAlert) {
          canvas.drawCircle(
            offset,
            9.6,
            Paint()
              ..color = scheme.error.withValues(alpha: 0.2)
              ..style = PaintingStyle.fill,
          );
        }
        canvas.drawCircle(offset, selected ? 4.3 : 3.4, paint);
        canvas.drawCircle(offset, selected ? 4.3 : 3.4, strokePaint);
        if (isAlert) {
          canvas.drawCircle(
            offset,
            7.1,
            Paint()
              ..color = scheme.error
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8,
          );
        }
      }
    }

    _drawLegend(canvas, plot, scheme,
        labelColor: labelColor,
        mutedLabelColor: mutedLabelColor,
        backgroundColor: legendBackground);
  }

  List<DataPoint> _sampleFit(double minX, double maxX) {
    final points = <DataPoint>[];
    const steps = 64;
    // 中文：64 个采样点在平滑度和绘制成本之间足够均衡。
    // English: Sixty-four samples balance smoothness and painting cost.
    for (var i = 0; i <= steps; i++) {
      final x = minX + (maxX - minX) * i / steps;
      points.add(DataPoint(x, _predict(x)));
    }
    return points;
  }

  double _predict(double x) {
    return predictFitValue(result, x);
  }

  bool _isResidualAlertPoint(DataPoint point) {
    return residualAlerts.any(
      (alert) =>
          (alert.point.x - point.x).abs() < 1e-9 &&
          (alert.point.y - point.y).abs() < 1e-9,
    );
  }

  void _drawLabel(
    Canvas canvas,
    Offset offset,
    String text,
    ColorScheme scheme, {
    required Color color,
    Color? backgroundColor,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (backgroundColor != null) {
      final rect = Rect.fromLTWH(
        offset.dx - 3,
        offset.dy - 2,
        painter.width + 6,
        painter.height + 4,
      );
      final paint = Paint()..color = backgroundColor;
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    }
    painter.paint(canvas, offset);
  }

  Color _seriesColor(int index, bool selected) {
    final colors = [scheme.tertiary, ...fitChartSeriesColors];
    final color = colors[index % colors.length];
    return selected ? color : color.withValues(alpha: 0.42);
  }

  void _drawLegend(
    Canvas canvas,
    Rect plot,
    ColorScheme scheme, {
    required Color labelColor,
    required Color mutedLabelColor,
    required Color backgroundColor,
  }) {
    final maxItems = math.min(series.length, 4);
    var dx = plot.left + 8;
    final y = plot.top + 8;
    for (var i = 0; i < maxItems; i++) {
      final selected = i == selectedSeriesIndex;
      final paint = Paint()
        ..color = _seriesColor(i, selected)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dx + 5, y + 5), 4, paint);
      final label =
          selected ? '${series[i].name}$legendFitSuffix' : series[i].name;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: selected ? labelColor : mutedLabelColor,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 78);
      final chipRect = Rect.fromLTWH(
        dx - 4,
        y - 3,
        painter.width + 24,
        painter.height + 7,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chipRect, const Radius.circular(6)),
        Paint()..color = backgroundColor,
      );
      painter.paint(canvas, Offset(dx + 13, y));
      dx += painter.width + 26;
      if (dx > plot.right - 56) break;
    }
  }

  @override
  bool shouldRepaint(covariant FitChartPainter oldDelegate) {
    return oldDelegate.result != result ||
        oldDelegate.series != series ||
        oldDelegate.selectedSeriesIndex != selectedSeriesIndex ||
        oldDelegate.residualAlerts != residualAlerts ||
        oldDelegate.scheme != scheme ||
        oldDelegate.legendFitSuffix != legendFitSuffix;
  }
}
