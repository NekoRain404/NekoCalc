import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> quadraticResults(Map<String, double> valuesByKey) {
  final a = valuesByKey['a'] ?? 0;
  final b = valuesByKey['b'] ?? 0;
  final c = valuesByKey['c'] ?? 0;
  if (a == 0) return const [ToolResult('错误', 'a 不能为 0', '', primary: true)];
  final d = b * b - 4 * a * c;
  final xv = -b / (2 * a);
  final yv = a * xv * xv + b * xv + c;
  if (d < 0) {
    return [
      ToolResult('判别式 Δ', formatNumber(d), '', primary: true),
      const ToolResult('实根', '无', ''),
      ToolResult('顶点', '(${formatNumber(xv)}, ${formatNumber(yv)})', ''),
      ToolResult('对称轴', 'x=${formatNumber(xv)}', ''),
    ];
  }
  final root = math.sqrt(d);
  final x1 = (-b + root) / (2 * a);
  final x2 = (-b - root) / (2 * a);
  return [
    ToolResult('解 (x1, x2)', '${formatNumber(x1)}  ${formatNumber(x2)}', '',
        primary: true),
    ToolResult('判别式 Δ', formatNumber(d), ''),
    ToolResult('顶点', '(${formatNumber(xv)}, ${formatNumber(yv)})', ''),
    ToolResult('对称轴', 'x=${formatNumber(xv)}', ''),
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
      ToolResult('D', formatNumber(determinant), ''),
      ToolResult('Dx', formatNumber(determinantX), ''),
      ToolResult('Dy', formatNumber(determinantY), ''),
      ToolResult('系数矩阵秩', coefficientRank.toString(), ''),
      ToolResult('增广矩阵秩', augmentedRank.toString(), ''),
      ToolResult('方程关系', relation, ''),
      const ToolResult('验证 1', '无效', ''),
      const ToolResult('验证 2', '无效', ''),
      const ToolResult('残差 1', '无效', ''),
      const ToolResult('残差 2', '无效', ''),
    ];
  }

  final x = determinantX / determinant;
  final y = determinantY / determinant;
  final check1 = a1 * x + b1 * y;
  final check2 = a2 * x + b2 * y;
  return [
    ToolResult('解 (x, y)', '${formatNumber(x)}  ${formatNumber(y)}', '',
        primary: true),
    ToolResult('x', formatNumber(x), ''),
    ToolResult('y', formatNumber(y), ''),
    ToolResult('D', formatNumber(determinant), ''),
    ToolResult('Dx', formatNumber(determinantX), ''),
    ToolResult('Dy', formatNumber(determinantY), ''),
    ToolResult('系数矩阵秩', coefficientRank.toString(), ''),
    ToolResult('增广矩阵秩', augmentedRank.toString(), ''),
    ToolResult('方程关系', relation, ''),
    ToolResult('验证 1', formatNumber(check1), ''),
    ToolResult('验证 2', formatNumber(check2), ''),
    ToolResult('残差 1', formatNumber(check1 - c1), ''),
    ToolResult('残差 2', formatNumber(check2 - c2), ''),
  ];
}

List<ToolResult> _invalidLinearSystemResults() {
  return const [
    ToolResult('解 (x, y)', '无效', '', primary: true),
    ToolResult('x', '无效', ''),
    ToolResult('y', '无效', ''),
    ToolResult('D', '无效', ''),
    ToolResult('Dx', '无效', ''),
    ToolResult('Dy', '无效', ''),
    ToolResult('系数矩阵秩', '无效', ''),
    ToolResult('增广矩阵秩', '无效', ''),
    ToolResult('方程关系', '无效', ''),
    ToolResult('验证 1', '无效', ''),
    ToolResult('验证 2', '无效', ''),
    ToolResult('残差 1', '无效', ''),
    ToolResult('残差 2', '无效', ''),
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
    ToolResult('x^y', power.isFinite ? formatNumber(power) : '无效', '',
        primary: true),
    ToolResult(
        'y^x', reversePower.isFinite ? formatNumber(reversePower) : '无效', ''),
    ToolResult('ln(x)', x <= 0 ? '无效' : formatNumber(math.log(x)), ''),
    ToolResult(
        'log10(x)', x <= 0 ? '无效' : formatNumber(math.log(x) / math.ln10), ''),
    ToolResult('log_y(x)', baseLog.isFinite ? formatNumber(baseLog) : '无效', ''),
    ToolResult(
        'e^x', math.exp(x).isFinite ? formatNumber(math.exp(x)) : '无效', ''),
    ToolResult('sqrt(x)', x < 0 ? '无效' : formatNumber(math.sqrt(x)), ''),
    ToolResult('y次根x', root.isFinite ? formatNumber(root) : '无效', ''),
    ToolResult('1/x', x == 0 ? '无效' : formatNumber(1 / x), ''),
    ToolResult('定义域', x > 0 ? '对数有效' : '对数无效', ''),
  ];
}

List<ToolResult> _invalidExponentialLogResults() {
  return const [
    ToolResult('x^y', '无效', '', primary: true),
    ToolResult('y^x', '无效', ''),
    ToolResult('ln(x)', '无效', ''),
    ToolResult('log10(x)', '无效', ''),
    ToolResult('log_y(x)', '无效', ''),
    ToolResult('e^x', '无效', ''),
    ToolResult('sqrt(x)', '无效', ''),
    ToolResult('y次根x', '无效', ''),
    ToolResult('1/x', '无效', ''),
    ToolResult('定义域', '无效', ''),
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
      ToolResult('a', formatNumber(a), ''),
      ToolResult('b', formatNumber(b), ''),
      ToolResult('方程关系', relation, ''),
      ToolResult('退化类型', relation, ''),
      const ToolResult('验证 ax+b', '无效', ''),
    ];
  }
  final x = -b / a;
  return [
    ToolResult('解 x', formatNumber(x), '', primary: true),
    ToolResult('a', formatNumber(a), ''),
    ToolResult('b', formatNumber(b), ''),
    ToolResult('斜率 a', formatNumber(a), ''),
    ToolResult('截距 b', formatNumber(b), ''),
    ToolResult('方程关系', relation, ''),
    ToolResult('验证 ax+b', formatNumber(a * x + b), ''),
    ToolResult('x 截距', formatNumber(x), ''),
  ];
}

List<ToolResult> _invalidLinearEquationResults() {
  return const [
    ToolResult('解 x', '无效', '', primary: true),
    ToolResult('a', '无效', ''),
    ToolResult('b', '无效', ''),
    ToolResult('斜率 a', '无效', ''),
    ToolResult('截距 b', '无效', ''),
    ToolResult('方程关系', '无效', ''),
    ToolResult('验证 ax+b', '无效', ''),
    ToolResult('x 截距', '无效', ''),
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
    ToolResult('组合 C(n,k)', formatNumber(combinations), '', primary: true),
    ToolResult('排列 A(n,k)', formatNumber(permutations), ''),
    ToolResult('n!', formatNumber(_factorial(n)), ''),
    ToolResult('k!', formatNumber(_factorial(k)), ''),
    ToolResult('(n-k)!', formatNumber(_factorial(n - k)), ''),
    ToolResult(
        '重复排列 n^k',
        repeatedPermutations.isFinite
            ? formatNumber(repeatedPermutations)
            : '无效',
        ''),
    ToolResult('互补组合 C(n,n-k)', formatNumber(combinations), ''),
    ToolResult('选择比例 k/n', n == 0 ? '无效' : formatNumber(k / n * 100), '%'),
    ToolResult('整数校验', integers ? '已取整数' : '无效', ''),
  ];
}

List<ToolResult> _invalidCombinationResults() {
  return const [
    ToolResult('组合 C(n,k)', '无效', '', primary: true),
    ToolResult('排列 A(n,k)', '无效', ''),
    ToolResult('n!', '无效', ''),
    ToolResult('k!', '无效', ''),
    ToolResult('(n-k)!', '无效', ''),
    ToolResult('重复排列 n^k', '无效', ''),
    ToolResult('互补组合 C(n,n-k)', '无效', ''),
    ToolResult('选择比例 k/n', '无效', '%'),
    ToolResult('整数校验', '无效', ''),
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
    ToolResult('至少一个发生', formatNumber(either * 100), '%', primary: true),
    ToolResult('同时发生', formatNumber(both * 100), '%'),
    ToolResult('仅 A 发生', formatNumber(onlyA * 100), '%'),
    ToolResult('仅 B 发生', formatNumber(onlyB * 100), '%'),
    ToolResult('都不发生', formatNumber(neither * 100), '%'),
    ToolResult('至多一个发生', formatNumber(atMostOne * 100), '%'),
    ToolResult('A 不发生', formatNumber((1 - p1) * 100), '%'),
    ToolResult('B 不发生', formatNumber((1 - p2) * 100), '%'),
    ToolResult('事件 A', formatNumber(p1Input), '%'),
    ToolResult('事件 B', formatNumber(p2Input), '%'),
  ];
}

List<ToolResult> _invalidProbabilityResults() {
  return const [
    ToolResult('至少一个发生', '无效', '%', primary: true),
    ToolResult('同时发生', '无效', '%'),
    ToolResult('仅 A 发生', '无效', '%'),
    ToolResult('仅 B 发生', '无效', '%'),
    ToolResult('都不发生', '无效', '%'),
    ToolResult('至多一个发生', '无效', '%'),
    ToolResult('A 不发生', '无效', '%'),
    ToolResult('B 不发生', '无效', '%'),
    ToolResult('事件 A', '无效', '%'),
    ToolResult('事件 B', '无效', '%'),
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
      ToolResult('平均值', '无效', '', primary: true),
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
    ToolResult('平均值', formatNumber(mean), '', primary: true),
    ToolResult('样本数', '$count', ''),
    ToolResult('中位数', formatNumber(median), ''),
    ToolResult('总和', formatNumber(sum), ''),
    ToolResult('最小值', formatNumber(minValue), ''),
    ToolResult('最大值', formatNumber(maxValue), ''),
    ToolResult('极差', formatNumber(maxValue - minValue), ''),
    ToolResult('样本标准差', count > 1 ? formatNumber(sampleStdDev) : '无效', ''),
    ToolResult('样本方差', count > 1 ? formatNumber(sampleVariance) : '无效', ''),
    ToolResult('总体标准差', formatNumber(populationStdDev), ''),
    ToolResult('总体方差', formatNumber(populationVariance), ''),
    ToolResult(
      '变异系数',
      count > 1 && mean != 0 ? formatNumber(coefficientOfVariation) : '无效',
      '%',
    ),
  ];
}
