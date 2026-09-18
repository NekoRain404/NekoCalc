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

/// 中文：**`►DRG` 那一次换算允许写在 `to` 两侧的拼法——第二张闭集，比 [kAppUnits] 窄。**
///
///       **两张表、两个用途，混用会开错门：**
///       - [kAppUnits] 是**可以插进任何表达式**的单位（`5 km`、`2 s`），翻译层对其中每一个拼法
///         一律放行；
///       - 本表是**只在一次 `to` 换算的两侧**才成立的拼法。换句话说 `deg` 在 `5 deg` 或
///         `deg + 1` 里仍旧到不了引擎（那正是文件头说的「同一个写法两侧含义不同」那一类错误），
///         只有在 `<值> <单位> to <单位>` 这个形状里它才是一个单位。判据只有一处，在
///         `engine_expression.dart` 的 `_angleConversion` 上；本表是它的**数据**，面板读的也是
///         同一张表（一个词汇，没有第二份）。
///
///       **为什么 `deg` 必须在这一张表里，而不是加进 [kAppUnits]。** 应用自己的 `deg` 是一个
///       **函数**——`deg(1.5707963268)` = 90，弧度换度（`expression_parser.dart:141`）——而它的
///       **单位**含义只在一次换算里有意义。加进 [kAppUnits] 就等于让裸的 `deg` 在整个表达式语言里
///       合法，那是本轮明确不开的门。`rad` 早在 [kAppUnits] 里（同一个字既是函数又是单位），所以
///       本表里的 `rad` **不是**新的放行：`deg` 是本表唯一比 [kAppUnits] 宽的拼法。
///
///       **六个拼法逐个量过**（宿主 `qalc` 5.12.0，与打包进 AAR 的同版本；`-t`，也就是宿主默认的
///       打印精度——桥自己问的是 16 位有效数字，所以屏幕上会多几位：同一句
///       `-t -set "precision 16"` 给的是 `1.570796326794897 rad` 与 `0.08726646259971648 rad`）：
///
///       | 调用 | 引擎印出来的 |
///       |---|---|
///       | `90 deg to rad` | `1.570796327 rad` |
///       | `1.570796326794897 rad to deg` | `90.00000000°` |
///       | `90 deg to gon` | `100 gra` |
///       | `90 deg to turn` | `0.25 tr` |
///       | `90 deg to arcmin` | `5400 arcmin` |
///       | `90 deg to arcsec` | `324000 arcsec` |
///       | `0.25 turn to deg` | `90°` |
///       | `1 gon to deg` | `0.9°` |
///       | `1 arcmin to deg` | `0.01666666667°` |
///       | `1 arcsec to deg` | `0.0002777777778°` |
///
///       **两侧都写出来时，答案与角度模式无关**（同一台宿主，`-set "angle unit deg|rad|gra"`
///       三档各跑一遍）：`90 deg to rad` 三档都是 `1.570796327 rad`，`1 rad to deg` 三档都是
///       `57.29577951°`。**只写目标单位就不成立**：`90 to rad` 在 DEG 下是 `1.570796327 rad`、
///       在 RAD 下是 `90 rad`、在 GRA 下是 `1.413716694 rad`——那一步的源单位是**当前角度模式**，
///       不是表达式里说出来的东西。（这一条与旧注释里那句「`90 to deg` 只是贴了个记号、值一个
///       字节没变」不同：**贴记号只在 DEG 下成立**，RAD 下 `90 to deg` 实测 `5156.620156°`。
///       本应用今天允许 `X to rad` 这类写法从 `CONV` 面板按出来，所以那条路上的答案随角度模式
///       变——**这是本轮量到、但本轮没有改的一条**，理由写在 `engine_expression.dart` 的
///       `_angleConversion` 上。）
///
///       **被拒绝的拼法（量过，写在这里免得下一轮重跑）**：`grad` **不是**百分度——
///       `1 grad` = `1357.168026 s·rad`（根本不是一个角），`90 grad to deg` = `81 d·°`、
///       `100 grad to deg` = `90 d·°`（**值对、单位坏了**：印出来是 `d·°` 而不是 `°`）。
///       百分度在本应用里用 `gon`（[kAppUnits] 的角度族里本来就有这个拼法）：`1 gon to deg` =
///       `0.9°`、`90 deg to gon` = `100 gra`、`400 gon to turn` = `1 tr`。`gradian`/`gra` 也对
///       （`1 gradian to deg` = `0.9°`），但一个单位只留一个拼法，所以它们不进表。
///       `degree(s)`/`radian(s)`/`arcminute` 引擎读得懂（实测 `90 degrees to rad` =
///       `1.570796327 rad`），但它们**不在应用的单位表里**——与 `zorkmid` 那一类同一条路：
///       不是引擎读不懂，是本应用没有给它们拼法。
/// English: **the spellings `►DRG`'s conversion may write on either side of `to` — a second closed
///          table, narrower than [kAppUnits].**
///
///          **Two tables, two uses; mixing them opens the wrong door:**
///          - [kAppUnits] holds the units that may be inserted into **any** expression (`5 km`,
///            `2 s`), and the translation lets every one of those spellings through;
///          - this table holds the spellings that hold **only on the two sides of one `to`
///            conversion**. So `deg` in `5 deg` or `deg + 1` still cannot reach the engine (that is
///            exactly the "one spelling, two meanings" class this file's head exists to prevent);
///            only in the shape `<value> <unit> to <unit>` is it a unit. There is exactly one
///            judgement and it is `_angleConversion` in `engine_expression.dart`; this table is its
///            **data**, and the sheet reads the same table (one vocabulary, no second copy).
///
///          **Why `deg` has to be in this table instead of being added to [kAppUnits].** This app's
///          own `deg` is a **function** — `deg(1.5707963268)` = 90, radians to degrees
///          (`expression_parser.dart:141`) — and its **unit** meaning only makes sense inside a
///          conversion. Adding it to [kAppUnits] would make a bare `deg` legal across the whole
///          expression language, which is the door this round deliberately does not open. `rad` has
///          been in [kAppUnits] all along (the same word is both a function and a unit), so `rad`
///          here is **not** a new admission: `deg` is this table's only spelling wider than
///          [kAppUnits].
///
///          **All six spellings measured** (host `qalc` 5.12.0, the version this AAR bundles; `-t`,
///          i.e. the host's default print precision — the bridge itself asks for 16 significant
///          digits, so the screen carries a few more: the same sentence under
///          `-t -set "precision 16"` gives `1.570796326794897 rad` and `0.08726646259971648 rad`) —
///          see the table above.
///
///          **With both sides written out, the answer does not depend on the angle mode** (same host,
///          `-set "angle unit deg|rad|gra"`, one run per mode): `90 deg to rad` gives
///          `1.570796327 rad` in all three and `1 rad to deg` gives `57.29577951°` in all three.
///          **Naming only the target does not hold**: `90 to rad` is `1.570796327 rad` under DEG,
///          `90 rad` under RAD and `1.413716694 rad` under GRA — that conversion's source unit is the
///          **current angle mode**, not something the expression said. (This differs from the old
///          note's "`90 to deg` merely attaches a symbol and the value does not move a byte": **that
///          holds only under DEG**; under RAD `90 to deg` measures `5156.620156°`. This app does allow
///          `X to rad` and friends to be pressed out of the `CONV` sheet today, so on that path the
///          answer moves with the angle mode — **measured this round and deliberately not changed**;
///          the reason is on `_angleConversion` in `engine_expression.dart`.)
///
///          **Refused spellings (measured, recorded so the next round need not re-measure)**: `grad`
///          is **not** the gradian — `1 grad` = `1357.168026 s·rad` (not an angle at all),
///          `90 grad to deg` = `81 d·°` and `100 grad to deg` = `90 d·°` (**value right, unit
///          corrupted**: it prints `d·°` rather than `°`). The gradian's spelling in this app is `gon`
///          (it has been in [kAppUnits]' angle family all along): `1 gon to deg` = `0.9°`,
///          `90 deg to gon` = `100 gra`, `400 gon to turn` = `1 tr`. `gradian`/`gra` work too
///          (`1 gradian to deg` = `0.9°`), but one unit keeps one spelling, so they stay out.
///          `degree(s)`/`radian(s)`/`arcminute` the engine does read (measured: `90 degrees to rad` =
///          `1.570796327 rad`), but they are **not in this app's unit table** — the same road as
///          `zorkmid`: not "the engine cannot read it" but "this app gives it no spelling".
const List<String> kAngleUnits = <String>[
  // 中文：顺序就是面板上的顺序：度最常用，其余按「一圈的几分之一」从大到小。
  // English: the order is the sheet's order: degrees first, then by "what fraction of a turn" from
  //          largest to smallest.
  'deg',
  'rad',
  'gon',
  'turn',
  'arcmin',
  'arcsec',
];

/// 中文：本表的拼法集合——**翻译层的判据与 `►DRG` 的面板读的是同一张表**（没有第二份清单）。
///       按原样比较（大小写敏感），与 [kAppUnitSymbols] 同一条理由。
/// English: the set of spellings in this table — **the translation's judgement and the `►DRG` sheet
///          read the same table** (no second list). Compared verbatim (case-sensitive), the same
///          reason [kAppUnitSymbols] has.
final Set<String> kAngleUnitSymbols = <String>{
  for (final unit in kAngleUnits) unit,
};

/// 中文：这个拼法是不是一次角度换算里可以写的单位（**大小写敏感**）。
/// English: whether this spelling is a unit that may be written in an angle conversion
///          (**case-sensitive**).
bool isAngleUnit(String spelling) => kAngleUnitSymbols.contains(spelling);

/// 中文：**一条角度换算写在表达式里的样子**：`<值> <源单位> to <目标单位>`——源单位**永远**写出来。
///
///       为什么源单位不能省：只写目标单位时，那一步的源单位是**当前角度模式**（实测见 [kAngleUnits]
///       上那张表：`90 to rad` 在 DEG/RAD/GRA 三档下是三个不同的答案），而用户按下 `►DRG` 时手里
///       那个数未必是当前模式的单位。写全了，答案与模式无关。
///
///       分隔符：值、源单位、`to`、目标单位之间各一个空格。`to` 两侧的空格不是排版——它是那个词
///       **成为词**的条件（`engine_expression.dart` 的 `_wordOperator`：不留空格时引擎把
///       `((5)*(km))to((mi))` 读成 `t`·`o` 的乘积，且**不报错**）。
/// English: **what one angle conversion looks like written into the expression**:
///          `<value> <source unit> to <target unit>` — the source unit is **always** written out.
///
///          Why the source cannot be dropped: with only the target named, the source unit of that
///          conversion is the **current angle mode** (measured; the table on [kAngleUnits] shows
///          `90 to rad` giving three different answers under DEG/RAD/GRA), while the number the user
///          holds when pressing `►DRG` need not be in the current mode's unit. Written out, the
///          answer does not depend on the mode.
///
///          Separators: one space between the value, the source unit, `to` and the target unit. The
///          spaces around `to` are not typography — they are what makes that word **a word**
///          (`_wordOperator` in `engine_expression.dart`: without them the engine reads
///          `((5)*(km))to((mi))` as the product `t`·`o`, and **does not error**).
String angleConversionCall(String value, String sourceUnit, String targetUnit) {
  assert(isAngleUnit(sourceUnit), '角度换算的源单位不在表里：$sourceUnit');
  assert(isAngleUnit(targetUnit), '角度换算的目标单位不在表里：$targetUnit');
  return '$value $sourceUnit to $targetUnit';
}
