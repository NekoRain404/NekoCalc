import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/graph_models.dart';

class GraphPainter extends CustomPainter {
  const GraphPainter({
    required this.functions,
    required this.viewport,
    required this.markers,
    required this.selectedMarker,
    required this.gridColor,
    required this.axisColor,
    required this.labelColor,
    required this.markerLabelColor,
    required this.markerLabelBackground,
    required this.markerLabelBorder,
  });

  final List<GraphFunction> functions;
  final GraphViewport viewport;
  final List<GraphMarker> markers;
  final int? selectedMarker;
  final Color gridColor;
  final Color axisColor;
  final Color labelColor;
  final Color markerLabelColor;
  final Color markerLabelBackground;
  final Color markerLabelBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    // 中文：网格步长使用 1/2/5 序列，让缩放时刻度更接近工程图表习惯。
    // English: Grid steps use the 1/2/5 sequence so zoomed ticks feel like engineering charts.
    final xStep = _niceStep(viewport.spanX / 8);
    final yStep = _niceStep(viewport.spanY / 8);
    for (var x = (viewport.xMin / xStep).floor() * xStep;
        x <= viewport.xMax;
        x += xStep) {
      final sx = viewport.toScreenX(x, size);
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), grid);
      _label(canvas, textPainter, x.toStringAsFixed(_digits(xStep)),
          Offset(sx + 3, size.height - 18));
    }
    for (var y = (viewport.yMin / yStep).floor() * yStep;
        y <= viewport.yMax;
        y += yStep) {
      final sy = viewport.toScreenY(y, size);
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), grid);
      _label(canvas, textPainter, y.toStringAsFixed(_digits(yStep)),
          Offset(4, sy - 16));
    }
    if (viewport.yMin <= 0 && viewport.yMax >= 0) {
      final y0 = viewport.toScreenY(0, size);
      canvas.drawLine(Offset(0, y0), Offset(size.width, y0), axis);
    }
    if (viewport.xMin <= 0 && viewport.xMax >= 0) {
      final x0 = viewport.toScreenX(0, size);
      canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), axis);
    }
    for (final function in functions.where((item) => item.visible)) {
      _plot(canvas, size, function);
    }
    _plotMarkers(canvas, size);
  }

  void _plot(Canvas canvas, Size size, GraphFunction function) {
    final paint = Paint()
      ..color = function.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    final segments = buildGraphPlotSegments(
      function: function,
      viewport: viewport,
      width: size.width,
      height: size.height,
    );
    for (final segment in segments) {
      for (var i = 0; i < segment.length; i++) {
        final point = segment[i];
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
    }
    canvas.drawPath(path, paint);
  }

  void _plotMarkers(Canvas canvas, Size size) {
    // 中文：只绘制当前视窗内的标记，平移后隐藏离屏点，避免标签污染画布。
    // English: Paint only in-viewport markers so offscreen points do not pollute the canvas after panning.
    for (var i = 0; i < markers.length; i++) {
      final marker = markers[i];
      if (marker.x < viewport.xMin ||
          marker.x > viewport.xMax ||
          marker.y < viewport.yMin ||
          marker.y > viewport.yMax) {
        continue;
      }
      final center = Offset(viewport.toScreenX(marker.x, size),
          viewport.toScreenY(marker.y, size));
      final selected = selectedMarker == i;
      final fill = Paint()..color = marker.color;
      final halo = Paint()
        ..color = marker.color.withValues(alpha: selected ? 0.22 : 0.12);
      final stroke = Paint()
        ..color = markerLabelBackground
        ..strokeWidth = selected ? 3 : 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, selected ? 14 : 10, halo);
      canvas.drawCircle(center, selected ? 6.5 : 5, fill);
      canvas.drawCircle(center, selected ? 6.5 : 5, stroke);
      if (selected) {
        _markerLabel(canvas, marker.kind, center + const Offset(10, -28));
      }
    }
  }

  void _markerLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: markerLabelColor,
              fontSize: 11,
              fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(
        offset.dx - 6, offset.dy - 4, painter.width + 12, painter.height + 8);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = markerLabelBackground);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = markerLabelBorder
        ..style = PaintingStyle.stroke,
    );
    painter.paint(canvas, offset);
  }

  void _label(Canvas canvas, TextPainter painter, String text, Offset offset) {
    painter.text =
        TextSpan(text: text, style: TextStyle(color: labelColor, fontSize: 10));
    painter.layout();
    painter.paint(canvas, offset);
  }

  double _niceStep(double value) {
    final exponent =
        math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    final fraction = value / exponent;
    final nice = fraction <= 1
        ? 1
        : fraction <= 2
            ? 2
            : fraction <= 5
                ? 5
                : 10;
    return nice * exponent;
  }

  int _digits(double step) => step < 1
      ? 2
      : step < 10
          ? 1
          : 0;

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.functions != functions ||
        oldDelegate.viewport != viewport ||
        oldDelegate.markers != markers ||
        oldDelegate.selectedMarker != selectedMarker ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.markerLabelColor != markerLabelColor ||
        oldDelegate.markerLabelBackground != markerLabelBackground ||
        oldDelegate.markerLabelBorder != markerLabelBorder;
  }
}

