part of 'expression_parser.dart';

String _stripPastedCalculationResult(String source) {
  final normalized = _normalizeFullWidthAscii(source)
      .replaceAll('\u00a0', ' ')
      .replaceAll('≈', '~=')
      .trim();
  if (normalized.isEmpty) return normalized;

  final lines = normalized
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  for (final line in lines) {
    final expression = RegExp(
      r'^(?:表达式|算式|expression|expr|formula)\s*[:：]\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (expression != null && expression.group(1)!.trim().isNotEmpty) {
      return expression.group(1)!.trim();
    }
  }
  for (final line in lines) {
    final labeledResult = _labeledResultExpression(line);
    if (labeledResult != null) return labeledResult;
  }

  if (lines.length == 1) {
    final labeledResult = _labeledResultExpression(lines.single);
    if (labeledResult != null) return labeledResult;
    final annotated = _trailingResultAnnotationExpression(lines.single);
    if (annotated != null) return annotated;
  }
  return source;
}

String? _labeledResultExpression(String line) {
  final match = RegExp(
    r'^(?:ans|answer|result|value|结果|答案|当前值)\s*[:：=]\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(line);
  final value = match?.group(1)?.trim();
  return value == null || value.isEmpty ? null : value;
}

String? _trailingResultAnnotationExpression(String line) {
  final trailingEquals = RegExp(r'^(.+?)\s*=\s*$').firstMatch(line);
  if (trailingEquals != null) {
    final expression = trailingEquals.group(1)!.trim();
    return _looksLikeCalculationExpression(expression) ? expression : null;
  }

  final annotated = RegExp(
    r'^(.+?)\s*(?:=|~=|≃|≅|->|=>|→)\s*[+-]?(?:(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?%?\s*$',
    caseSensitive: false,
  ).firstMatch(line);
  if (annotated == null) return null;
  final expression = annotated.group(1)!.trim();
  return _looksLikeCalculationExpression(expression) ? expression : null;
}

bool _looksLikeCalculationExpression(String source) {
  final text = source.trim().toLowerCase();
  if (text.isEmpty) return false;
  if (RegExp(r'[πτφ∞√∛¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]').hasMatch(text)) {
    return true;
  }
  if (RegExp(r'\b(?:pi|tau|phi|inf|infinity)\b').hasMatch(text)) {
    return true;
  }
  if (RegExp(
          r'\b(?:arcsin|arccos|arctan|atan2|sinh|cosh|tanh|sin|cos|tan|cot|sec|csc|sqrt|cbrt|ln|log|lg|abs|exp|floor|ceil|round|deg|rad|min|max|mod|ncr|npr|gcd|lcm|root|fact)\b')
      .hasMatch(text)) {
    return true;
  }
  if (RegExp(r'0[xbo][0-9a-f_]+').hasMatch(text)) return true;
  if (RegExp(r'\d(?:_?\d)*(?:\.\d*)?e[+-]?\d', caseSensitive: false)
      .hasMatch(text)) {
    return true;
  }
  return RegExp(r'\d').hasMatch(text) &&
      RegExp(r'[+\-*/^×÷()%!()]').hasMatch(text);
}

const String _constantPattern = 'infinity|inf|tau|phi|pi|e';
const String _leadingConstantPattern =
    'infinity|inf|tau|phi|pi|e(?![+-]?\\d)';
/// 中文：**接受两个及以上实参的函数名——唯一的一份。** 两处用它：
///       归一化时的「`名字(...)` 里的逗号是实参分隔符还是千分位」（[_startsFunctionArgument]），
///       以及求值时的实参个数校验（[_validateFunctionArity]）。
///       这两个问题必须用同一份表：`atan2(7,100)` 是**两个实参**（`atan2` 接两个），
///       而 `log2(1,024)` 是**一个实参 1024**（`log2` 只接一个）——同一个形状，
///       正确的读法相反。用「名字以数字结尾」或「括号前面是字母数字」都判不对。
/// English: **the function names that accept two or more arguments — one copy.** Two places use it:
///          whether a comma inside `name(...)` is an argument separator or a thousands separator
///          ([_startsFunctionArgument]), and the argument-count validation at evaluation time
///          ([_validateFunctionArity]). They must share this table: `atan2(7,100)` is **two
///          arguments** (`atan2` takes two) while `log2(1,024)` is **one argument, 1024** (`log2`
///          takes one) — the same shape with opposite correct readings. Neither "the name ends in a
///          digit" nor "the character before the bracket is alphanumeric" gets both right.
const Set<String> _twoArgumentFunctions = <String>{
  'atan2',
  'mod',
  'ncr',
  'npr',
  'root',
  'log',
  // 中文：`STAT` 面板那三格（`pearson`/`covar`/`spearman`）插进去的是**一个**实参
  //       （`pearson(matrix(2,4,…))`），所以它们在这里**不是承重的**——实测过：把它们删掉，
  //       那一格插进去的文本逐字节不变。写进来是因为它们确实是两个形参的函数，
  //       而这张表问的就是那一句话（同 `atan2`/`root`）。承重的是下面 `matrix`。
  // English: the three `STAT` cells (`pearson`/`covar`/`spearman`) insert **one** argument
  //          (`pearson(matrix(2,4,…))`), so these entries are **not load-bearing** — measured:
  //          removing them leaves the text that cell inserts byte-for-byte identical. They are here
  //          because each really does take two parameters and that is this table's one question (as
  //          with `atan2`/`root`). What is load-bearing is `matrix` below.
  'pearson',
  'covar',
  'spearman',
};

/// 中文：可变形参的函数（一个以上都收）。
///
///       统计那四个（`mean`/`median`/`stdev`/`var`）在这一张表里是**必须的**，不是顺手加的：
///       它们都吃一串数，而这段归一化会把函数实参里那个逗号判成千分位分隔符——
///       `mean(1,234)` 于是成了**一个**实参 `1234`（而不是 `1` 与 `234`），引擎照样答得出来、
///       照样是一个数字，屏幕上就是一个静默的错值。表里没有它，这个错值就成立。
///       它们只在引擎那边成立（应用自己的解析器没有实现，见 `AppEngineVocabulary.identifiers`），
///       但它们与本表其余几行回答的是同一个问题：**这个名字可能接两个以上实参吗**。
/// English: variadic functions (any number of arguments from one up).
///
///          The four statistics names (`mean`/`median`/`stdev`/`var`) are **load-bearing** in this
///          table rather than added for tidiness: each takes a run of numbers, and this normalisation
///          otherwise reads the comma inside a call as a thousands separator — `mean(1,234)` becomes
///          **one** argument, `1234`, instead of `1` and `234`. The engine still answers, still with a
///          number, and the screen carries a silent wrong value. Without the entry, that wrong value
///          stands. They hold only on the engine's side (this app's own parser does not implement
///          them — see `AppEngineVocabulary.identifiers`), but they answer this table's one question:
///          **may this name take two or more arguments.**
const Set<String> _variadicFunctions = <String>{
  'min',
  'max',
  'gcd',
  'lcm',
  'mean',
  'median',
  'stdev',
  'var',
  // 中文：**`matrix` 在这一张表里是承重的，而且它修的是一个已经存在的静默错值。**
  //       它的形参是「行数、列数、然后是那些值」，所以它里面的逗号全是分隔符。不写进来的话，
  //       这段归一化会把任何「逗号后面正好三位数字」的那一对吃掉——实测（归一化之后）：
  //
  //       | 输入 | 不写 `matrix` 时归一化成 | 后果 |
  //       |---|---|---|
  //       | `matrix(1,3,1,100,200)` | `matrix(1,3,1100200)` | 1×3 的矩阵只剩**一个**值 |
  //       | `matrix(1,5,1,8,27,64,125)` | `matrix(1,5,1,8,27,64125)` | 最后一个值从 125 变成 64125 |
  //
  //       两行都是**看着像答案的错值**，不是错误。它在本轮之前就存在（`matrix` 早就在词表里、
  //       用户打得进去），而本轮的每一格都要插一条 `matrix(…)`，所以它从「偶发」变成「必然」。
  //       **这一条与本项目最老的那条规矩是同一条**：错值比错误坏。
  // English: **`matrix` is load-bearing in this table, and it fixes a silent wrong value that already
  //          existed.** Its parameters are "rows, columns, then the values", so every comma inside it
  //          separates. Without the entry this normalisation eats any pair shaped "comma followed by
  //          exactly three digits" — measured, after normalisation:
  //
  //          | input | normalised without `matrix` | consequence |
  //          |---|---|---|
  //          | `matrix(1,3,1,100,200)` | `matrix(1,3,1100200)` | the 1×3 matrix has **one** value left |
  //          | `matrix(1,5,1,8,27,64,125)` | `matrix(1,5,1,8,27,64125)` | the last value becomes 64125 |
  //
  //          Both are **plausible-looking wrong values**, not errors. It predates this round (`matrix`
  //          has long been in the vocabulary and the user can type it), and every cell this round adds
  //          inserts a `matrix(…)`, so it goes from occasional to certain. **This is the project's
  //          oldest rule**: a wrong value is worse than an error.
  'matrix',
};

/// 中文：上两张表的并集——「这个名字可能接两个以上实参」。
/// English: the union of the two above — "this name may take two or more arguments".
const Set<String> _multiArgumentFunctions = <String>{
  ..._twoArgumentFunctions,
  ..._variadicFunctions,
};

final String _functionPattern = ExpressionParser.functionNames.join('|');
const String _bareUnaryFunctionPattern =
    'asin|acos|atan|sinh|cosh|tanh|sin|cos|tan|cot|sec|csc|sqrt|cbrt|log2|log|ln|abs|exp|floor|ceil|round|fact|deg|rad';
const String _decimalNumberPattern =
    r'(?:\d(?:_?\d)*(?:\.\d(?:_?\d)*)?|\.\d(?:_?\d)*)(?:e[+-]?\d(?:_?\d)*)?';
const String _radixNumberPattern =
    r'(?:0x[0-9a-f](?:_?[0-9a-f])*|0b[01](?:_?[01])*|0o[0-7](?:_?[0-7])*)';
const String _bareFunctionArgumentPattern =
    '(?:[+-]\\s*)?(?:(?:$_decimalNumberPattern)[%°]?|$_radixNumberPattern|(?:$_constantPattern))';

String _normalizeGroupedNumberSeparators(String source) {
  final pattern = RegExp(
      r'(?<![A-Za-z0-9_.])([+-]?\d{1,3}(?:,\d{3})+(?:\.\d+)?)(?![A-Za-z0-9_.])');
  return source.replaceAllMapped(
    pattern,
    (match) => _startsFunctionArgument(source, match.start)
        ? match.group(1)!
        : match.group(1)!.replaceAll(',', ''),
  );
}

bool _startsFunctionArgument(String source, int start) {
  var index = start - 1;
  while (index >= 0 && source[index].trim().isEmpty) {
    index--;
  }
  if (index < 0 || source[index] != '(') return false;
  index--;
  while (index >= 0 && source[index].trim().isEmpty) {
    index--;
  }
  if (index >= 0 && source[index] == ')') return true;
  // 中文：读回 `(` 前面那个**标识符**，问它接不接受两个以上实参（见 [_multiArgumentFunctions]）。
  //       `atan2(7,100)` → true（逗号是分隔符）；`log2(1,024)` 与 `2(1,234)` → false（逗号是千分位）。
  //
  //       读到的名字必须**先归一化再查表**，两个理由都在实测里：那张表写的是归一化**之后**的名字，
  //       而这段文本还没过别名替换（`c(1,234)` 修复前 = 1234，`ncr(1,234)` = 0）；而且它还没过
  //       `.toLowerCase()`（`C(1,234)`/`NCR(1,234)` 同样进不了表）。
  // English: read the **identifier** before the bracket and ask whether it accepts two or more
  //          arguments (see [_multiArgumentFunctions]). `atan2(7,100)` → true (the comma separates);
  //          `log2(1,024)` and `2(1,234)` → false (the comma is a thousands separator).
  //
  //          The name read here has to be **normalised before the lookup**, for two reasons that are
  //          both measured: the table is written in post-normalisation names while this text has not
  //          been through the alias replacement yet (`c(1,234)` was 1234 before the fix while
  //          `ncr(1,234)` was 0), and it has not been through `.toLowerCase()` either
  //          (`C(1,234)`/`NCR(1,234)` did not reach the table the same way).
  final nameEnd = index + 1;
  while (index >= 0 && RegExp(r'[A-Za-z0-9]').hasMatch(source[index])) {
    index--;
  }
  final name = ExpressionParser.canonicalFunctionName(source.substring(index + 1, nameEnd));
  return _multiArgumentFunctions.contains(name);
}

String _normalizeFunctionAliases(String source) {
  var text = source;
  for (final entry in ExpressionParser.functionAliases.entries) {
    // 中文：单字母别名（`c`/`p`）必须**紧跟着括号**才算别名——不加这条限制，它们会替换掉表达式里
    //       每一个 `c` 与 `p`。其余别名按词边界替换（`lg 100` 这种裸写法也要能归一化，
    //       后面 `_normalizeBareUnaryFunctionCalls` 才认得出 `log`）。
    // English: the one-letter aliases (`c`/`p`) only count **immediately before a bracket** — without
    //          that restriction they would replace every `c` and `p` in the expression. The other
    //          aliases replace on word boundaries (`lg 100` has to normalise too, or
    //          `_normalizeBareUnaryFunctionCalls` will not recognise the `log` it produces).
    final pattern = entry.key.length == 1
        ? RegExp('\\b${entry.key}(?=\\s*\\()')
        : RegExp('\\b${entry.key}\\b');
    text = text.replaceAllMapped(pattern, (_) => entry.value);
  }
  return text;
}

String _normalizeBareUnaryFunctionCalls(String source) {
  final pattern = RegExp(
    '\\b($_bareUnaryFunctionPattern)\\s+($_bareFunctionArgumentPattern)(?![a-z0-9_.])',
  );
  return source.replaceAllMapped(pattern, (match) {
    final argument = match.group(2)!.replaceAll(RegExp(r'\s+'), '');
    return '${match.group(1)}($argument)';
  });
}

String _normalizeLatexExpression(String source) {
  var text = source
      .replaceAll(r'\left', '')
      .replaceAll(r'\right', '')
      .replaceAll(r'\cdot', '*')
      .replaceAll(r'\times', '*')
      .replaceAll(r'\div', '/')
      .replaceAll(r'\pi', 'pi')
      .replaceAll(r'\tau', 'tau')
      .replaceAll(r'\varphi', 'phi')
      .replaceAll(r'\phi', 'phi')
      .replaceAll(r'\infty', 'infinity')
      .replaceAll(r'\%', '%')
      .replaceAll(r'\,', '')
      .replaceAll(r'\;', '')
      .replaceAll(r'\:', '');
  text = _normalizeLatexFractions(text);
  text = _normalizeLatexSquareRoots(text);
  text = _normalizeLatexCommands(text);
  text = _normalizeLatexWrappedFunctionCalls(text);
  return text.replaceAll('{', '(').replaceAll('}', ')');
}

String _normalizeLatexFractions(String source) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < source.length) {
    final commandIndex = source.indexOf(r'\frac', index);
    if (commandIndex < 0) {
      buffer.write(source.substring(index));
      break;
    }
    buffer.write(source.substring(index, commandIndex));
    var cursor = commandIndex + r'\frac'.length;
    final numerator =
        _consumeLatexGroup(source, cursor, open: '{', close: '}');
    if (numerator == null) {
      buffer.write(source.substring(commandIndex, cursor));
      index = cursor;
      continue;
    }
    cursor = numerator.end;
    final denominator =
        _consumeLatexGroup(source, cursor, open: '{', close: '}');
    if (denominator == null) {
      buffer.write(source.substring(commandIndex, cursor));
      index = cursor;
      continue;
    }
    buffer
      ..write('((')
      ..write(_normalizeLatexFractions(numerator.value))
      ..write(')/(')
      ..write(_normalizeLatexFractions(denominator.value))
      ..write('))');
    index = denominator.end;
  }
  return buffer.toString();
}

String _normalizeLatexSquareRoots(String source) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < source.length) {
    final commandIndex = source.indexOf(r'\sqrt', index);
    if (commandIndex < 0) {
      buffer.write(source.substring(index));
      break;
    }
    buffer.write(source.substring(index, commandIndex));
    var cursor = commandIndex + r'\sqrt'.length;
    final degree = _consumeLatexGroup(source, cursor, open: '[', close: ']');
    if (degree != null) cursor = degree.end;
    final body = _consumeLatexGroup(source, cursor, open: '{', close: '}');
    if (body == null) {
      buffer.write('sqrt');
      index = cursor;
      continue;
    }
    final bodyText = _normalizeLatexSquareRoots(body.value);
    if (degree == null) {
      buffer
        ..write('sqrt(')
        ..write(bodyText)
        ..write(')');
    } else {
      buffer
        ..write('root(')
        ..write(bodyText)
        ..write(',')
        ..write(degree.value)
        ..write(')');
    }
    index = body.end;
  }
  return buffer.toString();
}

String _normalizeLatexCommands(String source) {
  return source
      .replaceAllMapped(
        RegExp(
            r'\\(arcsin|arccos|arctan|atan2|sinh|cosh|tanh|sin|cos|tan|cot|sec|csc|sqrt|cbrt|ln|log|lg|abs|exp|floor|ceil|round|deg|rad|min|max|mod|ncr|npr|gcd|lcm|root|fact)\b'),
        (match) => match.group(1)!,
      )
      .replaceAllMapped(RegExp(r'\\operatorname\s*\{([a-z]+)\}'),
          (match) => match.group(1)!);
}

String _normalizeLatexWrappedFunctionCalls(String source) {
  const functions =
      'arcsin|arccos|arctan|atan2|sinh|cosh|tanh|sin|cos|tan|cot|sec|csc|sqrt|cbrt|ln|log|lg|abs|exp|floor|ceil|round|deg|rad|min|max|mod|ncr|npr|gcd|lcm|root|fact';
  return source.replaceAllMapped(
    RegExp('\\b($functions)\\s*\\{\\s*\\(([^{}]*)\\)\\s*\\}'),
    (match) => '${match.group(1)}(${match.group(2)})',
  );
}

_LatexGroup? _consumeLatexGroup(
  String source,
  int index, {
  required String open,
  required String close,
}) {
  var cursor = index;
  while (cursor < source.length && source[cursor].trim().isEmpty) {
    cursor++;
  }
  if (cursor >= source.length || source[cursor] != open) return null;
  var depth = 0;
  for (var i = cursor; i < source.length; i++) {
    if (source[i] == open) {
      depth++;
    } else if (source[i] == close) {
      depth--;
      if (depth == 0) {
        return _LatexGroup(source.substring(cursor + 1, i), i + 1);
      }
    }
  }
  return null;
}

String _normalizeUnicodeFractions(String source) {
  final text = source.replaceAllMapped(
    RegExp(r'(\d+)([¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞])'),
    (match) =>
        '(${match.group(1)}+${_unicodeFractionExpression(match.group(2)!)} )',
  );
  return text.replaceAllMapped(
    RegExp(r'[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]'),
    (match) => '(${_unicodeFractionExpression(match.group(0)!)} )',
  );
}

String _unicodeFractionExpression(String text) {
  return const {
    '¼': '1/4',
    '½': '1/2',
    '¾': '3/4',
    '⅐': '1/7',
    '⅑': '1/9',
    '⅒': '1/10',
    '⅓': '1/3',
    '⅔': '2/3',
    '⅕': '1/5',
    '⅖': '2/5',
    '⅗': '3/5',
    '⅘': '4/5',
    '⅙': '1/6',
    '⅚': '5/6',
    '⅛': '1/8',
    '⅜': '3/8',
    '⅝': '5/8',
    '⅞': '7/8',
  }[text]!;
}

String _normalizeExponentialDisplay(String source) {
  return source.replaceAllMapped(
    RegExp(r'\be\^\(((?:[^()]|\([^()]*\))+)\)'),
    (match) => 'exp(${match.group(1)})',
  );
}

String _normalizeSuperscriptRoots(String source) {
  const superscript = '[⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻]+';
  var text = source.replaceAllMapped(
    RegExp('$superscript' r'sqrt\(((?:[^()]|\([^()]*\))+)\)'),
    (match) =>
        'root(${match.group(1)},${_decodeSuperscript(match.group(0)!.split('sqrt').first)})',
  );
  text = text.replaceAllMapped(
    RegExp('$superscript' r'sqrt((?:\d+(?:\.\d+)?)|pi|e)(?![a-z0-9_(])'),
    (match) =>
        'root(${match.group(1)},${_decodeSuperscript(match.group(0)!.split('sqrt').first)})',
  );
  return text;
}

String _normalizeIndexedRoots(String source) {
  var text = source.replaceAllMapped(
    RegExp(r'sqrt\[([^\[\](),]+)\]\(((?:[^()]|\([^()]*\))+)\)'),
    (match) => 'root(${match.group(2)},${match.group(1)})',
  );
  text = text.replaceAllMapped(
    RegExp(r'sqrt\[([^\[\](),]+)\]((?:\d+(?:\.\d+)?)|pi|e)(?![a-z0-9_(])'),
    (match) => 'root(${match.group(2)},${match.group(1)})',
  );
  return text;
}

String _normalizeAbsoluteValueBars(String source) {
  var text = source;
  final pattern = RegExp(r'\|([^|]+)\|');
  while (pattern.hasMatch(text)) {
    text =
        text.replaceAllMapped(pattern, (match) => 'abs(${match.group(1)})');
  }
  return text;
}

String _replacePercent(String source) {
  var text = source;
  final pattern = RegExp('(($_decimalNumberPattern)|\\([^()]+\\))%');
  while (pattern.hasMatch(text)) {
    text =
        text.replaceAllMapped(pattern, (match) => '(${match.group(1)})/100');
  }
  return text;
}

String _normalizeScientificNotation(String source) {
  return source.replaceAllMapped(
    RegExp(r'(\d+(?:\.\d+)?|\.\d+)\s*(?:\*|x)\s*10\^([+-]?\d+)'),
    (match) => '${match.group(1)}e${match.group(2)}',
  );
}

String _normalizeSuperscriptExponents(String source) {
  return source.replaceAllMapped(
    RegExp(r'[⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻]+'),
    (match) => '^${_decodeSuperscript(match.group(0)!)}',
  );
}

String _decodeSuperscript(String source) {
  final buffer = StringBuffer();
  for (final rune in source.runes) {
    buffer.write(switch (rune) {
      0x2070 => '0',
      0x00b9 => '1',
      0x00b2 => '2',
      0x00b3 => '3',
      0x2074 => '4',
      0x2075 => '5',
      0x2076 => '6',
      0x2077 => '7',
      0x2078 => '8',
      0x2079 => '9',
      0x207a => '+',
      0x207b => '-',
      _ => '',
    });
  }
  return buffer.toString();
}

String _normalizeMathSubscripts(String source) {
  final buffer = StringBuffer();
  for (final rune in source.runes) {
    buffer.write(switch (rune) {
      0x2080 => '0',
      0x2081 => '1',
      0x2082 => '2',
      0x2083 => '3',
      0x2084 => '4',
      0x2085 => '5',
      0x2086 => '6',
      0x2087 => '7',
      0x2088 => '8',
      0x2089 => '9',
      _ => String.fromCharCode(rune),
    });
  }
  return buffer.toString();
}

String _normalizeFullWidthAscii(String source) {
  return source.runes.map((code) {
    if (code >= 0xff01 && code <= 0xff5e) {
      return String.fromCharCode(code - 0xfee0);
    }
    return String.fromCharCode(code);
  }).join();
}
