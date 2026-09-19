import 'package:flutter/material.dart';

import '../../../domain/entities/tool_category.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'category_visuals.dart';
import 'tool_catalog_strings.dart';
import 'tools_strings.dart';

/// 中文：**一张工具卡上说明最多占几行**——两种语言、浏览态与检索态、每一处表面都是这一个数。
///
///       **为什么是 4：它是从最窄的那处表面倒推出来的，不是拍的。** 说明那一格在 360dp 手机上
///       有三种宽度：工具首页的搜索卡片 **162dp**、分类页 **170dp**、而"其它分类"那张面板
///       （`ToolSearchEmptyState` 的 `Container(padding: 14)`）只有 **140dp**。取最窄的 140dp：
///       `4 × 140 = 560dp` ≥ 两种语言里最长的那条描述（中文 `flow_unit` 449.5dp、英文 357.0dp），
///       所以 117 条在**每一处表面上**都读得全。
///
///       **在 162dp / 170dp 这两处，第 4 行一条都用不到**（真字体实测：两种语言、浏览态与检索态，
///       最多只到 3 行），也就是这个上限在用户真正浏览的地方是空着的——它只在 140dp 那张面板上
///       被 3 条中文用到（`flow_unit`、`torque_unit`、`energy_unit` 那一类单位表）。
///       行数上限从 3 抬到 4 在这两处**一条行的高度都不改**：`Text` 只用它需要的行数。
///
///       为什么要有这个数、改之前的缺陷是什么、代价是几 dp，写在 [ToolListTile] 的注释里；
///       这里是它唯一的定义处，测试直接引用它，免得断言写出一个和卡片不一致的行数。
/// English: **how many lines a description may occupy on one tool card** — one number for both
///          languages, for the browse and search states, and for every surface.
///
///          **Why 4: it is derived from the narrowest surface, not picked.** On a 360dp phone the
///          description cell has three widths — **162dp** in the tools home's search card, **170dp** on
///          the category page, and only **140dp** in the "other categories" panel
///          (`ToolSearchEmptyState`'s `Container(padding: 14)`). Taking the narrowest, 140dp:
///          `4 × 140 = 560dp` ≥ the longest description in either language (Chinese `flow_unit` at
///          449.5dp, English at 357.0dp), so all 117 read in full **on every surface**.
///
///          **At 162dp and 170dp the fourth line is never used** (measured with the real fonts: two
///          languages, browse and search states, three lines at most), i.e. the cap sits unused where
///          people actually browse — only three Chinese rows reach it on the 140dp panel (`flow_unit`,
///          `torque_unit`, `energy_unit` and their like, the unit tables). Raising the cap from 3 to 4
///          **changes no row's height** on those two surfaces: a `Text` only takes the lines it needs.
///
///          Why this number exists, what the defect was before, and what it costs in dp, are written on
///          [ToolListTile]; this is its only definition, and tests reference it directly so that no
///          assertion can name a line count the card does not use.
const int toolDescriptionMaxLines = 4;

class HorizontalToolList extends StatelessWidget {
  const HorizontalToolList({
    required this.tools,
    required this.onTap,
    super.key,
  });

  final List<ToolDefinition> tools;
  final ValueChanged<ToolDefinition> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 中文：卡片上是**目录里的名字**（`ToolCatalogStrings`），不是 `tool.title`——后者是内容数据，
    //       住在 `lib/domain/usecases/tool_catalog*.dart`，中文下两者取值相同，英文下不同。
    // English: the card shows the **catalogue's name** (`ToolCatalogStrings`), not `tool.title` —
    //          the latter is content data living in `lib/domain/usecases/tool_catalog*.dart`; the two
    //          coincide in Chinese and differ in English.
    final catalog = ToolCatalogStrings.of(context);
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final tool = tools[index];
          return InkWell(
            onTap: () => onTap(tool),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 78,
              padding: const EdgeInsets.all(10),
              decoration: softPanel(context: context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tool.icon, color: tool.color),
                  const SizedBox(height: 8),
                  Text(catalog.toolName(tool.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurface)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    required this.category,
    required this.count,
    required this.onTap,
    super.key,
  });

  final ToolCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 中文：分类卡上的名字也走目录表，理由与上面那张工具卡相同。
    // English: the name on a category card comes from the catalogue table too, for the same reason
    //          as the tool card above.
    final catalog = ToolCatalogStrings.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: category.color.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(category.icon, color: category.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(catalog.categoryTitle(category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(ToolsStrings.of(context).toolCount(count),
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ToolListTile extends StatelessWidget {
  const ToolListTile({
    required this.tool,
    required this.favorite,
    required this.onTap,
    this.onFavoriteToggle,
    this.matchLabel,
    this.trailing,
    super.key,
  });

  final ToolDefinition tool;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final String? matchLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 中文：列表项上的标题与上面几张卡同源——目录表，不是 `tool.title`。
    // English: the tile's title comes from the same source as the cards above — the catalogue table,
    //          not `tool.title`.
    final catalog = ToolCatalogStrings.of(context);
    // 中文：副标题是**目录表里的描述**，与标题同一次 `of(context)`——名字与描述在同一张卡片上，
    //       两张表就会有两个 switch，语言分叉时会出现「英文名 + 中文描述」。理由写在
    //       `tool_description_strings.dart` 的文件头上；`tool.description` 那个字段仍是检索用的
    //       中文，本轮一个字节都没动。
    // English: the subtitle is the **catalogue table's description**, from the same `of(context)` call
    //          as the title — name and description sit on one card, and two tables mean two switches,
    //          where a language split puts an English name over a Chinese description. The reason is on
    //          `tool_description_strings.dart`'s file head; the `tool.description` field is still the
    //          Chinese that search reads, and not one byte of it moved this round.
    final description = catalog.toolDescription(tool.id);
    final matchLabel = this.matchLabel;
    return ListTile(
      onTap: onTap,
      // 中文：**命中提示占自己的一行，不再接在说明后面。** 接在说明后面时，副标题只有 162dp
      //       （工具首页）/ 170dp（分类页）宽，而说明本身就超过这个宽度：360dp 手机上实测
      //       （`RenderParagraph` 的 `constraints.maxWidth` + `didExceedMaxLines`，两种语言 ×
      //       （首页五个查询 + 分类页三个分类），共 343 行）**连标签那半截都读得到的：0 行**。
      //       接在后面时提示永远排在说明之后、也就永远排在省略号之后；换成自己的行它才排在
      //       省略号**之前**——同一批 343 行，改完是 343 / 343 读得到标签。
      //
      //       为什么是「加一行」而不是「搜索时用提示顶掉说明」：提示自己也比一行宽
      //       （`命中：工具 ID · gear ratio` 实测 163dp、英文 185dp，都超过 162dp），顶掉说明是
      //       既丢了说明、提示还照样被截。见 `tools_match_hint_visible_test.dart` 里那几条按真
      //       Roboto 字宽量出来的断言。
      //
      //       高度：搜索时最低 88dp（`isThreeLine` 抬的 +16dp），提示长到两行时到 124dp。
      //       卡片里是 `Column`，没有写死的高度可撑破（整轮全套测试没有一条 overflow）。
      //
      //       **说明那一格现在可以换行**（`toolDescriptionMaxLines`，默认语言下这一条是主因）：
      //       改之前它写死一行，而 360dp 上只有 162dp / 170dp 宽，**117 条中文里 94 条在省略号处
      //       截断**（英文 74 条）——中文是默认语言，也就是说五分之四的描述读不到。
      //       修法只是把行数放开，**一个字都没改**。三种盒子宽度（162 / 170 / 140dp）上逐条量
      //       （真 Roboto + 真 Noto Sans，`RenderParagraph.didExceedMaxLines`，117 × 2 语言 ×
      //       2 状态）：**改之前 94 / 93 / 102 条截断，改之后 0 / 0 / 0**。
      //
      //       代价（同一把尺子，逐条加总）：浏览态那一格中文平均 **72.0 → 81.1dp**（+12.7%）、
      //       英文 73.3 → 79.4（+8.2%）；搜索态中文 87.1 → 100.1（+14.9%）、英文 89.8 → 98.1（+9.3%）。
      //       涨的只有那些本来要被吃掉的尾巴：**中文 23 条仍然 72dp**（与改动前一模一样，它们本来就
      //       读得全），83 条到 80–84dp，11 条到 102–104dp。最窄的那张 140dp 面板上最高 124dp
      //       （检索态 164dp，3 条中文）。
      //
      //       仍然读不全的那一截在**末尾**：标签（最宽的 `Matched: Parameter · x` 实测约 151dp）
      //       永远落在第一行之内，被省略号吃掉的只可能是后面的命中原文，而它通常就是用户刚敲进去
      //       的那串字。原文长到两行还装不下的，实测是 343 行里的 14 行（都在 `a` 那个查询里，
      //       命中的是一条被截到 34 字的别名）。
      // English: **The match hint gets its own line instead of being appended to the description.**
      //          Appended, the subtitle line is only 162dp wide (tools home) / 170dp (category page)
      //          and the description alone overflows it: measured on a 360dp phone (the `RenderParagraph`'s
      //          `constraints.maxWidth` plus `didExceedMaxLines`; two languages × five tools-home
      //          queries + three category-page categories, 343 rows), **0 rows showed even the label**.
      //          Appended, the hint always sits after the description and therefore always after the
      //          ellipsis; on its own line it sits before it — the same 343 rows become 343 / 343 for
      //          the label.
      //
      //          Why a second line rather than replacing the description while searching: the hint is
      //          wider than one line itself (`命中：工具 ID · gear ratio` measures 163dp, 185dp in
      //          English, both against a 162dp line), so replacing would lose the description *and*
      //          still cut the hint. See the assertions measured with real Roboto advances in
      //          `tools_match_hint_visible_test.dart`.
      //
      //          Height: while searching the floor is 88dp (the +16dp `isThreeLine` adds), rising to
      //          124dp when a hint wraps. The card holds a `Column`, so there is no fixed height to
      //          break (no overflow anywhere in the suite).
      //
      //          **The description may now wrap** (`toolDescriptionMaxLines`; in the default language
      //          this is the main event): it used to be pinned to one line, only 162dp / 170dp wide on a
      //          360dp phone, and **94 of the 117 Chinese entries were cut at the ellipsis** (74 English)
      //          — Chinese being the default language, four descriptions in five could not be read. The
      //          fix only opens the line count up; **not one word of the copy changed**. Measured entry by
      //          entry at three box widths (162 / 170 / 140dp, real Roboto + real Noto Sans,
      //          `RenderParagraph.didExceedMaxLines`, 117 × 2 languages × 2 states): **94 / 93 / 102 rows
      //          clipped before, 0 / 0 / 0 after**.
      //
      //          What it costs (same ruler, summed per row): in the browse state the cell's Chinese
      //          average goes **72.0 → 81.1dp** (+12.7%) and English 73.3 → 79.4 (+8.2%); in the search
      //          state Chinese 87.1 → 100.1 (+14.9%) and English 89.8 → 98.1 (+9.3%). Only the tails that
      //          were being eaten grew: **23 Chinese rows are still 72dp** (exactly what they were, they
      //          always read in full), 83 land at 80–84dp and 11 at 102–104dp. On the narrowest, 140dp
      //          panel the tallest is 124dp (164dp in its search state, for three Chinese rows).
      //
      //          What still cannot be read in full is the tail: the label (the widest being
      //          `Matched: Parameter · x` at about 151dp) always lands inside the first line, so only
      //          the matched text after it can fall to the ellipsis — and that text is usually the very
      //          string the user just typed. Matched text so long that two lines still do not hold it:
      //          14 of those 343 rows, all under the `a` query, where the match is a 34-character
      //          truncated alias.
      isThreeLine: matchLabel != null,
      subtitle: matchLabel == null
          ? Text(description,
              maxLines: toolDescriptionMaxLines,
              overflow: TextOverflow.ellipsis)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(description,
                    maxLines: toolDescriptionMaxLines,
                    overflow: TextOverflow.ellipsis),
                Text(matchLabel,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: tool.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(tool.icon, color: tool.color),
      ),
      title: Text(catalog.toolName(tool.id),
          style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: trailing ??
          (onFavoriteToggle == null
              ? favorite
                  ? const Icon(Icons.star, color: Colors.amber, size: 18)
                  : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
              : IconButton(
                  tooltip: favorite
                      ? ToolsStrings.of(context).favoriteRemove
                      : ToolsStrings.of(context).favoriteAdd,
                  onPressed: onFavoriteToggle,
                  icon: Icon(favorite ? Icons.star : Icons.star_border,
                      color: favorite ? Colors.amber : scheme.onSurfaceVariant),
                )),
    );
  }
}

class ToolSearchEmptyState extends StatelessWidget {
  const ToolSearchEmptyState({
    required this.message,
    required this.suggestions,
    required this.examples,
    required this.onQuerySelected,
    this.alternatives = const <Widget>[],
    super.key,
  });

  final String message;
  final List<String> suggestions;
  final List<String> examples;
  final ValueChanged<String> onQuerySelected;
  final List<Widget> alternatives;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suggestionTexts = suggestions
        .map((suggestion) => suggestion.trim().toLowerCase())
        .toSet();
    final visibleExamples = examples
        .where((example) =>
            !suggestionTexts.contains(example.trim().toLowerCase()))
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: softPanel(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.search_off, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (suggestions.isNotEmpty || visibleExamples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...suggestions.map(
                  (suggestion) => ActionChip(
                    avatar: const Icon(Icons.manage_search, size: 16),
                    label: Text(suggestion),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onQuerySelected(suggestion),
                  ),
                ),
                ...visibleExamples.map((example) => ActionChip(
                      label: Text(example),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onQuerySelected(example),
                    )),
              ],
            ),
          ],
          if (alternatives.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              ToolsStrings.of(context).otherCategories,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            ...alternatives,
          ],
        ],
      ),
    );
  }
}

class DetailMetric extends StatelessWidget {
  const DetailMetric({required this.result, this.onCopy, super.key});

  final ToolResult result;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: softPanel(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(result.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
              ),
              if (onCopy != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    tooltip: ToolsStrings.of(context).copyThisItem,
                    onPressed: onCopy,
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(Icons.copy_outlined,
                        color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(result.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
          Text(result.unit,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}
