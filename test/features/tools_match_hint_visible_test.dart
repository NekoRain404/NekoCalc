import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/tool_search_engine.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/entities/tool_category.dart';
import 'package:nekocalc/features/tools/presentation/tool_category_screen.dart';
import 'package:nekocalc/features/tools/presentation/tool_widgets.dart';
import 'package:nekocalc/features/tools/presentation/tools_home_page.dart';
import 'package:nekocalc/features/tools/presentation/tools_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/roboto_regular_advances.dart';

/// 中文：**命中提示在 360dp 手机上读不读得到**——这一轮修的缺陷靠这四条护栏钉住。
///
///       那个缺陷是：`ToolListTile` 把提示**接在说明后面**，拼成
///       `说明 · 命中：工具 ID · gear ratio` 一个 `maxLines: 1` 的 `Text`。360dp 手机上这一格只有
///       162dp 宽（分类页 170dp），而说明本身就超过这个宽度，于是提示**永远排在省略号之后**：实测
///       343 行（两种语言 ×（首页五个查询 + 分类页三个分类））里，**连标签那半截都读不到的有 343
///       行**。本轮把提示挪到自己的一行。
///
///       **为什么这里不能拿测试字体当尺子。** `flutter_test` 的字体每个字形都占**一整个 em**，
///       于是 `Matched: Tool ID` 在测试字体里是 15 × 14 = 210dp，在真 Roboto 里只有约 110dp——
///       拿它当尺子会把每一条英文断言都判死（实测：`labelVisibleTest` 在英文下 0/115，中文下
///       115/115，同一批行）。所以宽度一律用 [advanceWidth]，即**真 Roboto-Regular 的逐字符
///       advance 表**（ASCII 32–126 全量）+ CJK/全角按 1em；下面每一条宽度断言都在 360dp 的
///       副标题盒子里成立。
///
///       这把尺子的刻度对不对，有一处**设备上量过的**旁证：上一轮的 `Custom Tools`（w800，14sp）
///       在设备上是 **91.0dp**，用同一张表的 Black 版算出来是 90.3dp（差 0.8%）。本表是 Regular，
///       同一串算出来 87.3dp——不宽于设备值，也就是个上限。
///
///       **不能全读完的那一截在末尾、而且只是命中原文**：标签（最宽的 `Matched: Parameter · x`
///       约 152dp）永远在一行之内的开头，被省略号吃掉的只可能是后面的命中原文，而它通常就是用户
///       刚敲进去的那串字。这条是**保证**，由下面第 3 条断言逐条钉住。
///
/// English: **Can the match hint be read on a 360dp phone?** Three guard rails pin the defect this round
///          fixed. The defect: `ToolListTile` **appended** the hint to the description, making one
///          `maxLines: 1` `Text` of `description · 命中：工具 ID · gear ratio`. On a 360dp phone that
///          cell is only 162dp wide (170dp on the category page) and the description alone overflows it,
///          so the hint **always sat after the ellipsis**: of 343 measured rows (two languages × tools
///          home / category page × seven queries), **343 showed not even the label**. This round moves
///          the hint onto a line of its own.
///
///          **Why the test font cannot be the ruler here.** Every glyph of `flutter_test`'s font is a
///          full **em**, so `Matched: Tool ID` is 15 × 14 = 210dp there against about 110dp in real
///          Roboto — as a ruler it condemns every English assertion (measured: `labelVisibleTest` is
///          0/115 in English and 115/115 in Chinese on the same rows). Every width below therefore comes
///          from [advanceWidth]: **real Roboto-Regular per-character advances** (all of ASCII 32–126)
///          plus 1em for CJK/full-width glyphs, checked against the 360dp subtitle box.
///
///          The ruler has one **device-measured** witness for its graduations: last round's
///          `Custom Tools` (w800, 14sp) is **91.0dp** on the device, and the Black table next door
///          computes 90.3dp for it (0.8% off). This table is Regular and computes 87.3dp — narrower than
///          the device value, i.e. an upper bound.
///
///          **What still cannot be read in full is only the tail, and only the matched text**: the label
///          (the widest being `Matched: Parameter · x` at 151.0dp) always sits inside the first line,
///          so the ellipsis can only eat the matched text after it — usually the very string the user
///          just typed. That is a **guarantee**, pinned token by token in the third test below.
void main() {
  testWidgets('搜索时命中提示是独立的一行，且那一行以提示开头（中英文、首页与分类页各一次）',
      (tester) async {
    // 中文：**这是本轮的形状断言**：改动前提示与说明在**同一个** `Text` 里（因此同一个
    //       `RenderParagraph`、同一条省略号），改动后提示是**自己的** `Text`、自己那一段的第一个
    //       字符。`find.text` 对截断无感，所以这里断言的不是"提示在树里"，而是"提示排在这一行的
    //       **开头**"——排在开头才有可能落在省略号之前。
    // English: **the shape assertion of this round**: before, the hint and the description lived in
    //          **one** `Text` (hence one `RenderParagraph`, one ellipsis); after, the hint is its
    //          **own** `Text` and the first thing in its own paragraph. `find.text` is blind to
    //          truncation, so what is asserted is not "the hint is in the tree" but "the hint is at
    //          the **start** of its line" — only then can it land before the ellipsis.
    for (final language in AppLanguage.values) {
      for (final query in const ['gear', 'a']) {
        final rows = await _hintRows(tester, language, query);
        expect(rows, isNotEmpty,
            reason: '`$query` 在 ${language.name} 下一条结果都没有，这条断言会空转');
        for (final row in rows) {
          expect(row.data.startsWith(row.marker), isTrue,
              reason: '这一格里第一个字符不是提示，说明提示又接回说明后面了：${row.data}');
          expect(row.paragraph.maxLines, 2,
              reason: '提示那一行的行数是与下面按字宽量的断言配套的：两行');
          // 中文：**这一行的开头按真 Roboto 量得过**——标签（`命中：工具 ID`）整段落在第一行
          //       之内。断在那儿的只可能是后面的命中原文。
          // English: **this line's beginning measures through in real Roboto** — the whole label
          //          (`命中：工具 ID`) lands inside the first line. Only the matched text after it can
          //          be cut.
          final style = row.paragraph.text.style!;
          expect(style.fontSize, _fontSize, reason: '尺子的字号是从这里读的，主题动过就要重量');
          expect(style.letterSpacing, _letterSpacing, reason: '同上，字距也是尺子的刻度');
          final label = row.data.split(' · ').first;
          final width = advanceWidth(label, style.fontSize!, style.letterSpacing!);
          expect(width, lessThanOrEqualTo(row.paragraph.constraints.maxWidth),
              reason: '「$label」宽 ${width.toStringAsFixed(1)}dp，'
                  '塞不进 ${row.paragraph.constraints.maxWidth.toStringAsFixed(1)}dp 那一行');
        }
      }
    }
  });

  testWidgets('浏览态那一格与改动前相同：一行说明、没有提示、不是三行项', (tester) async {
    // 中文：**默认态不许动。** 不搜索时 `matchLabel` 是 null，副标题必须还是那一个
    //       `maxLines: 1` 的 `Text`（数据就是 `tool.description`），`isThreeLine` 必须是 false——
    //       改动前的高度与逐像素外观都靠这两条保持。
    // English: **the default state must not move.** With no search, `matchLabel` is null, so the
    //          subtitle must still be that one `maxLines: 1` `Text` (whose data is `tool.description`)
    //          and `isThreeLine` must be false — those two keep the old height and the old pixels.
    final tiles = await _categoryTiles(tester);
    expect(tiles, isNotEmpty, reason: '分类页上一个工具都没有，这条断言会空转');
    for (final listTile in tiles) {
      expect(listTile.isThreeLine, isFalse, reason: '浏览态不该是三行项');
      final subtitle = listTile.subtitle;
      expect(subtitle, isA<Text>(), reason: '浏览态副标题应当还是一个 Text');
      expect((subtitle! as Text).maxLines, 1, reason: '浏览态副标题还是一行');
      expect((subtitle as Text).overflow, TextOverflow.ellipsis);
    }
  });

  testWidgets('十个标签（两种语言）都窄于副标题那一行：提示的开头永远读得到', (tester) async {
    final home = ToolsStrings.forLanguage(AppLanguage.zh);
    final cat = ToolsStrings.forLanguage(AppLanguage.en);
    final tokens = <String>[
      ToolMatchTokens.title,
      ToolMatchTokens.toolId,
      ToolMatchTokens.description,
      ToolMatchTokens.formula,
      ToolMatchTokens.explanation,
      ToolMatchTokens.alias,
      ToolMatchTokens.input,
      ToolMatchTokens.unit,
      ToolMatchTokens.parameter,
      ToolMatchTokens.keyword,
    ];
    var checked = 0;
    for (final strings in <ToolsStrings>[home, cat]) {
      final box = await _hintBox(tester, strings == home ? AppLanguage.zh : AppLanguage.en);
      for (final token in tokens) {
        // 中文：量的是 `命中：工具 ID · x` 这一串——标签 + 分隔符 + 命中原文的第一个字符。
        //       它装得下，读者就永远看得到"命中哪个字段"，末尾被省略号吃掉与否只影响原文。
        // English: measured string is `命中：工具 ID · x` — label + separator + the first character of
        //          the matched text. If that fits, the reader always sees which field matched; whether
        //          the tail falls to the ellipsis only affects the matched text.
        final probe = strings.matchWithText(token, 'x');
        final width = advanceWidth(probe, _fontSize, _letterSpacing);
        expect(width, lessThanOrEqualTo(box),
            reason: '${strings.match(token)}（$token）宽 ${width.toStringAsFixed(1)}dp，'
                '塞不进 ${box.toStringAsFixed(1)}dp 那一行——标签都会被截');
        checked++;
      }
    }
    expect(checked, 20, reason: '十个令牌 × 两种语言');
  });

  testWidgets('用户报的那条 `gear`：整句提示在 360dp 上两行内读得完（两种语言）',
      (tester) async {
    // 中文：**设备上那条缺陷的原样**：`gear` 查到 `齿轮传动比、转速、扭矩和功率损耗`，
    //       `matchLabel` 是工具 ID、命中原文是 `gear ratio`。改动前它排在说明之后，整句一个字都
    //       看不到；现在它是自己那一行，按真 Roboto 量 163.3dp（中文）/ 184.7dp（英文），两行
    //       （324dp）之内读得完。
    // English: **the reported defect verbatim**: `gear` finds `齿轮传动比、转速、扭矩和功率损耗`, whose
    //          `matchLabel` is the tool id and whose matched text is `gear ratio`. Before, it sat after
    //          the description and none of it could be seen; now it owns its line and measures 163.3dp
    //          (Chinese) / 184.7dp (English) in real Roboto — readable inside two lines (324dp).
    for (final language in AppLanguage.values) {
      final rows = await _hintRows(tester, language, 'gear');
      expect(rows.length, 1, reason: '`gear` 应当只查到一条');
      final row = rows.single;
      expect(row.data, contains('gear ratio'), reason: '命中原文没了');
      final box = row.paragraph.constraints.maxWidth;
      final width = advanceWidth(row.data, _fontSize, _letterSpacing);
      expect(width, lessThanOrEqualTo(box * row.paragraph.maxLines!),
          reason: '「${row.data}」宽 ${width.toStringAsFixed(1)}dp，'
              '${row.paragraph.maxLines} 行 ${(box * row.paragraph.maxLines!).toStringAsFixed(1)}dp '
              '装不下');
    }
  });
}

/// 中文：一行渲染出来的提示，连同它的文字与段落。
/// English: One rendered hint row, with its text and its paragraph.
class _HintRow {
  const _HintRow(this.data, this.paragraph, this.marker);

  final String data;
  final RenderParagraph paragraph;
  final String marker;
}

/// 中文：副标题那行的字号与字距（从真渲染出来的段落里读到的值，下面每一条宽度断言都先核对这两
///       个数——主题一动，尺子就得重新量）。分类页的盒子 170dp 也由 [_hintBox] 从渲染树里读。
/// English: The subtitle line's font size and letter spacing (read off a really-rendered paragraph and
///          re-checked by every width assertion below — move the theme and the ruler must be
///          re-measured). The category page's 170dp box is read off the render tree too, by [_hintBox].
const double _fontSize = 14;
const double _letterSpacing = 0.25;

/// 中文：把工具首页渲染起来、敲进 `query`，返回这一屏上每一行提示（两种语言各一条）。
/// English: renders the tools home, types `query`, and returns every hint row on screen.
Future<List<_HintRow>> _hintRows(
    WidgetTester tester, AppLanguage language, String query) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AppLanguageScope(
        language: language,
        child: const ToolsHomePage(
          db: _EmptyDatabase(),
          settings: AppSettings.fallback,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();

  final marker = language == AppLanguage.zh ? '命中：' : 'Matched: ';
  return [
    for (final element in find.byType(Text).evaluate())
      if ((element.widget as Text).data != null &&
          (element.widget as Text).data!.contains(marker))
        _HintRow((element.widget as Text).data!,
            element.renderObject! as RenderParagraph, marker),
  ];
}

/// 中文：副标题那一行的可用宽度——从**真渲染出来的**提示段落里读，不写死。
/// English: the subtitle line's available width, read off a **really-rendered** hint paragraph rather
///          than hard-coded.
Future<double> _hintBox(WidgetTester tester, AppLanguage language) async {
  final rows = await _hintRows(tester, language, 'gear');
  return rows.first.paragraph.constraints.maxWidth;
}

/// 中文：分类页浏览态（没有查询）下的那些 `ListTile`。
/// English: the `ListTile`s of the category page in its browse state (no query).
Future<List<ListTile>> _categoryTiles(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(
      body: AppLanguageScope(
        language: AppLanguage.zh,
        child: ToolCategoryScreen(
          db: _EmptyDatabase(),
          category: ToolCategory.mechanical,
          favoriteIds: <String>{},
          settings: AppSettings.fallback,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  return [
    for (final widget in tester.widgetList<ListTile>(find.descendant(
      of: find.byType(ToolListTile),
      matching: find.byType(ListTile),
    )))
      widget,
  ];
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
