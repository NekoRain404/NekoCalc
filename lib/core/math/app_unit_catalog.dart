/// 中文：**应用能插进表达式的单位——一张封闭的表。**
///
///       它与 [AppEngineVocabulary] 是同一个思路的第二个实例：那边管函数名，这里管单位名。
///       两边的存在理由也一样——**拼法表外的名字到不了引擎**，因为引擎不认识一个名字时不会报错，
///       它会**把那个词拆成它认识的符号**：
///
///       | 表达式 | 引擎读到的东西 | 引擎印出来的 |
///       |---|---|---|
///       | `5 zorkmid` | `z`（zepto 前缀）+ 剩下的部分 | `5E-21 B` |
///
///       一个不存在的单位于是得到一个**看起来完全合理的值**（实测，宿主 libqalculate 5.12.0）。
///       所以单位名与函数名一样必须是闭集：键盘只能插入这张表里的拼法，而翻译层拒绝表外的一切
///       自由变量（[AppEngineVocabulary.variableUnknownToEngine]）。
///
///       **表里的符号全部是量出来的**，不是想出来的：每一个都在宿主上按桥的调用序列
///       （`unlocalizeExpression` → `calculate`，精度 16、`mixed_units_conversion=NONE`、
///       `auto_post_conversion=NONE`）问过一句「`2 <符号>` 的结果带不带单位」，117 个全部通过
///       （量测程序与输出记在步骤 6 的报告里）。
///
///       **大小写敏感。** 引擎的单位名分大小写（`m` 是米、`M` 是马赫数前缀的写法之一），所以这里
///       按**原样**查表：`KM` 不是 `km`，它落回「表外的自由变量」那一条，由旧解析器报错。宁可
///       报错，也不要把两个不同的单位当成一个。
///
///       **刻意不在表里的两类**：
///       - **带 `^` 的复合单位**（`m^2`、`m/s`）：它们是**表达式**而不是名字，插入它们要先把
///         运算符一起插进去，这一步不做（用户可以用 `m`、再用键盘上的 `^`、`2` 自己拼）。
///       - **温度（`°C`/`°F`）**：应用自己的解析器把 `°` 当成角度后缀改写（`expression_parser.dart`
///         的 `_replaceDegree`），`5 °C` 在应用这一侧根本不是「5 摄氏度」那个意思。放进表里会让
///         同一个写法在两侧含义不同——那正是这个文件要防的那类错误，所以这一步不放。
///
/// English: **The units this app can insert into an expression — one closed table.**
///
///          It is the second instance of the same idea as [AppEngineVocabulary]: that one covers
///          function names, this one unit names, and the reason is identical — **a spelling outside
///          the table never reaches the engine**, because when the engine does not know a name it does
///          not error, it **takes the word apart into symbols it does know**:
///
///          | expression | what the engine reads | what it prints |
///          |---|---|---|
///          | `5 zorkmid` | `z` (the zepto prefix) + the rest | `5E-21 B` |
///
///          So a unit that does not exist comes back as a **completely plausible value** (measured,
///          host libqalculate 5.12.0). Unit names therefore have to be a closed set exactly as
///          function names are: the keypad can only insert spellings from this table, and the
///          translation refuses every free variable outside it
///          ([AppEngineVocabulary.variableUnknownToEngine]).
///
///          **Every symbol here is measured, not imagined**: each one was asked of the host through the
///          bridge's call sequence (`unlocalizeExpression` → `calculate`, precision 16,
///          `mixed_units_conversion=NONE`, `auto_post_conversion=NONE`) whether `2 <symbol>` yields
///          something carrying a unit — all 117 passed (the measuring program and its output are in the
///          step 6 report).
///
///          **Case-sensitive.** The engine's unit names distinguish case (`m` is metre), so the lookup
///          here is **exact**: `KM` is not `km` and falls back to "a free variable outside the table",
///          where the legacy parser reports an error. An error is preferable to treating two different
///          units as one.
///
///          **Two families deliberately absent**:
///          - **Compound units with `^`** (`m^2`, `m/s`): those are **expressions** rather than names,
///            and inserting one means inserting operators too. Not this step (the user can build them
///            from `m`, the keypad's `^` and `2`).
///          - **Temperature (`°C`/`°F`)**: this app's own parser rewrites `°` as an angle suffix
///            (`_replaceDegree` in `expression_parser.dart`), so `5 °C` does not mean "five degrees
///            Celsius" on this side at all. Listing it would make one spelling mean two things on the
///            two sides — exactly the class of mistake this file exists to prevent, so it stays out.
library;

/// 中文：一个可插入的单位：引擎的拼法、给用户看的中文名、以及它属于哪一族。
/// English: one insertable unit: the engine's spelling, the Chinese name shown to the user, and the
///          family it belongs to.
class AppUnit {
  const AppUnit(this.symbol, this.label, this.family);

  /// 中文：**插进表达式的那串文本**，也是给引擎的拼法。逐字来自宿主量测。
  /// English: **the text inserted into the expression**, and the spelling handed to the engine.
  ///          Verbatim from the host measurement.
  final String symbol;

  /// 中文：面板上显示的名字。
  /// English: the name shown in the sheet.
  final String label;

  /// 中文：所属族，用于分组显示。
  /// English: the family, used for grouping.
  final String family;
}

/// 中文：全部可插入单位。顺序就是面板上的顺序（族内按常用程度排）。
/// English: every insertable unit, in the order the sheet shows them (most common first within a
///          family).
const List<AppUnit> kAppUnits = <AppUnit>[
  // 长度
  AppUnit('m', '米', '长度'),
  AppUnit('km', '千米', '长度'),
  AppUnit('cm', '厘米', '长度'),
  AppUnit('mm', '毫米', '长度'),
  AppUnit('um', '微米', '长度'),
  AppUnit('nm', '纳米', '长度'),
  AppUnit('in', '英寸', '长度'),
  AppUnit('ft', '英尺', '长度'),
  AppUnit('yd', '码', '长度'),
  AppUnit('mi', '英里', '长度'),
  AppUnit('nmi', '海里', '长度'),
  AppUnit('AU', '天文单位', '长度'),
  AppUnit('ly', '光年', '长度'),
  AppUnit('pc', '秒差距', '长度'),
  // 面积
  AppUnit('ha', '公顷', '面积'),
  AppUnit('acre', '英亩', '面积'),
  AppUnit('are', '公亩', '面积'),
  // 体积
  AppUnit('L', '升', '体积'),
  AppUnit('mL', '毫升', '体积'),
  AppUnit('cL', '厘升', '体积'),
  AppUnit('gal', '加仑', '体积'),
  AppUnit('qt', '夸脱', '体积'),
  AppUnit('pt', '品脱', '体积'),
  AppUnit('floz', '液量盎司', '体积'),
  AppUnit('cup', '杯', '体积'),
  AppUnit('tbsp', '汤匙', '体积'),
  AppUnit('tsp', '茶匙', '体积'),
  // 质量
  AppUnit('kg', '千克', '质量'),
  AppUnit('g', '克', '质量'),
  AppUnit('mg', '毫克', '质量'),
  AppUnit('ug', '微克', '质量'),
  AppUnit('t', '吨', '质量'),
  AppUnit('lb', '磅', '质量'),
  AppUnit('oz', '盎司', '质量'),
  AppUnit('ton', '美吨', '质量'),
  AppUnit('carat', '克拉', '质量'),
  // 时间
  AppUnit('s', '秒', '时间'),
  AppUnit('ms', '毫秒', '时间'),
  AppUnit('us', '微秒', '时间'),
  AppUnit('ns', '纳秒', '时间'),
  AppUnit('h', '小时', '时间'),
  AppUnit('day', '天', '时间'),
  AppUnit('week', '周', '时间'),
  AppUnit('year', '年', '时间'),
  // 速度
  AppUnit('mph', '英里每小时', '速度'),
  AppUnit('kph', '千米每小时', '速度'),
  // 压强
  AppUnit('Pa', '帕斯卡', '压强'),
  AppUnit('kPa', '千帕', '压强'),
  AppUnit('MPa', '兆帕', '压强'),
  AppUnit('hPa', '百帕', '压强'),
  AppUnit('bar', '巴', '压强'),
  AppUnit('mbar', '毫巴', '压强'),
  AppUnit('atm', '标准大气压', '压强'),
  AppUnit('psi', '磅力每平方英寸', '压强'),
  AppUnit('mmHg', '毫米汞柱', '压强'),
  AppUnit('torr', '托', '压强'),
  // 能量
  AppUnit('J', '焦耳', '能量'),
  AppUnit('kJ', '千焦', '能量'),
  AppUnit('MJ', '兆焦', '能量'),
  AppUnit('cal', '卡', '能量'),
  AppUnit('kcal', '千卡', '能量'),
  AppUnit('Wh', '瓦时', '能量'),
  AppUnit('kWh', '千瓦时', '能量'),
  AppUnit('eV', '电子伏', '能量'),
  AppUnit('BTU', '英热单位', '能量'),
  AppUnit('erg', '尔格', '能量'),
  // 功率
  AppUnit('W', '瓦特', '功率'),
  AppUnit('kW', '千瓦', '功率'),
  AppUnit('MW', '兆瓦', '功率'),
  AppUnit('hp', '马力', '功率'),
  // 力
  AppUnit('N', '牛顿', '力'),
  AppUnit('kN', '千牛', '力'),
  AppUnit('dyn', '达因', '力'),
  AppUnit('lbf', '磅力', '力'),
  AppUnit('kgf', '千克力', '力'),
  // 频率
  AppUnit('Hz', '赫兹', '频率'),
  AppUnit('kHz', '千赫', '频率'),
  AppUnit('MHz', '兆赫', '频率'),
  AppUnit('GHz', '吉赫', '频率'),
  // 数据
  AppUnit('bit', '比特', '数据'),
  AppUnit('B', '字节', '数据'),
  AppUnit('byte', '字节（全拼）', '数据'),
  AppUnit('kB', '千字节', '数据'),
  AppUnit('MB', '兆字节', '数据'),
  AppUnit('GB', '吉字节', '数据'),
  AppUnit('KiB', 'KiB（1024）', '数据'),
  AppUnit('MiB', 'MiB（1024²）', '数据'),
  AppUnit('GiB', 'GiB（1024³）', '数据'),
  // 角度
  AppUnit('rad', '弧度', '角度'),
  AppUnit('arcmin', '角分', '角度'),
  AppUnit('arcsec', '角秒', '角度'),
  AppUnit('gon', '百分度', '角度'),
  AppUnit('turn', '圈', '角度'),
  // 电学
  AppUnit('A', '安培', '电学'),
  AppUnit('mA', '毫安', '电学'),
  AppUnit('uA', '微安', '电学'),
  AppUnit('V', '伏特', '电学'),
  AppUnit('mV', '毫伏', '电学'),
  AppUnit('kV', '千伏', '电学'),
  AppUnit('ohm', '欧姆', '电学'),
  AppUnit('kohm', '千欧', '电学'),
  AppUnit('Mohm', '兆欧', '电学'),
  AppUnit('F', '法拉', '电学'),
  AppUnit('mF', '毫法', '电学'),
  AppUnit('uF', '微法', '电学'),
  AppUnit('nF', '纳法', '电学'),
  AppUnit('pF', '皮法', '电学'),
  AppUnit('H', '亨利', '电学'),
  AppUnit('mH', '毫亨', '电学'),
  AppUnit('uH', '微亨', '电学'),
  AppUnit('C', '库仑', '电学'),
  AppUnit('mC', '毫库仑', '电学'),
  AppUnit('Ah', '安时', '电学'),
  AppUnit('mAh', '毫安时', '电学'),
  // 其他
  AppUnit('rpm', '转每分', '其他'),
  AppUnit('mol', '摩尔', '其他'),
  AppUnit('cd', '坎德拉', '其他'),
  AppUnit('lx', '勒克斯', '其他'),
  AppUnit('lm', '流明', '其他'),
  AppUnit('sr', '球面度', '其他'),
];

/// 中文：表里的拼法集合——**翻译层的判据读它**（[AppEngineVocabulary.variableUnknownToEngine]）。
///       按原样比较（大小写敏感），理由见文件头。
/// English: the set of spellings in the table — **the translation's judgement reads this**
///          ([AppEngineVocabulary.variableUnknownToEngine]). Compared verbatim (case-sensitive); see
///          the file header.
final Set<String> kAppUnitSymbols = <String>{
  for (final unit in kAppUnits) unit.symbol,
};

/// 中文：这个拼法是不是表里的单位（**大小写敏感**）。
/// English: whether this spelling is a unit in the table (**case-sensitive**).
bool isAppUnit(String spelling) => kAppUnitSymbols.contains(spelling);

/// 中文：族的顺序——面板按它分组，而不是按单位在表里的出现顺序去猜。
/// English: the order of the families — the sheet groups by this rather than guessing from the order
///          units happen to appear in the table.
const List<String> kAppUnitFamilies = <String>[
  '长度',
  '面积',
  '体积',
  '质量',
  '时间',
  '速度',
  '压强',
  '能量',
  '功率',
  '力',
  '频率',
  '数据',
  '角度',
  '电学',
  '其他',
];
