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
  //
  //       **这一行还不够，这是量出来的。** 第一版只加了这一行就以为好了，红证当场打脸：加上它
  //       之后 `matrix(2,4,1,100,2,200,3,300,4,400)` 照样并成 `matrix(2,4,1100,2200,3300,4400)`
  //       ——因为 [_startsFunctionArgument] 原来只答得了**紧跟在 `(` 后面**的那一个数字，
  //       而这里除第一个以外的每一个都跟在逗号后面。真正让它生效的是同一轮加的
  //       [_sitsInsideVariadicCall]：一个可变形参调用里**任意位置**的逗号都是分隔符。
  //       这两处要一起看——名字在这里，位置那一半在那边。
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
  //
  //          **This line alone is not enough, and that is measured.** The first version added only
  //          this and the red proof slapped it down: with it in place
  //          `matrix(2,4,1,100,2,200,3,300,4,400)` still merged into
  //          `matrix(2,4,1100,2200,3300,4400)` — because [_startsFunctionArgument] originally
  //          answered only for the digit group **immediately after `(`**, and here every group but the
  //          first follows a comma. What actually makes it hold is [_sitsInsideVariadicCall], added in
  //          the same round: inside a variadic call a comma separates in **every** position. The two
  //          have to be read together — the name lives here, the position half lives there.
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
  // 中文：**不是第一个实参的那一份。** 上面那条「紧跟在 `(` 后面」的判据只答得了**第一个**实参
  //       ——`mean(1,234)` 保住了，`mean(1,2,234,5)` 里的第三个实参却会被并成 `2234`（实测）。
  //       一个**可变形参**的调用里每一个逗号都必须是分隔符，所以那一边要问的是**包住它的那个调用**。
  //       固定形参的函数**不走这一支**：那里把逗号全认成分隔符会把一个（并错的）值变成一句实参个数
  //       错误，那是另一件事，不是这一轮的事。
  //
  //       这一段是**回归那一轮新加的**，理由是量出来的：数据集要变成 `matrix(2,n,值…)`，而那些值
  //       正是任意十进制文本——`matrix(2,4,1,100,2,200,3,300,4,400)` 原来会被并成
  //       `matrix(2,4,1100,2200,3300,4400)`，**屏幕上写着那 8 个数，引擎算的是另外 4 个**。
  //       那一类错值本项目有一条硬规矩：错值比错误坏。
  // English: **the argument that is not the first one.** The "immediately after `(`" test above can
  //          only answer for the **first** argument — `mean(1,234)` survives while the third argument
  //          of `mean(1,2,234,5)` is merged into `2234` (measured). Inside a **variadic** call every
  //          comma must be a separator, so what has to be asked there is the call **enclosing** the
  //          number. Fixed-arity functions do **not** come this way: reading every comma as a separator
  //          there would turn a (mis-merged) value into an arity error, which is a different question
  //          and not this round's.
  //
  //          This branch is **new in the regression round** and its reason is measured: the dataset has
  //          to become `matrix(2,n,values…)` and those values are arbitrary decimal text —
  //          `matrix(2,4,1,100,2,200,3,300,4,400)` used to merge into
  //          `matrix(2,4,1100,2200,3300,4400)`, **the screen showing eight numbers while the engine
  //          computes on four**. That is the class this project has one hard rule about: a wrong value
  //          is worse than an error.
  if (index < 0 || source[index] != '(') {
    return _sitsInsideVariadicCall(source, start);
  }
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

/// 中文：[start] 处那一组数字是不是坐在一个**可变形参调用**的括号里（任意实参位置）。
///
///       从表达式开头数到 [start]，最后那个还没配对的 `(` 就是包住它的那一个（数括号而不是回着找：
///       它前面可能隔着一整个带括号的实参，`atan2(root(8,3),1,234)` 那种）。再读回那一个 `(` 前面
///       的标识符——**同一个 [_variadicFunctions]，没有第二份表**——它是不是可变形参的函数。
///
///       数不到括号（`1,234` 这种光秃秃的千分位数字）时为假：那不是实参，是千分位。
///
/// English: whether the digit group at [start] sits inside a **variadic call's** brackets (in any
///          argument position).
///
///          Count from the start of the expression to [start]; the last `(` still unmatched is the one
///          enclosing it (counting brackets rather than walking back is deliberate: a whole bracketed
///          argument may sit in between, as in `atan2(root(8,3),1,234)`). Then read the identifier
///          before that `(` — **the same [_variadicFunctions], no second table** — and ask whether it
///          is a variadic function.
///
///          No bracket at all (`1,234`, a bare thousands-grouped number) is false: that is not an
///          argument, it is a thousands separator.
bool _sitsInsideVariadicCall(String source, int start) {
  var depth = 0;
  var openAt = -1;
  for (var i = 0; i < start; i++) {
    if (source[i] == '(') {
      depth++;
      openAt = i;
    } else if (source[i] == ')') {
      depth--;
    }
  }
  if (depth <= 0 || openAt < 0) return false;
  var index = openAt - 1;
  while (index >= 0 && source[index].trim().isEmpty) {
    index--;
  }
  final nameEnd = index + 1;
  while (index >= 0 && RegExp(r'[A-Za-z0-9]').hasMatch(source[index])) {
    index--;
  }
  if (nameEnd == index + 1) return false;
  return _variadicFunctions
      .contains(ExpressionParser.canonicalFunctionName(source.substring(index + 1, nameEnd)));
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

/// 中文：**度数记号：`30°` 是一个「角度」，而本应用把角度的数值写在当前的角度单位下。**
///
///       `30°` 从来不是 30，也不是恒定的一个数：它是「30 度」这个角度。本应用里每一个角度数值
///       都写在当前角度单位下——三角函数的实参这样读（DEG 下 `sin(30)` = 0.5），反三角函数的
///       返回值也这样给（DEG 下 `asin(0.5)` = 30，RAD 下 = 0.5235987755982988）。所以
///       `30°` 在 **DEG 下是 30**、**RAD 下是 0.5235987755982988**，而 `sin(30°)` 两边都是
///       **0.5**。参考实现（宿主 `qalc` 5.12.0，`-set "angle deg"` 与 `-set "angle rad"` 各测一次）
///       的 `sin(30°)`/`sin(90°)`/`tan(45°)` 是 0.5/1/1，两种角度模式下逐条相同。
///
///       **修复前这里是一个错值，而且只在 DEG 下错**（设备 `d87f1aa3`；改写原文是
///       `'rad(${match.group(1)})'`）：`rad` 是「度 → 弧度」换算、与模式无关，恒给
///       0.5235987755982988，而 DEG 的三角函数**再乘一次 π/180**——同一个角度被换算两次。
///       实测：`sin(30°)` = 0.009138395397176044、`sin(90°)` = 0.02741213359204429、
///       `tan(45°)` = 0.013708642534394055（RAD 下这三条是 0.5/0.9999999999999999/1，
///       因为那一边只换算一次）。
///
///       **为什么写成一个名字 `degangle(N)`，而不是「按模式改写成 `N` 或 `rad(N)`」。**
///       按模式改写文本，等于让这份归一化带一个角度模式参数；而它的消费者有七个
///       （`ExpressionParser` 构造函数、翻译器 `engineExpressionFor`、名字层
///       `canRead`/`canExpress`、`variable_references`、图形标签 `graph_models`、持久化），
///       它们看到的必须是**同一个字符串**——那是修复轮 8 与 9 的全部内容。模式一旦进了这一层，
///       七个调用点每一个都要选一个模式，而选错的那一个会让「谁看到了什么」不再一致；
///       引擎那条路更危险：RAD 文本含 `rad`（翻译器拒绝，于是引擎一次都不被问），DEG 文本
///       却是 `sin(30)`（翻译得过去）——同一句输入因此按模式走两个完全不同的权威。
///       定名法把模式留在它本来就在的地方：[ExpressionParser.degreeMode]。**文本不随模式变化**，
///       七个消费者一个字节都不改，而 `°` 的值由求值器按模式给出（`expression_parser.dart`
///       里 `degangle` 那一支）。
///
///       **`degangle` 是应用自己语言里的一个名字，不是给用户按的函数。** 键位插不出它，
///       引擎没有它的写法（词表那一行是 `engineKnowsThisName: false`），所以含 `°` 的表达式
///       照旧**一次都不会送去让引擎猜**——与修复前逐字相同的那条路（那条端到端实测在
///       `test/domain/calculator_engine_name_layer_test.dart`）。
///
///       同一个函数里别的改写都不是这个形状：`%`、上下标、根号、LaTeX、千分位全都只产出
///       **纯算术**，`degreeMode` 对它们没有任何影响——只有这一个产出的东西带着「角度」这个量纲。
/// English: **the degree mark: `30°` is an *angle*, and this app writes an angle's value in the
///          current angle unit.**
///
///          `30°` is never the number 30, nor is it one fixed number: it is the angle "30 degrees".
///          Every angle value in this app is written in the current angle unit — trig reads its
///          argument that way (`sin(30)` = 0.5 under DEG) and inverse trig returns that way
///          (`asin(0.5)` = 30 under DEG, 0.5235987755982988 under RAD). So `30°` is **30 under DEG**
///          and **0.5235987755982988 under RAD**, while `sin(30°)` is **0.5** in both. The reference
///          (host `qalc` 5.12.0, measured once with `-set "angle deg"` and once with
///          `-set "angle rad"`) gives 0.5/1/1 for `sin(30°)`/`sin(90°)`/`tan(45°)`, the same in both
///          angle modes.
///
///          **Before this fix there was a wrong value here, and only under DEG** (device `d87f1aa3`;
///          the rewrite used to read `'rad(${match.group(1)})'`): `rad` is a degrees → radians
///          conversion, independent of the mode, always 0.5235987755982988 — and DEG's trig
///          multiplies **again** by π/180, converting one angle twice. Measured: `sin(30°)` =
///          0.009138395397176044, `sin(90°)` = 0.02741213359204429, `tan(45°)` =
///          0.013708642534394055 (under RAD those three are 0.5 / 0.9999999999999999 / 1, because
///          that side converts once).
///
///          **Why one name, `degangle(N)`, rather than rewriting the text as `N` or `rad(N)` by
///          mode.** Rewriting the text by mode would mean handing this normalisation an angle-mode
///          parameter, and it has seven consumers (`ExpressionParser`'s constructor, the translator
///          `engineExpressionFor`, the name layer `canRead`/`canExpress`, `variable_references`, the
///          graph label `graph_models`, persistence) that must all see **one string** — which is the
///          whole content of fix rounds 8 and 9. With the mode inside this layer every one of the
///          seven call sites has to pick a mode, and the one that picks wrong makes "who saw what"
///          disagree. The engine route is the sharper hazard: the RAD text contains `rad` (the
///          translator refuses it, so the engine is never asked) while the DEG text is `sin(30)`
///          (which translates) — one input would travel to two different authorities depending on a
///          setting. Naming keeps the mode where it already lives: [ExpressionParser.degreeMode].
///          **The text does not vary with the mode**, no consumer changes a byte, and the value of
///          `°` is given by the evaluator (the `degangle` arm in `expression_parser.dart`).
///
///          **`degangle` is a name in this app's own language, not a function to press.** No key
///          inserts it and the engine has no spelling for it (its vocabulary row is
///          `engineKnowsThisName: false`), so an expression containing `°` is still **never sent to
///          the engine to guess at** — the very same route as before the fix (the end-to-end
///          measurement is in `test/domain/calculator_engine_name_layer_test.dart`).
///
///          No other rewrite in this function has that shape: `%`, superscripts, roots, LaTeX and
///          digit grouping all produce **plain arithmetic**, and `degreeMode` has nothing to say
///          about any of them — this is the only one whose product carries the dimension "angle".
String _replaceDegreeSign(String source) {
  return source.replaceAllMapped(
    RegExp(r'(?<![a-z0-9_.])(\d+(?:\.\d+)?)°'),
    (match) => 'degangle(${match.group(1)})',
  );
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
