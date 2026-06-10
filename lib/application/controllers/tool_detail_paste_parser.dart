part of 'tool_detail_controller.dart';

ToolInputPasteResult _parseRawInputValuesFromPastedText({
  required ToolDefinition tool,
  required String input,
}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty || tool.inputs.isEmpty) {
    return ToolInputPasteResult.empty();
  }
  final aliases = _pastedInputAliases(tool);
  final values = <String, String>{};
  final ignoredSegments = <String>[];
  final ambiguousSegments = <String>[];
  final duplicateKeys = <String>{};

  final jsonAssignments = _pastedJsonInputAssignments(trimmed, aliases);
  if (jsonAssignments.isNotEmpty) {
    for (final assignment in jsonAssignments) {
      _addPastedAssignment(
        values: values,
        duplicateKeys: duplicateKeys,
        assignment: assignment,
      );
    }
    return ToolInputPasteResult(
      values: values,
      ignoredSegments: const [],
      ambiguousSegments: const [],
      duplicateKeys: duplicateKeys,
      segmentCount: jsonAssignments.length,
    );
  }

  for (final segment in _pastedInputSegments(trimmed)) {
    final assignment = _matchPastedInputSegment(segment, aliases);
    if (assignment != null) {
      _addPastedAssignment(
        values: values,
        duplicateKeys: duplicateKeys,
        assignment: assignment,
      );
      continue;
    }
    final tableAssignment = _matchPastedTableSegment(segment, aliases);
    if (tableAssignment != null) {
      _addPastedAssignment(
        values: values,
        duplicateKeys: duplicateKeys,
        assignment: tableAssignment,
      );
      continue;
    }
    final compactAssignments = _compactPastedInputAssignments(segment, aliases);
    for (final compact in compactAssignments) {
      _addPastedAssignment(
        values: values,
        duplicateKeys: duplicateKeys,
        assignment: compact,
      );
    }
    if (compactAssignments.isNotEmpty) continue;
    final unitAssignments = _pastedInputSegmentUnitMatches(
      segment: segment,
      tool: tool,
      assignedKeys: values.keys.toSet(),
    );
    if (unitAssignments.length == 1) {
      _addPastedAssignment(
        values: values,
        duplicateKeys: duplicateKeys,
        assignment: unitAssignments.single,
      );
      continue;
    }
    if (unitAssignments.length > 1) {
      ambiguousSegments.add(segment);
      continue;
    }
    if (_shouldReportIgnoredPastedSegment(segment)) {
      ignoredSegments.add(segment);
    }
  }
  return ToolInputPasteResult(
    values: values,
    ignoredSegments: ignoredSegments,
    ambiguousSegments: ambiguousSegments,
    duplicateKeys: duplicateKeys,
    segmentCount: _pastedInputSegments(trimmed).length,
  );
}

Map<String, String> _rawInputValuesFromPastedText({
  required ToolDefinition tool,
  required String input,
}) {
  return _parseRawInputValuesFromPastedText(tool: tool, input: input).values;
}

void _addPastedAssignment({
  required Map<String, String> values,
  required Set<String> duplicateKeys,
  required _PastedInputAssignment assignment,
}) {
  if (values.containsKey(assignment.key)) duplicateKeys.add(assignment.key);
  values[assignment.key] = assignment.value;
}

List<_PastedInputAssignment> _pastedJsonInputAssignments(
  String input,
  List<_PastedToolInputAlias> aliases,
) {
  final trimmed = input.trimLeft();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return const [];
  try {
    return _pastedJsonAssignmentsFromNode(jsonDecode(input), aliases);
  } catch (_) {
    return const [];
  }
}

List<_PastedInputAssignment> _pastedJsonAssignmentsFromNode(
  Object? node,
  List<_PastedToolInputAlias> aliases,
) {
  final assignments = <_PastedInputAssignment>[];
  if (node is List) {
    for (final item in node) {
      assignments.addAll(_pastedJsonAssignmentsFromNode(item, aliases));
    }
    return assignments;
  }
  if (node is! Map) return assignments;
  for (final entry in node.entries) {
    final label = entry.key?.toString().trim() ?? '';
    if (label.isEmpty) continue;
    final alias = _matchPastedAlias(label, aliases);
    if (alias != null) {
      final value = _pastedJsonScalarValue(entry.value);
      if (value != null && _looksLikePastedNumericValue(value)) {
        assignments.add(_PastedInputAssignment(alias.key, value));
      }
      continue;
    }
    if (_looksLikePastedJsonContainerKey(label)) {
      assignments.addAll(
        _pastedJsonAssignmentsFromNode(entry.value, aliases),
      );
    }
  }
  return assignments;
}

bool _looksLikePastedJsonContainerKey(String label) {
  final normalized = _normalizePastedLabel(label);
  return const {
    'input',
    'inputs',
    'values',
    'params',
    'parameters',
    '参数',
    '输入',
    '输入参数',
  }.contains(normalized);
}

String? _pastedJsonScalarValue(Object? value) {
  if (value is num) return value.toString();
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is Map) {
    final raw = value['value'] ??
        value['raw'] ??
        value['text'] ??
        value['读数'] ??
        value['值'];
    final unit = value['unit'] ?? value['单位'];
    final scalar = _pastedJsonScalarValue(raw);
    if (scalar == null) return null;
    final unitText = unit?.toString().trim() ?? '';
    return unitText.isEmpty ? scalar : '$scalar$unitText';
  }
  return null;
}

List<_PastedToolInputAlias> _pastedInputAliases(ToolDefinition tool) {
  final aliases = <_PastedToolInputAlias>[];
  for (final input in tool.inputs) {
    final texts = <String>{
      input.key,
      input.label,
      ...input.label
          .split(RegExp(r'[\s/()（）\[\]【】]+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty),
    };
    for (final text in texts) {
      if (text.isEmpty) continue;
      aliases.add(_PastedToolInputAlias(key: input.key, text: text));
    }
  }
  aliases.sort((a, b) => b.text.length.compareTo(a.text.length));
  return aliases;
}

List<String> _pastedInputSegments(String input) {
  return const LineSplitter()
      .convert(input)
      .expand((line) => line.split(RegExp(r'[;；]')))
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
}

List<_PastedInputAssignment> _compactPastedInputAssignments(
  String input,
  List<_PastedToolInputAlias> aliases,
) {
  final assignments = <_PastedInputAssignment>[];
  for (final alias in aliases) {
    final pattern = RegExp(
      r'(?:^|[\s,;，；])' +
          RegExp.escape(alias.text) +
          r'\s*(?:=>|->|[:：=])\s*([^\s,;，；]+)',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(input)) {
      final value = match.group(1)?.trim();
      if (value == null || !_looksLikePastedNumericValue(value)) continue;
      assignments.add(_PastedInputAssignment(alias.key, value));
    }
  }
  return assignments;
}

_PastedInputAssignment? _matchPastedInputSegment(
  String segment,
  List<_PastedToolInputAlias> aliases,
) {
  for (final alias in aliases) {
    final pattern = RegExp(
      r'^\s*' + RegExp.escape(alias.text) + r'\s*(?:=>|->|[:：=])\s*(.+?)\s*$',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(segment);
    final value = match?.group(1)?.trim();
    if (value == null || !_looksLikePastedNumericValue(value)) continue;
    return _PastedInputAssignment(alias.key, value);
  }
  return null;
}

_PastedInputAssignment? _matchPastedTableSegment(
  String segment,
  List<_PastedToolInputAlias> aliases,
) {
  for (final columns in _pastedTableColumns(segment)) {
    if (columns.length < 2) continue;
    final label = columns.first;
    final value = columns.skip(1).join(' ').trim();
    if (!_looksLikePastedNumericValue(value)) continue;
    final matched = _matchPastedAlias(label, aliases);
    if (matched != null) return _PastedInputAssignment(matched.key, value);
  }
  return null;
}

List<List<String>> _pastedTableColumns(String segment) {
  return [
    if (segment.contains('\t')) segment.split(RegExp(r'\t+')),
    if (RegExp(r'\s{2,}').hasMatch(segment)) segment.split(RegExp(r'\s{2,}')),
    if (segment.contains(',') || segment.contains('，'))
      segment.split(RegExp(r'[,，]')),
  ]
      .map((columns) => columns.map((cell) => cell.trim()).toList())
      .where((columns) => columns.length >= 2)
      .map(
        (columns) =>
            columns.where((cell) => cell.isNotEmpty).toList(growable: false),
      )
      .where((columns) => columns.length >= 2)
      .toList(growable: false);
}

bool _matchesPastedLabel(String label, String alias) {
  final normalizedLabel = _normalizePastedLabel(label);
  final normalizedAlias = _normalizePastedLabel(alias);
  if (normalizedAlias.length <= 1) return normalizedLabel == normalizedAlias;
  return normalizedLabel == normalizedAlias ||
      normalizedLabel.contains(normalizedAlias);
}

_PastedToolInputAlias? _matchPastedAlias(
  String label,
  List<_PastedToolInputAlias> aliases,
) {
  for (final alias in aliases) {
    if (_matchesPastedLabel(label, alias.text)) return alias;
  }
  return null;
}

String _normalizePastedLabel(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[\s:：=,，;；\(\)（）\[\]【】]+'), '')
      .toLowerCase();
}

List<_PastedInputAssignment> _pastedInputSegmentUnitMatches({
  required String segment,
  required ToolDefinition tool,
  required Set<String> assignedKeys,
}) {
  if (!_looksLikePastedNumericValue(segment) ||
      _looksLikeLabeledPastedSegment(segment)) {
    return const [];
  }
  final matches = <_PastedInputAssignment>[];
  for (final input in tool.inputs) {
    if (assignedKeys.contains(input.key)) continue;
    if (input.unit.trim().isEmpty) continue;
    final parsed = ToolDetailController.parseNumericInputForUnit(
      segment,
      input.unit,
    );
    if (parsed.value != null) {
      matches.add(_PastedInputAssignment(input.key, segment));
    }
  }
  return matches;
}

bool _looksLikeLabeledPastedSegment(String segment) {
  return RegExp(r'(?:=>|->|[:：=])').hasMatch(segment);
}

bool _shouldReportIgnoredPastedSegment(String segment) {
  if (!_looksLikePastedNumericValue(segment)) return false;
  return _looksLikeLabeledPastedSegment(segment) ||
      segment.contains('\t') ||
      RegExp(r'\s{2,}|[,，]').hasMatch(segment);
}

bool _looksLikePastedNumericValue(String value) {
  final normalized = ToolDetailController._normalizeNumericText(value);
  return RegExp(r'[\d０-９]').hasMatch(value) ||
      normalized.contains('√') ||
      RegExp(
        r'\b(?:pi|e|sqrt|sin|cos|tan|asin|acos|atan|max|min|abs|log|ln)\b',
        caseSensitive: false,
      ).hasMatch(normalized);
}

class _PastedToolInputAlias {
  const _PastedToolInputAlias({required this.key, required this.text});

  final String key;
  final String text;
}

class _PastedInputAssignment {
  const _PastedInputAssignment(this.key, this.value);

  final String key;
  final String value;
}
