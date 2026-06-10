import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> bmiResults(Map<String, double> valuesByKey) {
  final weight = valuesByKey['weight'] ?? 0;
  final heightCm = valuesByKey['height'] ?? 0;
  final waistCm = valuesByKey['waist'];
  if (weight <= 0 ||
      heightCm <= 0 ||
      !weight.isFinite ||
      !heightCm.isFinite ||
      (waistCm != null && (!waistCm.isFinite || waistCm <= 0))) {
    return _invalidBmiResults(includeWaist: waistCm != null);
  }

  final heightM = heightCm / 100;
  final heightSquared = heightM * heightM;
  final bmi = weight / heightSquared;
  final healthyWeightLow = 18.5 * heightSquared;
  final healthyWeightHigh = 23.9 * heightSquared;
  final normalUpper = 24 * heightSquared;
  final targetWeight = 22 * heightSquared;
  final targetDelta = targetWeight - weight;
  final bsa = math.sqrt(heightCm * weight / 3600);
  final idealRange = _range(healthyWeightLow, healthyWeightHigh);
  final results = <ToolResult>[
    ToolResult('BMI', formatNumber(bmi), '', primary: true),
    ToolResult('区间', _bmiLabel(bmi), ''),
    ToolResult('健康体重范围', idealRange, 'kg'),
    ToolResult('正常体重下限', formatNumber(healthyWeightLow), 'kg'),
    ToolResult('正常体重上限', formatNumber(normalUpper), 'kg'),
    ToolResult('距健康区间',
        _weightRangeDelta(weight, healthyWeightLow, healthyWeightHigh), ''),
    ToolResult('BMI 22 目标体重', formatNumber(targetWeight), 'kg'),
    ToolResult('目标体重差', formatNumber(targetDelta), 'kg'),
    ToolResult('体表面积', formatNumber(bsa), 'm²'),
  ];
  if (waistCm != null) {
    final waistHeightRatio = waistCm / heightCm;
    results.add(ToolResult('腰高比', formatNumber(waistHeightRatio), ''));
    results.add(ToolResult('腰高比分级', _waistHeightLabel(waistHeightRatio), ''));
  }
  return results;
}

List<ToolResult> _invalidBmiResults({required bool includeWaist}) {
  return [
    const ToolResult('BMI', '无效', '', primary: true),
    const ToolResult('区间', '无效', ''),
    const ToolResult('健康体重范围', '无效', 'kg'),
    const ToolResult('正常体重下限', '无效', 'kg'),
    const ToolResult('正常体重上限', '无效', 'kg'),
    const ToolResult('距健康区间', '无效', 'kg'),
    const ToolResult('BMI 22 目标体重', '无效', 'kg'),
    const ToolResult('目标体重差', '无效', 'kg'),
    const ToolResult('体表面积', '无效', 'm²'),
    if (includeWaist) const ToolResult('腰高比', '无效', ''),
    if (includeWaist) const ToolResult('腰高比分级', '无效', ''),
  ];
}

String _bmiLabel(double bmi) {
  if (bmi < 18.5) return '偏瘦';
  if (bmi < 24) return '正常';
  if (bmi < 28) return '超重';
  return '肥胖';
}

String _waistHeightLabel(double ratio) {
  if (ratio < 0.4) return '偏低';
  if (ratio < 0.5) return '较低风险';
  if (ratio < 0.6) return '偏高风险';
  return '较高风险';
}

String _weightRangeDelta(double weight, double low, double high) {
  if (weight < low) return '+${formatNumber(low - weight)} kg';
  if (weight > high) return '-${formatNumber(weight - high)} kg';
  return '在范围内';
}

List<ToolResult> fuelEconomyResults(Map<String, double> valuesByKey) {
  final distanceInput = valuesByKey['distance'];
  final fuelInput = valuesByKey['fuel'];
  final consumptionInput = valuesByKey['consumption'];
  final price = valuesByKey['price'] ?? 0;
  final tank = valuesByKey['tank'];
  final annualDistance = valuesByKey['annualDistance'];
  final co2 = valuesByKey['co2'];
  final coreInputCount = [
    distanceInput,
    fuelInput,
    consumptionInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 2 ||
      (distanceInput != null &&
          (distanceInput <= 0 || !distanceInput.isFinite)) ||
      (fuelInput != null && (fuelInput <= 0 || !fuelInput.isFinite)) ||
      (consumptionInput != null &&
          (consumptionInput <= 0 || !consumptionInput.isFinite)) ||
      price < 0 ||
      !price.isFinite ||
      (tank != null && (tank <= 0 || !tank.isFinite)) ||
      (annualDistance != null &&
          (annualDistance < 0 || !annualDistance.isFinite)) ||
      (co2 != null && (co2 < 0 || !co2.isFinite))) {
    return _invalidFuelEconomyResults(
      includeTank: tank != null,
      includeAnnual: annualDistance != null,
      includeCo2: co2 != null,
    );
  }

  double distance;
  double fuel;
  double litersPer100Km;
  String source;
  double? consumptionDelta;
  if (distanceInput != null && fuelInput != null) {
    distance = distanceInput;
    fuel = fuelInput;
    litersPer100Km = fuel / distance * 100;
    consumptionDelta =
        consumptionInput == null ? null : litersPer100Km - consumptionInput;
    source = consumptionInput == null ? '里程+燃油' : '里程+燃油，百公里油耗作参考';
  } else if (distanceInput != null && consumptionInput != null) {
    distance = distanceInput;
    litersPer100Km = consumptionInput;
    fuel = distance * litersPer100Km / 100;
    source = '里程+百公里油耗';
  } else if (fuelInput != null && consumptionInput != null) {
    fuel = fuelInput;
    litersPer100Km = consumptionInput;
    distance = fuel * 100 / litersPer100Km;
    source = '燃油+百公里油耗';
  } else {
    return _invalidFuelEconomyResults(
      includeTank: tank != null,
      includeAnnual: annualDistance != null,
      includeCo2: co2 != null,
    );
  }

  final kmPerLiter = distance / fuel;
  final totalCost = fuel * price;
  final costPerKm = totalCost / distance;
  final costPer100Km = costPerKm * 100;
  final results = <ToolResult>[
    ToolResult('百公里油耗', formatNumber(litersPer100Km), 'L/100km', primary: true),
    ToolResult('km/L', formatNumber(kmPerLiter), 'km/L'),
    ToolResult('里程', formatNumber(distance), 'km'),
    ToolResult('燃油', formatNumber(fuel), 'L'),
    ToolResult('总费用', formatNumber(totalCost), '元'),
    ToolResult('每公里成本', formatNumber(costPerKm), '元/km'),
    ToolResult('百公里成本', formatNumber(costPer100Km), '元/100km'),
    ToolResult('输入来源', source, ''),
    if (consumptionDelta != null)
      ToolResult('油耗差值', formatNumber(consumptionDelta), 'L/100km'),
  ];
  if (tank != null) {
    results.add(ToolResult('满箱续航', formatNumber(tank * kmPerLiter), 'km'));
    results.add(ToolResult('满箱费用', formatNumber(tank * price), '元'));
  }
  if (annualDistance != null) {
    final annualFuel = annualDistance / 100 * litersPer100Km;
    final annualCost = annualFuel * price;
    results.add(ToolResult('年用油量', formatNumber(annualFuel), 'L'));
    results.add(ToolResult('年燃油费用', formatNumber(annualCost), '元'));
    if (tank != null) {
      results.add(ToolResult(
          '年加油次数', formatNumber(tank == 0 ? 0 : annualFuel / tank), '次'));
    }
    if (co2 != null) {
      final annualCo2 = annualFuel * co2;
      results.add(ToolResult(
          'CO2每公里', formatNumber(litersPer100Km * co2 * 10), 'g/km'));
      results.add(ToolResult('年CO2排放', formatNumber(annualCo2), 'kg'));
    }
  } else if (co2 != null) {
    results.add(
        ToolResult('CO2每公里', formatNumber(litersPer100Km * co2 * 10), 'g/km'));
  }
  return results;
}

List<ToolResult> _invalidFuelEconomyResults({
  required bool includeTank,
  required bool includeAnnual,
  required bool includeCo2,
}) {
  return [
    const ToolResult('百公里油耗', '无效', 'L/100km', primary: true),
    const ToolResult('km/L', '无效', 'km/L'),
    const ToolResult('里程', '无效', 'km'),
    const ToolResult('燃油', '无效', 'L'),
    const ToolResult('总费用', '无效', '元'),
    const ToolResult('每公里成本', '无效', '元/km'),
    const ToolResult('百公里成本', '无效', '元/100km'),
    const ToolResult('输入来源', '无效', ''),
    if (includeTank) const ToolResult('满箱续航', '无效', 'km'),
    if (includeTank) const ToolResult('满箱费用', '无效', '元'),
    if (includeAnnual) const ToolResult('年用油量', '无效', 'L'),
    if (includeAnnual) const ToolResult('年燃油费用', '无效', '元'),
    if (includeTank && includeAnnual) const ToolResult('年加油次数', '无效', '次'),
    if (includeCo2) const ToolResult('CO2每公里', '无效', 'g/km'),
    if (includeAnnual && includeCo2) const ToolResult('年CO2排放', '无效', 'kg'),
  ];
}

String _range(double a, double b) {
  final low = math.min(a, b);
  final high = math.max(a, b);
  return '${formatNumber(low)} ~ ${formatNumber(high)}';
}
