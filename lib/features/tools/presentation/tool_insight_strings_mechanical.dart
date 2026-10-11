/// 中文：**机械类工具洞察句的英文**——`tool_insights_mechanical.dart` 里那些句子的中文→英文表。
///       键是中文本身，查不到就原样返回（机制见 `tool_insight_strings.dart` 的文件头）。
///       带插值的句子在下面那张模板表里：键是源码原文（含 `$…`），英文一侧的 `{}` 是载荷位。
/// English: **the English of the mechanical-category tool insight sentences** — the Chinese→English
///          table for the sentences in `tool_insights_mechanical.dart`. The key is the Chinese itself
///          and a miss returns it unchanged (the mechanism is on `tool_insight_strings.dart`'s head).
///          Interpolated sentences sit in the template table below: the key is the source text
///          (including `$…`) and each `{}` on the English side is a payload slot.
library;

const Map<String, String> toolInsightsMechanicalEn = <String, String>{
  '驱动齿数和从动齿数必须大于 0，效率需在 0% 到 100%': 'Driver and driven tooth counts must be greater than 0, and efficiency must be between 0% and 100%',
  '目标输出转速不能为 0，且必须是有限数值': 'Target output speed cannot be 0 and must be a finite number',
  '单级传动比超过 10，齿轮尺寸、啮合强度和效率通常需要分级设计': 'A single-stage ratio above 10 usually needs split-stage design for gear size, mesh strength and efficiency',
  '高速增速比很大，需重点校核动平衡、润滑和齿面线速度': 'A very large step-up ratio needs extra checks on dynamic balance, lubrication and tooth-surface linear speed',
  '输出转速超过 10000rpm，轴承、润滑和动平衡要单独校核': 'Output speed above 10000rpm needs separate checks on bearings, lubrication and dynamic balance',
  '效率低于 80%，发热和润滑损耗会明显影响输出功率': 'Efficiency below 80% means heat and lubrication losses clearly cut the output power',
  '目标输出转速反推的从动齿数不是整数，需要选邻近齿数组合后复算转速误差': 'The driven tooth count back-solved from the target output speed is not an integer; pick a nearby tooth pair and recompute the speed error',
  '目标输出转速反推的驱动齿数不是整数，需要校核实际可用齿数组合': 'The driver tooth count back-solved from the target output speed is not an integer; check the tooth combinations actually available',
  '扭矩已乘效率；冲击载荷、齿面强度和轴承能力另算': 'Torque already includes efficiency; shock load, tooth strength and bearing capacity are counted separately',
  '扭矩和转速必须是有限数值': 'Torque and speed must be finite numbers',
  '转速为 0 时机械输出功率为 0，无法反推 1kW 所需扭矩': 'At 0 speed the mechanical output power is 0, so the torque for 1kW cannot be back-solved',
  '功率为负表示扭矩和转速方向相反，常见于制动或能量回馈': 'Negative power means torque and speed point in opposite directions, as in braking or regeneration',
  '转速超过 10000rpm，轴承、动平衡和临界转速需要单独校核': 'Speed above 10000rpm needs separate checks on bearings, balance and critical speed',
  '扭矩超过 1000N·m，轴径、键连接和联轴器额定值要单独校核': 'Torque above 1000N·m needs separate checks on shaft diameter, keyed joints and coupling ratings',
  '目标功率反推需要非零转速或非零扭矩作为参考': 'The target-power back-solve needs a non-zero speed or a non-zero torque as a reference',
  '目标功率反推只按轴功率计算，选型还要乘安全系数并计入效率': 'The target-power back-solve uses shaft power only; sizing must still apply a safety factor and count efficiency',
  '公式只给轴功率，电机效率、减速器效率和冲击载荷需另算': 'The formula gives shaft power only; motor efficiency, gearbox efficiency and shock load are counted separately',
  '弹簧刚度必须大于 0，变形量必须是有限数值': 'Spring stiffness must be greater than 0 and deflection must be a finite number',
  '目标储能不能为负，且必须是有限数值': 'Target stored energy cannot be negative and must be a finite number',
  '变形量为负表示按相反方向取参考，储能仍按位移平方计算': 'A negative deflection means the reference direction is reversed; stored energy still follows the square of the displacement',
  '弹簧力超过 1000N，端部固定、导向和材料许用应力要单独校核': 'Spring force above 1000N needs separate checks on end fixing, guidance and the material\'s allowable stress',
  '目标弹簧力为负时表示反向变形，实际结构需确认是否允许拉伸或反向受力': 'A negative target spring force means reversed deflection; the real structure must be checked for whether tension or reversed loading is allowed',
  '目标储能反推得到的是变形幅值，压缩或拉伸方向需按结构约束选择': 'The target-energy back-solve gives the deflection magnitude; the compression or tension direction follows the structural constraints',
  '按线性弹簧估算；接近并圈、屈服或非线性区时不能直接套用': 'Estimated as a linear spring; near solid height, yield or the non-linear region it does not apply directly',
  '气压不能为负，缸径必须大于 0，杆径需小于缸径': 'Air pressure cannot be negative, bore must be greater than 0, and rod diameter must be smaller than the bore',
  '气压超过 1MPa，需确认气缸、管路和接头额定压力': 'Pressure above 1MPa needs the cylinder, line and fitting pressure ratings confirmed',
  '杆径占比偏大，拉回力明显低于推出力，请核对回程负载': 'The rod diameter is a large share of the bore, so pull force is clearly below push force; check the return load',
  '目标推出力反推需要正气压或有效活塞面积作为参考': 'The target push force back-solve needs a positive pressure or a valid piston area as a reference',
  '目标推出力反推按理论面积计算，实际选型要扣除摩擦、背压并留安全系数': 'The target push force back-solve uses the theoretical area; real sizing must deduct friction and back pressure and keep a safety factor',
  '推出力余量为负，当前缸径和气压达不到目标推出力': 'The push force margin is negative; the current bore and pressure fall short of the target push force',
  '有效力还要扣掉密封摩擦、背压和压力波动': 'The effective force must also deduct seal friction, back pressure and pressure fluctuation',
  '质量不能为负，质量和加速度必须是有限数值': 'Mass cannot be negative, and mass and acceleration must be finite numbers',
  '加速度为负表示参考方向相反，力幅值已单独列出': 'A negative acceleration means the reference direction is reversed; the force magnitude is listed separately',
  '力超过 10kN，连接件、夹具和安全防护需要单独校核': 'Force above 10kN needs separate checks on fasteners, fixtures and guarding',
  '目标力反推需要非零质量或非零加速度作为参考': 'The target force back-solve needs a non-zero mass or a non-zero acceleration as a reference',
  '目标力反推只按 F=ma 计算，实际负载还要叠加摩擦、重力分力和冲击峰值': 'The target force back-solve uses F=ma only; the real load also adds friction, the gravity component and the shock peak',
  '这是 F = ma 的惯性力估算，不含摩擦、冲击、空气阻力和机构效率': 'This is an inertial force estimate from F = ma, excluding friction, impact, air drag and mechanism efficiency',
  '主动轮和从动轮直径必须大于 0，输入转速必须是有限数值': 'Driver and driven pulley diameters must be greater than 0 and the input speed must be a finite number',
  '皮带轮直径比超过 5:1，包角、张紧和打滑风险要单独确认': 'A pulley diameter ratio beyond 5:1 needs the wrap angle, tension and slip risk confirmed separately',
  '皮带线速度超过 30m/s，需核对皮带型号、动平衡和防护': 'Belt speed above 30m/s needs the belt type, balance and guarding checked',
  '目标输出转速反推轮径需要非零输入转速作为参考': 'Back-solving the pulley diameter from the target output speed needs a non-zero input speed as a reference',
  '目标输出转速反推按无打滑几何关系计算，实际需按标准轮径和包角修正': 'The target output speed back-solve uses the no-slip geometric relation; real work must correct for standard pulley diameters and the wrap angle',
  '按无打滑开口皮带估算；交叉皮带会反向，实际还受张力和包角影响': 'Estimated as a no-slip open belt; a crossed belt reverses the direction, and tension and wrap angle matter in practice',
  '导程必须大于 0，转速必须是有限数值': 'Lead must be greater than 0 and speed must be a finite number',
  '转速为负表示反向进给，线速度符号保留方向': 'A negative speed means reverse feed; the sign of the linear speed preserves the direction',
  '线速度超过 500mm/s，临界转速、振动和加减速距离要单独校核': 'Linear speed above 500mm/s needs separate checks on critical speed, vibration and the acceleration and deceleration distance',
  '目标线速度反推导程需要非零转速作为参考': 'Back-solving the lead from the target linear speed needs a non-zero speed as a reference',
  '目标线速度反推只按导程几何换算，实际还要校核丝杆临界转速和电机扭矩': 'The target linear speed back-solve is a lead geometry conversion only; real work must also check the screw\'s critical speed and motor torque',
  '仅按几何导程换算，不含丝杆效率、背隙、弹性变形和驱动扭矩限制': 'A geometric lead conversion only, excluding screw efficiency, backlash, elastic deformation and drive torque limits',
};

/// 中文：带插值的句子。键是源码原文，英文一侧的 `{}` 按出现顺序接住载荷。本分类今天没有这样的句子。
/// English: interpolated sentences. The key is the source text; each `{}` on the English side takes
///          the payloads in order. This category has none today.
const Map<String, String> toolInsightTemplatesMechanicalEn = <String, String>{};
