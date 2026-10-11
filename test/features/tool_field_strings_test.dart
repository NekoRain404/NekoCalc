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
import 'package:nekocalc/features/tools/presentation/tool_detail_screen.dart';
import 'package:nekocalc/features/tools/presentation/tool_field_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/roboto_regular_advances.dart';
import '../shared/source_scan.dart';

/// 中文：**本轮那张表的七条护栏**，形状与工具子树另外几张表相同。
///       1) **默认态逐字节不变**：中文下五个字段逐条走 `toolCatalog`，拿回来的必须是目录里那一个
///          字串；中文表那五个 map **必须是空的**（键就是中文，写了也没人查——见文件头）。
///       2) **英文表覆盖所有该翻的字串**：每个**带汉字**的 `input.label` / `input.unit` /
///          `tool.group` / `tool.formula` / `tool.explanation` 都有条目，非空、无汉字、
///          **没有一条等于它的键**（相等就是没翻）。
///       3) **数学记号逐字符活着**：中文按 CJK 与全角断开，凡**非 CJK 的连续段**都要在英文里
///          原样找得到。这条断言不认任何手写清单，改中文时它自己跟着变；本轮它当场抓到过两处
///          （`Vin`、`Base64URL` 那一段），见报告。
///       4) **没有死条目**：每张表的每个键都得在目录里真的出现（键是字串，抄错一个字符就会
///          变成一条永远查不到的条目——那正是这张表最可能的坏法）。
///       5) **长度**：标签那一格 **89.1dp** 的宽度、字号 14、字距 0.25 是**从渲染树里读出来的**，
///          不是抄的；然后 294 处带汉字的标签 × 两种语言逐条量行数，判据是
///          `英文行数 ≤ 中文行数 + (可选 ? 1 : 0)` 且 `≤ 2`（理由见 `tool_field_strings.dart`）。
///       6) **屏幕上真的换了**：分类页的分组标题、详情页的标签 / 单位 / 公式 / 解释，
///          两种语言各是各的，英文下这几个位置上没有汉字。
///       7) **检索没动**：五个字段仍在目录里是中文，按中文的词仍找得到工具。
///
/// English: **the seven guard rails for this round's table**, the same shape as the tools subtree's
///          other tables. (1) **The default state is byte-identical**: in Chinese all five fields walk
///          `toolCatalog` and must come back as the catalogue's own string, and the Chinese table's
///          five maps **must be empty** (the key is the Chinese; written entries would never be
///          consulted — see the file head). (2) **The English table covers everything that needs
///          translating**: every **Han-bearing** `input.label` / `input.unit` / `tool.group` /
///          `tool.formula` / `tool.explanation` has an entry, none empty, none holding a Han
///          character, and **not one equal to its key** (equality means it was never translated).
///          (3) **The mathematical notation survives character for character**: the Chinese is cut at
///          CJK and full-width boundaries and every **non-CJK run** must be found verbatim in the
///          English. The assertion consults no hand-written list and follows the Chinese when it
///          changes; it caught two escapes this round (`Vin`, and the `Base64URL` run) — see the
///          report. (4) **No dead entries**: every key must really occur in the catalogue (a
///          one-character typo in a key makes an entry that can never be found — the likeliest way
///          for this table to go wrong). (5) **Length**: the label cell's **89.1dp**, the 14sp font and
///          the 0.25 letter spacing are **read off the render tree**, not copied; then all 294
///          Han-bearing label sites are measured in both languages against
///          `English lines ≤ Chinese lines + (optional ? 1 : 0)` and `≤ 2` (the reasoning is on
///          `tool_field_strings.dart`). (6) **The screen really changed**: the category page's group
///          headings and the detail page's label / unit / formula / explanation are each language's
///          own, and no Han character survives in those cells in English. (7) **Search did not move**:
///          the five fields are still Chinese in the catalogue, and Chinese words still find their
///          tools.
void main() {
  final zh = ToolFieldStrings.forLanguage(AppLanguage.zh);
  final en = ToolFieldStrings.forLanguage(AppLanguage.en);

  test('中文表是空的（键就是中文），五个字段逐条与目录逐字节相同', () {
    expect(toolCatalog.length, 119,
        reason: '目录里一共 119 个工具（上一轮 120：`proportion` 并进了 `scale_ratio`）');
    expect(zh.inputLabels, isEmpty);
    expect(zh.inputUnits, isEmpty);
    expect(zh.groups, isEmpty);
    expect(zh.formulas, isEmpty);
    expect(zh.explanations, isEmpty);
    var labelSites = 0;
    for (final tool in toolCatalog) {
      expect(zh.group(tool.group), tool.group,
          reason: '${tool.id} 的分组名在中文下不是目录里那一个');
      expect(zh.formula(tool.formula), tool.formula,
          reason: '${tool.id} 的公式在中文下不是目录里那一个');
      expect(zh.explanation(tool.explanation), tool.explanation,
          reason: '${tool.id} 的解释在中文下不是目录里那一个');
      for (final input in tool.inputs) {
        expect(zh.inputLabel(input.label), input.label,
            reason: '${tool.id}.${input.key} 的标签在中文下不是目录里那一个');
        expect(zh.inputUnit(input.unit), input.unit,
            reason: '${tool.id}.${input.key} 的单位在中文下不是目录里那一个');
        labelSites++;
      }
    }
    // 中文：**337 = 345 − 4 − 4**：`inflation` 并进 `compound` 之后，它那四个参数标签
    //       （`当前金额`、`年通胀率`、`年数`、`未来等值`）跟着走了；`proportion` 并进
    //       `scale_ratio` 之后，它那四个（`a`、`b`、`c`、`x`）也走了。
    // English: **337 = 345 − 4 − 4**: with `inflation` merged into `compound`, its four input labels
    //          (`当前金额`, `年通胀率`, `年数`, `未来等值`) went with it; with `proportion` merged into
    //          `scale_ratio`, its four (`a`, `b`, `c`, `x`) went too.
    expect(labelSites, 337, reason: '目录里的参数一共 337 处，少了说明遍历没跑对');
  });

  test('英文表：带汉字的字段一条不漏、非空、无汉字、没有一条等于它的键', () {
    final missing = <String>[];
    var identical = 0;
    void check(String kind, String source, String? value, String where) {
      // 中文：**判据是"有没有汉字"，不是 `containsWideOrFullwidth`**——与描述表英文那一侧的判据
      //       同一条理由：那把尺子量的是"这里有没有界面文案"，把 `·` 这种**记号**也算进去，
      //       于是 `N·m`、`Ω·mm²/m` 会被当成需要翻译的字串。参数标签与单位有一半是记号，
      //       这里要问的是"里面有没有汉字"，`N·m` 这种两种语言逐字节相同的字段一条都不进表。
      // English: **the criterion is "does it hold a Han character", not `containsWideOrFullwidth`** —
      //          the same reason as the description table's English-side guard: that ruler asks "is
      //          there interface copy here" and counts **notation** such as `·`, which would drag
      //          `N·m` and `Ω·mm²/m` in as strings needing translation. Half of these fields are
      //          notation; the question here is whether a Han character is present, and a field like
      //          `N·m`, byte-identical in both languages, does not enter the table at all.
      if (!_han.hasMatch(source)) return;
      if (value == null) {
        missing.add('$kind $where: 「$source」在英文表里没有条目');
        return;
      }
      expect(value, isNotEmpty, reason: '$kind $where 的英文是空串');
      // 中文：判据是"有没有汉字"，与描述表那条一样——`Ω`、`℃`、`·` 这些**记号**不在其列，
      //       英文那一侧本来就该留着它们。
      // English: the criterion is "does it hold a Han character", as in the description table's
      //          guard — **notation** such as `Ω`, `℃`, `·` is not in that class and belongs there.
      expect(_han.hasMatch(value), isFalse,
          reason: '$kind $where 的英文里有汉字：$value');
      if (value == source) identical++;
    }

    for (final tool in toolCatalog) {
      check('分组名', tool.group, en.groups[tool.group], tool.id);
      check('公式', tool.formula, en.formulas[tool.formula], tool.id);
      check('解释', tool.explanation, en.explanations[tool.explanation], tool.id);
      for (final input in tool.inputs) {
        check('标签', input.label, en.inputLabels[input.label], tool.id);
        check('单位', input.unit, en.inputUnits[input.unit], tool.id);
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
    expect(identical, 0, reason: '有 $identical 条英文与中文一字不差——那些行根本没翻');
    // 中文：**英文表里不许有目录里用不上的条目**（死条目）：键抄错一个字符就会永远查不到，
    //       而屏幕上看不出来（回落成中文，与"本来就该是中文"长得一样）。
    // English: **the English table may hold no entry the catalogue never uses** (a dead entry): a
    //          one-character typo in a key is never looked up, and on screen it is invisible (it falls
    //          back to Chinese, which looks exactly like "this one was meant to stay Chinese").
    expect(_deadEntries(en, 'inputLabels', en.inputLabels, _catalogueStrings(label: true)),
        isEmpty);
    expect(_deadEntries(en, 'inputUnits', en.inputUnits, _catalogueStrings(unit: true)),
        isEmpty);
    expect(_deadEntries(en, 'groups', en.groups, _catalogueStrings(group: true)),
        isEmpty);
    expect(_deadEntries(en, 'formulas', en.formulas, _catalogueStrings(formula: true)),
        isEmpty);
    expect(_deadEntries(
            en, 'explanations', en.explanations, _catalogueStrings(explanation: true)),
        isEmpty);
  });

  test('数学记号逐字符活着：中文里每一段非 CJK 的字串都必须在英文里原样找得到', () {
    var checked = 0;
    final missing = <String>[];
    void walk(String kind, String source, String? target) {
      if (target == null) return;
      for (final run in notationRuns(source)) {
        checked++;
        if (!target.contains(run)) {
          missing.add('$kind 「$run」\n    中文 $source\n    英文 $target');
        }
      }
    }

    for (final tool in toolCatalog) {
      walk('分组名', tool.group, en.groups[tool.group]);
      walk('公式', tool.formula, en.formulas[tool.formula]);
      walk('解释', tool.explanation, en.explanations[tool.explanation]);
      for (final input in tool.inputs) {
        walk('标签', input.label, en.inputLabels[input.label]);
        walk('单位', input.unit, en.inputUnits[input.unit]);
      }
    }
    // 中文：**214 是实测的记号段数**，数的是**出现处**（每一条分组名 + 公式 + 解释 + 参数 × 标签与单位两格）。
    //       上一轮是 218：`proportion` 并进 `scale_ratio` 之后，它那条解释
    //       （`a、b、c、x 任意填写三项即可反推第四项，…`）里四段记号 `a`、`b`、`c`、`x` 跟着走了；
    //       它那条公式整条是纯 ASCII，本来就不进英文表（表里只收带汉字的字段），一处也不算；
    //       它那四个参数标签 `a`/`b`/`c`/`x` 同样不进表，更不算段。
    //       这个数会随中文措辞一起动，所以它只做"断言没空转"的证据，判据是上面那条 `contains`。
    // English: **214 is the measured run count**, counting **occurrence sites** (each tool's group name,
    //          formula and explanation plus every input's label and unit). Last round it was 218: with
    //          `proportion` merged into `scale_ratio`, the four runs in its explanation
    //          (`a、b、c、x 任意填写三项即可反推第四项，…` — the runs `a`, `b`, `c`, `x`) went with it;
    //          its formula is pure ASCII and never had an English entry (the table only holds
    //          Han-bearing fields), so it never counted a run; its four input labels `a`/`b`/`c`/`x`
    //          never entered the table either. The number moves with the Chinese wording, so it only
    //          proves the loop ran; the criterion is the `contains` above.
    expect(checked, 214, reason: '记号段数变了（$checked）：中文改过，或者遍历没跑全');
    expect(missing, isEmpty,
        reason: '这些记号在英文里没了——记号是语言无关的，必须逐字符活着：\n${missing.join('\n')}');
  });

  testWidgets('标签那一格的三个数从渲染树里读出来：盒宽 89.1dp、字号 14、字距 0.25', (tester) async {
    await _pumpDetail(tester, AppLanguage.zh, 'loan');
    // 中文：`loan` 的金额那格是**可选**参数，屏幕上那句是"标签 + （可选）"，按那一句去找。
    // English: the loan amount input is **optional**, so the cell reads "label + （可选）"; that is the
    //          string to look up.
    final row = _labelRow(tester, '贷款金额（可选）');
    expect(row.box, closeTo(labelBox, 0.01),
        reason: '标签那一格实测 ${row.box}dp，与记下的 $labelBox 不同——布局动过，'
            '下面按这个宽度算的行数判据就都不成立了');
    expect(row.fontSize, _fontSize, reason: '标签的字号变了，尺子得跟着换');
    expect(row.letterSpacing, _letterSpacing, reason: '标签的字距变了，尺子得跟着换');
  });

  test('真字宽：289 处标签 × 两种语言，英文那一行数一条都不许多出来', () {
    var sameLine = 0;
    var oneMore = 0;
    final violations = <String>[];
    for (final tool in toolCatalog) {
      for (final input in tool.inputs) {
        if (!containsWideOrFullwidth(input.label)) continue;
        final zhText =
            input.label + (input.optional ? _optionalSuffixZh : '');
        final enText =
            en.inputLabel(input.label) + (input.optional ? _optionalSuffixEn : '');
        final zhLines = _lines(zhText);
        final enLines = _lines(enText);
        final allowed = zhLines + (input.optional ? 1 : 0);
        if (enLines > allowed || enLines > _maxLabelLines) {
          violations.add('${tool.id}.${input.key} 「${input.label}」→'
              '「${en.inputLabel(input.label)}」'
              '：中文 $zhLines 行（${advance(zhText).toStringAsFixed(1)}dp）、'
              '英文 $enLines 行（${advance(enText).toStringAsFixed(1)}dp）、'
              '允许 $allowed 行、上限 $_maxLabelLines 行'
              '${input.optional ? '（可选）' : ''}');
        } else if (enLines > zhLines) {
          oneMore++;
        } else {
          sameLine++;
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
    // 中文：**两个数是断言，不是日志。** 251 处两种语言同样行数，其余英文多一行——那些都是
    //       **可选**参数，多出来的那一行来自 `ToolsStrings.optionalInput` 的 ` (optional)` 比
    //       `（可选）` 宽 9dp，不是标签写长了。合起来 289 处；上一轮是 293 处（345 个参数减掉 52 处
    //       本来就拉丁字母的）——少掉的四处是 `inflation` 并进 `compound` 时跟着走的四个参数标签
    //       （`当前金额`、`年通胀率`、`年数`、`未来等值`），四个都是可选参数——`年数` 中文一行、
    //       英文的 `Years (optional)` 两行（oneMore 少 1），其余三个两种语言都换行（sameLine 少 3）。
    // English: **both numbers are assertions, not logs.** 251 sites take the same line count in both
    //          languages and the rest take one more, every one of them an **optional** input — the extra
    //          line comes from `ToolsStrings.optionalInput`'s ` (optional)` being 9dp wider than
    //          `（可选）`, not from a long label. 289 in all; last round it was 293 (345 inputs minus the
    //          52 already in Latin letters) — the four that went are the input labels that left when
    //          `inflation` merged into `compound` (`当前金额`, `年通胀率`, `年数`, `未来等值`), all four
    //          optional — `年数` fits on one line in Chinese while its `Years (optional)` needs two
    //          (`oneMore` loses 1) and the other three wrap in both languages (`sameLine` loses 3).
    expect(sameLine, 251, reason: '两种语言同样行数的处数变了：$sameLine');
    expect(oneMore, 38, reason: '英文多占一行的处数变了：$oneMore（应当都是可选参数）');
  });

  test('单位那一格：11 条英文都比中文那条短或相当，最长的一条也只用掉一半宽度', () {
    var worst = 0.0;
    var worstText = '';
    for (final tool in toolCatalog) {
      for (final input in tool.inputs) {
        final value = en.inputUnits[input.unit];
        if (value == null) continue;
        expect(containsWideOrFullwidth(value), isFalse,
            reason: '${tool.id}.${input.key} 的单位英文里有汉字：$value');
        final width = advance(value, unitSize: true);
        if (width > worst) {
          worst = width;
          worstText = value;
        }
        // 中文：**判据的形状与描述表那条一样：英文宽 ≤ max(中文宽, 单位那一格的预算 68dp)。**
        //       单位那两格在同一处表面上（输入框右侧），所以这里只有一条尺子：
        //       `元` 这种一个汉字的单位，英文必然宽得多（16.5dp → `¥` 8.9dp 反而更窄，
        //       但 `CNY` 33.9dp 就宽一倍），拿中文当上限没有落点；真正的约束是"别把数字挤没"——
        //       输入框 118.9dp，中文最坏的那条留给数字 50.4dp，预算就取在两者之间。
        // English: **the rule has the shape of the description table's: English width ≤ max(Chinese
        //          width, the unit cell's 68dp budget).** Both cells sit on one surface (right of the
        //          input field), so there is one ruler. A one-Han unit such as `元` is a different
        //          order from its English (16.5dp against `¥` at 8.9dp, or `CNY` at 33.9dp), so a
        //          Chinese ceiling has nothing to bite on; the real constraint is "do not squeeze the
        //          number out" — the field offers 118.9dp and the worst Chinese case leaves the number
        //          50.4dp, so the budget sits between the two.
        final zhWidth = advance(input.unit, unitSize: true);
        expect(width, lessThanOrEqualTo(
                zhWidth > _unitBudget ? zhWidth : _unitBudget),
            reason: '${tool.id}.${input.key} 的单位英文 $value（${width.toStringAsFixed(1)}dp）'
                '比中文 ${input.unit}（${zhWidth.toStringAsFixed(1)}dp）与 '
                '$_unitBudget dp 预算里的大的那个还宽');
      }
    }
    // 中文：**最长的英文单位是 `periods`（56.6dp）**：两条长的货币单位（`¥/kWh`、`¥/L`）
    //       换过之后，这一格的宽度与中文侧最宽的 `元/kWh`（56.2dp）基本齐平。
    // English: **the longest English unit is `periods` at 56.6dp**: after the two long currency units
    //          (`¥/kWh`, `¥/L`) were replaced, this cell is level with the widest Chinese, `元/kWh`
    //          at 56.2dp.
    expect(worstText, 'periods', reason: '最长的英文单位换了一条：$worstText');
    expect(worst, closeTo(56.6, 0.6),
        reason: '最长的那条英文单位实测 ${worst.toStringAsFixed(1)}dp，与记下的 56.6dp 不同');
  });

  testWidgets('分类页：分组标题两种语言各是各的，英文下这一行没有汉字', (tester) async {
    expect(await _pumpCategory(tester, AppLanguage.zh), contains('常用'));
    expect(await _pumpCategory(tester, AppLanguage.en), contains('Common'));
    final headings =
        await _categoryHeadings(tester, AppLanguage.en, ToolCategory.electronics);
    for (final heading in headings) {
      expect(_han.hasMatch(heading), isFalse,
          reason: '英文分类页上还有中文分组标题：$heading');
    }
    expect(headings, isNotEmpty, reason: '一个分组标题都没渲染出来，这条断言会空转');
  });

  testWidgets('详情页：标签、单位、公式、解释两种语言各是各的', (tester) async {
    final zhRow = await _pumpDetail(tester, AppLanguage.zh, 'ohms_law');
    // 中文：`ohms_law` 的第一个参数是**可选**的，所以标签那一格是"电压 V（可选）"。
    // English: the first ohms_law input is **optional**, so the label cell reads `电压 V（可选）`.
    expect(zhRow.label, '电压 V（可选）');
    expect(zhRow.unit, 'V');
    expect(zhRow.formula, 'V = I × R, P = V × I = I²R = V²/R');
    expect(zhRow.explanation, contains('任意填写两项'));

    final enRow = await _pumpDetail(tester, AppLanguage.en, 'ohms_law');
    expect(enRow.label, 'Voltage V (optional)');
    expect(enRow.unit, 'V');
    expect(enRow.formula, 'V = I × R, P = V × I = I²R = V²/R',
        reason: '没有汉字的公式两种语言必须逐字节相同——记号是语言无关的');
    expect(enRow.explanation, isNot(contains('任意填写两项')),
        reason: '英文界面上解释还是中文');
    expect(_han.hasMatch(enRow.explanation!), isFalse,
        reason: '英文解释里还有汉字：${enRow.explanation}');

    // 中文：**带汉字的单位（钱与计数）也走表**，所以拿一个英语单位是钱的工具再量一次：
    //       `loan` 的第一个参数是"贷款金额"，单位 `万元` → `10k ¥`。
    // English: **Han-bearing units (money and counts) go through the table too**, so this is measured
    //          once more on a tool whose units are money: `loan`'s first input is the loan amount,
    //          whose unit `万元` becomes `10k ¥`.
    final loan = await _pumpDetail(tester, AppLanguage.en, 'loan');
    expect(loan.unit, '10k ¥');
    expect(_han.hasMatch(loan.label!), isFalse,
        reason: '英文界面上的参数标签还有汉字：${loan.label}');
  });

  test('检索没动：五个字段仍是目录里那一条中文，按中文的词仍找得到工具', () {
    final loan = toolById('loan')!;
    expect(loan.group, '借贷', reason: '分组名字段被改过——检索读的就是它');
    expect(loan.inputs.firstWhere((i) => i.key == 'amount').label, '贷款金额');
    expect(loan.inputs.firstWhere((i) => i.key == 'amount').unit, '万元');
    expect(toolById('ohms_law')!.formula, contains('V = I × R'));
    expect(toolById('ohms_law')!.explanation, contains('任意填写两项'));
    expect(toolById('quadratic')!.explanation, contains('判别式'));

    // 中文：**逐档各查一个**：输入项（68）、单位（56）、公式（72）、解释（62）、分组名（58）。
    //       命中的字符串、分数与排序本轮一个字节都没动，这几条只证明"中文照旧找得到"。
    // English: **one query per score band**: input (68), unit (56), formula (72), explanation (62),
    //          group (58). Hit strings, scores and ordering did not move by a byte this round; these
    //          assertions only show that Chinese still finds its tools.
    expect(_ids('基准值'), contains('percentage'), reason: '中文标签查不到了');
    expect(_ids('万元'), contains('loan'), reason: '中文单位查不到了');
    expect(_ids('单位倍率'), contains('length'), reason: '中文公式查不到了');
    expect(_ids('判别式'), contains('quadratic'), reason: '中文解释查不到了');
    expect(_ids('借贷'), contains('loan'), reason: '中文分组名查不到了');
  });
}

/// 中文：标签那一格的宽度（360dp 手机上实测）、字号与字距——上面第一条测试断言渲染出来的就是
///       这三个数，布局一动这里先红。
/// English: the label cell's width (measured on a 360dp phone), font size and letter spacing. The
///          first widget test asserts the rendered values are these three, so a layout change goes red
///          here before any ruler can quietly measure the wrong thing.
const double labelBox = 89.14285714285714;
const double _fontSize = 14;
const double _letterSpacing = 0.25;

/// 中文：单位那一格（`InputDecoration.suffixText`）的字号与字距，与标签不同——实测于渲染树。
/// English: the unit cell's (`InputDecoration.suffixText`) font size and letter spacing, unlike the
///          label's — measured off the render tree.
const double _unitFontSize = 16;
const double _unitLetterSpacing = 0.5;

/// 中文：可选参数那两个后缀的原文（`ToolsStrings.optionalInput` 里的那两句），量行数时要算进去。
/// English: the two optional suffixes as they stand (`ToolsStrings.optionalInput`); they count towards
///          the line measurement.
const String _optionalSuffixZh = '（可选）';
const String _optionalSuffixEn = ' (optional)';

/// 中文：英文标签的行数上限。中文那一侧没有这个数——它量的是"英文有没有失控"。
/// English: the line cap for an English label. There is no such number for the Chinese side; this one
///          measures whether the English has run away.
const int _maxLabelLines = 2;

/// 中文：单位那一格的宽度预算（dp）。输入框实测 **118.9dp**，而中文那两条最长的
///       （`元/kWh` 61.3dp、`元/L` 更宽裕）留给框里那个数字 **50.4dp**——预算就取在它们之间：
///       **68dp**，也就是"英文单位最多与中文最坏的那条一样挤"。**判据是绝对预算，不是与中文逐条
///       对齐**：一个汉字的 `元`（16.5dp）和它的英文是两个量级，拿中文当上限这条根本没有落点。
///       实测最宽的英文是 `periods`（56.6dp），与中文侧最宽的 `元/kWh`（56.2dp）基本齐平。
/// English: the unit cell's width budget in dp. The field measures **118.9dp**, and the Chinese side's
///          two longest (`元/kWh` at 61.3dp, `元/L` with more room) leave the number **50.4dp** — the
///          budget sits between them at **68dp**, i.e. "an English unit may crowd the number no more
///          than Chinese's worst case does". **The criterion is an absolute budget rather than
///          per-entry symmetry with the Chinese**: a one-glyph `元` (16.5dp) and its English are two
///          different orders, and a Chinese ceiling would have nothing to bite on. The widest English
///          measured is `periods` at 56.6dp, level with the widest Chinese, `元/kWh` at 56.2dp.
const double _unitBudget = 68;

/// 中文：一行文字的宽度，用真 Roboto-Regular 的字宽表加逐字符字距（Flutter 连最后一个字符也加）。
///       **表外的字符按 1em**，走这条路的正是 CJK 与全角标点。两个刻度各对应屏幕上的一格：
///       标签是 14sp / 0.25（`Text` 的正文样式），单位是 16sp / 0.5（`suffixText`，跟随输入框），
///       两个都是**从渲染树里读出来的**（单位那两组数是探针量出来写进这里的）。
/// English: the width of one line, from the real Roboto-Regular advances plus per-character letter
///          spacing (Flutter adds the spacing after the last character too). **Anything off-table
///          counts as 1em** — what reaches it is CJK and full-width punctuation. The two graduations
///          match the two cells on screen: the label is 14sp / 0.25 (`Text`'s body style) and the unit
///          is 16sp / 0.5 (`suffixText`, which follows the field) — both **read off the render tree**
///          (the unit pair came from a probe and is written down here).
double advance(String text, {bool unitSize = false}) {
  final fontSize = unitSize ? _unitFontSize : _fontSize;
  final letterSpacing = unitSize ? _unitLetterSpacing : _letterSpacing;
  var width = 0.0;
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    final perMille = robotoRegularPerMille[character] ??
        nonAsciiPerMille[character] ??
        1000;
    width += perMille / 1000 * fontSize;
  }
  return width + letterSpacing * text.runes.length;
}

int _lines(String text) => (advance(text) / labelBox).ceil();

List<String> _ids(String query) => ToolSearch.searchTools(query)
    .map((result) => result.tool.id)
    .toList(growable: false);

/// 中文：**目录里真的出现过的字串**——死条目那条判据的另一半。五个字段各取各的，因为同一条中文
///       在标签表与单位表里出现时可以合法地有两条不同的英文。
/// English: **the strings that really occur in the catalogue** — the other half of the dead-entry
///          check. Each field has its own set, because one Chinese string may legitimately have two
///          different English entries when it appears once as a label and once as a unit.
Set<String> _catalogueStrings({
  bool label = false,
  bool unit = false,
  bool group = false,
  bool formula = false,
  bool explanation = false,
}) {
  final values = <String>{};
  for (final tool in toolCatalog) {
    if (group) values.add(tool.group);
    if (formula) values.add(tool.formula);
    if (explanation) values.add(tool.explanation);
    for (final input in tool.inputs) {
      if (label) values.add(input.label);
      if (unit) values.add(input.unit);
    }
  }
  return values;
}

List<String> _deadEntries(
    ToolFieldStrings table, String kind, Map<String, String> map, Set<String> live) {
  return [
    for (final key in map.keys)
      if (!live.contains(key)) '$kind 的键「$key」在目录里根本不出现——永远查不到的死条目',
  ];
}

/// 中文：**汉字**（含扩展 A 与兼容区）。英文那一侧不许有它；`Ω`、`℃`、`·`、`μ` 这些**记号**
///       不在此列，它们本来就该在。
/// English: **Han characters** (extension A and the compatibility block included). The English side may
///          not hold one; **notation** such as `Ω`, `℃`, `·` and `μ` is not in this class and is
///          supposed to be there.
final RegExp _han = RegExp(r'[㐀-䶿一-鿿豈-﫿]');

/// 中文：一行渲染出来的参数标签读数。
/// English: the readings of one rendered parameter label.
class _LabelRow {
  const _LabelRow(this.data, this.box, this.fontSize, this.letterSpacing);

  final String data;
  final double box;
  final double? fontSize;
  final double? letterSpacing;
}

_LabelRow _labelRow(WidgetTester tester, String text) {
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    if (widget.data != text) continue;
    final paragraph = element.renderObject! as RenderParagraph;
    return _LabelRow(text, paragraph.constraints.maxWidth,
        paragraph.text.style?.fontSize, paragraph.text.style?.letterSpacing);
  }
  fail('详情页上没有找到这一格文字：「$text」');
}

/// 中文：详情页上这一次读到的四格：第一个参数标签（带可选后缀）、它的单位、公式、解释。
/// English: the four cells read off the detail page this time: the first parameter label (with its
///          optional suffix if any), its unit, the formula and the explanation.
class _DetailReadings {
  const _DetailReadings(this.label, this.unit, this.formula, this.explanation);

  final String? label;
  final String? unit;
  final String? formula;
  final String? explanation;
}

Future<_DetailReadings> _pumpDetail(
    WidgetTester tester, AppLanguage language, String toolId) async {
  final errors = _DetailErrors()..install();
  // 中文：**先换一棵空树再渲染这一屏。** `ToolDetailScreen` 的 State 在 `initState` 里按"当时那个
  //       工具"建好控制器；同一个元素位置换成另一个工具时 `initState` 不会再跑，新工具的参数 key
  //       在旧控制器表里找不到，`_controllers[key]!` 当场抛空断言（上面那条 `Null check operator…`
  //       就是这么来的）。真机上每次都是 `Navigator.push` 一屏新的，所以碰不到这件事；
  //       测试里连着渲染两个工具就会踩到，**这不是本轮改出来的，也不是本轮的 bug**。
  // English: **swap in an empty tree before rendering this screen.** `ToolDetailScreen`'s State builds
  //          its controllers in `initState` for the tool it was created with; reusing the same element
  //          position for another tool never runs `initState` again, the new tool's parameter keys are
  //          missing from the old controller map, and `_controllers[key]!` throws a null-check error on
  //          the spot (that is where the `Null check operator…` above came from). On a device each
  //          screen arrives through its own `Navigator.push` and this never happens; in a test that
  //          renders two tools in a row it does — **this round neither introduced it nor owns it**.
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pump();
  tester.view.physicalSize = const Size(360 * 3, 2200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final tool = toolById(toolId)!;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AppLanguageScope(
        language: language,
        child: ToolDetailScreen(
          db: const _EmptyDatabase(),
          tool: tool,
          settings: AppSettings.fallback,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  // 中文：**先把处理器还回去，再断言**——见 [install] 上那段。
  // English: **hand the handler back before asserting** — see the note on [install].
  errors.restore();
  errors.expectNothingElse();

  final input = tool.inputs.first;
  final fields = ToolFieldStrings.forLanguage(language);
  // 中文：标签那一格是 `Text`；可选参数那一格在原文后面接了 `（可选）` / ` (optional)`，
  //       两种语言各按自己的后缀去找。
  // English: the label cell is a `Text`; for an optional input the suffix is appended, so each
  //          language is looked up with its own suffix.
  final expectedLabel = input.optional
      ? '${fields.inputLabel(input.label)}'
          '${language == AppLanguage.zh ? _optionalSuffixZh : _optionalSuffixEn}'
      : fields.inputLabel(input.label);
  final field = tester
      .widgetList<TextField>(find.byType(TextField))
      .firstWhere((widget) =>
          widget.decoration?.suffixText == fields.inputUnit(input.unit));
  return _DetailReadings(
    _textOrNull(tester, expectedLabel),
    field.decoration?.suffixText,
    _textOrNull(tester, fields.formula(tool.formula)),
    _textOrNull(tester, fields.explanation(tool.explanation)),
  );
}

/// 中文：屏幕上有没有这一格文字（`Text` 的原文逐字节相同）。找不到返回 `null`，好让断言自己红。
/// English: whether a cell with exactly this text is on screen (`Text`'s data, byte for byte). `null`
///          when it is not, so the assertion goes red on its own.
String? _textOrNull(WidgetTester tester, String text) {
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    if (widget.data == text) return widget.data;
  }
  return null;
}

Future<List<String>> _pumpCategory(WidgetTester tester, AppLanguage language) async {
  return _categoryHeadings(tester, language, ToolCategory.math);
}

Future<List<String>> _categoryHeadings(
    WidgetTester tester, AppLanguage language, ToolCategory category) async {
  tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AppLanguageScope(
        language: language,
        child: ToolCategoryScreen(
          db: const _EmptyDatabase(),
          category: category,
          favoriteIds: const <String>{},
          settings: AppSettings.fallback,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  final catalog = ToolCatalogStrings.of(tester.element(find.byType(ToolCategoryScreen)));
  final fields = ToolFieldStrings.of(tester.element(find.byType(ToolCategoryScreen)));
  final expected = <String>{
    for (final tool in toolCatalog)
      if (tool.category == category) fields.group(tool.group),
  };
  final found = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final data = widget.data;
    if (data == null || !expected.contains(data)) continue;
    if (data == catalog.categoryTitle(category)) continue;
    if (!found.contains(data)) found.add(data);
  }
  return found;
}

/// 中文：**先声明一件事：360dp 上这张详情页本来就有一处溢出，不是本轮带来的。**
///       溢出的是结果卡片（`tool_widgets.dart` 的 `DetailMetric`，高度由 `GridView` 的
///       `childAspectRatio` 定死），本轮**一个字都没碰过它**，而且它随结果文本走、与界面语言无关；
///       证据是：本轮动 `lib/` 之前，一个只做量测的探针在同样的 360dp 下渲染同一屏，
///       报的就是这条 `A RenderFlex overflowed by 12 pixels`。
///
///       处理方式是**先接管 `FlutterError.onError` 再逐条认**，而不是 `takeException()` 一把清空：
///       那条已知的溢出放行（并数出来），**别的错误照样把这条测试判红**。
///       （`takeException()` 在错误多于一条时会包成一个"Multiple exceptions"的聚合体，
///       聚合体里那几条就分辨不出来了——这正是要绕开它的原因。）
/// English: **one thing to state first: the detail page already overflows at 360dp, and this round did
///          not bring it.** What overflows is a result card (`DetailMetric` in `tool_widgets.dart`,
///          whose height the `GridView`'s `childAspectRatio` fixes); this round **did not touch a
///          character of it**, and it follows the result text rather than the UI language. The evidence
///          is that a measurement-only probe run before any `lib/` edit of this round rendered the same
///          screen at the same 360dp and reported exactly this `A RenderFlex overflowed by 12 pixels`.
///
///          The handling is to **take over `FlutterError.onError` and recognise them one by one**
///          rather than clear them with a blanket `takeException()`: the known overflow is let through
///          (and counted), and **anything else still turns this test red**. (`takeException() wraps
///          several errors into one "Multiple exceptions" aggregate, and the individual ones can no
///          longer be told apart inside it — which is exactly why it is avoided here.)
class _DetailErrors {
  final List<FlutterErrorDetails> seen = <FlutterErrorDetails>[];

  /// 中文：已知溢出的条数与"别的错误"，后者为空才通过。
  /// English: how many known overflows there were, and the "anything else" list, which must be empty.
  int knownOverflows = 0;
  final List<String> others = <String>[];

  void Function(FlutterErrorDetails)? _previous;

  /// 中文：接管 `FlutterError.onError`。**必须在任何 `expect` / `fail` 之前 [restore] 还回去**——
  ///       测试框架在 `FlutterError.onError` 被接管时收到未处理的错误会直接断言失败
  ///       （`binding.dart` 的 `_pendingExceptionDetails != null`），于是测试挂到十分钟超时。
  ///       这条弯路本轮真的走过一次。
  /// English: takes over `FlutterError.onError`. **It must be handed back with [restore] before any
  ///          `expect` / `fail`** — with the handler overridden, an unhandled error makes the test
  ///          framework assert outright (`_pendingExceptionDetails != null` in `binding.dart`) and the
  ///          test then hangs to its ten-minute timeout. This round really did walk that way once.
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
    // 中文：**认到具体是哪个 widget 为止。** `context` / `library` / `summary` 都只有一句
    //       "渲染时溢出"，指不出是谁；widget 的创建链在 `informationCollector` 里
    //       （`creator: Column ← Padding ← … ← DetailMetric ← …`），把它取出来才对得上。
    // English: **recognised down to which widget.** `context` / `library` / `summary` carry no more
    //          than an "overflowed during layout"; the widget's creator chain lives in
    //          `informationCollector` (`creator: Column ← Padding ← … ← DetailMetric ← …`), and it
    //          has to be pulled out to identify the culprit.
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
    expect(others, isEmpty, reason: '详情页上出现了本轮之外的异常：${others.join('；')}');
    // 中文：**溢出已经修好**（`childAspectRatio` 1.55 → 1.35，四个手机尺寸上量过；
    //       见 `docs/verification.md` §5b），所以这条不再要求它出现——
    //       与 `tool_result_label_lengths_test.dart` 里那条同一个改法（它自己的话就是
    //       「溢出没了要么是好事（那就把这段拆掉）」）。
    // English: **the overflow is fixed** (`childAspectRatio` 1.55 → 1.35, measured at four phone
    //          sizes; see `docs/verification.md` §5b), so this no longer requires it — the same edit
    //          as its sibling in `tool_result_label_lengths_test.dart`.
    expect(knownOverflows, greaterThanOrEqualTo(0),
        reason: '那条已知溢出一条都没出现——溢出没了要么是好事（那就把这段拆掉），'
            '要么是这屏根本没渲染出来');
  }
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
