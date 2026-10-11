/// 中文：**物理类工具洞察句的英文**——`tool_insights_physics.dart` 里那些句子的中文→英文表。
///       键是中文本身，查不到就原样返回（机制见 `tool_insight_strings.dart` 的文件头）。
///       带插值的句子在下面那张模板表里：键是源码原文（含 `$…`），英文一侧的 `{}` 是载荷位。
/// English: **the English of the physics-category tool insight sentences** — the Chinese→English
///          table for the sentences in `tool_insights_physics.dart`. The key is the Chinese itself
///          and a miss returns it unchanged (the mechanism is on `tool_insight_strings.dart`'s head).
///          Interpolated sentences sit in the template table below: the key is the source text
///          (including `$…`) and each `{}` on the English side is a payload slot.
library;

const Map<String, String> toolInsightsPhysicsEn = <String, String>{
  '速度、时间、距离至少填写两项；数值不能为负，反推时分母不能为 0': 'Fill at least two of speed, time and distance; values cannot be negative and the denominator cannot be 0 when back-solving',
  '速度超过 120km/h，制动距离、反应时间和安全边界需要单独考虑': 'Speed above 120km/h: braking distance, reaction time and the safety margin need separate consideration',
  '匀速运动默认速度恒定，未计入加速、减速、坡度和阻力': 'Uniform motion assumes constant speed and ignores acceleration, deceleration, slope and resistance',
  '高度不能为负，重力加速度必须大于 0；填写质量时质量不能为负': 'Height cannot be negative and gravity must be above 0; when mass is filled in, it cannot be negative',
  '末速度超过 100km/h，空气阻力会明显改变真实结果': 'Final speed above 100km/h: air resistance clearly changes the real result',
  '初速度为负表示先向上抛出，再回落到指定高度差': 'A negative initial speed means a throw upwards first, then a fall back to the given height difference',
  '初速度按向下为正计入，会缩短落地时间并增加末端动能': 'A downward initial speed counts as positive, shortening the landing time and raising the final kinetic energy',
  '冲击能量超过 1kJ，真实碰撞还要看接触时间、缓冲距离和结构强度': 'Impact energy above 1kJ: a real collision also depends on the contact time, stopping distance and structural strength',
  '缓冲平均力需要同时填写质量和大于 0 的缓冲距离': 'Mean stop force needs both a mass and a stopping distance above 0',
  '缓冲平均力按冲击能量/缓冲距离估算，真实峰值取决于接触时间和缓冲曲线': 'Mean stop force is estimated as impact energy/stopping distance; the real peak depends on the contact time and the stopping curve',
  '缓冲平均力超过 10kN，实际峰值可能更高，需要结构和固定方式校核': 'Mean stop force above 10kN: the real peak may be higher, so the structure and its fixing need checking',
  '自由落体按真空模型计算，未计入空气阻力、姿态、旋转和碰撞缓冲': 'Free fall uses a vacuum model and ignores air resistance, attitude, spin and impact cushioning',
  '时间必须大于 0，效率需在 0% 到 100% 之间，力、位移和夹角需要是有限数值': 'Time must be above 0, efficiency between 0% and 100%, and force, displacement and angle must be finite values',
  '平均功率为负，表示力与位移方向相反或在回收能量': 'Negative average power means the force opposes the displacement or energy is being recovered',
  '力-位移夹角接近 90°，有效做功对角度误差非常敏感': 'A force-displacement angle near 90°: useful work is very sensitive to angle error',
  '效率低于 70%，输入功率和热损耗需要单独核对': 'Efficiency below 70%: input power and heat loss need checking separately',
  '损耗功率超过 100W，散热、温升和供能余量需要额外确认': 'Loss power above 100W: heat dissipation, temperature rise and supply headroom need extra confirmation',
  '目标功率反推时间或力需要非零目标功率、位移和有效夹角': 'Back-solving the time or force from a target power needs a non-zero target power, a displacement and a useful angle',
  '目标功率反推按平均功率计算，启动峰值和速度曲线需要按实际运动过程校核': 'The target-power back-solve uses average power; startup peaks and the speed profile need checking against the real motion',
  '功率为平均值，瞬时峰值、摩擦损耗、传动效率和控制策略需按实际工况复核': 'Power is an average value; instantaneous peaks, friction loss, drive efficiency and the control strategy need reviewing against the real operating conditions',
  '质量不能为负，速度和高度需要是有限数值': 'Mass cannot be negative, and speed and height must be finite values',
  '动能超过 10kJ，碰撞、防护和制动场景需要按安全规范复核': 'Kinetic energy above 10kJ: collision, protection and braking scenarios need reviewing against safety standards',
  '目标总能量反推速度需要非零质量，且目标能量必须不低于当前势能': 'Back-solving the speed from a target total energy needs a non-zero mass, and the target energy must not be below the current potential energy',
  '目标总能量反推只按动能和重力势能换算，实际运动还要计入损耗和安全余量': 'The target-total-energy back-solve converts only kinetic and gravitational potential energy; real motion also carries losses and a safety margin',
  '势能使用标准重力加速度 9.80665m/s²，未计入弹性势能和能量损耗': 'Potential energy uses standard gravity 9.80665m/s² and ignores elastic potential energy and energy loss',
  '质量、体积、密度至少填写两项；质量不能为负，体积和密度必须大于 0': 'Fill at least two of mass, volume and density; mass cannot be negative and volume and density must be above 0',
  '密度高于 8000kg/m³，接近重金属材料范围': 'Density above 8000kg/m³: close to the range of heavy-metal materials',
  '密度低于 1kg/m³，常见于低压气体口径，请确认单位和体积状态': 'Density below 1kg/m³ is common on a low-pressure gas basis; confirm the units and the volume state',
  '密度按均匀材料估算，孔隙、含水率、温度和混合比例会改变结果': 'Density is estimated for a uniform material; porosity, moisture content, temperature and mix ratio change the result',
  '请至少填写两项可形成浓度关系的输入；溶质量和浓度不能为负，体积和摩尔质量必须大于 0': 'Fill at least two inputs that form a concentration relation; solute mass and concentration cannot be negative and volume and molar mass must be above 0',
  '摩尔浓度超过 10mol/L，需核对溶解度和体积口径': 'Molarity above 10mol/L: check the solubility and the volume basis',
  '浓度按最终溶液体积估算，混合体积变化、活度和温度影响未计入': 'Concentration is estimated from the final solution volume; mixing volume change, activity and temperature effects are not included',
  '压力、物质的量、热力学温度和体积至少填写三项；物质的量不能为负，其余项必须大于 0': 'Fill at least three of pressure, amount of substance, thermodynamic temperature and volume; the amount of substance cannot be negative and the remaining items must be above 0',
  '压力超过 1000kPa，高压场景需按容器额定压力和真实气体修正复核': 'Pressure above 1000kPa: high-pressure cases need review against the vessel rating and real-gas corrections',
  '理想气体模型适合低压稀薄气体，高压、低温和相变附近误差会增大': 'The ideal-gas model suits low-pressure dilute gases; near high pressure, low temperature and phase change the error grows',
  '质量、比热容、温度变化、热量至少填写三项；质量和比热容不能为负，反推分母不能为 0': 'Fill at least three of mass, specific heat, temperature change and heat; mass and specific heat cannot be negative and the back-solve denominator cannot be 0',
  '热量为负，表示对象降温并向外放热': 'Negative heat means the object is cooling and releasing heat',
  '热量计算未计入相变潜热、散热损失、热容随温度变化和加热效率': 'The heat calculation ignores latent heat of phase change, heat loss, the temperature dependence of heat capacity and heating efficiency',
  '波速、频率、波长至少填写两项，且都必须大于 0': 'Fill at least two of wave speed, frequency and wavelength, and all must be above 0',
  '声波频率超过 20kHz，通常已进入超声范围': 'Sound frequency above 20kHz: usually already in the ultrasonic range',
  '波长按均匀介质计算，温度、介质变化和色散会改变波速': 'Wavelength is computed for a uniform medium; temperature, medium changes and dispersion alter the wave speed',
  '至少填写三项；初始量和剩余量不能为负，半衰期必须大于 0，经过时间不能为负，剩余比例需在 0% 到 100%': 'Fill at least three; the initial and remaining amounts cannot be negative, the half-life must be above 0, the elapsed time cannot be negative, and the remaining ratio must be between 0% and 100%',
  '剩余比例低于 1%，实际测量会更依赖本底噪声和探测限': 'A remaining ratio below 1%: measurements rely more on background noise and the detection limit',
  '半衰期模型按指数衰减估算，实际计数存在统计波动和测量效率误差': 'The half-life model estimates exponential decay; real counts carry statistical fluctuation and detection-efficiency error',
  '请填写有效的 pH、[H+] 或 [OH-]；浓度必须大于 0': 'Enter a valid pH, [H+] or [OH-]; the concentration must be above 0',
  'pH 极端，稀溶液近似和安全防护都需要额外核对': 'Extreme pH: the dilute-solution approximation and safety precautions both need extra checking',
  'pH 按 25℃ 水溶液 Kw=1e-14 简化估算，强酸强碱以外还要考虑活度和缓冲体系': 'pH is a simplified estimate at the 25℃ Kw=1e-14 of water; outside strong acids and bases, activity and buffer systems also count',
};

/// 中文：带插值的句子。键是源码原文，英文一侧的 `{}` 按出现顺序接住载荷。
/// English: interpolated sentences. The key is the source text; each `{}` on the English side takes
///          the payloads in order.
const Map<String, String> toolInsightTemplatesPhysicsEn = <String, String>{
  r'当前按 $source 计算，其余输出由匀速模型换算': 'Computed from {}; the other outputs follow the uniform-motion model',
  r'三项都填写时按速度×时间计算，和输入距离相差 ${formatNumber(distanceDelta)}m': 'With all three filled, speed × time is used; the result differs from the entered distance by {}m',
  r'当前总能量与目标相差 ${formatNumber(energyDelta)}J': 'The current total energy differs from the target by {}J',
  r'当前按 $source 计算，其余输出由 ρ=m/V 换算': 'Computed from {}; the other outputs follow ρ=m/V',
  r'三项都填写时按质量/体积计算，和输入密度相差 ${formatNumber(densityDelta)}kg/m³': 'With all three filled, mass/volume is used; the result differs from the entered density by {}kg/m³',
  r'当前按 $source 计算，其余输出由 γ=m/V 与 C=γ/M 换算': 'Computed from {}; the other outputs follow γ=m/V and C=γ/M',
  r'质量浓度参考值与当前计算相差 ${formatNumber(massConcentrationDelta)}g/L': 'The mass-concentration reference differs from the current calculation by {}g/L',
  r'摩尔浓度参考值与当前计算相差 ${formatNumber(molarityDelta)}mol/L': 'The molarity reference differs from the current calculation by {}mol/L',
  r'摩尔质量参考值与当前计算相差 ${formatNumber(molarMassDelta)}g/mol': 'The molar-mass reference differs from the current calculation by {}g/mol',
  r'当前按 $source 计算，其余输出由 PV=nRT 换算': 'Computed from {}; the other outputs follow PV=nRT',
  r'压力参考值与当前计算相差 ${formatNumber(pressureDelta)}kPa': 'The pressure reference differs from the current calculation by {}kPa',
  r'当前按 $source 计算，其余输出由 Q=mcΔT 换算': 'Computed from {}; the other outputs follow Q=mcΔT',
  r'热量参考值与当前计算相差 ${formatNumber(heatDelta)}J': 'The heat reference differs from the current calculation by {}J',
  r'当前按 $source 计算，其余输出由 λ=v/f 换算': 'Computed from {}; the other outputs follow λ=v/f',
  r'波长参考值与当前计算相差 ${formatNumber(wavelengthDelta)}m': 'The wavelength reference differs from the current calculation by {}m',
  r'当前按 $source 计算，其余输出由 N=N0×0.5^(t/T) 换算': 'Computed from {}; the other outputs follow N=N0×0.5^(t/T)',
  r'剩余量参考值与当前计算相差 ${formatNumber(remainingDelta)}': 'The remaining-amount reference differs from the current calculation by {}',
  r'剩余比例参考值与当前计算相差 ${formatNumber(remainingRatioDelta)}%': 'The remaining-ratio reference differs from the current calculation by {}%',
  r'当前以 $source 作为输入来源反推其它浓度': 'The other concentrations are back-solved from {} as the input source',
  r'当前 pH 与目标 pH 相差 ${formatNumber(phDelta)}': 'The current pH differs from the target pH by {}',
};
