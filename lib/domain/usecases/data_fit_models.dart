import 'dart:convert';
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

class FitRecommendation {
  const FitRecommendation({
    required this.model,
    required this.result,
    required this.available,
    this.warning,
  });

  final FitModel model;
  final FitResult? result;
  final bool available;
  final String? warning;
}

class FitResidualPoint {
  const FitResidualPoint({
    required this.index,
    required this.point,
    required this.predicted,
    required this.residual,
    required this.severity,
  });

  final int index;
  final DataPoint point;
  final double predicted;
  final double residual;
  final double severity;

  String get label {
    return '第 ${index + 1} 行 x=${formatNumber(point.x, precision: 6)}, '
        'y=${formatNumber(point.y, precision: 6)}, '
        'ŷ=${formatNumber(predicted, precision: 6)}, '
        '残差=${formatNumber(residual, precision: 6)}';
  }
}

class DataFitDraft {
  const DataFitDraft({
    required this.toolId,
    required this.data,
    required this.prediction,
    required this.model,
    required this.selectedSeriesIndex,
  });

  final String toolId;
  final String data;
  final String prediction;
  final FitModel model;
  final int selectedSeriesIndex;
}

String dataFitDraftSettingKey(String toolId) => 'data_fit_draft_$toolId';

String encodeDataFitDraft(DataFitDraft draft) {
  return jsonEncode({
    'version': 1,
    'toolId': draft.toolId,
    'data': draft.data,
    'prediction': draft.prediction,
    'model': draft.model.name,
    'selectedSeriesIndex': draft.selectedSeriesIndex,
  });
}

DataFitDraft? decodeDataFitDraft({
  required String toolId,
  required String? raw,
  int? seriesCount,
}) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['toolId'] != toolId) return null;
    final model = _fitModelByName(decoded['model']);
    if (model == null) return null;

    final rawIndex = decoded['selectedSeriesIndex'];
    final parsedIndex =
        rawIndex is num && rawIndex.isFinite ? rawIndex.toInt() : 0;
    final selectedSeriesIndex = _clampDraftSeriesIndex(
      parsedIndex,
      seriesCount: seriesCount,
    );

    return DataFitDraft(
      toolId: toolId,
      data: decoded['data'] is String ? decoded['data'] as String : '',
      prediction: decoded['prediction'] is String
          ? decoded['prediction'] as String
          : '',
      model: model,
      selectedSeriesIndex: selectedSeriesIndex,
    );
  } catch (_) {
    return null;
  }
}

FitModel? _fitModelByName(Object? value) {
  if (value == null) return FitModel.linear;
  if (value is! String) return null;
  for (final model in FitModel.values) {
    if (model.name == value) return model;
  }
  return null;
}

int _clampDraftSeriesIndex(int value, {int? seriesCount}) {
  if (seriesCount != null && seriesCount > 0) {
    return value.clamp(0, seriesCount - 1).toInt();
  }
  return math.max(0, value);
}
