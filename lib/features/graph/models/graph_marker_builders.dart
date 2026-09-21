part of 'graph_models.dart';

List<GraphMarker> buildSampleMarkers({
  required Iterable<GraphFunction> functions,
  required double x,
  required double yMin,
  required double yMax,
  required GraphStrings strings,
}) {
  final visible = functions.where((item) => item.visible).toList();
  final values = <({GraphFunction function, double y})>[];
  for (final function in visible) {
    final y = function.evaluate(x);
    if (y.isFinite && !y.isNaN && y >= yMin && y <= yMax) {
      values.add((function: function, y: y));
    }
  }
  return [
    for (var i = 0; i < values.length; i++)
      GraphMarker(
        x: x,
        y: values[i].y,
        color: values[i].function.color,
        kind: strings.sampleKind,
        info: [
          'x = ${x.toStringAsFixed(6)}',
          for (final value in values)
            '${value.function.label}: y = ${value.y.toStringAsFixed(6)}',
        ].join('\n'),
      ),
  ];
}

List<GraphMarker> buildGraphZeroMarkers({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
  required GraphStrings strings,
  int samples = 800,
}) {
  final visible = functions.where((item) => item.visible).toList();
  if (visible.isEmpty || !_yInViewport(0, viewport)) return const [];
  final markers = <GraphMarker>[];
  final tolerance = _rootResidualTolerance(viewport);
  final xTolerance = viewport.spanX / samples * 3;
  for (final function in visible) {
    if (_mostlyZeroAcrossViewport(
      evaluate: function.evaluate,
      viewport: viewport,
      samples: samples,
      tolerance: tolerance,
    )) {
      _addMarkerIfUnique(
        markers,
        GraphMarker(
          x: viewport.centerX,
          y: 0,
          color: function.color,
          kind: strings.zeroKind,
          info: strings.overlapsAxis(function.label),
        ),
        xTolerance,
        tolerance,
      );
      continue;
    }
    final roots = _findRootCandidates(
      evaluate: function.evaluate,
      xMin: viewport.xMin,
      xMax: viewport.xMax,
      samples: samples,
      tolerance: tolerance,
    );
    for (final root in roots) {
      final y = function.evaluate(root);
      if (!_finiteNumber(y) || y.abs() > tolerance) continue;
      _addMarkerIfUnique(
        markers,
        GraphMarker(
          x: root,
          y: 0,
          color: function.color,
          kind: strings.zeroKind,
          info: strings.zeroAt(function.label, root.toStringAsFixed(6)),
        ),
        xTolerance,
        tolerance,
      );
    }
  }
  return markers;
}

List<GraphMarker> buildGraphIntersectionMarkers({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
  required GraphStrings strings,
  int samples = 800,
}) {
  final visible = functions.where((item) => item.visible).toList();
  if (visible.length < 2) return const [];
  final markers = <GraphMarker>[];
  final tolerance = _rootResidualTolerance(viewport);
  final xTolerance = viewport.spanX / samples * 3;
  // 中文：所有可见函数两两配对，避免只检查前两条曲线导致交点缺失。
  // English: Compare every visible function pair so intersections are not limited to the first two curves.
  for (var i = 0; i < visible.length; i++) {
    for (var j = i + 1; j < visible.length; j++) {
      final first = visible[i];
      final second = visible[j];
      double difference(double x) => first.evaluate(x) - second.evaluate(x);
      if (_mostlyZeroAcrossViewport(
        evaluate: difference,
        viewport: viewport,
        samples: samples,
        tolerance: tolerance,
      )) {
        final overlap = _firstVisiblePoint(first, viewport, samples);
        if (overlap != null) {
          _addMarkerIfUnique(
            markers,
            GraphMarker(
              x: overlap.$1,
              y: overlap.$2,
              color: const Color(0xFFFF8A00),
              kind: strings.overlapKind,
              info: strings.overlapText(first.label, second.label),
            ),
            xTolerance,
            tolerance,
          );
        }
        continue;
      }
      final roots = _findRootCandidates(
        evaluate: difference,
        xMin: viewport.xMin,
        xMax: viewport.xMax,
        samples: samples,
        tolerance: tolerance,
      );
      for (final root in roots) {
        final firstY = first.evaluate(root);
        final secondY = second.evaluate(root);
        if (!_finiteNumber(firstY) || !_finiteNumber(secondY)) continue;
        if ((firstY - secondY).abs() > tolerance) continue;
        final y = (firstY + secondY) / 2;
        if (!_yInViewport(y, viewport)) continue;
        _addMarkerIfUnique(
          markers,
          GraphMarker(
            x: root,
            y: y,
            color: const Color(0xFFFF8A00),
            kind: strings.intersectionKind,
            info: strings.intersectionText(
              first.label,
              second.label,
              root.toStringAsFixed(6),
              y.toStringAsFixed(6),
            ),
          ),
          xTolerance,
          tolerance,
        );
      }
    }
  }
  return markers;
}

List<GraphMarker> buildGraphExtremeMarkers({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
  required GraphStrings strings,
  int samples = 1000,
}) {
  final visible = functions.where((item) => item.visible).toList();
  if (visible.isEmpty || samples < 2 || viewport.spanX <= 0) return const [];
  final markers = <GraphMarker>[];
  final step = viewport.spanX / samples;
  final xTolerance = step * 4;
  final yTolerance = math.max(1e-7, viewport.spanY.abs() * 1e-8);
  // 中文：使用相邻三点判断局部极值，再用二次插值细化点位。
  // English: Detect local extrema with three neighboring samples, then refine the point by quadratic interpolation.
  for (final function in visible) {
    var leftX = viewport.xMin;
    var leftY = function.evaluate(leftX);
    var midX = leftX + step;
    var midY = function.evaluate(midX);
    for (var rightX = midX + step;
        rightX <= viewport.xMax + step * 0.5;
        rightX += step) {
      final clampedRightX = math.min(rightX, viewport.xMax);
      final rightY = function.evaluate(clampedRightX);
      if (_finiteNumber(leftY) &&
          _finiteNumber(midY) &&
          _finiteNumber(rightY)) {
        final isMin = midY < leftY && midY <= rightY;
        final isMax = midY > leftY && midY >= rightY;
        if (isMin || isMax) {
          final refined = _quadraticVertex(
            leftX,
            leftY,
            midX,
            midY,
            clampedRightX,
            rightY,
          );
          final x = refined?.$1 ?? midX;
          final y = refined?.$2 ?? midY;
          if (_finiteNumber(x) &&
              _finiteNumber(y) &&
              x >= viewport.xMin &&
              x <= viewport.xMax &&
              _yInViewport(y, viewport)) {
            _addMarkerIfUnique(
              markers,
              GraphMarker(
                x: x,
                y: y,
                color:
                    isMin ? const Color(0xFF23B45D) : const Color(0xFFFF4D5E),
                kind: isMin ? strings.minimumKind : strings.maximumKind,
                info: strings.extremumText(
                  function.label,
                  isMin ? strings.minimumKind : strings.maximumKind,
                  x.toStringAsFixed(6),
                  y.toStringAsFixed(6),
                ),
              ),
              xTolerance,
              yTolerance,
            );
          }
        }
      }
      if (clampedRightX >= viewport.xMax) break;
      leftX = midX;
      leftY = midY;
      midX = clampedRightX;
      midY = rightY;
    }
  }
  return markers;
}

List<double> _findRootCandidates({
  required double Function(double x) evaluate,
  required double xMin,
  required double xMax,
  required int samples,
  required double tolerance,
}) {
  if (samples <= 0 || xMax <= xMin) return const [];
  final step = (xMax - xMin) / samples;
  final xTolerance = step * 3;
  final xs = List<double>.generate(samples + 1, (index) => xMin + index * step);
  final ys = [for (final x in xs) evaluate(x)];
  final roots = <double>[];

  for (var i = 0; i < ys.length; i++) {
    final y = ys[i];
    if (_finiteNumber(y) && y.abs() <= tolerance) {
      _addRootCandidate(roots, xs[i], xTolerance);
    }
  }

  for (var i = 0; i < samples; i++) {
    final y1 = ys[i];
    final y2 = ys[i + 1];
    if (!_finiteNumber(y1) || !_finiteNumber(y2)) continue;
    if (y1.abs() <= tolerance || y2.abs() <= tolerance) continue;
    if (y1.sign == y2.sign) continue;
    final root = _bisectRoot(
      evaluate: evaluate,
      left: xs[i],
      right: xs[i + 1],
      tolerance: tolerance,
    );
    if (root != null) _addRootCandidate(roots, root, xTolerance);
  }

  for (var i = 1; i < samples; i++) {
    final left = ys[i - 1];
    final middle = ys[i];
    final right = ys[i + 1];
    if (!_finiteNumber(left) ||
        !_finiteNumber(middle) ||
        !_finiteNumber(right)) {
      continue;
    }
    if (middle.abs() > left.abs() || middle.abs() > right.abs()) continue;
    final root = _minimizeAbsoluteRoot(
      evaluate: evaluate,
      left: xs[i - 1],
      right: xs[i + 1],
      tolerance: tolerance,
    );
    if (root != null) _addRootCandidate(roots, root, xTolerance);
  }

  roots.sort();
  return List.unmodifiable(roots);
}

double? _bisectRoot({
  required double Function(double x) evaluate,
  required double left,
  required double right,
  required double tolerance,
}) {
  var a = left;
  var b = right;
  var fa = evaluate(a);
  var fb = evaluate(b);
  if (!_finiteNumber(fa) || !_finiteNumber(fb)) return null;
  if (fa.abs() <= tolerance) return a;
  if (fb.abs() <= tolerance) return b;
  if (fa.sign == fb.sign) return null;
  var bestX = fa.abs() < fb.abs() ? a : b;
  var bestY = fa.abs() < fb.abs() ? fa : fb;
  for (var i = 0; i < 60; i++) {
    final mid = (a + b) / 2;
    final fm = evaluate(mid);
    if (!_finiteNumber(fm)) return null;
    if (fm.abs() < bestY.abs()) {
      bestX = mid;
      bestY = fm;
    }
    if (fm.abs() <= tolerance) return mid;
    if (fa.sign == fm.sign) {
      a = mid;
      fa = fm;
    } else {
      b = mid;
      fb = fm;
    }
  }
  return bestY.abs() <= tolerance ? bestX : null;
}

double? _minimizeAbsoluteRoot({
  required double Function(double x) evaluate,
  required double left,
  required double right,
  required double tolerance,
}) {
  var a = left;
  var b = right;
  for (var i = 0; i < 48; i++) {
    final m1 = a + (b - a) / 3;
    final m2 = b - (b - a) / 3;
    final y1 = evaluate(m1).abs();
    final y2 = evaluate(m2).abs();
    if (!_finiteNumber(y1) || !_finiteNumber(y2)) return null;
    if (y1 < y2) {
      b = m2;
    } else {
      a = m1;
    }
  }
  final candidate = (a + b) / 2;
  final value = evaluate(candidate);
  return _finiteNumber(value) && value.abs() <= tolerance ? candidate : null;
}

bool _mostlyZeroAcrossViewport({
  required double Function(double x) evaluate,
  required GraphViewport viewport,
  required int samples,
  required double tolerance,
}) {
  var finite = 0;
  var nearZero = 0;
  final probeSamples = math.min(samples, 80);
  for (var i = 0; i <= probeSamples; i++) {
    final x = viewport.xMin + i / probeSamples * viewport.spanX;
    final y = evaluate(x);
    if (!_finiteNumber(y)) continue;
    finite++;
    if (y.abs() <= tolerance) nearZero++;
  }
  return finite >= 3 && nearZero / finite >= 0.98;
}

(double, double)? _firstVisiblePoint(
  GraphFunction function,
  GraphViewport viewport,
  int samples,
) {
  final centerY = function.evaluate(viewport.centerX);
  if (_finiteNumber(centerY) && _yInViewport(centerY, viewport)) {
    return (viewport.centerX, centerY);
  }
  for (var i = 0; i <= samples; i++) {
    final x = viewport.xMin + i / samples * viewport.spanX;
    final y = function.evaluate(x);
    if (_finiteNumber(y) && _yInViewport(y, viewport)) return (x, y);
  }
  return null;
}

void _addRootCandidate(List<double> roots, double x, double tolerance) {
  if (!_finiteNumber(x)) return;
  if (roots.any((root) => (root - x).abs() < tolerance)) return;
  roots.add(x);
}

void _addMarkerIfUnique(
  List<GraphMarker> markers,
  GraphMarker marker,
  double xTolerance,
  double yTolerance,
) {
  if (markers.any((item) =>
      (item.x - marker.x).abs() < xTolerance &&
      (item.y - marker.y).abs() < yTolerance)) {
    return;
  }
  markers.add(marker);
}

bool _finiteNumber(double value) => value.isFinite && !value.isNaN;

(double, double)? _quadraticVertex(
  double x1,
  double y1,
  double x2,
  double y2,
  double x3,
  double y3,
) {
  // 中文：用三点拟合局部抛物线，提升极值标记精度但避免引入重型数值库。
  // English: Fit a local parabola from three points for better extrema accuracy without a heavy numeric library.
  final denominator = (x1 - x2) * (x1 - x3) * (x2 - x3);
  if (denominator.abs() < 1e-12) return null;
  final a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / denominator;
  final b = (x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1) + x1 * x1 * (y2 - y3)) /
      denominator;
  if (a.abs() < 1e-12) return null;
  final x = -b / (2 * a);
  if (x < math.min(x1, x3) || x > math.max(x1, x3)) return null;
  final y = a * x * x + b * x + (y2 - a * x2 * x2 - b * x2);
  return (x, y);
}

bool _yInViewport(double y, GraphViewport viewport) {
  return y >= viewport.yMin && y <= viewport.yMax;
}

double _rootResidualTolerance(GraphViewport viewport) {
  return math.max(1e-7, viewport.spanY.abs() * 1e-8);
}
