import '../entities/tool_category.dart';
import '../entities/tool_definition.dart';

final List<ToolDefinition> mechanicalToolDefinitions = [
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
];
