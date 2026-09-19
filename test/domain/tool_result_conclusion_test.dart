import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insight_result_readers.dart';

import '../shared/source_scan.dart';

/// 中文：**「这条结果是一条结论、是哪一条」也没动过一个语义。**
///
///       本轮把八个 `tool_insights_*.dart` 里那**十八行、十九次****回读那句话**的判据
///       （`toolResultText(results, '简单回收期') == '未回收'`、`state == '会下滑'`、
///       `relation == '无解'`、`delta != '在范围内'`…）改成了读产出方写下的令牌
///       （[ToolResult.conclusion]）。这份测试是那次改动的锁，四段各管一件事：
///
///       1. **令牌与它那句话一一对应**（[ToolResult.sentence]）：逐条走目录里每一个工具、
///          输入电池里每一组输入，**值是哪句话、令牌就必须是哪一条结论**，两个方向都查。
///          这一条是「产出方漏写令牌」的唯一防线——漏了不会有任何东西抛，只会静默少一句提示。
///       2. **判据那十九次没有空转**：每一句结论都必须真的被电池走到过（计数 ≥ 1），
///          否则上面那条比对就有一整条结论没被覆盖。
///       3. **读令牌与旧写法同义**：`toolResultText(...) == '那句话'` 与
///          [toolResultConclusion] 在三种边界上一致（标签 `contains` 匹配、取第一条、
///          没有这条结果时一个给 `null` 一个给「不是」）。
///       4. **源码里那句话只有一份**：`calculate_tool*.dart` 与 `tool_insights*.dart` 里
///          不许再出现与某条结论**整句相同**的字面量——句子住在 [ToolResultConclusion] 里。
///          （`tool_search_aliases_*.dart` 是只读的双语检索索引，**不在扫描范围**内，
///          也不该动：它里面那两个词是给人搜的，不是判据。）
///
///       **这不是断言出来的等价，是量出来的**：改动前后两棵树上跑同一支探针（目录里每个工具 ×
///       输入电池里每一组输入的提示行全文，29611 组 / 279435 条结果 / 10MB 输出），
///       两份输出 md5 相同（`a9f25488b1d1a5888d941e088a55fa0b`）。探针当时抓到过一次真实差异
///       （`flow_velocity` 在 `diameter=1e-300` 时雷诺数是 NaN，值与令牌从两个条件上判、
///       令牌多出来了），那处随即改成一条记录，值才算真的没动。
///
/// English: **"is this result a conclusion, and which one" has not moved by one case either.**
///
///          This round turned the eighteen lines / nineteen comparisons in the eight `tool_insights_*.dart` files that
///          **read the sentence back** (`toolResultText(results, '简单回收期') == '未回收'`,
///          `state == '会下滑'`, `relation == '无解'`, `delta != '在范围内'` …) into reads of the token
///          the producer writes ([ToolResult.conclusion]). This test is that change's lock, in four
///          parts:
///
///          1. **Token and sentence correspond one to one** ([ToolResult.sentence]): walking every tool
///             in the catalog and every input map in the battery, **which sentence the value is fixes
///             which conclusion the token must be**, checked in both directions. This is the only
///             defence against "a producer forgot the token" — forget it and nothing throws, a hint
///             line merely stops appearing.
///          2. **None of those seventeen is vacuous**: every conclusion sentence has to be reached by
///             the battery (count ≥ 1), or the comparison above leaves a whole conclusion uncovered.
///          3. **Reading the token means what the old writing meant**: `toolResultText(...) ==
///             'that sentence'` and [toolResultConclusion] agree on three boundaries (labels match by
///             `contains`, the first hit wins, and an absent result gives `null` on one side and "no"
///             on the other).
///          4. **The sentence exists once in the source**: no literal **equal to a whole conclusion
///             sentence** may appear in `calculate_tool*.dart` or `tool_insights*.dart` — the sentence
///             lives in [ToolResultConclusion]. (`tool_search_aliases_*.dart` is the read-only bilingual
///             search index, **out of scan range** and not to be touched: those two words are there to
///             be searched for, not to be judged by.)
///
///          **This is not asserted equivalence, it is measured**: a probe ran on both trees before and
///          after (the full insight lines for every tool in the catalog × every input map in the
///          battery — 29611 cases / 279435 results / 10MB of output) and the two outputs share one md5
///          (`a9f25488b1d1a5888d941e088a55fa0b`). The probe caught one real difference at the time
///          (`flow_velocity` at `diameter=1e-300`, where the Reynolds number is NaN: value and token
///          were judged from two conditions and the token appeared anyway); that site was rewritten as
///          one record, and only then did the value genuinely stop moving.
void main() {
  /// 中文：**改动前那些字面量本身**（句子 → 它今天是哪一条结论）。这份对照表**故意写在测试里**、
  ///       不从枚举生成：它的全部价值就在于它是**旧知识的一份抄本**，
  ///       与 `tool_result_error_flag_test.dart` 里那份 `_legacyPredicate` 同一个理由。
  ///       **不要拿它去追新语义**。
  /// English: **the literals from before the change** (sentence → which conclusion it is today). This
  ///          table is **deliberately written in the test** rather than generated from the enum: its
  ///          whole value is being **a copy of the old knowledge**, for the same reason
  ///          `_legacyPredicate` in `tool_result_error_flag_test.dart` exists. **Do not bring it up to
  ///          date with new semantics.**
  const legacySentences = <String, ToolResultConclusion>{
    '未回收': ToolResultConclusion.neverRecovers,
    '会下滑': ToolResultConclusion.slidesDown,
    '摩擦可抵住': ToolResultConclusion.frictionHolds,
    '无穷大': ToolResultConclusion.infinite,
    '过渡': ToolResultConclusion.transition,
    '超量程': ToolResultConclusion.overRange,
    '压差不足': ToolResultConclusion.insufficientHeadroom,
    '制动/回馈': ToolResultConclusion.braking,
    '无解': ToolResultConclusion.noSolution,
    '无穷多解': ToolResultConclusion.infiniteSolutions,
    '恒等式': ToolResultConclusion.identity,
    '唯一解': ToolResultConclusion.uniqueSolution,
    '对数无效': ToolResultConclusion.logUndefined,
    '同向平行': ToolResultConclusion.parallelAligned,
    '反向平行': ToolResultConclusion.parallelOpposite,
    '垂直': ToolResultConclusion.perpendicular,
    '在范围内': ToolResultConclusion.withinRange,
  };

  test('每个工具每一组输入：令牌与它那句话一一对应', () {
    // 中文：**对照表的每一句都必须真的在产出方那边出现过**——表里多一条而源码里没有，
    //       说明这条结论已经不再被写出来，那它就该从枚举里消失（死条目）。
    // English: **every sentence in the table must really occur on the producer's side** — an entry with
    //          nothing writing it means that conclusion is no longer produced and should leave the
    //          enum (a dead entry).
    final seen = <String, int>{
      for (final sentence in legacySentences.keys) sentence: 0,
    };

    var cases = 0;
    var results = 0;
    final tokenMismatches = <String>[];
    final missingTokens = <String>[];
    for (final tool in toolCatalog) {
      for (final values in _battery(tool)) {
        late final List<ToolResult> produced;
        try {
          produced = calculateTool(tool, values);
        } catch (_) {
          continue;
        }
        cases++;
        for (final result in produced) {
          results++;
          final expected = legacySentences[result.value];
          if (expected != null) {
            seen[result.value] = seen[result.value]! + 1;
            if (result.conclusion != expected) {
              missingTokens.add('${tool.id}: 「${result.label}」= 「${result.value}」 '
                  '令牌 ${result.conclusion} / 该是 $expected');
            }
          }
          // 中文：反方向——令牌写下了，值就必须是那句话。两样分了家，
          //       下游拿令牌问出来的结论与屏幕上印的就不是一回事了。
          // English: the other direction — a token written means the value has to be that sentence.
          //          Once the two come apart, what a downstream token read concludes is not what is
          //          printed on screen.
          final conclusion = result.conclusion;
          if (conclusion != null && result.value != conclusion.sentence) {
            tokenMismatches.add('${tool.id}: 「${result.label}」= 「${result.value}」 '
                '令牌 ${conclusion.name} 那句话是「${conclusion.sentence}」');
          }
        }
      }
    }
    expect(missingTokens, isEmpty,
        reason: '这些结果的值是一句结论，产出方却没写下对应令牌：\n'
            '${missingTokens.take(20).join('\n')}');
    expect(tokenMismatches, isEmpty,
        reason: '这些结果的令牌与它的值对不上：\n${tokenMismatches.take(20).join('\n')}');
    // 中文：**这条测试不能是空转的。** 十七句结论每一句都要被电池走到过，否则上面那条比对
    //       对那一句就是一句空话。
    // English: **this test must not be vacuous.** All seventeen conclusion sentences have to be reached
    //          by the battery, or the comparison above says nothing about that one.
    final unreached = seen.entries.where((entry) => entry.value == 0).toList();
    expect(unreached, isEmpty,
        reason: '这些结论句子电池一次都没走到（比对因此是空转）：'
            '${unreached.map((entry) => entry.key).join('、')}');
    expect(cases, greaterThan(25000), reason: '输入电池没跑满');
    expect(results, greaterThan(200000), reason: '结果数太少，电池没覆盖到');
  });

  test('读令牌与旧写法 `toolResultText(...) == 那句话` 同义', () {
    final marker = <ToolResult>[
      ToolResult.conclusion('滑动状态', ToolResultConclusion.slidesDown, ''),
      const ToolResult('滑动状态说明', '无下滑趋势', ''),
      ToolResult.conclusion('安全系数', ToolResultConclusion.infinite, ''),
      const ToolResult('安全系数说明', '工作应力为 0', ''),
    ];
    // 中文：**标签是 `contains` 匹配**（与 `toolResultText` 同一套），且取**第一条**命中。
    //       `'滑动状态'` 同时命中第 1、2 两条，旧写法取第 1 条，这里也必须取第 1 条。
    // English: **labels match by `contains`** (the same rule as `toolResultText`) and the **first** hit
    //          wins. `'滑动状态'` hits both entries 1 and 2; the old writing took the first, and so
    //          must this.
    expect(toolResultText(marker, '滑动状态'), '会下滑');
    expect(toolResultConclusion(marker, '滑动状态'),
        ToolResultConclusion.slidesDown);
    // 中文：不是结论的那条结果给 `null`——与旧写法 `'无下滑趋势' == '会下滑'` 为假同义。
    // English: a result that is not a conclusion gives `null` — the same as the old writing's
    //          `'无下滑趋势' == '会下滑'` being false.
    expect(toolResultConclusion(marker, '滑动状态说明'), isNull);
    expect(toolResultConclusion(marker, '安全系数'), ToolResultConclusion.infinite);
    // 中文：没有这条结果时，`toolResultText` 给 `null`，`null == '某句话'` 为假。
    // English: with no such result `toolResultText` gives `null` and `null == 'some sentence'` is false.
    expect(toolResultText(marker, '调节状态'), isNull);
    expect(toolResultConclusion(marker, '调节状态'), isNull);
    expect(toolResultConclusion(marker, '调节状态') ==
        ToolResultConclusion.insufficientHeadroom, isFalse);
    // 中文：**「那条记号」不是结论**——`无效` 是「算不出来」，不是产出方给的一个判断。
    // English: **the marker is not a conclusion** — `无效` says "it could not be produced", not a
    //          verdict the producer reached.
    const invalid = <ToolResult>[ToolResult.invalid('电压 V', 'V')];
    expect(toolResultConclusion(invalid, '电压 V'), isNull);
    expect(invalid.single.conclusion, isNull);
  });

  test('源码里那句话只有一份：产出方与判据都不许再写整句', () {
    // 中文：**扫的是"整句相同"，不是"含有"**：提示行的句子里出现「未回收」「垂直」这些词
    //       （`'按当前净收益无法回收投入'`）是正常的文案，整句相同才说明有人把那句话从枚举里
    //       抄回了源码——而抄回去的那一份不会跟着语言走。
    // English: **the scan looks for equality with a whole sentence, not containment**: hint lines
    //          naturally contain words like 未回收 or 垂直 (`'按当前净收益无法回收投入'`); an exact match
    //          means somebody copied the sentence back out of the enum — and that copy will not follow
    //          the language.
    final sentences = <String>{
      for (final conclusion in ToolResultConclusion.values) conclusion.sentence,
    };
    final offenders = <String>[];
    for (final directory in <Directory>[
      Directory('lib/domain/usecases'),
    ]) {
      expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');
      for (final entity in directory.listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('calculate_tool') &&
            !name.startsWith('tool_insight')) {
          continue;
        }
        final source = stripComments(entity.readAsStringSync());
        for (final literal in stringLiterals(source)) {
          if (sentences.contains(literal)) {
            offenders.add('${entity.path}: 「$literal」');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '这些字面量应当走 ToolResultConclusion（句子只住在那里）：\n'
            '${offenders.join('\n')}');
  });
}

const double _nan = double.nan;
const double _inf = double.infinity;

/// 中文：输入电池里那些值。**非有限值必须在**：`'无穷大'` 与 `'对数无效'` 这些结论正是由
///       非有限数或非正数决定的，而它们是否还判得对正是本文件要证明没动的东西。
/// English: the values in the input battery. **Non-finite values must be here**: conclusions such as
///          `'无穷大'` and `'对数无效'` are decided by non-finite or non-positive numbers, and whether
///          they are still judged the same is exactly what this file proves has not moved.
const List<double> _batteryValues = <double>[
  0,
  1,
  -1,
  2,
  0.5,
  10,
  -5,
  100,
  60,
  3.14159,
  0.001,
  1e-9,
  1e9,
  1e-300,
  1e300,
  -1e300,
  _nan,
  _inf,
  -_inf,
];

/// 中文：确定性伪随机——手写 FNV-1a，不借 `String.hashCode`（它没有跨运行的保证），
///       于是这条测试与那支跨树的探针拿到的是同一组输入（探针输出 md5 相同那一次用的就是它）。
/// English: deterministic pseudo-randomness — a hand-rolled FNV-1a rather than `String.hashCode`
///          (which guarantees nothing across runs), so this test and the cross-tree probe draw the same
///          inputs (the run whose probe outputs shared one md5 used exactly this).
int _seed(String id) {
  var hash = 0x811c9dc5;
  for (final code in id.codeUnits) {
    hash = ((hash ^ code) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

Map<String, double> _defaults(ToolDefinition tool) => <String, double>{
      for (final input in tool.inputs)
        if (!input.optional || input.defaultValue != null)
          input.key: input.defaultValue ?? 0,
    };

/// 中文：一个工具的输入电池——与 `tool_result_error_flag_test.dart` 里那份逐字相同
///       （同一组固定、可复现的输入，覆盖"三选二"那类工具缺字段的情形）。
/// English: one tool's input battery — character for character the one in
///          `tool_result_error_flag_test.dart` (the same fixed, reproducible inputs, covering the
///          missing-field cases that "pick two of three"-style tools need).
Iterable<Map<String, double>> _battery(ToolDefinition tool) sync* {
  final keys = tool.inputs.map((input) => input.key).toList();
  final defaults = _defaults(tool);
  yield defaults;
  yield const <String, double>{};
  for (final key in keys) {
    for (final value in _batteryValues) {
      yield <String, double>{...defaults, key: value};
    }
  }
  for (final key in keys) {
    for (final value in _batteryValues) {
      yield <String, double>{key: value};
    }
  }
  for (final value in _batteryValues) {
    yield <String, double>{for (final key in keys) key: value};
  }
  final rng = math.Random(_seed(tool.id));
  for (var i = 0; i < 120; i++) {
    final map = <String, double>{};
    for (final key in keys) {
      if (rng.nextInt(4) == 0) continue;
      map[key] = _batteryValues[rng.nextInt(_batteryValues.length)];
    }
    yield map;
  }
}
