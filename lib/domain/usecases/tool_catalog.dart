import '../entities/tool_category.dart';
import '../entities/tool_definition.dart';

final List<ToolDefinition> toolCatalog = [
  const ToolDefinition(
    id: 'quadratic',
    title: '二次方程',
    description: '求解 ax² + bx + c = 0 的根',
    category: ToolCategory.math,
    kind: ToolKind.quadratic,
    group: '方程',
    featured: true,
    inputs: [
      ToolInputDefinition(key: 'a', label: 'a', unit: '', defaultValue: 1),
      ToolInputDefinition(key: 'b', label: 'b', unit: '', defaultValue: -3),
      ToolInputDefinition(key: 'c', label: 'c', unit: '', defaultValue: 2),
    ],
    formula: 'x = (-b ± sqrt(b² - 4ac)) / 2a',
    explanation: '同时输出判别式、两个根、顶点坐标与对称轴。',
  ),
  const ToolDefinition(
    id: 'linear_system',
    title: '方程组',
    description: '2x2 线性方程组、秩、残差和解类型',
    category: ToolCategory.math,
    kind: ToolKind.linearSystem,
    group: '方程',
    featured: true,
    inputs: [
      ToolInputDefinition(key: 'a1', label: 'a1', unit: '', defaultValue: 2),
      ToolInputDefinition(key: 'b1', label: 'b1', unit: '', defaultValue: 1),
      ToolInputDefinition(key: 'c1', label: 'c1', unit: '', defaultValue: 5),
      ToolInputDefinition(key: 'a2', label: 'a2', unit: '', defaultValue: 1),
      ToolInputDefinition(key: 'b2', label: 'b2', unit: '', defaultValue: -1),
      ToolInputDefinition(key: 'c2', label: 'c2', unit: '', defaultValue: 1),
    ],
    formula: 'D = a1b2 - a2b1, x = Dx / D, y = Dy / D',
    explanation: '使用克莱姆法则求解 2x2 方程组，输出 D、Dx、Dy、矩阵秩、代回残差，并区分唯一解、无解和无穷多解。',
  ),
  const ToolDefinition(
    id: 'percentage',
    title: '百分比',
    description: '百分比计算与变化',
    category: ToolCategory.math,
    kind: ToolKind.percentage,
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'base',
          label: '基准值',
          unit: '',
          defaultValue: 200,
          optional: true),
      ToolInputDefinition(
          key: 'rate',
          label: '百分比',
          unit: '%',
          defaultValue: 15,
          optional: true),
      ToolInputDefinition(
          key: 'value', label: '百分比结果', unit: '', optional: true),
      ToolInputDefinition(
          key: 'newValue',
          label: '新值',
          unit: '',
          defaultValue: 230,
          optional: true),
    ],
    formula: 'value = base × rate / 100, new = base + value',
    explanation: '基准值、百分比、百分比结果和新值任意填写两项即可反推其余量，输出增加后、减少后、变化率、结果占新值和差值。',
  ),
  const ToolDefinition(
    id: 'exponential_log',
    title: '指数对数',
    description: 'x^y、y^x、换底对数、根号和定义域',
    category: ToolCategory.math,
    kind: ToolKind.exponentialLog,
    group: '常用',
    inputs: [
      ToolInputDefinition(key: 'x', label: 'x', unit: '', defaultValue: 2),
      ToolInputDefinition(key: 'y', label: 'y', unit: '', defaultValue: 8),
    ],
    formula: 'x^y, y^x, ln(x), log10(x), log_y(x), x^(1/y)',
    explanation: '常见指数与对数运算集合，输出幂、反向幂、自然/常用/换底对数、平方根、y 次根、倒数和实数域状态。',
  ),
  const ToolDefinition(
    id: 'linear_equation',
    title: '一元一次方程',
    description: '求解 ax + b = 0、退化类型和代回校验',
    category: ToolCategory.math,
    kind: ToolKind.linearEquation,
    group: '方程',
    inputs: [
      ToolInputDefinition(key: 'a', label: 'a', unit: '', defaultValue: 2),
      ToolInputDefinition(key: 'b', label: 'b', unit: '', defaultValue: -6),
    ],
    formula: 'x = -b / a',
    explanation: '用于快速求解一元一次方程，输出斜率、截距、x 截距、代回校验，并区分唯一解、无解和恒等式。',
  ),
  const ToolDefinition(
    id: 'proportion',
    title: '比例计算',
    description: 'a:b = c:x 比例求值',
    category: ToolCategory.math,
    kind: ToolKind.proportion,
    group: '常用',
    inputs: [
      ToolInputDefinition(
          key: 'a', label: 'a', unit: '', defaultValue: 2, optional: true),
      ToolInputDefinition(
          key: 'b', label: 'b', unit: '', defaultValue: 5, optional: true),
      ToolInputDefinition(
          key: 'c', label: 'c', unit: '', defaultValue: 8, optional: true),
      ToolInputDefinition(key: 'x', label: 'x', unit: '', optional: true),
    ],
    formula: 'a:b = c:x, a × x = b × c',
    explanation: 'a、b、c、x 任意填写三项即可反推第四项，并输出比例系数、右侧系数和交叉乘积差。',
  ),
  const ToolDefinition(
    id: 'combination',
    title: '排列组合',
    description: 'A(n,k)、C(n,k)、阶乘、重复排列和比例',
    category: ToolCategory.math,
    kind: ToolKind.combination,
    group: '概率',
    inputs: [
      ToolInputDefinition(key: 'n', label: 'n', unit: '', defaultValue: 10),
      ToolInputDefinition(key: 'k', label: 'k', unit: '', defaultValue: 3),
    ],
    formula: 'C(n,k)=n!/(k!(n-k)!), A(n,k)=n!/(n-k)!, n^k',
    explanation: '输入 n 和 k，输出排列数、组合数、n!/k!/(n-k)!、可重复有序抽取、互补组合和选择比例，并校验非负整数条件。',
  ),
  const ToolDefinition(
    id: 'probability',
    title: '概率计算',
    description: '独立事件概率组合',
    category: ToolCategory.math,
    kind: ToolKind.probability,
    group: '概率',
    inputs: [
      ToolInputDefinition(
          key: 'p1', label: '事件 A 概率', unit: '%', defaultValue: 30),
      ToolInputDefinition(
          key: 'p2', label: '事件 B 概率', unit: '%', defaultValue: 40),
    ],
    formula: 'P(A∩B)=P(A)P(B), P(A∪B)=P(A)+P(B)-P(A)P(B)',
    explanation: '按独立事件估算至少一个、同时发生、仅 A、仅 B、都不发生、至多一个和补集概率。',
  ),
  const ToolDefinition(
    id: 'statistics',
    title: '统计计算',
    description: '多样本均值、中位数、方差和标准差',
    category: ToolCategory.math,
    kind: ToolKind.statistics,
    group: '统计',
    inputs: [
      ToolInputDefinition(key: 'x1', label: 'x1', unit: '', defaultValue: 12),
      ToolInputDefinition(key: 'x2', label: 'x2', unit: '', defaultValue: 18),
      ToolInputDefinition(key: 'x3', label: 'x3', unit: '', defaultValue: 21),
      ToolInputDefinition(key: 'x4', label: 'x4', unit: '', optional: true),
      ToolInputDefinition(key: 'x5', label: 'x5', unit: '', optional: true),
      ToolInputDefinition(key: 'x6', label: 'x6', unit: '', optional: true),
      ToolInputDefinition(key: 'x7', label: 'x7', unit: '', optional: true),
      ToolInputDefinition(key: 'x8', label: 'x8', unit: '', optional: true),
    ],
    formula: 'mean = Σx / n, s = sqrt(Σ(x-mean)²/(n-1))',
    explanation: '支持最多 8 个样本，空白可选样本会被忽略，输出样本数、均值、中位数、总和、极差、总体/样本方差和标准差。',
  ),
  const ToolDefinition(
    id: 'data_fit',
    title: '数据拟合图表',
    description: '粘贴列表数据，生成趋势线、方程和拟合指标',
    category: ToolCategory.math,
    kind: ToolKind.staticOnly,
    group: '统计',
    featured: true,
    inputs: [],
    formula: '线性、二次、指数、幂函数最小二乘拟合',
    explanation: '适合把 Excel 风格的两列数据快速拟合成函数，并查看散点趋势图。',
  ),
  const ToolDefinition(
    id: 'matrix',
    title: '矩阵计算',
    description: '2x2 矩阵行列式、逆矩阵、秩和特征值',
    category: ToolCategory.math,
    kind: ToolKind.matrix,
    group: '矩阵',
    inputs: [
      ToolInputDefinition(key: 'a', label: 'a11', unit: '', defaultValue: 1),
      ToolInputDefinition(key: 'b', label: 'a12', unit: '', defaultValue: 2),
      ToolInputDefinition(key: 'c', label: 'a21', unit: '', defaultValue: 3),
      ToolInputDefinition(key: 'd', label: 'a22', unit: '', defaultValue: 4),
    ],
    formula: 'det(A) = ad - bc, A⁻¹ = 1/det × [[d,-b],[-c,a]]',
    explanation: '输入 2x2 矩阵四个元素，输出行列式、迹、特征判别项、逆矩阵、秩、特征值和常用矩阵范数。',
  ),
  const ToolDefinition(
    id: 'complex',
    title: '复数计算',
    description: '两个复数加减乘除、共轭、模长和幅角',
    category: ToolCategory.math,
    kind: ToolKind.complex,
    group: '矩阵',
    inputs: [
      ToolInputDefinition(key: 'a', label: 'z1 实部', unit: '', defaultValue: 3),
      ToolInputDefinition(key: 'b', label: 'z1 虚部', unit: 'i', defaultValue: 4),
      ToolInputDefinition(key: 'c', label: 'z2 实部', unit: '', defaultValue: 1),
      ToolInputDefinition(
          key: 'd', label: 'z2 虚部', unit: 'i', defaultValue: -2),
    ],
    formula: '(a+bi)(c+di)=(ac-bd)+(ad+bc)i',
    explanation: '输出复数加法、减法、乘法、除法、两个复数的模长、幅角和共轭。',
  ),
  const ToolDefinition(
    id: 'vector',
    title: '向量计算',
    description: '二维向量点积、叉积与夹角',
    category: ToolCategory.math,
    kind: ToolKind.vector,
    group: '矩阵',
    inputs: [
      ToolInputDefinition(key: 'x1', label: 'A.x', unit: '', defaultValue: 3),
      ToolInputDefinition(key: 'y1', label: 'A.y', unit: '', defaultValue: 4),
      ToolInputDefinition(key: 'x2', label: 'B.x', unit: '', defaultValue: 5),
      ToolInputDefinition(key: 'y2', label: 'B.y', unit: '', defaultValue: 2),
    ],
    formula: 'dot = AxBx + AyBy, cross = AxBy - AyBx',
    explanation: '用于几何、力学和图形计算中的二维向量分析，输出点积、叉积、夹角、距离、投影、方向角和平行/垂直关系。',
  ),
  const ToolDefinition(
    id: 'triangle',
    title: '三角形计算',
    description: '三边求面积、周长和角度',
    category: ToolCategory.math,
    kind: ToolKind.triangle,
    group: '几何',
    inputs: [
      ToolInputDefinition(key: 'a', label: '边 a', unit: '', defaultValue: 3),
      ToolInputDefinition(key: 'b', label: '边 b', unit: '', defaultValue: 4),
      ToolInputDefinition(key: 'c', label: '边 c', unit: '', defaultValue: 5),
    ],
    formula: 'S = √(s(s-a)(s-b)(s-c))',
    explanation: '使用海伦公式，输出面积、周长、角度、边长类型、三条高、内切圆半径和外接圆半径。',
  ),
  const ToolDefinition(
    id: 'circle',
    title: '圆形计算',
    description: '半径求面积、周长和直径',
    category: ToolCategory.math,
    kind: ToolKind.circle,
    group: '几何',
    inputs: [
      ToolInputDefinition(
          key: 'r', label: '半径', unit: '', defaultValue: 5, optional: true),
      ToolInputDefinition(
          key: 'diameter', label: '直径', unit: '', optional: true),
      ToolInputDefinition(
          key: 'circumference', label: '周长', unit: '', optional: true),
      ToolInputDefinition(key: 'area', label: '面积', unit: '', optional: true),
    ],
    formula: 'A=πr², C=2πr, d=2r',
    explanation: '半径、直径、周长或面积任填一项即可换算其余圆形量，多个输入会作为参考并输出差值。',
  ),
  const ToolDefinition(
    id: 'scale_ratio',
    title: '比例缩放',
    description: '按比例缩放长度和面积',
    category: ToolCategory.math,
    kind: ToolKind.scaleRatio,
    group: '常用',
    inputs: [
      ToolInputDefinition(
          key: 'value',
          label: '原始值',
          unit: '',
          defaultValue: 120,
          optional: true),
      ToolInputDefinition(
          key: 'from',
          label: '原比例',
          unit: '',
          defaultValue: 100,
          optional: true),
      ToolInputDefinition(
          key: 'to', label: '目标比例', unit: '', defaultValue: 75, optional: true),
      ToolInputDefinition(
          key: 'scaled', label: '缩放后', unit: '', optional: true),
    ],
    formula: 'scaled = value × target / source',
    explanation: '原始值、原比例、目标比例和缩放后任意填写三项即可反推第四项，输出线性、面积和体积缩放比例。',
  ),
  const ToolDefinition(
    id: 'ohms_law',
    title: '欧姆定律',
    description: 'V/I/R/P、电导、公差和功率档位',
    category: ToolCategory.electronics,
    kind: ToolKind.ohmsLaw,
    group: '基础',
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'voltage', label: '电压 V', unit: 'V', optional: true),
      ToolInputDefinition(
          key: 'current',
          label: '电流 I',
          unit: 'A',
          defaultValue: 0.02,
          optional: true),
      ToolInputDefinition(
          key: 'resistance',
          label: '电阻 R',
          unit: 'Ω',
          defaultValue: 220,
          optional: true),
      ToolInputDefinition(
          key: 'power', label: '功率 P', unit: 'W', optional: true),
      ToolInputDefinition(
          key: 'tol',
          label: '电阻公差',
          unit: '%',
          defaultValue: 5,
          optional: true),
    ],
    formula: 'V = I × R, P = V × I = I²R = V²/R',
    explanation: '电压、电流、电阻和功率任意填写两项即可反推其它量；默认按电流+电阻计算，并输出电导、公差范围和推荐电阻功率档位。',
  ),
  const ToolDefinition(
    id: 'voltage_divider',
    title: '电阻分压',
    description: 'Vin, R1, R2 → Vout，并估算负载、电流和功耗',
    category: ToolCategory.electronics,
    kind: ToolKind.voltageDivider,
    group: '基础',
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'vin', label: '输入电压 Vin', unit: 'V', defaultValue: 12),
      ToolInputDefinition(
          key: 'r1', label: '上拉电阻 R1', unit: 'kΩ', defaultValue: 10),
      ToolInputDefinition(
          key: 'r2', label: '下拉电阻 R2', unit: 'kΩ', defaultValue: 20),
      ToolInputDefinition(
          key: 'load',
          label: '负载电阻 RL',
          unit: 'kΩ',
          defaultValue: 100,
          optional: true),
      ToolInputDefinition(
          key: 'tol',
          label: '电阻公差',
          unit: '%',
          defaultValue: 1,
          optional: true),
      ToolInputDefinition(
          key: 'targetVout', label: '目标输出', unit: 'V', optional: true),
    ],
    formula: 'Vout = Vin × (R2 || RL) / (R1 + (R2 || RL))',
    explanation:
        '负载为空时按理想分压计算；填写负载后会计入并联影响、负载电流和功耗。填写目标输出后可反推保留 R1 或保留 R2 时所需的另一只电阻。',
  ),
  const ToolDefinition(
    id: 'rc_filter',
    title: 'RC滤波',
    description: '高通 / 低通截止频率、时间常数和频带参考',
    category: ToolCategory.electronics,
    kind: ToolKind.rcFilter,
    group: '信号',
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'r', label: '电阻 R', unit: 'kΩ', defaultValue: 10),
      ToolInputDefinition(
          key: 'c', label: '电容 C', unit: 'nF', defaultValue: 100),
      ToolInputDefinition(
          key: 'tol',
          label: '元件公差',
          unit: '%',
          defaultValue: 5,
          optional: true),
      ToolInputDefinition(
          key: 'targetFc', label: '目标截止频率', unit: 'Hz', optional: true),
    ],
    formula: 'fc = 1 / (2πRC)',
    explanation:
        '计算 RC 滤波器截止频率、时间常数、容差范围和常用频带参考点；填写目标截止频率后可反推保留 R 或保留 C 时所需的元件值。',
  ),
  const ToolDefinition(
    id: 'dbm',
    title: 'dBm换算',
    description: 'dBm、功率、50Ω 电压和分贝电压换算',
    category: ToolCategory.electronics,
    kind: ToolKind.dbm,
    group: '信号',
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'dbm', label: '功率', unit: 'dBm', defaultValue: 10)
    ],
    formula: 'mW = 10^(dBm / 10)',
    explanation: '射频功率常用单位换算，并给出 50Ω 正弦匹配系统下的 Vrms、Vpeak、Vpp、dBV 和 dBu。',
  ),
  const ToolDefinition(
    id: 'resistor_network',
    title: '电阻串并联',
    description: '两个电阻串联 / 并联等效与电导',
    category: ToolCategory.electronics,
    kind: ToolKind.resistorNetwork,
    group: '基础',
    inputs: [
      ToolInputDefinition(
          key: 'r1', label: 'R1', unit: 'Ω', defaultValue: 1000),
      ToolInputDefinition(
          key: 'r2', label: 'R2', unit: 'Ω', defaultValue: 2200),
      ToolInputDefinition(
          key: 'targetSeries', label: '目标串联等效', unit: 'Ω', optional: true),
      ToolInputDefinition(
          key: 'targetParallel', label: '目标并联等效', unit: 'Ω', optional: true),
      ToolInputDefinition(
          key: 'tol',
          label: '电阻公差',
          unit: '%',
          defaultValue: 5,
          optional: true),
    ],
    formula: 'Rs = R1 + R2, Rp = R1R2/(R1+R2)',
    explanation: '输出串联和并联等效电阻、总电导、元件比值和公差范围；填写目标等效值后可在保留 R1 时反推所需 R2。',
  ),
  const ToolDefinition(
    id: 'capacitor_network',
    title: '电容串并联',
    description: '两个电容串联 / 并联等效',
    category: ToolCategory.electronics,
    kind: ToolKind.capacitorNetwork,
    group: '基础',
    inputs: [
      ToolInputDefinition(
          key: 'c1', label: 'C1', unit: 'nF', defaultValue: 100),
      ToolInputDefinition(
          key: 'c2', label: 'C2', unit: 'nF', defaultValue: 220),
      ToolInputDefinition(
          key: 'targetParallel', label: '目标并联等效', unit: 'nF', optional: true),
      ToolInputDefinition(
          key: 'targetSeries', label: '目标串联等效', unit: 'nF', optional: true),
      ToolInputDefinition(
          key: 'tol',
          label: '电容公差',
          unit: '%',
          defaultValue: 10,
          optional: true),
    ],
    formula: 'Cp = C1 + C2, Cs = C1C2/(C1+C2)',
    explanation: '输出并联和串联等效电容、元件比值和公差范围；填写目标等效值后可在保留 C1 时反推所需 C2。',
  ),
  const ToolDefinition(
    id: 'inductor_network',
    title: '电感串并联',
    description: '两个电感串联 / 并联等效',
    category: ToolCategory.electronics,
    kind: ToolKind.inductorNetwork,
    group: '基础',
    inputs: [
      ToolInputDefinition(key: 'l1', label: 'L1', unit: 'mH', defaultValue: 10),
      ToolInputDefinition(key: 'l2', label: 'L2', unit: 'mH', defaultValue: 22),
      ToolInputDefinition(
          key: 'targetSeries', label: '目标串联等效', unit: 'mH', optional: true),
      ToolInputDefinition(
          key: 'targetParallel', label: '目标并联等效', unit: 'mH', optional: true),
      ToolInputDefinition(
          key: 'tol',
          label: '电感公差',
          unit: '%',
          defaultValue: 10,
          optional: true),
    ],
    formula: 'Ls = L1 + L2, Lp = L1L2/(L1+L2)',
    explanation: '忽略互感影响，输出串联和并联等效电感、元件比值和公差范围；填写目标等效值后可在保留 L1 时反推所需 L2。',
  ),
  const ToolDefinition(
    id: 'led_resistor',
    title: 'LED限流电阻',
    description: '按电源、电压降和电流计算限流电阻',
    category: ToolCategory.electronics,
    kind: ToolKind.ledResistor,
    group: '基础',
    inputs: [
      ToolInputDefinition(
          key: 'vin', label: '电源电压', unit: 'V', defaultValue: 5),
      ToolInputDefinition(
          key: 'vf', label: 'LED压降', unit: 'V', defaultValue: 2),
      ToolInputDefinition(
          key: 'current', label: '目标电流', unit: 'mA', defaultValue: 10),
      ToolInputDefinition(
          key: 'vfTol',
          label: '压降误差',
          unit: 'V',
          defaultValue: 0.1,
          optional: true),
      ToolInputDefinition(
          key: 'selectedResistance', label: '选用电阻', unit: 'Ω', optional: true),
    ],
    formula: 'R = (Vin - Vf) / I',
    explanation: '同时估算电阻功耗；填写实际选用电阻后会校核实际电流、电流偏差、功耗和压降误差范围。',
  ),
  const ToolDefinition(
    id: 'op_amp_gain',
    title: '运放增益',
    description: '同相/反相增益、dB 和反馈网络估算',
    category: ToolCategory.electronics,
    kind: ToolKind.opAmpGain,
    group: '信号',
    inputs: [
      ToolInputDefinition(
          key: 'rin', label: '输入电阻 Rin', unit: 'kΩ', defaultValue: 10),
      ToolInputDefinition(
          key: 'rf', label: '反馈电阻 Rf', unit: 'kΩ', defaultValue: 100),
      ToolInputDefinition(
          key: 'vin', label: '输入电压', unit: 'V', defaultValue: 0.2),
      ToolInputDefinition(
          key: 'targetGain', label: '目标同相增益', unit: '倍', optional: true),
      ToolInputDefinition(
          key: 'gbw', label: '增益带宽积', unit: 'Hz', optional: true),
      ToolInputDefinition(
          key: 'outputSwing', label: '输出峰值幅度', unit: 'V', optional: true),
      ToolInputDefinition(
          key: 'fullPowerFrequency',
          label: '满功率频率',
          unit: 'Hz',
          optional: true),
    ],
    formula: 'Av_non = 1 + Rf/Rin, Av_inv = -Rf/Rin',
    explanation:
        '输出同相与反相放大器增益、dB、输出电压、反馈系数和反馈网络阻值；填写目标增益、GBW 或满功率频率后估算所需反馈电阻、闭环带宽和压摆率。',
  ),
  const ToolDefinition(
    id: 'adc_resolution',
    title: 'ADC分辨率',
    description: 'ADC LSB、码值和动态范围估算',
    category: ToolCategory.electronics,
    kind: ToolKind.adcResolution,
    group: '采样',
    inputs: [
      ToolInputDefinition(
          key: 'vref', label: '参考电压', unit: 'V', defaultValue: 3.3),
      ToolInputDefinition(
          key: 'bits', label: '位数', unit: 'bit', defaultValue: 12),
      ToolInputDefinition(key: 'vin', label: '输入电压', unit: 'V', optional: true),
      ToolInputDefinition(
          key: 'enob', label: '有效位数 ENOB', unit: 'bit', optional: true),
    ],
    formula: 'LSB = Vref / (2^N - 1)',
    explanation:
        '输出 LSB、半 LSB 量化误差、最大码值、满量程和理论动态范围；填写输入电压或 ENOB 后估算码值、重构电压、量化误差和有效动态范围。',
  ),
  const ToolDefinition(
    id: 'rms_peak',
    title: 'Vrms/Vpp换算',
    description: '正弦波 RMS、峰值、峰峰值、dBm 和 50Ω 功率互算',
    category: ToolCategory.electronics,
    kind: ToolKind.rmsPeak,
    group: '信号',
    inputs: [
      ToolInputDefinition(
          key: 'vrms',
          label: 'Vrms',
          unit: 'V',
          defaultValue: 1,
          optional: true),
      ToolInputDefinition(
          key: 'vpeak', label: 'Vpeak', unit: 'V', optional: true),
      ToolInputDefinition(key: 'vpp', label: 'Vpp', unit: 'V', optional: true),
      ToolInputDefinition(
          key: 'dbm50', label: '50Ω dBm', unit: 'dBm', optional: true),
    ],
    formula: 'Vpeak = Vrms × √2, Vpp = 2 × Vpeak, P50 = Vrms²/50',
    explanation:
        'Vrms、Vpeak、Vpp 或 50Ω dBm 任填一项即可反推其它正弦波量，输出平均整流值、dBV、dBu、50Ω 功率、dBm 和参考差值。',
  ),
  const ToolDefinition(
    id: 'lc_resonance',
    title: 'LC谐振',
    description: '电感电容谐振频率、周期和谐振电抗',
    category: ToolCategory.electronics,
    kind: ToolKind.lcResonance,
    group: '信号',
    inputs: [
      ToolInputDefinition(
          key: 'l', label: '电感 L', unit: 'μH', defaultValue: 10),
      ToolInputDefinition(
          key: 'c', label: '电容 C', unit: 'nF', defaultValue: 100),
      ToolInputDefinition(
          key: 'esr', label: '串联 ESR', unit: 'Ω', optional: true),
    ],
    formula: 'f0 = 1 / (2π√LC)',
    explanation:
        '用于 LC/RLC 电路的基础谐振频率估算，输出角频率、周期、谐振点电抗；填写 ESR 后追加串联 Q 值、3dB 带宽和半功率点。',
  ),
  const ToolDefinition(
    id: 'dcdc_feedback',
    title: 'DCDC反馈',
    description: '反馈分压、目标输出反推和反馈电流预算',
    category: ToolCategory.electronics,
    kind: ToolKind.dcdcFeedback,
    group: '电源',
    inputs: [
      ToolInputDefinition(
          key: 'vref', label: '参考电压', unit: 'V', defaultValue: 0.8),
      ToolInputDefinition(
          key: 'rtop', label: '上拉电阻', unit: 'kΩ', defaultValue: 100),
      ToolInputDefinition(
          key: 'rbottom', label: '下拉电阻', unit: 'kΩ', defaultValue: 20),
      ToolInputDefinition(
          key: 'targetVout', label: '目标输出', unit: 'V', optional: true),
      ToolInputDefinition(
          key: 'targetCurrent', label: '目标反馈电流', unit: 'mA', optional: true),
    ],
    formula:
        'Vout = Vref × (1 + Rtop / Rbottom), Ictrl = Vout / (Rtop + Rbottom)',
    explanation: '适用于常见 Buck/Boost 芯片反馈分压估算，并输出反馈电流、电阻功耗、目标输出电压偏差和目标反馈电流所需电阻。',
  ),
  const ToolDefinition(
    id: 'ldo_power',
    title: 'LDO功耗',
    description: '线性稳压器压差、静态电流、热余量和电流限制',
    category: ToolCategory.electronics,
    kind: ToolKind.ldoPower,
    group: '电源',
    inputs: [
      ToolInputDefinition(
          key: 'vin', label: '输入电压', unit: 'V', defaultValue: 5),
      ToolInputDefinition(
          key: 'vout', label: '输出电压', unit: 'V', defaultValue: 3.3),
      ToolInputDefinition(
          key: 'current', label: '负载电流', unit: 'mA', defaultValue: 200),
      ToolInputDefinition(
          key: 'iq',
          label: '静态电流',
          unit: 'mA',
          defaultValue: 0,
          optional: true),
      ToolInputDefinition(
          key: 'dropout',
          label: '最小压差',
          unit: 'V',
          defaultValue: 0.3,
          optional: true),
      ToolInputDefinition(
          key: 'theta', label: '热阻 θJA', unit: '℃/W', defaultValue: 50),
      ToolInputDefinition(
          key: 'ambient', label: '环境温度', unit: '℃', defaultValue: 25),
      ToolInputDefinition(
          key: 'maxJunction', label: '最高结温', unit: '℃', defaultValue: 125),
    ],
    formula: 'Pd = max(0, Vin - Vout) × Iload + Vin × Iq, Tj = Ta + Pd × θJA',
    explanation: '用于 LDO 压差余量、静态电流损耗、效率、结温、热余量、最高环境温度、热阻上限和热限电流估算。',
  ),
  const ToolDefinition(
    id: 'capacitor_charge',
    title: '电容充放电',
    description: 'RC 充放电、电流、储能和目标时间反推',
    category: ToolCategory.electronics,
    kind: ToolKind.capacitorCharge,
    group: '信号',
    inputs: [
      ToolInputDefinition(
          key: 'vin', label: '电源电压', unit: 'V', defaultValue: 5),
      ToolInputDefinition(
          key: 'initialVoltage',
          label: '初始电压',
          unit: 'V',
          defaultValue: 0,
          optional: true),
      ToolInputDefinition(key: 'r', label: '电阻', unit: 'kΩ', defaultValue: 10),
      ToolInputDefinition(key: 'c', label: '电容', unit: 'μF', defaultValue: 100),
      ToolInputDefinition(key: 'time', label: '时间', unit: 's', defaultValue: 1),
      ToolInputDefinition(
          key: 'targetVoltage', label: '目标电压', unit: 'V', optional: true),
      ToolInputDefinition(
          key: 'targetRatio', label: '目标充电比例', unit: '%', optional: true),
    ],
    formula: 'Vc = Vin + (V0 - Vin) × e^(-t/RC)',
    explanation: '输出指定时间的充放电电压、充电比例、电流、电荷、储能和常用时间节点，并可按目标电压或目标充电比例反推所需时间。',
  ),
  const ToolDefinition(
    id: 'battery_life',
    title: '电池续航',
    description: '电池续航、目标容量、电流预算和放电倍率估算',
    category: ToolCategory.electronics,
    kind: ToolKind.batteryLife,
    group: '电源',
    inputs: [
      ToolInputDefinition(
          key: 'capacity', label: '容量', unit: 'mAh', defaultValue: 3000),
      ToolInputDefinition(
          key: 'current', label: '平均电流', unit: 'mA', defaultValue: 120),
      ToolInputDefinition(
          key: 'voltage', label: '标称电压', unit: 'V', defaultValue: 3.7),
      ToolInputDefinition(
          key: 'efficiency', label: '效率', unit: '%', defaultValue: 90),
      ToolInputDefinition(
          key: 'targetHours', label: '目标续航', unit: 'h', optional: true),
      ToolInputDefinition(
          key: 'reserve', label: '保留余量', unit: '%', defaultValue: 20),
    ],
    formula: 'time = capacity / current × η × (1-reserve)',
    explanation: '按容量、平均电流、标称电压、效率和保留余量估算续航，并反推目标续航所需容量与允许平均电流。',
  ),
  const ToolDefinition(
    id: 'pcb_current',
    title: 'PCB走线电流',
    description: '按线宽、铜厚、温升和目标电流估算载流与线宽预算',
    category: ToolCategory.electronics,
    kind: ToolKind.pcbCurrent,
    group: '电源',
    inputs: [
      ToolInputDefinition(
          key: 'width', label: '线宽', unit: 'mm', defaultValue: 1),
      ToolInputDefinition(
          key: 'copper', label: '铜厚', unit: 'oz', defaultValue: 1),
      ToolInputDefinition(
          key: 'rise', label: '允许温升', unit: '℃', defaultValue: 10),
      ToolInputDefinition(
          key: 'targetCurrent', label: '目标电流', unit: 'A', optional: true),
      ToolInputDefinition(
          key: 'layerFactor', label: '层位置系数', unit: 'x', defaultValue: 1),
    ],
    formula: 'I ≈ k × layer × area^0.725 × ΔT^0.44',
    explanation: '外层铜箔 IPC-2221 近似估算，可用层位置系数做内层降额，并反推目标电流所需线宽和余量。',
  ),
  const ToolDefinition(
    id: 'wire_voltage_drop',
    title: '电线压降',
    description: '线长、电流、线径和目标压降估算线损与线径预算',
    category: ToolCategory.electronics,
    kind: ToolKind.wireVoltageDrop,
    group: '电源',
    inputs: [
      ToolInputDefinition(
          key: 'current', label: '电流', unit: 'A', defaultValue: 5),
      ToolInputDefinition(
          key: 'length', label: '单程长度', unit: 'm', defaultValue: 3),
      ToolInputDefinition(
          key: 'area', label: '线芯截面积', unit: 'mm²', defaultValue: 1.5),
      ToolInputDefinition(
          key: 'voltage', label: '系统电压', unit: 'V', defaultValue: 12),
      ToolInputDefinition(
          key: 'dropLimit', label: '目标压降', unit: '%', defaultValue: 3),
      ToolInputDefinition(
          key: 'resistivity',
          label: '电阻率',
          unit: 'Ω·mm²/m',
          defaultValue: 0.0175),
      ToolInputDefinition(
          key: 'parallel', label: '并联根数', unit: '根', defaultValue: 1),
    ],
    formula: 'R = ρ × 2L / (A × n), Vdrop = I × R',
    explanation: '按导线电阻率、往返回路、并联根数和目标压降估算压降、线损、负载端电压、所需截面积和允许电流。',
  ),
  const ToolDefinition(
    id: 'timer_555',
    title: '555定时器',
    description: '无稳态频率、占空比和目标阻值反推',
    category: ToolCategory.electronics,
    kind: ToolKind.timer555,
    group: '信号',
    inputs: [
      ToolInputDefinition(key: 'ra', label: 'RA', unit: 'kΩ', defaultValue: 10),
      ToolInputDefinition(key: 'rb', label: 'RB', unit: 'kΩ', defaultValue: 47),
      ToolInputDefinition(key: 'c', label: 'C', unit: 'μF', defaultValue: 0.1),
      ToolInputDefinition(
          key: 'targetFrequency', label: '目标频率', unit: 'Hz', optional: true),
      ToolInputDefinition(
          key: 'targetDuty', label: '目标占空比', unit: '%', optional: true),
    ],
    formula: 'f = 1.44 / ((RA + 2RB)C), D = (RA + RB) / (RA + 2RB)',
    explanation: '555 无稳态振荡器常用估算，输出周期、高低电平时间和占空比，并可按目标频率/占空比在当前电容下反推 RA/RB。',
  ),
  const ToolDefinition(
    id: 'thermal_rise',
    title: '热阻温升',
    description: '功耗、热阻、结温、降额和目标余量预算',
    category: ToolCategory.electronics,
    kind: ToolKind.thermalRise,
    group: '电源',
    inputs: [
      ToolInputDefinition(
          key: 'power', label: '功耗', unit: 'W', defaultValue: 1.2),
      ToolInputDefinition(
          key: 'theta', label: '热阻', unit: '℃/W', defaultValue: 45),
      ToolInputDefinition(
          key: 'ambient', label: '环境温度', unit: '℃', defaultValue: 25),
      ToolInputDefinition(
          key: 'maxJunction', label: '最高结温', unit: '℃', defaultValue: 125),
      ToolInputDefinition(
          key: 'derating', label: '降额比例', unit: '%', defaultValue: 70),
      ToolInputDefinition(
          key: 'targetJunction', label: '目标结温', unit: '℃', optional: true),
      ToolInputDefinition(
          key: 'targetMargin', label: '目标热余量', unit: '℃', optional: true),
    ],
    formula: 'ΔT = P × θ, Tj = Ta + ΔT, margin = Tmax - Tj, Pderate = Pmax × k',
    explanation: '用于器件结温、温升、热余量、允许功耗、可配置降额功耗、最大环境温度、目标结温和目标热余量反推。',
  ),
  const ToolDefinition(
    id: 'gear_ratio',
    title: '齿轮比',
    description: '齿轮传动比、转速、扭矩和功率损耗',
    category: ToolCategory.mechanical,
    kind: ToolKind.gearRatio,
    group: '传动',
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'z1', label: '驱动齿数 Z1', unit: '齿', defaultValue: 20),
      ToolInputDefinition(
          key: 'z2', label: '从动齿数 Z2', unit: '齿', defaultValue: 50),
      ToolInputDefinition(
          key: 'rpm', label: '输入转速', unit: 'rpm', defaultValue: 1500),
      ToolInputDefinition(
          key: 'torque', label: '输入扭矩', unit: 'N·m', defaultValue: 20),
      ToolInputDefinition(
          key: 'efficiency',
          label: '效率',
          unit: '%',
          defaultValue: 95,
          optional: true),
      ToolInputDefinition(
          key: 'targetOutputRpm', label: '目标输出转速', unit: 'rpm', optional: true),
    ],
    formula: 'i = Z2 / Z1, n2 = n1 / i, T2 = T1 × i × η',
    explanation:
        '外啮合单级齿轮旋转方向相反，并估算输出转速、输出扭矩、输入/输出功率和效率损耗；填写目标输出转速后可反推目标传动比和保留其中一侧齿数时的另一侧齿数。',
  ),
  const ToolDefinition(
    id: 'torque_power',
    title: '扭矩功率换算',
    description: '扭矩、转速、功率、马力和功率方向',
    category: ToolCategory.mechanical,
    kind: ToolKind.torquePower,
    group: '传动',
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'torque', label: '扭矩', unit: 'N·m', defaultValue: 10),
      ToolInputDefinition(
          key: 'rpm', label: '转速', unit: 'rpm', defaultValue: 3000),
      ToolInputDefinition(
          key: 'targetPower', label: '目标功率', unit: 'kW', optional: true),
    ],
    formula: 'P(kW) = T × n / 9550',
    explanation:
        '机械传动中常用的功率、转速、扭矩关系，并输出角速度、马力、功率方向和 1kW 所需扭矩；填写目标功率后可反推所需扭矩或转速。',
  ),
  const ToolDefinition(
    id: 'spring',
    title: '弹簧刚度',
    description: '胡克定律、储能、柔度和等效重量',
    category: ToolCategory.mechanical,
    kind: ToolKind.spring,
    group: '结构',
    inputs: [
      ToolInputDefinition(
          key: 'k', label: '刚度 k', unit: 'N/mm', defaultValue: 12),
      ToolInputDefinition(
          key: 'x', label: '压缩量 x', unit: 'mm', defaultValue: 8),
      ToolInputDefinition(
          key: 'targetForce', label: '目标弹簧力', unit: 'N', optional: true),
      ToolInputDefinition(
          key: 'targetEnergy', label: '目标储能', unit: 'J', optional: true),
    ],
    formula: 'F = kx, E = 1/2kx²',
    explanation: '用于线性弹簧的载荷、储能、柔度、等效重量和变形方向估算；填写目标力或目标储能后可反推所需变形量。',
  ),
  const ToolDefinition(
    id: 'cylinder',
    title: '气缸推力',
    description: '气压、缸径、杆径和往返推力',
    category: ToolCategory.mechanical,
    kind: ToolKind.cylinder,
    group: '流体',
    inputs: [
      ToolInputDefinition(
          key: 'pressure', label: '气压', unit: 'MPa', defaultValue: 0.6),
      ToolInputDefinition(
          key: 'bore', label: '缸径', unit: 'mm', defaultValue: 32),
      ToolInputDefinition(
          key: 'rod',
          label: '杆径',
          unit: 'mm',
          defaultValue: 12,
          optional: true),
      ToolInputDefinition(
          key: 'targetForce', label: '目标推出力', unit: 'N', optional: true),
    ],
    formula: 'F = P × A',
    explanation: '输出推出力、拉回力、等效重量、活塞面积、杆侧有效面积和拉力比例；填写目标推出力后可反推所需气压或缸径。',
  ),
  const ToolDefinition(
    id: 'force',
    title: '力/质量/加速度',
    description: '牛顿第二定律、g 值和方向判断',
    category: ToolCategory.mechanical,
    kind: ToolKind.force,
    group: '基础',
    inputs: [
      ToolInputDefinition(
          key: 'mass', label: '质量', unit: 'kg', defaultValue: 5),
      ToolInputDefinition(
          key: 'acc', label: '加速度', unit: 'm/s²', defaultValue: 9.8),
      ToolInputDefinition(
          key: 'targetForce', label: '目标力', unit: 'N', optional: true),
    ],
    formula: 'F = m × a',
    explanation: '输出惯性力、力幅值、等效重量、g 值、质量重量和加速度方向；填写目标力后可反推所需加速度或质量。',
  ),
  const ToolDefinition(
    id: 'pulley_ratio',
    title: '皮带轮转速比',
    description: '直径比、转速、角速度和皮带线速度',
    category: ToolCategory.mechanical,
    kind: ToolKind.pulleyRatio,
    group: '传动',
    inputs: [
      ToolInputDefinition(
          key: 'd1', label: '主动轮直径', unit: 'mm', defaultValue: 40),
      ToolInputDefinition(
          key: 'd2', label: '从动轮直径', unit: 'mm', defaultValue: 80),
      ToolInputDefinition(
          key: 'rpm', label: '输入转速', unit: 'rpm', defaultValue: 1500),
      ToolInputDefinition(
          key: 'targetOutputRpm', label: '目标输出转速', unit: 'rpm', optional: true),
    ],
    formula: 'n2 = n1 × D1 / D2',
    explanation: '忽略打滑时估算输出转速、速度比、传动比、角速度、皮带线速度和开口皮带转向；填写目标输出转速后可反推轮径。',
  ),
  const ToolDefinition(
    id: 'screw_lead',
    title: '丝杆导程',
    description: '导程、转速、进给速度和行程换算',
    category: ToolCategory.mechanical,
    kind: ToolKind.screwLead,
    group: '传动',
    inputs: [
      ToolInputDefinition(
          key: 'lead', label: '导程', unit: 'mm/rev', defaultValue: 5),
      ToolInputDefinition(
          key: 'rpm', label: '转速', unit: 'rpm', defaultValue: 600),
      ToolInputDefinition(
          key: 'targetSpeed', label: '目标线速度', unit: 'mm/min', optional: true),
    ],
    formula: 'v = lead × rpm',
    explanation: '输出线速度、每秒位移、每转位移、每毫米转数、rps、小时行程和运动方向；填写目标线速度后可反推转速或导程。',
  ),
  const ToolDefinition(
    id: 'pressure_force',
    title: '压力面积力',
    description: '压力、面积、作用力和等效重量',
    category: ToolCategory.mechanical,
    kind: ToolKind.pressureForce,
    group: '流体',
    inputs: [
      ToolInputDefinition(
          key: 'pressure', label: '压力', unit: 'MPa', defaultValue: 0.6),
      ToolInputDefinition(
          key: 'area', label: '面积', unit: 'cm²', defaultValue: 10),
      ToolInputDefinition(
          key: 'targetForce', label: '目标作用力', unit: 'N', optional: true),
    ],
    formula: 'F = P × A',
    explanation: '用于液压、气动和压强估算，输出 N/kN、kgf、bar、面积换算和单位面积载荷；填写目标作用力后可反推所需压力或面积。',
  ),
  const ToolDefinition(
    id: 'friction',
    title: '摩擦力',
    description: '摩擦力、摩擦角和等效坡度',
    category: ToolCategory.mechanical,
    kind: ToolKind.friction,
    group: '受力',
    inputs: [
      ToolInputDefinition(
          key: 'normal', label: '正压力', unit: 'N', defaultValue: 100),
      ToolInputDefinition(
          key: 'mu', label: '摩擦系数', unit: '', defaultValue: 0.3),
    ],
    formula: 'Ff = μN',
    explanation: '输出静/动摩擦力、法向等效重量、摩擦角、最大可平衡坡角和等效坡度。',
  ),
  const ToolDefinition(
    id: 'inclined_plane',
    title: '斜面受力',
    description: '斜面分力、摩擦上限和滑动状态',
    category: ToolCategory.mechanical,
    kind: ToolKind.inclinedPlane,
    group: '受力',
    inputs: [
      ToolInputDefinition(
          key: 'mass', label: '质量', unit: 'kg', defaultValue: 10),
      ToolInputDefinition(
          key: 'angle', label: '角度', unit: 'deg', defaultValue: 30),
      ToolInputDefinition(
          key: 'mu', label: '摩擦系数', unit: '', defaultValue: 0.2),
    ],
    formula: 'F_parallel = mg sinθ, F_friction = μmg cosθ',
    explanation: '输出沿斜面分力、法向力、摩擦上限、净下滑力、坡度、摩擦角和滑动状态。',
  ),
  const ToolDefinition(
    id: 'beam_bending',
    title: '梁弯曲基础',
    description: '简支梁挠度、弯矩、反力和刚度',
    category: ToolCategory.mechanical,
    kind: ToolKind.beamBending,
    group: '结构',
    inputs: [
      ToolInputDefinition(
          key: 'load', label: '集中载荷', unit: 'N', defaultValue: 100),
      ToolInputDefinition(
          key: 'length', label: '跨度', unit: 'm', defaultValue: 1),
      ToolInputDefinition(
          key: 'elastic', label: '弹性模量', unit: 'GPa', defaultValue: 200),
      ToolInputDefinition(
          key: 'inertia', label: '惯性矩', unit: 'cm⁴', defaultValue: 8),
      ToolInputDefinition(
          key: 'targetDeflection', label: '目标挠度', unit: 'mm', optional: true),
    ],
    formula: 'δ = F L³ / (48 E I), Mmax = F L / 4',
    explanation:
        '简支梁中央集中载荷的基础估算，输出挠度、挠度幅值、弯矩、支座反力、等效刚度、跨度挠度比和 EI；填写目标挠度后可估算允许载荷、所需惯性矩或弹性模量。',
  ),
  const ToolDefinition(
    id: 'stress_strain',
    title: '应力应变',
    description: '轴向应力、应变、微应变和变形',
    category: ToolCategory.mechanical,
    kind: ToolKind.stressStrain,
    group: '结构',
    inputs: [
      ToolInputDefinition(
          key: 'force', label: '轴向力', unit: 'N', defaultValue: 1000),
      ToolInputDefinition(
          key: 'area', label: '截面积', unit: 'mm²', defaultValue: 50),
      ToolInputDefinition(
          key: 'elastic', label: '弹性模量', unit: 'GPa', defaultValue: 200),
    ],
    formula: 'σ = F/A, ε = σ/E',
    explanation: '输出工程应力、应力幅值、弹性应变、微应变、每米变形、截面积和拉压载荷类型。',
  ),
  const ToolDefinition(
    id: 'section_area',
    title: '截面属性计算',
    description: '圆、管、矩形面积、惯性矩、截面模量和回转半径',
    category: ToolCategory.mechanical,
    kind: ToolKind.sectionArea,
    group: '结构',
    inputs: [
      ToolInputDefinition(
          key: 'diameter', label: '圆直径', unit: 'mm', defaultValue: 20),
      ToolInputDefinition(
          key: 'outer', label: '管外径', unit: 'mm', defaultValue: 30),
      ToolInputDefinition(
          key: 'inner', label: '管内径', unit: 'mm', defaultValue: 20),
      ToolInputDefinition(
          key: 'width', label: '矩形宽', unit: 'mm', defaultValue: 40),
      ToolInputDefinition(
          key: 'height', label: '矩形高', unit: 'mm', defaultValue: 10),
    ],
    formula: 'A圆=πd²/4, I圆=πd⁴/64, Z=I/c, r=sqrt(I/A)',
    explanation:
        '用于材料重量、应力、梁弯曲和流通截面的基础计算；输出圆/管/矩形面积、惯性矩、截面模量、回转半径、管壁厚、空心率和矩形强弱轴。',
  ),
  const ToolDefinition(
    id: 'safety_factor',
    title: '安全系数',
    description: '许用强度、工作应力、余量和判断',
    category: ToolCategory.mechanical,
    kind: ToolKind.safetyFactor,
    group: '结构',
    inputs: [
      ToolInputDefinition(
          key: 'strength', label: '材料强度', unit: 'MPa', defaultValue: 250),
      ToolInputDefinition(
          key: 'stress', label: '工作应力', unit: 'MPa', defaultValue: 80),
      ToolInputDefinition(
          key: 'targetFactor', label: '目标安全系数', unit: '', optional: true),
    ],
    formula: 'n = strength / stress',
    explanation: '输出安全系数、强度余量、余量比例、工作应力幅值、许用强度和常用设计判断；填写目标安全系数后可反推所需强度或许用应力。',
  ),
  const ToolDefinition(
    id: 'flow_velocity',
    title: '流量管径流速',
    description: '流量、管径、流速和雷诺数',
    category: ToolCategory.mechanical,
    kind: ToolKind.flowVelocity,
    group: '流体',
    inputs: [
      ToolInputDefinition(
          key: 'flow', label: '流量', unit: 'L/min', defaultValue: 30),
      ToolInputDefinition(
          key: 'diameter', label: '管内径', unit: 'mm', defaultValue: 20),
    ],
    formula: 'v = Q / A',
    explanation: '用于水路、气路和液压管径初选，输出平均流速、截面积、m³/h、m³/s、雷诺数和 20℃ 水流态。',
  ),
  const ToolDefinition(
    id: 'material_weight',
    title: '材料重量',
    description: '板材重量、体积、表面积和面密度',
    category: ToolCategory.mechanical,
    kind: ToolKind.materialWeight,
    group: '结构',
    inputs: [
      ToolInputDefinition(
          key: 'length', label: '长度', unit: 'mm', defaultValue: 1000),
      ToolInputDefinition(
          key: 'width', label: '宽度', unit: 'mm', defaultValue: 100),
      ToolInputDefinition(
          key: 'thickness', label: '厚度', unit: 'mm', defaultValue: 10),
      ToolInputDefinition(
          key: 'density', label: '密度', unit: 'g/cm³', defaultValue: 7.85),
    ],
    formula: 'm = LWT × ρ',
    explanation: '适合钢板、铝板、塑料板等矩形材料估重，输出 kg/lb/N、体积、表面积和面密度。',
  ),
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
  _unitTool('length', '长度', 'nm、μm、mm、cm、m、km、Mm、in、ft、mile 换算',
      ToolKind.length, 'm', 3.3),
  _unitTool('area', '面积', 'km²、ha、公顷、亩、m²、cm²、mm²、acre、ft²、in² 换算',
      ToolKind.area, 'm²', 1.2),
  _unitTool('volume', '体积', 'm³、L、mL、cm³、mm³、gal、qt、pt、fl oz、ft³、in³ 换算',
      ToolKind.volume, 'm³', 0.02),
  _unitTool('mass', '质量', 'kg、g、mg、Mg、t、lb、oz、斤 换算', ToolKind.mass, 'kg', 5),
  _unitTool('pressure', '压力', 'mPa、Pa、kPa、MPa、GPa、bar、mbar、psi、atm 换算',
      ToolKind.pressure, 'Pa', 101325),
  _unitTool('speed', '速度', 'm/s、km/h、mph、ft/s、m/min、cm/s、kn 换算', ToolKind.speed,
      'm/s', 10),
  _unitTool('temperature', '温度', '℃、℉、K、°R 换算', ToolKind.temperature, '℃', 25),
  _unitTool('voltage', '电压', 'μV、mV、V、kV、MV 换算', ToolKind.voltage, 'V', 3.3),
  _unitTool('frequency', '频率', 'mHz、Hz、kHz、MHz、GHz、THz 换算', ToolKind.frequency,
      'Hz', 1000),
  _unitTool('data_size', '数据单位', 'bit、B、KB/MB/GB 与 KiB/MiB/GiB 换算',
      ToolKind.dataSize, 'B', 1048576),
  _unitTool('time_unit', '时间', 'ns、μs、ms、s、min、h、day、week 换算',
      ToolKind.timeUnit, 's', 3600),
  _unitTool('acceleration', '加速度', 'm/s²、g、ft/s²、cm/s²、Gal 换算',
      ToolKind.accelerationUnit, 'm/s²', 9.80665),
  _unitTool(
      'force_unit', '力', 'mN、N、kN、MN、kgf、lbf 换算', ToolKind.forceUnit, 'N', 100),
  _unitTool(
      'power_unit', '功率', 'mW、W、kW、MW、hp、dBm 换算', ToolKind.powerUnit, 'W', 750),
  _unitTool('energy_unit', '能量', 'J、kJ、cal、kcal、BTU、eV、Wh、kWh、MWh、度 换算',
      ToolKind.energyUnit, 'J', 3600),
  _unitTool('angle_unit', '角度', 'deg、rad、turn、grad/gon、arcmin、arcsec 换算',
      ToolKind.angleUnit, 'deg', 180),
  _unitTool('current_unit', '电流', 'nA、μA、mA、A、kA、MA 换算', ToolKind.currentUnit,
      'A', 0.02),
  _unitTool('resistance_unit', '电阻', 'μΩ、mΩ、Ω、kΩ、MΩ、GΩ 换算',
      ToolKind.resistanceUnit, 'Ω', 10000),
  _unitTool('capacitance_unit', '电容', 'F、mF、μF、nF、pF、MF 换算',
      ToolKind.capacitanceUnit, 'F', 0.000001),
  _unitTool('inductance_unit', '电感', 'pH、nH、μH、mH、H、kH、MH 换算',
      ToolKind.inductanceUnit, 'H', 0.001),
  _unitTool('torque_unit', '扭矩', 'kN·m、N·m、mN·m、N·mm、kgf·cm、lbf·in、ozf·in 换算',
      ToolKind.torqueUnit, 'N·m', 10),
  _unitTool(
      'flow_unit',
      '流量',
      'mL/min、L/min、L/h、L/s、m³/h、m³/min、m³/s、GPM、CFM 换算',
      ToolKind.flowUnit,
      'L/min',
      60),
  const ToolDefinition(
    id: 'motion',
    title: '速度时间距离',
    description: '速度、时间、距离三选二互算和配速',
    category: ToolCategory.science,
    kind: ToolKind.motion,
    group: '运动',
    inputs: [
      ToolInputDefinition(
          key: 'speed',
          label: '速度',
          unit: 'm/s',
          defaultValue: 12,
          optional: true),
      ToolInputDefinition(
          key: 'time',
          label: '时间',
          unit: 's',
          defaultValue: 30,
          optional: true),
      ToolInputDefinition(
          key: 'distance', label: '距离', unit: 'm', optional: true),
    ],
    formula: 's = v × t, v = s / t, t = s / v',
    explanation: '速度、时间、距离任意填写两项即可反推第三项；输出米/公里、m/s、km/h、时间换算、配速和输入来源。',
  ),
  const ToolDefinition(
    id: 'free_fall',
    title: '自由落体',
    description: '高度、初速度、落地时间、末速度和冲击能量',
    category: ToolCategory.science,
    kind: ToolKind.freeFall,
    group: '运动',
    inputs: [
      ToolInputDefinition(
          key: 'height', label: '高度', unit: 'm', defaultValue: 20),
      ToolInputDefinition(
          key: 'initialSpeed',
          label: '初速度',
          unit: 'm/s',
          defaultValue: 0,
          optional: true),
      ToolInputDefinition(
          key: 'g', label: '重力加速度', unit: 'm/s²', defaultValue: 9.80665),
      ToolInputDefinition(key: 'mass', label: '质量', unit: 'kg', optional: true),
      ToolInputDefinition(
          key: 'bufferDistance', label: '缓冲距离', unit: 'm', optional: true),
    ],
    formula: 'v² = v0² + 2gh, t = (v - v0) / g',
    explanation: '忽略空气阻力时的竖直下落估算，支持向下初速度；填写质量后追加势能变化、末端动能和冲击能量，填写缓冲距离后估算平均冲击力。',
  ),
  const ToolDefinition(
    id: 'work_power',
    title: '功与功率',
    description: '力、位移、夹角、效率、功和平均功率',
    category: ToolCategory.science,
    kind: ToolKind.workPower,
    group: '能量',
    inputs: [
      ToolInputDefinition(
          key: 'force', label: '力', unit: 'N', defaultValue: 100),
      ToolInputDefinition(
          key: 'distance', label: '位移', unit: 'm', defaultValue: 5),
      ToolInputDefinition(
          key: 'time', label: '时间', unit: 's', defaultValue: 10),
      ToolInputDefinition(
          key: 'angle',
          label: '力-位移夹角',
          unit: 'deg',
          defaultValue: 0,
          optional: true),
      ToolInputDefinition(
          key: 'efficiency',
          label: '效率',
          unit: '%',
          defaultValue: 100,
          optional: true),
      ToolInputDefinition(
          key: 'targetPower', label: '目标功率', unit: 'W', optional: true),
    ],
    formula: 'W = F s cosθ, Pout = W / t, Pin = Pout / η',
    explanation:
        '用于机械做功和平均功率快速计算，支持力-位移夹角和效率，输出有效功、输入功率、损耗、Wh/kWh、马力和做功方向；填写目标功率后可反推时间或力。',
  ),
  const ToolDefinition(
    id: 'kinetic_energy',
    title: '动能势能',
    description: '质量、速度、高度、动能和势能',
    category: ToolCategory.science,
    kind: ToolKind.kineticEnergy,
    group: '能量',
    inputs: [
      ToolInputDefinition(
          key: 'mass', label: '质量', unit: 'kg', defaultValue: 2),
      ToolInputDefinition(
          key: 'speed', label: '速度', unit: 'm/s', defaultValue: 5),
      ToolInputDefinition(
          key: 'height', label: '高度', unit: 'm', defaultValue: 3),
      ToolInputDefinition(
          key: 'targetTotalEnergy', label: '目标总能量', unit: 'J', optional: true),
    ],
    formula: 'Ek = 1/2mv², Ep = mgh',
    explanation: '输出动能、势能、总机械能、速度幅值、单位质量动能和等效高度；填写目标总能量后可反推所需速度或高度。',
  ),
  const ToolDefinition(
    id: 'density',
    title: '密度质量体积',
    description: '密度、质量、体积和比容关系',
    category: ToolCategory.science,
    kind: ToolKind.density,
    group: '物性',
    inputs: [
      ToolInputDefinition(
          key: 'mass', label: '质量', unit: 'kg', defaultValue: 7.8),
      ToolInputDefinition(
          key: 'volume', label: '体积', unit: 'm³', defaultValue: 0.001),
      ToolInputDefinition(
          key: 'density', label: '密度', unit: 'kg/m³', optional: true),
    ],
    formula: 'ρ = m / V, m = ρV, V = m / ρ',
    explanation: '质量、体积、密度任意填写两项即可反推第三项，并输出 kg/m³、g/cm³、kg/L、比容和体积换算。',
  ),
  const ToolDefinition(
    id: 'concentration',
    title: '浓度换算',
    description: '质量、体积、质量浓度和摩尔浓度',
    category: ToolCategory.science,
    kind: ToolKind.concentration,
    group: '化学',
    inputs: [
      ToolInputDefinition(
          key: 'mass',
          label: '溶质量',
          unit: 'g',
          defaultValue: 5,
          optional: true),
      ToolInputDefinition(
          key: 'volume',
          label: '溶液体积',
          unit: 'L',
          defaultValue: 0.5,
          optional: true),
      ToolInputDefinition(
          key: 'molarMass',
          label: '摩尔质量',
          unit: 'g/mol',
          defaultValue: 58.44,
          optional: true),
      ToolInputDefinition(
          key: 'massConcentration', label: '质量浓度', unit: 'g/L', optional: true),
      ToolInputDefinition(
          key: 'molarity', label: '摩尔浓度', unit: 'mol/L', optional: true),
    ],
    formula: 'γ = m/V, C = γ/M, m = γV',
    explanation: '支持用溶质量、体积、质量浓度或摩尔浓度互相反推；有摩尔质量时输出 mol/L、物质的量和差值校核。',
  ),
  const ToolDefinition(
    id: 'ideal_gas',
    title: '理想气体',
    description: 'PV=nRT 压力、温度、体积和摩尔体积',
    category: ToolCategory.science,
    kind: ToolKind.idealGas,
    group: '热学',
    inputs: [
      ToolInputDefinition(
          key: 'n',
          label: '物质的量',
          unit: 'mol',
          defaultValue: 1,
          optional: true),
      ToolInputDefinition(
          key: 'temp',
          label: '温度',
          unit: 'K',
          defaultValue: 298.15,
          optional: true),
      ToolInputDefinition(
          key: 'volume',
          label: '体积',
          unit: 'L',
          defaultValue: 24,
          optional: true),
      ToolInputDefinition(
          key: 'pressure', label: '压力', unit: 'kPa', optional: true),
    ],
    formula: 'PV = nRT',
    explanation:
        '压力、体积、物质的量和温度任意填写三项即可反推第四项；使用 R=8.314 J/(mol·K)，体积按 L 输入，压力按 kPa 输入。',
  ),
  const ToolDefinition(
    id: 'heat',
    title: '热量计算',
    description: '质量、比热容、温升和热量单位',
    category: ToolCategory.science,
    kind: ToolKind.heat,
    group: '热学',
    inputs: [
      ToolInputDefinition(
          key: 'mass',
          label: '质量',
          unit: 'kg',
          defaultValue: 1,
          optional: true),
      ToolInputDefinition(
          key: 'specific',
          label: '比热容',
          unit: 'J/kg℃',
          defaultValue: 4186,
          optional: true),
      ToolInputDefinition(
          key: 'delta',
          label: '温度变化',
          unit: '℃',
          defaultValue: 10,
          optional: true),
      ToolInputDefinition(key: 'heat', label: '热量', unit: 'J', optional: true),
    ],
    formula: 'Q = m c ΔT',
    explanation: '质量、比热容、温度变化和热量任意填写三项即可反推第四项，并输出 J、kJ、Wh、kcal 和吸放热状态。',
  ),
  const ToolDefinition(
    id: 'wavelength',
    title: '波长频率',
    description: '波速、频率、波长、周期和角频率',
    category: ToolCategory.science,
    kind: ToolKind.wavelength,
    group: '波动',
    inputs: [
      ToolInputDefinition(
          key: 'speed',
          label: '波速',
          unit: 'm/s',
          defaultValue: 343,
          optional: true),
      ToolInputDefinition(
          key: 'frequency',
          label: '频率',
          unit: 'Hz',
          defaultValue: 1000,
          optional: true),
      ToolInputDefinition(
          key: 'wavelength', label: '波长', unit: 'm', optional: true),
    ],
    formula: 'λ = v / f, v = λf, f = v / λ',
    explanation: '波速、频率和波长任意填写两项即可反推第三项，输出周期、频率单位、波数和角频率。',
  ),
  const ToolDefinition(
    id: 'half_life',
    title: '半衰期',
    description: '按半衰期估算剩余、衰减和衰变常数',
    category: ToolCategory.science,
    kind: ToolKind.halfLife,
    group: '物理',
    inputs: [
      ToolInputDefinition(
          key: 'initial',
          label: '初始量',
          unit: '',
          defaultValue: 100,
          optional: true),
      ToolInputDefinition(
          key: 'half',
          label: '半衰期',
          unit: 'h',
          defaultValue: 6,
          optional: true),
      ToolInputDefinition(
          key: 'time',
          label: '经过时间',
          unit: 'h',
          defaultValue: 18,
          optional: true),
      ToolInputDefinition(
          key: 'remaining', label: '剩余量', unit: '', optional: true),
      ToolInputDefinition(
          key: 'remainingRatio', label: '剩余比例', unit: '%', optional: true),
    ],
    formula: 'N = N0 × 0.5^(t/T)',
    explanation: '支持用初始量、半衰期、经过时间、剩余量或剩余比例反推，输出剩余、衰减、经历半衰期和衰变常数。',
  ),
  const ToolDefinition(
    id: 'ph',
    title: 'pH / pOH',
    description: 'pH、氢离子、氢氧根和酸碱性互算',
    category: ToolCategory.science,
    kind: ToolKind.ph,
    group: '化学',
    inputs: [
      ToolInputDefinition(key: 'ph', label: 'pH', unit: '', optional: true),
      ToolInputDefinition(
          key: 'h', label: '[H+]', unit: 'mol/L', defaultValue: 0.000001),
      ToolInputDefinition(
          key: 'oh', label: '[OH-]', unit: 'mol/L', optional: true),
      ToolInputDefinition(
          key: 'targetPh', label: '目标pH', unit: '', optional: true),
    ],
    formula: 'pH = -log10([H+]), pOH = -log10([OH-])',
    explanation:
        '可从 pH、[H+] 或 [OH-] 任一入口估算，其它字段留空即可；按 25℃ 水的 Kw=1e-14 输出 pH、pOH、[H+]、[OH-] 和酸碱性，填写目标pH后追加目标浓度和偏差。',
  ),
  const ToolDefinition(
    id: 'bmi',
    title: 'BMI',
    description: 'BMI、健康体重区间、腰高比和体表面积',
    category: ToolCategory.science,
    kind: ToolKind.bmi,
    group: '生活',
    inputs: [
      ToolInputDefinition(
          key: 'weight', label: '体重', unit: 'kg', defaultValue: 65),
      ToolInputDefinition(
          key: 'height', label: '身高', unit: 'cm', defaultValue: 170),
      ToolInputDefinition(
          key: 'waist', label: '腰围', unit: 'cm', optional: true),
    ],
    formula: 'BMI = weight / height²',
    explanation: '输出 BMI、常见区间、健康体重范围、目标体重差、腰高比和 Mosteller 体表面积；腰围可留空。',
  ),
  const ToolDefinition(
    id: 'fuel_economy',
    title: '油耗计算',
    description: '油耗、燃油成本、油箱续航和排放粗估',
    category: ToolCategory.science,
    kind: ToolKind.fuelEconomy,
    group: '生活',
    inputs: [
      ToolInputDefinition(
          key: 'distance',
          label: '里程',
          unit: 'km',
          defaultValue: 520,
          optional: true),
      ToolInputDefinition(
          key: 'fuel',
          label: '燃油',
          unit: 'L',
          defaultValue: 38,
          optional: true),
      ToolInputDefinition(
          key: 'consumption', label: '百公里油耗', unit: 'L/100km', optional: true),
      ToolInputDefinition(
          key: 'price', label: '油价', unit: '元/L', defaultValue: 8),
      ToolInputDefinition(
          key: 'tank',
          label: '油箱容量',
          unit: 'L',
          defaultValue: 55,
          optional: true),
      ToolInputDefinition(
          key: 'annualDistance',
          label: '年行驶里程',
          unit: 'km',
          defaultValue: 15000,
          optional: true),
      ToolInputDefinition(
          key: 'co2',
          label: 'CO2系数',
          unit: 'kg/L',
          defaultValue: 2.31,
          optional: true),
    ],
    formula: 'L/100km = fuel / distance × 100, distance = fuel × 100 / L/100km',
    explanation: '里程、燃油和百公里油耗任意填写两项即可反推第三项，输出 km/L、成本、油箱续航、年油费和排放粗估。',
  ),
  _textTool('base_convert', '进制转换', '二进制、八进制、十进制、十六进制转换',
      ToolCategory.programming, '编码', '支持 0x、#、h、0b、b、0o、o 与全角数字输入。'),
  _textTool('timestamp', '时间戳转换', 'Unix 时间戳与日期转换', ToolCategory.programming,
      '时间', '支持秒/毫秒时间戳、小数秒、ISO、本地和中文日期时间。'),
  _textTool('color_convert', 'RGB/HEX颜色', 'RGB、HEX、HSL 颜色转换',
      ToolCategory.programming, '编码', '支持 HEX、RGB/RGBA、HSL/HSLA 和常用 CSS 命名色。'),
  _textTool('base64', 'Base64', 'Base64 编码解码', ToolCategory.programming, '编码',
      '自动识别普通文本、Base64、Base64URL 和 data URL，输出标准/Base64URL/data URL 可复制格式。'),
  _textTool('url_codec', 'URL编码', 'URL 编码与解码', ToolCategory.programming, '编码',
      '自动识别完整 URL、query string 和 URL 组件，输出长度变化、百分号片段和 query 参数数量。'),
  _textTool('json_format', 'JSON格式化', 'JSON 格式化与校验', ToolCategory.programming,
      '数据', '输入 JSON 或 JSON Lines，输出格式化结果和结构摘要。'),
  _textTool(
      'ascii_unicode',
      'ASCII/Unicode',
      '字符码点查询',
      ToolCategory.programming,
      '编码',
      '输出码点、UTF-16、UTF-32、UTF-8、HTML 实体和字符分类，并支持 U+ 与 \\u 反查。'),
  _textTool('bitwise', '位运算', 'AND / OR / XOR / NOT 与移位',
      ToolCategory.programming, '数据', '输入两个整数或 A/B 标签，输出常用位运算结果。'),
  _textTool('checksum', '校验和', '文本字节校验和', ToolCategory.programming, '数据',
      '支持 UTF-8 文本和十六进制字节，输出 SUM8、XOR8、LRC。'),
  _textTool('uuid', 'UUID生成', '生成/校验 UUID', ToolCategory.programming, '编码',
      '留空生成随机 UUID v4，粘贴 UUID 可标准化并识别版本与 variant。'),
  _textTool(
      'jwt_decode',
      'JWT解析',
      '解析 JWT Header / Payload',
      ToolCategory.programming,
      '数据',
      '离线解码 Header/Payload，校核 claims 时间但不验证签名。'),
  _textTool('query_params', 'Query参数', 'URL 查询参数解析', ToolCategory.programming,
      '数据', '解析 URL 或 query string，输出键值表和 JSON。'),
  _textTool('html_entities', 'HTML实体', 'HTML 实体编码解码', ToolCategory.programming,
      '编码', '支持常见命名实体、十进制和十六进制数字实体。'),
  _textTool('regex_test', '正则测试', '正则匹配预览', ToolCategory.programming, '数据',
      '第一行输入正则，后续输入测试文本，输出匹配位置。'),
  _textTool('text_stats', '文本统计', '字符、词、行和字节统计', ToolCategory.programming, '数据',
      '统计字符、段落、UTF-8 字节和中英文/数字/标点分布。'),
  _textTool('csv_json', 'CSV转JSON', 'CSV / TSV 转 JSON',
      ToolCategory.programming, '数据', '支持逗号、Tab、分号和竖线分隔，首行作为表头。'),
  _textTool('fnv_crc', 'FNV/CRC32', 'FNV-1a 与 CRC32 哈希',
      ToolCategory.programming, '编码', '支持 UTF-8 文本和十六进制字节的 FNV-1a/CRC32。'),
  _textTool('custom_formula', '自定义公式', '创建自己的公式工具', ToolCategory.custom, '公式',
      '支持 a、b、c 三个变量和常用数学函数。'),
];

ToolDefinition? toolById(String id) {
  for (final tool in toolCatalog) {
    if (tool.id == id) return tool;
  }
  return null;
}

ToolDefinition _textTool(
  String id,
  String title,
  String description,
  ToolCategory category,
  String group,
  String explanation,
) {
  return ToolDefinition(
    id: id,
    title: title,
    description: description,
    category: category,
    kind: ToolKind.staticOnly,
    group: group,
    inputs: const [],
    formula: '文本输入工具',
    explanation: explanation,
  );
}

ToolDefinition _unitTool(String id, String title, String description,
    ToolKind kind, String unit, double value) {
  return ToolDefinition(
    id: id,
    title: title,
    description: description,
    category: ToolCategory.units,
    kind: kind,
    featured: true,
    inputs: [
      ToolInputDefinition(
          key: 'value', label: '输入值', unit: unit, defaultValue: value)
    ],
    formula: '目标值 = 输入值 × 单位倍率',
    explanation: '支持工程常用单位快速换算。',
  );
}
