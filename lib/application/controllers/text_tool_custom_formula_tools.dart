part of 'text_tool_controller.dart';

extension _TextToolCustomFormulaTools on TextToolController {
  /// 中文：这里收的是**门面**（`TextToolStrings`）而不是 `TextToolTextStrings`：变量解析
  ///       失败时兜底那句话就是全族共用的「输入无效」，而复用它比在表里再抄一份同样的字干净。
  /// English: This takes the **facade** (`TextToolStrings`) rather than `TextToolTextStrings`: the
  ///          fallback when a variable fails to parse is the family-wide "invalid input", and reusing
  ///          it beats copying the same words into this table as well.
  TextToolOutput _customFormula({
    required TextToolStrings strings,
    required String input,
    required String formula,
    required String a,
    required String b,
    required String c,
  }) {
    final text = strings.text;
    final parsed = _parseCustomFormulaInput(
      strings: strings,
      input: input,
      fallbackFormula: formula,
      fallbackVariables: {'a': a, 'b': b, 'c': c},
    );
    if (parsed.formula.trim().isEmpty) {
      throw FormatException(text.formulaEmpty);
    }

    final expression = _substituteFormulaVariables(
      parsed.formula,
      parsed.variables,
    );
    final result = ExpressionParser(expression, degreeMode: true).parse();
    if (!result.isFinite) {
      throw FormatException(text.formulaNotFinite);
    }

    final usedVariables = _customFormulaVariables(parsed.formula);
    final unusedVariables =
        parsed.variables.keys.where((name) => !usedVariables.contains(name));
    final missingVariables =
        usedVariables.where((name) => !parsed.variables.containsKey(name));
    if (missingVariables.isNotEmpty) {
      throw FormatException(
          text.formulaMissingVariables(missingVariables.join(', ')));
    }

    return TextToolOutput(
      _formatFormulaNumber(result),
      [
        text.formulaLabel(parsed.formula),
        text.formulaExpanded(expression),
        text.formulaVariables,
        for (final name in ['a', 'b', 'c'])
          if (parsed.variables[name] case final value?)
            text.formulaVariableLine(name, '${value.value}', value.source),
      ].join('\n'),
      insights: [
        if (parsed.extractedFormulaFromInput) text.formulaExtracted,
        if (parsed.extractedVariablesFromInput.isNotEmpty)
          text.formulaExtractedVariables(
              parsed.extractedVariablesFromInput.join(', ')),
        // 中文：这里传的是**排好序的列表本身**，不是 `join` 过的串——原文写的是
        //       `'公式使用变量: ${list}.'`，Dart 把列表插值成 `[a, b, c]`。那是屏幕上实际出现的
        //       字，所以照抄；`join` 会把它悄悄变成 `a, b, c`，那是改行为不是改语言。
        // English: What is passed here is **the sorted list itself**, not a joined string: the
        //          original read `'公式使用变量: ${list}.'` and Dart renders a list as `[a, b, c]`.
        //          That is what actually appeared on screen, so it is reproduced verbatim; `join`
        //          would silently turn it into `a, b, c` — a behaviour change, not a language one.
        if (usedVariables.isNotEmpty)
          text.formulaUsedVariables('${usedVariables.toList()..sort()}'),
        if (unusedVariables.isNotEmpty)
          text.formulaUnusedVariables(unusedVariables.join(', ')),
        text.formulaAngleNote,
      ],
    );
  }

  _ParsedCustomFormula _parseCustomFormulaInput({
    required TextToolStrings strings,
    required String input,
    required String fallbackFormula,
    required Map<String, String> fallbackVariables,
  }) {
    final fields = _extractCustomFormulaFields(input);
    final extractedFormula = fields['formula'];
    final formula = extractedFormula ?? fallbackFormula.trim();
    final variables = <String, _ParsedCustomFormulaVariable>{};
    final extractedVariables = <String>[];

    for (final name in ['a', 'b', 'c']) {
      final raw = (fields[name] ?? fallbackVariables[name] ?? '').trim();
      final parsed = ToolDetailController.parseNumericInputDetailed(raw);
      final value = parsed.value;
      if (value == null) {
        throw FormatException(strings.text.formulaVariableError(
          name,
          parsed.error ?? strings.output.invalidInput,
        ));
      }
      variables[name] = _ParsedCustomFormulaVariable(
        value: value,
        raw: raw,
        source: fields.containsKey(name)
            ? strings.text.formulaSourceInput(raw)
            : strings.text.formulaSourceField(raw),
      );
      if (fields.containsKey(name)) extractedVariables.add(name);
    }

    return _ParsedCustomFormula(
      formula: formula,
      variables: variables,
      extractedFormulaFromInput: extractedFormula != null,
      extractedVariablesFromInput: extractedVariables,
    );
  }

  String _substituteFormulaVariables(
    String formula,
    Map<String, _ParsedCustomFormulaVariable> variables,
  ) {
    return formula.replaceAllMapped(
      RegExp(r'\b[a-c]\b', caseSensitive: false),
      (match) {
        final name = match.group(0)!.toLowerCase();
        final variable = variables[name];
        if (variable == null) return match.group(0)!;
        return _formatFormulaNumber(variable.value);
      },
    );
  }

  Set<String> _customFormulaVariables(String formula) {
    return RegExp(r'\b[a-c]\b', caseSensitive: false)
        .allMatches(formula)
        .map((match) => match.group(0)!.toLowerCase())
        .toSet();
  }

  String _formatFormulaNumber(double value) {
    if (value == 0) return '0';
    final fixed = value.toStringAsPrecision(15);
    return fixed
        .replaceFirst(RegExp(r'\.?0+(?=e|$)', caseSensitive: false), '')
        .replaceFirst(RegExp(r'e\+'), 'e');
  }
}

Map<String, String> _extractCustomFormulaFields(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const {};
  final fields = <String, String>{};
  final lines = const LineSplitter().convert(trimmed);
  for (final line in lines) {
    final match = RegExp(
      r'^\s*(formula|expr|expression|公式|表达式|算式|[abc])\s*[:：=]\s*(.+?)\s*$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) continue;
    final key = _normalizeCustomFormulaFieldKey(match.group(1)!);
    if (key == null) continue;
    fields[key] = match.group(2)!.trim();
  }

  final compactMatches = RegExp(
    r'(?:^|[\s,;，；])([abc])\s*[:：=]\s*([^\s,;，；]+)',
    caseSensitive: false,
  ).allMatches(trimmed);
  for (final match in compactMatches) {
    fields[match.group(1)!.toLowerCase()] = match.group(2)!.trim();
  }

  if (!fields.containsKey('formula')) {
    final expressionLine = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .firstWhere(
          (line) =>
              !_looksLikeCustomFormulaAssignment(line) &&
              _looksLikeCustomFormulaExpression(line),
          orElse: () => '',
        );
    if (expressionLine.isNotEmpty) fields['formula'] = expressionLine;
  }
  return fields;
}

String? _normalizeCustomFormulaFieldKey(String key) {
  final normalized = key.trim().toLowerCase();
  if (normalized == 'a' || normalized == 'b' || normalized == 'c') {
    return normalized;
  }
  if (normalized == 'formula' ||
      normalized == 'expr' ||
      normalized == 'expression' ||
      normalized == '公式' ||
      normalized == '表达式' ||
      normalized == '算式') {
    return 'formula';
  }
  return null;
}

bool _looksLikeCustomFormulaAssignment(String line) {
  return RegExp(
    r'^\s*(formula|expr|expression|公式|表达式|算式|[abc])\s*[:：=]',
    caseSensitive: false,
  ).hasMatch(line);
}

bool _looksLikeCustomFormulaExpression(String line) {
  return RegExp(r'\b[abc]\b', caseSensitive: false).hasMatch(line) &&
      RegExp(r'[+\-*/^()]').hasMatch(line);
}

class _ParsedCustomFormula {
  const _ParsedCustomFormula({
    required this.formula,
    required this.variables,
    required this.extractedFormulaFromInput,
    required this.extractedVariablesFromInput,
  });

  final String formula;
  final Map<String, _ParsedCustomFormulaVariable> variables;
  final bool extractedFormulaFromInput;
  final List<String> extractedVariablesFromInput;
}

class _ParsedCustomFormulaVariable {
  const _ParsedCustomFormulaVariable({
    required this.value,
    required this.raw,
    required this.source,
  });

  final double value;
  final String raw;
  final String source;
}
