part of 'tool_detail_controller.dart';

NumericInputParseResult _parsePlainNumericInput(String normalized) {
  if (normalized.isEmpty) {
    return const NumericInputParseResult(value: null, error: '请输入数值');
  }
  if (normalized.endsWith('%')) {
    final value =
        double.tryParse(normalized.substring(0, normalized.length - 1));
    if (value != null) {
      return NumericInputParseResult(value: value / 100);
    }
  }
  final direct = double.tryParse(normalized);
  if (direct != null) return NumericInputParseResult(value: direct);
  try {
    final value = ExpressionParser(normalized, degreeMode: true).parse();
    if (!value.isFinite) {
      return const NumericInputParseResult(value: null, error: '结果不是有限数值');
    }
    return NumericInputParseResult(value: value);
  } catch (_) {
    return const NumericInputParseResult(value: null, error: '无法解析数值或表达式');
  }
}

NumericInputParseResult _parsePercentInput(String normalized) {
  final labeled = ToolUnitConversion.extractLabeledNumericCandidate(normalized);
  if (labeled != null) {
    final parsed = _parsePercentInput(ToolUnitConversion.normalizeNumericText(labeled));
    if (parsed.value != null) return parsed;
  }

  final nominal = ToolUnitConversion.extractNominalNumericCandidate(normalized);
  if (nominal != null && nominal != normalized) {
    final parsed = _parsePercentInput(ToolUnitConversion.normalizeNumericText(nominal));
    if (parsed.value != null) return parsed;
  }

  final compact = normalized.replaceAll(RegExp(r'\s+'), '');
  if (compact.endsWith('%')) {
    final value = ToolDetailController.parseNumericInputDetailed(
      compact.substring(0, compact.length - 1),
    ).value;
    if (value != null) return NumericInputParseResult(value: value);
  }
  return ToolDetailController.parseNumericInputDetailed(normalized);
}

NumericInputParseResult _parseNumericInputForUnitNormalized(
  String normalized,
  String targetUnit,
) {
  final wireGauge = _parseAwgInput(normalized, targetUnit);
  if (wireGauge != null) {
    return NumericInputParseResult(value: wireGauge);
  }

  final conductorArea = _parseConductorAreaInput(normalized, targetUnit);
  if (conductorArea != null) {
    return NumericInputParseResult(value: conductorArea);
  }

  final duration = _parseDurationInput(normalized, targetUnit);
  if (duration != null) {
    return NumericInputParseResult(value: duration);
  }

  final composite = ToolUnitConversion.parseCompositeUnitInput(normalized, targetUnit);
  if (composite != null) {
    return NumericInputParseResult(value: composite);
  }

  final range = _parseRangeInputForUnit(normalized, targetUnit);
  if (range != null) return range;

  final prefixedUnit = ToolUnitConversion.splitPrefixUnit(normalized, targetUnit);
  if (prefixedUnit != null) {
    final rangeValue = ToolUnitConversion.extractFirstRangeQuantity(
      prefixedUnit.valueText,
      unitRequiredForHyphen: false,
    );
    if (rangeValue != null) {
      final parsed = ToolDetailController.parseNumericInputDetailed(rangeValue);
      final value = parsed.value;
      if (value != null) {
        final converted =
            ToolUnitConversion.convertUnitValue(value, prefixedUnit.unitToken, targetUnit);
        if (converted != null) {
          return NumericInputParseResult(value: converted);
        }
      }
    }
    final parsed = ToolDetailController.parseNumericInputDetailed(prefixedUnit.valueText);
    final value = parsed.value;
    if (value == null) {
      return NumericInputParseResult(
        value: null,
        error: parsed.error ?? '无法解析数值或表达式',
      );
    }
    final converted =
        ToolUnitConversion.convertUnitValue(value, prefixedUnit.unitToken, targetUnit);
    if (converted == null) {
      return NumericInputParseResult(
        value: null,
        error: '单位 ${prefixedUnit.unitLabel} 与 $targetUnit 不匹配',
      );
    }
    return NumericInputParseResult(value: converted);
  }

  if (_looksLikeConductorAreaInput(normalized)) {
    return const NumericInputParseResult(value: null, error: '无法解析数值或表达式');
  }

  final unitSuffix = ToolUnitConversion.splitUnitSuffix(normalized, targetUnit);
  if (unitSuffix != null) {
    final rangeValue = ToolUnitConversion.extractFirstRangeQuantity(
      unitSuffix.valueText,
      unitRequiredForHyphen: false,
    );
    final parsed =
        ToolDetailController.parseNumericInputDetailed(rangeValue ?? unitSuffix.valueText);
    var value = parsed.value;
    if (value == null) {
      final nominal = ToolUnitConversion.extractNominalNumericCandidate(unitSuffix.valueText);
      if (nominal != null) {
        value = ToolDetailController.parseNumericInputDetailed(nominal).value;
      }
    }
    if (value == null) {
      return NumericInputParseResult(
        value: null,
        error: parsed.error ?? '无法解析数值或表达式',
      );
    }
    final converted =
        ToolUnitConversion.convertUnitValue(value, unitSuffix.unitToken, targetUnit);
    if (converted == null) {
      return NumericInputParseResult(
        value: null,
        error: '单位 ${unitSuffix.unitLabel} 与 $targetUnit 不匹配',
      );
    }
    return NumericInputParseResult(value: converted);
  }

  final componentMarking =
      ToolUnitConversion.parseComponentMarking(normalized, ToolUnitConversion.normalizeUnitToken(targetUnit));
  if (componentMarking != null) {
    return NumericInputParseResult(value: componentMarking);
  }

  final nominal = ToolUnitConversion.extractNominalNumericCandidate(normalized);
  if (nominal != null) {
    final nominalParsed =
        _parseNumericInputForUnitNormalized(nominal, targetUnit);
    if (nominalParsed.value != null) return nominalParsed;
  }

  final mismatchedUnit = ToolUnitConversion.splitAnyKnownUnitSuffix(normalized);
  if (mismatchedUnit != null) {
    return NumericInputParseResult(
      value: null,
      error: '单位 ${mismatchedUnit.unitLabel} 与 $targetUnit 不匹配',
    );
  }
  return ToolDetailController.parseNumericInputDetailed(normalized);
}

NumericInputParseResult? _parseRangeInputForUnit(
  String input,
  String targetUnit,
) {
  final firstQuantity = ToolUnitConversion.extractFirstRangeQuantity(input);
  if (firstQuantity == null) return null;
  final normalizedFirst = ToolUnitConversion.normalizeNumericText(firstQuantity);
  if (normalizedFirst == input) return null;
  final parsed = _parseNumericInputForUnitNormalized(
    normalizedFirst,
    targetUnit,
  );
  return parsed.value == null ? null : parsed;
}

double? _parseAwgInput(String input, String targetUnit) {
  final targetToken = ToolUnitConversion.normalizeUnitToken(targetUnit);
  if (!_isAreaToken(targetToken)) return null;
  final compact = ToolUnitConversion.normalizeUnitText(input).replaceAll(RegExp(r'\s+'), '');
  final match =
      RegExp(r'^(?:awg|#)?([0-9]{1,2})(?:awg)?$').firstMatch(compact);
  if (match == null) return null;
  final gauge = int.tryParse(match.group(1)!);
  if (gauge == null || gauge > 40) return null;
  final diameterMm = 0.127 * math.pow(92, (36 - gauge) / 39);
  final areaMm2 = math.pi * diameterMm * diameterMm / 4;
  return _convertAreaMm2ToTarget(areaMm2, targetToken);
}

double? _parseConductorAreaInput(String input, String targetUnit) {
  final targetToken = ToolUnitConversion.normalizeUnitToken(targetUnit);
  if (!_isAreaToken(targetToken)) return null;
  final compact = _normalizeConductorAreaText(input);
  final strandedArea = _parseStrandedWireAreaMm2(compact);
  if (strandedArea != null) {
    return _convertAreaMm2ToTarget(strandedArea, targetToken);
  }
  final circularArea = _parseCircularAreaMm2(compact);
  if (circularArea != null) {
    return _convertAreaMm2ToTarget(circularArea, targetToken);
  }
  return null;
}

bool _looksLikeConductorAreaInput(String input) {
  final compact = _normalizeConductorAreaText(input);
  if (compact.startsWith('diameter') || compact.startsWith('radius')) {
    return true;
  }
  final stranded =
      RegExp(r'^([1-9][0-9]{0,4})([/x*])(?:diameter|diam|dia|d)?(.+)$')
          .firstMatch(compact);
  if (stranded == null) return false;
  return _parseLengthQuantityToMillimeters(stranded.group(3)!.trim()) != null;
}

String _normalizeConductorAreaText(String input) {
  return ToolUnitConversion.normalizeUnitText(input)
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('×', 'x')
      .replaceAll('直径', 'diameter')
      .replaceAll('直徑', 'diameter')
      .replaceAll('线径', 'diameter')
      .replaceAll('線徑', 'diameter')
      .replaceAll('半径', 'radius')
      .replaceAll('半徑', 'radius')
      .replaceAll('φ', 'diameter')
      .replaceAll('ø', 'diameter')
      .replaceAll('股', 'x')
      .replaceAll('根', 'x')
      .replaceAll('芯', 'x');
}

double? _parseStrandedWireAreaMm2(String input) {
  final match =
      RegExp(r'^([1-9][0-9]{0,4})([/x*])(?:diameter|diam|dia|d)?(.+)$')
          .firstMatch(input);
  if (match == null) return null;
  final strands = int.tryParse(match.group(1)!);
  if (strands == null) return null;
  final diameter = _parseLengthQuantityToMillimeters(match.group(3)!.trim());
  if (diameter == null || diameter < 0) return null;
  return strands * math.pi * diameter * diameter / 4;
}

double? _parseCircularAreaMm2(String input) {
  final diameterPrefix =
      RegExp(r'^(?:diameter|diam|dia|d)[:=]?(.+)$').firstMatch(input);
  if (diameterPrefix != null) {
    final diameter = _parseLengthQuantityToMillimeters(
      diameterPrefix.group(1)!,
      allowBareMillimeters: true,
    );
    if (diameter == null || diameter < 0) return null;
    return math.pi * diameter * diameter / 4;
  }

  final radiusPrefix =
      RegExp(r'^(?:radius|rad|r)[:=]?(.+)$').firstMatch(input);
  if (radiusPrefix != null) {
    final radius = _parseLengthQuantityToMillimeters(
      radiusPrefix.group(1)!,
      allowBareMillimeters: true,
    );
    if (radius == null || radius < 0) return null;
    return math.pi * radius * radius;
  }
  return null;
}

double? _parseLengthQuantityToMillimeters(
  String input, {
  bool allowBareMillimeters = false,
}) {
  final compact = ToolUnitConversion.normalizeUnitText(input).replaceAll(RegExp(r'\s+'), '');
  final suffix = ToolUnitConversion.splitByAliases(compact, ToolUnitConversion.lengthUnitAliases);
  if (suffix != null) {
    final parsed = ToolDetailController.parseNumericInputDetailed(suffix.valueText);
    final value = parsed.value;
    if (value == null) return null;
    return ToolUnitConversion.convertUnitValue(value, suffix.unitToken, 'mm');
  }
  if (!allowBareMillimeters) return null;
  final parsed = ToolDetailController.parseNumericInputDetailed(compact);
  return parsed.value;
}

bool _isAreaToken(String token) {
  return const {'mm2', 'cm2', 'm2'}.contains(token);
}

double? _convertAreaMm2ToTarget(double areaMm2, String targetToken) {
  final targetFactor = const {
    'mm2': 1.0,
    'cm2': 100.0,
    'm2': 1000000.0,
  }[targetToken];
  return targetFactor == null ? null : areaMm2 / targetFactor;
}

double? _parseDurationInput(String input, String targetUnit) {
  final targetFactor = _durationTargetFactor(targetUnit);
  if (targetFactor == null) return null;
  final seconds = _parseDurationSeconds(input);
  return seconds == null ? null : seconds / targetFactor;
}

double? _durationTargetFactor(String targetUnit) {
  final raw = targetUnit.trim();
  if (raw == 'H') return null;
  final token = ToolUnitConversion.normalizeUnitToken(raw);
  return const {
    'ns': 0.000000001,
    'nanosecond': 0.000000001,
    'nanoseconds': 0.000000001,
    '纳秒': 0.000000001,
    'us': 0.000001,
    'microsecond': 0.000001,
    'microseconds': 0.000001,
    '微秒': 0.000001,
    'ms': 0.001,
    'millisecond': 0.001,
    'milliseconds': 0.001,
    '毫秒': 0.001,
    's': 1.0,
    'sec': 1.0,
    'secs': 1.0,
    'second': 1.0,
    'seconds': 1.0,
    '秒': 1.0,
    'min': 60.0,
    'mins': 60.0,
    'minute': 60.0,
    'minutes': 60.0,
    '分钟': 60.0,
    'h': 3600.0,
    'hr': 3600.0,
    'hrs': 3600.0,
    'hour': 3600.0,
    'hours': 3600.0,
    '小时': 3600.0,
    '时': 3600.0,
    'day': 86400.0,
    'days': 86400.0,
    'd': 86400.0,
    '天': 86400.0,
    'week': 604800.0,
    'weeks': 604800.0,
    'wk': 604800.0,
    'wks': 604800.0,
    '周': 604800.0,
    '星期': 604800.0,
  }[token];
}

double? _parseDurationSeconds(String input) {
  final normalized = _normalizeDurationText(input);
  if (normalized.isEmpty) return null;
  final colon = _parseColonDurationSeconds(normalized);
  if (colon != null) return colon;

  final matches = _durationTermPattern.allMatches(normalized).toList();
  if (matches.isEmpty) return null;
  var cursor = 0;
  var seconds = 0.0;
  for (final match in matches) {
    if (!_isDurationSeparator(normalized.substring(cursor, match.start))) {
      return null;
    }
    final value = double.tryParse(match.group(1)!);
    final factor = _durationUnitFactor(match.group(2)!);
    if (value == null || factor == null) return null;
    seconds += value * factor;
    cursor = match.end;
  }
  if (!_isDurationSeparator(normalized.substring(cursor))) return null;
  return seconds;
}

double? _parseColonDurationSeconds(String input) {
  final compact = input.replaceAll(RegExp(r'\s+'), '');
  if (!RegExp(r'^\d+(?::\d{1,2}){1,2}(?:\.\d+)?$').hasMatch(compact)) {
    return null;
  }
  final parts = compact.split(':');
  final hours = parts.length == 3 ? double.tryParse(parts[0]) : 0.0;
  final minutes = double.tryParse(parts[parts.length - 2]);
  final seconds = double.tryParse(parts.last);
  if (hours == null || minutes == null || seconds == null) return null;
  if (minutes >= 60 || seconds >= 60) return null;
  return hours * 3600 + minutes * 60 + seconds;
}

bool _isDurationSeparator(String text) {
  return text.trim().isEmpty || RegExp(r'^[\s,+]+$').hasMatch(text);
}

String _normalizeDurationText(String input) {
  return ToolUnitConversion.normalizeUnitText(input)
      .replaceAll('：', ':')
      .replaceAll('纳秒', 'ns')
      .replaceAll('微秒', 'us')
      .replaceAll('毫秒', 'ms')
      .replaceAll('小时', 'h')
      .replaceAll('时', 'h')
      .replaceAll('分钟', 'min')
      .replaceAll('分', 'min')
      .replaceAll('秒', 's')
      .replaceAll('星期', 'week')
      .replaceAll('周', 'week')
      .replaceAll('天', 'day');
}

double? _durationUnitFactor(String unit) {
  return const {
    'ns': 0.000000001,
    'nanosecond': 0.000000001,
    'nanoseconds': 0.000000001,
    'ms': 0.001,
    'millisecond': 0.001,
    'milliseconds': 0.001,
    'us': 0.000001,
    'microsecond': 0.000001,
    'microseconds': 0.000001,
    's': 1.0,
    'sec': 1.0,
    'secs': 1.0,
    'second': 1.0,
    'seconds': 1.0,
    'm': 60.0,
    'min': 60.0,
    'mins': 60.0,
    'minute': 60.0,
    'minutes': 60.0,
    'h': 3600.0,
    'hr': 3600.0,
    'hrs': 3600.0,
    'hour': 3600.0,
    'hours': 3600.0,
    'd': 86400.0,
    'day': 86400.0,
    'days': 86400.0,
    '天': 86400.0,
    'week': 604800.0,
    'weeks': 604800.0,
    'wk': 604800.0,
    'wks': 604800.0,
  }[unit];
}

final RegExp _durationTermPattern = RegExp(
  r'(\d+(?:\.\d+)?|\.\d+)\s*(nanoseconds?|ns|microseconds?|us|milliseconds?|ms|seconds?|secs?|s|minutes?|mins?|min|m|hours?|hrs?|hr|h|days?|d|weeks?|wks?|week)',
);

