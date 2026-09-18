part of 'text_tool_controller.dart';

extension _TextToolCsvTools on TextToolController {
  TextToolOutput _csvJson(TextToolStrings strings, String input) {
    final jsonCsv = _tryConvertJsonToCsv(strings, input);
    if (jsonCsv != null) return jsonCsv;

    final table = _parseDelimitedTable(strings, input);
    final records = table.records;
    if (records.length < 2) {
      throw FormatException(strings.data.csvNeedHeaderAndRow);
    }
    final headers = _normalizeDelimitedHeaders(records.first);
    final inconsistentRows = <int>[];
    final rows = records.skip(1).toList().asMap().entries.map((entry) {
      final cells = entry.value;
      if (cells.length != headers.length) inconsistentRows.add(entry.key + 2);
      final row = {
        for (var i = 0; i < headers.length; i++)
          headers[i]: i < cells.length ? cells[i] : '',
      };
      for (var i = headers.length; i < cells.length; i++) {
        row['extra_${i - headers.length + 1}'] = cells[i];
      }
      return row;
    }).toList();
    return TextToolOutput(
      strings.data.rowCount(rows.length),
      const JsonEncoder.withIndent('  ').convert(rows),
      insights: [
        strings.data.csvDelimiterAndColumns(
            _delimiterLabel(strings, table.delimiter), headers.length),
        if (table.quotedCells > 0)
          strings.data.csvQuotedCells(table.quotedCells),
        if (table.multilineFields > 0)
          strings.data.csvMultilineFields(table.multilineFields),
        if (table.skippedEmptyRows > 0)
          strings.data.csvSkippedEmptyRows(table.skippedEmptyRows),
        if (table.skippedMetadataRows > 0)
          strings.data.csvSkippedMetadataRows(table.skippedMetadataRows),
        if (table.skippedMarkdownSeparatorRows > 0)
          strings.data
              .csvSkippedMarkdownRows(table.skippedMarkdownSeparatorRows),
        if (table.skippedAsciiTableRows > 0)
          strings.data.csvSkippedAsciiTableRows(table.skippedAsciiTableRows),
        if (inconsistentRows.isNotEmpty)
          strings.data.csvInconsistentRows(inconsistentRows.take(6).join(', ')),
      ],
    );
  }

  TextToolOutput? _tryConvertJsonToCsv(TextToolStrings strings, String input) {
    final trimmed = input.trimLeft();
    if (!_couldBeJsonCsvInput(trimmed)) return null;
    final _ParsedJsonInput parsed;
    try {
      parsed = _parseJsonInput(strings.text, input);
    } on FormatException {
      return null;
    }
    final decoded = parsed.value;

    final rows = _jsonRowsForCsv(decoded);
    if (rows.isEmpty) {
      throw FormatException(strings.data.csvJsonNeedsValue);
    }
    final headers = _jsonCsvHeaders(rows);
    final csvLines = <String>[
      headers.map(_escapeCsvCell).join(','),
      for (final row in rows)
        headers.map((header) => _escapeCsvCell(row[header] ?? '')).join(','),
    ];
    return TextToolOutput(
      strings.data.rowCount(rows.length),
      csvLines.join('\n'),
      insights: [
        strings.data.csvFromJson,
        if (parsed.extractedDescription != null)
          strings.text.jsonExtractedFrom(parsed.extractedDescription!),
        if (parsed.jsonLines) strings.data.csvJsonLinesConverted,
        if (parsed.normalizedJsonLike) strings.text.jsonJsStyleNormalized,
        strings.data.csvColumnCount(headers.length),
        if (decoded is List) strings.data.csvTopLevelArray(decoded.length),
        if (decoded is Map) strings.data.csvTopLevelObject,
        if (_jsonRowsContainFlattenedKeys(rows))
          strings.data.csvNestedFlattened,
        if (_jsonRowsContainNestedValues(rows)) strings.data.csvNestedAsText,
      ],
    );
  }

  bool _couldBeJsonCsvInput(String input) {
    if (input.isEmpty) return false;
    if (input.startsWith('{') || input.startsWith('[')) return true;
    if (input.startsWith('"') || input.startsWith("'")) return true;
    if (input.startsWith('```')) return true;
    if (_looksLikeJsonLinesPaste(input)) return true;
    return RegExp(
      r'^(?:const|let|var)?\s*[A-Za-z_$][\w$]*\s*=',
      caseSensitive: false,
    ).hasMatch(input);
  }

  List<Map<String, String>> _jsonRowsForCsv(Object? decoded) {
    if (decoded is List) {
      return decoded.map(_jsonValueToCsvRow).toList();
    }
    return [_jsonValueToCsvRow(decoded)];
  }

  Map<String, String> _jsonValueToCsvRow(Object? value) {
    if (value is Map) {
      final row = <String, String>{};
      for (final entry in value.entries) {
        _addJsonCsvField(row, entry.key.toString(), entry.value);
      }
      return row;
    }
    return {'value': _jsonCsvCellValue(value)};
  }

  void _addJsonCsvField(Map<String, String> row, String key, Object? value) {
    if (value is Map && value.isNotEmpty) {
      for (final entry in value.entries) {
        _addJsonCsvField(row, '$key.${entry.key}', entry.value);
      }
      return;
    }
    row[key] = _jsonCsvCellValue(value);
  }

  List<String> _jsonCsvHeaders(List<Map<String, String>> rows) {
    final headers = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      for (final key in row.keys) {
        if (seen.add(key)) headers.add(key);
      }
    }
    return headers;
  }

  String _jsonCsvCellValue(Object? value) {
    return switch (value) {
      null => '',
      String() => value,
      num() || bool() => value.toString(),
      _ => json.encode(value),
    };
  }

  bool _jsonRowsContainNestedValues(List<Map<String, String>> rows) {
    return rows.any((row) => row.values.any((value) {
          final trimmed = value.trimLeft();
          return trimmed.startsWith('{') || trimmed.startsWith('[');
        }));
  }

  bool _jsonRowsContainFlattenedKeys(List<Map<String, String>> rows) {
    return rows.any((row) => row.keys.any((key) => key.contains('.')));
  }

  String _escapeCsvCell(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  _DelimitedTable _parseDelimitedTable(TextToolStrings strings, String input) {
    final candidates = [',', '\t', ';', '|'].map((delimiter) {
      return _parseDelimitedRecords(strings, input, delimiter);
    }).toList();
    candidates.sort((a, b) {
      final aColumns = a.records.isEmpty ? 0 : a.records.first.length;
      final bColumns = b.records.isEmpty ? 0 : b.records.first.length;
      final columnOrder = bColumns.compareTo(aColumns);
      if (columnOrder != 0) return columnOrder;
      final inconsistentOrder = _inconsistentDelimitedRows(a.records)
          .compareTo(_inconsistentDelimitedRows(b.records));
      if (inconsistentOrder != 0) return inconsistentOrder;
      return [',', '\t', ';', '|']
          .indexOf(a.delimiter)
          .compareTo([',', '\t', ';', '|'].indexOf(b.delimiter));
    });
    return candidates.first;
  }

  _DelimitedTable _parseDelimitedRecords(
    TextToolStrings strings,
    String input,
    String delimiter,
  ) {
    final records = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var inQuotes = false;
    var fieldQuoted = false;
    var atStartOfField = true;
    var afterClosingQuote = false;
    var quotedCells = 0;
    var multilineFields = 0;
    var newlinesInField = 0;
    var skippedEmptyRows = 0;

    void finishField() {
      row.add(fieldQuoted ? field.toString() : field.toString().trim());
      if (fieldQuoted) {
        quotedCells++;
        if (newlinesInField > 0) multilineFields++;
      }
      field = StringBuffer();
      fieldQuoted = false;
      atStartOfField = true;
      afterClosingQuote = false;
      newlinesInField = 0;
    }

    void finishRecord() {
      finishField();
      if (row.any((cell) => cell.trim().isNotEmpty)) {
        records.add(row);
      } else {
        skippedEmptyRows++;
      }
      row = <String>[];
    }

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
            afterClosingQuote = true;
          }
          continue;
        }
        if (char == '\r' || char == '\n') {
          field.write('\n');
          newlinesInField++;
          if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
            i++;
          }
          continue;
        }
        field.write(char);
        continue;
      }

      if (char == delimiter) {
        finishField();
        continue;
      }
      if (char == '\r' || char == '\n') {
        finishRecord();
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        continue;
      }
      if (char == '"' && atStartOfField) {
        inQuotes = true;
        fieldQuoted = true;
        atStartOfField = false;
        continue;
      }
      if (afterClosingQuote && char.trim().isEmpty) {
        continue;
      }
      if (atStartOfField && char.trim().isEmpty) {
        continue;
      }
      field.write(char);
      atStartOfField = false;
      afterClosingQuote = false;
    }

    if (inQuotes) throw FormatException(strings.data.csvUnclosedQuote);
    if (row.isNotEmpty || field.isNotEmpty || fieldQuoted || !atStartOfField) {
      finishRecord();
    }

    var skippedMarkdownSeparatorRows = 0;
    var skippedAsciiTableRows = 0;
    var skippedMetadataRows = 0;
    final normalizedRecords = <List<String>>[];
    for (final record in records) {
      final normalized =
          delimiter == '|' ? _trimMarkdownPipeBoundaryCells(record) : record;
      if (normalizedRecords.isEmpty && _isCsvMetadataOrCommentRow(normalized)) {
        skippedMetadataRows++;
        continue;
      }
      if (normalizedRecords.isNotEmpty && _isCsvUnitDescriptorRow(normalized)) {
        skippedMetadataRows++;
        continue;
      }
      if (delimiter == '|' && _isAsciiTableNonDataRow(normalized)) {
        skippedAsciiTableRows++;
        continue;
      }
      if (_isMarkdownTableSeparatorRow(normalized)) {
        skippedMarkdownSeparatorRows++;
        continue;
      }
      normalizedRecords.add(normalized);
    }

    return _DelimitedTable(
      records: normalizedRecords,
      delimiter: delimiter,
      quotedCells: quotedCells,
      multilineFields: multilineFields,
      skippedEmptyRows: skippedEmptyRows,
      skippedMetadataRows: skippedMetadataRows,
      skippedMarkdownSeparatorRows: skippedMarkdownSeparatorRows,
      skippedAsciiTableRows: skippedAsciiTableRows,
    );
  }

  List<String> _trimMarkdownPipeBoundaryCells(List<String> row) {
    var start = 0;
    var end = row.length;
    if (start < end && row[start].trim().isEmpty) start++;
    if (start < end && row[end - 1].trim().isEmpty) end--;
    return row.sublist(start, end);
  }

  bool _isCsvMetadataOrCommentRow(List<String> row) {
    final cells =
        row.map((cell) => cell.replaceFirst('\ufeff', '').trim()).toList();
    final nonEmpty = cells.where((cell) => cell.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return false;

    if (cells.first.toLowerCase() == 'sep=' &&
        cells.skip(1).every((cell) => cell.isEmpty)) {
      return true;
    }

    if (nonEmpty.length != 1) return false;
    final text = nonEmpty.single;
    if (RegExp(r'^sep\s*=\s*(?:,|;|\||\\t|tab)$', caseSensitive: false)
        .hasMatch(text)) {
      return true;
    }
    return text.startsWith('#') ||
        text.startsWith('//') ||
        text.startsWith('--');
  }

  bool _isCsvUnitDescriptorRow(List<String> row) {
    if (row.length < 2) return false;
    final first = row.first.replaceFirst('\ufeff', '').trim().toLowerCase();
    return first == 'unit' ||
        first == 'units' ||
        first == '单位' ||
        first == '量纲';
  }

  bool _isMarkdownTableSeparatorRow(List<String> row) {
    if (row.isEmpty) return false;
    return row.every(
      (cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell.trim()),
    );
  }

  bool _isAsciiTableNonDataRow(List<String> row) {
    if (row.length != 1) return false;
    final text = row.single.trim();
    if (text.isEmpty) return false;
    if (RegExp(r'^\(\d+\s+rows?\)$', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    if (RegExp(r'^\d+\s+rows?\s+in\s+set\b', caseSensitive: false)
        .hasMatch(text)) {
      return true;
    }
    return text.contains('+') &&
        text.contains('-') &&
        RegExp(r'^[+\-= ]+$').hasMatch(text);
  }

  int _inconsistentDelimitedRows(List<List<String>> records) {
    if (records.length < 2) return 0;
    final columns = records.first.length;
    return records.skip(1).where((row) => row.length != columns).length;
  }

  String _delimiterLabel(TextToolStrings strings, String delimiter) {
    return switch (delimiter) {
      '\t' => 'Tab',
      ',' => strings.data.delimiterComma,
      ';' => strings.data.delimiterSemicolon,
      '|' => strings.data.delimiterPipe,
      _ => delimiter,
    };
  }

  List<String> _normalizeDelimitedHeaders(List<String> rawHeaders) {
    final normalized = <String>[];
    final seen = <String, int>{};
    for (var i = 0; i < rawHeaders.length; i++) {
      final fallback = 'column_${i + 1}';
      final header = rawHeaders[i].replaceFirst('\ufeff', '').trim();
      final base = header.isEmpty ? fallback : header;
      final count = (seen[base] ?? 0) + 1;
      seen[base] = count;
      normalized.add(count == 1 ? base : '${base}_$count');
    }
    return normalized;
  }
}
