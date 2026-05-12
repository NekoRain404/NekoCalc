String formatExpressionForDisplay(String expression,
    {required bool mathSymbols}) {
  if (!mathSymbols || expression.isEmpty) return expression;

  final buffer = StringBuffer();
  var index = 0;
  while (index < expression.length) {
    final char = expression[index];
    if (_isIdentifierStart(char)) {
      final start = index;
      index++;
      while (
          index < expression.length && _isIdentifierPart(expression[index])) {
        index++;
      }
      final token = expression.substring(start, index);
      if (index < expression.length && expression[index] == '(') {
        final close = _matchingClose(expression, index);
        if (close != null) {
          final body = expression.substring(index + 1, close);
          final displayBody =
              formatExpressionForDisplay(body, mathSymbols: true);
          buffer.write(_functionCallForDisplay(token, displayBody));
          index = close + 1;
          continue;
        }
      }
      buffer.write(_symbolForToken(token));
      continue;
    }
    buffer.write(char);
    index++;
  }

  return _formatPowers(buffer.toString());
}

String _symbolForToken(String token) {
  return switch (token) {
    'pi' => 'π',
    _ => token,
  };
}

String _functionCallForDisplay(String name, String body) {
  return switch (name) {
    'sqrt' => '√($body)',
    'cbrt' => '∛($body)',
    'log' => 'log₁₀($body)',
    'log2' => 'log₂($body)',
    'exp' => 'e^($body)',
    'abs' => '|$body|',
    'fact' => '($body)!',
    'root' => _rootForDisplay(body),
    'ncr' => 'C($body)',
    'npr' => 'P($body)',
    'deg' => '$body°',
    _ => '$name($body)',
  };
}

String _rootForDisplay(String body) {
  final args = _splitTopLevelArgs(body);
  if (args.length != 2) return 'ⁿ√($body)';
  final radicand = args[0].trim();
  final index = args[1].trim();
  if (RegExp(r'^-?\d+$').hasMatch(index)) {
    return '${_toSuperscript(index)}√($radicand)';
  }
  return '√[$index]($radicand)';
}

List<String> _splitTopLevelArgs(String body) {
  final args = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < body.length; i++) {
    final char = body[i];
    if (char == '(') depth++;
    if (char == ')') depth--;
    if (char == ',' && depth == 0) {
      args.add(body.substring(start, i));
      start = i + 1;
    }
  }
  args.add(body.substring(start));
  return args;
}

int? _matchingClose(String source, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

String _formatPowers(String source) {
  return source.replaceAllMapped(RegExp(r'\^(-?\d+)'), (match) {
    final exponent = match.group(1)!;
    return _toSuperscript(exponent);
  });
}

String _toSuperscript(String value) {
  const chars = {
    '-': '⁻',
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
  };
  return value.split('').map((char) => chars[char] ?? char).join();
}

bool _isIdentifierStart(String char) {
  final code = char.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
}

bool _isIdentifierPart(String char) {
  final code = char.codeUnitAt(0);
  return _isIdentifierStart(char) || (code >= 48 && code <= 57);
}
