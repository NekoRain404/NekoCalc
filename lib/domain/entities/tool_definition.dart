import '../../core/utils/number_formatter.dart';
import 'tool_category.dart';

enum ToolKind {
  quadratic,
  linearSystem,
  percentage,
  exponentialLog,
  probability,
  complex,
  vector,
  triangle,
  circle,
  scaleRatio,
  matrix,
  linearEquation,
  proportion,
  combination,
  statistics,
  ohmsLaw,
  voltageDivider,
  rcFilter,
  dbm,
  resistorNetwork,
  capacitorNetwork,
  inductorNetwork,
  ledResistor,
  opAmpGain,
  adcResolution,
  rmsPeak,
  lcResonance,
  dcdcFeedback,
  ldoPower,
  capacitorCharge,
  batteryLife,
  pcbCurrent,
  wireVoltageDrop,
  timer555,
  thermalRise,
  gearRatio,
  torquePower,
  spring,
  cylinder,
  force,
  pulleyRatio,
  screwLead,
  pressureForce,
  friction,
  inclinedPlane,
  beamBending,
  stressStrain,
  sectionArea,
  safetyFactor,
  flowVelocity,
  materialWeight,
  loan,
  annuity,
  installment,
  breakEven,
  electricityCost,
  compound,
  profitMargin,
  roi,
  discount,
  tax,
  inflation,
  npv,
  length,
  pressure,
  voltage,
  frequency,
  mass,
  area,
  volume,
  speed,
  temperature,
  dataSize,
  timeUnit,
  accelerationUnit,
  forceUnit,
  powerUnit,
  energyUnit,
  angleUnit,
  currentUnit,
  resistanceUnit,
  capacitanceUnit,
  inductanceUnit,
  torqueUnit,
  flowUnit,
  motion,
  freeFall,
  workPower,
  kineticEnergy,
  density,
  concentration,
  idealGas,
  heat,
  wavelength,
  halfLife,
  ph,
  bmi,
  fuelEconomy,
  staticOnly,
}

class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.kind,
    required this.inputs,
    required this.formula,
    required this.explanation,
    this.group = '常用',
    this.featured = false,
  });

  final String id;
  final String title;
  final String description;
  final ToolCategory category;
  final ToolKind kind;
  final List<ToolInputDefinition> inputs;
  final String formula;
  final String explanation;
  final String group;
  final bool featured;
}

class ToolInputDefinition {
  const ToolInputDefinition({
    required this.key,
    required this.label,
    required this.unit,
    this.defaultValue,
    this.optional = false,
  });

  final String key;
  final String label;
  final String unit;
  final double? defaultValue;
  final bool optional;
}

/// 中文：产不出数值时那个结果的**值**。它是一句**给用户看的话**，所以它只该被产出方写下，
///       不该被谁拿去比较——比较它的地方一律改看旗标，见 [ToolResult.hasError]。
/// English: The **value** of a result that could not be produced. It is a **sentence meant for the
///          user**, so only a producer should ever write it, and nobody should compare against it —
///          every site that did now reads a flag instead; see [ToolResult.hasError].
const String invalidResultValue = '无效';

/// 中文：一条工具结果。**「这条是不是错误」是它的字段，不是从那句话里比出来的。**
///
///       原先这件事散在三处，全都是拿**要显示给用户的那句话**当判据：
///       `tool_detail_controller.dart` 与 `tool_insights.dart` 各一份
///       `_resultNeedsAttention`（`value.contains('无效'/'不能'/'不可'/'错误')`），
///       外加八个 `tool_insights_*.dart` 共 119 处 `xText == '无效'`。
///       那两句中文一旦换语言或改措辞，判据就静默变成假：错误结果会被当成正常答案收进
///       「可用结果」、屏幕上错误配色会翻成正常配色、下游的提示行会跟着一起错。没有任何东西会抛。
///
///       现在由**产出方**写下来：造一个错误结果用 [ToolResult.invalid]，
///       算一个数值结果用 [ToolResult.number]——它把「数值是不是有限数」这件事当场写成旗标——
///       其余情形（几句话拼出来的值）由产出方在构造时明写 [hasError]。
///
/// English: One tool result. **Whether it is an error is a field, not something compared out of the
///          value sentence.**
///
///          This used to live in three places, all of them using **the sentence shown to the user**
///          as the branch condition: one copy of `_resultNeedsAttention` in
///          `tool_detail_controller.dart` and one in `tool_insights.dart`
///          (`value.contains('无效'/'不能'/'不可'/'错误')`), plus 119 occurrences of
///          `xText == '无效'` spread over eight `tool_insights_*.dart` files. The day those Chinese
///          sentences change language or wording the conditions silently become false: an error
///          result is collected as a usable answer, the error colours on screen flip to normal, and
///          the hint lines downstream follow. Nothing throws.
///
///          Now the **producer** writes it down: build an error result with [ToolResult.invalid],
///          compute a numeric one with [ToolResult.number] — which turns "is this number finite?"
///          into the flag on the spot — and for everything else (values assembled out of several
///          sentences) state [hasError] at the construction site.
class ToolResult {
  const ToolResult(
    this.label,
    this.value,
    this.unit, {
    this.primary = false,
    this.hasError = false,
    this.isInvalidMarker = false,
  }) : assert(
          value != invalidResultValue || isInvalidMarker,
          '值是那条「无效」记号时，旗标必须一起写下——请走 ToolResult.invalid 或 '
          'ToolResult.number，别用这个构造函数写那条记号 / a value equal to the invalid '
          'marker must carry the flag with it: use ToolResult.invalid or ToolResult.number',
        );

  /// 中文：产出方明确说「这条算不出来」。值当场就是那条记号，旗标当场写下——
  ///       **这句话与这个旗标从此分不开**，写不出「值是『无效』却说它不是错误」的结果。
  /// English: The producer states plainly "this one cannot be produced". The value is the marker
  ///          right here and the flag is written right here — **sentence and flag can no longer come
  ///          apart**, and a result whose value is the marker but which claims not to be an error
  ///          cannot be written.
  const ToolResult.invalid(this.label, this.unit, {this.primary = false})
      : value = invalidResultValue,
        hasError = true,
        isInvalidMarker = true;

  /// 中文：产出方给的是**数值**，不是句子。`null` 表示这条算不出来；数值不是有限数时
  ///       `formatNumber` 会吐那条记号——两种情形都在这里当场变成旗标。
  ///       **默认「没写旗标」是 `false`**：与旧判据对不上号的句子（`'未回收'`、`'无穷大'`、
  ///       `'压差不足'`）今天就不算错误，今天也不该算——见 `tool_result_error_flag_test.dart`。
  /// English: The producer hands over a **number**, not a sentence. `null` means it cannot be
  ///          produced; a non-finite number is what makes `formatNumber` emit the marker — both
  ///          cases become the flag right here. **The default when no flag is written is `false`**:
  ///          sentences the old predicate did not match (`'未回收'`, `'无穷大'`, `'压差不足'`) are not
  ///          errors today and must not become ones — see `tool_result_error_flag_test.dart`.
  factory ToolResult.number(
    String label,
    num? value,
    String unit, {
    int precision = 6,
    bool primary = false,
  }) {
    if (value == null) {
      return ToolResult(label, invalidResultValue, unit,
          primary: primary, hasError: true, isInvalidMarker: true);
    }
    final isFinite = value.isFinite;
    return ToolResult(
      label,
      formatNumber(value, precision: precision),
      unit,
      primary: primary,
      hasError: !isFinite,
      isInvalidMarker: !isFinite,
    );
  }

  final String label;
  final String value;
  final String unit;
  final bool primary;

  /// 中文：这条结果是不是一条错误。[ToolResult.invalid] 与 [ToolResult.number] 各自写下它；
  ///       几句话拼出来的值由产出方在构造点上明写。
  /// English: Whether this result is an error. [ToolResult.invalid] and [ToolResult.number] each
  ///          write it; values assembled out of several sentences state it at the construction
  ///          site.
  final bool hasError;

  /// 中文：屏幕上那一格——**错误结果后面不粘单位**（`无效V` 读起来像个数）。
  ///       原先这件事在两个文件里各写了一遍（`tool_detail_controller.dart` 与
  ///       `tool_insights.dart` 的 `_resultValueWithUnit`），两处逐字相同、也都踩着那句
  ///       中文判据；现在它们都读这个 getter，判据那一侧是 [hasError]。
  /// English: The cell on screen — **no unit is glued onto an error result** (`无效V` reads like a
  ///          number). This used to be written twice (`_resultValueWithUnit` in both
  ///          `tool_detail_controller.dart` and `tool_insights.dart`), byte-identical, and both
  ///          standing on that Chinese predicate; both now read this getter, and the judgement behind
  ///          it is [hasError].
  String get valueWithUnit {
    final trimmedValue = value.trim();
    final trimmedUnit = unit.trim();
    if (trimmedUnit.isEmpty || hasError) return trimmedValue;
    return '$trimmedValue$trimmedUnit';
  }

  /// 中文：这条结果的值**就是那条「无效」记号本身**——不是「含有它的某句话」。
  ///       与 [hasError] 是两个问题：`(0, 无效)` 这种拼出来的值是错误（`hasError` 为真），
  ///       但它的值不是那条记号（这里为假）。下游读「这条回来了没有」的地方看这个旗标。
  /// English: Whether this result's value **is the `无效` marker itself** — not "some sentence that
  ///          contains it". That is a different question from [hasError]: an assembled value such as
  ///          `(0, 无效)` is an error (`hasError` true) but its value is not the marker (false here).
  ///          Sites downstream that ask "did this one come back?" read this flag.
  final bool isInvalidMarker;
}
