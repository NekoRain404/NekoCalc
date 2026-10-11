/// 中文：**结构类工具洞察句的英文**——`tool_insights_structure.dart` 里那些句子的中文→英文表。
///       键是中文本身，查不到就原样返回（机制见 `tool_insight_strings.dart` 的文件头）。
///       带插值的句子在下面那张模板表里：键是源码原文（含 `$…`），英文一侧的 `{}` 是载荷位。
/// English: **the English of the structure-category tool insight sentences** — the Chinese→English
///          table for the sentences in `tool_insights_structure.dart`. The key is the Chinese itself
///          and a miss returns it unchanged (the mechanism is on `tool_insight_strings.dart`'s head).
///          Interpolated sentences sit in the template table below: the key is the source text
///          (including `$…`) and each `{}` on the English side is a payload slot.
library;

const Map<String, String> toolInsightsStructureEn = <String, String>{
  '压力不能为负，受压面积必须大于 0': 'Pressure cannot be negative and the pressurised area must be greater than 0',
  '压力超过 20MPa，密封、软管和结构强度必须按额定值复核': 'Pressure above 20MPa: seals, hoses and structural strength must be checked against their ratings',
  '作用力超过 100kN，夹具刚度、压板强度和安全防护要单独校核': 'Force above 100kN: fixture stiffness, platen strength and safety guarding must be checked separately',
  '目标作用力反推需要非零压力和有效受压面积作为参考': 'Back-solving the target force needs a non-zero pressure and an effective pressurised area as a reference',
  '目标作用力反推仅按 F=P×A 估算，实际还要校核密封面积和压力损失': 'Target-force back-solving is estimated from F=P×A alone; seal area and pressure loss still need checking in practice',
  '压力面积力按均布压力估算，边缘密封、偏载和动态冲击未计入': 'The pressure-area force is estimated as uniform pressure; edge sealing, off-centre loading and dynamic shock are not included',
  '正压力和摩擦系数不能为负': 'Normal force and friction coefficient cannot be negative',
  '摩擦系数大于 1，通常只适合橡胶等高摩擦接触或特殊工况': 'A friction coefficient above 1 is usually only suitable for rubber and similar high-friction contacts, or special service conditions',
  '正压力为 0 时不会产生库仑摩擦力': 'With a normal force of 0 there is no Coulomb friction',
  '静摩擦上限和动摩擦系数可能不同，润滑、表面状态和温度会显著改变结果': 'The static friction limit and the kinetic friction coefficient can differ; lubrication, surface condition and temperature change the result markedly',
  '质量不能为负，摩擦系数不能为负，角度需在 -90° 到 90°': 'Mass and friction coefficient cannot be negative; the angle must be within -90° to 90°',
  '沿斜面分力超过摩擦上限，物体会沿斜面下滑': 'The down-slope component exceeds the friction limit, so the body slides down the slope',
  '斜面角度超过 45°，法向力下降且对摩擦系数更敏感': 'Slope angle above 45°: the normal force falls and the result is more sensitive to the friction coefficient',
  '净下滑力为正会下滑，为负说明摩擦可抵住；静摩擦和动摩擦需按材料分别取值': 'A positive net down-slope force means it slides and a negative one means friction holds; static and kinetic friction must be taken separately for each material',
  '跨度、弹性模量和惯性矩必须大于 0，载荷必须是有限数值': 'Span, elastic modulus and moment of inertia must be greater than 0, and the load must be a finite value',
  '跨度/挠度低于 250，刚度偏软，常见结构设计还需限制挠度': 'Span / deflection below 250: the stiffness is on the soft side, and common structural design also limits deflection',
  '目标挠度反推所需惯性矩需要非零载荷，目标挠度也必须大于 0': 'Back-solving the inertia for a target deflection needs a non-zero load, and the target deflection must also be greater than 0',
  '目标挠度反推按同一简支梁模型估算，换支撑或载荷形式需重算': 'Target-deflection back-solving uses the same simply supported beam model; a different support or load pattern means recomputing',
  '按简支梁中央集中载荷计算，支撑或载荷形式变化时不能直接套用': 'Computed for a simply supported beam with a central point load; other supports or load patterns do not carry over directly',
  '截面积和弹性模量必须大于 0，轴向力必须是有限数值': 'Section area and elastic modulus must be greater than 0, and the axial force must be a finite value',
  '应力超过 250MPa，常见结构钢也需要按材料牌号、屈服强度和安全系数复核': 'Stress above 250MPa: even common structural steel needs checking against its grade, yield strength and safety factor',
  '这是轴向平均应力，孔边、焊缝、压杆稳定和缺口要单独看应力集中': 'This is the mean axial stress; hole edges, welds, column buckling and notches need separate stress-concentration checks',
  '圆直径、管外径、矩形宽高必须大于 0，管内径不能为负且必须小于外径': 'Circle diameter, pipe OD and rectangle width and height must be greater than 0; the pipe ID cannot be negative and must be less than the outer diameter',
  '管截面内径必须小于外径': 'The inner diameter of a pipe section must be less than its outer diameter',
  '管壁厚小于外径 5%，薄壁管还需要校核局部屈曲和制造公差': 'Wall thickness below 5% of the outer diameter: a thin-walled tube also needs local buckling and manufacturing tolerance checked',
  '空心率超过 70%，截面更轻但局部稳定、连接和压溃风险要单独确认': 'Hollow ratio above 70%: the section is lighter, but local stability, connections and crushing risk need separate confirmation',
  '截面属性按理想几何计算，圆角、孔洞、焊缝和实际型材公差未计入': 'Section properties are computed from ideal geometry; fillets, holes, welds and real profile tolerances are not included',
  '材料强度必须大于 0，工作应力必须是有限数值': 'Material strength must be greater than 0, and the working stress must be a finite value',
  '工作应力为 0 时安全系数趋于无穷大，但仍需考虑预紧、冲击或装配载荷': 'At a working stress of 0 the safety factor tends to infinity, but preload, shock and assembly loads still need considering',
  '安全系数小于 1，按当前输入已经不足': 'Safety factor below 1: already insufficient with the current inputs',
  '安全系数偏紧，疲劳、冲击、温度和制造偏差要继续校核': 'The safety factor is on the tight side; fatigue, shock, temperature and manufacturing deviation still need checking',
  '强度余量为负，工作应力已超过许用强度': 'Strength margin is negative: the working stress has exceeded the allowable strength',
  '流量不能为负，管内径必须大于 0': 'Flow rate cannot be negative and the pipe ID must be greater than 0',
  '流速超过 3m/s，水路常见设计中压降、噪声和冲刷风险会明显增加': 'Flow velocity above 3m/s: in common water-circuit design the pressure drop, noise and erosion risk rise markedly',
  '流速低于 0.3m/s，管路可能更容易沉积或排气不畅': 'Flow velocity below 0.3m/s: the line may be more prone to sediment build-up or poor venting',
  '雷诺数处于过渡区，流态和压降对扰动比较敏感': 'The Reynolds number is in the transition zone; the flow regime and the pressure drop are sensitive to disturbance',
  '雷诺数超过 100000，粗糙度、局部阻力和弯头阀门损失需要单独计算': 'Reynolds number above 100000: roughness, minor losses and elbow and valve losses need separate calculation',
  '雷诺数按 20℃ 水的运动黏度估算，气体、油液或温度变化时需改用实际物性': 'The Reynolds number is estimated from the kinematic viscosity of water at 20℃; for gases, oils or other temperatures use the actual properties',
  '长度、宽度、厚度和密度都必须大于 0': 'Length, width, thickness and density must all be greater than 0',
  '重量超过 100kg，搬运、吊装和支撑工装需要单独考虑': 'Weight above 100kg: handling, lifting and support fixtures need separate consideration',
  '密度低于 1g/cm³，常见于泡沫、木材或轻质塑料，实际含水率会影响重量': 'Density below 1g/cm³ is typical of foam, timber or light plastics; actual moisture content affects the weight',
  '厚度低于 1mm，卷材、涂层和公差会明显影响重量估算': 'Thickness below 1mm: coil stock, coating and tolerance markedly affect the weight estimate',
  '矩形板材按实心体估算，开孔、倒角、涂层和加工余量未计入': 'The rectangular plate is estimated as a solid body; holes, chamfers, coating and machining allowance are not included',
};

/// 中文：带插值的句子。键是源码原文，英文一侧的 `{}` 按出现顺序接住载荷。
/// English: interpolated sentences. The key is the source text; each `{}` on the English side takes
///          the payloads in order.
const Map<String, String> toolInsightTemplatesStructureEn = <String, String>{
  r'目标作用力与当前作用力相差 ${formatNumber(forceDelta)}N': 'Target force differs from the current force by {}N',
  r'摩擦余量约 ${formatNumber(netDownhill.abs())}N，实际静摩擦系数不足时仍会滑动': 'Friction margin about {}N; it can still slide if the actual static friction coefficient falls short',
  r'目标挠度与当前挠度幅值相差 ${formatNumber(deflectionDelta)}mm': 'Target deflection differs from the current deflection magnitude by {}mm',
  r'矩形强轴为 $strongAxis，弯曲方向不同会显著改变挠度和应力': 'The rectangle\'s strong axis is {}; bending the other way changes the deflection and stress markedly',
  r'目标安全系数需要材料强度约 ${formatNumber(requiredStrength)}MPa': 'The target safety factor needs a material strength of about {}MPa',
  r'当前安全系数低于目标 ${formatNumber(factorDelta.abs())}': 'The current safety factor is below the target by {}',
};
