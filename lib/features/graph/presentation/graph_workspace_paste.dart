part of 'graph_page.dart';

class GraphWorkspacePasteResult {
  const GraphWorkspacePasteResult({
    required this.workspace,
    required this.fromCopyText,
    this.fromFunctionText = false,
  });

  factory GraphWorkspacePasteResult.empty() =>
      const GraphWorkspacePasteResult(workspace: null, fromCopyText: false);

  final GraphWorkspace? workspace;
  final bool fromCopyText;
  final bool fromFunctionText;

  bool get hasWorkspace => workspace != null;

  String get summary {
    final value = workspace;
    if (value == null) return '剪贴板里没有识别到图形工作区';
    final visibleCount = value.functions.where((item) => item.visible).length;
    return [
      if (fromFunctionText)
        '已从函数文本创建工作区'
      else if (fromCopyText)
        '已从图形数据恢复工作区'
      else
        '已恢复图形工作区',
      '${value.functions.length} 个函数',
      '$visibleCount 个可见',
      'x ${_formatGraphNumber(value.viewport.xMin)} ~ ${_formatGraphNumber(value.viewport.xMax)}',
    ].join(' · ');
  }
}

GraphWorkspacePasteResult parseGraphWorkspacePasteText(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return GraphWorkspacePasteResult.empty();

  final jsonWorkspace = decodeGraphWorkspace(trimmed);
  if (jsonWorkspace != null) {
    return GraphWorkspacePasteResult(
      workspace: jsonWorkspace,
      fromCopyText: false,
    );
  }

  final copyWorkspace = _parseGraphCopyTextWorkspace(trimmed);
  if (copyWorkspace != null) {
    return GraphWorkspacePasteResult(
      workspace: copyWorkspace,
      fromCopyText: true,
    );
  }

  final functionTextWorkspace = _parseGraphFunctionTextWorkspace(trimmed);
  if (functionTextWorkspace == null) return GraphWorkspacePasteResult.empty();
  return GraphWorkspacePasteResult(
    workspace: functionTextWorkspace,
    fromCopyText: false,
    fromFunctionText: true,
  );
}

GraphWorkspace? _parseGraphCopyTextWorkspace(String input) {
  final lines = const LineSplitter().convert(input);
  if (!_looksLikeGraphCopyText(lines)) return null;
  final functions = <GraphFunction>[];
  GraphViewport? viewport;
  var inViewport = false;

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trim();
    final normalized = line.toLowerCase();
    if (line == '视窗' || normalized == 'viewport') {
      inViewport = true;
      continue;
    }
    if (line == '标记' ||
        line == '当前标记' ||
        line == '函数' ||
        normalized == 'markers' ||
        normalized == 'functions') {
      inViewport = false;
      continue;
    }

    final expression = _graphExpressionFromCopyLine(line);
    if (expression != null) {
      final visible = _graphCopyLineVisible(lines, index);
      final preview = previewGraphFunctionInput(
        expression,
        color: _palette[functions.length % _palette.length],
      );
      if (preview.isValid) {
        functions.add(GraphFunction(
          expression: preview.normalizedExpression,
          label: preview.label,
          color: _palette[functions.length % _palette.length],
          visible: visible,
        ));
      }
      continue;
    }

    if (inViewport) {
      viewport = _viewportFromCopyLine(viewport, line);
    }
  }

  if (functions.isEmpty) return null;
  return GraphWorkspace(
    functions: List.unmodifiable(functions),
    viewport: viewport ?? defaultGraphViewport,
  );
}

bool _looksLikeGraphCopyText(List<String> lines) {
  var hasGraphTitle = false;
  var hasFunctionsSection = false;
  var hasViewportSection = false;
  for (final rawLine in lines) {
    final line = rawLine.trim();
    final normalized = line.toLowerCase();
    if (line == '图形数据' || normalized == 'graph data') {
      hasGraphTitle = true;
    }
    if (line == '函数' || normalized == 'functions') {
      hasFunctionsSection = true;
    }
    if (line == '视窗' || normalized == 'viewport') {
      hasViewportSection = true;
    }
  }
  return hasGraphTitle || (hasFunctionsSection && hasViewportSection);
}

GraphWorkspace? _parseGraphFunctionTextWorkspace(String input) {
  final functions = <GraphFunction>[];
  final seen = <String>{};
  final lines = const LineSplitter()
      .convert(input)
      .expand(_splitGraphFunctionPasteLine)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);

  for (final line in lines) {
    final candidate = _graphFunctionExpressionFromFreeText(line);
    if (candidate == null) continue;
    final color = _palette[functions.length % _palette.length];
    final preview = previewGraphFunctionInput(candidate, color: color);
    if (!preview.isValid) continue;
    if (!seen.add(preview.normalizedExpression)) continue;
    functions.add(GraphFunction(
      expression: preview.normalizedExpression,
      label: preview.label,
      color: color,
    ));
    if (functions.length == _maxPastedFunctionTextCount) break;
  }

  if (functions.isEmpty) return null;
  return GraphWorkspace(
    functions: List.unmodifiable(functions),
    viewport: defaultGraphViewport,
  );
}

Iterable<String> _splitGraphFunctionPasteLine(String line) {
  if (line.contains('\t')) return line.split('\t');
  return [line];
}

String? _graphFunctionExpressionFromFreeText(String line) {
  final bulletStripped =
      line.replaceFirst(RegExp(r'^\s*(?:[-*•]|\d+[.)、])\s*'), '').trim();
  if (bulletStripped.isEmpty) return null;

  final labeled = RegExp(
    r'^(?:表达式|函数|function|expr|expression)\s*[:：]\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(bulletStripped);
  if (labeled != null) return labeled.group(1)?.trim();
  final candidate = bulletStripped.trim();
  if (!_looksLikeGraphFunctionExpression(candidate)) return null;
  return candidate;
}

bool _looksLikeGraphFunctionExpression(String value) {
  final text = value.trim();
  if (text.isEmpty) return false;
  if (RegExp(
    r'^(?:y(?:\s*\(\s*x\s*\))?|[a-z]\s*\(\s*x\s*\))\s*(?::=|=>|->|=|:|→|⇒)\s*.+$',
    caseSensitive: false,
  ).hasMatch(text)) {
    return true;
  }
  if (RegExp(r'\bx\b', caseSensitive: false).hasMatch(text)) return true;
  if (RegExp(
    r'\b(?:sin|cos|tan|sqrt|ln|log|exp|abs|floor|ceil|round)\s*\(',
    caseSensitive: false,
  ).hasMatch(text)) {
    return true;
  }
  if (!RegExp(r'[+\-*/^×÷=]').hasMatch(text) ||
      !RegExp(r'[0-9)]').hasMatch(text)) {
    return false;
  }
  return RegExp(r'\d\s*[+\-*/^×÷=]\s*\d').hasMatch(text) ||
      RegExp(r'\)\s*[+\-*/^×÷=]\s*(?:\d|\()').hasMatch(text) ||
      RegExp(r'\d\s*[+\-*/^×÷=]\s*\(').hasMatch(text);
}

String? _graphExpressionFromCopyLine(String line) {
  final match =
      RegExp(r'^(?:表达式|expression)\s*[:：]\s*(.+)$', caseSensitive: false)
          .firstMatch(line);
  return match?.group(1)?.trim();
}

bool _graphCopyLineVisible(List<String> lines, int expressionLineIndex) {
  for (var index = expressionLineIndex - 1; index >= 0; index--) {
    final line = lines[index].trim();
    if (line.isEmpty) continue;
    if (RegExp(r'^\d+[.)、]').hasMatch(line)) {
      if (line.contains('隐藏') || line.toLowerCase().contains('hidden')) {
        return false;
      }
      return true;
    }
    if (_graphExpressionFromCopyLine(line) != null) break;
  }
  return true;
}

GraphViewport? _viewportFromCopyLine(GraphViewport? current, String line) {
  final match = RegExp(
    r'^([xy])\s*[:：]\s*([+\-]?(?:\d+(?:\.\d+)?|\.\d+))\s*(?:~|至|到|-)\s*([+\-]?(?:\d+(?:\.\d+)?|\.\d+))$',
    caseSensitive: false,
  ).firstMatch(line.replaceAll(',', ''));
  if (match == null) return current;
  final axis = match.group(1)!.toLowerCase();
  final start = double.tryParse(match.group(2)!);
  final end = double.tryParse(match.group(3)!);
  if (start == null || end == null || start == end) return current;
  final center = (start + end) / 2;
  final span = (end - start).abs();
  final base = current ?? defaultGraphViewport;
  if (axis == 'x') {
    return GraphViewport(
      centerX: center,
      centerY: base.centerY,
      spanX: span,
      spanY: base.spanY,
    );
  }
  return GraphViewport(
    centerX: base.centerX,
    centerY: center,
    spanX: base.spanX,
    spanY: span,
  );
}

const int _maxPastedFunctionTextCount = 12;
