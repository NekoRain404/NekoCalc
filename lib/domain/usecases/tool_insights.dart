import '../../core/utils/iterable_ext.dart';
import '../../core/utils/number_formatter.dart';
import '../entities/tool_category.dart';
import '../entities/tool_definition.dart';
import 'tool_insights_electronics.dart' as electronics_insights;
import 'tool_insights_finance.dart' as finance_insights;
import 'tool_insights_lifestyle.dart' as lifestyle_insights;
import 'tool_insights_math.dart' as math_insights;
import 'tool_insights_mechanical.dart' as mechanical_insights;
import 'tool_insights_physics.dart' as physics_insights;
import 'tool_insights_structure.dart' as structure_insights;

List<String> buildToolInsights(
    ToolDefinition tool, Map<String, double> values, List<ToolResult> results) {
  final primary = results.where((result) => result.primary).firstOrNull;
  return [
    _inputLine(tool, values),
    '公式 ${tool.formula}',
    if (primary != null) '${primary.label} ${primary.value}${primary.unit}',
    ..._errorLines(tool, values, results),
    ..._checkLines(tool, values, results),
  ].where((item) => item.trim().isNotEmpty).toList(growable: false);
}

String _inputLine(ToolDefinition tool, Map<String, double> values) {
  if (tool.inputs.isEmpty) return '无需数值输入';
  final fields = tool.inputs.map((input) {
    final rawValue = values[input.key];
    if (rawValue == null && input.optional) {
      return '${input.label} 未填写';
    }
    final value = formatNumber(rawValue ?? 0);
    return '${input.label} $value${input.unit}';
  }).join('，');
  return '输入 $fields';
}

List<String> _errorLines(
    ToolDefinition tool, Map<String, double> values, List<ToolResult> results) {
  final lines = <String>[];
  final tol = values['tol'];
  final vfTol = values['vfTol'];
  if (tol != null && tol > 0) {
    lines.add('误差按 ±${formatNumber(tol)}% 估算，范围结果只覆盖该公差，不包含温漂、老化和测量误差');
  }
  if (vfTol != null && vfTol > 0) {
    lines.add('LED 压降按 ±${formatNumber(vfTol)}V 扫描，实际还会随温度和电流移动');
  }
  final rangeLabels = results
      .where((result) => result.label.contains('范围'))
      .map((result) => '${result.label} ${_resultValueWithUnit(result)}');
  if (rangeLabels.isNotEmpty) lines.add('范围 ${rangeLabels.join('；')}');
  return lines;
}

List<String> _checkLines(
    ToolDefinition tool, Map<String, double> v, List<ToolResult> results) {
  if (math_insights.isMathInsightTool(tool.kind)) {
    return math_insights.buildMathToolInsights(tool.kind, v, results);
  }
  if (electronics_insights.isElectronicsInsightTool(tool.kind)) {
    return electronics_insights.buildElectronicsToolInsights(
        tool.kind, v, results);
  }
  if (mechanical_insights.isMechanicalInsightTool(tool.kind)) {
    return mechanical_insights.buildMechanicalToolInsights(
        tool.kind, v, results);
  }
  if (structure_insights.isStructureInsightTool(tool.kind)) {
    return structure_insights.buildStructureToolInsights(tool.kind, v, results);
  }
  if (finance_insights.isFinanceInsightTool(tool.kind)) {
    return finance_insights.buildFinanceToolInsights(tool.kind, v, results);
  }
  if (physics_insights.isPhysicsInsightTool(tool.kind)) {
    return physics_insights.buildPhysicsToolInsights(tool.kind, v, results);
  }
  if (lifestyle_insights.isLifestyleInsightTool(tool.kind)) {
    return lifestyle_insights.buildLifestyleToolInsights(tool.kind, v, results);
  }
  final lines = <String>[];
  switch (tool.kind) {
    default:
      lines.addAll(_categoryLines(tool.category));
  }
  return lines;
}

List<String> _categoryLines(ToolCategory category) {
  return switch (category) {
    ToolCategory.electronics => const ['理想元件模型，量产前要复核容差、温漂、额定功率和数据手册条件'],
    ToolCategory.mechanical => const ['静态估算结果，工程使用还要看材料、疲劳、冲击、装配误差和安全系数'],
    ToolCategory.finance => const ['本地估算，不替代合同条款、税务规则或投资判断'],
    ToolCategory.science => const ['默认理想模型，空气阻力、摩擦、热损耗和活度系数未自动计入'],
    ToolCategory.units => const ['固定系数换算；行业标准或标况条件不同会有差异'],
    ToolCategory.programming => const ['按常见工程约定处理，字符编码、时区和平台差异需按实际环境确认'],
    _ => const ['按当前输入和公式计算，实际使用前再核对场景约束'],
  };
}

String _resultValueWithUnit(ToolResult result) {
  final value = result.value.trim();
  final unit = result.unit.trim();
  if (unit.isEmpty || _resultNeedsAttention(result)) return value;
  return '$value$unit';
}

bool _resultNeedsAttention(ToolResult result) {
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
