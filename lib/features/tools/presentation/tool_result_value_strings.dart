import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';
import 'tool_input_strings.dart';

/// 中文：**结果值表**——`ToolResult.value` 与 `ToolResult.unit` 那两格上"不是数、而是一句话"的中文，
///       中文→英文。结果卡与主结果框那两处 `Text(result.value, …)` / `Text(primary.value, …)`
///       从前把产出方写下的那句话原样印出去，所以英文界面上一条结论、一个"无效"、一句输入来源
///       仍然是中文——**同一排左边的标签早就走表了，这两格只是被漏掉**。
///
///       ### 里面装的是什么
///
///       四样东西，都是"会出现在值里"的字，按目录里第一次出现的顺序排：
///         · **记号与结论 18 条**——`invalidResultValue`（`'无效'`）与 [ToolResultConclusion] 那 17
///           句（`'未回收'`、`'会下滑'`、`'无解'`、`'垂直'`…）。结论的句子就是屏幕上那句话，
///           键因此是它本身；
///         · **值里那几个词 90 条**——`'不可逆'`、`'已取整数'`、`'层流'`、`'偏瘦'`、`'x轴'`…，
///           以及**输入来源那两个词的词根**（`'电阻'`、`'摩尔浓度'`…）：它们今天只出现在
///           结果值内部（`'电压+电流，电阻、功率作参考'`），所以在这张表里，
///           与产出方那句拼装串同住一处。末尾九条是**三角形那九种合体**
///           （`'等边锐角'`…）：产出方把"边型 + 角型"黏成一个值，屏幕上从来不是那六个词单独出现。
///         · **输入来源那 107 条**——`'电压+电流'`、`'初始量+半衰期+经过时间'`、
///           `'贷款金额+年利率+贷款年限'`…：`calculate_tool*.dart` 里 `source` 那一格写下的值。
///           **"只写了输入名字"的那几个**（圆工具的 `'半径'`、`'直径'`、`'周长'`、`'面积'`）
///           不写在这里：它们就是输入标签本身，英文从 `toolInputLabelsEn` 借
///           （见 [ToolResultValueStrings.borrowed]）。
///         · **单位 21 条**——`'元/月'`、`'kWh/天'`、`'个'`…：`ToolResult.unit` 那一格。
///           **与值同一排、同两处 `Text`，所以本轮一起收**；`'N·m'`、`'Ω·mm²/m'` 那种
///           整条都是记号的单位不进表（两种语言逐字节相同）。这 21 条里只有 10 条写在本文件，
///           另外 11 条（`'元'`、`'万元'`、`'齿'`、`'倍'`…）**从 `toolInputUnitsEn` 借**——
///           同一条单位在输入格与结果格里是同一个字，见 [ToolResultValueStrings.borrowed]。
///
///       ### 机制与三张兄弟表逐字相同（键是中文本身、中文那一侧是空 map、回落是 `?? 键`），
///       详见 `tool_field_strings.dart` 的文件头。本文件只写自己那三件事：
///
///       —— 一、**带载荷的那一句在边缘拼，不整句进表。** 产出方有一处
///       `'$source，${references.join('、')}作参考'`（`calculate_tool_basic_electronics.dart`
///       与另外三个文件的 `_…Source` 帮手），它在运行期拼出一个**词表里的词 + '、' 连接的参考项**。
///       整句进表就等于把"一百种拼法"抄一百条；所以 [lookup] 在查不到整句时按**同一个形状**拆开：
///       头部与每个参考项各自查（表里有就用表里的英文；表里没有、整块又**不带汉字**的原样放行——
///       `'Vrms'`、`'50Ω dBm'` 这种记号本来两种语言就相同），两者都不成立才判没翻、整句回落中文。
///       英文按 `<head>, with <refs> as reference` 拼回去，并列两项写 `A and B`、三项起写
///       `A, B and C`。中文那一侧这条规则不会生效——中文表是空的，拆出来的词一个都查不到。
///
///       —— 二、**`unit` 与 `value` 共用一张表、一个查法**（[unit] 就是 [value]）。
///           两格在屏幕上同排、同两处 `Text`，分成两张表只会让"单位漏了一条"没人发现。
///
///       —— 三、**同一个字在两张表里只写一遍英文。** 两处都是这个道理，所以本表借了两张表
///           （[ToolResultValueStrings.borrowed]）：
///           `'元'`、`'万元'`、`'齿'`、`'倍'`… 这些**单位**既出现在输入格
///           （`toolInputUnitsEn`）又出现在结果格，那 11 条借过来查；`'半径'`、`'直径'`…
///           这些**输入标签**被整格搬进结果格当输入来源用时，也一样从 `toolInputLabelsEn` 借。
///
///       ⚠️ **不翻的两处，本轮明说**：剪贴板与笔记里那份正文（`resultSummary()` /
///       `singleResultCopyText()` / `noteBody()`）读的仍是 `result.value` 本身，一个字节没动——
///       与标签表那条边界相同（**屏幕上的是渲染出来的字，复制出去的是数据**）。
///       值里出现的数字、记号（`N·m`、`Ω·mm²/m`、`1~2Ω`、`0.5W`）两种语言逐字节相同，
///       一条都不进表。
/// English: **the result-value table** — the Chinese of the two cells `ToolResult.value` and
///          `ToolResult.unit` when they are "not a number but a sentence", Chinese → English. The two
///          `Text(result.value, …)` / `Text(primary.value, …)` sites printed whatever the producer
///          wrote, so an English interface still showed a Chinese conclusion, a Chinese "invalid" or a
///          Chinese input source — **the label at the left of the same row has long gone through a
///          table; these two cells were simply missed.**
///
///          ### What is in it
///
///          Four kinds of thing, all of them "words that land inside a value", in catalogue order:
///            · **The marker and the conclusions, 18** — `invalidResultValue` (`'无效'`) and the 17
///              sentences of [ToolResultConclusion] (`'未回收'`, `'会下滑'`, `'无解'`, `'垂直'`, …).
///              A conclusion's sentence *is* what is on screen, so the key is that sentence itself;
///            · **The words inside a value, 90** — `'不可逆'`, `'已取整数'`, `'层流'`, `'偏瘦'`,
///              `'x轴'`, … plus **the roots of the input-source wording** (`'电阻'`, `'摩尔浓度'`, …):
///              today they occur only inside a result value (`'电压+电流，电阻、功率作参考'`), so they
///              live in this table, beside the sentence the producer assembles. The last nine are
///              **the nine triangles the two halves make** (`'等边锐角'`, …): the producer glues the
///              side type and the angle type into one value, so the six halves never reach the screen
///              on their own;
///            · **The 107 input sources** — `'电压+电流'`, `'初始量+半衰期+经过时间'`,
///              `'贷款金额+年利率+贷款年限'`, …: what `calculate_tool*.dart` writes into `source`.
///              **The ones that name a single input** (the circle tool's `'半径'`, `'直径'`,
///              `'周长'`, `'面积'`) are not written here: they *are* input labels, and their English is
///              borrowed from `toolInputLabelsEn` (see [ToolResultValueStrings.borrowed]);
///            · **The 21 units** — `'元/月'`, `'kWh/天'`, `'个'`, …: the `ToolResult.unit` cell.
///              **It shares the row and the same two `Text` sites, so this round takes it too**;
///              notation-only units such as `'N·m'` and `'Ω·mm²/m'` do not enter the table
///              (byte-identical in both languages). Only 10 of the 21 are written in this file; the
///              other 11 (`'元'`, `'万元'`, `'齿'`, `'倍'`, …) are **borrowed from
///              `toolInputUnitsEn`** — one unit is one word in an input cell and in a result cell, see
///              [ToolResultValueStrings.borrowed].
///
///          ### The mechanism is character-for-character its three siblings' (the key is the Chinese
///          itself, the Chinese side is an empty map, the fallback is `?? key`); see
///          `tool_field_strings.dart`'s head. This file writes only its own three things:
///
///          — 1. **The sentence that carries a payload is assembled at the edge, not tabled whole.**
///          Four producer files hold `'$source，${references.join('、')}作参考'` (`_…Source` helpers),
///          which at run time joins **words from this table** with a `、`-separated reference list.
///          Tabling it whole would mean copying a hundred assemblies; so when [lookup] cannot find the
///          whole sentence it splits it by **that one shape**: the head and every reference are looked
///          up on their own (the map's English when there is one; otherwise, if the piece **holds no Han
///          character**, it passes through unchanged — `'Vrms'` and `'50Ω dBm'` are notation and read
///          the same in both languages); failing both counts as a miss and the whole sentence falls back
///          to Chinese. English is put back together as `<head>, with <refs> as reference`, with two
///          items reading `A and B` and three or more `A, B and C`. On the Chinese side the rule never
///          fires — the Chinese map is empty, so not one of the pieces resolves.
///
///          — 2. **`unit` and `value` share one table and one lookup** ([unit] *is* [value]). The two
///          cells share a row and the same two `Text` sites on screen; two tables would only make a
///          missed unit nobody's business.
///
///          — 3. **One word gets its English written once, not twice.** Both cases work this way, so
///          this table borrows two tables ([ToolResultValueStrings.borrowed]): the **units**
///          `'元'`, `'万元'`, `'齿'`, `'倍'`, … occur both in an input cell (`toolInputUnitsEn`) and in
///          a result cell, so those 11 are borrowed from there; the **input labels** `'半径'`,
///          `'直径'`, … are carried into a result cell as an input source, and they are borrowed from
///          `toolInputLabelsEn` the same way.
///
///          ⚠️ **Two places this round does not touch, said plainly**: the body copied to the clipboard
///          and to notes (`resultSummary()` / `singleResultCopyText()` / `noteBody()`) still reads
///          `result.value` itself, not one byte moved — the same boundary as the label table's
///          (**what is on screen is rendered copy; what is copied out is data**). Numbers and notation
///          inside a value (`N·m`, `Ω·mm²/m`, `1~2Ω`, `0.5W`) are byte-identical in both languages and
///          not one of them enters the table.
@immutable
class ToolResultValueStrings {
  const ToolResultValueStrings(this.values,
      {this.borrowed = const <Map<String, String>>[]});

  /// 中文：**中文那半句 → 英文**。查不到就原样返回——"回落到中文"不需要写代码，因为中文就是键。
  /// English: **Chinese value → English**. A miss returns its argument unchanged — **"fall back to
  ///          Chinese" needs no code**, because the Chinese *is* the key.
  final Map<String, String> values;

  /// 中文：**借来的表**——排在自己的表后面查。今天有两张：`toolInputUnitsEn` 与
  ///       `toolInputLabelsEn`。
  ///
  ///       —— 单位：**同一条单位在输入格与结果格里是同一个字、同一句英文**（`'万元'`、`'元'`、
  ///       `'齿'`、`'倍'`…），而输入那一族的表先有（`tool_input_strings.dart`）。
  ///       同一个字抄两份英文迟早会分家，所以这里借来用，不另写一遍——
  ///       `'万元'` 在输入格与结果格上都读 `'10k ¥'`，改一处两处一起改。
  ///
  ///       —— 标签：**"只写了输入名字"的输入来源本来就是那个输入标签**。`'半径'`、`'直径'`、
  ///       `'周长'`、`'面积'` 这四个值（`calculate_tool_math_geometry.dart` 的圆工具，
  ///       `provided == 1` 那一支）就是输入框的名字原样搬进结果格；它们的英文只有一份，
  ///       在 `toolInputLabelsEn` 里。**这一张是量出来的**：探针把 99 个工具 × 每个输入单独填的
  ///       档位全跑一遍，剩下的 4 条残留值就是这四个字。
  /// English: **borrowed tables**, consulted after the file's own. There are two today:
  ///          `toolInputUnitsEn` and `toolInputLabelsEn`.
  ///
  ///          — Units: **the same unit is the same word and the same English in an input cell and in a
  ///          result cell** (`'万元'`, `'元'`, `'齿'`, `'倍'`, …), and the input family's table came
  ///          first (`tool_input_strings.dart`). Two copies of one word's English drift apart sooner or
  ///          later, so this borrows instead of rewriting: `'万元'` reads `'10k ¥'` in an input cell
  ///          and in a result cell alike, and one edit moves both.
  ///
  ///          — Labels: **an input source that names one input is that input's label**. The four
  ///          values `'半径'`, `'直径'`, `'周长'`, `'面积'` (the circle tool in
  ///          `calculate_tool_math_geometry.dart`, the `provided == 1` branch) are the input cells'
  ///          names carried into a result cell; their English exists once, in `toolInputLabelsEn`.
  ///          **This table was measured in**: the probe ran all 99 tools with each input filled on its
  ///          own, and the four leftovers were exactly these four words.
  final List<Map<String, String>> borrowed;

  /// 中文：一个结果值（`ToolResult.value`）。整句查表 → 按"来源串"的形状拆开再查 → 原样返回。
  /// English: one result value (`ToolResult.value`): whole-sentence lookup, then the "source string"
  ///          shape, then the argument unchanged.
  String value(String value) => lookup(value) ?? value;

  /// 中文：**[value] 的前半步**——只差最后一格：查不到时返回 `null` 而不是原样。
  ///       洞察卡那边的载荷渲染（`ToolInsightStrings`）要区分"查到了"与"没查到"，好接着走它
  ///       自己那几条规则，所以那张表把这半步单独借出去用（见该文件头的"载荷怎么变成英文"）。
  ///       **运行期拼装规则都住在这里**，不在表里——表里是字，规则是拼法。
  /// English: **the first half of [value]** — it differs only in the last step: a miss returns `null`
  ///          instead of the argument. The insight card's payload rendering (`ToolInsightStrings`) has
  ///          to tell a hit from a miss so it can go on with its own rules, so that table borrows this
  ///          half (see "How a payload becomes English" in its head). **The run-time assembly rules
  ///          live here**, not in the maps: the maps hold words, the rules hold the ways they join.
  String? lookup(String text) {
    final own = values[text];
    if (own != null) return own;
    for (final table in borrowed) {
      final hit = table[text];
      if (hit != null) return hit;
    }
    return _composedSource(text);
  }

  /// 中文：一个结果单位（`ToolResult.unit`）。与 [value] 同一张表、同一个查法。
  /// English: one result unit (`ToolResult.unit`). Same table and same lookup as [value].
  String unit(String unit) => value(unit);

  /// 中文：**运行期拼出来的输入来源**——`'<头>，<参考项>、<参考项>作参考'`。
  ///       头部与每个参考项各自查表；表里没有、但整块也没有汉字时原样放行（`'Vrms'`、
  ///       `'50Ω dBm'` 这种记号本来就该两种语言相同——与"记号不进表"是同一条）；两者都不成立
  ///       就返回 `null`（= 整句回落中文）。中文界面下永远返回 `null`。
  /// English: **an input source assembled at run time** — `'<head>，<ref>、<ref>作参考'`. The head and
  ///          every reference are looked up on their own; a piece that is not in the map **but holds no
  ///          Han character either** passes through unchanged (`'Vrms'`, `'50Ω dBm'` — notation is
  ///          supposed to read the same in both languages, the same rule as "notation does not enter
  ///          the map"); failing both, `null` comes back (= the whole sentence falls back to Chinese).
  ///          Under a Chinese interface it always returns `null`.
  String? _composedSource(String text) {
    if (!text.endsWith('作参考')) return null;
    final body = text.substring(0, text.length - '作参考'.length);
    final comma = body.lastIndexOf('，');
    if (comma <= 0) return null;
    final head = _piece(body.substring(0, comma));
    if (head == null) return null;
    final references = <String>[];
    for (final reference in body.substring(comma + 1).split('、')) {
      final english = _piece(reference);
      if (english == null) return null;
      references.add(english);
    }
    if (references.isEmpty) return null;
    return '$head, with ${_englishList(references)} as reference';
  }

  /// 中文：**来源串里的一块**：先查表，查不到再看它带不带汉字（见 [_composedSource]）。
  /// English: **one piece of a source string**: the map first, then the Han-character test (see
  ///          [_composedSource]).
  String? _piece(String text) => values[text] ?? (holdsHan(text) ? null : text);

  /// 中文：**英文的并列写法**——两项写成 `A and B`，三项起写成 `A, B and C`（来源串里真有
  ///       三项的：`'Vrms，Vpeak、Vpp、50Ω dBm作参考'`，写成 `A and B and C` 是硬译）。
  /// English: **an English list** — two items read `A and B`, three or more read `A, B and C` (a
  ///          three-item source string does occur: `'Vrms，Vpeak、Vpp、50Ω dBm作参考'`, and
  ///          `A and B and C` would be translationese).
  static String _englishList(List<String> items) {
    if (items.length < 3) return items.join(' and ');
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过。
  /// English: picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here.
  static ToolResultValueStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。
  /// English: the same dispatch as [of], for callers without a `BuildContext`.
  static ToolResultValueStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => toolResultValuesZh,
      AppLanguage.en => toolResultValuesEnInstance,
    };
  }

  /// 中文：**中文表是空的，这是设计不是疏漏**（理由与 `ToolFieldStrings` 那五个空 map 相同）。
  /// English: **the Chinese table is empty on purpose** (the same reasoning as `ToolFieldStrings`'s
  ///          five empty maps).
  static const ToolResultValueStrings toolResultValuesZh =
      ToolResultValueStrings({});

  /// 中文：英文表。重复键在这三个 `const` map 之间是编译期错误；借来的那两张表另算（见 [borrowed]）。
  /// English: the English table. A duplicate key across these three `const` maps is a compile-time
  ///          error; the two borrowed tables count separately (see [borrowed]).
  static const ToolResultValueStrings toolResultValuesEnInstance =
      ToolResultValueStrings(toolResultValuesAllEn,
          borrowed: <Map<String, String>>[
        toolInputUnitsEn,
        toolInputLabelsEn,
      ]);
}

/// 中文：合并后的英文表。顺序只是读的顺序，**三个文件级 map 互不相交**（重复键编译不过）。
/// English: the merged English table. The order is only reading order; **the three file-level maps are
///          disjoint** (a duplicate key does not compile).
const Map<String, String> toolResultValuesAllEn = <String, String>{
  ...toolResultValuesConclusionsEn,
  ...toolResultValueWordsEn,
  ...toolResultValueSourcesEn,
  ...toolResultValueUnitsEn,
};

/// 中文：**记号与结论 18 条**——`'无效'` 与 [ToolResultConclusion] 的 17 句。
///       **中文那一侧一个字没动**：值仍是产出方写下的同一句话（枚举里的 [sentence]），
///       改的只是屏幕上那一格查不查表。
/// English: **the marker and the conclusions, 18** — `'无效'` and the 17 sentences of
///          [ToolResultConclusion]. **Not one character of Chinese moved**: the value is still the
///          sentence the producer wrote (the enum's [sentence]); only whether the cell on screen goes
///          through a table has changed.
const Map<String, String> toolResultValuesConclusionsEn = <String, String>{
  '无效': 'N/A',
  '未回收': 'Not recovered',
  '会下滑': 'Slides',
  '摩擦可抵住': 'Friction holds',
  '无穷大': 'Infinite',
  '过渡': 'Transition',
  '超量程': 'Over range',
  '压差不足': 'Insufficient headroom',
  '制动/回馈': 'Braking / regen',
  '无解': 'No solution',
  '无穷多解': 'Infinitely many',
  '恒等式': 'Identity',
  '唯一解': 'Unique solution',
  '对数无效': 'Log undefined',
  '同向平行': 'Parallel, same way',
  '反向平行': 'Parallel, opposite',
  '垂直': 'Perpendicular',
  '在范围内': 'Within range',
};

/// 中文：**值里那几个词 90 条**——从 `calculate_tool*.dart` 的 `ToolResult(value)` 那一格与
///       输入来源串的内部逐条量出来的（`'x轴'`、`'层流'`、`'偏瘦'`…）。
///       前八条**只出现在来源串内部**（`'电压+电流，电阻、功率作参考'` 里的"电阻"、"功率"），
///       所以它们在这里是小写词根，由 [ToolResultValueStrings._composedSource] 拼进英文句子。
///       末尾九条是三角形那九种合体（见下）。
/// English: **the 90 words inside a value**, measured cell by cell from `ToolResult(value)` in
///          `calculate_tool*.dart` and from inside the source strings (`'x轴'`, `'层流'`, `'偏瘦'`, …).
///          The first eight below **occur only inside a source string** (the "电阻" and "功率" of
///          `'电压+电流，电阻、功率作参考'`), so they are lowercase roots here and are assembled into an
///          English sentence by [ToolResultValueStrings._composedSource]. The last nine are the nine
///          triangles (see below).
const Map<String, String> toolResultValueWordsEn = <String, String>{
  // —— 来源串内部的词根（只在这里出现）——
  '电阻': 'resistance',
  '功率': 'power',
  '电流': 'current',
  '电压': 'voltage',
  '电压方向': 'voltage direction',
  '质量浓度': 'mass concentration',
  '摩尔浓度': 'molarity',
  '剩余量': 'remaining amount',
  '剩余比例': 'remaining ratio',
  // —— 目标值那一族（来源串的参考项：`'…，目标终值作参考'`）——
  '新值': 'new value',
  '目标值': 'target value',
  '结果值': 'result value',
  '目标月供': 'target monthly payment',
  '目标每期': 'target installment',
  '目标终值': 'target final value',
  '目标费用': 'target cost',
  '目标销量': 'target volume',
  // —— 判断句（值就是那句话）——
  'a 不能为 0': 'a must not be 0',
  '不可逆': 'Not invertible',
  '可逆': 'Invertible',
  '无': 'None',
  '对数有效': 'Log valid',
  '任意实数': 'Any real number',
  '已取整数': 'Rounded to integers',
  '零向量': 'Zero vector',
  '一般夹角': 'Oblique angle',
  '等边': 'Equilateral',
  '等腰': 'Isosceles',
  '不等边': 'Scalene',
  '直角': 'Right angle',
  '锐角': 'Acute angle',
  '钝角': 'Obtuse angle',
  // 中文：**三角形那九种合体**——`calculate_tool_math_geometry.dart` 的 `_triangleType` 把
  //       "边型 + 角型"直接黏成一个值（`return '$sideType$angleType'`），所以上面那六个词
  //       单独出现在屏幕上是不可能的：屏幕上只有 `'等边锐角'` 这种。九种组合都列出来，
  //       英文按英语里说三角形的方式写（`'Isosceles right'` 而不是 `'Isosceles Right angle'`）。
  //       **不是**把六个词拼起来算的：拼出来会是 `'Equilateral Acute angle'`，
  //       而这一格该是给人读的。
  // English: **the nine triangles the two halves make** — `_triangleType` in
  //          `calculate_tool_math_geometry.dart` glues the side type and the angle type into one value
  //          (`return '$sideType$angleType'`), so the six words above never reach the screen on their
  //          own: only the assembled `'等边锐角'` does. All nine pairs are listed, in the way English
  //          names triangles (`'Isosceles right'`, not `'Isosceles Right angle'`). **They are not
  //          assembled from the six**: that would read `'Equilateral Acute angle'`, and this cell is
  //          meant for a person.
  '等边锐角': 'Equilateral acute',
  '等边直角': 'Equilateral right',
  '等边钝角': 'Equilateral obtuse',
  '等腰锐角': 'Isosceles acute',
  '等腰直角': 'Isosceles right',
  '等腰钝角': 'Isosceles obtuse',
  '不等边锐角': 'Scalene acute',
  '不等边直角': 'Scalene right',
  '不等边钝角': 'Scalene obtuse',
  '偏瘦': 'Underweight',
  '正常': 'Normal',
  '超重': 'Overweight',
  '肥胖': 'Obese',
  '偏低': 'Low',
  '较低风险': 'Lower risk',
  '偏高风险': 'Elevated risk',
  '较高风险': 'High risk',
  '先上抛后下落': 'Up first, then down',
  '向下': 'Downward',
  '向上/反向': 'Up / opposite',
  '正功': 'Positive work',
  '负功': 'Negative work',
  '无功': 'No work',
  '吸热': 'Heat absorbed',
  '放热': 'Heat released',
  '无热量': 'No heat',
  '酸性': 'Acidic',
  '碱性': 'Alkaline',
  '近中性': 'Near neutral',
  '无输出功': 'No output power',
  '驱动': 'Driving',
  '零位': 'Zero position',
  '压缩': 'Compression',
  '拉伸': 'Tension',
  '拉伸/反向': 'Tension / opposite',
  '无加速度': 'No acceleration',
  '正向加速': 'Accelerating forward',
  '反向加速': 'Accelerating backward',
  '静止': 'At rest',
  '开口皮带同向': 'Open belt, same direction',
  '正向': 'Forward',
  '反向': 'Reverse',
  '相反': 'Opposite',
  '无载荷': 'No load',
  '较安全': 'Fairly safe',
  '临界': 'Critical',
  '失效风险': 'Failure risk',
  '层流': 'Laminar',
  '湍流': 'Turbulent',
  'x轴': 'x-axis',
  'y轴': 'y-axis',
  '无下滑趋势': 'No sliding tendency',
  '盈利': 'Profit',
  '亏损': 'Loss',
  '持平': 'Break-even',
  '有效': 'Valid',
  '可调节': 'Adjustable',
  '请使用文本详情页': 'Use the text detail page',
};

/// 中文：**输入来源 107 条**——`calculate_tool*.dart` 里 `source` 那一格写下的值
///       （`'电压+电流'`、`'热量+质量+比热容'`…），外加三条把"参考量"写进句子里的圆形量来源。
///       加号两侧的词与目录里那些是同一批（电压、质量、比热容…），**不另起一份**：整条仍进表，
///       因为英文的语序与中文不同（`'质量+比热容+温度变化'` 不是三段简单拼接）。
/// English: **the 107 input sources** — what `calculate_tool*.dart` writes into `source`
///          (`'电压+电流'`, `'热量+质量+比热容'`, …), plus the three circle sources that spell their
///          reference out. The words either side of the plus sign are the catalogue's own (voltage,
///          mass, specific heat …) and are **not copied separately**: the whole string still enters the
///          table, because English orders the pieces differently (`'质量+比热容+温度变化'` is not three
///          segments joined).
const Map<String, String> toolResultValueSourcesEn = <String, String>{
  // —— 电子 / 电学 ——
  '电压+电流': 'Voltage + current',
  '电压+电阻': 'Voltage + resistance',
  '电流+电阻': 'Current + resistance',
  '功率+电阻': 'Power + resistance',
  '功率+电流': 'Power + current',
  '功率+电压': 'Power + voltage',
  // —— 数学 / 比例 / 百分比 ——
  '基准值+百分比': 'Base + percent',
  '基准值+百分比，结果值作参考': 'Base + percent, with the result value as reference',
  '基准值+百分比结果': 'Base + percent value',
  '基准值+百分比结果，新值作参考': 'Base + percent value, with the new value as reference',
  '基准值+新值': 'Base + new value',
  '百分比+百分比结果': 'Percent + percent value',
  '百分比+百分比结果，新值作参考': 'Percent + percent value, with the new value as reference',
  '百分比+新值': 'Percent + new value',
  '百分比结果+新值': 'Percent value + new value',
  '原始值+原比例+目标比例': 'Original value + original ratio + target ratio',
  '原始值+原比例+目标比例，目标值作参考':
      'Original value + original ratio + target ratio, with the target value as reference',
  '缩放后+原比例+目标比例': 'Scaled value + original ratio + target ratio',
  '缩放后+原始值+目标比例': 'Scaled value + original value + target ratio',
  '缩放后+原始值+原比例': 'Scaled value + original value + original ratio',
  // —— 圆形 ——
  '半径，其他圆形量作参考': 'Radius, with the other circle quantities as reference',
  '直径，其他圆形量作参考': 'Diameter, with the other circle quantities as reference',
  '周长，其他圆形量作参考': 'Circumference, with the other circle quantities as reference',
  // —— 物理：运动 / 密度 / 热量 ——
  '速度+时间': 'Speed + time',
  '速度+时间，距离作参考': 'Speed + time, with the distance as reference',
  '距离+时间': 'Distance + time',
  '距离+速度': 'Distance + speed',
  '质量+体积': 'Mass + volume',
  '质量+体积，密度作参考': 'Mass + volume, with the density as reference',
  '质量+密度': 'Mass + density',
  '体积+密度': 'Volume + density',
  '热量+比热容+温度变化': 'Heat + specific heat + temperature change',
  '热量+质量+比热容': 'Heat + mass + specific heat',
  '热量+质量+温度变化': 'Heat + mass + temperature change',
  '质量+比热容+温度变化': 'Mass + specific heat + temperature change',
  '质量+比热容+温度变化，热量作参考':
      'Mass + specific heat + temperature change, with the heat as reference',
  // —— 物理：浓度 / 理想气体 / 半衰期 / 波 ——
  '溶质量+体积': 'Solute mass + volume',
  '溶质量+质量浓度': 'Solute mass + mass concentration',
  '体积+质量浓度': 'Volume + mass concentration',
  '溶质量+摩尔浓度': 'Solute mass + molarity',
  '体积+摩尔浓度': 'Volume + molarity',
  '质量浓度+摩尔浓度': 'Mass concentration + molarity',
  '质量浓度+摩尔浓度，摩尔质量作参考':
      'Mass concentration + molarity, with the molar mass as reference',
  '压力+温度+体积': 'Pressure + temperature + volume',
  '压力+物质的量+体积': 'Pressure + amount of substance + volume',
  '压力+物质的量+温度': 'Pressure + amount of substance + temperature',
  '物质的量+温度+体积': 'Amount of substance + temperature + volume',
  '物质的量+温度+体积，压力作参考':
      'Amount of substance + temperature + volume, with the pressure as reference',
  '初始量+半衰期+经过时间': 'Initial amount + half-life + elapsed time',
  '初始量+半衰期+剩余量': 'Initial amount + half-life + remaining amount',
  '初始量+半衰期+剩余比例': 'Initial amount + half-life + remaining ratio',
  '初始量+经过时间+剩余量': 'Initial amount + elapsed time + remaining amount',
  '初始量+经过时间+剩余比例': 'Initial amount + elapsed time + remaining ratio',
  '波速+频率': 'Wave speed + frequency',
  '波速+频率，波长作参考': 'Wave speed + frequency, with the wavelength as reference',
  '波速+波长': 'Wave speed + wavelength',
  '频率+波长': 'Frequency + wavelength',
  // —— 生活：油耗 ——
  '里程+燃油': 'Distance + fuel',
  '里程+燃油，百公里油耗作参考':
      'Distance + fuel, with the fuel economy as reference',
  '里程+百公里油耗': 'Distance + fuel economy',
  '燃油+百公里油耗': 'Fuel + fuel economy',
  // —— 财务：贷款 / 复利 / 分期 / 利润率 / 盈亏 / 电费 / 折扣 / 税 ——
  '贷款金额+年利率+贷款年限': 'Loan amount + annual rate + term',
  '贷款金额+年利率+贷款年限，目标月供作参考':
      'Loan amount + annual rate + term, with the target monthly payment as reference',
  '目标月供+年利率+贷款年限': 'Target monthly payment + annual rate + term',
  '目标月供+贷款金额+贷款年限': 'Target monthly payment + loan amount + term',
  '本金+年化收益+年限': 'Principal + annual return + years',
  '本金+年化收益+年限，目标终值作参考':
      'Principal + annual return + years, with the target final value as reference',
  '本金+目标终值+年限': 'Principal + target final value + years',
  '本金+目标终值+年化收益': 'Principal + target final value + annual return',
  '每期投入+年化收益+年限': 'Contribution + annual return + years',
  '每期投入+年化收益+年限，目标终值作参考':
      'Contribution + annual return + years, with the target final value as reference',
  '目标终值+年化收益+年限': 'Target final value + annual return + years',
  '目标终值+每期投入+年限': 'Target final value + contribution + years',
  '商品价格+总手续费率+分期期数': 'Price + total fee rate + installments',
  '商品价格+总手续费率+分期期数，目标每期作参考':
      'Price + total fee rate + installments, with the target installment as reference',
  '目标每期+总手续费率+分期期数':
      'Target installment + total fee rate + installments',
  '目标每期+商品价格+分期期数': 'Target installment + price + installments',
  '收益+投入': 'Return + investment',
  '收益+投入，ROI作参考': 'Return + investment, with the ROI as reference',
  '投入+ROI': 'Investment + ROI',
  '收益+ROI': 'Return + ROI',
  '成本+售价': 'Cost + price',
  '成本+售价，目标值作参考': 'Cost + price, with the target value as reference',
  '成本+目标毛利率': 'Cost + target margin',
  '售价+目标毛利率': 'Price + target margin',
  '成本+目标利润': 'Cost + target profit',
  '售价+目标利润': 'Price + target profit',
  '目标毛利率+目标利润': 'Target margin + target profit',
  '功率+每日使用+天数+电价': 'Power + daily use + days + tariff',
  '功率+每日使用+天数+电价，目标费用作参考':
      'Power + daily use + days + tariff, with the target cost as reference',
  '目标费用+每日使用+天数+电价': 'Target cost + daily use + days + tariff',
  '目标费用+功率+天数+电价': 'Target cost + power + days + tariff',
  '目标费用+功率+每日使用+电价': 'Target cost + power + daily use + tariff',
  '目标费用+功率+每日使用+天数':
      'Target cost + power + daily use + days',
  '固定成本+单价+单位变动成本': 'Fixed cost + unit price + unit variable cost',
  '固定成本+单价+单位变动成本，目标销量作参考':
      'Fixed cost + unit price + unit variable cost, with the target volume as reference',
  '目标销量+单价+单位变动成本':
      'Target volume + unit price + unit variable cost',
  '目标销量+固定成本+单位变动成本':
      'Target volume + fixed cost + unit variable cost',
  '目标销量+固定成本+单价': 'Target volume + fixed cost + unit price',
  '原价+折扣': 'List price + discount',
  '原价+折扣，到手价作参考':
      'List price + discount, with the final price as reference',
  '原价+到手价': 'List price + final price',
  '折扣+到手价': 'Discount + final price',
  '税前金额+税率': 'Net amount + tax rate',
  '税前金额+税率，含税金额作参考':
      'Net amount + tax rate, with the gross amount as reference',
  '含税金额+税率': 'Gross amount + tax rate',
  '税前金额+含税金额': 'Net amount + gross amount',
};

/// 中文：**只属于结果格的 10 条单位**——`ToolResult.unit` 那一格带汉字、而输入格上没有的单位
///       （`'元/月'`、`'kWh/天'`、`'个'`…）。输入格上也有的那 11 条（`'元'`、`'万元'`、`'齿'`…）
///       不在这里抄第二遍，查表时从 `toolInputUnitsEn` 借（[ToolResultValueStrings.borrowed]）。
///       整条是记号的单位（`'N·m'`、`'Ω·mm²/m'`、`'mm²'`、`'mAh'`）不进表：两种语言逐字节相同。
/// English: **the 10 units that belong to the result cell alone** — units that hold a Han character in
///          the `ToolResult.unit` cell and do not occur in an input cell (`'元/月'`, `'kWh/天'`,
///          `'个'`, …). The 11 that also occur in an input cell (`'元'`, `'万元'`, `'齿'`, …) are not
///          copied here a second time; the lookup borrows them from `toolInputUnitsEn`
///          ([ToolResultValueStrings.borrowed]). Notation-only units (`'N·m'`, `'Ω·mm²/m'`, `'mm²'`,
///          `'mAh'`) do not enter the table: byte-identical in both languages.
const Map<String, String> toolResultValueUnitsEn = <String, String>{
  '元/月': 'CNY/month',
  '元/年': 'CNY/yr',
  '元/天': 'CNY/day',
  '元/件': 'CNY/unit',
  '元/km': 'CNY/km',
  '元/100km': 'CNY/100km',
  'kWh/天': 'kWh/day',
  'mm²/根': 'mm²/run',
  '个': 'pcs',
  '次': 'times',
};

/// 中文：**这段字里还有汉字吗。** 两个文件共用这一把尺子（本文件的"来源串里的一块"与
///       `tool_insight_strings.dart` 的载荷渲染），定义放在这里是因为洞察那张表本来就要 import
///       本文件。判据取得比 `containsWideOrFullwidth` **窄**——`N·m`、`±`、`℃`、`°`、`Ω`
///       这些记号不是汉字，留着它们不算没翻（英文那一侧也这么写）。
/// English: **does this text still hold a Han character.** Two files share this ruler (this file's
///          "one piece of a source string" and the payload rendering in `tool_insight_strings.dart`);
///          it lives here because the insight table imports this file anyway. The range is
///          **narrower** than `containsWideOrFullwidth` — notation such as `N·m`, `±`, `℃`, `°` and
///          `Ω` is not Han, and a payload that keeps it is not untranslated (nor is the English side
///          written differently).
bool holdsHan(String text) {
  for (final unit in text.codeUnits) {
    if (unit >= 0x3000 && unit <= 0x303F) return true; // 中文标点 / CJK punctuation
    if (unit >= 0x3400 && unit <= 0x9FFF) return true; // 汉字（含扩展 A）
    if (unit >= 0xF900 && unit <= 0xFAFF) return true; // 兼容表意文字
    if (unit >= 0xFF00 && unit <= 0xFFEF) return true; // 全角形式
  }
  return false;
}
