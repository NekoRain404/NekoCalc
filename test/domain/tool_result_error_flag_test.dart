import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insight_result_readers.dart';

/// 中文：**「这条结果算不算错误」这件事，语义一个都没动。**
///
///       本轮把判据从「回读那句给用户看的话」改成了产出方写下的旗标
///       （[ToolResult.hasError]）。这份测试是**改动前后等价**的那把锁：下面那段
///       [_legacyPredicate] 是**改动前 `tool_detail_controller.dart` 与 `tool_insights.dart`
///       里逐字节相同的两份 `_resultNeedsAttention` 的原样抄本**，一个字都没改。对目录里每一个
///       工具、输入电池里每一组输入，它都必须与旗标给出同一个答案。
///
///       为什么必须钉住：旧判据看的是**要显示给用户的那句话**。那句话一旦换语言或改措辞
///       （「无效」→「不合法」），旧判据就静默变成假——错误结果会被当成可用答案收进
///       `usableResults`、屏幕上的错误配色会翻成正常配色、`issueResults` 会变空，
///       而且不会有任何东西抛出来。旗标改成字段之后，**「哪个产出方该写 true」这件事的正确性
///       只能由这份与旧判据的比对来证明**，不能靠断言。
///
///       失败的读法：`expected: <false> actual: <true>` 意味着某个产出方**漏写**了旗标——
///       那条结果今天是错误，现在被当成正常答案。反过来则是多写了。
///
/// English: **"Is this result an error" has not moved by one case.**
///
///          This round turned the judgement from "read the sentence shown to the user back" into a
///          flag the producer writes ([ToolResult.hasError]). This test is the lock on
///          **before-equals-after**: [_legacyPredicate] below is a **verbatim copy of the two
///          byte-identical `_resultNeedsAttention` functions that stood in
///          `tool_detail_controller.dart` and `tool_insights.dart` before the change**, not one
///          character edited. For every tool in the catalog and every input map in the battery it has
///          to give the same answer as the flag.
///
///          Why it has to be pinned: the old predicate read **the sentence shown to the user**. The
///          day that sentence changes language or wording (`无效` → `不合法`) the predicate silently
///          becomes false — an error result is collected as a usable answer by `usableResults`, the
///          error colours on screen flip to normal, `issueResults` goes empty, and nothing throws.
///          With the flag as a field, **which producers should write true can only be proved by this
///          comparison against the old predicate**, never asserted.
///
///          Reading a failure: `expected: <false> actual: <true>` means a producer **forgot** the
///          flag — that result is an error today and is now being taken as a normal answer. The
///          other way round means it was written where it should not have been.
void main() {
  _readerEquivalence();

  test('每个工具每一组输入：旗标与改动前的判据逐条相同', () {
    var calls = 0;
    var results = 0;
    var flagged = 0;
    var markerFlagged = 0;
    var concluded = 0;
    var threw = 0;
    final mismatches = <String>[];
    final markerMismatches = <String>[];
    final empties = <String>[];
    for (final tool in toolCatalog) {
      for (final values in _battery(tool)) {
        calls++;
        late final List<ToolResult> produced;
        try {
          produced = calculateTool(tool, values);
        } catch (_) {
          // 中文：非有限输入本来就会让少数计算器抛（本轮之前就如此，`adcResolutionResults`
          //       走 `double.round`）。那是既有缺陷，不在本轮范围内——这里只是不把它当成
          //       判据的差异。
          // English: non-finite inputs already made a few calculators throw before this round
          //          (`adcResolutionResults` goes through `double.round`). That is a pre-existing
          //          defect outside this round's scope; here it is simply not counted as a predicate
          //          difference.
          threw++;
          continue;
        }
        for (final result in produced) {
          results++;
          final legacy = _legacyPredicate(result.value);
          if (legacy) flagged++;
          if (result.value.trim().toLowerCase() == invalidResultValue) {
            markerFlagged++;
          }
          if (result.hasError && !result.isInvalidMarker) concluded++;
          if (result.hasError != legacy) {
            mismatches.add('${tool.id}: 「${result.label}」= '
                '「${result.value}」 旗标 ${result.hasError} / 旧判据 $legacy');
          }
          // 中文：两个旗标问的是两个问题，但在「值是那条记号」这件事上必须对得上。
          // English: the two flags ask two questions, but they must agree on "the value is the
          //          marker".
          if (result.value.trim().isEmpty) {
            empties.add('${tool.id}: 「${result.label}」');
          }
          if (result.isInvalidMarker !=
              (result.value.trim() == invalidResultValue)) {
            markerMismatches.add('${tool.id}: 「${result.label}」= '
                '「${result.value}」 记号旗标 ${result.isInvalidMarker}');
          }
        }
      }
    }
    expect(empties, isEmpty,
        reason: '出现了空值结果——空值必须由产出方自己写旗标：\n${empties.join('\n')}');
    expect(markerMismatches, isEmpty,
        reason: '这些结果的「值就是那条记号」旗标与它的值对不上：\n'
            '${markerMismatches.join('\n')}');
    expect(mismatches, isEmpty,
        reason: '这些结果的旗标与改动前的判据对不上：\n${mismatches.join('\n')}');
    // 中文：**这条测试不能是空转的。** 四个计数各自钉住电池真的走到过那四类结果——
    //       少了任何一个，上面的比对就有一整类结果没被覆盖。
    // English: **this test must not be vacuous.** The four counts pin that the battery really
    //          reached those four classes of result; drop any one and a whole class goes uncovered
    //          by the comparison above.
    expect(calls, greaterThan(25000), reason: '输入电池没跑满');
    expect(results, greaterThan(200000), reason: '结果数太少，电池没覆盖到');
    expect(flagged, greaterThan(50000), reason: '旧判据说「是错误」的结果一个都没走到');
    expect(markerFlagged, greaterThan(50000), reason: '那条记号一次都没出现过');
    expect(concluded, greaterThan(0), reason: '「有结论的错误」（不可逆那一类）一次都没走到');
    expect(threw, greaterThan(0), reason: '抛出那一路一次都没走到——上面那句 catch 就没被验过');
    expect(threw, lessThan(calls), reason: '全都抛了，旗标那一路根本没跑到');
  });
}

/// 中文：**空值这一条钉的是 fail-closed 的边界。**
///
///       旧判据里 `value.isEmpty` 那一行是 fail-closed 的：一个空值算错误。旗标是产出方写的、
///       默认 `false`，所以空值**不能靠默认值继承**——产出方必须自己说。这条断言把它钉成
///       可执行的：**今天目录里一条空值都没有**（所以它是一条不触碰的边界，不是一条被忽略的
///       规约），一旦有产出方写出空值，要么它明写旗标，要么上面那条与旧判据的比对
///       （旧判据说空值是错误）当场变红。
/// English: **the empty-value clause pins the fail-closed boundary.**
///
///          The `value.isEmpty` line in the old predicate was fail-closed: an empty value counts as
///          an error. The flag is written by the producer and defaults to `false`, so the empty case
///          **cannot be inherited from the default** — the producer has to say it. This assertion
///          makes the rule executable: **there is not one empty value in the catalog today** (so it
///          is an untouched boundary rather than an overlooked rule), and the moment a producer
///          writes one it must say so, or the comparison above — where the old predicate calls an
///          empty value an error — turns red on the spot.

/// 中文：**八个 `tool_insights_*.dart` 里那 119 处 `xText == '无效'` 的等价物。**
///
///       那 119 处从前是：`toolResultText(results, '…')` 取回那句话，再拿 `== '无效'` 比一下。
///       现在它们调 [toolResultUnavailable]，问的是产出方写下的"值就是那条记号"旗标。
///       这一组钉住三个容易错的细节：**标签是 `contains` 匹配**（与 `toolResultText` 同一套）、
///       **没有这条结果时两者都答"不是"**、以及**拼出来的值（`(0, 无效)`）不算那条记号**——
///       最后这条最容易写错：照抄 `hasError` 会让「矩阵元素必须是有限数值」那一类提示多出现一次。
/// English: **the equivalent of the 119 `xText == '无效'` comparisons in the eight
///          `tool_insights_*.dart` files.**
///
///          Those 119 used to fetch the sentence with `toolResultText(results, '…')` and compare it
///          with `== '无效'`. They now call [toolResultUnavailable], asking the flag the producer
///          wrote for "the value is the marker". This group pins three details that are easy to get
///          wrong: **labels match by `contains`** (the same rule as `toolResultText`), **an absent
///          result answers "no" on both sides**, and **an assembled value (`(0, 无效)`) is not the
///          marker** — the last is the easiest to get wrong, since copying `hasError` would make the
///          "matrix entries must be finite" hint fire once too often.
void _readerEquivalence() {
  test('读「值就是那条记号」与旧写法 `xText == \'无效\'` 同义', () {
    const marker = <ToolResult>[
      ToolResult.invalid('电压 V', 'V'),
    ];
    expect(toolResultText(marker, '电压 V') == invalidResultValue, isTrue);
    expect(toolResultUnavailable(marker, '电压 V'), isTrue);

    // 中文：标签是 `contains` 匹配——旧写法也一样，这里不能悄悄改成相等。
    // English: labels match by `contains` — the old code did too, and this must not quietly become
    //          equality.
    expect(toolResultUnavailable(marker, '电压'), isTrue);

    // 中文：没有这条结果时，`toolResultText` 给 `null`，`null == '无效'` 是假。
    // English: with no such result `toolResultText` gives `null`, and `null == '无效'` is false.
    expect(toolResultText(marker, '电流'), isNull);
    expect(toolResultUnavailable(marker, '电流'), isFalse);

    // 中文：**主构造函数写不出"值是那条记号却没有旗标"的结果**——那件事由构造函数的断言挡住，
    //       见下面那一条。所以这里那条记号的路径只有 [ToolResult.invalid] 与 [ToolResult.number]。
    // English: **the main constructor cannot write "the value is the marker but no flag"** — the
    //          assertion on it blocks that, see the clause below. So the marker's only routes are
    //          [ToolResult.invalid] and [ToolResult.number].
    expect(() => ToolResult('电压 V', invalidResultValue, 'V'),
        throwsA(isA<AssertionError>()),
        reason: '主构造函数放行了那条记号且没写旗标——这个口子必须堵着');

    // 中文：**拼出来的值是错误，但它的值不是那条记号。**
    // English: **an assembled value is an error, but its value is not the marker.**
    const assembled = <ToolResult>[
      ToolResult('投影', '(0, 无效)', '', hasError: true),
    ];
    expect(toolResultText(assembled, '投影') == invalidResultValue, isFalse);
    expect(toolResultUnavailable(assembled, '投影'), isFalse);
    expect(toolResultHasError(assembled, '投影'), isTrue);

    // 中文：产出方给了明确结论的那种错误（`不可逆`），只有 `concludedError` 认得出来。
    // English: the kind of error where the producer reached a conclusion (`不可逆`) is recognised
    //          only by `concludedError`.
    const concluded = <ToolResult>[
      ToolResult('可逆状态', '不可逆', '', hasError: true),
    ];
    expect(toolResultUnavailable(concluded, '可逆状态'), isFalse);
    expect(toolResultHasError(concluded, '可逆状态'), isTrue);
    expect(toolResultConcludedError(concluded, '可逆状态'), isTrue);

    // 中文：而「算不出来」那条记号不是结论。
    // English: and the "cannot be produced" marker is not a conclusion.
    expect(toolResultConcludedError(marker, '电压 V'), isFalse);
  });

  test('不算错误的那几种句子都不该被当成错误', () {
    // 中文：`'未回收'`、`'无穷大'`、`'压差不足'`、`'可逆'`——旧判据一个都不认，新旗标也一个都不认。
    // English: `'未回收'`, `'无穷大'`, `'压差不足'`, `'可逆'` — the old predicate matched none of
    //          them, and neither do the new flags.
    for (final sentence in <String>['未回收', '无穷大', '压差不足', '可逆', '在范围内']) {
      final results = <ToolResult>[ToolResult('x', sentence, '')];
      expect(results.single.hasError, isFalse, reason: sentence);
      expect(results.single.isInvalidMarker, isFalse, reason: sentence);
      expect(toolResultUnavailable(results, 'x'), isFalse, reason: sentence);
      expect(toolResultConcludedError(results, 'x'), isFalse, reason: sentence);
    }
  });
}

/// 中文：**改动前的判据原样抄本。** 两份逐字节相同的 `_resultNeedsAttention`
///       （`tool_detail_controller.dart` 第 621 行起、`tool_insights.dart` 第 108 行起）本身，
///       除了名字前面各去掉一个下划线之外，一个字都没动。**不要修它、不要格式化它、
///       不要拿它去追新语义**——它的全部价值就在于它是旧代码。
/// English: **a verbatim copy of the predicate from before the change.** The two byte-identical
///          `_resultNeedsAttention` functions (`tool_detail_controller.dart` from line 621,
///          `tool_insights.dart` from line 108) themselves, with nothing changed but the leading
///          underscore. **Do not fix it, do not format it, do not bring it up to date with the new
///          semantics** — its entire value is that it is the old code.
// ignore: unused_element
bool _legacyPredicate(String rawValue) {
  final value = rawValue.trim().toLowerCase();
  if (value.isEmpty) return true;
  const exact = {
    '无效',
    '无唯一解',
    '无效边长',
    '不可逆',
    'a 不能为 0',
  };
  if (exact.contains(value)) return true;
  return value.contains('无效') ||
      value.contains('不能') ||
      value.contains('不可') ||
      value.contains('错误') ||
      value.contains('not finite') ||
      value.contains('nan') ||
      value.contains('infinity');
}

const double _nan = double.nan;
const double _inf = double.infinity;

/// 中文：输入电池里那些值。**非有限值必须在**——`formatNumber` 遇到它们会吐那条记号，
///       而「谁该被标成错误」正是这条测试要证明没动的东西。
/// English: the values in the input battery. **Non-finite values must be here**: `formatNumber`
///          emits the marker for them, and "which results are errors" is exactly what this test has
///          to prove has not moved.
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
///       于是这条测试与那支跨树的探针拿到的是同一组输入。
/// English: deterministic pseudo-randomness — a hand-rolled FNV-1a rather than `String.hashCode`
///          (which guarantees nothing across runs), so this test and the cross-tree probe draw the
///          same inputs.
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

/// 中文：一个工具的输入电池——固定、可复现，覆盖"三选二"那类工具缺字段的情形。
/// English: one tool's input battery — fixed, reproducible, and covering the missing-field cases
///          that "pick two of three"-style tools need.
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
