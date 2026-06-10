import 'dart:math' as math;

/// 中文：轻量级递归下降表达式解析器，覆盖计算器、图形和工具页共用的数学输入。
/// English: Lightweight recursive-descent parser shared by calculator, graphing, and tool math inputs.
class ExpressionParser {
  ExpressionParser(this.source, {required this.degreeMode})
      : text = normalizeExpressionInput(source);

  final String source;
  final String text;
  final bool degreeMode;
  int _index = 0;

  double parse() {
    // 中文：入口只接受完整表达式，防止 "1+2abc" 这类半成功解析被误认为有效。
    // English: The entry point requires full consumption so partially parsed input is not treated as valid.
    final value = _parseExpression();
    _skipSpaces();
    if (_index != text.length) {
      throw FormatException('Unexpected token at $_index');
    }
    return value;
  }

  double _parseExpression() {
    // 中文：表达式层只处理加减，优先级更高的乘除、幂和一元运算交给下层。
    // English: This level handles addition/subtraction; higher-precedence operations are delegated below.
    var value = _parseTerm();
    while (true) {
      if (_match('+')) {
        value += _parseTerm();
      } else if (_match('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    // 中文：乘除层保持左结合，符合日常计算器输入习惯。
    // English: Multiplication and division are left-associative, matching normal calculator behavior.
    var value = _parseUnary();
    while (true) {
      if (_match('*')) {
        value *= _parseUnary();
      } else if (_match('/')) {
        value /= _parseUnary();
      } else {
        return value;
      }
    }
  }

  double _parsePower() {
    // 中文：幂运算右结合，且优先级高于前缀负号，保证 -2^2 解析为 -(2^2)。
    // English: Power is right-associative and binds tighter than prefix minus, so -2^2 parses as -(2^2).
    var value = _parsePostfix();
    if (_match('^')) value = math.pow(value, _parseUnary()).toDouble();
    return value;
  }

  double _parseUnary() {
    if (_match('+')) return _parseUnary();
    if (_match('-')) return -_parseUnary();
    return _parsePower();
  }

  double _parsePostfix() {
    var value = _parsePrimary();
    while (true) {
      if (_match('!')) {
        value = _factorial(value);
      } else {
        return value;
      }
    }
  }

  double _parsePrimary() {
    _skipSpaces();
    if (_match('(')) {
      final value = _parseExpression();
      if (!_match(')')) throw const FormatException('Missing )');
      return value;
    }
    if (_peekLetter()) {
      final name = _readName();
      if (name == 'pi') return math.pi;
      if (name == 'e') return math.e;
      if (name == 'tau') return math.pi * 2;
      if (name == 'phi') return (1 + math.sqrt(5)) / 2;
      if (name == 'inf' || name == 'infinity') return double.infinity;
      // 中文：函数统一要求括号，便于光标编辑、自动补括号和图形表达式复用。
      // English: Functions consistently require parentheses, which keeps cursor editing and graph reuse predictable.
      if (!_match('(')) throw FormatException('Function $name needs (');
      final args = <double>[];
      if (!_check(')')) {
        do {
          args.add(_parseExpression());
        } while (_match(','));
      }
      if (!_match(')')) throw const FormatException('Missing )');
      _validateFunctionArity(name, args);
      final arg = args.isEmpty ? 0.0 : args.first;
      final secondArg = args.length >= 2 ? args[1] : null;
      final angle = degreeMode ? arg * math.pi / 180 : arg;
      // 中文：三角函数在这里集中做角度制转换，其他函数始终按纯数值处理。
      // English: Trigonometric functions centralize degree/radian conversion here; other functions stay numeric.
      return switch (name) {
        'sin' => math.sin(angle),
        'cos' => math.cos(angle),
        'tan' => math.tan(angle),
        'cot' => 1 / math.tan(angle),
        'sec' => 1 / math.cos(angle),
        'csc' => 1 / math.sin(angle),
        'asin' => degreeMode ? math.asin(arg) * 180 / math.pi : math.asin(arg),
        'acos' => degreeMode ? math.acos(arg) * 180 / math.pi : math.acos(arg),
        'atan' => degreeMode ? math.atan(arg) * 180 / math.pi : math.atan(arg),
        'sinh' => (math.exp(arg) - math.exp(-arg)) / 2,
        'cosh' => (math.exp(arg) + math.exp(-arg)) / 2,
        'tanh' =>
          (math.exp(arg) - math.exp(-arg)) / (math.exp(arg) + math.exp(-arg)),
        'sqrt' => math.sqrt(arg),
        'cbrt' => arg < 0
            ? -math.pow(-arg, 1 / 3).toDouble()
            : math.pow(arg, 1 / 3).toDouble(),
        'ln' => math.log(arg),
        'log' => math.log(arg) / math.ln10,
        'log2' => math.log(arg) / math.ln2,
        'exp' => math.exp(arg),
        'abs' => arg.abs(),
        'floor' => arg.floorToDouble(),
        'ceil' => arg.ceilToDouble(),
        'round' => arg.roundToDouble(),
        'fact' => _factorial(arg),
        'deg' => arg * 180 / math.pi,
        'rad' => arg * math.pi / 180,
        'min' => _min(args),
        'max' => _max(args),
        'mod' => secondArg == null ? arg : arg % secondArg,
        'ncr' => secondArg == null ? arg : _combination(arg, secondArg),
        'npr' => secondArg == null ? arg : _permutation(arg, secondArg),
        'gcd' => _gcdMany(args),
        'lcm' => _lcmMany(args),
        'root' => secondArg == null ? arg : _root(arg, secondArg),
        'atan2' => secondArg == null
            ? (degreeMode ? math.atan(arg) * 180 / math.pi : math.atan(arg))
            : (degreeMode
                ? math.atan2(arg, secondArg) * 180 / math.pi
                : math.atan2(arg, secondArg)),
        _ => throw FormatException('Unknown function $name'),
      };
    }
    return _readNumber();
  }

  double _readNumber() {
    _skipSpaces();
    final radixValue = _readRadixNumber();
    if (radixValue != null) return radixValue;

    final start = _index;
    final number = StringBuffer();
    var hasDigit = false;
    var lastWasDigit = false;
    var dotSeen = false;
    while (_index < text.length) {
      final char = text[_index];
      if (_isDecimalDigit(char)) {
        number.write(char);
        hasDigit = true;
        lastWasDigit = true;
        _index++;
        continue;
      }
      if (char == '_') {
        if (!lastWasDigit || !_hasDecimalDigitAt(_index + 1)) break;
        lastWasDigit = false;
        _index++;
        continue;
      }
      if (char == '.' && !dotSeen) {
        number.write(char);
        dotSeen = true;
        lastWasDigit = false;
        _index++;
        continue;
      }
      break;
    }
    if (_index < text.length && (text[_index] == 'e' || text[_index] == 'E')) {
      // 中文：科学计数法只有在指数部分存在数字时才确认消费，避免把常数 e 误吞掉。
      // English: Scientific notation is consumed only when exponent digits exist, avoiding accidental capture of constant e.
      final exponentStart = _index;
      final exponent = StringBuffer();
      _index++;
      exponent.write('e');
      if (_index < text.length &&
          (text[_index] == '+' || text[_index] == '-')) {
        exponent.write(text[_index]);
        _index++;
      }
      var exponentDigits = 0;
      var lastExponentWasDigit = false;
      while (_index < text.length) {
        final char = text[_index];
        if (_isDecimalDigit(char)) {
          exponent.write(char);
          exponentDigits++;
          lastExponentWasDigit = true;
          _index++;
          continue;
        }
        if (char == '_') {
          if (!lastExponentWasDigit || !_hasDecimalDigitAt(_index + 1)) break;
          lastExponentWasDigit = false;
          _index++;
          continue;
        }
        break;
      }
      if (exponentDigits > 0) {
        number.write(exponent);
      } else {
        _index = exponentStart;
      }
    }
    if (start == _index || !hasDigit) {
      throw FormatException('Expected number at $_index');
    }
    return double.parse(number.toString());
  }

  double? _readRadixNumber() {
    if (_index + 2 > text.length || text[_index] != '0') return null;
    final prefix = text[_index + 1];
    final radix = switch (prefix) {
      'x' => 16,
      'b' => 2,
      'o' => 8,
      _ => null,
    };
    if (radix == null) return null;

    final start = _index;
    _index += 2;
    final digits = StringBuffer();
    var lastWasDigit = false;
    while (_index < text.length) {
      final char = text[_index];
      if (char == '_') {
        if (!lastWasDigit || _index + 1 >= text.length) break;
        final nextDigit = _digitValue(text[_index + 1]);
        if (nextDigit == null || nextDigit >= radix) break;
        lastWasDigit = false;
        _index++;
        continue;
      }
      final digit = _digitValue(char);
      if (digit == null || digit >= radix) break;
      digits.write(char);
      lastWasDigit = true;
      _index++;
    }
    if (digits.isEmpty) {
      _index = start;
      throw FormatException('Expected base-$radix digits at $_index');
    }
    return int.parse(digits.toString(), radix: radix).toDouble();
  }

  int? _digitValue(String char) {
    final code = char.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) return code - 0x30;
    if (code >= 0x61 && code <= 0x66) return code - 0x61 + 10;
    return null;
  }

  bool _isDecimalDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  bool _hasDecimalDigitAt(int index) {
    return index < text.length && _isDecimalDigit(text[index]);
  }

  String _readName() {
    final start = _index;
    while (
        _index < text.length && RegExp(r'[A-Za-z0-9]').hasMatch(text[_index])) {
      _index++;
    }
    return text.substring(start, _index);
  }

  bool _peekLetter() =>
      _index < text.length && RegExp(r'[A-Za-z]').hasMatch(text[_index]);

  bool _match(String token) {
    _skipSpaces();
    if (text.startsWith(token, _index)) {
      _index += token.length;
      return true;
    }
    return false;
  }

  bool _check(String token) {
    _skipSpaces();
    return text.startsWith(token, _index);
  }

  void _skipSpaces() {
    while (_index < text.length && text[_index].trim().isEmpty) {
      _index++;
    }
  }

  double _factorial(double value) {
    if (value < 0 || value > 170 || value % 1 != 0) {
      throw const FormatException('Factorial needs an integer from 0 to 170');
    }
    var result = 1.0;
    for (var i = 2; i <= value.toInt(); i++) {
      result *= i;
    }
    return result;
  }

  double _combination(double n, double r) {
    final ni = _readNonNegativeInteger(n, 'nCr n');
    final ri = _readNonNegativeInteger(r, 'nCr r');
    if (ri > ni) return 0;
    // 中文：组合数使用较小的 k 迭代，降低中间值增长速度并减少溢出风险。
    // English: nCr iterates with the smaller k to reduce intermediate growth and overflow risk.
    final k = math.min(ri, ni - ri);
    var result = 1.0;
    for (var i = 1; i <= k; i++) {
      result = result * (ni - k + i) / i;
    }
    return result;
  }

  double _permutation(double n, double r) {
    final ni = _readNonNegativeInteger(n, 'nPr n');
    final ri = _readNonNegativeInteger(r, 'nPr r');
    if (ri > ni) return 0;
    var result = 1.0;
    for (var i = 0; i < ri; i++) {
      result *= ni - i;
    }
    return result;
  }

  void _validateFunctionArity(String name, List<double> args) {
    if (const {'min', 'max', 'gcd', 'lcm'}.contains(name)) {
      if (args.isEmpty) throw FormatException('$name needs arguments');
      return;
    }
    if (const {'atan2', 'mod', 'ncr', 'npr', 'root'}.contains(name)) {
      if (args.isEmpty || args.length > 2) {
        throw FormatException('$name needs 1 or 2 arguments');
      }
      return;
    }
    if (args.length != 1) {
      throw FormatException('$name needs 1 argument');
    }
  }

  double _min(List<double> values) {
    if (values.isEmpty) throw const FormatException('min needs arguments');
    return values.reduce(math.min);
  }

  double _max(List<double> values) {
    if (values.isEmpty) throw const FormatException('max needs arguments');
    return values.reduce(math.max);
  }

  double _gcdMany(List<double> values) {
    if (values.isEmpty) throw const FormatException('gcd needs arguments');
    return values.skip(1).fold(values.first, _gcd);
  }

  double _lcmMany(List<double> values) {
    if (values.isEmpty) throw const FormatException('lcm needs arguments');
    return values.skip(1).fold(values.first, _lcm);
  }

  double _gcd(double a, double b) {
    var x = _readInteger(a, 'gcd a').abs();
    var y = _readInteger(b, 'gcd b').abs();
    while (y != 0) {
      final next = x % y;
      x = y;
      y = next;
    }
    return x.toDouble();
  }

  double _lcm(double a, double b) {
    final x = _readInteger(a, 'lcm a').abs();
    final y = _readInteger(b, 'lcm b').abs();
    if (x == 0 || y == 0) return 0;
    return (x ~/ _gcd(x.toDouble(), y.toDouble()).toInt() * y).toDouble();
  }

  double _root(double value, double degree) {
    if (degree == 0) throw const FormatException('Root degree cannot be 0');
    if (value < 0 && degree % 2 != 1) {
      throw const FormatException('Even root of negative number');
    }
    final magnitude = math.pow(value.abs(), 1 / degree).toDouble();
    return value < 0 ? -magnitude : magnitude;
  }

  int _readNonNegativeInteger(double value, String label) {
    final parsed = _readInteger(value, label);
    if (parsed < 0) throw FormatException('$label must be non-negative');
    return parsed;
  }

  int _readInteger(double value, String label) {
    if (value % 1 != 0) throw FormatException('$label must be an integer');
    if (value.abs() > 1000000000) throw FormatException('$label is too large');
    return value.toInt();
  }

  static String normalizeExpressionInput(String source) {
    final strippedSource = _stripPastedCalculationResult(source);
    var text = _normalizeGroupedNumberSeparators(_normalizeUnicodeFractions(
            _normalizeMathSubscripts(_normalizeFullWidthAscii(strippedSource))))
        .trim()
        .toLowerCase();
    text = _normalizeLatexExpression(text)
        .replaceAll('，', ',')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('［', '(')
        .replaceAll('］', ')')
        .replaceAll('【', '(')
        .replaceAll('】', ')')
        .replaceAll('−', '-')
        .replaceAll('－', '-')
        .replaceAll('＋', '+')
        .replaceAll('×', '*')
        .replaceAll('✕', '*')
        .replaceAll('∙', '*')
        .replaceAll('·', '*')
        .replaceAll('÷', '/')
        .replaceAll('／', '/')
        .replaceAll('π', 'pi')
        .replaceAll('τ', 'tau')
        .replaceAll('φ', 'phi')
        .replaceAll('ϕ', 'phi')
        .replaceAll('∞', 'infinity')
        .replaceAll('√', 'sqrt')
        .replaceAll('∛', 'cbrt')
        .replaceAll('％', '%');
    text = _normalizeFunctionAliases(text);
    text = _normalizeSuperscriptRoots(text);
    text = _normalizeSuperscriptExponents(text);
    text = _normalizeScientificNotation(text);
    text = _normalizeExponentialDisplay(text);
    text = _normalizeIndexedRoots(text);
    text = _normalizeAbsoluteValueBars(text);
    text = _normalizeBareUnaryFunctionCalls(text);
    text = _replacePercent(text);
    text = text.replaceAllMapped(
      RegExp(r'(sqrt|cbrt)((?:\d+(?:\.\d+)?)|pi|e)(?![a-z0-9_(])'),
      (match) => '${match.group(1)}(${match.group(2)})',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![a-z0-9_.])(\d+(?:\.\d+)?)°'),
      (match) => 'rad(${match.group(1)})',
    );
    text = text.replaceAllMapped(
      RegExp(
          '((?<![a-z])\\d|\\))(?=(\\(|$_leadingConstantPattern|$_functionPattern))'),
      (match) => '${match.group(1)}*',
    );
    text = text.replaceAllMapped(
      RegExp(
        '((?<![a-z0-9.])(?:$_constantPattern)|\\))(?=(\\d|\\(|$_leadingConstantPattern|$_functionPattern))',
      ),
      (match) => '${match.group(1)}*',
    );
    return text;
  }

  static String _stripPastedCalculationResult(String source) {
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

  static String? _labeledResultExpression(String line) {
    final match = RegExp(
      r'^(?:ans|answer|result|value|结果|答案|当前值)\s*[:：=]\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? _trailingResultAnnotationExpression(String line) {
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

  static bool _looksLikeCalculationExpression(String source) {
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

  static const String _constantPattern = 'infinity|inf|tau|phi|pi|e';
  static const String _leadingConstantPattern =
      'infinity|inf|tau|phi|pi|e(?![+-]?\\d)';
  static const String _functionPattern =
      'atan2|asin|acos|atan|sinh|cosh|tanh|sin|cos|tan|cot|sec|csc|sqrt|cbrt|log2|log|ln|abs|exp|floor|ceil|round|deg|rad|min|max|mod|ncr|npr|gcd|lcm|root|fact';
  static const String _bareUnaryFunctionPattern =
      'asin|acos|atan|sinh|cosh|tanh|sin|cos|tan|cot|sec|csc|sqrt|cbrt|log2|log|ln|abs|exp|floor|ceil|round|fact|deg|rad';
  static const String _decimalNumberPattern =
      r'(?:\d(?:_?\d)*(?:\.\d(?:_?\d)*)?|\.\d(?:_?\d)*)(?:e[+-]?\d(?:_?\d)*)?';
  static const String _radixNumberPattern =
      r'(?:0x[0-9a-f](?:_?[0-9a-f])*|0b[01](?:_?[01])*|0o[0-7](?:_?[0-7])*)';
  static const String _bareFunctionArgumentPattern =
      '(?:[+-]\\s*)?(?:(?:$_decimalNumberPattern)[%°]?|$_radixNumberPattern|(?:$_constantPattern))';

  static String _normalizeGroupedNumberSeparators(String source) {
    final pattern = RegExp(
        r'(?<![A-Za-z0-9_.])([+-]?\d{1,3}(?:,\d{3})+(?:\.\d+)?)(?![A-Za-z0-9_.])');
    return source.replaceAllMapped(
      pattern,
      (match) => _startsFunctionArgument(source, match.start)
          ? match.group(1)!
          : match.group(1)!.replaceAll(',', ''),
    );
  }

  static bool _startsFunctionArgument(String source, int start) {
    var index = start - 1;
    while (index >= 0 && source[index].trim().isEmpty) {
      index--;
    }
    if (index < 0 || source[index] != '(') return false;
    index--;
    while (index >= 0 && source[index].trim().isEmpty) {
      index--;
    }
    return index >= 0 && RegExp(r'[A-Za-z)]').hasMatch(source[index]);
  }

  static String _normalizeFunctionAliases(String source) {
    return source
        .replaceAllMapped(RegExp(r'\barcsin\b'), (_) => 'asin')
        .replaceAllMapped(RegExp(r'\barccos\b'), (_) => 'acos')
        .replaceAllMapped(RegExp(r'\barctan\b'), (_) => 'atan')
        .replaceAllMapped(RegExp(r'\blog10\b'), (_) => 'log')
        .replaceAllMapped(RegExp(r'\blg\b'), (_) => 'log')
        .replaceAllMapped(RegExp(r'\bc(?=\s*\()'), (_) => 'ncr')
        .replaceAllMapped(RegExp(r'\bp(?=\s*\()'), (_) => 'npr');
  }

  static String _normalizeBareUnaryFunctionCalls(String source) {
    final pattern = RegExp(
      '\\b($_bareUnaryFunctionPattern)\\s+($_bareFunctionArgumentPattern)(?![a-z0-9_.])',
    );
    return source.replaceAllMapped(pattern, (match) {
      final argument = match.group(2)!.replaceAll(RegExp(r'\s+'), '');
      return '${match.group(1)}($argument)';
    });
  }

  static String _normalizeLatexExpression(String source) {
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

  static String _normalizeLatexFractions(String source) {
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

  static String _normalizeLatexSquareRoots(String source) {
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

  static String _normalizeLatexCommands(String source) {
    return source
        .replaceAllMapped(
          RegExp(
              r'\\(arcsin|arccos|arctan|atan2|sinh|cosh|tanh|sin|cos|tan|cot|sec|csc|sqrt|cbrt|ln|log|lg|abs|exp|floor|ceil|round|deg|rad|min|max|mod|ncr|npr|gcd|lcm|root|fact)\b'),
          (match) => match.group(1)!,
        )
        .replaceAllMapped(RegExp(r'\\operatorname\s*\{([a-z]+)\}'),
            (match) => match.group(1)!);
  }

  static String _normalizeLatexWrappedFunctionCalls(String source) {
    const functions =
        'arcsin|arccos|arctan|atan2|sinh|cosh|tanh|sin|cos|tan|cot|sec|csc|sqrt|cbrt|ln|log|lg|abs|exp|floor|ceil|round|deg|rad|min|max|mod|ncr|npr|gcd|lcm|root|fact';
    return source.replaceAllMapped(
      RegExp('\\b($functions)\\s*\\{\\s*\\(([^{}]*)\\)\\s*\\}'),
      (match) => '${match.group(1)}(${match.group(2)})',
    );
  }

  static _LatexGroup? _consumeLatexGroup(
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

  static String _normalizeUnicodeFractions(String source) {
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

  static String _unicodeFractionExpression(String text) {
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

  static String _normalizeExponentialDisplay(String source) {
    return source.replaceAllMapped(
      RegExp(r'\be\^\(((?:[^()]|\([^()]*\))+)\)'),
      (match) => 'exp(${match.group(1)})',
    );
  }

  static String _normalizeSuperscriptRoots(String source) {
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

  static String _normalizeIndexedRoots(String source) {
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

  static String _normalizeAbsoluteValueBars(String source) {
    var text = source;
    final pattern = RegExp(r'\|([^|]+)\|');
    while (pattern.hasMatch(text)) {
      text =
          text.replaceAllMapped(pattern, (match) => 'abs(${match.group(1)})');
    }
    return text;
  }

  static String _replacePercent(String source) {
    var text = source;
    final pattern = RegExp('(($_decimalNumberPattern)|\\([^()]+\\))%');
    while (pattern.hasMatch(text)) {
      text =
          text.replaceAllMapped(pattern, (match) => '(${match.group(1)})/100');
    }
    return text;
  }

  static String _normalizeScientificNotation(String source) {
    return source.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?|\.\d+)\s*(?:\*|x)\s*10\^([+-]?\d+)'),
      (match) => '${match.group(1)}e${match.group(2)}',
    );
  }

  static String _normalizeSuperscriptExponents(String source) {
    return source.replaceAllMapped(
      RegExp(r'[⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻]+'),
      (match) => '^${_decodeSuperscript(match.group(0)!)}',
    );
  }

  static String _decodeSuperscript(String source) {
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

  static String _normalizeMathSubscripts(String source) {
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

  static String _normalizeFullWidthAscii(String source) {
    return source.runes.map((code) {
      if (code >= 0xff01 && code <= 0xff5e) {
        return String.fromCharCode(code - 0xfee0);
      }
      return String.fromCharCode(code);
    }).join();
  }
}

class _LatexGroup {
  const _LatexGroup(this.value, this.end);

  final String value;
  final int end;
}
