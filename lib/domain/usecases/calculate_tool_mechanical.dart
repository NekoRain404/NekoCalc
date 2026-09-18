import 'dart:math' as math;

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
    ToolResult.number('传动比 i', ratio, '', primary: true),
    ToolResult.number('输出转速', outputRpm, 'rpm'),
    ToolResult.number('输出扭矩', outputTorque, 'N·m'),
    ToolResult.number('输入功率', inputPower, 'kW'),
    ToolResult.number('输出功率', outputPower, 'kW'),
    ToolResult.number('损耗功率', lossPower, 'kW'),
    ToolResult.number('输入角速度', rpm * 2 * math.pi / 60, 'rad/s'),
    ToolResult.number('输出角速度', outputRpm * 2 * math.pi / 60, 'rad/s'),
    ToolResult.number('速度比 n1/n2', ratio, ''),
    const ToolResult('旋转方向', '相反', ''),
    if (includeTarget) ToolResult.number('目标输出转速', targetOutputRpm, 'rpm'),
    if (includeTarget) ToolResult.number('目标传动比', targetRatio, ''),
    if (includeTarget) ToolResult.number('保留Z1所需Z2', targetDrivenTeeth, '齿'),
    if (includeTarget) ToolResult.number('保留Z2所需Z1', targetDriverTeeth, '齿'),
    if (includeTarget) ToolResult.number('目标输出扭矩', targetOutputTorque, 'N·m'),
  ];
}

List<ToolResult> _invalidGearRatioResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('传动比 i', '', primary: true),
    const ToolResult.invalid('输出转速', 'rpm'),
    const ToolResult.invalid('输出扭矩', 'N·m'),
    const ToolResult.invalid('输入功率', 'kW'),
    const ToolResult.invalid('输出功率', 'kW'),
    const ToolResult.invalid('损耗功率', 'kW'),
    const ToolResult.invalid('输入角速度', 'rad/s'),
    const ToolResult.invalid('输出角速度', 'rad/s'),
    const ToolResult.invalid('速度比 n1/n2', ''),
    const ToolResult.invalid('旋转方向', ''),
    if (includeTarget) const ToolResult.invalid('目标输出转速', 'rpm'),
    if (includeTarget) const ToolResult.invalid('目标传动比', ''),
    if (includeTarget) const ToolResult.invalid('保留Z1所需Z2', '齿'),
    if (includeTarget) const ToolResult.invalid('保留Z2所需Z1', '齿'),
    if (includeTarget) const ToolResult.invalid('目标输出扭矩', 'N·m'),
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
  // 中文：**先算成数。** `rpm == 0` 那一支产出方明确说算不出来（值就是那条记号）。
  // English: **computed as a number first.** The `rpm == 0` branch is the producer saying plainly
  //          that it cannot be produced (the value is the marker itself).
  final torquePerKw = rpm == 0 ? null : 9550 / rpm;
  final targetTorque =
      targetPower == null || rpm == 0 ? null : targetPower * 9550 / rpm;
  final targetRpm =
      targetPower == null || torque == 0 ? null : targetPower * 9550 / torque;
  return [
    ToolResult.number('功率', kw, 'kW', primary: true),
    ToolResult.number('瓦特', kw * 1000, 'W'),
    ToolResult.number('机械马力', kw * 1.34102, 'hp'),
    ToolResult.number('公制马力', kw * 1.35962, 'PS'),
    ToolResult.number('角速度', omega, 'rad/s'),
    ToolResult.number('转速', rpm / 60, 'rps'),
    ToolResult('功率方向', direction, ''),
    ToolResult.number('1kW所需扭矩', torquePerKw, 'N·m'),
    if (includeTarget) ToolResult.number('目标功率', targetPower, 'kW'),
    if (includeTarget) ToolResult.number('目标功率所需扭矩', targetTorque, 'N·m'),
    if (includeTarget) ToolResult.number('目标功率所需转速', targetRpm, 'rpm'),
  ];
}

List<ToolResult> _invalidTorquePowerResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('功率', 'kW', primary: true),
    const ToolResult.invalid('瓦特', 'W'),
    const ToolResult.invalid('机械马力', 'hp'),
    const ToolResult.invalid('公制马力', 'PS'),
    const ToolResult.invalid('角速度', 'rad/s'),
    const ToolResult.invalid('转速', 'rps'),
    const ToolResult.invalid('功率方向', ''),
    const ToolResult.invalid('1kW所需扭矩', 'N·m'),
    if (includeTarget) const ToolResult.invalid('目标功率', 'kW'),
    if (includeTarget) const ToolResult.invalid('目标功率所需扭矩', 'N·m'),
    if (includeTarget) const ToolResult.invalid('目标功率所需转速', 'rpm'),
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
    ToolResult.number('弹簧力', force, 'N', primary: true),
    ToolResult.number('弹簧力幅值', force.abs(), 'N'),
    ToolResult.number('储能', energy, 'J'),
    ToolResult.number('刚度', stiffness * 1000, 'N/m'),
    ToolResult.number('柔度', 1 / stiffness, 'mm/N'),
    ToolResult.number('等效重量', force.abs() / 9.80665, 'kgf'),
    ToolResult('变形方向', direction, ''),
    if (includeForceTarget) ToolResult.number('目标弹簧力', targetForce, 'N'),
    if (targetForceTravel != null)
      ToolResult.number('目标力所需变形', targetForceTravel, 'mm'),
    if (includeEnergyTarget) ToolResult.number('目标储能', targetEnergy, 'J'),
    if (targetEnergyTravel != null)
      ToolResult.number('目标储能所需变形', targetEnergyTravel, 'mm'),
  ];
}

List<ToolResult> _invalidSpringResults({
  required bool includeForceTarget,
  required bool includeEnergyTarget,
}) {
  return [
    const ToolResult.invalid('弹簧力', 'N', primary: true),
    const ToolResult.invalid('弹簧力幅值', 'N'),
    const ToolResult.invalid('储能', 'J'),
    const ToolResult.invalid('刚度', 'N/m'),
    const ToolResult.invalid('柔度', 'mm/N'),
    const ToolResult.invalid('等效重量', 'kgf'),
    const ToolResult.invalid('变形方向', ''),
    if (includeForceTarget) const ToolResult.invalid('目标弹簧力', 'N'),
    if (includeForceTarget) const ToolResult.invalid('目标力所需变形', 'mm'),
    if (includeEnergyTarget) const ToolResult.invalid('目标储能', 'J'),
    if (includeEnergyTarget) const ToolResult.invalid('目标储能所需变形', 'mm'),
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
    ToolResult.number('推出力', extendForce, 'N', primary: true),
    ToolResult.number('拉回力', retractForce, 'N'),
    ToolResult.number('推出等效重量', extendForce / 9.80665, 'kgf'),
    ToolResult.number('拉回等效重量', retractForce / 9.80665, 'kgf'),
    ToolResult.number('活塞面积', area * 1e6, 'mm²'),
    ToolResult.number('杆侧有效面积', retractArea * 1e6, 'mm²'),
    ToolResult.number('杆截面积', rodArea * 1e6, 'mm²'),
    ToolResult.number('拉力比例', retractArea / area * 100, '%'),
    if (includeTarget) ToolResult.number('目标推出力', targetForce, 'N'),
    if (includeTarget) ToolResult.number('目标力所需气压', targetPressure, 'MPa'),
    if (includeTarget) ToolResult.number('目标力所需缸径', targetBore, 'mm'),
    if (includeTarget)
      ToolResult.number('推出力余量', extendForce - targetForce, 'N'),
  ];
}

List<ToolResult> _invalidCylinderResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('推出力', 'N', primary: true),
    const ToolResult.invalid('拉回力', 'N'),
    const ToolResult.invalid('推出等效重量', 'kgf'),
    const ToolResult.invalid('拉回等效重量', 'kgf'),
    const ToolResult.invalid('活塞面积', 'mm²'),
    const ToolResult.invalid('杆侧有效面积', 'mm²'),
    const ToolResult.invalid('杆截面积', 'mm²'),
    const ToolResult.invalid('拉力比例', '%'),
    if (includeTarget) const ToolResult.invalid('目标推出力', 'N'),
    if (includeTarget) const ToolResult.invalid('目标力所需气压', 'MPa'),
    if (includeTarget) const ToolResult.invalid('目标力所需缸径', 'mm'),
    if (includeTarget) const ToolResult.invalid('推出力余量', 'N'),
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
    ToolResult.number('力', force, 'N', primary: true),
    ToolResult.number('力幅值', force.abs(), 'N'),
    ToolResult.number('等效重量', force.abs() / 9.80665, 'kgf'),
    ToolResult.number('加速度', acc / 9.80665, 'g'),
    ToolResult.number('质量重量', mass * 9.80665, 'N'),
    ToolResult('运动方向', direction, ''),
    if (includeTarget) ToolResult.number('目标力', targetForce, 'N'),
    if (includeTarget)
      ToolResult.number('目标力所需加速度', targetAcceleration, 'm/s²'),
    if (includeTarget)
      ToolResult.number('目标力所需质量',
          targetMass == null || targetMass < 0 ? null : targetMass, 'kg'),
  ];
}

List<ToolResult> _invalidForceResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('力', 'N', primary: true),
    const ToolResult.invalid('力幅值', 'N'),
    const ToolResult.invalid('等效重量', 'kgf'),
    const ToolResult.invalid('加速度', 'g'),
    const ToolResult.invalid('质量重量', 'N'),
    const ToolResult.invalid('运动方向', ''),
    if (includeTarget) const ToolResult.invalid('目标力', 'N'),
    if (includeTarget) const ToolResult.invalid('目标力所需加速度', 'm/s²'),
    if (includeTarget) const ToolResult.invalid('目标力所需质量', 'kg'),
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
    ToolResult.number('输出转速', outputRpm, 'rpm', primary: true),
    ToolResult.number('速度比 n2/n1', ratio, ''),
    ToolResult.number('传动比 i', d2 / d1, ''),
    ToolResult.number('输出角速度', outputRpm * 2 * math.pi / 60, 'rad/s'),
    ToolResult.number('皮带线速度', beltSpeed, 'm/s'),
    ToolResult('转向', direction, ''),
    if (includeTarget) ToolResult.number('目标输出转速', targetOutputRpm, 'rpm'),
    if (includeTarget) ToolResult.number('目标速度比', targetRatio, ''),
    if (includeTarget)
      ToolResult.number('保留主动轮所需从动轮直径', targetDrivenDiameter, 'mm'),
    if (includeTarget)
      ToolResult.number('保留从动轮所需主动轮直径', targetDriverDiameter, 'mm'),
  ];
}

List<ToolResult> _invalidPulleyRatioResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('输出转速', 'rpm', primary: true),
    const ToolResult.invalid('速度比 n2/n1', ''),
    const ToolResult.invalid('传动比 i', ''),
    const ToolResult.invalid('输出角速度', 'rad/s'),
    const ToolResult.invalid('皮带线速度', 'm/s'),
    const ToolResult.invalid('转向', ''),
    if (includeTarget) const ToolResult.invalid('目标输出转速', 'rpm'),
    if (includeTarget) const ToolResult.invalid('目标速度比', ''),
    if (includeTarget) const ToolResult.invalid('保留主动轮所需从动轮直径', 'mm'),
    if (includeTarget) const ToolResult.invalid('保留从动轮所需主动轮直径', 'mm'),
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
    ToolResult.number('线速度', mmMin, 'mm/min', primary: true),
    ToolResult.number('每秒位移', mmMin / 60, 'mm/s'),
    ToolResult.number('每转位移', lead, 'mm/rev'),
    ToolResult.number('每毫米转数', 1 / lead, 'rev/mm'),
    ToolResult.number('转速', rpm / 60, 'rps'),
    ToolResult.number('小时行程', mmMin * 60 / 1000, 'm/h'),
    ToolResult('运动方向', direction, ''),
    if (includeTarget) ToolResult.number('目标线速度', targetSpeed, 'mm/min'),
    if (targetRpm != null) ToolResult.number('目标线速度所需转速', targetRpm, 'rpm'),
    if (includeTarget) ToolResult.number('目标线速度所需导程', targetLead, 'mm/rev'),
  ];
}

List<ToolResult> _invalidScrewLeadResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('线速度', 'mm/min', primary: true),
    const ToolResult.invalid('每秒位移', 'mm/s'),
    const ToolResult.invalid('每转位移', 'mm/rev'),
    const ToolResult.invalid('每毫米转数', 'rev/mm'),
    const ToolResult.invalid('转速', 'rps'),
    const ToolResult.invalid('小时行程', 'm/h'),
    const ToolResult.invalid('运动方向', ''),
    if (includeTarget) const ToolResult.invalid('目标线速度', 'mm/min'),
    if (includeTarget) const ToolResult.invalid('目标线速度所需转速', 'rpm'),
    if (includeTarget) const ToolResult.invalid('目标线速度所需导程', 'mm/rev'),
  ];
}
