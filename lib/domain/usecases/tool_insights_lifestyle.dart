import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';
import 'tool_insight_result_readers.dart';

bool isLifestyleInsightTool(ToolKind kind) {
  switch (kind) {
    case ToolKind.bmi:
    case ToolKind.fuelEconomy:
      return true;
    default:
      return false;
  }
}

List<String> buildLifestyleToolInsights(
  ToolKind kind,
  Map<String, double> v,
  List<ToolResult> results,
) {
  final lines = <String>[];
  switch (kind) {
    case ToolKind.bmi:
      final bmiText = toolResultText(results, 'BMI');
      final bmi = toolResultNumber(results, 'BMI');
      final range = toolResultText(results, '健康体重范围');
      final delta = toolResultText(results, '距健康区间');
      final waistHeightRatio = toolResultNumber(results, '腰高比');
      if (bmiText == '无效') {
        lines.add('身高和体重必须大于 0；填写腰围时腰围也必须大于 0');
      } else if (bmi != null) {
        if (bmi < 18.5) {
          lines.add('BMI 低于 18.5，体重低于常见健康区间');
        } else if (bmi >= 28) {
          lines.add('BMI 达到肥胖区间，建议结合腰围、血压、血糖和运动情况综合判断');
        } else if (bmi >= 24) {
          lines.add('BMI 进入超重区间，体重管理可优先看腰围和长期趋势');
        } else {
          lines.add('BMI 位于常见健康区间');
        }
      }
      if (range != null && range != '无效') {
        lines.add('按当前身高估算的健康体重范围约为 $range kg');
      }
      if (delta != null && delta != '无效' && delta != '在范围内') {
        lines.add('距健康体重区间还差 $delta，正号表示需要增重，负号表示需要减重');
      }
      if (waistHeightRatio != null && waistHeightRatio >= 0.5) {
        lines.add('腰高比达到 0.5 或更高，腹型肥胖风险需要额外关注');
      }
      lines.add('BMI 不能区分肌肉和脂肪，只能做筛查参考');
    case ToolKind.fuelEconomy:
      final consumptionText = toolResultText(results, '百公里油耗');
      final litersPer100Km = toolResultNumber(results, '百公里油耗');
      final costPer100Km = toolResultNumber(results, '百公里成本');
      final tankRange = toolResultNumber(results, '满箱续航');
      final annualCost = toolResultNumber(results, '年燃油费用');
      final annualCo2 = toolResultNumber(results, '年CO2排放');
      final source = toolResultText(results, '输入来源') ?? '';
      final consumptionDelta = toolResultNumber(results, '油耗差值');
      if (consumptionText == '无效') {
        lines.add('里程、燃油量和百公里油耗至少填写两项且必须大于 0；油价不能为负；可选油箱、年里程和 CO2 系数需为有效数值');
      } else if (litersPer100Km != null) {
        if (litersPer100Km < 4) {
          lines.add('百公里油耗低于 4L，结果可能来自高速巡航、混动工况或加油量记录偏差');
        } else if (litersPer100Km > 12) {
          lines.add('百公里油耗高于 12L，建议检查路况、胎压、载重、短途冷车和驾驶习惯');
        }
      }
      if (costPer100Km != null && costPer100Km > 100) {
        lines.add('百公里燃油成本超过 100 元，油价或油耗变化会明显影响用车预算');
      }
      if (tankRange != null && tankRange < 400) {
        lines.add('满箱续航低于 400km，长途前需要更保守地规划补能点');
      }
      if (annualCost != null && annualCost > 15000) {
        lines.add('年燃油费用超过 15000 元，可用年行驶里程和油价做预算敏感性对比');
      }
      if (annualCo2 != null && annualCo2 > 3000) {
        lines.add('年 CO2 粗估超过 3 吨，排放取决于燃油类型、实际油耗和统计口径');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由 fuel=distance×L/100km/100 换算');
      }
      if (consumptionDelta != null && consumptionDelta.abs() > 1e-12) {
        lines.add('油耗参考值与当前计算相差 ${formatNumber(consumptionDelta)}L/100km');
      }
      lines.add('路况、载重、胎压、空调和驾驶习惯都会改变油耗');
    default:
      break;
  }
  return lines;
}
