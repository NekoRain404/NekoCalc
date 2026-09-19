import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/tool_search_engine.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/entities/tool_category.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/tool_catalog_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_category_screen.dart';
import 'package:nekocalc/features/tools/presentation/tools_home_page.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：`ToolCatalogStrings`（工具目录的名字表）的四条护栏，形状与工具子树另外两张表相同。
///       1) **默认态逐字节不变**：中文表的每一条都拿 `toolCatalog` / `ToolCategory` 在**运行期**
///          逐条比对，而不是照抄一份清单——照抄的同一条错字会两边一起错，比对不会。
///       2) **英文表覆盖同一批 id**，没有空串、没有汉字。
///       3) **每条英文的来路可查**：`A` 类的名字去掉大小写与标点之后必须能在该 id 的别名表里
///          找到（那张表是 `ToolSearch.searchAliases` 给的，也就是
///          `tool_search_aliases_{a,b,c}.dart` 与 `tool_search_data.dart` 的 `unitSearchAliases`
///          两处索引的并集），`B` 类与 `L` 类则必须与下面那张**逐条带理由**的清单互为全集。
///          这一条把"99 条是提升、14 条是新写、4 条本来就是拉丁字母"从报告里的话变成机器能验的事实。
///       4) **屏幕上真的换了**：主页与分类页在装作用域与否两种情况下各渲染一次。
///
/// English: Four guard rails for `ToolCatalogStrings` (the tools catalogue's name table), the same
///          shape as the tools subtree's other two tables. (1) **The default state is byte-identical**:
///          every Chinese entry is compared against `toolCatalog` / `ToolCategory` **at run time**,
///          one by one, rather than against a copied list — a copied list would carry a typo on both
///          sides, a comparison would not. (2) **The English table covers the same ids**, with no
///          empty string and no Han character. (3) **Every English name's provenance is checkable**:
///          an `A` name, stripped of case and punctuation, must be found in that id's alias list (the
///          list `ToolSearch.searchAliases` returns, i.e. the union of the two index sources —
///          `tool_search_aliases_{a,b,c}.dart` and `ToolSearchData.unitSearchAliases` in
///          `tool_search_data.dart`), while the `B` and `L` ids must be **exactly** the ids on the
///          reason-per-entry list below. This clause turns "99 promoted, 14 authored, 4 already
///          Latin" from a claim in a report into a machine-checked fact. (4) **The screen really
///          changed**: the tools home and the category page are each rendered twice, with and without
///          the language scope.
void main() {
  final zh = ToolCatalogStrings.forLanguage(AppLanguage.zh);
  final en = ToolCatalogStrings.forLanguage(AppLanguage.en);

  test('工具目录每个 id 都在这张表里，中文一格与 tool_catalog*.dart 逐字节相同', () {
    expect(toolCatalog.length, 117,
        reason: '目录里一共 117 个工具（77 条 title: + 22 个 _unitTool + 18 个 _textTool）；'
            '这个数字变了，说明目录动过，本表要跟着走');
    expect(zh.toolNames.length, toolCatalog.length,
        reason: '中文表与目录要一一对应：多一条少一条都说明有 id 没跟上');

    for (final tool in toolCatalog) {
      expect(zh.toolName(tool.id), tool.title,
          reason: '${tool.id} 的中文名与目录里那个 title 不一样——默认态就不逐字节了');
    }
  });

  test('英文表覆盖同一批 id，没有空串、没有汉字', () {
    expect(en.toolNames.keys.toSet(), zh.toolNames.keys.toSet(),
        reason: '两张表的 id 集合必须相同');

    for (final tool in toolCatalog) {
      final name = en.toolName(tool.id);
      expect(name.trim(), isNotEmpty, reason: '${tool.id} 在英文表里是空的');
      expect(_containsCjk(name), isFalse,
          reason: '${tool.id} 的英文名里还有汉字：$name');
    }
  });

  test('A 类的名字去掉大小写与标点后，能在该 id 的别名表里找到', () {
    var promoted = 0;
    var notPromoted = 0;
    for (final tool in toolCatalog) {
      final name = en.toolName(tool.id);
      if (_aliasPool(tool).contains(_flat(name))) {
        promoted++;
      } else {
        notPromoted++;
      }
    }
    expect(promoted, 99,
        reason: 'A 类一共 99 条：提升出来的名字必须一条不落地能查回别名表');
    expect(notPromoted, authoredNames.length + latinNames.length,
        reason: '不是提升的只应当是下面那张清单里的那些 id');
  });

  test('B / L 两类 id 与逐条带理由的清单互为全集', () {
    final notPromoted = <String>{
      for (final tool in toolCatalog)
        if (!_aliasPool(tool).contains(_flat(en.toolName(tool.id)))) tool.id,
    };
    expect(notPromoted, _authoredAndLatinIds(),
        reason: '表里新写了一个名字、或者某条名字与别名脱了钩，这里就会对不上——'
            '要么补进清单并写清理由，要么把名字改回索引里那一条');

    // 中文：**清单里每一条都得带理由**，理由不是装饰：它是下一轮复核这 14 条时的唯一依据。
    // English: **every entry on the list carries its reason**, and the reason is not decoration: it
    //          is the only basis a later round has for re-checking these 14.
    for (final entry in authoredNames.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} 没写理由');
    }
    expect(authoredNames.length, 14, reason: 'B 类 14 条');
    expect(latinNames.length, 4, reason: 'L 类 4 条');
  });

  test('八个分类的名字与说明：中文与 ToolCategory 逐字节相同，英文换过且没有汉字', () {
    expect(ToolCategory.values.length, 8);
    for (final category in ToolCategory.values) {
      expect(zh.categoryTitle(category), category.title,
          reason: '${category.name} 的中文名与 ToolCategory.title 不一样');
      expect(zh.categorySubtitle(category), category.subtitle,
          reason: '${category.name} 的中文说明与 ToolCategory.subtitle 不一样');

      final title = en.categoryTitle(category);
      final subtitle = en.categorySubtitle(category);
      expect(title.trim(), isNotEmpty, reason: '${category.name} 的英文名是空的');
      expect(subtitle.trim(), isNotEmpty, reason: '${category.name} 的英文说明是空的');
      expect(_containsCjk(title), isFalse, reason: '${category.name}：$title');
      expect(_containsCjk(subtitle), isFalse, reason: '${category.name}：$subtitle');
      // 中文：分类名与说明都是**新写的**（两处索引里没有分类数据），所以必须真的换过。
      //       说明那一格今天屏幕上没有一处读它（唯一的读者是检索匹配的打分，本轮不碰），
      //       它照样进表、照样钉住——理由写在 `categorySubtitle` 的文档上。
      // English: category names and descriptions are all **authored** (neither alias index holds
      //          category data), so they have to really differ. Nothing on screen reads the
      //          description cell today (its only reader is the search scoring, untouched this
      //          round); it still goes into the table and is still pinned — the reason is on
      //          `categorySubtitle`'s docs.
      expect(title, isNot(category.title), reason: '${category.name} 的英文名没换');
      expect(subtitle, isNot(category.subtitle), reason: '${category.name} 的英文说明没换');
    }
  });

  testWidgets('不装作用域是中文，装上英文作用域是英文', (tester) async {
    late ToolCatalogStrings seen;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        seen = ToolCatalogStrings.of(context);
        return const SizedBox.shrink();
      }),
    ));
    expect(identical(seen, zh), isTrue, reason: '没有作用域时应当是中文表');

    await tester.pumpWidget(MaterialApp(
      home: AppLanguageScope(
        language: AppLanguage.en,
        child: Builder(builder: (context) {
          seen = ToolCatalogStrings.of(context);
          return const SizedBox.shrink();
        }),
      ),
    ));
    expect(identical(seen, en), isTrue, reason: 'en 作用域下应当是英文表');
  });

  testWidgets('没有装作用域时，工具首页的分类名与工具名仍是目录里那串中文', (tester) async {
    await tester.pumpWidget(_app(const ToolsHomePage(
      db: _EmptyDatabase(),
      settings: AppSettings(
        haptics: false,
        hapticStrength: '标准',
        restoreState: false,
        autoSaveHistory: false,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    )));
    await tester.pumpAndSettle();
    // 中文：**这就是"默认态逐字节不变"的证据**：八个分类名一个不少、一个不差，
    //       工具卡上是 `toolCatalog.first.title` 那个字面量。
    // English: **this is the "default state is byte-identical" evidence**: all eight category names
    //          exactly as they are, and the tool card carries the very `toolCatalog.first.title`
    //          literal.
    for (final category in ToolCategory.values) {
      expect(find.text(category.title), findsOneWidget,
          reason: '默认态下分类名 ${category.title} 应当照旧');
    }
    expect(find.text(toolCatalog.first.title), findsWidgets);
  });

  testWidgets('装了英文作用域时，工具首页的分类名与工具名换成英文', (tester) async {
    await tester.pumpWidget(_app(
      const ToolsHomePage(
        db: _EmptyDatabase(),
        settings: AppSettings(
          haptics: false,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: false,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
        ),
      ),
      language: AppLanguage.en,
    ));
    await tester.pumpAndSettle();
    for (final category in ToolCategory.values) {
      expect(find.text(en.categoryTitle(category)), findsOneWidget,
          reason: '${category.name} 的英文名没上屏');
      expect(find.text(category.title), findsNothing,
          reason: '${category.name} 的中文名还在屏幕上');
    }
    expect(find.text(en.toolName(toolCatalog.first.id)), findsWidgets);
    expect(find.text(toolCatalog.first.title), findsNothing);
  });

  testWidgets('分类页的页头、搜索提示与「没有匹配」那句用的是同一份分类名', (tester) async {
    const category = ToolCategory.mechanical;
    await tester.pumpWidget(_app(
      const ToolCategoryScreen(
        db: _EmptyDatabase(),
        category: category,
        favoriteIds: <String>{},
        settings: AppSettings.fallback,
      ),
      language: AppLanguage.en,
    ));
    await tester.pumpAndSettle();
    expect(find.text(en.categoryTitle(category)), findsOneWidget,
        reason: '页头那行应当是英文分类名');
    expect(find.text(category.title), findsNothing,
        reason: '页头上不该再有中文分类名');
    // 中文：**提示语里嵌着分类名**，这一格过去拿的是 `widget.category.title`，现在与页头同源。
    // English: **the hint embeds the category name**; it used to take `widget.category.title` and now
    //          shares one source with the page head.
    expect(find.text('Search ${en.categoryTitle(category)} tools'), findsOneWidget);
  });
}

/// 中文：**新写的 14 条，逐条带理由**——这份清单就是本轮报告里那张要复核的表，理由写在值里。
///       前九条在两处索引里都没有表；后五条有表，但表里没有一条能当名字用。
/// English: **the 14 authored names, each with its reason** — this list is the table to scrutinise in
///          this round's report, with the reason in the value. The first nine have no list in either
///          index; the last five have one, but not a single entry in it can serve as a name.
const Map<String, String> authoredNames = <String, String>{
  'quadratic': 'no alias list for this id in either index',
  'dbm': 'no alias list for this id in either index',
  'friction': 'no alias list for this id in either index',
  'inclined_plane': 'no alias list for this id in either index',
  'flow_velocity': 'no alias list for this id in either index',
  'material_weight': 'no alias list for this id in either index',
  'base_convert': 'no alias list for this id in either index',
  'bitwise': 'no alias list for this id in either index',
  'custom_formula': 'no alias list for this id in either index',
  'timestamp':
      "the four committed entries are 'unix time', 'epoch', 'epoch time' and 'timestamp convert' "
          '— three name a quantity and the fourth is a verb phrase, none is a name',
  'url_codec':
      "every committed entry is a verb phrase ('url encode', 'url decode', 'percent encode', …)",
  'uuid':
      "the committed entries name the data type ('guid') or a sub-case ('uuid v4', 'random uuid', "
          "'uuid validate'), none names the tool",
  'jwt_decode':
      "the committed entries are token kinds ('jwt token', 'bearer token', 'access token', "
          "'id token') and claim terms, not the tool",
  'text_stats':
      "the committed entries name individual counts ('word count', 'character count', "
          "'line count') and one diagnostic, not the tool",
};

/// 中文：**本来就是拉丁字母的四条**：中文标题里一个汉字都没有，没有可翻的东西，英文一格与原样
///       逐字节相同。它们与 [authoredNames] 一起构成"名字不是从别名里提升来的"那一集合。
/// English: **the four that were already Latin**: the Chinese title holds not one Han character, so
///          there is nothing to translate and the English cell is byte for byte the same string.
///          Together with [authoredNames] they make up the set of names not promoted from an alias.
const Set<String> latinNames = <String>{
  'ph',
  'base64',
  'ascii_unicode',
  'fnv_crc',
};

Set<String> _authoredAndLatinIds() => <String>{
      ...authoredNames.keys,
      ...latinNames,
    };

/// 中文：一个 id 的别名表——`ToolSearch.searchAliases` 恰好就是那两处索引的并集，取它比自己
///       解析源文件可靠。**只减掉它自己加在头里的标题与说明**，其余一条不动：那两条是
///       `tool.title` / `tool.description` 本身，不是别名，留着会让"提升"变成自证。
/// English: an id's alias list — `ToolSearch.searchAliases` is exactly the union of the two index
///          sources, and reading it is more reliable than parsing the source files. **Only its own
///          two prepended entries are removed**: those are `tool.title` / `tool.description`
///          themselves rather than aliases, and leaving them in would make "promoted" self-certifying.
Set<String> _aliasPool(ToolDefinition tool) {
  // 中文：**减掉的是"原始那两条字符串"，不是它们归一之后的样子。** 归一先做会把
  //       `rms_peak` 的标题 `Vrms/Vpp换算` 压成 `vrmsvpp`，而别名 `vrms vpp` 压出来一模一样——
  //       于是那条真别名会被顺手删掉（实测踩过），这一格就假红。按原文比对没有这个问题。
  // English: **what is removed is the two original strings, not their normalised forms.** Normalising
  //          first squashes `rms_peak`'s title `Vrms/Vpp换算` to `vrmsvpp`, which is exactly what the
  //          alias `vrms vpp` squashes to — so that genuine alias would be removed too (measured) and
  //          this entry would go falsely red. Comparing on the raw text has no such collision.
  final own = <String>{
    tool.title.replaceAll('/', ' '),
    tool.description.replaceAll('/', ' '),
  };
  return ToolSearch.searchAliases(tool)
      .where((entry) => !own.contains(entry))
      // 中文：**只看纯英文的别名。** 索引里那些中英混排的关键词（`编码 base64`、`rms 峰值`）
      //       归一之后会剩下一个光秃秃的拉丁词，能让一个**新写的**名字误判成"提升"——实测踩过
      //       一次（`base64`：那条中文别名 `编码 base64` 压出来正是 `base64`）。`A` 类的定义
      //       本来就是"名字来自一条英文别名"，所以含汉字的条目根本不参与。
      // English: **only pure-English aliases count.** The index's mixed keywords (`编码 base64`,
      //          `rms 峰值`) flatten to a bare Latin word, which can make an **authored** name look
      //          promoted — measured once already (`base64`: the Chinese alias `编码 base64` flattens
      //          to exactly `base64`). An `A` name is by definition one taken from an English alias,
      //          so entries holding Han characters take no part.
      .where((entry) => !_containsCjk(entry))
      .map(_flat)
      .where((entry) => entry.isNotEmpty)
      .toSet();
}

/// 中文：去掉大小写与一切非字母数字字符。别名全是小写的关键词串，而**表里那一格是给人看的**：
///       首字母大写、`DC-DC` 的连字符、`Vrms / Vpp` 的斜杠都是排版，不是另一个词。归一之后
///       `Op-Amp Gain` 与 `op amp gain` 相等，`DC-DC Feedback` 与 `dcdc feedback` 相等。
/// English: strips case and every non-alphanumeric character. The aliases are all-lowercase keyword
///          runs, while **the table's cell is meant to be read**: initial capitals, the hyphen in
///          `DC-DC` and the slash in `Vrms / Vpp` are typography, not different words. After
///          normalising, `Op-Amp Gain` equals `op amp gain` and `DC-DC Feedback` equals
///          `dcdc feedback`.
///
///          **拼写也算排版，而且这条规则写在明处：本仓库的英文是英式**（`Colour theme`），索引里
///          那条关键词是美式（`hex color`），所以两边都折叠 `colour → color`。**只有这一对**——
///          它是全仓库唯一一处英美拼写落到工具名上的地方（`color_convert` 那一条），不是一把
///          可以随手加词的尺子；再多一处就该像别的例外一样，进清单、写理由。
/// English: ... **spelling counts as typography too, and the rule is stated in the open: this
///          repository's English is British** (`Colour theme`) while the index keyword is American
///          (`hex color`), so both sides fold `colour → color`. **That one pair only** — it is the
///          sole place in this repository where a British/American spelling lands on a tool name
///          (`color_convert`), not a ruler anyone can add words to; one more case would belong on a
///          list with a reason, like every other exception.
String _flat(String text) => text
    .toLowerCase()
    .replaceAll('colour', 'color')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

/// 中文：CJK 统一表意文字区（含扩展 A）。够用了：本项目的界面文案都落在这里。
/// English: The CJK Unified Ideographs block (plus Extension A) — enough, since this project's UI
///          copy lives there.
bool _containsCjk(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}

Widget _app(Widget home, {AppLanguage? language}) => MaterialApp(
      // 中文：`ToolsHomePage` 直接返回一个 `ListView`（外壳会给它套 Scaffold），所以测试要自己
      //       补一层——没有 `Material` 祖先，`TextField` 会在构建时抛。
      // English: `ToolsHomePage` returns a bare `ListView` (the shell wraps it in a Scaffold), so the
      //          test supplies one — without a `Material` ancestor the `TextField` throws while
      //          building.
      home: Scaffold(
        body: language == null
            ? home
            : AppLanguageScope(language: language, child: home),
      ),
    );

/// 中文：一份什么都答"空"的库；护栏测试只关心首帧那几个字，不关心收藏与最近使用。
/// English: A database that answers empty to everything; the guard tests care about the first
///          frame's copy, not about favourites or recents.
class _EmptyDatabase implements AppDatabase {
  const _EmptyDatabase();

  /// 中文：`implements` 只列出真会被调用的那几个；其余的交给 `noSuchMethod` 抛错——真被调到
  ///       说明页面比这份假库以为的读得多，那时应当红，而不是悄悄返回空。
  /// English: `implements` lists only the members actually reached; everything else falls to
  ///          `noSuchMethod` and throws — if one of them is reached, the page reads more than this
  ///          fake assumed and the test should go red rather than quietly answer empty.
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
  Future<List<String>> recentToolIds({int limit = 8}) async => const [];
}
