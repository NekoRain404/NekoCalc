/// Returns the previous token boundary before [offset].
int previousExpressionBoundary(String value, int offset) {
  final cursor = offset.clamp(0, value.length).toInt();
  if (cursor == 0) return 0;
  if (!_hasBalancedParentheses(value)) {
    return _previousCodePointBoundary(value, cursor);
  }

  final groupStart = _matchingGroupStart(value, cursor);
  if (groupStart != null) {
    return _identifierStartBefore(value, groupStart) ?? groupStart;
  }

  final numericStart = _numericLiteralStartEndingAt(value, cursor);
  return numericStart ?? _previousCodePointBoundary(value, cursor);
}

/// Returns the next token boundary after [offset].
int nextExpressionBoundary(String value, int offset) {
  final cursor = offset.clamp(0, value.length).toInt();
  if (cursor == value.length) return value.length;
  if (!_hasBalancedParentheses(value)) {
    return _nextCodePointBoundary(value, cursor);
  }

  if (_isIdentifierStartAt(value, cursor) &&
      (cursor == 0 || !_isIdentifierStartAt(value, cursor - 1))) {
    var identifierEnd = cursor + 1;
    while (identifierEnd < value.length &&
        _isIdentifierPartAt(value, identifierEnd)) {
      identifierEnd++;
    }
    final groupEnd = _matchingGroupEnd(value, identifierEnd);
    if (groupEnd != null) return groupEnd + 1;
  }

  final groupEnd = _matchingGroupEnd(value, cursor);
  if (groupEnd != null) return groupEnd + 1;

  final numericEnd = _numericLiteralEndAt(value, cursor);
  return numericEnd ?? _nextCodePointBoundary(value, cursor);
}

int? _matchingGroupStart(String value, int end) {
  if (end == 0 || value.codeUnitAt(end - 1) != 41) return null;
  var depth = 0;
  for (var index = end - 1; index >= 0; index--) {
    final code = value.codeUnitAt(index);
    if (code == 41) {
      depth++;
    } else if (code == 40) {
      depth--;
      if (depth == 0) return index;
    }
  }
  return null;
}

int? _matchingGroupEnd(String value, int start) {
  if (start >= value.length || value.codeUnitAt(start) != 40) return null;
  var depth = 0;
  for (var index = start; index < value.length; index++) {
    final code = value.codeUnitAt(index);
    if (code == 40) {
      depth++;
    } else if (code == 41) {
      depth--;
      if (depth == 0) return index;
    }
  }
  return null;
}

bool _hasBalancedParentheses(String value) {
  var depth = 0;
  for (var index = 0; index < value.length; index++) {
    final code = value.codeUnitAt(index);
    if (code == 40) {
      depth++;
    } else if (code == 41) {
      depth--;
      if (depth < 0) return false;
    }
  }
  return depth == 0;
}

int? _identifierStartBefore(String value, int before) {
  var start = before;
  while (start > 0 && _isIdentifierPartAt(value, start - 1)) {
    start--;
  }
  for (var index = start; index < before; index++) {
    if (_isIdentifierStartAt(value, index)) return index;
  }
  return null;
}

int? _numericLiteralStartEndingAt(String value, int end) {
  var candidate = end;
  while (
      candidate > 0 && _isNumericCandidate(value.codeUnitAt(candidate - 1))) {
    candidate--;
  }
  for (var start = candidate; start < end; start++) {
    if (_numericLiteralEndAt(value, start) == end) return start;
  }
  return null;
}

int? _numericLiteralEndAt(String value, int start) {
  if (start >= value.length || !_isDecimalDigit(value.codeUnitAt(start))) {
    return null;
  }

  final radixEnd = _radixLiteralEndAt(value, start);
  if (radixEnd != null) return radixEnd;

  var index = start;
  var dotSeen = false;
  var lastWasDigit = false;
  while (index < value.length) {
    final code = value.codeUnitAt(index);
    if (_isDecimalDigit(code)) {
      lastWasDigit = true;
      index++;
      continue;
    }
    if (code == 95 &&
        lastWasDigit &&
        index + 1 < value.length &&
        _isDecimalDigit(value.codeUnitAt(index + 1))) {
      lastWasDigit = false;
      index++;
      continue;
    }
    if (code == 46 && !dotSeen) {
      dotSeen = true;
      lastWasDigit = false;
      index++;
      continue;
    }
    break;
  }

  if (index >= value.length ||
      (value.codeUnitAt(index) != 69 && value.codeUnitAt(index) != 101)) {
    return index;
  }

  final exponentStart = index;
  index++;
  if (index < value.length &&
      (value.codeUnitAt(index) == 43 || value.codeUnitAt(index) == 45)) {
    index++;
  }
  var exponentDigits = 0;
  var lastExponentWasDigit = false;
  while (index < value.length) {
    final code = value.codeUnitAt(index);
    if (_isDecimalDigit(code)) {
      exponentDigits++;
      lastExponentWasDigit = true;
      index++;
      continue;
    }
    if (code == 95 &&
        lastExponentWasDigit &&
        index + 1 < value.length &&
        _isDecimalDigit(value.codeUnitAt(index + 1))) {
      lastExponentWasDigit = false;
      index++;
      continue;
    }
    break;
  }
  return exponentDigits > 0 ? index : exponentStart;
}

int? _radixLiteralEndAt(String value, int start) {
  if (start + 2 > value.length || value.codeUnitAt(start) != 48) return null;
  final radix = switch (value.codeUnitAt(start + 1)) {
    66 || 98 => 2,
    79 || 111 => 8,
    88 || 120 => 16,
    _ => null,
  };
  if (radix == null) return null;

  var index = start + 2;
  var hasDigit = false;
  var lastWasDigit = false;
  while (index < value.length) {
    final digit = _radixDigitValue(value.codeUnitAt(index));
    if (digit != null && digit < radix) {
      hasDigit = true;
      lastWasDigit = true;
      index++;
      continue;
    }
    if (value.codeUnitAt(index) == 95 &&
        lastWasDigit &&
        index + 1 < value.length) {
      final nextDigit = _radixDigitValue(value.codeUnitAt(index + 1));
      if (nextDigit != null && nextDigit < radix) {
        lastWasDigit = false;
        index++;
        continue;
      }
    }
    break;
  }
  return hasDigit ? index : null;
}

int _previousCodePointBoundary(String value, int offset) {
  final index = offset - 1;
  if (_isLowSurrogate(value.codeUnitAt(index)) &&
      index > 0 &&
      _isHighSurrogate(value.codeUnitAt(index - 1))) {
    return index - 1;
  }
  return index;
}

int _nextCodePointBoundary(String value, int offset) {
  final code = value.codeUnitAt(offset);
  if (_isLowSurrogate(code) &&
      offset > 0 &&
      _isHighSurrogate(value.codeUnitAt(offset - 1))) {
    return offset + 1;
  }
  if (_isHighSurrogate(code) &&
      offset + 1 < value.length &&
      _isLowSurrogate(value.codeUnitAt(offset + 1))) {
    return offset + 2;
  }
  return offset + 1;
}

bool _isIdentifierStartAt(String value, int index) {
  final code = value.codeUnitAt(index);
  return code == 95 ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122);
}

bool _isIdentifierPartAt(String value, int index) {
  return _isIdentifierStartAt(value, index) ||
      _isDecimalDigit(value.codeUnitAt(index));
}

bool _isNumericCandidate(int code) {
  return _isDecimalDigit(code) ||
      code == 43 ||
      code == 45 ||
      code == 46 ||
      code == 66 ||
      code == 69 ||
      code == 70 ||
      code == 79 ||
      code == 88 ||
      code == 95 ||
      (code >= 97 && code <= 102) ||
      code == 111 ||
      code == 120;
}

bool _isDecimalDigit(int code) => code >= 48 && code <= 57;

int? _radixDigitValue(int code) {
  if (_isDecimalDigit(code)) return code - 48;
  if (code >= 65 && code <= 70) return code - 65 + 10;
  if (code >= 97 && code <= 102) return code - 97 + 10;
  return null;
}

bool _isHighSurrogate(int code) => code >= 0xd800 && code <= 0xdbff;

bool _isLowSurrogate(int code) => code >= 0xdc00 && code <= 0xdfff;
