import 'dart:math' as math;

class ExpressionParser {
  ExpressionParser(this.source, {required this.degreeMode})
      : text = source.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('π', 'pi');

  final String source;
  final String text;
  final bool degreeMode;
  int _index = 0;

  double parse() {
    final value = _parseExpression();
    _skipSpaces();
    if (_index != text.length) throw FormatException('Unexpected token at $_index');
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
      if (!_match(')')) throw const FormatException('Missing )');
      final angle = degreeMode ? arg * math.pi / 180 : arg;
      return switch (name) {
        'sin' => math.sin(angle),
        'cos' => math.cos(angle),
        'tan' => math.tan(angle),
        'asin' => degreeMode ? math.asin(arg) * 180 / math.pi : math.asin(arg),
        'acos' => degreeMode ? math.acos(arg) * 180 / math.pi : math.acos(arg),
        'atan' => degreeMode ? math.atan(arg) * 180 / math.pi : math.atan(arg),
        'sqrt' => math.sqrt(arg),
        'ln' => math.log(arg),
        'log' => math.log(arg) / math.ln10,
        'exp' => math.exp(arg),
        'abs' => arg.abs(),
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
      if (_index < text.length && (text[_index] == '+' || text[_index] == '-')) _index++;
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
    while (_index < text.length && RegExp(r'[A-Za-z]').hasMatch(text[_index])) {
      _index++;
    }
    return text.substring(start, _index);
  }

  bool _peekLetter() => _index < text.length && RegExp(r'[A-Za-z]').hasMatch(text[_index]);

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
}
