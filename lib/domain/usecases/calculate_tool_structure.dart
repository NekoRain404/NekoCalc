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
    ToolResult.number('作用力', force, 'N', primary: true),
    ToolResult.number('作用力', force / 1000, 'kN'),
    ToolResult.number('等效重量', force / 9.80665, 'kgf'),
    ToolResult.number('压力', pressureMpa * 10, 'bar'),
    ToolResult.number('面积', areaCm2 * 100, 'mm²'),
    ToolResult.number('面积', area, 'm²'),
    ToolResult.number('单位面积载荷', force / areaCm2, 'N/cm²'),
    if (includeTarget) ToolResult.number('目标作用力', targetForce, 'N'),
    if (includeTarget) ToolResult.number('目标力所需压力', requiredPressure, 'MPa'),
    if (includeTarget) ToolResult.number('目标力所需面积', requiredArea, 'cm²'),
    if (includeTarget) ToolResult.number('作用力差值', force - targetForce, 'N'),
  ];
}

List<ToolResult> _invalidPressureForceResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('作用力', 'N', primary: true),
    const ToolResult.invalid('作用力', 'kN'),
    const ToolResult.invalid('等效重量', 'kgf'),
    const ToolResult.invalid('压力', 'bar'),
    const ToolResult.invalid('面积', 'mm²'),
    const ToolResult.invalid('面积', 'm²'),
    const ToolResult.invalid('单位面积载荷', 'N/cm²'),
    if (includeTarget) const ToolResult.invalid('目标作用力', 'N'),
    if (includeTarget) const ToolResult.invalid('目标力所需压力', 'MPa'),
    if (includeTarget) const ToolResult.invalid('目标力所需面积', 'cm²'),
    if (includeTarget) const ToolResult.invalid('作用力差值', 'N'),
  ];
}

List<ToolResult> frictionResults(Map<String, double> valuesByKey) {
  final normal = valuesByKey['normal'] ?? 0;
  final mu = valuesByKey['mu'] ?? 0;
  if (normal < 0 || mu < 0 || !normal.isFinite || !mu.isFinite) {
    return const [
      ToolResult.invalid('摩擦力', 'N', primary: true),
      ToolResult.invalid('摩擦系数', ''),
      ToolResult.invalid('法向等效重量', 'kgf'),
      ToolResult.invalid('摩擦角', 'deg'),
      ToolResult.invalid('最大可平衡坡角', 'deg'),
      ToolResult.invalid('等效坡度', '%'),
    ];
  }
  final friction = normal * mu;
  final angle = math.atan(mu) * 180 / math.pi;
  return [
    ToolResult.number('摩擦力', friction, 'N', primary: true),
    ToolResult.number('摩擦系数', mu, ''),
    ToolResult.number('法向等效重量', normal / 9.80665, 'kgf'),
    ToolResult.number('摩擦角', angle, 'deg'),
    ToolResult.number('最大可平衡坡角', angle, 'deg'),
    ToolResult.number('等效坡度', mu * 100, '%'),
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
      ToolResult.invalid('沿斜面分力', 'N', primary: true),
      ToolResult.invalid('法向力', 'N'),
      ToolResult.invalid('摩擦力', 'N'),
      ToolResult.invalid('净下滑力', 'N'),
      ToolResult.invalid('重力', 'N'),
      ToolResult.invalid('坡度', '%'),
      ToolResult.invalid('摩擦角', 'deg'),
      ToolResult.invalid('滑动状态', ''),
    ];
  }
  final angle = angleDeg * math.pi / 180;
  final weight = mass * 9.80665;
  final normal = weight * math.cos(angle);
  final parallel = weight * math.sin(angle);
  final friction = mu * normal;
  final netDownhill = parallel.abs() - friction;
  // 中文：**坡度那一格的两支里，只有「无穷大」是一句结论**（它自己那句话从枚举来），
  //       另一支是一个数。`slopeIsInfinite` 判一次、两处用，值与令牌因此不会各自漂。
  // English: **only "无穷大" is a conclusion among the slope cell's two branches** (its sentence comes
  //          from the enum); the other branch is a number. `slopeIsInfinite` is judged once and used
  //          twice, so value and token cannot drift apart.
  final slopeIsInfinite = angleDeg.abs() == 90;
  final slopeGrade = slopeIsInfinite
      ? ToolResultConclusion.infinite.sentence
      : formatNumber(math.tan(angle) * 100);
  final frictionAngle = math.atan(mu) * 180 / math.pi;
  // 中文：**滑动状态是下游判据读的那一格**（`tool_insights_structure.dart` 问「会下滑 / 摩擦可抵住」），
  //       所以那两句结论从枚举取；`'无下滑趋势'` 没有被任何判据读过，是普通字面量。
  // English: **the sliding state is the cell a downstream judgement reads**
  //          (`tool_insights_structure.dart` asks "会下滑 / 摩擦可抵住"), so those two conclusions come
  //          from the enum; `'无下滑趋势'` is read by no judgement and stays an ordinary literal.
  final stateConclusion = parallel == 0
      ? null
      : netDownhill > 0
          ? ToolResultConclusion.slidesDown
          : ToolResultConclusion.frictionHolds;
  final state = stateConclusion?.sentence ?? '无下滑趋势';
  return [
    ToolResult.number('沿斜面分力', parallel, 'N', primary: true),
    ToolResult.number('法向力', normal, 'N'),
    ToolResult.number('摩擦力', friction, 'N'),
    ToolResult.number('净下滑力', netDownhill, 'N'),
    ToolResult.number('重力', weight, 'N'),
    ToolResult('坡度', slopeGrade, '%',
        conclusion: slopeIsInfinite ? ToolResultConclusion.infinite : null),
    ToolResult.number('摩擦角', frictionAngle, 'deg'),
    ToolResult('滑动状态', state, '', conclusion: stateConclusion),
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
    ToolResult.number('最大挠度', deflection * 1000, 'mm', primary: true),
    ToolResult.number('挠度幅值', deflectionAbs * 1000, 'mm'),
    ToolResult.number('最大弯矩', load * length / 4, 'N·m'),
    ToolResult.number('支座反力', load / 2, 'N'),
    ToolResult.number('刚度 F/δ', stiffness, 'N/m'),
    // 中文：`无穷大` 今天不算错误（旧判据的词表里没有它），旗标照旧为假；另一支照旧由
    //       那个商是不是有限数决定。
    // English: `无穷大` is not an error today (it is not in the old predicate's word list) and the
    //          flag stays false; the other branch is decided, as before, by whether the quotient is
    //          finite.
    // 中文：`deflectionAbs == 0` 时屏幕上是 `'无穷大'`——**那不是错误**（旧判据的词表里没有它）；
    //       另一支交给 [ToolResult.number]，值就是那个商。
    // English: when `deflectionAbs == 0` the screen shows `'无穷大'` — **that is not an error** (it is
    //          not in the old predicate's word list); the other branch goes through
    //          [ToolResult.number] and the value is the quotient.
    if (deflectionAbs == 0)
      ToolResult.conclusion('跨度/挠度', ToolResultConclusion.infinite, '')
    else
      ToolResult.number('跨度/挠度', length / deflectionAbs, ''),
    ToolResult.number('弯曲刚度 EI', elastic * inertia, 'N·m²'),
    ToolResult('载荷方向', loadDirection, ''),
    if (includeTarget) ToolResult.number('目标挠度', targetDeflectionMm, 'mm'),
    if (includeTarget) ToolResult.number('目标挠度允许载荷', requiredLoad, 'N'),
    if (includeTarget) ToolResult.number('目标挠度所需惯性矩', requiredInertia, 'cm⁴'),
    if (includeTarget) ToolResult.number('目标挠度所需弹性模量', requiredElastic, 'GPa'),
    if (includeTarget)
      ToolResult.number(
          '挠度差值', deflectionAbs * 1000 - targetDeflectionMm, 'mm'),
  ];
}

List<ToolResult> _invalidBeamBendingResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('最大挠度', 'mm', primary: true),
    const ToolResult.invalid('挠度幅值', 'mm'),
    const ToolResult.invalid('最大弯矩', 'N·m'),
    const ToolResult.invalid('支座反力', 'N'),
    const ToolResult.invalid('刚度 F/δ', 'N/m'),
    const ToolResult.invalid('跨度/挠度', ''),
    const ToolResult.invalid('弯曲刚度 EI', 'N·m²'),
    const ToolResult.invalid('载荷方向', ''),
    if (includeTarget) const ToolResult.invalid('目标挠度', 'mm'),
    if (includeTarget) const ToolResult.invalid('目标挠度允许载荷', 'N'),
    if (includeTarget) const ToolResult.invalid('目标挠度所需惯性矩', 'cm⁴'),
    if (includeTarget) const ToolResult.invalid('目标挠度所需弹性模量', 'GPa'),
    if (includeTarget) const ToolResult.invalid('挠度差值', 'mm'),
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
      ToolResult.invalid('应力', 'MPa', primary: true),
      ToolResult.invalid('应力幅值', 'MPa'),
      ToolResult.invalid('应变', ''),
      ToolResult.invalid('微应变', 'με'),
      ToolResult.invalid('每米变形', 'mm/m'),
      ToolResult.invalid('截面积', 'cm²'),
      ToolResult.invalid('载荷类型', ''),
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
    ToolResult.number('应力', stress / 1e6, 'MPa', primary: true),
    ToolResult.number('应力幅值', stress.abs() / 1e6, 'MPa'),
    ToolResult.number('应变', strain, ''),
    ToolResult.number('微应变', strain * 1000000, 'με'),
    ToolResult.number('每米变形', strain * 1000, 'mm/m'),
    ToolResult.number('截面积', area * 10000, 'cm²'),
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
    ToolResult.number('圆截面积', circleArea, 'mm²', primary: true),
    ToolResult.number('圆惯性矩 I', circleInertia, 'mm⁴'),
    ToolResult.number('圆截面模量 Z', circleModulus, 'mm³'),
    ToolResult.number('圆回转半径', circleRadiusOfGyration, 'mm'),
    ToolResult.number('圆周长', circlePerimeter, 'mm'),
    ToolResult.number('管截面积', tubeArea, 'mm²'),
    ToolResult.number('管惯性矩 I', tubeInertia, 'mm⁴'),
    ToolResult.number('管截面模量 Z', tubeModulus, 'mm³'),
    ToolResult.number('管回转半径', tubeRadiusOfGyration, 'mm'),
    ToolResult.number('管壁厚', tubeWall, 'mm'),
    ToolResult.number('管平均直径', tubeMeanDiameter, 'mm'),
    ToolResult.number('空心率', hollowRatio, '%'),
    ToolResult.number('矩形截面积', rectangleArea, 'mm²'),
    ToolResult.number('矩形 Ix', rectangleIx, 'mm⁴'),
    ToolResult.number('矩形 Iy', rectangleIy, 'mm⁴'),
    ToolResult('矩形 Zx/Zy',
        '${formatNumber(rectangleZx)} / ${formatNumber(rectangleZy)}', 'mm³',
        hasError: !rectangleZx.isFinite || !rectangleZy.isFinite),
    ToolResult('矩形 rx/ry',
        '${formatNumber(rectangleRx)} / ${formatNumber(rectangleRy)}', 'mm',
        hasError: !rectangleRx.isFinite || !rectangleRy.isFinite),
    ToolResult('强轴', strongAxis, ''),
    ToolResult('弱轴', weakAxis, ''),
  ];
}

List<ToolResult> _invalidSectionAreaResults() {
  return const [
    ToolResult.invalid('圆截面积', 'mm²', primary: true),
    ToolResult.invalid('圆惯性矩 I', 'mm⁴'),
    ToolResult.invalid('圆截面模量 Z', 'mm³'),
    ToolResult.invalid('圆回转半径', 'mm'),
    ToolResult.invalid('圆周长', 'mm'),
    ToolResult.invalid('管截面积', 'mm²'),
    ToolResult.invalid('管惯性矩 I', 'mm⁴'),
    ToolResult.invalid('管截面模量 Z', 'mm³'),
    ToolResult.invalid('管回转半径', 'mm'),
    ToolResult.invalid('管壁厚', 'mm'),
    ToolResult.invalid('管平均直径', 'mm'),
    ToolResult.invalid('空心率', '%'),
    ToolResult.invalid('矩形截面积', 'mm²'),
    ToolResult.invalid('矩形 Ix', 'mm⁴'),
    ToolResult.invalid('矩形 Iy', 'mm⁴'),
    ToolResult.invalid('矩形 Zx/Zy', 'mm³'),
    ToolResult.invalid('矩形 rx/ry', 'mm'),
    ToolResult.invalid('强轴', ''),
    ToolResult.invalid('弱轴', ''),
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
  // 中文：**这一格正是下游判据读的那一格**（`tool_insights_structure.dart` 问
  //       `factorText == '无穷大'`）——句子的字从枚举来，令牌跟着值一起写下。
  // English: **this is the cell a downstream judgement reads** (`tool_insights_structure.dart` asks
  //          `factorText == '无穷大'`) — the sentence's characters come from the enum and the token is
  //          written alongside the value.
  final factorText = factor.isInfinite
      ? ToolResultConclusion.infinite.sentence
      : formatNumber(factor);
  final targetResults = <ToolResult>[];
  if (targetFactor != null) {
    final requiredStrength = stressAbs * targetFactor;
    final allowableStress = strength / targetFactor;
    final stressReduction = stressAbs - allowableStress;
    targetResults.addAll([
      ToolResult.number('目标安全系数', targetFactor, ''),
      ToolResult.number('目标系数所需强度', requiredStrength, 'MPa'),
      ToolResult.number('目标系数许用应力', allowableStress, 'MPa'),
      ToolResult.number('需降低应力', stressReduction, 'MPa'),
      if (!factor.isInfinite)
        ToolResult.number('安全系数差值', factor - targetFactor, ''),
    ]);
  }
  return [
    ToolResult('安全系数', factorText, '',
        primary: true,
        conclusion: factor.isInfinite ? ToolResultConclusion.infinite : null),
    ToolResult.number('余量', margin, 'MPa'),
    ToolResult.number('余量比例', margin / strength * 100, '%'),
    ToolResult.number('工作应力幅值', stressAbs, 'MPa'),
    ToolResult.number('许用强度', strength, 'MPa'),
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
    const ToolResult.invalid('安全系数', '', primary: true),
    const ToolResult.invalid('余量', 'MPa'),
    const ToolResult.invalid('余量比例', '%'),
    const ToolResult.invalid('工作应力幅值', 'MPa'),
    const ToolResult.invalid('许用强度', 'MPa'),
    const ToolResult.invalid('判断', ''),
    if (includeTarget) const ToolResult.invalid('目标安全系数', ''),
    if (includeTarget) const ToolResult.invalid('目标系数所需强度', 'MPa'),
    if (includeTarget) const ToolResult.invalid('目标系数许用应力', 'MPa'),
    if (includeTarget) const ToolResult.invalid('需降低应力', 'MPa'),
    if (includeTarget) const ToolResult.invalid('安全系数差值', ''),
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
      ToolResult.invalid('平均流速', 'm/s', primary: true),
      ToolResult.invalid('截面积', 'mm²'),
      ToolResult.invalid('流量', 'm³/h'),
      ToolResult.invalid('流量', 'm³/s'),
      ToolResult.invalid('管内径', 'm'),
      ToolResult.invalid('水力直径', 'mm'),
      ToolResult.invalid('雷诺数(水20℃)', ''),
      ToolResult.invalid('流动状态(水)', ''),
    ];
  }
  final flow = flowLMin / 1000 / 60;
  final diameter = diameterMm / 1000;
  final area = math.pi * diameter * diameter / 4;
  final speed = flow / area;
  final reynoldsWater = speed * diameter / 1.004e-6;
  // 中文：**三支里只有 `'过渡'` 是下游判据读的结论**（`tool_insights_structure.dart` 问
  //       `state == '过渡'`），所以令牌只在这一支上有值；`'层流'` / `'湍流'` 是普通字面量。
  // English: **only `'过渡'` is a conclusion a downstream judgement reads**
  //          (`tool_insights_structure.dart` asks `state == '过渡'`), so the token has a value on that
  //          branch alone; `'层流'` / `'湍流'` stay ordinary literals.
  // 中文：**值与令牌从同一棵判断树上取下来**，所以两支不可能各判各的。这不是洁癖：
  //       第一版把它们写成两个条件（`r < 2300 || r >= 4000 ? null : transition` 配一句
  //       `r < 2300 ? '层流' : '湍流'`），**跨树探针当场抓到差异**——`reynoldsWater` 是 NaN 时
  //       （`diameter=1e-300` 那一组：面积下溢成 0，`0/0` 得 NaN）两句话都判定为假，
  //       于是值仍是 `'湍流'`（没变），令牌却成了 `transition`，下游那句提示凭空多出现两次。
  //       写成一条记录之后，NaN 走第三支、与改动前逐条相同。
  // English: **value and token come off one judgement tree**, so the two branches cannot decide
  //          separately. This is not fastidiousness: the first version wrote them as two conditions
  //          (`r < 2300 || r >= 4000 ? null : transition` beside `r < 2300 ? '层流' : '湍流'`) and **the
  //          cross-tree probe caught the difference on the spot** — with `reynoldsWater` NaN (the
  //          `diameter=1e-300` case: the area underflows to 0 and `0/0` gives NaN) both sentences test
  //          false, so the value stayed `'湍流'` (unmoved) while the token became `transition` and the
  //          hint line downstream appeared twice out of nowhere. Written as one record, NaN takes the
  //          third branch — item for item as before.
  final flowState = reynoldsWater < 2300
      ? (text: '层流', conclusion: null)
      : reynoldsWater < 4000
          ? (
              text: ToolResultConclusion.transition.sentence,
              conclusion: ToolResultConclusion.transition,
            )
          : (text: '湍流', conclusion: null);
  return [
    ToolResult.number('平均流速', speed, 'm/s', primary: true),
    ToolResult.number('截面积', area * 1000000, 'mm²'),
    ToolResult.number('流量', flow * 3600, 'm³/h'),
    ToolResult.number('流量', flow, 'm³/s'),
    ToolResult.number('管内径', diameter, 'm'),
    ToolResult.number('水力直径', diameterMm, 'mm'),
    ToolResult.number('雷诺数(水20℃)', reynoldsWater, ''),
    ToolResult('流动状态(水)', flowState.text, '',
        conclusion: flowState.conclusion),
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
      ToolResult.invalid('重量', 'kg', primary: true),
      ToolResult.invalid('体积', 'cm³'),
      ToolResult.invalid('重量', 'lb'),
      ToolResult.invalid('重量', 'N'),
      ToolResult.invalid('体积', 'L'),
      ToolResult.invalid('体积', 'm³'),
      ToolResult.invalid('表面积', 'm²'),
      ToolResult.invalid('面密度', 'kg/m²'),
    ];
  }
  final volumeCm3 = length * width * thickness / 1000;
  final massKg = volumeCm3 * density / 1000;
  final volumeM3 = volumeCm3 / 1000000;
  final surfaceAreaM2 =
      2 * (length * width + length * thickness + width * thickness) / 1000000;
  final faceAreaM2 = length * width / 1000000;
  return [
    ToolResult.number('重量', massKg, 'kg', primary: true),
    ToolResult.number('体积', volumeCm3, 'cm³'),
    ToolResult.number('重量', massKg * 2.20462, 'lb'),
    ToolResult.number('重量', massKg * 9.80665, 'N'),
    ToolResult.number('体积', volumeCm3 / 1000, 'L'),
    ToolResult.number('体积', volumeM3, 'm³'),
    ToolResult.number('表面积', surfaceAreaM2, 'm²'),
    ToolResult.number('面密度', massKg / faceAreaM2, 'kg/m²'),
  ];
}
