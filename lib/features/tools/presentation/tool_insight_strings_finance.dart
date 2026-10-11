/// 中文：**财务类工具洞察句的英文**——`tool_insights_finance.dart` 里那些句子的中文→英文表。
///       键是中文本身，查不到就原样返回（机制见 `tool_insight_strings.dart` 的文件头）。
///       带插值的句子在下面那张模板表里：键是源码原文（含 `$…`），英文一侧的 `{}` 是载荷位。
/// English: **the English of the finance-category tool insight sentences** — the Chinese→English
///          table for the sentences in `tool_insights_finance.dart`. The key is the Chinese itself
///          and a miss returns it unchanged (the mechanism is on `tool_insight_strings.dart`'s head).
///          Interpolated sentences sit in the template table below: the key is the source text
///          (including `$…`) and each `{}` on the English side is a payload slot.
library;

const Map<String, String> toolInsightsFinanceEn = <String, String>{
  '贷款金额、年利率、贷款年限和目标月供至少填写三项；年利率需大于 -100%，贷款年限必须大于 0': 'Fill at least three of loan amount, annual rate, term and target payment; the annual rate must be above -100% and the term must be above 0',
  '总利息超过本金 50%，建议比较更短期限、提前还款或更低利率方案': 'Total interest is over 50% of the principal; compare a shorter term, early repayment or a lower rate',
  '按等额本息算，提前还款、手续费和浮动利率未计入': 'Computed as equal instalments of principal and interest; early repayment, fees and a floating rate are not included',
  '每期投入、年化收益、年限和目标终值至少填写三项；年化收益需大于 -100%，每年期数必须大于 0': 'Fill at least three of payment, annual return, years and target value; the annual return must be above -100% and periods per year must be above 0',
  '收益为负，表示当前收益率和期限下本金发生亏损': 'A negative return means the principal loses money at the current return rate and term',
  '年金按期末投入估算，实际定投日、申购费、税费和收益波动未计入': 'The annuity is estimated with end-of-period payments; actual investment dates, subscription fees, taxes and return volatility are not included',
  '商品价格、总手续费率、分期期数和目标每期至少填写三项；价格和手续费率不能为负，期数必须大于 0': 'Fill at least three of item price, total fee rate, instalment count and target payment; price and fee rate cannot be negative and the instalment count must be above 0',
  '总手续费率超过 20%，建议换算年化成本后再比较': 'Total fee rate is over 20%; convert it to an annualised cost before comparing',
  '分期按总手续费平均摊到每期，未按真实 IRR 年化利率折算': 'Instalments spread the total fee evenly across periods; not converted at the true annualised IRR',
  '边际贡献不大于 0，卖得越多也无法覆盖固定成本': 'Contribution is 0 or less; selling more still cannot cover the fixed cost',
  '固定成本、单价、单位变动成本和目标销量至少填写三项；固定成本和单位变动成本不能为负，单价和目标销量必须大于 0，反推结果需保持边际贡献大于 0': 'Fill at least three of fixed cost, unit price, unit variable cost and sales target; fixed cost and unit variable cost cannot be negative, unit price and sales target must be above 0, and a back-solved result must keep the contribution above 0',
  '盈亏平衡只看单品静态模型，折扣、退货、渠道费和产能限制未计入': 'Break-even is a static single-product model; discounts, returns, channel fees and capacity limits are not included',
  '功率、每日使用、天数、电价和目标费用至少填写四项；数值不能为负，每日使用不能超过 24 小时，反推时分母不能为 0': 'Fill at least four of power, daily use, days, tariff and target cost; values cannot be negative, daily use cannot exceed 24 hours, and the denominator cannot be 0 when back-solving',
  '日均用电超过 20kWh，长期运行成本和线路容量需要单独核对': 'Daily energy is over 20kWh; the long-run cost and circuit capacity need a separate check',
  '电费按固定单价估算，阶梯电价、峰谷电价、需量电费和功率因数未计入': 'Electricity cost is estimated at a flat tariff; tiered tariffs, peak/off-peak tariffs, demand charges and power factor are not included',
  '本金、年化收益、年限和目标终值至少填写三项；本金和目标终值不能为负，年化收益需大于 -100%，年限不能为负，反推年化收益或年限时分母不能为 0': 'Fill at least three of principal, annual return, years and target value; principal and target value cannot be negative, the annual return must be above -100%, years cannot be negative, and the denominator cannot be 0 when back-solving the annual return or the years',
  '收益为负，表示复利期末金额低于初始本金': 'A negative return means the compounded end amount is below the starting principal',
  '购买力损失为正，表示同样金额未来实际购买力下降': 'A positive buying-power loss means the same amount buys less in the future',
  '年化收益率为负，当前相当于按固定通缩率估算': 'The annual return rate is negative; the current figure is equivalent to estimating at a fixed deflation rate',
  '增长倍数超过 2x，可以同步看最大回撤和波动风险': 'Growth multiple is over 2x; check the maximum drawdown and volatility risk alongside',
  '复利按固定年化收益估算，未计入追加投入、提现、税费、手续费和收益波动': 'Compounding is estimated at a fixed annual return; top-ups, withdrawals, taxes, fees and return volatility are not included',
  '通胀按固定年率估算，实际价格篮子、地区差异和收入变化未计入': 'Inflation is estimated at a fixed annual rate; the actual price basket, regional differences and income changes are not included',
  '成本、售价、目标毛利率和目标利润至少填写两项；成本不能为负，售价必须大于 0，目标毛利率必须小于 100%，反推结果不能让售价或成本为负': 'Fill at least two of cost, price, target margin and target profit; cost cannot be negative, price must be above 0, the target margin must be below 100%, and a back-solved result must not make the price or the cost negative',
  '当前售价低于成本，单件销售会亏损': 'The current price is below cost; each unit sold loses money',
  '毛利率低于 15%，渠道费、退货和损耗可能很快吞掉利润': 'Gross margin is below 15%; channel fees, returns and shrinkage can eat the profit quickly',
  '利润率只看单件毛利，未计入平台抽佣、物流、人工、税费和库存损耗': 'The margin covers per-unit gross profit only; platform commission, logistics, labour, taxes and inventory shrinkage are not included',
  '收益、投入和 ROI 至少填写两项；投入必须大于 0，收益不能为负，ROI 不能低于 -100%；填写持有年限时年限必须大于 0': 'Fill at least two of gain, cost and ROI; cost must be above 0, gain cannot be negative and ROI cannot be below -100%; holding years, when filled, must be above 0',
  'ROI 为负，当前收益没有覆盖投入成本': 'ROI is negative; the current gain does not cover the cost',
  'ROI 超过 100%，建议复核收益口径、周期和一次性收益': 'ROI is over 100%; review the gain definition, the period and any one-off gain',
  '年化 ROI 为负，持有期越长资金机会成本越明显': 'Annual ROI is negative; the longer the holding period, the larger the opportunity cost of the capital',
  '年化 ROI 超过 30%，建议复核收益是否可持续、是否包含一次性收益': 'Annual ROI is over 30%; check whether the gain is sustainable and whether it includes a one-off gain',
  '已按持有年限折算年化 ROI，便于和不同周期项目比较': 'Annual ROI is derived from the holding years, for comparison with projects of other periods',
  '未填写持有年限，当前 ROI 不包含时间维度': 'Holding years are not filled in; the current ROI has no time dimension',
  '按当前净收益无法回收投入': 'The current net gain never recovers the cost',
  '原价、折扣和到手价至少填写两项；原价必须大于 0，折扣需在 0% 到 100%，到手价不能为负且不能高于原价': 'Fill at least two of original price, discount and final price; the original price must be above 0, the discount must be between 0% and 100%, and the final price cannot be negative or above the original price',
  '优惠比例超过 50%，建议核对是否存在限量、凑单、运费或售后条件': 'The discount is over 50%; check for quantity limits, add-on items, shipping or after-sales conditions',
  '折扣计算只看标价优惠，未计入满减门槛、券后返现、运费和税费': 'The discount covers listed-price savings only; minimum-spend thresholds, coupon cashback, shipping and taxes are not included',
  '初始投入不能为负，折现率需大于 -100%，至少需要 1 期有限现金流': 'The initial cost cannot be negative, the discount rate must be above -100%, and at least 1 period of finite cash flow is required',
  'NPV 为负，按当前折现率估算项目没有覆盖资金成本': 'NPV is negative; at the current discount rate the project does not cover the cost of capital',
  '盈利指数低于 1，折现现金流小于初始投入': 'The profitability index is below 1; the discounted cash flow is less than the initial cost',
  '折现现金流在当前期数内尚未回收初始投入': 'The discounted cash flows do not recover the initial cost within the current period count',
  '折现率上下浮动 2% 会改变 NPV 正负，项目对资金成本非常敏感': 'A 2% swing either way in the discount rate flips the sign of NPV; the project is very sensitive to the cost of capital',
  'NPV 对折现率很敏感，最好用不同折现率再扫一遍': 'NPV is very sensitive to the discount rate; sweep it again at other rates',
  '税前金额、税率和含税金额至少填写两项；金额不能为负，税率需大于 -100%，按税前金额和含税金额反推时税前金额必须大于 0': 'Fill at least two of net amount, tax rate and gross amount; amounts cannot be negative and the tax rate must be above -100%; when back-solving from the net and the gross, the net amount must be above 0',
  '税负率超过 20%，报价和现金流需要预留足够税费空间': 'The tax burden is over 20%; quotes and cash flows need to set aside enough room for tax',
  '这里只按简单税率换算，不区分价内税、价外税、抵扣规则和地区税制': 'This converts by a simple tax rate only; tax-inclusive and tax-exclusive pricing, deduction rules and regional tax systems are not distinguished',
};

/// 中文：带插值的句子。键是源码原文，英文一侧的 `{}` 按出现顺序接住载荷。
/// English: interpolated sentences. The key is the source text; each `{}` on the English side takes
///          the payloads in order.
const Map<String, String> toolInsightTemplatesFinanceEn = <String, String>{
  r'目标月供与当前月供相差 ${formatNumber(paymentDelta)}元': 'Target payment differs from the current payment by {} CNY',
  r'目标终值与当前终值相差 ${formatNumber(targetDelta)}元': 'Target future value differs from the current future value by {} CNY',
  r'目标每期与当前每期付款相差 ${formatNumber(paymentDelta)}元': 'Target payment per period differs from the current payment by {} CNY',
  r'当前按 $source 计算，其余输出由Q=固定成本/(单价-单位变动成本)换算': 'Computed from {}; the other outputs follow from Q=fixed cost/(unit price-unit variable cost)',
  r'目标销量与当前平衡销量相差 ${formatNumber(quantityDelta)}件': 'The sales target differs from the current break-even units by {} units',
  r'当前按 $source 计算，其余输出由费用=P(kW)×每日使用×天数×电价换算': 'Computed from {}; the other outputs follow from cost=P(kW)×daily use×days×tariff',
  r'目标费用与当前计算相差 ${formatNumber(costDelta)}元': 'Target cost differs from the current result by {} CNY',
  r'当前按 $source 计算，其余输出由 FV=PV×(1+r)^n 换算': 'Computed from {}; the other outputs follow from FV=PV×(1+r)^n',
  r'目标终值与当前计算相差 ${formatNumber(targetDelta)}元': 'Target future value differs from the current result by {} CNY',
  r'当前按 $source 计算，其余输出由利润=售价-成本、毛利率=利润/售价换算': 'Computed from {}; the other outputs follow from profit=price-cost, margin=profit/price',
  r'目标利润与当前计算相差 ${formatNumber(profitDelta)}元': 'Target profit differs from the current result by {} CNY',
  r'目标毛利率与当前计算相差 ${formatNumber(marginDelta)}%': 'Target gross margin differs from the current result by {}%',
  r'当前按 $source 计算，其余输出由收益=投入×(1+ROI)换算': 'Computed from {}; the other outputs follow from gain=cost×(1+ROI)',
  r'ROI 参考值与当前计算相差 ${formatNumber(roiDelta)}%': 'The ROI reference differs from the current result by {}%',
  r'简单回收期约 $payback 年，未考虑现金流发生时间和折现': 'Simple payback about {} years, ignoring when the cash flows occur and discounting',
  r'当前按 $source 计算，其余输出由到手价=原价×折扣/100换算': 'Computed from {}; the other outputs follow from final price=original price×discount/100',
  r'到手价参考值与当前计算相差 ${formatNumber(finalPriceDelta)}元': 'The final price reference differs from the current result by {} CNY',
  r'折现回收期约 $payback 期，需结合现金流稳定性判断': 'Discounted payback about {} periods; judge it together with the stability of the cash flows',
  r'当前按 ${periodCount.round()} 期现金流估算': 'Estimated from {} periods of cash flow',
  r'当前按 $source 计算，其余输出由含税金额=税前金额×(1+税率)换算': 'Computed from {}; the other outputs follow from gross=net×(1+tax rate)',
  r'含税金额参考值与当前计算相差 ${formatNumber(grossDelta)}元': 'The gross amount reference differs from the current result by {} CNY',
};
