import 'dart:convert';
import 'dart:math' as math;

import 'package:characters/characters.dart';

import '../../core/math/expression_parser.dart';
import '../../features/tools/presentation/text_tool_strings.dart';
import 'text_tool_models.dart';
import 'tool_detail_controller.dart';

export 'text_tool_models.dart';

part 'text_tool_color_tools.dart';
part 'text_tool_csv_tools.dart';
part 'text_tool_custom_formula_tools.dart';
part 'text_tool_date_tools.dart';
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
part 'text_tool_url_codec_tools.dart';
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

  /// 中文：**`strings` 是必填的，没有中文兜底。** 这条签名是这一族唯一一道"语言可能漏传"的
  ///       闸门，所以它选择编译不过而不是静默回落到中文：漏传的后果是英文界面里蹦出一整屏
  ///       中文长句，而那种事在评审里几乎看不出来。屏幕那边在 `build` 里取一次
  ///       `TextToolStrings.of(context)` 递进来；纯 Dart 测试里用
  ///       `TextToolStrings.forLanguage(AppLanguage.zh)`，与"默认态逐字节不变"取的是同一张表。
  ///
  ///       **每一条分支现在都接表了**：`switch` 里 18 个工具无一例外，其中六个从
  ///       `strings` 里取自己那一张子表往下传（编解码组、Web 格式组、时间戳）。
  /// English: **`strings` is required, with no Chinese fallback.** This signature is the family's
  ///          one gate against "the language was forgotten", so it chooses a compile error over a
  ///          silent fall back to Chinese: forgetting it puts a screenful of Chinese sentences into
  ///          an English interface, and that is close to invisible in review. The screen reads
  ///          `TextToolStrings.of(context)` once in `build` and passes it in; plain Dart tests use
  ///          `TextToolStrings.forLanguage(AppLanguage.zh)`, the same table the "default state stays
  ///          byte-identical" rule is about.
  ///
  ///          **Every branch takes a table now**: all eighteen tools in the `switch` do, six of them
  ///          taking their own sub-table out of `strings` and handing it down (the codec group, the
  ///          web-format group and timestamps).
  TextToolOutput calculate({
    required String toolId,
    required TextToolStrings strings,
    required String input,
    String formula = 'a * b + c',
    String a = '12',
    String b = '3',
    String c = '5',
    // 中文：**只有日期计算看得见它。** 「今天」在 `date_calc` 里是一个输入，所以它必须可注入——
    //       写死 `DateTime.now()` 的话，「今天 + 30」这一整条路就只能靠真机验，而它是一个纯函数。
    //       其余工具不看这个参数。
    // English: **only the date calculator sees this.** "Today" is an input inside `date_calc`, so it has
    //          to be injectable — with a hard-wired `DateTime.now()` the whole "today + 30" path would
    //          be device-only, and it is a pure function. No other tool reads this parameter.
    DateTime? today,
  }) {
    try {
      final trimmed = input.trim();
      return switch (toolId) {
        'base_convert' => _baseConvert(strings.codec, trimmed),
        // 中文：**`today` 从参数走**，不在这里写死 `DateTime.now()`——那个写法会让这一条永远只能靠真机验，
        //       而它本来是一个纯函数。测试传一个固定日期就能把整条路走完。
        // English: **`today` travels through the parameter list** rather than a hard-wired
        //          `DateTime.now()` here, which would make this branch device-only — and it is
        //          a pure function. A test passing a fixed date walks the whole path.
        'date_calc' => _dateCalc(strings.date, trimmed, today ?? DateTime.now()),
        'timestamp' => _timestamp(strings.timestamp, trimmed),
        'color_convert' => _colorConvert(strings.web, trimmed),
        'base64' => _base64(strings.codec, trimmed),
        'url_codec' => _urlCodec(strings.web, trimmed),
        'json_format' => _jsonFormat(strings.text, trimmed),
        'ascii_unicode' => _asciiUnicode(strings.stats, input),
        'bitwise' => _bitwise(strings.codec, trimmed),
        'checksum' => _checksum(strings.codec, input),
        'uuid' => _uuid(strings.text, trimmed),
        'jwt_decode' => _jwtDecode(strings, trimmed),
        'query_params' => _queryParams(strings.web, trimmed),
        'html_entities' => _htmlEntities(strings.output, input),
        'regex_test' => _regexTest(strings.text, input),
        'text_stats' => _textStats(strings.stats, input),
        'csv_json' => _csvJson(strings, input),
        'fnv_crc' => _fnvCrc(strings.codec, input),
        'custom_formula' => _customFormula(
            strings: strings,
            input: input,
            formula: formula,
            a: a,
            b: b,
            c: c,
          ),
        _ => TextToolOutput(
            strings.output.unsupportedTool,
            strings.output.unsupportedToolDetail,
            hasError: true,
          ),
      };
    } catch (error) {
      return TextToolOutput(
        strings.output.invalidInput,
        error.toString(),
        hasError: true,
        insights: [strings.output.retryHint],
      );
    }
  }

  TextToolOutput _htmlEntities(TextToolOutputStrings strings, String input) {
    final decoded = _decodeHtmlEntities(input);
    if (decoded.changedCount > 0) {
      return TextToolOutput(
        decoded.value,
        strings.htmlEntityDecoded(decoded.changedCount, decoded.unknownCount),
        insights: [
          strings.htmlEntitySupport,
          if (decoded.unknownCount > 0) strings.htmlEntityUnknownKept,
        ],
      );
    }
    final encoded = _encodeHtmlEntities(input);
    return TextToolOutput(
      encoded,
      strings.htmlTextEncoded,
      insights: [strings.htmlEscaped],
    );
  }
}
