import '../entities/tool_definition.dart';
import 'tool_catalog_electronics.dart';
import 'tool_catalog_finance.dart';
import 'tool_catalog_math.dart';
import 'tool_catalog_mechanical.dart';
import 'tool_catalog_science.dart';
import 'tool_catalog_utilities.dart';

final List<ToolDefinition> toolCatalog = [
  ...mathToolDefinitions,
  ...electronicsToolDefinitions,
  ...mechanicalToolDefinitions,
  ...financeToolDefinitions,
  ...unitToolDefinitions,
  ...scienceToolDefinitions,
  ...textToolDefinitions,
];

ToolDefinition? toolById(String id) {
  for (final tool in toolCatalog) {
    if (tool.id == id) return tool;
  }
  return null;
}
