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

List<ToolResult> percentageResults(Map<String, double> valuesByKey) {
  final baseInput = valuesByKey['base'];
  final rateInput = valuesByKey['rate'];
  final valueInput = valuesByKey['value'];
  final newValueInput = valuesByKey['newValue'];
  final coreInputCount = [
    baseInput,
    rateInput,
    valueInput,
    newValueInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 2 ||
      (baseInput != null && !baseInput.isFinite) ||
      (rateInput != null && !rateInput.isFinite) ||
      (valueInput != null && !valueInput.isFinite) ||
      (newValueInput != null && !newValueInput.isFinite)) {
    return _invalidPercentageResults();
  }

  double base;
  double rate;
  double value;
  double newValue;
  String source;
  double? valueDelta;
  double? newValueDelta;
  if (baseInput != null && rateInput != null) {
    base = baseInput;
    rate = rateInput;
    value = base * rate / 100;
    newValue = base + value;
    valueDelta = valueInput == null ? null : value - valueInput;
    newValueDelta = newValueInput == null ? null : newValue - newValueInput;
    source = valueInput == null && newValueInput == null
        ? '基准值+百分比'
        : '基准值+百分比，结果值作参考';
  } else if (baseInput != null && valueInput != null) {
    base = baseInput;
    value = valueInput;
    if (base == 0) return _invalidPercentageResults();
    rate = value / base * 100;
    newValue = base + value;
    newValueDelta = newValueInput == null ? null : newValue - newValueInput;
    source = newValueInput == null ? '基准值+百分比结果' : '基准值+百分比结果，新值作参考';
  } else if (baseInput != null && newValueInput != null) {
    base = baseInput;
    newValue = newValueInput;
    value = newValue - base;
    if (base == 0) return _invalidPercentageResults();
    rate = value / base * 100;
    source = '基准值+新值';
  } else if (rateInput != null && valueInput != null) {
    rate = rateInput;
    value = valueInput;
    if (rate == 0) return _invalidPercentageResults();
    base = value * 100 / rate;
    newValue = base + value;
    newValueDelta = newValueInput == null ? null : newValue - newValueInput;
    source = newValueInput == null ? '百分比+百分比结果' : '百分比+百分比结果，新值作参考';
  } else if (rateInput != null && newValueInput != null) {
    rate = rateInput;
    newValue = newValueInput;
    final multiplier = 1 + rate / 100;
    if (multiplier == 0) return _invalidPercentageResults();
    base = newValue / multiplier;
    value = newValue - base;
    source = '百分比+新值';
  } else if (valueInput != null && newValueInput != null) {
    value = valueInput;
    newValue = newValueInput;
    base = newValue - value;
    if (base == 0) return _invalidPercentageResults();
    rate = value / base * 100;
    source = '百分比结果+新值';
  } else {
    return _invalidPercentageResults();
  }

  final decreaseValue = base - value;
  return [
    ToolResult('百分比结果', formatNumber(value), '', primary: true),
    ToolResult('基准值', formatNumber(base), ''),
    ToolResult('百分比', formatNumber(rate), '%'),
    ToolResult('增加后', formatNumber(newValue), ''),
    ToolResult('减少后', formatNumber(decreaseValue), ''),
    ToolResult('变化率', formatNumber(rate), '%'),
    ToolResult(
      '结果占新值',
      newValue == 0 ? '无效' : formatNumber(value / newValue * 100),
      '%',
    ),
    ToolResult('输入来源', source, ''),
    if (valueDelta != null) ToolResult('结果差值', formatNumber(valueDelta), ''),
    if (newValueDelta != null)
      ToolResult('新值差值', formatNumber(newValueDelta), ''),
  ];
}

List<ToolResult> _invalidPercentageResults() {
  return const [
    ToolResult('百分比结果', '无效', '', primary: true),
    ToolResult('基准值', '无效', ''),
    ToolResult('百分比', '无效', '%'),
    ToolResult('增加后', '无效', ''),
    ToolResult('减少后', '无效', ''),
    ToolResult('变化率', '无效', '%'),
    ToolResult('结果占新值', '无效', '%'),
    ToolResult('输入来源', '无效', ''),
  ];
}

List<ToolResult> proportionResults(Map<String, double> valuesByKey) {
  final aInput = valuesByKey['a'];
  final bInput = valuesByKey['b'];
  final cInput = valuesByKey['c'];
  final xInput = valuesByKey['x'];
  final inputCount =
      [aInput, bInput, cInput, xInput].where((value) => value != null).length;
  if (inputCount < 3 ||
      (aInput != null && !aInput.isFinite) ||
      (bInput != null && !bInput.isFinite) ||
      (cInput != null && !cInput.isFinite) ||
      (xInput != null && !xInput.isFinite)) {
    return _invalidProportionResults();
  }

  double a;
  double b;
  double c;
  double x;
  String source;
  double? xDelta;
  if (aInput != null && bInput != null && cInput != null) {
    if (aInput == 0) return _invalidProportionResults();
    a = aInput;
    b = bInput;
    c = cInput;
    x = b * c / a;
    xDelta = xInput == null ? null : x - xInput;
    source = xInput == null ? 'a+b+c' : 'a+b+c，x作参考';
  } else if (xInput != null && bInput != null && cInput != null) {
    if (xInput == 0) return _invalidProportionResults();
    x = xInput;
    b = bInput;
    c = cInput;
    a = b * c / x;
    source = 'b+c+x';
  } else if (xInput != null && aInput != null && cInput != null) {
    if (cInput == 0) return _invalidProportionResults();
    x = xInput;
    a = aInput;
    c = cInput;
    b = a * x / c;
    source = 'a+c+x';
  } else if (xInput != null && aInput != null && bInput != null) {
    if (bInput == 0) return _invalidProportionResults();
    x = xInput;
    a = aInput;
    b = bInput;
    c = a * x / b;
    source = 'a+b+x';
  } else {
    return _invalidProportionResults();
  }

  final leftRatio = a == 0 ? double.nan : b / a;
  final rightRatio = c == 0 ? double.nan : x / c;
  return [
    ToolResult('x', formatNumber(x), '', primary: true),
    ToolResult('a', formatNumber(a), ''),
    ToolResult('b', formatNumber(b), ''),
    ToolResult('c', formatNumber(c), ''),
    ToolResult(
        '比例',
        '${formatNumber(a)}:${formatNumber(b)} = ${formatNumber(c)}:${formatNumber(x)}',
        ''),
    ToolResult(
      '比例系数',
      leftRatio.isFinite ? formatNumber(leftRatio) : '无效',
      'x',
    ),
    ToolResult(
      '交叉乘积差',
      formatNumber(a * x - b * c),
      '',
    ),
    ToolResult(
      '右侧系数',
      rightRatio.isFinite ? formatNumber(rightRatio) : '无效',
      'x',
    ),
    ToolResult('输入来源', source, ''),
    if (xDelta != null) ToolResult('x差值', formatNumber(xDelta), ''),
  ];
}

List<ToolResult> _invalidProportionResults() {
  return const [
    ToolResult('x', '无效', '', primary: true),
    ToolResult('a', '无效', ''),
    ToolResult('b', '无效', ''),
    ToolResult('c', '无效', ''),
    ToolResult('比例', '无效', ''),
    ToolResult('比例系数', '无效', 'x'),
    ToolResult('交叉乘积差', '无效', ''),
    ToolResult('右侧系数', '无效', 'x'),
    ToolResult('输入来源', '无效', ''),
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

List<ToolResult> matrixResults(Map<String, double> valuesByKey) {
  final a = valuesByKey['a'] ?? 0;
  final b = valuesByKey['b'] ?? 0;
  final c = valuesByKey['c'] ?? 0;
  final d = valuesByKey['d'] ?? 0;
  if (!a.isFinite || !b.isFinite || !c.isFinite || !d.isFinite) {
    return _invalidMatrixResults();
  }
  final determinant = a * d - b * c;
  final trace = a + d;
  final discriminant = trace * trace - 4 * determinant;
  final frobenius = math.sqrt(a * a + b * b + c * c + d * d);
  final row1Norm = a.abs() + b.abs();
  final row2Norm = c.abs() + d.abs();
  final col1Norm = a.abs() + c.abs();
  final col2Norm = b.abs() + d.abs();
  final rank = determinant.abs() > 1e-12
      ? 2
      : (a.abs() > 1e-12 ||
              b.abs() > 1e-12 ||
              c.abs() > 1e-12 ||
              d.abs() > 1e-12)
          ? 1
          : 0;
  final inverse = determinant.abs() <= 1e-12
      ? '不可逆'
      : '[${formatNumber(d / determinant)}, ${formatNumber(-b / determinant)}; ${formatNumber(-c / determinant)}, ${formatNumber(a / determinant)}]';
  final eigenText = discriminant < 0
      ? _complexEigenvalues(trace, discriminant)
      : _realEigenvalues(trace, discriminant);
  return [
    ToolResult('行列式 det', formatNumber(determinant), '', primary: true),
    ToolResult('迹 tr', formatNumber(trace), ''),
    ToolResult('判别项', formatNumber(discriminant), ''),
    ToolResult('逆矩阵', inverse, ''),
    ToolResult('秩', rank.toString(), ''),
    ToolResult('特征值', eigenText, ''),
    ToolResult('Frobenius范数', formatNumber(frobenius), ''),
    ToolResult('行和范数', formatNumber(math.max(row1Norm, row2Norm)), ''),
    ToolResult('列和范数', formatNumber(math.max(col1Norm, col2Norm)), ''),
    ToolResult('可逆状态', determinant.abs() <= 1e-12 ? '不可逆' : '可逆', ''),
  ];
}

List<ToolResult> _invalidMatrixResults() {
  return const [
    ToolResult('行列式 det', '无效', '', primary: true),
    ToolResult('迹 tr', '无效', ''),
    ToolResult('判别项', '无效', ''),
    ToolResult('逆矩阵', '无效', ''),
    ToolResult('秩', '无效', ''),
    ToolResult('特征值', '无效', ''),
    ToolResult('Frobenius范数', '无效', ''),
    ToolResult('行和范数', '无效', ''),
    ToolResult('列和范数', '无效', ''),
    ToolResult('可逆状态', '无效', ''),
  ];
}

String _realEigenvalues(double trace, double discriminant) {
  final root = math.sqrt(discriminant);
  return '${formatNumber((trace + root) / 2)} / ${formatNumber((trace - root) / 2)}';
}

String _complexEigenvalues(double trace, double discriminant) {
  final real = trace / 2;
  final imaginary = math.sqrt(-discriminant) / 2;
  return '${formatNumber(real)} + ${formatNumber(imaginary)}i / ${formatNumber(real)} - ${formatNumber(imaginary)}i';
}

List<ToolResult> complexResults(Map<String, double> valuesByKey) {
  final a = valuesByKey['a'] ?? 0;
  final b = valuesByKey['b'] ?? 0;
  final c = valuesByKey['c'] ?? 0;
  final d = valuesByKey['d'] ?? 0;
  if (!a.isFinite || !b.isFinite || !c.isFinite || !d.isFinite) {
    return _invalidComplexResults();
  }
  final denominator = c * c + d * d;
  final z1Magnitude = math.sqrt(a * a + b * b);
  final z2Magnitude = math.sqrt(c * c + d * d);
  final argument = math.atan2(b, a) * 180 / math.pi;
  final z2Argument = math.atan2(d, c) * 180 / math.pi;
  return [
    ToolResult('z1 + z2', _complexText(a + c, b + d), '', primary: true),
    ToolResult('z1 - z2', _complexText(a - c, b - d), ''),
    ToolResult('z1 × z2', _complexText(a * c - b * d, a * d + b * c), ''),
    ToolResult(
      'z1 ÷ z2',
      denominator == 0
          ? '无效'
          : _complexText(
              (a * c + b * d) / denominator,
              (b * c - a * d) / denominator,
            ),
      '',
    ),
    ToolResult('|z1|', formatNumber(z1Magnitude), ''),
    ToolResult('|z2|', formatNumber(z2Magnitude), ''),
    ToolResult(
        'arg(z1)', z1Magnitude == 0 ? '无效' : formatNumber(argument), 'deg'),
    ToolResult(
        'arg(z2)', z2Magnitude == 0 ? '无效' : formatNumber(z2Argument), 'deg'),
    ToolResult('conj(z1)', _complexText(a, -b), ''),
    ToolResult('conj(z2)', _complexText(c, -d), ''),
  ];
}

List<ToolResult> _invalidComplexResults() {
  return const [
    ToolResult('z1 + z2', '无效', '', primary: true),
    ToolResult('z1 - z2', '无效', ''),
    ToolResult('z1 × z2', '无效', ''),
    ToolResult('z1 ÷ z2', '无效', ''),
    ToolResult('|z1|', '无效', ''),
    ToolResult('|z2|', '无效', ''),
    ToolResult('arg(z1)', '无效', 'deg'),
    ToolResult('arg(z2)', '无效', 'deg'),
    ToolResult('conj(z1)', '无效', ''),
    ToolResult('conj(z2)', '无效', ''),
  ];
}

String _complexText(double real, double imaginary) {
  return '${formatNumber(real)} ${_signedImag(imaginary)}i';
}

List<ToolResult> vectorResults(Map<String, double> valuesByKey) {
  final x1 = valuesByKey['x1'] ?? 0;
  final y1 = valuesByKey['y1'] ?? 0;
  final x2 = valuesByKey['x2'] ?? 0;
  final y2 = valuesByKey['y2'] ?? 0;
  if (!x1.isFinite || !y1.isFinite || !x2.isFinite || !y2.isFinite) {
    return _invalidVectorResults();
  }
  final dot = x1 * x2 + y1 * y2;
  final cross = x1 * y2 - y1 * x2;
  final len1 = math.sqrt(x1 * x1 + y1 * y1);
  final len2 = math.sqrt(x2 * x2 + y2 * y2);
  final cos = len1 == 0 || len2 == 0
      ? double.nan
      : (dot / (len1 * len2)).clamp(-1.0, 1.0);
  final angle = cos.isFinite ? math.acos(cos) * 180 / math.pi : double.nan;
  final distance = math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2));
  final projectionOnB = len2 == 0 ? double.nan : dot / len2;
  final projectionVectorOnB = len2 == 0
      ? '无效'
      : '(${formatNumber(dot / (len2 * len2) * x2)}, ${formatNumber(dot / (len2 * len2) * y2)})';
  final directionA =
      len1 == 0 ? double.nan : math.atan2(y1, x1) * 180 / math.pi;
  final directionB =
      len2 == 0 ? double.nan : math.atan2(y2, x2) * 180 / math.pi;
  return [
    ToolResult('点积', formatNumber(dot), '', primary: true),
    ToolResult('叉积 z', formatNumber(cross), ''),
    ToolResult('夹角', angle.isFinite ? formatNumber(angle) : '无效', 'deg'),
    ToolResult(
        '|A| / |B|', '${formatNumber(len1)} / ${formatNumber(len2)}', ''),
    ToolResult('距离 |A-B|', formatNumber(distance), ''),
    ToolResult('cosθ', cos.isFinite ? formatNumber(cos) : '无效', ''),
    ToolResult('A在B方向投影',
        projectionOnB.isFinite ? formatNumber(projectionOnB) : '无效', ''),
    ToolResult('A到B投影向量', projectionVectorOnB, ''),
    ToolResult(
        '方向角 A', directionA.isFinite ? formatNumber(directionA) : '无效', 'deg'),
    ToolResult(
        '方向角 B', directionB.isFinite ? formatNumber(directionB) : '无效', 'deg'),
    ToolResult('关系', _vectorRelation(dot, cross, len1, len2), ''),
  ];
}

List<ToolResult> _invalidVectorResults() {
  return const [
    ToolResult('点积', '无效', '', primary: true),
    ToolResult('叉积 z', '无效', ''),
    ToolResult('夹角', '无效', 'deg'),
    ToolResult('|A| / |B|', '无效', ''),
    ToolResult('距离 |A-B|', '无效', ''),
    ToolResult('cosθ', '无效', ''),
    ToolResult('A在B方向投影', '无效', ''),
    ToolResult('A到B投影向量', '无效', ''),
    ToolResult('方向角 A', '无效', 'deg'),
    ToolResult('方向角 B', '无效', 'deg'),
    ToolResult('关系', '无效', ''),
  ];
}

String _vectorRelation(
  double dot,
  double cross,
  double len1,
  double len2,
) {
  if (len1 == 0 || len2 == 0) return '零向量';
  if (cross.abs() < 1e-9) return dot >= 0 ? '同向平行' : '反向平行';
  if (dot.abs() < 1e-9) return '垂直';
  return '一般夹角';
}

List<ToolResult> triangleResults(Map<String, double> valuesByKey) {
  final a = valuesByKey['a'] ?? 0;
  final b = valuesByKey['b'] ?? 0;
  final c = valuesByKey['c'] ?? 0;
  final valid = a > 0 &&
      b > 0 &&
      c > 0 &&
      a.isFinite &&
      b.isFinite &&
      c.isFinite &&
      a + b > c &&
      a + c > b &&
      b + c > a;
  if (!valid) return _invalidTriangleResults();

  final perimeter = a + b + c;
  final s = perimeter / 2;
  final area = math.sqrt(s * (s - a) * (s - b) * (s - c));
  final angleA = _triangleAngle(opposite: a, adjacent1: b, adjacent2: c);
  final angleB = _triangleAngle(opposite: b, adjacent1: a, adjacent2: c);
  final angleC = 180 - angleA - angleB;
  final longest = math.max(a, math.max(b, c));
  final shortest = math.min(a, math.min(b, c));
  final inradius = area / s;
  final circumradius = a * b * c / (4 * area);
  final heightA = 2 * area / a;
  final heightB = 2 * area / b;
  final heightC = 2 * area / c;
  final type = _triangleType(a, b, c);
  return [
    ToolResult('面积', formatNumber(area), '', primary: true),
    ToolResult('周长', formatNumber(perimeter), ''),
    ToolResult('半周长', formatNumber(s), ''),
    ToolResult(
      '角 A/B/C',
      '${formatNumber(angleA)} / ${formatNumber(angleB)} / ${formatNumber(angleC)}',
      'deg',
    ),
    ToolResult('边长类型', type, ''),
    ToolResult('最长边', formatNumber(longest), ''),
    ToolResult('最短边', formatNumber(shortest), ''),
    ToolResult(
        '高 ha/hb/hc',
        '${formatNumber(heightA)} / ${formatNumber(heightB)} / ${formatNumber(heightC)}',
        ''),
    ToolResult('内切圆半径', formatNumber(inradius), ''),
    ToolResult('外接圆半径', formatNumber(circumradius), ''),
  ];
}

List<ToolResult> _invalidTriangleResults() {
  return const [
    ToolResult('面积', '无效', '', primary: true),
    ToolResult('周长', '无效', ''),
    ToolResult('半周长', '无效', ''),
    ToolResult('角 A/B/C', '无效', 'deg'),
    ToolResult('边长类型', '无效', ''),
    ToolResult('最长边', '无效', ''),
    ToolResult('最短边', '无效', ''),
    ToolResult('高 ha/hb/hc', '无效', ''),
    ToolResult('内切圆半径', '无效', ''),
    ToolResult('外接圆半径', '无效', ''),
  ];
}

double _triangleAngle({
  required double opposite,
  required double adjacent1,
  required double adjacent2,
}) {
  return math.acos(
        ((adjacent1 * adjacent1 + adjacent2 * adjacent2 - opposite * opposite) /
                (2 * adjacent1 * adjacent2))
            .clamp(-1.0, 1.0),
      ) *
      180 /
      math.pi;
}

String _triangleType(double a, double b, double c) {
  final sides = [a, b, c]..sort();
  final sideType = (a == b && b == c)
      ? '等边'
      : (a == b || a == c || b == c)
          ? '等腰'
          : '不等边';
  final squareCompare =
      sides[0] * sides[0] + sides[1] * sides[1] - sides[2] * sides[2];
  final angleType = squareCompare.abs() < 1e-9
      ? '直角'
      : squareCompare > 0
          ? '锐角'
          : '钝角';
  return '$sideType$angleType';
}

List<ToolResult> circleResults(Map<String, double> valuesByKey) {
  final radiusInput = valuesByKey['r'];
  final diameterInput = valuesByKey['diameter'];
  final circumferenceInput = valuesByKey['circumference'];
  final areaInput = valuesByKey['area'];
  final provided = [
    radiusInput,
    diameterInput,
    circumferenceInput,
    areaInput,
  ].where((value) => value != null).length;
  if (provided == 0 ||
      (radiusInput != null && (radiusInput < 0 || !radiusInput.isFinite)) ||
      (diameterInput != null &&
          (diameterInput < 0 || !diameterInput.isFinite)) ||
      (circumferenceInput != null &&
          (circumferenceInput < 0 || !circumferenceInput.isFinite)) ||
      (areaInput != null && (areaInput < 0 || !areaInput.isFinite))) {
    return _invalidCircleResults();
  }

  double radius;
  String source;
  if (radiusInput != null) {
    radius = radiusInput;
    source = provided == 1 ? '半径' : '半径，其他圆形量作参考';
  } else if (diameterInput != null) {
    radius = diameterInput / 2;
    source = provided == 1 ? '直径' : '直径，其他圆形量作参考';
  } else if (circumferenceInput != null) {
    radius = circumferenceInput / (2 * math.pi);
    source = provided == 1 ? '周长' : '周长，其他圆形量作参考';
  } else if (areaInput != null) {
    radius = math.sqrt(areaInput / math.pi);
    source = '面积';
  } else {
    return _invalidCircleResults();
  }
  if (!radius.isFinite) return _invalidCircleResults();

  final diameter = 2 * radius;
  final circumference = 2 * math.pi * radius;
  final area = math.pi * radius * radius;
  return [
    ToolResult('面积', formatNumber(area), '', primary: true),
    ToolResult('半径', formatNumber(radius), ''),
    ToolResult('直径', formatNumber(diameter), ''),
    ToolResult('周长', formatNumber(circumference), ''),
    ToolResult('半周长', formatNumber(circumference / 2), ''),
    ToolResult('单位半径面积', formatNumber(radius == 0 ? 0 : area / radius), ''),
    ToolResult('输入来源', source, ''),
    if (diameterInput != null && radiusInput != null)
      ToolResult('直径差值', formatNumber(diameter - diameterInput), ''),
    if (circumferenceInput != null &&
        (radiusInput != null || diameterInput != null))
      ToolResult('周长差值', formatNumber(circumference - circumferenceInput), ''),
    if (areaInput != null &&
        (radiusInput != null ||
            diameterInput != null ||
            circumferenceInput != null))
      ToolResult('面积差值', formatNumber(area - areaInput), ''),
  ];
}

List<ToolResult> _invalidCircleResults() {
  return const [
    ToolResult('面积', '无效', '', primary: true),
    ToolResult('半径', '无效', ''),
    ToolResult('直径', '无效', ''),
    ToolResult('周长', '无效', ''),
    ToolResult('半周长', '无效', ''),
    ToolResult('单位半径面积', '无效', ''),
    ToolResult('输入来源', '无效', ''),
  ];
}

List<ToolResult> scaleRatioResults(Map<String, double> valuesByKey) {
  final valueInput = valuesByKey['value'];
  final fromInput = valuesByKey['from'];
  final toInput = valuesByKey['to'];
  final scaledInput = valuesByKey['scaled'];
  final coreInputCount = [
    valueInput,
    fromInput,
    toInput,
    scaledInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 3 ||
      (valueInput != null && !valueInput.isFinite) ||
      (fromInput != null && (fromInput == 0 || !fromInput.isFinite)) ||
      (toInput != null && !toInput.isFinite) ||
      (scaledInput != null && !scaledInput.isFinite)) {
    return _invalidScaleRatioResults();
  }

  double value;
  double from;
  double to;
  double scaled;
  String source;
  double? scaledDelta;
  if (valueInput != null && fromInput != null && toInput != null) {
    value = valueInput;
    from = fromInput;
    to = toInput;
    scaled = value * to / from;
    scaledDelta = scaledInput == null ? null : scaled - scaledInput;
    source = scaledInput == null ? '原始值+原比例+目标比例' : '原始值+原比例+目标比例，目标值作参考';
  } else if (scaledInput != null && fromInput != null && toInput != null) {
    if (toInput == 0) return _invalidScaleRatioResults();
    scaled = scaledInput;
    from = fromInput;
    to = toInput;
    value = scaled * from / to;
    source = '缩放后+原比例+目标比例';
  } else if (scaledInput != null && valueInput != null && toInput != null) {
    if (scaledInput == 0) return _invalidScaleRatioResults();
    scaled = scaledInput;
    value = valueInput;
    to = toInput;
    from = value * to / scaled;
    if (from == 0) return _invalidScaleRatioResults();
    source = '缩放后+原始值+目标比例';
  } else if (scaledInput != null && valueInput != null && fromInput != null) {
    if (valueInput == 0) return _invalidScaleRatioResults();
    scaled = scaledInput;
    value = valueInput;
    from = fromInput;
    to = scaled * from / value;
    source = '缩放后+原始值+原比例';
  } else {
    return _invalidScaleRatioResults();
  }

  final ratio = to / from;
  return [
    ToolResult('缩放后', formatNumber(scaled), '', primary: true),
    ToolResult('原始值', formatNumber(value), ''),
    ToolResult('原比例', formatNumber(from), ''),
    ToolResult('目标比例', formatNumber(to), ''),
    ToolResult('缩放比例', formatNumber(ratio), 'x'),
    ToolResult('面积比例', formatNumber(math.pow(ratio, 2).toDouble()), 'x'),
    ToolResult('体积比例', formatNumber(math.pow(ratio, 3).toDouble()), 'x'),
    ToolResult('输入来源', source, ''),
    if (scaledDelta != null) ToolResult('缩放值差值', formatNumber(scaledDelta), ''),
  ];
}

List<ToolResult> _invalidScaleRatioResults() {
  return const [
    ToolResult('缩放后', '无效', '', primary: true),
    ToolResult('原始值', '无效', ''),
    ToolResult('原比例', '无效', ''),
    ToolResult('目标比例', '无效', ''),
    ToolResult('缩放比例', '无效', 'x'),
    ToolResult('面积比例', '无效', 'x'),
    ToolResult('体积比例', '无效', 'x'),
    ToolResult('输入来源', '无效', ''),
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

String _signedImag(double value) {
  final sign = value < 0 ? '-' : '+';
  return '$sign ${formatNumber(value.abs())}';
}
