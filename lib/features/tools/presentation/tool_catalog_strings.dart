import 'package:flutter/widgets.dart';

import '../../../domain/entities/tool_category.dart';
import '../../../domain/usecases/tool_catalog.dart';
import '../../../l10n/app_language.dart';
import 'tool_description_strings.dart';

/// 中文：**工具目录的名字表**——117 个工具的名字，加上 8 个分类的名字与说明（16 条）。
///       机制本身（为什么是手写分表而不是 ARB / `gen-l10n`、为什么**兄弟表**是 `static final`
///       而不是 `const`）与设置页那张表共用一套理由，写在 `settings_strings.dart` 的文件头上，
///       这里不重抄；**这一张是 `static const`**，与兄弟表不同的那一点写在 [toolCatalogZh] 上。
///
///       **为什么这是工具子树的第三张表，而不是并进 `ToolsStrings`。** 前两张装的是"包在目录
///       外面的壳"（页头、按钮、提示），这一张装的是**目录本身的名字**。并进去要多 234 条
///       （117×2）加 16 条分类，`tools_strings.dart` 会直接冲过八百行硬线——`data_fit_strings.dart`
///       的文件头已经为同样的理由做过一次切分。**切分判据是"一屏看得完"，不是"一个屏幕一张"**：
///       这张表是唯一一张被工具首页 / 分类页 / 工具详情页 / 文本工具页 / 拟合页**五处共用**的
///       名字来源，按屏幕切它没有落点。
///
///       **117 个名字里有 99 个不是本轮写的，是把仓库里已经提交的英文找出来。**
///       那份检索索引有**两处**，都是故意做实了的双语数据：`tool_search_aliases_{a,b,c}.dart`
///       里 **86** 个 id 各一张别名表（33 + 28 + 25），`tool_search_data.dart` 的
///       `unitSearchAliases` 里再 **21** 个（22 个换算工具中的 21 个在那里，剩下的 `data_size`
///       在前一处）——合起来 **107** 个 id 有别名表。**表里第一条能当名字用的英文别名就是这个
///       工具的英文名**；本表按那条规则取名，只做排版归一（首字母大写；连字符、斜杠按英文写法
///       补上），一个词都不增删。**两处索引本轮一个字节都没动**：本表读它们，不改它们。
///       每条英文后面的注释写着它属于哪一类：
///         · `A` 提升（promoted，**99 条**）——名字就是该 id 别名表里的某一条，注释里是那条原文；
///         · `B` 新写（authored，**14 条**）——**没有可用的别名**，注释里是理由：九条是该 id 在
///              两处索引里根本没有表，五条是有表但表里没有一条是名字
///              （`timestamp`、`url_codec`、`uuid`、`jwt_decode`、`text_stats`）；
///         · `L` 本来就是拉丁字母（**4 条**）——中文标题就是 `Base64`、`pH / pOH`、`FNV/CRC32`、
///              `ASCII/Unicode`，没有可翻的东西，英文一格与原样**逐字节相同**。
///       `tool_catalog_strings_test.dart` 把这件事**做成机器可查**：每一条 `A` 的名字去掉大小写、
///       空格、连字符与斜杠之后，必须能在该 id 的别名表里找到；`B` 与 `L` 的 id 则与测试里那张
///       逐条带理由的清单**互为全集**——多一个少一个都红。
///
///       **分类那 16 条是另一码事。** 八个**英文**分类名是**按卡片宽度量出来的**——可用宽度
///       `(W - 42) / 2 - 72`、两根来自设备的标尺、八个旧名 → 新名各自丢了什么，逐条写在
///       [toolCatalogEn] 头上那一段里；中文那八个名字一个字都没动，说明那 8 条照旧成对进表。
///
///       **中文一侧是逐条写出来的字面量，不是从目录里转引的。** 两种语言并排看得见，是这套机制的
///       本来面目；而 `tool_catalog_strings_test.dart` 拿 `toolCatalog` 逐条比对，**任何一条与
///       `tool.title` 不同就红**——那条断言在运行期读目录，所以它不是自证。认不出的 id 回落到
///       `toolById(id)?.title`，也就是今天屏幕上的字：**默认态因此连"表漏一条"都改不动**；
///       英文下这种漏会以中文的样子露出来（而不是静默给个别的英文），同时测试已经红了。
///
///       **本表装名字与描述两样，别的仍不住在这里。** 描述本来也留在这里（当时文件头上写着
///       "本表只管名字"），本轮接进来时**另起了一个文件**——`tool_description_strings.dart`，
///       理由只有一条行数硬线，写在那个文件的头上；两张表由本类**同一个 switch** 分派，
///       所以卡片上的名字与描述不可能来自两种语言。**公式、参数标签、单位、分组名**
///       （`tool.formula`、`input.label`、`input.unit`、`input.key`、`result.label`、`tool.group`）
///       仍住在 `tool_catalog*.dart` 与 `tool_insights_*.dart`，今天仍是中文——**已知的残留**，
///       与 `tools_strings.dart` 文件头列的那几条同类，规模量在
///       `.superpowers/backup/tool-descriptions-report.md` 里。
///
///       ⚠️ **这里原先把检索结果那行"匹配到 XXX"也列作"没动"，那句话此后不再成立。** 那行现在
///       分两半：**外壳**（`标题`、`别名`、`关键词`…十个）成了 `ToolMatchTokens` 里的 ASCII 令牌，
///       字落在 `ToolsStrings` 的令牌表；**内容**（`tool.group` 与**本表的分类名**）原样透传，
///       所以本表仍是它在屏幕上的唯一来源。两半的判据写在 `ToolsStrings.match` 上。
/// English: **This table holds names only.** Descriptions, formulas, parameter labels, units and group
///          names (`tool.description`, `input.label`, `tool.group`, …) still live in
///          `tool_catalog*.dart` and are still Chinese today — a **known remainder**, of the same kind
///          as the ones listed on `tools_strings.dart`'s file head.
///
///          ⚠️ **The "matched …" line used to be listed here as untouched too; that no longer holds.**
///          The line is now two halves: the **chrome** (`标题`, `别名`, `关键词`, … ten of them) became
///          ASCII tokens in `ToolMatchTokens` whose words land in `ToolsStrings`' token table, while the
///          **content** (`tool.group` and **this table's category names**) passes through verbatim — so
///          this table is still their one source on screen. The rule for the two halves is written on
///          `ToolsStrings.match`.
/// English: **the tools catalogue's name table** — the 117 tool names plus the 8 categories' names
///          and descriptions (16 strings). The mechanism itself (why hand-written tables rather than
///          ARB / `gen-l10n`, why the tables are `static final` rather than `const`) shares one set of
///          reasons with the settings table and is written on `settings_strings.dart`'s file head; it
///          is not copied again here. **This one is `static const`**, and the one point where it
///          differs from its siblings is written on [toolCatalogZh].
///
///          **Why this is the tools subtree's third table instead of part of `ToolsStrings`.** The
///          first two hold the shell around the catalogue (page heads, buttons, hints); this one holds
///          **the catalogue's own names**. Folding it in would add 234 entries (117 × 2) plus the 16
///          category strings and push `tools_strings.dart` straight past the hard 800-line limit —
///          the very split `data_fit_strings.dart`'s file head already made for the same reason.
///          **The split is judged by "readable in one screen", not by "one table per screen"**: this
///          is the one table **five** screens share (tools home, category, tool detail, text tool
///          detail, fit), so splitting it by screen has nowhere to land.
///
///          **99 of the 117 names are not written this round — they are English the repository had
///          already committed.** That search index lives in **two** places, both deliberately
///          bilingual: `tool_search_aliases_{a,b,c}.dart` (one alias list each for **86** ids — 33 +
///          28 + 25) and `ToolSearchData.unitSearchAliases` in `tool_search_data.dart` (another
///          **21**, which is 21 of the 22 conversion tools; `data_size` is in the first place) —
///          **107** ids with an alias list between them. **The first name-like English entry is that
///          tool's English name**; this table takes names by that rule, normalising typography only
///          (initial capitals; hyphens and slashes where English orthography wants them) and adding or
///          dropping not one word. **Neither index was touched this round by one byte**: this table
///          reads them, it does not edit them. The comment after each English entry says which class
///          it belongs to:
///            · `A` promoted (**99**) — the name *is* one of that id's committed aliases, quoted in
///              the comment;
///            · `B` authored (**14**) — **no usable alias exists**; the comment gives the reason. Nine
///              of these ids have no list in either index, and five have a list whose entries are not
///              names (the `timestamp`, `url_codec`, `uuid`, `jwt_decode`, `text_stats` kind);
///            · `L` already Latin (**4**) — the Chinese title itself is `Base64`, `pH / pOH`,
///              `FNV/CRC32`, `ASCII/Unicode`; there is nothing to translate and the English cell is
///              **byte for byte** the same string.
///          `tool_catalog_strings_test.dart` makes that **machine-checkable**: every `A` name, stripped
///          of case, spaces, hyphens and slashes, must be found in that id's alias list, and the `B`
///          and `L` ids are **exactly** the ids on the reason-per-entry list inside the test — one
///          more or one fewer goes red.
///
///          **The sixteen category strings are a different matter.** The eight **English** category
///          names were **measured against the card** — the available width `(W - 42) / 2 - 72`, the two
///          rulers taken from the device, and what each of the eight gives up, are written entry by
///          entry on [toolCatalogEn]; the eight Chinese names did not move by a character, and the 8
///          descriptions still come in as the name's pair.
///
///          **The Chinese side is written out entry by entry rather than derived from the catalogue.**
///          Seeing both languages side by side is what this mechanism looks like; and
///          `tool_catalog_strings_test.dart` compares every entry against `toolCatalog` and **goes red
///          the moment one differs from `tool.title`** — that assertion reads the catalogue at run
///          time, so it is not self-certifying. An unrecognised id falls back to
///          `toolById(id)?.title`, the string on screen today: **the default state therefore cannot
///          move even if the table misses an entry**; in English such a miss shows up as Chinese
///          (rather than quietly rendering some other English) while the test is already red.
///
///          **This table holds names and descriptions, and nothing else moved in.** Descriptions used
///          to be left out of it (the file head read "this table holds names only"); they arrive this
///          round from **a file of their own** — `tool_description_strings.dart`, split off for the
///          one reason of the line-count limit, written on that file's head. Both tables are
///          dispatched by **this class's single switch**, so the name and the description on one card
///          cannot come from two languages. **Formulas, parameter labels, units, group names**
///          (`tool.formula`, `input.label`, `input.unit`, `input.key`, `result.label`, `tool.group`)
///          still live in `tool_catalog*.dart` and `tool_insights_*.dart` and are still Chinese today —
///          a **known remainder**, of the same kind as the ones listed on `tools_strings.dart`'s file
///          head, and its size is measured in `.superpowers/backup/tool-descriptions-report.md`. The
///          "matched …" line in a search result (`ToolSearchResult.matchLabel` / `matchText`) is
///          untouched too: it is part of search matching itself, which this round does not touch.
@immutable
class ToolCatalogStrings {
  const ToolCatalogStrings({
    required this.toolNames,
    required this.toolDescriptions,
    required this.mathTitle,
    required this.mathSubtitle,
    required this.electronicsTitle,
    required this.electronicsSubtitle,
    required this.mechanicalTitle,
    required this.mechanicalSubtitle,
    required this.financeTitle,
    required this.financeSubtitle,
    required this.scienceTitle,
    required this.scienceSubtitle,
    required this.unitsTitle,
    required this.unitsSubtitle,
    required this.programmingTitle,
    required this.programmingSubtitle,
    required this.customTitle,
    required this.customSubtitle,
  });

  /// 中文：**工具 id → 名字**。八分类那种"封闭集合"这里用不了字段名：ids 来自目录，字段名给不了
  ///       编译期完整性（没有任何东西把字段和目录里的 id 绑起来），而 117 条 × 四行（构造参数、
  ///       字段、两份表）正好把文件顶到八百行。完整性交给 `tool_catalog_strings_test.dart` 里那条
  ///       遍历 `toolCatalog` 的断言，与 `settings_strings_test.dart` 遍历 `CalcTheme.all` 同一种做法。
  /// English: **tool id → name.** The named-field treatment the eight categories get cannot be used
  ///          here: the ids come from the catalogue, so field names would not give compile-time
  ///          completeness (nothing ties a field to a catalogue id), and 117 entries × four lines
  ///          (constructor parameter, field, two tables) would put this file against the 800-line
  ///          limit. Completeness is carried by the assertion in `tool_catalog_strings_test.dart` that
  ///          walks `toolCatalog` — the same trick `settings_strings_test.dart` uses for `CalcTheme.all`.
  final Map<String, String> toolNames;

  /// 中文：**工具 id → 描述**。与 [toolNames] 同一批 id、同一条回落、同一次分派；两张表住在两个
  ///       文件里只是为了行数，理由写在 `tool_description_strings.dart` 的文件头上。
  ///       完整性同样交给 `tool_description_strings_test.dart` 里那条遍历 `toolCatalog` 的断言。
  /// English: **tool id → description.** The same ids, the same fallback and the same dispatch as
  ///          [toolNames]; the two tables live in two files purely for the line limit, and the reason
  ///          is on `tool_description_strings.dart`'s file head. Completeness is carried by the
  ///          assertion in `tool_description_strings_test.dart` that walks `toolCatalog`.
  final Map<String, String> toolDescriptions;

  // —— 分类：八个，封闭集合，所以用命名字段：加第九个分类会让下面两个 switch 编译不过。——
  final String mathTitle;
  final String mathSubtitle;
  final String electronicsTitle;
  final String electronicsSubtitle;
  final String mechanicalTitle;
  final String mechanicalSubtitle;
  final String financeTitle;
  final String financeSubtitle;
  final String scienceTitle;
  final String scienceSubtitle;
  final String unitsTitle;
  final String unitsSubtitle;
  final String programmingTitle;
  final String programmingSubtitle;
  final String customTitle;
  final String customSubtitle;

  /// 中文：工具名。认不出的 id 回落到目录里那一条的中文名，再不行才回落到 id 本身——理由见文件头。
  /// English: A tool's name. An unrecognised id falls back to that entry's Chinese title in the
  ///          catalogue, and only then to the id itself — see the file head.
  String toolName(String toolId) {
    return toolNames[toolId] ?? toolById(toolId)?.title ?? toolId;
  }

  /// 中文：工具描述，卡片上名字下面那一行。回落到目录里那一条的 `description`（今天屏幕上的中文），
  ///       再不行才回落到空串——**名字有 id 可以回落到最后，描述没有**，一句空话好过把 id 印在
  ///       说明的位置上。理由与 [toolName] 那条同。
  /// English: A tool's description, the line under the name on a card. It falls back to that entry's
  ///          `description` in the catalogue (the Chinese on screen today) and only then to the empty
  ///          string — **a name can fall back to the id as a last resort, a description cannot**; an
  ///          empty sentence beats printing an id where a description belongs. Same reasoning as
  ///          [toolName].
  String toolDescription(String toolId) {
    return toolDescriptions[toolId] ?? toolById(toolId)?.description ?? '';
  }

  /// 中文：分类名。**switch 必须穷尽 `ToolCategory`**——加第九个分类时这里编译不过，而不是静默
  ///       回落到中文，这条保证与 `of` 对 `AppLanguage` 的那条是同一件事。
  /// English: A category's name. The **switch must exhaust `ToolCategory`** so adding a ninth category
  ///          breaks the build here rather than silently falling back to Chinese — the same guarantee
  ///          `of` gives for `AppLanguage`.
  String categoryTitle(ToolCategory category) {
    return switch (category) {
      ToolCategory.math => mathTitle,
      ToolCategory.electronics => electronicsTitle,
      ToolCategory.mechanical => mechanicalTitle,
      ToolCategory.finance => financeTitle,
      ToolCategory.science => scienceTitle,
      ToolCategory.units => unitsTitle,
      ToolCategory.programming => programmingTitle,
      ToolCategory.custom => customTitle,
    };
  }

  /// 中文：分类说明，跟在分类名下面那一行。穷尽性与 [categoryTitle] 同。
  ///
  ///       **今天屏幕上没有一处读它。** 唯一读 `ToolCategory.subtitle` 的地方是
  ///       `ToolSearch.rankTool` / `tokenMatch` 的匹配打分（`lib/application/controllers/
  ///       tool_search_engine.dart` 的 138、217 行），而检索匹配本轮明确不碰。这一格因此是
  ///       **为下一轮备好的**：检索一旦按语言取词，它就该从这里取。写它是因为分类的"名字 + 说明"
  ///       是一对，只留一半会让这张表看起来像漏了；**不要**为了让它上屏而往分类卡上加字——
  ///       那会改掉默认态（中文界面上今天没有这行字）。
  /// English: A category's description, the line under its name. Exhaustive for the same reason as
  ///          [categoryTitle].
  ///
  ///          **Nothing on screen reads it today.** The only reader of `ToolCategory.subtitle` is the
  ///          match scoring in `ToolSearch.rankTool` / `tokenMatch`
  ///          (`lib/application/controllers/tool_search_engine.dart`, lines 138 and 217), and search
  ///          matching is explicitly out of this round's scope. This cell is therefore **prepared for
  ///          a later round**: once search takes its words by language, it should take them from here.
  ///          It is written because a category's name and description are one pair, and leaving half
  ///          of it out would make the table look incomplete; **do not** put it on a category card
  ///          just to make it visible — that would move the default state (no such line is on screen
  ///          in Chinese today).
  String categorySubtitle(ToolCategory category) {
    return switch (category) {
      ToolCategory.math => mathSubtitle,
      ToolCategory.electronics => electronicsSubtitle,
      ToolCategory.mechanical => mechanicalSubtitle,
      ToolCategory.finance => financeSubtitle,
      ToolCategory.science => scienceSubtitle,
      ToolCategory.units => unitsSubtitle,
      ToolCategory.programming => programmingSubtitle,
      ToolCategory.custom => customSubtitle,
    };
  }

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过，
  ///       而不是静默回落到中文。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here rather than silently falling back to Chinese.
  static ToolCatalogStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。两条路径共用这一个
  ///       switch，不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext`. Both routes share this
  ///          one switch, so they cannot drift apart.
  static ToolCatalogStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => toolCatalogZh,
      AppLanguage.en => toolCatalogEn,
    };
  }

  /// 中文：中文表。**逐条写出来**，与 `tool_catalog*.dart` 里那些 `title` 逐字节相同，
  ///       `tool_catalog_strings_test.dart` 拿 `toolCatalog` 逐条钉住。
  ///
  ///       **这两张表是 `static const`，与兄弟表的 `static final` 不同，原因是它们真的能 const。**
  ///       设置页那张表里带参数的文案是闭包，闭包不是常量表达式，所以那边非 `static final` 不可
  ///       （理由写在 `settings_strings.dart` 文件头）。这张表一条带参数的文案都没有，全部是常量，
  ///       `analysis_options.yaml` 里的 `prefer_const_constructors` 也要求写 `const`——能用更严的
  ///       形态就用更严的：整张表在编译期就定下来了。
  /// English: The Chinese table, **written out entry by entry**, byte-identical to the `title` fields
  ///          in `tool_catalog*.dart`; `tool_catalog_strings_test.dart` pins it against `toolCatalog`.
  ///
  ///          **These two tables are `static const`, where their siblings are `static final`, because
  ///          they genuinely can be.** The settings table holds parameterised copy as closures, and a
  ///          closure is not a constant expression, so that one cannot be `static final`'s const
  ///          sibling (the reasoning is on `settings_strings.dart`'s file head). This table has not
  ///          one parameterised string — every entry is a constant — and `prefer_const_constructors`
  ///          in `analysis_options.yaml` asks for `const` anyway. Where the stricter form is
  ///          available, take it: the whole table is fixed at compile time.
  static const ToolCatalogStrings toolCatalogZh = ToolCatalogStrings(
    toolNames: {
      'quadratic': '二次方程',
      'linear_system': '方程组',
      'percentage': '百分比',
      'exponential_log': '指数对数',
      'linear_equation': '一元一次方程',
      'proportion': '比例计算',
      'combination': '排列组合',
      'probability': '概率计算',
      'statistics': '统计计算',
      'data_fit': '数据拟合图表',
      'matrix': '矩阵计算',
      'complex': '复数计算',
      'vector': '向量计算',
      'triangle': '三角形计算',
      'circle': '圆形计算',
      'scale_ratio': '比例缩放',
      'ohms_law': '欧姆定律',
      'voltage_divider': '电阻分压',
      'rc_filter': 'RC滤波',
      'dbm': 'dBm换算',
      'resistor_network': '电阻串并联',
      'capacitor_network': '电容串并联',
      'inductor_network': '电感串并联',
      'led_resistor': 'LED限流电阻',
      'op_amp_gain': '运放增益',
      'adc_resolution': 'ADC分辨率',
      'rms_peak': 'Vrms/Vpp换算',
      'lc_resonance': 'LC谐振',
      'dcdc_feedback': 'DCDC反馈',
      'ldo_power': 'LDO功耗',
      'capacitor_charge': '电容充放电',
      'battery_life': '电池续航',
      'pcb_current': 'PCB走线电流',
      'wire_voltage_drop': '电线压降',
      'timer_555': '555定时器',
      'thermal_rise': '热阻温升',
      'gear_ratio': '齿轮比',
      'torque_power': '扭矩功率换算',
      'spring': '弹簧刚度',
      'cylinder': '气缸推力',
      'force': '力/质量/加速度',
      'pulley_ratio': '皮带轮转速比',
      'screw_lead': '丝杆导程',
      'pressure_force': '压力面积力',
      'friction': '摩擦力',
      'inclined_plane': '斜面受力',
      'beam_bending': '梁弯曲基础',
      'stress_strain': '应力应变',
      'section_area': '截面属性计算',
      'safety_factor': '安全系数',
      'flow_velocity': '流量管径流速',
      'material_weight': '材料重量',
      'loan': '贷款月供',
      'annuity': '年金终值',
      'installment': '分期付款',
      'break_even': '盈亏平衡',
      'electricity_cost': '电费计算',
      'compound': '复利计算',
      'profit_margin': '利润率',
      'roi': 'ROI',
      'discount': '折扣计算',
      'tax': '税前税后',
      'inflation': '通胀折算',
      'npv': 'NPV',
      'length': '长度',
      'area': '面积',
      'volume': '体积',
      'mass': '质量',
      'pressure': '压力',
      'speed': '速度',
      'temperature': '温度',
      'voltage': '电压',
      'frequency': '频率',
      'data_size': '数据单位',
      'time_unit': '时间',
      'acceleration': '加速度',
      'force_unit': '力',
      'power_unit': '功率',
      'energy_unit': '能量',
      'angle_unit': '角度',
      'current_unit': '电流',
      'resistance_unit': '电阻',
      'capacitance_unit': '电容',
      'inductance_unit': '电感',
      'torque_unit': '扭矩',
      'flow_unit': '流量',
      'motion': '速度时间距离',
      'free_fall': '自由落体',
      'work_power': '功与功率',
      'kinetic_energy': '动能势能',
      'density': '密度质量体积',
      'concentration': '浓度换算',
      'ideal_gas': '理想气体',
      'heat': '热量计算',
      'wavelength': '波长频率',
      'half_life': '半衰期',
      'ph': 'pH / pOH',
      'bmi': 'BMI',
      'fuel_economy': '油耗计算',
      'base_convert': '进制转换',
      'timestamp': '时间戳转换',
      'color_convert': 'RGB/HEX颜色',
      'base64': 'Base64',
      'url_codec': 'URL编码',
      'json_format': 'JSON格式化',
      'ascii_unicode': 'ASCII/Unicode',
      'bitwise': '位运算',
      'checksum': '校验和',
      'uuid': 'UUID生成',
      'jwt_decode': 'JWT解析',
      'query_params': 'Query参数',
      'html_entities': 'HTML实体',
      'regex_test': '正则测试',
      'text_stats': '文本统计',
      'csv_json': 'CSV转JSON',
      'fnv_crc': 'FNV/CRC32',
      'custom_formula': '自定义公式',
    },
    // 中文：描述那 117 条住在 `tool_description_strings.dart`，理由见文件头。
    // English: the 117 descriptions live in `tool_description_strings.dart`; the reason is on the file
    //          head.
    toolDescriptions: toolDescriptionsZh,
    mathTitle: '方程与数学',
    mathSubtitle: '多项式、方程组、统计与矩阵',
    electronicsTitle: '电路与电子',
    electronicsSubtitle: '分压、滤波、dBm 与电源计算',
    mechanicalTitle: '机械与工程',
    mechanicalSubtitle: '齿轮、扭矩、弹簧与气缸',
    financeTitle: '财务与商业',
    financeSubtitle: '贷款、复利、利润率与 ROI',
    scienceTitle: '物理与科学',
    scienceSubtitle: '运动、热量、浓度与波动',
    unitsTitle: '单位换算',
    unitsSubtitle: '长度、压力、电学和频率',
    programmingTitle: '编程与数据',
    programmingSubtitle: '进制、时间戳、编码与数据单位',
    customTitle: '自定义工具',
    customSubtitle: '个人公式和专属工作流',
  );

  /// 中文：**分类名为什么这么短——八个名字是按卡片宽度量出来的，不是随手缩的。**
  ///
  ///       **约束是从屏幕上的两句话里量出来的。** 分类卡是两列网格里的一格（`tools_home_page.dart`
  ///       的 `GridView.count`：`crossAxisCount: 2`、`crossAxisSpacing: 10`，外层 `ListView` 左右各
  ///       16），格内一行是「36 的图标盒 + 10 的间距 + 文字」，`CategoryCard` 自己还有 12 的内边距
  ///       与 1dp 的边框（`Container` 会把 `Border` 的尺寸并进 padding）。于是那行标题的可用宽度是
  ///       **`(W - 42) / 2 - 72`**（W 是逻辑宽度）：412 宽时是 113.0dp，这一条不是推的，
  ///       是从渲染树里读出来的（`tool_catalog_strings_test.dart` 里那条护栏读的就是它）。
  ///       标题的字号也不是默认值：`TextStyle` 只写了 `fontWeight: w800`，其余从 `bodyMedium`
  ///       并进来，所以是 **14px + 0.25 字距**（同样在渲染树上量过）。
  ///
  ///       **设备上那两根标尺**（用户报的，不是本仓库量的）：`Custom Tools` 完整显示，
  ///       `Unit Conversion` 被截成 `Unit Convers…`。按上一条样式量这两串，分别是 **91.0dp** 与
  ///       **105.0dp**——于是这台机器上"能放下"的门槛落在 (91.0, 105.0) 之间，而**它自己新名字的
  ///       上限就取在这条缝里**：八个名字一律 **≤ 85dp**（= 已知能放下的那串的 93%，已知放不下的
  ///       那串的 81%）。最宽的一个是 `Code & Data` 80.4dp，即 88.4%。
  ///
  ///       **这条判断不靠"我猜设备用哪个字重、哪个 dpr"。** 它靠的是一个**排序**：只要每个新名字都
  ///       比屏幕上已经证明放得下的那串更窄，它就能放下。排序用九套互不相干的字体（SDK 的
  ///       Roboto 三个字重、DejaVu、Liberation、Arial、Georgia、Noto Mono…）交叉验过：七改一留
  ///       全都在 `Custom Tools` 之下（最紧的 `Code & Data` 在 DejaVu Sans Bold 下是 92.7%），
  ///       而旧的七条在每一套字体下都是它的 113%–183%——**这正是屏幕上看到的那片截断**。
  ///       字距与字号都是线性缩放，所以**这条排序与系统字体缩放无关**，换 dpr 也不动。
  ///
  ///       **八个名字的来路与代价**（`旧 → 新`，宽度是 Roboto-Black @14px+0.25 的实测值；
  ///       Bold 比它窄不到 0.5%，取 Black 是取上限）：
  ///         · `Equations & Math` 115.4 → **`Maths`** 40.8 —— 丢"方程"两字；`Maths` 是**英式**，
  ///           与仓库既有的 `favourites` / `Colour` / `normalise` 同一套拼法（要美式就改 `Math`）。
  ///         · `Circuits & Electronics` 142.0 → **`Circuits`** 51.3 —— 丢"电子"一词，电路那一半还在。
  ///         · `Mechanical Engineering` 157.7 → **`Mechanical`** 75.3 —— 原来的第一个词，
  ///           "工程"那一半由它代着（`Mechanics` 更短 70.9，但那是力学，会与科学分类撞）。
  ///         · `Finance & Business` 128.3 → **`Finance`** 51.4 —— 丢"商业"一词，十二个工具里
  ///           贷款、复利、利润、ROI、税、通胀全是财务。
  ///         · `Physics & Science` 120.7 → **`Science`** 52.0 —— 丢"物理"一词；这一格里有 pH、
  ///           BMI、油耗，`Science` 是那个能把它们都装下的伞（`Physics` 装不下）。
  ///         · `Unit Conversion` 105.0 → **`Units`** 34.3 —— 丢"换算"一词；22 个工具全是换算器，
  ///           卡片图标本来就是 `swap_horiz`。`Conversion`（74.4）会被误读成进制/时间戳换算，
  ///           那两条在**编程**那一格。
  ///         · `Programming & Data` 136.6 → **`Code & Data`** 80.4 —— 一词没丢，只把两半摆短；
  ///           这是八个里最宽的一个（88.4%）。
  ///         · `Custom Tools` 91.0 → **`Custom`** 50.5 —— 一句实话：这一串**在设备上是量过能放下的**，
  ///           本来可以一个字节都不动。改它的唯一理由是 360dp 宽的手机上那行只有 87dp，
  ///           91.0 会截断；改成 50.5 之后**八个名字在 ≥360dp 的屏上都完整**（320dp 上仍有
  ///           `Mechanical` 与 `Code & Data` 两条放不下，那是更小的屏，本轮不追）。
  ///
  ///       **为什么不动卡片布局。** 换行（`maxLines: 2`）会吃竖直空间：卡片高度由
  ///       `childAspectRatio: 1.85` 定死，320dp 宽时内容区只有 49.1dp，而两行标题 + 那行
  ///       `16 tools` 要 59.2dp——**在窄屏上会从"截断"变成"溢出"**，那是更坏的失败。要让它安全就得
  ///       同时压 `childAspectRatio`，而**卡片变高会改掉中文侧的渲染**（同样八个格、同样那行计数，
  ///       位置全动），这正是本轮不许碰的东西。把字号调小或把图标盒改窄同样会动中文那一侧。
  ///       **本轮一个布局字节都没改**：中文侧因此不是"验过没变"，而是**没有可变的路径**。
  /// English: **Why the category names are this short — the eight were measured against the card, not
  ///          trimmed by feel.**
  ///
  ///          **The constraint comes from two sentences measured on the screen.** A category card is one
  ///          cell of a two-column grid (`tools_home_page.dart`'s `GridView.count`: `crossAxisCount: 2`,
  ///          `crossAxisSpacing: 10`, inside a `ListView` with 16 on each side), and the cell is one row
  ///          of "36 icon box + 10 gap + text"; `CategoryCard` itself carries 12 of padding and a 1dp
  ///          border (`Container` folds a `Border`'s dimensions into its padding). The title line's
  ///          available width is therefore **`(W - 42) / 2 - 72`** (W = logical width): 113.0dp at 412.
  ///          That is not deduced — it is read off the render tree (the guard in
  ///          `tool_catalog_strings_test.dart` reads exactly this). The title's type is not the default
  ///          either: the `TextStyle` sets only `fontWeight: w800` and inherits the rest from
  ///          `bodyMedium`, so it is **14px + 0.25 letter-spacing** (measured on the render tree too).
  ///
  ///          **The two rulers come from the device** (reported by the user, not measured here):
  ///          `Custom Tools` renders in full and `Unit Conversion` is cut to `Unit Convers…`. Measured
  ///          in the style above those two strings are **91.0dp** and **105.0dp** — so the "fits"
  ///          threshold on that handset lies inside (91.0, 105.0), and **the new names take their ceiling
  ///          from inside that gap**: all eight are **≤ 85dp** (93% of the string known to fit, 81% of
  ///          the one known not to). The widest, `Code & Data`, is 80.4dp — 88.4%.
  ///
  ///          **This judgement does not rest on guessing the device's weight or dpr.** It rests on an
  ///          **ordering**: if every new name is narrower than a string already proven to fit on screen,
  ///          it fits. That ordering was cross-checked in nine unrelated typefaces (three weights of the
  ///          SDK's Roboto, DejaVu, Liberation, Arial, Georgia, Noto Mono…): all eight stay under
  ///          `Custom Tools` (the tightest, `Code & Data`, at 92.7% under DejaVu Sans Bold), while the
  ///          seven old names run at 113%–183% of it in *every* one of them — **which is exactly the
  ///          truncation seen on the screen**. Letter-spacing and font size are both linear, so **the
  ///          ordering is independent of the system font scale** and does not move with dpr.
  ///
  ///          **Where each of the eight comes from, and what it gives up** (`old → new`; widths measured
  ///          in Roboto-Black at 14px + 0.25 — Bold is under 0.5% narrower, so Black is the ceiling):
  ///            · `Equations & Math` 115.4 → **`Maths`** 40.8 — gives up the word "equations"; `Maths` is
  ///              **British**, matching the repository's existing `favourites` / `Colour` / `normalise`
  ///              (`Math` if American is wanted).
  ///            · `Circuits & Electronics` 142.0 → **`Circuits`** 51.3 — gives up "electronics"; the
  ///              circuit half stays.
  ///            · `Mechanical Engineering` 157.7 → **`Mechanical`** 75.3 — the original's first word,
  ///              standing in for the "engineering" half (`Mechanics` is shorter at 70.9, but that is
  ///              the physics term and would collide with the science category).
  ///            · `Finance & Business` 128.3 → **`Finance`** 51.4 — gives up "business"; of the twelve
  ///              tools, loans, interest, margin, ROI, tax and inflation are all finance.
  ///            · `Physics & Science` 120.7 → **`Science`** 52.0 — gives up "physics"; this cell holds
  ///              pH, BMI and fuel economy too, and `Science` is the umbrella that covers them
  ///              (`Physics` does not).
  ///            · `Unit Conversion` 105.0 → **`Units`** 34.3 — gives up "conversion"; all 22 tools are
  ///              converters and the card's icon is already `swap_horiz`. `Conversion` (74.4) would read
  ///              as base or timestamp conversion, and those two sit in the **programming** cell.
  ///            · `Programming & Data` 136.6 → **`Code & Data`** 80.4 — not a word dropped, just the two
  ///              halves kept short; it is the widest of the eight (88.4%).
  ///            · `Custom Tools` 91.0 → **`Custom`** 50.5 — honestly: that string **was measured to fit
  ///              on the device** and could have been left alone. The one reason to change it is that a
  ///              360dp-wide handset gives that line 87dp, where 91.0 truncates; at 50.5 **all eight
  ///              names are complete on any screen ≥360dp wide** (at 320dp `Mechanical` and
  ///              `Code & Data` still do not fit — a smaller screen than this round chases).
  ///
  ///          **Why the card layout was not touched.** Wrapping (`maxLines: 2`) costs vertical space: the
  ///          card's height is pinned by `childAspectRatio: 1.85`, at 320dp the content area is 49.1dp,
  ///          and a two-line title plus the `16 tools` line needs 59.2dp — **on a narrow screen that
  ///          turns a truncation into an overflow**, a worse failure. Making it safe means lowering
  ///          `childAspectRatio` too, and **taller cards move the Chinese side's rendering** (same eight
  ///          cells, same count line, every position shifted) — precisely what this round must not
  ///          touch. Shrinking the face or the icon box moves the Chinese side as well. **Not one layout
  ///          byte changed this round**: the Chinese side is therefore not "checked unchanged" but has
  ///          **no path by which it could change**.
  static const ToolCatalogStrings toolCatalogEn = ToolCatalogStrings(
    toolNames: {
      'quadratic': 'Quadratic Equation', // B · no alias in either index
      'linear_system': 'Linear System', // A · 'linear system'
      'percentage': 'Percentage Calculator', // A · 'percentage calculator'
      'exponential_log':
          'Exponent / Logarithm', // A · 'exponent logarithm' · slash = typography for the juxtaposed pair
      'linear_equation': 'Linear Equation', // A · 'linear equation'
      'proportion': 'Proportion Calculator', // A · 'proportion calculator'
      'combination': 'Combination', // A · 'combination'
      'probability': 'Probability Calculator', // A · 'probability calculator'
      'statistics': 'Statistics', // A · 'statistics'
      'data_fit':
          'Curve Fitting', // A · 'curve fitting' · first entry "regression" names one model
      'matrix': 'Matrix Calculator', // A · 'matrix calculator'
      'complex': 'Complex Calculator', // A · 'complex calculator'
      'vector': 'Vector Calculator', // A · 'vector calculator'
      'triangle': 'Triangle Calculator', // A · 'triangle calculator'
      'circle': 'Circle Calculator', // A · 'circle calculator'
      'scale_ratio': 'Scale Ratio', // A · 'scale ratio'
      'ohms_law': 'Ohms Law', // A · 'ohms law'
      'voltage_divider': 'Voltage Divider', // A · 'voltage divider'
      'rc_filter': 'RC Filter', // A · 'rc filter'
      'dbm': 'dBm Conversion', // B · no alias in either index
      'resistor_network': 'Resistor Network', // A · 'resistor network'
      'capacitor_network': 'Capacitor Network', // A · 'capacitor network'
      'inductor_network': 'Inductor Network', // A · 'inductor network'
      'led_resistor': 'LED Resistor', // A · 'led resistor'
      'op_amp_gain': 'Op-Amp Gain', // A · 'op amp gain' · hyphen = orthography
      'adc_resolution': 'ADC Resolution', // A · 'adc resolution'
      'rms_peak': 'Vrms / Vpp', // A · 'vrms vpp' · slash = typography
      'lc_resonance': 'LC Resonance', // A · 'lc resonance'
      'dcdc_feedback':
          'DC-DC Feedback', // A · 'dcdc feedback' · first entry "buck feedback" names one topology
      'ldo_power': 'LDO Thermal', // A · 'ldo thermal'
      'capacitor_charge':
          'Capacitor Charge', // A · 'capacitor charge' · first entry "rc charge" names the circuit, not the subject
      'battery_life': 'Battery Runtime', // A · 'battery runtime'
      'pcb_current': 'PCB Trace Current', // A · 'pcb trace current'
      'wire_voltage_drop': 'Wire Voltage Drop', // A · 'wire voltage drop'
      'timer_555': '555 Timer', // A · '555 timer'
      'thermal_rise': 'Thermal Rise', // A · 'thermal rise'
      'gear_ratio': 'Gear Ratio', // A · 'gear ratio'
      'torque_power':
          'Torque / Power', // A · 'torque power' · slash = typography
      'spring': 'Spring Stiffness', // A · 'spring stiffness'
      'cylinder': 'Cylinder Force', // A · 'cylinder force'
      'force':
          'Force / Mass / Acceleration', // A · 'force mass acceleration' · slash = the title’s own 力/质量/加速度
      'pulley_ratio': 'Pulley Ratio', // A · 'pulley ratio'
      'screw_lead': 'Screw Lead', // A · 'screw lead'
      'pressure_force':
          'Pressure / Area / Force', // A · 'pressure area force' · first entry omits one of the three inputs
      'friction': 'Friction Force', // B · no alias in either index
      'inclined_plane': 'Inclined Plane', // B · no alias in either index
      'beam_bending': 'Beam Bending', // A · 'beam bending'
      'stress_strain':
          'Stress and Strain', // A · 'stress and strain' · same words as entry 1, with its coordinator
      'section_area':
          'Section Properties', // A · 'section properties' · first entry names one output
      'safety_factor': 'Safety Factor', // A · 'safety factor'
      'flow_velocity': 'Pipe Flow', // B · no alias in either index
      'material_weight': 'Material Weight', // B · no alias in either index
      'loan': 'Loan Calculator', // A · 'loan calculator'
      'annuity': 'Annuity Calculator', // A · 'annuity calculator'
      'installment': 'Installment Calculator', // A · 'installment calculator'
      'break_even': 'Break-Even', // A · 'break even' · hyphen = orthography
      'electricity_cost': 'Electricity Cost', // A · 'electricity cost'
      'compound': 'Compound Interest', // A · 'compound interest'
      'profit_margin': 'Profit Margin', // A · 'profit margin'
      'roi': 'Return on Investment', // A · 'return on investment'
      'discount': 'Discount Calculator', // A · 'discount calculator'
      'tax': 'Tax Calculator', // A · 'tax calculator'
      'inflation': 'Inflation Calculator', // A · 'inflation calculator'
      'npv': 'Net Present Value', // A · 'net present value'
      'length': 'Length Converter', // A · 'length converter'
      'area': 'Area Converter', // A · 'area converter'
      'volume': 'Volume Converter', // A · 'volume converter'
      'mass': 'Mass Converter', // A · 'mass converter'
      'pressure': 'Pressure Converter', // A · 'pressure converter'
      'speed': 'Speed Converter', // A · 'speed converter'
      'temperature': 'Temperature Converter', // A · 'temperature converter'
      'voltage': 'Voltage Converter', // A · 'voltage converter'
      'frequency': 'Frequency Converter', // A · 'frequency converter'
      'data_size':
          'Data Size Converter', // A · 'data size converter' · first two entries name one unit
      'time_unit': 'Time Converter', // A · 'time converter'
      'acceleration': 'Acceleration Converter', // A · 'acceleration converter'
      'force_unit': 'Force Converter', // A · 'force converter'
      'power_unit': 'Power Converter', // A · 'power converter'
      'energy_unit': 'Energy Converter', // A · 'energy converter'
      'angle_unit': 'Angle Converter', // A · 'angle converter'
      'current_unit': 'Current Converter', // A · 'current converter'
      'resistance_unit': 'Resistance Converter', // A · 'resistance converter'
      'capacitance_unit':
          'Capacitance Converter', // A · 'capacitance converter'
      'inductance_unit': 'Inductance Converter', // A · 'inductance converter'
      'torque_unit': 'Torque Converter', // A · 'torque converter'
      'flow_unit': 'Flow Converter', // A · 'flow converter'
      'motion':
          'Distance / Time / Speed', // A · 'distance time speed' · slash = typography
      'free_fall': 'Free Fall', // A · 'free fall'
      'work_power': 'Work / Power', // A · 'work power' · slash = typography
      'kinetic_energy': 'Kinetic Energy', // A · 'kinetic energy'
      'density': 'Density Calculator', // A · 'density calculator'
      'concentration': 'Concentration', // A · 'concentration'
      'ideal_gas': 'Ideal Gas', // A · 'ideal gas'
      'heat': 'Heat', // A · 'heat'
      'wavelength': 'Wavelength', // A · 'wavelength'
      'half_life': 'Half-Life', // A · 'half life' · hyphen = orthography
      'ph': 'pH / pOH', // L · title already Latin
      'bmi': 'Body Mass Index', // A · 'body mass index'
      'fuel_economy': 'Fuel Economy', // A · 'fuel economy'
      'base_convert': 'Base Conversion', // B · no alias in either index
      'timestamp':
          'Timestamp Converter', // B · four entries: three name a quantity, one is a verb phrase
      'color_convert': 'Hex Colour', // A · 'hex color'
      'base64': 'Base64', // L · title already Latin
      'url_codec':
          'URL Encoding', // B · entries are verb phrases ("url encode"), not names
      'json_format': 'JSON Formatter', // A · 'json formatter'
      'ascii_unicode': 'ASCII/Unicode', // L · title already Latin
      'bitwise': 'Bitwise Operations', // B · no alias in either index
      'checksum':
          'Checksum', // A · 'checksum' · first three entries name the algorithms, not the tool
      'uuid':
          'UUID Generator', // B · entries name the data type or a sub-case, not the tool
      'jwt_decode':
          'JWT Decoder', // B · entries name token kinds and claim terms, not the tool
      'query_params': 'Query String', // A · 'query string'
      'html_entities': 'HTML Entity', // A · 'html entity'
      'regex_test': 'Regex', // A · 'regex'
      'text_stats':
          'Text Statistics', // B · entries name individual counts, not the tool
      'csv_json': 'CSV to JSON', // A · 'csv to json'
      'fnv_crc': 'FNV/CRC32', // L · title already Latin
      'custom_formula': 'Custom Formula', // B · no alias in either index
    },
    toolDescriptions: toolDescriptionsEn,
    // —— 分类名：八个都是**按卡片宽度量出来的**，理由与数字见本表头上那段「分类名为什么这么短」。——
    mathTitle: 'Maths',
    mathSubtitle: 'Polynomials, systems, statistics and matrices',
    electronicsTitle: 'Circuits',
    electronicsSubtitle: 'Dividers, filters, dBm and power calculations',
    mechanicalTitle: 'Mechanical',
    mechanicalSubtitle: 'Gears, torque, springs and cylinders',
    financeTitle: 'Finance',
    financeSubtitle: 'Loans, compound interest, margins and ROI',
    scienceTitle: 'Science',
    scienceSubtitle: 'Motion, heat, concentration and waves',
    unitsTitle: 'Units',
    unitsSubtitle: 'Length, pressure, electrical units and frequency',
    programmingTitle: 'Code & Data',
    programmingSubtitle: 'Number bases, timestamps, encoding and data units',
    customTitle: 'Custom',
    customSubtitle: 'Your own formulas and workflows',
  );
}
