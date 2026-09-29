import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

/// 中文：**统计工具那一组测试。** 从 `calculate_tool_math_test.dart` 里分出来的，**唯一理由是
///       那个文件被本轮的七条统计断言推到了 880 行**，越过了 800 行的硬线。分出来的边界是
///       "按工具族分文件"——本仓 `test/domain/` 下 `calculate_tool_finance_*_test.dart`、
///       `calculate_tool_mechanics_*_test.dart` 早已是这个形状，所以这不是新规矩。
///
///       ⚠️ **几条期望值是拿引擎核过的，不是我自己算的。** 宿主 `qalc` 5.12.0 对
///       `quartile(x,1)` / `quartile(x,3)` / `geomean(x)` / `harmmean(x)` 的返回值写在各条上，
///       见 `.superpowers/backup/engine-capability-probe.md` 第七节。
/// English: **the statistics tool's test group.** Split out of `calculate_tool_math_test.dart` for
///          **one reason only: this round's seven statistics assertions pushed that file to 880
///          lines**, past the hard 800 cap. The split is by tool family, which is already the shape of
///          `calculate_tool_finance_*_test.dart` and `calculate_tool_mechanics_*_test.dart` under
///          `test/domain/`, so it is not a new rule.
///
///          ⚠️ **Several expected values were checked against the engine rather than computed by
///          hand.** Host `qalc` 5.12.0's returns for `quartile(x,1)`, `quartile(x,3)`, `geomean(x)`
///          and `harmmean(x)` are quoted on the individual tests; see section 七 of
///          `.superpowers/backup/engine-capability-probe.md`.
void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

  test('statistics reports multi sample descriptive metrics', () {
    final definition = tool('statistics');
    final values = <String, double>{
      'x1': 2,
      'x2': 4,
      'x3': 4,
      'x4': 4,
      'x5': 5,
      'x6': 5,
      'x7': 7,
      'x8': 9,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final unitsByLabel = {
      for (final result in results) result.label: result.unit,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.label, '平均值');
    expect(results.first.value, '5');
    expect(valuesByLabel['样本数'], '8');
    expect(valuesByLabel['中位数'], '4.5');
    expect(valuesByLabel['总和'], '40');
    expect(valuesByLabel['最小值'], '2');
    expect(valuesByLabel['最大值'], '9');
    expect(valuesByLabel['极差'], '7');
    expect(valuesByLabel['样本标准差'], startsWith('2.138'));
    expect(valuesByLabel['样本方差'], startsWith('4.571'));
    expect(valuesByLabel['总体标准差'], '2');
    expect(valuesByLabel['总体方差'], '4');
    expect(valuesByLabel['变异系数'], startsWith('42.761'));
    expect(unitsByLabel['变异系数'], '%');
    expect(insights, contains('当前按 8 个有效样本计算'));
    expect(insights, contains('变异系数超过 30%'));
  });

  test('statistics ignores omitted optional samples', () {
    final results = calculateTool(tool('statistics'), {
      'x1': 10,
      'x2': 20,
      'x3': 30,
    });
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['样本数'], '3');
    expect(valuesByLabel['平均值'], '20');
    expect(valuesByLabel['中位数'], '20');
    expect(valuesByLabel['总和'], '60');
    expect(valuesByLabel['总体标准差'], startsWith('8.164'));
    expect(valuesByLabel['样本标准差'], '10');
  });

  test('statistics reports quartiles geometric and harmonic means', () {
    final definition = tool('statistics');
    final values = <String, double>{
      'x1': 2,
      'x2': 4,
      'x3': 4,
      'x4': 4,
      'x5': 5,
      'x6': 5,
      'x7': 7,
      'x8': 9,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    // 中文：**这一组期望值不是我自己算的，是拿引擎核过的。** 宿主 `qalc` 5.12.0：
    //       `quartile([2,4,4,4,5,5,7,9], 1)` → `4`，`(…, 3)` → `5.5`，
    //       `geomean(…)` → `4.603215596`，`harmmean(…)` → `4.201750729`。
    //       也就是说本工具手写的四分位数（R-7 / Excel `QUARTILE.INC` 那一支）与引擎同值——
    //       **这是一条独立核对，不是自己证自己。**
    // English: **these expected values are not mine; they were checked against the engine.** Host
    //          `qalc` 5.12.0: `quartile([2,4,4,4,5,5,7,9], 1)` → `4`, `(…, 3)` → `5.5`,
    //          `geomean(…)` → `4.603215596`, `harmmean(…)` → `4.201750729`. So this tool's hand-written
    //          quartiles (the R-7 / Excel `QUARTILE.INC` branch) agree with the engine — **an independent
    //          check rather than self-certification.**
    expect(valuesByLabel['第一四分位数'], '4');
    expect(valuesByLabel['第三四分位数'], '5.5');
    expect(valuesByLabel['四分位距'], '1.5');
    expect(valuesByLabel['几何平均数'], startsWith('4.6032'));
    expect(valuesByLabel['调和平均数'], startsWith('4.2017'));
  });

  test('statistics quartiles are the same number for even and odd counts', () {
    // 中文：**偶数与奇数各钉一条。** 中位数在两种个数下走的是两个分支，四分位数不该跟着分叉。
    //       三数那组同样是引擎核对过的：`quartile([10,20,30],1)` → `15`、`(…,3)` → `25`。
    // English: **one even count and one odd count.** The median takes two branches depending on parity;
    //          the quartiles must not fork with it. The three-value set is engine-checked too:
    //          `quartile([10,20,30],1)` → `15`, `(…,3)` → `25`.
    final three = calculateTool(tool('statistics'), {
      'x1': 10,
      'x2': 20,
      'x3': 30,
    });
    final byLabel = {for (final result in three) result.label: result.value};
    expect(byLabel['第一四分位数'], '15');
    expect(byLabel['第三四分位数'], '25');
    expect(byLabel['四分位距'], '10');
  });

  test('⚠️ 几何与调和平均数在没有定义时印空档，绝不印 NaN', () {
    // 中文：**这是这两条最容易骗人的地方。** 几何平均数要求全正（有 0 或负数就没有定义），
    //       调和平均数要求全非零。`math.exp` 与 `1/x` 都不会抛，它们会**照常返回一个数**——
    //       `0` 混进去，几何平均数会静悄悄变成 `0`；负号混进去，`log` 给 `NaN`。
    //       屏幕上出现 `NaN` 就是用户眼里的"程序坏了"，而出现 `0` 更糟——那看起来像个答案。
    // English: **this is where these two most easily lie.** The geometric mean needs all-positive
    //          (a zero or a negative leaves it undefined) and the harmonic mean needs none-zero.
    //          Neither `math.exp` nor `1/x` throws; they **return a number regardless** — slip a `0` in
    //          and the geometric mean quietly becomes `0`, slip in a negative and `log` hands back
    //          `NaN`. A `NaN` on screen reads as "the program broke", and a `0` is worse: it looks like
    //          an answer.
    final withZero = calculateTool(tool('statistics'), {
      'x1': 2,
      'x2': 0,
      'x3': 8,
    });
    final withNegative = calculateTool(tool('statistics'), {
      'x1': 2,
      'x2': -4,
      'x3': 8,
    });
    final zeroValues = {for (final r in withZero) r.label: r.value};
    final negativeValues = {for (final r in withNegative) r.label: r.value};

    expect(zeroValues['几何平均数'], isNot(contains('NaN')),
        reason: '混进 0 之后几何平均数不许印出数值');
    expect(zeroValues['几何平均数'], isNot('0'), reason: '`0` 看起来像答案，比 NaN 更坏');
    expect(negativeValues['几何平均数'], isNot(contains('NaN')));
    expect(negativeValues['调和平均数'], isNot(contains('NaN')));
    // 中文：**不可用的那一格写的是那条记号本身**（`无效`，`invalidResultValue` 只有一处写法），
    //       不是破折号——这一点我先前记错过一次，是测试纠正的。
    // English: **the unavailable cell carries the marker itself** (`无效`, spelled in one place in
    //          `invalidResultValue`), not a dash — a detail I mis-remembered and the test corrected.
    expect(zeroValues['几何平均数'], '无效');
    expect(negativeValues['几何平均数'], '无效', reason: '与其它不可用格同一条规矩');
  });

  test('⚠️ 调和平均数在 `[2, -4, 8]` 上会算出一个数，但那正是必须挡掉的那种数', () {
    // 中文：**这一条是我自己先写错、被引擎纠正的。** 我原来的闸门是"没有 0 就放行"，
    //       于是 `[2, -4, 8]` 会印出 `8`——因为倒数和 `0.5 - 0.25 + 0.125 = 0.375` 一路可算。
    //       但 `[2, -4, 3]` 的商是 `5.14`，**比最大值 3 还大**：一个"平均"落在取值范围之外，
    //       它不是任何意义上的平均数。引擎拒绝算它，Excel 的 `HARMEAN` 也拒绝。
    //       **所以这里断言的是"拒绝"，而不是"算出 8"。**
    // English: **I wrote this one wrong first and the engine corrected me.** My original gate was "no
    //          zeroes, let it through", so `[2, -4, 8]` printed `8` — because the reciprocal sum
    //          `0.5 - 0.25 + 0.125 = 0.375` computes fine. But for `[2, -4, 3]` the quotient is `5.14`,
    //          **larger than the maximum, 3**: an "average" outside the range of its data is not an
    //          average in any sense. The engine refuses it and so does Excel's `HARMEAN`.
    //          **So what is asserted here is the refusal, not the `8`.**
    final mixed = calculateTool(tool('statistics'), {
      'x1': 2,
      'x2': -4,
      'x3': 8,
    });
    final byLabel = {for (final r in mixed) r.label: r.value};

    expect(byLabel['调和平均数'], '无效', reason: '有负数时调和平均数没有定义');
    expect(byLabel['几何平均数'], '无效', reason: '有负数时几何平均数没有定义');
    // 中文：**同一次里正数那几格照旧要出数。** 挡掉一个没有定义的格子，不能顺手把整张表变空。
    // English: **the well-defined cells in the same run must still produce numbers** — refusing one
    //          undefined cell must not empty the whole table.
    expect(byLabel['平均值'], '2');
    expect(byLabel['中位数'], '2');
  });

  test('调和平均数在大数上照旧出数：归一那一步防的是下溢成 ∞', () {
    // 中文：**直接 `n / Σ(1/xᵢ)` 在这里是坏的。** `1/1e308` 是 `1e-308`，两项相加仍在 `double`
    //       里，但真实用例里更小的数会让和**下溢成 0**，商就成了 `∞`——闸门于是把正确答案挡掉。
    //       引擎给的是 `harmmean([1e308, 1e308])` → `1E308`，本工具必须同值。
    // English: **the direct `n / Σ(1/xᵢ)` is broken here.** `1/1e308` is `1e-308` and two of them still
    //          fit in a `double`, but smaller values underflow the sum to `0` and the quotient becomes
    //          `∞` — at which point the gate discards a correct answer. The engine gives
    //          `harmmean([1e308, 1e308])` → `1E308`; this tool must match.
    final huge = calculateTool(tool('statistics'), {
      'x1': 1e308,
      'x2': 1e308,
    });
    final byLabel = {for (final r in huge) r.label: r.value};

    expect(byLabel['调和平均数'], isNot('无效'), reason: '两个大数的调和平均数是定义好了的');
    expect(byLabel['调和平均数'], isNot(contains('∞')));
    expect(double.tryParse(byLabel['调和平均数']!), isNotNull);
  });
}
