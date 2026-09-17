import '../entities/tool_category.dart';
import '../entities/tool_definition.dart';

final List<ToolDefinition> financeToolDefinitions = [
  const ToolDefinition(
    id: 'loan',
    title: '贷款月供',
    description: '等额本息月供、首月拆分和利息占比',
    category: ToolCategory.finance,
    kind: ToolKind.loan,
    group: '借贷',
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'amount',
          label: '贷款金额',
          unit: '万元',
          defaultValue: 50,
          optional: true),
      ToolInputDefinition(
          key: 'rate',
          label: '年利率',
          unit: '%',
          defaultValue: 4.1,
          optional: true),
      ToolInputDefinition(
          key: 'years',
          label: '贷款年限',
          unit: '年',
          defaultValue: 20,
          optional: true),
      ToolInputDefinition(
          key: 'targetPayment', label: '目标月供', unit: '元', optional: true),
    ],
    formula: 'M = P × r(1+r)^n / ((1+r)^n - 1), P = M / paymentFactor',
    explanation:
        '贷款金额、年利率、贷款年限和目标月供任意填写三项，可正算月供或反推可贷金额/年利率，并输出总利息、首月拆分、利息占本金、年还款额和目标差值。',
  ),
  const ToolDefinition(
    id: 'annuity',
    title: '年金终值',
    description: '定投终值、累计投入、收益和期数',
    category: ToolCategory.finance,
    kind: ToolKind.annuity,
    group: '投资',
    inputs: [
      ToolInputDefinition(
          key: 'payment',
          label: '每期投入',
          unit: '元',
          defaultValue: 1000,
          optional: true),
      ToolInputDefinition(
          key: 'rate',
          label: '年化收益',
          unit: '%',
          defaultValue: 5,
          optional: true),
      ToolInputDefinition(
          key: 'years',
          label: '年限',
          unit: '年',
          defaultValue: 10,
          optional: true),
      ToolInputDefinition(
          key: 'perYear', label: '每年期数', unit: '期', defaultValue: 12),
      ToolInputDefinition(
          key: 'target', label: '目标终值', unit: '元', optional: true),
    ],
    formula: 'FV = PMT × ((1+r)^n - 1) / r, PMT = FV / factor',
    explanation:
        '每期投入、年化收益、年限和目标终值任意填写三项，可正算终值或反推每期投入/年化收益，并输出累计投入、收益、期数、每期收益率和目标差值。',
  ),
  const ToolDefinition(
    id: 'installment',
    title: '分期付款',
    description: '商品分期每期付款、手续费和费率',
    category: ToolCategory.finance,
    kind: ToolKind.installment,
    group: '借贷',
    inputs: [
      ToolInputDefinition(
          key: 'price',
          label: '商品价格',
          unit: '元',
          defaultValue: 6000,
          optional: true),
      ToolInputDefinition(
          key: 'fee',
          label: '总手续费率',
          unit: '%',
          defaultValue: 6,
          optional: true),
      ToolInputDefinition(
          key: 'months',
          label: '分期期数',
          unit: '期',
          defaultValue: 12,
          optional: true),
      ToolInputDefinition(
          key: 'targetPayment', label: '目标每期', unit: '元', optional: true),
    ],
    formula: '月供 = 价格 × (1 + 手续费率) / 期数',
    explanation:
        '商品价格、总手续费率、分期期数和目标每期任意填写三项，可正算每期付款或反推可承受价格/手续费率，并输出本金拆分、手续费、总支付和目标差值。',
  ),
  const ToolDefinition(
    id: 'break_even',
    title: '盈亏平衡',
    description: '固定成本、边际贡献和平衡销售额',
    category: ToolCategory.finance,
    kind: ToolKind.breakEven,
    group: '商业',
    inputs: [
      ToolInputDefinition(
          key: 'fixed',
          label: '固定成本',
          unit: '元',
          defaultValue: 50000,
          optional: true),
      ToolInputDefinition(
          key: 'price',
          label: '单价',
          unit: '元',
          defaultValue: 120,
          optional: true),
      ToolInputDefinition(
          key: 'variable',
          label: '单位变动成本',
          unit: '元',
          defaultValue: 70,
          optional: true),
      ToolInputDefinition(
          key: 'targetQuantity', label: '目标销量', unit: '件', optional: true),
    ],
    formula: 'Q = fixed / (price - variable), price = fixed / Q + variable',
    explanation:
        '固定成本、单价、单位变动成本和目标销量任意填写三项即可反推第四项，输出平衡销量、边际贡献、边际率、平衡销售额、平衡变动成本和目标差值。',
  ),
  const ToolDefinition(
    id: 'electricity_cost',
    title: '电费计算',
    description: '功率、时间、电价和长期运行成本',
    category: ToolCategory.finance,
    kind: ToolKind.electricityCost,
    group: '生活',
    inputs: [
      ToolInputDefinition(
          key: 'power',
          label: '功率',
          unit: 'W',
          defaultValue: 800,
          optional: true),
      ToolInputDefinition(
          key: 'hours',
          label: '每日使用',
          unit: 'h',
          defaultValue: 3,
          optional: true),
      ToolInputDefinition(
          key: 'days',
          label: '天数',
          unit: '天',
          defaultValue: 30,
          optional: true),
      ToolInputDefinition(
          key: 'price',
          label: '电价',
          unit: '元/kWh',
          defaultValue: 0.6,
          optional: true),
      ToolInputDefinition(
          key: 'targetCost', label: '目标费用', unit: '元', optional: true),
    ],
    formula: 'cost = P(kW) × h × days × price',
    explanation:
        '功率、每日使用、天数、电价和目标费用任意填写四项即可反推缺失项，输出费用、用电量、日均费用、日均用电、月化费用、年化费用和目标差值。',
  ),
  const ToolDefinition(
    id: 'compound',
    title: '复利计算',
    description: '计算终值、收益、收益率和增长倍数',
    category: ToolCategory.finance,
    kind: ToolKind.compound,
    group: '投资',
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'principal',
          label: '本金',
          unit: '元',
          defaultValue: 10000,
          optional: true),
      ToolInputDefinition(
          key: 'rate',
          label: '年化收益',
          unit: '%',
          defaultValue: 5,
          optional: true),
      ToolInputDefinition(
          key: 'years',
          label: '年限',
          unit: '年',
          defaultValue: 10,
          optional: true),
      ToolInputDefinition(
          key: 'target', label: '目标终值', unit: '元', optional: true),
    ],
    formula: 'FV = PV × (1 + r)^n, r = (FV / PV)^(1/n) - 1',
    explanation: '本金、年化收益、年限和目标终值任意填写三项即可反推第四项，输出收益、收益率、增长倍数、年化收益率和目标差值。',
  ),
  const ToolDefinition(
    id: 'profit_margin',
    title: '利润率',
    description: '成本、售价、利润率和盈利状态',
    category: ToolCategory.finance,
    kind: ToolKind.profitMargin,
    group: '商业',
    inputs: [
      ToolInputDefinition(
          key: 'cost',
          label: '成本',
          unit: '元',
          defaultValue: 80,
          optional: true),
      ToolInputDefinition(
          key: 'price',
          label: '售价',
          unit: '元',
          defaultValue: 120,
          optional: true),
      ToolInputDefinition(
          key: 'margin', label: '目标毛利率', unit: '%', optional: true),
      ToolInputDefinition(
          key: 'profit', label: '目标利润', unit: '元', optional: true),
    ],
    formula: '利润 = 售价 - 成本, 毛利率 = 利润 / 售价',
    explanation: '成本、售价、目标毛利率和目标利润填写足够两项即可反推缺失项，输出加价率、成本占比、保本售价、盈利状态和参考差值。',
  ),
  const ToolDefinition(
    id: 'roi',
    title: 'ROI',
    description: '投资回报率、年化回报、回本率和净收益',
    category: ToolCategory.finance,
    kind: ToolKind.roi,
    group: '投资',
    inputs: [
      ToolInputDefinition(
          key: 'gain',
          label: '收益',
          unit: '元',
          defaultValue: 12500,
          optional: true),
      ToolInputDefinition(
          key: 'cost',
          label: '投入',
          unit: '元',
          defaultValue: 10000,
          optional: true),
      ToolInputDefinition(key: 'roi', label: 'ROI', unit: '%', optional: true),
      ToolInputDefinition(
          key: 'years',
          label: '持有年限',
          unit: '年',
          defaultValue: 1,
          optional: true),
    ],
    formula: 'ROI = (收益 - 投入) / 投入, 收益 = 投入 × (1 + ROI)',
    explanation:
        '收益、投入和 ROI 任意填写两项即可反推第三项，输出净收益、回报倍数和回本率；填写持有年限后追加年化 ROI、月均净收益和简单回收期。',
  ),
  const ToolDefinition(
    id: 'discount',
    title: '折扣计算',
    description: '原价、折扣、节省金额与优惠比例',
    category: ToolCategory.finance,
    kind: ToolKind.discount,
    group: '商业',
    inputs: [
      ToolInputDefinition(
          key: 'price',
          label: '原价',
          unit: '元',
          defaultValue: 299,
          optional: true),
      ToolInputDefinition(
          key: 'discount',
          label: '折扣',
          unit: '%',
          defaultValue: 85,
          optional: true),
      ToolInputDefinition(
          key: 'finalPrice', label: '到手价', unit: '元', optional: true),
    ],
    formula: '到手价 = 原价 × 折扣 / 100, 折扣 = 到手价 / 原价 × 100',
    explanation: '原价、折扣和到手价任意填写两项即可反推第三项，同时输出节省金额、优惠比例和每百元支付金额。',
  ),
  const ToolDefinition(
    id: 'tax',
    title: '税前税后',
    description: '税率、税额、含税金额和税负率',
    category: ToolCategory.finance,
    kind: ToolKind.tax,
    group: '商业',
    inputs: [
      ToolInputDefinition(
          key: 'net',
          label: '税前金额',
          unit: '元',
          defaultValue: 1000,
          optional: true),
      ToolInputDefinition(
          key: 'rate',
          label: '税率',
          unit: '%',
          defaultValue: 13,
          optional: true),
      ToolInputDefinition(
          key: 'gross', label: '含税金额', unit: '元', optional: true),
    ],
    formula: '含税金额 = 税前金额 × (1 + 税率), 税率 = 含税金额 / 税前金额 - 1',
    explanation: '税前金额、税率和含税金额任意填写两项即可反推第三项，输出税额、税负率、价税倍率和参考差值。',
  ),
  const ToolDefinition(
    id: 'inflation',
    title: '通胀折算',
    description: '按年通胀率折算未来金额和购买力',
    category: ToolCategory.finance,
    kind: ToolKind.inflation,
    group: '投资',
    inputs: [
      ToolInputDefinition(
          key: 'amount',
          label: '当前金额',
          unit: '元',
          defaultValue: 10000,
          optional: true),
      ToolInputDefinition(
          key: 'rate',
          label: '年通胀率',
          unit: '%',
          defaultValue: 3,
          optional: true),
      ToolInputDefinition(
          key: 'years',
          label: '年数',
          unit: '年',
          defaultValue: 10,
          optional: true),
      ToolInputDefinition(
          key: 'future', label: '未来等值', unit: '元', optional: true),
    ],
    formula: 'FV = PV × (1 + i)^n, i = (FV / PV)^(1/n) - 1',
    explanation: '当前金额、年通胀率、年数和未来等值任意填写三项即可反推第四项，输出购买力折现、累计涨幅、购买力损失和参考差值。',
  ),
  const ToolDefinition(
    id: 'npv',
    title: 'NPV',
    description: '多期现金流净现值、盈利指数和回收期',
    category: ToolCategory.finance,
    kind: ToolKind.npv,
    group: '投资',
    inputs: [
      ToolInputDefinition(
          key: 'initial', label: '初始投入', unit: '元', defaultValue: 10000),
      ToolInputDefinition(
          key: 'rate', label: '折现率', unit: '%', defaultValue: 8),
      ToolInputDefinition(
          key: 'cf1', label: '第1期现金流', unit: '元', defaultValue: 4000),
      ToolInputDefinition(
          key: 'cf2', label: '第2期现金流', unit: '元', defaultValue: 5000),
      ToolInputDefinition(
          key: 'cf3', label: '第3期现金流', unit: '元', defaultValue: 6000),
      ToolInputDefinition(
          key: 'cf4', label: '第4期现金流', unit: '元', optional: true),
      ToolInputDefinition(
          key: 'cf5', label: '第5期现金流', unit: '元', optional: true),
    ],
    formula: 'NPV = Σ CFt/(1+r)^t - 初始投入',
    explanation: '支持最多 5 期现金流，空白可选期会被忽略，输出净现值、折现现金流、盈利指数、回收差额、折现回收期和折现率敏感性。',
  ),
];
