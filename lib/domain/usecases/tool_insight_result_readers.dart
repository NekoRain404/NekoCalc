import '../entities/tool_definition.dart';

double? toolResultNumber(List<ToolResult> results, String label) {
  for (final result in results) {
    if (!result.label.contains(label)) continue;
    final normalized = result.value
        .trim()
        .replaceAll(',', '')
        .replaceAll('%', '')
        .replaceAll('−', '-');
    return double.tryParse(normalized);
  }
  return null;
}

String? toolResultText(List<ToolResult> results, String label) {
  for (final result in results) {
    if (result.label.contains(label)) return result.value;
  }
  return null;
}
