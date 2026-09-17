import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
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
    ToolResult('终值', formatNumber(target), '元', primary: true),
    ToolResult('收益', formatNumber(gain), '元'),
    ToolResult(
        '收益率', formatNumber(principal == 0 ? 0 : gain / principal * 100), '%'),
    ToolResult('本金', formatNumber(principal), '元'),
    ToolResult('增长倍数', formatNumber(multiple), 'x'),
    ToolResult('年化收益率', formatNumber(rawRate), '%'),
    ToolResult('年限', formatNumber(years), '年'),
    ToolResult('输入来源', source, ''),
    if (targetDelta != null) ToolResult('终值差值', formatNumber(targetDelta), '元'),
  ];
}

List<ToolResult> _invalidCompoundResults() {
  return const [
    ToolResult('终值', '无效', '元', primary: true),
    ToolResult('收益', '无效', '元'),
    ToolResult('收益率', '无效', '%'),
    ToolResult('本金', '无效', '元'),
    ToolResult('增长倍数', '无效', 'x'),
    ToolResult('年化收益率', '无效', '%'),
    ToolResult('年限', '无效', '年'),
    ToolResult('输入来源', '无效', ''),
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
    ToolResult('到手价', formatNumber(finalPrice), '元', primary: true),
    ToolResult('原价', formatNumber(price), '元'),
    ToolResult('节省', formatNumber(price - finalPrice), '元'),
    ToolResult('折扣率', formatNumber(discount), '%'),
    ToolResult('优惠比例', formatNumber(100 - discount), '%'),
    ToolResult('每百元支付', formatNumber(discount), '元'),
    ToolResult('输入来源', source, ''),
    if (finalPriceDelta != null)
      ToolResult('到手价差值', formatNumber(finalPriceDelta), '元'),
  ];
}

List<ToolResult> _invalidDiscountResults() {
  return const [
    ToolResult('到手价', '无效', '元', primary: true),
    ToolResult('原价', '无效', '元'),
    ToolResult('节省', '无效', '元'),
    ToolResult('折扣率', '无效', '%'),
    ToolResult('优惠比例', '无效', '%'),
    ToolResult('每百元支付', '无效', '元'),
    ToolResult('输入来源', '无效', ''),
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
    ToolResult('含税金额', formatNumber(gross), '元', primary: true),
    ToolResult('税额', formatNumber(tax), '元'),
    ToolResult('不含税反推', formatNumber(net), '元'),
    ToolResult('税率', formatNumber(rawRate), '%'),
    ToolResult('税负率', gross == 0 ? '0' : formatNumber(tax / gross * 100), '%'),
    ToolResult('价税合计倍率', formatNumber(1 + rawRate / 100), 'x'),
    ToolResult('输入来源', source, ''),
    if (grossDelta != null) ToolResult('含税金额差值', formatNumber(grossDelta), '元'),
  ];
}

List<ToolResult> _invalidTaxResults() {
  return const [
    ToolResult('含税金额', '无效', '元', primary: true),
    ToolResult('税额', '无效', '元'),
    ToolResult('不含税反推', '无效', '元'),
    ToolResult('税率', '无效', '%'),
    ToolResult('税负率', '无效', '%'),
    ToolResult('价税合计倍率', '无效', 'x'),
    ToolResult('输入来源', '无效', ''),
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
    ToolResult('未来等值', formatNumber(future), '元', primary: true),
    ToolResult('当前金额', formatNumber(amount), '元'),
    ToolResult('年通胀率', formatNumber(rawRate), '%'),
    ToolResult('年数', formatNumber(years), '年'),
    ToolResult('购买力折现', formatNumber(presentPower), '元'),
    ToolResult('累计涨幅', formatNumber((multiplier - 1) * 100), '%'),
    ToolResult('购买力损失', formatNumber(amount - presentPower), '元'),
    ToolResult('等值倍率', formatNumber(multiplier), 'x'),
    ToolResult('输入来源', source, ''),
    if (futureDelta != null)
      ToolResult('未来等值差值', formatNumber(futureDelta), '元'),
  ];
}

List<ToolResult> _invalidInflationResults() {
  return const [
    ToolResult('未来等值', '无效', '元', primary: true),
    ToolResult('当前金额', '无效', '元'),
    ToolResult('年通胀率', '无效', '%'),
    ToolResult('年数', '无效', '年'),
    ToolResult('购买力折现', '无效', '元'),
    ToolResult('累计涨幅', '无效', '%'),
    ToolResult('购买力损失', '无效', '元'),
    ToolResult('等值倍率', '无效', 'x'),
    ToolResult('输入来源', '无效', ''),
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
    ToolResult('NPV', formatNumber(npv), '元', primary: true),
    ToolResult('期数', '${cashFlows.length}', '期'),
    ToolResult('总现金流', formatNumber(totalCashFlow), '元'),
    ToolResult('折现现金流', formatNumber(discountedCashFlow), '元'),
    ToolResult(
      '盈利指数',
      initial == 0 ? '无效' : formatNumber(discountedCashFlow / initial),
      'x',
    ),
    ToolResult('回收差额', formatNumber(totalCashFlow - initial), '元'),
    ToolResult('折现回收期', _formatPayback(discountedBalance), '期'),
    ToolResult('简单回收期', _formatPayback(simpleBalance), '期'),
    ToolResult('折现率-2% NPV', formatNumber(npvLow), '元'),
    ToolResult('折现率+2% NPV', formatNumber(npvHigh), '元'),
    ToolResult(
      '等效年化收益',
      averageAnnualReturn.isFinite ? formatNumber(averageAnnualReturn) : '无效',
      '%',
    ),
  ];
}

List<ToolResult> _invalidNpvResults() {
  return const [
    ToolResult('NPV', '无效', '元', primary: true),
    ToolResult('期数', '无效', '期'),
    ToolResult('总现金流', '无效', '元'),
    ToolResult('折现现金流', '无效', '元'),
    ToolResult('盈利指数', '无效', 'x'),
    ToolResult('回收差额', '无效', '元'),
    ToolResult('折现回收期', '无效', '期'),
    ToolResult('简单回收期', '无效', '期'),
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

String _formatPayback(double? value) {
  return value == null ? '未回收' : formatNumber(value);
}
