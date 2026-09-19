/// 中文：**工具目录的输入卡表**——`input.label`（231 条）与 `input.unit`（11 条）的英文。
///
///       **机制（键是中文本身、中文那一侧没有表、回落是 `?? 键`）与三张表为什么分成三个文件，
///       写在 `tool_field_strings.dart` 的文件头上，这里不重抄。** 本文件只有一句自己的话：
///       **这两格是"输入卡"这一处表面的两半**——左边那列文字与输入框右侧那个后缀，
///       同一行里并排出现，所以放在同一张表、同一个文件里。
///
///       逐条量过的规模：`input.label` 在目录里 **346 处**，其中 **231** 个不同字串带汉字
///       （另外 **46** 个是 `a`、`pH`、`ROI`、`Vpp`、`50Ω dBm` 这类本来就是拉丁字母的，
///       **两种语言逐字节相同，所以一条都不进表**）；`input.unit` **288 处**，
///       只有 **11** 个不同值带汉字（`元`、`天`、`年`、`万元`、`元/kWh`…），
///       其余 65 个是 `Ω`、`nF`、`m/s²`、`℃/W` 这种记号，同样一条都不进表。
///
///       **单位那 11 条是"钱与计数"，不是物理单位。** 物理单位（V、A、kΩ、nF、rpm、N·m…）
///       在两种语言里本来就是同一个符号串，一个都没动；进表的只有中文特有的计钱与计数词：
///       `元`→`¥`、`万元`→`10k ¥`、`元/kWh`→`¥/kWh`、`元/L`→`¥/L`、`件`/`根`→`pcs`、
///       `齿`→`teeth`、`天`→`days`、`年`→`years`、`期`→`periods`，以及 `倍`（增益的"倍"）→`×`。
///       `kWh`/`L` 那种斜杠写法照原样留着（中文里 `元/kWh` 的那一段非 CJK 记号是 `/kWh`，
///       英文必须原样含它）。
///
///       ⚠️ **`¥` 而不是 `CNY`，是被那一格量出来的，不是口味。** 单位是输入框**里面**的
///       `suffixText`，实测框宽 118.9dp，而中文那两条最长的 `元/kWh`（61.3dp）留给数字 50.4dp、
///       `元/L` 更宽裕。先写的 `CNY/kWh`（72.7dp）在真字体下把同一个输入框的**可编辑区从 50.4dp
///       压到 0.9dp**——数字几乎没地方站了。换成 `¥/kWh`（55.9dp）之后，这两条英文比它们的中文
///       **还窄**，数字那一侧的余量反而比改动前更宽松。`¥` 在 Roboto 与 Noto Sans SC 里都有字形
///       （`U+00A5`，本轮查过两张字体表），所以不是靠回退才画得出来的。
///
///       **长度**：标签那一格 89.1dp（量法与判据写在 `tool_field_strings.dart` 头上与测试里），
///       单位那一格在输入框内、可用宽度 **118.9dp**；这 11 条里最宽的英文是 `periods`（56.6dp），
///       最宽的中文是 `元/kWh`（56.2dp）——**两种语言在这一格上基本齐平（差 0.4dp）**，
///       也都只用掉输入框的一半，所以单位这一侧不存在长度问题。
/// English: **the tools catalogue's input-card table** — the English of `input.label` (231) and
///          `input.unit` (11).
///
///          **The mechanism (the key is the Chinese itself, there is no Chinese-side table, the
///          fallback is `?? key`) and why the tables live in three files are on
///          `tool_field_strings.dart`'s head and are not copied here.** This file has one thing of its
///          own to say: **these two fields are the two halves of one surface, the input card** — the
///          text in the left column and the suffix inside the field, side by side on the same row, so
///          they share one table and one file.
///
///          Measured: `input.label` occurs **346** times, **231** distinct strings holding a Han
///          character (the other **46** are `a`, `pH`, `ROI`, `Vpp`, `50Ω dBm` and the like — already
///          Latin, **byte-identical in both languages, so not one enters the table**); `input.unit`
///          occurs **288** times with only **11** distinct Han-bearing values (`元`, `天`, `年`,
///          `万元`, `元/kWh`, …), the other 65 distinct values being notation such as `Ω`, `nF`,
///          `m/s²`, `℃/W`, which likewise stay out.
///
///          **Those 11 units are money and counts, not physical units.** Physical units (V, A, kΩ, nF,
///          rpm, N·m, …) are the same symbol string in both languages and none of them moved; what
///          enters the table is what only Chinese spells out: `元`→`¥`, `万元`→`10k ¥`,
///          `元/kWh`→`¥/kWh`, `元/L`→`¥/L`, `件`/`根`→`pcs`, `齿`→`teeth`, `天`→`days`,
///          `年`→`years`, `期`→`periods`, and `倍` (a gain in times) → `×`. The slash forms stay as they
///          are (`元/kWh`'s non-CJK run is `/kWh`, and the English must contain exactly that).
///
///          ⚠️ **`¥` rather than `CNY` is a measurement, not a preference.** The unit is the
///          `suffixText` **inside** the input field, which measures 118.9dp; the Chinese `元/kWh`
///          (61.3dp) leaves the number 50.4dp, and `元/L` has more room still. The `CNY/kWh` written
///          first (72.7dp) **squeezed the same field's editable area from 50.4dp down to 0.9dp** in the
///          real font — the number had almost nowhere to stand. `¥/kWh` (55.9dp) leaves these two
///          English units **narrower than their Chinese**, so the room on the number's side is more
///          generous than before the change. `¥` has a glyph in both Roboto and Noto Sans SC (`U+00A5`,
///          both font tables were read this round), so it does not depend on a fallback to draw.
///
///          **Length**: the label cell is 89.1dp (how it is measured, and the rule, are on
///          `tool_field_strings.dart`'s head and in the test); the unit cell sits inside the field with
///          **118.9dp** available. Of these 11 the widest English is `periods` at 56.6dp and the widest
///          Chinese `元/kWh` at 56.2dp — **the two languages are level in this cell, 0.4dp apart**, and
///          both use half the field, so length is not a problem on the unit side.
const Map<String, String> toolInputLabelsEn = {
  '基准值': 'Base value',
  '百分比': 'Percent',
  '百分比结果': 'Percent value',
  '新值': 'New value',
  '事件 A 概率': 'P(event A)',
  '事件 B 概率': 'P(event B)',
  'z1 实部': 'z1 real part',
  'z1 虚部': 'z1 imag part',
  'z2 实部': 'z2 real part',
  'z2 虚部': 'z2 imag part',
  '边 a': 'Side a',
  '边 b': 'Side b',
  '边 c': 'Side c',
  '半径': 'Radius',
  '直径': 'Diameter',
  '周长': 'Circumference',
  '面积': 'Area',
  '原始值': 'Original value',
  '原比例': 'Original ratio',
  '目标比例': 'Target ratio',
  '缩放后': 'Scaled value',
  '电压 V': 'Voltage V',
  '电流 I': 'Current I',
  '电阻 R': 'Resistor R',
  '功率 P': 'Power P',
  '电阻公差': 'Tolerance',
  '输入电压 Vin': 'Input Vin',
  '上拉电阻 R1': 'Pull-up R1',
  '下拉电阻 R2': 'Pull-down R2',
  '负载电阻 RL': 'Load RL',
  '目标输出': 'Target output',
  '电容 C': 'Capacitor C',
  '元件公差': 'Tolerance',
  '目标截止频率': 'Target cutoff',
  '功率': 'Power',
  '目标串联等效': 'Series',
  '目标并联等效': 'Parallel',
  '电容公差': 'Tolerance',
  '电感公差': 'Tolerance',
  '电源电压': 'Supply',
  'LED压降': 'LED drop',
  '目标电流': 'Target I',
  '压降误差': 'Vf tolerance',
  '选用电阻': 'Selected R',
  '输入电阻 Rin': 'Input Rin',
  '反馈电阻 Rf': 'Feedback Rf',
  '输入电压': 'Input voltage',
  '目标同相增益': 'Target gain',
  '增益带宽积': 'GBW',
  '输出峰值幅度': 'Output swing',
  '满功率频率': 'Full-power BW',
  '参考电压': 'Vref',
  '位数': 'Bits',
  '有效位数 ENOB': 'ENOB',
  '电感 L': 'Inductor L',
  '串联 ESR': 'Series ESR',
  '上拉电阻': 'Pull-up R',
  '下拉电阻': 'Pull-down R',
  '目标反馈电流': 'Target Ifb',
  '输出电压': 'Vout',
  '负载电流': 'Load current',
  '静态电流': 'Quiescent I',
  '最小压差': 'Min dropout',
  '热阻 θJA': 'θJA',
  '环境温度': 'Ambient',
  '最高结温': 'Max junction',
  '初始电压': 'Initial voltage',
  '电阻': 'Resistance',
  '电容': 'Capacitance',
  '时间': 'Time',
  '目标电压': 'Target V',
  '目标充电比例': 'Target charge',
  '容量': 'Capacity',
  '平均电流': 'Avg current',
  '标称电压': 'Nominal V',
  '效率': 'Efficiency',
  '目标续航': 'Target hours',
  '保留余量': 'Reserve',
  '线宽': 'Trace width',
  '铜厚': 'Copper',
  '允许温升': 'Temp rise',
  '层位置系数': 'Layer factor',
  '电流': 'Current',
  '单程长度': 'One-way run',
  '线芯截面积': 'Wire area',
  '系统电压': 'System V',
  '目标压降': 'Target drop',
  '电阻率': 'Resistivity',
  '并联根数': 'Parallel wires',
  '目标频率': 'Target freq',
  '目标占空比': 'Target duty',
  '功耗': 'Power',
  '热阻': 'Thermal R',
  '降额比例': 'Derating',
  '目标结温': 'Target Tj',
  '目标热余量': 'Margin',
  '驱动齿数 Z1': 'Driving Z1',
  '从动齿数 Z2': 'Driven Z2',
  '输入转速': 'Input speed',
  '输入扭矩': 'Input torque',
  '目标输出转速': 'Target speed',
  '扭矩': 'Torque',
  '转速': 'Speed',
  '目标功率': 'Target power',
  '刚度 k': 'Stiffness k',
  '压缩量 x': 'Deflection x',
  '目标弹簧力': 'Target force',
  '目标储能': 'Target energy',
  '气压': 'Air pressure',
  '缸径': 'Bore',
  '杆径': 'Rod diameter',
  '目标推出力': 'Target force',
  '质量': 'Mass',
  '加速度': 'Acceleration',
  '目标力': 'Target force',
  '主动轮直径': 'Driver dia',
  '从动轮直径': 'Driven dia',
  '导程': 'Lead',
  '目标线速度': 'Target speed',
  '压力': 'Pressure',
  '目标作用力': 'Target force',
  '正压力': 'Normal force',
  '摩擦系数': 'Friction μ',
  '角度': 'Angle',
  '集中载荷': 'Point load',
  '跨度': 'Span',
  '弹性模量': 'Modulus E',
  '惯性矩': 'Inertia',
  '目标挠度': 'Deflection',
  '轴向力': 'Axial force',
  '截面积': 'Section area',
  '圆直径': 'Circle dia',
  '管外径': 'Pipe OD',
  '管内径': 'Pipe ID',
  '矩形宽': 'Rect width',
  '矩形高': 'Rect height',
  '材料强度': 'Strength',
  '工作应力': 'Stress',
  '目标安全系数': 'Target factor',
  '流量': 'Flow rate',
  '长度': 'Length',
  '宽度': 'Width',
  '厚度': 'Thickness',
  '密度': 'Density',
  '贷款金额': 'Loan amount',
  '年利率': 'Annual rate',
  '贷款年限': 'Loan term',
  '目标月供': 'Payment',
  '每期投入': 'Payment',
  '年化收益': 'Annual return',
  '年限': 'Years',
  '每年期数': 'Periods/yr',
  '目标终值': 'Target value',
  '商品价格': 'Price',
  '总手续费率': 'Total fee rate',
  '分期期数': 'Instalments',
  '目标每期': 'Payment',
  '固定成本': 'Fixed cost',
  '单价': 'Unit price',
  '单位变动成本': 'Unit var. cost',
  '目标销量': 'Sales target',
  '每日使用': 'Hours/day',
  '天数': 'Days',
  '电价': 'Tariff',
  '目标费用': 'Target cost',
  '本金': 'Principal',
  '成本': 'Cost',
  '售价': 'Price',
  '目标毛利率': 'Margin',
  '目标利润': 'Target profit',
  '收益': 'Gain',
  '投入': 'Cost',
  '持有年限': 'Holding years',
  '原价': 'Original price',
  '折扣': 'Discount',
  '到手价': 'Final price',
  '税前金额': 'Net',
  '税率': 'Tax rate',
  '含税金额': 'Gross',
  '当前金额': 'Current value',
  '年通胀率': 'Inflation rate',
  '年数': 'Years',
  '未来等值': 'Future value',
  '初始投入': 'Initial cost',
  '折现率': 'Discount rate',
  '第1期现金流': 'Cash flow 1',
  '第2期现金流': 'Cash flow 2',
  '第3期现金流': 'Cash flow 3',
  '第4期现金流': 'Cash flow 4',
  '第5期现金流': 'Cash flow 5',
  '输入值': 'Input value',
  '速度': 'Speed',
  '距离': 'Distance',
  '高度': 'Height',
  '初速度': 'Initial speed',
  '重力加速度': 'Gravity',
  '缓冲距离': 'Buffer',
  '力': 'Force',
  '位移': 'Displacement',
  '力-位移夹角': 'Force angle',
  '目标总能量': 'Target energy',
  '体积': 'Volume',
  '溶质量': 'Solute mass',
  '溶液体积': 'Volume',
  '摩尔质量': 'Molar mass',
  '质量浓度': 'Mass conc.',
  '摩尔浓度': 'Molarity',
  '物质的量': 'Moles n',
  '温度': 'Temperature',
  '比热容': 'Specific heat',
  '温度变化': 'Temp change',
  '热量': 'Heat',
  '波速': 'Wave speed',
  '频率': 'Frequency',
  '波长': 'Wavelength',
  '初始量': 'Initial amount',
  '半衰期': 'Half-life',
  '经过时间': 'Elapsed time',
  '剩余量': 'Remaining',
  '剩余比例': 'Remaining %',
  '目标pH': 'Target pH',
  '体重': 'Weight',
  '身高': 'Height',
  '腰围': 'Waist',
  '里程': 'Distance',
  '燃油': 'Fuel',
  '百公里油耗': 'Consumption',
  '油价': 'Fuel price',
  '油箱容量': 'Tank size',
  '年行驶里程': 'Annual km',
  'CO2系数': 'CO2 factor',
};

/// 中文：**中文单位 → 英文**，11 条，按目录里第一次出现的顺序排。查表在
///       [ToolFieldStrings.inputUnit]；认不出的单位（`Ω`、`nF`、`m/s`…）原样返回，
///       所以那 65 个记号两种语言完全相同。
/// English: **Chinese unit → English**, 11 entries in catalogue order. The lookup is
///          [ToolFieldStrings.inputUnit]; an unknown unit (`Ω`, `nF`, `m/s`, …) comes back unchanged,
///          which is why those 65 pieces of notation read the same in both languages.
const Map<String, String> toolInputUnitsEn = {
  '倍': '×',
  '根': 'pcs',
  '齿': 'teeth',
  '万元': '10k ¥',
  '年': 'years',
  '元': '¥',
  '期': 'periods',
  '件': 'pcs',
  '天': 'days',
  '元/kWh': '¥/kWh',
  '元/L': '¥/L',
};
