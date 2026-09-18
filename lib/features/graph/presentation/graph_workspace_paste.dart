import 'dart:convert';

import '../models/graph_models.dart';
import 'graph_workspace_strings.dart';

class GraphWorkspacePasteResult {
  /// 中文：**不再是 `const`。** 文案表是 `static final`（带闭包，不是常量表达式），所以"没有传
  ///       就用中文那一份"这件事只能在构造体里做，`const` 构造放不下。这个类只在本文件与测试里
  ///       构造（`graph_page.dart` 只用 `parseGraphWorkspacePasteText` 与 `summary`），
  ///       所以丢掉 `const` 不会波及调用方。
  /// English: **No longer `const`.** The copy tables are `static final` (they hold closures, not
  ///          constant expressions), so "use the Chinese one when none was given" can only happen in
  ///          the constructor body, which a `const` constructor cannot have. The class is only
  ///          constructed in this file and in tests (`graph_page.dart` uses only
  ///          `parseGraphWorkspacePasteText` and `summary`), so dropping `const` reaches no caller.
  GraphWorkspacePasteResult({
    required this.workspace,
    required this.fromCopyText,
    this.fromFunctionText = false,
    GraphWorkspaceStrings? strings,
  }) : strings = strings ?? GraphWorkspaceStrings.graphWorkspaceZh;

  factory GraphWorkspacePasteResult.empty({GraphWorkspaceStrings? strings}) =>
      GraphWorkspacePasteResult(
        workspace: null,
        fromCopyText: false,
        strings: strings,
      );

  final GraphWorkspace? workspace;
  final bool fromCopyText;
  final bool fromFunctionText;

  /// 中文：这一份结果该用哪种语言说话。**它是字段而不是查出来的**——`summary` 是个 getter，
  ///       没有 `BuildContext` 可查（理由见 `graph_workspace_strings.dart` 的文件头）。
  ///       默认值是中文那一份，所以 `graph_page.dart` 不改也能编译、也仍然逐字节渲染今天这些字。
  /// English: Which language this result speaks. **It is a field rather than something looked up** —
  ///          `summary` is a getter with no `BuildContext` to look anything up from (see
  ///          `graph_workspace_strings.dart`'s file head). The default is the Chinese one, so
  ///          `graph_page.dart` compiles unchanged and still renders exactly today's characters.
  final GraphWorkspaceStrings strings;

  bool get hasWorkspace => workspace != null;

  /// 中文：`graph_page.dart` 今天用的那一条。语言取自构造时定下的 [strings]。
  /// English: The entry point `graph_page.dart` uses today. The language comes from the [strings]
  ///          fixed at construction.
  String get summary => summaryIn(strings);

  /// 中文：**给下一轮留的接线口。** 图形页整页还在中文里，等它开始接表时，把
  ///       `GraphWorkspaceStrings.of(context)` 从 `graph_page.dart` 传进
  ///       `parseGraphWorkspacePasteText`，这条路径自然就通了。
  /// English: **The wiring point left for the next round.** The graph page is still Chinese end to
  ///          end; when it starts taking tables, pass `GraphWorkspaceStrings.of(context)` from
  ///          `graph_page.dart` into `parseGraphWorkspacePasteText` and this path lights up on its
  ///          own.
  String summaryIn(GraphWorkspaceStrings strings) {
    final value = workspace;
    if (value == null) return strings.noWorkspace;
    final visibleCount = value.functions.where((item) => item.visible).length;
    return [
      if (fromFunctionText)
        strings.fromFunctionText
      else if (fromCopyText)
        strings.fromCopyText
      else
        strings.restored,
      strings.functionCount(value.functions.length),
      strings.visibleCount(visibleCount),
      'x ${formatGraphNumber(value.viewport.xMin)} ~ ${formatGraphNumber(value.viewport.xMax)}',
    ].join(' · ');
  }
}

/// 中文：**`strings` 是可选参数，没传就用中文那一份。** 这不是"静默回落"，而是这一族今天唯一
///       可用的形状：唯一的调用方 `graph_page.dart` 是另一位作者的未提交工作，本轮不许改，它的
///       调用点只传一个位置参数。默认值让那里保持编译通过、且逐字节渲染今天这些字；等下一轮把
///       `GraphWorkspaceStrings.of(context)` 从那儿传进来，这个默认值就只剩测试在用。
///       ——理由与整条时间线写在 `graph_workspace_strings.dart` 的文件头上。
/// English: **`strings` is optional and falls back to the Chinese table.** This is not a "silent
///          fallback" but the only shape available to this family today: the sole caller,
///          `graph_page.dart`, is another author's uncommitted work that must not be touched this
///          round, and its call site passes one positional argument. The default keeps that site
///          compiling and rendering exactly today's characters; once the next round passes
///          `GraphWorkspaceStrings.of(context)` in from there, the default is used by tests alone.
///          The reasoning and the whole timeline are on `graph_workspace_strings.dart`'s file head.
GraphWorkspacePasteResult parseGraphWorkspacePasteText(
  String input, {
  GraphWorkspaceStrings? strings,
}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return GraphWorkspacePasteResult.empty(strings: strings);

  final jsonWorkspace = decodeGraphWorkspace(trimmed);
  if (jsonWorkspace != null) {
    return GraphWorkspacePasteResult(
      workspace: jsonWorkspace,
      fromCopyText: false,
      strings: strings,
    );
  }

  final copyWorkspace = _parseGraphCopyTextWorkspace(trimmed);
  if (copyWorkspace != null) {
    return GraphWorkspacePasteResult(
      workspace: copyWorkspace,
      fromCopyText: true,
      strings: strings,
    );
  }

  final functionTextWorkspace = _parseGraphFunctionTextWorkspace(trimmed);
  if (functionTextWorkspace == null) {
    return GraphWorkspacePasteResult.empty(strings: strings);
  }
  return GraphWorkspacePasteResult(
    workspace: functionTextWorkspace,
    fromCopyText: false,
    fromFunctionText: true,
    strings: strings,
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
        color: graphPalette[functions.length % graphPalette.length],
      );
      if (preview.isValid) {
        functions.add(GraphFunction(
          expression: preview.normalizedExpression,
          label: preview.label,
          color: graphPalette[functions.length % graphPalette.length],
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
    final color = graphPalette[functions.length % graphPalette.length];
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
