import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';

enum FitModel {
  linear('线性', 'y = ax + b'),
  quadratic('二次', 'y = ax² + bx + c'),
  exponential('指数', 'y = A·e^(Bx)'),
  power('幂函数', 'y = A·x^B'),
  logarithmic('对数', 'y = a·ln(x) + b'),
  reciprocal('倒数', 'y = a / x + b');

  const FitModel(this.label, this.template);

  final String label;
  final String template;
}

class DataPoint {
  const DataPoint(this.x, this.y);

  final double x;
  final double y;
}

class DataSeries {
  const DataSeries({required this.name, required this.points});

  final String name;
  final List<DataPoint> points;
}

class FitResult {
  const FitResult({
    required this.model,
    required this.points,
    required this.coefficients,
    required this.equation,
    required this.rSquared,
    required this.rmse,
    required this.predictions,
  });

  final FitModel model;
  final List<DataPoint> points;
  final List<double> coefficients;
  final String equation;
  final double rSquared;
  final double rmse;
  final List<DataPoint> predictions;

  String get summary {
    return '${model.label}拟合\n$equation\nR²=${formatNumber(rSquared, precision: 6)}, RMSE=${formatNumber(rmse, precision: 6)}';
  }
}

List<DataPoint> parseDataPoints(String source) {
  final series = parseDataSeries(source);
  return series.isEmpty ? const [] : series.first.points;
}

List<DataSeries> parseDataSeries(String source) {
  final blocks = source
      .split(RegExp(r'(?:\r?\n\s*){2,}'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty)
      .toList();
  if (blocks.isEmpty) return const [];
  final series = <DataSeries>[];
  for (final block in blocks) {
    final parsed = _parseBlock(block, startIndex: series.length);
    series.addAll(parsed);
  }
  return series;
}

List<DataSeries> _parseBlock(String block, {required int startIndex}) {
  final rows = <List<double>>[];
  for (final rawLine in block.split(RegExp(r'[\r\n]+'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final matches = _numbers(line);
    if (matches.isNotEmpty) rows.add(matches);
  }
  if (rows.isEmpty) return const [];
  final maxColumns = rows.map((row) => row.length).reduce(math.max);
  if (maxColumns >= 3) {
    final series = <DataSeries>[];
    for (var column = 1; column < maxColumns; column++) {
      final points = <DataPoint>[];
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        if (row.length > column) points.add(DataPoint(row[0], row[column]));
      }
      if (points.isNotEmpty) {
        series.add(DataSeries(
          name: '数据 ${startIndex + series.length + 1}',
          points: points,
        ));
      }
    }
    return series;
  }

  final points = <DataPoint>[];
  var autoX = 1.0;
  for (final row in rows) {
    if (row.length >= 2) {
      points.add(DataPoint(row[0], row[1]));
    } else {
      points.add(DataPoint(autoX, row[0]));
    }
    autoX = points.length + 1.0;
  }
  return [
    DataSeries(name: '数据 ${startIndex + 1}', points: points),
  ];
}

List<double> _numbers(String line) {
  return RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
      .allMatches(line)
      .map((match) => double.tryParse(match.group(0)!))
      .whereType<double>()
      .toList();
}

FitResult fitData(List<DataPoint> points, FitModel model) {
  if (points.length < _minPoints(model)) {
    throw FormatException('${model.label}拟合至少需要 ${_minPoints(model)} 个点');
  }
  return switch (model) {
    FitModel.linear => _fitLinear(points),
    FitModel.quadratic => _fitQuadratic(points),
    FitModel.exponential => _fitExponential(points),
    FitModel.power => _fitPower(points),
    FitModel.logarithmic => _fitLogarithmic(points),
    FitModel.reciprocal => _fitReciprocal(points),
  };
}

int _minPoints(FitModel model) => model == FitModel.quadratic ? 3 : 2;

FitResult _fitLinear(List<DataPoint> points) {
  final n = points.length.toDouble();
  final sx = points.fold<double>(0, (sum, p) => sum + p.x);
  final sy = points.fold<double>(0, (sum, p) => sum + p.y);
  final sxx = points.fold<double>(0, (sum, p) => sum + p.x * p.x);
  final sxy = points.fold<double>(0, (sum, p) => sum + p.x * p.y);
  final denominator = n * sxx - sx * sx;
  if (denominator.abs() < 1e-12) {
    throw const FormatException('x 数据没有变化，无法做线性拟合');
  }
  final a = (n * sxy - sx * sy) / denominator;
  final b = (sy - a * sx) / n;
  return _buildResult(
    model: FitModel.linear,
    points: points,
    coefficients: [a, b],
    equation: 'y = ${formatNumber(a, precision: 6)}x ${_signedTerm(b)}',
    predict: (x) => a * x + b,
  );
}

FitResult _fitQuadratic(List<DataPoint> points) {
  final n = points.length.toDouble();
  var sx = 0.0, sx2 = 0.0, sx3 = 0.0, sx4 = 0.0;
  var sy = 0.0, sxy = 0.0, sx2y = 0.0;
  for (final p in points) {
    final x2 = p.x * p.x;
    sx += p.x;
    sx2 += x2;
    sx3 += x2 * p.x;
    sx4 += x2 * x2;
    sy += p.y;
    sxy += p.x * p.y;
    sx2y += x2 * p.y;
  }
  final solution = _solve3([
    [sx4, sx3, sx2],
    [sx3, sx2, sx],
    [sx2, sx, n],
  ], [
    sx2y,
    sxy,
    sy,
  ]);
  final a = solution[0], b = solution[1], c = solution[2];
  return _buildResult(
    model: FitModel.quadratic,
    points: points,
    coefficients: [a, b, c],
    equation:
        'y = ${formatNumber(a, precision: 6)}x² ${_signedTerm(b)}x ${_signedTerm(c)}',
    predict: (x) => a * x * x + b * x + c,
  );
}

FitResult _fitExponential(List<DataPoint> points) {
  final valid = points.where((p) => p.y > 0).toList();
  if (valid.length < 2) {
    throw const FormatException('指数拟合要求 y 全部为正数');
  }
  final transformed = valid.map((p) => DataPoint(p.x, math.log(p.y))).toList();
  final linear = _fitLinear(transformed);
  final b = linear.coefficients[0];
  final a = math.exp(linear.coefficients[1]);
  return _buildResult(
    model: FitModel.exponential,
    points: valid,
    coefficients: [a, b],
    equation:
        'y = ${formatNumber(a, precision: 6)}·e^(${formatNumber(b, precision: 6)}x)',
    predict: (x) => a * math.exp(b * x),
  );
}

FitResult _fitPower(List<DataPoint> points) {
  final valid = points.where((p) => p.x > 0 && p.y > 0).toList();
  if (valid.length < 2) {
    throw const FormatException('幂函数拟合要求 x 和 y 全部为正数');
  }
  final transformed =
      valid.map((p) => DataPoint(math.log(p.x), math.log(p.y))).toList();
  final linear = _fitLinear(transformed);
  final b = linear.coefficients[0];
  final a = math.exp(linear.coefficients[1]);
  return _buildResult(
    model: FitModel.power,
    points: valid,
    coefficients: [a, b],
    equation:
        'y = ${formatNumber(a, precision: 6)}·x^${formatNumber(b, precision: 6)}',
    predict: (x) => a * math.pow(x, b).toDouble(),
  );
}

FitResult _fitLogarithmic(List<DataPoint> points) {
  final valid = points.where((p) => p.x > 0).toList();
  if (valid.length < 2) {
    throw const FormatException('对数拟合要求 x 全部为正数');
  }
  // 中文：对数拟合把 x 映射到 ln(x)，再复用线性最小二乘，减少重复算法。
  // English: Logarithmic fitting maps x to ln(x) and reuses linear least squares.
  final transformed = valid.map((p) => DataPoint(math.log(p.x), p.y)).toList();
  final linear = _fitLinear(transformed);
  final a = linear.coefficients[0];
  final b = linear.coefficients[1];
  return _buildResult(
    model: FitModel.logarithmic,
    points: valid,
    coefficients: [a, b],
    equation: 'y = ${formatNumber(a, precision: 6)}·ln(x) ${_signedTerm(b)}',
    predict: (x) => a * math.log(x) + b,
  );
}

FitResult _fitReciprocal(List<DataPoint> points) {
  final valid = points.where((p) => p.x != 0).toList();
  if (valid.length < 2) {
    throw const FormatException('倒数拟合要求 x 不能为 0');
  }
  // 中文：倒数模型把 1/x 作为自变量，适合衰减、阻抗和反比例近似数据。
  // English: Reciprocal fitting uses 1/x as the variable for decay and inverse-proportion data.
  final transformed = valid.map((p) => DataPoint(1 / p.x, p.y)).toList();
  final linear = _fitLinear(transformed);
  final a = linear.coefficients[0];
  final b = linear.coefficients[1];
  return _buildResult(
    model: FitModel.reciprocal,
    points: valid,
    coefficients: [a, b],
    equation: 'y = ${formatNumber(a, precision: 6)} / x ${_signedTerm(b)}',
    predict: (x) => a / x + b,
  );
}

FitResult _buildResult({
  required FitModel model,
  required List<DataPoint> points,
  required List<double> coefficients,
  required String equation,
  required double Function(double x) predict,
}) {
  final predictions =
      points.map((point) => DataPoint(point.x, predict(point.x))).toList();
  final meanY = points.fold<double>(0, (sum, p) => sum + p.y) / points.length;
  var ssRes = 0.0;
  var ssTot = 0.0;
  for (var i = 0; i < points.length; i++) {
    final error = points[i].y - predictions[i].y;
    ssRes += error * error;
    final centered = points[i].y - meanY;
    ssTot += centered * centered;
  }
  final rSquared = ssTot.abs() < 1e-12 ? 1.0 : 1 - ssRes / ssTot;
  final rmse = math.sqrt(ssRes / points.length);
  return FitResult(
    model: model,
    points: points,
    coefficients: coefficients,
    equation: equation,
    rSquared: rSquared,
    rmse: rmse,
    predictions: predictions,
  );
}

List<double> _solve3(List<List<double>> matrix, List<double> values) {
  final a = [
    [...matrix[0], values[0]],
    [...matrix[1], values[1]],
    [...matrix[2], values[2]],
  ];
  for (var pivot = 0; pivot < 3; pivot++) {
    var best = pivot;
    for (var row = pivot + 1; row < 3; row++) {
      if (a[row][pivot].abs() > a[best][pivot].abs()) best = row;
    }
    if (a[best][pivot].abs() < 1e-12) {
      throw const FormatException('数据点无法确定唯一拟合曲线');
    }
    if (best != pivot) {
      final temp = a[pivot];
      a[pivot] = a[best];
      a[best] = temp;
    }
    final divisor = a[pivot][pivot];
    for (var col = pivot; col < 4; col++) {
      a[pivot][col] /= divisor;
    }
    for (var row = 0; row < 3; row++) {
      if (row == pivot) continue;
      final factor = a[row][pivot];
      for (var col = pivot; col < 4; col++) {
        a[row][col] -= factor * a[pivot][col];
      }
    }
  }
  return [a[0][3], a[1][3], a[2][3]];
}

String _signedTerm(double value) {
  final sign = value < 0 ? '-' : '+';
  return '$sign ${formatNumber(value.abs(), precision: 6)}';
}
