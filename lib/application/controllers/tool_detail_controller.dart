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
import '../../features/tools/presentation/tool_detail_strings.dart';
import 'tool_detail_models.dart';
part 'tool_detail_paste_parser.dart';
part 'tool_detail_input_parsing.dart';

// 中文：**把状态说成人话的那一半在这个 part 里**（参数行、结果行、状态卡那两句、复制与笔记正文、
//       两处原样返回的标签读法）。为什么在那里切、切完两边各管什么，写在
//       `tool_detail_sentences.dart` 的文件头上。
// English: **the half that turns state into sentences is in this part** (the input rows, the result rows,
//          the status card's two sentences, the copied and note bodies, and the two label readers that
//          return their argument unchanged). Why the seam is there, and what each half owns afterwards,
//          is on `tool_detail_sentences.dart`'s head.
part 'tool_detail_sentences.dart';

class ToolDetailController extends ChangeNotifier {
  ToolDetailController({
    required this.historyRepository,
    required this.notesRepository,
    required this.toolUsageRepository,
    required this.tool,
    required this.strings,
  }) {
    _values = _defaultValues(tool);
    _recalculate();
  }

  final HistoryRepository historyRepository;
  final NotesRepository notesRepository;
  final ToolUsageRepository toolUsageRepository;
  final ToolDefinition tool;

  /// 中文：**这个控制器写的每一句人话都从这张表来**（状态卡、复制正文、粘贴摘要、错误行）。
  ///       必填、没有中文兜底：忘了递表的调用点编译不过，而不是在英文界面上悄悄吐中文。
  ///       为什么表住在 `features/`、为什么不挂在 `BuildContext` 上，见
  ///       `tool_detail_strings.dart` 的文件头。
  ///
  ///       **它可以被换掉，而且必须被换掉。** 界面在 `didChangeDependencies` 里把它换成作用域中
  ///       **当场生效**的那一张：控制器是 `initState` 里造的、之后一直活着，而用户换语言时
  ///       `app.dart` 只换内存里的 `_language`（不重载设置记录），所以只按构造时的设置取值，
  ///       会让"设置页还开着、底下的详情页已经该换语言了"这一种停在旧语言上。字段可变正是为此，
  ///       与 [tool] / 三个仓库那种一辈子不动的字段不是一回事。
  /// English: **every human sentence this controller writes comes from this table** (the status card,
  ///          the copied body, paste summaries, error lines). Required, with no Chinese fallback: a
  ///          call site that forgets it fails to compile rather than quietly emitting Chinese into an
  ///          English interface. Why the table lives under `features/` and why it is not read from a
  ///          `BuildContext` is on `tool_detail_strings.dart`'s head.
  ///
  ///          **It is reassignable, and it has to be.** The screen replaces it in
  ///          `didChangeDependencies` with the scope's **immediately effective** table: the controller
  ///          is built in `initState` and then lives on, while a language change makes `app.dart` swap
  ///          only the in-memory `_language` (the settings record is not reloaded), so reading the
  ///          construction-time setting alone would leave "the settings page is still open but the
  ///          detail screen underneath should already have changed language" stuck in the old one. The
  ///          mutability is for exactly that, unlike [tool] and the three repositories, which never
  ///          move.
  ToolDetailStrings strings;

  /// 中文：输入框下那一行的文案。**`issue` 为空时才是 `'输入无效'`**——与改动前
  ///       `parsed.error ?? '输入无效'` 逐字节同一条。
  /// English: the wording of the line under an input. **`'输入无效'` only when `issue` is null** —
  ///          byte-for-byte the old `parsed.error ?? '输入无效'`.
  String inputErrorText(NumericInputParseResult parsed) {
    return parsed.issue == null
        ? strings.invalidInput
        : parsed.issueMessage(strings.numericInput);
  }

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
      return const NumericInputParseResult(
        value: null,
        issue: NumericInputIssue.empty,
      );
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
      nextErrors[key] = inputErrorText(parsed);
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
        nextErrors[entry.key] = inputErrorText(parsed);
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

  /// 中文：**旧判据（`value.contains('无效'/'不能'/'不可'/'错误')` 那一份）就在这里**，本轮没了。
  ///       它现在只读产出方写下的旗标。这里留一个薄壳而不是把它删掉：它是这个控制器的公开面，
  ///       契约不变、实现改向。真正的判据只有一份，在 [ToolResult.hasError]。
  /// English: **The old predicate (the `value.contains('无效'/'不能'/'不可'/'错误')` copy) lived
  ///          right here** and is gone this round. It now reads the flag the producer wrote. A thin
  ///          shell is kept rather than the method deleted: this is the controller's public surface,
  ///          so the contract stays and only the implementation is redirected. There is exactly one
  ///          judgement, in [ToolResult.hasError].
  bool resultNeedsAttention(ToolResult result) {
    return result.hasError;
  }
}
