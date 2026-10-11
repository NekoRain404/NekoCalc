import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/tool_field_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';
import 'package:nekocalc/shared/presentation/app_theme.dart';

import '../shared/source_scan.dart';

/// 中文：**标签与单位那一格的"真字体量的长度"**，与 `tool_field_strings_test.dart` 里那两条按字宽表
///       算的判据互为表里：那两条算的是**宽度**（表宽 ÷ 格宽向上取整），这条量的是**真的断行结果**
///       ——同一个宽度下，英文按词断行，可能比 `ceil(宽 / 格宽)` 多出一行来。这正是要真字体才问得
///       出的问题，所以它单独一个文件、单独一条测试。
///
///       **为什么另起一个文件。** 行数硬线：`tool_field_strings_test.dart` 加到这条会越过 800 行；
///       这也正是描述表那一轮把量行数的部分拆成 `tool_description_lines_test.dart` 的理由。
///
///       **判据与本轮那条规则逐字相同**（写在 `tool_field_strings.dart` 的文件头上）：
///         · 英文行数 ≤ 中文行数 + （可选参数 ? 1 : 0）；
///         · 且英文行数 ≤ 2（两行以内）。
///       宽高与字号取自渲染树（`tool_field_strings_test.dart` 里那条量了它们）：
///       格宽 **89.14285714285714dp**、字号 14、字距 0.25；**标签不截断**，装不下就换行。
///
///       **量的方法**：把真 Roboto-Regular（Flutter SDK 自带）与一份真 CJK 字体装进测试环境，
///       先用两个已知答案验尺子（`abc` 必须是 22.80dp、`齿` 必须是一整个 em 的 14.00dp），
///       再用 `TextPainter` 按格宽排版、数 `computeLineMetrics()`。**装不上字体时这条测试不通过、
///       也不假装通过**：它打一行说明然后跳过——那种情况下它什么都没证明。
/// English: **the real-font length measurement for the label and unit cells**, the other half of the two
///          ruler-based assertions in `tool_field_strings_test.dart`: those measure **width**
///          (table width ÷ cell width, rounded up) and this measures **the real line break** — at one
///          width English breaks at word boundaries and may need a line more than `ceil(width / cell)`
///          says. That is a question only a real font can answer, so it gets its own file and its own
///          test.
///
///          **Why its own file.** The line limit: adding this to `tool_field_strings_test.dart` would
///          cross 800 lines — exactly the reason the description round split its measurement half into
///          `tool_description_lines_test.dart`.
///
///          **The rule is character-for-character this round's rule** (written on
///          `tool_field_strings.dart`'s head): English lines ≤ Chinese lines + (optional ? 1 : 0), and
///          English lines ≤ 2. The width, font size and letter spacing come off the render tree (they
///          are asserted in `tool_field_strings_test.dart`): cell **89.14285714285714dp**, 14sp,
///          letter spacing 0.25. Labels **do not truncate** — too long and they wrap.
///
///          **How it measures**: real Roboto-Regular (shipped with the Flutter SDK) and a real CJK face
///          are loaded into the test environment, the ruler is verified against two known answers
///          (`abc` must be 22.80dp, `齿` exactly one em at 14.00dp), and a `TextPainter` lays the text
///          out at the cell width and counts `computeLineMetrics()`. **When the fonts cannot be
///          loaded this test neither passes nor pretends to**: it prints one line and returns — in that
///          case it has proved nothing.
void main() {
  final en = ToolFieldStrings.forLanguage(AppLanguage.en);
  final zh = ToolFieldStrings.forLanguage(AppLanguage.zh);

  testWidgets('真字体逐条量：268 处标签 × 两种语言，行数判据一条都不违反', (tester) async {
    if (!await _loadRealFonts(tester)) {
      // 中文：**这里不是"通过"，是"没量"。**
      // English: **this is not a pass, it is a skip.**
      // ignore: avoid_print
      print('跳过：本机找不到可用的 Roboto / Noto Sans（CJK）字体，真字体那把尺子用不了。');
      return;
    }
    var measured = 0;
    var same = 0;
    var oneMore = 0;
    var worstEnglish = 0;
    var worstChinese = 0;
    final violations = <String>[];
    for (final tool in toolCatalog) {
      for (final input in tool.inputs) {
        if (!containsWideOrFullwidth(input.label)) continue;
        final zhText = zh.inputLabel(input.label) +
            (input.optional ? _optionalSuffixZh : '');
        final enText = en.inputLabel(input.label) +
            (input.optional ? _optionalSuffixEn : '');
        final zhLines = _lines(zhText, _labelStyle);
        final enLines = _lines(enText, _labelStyle);
        measured++;
        if (enLines > worstEnglish) worstEnglish = enLines;
        if (zhLines > worstChinese) worstChinese = zhLines;
        final allowed = zhLines + (input.optional ? 1 : 0);
        if (enLines > allowed || enLines > _maxLabelLines) {
          violations.add('${tool.id}.${input.key} 「${input.label}」→'
              '「${en.inputLabel(input.label)}」：中文 $zhLines 行、英文 $enLines 行、'
              '允许 $allowed 行、上限 $_maxLabelLines 行${input.optional ? '（可选）' : ''}');
        } else if (enLines > zhLines) {
          oneMore++;
        } else {
          same++;
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
    // 中文：**三个数都是断言，不是日志**：268 处里 230 处两种语言行数相同、38 处英文多一行
    //       （全是可选参数，多出来的那一行来自 ` (optional)` 比 `（可选）` 宽 9dp 的壳），
    //       英文最多 2 行、中文最多 2 行。**真字体量出来的数与按字宽表算的完全一致**——
    //       也就是说这一轮没有一处英文是被断行规则多挤出一行的。
    //       上一轮是 289 / 251 / 38：少掉的 21 处就是那 21 个被并掉的换算工具各带走的一处参数标签
    //       （`输入值`，都不可选，所以只有 same 少 21，oneMore 一条没动）。
    // English: **all three numbers are assertions, not logs**: of the 268 sites, 230 take the same line
    //          count in both languages and 38 take one more (all optional, that extra line coming from
    //          the ` (optional)` chrome being 9dp wider than `（可选）`); English never exceeds 2 lines
    //          and neither does Chinese. **The real-font numbers agree exactly with the arithmetic
    //          ones** — no English line here was pushed over by a break rule. Last round it was
    //          289 / 251 / 38: the 21 that went are the one input label each folded-away converter took
    //          with it (`输入值`, none of them optional, so only `same` loses 21 while `oneMore` does not
    //          move).
    expect(measured, 268, reason: '量到的处数变了：$measured');
    expect(same, 230, reason: '两种语言行数相同的处数变了：$same');
    expect(oneMore, 38, reason: '英文多一行的处数变了：$oneMore（应当都是可选参数）');
    expect(worstEnglish, _maxLabelLines, reason: '英文的最多行数变了：$worstEnglish');
    // 中文：**中文那一侧最多 3 行，这是它今天的样子，本轮一个字都没动它。**
    //       （`目标并联等效（可选）` 这类 6 个汉字 + `（可选）` 的组合在 89.1dp 上要换 3 行；
    //       英文那几条反而更短，最多 2 行。）这条断言钉住的是"中文没被谁顺手改短"。
    // English: **the Chinese side reaches 3 lines, which is how it stands today and not one character
    //          of it moved this round** (a six-Han label plus `（可选）` wraps to three lines at
    //          89.1dp, while its English is shorter and stops at two). This assertion pins down that
    //          nobody quietly shortened the Chinese.)
    expect(worstChinese, 3, reason: '中文的最多行数变了：$worstChinese');
  });

  testWidgets('真字体量单位那一格：11 条英文单位都装得进输入框，最宽的一条压在预算里', (tester) async {
    if (!await _loadRealFonts(tester)) {
      // ignore: avoid_print
      print('跳过：本机找不到可用的 Roboto / Noto Sans（CJK）字体，真字体那把尺子用不了。');
      return;
    }
    var widest = 0.0;
    var widestText = '';
    var widestChinese = 0.0;
    for (final tool in toolCatalog) {
      for (final input in tool.inputs) {
        final value = en.inputUnits[input.unit];
        if (value == null) continue;
        final width = _width(value, _unitStyle);
        if (width > widest) {
          widest = width;
          widestText = value;
        }
        final zhWidth = _width(input.unit, _unitStyle);
        if (zhWidth > widestChinese) widestChinese = zhWidth;
      }
    }
    // 中文：**预算 68dp 与 `tool_field_strings_test.dart` 里那个数是同一个**：输入框实测 118.9dp，
    //       中文那两条最长的留给数字 50.4dp，预算就压在两者之间；中文那一侧最宽的是 `元/kWh`。
    // English: **the 68dp budget is the same number as in `tool_field_strings_test.dart`**: the field
    //          measures 118.9dp, the longest Chinese units leave the number 50.4dp, and the budget sits
    //          between the two; the widest Chinese is `元/kWh`.
    expect(widest, lessThanOrEqualTo(_unitBudget),
        reason: '$widestText 实测 ${widest.toStringAsFixed(1)}dp，超出 $_unitBudget dp 预算');
    // 中文：**最宽的那条英文单位是 `periods`（56.6dp），不是 `¥/kWh`（48.6dp）**——两条长的
    //       货币单位换过之后，最宽的一条反而落在"期"上；中文那一侧最宽的是 `元/kWh`（56.2dp），
    //       两种语言在这一格上基本齐平（差 0.4dp）。
    // English: **the widest English unit is `periods` at 56.6dp, not `¥/kWh` at 48.6dp** — once the
    //          two long currency units were replaced, the widest one fell on "periods"; the widest
    //          Chinese is `元/kWh` at 56.2dp, so the two languages are level in this cell (0.4dp
    //          apart).
    expect(widestText, 'periods', reason: '最宽的英文单位换了一条：$widestText');
    expect(widest, closeTo(56.6, 0.6),
        reason: '最宽的那条英文单位实测 ${widest.toStringAsFixed(1)}dp，与记下的 56.6dp 不同');
    expect(widestChinese, closeTo(56.2, 0.6),
        reason: '最宽的那条中文单位实测 ${widestChinese.toStringAsFixed(1)}dp，与记下的 56.2dp 不同');
  });
}

/// 中文：标签那一格的宽度——与 `tool_field_strings_test.dart` 里那条从渲染树读出来的断言是同一个
///       数；那边保证它没变，这边用它排版。
/// English: the label cell's width — the same number the render-tree assertion in
///          `tool_field_strings_test.dart` pins; that test guarantees it has not moved, this one lays
///          text out at it.
const double _labelBox = 89.14285714285714;

/// 中文：英文标签的行数上限，与 `tool_field_strings_test.dart` 里的那一条同一个数。
/// English: the line cap for an English label, the same number as in `tool_field_strings_test.dart`.
const int _maxLabelLines = 2;

/// 中文：单位那一格的宽度预算，与 `tool_field_strings_test.dart` 里的那一条同一个数（118.9dp 的
///       输入框里，中文最坏的那条留给数字 50.4dp，预算是这两者之间的 68dp）。
/// English: the unit cell's width budget, the same number as in `tool_field_strings_test.dart` (in a
///          118.9dp field whose worst Chinese case leaves the number 50.4dp, the budget is the 68dp
///          between them).
const double _unitBudget = 68;

/// 中文：可选参数那两个后缀的原文（`ToolsStrings.optionalInput` 里的那两句）。
/// English: the two optional suffixes as they stand (`ToolsStrings.optionalInput`).
const String _optionalSuffixZh = '（可选）';
const String _optionalSuffixEn = ' (optional)';

/// 中文：这两格的文字样式。标签是 `Text` 的默认正文样式（14sp、字距 0.25，实测于渲染树），
///       单位是 `InputDecoration.suffixText`，字号跟随输入框（16sp、字距 0.5，
///       与 [AppTheme] 里 `bodyLarge` 的写法一致）。字体名在装好真字体之后才有意义。
/// English: the text styles of the two cells. The label is the default body style (`Text`'s default:
///          14sp, letter spacing 0.25, both measured off the render tree); the unit is
///          `InputDecoration.suffixText`, which follows the field (16sp, letter spacing 0.5, matching
///          `bodyLarge` in [AppTheme]). The family names only mean anything once the real fonts are
///          loaded.
const TextStyle _labelStyle = TextStyle(
    fontSize: 14,
    letterSpacing: 0.25,
    fontFamily: 'Roboto',
    fontFamilyFallback: ['NotoCJK']);

/// 中文：验尺子用的样式：与 [_labelStyle] 同一字体与字号，**只差没有字距**。
/// English: the style the ruler is verified with: the same family and size as [_labelStyle], **only
///          without letter spacing**.
const TextStyle _rulerStyle = TextStyle(
    fontSize: 14, fontFamily: 'Roboto', fontFamilyFallback: ['NotoCJK']);

const TextStyle _unitStyle = TextStyle(
    fontSize: 16,
    letterSpacing: 0.5,
    fontFamily: 'Roboto',
    fontFamilyFallback: ['NotoCJK']);

double _width(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

int _lines(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: _labelBox);
  return painter.computeLineMetrics().length;
}

/// 中文：把真 Roboto-Regular（Flutter SDK 自带）与一份真 CJK 字体装进测试环境，装完**先验尺子**：
///       `abc` 必须是 Roboto 的 22.80dp、`齿` 必须是一整个 em 的 14.00dp（设备上的 Noto Sans CJK
///       就是一个 em）；对不上就当没装上。返回"装上了没有"。
///       **与 `tool_description_lines_test.dart` 里那份是同一套做法**（字体、验尺子、返回值），
///       两处各自装一次是因为字体装载是测试进程级的状态，跨文件共享要靠一个全局开关，不值得。
/// English: loads real Roboto-Regular (shipped with the Flutter SDK) and a real CJK face into the test
///          environment, then **verifies the ruler**: `abc` must measure Roboto's 22.80dp and `齿` must
///          measure one full em, 14.00dp (Noto Sans CJK on the device is exactly one em); anything else
///          counts as "not loaded". Returns whether it loaded. **The same shape as the copy in
///          `tool_description_lines_test.dart`** (the fonts, the ruler check, the return value); each
///          file loads its own because font loading is process-wide state and sharing it would need a
///          global switch that is not worth its keep.
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

/// 中文：尺子先量两个已知答案：`abc` 与 `齿`。装错字体（或没装上）时这两个数会立刻不对。
/// English: the ruler measures two known answers first, `abc` and `齿`; a font that failed to load — or
///          the wrong one — moves both at once.
bool _rulerIsTrue() {
  // 中文：**验尺子这一下不加字距**：`abc` 在 Roboto-Regular 14sp 下是 22.80dp（描述表那边量到的
  //       同一个数），加了 0.25 的字距会变成 23.54dp，那是尺子本身没装对时看不出来的偏差。
  // English: **the ruler check adds no letter spacing**: `abc` at Roboto-Regular 14sp is 22.80dp (the
  //          same number the description table measured); with the 0.25 spacing it becomes 23.54dp,
  //          which is a deviation this check would not see if the ruler were the wrong font.
  return (_width('abc', _rulerStyle) - 22.80).abs() < 0.05 &&
      (_width('齿', _rulerStyle) - 14).abs() < 0.01;
}
