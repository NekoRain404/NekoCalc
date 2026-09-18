import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：文本识别组的界面文案表——UUID、JSON、正则、自定义公式四个工具的长句。
///       **为什么单独一张**、**为什么控制器要接表进来**、以及**哪些中文刻意不翻**，
///       三条理由都写在 `text_tool_strings.dart` 的文件头上，这里不重抄。
///
///       **表里装的是"给人看的字"以外的第二层：输入识别的说明句。** 这些句子会被拼进
///       `TextToolOutput.detail` 与 `insights`，用户直接读得到，所以它们和按钮标签一样要翻；
///       但它们的**触发条件是输入的形状**（是不是 JSON、是几位 HEX、带不带 data URL 前缀），
///       那部分判据留在控制器里，没有跟着进来。
/// English: The copy table for the recognition group — the long sentences of the UUID, JSON, regex
///          and custom-formula tools. **Why it is a table of its own**, **why the controller takes a
///          table as an argument**, and **which Chinese is deliberately left untranslated** are all
///          written on `text_tool_strings.dart`'s file head and not copied again here.
///
///          **What lives here is a second layer beyond labels: the input-recognition notes.** These
///          sentences are spliced into `TextToolOutput.detail` and `insights` and the user reads
///          them directly, so they need translating just like a button label; but the **condition
///          that triggers them** is the shape of the input (is it JSON, how many HEX digits, does it
///          carry a data-URL prefix), and that condition stays in the controller and did not come in
///          here.
@immutable
class TextToolTextStrings {
  const TextToolTextStrings({
    // —— UUID ——
    required this.uuidStandard,
    required this.uuidUppercase,
    required this.uuidNoHyphens,
    required this.uuidVersionLine,
    required this.uuidVariantLine,
    required this.uuidGenerated,
    required this.uuidValid,
    required this.uuidExtractedFrom,
    required this.uuidNormalized,
    required this.uuidInvalid,
    required this.uuidHyphens,
    required this.uuidSourceJsonField,
    required this.uuidSourceGuidCall,
    required this.uuidSourceLabelText,
    required this.uuidSourceByteArray,
    required this.uuidVersion1,
    required this.uuidVersion2,
    required this.uuidVersion3,
    required this.uuidVersion4,
    required this.uuidVersion5,
    required this.uuidVersion6,
    required this.uuidVersion7,
    required this.uuidVersion8,
    required this.uuidVersionOther,
    required this.uuidVariantNcs,
    required this.uuidVariantRfc,
    required this.uuidVariantMicrosoft,
    required this.uuidVariantFuture,
    // —— JSON ——
    required this.jsonLinesValid,
    required this.jsonValid,
    required this.jsonEmpty,
    required this.jsonEscapedString,
    required this.jsonEscapedStringIn,
    required this.jsonSourceMarkdownFence,
    required this.jsonSourcePastedText,
    required this.jsonExtractedFrom,
    required this.jsonLinesConverted,
    required this.jsonJsStyleNormalized,
    required this.jsonTopLevelObject,
    required this.jsonTopLevelArray,
    required this.jsonTopLevelString,
    required this.jsonTopLevelNumber,
    required this.jsonTopLevelBoolean,
    required this.jsonTopLevelNull,
    required this.jsonTopLevelOther,
    required this.jsonStructure,
    required this.jsonKeysAndDepth,
    required this.jsonNullCount,
    // —— 正则 ——
    required this.regexNeedTwoLines,
    required this.regexMatchCount,
    required this.regexNoMatches,
    required this.regexLabeledInput,
    required this.regexGlobalFlag,
    required this.regexFirst50,
    required this.regexNoHit,
    required this.regexEmptyPattern,
    required this.regexHasGroups,
    required this.regexFlagsUnsupported,
    // —— 自定义公式 ——
    required this.formulaEmpty,
    required this.formulaNotFinite,
    required this.formulaMissingVariables,
    required this.formulaLabel,
    required this.formulaExpanded,
    required this.formulaVariables,
    required this.formulaVariableLine,
    required this.formulaExtracted,
    required this.formulaExtractedVariables,
    required this.formulaUsedVariables,
    required this.formulaUnusedVariables,
    required this.formulaAngleNote,
    required this.formulaVariableError,
    required this.formulaSourceInput,
    required this.formulaSourceField,
  });

  // —— UUID ——
  final String Function(String standard) uuidStandard;
  final String Function(String upper) uuidUppercase;
  final String Function(String hex) uuidNoHyphens;
  final String Function(String label) uuidVersionLine;
  final String Function(String label) uuidVariantLine;
  final String uuidGenerated;
  final String uuidValid;
  final String Function(String source) uuidExtractedFrom;
  final String uuidNormalized;

  /// 中文：`FormatException` 的正文。它会被 `TextToolOutput` 兜底那句接住，以
  ///       `FormatException: …` 的形状显示在详情里，所以它同样是给人看的字。
  /// English: The body of a `FormatException`. The `TextToolOutput` fallback picks it up and shows
  ///          it in the detail pane as `FormatException: …`, so it is human-facing copy too.
  final String uuidInvalid;
  final String uuidHyphens;
  final String uuidSourceJsonField;
  final String uuidSourceGuidCall;
  final String uuidSourceLabelText;
  final String uuidSourceByteArray;
  final String uuidVersion1;
  final String uuidVersion2;
  final String uuidVersion3;
  final String uuidVersion4;
  final String uuidVersion5;
  final String uuidVersion6;
  final String uuidVersion7;
  final String uuidVersion8;
  final String Function(int version) uuidVersionOther;
  final String uuidVariantNcs;
  final String uuidVariantRfc;
  final String uuidVariantMicrosoft;
  final String uuidVariantFuture;

  // —— JSON ——
  final String jsonLinesValid;
  final String jsonValid;
  final String jsonEmpty;
  final String jsonEscapedString;
  final String Function(String source) jsonEscapedStringIn;
  final String jsonSourceMarkdownFence;
  final String jsonSourcePastedText;
  final String Function(String source) jsonExtractedFrom;
  final String jsonLinesConverted;
  final String jsonJsStyleNormalized;
  final String Function(int count) jsonTopLevelObject;
  final String Function(int count) jsonTopLevelArray;
  final String jsonTopLevelString;
  final String jsonTopLevelNumber;
  final String jsonTopLevelBoolean;
  final String jsonTopLevelNull;
  final String Function(String type) jsonTopLevelOther;
  final String Function(int objects, int arrays, int scalars) jsonStructure;
  final String Function(int keys, int depth) jsonKeysAndDepth;
  final String Function(int count) jsonNullCount;

  // —— 正则 ——
  final String regexNeedTwoLines;
  final String Function(int count) regexMatchCount;
  final String regexNoMatches;
  final String regexLabeledInput;
  final String regexGlobalFlag;
  final String regexFirst50;
  final String regexNoHit;
  final String regexEmptyPattern;
  final String regexHasGroups;
  final String regexFlagsUnsupported;

  // —— 自定义公式 ——
  final String formulaEmpty;
  final String formulaNotFinite;
  final String Function(String names) formulaMissingVariables;
  final String Function(String formula) formulaLabel;
  final String Function(String expression) formulaExpanded;
  final String formulaVariables;
  final String Function(String name, String value, String source)
      formulaVariableLine;
  final String formulaExtracted;
  final String Function(String names) formulaExtractedVariables;
  final String Function(String names) formulaUsedVariables;
  final String Function(String names) formulaUnusedVariables;
  final String formulaAngleNote;
  final String Function(String name, String error) formulaVariableError;
  final String Function(String raw) formulaSourceInput;
  final String Function(String raw) formulaSourceField;

  static TextToolTextStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  static TextToolTextStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => textZh,
      AppLanguage.en => textEn,
    };
  }

  static final TextToolTextStrings textZh = TextToolTextStrings(
    uuidStandard: (standard) => '标准: $standard',
    uuidUppercase: (upper) => '大写: $upper',
    uuidNoHyphens: (hex) => '无连字符: $hex',
    uuidVersionLine: (label) => '版本: $label',
    uuidVariantLine: (label) => 'Variant: $label',
    uuidGenerated: '已离线生成随机 UUID v4。',
    uuidValid: '输入 UUID 有效，已标准化。',
    uuidExtractedFrom: (source) => '已从$source中提取 UUID。',
    uuidNormalized: '输入已规范为小写 8-4-4-4-12 格式。',
    uuidInvalid: '请输入有效 UUID，例如 550e8400-e29b-41d4-a716-446655440000',
    uuidHyphens: 'UUID 连字符位置应为 8-4-4-4-12。',
    uuidSourceJsonField: 'JSON 字段',
    uuidSourceGuidCall: 'Guid/UUID 调用',
    uuidSourceLabelText: '标签文本',
    uuidSourceByteArray: '字节数组',
    uuidVersion1: '1（时间/MAC）',
    uuidVersion2: '2（DCE Security）',
    uuidVersion3: '3（MD5 namespace）',
    uuidVersion4: '4（随机）',
    uuidVersion5: '5（SHA-1 namespace）',
    uuidVersion6: '6（重排时间）',
    uuidVersion7: '7（Unix 时间）',
    uuidVersion8: '8（自定义）',
    uuidVersionOther: (version) => '$version（未知/保留）',
    uuidVariantNcs: 'NCS 兼容',
    uuidVariantRfc: 'RFC 4122 / RFC 9562',
    uuidVariantMicrosoft: 'Microsoft 兼容',
    uuidVariantFuture: '未来保留',
    jsonLinesValid: 'JSON Lines 有效',
    jsonValid: 'JSON 有效',
    jsonEmpty: '请输入 JSON 文本',
    jsonEscapedString: '转义 JSON 字符串',
    jsonEscapedStringIn: (source) => '$source中的转义 JSON 字符串',
    jsonSourceMarkdownFence: 'Markdown 代码块',
    jsonSourcePastedText: '粘贴文本',
    jsonExtractedFrom: (source) => '已从$source中提取 JSON。',
    jsonLinesConverted: '输入识别为 JSON Lines / NDJSON，已转换为数组。',
    jsonJsStyleNormalized: '已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。',
    jsonTopLevelObject: (count) => '顶层类型: Object，键数量: $count。',
    jsonTopLevelArray: (count) => '顶层类型: Array，元素数量: $count。',
    jsonTopLevelString: '顶层类型: String。',
    jsonTopLevelNumber: '顶层类型: Number。',
    jsonTopLevelBoolean: '顶层类型: Boolean。',
    jsonTopLevelNull: '顶层类型: Null。',
    jsonTopLevelOther: (type) => '顶层类型: $type。',
    jsonStructure: (objects, arrays, scalars) =>
        '结构: Object $objects，Array $arrays，标量 $scalars。',
    jsonKeysAndDepth: (keys, depth) => '总键数: $keys，最大深度: $depth。',
    jsonNullCount: (count) => '包含 null 值: $count。',
    regexNeedTwoLines: '第一行输入正则，后续行输入测试文本。',
    regexMatchCount: (count) => '$count 个匹配',
    regexNoMatches: '没有匹配项',
    regexLabeledInput: '已识别 pattern/text 标签格式。',
    regexGlobalFlag: '已兼容 g/global 标志；本工具默认列出所有匹配。',
    regexFirst50: '仅展示前 50 个匹配项。',
    regexNoHit: '当前正则没有命中测试文本。',
    regexEmptyPattern: '正则为空，会匹配所有位置。',
    regexHasGroups: '包含捕获组，详情中已列出 group 值。',
    regexFlagsUnsupported: '正则 flags 仅支持 g、i、m、s、u',
    formulaEmpty: '请输入公式，例如 a * b + c',
    formulaNotFinite: '公式结果不是有限数值，请检查除零、对数或开方范围。',
    formulaMissingVariables: (names) => '公式包含未赋值变量: $names',
    formulaLabel: (formula) => '公式: $formula',
    formulaExpanded: (expression) => '展开公式: $expression',
    formulaVariables: '变量:',
    formulaVariableLine: (name, value, source) =>
        '  $name = $value  来源: $source',
    formulaExtracted: '已从输入文本中提取公式。',
    formulaExtractedVariables: (names) => '已从输入文本中提取变量: $names。',
    formulaUsedVariables: (names) => '公式使用变量: $names.',
    formulaUnusedVariables: (names) => '未使用变量: $names。',
    formulaAngleNote: '表达式按角度制解析三角函数，支持常量 pi/e 和常用数学函数。',
    formulaVariableError: (name, error) => '变量 $name: $error',
    formulaSourceInput: (raw) => '输入文本 "$raw"',
    formulaSourceField: (raw) => '变量框 "$raw"',
  );

  static final TextToolTextStrings textEn = TextToolTextStrings(
    uuidStandard: (standard) => 'Standard: $standard',
    uuidUppercase: (upper) => 'Uppercase: $upper',
    uuidNoHyphens: (hex) => 'No hyphens: $hex',
    uuidVersionLine: (label) => 'Version: $label',
    uuidVariantLine: (label) => 'Variant: $label',
    uuidGenerated: 'Generated a random UUID v4 offline.',
    uuidValid: 'The input UUID is valid and has been normalised.',
    uuidExtractedFrom: (source) => 'Extracted the UUID from $source.',
    uuidNormalized: 'The input was normalised to lowercase 8-4-4-4-12 form.',
    uuidInvalid:
        'Enter a valid UUID, for example 550e8400-e29b-41d4-a716-446655440000',
    uuidHyphens: 'A UUID hyphenates as 8-4-4-4-12.',
    uuidSourceJsonField: 'a JSON field',
    uuidSourceGuidCall: 'a Guid/UUID call',
    uuidSourceLabelText: 'labelled text',
    uuidSourceByteArray: 'a byte array',
    uuidVersion1: '1 (time/MAC)',
    uuidVersion2: '2 (DCE Security)',
    uuidVersion3: '3 (MD5 namespace)',
    uuidVersion4: '4 (random)',
    uuidVersion5: '5 (SHA-1 namespace)',
    uuidVersion6: '6 (reordered time)',
    uuidVersion7: '7 (Unix time)',
    uuidVersion8: '8 (custom)',
    uuidVersionOther: (version) => '$version (unknown/reserved)',
    uuidVariantNcs: 'NCS compatible',
    uuidVariantRfc: 'RFC 4122 / RFC 9562',
    uuidVariantMicrosoft: 'Microsoft compatible',
    uuidVariantFuture: 'Reserved for the future',
    jsonLinesValid: 'Valid JSON Lines',
    jsonValid: 'Valid JSON',
    jsonEmpty: 'Enter some JSON text',
    jsonEscapedString: 'an escaped JSON string',
    jsonEscapedStringIn: (source) => 'an escaped JSON string in $source',
    jsonSourceMarkdownFence: 'a Markdown code fence',
    jsonSourcePastedText: 'the pasted text',
    jsonExtractedFrom: (source) => 'Extracted JSON from $source.',
    jsonLinesConverted:
        'Recognised JSON Lines / NDJSON input and converted it to an array.',
    jsonJsStyleNormalized:
        'Accepted a JS-style object: comments, unquoted keys, single quotes and '
        'trailing commas were normalised.',
    jsonTopLevelObject: (count) => 'Top level: Object, $count keys.',
    jsonTopLevelArray: (count) => 'Top level: Array, $count elements.',
    jsonTopLevelString: 'Top level: String.',
    jsonTopLevelNumber: 'Top level: Number.',
    jsonTopLevelBoolean: 'Top level: Boolean.',
    jsonTopLevelNull: 'Top level: Null.',
    jsonTopLevelOther: (type) => 'Top level: $type.',
    jsonStructure: (objects, arrays, scalars) =>
        'Structure: Object $objects, Array $arrays, scalars $scalars.',
    jsonKeysAndDepth: (keys, depth) =>
        'Total keys: $keys, maximum depth: $depth.',
    jsonNullCount: (count) => 'Contains null values: $count.',
    regexNeedTwoLines:
        'Put the pattern on the first line and the test text below.',
    regexMatchCount: (count) => '$count matches',
    regexNoMatches: 'No matches',
    regexLabeledInput: 'Recognised the pattern/text labelled form.',
    regexGlobalFlag:
        'Accepted the g/global flag; this tool lists every match by default.',
    regexFirst50: 'Showing the first 50 matches only.',
    regexNoHit: 'The pattern did not match the test text.',
    regexEmptyPattern: 'The pattern is empty, so it matches at every position.',
    regexHasGroups:
        'Capture groups are present; the detail lists each group value.',
    regexFlagsUnsupported: 'Regex flags support only g, i, m, s and u',
    formulaEmpty: 'Enter a formula, for example a * b + c',
    formulaNotFinite:
        'The formula did not produce a finite number; check for division by zero, '
        'or a logarithm or square root outside its domain.',
    formulaMissingVariables: (names) =>
        'The formula uses unassigned variables: $names',
    formulaLabel: (formula) => 'Formula: $formula',
    formulaExpanded: (expression) => 'Expanded formula: $expression',
    formulaVariables: 'Variables:',
    formulaVariableLine: (name, value, source) =>
        '  $name = $value  from $source',
    formulaExtracted: 'Extracted the formula from the input text.',
    formulaExtractedVariables: (names) =>
        'Extracted variables from the input text: $names.',
    formulaUsedVariables: (names) => 'The formula uses the variables: $names.',
    formulaUnusedVariables: (names) => 'Unused variables: $names.',
    formulaAngleNote:
        'The expression evaluates trigonometry in degrees and supports the '
        'constants pi/e and the usual mathematical functions.',
    formulaVariableError: (name, error) => 'Variable $name: $error',
    formulaSourceInput: (raw) => 'the input text "$raw"',
    formulaSourceField: (raw) => 'the variable field "$raw"',
  );
}
