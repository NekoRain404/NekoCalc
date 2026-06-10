import '../../data/models/history_item.dart';
import '../../data/models/note_item.dart';

enum RecordTab { all, notes, history, formulas, tools }

bool matchesHistoryRecord(HistoryItem item, RecordTab tab) {
  if (tab == RecordTab.tools) {
    return item.toolId != null ||
        item.expression.contains('=') ||
        item.result.contains(':');
  }
  if (tab == RecordTab.formulas) {
    return item.expression.contains('sin') ||
        item.expression.contains('sqrt') ||
        item.expression.contains('公式');
  }
  return true;
}

bool matchesNoteRecord(NoteItem item, RecordTab tab) {
  if (tab == RecordTab.tools) {
    return item.body.contains('公式：') ||
        item.description.contains('工具') ||
        item.title.contains('计算');
  }
  if (tab == RecordTab.formulas) {
    return item.title.contains('公式') ||
        item.description.contains('公式') ||
        item.body.contains('=');
  }
  return true;
}

bool matchesHistoryQuery(HistoryItem item, String query) {
  final tokens = _queryTokens(query);
  if (tokens.isEmpty) return true;
  final fields = [
    item.expression,
    item.result,
    if (item.toolId != null) item.toolId!,
    ..._dateSearchFields(item.createdAt),
  ].map(_normalizeSearchText).toList(growable: false);
  return tokens.every((token) => fields.any((field) => field.contains(token)));
}

bool matchesNoteQuery(NoteItem item, String query) {
  final tokens = _queryTokens(query);
  if (tokens.isEmpty) return true;
  final fields = [
    item.title,
    item.description,
    item.body,
    ..._dateSearchFields(item.createdAt),
    ..._dateSearchFields(item.updatedAt),
  ].map(_normalizeSearchText).toList(growable: false);
  return tokens.every((token) => fields.any((field) => field.contains(token)));
}

List<String> recordQueryTokens(String query) => _queryTokens(query);

String normalizeRecordSearchText(String value) => _normalizeSearchText(value);

List<String> _queryTokens(String query) {
  return _normalizeSearchText(_stripReportLabels(query))
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

String _normalizeSearchText(String value) {
  final groupedNumbers = _normalizeFullWidthAscii(value).replaceAllMapped(
    RegExp(
        r'(?<![A-Za-z0-9_.])([+-]?\d{1,3}(?:,\d{3})+(?:\.\d+)?)(?![A-Za-z0-9_.])'),
    (match) => match.group(1)!.replaceAll(',', ''),
  );
  return groupedNumbers
      .trim()
      .toLowerCase()
      .replaceAll('，', ' ')
      .replaceAll(',', ' ')
      .replaceAll('；', ' ')
      .replaceAll(';', ' ')
      .replaceAll('：', ' ')
      .replaceAll(':', ' ')
      .replaceAll('　', ' ')
      .replaceAll('_', ' ')
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('π', 'pi')
      .replaceAll('τ', 'tau')
      .replaceAll('φ', 'phi')
      .replaceAll('ϕ', 'phi')
      .replaceAll('√', 'sqrt')
      .replaceAll('²', '2')
      .replaceAll('³', '3')
      .replaceAll('℃', 'degc')
      .replaceAll('℉', 'degf')
      .replaceAll('μ', 'u')
      .replaceAll('µ', 'u')
      .replaceAll('Ω', 'ohm')
      .replaceAll('ω', 'ohm')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _stripReportLabels(String query) {
  final text = _normalizeFullWidthAscii(query)
      .replaceAll('\u00a0', ' ')
      .replaceAllMapped(
        RegExp(
          r'^\s*(?:计算历史|工具历史|nekocalc\s+批量导出)\s*$',
          caseSensitive: false,
          multiLine: true,
        ),
        (_) => ' ',
      );
  return text.replaceAllMapped(
    RegExp(
      r'(?:^|[\r\n\s,，;；])(?:工具历史|计算历史|表达式|算式|公式|结果|答案|当前值|笔记|描述|创建时间|更新时间|时间|expression|expr|formula|result|answer|value|note|description|created|updated|time)\s*[:：=]\s*',
      caseSensitive: false,
    ),
    (match) => match.group(0)!.startsWith(RegExp(r'[\r\n]')) ? '\n' : ' ',
  );
}

String _normalizeFullWidthAscii(String source) {
  return source.runes.map((code) {
    if (code >= 0xff01 && code <= 0xff5e) {
      return String.fromCharCode(code - 0xfee0);
    }
    return String.fromCharCode(code);
  }).join();
}

List<String> _dateSearchFields(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  final naturalMonth = date.month.toString();
  final naturalDay = date.day.toString();
  return [
    '$year-$month-$day',
    '$year/$month/$day',
    '$year$month$day',
    '$year年$month月$day日',
    '$year年$naturalMonth月$naturalDay日',
    '$month-$day',
    '$month/$day',
    '$naturalMonth月$naturalDay日',
    '$hour:$minute',
  ];
}
