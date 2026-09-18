import '../utils/number_formatter.dart';
import 'math_result.dart';

/// 中文：**带单位结果的显示取整**——用户设置里的「小数位数」对一个「量」的含义。
///
///       带单位的引擎结果（`-0.08726646259971648 rad`、`3.106855961186670 mi`）**进不了
///       `formatNumber`**：那个函数要一个 `double`，而这一份显示文本末尾带着单位，`decimalValue`
///       因此为 null，结果整份原样上屏——同一个屏幕上于是出现两种行为：`1÷3` 显示 `0.333333`
///       （6 位），`-5deg to rad` 显示 16 位。设备实测（同一台、同一设置、相差几分钟）：
///
///       | 表达式 | 屏幕 | 设置 | 判定 |
///       |---|---|---|---|
///       | `1÷3` | `= 0.333333` | 6 位 | 取整生效 |
///       | `-5deg to rad` | `= -0.08726646259971648 rad` | 6 位 | **没生效** |
///
///       这个函数补上那一步：**数取整、单位原样、值不动**。它只回答一件事——「这一份结果的数字
///       部分该写成几个小数」，答案是一个字符串；`null` 表示**这一次不取整，原样上屏**（下面每一条
///       拒绝的理由都写明了）。
///
///       **取整用的仍然是 [formatNumber]，没有第二份取整实现**：这个函数只负责把「数 + 单位」拆开、
///       把数交给那一个实现、再把单位原样接回去。写法的规矩（科学计数法的门限、末尾零的裁剪）因此
///       与屏幕上每一个别的数字逐字相同。
///
///       **值的部分不许动**：拆出来的数字走的是应用**唯一**那道「文本 → 可用 double」的门
///       （[MathResult.decimalValueOf]），装不下就整份不取整（见下面第 3 条）；单位那一截
///       **逐字节照抄**，一个字符都不重新拼。取整只改数字的写法，不改它是什么数。
///
///       拒绝的四条，缺一不可：
///
///       1. **只有两种种类在范围内**（[EngineResultKind.conversion]、[EngineResultKind.quantity]）。
///          它们是引擎判出来的「一次换算的结果」与「一个量」——形状是**数 × 单位**，所以「数字部分」
///          是一个有意义的东西。别的种类要么上不了屏（`unit`/`unitMismatch`，[MathResult.isDisplayable]
///          拒绝）、要么文本里根本没有「一个数」：矩阵是一整片数（`[1  2; 3  4]`）、复数（`1 + 2i`）
///          与符号式（`2x`）里的数字只是**其中一个**因子，把小数位数施加到它们身上不是在执行这个设置
///          的含义。（`5 km + 3 s` 那种「算不出来的加法」是 `unit`，连这条门都过不了——它不是量。）
///       2. **文本必须是「数字 + 空格 + 单位」这个形状**，而且是**严格**的形状：数字是完整的一段十进制
///          （符号、小数点、指数都算它的，`1.5e+3 km` 也认），后面跟着空格，再后面是一个**不含空白**
///          的单位记号。这不是 `split(' ')`：那个写法会把 `5 m^−2`、`m/s²`、`N·m` 这类记号切坏，
///          也会把 `5 km + 3 s` 的 `+ 3 s` 当成单位。单位那一截允许带数字、允许带 `^`、`−`、`·`、`/`
///          （实测的印法：`m/s²`、`m^−2`、`N·m`、`s·rad`），**只要求它是一个整块**；一块里只要出现
///          空白就整条不认——那正是「算式」与「量」在文本上分得开的地方。
///       3. **数字得装进一个 double**。放不下的原样上屏，与既有那条豁免逐字相同：`2^2000 m` 实测印
///          `1.148130695274255E599 km`，硬取整只能先把 `Infinity` 喂给 [formatNumber]（它印「无效」），
///          而 `Infinity` 是假值。下溢同理（`2^-2000` 那一份 `double.tryParse` 给 `0.0`，也是假的）。
///          这一条由 [MathResult.decimalValueOf] 一处判，与提交路径、粘贴路径、记忆寄存器同一处实现。
///       4. **形状认不出来就不动**：`0xFF`（进制换算的结果）、`$4.38`（引擎把货币符号印在数字**前面**，
///          `5 USD` 实测如此）都落在这里。拿不准时原样上屏——那是今天的行为，不是新的错值。
///
///       **单位为什么不必再查一遍表**：能到这里的种类是引擎自己判的「数 × 单位」，而输入侧是闭的
///       （翻译层只放行应用词表与单位表，见 [EngineResultKind.quantity] 的注释）。这个函数因此不猜
///       单位是什么，只把那一截原样搬运。
///
///       **表里那一行 `-5deg to rad` 的表达式写法是量过的**：能问到引擎的是**带空格**的
///       `-5 deg to rad`（或 `(-5) deg to rad`），写成 `-5deg to rad` 时 `deg` 是表外自由变量，
///       翻译层在引擎被问到之前就拒绝了它，屏幕上根本没有这个错值。错值本身与成因没有变，只是那一栏
///       的拼法要写对——`engineExpressionFor` 两种都量过。
/// English: **display rounding for unit-carrying results** — what the user's "decimal places" setting
///          means for a quantity.
///
///          A unit-carrying engine result (`-0.08726646259971648 rad`, `3.106855961186670 mi`) **cannot
///          enter `formatNumber`**: that function wants a `double`, while this display text ends in a
///          unit, so `decimalValue` is null and the whole result goes to the screen as it stands. One
///          screen then showed two behaviours: `1÷3` read `0.333333` (6 places) while `-5deg to rad`
///          read 16 digits. Measured on the device (same phone, same settings, minutes apart):
///
///          | expression | screen | setting | verdict |
///          |---|---|---|---|
///          | `1÷3` | `= 0.333333` | 6 places | honoured |
///          | `-5deg to rad` | `= -0.08726646259971648 rad` | 6 places | **ignored** |
///
///          This function supplies that step: **round the number, copy the unit, never move the
///          value**. It answers exactly one question — "how many decimal places should this result's
///          numeric part be written with" — and the answer is a string; `null` means **do not round
///          this time, show it as it stands** (each refusal has its reason below).
///
///          **The rounding is still [formatNumber]; there is no second implementation**: this function
///          only splits "number + unit", hands the number to that one implementation, and puts the
///          unit back verbatim. The spelling rules (the scientific-notation thresholds, the trailing
///          zeros) are therefore character-for-character those of every other number on screen.
///
///          **The value may not move**: the split-out number goes through this app's **single**
///          "text → usable double" gate ([MathResult.decimalValueOf]) and everything that does not
///          fit is left unrounded (item 3); the unit stretch is **copied byte for byte**, not one
///          character is re-assembled. Rounding changes how the number is written, not what it is.
///
///          Four refusals, all of them necessary:
///
///          1. **Only two kinds are in scope** ([EngineResultKind.conversion],
///             [EngineResultKind.quantity]). Those are the engine's own "the result of one conversion"
///             and "a quantity" — their shape is **a number times a unit**, so "the numeric part" is a
///             meaningful thing. The other kinds either never reach the screen (`unit`/`unitMismatch`,
///             refused by [MathResult.isDisplayable]) or hold no single number: a matrix is a field of
///             numbers (`[1  2; 3  4]`), and the number inside a complex (`1 + 2i`) or a symbolic
///             result (`2x`) is only **one factor** — applying a decimal-place count to it is not
///             what that setting means. (`5 km + 3 s`, an addition the engine could not evaluate, is
///             `unit` and does not pass this gate at all: it is not a quantity.)
///          2. **The text has to have the "number, space, unit" shape**, and **strictly**: the number
///             is one complete decimal stretch (its sign, point and exponent included, so `1.5e+3 km`
///             counts) followed by a space and then a unit token **containing no whitespace**. This is
///             not `split(' ')`: that would cut `5 m^−2`, `m/s²` and `N·m` in half, and would read the
///             `+ 3 s` of `5 km + 3 s` as a unit. The unit stretch may carry digits and `^`, `−`, `·`
///             or `/` (measured prints: `m/s²`, `m^−2`, `N·m`, `s·rad`) — all that is asked is that it
///             be **one block**; a block containing whitespace fails the whole match, and that is
///             exactly where "an expression" and "a quantity" come apart in text.
///          3. **The number has to fit a double.** What does not fit is shown as it stands, verbatim
///             as the existing exemption does: `2^2000 m` measures `1.148130695274255E599 km`, and
///             forcing it through [formatNumber] would mean feeding in `Infinity` (it prints `无效`) —
///             a false value. Underflow is the same story (`2^-2000`'s text parses to `0.0`, equally
///             false). This one is judged by [MathResult.decimalValueOf] alone, the same
///             implementation the submit path, the paste path and the memory register use.
///          4. **An unrecognised shape is left alone**: `0xFF` (a base conversion's result) and
///             `$4.38` (the engine prints currency symbols **before** the number — measured on
///             `5 USD`) both land here. When in doubt, show it as it stands — that is today's
///             behaviour, not a new wrong value.
///
///          **The unit needs no second table lookup**: the kinds that reach here are the engine's own
///          "a number times a unit", and the input side is closed (the translation lets through only
///          the app vocabulary and the unit table; see [EngineResultKind.quantity]). This function
///          therefore never guesses what a unit is — it copies that stretch as it stands.
///
///          **The expression spelling in that table's row is a measured fact**: what reaches the
///          engine is the **spaced** `-5 deg to rad` (or `(-5) deg to rad`); written `-5deg to rad`,
///          `deg` is a free variable outside the table and the translation refuses it before the
///          engine is asked, so that screen never shows this wrong value at all. The wrong value and
///          its cause are unchanged — only that column's spelling has to be right, and both were
///          measured through `engineExpressionFor`.
String? roundedQuantityDisplayText(
  MathResult result, {
  required int precision,
  required bool groupThousands,
}) {
  if (!_roundableKinds.contains(result.resultKind)) return null;
  final match = _numberThenUnit.firstMatch(result.displayText.trim());
  if (match == null) return null;
  final amount = MathResult.decimalValueOf(match.group(1)!);
  if (amount == null) return null;
  return '${formatNumber(amount, precision: precision, groupThousands: groupThousands)}'
      ' ${match.group(2)!}';
}

/// 中文：范围内的两种种类——「一次成功的换算」与「一个量」。理由见函数注释第 1 条。
/// English: the two kinds in scope — "a conversion that happened" and "a quantity". See item 1 on the
///          function.
final Set<EngineResultKind> _roundableKinds = <EngineResultKind>{
  EngineResultKind.conversion,
  EngineResultKind.quantity,
};

/// 中文：`数字 单位` 的形状：一段**完整**的十进制数（可带符号与指数）、**至少一个空格**、
///       然后是一个**不含空白**的单位记号。整串必须从头到尾吻合——前面多一个字符（`0xFF`、
///       `$4.38`）就整条不认。
///
///       空格写成 ` +` 而不是 ` `：引擎实测是一个普通空格（U+0020，`od` 量过），多认一个只是
///       容错；真正的判据是「数后面必须先是空格」，`5km` 那种粘在一起的写法因此不认。
/// English: the `number unit` shape: one **complete** decimal number (sign and exponent allowed),
///          **at least one space**, then a unit token **containing no whitespace**. The whole string
///          must match — one extra character in front (`0xFF`, `$4.38`) fails the match.
///
///          The space is written ` +` rather than ` `: the engine prints a plain U+0020 (measured with
///          `od`), and accepting one more is only tolerance; the real judgement is "a space must come
///          right after the number", which is why a glued `5km` is refused.
final RegExp _numberThenUnit =
    RegExp(r'^([+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?) +(\S+)$');
