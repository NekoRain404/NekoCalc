/// 中文：**工具结果卡上那一大格**——`result.label` 的英文，**715 条**。
///       这是工具子树最后一块中文：名字、分类、外壳、命中提示、描述、参数标签、单位、公式、
///       解释都已在表里，剩下的是每个结果行左边那句话。
///
///       **机制与三张兄弟表逐字相同，不重抄**（键是中文本身、中文那一侧没有表、回落是 `?? 键`、
///       为什么是手写分表而不是 ARB）：写在 `tool_field_strings.dart` 的文件头上。本文件只写
///       **这张表自己的三件事**。
///
///       —— 一、规模：**715 条**，一条都没有可对照的东西 ——
///       逐条量过：16 个 `lib/domain/usecases/calculate_tool*.dart` 里
///       `ToolResult(...)` / `.number(...)` / `.invalid(...)` 的**第一个位置参数**（标签是位置参数，
///       不是具名参数——按 `label:` 去数会数到 **0**，这是这张表最容易被量错的地方）
///       一共 **1784 处**，其中第一个实参是字符串字面量的 **1774 处**（另外 10 处第一个实参是形参：
///       `tool_definition.dart` 里那 5 处是类型定义与构造函数本身，另 5 处是五个转发函数
///       （`_unitResults`、`_rangeResult`、`_resistorPowerRating`、`_complexResult`）的形参）。
///       **去重后 794 条，其中带汉字的 715 条**。剩下那 79 条整条都是记号（`dBW`、`Wh`、`m³`、
///       `ft²`、`mm²`…），两种语言逐字节相同，**一条都不进表**——
///       与兄弟表"没有可翻的东西就不进表"是同一条口径。
///       **这 715 条在仓库里没有第二份**：两处检索索引里没有 `result.label`
///       （见下面第三条），`calculate_tool*.dart` 里只有中文一份。所以本轮和上一轮一样
///       **全部是新写的**，报告里那张逐条对照表是它唯一的复核面。
///
///       —— 二、为什么是六个文件，缝在哪儿 ——
///       判据是这棵子树一直在用的那条（"读者知道该打开哪一个"），**不是 800 行硬线**
///       （715 条并进一个文件约 790 行，是真会顶到线，但那不是分开的理由）。缝取的是
///       **结果属于哪个工具分类**，因为这条缝本来就在仓库里：`tool_catalog_math.dart` /
///       `_electronics.dart` / `_mechanical.dart` / `_finance.dart` / `_science.dart` 就是这么分的
///       （见 `tool_catalog.dart` 的六路展开），而每一个工具分类恰好对应一组计算文件：
///         · `tool_result_label_strings_math.dart` —— 106 条（`calculate_tool_math*.dart`）
///         · `tool_result_label_strings_electronics.dart` —— 221 条（`_basic_electronics`/`_signal`/`_power`）
///         · `tool_result_label_strings_mechanical.dart` —— 137 条（`_mechanical`/`_structure`）
///         · `tool_result_label_strings_finance.dart` —— 107 条（`_finance`/`_finance_business`/`_finance_growth`）
///         · `tool_result_label_strings_science.dart` —— 124 条（`_physics`/`_physics_matter`/`_physics_waves`/`_lifestyle`）
///         · 本文件 —— **19 条两个以上分类都会产出的**（`功率`、`效率`、`截面积`、`输入来源`…）
///           外加 `calculate_tool.dart` 里那一条 `文本工具`
///       单位换算那一类（`calculate_tool_units.dart`）**一个文件都没有**：它的标签全是 `m`、`kg`、
///       `kPa` 这种符号，715 条里一条都不属于它。
///       **跨分类的 19 条不能留在任何一个分类文件里**——放哪一边，另一边就是错的；所以它们在
///       本文件里，理由写在表头上。**六个 map 互不相交是编译器保证的**：下面那个合并用的是
///       `const` 展开，Dart 对常量 map 的重复键是**编译期错误**，所以"同一条中文在两张表里各写
///       一份、屏幕上由加载顺序决定读哪一份"这件事**写不出来**。
///
///       —— 三、检索一个字节没动 ——
///       `result.label` **本来就不进检索**：`tool_search_engine.dart` 的 `rankTool` 读的是
///       `title` / `description` / `formula` / `explanation` / `group` / `category` / `inputs`，
///       `tokenMatch`、`bestTokenMatchText`、`suggestionPhrases` 也只收那几项与别名表；
///       `result.label` 在这三处**一次都没出现**（本轮逐处查过）。所以命中的字符串、分数与排序
///       与改动前逐条相同，本轮**没有碰引擎一行**。
///       本表**只被显示读**：`tool_widgets.dart` 的结果卡与 `tool_detail_screen.dart` 的主结果框。
///
///       —— 四、长度是量过的（这一格是**单行截断**，与前几轮不同）——
///       `DetailMetric` 里那句是 `Text(result.label, maxLines: 1, overflow: ellipsis)`，
///       所以"太长的英文"不是多占一行，而是**直接被省略号吃掉**。格宽从渲染树里读出来：
///       360dp 屏上结果卡是两列，格 **110.0dp**，字号 **12**、字距 **0.25**
///       （读法与数在 `tool_result_label_lengths_test.dart` 里）。
///       **判据因此比前几轮更硬：715 条英文一条都不许超过 110dp。** 逐条按
///       `roboto_regular_advances.dart` 那把尺子量过，**最宽的一条是 `Speed for tgt speed`
///       109.1dp**，12 条在 105dp 以上，其余都在 105 以下。
///       **中文那一侧一个字没动**：它今天有 6 条本来就超过 110dp（最长的是 `保留从动轮所需主动轮直径`
///       147.0dp），今天也照样被省略号截断，本轮没有为了给英文腾地方改动任何一条中文——
///       这正是"默认语言的那份不许让路"。
///       **为了塞进 110dp，这张表用了一套写下来的缩写**（其余几格不许随便用）：
///       `tgt` 目标 · `Accel.` 加速度 · `Defl.` 变形/挠度 · `Decel.` 减速度 · `Equiv.` 等效 ·
///       `temp` 温度 · `conc.` 浓度 · `ampl.` 幅值 · `wt` 重量 · `P` 功率 · `I` 电流 ·
///       `θJA` 结到环境热阻 · `SF` 安全系数 · `BE` 盈亏平衡 · `CF` 现金流 · `Proj.` 投影 ·
///       `Perms`/`Combns`/`Compl.` 排列/组合/互补 · `Disc.` 折现 · `ω` 角速度 ·
///       `dia` 直径 · `freq.` 频率 · `var.` 变动 · `KE` 动能 · `non-inv` 同相 · `inv` 反相。
///       符号在两种语言里是同一个（`ROI`、`pH`、`BMI 22`、`C(n,k)`、`20℃)`、`-2% NPV`…），
///       按 `test/shared/source_scan.dart` 的 `notationRuns` 逐段查过：**132 段记号，0 段丢失**。
///
///       ⚠️ **不在本轮的一格**：**复制出去的那份文本仍是中文。** `resultSummary()`、
///       `_resultReportLine()`、`singleResultCopyText()`（剪贴板与历史/笔记）读的还是 `result.label`
///       本身，一个字节没动——与上一轮"写笔记与剪贴板那几处是持久化，本轮一行未动"同一条边界。
///       屏幕上那句"已复制 X"里的 X 走本表（它是**渲染出来的字**），剪贴板里的 X 不走
///       （它是**复制出去的数据**）。英文界面下这两处因此不一致，这是本轮认下的代价。
/// English: **the result card's biggest cell** — the English of `result.label`, **715 entries**. This is
///          the tools subtree's last Chinese block: names, categories, chrome, match hints,
///          descriptions, parameter labels, units, formulas and explanations are all in tables; what is
///          left is the sentence on the left of every result row.
///
///          **The mechanism is character-for-character its three siblings' and is not copied here**
///          (the key is the Chinese itself, there is no Chinese-side table, the fallback is
///          `?? key`, and why these are hand-written tables rather than ARB): it is on
///          `tool_field_strings.dart`'s head. This file writes **the three things of its own**.
///
///          — 1. Size: **715 entries**, and not one of them had anything to be promoted from —
///          Measured: across the 16 `lib/domain/usecases/calculate_tool*.dart` files the **first
///          positional argument** of `ToolResult(...)` / `.number(...)` / `.invalid(...)` (the label is
///          positional, not named — counting on `label:` counts **0**, the easiest way to mis-measure
///          this table) occurs **1784** times, of which **1774** pass a string literal (in the other 10
///          the first argument is a parameter: the five in `tool_definition.dart` are the type
///          definition and its constructors, the other five are the parameters of the five forwarding
///          helpers `_unitResults`, `_rangeResult`, `_resistorPowerRating` and `_complexResult`).
///          **794 distinct, 715 of them holding a Han character**. The remaining 79 are notation end to
///          end (`dBW`, `Wh`, `m³`, `ft²`, `mm²`, …) and are byte-identical in both languages, so **not
///          one of them enters the table** —
///          the same rule as the siblings' "nothing to translate, nothing in the table".
///          **These 715 exist in exactly one place in the repository**: `result.label` is in neither
///          search index (see the third note below) and `calculate_tool*.dart` holds Chinese only. So
///          this round, like the last, is **authored in full**, and the entry-by-entry table in the
///          report is its only review surface.
///
///          — 2. Why six files, and where the seam is —
///          The criterion is the one this subtree has used all along ("the reader knows which file to
///          open"), **not the 800-line limit** (all 715 in one file would be about 790 lines and really
///          would touch the limit, but that is not the reason for splitting). The seam is **which tool
///          category the result belongs to**, because that seam already exists in the repository:
///          `tool_catalog_math.dart` / `_electronics.dart` / `_mechanical.dart` / `_finance.dart` /
///          `_science.dart` split that way (see the six-way spread in `tool_catalog.dart`), and each
///          category corresponds to a group of calculator files:
///            · `tool_result_label_strings_math.dart` — 106 (`calculate_tool_math*.dart`)
///            · `tool_result_label_strings_electronics.dart` — 221 (`_basic_electronics`/`_signal`/`_power`)
///            · `tool_result_label_strings_mechanical.dart` — 137 (`_mechanical`/`_structure`)
///            · `tool_result_label_strings_finance.dart` — 107 (`_finance`/`_finance_business`/`_finance_growth`)
///            · `tool_result_label_strings_science.dart` — 124 (`_physics`/`_physics_matter`/`_physics_waves`/`_lifestyle`)
///            · this file — **the 19 that two or more categories both produce** (`功率`, `效率`,
///              `截面积`, `输入来源`, …) plus the one `文本工具` literal in `calculate_tool.dart`
///          The unit-conversion family (`calculate_tool_units.dart`) **gets no file at all**: every one
///          of its labels is a symbol such as `m`, `kg`, `kPa`, and none of the 715 belongs to it.
///          **Those 19 cross-category entries cannot live in any one category's file** — put them on
///          either side and the other side is wrong, so they live here, with the reasoning on the
///          table's head. **The six maps being disjoint is guaranteed by the compiler**: the merge
///          below uses a `const` spread and Dart makes a duplicate key in a constant map a
///          **compile-time error**, so "one Chinese string written twice, the loaded one deciding what
///          the screen shows" **cannot be written**.
///
///          — 3. Search did not move by a byte —
///          `result.label` **never entered search**: `rankTool` in `tool_search_engine.dart` reads
///          `title` / `description` / `formula` / `explanation` / `group` / `category` / `inputs`, and
///          `tokenMatch`, `bestTokenMatchText` and `suggestionPhrases` collect only those and the alias
///          tables; `result.label` **does not occur once** in any of the three (checked site by site
///          this round). So the matched strings, the scores and the ordering are exactly as before, and
///          **not one line of the engine was touched**.
///          This table is **read for display only**: the result card in `tool_widgets.dart` and the
///          primary-result box in `tool_detail_screen.dart`.
///
///          — 4. Length is measured, and this cell is a **single truncated line** —
///          The sentence in `DetailMetric` is `Text(result.label, maxLines: 1, overflow: ellipsis)`, so
///          an over-long English label does not wrap, it is **eaten by an ellipsis**. The cell width was
///          read off the render tree: on a 360dp screen the result card is two columns, the cell is
///          **110.0dp**, the font size **12** and the letter spacing **0.25** (how they are read, and
///          the numbers, are in `tool_result_label_lengths_test.dart`).
///          **So the rule is harder than the previous rounds': not one of the 715 English labels may
///          exceed 110dp.** Measured entry by entry with the ruler in `roboto_regular_advances.dart`,
///          **the widest is `Speed for tgt speed` at 109.1dp**, twelve sit above 105dp and the rest
///          below.
///          **The Chinese side did not move by a character**: six of its labels already exceed 110dp
///          today (the longest, `保留从动轮所需主动轮直径`, at 147.0dp) and are already truncated by that
///          ellipsis; this round changed no Chinese label to make room for the English — which is what
///          "the default language's copy must not be the thing that gives way" means here.
///          **To fit 110dp the table uses a written-down set of abbreviations** (not to be sprinkled
///          elsewhere): `tgt` target · `Accel.` acceleration · `Defl.` deflection/deformation ·
///          `Decel.` deceleration · `Equiv.` equivalent · `temp` temperature · `conc.` concentration ·
///          `ampl.` amplitude · `wt` weight · `P` power · `I` current · `θJA` junction-to-ambient ·
///          `SF` safety factor · `BE` break-even · `CF` cash flow · `Proj.` projection ·
///          `Perms`/`Combns`/`Compl.` permutations/combinations/complement · `Disc.` discounted ·
///          `ω` angular speed · `dia` diameter · `freq.` frequency · `var.` variable · `KE` kinetic
///          energy · `non-inv` non-inverting · `inv` inverting.
///          Symbols are the same in both languages (`ROI`, `pH`, `BMI 22`, `C(n,k)`, `20℃)`,
///          `-2% NPV`, …) and were checked run by run with `notationRuns` from
///          `test/shared/source_scan.dart`: **132 runs, 0 lost**.
///
///          ⚠️ **The one cell not in this round: what is copied out is still Chinese.**
///          `resultSummary()`, `_resultReportLine()` and `singleResultCopyText()` (the clipboard, and
///          history and notes) still read `result.label` itself and not one byte moved — the same
///          boundary as the last round's "the note and clipboard sites are persistence and not one line
///          moved". The X in the on-screen "X copied" goes through this table (it is **rendered text**);
///          the X in the clipboard does not (it is **copied-out data**). In English those two therefore
///          disagree, and that is a cost this round knowingly accepts.
library;

import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';
import 'tool_result_label_strings_electronics.dart';
import 'tool_result_label_strings_finance.dart';
import 'tool_result_label_strings_math.dart';
import 'tool_result_label_strings_mechanical.dart';
import 'tool_result_label_strings_science.dart';

/// 中文：结果标签表。**一张 map，两种语言各一个实例**——中文那个是空 map（键就是屏幕上那句中文），
///       英文那个是下面六个文件的合并。
/// English: the result-label table. **One map, one instance per language** — the Chinese one is an
///          empty map (the key *is* the Chinese on screen), the English one merges the six files below.
@immutable
class ToolResultLabelStrings {
  const ToolResultLabelStrings(this.labels);

  /// 中文：**中文标签 → 英文**。查不到就原样返回——**"回落到中文"不需要写代码**，因为中文就是键。
  /// English: **Chinese label → English**. A miss returns its argument unchanged — **"fall back to
  ///          Chinese" needs no code**, because the Chinese *is* the key.
  final Map<String, String> labels;

  /// 中文：一个结果行左边那句话。回落见 [labels]。
  /// English: the sentence at the left of a result row. Fallback as on [labels].
  String label(String label) => labels[label] ?? label;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过。
  /// English: picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here.
  static ToolResultLabelStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。
  /// English: the same dispatch as [of], for callers without a `BuildContext`.
  static ToolResultLabelStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => toolResultLabelsZh,
      AppLanguage.en => toolResultLabelsEn,
    };
  }

  /// 中文：**中文表是空的，这是设计不是疏漏**（理由与 `ToolFieldStrings` 那五个空 map 相同）。
  /// English: **the Chinese table is empty on purpose** (the same reasoning as `ToolFieldStrings`'s
  ///          five empty maps).
  static const ToolResultLabelStrings toolResultLabelsZh =
      ToolResultLabelStrings({});

  /// 中文：英文表 = 六个文件合并。**重复键在这里是编译期错误**，所以六个文件必然互不相交。
  /// English: the English table merges six files. **A duplicate key is a compile-time error here**, so
  ///          the six files are necessarily disjoint.
  static const ToolResultLabelStrings toolResultLabelsEn =
      ToolResultLabelStrings(toolResultLabelsAllEn);
}

/// 中文：合并后的英文表，715 条。顺序只是读的顺序，**六个文件互不相交**（见文件头）。
/// English: the merged English table, 715 entries. The order is only reading order; **the six files are
///          disjoint** (see the file head).
const Map<String, String> toolResultLabelsAllEn = {
  ...toolResultLabelsSharedEn,
  ...toolResultLabelsMathEn,
  ...toolResultLabelsElectronicsEn,
  ...toolResultLabelsMechanicalEn,
  ...toolResultLabelsFinanceEn,
  ...toolResultLabelsScienceEn,
};

/// 中文：**两个以上工具分类都会产出的那 19 条**，外加 `calculate_tool.dart` 里那一条 `文本工具`
///       （文本工具没有计算，那一条是占位）。这 19 条放哪一边另一边就错，所以它们在这里。
///       逐条量过：`输入来源` 11 个计算文件里都有（速度、浓度、NPV、LDO…都要说"这个值是哪来的"），
///       `功率`/`输入功率`/`输出功率`/`损耗功率`/`瓦特`/`效率` 电子与机械两边都算，
///       `体积`/`面积`/`截面积`/`压力`/`周期`/`频率`/`天数`/`储能`/`运动方向`/`目标功率` 同理。
/// English: **the 19 that two or more tool categories both produce**, plus the one `文本工具` literal in
///          `calculate_tool.dart` (the text tools compute nothing; that entry is a placeholder). Putting
///          any of these on one side makes the other side wrong, so they are here. Measured entry by
///          entry: `输入来源` occurs in 11 calculator files (speed, concentration, NPV and LDO all have
///          to say where the value came from); `功率`/`输入功率`/`输出功率`/`损耗功率`/`瓦特`/`效率` are
///          computed on both the electronics and the mechanical side, and so are
///          `体积`/`面积`/`截面积`/`压力`/`周期`/`频率`/`天数`/`储能`/`运动方向`/`目标功率`.
const Map<String, String> toolResultLabelsSharedEn = {
  '输入来源': 'Input source',
  '面积': 'Area',
  '功率': 'Power',
  '瓦特': 'Watts',
  '周期': 'Period',
  '频率': 'Frequency',
  '储能': 'Stored energy',
  '天数': 'Days',
  '截面积': 'Section area',
  '效率': 'Efficiency',
  '输入功率': 'Input power',
  '输出功率': 'Output power',
  '损耗功率': 'Loss power',
  '机械马力': 'Mechanical hp',
  '公制马力': 'Metric hp',
  '目标功率': 'Target power',
  '运动方向': 'Direction',
  '压力': 'Pressure',
  '体积': 'Volume',
  '文本工具': 'Text tool',
};
