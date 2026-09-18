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
      .map((result) => '${result.label} ${result.valueWithUnit}');
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

/// 中文：**旧判据的第二份拷贝就在这里**，本轮没了——它现在只读产出方写下的旗标。
///       两份拷贝为什么必须一起改、为什么不能再漂开：判据现在只有一处，在
///       [ToolResult.hasError]；`_resultValueWithUnit` 同样只剩一处，在 [ToolResult.valueWithUnit]。
///       **本文件不 import 控制器**（`domain` 不依赖 `application`），所以"一份代码两处用"这件事
///       只能靠把两样东西都放进 `domain/entities/tool_definition.dart` 来做。
/// English: **The second copy of the old predicate lived right here** and is gone this round — it
///          now reads only the flag the producer wrote. Why the two copies had to change together and
///          why they cannot drift apart again: there is now one judgement, in [ToolResult.hasError],
///          and one `_resultValueWithUnit`, in [ToolResult.valueWithUnit]. **This file does not
///          import the controller** (`domain` does not depend on `application`), so "one
///          implementation, two callers" could only be done by putting both on
///          `domain/entities/tool_definition.dart`.
