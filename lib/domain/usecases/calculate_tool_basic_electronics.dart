import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> ohmsLawResults(Map<String, double> valuesByKey) {
  final voltageInput = valuesByKey['voltage'];
  final currentInput = valuesByKey['current'];
  final resistanceInput = valuesByKey['resistance'];
  final powerInput = valuesByKey['power'];
  final tolerance = ((valuesByKey['tol'] ?? 0).abs()) / 100;
  final solved = _solveOhmsLaw(
    voltage: voltageInput,
    current: currentInput,
    resistance: resistanceInput,
    power: powerInput,
  );
  if (solved == null) return _invalidOhmsLawResults();

  final minResistance = solved.resistance * (1 - tolerance);
  final maxResistance = solved.resistance * (1 + tolerance);
  final minPower = solved.current * solved.current * minResistance;
  final maxPower = solved.current * solved.current * maxResistance;
  return [
    ToolResult.number('电压 V', solved.voltage, 'V', primary: true),
    ToolResult.number('电压幅值', solved.voltage.abs(), 'V'),
    ToolResult.number('功率 P', solved.power, 'W'),
    ToolResult.number('电流', solved.current * 1000, 'mA'),
    ToolResult.number('电阻', solved.resistance / 1000, 'kΩ'),
    ToolResult.number('电导', 1000 / solved.resistance, 'mS'),
    _powerRatingResult('推荐功率', solved.power, ''),
    _rangeResult('电压范围', solved.current * minResistance,
        solved.current * maxResistance, 'V'),
    _rangeResult('功率范围', minPower, maxPower, 'W'),
    ToolResult('输入来源', solved.source, ''),
  ];
}

List<ToolResult> _invalidOhmsLawResults() {
  return const [
    ToolResult.invalid('电压 V', 'V', primary: true),
    ToolResult.invalid('电压幅值', 'V'),
    ToolResult.invalid('功率 P', 'W'),
    ToolResult.invalid('电流', 'mA'),
    ToolResult.invalid('电阻', 'kΩ'),
    ToolResult.invalid('电导', 'mS'),
    ToolResult.invalid('推荐功率', ''),
    ToolResult.invalid('电压范围', 'V'),
    ToolResult.invalid('功率范围', 'W'),
    ToolResult.invalid('输入来源', ''),
  ];
}

_OhmsLawSolution? _solveOhmsLaw({
  required double? voltage,
  required double? current,
  required double? resistance,
  required double? power,
}) {
  final invalid = [
    voltage,
    current,
    resistance,
    power,
  ].where((value) => value != null && !value.isFinite);
  if (invalid.isNotEmpty) return null;
  final inputs = [
    voltage,
    current,
    resistance,
    power,
  ].where((value) => value != null).length;
  if (inputs < 2) return null;

  if (voltage != null && current != null) {
    if (current == 0) return null;
    final resistanceValue = voltage / current;
    if (resistanceValue <= 0) return null;
    return _OhmsLawSolution(
      voltage: voltage,
      current: current,
      resistance: resistanceValue,
      power: (voltage * current).abs(),
      source: _referenceSource('电压+电流', [
        if (resistance != null) '电阻',
        if (power != null) '功率',
      ]),
    );
  }
  if (voltage != null && resistance != null) {
    if (resistance <= 0) return null;
    final currentValue = voltage / resistance;
    return _OhmsLawSolution(
      voltage: voltage,
      current: currentValue,
      resistance: resistance,
      power: voltage * currentValue,
      source: _referenceSource('电压+电阻', [
        if (current != null) '电流',
        if (power != null) '功率',
      ]),
    );
  }
  if (current != null && resistance != null) {
    if (resistance <= 0) return null;
    final voltageValue = current * resistance;
    return _OhmsLawSolution(
      voltage: voltageValue,
      current: current,
      resistance: resistance,
      power: current * current * resistance,
      source: _referenceSource('电流+电阻', [
        if (voltage != null) '电压',
        if (power != null) '功率',
      ]),
    );
  }
  if (power != null && resistance != null) {
    if (power < 0 || resistance <= 0) return null;
    final currentMagnitude = math.sqrt(power / resistance);
    final currentSign = voltage != null && voltage < 0 ? -1 : 1;
    final currentValue = currentMagnitude * currentSign;
    return _OhmsLawSolution(
      voltage: currentValue * resistance,
      current: currentValue,
      resistance: resistance,
      power: power,
      source: _referenceSource('功率+电阻', [
        if (voltage != null) '电压方向',
        if (current != null) '电流',
      ]),
    );
  }
  if (power != null && current != null) {
    if (power < 0 || current == 0) return null;
    final voltageValue = power / current;
    final resistanceValue = voltageValue / current;
    if (resistanceValue <= 0) return null;
    return _OhmsLawSolution(
      voltage: voltageValue,
      current: current,
      resistance: resistanceValue,
      power: power,
      source: _referenceSource('功率+电流', [
        if (voltage != null) '电压',
        if (resistance != null) '电阻',
      ]),
    );
  }
  if (power != null && voltage != null) {
    if (power < 0 || voltage == 0) return null;
    final currentValue = power / voltage;
    final resistanceValue = voltage / currentValue;
    if (resistanceValue <= 0) return null;
    return _OhmsLawSolution(
      voltage: voltage,
      current: currentValue,
      resistance: resistanceValue,
      power: power,
      source: _referenceSource('功率+电压', [
        if (current != null) '电流',
        if (resistance != null) '电阻',
      ]),
    );
  }
  return null;
}

String _referenceSource(String source, List<String> references) {
  if (references.isEmpty) return source;
  return '$source，${references.join('、')}作参考';
}

class _OhmsLawSolution {
  const _OhmsLawSolution({
    required this.voltage,
    required this.current,
    required this.resistance,
    required this.power,
    required this.source,
  });

  final double voltage;
  final double current;
  final double resistance;
  final double power;
  final String source;
}

List<ToolResult> ledResistorResults(Map<String, double> valuesByKey) {
  final vin = valuesByKey['vin'] ?? 0;
  final vf = valuesByKey['vf'] ?? 0;
  final currentMa = valuesByKey['current'] ?? 0;
  final vfTolerance = (valuesByKey['vfTol'] ?? 0).abs();
  final selectedResistance = valuesByKey['selectedResistance'];
  final includeSelected = selectedResistance != null;
  final current = currentMa / 1000;
  final availableVoltage = vin - vf;
  final minAvailableVoltage = availableVoltage - vfTolerance;
  final maxAvailableVoltage = availableVoltage + vfTolerance;
  if (current <= 0 ||
      availableVoltage <= 0 ||
      !vin.isFinite ||
      !vf.isFinite ||
      !currentMa.isFinite ||
      !vfTolerance.isFinite ||
      (selectedResistance != null &&
          (selectedResistance <= 0 || !selectedResistance.isFinite))) {
    return _invalidLedResistorResults(
      availableVoltage: availableVoltage,
      minAvailableVoltage: minAvailableVoltage,
      includeSelected: includeSelected,
    );
  }

  final resistance = availableVoltage / current;
  final minResistance = minAvailableVoltage / current;
  final maxResistance = maxAvailableVoltage / current;
  final power = current * availableVoltage;
  final selectedCurrent = selectedResistance == null
      ? null
      : availableVoltage / selectedResistance * 1000;
  final selectedMinCurrent = selectedResistance == null
      ? null
      : minAvailableVoltage / selectedResistance * 1000;
  final selectedMaxCurrent = selectedResistance == null
      ? null
      : maxAvailableVoltage / selectedResistance * 1000;
  final selectedPower = selectedResistance == null
      ? null
      : availableVoltage * availableVoltage / selectedResistance;

  return [
    ToolResult.number('限流电阻', resistance, 'Ω', primary: true),
    ToolResult.number('可用压差', availableVoltage, 'V'),
    ToolResult.number('最小压差', minAvailableVoltage, 'V'),
    ToolResult.number('功耗', power * 1000, 'mW'),
    _powerRatingResult('推荐功率', power, ''),
    if (minAvailableVoltage <= 0)
      const ToolResult.invalid('电阻范围', 'Ω')
    else
      _rangeResult('电阻范围', minResistance, maxResistance, 'Ω'),
    if (includeSelected) ToolResult.number('选用电阻', selectedResistance, 'Ω'),
    if (selectedCurrent != null)
      ToolResult.number('实际电流', selectedCurrent, 'mA'),
    if (selectedPower != null)
      ToolResult.number('实际功耗', selectedPower * 1000, 'mW'),
    if (selectedPower != null) _powerRatingResult('实际推荐功率', selectedPower, ''),
    if (selectedCurrent != null)
      ToolResult.number('电流偏差', selectedCurrent - currentMa, 'mA'),
    if (selectedMinCurrent != null && selectedMaxCurrent != null)
      _rangeResult('实际电流范围', selectedMinCurrent, selectedMaxCurrent, 'mA'),
  ];
}

List<ToolResult> _invalidLedResistorResults({
  required double availableVoltage,
  required double minAvailableVoltage,
  required bool includeSelected,
}) {
  return [
    const ToolResult.invalid('限流电阻', 'Ω', primary: true),
    ToolResult.number('可用压差', availableVoltage, 'V'),
    ToolResult.number('最小压差', minAvailableVoltage, 'V'),
    const ToolResult.invalid('功耗', 'mW'),
    const ToolResult.invalid('推荐功率', ''),
    const ToolResult.invalid('电阻范围', 'Ω'),
    if (includeSelected) const ToolResult.invalid('选用电阻', 'Ω'),
    if (includeSelected) const ToolResult.invalid('实际电流', 'mA'),
    if (includeSelected) const ToolResult.invalid('实际功耗', 'mW'),
    if (includeSelected) const ToolResult.invalid('实际推荐功率', ''),
    if (includeSelected) const ToolResult.invalid('电流偏差', 'mA'),
    if (includeSelected) const ToolResult.invalid('实际电流范围', 'mA'),
  ];
}

List<ToolResult> resistorNetworkResults(Map<String, double> valuesByKey) {
  final r1 = valuesByKey['r1'] ?? 0;
  final r2 = valuesByKey['r2'] ?? 0;
  final tolerance = ((valuesByKey['tol'] ?? 0).abs()) / 100;
  final targetSeries = valuesByKey['targetSeries'];
  final targetParallel = valuesByKey['targetParallel'];
  if (!_validPositivePair(r1, r2) ||
      !_validOptionalPositive(targetSeries) ||
      !_validOptionalPositive(targetParallel)) {
    return _invalidResistorNetworkResults(
      includeTargetSeries: targetSeries != null,
      includeTargetParallel: targetParallel != null,
    );
  }

  final series = r1 + r2;
  final parallel = r1 * r2 / (r1 + r2);
  final conductance = (1 / r1 + 1 / r2) * 1000;
  final targetSeriesR2 = targetSeries == null ? null : targetSeries - r1;
  final targetParallelR2 =
      targetParallel == null ? null : _requiredParallelMate(r1, targetParallel);
  return [
    ToolResult.number('串联等效', series, 'Ω', primary: true),
    ToolResult.number('并联等效', parallel, 'Ω'),
    ToolResult.number('总电导', conductance, 'mS'),
    ToolResult.number('元件比值', _componentRatio(r1, r2), ''),
    _rangeResult(
        '串联范围', series * (1 - tolerance), series * (1 + tolerance), 'Ω'),
    _rangeResult(
        '并联范围', parallel * (1 - tolerance), parallel * (1 + tolerance), 'Ω'),
    if (targetSeries != null) ToolResult.number('目标串联等效', targetSeries, 'Ω'),
    if (targetSeries != null)
      ToolResult.number(
          '串联目标所需R2',
          targetSeriesR2 != null && targetSeriesR2 > 0 ? targetSeriesR2 : null,
          'Ω'),
    if (targetParallel != null)
      ToolResult.number('目标并联等效', targetParallel, 'Ω'),
    if (targetParallel != null)
      ToolResult.number('并联目标所需R2', targetParallelR2, 'Ω'),
  ];
}

List<ToolResult> _invalidResistorNetworkResults({
  required bool includeTargetSeries,
  required bool includeTargetParallel,
}) {
  return [
    const ToolResult.invalid('串联等效', 'Ω', primary: true),
    const ToolResult.invalid('并联等效', 'Ω'),
    const ToolResult.invalid('总电导', 'mS'),
    const ToolResult.invalid('元件比值', ''),
    const ToolResult.invalid('串联范围', 'Ω'),
    const ToolResult.invalid('并联范围', 'Ω'),
    if (includeTargetSeries) const ToolResult.invalid('目标串联等效', 'Ω'),
    if (includeTargetSeries) const ToolResult.invalid('串联目标所需R2', 'Ω'),
    if (includeTargetParallel) const ToolResult.invalid('目标并联等效', 'Ω'),
    if (includeTargetParallel) const ToolResult.invalid('并联目标所需R2', 'Ω'),
  ];
}

List<ToolResult> capacitorNetworkResults(Map<String, double> valuesByKey) {
  final c1 = valuesByKey['c1'] ?? 0;
  final c2 = valuesByKey['c2'] ?? 0;
  final tolerance = ((valuesByKey['tol'] ?? 0).abs()) / 100;
  final targetParallel = valuesByKey['targetParallel'];
  final targetSeries = valuesByKey['targetSeries'];
  if (!_validPositivePair(c1, c2) ||
      !_validOptionalPositive(targetParallel) ||
      !_validOptionalPositive(targetSeries)) {
    return _invalidCapacitorNetworkResults(
      includeTargetParallel: targetParallel != null,
      includeTargetSeries: targetSeries != null,
    );
  }

  final series = c1 * c2 / (c1 + c2);
  final parallel = c1 + c2;
  final targetParallelC2 = targetParallel == null ? null : targetParallel - c1;
  final targetSeriesC2 =
      targetSeries == null ? null : _requiredParallelMate(c1, targetSeries);
  return [
    ToolResult.number('并联等效', parallel, 'nF', primary: true),
    ToolResult.number('串联等效', series, 'nF'),
    ToolResult.number('元件比值', _componentRatio(c1, c2), ''),
    _rangeResult(
        '并联范围', parallel * (1 - tolerance), parallel * (1 + tolerance), 'nF'),
    _rangeResult(
        '串联范围', series * (1 - tolerance), series * (1 + tolerance), 'nF'),
    if (targetParallel != null)
      ToolResult.number('目标并联等效', targetParallel, 'nF'),
    if (targetParallel != null)
      ToolResult.number(
          '并联目标所需C2',
          targetParallelC2 != null && targetParallelC2 > 0
              ? targetParallelC2
              : null,
          'nF'),
    if (targetSeries != null) ToolResult.number('目标串联等效', targetSeries, 'nF'),
    if (targetSeries != null)
      ToolResult.number('串联目标所需C2', targetSeriesC2, 'nF'),
  ];
}

List<ToolResult> _invalidCapacitorNetworkResults({
  required bool includeTargetParallel,
  required bool includeTargetSeries,
}) {
  return [
    const ToolResult.invalid('并联等效', 'nF', primary: true),
    const ToolResult.invalid('串联等效', 'nF'),
    const ToolResult.invalid('元件比值', ''),
    const ToolResult.invalid('并联范围', 'nF'),
    const ToolResult.invalid('串联范围', 'nF'),
    if (includeTargetParallel) const ToolResult.invalid('目标并联等效', 'nF'),
    if (includeTargetParallel) const ToolResult.invalid('并联目标所需C2', 'nF'),
    if (includeTargetSeries) const ToolResult.invalid('目标串联等效', 'nF'),
    if (includeTargetSeries) const ToolResult.invalid('串联目标所需C2', 'nF'),
  ];
}

List<ToolResult> inductorNetworkResults(Map<String, double> valuesByKey) {
  final l1 = valuesByKey['l1'] ?? 0;
  final l2 = valuesByKey['l2'] ?? 0;
  final tolerance = ((valuesByKey['tol'] ?? 0).abs()) / 100;
  final targetSeries = valuesByKey['targetSeries'];
  final targetParallel = valuesByKey['targetParallel'];
  if (!_validPositivePair(l1, l2) ||
      !_validOptionalPositive(targetSeries) ||
      !_validOptionalPositive(targetParallel)) {
    return _invalidInductorNetworkResults(
      includeTargetSeries: targetSeries != null,
      includeTargetParallel: targetParallel != null,
    );
  }

  final series = l1 + l2;
  final parallel = l1 * l2 / (l1 + l2);
  final targetSeriesL2 = targetSeries == null ? null : targetSeries - l1;
  final targetParallelL2 =
      targetParallel == null ? null : _requiredParallelMate(l1, targetParallel);
  return [
    ToolResult.number('串联等效', series, 'mH', primary: true),
    ToolResult.number('并联等效', parallel, 'mH'),
    ToolResult.number('元件比值', _componentRatio(l1, l2), ''),
    _rangeResult(
        '串联范围', series * (1 - tolerance), series * (1 + tolerance), 'mH'),
    _rangeResult(
        '并联范围', parallel * (1 - tolerance), parallel * (1 + tolerance), 'mH'),
    if (targetSeries != null) ToolResult.number('目标串联等效', targetSeries, 'mH'),
    if (targetSeries != null)
      ToolResult.number(
          '串联目标所需L2',
          targetSeriesL2 != null && targetSeriesL2 > 0 ? targetSeriesL2 : null,
          'mH'),
    if (targetParallel != null)
      ToolResult.number('目标并联等效', targetParallel, 'mH'),
    if (targetParallel != null)
      ToolResult.number('并联目标所需L2', targetParallelL2, 'mH'),
  ];
}

List<ToolResult> _invalidInductorNetworkResults({
  required bool includeTargetSeries,
  required bool includeTargetParallel,
}) {
  return [
    const ToolResult.invalid('串联等效', 'mH', primary: true),
    const ToolResult.invalid('并联等效', 'mH'),
    const ToolResult.invalid('元件比值', ''),
    const ToolResult.invalid('串联范围', 'mH'),
    const ToolResult.invalid('并联范围', 'mH'),
    if (includeTargetSeries) const ToolResult.invalid('目标串联等效', 'mH'),
    if (includeTargetSeries) const ToolResult.invalid('串联目标所需L2', 'mH'),
    if (includeTargetParallel) const ToolResult.invalid('目标并联等效', 'mH'),
    if (includeTargetParallel) const ToolResult.invalid('并联目标所需L2', 'mH'),
  ];
}

List<ToolResult> voltageDividerResults(Map<String, double> valuesByKey) {
  final vin = valuesByKey['vin'] ?? 0;
  final r1 = (valuesByKey['r1'] ?? 0) * 1000;
  final r2 = (valuesByKey['r2'] ?? 0) * 1000;
  final loadK = valuesByKey['load'] ?? 0;
  final tolerance = (valuesByKey['tol'] ?? 0).abs();
  final targetVout = valuesByKey['targetVout'];
  final includeTarget = targetVout != null;
  if (r1 <= 0 ||
      r2 <= 0 ||
      loadK < 0 ||
      !vin.isFinite ||
      !r1.isFinite ||
      !r2.isFinite ||
      !loadK.isFinite ||
      (targetVout != null && !targetVout.isFinite)) {
    return _invalidVoltageDividerResults(includeTarget: includeTarget);
  }

  final load = loadK <= 0 ? 0.0 : loadK * 1000;
  final lower = load <= 0 ? r2 : 1 / (1 / r2 + 1 / load);
  final unloadedVout = vin * r2 / (r1 + r2);
  final vout = vin * lower / (r1 + lower);
  final current = vin / (r1 + lower);
  final loadCurrent = load <= 0 ? 0.0 : vout / load;
  final upperPower = (vin - vout) * (vin - vout) / r1;
  final lowerPower = vout * vout / r2;
  final target = targetVout == null
      ? null
      : _solveTargetDivider(
          vin: vin,
          r1: r1,
          r2: r2,
          load: load,
          targetVout: targetVout,
        );

  return [
    ToolResult.number('输出电压 Vout', vout, 'V', precision: 4, primary: true),
    ToolResult.number('空载输出', unloadedVout, 'V', precision: 4),
    ToolResult.number('下臂等效', lower / 1000, 'kΩ'),
    ToolResult.number('分压电流', current * 1000, 'mA'),
    ToolResult.number('负载电流', loadCurrent * 1000, 'mA'),
    ToolResult.number('总功耗', vin * current * 1000, 'mW'),
    ToolResult.number('上臂功耗', upperPower * 1000, 'mW'),
    ToolResult.number('下臂功耗', lowerPower * 1000, 'mW'),
    // 中文：**两个端点先算成数值，错误状态由它们决定。** 从前这是把两个 `formatNumber`
    //       拼进一句话里，判据再回读那句话里有没有「无效」——两个端点是不是有限数才是真原因。
    // English: **Both endpoints are computed as numbers first, and they decide the error state.**
    //          This used to interpolate two `formatNumber` calls into one sentence and let the
    //          predicate read that sentence back — whether the two endpoints are finite is the real
    //          reason.
    ToolResult(
      '误差范围',
      '${formatNumber(vout * (1 - tolerance / 100))}~'
          '${formatNumber(vout * (1 + tolerance / 100))}',
      'V',
      hasError: !(vout * (1 - tolerance / 100)).isFinite ||
          !(vout * (1 + tolerance / 100)).isFinite,
    ),
    if (includeTarget)
      ToolResult.number(
          '目标输出电压', target?.valid ?? false ? targetVout : null, 'V'),
    if (includeTarget)
      ToolResult.number(
          '输出偏差', target?.valid ?? false ? vout - targetVout : null, 'V'),
    if (includeTarget)
      ToolResult.number('保留R2所需R1',
          target?.requiredR1 == null ? null : target!.requiredR1! / 1000, 'kΩ'),
    if (includeTarget)
      ToolResult.number('保留R1所需R2',
          target?.requiredR2 == null ? null : target!.requiredR2! / 1000, 'kΩ'),
    if (includeTarget)
      ToolResult.number(
          '目标下臂等效',
          target?.requiredLower == null ? null : target!.requiredLower! / 1000,
          'kΩ'),
  ];
}

List<ToolResult> _invalidVoltageDividerResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('输出电压 Vout', 'V', primary: true),
    const ToolResult.invalid('空载输出', 'V'),
    const ToolResult.invalid('下臂等效', 'kΩ'),
    const ToolResult.invalid('分压电流', 'mA'),
    const ToolResult.invalid('负载电流', 'mA'),
    const ToolResult.invalid('总功耗', 'mW'),
    const ToolResult.invalid('上臂功耗', 'mW'),
    const ToolResult.invalid('下臂功耗', 'mW'),
    const ToolResult.invalid('误差范围', 'V'),
    if (includeTarget) const ToolResult.invalid('目标输出电压', 'V'),
    if (includeTarget) const ToolResult.invalid('输出偏差', 'V'),
    if (includeTarget) const ToolResult.invalid('保留R2所需R1', 'kΩ'),
    if (includeTarget) const ToolResult.invalid('保留R1所需R2', 'kΩ'),
    if (includeTarget) const ToolResult.invalid('目标下臂等效', 'kΩ'),
  ];
}

_TargetDivider? _solveTargetDivider({
  required double vin,
  required double r1,
  required double r2,
  required double load,
  required double targetVout,
}) {
  if (vin == 0 || targetVout == 0 || targetVout / vin <= 0) {
    return const _TargetDivider.invalid();
  }
  final ratio = targetVout / vin;
  if (ratio >= 1 || !ratio.isFinite) return const _TargetDivider.invalid();

  final currentLower = load <= 0 ? r2 : 1 / (1 / r2 + 1 / load);
  final requiredLowerForR1 = r1 * ratio / (1 - ratio);
  final requiredR1ForR2 = currentLower * (1 - ratio) / ratio;
  double? requiredR2 = requiredLowerForR1;
  if (load > 0) {
    requiredR2 = requiredLowerForR1 >= load
        ? null
        : requiredLowerForR1 * load / (load - requiredLowerForR1);
  }

  return _TargetDivider(
    valid: true,
    requiredR1: requiredR1ForR2 > 0 && requiredR1ForR2.isFinite
        ? requiredR1ForR2
        : null,
    requiredR2: requiredR2 != null && requiredR2 > 0 && requiredR2.isFinite
        ? requiredR2
        : null,
    requiredLower: requiredLowerForR1 > 0 && requiredLowerForR1.isFinite
        ? requiredLowerForR1
        : null,
  );
}

/// 中文：**一条「范围」结果。** 错误状态由两个端点本身决定，不由 [ _formatRange ] 那句话决定——
///       「这句话里有没有『无效』」只在端点不是有限数时为真，与它怎么措辞无关。
/// English: **One "range" result.** The error state is decided by the two endpoints themselves, not
///          by the sentence [_formatRange] builds — "does that sentence contain 无效" is true exactly
///          when an endpoint is not finite, whatever the wording.
ToolResult _rangeResult(String label, double a, double b, String unit,
    {bool primary = false}) {
  return ToolResult(label, _formatRange(a, b), unit,
      primary: primary, hasError: !a.isFinite || !b.isFinite);
}

/// 中文：**一条「推荐功率」结果。** `dissipatedPowerW` 不是正有限数时 [ _resistorPowerRating ]
///       回的就是那条记号——产出方知道的是这个条件，不是那句话。
/// English: **One "recommended rating" result.** When `dissipatedPowerW` is not a positive finite
///          number [_resistorPowerRating] hands back the marker — the condition is what the producer
///          knows, not the sentence.
ToolResult _powerRatingResult(
    String label, double dissipatedPowerW, String unit) {
  // 中文：那个条件成立时 [_resistorPowerRating] 回的就是**那条记号本身**，所以两个旗标一起写。
  // English: when that condition holds [_resistorPowerRating] hands back **the marker itself**, so
  //          both flags are written together.
  final unavailable = dissipatedPowerW <= 0 || !dissipatedPowerW.isFinite;
  return ToolResult(label, _resistorPowerRating(dissipatedPowerW), unit,
      hasError: unavailable, isInvalidMarker: unavailable);
}

String _formatRange(double a, double b) {
  final low = a < b ? a : b;
  final high = a < b ? b : a;
  return '${formatNumber(low)} ~ ${formatNumber(high)}';
}

bool _validPositivePair(double first, double second) {
  return first > 0 && second > 0 && first.isFinite && second.isFinite;
}

bool _validOptionalPositive(double? value) {
  return value == null || (value > 0 && value.isFinite);
}

/// 中文：元件比值这个**数值**。它从前直接返回一句话，调用方只好回读那句话判断「算出来了没有」；
///       现在它交数值，错误状态归 [ToolResult.number] 管。
/// English: The **number** that is the component ratio. It used to return a sentence outright,
///          leaving the caller to read that sentence back to decide "did this compute?"; it now
///          hands over the number and [ToolResult.number] owns the error state.
double _componentRatio(double first, double second) {
  return math.max(first, second) / math.min(first, second);
}

double? _requiredParallelMate(double knownComponent, double targetEquivalent) {
  if (targetEquivalent >= knownComponent) return null;
  final required =
      knownComponent * targetEquivalent / (knownComponent - targetEquivalent);
  return required > 0 && required.isFinite ? required : null;
}

String _resistorPowerRating(double dissipatedPowerW) {
  if (dissipatedPowerW <= 0 || !dissipatedPowerW.isFinite) return '无效';
  final recommended = dissipatedPowerW * 2;
  const ratings = <double>[0.125, 0.25, 0.5, 1, 2, 3, 5, 10];
  final rating = ratings.firstWhere(
    (value) => value >= recommended,
    orElse: () => recommended,
  );
  return '≥ ${_powerRatingLabel(rating)}';
}

String _powerRatingLabel(double watts) {
  switch (watts) {
    case 0.125:
      return '1/8W';
    case 0.25:
      return '1/4W';
    case 0.5:
      return '1/2W';
    default:
      return '${formatNumber(watts)}W';
  }
}

class _TargetDivider {
  const _TargetDivider({
    required this.valid,
    required this.requiredR1,
    required this.requiredR2,
    required this.requiredLower,
  });

  const _TargetDivider.invalid()
      : valid = false,
        requiredR1 = null,
        requiredR2 = null,
        requiredLower = null;

  final bool valid;
  final double? requiredR1;
  final double? requiredR2;
  final double? requiredLower;
}
