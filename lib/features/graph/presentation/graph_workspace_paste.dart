import 'dart:convert';

import '../models/graph_models.dart';
import '../models/graph_strings.dart';

/// 中文：粘贴结果小结的文案**现在走 `GraphStrings`**（graph 整棵子树那一张表）。本轮之前这里
///       另有一张只有六条的 `GraphWorkspaceStrings`，它带着"没传就中文"的默认值——那是因为当时
///       唯一的调用方是另一位作者的未提交文件、不许改。本轮调用方已入库，默认值随之删掉：
///       **表必填，漏传是编译错误。** 六条文案与原来逐字节相同，只是换了住址。
/// English: The paste summary's copy **now goes through `GraphStrings`** (the table for the whole
///          graph subtree). Before this round there was a separate six-entry `GraphWorkspaceStrings`
///          here carrying a "Chinese when omitted" default, because the only caller was another
///          author's uncommitted file that could not be touched. That caller is committed now, so the
///          default is gone: **the table is required and omitting it is a compile error.** The six
///          strings are byte-identical to before; only their address changed.
class GraphWorkspacePasteResult {
  /// 中文：**不是 `const`。** 文案表是 `static final`（带闭包，不是常量表达式），构造体里要装它。
  /// English: **Not `const`.** The copy tables are `static final` (they hold closures, not constant
  ///          expressions), and the constructor stores one.
  GraphWorkspacePasteResult({
    required this.workspace,
    required this.fromCopyText,
    required this.strings,
    this.fromFunctionText = false,
  });

  factory GraphWorkspacePasteResult.empty({required GraphStrings strings}) =>
      GraphWorkspacePasteResult(
        workspace: null,
        fromCopyText: false,
        strings: strings,
      );

  final GraphWorkspace? workspace;
  final bool fromCopyText;
  final bool fromFunctionText;

  /// 中文：这一份结果该用哪种语言说话。**它是字段而不是查出来的**——`summary` 是个 getter，
  ///       没有 `BuildContext` 可查；语言由调用方（`graph_page.dart` 从 `context` 取表）定下。
  /// English: Which language this result speaks. **It is a field rather than something looked up** —
  ///          `summary` is a getter with no `BuildContext`; the language is fixed by the caller
  ///          (`graph_page.dart`, reading the table off `context`).
  final GraphStrings strings;

  bool get hasWorkspace => workspace != null;

  /// 中文：`graph_page.dart` 用的那一条。语言取自构造时定下的 [strings]。
  /// English: The entry point `graph_page.dart` uses. The language comes from the [strings] fixed at
  ///          construction.
  String get summary => summaryIn(strings);

  /// 中文：**给测试与下一处调用留的显式入口。** 传入另一张表即换一种语言，不改字段。
  /// English: **An explicit entry point for tests and any next caller.** Pass another table to switch
  ///          language without touching the field.
  String summaryIn(GraphStrings strings) {
    final value = workspace;
    if (value == null) return strings.noWorkspace;
    final visibleCount = value.functions.where((item) => item.visible).length;
    return [
      if (fromFunctionText)
        strings.fromFunctionText
      else if (fromCopyText)
        strings.fromCopyText
      else
        strings.workspaceRestored,
      strings.functionCount(value.functions.length),
      strings.visibleCount(visibleCount),
      'x ${formatGraphNumber(value.viewport.xMin)} ~ ${formatGraphNumber(value.viewport.xMax)}',
    ].join(' · ');
  }
}

/// 中文：**`strings` 是必填参数。** 理由见本文件头上那段（调用方已入库、默认值已删）。
///       [degreeMode] 是产出的函数（与它们各自那次预览探测）求值用的角度单位，由调用方——图形页——
///       从设置里递下来；理由见 `GraphFunction.degreeMode`。
/// English: **`strings` is required.** The reasoning is in the block at the head of this file (the
///          caller is committed and the default was removed). [degreeMode] is the angle unit the
///          resulting functions (and each of their preview probes) evaluate under; the caller — the
///          graph page — hands it down from settings. See `GraphFunction.degreeMode`.
GraphWorkspacePasteResult parseGraphWorkspacePasteText(
  String input, {
  required GraphStrings strings,
  bool degreeMode = false,
}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return GraphWorkspacePasteResult.empty(strings: strings);

  final jsonWorkspace =
      decodeGraphWorkspace(trimmed, strings: strings, degreeMode: degreeMode);
  if (jsonWorkspace != null) {
    return GraphWorkspacePasteResult(
      workspace: jsonWorkspace,
      fromCopyText: false,
      strings: strings,
    );
  }

  final copyWorkspace =
      _parseGraphCopyTextWorkspace(trimmed, strings, degreeMode);
  if (copyWorkspace != null) {
    return GraphWorkspacePasteResult(
      workspace: copyWorkspace,
      fromCopyText: true,
      strings: strings,
    );
  }

  final functionTextWorkspace =
      _parseGraphFunctionTextWorkspace(trimmed, strings, degreeMode);
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

GraphWorkspace? _parseGraphCopyTextWorkspace(
  String input,
  GraphStrings strings,
  bool degreeMode,
) {
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
    // 中文：小节边界。英文等价物与中文**逐条对齐**：`viewport` / `graph data` 在下面与
    //       `_looksLikeGraphCopyText` 里，`functions` / `markers` / `current marker` 在这里。
    //       补 `current marker` 是交接文档点名的那一条——`markers` 与 `hidden` 其实早已接上，
    //       只有它漏了；不补的话，等 `buildGraphCopyText` 哪天出英文，英文界面复制出去的数据
    //       在英文界面里自己都粘不回来。
    // English: Section boundaries. The English equivalents line up one-for-one with the Chinese:
    //          `viewport` / `graph data` below and in `_looksLikeGraphCopyText`, and
    //          `functions` / `markers` / `current marker` here. Adding `current marker` is the item
    //          the handover named — `markers` and `hidden` were in fact already accepted and only
    //          this one was missing; without it, once `buildGraphCopyText` ever emits English, data
    //          copied out of the English interface would not paste back into it.
    if (line == '标记' ||
        line == '当前标记' ||
        line == '函数' ||
        normalized == 'markers' ||
        normalized == 'current marker' ||
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
        strings: strings,
        degreeMode: degreeMode,
      );
      if (preview.isValid) {
        functions.add(GraphFunction(
          expression: preview.normalizedExpression,
          label: preview.label,
          color: graphPalette[functions.length % graphPalette.length],
          visible: visible,
          degreeMode: degreeMode,
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

GraphWorkspace? _parseGraphFunctionTextWorkspace(
  String input,
  GraphStrings strings,
  bool degreeMode,
) {
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
    final preview = previewGraphFunctionInput(candidate,
        color: color, strings: strings, degreeMode: degreeMode);
    if (!preview.isValid) continue;
    if (!seen.add(preview.normalizedExpression)) continue;
    functions.add(GraphFunction(
      expression: preview.normalizedExpression,
      label: preview.label,
      color: color,
      degreeMode: degreeMode,
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
      // 中文：**判据要认 `buildGraphCopyText` 真正写出去的那个词。** 中文侧写 `(隐藏)`，英文侧
      //       写的是 `strings.hide` 的 `(Hide)`——不是 `hidden`。原来只认 `隐藏` 与 `hidden`，
      //       于是**英文界面复制出去的数据再粘回来时，隐藏的函数会悄悄变回显示**。
      //       两种英文拼法都收：`hide`（现在的线格式）与 `hidden`（更早的写法、现有测试仍用它）。
      //       **`hide` 不是 `hidden` 的子串**（`hidden` 是 `hid`+`den`），所以两个都要判。
      // English: **the test has to recognise the word `buildGraphCopyText` actually writes.** The
      //          Chinese side writes `(隐藏)` and the English side writes `strings.hide`, which is
      //          `(Hide)` — not `hidden`. The old test only knew `隐藏` and `hidden`, so **pasting
      //          English data back in silently turned hidden functions visible again**. Both English
      //          spellings are accepted: `hide` (the current wire format) and `hidden` (the earlier
      //          spelling the existing test still uses). **`hide` is not a substring of `hidden`**
      //          (`hidden` is `hid` + `den`), so both have to be tested.
      if (line.contains('隐藏') ||
          line.toLowerCase().contains('hide') ||
          line.toLowerCase().contains('hidden')) {
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
