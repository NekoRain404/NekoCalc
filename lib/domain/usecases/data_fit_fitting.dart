import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import 'data_fit_copy.dart';
import 'data_fit_models.dart';

/// 中文：**`copy` 是必填的**，它只为一件事而来：拟合失败时抛出的那句话是给用户看的
///       （`_recalculate` 把它显示在空态面板上，`recommendFitModels` 把它存进
///       `FitRecommendation.warning`），所以要按当前语言写。数学一行没动，
///       只有这句文案的来源变了。
///
///       **没有换掉 `FormatException` 去自造一个异常类型**：屏幕那边
///       （`data_fit_tool_screen.dart`）抓的是 `error.toString().replaceFirst('FormatException: ', '')`，
///       换类型就得连那条通路一起改，而那条通路今天是对的。
/// English: **`copy` is required** and it is here for one thing only: the sentence a failed fit
///          throws is read by the user (`_recalculate` shows it in the empty-state panel and
///          `recommendFitModels` stores it as `FitRecommendation.warning`), so it has to be written
///          in the active language. Not one line of the mathematics moved; only the source of that
///          sentence did.
///
///          **`FormatException` was kept rather than replaced with a bespoke type**: the screen
///          (`data_fit_tool_screen.dart`) catches it as
///          `error.toString().replaceFirst('FormatException: ', '')`, so a new type would mean
///          rewriting that path too — and that path is correct today.
FitResult fitData(
  List<DataPoint> points,
  FitModel model, {
  required DataFitCopy copy,
}) {
  if (points.length < _minPoints(model)) {
    throw FormatException(
        copy.modelNeedsPoints(fitModelLabelIn(copy, model), _minPoints(model)));
  }
  return switch (model) {
    FitModel.linear => _fitLinear(points, copy),
    FitModel.quadratic => _fitQuadratic(points, copy),
    FitModel.exponential => _fitExponential(points, copy),
    FitModel.power => _fitPower(points, copy),
    FitModel.logarithmic => _fitLogarithmic(points, copy),
    FitModel.reciprocal => _fitReciprocal(points, copy),
  };
}

double predictFitValue(FitResult result, double x) {
  final c = result.coefficients;
  return switch (result.model) {
    FitModel.linear => c[0] * x + c[1],
    FitModel.quadratic => c[0] * x * x + c[1] * x + c[2],
    FitModel.exponential => c[0] * math.exp(c[1] * x),
    FitModel.power => x <= 0 ? double.nan : c[0] * math.pow(x, c[1]).toDouble(),
    FitModel.logarithmic => x <= 0 ? double.nan : c[0] * math.log(x) + c[1],
    FitModel.reciprocal => x == 0 ? double.nan : c[0] / x + c[1],
  };
}

List<FitRecommendation> recommendFitModels(
  List<DataPoint> points, {
  required DataFitCopy copy,
}) {
  final recommendations = <FitRecommendation>[];
  for (final model in FitModel.values) {
    try {
      recommendations.add(FitRecommendation(
        model: model,
        result: fitData(points, model, copy: copy),
        available: true,
      ));
    } catch (error) {
      recommendations.add(FitRecommendation(
        model: model,
        result: null,
        available: false,
        warning: error.toString().replaceFirst('FormatException: ', ''),
      ));
    }
  }
  recommendations.sort((a, b) {
    if (a.available != b.available) return a.available ? -1 : 1;
    final left = a.result;
    final right = b.result;
    if (left == null || right == null) {
      return a.model.index.compareTo(b.model.index);
    }
    final rOrder = right.rSquared.compareTo(left.rSquared);
    if (rOrder != 0) return rOrder;
    final rmseOrder = left.rmse.compareTo(right.rmse);
    if (rmseOrder != 0) return rmseOrder;
    return left.model.index.compareTo(right.model.index);
  });
  return recommendations;
}

int _minPoints(FitModel model) => model == FitModel.quadratic ? 3 : 2;

FitResult _fitLinear(List<DataPoint> points, DataFitCopy copy) {
  final n = points.length.toDouble();
  final sx = points.fold<double>(0, (sum, p) => sum + p.x);
  final sy = points.fold<double>(0, (sum, p) => sum + p.y);
  final sxx = points.fold<double>(0, (sum, p) => sum + p.x * p.x);
  final sxy = points.fold<double>(0, (sum, p) => sum + p.x * p.y);
  final denominator = n * sxx - sx * sx;
  if (denominator.abs() < 1e-12) {
    throw FormatException(copy.xHasNoVariation);
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

FitResult _fitQuadratic(List<DataPoint> points, DataFitCopy copy) {
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
  final solution = _solve3(copy, [
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

FitResult _fitExponential(List<DataPoint> points, DataFitCopy copy) {
  final valid = points.where((p) => p.y > 0).toList();
  if (valid.length < 2) {
    throw FormatException(copy.exponentialNeedsPositiveY);
  }
  final transformed = valid.map((p) => DataPoint(p.x, math.log(p.y))).toList();
  final linear = _fitLinear(transformed, copy);
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

FitResult _fitPower(List<DataPoint> points, DataFitCopy copy) {
  final valid = points.where((p) => p.x > 0 && p.y > 0).toList();
  if (valid.length < 2) {
    throw FormatException(copy.powerNeedsPositiveXY);
  }
  final transformed =
      valid.map((p) => DataPoint(math.log(p.x), math.log(p.y))).toList();
  final linear = _fitLinear(transformed, copy);
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

FitResult _fitLogarithmic(List<DataPoint> points, DataFitCopy copy) {
  final valid = points.where((p) => p.x > 0).toList();
  if (valid.length < 2) {
    throw FormatException(copy.logarithmicNeedsPositiveX);
  }
  // 中文：对数拟合把 x 映射到 ln(x)，再复用线性最小二乘，减少重复算法。
  // English: Logarithmic fitting maps x to ln(x) and reuses linear least squares.
  final transformed = valid.map((p) => DataPoint(math.log(p.x), p.y)).toList();
  final linear = _fitLinear(transformed, copy);
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

FitResult _fitReciprocal(List<DataPoint> points, DataFitCopy copy) {
  final valid = points.where((p) => p.x != 0).toList();
  if (valid.length < 2) {
    throw FormatException(copy.reciprocalNeedsNonZeroX);
  }
  // 中文：倒数模型把 1/x 作为自变量，适合衰减、阻抗和反比例近似数据。
  // English: Reciprocal fitting uses 1/x as the variable for decay and inverse-proportion data.
  final transformed = valid.map((p) => DataPoint(1 / p.x, p.y)).toList();
  final linear = _fitLinear(transformed, copy);
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

List<double> _solve3(
  DataFitCopy copy,
  List<List<double>> matrix,
  List<double> values,
) {
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
      throw FormatException(copy.noUniqueCurve);
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
