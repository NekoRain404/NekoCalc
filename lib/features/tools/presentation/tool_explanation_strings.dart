/// 中文：**工具目录的公式卡表**——`tool.formula`（10 条）与 `tool.explanation`（96 条）的英文。
///
///       **机制（键是中文本身、中文那一侧没有表、回落是 `?? 键`）与三张表为什么分成三个文件，
///       写在 `tool_field_strings.dart` 的文件头上，这里不重抄。** 本文件自己的一句话是：
///       **这两格是详情页上同一张卡片的两行**——`SectionTitle(公式)` 下面，先公式、后解释，
///       在同一个 `Card` 里上下相邻，所以放在同一张表、同一个文件里。
///
///       **公式那 10 条多数只是"记号里嵌着几个汉字"。** `tool.formula` 在目录里 117 处、
///       78 个不同值，其中 **68 个从头到尾都是记号**（`1/R1 = 1/R2 + 1/R3`、`a² + b² = c²`、
///       `PV = nRT`、`V = IR`），**一个汉字都没有**，两种语言逐字节相同，一条都不进表；
///       进表的 10 条里，`目标值 = 输入值 × 单位倍率` 一条就覆盖了 22 个换算工具，
///       `文本输入工具` 一条覆盖 18 个文本工具。**翻这 10 条时只动汉字，记号一个字符不改**——
///       `A圆=πd²/4, I圆=πd⁴/64, Z=I/c, r=sqrt(I/A)` 翻成 `Circle: A=πd²/4, I=πd⁴/64, Z=I/c,
///       r=sqrt(I/A)`，除了"圆"字与它前面的 `A`/`I` 换了位置，其余逐字符相同；
///       `含税金额 = 税前金额 × (1 + 税率)` 这类带括号与空格的，**连括号里那几个空格也照原样留着**
///       （中文那一段非 CJK 记号是 `× (1 +`，英文里必须原样找得到）。
///
///       **解释那 96 条是这一轮最大的写作量，也是最容易出错的一格。** 每一句里都嵌着语言无关的
///       记号：`2x2`、`D、Dx、Dy`、`n!/k!/(n-k)!`、`50Ω`、`Vrms、Vpeak、Vpp`、`dBV`、`dBu`、
///       `LC/RLC`、`3dB`、`Buck/Boost`、`IPC-2221`、`RA/RB`、`1kW`、`N/kN`、`kgf`、`bar`、
///       `m³/h`、`20℃`、`kg/lb/N`、`R=8.314 J/(mol·K)`、`[H+]`、`[OH-]`、`Kw=1e-14`、
///       `Mosteller`、`0x、#、h、0b、b、0o、o`、`UTF-16/32/8`、`U+` 与 `\u`、`SUM8、XOR8、LRC`、
///       `Header/Payload`、`FNV-1a/CRC32`、`A/B`、`JSON Lines`、`km/L`。
///       **判据是机器查的**：中文按 CJK 与全角断开，凡**非 CJK 的连续段**都必须在英文里原样
///       找得到（`tool_field_strings_test.dart`，与 `tool_description_strings_test.dart` 同一把
///       尺子、同一套例外规则）。这条断言本轮当场抓到过两处：`输入电压 Vin` 那一格漏了 `Vin`
///       （一开始写成 `Input voltage`），base64 那句把 `标准/Base64URL/data URL` 写成了带空格的
///       `standard / Base64URL / data URL`——**两处都是眼睛看不出来的**，见报告。
/// English: **the tools catalogue's formula-card table** — the English of `tool.formula` (10) and
///          `tool.explanation` (96).
///
///          **The mechanism (key = the Chinese, no Chinese-side table, fallback `?? key`) and the
///          reason for three files are on `tool_field_strings.dart`'s head and are not copied here.**
///          What this file adds: **these are the two lines of one card on the detail page** — under
///          `SectionTitle(公式)`, formula first and explanation below it, adjacent in one `Card`, so
///          they share one table and one file.
///
///          **Most of the 10 formulas are notation with a few Han characters embedded.** `tool.formula`
///          occurs 117 times across 78 distinct values, and **68 of those are notation from end to
///          end** (`1/R1 = 1/R2 + 1/R3`, `a² + b² = c²`, `PV = nRT`, `V = IR`) with **not one Han
///          character**, identical in both languages and absent from the table. Of the 10 that enter,
///          `目标值 = 输入值 × 单位倍率` alone covers the 22 conversion tools and `文本输入工具` the 18
///          text tools. **Translating them moves the Han characters and nothing else** —
///          `A圆=πd²/4, I圆=πd⁴/64, Z=I/c, r=sqrt(I/A)` becomes `Circle: A=πd²/4, I=πd⁴/64, Z=I/c,
///          r=sqrt(I/A)`, byte-identical apart from `圆` and where `A`/`I` sit; and where the Chinese
///          carries brackets and spaces, `含税金额 = 税前金额 × (1 + 税率)`, **even the spaces inside
///          the brackets stay exactly as they were** (the Chinese run there is `× (1 +` and the
///          English must contain precisely that).
///
///          **The 96 explanations are this round's largest piece of writing and its easiest place to
///          slip.** Every one carries language-neutral notation: `2x2`, `D、Dx、Dy`, `n!/k!/(n-k)!`,
///          `50Ω`, `Vrms、Vpeak、Vpp`, `dBV`, `dBu`, `LC/RLC`, `3dB`, `Buck/Boost`, `IPC-2221`,
///          `RA/RB`, `1kW`, `N/kN`, `kgf`, `bar`, `m³/h`, `20℃`, `kg/lb/N`, `R=8.314 J/(mol·K)`,
///          `[H+]`, `[OH-]`, `Kw=1e-14`, `Mosteller`, `0x、#、h、0b、b、0o、o`, `UTF-16/32/8`, `U+`
///          and `\u`, `SUM8、XOR8、LRC`, `Header/Payload`, `FNV-1a/CRC32`, `A/B`, `JSON Lines`,
///          `km/L`. **A machine checks it**: the Chinese is cut at CJK and full-width boundaries and
///          every **non-CJK run** must be found verbatim in the English
///          (`tool_field_strings_test.dart`, the same ruler and the same exception rules as
///          `tool_description_strings_test.dart`). It caught two here on the spot — the `Vin` missing
///          from `输入电压 Vin`'s English (first written `Input voltage`) and base64's
///          `标准/Base64URL/data URL` written as the spaced `standard / Base64URL / data URL`; **neither
///          is visible to the eye**. See the report.
const Map<String, String> toolFormulasEn = {
  '线性、二次、指数、幂函数最小二乘拟合': 'Least-squares fitting of linear, quadratic, exponential and power functions',
  'A圆=πd²/4, I圆=πd⁴/64, Z=I/c, r=sqrt(I/A)': 'Circle: A=πd²/4, I=πd⁴/64, Z=I/c, r=sqrt(I/A)',
  '月供 = 价格 × (1 + 手续费率) / 期数': 'Payment = price × (1 + fee rate) / periods',
  '利润 = 售价 - 成本, 毛利率 = 利润 / 售价': 'Profit = price - cost, margin = profit / price',
  'ROI = (收益 - 投入) / 投入, 收益 = 投入 × (1 + ROI)': 'ROI = (gain - cost) / cost, gain = cost × (1 + ROI)',
  '到手价 = 原价 × 折扣 / 100, 折扣 = 到手价 / 原价 × 100': 'Final price = original price × discount / 100, discount = final price / original price × 100',
  '含税金额 = 税前金额 × (1 + 税率), 税率 = 含税金额 / 税前金额 - 1': 'Gross = net × (1 + tax rate), tax rate = gross / net - 1',
  'NPV = Σ CFt/(1+r)^t - 初始投入': 'NPV = Σ CFt/(1+r)^t - initial cost',
  '目标值 = 输入值 × 单位倍率': 'Target = input × unit factor',
  '文本输入工具': 'Text-input tool',
};

/// 中文：**中文解释 → 英文**，96 条，按目录里第一次出现的顺序排。**一项一条，不是一工具一条**：
///       117 处解释里有 21 处与别的工具共用同一句（22 个换算工具共用 `支持工程常用单位快速换算。`
///       一句），所以表里是 96 行而不是 117 行——**共用的句子只有一份英文，不可能漂**。
///
///       **写作口径**：句子结构与中文对齐（先是"能填什么/反推什么"，再是"输出什么"），
///       从句与从句之间用分号；`/` 与 `、` 一律按英文习惯改写成斜杠或逗号，但**记号段按原样**
///       （见上）。用词与同一页上的字段表同源：`截止频率` 在解释里写 `cutoff frequency`、
///       在标签那格写 `Target cutoff`；`压降误差` 写 `forward-voltage tolerance`、
///       标签写 `Vf tolerance`。拼写用英式（`colour`/`normalised`/`quantisation`），
///       与 `tool_catalog_strings.dart` 里已经提交的那些英文一致。
/// English: **Chinese explanation → English**, 96 entries in catalogue order of first appearance.
///          **One entry per sentence, not per tool**: 21 of the 117 occurrence sites share a sentence
///          with another tool (the 22 conversion tools share `支持工程常用单位快速换算。`), so the table
///          has 96 rows rather than 117 — **a shared sentence has exactly one English, and cannot
///          drift**.
///
///          **House style**: the sentence structure follows the Chinese (what may be filled in / what
///          is back-solved first, what comes out second), clauses separated by semicolons; `/` and
///          `、` are rewritten the way English wants them, but **notation runs stay as they are** (see
///          above). The wording comes from the same page's field table: `截止频率` is `cutoff
///          frequency` in prose and `Target cutoff` in a label; `压降误差` is `forward-voltage
///          tolerance` in prose and `Vf tolerance` in a label. British spelling
///          (`colour`/`normalised`/`quantisation`) matches the English already committed in
///          `tool_catalog_strings.dart`.
const Map<String, String> toolExplanationsEn = {
  '同时输出判别式、两个根、顶点坐标与对称轴。': 'Also gives the discriminant, both roots, the vertex and the axis of symmetry.',
  '使用克莱姆法则求解 2x2 方程组，输出 D、Dx、Dy、矩阵秩、代回残差，并区分唯一解、无解和无穷多解。': 'Solves a 2x2 system by Cramer\'s rule and gives D, Dx, Dy, the matrix rank and the residual of the back-substitution, telling a unique solution from none and from infinitely many.',
  '基准值、百分比、百分比结果和新值任意填写两项即可反推其余量，输出增加后、减少后、变化率、结果占新值和差值。': 'Fill any two of base, percent, percent value and new value and the rest are back-solved; gives the after-increase and after-decrease values, the change rate, the value as a share of the new value, and the difference.',
  '常见指数与对数运算集合，输出幂、反向幂、自然/常用/换底对数、平方根、y 次根、倒数和实数域状态。': 'A set of everyday power and logarithm operations: power, inverse power, natural / common / base-change logs, square root, y-th root, reciprocal, and whether the result is real.',
  '对 x 求导并逐步写出用了哪条法则：和、积、幂、负号；不会的那一步如实停下，绝不跳过。':
      'Differentiates with respect to x and writes out the rule used at each step — sum, product, power, sign; a step it cannot do stops the derivation rather than being skipped.',
  '用于快速求解一元一次方程，输出斜率、截距、x 截距、代回校验，并区分唯一解、无解和恒等式。': 'Quickly solves a linear equation in one unknown and gives the slope, intercept, x-intercept and a back-substitution check, telling a unique solution from none and from an identity.',
  'a、b、c、x 任意填写三项即可反推第四项，并输出比例系数、右侧系数和交叉乘积差。': 'Fill any three of a, b, c and x and the fourth is back-solved, with the ratio factor, the right-hand factor and the cross-product difference.',
  '输入 n 和 k，输出排列数、组合数、n!/k!/(n-k)!、可重复有序抽取、互补组合和选择比例，并校验非负整数条件。': 'Enter n and k for permutations, combinations, n!/k!/(n-k)!, ordered draws with repetition, the complementary combination and the selection ratio, with a non-negative-integer check.',
  '按独立事件估算至少一个、同时发生、仅 A、仅 B、都不发生、至多一个和补集概率。': 'For independent events, estimates at least one, both, only A, only B, neither, at most one and the complement.',
  '支持最多 8 个样本，空白可选样本会被忽略，输出样本数、均值、中位数、总和、极差、总体/样本方差和标准差。': 'Takes up to 8 samples and ignores blank optional ones, giving the count, mean, median, sum, range, population / sample variance and standard deviation.',
  '适合把 Excel 风格的两列数据快速拟合成函数，并查看散点趋势图。': 'Fits two columns of Excel-style data to a function quickly, with a scatter trend chart.',
  '输入 2x2 矩阵四个元素，输出行列式、迹、特征判别项、逆矩阵、秩、特征值和常用矩阵范数。': 'Enter the four elements of a 2x2 matrix for the determinant, trace, characteristic term, inverse, rank, eigenvalues and the common matrix norms.',
  '输出复数加法、减法、乘法、除法、两个复数的模长、幅角和共轭。': 'Gives complex addition, subtraction, multiplication and division, plus the modulus, argument and conjugate of both numbers.',
  '用于几何、力学和图形计算中的二维向量分析，输出点积、叉积、夹角、距离、投影、方向角和平行/垂直关系。': '2D vector analysis for geometry, mechanics and graphics: dot product, cross product, angle, distance, projection, direction angle, and whether the vectors are parallel or perpendicular.',
  '使用海伦公式，输出面积、周长、角度、边长类型、三条高、内切圆半径和外接圆半径。': 'Uses Heron\'s formula and gives the area, perimeter, angles, side type, the three heights, the incircle radius and the circumradius.',
  '半径、直径、周长或面积任填一项即可换算其余圆形量，多个输入会作为参考并输出差值。': 'Fill any one of radius, diameter, perimeter or area and the rest of the circle are converted; extra inputs are kept as a reference and their difference is given.',
  '原始值、原比例、目标比例和缩放后任意填写三项即可反推第四项，输出线性、面积和体积缩放比例。': 'Fill any three of original value, original ratio, target ratio and scaled value and the fourth is back-solved, with the linear, area and volume scale factors.',
  '电压、电流、电阻和功率任意填写两项即可反推其它量；默认按电流+电阻计算，并输出电导、公差范围和推荐电阻功率档位。': 'Fill any two of voltage, current, resistance and power and the others are back-solved; the default is current + resistance, and conductance, the tolerance range and the recommended resistor power rating come with it.',
  '负载为空时按理想分压计算；填写负载后会计入并联影响、负载电流和功耗。填写目标输出后可反推保留 R1 或保留 R2 时所需的另一只电阻。': 'With no load it computes an ideal divider; with a load it accounts for the parallel effect, the load current and the dissipation. Fill the target output to back-solve the other resistor while keeping either R1 or R2.',
  '计算 RC 滤波器截止频率、时间常数、容差范围和常用频带参考点；填写目标截止频率后可反推保留 R 或保留 C 时所需的元件值。': 'Computes an RC filter\'s cutoff frequency, time constant, tolerance range and common-band reference points; fill the target cutoff to back-solve the part value while keeping either R or C.',
  '射频功率常用单位换算，并给出 50Ω 正弦匹配系统下的 Vrms、Vpeak、Vpp、dBV 和 dBu。': 'Converts the usual RF power units and gives Vrms, Vpeak, Vpp, dBV and dBu for a matched 50Ω sine system.',
  '输出串联和并联等效电阻、总电导、元件比值和公差范围；填写目标等效值后可在保留 R1 时反推所需 R2。': 'Gives the series and parallel equivalent resistance, total conductance, part ratio and tolerance range; fill the target equivalent to back-solve the R2 it needs while keeping R1.',
  '输出并联和串联等效电容、元件比值和公差范围；填写目标等效值后可在保留 C1 时反推所需 C2。': 'Gives the parallel and series equivalent capacitance, part ratio and tolerance range; fill the target equivalent to back-solve the C2 it needs while keeping C1.',
  '忽略互感影响，输出串联和并联等效电感、元件比值和公差范围；填写目标等效值后可在保留 L1 时反推所需 L2。': 'Ignores mutual inductance; gives the series and parallel equivalent inductance, part ratio and tolerance range, and fill the target equivalent to back-solve the L2 it needs while keeping L1.',
  '同时估算电阻功耗；填写实际选用电阻后会校核实际电流、电流偏差、功耗和压降误差范围。': 'Estimates the resistor dissipation too; fill the resistor you actually chose and it checks the real current, the current deviation, the dissipation and the forward-voltage tolerance range.',
  '输出同相与反相放大器增益、dB、输出电压、反馈系数和反馈网络阻值；填写目标增益、GBW 或满功率频率后估算所需反馈电阻、闭环带宽和压摆率。': 'Gives the non-inverting and inverting gain, dB, output voltage, feedback factor and feedback network resistance; fill the target gain, GBW or full-power frequency to estimate the feedback resistor it needs, the closed-loop bandwidth and the slew rate.',
  '输出 LSB、半 LSB 量化误差、最大码值、满量程和理论动态范围；填写输入电压或 ENOB 后估算码值、重构电压、量化误差和有效动态范围。': 'Gives the LSB, half-LSB quantisation error, maximum code, full scale and theoretical dynamic range; fill the input voltage or ENOB to estimate the code, reconstructed voltage, quantisation error and effective dynamic range.',
  'Vrms、Vpeak、Vpp 或 50Ω dBm 任填一项即可反推其它正弦波量，输出平均整流值、dBV、dBu、50Ω 功率、dBm 和参考差值。': 'Fill any one of Vrms, Vpeak, Vpp or 50Ω dBm and the other sine quantities are back-solved, with the average rectified value, dBV, dBu, 50Ω power, dBm and the reference difference.',
  '用于 LC/RLC 电路的基础谐振频率估算，输出角频率、周期、谐振点电抗；填写 ESR 后追加串联 Q 值、3dB 带宽和半功率点。': 'Basic resonant-frequency estimation for LC/RLC circuits, giving the angular frequency, the period and the reactance at resonance; fill ESR for the series Q, 3dB bandwidth and half-power points.',
  '适用于常见 Buck/Boost 芯片反馈分压估算，并输出反馈电流、电阻功耗、目标输出电压偏差和目标反馈电流所需电阻。': 'For the feedback divider of common Buck/Boost chips: gives the feedback current, resistor dissipation, the target output voltage deviation, and the resistance a target feedback current needs.',
  '用于 LDO 压差余量、静态电流损耗、效率、结温、热余量、最高环境温度、热阻上限和热限电流估算。': 'Estimates an LDO\'s dropout headroom, quiescent loss, efficiency, junction temperature, thermal margin, maximum ambient, thermal-resistance ceiling and thermally limited current.',
  '输出指定时间的充放电电压、充电比例、电流、电荷、储能和常用时间节点，并可按目标电压或目标充电比例反推所需时间。': 'Gives the charge / discharge voltage, charge fraction, current, charge, stored energy and common time marks at a given time, and back-solves the time a target voltage or charge fraction needs.',
  '按容量、平均电流、标称电压、效率和保留余量估算续航，并反推目标续航所需容量与允许平均电流。': 'Estimates runtime from capacity, average current, nominal voltage, efficiency and reserve, and back-solves the capacity and the allowable average current a target runtime needs.',
  '外层铜箔 IPC-2221 近似估算，可用层位置系数做内层降额，并反推目标电流所需线宽和余量。': 'An IPC-2221 approximation for outer-layer copper, with a layer factor for inner-layer derating and a back-solve for the trace width and margin a target current needs.',
  '按导线电阻率、往返回路、并联根数和目标压降估算压降、线损、负载端电压、所需截面积和允许电流。': 'Estimates the drop, line loss, load-end voltage, the area needed and the allowable current from the resistivity, the return path, the number of parallel wires and the target drop.',
  '555 无稳态振荡器常用估算，输出周期、高低电平时间和占空比，并可按目标频率/占空比在当前电容下反推 RA/RB。': 'The usual 555 astable estimates: period, high and low times and duty cycle, with a back-solve for RA/RB at the current capacitor from a target frequency / duty cycle.',
  '用于器件结温、温升、热余量、允许功耗、可配置降额功耗、最大环境温度、目标结温和目标热余量反推。': 'Junction temperature, rise, thermal margin, allowable dissipation, configurable derated dissipation and maximum ambient, plus back-solves from a target junction temperature or thermal margin.',
  '外啮合单级齿轮旋转方向相反，并估算输出转速、输出扭矩、输入/输出功率和效率损耗；填写目标输出转速后可反推目标传动比和保留其中一侧齿数时的另一侧齿数。': 'A single external gear pair turns the opposite way; estimates the output speed, output torque, input / output power and efficiency loss; fill the target output speed to back-solve the ratio and the other gear\'s tooth count while keeping one side.',
  '机械传动中常用的功率、转速、扭矩关系，并输出角速度、马力、功率方向和 1kW 所需扭矩；填写目标功率后可反推所需扭矩或转速。': 'The usual power, speed and torque relations of a drive: angular speed, horsepower, power direction and the torque 1kW needs; fill the target power to back-solve the torque or speed.',
  '用于线性弹簧的载荷、储能、柔度、等效重量和变形方向估算；填写目标力或目标储能后可反推所需变形量。': 'Load, stored energy, compliance, equivalent weight and deflection direction for a linear spring; fill the target force or energy to back-solve the deflection it needs.',
  '输出推出力、拉回力、等效重量、活塞面积、杆侧有效面积和拉力比例；填写目标推出力后可反推所需气压或缸径。': 'Gives the push force, pull force, equivalent weight, piston area, rod-side area and pull ratio; fill the target push force to back-solve the pressure or bore it needs.',
  '输出惯性力、力幅值、等效重量、g 值、质量重量和加速度方向；填写目标力后可反推所需加速度或质量。': 'Gives the inertial force, force magnitude, equivalent weight, g value, mass weight and acceleration direction; fill the target force to back-solve the acceleration or mass it needs.',
  '忽略打滑时估算输出转速、速度比、传动比、角速度、皮带线速度和开口皮带转向；填写目标输出转速后可反推轮径。': 'Without slip: estimates the output speed, speed ratio, drive ratio, angular speed, belt speed and open-belt direction; fill the target output speed to back-solve the pulley diameter.',
  '输出线速度、每秒位移、每转位移、每毫米转数、rps、小时行程和运动方向；填写目标线速度后可反推转速或导程。': 'Gives the linear speed, travel per second, travel per turn, turns per mm, rps, travel per hour and direction; fill the target speed to back-solve the speed or lead.',
  '用于液压、气动和压强估算，输出 N/kN、kgf、bar、面积换算和单位面积载荷；填写目标作用力后可反推所需压力或面积。': 'For hydraulic, pneumatic and pressure estimation: N/kN, kgf, bar, area conversion and load per unit area; fill the target force to back-solve the pressure or area it needs.',
  '输出静/动摩擦力、法向等效重量、摩擦角、最大可平衡坡角和等效坡度。': 'Gives the static / kinetic friction, the normal equivalent weight, the friction angle, the steepest slope it can hold and the equivalent grade.',
  '输出沿斜面分力、法向力、摩擦上限、净下滑力、坡度、摩擦角和滑动状态。': 'Gives the along-slope component, normal force, friction limit, net downhill force, slope, friction angle and whether it slides.',
  '简支梁中央集中载荷的基础估算，输出挠度、挠度幅值、弯矩、支座反力、等效刚度、跨度挠度比和 EI；填写目标挠度后可估算允许载荷、所需惯性矩或弹性模量。': 'Basic centre point-load estimation for a simply supported beam: deflection, deflection magnitude, bending moment, support reactions, equivalent stiffness, span / deflection ratio and EI; fill the target deflection to estimate the allowable load, the inertia or the modulus it needs.',
  '输出工程应力、应力幅值、弹性应变、微应变、每米变形、截面积和拉压载荷类型。': 'Gives engineering stress, stress magnitude, elastic strain, microstrain, deformation per metre, section area and whether the load is tension or compression.',
  '用于材料重量、应力、梁弯曲和流通截面的基础计算；输出圆/管/矩形面积、惯性矩、截面模量、回转半径、管壁厚、空心率和矩形强弱轴。': 'Basic section maths for material weight, stress, beam bending and flow: circle / pipe / rectangle area, moment of inertia, section modulus, radius of gyration, wall thickness, hollowness and the rectangle\'s strong and weak axes.',
  '输出安全系数、强度余量、余量比例、工作应力幅值、许用强度和常用设计判断；填写目标安全系数后可反推所需强度或许用应力。': 'Gives the safety factor, strength margin, margin ratio, working stress magnitude, allowable strength and the usual design verdict; fill the target factor to back-solve the strength or allowable stress it needs.',
  '用于水路、气路和液压管径初选，输出平均流速、截面积、m³/h、m³/s、雷诺数和 20℃ 水流态。': 'For first-pass pipe sizing in water, air and hydraulic lines: mean velocity, area, m³/h, m³/s, Reynolds number and the flow regime of 20℃ water.',
  '适合钢板、铝板、塑料板等矩形材料估重，输出 kg/lb/N、体积、表面积和面密度。': 'Weight estimation for rectangular stock such as steel, aluminium and plastic plate: kg/lb/N, volume, surface area and area density.',
  '贷款金额、年利率、贷款年限和目标月供任意填写三项，可正算月供或反推可贷金额/年利率，并输出总利息、首月拆分、利息占本金、年还款额和目标差值。': 'Fill any three of loan amount, annual rate, term and target payment to compute the payment or back-solve the amount / rate, with the total interest, the first-month split, the interest as a share of principal, the annual repayment and the target difference.',
  '每期投入、年化收益、年限和目标终值任意填写三项，可正算终值或反推每期投入/年化收益，并输出累计投入、收益、期数、每期收益率和目标差值。': 'Fill any three of payment, annual return, years and target value to compute the value or back-solve the payment / return, with the total paid in, the gain, the period count, the per-period return and the target difference.',
  '商品价格、总手续费率、分期期数和目标每期任意填写三项，可正算每期付款或反推可承受价格/手续费率，并输出本金拆分、手续费、总支付和目标差值。': 'Fill any three of price, total fee rate, instalment count and target payment to compute the payment or back-solve the price / fee rate, with the principal split, the fee, the total paid and the target difference.',
  '固定成本、单价、单位变动成本和目标销量任意填写三项即可反推第四项，输出平衡销量、边际贡献、边际率、平衡销售额、平衡变动成本和目标差值。': 'Fill any three of fixed cost, unit price, unit variable cost and sales target and the fourth is back-solved, with the break-even quantity, contribution margin, margin ratio, break-even revenue, break-even variable cost and the target difference.',
  '功率、每日使用、天数、电价和目标费用任意填写四项即可反推缺失项，输出费用、用电量、日均费用、日均用电、月化费用、年化费用和目标差值。': 'Fill any four of power, hours per day, days, tariff and target cost and the missing one is back-solved, with the cost, energy used, daily cost, daily energy, monthly and yearly cost and the target difference.',
  '本金、年化收益、年限和目标终值任意填写三项即可反推第四项，输出收益、收益率、增长倍数、年化收益率和目标差值。': 'Fill any three of principal, annual return, years and target value and the fourth is back-solved, with the gain, return rate, growth multiple, annualised return and the target difference.',
  '成本、售价、目标毛利率和目标利润填写足够两项即可反推缺失项，输出加价率、成本占比、保本售价、盈利状态和参考差值。': 'Fill enough of cost, price, target margin and target profit (any two) and the missing ones are back-solved, with the markup, cost share, break-even price, profit state and reference difference.',
  '收益、投入和 ROI 任意填写两项即可反推第三项，输出净收益、回报倍数和回本率；填写持有年限后追加年化 ROI、月均净收益和简单回收期。': 'Fill any two of gain, cost and ROI and the third is back-solved, with the net gain, return multiple and payback rate; add holding years for the annualised ROI, the monthly net gain and the simple payback period.',
  '原价、折扣和到手价任意填写两项即可反推第三项，同时输出节省金额、优惠比例和每百元支付金额。': 'Fill any two of original price, discount and final price and the third is back-solved, along with the amount saved, the discount ratio and the payment per 100.',
  '税前金额、税率和含税金额任意填写两项即可反推第三项，输出税额、税负率、价税倍率和参考差值。': 'Fill any two of net amount, tax rate and gross amount and the third is back-solved, with the tax, the tax burden ratio, the gross / net multiple and the reference difference.',
  '当前金额、年通胀率、年数和未来等值任意填写三项即可反推第四项，输出购买力折现、累计涨幅、购买力损失和参考差值。': 'Fill any three of current amount, inflation rate, years and future value and the fourth is back-solved, with the purchasing-power discount, the cumulative rise, the purchasing-power loss and the reference difference.',
  '支持最多 5 期现金流，空白可选期会被忽略，输出净现值、折现现金流、盈利指数、回收差额、折现回收期和折现率敏感性。': 'Takes up to 5 cash flows and ignores blank optional periods, giving the net present value, the discounted cash flows, the profitability index, the payback gap, the discounted payback period and the discount-rate sensitivity.',
  '支持工程常用单位快速换算。': 'Quick conversion between the units engineers use.',
  '速度、时间、距离任意填写两项即可反推第三项；输出米/公里、m/s、km/h、时间换算、配速和输入来源。': 'Fill any two of speed, time and distance and the third is back-solved; gives metres / kilometres, m/s, km/h, the time conversion, the pace and where the value came from.',
  '忽略空气阻力时的竖直下落估算，支持向下初速度；填写质量后追加势能变化、末端动能和冲击能量，填写缓冲距离后估算平均冲击力。': 'Vertical fall ignoring air resistance, with a downward initial speed; mass adds the potential-energy change, the terminal kinetic energy and the impact energy, and a buffer distance estimates the mean impact force.',
  '用于机械做功和平均功率快速计算，支持力-位移夹角和效率，输出有效功、输入功率、损耗、Wh/kWh、马力和做功方向；填写目标功率后可反推时间或力。': 'Quick mechanical work and average power, with a force-displacement angle and efficiency: useful work, input power, loss, Wh/kWh, horsepower and the work direction; fill the target power to back-solve the time or force.',
  '输出动能、势能、总机械能、速度幅值、单位质量动能和等效高度；填写目标总能量后可反推所需速度或高度。': 'Gives the kinetic energy, potential energy, total mechanical energy, speed magnitude, energy per unit mass and equivalent height; fill the target energy to back-solve the speed or height it needs.',
  '质量、体积、密度任意填写两项即可反推第三项，并输出 kg/m³、g/cm³、kg/L、比容和体积换算。': 'Fill any two of mass, volume and density and the third is back-solved, along with kg/m³, g/cm³, kg/L, specific volume and the volume conversion.',
  '支持用溶质量、体积、质量浓度或摩尔浓度互相反推；有摩尔质量时输出 mol/L、物质的量和差值校核。': 'Back-solves between solute mass, volume, mass concentration and molarity; with a molar mass it gives mol/L, the amount of substance and a difference check.',
  '压力、体积、物质的量和温度任意填写三项即可反推第四项；使用 R=8.314 J/(mol·K)，体积按 L 输入，压力按 kPa 输入。': 'Fill any three of pressure, volume, amount of substance and temperature and the fourth is back-solved; uses R=8.314 J/(mol·K), with volume in L and pressure in kPa.',
  '质量、比热容、温度变化和热量任意填写三项即可反推第四项，并输出 J、kJ、Wh、kcal 和吸放热状态。': 'Fill any three of mass, specific heat, temperature change and heat and the fourth is back-solved, along with J, kJ, Wh, kcal and whether heat is absorbed or released.',
  '波速、频率和波长任意填写两项即可反推第三项，输出周期、频率单位、波数和角频率。': 'Fill any two of wave speed, frequency and wavelength and the third is back-solved, with the period, the frequency unit, the wavenumber and the angular frequency.',
  '支持用初始量、半衰期、经过时间、剩余量或剩余比例反推，输出剩余、衰减、经历半衰期和衰变常数。': 'Back-solves from the initial amount, half-life, elapsed time, remaining amount or remaining ratio, and gives the remainder, the decay, the half-lives elapsed and the decay constant.',
  '可从 pH、[H+] 或 [OH-] 任一入口估算，其它字段留空即可；按 25℃ 水的 Kw=1e-14 输出 pH、pOH、[H+]、[OH-] 和酸碱性，填写目标pH后追加目标浓度和偏差。': 'Start from pH, [H+] or [OH-] and leave the others blank; at the 25℃ Kw=1e-14 of water it gives pH, pOH, [H+], [OH-] and whether the solution is acidic or basic, and a target pH adds the target concentration and the deviation.',
  '输出 BMI、常见区间、健康体重范围、目标体重差、腰高比和 Mosteller 体表面积；腰围可留空。': 'Gives the BMI, the common bands, the healthy weight range, the target weight gap, the waist-to-height ratio and the Mosteller body surface area; waist may be left blank.',
  '里程、燃油和百公里油耗任意填写两项即可反推第三项，输出 km/L、成本、油箱续航、年油费和排放粗估。': 'Fill any two of distance, fuel and consumption per 100 km and the third is back-solved, with km/L, cost, tank range, the annual fuel cost and a rough emissions estimate.',
  '支持 0x、#、h、0b、b、0o、o 与全角数字输入。': 'Accepts 0x, #, h, 0b, b, 0o, o and full-width digit input.',
  '支持秒/毫秒时间戳、小数秒、ISO、本地和中文日期时间。': 'Accepts second / millisecond timestamps, fractional seconds, ISO, local and Chinese date-time input.',
  '支持两个日期的间隔、单日期加减天数、今天起算，并给出星期、年内天数与 ISO 周。':
      'Spans between two dates, or a date plus or minus days, counted from today too, with weekday, day of year and ISO week.',
  '输入若干「值 ± 不确定度」，给出和与差的合成不确定度、积与商的相对不确定度，以及哪一项是主要误差来源。':
      'Enter value ± uncertainty pairs for the combined uncertainty of a sum or difference, the relative uncertainty of a product or quotient, and which term dominates.',
  '支持 HEX、RGB/RGBA、HSL/HSLA 和常用 CSS 命名色。': 'Accepts HEX, RGB/RGBA, HSL/HSLA and the common CSS colour names.',
  '自动识别普通文本、Base64、Base64URL 和 data URL，输出标准/Base64URL/data URL 可复制格式。': 'Recognises plain text, Base64, Base64URL and data URLs and gives copyable standard/Base64URL/data URL forms.',
  '自动识别完整 URL、query string 和 URL 组件，输出长度变化、百分号片段和 query 参数数量。': 'Recognises whole URLs, query strings and URL components and gives the length change, the percent-encoded parts and the query parameter count.',
  '输入 JSON 或 JSON Lines，输出格式化结果和结构摘要。': 'Enter JSON or JSON Lines for a formatted result and a structure summary.',
  '输出码点、UTF-16、UTF-32、UTF-8、HTML 实体和字符分类，并支持 U+ 与 \\u 反查。': 'Gives the code point, UTF-16, UTF-32, UTF-8, HTML entity and character class, and reverse-looks-up U+ and \\u.',
  '输入两个整数或 A/B 标签，输出常用位运算结果。': 'Enter two integers or A/B labels for the usual bitwise results.',
  '支持 UTF-8 文本和十六进制字节，输出 SUM8、XOR8、LRC。': 'Accepts UTF-8 text and hex bytes and gives SUM8, XOR8 and LRC.',
  '留空生成随机 UUID v4，粘贴 UUID 可标准化并识别版本与 variant。': 'Empty generates a random UUID v4; a pasted UUID is normalised and its version and variant identified.',
  '离线解码 Header/Payload，校核 claims 时间但不验证签名。': 'Decodes the Header/Payload offline and checks the claims\' times without verifying the signature.',
  '解析 URL 或 query string，输出键值表和 JSON。': 'Parses a URL or query string and gives the key-value table and JSON.',
  '支持常见命名实体、十进制和十六进制数字实体。': 'Accepts the common named entities plus decimal and hexadecimal numeric entities.',
  '第一行输入正则，后续输入测试文本，输出匹配位置。': 'The first line is the pattern and the following lines the test text; gives the match positions.',
  '统计字符、段落、UTF-8 字节和中英文/数字/标点分布。': 'Counts characters, paragraphs, UTF-8 bytes and the Chinese / Latin / digit / punctuation split.',
  '支持逗号、Tab、分号和竖线分隔，首行作为表头。': 'Accepts comma, Tab, semicolon and pipe separation, with the first row as the header.',
  '支持 UTF-8 文本和十六进制字节的 FNV-1a/CRC32。': 'FNV-1a/CRC32 over UTF-8 text and hexadecimal bytes.',
  '支持 a、b、c 三个变量和常用数学函数。': 'Supports the a, b and c variables and the usual mathematical functions.',
};
