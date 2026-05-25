import 'package:flutter/foundation.dart';

import '../../core/utils/iterable_ext.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/tool_usage_repository.dart';
import '../../domain/entities/tool_definition.dart';
import '../../domain/usecases/calculate_tool.dart';
import '../../domain/usecases/tool_insights.dart';

class ToolDetailController extends ChangeNotifier {
  ToolDetailController({
    required this.historyRepository,
    required this.notesRepository,
    required this.toolUsageRepository,
    required this.tool,
  }) {
    _values = {
      for (final input in tool.inputs) input.key: input.defaultValue ?? 0,
    };
    _recalculate();
  }

  final HistoryRepository historyRepository;
  final NotesRepository notesRepository;
  final ToolUsageRepository toolUsageRepository;
  final ToolDefinition tool;

  Map<String, double> _values = const {};
  List<ToolResult> _results = const [];
  List<String> _insights = const [];
  bool _favorite = false;

  Map<String, double> get values => Map.unmodifiable(_values);

  List<ToolResult> get results => _results;

  List<String> get insights => _insights;

  bool get favorite => _favorite;

  ToolResult? get primary =>
      _results.where((result) => result.primary).firstOrNull ??
      _results.firstOrNull;

  Future<void> loadFavorite() async {
    final ids = await toolUsageRepository.favoriteIds();
    _favorite = ids.contains(tool.id);
    notifyListeners();
  }

  void updateValue(String key, String rawValue) {
    final next = double.tryParse(rawValue.replaceAll(',', '')) ?? 0;
    if (_values[key] == next) return;
    _values = {..._values, key: next};
    _recalculate();
    notifyListeners();
  }

  void updateValues(Map<String, String> rawValues) {
    var changed = false;
    final nextValues = {..._values};
    // 中文：批量应用输入框变化，避免多个参数连续编辑时重复计算和重复通知 UI。
    // English: Apply input changes in one batch to avoid repeated recalculation and UI notifications.
    for (final entry in rawValues.entries) {
      final next = double.tryParse(entry.value.replaceAll(',', '')) ?? 0;
      if (nextValues[entry.key] == next) continue;
      nextValues[entry.key] = next;
      changed = true;
    }
    if (!changed) return;
    _values = nextValues;
    _recalculate();
    notifyListeners();
  }

  void resetValues() {
    _values = {
      for (final input in tool.inputs) input.key: input.defaultValue ?? 0,
    };
    _recalculate();
    notifyListeners();
  }

  Future<void> toggleFavorite() async {
    final next = !_favorite;
    await toolUsageRepository.setFavorite(tool.id, next);
    _favorite = next;
    notifyListeners();
  }

  Future<void> saveResult(String expression) async {
    final item = primary;
    if (item == null) return;
    await historyRepository.saveToolResult(
      expression: expression,
      result: '${item.label}: ${item.value}${item.unit}',
      toolId: tool.id,
    );
  }

  Future<void> saveNote() {
    return notesRepository.create(
        title: tool.title, body: noteBody(), description: tool.description);
  }

  String copyText() {
    return [
      ..._results
          .map((result) => '${result.label}: ${result.value}${result.unit}'),
      '',
      ..._insights,
    ].join('\n');
  }

  String noteBody() {
    return [
      tool.description,
      ..._results
          .map((result) => '${result.label}: ${result.value}${result.unit}'),
      '',
      ..._insights,
      '公式：${tool.formula}',
    ].join('\n');
  }

  void _recalculate() {
    _results = calculateTool(tool, _values);
    _insights = buildToolInsights(tool, _values, _results);
  }
}
