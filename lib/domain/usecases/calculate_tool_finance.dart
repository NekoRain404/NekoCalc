import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> loanResults(Map<String, double> valuesByKey) {
  final amountInput = valuesByKey['amount'];
  final rateInput = valuesByKey['rate'];
  final yearsInput = valuesByKey['years'];
  final targetPaymentInput = valuesByKey['targetPayment'];
  final coreInputCount = [
    amountInput,
    rateInput,
    yearsInput,
    targetPaymentInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 3 ||
      (amountInput != null && (amountInput < 0 || !amountInput.isFinite)) ||
      (rateInput != null && (rateInput <= -100 || !rateInput.isFinite)) ||
      (yearsInput != null && (yearsInput <= 0 || !yearsInput.isFinite)) ||
      (targetPaymentInput != null &&
          (targetPaymentInput < 0 || !targetPaymentInput.isFinite))) {
    return _invalidLoanResults();
  }

  double amount;
  double rate;
  double years;
  double monthlyPayment;
  String source;
  double? paymentDelta;
  if (amountInput != null && rateInput != null && yearsInput != null) {
    amount = amountInput;
    rate = rateInput;
    years = yearsInput;
    final principal = amount * 10000;
    final months = (years * 12).round();
    monthlyPayment = _loanPayment(principal, rate, months);
    if (!monthlyPayment.isFinite) return _invalidLoanResults();
    paymentDelta =
        targetPaymentInput == null ? null : monthlyPayment - targetPaymentInput;
    source =
        targetPaymentInput == null ? '贷款金额+年利率+贷款年限' : '贷款金额+年利率+贷款年限，目标月供作参考';
  } else if (targetPaymentInput != null &&
      rateInput != null &&
      yearsInput != null) {
    rate = rateInput;
    years = yearsInput;
    monthlyPayment = targetPaymentInput;
    final months = (years * 12).round();
    final paymentPerPrincipal = _loanPayment(1, rate, months);
    if (paymentPerPrincipal <= 0 || !paymentPerPrincipal.isFinite) {
      return _invalidLoanResults();
    }
    amount = monthlyPayment / paymentPerPrincipal / 10000;
    source = '目标月供+年利率+贷款年限';
  } else if (targetPaymentInput != null &&
      amountInput != null &&
      yearsInput != null) {
    amount = amountInput;
    years = yearsInput;
    monthlyPayment = targetPaymentInput;
    final principal = amount * 10000;
    final months = (years * 12).round();
    if (principal == 0) return _invalidLoanResults();
    final zeroRatePayment = principal / months;
    rate = monthlyPayment == zeroRatePayment
        ? 0
        : _solveLoanAnnualRate(
            principal: principal,
            months: months,
            payment: monthlyPayment,
          );
    if (!rate.isFinite || rate <= -100) return _invalidLoanResults();
    source = '目标月供+贷款金额+贷款年限';
  } else {
    return _invalidLoanResults();
  }

  final principal = amount * 10000;
  final months = (years * 12).round();
  if (months <= 0 || principal < 0) return _invalidLoanResults();
  final monthlyRate = rate / 100 / 12;
  final totalRepayment = monthlyPayment * months;
  final totalInterest = totalRepayment - principal;
  final firstInterest = principal * monthlyRate;
  final firstPrincipal = monthlyPayment - firstInterest;
  return [
    ToolResult('每月还款额', formatNumber(monthlyPayment), '元', primary: true),
    ToolResult('贷款金额', formatNumber(amount), '万元'),
    ToolResult('年利率', formatNumber(rate), '%'),
    ToolResult('贷款年限', formatNumber(years), '年'),
    ToolResult('总利息', formatNumber(totalInterest), '元'),
    ToolResult('总还款额', formatNumber(totalRepayment), '元'),
    ToolResult('还款期数', months.toString(), '期'),
    ToolResult('首月利息', formatNumber(firstInterest), '元'),
    ToolResult('首月本金', formatNumber(firstPrincipal), '元'),
    ToolResult(
      '利息占本金',
      principal == 0 ? '0' : formatNumber(totalInterest / principal * 100),
      '%',
    ),
    ToolResult('年还款额', formatNumber(monthlyPayment * 12), '元'),
    ToolResult('输入来源', source, ''),
    if (paymentDelta != null)
      ToolResult('月供差值', formatNumber(paymentDelta), '元'),
  ];
}

List<ToolResult> _invalidLoanResults() {
  return const [
    ToolResult('每月还款额', '无效', '元', primary: true),
    ToolResult('贷款金额', '无效', '万元'),
    ToolResult('年利率', '无效', '%'),
    ToolResult('贷款年限', '无效', '年'),
    ToolResult('总利息', '无效', '元'),
    ToolResult('总还款额', '无效', '元'),
    ToolResult('还款期数', '无效', '期'),
    ToolResult('首月利息', '无效', '元'),
    ToolResult('首月本金', '无效', '元'),
    ToolResult('利息占本金', '无效', '%'),
    ToolResult('年还款额', '无效', '元'),
    ToolResult('输入来源', '无效', ''),
  ];
}

double _loanPayment(double principal, double annualRate, int months) {
  if (months <= 0) return double.nan;
  final monthlyRate = annualRate / 100 / 12;
  if (monthlyRate == 0) return principal / months;
  final factor = math.pow(1 + monthlyRate, months).toDouble();
  if (!factor.isFinite || factor == 1) return double.nan;
  return principal * monthlyRate * factor / (factor - 1);
}

double _solveLoanAnnualRate({
  required double principal,
  required int months,
  required double payment,
}) {
  const minMonthlyRate = -0.999999 / 12;
  var low = minMonthlyRate;
  var high = 1.0;
  final lowPayment = _loanPayment(principal, low * 1200, months);
  if (!lowPayment.isFinite || payment < lowPayment) return double.nan;
  for (var i = 0; i < 80; i++) {
    final highPayment = _loanPayment(principal, high * 1200, months);
    if (!highPayment.isFinite) break;
    if (highPayment >= payment) break;
    high *= 2;
    if (high > 1000) return double.nan;
  }
  for (var i = 0; i < 100; i++) {
    final mid = (low + high) / 2;
    final midPayment = _loanPayment(principal, mid * 1200, months);
    if (!midPayment.isFinite) return double.nan;
    if (midPayment < payment) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return (low + high) / 2 * 1200;
}

List<ToolResult> annuityResults(Map<String, double> valuesByKey) {
  final paymentInput = valuesByKey['payment'];
  final rateInput = valuesByKey['rate'];
  final yearsInput = valuesByKey['years'];
  final perYearInput = valuesByKey['perYear'];
  final targetInput = valuesByKey['target'];
  final coreInputCount = [
    paymentInput,
    rateInput,
    yearsInput,
    targetInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 3 ||
      (paymentInput != null && (paymentInput < 0 || !paymentInput.isFinite)) ||
      (rateInput != null && (rateInput <= -100 || !rateInput.isFinite)) ||
      (yearsInput != null && (yearsInput < 0 || !yearsInput.isFinite)) ||
      (perYearInput != null && (perYearInput <= 0 || !perYearInput.isFinite)) ||
      (targetInput != null && (targetInput < 0 || !targetInput.isFinite))) {
    return _invalidAnnuityResults();
  }

  final perYear = (perYearInput ?? 1).round();
  if (perYear <= 0) return _invalidAnnuityResults();
  double payment;
  double rawRate;
  double years;
  double target;
  String source;
  double? targetDelta;
  if (paymentInput != null && rateInput != null && yearsInput != null) {
    payment = paymentInput;
    rawRate = rateInput;
    years = yearsInput;
    final periods = (years * perYear).round();
    final factor = _annuityFutureValueFactor(rawRate, perYear, periods);
    if (!factor.isFinite || factor < 0) return _invalidAnnuityResults();
    target = payment * factor;
    targetDelta = targetInput == null ? null : target - targetInput;
    source = targetInput == null ? '每期投入+年化收益+年限' : '每期投入+年化收益+年限，目标终值作参考';
  } else if (targetInput != null && rateInput != null && yearsInput != null) {
    rawRate = rateInput;
    years = yearsInput;
    target = targetInput;
    final periods = (years * perYear).round();
    final factor = _annuityFutureValueFactor(rawRate, perYear, periods);
    if (factor <= 0 || !factor.isFinite) return _invalidAnnuityResults();
    payment = target / factor;
    source = '目标终值+年化收益+年限';
  } else if (targetInput != null &&
      paymentInput != null &&
      yearsInput != null) {
    payment = paymentInput;
    years = yearsInput;
    target = targetInput;
    final periods = (years * perYear).round();
    if (payment == 0 || periods <= 0) return _invalidAnnuityResults();
    rawRate = target == payment * periods
        ? 0
        : _solveAnnuityAnnualRate(
            payment: payment,
            periods: periods,
            perYear: perYear,
            target: target,
          );
    if (!rawRate.isFinite || rawRate <= -100) return _invalidAnnuityResults();
    source = '目标终值+每期投入+年限';
  } else {
    return _invalidAnnuityResults();
  }

  final periods = (years * perYear).round();
  if (periods < 0) return _invalidAnnuityResults();
  final ratePerPeriod = rawRate / 100 / perYear;
  final invested = payment * periods;
  final gain = target - invested;
  return [
    ToolResult('终值', formatNumber(target), '元', primary: true),
    ToolResult('每期投入', formatNumber(payment), '元'),
    ToolResult('年化收益', formatNumber(rawRate), '%'),
    ToolResult('年限', formatNumber(years), '年'),
    ToolResult('每年期数', perYear.toString(), '期'),
    ToolResult('累计投入', formatNumber(invested), '元'),
    ToolResult('收益', formatNumber(gain), '元'),
    ToolResult('期数', periods.toString(), '期'),
    ToolResult('每期收益率', formatNumber(ratePerPeriod * 100), '%'),
    ToolResult(
      '收益/投入',
      invested == 0 ? '0' : formatNumber(gain / invested * 100),
      '%',
    ),
    ToolResult('输入来源', source, ''),
    if (targetDelta != null) ToolResult('终值差值', formatNumber(targetDelta), '元'),
  ];
}

List<ToolResult> _invalidAnnuityResults() {
  return const [
    ToolResult('终值', '无效', '元', primary: true),
    ToolResult('每期投入', '无效', '元'),
    ToolResult('年化收益', '无效', '%'),
    ToolResult('年限', '无效', '年'),
    ToolResult('每年期数', '无效', '期'),
    ToolResult('累计投入', '无效', '元'),
    ToolResult('收益', '无效', '元'),
    ToolResult('期数', '无效', '期'),
    ToolResult('每期收益率', '无效', '%'),
    ToolResult('收益/投入', '无效', '%'),
    ToolResult('输入来源', '无效', ''),
  ];
}

double _annuityFutureValueFactor(double annualRate, int perYear, int periods) {
  if (periods < 0 || perYear <= 0) return double.nan;
  final ratePerPeriod = annualRate / 100 / perYear;
  if (ratePerPeriod == 0) return periods.toDouble();
  final factor = math.pow(1 + ratePerPeriod, periods).toDouble();
  if (!factor.isFinite) return double.nan;
  return (factor - 1) / ratePerPeriod;
}

double _solveAnnuityAnnualRate({
  required double payment,
  required int periods,
  required int perYear,
  required double target,
}) {
  final minRatePerPeriod = -0.999999 / perYear;
  var low = minRatePerPeriod;
  var high = 0.01;
  final lowValue = payment *
      _annuityFutureValueFactor(low * perYear * 100, perYear, periods);
  if (!lowValue.isFinite || target < lowValue) return double.nan;
  for (var i = 0; i < 100; i++) {
    final highValue = payment *
        _annuityFutureValueFactor(high * perYear * 100, perYear, periods);
    if (!highValue.isFinite) break;
    if (highValue >= target) break;
    high *= 2;
    if (high > 1000) return double.nan;
  }
  for (var i = 0; i < 100; i++) {
    final mid = (low + high) / 2;
    final midValue = payment *
        _annuityFutureValueFactor(mid * perYear * 100, perYear, periods);
    if (!midValue.isFinite) return double.nan;
    if (midValue < target) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return (low + high) / 2 * perYear * 100;
}

List<ToolResult> installmentResults(Map<String, double> valuesByKey) {
  final priceInput = valuesByKey['price'];
  final feeInput = valuesByKey['fee'];
  final monthsInput = valuesByKey['months'];
  final targetPaymentInput = valuesByKey['targetPayment'];
  final coreInputCount = [
    priceInput,
    feeInput,
    monthsInput,
    targetPaymentInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 3 ||
      (priceInput != null && (priceInput < 0 || !priceInput.isFinite)) ||
      (feeInput != null && (feeInput < 0 || !feeInput.isFinite)) ||
      (monthsInput != null && (monthsInput <= 0 || !monthsInput.isFinite)) ||
      (targetPaymentInput != null &&
          (targetPaymentInput < 0 || !targetPaymentInput.isFinite))) {
    return _invalidInstallmentResults();
  }

  double price;
  double rawFee;
  int months;
  double payment;
  String source;
  double? paymentDelta;
  if (priceInput != null && feeInput != null && monthsInput != null) {
    price = priceInput;
    rawFee = feeInput;
    months = monthsInput.round();
    final total = price * (1 + rawFee / 100);
    payment = total / months;
    paymentDelta =
        targetPaymentInput == null ? null : payment - targetPaymentInput;
    source = targetPaymentInput == null
        ? '商品价格+总手续费率+分期期数'
        : '商品价格+总手续费率+分期期数，目标每期作参考';
  } else if (targetPaymentInput != null &&
      feeInput != null &&
      monthsInput != null) {
    rawFee = feeInput;
    months = monthsInput.round();
    payment = targetPaymentInput;
    final multiplier = 1 + rawFee / 100;
    if (multiplier <= 0) return _invalidInstallmentResults();
    price = payment * months / multiplier;
    source = '目标每期+总手续费率+分期期数';
  } else if (targetPaymentInput != null &&
      priceInput != null &&
      monthsInput != null) {
    price = priceInput;
    months = monthsInput.round();
    payment = targetPaymentInput;
    if (price == 0) return _invalidInstallmentResults();
    rawFee = (payment * months / price - 1) * 100;
    if (rawFee < 0) return _invalidInstallmentResults();
    source = '目标每期+商品价格+分期期数';
  } else {
    return _invalidInstallmentResults();
  }

  if (months <= 0) return _invalidInstallmentResults();
  final fee = rawFee / 100;
  final feeAmount = price * fee;
  final total = price + feeAmount;
  return [
    ToolResult('每期付款', formatNumber(payment), '元', primary: true),
    ToolResult('商品价格', formatNumber(price), '元'),
    ToolResult('总手续费率', formatNumber(rawFee), '%'),
    ToolResult('手续费', formatNumber(feeAmount), '元'),
    ToolResult('总支付', formatNumber(total), '元'),
    ToolResult('期数', months.toString(), '期'),
    ToolResult('每期本金', formatNumber(price / months), '元'),
    ToolResult('每期手续费', formatNumber(feeAmount / months), '元'),
    ToolResult('等效每期费率', formatNumber(rawFee / months), '%'),
    ToolResult('输入来源', source, ''),
    if (paymentDelta != null)
      ToolResult('每期差值', formatNumber(paymentDelta), '元'),
  ];
}

List<ToolResult> _invalidInstallmentResults() {
  return const [
    ToolResult('每期付款', '无效', '元', primary: true),
    ToolResult('商品价格', '无效', '元'),
    ToolResult('总手续费率', '无效', '%'),
    ToolResult('手续费', '无效', '元'),
    ToolResult('总支付', '无效', '元'),
    ToolResult('期数', '无效', '期'),
    ToolResult('每期本金', '无效', '元'),
    ToolResult('每期手续费', '无效', '元'),
    ToolResult('等效每期费率', '无效', '%'),
    ToolResult('输入来源', '无效', ''),
  ];
}

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
    ToolResult('ROI', formatNumber(roi), '%', primary: true),
    ToolResult('收益', formatNumber(gain), '元'),
    ToolResult('投入', formatNumber(cost), '元'),
    ToolResult('净收益', formatNumber(net), '元'),
    ToolResult('回报倍数', formatNumber(multiple), 'x'),
    ToolResult('回本率', formatNumber(multiple * 100), '%'),
    ToolResult('盈亏平衡差额', formatNumber(net), '元'),
    ToolResult('输入来源', source, ''),
    if (roiDelta != null) ToolResult('ROI差值', formatNumber(roiDelta), '%'),
  ];
  if (years != null) {
    final annualMultiple =
        multiple < 0 ? double.nan : math.pow(multiple, 1 / years).toDouble();
    final annualRoi = (annualMultiple - 1) * 100;
    final monthlyNet = net / (years * 12);
    final paybackYears = net <= 0 ? double.nan : cost / (net / years);
    results.addAll([
      ToolResult('持有年限', formatNumber(years), '年'),
      ToolResult('年化ROI', formatNumber(annualRoi), '%'),
      ToolResult('年化回报倍数', formatNumber(annualMultiple), 'x'),
      ToolResult('月均净收益', formatNumber(monthlyNet), '元/月'),
      ToolResult('简单回收期',
          paybackYears.isFinite ? formatNumber(paybackYears) : '未回收', '年'),
    ]);
  }
  return results;
}

List<ToolResult> _invalidRoiResults({required bool includeYears}) {
  return [
    const ToolResult('ROI', '无效', '%', primary: true),
    const ToolResult('收益', '无效', '元'),
    const ToolResult('投入', '无效', '元'),
    const ToolResult('净收益', '无效', '元'),
    const ToolResult('回报倍数', '无效', 'x'),
    const ToolResult('回本率', '无效', '%'),
    const ToolResult('盈亏平衡差额', '无效', '元'),
    const ToolResult('输入来源', '无效', ''),
    if (includeYears) const ToolResult('持有年限', '无效', '年'),
    if (includeYears) const ToolResult('年化ROI', '无效', '%'),
    if (includeYears) const ToolResult('年化回报倍数', '无效', 'x'),
    if (includeYears) const ToolResult('月均净收益', '无效', '元/月'),
    if (includeYears) const ToolResult('简单回收期', '无效', '年'),
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
    ToolResult('利润', formatNumber(profit), '元', primary: true),
    ToolResult('成本', formatNumber(cost), '元'),
    ToolResult('售价', formatNumber(price), '元'),
    ToolResult('毛利率', formatNumber(margin), '%'),
    ToolResult(
        '加价率', cost == 0 ? '无效' : formatNumber(profit / cost * 100), '%'),
    ToolResult('成本占比', formatNumber(cost / price * 100), '%'),
    ToolResult('保本售价', formatNumber(cost), '元'),
    ToolResult('利润状态', profit > 0 ? '盈利' : (profit < 0 ? '亏损' : '持平'), ''),
    ToolResult('输入来源', source, ''),
    if (profitDelta != null) ToolResult('利润差值', formatNumber(profitDelta), '元'),
    if (marginDelta != null)
      ToolResult('毛利率差值', formatNumber(marginDelta), '%'),
  ];
}

List<ToolResult> _invalidProfitMarginResults() {
  return const [
    ToolResult('利润', '无效', '元', primary: true),
    ToolResult('成本', '无效', '元'),
    ToolResult('售价', '无效', '元'),
    ToolResult('毛利率', '无效', '%'),
    ToolResult('加价率', '无效', '%'),
    ToolResult('成本占比', '无效', '%'),
    ToolResult('保本售价', '无效', '元'),
    ToolResult('利润状态', '无效', ''),
    ToolResult('输入来源', '无效', ''),
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
    ToolResult('费用', formatNumber(cost), '元', primary: true),
    ToolResult('用电量', formatNumber(energy), 'kWh'),
    ToolResult('功率', formatNumber(powerW), 'W'),
    ToolResult('每日使用', formatNumber(hours), 'h'),
    ToolResult('天数', formatNumber(days), '天'),
    ToolResult('电价', formatNumber(price), '元/kWh'),
    ToolResult('日均费用', formatNumber(dailyCost), '元/天'),
    ToolResult('日均用电', formatNumber(dailyEnergy), 'kWh/天'),
    ToolResult('月化费用', formatNumber(dailyCost * 30), '元/月'),
    ToolResult('年化费用', formatNumber(dailyCost * 365), '元/年'),
    ToolResult('输入来源', source, ''),
    if (costDelta != null) ToolResult('费用差值', formatNumber(costDelta), '元'),
  ];
}

List<ToolResult> _invalidElectricityCostResults() {
  return const [
    ToolResult('费用', '无效', '元', primary: true),
    ToolResult('用电量', '无效', 'kWh'),
    ToolResult('功率', '无效', 'W'),
    ToolResult('每日使用', '无效', 'h'),
    ToolResult('天数', '无效', '天'),
    ToolResult('电价', '无效', '元/kWh'),
    ToolResult('日均费用', '无效', '元/天'),
    ToolResult('日均用电', '无效', 'kWh/天'),
    ToolResult('月化费用', '无效', '元/月'),
    ToolResult('年化费用', '无效', '元/年'),
    ToolResult('输入来源', '无效', ''),
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
    ToolResult('平衡销量', formatNumber(quantity), '件', primary: true),
    ToolResult('向上取整销量', quantity.ceil().toString(), '件'),
    ToolResult('固定成本', formatNumber(fixed), '元'),
    ToolResult('单价', formatNumber(price), '元'),
    ToolResult('单位变动成本', formatNumber(variable), '元'),
    ToolResult('边际贡献', formatNumber(margin), '元/件'),
    ToolResult('边际率', formatNumber(margin / price * 100), '%'),
    ToolResult('平衡销售额', formatNumber(quantity * price), '元'),
    ToolResult('平衡变动成本', formatNumber(quantity * variable), '元'),
    ToolResult('输入来源', source, ''),
    if (quantityDelta != null)
      ToolResult('销量差值', formatNumber(quantityDelta), '件'),
  ];
}

List<ToolResult> _invalidBreakEvenResults({double? margin, double? price}) {
  return [
    const ToolResult('平衡销量', '无效', '件', primary: true),
    const ToolResult('向上取整销量', '无效', '件'),
    const ToolResult('固定成本', '无效', '元'),
    const ToolResult('单价', '无效', '元'),
    const ToolResult('单位变动成本', '无效', '元'),
    ToolResult('边际贡献', margin == null ? '无效' : formatNumber(margin), '元/件'),
    ToolResult(
      '边际率',
      margin == null || price == null || price == 0
          ? '无效'
          : formatNumber(margin / price * 100),
      '%',
    ),
    const ToolResult('平衡销售额', '无效', '元'),
    const ToolResult('平衡变动成本', '无效', '元'),
    const ToolResult('输入来源', '无效', ''),
  ];
}

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
