import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/utils/iterable_ext.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/math/expression_parser.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/tool_usage_repository.dart';
import '../../domain/entities/tool_definition.dart';
import '../../domain/usecases/calculate_tool.dart';
import '../../domain/usecases/tool_save_result.dart';
import '../../domain/usecases/tool_insights.dart';

part 'tool_detail_paste_parser.dart';

class ToolDetailController extends ChangeNotifier {
  ToolDetailController({
    required this.historyRepository,
    required this.notesRepository,
    required this.toolUsageRepository,
    required this.tool,
  }) {
    _values = _defaultValues(tool);
    _recalculate();
  }

  final HistoryRepository historyRepository;
  final NotesRepository notesRepository;
  final ToolUsageRepository toolUsageRepository;
  final ToolDefinition tool;

  Map<String, double> _values = const {};
  List<ToolResult> _results = const [];
  List<String> _insights = const [];
  Map<String, String> _inputErrors = const {};
  bool _favorite = false;

  Map<String, double> get values => Map.unmodifiable(_values);

  List<ToolResult> get results => _results;

  List<String> get insights => _insights;

  Map<String, String> get inputErrors => Map.unmodifiable(_inputErrors);

  bool get hasInputErrors => _inputErrors.isNotEmpty;

  bool get favorite => _favorite;

  ToolResult? get primary =>
      _results.where((result) => result.primary).firstOrNull ??
      _results.firstOrNull;

  List<ToolResult> get usableResults => _results
      .where((result) => !resultNeedsAttention(result))
      .toList(growable: false);

  List<ToolResult> get issueResults =>
      _results.where(resultNeedsAttention).toList(growable: false);

  bool get hasResultIssues => issueResults.isNotEmpty;

  static double parseNumericInput(String rawValue) {
    final parsed = parseNumericInputDetailed(rawValue);
    return parsed.value ?? 0;
  }

  static NumericInputParseResult parseNumericInputDetailed(String rawValue) {
    final normalized = _normalizeNumericText(rawValue).replaceAll(',', '');
    final parsed = _parsePlainNumericInput(normalized);
    if (parsed.value != null) return parsed;

    final labeled = _extractLabeledNumericCandidate(rawValue);
    if (labeled != null) {
      final labeledParsed = _parsePlainNumericInput(
          _normalizeNumericText(labeled).replaceAll(',', ''));
      if (labeledParsed.value != null) return labeledParsed;
      final labeledNominal = _extractNominalNumericCandidate(labeled);
      if (labeledNominal != null) {
        final nominalParsed = _parsePlainNumericInput(
            _normalizeNumericText(labeledNominal).replaceAll(',', ''));
        if (nominalParsed.value != null) return nominalParsed;
      }
    }

    final nominal = _extractNominalNumericCandidate(rawValue);
    if (nominal != null) {
      final nominalParsed = _parsePlainNumericInput(
          _normalizeNumericText(nominal).replaceAll(',', ''));
      if (nominalParsed.value != null) return nominalParsed;
    }
    return parsed;
  }

  static NumericInputParseResult _parsePlainNumericInput(String normalized) {
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

  static NumericInputParseResult parseNumericInputForUnit(
    String rawValue,
    String targetUnit,
  ) {
    final normalized = _normalizeNumericText(rawValue);
    if (normalized.isEmpty) {
      return const NumericInputParseResult(value: null, error: '请输入数值');
    }
    if (targetUnit.trim().isEmpty) return parseNumericInputDetailed(rawValue);
    if (_normalizeUnitToken(targetUnit) == '%') {
      return _parsePercentInput(normalized);
    }

    final parsed = _parseNumericInputForUnitNormalized(normalized, targetUnit);
    if (parsed.value != null) return parsed;

    final labeled = _extractLabeledNumericCandidate(rawValue);
    if (labeled != null) {
      final labeledParsed = _parseNumericInputForUnitNormalized(
        _normalizeNumericText(labeled),
        targetUnit,
      );
      if (labeledParsed.value != null) return labeledParsed;
      final labeledNominal = _extractNominalNumericCandidate(labeled);
      if (labeledNominal != null) {
        final nominalParsed = _parseNumericInputForUnitNormalized(
          _normalizeNumericText(labeledNominal),
          targetUnit,
        );
        if (nominalParsed.value != null) return nominalParsed;
      }
    }

    final nominal = _extractNominalNumericCandidate(rawValue);
    if (nominal != null) {
      final nominalParsed = _parseNumericInputForUnitNormalized(
        _normalizeNumericText(nominal),
        targetUnit,
      );
      if (nominalParsed.value != null) return nominalParsed;
      final suffix =
          _splitUnitSuffix(_normalizeNumericText(nominal), targetUnit);
      if (suffix != null) {
        final parsedValue = parseNumericInputDetailed(suffix.valueText).value;
        if (parsedValue != null) {
          final converted =
              _convertUnitValue(parsedValue, suffix.unitToken, targetUnit);
          if (converted != null) {
            return NumericInputParseResult(value: converted);
          }
        }
      }
    }
    return parsed;
  }

  static NumericInputParseResult _parsePercentInput(String normalized) {
    final labeled = _extractLabeledNumericCandidate(normalized);
    if (labeled != null) {
      final parsed = _parsePercentInput(_normalizeNumericText(labeled));
      if (parsed.value != null) return parsed;
    }

    final nominal = _extractNominalNumericCandidate(normalized);
    if (nominal != null && nominal != normalized) {
      final parsed = _parsePercentInput(_normalizeNumericText(nominal));
      if (parsed.value != null) return parsed;
    }

    final compact = normalized.replaceAll(RegExp(r'\s+'), '');
    if (compact.endsWith('%')) {
      final value = parseNumericInputDetailed(
        compact.substring(0, compact.length - 1),
      ).value;
      if (value != null) return NumericInputParseResult(value: value);
    }
    return parseNumericInputDetailed(normalized);
  }

  static NumericInputParseResult _parseNumericInputForUnitNormalized(
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

    final composite = _parseCompositeUnitInput(normalized, targetUnit);
    if (composite != null) {
      return NumericInputParseResult(value: composite);
    }

    final range = _parseRangeInputForUnit(normalized, targetUnit);
    if (range != null) return range;

    final prefixedUnit = _splitPrefixUnit(normalized, targetUnit);
    if (prefixedUnit != null) {
      final rangeValue = _extractFirstRangeQuantity(
        prefixedUnit.valueText,
        unitRequiredForHyphen: false,
      );
      if (rangeValue != null) {
        final parsed = parseNumericInputDetailed(rangeValue);
        final value = parsed.value;
        if (value != null) {
          final converted =
              _convertUnitValue(value, prefixedUnit.unitToken, targetUnit);
          if (converted != null) {
            return NumericInputParseResult(value: converted);
          }
        }
      }
      final parsed = parseNumericInputDetailed(prefixedUnit.valueText);
      final value = parsed.value;
      if (value == null) {
        return NumericInputParseResult(
          value: null,
          error: parsed.error ?? '无法解析数值或表达式',
        );
      }
      final converted =
          _convertUnitValue(value, prefixedUnit.unitToken, targetUnit);
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

    final unitSuffix = _splitUnitSuffix(normalized, targetUnit);
    if (unitSuffix != null) {
      final rangeValue = _extractFirstRangeQuantity(
        unitSuffix.valueText,
        unitRequiredForHyphen: false,
      );
      final parsed =
          parseNumericInputDetailed(rangeValue ?? unitSuffix.valueText);
      var value = parsed.value;
      if (value == null) {
        final nominal = _extractNominalNumericCandidate(unitSuffix.valueText);
        if (nominal != null) {
          value = parseNumericInputDetailed(nominal).value;
        }
      }
      if (value == null) {
        return NumericInputParseResult(
          value: null,
          error: parsed.error ?? '无法解析数值或表达式',
        );
      }
      final converted =
          _convertUnitValue(value, unitSuffix.unitToken, targetUnit);
      if (converted == null) {
        return NumericInputParseResult(
          value: null,
          error: '单位 ${unitSuffix.unitLabel} 与 $targetUnit 不匹配',
        );
      }
      return NumericInputParseResult(value: converted);
    }

    final componentMarking =
        _parseComponentMarking(normalized, _normalizeUnitToken(targetUnit));
    if (componentMarking != null) {
      return NumericInputParseResult(value: componentMarking);
    }

    final nominal = _extractNominalNumericCandidate(normalized);
    if (nominal != null) {
      final nominalParsed =
          _parseNumericInputForUnitNormalized(nominal, targetUnit);
      if (nominalParsed.value != null) return nominalParsed;
    }

    final mismatchedUnit = _splitAnyKnownUnitSuffix(normalized);
    if (mismatchedUnit != null) {
      return NumericInputParseResult(
        value: null,
        error: '单位 ${mismatchedUnit.unitLabel} 与 $targetUnit 不匹配',
      );
    }
    return parseNumericInputDetailed(normalized);
  }

  static NumericInputParseResult? _parseRangeInputForUnit(
    String input,
    String targetUnit,
  ) {
    final firstQuantity = _extractFirstRangeQuantity(input);
    if (firstQuantity == null) return null;
    final normalizedFirst = _normalizeNumericText(firstQuantity);
    if (normalizedFirst == input) return null;
    final parsed = _parseNumericInputForUnitNormalized(
      normalizedFirst,
      targetUnit,
    );
    return parsed.value == null ? null : parsed;
  }

  static double? _parseAwgInput(String input, String targetUnit) {
    final targetToken = _normalizeUnitToken(targetUnit);
    if (!_isAreaToken(targetToken)) return null;
    final compact = _normalizeUnitText(input).replaceAll(RegExp(r'\s+'), '');
    final match =
        RegExp(r'^(?:awg|#)?([0-9]{1,2})(?:awg)?$').firstMatch(compact);
    if (match == null) return null;
    final gauge = int.tryParse(match.group(1)!);
    if (gauge == null || gauge > 40) return null;
    final diameterMm = 0.127 * math.pow(92, (36 - gauge) / 39);
    final areaMm2 = math.pi * diameterMm * diameterMm / 4;
    return _convertAreaMm2ToTarget(areaMm2, targetToken);
  }

  static double? _parseConductorAreaInput(String input, String targetUnit) {
    final targetToken = _normalizeUnitToken(targetUnit);
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

  static bool _looksLikeConductorAreaInput(String input) {
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

  static String _normalizeConductorAreaText(String input) {
    return _normalizeUnitText(input)
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

  static double? _parseStrandedWireAreaMm2(String input) {
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

  static double? _parseCircularAreaMm2(String input) {
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

  static double? _parseLengthQuantityToMillimeters(
    String input, {
    bool allowBareMillimeters = false,
  }) {
    final compact = _normalizeUnitText(input).replaceAll(RegExp(r'\s+'), '');
    final suffix = _splitByAliases(compact, _lengthUnitAliases);
    if (suffix != null) {
      final parsed = parseNumericInputDetailed(suffix.valueText);
      final value = parsed.value;
      if (value == null) return null;
      return _convertUnitValue(value, suffix.unitToken, 'mm');
    }
    if (!allowBareMillimeters) return null;
    final parsed = parseNumericInputDetailed(compact);
    return parsed.value;
  }

  static bool _isAreaToken(String token) {
    return const {'mm2', 'cm2', 'm2'}.contains(token);
  }

  static double? _convertAreaMm2ToTarget(double areaMm2, String targetToken) {
    final targetFactor = const {
      'mm2': 1.0,
      'cm2': 100.0,
      'm2': 1000000.0,
    }[targetToken];
    return targetFactor == null ? null : areaMm2 / targetFactor;
  }

  static double? _parseDurationInput(String input, String targetUnit) {
    final targetFactor = _durationTargetFactor(targetUnit);
    if (targetFactor == null) return null;
    final seconds = _parseDurationSeconds(input);
    return seconds == null ? null : seconds / targetFactor;
  }

  static double? _durationTargetFactor(String targetUnit) {
    final raw = targetUnit.trim();
    if (raw == 'H') return null;
    final token = _normalizeUnitToken(raw);
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

  static double? _parseDurationSeconds(String input) {
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

  static double? _parseColonDurationSeconds(String input) {
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

  static bool _isDurationSeparator(String text) {
    return text.trim().isEmpty || RegExp(r'^[\s,+]+$').hasMatch(text);
  }

  static String _normalizeDurationText(String input) {
    return _normalizeUnitText(input)
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

  static double? _durationUnitFactor(String unit) {
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

  static final RegExp _durationTermPattern = RegExp(
    r'(\d+(?:\.\d+)?|\.\d+)\s*(nanoseconds?|ns|microseconds?|us|milliseconds?|ms|seconds?|secs?|s|minutes?|mins?|min|m|hours?|hrs?|hr|h|days?|d|weeks?|wks?|week)',
  );

  static String draftSettingKey(String toolId) => 'tool_draft_$toolId';

  static Map<String, String> defaultInputTexts(ToolDefinition tool) {
    return {
      for (final input in tool.inputs)
        input.key:
            input.defaultValue == null ? '' : formatNumber(input.defaultValue!)
    };
  }

  static Map<String, double> _defaultValues(ToolDefinition tool) {
    return {
      for (final input in tool.inputs)
        if (!input.optional || input.defaultValue != null)
          input.key: input.defaultValue ?? 0,
    };
  }

  static String encodeDraft({
    required ToolDefinition tool,
    required Map<String, String> rawValues,
  }) {
    final allowedKeys = tool.inputs.map((input) => input.key).toSet();
    final values = {
      for (final entry in rawValues.entries)
        if (allowedKeys.contains(entry.key)) entry.key: entry.value,
    };
    return jsonEncode({
      'version': 1,
      'toolId': tool.id,
      'values': values,
    });
  }

  static Map<String, String>? decodeDraft({
    required ToolDefinition tool,
    required String? raw,
  }) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['toolId'] != tool.id) return null;
      final values = decoded['values'];
      if (values is! Map) return null;
      final allowedKeys = tool.inputs.map((input) => input.key).toSet();
      final result = <String, String>{};
      for (final entry in values.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is String && allowedKeys.contains(key)) {
          result[key] = value;
        }
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> rawInputValuesFromPastedText({
    required ToolDefinition tool,
    required String input,
  }) {
    return _rawInputValuesFromPastedText(tool: tool, input: input);
  }

  static ToolInputPasteResult inputPasteResultFromPastedText({
    required ToolDefinition tool,
    required String input,
  }) {
    return _parseRawInputValuesFromPastedText(tool: tool, input: input);
  }

  ToolInputApplyResult applyInputPasteResult(
    ToolInputPasteResult pasteResult,
  ) {
    return applyRawInputValuesDetailed(
      pasteResult.values,
      pasteResult: pasteResult,
    );
  }

  Map<String, String> applyRawInputValues(Map<String, String> rawValues) {
    return applyRawInputValuesDetailed(rawValues).inputTexts;
  }

  ToolInputApplyResult applyRawInputValuesDetailed(
    Map<String, String> rawValues, {
    ToolInputPasteResult? pasteResult,
  }) {
    final allowedKeys = tool.inputs.map((input) => input.key).toSet();
    final filteredRawValues = {
      for (final entry in rawValues.entries)
        if (allowedKeys.contains(entry.key)) entry.key: entry.value,
    };
    _applyInputValueBatch(
      filteredRawValues,
      preserveExistingErrors: true,
    );
    final invalidKeyErrors = {
      for (final key in filteredRawValues.keys)
        if (_inputErrors[key] != null) key: _inputErrors[key]!,
    };
    return ToolInputApplyResult(
      inputTexts: {
        ...defaultInputTexts(tool),
        ...filteredRawValues,
      },
      filledKeys: filteredRawValues.keys.toSet(),
      validKeys: {
        for (final key in filteredRawValues.keys)
          if (!invalidKeyErrors.containsKey(key)) key,
      },
      invalidKeyErrors: invalidKeyErrors,
      pasteResult: pasteResult,
    );
  }

  Future<void> loadFavorite() async {
    final ids = await toolUsageRepository.favoriteIds();
    _favorite = ids.contains(tool.id);
    notifyListeners();
  }

  void updateValue(String key, String rawValue) {
    if (_inputIsOptional(key) && rawValue.trim().isEmpty) {
      final nextErrors = {..._inputErrors}..remove(key);
      final nextValues = {..._values}..remove(key);
      final changed = !mapEquals(_inputErrors, nextErrors) ||
          !mapEquals(_values, nextValues);
      if (!changed) return;
      _inputErrors = nextErrors;
      _values = nextValues;
      _recalculate();
      notifyListeners();
      return;
    }
    final parsed = _parseInputValue(key, rawValue, _values);
    final nextErrors = {..._inputErrors};
    if (parsed.value == null) {
      nextErrors[key] = parsed.error ?? '输入无效';
      _inputErrors = nextErrors;
      notifyListeners();
      return;
    }
    nextErrors.remove(key);
    final next = parsed.value!;
    if (_values[key] == next) {
      if (!mapEquals(_inputErrors, nextErrors)) {
        _inputErrors = nextErrors;
        notifyListeners();
      }
      return;
    }
    _inputErrors = nextErrors;
    _values = {..._values, key: next};
    _recalculate();
    notifyListeners();
  }

  void updateValues(Map<String, String> rawValues) {
    _applyInputValueBatch(rawValues, preserveExistingErrors: false);
  }

  void _applyInputValueBatch(
    Map<String, String> rawValues, {
    required bool preserveExistingErrors,
  }) {
    var changed = false;
    final nextValues = {..._values};
    final nextErrors =
        preserveExistingErrors ? {..._inputErrors} : <String, String>{};
    // 中文：批量应用输入框变化，避免多个参数连续编辑时重复计算和重复通知 UI。
    // English: Apply input changes in one batch to avoid repeated recalculation and UI notifications.
    final entries = rawValues.entries.toList();
    if (tool.id == 'battery_life') {
      entries.sort((a, b) {
        if (a.key == 'voltage') return -1;
        if (b.key == 'voltage') return 1;
        return 0;
      });
    }
    for (final entry in entries) {
      if (_inputIsOptional(entry.key) && entry.value.trim().isEmpty) {
        nextErrors.remove(entry.key);
        if (nextValues.containsKey(entry.key)) {
          nextValues.remove(entry.key);
          changed = true;
        }
        continue;
      }
      final parsed = _parseInputValue(entry.key, entry.value, nextValues);
      if (parsed.value == null) {
        nextErrors[entry.key] = parsed.error ?? '输入无效';
        continue;
      }
      final next = parsed.value!;
      if (nextValues[entry.key] == next) continue;
      nextValues[entry.key] = next;
      changed = true;
    }
    final errorsChanged = !mapEquals(_inputErrors, nextErrors);
    if (!changed && !errorsChanged) return;
    _inputErrors = nextErrors;
    _values = nextValues;
    if (changed) _recalculate();
    notifyListeners();
  }

  NumericInputParseResult _parseInputValue(
    String key,
    String rawValue,
    Map<String, double> values,
  ) {
    if (tool.id == 'battery_life') {
      final battery = _parseBatteryLifeInput(key, rawValue, values);
      if (battery.value != null) return battery;
    }
    return parseNumericInputForUnit(rawValue, _inputUnit(key));
  }

  NumericInputParseResult _parseBatteryLifeInput(
    String key,
    String rawValue,
    Map<String, double> values,
  ) {
    final voltage = values['voltage'] ?? 0;
    if (key == 'capacity' && voltage > 0) {
      if (_splitUnitSuffix(rawValue, 'Wh') != null) {
        final wattHours = parseNumericInputForUnit(rawValue, 'Wh');
        if (wattHours.value != null) {
          return NumericInputParseResult(
              value: wattHours.value! * 1000 / voltage);
        }
      }
    }
    if (key == 'current' && voltage > 0) {
      if (_splitUnitSuffix(rawValue, 'W') != null) {
        final watts = parseNumericInputForUnit(rawValue, 'W');
        if (watts.value != null) {
          return NumericInputParseResult(value: watts.value! * 1000 / voltage);
        }
      }
    }
    return const NumericInputParseResult(value: null);
  }

  void resetValues() {
    _values = _defaultValues(tool);
    _inputErrors = const {};
    _recalculate();
    notifyListeners();
  }

  Future<void> toggleFavorite() async {
    final next = !_favorite;
    await toolUsageRepository.setFavorite(tool.id, next);
    _favorite = next;
    notifyListeners();
  }

  Future<ToolSaveResult> saveResult(String expression) async {
    if (hasInputErrors) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.history,
        summary: inputErrorSummary(),
      );
    }
    final item = primary;
    if (item == null) return ToolSaveResult.noResult(ToolSaveTarget.history);
    try {
      final historyId = await historyRepository.saveToolResult(
        expression: expression,
        result: _resultReportLine(item),
        toolId: tool.id,
      );
      if (historyId <= 0) {
        return ToolSaveResult.notWritten(ToolSaveTarget.history);
      }
      return ToolSaveResult.savedHistory(historyId);
    } catch (error) {
      return ToolSaveResult.failed(
        target: ToolSaveTarget.history,
        error: error,
      );
    }
  }

  Future<ToolSaveResult> saveNote() async {
    if (hasInputErrors) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.note,
        summary: inputErrorSummary(),
      );
    }
    if (primary == null) return ToolSaveResult.noResult(ToolSaveTarget.note);
    try {
      final noteId = await notesRepository.create(
        title: tool.title,
        body: noteBody(),
        description: tool.description,
      );
      if (noteId <= 0) return ToolSaveResult.notWritten(ToolSaveTarget.note);
      return ToolSaveResult.savedNote(noteId);
    } catch (error) {
      return ToolSaveResult.failed(
        target: ToolSaveTarget.note,
        error: error,
      );
    }
  }

  String inputSummary() {
    if (tool.inputs.isEmpty) return '无需输入参数';
    return tool.inputs.map(_inputReportLine).join('\n');
  }

  String resultSummary() {
    if (_results.isEmpty) return '暂无结果';
    return _results.map(_resultReportLine).join('\n');
  }

  String primaryResultLine() {
    final item = primary;
    return item == null ? '暂无结果' : _resultReportLine(item);
  }

  String resultHealthSummary() {
    if (_results.isEmpty) return '暂无计算结果';
    final issues = issueResults;
    if (issues.isNotEmpty) {
      final visible = issues.take(3).map((result) => result.label).join('、');
      final suffix = issues.length > 3 ? ' 等 ${issues.length} 项' : '';
      return '$visible$suffix 需要检查，请结合输入参数和校核提示确认。';
    }
    return '${usableResults.length} 个结果可复用，主结果 ${primaryResultLine()}';
  }

  String resultIssueSummary({int limit = 4}) {
    final issues = issueResults;
    if (issues.isEmpty) return '';
    final visibleLimit = limit <= 0 ? issues.length : limit;
    final visible = issues.take(visibleLimit).map(_resultReportLine).join('\n');
    final remaining = issues.length - visibleLimit;
    if (remaining <= 0) return visible;
    return '$visible\n另有 $remaining 项结果需要检查';
  }

  String insightSummary() {
    if (_insights.isEmpty) return '暂无校核提示';
    return _insights.join('\n');
  }

  String inputErrorSummary() {
    if (_inputErrors.isEmpty) return '';
    final byKey = {
      for (final input in tool.inputs) input.key: input,
    };
    return _inputErrors.entries.map((entry) {
      final input = byKey[entry.key];
      final label = input?.label ?? entry.key;
      final unit = input?.unit ?? '';
      final suffix = unit.isEmpty ? '' : '（$unit）';
      return '$label$suffix: ${entry.value}';
    }).join('\n');
  }

  String copyText() {
    return [
      tool.title,
      tool.description,
      '',
      if (tool.inputs.isNotEmpty) ...['输入参数:', inputSummary(), ''],
      '计算结果:',
      resultSummary(),
      '',
      '结果状态:',
      resultHealthSummary(),
      '',
      '校核:',
      insightSummary(),
      '',
      '公式: ${tool.formula}',
    ].join('\n');
  }

  String inputCopyText() {
    return [
      tool.title,
      if (tool.inputs.isNotEmpty) ...['输入参数:', inputSummary()] else '无需输入参数',
    ].join('\n');
  }

  String noteBody() {
    return [
      tool.description,
      if (tool.inputs.isNotEmpty) ...['输入参数:', inputSummary()],
      if (tool.inputs.isNotEmpty) '',
      '计算结果:',
      resultSummary(),
      '',
      '结果状态:',
      resultHealthSummary(),
      '',
      '校核:',
      insightSummary(),
      '公式: ${tool.formula}',
    ].join('\n');
  }

  String singleResultCopyText(ToolResult result) {
    return [
      tool.title,
      _resultReportLine(result),
      if (tool.inputs.isNotEmpty) ...['', '输入参数:', inputSummary()],
      '',
      '公式: ${tool.formula}',
      if (_insights.isNotEmpty) ...[
        '',
        '校核:',
        _insights.take(3).join('\n'),
      ],
    ].join('\n');
  }

  String _inputReportLine(ToolInputDefinition input) {
    final value = _values[input.key];
    if (value == null && input.optional) return '${input.label}: 未填写';
    final formatted = formatNumber(value ?? 0, precision: 8);
    return '${input.label}: $formatted${input.unit}';
  }

  String _resultReportLine(ToolResult result) {
    return '${result.label}: ${_resultValueWithUnit(result)}';
  }

  void _recalculate() {
    _results = calculateTool(tool, _values);
    _insights = buildToolInsights(tool, _values, _results);
  }

  String _inputUnit(String key) {
    return tool.inputs
            .where((input) => input.key == key)
            .map((input) => input.unit)
            .firstOrNull ??
        '';
  }

  bool _inputIsOptional(String key) {
    return tool.inputs.any((input) => input.key == key && input.optional);
  }

  bool resultNeedsAttention(ToolResult result) {
    return _resultNeedsAttention(result);
  }

  static String _resultValueWithUnit(ToolResult result) {
    final value = result.value.trim();
    final unit = result.unit.trim();
    if (unit.isEmpty || _resultNeedsAttention(result)) return value;
    return '$value$unit';
  }

  static bool _resultNeedsAttention(ToolResult result) {
    final value = result.value.trim().toLowerCase();
    if (value.isEmpty) return true;
    const exact = {
      '无效',
      '无唯一解',
      '无效边长',
      '不可逆',
      'a 不能为 0',
    };
    if (exact.contains(value)) return true;
    return value.contains('无效') ||
        value.contains('不能') ||
        value.contains('不可') ||
        value.contains('错误') ||
        value.contains('not finite') ||
        value.contains('nan') ||
        value.contains('infinity');
  }

  static String _normalizeNumericText(String rawValue) {
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
    return _stripSpecValueDecorations(normalized);
  }

  static String _stripSpecValueDecorations(String value) {
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

  static String? _extractLabeledNumericCandidate(String rawValue) {
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

  static String? _extractNominalNumericCandidate(String rawValue) {
    final lines = rawValue
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    final source = _normalizeNumericText(lines.last)
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

  static String? _extractFirstRangeQuantity(
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
      final first = _parseRangeBound(firstNumber);
      final second = _parseRangeBound(secondNumber);
      if (first == null || second == null || first > second) return null;
    }

    final unit = firstUnit.isNotEmpty ? firstUnit : secondUnit;
    return '$firstNumber$unit'.trim();
  }

  static double? _parseRangeBound(String rawValue) {
    return double.tryParse(rawValue.replaceAll(',', '').replaceAll('_', ''));
  }

  static _ParsedUnitSuffix? _splitUnitSuffix(
    String input,
    String targetUnit,
  ) {
    final targetToken = _normalizeUnitToken(targetUnit);
    final aliases = _unitAliasesForTarget(targetToken, targetUnit);
    if (aliases.isEmpty) return null;
    return _splitByAliases(input, aliases);
  }

  static _ParsedUnitSuffix? _splitAnyKnownUnitSuffix(String input) {
    return _splitByAliases(input, _allKnownUnitAliases);
  }

  static _ParsedUnitSuffix? _splitByAliases(
    String input,
    Iterable<String> aliases,
  ) {
    final compact = _normalizeUnitText(input).replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return null;
    final sorted = aliases.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final alias in sorted) {
      if (alias.isEmpty || !compact.endsWith(alias)) continue;
      final valueText = compact
          .substring(0, compact.length - alias.length)
          .replaceFirst(RegExp(r'[-_/]+$'), '');
      if (valueText.isEmpty) continue;
      return _ParsedUnitSuffix(
        valueText: valueText,
        unitToken: alias,
        unitLabel: _displayUnitAlias(alias),
      );
    }
    return null;
  }

  static _ParsedUnitSuffix? _splitPrefixUnit(
    String input,
    String targetUnit,
  ) {
    final targetToken = _normalizeUnitToken(targetUnit);
    final aliases = _unitAliasesForTarget(targetToken, targetUnit)
        .where(_supportsPrefixUnitNotation)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (aliases.isEmpty) return null;

    final compact = _normalizeUnitText(input)
        .replaceAll(',', '')
        .replaceAll(RegExp(r'\s+'), '');
    for (final alias in aliases) {
      if (!compact.startsWith(alias)) continue;
      final valueText = compact.substring(alias.length);
      if (valueText.isEmpty || !RegExp(r'^[+\-.\d]').hasMatch(valueText)) {
        continue;
      }
      return _ParsedUnitSuffix(
        valueText: valueText,
        unitToken: alias,
        unitLabel: _displayUnitAlias(alias),
      );
    }
    return null;
  }

  static bool _supportsPrefixUnitNotation(String alias) {
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

  static Set<String> _unitAliasesForTarget(
    String targetToken,
    String rawTargetUnit,
  ) {
    if (_isTemperatureTargetUnit(rawTargetUnit)) {
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

  static bool _isTemperatureTargetUnit(String unit) {
    final trimmed = unit.trim();
    return trimmed == 'K' ||
        trimmed == '℃' ||
        trimmed == '°C' ||
        trimmed == '℉' ||
        trimmed == '°F' ||
        trimmed == '°R';
  }

  static double? _convertUnitValue(
    double value,
    String sourceUnit,
    String targetUnit,
  ) {
    final sourceToken = _normalizeUnitToken(sourceUnit);
    final targetToken = _normalizeUnitToken(targetUnit);
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

  static double? _convertCompoundUnitValue(
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

  static double? _convertDecibelPowerValue(
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

  static double? _wattsFromPowerToken(double value, String sourceToken) {
    final factor = _powerFactorForToken(sourceToken);
    if (factor != null) return value * factor;
    return switch (sourceToken) {
      'dbm' => math.pow(10, value / 10).toDouble() / 1000,
      'dbw' => math.pow(10, value / 10).toDouble(),
      _ => null,
    };
  }

  static double? _convertTemperatureValue(
    double value,
    String sourceToken,
    String targetToken,
  ) {
    final source = _normalizeTemperatureToken(sourceToken);
    final target = _normalizeTemperatureToken(targetToken);
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

  static double? _parseCompositeUnitInput(String input, String targetUnit) {
    if (_isTemperatureTargetUnit(targetUnit)) return null;
    final aliases = _unitAliasesForTarget(
      _normalizeUnitToken(targetUnit),
      targetUnit,
    ).where((alias) => alias.isNotEmpty).toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (aliases.isEmpty) return null;

    final source = _normalizeUnitText(input).replaceAll(',', '');
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

      final converted = _convertUnitValue(value, unitToken, targetUnit);
      if (converted == null) return null;
      total += converted;
      count++;

      skipSeparators();
    }
    return count >= 2 ? total : null;
  }

  static String? _normalizeTemperatureToken(String token) {
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

  static double? _parseComponentMarking(String input, String targetToken) {
    final compact = _normalizeUnitText(input).replaceAll(RegExp(r'\s+'), '');
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

  static double? _parseResistanceMarking(String input) {
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

  static double? _parseCapacitanceMarking(String input) {
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

  static double? _parseInductanceMarking(String input) {
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

  static double _numberFromWholeFraction(String whole, String fraction) {
    final text = fraction.isEmpty ? whole : '$whole.$fraction';
    return double.parse(text);
  }

  static bool _isResistanceToken(String token) {
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

  static bool _isCapacitanceToken(String token) {
    return const {'f', 'uf', 'nf', 'pf'}.contains(token);
  }

  static bool _isInductanceToken(String token) {
    return const {'h', 'kh', 'mh', 'uh', 'nh', 'ph', 'megahenry'}
        .contains(token);
  }

  static double? _resistanceFactorForToken(String token) {
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

  static double? _capacitanceFactorForToken(String token) {
    return const {
      'f': 1.0,
      'millifarad': 0.001,
      'uf': 0.000001,
      'nf': 0.000000001,
      'pf': 0.000000000001,
      'megafarad': 1000000.0,
    }[token];
  }

  static double? _inductanceFactorForToken(String token) {
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

  static double? _powerFactorForToken(String token) {
    return const {
      'w': 1.0,
      'mw': 0.001,
      'kw': 1000.0,
      'megawatt': 1000000.0,
      'hp': 745.7,
    }[token];
  }

  static String _normalizeUnitText(String value) {
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

  static String _normalizeUnitToken(String unit) {
    return _normalizeUnitText(unit).replaceAll(RegExp(r'\s+'), '');
  }

  static String _displayUnitAlias(String alias) {
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

  static final Set<String> _allKnownUnitAliases = {
    for (final group in _unitGroups) ...group.keys,
    for (final group in _compoundUnitGroups) ...group.keys,
    'dbm',
    'dbw',
    'c',
    'f',
    'k',
  };

  static final Set<String> _lengthUnitAliases = _unitGroups.first.keys.toSet();

  static const List<Map<String, double>> _compoundUnitGroups = [
    {
      'l/100km': 1,
      'lper100km': 1,
      'liter/100km': 1,
      'liters/100km': 1,
      'litre/100km': 1,
      'litres/100km': 1,
      '升/百公里': 1,
      '升每百公里': 1,
    },
    {
      '元/l': 1,
      '元/升': 1,
      '元每升': 1,
      'cny/l': 1,
      'rmb/l': 1,
      'yuan/l': 1,
    },
    {
      'kg/l': 1,
      'kg/升': 1,
      '千克/升': 1,
      '千克每升': 1,
      'kgperliter': 1,
    },
  ];

  static const List<Map<String, double>> _unitGroups = [
    {
      'm': 1,
      '米': 1,
      '公尺': 1,
      'meter': 1,
      'meters': 1,
      'nm': 0.000000001,
      '纳米': 0.000000001,
      'nanometer': 0.000000001,
      'nanometers': 0.000000001,
      'nanometre': 0.000000001,
      'nanometres': 0.000000001,
      'um': 0.000001,
      '微米': 0.000001,
      'micrometer': 0.000001,
      'micrometers': 0.000001,
      'micrometre': 0.000001,
      'micrometres': 0.000001,
      'km': 1000,
      '公里': 1000,
      '千米': 1000,
      'megameter': 1000000,
      'megameters': 1000000,
      'megametre': 1000000,
      'megametres': 1000000,
      '兆米': 1000000,
      'cm': 0.01,
      '厘米': 0.01,
      'mm': 0.001,
      '毫米': 0.001,
      'in': 0.0254,
      'inch': 0.0254,
      'inches': 0.0254,
      '"': 0.0254,
      '″': 0.0254,
      '英寸': 0.0254,
      'ft': 0.3048,
      'foot': 0.3048,
      'feet': 0.3048,
      "'": 0.3048,
      '′': 0.3048,
      '英尺': 0.3048,
      'yd': 0.9144,
      'yard': 0.9144,
      'yards': 0.9144,
      '码': 0.9144,
      'mi': 1609.344,
      'mile': 1609.344,
      'miles': 1609.344,
      '英里': 1609.344,
    },
    {
      'm2': 1,
      '平方米': 1,
      '平米': 1,
      '㎡': 1,
      'km2': 1000000,
      '平方公里': 1000000,
      '平方千米': 1000000,
      'sqkm': 1000000,
      'squarekilometer': 1000000,
      'squarekilometers': 1000000,
      'squarekilometre': 1000000,
      'squarekilometres': 1000000,
      'cm2': 0.0001,
      '平方厘米': 0.0001,
      '平方公分': 0.0001,
      'mm2': 0.000001,
      '平方毫米': 0.000001,
      'ha': 10000,
      'hectare': 10000,
      'hectares': 10000,
      '公顷': 10000,
      '亩': 666.6666666666666,
      'mu': 666.6666666666666,
      'acre': 4046.8564224,
      'acres': 4046.8564224,
      '英亩': 4046.8564224,
      'ft2': 0.09290304,
      'sqft': 0.09290304,
      'squarefoot': 0.09290304,
      'squarefeet': 0.09290304,
      '平方英尺': 0.09290304,
      'in2': 0.00064516,
      'sqin': 0.00064516,
      'squareinch': 0.00064516,
      'squareinches': 0.00064516,
      '平方英寸': 0.00064516,
      'yd2': 0.83612736,
      'sqyd': 0.83612736,
      'squareyard': 0.83612736,
      'squareyards': 0.83612736,
      '平方码': 0.83612736,
    },
    {
      'm4': 1,
      '米4': 1,
      'cm4': 0.00000001,
      '厘米4': 0.00000001,
      '公分4': 0.00000001,
      'mm4': 0.000000000001,
      '毫米4': 0.000000000001,
      'in4': 0.0000004162314256,
      'inch4': 0.0000004162314256,
      '英寸4': 0.0000004162314256,
    },
    {
      'm3': 1,
      '立方米': 1,
      'l': 0.001,
      '升': 0.001,
      '公升': 0.001,
      'liter': 0.001,
      'liters': 0.001,
      'litre': 0.001,
      'litres': 0.001,
      'ml': 0.000001,
      '毫升': 0.000001,
      'milliliter': 0.000001,
      'milliliters': 0.000001,
      'millilitre': 0.000001,
      'millilitres': 0.000001,
      'mm3': 0.000000001,
      '立方毫米': 0.000000001,
      'cubicmillimeter': 0.000000001,
      'cubicmillimeters': 0.000000001,
      'cubicmillimetre': 0.000000001,
      'cubicmillimetres': 0.000000001,
      'cm3': 0.000001,
      '立方厘米': 0.000001,
      'cubiccentimeter': 0.000001,
      'cubiccentimeters': 0.000001,
      'cubiccentimetre': 0.000001,
      'cubiccentimetres': 0.000001,
      'cc': 0.000001,
      'ft3': 0.0283168,
      'cubicfoot': 0.0283168,
      'cubicfeet': 0.0283168,
      'cuft': 0.0283168,
      'in3': 0.000016387064,
      'cubicinch': 0.000016387064,
      'cubicinches': 0.000016387064,
      'cuin': 0.000016387064,
      '立方英寸': 0.000016387064,
      'yd3': 0.764554857984,
      'cubicyard': 0.764554857984,
      'cubicyards': 0.764554857984,
      'cuyd': 0.764554857984,
      '立方码': 0.764554857984,
      'gal': 0.003785411784,
      'gallon': 0.003785411784,
      'gallons': 0.003785411784,
      'usgallon': 0.003785411784,
      'usgallons': 0.003785411784,
      '加仑': 0.003785411784,
      'qt': 0.000946352946,
      'quart': 0.000946352946,
      'quarts': 0.000946352946,
      '夸脱': 0.000946352946,
      'pt': 0.000473176473,
      'pint': 0.000473176473,
      'pints': 0.000473176473,
      '品脱': 0.000473176473,
      'floz': 0.0000295735295625,
      'fluidounce': 0.0000295735295625,
      'fluidounces': 0.0000295735295625,
      '液盎司': 0.0000295735295625,
      'cup': 0.0002365882365,
      'cups': 0.0002365882365,
      '杯': 0.0002365882365,
      'tbsp': 0.00001478676478125,
      'tablespoon': 0.00001478676478125,
      'tablespoons': 0.00001478676478125,
      '汤匙': 0.00001478676478125,
      'tsp': 0.00000492892159375,
      'teaspoon': 0.00000492892159375,
      'teaspoons': 0.00000492892159375,
      '茶匙': 0.00000492892159375,
    },
    {
      'kg': 1,
      '千克': 1,
      '公斤': 1,
      'kilogram': 1,
      'kilograms': 1,
      'g': 0.001,
      '克': 0.001,
      'gram': 0.001,
      'grams': 0.001,
      'mg': 0.000001,
      '毫克': 0.000001,
      'milligram': 0.000001,
      'milligrams': 0.000001,
      'megagram': 1000,
      'megagrams': 1000,
      't': 1000,
      'tonne': 1000,
      'tonnes': 1000,
      'metricton': 1000,
      'metrictons': 1000,
      '吨': 1000,
      '公吨': 1000,
      'lb': 0.45359237,
      'lbs': 0.45359237,
      'pound': 0.45359237,
      'pounds': 0.45359237,
      'oz': 0.028349523125,
      'ounce': 0.028349523125,
      'ounces': 0.028349523125,
      '斤': 0.5,
    },
    {
      'pa': 1,
      '帕': 1,
      'pascal': 1,
      'pascals': 1,
      'millipascal': 0.001,
      'millipascals': 0.001,
      '毫帕': 0.001,
      'kpa': 1000,
      '千帕': 1000,
      'kilopascal': 1000,
      'kilopascals': 1000,
      'mpa': 1000000,
      '兆帕': 1000000,
      'megapascal': 1000000,
      'megapascals': 1000000,
      'gpa': 1000000000,
      'gigapascal': 1000000000,
      'gigapascals': 1000000000,
      '吉帕': 1000000000,
      'bar': 100000,
      'bars': 100000,
      'mbar': 100,
      'millibar': 100,
      'millibars': 100,
      '毫巴': 100,
      'psi': 6894.757293,
      'atm': 101325,
      'atmosphere': 101325,
      'atmospheres': 101325,
      '大气压': 101325,
      'kgf/cm2': 98066.5,
      'kg/cm2': 98066.5,
      '公斤力/平方厘米': 98066.5,
      '千克力/平方厘米': 98066.5,
      '公斤/平方厘米': 98066.5,
      'n/mm2': 1000000,
      '牛/平方毫米': 1000000,
      'kgf/mm2': 9806650,
      '公斤力/平方毫米': 9806650,
      'mmhg': 133.322368,
      '毫米汞柱': 133.322368,
    },
    {
      'm/s': 1,
      'meter/second': 1,
      'meters/second': 1,
      'meterpersecond': 1,
      'meterspersecond': 1,
      '米/秒': 1,
      '米每秒': 1,
      'km/h': 1 / 3.6,
      'kmh': 1 / 3.6,
      'kilometer/hour': 1 / 3.6,
      'kilometers/hour': 1 / 3.6,
      'kilometre/hour': 1 / 3.6,
      'kilometres/hour': 1 / 3.6,
      'kilometerperhour': 1 / 3.6,
      'kilometersperhour': 1 / 3.6,
      'kilometreperhour': 1 / 3.6,
      'kilometresperhour': 1 / 3.6,
      '公里/小时': 1 / 3.6,
      '公里每小时': 1 / 3.6,
      '千米/小时': 1 / 3.6,
      '千米每小时': 1 / 3.6,
      'kph': 1 / 3.6,
      'mph': 0.44704,
      'mile/hour': 0.44704,
      'miles/hour': 0.44704,
      'mileperhour': 0.44704,
      'milesperhour': 0.44704,
      'ft/s': 0.3048,
      'ft/sec': 0.3048,
      'foot/second': 0.3048,
      'feet/second': 0.3048,
      'footpersecond': 0.3048,
      'feetpersecond': 0.3048,
      'm/min': 1 / 60,
      'meter/min': 1 / 60,
      'meters/min': 1 / 60,
      'meter/minute': 1 / 60,
      'meters/minute': 1 / 60,
      'meterperminute': 1 / 60,
      'metersperminute': 1 / 60,
      '米/分钟': 1 / 60,
      '米每分钟': 1 / 60,
      'cm/s': 0.01,
      'centimeter/second': 0.01,
      'centimeters/second': 0.01,
      'centimetre/second': 0.01,
      'centimetres/second': 0.01,
      'centimeterpersecond': 0.01,
      'centimeterspersecond': 0.01,
      '厘米/秒': 0.01,
      '厘米每秒': 0.01,
      'kn': 0.5144444444444445,
      'knot': 0.5144444444444445,
      'knots': 0.5144444444444445,
      '节': 0.5144444444444445,
      '海里/小时': 0.5144444444444445,
      '海里每小时': 0.5144444444444445,
    },
    {
      'v': 1,
      '伏': 1,
      '伏特': 1,
      'volt': 1,
      'volts': 1,
      'vdc': 1,
      'vac': 1,
      'mv': 0.001,
      '毫伏': 0.001,
      'millivolt': 0.001,
      'millivolts': 0.001,
      'uv': 0.000001,
      '微伏': 0.000001,
      'kv': 1000,
      '千伏': 1000,
      'kilovolt': 1000,
      'kilovolts': 1000,
      'megavolt': 1000000,
      'megavolts': 1000000,
      '兆伏': 1000000,
    },
    {
      'hz': 1,
      '赫兹': 1,
      'hertz': 1,
      'millihertz': 0.001,
      'millihertzs': 0.001,
      '毫赫': 0.001,
      'khz': 1000,
      '千赫': 1000,
      'kilohertz': 1000,
      'mhz': 1000000,
      '兆赫': 1000000,
      'megahertz': 1000000,
      'ghz': 1000000000,
      '吉赫': 1000000000,
      'gigahertz': 1000000000,
      'terahertz': 1000000000000,
      '太赫兹': 1000000000000,
    },
    {
      'b': 1,
      'byte': 1,
      'bytes': 1,
      '字节': 1,
      '位元组': 1,
      'kb': 1000,
      'kilobyte': 1000,
      'kilobytes': 1000,
      'kib': 1024,
      'kibibyte': 1024,
      'kibibytes': 1024,
      '千字节': 1000,
      '千位元组': 1000,
      '二进制千字节': 1024,
      '二进制千位元组': 1024,
      'mb': 1000000,
      'megabyte': 1000000,
      'megabytes': 1000000,
      'mib': 1048576,
      'mebibyte': 1048576,
      'mebibytes': 1048576,
      '兆字节': 1000000,
      '兆位元组': 1000000,
      '二进制兆字节': 1048576,
      '二进制兆位元组': 1048576,
      'gb': 1000000000,
      'gigabyte': 1000000000,
      'gigabytes': 1000000000,
      'gib': 1073741824,
      'gibibyte': 1073741824,
      'gibibytes': 1073741824,
      '吉字节': 1000000000,
      '吉位元组': 1000000000,
      '二进制吉字节': 1073741824,
      '二进制吉位元组': 1073741824,
      'tb': 1000000000000,
      'terabyte': 1000000000000,
      'terabytes': 1000000000000,
      'tib': 1099511627776,
      'tebibyte': 1099511627776,
      'tebibytes': 1099511627776,
      '太字节': 1000000000000,
      '太位元组': 1000000000000,
      '二进制太字节': 1099511627776,
      '二进制太位元组': 1099511627776,
      'bit': 0.125,
      'bits': 0.125,
      '比特': 0.125,
      '位': 0.125,
      'kbit': 125,
      'kbits': 125,
      'kilobit': 125,
      'kilobits': 125,
      '千比特': 125,
      'mbit': 125000,
      'mbits': 125000,
      'megabit': 125000,
      'megabits': 125000,
      '兆比特': 125000,
      'gbit': 125000000,
      'gbits': 125000000,
      'gigabit': 125000000,
      'gigabits': 125000000,
      '吉比特': 125000000,
      'tbit': 125000000000,
      'tbits': 125000000000,
      'terabit': 125000000000,
      'terabits': 125000000000,
      '太比特': 125000000000,
    },
    {
      's': 1,
      'sec': 1,
      'second': 1,
      'seconds': 1,
      'ms': 0.001,
      'min': 60,
      'h': 3600,
      'hr': 3600,
      'hour': 3600,
      'hours': 3600,
      'day': 86400,
      'days': 86400,
      'd': 86400,
      'week': 604800,
      'weeks': 604800,
      'wk': 604800,
      'wks': 604800,
      '周': 604800,
      '星期': 604800,
    },
    {
      'm/s2': 1,
      'meter/second2': 1,
      'meters/second2': 1,
      'meterpersecond2': 1,
      'meterspersecond2': 1,
      'meterpersecondsquared': 1,
      'meterspersecondsquared': 1,
      '米/秒2': 1,
      '米每秒2': 1,
      '米/秒/秒': 1,
      'g': 9.80665,
      'cm/s2': 0.01,
      'centimeter/second2': 0.01,
      'centimeters/second2': 0.01,
      'centimetre/second2': 0.01,
      'centimetres/second2': 0.01,
      'centimeterpersecond2': 0.01,
      'centimeterspersecond2': 0.01,
      'centimeterpersecondsquared': 0.01,
      'centimeterspersecondsquared': 0.01,
      '厘米/秒2': 0.01,
      '厘米每秒2': 0.01,
      'galileo': 0.01,
      'galileos': 0.01,
      'gal': 0.01,
      '伽': 0.01,
      'ft/s2': 0.3048,
      'ft/sec2': 0.3048,
      'foot/second2': 0.3048,
      'feet/second2': 0.3048,
      'footpersecond2': 0.3048,
      'feetpersecond2': 0.3048,
      'footpersecondsquared': 0.3048,
      'feetpersecondsquared': 0.3048,
    },
    {
      'n': 1,
      '牛': 1,
      '牛顿': 1,
      'newton': 1,
      'newtons': 1,
      'millinewton': 0.001,
      'millinewtons': 0.001,
      '毫牛': 0.001,
      '毫牛顿': 0.001,
      'kn': 1000,
      '千牛': 1000,
      'kilonewton': 1000,
      'kilonewtons': 1000,
      'meganewton': 1000000,
      'meganewtons': 1000000,
      '兆牛': 1000000,
      '兆牛顿': 1000000,
      'kgf': 9.80665,
      '公斤力': 9.80665,
      '千克力': 9.80665,
      'lbf': 4.448221615,
      'poundforce': 4.448221615,
      'poundsforce': 4.448221615,
      '磅力': 4.448221615,
    },
    {
      'w': 1,
      '瓦': 1,
      '瓦特': 1,
      'watt': 1,
      'watts': 1,
      'mw': 0.001,
      '毫瓦': 0.001,
      'milliwatt': 0.001,
      'milliwatts': 0.001,
      'kw': 1000,
      '千瓦': 1000,
      'kilowatt': 1000,
      'kilowatts': 1000,
      'megawatt': 1000000,
      'megawatts': 1000000,
      '兆瓦': 1000000,
      'hp': 745.7,
      '马力': 745.7,
    },
    {
      'j': 1,
      '焦': 1,
      '焦耳': 1,
      'joule': 1,
      'joules': 1,
      'kj': 1000,
      '千焦': 1000,
      'kilojoule': 1000,
      'kilojoules': 1000,
      'cal': 4.184,
      'calorie': 4.184,
      'calories': 4.184,
      '卡': 4.184,
      '卡路里': 4.184,
      'kcal': 4184,
      'kilocalorie': 4184,
      'kilocalories': 4184,
      '千卡': 4184,
      '大卡': 4184,
      'btu': 1055.05585262,
      'btus': 1055.05585262,
      'britishthermalunit': 1055.05585262,
      'britishthermalunits': 1055.05585262,
      '英热单位': 1055.05585262,
      'ev': 1.602176634e-19,
      'electronvolt': 1.602176634e-19,
      'electronvolts': 1.602176634e-19,
      '电子伏特': 1.602176634e-19,
      'milliwatthour': 3.6,
      'milliwatthours': 3.6,
      'milliwatt-hour': 3.6,
      'milliwatt-hours': 3.6,
      '毫瓦时': 3.6,
      'wh': 3600,
      '瓦时': 3600,
      'watthour': 3600,
      'watthours': 3600,
      'watt-hour': 3600,
      'watt-hours': 3600,
      'kwh': 3600000,
      '千瓦时': 3600000,
      'kilowatthour': 3600000,
      'kilowatthours': 3600000,
      'kilowatt-hour': 3600000,
      'kilowatt-hours': 3600000,
      '度': 3600000,
      'megawatthour': 3600000000,
      'megawatthours': 3600000000,
      'megawatt-hour': 3600000000,
      'megawatt-hours': 3600000000,
      '兆瓦时': 3600000000,
    },
    {
      'deg': 1,
      'degree': 1,
      'degrees': 1,
      '°': 1,
      '度': 1,
      'rad': 180 / 3.141592653589793,
      'radian': 180 / 3.141592653589793,
      'radians': 180 / 3.141592653589793,
      '弧度': 180 / 3.141592653589793,
      'turn': 360,
      'turns': 360,
      '圈': 360,
      'grad': 0.9,
      'grads': 0.9,
      'gon': 0.9,
      'gons': 0.9,
      '百分度': 0.9,
      'arcmin': 1 / 60,
      'arcminute': 1 / 60,
      'arcminutes': 1 / 60,
      '′': 1 / 60,
      '角分': 1 / 60,
      'arcsec': 1 / 3600,
      'arcsecond': 1 / 3600,
      'arcseconds': 1 / 3600,
      '″': 1 / 3600,
      '角秒': 1 / 3600,
    },
    {
      'a': 1,
      '安': 1,
      '安培': 1,
      'amp': 1,
      'amps': 1,
      'ampere': 1,
      'amperes': 1,
      'ma': 0.001,
      '毫安': 0.001,
      'milliamp': 0.001,
      'milliamps': 0.001,
      'milliampere': 0.001,
      'milliamperes': 0.001,
      'ua': 0.000001,
      '微安': 0.000001,
      'microamp': 0.000001,
      'microamps': 0.000001,
      'microampere': 0.000001,
      'microamperes': 0.000001,
      'na': 0.000000001,
      '纳安': 0.000000001,
      'nanoamp': 0.000000001,
      'nanoamps': 0.000000001,
      'nanoampere': 0.000000001,
      'nanoamperes': 0.000000001,
      'ka': 1000,
      '千安': 1000,
      '千安培': 1000,
      'kiloamp': 1000,
      'kiloamps': 1000,
      'kiloampere': 1000,
      'kiloamperes': 1000,
      'megaamp': 1000000,
      'megaamps': 1000000,
      'megaampere': 1000000,
      'megaamperes': 1000000,
      '兆安': 1000000,
      '兆安培': 1000000,
    },
    {
      'ohm': 1,
      '微欧': 0.000001,
      '微欧姆': 0.000001,
      'microohm': 0.000001,
      'microohms': 0.000001,
      'milliohm': 0.001,
      'milliohms': 0.001,
      'kohm': 1000,
      'kiloohm': 1000,
      'kiloohms': 1000,
      'mohm': 1000000,
      'megohm': 1000000,
      'megohms': 1000000,
      '兆欧': 1000000,
      '兆欧姆': 1000000,
      'gohm': 1000000000,
      'gigaohm': 1000000000,
      'gigaohms': 1000000000,
      '吉欧': 1000000000,
      '吉欧姆': 1000000000,
      'r': 1,
    },
    {
      'f': 1,
      '法': 1,
      '法拉': 1,
      'millifarad': 0.001,
      'millifarads': 0.001,
      '毫法': 0.001,
      '毫法拉': 0.001,
      'uf': 0.000001,
      '微法': 0.000001,
      'nf': 0.000000001,
      '纳法': 0.000000001,
      'pf': 0.000000000001,
      '皮法': 0.000000000001,
      'megafarad': 1000000,
      'megafarads': 1000000,
      '兆法': 1000000,
      '兆法拉': 1000000,
    },
    {
      'h': 1,
      '亨': 1,
      '亨利': 1,
      'kh': 1000,
      '千亨': 1000,
      '千亨利': 1000,
      'kilohenry': 1000,
      'kilohenrys': 1000,
      'mh': 0.001,
      '毫亨': 0.001,
      'uh': 0.000001,
      '微亨': 0.000001,
      'nh': 0.000000001,
      '纳亨': 0.000000001,
      'nanohenry': 0.000000001,
      'nanohenrys': 0.000000001,
      'ph': 0.000000000001,
      '皮亨': 0.000000000001,
      'picohenry': 0.000000000001,
      'picohenrys': 0.000000000001,
      'megahenry': 1000000,
      'megahenrys': 1000000,
      '兆亨': 1000000,
      '兆亨利': 1000000,
    },
    {
      'n.m': 1,
      'n*m': 1,
      'nm': 1,
      'newtonmeter': 1,
      'newtonmeters': 1,
      'newton-meters': 1,
      'newton-meter': 1,
      '牛米': 1,
      '牛.米': 1,
      '牛顿米': 1,
      '牛顿.米': 1,
      'kn.m': 1000,
      'kn*m': 1000,
      'knm': 1000,
      'kilonewtonmeter': 1000,
      'kilonewtonmeters': 1000,
      'kilonewton-meter': 1000,
      'kilonewton-meters': 1000,
      '千牛米': 1000,
      '千牛.米': 1000,
      'millinewton.m': 0.001,
      'millinewton*m': 0.001,
      'mn.m': 0.001,
      'mn*m': 0.001,
      'mnm': 0.001,
      'millinewtonmeter': 0.001,
      'millinewtonmeters': 0.001,
      'millinewton-meter': 0.001,
      'millinewton-meters': 0.001,
      '毫牛米': 0.001,
      '毫牛.米': 0.001,
      'n.mm': 0.001,
      'n*mm': 0.001,
      'nmm': 0.001,
      '牛.毫米': 0.001,
      'kgf.m': 9.80665,
      'kgf*m': 9.80665,
      'kg.m': 9.80665,
      '公斤力.米': 9.80665,
      '公斤.米': 9.80665,
      'kgf.cm': 0.0980665,
      'kgf*cm': 0.0980665,
      'kg.cm': 0.0980665,
      '公斤力.厘米': 0.0980665,
      '公斤.厘米': 0.0980665,
      'lbf.ft': 1.355817948,
      'lbf*ft': 1.355817948,
      'lb.ft': 1.355817948,
      'lb-ft': 1.355817948,
      '磅力.英尺': 1.355817948,
      'lbf.in': 0.112984829,
      'lbf*in': 0.112984829,
      'lb.in': 0.112984829,
      'lb-in': 0.112984829,
      '磅力.英寸': 0.112984829,
      'ozf.in': 0.0070615518125,
      'ozf*in': 0.0070615518125,
      'oz.in': 0.0070615518125,
      'oz-in': 0.0070615518125,
      'ounceforceinch': 0.0070615518125,
      'ounceforceinches': 0.0070615518125,
      '盎司力.英寸': 0.0070615518125,
    },
    {
      'l/min': 1,
      'lpm': 1,
      '升/分钟': 1,
      '升每分钟': 1,
      'liter/min': 1,
      'liters/min': 1,
      'litre/min': 1,
      'litres/min': 1,
      'literperminute': 1,
      'litersperminute': 1,
      'litreperminute': 1,
      'litresperminute': 1,
      'l/s': 60,
      '升/秒': 60,
      '升每秒': 60,
      'liter/s': 60,
      'liters/s': 60,
      'literpersecond': 60,
      'literspersecond': 60,
      'l/h': 1 / 60,
      'lph': 1 / 60,
      '升/小时': 1 / 60,
      '升每小时': 1 / 60,
      'liter/hour': 1 / 60,
      'liters/hour': 1 / 60,
      'literperhour': 1 / 60,
      'litersperhour': 1 / 60,
      'ml/min': 0.001,
      'mlpm': 0.001,
      '毫升/分钟': 0.001,
      '毫升每分钟': 0.001,
      'milliliter/min': 0.001,
      'milliliters/min': 0.001,
      'millilitre/min': 0.001,
      'millilitres/min': 0.001,
      'milliliterperminute': 0.001,
      'millilitersperminute': 0.001,
      'millilitreperminute': 0.001,
      'millilitresperminute': 0.001,
      'm3/h': 1000 / 60,
      '立方米/小时': 1000 / 60,
      '立方米每小时': 1000 / 60,
      'm3/min': 1000,
      '立方米/分钟': 1000,
      '立方米每分钟': 1000,
      'm3/s': 60000,
      '立方米/秒': 60000,
      '立方米每秒': 60000,
      'gpm': 3.78541,
      'gallon/min': 3.785411784,
      'gallons/min': 3.785411784,
      'gallonperminute': 3.785411784,
      'gallonsperminute': 3.785411784,
      '加仑/分钟': 3.785411784,
      '加仑每分钟': 3.785411784,
      'cfm': 28.316846592,
      'cubicfoot/min': 28.316846592,
      'cubicfeet/min': 28.316846592,
      'cubicfootperminute': 28.316846592,
      'cubicfeetperminute': 28.316846592,
      'ft3/min': 28.316846592,
    },
    {
      'g/cm3': 1,
      'g/cc': 1,
      '克/立方厘米': 1,
      '克每立方厘米': 1,
      'kg/m3': 0.001,
      '千克/立方米': 0.001,
      '千克每立方米': 0.001,
    },
    {
      '元': 1,
      '¥': 1,
      '￥': 1,
      'cny': 1,
      'rmb': 1,
      '人民币': 1,
      'yuan': 1,
      'yuans': 1,
      '万元': 10000,
    },
    {
      'mah': 1,
      'ma.h': 1,
      'milliamp-hour': 1,
      'milliamp-hours': 1,
      'milliamperehour': 1,
      'milliamperehours': 1,
      'milliampere-hour': 1,
      'milliampere-hours': 1,
      'ah': 1000,
      'a.h': 1000,
      'amp-hour': 1000,
      'amp-hours': 1000,
      'amperehour': 1000,
      'amperehours': 1000,
      'ampere-hour': 1000,
      'ampere-hours': 1000,
      'uah': 0.001,
      'ua.h': 0.001,
      'microamp-hour': 0.001,
      'microamp-hours': 0.001,
      'microamperehour': 0.001,
      'microamperehours': 0.001,
      'microampere-hour': 0.001,
      'microampere-hours': 0.001,
    },
    {
      '%': 1,
      'percent': 1,
    },
    {
      'rpm': 1,
      'r/min': 1,
      'rev/min': 1,
      'revs/min': 1,
      'revolution/min': 1,
      'revolutions/min': 1,
      'revolutionperminute': 1,
      'revolutionsperminute': 1,
      'bit': 1,
      'bits': 1,
      'i': 1,
      '齿': 1,
      'oz': 1,
      '年': 1,
      '期': 1,
      '天': 1,
      'mol': 1,
      'g/mol': 1,
      'mol/l': 1,
      'j/kgc': 1,
      'c/w': 1,
      'k/w': 1,
      'kelvin/w': 1,
      'kelvins/w': 1,
      'kelvinperwatt': 1,
      'kelvinsperwatt': 1,
      'n/mm': 1,
      'mm/rev': 1,
      'mm/turn': 1,
      'mm/revolution': 1,
      'mmperrev': 1,
      'mmperturn': 1,
      'mmperrevolution': 1,
      '元/kwh': 1,
      '元/l': 1,
    },
  ];
}

class NumericInputParseResult {
  const NumericInputParseResult({required this.value, this.error});

  final double? value;
  final String? error;
}

class ToolInputPasteResult {
  const ToolInputPasteResult({
    required this.values,
    required this.ignoredSegments,
    required this.ambiguousSegments,
    required this.duplicateKeys,
    required this.segmentCount,
  });

  factory ToolInputPasteResult.empty() => const ToolInputPasteResult(
        values: {},
        ignoredSegments: [],
        ambiguousSegments: [],
        duplicateKeys: {},
        segmentCount: 0,
      );

  final Map<String, String> values;
  final List<String> ignoredSegments;
  final List<String> ambiguousSegments;
  final Set<String> duplicateKeys;
  final int segmentCount;

  bool get hasValues => values.isNotEmpty;

  int get matchedCount => values.length;

  int get issueCount =>
      ignoredSegments.length + ambiguousSegments.length + duplicateKeys.length;

  bool get hasIssues => issueCount > 0;

  String summaryForTool(ToolDefinition tool) {
    if (!hasValues) {
      if (ambiguousSegments.isNotEmpty) {
        return '剪贴板里的参数单位有歧义，未自动填入';
      }
      if (ignoredSegments.isNotEmpty) {
        return '剪贴板里有数字，但没有匹配到本工具参数';
      }
      return '剪贴板里没有识别到本工具的参数';
    }
    final parts = <String>['已粘贴 $matchedCount 个参数'];
    if (duplicateKeys.isNotEmpty) {
      parts.add('重复字段已取最后值：${_inputLabels(tool, duplicateKeys).join('、')}');
    }
    if (ambiguousSegments.isNotEmpty) {
      parts.add('跳过 ${ambiguousSegments.length} 条歧义值');
    }
    if (ignoredSegments.isNotEmpty) {
      parts.add('忽略 ${ignoredSegments.length} 条未匹配值');
    }
    return parts.join('，');
  }

  static List<String> _inputLabels(ToolDefinition tool, Iterable<String> keys) {
    final byKey = {for (final input in tool.inputs) input.key: input.label};
    return keys.map((key) => byKey[key] ?? key).toList(growable: false);
  }
}

class ToolInputApplyResult {
  const ToolInputApplyResult({
    required this.inputTexts,
    required this.filledKeys,
    required this.validKeys,
    required this.invalidKeyErrors,
    this.pasteResult,
  });

  final Map<String, String> inputTexts;
  final Set<String> filledKeys;
  final Set<String> validKeys;
  final Map<String, String> invalidKeyErrors;
  final ToolInputPasteResult? pasteResult;

  bool get hasValues => filledKeys.isNotEmpty;

  bool get hasInvalidValues => invalidKeyErrors.isNotEmpty;

  bool get hasValidValues => validKeys.isNotEmpty;

  String summaryForTool(ToolDefinition tool) {
    final paste = pasteResult;
    if (!hasValues) {
      return paste?.summaryForTool(tool) ?? '没有可应用的参数';
    }
    final parts = <String>[
      if (hasValidValues)
        '已应用 ${validKeys.length} 个参数'
      else
        '识别到 ${filledKeys.length} 个参数但都需要修正',
    ];
    if (hasInvalidValues) {
      parts.add('需修正：${_inputLabels(tool, invalidKeyErrors.keys).join('、')}');
    }
    if (paste != null) {
      if (paste.duplicateKeys.isNotEmpty) {
        parts.add(
            '重复字段已取最后值：${_inputLabels(tool, paste.duplicateKeys).join('、')}');
      }
      if (paste.ambiguousSegments.isNotEmpty) {
        parts.add('跳过 ${paste.ambiguousSegments.length} 条歧义值');
      }
      if (paste.ignoredSegments.isNotEmpty) {
        parts.add('忽略 ${paste.ignoredSegments.length} 条未匹配值');
      }
    }
    return parts.join('，');
  }

  static List<String> _inputLabels(ToolDefinition tool, Iterable<String> keys) {
    final byKey = {for (final input in tool.inputs) input.key: input.label};
    return keys.map((key) => byKey[key] ?? key).toList(growable: false);
  }
}

class _ParsedUnitSuffix {
  const _ParsedUnitSuffix({
    required this.valueText,
    required this.unitToken,
    required this.unitLabel,
  });

  final String valueText;
  final String unitToken;
  final String unitLabel;
}
