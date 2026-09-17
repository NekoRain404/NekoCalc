import '../entities/tool_category.dart';
import '../entities/tool_definition.dart';

final List<ToolDefinition> electronicsToolDefinitions = [
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
];
