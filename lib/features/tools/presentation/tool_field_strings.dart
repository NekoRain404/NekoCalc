import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';
import 'tool_explanation_strings.dart';
import 'tool_input_strings.dart';

/// 中文：**工具目录最后几格的表**——`input.label`、`input.unit`、`tool.group`、`tool.formula`、
///       `tool.explanation` 五种字段的两种语言。工具详情页上的字与分类页上的分组标题，到此为止
///       全部走表；这几格今天仍是中文之外的最后一处（`result.label` 那一大格**不在本轮**，规模量在
///       `.superpowers/backup/tool-detail-inputs-report.md` 里）。
///
///       **这一张与本子树另外两张表有一个机制上的不同，先说它：键是中文本身，不是 `tool.id`。**
///       `tool_catalog_strings.dart`（名字与分类）与 `tool_description_strings.dart`（描述）按 id
///       取词、两种语言各写一份——因为**一个 id 只有一条名字、一条描述**。这几格不是：
///       **同一个字串在各工具里反复出现**。本轮逐条量过：
///         · `input.label` 346 处 → **231** 个带汉字的字串（`输入值` 一份就 22 处，`电阻公差` 3 处，
///           `目标力`/`目标作用力`/`目标推出力`/`目标弹簧力` 四条各自指向同一个 `Target force`…）；
///         · `input.unit` 288 处 → **11** 个字串带汉字（其余 65 个不同值全是 `Ω`、`nF`、`m/s`
///           这种**记号**，没有可翻的东西）；`tool.group` 117 处 → **29** 个；
///         · `tool.formula` 117 处 → **10** 个带汉字（另 68 个不同值整条都是记号，
///           `1/R1` 这种一个汉字都没有）；`tool.explanation` 117 处 → **96** 条。
///       按 id 写要把同一句英文抄十几遍，**一份话十几份副本，改一处漂一处**；按字串写一次写清，
///       而且**同一个中文词在屏幕上永远只有一种英文**——这是构造上成立的，不是约定。
///
///       由此得到三条兄弟表没有的性质，也是这张表敢这么写的前提：
///         · **中文那一侧没有表，因为键就是它。** `表[中文] ?? 中文` 就是整条查表逻辑：认得出的
///           查表，认不出的原样返回。于是**默认态不是"与目录逐字节相同"（那要靠断言），
///           而是"屏幕上那个字串就是目录里那个对象"（那是构造）**——中文界面上这几格今天仍然直接
///           来自 `tool_catalog*.dart` 与 `tool_insights_*.dart`，本轮**没有改过它们一个字节**。
///         · **一张表只有一半**：兄弟表写中文 + 英文两份，这里英文那份的**键**就是中文那份，
///           一行里两种语言并排看得见。要是照兄弟表的写法写全两份，是 985 处 × 2 行。
///         · **死条目与漏条目都能机器查**：键在目录里根本不出现就是死条目，目录里带汉字的字段
///           找不到对应的键就是漏条目（英文下这种漏会以中文的样子露在屏幕上）——
///           两条都在 `tool_field_strings_test.dart` 里逐条走过目录。
///
///       **377 条 (231 + 11 + 29 + 10 + 96) 全部是本轮新写的，没有一条可提升。** 名字那 99 条
///       能从两处检索索引里找出来（`tool_catalog_strings.dart` 的文件头写了这件事）；
///       **这五格在两处索引里一条都没有**，`tool_catalog*.dart` 与 `tool_insights_*.dart` 里
///       也只有中文一份。所以这一轮和上一轮一样：**没有可对照的东西**，
///       `.superpowers/backup/tool-detail-inputs-report.md` 里那张逐条对照表是它唯一的复核面。
///
///       **为什么是三个文件，而不是一张大表。** 依据是这棵子树一直在用的那条判据
///       （"一屏看得完"，见 `tool_description_strings.dart` 的文件头），**不是行数硬线**——
///       硬线这一回并没有被逼到：377 条并进一个文件大约 520 行，照样在 800 以下。
///       分的是**字段本身**，每张表各配一处屏幕上的落点：
///         · 本文件——**分组名 29 条**（外加这个类和它的分派）。分组名是**列表上的标题**，
///           与分类页的八个分类名同类，所以待在类文件里，正如那八个待在 `ToolCatalogStrings` 里；
///         · `tool_input_strings.dart`——**输入卡上那两格**：参数标签 231 + 单位 11。
///           单是这一张就与整张描述表（117 条）一样大；
///         · `tool_explanation_strings.dart`——**公式卡上那两行**：公式 10 + 解释 96，
///           每一条都是一句话，与上面那些短字段排在同一张表里两种都读不下去。
///
///       **长度是量过的，判据写在测试里。** 参数标签那一格在 360dp 手机上是 **89.1dp**
///       （`_inputRow` 里 `Expanded(flex: 3)` 分到的那一格；行里另有 8+34+4+4+34 的固定宽度，
///       卡片内容宽 292dp）。标签**不截断**（没有 `maxLines`，装不下就换行、行就变高），
///       所以长度问题表现为**行数**：**没有任何一条英文标签需要 3 行，也没有任何一条非可选的
///       英文标签比它的中文多占一行**。有 39 处**可选**参数英文比中文多一行，
///       原因不在标签而在**上一轮的壳**：`ToolsStrings.optionalInput` 的 ` (optional)` 是
///       65.4dp，中文的 `（可选）` 是 56dp——**哪怕标签只有 4 个字母也照样超**，
///       所以那 39 处不是"标签写长了"，是"壳比中文宽"（详见报告；本轮不碰那张表）。
///
///       **检索一个字节没动，中文照旧找得到。** `label` / `unit` / `group` / `formula` /
///       `explanation` 五个字段本身仍是目录里那一条中文，`tool_search_engine.dart` 的
///       `rankTool`（输入项 68、单位 56、公式 72、解释 62、分组名 58 五档）、`tokenMatch` 与
///       `suggestionPhrases` 读的还是它们；本表**只被显示读**，不参与匹配、不落库
///       （写笔记与剪贴板那几处 `tool.description` / `tool.formula` / `input.label` 是持久化，
///       本轮一行未动）。命中的字符串、分数与排序因此与改动前逐条相同。
///
///       ⚠️ **`tool.group` 在"命中：XXX"那一行里不是本表翻的。** 那行里的分组名与分类名是
///       **内容透传**，`tools_match_labels_test.dart` 明确钉住"英文界面下仍是目录里那五个汉字"。
///       本轮只翻**分类页上的分组标题**那处显示，不动那一行的透传——理由与它自己的注释写在
///       那份测试里，改动它会推翻上一轮的一个决定，不在本轮范围。
/// English: **the last fields of the tools catalogue** — the two languages of `input.label`,
///          `input.unit`, `tool.group`, `tool.formula` and `tool.explanation`. Every word on the tool
///          detail page and the category page's group headings now comes from a table; these fields
///          were the last Chinese outside them (`result.label` is **not** in this round, and its size
///          is measured in `.superpowers/backup/tool-detail-inputs-report.md`).
///
///          **This table differs from its two siblings in one mechanism, and that comes first: the key
///          is the Chinese string itself, not `tool.id`.** `tool_catalog_strings.dart` (names and
///          categories) and `tool_description_strings.dart` (descriptions) are keyed by id with both
///          languages written out, because **an id owns exactly one name and one description**. These
///          fields are not like that: **the same string comes round in tool after tool.** Measured
///          this round: `input.label` 346 occurrences → **231** distinct strings holding a Han
///          character (`输入值` alone 22 times, `电阻公差` 3 times, and `目标力` / `目标作用力` /
///          `目标推出力` / `目标弹簧力` all landing on one `Target force`); `input.unit` 288 → **11**
///          with a Han character (the other 65 distinct values are **notation** such as `Ω`, `nF`,
///          `m/s`, with nothing to translate); `tool.group` 117 → **29**; `tool.formula` 117 → **10**
///          (the other 68 distinct values are notation end to end); `tool.explanation` 117 → **96**.
///          Keying by id would copy one English sentence a dozen times — **a dozen copies that drift
///          apart the moment one is edited**. Keyed by string it is written once, and **one Chinese
///          word always renders as exactly one English phrase** — a property of the construction, not
///          of a convention.
///
///          Three consequences follow, and they are what makes this shape safe:
///            · **There is no Chinese table, because the key is the Chinese.** `map[chinese] ??
///              chinese` is the whole lookup. So the default state is not "byte-identical to the
///              catalogue" (that would need an assertion) but **"the string on screen *is* the object
///              in the catalogue"** (that is the construction). In Chinese these fields still come
///              straight out of `tool_catalog*.dart` and `tool_insights_*.dart`, and **not one byte of
///              those files was changed**.
///            · **The table is only half of one**: the sibling tables write Chinese + English, here the
///              English table's **keys** are the Chinese side, so both languages are on one line.
///              Writing it out the siblings' way would be 985 occurrences × 2 lines.
///            · **Dead entries and missing entries are both machine-checkable**: a key that never
///              occurs in the catalogue is dead, and a Han-bearing field with no key is missing (in
///              English such a miss shows up as Chinese on screen). Both walk the catalogue in
///              `tool_field_strings_test.dart`.
///
///          **All 377 entries (231 + 11 + 29 + 10 + 96) are authored this round; none is promoted.**
///          Of the names, 99 could be lifted from the two search indexes (the story is on
///          `tool_catalog_strings.dart`'s head); **these five fields appear in neither index**, and
///          `tool_catalog*.dart` / `tool_insights_*.dart` hold Chinese only. So this round, like the
///          last, **has nothing to check against** — the entry-by-entry table in
///          `.superpowers/backup/tool-detail-inputs-report.md` is its only review surface.
///
///          **Why three files rather than one big table.** The criterion is the one this subtree has
///          used all along ("readable in one screen", see `tool_description_strings.dart`'s head),
///          **not the line limit** — that limit is not even close this time: all 377 entries in one
///          file would be about 520 lines, well under 800. What splits is **the fields themselves**,
///          each table matching one landing place on screen:
///            · this file — **the 29 group names** (plus the class and its dispatch). A group name is a
///              **heading over a list**, the same kind of thing as the eight category names, so it
///              lives in the class file exactly as those live in `ToolCatalogStrings`;
///            · `tool_input_strings.dart` — **the input card's two fields**: 231 labels + 11 units.
///              That one table alone is as large as the whole description table (117 entries);
///            · `tool_explanation_strings.dart` — **the formula card's two lines**: 10 formulas + 96
///              explanations, every one a sentence, which beside the short fields above would make
///              both unreadable.
///
///          **Length was measured, and the rule is in the test.** The label cell is **89.1dp** wide on
///          a 360dp phone (the `Expanded(flex: 3)` inside `_inputRow`; the row also carries 8+34+4+4+34
///          of fixed width inside a 292dp card). Labels **do not truncate** (no `maxLines`; too long
///          and it wraps, and the row grows), so the cost shows up as **line count**: **no English
///          label needs 3 lines, and no non-optional English label takes more lines than its Chinese**.
///          Thirty-nine **optional** rows do take one line more, and the cause is not the label but
///          **the previous round's chrome**: `ToolsStrings.optionalInput`'s ` (optional)` is 65.4dp
///          against Chinese `（可选）` at 56dp — **even a four-letter label overflows**, so those 39
///          are "the chrome is wider than Chinese", not "the label is long" (the report has the
///          numbers; that table is not touched this round).
///
///          **Search did not move by a byte, and Chinese still finds tools.** The five fields are
///          still the catalogue's single Chinese string, and `tool_search_engine.dart`'s `rankTool`
///          (input 68, unit 56, formula 72, explanation 62, group 58), `tokenMatch` and
///          `suggestionPhrases` still read them; this table is **read by display only** — it neither
///          matches nor persists (the `tool.description` / `tool.formula` / `input.label` sites in
///          note writing and clipboard are persistence, untouched here). Hit strings, scores and
///          ordering are therefore identical to before.
///
///          ⚠️ **`tool.group` on the "Matched: …" line is not translated by this table.** There the
///          group name and the category names **pass through as content**, and
///          `tools_match_labels_test.dart` pins that they stay those same five Han characters in the
///          English interface. This round translates the **category page's heading** only and leaves
///          that pass-through alone — the reasoning is written in that test, and changing it would
///          overturn a decision from the previous round, which is out of scope here.
@immutable
class ToolFieldStrings {
  const ToolFieldStrings({
    required this.inputLabels,
    required this.inputUnits,
    required this.groups,
    required this.formulas,
    required this.explanations,
  });

  /// 中文：**中文标签 → 英文**，231 条。中文界面下这张表**根本没被查**（键就是屏幕上那句话本身），
  ///       所以它可以是空的——`toolFieldsZh` 五个 map 全空不是漏写，是这张表的本来面目。
  /// English: **Chinese label → English**, 231 entries. In Chinese this table is **never consulted**
  ///          (the key *is* the sentence on screen), so it may be empty — `toolFieldsZh`'s five empty
  ///          maps are the shape of the mechanism, not an omission.
  final Map<String, String> inputLabels;

  /// 中文：**中文单位 → 英文**，11 条（`Ω`、`nF`、`m/s` 这类记号不进来：两种语言逐字节相同，
  ///       进表只会多出一条"值等于键"的死条目）。
  /// English: **Chinese unit → English**, 11 entries (`Ω`, `nF`, `m/s` are notation and stay out:
  ///          they are byte-identical in both languages, and an entry would only add a dead row whose
  ///          value equals its key).
  final Map<String, String> inputUnits;

  /// 中文：**中文分组名 → 英文**，29 条，分类页上那行小标题。表在下面 [toolGroupsEn]。
  /// English: **Chinese group name → English**, 29 entries — the small heading on the category page.
  ///          The table is [toolGroupsEn] below.
  final Map<String, String> groups;

  /// 中文：**中文公式 → 英文**，10 条。其余 68 个不同公式整条都是记号（`1/R1`、`a² + b² = c²`），
  ///       两种语言逐字节相同，不进表。表在 `tool_explanation_strings.dart`。
  /// English: **Chinese formula → English**, 10 entries. The other 68 distinct formulas are notation
  ///          end to end (`1/R1`, `a² + b² = c²`) and are byte-identical in both languages, so they
  ///          stay out. The table lives in `tool_explanation_strings.dart`.
  final Map<String, String> formulas;

  /// 中文：**中文解释 → 英文**，96 条，公式下面那段话。表在 `tool_explanation_strings.dart`。
  /// English: **Chinese explanation → English**, 96 entries — the prose under the formula. The table
  ///          lives in `tool_explanation_strings.dart`.
  final Map<String, String> explanations;

  /// 中文：参数标签。查不到就原样返回——**回落到"中文"这件事在这里不需要写**，因为中文就是键：
  ///       目录里那句中文原封不动地回到屏幕上，一个字符都没经过谁的手。
  /// English: An input label. A miss returns its argument unchanged — **"fall back to Chinese" needs
  ///          no code here**, because the Chinese *is* the key: the catalogue's own sentence reaches
  ///          the screen with nothing in between.
  String inputLabel(String label) => inputLabels[label] ?? label;

  /// 中文：单位，输入框右侧那个后缀。回落同 [inputLabel]。
  /// English: A unit, the suffix inside the input field. Same fallback as [inputLabel].
  String inputUnit(String unit) => inputUnits[unit] ?? unit;

  /// 中文：分组名，分类页上分组的标题。回落同 [inputLabel]。
  /// English: A group name, the heading over a group on the category page. Same fallback as
  ///          [inputLabel].
  String group(String group) => groups[group] ?? group;

  /// 中文：公式那一行。回落同 [inputLabel]——**没有汉字的公式因此两种语言一模一样**，
  ///       这正是"记号是语言无关的"那句话在代码里的样子。
  /// English: The formula line. Same fallback as [inputLabel] — **a formula with no Han character is
  ///          therefore identical in both languages**, which is what "notation is language-neutral"
  ///          looks like in code.
  String formula(String formula) => formulas[formula] ?? formula;

  /// 中文：公式下面那段解释。回落同 [inputLabel]。
  /// English: The prose under the formula. Same fallback as [inputLabel].
  String explanation(String explanation) => explanations[explanation] ?? explanation;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过，
  ///       而不是静默回落到中文。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here rather than silently falling back to Chinese.
  static ToolFieldStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。
  /// English: The same dispatch as [of], for callers without a `BuildContext`.
  static ToolFieldStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => toolFieldsZh,
      AppLanguage.en => toolFieldsEn,
    };
  }

  /// 中文：**中文表是五个空 map，这是设计不是疏漏。** 查表是 `表[键] ?? 键`，键就是屏幕上那句中文，
  ///       所以"中文那一侧"根本不需要一份数据；写一份 `{'功率': '功率'}` 那样的表，
  ///       只会多出 377 条值等于键的行，并让"漏翻"和"没翻"看起来一样。
  ///       `tool_field_strings_test.dart` 因此钉的不是"中文表与目录逐条相同"，而是
  ///       **"中文下每个字段都逐字节等于目录里那一条"**——那是同一条断言在构造下的形式。
  /// English: **The Chinese table is five empty maps on purpose.** The lookup is `map[key] ?? key` and
  ///          the key is the Chinese on screen, so the Chinese side needs no data at all; writing
  ///          `{'功率': '功率'}` style rows would add 377 value-equals-key entries and make "missed"
  ///          look like "not needed". `tool_field_strings_test.dart` therefore pins
  ///          **"every field, in Chinese, is byte-identical to the catalogue"** rather than
  ///          "the Chinese table matches the catalogue entry by entry" — the same assertion in the
  ///          shape this construction gives it.
  static const ToolFieldStrings toolFieldsZh = ToolFieldStrings(
    inputLabels: {},
    inputUnits: {},
    groups: {},
    formulas: {},
    explanations: {},
  );

  /// 中文：英文表。五张表住在三个文件里（本文件、`tool_input_strings.dart`、
  ///       `tool_explanation_strings.dart`），由**这一个类**分派，所以同一个字段在屏幕上不可能
  ///       一半来自表、一半来自目录。
  /// English: The English table. The five maps live in three files (this one,
  ///          `tool_input_strings.dart`, `tool_explanation_strings.dart`) dispatched by **this one
  ///          class**, so one field on screen cannot half come from a table and half from the
  ///          catalogue.
  static const ToolFieldStrings toolFieldsEn = ToolFieldStrings(
    inputLabels: toolInputLabelsEn,
    inputUnits: toolInputUnitsEn,
    groups: toolGroupsEn,
    formulas: toolFormulasEn,
    explanations: toolExplanationsEn,
  );
}

/// 中文：**中文分组名 → 英文**，29 条，按它们在目录里第一次出现的顺序排。分类页上那一行
///       `SectionTitle(entry.key)` 读的就是它——**分组本身仍按 `tool.group`（中文）分组**，
///       翻的只是标题那一步：`grouped` 的键一个字节都没动，所以分组的成员、顺序与检索命中
///       与改动前逐条相同。
///
///       词是怎么选的：这一行是 15sp w800 的整行标题，**不存在宽度问题**，所以取的是英文里
///       那个领域最常用的说法，而不是缩写——`编码`/`数据`/`公式`/`时间` 是编程分类下四个子组，
///       `基础`/`信号`/`电源`/`采样` 是电子分类下的（`基础` 里还有一条力学的 `force`，
///       名字与内容不符是目录自己的事，本轮不动目录）。`常用` 那 26 个工具是单位换算与常用计算，
///       英文用 `Common`，与工具首页的 `Common tools`（`ToolsStrings.commonTools`）同源。
/// English: **Chinese group name → English**, 29 entries in catalogue order of first appearance. The
///          category page's `SectionTitle(entry.key)` reads it — **grouping itself still uses
///          `tool.group` (the Chinese)**, and only the heading step translates: the keys of `grouped`
///          do not move by a byte, so membership, order and search hits are exactly as before.
///
///          How the words were chosen: this line is a full-width 15sp w800 heading, so **there is no
///          width problem** — the commonest English term in the field wins over an abbreviation.
///          `编码` / `数据` / `公式` / `时间` are the programming category's subgroups,
///          `基础` / `信号` / `电源` / `采样` the electronics ones (`基础` also holds the mechanical
///          `force` tool; that mismatch is the catalogue's own and the catalogue is not touched this
///          round). `常用` covers the 26 unit-conversion and everyday tools; English uses `Common`,
///          the same word as the tools home's `Common tools` (`ToolsStrings.commonTools`).
const Map<String, String> toolGroupsEn = {
  '方程': 'Equations',
  '常用': 'Common',
  '概率': 'Probability',
  '统计': 'Statistics',
  '矩阵': 'Matrices',
  '几何': 'Geometry',
  '基础': 'Basics',
  '信号': 'Signal',
  '采样': 'Sampling',
  '电源': 'Power supply',
  '传动': 'Drive',
  '结构': 'Structure',
  '流体': 'Fluids',
  '受力': 'Forces',
  '借贷': 'Loans',
  '投资': 'Investment',
  '商业': 'Business',
  '生活': 'Everyday',
  '运动': 'Motion',
  '能量': 'Energy',
  '物性': 'Properties',
  '化学': 'Chemistry',
  '热学': 'Heat',
  '波动': 'Waves',
  '物理': 'Physics',
  '编码': 'Encoding',
  '时间': 'Time',
  '数据': 'Data',
  '公式': 'Formulas',
};
