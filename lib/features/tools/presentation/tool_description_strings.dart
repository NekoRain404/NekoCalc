/// 中文：**工具目录的描述表**——117 条 `tool.description` 的两种语言。
///
///       **机制本身不在这里重抄。** 为什么是手写分表而不是 ARB / `gen-l10n`、为什么**兄弟表**
///       （`settings_strings.dart`）是 `static final`，都写在设置页那张表的文件头上；本文件的两张表
///       是**顶层 `const` Map**而不是一个类，理由见下一条。
///
///       **为什么另起一个文件，而不是并进 `tool_catalog_strings.dart`。** 那条线是**行数硬线**：
///       `tool_catalog_strings.dart` 本轮开始时是 **684 行**，再塞进 117×2 条描述（每条一行、还要带
///       注释）会直接冲过八百行。这与 `data_fit_strings.dart` 当初从 `tools_strings.dart` 里切出来的
///       理由是同一个。**切分判据是"一屏看得完"，不是"一个屏幕一张"**：描述与名字是同一张表的两个
///       字段，不该按屏幕切。
///
///       **挂在 `ToolCatalogStrings` 上，而不是另立一张有自己 `of` 的表。** 一个工具的名字与描述
///       出现在**同一张卡片上**（`ToolListTile` 的 title 与 subtitle），两处必须取自**同一次**
///       `ToolCatalogStrings.of(context)`——两张表就有两个 switch、两个 `BuildContext` 查询，
///       语言分叉时屏幕会出现「英文名 + 中文描述」。回落也只有一条：认不出的 id 回落到
///       `toolById(id)?.description`，也就是今天屏幕上的那句中文，所以**默认态连"表漏一条"都改不动**
///       （英文下这种漏会以中文的样子露出来，同时测试已经红了）——与 [ToolCatalogStrings.toolName]
///       那条完全同形。
///
///       ⚠️ **这 117 条英文没有一条是"提升"来的，全部是**本轮新写的**。** 上一轮的名字有出处：
///       99 条能在 `tool_search_aliases_{a,b,c}.dart` 与 `tool_search_data.dart` 两处检索索引里
///       找到已经提交的同义英文。**描述没有这样一份索引**——两处索引里没有任何一处存过描述，
///       `tool.description` 本身也只有中文一份。所以这一轮**没有可对照的东西**：
///       `.superpowers/backup/tool-descriptions-report.md` 里那张逐条对照表是它唯一的复核面。
///
///       **长度是有规矩的，而且量过。** 卡片上那一格（`ToolListTile` 的 subtitle）在 360dp 手机上
///       只有 **162dp** 宽（分类页 170dp、"其它分类"那张面板 140dp），一个汉字约 14dp、一个小写拉丁
///       字母约 7.4dp，所以**中文比英文宽得多**——本表落地时它还是 `maxLines: 1`，**117 条中文里
///       只有 23 条完整显示**，其余 94 条在省略号处截断（`齿轮传动比、转速、扭矩和功率损耗` 就是
///       这么被截成 `齿轮传动比、转速、扭矩和功…` 的）。**那一轮之后，卡片改成让说明换行**
///       （`toolDescriptionMaxLines`，见 `tool_widgets.dart`）：今天两种语言的 117 条在四种表面、
///       两种状态下都完整显示，一个字的文案都没动。
///
///       规矩仍然是这一条，因为它管的是**宽度**——英文比中文宽出去的那一截，最终要从行数里出：
///
///           **英文字串宽 ≤ max(中文字串宽, 162dp)**
///
///       也就是两句话：中文**本来就被截断**的那些，英文**不许比它更早截断**；中文**本来读得全**的
///       那些，英文**也必须读得全**。宽度用真 Roboto-Regular 的逐字符 advance 表量（尺子在
///       `test/shared/roboto_regular_advances.dart`，与命中提示那条护栏共用一把）。实测结果：
///       **英文 117 条一条都不违反**，其中 **42 条完整落在 162dp 那一行之内**——中文只有 23 条。
///       换句话说英文那 42 条一行读得全，剩下 75 条与中文一样要换行（换行之后两种语言都读得全），
///       但**没有一条比中文占得宽**。逐条的字数、屏上宽度、以及 11 条"比中文宽、但仍完整落在一行内"
///       的例外，都在上面那份报告里。
///
///       **数学记号逐字符活着，而且是机器查的。** 中文描述里带着与语言无关的记号——`ax² + bx + c = 0`、
///       `x^y`、`y^x`、`a:b = c:x`、`2x2`、`A(n,k)`、`PV=nRT`、`V/I/R/P`、`50Ω`、`kN·m`、`℃`/`℉`/`°R`、
///       每一张单位符号表。`tool_description_strings_test.dart` 把中文**按 CJK 与全角断开**，凡是
///       **非 CJK 的那一段**（含空格，去掉纯 ASCII 标点段）都必须在英文里**原样找得到**——
///       这条断言不认任何一张手写清单，改中文时它会自己跟着变。
///
///       **检索一个字节都没动。** `tool.description` 这个字段**仍然只有中文那一条**，
///       `ToolSearch.rankTool`（76 分那一档）、`searchAliases`（把描述前插成别名）与 `tokenMatch`
///       读的还是它，所以命中的字符串、分数与排序与改动前逐条相同；**中文描述照旧被检索**。
///       本表只被**显示**读，不参与匹配、不落库（写笔记时那三处 `description: tool.description`
///       是持久化，本轮一行未动）。
/// English: **the tools catalogue's description table** — the two languages of all 117
///          `tool.description` strings.
///
///          **The mechanism is not copied here.** Why hand-written tables rather than ARB /
///          `gen-l10n`, and why the sibling table (`settings_strings.dart`) is `static final`, are on
///          the settings table's file head. Why this file's two tables are **top-level `const` maps**
///          rather than a class is the next point.
///
///          **Why its own file rather than part of `tool_catalog_strings.dart`.** That line is the
///          **line-count limit**: `tool_catalog_strings.dart` stood at **684 lines** when this round
///          began, and 117 × 2 more entries (one line each, comments on top) would cross 800. This is
///          the same reason `data_fit_strings.dart` was split out of `tools_strings.dart`.
///          **The split is judged by "readable in one screen", not by "one table per screen"**:
///          descriptions and names are two fields of one table and must not be split by screen.
///
///          **It hangs off `ToolCatalogStrings` instead of becoming a second table with its own
///          `of`.** A tool's name and its description appear **on the same card** (`ToolListTile`'s
///          title and subtitle), so both must come from **one** `ToolCatalogStrings.of(context)`
///          call — two tables mean two switches and two `BuildContext` lookups, and a language split
///          puts an English name over a Chinese description. The fallback is single too: an
///          unrecognised id falls back to `toolById(id)?.description`, the Chinese on screen today, so
///          **the default state cannot move even if the table misses an entry** (in English such a
///          miss shows up as Chinese while the test is already red) — exactly the shape of
///          [ToolCatalogStrings.toolName].
///
///          ⚠️ **Not one of these 117 English lines is promoted; every one is authored this round.**
///          The names had a source: 99 of them were English the repository had already committed, in
///          the two search indexes (`tool_search_aliases_{a,b,c}.dart` and `tool_search_data.dart`).
///          **Descriptions have no such index** — neither index has ever held a description, and
///          `tool.description` itself exists only in Chinese. So this round **has nothing to check
///          against**: the entry-by-entry table in `.superpowers/backup/tool-descriptions-report.md`
///          is its only review surface.
///
///          **Length is a rule, and it was measured.** The card's cell (`ToolListTile`'s subtitle) is
///          only **162dp** wide on a 360dp phone (170dp on the category page, 140dp in the "other
///          categories" panel); one CJK glyph is about 14dp and one lowercase Latin letter about 7.4dp,
///          so **the Chinese runs far wider than the English** — when this table landed the cell was
///          still `maxLines: 1`, and **only 23 of the 117 Chinese entries rendered in full**; the other
///          94 stopped at the ellipsis (`齿轮传动比、转速、扭矩和功率损耗` is cut to
///          `齿轮传动比、转速、扭矩和功…` that way). **Since that round the card lets the description
///          wrap** (`toolDescriptionMaxLines`, see `tool_widgets.dart`): today all 117 render in full in
///          both languages, on all four surfaces and in both states, with not one word of copy changed.
///
///          The rule still stands because it governs **width** — whatever the English is wider by has to
///          come out of the line count:
///
///              **English width ≤ max(Chinese width, 162dp)**
///
///          Two sentences: where the Chinese **is already truncated**, the English **may not truncate
///          earlier**; where the Chinese **reads in full**, the English **must read in full too**.
///          Widths come from real Roboto-Regular per-character advances (the ruler lives in
///          `test/shared/roboto_regular_advances.dart`, shared with the match-hint guard). Measured:
///          **not one of the 117 English lines violates it**, and **42 of them fit the 162dp line
///          entirely** — against 23 for Chinese. Those 42 read in a single line; the remaining 75 wrap
///          like their Chinese (and both languages read in full once wrapped), but **not one of them
///          takes more width than its Chinese**. Per-line character counts, on-screen widths and the 11
///          exceptions ("wider than the Chinese yet still wholly inside one line") are in that report.
///
///          **The mathematical notation survives character for character, and a machine checks it.**
///          The Chinese carries notation that is language-neutral — `ax² + bx + c = 0`, `x^y`, `y^x`,
///          `a:b = c:x`, `2x2`, `A(n,k)`, `PV=nRT`, `V/I/R/P`, `50Ω`, `kN·m`, `℃`/`℉`/`°R`, every unit
///          symbol list. `tool_description_strings_test.dart` cuts the Chinese **at CJK and full-width
///          boundaries** and requires every **non-CJK run** (spaces trimmed, ASCII-punctuation-only
///          runs dropped) to be found **verbatim** in the English — an assertion that consults no
///          hand-written list and follows the Chinese by itself.
///
///          **Search is untouched, byte for byte.** `tool.description` **still holds the Chinese
///          alone**; `ToolSearch.rankTool` (its 76-point slot), `searchAliases` (which prepends the
///          description as an alias) and `tokenMatch` still read it, so the matched strings, the scores
///          and the ordering are line-for-line what they were, and **the Chinese description is still
///          searched**. This table is read by **display** only: it does not take part in matching and is
///          persisted nowhere (the three `description: tool.description` sites that save a note are
///          storage, and not one line of them moved).
library;

/// 中文：工具 id → 描述，中文。**逐条写出来，与 `tool_catalog*.dart` 里的 `description` 逐字节相同**，
///       `tool_description_strings_test.dart` 拿 `toolCatalog` 在**运行期**逐条钉住——
///       认不出的 id 在 `ToolCatalogStrings.toolDescription` 处回落到目录里那一条，理由见文件头。
/// English: tool id → description, Chinese. **Written out entry by entry, byte-identical to the
///          `description` fields in `tool_catalog*.dart`**; `tool_description_strings_test.dart` pins
///          them against `toolCatalog` at **run time**. An unrecognised id falls back to that entry in
///          the catalogue inside `ToolCatalogStrings.toolDescription` — see the file head.
const Map<String, String> toolDescriptionsZh = {
      'quadratic': '求解 ax² + bx + c = 0 的根',
      'linear_system': '2x2 线性方程组、秩、残差和解类型',
      'percentage': '百分比计算与变化',
      'exponential_log': 'x^y、y^x、换底对数、根号和定义域',
      'linear_equation': '求解 ax + b = 0、退化类型和代回校验',
      'proportion': 'a:b = c:x 比例求值',
      'combination': 'A(n,k)、C(n,k)、阶乘、重复排列和比例',
      'probability': '独立事件概率组合',
      'statistics': '多样本均值、中位数、方差和标准差',
      'data_fit': '粘贴列表数据，生成趋势线、方程和拟合指标',
      'matrix': '2x2 矩阵行列式、逆矩阵、秩和特征值',
      'complex': '两个复数加减乘除、共轭、模长和幅角',
      'vector': '二维向量点积、叉积与夹角',
      'triangle': '三边求面积、周长和角度',
      'circle': '半径求面积、周长和直径',
      'scale_ratio': '按比例缩放长度和面积',
      'ohms_law': 'V/I/R/P、电导、公差和功率档位',
      'voltage_divider': 'Vin, R1, R2 → Vout，并估算负载、电流和功耗',
      'rc_filter': '高通 / 低通截止频率、时间常数和频带参考',
      'dbm': 'dBm、功率、50Ω 电压和分贝电压换算',
      'resistor_network': '两个电阻串联 / 并联等效与电导',
      'capacitor_network': '两个电容串联 / 并联等效',
      'inductor_network': '两个电感串联 / 并联等效',
      'led_resistor': '按电源、电压降和电流计算限流电阻',
      'op_amp_gain': '同相/反相增益、dB 和反馈网络估算',
      'adc_resolution': 'ADC LSB、码值和动态范围估算',
      'rms_peak': '正弦波 RMS、峰值、峰峰值、dBm 和 50Ω 功率互算',
      'lc_resonance': '电感电容谐振频率、周期和谐振电抗',
      'dcdc_feedback': '反馈分压、目标输出反推和反馈电流预算',
      'ldo_power': '线性稳压器压差、静态电流、热余量和电流限制',
      'capacitor_charge': 'RC 充放电、电流、储能和目标时间反推',
      'battery_life': '电池续航、目标容量、电流预算和放电倍率估算',
      'pcb_current': '按线宽、铜厚、温升和目标电流估算载流与线宽预算',
      'wire_voltage_drop': '线长、电流、线径和目标压降估算线损与线径预算',
      'timer_555': '无稳态频率、占空比和目标阻值反推',
      'thermal_rise': '功耗、热阻、结温、降额和目标余量预算',
      'gear_ratio': '齿轮传动比、转速、扭矩和功率损耗',
      'torque_power': '扭矩、转速、功率、马力和功率方向',
      'spring': '胡克定律、储能、柔度和等效重量',
      'cylinder': '气压、缸径、杆径和往返推力',
      'force': '牛顿第二定律、g 值和方向判断',
      'pulley_ratio': '直径比、转速、角速度和皮带线速度',
      'screw_lead': '导程、转速、进给速度和行程换算',
      'pressure_force': '压力、面积、作用力和等效重量',
      'friction': '摩擦力、摩擦角和等效坡度',
      'inclined_plane': '斜面分力、摩擦上限和滑动状态',
      'beam_bending': '简支梁挠度、弯矩、反力和刚度',
      'stress_strain': '轴向应力、应变、微应变和变形',
      'section_area': '圆、管、矩形面积、惯性矩、截面模量和回转半径',
      'safety_factor': '许用强度、工作应力、余量和判断',
      'flow_velocity': '流量、管径、流速和雷诺数',
      'material_weight': '板材重量、体积、表面积和面密度',
      'loan': '等额本息月供、首月拆分和利息占比',
      'annuity': '定投终值、累计投入、收益和期数',
      'installment': '商品分期每期付款、手续费和费率',
      'break_even': '固定成本、边际贡献和平衡销售额',
      'electricity_cost': '功率、时间、电价和长期运行成本',
      'compound': '计算终值、收益、收益率和增长倍数',
      'profit_margin': '成本、售价、利润率和盈利状态',
      'roi': '投资回报率、年化回报、回本率和净收益',
      'discount': '原价、折扣、节省金额与优惠比例',
      'tax': '税率、税额、含税金额和税负率',
      'inflation': '按年通胀率折算未来金额和购买力',
      'npv': '多期现金流净现值、盈利指数和回收期',
      'length': 'nm、μm、mm、cm、m、km、Mm、in、ft、mile 换算',
      'area': 'km²、ha、公顷、亩、m²、cm²、mm²、acre、ft²、in² 换算',
      'volume': 'm³、L、mL、cm³、mm³、gal、qt、pt、fl oz、ft³、in³ 换算',
      'mass': 'kg、g、mg、Mg、t、lb、oz、斤 换算',
      'pressure': 'mPa、Pa、kPa、MPa、GPa、bar、mbar、psi、atm 换算',
      'speed': 'm/s、km/h、mph、ft/s、m/min、cm/s、kn 换算',
      'temperature': '℃、℉、K、°R 换算',
      'voltage': 'μV、mV、V、kV、MV 换算',
      'frequency': 'mHz、Hz、kHz、MHz、GHz、THz 换算',
      'data_size': 'bit、B、KB/MB/GB 与 KiB/MiB/GiB 换算',
      'time_unit': 'ns、μs、ms、s、min、h、day、week 换算',
      'acceleration': 'm/s²、g、ft/s²、cm/s²、Gal 换算',
      'force_unit': 'mN、N、kN、MN、kgf、lbf 换算',
      'power_unit': 'mW、W、kW、MW、hp、dBm 换算',
      'energy_unit': 'J、kJ、cal、kcal、BTU、eV、Wh、kWh、MWh、度 换算',
      'angle_unit': 'deg、rad、turn、grad/gon、arcmin、arcsec 换算',
      'current_unit': 'nA、μA、mA、A、kA、MA 换算',
      'resistance_unit': 'μΩ、mΩ、Ω、kΩ、MΩ、GΩ 换算',
      'capacitance_unit': 'F、mF、μF、nF、pF、MF 换算',
      'inductance_unit': 'pH、nH、μH、mH、H、kH、MH 换算',
      'torque_unit': 'kN·m、N·m、mN·m、N·mm、kgf·cm、lbf·in、ozf·in 换算',
      'flow_unit': 'mL/min、L/min、L/h、L/s、m³/h、m³/min、m³/s、GPM、CFM 换算',
      'motion': '速度、时间、距离三选二互算和配速',
      'free_fall': '高度、初速度、落地时间、末速度和冲击能量',
      'work_power': '力、位移、夹角、效率、功和平均功率',
      'kinetic_energy': '质量、速度、高度、动能和势能',
      'density': '密度、质量、体积和比容关系',
      'concentration': '质量、体积、质量浓度和摩尔浓度',
      'ideal_gas': 'PV=nRT 压力、温度、体积和摩尔体积',
      'heat': '质量、比热容、温升和热量单位',
      'wavelength': '波速、频率、波长、周期和角频率',
      'half_life': '按半衰期估算剩余、衰减和衰变常数',
      'ph': 'pH、氢离子、氢氧根和酸碱性互算',
      'bmi': 'BMI、健康体重区间、腰高比和体表面积',
      'fuel_economy': '油耗、燃油成本、油箱续航和排放粗估',
      'base_convert': '二进制、八进制、十进制、十六进制转换',
      'prime_factor': '把一个整数分解成质因数',
      'arithmetic_steps': '把四则运算的运算顺序一步步写出来',
      'timestamp': 'Unix 时间戳与日期转换',
      'date_calc': '两个日期相差多少天、某个日期加减几天',
      'derive_steps': '把求导的每一步与所用法则写出来',
      'uncertainty': '多个测量值的合成不确定度与主要误差来源',
      'color_convert': 'RGB、HEX、HSL 颜色转换',
      'base64': 'Base64 编码解码',
      'url_codec': 'URL 编码与解码',
      'json_format': 'JSON 格式化与校验',
      'ascii_unicode': '字符码点查询',
      'bitwise': 'AND / OR / XOR / NOT 与移位',
      'checksum': '文本字节校验和',
      'uuid': '生成/校验 UUID',
      'jwt_decode': '解析 JWT Header / Payload',
      'query_params': 'URL 查询参数解析',
      'html_entities': 'HTML 实体编码解码',
      'regex_test': '正则匹配预览',
      'text_stats': '字符、词、行和字节统计',
      'csv_json': 'CSV / TSV 转 JSON',
      'fnv_crc': 'FNV-1a 与 CRC32 哈希',
      'custom_formula': '创建自己的公式工具',
};

/// 中文：工具 id → 描述，英文。**117 条全部是本轮新写的**（理由见文件头），长度按本文件头那条
///       「英文宽 ≤ max(中文宽, 162dp)」的规矩量过。
/// English: tool id → description, English. **All 117 are authored this round** (see the file head), and
///          every one was measured against the file head's rule, "English width ≤ max(Chinese width,
///          162dp)".
const Map<String, String> toolDescriptionsEn = {
      'quadratic': 'ax² + bx + c = 0 roots',
      'linear_system': '2x2 systems: rank, residual, type',
      'percentage': 'Percent of and change',
      'exponential_log': 'x^y, y^x, logs, roots, domain',
      'linear_equation': 'ax + b = 0, degenerate, check',
      'proportion': 'Solve a:b = c:x',
      'combination': 'A(n,k), C(n,k), factorial, repeats',
      'probability': 'Independent events',
      'statistics': 'Mean, median, variance and σ',
      'data_fit': 'Paste data: trend line, equation, fit',
      'matrix': '2x2 determinant, inverse, rank, λ',
      'complex': 'Conjugate, modulus, argument',
      'vector': '2D dot, cross and angle',
      'triangle': 'Area, perimeter, angles',
      'circle': 'Radius, area, perimeter',
      'scale_ratio': 'Scale length and area',
      'ohms_law': 'V/I/R/P, conductance, power',
      'voltage_divider': 'Vin, R1, R2 → Vout, load, current',
      'rc_filter': 'High/low-pass cutoff, time constant',
      'dbm': 'dBm, power, 50Ω voltage, dBV',
      'resistor_network': 'Two in series or parallel',
      'capacitor_network': 'Two in series or parallel',
      'inductor_network': 'Two in series or parallel',
      'led_resistor': 'Resistor from supply, drop, current',
      'op_amp_gain': 'Inverting/non-inverting gain, dB',
      'adc_resolution': 'ADC LSB, codes, range',
      'rms_peak': 'Sine RMS, peak, peak-to-peak, dBm, 50Ω',
      'lc_resonance': 'LC resonance: f, period, reactance',
      'dcdc_feedback': 'Divider, target output, bias current',
      'ldo_power': 'Dropout, quiescent current, thermal',
      'capacitor_charge': 'RC charge, current, energy, time',
      'battery_life': 'Runtime, capacity, budget, C-rate',
      'pcb_current': 'Trace width, copper, rise, current',
      'wire_voltage_drop': 'Run, current, gauge, drop and loss',
      'timer_555': 'Astable frequency, duty, resistor',
      'thermal_rise': 'Power, thermal resistance, junction',
      'gear_ratio': 'Gear ratio, speed, torque, loss',
      'torque_power': 'Torque, speed, power, horsepower',
      'spring': 'Hooke\'s law, energy, compliance',
      'cylinder': 'Bore, rod, pressure, force',
      'force': 'Newton\'s second law, g force',
      'pulley_ratio': 'Diameter ratio, rpm, belt speed',
      'screw_lead': 'Lead, speed, feed rate and travel',
      'pressure_force': 'Pressure, area, force, weight',
      'friction': 'Friction force, angle, slope',
      'inclined_plane': 'Components, friction, sliding',
      'beam_bending': 'Deflection, moment, reaction',
      'stress_strain': 'Stress, strain, deflection',
      'section_area': 'Circle, tube, rectangle: A, I, Z, r',
      'safety_factor': 'Allowable vs working stress',
      'flow_velocity': 'Flow, bore, Reynolds',
      'material_weight': 'Weight, volume, area, density',
      'loan': 'Monthly payment, interest split',
      'annuity': 'Future value, paid in, gain',
      'installment': 'Per-period payment, fees, rate',
      'break_even': 'Fixed cost, contribution margin',
      'electricity_cost': 'Power, hours, tariff, running cost',
      'compound': 'Future value, gain, rate, multiple',
      'profit_margin': 'Cost, price, margin and profit',
      'roi': 'ROI, annualised return, payback',
      'discount': 'List price, discount, saving, final',
      'tax': 'Rate, tax, gross price',
      'inflation': 'Future value, buying power',
      'npv': 'Net present value, PI, payback',
      'length': 'nm, μm, mm, cm, m, km, Mm, in, ft, mile',
      // 中文：`亩` 写成 `mu`——那是换算表自己收下的拉丁拼法（`tool_unit_conversion_units_core.dart`）。
      // English: `亩` is written `mu`, the Latin spelling the conversion table itself accepts (it is
      //          in `tool_unit_conversion_units_core.dart`).
      'area': 'km², ha, hectare, mu, m², cm², mm², acre, ft², in²',
      'volume': 'm³, L, mL, cm³, mm³, gal, qt, pt, fl oz, ft³, in³',
      // 中文：`斤` 在换算表里只有这一个拼法（没有 `jin` 别名），英文一侧按通行的拉丁拼法写作 `jin`。
      // English: `斤` has exactly one spelling in the conversion table (there is no `jin` alias); the
      //          English side writes it `jin`, the usual Latin spelling.
      'mass': 'kg, g, mg, Mg, t, lb, oz, jin',
      'pressure': 'mPa, Pa, kPa, MPa, GPa, bar, mbar, psi, atm',
      'speed': 'm/s, km/h, mph, ft/s, m/min, cm/s, kn',
      'temperature': '℃, ℉, K, °R',
      'voltage': 'μV, mV, V, kV, MV',
      'frequency': 'mHz, Hz, kHz, MHz, GHz, THz',
      'data_size': 'bit, B, KB/MB/GB, KiB/MiB/GiB',
      'time_unit': 'ns, μs, ms, s, min, h, day, week',
      'acceleration': 'm/s², g, ft/s², cm/s², Gal',
      'force_unit': 'mN, N, kN, MN, kgf, lbf',
      'power_unit': 'mW, W, kW, MW, hp, dBm',
      // 中文：`度` 在换算表里就是 `kWh` 的同义词，英文一侧只列一次。
      // English: `度` is a synonym of `kWh` in the conversion table, so the English side lists it once.
      'energy_unit': 'J, kJ, cal, kcal, BTU, eV, Wh, kWh, MWh',
      'angle_unit': 'deg, rad, turn, grad/gon, arcmin, arcsec',
      'current_unit': 'nA, μA, mA, A, kA, MA',
      'resistance_unit': 'μΩ, mΩ, Ω, kΩ, MΩ, GΩ',
      'capacitance_unit': 'F, mF, μF, nF, pF, MF',
      'inductance_unit': 'pH, nH, μH, mH, H, kH, MH',
      'torque_unit': 'kN·m, N·m, mN·m, N·mm, kgf·cm, lbf·in, ozf·in',
      'flow_unit': 'mL/min, L/min, L/h, L/s, m³/h, m³/min, m³/s, GPM, CFM',
      'motion': 'Speed, time, distance, pace',
      'free_fall': 'Height, initial speed, fall time, impact',
      'work_power': 'Force, distance, angle, work, power',
      'kinetic_energy': 'Mass, speed, height, energy',
      'density': 'Density, mass, volume',
      'concentration': 'Mass, volume, mass and molar',
      'ideal_gas': 'PV=nRT: P, T, V, moles',
      'heat': 'Mass, specific heat, rise',
      'wavelength': 'Speed, frequency, wavelength',
      'half_life': 'Remaining amount, decay',
      'ph': 'pH, hydrogen and hydroxide ions',
      'bmi': 'BMI, healthy weight range, waist ratio',
      'fuel_economy': 'Fuel use, cost, tank range, emissions',
      'base_convert': 'Binary, octal, decimal, hex',
      'prime_factor': 'An integer into its primes',
      'arithmetic_steps': 'Arithmetic, one step at a time',
      'timestamp': 'Unix time and date',
      'date_calc': 'Days between dates, or add days',
      'derive_steps': 'Derivative steps, rule by rule',
      'uncertainty': 'Combined measurement uncertainty',
      'color_convert': 'RGB, HEX and HSL colour',
      'base64': 'Base64 encode / decode',
      'url_codec': 'URL encode / decode',
      'json_format': 'JSON format / validate',
      'ascii_unicode': 'Character code points',
      'bitwise': 'AND / OR / XOR / NOT, shifts',
      'checksum': 'Text / byte checksums',
      'uuid': 'Create or check UUIDs',
      'jwt_decode': 'JWT Header / Payload',
      'query_params': 'URL query parameters',
      'html_entities': 'HTML entity codec',
      'regex_test': 'Match preview',
      'text_stats': 'Char, word, line, byte',
      'csv_json': 'CSV / TSV to JSON',
      'fnv_crc': 'FNV-1a and CRC32',
      'custom_formula': 'Your own formula tool',
};
