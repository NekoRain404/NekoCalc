import '../entities/tool_category.dart';
import '../entities/tool_definition.dart';

final List<ToolDefinition> scienceToolDefinitions = [
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
];
