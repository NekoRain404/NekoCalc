import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';
import 'tool_insight_result_readers.dart';

bool isFinanceInsightTool(ToolKind kind) {
  switch (kind) {
    case ToolKind.loan:
    case ToolKind.annuity:
    case ToolKind.installment:
    case ToolKind.breakEven:
    case ToolKind.electricityCost:
    case ToolKind.compound:
    case ToolKind.profitMargin:
    case ToolKind.roi:
    case ToolKind.discount:
    case ToolKind.tax:
    case ToolKind.inflation:
    case ToolKind.npv:
      return true;
    default:
      return false;
  }
}

List<String> buildFinanceToolInsights(
  ToolKind kind,
  Map<String, double> v,
  List<ToolResult> results,
) {
  final lines = <String>[];
  switch (kind) {
    case ToolKind.loan:
      final paymentText = toolResultText(results, '每月还款额');
      final interestRatio = toolResultNumber(results, '利息占本金');
      final paymentDelta = toolResultNumber(results, '月供差值');
      if (paymentText == '无效') {
        lines.add('贷款金额、年利率、贷款年限和目标月供至少填写三项；年利率需大于 -100%，贷款年限必须大于 0');
      }
      if (interestRatio != null && interestRatio > 50) {
        lines.add('总利息超过本金 50%，建议比较更短期限、提前还款或更低利率方案');
      }
      if (paymentDelta != null) {
        lines.add('目标月供与当前月供相差 ${formatNumber(paymentDelta)}元');
      }
      lines.add('按等额本息算，提前还款、手续费和浮动利率未计入');
    case ToolKind.annuity:
      final fvText = toolResultText(results, '终值');
      final gain = toolResultNumber(results, '收益');
      final targetDelta = toolResultNumber(results, '终值差值');
      if (fvText == '无效') {
        lines.add('每期投入、年化收益、年限和目标终值至少填写三项；年化收益需大于 -100%，每年期数必须大于 0');
      }
      if (gain != null && gain < 0) lines.add('收益为负，表示当前收益率和期限下本金发生亏损');
      if (targetDelta != null) {
        lines.add('目标终值与当前终值相差 ${formatNumber(targetDelta)}元');
      }
      lines.add('年金按期末投入估算，实际定投日、申购费、税费和收益波动未计入');
    case ToolKind.installment:
      final paymentText = toolResultText(results, '每期付款');
      final feeRate = toolResultNumber(results, '总手续费率') ?? v['fee'] ?? 0;
      final paymentDelta = toolResultNumber(results, '每期差值');
      if (paymentText == '无效') {
        lines.add('商品价格、总手续费率、分期期数和目标每期至少填写三项；价格和手续费率不能为负，期数必须大于 0');
      }
      if (feeRate > 20) lines.add('总手续费率超过 20%，建议换算年化成本后再比较');
      if (paymentDelta != null) {
        lines.add('目标每期与当前每期付款相差 ${formatNumber(paymentDelta)}元');
      }
      lines.add('分期按总手续费平均摊到每期，未按真实 IRR 年化利率折算');
    case ToolKind.breakEven:
      final quantityText = toolResultText(results, '平衡销量');
      final margin = toolResultNumber(results, '边际贡献');
      final source = toolResultText(results, '输入来源') ?? '';
      final quantityDelta = toolResultNumber(results, '销量差值');
      if (quantityText == '无效' && margin != null && margin <= 0) {
        lines.add('边际贡献不大于 0，卖得越多也无法覆盖固定成本');
      } else if (quantityText == '无效') {
        lines.add(
            '固定成本、单价、单位变动成本和目标销量至少填写三项；固定成本和单位变动成本不能为负，单价和目标销量必须大于 0，反推结果需保持边际贡献大于 0');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由Q=固定成本/(单价-单位变动成本)换算');
      }
      if (quantityDelta != null && quantityDelta.abs() > 1e-12) {
        lines.add('目标销量与当前平衡销量相差 ${formatNumber(quantityDelta)}件');
      }
      lines.add('盈亏平衡只看单品静态模型，折扣、退货、渠道费和产能限制未计入');
    case ToolKind.electricityCost:
      final costText = toolResultText(results, '费用');
      final dailyEnergy = toolResultNumber(results, '日均用电');
      final source = toolResultText(results, '输入来源') ?? '';
      final costDelta = toolResultNumber(results, '费用差值');
      if (costText == '无效') {
        lines.add('功率、每日使用、天数、电价和目标费用至少填写四项；数值不能为负，每日使用不能超过 24 小时，反推时分母不能为 0');
      }
      if (dailyEnergy != null && dailyEnergy > 20) {
        lines.add('日均用电超过 20kWh，长期运行成本和线路容量需要单独核对');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由费用=P(kW)×每日使用×天数×电价换算');
      }
      if (costDelta != null && costDelta.abs() > 1e-12) {
        lines.add('目标费用与当前计算相差 ${formatNumber(costDelta)}元');
      }
      lines.add('电费按固定单价估算，阶梯电价、峰谷电价、需量电费和功率因数未计入');
    case ToolKind.compound:
      final fvText = toolResultText(results, '终值');
      final gain = toolResultNumber(results, '收益');
      final multiple = toolResultNumber(results, '增长倍数');
      final source = toolResultText(results, '输入来源') ?? '';
      final targetDelta = toolResultNumber(results, '终值差值');
      if (fvText == '无效') {
        lines.add(
            '本金、年化收益、年限和目标终值至少填写三项；本金和目标终值不能为负，年化收益需大于 -100%，年限不能为负，反推年化收益或年限时分母不能为 0');
      }
      if (gain != null && gain < 0) lines.add('收益为负，表示复利期末金额低于初始本金');
      if (multiple != null && multiple >= 2) {
        lines.add('增长倍数超过 2x，可以同步看最大回撤和波动风险');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由 FV=PV×(1+r)^n 换算');
      }
      if (targetDelta != null && targetDelta.abs() > 1e-12) {
        lines.add('目标终值与当前计算相差 ${formatNumber(targetDelta)}元');
      }
      lines.add('复利按固定年化收益估算，未计入追加投入、提现、税费、手续费和收益波动');
    case ToolKind.profitMargin:
      final profitText = toolResultText(results, '利润');
      final profit = toolResultNumber(results, '利润');
      final margin = toolResultNumber(results, '毛利率');
      final source = toolResultText(results, '输入来源') ?? '';
      final profitDelta = toolResultNumber(results, '利润差值');
      final marginDelta = toolResultNumber(results, '毛利率差值');
      if (profitText == '无效') {
        lines.add(
            '成本、售价、目标毛利率和目标利润至少填写两项；成本不能为负，售价必须大于 0，目标毛利率必须小于 100%，反推结果不能让售价或成本为负');
      }
      if (profit != null && profit < 0) lines.add('当前售价低于成本，单件销售会亏损');
      if (margin != null && margin < 15) {
        lines.add('毛利率低于 15%，渠道费、退货和损耗可能很快吞掉利润');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由利润=售价-成本、毛利率=利润/售价换算');
      }
      if (profitDelta != null && profitDelta.abs() > 1e-12) {
        lines.add('目标利润与当前计算相差 ${formatNumber(profitDelta)}元');
      }
      if (marginDelta != null && marginDelta.abs() > 1e-12) {
        lines.add('目标毛利率与当前计算相差 ${formatNumber(marginDelta)}%');
      }
      lines.add('利润率只看单件毛利，未计入平台抽佣、物流、人工、税费和库存损耗');
    case ToolKind.roi:
      final roiText = toolResultText(results, 'ROI');
      final roi = toolResultNumber(results, 'ROI');
      final annualRoi = toolResultNumber(results, '年化ROI');
      final payback = toolResultText(results, '简单回收期');
      final source = toolResultText(results, '输入来源') ?? '';
      final roiDelta = toolResultNumber(results, 'ROI差值');
      if (roiText == '无效') {
        lines.add(
            '收益、投入和 ROI 至少填写两项；投入必须大于 0，收益不能为负，ROI 不能低于 -100%；填写持有年限时年限必须大于 0');
      }
      if (roi != null && roi < 0) lines.add('ROI 为负，当前收益没有覆盖投入成本');
      if (roi != null && roi > 100) {
        lines.add('ROI 超过 100%，建议复核收益口径、周期和一次性收益');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由收益=投入×(1+ROI)换算');
      }
      if (roiDelta != null && roiDelta.abs() > 1e-12) {
        lines.add('ROI 参考值与当前计算相差 ${formatNumber(roiDelta)}%');
      }
      if (annualRoi != null) {
        if (annualRoi < 0) {
          lines.add('年化 ROI 为负，持有期越长资金机会成本越明显');
        } else if (annualRoi > 30) {
          lines.add('年化 ROI 超过 30%，建议复核收益是否可持续、是否包含一次性收益');
        } else {
          lines.add('已按持有年限折算年化 ROI，便于和不同周期项目比较');
        }
      } else {
        lines.add('未填写持有年限，当前 ROI 不包含时间维度');
      }
      if (payback == '未回收') {
        lines.add('按当前净收益无法回收投入');
      } else if (payback != null && payback != '无效') {
        lines.add('简单回收期约 $payback 年，未考虑现金流发生时间和折现');
      }
    case ToolKind.discount:
      final finalPriceText = toolResultText(results, '到手价');
      final savingRatio = toolResultNumber(results, '优惠比例');
      final source = toolResultText(results, '输入来源') ?? '';
      final finalPriceDelta = toolResultNumber(results, '到手价差值');
      if (finalPriceText == '无效') {
        lines.add('原价、折扣和到手价至少填写两项；原价必须大于 0，折扣需在 0% 到 100%，到手价不能为负且不能高于原价');
      }
      if (savingRatio != null && savingRatio >= 50) {
        lines.add('优惠比例超过 50%，建议核对是否存在限量、凑单、运费或售后条件');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由到手价=原价×折扣/100换算');
      }
      if (finalPriceDelta != null && finalPriceDelta.abs() > 1e-12) {
        lines.add('到手价参考值与当前计算相差 ${formatNumber(finalPriceDelta)}元');
      }
      lines.add('折扣计算只看标价优惠，未计入满减门槛、券后返现、运费和税费');
    case ToolKind.npv:
      final npvText = toolResultText(results, 'NPV');
      final npv = toolResultNumber(results, 'NPV');
      final profitabilityIndex = toolResultNumber(results, '盈利指数');
      final payback = toolResultText(results, '折现回收期') ?? '';
      final periodCount = toolResultNumber(results, '期数');
      final lowerRateNpv = toolResultNumber(results, '折现率-2% NPV');
      final higherRateNpv = toolResultNumber(results, '折现率+2% NPV');
      if (npvText == '无效') {
        lines.add('初始投入不能为负，折现率需大于 -100%，至少需要 1 期有限现金流');
      }
      if (npv != null && npv < 0) lines.add('NPV 为负，按当前折现率估算项目没有覆盖资金成本');
      if (profitabilityIndex != null && profitabilityIndex < 1) {
        lines.add('盈利指数低于 1，折现现金流小于初始投入');
      }
      if (payback == '未回收') {
        lines.add('折现现金流在当前期数内尚未回收初始投入');
      } else if (payback.isNotEmpty && payback != '无效') {
        lines.add('折现回收期约 $payback 期，需结合现金流稳定性判断');
      }
      if (periodCount != null) lines.add('当前按 ${periodCount.round()} 期现金流估算');
      if (lowerRateNpv != null &&
          higherRateNpv != null &&
          lowerRateNpv.sign != higherRateNpv.sign) {
        lines.add('折现率上下浮动 2% 会改变 NPV 正负，项目对资金成本非常敏感');
      }
      lines.add('NPV 对折现率很敏感，最好用不同折现率再扫一遍');
    case ToolKind.tax:
      final grossText = toolResultText(results, '含税金额');
      final taxBurden = toolResultNumber(results, '税负率');
      final source = toolResultText(results, '输入来源') ?? '';
      final grossDelta = toolResultNumber(results, '含税金额差值');
      if (grossText == '无效') {
        lines.add(
            '税前金额、税率和含税金额至少填写两项；金额不能为负，税率需大于 -100%，按税前金额和含税金额反推时税前金额必须大于 0');
      }
      if (taxBurden != null && taxBurden > 20) {
        lines.add('税负率超过 20%，报价和现金流需要预留足够税费空间');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由含税金额=税前金额×(1+税率)换算');
      }
      if (grossDelta != null && grossDelta.abs() > 1e-12) {
        lines.add('含税金额参考值与当前计算相差 ${formatNumber(grossDelta)}元');
      }
      lines.add('这里只按简单税率换算，不区分价内税、价外税、抵扣规则和地区税制');
    case ToolKind.inflation:
      final futureText = toolResultText(results, '未来等值');
      final loss = toolResultNumber(results, '购买力损失');
      final rate = toolResultNumber(results, '年通胀率');
      final source = toolResultText(results, '输入来源') ?? '';
      final futureDelta = toolResultNumber(results, '未来等值差值');
      if (futureText == '无效') {
        lines.add(
            '当前金额、年通胀率、年数和未来等值至少填写三项；金额不能为负，年通胀率需大于 -100%，年数不能为负，反推通胀率或年数时分母不能为 0');
      }
      if (loss != null && loss > 0) lines.add('购买力损失为正，表示同样金额未来实际购买力下降');
      if (rate != null && rate < 0) lines.add('年通胀率为负，当前相当于按固定通缩率估算');
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 计算，其余输出由 FV=PV×(1+i)^n 换算');
      }
      if (futureDelta != null && futureDelta.abs() > 1e-12) {
        lines.add('未来等值参考值与当前计算相差 ${formatNumber(futureDelta)}元');
      }
      lines.add('通胀按固定年率估算，实际价格篮子、地区差异和收入变化未计入');
    default:
      break;
  }
  return lines;
}
