import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

const double _timer555Coefficient = 0.693;

List<ToolResult> dbmResults(Map<String, double> valuesByKey) {
  final dbm = valuesByKey['dbm'] ?? 0;
  if (!dbm.isFinite) {
    return const [
      ToolResult('功率', '无效', 'mW', primary: true),
      ToolResult('微瓦', '无效', 'μW'),
      ToolResult('瓦特', '无效', 'W'),
      ToolResult('dBW', '无效', 'dBW'),
      ToolResult('50Ω Vrms', '无效', 'V'),
      ToolResult('50Ω Vpeak', '无效', 'V'),
      ToolResult('50Ω Vpp', '无效', 'V'),
      ToolResult('50Ω dBV', '无效', 'dBV'),
      ToolResult('50Ω dBu', '无效', 'dBu'),
    ];
  }

  final mw = math.pow(10, dbm / 10).toDouble();
  final watts = mw / 1000;
  final vrms50 = math.sqrt(watts * 50);
  final vpeak50 = vrms50 * math.sqrt2;
  final dbv =
      vrms50 > 0 ? formatNumber(20 * math.log(vrms50) / math.ln10) : '无效';
  final dbu = vrms50 > 0
      ? formatNumber(20 * math.log(vrms50 / 0.775) / math.ln10)
      : '无效';
  return [
    ToolResult('功率', formatNumber(mw), 'mW', primary: true),
    ToolResult('微瓦', formatNumber(mw * 1000), 'μW'),
    ToolResult('瓦特', formatNumber(watts), 'W'),
    ToolResult('dBW', formatNumber(dbm - 30), 'dBW'),
    ToolResult('50Ω Vrms', formatNumber(vrms50), 'V'),
    ToolResult('50Ω Vpeak', formatNumber(vpeak50), 'V'),
    ToolResult('50Ω Vpp', formatNumber(vpeak50 * 2), 'V'),
    ToolResult('50Ω dBV', dbv, 'dBV'),
    ToolResult('50Ω dBu', dbu, 'dBu'),
  ];
}

List<ToolResult> rcFilterResults(Map<String, double> valuesByKey) {
  final resistance = (valuesByKey['r'] ?? 0) * 1000;
  final capacitance = (valuesByKey['c'] ?? 0) * 1e-9;
  final tolerance = ((valuesByKey['tol'] ?? 0).abs()) / 100;
  final targetCutoff = valuesByKey['targetFc'];
  final includeTarget = targetCutoff != null;
  if (resistance <= 0 ||
      capacitance <= 0 ||
      !resistance.isFinite ||
      !capacitance.isFinite ||
      (targetCutoff != null && (targetCutoff <= 0 || !targetCutoff.isFinite))) {
    return _invalidRcFilterResults(includeTarget: includeTarget);
  }

  final cutoff = 1 / (2 * math.pi * resistance * capacitance);
  final tau = resistance * capacitance;
  final low = 1 /
      (2 *
          math.pi *
          resistance *
          (1 + tolerance) *
          capacitance *
          (1 + tolerance));
  final high = 1 /
      (2 *
          math.pi *
          resistance *
          (1 - tolerance).clamp(0.0001, 1) *
          capacitance *
          (1 - tolerance).clamp(0.0001, 1));
  final targetCapacitance = targetCutoff == null
      ? null
      : 1 / (2 * math.pi * resistance * targetCutoff);
  final targetResistance = targetCutoff == null
      ? null
      : 1 / (2 * math.pi * capacitance * targetCutoff);
  final targetTau =
      targetCutoff == null ? null : 1 / (2 * math.pi * targetCutoff);

  return [
    ToolResult('截止频率 fc', formatNumber(cutoff), 'Hz', primary: true),
    ToolResult('截止频率', formatNumber(cutoff / 1000), 'kHz'),
    ToolResult('时间常数 τ', formatNumber(tau * 1000), 'ms'),
    ToolResult('等效周期', formatNumber(1 / cutoff * 1000), 'ms'),
    ToolResult('0.1fc', formatNumber(cutoff / 10), 'Hz'),
    ToolResult('10fc', formatNumber(cutoff * 10), 'Hz'),
    ToolResult('100fc', formatNumber(cutoff * 100), 'Hz'),
    ToolResult('fc范围', _formatRange(low, high), 'Hz'),
    if (includeTarget) ToolResult('目标截止频率', formatNumber(targetCutoff), 'Hz'),
    if (includeTarget)
      ToolResult('频率偏差', formatNumber(cutoff - targetCutoff), 'Hz'),
    if (targetResistance != null)
      ToolResult('保留C所需R', formatNumber(targetResistance / 1000), 'kΩ'),
    if (targetCapacitance != null)
      ToolResult('保留R所需C', formatNumber(targetCapacitance * 1e9), 'nF'),
    if (targetTau != null)
      ToolResult('目标时间常数 τ', formatNumber(targetTau * 1000), 'ms'),
  ];
}

List<ToolResult> _invalidRcFilterResults({required bool includeTarget}) {
  return [
    const ToolResult('截止频率 fc', '无效', 'Hz', primary: true),
    const ToolResult('截止频率', '无效', 'kHz'),
    const ToolResult('时间常数 τ', '无效', 'ms'),
    const ToolResult('等效周期', '无效', 'ms'),
    const ToolResult('0.1fc', '无效', 'Hz'),
    const ToolResult('10fc', '无效', 'Hz'),
    const ToolResult('100fc', '无效', 'Hz'),
    const ToolResult('fc范围', '无效', 'Hz'),
    if (includeTarget) const ToolResult('目标截止频率', '无效', 'Hz'),
    if (includeTarget) const ToolResult('频率偏差', '无效', 'Hz'),
    if (includeTarget) const ToolResult('保留C所需R', '无效', 'kΩ'),
    if (includeTarget) const ToolResult('保留R所需C', '无效', 'nF'),
    if (includeTarget) const ToolResult('目标时间常数 τ', '无效', 'ms'),
  ];
}

String _formatRange(double a, double b) {
  final low = math.min(a, b);
  final high = math.max(a, b);
  return '${formatNumber(low)} ~ ${formatNumber(high)}';
}

List<ToolResult> opAmpGainResults(Map<String, double> valuesByKey) {
  final rin = valuesByKey['rin'] ?? 0;
  final rf = valuesByKey['rf'] ?? 0;
  final vin = valuesByKey['vin'] ?? 0;
  final targetGain = valuesByKey['targetGain'];
  final gbw = valuesByKey['gbw'];
  final outputSwing = valuesByKey['outputSwing'];
  final fullPowerFrequency = valuesByKey['fullPowerFrequency'];
  final includeTarget = targetGain != null;
  final includeBandwidth = gbw != null;
  final includeSlewRate = outputSwing != null || fullPowerFrequency != null;
  if (rin <= 0 ||
      rf < 0 ||
      !rin.isFinite ||
      !rf.isFinite ||
      !vin.isFinite ||
      (targetGain != null && (targetGain <= 1 || !targetGain.isFinite)) ||
      (gbw != null && (gbw <= 0 || !gbw.isFinite)) ||
      (outputSwing != null && (outputSwing < 0 || !outputSwing.isFinite)) ||
      (fullPowerFrequency != null &&
          (fullPowerFrequency < 0 || !fullPowerFrequency.isFinite))) {
    return _invalidOpAmpGainResults(
      includeTarget: includeTarget,
      includeBandwidth: includeBandwidth,
      includeSlewRate: includeSlewRate,
    );
  }

  final ratio = rf / rin;
  final nonInvertingGain = 1 + ratio;
  final invertingGain = -ratio;
  final feedbackTotal = rin + rf;
  final feedbackFactor = rin / feedbackTotal;
  final closedLoopBandwidth = gbw == null ? null : gbw / nonInvertingGain;
  final invertingBandwidth = gbw == null || ratio <= 0 ? null : gbw / ratio;
  final targetRf = targetGain == null ? null : rin * (targetGain - 1);
  final targetRin =
      targetGain == null || targetGain <= 1 ? null : rf / (targetGain - 1);
  final targetInvertingRf = targetGain == null ? null : rin * targetGain.abs();
  final slewRate = outputSwing == null || fullPowerFrequency == null
      ? null
      : 2 * math.pi * fullPowerFrequency * outputSwing / 1000000;
  return [
    ToolResult('同相增益', formatNumber(nonInvertingGain), '倍', primary: true),
    ToolResult('反相增益', formatNumber(invertingGain), '倍'),
    ToolResult('同相增益 dB',
        formatNumber(20 * math.log(nonInvertingGain) / math.ln10), 'dB'),
    ToolResult(
        '反相增益 dB',
        ratio == 0 ? '无效' : formatNumber(20 * math.log(ratio) / math.ln10),
        'dB'),
    ToolResult('同相输出', formatNumber(vin * nonInvertingGain), 'V'),
    ToolResult('反相输出', formatNumber(vin * invertingGain), 'V'),
    ToolResult('电阻比 Rf/Rin', formatNumber(ratio), ''),
    ToolResult('反馈系数 β', formatNumber(feedbackFactor), ''),
    ToolResult('反相输入阻抗', formatNumber(rin), 'kΩ'),
    ToolResult('反馈总阻值', formatNumber(feedbackTotal), 'kΩ'),
    if (includeTarget) ToolResult('目标同相增益', formatNumber(targetGain), '倍'),
    if (includeTarget)
      ToolResult(
          '目标所需Rf',
          targetRf != null && targetRf >= 0 ? formatNumber(targetRf) : '无效',
          'kΩ'),
    if (includeTarget)
      ToolResult(
          '保留Rf所需Rin',
          targetRin != null && targetRin > 0 ? formatNumber(targetRin) : '无效',
          'kΩ'),
    if (includeTarget)
      ToolResult(
          '反相目标所需Rf',
          targetInvertingRf != null && targetInvertingRf >= 0
              ? formatNumber(targetInvertingRf)
              : '无效',
          'kΩ'),
    if (closedLoopBandwidth != null)
      ToolResult('同相闭环带宽', formatNumber(closedLoopBandwidth), 'Hz'),
    if (invertingBandwidth != null)
      ToolResult('反相闭环带宽', formatNumber(invertingBandwidth), 'Hz'),
    if (slewRate != null) ToolResult('所需压摆率', formatNumber(slewRate), 'V/μs'),
  ];
}

List<ToolResult> _invalidOpAmpGainResults({
  required bool includeTarget,
  required bool includeBandwidth,
  required bool includeSlewRate,
}) {
  return [
    const ToolResult('同相增益', '无效', '倍', primary: true),
    const ToolResult('反相增益', '无效', '倍'),
    const ToolResult('同相增益 dB', '无效', 'dB'),
    const ToolResult('反相增益 dB', '无效', 'dB'),
    const ToolResult('同相输出', '无效', 'V'),
    const ToolResult('反相输出', '无效', 'V'),
    const ToolResult('电阻比 Rf/Rin', '无效', ''),
    const ToolResult('反馈系数 β', '无效', ''),
    const ToolResult('反相输入阻抗', '无效', 'kΩ'),
    const ToolResult('反馈总阻值', '无效', 'kΩ'),
    if (includeTarget) const ToolResult('目标同相增益', '无效', '倍'),
    if (includeTarget) const ToolResult('目标所需Rf', '无效', 'kΩ'),
    if (includeTarget) const ToolResult('保留Rf所需Rin', '无效', 'kΩ'),
    if (includeTarget) const ToolResult('反相目标所需Rf', '无效', 'kΩ'),
    if (includeBandwidth) const ToolResult('同相闭环带宽', '无效', 'Hz'),
    if (includeBandwidth) const ToolResult('反相闭环带宽', '无效', 'Hz'),
    if (includeSlewRate) const ToolResult('所需压摆率', '无效', 'V/μs'),
  ];
}

List<ToolResult> adcResolutionResults(Map<String, double> valuesByKey) {
  final vref = valuesByKey['vref'] ?? 0;
  final bits = (valuesByKey['bits'] ?? 0).round();
  final inputVoltage = valuesByKey['vin'];
  final enob = valuesByKey['enob'];
  final includeInput = inputVoltage != null;
  final includeEnob = enob != null;
  if (vref <= 0 ||
      bits <= 0 ||
      bits > 32 ||
      !vref.isFinite ||
      (inputVoltage != null && !inputVoltage.isFinite) ||
      (enob != null && (enob <= 0 || enob > bits || !enob.isFinite))) {
    return _invalidAdcResolutionResults(
      includeInput: includeInput,
      includeEnob: includeEnob,
    );
  }

  final codes = math.pow(2, bits).toDouble();
  final maxCode = codes - 1;
  final lsb = vref / maxCode;
  final dynamicRange = bits * 6.02 + 1.76;
  final clippedInput = inputVoltage?.clamp(0.0, vref);
  final idealCode = clippedInput == null ? null : clippedInput / vref * maxCode;
  final roundedCode = idealCode?.round();
  final reconstructedVoltage = roundedCode == null ? null : roundedCode * lsb;
  final quantizationError = reconstructedVoltage == null || inputVoltage == null
      ? null
      : reconstructedVoltage - inputVoltage;
  final enobCodes = enob == null ? null : math.pow(2, enob).toDouble();
  final enobLsb = enobCodes == null ? null : vref / (enobCodes - 1);
  return [
    ToolResult('LSB', formatNumber(lsb * 1000), 'mV', primary: true),
    ToolResult('LSB', formatNumber(lsb * 1000000), 'μV'),
    ToolResult('量化误差', formatNumber(lsb * 500), 'mV'),
    ToolResult('码数', formatNumber(codes), ''),
    ToolResult('最大码值', formatNumber(maxCode), ''),
    ToolResult('动态范围', formatNumber(dynamicRange), 'dB'),
    ToolResult('满量程', formatNumber(vref), 'V'),
    if (inputVoltage != null)
      ToolResult('输入电压', formatNumber(inputVoltage), 'V'),
    if (roundedCode != null) ToolResult('理想码值', formatNumber(roundedCode), ''),
    if (reconstructedVoltage != null)
      ToolResult('码值对应电压', formatNumber(reconstructedVoltage), 'V'),
    if (quantizationError != null)
      ToolResult('输入量化误差', formatNumber(quantizationError * 1000), 'mV'),
    if (inputVoltage != null)
      ToolResult(
          '输入状态', inputVoltage < 0 || inputVoltage > vref ? '超量程' : '有效', ''),
    if (enob != null) ToolResult('ENOB', formatNumber(enob), 'bit'),
    if (enobLsb != null)
      ToolResult('ENOB LSB', formatNumber(enobLsb * 1000), 'mV'),
    if (enob != null)
      ToolResult('ENOB动态范围', formatNumber(enob * 6.02 + 1.76), 'dB'),
  ];
}

List<ToolResult> _invalidAdcResolutionResults({
  required bool includeInput,
  required bool includeEnob,
}) {
  return [
    const ToolResult('LSB', '无效', 'mV', primary: true),
    const ToolResult('LSB', '无效', 'μV'),
    const ToolResult('量化误差', '无效', 'mV'),
    const ToolResult('码数', '无效', ''),
    const ToolResult('最大码值', '无效', ''),
    const ToolResult('动态范围', '无效', 'dB'),
    const ToolResult('满量程', '无效', 'V'),
    if (includeInput) const ToolResult('输入电压', '无效', 'V'),
    if (includeInput) const ToolResult('理想码值', '无效', ''),
    if (includeInput) const ToolResult('码值对应电压', '无效', 'V'),
    if (includeInput) const ToolResult('输入量化误差', '无效', 'mV'),
    if (includeInput) const ToolResult('输入状态', '无效', ''),
    if (includeEnob) const ToolResult('ENOB', '无效', 'bit'),
    if (includeEnob) const ToolResult('ENOB LSB', '无效', 'mV'),
    if (includeEnob) const ToolResult('ENOB动态范围', '无效', 'dB'),
  ];
}

List<ToolResult> rmsPeakResults(Map<String, double> valuesByKey) {
  final vrmsInput = valuesByKey['vrms'];
  final vpeakInput = valuesByKey['vpeak'];
  final vppInput = valuesByKey['vpp'];
  final dbmInput = valuesByKey['dbm50'];
  if ((vrmsInput != null && (vrmsInput < 0 || !vrmsInput.isFinite)) ||
      (vpeakInput != null && (vpeakInput < 0 || !vpeakInput.isFinite)) ||
      (vppInput != null && (vppInput < 0 || !vppInput.isFinite)) ||
      (dbmInput != null && !dbmInput.isFinite)) {
    return _invalidRmsPeakResults();
  }

  double vrms;
  String source;
  if (vrmsInput != null) {
    vrms = vrmsInput;
    source = _referenceSource('Vrms', [
      if (vpeakInput != null) 'Vpeak',
      if (vppInput != null) 'Vpp',
      if (dbmInput != null) '50Ω dBm',
    ]);
  } else if (vpeakInput != null) {
    vrms = vpeakInput / math.sqrt2;
    source = _referenceSource('Vpeak', [
      if (vppInput != null) 'Vpp',
      if (dbmInput != null) '50Ω dBm',
    ]);
  } else if (vppInput != null) {
    vrms = vppInput / (2 * math.sqrt2);
    source = _referenceSource('Vpp', [
      if (dbmInput != null) '50Ω dBm',
    ]);
  } else if (dbmInput != null) {
    final mw = math.pow(10, dbmInput / 10).toDouble();
    vrms = math.sqrt(mw / 1000 * 50);
    source = '50Ω dBm';
  } else {
    return _invalidRmsPeakResults();
  }

  final vpeak = vrms * math.sqrt2;
  final vpp = vpeak * 2;
  final averageRectified = 2 * vpeak / math.pi;
  final power50W = vrms * vrms / 50;
  final power50Mw = power50W * 1000;
  final dbv = vrms > 0 ? formatNumber(20 * math.log(vrms) / math.ln10) : '无效';
  final dbu =
      vrms > 0 ? formatNumber(20 * math.log(vrms / 0.775) / math.ln10) : '无效';
  final dbm50 =
      power50Mw > 0 ? formatNumber(10 * math.log(power50Mw) / math.ln10) : '无效';
  return [
    ToolResult('Vpeak', formatNumber(vpeak), 'V', primary: true),
    ToolResult('Vpp', formatNumber(vpp), 'V'),
    ToolResult('Vrms', formatNumber(vrms), 'V'),
    ToolResult('Vp-p/2', formatNumber(vpeak), 'V'),
    const ToolResult('峰值系数', '1.414214', ''),
    ToolResult('平均整流值', formatNumber(averageRectified), 'V'),
    ToolResult('50Ω 功率', formatNumber(power50Mw), 'mW'),
    ToolResult('50Ω dBm', dbm50, 'dBm'),
    ToolResult('dBV', dbv, 'dBV'),
    ToolResult('dBu', dbu, 'dBu'),
    ToolResult('输入来源', source, ''),
    if (vpeakInput != null)
      ToolResult('Vpeak差值', formatNumber(vpeak - vpeakInput), 'V'),
    if (vppInput != null)
      ToolResult('Vpp差值', formatNumber(vpp - vppInput), 'V'),
    if (dbmInput != null && dbm50 != '无效')
      ToolResult(
          '50Ω dBm差值', formatNumber(double.parse(dbm50) - dbmInput), 'dB'),
  ];
}

List<ToolResult> _invalidRmsPeakResults() {
  return const [
    ToolResult('Vpeak', '无效', 'V', primary: true),
    ToolResult('Vpp', '无效', 'V'),
    ToolResult('Vrms', '无效', 'V'),
    ToolResult('Vp-p/2', '无效', 'V'),
    ToolResult('峰值系数', '无效', ''),
    ToolResult('平均整流值', '无效', 'V'),
    ToolResult('50Ω 功率', '无效', 'mW'),
    ToolResult('50Ω dBm', '无效', 'dBm'),
    ToolResult('dBV', '无效', 'dBV'),
    ToolResult('dBu', '无效', 'dBu'),
    ToolResult('输入来源', '无效', ''),
  ];
}

List<ToolResult> lcResonanceResults(Map<String, double> valuesByKey) {
  final lInput = valuesByKey['l'] ?? 0;
  final cInput = valuesByKey['c'] ?? 0;
  final esrInput = valuesByKey['esr'];
  final l = lInput * 1e-6;
  final c = cInput * 1e-9;
  if (l <= 0 ||
      c <= 0 ||
      !lInput.isFinite ||
      !cInput.isFinite ||
      (esrInput != null && (esrInput < 0 || !esrInput.isFinite))) {
    return _invalidLcResonanceResults();
  }
  final f = 1 / (2 * math.pi * math.sqrt(l * c));
  final omega = 2 * math.pi * f;
  final reactance = omega * l;
  final esr = esrInput ?? 0;
  final q = esr > 0 ? reactance / esr : double.infinity;
  final bandwidth = q.isFinite && q > 0 ? f / q : double.infinity;
  final lowerHalfPower = bandwidth.isFinite ? f - bandwidth / 2 : double.nan;
  final upperHalfPower = bandwidth.isFinite ? f + bandwidth / 2 : double.nan;
  return [
    ToolResult('谐振频率', formatNumber(f), 'Hz', primary: true),
    ToolResult('谐振频率', formatNumber(f / 1000), 'kHz'),
    ToolResult('谐振频率', formatNumber(f / 1000000), 'MHz'),
    ToolResult('角频率 ω0', formatNumber(omega), 'rad/s'),
    ToolResult('周期', formatNumber(1 / f * 1000000), 'μs'),
    ToolResult('谐振感抗 XL', formatNumber(reactance), 'Ω'),
    ToolResult('谐振容抗 XC', formatNumber(reactance), 'Ω'),
    ToolResult('ESR', formatNumber(esr), 'Ω'),
    ToolResult('Q值(串联)', q.isInfinite ? '无穷大' : formatNumber(q), ''),
    ToolResult(
        '3dB带宽', bandwidth.isInfinite ? '无效' : formatNumber(bandwidth), 'Hz'),
    ToolResult('下半功率点',
        lowerHalfPower.isFinite ? formatNumber(lowerHalfPower) : '无效', 'Hz'),
    ToolResult('上半功率点',
        upperHalfPower.isFinite ? formatNumber(upperHalfPower) : '无效', 'Hz'),
  ];
}

List<ToolResult> _invalidLcResonanceResults() {
  return const [
    ToolResult('谐振频率', '无效', 'Hz', primary: true),
    ToolResult('谐振频率', '无效', 'kHz'),
    ToolResult('谐振频率', '无效', 'MHz'),
    ToolResult('角频率 ω0', '无效', 'rad/s'),
    ToolResult('周期', '无效', 'μs'),
    ToolResult('谐振感抗 XL', '无效', 'Ω'),
    ToolResult('谐振容抗 XC', '无效', 'Ω'),
    ToolResult('ESR', '无效', 'Ω'),
    ToolResult('Q值(串联)', '无效', ''),
    ToolResult('3dB带宽', '无效', 'Hz'),
    ToolResult('下半功率点', '无效', 'Hz'),
    ToolResult('上半功率点', '无效', 'Hz'),
  ];
}

String _referenceSource(String source, List<String> references) {
  if (references.isEmpty) return source;
  return '$source，${references.join('、')}作参考';
}

List<ToolResult> timer555Results(Map<String, double> valuesByKey) {
  final ra = (valuesByKey['ra'] ?? 0) * 1000;
  final rb = (valuesByKey['rb'] ?? 0) * 1000;
  final capacitance = (valuesByKey['c'] ?? 0) * 1e-6;
  final targetFrequency = valuesByKey['targetFrequency'];
  final targetDuty = valuesByKey['targetDuty'];
  final includeTarget = targetFrequency != null || targetDuty != null;
  if (ra <= 0 ||
      rb <= 0 ||
      capacitance <= 0 ||
      !ra.isFinite ||
      !rb.isFinite ||
      !capacitance.isFinite) {
    return _invalidTimer555Results(includeTarget: includeTarget);
  }

  final high = _timer555Coefficient * (ra + rb) * capacitance;
  final low = _timer555Coefficient * rb * capacitance;
  final period = high + low;
  final frequency = 1 / period;
  final duty = high / period * 100;
  final targetFrequencyValue = targetFrequency ?? frequency;
  final targetDutyValue = targetDuty ?? duty;
  final targetIsValid = targetFrequencyValue > 0 &&
      targetFrequencyValue.isFinite &&
      targetDutyValue > 50 &&
      targetDutyValue < 100 &&
      targetDutyValue.isFinite;
  final targetPeriod = targetIsValid ? 1 / targetFrequencyValue : null;
  final targetDutyRatio = targetDutyValue / 100;
  final targetScale = targetPeriod == null
      ? null
      : targetPeriod / (_timer555Coefficient * capacitance);
  final targetRb =
      targetScale == null ? null : targetScale * (1 - targetDutyRatio);
  final targetRa =
      targetScale == null ? null : targetScale * (2 * targetDutyRatio - 1);

  return [
    ToolResult('频率', formatNumber(frequency), 'Hz', primary: true),
    ToolResult('频率', formatNumber(frequency / 1000), 'kHz'),
    ToolResult('周期', formatNumber(period * 1000), 'ms'),
    ToolResult('高电平时间', formatNumber(high * 1000), 'ms'),
    ToolResult('低电平时间', formatNumber(low * 1000), 'ms'),
    ToolResult('占空比', formatNumber(duty), '%'),
    if (includeTarget)
      ToolResult('目标频率',
          targetIsValid ? formatNumber(targetFrequencyValue) : '无效', 'Hz'),
    if (includeTarget)
      ToolResult(
          '目标周期',
          targetPeriod == null ? '无效' : formatNumber(targetPeriod * 1000),
          'ms'),
    if (includeTarget)
      ToolResult(
          '目标占空比', targetIsValid ? formatNumber(targetDutyValue) : '无效', '%'),
    if (targetFrequency != null)
      ToolResult(
          '频率偏差',
          targetIsValid ? formatNumber(frequency - targetFrequency) : '无效',
          'Hz'),
    if (targetDuty != null)
      ToolResult(
          '占空比偏差', targetIsValid ? formatNumber(duty - targetDuty) : '无效', '%'),
    if (includeTarget)
      ToolResult('目标RA',
          targetRa == null ? '无效' : formatNumber(targetRa / 1000), 'kΩ'),
    if (includeTarget)
      ToolResult('目标RB',
          targetRb == null ? '无效' : formatNumber(targetRb / 1000), 'kΩ'),
    if (includeTarget)
      ToolResult(
          '目标高电平时间',
          targetPeriod == null
              ? '无效'
              : formatNumber(targetPeriod * targetDutyRatio * 1000),
          'ms'),
    if (includeTarget)
      ToolResult(
          '目标低电平时间',
          targetPeriod == null
              ? '无效'
              : formatNumber(targetPeriod * (1 - targetDutyRatio) * 1000),
          'ms'),
  ];
}

List<ToolResult> _invalidTimer555Results({required bool includeTarget}) {
  return [
    const ToolResult('频率', '无效', 'Hz', primary: true),
    const ToolResult('频率', '无效', 'kHz'),
    const ToolResult('周期', '无效', 'ms'),
    const ToolResult('高电平时间', '无效', 'ms'),
    const ToolResult('低电平时间', '无效', 'ms'),
    const ToolResult('占空比', '无效', '%'),
    if (includeTarget) const ToolResult('目标频率', '无效', 'Hz'),
    if (includeTarget) const ToolResult('目标周期', '无效', 'ms'),
    if (includeTarget) const ToolResult('目标占空比', '无效', '%'),
    if (includeTarget) const ToolResult('频率偏差', '无效', 'Hz'),
    if (includeTarget) const ToolResult('占空比偏差', '无效', '%'),
    if (includeTarget) const ToolResult('目标RA', '无效', 'kΩ'),
    if (includeTarget) const ToolResult('目标RB', '无效', 'kΩ'),
    if (includeTarget) const ToolResult('目标高电平时间', '无效', 'ms'),
    if (includeTarget) const ToolResult('目标低电平时间', '无效', 'ms'),
  ];
}

List<ToolResult> capacitorChargeResults(Map<String, double> valuesByKey) {
  final vin = valuesByKey['vin'] ?? 0;
  final initialVoltage = valuesByKey['initialVoltage'] ?? 0;
  final resistance = (valuesByKey['r'] ?? 0) * 1000;
  final capacitance = (valuesByKey['c'] ?? 0) * 1e-6;
  final time = valuesByKey['time'] ?? 0;
  final targetVoltage = valuesByKey['targetVoltage'];
  final targetRatio = valuesByKey['targetRatio'];
  final includeTargetVoltage = targetVoltage != null;
  final includeTargetRatio = targetRatio != null;
  if (resistance <= 0 ||
      capacitance <= 0 ||
      time < 0 ||
      !vin.isFinite ||
      !initialVoltage.isFinite ||
      !resistance.isFinite ||
      !capacitance.isFinite ||
      !time.isFinite ||
      (targetVoltage != null && !targetVoltage.isFinite) ||
      (targetRatio != null &&
          (targetRatio < 0 || targetRatio > 100 || !targetRatio.isFinite))) {
    return _invalidCapacitorChargeResults(
      includeTargetVoltage: includeTargetVoltage,
      includeTargetRatio: includeTargetRatio,
    );
  }

  final tau = resistance * capacitance;
  final decay = math.exp(-time / tau);
  final voltage = vin + (initialVoltage - vin) * decay;
  final chargeRatio = _progressRatio(
    initial: initialVoltage,
    target: vin,
    value: voltage,
  );
  final idealChargeVoltage = vin * (1 - decay);
  final dischargeVoltage = initialVoltage == 0 ? vin * decay : voltage;
  final remainingDelta = vin - voltage;
  final initialCurrent = (vin - initialVoltage) / resistance;
  final current = initialCurrent * decay;
  final charge = capacitance * voltage;
  final energy = 0.5 * capacitance * voltage * voltage;
  final targetVoltageTime = targetVoltage == null
      ? null
      : _timeToVoltage(
          source: initialVoltage,
          target: vin,
          voltage: targetVoltage,
          tau: tau,
        );
  final targetRatioVoltage = targetRatio == null
      ? null
      : initialVoltage + (vin - initialVoltage) * targetRatio / 100;
  final targetRatioTime = targetRatioVoltage == null
      ? null
      : _timeToVoltage(
          source: initialVoltage,
          target: vin,
          voltage: targetRatioVoltage,
          tau: tau,
        );

  return [
    ToolResult('电容电压', formatNumber(voltage), 'V', primary: true),
    ToolResult('充电比例', formatNumber(chargeRatio), '%'),
    ToolResult('放电电压', formatNumber(dischargeVoltage), 'V'),
    ToolResult('理想充电电压', formatNumber(idealChargeVoltage), 'V'),
    ToolResult('剩余压差', formatNumber(remainingDelta), 'V'),
    ToolResult('初始电压', formatNumber(initialVoltage), 'V'),
    ToolResult('时间常数 τ', formatNumber(tau), 's'),
    ToolResult('半充时间', formatNumber(tau * math.ln2), 's'),
    ToolResult('90% 时间', formatNumber(tau * math.ln10), 's'),
    ToolResult('约 99% 时间', formatNumber(tau * 5), 's'),
    ToolResult('初始电流', formatNumber(initialCurrent * 1000), 'mA'),
    ToolResult('当前电流', formatNumber(current * 1000), 'mA'),
    ToolResult('电荷', formatNumber(charge * 1000), 'mC'),
    ToolResult('储能', formatNumber(energy * 1000), 'mJ'),
    if (targetVoltage != null)
      ToolResult('目标电压', formatNumber(targetVoltage), 'V'),
    if (targetVoltageTime != null)
      ToolResult('目标电压时间', _formatOptionalTime(targetVoltageTime), 's'),
    if (targetVoltage != null)
      ToolResult('目标电压差', formatNumber(voltage - targetVoltage), 'V'),
    if (targetRatio != null)
      ToolResult('目标充电比例', formatNumber(targetRatio), '%'),
    if (targetRatioVoltage != null)
      ToolResult('目标比例电压', formatNumber(targetRatioVoltage), 'V'),
    if (targetRatioTime != null)
      ToolResult('目标比例时间', _formatOptionalTime(targetRatioTime), 's'),
  ];
}

double _progressRatio({
  required double initial,
  required double target,
  required double value,
}) {
  final span = target - initial;
  if (span == 0) return value == target ? 100 : double.nan;
  return (value - initial) / span * 100;
}

double? _timeToVoltage({
  required double source,
  required double target,
  required double voltage,
  required double tau,
}) {
  final span = source - target;
  if (span == 0) return voltage == target ? 0 : null;
  final ratio = (voltage - target) / span;
  if (ratio <= 0 || ratio > 1) return null;
  return -tau * math.log(ratio);
}

String _formatOptionalTime(double? value) {
  return value == null ? '无效' : formatNumber(value);
}

List<ToolResult> _invalidCapacitorChargeResults({
  required bool includeTargetVoltage,
  required bool includeTargetRatio,
}) {
  return [
    const ToolResult('电容电压', '无效', 'V', primary: true),
    const ToolResult('充电比例', '无效', '%'),
    const ToolResult('放电电压', '无效', 'V'),
    const ToolResult('理想充电电压', '无效', 'V'),
    const ToolResult('剩余压差', '无效', 'V'),
    const ToolResult('初始电压', '无效', 'V'),
    const ToolResult('时间常数 τ', '无效', 's'),
    const ToolResult('半充时间', '无效', 's'),
    const ToolResult('90% 时间', '无效', 's'),
    const ToolResult('约 99% 时间', '无效', 's'),
    const ToolResult('初始电流', '无效', 'mA'),
    const ToolResult('当前电流', '无效', 'mA'),
    const ToolResult('电荷', '无效', 'mC'),
    const ToolResult('储能', '无效', 'mJ'),
    if (includeTargetVoltage) const ToolResult('目标电压', '无效', 'V'),
    if (includeTargetVoltage) const ToolResult('目标电压时间', '无效', 's'),
    if (includeTargetVoltage) const ToolResult('目标电压差', '无效', 'V'),
    if (includeTargetRatio) const ToolResult('目标充电比例', '无效', '%'),
    if (includeTargetRatio) const ToolResult('目标比例电压', '无效', 'V'),
    if (includeTargetRatio) const ToolResult('目标比例时间', '无效', 's'),
  ];
}
