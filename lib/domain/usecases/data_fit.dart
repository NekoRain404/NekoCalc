import 'dart:convert';
import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';

part 'data_fit_paste.dart';

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

List<DataPoint> parseDataPoints(String source) {
  final series = parseDataSeries(source);
  return series.isEmpty ? const [] : series.first.points;
}

double? parseFitNumber(String source) {
  final values = _numbers(source.trim());
  return values.length == 1 ? values.single : null;
}

List<DataSeries> parseDataSeries(String source) {
  final jsonSeries = _tryParseJsonDataSeries(source);
  if (jsonSeries != null) return jsonSeries;

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

List<DataSeries>? _tryParseJsonDataSeries(String source) {
  final trimmed = source.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
  try {
    final decoded = json.decode(trimmed);
    final series = _seriesFromJsonValue(decoded, startIndex: 0);
    return series.isEmpty ? null : series;
  } catch (_) {
    final jsonLines = _tryParseJsonLineValues(trimmed);
    if (jsonLines == null) return null;
    final series = _seriesFromJsonValue(jsonLines, startIndex: 0);
    return series.isEmpty ? null : series;
  }
}

List<Object?>? _tryParseJsonLineValues(String source) {
  final lines = const LineSplitter()
      .convert(source)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length < 2) return null;

  final values = <Object?>[];
  for (final line in lines) {
    try {
      values.add(json.decode(line));
    } catch (_) {
      return null;
    }
  }
  return values;
}

List<DataSeries> _seriesFromJsonValue(Object? value,
    {required int startIndex}) {
  if (value is Map) {
    final seriesValue = _firstJsonValue(value, const ['series', 'datasets']);
    if (seriesValue != null) {
      return _seriesFromJsonValue(seriesValue, startIndex: startIndex);
    }
    final pointsValue =
        _firstJsonValue(value, const ['points', 'data', 'values']);
    if (pointsValue != null) {
      final points = _pointsFromJsonList(pointsValue);
      if (points.isEmpty) return const [];
      return [
        DataSeries(
          name: _jsonString(value['name']) ?? '数据 ${startIndex + 1}',
          points: points,
        ),
      ];
    }
    final columnSeries =
        _seriesFromColumnJsonMap(value, startIndex: startIndex);
    if (columnSeries.isNotEmpty) return columnSeries;
    final points = _pointsFromJsonList(value);
    if (points.isEmpty) return const [];
    return [
      DataSeries(name: '数据 ${startIndex + 1}', points: points),
    ];
  }
  if (value is List) {
    if (value.isEmpty) return const [];
    final nestedSeries = <DataSeries>[];
    for (final item in value) {
      if (item is Map &&
          (_firstJsonValue(item, const ['points', 'data', 'values']) != null ||
              _jsonString(item['name']) != null)) {
        nestedSeries.addAll(
          _seriesFromJsonValue(item,
              startIndex: startIndex + nestedSeries.length),
        );
      }
    }
    if (nestedSeries.isNotEmpty) return nestedSeries;

    final rowSeries = _seriesFromRowJsonList(value, startIndex: startIndex);
    if (rowSeries.isNotEmpty) return rowSeries;

    final points = _pointsFromJsonList(value);
    if (points.isEmpty) return const [];
    return [
      DataSeries(name: '数据 ${startIndex + 1}', points: points),
    ];
  }
  return const [];
}

Object? _firstJsonValue(Map value, List<String> keys) {
  for (final entry in value.entries) {
    final key = entry.key.toString().toLowerCase();
    if (keys.contains(key)) return entry.value;
  }
  return null;
}

List<DataSeries> _seriesFromRowJsonList(List value, {required int startIndex}) {
  final rows = <Map<String, double>>[];
  final columns = <String>{};
  for (final item in value) {
    if (item is! Map) return const [];
    final row = <String, double>{};
    for (final entry in item.entries) {
      final key = entry.key.toString().trim();
      final number = _jsonScalarNumber(entry.value);
      if (key.isEmpty || number == null) continue;
      row[key] = number;
      columns.add(key);
    }
    if (row.isNotEmpty) rows.add(row);
  }
  if (rows.length < 2 || columns.length < 2) return const [];

  String? xKey;
  for (final column in columns) {
    if (_isJsonXColumn(column)) {
      xKey = column;
      break;
    }
  }
  if (xKey == null && columns.length == 2) {
    return const [];
  }

  final yKeys = columns.where((key) => key != xKey).toList();
  if (yKeys.isEmpty) return const [];

  final series = <DataSeries>[];
  for (final yKey in yKeys) {
    final points = <DataPoint>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final y = row[yKey];
      if (y == null) continue;
      final x = xKey == null ? rowIndex + 1.0 : row[xKey];
      if (x == null) continue;
      points.add(DataPoint(x, y));
    }
    if (points.isNotEmpty) {
      series.add(DataSeries(
        name: yKey,
        points: points,
      ));
    }
  }
  return series;
}

double? _jsonScalarNumber(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalized = _normalizeNumberText(value.trim());
    if (normalized.isEmpty) return null;
    return _parseNumberToken(normalized);
  }
  return null;
}

List<DataPoint> _pointsFromJsonList(Object? value) {
  if (value is! List) return const [];
  final points = <DataPoint>[];
  var autoX = 1.0;
  for (final item in value) {
    final point = _pointFromJsonValue(item, autoX: autoX);
    if (point == null) continue;
    points.add(point);
    autoX = points.length + 1.0;
  }
  return points;
}

DataPoint? _pointFromJsonValue(Object? value, {required double autoX}) {
  final scalar = _jsonScalarNumber(value);
  if (scalar != null) return DataPoint(autoX, scalar);
  if (value is List) {
    final values = value
        .map(_jsonScalarNumber)
        .whereType<double>()
        .toList(growable: false);
    if (values.length >= 2) return DataPoint(values[0], values[1]);
    if (values.length == 1) return DataPoint(autoX, values[0]);
    return null;
  }
  if (value is Map) {
    final x = _jsonNumber(value, const ['x', 'time', 't']);
    final y = _jsonNumber(value, const ['y', 'value', 'v']);
    if (x != null && y != null) return DataPoint(x, y);
    final numbers =
        value.values.map(_jsonScalarNumber).whereType<double>().toList();
    if (numbers.length >= 2) return DataPoint(numbers[0], numbers[1]);
    if (numbers.length == 1) return DataPoint(autoX, numbers[0]);
  }
  return null;
}

double? _jsonNumber(Map value, List<String> keys) {
  for (final entry in value.entries) {
    final key = entry.key.toString().toLowerCase();
    if (!keys.contains(key)) continue;
    final candidate = _jsonScalarNumber(entry.value);
    if (candidate != null) return candidate;
  }
  return null;
}

List<DataSeries> _seriesFromColumnJsonMap(Map value,
    {required int startIndex}) {
  final columns = <String, List<double>>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) continue;
    final numbers = _jsonNumberList(entry.value);
    if (numbers.isNotEmpty) columns[key] = numbers;
  }
  if (columns.isEmpty) return const [];

  String? xKey;
  List<double>? xValues;
  for (final entry in columns.entries) {
    if (_isJsonXColumn(entry.key)) {
      xKey = entry.key;
      xValues = entry.value;
      break;
    }
  }

  final yColumns = columns.entries
      .where((entry) => entry.key != xKey)
      .where((entry) => entry.value.isNotEmpty)
      .toList();
  if (yColumns.isEmpty) return const [];

  final series = <DataSeries>[];
  for (final yColumn in yColumns) {
    final length = xValues == null
        ? yColumn.value.length
        : math.min(xValues.length, yColumn.value.length);
    if (length == 0) continue;
    final points = <DataPoint>[];
    for (var index = 0; index < length; index++) {
      points.add(
        DataPoint(xValues == null ? index + 1.0 : xValues[index],
            yColumn.value[index]),
      );
    }
    series.add(DataSeries(
      name: _columnSeriesName(
        value,
        yColumn.key,
        startIndex + series.length,
        singleYColumn: yColumns.length == 1,
      ),
      points: points,
    ));
  }
  return series;
}

bool _isJsonXColumn(String key) {
  final normalized = key.toLowerCase();
  return normalized == 'x' ||
      normalized == 'time' ||
      normalized == 't' ||
      normalized == 'step' ||
      normalized == 'epoch' ||
      normalized == 'iteration' ||
      normalized == 'iter';
}

String _columnSeriesName(
  Map value,
  String key,
  int fallbackIndex, {
  required bool singleYColumn,
}) {
  final trimmedKey = key.trim();
  final mapName = _jsonString(value['name'])?.trim();
  if (singleYColumn &&
      mapName != null &&
      mapName.isNotEmpty &&
      _isGenericJsonYColumn(trimmedKey)) {
    return mapName;
  }
  if (trimmedKey.isNotEmpty) return trimmedKey;
  return '数据 ${fallbackIndex + 1}';
}

bool _isGenericJsonYColumn(String key) {
  final normalized = key.toLowerCase();
  return normalized == 'y' || normalized == 'value' || normalized == 'v';
}

List<double> _jsonNumberList(Object? value) {
  if (value is! List || value.isEmpty) return const [];
  final values = <double>[];
  for (final item in value) {
    final parsed = _jsonScalarNumber(item);
    if (parsed == null) return const [];
    values.add(parsed);
  }
  return values;
}

String? _jsonString(Object? value) => value is String ? value : null;

List<DataSeries> _parseBlock(String block, {required int startIndex}) {
  final rows = <List<double>>[];
  var headers = <String>[];
  var headerDelimiter = '';
  for (final rawLine in block.split(RegExp(r'[\r\n]+'))) {
    final line = rawLine.trim().replaceFirst('\ufeff', '');
    if (line.isEmpty) continue;
    if (_isMetadataLine(line)) continue;
    if (_isUnitDescriptorLine(line)) continue;
    if (_isMarkdownSeparatorLine(line)) continue;
    final named = _namedNumbersFromLine(line);
    final matches = named == null
        ? _numbersFromHeaderDelimitedLine(
                line, headerDelimiter, headers.length) ??
            _numbers(line)
        : _valuesForNamedLine(named, headers);
    if (matches.isNotEmpty) {
      if (named != null && named.names.length >= 2 && headers.isEmpty) {
        headers = named.names;
        headerDelimiter = '';
      }
      rows.add(matches);
    } else if (rows.isEmpty && headers.isEmpty) {
      final parsedHeaders = _headerCells(line);
      if (parsedHeaders.length >= 2) {
        headers = parsedHeaders;
        headerDelimiter = _tableDelimiter(line);
      }
    }
  }
  if (rows.isEmpty) return const [];
  final normalizedTable = _stripLeadingIndexColumn(rows, headers);
  final parsedRows = normalizedTable.rows;
  headers = normalizedTable.headers;
  final maxColumns = parsedRows.map((row) => row.length).reduce(math.max);
  if (maxColumns >= 3) {
    final series = <DataSeries>[];
    for (var column = 1; column < maxColumns; column++) {
      final points = <DataPoint>[];
      for (var rowIndex = 0; rowIndex < parsedRows.length; rowIndex++) {
        final row = parsedRows[rowIndex];
        if (row.length > column) points.add(DataPoint(row[0], row[column]));
      }
      if (points.isNotEmpty) {
        series.add(DataSeries(
          name: _seriesName(headers, column, startIndex + series.length),
          points: points,
        ));
      }
    }
    return series;
  }

  final points = <DataPoint>[];
  var autoX = 1.0;
  for (final row in parsedRows) {
    if (row.length >= 2) {
      points.add(DataPoint(row[0], row[1]));
    } else {
      points.add(DataPoint(autoX, row[0]));
    }
    autoX = points.length + 1.0;
  }
  return [
    DataSeries(name: _seriesName(headers, 1, startIndex), points: points),
  ];
}

({List<List<double>> rows, List<String> headers}) _stripLeadingIndexColumn(
  List<List<double>> rows,
  List<String> headers,
) {
  if (rows.length < 2 || headers.isEmpty) {
    return (rows: rows, headers: headers);
  }
  final maxColumns = rows.map((row) => row.length).reduce(math.max);
  if (maxColumns < 3 || rows.any((row) => row.length != maxColumns)) {
    return (rows: rows, headers: headers);
  }

  var shouldStrip = false;
  var normalizedHeaders = headers;
  if (headers.length == maxColumns - 1 && _isTableXHeader(headers.first)) {
    shouldStrip = true;
  } else if (headers.length == maxColumns &&
      _isIndexHeader(headers.first) &&
      headers.length > 1 &&
      _isTableXHeader(headers[1])) {
    shouldStrip = true;
    normalizedHeaders = headers.sublist(1);
  }
  if (!shouldStrip) return (rows: rows, headers: headers);

  final indexValues = rows.map((row) => row.first).toList();
  if (!_isSequentialIndex(indexValues)) {
    return (rows: rows, headers: headers);
  }
  return (
    rows: rows.map((row) => row.sublist(1)).toList(),
    headers: normalizedHeaders,
  );
}

bool _isSequentialIndex(List<double> values) {
  if (values.length < 2) return false;
  return _isSequentialIndexStartingAt(values, 0) ||
      _isSequentialIndexStartingAt(values, 1);
}

bool _isSequentialIndexStartingAt(List<double> values, int start) {
  for (var index = 0; index < values.length; index++) {
    final expected = start + index;
    if ((values[index] - expected).abs() > 1e-9) return false;
  }
  return true;
}

bool _isTableXHeader(String header) {
  final normalized = header.trim().toLowerCase();
  return normalized == 'x' ||
      normalized == 'time' ||
      normalized == 't' ||
      normalized == 'date' ||
      normalized == 'datetime';
}

bool _isIndexHeader(String header) {
  final normalized = header.trim().toLowerCase();
  return normalized == 'index' ||
      normalized == 'idx' ||
      normalized == 'row' ||
      normalized == 'no' ||
      normalized == '#' ||
      normalized == '序号' ||
      normalized == '行号';
}

String _seriesName(List<String> headers, int column, int fallbackIndex) {
  if (column < headers.length && headers[column].trim().isNotEmpty) {
    return headers[column].trim();
  }
  return '数据 ${fallbackIndex + 1}';
}

List<String> _headerCells(String line) {
  final delimiter = _tableDelimiter(line);
  if (delimiter.isEmpty) return const [];
  var cells = line.split(delimiter).map((cell) => cell.trim()).toList();
  if (delimiter == '|') {
    if (cells.isNotEmpty && cells.first.isEmpty) cells = cells.sublist(1);
    if (cells.isNotEmpty && cells.last.isEmpty) {
      cells = cells.sublist(0, cells.length - 1);
    }
  }
  return cells.where((cell) => cell.isNotEmpty).toList();
}

String _tableDelimiter(String line) {
  return line.contains('|')
      ? '|'
      : line.contains('\t')
          ? '\t'
          : line.contains(',')
              ? ','
              : line.contains(';')
                  ? ';'
                  : '';
}

bool _isMetadataLine(String line) {
  final trimmed = line.trimLeft().replaceFirst('\ufeff', '');
  if (trimmed.isEmpty) return true;
  if (trimmed.startsWith('#') ||
      trimmed.startsWith('//') ||
      trimmed.startsWith('--')) {
    return true;
  }
  if (RegExp(r'^sep\s*=\s*(?:,|;|\||\\t|tab)$', caseSensitive: false)
      .hasMatch(trimmed)) {
    return true;
  }
  if (RegExp(r'^[+\-= ]+$').hasMatch(trimmed) &&
      trimmed.contains('+') &&
      trimmed.contains('-')) {
    return true;
  }
  return false;
}

bool _isUnitDescriptorLine(String line) {
  final cells = _headerCells(line);
  if (cells.length < 2) return false;
  final first = cells.first.trim().toLowerCase();
  return first == 'unit' || first == 'units' || first == '单位' || first == '量纲';
}

bool _isMarkdownSeparatorLine(String line) {
  if (!line.contains('|')) return false;
  final cells = _headerCells(line);
  if (cells.isEmpty) return false;
  return cells.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell));
}

List<double>? _numbersFromHeaderDelimitedLine(
  String line,
  String delimiter,
  int headerCount,
) {
  if (delimiter.isEmpty || headerCount < 2) return null;
  final normalized = _normalizeNumberText(line);
  var cells = normalized.split(delimiter).map((cell) => cell.trim()).toList();
  if (delimiter == '|') {
    if (cells.isNotEmpty && cells.first.isEmpty) cells = cells.sublist(1);
    if (cells.isNotEmpty && cells.last.isEmpty) {
      cells = cells.sublist(0, cells.length - 1);
    }
  }
  final matchesExpectedColumns = delimiter == ','
      ? cells.length == headerCount
      : cells.length == headerCount || cells.length == headerCount + 1;
  if (!matchesExpectedColumns) return null;

  final values = <double>[];
  for (final cell in cells) {
    final cellNumbers = _numbers(cell);
    if (cellNumbers.length != 1) return null;
    values.add(cellNumbers.single);
  }
  return values;
}

List<double> _numbers(String line) {
  final normalized = _normalizeNumberText(line);
  final pattern = RegExp(
    r'[-+]?(?:(?:\d{1,3}(?:,\d{3})+(?:\.\d*)?)|(?:\d+\.?\d*)|(?:\.\d+))(?:[eE][-+]?\d+)?%?',
  );
  final values = <double>[];
  for (final match in pattern.allMatches(normalized)) {
    if (_startsInsideIdentifier(normalized, match.start)) continue;
    final token = match.group(0)!;
    final value = _parseNumberToken(token);
    if (value == null) continue;
    values.add(value);
  }
  return values;
}

({List<String> names, List<double> values})? _namedNumbersFromLine(
    String line) {
  final normalized = _normalizeNumberText(line);
  final trimmed = normalized.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return null;

  const numberPattern =
      r'[-+]?(?:(?:\d{1,3}(?:,\d{3})+(?:\.\d*)?)|(?:\d+\.?\d*)|(?:\.\d+))(?:[eE][-+]?\d+)?%?';
  final pattern = RegExp(
    r'(?:^|[\s,;|])([A-Za-z_\u4e00-\u9fff][A-Za-z0-9_\u4e00-\u9fff./%°℃℉()\[\]（）-]{0,48})\s*[:=]\s*(' +
        numberPattern +
        r')',
  );
  final names = <String>[];
  final values = <double>[];
  for (final match in pattern.allMatches(normalized)) {
    final name = _normalizeDataFieldName(match.group(1)!);
    final value = _parseNumberToken(match.group(2)!);
    if (name.isEmpty || value == null) continue;
    names.add(name);
    values.add(value);
  }
  if (values.length < 2) return null;
  return (names: names, values: values);
}

String _normalizeDataFieldName(String value) {
  return value
      .trim()
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceFirst(RegExp(r'[:=]+$'), '')
      .trim();
}

List<double> _valuesForNamedLine(
  ({List<String> names, List<double> values}) named,
  List<String> headers,
) {
  if (headers.length != named.names.length || headers.isEmpty) {
    return named.values;
  }
  final byName = <String, double>{};
  for (var index = 0; index < named.names.length; index++) {
    byName[_fieldNameKey(named.names[index])] = named.values[index];
  }
  if (!headers.every((header) => byName.containsKey(_fieldNameKey(header)))) {
    return named.values;
  }
  return [
    for (final header in headers) byName[_fieldNameKey(header)]!,
  ];
}

String _fieldNameKey(String value) => value.trim().toLowerCase();

double? _parseNumberToken(String token) {
  final isPercent = token.endsWith('%');
  final numeric = token.replaceAll(',', '').replaceAll('%', '');
  final value = double.tryParse(numeric);
  if (value == null) return null;
  return isPercent ? value / 100 : value;
}

String _normalizeNumberText(String source) {
  final buffer = StringBuffer();
  for (final rune in source.runes) {
    if (rune >= 0xff10 && rune <= 0xff19) {
      buffer.writeCharCode(0x30 + rune - 0xff10);
      continue;
    }
    switch (rune) {
      case 0xff0b:
        buffer.write('+');
      case 0xff0d:
      case 0x2212:
        buffer.write('-');
      case 0xff0e:
        buffer.write('.');
      case 0xff0c:
        buffer.write(',');
      case 0xff05:
        buffer.write('%');
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

bool _startsInsideIdentifier(String source, int start) {
  if (start <= 0) return false;
  final previous = source.codeUnitAt(start - 1);
  return (previous >= 0x41 && previous <= 0x5a) ||
      (previous >= 0x61 && previous <= 0x7a) ||
      previous == 0x5f;
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

List<FitRecommendation> recommendFitModels(List<DataPoint> points) {
  final recommendations = <FitRecommendation>[];
  for (final model in FitModel.values) {
    try {
      recommendations.add(FitRecommendation(
        model: model,
        result: fitData(points, model),
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
