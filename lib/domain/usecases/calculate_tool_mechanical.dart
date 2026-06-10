import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> gearRatioResults(Map<String, double> valuesByKey) {
  final z1 = valuesByKey['z1'] ?? 0;
  final z2 = valuesByKey['z2'] ?? 0;
  final rpm = valuesByKey['rpm'] ?? 0;
  final torque = valuesByKey['torque'] ?? 0;
  final efficiency = valuesByKey['efficiency'] ?? 100;
  final targetOutputRpm = valuesByKey['targetOutputRpm'];
  final includeTarget = targetOutputRpm != null;
  if (z1 <= 0 ||
      z2 <= 0 ||
      efficiency < 0 ||
      efficiency > 100 ||
      !z1.isFinite ||
      !z2.isFinite ||
      !rpm.isFinite ||
      !torque.isFinite ||
      !efficiency.isFinite ||
      (targetOutputRpm != null &&
          (targetOutputRpm == 0 || !targetOutputRpm.isFinite))) {
    return _invalidGearRatioResults(includeTarget: includeTarget);
  }

  final eta = efficiency / 100;
  final ratio = z2 / z1;
  final outputRpm = rpm / ratio;
  final inputPower = torque * rpm / 9550;
  final outputTorque = torque * ratio * eta;
  final outputPower = inputPower * eta;
  final lossPower = inputPower.abs() * (1 - eta);
  final targetRatio =
      targetOutputRpm == null || rpm == 0 ? null : rpm / targetOutputRpm;
  final targetDrivenTeeth = targetRatio == null ? null : z1 * targetRatio;
  final targetDriverTeeth =
      targetRatio == null || targetRatio == 0 ? null : z2 / targetRatio;
  final targetOutputTorque =
      targetRatio == null ? null : torque * targetRatio * eta;
  return [
    ToolResult('传动比 i', formatNumber(ratio), '', primary: true),
    ToolResult('输出转速', formatNumber(outputRpm), 'rpm'),
    ToolResult('输出扭矩', formatNumber(outputTorque), 'N·m'),
    ToolResult('输入功率', formatNumber(inputPower), 'kW'),
    ToolResult('输出功率', formatNumber(outputPower), 'kW'),
    ToolResult('损耗功率', formatNumber(lossPower), 'kW'),
    ToolResult('输入角速度', formatNumber(rpm * 2 * math.pi / 60), 'rad/s'),
    ToolResult('输出角速度', formatNumber(outputRpm * 2 * math.pi / 60), 'rad/s'),
    ToolResult('速度比 n1/n2', formatNumber(ratio), ''),
    const ToolResult('旋转方向', '相反', ''),
    if (includeTarget)
      ToolResult('目标输出转速', formatNumber(targetOutputRpm), 'rpm'),
    if (includeTarget)
      ToolResult(
          '目标传动比', targetRatio == null ? '无效' : formatNumber(targetRatio), ''),
    if (includeTarget)
      ToolResult(
          '保留Z1所需Z2',
          targetDrivenTeeth == null ? '无效' : formatNumber(targetDrivenTeeth),
          '齿'),
    if (includeTarget)
      ToolResult(
          '保留Z2所需Z1',
          targetDriverTeeth == null ? '无效' : formatNumber(targetDriverTeeth),
          '齿'),
    if (includeTarget)
      ToolResult(
          '目标输出扭矩',
          targetOutputTorque == null ? '无效' : formatNumber(targetOutputTorque),
          'N·m'),
  ];
}

List<ToolResult> _invalidGearRatioResults({required bool includeTarget}) {
  return [
    const ToolResult('传动比 i', '无效', '', primary: true),
    const ToolResult('输出转速', '无效', 'rpm'),
    const ToolResult('输出扭矩', '无效', 'N·m'),
    const ToolResult('输入功率', '无效', 'kW'),
    const ToolResult('输出功率', '无效', 'kW'),
    const ToolResult('损耗功率', '无效', 'kW'),
    const ToolResult('输入角速度', '无效', 'rad/s'),
    const ToolResult('输出角速度', '无效', 'rad/s'),
    const ToolResult('速度比 n1/n2', '无效', ''),
    const ToolResult('旋转方向', '无效', ''),
    if (includeTarget) const ToolResult('目标输出转速', '无效', 'rpm'),
    if (includeTarget) const ToolResult('目标传动比', '无效', ''),
    if (includeTarget) const ToolResult('保留Z1所需Z2', '无效', '齿'),
    if (includeTarget) const ToolResult('保留Z2所需Z1', '无效', '齿'),
    if (includeTarget) const ToolResult('目标输出扭矩', '无效', 'N·m'),
  ];
}

List<ToolResult> torquePowerResults(Map<String, double> valuesByKey) {
  final torque = valuesByKey['torque'] ?? 0;
  final rpm = valuesByKey['rpm'] ?? 0;
  final targetPower = valuesByKey['targetPower'];
  final includeTarget = targetPower != null;
  if (!torque.isFinite ||
      !rpm.isFinite ||
      (targetPower != null && !targetPower.isFinite)) {
    return _invalidTorquePowerResults(includeTarget: includeTarget);
  }

  final kw = torque * rpm / 9550;
  final omega = rpm * 2 * math.pi / 60;
  final direction = kw == 0
      ? '无输出功'
      : kw > 0
          ? '驱动'
          : '制动/回馈';
  final torquePerKw = rpm == 0 ? '无效' : formatNumber(9550 / rpm);
  final targetTorque =
      targetPower == null || rpm == 0 ? null : targetPower * 9550 / rpm;
  final targetRpm =
      targetPower == null || torque == 0 ? null : targetPower * 9550 / torque;
  return [
    ToolResult('功率', formatNumber(kw), 'kW', primary: true),
    ToolResult('瓦特', formatNumber(kw * 1000), 'W'),
    ToolResult('机械马力', formatNumber(kw * 1.34102), 'hp'),
    ToolResult('公制马力', formatNumber(kw * 1.35962), 'PS'),
    ToolResult('角速度', formatNumber(omega), 'rad/s'),
    ToolResult('转速', formatNumber(rpm / 60), 'rps'),
    ToolResult('功率方向', direction, ''),
    ToolResult('1kW所需扭矩', torquePerKw, 'N·m'),
    if (includeTarget) ToolResult('目标功率', formatNumber(targetPower), 'kW'),
    if (includeTarget)
      ToolResult('目标功率所需扭矩',
          targetTorque == null ? '无效' : formatNumber(targetTorque), 'N·m'),
    if (includeTarget)
      ToolResult('目标功率所需转速', targetRpm == null ? '无效' : formatNumber(targetRpm),
          'rpm'),
  ];
}

List<ToolResult> _invalidTorquePowerResults({required bool includeTarget}) {
  return [
    const ToolResult('功率', '无效', 'kW', primary: true),
    const ToolResult('瓦特', '无效', 'W'),
    const ToolResult('机械马力', '无效', 'hp'),
    const ToolResult('公制马力', '无效', 'PS'),
    const ToolResult('角速度', '无效', 'rad/s'),
    const ToolResult('转速', '无效', 'rps'),
    const ToolResult('功率方向', '无效', ''),
    const ToolResult('1kW所需扭矩', '无效', 'N·m'),
    if (includeTarget) const ToolResult('目标功率', '无效', 'kW'),
    if (includeTarget) const ToolResult('目标功率所需扭矩', '无效', 'N·m'),
    if (includeTarget) const ToolResult('目标功率所需转速', '无效', 'rpm'),
  ];
}

List<ToolResult> springResults(Map<String, double> valuesByKey) {
  final stiffness = valuesByKey['k'] ?? 0;
  final travel = valuesByKey['x'] ?? 0;
  final targetForce = valuesByKey['targetForce'];
  final targetEnergy = valuesByKey['targetEnergy'];
  final includeForceTarget = targetForce != null;
  final includeEnergyTarget = targetEnergy != null;
  if (stiffness <= 0 ||
      !stiffness.isFinite ||
      !travel.isFinite ||
      (targetForce != null && !targetForce.isFinite) ||
      (targetEnergy != null && (targetEnergy < 0 || !targetEnergy.isFinite))) {
    return _invalidSpringResults(
      includeForceTarget: includeForceTarget,
      includeEnergyTarget: includeEnergyTarget,
    );
  }

  final force = stiffness * travel;
  final energy = 0.5 * stiffness * travel * travel / 1000;
  final direction = travel == 0
      ? '零位'
      : travel > 0
          ? '压缩'
          : '拉伸/反向';
  final targetForceTravel =
      targetForce == null ? null : targetForce / stiffness;
  final targetEnergyTravel = targetEnergy == null
      ? null
      : math.sqrt(2 * targetEnergy * 1000 / stiffness);
  return [
    ToolResult('弹簧力', formatNumber(force), 'N', primary: true),
    ToolResult('弹簧力幅值', formatNumber(force.abs()), 'N'),
    ToolResult('储能', formatNumber(energy), 'J'),
    ToolResult('刚度', formatNumber(stiffness * 1000), 'N/m'),
    ToolResult('柔度', formatNumber(1 / stiffness), 'mm/N'),
    ToolResult('等效重量', formatNumber(force.abs() / 9.80665), 'kgf'),
    ToolResult('变形方向', direction, ''),
    if (includeForceTarget) ToolResult('目标弹簧力', formatNumber(targetForce), 'N'),
    if (targetForceTravel != null)
      ToolResult('目标力所需变形', formatNumber(targetForceTravel), 'mm'),
    if (includeEnergyTarget)
      ToolResult('目标储能', formatNumber(targetEnergy), 'J'),
    if (targetEnergyTravel != null)
      ToolResult('目标储能所需变形', formatNumber(targetEnergyTravel), 'mm'),
  ];
}

List<ToolResult> _invalidSpringResults({
  required bool includeForceTarget,
  required bool includeEnergyTarget,
}) {
  return [
    const ToolResult('弹簧力', '无效', 'N', primary: true),
    const ToolResult('弹簧力幅值', '无效', 'N'),
    const ToolResult('储能', '无效', 'J'),
    const ToolResult('刚度', '无效', 'N/m'),
    const ToolResult('柔度', '无效', 'mm/N'),
    const ToolResult('等效重量', '无效', 'kgf'),
    const ToolResult('变形方向', '无效', ''),
    if (includeForceTarget) const ToolResult('目标弹簧力', '无效', 'N'),
    if (includeForceTarget) const ToolResult('目标力所需变形', '无效', 'mm'),
    if (includeEnergyTarget) const ToolResult('目标储能', '无效', 'J'),
    if (includeEnergyTarget) const ToolResult('目标储能所需变形', '无效', 'mm'),
  ];
}

List<ToolResult> cylinderResults(Map<String, double> valuesByKey) {
  final pressureMpa = valuesByKey['pressure'] ?? 0;
  final boreMm = valuesByKey['bore'] ?? 0;
  final rodMm = valuesByKey['rod'] ?? 0;
  final targetForce = valuesByKey['targetForce'];
  final includeTarget = targetForce != null;
  if (pressureMpa < 0 ||
      boreMm <= 0 ||
      rodMm < 0 ||
      rodMm >= boreMm ||
      !pressureMpa.isFinite ||
      !boreMm.isFinite ||
      !rodMm.isFinite ||
      (targetForce != null && (targetForce < 0 || !targetForce.isFinite))) {
    return _invalidCylinderResults(includeTarget: includeTarget);
  }
  final pressure = pressureMpa * 1e6;
  final bore = boreMm / 1000;
  final rod = rodMm / 1000;
  final area = math.pi * bore * bore / 4;
  final rodArea = math.pi * rod * rod / 4;
  final retractArea = area - rodArea;
  final extendForce = pressure * area;
  final retractForce = pressure * retractArea;
  final targetPressure =
      targetForce == null || area == 0 ? null : targetForce / area / 1e6;
  final targetBore = targetForce == null || pressure <= 0
      ? null
      : math.sqrt(4 * targetForce / pressure / math.pi) * 1000;
  return [
    ToolResult('推出力', formatNumber(extendForce), 'N', primary: true),
    ToolResult('拉回力', formatNumber(retractForce), 'N'),
    ToolResult('推出等效重量', formatNumber(extendForce / 9.80665), 'kgf'),
    ToolResult('拉回等效重量', formatNumber(retractForce / 9.80665), 'kgf'),
    ToolResult('活塞面积', formatNumber(area * 1e6), 'mm²'),
    ToolResult('杆侧有效面积', formatNumber(retractArea * 1e6), 'mm²'),
    ToolResult('杆截面积', formatNumber(rodArea * 1e6), 'mm²'),
    ToolResult('拉力比例', formatNumber(retractArea / area * 100), '%'),
    if (includeTarget) ToolResult('目标推出力', formatNumber(targetForce), 'N'),
    if (includeTarget)
      ToolResult('目标力所需气压',
          targetPressure == null ? '无效' : formatNumber(targetPressure), 'MPa'),
    if (includeTarget)
      ToolResult('目标力所需缸径',
          targetBore == null ? '无效' : formatNumber(targetBore), 'mm'),
    if (includeTarget)
      ToolResult('推出力余量', formatNumber(extendForce - targetForce), 'N'),
  ];
}

List<ToolResult> _invalidCylinderResults({required bool includeTarget}) {
  return [
    const ToolResult('推出力', '无效', 'N', primary: true),
    const ToolResult('拉回力', '无效', 'N'),
    const ToolResult('推出等效重量', '无效', 'kgf'),
    const ToolResult('拉回等效重量', '无效', 'kgf'),
    const ToolResult('活塞面积', '无效', 'mm²'),
    const ToolResult('杆侧有效面积', '无效', 'mm²'),
    const ToolResult('杆截面积', '无效', 'mm²'),
    const ToolResult('拉力比例', '无效', '%'),
    if (includeTarget) const ToolResult('目标推出力', '无效', 'N'),
    if (includeTarget) const ToolResult('目标力所需气压', '无效', 'MPa'),
    if (includeTarget) const ToolResult('目标力所需缸径', '无效', 'mm'),
    if (includeTarget) const ToolResult('推出力余量', '无效', 'N'),
  ];
}

List<ToolResult> forceResults(Map<String, double> valuesByKey) {
  final mass = valuesByKey['mass'] ?? 0;
  final acc = valuesByKey['acc'] ?? 0;
  final targetForce = valuesByKey['targetForce'];
  final includeTarget = targetForce != null;
  if (mass < 0 ||
      !mass.isFinite ||
      !acc.isFinite ||
      (targetForce != null && !targetForce.isFinite)) {
    return _invalidForceResults(includeTarget: includeTarget);
  }
  final force = mass * acc;
  final direction = acc == 0
      ? '无加速度'
      : acc > 0
          ? '正向加速'
          : '反向加速';
  final targetAcceleration =
      targetForce == null || mass == 0 ? null : targetForce / mass;
  final targetMass = targetForce == null || acc == 0 ? null : targetForce / acc;
  return [
    ToolResult('力', formatNumber(force), 'N', primary: true),
    ToolResult('力幅值', formatNumber(force.abs()), 'N'),
    ToolResult('等效重量', formatNumber(force.abs() / 9.80665), 'kgf'),
    ToolResult('加速度', formatNumber(acc / 9.80665), 'g'),
    ToolResult('质量重量', formatNumber(mass * 9.80665), 'N'),
    ToolResult('运动方向', direction, ''),
    if (includeTarget) ToolResult('目标力', formatNumber(targetForce), 'N'),
    if (includeTarget)
      ToolResult(
          '目标力所需加速度',
          targetAcceleration == null ? '无效' : formatNumber(targetAcceleration),
          'm/s²'),
    if (includeTarget)
      ToolResult(
          '目标力所需质量',
          targetMass == null || targetMass < 0
              ? '无效'
              : formatNumber(targetMass),
          'kg'),
  ];
}

List<ToolResult> _invalidForceResults({required bool includeTarget}) {
  return [
    const ToolResult('力', '无效', 'N', primary: true),
    const ToolResult('力幅值', '无效', 'N'),
    const ToolResult('等效重量', '无效', 'kgf'),
    const ToolResult('加速度', '无效', 'g'),
    const ToolResult('质量重量', '无效', 'N'),
    const ToolResult('运动方向', '无效', ''),
    if (includeTarget) const ToolResult('目标力', '无效', 'N'),
    if (includeTarget) const ToolResult('目标力所需加速度', '无效', 'm/s²'),
    if (includeTarget) const ToolResult('目标力所需质量', '无效', 'kg'),
  ];
}

List<ToolResult> pulleyRatioResults(Map<String, double> valuesByKey) {
  final d1 = valuesByKey['d1'] ?? 0;
  final d2 = valuesByKey['d2'] ?? 0;
  final rpm = valuesByKey['rpm'] ?? 0;
  final targetOutputRpm = valuesByKey['targetOutputRpm'];
  final includeTarget = targetOutputRpm != null;
  if (d1 <= 0 ||
      d2 <= 0 ||
      !d1.isFinite ||
      !d2.isFinite ||
      !rpm.isFinite ||
      (targetOutputRpm != null &&
          (targetOutputRpm == 0 || !targetOutputRpm.isFinite))) {
    return _invalidPulleyRatioResults(includeTarget: includeTarget);
  }
  final ratio = d1 / d2;
  final outputRpm = rpm * ratio;
  final beltSpeed = math.pi * (d1 / 1000) * rpm.abs() / 60;
  final direction = rpm == 0 ? '静止' : '开口皮带同向';
  final targetRatio =
      targetOutputRpm == null || rpm == 0 ? null : targetOutputRpm / rpm;
  final targetDrivenDiameter = targetRatio == null ? null : d1 / targetRatio;
  final targetDriverDiameter = targetRatio == null ? null : d2 * targetRatio;
  return [
    ToolResult('输出转速', formatNumber(outputRpm), 'rpm', primary: true),
    ToolResult('速度比 n2/n1', formatNumber(ratio), ''),
    ToolResult('传动比 i', formatNumber(d2 / d1), ''),
    ToolResult('输出角速度', formatNumber(outputRpm * 2 * math.pi / 60), 'rad/s'),
    ToolResult('皮带线速度', formatNumber(beltSpeed), 'm/s'),
    ToolResult('转向', direction, ''),
    if (includeTarget)
      ToolResult('目标输出转速', formatNumber(targetOutputRpm), 'rpm'),
    if (includeTarget)
      ToolResult(
          '目标速度比', targetRatio == null ? '无效' : formatNumber(targetRatio), ''),
    if (includeTarget)
      ToolResult(
          '保留主动轮所需从动轮直径',
          targetDrivenDiameter == null
              ? '无效'
              : formatNumber(targetDrivenDiameter),
          'mm'),
    if (includeTarget)
      ToolResult(
          '保留从动轮所需主动轮直径',
          targetDriverDiameter == null
              ? '无效'
              : formatNumber(targetDriverDiameter),
          'mm'),
  ];
}

List<ToolResult> _invalidPulleyRatioResults({required bool includeTarget}) {
  return [
    const ToolResult('输出转速', '无效', 'rpm', primary: true),
    const ToolResult('速度比 n2/n1', '无效', ''),
    const ToolResult('传动比 i', '无效', ''),
    const ToolResult('输出角速度', '无效', 'rad/s'),
    const ToolResult('皮带线速度', '无效', 'm/s'),
    const ToolResult('转向', '无效', ''),
    if (includeTarget) const ToolResult('目标输出转速', '无效', 'rpm'),
    if (includeTarget) const ToolResult('目标速度比', '无效', ''),
    if (includeTarget) const ToolResult('保留主动轮所需从动轮直径', '无效', 'mm'),
    if (includeTarget) const ToolResult('保留从动轮所需主动轮直径', '无效', 'mm'),
  ];
}

List<ToolResult> screwLeadResults(Map<String, double> valuesByKey) {
  final lead = valuesByKey['lead'] ?? 0;
  final rpm = valuesByKey['rpm'] ?? 0;
  final targetSpeed = valuesByKey['targetSpeed'];
  final includeTarget = targetSpeed != null;
  if (lead <= 0 ||
      !lead.isFinite ||
      !rpm.isFinite ||
      (targetSpeed != null && !targetSpeed.isFinite)) {
    return _invalidScrewLeadResults(includeTarget: includeTarget);
  }
  final mmMin = lead * rpm;
  final direction = rpm == 0
      ? '静止'
      : rpm > 0
          ? '正向'
          : '反向';
  final targetRpm = targetSpeed == null ? null : targetSpeed / lead;
  final targetLead = targetSpeed == null || rpm == 0 ? null : targetSpeed / rpm;
  return [
    ToolResult('线速度', formatNumber(mmMin), 'mm/min', primary: true),
    ToolResult('每秒位移', formatNumber(mmMin / 60), 'mm/s'),
    ToolResult('每转位移', formatNumber(lead), 'mm/rev'),
    ToolResult('每毫米转数', formatNumber(1 / lead), 'rev/mm'),
    ToolResult('转速', formatNumber(rpm / 60), 'rps'),
    ToolResult('小时行程', formatNumber(mmMin * 60 / 1000), 'm/h'),
    ToolResult('运动方向', direction, ''),
    if (includeTarget) ToolResult('目标线速度', formatNumber(targetSpeed), 'mm/min'),
    if (targetRpm != null)
      ToolResult('目标线速度所需转速', formatNumber(targetRpm), 'rpm'),
    if (includeTarget)
      ToolResult('目标线速度所需导程',
          targetLead == null ? '无效' : formatNumber(targetLead), 'mm/rev'),
  ];
}

List<ToolResult> _invalidScrewLeadResults({required bool includeTarget}) {
  return [
    const ToolResult('线速度', '无效', 'mm/min', primary: true),
    const ToolResult('每秒位移', '无效', 'mm/s'),
    const ToolResult('每转位移', '无效', 'mm/rev'),
    const ToolResult('每毫米转数', '无效', 'rev/mm'),
    const ToolResult('转速', '无效', 'rps'),
    const ToolResult('小时行程', '无效', 'm/h'),
    const ToolResult('运动方向', '无效', ''),
    if (includeTarget) const ToolResult('目标线速度', '无效', 'mm/min'),
    if (includeTarget) const ToolResult('目标线速度所需转速', '无效', 'rpm'),
    if (includeTarget) const ToolResult('目标线速度所需导程', '无效', 'mm/rev'),
  ];
}
