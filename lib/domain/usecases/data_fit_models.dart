import 'dart:convert';
import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import 'data_fit_copy.dart';

/// 中文：六种拟合模型。**枚举里只剩下"令牌 + 记号"，字在表里。**
///
///       - `name`（枚举名，`linear` / `quadratic`…）是**令牌**：它写进草稿
///         （`encodeDataFitDraft` 存的是 `draft.model.name`）、认报告时也拿它比，
///         两种语言下都不变。
///       - `template`（`y = ax + b`）是**记号不是文案**，留在领域层：两边的写法本来一样。
///       - **`label` 这一格本轮搬去 `DataFitCopy`**（原来是 `线性` / `二次` / …）。
///         分派在 [fitModelLabelIn]，一个**穷尽 `switch`**——加一个模型，那里编译不过，
///         不会静默掉回某个默认名字。
/// English: the six fit models. **Only the token and the notation stay on the enum; the words moved
///          to the table.**
///
///          - `name` (the enum name: `linear`, `quadratic`, …) is the **token**: the draft persists
///            it (`encodeDataFitDraft` writes `draft.model.name`) and report recognition compares
///            against it, and it is the same in both languages.
///          - `template` (`y = ax + b`) is **notation, not copy**, and stays in the domain: the two
///            languages write it identically.
///          - **The `label` slot moved to `DataFitCopy` this round** (it used to hold `线性` /
///            `二次` / …). Dispatch happens in [fitModelLabelIn], an **exhaustive `switch`**: adding
///            a model breaks the build there instead of quietly falling back to some default name.
enum FitModel {
  linear('y = ax + b'),
  quadratic('y = ax² + bx + c'),
  exponential('y = A·e^(Bx)'),
  power('y = A·x^B'),
  logarithmic('y = a·ln(x) + b'),
  reciprocal('y = a / x + b');

  const FitModel(this.template);

  final String template;
}

/// 中文：模型 → 表里那一格。**穷尽 `switch`，没有 `default`**——这正是它存在的理由。
/// English: model → the table's slot. **An exhaustive `switch` with no `default`** — which is
///          exactly why it exists.
String fitModelLabelIn(DataFitCopy copy, FitModel model) {
  return switch (model) {
    FitModel.linear => copy.modelLinear,
    FitModel.quadratic => copy.modelQuadratic,
    FitModel.exponential => copy.modelExponential,
    FitModel.power => copy.modelPower,
    FitModel.logarithmic => copy.modelLogarithmic,
    FitModel.reciprocal => copy.modelReciprocal,
  };
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

  /// 中文：结论正文，复制 / 落库 / 粘贴回读都用它。标题那半句走表（`copy.fitOf`），
  ///       `\n` 与 `R²=` / `RMSE=` 是记号，留在领域层。
  /// English: the conclusion body, used by copy, persist and paste-back alike. The heading half comes
  ///          from the table (`copy.fitOf`); the `\n` and `R²=` / `RMSE=` are notation and stay in
  ///          the domain.
  String summaryIn(DataFitCopy copy) {
    return '${copy.fitOf(fitModelLabelIn(copy, model))}\n$equation\n'
        'R²=${formatNumber(rSquared, precision: 6)}, RMSE=${formatNumber(rmse, precision: 6)}';
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

  /// 中文：一行异常点。`第 N 行` 与 `残差=` 走表（`copy.residualRow`），四个数在这里用
  ///       `precision: 6` 格式化——精度是记号的一部分，两种语言一样。
  /// English: one outlier row. `第 N 行` and `残差=` come from the table (`copy.residualRow`), while
  ///          the four numbers are formatted here with `precision: 6` — the precision is part of the
  ///          notation and is the same in both languages.
  String labelIn(DataFitCopy copy) {
    return copy.residualRow(
      index + 1,
      formatNumber(point.x, precision: 6),
      formatNumber(point.y, precision: 6),
      formatNumber(predicted, precision: 6),
      formatNumber(residual, precision: 6),
    );
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
