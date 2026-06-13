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

import '../../core/units/tool_unit_conversion.dart';
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
    final normalized = ToolUnitConversion.normalizeNumericText(rawValue).replaceAll(',', '');
    final parsed = _parsePlainNumericInput(normalized);
    if (parsed.value != null) return parsed;

    final labeled = ToolUnitConversion.extractLabeledNumericCandidate(rawValue);
    if (labeled != null) {
      final labeledParsed = _parsePlainNumericInput(
          ToolUnitConversion.normalizeNumericText(labeled).replaceAll(',', ''));
      if (labeledParsed.value != null) return labeledParsed;
      final labeledNominal = ToolUnitConversion.extractNominalNumericCandidate(labeled);
      if (labeledNominal != null) {
        final nominalParsed = _parsePlainNumericInput(
            ToolUnitConversion.normalizeNumericText(labeledNominal).replaceAll(',', ''));
        if (nominalParsed.value != null) return nominalParsed;
      }
    }

    final nominal = ToolUnitConversion.extractNominalNumericCandidate(rawValue);
    if (nominal != null) {
      final nominalParsed = _parsePlainNumericInput(
          ToolUnitConversion.normalizeNumericText(nominal).replaceAll(',', ''));
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
    final normalized = ToolUnitConversion.normalizeNumericText(rawValue);
    if (normalized.isEmpty) {
      return const NumericInputParseResult(value: null, error: '请输入数值');
    }
    if (targetUnit.trim().isEmpty) return parseNumericInputDetailed(rawValue);
    if (ToolUnitConversion.normalizeUnitToken(targetUnit) == '%') {
      return _parsePercentInput(normalized);
    }

    final parsed = _parseNumericInputForUnitNormalized(normalized, targetUnit);
    if (parsed.value != null) return parsed;

    final labeled = ToolUnitConversion.extractLabeledNumericCandidate(rawValue);
    if (labeled != null) {
      final labeledParsed = _parseNumericInputForUnitNormalized(
        ToolUnitConversion.normalizeNumericText(labeled),
        targetUnit,
      );
      if (labeledParsed.value != null) return labeledParsed;
      final labeledNominal = ToolUnitConversion.extractNominalNumericCandidate(labeled);
      if (labeledNominal != null) {
        final nominalParsed = _parseNumericInputForUnitNormalized(
          ToolUnitConversion.normalizeNumericText(labeledNominal),
          targetUnit,
        );
        if (nominalParsed.value != null) return nominalParsed;
      }
    }

    final nominal = ToolUnitConversion.extractNominalNumericCandidate(rawValue);
    if (nominal != null) {
      final nominalParsed = _parseNumericInputForUnitNormalized(
        ToolUnitConversion.normalizeNumericText(nominal),
        targetUnit,
      );
      if (nominalParsed.value != null) return nominalParsed;
      final suffix =
          ToolUnitConversion.splitUnitSuffix(ToolUnitConversion.normalizeNumericText(nominal), targetUnit);
      if (suffix != null) {
        final parsedValue = parseNumericInputDetailed(suffix.valueText).value;
        if (parsedValue != null) {
          final converted =
              ToolUnitConversion.convertUnitValue(parsedValue, suffix.unitToken, targetUnit);
          if (converted != null) {
            return NumericInputParseResult(value: converted);
          }
        }
      }
    }
    return parsed;
  }

  static NumericInputParseResult _parsePercentInput(String normalized) {
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
        final parsed = parseNumericInputDetailed(rangeValue);
        final value = parsed.value;
        if (value != null) {
          final converted =
              ToolUnitConversion.convertUnitValue(value, prefixedUnit.unitToken, targetUnit);
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
          parseNumericInputDetailed(rangeValue ?? unitSuffix.valueText);
      var value = parsed.value;
      if (value == null) {
        final nominal = ToolUnitConversion.extractNominalNumericCandidate(unitSuffix.valueText);
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
    return parseNumericInputDetailed(normalized);
  }

  static NumericInputParseResult? _parseRangeInputForUnit(
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

  static double? _parseAwgInput(String input, String targetUnit) {
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

  static double? _parseConductorAreaInput(String input, String targetUnit) {
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
    final compact = ToolUnitConversion.normalizeUnitText(input).replaceAll(RegExp(r'\s+'), '');
    final suffix = ToolUnitConversion.splitByAliases(compact, ToolUnitConversion.lengthUnitAliases);
    if (suffix != null) {
      final parsed = parseNumericInputDetailed(suffix.valueText);
      final value = parsed.value;
      if (value == null) return null;
      return ToolUnitConversion.convertUnitValue(value, suffix.unitToken, 'mm');
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
      if (ToolUnitConversion.splitUnitSuffix(rawValue, 'Wh') != null) {
        final wattHours = parseNumericInputForUnit(rawValue, 'Wh');
        if (wattHours.value != null) {
          return NumericInputParseResult(
              value: wattHours.value! * 1000 / voltage);
        }
      }
    }
    if (key == 'current' && voltage > 0) {
      if (ToolUnitConversion.splitUnitSuffix(rawValue, 'W') != null) {
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

