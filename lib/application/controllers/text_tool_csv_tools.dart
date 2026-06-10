part of 'text_tool_controller.dart';

extension _TextToolCsvTools on TextToolController {
  TextToolOutput _csvJson(String input) {
    final jsonCsv = _tryConvertJsonToCsv(input);
    if (jsonCsv != null) return jsonCsv;

    final table = _parseDelimitedTable(input);
    final records = table.records;
    if (records.length < 2) throw const FormatException('至少需要表头和一行数据。');
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
      '${rows.length} 行',
      const JsonEncoder.withIndent('  ').convert(rows),
      insights: [
        '分隔符: ${_delimiterLabel(table.delimiter)}，列数: ${headers.length}。',
        if (table.quotedCells > 0) '已处理 ${table.quotedCells} 个带引号字段。',
        if (table.multilineFields > 0) '已保留 ${table.multilineFields} 个包含换行的字段。',
        if (table.skippedEmptyRows > 0) '已跳过 ${table.skippedEmptyRows} 个空行。',
        if (table.skippedMetadataRows > 0)
          '已跳过 ${table.skippedMetadataRows} 行 CSV 元数据或注释。',
        if (table.skippedMarkdownSeparatorRows > 0)
          '已跳过 ${table.skippedMarkdownSeparatorRows} 行 Markdown 表格分隔线。',
        if (table.skippedAsciiTableRows > 0)
          '已跳过 ${table.skippedAsciiTableRows} 行 SQL/ASCII 表格边框或尾行。',
        if (inconsistentRows.isNotEmpty)
          '第 ${inconsistentRows.take(6).join(', ')} 行列数与表头不一致。',
      ],
    );
  }

  TextToolOutput? _tryConvertJsonToCsv(String input) {
    final trimmed = input.trimLeft();
    if (!_couldBeJsonCsvInput(trimmed)) return null;
    final _ParsedJsonInput parsed;
    try {
      parsed = _parseJsonInput(input);
    } on FormatException {
      return null;
    }
    final decoded = parsed.value;

    final rows = _jsonRowsForCsv(decoded);
    if (rows.isEmpty) {
      throw const FormatException('JSON 转 CSV 至少需要一个对象或标量值。');
    }
    final headers = _jsonCsvHeaders(rows);
    final csvLines = <String>[
      headers.map(_escapeCsvCell).join(','),
      for (final row in rows)
        headers.map((header) => _escapeCsvCell(row[header] ?? '')).join(','),
    ];
    return TextToolOutput(
      '${rows.length} 行',
      csvLines.join('\n'),
      insights: [
        '输入识别为 JSON，已转换为 CSV。',
        if (parsed.extractedDescription != null)
          '已从${parsed.extractedDescription}中提取 JSON。',
        if (parsed.jsonLines) '输入识别为 JSON Lines / NDJSON，已按多行记录转换。',
        if (parsed.normalizedJsonLike) '已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。',
        '列数: ${headers.length}。',
        if (decoded is List) '顶层数组元素: ${decoded.length}。',
        if (decoded is Map) '顶层对象已作为 1 行数据处理。',
        if (_jsonRowsContainFlattenedKeys(rows)) '嵌套对象已展开为点号列名。',
        if (_jsonRowsContainNestedValues(rows)) '嵌套对象/数组已按 JSON 文本写入单元格。',
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

  _DelimitedTable _parseDelimitedTable(String input) {
    final candidates = [',', '\t', ';', '|'].map((delimiter) {
      return _parseDelimitedRecords(input, delimiter);
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

  _DelimitedTable _parseDelimitedRecords(String input, String delimiter) {
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

    if (inQuotes) throw const FormatException('CSV 引号未闭合。');
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

  String _delimiterLabel(String delimiter) {
    return switch (delimiter) {
      '\t' => 'Tab',
      ',' => '逗号',
      ';' => '分号',
      '|' => '竖线',
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
