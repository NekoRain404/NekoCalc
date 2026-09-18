import 'dart:math' as math;

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
    ToolResult.number('距离', distance, 'm', primary: true),
    ToolResult.number('距离 km', distance / 1000, 'km'),
    ToolResult.number('速度', speed * 3.6, 'km/h'),
    ToolResult.number('速度 m/s', speed, 'm/s'),
    ToolResult.number('速度 mph', speed * 2.2369362921, 'mph'),
    ToolResult.number('时间', time, 's'),
    ToolResult.number('时间 min', time / 60, 'min'),
    ToolResult.number('时间 h', time / 3600, 'h'),
    ToolResult.number('配速', speed <= 0 ? null : 1000 / speed / 60, 'min/km'),
    ToolResult.number('往返时间', time * 2, 's'),
    ToolResult('输入来源', source, ''),
    if (distanceInput != null && speedInput != null && timeInput != null)
      ToolResult.number('距离差值', referenceDelta, 'm'),
  ];
}

List<ToolResult> _invalidMotionResults() {
  return const [
    ToolResult.invalid('距离', 'm', primary: true),
    ToolResult.invalid('距离 km', 'km'),
    ToolResult.invalid('速度', 'km/h'),
    ToolResult.invalid('速度 m/s', 'm/s'),
    ToolResult.invalid('速度 mph', 'mph'),
    ToolResult.invalid('时间', 's'),
    ToolResult.invalid('时间 min', 'min'),
    ToolResult.invalid('时间 h', 'h'),
    ToolResult.invalid('配速', 'min/km'),
    ToolResult.invalid('往返时间', 's'),
    ToolResult.invalid('输入来源', ''),
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
    ToolResult.number('落地时间', time, 's', primary: true),
    ToolResult.number('末速度', endSpeed, 'm/s'),
    ToolResult.number('末速度 km/h', endSpeed * 3.6, 'km/h'),
    ToolResult.number('平均速度', averageSpeed, 'm/s'),
    ToolResult.number('初速度', initialSpeed, 'm/s'),
    ToolResult.number('速度增量', speedDelta, 'm/s'),
    ToolResult.number('高度', height, 'm'),
    ToolResult.number('重力加速度', g, 'm/s²'),
    ToolResult('运动方向', direction, ''),
  ];
  if (mass != null) {
    final potentialChange = mass * g * height;
    final initialKinetic = 0.5 * mass * initialSpeed * initialSpeed;
    final impactEnergy = 0.5 * mass * endSpeed * endSpeed;
    results.addAll([
      ToolResult.number('势能变化', potentialChange, 'J'),
      ToolResult.number('初始动能', initialKinetic, 'J'),
      ToolResult.number('末端动能', impactEnergy, 'J'),
      ToolResult.number('冲击能量', impactEnergy, 'J'),
    ]);
    if (bufferDistance != null) {
      final averageImpactForce = impactEnergy / bufferDistance;
      final averageDeceleration =
          mass == 0 ? double.nan : averageImpactForce / mass;
      results.addAll([
        ToolResult.number('缓冲距离', bufferDistance, 'm'),
        ToolResult.number('缓冲平均力', averageImpactForce, 'N'),
        ToolResult.number('缓冲平均减速度',
            averageDeceleration.isFinite ? averageDeceleration : null, 'm/s²'),
        ToolResult.number(
            '缓冲减速度',
            averageDeceleration.isFinite ? averageDeceleration / 9.80665 : null,
            'g'),
      ]);
    }
  } else if (bufferDistance != null) {
    results.addAll([
      ToolResult.number('缓冲距离', bufferDistance, 'm'),
      const ToolResult.invalid('缓冲平均力', 'N'),
      const ToolResult.invalid('缓冲平均减速度', 'm/s²'),
      const ToolResult.invalid('缓冲减速度', 'g'),
    ]);
  }
  return results;
}

List<ToolResult> _invalidFreeFallResults({
  required bool includeMass,
  required bool includeBuffer,
}) {
  return [
    const ToolResult.invalid('落地时间', 's', primary: true),
    const ToolResult.invalid('末速度', 'm/s'),
    const ToolResult.invalid('末速度 km/h', 'km/h'),
    const ToolResult.invalid('平均速度', 'm/s'),
    const ToolResult.invalid('初速度', 'm/s'),
    const ToolResult.invalid('速度增量', 'm/s'),
    const ToolResult.invalid('高度', 'm'),
    const ToolResult.invalid('重力加速度', 'm/s²'),
    const ToolResult.invalid('运动方向', ''),
    if (includeMass) const ToolResult.invalid('势能变化', 'J'),
    if (includeMass) const ToolResult.invalid('初始动能', 'J'),
    if (includeMass) const ToolResult.invalid('末端动能', 'J'),
    if (includeMass) const ToolResult.invalid('冲击能量', 'J'),
    if (includeBuffer) const ToolResult.invalid('缓冲距离', 'm'),
    if (includeBuffer) const ToolResult.invalid('缓冲平均力', 'N'),
    if (includeBuffer) const ToolResult.invalid('缓冲平均减速度', 'm/s²'),
    if (includeBuffer) const ToolResult.invalid('缓冲减速度', 'g'),
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
    ToolResult.number('功', work, 'J', primary: true),
    ToolResult.number('平均功率', outputPower, 'W'),
    ToolResult.number('功率 kW', outputPower / 1000, 'kW'),
    ToolResult.number('输入功率', inputPower, 'W'),
    ToolResult.number('损耗功率', lossPower, 'W'),
    ToolResult.number('表观功', apparentWork, 'J'),
    ToolResult.number('输入能量', inputEnergy, 'J'),
    ToolResult.number('损耗能量', lossEnergy, 'J'),
    ToolResult.number('Wh', work / 3600, 'Wh'),
    ToolResult.number('kWh', work / 3600000, 'kWh'),
    ToolResult.number('机械马力', outputPower / 745.699872, 'hp'),
    ToolResult.number('公制马力', outputPower / 735.49875, 'PS'),
    ToolResult.number('力-位移夹角', angle, 'deg'),
    ToolResult.number('效率', efficiencyPercent, '%'),
    ToolResult('做功方向', work > 0 ? '正功' : (work < 0 ? '负功' : '无功'), ''),
    if (includeTarget) ToolResult.number('目标功率', targetPower, 'W'),
    if (includeTarget)
      ToolResult.number('目标功率所需时间',
          targetTime == null || targetTime <= 0 ? null : targetTime, 's'),
    if (includeTarget) ToolResult.number('目标功率所需力', targetForce, 'N'),
    if (includeTarget)
      ToolResult.number('目标功率偏差', outputPower - targetPower, 'W'),
  ];
}

List<ToolResult> _invalidWorkPowerResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('功', 'J', primary: true),
    const ToolResult.invalid('平均功率', 'W'),
    const ToolResult.invalid('功率 kW', 'kW'),
    const ToolResult.invalid('输入功率', 'W'),
    const ToolResult.invalid('损耗功率', 'W'),
    const ToolResult.invalid('表观功', 'J'),
    const ToolResult.invalid('输入能量', 'J'),
    const ToolResult.invalid('损耗能量', 'J'),
    const ToolResult.invalid('Wh', 'Wh'),
    const ToolResult.invalid('kWh', 'kWh'),
    const ToolResult.invalid('机械马力', 'hp'),
    const ToolResult.invalid('公制马力', 'PS'),
    const ToolResult.invalid('力-位移夹角', 'deg'),
    const ToolResult.invalid('效率', '%'),
    const ToolResult.invalid('做功方向', ''),
    if (includeTarget) const ToolResult.invalid('目标功率', 'W'),
    if (includeTarget) const ToolResult.invalid('目标功率所需时间', 's'),
    if (includeTarget) const ToolResult.invalid('目标功率所需力', 'N'),
    if (includeTarget) const ToolResult.invalid('目标功率偏差', 'W'),
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
    ToolResult.number('密度', density, 'kg/m³', primary: true),
    ToolResult.number('g/cm³', density / 1000, 'g/cm³'),
    ToolResult.number('kg/L', density / 1000, 'kg/L'),
    ToolResult.number('比容', density <= 0 ? null : 1 / density, 'm³/kg'),
    ToolResult.number('质量', mass, 'kg'),
    ToolResult.number('体积', volume * 1000, 'L'),
    ToolResult.number('体积 m³', volume, 'm³'),
    ToolResult('输入来源', source, ''),
    if (massInput != null && volumeInput != null && densityInput != null)
      ToolResult.number('密度差值', densityDelta, 'kg/m³'),
  ];
}

List<ToolResult> _invalidDensityResults() {
  return const [
    ToolResult.invalid('密度', 'kg/m³', primary: true),
    ToolResult.invalid('g/cm³', 'g/cm³'),
    ToolResult.invalid('kg/L', 'kg/L'),
    ToolResult.invalid('比容', 'm³/kg'),
    ToolResult.invalid('质量', 'kg'),
    ToolResult.invalid('体积', 'L'),
    ToolResult.invalid('体积 m³', 'm³'),
    ToolResult.invalid('输入来源', ''),
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
    ToolResult.number('总能量', total, 'J', primary: true),
    ToolResult.number('动能', kinetic, 'J'),
    ToolResult.number('势能', potential, 'J'),
    ToolResult.number('速度幅值', speed.abs(), 'm/s'),
    ToolResult.number('速度', speed.abs() * 3.6, 'km/h'),
    ToolResult.number('单位质量动能', mass == 0 ? null : kinetic / mass, 'J/kg'),
    ToolResult.number('等效高度', mass == 0 ? null : total / (mass * 9.80665), 'm'),
    if (includeTarget) ToolResult.number('目标总能量', targetTotalEnergy, 'J'),
    if (includeTarget)
      ToolResult.number(
          '目标能量所需速度',
          targetSpeed == null || !targetSpeed.isFinite ? null : targetSpeed,
          'm/s'),
    if (includeTarget) ToolResult.number('目标能量所需高度', targetHeight, 'm'),
    if (includeTarget)
      ToolResult.number('目标能量差值', total - targetTotalEnergy, 'J'),
  ];
}

List<ToolResult> _invalidKineticEnergyResults({
  required bool includeTarget,
}) {
  return [
    const ToolResult.invalid('总能量', 'J', primary: true),
    const ToolResult.invalid('动能', 'J'),
    const ToolResult.invalid('势能', 'J'),
    const ToolResult.invalid('速度幅值', 'm/s'),
    const ToolResult.invalid('速度', 'km/h'),
    const ToolResult.invalid('单位质量动能', 'J/kg'),
    const ToolResult.invalid('等效高度', 'm'),
    if (includeTarget) const ToolResult.invalid('目标总能量', 'J'),
    if (includeTarget) const ToolResult.invalid('目标能量所需速度', 'm/s'),
    if (includeTarget) const ToolResult.invalid('目标能量所需高度', 'm'),
    if (includeTarget) const ToolResult.invalid('目标能量差值', 'J'),
  ];
}
