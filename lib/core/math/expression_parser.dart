import 'dart:math' as math;

class ExpressionParser {
  ExpressionParser(this.source, {required this.degreeMode})
      : text = source
            .replaceAll('×', '*')
            .replaceAll('÷', '/')
            .replaceAll('π', 'pi');

  final String source;
  final String text;
  final bool degreeMode;
  int _index = 0;

  double parse() {
    final value = _parseExpression();
    _skipSpaces();
    if (_index != text.length) {
      throw FormatException('Unexpected token at $_index');
    }
    return value;
  }

  double _parseExpression() {
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
    var value = _parsePower();
    while (true) {
      if (_match('*')) {
        value *= _parsePower();
      } else if (_match('/')) {
        value /= _parsePower();
      } else {
        return value;
      }
    }
  }

  double _parsePower() {
    var value = _parseUnary();
    if (_match('^')) value = math.pow(value, _parsePower()).toDouble();
    return value;
  }

  double _parseUnary() {
    if (_match('+')) return _parseUnary();
    if (_match('-')) return -_parseUnary();
    return _parsePrimary();
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
      if (!_match('(')) throw FormatException('Function $name needs (');
      final arg = _parseExpression();
      double? secondArg;
      if (_match(',')) {
        secondArg = _parseExpression();
      }
      if (!_match(')')) throw const FormatException('Missing )');
      final angle = degreeMode ? arg * math.pi / 180 : arg;
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
        'min' => secondArg == null ? arg : math.min(arg, secondArg),
        'max' => secondArg == null ? arg : math.max(arg, secondArg),
        'mod' => secondArg == null ? arg : arg % secondArg,
        'ncr' => secondArg == null ? arg : _combination(arg, secondArg),
        'npr' => secondArg == null ? arg : _permutation(arg, secondArg),
        'gcd' => secondArg == null ? arg : _gcd(arg, secondArg),
        'lcm' => secondArg == null ? arg : _lcm(arg, secondArg),
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
    final start = _index;
    while (_index < text.length && RegExp(r'[0-9.]').hasMatch(text[_index])) {
      _index++;
    }
    if (_index < text.length && (text[_index] == 'e' || text[_index] == 'E')) {
      final exponentStart = _index;
      _index++;
      if (_index < text.length &&
          (text[_index] == '+' || text[_index] == '-')) {
        _index++;
      }
      final digitsStart = _index;
      while (_index < text.length && RegExp(r'[0-9]').hasMatch(text[_index])) {
        _index++;
      }
      if (digitsStart == _index) _index = exponentStart;
    }
    if (start == _index) throw FormatException('Expected number at $_index');
    return double.parse(text.substring(start, _index));
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
}
