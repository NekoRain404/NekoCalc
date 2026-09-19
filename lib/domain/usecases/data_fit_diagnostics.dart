import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import 'data_fit_copy.dart';
import 'data_fit_models.dart';

/// 中文：**每一句都走表**，`copy` 是必填的（没有中文兜底，理由写在 `data_fit_copy.dart` 文件头）。
///       阈值与判据（`0.995` / `0.95` / `0.8`、`0.35` / `0.18`、`_hasResidualRuns` 的 5 与 3、
///       `_isEdgeHeavyResidual` 的 1.6）一个字没动——本轮只搬字。
/// English: **every sentence goes through the table**, and `copy` is required (no Chinese fallback;
///          the reason is in `data_fit_copy.dart`'s head). The thresholds and criteria (`0.995` /
///          `0.95` / `0.8`, `0.35` / `0.18`, `_hasResidualRuns`'s 5 and 3, `_isEdgeHeavyResidual`'s
///          1.6) are untouched — this round moves words only.
List<String> buildFitDiagnostics(
  FitResult result, {
  required DataFitCopy copy,
}) {
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
    lines.add(copy.fitQualityVeryHigh);
  } else if (result.rSquared >= 0.95) {
    lines.add(copy.fitQualityGood);
  } else if (result.rSquared >= 0.8) {
    lines.add(copy.fitQualityFair);
  } else {
    lines.add(copy.fitQualityLow);
  }

  if (relativeRmse > 0.35) {
    lines.add(copy.rmseHigh);
  } else if (relativeRmse > 0.18) {
    lines.add(copy.rmseMedium);
  } else {
    lines.add(copy.rmseLow);
  }

  if (maxResidualIndex >= 0) {
    final point = result.points[maxResidualIndex];
    lines.add(copy.maxResidual(
      maxResidualIndex + 1,
      formatNumber(point.x, precision: 6),
      formatNumber(residuals[maxResidualIndex], precision: 6),
    ));
  }

  if (_hasResidualRuns(residuals)) {
    lines.add(copy.residualRun);
  }
  if (_isEdgeHeavyResidual(residuals)) {
    lines.add(copy.edgeHeavyResidual);
  }
  final alerts = buildFitResidualAlerts(result);
  if (alerts.isNotEmpty) {
    lines.add(copy.outliers([
      for (final item in alerts) item.labelIn(copy),
    ]));
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
