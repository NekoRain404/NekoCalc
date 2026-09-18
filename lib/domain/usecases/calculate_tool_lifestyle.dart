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
    ToolResult.number('BMI', bmi, '', primary: true),
    ToolResult('区间', _bmiLabel(bmi), ''),
    ToolResult('健康体重范围', idealRange, 'kg',
        hasError: !healthyWeightLow.isFinite || !healthyWeightHigh.isFinite),
    ToolResult.number('正常体重下限', healthyWeightLow, 'kg'),
    ToolResult.number('正常体重上限', normalUpper, 'kg'),
    ToolResult('距健康区间',
        _weightRangeDelta(weight, healthyWeightLow, healthyWeightHigh), '',
        hasError: _weightDeltaNeedsAttention(
            weight, healthyWeightLow, healthyWeightHigh)),
    ToolResult.number('BMI 22 目标体重', targetWeight, 'kg'),
    ToolResult.number('目标体重差', targetDelta, 'kg'),
    ToolResult.number('体表面积', bsa, 'm²'),
  ];
  if (waistCm != null) {
    final waistHeightRatio = waistCm / heightCm;
    results.add(ToolResult.number('腰高比', waistHeightRatio, ''));
    results.add(ToolResult('腰高比分级', _waistHeightLabel(waistHeightRatio), ''));
  }
  return results;
}

List<ToolResult> _invalidBmiResults({required bool includeWaist}) {
  return [
    const ToolResult.invalid('BMI', '', primary: true),
    const ToolResult.invalid('区间', ''),
    const ToolResult.invalid('健康体重范围', 'kg'),
    const ToolResult.invalid('正常体重下限', 'kg'),
    const ToolResult.invalid('正常体重上限', 'kg'),
    const ToolResult.invalid('距健康区间', 'kg'),
    const ToolResult.invalid('BMI 22 目标体重', 'kg'),
    const ToolResult.invalid('目标体重差', 'kg'),
    const ToolResult.invalid('体表面积', 'm²'),
    if (includeWaist) const ToolResult.invalid('腰高比', ''),
    if (includeWaist) const ToolResult.invalid('腰高比分级', ''),
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

/// 中文：`'距健康区间'` 那条**要不要标成错误**。它与 [ _weightRangeDelta ] 走同一套分支：
///       两支里拼进去的那个数不是有限数时，那句话里才会出现「无效」；`'在范围内'` 不是错误。
/// English: Whether the `'距健康区间'` result **should be marked as an error**. It follows the same
///          branches as [_weightRangeDelta]: the marker only appears when the number interpolated in
///          one of the two branches is not finite; `'在范围内'` is not an error.
bool _weightDeltaNeedsAttention(double weight, double low, double high) {
  if (weight < low) return !(low - weight).isFinite;
  if (weight > high) return !(weight - high).isFinite;
  return false;
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
    ToolResult.number('百公里油耗', litersPer100Km, 'L/100km', primary: true),
    ToolResult.number('km/L', kmPerLiter, 'km/L'),
    ToolResult.number('里程', distance, 'km'),
    ToolResult.number('燃油', fuel, 'L'),
    ToolResult.number('总费用', totalCost, '元'),
    ToolResult.number('每公里成本', costPerKm, '元/km'),
    ToolResult.number('百公里成本', costPer100Km, '元/100km'),
    ToolResult('输入来源', source, ''),
    if (consumptionDelta != null)
      ToolResult.number('油耗差值', consumptionDelta, 'L/100km'),
  ];
  if (tank != null) {
    results.add(ToolResult.number('满箱续航', tank * kmPerLiter, 'km'));
    results.add(ToolResult.number('满箱费用', tank * price, '元'));
  }
  if (annualDistance != null) {
    final annualFuel = annualDistance / 100 * litersPer100Km;
    final annualCost = annualFuel * price;
    results.add(ToolResult.number('年用油量', annualFuel, 'L'));
    results.add(ToolResult.number('年燃油费用', annualCost, '元'));
    if (tank != null) {
      results.add(
          ToolResult.number('年加油次数', tank == 0 ? 0 : annualFuel / tank, '次'));
    }
    if (co2 != null) {
      final annualCo2 = annualFuel * co2;
      results
          .add(ToolResult.number('CO2每公里', litersPer100Km * co2 * 10, 'g/km'));
      results.add(ToolResult.number('年CO2排放', annualCo2, 'kg'));
    }
  } else if (co2 != null) {
    results.add(ToolResult.number('CO2每公里', litersPer100Km * co2 * 10, 'g/km'));
  }
  return results;
}

List<ToolResult> _invalidFuelEconomyResults({
  required bool includeTank,
  required bool includeAnnual,
  required bool includeCo2,
}) {
  return [
    const ToolResult.invalid('百公里油耗', 'L/100km', primary: true),
    const ToolResult.invalid('km/L', 'km/L'),
    const ToolResult.invalid('里程', 'km'),
    const ToolResult.invalid('燃油', 'L'),
    const ToolResult.invalid('总费用', '元'),
    const ToolResult.invalid('每公里成本', '元/km'),
    const ToolResult.invalid('百公里成本', '元/100km'),
    const ToolResult.invalid('输入来源', ''),
    if (includeTank) const ToolResult.invalid('满箱续航', 'km'),
    if (includeTank) const ToolResult.invalid('满箱费用', '元'),
    if (includeAnnual) const ToolResult.invalid('年用油量', 'L'),
    if (includeAnnual) const ToolResult.invalid('年燃油费用', '元'),
    if (includeTank && includeAnnual) const ToolResult.invalid('年加油次数', '次'),
    if (includeCo2) const ToolResult.invalid('CO2每公里', 'g/km'),
    if (includeAnnual && includeCo2) const ToolResult.invalid('年CO2排放', 'kg'),
  ];
}

String _range(double a, double b) {
  final low = math.min(a, b);
  final high = math.max(a, b);
  return '${formatNumber(low)} ~ ${formatNumber(high)}';
}
