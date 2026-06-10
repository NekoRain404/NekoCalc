import '../entities/tool_definition.dart';
import 'tool_insight_result_readers.dart';

bool isMechanicalInsightTool(ToolKind kind) {
  switch (kind) {
    case ToolKind.gearRatio:
    case ToolKind.torquePower:
    case ToolKind.spring:
    case ToolKind.cylinder:
    case ToolKind.force:
    case ToolKind.pulleyRatio:
    case ToolKind.screwLead:
      return true;
    default:
      return false;
  }
}

List<String> buildMechanicalToolInsights(
  ToolKind kind,
  Map<String, double> v,
  List<ToolResult> results,
) {
  final lines = <String>[];
  switch (kind) {
    case ToolKind.gearRatio:
      final ratioText = toolResultText(results, '传动比');
      final ratio = toolResultNumber(results, '传动比');
      final outputRpm = toolResultNumber(results, '输出转速');
      final targetDrivenTeeth = toolResultNumber(results, '保留Z1所需Z2');
      final targetDriverTeeth = toolResultNumber(results, '保留Z2所需Z1');
      final efficiency = v['efficiency'] ?? 100;
      if (ratioText == '无效') {
        lines.add('驱动齿数和从动齿数必须大于 0，效率需在 0% 到 100%');
        if (v['targetOutputRpm'] != null) {
          lines.add('目标输出转速不能为 0，且必须是有限数值');
        }
      }
      if (ratio != null && ratio > 10) {
        lines.add('单级传动比超过 10，齿轮尺寸、啮合强度和效率通常需要分级设计');
      } else if (ratio != null && ratio < 0.2) {
        lines.add('高速增速比很大，需重点校核动平衡、润滑和齿面线速度');
      }
      if (outputRpm != null && outputRpm.abs() > 10000) {
        lines.add('输出转速超过 10000rpm，轴承、润滑和动平衡要单独校核');
      }
      if (efficiency > 0 && efficiency < 80) {
        lines.add('效率低于 80%，发热和润滑损耗会明显影响输出功率');
      }
      if (targetDrivenTeeth != null &&
          _distanceFromInteger(targetDrivenTeeth) > 0.05) {
        lines.add('目标输出转速反推的从动齿数不是整数，需要选邻近齿数组合后复算转速误差');
      }
      if (targetDriverTeeth != null &&
          _distanceFromInteger(targetDriverTeeth) > 0.05) {
        lines.add('目标输出转速反推的驱动齿数不是整数，需要校核实际可用齿数组合');
      }
      lines.add('扭矩已乘效率；冲击载荷、齿面强度和轴承能力另算');
    case ToolKind.torquePower:
      final powerText = toolResultText(results, '功率');
      final direction = toolResultText(results, '功率方向');
      final rpm = v['rpm'] ?? 0;
      final torque = v['torque'] ?? 0;
      final targetTorqueText = toolResultText(results, '目标功率所需扭矩');
      final targetRpmText = toolResultText(results, '目标功率所需转速');
      if (powerText == '无效') {
        lines.add('扭矩和转速必须是有限数值');
      }
      if (rpm == 0) {
        lines.add('转速为 0 时机械输出功率为 0，无法反推 1kW 所需扭矩');
      }
      if (direction == '制动/回馈') {
        lines.add('功率为负表示扭矩和转速方向相反，常见于制动或能量回馈');
      }
      if (rpm.abs() > 10000) {
        lines.add('转速超过 10000rpm，轴承、动平衡和临界转速需要单独校核');
      }
      if (torque.abs() > 1000) {
        lines.add('扭矩超过 1000N·m，轴径、键连接和联轴器额定值要单独校核');
      }
      if (targetTorqueText == '无效' || targetRpmText == '无效') {
        lines.add('目标功率反推需要非零转速或非零扭矩作为参考');
      } else if (targetTorqueText != null || targetRpmText != null) {
        lines.add('目标功率反推只按轴功率计算，选型还要乘安全系数并计入效率');
      }
      lines.add('公式只给轴功率，电机效率、减速器效率和冲击载荷需另算');
    case ToolKind.spring:
      final forceText = toolResultText(results, '弹簧力');
      final force = toolResultNumber(results, '弹簧力幅值');
      final travel = v['x'] ?? 0;
      final targetForceTravel = toolResultNumber(results, '目标力所需变形');
      final targetEnergyTravel = toolResultNumber(results, '目标储能所需变形');
      if (forceText == '无效') {
        lines.add('弹簧刚度必须大于 0，变形量必须是有限数值');
        if (v['targetEnergy'] != null) {
          lines.add('目标储能不能为负，且必须是有限数值');
        }
      }
      if (travel < 0) lines.add('变形量为负表示按相反方向取参考，储能仍按位移平方计算');
      if (force != null && force > 1000) {
        lines.add('弹簧力超过 1000N，端部固定、导向和材料许用应力要单独校核');
      }
      if (targetForceTravel != null && targetForceTravel < 0) {
        lines.add('目标弹簧力为负时表示反向变形，实际结构需确认是否允许拉伸或反向受力');
      }
      if (targetEnergyTravel != null) {
        lines.add('目标储能反推得到的是变形幅值，压缩或拉伸方向需按结构约束选择');
      }
      lines.add('按线性弹簧估算；接近并圈、屈服或非线性区时不能直接套用');
    case ToolKind.cylinder:
      final extendText = toolResultText(results, '推出力');
      final retractRatio = toolResultNumber(results, '拉力比例');
      final targetPressureText = toolResultText(results, '目标力所需气压');
      final forceMargin = toolResultNumber(results, '推出力余量');
      final pressure = v['pressure'] ?? 0;
      if (extendText == '无效') {
        lines.add('气压不能为负，缸径必须大于 0，杆径需小于缸径');
      }
      if (pressure > 1) lines.add('气压超过 1MPa，需确认气缸、管路和接头额定压力');
      if (retractRatio != null && retractRatio < 70) {
        lines.add('杆径占比偏大，拉回力明显低于推出力，请核对回程负载');
      }
      if (targetPressureText == '无效') {
        lines.add('目标推出力反推需要正气压或有效活塞面积作为参考');
      } else if (targetPressureText != null) {
        lines.add('目标推出力反推按理论面积计算，实际选型要扣除摩擦、背压并留安全系数');
      }
      if (forceMargin != null && forceMargin < 0) {
        lines.add('推出力余量为负，当前缸径和气压达不到目标推出力');
      }
      lines.add('有效力还要扣掉密封摩擦、背压和压力波动');
    case ToolKind.force:
      final forceText = toolResultText(results, '力');
      final force = toolResultNumber(results, '力幅值');
      final targetAccelerationText = toolResultText(results, '目标力所需加速度');
      final targetMassText = toolResultText(results, '目标力所需质量');
      final acc = v['acc'] ?? 0;
      if (forceText == '无效') {
        lines.add('质量不能为负，质量和加速度必须是有限数值');
      }
      if (acc < 0) lines.add('加速度为负表示参考方向相反，力幅值已单独列出');
      if (force != null && force > 10000) {
        lines.add('力超过 10kN，连接件、夹具和安全防护需要单独校核');
      }
      if (targetAccelerationText == '无效' || targetMassText == '无效') {
        lines.add('目标力反推需要非零质量或非零加速度作为参考');
      } else if (targetAccelerationText != null || targetMassText != null) {
        lines.add('目标力反推只按 F=ma 计算，实际负载还要叠加摩擦、重力分力和冲击峰值');
      }
      lines.add('这是 F = ma 的惯性力估算，不含摩擦、冲击、空气阻力和机构效率');
    case ToolKind.pulleyRatio:
      final rpmText = toolResultText(results, '输出转速');
      final beltSpeed = toolResultNumber(results, '皮带线速度');
      final ratio = toolResultNumber(results, '传动比');
      final targetRatioText = toolResultText(results, '目标速度比');
      if (rpmText == '无效') {
        lines.add('主动轮和从动轮直径必须大于 0，输入转速必须是有限数值');
      }
      if (ratio != null && (ratio > 5 || ratio < 0.2)) {
        lines.add('皮带轮直径比超过 5:1，包角、张紧和打滑风险要单独确认');
      }
      if (beltSpeed != null && beltSpeed > 30) {
        lines.add('皮带线速度超过 30m/s，需核对皮带型号、动平衡和防护');
      }
      if (targetRatioText == '无效') {
        lines.add('目标输出转速反推轮径需要非零输入转速作为参考');
      } else if (targetRatioText != null) {
        lines.add('目标输出转速反推按无打滑几何关系计算，实际需按标准轮径和包角修正');
      }
      lines.add('按无打滑开口皮带估算；交叉皮带会反向，实际还受张力和包角影响');
    case ToolKind.screwLead:
      final speedText = toolResultText(results, '线速度');
      final mmPerSecond = toolResultNumber(results, '每秒位移');
      final targetLeadText = toolResultText(results, '目标线速度所需导程');
      if (speedText == '无效') {
        lines.add('导程必须大于 0，转速必须是有限数值');
      }
      if ((v['rpm'] ?? 0) < 0) lines.add('转速为负表示反向进给，线速度符号保留方向');
      if (mmPerSecond != null && mmPerSecond.abs() > 500) {
        lines.add('线速度超过 500mm/s，临界转速、振动和加减速距离要单独校核');
      }
      if (targetLeadText == '无效') {
        lines.add('目标线速度反推导程需要非零转速作为参考');
      } else if (targetLeadText != null) {
        lines.add('目标线速度反推只按导程几何换算，实际还要校核丝杆临界转速和电机扭矩');
      }
      lines.add('仅按几何导程换算，不含丝杆效率、背隙、弹性变形和驱动扭矩限制');
    default:
      break;
  }
  return lines;
}

double _distanceFromInteger(double value) {
  return (value - value.round()).abs();
}
