import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

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

List<ToolResult> concentrationResults(Map<String, double> valuesByKey) {
  final massInput = valuesByKey['mass'];
  final volumeInput = valuesByKey['volume'];
  final molarMassInput = valuesByKey['molarMass'];
  final massConcentrationInput = valuesByKey['massConcentration'];
  final molarityInput = valuesByKey['molarity'];
  final validInputs = [
    massInput,
    volumeInput,
    massConcentrationInput,
    molarityInput,
  ].where((value) => value != null).length;
  if (validInputs < 2 ||
      (massInput != null && (massInput < 0 || !massInput.isFinite)) ||
      (volumeInput != null && (volumeInput <= 0 || !volumeInput.isFinite)) ||
      (molarMassInput != null &&
          (molarMassInput <= 0 || !molarMassInput.isFinite)) ||
      (massConcentrationInput != null &&
          (massConcentrationInput < 0 || !massConcentrationInput.isFinite)) ||
      (molarityInput != null &&
          (molarityInput < 0 || !molarityInput.isFinite))) {
    return _invalidConcentrationResults();
  }

  double? mass = massInput;
  double? volume = volumeInput;
  double? molarMass = molarMassInput;
  double? massConcentration = massConcentrationInput;
  double? molarity;
  String source;

  if (mass != null && volume != null) {
    massConcentration = volume == 0 ? null : mass / volume;
    source = _concentrationSource(
      '溶质量+体积',
      hasMassConcentrationReference: massConcentrationInput != null,
      hasMolarityReference: molarityInput != null,
    );
  } else if (mass != null && massConcentration != null) {
    if (massConcentration == 0) return _invalidConcentrationResults();
    volume = mass / massConcentration;
    source = _concentrationSource(
      '溶质量+质量浓度',
      hasMolarityReference: molarityInput != null,
    );
  } else if (volume != null && massConcentration != null) {
    mass = massConcentration * volume;
    source = _concentrationSource(
      '体积+质量浓度',
      hasMolarityReference: molarityInput != null,
    );
  } else if (mass != null && molarityInput != null && molarMass != null) {
    final derivedMassConcentration = molarityInput * molarMass;
    if (derivedMassConcentration == 0) return _invalidConcentrationResults();
    massConcentration = derivedMassConcentration;
    volume = mass / derivedMassConcentration;
    molarity = molarityInput;
    source = '溶质量+摩尔浓度';
  } else if (volume != null && molarityInput != null && molarMass != null) {
    massConcentration = molarityInput * molarMass;
    mass = massConcentration * volume;
    molarity = molarityInput;
    source = '体积+摩尔浓度';
  } else if (massConcentration != null &&
      molarityInput != null &&
      molarityInput > 0) {
    molarity = molarityInput;
    molarMass = massConcentration / molarityInput;
    source = molarMassInput == null ? '质量浓度+摩尔浓度' : '质量浓度+摩尔浓度，摩尔质量作参考';
  } else {
    return _invalidConcentrationResults();
  }

  if (massConcentration == null || !massConcentration.isFinite) {
    return _invalidConcentrationResults();
  }
  if (molarMass != null) {
    molarity = massConcentration / molarMass;
  }
  if (molarMass == null &&
      molarityInput != null &&
      molarityInput > 0 &&
      massConcentration > 0) {
    molarity = molarityInput;
    molarMass = massConcentration / molarityInput;
  }

  final amount = mass != null && molarMass != null ? mass / molarMass : null;
  final massConcentrationDelta = massConcentrationInput == null
      ? null
      : massConcentration - massConcentrationInput;
  final molarityDelta = molarityInput == null || molarity == null
      ? null
      : molarity - molarityInput;
  final molarMassDelta = molarMassInput == null || molarMass == null
      ? null
      : molarMass - molarMassInput;
  return [
    ToolResult('质量浓度', formatNumber(massConcentration), 'g/L', primary: true),
    ToolResult('mg/mL', formatNumber(massConcentration), 'mg/mL'),
    ToolResult('mg/L', formatNumber(massConcentration * 1000), 'mg/L'),
    ToolResult(
        '摩尔浓度', molarity == null ? '无效' : formatNumber(molarity), 'mol/L'),
    ToolResult('溶质物质的量', amount == null ? '无效' : formatNumber(amount), 'mol'),
    ToolResult('溶质量', mass == null ? '无效' : formatNumber(mass), 'g'),
    ToolResult(
        '溶液体积', volume == null ? '无效' : formatNumber(volume * 1000), 'mL'),
    ToolResult('溶液体积 L', volume == null ? '无效' : formatNumber(volume), 'L'),
    ToolResult(
        '摩尔质量', molarMass == null ? '无效' : formatNumber(molarMass), 'g/mol'),
    ToolResult('输入来源', source, ''),
    if (massConcentrationDelta != null)
      ToolResult('质量浓度差值', formatNumber(massConcentrationDelta), 'g/L'),
    if (molarityDelta != null)
      ToolResult('摩尔浓度差值', formatNumber(molarityDelta), 'mol/L'),
    if (molarMassDelta != null)
      ToolResult('摩尔质量差值', formatNumber(molarMassDelta), 'g/mol'),
  ];
}

List<ToolResult> _invalidConcentrationResults() {
  return const [
    ToolResult('质量浓度', '无效', 'g/L', primary: true),
    ToolResult('mg/mL', '无效', 'mg/mL'),
    ToolResult('mg/L', '无效', 'mg/L'),
    ToolResult('摩尔浓度', '无效', 'mol/L'),
    ToolResult('溶质物质的量', '无效', 'mol'),
    ToolResult('溶质量', '无效', 'g'),
    ToolResult('溶液体积', '无效', 'mL'),
    ToolResult('溶液体积 L', '无效', 'L'),
    ToolResult('摩尔质量', '无效', 'g/mol'),
    ToolResult('输入来源', '无效', ''),
  ];
}

String _concentrationSource(
  String source, {
  bool hasMassConcentrationReference = false,
  bool hasMolarityReference = false,
}) {
  final references = [
    if (hasMassConcentrationReference) '质量浓度',
    if (hasMolarityReference) '摩尔浓度',
  ];
  if (references.isEmpty) return source;
  return '$source，${references.join('、')}作参考';
}

List<ToolResult> idealGasResults(Map<String, double> valuesByKey) {
  const gasConstant = 8.314462618;
  final nInput = valuesByKey['n'];
  final tempInput = valuesByKey['temp'];
  final volumeInput = valuesByKey['volume'];
  final pressureInput = valuesByKey['pressure'];
  final validInputs = [
    nInput,
    tempInput,
    volumeInput,
    pressureInput,
  ].where((value) => value != null).length;
  if (validInputs < 3 ||
      (nInput != null && (nInput < 0 || !nInput.isFinite)) ||
      (tempInput != null && (tempInput <= 0 || !tempInput.isFinite)) ||
      (volumeInput != null && (volumeInput <= 0 || !volumeInput.isFinite)) ||
      (pressureInput != null &&
          (pressureInput <= 0 || !pressureInput.isFinite))) {
    return _invalidIdealGasResults();
  }

  double n;
  double temp;
  double volumeL;
  double pressureKpa;
  String source;
  if (nInput != null && tempInput != null && volumeInput != null) {
    n = nInput;
    temp = tempInput;
    volumeL = volumeInput;
    final volumeM3 = volumeL / 1000;
    pressureKpa = n * gasConstant * temp / volumeM3 / 1000;
    source = pressureInput == null ? '物质的量+温度+体积' : '物质的量+温度+体积，压力作参考';
  } else if (pressureInput != null &&
      tempInput != null &&
      volumeInput != null) {
    pressureKpa = pressureInput;
    temp = tempInput;
    volumeL = volumeInput;
    n = pressureKpa * 1000 * (volumeL / 1000) / (gasConstant * temp);
    source = '压力+温度+体积';
  } else if (pressureInput != null && nInput != null && volumeInput != null) {
    pressureKpa = pressureInput;
    n = nInput;
    volumeL = volumeInput;
    if (n == 0) return _invalidIdealGasResults();
    temp = pressureKpa * 1000 * (volumeL / 1000) / (n * gasConstant);
    source = '压力+物质的量+体积';
  } else if (pressureInput != null && nInput != null && tempInput != null) {
    pressureKpa = pressureInput;
    n = nInput;
    temp = tempInput;
    volumeL = n * gasConstant * temp / (pressureKpa * 1000) * 1000;
    source = '压力+物质的量+温度';
  } else {
    return _invalidIdealGasResults();
  }

  final pressureDelta =
      pressureInput == null ? null : pressureKpa - pressureInput;
  return [
    ToolResult('压力', formatNumber(pressureKpa), 'kPa', primary: true),
    ToolResult('压力 atm', formatNumber(pressureKpa * 1000 / 101325), 'atm'),
    ToolResult('压力 Pa', formatNumber(pressureKpa * 1000), 'Pa'),
    ToolResult('体积', formatNumber(volumeL / 1000), 'm³'),
    ToolResult('体积 L', formatNumber(volumeL), 'L'),
    ToolResult('温度', formatNumber(temp - 273.15), '℃'),
    ToolResult('温度 K', formatNumber(temp), 'K'),
    ToolResult('物质的量', formatNumber(n), 'mol'),
    ToolResult('摩尔体积', n == 0 ? '无效' : formatNumber(volumeL / n), 'L/mol'),
    ToolResult('分子数', formatNumber(n * 6.02214076e23), ''),
    ToolResult('输入来源', source, ''),
    if (pressureDelta != null)
      ToolResult('压力差值', formatNumber(pressureDelta), 'kPa'),
  ];
}

List<ToolResult> _invalidIdealGasResults() {
  return const [
    ToolResult('压力', '无效', 'kPa', primary: true),
    ToolResult('压力 atm', '无效', 'atm'),
    ToolResult('压力 Pa', '无效', 'Pa'),
    ToolResult('体积', '无效', 'm³'),
    ToolResult('体积 L', '无效', 'L'),
    ToolResult('温度', '无效', '℃'),
    ToolResult('温度 K', '无效', 'K'),
    ToolResult('物质的量', '无效', 'mol'),
    ToolResult('摩尔体积', '无效', 'L/mol'),
    ToolResult('分子数', '无效', ''),
    ToolResult('输入来源', '无效', ''),
  ];
}

List<ToolResult> heatResults(Map<String, double> valuesByKey) {
  final massInput = valuesByKey['mass'];
  final specificInput = valuesByKey['specific'];
  final deltaInput = valuesByKey['delta'];
  final heatInput = valuesByKey['heat'];
  final validInputs = [
    massInput,
    specificInput,
    deltaInput,
    heatInput,
  ].where((value) => value != null).length;
  if (validInputs < 3 ||
      (massInput != null && (massInput < 0 || !massInput.isFinite)) ||
      (specificInput != null &&
          (specificInput < 0 || !specificInput.isFinite)) ||
      (deltaInput != null && !deltaInput.isFinite) ||
      (heatInput != null && !heatInput.isFinite)) {
    return _invalidHeatResults();
  }

  double mass;
  double specific;
  double delta;
  double heat;
  String source;
  if (massInput != null && specificInput != null && deltaInput != null) {
    mass = massInput;
    specific = specificInput;
    delta = deltaInput;
    heat = mass * specific * delta;
    source = heatInput == null ? '质量+比热容+温度变化' : '质量+比热容+温度变化，热量作参考';
  } else if (heatInput != null && specificInput != null && deltaInput != null) {
    if (specificInput == 0 || deltaInput == 0) return _invalidHeatResults();
    heat = heatInput;
    specific = specificInput;
    delta = deltaInput;
    mass = heat / (specific * delta);
    if (mass < 0) return _invalidHeatResults();
    source = '热量+比热容+温度变化';
  } else if (heatInput != null && massInput != null && deltaInput != null) {
    if (massInput == 0 || deltaInput == 0) return _invalidHeatResults();
    heat = heatInput;
    mass = massInput;
    delta = deltaInput;
    specific = heat / (mass * delta);
    if (specific < 0) return _invalidHeatResults();
    source = '热量+质量+温度变化';
  } else if (heatInput != null && massInput != null && specificInput != null) {
    if (massInput == 0 || specificInput == 0) return _invalidHeatResults();
    heat = heatInput;
    mass = massInput;
    specific = specificInput;
    delta = heat / (mass * specific);
    source = '热量+质量+比热容';
  } else {
    return _invalidHeatResults();
  }

  final heatDelta = heatInput == null ? null : heat - heatInput;
  return [
    ToolResult('热量', formatNumber(heat), 'J', primary: true),
    ToolResult('kJ', formatNumber(heat / 1000), 'kJ'),
    ToolResult('Wh', formatNumber(heat / 3600), 'Wh'),
    ToolResult('kcal', formatNumber(heat / 4184), 'kcal'),
    ToolResult('质量', formatNumber(mass), 'kg'),
    ToolResult('比热容', formatNumber(specific), 'J/kg℃'),
    ToolResult('温度变化', formatNumber(delta), '℃'),
    ToolResult('热过程', heat > 0 ? '吸热' : (heat < 0 ? '放热' : '无热量'), ''),
    ToolResult('输入来源', source, ''),
    if (heatDelta != null) ToolResult('热量差值', formatNumber(heatDelta), 'J'),
  ];
}

List<ToolResult> _invalidHeatResults() {
  return const [
    ToolResult('热量', '无效', 'J', primary: true),
    ToolResult('kJ', '无效', 'kJ'),
    ToolResult('Wh', '无效', 'Wh'),
    ToolResult('kcal', '无效', 'kcal'),
    ToolResult('质量', '无效', 'kg'),
    ToolResult('比热容', '无效', 'J/kg℃'),
    ToolResult('温度变化', '无效', '℃'),
    ToolResult('热过程', '无效', ''),
    ToolResult('输入来源', '无效', ''),
  ];
}

List<ToolResult> wavelengthResults(Map<String, double> valuesByKey) {
  final speedInput = valuesByKey['speed'];
  final frequencyInput = valuesByKey['frequency'];
  final wavelengthInput = valuesByKey['wavelength'];
  final validInputs = [
    speedInput,
    frequencyInput,
    wavelengthInput,
  ].where((value) => value != null).length;
  if (validInputs < 2 ||
      (speedInput != null && (speedInput <= 0 || !speedInput.isFinite)) ||
      (frequencyInput != null &&
          (frequencyInput <= 0 || !frequencyInput.isFinite)) ||
      (wavelengthInput != null &&
          (wavelengthInput <= 0 || !wavelengthInput.isFinite))) {
    return _invalidWavelengthResults();
  }

  double speed;
  double frequency;
  double wavelength;
  String source;
  if (speedInput != null && frequencyInput != null) {
    speed = speedInput;
    frequency = frequencyInput;
    wavelength = speed / frequency;
    source = wavelengthInput == null ? '波速+频率' : '波速+频率，波长作参考';
  } else if (speedInput != null && wavelengthInput != null) {
    speed = speedInput;
    wavelength = wavelengthInput;
    frequency = speed / wavelength;
    source = '波速+波长';
  } else if (frequencyInput != null && wavelengthInput != null) {
    frequency = frequencyInput;
    wavelength = wavelengthInput;
    speed = wavelength * frequency;
    source = '频率+波长';
  } else {
    return _invalidWavelengthResults();
  }

  final wavelengthDelta =
      wavelengthInput == null ? null : wavelength - wavelengthInput;
  return [
    ToolResult('波长', formatNumber(wavelength), 'm', primary: true),
    ToolResult('周期', formatNumber(1 / frequency), 's'),
    ToolResult('频率', formatNumber(frequency), 'Hz'),
    ToolResult('频率 kHz', formatNumber(frequency / 1000), 'kHz'),
    ToolResult('波速', formatNumber(speed), 'm/s'),
    ToolResult('波速 km/h', formatNumber(speed * 3.6), 'km/h'),
    ToolResult('波数', formatNumber(1 / wavelength), '1/m'),
    ToolResult('角频率', formatNumber(2 * math.pi * frequency), 'rad/s'),
    ToolResult('输入来源', source, ''),
    if (wavelengthDelta != null)
      ToolResult('波长差值', formatNumber(wavelengthDelta), 'm'),
  ];
}

List<ToolResult> _invalidWavelengthResults() {
  return const [
    ToolResult('波长', '无效', 'm', primary: true),
    ToolResult('周期', '无效', 's'),
    ToolResult('频率', '无效', 'Hz'),
    ToolResult('频率 kHz', '无效', 'kHz'),
    ToolResult('波速', '无效', 'm/s'),
    ToolResult('波速 km/h', '无效', 'km/h'),
    ToolResult('波数', '无效', '1/m'),
    ToolResult('角频率', '无效', 'rad/s'),
    ToolResult('输入来源', '无效', ''),
  ];
}

List<ToolResult> halfLifeResults(Map<String, double> valuesByKey) {
  final initialInput = valuesByKey['initial'];
  final halfInput = valuesByKey['half'];
  final timeInput = valuesByKey['time'];
  final remainingInput = valuesByKey['remaining'];
  final remainingRatioInput = valuesByKey['remainingRatio'];
  final validInputs = [
    initialInput,
    halfInput,
    timeInput,
    remainingInput,
    remainingRatioInput,
  ].where((value) => value != null).length;
  if (validInputs < 3 ||
      (initialInput != null && (initialInput < 0 || !initialInput.isFinite)) ||
      (halfInput != null && (halfInput <= 0 || !halfInput.isFinite)) ||
      (timeInput != null && (timeInput < 0 || !timeInput.isFinite)) ||
      (remainingInput != null &&
          (remainingInput < 0 ||
              !remainingInput.isFinite ||
              (initialInput != null && remainingInput > initialInput))) ||
      (remainingRatioInput != null &&
          (remainingRatioInput < 0 ||
              remainingRatioInput > 100 ||
              !remainingRatioInput.isFinite))) {
    return _invalidHalfLifeResults();
  }

  double initial;
  double half;
  double time;
  double remaining;
  double remainingRatio;
  String source;
  if (initialInput != null && halfInput != null && timeInput != null) {
    initial = initialInput;
    half = halfInput;
    time = timeInput;
    final periods = time / half;
    remaining = initial * math.pow(0.5, periods).toDouble();
    remainingRatio = initial == 0 ? 0.0 : remaining / initial * 100;
    source = _halfLifeSource(
      '初始量+半衰期+经过时间',
      hasRemainingReference: remainingInput != null,
      hasRatioReference: remainingRatioInput != null,
    );
  } else if (initialInput != null && halfInput != null) {
    initial = initialInput;
    half = halfInput;
    final ratio = _halfLifeRatioFromRemaining(
      initial: initial,
      remaining: remainingInput,
      remainingRatio: remainingRatioInput,
    );
    if (ratio == null || ratio <= 0 || ratio > 1) {
      return _invalidHalfLifeResults();
    }
    remainingRatio = ratio * 100;
    remaining = initial * ratio;
    time = -half * math.log(ratio) / math.ln2;
    source = _halfLifeSource(
      remainingInput != null ? '初始量+半衰期+剩余量' : '初始量+半衰期+剩余比例',
      hasRatioReference: remainingInput != null && remainingRatioInput != null,
    );
  } else if (initialInput != null && timeInput != null) {
    initial = initialInput;
    time = timeInput;
    final ratio = _halfLifeRatioFromRemaining(
      initial: initial,
      remaining: remainingInput,
      remainingRatio: remainingRatioInput,
    );
    if (ratio == null || ratio <= 0 || ratio > 1 || time == 0) {
      return _invalidHalfLifeResults();
    }
    remainingRatio = ratio * 100;
    remaining = initial * ratio;
    half = -time * math.ln2 / math.log(ratio);
    source = _halfLifeSource(
      remainingInput != null ? '初始量+经过时间+剩余量' : '初始量+经过时间+剩余比例',
      hasRatioReference: remainingInput != null && remainingRatioInput != null,
    );
  } else {
    return _invalidHalfLifeResults();
  }

  final periods = time / half;
  final remainingDelta =
      remainingInput == null ? null : remaining - remainingInput;
  final remainingRatioDelta =
      remainingRatioInput == null ? null : remainingRatio - remainingRatioInput;
  return [
    ToolResult('剩余量', formatNumber(remaining), '', primary: true),
    ToolResult('剩余比例', formatNumber(remainingRatio), '%'),
    ToolResult('衰减量', formatNumber(initial - remaining), ''),
    ToolResult('衰减比例', formatNumber(100 - remainingRatio), '%'),
    ToolResult('初始量', formatNumber(initial), ''),
    ToolResult('半衰期', formatNumber(half), 'h'),
    ToolResult('经过时间', formatNumber(time), 'h'),
    ToolResult('经历半衰期', formatNumber(periods), '个'),
    ToolResult('衰变常数', formatNumber(math.ln2 / half), '1/h'),
    ToolResult('输入来源', source, ''),
    if (remainingDelta != null)
      ToolResult('剩余量差值', formatNumber(remainingDelta), ''),
    if (remainingRatioDelta != null)
      ToolResult('剩余比例差值', formatNumber(remainingRatioDelta), '%'),
  ];
}

double? _halfLifeRatioFromRemaining({
  required double initial,
  double? remaining,
  double? remainingRatio,
}) {
  if (remaining != null) {
    if (initial <= 0 || remaining > initial) return null;
    return remaining / initial;
  }
  if (remainingRatio != null) return remainingRatio / 100;
  return null;
}

String _halfLifeSource(
  String source, {
  bool hasRemainingReference = false,
  bool hasRatioReference = false,
}) {
  final references = [
    if (hasRemainingReference) '剩余量',
    if (hasRatioReference) '剩余比例',
  ];
  if (references.isEmpty) return source;
  return '$source，${references.join('、')}作参考';
}

List<ToolResult> _invalidHalfLifeResults() {
  return const [
    ToolResult('剩余量', '无效', '', primary: true),
    ToolResult('剩余比例', '无效', '%'),
    ToolResult('衰减量', '无效', ''),
    ToolResult('衰减比例', '无效', '%'),
    ToolResult('初始量', '无效', ''),
    ToolResult('半衰期', '无效', 'h'),
    ToolResult('经过时间', '无效', 'h'),
    ToolResult('经历半衰期', '无效', '个'),
    ToolResult('衰变常数', '无效', '1/h'),
    ToolResult('输入来源', '无效', ''),
  ];
}

List<ToolResult> phResults(Map<String, double> valuesByKey) {
  const kw = 1e-14;
  final directPh = valuesByKey['ph'];
  final hInput = valuesByKey['h'];
  final ohInput = valuesByKey['oh'];
  final targetPh = valuesByKey['targetPh'];
  final includeTarget = targetPh != null;
  double? ph;
  String source;

  if (targetPh != null && !targetPh.isFinite) {
    return _invalidPhResults(includeTarget: includeTarget);
  }
  if (directPh != null) {
    if (!directPh.isFinite) {
      return _invalidPhResults(includeTarget: includeTarget);
    }
    ph = directPh;
    source = 'pH';
  } else if (hInput != null) {
    if (hInput <= 0 || !hInput.isFinite) {
      return _invalidPhResults(includeTarget: includeTarget);
    }
    ph = -math.log(hInput) / math.ln10;
    source = '[H+]';
  } else if (ohInput != null) {
    if (ohInput <= 0 || !ohInput.isFinite) {
      return _invalidPhResults(includeTarget: includeTarget);
    }
    final poh = -math.log(ohInput) / math.ln10;
    ph = 14 - poh;
    source = '[OH-]';
  } else {
    return _invalidPhResults(includeTarget: includeTarget);
  }

  final poh = 14 - ph;
  final h = math.pow(10, -ph).toDouble();
  final oh = kw / h;
  final hNm = h * 1e9;
  final ohNm = oh * 1e9;
  final targetH = targetPh == null ? null : math.pow(10, -targetPh).toDouble();
  final targetOh = targetH == null ? null : kw / targetH;
  final type = ph < 6.8
      ? '酸性'
      : ph > 7.2
          ? '碱性'
          : '近中性';
  return [
    ToolResult('pH', formatNumber(ph), '', primary: true),
    ToolResult('pOH', formatNumber(poh), ''),
    ToolResult('[H+]', formatNumber(h), 'mol/L'),
    ToolResult('[OH-]', formatNumber(oh), 'mol/L'),
    ToolResult('[H+] nmol/L', formatNumber(hNm), 'nmol/L'),
    ToolResult('[OH-] nmol/L', formatNumber(ohNm), 'nmol/L'),
    ToolResult('酸碱性', type, ''),
    ToolResult('输入来源', source, ''),
    if (includeTarget) ToolResult('目标pH', formatNumber(targetPh), ''),
    if (targetH != null) ToolResult('目标[H+]', formatNumber(targetH), 'mol/L'),
    if (targetOh != null)
      ToolResult('目标[OH-]', formatNumber(targetOh), 'mol/L'),
    if (includeTarget) ToolResult('pH差值', formatNumber(ph - targetPh), ''),
  ];
}

List<ToolResult> _invalidPhResults({required bool includeTarget}) {
  return [
    const ToolResult('pH', '无效', '', primary: true),
    const ToolResult('pOH', '无效', ''),
    const ToolResult('[H+]', '无效', 'mol/L'),
    const ToolResult('[OH-]', '无效', 'mol/L'),
    const ToolResult('酸碱性', '无效', ''),
    if (includeTarget) const ToolResult('目标pH', '无效', ''),
    if (includeTarget) const ToolResult('目标[H+]', '无效', 'mol/L'),
    if (includeTarget) const ToolResult('目标[OH-]', '无效', 'mol/L'),
    if (includeTarget) const ToolResult('pH差值', '无效', ''),
  ];
}
