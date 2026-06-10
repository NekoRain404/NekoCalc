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
    ToolResult('电压 V', formatNumber(solved.voltage), 'V', primary: true),
    ToolResult('电压幅值', formatNumber(solved.voltage.abs()), 'V'),
    ToolResult('功率 P', formatNumber(solved.power), 'W'),
    ToolResult('电流', formatNumber(solved.current * 1000), 'mA'),
    ToolResult('电阻', formatNumber(solved.resistance / 1000), 'kΩ'),
    ToolResult('电导', formatNumber(1000 / solved.resistance), 'mS'),
    ToolResult('推荐功率', _resistorPowerRating(solved.power), ''),
    ToolResult(
        '电压范围',
        _formatRange(
            solved.current * minResistance, solved.current * maxResistance),
        'V'),
    ToolResult('功率范围', _formatRange(minPower, maxPower), 'W'),
    ToolResult('输入来源', solved.source, ''),
  ];
}

List<ToolResult> _invalidOhmsLawResults() {
  return const [
    ToolResult('电压 V', '无效', 'V', primary: true),
    ToolResult('电压幅值', '无效', 'V'),
    ToolResult('功率 P', '无效', 'W'),
    ToolResult('电流', '无效', 'mA'),
    ToolResult('电阻', '无效', 'kΩ'),
    ToolResult('电导', '无效', 'mS'),
    ToolResult('推荐功率', '无效', ''),
    ToolResult('电压范围', '无效', 'V'),
    ToolResult('功率范围', '无效', 'W'),
    ToolResult('输入来源', '无效', ''),
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
    ToolResult('限流电阻', formatNumber(resistance), 'Ω', primary: true),
    ToolResult('可用压差', formatNumber(availableVoltage), 'V'),
    ToolResult('最小压差', formatNumber(minAvailableVoltage), 'V'),
    ToolResult('功耗', formatNumber(power * 1000), 'mW'),
    ToolResult('推荐功率', _resistorPowerRating(power), ''),
    ToolResult(
        '电阻范围',
        minAvailableVoltage <= 0
            ? '无效'
            : _formatRange(minResistance, maxResistance),
        'Ω'),
    if (includeSelected)
      ToolResult('选用电阻', formatNumber(selectedResistance), 'Ω'),
    if (selectedCurrent != null)
      ToolResult('实际电流', formatNumber(selectedCurrent), 'mA'),
    if (selectedPower != null)
      ToolResult('实际功耗', formatNumber(selectedPower * 1000), 'mW'),
    if (selectedPower != null)
      ToolResult('实际推荐功率', _resistorPowerRating(selectedPower), ''),
    if (selectedCurrent != null)
      ToolResult('电流偏差', formatNumber(selectedCurrent - currentMa), 'mA'),
    if (selectedMinCurrent != null && selectedMaxCurrent != null)
      ToolResult(
          '实际电流范围', _formatRange(selectedMinCurrent, selectedMaxCurrent), 'mA'),
  ];
}

List<ToolResult> _invalidLedResistorResults({
  required double availableVoltage,
  required double minAvailableVoltage,
  required bool includeSelected,
}) {
  return [
    const ToolResult('限流电阻', '无效', 'Ω', primary: true),
    ToolResult('可用压差', formatNumber(availableVoltage), 'V'),
    ToolResult('最小压差', formatNumber(minAvailableVoltage), 'V'),
    const ToolResult('功耗', '无效', 'mW'),
    const ToolResult('推荐功率', '无效', ''),
    const ToolResult('电阻范围', '无效', 'Ω'),
    if (includeSelected) const ToolResult('选用电阻', '无效', 'Ω'),
    if (includeSelected) const ToolResult('实际电流', '无效', 'mA'),
    if (includeSelected) const ToolResult('实际功耗', '无效', 'mW'),
    if (includeSelected) const ToolResult('实际推荐功率', '无效', ''),
    if (includeSelected) const ToolResult('电流偏差', '无效', 'mA'),
    if (includeSelected) const ToolResult('实际电流范围', '无效', 'mA'),
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
    ToolResult('串联等效', formatNumber(series), 'Ω', primary: true),
    ToolResult('并联等效', formatNumber(parallel), 'Ω'),
    ToolResult('总电导', formatNumber(conductance), 'mS'),
    ToolResult('元件比值', _componentRatio(r1, r2), ''),
    ToolResult('串联范围',
        _formatRange(series * (1 - tolerance), series * (1 + tolerance)), 'Ω'),
    ToolResult(
        '并联范围',
        _formatRange(parallel * (1 - tolerance), parallel * (1 + tolerance)),
        'Ω'),
    if (targetSeries != null)
      ToolResult('目标串联等效', formatNumber(targetSeries), 'Ω'),
    if (targetSeries != null)
      ToolResult(
          '串联目标所需R2',
          targetSeriesR2 != null && targetSeriesR2 > 0
              ? formatNumber(targetSeriesR2)
              : '无效',
          'Ω'),
    if (targetParallel != null)
      ToolResult('目标并联等效', formatNumber(targetParallel), 'Ω'),
    if (targetParallel != null)
      ToolResult(
          '并联目标所需R2',
          targetParallelR2 == null ? '无效' : formatNumber(targetParallelR2),
          'Ω'),
  ];
}

List<ToolResult> _invalidResistorNetworkResults({
  required bool includeTargetSeries,
  required bool includeTargetParallel,
}) {
  return [
    const ToolResult('串联等效', '无效', 'Ω', primary: true),
    const ToolResult('并联等效', '无效', 'Ω'),
    const ToolResult('总电导', '无效', 'mS'),
    const ToolResult('元件比值', '无效', ''),
    const ToolResult('串联范围', '无效', 'Ω'),
    const ToolResult('并联范围', '无效', 'Ω'),
    if (includeTargetSeries) const ToolResult('目标串联等效', '无效', 'Ω'),
    if (includeTargetSeries) const ToolResult('串联目标所需R2', '无效', 'Ω'),
    if (includeTargetParallel) const ToolResult('目标并联等效', '无效', 'Ω'),
    if (includeTargetParallel) const ToolResult('并联目标所需R2', '无效', 'Ω'),
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
    ToolResult('并联等效', formatNumber(parallel), 'nF', primary: true),
    ToolResult('串联等效', formatNumber(series), 'nF'),
    ToolResult('元件比值', _componentRatio(c1, c2), ''),
    ToolResult(
        '并联范围',
        _formatRange(parallel * (1 - tolerance), parallel * (1 + tolerance)),
        'nF'),
    ToolResult('串联范围',
        _formatRange(series * (1 - tolerance), series * (1 + tolerance)), 'nF'),
    if (targetParallel != null)
      ToolResult('目标并联等效', formatNumber(targetParallel), 'nF'),
    if (targetParallel != null)
      ToolResult(
          '并联目标所需C2',
          targetParallelC2 != null && targetParallelC2 > 0
              ? formatNumber(targetParallelC2)
              : '无效',
          'nF'),
    if (targetSeries != null)
      ToolResult('目标串联等效', formatNumber(targetSeries), 'nF'),
    if (targetSeries != null)
      ToolResult('串联目标所需C2',
          targetSeriesC2 == null ? '无效' : formatNumber(targetSeriesC2), 'nF'),
  ];
}

List<ToolResult> _invalidCapacitorNetworkResults({
  required bool includeTargetParallel,
  required bool includeTargetSeries,
}) {
  return [
    const ToolResult('并联等效', '无效', 'nF', primary: true),
    const ToolResult('串联等效', '无效', 'nF'),
    const ToolResult('元件比值', '无效', ''),
    const ToolResult('并联范围', '无效', 'nF'),
    const ToolResult('串联范围', '无效', 'nF'),
    if (includeTargetParallel) const ToolResult('目标并联等效', '无效', 'nF'),
    if (includeTargetParallel) const ToolResult('并联目标所需C2', '无效', 'nF'),
    if (includeTargetSeries) const ToolResult('目标串联等效', '无效', 'nF'),
    if (includeTargetSeries) const ToolResult('串联目标所需C2', '无效', 'nF'),
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
    ToolResult('串联等效', formatNumber(series), 'mH', primary: true),
    ToolResult('并联等效', formatNumber(parallel), 'mH'),
    ToolResult('元件比值', _componentRatio(l1, l2), ''),
    ToolResult('串联范围',
        _formatRange(series * (1 - tolerance), series * (1 + tolerance)), 'mH'),
    ToolResult(
        '并联范围',
        _formatRange(parallel * (1 - tolerance), parallel * (1 + tolerance)),
        'mH'),
    if (targetSeries != null)
      ToolResult('目标串联等效', formatNumber(targetSeries), 'mH'),
    if (targetSeries != null)
      ToolResult(
          '串联目标所需L2',
          targetSeriesL2 != null && targetSeriesL2 > 0
              ? formatNumber(targetSeriesL2)
              : '无效',
          'mH'),
    if (targetParallel != null)
      ToolResult('目标并联等效', formatNumber(targetParallel), 'mH'),
    if (targetParallel != null)
      ToolResult(
          '并联目标所需L2',
          targetParallelL2 == null ? '无效' : formatNumber(targetParallelL2),
          'mH'),
  ];
}

List<ToolResult> _invalidInductorNetworkResults({
  required bool includeTargetSeries,
  required bool includeTargetParallel,
}) {
  return [
    const ToolResult('串联等效', '无效', 'mH', primary: true),
    const ToolResult('并联等效', '无效', 'mH'),
    const ToolResult('元件比值', '无效', ''),
    const ToolResult('串联范围', '无效', 'mH'),
    const ToolResult('并联范围', '无效', 'mH'),
    if (includeTargetSeries) const ToolResult('目标串联等效', '无效', 'mH'),
    if (includeTargetSeries) const ToolResult('串联目标所需L2', '无效', 'mH'),
    if (includeTargetParallel) const ToolResult('目标并联等效', '无效', 'mH'),
    if (includeTargetParallel) const ToolResult('并联目标所需L2', '无效', 'mH'),
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
    ToolResult('输出电压 Vout', formatNumber(vout, precision: 4), 'V',
        primary: true),
    ToolResult('空载输出', formatNumber(unloadedVout, precision: 4), 'V'),
    ToolResult('下臂等效', formatNumber(lower / 1000), 'kΩ'),
    ToolResult('分压电流', formatNumber(current * 1000), 'mA'),
    ToolResult('负载电流', formatNumber(loadCurrent * 1000), 'mA'),
    ToolResult('总功耗', formatNumber(vin * current * 1000), 'mW'),
    ToolResult('上臂功耗', formatNumber(upperPower * 1000), 'mW'),
    ToolResult('下臂功耗', formatNumber(lowerPower * 1000), 'mW'),
    ToolResult(
        '误差范围',
        '${formatNumber(vout * (1 - tolerance / 100))}~'
            '${formatNumber(vout * (1 + tolerance / 100))}',
        'V'),
    if (includeTarget)
      ToolResult('目标输出电压',
          target?.valid ?? false ? formatNumber(targetVout) : '无效', 'V'),
    if (includeTarget)
      ToolResult('输出偏差',
          target?.valid ?? false ? formatNumber(vout - targetVout) : '无效', 'V'),
    if (includeTarget)
      ToolResult(
          '保留R2所需R1',
          target?.requiredR1 == null
              ? '无效'
              : formatNumber(target!.requiredR1! / 1000),
          'kΩ'),
    if (includeTarget)
      ToolResult(
          '保留R1所需R2',
          target?.requiredR2 == null
              ? '无效'
              : formatNumber(target!.requiredR2! / 1000),
          'kΩ'),
    if (includeTarget)
      ToolResult(
          '目标下臂等效',
          target?.requiredLower == null
              ? '无效'
              : formatNumber(target!.requiredLower! / 1000),
          'kΩ'),
  ];
}

List<ToolResult> _invalidVoltageDividerResults({required bool includeTarget}) {
  return [
    const ToolResult('输出电压 Vout', '无效', 'V', primary: true),
    const ToolResult('空载输出', '无效', 'V'),
    const ToolResult('下臂等效', '无效', 'kΩ'),
    const ToolResult('分压电流', '无效', 'mA'),
    const ToolResult('负载电流', '无效', 'mA'),
    const ToolResult('总功耗', '无效', 'mW'),
    const ToolResult('上臂功耗', '无效', 'mW'),
    const ToolResult('下臂功耗', '无效', 'mW'),
    const ToolResult('误差范围', '无效', 'V'),
    if (includeTarget) const ToolResult('目标输出电压', '无效', 'V'),
    if (includeTarget) const ToolResult('输出偏差', '无效', 'V'),
    if (includeTarget) const ToolResult('保留R2所需R1', '无效', 'kΩ'),
    if (includeTarget) const ToolResult('保留R1所需R2', '无效', 'kΩ'),
    if (includeTarget) const ToolResult('目标下臂等效', '无效', 'kΩ'),
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

String _componentRatio(double first, double second) {
  return formatNumber(math.max(first, second) / math.min(first, second));
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
