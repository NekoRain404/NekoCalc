/// 中文：**生活类工具洞察句的英文**——`tool_insights_lifestyle.dart` 里那些句子的中文→英文表。
///       键是中文本身，查不到就原样返回（机制见 `tool_insight_strings.dart` 的文件头）。
///       带插值的句子在下面那张模板表里：键是源码原文（含 `$…`），英文一侧的 `{}` 是载荷位。
/// English: **the English of the lifestyle-category tool insight sentences** — the Chinese→English
///          table for the sentences in `tool_insights_lifestyle.dart`. The key is the Chinese itself
///          and a miss returns it unchanged (the mechanism is on `tool_insight_strings.dart`'s head).
///          Interpolated sentences sit in the template table below: the key is the source text
///          (including `$…`) and each `{}` on the English side is a payload slot.
library;

const Map<String, String> toolInsightsLifestyleEn = <String, String>{
  '身高和体重必须大于 0；填写腰围时腰围也必须大于 0': 'Height and weight must be greater than 0; a filled-in waist must be greater than 0 too',
  'BMI 低于 18.5，体重低于常见健康区间': 'BMI below 18.5, weight below the common healthy band',
  'BMI 达到肥胖区间，建议结合腰围、血压、血糖和运动情况综合判断': 'BMI is in the obese band; combine waist, blood pressure, blood glucose and physical activity for the overall judgement',
  'BMI 进入超重区间，体重管理可优先看腰围和长期趋势': 'BMI is in the overweight band; waist and long-term trend come first in weight management',
  'BMI 位于常见健康区间': 'BMI is within the common healthy band',
  '腰高比达到 0.5 或更高，腹型肥胖风险需要额外关注': 'Waist-to-height ratio is 0.5 or higher; abdominal obesity risk needs extra attention',
  'BMI 不能区分肌肉和脂肪，只能做筛查参考': 'BMI cannot distinguish muscle from fat and is a screening reference only',
  '里程、燃油量和百公里油耗至少填写两项且必须大于 0；油价不能为负；可选油箱、年里程和 CO2 系数需为有效数值': 'Fill at least two of distance, fuel and consumption per 100 km, and each must be greater than 0; the fuel price cannot be negative; the optional tank, annual distance and CO2 factor must be valid numbers',
  '百公里油耗低于 4L，结果可能来自高速巡航、混动工况或加油量记录偏差': 'Consumption per 100 km below 4L; the result may come from highway cruising, hybrid operation or a mis-recorded refuel volume',
  '百公里油耗高于 12L，建议检查路况、胎压、载重、短途冷车和驾驶习惯': 'Consumption per 100 km above 12L; check road conditions, tyre pressure, load, short cold-engine trips and driving habits',
  '百公里燃油成本超过 100 元，油价或油耗变化会明显影响用车预算': 'Fuel cost per 100 km above 100 ¥; a change in fuel price or consumption clearly affects the running budget',
  '满箱续航低于 400km，长途前需要更保守地规划补能点': 'Tank range below 400km; plan refuelling stops more conservatively before a long trip',
  '年燃油费用超过 15000 元，可用年行驶里程和油价做预算敏感性对比': 'Annual fuel cost above 15000 ¥; use annual distance and fuel price for a budget-sensitivity comparison',
  '年 CO2 粗估超过 3 吨，排放取决于燃油类型、实际油耗和统计口径': 'Rough annual CO2 estimate above 3 tonnes; emissions depend on fuel type, actual consumption and the accounting basis',
  '路况、载重、胎压、空调和驾驶习惯都会改变油耗': 'Road conditions, load, tyre pressure, air conditioning and driving habits all change consumption',
};

/// 中文：带插值的句子。键是源码原文，英文一侧的 `{}` 按出现顺序接住载荷。
/// English: interpolated sentences. The key is the source text; each `{}` on the English side takes
///          the payloads in order.
const Map<String, String> toolInsightTemplatesLifestyleEn = <String, String>{
  r'按当前身高估算的健康体重范围约为 $range kg': 'The healthy weight range for this height is about {} kg',
  r'距健康体重区间还差 $delta，正号表示需要增重，负号表示需要减重': 'The gap to the healthy weight band is {}; a plus sign means weight to gain, a minus sign means weight to lose',
  r'当前按 $source 计算，其余输出由 fuel=distance×L/100km/100 换算': 'Currently computed from {}; the remaining outputs are converted with fuel=distance×L/100km/100',
  r'油耗参考值与当前计算相差 ${formatNumber(consumptionDelta)}L/100km': 'The reference consumption differs from the current calculation by {}L/100km',
};
