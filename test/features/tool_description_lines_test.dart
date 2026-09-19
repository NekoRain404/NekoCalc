import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/tool_catalog_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_widgets.dart';
import 'package:nekocalc/l10n/app_language.dart';
import 'package:nekocalc/shared/presentation/app_theme.dart';

import '../shared/roboto_regular_advances.dart';

// 中文：文件头那段说明（缺陷、修法、三把尺子、代价）写在 `tool_widgets.dart` 的
//       `toolDescriptionMaxLines` 与 `ToolListTile` 上，这里只留量测本身。
// English: the narrative (the defect, the fix, the three rulers, the cost) lives on
//          `toolDescriptionMaxLines` and `ToolListTile` in `tool_widgets.dart`; this file is only the
//          measurement.
void main() {
  // 中文：三个盒子宽度（360dp 手机上量出来的）。第 1 条测试断言渲染出来的就是这三个数——布局一动，
  //       这里先红，下面按盒子算的判据才不会悄悄量错东西。
  // English: the three box widths, measured on a 360dp phone. The first test asserts the rendered boxes
  //          are these numbers, so a layout change goes red here before any ruler can go quietly wrong.
  const homeBox = 162.0;
  const categoryBox = 170.0;
  const narrowBox = 140.0;

  testWidgets('三种表面：说明那一格的行数上限都是同一个数，盒子宽度与记下的相同，且一处都不溢出',
      (tester) async {
    for (final language in AppLanguage.values) {
      for (final surface in _Surface.values) {
        for (final withHint in const [false, true]) {
          final rows = await _pumpAll(tester, language, surface, withHint);
          expect(rows, isNotEmpty,
              reason: '${surface.name} 上一格说明都没渲染出来，这条断言会空转');
          final boxes = rows.map((row) => row.box).toSet();
          expect(boxes.length, 1,
              reason: '同一屏上出现了两种盒子宽度 $boxes——按一个盒子算的判据就不成立了');
          expect(boxes.single, closeTo(surface.box, 0.01),
              reason: '${surface.name} 那一格实测 ${boxes.single}dp，与记下的 ${surface.box}dp 不同'
                  '——布局动过，行数上限得按新宽度重量');
          for (final row in rows) {
            expect(row.maxLines, toolDescriptionMaxLines,
                reason: '${surface.name}/${language.name} 下说明那一格用的是 ${row.maxLines} 行，'
                    '不是 $toolDescriptionMaxLines 行');
          }
        }
      }
    }
    expect(tester.takeException(), isNull, reason: '三种表面上都不该有溢出');
  });

  test('真 Roboto 字宽：117 条在三个盒子里都不超过行数上限（一条都不许落下）', () {
    for (final box in const [homeBox, categoryBox, narrowBox]) {
      for (final language in AppLanguage.values) {
        final catalog = ToolCatalogStrings.forLanguage(language);
        expect(catalog.toolDescriptions.length, toolCatalog.length,
            reason: '${language.name} 的描述表条数与目录不同，下面会空转');
        var widest = 0.0;
        for (final tool in toolCatalog) {
          final width = advanceWidth(
              catalog.toolDescription(tool.id), _fontSize, _letterSpacing);
          if (width > widest) widest = width;
        }
        // 中文：**这条断言的意思就是"没有一条需要第 N+1 行"**：最宽的那条 ≤ 上限 × 盒子。
        //       它跟着描述一起动——中文哪一条变长、或上限被调小，这里立刻红。
        // English: **what this asserts is "not one entry needs line N+1"**: the widest entry is no wider
        //          than cap × box. It moves with the copy — lengthen a Chinese entry or lower the cap
        //          and this goes red at once.
        expect(widest, lessThanOrEqualTo(box * toolDescriptionMaxLines),
            reason: '盒子 ${box}dp / ${language.name}：最宽的一条 ${widest.toStringAsFixed(1)}dp，'
                '比 $toolDescriptionMaxLines 行（${(box * toolDescriptionMaxLines).toStringAsFixed(1)}dp）'
                '还宽——换行上限不够，或者有两个盒子宽度记错了');
      }
    }
  });

  testWidgets('真字体下逐条量：117 条说明 × 两种语言 × 三种表面 × 两种状态，全部读得全',
      (tester) async {
    if (!await _loadRealFonts(tester)) {
      // 中文：**这里不是"通过"，是"没量"**——本机没有可用的系统字体时，这条测试什么都不证明。
      // English: **this is not a pass, it is a skip** — with no usable system font, nothing is measured.
      // ignore: avoid_print
      print('跳过：本机找不到可用的 Roboto / Noto Sans（CJK）字体，真字体那把尺子用不了。');
      return;
    }

    var measured = 0;
    for (final language in AppLanguage.values) {
      for (final surface in _Surface.values) {
        for (final withHint in const [false, true]) {
          final rows = await _pumpAll(tester, language, surface, withHint);
          for (final row in rows) {
            expect(row.exceeded, isFalse,
                reason: '${surface.name}/${language.name}'
                    '${withHint ? '/检索态' : '/浏览态'}：这一条在 '
                    '${row.box.toStringAsFixed(0)}dp 上被省略号截了——「${row.data}」');
            measured++;
          }
        }
      }
    }
    // 中文：**这个数是断言，不是日志**：三种表面 × 两种语言 × 两种状态 × 117 条。
    // English: **this number is an assertion, not a log line**: three surfaces × two languages × two
    //          states × 117 entries.
    expect(
        measured,
        toolCatalog.length * _Surface.values.length * AppLanguage.values.length * 2,
        reason: '量到的条数与"逐条量完"不一致，多半有哪一屏没渲染出来');
  });
}

/// 中文：说明那一格出现的三种表面——`box` 是它的实测宽度，其余两个数是上面那层卡片/面板的壳。
/// English: the three surfaces the description cell appears in — `box` is its measured width, and the
///          other two numbers are the card/panel chrome above it.
enum _Surface {
  /// 中文：工具首页的搜索卡片（页面左右 16 + 卡片 4）。
  /// English: the tools home's search card (page padding 16, card margin 4).
  home(162.0, 16, EdgeInsets.all(4)),

  /// 中文：分类页上按分组的那张卡片（只留 14dp 下边距）。
  /// English: the category page's per-group card (a 14dp bottom margin only).
  category(170.0, 16, EdgeInsets.only(bottom: 14)),

  /// 中文："其它分类"那张面板：`ToolSearchEmptyState` 的 `Container(padding: 14)` 里那一列，
  ///       卡片宽 298dp——**全应用最窄的一处**，行数上限就是从它取的。
  /// English: the "other categories" panel: the column inside `ToolSearchEmptyState`'s
  ///          `Container(padding: 14)`, a 298dp card — **the narrowest surface in the app**, and where
  ///          the line cap comes from.
  narrow(140.0, 31, EdgeInsets.zero);

  const _Surface(this.box, this.padding, this.margin);

  final double box;
  final double padding;
  final EdgeInsets margin;
}

/// 中文：一条渲染出来的说明，连同它的段落读数。
/// English: one rendered description, with its paragraph readings.
class _Row {
  const _Row(this.data, this.maxLines, this.box, this.exceeded);

  final String data;
  final int maxLines;
  final double box;
  final bool exceeded;
}

/// 中文：把 117 张卡按某一处表面的壳渲染出来（真字体装好时也走这条路），返回每一格说明的读数。
///       说明那一格用 `maxLines == toolDescriptionMaxLines` 认——提示那一行也是 `Text`，
///       所以另外按前缀（`命中：` / `Matched: `）剔掉。
/// English: renders all 117 cards inside one surface's chrome (this is also the path the real fonts go
///          through) and returns a reading per description cell. A description cell is recognised by
///          `maxLines == toolDescriptionMaxLines`; the hint line is a `Text` too, so it is filtered out
///          by its prefix (`命中：` / `Matched: `).
Future<List<_Row>> _pumpAll(WidgetTester tester, AppLanguage language,
    _Surface surface, bool withHint) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme: _theme(),
    home: Scaffold(
      body: AppLanguageScope(
        language: language,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(surface.padding, 16, surface.padding, 20),
          child: Card(
            margin: surface.margin,
            child: Column(
              children: [
                for (final ToolDefinition tool in toolCatalog)
                  ToolListTile(
                    tool: tool,
                    favorite: false,
                    matchLabel: withHint ? _hintProbe : null,
                    onTap: () {},
                    onFavoriteToggle: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  final rows = <_Row>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final data = widget.data;
    if (data == null || widget.maxLines != toolDescriptionMaxLines) continue;
    if (_isHint(data)) continue;
    final paragraph = element.renderObject! as RenderParagraph;
    rows.add(_Row(data, widget.maxLines!, paragraph.constraints.maxWidth,
        paragraph.didExceedMaxLines));
  }
  return rows;
}

bool _isHint(String data) =>
    data.startsWith('命中：') || data.startsWith('Matched: ');

/// 中文：检索态用的那条提示——固定值，不随查询变，量的是"卡片在检索态下的行数上限"。
/// English: the hint used in the search state — a fixed string, so what gets measured is the card's line
///          cap in the search state rather than one particular query.
const String _hintProbe = '命中：工具 ID · gear ratio';

/// 中文：尺子的两个刻度：副标题那一行的字号与字距，与命中提示那条护栏用的是同一把尺子。
/// English: the ruler's two graduations: the subtitle line's font size and letter spacing, the same
///          ruler the match-hint guard rail uses.
const double _fontSize = 14;
const double _letterSpacing = 0.25;

/// 中文：把真字体装进测试环境后的主题：**只有字体这一项与 `AppTheme` 不同**，所以量到的字号、字距、
///       内边距与设备一致。
/// English: the theme with the real fonts loaded: **the fonts are the only thing that differs from
///          `AppTheme`**, so the font size, letter spacing and padding measured are the device's.
ThemeData _theme() {
  final base = AppTheme.light();
  return base.copyWith(
    textTheme: base.textTheme
        .apply(fontFamily: 'Roboto', fontFamilyFallback: const ['NotoCJK']),
  );
}

/// 中文：把真 Roboto-Regular（Flutter SDK 自带）与一份真 CJK 字体装进测试环境，装完**先验尺子**：
///       `abc` 必须是 Roboto 的 22.80dp、`齿` 必须是一整个 em 的 14.00dp（设备上的 Noto Sans CJK
///       就是一个 em）；对不上就当没装上。返回"装上了没有"。
/// English: loads real Roboto-Regular (shipped with the Flutter SDK) and a real CJK face into the test
///          environment, then **verifies the ruler**: `abc` must measure Roboto's 22.80dp and `齿` must
///          measure one full em, 14.00dp (Noto Sans CJK on the device is exactly one em); anything else
///          counts as "not loaded". Returns whether it loaded.
Future<bool> _loadRealFonts(WidgetTester tester) async {
  final roboto = '${Platform.environment['FLUTTER_ROOT']}'
      '/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
  if (!File(roboto).existsSync()) return false;

  String? cjk;
  for (final candidate in const [
    // 中文：本机（fontconfig）上那份 Noto Sans SC；任何 1em 宽的 CJK 字体都行。
    // English: the Noto Sans SC on this machine (fontconfig); any 1em-wide CJK face will do.
    '/usr/share/fonts/Win_fonts/NotoSansSC-VF.ttf',
    '/usr/share/fonts/opentype/noto/NotoSansSC-Regular.otf',
    '/usr/share/fonts/truetype/noto/NotoSansSC-Regular.otf',
  ]) {
    if (File(candidate).existsSync()) {
      cjk = candidate;
      break;
    }
  }
  if (cjk == null) return false;

  final cjkPath = cjk;
  await tester.runAsync(() => _load('Roboto', roboto));
  try {
    await tester.runAsync(() => _load('NotoCJK', cjkPath));
  } on Exception {
    return false;
  }
  return _rulerIsTrue();
}

Future<void> _load(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(File(path)
        .readAsBytes()
        .then((bytes) => ByteData.view(bytes.buffer)));
  await loader.load();
}

/// 中文：尺子先量两个已知答案：`abc` 与 `齿`。装错字体（或没装上）时这两个数会立刻不对。
/// English: the ruler measures two known answers first, `abc` and `齿`; a font that failed to load — or
///          the wrong one — moves both at once.
bool _rulerIsTrue() {
  const style = TextStyle(
      fontSize: _fontSize,
      fontFamily: 'Roboto',
      fontFamilyFallback: ['NotoCJK']);
  double width(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  return (width('abc') - 22.80).abs() < 0.05 &&
      (width('齿') - _fontSize).abs() < 0.01;
}
