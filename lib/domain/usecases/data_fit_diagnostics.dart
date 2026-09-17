import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import 'data_fit_models.dart';

List<String> buildFitDiagnostics(FitResult result) {
  final lines = <String>[];
  final residuals = _fitResiduals(result);
  final maxResidual = residuals.map((value) => value.abs()).reduce(math.max);
  final maxResidualIndex =
      residuals.indexWhere((value) => value.abs() == maxResidual);
  final meanY = result.points.fold<double>(0, (sum, point) => sum + point.y) /
      result.points.length;
  final meanAbsY = result.points
          .fold<double>(0, (sum, point) => sum + (point.y - meanY).abs()) /
      result.points.length;
  final relativeRmse = meanAbsY.abs() < 1e-12 ? 0.0 : result.rmse / meanAbsY;

  if (result.rSquared >= 0.995) {
    lines.add('拟合度很高，R² 接近 1。');
  } else if (result.rSquared >= 0.95) {
    lines.add('拟合度较好，建议仍检查残差分布。');
  } else if (result.rSquared >= 0.8) {
    lines.add('拟合度一般，可能需要换模型或分段拟合。');
  } else {
    lines.add('拟合度偏低，当前模型可能不适合这组数据。');
  }

  if (relativeRmse > 0.35) {
    lines.add('RMSE 相对波动较大，预测误差需要谨慎使用。');
  } else if (relativeRmse > 0.18) {
    lines.add('RMSE 中等，适合粗略估算，不适合高精度外推。');
  } else {
    lines.add('RMSE 相对较小，样本范围内预测更稳定。');
  }

  if (maxResidualIndex >= 0) {
    final point = result.points[maxResidualIndex];
    lines.add(
      '最大残差出现在第 ${maxResidualIndex + 1} 行：x=${formatNumber(point.x, precision: 6)}, '
      '残差=${formatNumber(residuals[maxResidualIndex], precision: 6)}。',
    );
  }

  if (_hasResidualRuns(residuals)) {
    lines.add('残差连续同号较多，可能存在系统性偏差。');
  }
  if (_isEdgeHeavyResidual(residuals)) {
    lines.add('首尾残差偏大，外推时建议降低置信度。');
  }
  final alerts = buildFitResidualAlerts(result);
  if (alerts.isNotEmpty) {
    lines.add('疑似异常点：${alerts.map((item) => item.label).join('；')}。');
  }
  return lines;
}

List<FitResidualPoint> buildFitResidualAlerts(
  FitResult result, {
  int limit = 3,
}) {
  final residuals = _fitResiduals(result);
  if (residuals.length < 4 || result.rmse < 1e-12) return const [];
  final meanAbsResidual =
      residuals.fold<double>(0, (sum, value) => sum + value.abs()) /
          residuals.length;
  final threshold = math.max(result.rmse * 2, meanAbsResidual * 3);
  if (threshold < 1e-12) return const [];
  final alerts = <FitResidualPoint>[];
  for (var i = 0; i < residuals.length; i++) {
    final residual = residuals[i];
    final severity = residual.abs() / threshold;
    if (severity < 1) continue;
    alerts.add(FitResidualPoint(
      index: i,
      point: result.points[i],
      predicted: result.predictions[i].y,
      residual: residual,
      severity: severity,
    ));
  }
  alerts.sort((a, b) {
    final severityOrder = b.severity.compareTo(a.severity);
    if (severityOrder != 0) return severityOrder;
    return a.index.compareTo(b.index);
  });
  final normalizedLimit = limit <= 0 ? alerts.length : limit;
  return alerts.take(normalizedLimit).toList(growable: false);
}

List<double> _fitResiduals(FitResult result) {
  return [
    for (var i = 0; i < result.points.length; i++)
      result.points[i].y - result.predictions[i].y,
  ];
}

bool _hasResidualRuns(List<double> residuals) {
  if (residuals.length < 5) return false;
  var run = 0;
  var previousSign = 0;
  for (final residual in residuals) {
    final sign = residual.abs() < 1e-9 ? 0 : residual.sign.toInt();
    if (sign == 0) {
      run = 0;
      previousSign = 0;
      continue;
    }
    if (sign == previousSign) {
      run++;
    } else {
      run = 1;
      previousSign = sign;
    }
    if (run >= 3) return true;
  }
  return false;
}

bool _isEdgeHeavyResidual(List<double> residuals) {
  if (residuals.length < 5) return false;
  final absResiduals = residuals.map((value) => value.abs()).toList();
  final mean = absResiduals.fold<double>(0, (sum, value) => sum + value) /
      absResiduals.length;
  if (mean < 1e-12) return false;
  final edgeMean = (absResiduals.first + absResiduals.last) / 2;
  return edgeMean > mean * 1.6;
}
