part of 'text_tool_controller.dart';

extension _TextToolCustomFormulaTools on TextToolController {
  TextToolOutput _customFormula({
    required String input,
    required String formula,
    required String a,
    required String b,
    required String c,
  }) {
    final parsed = _parseCustomFormulaInput(
      input: input,
      fallbackFormula: formula,
      fallbackVariables: {'a': a, 'b': b, 'c': c},
    );
    if (parsed.formula.trim().isEmpty) {
      throw const FormatException('请输入公式，例如 a * b + c');
    }

    final expression = _substituteFormulaVariables(
      parsed.formula,
      parsed.variables,
    );
    final result = ExpressionParser(expression, degreeMode: true).parse();
    if (!result.isFinite) {
      throw const FormatException('公式结果不是有限数值，请检查除零、对数或开方范围。');
    }

    final usedVariables = _customFormulaVariables(parsed.formula);
    final unusedVariables =
        parsed.variables.keys.where((name) => !usedVariables.contains(name));
    final missingVariables =
        usedVariables.where((name) => !parsed.variables.containsKey(name));
    if (missingVariables.isNotEmpty) {
      throw FormatException('公式包含未赋值变量: ${missingVariables.join(', ')}');
    }

    return TextToolOutput(
      _formatFormulaNumber(result),
      [
        '公式: ${parsed.formula}',
        '展开公式: $expression',
        '变量:',
        for (final name in ['a', 'b', 'c'])
          if (parsed.variables[name] case final value?)
            '  $name = ${value.value}  来源: ${value.source}',
      ].join('\n'),
      insights: [
        if (parsed.extractedFormulaFromInput) '已从输入文本中提取公式。',
        if (parsed.extractedVariablesFromInput.isNotEmpty)
          '已从输入文本中提取变量: ${parsed.extractedVariablesFromInput.join(', ')}。',
        if (usedVariables.isNotEmpty)
          '公式使用变量: ${usedVariables.toList()..sort()}.',
        if (unusedVariables.isNotEmpty) '未使用变量: ${unusedVariables.join(', ')}。',
        '表达式按角度制解析三角函数，支持常量 pi/e 和常用数学函数。',
      ],
    );
  }

  _ParsedCustomFormula _parseCustomFormulaInput({
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
        throw FormatException('变量 $name: ${parsed.error ?? '输入无效'}');
      }
      variables[name] = _ParsedCustomFormulaVariable(
        value: value,
        raw: raw,
        source: fields.containsKey(name) ? '输入文本 "$raw"' : '变量框 "$raw"',
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
