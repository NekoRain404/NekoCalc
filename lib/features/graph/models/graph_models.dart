import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/math/expression_parser.dart';
import '../../../core/utils/expression_display_formatter.dart';
import '../../../core/utils/number_formatter.dart';

class GraphFunction {
  const GraphFunction({
    required this.expression,
    required this.label,
    required this.color,
    this.visible = true,
  });

  final String expression;
  final String label;
  final Color color;
  final bool visible;

  static String labelFor(String expression) {
    return 'y = ${formatExpressionForDisplay(
      normalizeExpression(expression),
      mathSymbols: true,
    )}';
  }

  static String normalizeExpression(String raw) {
    var expression = raw
        .trim()
        .replaceAll('−', '-')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('，', ',')
        .replaceAll('：', ':')
        .replaceAll('＝', '=');
    expression = _stripGraphAssignmentPrefix(expression).trim();
    expression = _stripGraphDomainSuffix(expression).trim();
    return ExpressionParser.normalizeExpressionInput(expression);
  }

  static String _stripGraphAssignmentPrefix(String expression) {
    final prefixed = RegExp(
      r'^(?:y(?:\s*\(\s*x\s*\))?|[a-z]\s*\(\s*x\s*\))\s*(?::=|=>|->|=|:|→|⇒)\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(expression);
    if (prefixed != null) return prefixed.group(1)!;

    final equation = _equationParts(expression);
    if (equation != null) {
      return '((${equation.left})-(${equation.right}))';
    }
    return expression;
  }

  static ({String left, String right})? _equationParts(String expression) {
    final match =
        RegExp(r'^(.*?)\s*(?:=>|⇒|=|＝)\s*(.*?)$').firstMatch(expression);
    if (match == null) return null;
    final left = match.group(1)?.trim() ?? '';
    final right = match.group(2)?.trim() ?? '';
    if (left.isEmpty || right.isEmpty) return null;
    return (left: left, right: right);
  }

  static String _stripGraphDomainSuffix(String expression) {
    final separated = RegExp(
      r'^(.*?)(?:[,;，；]\s*(?:(?:定义域|domain\b)|x\s*(?:∈|in\b|属于|范围)|for\s+x\b).*)$',
      caseSensitive: false,
    ).firstMatch(expression);
    final forX = RegExp(
      r'^(.*?)\s+for\s+x\b.*$',
      caseSensitive: false,
    ).firstMatch(expression);
    final value = separated?.group(1)?.trim() ?? forX?.group(1)?.trim();
    if (value == null || value.isEmpty) return expression;
    return value;
  }

  GraphFunction copyWith({bool? visible}) {
    return GraphFunction(
        expression: expression,
        label: label,
        color: color,
        visible: visible ?? this.visible);
  }

  double evaluate(double x) {
    try {
      // 中文：图形页复用核心表达式解析器，保证计算器和图形函数语义一致。
      // English: The graph page reuses the core expression parser so graph functions match calculator semantics.
      final parsed = _normalizeForParser(expression, x);
      return ExpressionParser(parsed, degreeMode: false).parse();
    } catch (_) {
      return double.nan;
    }
  }

  String _normalizeForParser(String raw, double x) {
    // 中文：图形页只替换变量 x，其余符号归一化和隐式乘法交给核心解析器统一处理。
    // English: Graphing only substitutes x; core parser handles symbol normalization and implicit multiplication.
    return _replaceGraphVariable(normalizeExpression(raw).toLowerCase(), x);
  }

  String _numberLiteral(double value) {
    if (value.abs() < 1e-12) return '0';
    return value
        .toStringAsFixed(12)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _replaceGraphVariable(String expression, double x) {
    final literal = '(${_numberLiteral(x)})';
    final buffer = StringBuffer();
    var index = 0;
    while (index < expression.length) {
      final radixEnd = _radixLiteralEnd(expression, index);
      if (radixEnd != null) {
        buffer.write(expression.substring(index, radixEnd));
        index = radixEnd;
        continue;
      }
      final char = expression[index];
      if (char == 'x' && _isGraphVariableAt(expression, index)) {
        buffer.write(literal);
      } else {
        buffer.write(char);
      }
      index++;
    }
    return buffer.toString();
  }

  int? _radixLiteralEnd(String expression, int index) {
    if (index + 1 >= expression.length || expression[index] != '0') {
      return null;
    }
    if (index > 0 && _isIdentifierOrDigit(expression[index - 1])) {
      return null;
    }
    final prefix = expression[index + 1];
    final radix = switch (prefix) {
      'x' => 16,
      'b' => 2,
      'o' => 8,
      _ => null,
    };
    if (radix == null) return null;

    var cursor = index + 2;
    while (cursor < expression.length) {
      final char = expression[cursor];
      if (char == '_') {
        cursor++;
        continue;
      }
      final digit = _radixDigitValue(char);
      if (digit == null || digit >= radix) break;
      cursor++;
    }
    return cursor;
  }

  int? _radixDigitValue(String char) {
    final code = char.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) return code - 0x30;
    if (code >= 0x61 && code <= 0x66) return code - 0x61 + 10;
    return null;
  }

  bool _isGraphVariableAt(String expression, int index) {
    final before = index == 0 ? null : expression[index - 1];
    final after = index + 1 >= expression.length ? null : expression[index + 1];
    return !_isAsciiLetter(before) && !_isAsciiLetter(after);
  }

  bool _isIdentifierOrDigit(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5a) ||
        (code >= 0x61 && code <= 0x7a) ||
        char == '_';
  }

  bool _isAsciiLetter(String? char) {
    if (char == null) return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a);
  }
}


class GraphMarker {
  const GraphMarker({
    required this.x,
    required this.y,
    required this.color,
    required this.kind,
    required this.info,
  });

  final double x;
  final double y;
  final Color color;
  final String kind;
  final String info;
}


class GraphFunctionInputPreview {
  const GraphFunctionInputPreview({
    required this.rawInput,
    required this.normalizedExpression,
    required this.label,
    required this.validSampleCount,
    this.errorMessage,
  });

  factory GraphFunctionInputPreview.empty() {
    return const GraphFunctionInputPreview(
      rawInput: '',
      normalizedExpression: '',
      label: 'y =',
      validSampleCount: 0,
      errorMessage: '请输入函数表达式',
    );
  }

  final String rawInput;
  final String normalizedExpression;
  final String label;
  final int validSampleCount;
  final String? errorMessage;

  bool get isValid => errorMessage == null;

  String get message {
    if (errorMessage != null) return errorMessage!;
    return '将绘制 $label，有效采样 $validSampleCount/5';
  }
}


const String graphWorkspaceSettingKey = 'graph_workspace';
const int _graphWorkspaceVersion = 1;
const GraphViewport defaultGraphViewport =
    GraphViewport(centerX: 0, centerY: 0, spanX: 12, spanY: 12);

List<GraphFunction> defaultGraphFunctions() {
  return [
    const GraphFunction(
      expression: 'sin(x)',
      label: 'y = sin(x)',
      color: Color(0xFF1677FF),
    ),
    const GraphFunction(
      expression: 'x^2 - 3*x + 2',
      label: 'y = x² - 3x + 2',
      color: Color(0xFF7C3AED),
    ),
  ];
}

class GraphWorkspace {
  const GraphWorkspace({
    required this.functions,
    required this.viewport,
  });

  final List<GraphFunction> functions;
  final GraphViewport viewport;
}


String encodeGraphWorkspace({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
}) {
  final functionList = functions
      .where((function) => function.expression.trim().isNotEmpty)
      .toList(growable: false);
  final effectiveFunctions =
      functionList.isEmpty ? defaultGraphFunctions() : functionList;
  return jsonEncode({
    'version': _graphWorkspaceVersion,
    'viewport': viewport.toJson(),
    'functions': [
      for (final function in effectiveFunctions)
        {
          'expression': function.expression,
          'visible': function.visible,
          'color': function.color.toARGB32(),
        },
    ],
  });
}

GraphWorkspace? decodeGraphWorkspace(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final viewport =
        GraphViewport.fromJson(decoded['viewport']) ?? defaultGraphViewport;
    final rawFunctions = decoded['functions'];
    if (rawFunctions is! List) return null;
    final functions = <GraphFunction>[];
    for (var i = 0; i < rawFunctions.length; i++) {
      final function = _graphFunctionFromJson(
        rawFunctions[i],
        fallbackColor: graphPalette[i % graphPalette.length],
      );
      if (function != null) functions.add(function);
    }
    if (functions.isEmpty) return null;
    return GraphWorkspace(
      functions: List.unmodifiable(functions),
      viewport: viewport,
    );
  } catch (_) {
    return null;
  }
}


GraphFunction? _graphFunctionFromJson(
  Object? raw, {
  required Color fallbackColor,
}) {
  if (raw is! Map) return null;
  final rawExpression = raw['expression'];
  if (rawExpression is! String) return null;
  final color = _colorFromJson(raw['color']) ?? fallbackColor;
  final preview = previewGraphFunctionInput(rawExpression, color: color);
  if (!preview.isValid) return null;
  final visible = raw['visible'] is bool ? raw['visible'] as bool : true;
  return GraphFunction(
    expression: preview.normalizedExpression,
    label: preview.label,
    color: color,
    visible: visible,
  );
}

Color? _colorFromJson(Object? raw) {
  final value = switch (raw) {
    int value => value,
    num value => value.toInt(),
    String value => _parseColorString(value),
    _ => null,
  };
  if (value == null || value < 0 || value > 0xFFFFFFFF) return null;
  return Color(value);
}

int? _parseColorString(String raw) {
  var text = raw.trim();
  if (text.startsWith('#')) text = text.substring(1);
  if (text.startsWith('0x') || text.startsWith('0X')) text = text.substring(2);
  if (text.length == 6) text = 'FF$text';
  if (text.length != 8) return null;
  return int.tryParse(text, radix: 16);
}


GraphFunctionInputPreview previewGraphFunctionInput(
  String raw, {
  required Color color,
}) {
  final normalized = GraphFunction.normalizeExpression(raw);
  if (normalized.isEmpty) {
    return GraphFunctionInputPreview(
      rawInput: raw,
      normalizedExpression: normalized,
      label: 'y =',
      validSampleCount: 0,
      errorMessage: '请输入函数表达式',
    );
  }

  final probe = GraphFunction(
    expression: normalized,
    label: GraphFunction.labelFor(normalized),
    color: color,
  );
  final validSamples = [-2.0, -1.0, 0.0, 1.0, 2.0]
      .map(probe.evaluate)
      .where((value) => value.isFinite)
      .length;
  if (validSamples == 0) {
    return GraphFunctionInputPreview(
      rawInput: raw,
      normalizedExpression: normalized,
      label: probe.label,
      validSampleCount: validSamples,
      errorMessage: '表达式无法计算，请检查函数名、括号或变量 x',
    );
  }

  return GraphFunctionInputPreview(
    rawInput: raw,
    normalizedExpression: normalized,
    label: probe.label,
    validSampleCount: validSamples,
  );
}

String buildGraphCopyText({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
  required Iterable<GraphMarker> markers,
  int? selectedMarker,
}) {
  final functionList = functions.toList(growable: false);
  final markerList = markers.toList(growable: false);
  final lines = <String>[
    '图形数据',
    '',
    '函数',
    if (functionList.isEmpty)
      '无'
    else
      for (var i = 0; i < functionList.length; i++) ...[
        '${i + 1}. ${functionList[i].label} (${functionList[i].visible ? '显示' : '隐藏'})',
        '   表达式: ${functionList[i].expression}',
      ],
    '',
    '视窗',
    'x: ${formatGraphNumber(viewport.xMin)} ~ ${formatGraphNumber(viewport.xMax)}',
    'y: ${formatGraphNumber(viewport.yMin)} ~ ${formatGraphNumber(viewport.yMax)}',
  ];

  if (selectedMarker != null &&
      selectedMarker >= 0 &&
      selectedMarker < markerList.length) {
    final marker = markerList[selectedMarker];
    lines.addAll([
      '',
      '当前标记',
      markerCopyLine(marker),
      marker.info,
    ]);
  }

  lines.addAll([
    '',
    '标记',
    if (markerList.isEmpty)
      '无'
    else
      for (var i = 0; i < markerList.length; i++)
        '${i + 1}. ${markerCopyLine(markerList[i])}',
  ]);

  return lines.join('\n');
}

String markerCopyLine(GraphMarker marker) {
  return '${marker.kind}: x = ${formatGraphNumber(marker.x)}, y = ${formatGraphNumber(marker.y)}';
}

String buildMarkerCopyText(GraphMarker marker) {
  return [
    markerCopyLine(marker),
    marker.info,
  ].join('\n');
}

String formatGraphNumber(double value) {
  return formatNumber(value, precision: 8);
}

List<GraphMarker> buildSampleMarkers({
  required Iterable<GraphFunction> functions,
  required double x,
  required double yMin,
  required double yMax,
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
        kind: '取样',
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
          kind: '零点',
          info: '${function.label} 与 x 轴重合\n当前视图内所有 x 都是零点',
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
          kind: '零点',
          info: '${function.label} 零点\nx = ${root.toStringAsFixed(6)}\ny = 0',
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
              kind: '重合',
              info: '${first.label}\n${second.label}\n两条曲线在当前视图内重合',
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
            kind: '交点',
            info:
                '${first.label}\n${second.label}\n交点 x = ${root.toStringAsFixed(6)}, y = ${y.toStringAsFixed(6)}',
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
                kind: isMin ? '极小值' : '极大值',
                info:
                    '${function.label} ${isMin ? '极小值' : '极大值'}\nx = ${x.toStringAsFixed(6)}\ny = ${y.toStringAsFixed(6)}',
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


List<List<Offset>> buildGraphPlotSegments({
  required GraphFunction function,
  required GraphViewport viewport,
  required double width,
  required double height,
}) {
  if (width <= 0 || height <= 0) return const [];
  final segments = <List<Offset>>[];
  var current = <Offset>[];
  Offset? previous;
  final maxJump = height * 0.75;
  for (var i = 0; i <= width.round(); i++) {
    // 中文：按屏幕像素采样，缩放后曲线密度自然跟随可见宽度。
    // English: Sample per screen pixel so curve density follows the visible width after zooming.
    final screenX = i.toDouble();
    final x = viewport.xMin + screenX / width * viewport.spanX;
    final y = function.evaluate(x);
    final inBand = y.isFinite &&
        !y.isNaN &&
        y >= viewport.yMin - viewport.spanY &&
        y <= viewport.yMax + viewport.spanY;
    if (!inBand) {
      _finishGraphSegment(segments, current);
      current = <Offset>[];
      previous = null;
      continue;
    }
    final point = Offset(screenX, viewport.toScreenY(y, Size(width, height)));
    if (previous != null && (point.dy - previous.dy).abs() > maxJump) {
      // 中文：大跳变时断开路径，避免渐近线被错误连成竖线。
      // English: Break the path on large jumps to avoid drawing false vertical lines at asymptotes.
      _finishGraphSegment(segments, current);
      current = <Offset>[];
    }
    current.add(point);
    previous = point;
  }
  _finishGraphSegment(segments, current);
  return segments;
}

void _finishGraphSegment(List<List<Offset>> segments, List<Offset> current) {
  if (current.length >= 2) {
    segments.add(List.unmodifiable(current));
  }
}


const List<Color> graphPalette = [
  Color(0xFF1677FF),
  Color(0xFF7C3AED),
  Color(0xFFFF8A00),
  Color(0xFF23B45D),
  Color(0xFFFF4D5E),
];


class GraphViewport {
  const GraphViewport({
    required this.centerX,
    required this.centerY,
    required this.spanX,
    required this.spanY,
  });

  final double centerX;
  final double centerY;
  final double spanX;
  final double spanY;

  Map<String, double> toJson() {
    return {
      'centerX': centerX,
      'centerY': centerY,
      'spanX': spanX,
      'spanY': spanY,
    };
  }

  static GraphViewport? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final centerX = _jsonDouble(raw['centerX']);
    final centerY = _jsonDouble(raw['centerY']);
    final spanX = _jsonDouble(raw['spanX']);
    final spanY = _jsonDouble(raw['spanY']);
    if (centerX == null || centerY == null || spanX == null || spanY == null) {
      return null;
    }
    if (spanX <= 0 || spanY <= 0) return null;
    return GraphViewport(
      centerX: centerX,
      centerY: centerY,
      spanX: spanX.clamp(0.5, 200).toDouble(),
      spanY: spanY.clamp(0.5, 200).toDouble(),
    );
  }

  double get xMin => centerX - spanX / 2;
  double get xMax => centerX + spanX / 2;
  double get yMin => centerY - spanY / 2;
  double get yMax => centerY + spanY / 2;

  GraphViewport zoom(double factor) {
    return zoomAt(factor, null, null);
  }

  GraphViewport zoomAt(double factor, Offset? focalPoint, Size? size) {
    final safe = factor.clamp(0.2, 5.0);
    final nextSpanX = (spanX * safe).clamp(0.5, 200).toDouble();
    final nextSpanY = (spanY * safe).clamp(0.5, 200).toDouble();
    if (focalPoint == null ||
        size == null ||
        size.width <= 0 ||
        size.height <= 0) {
      return GraphViewport(
          centerX: centerX,
          centerY: centerY,
          spanX: nextSpanX,
          spanY: nextSpanY);
    }

    final focalX = toGraphX(focalPoint.dx, size);
    final focalY = toGraphY(focalPoint.dy, size);
    final ratioX = (focalPoint.dx / size.width).clamp(0.0, 1.0);
    final ratioY = (focalPoint.dy / size.height).clamp(0.0, 1.0);
    final nextXMin = focalX - ratioX * nextSpanX;
    final nextYMax = focalY + ratioY * nextSpanY;
    return GraphViewport(
      centerX: nextXMin + nextSpanX / 2,
      centerY: nextYMax - nextSpanY / 2,
      spanX: nextSpanX,
      spanY: nextSpanY,
    );
  }

  GraphViewport pan(Offset delta, Size size) {
    if (size.width <= 0 || size.height <= 0) return this;
    return GraphViewport(
      centerX: centerX - delta.dx / size.width * spanX,
      centerY: centerY + delta.dy / size.height * spanY,
      spanX: spanX,
      spanY: spanY,
    );
  }

  GraphViewport centerOn(double x, double y) {
    if (!x.isFinite || !y.isFinite) return this;
    return GraphViewport(
      centerX: x,
      centerY: y,
      spanX: spanX,
      spanY: spanY,
    );
  }

  double toScreenX(double x, Size size) => (x - xMin) / spanX * size.width;

  double toScreenY(double y, Size size) => (yMax - y) / spanY * size.height;

  double toGraphX(double screenX, Size size) {
    if (size.width <= 0) return centerX;
    return xMin + screenX / size.width * spanX;
  }

  double toGraphY(double screenY, Size size) {
    if (size.height <= 0) return centerY;
    return yMax - screenY / size.height * spanY;
  }
}


double? _jsonDouble(Object? value) {
  final parsed = switch (value) {
    num value => value.toDouble(),
    String value => double.tryParse(value),
    _ => null,
  };
  return parsed == null || !parsed.isFinite ? null : parsed;
}
