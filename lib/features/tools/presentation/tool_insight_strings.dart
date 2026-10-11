import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';
import 'tool_explanation_strings.dart';
import 'tool_input_strings.dart';
import 'tool_insight_strings_electronics.dart';
import 'tool_insight_strings_finance.dart';
import 'tool_insight_strings_lifestyle.dart';
import 'tool_insight_strings_math.dart';
import 'tool_insight_strings_mechanical.dart';
import 'tool_insight_strings_physics.dart';
import 'tool_insight_strings_structure.dart';
import 'tool_result_label_strings.dart';
import 'tool_result_value_strings.dart';

/// 中文：**工具洞察卡那张表的门面。** 详情页那张卡（`tool_detail_output_section.dart` 的
///       `_insightCard`）从 `_detailController.insights` 拿到一串**中文句子**再逐条
///       `Text(item)` 印出去——`buildToolInsights`（`lib/domain/usecases/tool_insights.dart`）
///       在 `domain` 里把它们拼好，一句话都不经过文案表，于是英文界面上这一整块是中文的。
///       本文件把那串句子接到表上：**产出方一个字没改，改的是屏幕上那一格查不查表。**
///
///       ### 两张表，因为有两类句子
///
///       —— [sentences]（**整句**）：键就是屏幕上那句话本身，值就是英文。442 条里 367 条是这一类
///       （本文件的 8 条 + 七个分类文件），查不到原样返回。
///
///       —— [templates]（**带载荷的句子**）：句子中间嵌着运行期的值（数字、标签、输入来源），
///       键写成**产出方那行源码的原文**（含 `$…`），英文一侧用 `{}` 接住载荷，按出现顺序一一对应。
///       90 条属于这一类。**为什么不把整句算出来再查表**：`'误差按 ±2% 估算，…'` 与
///       `'误差按 ±5% 估算，…'` 是同一句话的两个实例，整句进表就要把每一种数字都抄一遍。
///       这与 `notes_receipt_message.dart` / `settings_backup_messages.dart` 的做法是同一条：
///       **载荷在边缘拼，句子本身进表。**
///
///       ### 模板怎么匹配（本文件唯一的算法，约六十行）
///
///       键 `r'当前按 $source 计算，其余输出由 PV=nRT 换算'` 先被切成**字面段**：
///       `['当前按 ', ' 计算，其余输出由 PV=nRT 换算']`，两段之间是载荷位。匹配一条运行期句子
///       就是：必须以第一段开头、以最后一段结尾，中间每段按顺序找到，段与段之间的原文就是载荷。
///       **一处对不上不是终点**：一条模板的每一种切法都算一个候选，按"载荷最长优先"排
///       （`_InsightTemplate.candidates`）逐个交给 [_splice] 去翻，哪一刀切出来的载荷全认得
///       哪一刀算命中——**这一层回溯不是锦上添花**，`'错误 a 不能为 0'` 只有从后往前切才对得上。
///       一个候选都没成就是**不匹配**（回落到中文），所以一条句子可能试到第 90 条模板才命中
///       ——这也是为什么每条模板**只解析一次**（[_compiled]）而不是每次重建都再切一遍。
///
///       ### 载荷怎么变成英文（[payloadTables]）
///
///       一句话里的载荷可能是：结果标签（`输出电压`）、输入标签（`电压 V`）、结果的**值**或
///       **输入来源**（`无效`、`电压+电流`）、公式（`月供 = 价格 × (1 + 手续费率) / 期数`）。
///       这四种字**各自已经有表**（结果标签表、输入标签表、结果值表、公式表），所以这里不新造
///       词典，只按固定优先级查那四张表：**输入标签 → 结果标签 → 结果值 → 公式**
///       （`N·m` 这种记号两种语言逐字节相同，查不到就是原样，本来也不需要翻）。
///       那四张表之后还有一条**带规则的查法**（[payloadLookups]，今天只有结果值那一族）：
///       结果值表里除了词条还借了输入单位表（`元`、`根`、`齿` 这些**单位**的英文只有那一份），
///       所以查的是函数而不是 map。
///
///       一个载荷的翻译规则，按顺序：
///         · **整格查表**（含上面那条借来的查法）；
///         · 载荷里有 `；` 或 `，` 时按标点拆开、各自翻完再用 `; ` / `, ` 拼回（`输入` 那一行是
///           `电压 V 5V，电流 I 1A` 这样的列表；`范围` 那一行是 `；` 连接的列表）；
///         · 载荷里没有汉字就是**原样**（数字、`V`、`N·m` 这些两语言逐字节相同）；
///         · **载荷里还嵌着一句时再走一遍模板**（`'电压 V 未填写'` —— `输入` 那一行是把内层
///           句子用 `，` 拼起来的，内层自己也有一条模板；不往下钻，空着的可选参数就没人翻）。
///           层数有上限（`_nestingDepth`）；
///         · **值与单位黏在一起时切开**（`'837.854116元'`、`'无效V'`）：产出方把
///           `'${primary.value}${primary.unit}'` 直接拼在一起，中间一个字符都没有，只能反过来找
///           那个切点——切开后两半都得认得。拼回去时补一格空格，`%` 与 `°` 打头的除外（
///           `'N/A %'`、`'N/A °C'` 不是英文写法）；
///         · 载荷以某个**标签加一个空格**开头时（`压降范围 1.2V`、`电压范围 无效`），翻标签
///           那一截、**剩下那截照样翻**；
///         · **翻完还留着汉字的载荷，整条模板判为不匹配。** 这一条既是安全网（宁可不翻，也不把
///           半中半英的句子印出去），也让那条最宽松的模板 `'${primary.label} ${primary.value}
///           ${primary.unit}'`（它形如"任意字符串 + 空格 + 任意字符串"）只在那两截真的都认得时
///           才生效——否则它会抢在更具体的模板前面命中。
///
///       ### 本文件不管什么
///
///       产出方（`lib/domain/usecases/tool_insights*.dart`）**一个字没动**：句子的中文仍是那一句，
///       `_insights` 里存的仍是中文，剪贴板/笔记那条正文读的也仍是 `result.value` 本身。
///       屏幕上的是渲染出来的字，复制出去的是数据——与结果标签表那条边界相同。
/// English: **the facade of the tools' insight-card table.** The card on the detail page
///          (`_insightCard` in `tool_detail_output_section.dart`) takes a list of **Chinese
///          sentences** from `_detailController.insights` and prints each with `Text(item)` —
///          `buildToolInsights` (`lib/domain/usecases/tool_insights.dart`) assembles them in
///          `domain`, not one sentence passing through a copy table, so the whole block is Chinese
///          under an English interface. This file wires that list to tables: **the producers did not
///          change by one character; what changed is whether the cell on screen goes through one.**
///
///          ### Two tables, because there are two kinds of sentence
///
///          — [sentences] (**whole sentences**): the key is the sentence on screen itself and the
///          value is its English. 367 of the 442 are of this kind (this file's 8 plus the seven
///          category files); a miss returns the argument unchanged.
///
///          — [templates] (**sentences that carry a payload**): the sentence has a run-time value in
///          the middle (a number, a label, an input source), so the key is written as **the producer's
///          own source text** (including `$…`) and the English side catches the payloads with `{}`, in
///          order. 90 are of this kind. **Why not compute the whole sentence and look that up**:
///          `'误差按 ±2% 估算，…'` and `'误差按 ±5% 估算，…'` are two instances of one sentence, and
///          tabling it whole would mean copying every number. This is the same line
///          `notes_receipt_message.dart` / `settings_backup_messages.dart` take: **the payload is
///          spliced at the edge, the sentence itself is tabled.**
///
///          ### How a template matches (the only algorithm in this file, about sixty lines)
///
///          The key `r'当前按 $source 计算，其余输出由 PV=nRT 换算'` is cut into **literal segments**:
///          `['当前按 ', ' 计算，其余输出由 PV=nRT 换算']`, with a payload slot between them. Matching a
///          run-time sentence means: it must start with the first segment and end with the last, each
///          middle segment must be found in order, and the text between segments is the payload.
///          **One wrong landing is not the end**: every cut of a template is a candidate, ordered
///          "longest payload first" (`_InsightTemplate.candidates`), handed one by one to [_splice];
///          the cut whose payloads all render is the match. **That backtracking is not a nicety** —
///          `'错误 a 不能为 0'` only comes out right when the cut is taken from the right. No candidate
///          working means **no match** (fall back to Chinese), so one sentence may be tried against
///          all 90 templates before it hits — which is why each template is parsed **once**
///          ([_compiled]) instead of being cut again on every rebuild.
///
///          ### How a payload becomes English ([payloadTables])
///
///          A payload can be a result label (`输出电压`), an input label (`电压 V`), a result **value**
///          or **input source** (`无效`, `电压+电流`), or a formula
///          (`月供 = 价格 × (1 + 手续费率) / 期数`). Each of those four **already has a table** (the
///          result-label table, the input-label table, the result-value table, the formula table), so
///          no new dictionary is built here: the four are consulted in a fixed order — **input labels
///          → result labels → result values → formulas** (notation such as `N·m` is byte-identical in
///          both languages; a miss is the text itself, and nothing needs translating anyway). After
///          the four come the **rule-carrying lookups** ([payloadLookups], today only the result-value
///          family): that table borrows the input-unit table on top of its own entries (`元`, `根`,
///          `齿` are **units** whose English exists in one place only), so what is consulted is a
///          function rather than a map.
///
///          The rules for one payload, in order:
///            · **whole-cell lookup** (including the borrowed one above);
///            · a payload containing `；` or `，` is split on that punctuation, each part rendered, and
///              the parts rejoined with `; ` / `, ` (the `输入` line is a list such as
///              `电压 V 5V，电流 I 1A`; the `范围` line is a `；`-joined list);
///            · a payload with no Han character is **passed through** (numbers, `V`, `N·m` are
///              byte-identical in both languages);
///            · **a payload holding a sentence of its own goes through the templates again**
///              (`'电压 V 未填写'` — the `输入` line joins its inner sentences with `，` and each inner
///              sentence has a template of its own; without the descent a blank optional input would
///              be rendered by nobody). The nesting is bounded (`_nestingDepth`);
///            · **a value glued to a unit is cut apart** (`'837.854116元'`, `'无效V'`): the producer
///              writes `'${primary.value}${primary.unit}'` with no character in between, so the cut
///              can only be found by asking the tables — both halves must be recognised. The halves
///              are rejoined with one space, except after `%` and `°` (`'N/A %'` and `'N/A °C'` are not
///              how English writes it);
///            · a payload that starts with **a label followed by one space** (`压降范围 1.2V`,
///              `电压范围 无效`) renders the label and **renders the rest as well**;
///            · **a payload still holding a Han character after rendering rejects the whole template.**
///              That is both a safety net (rather than print a half-Chinese sentence, print nothing new)
///              and what keeps the loosest template, `'${primary.label} ${primary.value}${primary.unit}'`
///              — which is shaped "any text, a space, any text" — from firing before the more specific
///              ones: it wins only when both halves really are recognised.
///
///          ### What this file does not touch
///
///          The producers (`lib/domain/usecases/tool_insights*.dart`) **did not change by one
///          character**: the sentence's Chinese is still that sentence, `_insights` still holds
///          Chinese, and the clipboard/notes body still reads `result.value` itself. What is on screen
///          is rendered copy; what is copied out is data — the same boundary as the result-label
///          table's.
@immutable
class ToolInsightStrings {
  const ToolInsightStrings({
    required this.sentences,
    required this.templates,
    required this.payloadTables,
    this.payloadLookups = const <String? Function(String)>[],
  });

  /// 中文：**整句表**——键是屏幕上那句话，值是英文；查不到原样返回。
  /// English: **the whole-sentence table** — the key is the sentence on screen, the value its
  ///          English; a miss returns the argument unchanged.
  final Map<String, String> sentences;

  /// 中文：**带载荷的句子**——键是产出方源码的原文（含 `$…`），值是带 `{}` 的英文。
  /// English: **sentences that carry a payload** — the key is the producer's source text (with
  ///          `$…`) and the value is English with `{}` placeholders.
  final Map<String, String> templates;

  /// 中文：**载荷词典，按优先级排**（见文件头）。中文那一侧是空表，所以载荷一个都查不到，
  ///       模板永远不会命中——中文界面下这个类就是恒等函数。
  /// English: **the payload dictionaries, in priority order** (see the head). The Chinese side is
  ///          empty, so no payload resolves and no template ever matches — under a Chinese interface
  ///          this class is the identity function.
  final List<Map<String, String>> payloadTables;

  /// 中文：**带拼装规则的那几张表**，排在 [payloadTables] 后面查。今天只有一张：结果值那一族
  ///       （`ToolResultValueStrings.lookup`）——它除了查表还会按"输入来源"的形状拆一句
  ///       （`'电压+电流，电阻、功率作参考'`），所以交过来的不是一个 map 而是一个函数。
  ///       规则住在那一族自己的文件里，这里只是照优先级调用（见文件头）。
  /// English: **the tables that carry assembly rules**, consulted after [payloadTables]. There is
  ///          exactly one today: the result-value family (`ToolResultValueStrings.lookup`), which not
  ///          only reads a map but also splits a sentence by the "input source" shape
  ///          (`'电压+电流，电阻、功率作参考'`) — hence a function rather than a map. The rules live in
  ///          that family's own file; this one only calls them in priority order (see the head).
  final List<String? Function(String)> payloadLookups;

  /// 中文：一条洞察句子的英文。整句查表 → 按模板形状匹配 → 原样返回。
  /// English: the English of one insight sentence: whole-sentence lookup, then template matching,
  ///          then the argument unchanged.
  String insight(String raw) => _render(raw, _nestingDepth);

  /// 中文：**一层句子的英文**——[insight] 与"载荷里还嵌着一句"（[_renderPayload] 的嵌套那一步）
  ///       走的是同一条路：整句表 → 每条模板的每种切法 → 原样返回。`depth` 是还能再嵌几层，
  ///       到 0 就不再往下钻（模板键理论上可以首尾相接，钻不出头）。
  /// English: **one layer of sentence rendering** — [insight] and the "a payload holds a sentence of
  ///          its own" step in [_renderPayload] take the same road: the whole-sentence table, then
  ///          every split of every template, then the argument unchanged. `depth` counts how many more
  ///          layers may nest; at 0 the descent stops (template keys could in principle chain
  ///          end-to-end, and there has to be a floor).
  String _render(String raw, int depth) {
    final hit = sentences[raw];
    if (hit != null) return hit;
    for (final entry in templates.entries) {
      final compiled = _compiled(entry.key);
      var tried = 0;
      for (final payloads in compiled.candidates(raw)) {
        if (tried >= _candidatesPerTemplate) break;
        tried++;
        final rendered = _splice(entry.value, payloads, depth);
        if (rendered != null) return rendered;
      }
    }
    return raw;
  }

  /// 中文：把英文模板里的 `{}` 换成翻好的载荷。**占位符个数对不上、或还有载荷留着汉字时返回
  ///       `null`**——调用方把它当作"这条模板不匹配"，继续试下一条，最后回落到中文。
  /// English: replaces the `{}` of the English template with the rendered payloads. **Returns `null`
  ///          when the placeholder count disagrees or a payload still holds a Han character** — the
  ///          caller treats that as "this template does not match", tries the next one and finally
  ///          falls back to Chinese.
  String? _splice(String english, List<String> payloads, int depth) {
    final parts = english.split('{}');
    if (parts.length - 1 != payloads.length) return null;
    final buffer = StringBuffer(parts.first);
    for (var i = 0; i < payloads.length; i++) {
      final payload = _renderPayload(payloads[i], depth);
      if (holdsHan(payload)) return null;
      buffer
        ..write(payload)
        ..write(parts[i + 1]);
    }
    return buffer.toString();
  }

  /// 中文：一个载荷的英文。整句查 → 列表拆开分别翻 → **载荷里还嵌着一句时再走一遍模板**
  ///       → **值与单位黏在一起时切开** → 标签前缀翻 → 原样。
  ///
  ///       —— 嵌套那一步（`'电压 V 未填写'`）：`输入` 那一行是把内层句子用 `'，'` 拼起来的
  ///       （`tool_insights.dart` 的 `_inputLine`），内层那一句自己也有一条模板
  ///       （`r'${input.label} 未填写'`）。不往下钻一层，`'未填写'` 就没人翻，整行回落中文——
  ///       而**空着的可选参数是常态**。
  ///
  ///       —— 值+单位那一步（`'837.854116元'`、`'无效V'`）：产出方把 `value` 与 `unit` 直接黏在
  ///       一起（`'${primary.value}${primary.unit}'`），中间一个字符都没有，只能靠两张表反过来找
  ///       那个切点：切开后两半都得认得（半边查表、另半边查表或本来就不带汉字）。切点在
  ///       第一处说得通的地方停；拼回去时中间补一格空格，`%` 与 `°` 打头的除外
  ///       （`'N/A %'`、`'N/A °C'` 不是英文写法）。
  ///
  ///       `depth` 见 [_render]：嵌套用的是**递减后**的层数，到 0 就不再往下钻。
  /// English: the English of one payload: whole lookup, then list splitting, then **one more pass
  ///          through the templates when the payload holds a sentence of its own**, then **a cut when
  ///          a value and a unit are glued together**, then the label prefix, then the text itself.
  ///
  ///          — The nested step (`'电压 V 未填写'`): the `输入` line joins its inner sentences with
  ///          `'，'` (`_inputLine` in `tool_insights.dart`) and the inner sentence has a template of its
  ///          own (`r'${input.label} 未填写'`). Without descending one layer, `'未填写'` is rendered by
  ///          nobody and the whole line falls back to Chinese — and **a blank optional input is the
  ///          normal case**.
  ///
  ///          — The value+unit step (`'837.854116元'`, `'无效V'`): the producer glues `value` and `unit`
  ///          with no character in between (`'${primary.value}${primary.unit}'`), so the only way to
  ///          find the cut is to ask the two tables: both halves must be recognised (one by a lookup,
  ///          the other by a lookup or by holding no Han character at all). The first cut that works
  ///          wins; the halves are rejoined with one space, except after `%` and `°` (`'N/A %'` and
  ///          `'N/A °C'` are not how English writes it).
  ///
  ///          `depth` is as in [_render]: nesting uses the decremented count and stops at 0.
  String _renderPayload(String payload, int depth) {
    if (payload.isEmpty) return payload;
    final direct = _lookup(payload);
    if (direct != null) return direct;
    if (payload.contains('；')) {
      return payload.split('；').map((part) => _renderPayload(part, depth)).join('; ');
    }
    if (payload.contains('，')) {
      return payload.split('，').map((part) => _renderPayload(part, depth)).join(', ');
    }
    if (!holdsHan(payload)) return payload;
    if (depth > 0) {
      final nested = _render(payload, depth - 1);
      if (!holdsHan(nested)) return nested;
    }
    final glued = _splitValueUnit(payload);
    if (glued != null) return glued;
    // 中文：**标签前缀从后往前找**——标签自己可能带空格（`'事件 A 概率 0%'`、`'边 a 1'`），
    //       值/单位不带，所以最靠右那个**查得到表的前缀**才是标签那一截。剩下那一截照样要翻
    //       （`'压降范围 1.2V'` 的前缀是标签、后面是数，`'电压范围 无效'` 后面那一截是值），
    //       翻完还带汉字就换下一个前缀——**不许交出半中半英**。
    // English: **the label prefix is searched from the right** — a label may carry spaces of its own
    //          (`'事件 A 概率 0%'`, `'边 a 1'`) while values and units do not, so the rightmost prefix
    //          that hits a table is the label. The remainder is rendered as well (`'压降范围 1.2V'`
    //          has a label in front and a number behind; `'电压范围 无效'` has a value behind); a
    //          remainder that still holds Han moves on to the next prefix — **a half-Chinese result is
    //          never handed back**.
    for (var space = payload.lastIndexOf(' ');
        space > 0;
        space = payload.lastIndexOf(' ', space - 1)) {
      final head = _lookup(payload.substring(0, space));
      if (head == null) continue;
      final tail = _renderPayload(payload.substring(space + 1), depth);
      if (holdsHan(tail)) continue;
      return '$head $tail';
    }
    return payload;
  }

  /// 中文：**值与单位黏在一起的那一格**：找一个切点，让两半都认得（见 [_renderPayload]）。
  ///       找不到返回 `null`。**只在载荷还带着汉字时才会被问到**，所以两半不可能都原样放行。
  /// English: **a cell where the value and the unit are glued together**: find the cut that makes both
  ///          halves recognisable (see [_renderPayload]). `null` when there is none. It is only ever
  ///          asked about a payload that still holds Han, so the two halves can never both pass
  ///          through untouched.
  String? _splitValueUnit(String payload) {
    for (var cut = 1; cut < payload.length; cut++) {
      final left = payload.substring(0, cut);
      final right = payload.substring(cut);
      final head = _lookup(left) ?? (holdsHan(left) ? null : left);
      if (head == null) continue;
      final tail = _lookup(right) ?? (holdsHan(right) ? null : right);
      if (tail == null) continue;
      final glue = tail.startsWith('%') || tail.startsWith('°') ? '' : ' ';
      return '$head$glue$tail';
    }
    return null;
  }

  /// 中文：先按优先级查 [payloadTables] 那几张 map，再交给 [payloadLookups] 那几条带规则的查法；
  ///       一个都没中就返回 `null`（**不是**原样——调用方要区分"查到了"与"没查到"，
  ///       好接着走后面几条规则）。
  /// English: the [payloadTables] maps in priority order first, then the rule-carrying lookups of
  ///          [payloadLookups]; `null` when none hits (**not** the text itself — the caller has to
  ///          tell a hit from a miss to go on with the remaining rules).
  String? _lookup(String text) {
    for (final table in payloadTables) {
      final hit = table[text];
      if (hit != null) return hit;
    }
    for (final lookup in payloadLookups) {
      final hit = lookup(text);
      if (hit != null) return hit;
    }
    return null;
  }

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过。
  /// English: picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here.
  static ToolInsightStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。
  /// English: the same dispatch as [of], for callers without a `BuildContext`.
  static ToolInsightStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => toolInsightsZh,
      AppLanguage.en => toolInsightsEn,
    };
  }

  /// 中文：**中文那两张表是空的，这是设计不是疏漏**（理由与 `ToolFieldStrings` 那五个空 map 相同）。
  /// English: **the Chinese tables are empty on purpose** (the same reasoning as `ToolFieldStrings`'s
  ///          five empty maps).
  static const ToolInsightStrings toolInsightsZh = ToolInsightStrings(
    sentences: <String, String>{},
    templates: <String, String>{},
    payloadTables: <Map<String, String>>[],
  );

  /// 中文：英文表。四张载荷表按优先级排：输入标签 → 结果标签 → 结果值 → 公式；
  ///       排在四张表之后的是结果值那一族**带规则的查法**（单位借的是输入单位表，
  ///       还会把"值+单位"黏在一起的那一格切开，见 [payloadLookups]）。
  /// English: the English tables. The four payload dictionaries in priority order: input labels,
  ///          result labels, result values, formulas; after them come the rule-carrying lookups of
  ///          the result-value family (the units are borrowed from the input-unit table and a
  ///          "value+unit" cell is cut apart — see [payloadLookups]).
  static final ToolInsightStrings toolInsightsEn = ToolInsightStrings(
    sentences: toolInsightSentencesAllEn,
    templates: toolInsightTemplatesAllEn,
    payloadTables: const <Map<String, String>>[
      toolInputLabelsEn,
      toolResultLabelsAllEn,
      toolResultValuesAllEn,
      toolFormulasEn,
    ],
    payloadLookups: <String? Function(String)>[
      ToolResultValueStrings.toolResultValuesEnInstance.lookup,
    ],
  );
}

/// 中文：**模板里还能再嵌几层句子。** 今天只需要一层（`'输入 电压 V 未填写'` 里的
///       `'电压 V 未填写'` 再套 `r'${input.label} 未填写'`），留到 3 是为了不必每次
///       对着产出方数一遍；**必须有上限**，否则两条首尾相接的模板键能互相套下去。
///       见 [ToolInsightStrings._render]。
/// English: **how many more layers of sentences a payload may nest.** One is enough today
///          (`'电压 V 未填写'` inside `'输入 电压 V 未填写'` matches `r'${input.label} 未填写'` again) and
///          3 leaves headroom; **the bound is not optional**, or two templates that chain
///          end-to-end could nest for ever. See [ToolInsightStrings._render].
const int _nestingDepth = 3;

/// 中文：**一条模板最多试几种切法。** 松模板（`'{} {}{}'`）的切法数 = 句子里空格的个数，
///       长句子能到十几二十种；每一种都要把载荷翻一遍才算"不行"，所以设个上限。
///       从后往前数，先试的是**载荷最长**的那几种（见 [_InsightTemplate.candidates] 里
///       "空格从后往前找"那段）。
/// English: **how many different cuts of one template are tried.** A loose template
///          (`'{} {}{}'`) has as many cuts as the sentence has spaces — a long sentence can reach
///          twenty; each one has to render every payload before it can be called a failure, so there
///          is a ceiling. The count is taken from the right, so the **longest payloads** are tried
///          first (see the "a space scans backwards" note in [_InsightTemplate.candidates]).
const int _candidatesPerTemplate = 16;

/// 中文：**核心那 8 条整句**——`buildToolInsights` 自己写下的（`tool_insights.dart:26,91-97`）：
///       `'无需数值输入'` 与七个分类的兜底句。
/// English: **the 8 core whole sentences** written by `buildToolInsights` itself
///          (`tool_insights.dart:26,91-97`): `'无需数值输入'` and the seven categories' fallbacks.
const Map<String, String> toolInsightsCoreEn = <String, String>{
  '无需数值输入': 'No numeric input needed',
  '理想元件模型，量产前要复核容差、温漂、额定功率和数据手册条件':
      'Ideal-component model; before production, recheck tolerances, drift, power ratings and datasheet conditions',
  '静态估算结果，工程使用还要看材料、疲劳、冲击、装配误差和安全系数':
      'A static estimate; engineering use also depends on material, fatigue, impact, assembly error and safety factor',
  '本地估算，不替代合同条款、税务规则或投资判断':
      'A local estimate; it does not replace contract terms, tax rules or investment judgement',
  '默认理想模型，空气阻力、摩擦、热损耗和活度系数未自动计入':
      'Ideal model by default; air resistance, friction, heat loss and activity coefficients are not included automatically',
  '固定系数换算；行业标准或标况条件不同会有差异':
      'Fixed-factor conversion; other industry standards or reference conditions give different results',
  '按常见工程约定处理，字符编码、时区和平台差异需按实际环境确认':
      'Handled by common engineering convention; confirm character encoding, time zone and platform differences against the real environment',
  '按当前输入和公式计算，实际使用前再核对场景约束':
      'Computed from the current inputs and the formula; recheck the scenario constraints before real use',
};

/// 中文：**核心那 7 条带载荷的句子。** 键是 `tool_insights.dart` 里那几行的**源码原文**；
///       最后一条 `'${primary.label} ${primary.value}${primary.unit}'` 形如
///       "标签 + 空格 + 值 + 单位"，所以它排在**最后**，而且要求每一个载荷都认得
///       （见 [ToolInsightStrings._splice]）。**它切出来是三个载荷不是两个**：
///       两段 `${}` 之间没有字面字符，所以 `splitTemplate` 会切出中间那个空载荷
///       （`['标签', '', '值+单位']`），英文因此写成 `'{} {}{}'`——空的那一格渲染出来是空串，
///       屏幕上就是 `Voltage 12V`。**这条是本轮那条 `{}` 个数断言抓出来的**：
///       原先写的 `'{} {}'` 少一个占位符，`_splice` 于是永远返回 `null`，
///       主结果那一行在英文界面上会一直留在中文。
/// English: **the 7 core sentences that carry a payload.** The key is the **source text** of those
///          lines in `tool_insights.dart`; the last one,
///          `'${primary.label} ${primary.value}${primary.unit}'`, is shaped "label, a space, value,
///          unit", so it comes **last** and requires every payload to be recognised (see
///          [ToolInsightStrings._splice]). **It splits into three payloads, not two**: there is no
///          literal character between the two `${}`, so `splitTemplate` cuts out the empty middle
///          payload (`['label', '', 'value+unit']`) and the English is therefore written
///          `'{} {}{}'` — the empty slot renders as nothing, so the screen shows `Voltage 12V`.
///          **The `{}`-count assertion this round added is what caught this**: `'{} {}'` was one
///          placeholder short, so `_splice` returned `null` for ever and the primary-result line
///          would have stayed Chinese under an English interface.
const Map<String, String> toolInsightTemplatesCoreEn = <String, String>{
  r'公式 ${tool.formula}': 'Formula {}',
  r'${input.label} 未填写': '{} not filled in',
  r'输入 $fields': 'Input: {}',
  r'误差按 ±${formatNumber(tol)}% 估算，范围结果只覆盖该公差，不包含温漂、老化和测量误差':
      'Error estimated at ±{}%; a range result covers only that tolerance and excludes drift, ageing and measurement error',
  r'LED 压降按 ±${formatNumber(vfTol)}V 扫描，实际还会随温度和电流移动':
      'LED forward drop swept at ±{}V; in practice it also moves with temperature and current',
  // 中文：这一条是 raw 的**双引号**字符串——键里那个 `'；'` 自带单引号，`r'…'` 写不下。
  // English: this one is a raw **double-quoted** string — the `'；'` inside the key carries single
  //          quotes of its own, which `r'…'` cannot hold.
  r"范围 ${rangeLabels.join('；')}": 'Range: {}',
  r'${primary.label} ${primary.value}${primary.unit}': '{} {}{}',
};

/// 中文：**整句表的合并结果**——核心 8 条 + 七个分类各一张。八个 map 互不相交，
///       重复键在这里是**编译期错误**（与结果标签表同一道保险）。
/// English: **the merged whole-sentence table** — the 8 core entries plus one map per category. The
///          eight maps are disjoint and a duplicate key is a **compile-time error** here (the same
///          insurance the result-label table takes).
const Map<String, String> toolInsightSentencesAllEn = <String, String>{
  ...toolInsightsCoreEn,
  ...toolInsightsElectronicsEn,
  ...toolInsightsFinanceEn,
  ...toolInsightsLifestyleEn,
  ...toolInsightsMathEn,
  ...toolInsightsMechanicalEn,
  ...toolInsightsPhysicsEn,
  ...toolInsightsStructureEn,
};

/// 中文：**模板表的合并结果**——核心 7 条 + 七个分类各一张（机械那一张今天为空）。
///       **核心那几条放最后**：它们最短、最容易误命中。
/// English: **the merged template table** — the 7 core entries plus one map per category (the
///          mechanical one is empty today). **The core entries go last**: they are the shortest and
///          the easiest to match by accident.
const Map<String, String> toolInsightTemplatesAllEn = <String, String>{
  ...toolInsightTemplatesElectronicsEn,
  ...toolInsightTemplatesFinanceEn,
  ...toolInsightTemplatesLifestyleEn,
  ...toolInsightTemplatesMathEn,
  ...toolInsightTemplatesMechanicalEn,
  ...toolInsightTemplatesPhysicsEn,
  ...toolInsightTemplatesStructureEn,
  ...toolInsightTemplatesCoreEn,
};

/// 中文：**解析过的模板，按源码原文缓存。** 一条句子最多要试 90 条模板，而切分（[splitTemplate]）
///       与匹配无关、只与键有关——重建一次文本可能要走十几行句子，所以切分只做一次。
///       **键是 `const` 表里的字符串本身**，表的生命周期与进程相同，不存在"表换了、缓存没换"。
/// English: **parsed templates, cached by source text.** One sentence may be tried against 90
///          templates, and the split ([splitTemplate]) depends only on the key, not on the match —
///          one text rebuild may walk a dozen sentences, so the split happens once. **The key is the
///          string in a `const` table**, whose lifetime is the process's, so a stale cache is not a
///          possibility.
final Map<String, _InsightTemplate> _templateCache = <String, _InsightTemplate>{};

_InsightTemplate _compiled(String source) =>
    _templateCache.putIfAbsent(source, () => _InsightTemplate(splitTemplate(source)));

/// 中文：**一条模板**——一串字面段，段与段之间是载荷位。`n` 个载荷就是 `n + 1` 段。
/// English: **one template** — a list of literal segments with a payload slot between them. `n`
///          payloads mean `n + 1` segments.
@immutable
class _InsightTemplate {
  const _InsightTemplate(this.segments);

  final List<String> segments;

  /// 中文：拿一条运行期句子来试，**按"最像的切法优先"吐出每一种切法**（载荷列表，空载荷是空串）。
  ///       一种都吐不出来就是不匹配。**这是一个生成器**：调用方一边试一边翻，切法够用就不再往下要
  ///       （`_candidatesPerTemplate` 那道上限），所以不会为了找一种切法把整棵搜索树走完。
  ///
  ///       为什么要"每一种切法"而不是"找第一处"：模板里那些**单空格段**是给标签/值分界的，
  ///       而标签自己带空格（`'电压 V'`）、值后面也可能还跟着空格，从前往后找第一处就会切错，
  ///       切错了载荷翻不认账，**整条模板就白试了**——可句子明明是对的。所以往下试到切对为止。
  /// English: tries one run-time sentence and **yields every cut, the most plausible first** (the
  ///          payload list; an empty payload is the empty string). Nothing yielded means no match.
  ///          **It is a generator**: the caller renders while it walks and stops asking once a cut
  ///          works (`_candidatesPerTemplate` is the ceiling), so a match is not paid for with the
  ///          whole search tree.
  ///
  ///          Why every cut rather than the first hit: the **single-space segments** are what separate
  ///          a label from a value, and labels carry spaces of their own (`'电压 V'`) while a value may
  ///          have spaces after it too — scanning forwards for the first hit cuts in the wrong place,
  ///          the payload then fails to render and **the whole template is wasted** even though the
  ///          sentence was the right one. So it keeps cutting until one of them lands.
  Iterable<List<String>> candidates(String text) sync* {
    final first = segments.first;
    final last = segments.last;
    if (segments.length == 1) {
      if (text == first) yield const <String>[];
      return;
    }
    if (!text.startsWith(first) || !text.endsWith(last)) return;
    final limit = text.length - last.length;
    if (limit < first.length) return;
    yield* _cuts(1, first.length, limit, <String>[], text);
  }

  /// 中文：段 [i] 的每一种落点，往下走到最后一段就吐出一份载荷。**回溯**：把 `payloads` 当栈使，
  ///       吐完自己那格就弹掉。
  /// English: every landing of segment [i], descending to the last segment to yield one payload list.
  ///          **Backtracking**: `payloads` is used as a stack and popped again once yielded.
  Iterable<List<String>> _cuts(int i, int cursor, int limit, List<String> payloads,
      String text) sync* {
    if (i == segments.length - 1) {
      payloads.add(text.substring(cursor, limit));
      yield List<String>.of(payloads);
      payloads.removeLast();
      return;
    }
    final segment = segments[i];
    for (final index in _landings(segment, text, cursor, limit)) {
      payloads.add(text.substring(cursor, index));
      yield* _cuts(i + 1, index + segment.length, limit, payloads, text);
      payloads.removeLast();
    }
  }

  /// 中文：**这一段的落点，从后往前。** 单空格段从后往前扫（理由见 [candidates] 那段注释），
  ///       其余段照旧从前往后（`' 未填写'`、`'；'` 这些是真正的分隔串，只有一处写法）。
  ///       从后往前还带来一个好处：**先试的切法载荷最长**，而载荷越长越可能是"标签+值"的整格，
  ///       所以常用形状先命中，上限那道闸刀几乎不会砍掉对的切法。
  /// English: **the landings of one segment, from the right.** A single-space segment scans backwards
  ///          (see the note in [candidates]); every other segment still scans forwards (`' 未填写'`,
  ///          `'；'` and the like are real separators with exactly one spelling). Scanning backwards has
  ///          a second effect: **the longest payloads are tried first**, and the longer a payload the
  ///          more likely it is a whole "label + value" cell, so the usual shapes land early and the
  ///          ceiling almost never cuts away the right cut.
  Iterable<int> _landings(String segment, String text, int cursor, int limit) sync* {
    if (segment == ' ') {
      for (var index = text.lastIndexOf(segment, limit);
          index >= cursor;
          index = text.lastIndexOf(segment, index - 1)) {
        yield index;
      }
      return;
    }
    // 中文：**空段只有一种落点**，就在光标处——两段之间那一格是"空载荷"
    //       （`'${primary.label} ${primary.value}${primary.unit}'` 中间那格）。`indexOf('')`
    //       会返回 `start` 本身，用 `start + 1` 往下走会越界，所以它得单独出来。
    // English: **an empty segment has exactly one landing**, at the cursor — the slot between two
    //          segments is the "empty payload" (`'${primary.label} ${primary.value}${primary.unit}'`
    //          has one in the middle). `indexOf('')` returns `start` itself and stepping with
    //          `start + 1` would run off the end, so it gets its own branch.
    if (segment.isEmpty) {
      yield cursor;
      return;
    }
    for (var index = text.indexOf(segment, cursor);
        index >= 0 && index <= limit;
        index = text.indexOf(segment, index + 1)) {
      yield index;
    }
  }
}

/// 中文：**把模板键切成字面段。** `$name` 与 `${…}` 都算载荷位（`${…}` 里可能还有一层字符串，
///       所以从 `${` 起要数括号配对，并且跳过引号里的 `}` —— `rangeLabels.join('；')` 就是这种）。
///       模板键里没有字面的 `$`，所以不必处理 `$$`。
/// English: **cuts a template key into literal segments.** Both `$name` and `${…}` count as payload
///          slots (a `${…}` may hold a nested string, so from `${` the braces are counted in pairs and
///          a `}` inside quotes is skipped — `rangeLabels.join('；')` is exactly that case). No
///          template key holds a literal `$`, so `$$` needs no handling.
List<String> splitTemplate(String source) {
  final segments = <String>[];
  var buffer = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source[i] != r'$') {
      buffer.write(source[i]);
      i++;
      continue;
    }
    i++;
    if (i < source.length && source[i] == '{') {
      var depth = 1;
      i++;
      while (i < source.length && depth > 0) {
        final char = source[i];
        if (char == "'" || char == '"') {
          final quote = char;
          i++;
          while (i < source.length && source[i] != quote) {
            i += source[i] == r'\' ? 2 : 1;
          }
        } else if (char == '{') {
          depth++;
        } else if (char == '}') {
          depth--;
        }
        i++;
      }
    } else {
      while (i < source.length && _isIdentifierChar(source.codeUnitAt(i))) {
        i++;
      }
    }
    segments.add(buffer.toString());
    buffer = StringBuffer();
  }
  segments.add(buffer.toString());
  return segments;
}

/// 中文：`$name` 里名字的那些字符（ASCII 字母、数字、下划线）。
/// English: the characters of a `$name`: ASCII letters, digits, underscore.
bool _isIdentifierChar(int unit) =>
    (unit >= 0x30 && unit <= 0x39) ||
    (unit >= 0x41 && unit <= 0x5A) ||
    (unit >= 0x61 && unit <= 0x7A) ||
    unit == 0x5F;

/// 中文：**这段载荷里还有汉字吗**——本文件原来在这里自己写了一份，现在搬到结果值那一族
///       （`tool_result_value_strings.dart` 的 [holdsHan]）**只留一份**：拆句那一侧要问它
///       （"翻完了没有"、给最松的模板把关），切"值+单位"那一侧也要问它（两半都得认得），
///       两处问的必须是同一件事。范围取得比 `containsWideOrFullwidth` **窄**——`N·m`、`±`、`℃`
///       这些记号不是汉字（英文那一侧也这么写），判定表与理由都在那边。
/// English: **does this payload still hold a Han character** — this file used to keep a copy of that
///          predicate right here; it now lives in the result-value family ([holdsHan] in
///          `tool_result_value_strings.dart`) and is **kept in exactly one place**: the splicing side
///          asks it ("fully rendered yet?", the gate on the loosest template) and the "value + unit"
///          cutter asks it too (both halves must be recognised), and both must be asking the same
///          question. The range is **narrower** than `containsWideOrFullwidth` — notation such as
///          `N·m`, `±`, `℃` is not Han (nor is the English side written differently); the predicate
///          and the reasoning live over there.
