import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

export 'calculate_tool_physics_matter.dart';
export 'calculate_tool_physics_waves.dart';

List<ToolResult> motionResults(Map<String, double> valuesByKey) {
  final speedInput = valuesByKey['speed'];
  final timeInput = valuesByKey['time'];
  final distanceInput = valuesByKey['distance'];
  final validInputs = [
    speedInput,
    timeInput,
    distanceInput,
  ].where((value) => value != null).length;
  if (validInputs < 2 ||
      (speedInput != null && (speedInput < 0 || !speedInput.isFinite)) ||
      (timeInput != null && (timeInput < 0 || !timeInput.isFinite)) ||
      (distanceInput != null &&
          (distanceInput < 0 || !distanceInput.isFinite))) {
    return _invalidMotionResults();
  }

  double speed;
  double time;
  double distance;
  String source;
  if (speedInput != null && timeInput != null) {
    speed = speedInput;
    time = timeInput;
    distance = speed * time;
    source = distanceInput == null ? '速度+时间' : '速度+时间，距离作参考';
  } else if (distanceInput != null && timeInput != null) {
    if (timeInput == 0) return _invalidMotionResults();
    distance = distanceInput;
    time = timeInput;
    speed = distance / time;
    source = '距离+时间';
  } else if (distanceInput != null && speedInput != null) {
    if (speedInput == 0) return _invalidMotionResults();
    distance = distanceInput;
    speed = speedInput;
    time = distance / speed;
    source = '距离+速度';
  } else {
    return _invalidMotionResults();
  }

  final referenceDelta = distanceInput == null ? 0.0 : distance - distanceInput;
  return [
    ToolResult('距离', formatNumber(distance), 'm', primary: true),
    ToolResult('距离 km', formatNumber(distance / 1000), 'km'),
    ToolResult('速度', formatNumber(speed * 3.6), 'km/h'),
    ToolResult('速度 m/s', formatNumber(speed), 'm/s'),
    ToolResult('速度 mph', formatNumber(speed * 2.2369362921), 'mph'),
    ToolResult('时间', formatNumber(time), 's'),
    ToolResult('时间 min', formatNumber(time / 60), 'min'),
    ToolResult('时间 h', formatNumber(time / 3600), 'h'),
    ToolResult(
        '配速', speed <= 0 ? '无效' : formatNumber(1000 / speed / 60), 'min/km'),
    ToolResult('往返时间', formatNumber(time * 2), 's'),
    ToolResult('输入来源', source, ''),
    if (distanceInput != null && speedInput != null && timeInput != null)
      ToolResult('距离差值', formatNumber(referenceDelta), 'm'),
  ];
}

List<ToolResult> _invalidMotionResults() {
  return const [
    ToolResult('距离', '无效', 'm', primary: true),
    ToolResult('距离 km', '无效', 'km'),
    ToolResult('速度', '无效', 'km/h'),
    ToolResult('速度 m/s', '无效', 'm/s'),
    ToolResult('速度 mph', '无效', 'mph'),
    ToolResult('时间', '无效', 's'),
    ToolResult('时间 min', '无效', 'min'),
    ToolResult('时间 h', '无效', 'h'),
    ToolResult('配速', '无效', 'min/km'),
    ToolResult('往返时间', '无效', 's'),
    ToolResult('输入来源', '无效', ''),
  ];
}

List<ToolResult> freeFallResults(Map<String, double> valuesByKey) {
  final height = valuesByKey['height'] ?? 0;
  final initialSpeed = valuesByKey['initialSpeed'] ?? 0;
  final g = valuesByKey['g'] ?? 9.80665;
  final mass = valuesByKey['mass'];
  final bufferDistance = valuesByKey['bufferDistance'];
  final includeBuffer = bufferDistance != null;
  if (height < 0 ||
      g <= 0 ||
      !height.isFinite ||
      !initialSpeed.isFinite ||
      !g.isFinite ||
      (mass != null && (mass < 0 || !mass.isFinite)) ||
      (bufferDistance != null &&
          (bufferDistance <= 0 || !bufferDistance.isFinite))) {
    return _invalidFreeFallResults(
      includeMass: mass != null,
      includeBuffer: includeBuffer,
    );
  }

  final endSpeedSquared = initialSpeed * initialSpeed + 2 * g * height;
  final endSpeedMagnitude = math.sqrt(endSpeedSquared);
  final endSpeed = endSpeedMagnitude;
  final time = (endSpeed - initialSpeed) / g;
  final averageSpeed = height == 0 && time == 0 ? initialSpeed : height / time;
  final speedDelta = endSpeed - initialSpeed;
  final direction = initialSpeed < 0 ? '先上抛后下落' : '向下';
  final results = <ToolResult>[
    ToolResult('落地时间', formatNumber(time), 's', primary: true),
    ToolResult('末速度', formatNumber(endSpeed), 'm/s'),
    ToolResult('末速度 km/h', formatNumber(endSpeed * 3.6), 'km/h'),
    ToolResult('平均速度', formatNumber(averageSpeed), 'm/s'),
    ToolResult('初速度', formatNumber(initialSpeed), 'm/s'),
    ToolResult('速度增量', formatNumber(speedDelta), 'm/s'),
    ToolResult('高度', formatNumber(height), 'm'),
    ToolResult('重力加速度', formatNumber(g), 'm/s²'),
    ToolResult('运动方向', direction, ''),
  ];
  if (mass != null) {
    final potentialChange = mass * g * height;
    final initialKinetic = 0.5 * mass * initialSpeed * initialSpeed;
    final impactEnergy = 0.5 * mass * endSpeed * endSpeed;
    results.addAll([
      ToolResult('势能变化', formatNumber(potentialChange), 'J'),
      ToolResult('初始动能', formatNumber(initialKinetic), 'J'),
      ToolResult('末端动能', formatNumber(impactEnergy), 'J'),
      ToolResult('冲击能量', formatNumber(impactEnergy), 'J'),
    ]);
    if (bufferDistance != null) {
      final averageImpactForce = impactEnergy / bufferDistance;
      final averageDeceleration =
          mass == 0 ? double.nan : averageImpactForce / mass;
      results.addAll([
        ToolResult('缓冲距离', formatNumber(bufferDistance), 'm'),
        ToolResult('缓冲平均力', formatNumber(averageImpactForce), 'N'),
        ToolResult(
            '缓冲平均减速度',
            averageDeceleration.isFinite
                ? formatNumber(averageDeceleration)
                : '无效',
            'm/s²'),
        ToolResult(
            '缓冲减速度',
            averageDeceleration.isFinite
                ? formatNumber(averageDeceleration / 9.80665)
                : '无效',
            'g'),
      ]);
    }
  } else if (bufferDistance != null) {
    results.addAll([
      ToolResult('缓冲距离', formatNumber(bufferDistance), 'm'),
      const ToolResult('缓冲平均力', '无效', 'N'),
      const ToolResult('缓冲平均减速度', '无效', 'm/s²'),
      const ToolResult('缓冲减速度', '无效', 'g'),
    ]);
  }
  return results;
}

List<ToolResult> _invalidFreeFallResults({
  required bool includeMass,
  required bool includeBuffer,
}) {
  return [
    const ToolResult('落地时间', '无效', 's', primary: true),
    const ToolResult('末速度', '无效', 'm/s'),
    const ToolResult('末速度 km/h', '无效', 'km/h'),
    const ToolResult('平均速度', '无效', 'm/s'),
    const ToolResult('初速度', '无效', 'm/s'),
    const ToolResult('速度增量', '无效', 'm/s'),
    const ToolResult('高度', '无效', 'm'),
    const ToolResult('重力加速度', '无效', 'm/s²'),
    const ToolResult('运动方向', '无效', ''),
    if (includeMass) const ToolResult('势能变化', '无效', 'J'),
    if (includeMass) const ToolResult('初始动能', '无效', 'J'),
    if (includeMass) const ToolResult('末端动能', '无效', 'J'),
    if (includeMass) const ToolResult('冲击能量', '无效', 'J'),
    if (includeBuffer) const ToolResult('缓冲距离', '无效', 'm'),
    if (includeBuffer) const ToolResult('缓冲平均力', '无效', 'N'),
    if (includeBuffer) const ToolResult('缓冲平均减速度', '无效', 'm/s²'),
    if (includeBuffer) const ToolResult('缓冲减速度', '无效', 'g'),
  ];
}

List<ToolResult> workPowerResults(Map<String, double> valuesByKey) {
  final force = valuesByKey['force'] ?? 0;
  final distance = valuesByKey['distance'] ?? 0;
  final time = valuesByKey['time'] ?? 0;
  final angle = valuesByKey['angle'] ?? 0;
  final efficiencyPercent = valuesByKey['efficiency'] ?? 100;
  final targetPower = valuesByKey['targetPower'];
  final includeTarget = targetPower != null;
  if (time <= 0 ||
      efficiencyPercent <= 0 ||
      efficiencyPercent > 100 ||
      !force.isFinite ||
      !distance.isFinite ||
      !time.isFinite ||
      !angle.isFinite ||
      !efficiencyPercent.isFinite ||
      (targetPower != null && !targetPower.isFinite)) {
    return _invalidWorkPowerResults(includeTarget: includeTarget);
  }

  final cosTheta = math.cos(angle * math.pi / 180);
  final apparentWork = force * distance;
  final work = apparentWork * cosTheta;
  final outputPower = work / time;
  final efficiency = efficiencyPercent / 100;
  final inputEnergy = work / efficiency;
  final inputPower = outputPower / efficiency;
  final lossEnergy = inputEnergy - work;
  final lossPower = inputPower - outputPower;
  final targetTime =
      targetPower == null || targetPower == 0 ? null : work / targetPower;
  final targetForce =
      targetPower == null || distance == 0 || cosTheta.abs() < 1e-12
          ? null
          : targetPower * time / (distance * cosTheta);
  return [
    ToolResult('功', formatNumber(work), 'J', primary: true),
    ToolResult('平均功率', formatNumber(outputPower), 'W'),
    ToolResult('功率 kW', formatNumber(outputPower / 1000), 'kW'),
    ToolResult('输入功率', formatNumber(inputPower), 'W'),
    ToolResult('损耗功率', formatNumber(lossPower), 'W'),
    ToolResult('表观功', formatNumber(apparentWork), 'J'),
    ToolResult('输入能量', formatNumber(inputEnergy), 'J'),
    ToolResult('损耗能量', formatNumber(lossEnergy), 'J'),
    ToolResult('Wh', formatNumber(work / 3600), 'Wh'),
    ToolResult('kWh', formatNumber(work / 3600000), 'kWh'),
    ToolResult('机械马力', formatNumber(outputPower / 745.699872), 'hp'),
    ToolResult('公制马力', formatNumber(outputPower / 735.49875), 'PS'),
    ToolResult('力-位移夹角', formatNumber(angle), 'deg'),
    ToolResult('效率', formatNumber(efficiencyPercent), '%'),
    ToolResult('做功方向', work > 0 ? '正功' : (work < 0 ? '负功' : '无功'), ''),
    if (includeTarget) ToolResult('目标功率', formatNumber(targetPower), 'W'),
    if (includeTarget)
      ToolResult(
          '目标功率所需时间',
          targetTime == null || targetTime <= 0
              ? '无效'
              : formatNumber(targetTime),
          's'),
    if (includeTarget)
      ToolResult('目标功率所需力',
          targetForce == null ? '无效' : formatNumber(targetForce), 'N'),
    if (includeTarget)
      ToolResult('目标功率偏差', formatNumber(outputPower - targetPower), 'W'),
  ];
}

List<ToolResult> _invalidWorkPowerResults({required bool includeTarget}) {
  return [
    const ToolResult('功', '无效', 'J', primary: true),
    const ToolResult('平均功率', '无效', 'W'),
    const ToolResult('功率 kW', '无效', 'kW'),
    const ToolResult('输入功率', '无效', 'W'),
    const ToolResult('损耗功率', '无效', 'W'),
    const ToolResult('表观功', '无效', 'J'),
    const ToolResult('输入能量', '无效', 'J'),
    const ToolResult('损耗能量', '无效', 'J'),
    const ToolResult('Wh', '无效', 'Wh'),
    const ToolResult('kWh', '无效', 'kWh'),
    const ToolResult('机械马力', '无效', 'hp'),
    const ToolResult('公制马力', '无效', 'PS'),
    const ToolResult('力-位移夹角', '无效', 'deg'),
    const ToolResult('效率', '无效', '%'),
    const ToolResult('做功方向', '无效', ''),
    if (includeTarget) const ToolResult('目标功率', '无效', 'W'),
    if (includeTarget) const ToolResult('目标功率所需时间', '无效', 's'),
    if (includeTarget) const ToolResult('目标功率所需力', '无效', 'N'),
    if (includeTarget) const ToolResult('目标功率偏差', '无效', 'W'),
  ];
}

List<ToolResult> densityResults(Map<String, double> valuesByKey) {
  final massInput = valuesByKey['mass'];
  final volumeInput = valuesByKey['volume'];
  final densityInput = valuesByKey['density'];
  final validInputs = [
    massInput,
    volumeInput,
    densityInput,
  ].where((value) => value != null).length;
  if (validInputs < 2 ||
      (massInput != null && (massInput < 0 || !massInput.isFinite)) ||
      (volumeInput != null && (volumeInput <= 0 || !volumeInput.isFinite)) ||
      (densityInput != null && (densityInput <= 0 || !densityInput.isFinite))) {
    return _invalidDensityResults();
  }

  double mass;
  double volume;
  double density;
  String source;
  if (massInput != null && volumeInput != null) {
    mass = massInput;
    volume = volumeInput;
    density = mass / volume;
    source = densityInput == null ? '质量+体积' : '质量+体积，密度作参考';
  } else if (massInput != null && densityInput != null) {
    mass = massInput;
    density = densityInput;
    volume = mass / density;
    source = '质量+密度';
  } else if (volumeInput != null && densityInput != null) {
    volume = volumeInput;
    density = densityInput;
    mass = density * volume;
    source = '体积+密度';
  } else {
    return _invalidDensityResults();
  }

  final densityDelta = densityInput == null ? 0.0 : density - densityInput;
  return [
    ToolResult('密度', formatNumber(density), 'kg/m³', primary: true),
    ToolResult('g/cm³', formatNumber(density / 1000), 'g/cm³'),
    ToolResult('kg/L', formatNumber(density / 1000), 'kg/L'),
    ToolResult('比容', density <= 0 ? '无效' : formatNumber(1 / density), 'm³/kg'),
    ToolResult('质量', formatNumber(mass), 'kg'),
    ToolResult('体积', formatNumber(volume * 1000), 'L'),
    ToolResult('体积 m³', formatNumber(volume), 'm³'),
    ToolResult('输入来源', source, ''),
    if (massInput != null && volumeInput != null && densityInput != null)
      ToolResult('密度差值', formatNumber(densityDelta), 'kg/m³'),
  ];
}

List<ToolResult> _invalidDensityResults() {
  return const [
    ToolResult('密度', '无效', 'kg/m³', primary: true),
    ToolResult('g/cm³', '无效', 'g/cm³'),
    ToolResult('kg/L', '无效', 'kg/L'),
    ToolResult('比容', '无效', 'm³/kg'),
    ToolResult('质量', '无效', 'kg'),
    ToolResult('体积', '无效', 'L'),
    ToolResult('体积 m³', '无效', 'm³'),
    ToolResult('输入来源', '无效', ''),
  ];
}

List<ToolResult> kineticEnergyResults(Map<String, double> valuesByKey) {
  final mass = valuesByKey['mass'] ?? 0;
  final speed = valuesByKey['speed'] ?? 0;
  final height = valuesByKey['height'] ?? 0;
  final targetTotalEnergy = valuesByKey['targetTotalEnergy'];
  final includeTarget = targetTotalEnergy != null;
  if (mass < 0 ||
      !mass.isFinite ||
      !speed.isFinite ||
      !height.isFinite ||
      (targetTotalEnergy != null && !targetTotalEnergy.isFinite)) {
    return _invalidKineticEnergyResults(includeTarget: includeTarget);
  }

  final kinetic = 0.5 * mass * speed * speed;
  final potential = mass * 9.80665 * height;
  final total = kinetic + potential;
  final targetSpeed = targetTotalEnergy == null || mass == 0
      ? null
      : math.sqrt(2 * (targetTotalEnergy - potential) / mass);
  final targetHeight = targetTotalEnergy == null || mass == 0
      ? null
      : (targetTotalEnergy - kinetic) / (mass * 9.80665);
  return [
    ToolResult('总能量', formatNumber(total), 'J', primary: true),
    ToolResult('动能', formatNumber(kinetic), 'J'),
    ToolResult('势能', formatNumber(potential), 'J'),
    ToolResult('速度幅值', formatNumber(speed.abs()), 'm/s'),
    ToolResult('速度', formatNumber(speed.abs() * 3.6), 'km/h'),
    ToolResult(
        '单位质量动能', mass == 0 ? '无效' : formatNumber(kinetic / mass), 'J/kg'),
    ToolResult(
        '等效高度', mass == 0 ? '无效' : formatNumber(total / (mass * 9.80665)), 'm'),
    if (includeTarget)
      ToolResult('目标总能量', formatNumber(targetTotalEnergy), 'J'),
    if (includeTarget)
      ToolResult(
          '目标能量所需速度',
          targetSpeed == null || !targetSpeed.isFinite
              ? '无效'
              : formatNumber(targetSpeed),
          'm/s'),
    if (includeTarget)
      ToolResult('目标能量所需高度',
          targetHeight == null ? '无效' : formatNumber(targetHeight), 'm'),
    if (includeTarget)
      ToolResult('目标能量差值', formatNumber(total - targetTotalEnergy), 'J'),
  ];
}

List<ToolResult> _invalidKineticEnergyResults({
  required bool includeTarget,
}) {
  return [
    const ToolResult('总能量', '无效', 'J', primary: true),
    const ToolResult('动能', '无效', 'J'),
    const ToolResult('势能', '无效', 'J'),
    const ToolResult('速度幅值', '无效', 'm/s'),
    const ToolResult('速度', '无效', 'km/h'),
    const ToolResult('单位质量动能', '无效', 'J/kg'),
    const ToolResult('等效高度', '无效', 'm'),
    if (includeTarget) const ToolResult('目标总能量', '无效', 'J'),
    if (includeTarget) const ToolResult('目标能量所需速度', '无效', 'm/s'),
    if (includeTarget) const ToolResult('目标能量所需高度', '无效', 'm'),
    if (includeTarget) const ToolResult('目标能量差值', '无效', 'J'),
  ];
}
