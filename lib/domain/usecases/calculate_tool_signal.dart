import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

const double _timer555Coefficient = 0.693;

List<ToolResult> dbmResults(Map<String, double> valuesByKey) {
  final dbm = valuesByKey['dbm'] ?? 0;
  if (!dbm.isFinite) {
    return const [
      ToolResult.invalid('功率', 'mW', primary: true),
      ToolResult.invalid('微瓦', 'μW'),
      ToolResult.invalid('瓦特', 'W'),
      ToolResult.invalid('dBW', 'dBW'),
      ToolResult.invalid('50Ω Vrms', 'V'),
      ToolResult.invalid('50Ω Vpeak', 'V'),
      ToolResult.invalid('50Ω Vpp', 'V'),
      ToolResult.invalid('50Ω dBV', 'dBV'),
      ToolResult.invalid('50Ω dBu', 'dBu'),
    ];
  }

  final mw = math.pow(10, dbm / 10).toDouble();
  final watts = mw / 1000;
  final vrms50 = math.sqrt(watts * 50);
  final vpeak50 = vrms50 * math.sqrt2;
  // 中文：**两个分贝值先算成数。** 条件不成立那一支产出方明确说算不出来（`null`）。
  // English: **both decibel figures are computed as numbers first.** The branch where the condition
  //          fails is the producer saying plainly that it cannot be produced (`null`).
  final dbv = vrms50 > 0 ? 20 * math.log(vrms50) / math.ln10 : null;
  final dbu = vrms50 > 0 ? 20 * math.log(vrms50 / 0.775) / math.ln10 : null;
  return [
    ToolResult.number('功率', mw, 'mW', primary: true),
    ToolResult.number('微瓦', mw * 1000, 'μW'),
    ToolResult.number('瓦特', watts, 'W'),
    ToolResult.number('dBW', dbm - 30, 'dBW'),
    ToolResult.number('50Ω Vrms', vrms50, 'V'),
    ToolResult.number('50Ω Vpeak', vpeak50, 'V'),
    ToolResult.number('50Ω Vpp', vpeak50 * 2, 'V'),
    ToolResult.number('50Ω dBV', dbv, 'dBV'),
    ToolResult.number('50Ω dBu', dbu, 'dBu'),
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
    ToolResult.number('截止频率 fc', cutoff, 'Hz', primary: true),
    ToolResult.number('截止频率', cutoff / 1000, 'kHz'),
    ToolResult.number('时间常数 τ', tau * 1000, 'ms'),
    ToolResult.number('等效周期', 1 / cutoff * 1000, 'ms'),
    ToolResult.number('0.1fc', cutoff / 10, 'Hz'),
    ToolResult.number('10fc', cutoff * 10, 'Hz'),
    ToolResult.number('100fc', cutoff * 100, 'Hz'),
    _rangeResult('fc范围', low, high, 'Hz'),
    if (includeTarget) ToolResult.number('目标截止频率', targetCutoff, 'Hz'),
    if (includeTarget) ToolResult.number('频率偏差', cutoff - targetCutoff, 'Hz'),
    if (targetResistance != null)
      ToolResult.number('保留C所需R', targetResistance / 1000, 'kΩ'),
    if (targetCapacitance != null)
      ToolResult.number('保留R所需C', targetCapacitance * 1e9, 'nF'),
    if (targetTau != null)
      ToolResult.number('目标时间常数 τ', targetTau * 1000, 'ms'),
  ];
}

List<ToolResult> _invalidRcFilterResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('截止频率 fc', 'Hz', primary: true),
    const ToolResult.invalid('截止频率', 'kHz'),
    const ToolResult.invalid('时间常数 τ', 'ms'),
    const ToolResult.invalid('等效周期', 'ms'),
    const ToolResult.invalid('0.1fc', 'Hz'),
    const ToolResult.invalid('10fc', 'Hz'),
    const ToolResult.invalid('100fc', 'Hz'),
    const ToolResult.invalid('fc范围', 'Hz'),
    if (includeTarget) const ToolResult.invalid('目标截止频率', 'Hz'),
    if (includeTarget) const ToolResult.invalid('频率偏差', 'Hz'),
    if (includeTarget) const ToolResult.invalid('保留C所需R', 'kΩ'),
    if (includeTarget) const ToolResult.invalid('保留R所需C', 'nF'),
    if (includeTarget) const ToolResult.invalid('目标时间常数 τ', 'ms'),
  ];
}

/// 中文：**一条「范围」结果。** 错误状态由两个端点本身决定，不由 [ _formatRange ] 那句话决定。
/// English: **One "range" result.** The error state is decided by the two endpoints themselves, not
///          by the sentence [_formatRange] builds.
ToolResult _rangeResult(String label, double a, double b, String unit,
    {bool primary = false}) {
  return ToolResult(label, _formatRange(a, b), unit,
      primary: primary, hasError: !a.isFinite || !b.isFinite);
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
    ToolResult.number('同相增益', nonInvertingGain, '倍', primary: true),
    ToolResult.number('反相增益', invertingGain, '倍'),
    ToolResult.number(
        '同相增益 dB', 20 * math.log(nonInvertingGain) / math.ln10, 'dB'),
    ToolResult.number(
        '反相增益 dB', ratio == 0 ? null : 20 * math.log(ratio) / math.ln10, 'dB'),
    ToolResult.number('同相输出', vin * nonInvertingGain, 'V'),
    ToolResult.number('反相输出', vin * invertingGain, 'V'),
    ToolResult.number('电阻比 Rf/Rin', ratio, ''),
    ToolResult.number('反馈系数 β', feedbackFactor, ''),
    ToolResult.number('反相输入阻抗', rin, 'kΩ'),
    ToolResult.number('反馈总阻值', feedbackTotal, 'kΩ'),
    if (includeTarget) ToolResult.number('目标同相增益', targetGain, '倍'),
    if (includeTarget)
      ToolResult.number(
          '目标所需Rf', targetRf != null && targetRf >= 0 ? targetRf : null, 'kΩ'),
    if (includeTarget)
      ToolResult.number('保留Rf所需Rin',
          targetRin != null && targetRin > 0 ? targetRin : null, 'kΩ'),
    if (includeTarget)
      ToolResult.number(
          '反相目标所需Rf',
          targetInvertingRf != null && targetInvertingRf >= 0
              ? targetInvertingRf
              : null,
          'kΩ'),
    if (closedLoopBandwidth != null)
      ToolResult.number('同相闭环带宽', closedLoopBandwidth, 'Hz'),
    if (invertingBandwidth != null)
      ToolResult.number('反相闭环带宽', invertingBandwidth, 'Hz'),
    if (slewRate != null) ToolResult.number('所需压摆率', slewRate, 'V/μs'),
  ];
}

List<ToolResult> _invalidOpAmpGainResults({
  required bool includeTarget,
  required bool includeBandwidth,
  required bool includeSlewRate,
}) {
  return [
    const ToolResult.invalid('同相增益', '倍', primary: true),
    const ToolResult.invalid('反相增益', '倍'),
    const ToolResult.invalid('同相增益 dB', 'dB'),
    const ToolResult.invalid('反相增益 dB', 'dB'),
    const ToolResult.invalid('同相输出', 'V'),
    const ToolResult.invalid('反相输出', 'V'),
    const ToolResult.invalid('电阻比 Rf/Rin', ''),
    const ToolResult.invalid('反馈系数 β', ''),
    const ToolResult.invalid('反相输入阻抗', 'kΩ'),
    const ToolResult.invalid('反馈总阻值', 'kΩ'),
    if (includeTarget) const ToolResult.invalid('目标同相增益', '倍'),
    if (includeTarget) const ToolResult.invalid('目标所需Rf', 'kΩ'),
    if (includeTarget) const ToolResult.invalid('保留Rf所需Rin', 'kΩ'),
    if (includeTarget) const ToolResult.invalid('反相目标所需Rf', 'kΩ'),
    if (includeBandwidth) const ToolResult.invalid('同相闭环带宽', 'Hz'),
    if (includeBandwidth) const ToolResult.invalid('反相闭环带宽', 'Hz'),
    if (includeSlewRate) const ToolResult.invalid('所需压摆率', 'V/μs'),
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
    ToolResult.number('LSB', lsb * 1000, 'mV', primary: true),
    ToolResult.number('LSB', lsb * 1000000, 'μV'),
    ToolResult.number('量化误差', lsb * 500, 'mV'),
    ToolResult.number('码数', codes, ''),
    ToolResult.number('最大码值', maxCode, ''),
    ToolResult.number('动态范围', dynamicRange, 'dB'),
    ToolResult.number('满量程', vref, 'V'),
    if (inputVoltage != null) ToolResult.number('输入电压', inputVoltage, 'V'),
    if (roundedCode != null) ToolResult.number('理想码值', roundedCode, ''),
    if (reconstructedVoltage != null)
      ToolResult.number('码值对应电压', reconstructedVoltage, 'V'),
    if (quantizationError != null)
      ToolResult.number('输入量化误差', quantizationError * 1000, 'mV'),
    // 中文：**这一格被下游判据读过**（`tool_insights_electronics.dart` 问 `inputState == '超量程'`）：
    //       结论那一支的值从枚举来、令牌一起写下；`'有效'` 没有被任何判据读过，是普通字面量。
    // English: **a downstream judgement reads this cell** (`tool_insights_electronics.dart` asks
    //          `inputState == '超量程'`): the conclusion branch's value comes from the enum with the
    //          token written alongside; `'有效'` is read by no judgement and stays an ordinary literal.
    if (inputVoltage != null)
      ToolResult(
        '输入状态',
        inputVoltage < 0 || inputVoltage > vref
            ? ToolResultConclusion.overRange.sentence
            : '有效',
        '',
        conclusion: inputVoltage < 0 || inputVoltage > vref
            ? ToolResultConclusion.overRange
            : null,
      ),
    if (enob != null) ToolResult.number('ENOB', enob, 'bit'),
    if (enobLsb != null) ToolResult.number('ENOB LSB', enobLsb * 1000, 'mV'),
    if (enob != null) ToolResult.number('ENOB动态范围', enob * 6.02 + 1.76, 'dB'),
  ];
}

List<ToolResult> _invalidAdcResolutionResults({
  required bool includeInput,
  required bool includeEnob,
}) {
  return [
    const ToolResult.invalid('LSB', 'mV', primary: true),
    const ToolResult.invalid('LSB', 'μV'),
    const ToolResult.invalid('量化误差', 'mV'),
    const ToolResult.invalid('码数', ''),
    const ToolResult.invalid('最大码值', ''),
    const ToolResult.invalid('动态范围', 'dB'),
    const ToolResult.invalid('满量程', 'V'),
    if (includeInput) const ToolResult.invalid('输入电压', 'V'),
    if (includeInput) const ToolResult.invalid('理想码值', ''),
    if (includeInput) const ToolResult.invalid('码值对应电压', 'V'),
    if (includeInput) const ToolResult.invalid('输入量化误差', 'mV'),
    if (includeInput) const ToolResult.invalid('输入状态', ''),
    if (includeEnob) const ToolResult.invalid('ENOB', 'bit'),
    if (includeEnob) const ToolResult.invalid('ENOB LSB', 'mV'),
    if (includeEnob) const ToolResult.invalid('ENOB动态范围', 'dB'),
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
  // 中文：**三个分贝值先算成数。** 条件不成立那一支产出方明确说算不出来（`null`）。
  // English: **the three decibel figures are computed as numbers first.** The branch where the
  //          condition fails is the producer saying plainly that it cannot be produced (`null`).
  final dbv = vrms > 0 ? 20 * math.log(vrms) / math.ln10 : null;
  final dbu = vrms > 0 ? 20 * math.log(vrms / 0.775) / math.ln10 : null;
  final dbm50 = power50Mw > 0 ? 10 * math.log(power50Mw) / math.ln10 : null;
  return [
    ToolResult.number('Vpeak', vpeak, 'V', primary: true),
    ToolResult.number('Vpp', vpp, 'V'),
    ToolResult.number('Vrms', vrms, 'V'),
    ToolResult.number('Vp-p/2', vpeak, 'V'),
    const ToolResult('峰值系数', '1.414214', ''),
    ToolResult.number('平均整流值', averageRectified, 'V'),
    ToolResult.number('50Ω 功率', power50Mw, 'mW'),
    ToolResult.number('50Ω dBm', dbm50, 'dBm'),
    ToolResult.number('dBV', dbv, 'dBV'),
    ToolResult.number('dBu', dbu, 'dBu'),
    ToolResult('输入来源', source, ''),
    if (vpeakInput != null)
      ToolResult.number('Vpeak差值', vpeak - vpeakInput, 'V'),
    if (vppInput != null) ToolResult.number('Vpp差值', vpp - vppInput, 'V'),
    // 中文：**这里从前比的是那句话。** `dbm50 != '无效'` 外加 `double.parse(dbm50)`——
    //       判据与取值都从用户看得见的那句话里回读。现在看的是数本身。
    // English: **this used to compare the sentence.** `dbm50 != '无效'` plus `double.parse(dbm50)` —
    //          both the condition and the value were read back out of what the user sees. It now
    //          looks at the number itself.
    // 中文：**保留那次格式化往返**——旧代码是 `double.parse(dbm50)`，而 `dbm50` 当初是
    //       `formatNumber(...)` 出来的六位有效数字。直接相减会差一个舍入，屏幕上的数会变。
    // English: **the formatting round-trip is kept** — the old code was `double.parse(dbm50)`, and
    //          `dbm50` was the six-significant-digit output of `formatNumber(...)`. Subtracting
    //          directly would differ by one rounding step and the figure on screen would move.
    if (dbmInput != null && dbm50 != null && dbm50.isFinite)
      ToolResult.number(
          '50Ω dBm差值', double.parse(formatNumber(dbm50)) - dbmInput, 'dB'),
  ];
}

List<ToolResult> _invalidRmsPeakResults() {
  return const [
    ToolResult.invalid('Vpeak', 'V', primary: true),
    ToolResult.invalid('Vpp', 'V'),
    ToolResult.invalid('Vrms', 'V'),
    ToolResult.invalid('Vp-p/2', 'V'),
    ToolResult.invalid('峰值系数', ''),
    ToolResult.invalid('平均整流值', 'V'),
    ToolResult.invalid('50Ω 功率', 'mW'),
    ToolResult.invalid('50Ω dBm', 'dBm'),
    ToolResult.invalid('dBV', 'dBV'),
    ToolResult.invalid('dBu', 'dBu'),
    ToolResult.invalid('输入来源', ''),
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
    ToolResult.number('谐振频率', f, 'Hz', primary: true),
    ToolResult.number('谐振频率', f / 1000, 'kHz'),
    ToolResult.number('谐振频率', f / 1000000, 'MHz'),
    ToolResult.number('角频率 ω0', omega, 'rad/s'),
    ToolResult.number('周期', 1 / f * 1000000, 'μs'),
    ToolResult.number('谐振感抗 XL', reactance, 'Ω'),
    ToolResult.number('谐振容抗 XC', reactance, 'Ω'),
    ToolResult.number('ESR', esr, 'Ω'),
    // 中文：`无穷大` 今天不算错误（旧判据的词表里没有它），旗标照旧为假。
    //       这一格没有被下游判据读过，但值就是那条结论那句话，所以照样从枚举取——
    //       那句话在源码里因此只有一份（`ToolResultConclusion.infinite`）。
    // English: `无穷大` is not an error today (it is not in the old predicate's word list) and the
    //          flag stays false. No downstream judgement reads this cell, but the value is that
    //          conclusion's sentence, so it comes from the enum all the same — leaving the sentence in
    //          exactly one place in the source (`ToolResultConclusion.infinite`).
    ToolResult(
      'Q值(串联)',
      q.isInfinite
          ? ToolResultConclusion.infinite.sentence
          : formatNumber(q),
      '',
      conclusion: q.isInfinite ? ToolResultConclusion.infinite : null,
    ),
    ToolResult.number('3dB带宽', bandwidth.isInfinite ? null : bandwidth, 'Hz'),
    ToolResult.number(
        '下半功率点', lowerHalfPower.isFinite ? lowerHalfPower : null, 'Hz'),
    ToolResult.number(
        '上半功率点', upperHalfPower.isFinite ? upperHalfPower : null, 'Hz'),
  ];
}

List<ToolResult> _invalidLcResonanceResults() {
  return const [
    ToolResult.invalid('谐振频率', 'Hz', primary: true),
    ToolResult.invalid('谐振频率', 'kHz'),
    ToolResult.invalid('谐振频率', 'MHz'),
    ToolResult.invalid('角频率 ω0', 'rad/s'),
    ToolResult.invalid('周期', 'μs'),
    ToolResult.invalid('谐振感抗 XL', 'Ω'),
    ToolResult.invalid('谐振容抗 XC', 'Ω'),
    ToolResult.invalid('ESR', 'Ω'),
    ToolResult.invalid('Q值(串联)', ''),
    ToolResult.invalid('3dB带宽', 'Hz'),
    ToolResult.invalid('下半功率点', 'Hz'),
    ToolResult.invalid('上半功率点', 'Hz'),
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
    ToolResult.number('频率', frequency, 'Hz', primary: true),
    ToolResult.number('频率', frequency / 1000, 'kHz'),
    ToolResult.number('周期', period * 1000, 'ms'),
    ToolResult.number('高电平时间', high * 1000, 'ms'),
    ToolResult.number('低电平时间', low * 1000, 'ms'),
    ToolResult.number('占空比', duty, '%'),
    if (includeTarget)
      ToolResult.number(
          '目标频率', targetIsValid ? targetFrequencyValue : null, 'Hz'),
    if (includeTarget)
      ToolResult.number(
          '目标周期', targetPeriod == null ? null : targetPeriod * 1000, 'ms'),
    if (includeTarget)
      ToolResult.number('目标占空比', targetIsValid ? targetDutyValue : null, '%'),
    if (targetFrequency != null)
      ToolResult.number(
          '频率偏差', targetIsValid ? frequency - targetFrequency : null, 'Hz'),
    if (targetDuty != null)
      ToolResult.number('占空比偏差', targetIsValid ? duty - targetDuty : null, '%'),
    if (includeTarget)
      ToolResult.number(
          '目标RA', targetRa == null ? null : targetRa / 1000, 'kΩ'),
    if (includeTarget)
      ToolResult.number(
          '目标RB', targetRb == null ? null : targetRb / 1000, 'kΩ'),
    if (includeTarget)
      ToolResult.number(
          '目标高电平时间',
          targetPeriod == null ? null : targetPeriod * targetDutyRatio * 1000,
          'ms'),
    if (includeTarget)
      ToolResult.number(
          '目标低电平时间',
          targetPeriod == null
              ? null
              : targetPeriod * (1 - targetDutyRatio) * 1000,
          'ms'),
  ];
}

List<ToolResult> _invalidTimer555Results({required bool includeTarget}) {
  return [
    const ToolResult.invalid('频率', 'Hz', primary: true),
    const ToolResult.invalid('频率', 'kHz'),
    const ToolResult.invalid('周期', 'ms'),
    const ToolResult.invalid('高电平时间', 'ms'),
    const ToolResult.invalid('低电平时间', 'ms'),
    const ToolResult.invalid('占空比', '%'),
    if (includeTarget) const ToolResult.invalid('目标频率', 'Hz'),
    if (includeTarget) const ToolResult.invalid('目标周期', 'ms'),
    if (includeTarget) const ToolResult.invalid('目标占空比', '%'),
    if (includeTarget) const ToolResult.invalid('频率偏差', 'Hz'),
    if (includeTarget) const ToolResult.invalid('占空比偏差', '%'),
    if (includeTarget) const ToolResult.invalid('目标RA', 'kΩ'),
    if (includeTarget) const ToolResult.invalid('目标RB', 'kΩ'),
    if (includeTarget) const ToolResult.invalid('目标高电平时间', 'ms'),
    if (includeTarget) const ToolResult.invalid('目标低电平时间', 'ms'),
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
    ToolResult.number('电容电压', voltage, 'V', primary: true),
    ToolResult.number('充电比例', chargeRatio, '%'),
    ToolResult.number('放电电压', dischargeVoltage, 'V'),
    ToolResult.number('理想充电电压', idealChargeVoltage, 'V'),
    ToolResult.number('剩余压差', remainingDelta, 'V'),
    ToolResult.number('初始电压', initialVoltage, 'V'),
    ToolResult.number('时间常数 τ', tau, 's'),
    ToolResult.number('半充时间', tau * math.ln2, 's'),
    ToolResult.number('90% 时间', tau * math.ln10, 's'),
    ToolResult.number('约 99% 时间', tau * 5, 's'),
    ToolResult.number('初始电流', initialCurrent * 1000, 'mA'),
    ToolResult.number('当前电流', current * 1000, 'mA'),
    ToolResult.number('电荷', charge * 1000, 'mC'),
    ToolResult.number('储能', energy * 1000, 'mJ'),
    if (targetVoltage != null) ToolResult.number('目标电压', targetVoltage, 'V'),
    if (targetVoltageTime != null)
      ToolResult('目标电压时间', _formatOptionalTime(targetVoltageTime), 's',
          hasError: !targetVoltageTime.isFinite),
    if (targetVoltage != null)
      ToolResult.number('目标电压差', voltage - targetVoltage, 'V'),
    if (targetRatio != null) ToolResult.number('目标充电比例', targetRatio, '%'),
    if (targetRatioVoltage != null)
      ToolResult.number('目标比例电压', targetRatioVoltage, 'V'),
    if (targetRatioTime != null)
      ToolResult('目标比例时间', _formatOptionalTime(targetRatioTime), 's',
          hasError: !targetRatioTime.isFinite),
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
  // 中文：`null` 那一支写下的就是**那条记号本身**（[invalidResultValue]，只有一处写法）。
  //       今天两个调用点都由 `!= null` 把住，所以这一支走不到；留着它是因为形状，而不是因为它
  //       常走——一旦有人解开那道门，写下的必须是**同一个词**，否则构造点的断言（它比的正是那个
  //       常量）与这里就会各说各话。
  // English: the `null` branch writes **the marker itself** ([invalidResultValue], spelled in one
  //          place). Both call sites are guarded by `!= null` today, so this branch is unreachable;
  //          it stays for its shape rather than its frequency — the moment somebody opens that door,
  //          the word written here has to be **the same one**, or this and the assertion at the
  //          construction point (which compares against that constant) say different things.
  return value == null ? invalidResultValue : formatNumber(value);
}

List<ToolResult> _invalidCapacitorChargeResults({
  required bool includeTargetVoltage,
  required bool includeTargetRatio,
}) {
  return [
    const ToolResult.invalid('电容电压', 'V', primary: true),
    const ToolResult.invalid('充电比例', '%'),
    const ToolResult.invalid('放电电压', 'V'),
    const ToolResult.invalid('理想充电电压', 'V'),
    const ToolResult.invalid('剩余压差', 'V'),
    const ToolResult.invalid('初始电压', 'V'),
    const ToolResult.invalid('时间常数 τ', 's'),
    const ToolResult.invalid('半充时间', 's'),
    const ToolResult.invalid('90% 时间', 's'),
    const ToolResult.invalid('约 99% 时间', 's'),
    const ToolResult.invalid('初始电流', 'mA'),
    const ToolResult.invalid('当前电流', 'mA'),
    const ToolResult.invalid('电荷', 'mC'),
    const ToolResult.invalid('储能', 'mJ'),
    if (includeTargetVoltage) const ToolResult.invalid('目标电压', 'V'),
    if (includeTargetVoltage) const ToolResult.invalid('目标电压时间', 's'),
    if (includeTargetVoltage) const ToolResult.invalid('目标电压差', 'V'),
    if (includeTargetRatio) const ToolResult.invalid('目标充电比例', '%'),
    if (includeTargetRatio) const ToolResult.invalid('目标比例电压', 'V'),
    if (includeTargetRatio) const ToolResult.invalid('目标比例时间', 's'),
  ];
}
