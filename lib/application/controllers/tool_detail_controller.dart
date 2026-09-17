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
import 'tool_detail_models.dart';
part 'tool_detail_paste_parser.dart';
part 'tool_detail_input_parsing.dart';

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
