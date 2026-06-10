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

  String get summary {
    if (!hasData) return '剪贴板里没有识别到可拟合数据';
    final parts = <String>[
      extractedFromReport ? '已从报告提取数据' : '已粘贴数据',
      '${series.length} 组',
      '$totalPointCount 点',
    ];
    if (model != null) parts.add('模型 ${model!.label}');
    if (prediction != null && prediction!.trim().isNotEmpty) {
      parts.add('预测 x=$prediction');
    }
    return parts.join(' · ');
  }
}

DataFitPasteResult parseDataFitPasteText(String input) {
  final normalized = input.trim();
  if (normalized.isEmpty) return DataFitPasteResult.empty();

  final reportData = _extractPastedFitDataBlock(normalized);
  if (reportData != null) {
    final reportSeries = parseDataSeries(reportData);
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

  final directSeries = parseDataSeries(normalized);
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

FitModel? _extractPastedFitModel(String input) {
  final normalized = input.toLowerCase();
  for (final model in FitModel.values) {
    if (normalized.contains(model.label.toLowerCase()) ||
        normalized.contains(model.name.toLowerCase())) {
      return model;
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
