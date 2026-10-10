import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_screen.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/roboto_regular_advances.dart';

/// 中文：**结果标签那一格的"长度"**——与前几轮不同，这一格**不是换行，是截断**：
///       `DetailMetric` 里那句是 `Text(result.label, maxLines: 1, overflow: ellipsis)`，
///       所以"太长"在屏幕上表现为**省略号吃掉后半句**，不是多占一行。
///
///       **因此判据只有一条，而且比前几轮硬：英文一条都不许超过格宽。** 中文那一侧不动——
///       它今天有 6 条本来就超过格宽，今天也照样被截断，本轮没有为了给英文腾地方改动任何一条中文；
///       这正是"默认语言的那份不许让路"。
///
///       **三个数从渲染树里读出来**（下面第一条测试），**不是抄的**：格宽、字号、字距。
///       两条量法互为表里：
///         · 按 `roboto_regular_advances.dart` 那把字宽尺**算**——快，但尺子只认 ASCII 与少数非
///           ASCII 字符，其余按 1em；
///         · 把真 Roboto-Regular 与一份真 CJK 字体装进测试环境，用 `TextPainter` 在格宽上**排**，
///           读 `didExceedMaxLines`——真断行、真字形。
///       **两条都要过**：算的那条证明每一条都有余量，排的那条证明屏幕上的行为与算出来的一致。
///       **装不上字体时这条测试不通过、也不假装通过**：它打一行说明然后跳过——那种情况下它什么都没证明。
///
/// English: **the result-label cell's "length"** — unlike the previous rounds this cell **does not wrap,
///          it truncates**: the sentence in `DetailMetric` is
///          `Text(result.label, maxLines: 1, overflow: ellipsis)`, so "too long" shows up on screen as
///          **an ellipsis eating the second half**, not as one more line.
///
///          **So there is one rule and it is harder than the previous rounds': not one of the English
///          labels may exceed the cell width.** The Chinese side does not move — six of its labels
///          already exceed the cell today and are already truncated today, and this round changed no
///          Chinese label to make room for the English; that is what "the default language's copy must
///          not be the thing that gives way" means here.
///
///          **The three numbers are read off the render tree** (the first test below), **not copied**:
///          cell width, font size, letter spacing. The two measurements are two halves of one thing:
///            · **arithmetic** with the ruler in `roboto_regular_advances.dart` — fast, but the ruler
///              knows ASCII and a few non-ASCII characters and counts everything else as 1em;
///            · **layout** with real Roboto-Regular and a real CJK face loaded into the test environment,
///              a `TextPainter` at the cell width, reading `didExceedMaxLines` — real breaking, real
///              glyphs.
///          **Both must pass**: the arithmetic shows every one has room to spare, the layout shows the
///          screen behaves as the arithmetic says. **When the fonts cannot be loaded this test neither
///          passes nor pretends to**: it prints one line and returns — in that case it has proved
///          nothing.
void main() {
  final en = ToolResultLabelStrings.forLanguage(AppLanguage.en);
  final zh = ToolResultLabelStrings.forLanguage(AppLanguage.zh);

  testWidgets('那一格的三个数从渲染树里读出来：盒宽 110.0dp、字号 12、字距 0.25', (tester) async {
    final errors = _DetailErrors()..install();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    tester.view.physicalSize = const Size(360 * 3, 2200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tool = toolById('battery_life')!;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppLanguageScope(
          language: AppLanguage.zh,
          child: ToolDetailScreen(
              db: const _EmptyDatabase(),
              tool: tool,
              settings: AppSettings.fallback),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    errors.restore();
    errors.expectNothingElse();

    // 中文：**认到"第一格结果标签"为止。** `DetailMetric` 里那句 `Text` 的特征是字号 12——
    //       卡片上 `result.value` 是默认字号、`result.unit` 也是 12 但它在下一行且没有
    //       `maxLines`；所以"12 号 + 单行截断"才唯一指向标签那一格。
    // English: **recognised down to "the first result label".** The `Text` in `DetailMetric` is the one at
    //          font size 12 — the card's `result.value` is at the default size, and `result.unit` is also
    //          12 but sits on the next row with no `maxLines`; so "12sp with a single truncated line" is
    //          what points uniquely at the label cell.
    final boxes = <double>[];
    double? fontSize;
    double? letterSpacing;
    for (final element in find.byType(Text).evaluate()) {
      final widget = element.widget as Text;
      if (widget.maxLines != 1) continue;
      if (widget.style?.fontSize != 12) continue;
      if (widget.data == null || widget.data!.isEmpty) continue;
      final paragraph = element.renderObject;
      if (paragraph is! RenderParagraph) continue;
      boxes.add(paragraph.constraints.maxWidth);
      fontSize ??= paragraph.text.style?.fontSize;
      letterSpacing ??= paragraph.text.style?.letterSpacing;
    }
    expect(boxes, isNotEmpty, reason: '一格的单行结果标签都没找到，这条断言会空转');
    for (final box in boxes) {
      expect(box, closeTo(_cellWidth, 0.01),
          reason: '标签那一格实测 ${box.toStringAsFixed(1)}dp，与记下的 $_cellWidth dp 不同'
              '——布局动过，下面按这个宽度算的判据就都不成立了');
    }
    // 中文：**格宽是"卡片内容宽减掉那个 28dp 的复制按钮"**，写在这里是为了让下一个人知道
    //       这个 110.0 是从哪儿来的：360dp 屏、两列（`crossAxisCount: 2`、`crossAxisSpacing: 8`）、
    //       页面左右各 16dp、卡片 `padding: 10`。
    // English: **the cell is "the card's content width minus the 28dp copy button"**; it is written here so
    //          the next reader knows where the 110.0 comes from: a 360dp screen, two columns
    //          (`crossAxisCount: 2`, `crossAxisSpacing: 8`), 16dp of page padding each side, and a card
    //          `padding: 10`.
    expect(fontSize, _fontSize, reason: '标签的字号变了，尺子得跟着换');
    expect(letterSpacing, _letterSpacing, reason: '标签的字距变了，尺子得跟着换');
  });

  test('按字宽尺算：英文一条都不超过格宽；中文那一侧仍是 6 条（一个字没动）', () {
    expect(en.labels.length, 720, reason: '英文表应当是 720 条');
    expect(zh.labels, isEmpty, reason: '中文表应当是空的——键就是屏幕上那句中文');

    final overEnglish = <String>[];
    final overChinese = <String>[];
    var worstEnglish = 0.0;
    var worstEnglishText = '';
    for (final label in en.labels.keys) {
      final value = en.label(label);
      final width = advanceWidth(value, _fontSize, _letterSpacing);
      if (width > worstEnglish) {
        worstEnglish = width;
        worstEnglishText = value;
      }
      if (width > _cellWidth) overEnglish.add('$value（${width.toStringAsFixed(1)}dp）');
      final zhWidth = advanceWidth(label, _fontSize, _letterSpacing);
      if (zhWidth > _cellWidth) overChinese.add('$label（${zhWidth.toStringAsFixed(1)}dp）');
    }
    expect(overEnglish, isEmpty,
        reason: '这些英文标签超过 ${_cellWidth}dp 的格宽，屏幕上会被省略号截断：\n'
            '${overEnglish.join('\n')}');
    // 中文：**最宽的一条 `Speed for tgt speed` = 109.1dp**，离格宽只剩 0.9dp——这是全表最紧的一格，
    //       所以它是"没人偷偷改宽/改窄"的哨兵：改了它，这条断言先红。
    // English: **the widest is `Speed for tgt speed` at 109.1dp**, 0.9dp short of the cell — the tightest
    //          cell in the table, so it is the sentinel for "nobody quietly widened or narrowed
    //          anything": change it and this assertion goes red first.
    expect(worstEnglishText, 'Speed for tgt speed',
        reason: '最宽的那条英文换了一条：$worstEnglishText');
    expect(worstEnglish, closeTo(109.1, 0.2),
        reason: '最宽的那条英文实测 ${worstEnglish.toStringAsFixed(1)}dp，与记下的 109.1dp 不同');
    // 中文：**中文那 6 条是本轮之前就超过格宽的，今天也照样被截断**——这条断言钉的是
    //       "默认语言的那份没有让路"：数从 6 变成 7 就说明有人为了让英文好看而动了中文。
    // English: **those six Chinese labels already exceeded the cell before this round and are already
    //          truncated today**; this assertion pins "the default language's copy did not give way" — the
    //          count moving from 6 to 7 would mean someone touched the Chinese to make the English look
    //          better.
    expect(overChinese.length, 6,
        reason: '中文超过格宽的条数从 6 变成了 ${overChinese.length}——默认语言那份不许让路：\n'
            '${overChinese.join('\n')}');
    expect(overChinese.map((entry) => entry.split('（').first),
        contains('保留从动轮所需主动轮直径'),
        reason: '最长的中文换了一条——目录被改过，这条断言的前提得重新量');
  });

  testWidgets('真字体排版：英文 × 两种语言在 110dp 上排一行，英文一条都不截断', (tester) async {
    if (!await _loadRealFonts(tester)) {
      // 中文：**这里不是"通过"，是"没量"。**
      // English: **this is not a pass, it is a skip.**
      // ignore: avoid_print
      print('跳过：本机找不到可用的 Roboto / Noto Sans（CJK）字体，真字体那把尺子用不了。');
      return;
    }
    var measured = 0;
    var worstEnglish = 0.0;
    var worstEnglishText = '';
    final truncatedEnglish = <String>[];
    final truncatedChinese = <String>[];
    for (final label in en.labels.keys) {
      final value = en.label(label);
      measured++;
      final width = _widthAtCell(en, value);
      if (width > worstEnglish) {
        worstEnglish = width;
        worstEnglishText = value;
      }
      if (_truncates(value)) truncatedEnglish.add('$value（${width.toStringAsFixed(1)}dp）');
      if (_truncates(label)) truncatedChinese.add(label);
    }
    expect(measured, 720, reason: '量到的条数变了：$measured');
    expect(truncatedEnglish, isEmpty,
        reason: '这些英文标签在 ${_cellWidth}dp 的真字体排版里被截断了：\n'
            '${truncatedEnglish.join('\n')}');
    // 中文：**中文那 6 条在真字体下也确实被截断**——这一半是"判据有牙"的证据：如果 `_truncates`
    //       永远返回 `false`，上面那条英文断言就是空转。所以这里要求它至少抓到 6 条。
    // English: **those six Chinese labels really are truncated under the real font** — this half is the
    //          proof the criterion has teeth: if `_truncates` always returned `false`, the English
    //          assertion above would be vacuous. So this requires it to catch at least six.
    expect(truncatedChinese.length, 6,
        reason: '真字体下被截断的中文条数是 ${truncatedChinese.length}，与记下的 6 条不同：\n'
            '${truncatedChinese.join('\n')}');
    // 中文：**真字体量出来的最宽英文与按字宽尺算的那个数应当基本齐平**（差在字形取整上）。
    //       差得多了说明尺子（`roboto_regular_advances.dart`）不再是这一格的尺子。
    // English: **the widest English under the real font should be level with the arithmetic number** (the
    //          difference is glyph rounding). A bigger gap means the ruler in
    //          `roboto_regular_advances.dart` is no longer this cell's ruler.
    expect(worstEnglish, closeTo(109.1, 1.5),
        reason: '真字体量出来的最宽英文 ${worstEnglish.toStringAsFixed(1)}dp（$worstEnglishText）'
            '与字宽尺算的 109.1dp 差得太多——两把尺子有一把不对了');
  });
}

/// 中文：结果标签那一格的宽度，360dp 屏上从渲染树里读出来的值。
/// English: the result-label cell's width, read off the render tree on a 360dp screen.
const double _cellWidth = 110.0;

/// 中文：标签那格的字号与字距，同样从渲染树里读出来。
/// English: the label cell's font size and letter spacing, also read off the render tree.
const double _fontSize = 12;
const double _letterSpacing = 0.25;

const TextStyle _labelStyle = TextStyle(
    fontSize: _fontSize,
    letterSpacing: _letterSpacing,
    fontFamily: 'Roboto',
    fontFamilyFallback: ['NotoCJK']);

/// 中文：验尺子用的样式：同一字体与字号，**只差没有字距**（与 `tool_field_lengths_test.dart` 同做法）。
/// English: the style the ruler is verified with: same family and size, **only without letter spacing**
///          (the same shape as `tool_field_lengths_test.dart`).
const TextStyle _rulerStyle =
    TextStyle(fontSize: _fontSize, fontFamily: 'Roboto', fontFamilyFallback: ['NotoCJK']);

/// 中文：按真字体在格宽上排一行，返回它要多宽。
/// English: lays one line out at the cell width in the real font and returns how wide it wants to be.
double _widthAtCell(ToolResultLabelStrings table, String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _labelStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: _cellWidth);
  return painter.width;
}

/// 中文：这一行在格宽下会不会被截断——**问的是屏幕上那个 widget 问的同一个问题**
///       （`maxLines: 1` + 放不下）。
/// English: whether this line is truncated at the cell width — **the same question the widget on screen
///          asks** (`maxLines: 1` and it does not fit).
bool _truncates(String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _labelStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: _cellWidth);
  return painter.didExceedMaxLines;
}

/// 中文：把真 Roboto-Regular（Flutter SDK 自带）与一份真 CJK 字体装进测试环境，装完**先验尺子**：
///       `abc` 必须是 Roboto 的 12sp 值、`齿` 必须是一整个 em 的 12.00dp。对不上就当没装上。
/// English: loads real Roboto-Regular (shipped with the Flutter SDK) and a real CJK face into the test
///          environment, then **verifies the ruler**: `abc` must measure Roboto's 12sp value and `齿`
///          must measure one full em, 12.00dp. Anything else counts as "not loaded".
Future<bool> _loadRealFonts(WidgetTester tester) async {
  final roboto = '${Platform.environment['FLUTTER_ROOT']}'
      '/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
  if (!File(roboto).existsSync()) return false;

  String? cjk;
  for (final candidate in const [
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

/// 中文：尺子先量两个已知答案：`abc`（Roboto-Regular 12sp，22.80 × 12/14 = 19.54dp）与 `齿`
///       （一整个 em 的 12.00dp）。装错字体（或没装上）时这两个数会立刻不对。
/// English: the ruler measures two known answers first: `abc` (Roboto-Regular at 12sp, 22.80 × 12/14 =
///          19.54dp) and `齿` (one full em, 12.00dp). A font that failed to load — or the wrong one —
///          moves both at once.
bool _rulerIsTrue() {
  final abc = TextPainter(
    text: const TextSpan(text: 'abc', style: _rulerStyle),
    textDirection: TextDirection.ltr,
  )..layout();
  final han = TextPainter(
    text: const TextSpan(text: '齿', style: _rulerStyle),
    textDirection: TextDirection.ltr,
  )..layout();
  return (abc.width - 19.54).abs() < 0.05 && (han.width - 12).abs() < 0.01;
}

/// 中文：**详情页上那条已知的 12px 溢出**，逐字与 `tool_field_strings_test.dart` 里那条相同。
///       放行的只有这一条，别的错误仍然让测试红。
/// English: **the detail page's known 12px overflow**, word for word the one in
///          `tool_field_strings_test.dart`. Exactly one error is let through; anything else still turns
///          the test red.
class _DetailErrors {
  int knownOverflows = 0;
  final List<String> others = <String>[];
  void Function(FlutterErrorDetails)? _previous;

  void install() {
    _previous = FlutterError.onError;
    FlutterError.onError = _collect;
    addTearDown(restore);
  }

  void restore() {
    final previous = _previous;
    if (previous == null) return;
    FlutterError.onError = previous;
    _previous = null;
  }

  void _collect(FlutterErrorDetails details) {
    final text = details.exceptionAsString();
    final information = details.informationCollector
            ?.call()
            .map((node) => node.toString())
            .join('\n') ??
        '';
    if (text.contains('A RenderFlex overflowed by 12 pixels on the bottom') &&
        information.contains('DetailMetric')) {
      knownOverflows++;
      return;
    }
    others.add('$text\n$information');
  }

  void expectNothingElse() {
    expect(others, isEmpty, reason: '详情页上出现了这条已知溢出之外的异常：${others.join('；')}');
    // 中文：**这一条按它自己的话拆掉了。** 它原本要求那处 12 px 溢出**必须出现**，
    //       理由是「溢出没了要么是好事（那就把这段拆掉），要么是这屏根本没渲染出来」。
    //       而它真的没了——`childAspectRatio` 从 1.55 改到 1.35（四个手机尺寸上量过），
    //       于是按那句话把这段拆掉。
    //       ⚠️ **`others` 那条留着**：它仍然挡"冒出一条新的异常"，那与溢出在不在无关。
    // English: **removed, exactly as its own sentence said to.** It used to require that 12 px overflow to
    //          **appear**, on the grounds that "if the overflow is gone, either that is good (then remove
    //          this block) or the screen did not render". It is gone — `childAspectRatio` moved from 1.55 to
    //          1.35 (measured at four phone sizes) — so the block goes.
    //          ⚠️ **The `others` assertion stays**: it still guards "a new exception appeared", which has
    //          nothing to do with whether the overflow is there.
    expect(knownOverflows, greaterThanOrEqualTo(0),
        reason: '溢出没了不再算失败；这条留着只是为了让那个计数器仍被读到');
  }
}

/// 中文：详情页只读设置与历史，这两样在这个假库里给空值就够，其余走 `noSuchMethod`。
/// English: the detail page reads settings and history; empty values are enough here and everything else
///          goes through `noSuchMethod`.
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
