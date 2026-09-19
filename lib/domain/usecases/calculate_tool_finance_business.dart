import 'dart:math' as math;

import '../entities/tool_definition.dart';

List<ToolResult> roiResults(Map<String, double> valuesByKey) {
  final gainInput = valuesByKey['gain'];
  final costInput = valuesByKey['cost'];
  final roiInput = valuesByKey['roi'];
  final years = valuesByKey['years'];
  final coreInputCount = [
    gainInput,
    costInput,
    roiInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 2 ||
      (gainInput != null && (gainInput < 0 || !gainInput.isFinite)) ||
      (costInput != null && (costInput <= 0 || !costInput.isFinite)) ||
      (roiInput != null && (roiInput < -100 || !roiInput.isFinite)) ||
      (years != null && (years <= 0 || !years.isFinite))) {
    return _invalidRoiResults(includeYears: years != null);
  }

  double gain;
  double cost;
  double roi;
  String source;
  double? roiDelta;
  if (gainInput != null && costInput != null) {
    gain = gainInput;
    cost = costInput;
    roi = (gain - cost) / cost * 100;
    roiDelta = roiInput == null ? null : roi - roiInput;
    source = roiInput == null ? '收益+投入' : '收益+投入，ROI作参考';
  } else if (costInput != null && roiInput != null) {
    cost = costInput;
    roi = roiInput;
    gain = cost * (1 + roi / 100);
    source = '投入+ROI';
  } else if (gainInput != null && roiInput != null) {
    if (roiInput <= -100) {
      return _invalidRoiResults(includeYears: years != null);
    }
    gain = gainInput;
    roi = roiInput;
    cost = gain / (1 + roi / 100);
    source = '收益+ROI';
  } else {
    return _invalidRoiResults(includeYears: years != null);
  }

  final net = gain - cost;
  final multiple = gain / cost;
  final results = <ToolResult>[
    ToolResult.number('ROI', roi, '%', primary: true),
    ToolResult.number('收益', gain, '元'),
    ToolResult.number('投入', cost, '元'),
    ToolResult.number('净收益', net, '元'),
    ToolResult.number('回报倍数', multiple, 'x'),
    ToolResult.number('回本率', multiple * 100, '%'),
    ToolResult.number('盈亏平衡差额', net, '元'),
    ToolResult('输入来源', source, ''),
    if (roiDelta != null) ToolResult.number('ROI差值', roiDelta, '%'),
  ];
  if (years != null) {
    final annualMultiple =
        multiple < 0 ? double.nan : math.pow(multiple, 1 / years).toDouble();
    final annualRoi = (annualMultiple - 1) * 100;
    final monthlyNet = net / (years * 12);
    final paybackYears = net <= 0 ? double.nan : cost / (net / years);
    results.addAll([
      ToolResult.number('持有年限', years, '年'),
      ToolResult.number('年化ROI', annualRoi, '%'),
      ToolResult.number('年化回报倍数', annualMultiple, 'x'),
      ToolResult.number('月均净收益', monthlyNet, '元/月'),
      // 中文：算不出有限数时屏幕上是 `'未回收'`——**那不是错误**。
      // English: when no finite number comes out the screen shows `'未回收'` — **that is not an
      //          error**.
      if (!paybackYears.isFinite)
        // 中文：**结论走令牌，值从表里来**——下游那句提示（`tool_insights_finance.dart`）读的是
        //       令牌，不再回读这句话。理由与病史见 `ToolResultConclusion`。
        // English: **a conclusion goes through the token and the value comes from the table** — the
        //          hint line downstream (`tool_insights_finance.dart`) reads the token instead of this
        //          sentence. See `ToolResultConclusion` for the reasons and the history.
        ToolResult.conclusion(
            '简单回收期', ToolResultConclusion.neverRecovers, '年')
      else
        ToolResult.number('简单回收期', paybackYears, '年'),
    ]);
  }
  return results;
}

List<ToolResult> _invalidRoiResults({required bool includeYears}) {
  return [
    const ToolResult.invalid('ROI', '%', primary: true),
    const ToolResult.invalid('收益', '元'),
    const ToolResult.invalid('投入', '元'),
    const ToolResult.invalid('净收益', '元'),
    const ToolResult.invalid('回报倍数', 'x'),
    const ToolResult.invalid('回本率', '%'),
    const ToolResult.invalid('盈亏平衡差额', '元'),
    const ToolResult.invalid('输入来源', ''),
    if (includeYears) const ToolResult.invalid('持有年限', '年'),
    if (includeYears) const ToolResult.invalid('年化ROI', '%'),
    if (includeYears) const ToolResult.invalid('年化回报倍数', 'x'),
    if (includeYears) const ToolResult.invalid('月均净收益', '元/月'),
    if (includeYears) const ToolResult.invalid('简单回收期', '年'),
  ];
}

List<ToolResult> profitMarginResults(Map<String, double> valuesByKey) {
  final costInput = valuesByKey['cost'];
  final priceInput = valuesByKey['price'];
  final marginInput = valuesByKey['margin'];
  final profitInput = valuesByKey['profit'];
  final coreInputCount = [
    costInput,
    priceInput,
    marginInput,
    profitInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 2 ||
      (costInput != null && (costInput < 0 || !costInput.isFinite)) ||
      (priceInput != null && (priceInput <= 0 || !priceInput.isFinite)) ||
      (marginInput != null && (marginInput >= 100 || !marginInput.isFinite)) ||
      (profitInput != null && !profitInput.isFinite)) {
    return _invalidProfitMarginResults();
  }

  double cost;
  double price;
  double profit;
  double margin;
  String source;
  double? profitDelta;
  double? marginDelta;
  if (costInput != null && priceInput != null) {
    cost = costInput;
    price = priceInput;
    profit = price - cost;
    margin = profit / price * 100;
    profitDelta = profitInput == null ? null : profit - profitInput;
    marginDelta = marginInput == null ? null : margin - marginInput;
    source =
        marginInput == null && profitInput == null ? '成本+售价' : '成本+售价，目标值作参考';
  } else if (costInput != null && marginInput != null) {
    final denominator = 1 - marginInput / 100;
    if (denominator <= 0) return _invalidProfitMarginResults();
    cost = costInput;
    margin = marginInput;
    price = cost / denominator;
    profit = price - cost;
    source = '成本+目标毛利率';
  } else if (priceInput != null && marginInput != null) {
    price = priceInput;
    margin = marginInput;
    profit = price * margin / 100;
    cost = price - profit;
    if (cost < 0) return _invalidProfitMarginResults();
    source = '售价+目标毛利率';
  } else if (costInput != null && profitInput != null) {
    cost = costInput;
    profit = profitInput;
    price = cost + profit;
    if (price <= 0) return _invalidProfitMarginResults();
    margin = profit / price * 100;
    source = '成本+目标利润';
  } else if (priceInput != null && profitInput != null) {
    price = priceInput;
    profit = profitInput;
    cost = price - profit;
    if (cost < 0) return _invalidProfitMarginResults();
    margin = profit / price * 100;
    source = '售价+目标利润';
  } else if (marginInput != null && profitInput != null) {
    if (marginInput == 0) return _invalidProfitMarginResults();
    margin = marginInput;
    profit = profitInput;
    price = profit / (margin / 100);
    cost = price - profit;
    if (price <= 0 || cost < 0) return _invalidProfitMarginResults();
    source = '目标毛利率+目标利润';
  } else {
    return _invalidProfitMarginResults();
  }

  return [
    ToolResult.number('利润', profit, '元', primary: true),
    ToolResult.number('成本', cost, '元'),
    ToolResult.number('售价', price, '元'),
    ToolResult.number('毛利率', margin, '%'),
    ToolResult.number('加价率', cost == 0 ? null : profit / cost * 100, '%'),
    ToolResult.number('成本占比', cost / price * 100, '%'),
    ToolResult.number('保本售价', cost, '元'),
    ToolResult('利润状态', profit > 0 ? '盈利' : (profit < 0 ? '亏损' : '持平'), ''),
    ToolResult('输入来源', source, ''),
    if (profitDelta != null) ToolResult.number('利润差值', profitDelta, '元'),
    if (marginDelta != null) ToolResult.number('毛利率差值', marginDelta, '%'),
  ];
}

List<ToolResult> _invalidProfitMarginResults() {
  return const [
    ToolResult.invalid('利润', '元', primary: true),
    ToolResult.invalid('成本', '元'),
    ToolResult.invalid('售价', '元'),
    ToolResult.invalid('毛利率', '%'),
    ToolResult.invalid('加价率', '%'),
    ToolResult.invalid('成本占比', '%'),
    ToolResult.invalid('保本售价', '元'),
    ToolResult.invalid('利润状态', ''),
    ToolResult.invalid('输入来源', ''),
  ];
}

List<ToolResult> electricityCostResults(Map<String, double> valuesByKey) {
  final powerInput = valuesByKey['power'];
  final hoursInput = valuesByKey['hours'];
  final daysInput = valuesByKey['days'];
  final priceInput = valuesByKey['price'];
  final targetCostInput = valuesByKey['targetCost'];
  final coreInputCount = [
    powerInput,
    hoursInput,
    daysInput,
    priceInput,
    targetCostInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 4 ||
      (powerInput != null && (powerInput < 0 || !powerInput.isFinite)) ||
      (hoursInput != null &&
          (hoursInput < 0 || hoursInput > 24 || !hoursInput.isFinite)) ||
      (daysInput != null && (daysInput < 0 || !daysInput.isFinite)) ||
      (priceInput != null && (priceInput < 0 || !priceInput.isFinite)) ||
      (targetCostInput != null &&
          (targetCostInput < 0 || !targetCostInput.isFinite))) {
    return _invalidElectricityCostResults();
  }

  double powerW;
  double hours;
  double days;
  double price;
  double cost;
  String source;
  double? costDelta;
  if (powerInput != null &&
      hoursInput != null &&
      daysInput != null &&
      priceInput != null) {
    powerW = powerInput;
    hours = hoursInput;
    days = daysInput;
    price = priceInput;
    cost = powerW / 1000 * hours * days * price;
    costDelta = targetCostInput == null ? null : cost - targetCostInput;
    source =
        targetCostInput == null ? '功率+每日使用+天数+电价' : '功率+每日使用+天数+电价，目标费用作参考';
  } else if (targetCostInput != null &&
      hoursInput != null &&
      daysInput != null &&
      priceInput != null) {
    final denominator = hoursInput * daysInput * priceInput;
    if (denominator <= 0) return _invalidElectricityCostResults();
    cost = targetCostInput;
    hours = hoursInput;
    days = daysInput;
    price = priceInput;
    powerW = cost * 1000 / denominator;
    source = '目标费用+每日使用+天数+电价';
  } else if (targetCostInput != null &&
      powerInput != null &&
      daysInput != null &&
      priceInput != null) {
    final denominator = powerInput / 1000 * daysInput * priceInput;
    if (denominator <= 0) return _invalidElectricityCostResults();
    cost = targetCostInput;
    powerW = powerInput;
    days = daysInput;
    price = priceInput;
    hours = cost / denominator;
    if (hours > 24) return _invalidElectricityCostResults();
    source = '目标费用+功率+天数+电价';
  } else if (targetCostInput != null &&
      powerInput != null &&
      hoursInput != null &&
      priceInput != null) {
    final denominator = powerInput / 1000 * hoursInput * priceInput;
    if (denominator <= 0) return _invalidElectricityCostResults();
    cost = targetCostInput;
    powerW = powerInput;
    hours = hoursInput;
    price = priceInput;
    days = cost / denominator;
    source = '目标费用+功率+每日使用+电价';
  } else if (targetCostInput != null &&
      powerInput != null &&
      hoursInput != null &&
      daysInput != null) {
    final denominator = powerInput / 1000 * hoursInput * daysInput;
    if (denominator <= 0) return _invalidElectricityCostResults();
    cost = targetCostInput;
    powerW = powerInput;
    hours = hoursInput;
    days = daysInput;
    price = cost / denominator;
    source = '目标费用+功率+每日使用+天数';
  } else {
    return _invalidElectricityCostResults();
  }

  final powerKw = powerW / 1000;
  final energy = powerKw * hours * days;
  final dailyEnergy = powerKw * hours;
  final dailyCost = days == 0 ? 0.0 : cost / days;
  return [
    ToolResult.number('费用', cost, '元', primary: true),
    ToolResult.number('用电量', energy, 'kWh'),
    ToolResult.number('功率', powerW, 'W'),
    ToolResult.number('每日使用', hours, 'h'),
    ToolResult.number('天数', days, '天'),
    ToolResult.number('电价', price, '元/kWh'),
    ToolResult.number('日均费用', dailyCost, '元/天'),
    ToolResult.number('日均用电', dailyEnergy, 'kWh/天'),
    ToolResult.number('月化费用', dailyCost * 30, '元/月'),
    ToolResult.number('年化费用', dailyCost * 365, '元/年'),
    ToolResult('输入来源', source, ''),
    if (costDelta != null) ToolResult.number('费用差值', costDelta, '元'),
  ];
}

List<ToolResult> _invalidElectricityCostResults() {
  return const [
    ToolResult.invalid('费用', '元', primary: true),
    ToolResult.invalid('用电量', 'kWh'),
    ToolResult.invalid('功率', 'W'),
    ToolResult.invalid('每日使用', 'h'),
    ToolResult.invalid('天数', '天'),
    ToolResult.invalid('电价', '元/kWh'),
    ToolResult.invalid('日均费用', '元/天'),
    ToolResult.invalid('日均用电', 'kWh/天'),
    ToolResult.invalid('月化费用', '元/月'),
    ToolResult.invalid('年化费用', '元/年'),
    ToolResult.invalid('输入来源', ''),
  ];
}

List<ToolResult> breakEvenResults(Map<String, double> valuesByKey) {
  final fixedInput = valuesByKey['fixed'];
  final priceInput = valuesByKey['price'];
  final variableInput = valuesByKey['variable'];
  final targetQuantityInput = valuesByKey['targetQuantity'];
  final coreInputCount = [
    fixedInput,
    priceInput,
    variableInput,
    targetQuantityInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 3 ||
      (fixedInput != null && (fixedInput < 0 || !fixedInput.isFinite)) ||
      (priceInput != null && (priceInput <= 0 || !priceInput.isFinite)) ||
      (variableInput != null &&
          (variableInput < 0 || !variableInput.isFinite)) ||
      (targetQuantityInput != null &&
          (targetQuantityInput <= 0 || !targetQuantityInput.isFinite))) {
    return _invalidBreakEvenResults();
  }

  double fixed;
  double price;
  double variable;
  double quantity;
  String source;
  double? quantityDelta;
  if (fixedInput != null && priceInput != null && variableInput != null) {
    fixed = fixedInput;
    price = priceInput;
    variable = variableInput;
    final margin = price - variable;
    if (margin <= 0) {
      return _invalidBreakEvenResults(margin: margin, price: price);
    }
    quantity = fixed / margin;
    quantityDelta =
        targetQuantityInput == null ? null : quantity - targetQuantityInput;
    source = targetQuantityInput == null
        ? '固定成本+单价+单位变动成本'
        : '固定成本+单价+单位变动成本，目标销量作参考';
  } else if (targetQuantityInput != null &&
      priceInput != null &&
      variableInput != null) {
    final margin = priceInput - variableInput;
    if (margin <= 0) {
      return _invalidBreakEvenResults(margin: margin, price: priceInput);
    }
    quantity = targetQuantityInput;
    price = priceInput;
    variable = variableInput;
    fixed = quantity * margin;
    source = '目标销量+单价+单位变动成本';
  } else if (targetQuantityInput != null &&
      fixedInput != null &&
      variableInput != null) {
    quantity = targetQuantityInput;
    fixed = fixedInput;
    variable = variableInput;
    price = fixed / quantity + variable;
    if (price <= 0) return _invalidBreakEvenResults();
    source = '目标销量+固定成本+单位变动成本';
  } else if (targetQuantityInput != null &&
      fixedInput != null &&
      priceInput != null) {
    quantity = targetQuantityInput;
    fixed = fixedInput;
    price = priceInput;
    variable = price - fixed / quantity;
    if (variable < 0) return _invalidBreakEvenResults();
    source = '目标销量+固定成本+单价';
  } else {
    return _invalidBreakEvenResults();
  }

  final margin = price - variable;
  if (margin <= 0) {
    return _invalidBreakEvenResults(margin: margin, price: price);
  }
  return [
    ToolResult.number('平衡销量', quantity, '件', primary: true),
    ToolResult('向上取整销量', quantity.ceil().toString(), '件'),
    ToolResult.number('固定成本', fixed, '元'),
    ToolResult.number('单价', price, '元'),
    ToolResult.number('单位变动成本', variable, '元'),
    ToolResult.number('边际贡献', margin, '元/件'),
    ToolResult.number('边际率', margin / price * 100, '%'),
    ToolResult.number('平衡销售额', quantity * price, '元'),
    ToolResult.number('平衡变动成本', quantity * variable, '元'),
    ToolResult('输入来源', source, ''),
    if (quantityDelta != null) ToolResult.number('销量差值', quantityDelta, '件'),
  ];
}

List<ToolResult> _invalidBreakEvenResults({double? margin, double? price}) {
  return [
    const ToolResult.invalid('平衡销量', '件', primary: true),
    const ToolResult.invalid('向上取整销量', '件'),
    const ToolResult.invalid('固定成本', '元'),
    const ToolResult.invalid('单价', '元'),
    const ToolResult.invalid('单位变动成本', '元'),
    ToolResult.number('边际贡献', margin, '元/件'),
    ToolResult.number(
        '边际率',
        margin == null || price == null || price == 0
            ? null
            : margin / price * 100,
        '%'),
    const ToolResult.invalid('平衡销售额', '元'),
    const ToolResult.invalid('平衡变动成本', '元'),
    const ToolResult.invalid('输入来源', ''),
  ];
}
