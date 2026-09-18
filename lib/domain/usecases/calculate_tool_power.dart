import 'dart:math' as math;

import '../entities/tool_definition.dart';

List<ToolResult> batteryLifeResults(Map<String, double> valuesByKey) {
  final capacity = valuesByKey['capacity'] ?? 0;
  final current = valuesByKey['current'] ?? 0;
  final voltage = valuesByKey['voltage'] ?? 0;
  final efficiency = valuesByKey['efficiency'] ?? 100;
  final targetHours = valuesByKey['targetHours'];
  final reservePercent = valuesByKey['reserve'] ?? 20;
  if (capacity <= 0 ||
      current <= 0 ||
      voltage <= 0 ||
      efficiency <= 0 ||
      efficiency > 100 ||
      reservePercent < 0 ||
      reservePercent >= 100 ||
      (targetHours != null && targetHours <= 0)) {
    return _invalidBatteryLifeResults(targetHours != null);
  }

  final eta = efficiency / 100;
  final reserveFactor = 1 - reservePercent / 100;
  final hours = capacity / current * eta;
  final usableHours = hours * reserveFactor;
  final nominalWh = capacity * voltage / 1000;
  final loadW = current * voltage / 1000;
  final equivalentBatteryCurrent = current / eta;
  final equivalentBatteryPower = loadW / eta;
  final cRate = equivalentBatteryCurrent / capacity;
  final requiredCapacity =
      targetHours == null ? null : targetHours * current / eta / reserveFactor;
  final allowedAverageCurrent =
      targetHours == null ? null : capacity * eta * reserveFactor / targetHours;
  final targetEnergy = targetHours == null ? null : targetHours * loadW;

  return [
    ToolResult.number('续航时间', hours, 'h', primary: true),
    ToolResult.number('天数', hours / 24, 'day'),
    ToolResult.number('留 20% 余量', hours * 0.8, 'h'),
    ToolResult.number('余量后续航', usableHours, 'h'),
    ToolResult.number('保留余量', reservePercent, '%'),
    ToolResult.number('可用容量', capacity * eta, 'mAh'),
    ToolResult.number('余量后容量', capacity * eta * reserveFactor, 'mAh'),
    ToolResult.number('标称能量', nominalWh, 'Wh'),
    ToolResult.number('可用能量', nominalWh * eta, 'Wh'),
    ToolResult.number('余量后能量', nominalWh * eta * reserveFactor, 'Wh'),
    ToolResult.number('负载功率', loadW, 'W'),
    ToolResult.number('等效电池电流', equivalentBatteryCurrent, 'mA'),
    ToolResult.number('等效电池功率', equivalentBatteryPower, 'W'),
    ToolResult.number('C倍率', cRate, 'C'),
    ToolResult.number('每小时消耗', 100 / hours, '%'),
    if (requiredCapacity != null)
      ToolResult.number('目标所需容量', requiredCapacity, 'mAh'),
    if (requiredCapacity != null)
      ToolResult.number('目标所需能量', requiredCapacity * voltage / 1000, 'Wh'),
    if (allowedAverageCurrent != null)
      ToolResult.number('目标允许电流', allowedAverageCurrent, 'mA'),
    if (targetEnergy != null) ToolResult.number('目标负载能量', targetEnergy, 'Wh'),
  ];
}

List<ToolResult> _invalidBatteryLifeResults(bool includeTarget) {
  return [
    const ToolResult.invalid('续航时间', 'h', primary: true),
    const ToolResult.invalid('天数', 'day'),
    const ToolResult.invalid('留 20% 余量', 'h'),
    const ToolResult.invalid('余量后续航', 'h'),
    const ToolResult.invalid('保留余量', '%'),
    const ToolResult.invalid('可用容量', 'mAh'),
    const ToolResult.invalid('余量后容量', 'mAh'),
    const ToolResult.invalid('标称能量', 'Wh'),
    const ToolResult.invalid('可用能量', 'Wh'),
    const ToolResult.invalid('余量后能量', 'Wh'),
    const ToolResult.invalid('负载功率', 'W'),
    const ToolResult.invalid('等效电池电流', 'mA'),
    const ToolResult.invalid('等效电池功率', 'W'),
    const ToolResult.invalid('C倍率', 'C'),
    const ToolResult.invalid('每小时消耗', '%'),
    if (includeTarget) const ToolResult.invalid('目标所需容量', 'mAh'),
    if (includeTarget) const ToolResult.invalid('目标所需能量', 'Wh'),
    if (includeTarget) const ToolResult.invalid('目标允许电流', 'mA'),
    if (includeTarget) const ToolResult.invalid('目标负载能量', 'Wh'),
  ];
}

List<ToolResult> pcbCurrentResults(Map<String, double> valuesByKey) {
  final widthMm = valuesByKey['width'] ?? 0;
  final copperOz = valuesByKey['copper'] ?? 0;
  final rise = valuesByKey['rise'] ?? 0;
  final targetCurrent = valuesByKey['targetCurrent'];
  final layerFactor = valuesByKey['layerFactor'] ?? 1;
  if (widthMm <= 0 ||
      copperOz <= 0 ||
      rise <= 0 ||
      layerFactor <= 0 ||
      !widthMm.isFinite ||
      !copperOz.isFinite ||
      !rise.isFinite ||
      !layerFactor.isFinite ||
      (targetCurrent != null &&
          (targetCurrent <= 0 || !targetCurrent.isFinite))) {
    return _invalidPcbCurrentResults(targetCurrent != null);
  }

  final widthMil = widthMm / 0.0254;
  final thicknessMil = copperOz * 1.378;
  final areaMil2 = widthMil * thicknessMil;
  final thicknessUm = thicknessMil * 25.4;
  final areaMm2 = widthMm * thicknessUm / 1000;
  final current =
      0.048 * layerFactor * math.pow(rise, 0.44) * math.pow(areaMil2, 0.725);
  final deratedCurrent = current * 0.7;
  final targetAreaMil2 = targetCurrent == null
      ? null
      : math
          .pow(
            targetCurrent / (0.048 * layerFactor * math.pow(rise, 0.44)),
            1 / 0.725,
          )
          .toDouble();
  final targetWidthMil =
      targetAreaMil2 == null ? null : targetAreaMil2 / thicknessMil;
  final targetWidthMm = targetWidthMil == null ? null : targetWidthMil * 0.0254;
  final targetAreaMm2 =
      targetWidthMm == null ? null : targetWidthMm * thicknessUm / 1000;
  final currentMargin = targetCurrent == null ? null : current - targetCurrent;
  final deratedMargin =
      targetCurrent == null ? null : deratedCurrent - targetCurrent;
  final utilization = targetCurrent == null || current <= 0
      ? null
      : targetCurrent / current * 100;

  return [
    ToolResult.number('估算电流', current, 'A', primary: true),
    ToolResult.number('保守 70%', deratedCurrent, 'A'),
    ToolResult.number('层位置系数', layerFactor, 'x'),
    ToolResult.number('线宽', widthMil, 'mil'),
    ToolResult.number('铜厚', thicknessUm, 'μm'),
    ToolResult.number('截面积', areaMil2, 'mil²'),
    ToolResult.number('截面积', areaMm2, 'mm²'),
    ToolResult.number('电流密度', current / areaMm2, 'A/mm²'),
    if (targetCurrent != null) ToolResult.number('目标电流', targetCurrent, 'A'),
    if (targetWidthMil != null)
      ToolResult.number('目标所需线宽', targetWidthMil, 'mil'),
    if (targetWidthMm != null) ToolResult.number('目标所需线宽', targetWidthMm, 'mm'),
    if (targetAreaMil2 != null)
      ToolResult.number('目标所需截面积', targetAreaMil2, 'mil²'),
    if (targetAreaMm2 != null)
      ToolResult.number('目标所需截面积', targetAreaMm2, 'mm²'),
    if (currentMargin != null) ToolResult.number('电流余量', currentMargin, 'A'),
    if (deratedMargin != null) ToolResult.number('70%余量', deratedMargin, 'A'),
    if (utilization != null) ToolResult.number('目标利用率', utilization, '%'),
  ];
}

List<ToolResult> _invalidPcbCurrentResults(bool includeTarget) {
  return [
    const ToolResult.invalid('估算电流', 'A', primary: true),
    const ToolResult.invalid('保守 70%', 'A'),
    const ToolResult.invalid('层位置系数', 'x'),
    const ToolResult.invalid('线宽', 'mil'),
    const ToolResult.invalid('铜厚', 'μm'),
    const ToolResult.invalid('截面积', 'mil²'),
    const ToolResult.invalid('截面积', 'mm²'),
    const ToolResult.invalid('电流密度', 'A/mm²'),
    if (includeTarget) const ToolResult.invalid('目标电流', 'A'),
    if (includeTarget) const ToolResult.invalid('目标所需线宽', 'mil'),
    if (includeTarget) const ToolResult.invalid('目标所需线宽', 'mm'),
    if (includeTarget) const ToolResult.invalid('目标所需截面积', 'mil²'),
    if (includeTarget) const ToolResult.invalid('目标所需截面积', 'mm²'),
    if (includeTarget) const ToolResult.invalid('电流余量', 'A'),
    if (includeTarget) const ToolResult.invalid('70%余量', 'A'),
    if (includeTarget) const ToolResult.invalid('目标利用率', '%'),
  ];
}

List<ToolResult> wireVoltageDropResults(Map<String, double> valuesByKey) {
  final current = valuesByKey['current'] ?? 0;
  final length = valuesByKey['length'] ?? 0;
  final area = valuesByKey['area'] ?? 0;
  final voltage = valuesByKey['voltage'] ?? 0;
  final dropLimit = valuesByKey['dropLimit'] ?? 3;
  final resistivity = valuesByKey['resistivity'] ?? 0.0175;
  final parallel = valuesByKey['parallel'] ?? 1;
  if (current < 0 ||
      length <= 0 ||
      area <= 0 ||
      dropLimit <= 0 ||
      voltage < 0 ||
      resistivity <= 0 ||
      parallel <= 0 ||
      !current.isFinite ||
      !length.isFinite ||
      !area.isFinite ||
      !voltage.isFinite ||
      !dropLimit.isFinite ||
      !resistivity.isFinite ||
      !parallel.isFinite) {
    return _invalidWireVoltageDropResults();
  }

  final loopLength = length * 2;
  final effectiveArea = area * parallel;
  final resistancePerMeter = resistivity / effectiveArea;
  final resistance = resistancePerMeter * loopLength;
  final drop = current * resistance;
  final ratio = voltage <= 0 ? null : drop / voltage * 100;
  final loadVoltage = voltage <= 0 ? null : voltage - drop;
  final targetDropVoltage = voltage <= 0 ? null : voltage * dropLimit / 100;
  final requiredEffectiveArea =
      targetDropVoltage == null || targetDropVoltage <= 0
          ? null
          : current * resistivity * loopLength / targetDropVoltage;
  final requiredAreaPerRun =
      requiredEffectiveArea == null ? null : requiredEffectiveArea / parallel;
  final allowedCurrent = targetDropVoltage == null || resistance <= 0
      ? null
      : targetDropVoltage / resistance;
  final currentMargin =
      allowedCurrent == null ? null : allowedCurrent - current;
  final maxOneWayLength = current <= 0 || targetDropVoltage == null
      ? null
      : targetDropVoltage * effectiveArea / (current * resistivity * 2);
  final lossRatio = voltage <= 0 || current <= 0 ? null : drop / voltage * 100;

  return [
    ToolResult.number('压降', drop, 'V', primary: true),
    ToolResult.number('压降比例', ratio, '%'),
    ToolResult.number('负载端电压', loadVoltage, 'V'),
    ToolResult.number('目标压降', dropLimit, '%'),
    ToolResult.number('目标压降电压', targetDropVoltage, 'V'),
    ToolResult.number('回路长度', loopLength, 'm'),
    ToolResult.number('有效截面积', effectiveArea, 'mm²'),
    ToolResult.number('并联根数', parallel, '根'),
    ToolResult.number('电阻率', resistivity, 'Ω·mm²/m'),
    ToolResult.number('线阻', resistance, 'Ω'),
    ToolResult.number('每米线阻', resistancePerMeter, 'Ω/m'),
    ToolResult.number('线损', drop * current, 'W'),
    ToolResult.number('线损占比', lossRatio, '%'),
    ToolResult.number('电流密度', current / effectiveArea, 'A/mm²'),
    ToolResult.number('目标所需截面积', requiredAreaPerRun, 'mm²/根'),
    ToolResult.number('目标允许电流', allowedCurrent, 'A'),
    ToolResult.number('电流余量', currentMargin, 'A'),
    ToolResult.number('目标允许单程长度', maxOneWayLength, 'm'),
  ];
}

List<ToolResult> _invalidWireVoltageDropResults() {
  return const [
    ToolResult.invalid('压降', 'V', primary: true),
    ToolResult.invalid('压降比例', '%'),
    ToolResult.invalid('负载端电压', 'V'),
    ToolResult.invalid('目标压降', '%'),
    ToolResult.invalid('目标压降电压', 'V'),
    ToolResult.invalid('回路长度', 'm'),
    ToolResult.invalid('有效截面积', 'mm²'),
    ToolResult.invalid('并联根数', '根'),
    ToolResult.invalid('电阻率', 'Ω·mm²/m'),
    ToolResult.invalid('线阻', 'Ω'),
    ToolResult.invalid('每米线阻', 'Ω/m'),
    ToolResult.invalid('线损', 'W'),
    ToolResult.invalid('线损占比', '%'),
    ToolResult.invalid('电流密度', 'A/mm²'),
    ToolResult.invalid('目标所需截面积', 'mm²/根'),
    ToolResult.invalid('目标允许电流', 'A'),
    ToolResult.invalid('电流余量', 'A'),
    ToolResult.invalid('目标允许单程长度', 'm'),
  ];
}

List<ToolResult> dcdcFeedbackResults(Map<String, double> valuesByKey) {
  final vref = valuesByKey['vref'] ?? 0;
  final rtop = valuesByKey['rtop'] ?? 0;
  final rbottom = valuesByKey['rbottom'] ?? 0;
  final targetVout = valuesByKey['targetVout'];
  final targetCurrent = valuesByKey['targetCurrent'];
  final hasTargetVout = targetVout != null;
  final hasTargetCurrent = targetCurrent != null;
  if (vref <= 0 ||
      rtop < 0 ||
      rbottom <= 0 ||
      !vref.isFinite ||
      !rtop.isFinite ||
      !rbottom.isFinite ||
      (targetVout != null && (targetVout < vref || !targetVout.isFinite)) ||
      (targetCurrent != null &&
          (targetCurrent <= 0 || !targetCurrent.isFinite))) {
    return _invalidDcdcFeedbackResults(
      includeTargetVout: hasTargetVout,
      includeTargetCurrent: hasTargetCurrent,
    );
  }

  final ratio = rtop / rbottom;
  final output = vref * (1 + ratio);
  final totalResistance = rtop + rbottom;
  final topDrop = output - vref;
  final feedbackCurrent = output / totalResistance;
  final topPower = rtop == 0 ? 0.0 : topDrop * topDrop / rtop;
  final bottomPower = vref * vref / rbottom;
  final targetOutput = targetVout ?? output;
  final targetRatio = targetOutput / vref - 1;
  final targetTopKeepBottom = targetRatio * rbottom;
  final targetBottomKeepTop = targetRatio > 0 ? rtop / targetRatio : null;
  final targetOutputDelta = targetVout == null ? null : output - targetVout;
  final targetOutputError = targetVout == null || targetOutputDelta == null
      ? null
      : targetOutputDelta / targetVout * 100;
  final targetTopByCurrent = targetCurrent == null
      ? null
      : math.max(0.0, targetOutput - vref) / targetCurrent;
  final targetBottomByCurrent =
      targetCurrent == null ? null : vref / targetCurrent;
  final targetTotalByCurrent =
      targetCurrent == null ? null : targetOutput / targetCurrent;
  final targetCurrentDelta =
      targetCurrent == null ? null : feedbackCurrent - targetCurrent;

  return [
    ToolResult.number('输出电压', output, 'V', primary: true),
    ToolResult.number('分压比', ratio, ''),
    ToolResult.number('反馈电压', vref, 'V'),
    ToolResult.number('上拉压降', topDrop, 'V'),
    ToolResult.number('反馈电流', feedbackCurrent, 'mA'),
    ToolResult.number('反馈总阻值', totalResistance, 'kΩ'),
    ToolResult.number('上拉功耗', topPower, 'mW'),
    ToolResult.number('下拉功耗', bottomPower, 'mW'),
    ToolResult.number('反馈总功耗', topPower + bottomPower, 'mW'),
    if (targetVout != null) ToolResult.number('目标输出电压', targetVout, 'V'),
    if (targetVout != null) ToolResult.number('输出偏差', targetOutputDelta!, 'V'),
    if (targetOutputError != null)
      ToolResult.number('输出偏差比例', targetOutputError, '%'),
    if (targetVout != null) ToolResult.number('目标分压比', targetRatio, ''),
    if (targetVout != null)
      ToolResult.number('保留下拉所需上拉', targetTopKeepBottom, 'kΩ'),
    if (targetVout != null)
      ToolResult.number('保留上拉所需下拉', targetBottomKeepTop, 'kΩ'),
    if (targetCurrent != null) ToolResult.number('目标反馈电流', targetCurrent, 'mA'),
    if (targetCurrentDelta != null)
      ToolResult.number('反馈电流偏差', targetCurrentDelta, 'mA'),
    if (targetTopByCurrent != null)
      ToolResult.number('目标上拉电阻', targetTopByCurrent, 'kΩ'),
    if (targetBottomByCurrent != null)
      ToolResult.number('目标下拉电阻', targetBottomByCurrent, 'kΩ'),
    if (targetTotalByCurrent != null)
      ToolResult.number('目标总阻值', targetTotalByCurrent, 'kΩ'),
    if (targetCurrent != null)
      ToolResult.number('目标反馈功耗', targetOutput * targetCurrent, 'mW'),
  ];
}

List<ToolResult> _invalidDcdcFeedbackResults({
  required bool includeTargetVout,
  required bool includeTargetCurrent,
}) {
  return [
    const ToolResult.invalid('输出电压', 'V', primary: true),
    const ToolResult.invalid('分压比', ''),
    const ToolResult.invalid('反馈电压', 'V'),
    const ToolResult.invalid('上拉压降', 'V'),
    const ToolResult.invalid('反馈电流', 'mA'),
    const ToolResult.invalid('反馈总阻值', 'kΩ'),
    const ToolResult.invalid('上拉功耗', 'mW'),
    const ToolResult.invalid('下拉功耗', 'mW'),
    const ToolResult.invalid('反馈总功耗', 'mW'),
    if (includeTargetVout) const ToolResult.invalid('目标输出电压', 'V'),
    if (includeTargetVout) const ToolResult.invalid('输出偏差', 'V'),
    if (includeTargetVout) const ToolResult.invalid('输出偏差比例', '%'),
    if (includeTargetVout) const ToolResult.invalid('目标分压比', ''),
    if (includeTargetVout) const ToolResult.invalid('保留下拉所需上拉', 'kΩ'),
    if (includeTargetVout) const ToolResult.invalid('保留上拉所需下拉', 'kΩ'),
    if (includeTargetCurrent) const ToolResult.invalid('目标反馈电流', 'mA'),
    if (includeTargetCurrent) const ToolResult.invalid('反馈电流偏差', 'mA'),
    if (includeTargetCurrent) const ToolResult.invalid('目标上拉电阻', 'kΩ'),
    if (includeTargetCurrent) const ToolResult.invalid('目标下拉电阻', 'kΩ'),
    if (includeTargetCurrent) const ToolResult.invalid('目标总阻值', 'kΩ'),
    if (includeTargetCurrent) const ToolResult.invalid('目标反馈功耗', 'mW'),
  ];
}

List<ToolResult> ldoPowerResults(Map<String, double> valuesByKey) {
  final vin = valuesByKey['vin'] ?? 0;
  final vout = valuesByKey['vout'] ?? 0;
  final loadCurrentMa = valuesByKey['current'] ?? 0;
  final iqMa = valuesByKey['iq'] ?? 0;
  final requiredDropout = valuesByKey['dropout'] ?? 0;
  final theta = valuesByKey['theta'] ?? 50;
  final ambient = valuesByKey['ambient'] ?? 25;
  final maxJunction = valuesByKey['maxJunction'] ?? 125;
  if (vin <= 0 ||
      vout < 0 ||
      loadCurrentMa < 0 ||
      iqMa < 0 ||
      requiredDropout < 0 ||
      theta <= 0 ||
      !vin.isFinite ||
      !vout.isFinite ||
      !loadCurrentMa.isFinite ||
      !iqMa.isFinite ||
      !requiredDropout.isFinite ||
      !theta.isFinite ||
      !ambient.isFinite ||
      !maxJunction.isFinite) {
    return _invalidLdoPowerResults();
  }

  final loadCurrent = loadCurrentMa / 1000;
  final quiescentCurrent = iqMa / 1000;
  final inputCurrent = loadCurrent + quiescentCurrent;
  final headroom = vin - vout;
  final headroomMargin = headroom - requiredDropout;
  final regulates = headroomMargin >= 0;
  final loadLoss = math.max(0.0, headroom) * loadCurrent;
  final quiescentLoss = vin * quiescentCurrent;
  final loss = loadLoss + quiescentLoss;
  final inputPower = vin * inputCurrent;
  final outputPower = vout * loadCurrent;
  // 中文：效率**先算成数**；条件不成立那一支产出方明确说算不出来。
  // English: efficiency **is computed as a number first**; the branch where the condition fails is
  //          the producer saying plainly that it cannot be produced.
  final efficiency =
      regulates && inputPower > 0 ? outputPower / inputPower * 100 : null;
  final rise = loss * theta;
  final junction = ambient + rise;
  final margin = maxJunction - junction;
  final maxAmbient = maxJunction - rise;
  final allowedRise = math.max(0.0, maxJunction - ambient);
  final allowedPower = allowedRise / theta;
  final thermalResistanceLimit = loss > 0 ? allowedRise / loss : null;
  final thermalCurrentLimit = headroom > 0
      ? math.max(0.0, (allowedPower - quiescentLoss) / headroom) * 1000
      : null;

  return [
    ToolResult.number('功耗', loss, 'W', primary: true),
    ToolResult.number('效率', efficiency, '%'),
    ToolResult.number('输入功率', inputPower, 'W'),
    ToolResult.number('输出功率', outputPower, 'W'),
    ToolResult.number('负载损耗', loadLoss, 'W'),
    ToolResult.number('静态损耗', quiescentLoss, 'W'),
    ToolResult.number('压差', headroom, 'V'),
    ToolResult.number('最小压差', requiredDropout, 'V'),
    ToolResult.number('压差余量', headroomMargin, 'V'),
    ToolResult.number('静态电流', iqMa, 'mA'),
    ToolResult.number('总输入电流', inputCurrent * 1000, 'mA'),
    ToolResult('调节状态', regulates ? '可调节' : '压差不足', ''),
    ToolResult.number('温升', rise, '℃'),
    ToolResult.number('结温估算', junction, '℃'),
    ToolResult.number('热余量', margin, '℃'),
    ToolResult.number('最大环境温度', maxAmbient, '℃'),
    ToolResult.number('热阻上限', thermalResistanceLimit, '℃/W'),
    ToolResult.number('热限电流', thermalCurrentLimit, 'mA'),
  ];
}

List<ToolResult> _invalidLdoPowerResults() {
  return const [
    ToolResult.invalid('功耗', 'W', primary: true),
    ToolResult.invalid('效率', '%'),
    ToolResult.invalid('输入功率', 'W'),
    ToolResult.invalid('输出功率', 'W'),
    ToolResult.invalid('负载损耗', 'W'),
    ToolResult.invalid('静态损耗', 'W'),
    ToolResult.invalid('压差', 'V'),
    ToolResult.invalid('最小压差', 'V'),
    ToolResult.invalid('压差余量', 'V'),
    ToolResult.invalid('静态电流', 'mA'),
    ToolResult.invalid('总输入电流', 'mA'),
    ToolResult.invalid('调节状态', ''),
    ToolResult.invalid('温升', '℃'),
    ToolResult.invalid('结温估算', '℃'),
    ToolResult.invalid('热余量', '℃'),
    ToolResult.invalid('最大环境温度', '℃'),
    ToolResult.invalid('热阻上限', '℃/W'),
    ToolResult.invalid('热限电流', 'mA'),
  ];
}

List<ToolResult> thermalRiseResults(Map<String, double> valuesByKey) {
  final power = valuesByKey['power'] ?? 0;
  final theta = valuesByKey['theta'] ?? 0;
  final ambient = valuesByKey['ambient'] ?? 0;
  final maxJunction = valuesByKey['maxJunction'] ?? 125;
  final derating = valuesByKey['derating'] ?? 70;
  final targetJunction = valuesByKey['targetJunction'];
  final targetMargin = valuesByKey['targetMargin'];
  final includeTargetJunction = targetJunction != null;
  final includeTargetMargin = targetMargin != null;
  if (power < 0 ||
      theta <= 0 ||
      maxJunction <= ambient ||
      derating <= 0 ||
      derating > 100 ||
      !power.isFinite ||
      !theta.isFinite ||
      !ambient.isFinite ||
      !maxJunction.isFinite ||
      !derating.isFinite ||
      (targetJunction != null &&
          (targetJunction <= ambient ||
              targetJunction > maxJunction ||
              !targetJunction.isFinite)) ||
      (targetMargin != null &&
          (targetMargin < 0 ||
              targetMargin >= maxJunction - ambient ||
              !targetMargin.isFinite))) {
    return _invalidThermalRiseResults(
      includeTargetJunction: includeTargetJunction,
      includeTargetMargin: includeTargetMargin,
    );
  }

  final rise = power * theta;
  final junction = ambient + rise;
  final allowedRise = maxJunction - ambient;
  final margin = maxJunction - junction;
  final maxPower = allowedRise / theta;
  final deratedPower = maxPower * derating / 100;
  final thetaLimit = power > 0 ? allowedRise / power : double.infinity;
  final maxAmbientAtPower = maxJunction - rise;
  final powerUtilization = maxPower > 0 ? power / maxPower * 100 : double.nan;
  final deratedUtilization =
      deratedPower > 0 ? power / deratedPower * 100 : double.nan;
  final targetJunctionPower =
      targetJunction == null ? null : (targetJunction - ambient) / theta;
  final targetJunctionTheta = targetJunction == null || power <= 0
      ? null
      : (targetJunction - ambient) / power;
  final targetMarginPower =
      targetMargin == null ? null : (allowedRise - targetMargin) / theta;
  final targetMarginTheta = targetMargin == null || power <= 0
      ? null
      : (allowedRise - targetMargin) / power;

  return [
    ToolResult.number('结温估算', junction, '℃', primary: true),
    ToolResult.number('温升', rise, '℃'),
    ToolResult.number('环境温度', ambient, '℃'),
    ToolResult.number('最高结温', maxJunction, '℃'),
    ToolResult.number('热余量', margin, '℃'),
    ToolResult.number('热余量比例', margin / allowedRise * 100, '%'),
    ToolResult.number('允许温升', allowedRise, '℃'),
    ToolResult.number('允许功耗', maxPower, 'W'),
    ToolResult.number('降额比例', derating, '%'),
    ToolResult.number('降额功耗', deratedPower, 'W'),
    ToolResult.number('70% 降额功耗', maxPower * 0.7, 'W'),
    ToolResult.number('功耗利用率', powerUtilization, '%'),
    ToolResult.number('降额利用率', deratedUtilization, '%'),
    ToolResult.number('最大环境温度', maxAmbientAtPower, '℃'),
    ToolResult.number('热阻上限', thetaLimit.isFinite ? thetaLimit : null, '℃/W'),
    if (targetJunction != null) ToolResult.number('目标结温', targetJunction, '℃'),
    if (targetJunctionPower != null)
      ToolResult.number('目标结温允许功耗', targetJunctionPower, 'W'),
    if (targetJunctionTheta != null)
      ToolResult.number('目标结温热阻上限', targetJunctionTheta, '℃/W'),
    if (targetMargin != null) ToolResult.number('目标热余量', targetMargin, '℃'),
    if (targetMarginPower != null)
      ToolResult.number('目标余量允许功耗', targetMarginPower, 'W'),
    if (targetMarginTheta != null)
      ToolResult.number('目标余量热阻上限', targetMarginTheta, '℃/W'),
  ];
}

List<ToolResult> _invalidThermalRiseResults({
  required bool includeTargetJunction,
  required bool includeTargetMargin,
}) {
  return [
    const ToolResult.invalid('结温估算', '℃', primary: true),
    const ToolResult.invalid('温升', '℃'),
    const ToolResult.invalid('环境温度', '℃'),
    const ToolResult.invalid('最高结温', '℃'),
    const ToolResult.invalid('热余量', '℃'),
    const ToolResult.invalid('热余量比例', '%'),
    const ToolResult.invalid('允许温升', '℃'),
    const ToolResult.invalid('允许功耗', 'W'),
    const ToolResult.invalid('降额比例', '%'),
    const ToolResult.invalid('降额功耗', 'W'),
    const ToolResult.invalid('70% 降额功耗', 'W'),
    const ToolResult.invalid('功耗利用率', '%'),
    const ToolResult.invalid('降额利用率', '%'),
    const ToolResult.invalid('最大环境温度', '℃'),
    const ToolResult.invalid('热阻上限', '℃/W'),
    if (includeTargetJunction) const ToolResult.invalid('目标结温', '℃'),
    if (includeTargetJunction) const ToolResult.invalid('目标结温允许功耗', 'W'),
    if (includeTargetJunction) const ToolResult.invalid('目标结温热阻上限', '℃/W'),
    if (includeTargetMargin) const ToolResult.invalid('目标热余量', '℃'),
    if (includeTargetMargin) const ToolResult.invalid('目标余量允许功耗', 'W'),
    if (includeTargetMargin) const ToolResult.invalid('目标余量热阻上限', '℃/W'),
  ];
}
