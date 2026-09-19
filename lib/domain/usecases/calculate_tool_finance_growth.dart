import 'dart:math' as math;

import '../entities/tool_definition.dart';

List<ToolResult> compoundResults(Map<String, double> valuesByKey) {
  final principalInput = valuesByKey['principal'];
  final rateInput = valuesByKey['rate'];
  final yearsInput = valuesByKey['years'];
  final targetInput = valuesByKey['target'];
  final coreInputCount = [
    principalInput,
    rateInput,
    yearsInput,
    targetInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 3 ||
      (principalInput != null &&
          (principalInput < 0 || !principalInput.isFinite)) ||
      (rateInput != null && (rateInput <= -100 || !rateInput.isFinite)) ||
      (yearsInput != null && (yearsInput < 0 || !yearsInput.isFinite)) ||
      (targetInput != null && (targetInput < 0 || !targetInput.isFinite))) {
    return _invalidCompoundResults();
  }

  double principal;
  double rawRate;
  double years;
  double target;
  String source;
  double? targetDelta;
  if (principalInput != null && rateInput != null && yearsInput != null) {
    principal = principalInput;
    rawRate = rateInput;
    years = yearsInput;
    final multiplier = math.pow(1 + rawRate / 100, years).toDouble();
    if (!multiplier.isFinite || multiplier < 0) {
      return _invalidCompoundResults();
    }
    target = principal * multiplier;
    targetDelta = targetInput == null ? null : target - targetInput;
    source = targetInput == null ? '本金+年化收益+年限' : '本金+年化收益+年限，目标终值作参考';
  } else if (targetInput != null && rateInput != null && yearsInput != null) {
    final multiplier = math.pow(1 + rateInput / 100, yearsInput).toDouble();
    if (!multiplier.isFinite || multiplier <= 0) {
      return _invalidCompoundResults();
    }
    target = targetInput;
    rawRate = rateInput;
    years = yearsInput;
    principal = target / multiplier;
    source = '目标终值+年化收益+年限';
  } else if (principalInput != null &&
      targetInput != null &&
      yearsInput != null) {
    if (principalInput <= 0 || yearsInput <= 0) {
      return _invalidCompoundResults();
    }
    principal = principalInput;
    target = targetInput;
    years = yearsInput;
    rawRate = (math.pow(target / principal, 1 / years).toDouble() - 1) * 100;
    if (rawRate <= -100 || !rawRate.isFinite) {
      return _invalidCompoundResults();
    }
    source = '本金+目标终值+年限';
  } else if (principalInput != null &&
      targetInput != null &&
      rateInput != null) {
    if (principalInput <= 0 || targetInput <= 0 || rateInput == 0) {
      return _invalidCompoundResults();
    }
    final base = 1 + rateInput / 100;
    if (base <= 0 || base == 1) return _invalidCompoundResults();
    principal = principalInput;
    target = targetInput;
    rawRate = rateInput;
    years = math.log(target / principal) / math.log(base);
    if (years < 0 || !years.isFinite) return _invalidCompoundResults();
    source = '本金+目标终值+年化收益';
  } else {
    return _invalidCompoundResults();
  }

  final gain = target - principal;
  final multiple = principal == 0 ? 0.0 : target / principal;
  return [
    ToolResult.number('终值', target, '元', primary: true),
    ToolResult.number('收益', gain, '元'),
    ToolResult.number('收益率', principal == 0 ? 0 : gain / principal * 100, '%'),
    ToolResult.number('本金', principal, '元'),
    ToolResult.number('增长倍数', multiple, 'x'),
    ToolResult.number('年化收益率', rawRate, '%'),
    ToolResult.number('年限', years, '年'),
    ToolResult('输入来源', source, ''),
    if (targetDelta != null) ToolResult.number('终值差值', targetDelta, '元'),
  ];
}

List<ToolResult> _invalidCompoundResults() {
  return const [
    ToolResult.invalid('终值', '元', primary: true),
    ToolResult.invalid('收益', '元'),
    ToolResult.invalid('收益率', '%'),
    ToolResult.invalid('本金', '元'),
    ToolResult.invalid('增长倍数', 'x'),
    ToolResult.invalid('年化收益率', '%'),
    ToolResult.invalid('年限', '年'),
    ToolResult.invalid('输入来源', ''),
  ];
}

List<ToolResult> discountResults(Map<String, double> valuesByKey) {
  final priceInput = valuesByKey['price'];
  final discountInput = valuesByKey['discount'];
  final finalPriceInput = valuesByKey['finalPrice'];
  final coreInputCount = [
    priceInput,
    discountInput,
    finalPriceInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 2 ||
      (priceInput != null && (priceInput <= 0 || !priceInput.isFinite)) ||
      (discountInput != null &&
          (discountInput < 0 ||
              discountInput > 100 ||
              !discountInput.isFinite)) ||
      (finalPriceInput != null &&
          (finalPriceInput < 0 ||
              !finalPriceInput.isFinite ||
              (priceInput != null && finalPriceInput > priceInput)))) {
    return _invalidDiscountResults();
  }

  double price;
  double discount;
  double finalPrice;
  String source;
  double? finalPriceDelta;
  if (priceInput != null && discountInput != null) {
    price = priceInput;
    discount = discountInput;
    finalPrice = price * discount / 100;
    finalPriceDelta =
        finalPriceInput == null ? null : finalPrice - finalPriceInput;
    source = finalPriceInput == null ? '原价+折扣' : '原价+折扣，到手价作参考';
  } else if (priceInput != null && finalPriceInput != null) {
    price = priceInput;
    finalPrice = finalPriceInput;
    discount = finalPrice / price * 100;
    source = '原价+到手价';
  } else if (discountInput != null && finalPriceInput != null) {
    if (discountInput <= 0) return _invalidDiscountResults();
    discount = discountInput;
    finalPrice = finalPriceInput;
    price = finalPrice * 100 / discount;
    source = '折扣+到手价';
  } else {
    return _invalidDiscountResults();
  }

  return [
    ToolResult.number('到手价', finalPrice, '元', primary: true),
    ToolResult.number('原价', price, '元'),
    ToolResult.number('节省', price - finalPrice, '元'),
    ToolResult.number('折扣率', discount, '%'),
    ToolResult.number('优惠比例', 100 - discount, '%'),
    ToolResult.number('每百元支付', discount, '元'),
    ToolResult('输入来源', source, ''),
    if (finalPriceDelta != null)
      ToolResult.number('到手价差值', finalPriceDelta, '元'),
  ];
}

List<ToolResult> _invalidDiscountResults() {
  return const [
    ToolResult.invalid('到手价', '元', primary: true),
    ToolResult.invalid('原价', '元'),
    ToolResult.invalid('节省', '元'),
    ToolResult.invalid('折扣率', '%'),
    ToolResult.invalid('优惠比例', '%'),
    ToolResult.invalid('每百元支付', '元'),
    ToolResult.invalid('输入来源', ''),
  ];
}

List<ToolResult> taxResults(Map<String, double> valuesByKey) {
  final netInput = valuesByKey['net'];
  final rateInput = valuesByKey['rate'];
  final grossInput = valuesByKey['gross'];
  final coreInputCount = [
    netInput,
    rateInput,
    grossInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 2 ||
      (netInput != null && (netInput < 0 || !netInput.isFinite)) ||
      (rateInput != null && (rateInput <= -100 || !rateInput.isFinite)) ||
      (grossInput != null && (grossInput < 0 || !grossInput.isFinite))) {
    return _invalidTaxResults();
  }

  double net;
  double rawRate;
  double gross;
  String source;
  double? grossDelta;
  if (netInput != null && rateInput != null) {
    net = netInput;
    rawRate = rateInput;
    gross = net * (1 + rawRate / 100);
    grossDelta = grossInput == null ? null : gross - grossInput;
    source = grossInput == null ? '税前金额+税率' : '税前金额+税率，含税金额作参考';
  } else if (grossInput != null && rateInput != null) {
    final multiplier = 1 + rateInput / 100;
    if (multiplier <= 0) return _invalidTaxResults();
    gross = grossInput;
    rawRate = rateInput;
    net = gross / multiplier;
    source = '含税金额+税率';
  } else if (netInput != null && grossInput != null) {
    if (netInput <= 0) return _invalidTaxResults();
    net = netInput;
    gross = grossInput;
    rawRate = (gross / net - 1) * 100;
    if (rawRate <= -100 || !rawRate.isFinite) return _invalidTaxResults();
    source = '税前金额+含税金额';
  } else {
    return _invalidTaxResults();
  }

  final tax = gross - net;
  return [
    ToolResult.number('含税金额', gross, '元', primary: true),
    ToolResult.number('税额', tax, '元'),
    ToolResult.number('不含税反推', net, '元'),
    ToolResult.number('税率', rawRate, '%'),
    ToolResult.number('税负率', gross == 0 ? 0 : tax / gross * 100, '%'),
    ToolResult.number('价税合计倍率', 1 + rawRate / 100, 'x'),
    ToolResult('输入来源', source, ''),
    if (grossDelta != null) ToolResult.number('含税金额差值', grossDelta, '元'),
  ];
}

List<ToolResult> _invalidTaxResults() {
  return const [
    ToolResult.invalid('含税金额', '元', primary: true),
    ToolResult.invalid('税额', '元'),
    ToolResult.invalid('不含税反推', '元'),
    ToolResult.invalid('税率', '%'),
    ToolResult.invalid('税负率', '%'),
    ToolResult.invalid('价税合计倍率', 'x'),
    ToolResult.invalid('输入来源', ''),
  ];
}

List<ToolResult> inflationResults(Map<String, double> valuesByKey) {
  final amountInput = valuesByKey['amount'];
  final rateInput = valuesByKey['rate'];
  final yearsInput = valuesByKey['years'];
  final futureInput = valuesByKey['future'];
  final coreInputCount = [
    amountInput,
    rateInput,
    yearsInput,
    futureInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 3 ||
      (amountInput != null && (amountInput < 0 || !amountInput.isFinite)) ||
      (rateInput != null && (rateInput <= -100 || !rateInput.isFinite)) ||
      (yearsInput != null && (yearsInput < 0 || !yearsInput.isFinite)) ||
      (futureInput != null && (futureInput < 0 || !futureInput.isFinite))) {
    return _invalidInflationResults();
  }

  double amount;
  double rawRate;
  double years;
  double future;
  double multiplier;
  String source;
  double? futureDelta;
  if (amountInput != null && rateInput != null && yearsInput != null) {
    amount = amountInput;
    rawRate = rateInput;
    years = yearsInput;
    multiplier = math.pow(1 + rawRate / 100, years).toDouble();
    future = amount * multiplier;
    futureDelta = futureInput == null ? null : future - futureInput;
    source = futureInput == null ? '当前金额+年通胀率+年数' : '当前金额+年通胀率+年数，未来等值作参考';
  } else if (futureInput != null && rateInput != null && yearsInput != null) {
    multiplier = math.pow(1 + rateInput / 100, yearsInput).toDouble();
    if (multiplier <= 0 || !multiplier.isFinite) {
      return _invalidInflationResults();
    }
    future = futureInput;
    rawRate = rateInput;
    years = yearsInput;
    amount = future / multiplier;
    source = '未来等值+年通胀率+年数';
  } else if (amountInput != null && futureInput != null && yearsInput != null) {
    if (amountInput <= 0 || yearsInput <= 0) {
      return _invalidInflationResults();
    }
    amount = amountInput;
    future = futureInput;
    years = yearsInput;
    multiplier = future / amount;
    rawRate = (math.pow(future / amount, 1 / years).toDouble() - 1) * 100;
    if (rawRate <= -100 || !rawRate.isFinite) {
      return _invalidInflationResults();
    }
    source = '当前金额+未来等值+年数';
  } else if (amountInput != null && futureInput != null && rateInput != null) {
    if (amountInput <= 0 || futureInput <= 0 || rateInput == 0) {
      return _invalidInflationResults();
    }
    final base = 1 + rateInput / 100;
    if (base <= 0 || base == 1) return _invalidInflationResults();
    amount = amountInput;
    future = futureInput;
    rawRate = rateInput;
    multiplier = future / amount;
    years = math.log(future / amount) / math.log(base);
    if (years < 0 || !years.isFinite) return _invalidInflationResults();
    source = '当前金额+未来等值+年通胀率';
  } else {
    return _invalidInflationResults();
  }

  if (!multiplier.isFinite || multiplier <= 0) {
    return _invalidInflationResults();
  }
  final presentPower = amount / multiplier;
  return [
    ToolResult.number('未来等值', future, '元', primary: true),
    ToolResult.number('当前金额', amount, '元'),
    ToolResult.number('年通胀率', rawRate, '%'),
    ToolResult.number('年数', years, '年'),
    ToolResult.number('购买力折现', presentPower, '元'),
    ToolResult.number('累计涨幅', (multiplier - 1) * 100, '%'),
    ToolResult.number('购买力损失', amount - presentPower, '元'),
    ToolResult.number('等值倍率', multiplier, 'x'),
    ToolResult('输入来源', source, ''),
    if (futureDelta != null) ToolResult.number('未来等值差值', futureDelta, '元'),
  ];
}

List<ToolResult> _invalidInflationResults() {
  return const [
    ToolResult.invalid('未来等值', '元', primary: true),
    ToolResult.invalid('当前金额', '元'),
    ToolResult.invalid('年通胀率', '%'),
    ToolResult.invalid('年数', '年'),
    ToolResult.invalid('购买力折现', '元'),
    ToolResult.invalid('累计涨幅', '%'),
    ToolResult.invalid('购买力损失', '元'),
    ToolResult.invalid('等值倍率', 'x'),
    ToolResult.invalid('输入来源', ''),
  ];
}

List<ToolResult> npvResults(Map<String, double> valuesByKey) {
  final initial = valuesByKey['initial'] ?? 0;
  final ratePercent = valuesByKey['rate'] ?? 0;
  final rate = ratePercent / 100;
  final cashFlows = <double>[];
  for (var period = 1; period <= 5; period++) {
    final value = valuesByKey['cf$period'];
    if (value != null) cashFlows.add(value);
  }
  if (initial < 0 ||
      rate <= -1 ||
      !initial.isFinite ||
      !rate.isFinite ||
      cashFlows.isEmpty ||
      cashFlows.any((value) => !value.isFinite)) {
    return _invalidNpvResults();
  }

  final discounted = <double>[];
  for (var index = 0; index < cashFlows.length; index++) {
    discounted.add(cashFlows[index] / math.pow(1 + rate, index + 1));
  }
  final totalCashFlow = cashFlows.fold<double>(0, (sum, item) => sum + item);
  final discountedCashFlow =
      discounted.fold<double>(0, (sum, item) => sum + item);
  final npv = discountedCashFlow - initial;
  final discountedBalance = _paybackPeriod(initial, discounted);
  final simpleBalance = _paybackPeriod(initial, cashFlows);
  final rateLow = math.max(-99.0, ratePercent - 2);
  final rateHigh = ratePercent + 2;
  final npvLow = _npvAtRate(initial, cashFlows, rateLow / 100);
  final npvHigh = _npvAtRate(initial, cashFlows, rateHigh / 100);
  final averageAnnualReturn =
      initial == 0 || discountedCashFlow < 0 || cashFlows.isEmpty
          ? double.nan
          : (math
                      .pow(discountedCashFlow / initial, 1 / cashFlows.length)
                      .toDouble() -
                  1) *
              100;

  return [
    ToolResult.number('NPV', npv, '元', primary: true),
    ToolResult('期数', '${cashFlows.length}', '期'),
    ToolResult.number('总现金流', totalCashFlow, '元'),
    ToolResult.number('折现现金流', discountedCashFlow, '元'),
    ToolResult.number(
        '盈利指数', initial == 0 ? null : discountedCashFlow / initial, 'x'),
    ToolResult.number('回收差额', totalCashFlow - initial, '元'),
    // 中文：`null`（算不出来）时屏幕上是 `'未回收'`——**那不是错误**；有数时值就是数值本身，
    //       不是有限数时才会变成那条记号。两支分开写，省得把两个问题搅在一起。
    // English: when `null` (cannot be computed) the screen shows `'未回收'` — **that is not an
    //          error**; with a number the value is that number, and only a non-finite one turns into
    //          the marker. Written as two branches so the two questions do not get mixed up.
    // 中文：**这两支的结论走令牌，值从表里来**——下游那两句提示
    //       （`tool_insights_finance.dart`）读的是令牌，不再回读这句话。理由与病史见
    //       `ToolResultConclusion`。
    // English: **these two branches' conclusion goes through the token and the value comes from the
    //          table** — the two hint lines downstream (`tool_insights_finance.dart`) read the token
    //          instead of this sentence. See `ToolResultConclusion` for the reasons and the history.
    if (discountedBalance == null)
      ToolResult.conclusion(
          '折现回收期', ToolResultConclusion.neverRecovers, '期')
    else
      ToolResult.number('折现回收期', discountedBalance, '期'),
    if (simpleBalance == null)
      ToolResult.conclusion(
          '简单回收期', ToolResultConclusion.neverRecovers, '期')
    else
      ToolResult.number('简单回收期', simpleBalance, '期'),
    ToolResult.number('折现率-2% NPV', npvLow, '元'),
    ToolResult.number('折现率+2% NPV', npvHigh, '元'),
    ToolResult.number('等效年化收益',
        averageAnnualReturn.isFinite ? averageAnnualReturn : null, '%'),
  ];
}

List<ToolResult> _invalidNpvResults() {
  return const [
    ToolResult.invalid('NPV', '元', primary: true),
    ToolResult.invalid('期数', '期'),
    ToolResult.invalid('总现金流', '元'),
    ToolResult.invalid('折现现金流', '元'),
    ToolResult.invalid('盈利指数', 'x'),
    ToolResult.invalid('回收差额', '元'),
    ToolResult.invalid('折现回收期', '期'),
    ToolResult.invalid('简单回收期', '期'),
  ];
}

double _npvAtRate(double initial, List<double> cashFlows, double rate) {
  var discounted = 0.0;
  for (var index = 0; index < cashFlows.length; index++) {
    discounted += cashFlows[index] / math.pow(1 + rate, index + 1);
  }
  return discounted - initial;
}

double? _paybackPeriod(double initial, List<double> cashFlows) {
  if (initial <= 0) return 0;
  var recovered = 0.0;
  for (var index = 0; index < cashFlows.length; index++) {
    final flow = cashFlows[index];
    final next = recovered + flow;
    if (flow > 0 && next >= initial) {
      final remaining = initial - recovered;
      return index + remaining / flow;
    }
    recovered = next;
  }
  return null;
}
