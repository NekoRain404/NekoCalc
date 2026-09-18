import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：数据组的界面文案表——CSV/JSON 表格与 JWT 解码两个工具的长句。
///       **为什么控制器要接表进来**、以及**哪些中文刻意不翻**，两条理由都写在
///       `text_tool_strings.dart` 的文件头上，这里不重抄。
///
///       **时间戳工具不在这张表里，它在 `TextToolTimestampStrings`。** 它整条链上每一层都在
///       产出中文（识别说明、单位说明、相对时间），所以自成一张；`'现在'` / `'北京时间'`
///       那几处**判据**则留在控制器里，一条也没翻。
///
///       **刻意不翻的两处**，都在 CSV 的输入文法里，它们是**与输入比较的判据**：
///       - `_isCsvUnitDescriptorRow` 里的 `first == '单位' || first == '量纲'`：这一行判的是
///         "用户粘贴的表格首列写着单位吗"。把它翻了，中文表格的单位行就再也认不出来。
///       - `_delimiterLabel` 的 `'\t' => 'Tab'` 那一支是 ASCII，本来就不需要翻；
///         `',' => '逗号'` 那几支是**给用户看的标签**，所以它们在表里。
/// English: The copy table for the data group — the long sentences of the CSV/JSON table tool and
///          the JWT decoder. **Why the controller takes a table as an argument** and **which Chinese
///          is deliberately left untranslated** are both written on `text_tool_strings.dart`'s file
///          head and not copied again here.
///
///          **The timestamp tool is not in this table; it lives in `TextToolTimestampStrings`.**
///          Every layer of its chain produces Chinese (recognition notes, unit notes, relative time),
///          so it gets a table of its own; the **branch conditions** `'现在'` / `'北京时间'` stay in
///          the controller and were not translated at all.
///
///          **Two things deliberately untranslated**, both in the CSV input grammar, both **branch
///          conditions compared against input**:
///          - `first == '单位' || first == '量纲'` in `_isCsvUnitDescriptorRow`: that line asks "does
///            the first column of the table the user pasted say 单位". Translate it and a Chinese
///            table's unit row stops being recognised.
///          - The `'\t' => 'Tab'` branch of `_delimiterLabel` is ASCII and needed no work; the
///            `',' => '逗号'` branches are **labels for the reader**, so they are in the table.
@immutable
class TextToolDataStrings {
  const TextToolDataStrings({
    // —— CSV ——
    required this.csvNeedHeaderAndRow,
    required this.rowCount,
    required this.csvDelimiterAndColumns,
    required this.delimiterComma,
    required this.delimiterSemicolon,
    required this.delimiterPipe,
    required this.csvQuotedCells,
    required this.csvMultilineFields,
    required this.csvSkippedEmptyRows,
    required this.csvSkippedMetadataRows,
    required this.csvSkippedMarkdownRows,
    required this.csvSkippedAsciiTableRows,
    required this.csvInconsistentRows,
    required this.csvJsonNeedsValue,
    required this.csvFromJson,
    required this.csvJsonLinesConverted,
    required this.csvColumnCount,
    required this.csvTopLevelArray,
    required this.csvTopLevelObject,
    required this.csvNestedFlattened,
    required this.csvNestedAsText,
    required this.csvUnclosedQuote,
    // —— JWT ——
    required this.jwtNeedHeaderPayload,
    required this.jwtParsed,
    required this.jwtSignatureSegment,
    required this.jwtSignatureNone,
    required this.jwtNotJsonObject,
    required this.jwtEmpty,
    required this.jwtFromBearer,
    required this.jwtFromTokenField,
    required this.jwtFromPastedText,
    required this.jwtFromJsonField,
    required this.jwtFromCookie,
    required this.jwtFromUrlQuery,
    required this.jwtHasSignature,
    required this.jwtNoSignature,
    required this.jwtAlgorithm,
    required this.jwtType,
    required this.jwtAlgNone,
    required this.jwtKeyId,
    required this.jwtExpired,
    required this.jwtNotExpired,
    required this.jwtNoExpiry,
    required this.jwtNotYetValid,
    required this.jwtNbfReached,
    required this.jwtHasIssuedAt,
    required this.jwtHasAudience,
    required this.jwtHasIssuer,
    required this.jwtHasSubject,
  });

  // —— CSV ——
  final String csvNeedHeaderAndRow;
  final String Function(int rows) rowCount;
  final String Function(String delimiter, int columns) csvDelimiterAndColumns;
  final String delimiterComma;
  final String delimiterSemicolon;
  final String delimiterPipe;
  final String Function(int count) csvQuotedCells;
  final String Function(int count) csvMultilineFields;
  final String Function(int count) csvSkippedEmptyRows;
  final String Function(int count) csvSkippedMetadataRows;
  final String Function(int count) csvSkippedMarkdownRows;
  final String Function(int count) csvSkippedAsciiTableRows;

  /// 中文：行号那一段是拼好的字符串（`inconsistentRows.take(6).join(', ')`），所以收 `String`。
  /// English: The row list arrives pre-joined (`inconsistentRows.take(6).join(', ')`), hence the
  ///          `String` parameter.
  final String Function(String rows) csvInconsistentRows;
  final String csvJsonNeedsValue;
  final String csvFromJson;
  final String csvJsonLinesConverted;
  final String Function(int columns) csvColumnCount;
  final String Function(int count) csvTopLevelArray;
  final String csvTopLevelObject;
  final String csvNestedFlattened;
  final String csvNestedAsText;
  final String csvUnclosedQuote;

  // —— JWT ——
  final String jwtNeedHeaderPayload;
  final String jwtParsed;
  final String Function(String value) jwtSignatureSegment;
  final String jwtSignatureNone;
  final String Function(String label) jwtNotJsonObject;
  final String jwtEmpty;
  final String jwtFromBearer;
  final String jwtFromTokenField;
  final String jwtFromPastedText;
  final String jwtFromJsonField;
  final String jwtFromCookie;
  final String jwtFromUrlQuery;
  final String jwtHasSignature;
  final String jwtNoSignature;
  final String Function(String alg) jwtAlgorithm;
  final String Function(String typ) jwtType;
  final String jwtAlgNone;
  final String Function(String kid) jwtKeyId;
  final String jwtExpired;
  final String jwtNotExpired;
  final String jwtNoExpiry;
  final String jwtNotYetValid;
  final String jwtNbfReached;
  final String jwtHasIssuedAt;
  final String jwtHasAudience;
  final String jwtHasIssuer;
  final String jwtHasSubject;

  static TextToolDataStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  static TextToolDataStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => dataZh,
      AppLanguage.en => dataEn,
    };
  }

  static final TextToolDataStrings dataZh = TextToolDataStrings(
    csvNeedHeaderAndRow: '至少需要表头和一行数据。',
    rowCount: (rows) => '$rows 行',
    csvDelimiterAndColumns: (delimiter, columns) =>
        '分隔符: $delimiter，列数: $columns。',
    delimiterComma: '逗号',
    delimiterSemicolon: '分号',
    delimiterPipe: '竖线',
    csvQuotedCells: (count) => '已处理 $count 个带引号字段。',
    csvMultilineFields: (count) => '已保留 $count 个包含换行的字段。',
    csvSkippedEmptyRows: (count) => '已跳过 $count 个空行。',
    csvSkippedMetadataRows: (count) => '已跳过 $count 行 CSV 元数据或注释。',
    csvSkippedMarkdownRows: (count) => '已跳过 $count 行 Markdown 表格分隔线。',
    csvSkippedAsciiTableRows: (count) => '已跳过 $count 行 SQL/ASCII 表格边框或尾行。',
    csvInconsistentRows: (rows) => '第 $rows 行列数与表头不一致。',
    csvJsonNeedsValue: 'JSON 转 CSV 至少需要一个对象或标量值。',
    csvFromJson: '输入识别为 JSON，已转换为 CSV。',
    csvJsonLinesConverted: '输入识别为 JSON Lines / NDJSON，已按多行记录转换。',
    csvColumnCount: (columns) => '列数: $columns。',
    csvTopLevelArray: (count) => '顶层数组元素: $count。',
    csvTopLevelObject: '顶层对象已作为 1 行数据处理。',
    csvNestedFlattened: '嵌套对象已展开为点号列名。',
    csvNestedAsText: '嵌套对象/数组已按 JSON 文本写入单元格。',
    csvUnclosedQuote: 'CSV 引号未闭合。',
    jwtNeedHeaderPayload: '请输入 JWT，至少包含 header.payload',
    jwtParsed: 'JWT 已解析',
    jwtSignatureSegment: (value) => '签名段: $value',
    jwtSignatureNone: '无',
    jwtNotJsonObject: (label) => 'JWT $label 必须是 JSON object',
    jwtEmpty: '请输入 JWT',
    jwtFromBearer: '已从 Bearer/Authorization 文本中提取 JWT。',
    jwtFromTokenField: '已从 token 字段中提取 JWT。',
    jwtFromPastedText: '已从粘贴文本中提取 JWT。',
    jwtFromJsonField: '已从 JSON 字段中提取 JWT。',
    jwtFromCookie: '已从 Cookie 字段中提取 JWT。',
    jwtFromUrlQuery: '已从 URL query 参数中提取 JWT。',
    jwtHasSignature: '包含签名段，但未在本地校验签名。',
    jwtNoSignature: '缺少签名段，仅能查看内容。',
    jwtAlgorithm: (alg) => '算法 alg: $alg。',
    jwtType: (typ) => '类型 typ: $typ。',
    jwtAlgNone: 'alg=none，Token 不包含加密签名。',
    jwtKeyId: (kid) => '包含密钥 ID kid: $kid。',
    jwtExpired: 'Token 已过期。',
    jwtNotExpired: 'Token 尚未过期。',
    jwtNoExpiry: '缺少过期时间 exp。',
    jwtNotYetValid: 'Token 尚未生效。',
    jwtNbfReached: 'Token 已到 nbf 生效时间。',
    jwtHasIssuedAt: '包含签发时间 iat。',
    jwtHasAudience: '包含受众 aud。',
    jwtHasIssuer: '包含签发者 iss。',
    jwtHasSubject: '包含主题 sub。',
  );

  static final TextToolDataStrings dataEn = TextToolDataStrings(
    csvNeedHeaderAndRow: 'A header row and at least one data row are needed.',
    rowCount: (rows) => '$rows rows',
    csvDelimiterAndColumns: (delimiter, columns) =>
        'Delimiter: $delimiter, $columns columns.',
    delimiterComma: 'comma',
    delimiterSemicolon: 'semicolon',
    delimiterPipe: 'pipe',
    csvQuotedCells: (count) => 'Handled $count quoted fields.',
    csvMultilineFields: (count) => 'Kept $count fields containing line breaks.',
    csvSkippedEmptyRows: (count) => 'Skipped $count empty rows.',
    csvSkippedMetadataRows: (count) =>
        'Skipped $count rows of CSV metadata or comments.',
    csvSkippedMarkdownRows: (count) =>
        'Skipped $count Markdown table separator rows.',
    csvSkippedAsciiTableRows: (count) =>
        'Skipped $count SQL/ASCII table border or trailing rows.',
    csvInconsistentRows: (rows) =>
        'Rows $rows have a different column count from the header.',
    csvJsonNeedsValue:
        'Converting JSON to CSV needs at least one object or scalar.',
    csvFromJson: 'Recognised JSON input and converted it to CSV.',
    csvJsonLinesConverted:
        'Recognised JSON Lines / NDJSON input and converted it row by row.',
    csvColumnCount: (columns) => 'Columns: $columns.',
    csvTopLevelArray: (count) => 'Top-level array elements: $count.',
    csvTopLevelObject: 'The top-level object was treated as a single row.',
    csvNestedFlattened:
        'Nested objects were flattened into dotted column names.',
    csvNestedAsText:
        'Nested objects/arrays were written into cells as JSON text.',
    csvUnclosedQuote: 'A CSV quote was never closed.',
    jwtNeedHeaderPayload: 'Enter a JWT with at least header.payload',
    jwtParsed: 'JWT parsed',
    jwtSignatureSegment: (value) => 'Signature segment: $value',
    jwtSignatureNone: 'none',
    jwtNotJsonObject: (label) => 'The JWT $label must be a JSON object',
    jwtEmpty: 'Enter a JWT',
    jwtFromBearer: 'Extracted the JWT from Bearer/Authorization text.',
    jwtFromTokenField: 'Extracted the JWT from a token field.',
    jwtFromPastedText: 'Extracted the JWT from the pasted text.',
    jwtFromJsonField: 'Extracted the JWT from a JSON field.',
    jwtFromCookie: 'Extracted the JWT from a Cookie field.',
    jwtFromUrlQuery: 'Extracted the JWT from a URL query parameter.',
    jwtHasSignature:
        'A signature segment is present, but it was not verified locally.',
    jwtNoSignature:
        'No signature segment, so only the contents can be inspected.',
    jwtAlgorithm: (alg) => 'Algorithm alg: $alg.',
    jwtType: (typ) => 'Type typ: $typ.',
    jwtAlgNone: 'alg=none, so the token carries no cryptographic signature.',
    jwtKeyId: (kid) => 'Contains a key ID kid: $kid.',
    jwtExpired: 'The token has expired.',
    jwtNotExpired: 'The token has not expired yet.',
    jwtNoExpiry: 'No expiry time exp.',
    jwtNotYetValid: 'The token is not valid yet.',
    jwtNbfReached: 'The token has reached its nbf validity time.',
    jwtHasIssuedAt: 'Contains an issued-at time iat.',
    jwtHasAudience: 'Contains an audience aud.',
    jwtHasIssuer: 'Contains an issuer iss.',
    jwtHasSubject: 'Contains a subject sub.',
  );
}
