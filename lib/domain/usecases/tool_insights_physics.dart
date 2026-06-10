import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';
import 'tool_insight_result_readers.dart';

bool isPhysicsInsightTool(ToolKind kind) {
  switch (kind) {
    case ToolKind.motion:
    case ToolKind.freeFall:
    case ToolKind.workPower:
    case ToolKind.kineticEnergy:
    case ToolKind.density:
    case ToolKind.concentration:
    case ToolKind.idealGas:
    case ToolKind.heat:
    case ToolKind.wavelength:
    case ToolKind.halfLife:
    case ToolKind.ph:
      return true;
    default:
      return false;
  }
}

List<String> buildPhysicsToolInsights(
  ToolKind kind,
  Map<String, double> v,
  List<ToolResult> results,
) {
  final lines = <String>[];
  switch (kind) {
    case ToolKind.motion:
      final distanceText = toolResultText(results, '距离');
      final speedKmh = toolResultNumber(results, '速度');
      final source = toolResultText(results, '输入来源') ?? '';
      final distanceDelta = toolResultNumber(results, '距离差值');
      if (distanceText == '无效') {
        lines.add('速度、时间、距离至少填写两项；数值不能为负，反推时分母不能为 0');
      }
      if (speedKmh != null && speedKmh > 120) {
        lines.add('速度超过 120km/h，制动距离、反应时间和安全边界需要单独考虑');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由匀速模型换算');
      }
      if (distanceDelta != null && distanceDelta.abs() > 1e-9) {
        lines.add('三项都填写时按速度×时间计算，和输入距离相差 ${formatNumber(distanceDelta)}m');
      }
      lines.add('匀速运动默认速度恒定，未计入加速、减速、坡度和阻力');
    case ToolKind.freeFall:
      final fallText = toolResultText(results, '落地时间');
      final endSpeedKmh = toolResultNumber(results, '末速度 km/h');
      final initialSpeed = toolResultNumber(results, '初速度');
      final impactEnergy = toolResultNumber(results, '冲击能量');
      final bufferForce = toolResultNumber(results, '缓冲平均力');
      final bufferForceText = toolResultText(results, '缓冲平均力');
      if (fallText == '无效') {
        lines.add('高度不能为负，重力加速度必须大于 0；填写质量时质量不能为负');
      }
      if (endSpeedKmh != null && endSpeedKmh > 100) {
        lines.add('末速度超过 100km/h，空气阻力会明显改变真实结果');
      }
      if (initialSpeed != null && initialSpeed < 0) {
        lines.add('初速度为负表示先向上抛出，再回落到指定高度差');
      } else if (initialSpeed != null && initialSpeed > 0) {
        lines.add('初速度按向下为正计入，会缩短落地时间并增加末端动能');
      }
      if (impactEnergy != null && impactEnergy > 1000) {
        lines.add('冲击能量超过 1kJ，真实碰撞还要看接触时间、缓冲距离和结构强度');
      }
      if (bufferForceText == '无效') {
        lines.add('缓冲平均力需要同时填写质量和大于 0 的缓冲距离');
      } else if (bufferForce != null) {
        lines.add('缓冲平均力按冲击能量/缓冲距离估算，真实峰值取决于接触时间和缓冲曲线');
        if (bufferForce > 10000) {
          lines.add('缓冲平均力超过 10kN，实际峰值可能更高，需要结构和固定方式校核');
        }
      }
      lines.add('自由落体按真空模型计算，未计入空气阻力、姿态、旋转和碰撞缓冲');
    case ToolKind.workPower:
      final workText = toolResultText(results, '功');
      final power = toolResultNumber(results, '平均功率');
      final angle = toolResultNumber(results, '力-位移夹角');
      final efficiency = toolResultNumber(results, '效率');
      final lossPower = toolResultNumber(results, '损耗功率');
      final targetTimeText = toolResultText(results, '目标功率所需时间');
      final targetForceText = toolResultText(results, '目标功率所需力');
      if (workText == '无效') {
        lines.add('时间必须大于 0，效率需在 0% 到 100% 之间，力、位移和夹角需要是有限数值');
      }
      if (power != null && power < 0) lines.add('平均功率为负，表示力与位移方向相反或在回收能量');
      if (angle != null && angle.abs() > 80 && angle.abs() < 100) {
        lines.add('力-位移夹角接近 90°，有效做功对角度误差非常敏感');
      }
      if (efficiency != null && efficiency < 70) {
        lines.add('效率低于 70%，输入功率和热损耗需要单独核对');
      }
      if (lossPower != null && lossPower.abs() > 100) {
        lines.add('损耗功率超过 100W，散热、温升和供能余量需要额外确认');
      }
      if (targetTimeText == '无效' || targetForceText == '无效') {
        lines.add('目标功率反推时间或力需要非零目标功率、位移和有效夹角');
      } else if (targetTimeText != null || targetForceText != null) {
        lines.add('目标功率反推按平均功率计算，启动峰值和速度曲线需要按实际运动过程校核');
      }
      lines.add('功率为平均值，瞬时峰值、摩擦损耗、传动效率和控制策略需按实际工况复核');
    case ToolKind.kineticEnergy:
      final totalText = toolResultText(results, '总能量');
      final kinetic = toolResultNumber(results, '动能');
      final targetSpeedText = toolResultText(results, '目标能量所需速度');
      final energyDelta = toolResultNumber(results, '目标能量差值');
      if (totalText == '无效') {
        lines.add('质量不能为负，速度和高度需要是有限数值');
      }
      if (kinetic != null && kinetic > 10000) {
        lines.add('动能超过 10kJ，碰撞、防护和制动场景需要按安全规范复核');
      }
      if (targetSpeedText == '无效') {
        lines.add('目标总能量反推速度需要非零质量，且目标能量必须不低于当前势能');
      } else if (targetSpeedText != null) {
        lines.add('目标总能量反推只按动能和重力势能换算，实际运动还要计入损耗和安全余量');
      }
      if (energyDelta != null && energyDelta.abs() > 1e-9) {
        lines.add('当前总能量与目标相差 ${formatNumber(energyDelta)}J');
      }
      lines.add('势能使用标准重力加速度 9.80665m/s²，未计入弹性势能和能量损耗');
    case ToolKind.density:
      final densityText = toolResultText(results, '密度');
      final density = toolResultNumber(results, '密度');
      final source = toolResultText(results, '输入来源') ?? '';
      final densityDelta = toolResultNumber(results, '密度差值');
      if (densityText == '无效') {
        lines.add('质量、体积、密度至少填写两项；质量不能为负，体积和密度必须大于 0');
      }
      if (density != null && density > 8000) {
        lines.add('密度高于 8000kg/m³，接近重金属材料范围');
      }
      if (density != null && density < 1) {
        lines.add('密度低于 1kg/m³，常见于低压气体口径，请确认单位和体积状态');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由 ρ=m/V 换算');
      }
      if (densityDelta != null && densityDelta.abs() > 1e-9) {
        lines.add('三项都填写时按质量/体积计算，和输入密度相差 ${formatNumber(densityDelta)}kg/m³');
      }
      lines.add('密度按均匀材料估算，孔隙、含水率、温度和混合比例会改变结果');
    case ToolKind.concentration:
      final concentrationText = toolResultText(results, '质量浓度');
      final molarity = toolResultNumber(results, '摩尔浓度');
      final source = toolResultText(results, '输入来源') ?? '';
      final massConcentrationDelta = toolResultNumber(results, '质量浓度差值');
      final molarityDelta = toolResultNumber(results, '摩尔浓度差值');
      final molarMassDelta = toolResultNumber(results, '摩尔质量差值');
      if (concentrationText == '无效') {
        lines.add('请至少填写两项可形成浓度关系的输入；溶质量和浓度不能为负，体积和摩尔质量必须大于 0');
      }
      if (molarity != null && molarity > 10) {
        lines.add('摩尔浓度超过 10mol/L，需核对溶解度和体积口径');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由 γ=m/V 与 C=γ/M 换算');
      }
      if (massConcentrationDelta != null &&
          massConcentrationDelta.abs() > 1e-9) {
        lines.add('质量浓度参考值与当前计算相差 ${formatNumber(massConcentrationDelta)}g/L');
      }
      if (molarityDelta != null && molarityDelta.abs() > 1e-9) {
        lines.add('摩尔浓度参考值与当前计算相差 ${formatNumber(molarityDelta)}mol/L');
      }
      if (molarMassDelta != null && molarMassDelta.abs() > 1e-9) {
        lines.add('摩尔质量参考值与当前计算相差 ${formatNumber(molarMassDelta)}g/mol');
      }
      lines.add('浓度按最终溶液体积估算，混合体积变化、活度和温度影响未计入');
    case ToolKind.idealGas:
      final pressureText = toolResultText(results, '压力');
      final pressureKpa = toolResultNumber(results, '压力');
      final source = toolResultText(results, '输入来源') ?? '';
      final pressureDelta = toolResultNumber(results, '压力差值');
      if (pressureText == '无效') {
        lines.add('压力、物质的量、热力学温度和体积至少填写三项；物质的量不能为负，其余项必须大于 0');
      }
      if (pressureKpa != null && pressureKpa > 1000) {
        lines.add('压力超过 1000kPa，高压场景需按容器额定压力和真实气体修正复核');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由 PV=nRT 换算');
      }
      if (pressureDelta != null && pressureDelta.abs() > 1e-9) {
        lines.add('压力参考值与当前计算相差 ${formatNumber(pressureDelta)}kPa');
      }
      lines.add('理想气体模型适合低压稀薄气体，高压、低温和相变附近误差会增大');
    case ToolKind.heat:
      final heatText = toolResultText(results, '热量');
      final heat = toolResultNumber(results, '热量');
      final source = toolResultText(results, '输入来源') ?? '';
      final heatDelta = toolResultNumber(results, '热量差值');
      if (heatText == '无效') {
        lines.add('质量、比热容、温度变化、热量至少填写三项；质量和比热容不能为负，反推分母不能为 0');
      }
      if (heat != null && heat < 0) lines.add('热量为负，表示对象降温并向外放热');
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由 Q=mcΔT 换算');
      }
      if (heatDelta != null && heatDelta.abs() > 1e-9) {
        lines.add('热量参考值与当前计算相差 ${formatNumber(heatDelta)}J');
      }
      lines.add('热量计算未计入相变潜热、散热损失、热容随温度变化和加热效率');
    case ToolKind.wavelength:
      final wavelengthText = toolResultText(results, '波长');
      final frequency = toolResultNumber(results, '频率');
      final source = toolResultText(results, '输入来源') ?? '';
      final wavelengthDelta = toolResultNumber(results, '波长差值');
      if (wavelengthText == '无效') {
        lines.add('波速、频率、波长至少填写两项，且都必须大于 0');
      }
      if (frequency != null && frequency > 20000 && (v['speed'] ?? 0) < 1000) {
        lines.add('声波频率超过 20kHz，通常已进入超声范围');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由 λ=v/f 换算');
      }
      if (wavelengthDelta != null && wavelengthDelta.abs() > 1e-12) {
        lines.add('波长参考值与当前计算相差 ${formatNumber(wavelengthDelta)}m');
      }
      lines.add('波长按均匀介质计算，温度、介质变化和色散会改变波速');
    case ToolKind.halfLife:
      final remainingText = toolResultText(results, '剩余量');
      final remainingRatio = toolResultNumber(results, '剩余比例');
      final source = toolResultText(results, '输入来源') ?? '';
      final remainingDelta = toolResultNumber(results, '剩余量差值');
      final remainingRatioDelta = toolResultNumber(results, '剩余比例差值');
      if (remainingText == '无效') {
        lines.add('至少填写三项；初始量和剩余量不能为负，半衰期必须大于 0，经过时间不能为负，剩余比例需在 0% 到 100%');
      }
      if (remainingRatio != null && remainingRatio < 1) {
        lines.add('剩余比例低于 1%，实际测量会更依赖本底噪声和探测限');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由 N=N0×0.5^(t/T) 换算');
      }
      if (remainingDelta != null && remainingDelta.abs() > 1e-12) {
        lines.add('剩余量参考值与当前计算相差 ${formatNumber(remainingDelta)}');
      }
      if (remainingRatioDelta != null && remainingRatioDelta.abs() > 1e-12) {
        lines.add('剩余比例参考值与当前计算相差 ${formatNumber(remainingRatioDelta)}%');
      }
      lines.add('半衰期模型按指数衰减估算，实际计数存在统计波动和测量效率误差');
    case ToolKind.ph:
      final phText = toolResultText(results, 'pH');
      final ph = toolResultNumber(results, 'pH');
      final source = toolResultText(results, '输入来源') ?? '';
      final phDelta = toolResultNumber(results, 'pH差值');
      if (phText == '无效') {
        lines.add('请填写有效的 pH、[H+] 或 [OH-]；浓度必须大于 0');
      }
      if (ph != null && (ph < 2 || ph > 12)) {
        lines.add('pH 极端，稀溶液近似和安全防护都需要额外核对');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前以 $source 作为输入来源反推其它浓度');
      }
      if (phDelta != null && phDelta.abs() > 1e-12) {
        lines.add('当前 pH 与目标 pH 相差 ${formatNumber(phDelta)}');
      }
      lines.add('pH 按 25℃ 水溶液 Kw=1e-14 简化估算，强酸强碱以外还要考虑活度和缓冲体系');
    default:
      break;
  }
  return lines;
}
