import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

export 'calculate_tool_finance_business.dart';
export 'calculate_tool_finance_growth.dart';

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
