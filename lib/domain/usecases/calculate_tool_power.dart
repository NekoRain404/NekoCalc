import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
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
    ToolResult('续航时间', formatNumber(hours), 'h', primary: true),
    ToolResult('天数', formatNumber(hours / 24), 'day'),
    ToolResult('留 20% 余量', formatNumber(hours * 0.8), 'h'),
    ToolResult('余量后续航', formatNumber(usableHours), 'h'),
    ToolResult('保留余量', formatNumber(reservePercent), '%'),
    ToolResult('可用容量', formatNumber(capacity * eta), 'mAh'),
    ToolResult('余量后容量', formatNumber(capacity * eta * reserveFactor), 'mAh'),
    ToolResult('标称能量', formatNumber(nominalWh), 'Wh'),
    ToolResult('可用能量', formatNumber(nominalWh * eta), 'Wh'),
    ToolResult('余量后能量', formatNumber(nominalWh * eta * reserveFactor), 'Wh'),
    ToolResult('负载功率', formatNumber(loadW), 'W'),
    ToolResult('等效电池电流', formatNumber(equivalentBatteryCurrent), 'mA'),
    ToolResult('等效电池功率', formatNumber(equivalentBatteryPower), 'W'),
    ToolResult('C倍率', formatNumber(cRate), 'C'),
    ToolResult('每小时消耗', formatNumber(100 / hours), '%'),
    if (requiredCapacity != null)
      ToolResult('目标所需容量', formatNumber(requiredCapacity), 'mAh'),
    if (requiredCapacity != null)
      ToolResult(
          '目标所需能量', formatNumber(requiredCapacity * voltage / 1000), 'Wh'),
    if (allowedAverageCurrent != null)
      ToolResult('目标允许电流', formatNumber(allowedAverageCurrent), 'mA'),
    if (targetEnergy != null)
      ToolResult('目标负载能量', formatNumber(targetEnergy), 'Wh'),
  ];
}

List<ToolResult> _invalidBatteryLifeResults(bool includeTarget) {
  return [
    const ToolResult('续航时间', '无效', 'h', primary: true),
    const ToolResult('天数', '无效', 'day'),
    const ToolResult('留 20% 余量', '无效', 'h'),
    const ToolResult('余量后续航', '无效', 'h'),
    const ToolResult('保留余量', '无效', '%'),
    const ToolResult('可用容量', '无效', 'mAh'),
    const ToolResult('余量后容量', '无效', 'mAh'),
    const ToolResult('标称能量', '无效', 'Wh'),
    const ToolResult('可用能量', '无效', 'Wh'),
    const ToolResult('余量后能量', '无效', 'Wh'),
    const ToolResult('负载功率', '无效', 'W'),
    const ToolResult('等效电池电流', '无效', 'mA'),
    const ToolResult('等效电池功率', '无效', 'W'),
    const ToolResult('C倍率', '无效', 'C'),
    const ToolResult('每小时消耗', '无效', '%'),
    if (includeTarget) const ToolResult('目标所需容量', '无效', 'mAh'),
    if (includeTarget) const ToolResult('目标所需能量', '无效', 'Wh'),
    if (includeTarget) const ToolResult('目标允许电流', '无效', 'mA'),
    if (includeTarget) const ToolResult('目标负载能量', '无效', 'Wh'),
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
    ToolResult('估算电流', formatNumber(current), 'A', primary: true),
    ToolResult('保守 70%', formatNumber(deratedCurrent), 'A'),
    ToolResult('层位置系数', formatNumber(layerFactor), 'x'),
    ToolResult('线宽', formatNumber(widthMil), 'mil'),
    ToolResult('铜厚', formatNumber(thicknessUm), 'μm'),
    ToolResult('截面积', formatNumber(areaMil2), 'mil²'),
    ToolResult('截面积', formatNumber(areaMm2), 'mm²'),
    ToolResult('电流密度', formatNumber(current / areaMm2), 'A/mm²'),
    if (targetCurrent != null)
      ToolResult('目标电流', formatNumber(targetCurrent), 'A'),
    if (targetWidthMil != null)
      ToolResult('目标所需线宽', formatNumber(targetWidthMil), 'mil'),
    if (targetWidthMm != null)
      ToolResult('目标所需线宽', formatNumber(targetWidthMm), 'mm'),
    if (targetAreaMil2 != null)
      ToolResult('目标所需截面积', formatNumber(targetAreaMil2), 'mil²'),
    if (targetAreaMm2 != null)
      ToolResult('目标所需截面积', formatNumber(targetAreaMm2), 'mm²'),
    if (currentMargin != null)
      ToolResult('电流余量', formatNumber(currentMargin), 'A'),
    if (deratedMargin != null)
      ToolResult('70%余量', formatNumber(deratedMargin), 'A'),
    if (utilization != null)
      ToolResult('目标利用率', formatNumber(utilization), '%'),
  ];
}

List<ToolResult> _invalidPcbCurrentResults(bool includeTarget) {
  return [
    const ToolResult('估算电流', '无效', 'A', primary: true),
    const ToolResult('保守 70%', '无效', 'A'),
    const ToolResult('层位置系数', '无效', 'x'),
    const ToolResult('线宽', '无效', 'mil'),
    const ToolResult('铜厚', '无效', 'μm'),
    const ToolResult('截面积', '无效', 'mil²'),
    const ToolResult('截面积', '无效', 'mm²'),
    const ToolResult('电流密度', '无效', 'A/mm²'),
    if (includeTarget) const ToolResult('目标电流', '无效', 'A'),
    if (includeTarget) const ToolResult('目标所需线宽', '无效', 'mil'),
    if (includeTarget) const ToolResult('目标所需线宽', '无效', 'mm'),
    if (includeTarget) const ToolResult('目标所需截面积', '无效', 'mil²'),
    if (includeTarget) const ToolResult('目标所需截面积', '无效', 'mm²'),
    if (includeTarget) const ToolResult('电流余量', '无效', 'A'),
    if (includeTarget) const ToolResult('70%余量', '无效', 'A'),
    if (includeTarget) const ToolResult('目标利用率', '无效', '%'),
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
    ToolResult('压降', formatNumber(drop), 'V', primary: true),
    ToolResult('压降比例', ratio == null ? '无效' : formatNumber(ratio), '%'),
    ToolResult(
        '负载端电压', loadVoltage == null ? '无效' : formatNumber(loadVoltage), 'V'),
    ToolResult('目标压降', formatNumber(dropLimit), '%'),
    ToolResult(
        '目标压降电压',
        targetDropVoltage == null ? '无效' : formatNumber(targetDropVoltage),
        'V'),
    ToolResult('回路长度', formatNumber(loopLength), 'm'),
    ToolResult('有效截面积', formatNumber(effectiveArea), 'mm²'),
    ToolResult('并联根数', formatNumber(parallel), '根'),
    ToolResult('电阻率', formatNumber(resistivity), 'Ω·mm²/m'),
    ToolResult('线阻', formatNumber(resistance), 'Ω'),
    ToolResult('每米线阻', formatNumber(resistancePerMeter), 'Ω/m'),
    ToolResult('线损', formatNumber(drop * current), 'W'),
    ToolResult('线损占比', lossRatio == null ? '无效' : formatNumber(lossRatio), '%'),
    ToolResult('电流密度', formatNumber(current / effectiveArea), 'A/mm²'),
    ToolResult(
        '目标所需截面积',
        requiredAreaPerRun == null ? '无效' : formatNumber(requiredAreaPerRun),
        'mm²/根'),
    ToolResult('目标允许电流',
        allowedCurrent == null ? '无效' : formatNumber(allowedCurrent), 'A'),
    ToolResult('电流余量',
        currentMargin == null ? '无效' : formatNumber(currentMargin), 'A'),
    ToolResult('目标允许单程长度',
        maxOneWayLength == null ? '无效' : formatNumber(maxOneWayLength), 'm'),
  ];
}

List<ToolResult> _invalidWireVoltageDropResults() {
  return const [
    ToolResult('压降', '无效', 'V', primary: true),
    ToolResult('压降比例', '无效', '%'),
    ToolResult('负载端电压', '无效', 'V'),
    ToolResult('目标压降', '无效', '%'),
    ToolResult('目标压降电压', '无效', 'V'),
    ToolResult('回路长度', '无效', 'm'),
    ToolResult('有效截面积', '无效', 'mm²'),
    ToolResult('并联根数', '无效', '根'),
    ToolResult('电阻率', '无效', 'Ω·mm²/m'),
    ToolResult('线阻', '无效', 'Ω'),
    ToolResult('每米线阻', '无效', 'Ω/m'),
    ToolResult('线损', '无效', 'W'),
    ToolResult('线损占比', '无效', '%'),
    ToolResult('电流密度', '无效', 'A/mm²'),
    ToolResult('目标所需截面积', '无效', 'mm²/根'),
    ToolResult('目标允许电流', '无效', 'A'),
    ToolResult('电流余量', '无效', 'A'),
    ToolResult('目标允许单程长度', '无效', 'm'),
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
    ToolResult('输出电压', formatNumber(output), 'V', primary: true),
    ToolResult('分压比', formatNumber(ratio), ''),
    ToolResult('反馈电压', formatNumber(vref), 'V'),
    ToolResult('上拉压降', formatNumber(topDrop), 'V'),
    ToolResult('反馈电流', formatNumber(feedbackCurrent), 'mA'),
    ToolResult('反馈总阻值', formatNumber(totalResistance), 'kΩ'),
    ToolResult('上拉功耗', formatNumber(topPower), 'mW'),
    ToolResult('下拉功耗', formatNumber(bottomPower), 'mW'),
    ToolResult('反馈总功耗', formatNumber(topPower + bottomPower), 'mW'),
    if (targetVout != null) ToolResult('目标输出电压', formatNumber(targetVout), 'V'),
    if (targetVout != null)
      ToolResult('输出偏差', formatNumber(targetOutputDelta!), 'V'),
    if (targetOutputError != null)
      ToolResult('输出偏差比例', formatNumber(targetOutputError), '%'),
    if (targetVout != null) ToolResult('目标分压比', formatNumber(targetRatio), ''),
    if (targetVout != null)
      ToolResult('保留下拉所需上拉', formatNumber(targetTopKeepBottom), 'kΩ'),
    if (targetVout != null)
      ToolResult(
        '保留上拉所需下拉',
        targetBottomKeepTop == null ? '无效' : formatNumber(targetBottomKeepTop),
        'kΩ',
      ),
    if (targetCurrent != null)
      ToolResult('目标反馈电流', formatNumber(targetCurrent), 'mA'),
    if (targetCurrentDelta != null)
      ToolResult('反馈电流偏差', formatNumber(targetCurrentDelta), 'mA'),
    if (targetTopByCurrent != null)
      ToolResult('目标上拉电阻', formatNumber(targetTopByCurrent), 'kΩ'),
    if (targetBottomByCurrent != null)
      ToolResult('目标下拉电阻', formatNumber(targetBottomByCurrent), 'kΩ'),
    if (targetTotalByCurrent != null)
      ToolResult('目标总阻值', formatNumber(targetTotalByCurrent), 'kΩ'),
    if (targetCurrent != null)
      ToolResult(
        '目标反馈功耗',
        formatNumber(targetOutput * targetCurrent),
        'mW',
      ),
  ];
}

List<ToolResult> _invalidDcdcFeedbackResults({
  required bool includeTargetVout,
  required bool includeTargetCurrent,
}) {
  return [
    const ToolResult('输出电压', '无效', 'V', primary: true),
    const ToolResult('分压比', '无效', ''),
    const ToolResult('反馈电压', '无效', 'V'),
    const ToolResult('上拉压降', '无效', 'V'),
    const ToolResult('反馈电流', '无效', 'mA'),
    const ToolResult('反馈总阻值', '无效', 'kΩ'),
    const ToolResult('上拉功耗', '无效', 'mW'),
    const ToolResult('下拉功耗', '无效', 'mW'),
    const ToolResult('反馈总功耗', '无效', 'mW'),
    if (includeTargetVout) const ToolResult('目标输出电压', '无效', 'V'),
    if (includeTargetVout) const ToolResult('输出偏差', '无效', 'V'),
    if (includeTargetVout) const ToolResult('输出偏差比例', '无效', '%'),
    if (includeTargetVout) const ToolResult('目标分压比', '无效', ''),
    if (includeTargetVout) const ToolResult('保留下拉所需上拉', '无效', 'kΩ'),
    if (includeTargetVout) const ToolResult('保留上拉所需下拉', '无效', 'kΩ'),
    if (includeTargetCurrent) const ToolResult('目标反馈电流', '无效', 'mA'),
    if (includeTargetCurrent) const ToolResult('反馈电流偏差', '无效', 'mA'),
    if (includeTargetCurrent) const ToolResult('目标上拉电阻', '无效', 'kΩ'),
    if (includeTargetCurrent) const ToolResult('目标下拉电阻', '无效', 'kΩ'),
    if (includeTargetCurrent) const ToolResult('目标总阻值', '无效', 'kΩ'),
    if (includeTargetCurrent) const ToolResult('目标反馈功耗', '无效', 'mW'),
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
  final efficiency = regulates && inputPower > 0
      ? formatNumber(outputPower / inputPower * 100)
      : '无效';
  final rise = loss * theta;
  final junction = ambient + rise;
  final margin = maxJunction - junction;
  final maxAmbient = maxJunction - rise;
  final allowedRise = math.max(0.0, maxJunction - ambient);
  final allowedPower = allowedRise / theta;
  final thermalResistanceLimit =
      loss > 0 ? formatNumber(allowedRise / loss) : '无效';
  final thermalCurrentLimit = headroom > 0
      ? formatNumber(
          math.max(0.0, (allowedPower - quiescentLoss) / headroom) * 1000,
        )
      : '无效';

  return [
    ToolResult('功耗', formatNumber(loss), 'W', primary: true),
    ToolResult('效率', efficiency, '%'),
    ToolResult('输入功率', formatNumber(inputPower), 'W'),
    ToolResult('输出功率', formatNumber(outputPower), 'W'),
    ToolResult('负载损耗', formatNumber(loadLoss), 'W'),
    ToolResult('静态损耗', formatNumber(quiescentLoss), 'W'),
    ToolResult('压差', formatNumber(headroom), 'V'),
    ToolResult('最小压差', formatNumber(requiredDropout), 'V'),
    ToolResult('压差余量', formatNumber(headroomMargin), 'V'),
    ToolResult('静态电流', formatNumber(iqMa), 'mA'),
    ToolResult('总输入电流', formatNumber(inputCurrent * 1000), 'mA'),
    ToolResult('调节状态', regulates ? '可调节' : '压差不足', ''),
    ToolResult('温升', formatNumber(rise), '℃'),
    ToolResult('结温估算', formatNumber(junction), '℃'),
    ToolResult('热余量', formatNumber(margin), '℃'),
    ToolResult('最大环境温度', formatNumber(maxAmbient), '℃'),
    ToolResult('热阻上限', thermalResistanceLimit, '℃/W'),
    ToolResult('热限电流', thermalCurrentLimit, 'mA'),
  ];
}

List<ToolResult> _invalidLdoPowerResults() {
  return const [
    ToolResult('功耗', '无效', 'W', primary: true),
    ToolResult('效率', '无效', '%'),
    ToolResult('输入功率', '无效', 'W'),
    ToolResult('输出功率', '无效', 'W'),
    ToolResult('负载损耗', '无效', 'W'),
    ToolResult('静态损耗', '无效', 'W'),
    ToolResult('压差', '无效', 'V'),
    ToolResult('最小压差', '无效', 'V'),
    ToolResult('压差余量', '无效', 'V'),
    ToolResult('静态电流', '无效', 'mA'),
    ToolResult('总输入电流', '无效', 'mA'),
    ToolResult('调节状态', '无效', ''),
    ToolResult('温升', '无效', '℃'),
    ToolResult('结温估算', '无效', '℃'),
    ToolResult('热余量', '无效', '℃'),
    ToolResult('最大环境温度', '无效', '℃'),
    ToolResult('热阻上限', '无效', '℃/W'),
    ToolResult('热限电流', '无效', 'mA'),
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
    ToolResult('结温估算', formatNumber(junction), '℃', primary: true),
    ToolResult('温升', formatNumber(rise), '℃'),
    ToolResult('环境温度', formatNumber(ambient), '℃'),
    ToolResult('最高结温', formatNumber(maxJunction), '℃'),
    ToolResult('热余量', formatNumber(margin), '℃'),
    ToolResult('热余量比例', formatNumber(margin / allowedRise * 100), '%'),
    ToolResult('允许温升', formatNumber(allowedRise), '℃'),
    ToolResult('允许功耗', formatNumber(maxPower), 'W'),
    ToolResult('降额比例', formatNumber(derating), '%'),
    ToolResult('降额功耗', formatNumber(deratedPower), 'W'),
    ToolResult('70% 降额功耗', formatNumber(maxPower * 0.7), 'W'),
    ToolResult('功耗利用率', formatNumber(powerUtilization), '%'),
    ToolResult('降额利用率', formatNumber(deratedUtilization), '%'),
    ToolResult('最大环境温度', formatNumber(maxAmbientAtPower), '℃'),
    ToolResult(
      '热阻上限',
      thetaLimit.isFinite ? formatNumber(thetaLimit) : '无效',
      '℃/W',
    ),
    if (targetJunction != null)
      ToolResult('目标结温', formatNumber(targetJunction), '℃'),
    if (targetJunctionPower != null)
      ToolResult('目标结温允许功耗', formatNumber(targetJunctionPower), 'W'),
    if (targetJunctionTheta != null)
      ToolResult('目标结温热阻上限', formatNumber(targetJunctionTheta), '℃/W'),
    if (targetMargin != null)
      ToolResult('目标热余量', formatNumber(targetMargin), '℃'),
    if (targetMarginPower != null)
      ToolResult('目标余量允许功耗', formatNumber(targetMarginPower), 'W'),
    if (targetMarginTheta != null)
      ToolResult('目标余量热阻上限', formatNumber(targetMarginTheta), '℃/W'),
  ];
}

List<ToolResult> _invalidThermalRiseResults({
  required bool includeTargetJunction,
  required bool includeTargetMargin,
}) {
  return [
    const ToolResult('结温估算', '无效', '℃', primary: true),
    const ToolResult('温升', '无效', '℃'),
    const ToolResult('环境温度', '无效', '℃'),
    const ToolResult('最高结温', '无效', '℃'),
    const ToolResult('热余量', '无效', '℃'),
    const ToolResult('热余量比例', '无效', '%'),
    const ToolResult('允许温升', '无效', '℃'),
    const ToolResult('允许功耗', '无效', 'W'),
    const ToolResult('降额比例', '无效', '%'),
    const ToolResult('降额功耗', '无效', 'W'),
    const ToolResult('70% 降额功耗', '无效', 'W'),
    const ToolResult('功耗利用率', '无效', '%'),
    const ToolResult('降额利用率', '无效', '%'),
    const ToolResult('最大环境温度', '无效', '℃'),
    const ToolResult('热阻上限', '无效', '℃/W'),
    if (includeTargetJunction) const ToolResult('目标结温', '无效', '℃'),
    if (includeTargetJunction) const ToolResult('目标结温允许功耗', '无效', 'W'),
    if (includeTargetJunction) const ToolResult('目标结温热阻上限', '无效', '℃/W'),
    if (includeTargetMargin) const ToolResult('目标热余量', '无效', '℃'),
    if (includeTargetMargin) const ToolResult('目标余量允许功耗', '无效', 'W'),
    if (includeTargetMargin) const ToolResult('目标余量热阻上限', '无效', '℃/W'),
  ];
}
