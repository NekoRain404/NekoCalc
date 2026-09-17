part of 'tool_unit_conversion.dart';

bool _supportsPrefixUnitNotation(String alias) {
  return const {
    '¥',
    '￥',
    '元',
    'cny',
    'rmb',
    '人民币',
    'yuan',
    'yuans',
  }.contains(alias);
}


double? _convertCompoundUnitValue(
  double value,
  String sourceToken,
  String targetToken,
) {
  for (final group in _compoundUnitGroups) {
    final sourceFactor = group[sourceToken];
    final targetFactor = group[targetToken];
    if (sourceFactor != null && targetFactor != null) {
      return value * sourceFactor / targetFactor;
    }
  }
  return null;
}

double? _convertDecibelPowerValue(
  double value,
  String sourceToken,
  String targetToken,
) {
  if (targetToken == 'dbm') {
    final watts = _wattsFromPowerToken(value, sourceToken);
    return watts == null || watts <= 0
        ? null
        : 10 * math.log(watts * 1000) / math.ln10;
  }
  if (targetToken == 'dbw') {
    final watts = _wattsFromPowerToken(value, sourceToken);
    return watts == null || watts <= 0
        ? null
        : 10 * math.log(watts) / math.ln10;
  }
  final targetFactor = _powerFactorForToken(targetToken);
  if (targetFactor == null) return null;
  final watts = _wattsFromPowerToken(value, sourceToken);
  return watts == null ? null : watts / targetFactor;
}

double? _wattsFromPowerToken(double value, String sourceToken) {
  final factor = _powerFactorForToken(sourceToken);
  if (factor != null) return value * factor;
  return switch (sourceToken) {
    'dbm' => math.pow(10, value / 10).toDouble() / 1000,
    'dbw' => math.pow(10, value / 10).toDouble(),
    _ => null,
  };
}

double? _convertTemperatureValue(
  double value,
  String sourceToken,
  String targetToken,
) {
  final source = ToolUnitConversion.normalizeTemperatureToken(sourceToken);
  final target = ToolUnitConversion.normalizeTemperatureToken(targetToken);
  if (source == null || target == null) return null;
  const fahrenheitTokens = {'f', '℉'};
  final celsius = source == 'k'
      ? value - 273.15
      : source == 'r'
          ? value * 5 / 9 - 273.15
          : fahrenheitTokens.contains(source)
              ? (value - 32) * 5 / 9
              : value;
  return target == 'k'
      ? celsius + 273.15
      : target == 'r'
          ? (celsius + 273.15) * 9 / 5
          : fahrenheitTokens.contains(target)
              ? celsius * 9 / 5 + 32
              : celsius;
}


double? _parseResistanceMarking(String input) {
  final rCode = RegExp(r'^([0-9]+)r([0-9]*)$').firstMatch(input);
  if (rCode != null) {
    return _numberFromWholeFraction(rCode.group(1)!, rCode.group(2)!);
  }
  final prefixed = RegExp(r'^([0-9]+)([kmg])([0-9]*)$').firstMatch(input);
  if (prefixed == null) return null;
  final multiplier = switch (prefixed.group(2)!) {
    'k' => 1000.0,
    'm' => 1000000.0,
    'g' => 1000000000.0,
    _ => 1.0,
  };
  return _numberFromWholeFraction(prefixed.group(1)!, prefixed.group(3)!) *
      multiplier;
}

double? _parseCapacitanceMarking(String input) {
  final prefixed = RegExp(r'^([0-9]+)(p|n|u)([0-9]*)$').firstMatch(input);
  if (prefixed != null) {
    final multiplier = switch (prefixed.group(2)!) {
      'p' => 1e-12,
      'n' => 1e-9,
      'u' => 1e-6,
      _ => 1.0,
    };
    return _numberFromWholeFraction(prefixed.group(1)!, prefixed.group(3)!) *
        multiplier;
  }
  if (RegExp(r'^[0-9]{3}$').hasMatch(input)) {
    final significant = int.parse(input.substring(0, 2));
    final exponent = int.parse(input.substring(2));
    var picofarads = significant.toDouble();
    for (var i = 0; i < exponent; i++) {
      picofarads *= 10;
    }
    return picofarads * 1e-12;
  }
  return null;
}

double? _parseInductanceMarking(String input) {
  final prefixed = RegExp(r'^([0-9]+)(n|u|m)([0-9]*)$').firstMatch(input);
  if (prefixed != null) {
    final multiplier = switch (prefixed.group(2)!) {
      'n' => 1e-9,
      'u' => 1e-6,
      'm' => 1e-3,
      _ => 1.0,
    };
    return _numberFromWholeFraction(prefixed.group(1)!, prefixed.group(3)!) *
        multiplier;
  }
  final rCode = RegExp(r'^([0-9]+)r([0-9]*)$').firstMatch(input);
  if (rCode != null) {
    return _numberFromWholeFraction(rCode.group(1)!, rCode.group(2)!);
  }
  return null;
}

double _numberFromWholeFraction(String whole, String fraction) {
  final text = fraction.isEmpty ? whole : '$whole.$fraction';
  return double.parse(text);
}

bool _isResistanceToken(String token) {
  return const {
    'ohm',
    'microohm',
    'milliohm',
    'kohm',
    'mohm',
    'gohm',
    'r',
  }.contains(token);
}

bool _isCapacitanceToken(String token) {
  return const {'f', 'uf', 'nf', 'pf'}.contains(token);
}

bool _isInductanceToken(String token) {
  return const {'h', 'kh', 'mh', 'uh', 'nh', 'ph', 'megahenry'}
      .contains(token);
}

double? _resistanceFactorForToken(String token) {
  return const {
    'ohm': 1.0,
    'microohm': 0.000001,
    'milliohm': 0.001,
    'kohm': 1000.0,
    'mohm': 1000000.0,
    'gohm': 1000000000.0,
    'r': 1.0
  }[token];
}

double? _capacitanceFactorForToken(String token) {
  return const {
    'f': 1.0,
    'millifarad': 0.001,
    'uf': 0.000001,
    'nf': 0.000000001,
    'pf': 0.000000000001,
    'megafarad': 1000000.0,
  }[token];
}

double? _inductanceFactorForToken(String token) {
  return const {
    'h': 1.0,
    'kh': 1000.0,
    'mh': 0.001,
    'uh': 0.000001,
    'nh': 0.000000001,
    'ph': 0.000000000001,
    'megahenry': 1000000.0,
  }[token];
}

double? _powerFactorForToken(String token) {
  return const {
    'w': 1.0,
    'mw': 0.001,
    'kw': 1000.0,
    'megawatt': 1000000.0,
    'hp': 745.7,
  }[token];
}

