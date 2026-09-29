import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> quadraticResults(Map<String, double> valuesByKey) {
  final a = valuesByKey['a'] ?? 0;
  final b = valuesByKey['b'] ?? 0;
  final c = valuesByKey['c'] ?? 0;
  // 中文：**这句话是产出方写下的错误，旗标也由产出方写下。** 从前它靠 `contains('不能')`
  //       被认出来——换成别的措辞就认不出了。
  // English: **The producer writes this sentence, and the producer writes the flag.** It used to be
  //          recognised by `contains('不能')` — any other wording would have slipped past.
  if (a == 0) {
    return const [
      ToolResult('错误', 'a 不能为 0', '', primary: true, hasError: true),
    ];
  }
  final d = b * b - 4 * a * c;
  final xv = -b / (2 * a);
  final yv = a * xv * xv + b * xv + c;
  if (d < 0) {
    return [
      ToolResult.number('判别式 Δ', d, '', primary: true),
      const ToolResult('实根', '无', ''),
      ToolResult('顶点', '(${formatNumber(xv)}, ${formatNumber(yv)})', '',
          hasError: !xv.isFinite || !yv.isFinite),
      ToolResult('对称轴', 'x=${formatNumber(xv)}', '', hasError: !xv.isFinite),
    ];
  }
  final root = math.sqrt(d);
  final x1 = (-b + root) / (2 * a);
  final x2 = (-b - root) / (2 * a);
  return [
    ToolResult('解 (x1, x2)', '${formatNumber(x1)}  ${formatNumber(x2)}', '',
        primary: true, hasError: !x1.isFinite || !x2.isFinite),
    ToolResult.number('判别式 Δ', d, ''),
    ToolResult('顶点', '(${formatNumber(xv)}, ${formatNumber(yv)})', '',
        hasError: !xv.isFinite || !yv.isFinite),
    ToolResult('对称轴', 'x=${formatNumber(xv)}', '', hasError: !xv.isFinite),
  ];
}

double _factorial(int n) {
  var result = 1.0;
  for (var i = 2; i <= n; i++) {
    result *= i;
  }
  return result;
}

List<ToolResult> linearSystemResults(Map<String, double> valuesByKey) {
  final a1 = valuesByKey['a1'] ?? 0;
  final b1 = valuesByKey['b1'] ?? 0;
  final c1 = valuesByKey['c1'] ?? 0;
  final a2 = valuesByKey['a2'] ?? 0;
  final b2 = valuesByKey['b2'] ?? 0;
  final c2 = valuesByKey['c2'] ?? 0;
  if ([a1, b1, c1, a2, b2, c2].any((value) => !value.isFinite)) {
    return _invalidLinearSystemResults();
  }

  final determinant = a1 * b2 - a2 * b1;
  final determinantX = c1 * b2 - c2 * b1;
  final determinantY = a1 * c2 - a2 * c1;
  final coefficientRank = _rank2x2(a1, b1, a2, b2);
  final augmentedRank = _rank2x3(a1, b1, c1, a2, b2, c2);
  // 中文：**「方程关系」那一格被下游判据读过**（`tool_insights_math.dart` 问 `'无解'` / `'无穷多解'`），
  //       所以三支各是一条结论、句子从枚举来，值一个字都没动。
  // English: **the "方程关系" cell is read by a downstream judgement** (`tool_insights_math.dart` asks
  //          `'无解'` / `'无穷多解'`), so each of the three branches is a conclusion whose sentence comes
  //          from the enum; not one character of the value moved.
  final relationConclusion = determinant.abs() <= 1e-12
      ? (coefficientRank == augmentedRank
          ? ToolResultConclusion.infiniteSolutions
          : ToolResultConclusion.noSolution)
      : ToolResultConclusion.uniqueSolution;
  final relation = relationConclusion.sentence;
  if (determinant.abs() <= 1e-12) {
    return [
      ToolResult('解 (x, y)', relation, '',
          primary: true, conclusion: relationConclusion),
      ToolResult.number('D', determinant, ''),
      ToolResult.number('Dx', determinantX, ''),
      ToolResult.number('Dy', determinantY, ''),
      ToolResult('系数矩阵秩', coefficientRank.toString(), ''),
      ToolResult('增广矩阵秩', augmentedRank.toString(), ''),
      ToolResult('方程关系', relation, '', conclusion: relationConclusion),
      const ToolResult.invalid('验证 1', ''),
      const ToolResult.invalid('验证 2', ''),
      const ToolResult.invalid('残差 1', ''),
      const ToolResult.invalid('残差 2', ''),
    ];
  }

  final x = determinantX / determinant;
  final y = determinantY / determinant;
  final check1 = a1 * x + b1 * y;
  final check2 = a2 * x + b2 * y;
  return [
    ToolResult('解 (x, y)', '${formatNumber(x)}  ${formatNumber(y)}', '',
        primary: true, hasError: !x.isFinite || !y.isFinite),
    ToolResult.number('x', x, ''),
    ToolResult.number('y', y, ''),
    ToolResult.number('D', determinant, ''),
    ToolResult.number('Dx', determinantX, ''),
    ToolResult.number('Dy', determinantY, ''),
    ToolResult('系数矩阵秩', coefficientRank.toString(), ''),
    ToolResult('增广矩阵秩', augmentedRank.toString(), ''),
    ToolResult('方程关系', relation, '', conclusion: relationConclusion),
    ToolResult.number('验证 1', check1, ''),
    ToolResult.number('验证 2', check2, ''),
    ToolResult.number('残差 1', check1 - c1, ''),
    ToolResult.number('残差 2', check2 - c2, ''),
  ];
}

List<ToolResult> _invalidLinearSystemResults() {
  return const [
    ToolResult.invalid('解 (x, y)', '', primary: true),
    ToolResult.invalid('x', ''),
    ToolResult.invalid('y', ''),
    ToolResult.invalid('D', ''),
    ToolResult.invalid('Dx', ''),
    ToolResult.invalid('Dy', ''),
    ToolResult.invalid('系数矩阵秩', ''),
    ToolResult.invalid('增广矩阵秩', ''),
    ToolResult.invalid('方程关系', ''),
    ToolResult.invalid('验证 1', ''),
    ToolResult.invalid('验证 2', ''),
    ToolResult.invalid('残差 1', ''),
    ToolResult.invalid('残差 2', ''),
  ];
}

int _rank2x2(double a, double b, double c, double d) {
  if ((a * d - b * c).abs() > 1e-12) return 2;
  return [a, b, c, d].any((value) => value.abs() > 1e-12) ? 1 : 0;
}

int _rank2x3(double a1, double b1, double c1, double a2, double b2, double c2) {
  final minors = [
    a1 * b2 - a2 * b1,
    a1 * c2 - a2 * c1,
    b1 * c2 - b2 * c1,
  ];
  if (minors.any((value) => value.abs() > 1e-12)) return 2;
  return [a1, b1, c1, a2, b2, c2].any((value) => value.abs() > 1e-12) ? 1 : 0;
}

List<ToolResult> exponentialLogResults(Map<String, double> valuesByKey) {
  final x = valuesByKey['x'] ?? 0;
  final y = valuesByKey['y'] ?? 0;
  if (!x.isFinite || !y.isFinite) return _invalidExponentialLogResults();

  final power = math.pow(x, y).toDouble();
  final reversePower = math.pow(y, x).toDouble();
  final root = y == 0 ? double.nan : math.pow(x, 1 / y).toDouble();
  final baseLog =
      x > 0 && y > 0 && y != 1 ? math.log(x) / math.log(y) : double.nan;
  return [
    ToolResult.number('x^y', power.isFinite ? power : null, '', primary: true),
    ToolResult.number('y^x', reversePower.isFinite ? reversePower : null, ''),
    ToolResult.number('ln(x)', x <= 0 ? null : math.log(x), ''),
    ToolResult.number('log10(x)', x <= 0 ? null : math.log(x) / math.ln10, ''),
    ToolResult.number('log_y(x)', baseLog.isFinite ? baseLog : null, ''),
    ToolResult.number('e^x', math.exp(x).isFinite ? math.exp(x) : null, ''),
    ToolResult.number('sqrt(x)', x < 0 ? null : math.sqrt(x), ''),
    ToolResult.number('y次根x', root.isFinite ? root : null, ''),
    ToolResult.number('1/x', x == 0 ? null : 1 / x, ''),
    // 中文：**这一格被下游判据读过**（`tool_insights_math.dart` 问 `domain == '对数无效'`）：
    //       结论那一支的值从枚举来、旗标与令牌一起写下；`'对数有效'` 没有被任何判据读过。
    //       `hasError: !(x > 0)` 逐条不变——旧写法就是「值是『对数无效』时是错误」，两支一一对应。
    // English: **a downstream judgement reads this cell** (`tool_insights_math.dart` asks
    //          `domain == '对数无效'`): that branch's value comes from the enum with the flag and the
    //          token alongside; `'对数有效'` is read by no judgement. `hasError: !(x > 0)` is item for
    //          item unchanged — the old writing was "it is an error when the value is 对数无效", and
    //          the two branches map one to one.
    x > 0
        ? const ToolResult('定义域', '对数有效', '')
        : ToolResult.conclusion(
            '定义域', ToolResultConclusion.logUndefined, '',
            hasError: true),
  ];
}

List<ToolResult> _invalidExponentialLogResults() {
  return const [
    ToolResult.invalid('x^y', '', primary: true),
    ToolResult.invalid('y^x', ''),
    ToolResult.invalid('ln(x)', ''),
    ToolResult.invalid('log10(x)', ''),
    ToolResult.invalid('log_y(x)', ''),
    ToolResult.invalid('e^x', ''),
    ToolResult.invalid('sqrt(x)', ''),
    ToolResult.invalid('y次根x', ''),
    ToolResult.invalid('1/x', ''),
    ToolResult.invalid('定义域', ''),
  ];
}

List<ToolResult> linearEquationResults(Map<String, double> valuesByKey) {
  final a = valuesByKey['a'] ?? 0;
  final b = valuesByKey['b'] ?? 0;
  if (!a.isFinite || !b.isFinite) return _invalidLinearEquationResults();
  // 中文：**这一格被下游判据读过**（`tool_insights_math.dart` 问 `'无解'` / `'恒等式'` / `'唯一解'`）：
  //       三支各是一条结论、句子从枚举来，值一个字都没动。
  // English: **this cell is read by a downstream judgement** (`tool_insights_math.dart` asks `'无解'` /
  //          `'恒等式'` / `'唯一解'`): each of the three branches is a conclusion whose sentence comes
  //          from the enum; not one character of the value moved.
  final relationConclusion = a != 0
      ? ToolResultConclusion.uniqueSolution
      : (b == 0
          ? ToolResultConclusion.identity
          : ToolResultConclusion.noSolution);
  final relation = relationConclusion.sentence;
  if (a == 0) {
    return [
      // 中文：`'任意实数'` 没有被任何判据读过（它是普通字面量），`'无解'` 那一支是结论。
      // English: `'任意实数'` is read by no judgement (an ordinary literal); the `'无解'` branch is a
      //          conclusion.
      b == 0
          ? const ToolResult('解 x', '任意实数', '', primary: true)
          : ToolResult.conclusion('解 x', ToolResultConclusion.noSolution, '',
              primary: true),
      ToolResult.number('a', a, ''),
      ToolResult.number('b', b, ''),
      ToolResult('方程关系', relation, '', conclusion: relationConclusion),
      ToolResult('退化类型', relation, '', conclusion: relationConclusion),
      const ToolResult.invalid('验证 ax+b', ''),
    ];
  }
  final x = -b / a;
  return [
    ToolResult.number('解 x', x, '', primary: true),
    ToolResult.number('a', a, ''),
    ToolResult.number('b', b, ''),
    ToolResult.number('斜率 a', a, ''),
    ToolResult.number('截距 b', b, ''),
    ToolResult('方程关系', relation, '', conclusion: relationConclusion),
    ToolResult.number('验证 ax+b', a * x + b, ''),
    ToolResult.number('x 截距', x, ''),
  ];
}

List<ToolResult> _invalidLinearEquationResults() {
  return const [
    ToolResult.invalid('解 x', '', primary: true),
    ToolResult.invalid('a', ''),
    ToolResult.invalid('b', ''),
    ToolResult.invalid('斜率 a', ''),
    ToolResult.invalid('截距 b', ''),
    ToolResult.invalid('方程关系', ''),
    ToolResult.invalid('验证 ax+b', ''),
    ToolResult.invalid('x 截距', ''),
  ];
}

List<ToolResult> combinationResults(Map<String, double> valuesByKey) {
  final rawN = valuesByKey['n'] ?? 0;
  final rawK = valuesByKey['k'] ?? 0;
  if (!rawN.isFinite || !rawK.isFinite) return _invalidCombinationResults();
  final n = rawN.round();
  final k = rawK.round();
  final integers = (rawN - n).abs() < 1e-9 && (rawK - k).abs() < 1e-9;
  final valid = integers && n >= 0 && k >= 0 && k <= n;
  if (!valid) return _invalidCombinationResults();

  final combinations = _factorial(n) / (_factorial(k) * _factorial(n - k));
  final permutations = _factorial(n) / _factorial(n - k);
  final repeatedPermutations = math.pow(n, k).toDouble();
  return [
    ToolResult.number('组合 C(n,k)', combinations, '', primary: true),
    ToolResult.number('排列 A(n,k)', permutations, ''),
    ToolResult.number('n!', _factorial(n), ''),
    ToolResult.number('k!', _factorial(k), ''),
    ToolResult.number('(n-k)!', _factorial(n - k), ''),
    ToolResult.number('重复排列 n^k',
        repeatedPermutations.isFinite ? repeatedPermutations : null, ''),
    ToolResult.number('互补组合 C(n,n-k)', combinations, ''),
    ToolResult.number('选择比例 k/n', n == 0 ? null : k / n * 100, '%'),
    // 中文：`'无效'` 那一支的值**就是那条记号本身**，两个旗标一起为真。
    // English: the `'无效'` branch's value **is the marker itself**, so both flags are true.
    ToolResult('整数校验', integers ? '已取整数' : invalidResultValue, '',
        hasError: !integers, isInvalidMarker: !integers),
  ];
}

List<ToolResult> _invalidCombinationResults() {
  return const [
    ToolResult.invalid('组合 C(n,k)', '', primary: true),
    ToolResult.invalid('排列 A(n,k)', ''),
    ToolResult.invalid('n!', ''),
    ToolResult.invalid('k!', ''),
    ToolResult.invalid('(n-k)!', ''),
    ToolResult.invalid('重复排列 n^k', ''),
    ToolResult.invalid('互补组合 C(n,n-k)', ''),
    ToolResult.invalid('选择比例 k/n', '%'),
    ToolResult.invalid('整数校验', ''),
  ];
}

List<ToolResult> probabilityResults(Map<String, double> valuesByKey) {
  final p1Input = valuesByKey['p1'];
  final p2Input = valuesByKey['p2'];
  if (p1Input == null ||
      p2Input == null ||
      p1Input < 0 ||
      p1Input > 100 ||
      p2Input < 0 ||
      p2Input > 100 ||
      !p1Input.isFinite ||
      !p2Input.isFinite) {
    return _invalidProbabilityResults();
  }

  final p1 = p1Input / 100;
  final p2 = p2Input / 100;
  final both = p1 * p2;
  final onlyA = p1 * (1 - p2);
  final onlyB = p2 * (1 - p1);
  final either = both + onlyA + onlyB;
  final neither = (1 - p1) * (1 - p2);
  final atMostOne = 1 - both;
  return [
    ToolResult.number('至少一个发生', either * 100, '%', primary: true),
    ToolResult.number('同时发生', both * 100, '%'),
    ToolResult.number('仅 A 发生', onlyA * 100, '%'),
    ToolResult.number('仅 B 发生', onlyB * 100, '%'),
    ToolResult.number('都不发生', neither * 100, '%'),
    ToolResult.number('至多一个发生', atMostOne * 100, '%'),
    ToolResult.number('A 不发生', (1 - p1) * 100, '%'),
    ToolResult.number('B 不发生', (1 - p2) * 100, '%'),
    ToolResult.number('事件 A', p1Input, '%'),
    ToolResult.number('事件 B', p2Input, '%'),
  ];
}

List<ToolResult> _invalidProbabilityResults() {
  return const [
    ToolResult.invalid('至少一个发生', '%', primary: true),
    ToolResult.invalid('同时发生', '%'),
    ToolResult.invalid('仅 A 发生', '%'),
    ToolResult.invalid('仅 B 发生', '%'),
    ToolResult.invalid('都不发生', '%'),
    ToolResult.invalid('至多一个发生', '%'),
    ToolResult.invalid('A 不发生', '%'),
    ToolResult.invalid('B 不发生', '%'),
    ToolResult.invalid('事件 A', '%'),
    ToolResult.invalid('事件 B', '%'),
  ];
}


/// 中文：**分位数，用线性插值（R-7）。**
///
///       ⚠️ **分位数有好几种都合法的定义**——Tukey 铰链（取两半的中位数）、Excel 的
///       `QUARTILE.EXC`、本函数用的线性插值（R 与 NumPy 的默认、Excel 的 `QUARTILE.INC`）。
///       **样本少的时候它们给出的数不一样**（`12, 18, 21, 25` 的 Q1：R-7 给 16.5，
///       Tukey 给 15）。所以这里把用的是哪一种写在函数头上，
///       而不是让读者以为"分位数"只有一个答案——**那正是看起来像答案的错值**。
/// English: **a quantile, by linear interpolation (R-7).**
///
///          ⚠️ **Several definitions of a quantile are all legitimate** — Tukey's hinges (the median of
///          each half), Excel's `QUARTILE.EXC`, and the linear interpolation used here (the default in R
///          and NumPy, and Excel's `QUARTILE.INC`). **With few samples they disagree** (`12, 18, 21, 25`
///          has Q1 = 16.5 under R-7 and 15 under Tukey). So which one is used is written on this
///          function rather than left for the reader to assume "the" quartile — **an assumption that
///          produces a plausible-looking wrong value.**
double _quantile(List<double> sorted, double p) {
  if (sorted.length == 1) return sorted.first;
  final position = (sorted.length - 1) * p;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sorted[lower];
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
}

/// 中文：**几何平均数。** 只有在**全部为正**时才有定义——出现 0 或负数时回 `null`，
///       由工具照常印 `—`，**不印一个 `NaN`**。它适合"比率连乘"的场合（增长率、倍数）。
/// English: **the geometric mean.** Defined **only when every value is positive** — a zero or a negative
///          returns `null` and the tool prints `—` as it does for any unavailable cell, **never a
///          `NaN`**. It suits quantities that multiply (growth rates, ratios).
double? _geometricMean(List<double> values) {
  if (values.any((v) => v <= 0)) return null;
  final logSum = values.map(math.log).fold<double>(0, (a, b) => a + b);
  return math.exp(logSum / values.length);
}

/// 中文：**调和平均数。** 只有在**全部为正**时才有定义。
///
///       ⚠️ **闸门是 `<= 0` 而不是 `== 0`，这一条是问过引擎才定下来的。** `n / Σ(1/xᵢ)` 在
///       `[2, -4, 8]` 上**数学上一路可算**——倒数和 `0.5 - 0.25 + 0.125 = 0.375`，商是 `8`——
///       但**引擎拒绝算它**：宿主 `qalc` 5.12.0 对 `harmmean([2,-4,8])` 与
///       `harmmean([-2,-4,-8])` **都原样退回**，只对全正的一组给数。
///       **Excel 的 `HARMEAN` 是同一条规矩**（有 `≤ 0` 就返回 `#NUM!`）。
///
///       原因是这个"平均"只在**全正**时落在最小与最大之间：`[2, -4, 3]` 的倒数和是 `0.5833`，
///       商是 `5.14`——**比最大值 3 还大**，那个数不是任何意义上的"平均"。
///       所以放行它就等于印一个**看起来像答案的错值**，正是本项目最反对的那一类。
/// English: **the harmonic mean.** Defined only when **every value is positive**.
///
///          ⚠️ **The gate is `<= 0`, not `== 0`, and that was settled by asking the engine.** On
///          `[2, -4, 8]` the formula `n / Σ(1/xᵢ)` **does compute** — the reciprocal sum is
///          `0.5 - 0.25 + 0.125 = 0.375` and the quotient is `8` — yet **the engine refuses it**: host
///          `qalc` 5.12.0 returns `harmmean([2,-4,8])` and `harmmean([-2,-4,-8])` unevaluated, and only
///          evaluates an all-positive set. **Excel's `HARMEAN` follows the same rule** (any `≤ 0` gives
///          `#NUM!`).
///
///          The reason is that this "mean" only lands between the minimum and the maximum when all
///          values are positive: for `[2, -4, 3]` the reciprocal sum is `0.5833` and the quotient is
///          `5.14` — **larger than the maximum, 3** — which is not an average in any sense. Letting it
///          through would print **a wrong value that looks like an answer**, exactly the class this
///          project rejects.
double? _harmonicMean(List<double> values) {
  if (values.any((v) => v <= 0)) return null;
  // 中文：**先按最大值归一，再还原。** 直接 `n / Σ(1/xᵢ)` 在全是大数时**倒数和下溢成 0**，
  //       商就成了 `∞`——而那正是"闸门把正确结果挡掉"的形状。归一之后每一项都在 `(0, 1]`，
  //       最大那一项恰好是 `1`，所以**倒数和恒 `≥ 1`，既不下溢也不除零**，而调和平均数是
  //       齐次的（`H(cx) = c·H(x)`），乘回去就是原答案。
  //       这一条也过了引擎：`harmmean([1e308, 1e308])` → `1E308`。
  // English: **normalise by the maximum first, then scale back.** The direct `n / Σ(1/xᵢ)` **underflows
  //          the reciprocal sum to 0** when every value is huge, and the quotient becomes `∞` — which is
  //          the shape of a gate throwing away a correct answer. After normalising every term lies in
  //          `(0, 1]` and the largest is exactly `1`, so **the reciprocal sum is always `≥ 1`**: no
  //          underflow and no division by zero — and the harmonic mean is homogeneous
  //          (`H(cx) = c·H(x)`), so multiplying back returns the same answer. The engine agrees:
  //          `harmmean([1e308, 1e308])` → `1E308`.
  final scale = values.reduce(math.max);
  final reciprocalSum =
      values.map((v) => scale / v).fold<double>(0, (a, b) => a + b);
  // 中文：**先除后乘，不能先乘。** `n * scale` 在 `scale = 1e308` 时自己就溢出成 `∞`；
  //       而 `n / reciprocalSum` 恒 `≤ n`（因为倒数和 `≥ 1`），再乘以 `scale` 得到的正是
  //       `H ≤ scale`，两头都在 `double` 里。
  // English: **divide before multiplying.** `n * scale` overflows to `∞` on its own at `scale = 1e308`,
  //          whereas `n / reciprocalSum` is always `≤ n` (the reciprocal sum is `≥ 1`) and the
  //          subsequent `× scale` yields exactly `H ≤ scale` — both ends are inside `double`.
  return values.length / reciprocalSum * scale;
}

List<ToolResult> statisticsResults(Map<String, double> valuesByKey) {
  final values = <double>[];
  for (var index = 1; index <= 8; index++) {
    final value = valuesByKey['x$index'];
    if (value != null && value.isFinite) values.add(value);
  }
  if (values.isEmpty) {
    return const [
      ToolResult.invalid('平均值', '', primary: true),
      ToolResult('样本数', '0', ''),
    ];
  }

  final sorted = [...values]..sort();
  final count = sorted.length;
  final sum = values.reduce((a, b) => a + b);
  final mean = sum / count;
  final minValue = sorted.first;
  final maxValue = sorted.last;
  final median = count.isOdd
      ? sorted[count ~/ 2]
      : (sorted[count ~/ 2 - 1] + sorted[count ~/ 2]) / 2;
  final squaredErrorSum = values
      .map((item) => math.pow(item - mean, 2).toDouble())
      .fold<double>(0, (sum, item) => sum + item);
  final populationVariance = squaredErrorSum / count;
  final sampleVariance = count > 1 ? squaredErrorSum / (count - 1) : double.nan;
  final sampleStdDev = count > 1 ? math.sqrt(sampleVariance) : double.nan;
  final populationStdDev = math.sqrt(populationVariance);
  final coefficientOfVariation =
      mean == 0 ? double.nan : sampleStdDev / mean.abs() * 100;

  return [
    ToolResult.number('平均值', mean, '', primary: true),
    ToolResult('样本数', '$count', ''),
    ToolResult.number('中位数', median, ''),
    ToolResult.number('总和', sum, ''),
    ToolResult.number('最小值', minValue, ''),
    ToolResult.number('最大值', maxValue, ''),
    ToolResult.number('极差', maxValue - minValue, ''),
    ToolResult.number('样本标准差', count > 1 ? sampleStdDev : null, ''),
    ToolResult.number('样本方差', count > 1 ? sampleVariance : null, ''),
    ToolResult.number('总体标准差', populationStdDev, ''),
    ToolResult.number('总体方差', populationVariance, ''),
    ToolResult.number(
        '变异系数', count > 1 && mean != 0 ? coefficientOfVariation : null, '%'),
    // 中文：**四分位数与四分位距**——HiPER 手册里 `percentil`/`quartil`/`interquartile` 命中都是 0。
    //       IQR 的用处是**认离群点**：`[Q1 − 1.5·IQR, Q3 + 1.5·IQR]` 之外就是。
    // English: **quartiles and the interquartile range** — HiPER's manual scores zero for `percentil`,
    //          `quartil` and `interquartile`. The IQR is what spots outliers: outside
    //          `[Q1 − 1.5·IQR, Q3 + 1.5·IQR]`.
    ToolResult.number('第一四分位数', _quantile(sorted, 0.25), ''),
    ToolResult.number('第三四分位数', _quantile(sorted, 0.75), ''),
    ToolResult.number(
        '四分位距', _quantile(sorted, 0.75) - _quantile(sorted, 0.25), ''),
    // 中文：几何与调和平均数——HiPER 手册里 `geometric mean` 与 `harmonic` 也都是 0。
    // English: the geometric and harmonic means — HiPER's manual scores zero for both too.
    ToolResult.number('几何平均数', _geometricMean(values), ''),
    ToolResult.number('调和平均数', _harmonicMean(values), ''),
  ];
}
