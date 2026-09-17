import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

  test('loan tool reports payment breakdown and interest ratio', () {
    final definition = tool('loan');
    final values = <String, double>{'amount': 50, 'rate': 4.1, 'years': 20};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['每月还款额'], startsWith('3056.313'));
    expect(valuesByLabel['贷款金额'], '50');
    expect(valuesByLabel['年利率'], '4.1');
    expect(valuesByLabel['贷款年限'], '20');
    expect(valuesByLabel['总利息'], startsWith('233515.125'));
    expect(valuesByLabel['总还款额'], startsWith('733515.125'));
    expect(valuesByLabel['还款期数'], '240');
    expect(valuesByLabel['首月利息'], startsWith('1708.333'));
    expect(valuesByLabel['首月本金'], startsWith('1347.979'));
    expect(valuesByLabel['利息占本金'], startsWith('46.703'));
    expect(valuesByLabel['年还款额'], startsWith('36675.756'));
    expect(valuesByLabel['输入来源'], '贷款金额+年利率+贷款年限');
    expect(insights, contains('按等额本息算'));

    final referenceValues = <String, double>{
      'amount': 50,
      'rate': 4.1,
      'years': 20,
      'targetPayment': 3000,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '贷款金额+年利率+贷款年限，目标月供作参考');
    expect(referenceByLabel['月供差值'], startsWith('56.313'));
    expect(referenceInsights, contains('目标月供与当前月供相差 56.313'));
  });

  test('loan tool rejects invalid term and warns on high interest burden', () {
    final definition = tool('loan');
    final invalidValues = <String, double>{
      'amount': 50,
      'rate': 4.1,
      'years': 0
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['每月还款额'], '无效');
    expect(invalidByLabel['利息占本金'], '无效');
    expect(invalidInsights.join('\n'), contains('贷款金额、年利率、贷款年限和目标月供至少填写三项'));

    final highInterestValues = <String, double>{
      'amount': 50,
      'rate': 8,
      'years': 30,
    };
    final highInterestResults = calculateTool(definition, highInterestValues);
    final highInterestInsights =
        buildToolInsights(definition, highInterestValues, highInterestResults)
            .join('\n');

    expect(highInterestResults.first.value, startsWith('3668.822'));
    expect(highInterestInsights, contains('总利息超过本金 50%'));
  });

  test('loan tool reverse solves affordable amount and required rate', () {
    final definition = tool('loan');
    final amountResults = calculateTool(definition, {
      'targetPayment': 3056.313,
      'rate': 4.1,
      'years': 20,
    });
    final amountByLabel = {
      for (final result in amountResults) result.label: result.value,
    };
    expect(amountByLabel['贷款金额'], '50');
    expect(amountByLabel['输入来源'], '目标月供+年利率+贷款年限');

    final rateResults = calculateTool(definition, {
      'amount': 50,
      'targetPayment': 3056.313,
      'years': 20,
    });
    final rateByLabel = {
      for (final result in rateResults) result.label: result.value,
    };
    expect(rateByLabel['年利率'], '4.1');
    expect(rateByLabel['输入来源'], '目标月供+贷款金额+贷款年限');
  });

  test('annuity tool reports periods per-period rate and gain ratio', () {
    final definition = tool('annuity');
    final values = <String, double>{
      'payment': 1000,
      'rate': 5,
      'years': 10,
      'perYear': 12,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['终值'], startsWith('155282.279'));
    expect(valuesByLabel['每期投入'], '1000');
    expect(valuesByLabel['年化收益'], '5');
    expect(valuesByLabel['年限'], '10');
    expect(valuesByLabel['每年期数'], '12');
    expect(valuesByLabel['累计投入'], '120000');
    expect(valuesByLabel['收益'], startsWith('35282.279'));
    expect(valuesByLabel['期数'], '120');
    expect(valuesByLabel['每期收益率'], startsWith('0.416667'));
    expect(valuesByLabel['收益/投入'], startsWith('29.401'));
    expect(valuesByLabel['输入来源'], '每期投入+年化收益+年限');
    expect(insights, contains('年金按期末投入估算'));

    final referenceValues = <String, double>{
      'payment': 1000,
      'rate': 5,
      'years': 10,
      'perYear': 12,
      'target': 150000,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '每期投入+年化收益+年限，目标终值作参考');
    expect(referenceByLabel['终值差值'], startsWith('5282.279'));
    expect(referenceInsights, contains('目标终值与当前终值相差 5282.279'));
  });

  test('annuity tool rejects invalid frequency and warns on negative gain', () {
    final definition = tool('annuity');
    final invalidValues = <String, double>{
      'payment': 1000,
      'rate': 5,
      'years': 10,
      'perYear': 0,
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['终值'], '无效');
    expect(invalidByLabel['每期收益率'], '无效');
    expect(
      invalidInsights.join('\n'),
      contains('每期投入、年化收益、年限和目标终值至少填写三项'),
    );

    final lossValues = <String, double>{
      'payment': 1000,
      'rate': -5,
      'years': 10,
      'perYear': 12,
    };
    final lossResults = calculateTool(definition, lossValues);
    final lossInsights =
        buildToolInsights(definition, lossValues, lossResults).join('\n');

    expect(lossResults.first.value, startsWith('94584.617'));
    expect(lossInsights, contains('收益为负'));
  });

  test('annuity tool reverse solves contribution and required return', () {
    final definition = tool('annuity');
    final paymentResults = calculateTool(definition, {
      'target': 155282.279,
      'rate': 5,
      'years': 10,
      'perYear': 12,
    });
    final paymentByLabel = {
      for (final result in paymentResults) result.label: result.value,
    };
    expect(paymentByLabel['每期投入'], startsWith('999.999'));
    expect(paymentByLabel['输入来源'], '目标终值+年化收益+年限');

    final rateResults = calculateTool(definition, {
      'payment': 1000,
      'target': 155282.279,
      'years': 10,
      'perYear': 12,
    });
    final rateByLabel = {
      for (final result in rateResults) result.label: result.value,
    };
    expect(rateByLabel['年化收益'], '5');
    expect(rateByLabel['输入来源'], '目标终值+每期投入+年限');
  });

  test('installment tool reports per-period fee and effective period rate', () {
    final definition = tool('installment');
    final values = <String, double>{'price': 6000, 'fee': 6, 'months': 12};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['每期付款'], '530');
    expect(valuesByLabel['商品价格'], '6000');
    expect(valuesByLabel['总手续费率'], '6');
    expect(valuesByLabel['手续费'], '360');
    expect(valuesByLabel['总支付'], '6360');
    expect(valuesByLabel['期数'], '12');
    expect(valuesByLabel['每期本金'], '500');
    expect(valuesByLabel['每期手续费'], '30');
    expect(valuesByLabel['等效每期费率'], '0.5');
    expect(valuesByLabel['输入来源'], '商品价格+总手续费率+分期期数');
    expect(insights, contains('分期按总手续费平均摊到每期'));

    final referenceValues = <String, double>{
      'price': 6000,
      'fee': 6,
      'months': 12,
      'targetPayment': 500,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '商品价格+总手续费率+分期期数，目标每期作参考');
    expect(referenceByLabel['每期差值'], '30');
    expect(referenceInsights, contains('目标每期与当前每期付款相差 30元'));
  });

  test('installment tool rejects invalid months and warns on high fee', () {
    final definition = tool('installment');
    final invalidValues = <String, double>{
      'price': 6000,
      'fee': 6,
      'months': 0
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['每期付款'], '无效');
    expect(invalidByLabel['期数'], '无效');
    expect(invalidInsights.join('\n'), contains('商品价格、总手续费率、分期期数和目标每期至少填写三项'));

    final highFeeResults =
        calculateTool(definition, {'price': 6000, 'fee': 25, 'months': 12});
    final highFeeInsights = buildToolInsights(definition,
            {'price': 6000, 'fee': 25, 'months': 12}, highFeeResults)
        .join('\n');

    expect(highFeeResults.first.value, '625');
    expect(highFeeInsights, contains('总手续费率超过 20%'));
  });

  test('installment tool reverse solves affordable price and fee rate', () {
    final definition = tool('installment');
    final priceResults = calculateTool(definition, {
      'targetPayment': 530,
      'fee': 6,
      'months': 12,
    });
    final priceByLabel = {
      for (final result in priceResults) result.label: result.value,
    };
    expect(priceByLabel['商品价格'], '6000');
    expect(priceByLabel['输入来源'], '目标每期+总手续费率+分期期数');

    final feeResults = calculateTool(definition, {
      'price': 6000,
      'targetPayment': 530,
      'months': 12,
    });
    final feeByLabel = {
      for (final result in feeResults) result.label: result.value,
    };
    expect(feeByLabel['总手续费率'], '6');
    expect(feeByLabel['输入来源'], '目标每期+商品价格+分期期数');
  });

  test('break even tool reverse solves economics and reports sales amounts',
      () {
    final definition = tool('break_even');
    final values = <String, double>{
      'fixed': 50000,
      'price': 120,
      'variable': 70
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['平衡销量'], '1000');
    expect(valuesByLabel['向上取整销量'], '1000');
    expect(valuesByLabel['边际贡献'], '50');
    expect(valuesByLabel['边际率'], startsWith('41.666'));
    expect(valuesByLabel['平衡销售额'], '120000');
    expect(valuesByLabel['平衡变动成本'], '70000');
    expect(valuesByLabel['输入来源'], '固定成本+单价+单位变动成本');
    expect(insights, contains('盈亏平衡只看单品静态模型'));

    final fixedFromTarget = calculateTool(definition, {
      'targetQuantity': 1000,
      'price': 120,
      'variable': 70,
    });
    final fixedFromTargetByLabel = {
      for (final result in fixedFromTarget) result.label: result.value,
    };
    expect(fixedFromTargetByLabel['固定成本'], '50000');
    expect(fixedFromTargetByLabel['输入来源'], '目标销量+单价+单位变动成本');

    final priceFromTarget = calculateTool(definition, {
      'fixed': 50000,
      'targetQuantity': 1000,
      'variable': 70,
    });
    final priceFromTargetByLabel = {
      for (final result in priceFromTarget) result.label: result.value,
    };
    expect(priceFromTargetByLabel['单价'], '120');
    expect(priceFromTargetByLabel['输入来源'], '目标销量+固定成本+单位变动成本');

    final variableFromTarget = calculateTool(definition, {
      'fixed': 50000,
      'price': 120,
      'targetQuantity': 1000,
    });
    final variableFromTargetByLabel = {
      for (final result in variableFromTarget) result.label: result.value,
    };
    expect(variableFromTargetByLabel['单位变动成本'], '70');
    expect(variableFromTargetByLabel['输入来源'], '目标销量+固定成本+单价');

    final referenceValues = <String, double>{
      'fixed': 50000,
      'price': 120,
      'variable': 70,
      'targetQuantity': 900,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '固定成本+单价+单位变动成本，目标销量作参考');
    expect(referenceByLabel['销量差值'], '100');
    expect(referenceInsights, contains('目标销量与当前平衡销量相差 100件'));
  });

  test('break even tool rejects invalid economics and non-positive margin', () {
    final definition = tool('break_even');
    final invalidResults =
        calculateTool(definition, {'fixed': -1, 'price': 120, 'variable': 70});
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights = buildToolInsights(definition,
        {'fixed': -1, 'price': 120, 'variable': 70}, invalidResults);

    expect(invalidByLabel['平衡销量'], '无效');
    expect(invalidByLabel['平衡销售额'], '无效');
    expect(
      invalidInsights.join('\n'),
      contains('固定成本、单价、单位变动成本和目标销量至少填写三项'),
    );

    final noMarginValues = <String, double>{
      'fixed': 50000,
      'price': 70,
      'variable': 70,
    };
    final noMarginResults = calculateTool(definition, noMarginValues);
    final noMarginByLabel = {
      for (final result in noMarginResults) result.label: result.value,
    };
    final noMarginInsights =
        buildToolInsights(definition, noMarginValues, noMarginResults);

    expect(noMarginByLabel['平衡销量'], '无效');
    expect(noMarginByLabel['边际贡献'], '0');
    expect(noMarginInsights, contains('边际贡献不大于 0，卖得越多也无法覆盖固定成本'));

    final incompleteResults =
        calculateTool(definition, {'targetQuantity': 1000, 'price': 120});
    final impossibleVariable = calculateTool(definition, {
      'fixed': 50000,
      'price': 40,
      'targetQuantity': 1000,
    });

    expect(incompleteResults.first.value, '无效');
    expect(impossibleVariable.first.value, '无效');
  });

  test('electricity cost reverse solves budget inputs and reports long costs',
      () {
    final definition = tool('electricity_cost');
    final values = <String, double>{
      'power': 800,
      'hours': 3,
      'days': 30,
      'price': 0.6,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['费用'], '43.2');
    expect(valuesByLabel['用电量'], '72');
    expect(valuesByLabel['日均费用'], '1.44');
    expect(valuesByLabel['日均用电'], '2.4');
    expect(valuesByLabel['月化费用'], '43.2');
    expect(valuesByLabel['年化费用'], '525.6');
    expect(valuesByLabel['输入来源'], '功率+每日使用+天数+电价');
    expect(insights, contains('电费按固定单价估算'));

    final powerFromTarget = calculateTool(definition, {
      'targetCost': 43.2,
      'hours': 3,
      'days': 30,
      'price': 0.6,
    });
    final powerFromTargetByLabel = {
      for (final result in powerFromTarget) result.label: result.value,
    };
    expect(powerFromTargetByLabel['功率'], '800');
    expect(powerFromTargetByLabel['输入来源'], '目标费用+每日使用+天数+电价');

    final hoursFromTarget = calculateTool(definition, {
      'targetCost': 43.2,
      'power': 800,
      'days': 30,
      'price': 0.6,
    });
    final hoursFromTargetByLabel = {
      for (final result in hoursFromTarget) result.label: result.value,
    };
    expect(hoursFromTargetByLabel['每日使用'], '3');
    expect(hoursFromTargetByLabel['输入来源'], '目标费用+功率+天数+电价');

    final priceFromTarget = calculateTool(definition, {
      'targetCost': 43.2,
      'power': 800,
      'hours': 3,
      'days': 30,
    });
    final priceFromTargetByLabel = {
      for (final result in priceFromTarget) result.label: result.value,
    };
    expect(priceFromTargetByLabel['电价'], '0.6');
    expect(priceFromTargetByLabel['输入来源'], '目标费用+功率+每日使用+天数');

    final referenceValues = <String, double>{
      'power': 800,
      'hours': 3,
      'days': 30,
      'price': 0.6,
      'targetCost': 40,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '功率+每日使用+天数+电价，目标费用作参考');
    expect(referenceByLabel['费用差值'], '3.2');
    expect(referenceInsights, contains('目标费用与当前计算相差 3.2元'));
  });

  test('electricity cost rejects invalid hours and warns on high consumption',
      () {
    final definition = tool('electricity_cost');
    final invalidValues = <String, double>{
      'power': 800,
      'hours': 25,
      'days': 30,
      'price': 0.6,
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['费用'], '无效');
    expect(invalidByLabel['日均用电'], '无效');
    expect(
      invalidInsights.join('\n'),
      contains('功率、每日使用、天数、电价和目标费用至少填写四项'),
    );

    final incompleteResults =
        calculateTool(definition, {'targetCost': 43.2, 'power': 800});
    final impossibleHours = calculateTool(definition, {
      'targetCost': 1000,
      'power': 800,
      'days': 30,
      'price': 0.6,
    });

    expect(incompleteResults.first.value, '无效');
    expect(impossibleHours.first.value, '无效');

    final highUseValues = <String, double>{
      'power': 5000,
      'hours': 8,
      'days': 30,
      'price': 0.6,
    };
    final highUseResults = calculateTool(definition, highUseValues);
    final highUseInsights =
        buildToolInsights(definition, highUseValues, highUseResults).join('\n');

    expect(highUseResults.first.value, '720');
    expect(highUseInsights, contains('日均用电超过 20kWh'));
  });

  test('compound tool reverse solves principal rate years and validates inputs',
      () {
    final definition = tool('compound');
    final values = <String, double>{'principal': 10000, 'rate': 5, 'years': 10};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['终值'], startsWith('16288.946'));
    expect(valuesByLabel['收益'], startsWith('6288.946'));
    expect(valuesByLabel['收益率'], startsWith('62.889'));
    expect(valuesByLabel['本金'], '10000');
    expect(valuesByLabel['增长倍数'], startsWith('1.628'));
    expect(valuesByLabel['年化收益率'], '5');
    expect(valuesByLabel['年限'], '10');
    expect(valuesByLabel['输入来源'], '本金+年化收益+年限');
    expect(insights, contains('复利按固定年化收益估算'));

    final principalFromTarget = calculateTool(definition, {
      'target': 16288.946267,
      'rate': 5,
      'years': 10,
    });
    final principalFromTargetByLabel = {
      for (final result in principalFromTarget) result.label: result.value,
    };
    expect(principalFromTargetByLabel['本金'], startsWith('10000'));
    expect(principalFromTargetByLabel['输入来源'], '目标终值+年化收益+年限');

    final rateFromTarget = calculateTool(definition, {
      'principal': 10000,
      'target': 16288.946267,
      'years': 10,
    });
    final rateFromTargetByLabel = {
      for (final result in rateFromTarget) result.label: result.value,
    };
    expect(rateFromTargetByLabel['年化收益率'], startsWith('5'));
    expect(rateFromTargetByLabel['输入来源'], '本金+目标终值+年限');

    final yearsFromTarget = calculateTool(definition, {
      'principal': 10000,
      'target': 16288.946267,
      'rate': 5,
    });
    final yearsFromTargetByLabel = {
      for (final result in yearsFromTarget) result.label: result.value,
    };
    expect(yearsFromTargetByLabel['年限'], startsWith('10'));
    expect(yearsFromTargetByLabel['输入来源'], '本金+目标终值+年化收益');

    final referenceValues = <String, double>{
      'principal': 10000,
      'rate': 5,
      'years': 10,
      'target': 16000,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '本金+年化收益+年限，目标终值作参考');
    expect(referenceByLabel['终值差值'], startsWith('288.946'));
    expect(referenceInsights, contains('目标终值与当前计算相差'));

    final invalidValues = <String, double>{
      'principal': 10000,
      'rate': -100,
      'years': 10,
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);
    final incompleteResults = calculateTool(definition, {'target': 16000});

    expect(invalidByLabel['终值'], '无效');
    expect(invalidByLabel['增长倍数'], '无效');
    expect(incompleteResults.first.value, '无效');
    expect(
      invalidInsights.join('\n'),
      contains('本金、年化收益、年限和目标终值至少填写三项'),
    );
  });
}
