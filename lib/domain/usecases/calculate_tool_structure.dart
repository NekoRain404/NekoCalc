import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> pressureForceResults(Map<String, double> valuesByKey) {
  final pressureMpa = valuesByKey['pressure'] ?? 0;
  final areaCm2 = valuesByKey['area'] ?? 0;
  final targetForce = valuesByKey['targetForce'];
  final includeTarget = targetForce != null;
  if (pressureMpa < 0 ||
      areaCm2 <= 0 ||
      !pressureMpa.isFinite ||
      !areaCm2.isFinite ||
      (targetForce != null && (targetForce < 0 || !targetForce.isFinite))) {
    return _invalidPressureForceResults(includeTarget: includeTarget);
  }
  final pressure = pressureMpa * 1e6;
  final area = areaCm2 * 1e-4;
  final force = pressure * area;
  final requiredPressure =
      targetForce == null || areaCm2 == 0 ? null : targetForce / areaCm2 / 100;
  final requiredArea = targetForce == null || pressureMpa == 0
      ? null
      : targetForce / pressureMpa / 100;
  return [
    ToolResult('作用力', formatNumber(force), 'N', primary: true),
    ToolResult('作用力', formatNumber(force / 1000), 'kN'),
    ToolResult('等效重量', formatNumber(force / 9.80665), 'kgf'),
    ToolResult('压力', formatNumber(pressureMpa * 10), 'bar'),
    ToolResult('面积', formatNumber(areaCm2 * 100), 'mm²'),
    ToolResult('面积', formatNumber(area), 'm²'),
    ToolResult('单位面积载荷', formatNumber(force / areaCm2), 'N/cm²'),
    if (includeTarget) ToolResult('目标作用力', formatNumber(targetForce), 'N'),
    if (includeTarget)
      ToolResult(
          '目标力所需压力',
          requiredPressure == null ? '无效' : formatNumber(requiredPressure),
          'MPa'),
    if (includeTarget)
      ToolResult('目标力所需面积',
          requiredArea == null ? '无效' : formatNumber(requiredArea), 'cm²'),
    if (includeTarget)
      ToolResult('作用力差值', formatNumber(force - targetForce), 'N'),
  ];
}

List<ToolResult> _invalidPressureForceResults({required bool includeTarget}) {
  return [
    const ToolResult('作用力', '无效', 'N', primary: true),
    const ToolResult('作用力', '无效', 'kN'),
    const ToolResult('等效重量', '无效', 'kgf'),
    const ToolResult('压力', '无效', 'bar'),
    const ToolResult('面积', '无效', 'mm²'),
    const ToolResult('面积', '无效', 'm²'),
    const ToolResult('单位面积载荷', '无效', 'N/cm²'),
    if (includeTarget) const ToolResult('目标作用力', '无效', 'N'),
    if (includeTarget) const ToolResult('目标力所需压力', '无效', 'MPa'),
    if (includeTarget) const ToolResult('目标力所需面积', '无效', 'cm²'),
    if (includeTarget) const ToolResult('作用力差值', '无效', 'N'),
  ];
}

List<ToolResult> frictionResults(Map<String, double> valuesByKey) {
  final normal = valuesByKey['normal'] ?? 0;
  final mu = valuesByKey['mu'] ?? 0;
  if (normal < 0 || mu < 0 || !normal.isFinite || !mu.isFinite) {
    return const [
      ToolResult('摩擦力', '无效', 'N', primary: true),
      ToolResult('摩擦系数', '无效', ''),
      ToolResult('法向等效重量', '无效', 'kgf'),
      ToolResult('摩擦角', '无效', 'deg'),
      ToolResult('最大可平衡坡角', '无效', 'deg'),
      ToolResult('等效坡度', '无效', '%'),
    ];
  }
  final friction = normal * mu;
  final angle = math.atan(mu) * 180 / math.pi;
  return [
    ToolResult('摩擦力', formatNumber(friction), 'N', primary: true),
    ToolResult('摩擦系数', formatNumber(mu), ''),
    ToolResult('法向等效重量', formatNumber(normal / 9.80665), 'kgf'),
    ToolResult('摩擦角', formatNumber(angle), 'deg'),
    ToolResult('最大可平衡坡角', formatNumber(angle), 'deg'),
    ToolResult('等效坡度', formatNumber(mu * 100), '%'),
  ];
}

List<ToolResult> inclinedPlaneResults(Map<String, double> valuesByKey) {
  final mass = valuesByKey['mass'] ?? 0;
  final angleDeg = valuesByKey['angle'] ?? 0;
  final mu = valuesByKey['mu'] ?? 0;
  if (mass < 0 ||
      mu < 0 ||
      angleDeg.abs() > 90 ||
      !mass.isFinite ||
      !angleDeg.isFinite ||
      !mu.isFinite) {
    return const [
      ToolResult('沿斜面分力', '无效', 'N', primary: true),
      ToolResult('法向力', '无效', 'N'),
      ToolResult('摩擦力', '无效', 'N'),
      ToolResult('净下滑力', '无效', 'N'),
      ToolResult('重力', '无效', 'N'),
      ToolResult('坡度', '无效', '%'),
      ToolResult('摩擦角', '无效', 'deg'),
      ToolResult('滑动状态', '无效', ''),
    ];
  }
  final angle = angleDeg * math.pi / 180;
  final weight = mass * 9.80665;
  final normal = weight * math.cos(angle);
  final parallel = weight * math.sin(angle);
  final friction = mu * normal;
  final netDownhill = parallel.abs() - friction;
  final slopeGrade =
      angleDeg.abs() == 90 ? '无穷大' : formatNumber(math.tan(angle) * 100);
  final frictionAngle = math.atan(mu) * 180 / math.pi;
  final state = parallel == 0
      ? '无下滑趋势'
      : netDownhill > 0
          ? '会下滑'
          : '摩擦可抵住';
  return [
    ToolResult('沿斜面分力', formatNumber(parallel), 'N', primary: true),
    ToolResult('法向力', formatNumber(normal), 'N'),
    ToolResult('摩擦力', formatNumber(friction), 'N'),
    ToolResult('净下滑力', formatNumber(netDownhill), 'N'),
    ToolResult('重力', formatNumber(weight), 'N'),
    ToolResult('坡度', slopeGrade, '%'),
    ToolResult('摩擦角', formatNumber(frictionAngle), 'deg'),
    ToolResult('滑动状态', state, ''),
  ];
}

List<ToolResult> beamBendingResults(Map<String, double> valuesByKey) {
  final load = valuesByKey['load'] ?? 0;
  final length = valuesByKey['length'] ?? 0;
  final elastic = (valuesByKey['elastic'] ?? 0) * 1e9;
  final inertia = (valuesByKey['inertia'] ?? 0) * 1e-8;
  final targetDeflectionMm = valuesByKey['targetDeflection'];
  final includeTarget = targetDeflectionMm != null;
  if (length <= 0 ||
      elastic <= 0 ||
      inertia <= 0 ||
      !load.isFinite ||
      !length.isFinite ||
      !elastic.isFinite ||
      !inertia.isFinite ||
      (targetDeflectionMm != null &&
          (targetDeflectionMm <= 0 || !targetDeflectionMm.isFinite))) {
    return _invalidBeamBendingResults(includeTarget: includeTarget);
  }
  final deflection = load * math.pow(length, 3) / (48 * elastic * inertia);
  final stiffness = 48 * elastic * inertia / math.pow(length, 3);
  final deflectionAbs = deflection.abs();
  final targetDeflection =
      targetDeflectionMm == null ? null : targetDeflectionMm / 1000;
  final requiredLoad = targetDeflection == null
      ? null
      : targetDeflection * 48 * elastic * inertia / math.pow(length, 3);
  final requiredInertia = targetDeflection == null || load.abs() == 0
      ? null
      : load.abs() *
          math.pow(length, 3) /
          (48 * elastic * targetDeflection) /
          1e-8;
  final requiredElastic = targetDeflection == null || load.abs() == 0
      ? null
      : load.abs() *
          math.pow(length, 3) /
          (48 * inertia * targetDeflection) /
          1e9;
  final loadDirection = load == 0
      ? '无载荷'
      : load > 0
          ? '向下'
          : '向上/反向';
  return [
    ToolResult('最大挠度', formatNumber(deflection * 1000), 'mm', primary: true),
    ToolResult('挠度幅值', formatNumber(deflectionAbs * 1000), 'mm'),
    ToolResult('最大弯矩', formatNumber(load * length / 4), 'N·m'),
    ToolResult('支座反力', formatNumber(load / 2), 'N'),
    ToolResult('刚度 F/δ', formatNumber(stiffness), 'N/m'),
    ToolResult('跨度/挠度',
        deflectionAbs == 0 ? '无穷大' : formatNumber(length / deflectionAbs), ''),
    ToolResult('弯曲刚度 EI', formatNumber(elastic * inertia), 'N·m²'),
    ToolResult('载荷方向', loadDirection, ''),
    if (includeTarget)
      ToolResult('目标挠度', formatNumber(targetDeflectionMm), 'mm'),
    if (includeTarget)
      ToolResult('目标挠度允许载荷',
          requiredLoad == null ? '无效' : formatNumber(requiredLoad), 'N'),
    if (includeTarget)
      ToolResult(
          '目标挠度所需惯性矩',
          requiredInertia == null ? '无效' : formatNumber(requiredInertia),
          'cm⁴'),
    if (includeTarget)
      ToolResult(
          '目标挠度所需弹性模量',
          requiredElastic == null ? '无效' : formatNumber(requiredElastic),
          'GPa'),
    if (includeTarget)
      ToolResult('挠度差值',
          formatNumber(deflectionAbs * 1000 - targetDeflectionMm), 'mm'),
  ];
}

List<ToolResult> _invalidBeamBendingResults({required bool includeTarget}) {
  return [
    const ToolResult('最大挠度', '无效', 'mm', primary: true),
    const ToolResult('挠度幅值', '无效', 'mm'),
    const ToolResult('最大弯矩', '无效', 'N·m'),
    const ToolResult('支座反力', '无效', 'N'),
    const ToolResult('刚度 F/δ', '无效', 'N/m'),
    const ToolResult('跨度/挠度', '无效', ''),
    const ToolResult('弯曲刚度 EI', '无效', 'N·m²'),
    const ToolResult('载荷方向', '无效', ''),
    if (includeTarget) const ToolResult('目标挠度', '无效', 'mm'),
    if (includeTarget) const ToolResult('目标挠度允许载荷', '无效', 'N'),
    if (includeTarget) const ToolResult('目标挠度所需惯性矩', '无效', 'cm⁴'),
    if (includeTarget) const ToolResult('目标挠度所需弹性模量', '无效', 'GPa'),
    if (includeTarget) const ToolResult('挠度差值', '无效', 'mm'),
  ];
}

List<ToolResult> stressStrainResults(Map<String, double> valuesByKey) {
  final force = valuesByKey['force'] ?? 0;
  final area = (valuesByKey['area'] ?? 0) * 1e-6;
  final elastic = (valuesByKey['elastic'] ?? 0) * 1e9;
  if (area <= 0 ||
      elastic <= 0 ||
      !force.isFinite ||
      !area.isFinite ||
      !elastic.isFinite) {
    return const [
      ToolResult('应力', '无效', 'MPa', primary: true),
      ToolResult('应力幅值', '无效', 'MPa'),
      ToolResult('应变', '无效', ''),
      ToolResult('微应变', '无效', 'με'),
      ToolResult('每米变形', '无效', 'mm/m'),
      ToolResult('截面积', '无效', 'cm²'),
      ToolResult('载荷类型', '无效', ''),
    ];
  }
  final stress = force / area;
  final strain = stress / elastic;
  final loadType = force == 0
      ? '无载荷'
      : force > 0
          ? '拉伸'
          : '压缩';
  return [
    ToolResult('应力', formatNumber(stress / 1e6), 'MPa', primary: true),
    ToolResult('应力幅值', formatNumber(stress.abs() / 1e6), 'MPa'),
    ToolResult('应变', formatNumber(strain), ''),
    ToolResult('微应变', formatNumber(strain * 1000000), 'με'),
    ToolResult('每米变形', formatNumber(strain * 1000), 'mm/m'),
    ToolResult('截面积', formatNumber(area * 10000), 'cm²'),
    ToolResult('载荷类型', loadType, ''),
  ];
}

List<ToolResult> sectionAreaResults(Map<String, double> valuesByKey) {
  final diameter = valuesByKey['diameter'] ?? 0;
  final outer = valuesByKey['outer'] ?? 0;
  final inner = valuesByKey['inner'] ?? 0;
  final width = valuesByKey['width'] ?? 0;
  final height = valuesByKey['height'] ?? 0;
  if (diameter <= 0 ||
      outer <= 0 ||
      inner < 0 ||
      inner >= outer ||
      width <= 0 ||
      height <= 0 ||
      [diameter, outer, inner, width, height].any((value) => !value.isFinite)) {
    return _invalidSectionAreaResults();
  }

  final circleArea = math.pi * diameter * diameter / 4;
  final circleRadius = diameter / 2;
  final circlePerimeter = math.pi * diameter;
  final circleInertia = math.pi * math.pow(diameter, 4) / 64;
  final circleModulus = circleInertia / circleRadius;
  final circleRadiusOfGyration = math.sqrt(circleInertia / circleArea);

  final tubeArea = math.pi * (outer * outer - inner * inner) / 4;
  final tubeWall = (outer - inner) / 2;
  final tubeMeanDiameter = (outer + inner) / 2;
  final tubeInertia = math.pi * (math.pow(outer, 4) - math.pow(inner, 4)) / 64;
  final tubeModulus = tubeInertia / (outer / 2);
  final tubeRadiusOfGyration = math.sqrt(tubeInertia / tubeArea);
  final hollowRatio = inner * inner / (outer * outer) * 100;

  final rectangleArea = width * height;
  final rectangleIx = width * math.pow(height, 3) / 12;
  final rectangleIy = height * math.pow(width, 3) / 12;
  final rectangleZx = rectangleIx / (height / 2);
  final rectangleZy = rectangleIy / (width / 2);
  final rectangleRx = math.sqrt(rectangleIx / rectangleArea);
  final rectangleRy = math.sqrt(rectangleIy / rectangleArea);
  final strongAxis = rectangleIx >= rectangleIy ? 'x轴' : 'y轴';
  final weakAxis = rectangleIx >= rectangleIy ? 'y轴' : 'x轴';

  return [
    ToolResult('圆截面积', formatNumber(circleArea), 'mm²', primary: true),
    ToolResult('圆惯性矩 I', formatNumber(circleInertia), 'mm⁴'),
    ToolResult('圆截面模量 Z', formatNumber(circleModulus), 'mm³'),
    ToolResult('圆回转半径', formatNumber(circleRadiusOfGyration), 'mm'),
    ToolResult('圆周长', formatNumber(circlePerimeter), 'mm'),
    ToolResult('管截面积', formatNumber(tubeArea), 'mm²'),
    ToolResult('管惯性矩 I', formatNumber(tubeInertia), 'mm⁴'),
    ToolResult('管截面模量 Z', formatNumber(tubeModulus), 'mm³'),
    ToolResult('管回转半径', formatNumber(tubeRadiusOfGyration), 'mm'),
    ToolResult('管壁厚', formatNumber(tubeWall), 'mm'),
    ToolResult('管平均直径', formatNumber(tubeMeanDiameter), 'mm'),
    ToolResult('空心率', formatNumber(hollowRatio), '%'),
    ToolResult('矩形截面积', formatNumber(rectangleArea), 'mm²'),
    ToolResult('矩形 Ix', formatNumber(rectangleIx), 'mm⁴'),
    ToolResult('矩形 Iy', formatNumber(rectangleIy), 'mm⁴'),
    ToolResult('矩形 Zx/Zy',
        '${formatNumber(rectangleZx)} / ${formatNumber(rectangleZy)}', 'mm³'),
    ToolResult('矩形 rx/ry',
        '${formatNumber(rectangleRx)} / ${formatNumber(rectangleRy)}', 'mm'),
    ToolResult('强轴', strongAxis, ''),
    ToolResult('弱轴', weakAxis, ''),
  ];
}

List<ToolResult> _invalidSectionAreaResults() {
  return const [
    ToolResult('圆截面积', '无效', 'mm²', primary: true),
    ToolResult('圆惯性矩 I', '无效', 'mm⁴'),
    ToolResult('圆截面模量 Z', '无效', 'mm³'),
    ToolResult('圆回转半径', '无效', 'mm'),
    ToolResult('圆周长', '无效', 'mm'),
    ToolResult('管截面积', '无效', 'mm²'),
    ToolResult('管惯性矩 I', '无效', 'mm⁴'),
    ToolResult('管截面模量 Z', '无效', 'mm³'),
    ToolResult('管回转半径', '无效', 'mm'),
    ToolResult('管壁厚', '无效', 'mm'),
    ToolResult('管平均直径', '无效', 'mm'),
    ToolResult('空心率', '无效', '%'),
    ToolResult('矩形截面积', '无效', 'mm²'),
    ToolResult('矩形 Ix', '无效', 'mm⁴'),
    ToolResult('矩形 Iy', '无效', 'mm⁴'),
    ToolResult('矩形 Zx/Zy', '无效', 'mm³'),
    ToolResult('矩形 rx/ry', '无效', 'mm'),
    ToolResult('强轴', '无效', ''),
    ToolResult('弱轴', '无效', ''),
  ];
}

List<ToolResult> safetyFactorResults(Map<String, double> valuesByKey) {
  final strength = valuesByKey['strength'] ?? 0;
  final stress = valuesByKey['stress'] ?? 0;
  final targetFactor = valuesByKey['targetFactor'];
  final includeTarget = targetFactor != null;
  if (strength <= 0 ||
      !strength.isFinite ||
      !stress.isFinite ||
      (targetFactor != null && (targetFactor <= 0 || !targetFactor.isFinite))) {
    return _invalidSafetyFactorResults(includeTarget: includeTarget);
  }
  final stressAbs = stress.abs();
  final factor = stressAbs == 0 ? double.infinity : strength / stressAbs;
  final margin = strength - stressAbs;
  final factorText = factor.isInfinite ? '无穷大' : formatNumber(factor);
  final targetResults = <ToolResult>[];
  if (targetFactor != null) {
    final requiredStrength = stressAbs * targetFactor;
    final allowableStress = strength / targetFactor;
    final stressReduction = stressAbs - allowableStress;
    targetResults.addAll([
      ToolResult('目标安全系数', formatNumber(targetFactor), ''),
      ToolResult('目标系数所需强度', formatNumber(requiredStrength), 'MPa'),
      ToolResult('目标系数许用应力', formatNumber(allowableStress), 'MPa'),
      ToolResult('需降低应力', formatNumber(stressReduction), 'MPa'),
      if (!factor.isInfinite)
        ToolResult('安全系数差值', formatNumber(factor - targetFactor), ''),
    ]);
  }
  return [
    ToolResult('安全系数', factorText, '', primary: true),
    ToolResult('余量', formatNumber(margin), 'MPa'),
    ToolResult('余量比例', formatNumber(margin / strength * 100), '%'),
    ToolResult('工作应力幅值', formatNumber(stressAbs), 'MPa'),
    ToolResult('许用强度', formatNumber(strength), 'MPa'),
    ToolResult(
        '判断',
        stressAbs == 0
            ? '无载荷'
            : factor >= 2
                ? '较安全'
                : factor >= 1
                    ? '临界'
                    : '失效风险',
        ''),
    ...targetResults,
  ];
}

List<ToolResult> _invalidSafetyFactorResults({required bool includeTarget}) {
  return [
    const ToolResult('安全系数', '无效', '', primary: true),
    const ToolResult('余量', '无效', 'MPa'),
    const ToolResult('余量比例', '无效', '%'),
    const ToolResult('工作应力幅值', '无效', 'MPa'),
    const ToolResult('许用强度', '无效', 'MPa'),
    const ToolResult('判断', '无效', ''),
    if (includeTarget) const ToolResult('目标安全系数', '无效', ''),
    if (includeTarget) const ToolResult('目标系数所需强度', '无效', 'MPa'),
    if (includeTarget) const ToolResult('目标系数许用应力', '无效', 'MPa'),
    if (includeTarget) const ToolResult('需降低应力', '无效', 'MPa'),
    if (includeTarget) const ToolResult('安全系数差值', '无效', ''),
  ];
}

List<ToolResult> flowVelocityResults(Map<String, double> valuesByKey) {
  final flowLMin = valuesByKey['flow'] ?? 0;
  final diameterMm = valuesByKey['diameter'] ?? 0;
  if (flowLMin < 0 ||
      diameterMm <= 0 ||
      !flowLMin.isFinite ||
      !diameterMm.isFinite) {
    return const [
      ToolResult('平均流速', '无效', 'm/s', primary: true),
      ToolResult('截面积', '无效', 'mm²'),
      ToolResult('流量', '无效', 'm³/h'),
      ToolResult('流量', '无效', 'm³/s'),
      ToolResult('管内径', '无效', 'm'),
      ToolResult('水力直径', '无效', 'mm'),
      ToolResult('雷诺数(水20℃)', '无效', ''),
      ToolResult('流动状态(水)', '无效', ''),
    ];
  }
  final flow = flowLMin / 1000 / 60;
  final diameter = diameterMm / 1000;
  final area = math.pi * diameter * diameter / 4;
  final speed = flow / area;
  final reynoldsWater = speed * diameter / 1.004e-6;
  final flowState = reynoldsWater < 2300
      ? '层流'
      : reynoldsWater < 4000
          ? '过渡'
          : '湍流';
  return [
    ToolResult('平均流速', formatNumber(speed), 'm/s', primary: true),
    ToolResult('截面积', formatNumber(area * 1000000), 'mm²'),
    ToolResult('流量', formatNumber(flow * 3600), 'm³/h'),
    ToolResult('流量', formatNumber(flow), 'm³/s'),
    ToolResult('管内径', formatNumber(diameter), 'm'),
    ToolResult('水力直径', formatNumber(diameterMm), 'mm'),
    ToolResult('雷诺数(水20℃)', formatNumber(reynoldsWater), ''),
    ToolResult('流动状态(水)', flowState, ''),
  ];
}

List<ToolResult> materialWeightResults(Map<String, double> valuesByKey) {
  final length = valuesByKey['length'] ?? 0;
  final width = valuesByKey['width'] ?? 0;
  final thickness = valuesByKey['thickness'] ?? 0;
  final density = valuesByKey['density'] ?? 0;
  if (length <= 0 ||
      width <= 0 ||
      thickness <= 0 ||
      density <= 0 ||
      !length.isFinite ||
      !width.isFinite ||
      !thickness.isFinite ||
      !density.isFinite) {
    return const [
      ToolResult('重量', '无效', 'kg', primary: true),
      ToolResult('体积', '无效', 'cm³'),
      ToolResult('重量', '无效', 'lb'),
      ToolResult('重量', '无效', 'N'),
      ToolResult('体积', '无效', 'L'),
      ToolResult('体积', '无效', 'm³'),
      ToolResult('表面积', '无效', 'm²'),
      ToolResult('面密度', '无效', 'kg/m²'),
    ];
  }
  final volumeCm3 = length * width * thickness / 1000;
  final massKg = volumeCm3 * density / 1000;
  final volumeM3 = volumeCm3 / 1000000;
  final surfaceAreaM2 =
      2 * (length * width + length * thickness + width * thickness) / 1000000;
  final faceAreaM2 = length * width / 1000000;
  return [
    ToolResult('重量', formatNumber(massKg), 'kg', primary: true),
    ToolResult('体积', formatNumber(volumeCm3), 'cm³'),
    ToolResult('重量', formatNumber(massKg * 2.20462), 'lb'),
    ToolResult('重量', formatNumber(massKg * 9.80665), 'N'),
    ToolResult('体积', formatNumber(volumeCm3 / 1000), 'L'),
    ToolResult('体积', formatNumber(volumeM3), 'm³'),
    ToolResult('表面积', formatNumber(surfaceAreaM2), 'm²'),
    ToolResult('面密度', formatNumber(massKg / faceAreaM2), 'kg/m²'),
  ];
}
