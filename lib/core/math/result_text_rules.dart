/// 中文：**结果文本这一层上的判据**——「这一段文本能不能当数字用」与「它能不能显示」。
///
///       它们原来住在 `MathResult` 里（都是不碰 `this` 的静态成员），本轮搬到库的顶层：那个类型
///       回答的是「屏幕上这一份结果长什么样、能不能画、写回去写什么」，而这两个问题问的是**文本**。
///       `MathResult.isDisplayable` 自己的注释就把这条线画出来了——`MathResult.hasFiniteDecimal` 问的是
///       「能不能当数字用」，`isDisplayable` 问的是「能不能显示」，**两个判据不是同一个**：文本层
///       跟着这一半走，形状层（`resultKind` 与那个 `switch`）留在那个类型里。
///
///       **这些函数仍然各只有一份实现**：`MathResult` 的三个 getter（`decimalValue`、
///       `hasFiniteDecimal`、`displayTextIsParseable`）读的就是这里，别处没有第二份——那条
///       「实现只有这一处，再散开必然重演」的规矩跟着代码一起搬了过来。
///
/// English: **the judgements made on a result's text** — "may this text be used as a number" and
///          "may it be shown". They used to live on `MathResult` (every one of them a static that
///          never touches `this`) and moved to library level this round: that type answers "what
///          does this result look like, may it be drawn, what does it write back", while these two
///          questions are about the **text**. `MathResult.isDisplayable`'s own comment drew that
///          line — `MathResult.hasFiniteDecimal` asks "can this be used as a number", `isDisplayable` asks
///          "can this be shown", **two judgements and not the same one**: the text layer travels
///          with this half, the shape layer (`resultKind` and that `switch`) stays on the type.
///
///          **Each of these still has exactly one implementation**: `MathResult`'s three getters
///          (`decimalValue`, `hasFiniteDecimal`, `displayTextIsParseable`) read this file and no
///          second copy exists — the rule "the implementation lives in one place, scattering it
///          again would start the same drift" travelled with the code.
library;

/// 中文：从一段显示文本里提取十进制形态：去掉千分位与首尾空白，`double.tryParse` 不接受就返回
///       空串。旧求值器的显示文本正是从这里变成十进制形态的，也是全应用唯一一处「把显示文本当
///       数字看」的地方。
/// English: Extract the decimal form from a piece of display text: strip grouping separators and
///          surrounding whitespace, and return an empty string when `double.tryParse` rejects it.
///          This is how the legacy evaluator's display text becomes a decimal form, and the one
///          place in the app where display text is looked at as a number at all.
String decimalTextOf(String value) {
  final normalized = value.replaceAll(',', '').trim();
  if (double.tryParse(normalized) == null) return '';
  return normalized;
}

/// 中文：**一段十进制文本 → 一个可用的 double**，放不下时给 null。这是全应用唯一的实现，
///       提交路径、粘贴路径与任何要 double 的消费者都从这里过——写第二份的话，两份迟早会漂移
///       （这正是修复轮 2 要收的那个尾：守卫在提交路径上修好了，消费者的表达式分支却没有）。
///
///       判定按上面的顺序：空 → null；不是数 → null；不是有限（溢出成 `Infinity`、`NaN`）→ null；
///       解析出 0 而数字部分有非零数字（下溢）→ null。**它绝不返回 `Infinity`，也绝不返回一个
///       静默下溢的 0。**
/// English: **A piece of decimal text into a usable double**, or null when it does not fit. This is
///          the app's single implementation: the submit path, the paste path and any consumer that
///          needs a double all come through here — a second copy would eventually drift, which is
///          exactly the tail fix round 2 is collecting (the guard was fixed on the submit path
///          while a consumer's expression branch kept the old rule).
///
///          The order is as above: empty → null; not a number → null; not finite (overflowed to
///          `Infinity`, or `NaN`) → null; parsed 0 whose significand contains a non-zero digit
///          (underflow) → null. It **never returns `Infinity`, and never a silently underflowed
///          0**.
double? decimalValueOf(String decimalText) {
  if (decimalText.trim().isEmpty) return null;
  final parsed = double.tryParse(decimalText);
  if (parsed == null) return null;
  final value = usableDouble(parsed);
  if (value == null) return null;
  if (value == 0 && _hasNonZeroDigit(decimalText)) return null;
  return value;
}

/// 中文：一段文本能不能显示（`MathResult.isDisplayable` 用它判 `MathResult.displayText`）。**只拒绝两类**，都在字符串层面判：
///
///       1. **真正非有限的字面量**：`∞` / `-∞` / `+∞` / `infinity` / `-infinity` / `NaN`
///          （`ln(0)` 实测印成 `-infinity`）。这一条**不能省**：`-infinity` 在引擎那里是一个
///          Number，形状那一层会把它当 `EngineResultKind.number` 放行。
///
///       **空串为假**：没有十进制形态的失败回执不该被当成可显示的结果（那是 `EngineReply` 的
///       `ok: false` 那一类，由调用方处理）。
///
///       它**曾经还有第二条**：整个文本是「数字 运算符 数字」就当成「引擎没算」。那是一条举例
///       清单，只匹配一种写法，实测漏掉了 `i/0`、`(1+i)/0`、`matrix(...)/0`、`2 mod 0`、
///       `root(2,0)`、`x/0`。现在这一类由 `MathResult.resultKind` 的
///       `EngineResultKind.arithmetic` 从**结构上**挡住（引擎自己说这个结果是乘积/幂/函数调用），
///       不再看算式长什么样——所以那第二条被删掉了，而不是又补了几个例子。
///
///       实现**只有这一处**，与 [decimalValueOf] / `MathResult.hasFiniteDecimal` 放在一起——这个类已经挪过
///       三次，再散开必然重演。
/// English: Whether a piece of text may be displayed (`MathResult.isDisplayable` uses it on `MathResult.displayText`). The two things it rejects are judged at the
///          string level:
///
///          1. **genuinely non-finite literals**: `∞` / `-∞` / `+∞` / `infinity` / `-infinity` /
///             `NaN` (`ln(0)` prints as `-infinity`, measured).
///             measured). This clause **cannot be dropped**: `-infinity` is a Number on the engine's
///             side, and the shape layer would wave it through as `EngineResultKind.number`.
///
///          An **empty string is not displayable**: a failure receipt with no result is not a
///          result (that is `EngineReply`'s `ok: false` family, the caller's business).
///
///          It **used to be** a match of "the whole string equals `∞`/`infinity`/`NaN`", so a
///          non-finite value *nested inside an expression* (`infinity*i`) was displayed anyway.
///          Scanning by position covers that class, and the judgement is still about finiteness
///          rather than about a few examples.
///
///          This is the **only** implementation, and it lives beside [decimalValueOf] /
///          `MathResult.hasFiniteDecimal` — this class has moved three times already, and a second copy would
///          only start the same drift again.
bool textIsDisplayable(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  return !_nonFiniteToken.hasMatch(trimmed);
}

/// 中文：表示非有限值的记号，**在文本的任意位置**匹配（前后不能是标识符字符，免得撞上
///       `info`、`nanny` 这类名字）。两个拼法是 IEEE-754 那两类非有限值在**本桥的输出字母表**里的
///       唯一写法（符号位由 `+`/`-` 表示，不在这个记号里）。
/// English: the tokens denoting a non-finite value, matched **anywhere in the text** (no identifier
///          character on either side, so `info` or `nanny` cannot collide). The two spellings are the
///          only ones IEEE-754's two non-finite kinds take in **this bridge's output alphabet** (the
///          sign is a separate `+`/`-`; `∞` is the same value's other spelling).
final RegExp _nonFiniteToken =
    RegExp(r'(?<![A-Za-z_])(?:infinity|nan|∞)(?![A-Za-z_])', caseSensitive: false);

/// 中文：一个**已经算出来的** double 能不能交给消费者：`Infinity` / `NaN` 不能，其余（包括真正的 0）
///       都能。它判不了下溢——`double.tryParse('9.3e-603')` 给的是 `0.0`，一个 double 自己说不清
///       它是「真的是 0」还是「小到装不下」——所以**凡手里有文本的地方一律先走 [decimalValueOf]**，
///       只有拿到的是一个算出来的 double 时才用它。
/// English: Whether an *already computed* double may be handed to a consumer: `Infinity` / `NaN`
///          may not, everything else (a genuine 0 included) may. It cannot detect underflow —
///          `double.tryParse('9.3e-603')` yields `0.0`, and a double cannot say whether that is
///          "really zero" or "too small to store" — so **anywhere text is available, go through
///          [decimalValueOf] first**; use this only for a double that was computed.
double? usableDouble(double value) => value.isFinite ? value : null;

/// 中文：一段文本是不是一个有限数。见 `MathResult.hasFiniteDecimal`。
///
///       先 trim 再判：`double.tryParse` 自己会跳过首尾空白，而下面那个字面量正则不会，
///       于是 `' Infinity '` 会被判成有限数——这是等着被踩的坑（适配层先 trim 过，所以今天
///       走不到，但下一个调用方未必）。
/// English: Whether a piece of text is a finite number. See `MathResult.hasFiniteDecimal`.
///
///          Trims first: `double.tryParse` skips surrounding whitespace on its own while the
///          literal regex below does not, so `' Infinity '` used to come back as a finite number —
///          a trap waiting to be stepped on (the adapter trims before calling, so it is
///          unreachable today, but the next caller need not).
bool decimalTextIsFinite(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (double.tryParse(trimmed) == null) return false;
  return !_nonFiniteLiteral.hasMatch(trimmed);
}

/// 中文：`double.tryParse` 认得、但**不是有限数**的那两个字面量（大小写放宽只是兜底）。
/// English: The two literals `double.tryParse` accepts that are *not* finite numbers (the loose
///          casing is only a backstop).
final RegExp _nonFiniteLiteral =
    RegExp(r'^[+-]?(infinity|nan)$', caseSensitive: false);

/// 中文：数字部分里有没有非零数字（指数部分不算，`0e-999` 仍然是零）。用来识别下溢。
/// English: Whether the significand contains a non-zero digit (the exponent does not count —
///          `0e-999` is still zero). Used to recognise underflow.
bool _hasNonZeroDigit(String value) {
  final significand = value.split(RegExp('[eE]')).first;
  return RegExp('[1-9]').hasMatch(significand);
}
