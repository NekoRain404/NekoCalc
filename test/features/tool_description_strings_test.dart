import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/tool_search_engine.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/entities/tool_category.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/tool_catalog_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_category_screen.dart';
import 'package:nekocalc/features/tools/presentation/tool_widgets.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/roboto_regular_advances.dart';
import '../shared/source_scan.dart';

/// 中文：**工具描述表的六条护栏**，形状与工具子树另外几张表相同。
///       1) **默认态逐字节不变**：中文表的每一条都拿 `toolCatalog` 在**运行期**逐条比对
///          `tool.description`，而不是照抄一份清单——照抄的同一条错字会两边一起错，比对不会；
///          两张表的 id 集合还必须与名字表**互为全集**。
///       2) **英文表覆盖同一批 id**、没有空串、没有汉字，而且**没有一条等于它的中文**——
///          相等就说明那一行根本没翻。
///       3) **数学记号逐字符活着**：中文按 CJK 与全角断开，凡**非 CJK 的连续段**都必须在英文里
///          原样找得到。这条断言**不认任何手写清单**——`ax² + bx + c = 0`、`x^y`、`a:b = c:x`、
///          `2x2`、`A(n,k)`、`PV=nRT`、`V/I/R/P`、`50Ω`、`kN·m`、`℃`/`℉`/`°R`、每一张单位符号表
///          都在它名下。它当场抓到过四条漏网的（`50Ω`、`Base64`、`URL`、`JWT Header` 的大小写），
///          见报告。
///       4) **长度**：卡片上那一行装得下——判据是"英文宽 ≤ max(中文宽, 那一行的宽)"，
///          宽度用真 Roboto-Regular 的字宽尺（`test/shared/roboto_regular_advances.dart`）
///          与**从渲染树里读出来的**行宽、字号、字距。
///       5) **屏幕上真的换了**：分类页在中文/英文下各渲染一次，卡片上那行说明两种语言各是各的。
///       6) **检索没动**：`tool.description` 那个字段仍是中文那一条，`ToolSearch.searchAliases`
///          仍把它前插成别名，中文描述照旧找得到工具。
///
/// English: **six guard rails for the tool description table**, the same shape as the tools subtree's
///          other tables. (1) **The default state is byte-identical**: every Chinese entry is compared
///          against `tool.description` **at run time** by walking `toolCatalog`, not against a
///          transcribed list (a transcription goes wrong on both sides at once; a comparison does
///          not), and the two tables' id sets must be **exactly** the name table's. (2) **The English
///          table covers the same ids**, with no empty string, no Han character, and **not one entry
///          equal to its Chinese** — equality would mean that row was never translated. (3) **The
///          mathematical notation survives character for character**: the Chinese is cut at CJK and
///          full-width boundaries and every **non-CJK run** must be found verbatim in the English.
///          This assertion **consults no hand-written list** — it covers `ax² + bx + c = 0`, `x^y`,
///          `a:b = c:x`, `2x2`, `A(n,k)`, `PV=nRT`, `V/I/R/P`, `50Ω`, `kN·m`, `℃`/`℉`/`°R` and every
///          unit symbol list, and it caught four escapes on the spot (`50Ω`, `Base64`, `URL`, the case
///          of `JWT Header`); see the report. (4) **Length**: the card's line must hold it — the rule is
///          "English width ≤ max(Chinese width, the line's width)", measured with the real
///          Roboto-Regular ruler (`test/shared/roboto_regular_advances.dart`) against a line width,
///          font size and letter spacing **read off the render tree**. (5) **The screen really
///          changed**: the category page renders once per language and the card's description line is
///          each language's own. (6) **Search did not move**: the `tool.description` field is still the
///          Chinese string, `ToolSearch.searchAliases` still prepends it, and the Chinese description
///          still finds its tool.
void main() {
  final zh = ToolCatalogStrings.forLanguage(AppLanguage.zh);
  final en = ToolCatalogStrings.forLanguage(AppLanguage.en);

  test('中文表与目录逐条相同，两张表与名字表互为全集（运行期比对，不是照抄）', () {
    expect(toolCatalog.length, 119,
        reason: '目录里一共 119 个工具（77 条 title: + 22 个 _unitTool + 20 个 _textTool）');
    expect(zh.toolDescriptions.length, toolCatalog.length,
        reason: '中文描述表的条数与目录不同——多一条或少一条都会让下面那条断言空转');
    expect(en.toolDescriptions.length, toolCatalog.length,
        reason: '英文描述表的条数与目录不同');
    expect(zh.toolDescriptions.keys.toSet(), zh.toolNames.keys.toSet(),
        reason: '描述表与名字表必须覆盖同一批 id：漏一个工具会让它的卡片在英文下只剩名字');
    expect(en.toolDescriptions.keys.toSet(), zh.toolNames.keys.toSet(),
        reason: '同上，英文一侧');
    for (final tool in toolCatalog) {
      expect(zh.toolDescriptions[tool.id], tool.description,
          reason: '${tool.id} 的中文描述与 `tool_catalog*.dart` 里那一条不同——'
              '默认态就是那句中文，一个字节都不许动');
      expect(zh.toolDescription(tool.id), tool.description,
          reason: '查表那一层同上（${tool.id}）');
    }
  });

  test('英文表：同一批 id、非空、无汉字，且没有一条是中文那条的原样', () {
    var identical = 0;
    for (final tool in toolCatalog) {
      final value = en.toolDescriptions[tool.id];
      expect(value, isNotNull, reason: '${tool.id} 在英文表里没有描述');
      expect(value, isNotEmpty, reason: '${tool.id} 的英文描述是空串');
      // 中文：**判据是"有没有汉字"，不是 `containsWideOrFullwidth`。** 那个尺子量的是"这里有没有
      //       界面文案"，把 `·`、`℃`、`℉`、`μ`、`Ω` 这些**记号**也算进去——而英文那一侧恰恰
      //       **必须**留着它们（`kN·m`、`℃, ℉, K, °R`、`μV`、`50Ω`），第 3 条护栏就是为它们立的。
      // English: **the criterion is "does it hold a Han character", not `containsWideOrFullwidth`.** That
      //          ruler asks "is there interface copy here" and counts **notation** such as `·`, `℃`,
      //          `℉`, `μ` and `Ω` — which the English side **must** keep (`kN·m`, `℃, ℉, K, °R`, `μV`,
      //          `50Ω`); the third guard rail exists for exactly those.
      expect(_han.hasMatch(value!), isFalse,
          reason: '${tool.id} 的英文描述里有汉字：$value');
      if (value == zh.toolDescriptions[tool.id]) identical++;
    }
    expect(identical, 0,
        reason: '有 $identical 条英文与中文一字不差——那些行根本没翻，回落到目录时会以中文露出来');
  });

  test('数学记号逐字符活着：中文里每一段非 CJK 的字串都必须在英文里原样找得到', () {
    var checked = 0;
    final missing = <String>[];
    for (final tool in toolCatalog) {
      final source = zh.toolDescriptions[tool.id]!;
      final target = en.toolDescriptions[tool.id]!;
      for (final run in notationRuns(source)) {
        checked++;
        if (!target.contains(run)) {
          missing.add('${tool.id}: 「$run」\n    中文 $source\n    英文 $target');
        }
      }
    }
    // 中文：191 是改动前的实测值。**这个数字会随着中文措辞一起动**，所以它只做"断言没空转"的
    //       证据，不是判据本身——判据是上面那条 `contains`。
    // English: 191 is the measured count before this round. **The number moves with the Chinese
    //          wording**, so it is only evidence that the loop ran, not the criterion; the criterion is
    //          the `contains` above.
    expect(checked, greaterThan(150), reason: '只查到 $checked 段记号，遍历多半没跑起来');
    expect(missing, isEmpty,
        reason: '这些记号在英文里没了——数学记号是语言无关的，必须逐字符活着：\n${missing.join('\n')}');
  });

  testWidgets('卡片那一行装得下：英文宽 ≤ max(中文宽, 那一行的宽)（逐条量）',
      (tester) async {
    final rows = await _descriptionRows(tester);
    expect(rows, isNotEmpty, reason: '分类页上一张带说明的工具卡都没有，下面每条断言都会空转');

    // 中文：**尺子的三个刻度都从渲染树里读，不写死。** 主题一动，下面每条宽度断言就该重新量。
    // English: **all three graduations come off the render tree rather than being hard-coded.** Move the
    //          theme and every width assertion below must be re-measured.
    final box = rows.first.paragraph.constraints.maxWidth;
    final style = rows.first.paragraph.text.style!;
    expect(style.fontSize, isNotNull, reason: '描述那一行没有字号，量不了');
    final fontSize = style.fontSize!;
    final letterSpacing = style.letterSpacing ?? 0;
    // 中文：360dp 手机上说明那一行**分类页**实测 170dp、**工具首页** 162dp（上一轮 343 行量出来的
    //       那两个数）。本条用分类页，所以量到 170；读到别的数就说明布局动了，尺子得重量。
    // English: on a 360dp phone the description line measures **170dp on the category page** and
    //          **162dp on the tools home** — the two numbers last round measured over 343 rows. This
    //          test renders the category page, so it reads 170; any other number means the layout moved
    //          and the ruler must be re-measured.
    expect(box, greaterThan(160), reason: '说明那一行只剩 $box，装不下任何一条');
    expect(box, lessThan(175), reason: '说明那一行有 $box——比改动前的 170dp（分类页）宽了');
    expect(fontSize, 14, reason: '尺子的字号是从这里读的');
    expect(letterSpacing, closeTo(0.25, 0.001), reason: '同上，字距也是尺子的刻度');

    var fits = 0;
    final over = <String>[];
    for (final tool in toolCatalog) {
      final zhWidth =
          advanceWidth(zh.toolDescription(tool.id), fontSize, letterSpacing);
      final enWidth =
          advanceWidth(en.toolDescription(tool.id), fontSize, letterSpacing);
      if (enWidth <= box) fits++;
      final budget = zhWidth > box ? zhWidth : box;
      if (enWidth > budget) {
        over.add('${tool.id}: 英文 ${enWidth.toStringAsFixed(1)}dp > '
            '预算 ${budget.toStringAsFixed(1)}dp（中文 ${zhWidth.toStringAsFixed(1)}dp）\n'
            '    中文 ${zh.toolDescription(tool.id)}\n'
            '    英文 ${en.toolDescription(tool.id)}');
      }
    }
    // 中文：**42 是本轮交付时的实测值**，把它钉住是为了让"英文比中文读得全"这件事不会悄悄退回去
    //       （中文那一侧是 23）。改小这条数就要说清楚哪一条为什么变长了。
    // English: **42 is what this round shipped**, pinned so that "the English reads in full more often
    //          than the Chinese" cannot quietly regress (the Chinese side is 23). Lowering it means
    //          saying which line grew and why.
    expect(fits, greaterThanOrEqualTo(42),
        reason: '完整落在一行内的英文描述从 42 条掉到 $fits 条——有行变长了');
    expect(over, isEmpty,
        reason: '这些行比中文**更早**被省略号截断（中文没截的它截了，那就是倒退）：\n'
            '${over.join('\n')}');
  });

  testWidgets('分类页上那行说明真的换了语言（两种语言各渲染一次）', (tester) async {
    final first = toolCatalog.firstWhere((tool) => tool.category == ToolCategory.math);
    final zhDescription = zh.toolDescription(first.id);
    final enDescription = en.toolDescription(first.id);
    expect(zhDescription, isNot(enDescription), reason: '这一条本来就该是两句话');

    for (final language in AppLanguage.values) {
      await _pumpCategory(tester, language);
      final expected =
          language == AppLanguage.zh ? zhDescription : enDescription;
      final unexpected =
          language == AppLanguage.zh ? enDescription : zhDescription;
      expect(find.text(expected), findsWidgets,
          reason: '${language.name} 下卡片上没有这一句：$expected');
      expect(find.text(unexpected), findsNothing,
          reason: '${language.name} 下卡片上还留着另一种语言那一句：$unexpected');
      // 中文：名字那条也一起翻面：守着"名字与描述取自同一次 `of(context)`"——两张表若分派到
      //       不同语言，这里会抓到「英文名 + 中文描述」。
      // English: the name flips with it: this guards "name and description come from one
      //          `of(context)` call" — if the two tables dispatched to different languages, this is
      //          where "English name over Chinese description" gets caught.
      final unexpectedName =
          language == AppLanguage.zh ? en.toolName(first.id) : zh.toolName(first.id);
      expect(find.text(unexpectedName), findsNothing,
          reason: '${language.name} 下出现了另一种语言的名字：$unexpectedName');
    }
  });

  test('检索没动：`tool.description` 仍是中文那一条，仍被前插成别名，仍找得到工具', () {
    final tool = toolById('gear_ratio')!;
    expect(tool.description, zh.toolDescriptions[tool.id],
        reason: '目录里那个字段被改过——检索读的就是它');
    expect(containsWideOrFullwidth(tool.description), isTrue,
        reason: '目录里那个字段不再是中文了，中文描述就没法再被搜到');
    expect(ToolSearch.searchAliases(tool), contains(tool.description.replaceAll('/', ' ')),
        reason: '`searchAliases` 会把描述前插成别名（86 分那一档），那一条不见了');
    expect(
        ToolSearch.searchTools('齿轮传动比').map((result) => result.tool.id),
        contains('gear_ratio'),
        reason: '中文描述里的词查不到这个工具了——描述仍在参与检索匹配');
  });
}

// 中文：**那把"非 CJK 连续段"的尺子本轮搬去了 `test/shared/source_scan.dart`**——
//       同一把尺子还要给 `tool_field_strings_test.dart` 用（量参数标签 / 单位 / 公式 / 解释里的记号），
//       两处各留一份就会各自漂移。判据与这段文字一起搬过去，**行为一个字符都没改**。
// English: **the "non-CJK runs" ruler moved to `test/shared/source_scan.dart` this round** — the same
//          ruler is also needed by `tool_field_strings_test.dart` (measuring the notation in labels,
//          units, formulas and explanations), and two copies would drift. The criterion moved with this
//          text and **not one character of its behaviour changed**.

/// 中文：**汉字**（含扩展 A 与兼容区）。英文那一侧不许有它；`·`、`℃`、`℉`、`μ`、`Ω` 这些**记号**
///       不在此列，它们本来就该在。
/// English: **Han characters** (including extension A and the compatibility block). The English side may
///          not hold one; **notation** such as `·`, `℃`, `℉`, `μ` and `Ω` is not in this class and is
///          supposed to be there.
final RegExp _han = RegExp(r'[㐀-䶿一-鿿豈-﫿]');

/// 中文：一行的说明，连同它的文字与段落。
/// English: one rendered description row, with its text and its paragraph.
class _DescriptionRow {
  const _DescriptionRow(this.data, this.paragraph);

  final String data;
  final RenderParagraph paragraph;
}

/// 中文：分类页（数学，前四张卡）上每一行**说明**，连同它那一段。用 [ListTile] 的 subtitle 去认，
///       而不是按文字找——`Two in series or parallel` 这种描述在电子分类里正好有三条一模一样。
/// English: every **description** row on the category page (maths, the first four cards) with its
///          paragraph. It is identified through [ListTile]'s subtitle rather than by text, because
///          descriptions such as `Two in series or parallel` appear three times over in electronics.
Future<List<_DescriptionRow>> _descriptionRows(WidgetTester tester) async {
  await _pumpCategory(tester, AppLanguage.zh);
  final rows = <_DescriptionRow>[];
  for (final tile in tester.widgetList<ListTile>(find.descendant(
    of: find.byType(ToolListTile),
    matching: find.byType(ListTile),
  ))) {
    final subtitle = tile.subtitle;
    if (subtitle is! Text || subtitle.data == null) continue;
    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(
      of: find.byWidget(tile),
      matching: find.byWidget(subtitle),
    ));
    rows.add(_DescriptionRow(subtitle.data!, paragraph));
  }
  return rows;
}

Future<void> _pumpCategory(WidgetTester tester, AppLanguage language) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AppLanguageScope(
        language: language,
        child: const ToolCategoryScreen(
          db: _EmptyDatabase(),
          category: ToolCategory.math,
          favoriteIds: <String>{},
          settings: AppSettings.fallback,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

class _EmptyDatabase implements AppDatabase {
  const _EmptyDatabase();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<Set<String>> favoriteToolIds() async => const {};

  @override
  Future<void> setFavorite(String toolId, bool favorite) async {}

  @override
  Future<void> markRecent(String toolId) async {}

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async => const [];
}
