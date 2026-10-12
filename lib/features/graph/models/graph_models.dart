import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/math/expression_parser.dart';
import '../../../core/utils/expression_display_formatter.dart';
import '../../../core/utils/number_formatter.dart';
import 'graph_strings.dart';

part 'graph_marker_builders.dart';

class GraphFunction {
  const GraphFunction({
    required this.expression,
    required this.label,
    required this.color,
    this.visible = true,
    this.degreeMode = false,
  });

  final String expression;
  final String label;
  final Color color;
  final bool visible;

  /// 中文：求值时的角度单位——`true` 是角度制（DEG），`false` 是弧度制（RAD）。**它是函数自己身上的
  ///       字段**，因为求值发生在三条独立路径上（画曲线、解标记、适配 y 窗口，另有预览那一次探测），
  ///       它们手里都只有一个 [GraphFunction]；把模式放在这里，四条路就都跟着同一个值走。
  ///       调用方是图形页：它从外壳递下来的设置里取当前单位，装进它持有的每一个函数。
  ///       默认 `false` 等于弧度制，也就是本应用 `AppSettings.fallback` 的角度单位。
  /// English: the angle unit used when evaluating — `true` is degrees (DEG), `false` radians (RAD).
  ///          **It is a field on the function itself** because evaluation happens on three separate
  ///          paths (plotting the curve, solving markers, fitting the y window, plus the preview's one
  ///          probe), and each of them holds nothing but a [GraphFunction]; putting the mode here makes
  ///          all four follow the same value. The caller is the graph page, which takes the current
  ///          unit from the settings handed down by the shell and puts it on every function it holds.
  ///          The `false` default is radians — the app's angle unit in `AppSettings.fallback`.
  final bool degreeMode;

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

  GraphFunction copyWith({bool? visible, bool? degreeMode}) {
    return GraphFunction(
        expression: expression,
        label: label,
        color: color,
        visible: visible ?? this.visible,
        degreeMode: degreeMode ?? this.degreeMode);
  }

  double evaluate(double x) {
    try {
      // 中文：图形页复用核心表达式解析器，并把**当前角度单位**一起递给它（[degreeMode]），
      //       于是计算器和图形函数语义一致：`sin(90)` 在角度制下两边都是 `1`。
      // English: the graph page reuses the core expression parser and hands it **the current angle
      //          unit** ([degreeMode]), so graph functions match calculator semantics: `sin(90)` is
      //          `1` on both sides under degree mode.
      final parsed = _normalizeForParser(expression, x);
      return ExpressionParser(parsed, degreeMode: degreeMode).parse();
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
    required this.strings,
    this.errorMessage,
  });

  factory GraphFunctionInputPreview.empty(GraphStrings strings) {
    return GraphFunctionInputPreview(
      rawInput: '',
      normalizedExpression: '',
      label: 'y =',
      validSampleCount: 0,
      strings: strings,
      errorMessage: strings.enterExpression,
    );
  }

  final String rawInput;
  final String normalizedExpression;
  final String label;
  final int validSampleCount;

  /// 中文：这一条预览该用哪种语言说话。**它是字段而不是查出来的**——预览在模型层构造，
  ///       没有 `BuildContext`；语言由调用方（表现层从 `context` 取表）在构造时定下。
  /// English: Which language this preview speaks. **It is a field rather than something looked up** —
  ///          previews are built in the models layer with no `BuildContext`; the language is fixed at
  ///          construction by the caller (presentation, which reads the table off `context`).
  final GraphStrings strings;

  final String? errorMessage;

  bool get isValid => errorMessage == null;

  /// 中文：屏幕上那一句。两个分支都过 [strings]，所以英文界面拿到的是英文。
  /// English: the sentence shown on screen. Both branches go through [strings], so the English
  ///          interface gets English.
  String get message {
    if (errorMessage != null) return errorMessage!;
    return strings.willPlot(label, validSampleCount);
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

/// 中文：**表是必填参数。** 理由写在 `graph_strings.dart` 的文件头（模型层没有 `BuildContext`，
///       语言由调用方在构造时定下；漏传是编译错误而不是静默回落）。
/// English: **The table is a required parameter.** The reasoning is on `graph_strings.dart`'s file
///          head (the models layer has no `BuildContext`, so the language is fixed by the caller at
///          construction; omitting it is a compile error rather than a silent fallback).
GraphWorkspace? decodeGraphWorkspace(String? raw,
    {required GraphStrings strings, bool degreeMode = false}) {
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
        strings: strings,
        degreeMode: degreeMode,
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
  required GraphStrings strings,
  required bool degreeMode,
}) {
  if (raw is! Map) return null;
  final rawExpression = raw['expression'];
  if (rawExpression is! String) return null;
  final color = _colorFromJson(raw['color']) ?? fallbackColor;
  final preview = previewGraphFunctionInput(rawExpression,
      color: color, strings: strings, degreeMode: degreeMode);
  if (!preview.isValid) return null;
  final visible = raw['visible'] is bool ? raw['visible'] as bool : true;
  return GraphFunction(
    expression: preview.normalizedExpression,
    label: preview.label,
    color: color,
    visible: visible,
    degreeMode: degreeMode,
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

/// 中文：**表是必填参数**，理由同 `decodeGraphWorkspace`。[degreeMode] 是这次探测求值用的角度
///       单位（也是产出的函数的），理由写在 [GraphFunction.degreeMode] 上。
/// English: **The table is a required parameter**, for the same reason as `decodeGraphWorkspace`.
///          [degreeMode] is the angle unit this probe evaluates under (and the one the resulting
///          function carries); the reasoning is on [GraphFunction.degreeMode].
GraphFunctionInputPreview previewGraphFunctionInput(
  String raw, {
  required Color color,
  required GraphStrings strings,
  bool degreeMode = false,
}) {
  final normalized = GraphFunction.normalizeExpression(raw);
  if (normalized.isEmpty) {
    return GraphFunctionInputPreview(
      rawInput: raw,
      normalizedExpression: normalized,
      label: 'y =',
      validSampleCount: 0,
      strings: strings,
      errorMessage: strings.enterExpression,
    );
  }

  final probe = GraphFunction(
    expression: normalized,
    label: GraphFunction.labelFor(normalized),
    color: color,
    degreeMode: degreeMode,
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
      strings: strings,
      errorMessage: strings.cannotCompute,
    );
  }

  return GraphFunctionInputPreview(
    rawInput: raw,
    normalizedExpression: normalized,
    label: probe.label,
    validSampleCount: validSamples,
    strings: strings,
  );
}

/// 中文：**表是必填参数。** 小节名（`图形数据` / `函数` / `视窗` / `标记` / `当前标记`）是**线格式**——
///       写出去、粘贴解析器又读回来；解析器两种语言都收，所以英文界面复制出去的数据在英文界面里
///       能自己粘回来。理由详见 `graph_strings.dart` 的文件头。
/// English: **The table is a required parameter.** The section names (`图形数据` / `函数` / `视窗` /
///          `标记` / `当前标记`) are the **wire format** — written out and read back by the paste
///          parser; the parser accepts both languages, so data copied out of the English interface
///          pastes back into it. The reasoning is on `graph_strings.dart`'s file head.
String buildGraphCopyText({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
  required Iterable<GraphMarker> markers,
  required GraphStrings strings,
  int? selectedMarker,
}) {
  final functionList = functions.toList(growable: false);
  final markerList = markers.toList(growable: false);
  final lines = <String>[
    strings.graphDataTitle,
    '',
    strings.functionsSection,
    if (functionList.isEmpty)
      strings.none
    else
      for (var i = 0; i < functionList.length; i++) ...[
        '${i + 1}. ${functionList[i].label} '
            '(${functionList[i].visible ? strings.show : strings.hide})',
        strings.expressionLine(functionList[i].expression),
      ],
    '',
    strings.viewportSection,
    'x: ${formatGraphNumber(viewport.xMin)} ~ ${formatGraphNumber(viewport.xMax)}',
    'y: ${formatGraphNumber(viewport.yMin)} ~ ${formatGraphNumber(viewport.yMax)}',
  ];

  if (selectedMarker != null &&
      selectedMarker >= 0 &&
      selectedMarker < markerList.length) {
    final marker = markerList[selectedMarker];
    lines.addAll([
      '',
      strings.currentMarkerSection,
      markerCopyLine(marker),
      marker.info,
    ]);
  }

  lines.addAll([
    '',
    strings.markersSection,
    if (markerList.isEmpty)
      strings.none
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
