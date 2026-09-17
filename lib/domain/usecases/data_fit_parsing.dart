import 'dart:convert';
import 'dart:math' as math;

import 'data_fit_models.dart';

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
