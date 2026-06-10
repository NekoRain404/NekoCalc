import 'dart:convert';
import 'dart:math' as math;

import 'package:characters/characters.dart';

import '../../core/math/expression_parser.dart';
import 'text_tool_models.dart';
import 'tool_detail_controller.dart';

export 'text_tool_models.dart';

part 'text_tool_color_tools.dart';
part 'text_tool_csv_tools.dart';
part 'text_tool_custom_formula_tools.dart';
part 'text_tool_binary_tools.dart';
part 'text_tool_html_entities.dart';
part 'text_tool_integer_tools.dart';
part 'text_tool_json_tools.dart';
part 'text_tool_jwt_tools.dart';
part 'text_tool_parsed_models.dart';
part 'text_tool_regex_tools.dart';
part 'text_tool_shared_text.dart';
part 'text_tool_text_stats_tools.dart';
part 'text_tool_timestamp_tools.dart';
part 'text_tool_url_query_tools.dart';
part 'text_tool_uuid_tools.dart';

class TextToolController {
  const TextToolController();

  static String draftSettingKey(String toolId) => 'text_tool_draft_$toolId';

  static String encodeDraft(TextToolDraft draft) {
    return jsonEncode({
      'version': 1,
      'toolId': draft.toolId,
      'input': draft.input,
      'formula': draft.formula,
      'a': draft.a,
      'b': draft.b,
      'c': draft.c,
    });
  }

  static TextToolDraft? decodeDraft({
    required String toolId,
    required String? raw,
  }) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['toolId'] != toolId) return null;
      String value(String key, String fallback) {
        final rawValue = decoded[key];
        return rawValue is String ? rawValue : fallback;
      }

      return TextToolDraft(
        toolId: toolId,
        input: value('input', ''),
        formula: value('formula', defaultFormula),
        a: value('a', defaultA),
        b: value('b', defaultB),
        c: value('c', defaultC),
      );
    } catch (_) {
      return null;
    }
  }

  static const String defaultFormula = 'a * b + c';
  static const String defaultA = '12';
  static const String defaultB = '3';
  static const String defaultC = '5';

  static TextToolDraft customFormulaDraftFromPastedText({
    required String input,
    String currentFormula = defaultFormula,
    String currentA = defaultA,
    String currentB = defaultB,
    String currentC = defaultC,
  }) {
    final fields = _extractCustomFormulaFields(input);
    final formula =
        fields['formula'] ?? (fields.isEmpty ? input : currentFormula);

    return TextToolDraft(
      toolId: 'custom_formula',
      input: input,
      formula: formula,
      a: fields['a'] ?? currentA,
      b: fields['b'] ?? currentB,
      c: fields['c'] ?? currentC,
    );
  }

  TextToolOutput calculate({
    required String toolId,
    required String input,
    String formula = 'a * b + c',
    String a = '12',
    String b = '3',
    String c = '5',
  }) {
    try {
      final trimmed = input.trim();
      return switch (toolId) {
        'base_convert' => _baseConvert(trimmed),
        'timestamp' => _timestamp(trimmed),
        'color_convert' => _colorConvert(trimmed),
        'base64' => _base64(trimmed),
        'url_codec' => _urlCodec(trimmed),
        'json_format' => _jsonFormat(trimmed),
        'ascii_unicode' => _asciiUnicode(input),
        'bitwise' => _bitwise(trimmed),
        'checksum' => _checksum(input),
        'uuid' => _uuid(trimmed),
        'jwt_decode' => _jwtDecode(trimmed),
        'query_params' => _queryParams(trimmed),
        'html_entities' => _htmlEntities(input),
        'regex_test' => _regexTest(input),
        'text_stats' => _textStats(input),
        'csv_json' => _csvJson(input),
        'fnv_crc' => _fnvCrc(input),
        'custom_formula' =>
          _customFormula(input: input, formula: formula, a: a, b: b, c: c),
        _ => const TextToolOutput('不支持的文本工具', '请从工具中心打开已登记的编程与数据工具。'),
      };
    } catch (error) {
      return TextToolOutput(
        '输入无效',
        error.toString(),
        insights: const ['请检查输入格式后重试。'],
      );
    }
  }

  TextToolOutput _htmlEntities(String input) {
    final decoded = _decodeHtmlEntities(input);
    if (decoded.changedCount > 0) {
      return TextToolOutput(
        decoded.value,
        '检测为 HTML 实体文本，已解码 ${decoded.changedCount} 处实体。\n未知实体: ${decoded.unknownCount}',
        insights: [
          '支持常见命名实体、十进制数字实体和十六进制数字实体。',
          if (decoded.unknownCount > 0) '未知实体已保留原文，避免误改内容。',
        ],
      );
    }
    final encoded = _encodeHtmlEntities(input);
    return TextToolOutput(
      encoded,
      '检测为普通文本，已编码 HTML 特殊字符。',
      insights: const ['已转义 &、<、>、引号、撇号和不间断空格。'],
    );
  }
}
