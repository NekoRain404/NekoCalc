import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

  test(
      'profit margin tool reverse solves price cost margin and validates inputs',
      () {
    final definition = tool('profit_margin');
    final values = <String, double>{'cost': 80, 'price': 120};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['利润'], '40');
    expect(valuesByLabel['毛利率'], startsWith('33.333'));
    expect(valuesByLabel['加价率'], '50');
    expect(valuesByLabel['成本占比'], startsWith('66.666'));
    expect(valuesByLabel['保本售价'], '80');
    expect(valuesByLabel['利润状态'], '盈利');
    expect(valuesByLabel['输入来源'], '成本+售价');
    expect(insights, contains('利润率只看单件毛利'));

    final priceFromMargin = calculateTool(definition, {
      'cost': 80,
      'margin': 33.3333333333,
    });
    final priceFromMarginByLabel = {
      for (final result in priceFromMargin) result.label: result.value,
    };
    expect(priceFromMarginByLabel['售价'], startsWith('120'));
    expect(priceFromMarginByLabel['利润'], startsWith('40'));
    expect(priceFromMarginByLabel['输入来源'], '成本+目标毛利率');

    final costFromProfit = calculateTool(definition, {
      'price': 120,
      'profit': 40,
    });
    final costFromProfitByLabel = {
      for (final result in costFromProfit) result.label: result.value,
    };
    expect(costFromProfitByLabel['成本'], '80');
    expect(costFromProfitByLabel['毛利率'], startsWith('33.333'));
    expect(costFromProfitByLabel['输入来源'], '售价+目标利润');

    final marginFromProfit = calculateTool(definition, {
      'margin': 33.3333333333,
      'profit': 40,
    });
    final marginFromProfitByLabel = {
      for (final result in marginFromProfit) result.label: result.value,
    };
    expect(marginFromProfitByLabel['售价'], startsWith('120'));
    expect(marginFromProfitByLabel['成本'], startsWith('80'));
    expect(marginFromProfitByLabel['输入来源'], '目标毛利率+目标利润');

    final referenceValues = <String, double>{
      'cost': 80,
      'price': 120,
      'margin': 30,
      'profit': 45,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '成本+售价，目标值作参考');
    expect(referenceByLabel['利润差值'], '-5');
    expect(referenceByLabel['毛利率差值'], startsWith('3.333'));
    expect(referenceInsights, contains('目标利润与当前计算相差 -5元'));
    expect(referenceInsights, contains('目标毛利率与当前计算相差'));

    final lossValues = <String, double>{'cost': 130, 'price': 120};
    final lossResults = calculateTool(definition, lossValues);
    final lossByLabel = {
      for (final result in lossResults) result.label: result.value,
    };
    final lossInsights =
        buildToolInsights(definition, lossValues, lossResults).join('\n');

    expect(lossByLabel['利润'], '-10');
    expect(lossByLabel['利润状态'], '亏损');
    expect(lossInsights, contains('当前售价低于成本'));

    final invalidResults = calculateTool(definition, {'cost': 80, 'price': 0});
    final incompleteResults = calculateTool(definition, {'margin': 30});

    expect(invalidResults.first.value, '无效');
    expect(incompleteResults.first.value, '无效');
  });

  test('roi tool reports payback metrics and rejects zero investment', () {
    final definition = tool('roi');
    final values = <String, double>{'gain': 12500, 'cost': 10000, 'years': 2};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['ROI'], '25');
    expect(valuesByLabel['收益'], '12500');
    expect(valuesByLabel['投入'], '10000');
    expect(valuesByLabel['净收益'], '2500');
    expect(valuesByLabel['回报倍数'], '1.25');
    expect(valuesByLabel['回本率'], '125');
    expect(valuesByLabel['盈亏平衡差额'], '2500');
    expect(valuesByLabel['输入来源'], '收益+投入');
    expect(valuesByLabel['持有年限'], '2');
    expect(valuesByLabel['年化ROI'], startsWith('11.803'));
    expect(valuesByLabel['年化回报倍数'], startsWith('1.118'));
    expect(valuesByLabel['月均净收益'], startsWith('104.166'));
    expect(valuesByLabel['简单回收期'], '8');
    expect(insights, contains('已按持有年限折算年化 ROI'));
    expect(insights, contains('简单回收期约 8 年'));

    final noYears = calculateTool(definition, {'gain': 12500, 'cost': 10000});
    final noYearsByLabel = {
      for (final result in noYears) result.label: result.value,
    };
    final noYearsInsights =
        buildToolInsights(definition, {'gain': 12500, 'cost': 10000}, noYears)
            .join('\n');

    expect(noYearsByLabel, isNot(contains('年化ROI')));
    expect(noYearsInsights, contains('持有年限 未填写'));
    expect(noYearsInsights, contains('未填写持有年限'));

    final gainFromRoi = calculateTool(definition, {
      'cost': 10000,
      'roi': 25,
      'years': 2,
    });
    final gainFromRoiByLabel = {
      for (final result in gainFromRoi) result.label: result.value,
    };
    expect(gainFromRoiByLabel['收益'], '12500');
    expect(gainFromRoiByLabel['净收益'], '2500');
    expect(gainFromRoiByLabel['输入来源'], '投入+ROI');

    final costFromRoi = calculateTool(definition, {
      'gain': 12500,
      'roi': 25,
    });
    final costFromRoiByLabel = {
      for (final result in costFromRoi) result.label: result.value,
    };
    expect(costFromRoiByLabel['投入'], '10000');
    expect(costFromRoiByLabel['输入来源'], '收益+ROI');

    final referenceRoi = calculateTool(definition, {
      'gain': 12500,
      'cost': 10000,
      'roi': 20,
    });
    final referenceRoiByLabel = {
      for (final result in referenceRoi) result.label: result.value,
    };
    final referenceRoiInsights = buildToolInsights(
      definition,
      {
        'gain': 12500,
        'cost': 10000,
        'roi': 20,
      },
      referenceRoi,
    ).join('\n');
    expect(referenceRoiByLabel['输入来源'], '收益+投入，ROI作参考');
    expect(referenceRoiByLabel['ROI差值'], '5');
    expect(referenceRoiInsights, contains('ROI 参考值与当前计算相差 5%'));

    final negative = calculateTool(definition, {
      'gain': 9000,
      'cost': 10000,
      'years': 2,
    });
    final negativeByLabel = {
      for (final result in negative) result.label: result.value,
    };
    final negativeInsights = buildToolInsights(
      definition,
      {'gain': 9000, 'cost': 10000, 'years': 2},
      negative,
    ).join('\n');

    expect(negativeByLabel['ROI'], '-10');
    expect(negativeByLabel['年化ROI'], startsWith('-5.131'));
    expect(negativeByLabel['简单回收期'], '未回收');
    expect(negativeInsights, contains('ROI 为负'));
    expect(negativeInsights, contains('按当前净收益无法回收投入'));

    final invalidValues = <String, double>{'gain': 12500, 'cost': 0};
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults).join('\n');

    expect(invalidResults.first.value, '无效');
    expect(invalidInsights, contains('至少填写两项'));

    final invalidYears = calculateTool(definition, {
      'gain': 12500,
      'cost': 10000,
      'years': 0,
    });
    final invalidYearsByLabel = {
      for (final result in invalidYears) result.label: result.value,
    };

    expect(invalidYearsByLabel['ROI'], '无效');
    expect(invalidYearsByLabel['年化ROI'], '无效');
  });

  test('discount tool reports saving ratio and validates discount range', () {
    final definition = tool('discount');
    final values = <String, double>{'price': 299, 'discount': 85};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['到手价'], '254.15');
    expect(valuesByLabel['原价'], '299');
    expect(valuesByLabel['节省'], '44.85');
    expect(valuesByLabel['折扣率'], '85');
    expect(valuesByLabel['优惠比例'], '15');
    expect(valuesByLabel['每百元支付'], '85');
    expect(valuesByLabel['输入来源'], '原价+折扣');
    expect(insights, contains('当前按 原价+折扣 计算'));
    expect(insights, contains('折扣计算只看标价优惠'));

    final discountFromFinal = calculateTool(definition, {
      'price': 299,
      'finalPrice': 254.15,
    });
    final discountFromFinalByLabel = {
      for (final result in discountFromFinal) result.label: result.value,
    };
    expect(discountFromFinalByLabel['折扣率'], '85');
    expect(discountFromFinalByLabel['节省'], '44.85');
    expect(discountFromFinalByLabel['输入来源'], '原价+到手价');

    final priceFromDiscount = calculateTool(definition, {
      'discount': 85,
      'finalPrice': 254.15,
    });
    final priceFromDiscountByLabel = {
      for (final result in priceFromDiscount) result.label: result.value,
    };
    expect(priceFromDiscountByLabel['原价'], '299');
    expect(priceFromDiscountByLabel['输入来源'], '折扣+到手价');

    final referenceFinalPrice = calculateTool(definition, {
      'price': 299,
      'discount': 85,
      'finalPrice': 250,
    });
    final referenceFinalPriceByLabel = {
      for (final result in referenceFinalPrice) result.label: result.value,
    };
    final referenceFinalPriceInsights = buildToolInsights(
      definition,
      {
        'price': 299,
        'discount': 85,
        'finalPrice': 250,
      },
      referenceFinalPrice,
    ).join('\n');
    expect(referenceFinalPriceByLabel['输入来源'], '原价+折扣，到手价作参考');
    expect(referenceFinalPriceByLabel['到手价差值'], '4.15');
    expect(referenceFinalPriceInsights, contains('到手价参考值与当前计算相差 4.15元'));

    final deepDiscountValues = <String, double>{'price': 299, 'discount': 40};
    final deepDiscountResults = calculateTool(definition, deepDiscountValues);
    final deepDiscountInsights =
        buildToolInsights(definition, deepDiscountValues, deepDiscountResults)
            .join('\n');

    expect(deepDiscountResults.first.value, '119.6');
    expect(deepDiscountInsights, contains('优惠比例超过 50%'));

    final invalidDiscount =
        calculateTool(definition, {'price': 299, 'discount': 120});
    final invalidFinalPrice =
        calculateTool(definition, {'price': 299, 'finalPrice': 300});

    expect(invalidDiscount.first.value, '无效');
    expect(invalidFinalPrice.first.value, '无效');
  });

  test('tax tool reverse solves amounts rate and validates inputs', () {
    final definition = tool('tax');
    final values = <String, double>{'net': 1000, 'rate': 13};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['含税金额'], '1130');
    expect(valuesByLabel['税额'], '130');
    expect(valuesByLabel['不含税反推'], '1000');
    expect(valuesByLabel['税率'], '13');
    expect(valuesByLabel['税负率'], startsWith('11.504'));
    expect(valuesByLabel['价税合计倍率'], '1.13');
    expect(valuesByLabel['输入来源'], '税前金额+税率');
    expect(insights, contains('当前按 税前金额+税率 计算'));

    final netFromGross = calculateTool(definition, {
      'gross': 1130,
      'rate': 13,
    });
    final netFromGrossByLabel = {
      for (final result in netFromGross) result.label: result.value,
    };
    expect(netFromGrossByLabel['不含税反推'], '1000');
    expect(netFromGrossByLabel['税额'], '130');
    expect(netFromGrossByLabel['输入来源'], '含税金额+税率');

    final rateFromAmounts = calculateTool(definition, {
      'net': 1000,
      'gross': 1130,
    });
    final rateFromAmountsByLabel = {
      for (final result in rateFromAmounts) result.label: result.value,
    };
    expect(rateFromAmountsByLabel['税率'], '13');
    expect(rateFromAmountsByLabel['输入来源'], '税前金额+含税金额');

    final referenceGrossValues = <String, double>{
      'net': 1000,
      'rate': 13,
      'gross': 1120,
    };
    final referenceGrossResults =
        calculateTool(definition, referenceGrossValues);
    final referenceGrossByLabel = {
      for (final result in referenceGrossResults) result.label: result.value,
    };
    final referenceGrossInsights = buildToolInsights(
            definition, referenceGrossValues, referenceGrossResults)
        .join('\n');
    expect(referenceGrossByLabel['输入来源'], '税前金额+税率，含税金额作参考');
    expect(referenceGrossByLabel['含税金额差值'], '10');
    expect(referenceGrossInsights, contains('含税金额参考值与当前计算相差 10元'));

    final highTaxValues = <String, double>{'net': 1000, 'rate': 30};
    final highTaxResults = calculateTool(definition, highTaxValues);
    final highTaxInsights =
        buildToolInsights(definition, highTaxValues, highTaxResults).join('\n');

    expect(highTaxResults.first.value, '1300');
    expect(highTaxInsights, contains('税负率超过 20%'));

    final invalidResults =
        calculateTool(definition, {'net': 1000, 'rate': -100});
    final incompleteResults = calculateTool(definition, {'gross': 1130});

    expect(invalidResults.first.value, '无效');
    expect(incompleteResults.first.value, '无效');
  });

  // 中文：**`inflation` 工具已并进 `compound`**——这一段把那个工具原来的断言整段搬到合并后的工具上：
  //       键名换成 `principal` / `target`（同一台机器、同一批数），它那两行购买力输出（购买力折现、
  //       购买力损失）与那句"购买力损失为正"的提示照旧断言；原来的「未来等值 / 累计涨幅 / 等值倍率」
  //       在合并后的工具上叫「终值 / 收益率 / 增长倍数」，断言的**数一个没少**，只是标签换了。
  // English: **the `inflation` tool is merged into `compound`** — this block moves that tool's assertions
  //          onto the merged tool whole: the keys become `principal` / `target` (the same machine, the
  //          same numbers), its two purchasing-power rows (the discount and the loss) and the
  //          "purchasing-power loss is positive" hint are asserted as before, and the old
  //          `未来等值` / `累计涨幅` / `等值倍率` are `终值` / `收益率` / `增长倍数` on the merged tool —
  //          **not one number is dropped**, only the labels changed.
  test('compound tool reverse solves principal rate years with inflation rows',
      () {
    final definition = tool('compound');
    final values = <String, double>{'principal': 10000, 'rate': 3, 'years': 10};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['终值'], startsWith('13439.163'));
    expect(valuesByLabel['购买力折现'], startsWith('7440.939'));
    expect(valuesByLabel['收益率'], startsWith('34.391'));
    expect(valuesByLabel['购买力损失'], startsWith('2559.060'));
    expect(valuesByLabel['增长倍数'], startsWith('1.343'));
    expect(valuesByLabel['输入来源'], '本金+年化收益+年限');
    expect(insights, contains('购买力损失为正'));

    final amountFromFuture = calculateTool(definition, {
      'target': 13439.163793,
      'rate': 3,
      'years': 10,
    });
    final amountFromFutureByLabel = {
      for (final result in amountFromFuture) result.label: result.value,
    };
    expect(amountFromFutureByLabel['本金'], startsWith('10000'));
    expect(amountFromFutureByLabel['输入来源'], '目标终值+年化收益+年限');

    final rateFromFuture = calculateTool(definition, {
      'principal': 10000,
      'target': 13439.163793,
      'years': 10,
    });
    final rateFromFutureByLabel = {
      for (final result in rateFromFuture) result.label: result.value,
    };
    expect(rateFromFutureByLabel['年化收益率'], startsWith('3'));
    expect(rateFromFutureByLabel['输入来源'], '本金+目标终值+年限');

    final yearsFromFuture = calculateTool(definition, {
      'principal': 10000,
      'target': 13439.163793,
      'rate': 3,
    });
    final yearsFromFutureByLabel = {
      for (final result in yearsFromFuture) result.label: result.value,
    };
    expect(yearsFromFutureByLabel['年限'], startsWith('10'));
    expect(yearsFromFutureByLabel['输入来源'], '本金+目标终值+年化收益');

    final referenceFutureValues = <String, double>{
      'principal': 10000,
      'rate': 3,
      'years': 10,
      'target': 13000,
    };
    final referenceFutureResults =
        calculateTool(definition, referenceFutureValues);
    final referenceFutureByLabel = {
      for (final result in referenceFutureResults) result.label: result.value,
    };
    final referenceFutureInsights = buildToolInsights(
      definition,
      referenceFutureValues,
      referenceFutureResults,
    ).join('\n');
    expect(referenceFutureByLabel['输入来源'], '本金+年化收益+年限，目标终值作参考');
    expect(referenceFutureByLabel['终值差值'], startsWith('439.163'));
    expect(referenceFutureInsights, contains('目标终值与当前计算相差'));

    final invalidIncomplete = calculateTool(definition, {'target': 12000});
    final invalidRateSolve = calculateTool(definition, {
      'principal': 0,
      'target': 12000,
      'years': 10,
    });

    expect(invalidIncomplete.first.value, '无效');
    expect(invalidRateSolve.first.value, '无效');
  });

  test('npv tool reports discounted cash flow and negative npv warning', () {
    final definition = tool('npv');
    final values = <String, double>{
      'initial': 10000,
      'rate': 8,
      'cf1': 4000,
      'cf2': 5000,
      'cf3': 6000,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['NPV'], startsWith('2753.391'));
    expect(valuesByLabel['期数'], '3');
    expect(valuesByLabel['总现金流'], '15000');
    expect(valuesByLabel['折现现金流'], startsWith('12753.391'));
    expect(valuesByLabel['盈利指数'], startsWith('1.275'));
    expect(valuesByLabel['回收差额'], '5000');
    expect(valuesByLabel['折现回收期'], startsWith('2.421'));
    expect(valuesByLabel['简单回收期'], startsWith('2.166'));
    expect(valuesByLabel['折现率-2% NPV'], startsWith('3261.282'));
    expect(valuesByLabel['折现率+2% NPV'], startsWith('2276.483'));
    expect(valuesByLabel['等效年化收益'], startsWith('8.444'));
    expect(insights, contains('NPV 对折现率很敏感'));
    expect(insights, contains('当前按 3 期现金流估算'));

    final negativeValues = <String, double>{
      'initial': 5000,
      'rate': 10,
      'cf1': 1000,
      'cf2': 1000,
      'cf3': 1000,
    };
    final negativeResults = calculateTool(definition, negativeValues);
    final negativeInsights =
        buildToolInsights(definition, negativeValues, negativeResults)
            .join('\n');

    expect(negativeResults.first.value, startsWith('-2513.148'));
    expect(negativeInsights, contains('NPV 为负'));
    expect(negativeInsights, contains('盈利指数低于 1'));
    expect(negativeInsights, contains('尚未回收初始投入'));
  });

  test('npv tool handles optional five period cash flows', () {
    final definition = tool('npv');
    final values = <String, double>{
      'initial': 12000,
      'rate': 7,
      'cf1': 2000,
      'cf2': 3000,
      'cf3': 3500,
      'cf4': 4000,
      'cf5': 4500,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['期数'], '5');
    expect(valuesByLabel['总现金流'], '17000');
    expect(valuesByLabel['NPV'], startsWith('1606.536'));
    expect(valuesByLabel['折现现金流'], startsWith('13606.536'));
    expect(valuesByLabel['盈利指数'], startsWith('1.133'));
    expect(valuesByLabel['折现回收期'], startsWith('4.499'));
    expect(valuesByLabel['简单回收期'], startsWith('3.875'));
    expect(valuesByLabel['等效年化收益'], startsWith('2.544'));
    expect(insights, contains('当前按 5 期现金流估算'));
  });

  test('financial edge cases do not expose infinity text', () {
    // 中文：**这条原来量的是 `inflation` 工具**；它并进 `compound` 之后，同一组边界（金额 1000、
    //       年率 -100）改在合并后的工具上量——`rate <= -100` 在两条路径上都是"无效"，断言一字未改。
    // English: **this used to measure the `inflation` tool**; after the merge the same edge (amount
    //          1000, rate -100) is measured on the merged tool — `rate <= -100` is "invalid" on both
    //          paths, and not a word of the assertion moved.
    final inflation = calculateTool(
        tool('compound'), {'principal': 1000, 'rate': -100, 'years': 1});
    final npv = calculateTool(tool('npv'), {
      'initial': 1000,
      'rate': -100,
      'cf1': 100,
      'cf2': 100,
      'cf3': 100,
    });

    expect(inflation.map((item) => item.value).join('\n'),
        isNot(contains('Infinity')));
    expect(inflation.map((item) => item.value).join('\n'), contains('无效'));
    expect(
        npv.map((item) => item.value).join('\n'), isNot(contains('Infinity')));
    expect(npv.first.value, '无效');
  });
}
