import '../entities/tool_definition.dart';

const Set<String> textToolIds = {
  'base_convert',
  'prime_factor',
  'arithmetic_steps',
  'timestamp',
  'date_calc',
  'derive_steps',
  'uncertainty',
  'color_convert',
  'base64',
  'url_codec',
  'json_format',
  'ascii_unicode',
  'bitwise',
  'checksum',
  'uuid',
  'jwt_decode',
  'query_params',
  'html_entities',
  'regex_test',
  'text_stats',
  'csv_json',
  'fnv_crc',
  'custom_formula',
};

/// 中文：**点开不是详情页、而是计算页那个面板的工具**——今天是 `unit_convert` 一个。
///       它存在的理由与 [textToolIds] 相同：**"这个工具点开之后去哪"是工具自己的性质**，
///       写在一处、由 `openToolDetail` 一处读，别在两张屏幕上各写一遍。
///
///       名字里的"面板"就是键盘上 `CONV` 打开的那一个（`CalculatorPage._openUnitSheet` 与
///       `UnitPickerSheet`）。**不是第二个实现**：这里只声明"要去那个面板"，
///       面板本身仍只有那一份。
/// English: **tools that open the calculator's sheet rather than a detail page** — one today,
///          `unit_convert`. The reason it exists is the same as [textToolIds]': **where a tool goes
///          when opened is a property of the tool**, written once and read once in `openToolDetail`,
///          instead of being spelled out on two screens.
///
///          The sheet in the name is the one the keypad's `CONV` opens (`CalculatorPage._openUnitSheet`
///          and `UnitPickerSheet`). **It is not a second implementation**: this only declares "go to
///          that sheet"; the sheet itself stays one.
const Set<String> unitSheetToolIds = {
  'unit_convert',
};

extension ToolCapabilities on ToolDefinition {
  bool get usesTextDetail => textToolIds.contains(id);

  /// 中文：点开它要弹的是单位面板（见 [unitSheetToolIds]），不是详情页。
  /// English: opening it must raise the unit sheet (see [unitSheetToolIds]), not a detail page.
  bool get opensUnitSheet => unitSheetToolIds.contains(id);
}
