import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';
import 'tool_insight_result_readers.dart';

bool isStructureInsightTool(ToolKind kind) {
  switch (kind) {
    case ToolKind.pressureForce:
    case ToolKind.friction:
    case ToolKind.inclinedPlane:
    case ToolKind.beamBending:
    case ToolKind.stressStrain:
    case ToolKind.sectionArea:
    case ToolKind.safetyFactor:
    case ToolKind.flowVelocity:
    case ToolKind.materialWeight:
      return true;
    default:
      return false;
  }
}

List<String> buildStructureToolInsights(
  ToolKind kind,
  Map<String, double> v,
  List<ToolResult> results,
) {
  final lines = <String>[];
  switch (kind) {
    case ToolKind.pressureForce:
      final forceText = toolResultText(results, '作用力');
      final force = toolResultNumber(results, '作用力');
      final forceDelta = toolResultNumber(results, '作用力差值');
      final requiredPressure = toolResultText(results, '目标力所需压力');
      final requiredArea = toolResultText(results, '目标力所需面积');
      final pressure = v['pressure'] ?? 0;
      if (forceText == '无效') {
        lines.add('压力不能为负，受压面积必须大于 0');
      }
      if (pressure > 20) {
        lines.add('压力超过 20MPa，密封、软管和结构强度必须按额定值复核');
      }
      if (force != null && force > 100000) {
        lines.add('作用力超过 100kN，夹具刚度、压板强度和安全防护要单独校核');
      }
      if (requiredPressure == '无效' || requiredArea == '无效') {
        lines.add('目标作用力反推需要非零压力和有效受压面积作为参考');
      } else if (forceDelta != null) {
        lines.add('目标作用力与当前作用力相差 ${formatNumber(forceDelta)}N');
        lines.add('目标作用力反推仅按 F=P×A 估算，实际还要校核密封面积和压力损失');
      }
      lines.add('压力面积力按均布压力估算，边缘密封、偏载和动态冲击未计入');
    case ToolKind.friction:
      final frictionText = toolResultText(results, '摩擦力');
      final mu = v['mu'] ?? 0;
      if (frictionText == '无效') {
        lines.add('正压力和摩擦系数不能为负');
      }
      if (mu > 1) {
        lines.add('摩擦系数大于 1，通常只适合橡胶等高摩擦接触或特殊工况');
      }
      if ((v['normal'] ?? 0) == 0) lines.add('正压力为 0 时不会产生库仑摩擦力');
      lines.add('静摩擦上限和动摩擦系数可能不同，润滑、表面状态和温度会显著改变结果');
    case ToolKind.inclinedPlane:
      final parallelText = toolResultText(results, '沿斜面分力');
      final state = toolResultText(results, '滑动状态');
      final netDownhill = toolResultNumber(results, '净下滑力');
      final angle = v['angle'] ?? 0;
      if (parallelText == '无效') {
        lines.add('质量不能为负，摩擦系数不能为负，角度需在 -90° 到 90°');
      }
      if (state == '会下滑') {
        lines.add('沿斜面分力超过摩擦上限，物体会沿斜面下滑');
      } else if (state == '摩擦可抵住' && netDownhill != null) {
        lines.add('摩擦余量约 ${formatNumber(netDownhill.abs())}N，实际静摩擦系数不足时仍会滑动');
      }
      if (angle.abs() > 45) {
        lines.add('斜面角度超过 45°，法向力下降且对摩擦系数更敏感');
      }
      lines.add('净下滑力为正会下滑，为负说明摩擦可抵住；静摩擦和动摩擦需按材料分别取值');
    case ToolKind.beamBending:
      final deflectionText = toolResultText(results, '最大挠度');
      final ratio = toolResultNumber(results, '跨度/挠度');
      final targetDeflectionText = toolResultText(results, '目标挠度');
      final deflectionDelta = toolResultNumber(results, '挠度差值');
      final requiredInertiaText = toolResultText(results, '目标挠度所需惯性矩');
      if (deflectionText == '无效') {
        lines.add('跨度、弹性模量和惯性矩必须大于 0，载荷必须是有限数值');
      }
      if (ratio != null && ratio < 250) {
        lines.add('跨度/挠度低于 250，刚度偏软，常见结构设计还需限制挠度');
      }
      if (requiredInertiaText == '无效') {
        lines.add('目标挠度反推所需惯性矩需要非零载荷，目标挠度也必须大于 0');
      } else if (targetDeflectionText != null && deflectionDelta != null) {
        lines.add('目标挠度与当前挠度幅值相差 ${formatNumber(deflectionDelta)}mm');
        lines.add('目标挠度反推按同一简支梁模型估算，换支撑或载荷形式需重算');
      }
      lines.add('按简支梁中央集中载荷计算，支撑或载荷形式变化时不能直接套用');
    case ToolKind.stressStrain:
      final stressText = toolResultText(results, '应力');
      final stress = toolResultNumber(results, '应力幅值');
      if (stressText == '无效') {
        lines.add('截面积和弹性模量必须大于 0，轴向力必须是有限数值');
      }
      if (stress != null && stress > 250) {
        lines.add('应力超过 250MPa，常见结构钢也需要按材料牌号、屈服强度和安全系数复核');
      }
      lines.add('这是轴向平均应力，孔边、焊缝、压杆稳定和缺口要单独看应力集中');
    case ToolKind.sectionArea:
      final areaText = toolResultText(results, '圆截面积');
      final outer = v['outer'] ?? 0;
      final inner = v['inner'] ?? 0;
      final wall = toolResultNumber(results, '管壁厚');
      final hollowRatio = toolResultNumber(results, '空心率');
      final strongAxis = toolResultText(results, '强轴');
      if (areaText == '无效') {
        lines.add('圆直径、管外径、矩形宽高必须大于 0，管内径不能为负且必须小于外径');
      }
      if (inner >= outer && outer > 0) lines.add('管截面内径必须小于外径');
      if (wall != null && wall > 0 && wall / outer < 0.05) {
        lines.add('管壁厚小于外径 5%，薄壁管还需要校核局部屈曲和制造公差');
      }
      if (hollowRatio != null && hollowRatio > 70) {
        lines.add('空心率超过 70%，截面更轻但局部稳定、连接和压溃风险要单独确认');
      }
      if (strongAxis != null && strongAxis != '无效') {
        lines.add('矩形强轴为 $strongAxis，弯曲方向不同会显著改变挠度和应力');
      }
      lines.add('截面属性按理想几何计算，圆角、孔洞、焊缝和实际型材公差未计入');
    case ToolKind.safetyFactor:
      final factorText = toolResultText(results, '安全系数');
      final factor = toolResultNumber(results, '安全系数');
      final margin = toolResultNumber(results, '余量');
      final targetFactor = toolResultNumber(results, '目标安全系数');
      final factorDelta = toolResultNumber(results, '安全系数差值');
      final requiredStrength = toolResultNumber(results, '目标系数所需强度');
      if (factorText == '无效') {
        lines.add('材料强度必须大于 0，工作应力必须是有限数值');
      }
      if (factorText == '无穷大') {
        lines.add('工作应力为 0 时安全系数趋于无穷大，但仍需考虑预紧、冲击或装配载荷');
      }
      if (factor != null && factor < 1) lines.add('安全系数小于 1，按当前输入已经不足');
      if (factor != null && factor >= 1 && factor < 2) {
        lines.add('安全系数偏紧，疲劳、冲击、温度和制造偏差要继续校核');
      }
      if (margin != null && margin < 0) {
        lines.add('强度余量为负，工作应力已超过许用强度');
      }
      if (targetFactor != null && requiredStrength != null) {
        lines.add('目标安全系数需要材料强度约 ${formatNumber(requiredStrength)}MPa');
      }
      if (factorDelta != null && factorDelta < 0) {
        lines.add('当前安全系数低于目标 ${formatNumber(factorDelta.abs())}');
      }
    case ToolKind.flowVelocity:
      final speedText = toolResultText(results, '平均流速');
      final speed = toolResultNumber(results, '平均流速');
      final reynolds = toolResultNumber(results, '雷诺数');
      final state = toolResultText(results, '流动状态');
      if (speedText == '无效') {
        lines.add('流量不能为负，管内径必须大于 0');
      }
      if (speed != null && speed > 3) {
        lines.add('流速超过 3m/s，水路常见设计中压降、噪声和冲刷风险会明显增加');
      } else if (speed != null && speed > 0 && speed < 0.3) {
        lines.add('流速低于 0.3m/s，管路可能更容易沉积或排气不畅');
      }
      if (state == '过渡') lines.add('雷诺数处于过渡区，流态和压降对扰动比较敏感');
      if (reynolds != null && reynolds > 100000) {
        lines.add('雷诺数超过 100000，粗糙度、局部阻力和弯头阀门损失需要单独计算');
      }
      lines.add('雷诺数按 20℃ 水的运动黏度估算，气体、油液或温度变化时需改用实际物性');
    case ToolKind.materialWeight:
      final massText = toolResultText(results, '重量');
      final mass = toolResultNumber(results, '重量');
      final density = v['density'] ?? 0;
      final thickness = v['thickness'] ?? 0;
      if (massText == '无效') {
        lines.add('长度、宽度、厚度和密度都必须大于 0');
      }
      if (mass != null && mass > 100) {
        lines.add('重量超过 100kg，搬运、吊装和支撑工装需要单独考虑');
      }
      if (density > 0 && density < 1) {
        lines.add('密度低于 1g/cm³，常见于泡沫、木材或轻质塑料，实际含水率会影响重量');
      }
      if (thickness > 0 && thickness < 1) {
        lines.add('厚度低于 1mm，卷材、涂层和公差会明显影响重量估算');
      }
      lines.add('矩形板材按实心体估算，开孔、倒角、涂层和加工余量未计入');
    default:
      break;
  }
  return lines;
}
