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
  final relation = determinant.abs() <= 1e-12
      ? (coefficientRank == augmentedRank ? '无穷多解' : '无解')
      : '唯一解';
  if (determinant.abs() <= 1e-12) {
    return [
      ToolResult('解 (x, y)', relation, '', primary: true),
      ToolResult.number('D', determinant, ''),
      ToolResult.number('Dx', determinantX, ''),
      ToolResult.number('Dy', determinantY, ''),
      ToolResult('系数矩阵秩', coefficientRank.toString(), ''),
      ToolResult('增广矩阵秩', augmentedRank.toString(), ''),
      ToolResult('方程关系', relation, ''),
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
    ToolResult('方程关系', relation, ''),
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
    ToolResult('定义域', x > 0 ? '对数有效' : '对数无效', '', hasError: !(x > 0)),
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
  final relation = a == 0 ? (b == 0 ? '恒等式' : '无解') : '唯一解';
  if (a == 0) {
    return [
      ToolResult('解 x', b == 0 ? '任意实数' : '无解', '', primary: true),
      ToolResult.number('a', a, ''),
      ToolResult.number('b', b, ''),
      ToolResult('方程关系', relation, ''),
      ToolResult('退化类型', relation, ''),
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
    ToolResult('方程关系', relation, ''),
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
  ];
}
