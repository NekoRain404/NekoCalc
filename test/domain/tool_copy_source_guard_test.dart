import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';
import 'package:nekocalc/features/tools/presentation/tool_explanation_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_field_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_insight_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_input_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_value_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**领域层产出方那条源码护栏，加上本轮两张新表自己的四条判据，再加一条全目录的行为面。**
///       前两条是源码面的（字有没有进表），第三条是行为面的（屏幕上真的还有没有中文）：
///       99 个工具 × 每个输入单独填的档位全算一遍，按界面侧那两个查法渲染，剩下的汉字必须是 0。
///
///       **它为什么存在。** 在此之前，三条源码护栏扫的都是别人的地盘：
///       `tools_source_guard_test.dart` / `text_tool_source_guard_test.dart` 扫**界面子树**，
///       `data_fit_copy_test.dart` 扫 `lib/domain/usecases/data_fit*.dart`。于是
///       `lib/domain/usecases/**`（除拟合那一族）与 `lib/domain/entities/**` **一条护栏都没有**
///       ——而本轮之前，工具结果值、洞察句子、目录数据这些"会到屏幕上的字"正住在这里，
///       靠人手抄进界面侧的文案表（`tool_result_label_strings*.dart` 等）而没有东西拦住下一个人。
///       本轮把结果值与洞察两族搬进表之后，缺的这条护栏补在这里。
///
///       **它扫什么。** `lib/domain/usecases` 与 `lib/domain/entities` 两个目录、全部 `.dart`
///       （两个目录都是平的，所以不递归）。**跳过的只有两类**：拟合那一族（`data_fit*`，
///       它有自己那条护栏，判据比这条严），以及下面 `_exemptFiles` 里逐条带理由的十二个文件
///       ——**豁免的是"整张表"或"整族的输入文法"，从来没有"某个产出方"**：
///       25 个产出方（17 个 `calculate_tool*.dart` + 8 个 `tool_insights*.dart`）
///       一个都不许被文件级豁免，这条也在下面断言。
///
///       **判据。** 与另外三条护栏同一把尺子（`containsWideOrFullwidth`，见
///       `test/shared/source_scan.dart`）：一条字面量含"界面文案会用到的那种字"，
///       就必须满足三者之一——
///         （一）它是**九张表**里任何一张的键：本轮的 `toolInsightSentencesAllEn` /
///               `toolInsightTemplatesAllEn` / `toolResultValuesAllEn`，
///               加上早就存在的 `toolResultLabelsAllEn`、`toolInputLabelsEn`、
///               `toolInputUnitsEn`、`toolFormulasEn`、`toolExplanationsEn`、`toolGroupsEn`。
///               **键就是中文本身**，所以"查得到"与"翻得出来"是同一件事；
///         （二）除了乘号点 `·` 再没有宽/全角字符（理由与 `data_fit_copy_test.dart` 里那条
///               `_isMultiplicationDotNotation` 逐字相同：`N·m`、`Ω·mm²/m` 这类记号
///               两种语言逐字节一样，本来就不进表）；
///         （三）在 `_sourceLiterals` 里，逐条带理由——那三条共同形状是
///               **"拿它去比、不是拿它去印"**（判据 / 输入文法 / 开发期的断言文本）。
///
///       **它不是空转的**（下面每一条都有断言）：扫到 **48** 个文件、判据放行 **1668** 条
///       表键（其中 **1649** 条来自产出方）、**5** 条记号、**12** 条豁免（**条条命中**，
///       没有死条目）、十二个豁免文件**每一个都真的含中文**；运行期拼出来那句来源的落点
///       钉在 **4** 个文件上——豁免它的那两条碎片只有在"这句还在拼"时才是对的。
///       **别把界面文案加进 `_sourceLiterals` 或 `_exemptFiles`**：入选条件是上面那些理由，
///       不是方便。
/// English: **the domain layer's producer-side source guard, plus four criteria on this round's two
///          new tables, plus a whole-catalogue behavioural sweep.** The first two tests are
///          source-level (did the words enter a table); the third is behavioural (is there still
///          Chinese on screen): all 99 tools are run under every input profile — including each input
///          filled on its own — pushed through the interface's two lookups, and what is left over must
///          be 0.
///
///          **Why it exists.** Until now all three source guards swept somebody else's ground:
///          `tools_source_guard_test.dart` / `text_tool_source_guard_test.dart` sweep the
///          **interface subtrees** and `data_fit_copy_test.dart` sweeps
///          `lib/domain/usecases/data_fit*.dart`. So `lib/domain/usecases/**` (minus the fit family)
///          and `lib/domain/entities/**` had **no guard at all** — and before this round the words
///          that reach the screen (result values, insight sentences, catalogue data) lived exactly
///          there, copied by hand into the interface-side tables (`tool_result_label_strings*.dart`
///          and friends) with nothing to stop the next person. Now that the result values and the
///          insights have moved into tables, the missing guard is added here.
///
///          **What it sweeps.** Both `lib/domain/usecases` and `lib/domain/entities`, every `.dart`
///          (both directories are flat, so no recursion). **Only two kinds are skipped**: the fit
///          family (`data_fit*`, which has its own stricter guard) and the twelve files in
///          `_exemptFiles` below, each with its reason — **what is exempted is a whole table or a
///          family's input grammar, never "some producer"**: none of the 25 producers (17
///          `calculate_tool*.dart` plus 8 `tool_insights*.dart`) may be exempted as a file, and that
///          is asserted below.
///
///          **The criterion** is the same ruler the other three guards use
///          (`containsWideOrFullwidth`, see `test/shared/source_scan.dart`): a literal holding "a
///          character interface copy is written with" must satisfy one of three things —
///            (1) it is a key of one of the **nine tables**: this round's
///                `toolInsightSentencesAllEn` / `toolInsightTemplatesAllEn` /
///                `toolResultValuesAllEn` plus the long-standing `toolResultLabelsAllEn`,
///                `toolInputLabelsEn`, `toolInputUnitsEn`, `toolFormulasEn`, `toolExplanationsEn`
///                and `toolGroupsEn`. **The key is the Chinese itself**, so "found" and "translated"
///                are the same fact;
///            (2) apart from the multiplication dot `·` it holds no wide/fullwidth character (the
///                reason is character-for-character the one behind `_isMultiplicationDotNotation` in
///                `data_fit_copy_test.dart`: notation such as `N·m` or `Ω·mm²/m` is byte-identical
///                in both languages and does not enter a table);
///            (3) it is in `_sourceLiterals`, entry by entry with a reason — those share one shape:
///                **compared against, not printed** (a needle, input grammar, a development-time
///                assertion text).
///
///          **It is not idling** (every number below is asserted): **48** files scanned, **1668**
///          table keys accepted (**1649** of them from producers), **5** notation literals, **12**
///          exemptions (**every one fires**, no dead entry), and **every** exempted file really holds
///          Chinese; the sites of the run-time-composed source are pinned at **4** files — the two
///          fragments exempted for it are only correct while that sentence is still assembled.
///          **Do not add interface copy to `_sourceLiterals` or `_exemptFiles`**: the reasons above
///          qualify an entry, not convenience.
void main() {
  test('领域层产出方写下的中文，要么在文案表里当键，要么在带理由的豁免表里', () {
    final base = Directory('lib/domain');
    expect(base.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    // 中文：**九张表的键并成一张集合。** 它们是"渲染这张网"的全部落点：领域层写下的中文
    //       只要等于其中任何一张的键，就一定能被对应的那处查表翻出来。
    // English: **the nine tables' keys merged into one set.** They are the whole rendering net: any
    //          Chinese literal the domain layer writes that equals one of these keys is guaranteed
    //          to be translated by the lookup that owns that table.
    final tableKeys = <String>{
      ...toolInsightSentencesAllEn.keys,
      ...toolInsightTemplatesAllEn.keys,
      ...toolResultValuesAllEn.keys,
      ...toolResultLabelsAllEn.keys,
      ...toolInputLabelsEn.keys,
      ...toolInputUnitsEn.keys,
      ...toolFormulasEn.keys,
      ...toolExplanationsEn.keys,
      ...toolGroupsEn.keys,
    };

    final offenders = <String>[];
    final usedExemptions = <String>{};
    final usedFileExemptions = <String>{};
    final notationOnly = <String>[];
    final producers = <String>[];
    final producersWithoutWideLiterals = <String>[];
    var scannedFiles = 0;
    var covered = 0;
    var coveredInProducers = 0;
    var composerSites = 0;

    for (final root in const <String>['lib/domain/usecases', 'lib/domain/entities']) {
      for (final entity in Directory(root).listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final name = entity.uri.pathSegments.last;
        // 中文：拟合那一族有自己的护栏（判据比这条严），跳过。
        // English: the fit family has its own, stricter guard; skip it.
        if (name.startsWith('data_fit')) continue;
        scannedFiles++;
        final isProducer =
            name.startsWith('calculate_tool') || name.startsWith('tool_insights');
        if (isProducer) producers.add(name);
        final source = stripComments(entity.readAsStringSync());
        final literals = stringLiterals(source).toSet();
        // 中文：**整文件豁免表**（逐条理由在 `_exemptFiles` 里）。只有真的含中文才算"用到了"，
        //       否则豁免会变成一个静默的洞。
        // English: **the whole-file exemption table** (reasons in `_exemptFiles`). It only counts as
        //          used when the file really holds Chinese; otherwise the exemption is a silent hole.
        if (_exemptFiles.containsKey(name)) {
          if (literals.any(containsWideOrFullwidth)) usedFileExemptions.add(name);
          continue;
        }
        // 中文：**运行期拼来源那句的落点。** 判据是源码里那句拼装的原文（两个 `_…Source` 帮手
        //       在四个文件里各写一遍），数出来钉在 4 上——下面豁免的那两条碎片只有在它还在时才成立。
        // English: **the sites of the run-time-composed source.** The needle is that assembly's
        //          source text (the two `_…Source` helpers spell it out in four files); the count is
        //          pinned at 4, because the two fragments exempted below are only legitimate while it
        //          is still there.
        if (source.contains(r"，${references.join('、')}作参考")) composerSites++;
        var fileCovered = 0;
        var fileWide = 0;
        for (final literal in literals) {
          if (!containsWideOrFullwidth(literal)) continue;
          fileWide++;
          if (tableKeys.contains(literal)) {
            fileCovered++;
            continue;
          }
          if (_isMultiplicationDotNotation(literal)) {
            notationOnly.add('$root/$name: $literal');
            continue;
          }
          if (_sourceLiterals.contains(literal)) {
            usedExemptions.add(literal);
            continue;
          }
          offenders.add('$root/$name: $literal');
        }
        covered += fileCovered;
        if (isProducer) coveredInProducers += fileCovered;
        if (isProducer && fileWide == 0) producersWithoutWideLiterals.add(name);
      }
    }

    expect(offenders, isEmpty,
        reason: '这些字面量还没走文案表（领域层的出路见本文件开头）：\n${offenders.join('\n')}');
    expect(_sourceLiterals.difference(usedExemptions), isEmpty,
        reason: '豁免表里这些条目一条都没用到，是死条目：'
            '\n${_sourceLiterals.difference(usedExemptions).join('\n')}');
    expect(_exemptFiles.keys.toSet().difference(usedFileExemptions), isEmpty,
        reason: '这些文件被豁免了却一条中文都没有（豁免已过期）：'
            '\n${_exemptFiles.keys.toSet().difference(usedFileExemptions).join('\n')}');
    expect(_exemptFiles.values.any((reason) => reason.trim().isEmpty), isFalse,
        reason: '文件豁免表里有一条没写理由');
    // 中文：**产出方一个都不许被整文件豁免。** 这条是这张表最容易被松动的地方：
    //       把某个产出方写进 `_exemptFiles`，整棵树立刻变绿而它写下的中文一条都没进表。
    // English: **no producer may be exempted as a whole file.** This is the easiest place for the
    //          table to go slack: putting one producer into `_exemptFiles` turns the whole tree green
    //          while not one of the Chinese literals it writes has entered a table.
    expect(producers.where(_exemptFiles.containsKey), isEmpty,
        reason: '产出方被整文件豁免了：${producers.where(_exemptFiles.containsKey).join(', ')}');

    // 中文：以下五个数是本轮实测，会随中文措辞与新增文件一起动，所以它们的作用只是
    //       **证明上面那几条断言没有空转**（扫描真的跑了、判据真的放行了东西、
    //       豁免真的被命中）；真正的判据是上面那四条 `expect`。
    // English: the five numbers below are this round's measurements and move with the Chinese
    //          wording and with new files, so their job is to **prove the assertions above are not
    //          idling** (the sweep really ran, the criteria really let things through, the
    //          exemptions really fired); the criteria are the four `expect`s above.
    expect(scannedFiles, 48, reason: '扫描的文件数变了（$scannedFiles）：46 个非拟合用例 + 2 个实体');
    expect(covered, 1668, reason: '表键放行的字面量数变了（$covered）：中文改过，或者表动过');
    expect(coveredInProducers, 1649, reason: '产出方贡献的数变了（$coveredInProducers）：产出方的中文没进表？');
    expect(notationOnly.length, 5, reason: '记号规则放行的条数变了（${notationOnly.length}）');
    expect(_sourceLiterals.length, 12, reason: '豁免条目数变了（${_sourceLiterals.length}）');
    expect(composerSites, 4, reason: '拼来源那句的落点数变了（$composerSites）：豁免的那两条碎片要跟着复核');
    // 中文：**25 个产出方，其中 24 个真的含中文。** 剩下的那个是 `calculate_tool_units.dart`
    //       ——单位换算那一个今天一条中文都没有，护栏对它无话可说，所以它单独记在这里，
    //       而不是让"产出方都含中文"这句话含糊地成立。
    // English: **25 producers, 24 of which really hold Chinese.** The one left is
    //          `calculate_tool_units.dart` — the unit converter holds no Chinese at all today, so the
    //          guard can say nothing about it; it is recorded here by name rather than letting "every
    //          producer holds Chinese" stand vaguely.
    expect(producers.length, 25, reason: '产出方数变了（${producers.length}）');
    expect(producersWithoutWideLiterals, <String>['calculate_tool_units.dart'],
        reason: '不含中文的产出方变了：${producersWithoutWideLiterals.join(', ')}');
  });

  test('本轮两张新表：长度、英文侧、占位符与边缘拼装', () {
    // 中文：**长度钉死。** 367 / 90 / 225 是本轮实测：它们让"某张表被清空或漏合并"立刻现形。
    // English: **lengths pinned.** 367 / 90 / 225 are this round's measurements: they make an
    //          emptied or half-merged table show up immediately.
    expect(toolInsightSentencesAllEn.length, 367, reason: '整句表长度变了');
    expect(toolInsightTemplatesAllEn.length, 90, reason: '模板表长度变了');
    expect(toolResultValuesAllEn.length, 225, reason: '结果值表长度变了：18 结论 + 90 词 + 107 来源 + 10 单位');

    var checked = 0;
    for (final table in <Map<String, String>>[
      toolInsightSentencesAllEn,
      toolInsightTemplatesAllEn,
      toolResultValuesAllEn,
    ]) {
      for (final entry in table.entries) {
        checked++;
        expect(entry.key.trim(), isNotEmpty, reason: '有一格的键是空的');
        expect(entry.value.trim(), isNotEmpty, reason: '「${entry.key}」的英文是空的');
        // 中文：英文侧不许有宽/全角字符，**只有乘号点 `·` 例外**（`N·m` 这类记号两边一样，
        //       判据与 `data_fit_copy_test.dart` 那条逐字相同）。
        // English: the English side holds no wide/fullwidth character, **with the multiplication dot
        //          `·` the only exception** (notation such as `N·m` reads the same in both languages;
        //          the criterion is character-for-character the one in `data_fit_copy_test.dart`).
        expect(containsWideOrFullwidth(entry.value.replaceAll('·', '')), isFalse,
            reason: '「${entry.key}」的英文里还有宽/全角字符：${entry.value}');
        expect(entry.value, isNot(entry.key), reason: '「${entry.key}」在英文表里没换');
      }
    }
    expect(checked, 682, reason: '三条表的条目数变了（$checked）：367 + 90 + 225');

    // 中文：**占位符个数 == 载荷个数。** `_splice` 在个数对不上时返回 `null`（= 这条模板永远
    //       不命中、整句回落中文），所以"少写一个 `{}`"是一个**静默**的漏翻——
    //       **本轮它真的抓到了一条**：主结果那条模板原先写成 `'{} {}'`，
    //       而键切出来是三个载荷（两段 `${}` 之间那个空载荷也算一格），于是那一行在英文界面上
    //       一直是中文。这条断言就是为这一类写的。
    // English: **placeholder count == payload count.** `_splice` returns `null` on a mismatch (=
    //          that template never fires and the sentence falls back to Chinese), so "one `{}` short"
    //          is a **silent** miss — **and this round it really caught one**: the primary-result
    //          template was written `'{} {}'` while its key splits into three payloads (the empty slot
    //          between the two `${}` counts too), so that line stayed Chinese under an English
    //          interface. This assertion exists for exactly that class.
    for (final entry in toolInsightTemplatesAllEn.entries) {
      expect('{}'.allMatches(entry.value).length, splitTemplate(entry.key).length - 1,
          reason: '「${entry.key}」的占位符与载荷对不上：${entry.value}');
    }

    // 中文：**中文那一侧是恒等函数**（空表，查不到就原样）——这是设计，不是漏配。
    // English: **the Chinese side is the identity function** (empty tables, a miss returns the
    //          argument) — by design, not by omission.
    expect(ToolResultValueStrings.toolResultValuesZh.values, isEmpty);
    expect(ToolResultValueStrings.toolResultValuesZh.value('无效'), '无效');
    expect(ToolInsightStrings.toolInsightsZh.insight('公式 P=UI'), '公式 P=UI');

    // 中文：**边缘那两步真的在拼。** 整句查表、模板匹配、载荷按 `；` / `，` 拆开各自查表、
    //       运行期拼出来的输入来源按形状拆——每一条都在这里钉一个具体的字符串。
    // English: **the two edge steps really assemble.** Whole-sentence lookup, template matching,
    //          payloads split on `；` / `，` and looked up one by one, and the run-time-composed input
    //          source taken apart by shape — each one is pinned here by a concrete string.
    final insights = ToolInsightStrings.forLanguage(AppLanguage.en);
    final values = ToolResultValueStrings.forLanguage(AppLanguage.en);
    expect(insights.insight('无需数值输入'), 'No numeric input needed');
    expect(insights.insight('公式 P=UI'), 'Formula P=UI');
    expect(insights.insight('输入 电压 V，电流 I'), 'Input: Voltage V, Current I');
    expect(insights.insight('范围 0.5；1.5'), 'Range: 0.5; 1.5');
    expect(insights.insight('电压 V 12V'), 'Voltage V 12V');
    // 中文：表里没有的句子原样返回——**宁可留中文，也不半翻**：`_splice` 对"载荷里还有汉字"
    //       与"个数对不上"同样返回 `null`，这条断言把那个出口也钉住了。
    // English: a sentence no table knows comes back unchanged — **Chinese is better than half
    //          translated**: `_splice` returns `null` both for "a payload still holds Han" and for a
    //          count mismatch, and this assertion pins that exit too.
    expect(insights.insight('表里没有的一句中文'), '表里没有的一句中文');
    expect(values.value('无效'), 'N/A');
    expect(values.value('电压+电流，电阻、功率作参考'),
        'Voltage + current, with resistance and power as reference');
  });

  test('全目录行为面：每个工具每种输入档位，渲染出来的英文里一个汉字都不许剩', () {
    // 中文：**这一条是行为面的，不是源码面的。** 上面两条量的是"字有没有进表"，这一条量的是
    //       "屏幕上真的还有没有中文"：把 99 个工具的每种输入档位都算一遍，再按界面侧那两个查法
    //       （`ToolInsightStrings.insight` 与 `ToolResultValueStrings.value/unit`）走一遍，
    //       剩下的汉字必须是 **0**。**档位里有"每个输入单独填一个"**——产出方的 `provided == 1`
    //       分支（圆工具的 `'半径'`、`'直径'`、`'周长'`、`'面积'`）只有这一档碰得到，
    //       只跑"全填"与"全空"会整整漏掉它（本轮就是这么量出来的）。
    //       尺子与上面那条源码护栏同一把（`containsWideOrFullwidth`，`·` 照旧例外）。
    // English: **this one is behavioural, not source-level.** The two above measure "did the words
    //          enter a table"; this measures "is there still Chinese on screen": every input profile
    //          of all 99 tools is computed and pushed through the interface's two lookups
    //          (`ToolInsightStrings.insight` and `ToolResultValueStrings.value/unit`), and what is
    //          left over must be **0**. **The profiles include "each input filled on its own"** — the
    //          producer's `provided == 1` branch (the circle tool's `'半径'`, `'直径'`, `'周长'`,
    //          `'面积'`) is only reachable through it, so running "all filled" and "all empty" alone
    //          would miss it outright (that is exactly how this round measured it). The ruler is the
    //          one the source guard above uses (`containsWideOrFullwidth`, `·` excepted as always).
    final insights = ToolInsightStrings.forLanguage(AppLanguage.en);
    final values = ToolResultValueStrings.forLanguage(AppLanguage.en);
    final offenders = <String>[];
    var lines = 0;
    var translated = 0;
    var cells = 0;
    for (final tool in toolCatalog) {
      for (final profile in _inputProfiles(tool)) {
        final results = calculateTool(tool, profile);
        for (final result in results) {
          for (final cell in <String>[
            values.value(result.value),
            values.unit(result.unit),
          ]) {
            cells++;
            if (containsWideOrFullwidth(cell.replaceAll('·', ''))) {
              offenders.add('${tool.id}：$cell');
            }
          }
        }
        for (final line in buildToolInsights(tool, profile, results)) {
          lines++;
          final english = insights.insight(line);
          if (english != line) translated++;
          if (containsWideOrFullwidth(english.replaceAll('·', ''))) {
            offenders.add('${tool.id}：$line');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '英文界面上还剩这些中文：\n${offenders.take(20).join('\n')}');
    // 中文：**这三个数是实测的看门人**：`translated` 证明这一趟真的翻到了东西（不是所有句子都
    //       原样返回），`cells` 证明结果值/单位那两格真的被数过。
    // English: **the three numbers are the keepers**: `translated` proves the sweep really rendered
    //          something (not every sentence coming back unchanged), `cells` proves the value/unit
    //          cells were really counted.
    expect(toolCatalog.length, 99, reason: '工具数变了（${toolCatalog.length}）');
    expect(lines, 3380, reason: '扫过的洞察句子数变了（$lines）');
    expect(translated, 3343, reason: '真的换了语言的句子数变了（$translated）');
    expect(cells, 12610, reason: '扫过的结果值/单位格数变了（$cells）');
  });
}

/// 中文：**一个工具的输入档位**：全空、全填、只填第一个、只填前两个，外加**每个输入单独填一个**。
///       最后那一组是这条测试的重点（见上面那段注释）。
/// English: **the input profiles of one tool**: all empty, all filled, first only, first two only, and
///          **each input filled on its own**. That last group is what this test is here for (see the
///          note above).
List<Map<String, double>> _inputProfiles(ToolDefinition tool) {
  return <Map<String, double>>[
    const <String, double>{},
    <String, double>{for (final input in tool.inputs) input.key: 1},
    if (tool.inputs.isNotEmpty)
      <String, double>{tool.inputs.first.key: 1},
    if (tool.inputs.length > 1)
      <String, double>{for (final input in tool.inputs.take(2)) input.key: 1},
    for (final input in tool.inputs) <String, double>{input.key: 1},
  ];
}

/// 中文：**整文件豁免，逐条带理由。** 入选条件只有两条：**它自己就是一张文案表**
///       （汉字住在这里是对的），或者**这是输入文法/持久化数据**（拿它去比、不是拿它去印）。
///       **没有一条是"某个产出方太麻烦"**；产出方被豁免下面有断言拦着。
/// English: **whole-file exemptions, each with its reason.** Only two conditions qualify a file: **it
///          is itself a copy table** (Chinese belongs there), or **it is input grammar / persisted
///          data** (compared against, not printed). **Not one is "this producer is inconvenient"**;
///          an assertion below stops a producer from being exempted.
const Map<String, String> _exemptFiles = <String, String>{
  // 中文：**目录那一族（六个文件 + 实体里那张分类表）。** 工具名、分类、分组与描述是**目录数据**，
  //       显示层那侧已经有 `tool_catalog_strings.dart` / `tool_field_strings.dart` 两张表
  //       （粗测：这七个文件里的 594 条宽/全角字面量中 592 条已在显示层某张表里以字面量出现，
  //       剩下两条是 `Ω·mm²/m` 与 `N·m` 这种两边逐字节相同的记号）。
  //       本轮按指示把目录整族留在范围外（另一个改动在做那一族），所以这里只做文件级豁免。
  // English: **the catalogue family (six files plus the category table in entities).** Tool names,
  //          categories, groups and descriptions are **catalogue data**, and the display side already
  //          owns two tables for them (`tool_catalog_strings.dart` / `tool_field_strings.dart`)
  //          (a rough measurement: of the 594 wide/fullwidth literals in these seven files, 592
  //          already occur as literals in a presentation-side table; the other two are notation such
  //          as `Ω·mm²/m` and `N·m`, byte-identical in both languages). This round leaves the whole
  //          catalogue family out of scope by instruction (another change owns it), so only a
  //          file-level exemption is recorded here.
  'tool_catalog_electronics.dart': '目录数据：工具名、分组与描述（显示层表在 tool_catalog_strings.dart）',
  'tool_catalog_finance.dart': '目录数据：工具名、分组与描述（显示层表在 tool_catalog_strings.dart）',
  'tool_catalog_math.dart': '目录数据：工具名、分组与描述（显示层表在 tool_catalog_strings.dart）',
  'tool_catalog_mechanical.dart': '目录数据：工具名、分组与描述（显示层表在 tool_catalog_strings.dart）',
  'tool_catalog_science.dart': '目录数据：工具名、分组与描述（显示层表在 tool_catalog_strings.dart）',
  'tool_catalog_utilities.dart': '目录数据：工具名、分组与描述（显示层表在 tool_catalog_strings.dart）',
  'tool_category.dart': '目录数据：分类名与分类说明（显示层表在 tool_catalog_strings.dart）',
  // 中文：**计算器那一族自己的两张表**（`CalculatorPasteStrings` 的 zh/en 两个实例、
  //       `CalculatorReportLabels.zh/.en/.all`）。它们与 `data_fit_copy.dart` 是同一条形状：
  //       拼句子的代码在领域层、字也在领域层，只是**取值方式改成必填参数**由界面侧递进来。
  //       所以这里是"汉字该住的地方"，不是漏翻。
  // English: **the calculator family's own two tables** (the zh/en instances of `CalculatorPasteStrings`
  //          and `CalculatorReportLabels.zh/.en/.all`). They have exactly the shape of
  //          `data_fit_copy.dart`: the code that assembles the sentence lives in the domain layer and
  //          so do the words, with the language handed in as a required argument from the interface
  //          side. So this is "where the Chinese is supposed to live", not a missed translation.
  'calculator_paste_strings.dart': '计算器那一族自己的文案表（zh/en 两个实例都在这个文件里）',
  'calculator_report_labels.dart': '计算器那一族自己的报告标签表（CalculatorReportLabels.zh/.en/.all）',
  // 中文：**笔记与记录那两处**：`notes_clipboard_import.dart` 写下的是**识别粘贴内容用的标记与
  //       九个往返标签**（`'笔记:'`、`'表达式:'`、`'工具历史:'`、`'NekoCalc 批量导出'`…）与草稿的
  //       **载荷**（首行原文、表达式原文——都是用户的数据）；`record_filter.dart` /
  //       `record_search_suggestions.dart` 是**过滤与搜索的判据**（日期写法、正则形状、
  //       拿去比中文记录的关键词）。两者都是"数据与输入文法"。
  //
  //       **这一条从前是一笔具名欠账，现在还清了。** 从前它还豁免着两句会给用户看的标题
  //       （`'导入笔记'`、`'剪贴板笔记 · …'`）——那是**产出方太麻烦**那一类，本文件开头明写不许。
  //       这一轮按 §5l 的 A+ 形状改掉了：草稿只带**措辞令牌与载荷**，标题与描述在**保存那一刻**
  //       由 `notes_import_draft_message.dart` 按 `NotesStrings` 拼（控制器手里那张表就是当时的语言，
  //       与 §5l 那三句同一条路），导入对话框那两行预览同样在画的时候取。所以下面这条豁免今天只
  //       覆盖"数据与输入文法"这一条入选理由——文件里剩下的宽/全角字面量必须**只是**那些标签；
  //       而"旧句子一个字都不许留"的看门人是 `notes_receipt_message_test.dart` 与
  //       `notes_strings_test.dart` 里各一条整文件扫描（两张扫描都不豁免这个文件）。
  // English: **the notes and records pair**: `notes_clipboard_import.dart` writes **the markers it
  //          recognises in pasted content and the nine round-trip labels** (`'笔记:'`, `'表达式:'`,
  //          `'工具历史:'`, `'NekoCalc 批量导出'` …) plus the drafts' **payloads** (the first line as
  //          written, the expression as written — the user's own data); `record_filter.dart` /
  //          `record_search_suggestions.dart` are **the criteria for filtering and search** (date
  //          spellings, regex shapes, the keywords compared against Chinese records). Both are "data
  //          and input grammar".
  //
  //          **This entry used to be a named debt; it is now paid.** It used to exempt two titles a
  //          user would see (`'导入笔记'`, `'剪贴板笔记 · …'`) — that is the "this producer is
  //          inconvenient" kind the head of this file forbids. This round changed it to §5l's A+ shape:
  //          a draft carries only **a wording token and payloads**, the title and description are
  //          composed **at the moment of saving** by `notes_import_draft_message.dart` from
  //          `NotesStrings` (the table the controller holds *is* the language of that moment, the same
  //          road as §5l's three sentences), and the import dialog's two preview rows are fetched when
  //          they are painted. So this exemption now covers **only** the "data and input grammar"
  //          qualifying condition — the wide/fullwidth literals left in the file must be **just** those
  //          labels; and the keepers of "not one word of the old sentences may stay" are one whole-file
  //          scan each in `notes_receipt_message_test.dart` and `notes_strings_test.dart` (neither scan
  //          exempts this file).
  'notes_clipboard_import.dart':
      '粘贴往返的文法：九个标签与批量导出头（标题与描述已改由笔记呈现层在保存边缘拼）',
  'record_filter.dart': '记录的过滤判据：日期写法与正则形状（拿它去比中文记录，不是拿去印）',
  'record_search_suggestions.dart': '搜索建议的分词判据（同上：输入文法）',
};

/// 中文：**单条字面量的豁免，逐条带理由**（判据见本文件开头）。共同形状是
///       **"拿它去比、不是拿它去印"**：两条是运行期拼来源那句被扫描器切开的碎片，
///       五条是产出方拿去查结果/判字段的**针**，一条是拼接用的分隔符，
///       两条是开发期断言的文本，一条是粘贴解析器的正则形状。
///       **原文与源码里逐字节相同**（扫描器取的就是引号之间的原文），所以是 raw 字符串。
/// English: **per-literal exemptions, each with its reason** (criteria at the head of this file). Their
///          common shape is **compared against, not printed**: two are fragments the scanner cuts out
///          of the run-time-composed source sentence, five are **needles** producers use to find a
///          result or judge a field, one is a join separator, two are development-time assertion
///          texts and one is the paste parser's regex shape. **Spelled exactly as they stand in the
///          source** (the scanner yields the raw text between the quotes), hence raw strings.
const Set<String> _sourceLiterals = <String>{
  // 中文：**运行期拼来源那句的两半。** 原文是 `'$source，${references.join('、')}作参考'`
  //       （四个 `_…Source` 帮手各写一遍），扫描器在内层引号处切开，于是看到的是这两段碎片
  //       ——都不是句子。整句由 `ToolResultValueStrings._composedSource` **按形状**在呈现边缘拼：
  //       头部与每个参考项各自查表，查不到就整句回落中文。上面钉住的 4 个落点就是这句话的看门人。
  // English: **the two halves of the run-time-composed source.** The source reads
  //          `'$source，${references.join('、')}作参考'` (spelled out by the four `_…Source` helpers);
  //          the scanner cuts at the nested quotes, so what it sees is these two fragments — neither is
  //          a sentence. The whole sentence is assembled **by shape** at the presentation edge by
  //          `ToolResultValueStrings._composedSource`: the head and each reference are looked up on
  //          their own, and one miss falls the whole sentence back to Chinese. The 4 sites pinned
  //          above are that sentence's keepers.
  r'$source，${references.join(',
  r')}作参考',
  // 中文：**产出方拿去比对的针。** `'范围'` 是 `result.label.contains('范围')` 的判据
  //       （决定要不要写下面那句范围行）；另外四条是 `toolResultNumber(results, '…')` /
  //       `toolResultConclusion(results, '…')` 的**查找键**——它们从不直接上屏，
  //       上屏的是查到的那个 `ToolResult`（它的 label 走 `ToolResultLabelStrings`，
  //       它的 value 走 `ToolResultValueStrings`），以及引用这些词的洞察句子（那些句子本身是
  //       `toolInsightSentencesAllEn` 的键）。
  // English: **needles the producers compare against.** `'范围'` is the criterion of
  //          `result.label.contains('范围')` (it decides whether the range line below gets written);
  //          the other four are **lookup keys** for `toolResultNumber(results, '…')` /
  //          `toolResultConclusion(results, '…')` — they never reach the screen themselves. What
  //          reaches the screen is the `ToolResult` they found (its label goes through
  //          `ToolResultLabelStrings`, its value through `ToolResultValueStrings`) and the insight
  //          sentences that quote these words (those sentences are keys of
  //          `toolInsightSentencesAllEn`).
  '范围',
  '电阻比',
  '传动比',
  '雷诺数',
  '流动状态',
  // 中文：**模板键被扫描器切开的那一段。** `tool_insights.dart` 里那句是
  //       `'范围 ${rangeLabels.join('；')}'`（单引号套单引号），扫描器在外层引号处切开，
  //       于是看到 `范围 ${rangeLabels.join(` 这么一段——**它不是一句独立的话**：
  //       整句的形状是 `toolInsightTemplatesCoreEn` 的键 `r"范围 ${rangeLabels.join('；')}"`
  //       （英文 `'Range: {}'`），载荷在边缘按 `；` 拆开。
  // English: **the piece of a template key the scanner cuts off.** The line in `tool_insights.dart`
  //          reads `'范围 ${rangeLabels.join('；')}'` (single quotes inside single quotes) and the
  //          scanner cuts at the outer quotes, so it sees `范围 ${rangeLabels.join(` — **not a
  //          sentence of its own**: the whole shape is the key
  //          `r"范围 ${rangeLabels.join('；')}"` in `toolInsightTemplatesCoreEn` (English
  //          `'Range: {}'`), with the payload split on `；` at the edge.
  r'范围 ${rangeLabels.join(',
  // 中文：**拼接用的分隔符。** `_inputLine` 把各参数格 `join('，')` 成一串，
  //       再由边缘按 `，` 拆开逐格查表（英文接 `', '`）。它自己从不成句。
  // English: **a join separator.** `_inputLine` joins the input cells with `'，'` and the edge splits
  //          them apart again to look each one up (English joins with `', '`). It is never a sentence
  //          on its own.
  '，',
  // 中文：**开发期断言的文本**（`ToolResult` 的构造函数断言，两段相邻字面量拼成一句话）。
  //       两种语言写在同一句里是**故意的**（读它的是写代码的人，不是用户），
  //       它永远不上屏，也不该进任何文案表。
  // English: **development-time assertion text** (the constructor assert of `ToolResult`; the two
  //          adjacent literals form one message). Spelling both languages in one sentence is
  //          **deliberate** (its reader is whoever writes the code, not a user); it never reaches the
  //          screen and does not belong in any copy table.
  '值是那条「无效」记号时，旗标必须一起写下——请走 ToolResult.invalid 或 ',
  'ToolResult.number，别用这个构造函数写那条记号 / a value equal to the invalid ',
  // 中文：**粘贴解析器的输入文法**（`calculator_paste_result.dart`）：它拿用户粘进来的
  //       "标签: 值"那一行去比，字符类里收着全角冒号。翻了它就再也读不懂中文输入。
  //       这个文件**吐出去**的话已经走 `CalculatorPasteStrings`（见上面的文件豁免）。
  // English: **the paste parser's input grammar** (`calculator_paste_result.dart`): it matches the
  //          "label: value" line the user pasted and its character class carries the full-width
  //          colon. Translated, it stops understanding Chinese input. The copy this file **emits**
  //          already goes through `CalculatorPasteStrings` (see the file exemption above).
  r'^\\s*(?:$escaped)\\s*[:：]\\s*(.+?)\\s*\$',
};

/// 中文：**"整条字面量里的宽/全角字符只有乘号点 `·`"的，就不是文案。** 判据与理由逐字取自
///       `data_fit_copy_test.dart` 里那条同名规则（`·` 是"中文排版里算标点"才被尺子收进来的，
///       而它同时是数学上的乘号；除了它再没有宽/全角字符，就不可能是句子）。
///       本轮它挡住的 5 条：`N·m`、`N·m²`、`Ω·mm²/m` 三个单位（两种语言逐字节相同，
///       本来就不进表），以及计算器粘贴回执里那个 ` · ` 分隔符。
/// English: **a literal whose only wide/fullwidth character is the multiplication dot `·` is not
///          copy.** The criterion and its reason are taken character-for-character from the rule of
///          the same name in `data_fit_copy_test.dart` (`·` is collected by the ruler because it
///          typesets as punctuation in Chinese, and it is also the mathematical multiplication dot;
///          with it aside, no wide/fullwidth character remains, so the literal cannot be a sentence).
///          The 5 it stops this round: the units `N·m`, `N·m²` and `Ω·mm²/m` (byte-identical in both
///          languages, so they never enter a table) and the ` · ` separator in the calculator's paste
///          receipt.
bool _isMultiplicationDotNotation(String literal) {
  return !containsWideOrFullwidth(literal.replaceAll('·', ''));
}
