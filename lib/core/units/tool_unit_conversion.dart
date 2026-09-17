import 'dart:math' as math;

part 'tool_unit_conversion_internals.dart';
part 'tool_unit_conversion_units_core.dart';
part 'tool_unit_conversion_units_engineering.dart';

/// 单位转换和单位文本归一化工具。
/// Extracted from ToolDetailController for separation of concerns.
class ToolUnitConversion {
  ToolUnitConversion._();


  static String normalizeNumericText(String rawValue) {
    final normalized = rawValue
        .trim()
        .replaceAll('，', ',')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('－', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('‐', '-')
        .replaceAll('‑', '-')
        .replaceAll('﹣', '-')
        .replaceAll('＋', '+')
        .replaceAll('％', '%')
        .replaceAll('～', '~')
        .replaceAllMapped(
          RegExp(r'[\uFF10-\uFF19]'),
          (match) =>
              String.fromCharCode(match.group(0)!.codeUnitAt(0) - 0xfee0),
        );
    return stripSpecValueDecorations(normalized);
  }

  static String stripSpecValueDecorations(String value) {
    var output = value.trim();
    output = output.replaceFirst(
      RegExp(
        r'^(?:[~≈≃≅≒≤≥<>≦≧=]+|小于等于|不大于|不超过|最多|小于|低于|少于|大于等于|不小于|不少于|至少|大于|高于|超过|约为|约等于|约等|约|大约|大概|近似)\s*',
        caseSensitive: false,
      ),
      '',
    );
    output = output.replaceFirst(
      RegExp(
        r'^(?:around|about|approx(?:imately)?|ca\.?|circa|typ\.?|typical|nominal|rated|min(?:imum)?|max(?:imum)?)(?=\s|[:：=~-])\s*[:：=~-]?\s*',
        caseSensitive: false,
      ),
      '',
    );
    output = output.replaceFirst(
      RegExp(
        r'\s*(?:\((?:typ\.?|typical|nominal|rated|max(?:imum)?|approx(?:imately)?|about|around)\.?\)|typ\.?|typical|nominal|rated|max(?:imum)?|approx(?:imately)?|about|around|左右|约|以内|以下|以上)\.?$',
        caseSensitive: false,
      ),
      '',
    );
    return output.trim();
  }

  static String? extractLabeledNumericCandidate(String rawValue) {
    final lines = rawValue
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    final source = lines.last;
    final match = RegExp(
            r'^([^:=：>\-]*(?:[A-Za-z_\u4e00-\u9fff][^:=：>\-]*)+)(?:->|=>|[:=：])\s*(.+)$')
        .firstMatch(source);
    final value = match?.group(2)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? extractNominalNumericCandidate(String rawValue) {
    final lines = rawValue
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    final source = normalizeNumericText(lines.last)
        .replaceAll('（', '(')
        .replaceAll('）', ')');
    final match =
        RegExp(r'^(.*?)\s*(?:±|\+/-|-/\+|\+-)\s*.+$').firstMatch(source);
    if (match == null) return null;
    var candidate = match.group(1)?.trim();
    if (candidate == null || candidate.isEmpty) return null;
    candidate =
        candidate.replaceFirst(RegExp(r'[\s,;，；:：=\(\[\{]+$'), '').trim();
    if (candidate.isEmpty || !RegExp(r'\d').hasMatch(candidate)) return null;
    return candidate;
  }

  static String? extractFirstRangeQuantity(
    String rawValue, {
    bool unitRequiredForHyphen = true,
  }) {
    final source = rawValue.trim();
    if (source.isEmpty) return null;
    const number =
        r'[+-]?(?:(?:\d[\d,_]*(?:\.\d[\d,_]*)?)|(?:\.\d[\d,_]*))(?:e[+-]?\d+)?';
    final match = RegExp(
      '^\\s*($number)\\s*([^~\\-至到]*?)\\s*(\\.\\.|…|~|至|到|to|-)\\s*'
      '($number)\\s*(.*?)\\s*\$',
      caseSensitive: false,
    ).firstMatch(source);
    if (match == null) return null;

    final separator = match.group(3)!.toLowerCase();
    final firstNumber = match.group(1)!;
    final secondNumber = match.group(4)!;
    final firstUnit = match.group(2)!.trim();
    final secondUnit = match.group(5)!.trim();
    if (separator == '-') {
      if (unitRequiredForHyphen && firstUnit.isEmpty && secondUnit.isEmpty) {
        return null;
      }
      final first = parseRangeBound(firstNumber);
      final second = parseRangeBound(secondNumber);
      if (first == null || second == null || first > second) return null;
    }

    final unit = firstUnit.isNotEmpty ? firstUnit : secondUnit;
    return '$firstNumber$unit'.trim();
  }

  static double? parseRangeBound(String rawValue) {
    return double.tryParse(rawValue.replaceAll(',', '').replaceAll('_', ''));
  }

  static ParsedUnitSuffix? splitUnitSuffix(
    String input,
    String targetUnit,
  ) {
    final targetToken = normalizeUnitToken(targetUnit);
    final aliases = unitAliasesForTarget(targetToken, targetUnit);
    if (aliases.isEmpty) return null;
    return splitByAliases(input, aliases);
  }

  static ParsedUnitSuffix? splitAnyKnownUnitSuffix(String input) {
    return splitByAliases(input, _allKnownUnitAliases);
  }

  static ParsedUnitSuffix? splitByAliases(
    String input,
    Iterable<String> aliases,
  ) {
    final compact = normalizeUnitText(input).replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return null;
    final sorted = aliases.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final alias in sorted) {
      if (alias.isEmpty || !compact.endsWith(alias)) continue;
      final valueText = compact
          .substring(0, compact.length - alias.length)
          .replaceFirst(RegExp(r'[-_/]+$'), '');
      if (valueText.isEmpty) continue;
      return ParsedUnitSuffix(
        valueText: valueText,
        unitToken: alias,
        unitLabel: displayUnitAlias(alias),
      );
    }
    return null;
  }

  static ParsedUnitSuffix? splitPrefixUnit(
    String input,
    String targetUnit,
  ) {
    final targetToken = normalizeUnitToken(targetUnit);
    final aliases = unitAliasesForTarget(targetToken, targetUnit)
        .where(_supportsPrefixUnitNotation)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (aliases.isEmpty) return null;

    final compact = normalizeUnitText(input)
        .replaceAll(',', '')
        .replaceAll(RegExp(r'\s+'), '');
    for (final alias in aliases) {
      if (!compact.startsWith(alias)) continue;
      final valueText = compact.substring(alias.length);
      if (valueText.isEmpty || !RegExp(r'^[+\-.\d]').hasMatch(valueText)) {
        continue;
      }
      return ParsedUnitSuffix(
        valueText: valueText,
        unitToken: alias,
        unitLabel: displayUnitAlias(alias),
      );
    }
    return null;
  }

  static Set<String> unitAliasesForTarget(
    String targetToken,
    String rawTargetUnit,
  ) {
    if (isTemperatureTargetUnit(rawTargetUnit)) {
      return const {
        'k',
        'kelvin',
        'kelvins',
        '开尔文',
        '开氏度',
        'c',
        'celsius',
        'centigrade',
        '摄氏',
        '摄氏度',
        'f',
        'fahrenheit',
        '华氏',
        '华氏度',
        'r',
        'rankine',
        'rankines',
        '兰氏',
        '兰氏度',
      };
    }
    if (rawTargetUnit.trim() == 'H') {
      return const {'h', 'kh', 'mh', 'uh', 'nh', 'ph', 'megahenry'};
    }
    if (targetToken == 'l/100km') {
      return const {
        'l/100km',
        'lper100km',
        'liter/100km',
        'liters/100km',
        'litre/100km',
        'litres/100km',
        '升/百公里',
        '升每百公里',
      };
    }
    if (targetToken == '元/l') {
      return const {
        '元/l',
        '元/升',
        '元每升',
        'cny/l',
        'rmb/l',
        'yuan/l',
      };
    }
    if (targetToken == 'kg/l') {
      return const {
        'kg/l',
        'kg/升',
        '千克/升',
        '千克每升',
        'kgperliter',
      };
    }
    if (targetToken == 'dbm' || targetToken == 'dbw') {
      return const {
        'dbm',
        'dbw',
        'w',
        '瓦',
        '瓦特',
        'watt',
        'watts',
        'mw',
        '毫瓦',
        'milliwatt',
        'milliwatts',
        'kw',
        '千瓦',
        'kilowatt',
        'kilowatts',
        'megawatt',
        'megawatts',
        '兆瓦',
        'hp',
        '马力',
      };
    }
    final group =
        _unitGroups.where((item) => item.containsKey(targetToken)).firstOrNull;
    if (group == null) return {targetToken};
    final aliases = group.keys.toSet();
    if (_powerFactorForToken(targetToken) != null) {
      aliases.addAll(const {'dbm', 'dbw'});
    }
    return aliases;
  }

  static bool isTemperatureTargetUnit(String unit) {
    final trimmed = unit.trim();
    return trimmed == 'K' ||
        trimmed == '℃' ||
        trimmed == '°C' ||
        trimmed == '℉' ||
        trimmed == '°F' ||
        trimmed == '°R';
  }

  static double? convertUnitValue(
    double value,
    String sourceUnit,
    String targetUnit,
  ) {
    final sourceToken = normalizeUnitToken(sourceUnit);
    final targetToken = normalizeUnitToken(targetUnit);
    final temperature =
        _convertTemperatureValue(value, sourceToken, targetToken);
    if (temperature != null) return temperature;
    final decibelPower = _convertDecibelPowerValue(
      value,
      sourceToken,
      targetToken,
    );
    if (decibelPower != null) return decibelPower;
    final compoundUnit = _convertCompoundUnitValue(
      value,
      sourceToken,
      targetToken,
    );
    if (compoundUnit != null) return compoundUnit;
    for (final group in _unitGroups) {
      final sourceFactor = group[sourceToken];
      final targetFactor = group[targetToken];
      if (sourceFactor != null && targetFactor != null) {
        return value * sourceFactor / targetFactor;
      }
    }
    return sourceToken == targetToken ? value : null;
  }

  static double? parseCompositeUnitInput(String input, String targetUnit) {
    if (isTemperatureTargetUnit(targetUnit)) return null;
    final aliases = unitAliasesForTarget(
      normalizeUnitToken(targetUnit),
      targetUnit,
    ).where((alias) => alias.isNotEmpty).toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (aliases.isEmpty) return null;

    final source = normalizeUnitText(input).replaceAll(',', '');
    var index = 0;
    var count = 0;
    var total = 0.0;

    void skipSeparators() {
      while (index < source.length &&
          RegExp(r'[\s,+;，；]+').hasMatch(source[index])) {
        index++;
      }
    }

    skipSeparators();
    while (index < source.length) {
      final numberMatch = RegExp(
        r'[+-]?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+))(?:e[+-]?\d+)?',
        caseSensitive: false,
      ).matchAsPrefix(source, index);
      if (numberMatch == null) return null;
      final value = double.tryParse(numberMatch.group(0)!);
      if (value == null) return null;
      index = numberMatch.end;
      while (index < source.length && RegExp(r'\s').hasMatch(source[index])) {
        index++;
      }

      String? unitToken;
      for (final alias in aliases) {
        if (source.startsWith(alias, index)) {
          unitToken = alias;
          break;
        }
      }
      if (unitToken == null) return null;
      index += unitToken.length;

      final converted = convertUnitValue(value, unitToken, targetUnit);
      if (converted == null) return null;
      total += converted;
      count++;

      skipSeparators();
    }
    return count >= 2 ? total : null;
  }

  static String? normalizeTemperatureToken(String token) {
    return const {
      'k': 'k',
      'kelvin': 'k',
      'kelvins': 'k',
      '开尔文': 'k',
      '开氏度': 'k',
      'c': 'c',
      '℃': 'c',
      'celsius': 'c',
      'centigrade': 'c',
      '摄氏': 'c',
      '摄氏度': 'c',
      'f': 'f',
      '℉': 'f',
      'fahrenheit': 'f',
      '华氏': 'f',
      '华氏度': 'f',
      'r': 'r',
      'rankine': 'r',
      'rankines': 'r',
      '兰氏': 'r',
      '兰氏度': 'r',
    }[token];
  }

  static double? parseComponentMarking(String input, String targetToken) {
    final compact = normalizeUnitText(input).replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty || compact.contains(',')) return null;
    if (_isResistanceToken(targetToken)) {
      final ohms = _parseResistanceMarking(compact);
      final targetFactor = _resistanceFactorForToken(targetToken);
      return ohms == null || targetFactor == null ? null : ohms / targetFactor;
    }
    if (_isCapacitanceToken(targetToken)) {
      final farads = _parseCapacitanceMarking(compact);
      final targetFactor = _capacitanceFactorForToken(targetToken);
      return farads == null || targetFactor == null
          ? null
          : farads / targetFactor;
    }
    if (_isInductanceToken(targetToken)) {
      final henries = _parseInductanceMarking(compact);
      final targetFactor = _inductanceFactorForToken(targetToken);
      return henries == null || targetFactor == null
          ? null
          : henries / targetFactor;
    }
    return null;
  }

  static String normalizeUnitText(String value) {
    return value
        .trim()
        .replaceAll('MWh', 'megawatthour')
        .replaceAll('mWh', 'milliwatthour')
        .replaceAll('mHz', 'millihertz')
        .replaceAll('THz', 'terahertz')
        .replaceAll('MHz', 'megahertz')
        .replaceAll('MV', 'megavolt')
        .replaceAll('MW', 'megawatt')
        .replaceAll('MA', 'megaamp')
        .replaceAll('MF', 'megafarad')
        .replaceAll('mF', 'millifarad')
        .replaceAll('MH', 'megahenry')
        .replaceAll('kH', 'kh')
        .replaceAll('nH', 'nh')
        .replaceAll('pH', 'ph')
        .replaceAll('Mg', 'megagram')
        .replaceAll('mPa', 'millipascal')
        .replaceAll('MPa', 'megapascal')
        .replaceAll('GPa', 'gigapascal')
        .replaceAll('mN', 'millinewton')
        .replaceAll('MN', 'meganewton')
        .replaceAll('kA', 'ka')
        .replaceAll('Mm', 'megameter')
        .replaceAll('μΩ', 'microohm')
        .replaceAll('µΩ', 'microohm')
        .replaceAll('μΩ', 'microohm')
        .replaceAll('µΩ', 'microohm')
        .replaceAll('mΩ', 'milliohm')
        .replaceAll('mΩ', 'milliohm')
        .replaceAll('GΩ', 'gohm')
        .replaceAll('GΩ', 'gohm')
        .replaceAll('微欧姆', 'microohm')
        .replaceAll('微欧', 'microohm')
        .replaceAll('毫欧姆', 'milliohm')
        .replaceAll('毫欧', 'milliohm')
        .replaceAll('吉欧姆', 'gohm')
        .replaceAll('吉欧', 'gohm')
        .replaceAll('μ', 'u')
        .replaceAll('µ', 'u')
        .replaceAll('Ω', 'ohm')
        .replaceAll('Ω', 'ohm')
        .replaceAll('ω', 'ohm')
        .replaceAll('欧姆', 'ohm')
        .replaceAll('℃', 'c')
        .replaceAll('℉', 'f')
        .replaceAll('°C', 'c')
        .replaceAll('°c', 'c')
        .replaceAll('°F', 'f')
        .replaceAll('°f', 'f')
        .replaceAll('°R', 'r')
        .replaceAll('°r', 'r')
        .replaceAll('²', '2')
        .replaceAll('³', '3')
        .replaceAll('^2', '2')
        .replaceAll('^3', '3')
        .replaceAll('⁴', '4')
        .replaceAll('^4', '4')
        .replaceAll('·', '.')
        .replaceAll('／', '/')
        .replaceAll('⁄', '/')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .toLowerCase();
  }

  static String normalizeUnitToken(String unit) {
    return normalizeUnitText(unit).replaceAll(RegExp(r'\s+'), '');
  }

  static String displayUnitAlias(String alias) {
    return const {
          'ohm': 'Ω',
          'microohm': 'μΩ',
          'kohm': 'kΩ',
          'mohm': 'MΩ',
          'gohm': 'GΩ',
          'milliohm': 'mΩ',
          'millifarad': 'mF',
          'uf': 'μF',
          'nf': 'nF',
          'pf': 'pF',
          'megafarad': 'MF',
          'h': 'H',
          'kh': 'kH',
          'mh': 'mH',
          'uh': 'μH',
          'nh': 'nH',
          'ph': 'pH',
          'megahenry': 'MH',
          'megahenrys': 'MH',
          'ns': 'ns',
          'us': 'μs',
          'ms': 'ms',
          's': 's',
          'sec': 's',
          'min': 'min',
          'hr': 'h',
          'day': 'day',
          'week': 'week',
          'wk': 'week',
          'deg': 'deg',
          'rad': 'rad',
          'turn': 'turn',
          'grad': 'grad',
          'gon': 'gon',
          'arcmin': 'arcmin',
          'arcminute': 'arcmin',
          'arcsec': 'arcsec',
          'arcsecond': 'arcsec',
          'nm': 'nm',
          'nanometer': 'nm',
          'nanometers': 'nm',
          'um': 'μm',
          'micrometer': 'μm',
          'micrometers': 'μm',
          'megameter': 'Mm',
          'megameters': 'Mm',
          'v': 'V',
          'volt': 'V',
          'volts': 'V',
          'vdc': 'VDC',
          'vac': 'VAC',
          'mv': 'mV',
          'mw': 'mW',
          'millivolt': 'mV',
          'millivolts': 'mV',
          'kv': 'kV',
          'kilovolt': 'kV',
          'kilovolts': 'kV',
          'megavolt': 'MV',
          'megavolts': 'MV',
          'w': 'W',
          'watt': 'W',
          'watts': 'W',
          'kw': 'kW',
          'kilowatt': 'kW',
          'kilowatts': 'kW',
          'megawatt': 'MW',
          'megawatts': 'MW',
          'dbm': 'dBm',
          'dbw': 'dBW',
          'millihertz': 'mHz',
          'hz': 'Hz',
          'hertz': 'Hz',
          'khz': 'kHz',
          'kilohertz': 'kHz',
          'mhz': 'MHz',
          'megahertz': 'MHz',
          'ghz': 'GHz',
          'gigahertz': 'GHz',
          'terahertz': 'THz',
          'thz': 'THz',
          'j': 'J',
          'kj': 'kJ',
          'milliwatthour': 'mWh',
          'megawatthour': 'MWh',
          'wh': 'Wh',
          'kwh': 'kWh',
          'cal': 'cal',
          'kcal': 'kcal',
          'btu': 'BTU',
          'ev': 'eV',
          'a': 'A',
          'amp': 'A',
          'amps': 'A',
          'ampere': 'A',
          'amperes': 'A',
          'ma': 'mA',
          'milliamp': 'mA',
          'milliamps': 'mA',
          'milliampere': 'mA',
          'milliamperes': 'mA',
          'ua': 'μA',
          'na': 'nA',
          'ka': 'kA',
          'megaamp': 'MA',
          'megaamps': 'MA',
          'megaampere': 'MA',
          'megaamperes': 'MA',
          'millinewton': 'mN',
          'millinewtons': 'mN',
          'n': 'N',
          'newton': 'N',
          'newtons': 'N',
          'kn': 'kN',
          'kilonewton': 'kN',
          'kilonewtons': 'kN',
          'meganewton': 'MN',
          'meganewtons': 'MN',
          'pa': 'Pa',
          'pascal': 'Pa',
          'pascals': 'Pa',
          'millipascal': 'mPa',
          'millipascals': 'mPa',
          'kpa': 'kPa',
          'kilopascal': 'kPa',
          'kilopascals': 'kPa',
          'mpa': 'MPa',
          'megapascal': 'MPa',
          'megapascals': 'MPa',
          'gpa': 'GPa',
          'gigapascal': 'GPa',
          'gigapascals': 'GPa',
          'mbar': 'mbar',
          'kgf/cm2': 'kgf/cm²',
          'n/mm2': 'N/mm²',
          'm2': 'm²',
          'km2': 'km²',
          'cm2': 'cm²',
          'mm2': 'mm²',
          'ft2': 'ft²',
          'in2': 'in²',
          'yd2': 'yd²',
          'ha': 'ha',
          'acre': 'acre',
          'mu': '亩',
          'm3': 'm³',
          'mm3': 'mm³',
          'cm3': 'cm³',
          'ft3': 'ft³',
          'in3': 'in³',
          'yd3': 'yd³',
          'l': 'L',
          'ml': 'mL',
          'gal': 'gal',
          'qt': 'qt',
          'pt': 'pt',
          'floz': 'fl oz',
          'cup': 'cup',
          'tbsp': 'tbsp',
          'tsp': 'tsp',
          'm/min': 'm/min',
          'cm/s': 'cm/s',
          'knot': 'kn',
          'm/s2': 'm/s²',
          'cm/s2': 'cm/s²',
          'galileo': 'Gal',
          'n.m': 'N·m',
          'n.mm': 'N·mm',
          'kn.m': 'kN·m',
          'millinewton.m': 'mN·m',
          'kgf.m': 'kgf·m',
          'kgf.cm': 'kgf·cm',
          'lbf.ft': 'lbf·ft',
          'lbf.in': 'lbf·in',
          'ozf.in': 'ozf·in',
          'kph': 'km/h',
          'l/min': 'L/min',
          'l/h': 'L/h',
          'ml/min': 'mL/min',
          'm3/h': 'm³/h',
          'm3/min': 'm³/min',
          'm3/s': 'm³/s',
          'cfm': 'CFM',
          'g/cm3': 'g/cm³',
          'kg/m3': 'kg/m³',
          'mg': 'mg',
          'megagram': 'Mg',
          'megagrams': 'Mg',
          't': 't',
          'tonne': 't',
          'tonnes': 't',
          'kib': 'KiB',
          'mib': 'MiB',
          'gib': 'GiB',
          'tib': 'TiB',
          'tb': 'TB',
          'kbit': 'Kbit',
          'mbit': 'Mbit',
          'gbit': 'Gbit',
          'tbit': 'Tbit',
          'mah': 'mAh',
          'ah': 'Ah',
          'uah': 'μAh',
          'ma.h': 'mA·h',
          'a.h': 'A·h',
          'ua.h': 'μA·h',
          'c': '℃',
          'f': '℉',
        }[alias] ??
        alias;
  }

  static final Set<String> lengthUnitAliases = _unitGroups.first.keys.toSet();

}

class ParsedUnitSuffix {
  const ParsedUnitSuffix({
    required this.valueText,
    required this.unitToken,
    required this.unitLabel,
  });

  final String valueText;
  final String unitToken;
  final String unitLabel;
}
