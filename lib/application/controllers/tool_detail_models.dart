import '../../domain/entities/tool_definition.dart';

class NumericInputParseResult {
  const NumericInputParseResult({required this.value, this.error});

  final double? value;
  final String? error;
}

class ToolInputPasteResult {
  const ToolInputPasteResult({
    required this.values,
    required this.ignoredSegments,
    required this.ambiguousSegments,
    required this.duplicateKeys,
    required this.segmentCount,
  });

  factory ToolInputPasteResult.empty() => const ToolInputPasteResult(
        values: {},
        ignoredSegments: [],
        ambiguousSegments: [],
        duplicateKeys: {},
        segmentCount: 0,
      );

  final Map<String, String> values;
  final List<String> ignoredSegments;
  final List<String> ambiguousSegments;
  final Set<String> duplicateKeys;
  final int segmentCount;

  bool get hasValues => values.isNotEmpty;

  int get matchedCount => values.length;

  int get issueCount =>
      ignoredSegments.length + ambiguousSegments.length + duplicateKeys.length;

  bool get hasIssues => issueCount > 0;

  String summaryForTool(ToolDefinition tool) {
    if (!hasValues) {
      if (ambiguousSegments.isNotEmpty) {
        return '剪贴板里的参数单位有歧义，未自动填入';
      }
      if (ignoredSegments.isNotEmpty) {
        return '剪贴板里有数字，但没有匹配到本工具参数';
      }
      return '剪贴板里没有识别到本工具的参数';
    }
    final parts = <String>['已粘贴 $matchedCount 个参数'];
    if (duplicateKeys.isNotEmpty) {
      parts.add('重复字段已取最后值：${_inputLabels(tool, duplicateKeys).join('、')}');
    }
    if (ambiguousSegments.isNotEmpty) {
      parts.add('跳过 ${ambiguousSegments.length} 条歧义值');
    }
    if (ignoredSegments.isNotEmpty) {
      parts.add('忽略 ${ignoredSegments.length} 条未匹配值');
    }
    return parts.join('，');
  }

  static List<String> _inputLabels(ToolDefinition tool, Iterable<String> keys) {
    final byKey = {for (final input in tool.inputs) input.key: input.label};
    return keys.map((key) => byKey[key] ?? key).toList(growable: false);
  }
}

class ToolInputApplyResult {
  const ToolInputApplyResult({
    required this.inputTexts,
    required this.filledKeys,
    required this.validKeys,
    required this.invalidKeyErrors,
    this.pasteResult,
  });

  final Map<String, String> inputTexts;
  final Set<String> filledKeys;
  final Set<String> validKeys;
  final Map<String, String> invalidKeyErrors;
  final ToolInputPasteResult? pasteResult;

  bool get hasValues => filledKeys.isNotEmpty;

  bool get hasInvalidValues => invalidKeyErrors.isNotEmpty;

  bool get hasValidValues => validKeys.isNotEmpty;

  String summaryForTool(ToolDefinition tool) {
    final paste = pasteResult;
    if (!hasValues) {
      return paste?.summaryForTool(tool) ?? '没有可应用的参数';
    }
    final parts = <String>[
      if (hasValidValues)
        '已应用 ${validKeys.length} 个参数'
      else
        '识别到 ${filledKeys.length} 个参数但都需要修正',
    ];
    if (hasInvalidValues) {
      parts.add('需修正：${_inputLabels(tool, invalidKeyErrors.keys).join('、')}');
    }
    if (paste != null) {
      if (paste.duplicateKeys.isNotEmpty) {
        parts.add(
            '重复字段已取最后值：${_inputLabels(tool, paste.duplicateKeys).join('、')}');
      }
      if (paste.ambiguousSegments.isNotEmpty) {
        parts.add('跳过 ${paste.ambiguousSegments.length} 条歧义值');
      }
      if (paste.ignoredSegments.isNotEmpty) {
        parts.add('忽略 ${paste.ignoredSegments.length} 条未匹配值');
      }
    }
    return parts.join('，');
  }

  static List<String> _inputLabels(ToolDefinition tool, Iterable<String> keys) {
    final byKey = {for (final input in tool.inputs) input.key: input.label};
    return keys.map((key) => byKey[key] ?? key).toList(growable: false);
  }
}

