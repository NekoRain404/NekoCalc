part of 'data_fit.dart';

class DataFitPasteResult {
  const DataFitPasteResult({
    required this.data,
    required this.series,
    this.prediction,
    this.model,
    this.extractedFromReport = false,
  });

  factory DataFitPasteResult.empty() => const DataFitPasteResult(
        data: '',
        series: [],
      );

  final String data;
  final List<DataSeries> series;
  final String? prediction;
  final FitModel? model;
  final bool extractedFromReport;

  bool get hasData => series.isNotEmpty;

  int get totalPointCount =>
      series.fold<int>(0, (sum, item) => sum + item.points.length);

  /// 中文：粘贴后那条提示。**夹在中间的那个 ` · ` 是记号，两种语言一样**，所以留在领域层；
  ///       每一段本身走表。
  /// English: the snack bar shown after a paste. **The ` · ` between the parts is notation and is the
  ///          same in both languages**, so it stays in the domain; each part itself goes through the
  ///          table.
  String summaryIn(DataFitCopy copy) {
    if (!hasData) return copy.noRecognisedData;
    final parts = <String>[
      extractedFromReport ? copy.fromReport : copy.fromDirectData,
      copy.seriesCount(series.length),
      copy.points(totalPointCount),
    ];
    if (model != null) {
      parts.add(copy.modelSummary(fitModelLabelIn(copy, model!)));
    }
    if (prediction != null && prediction!.trim().isNotEmpty) {
      parts.add(copy.predictionSummary(prediction!));
    }
    return parts.join(' · ');
  }
}

/// 中文：`copy` 必填（没有中文兜底，理由见 `data_fit_copy.dart` 文件头）：摘要那句提示是按当前
///       语言写的。**识别那一路不吃 `copy`**——报告可能是另一种语言下复制出来的，
///       所以模型名三种拼法都认（见 `_extractPastedFitModel`）。
/// English: `copy` is required (no Chinese fallback; the reason is on `data_fit_copy.dart`'s head):
///          the summary line is written in the active language. **Recognition does not take
///          `copy`** — a report may have been copied under the other language, so model names are
///          accepted in all three spellings (see `_extractPastedFitModel`).
DataFitPasteResult parseDataFitPasteText(
  String input, {
  required DataFitCopy copy,
}) {
  final normalized = input.trim();
  if (normalized.isEmpty) return DataFitPasteResult.empty();

  final reportData = _extractPastedFitDataBlock(normalized);
  if (reportData != null) {
    final reportSeries = parseDataSeries(reportData, copy: copy);
    if (reportSeries.isNotEmpty) {
      return DataFitPasteResult(
        data: reportData,
        series: reportSeries,
        prediction: _extractPastedFitPrediction(normalized),
        model: _extractPastedFitModel(normalized),
        extractedFromReport: true,
      );
    }
  }

  final directSeries = parseDataSeries(normalized, copy: copy);
  if (directSeries.isNotEmpty) {
    return DataFitPasteResult(
      data: normalized,
      series: directSeries,
      prediction: _extractPastedFitPrediction(normalized),
      model: _extractPastedFitModel(normalized),
    );
  }

  return DataFitPasteResult.empty();
}

String? _extractPastedFitDataBlock(String input) {
  final lines = const LineSplitter().convert(input);
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trim();
    if (!_isPastedFitDataMarker(line)) continue;
    final block = lines
        .skip(index + 1)
        .takeWhile((line) => !_isPastedFitSectionBoundary(line))
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .join('\n')
        .trim();
    if (block.isNotEmpty) return block;
  }
  return null;
}

bool _isPastedFitDataMarker(String line) {
  final normalized = line.trim().replaceAll(RegExp(r'[:：]+$'), '');
  return const {
    '数据',
    '原始数据',
    '样本数据',
    'data',
    'raw data',
    'dataset',
  }.contains(normalized.toLowerCase());
}

bool _isPastedFitSectionBoundary(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  if (_isPastedFitDataMarker(trimmed)) return false;
  final normalized = trimmed.replaceAll(RegExp(r'[:：]+$'), '').toLowerCase();
  if (const {
    '模型建议',
    '诊断',
    '疑似异常点',
    '预测',
    '公式',
    '结果',
    '计算结果',
    'model suggestions',
    'diagnostics',
    'outliers',
    'prediction',
    'result',
  }.contains(normalized)) {
    return true;
  }
  if (_extractPastedFitModel(trimmed) != null) return true;
  return false;
}

String? _extractPastedFitPrediction(String input) {
  final patterns = [
    RegExp(
      r'预测\s*[:：]\s*x\s*=\s*([^,，\s]+)',
      caseSensitive: false,
    ),
    RegExp(
      r'prediction\s*[:：]\s*x\s*=\s*([^,，\s]+)',
      caseSensitive: false,
    ),
    RegExp(
      r'预测\s*x\s*[:：=]\s*([^,，\s]+)',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(input);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) continue;
    if (parseFitNumber(value) != null) return value;
  }
  return null;
}

/// 中文：**模型名在两种语言里都要认。** 报告可能是中文界面下复制出来的、在英文界面下粘回来
///       （或反过来），所以三种拼法都算数：本表 `zh` 的名字、`en` 的名字、以及枚举名
///       （`linear` / `quadratic`…，它同时是草稿里存的令牌）。**识别是"读用户粘进来的文本"，
///       不是文案**，所以它不像显示那样跟着当前语言走。
///       **行为与搬家前逐字节相同**：以前认的是 `model.label`（就是 `zh` 那一列）加
///       `model.name`；`en` 那一列去掉大小写后与 `model.name` 相同，认不出别的词。
/// English: **model names are recognised in both languages.** A report copied under the Chinese
///          interface may be pasted back under the English one (or the other way round), so all three
///          spellings count: this table's `zh` names, its `en` names, and the enum name (`linear`,
///          `quadratic`, …, which is also the token the draft persists). **Recognition reads the text
///          the user pasted; it is not copy**, so unlike display it does not follow the active
///          language. **The behaviour is byte-identical to before the move**: it used to accept
///          `model.label` (which is the `zh` column) plus `model.name`, and the `en` column
///          lower-cased equals `model.name`, so no extra word can match.
Iterable<String> _modelSpellings(FitModel model) sync* {
  yield fitModelLabelIn(DataFitCopy.zh, model);
  yield fitModelLabelIn(DataFitCopy.en, model);
  yield model.name;
}

FitModel? _extractPastedFitModel(String input) {
  final normalized = input.toLowerCase();
  for (final model in FitModel.values) {
    for (final spelling in _modelSpellings(model)) {
      if (normalized.contains(spelling.toLowerCase())) return model;
    }
  }
  if (normalized.contains('quadratic') ||
      normalized.contains('polynomial') ||
      normalized.contains('x²') ||
      normalized.contains('x^2')) {
    return FitModel.quadratic;
  }
  if (normalized.contains('linear')) return FitModel.linear;
  if (normalized.contains('exponential')) return FitModel.exponential;
  if (normalized.contains('power')) return FitModel.power;
  if (normalized.contains('logarithmic')) return FitModel.logarithmic;
  if (normalized.contains('reciprocal')) return FitModel.reciprocal;
  return null;
}
