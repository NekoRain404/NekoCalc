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
  combination,
  statistics,
  ohmsLaw,
  voltageDivider,
  rcFilter,
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

/// 中文：**产出方写下的一条结论**——当一条结果的值不是一个数、而是一句有语义的判断时
///       （`'未回收'`、`'会下滑'`、`'无解'`、`'过渡'`…），产出方在这里写下它是**哪一条**结论，
///       句子由这张表自己带着走（[sentence]）。
///
///       ### 它修的是什么
///
///       八个 `tool_insights_*.dart` 里有一批评据是**回读那句给用户看的话**：
///       `toolResultText(results, '简单回收期') == '未回收'`、`state == '会下滑'`、
///       `relation == '无解'`、`delta != '在范围内'`… **十八行、十九次比较**（这一轮逐处数过：
///       量它的那条命令是 `grep -n "[!=]= '…'" lib/domain/usecases/tool_insights*.dart`，
///       去注释后数出 19 次；改完之后同一个命令的输出是 0 行）。
///       那与 `hasError` 修的是**同一类**缺陷的第二半：词一旦换语言或改措辞，判据静默变成永远
///       为假——下游那句提示不再出现，没有异常、没有日志。`hasError` 那一半修完时这些句子
///       **还不是错误**（`'未回收'`、`'无穷大'`、`'压差不足'` 旧判据一个都不认），
///       所以它们当时被留在源码里；这一轮把这一半也收进字段。
///
///       ### 值仍然是那句话，一个字都没动
///
///       [sentence] 就是屏幕上那句话，逐字节与它从前在产出方源码里的写法相同（中文必须不变）。
///       改的只是**判据从哪来**：下游读 [ToolResult.conclusion]，不再回读那句话。
///
///       ### 为什么不是「一个布尔」
///
///       因为这些结论**互不相同、而且可以并列**：同一个标签上 `'会下滑'` 与 `'摩擦可抵住'`
///       是两个相反的结论，`'层流'` / `'过渡'` / `'湍流'` 是三支。一个布尔表达不了「是哪一条」，
///       而枚举能，并且**加一条结论时下游的 `switch` 编译不过**。
///
///       ### 哪些句子进来、哪些不进来
///
///       进来的**只有被下游判据读过的那些**——也就是今天源码里真的出现过
///       `xText == '这句话'` 的那些（外加**三处**同义的 `'无穷大'`——`'坡度'`、`'跨度/挠度'`、
///       `'Q值(串联)'`，判据只读其中一处，但值是同一句话，三处都按同一张表写出去，
///       免得同一句话在源码里留三份）。`'层流'`、`'湍流'`、`'零向量'`、`'一般夹角'`、
///       `'任意实数'`、`'可调节'`、`'有效'`、`'对数有效'` 这些**没有被判据读过**，
///       所以它们不进表、照旧是普通字面量：**这份枚举是判据的身份证，不是值字典。**
///
/// English: **a conclusion the producer writes down** — when a result's value is not a number but a
///          meaningful verdict (`'未回收'`, `'会下滑'`, `'无解'`, `'过渡'`, …) the producer writes
///          down **which** conclusion it is, and the sentence travels with the table ([sentence]).
///
///          ### What it fixes
///
///          The eight `tool_insights_*.dart` files held a set of judgements that **read the sentence
///          shown to the user back**: `toolResultText(results, '简单回收期') == '未回收'`,
///          `state == '会下滑'`, `relation == '无解'`, `delta != '在范围内'` … **eighteen lines, nineteen comparisons**
///          (counted site by site this round; after the change the same count is zero lines). That is the **second half of the same class** `hasError` fixed: change a word
///          or a language and the judgement silently becomes permanently false — the hint line
///          downstream stops appearing, with nothing thrown and nothing logged. When the `hasError`
///          half was fixed these sentences **were not errors** (the old predicate matched none of
///          `'未回收'`, `'无穷大'`, `'压差不足'`), so they were left in the source; this round collects
///          that half into a field too.
///
///          ### The value is still the sentence, unmoved by one character
///
///          [sentence] is what is on screen, byte-identical to how it used to be written in the
///          producer's source (the Chinese must not move). What changes is **where the judgement comes
///          from**: downstream reads [ToolResult.conclusion] instead of the sentence.
///
///          ### Why not "a boolean"
///
///          Because the conclusions **differ and can sit side by side**: on one label `'会下滑'` and
///          `'摩擦可抵住'` are opposite verdicts, and `'层流'` / `'过渡'` / `'湍流'` are three branches.
///          A boolean cannot say "which one"; an enum can, and **a downstream `switch` fails to
///          compile when a conclusion is added**.
///
///          ### Which sentences get in, and which do not
///
///          Only the ones **a downstream judgement actually read** — the ones a literal
///          `xText == 'this sentence'` really appeared for in the source today (plus **three** same-word
///          `'无穷大'` sites — `'坡度'`, `'跨度/挠度'`, `'Q值(串联)'`; the judgement reads only one of them,
///          but the value is that one sentence, so all three write it through the same table rather than
///          leaving it in three places in the source). `'层流'`, `'湍流'`, `'零向量'`,
///          `'一般夹角'`, `'任意实数'`, `'可调节'`, `'有效'`, `'对数有效'` are **not read by any
///          judgement**, so they are not in the table and stay ordinary literals: **this enum is the
///          judgement's identity card, not a dictionary of values.**
enum ToolResultConclusion {
  /// 中文：`未回收`——按当前净收益（或折现现金流）收不回投入。
  /// English: `未回收` — the investment is not recovered by the current net return (or discounted
  ///          cash flow).
  neverRecovers('未回收'),

  /// 中文：`会下滑`——沿斜面分力超过摩擦上限。
  /// English: `会下滑` — the force along the incline exceeds the friction limit.
  slidesDown('会下滑'),

  /// 中文：`摩擦可抵住`——净下滑力为负。
  /// English: `摩擦可抵住` — the net downhill force is negative.
  frictionHolds('摩擦可抵住'),

  /// 中文：`无穷大`——分母为 0（挠度为 0、工作应力为 0）那一支的读数。
  /// English: `无穷大` — the reading of the branch whose denominator is 0 (zero deflection, zero
  ///          working stress).
  infinite('无穷大'),

  /// 中文：`过渡`——雷诺数落在过渡区。
  /// English: `过渡` — the Reynolds number lands in the transition range.
  transition('过渡'),

  /// 中文：`超量程`——输入电压落在 0~Vref 之外。
  /// English: `超量程` — the input voltage sits outside 0~Vref.
  overRange('超量程'),

  /// 中文：`压差不足`——Vin 没有高出 Vout 足够的 dropout。
  /// English: `压差不足` — Vin is not far enough above Vout for the dropout.
  insufficientHeadroom('压差不足'),

  /// 中文：`制动/回馈`——功率为负。
  /// English: `制动/回馈` — the power is negative.
  braking('制动/回馈'),

  /// 中文：`无解`——方程（组）在实数域无解。
  /// English: `无解` — the equation (system) has no solution over the reals.
  noSolution('无解'),

  /// 中文：`无穷多解`——方程组的两条直线重合或退化。
  /// English: `无穷多解` — the system's two lines coincide or have degenerated.
  infiniteSolutions('无穷多解'),

  /// 中文：`恒等式`——`a=0` 且 `b=0`，任意实数都满足。
  /// English: `恒等式` — `a=0` and `b=0`, so every real number satisfies it.
  identity('恒等式'),

  /// 中文：`唯一解`——`a` 不为 0。
  /// English: `唯一解` — `a` is not 0.
  uniqueSolution('唯一解'),

  /// 中文：`对数无效`——`x` 不大于 0，`ln(x)` 一类在实数域没有定义。
  /// English: `对数无效` — `x` is not greater than 0, so `ln(x)`-style expressions have no real
  ///          value.
  logUndefined('对数无效'),

  /// 中文：`同向平行`——叉积接近 0 且点积不小于 0。
  /// English: `同向平行` — the cross product is near 0 and the dot product is not negative.
  parallelAligned('同向平行'),

  /// 中文：`反向平行`——叉积接近 0 且点积为负。
  /// English: `反向平行` — the cross product is near 0 and the dot product is negative.
  parallelOpposite('反向平行'),

  /// 中文：`垂直`——点积接近 0。
  /// English: `垂直` — the dot product is near 0.
  perpendicular('垂直'),

  /// 中文：`在范围内`——体重落在健康区间里，所以没有差值可报。
  /// English: `在范围内` — the weight is inside the healthy range, so there is no difference to
  ///          report.
  withinRange('在范围内');

  const ToolResultConclusion(this.sentence);

  /// 中文：这条结论在屏幕上那句话。**逐字节就是它从前在产出方源码里的写法**——
  ///       中文一个字都没动，改的只是判据从哪来。
  /// English: what this conclusion reads on screen. **Byte for byte how it used to be written in the
  ///          producer's source** — not one character of Chinese moved; only where the judgement comes
  ///          from changed.
  final String sentence;
}

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
    this.conclusion,
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
        isInvalidMarker = true,
        // 中文：那条记号不是一条「结论」（结论是产出方给出的判断，记号是「算不出来」），
        //       所以这里令牌为空——`hasError` 与 `conclusion` 问的是两个问题。
        // English: the marker is not a "conclusion" (a conclusion is a verdict the producer reached;
        //          the marker says it could not be produced), so the token is empty here — `hasError`
        //          and `conclusion` ask two different questions.
        conclusion = null;

  /// 中文：**产出方说「这条结果是一条结论」**——值就是那条结论的句子（从
  ///       [ToolResultConclusion.sentence] 取，不在这里另写一遍），令牌一起写下。
  ///
  ///       写不出「值是『未回收』却带着别的令牌」的结果，因为值根本不在这里传：
  ///       这条构造路只有令牌一个入口。**混合情形**（同一格里有一支是结论、另一支不是，例如
  ///       `'层流'` / `'过渡'` / `'湍流'`）走主构造函数的 `conclusion:` 具名参数，值与令牌分两处写，
  ///       由 `tool_result_conclusion_test.dart` 的电池逐条钉住它们必须一致。
  ///
  ///       **它是 factory 不是 const 构造函数**：值要从枚举的字段上取，而 Dart 的常量构造函数
  ///       不允许访问参数的字段（实测：`conclusion.sentence` 编不过）。const 与否在这里不可观测。
  /// English: **the producer says "this result is a conclusion"** — the value is that conclusion's
  ///          sentence (taken from [ToolResultConclusion.sentence], not written a second time here),
  ///          with the token written alongside.
  ///
  ///          A result whose value is `'未回收'` but which carries some other token cannot be written,
  ///          because the value is not passed in at all: this road has the token as its only entry.
  ///          **Mixed cases** (where one branch of a cell is a conclusion and another is not, such as
  ///          `'层流'` / `'过渡'` / `'湍流'`) go through the main constructor's `conclusion:` named
  ///          parameter, with value and token written in two places, and
  ///          `tool_result_conclusion_test.dart`'s battery pins that the two agree.
  ///
  ///          **It is a factory rather than a const constructor**: the value has to be read off the
  ///          enum's field, and Dart's constant constructors may not access a parameter's fields
  ///          (measured: `conclusion.sentence` fails to compile). Whether it is const is not
  ///          observable here.
  factory ToolResult.conclusion(
    String label,
    ToolResultConclusion conclusion,
    String unit, {
    bool primary = false,
    bool hasError = false,
  }) {
    return ToolResult(
      label,
      conclusion.sentence,
      unit,
      primary: primary,
      hasError: hasError,
      conclusion: conclusion,
    );
  }

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

  /// 中文：这条结果是一条**结论**（[ToolResultConclusion]）时的令牌；值是别的什么时为 `null`。
  ///       **判据读这里，不读 [value]。** 理由与病史见那个枚举的文档。
  /// English: the token when this result is a **conclusion** ([ToolResultConclusion]); `null` when the
  ///          value is anything else. **A judgement reads this, never [value].** The reasons and the
  ///          history are on that enum's docs.
  final ToolResultConclusion? conclusion;

  /// 中文：这条结果的值**就是那条「无效」记号本身**——不是「含有它的某句话」。
  ///       与 [hasError] 是两个问题：`(0, 无效)` 这种拼出来的值是错误（`hasError` 为真），
  ///       但它的值不是那条记号（这里为假）。下游读「这条回来了没有」的地方看这个旗标。
  /// English: Whether this result's value **is the `无效` marker itself** — not "some sentence that
  ///          contains it". That is a different question from [hasError]: an assembled value such as
  ///          `(0, 无效)` is an error (`hasError` true) but its value is not the marker (false here).
  ///          Sites downstream that ask "did this one come back?" read this flag.
  final bool isInvalidMarker;
}
