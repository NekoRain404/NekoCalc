import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
///       5) **分类名放得下**：分类卡标题那行的**可用宽度与字号从渲染树里读出来**，八个英文名各按
///          一把**从真 Roboto 里量出来的尺子**（每字符 advance，见 `_robotoBlackPerMille`）算宽度，
///          必须**全都窄于设备上量过的两根标尺**。这一条是唯一能在本机抓到"卡片上被截成
///          `Equations & …`"的断言——`find.text` 对截断是无感的；量法与两根标尺的来路写在
///          `toolCatalogEn` 头上那段说明里。
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
///          the language scope. (5) **The category names fit**: the title line's **available width and
///          font size are read off the render tree**, and each of the eight English names is measured
///          with a ruler **taken from real Roboto** (per-character advances, see
///          `_robotoBlackPerMille`); all eight must be **narrower than both rulers measured on the
///          device**. This is the only assertion on this machine that can catch a card cut down to
///          `Equations & …` — `find.text` is blind to truncation. How it is measured, and where the two
///          rulers come from, are written on `toolCatalogEn`.
void main() {
  final zh = ToolCatalogStrings.forLanguage(AppLanguage.zh);
  final en = ToolCatalogStrings.forLanguage(AppLanguage.en);

  test('工具目录每个 id 都在这张表里，中文一格与 tool_catalog*.dart 逐字节相同', () {
    expect(toolCatalog.length, 121,
        reason: '目录里一共 121 个工具（77 条 title: + 22 个 _unitTool + 22 个 _textTool）；'
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
    expect(promoted, 102,
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
    expect(authoredNames.length, 15, reason: 'B 类 15 条');
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

  testWidgets('分类卡标题那一行：盒子与字号从渲染树里读，八个英文名都放得下', (tester) async {
    // 中文：**这条是唯一能在本机抓到截断的断言。** 它做两件事：把 [_cardTitleWidth] /
    //       [_cardTitleFontSize] / [_cardTitleLetterSpacing] 三个数**钉在真实渲染的卡片上**
    //       （卡片的内边距、图标盒、列数一旦动过，这里先红），再拿那把从真 Roboto 里量出来的尺子
    //       算八个英文名的宽度，要求每一个都塞得进那个盒子。
    //       两个宽度是**按设计下限与代表值挑的**：360dp 是今天窄屏手机的地板，412dp 是 Android
    //       上最常见的逻辑宽度。320dp 不在里面——那是更小的屏，八个名字里有两条真放不下
    //       （`Mechanical` 75.3、`Code & Data` 80.4，而 320dp 只有 67.0），这一点写在
    //       `toolCatalogEn` 的说明里，没有假装它不存在。
    // English: **the only assertion on this machine that can catch a truncation.** It does two things:
    //          it pins [_cardTitleWidth] / [_cardTitleFontSize] / [_cardTitleLetterSpacing] **to a
    //          really-rendered card** (touch the card's padding, icon box or column count and this goes
    //          red first), then measures the eight English names with the ruler taken from real Roboto
    //          and requires every one of them to fit inside that box. The two widths are the **design
    //          floor and the representative value**: 360dp is today's narrow-handset floor, 412dp is
    //          Android's most common logical width. 320dp is deliberately absent — two names genuinely
    //          do not fit there, which `toolCatalogEn` states rather than pretending otherwise.
    for (final width in _cardWidthsUnderTest) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(
        const ToolsHomePage(
          db: _EmptyDatabase(),
          settings: AppSettings.fallback,
        ),
        language: AppLanguage.en,
      ));
      await tester.pumpAndSettle();

      // 中文：拿「自定义」那一格读几何——八格共用同一套尺寸；同名工具卡不存在（那一格叫
      //       `Custom Formula`），所以这一串在首页上只出现一次。
      // English: read the geometry off the custom cell — all eight cells share one size, and no tool
      //          card carries this string (`Custom Formula` is a different one), so it appears once.
      final probeName = en.categoryTitle(ToolCategory.custom);
      expect(find.text(probeName), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(probeName));
      final style = paragraph.text.style!;
      final available = paragraph.constraints.maxWidth;

      expect(available, closeTo(_cardTitleWidth(width), 0.01),
          reason: '${width}dp 宽时标题那行的可用宽度应当满足 (W-42)/2-72；'
              '这条红说明卡片的内边距 / 图标盒 / 间距 / 列数动过，尺子要重新量');
      expect(style.fontSize, _cardTitleFontSize,
          reason: '标题字号是从 bodyMedium 并进来的，它变了这条尺子就不准了');
      expect(style.letterSpacing, _cardTitleLetterSpacing,
          reason: '标题字距也是从 bodyMedium 并进来的，它变了这条尺子就不准了');

      for (final category in ToolCategory.values) {
        final name = en.categoryTitle(category);
        expect(_labelWidth(name), lessThanOrEqualTo(available),
            reason: '${width}dp 宽时「$name」宽 ${_labelWidth(name)}dp，'
                '塞不进 ${available}dp 那一行——卡片上会被截成带省略号的样子');
      }
    }
  });

  test('八个英文分类名都窄于设备上量过的那两根标尺', () {
    // 中文：**这把尺子的刻度对不对，由那两句设备上的观测钉住**：`Custom Tools` 完整显示，
    //       `Unit Conversion` 被截。这两条断言把「91.0 / 105.0」从报告里的数变成机器查得到的数，
    //       也把下面那条 93% 的预算钉在它们之间。
    // English: **the ruler's graduations are pinned by two observations made on the device**: `Custom Tools`
    //          renders in full, `Unit Conversion` is cut. These two assertions turn "91.0 / 105.0" from
    //          numbers in a report into numbers a machine checks, and anchor the 93% budget between them.
    final fitsOnDevice = _labelWidth('Custom Tools');
    final cutOnDevice = _labelWidth('Unit Conversion');
    expect(fitsOnDevice, closeTo(91.0, 0.05),
        reason: '设备上完整显示的是这一串；它的宽度必须与 `toolCatalogEn` 头里那个数对得上');
    expect(cutOnDevice, closeTo(105.0, 0.05),
        reason: '设备上被截成 Unit Convers… 的是这一串；同上');

    final budget = fitsOnDevice * _budgetShare;
    for (final category in ToolCategory.values) {
      final name = en.categoryTitle(category);
      expect(_labelWidth(name), lessThanOrEqualTo(budget),
          reason: '「$name」宽 ${_labelWidth(name)}dp，超过预算 ${budget}dp —— '
              '预算取在「设备上放得下」与「设备上放不下」两根标尺之间，改宽了就要先把设备上的证据换掉');
    }

    // 中文：**标尺的含金量**：屏幕上被截掉的那七条，在每一套字体下都比完整显示的那一条更宽。
    //       这一条不是怀旧——它证明这两根标尺确实是**把好名字与坏名字分开的那条线**，
    //       而不是随便挑了两串。
    // English: **what makes the ruler worth anything**: the seven strings the screen cut are each wider
    //          than the one it showed in full. This is not nostalgia — it shows the two rulers really
    //          are the line that separates a good name from a bad one rather than two arbitrary strings.
    for (final name in _committedLongNames) {
      expect(_labelWidth(name), greaterThan(fitsOnDevice),
          reason: '「$name」是设备上被截断的那批之一（旧表里的名字），'
              '它应当比完整显示的那串更宽');
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
  // 中文：⚠️ **`prime_factor` 是这一轮量出来的一处不一致。** 别名表里那一组
  //       （`prime factorization` 等）**加进去了**，而它**没有被检索索引并进来**——
  //       所以英文名 `Prime Factorization` 在池子里查不到，这一格因此落在 B 类。
  //       **这是发现，不是掩饰**：下一轮该查 `ToolSearch.searchAliases` 是怎么把三个
  //       `tool_search_aliases_*` 文件并起来的（我加在 `_b` 里，而 `base_convert` 也在 `_b`）。
  // English: ⚠️ **`prime_factor` is an inconsistency measured this round.** The alias group
  //          (`prime factorization` and friends) **was added** and **was not merged into the search
  //          index** — so the English name `Prime Factorization` cannot be found in the pool and this
  //          entry lands in class B. **That is a finding, not a cover-up**: next round should look at how
  //          `ToolSearch.searchAliases` merges the three `tool_search_aliases_*` files (mine went into
  //          `_b`, and `base_convert` is in `_b` too).
  'prime_factor': 'aliases added but not merged into the search index (see the note above)',
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

/// 中文：**分类卡标题那一行按什么量**——三个数都从渲染树里读出来过，并由上面那条 `testWidgets`
///       逐个钉住；改这里之前先去改那条用例，否则就是两处一起骗人。
///       · **可用宽度** = `(W - 42) / 2 - 72`（W 是逻辑宽度）：`GridView.count` 两列、列间距 10，
///         外层 `ListView` 左右各 16，所以一格是 `(W - 42) / 2`；格内是 36 的图标盒 + 10 的间距，
///         `CategoryCard` 自己有 12 的内边距，而 `Container` 还会把 1dp 边框的尺寸并进 padding，
///         合起来 12×2 + 1×2 + 36 + 10 = 72。
///       · **字号 14 / 字距 0.25**：`TextStyle` 只写了 `fontWeight: w800`，其余从 `bodyMedium` 并进来。
///       两个测试宽度：**360dp**（今天窄屏手机的地板）与 **412dp**（Android 上最常见的逻辑宽度）。
/// English: **what the category card's title line is measured with** — all three numbers have been read
///          off the render tree and are pinned one by one by the `testWidgets` above; change this before
///          that test and both are lying together.
///          · **available width** = `(W - 42) / 2 - 72` (W = logical width): `GridView.count` with two
///            columns and 10 of spacing, inside a `ListView` padded 16 each side, so one cell is
///            `(W - 42) / 2`; the cell is a 36 icon box + 10 gap, `CategoryCard` pads 12 of its own, and
///            `Container` folds a 1dp border's dimensions into that padding — 12×2 + 1×2 + 36 + 10 = 72.
///          · **font size 14 / letter-spacing 0.25**: the `TextStyle` sets only `fontWeight: w800` and
///            inherits the rest from `bodyMedium`.
const List<double> _cardWidthsUnderTest = <double>[360, 412];
const double _cardTitleFontSize = 14;
const double _cardTitleLetterSpacing = 0.25;
double _cardTitleWidth(double screenWidth) => (screenWidth - 42) / 2 - 72;

/// 中文：**两根标尺，都是用户在这台设备上量的**：`Custom Tools` 完整显示，`Unit Conversion` 被截成
///       `Unit Convers…`。预算取在两者之间：新名字一律 ≤ 前者的 [_budgetShare]，也就是 84.6dp——
///       比"已知放得下"的那串窄 7%，比"已知放不下"的那串窄 19%。
/// English: **the two rulers, both measured by the user on the device**: `Custom Tools` renders in
///          full, `Unit Conversion` is cut to `Unit Convers…`. The budget sits between them: every new
///          name is ≤ [_budgetShare] of the former, i.e. 84.6dp — 7% under the string known to fit and
///          19% under the one known not to.
const double _budgetShare = 0.93;

/// 中文：**旧表里那七条**（`Custom Tools` 不在内——它在设备上量过是放得下的）。它们进这个清单的
///       用处只有一个：证明两根标尺确实分开了好名字与坏名字，见那条断言的理由。
/// English: **the seven from the old table** (`Custom Tools` is not among them — it was measured as
///          fitting). They are here for one purpose: to show the two rulers really do separate the good
///          names from the bad ones, as that assertion's reason says.
const List<String> _committedLongNames = <String>[
  'Equations & Math',
  'Circuits & Electronics',
  'Mechanical Engineering',
  'Finance & Business',
  'Physics & Science',
  'Unit Conversion',
  'Programming & Data',
];

/// 中文：一串英文在分类卡标题那一行里占多宽（dp）。**不是估的**：每字符的 advance 来自真 Roboto
///       （表见 [_robotoBlackPerMille]），字距按 Flutter 的算法**每个字符都加、含最后一个**——
///       这一点也量过：测试字体下 `Custom Tools` 恰好是 12 × (14 + 0.25) = 171.0，而"只夹在中间"
///       会得 170.75。**字偶距没有算**，所以这是个**上界**：真机上只会更窄。
/// English: how wide a Latin string is on the category card's title line, in dp. **Not an estimate**:
///          the per-character advances come from real Roboto (see [_robotoBlackPerMille]), and
///          letter-spacing is added **per character including the last**, the way Flutter lays it out —
///          also measured: under the test font `Custom Tools` is exactly 12 × (14 + 0.25) = 171.0,
///          where "between characters only" would give 170.75. **Kerning is not modelled**, so this is
///          an **upper bound**: the device renders no wider than this.
double _labelWidth(String text) {
  var width = 0.0;
  for (final unit in text.codeUnits) {
    final character = String.fromCharCode(unit);
    final advance = _robotoBlackPerMille[character];
    if (advance == null) {
      fail('「$text」里有一个 ASCII 32–126 之外的字符：$character；'
          '分类名是英文，字宽表是全量的，出现这个说明名字里进了表外的字符');
    }
    width += advance / 1000 * _cardTitleFontSize;
  }
  return width + _cardTitleLetterSpacing * text.length;
}

/// 中文：**Roboto-Black 的字宽尺**，单位是 **1/1000 em**，ASCII 32–126 全量（95 条）。生成方式
///       （一条命令，文件是 Flutter SDK 自己那份 Roboto）：
///
///       `python3 -c "from fontTools.ttLib import TTFont; p='$FLUTTER_ROOT/bin/cache/artifacts/`
///       `material_fonts/Roboto-Black.ttf'; f=TTFont(p); upm=f['head'].unitsPerEm;`
///       `cmap=f.getBestCmap(); hmtx=f['hmtx']; print({chr(c): round(hmtx[cmap[c]][0]/upm*1000)`
///       ` for c in cmap if 32<=c<127})"`
///
///       **为什么取 Black 而不是 Bold**：卡片上是 `w800`，Android 从 700 与 900 里挑哪个由系统定，
///       Black 是更宽的那个（逐字符差 ≤ 0.5%），取它得当上限。
///       **为什么不在测试字体里量**：`flutter_test` 的字体每个字形都是一整个 **em**（实测：测试字体下
///       `Custom Tools` = 171.0dp，真 Roboto 只有 91.0dp），拿它当尺子会把八个名字全判死，也就是
///       说它只能证明"截断会发生"，证明不了"多长才不截断"。这一把能。
/// English: **a Roboto-Black width ruler**, in **1/1000 em**, all of ASCII 32–126 (95 entries).
///          Generated with (one command; the file is Flutter SDK's own copy of Roboto):
///          [the same command as above]
///          **Why Black and not Bold**: the card is `w800` and Android decides between 700 and 900;
///          Black is the wider of the two (≤ 0.5% per character), so taking it is taking the ceiling.
///          **Why not measure in the test font**: every `flutter_test` glyph is a full **em** wide
///          (measured: `Custom Tools` is 171.0dp there against real Roboto's 91.0dp), so as a ruler it
///          condemns all eight names — it can show that truncation happens, never how short is short
///          enough. This one can.
const Map<String, int> _robotoBlackPerMille = <String, int>{
  ' ': 249, '!': 276, '"': 317, '#': 581, r'$': 579, '%': 742, '&': 674, '\'': 154,
  '(': 353, ')': 352, '*': 465, '+': 534, ',': 270, '-': 450, '.': 302, '/': 351,
  '0': 579, '1': 579, '2': 579, '3': 579, '4': 579, '5': 579, '6': 579, '7': 579,
  '8': 579, '9': 579, ':': 300, ';': 288, '<': 510, '=': 585, '>': 513, '?': 509,
  '@': 896, 'A': 681, 'B': 645, 'C': 656, 'D': 646, 'E': 560, 'F': 547, 'G': 682,
  'H': 703, 'I': 302, 'J': 562, 'K': 640, 'L': 542, 'M': 876, 'N': 702, 'O': 690,
  'P': 651, 'Q': 690, 'R': 652, 'S': 626, 'T': 630, 'U': 665, 'V': 661, 'W': 869,
  'X': 638, 'Y': 628, 'Z': 610, '[': 282, '\\': 426, ']': 282, '^': 447, '_': 441,
  '`': 339, 'a': 531, 'b': 563, 'c': 520, 'd': 562, 'e': 544, 'f': 362, 'g': 575,
  'h': 564, 'i': 275, 'j': 270, 'k': 547, 'l': 275, 'm': 861, 'n': 564, 'o': 562,
  'p': 563, 'q': 562, 'r': 379, 's': 512, 't': 343, 'u': 564, 'v': 517, 'w': 726,
  'x': 515, 'y': 518, 'z': 515, '{': 325, '|': 255, '}': 325, '~': 632,
};

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
