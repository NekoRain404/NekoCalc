/// 中文：**把一个十进制数写成另一个进制。**
///
///       这一条**不走引擎**，理由与日期计算、不确定度那两个工具同源（**"引擎能做"不等于
///       "该让引擎做"**），但这里还多一层——**引擎那条路是量出来的死路**：
///
///       | 调用 | `100 to hex` |
///       |---|---|
///       | `qalc -t`（CLI） | `0x64` ✓ |
///       | `Calculator::calculate(...)`（**应用桥用的那一个**） | `(100 / hex()) * hex()` ✗ |
///       | `Calculator::calculateAndPrint(...)` | `64` ✓ |
///
///       `Calculator.h:441` 的 `calculate` 把结尾的 `to` 当成**一次除法**（那个形参名字就叫
///       `make_to_division`，桥传的是 `true`），**只有 `calculateAndPrint` 处理 to-命令**——
///       它自己的文档写着这件事。单位换算两条路都行，所以这个坑只在**进制 / 罗马数字 / 分数**
///       这一族上露出来。
///
///       ⚠️ **这不是"引擎不支持"，是"应用问错了入口"。** 上一轮我把这一族记成"引擎支持"，
///       栽在**拿 CLI 的结果当库的行为**上。
///
///       **为什么在这里自己算是安全的**：这是一次**纯函数**变换，输入是一个十进制**文本**、
///       输出是一个数字串，中间没有浮点误差以外的自由度。`BigInt` 让整数部分**精确**，
///       连 `2^2000` 那种 602 位的值都算得对（再按位宽截断，截断处看得见）。
///       而且它**不依赖引擎 ⇒ 单测就能证完**——真机只能证明"我这一次看到了"。
///
///       **它不做的事**：不猜。读不出的文本、非有限的值、`2..36` 之外的进制，一律回 `null`，
///       由调用方照常印"没有答案"，**绝不印一个看起来像数字的东西**。
/// English: **write a decimal number in another base.**
///
///          This **does not go through the engine**, for the reason the date calculator and the
///          uncertainty tool share (**"the engine can" is not "the engine should"**), and here there
///          is one more layer — **the engine road is a measured dead end**:
///
///          | call | `100 to hex` |
///          |---|---|
///          | `qalc -t` (the CLI) | `0x64` ✓ |
///          | `Calculator::calculate(...)` (**the one the app's bridge uses**) | `(100 / hex()) * hex()` ✗ |
///          | `Calculator::calculateAndPrint(...)` | `64` ✓ |
///
///          `Calculator.h:441`'s `calculate` reads a trailing `to` as **a division** (the parameter is
///          literally named `make_to_division`, and the bridge passes `true`); **only
///          `calculateAndPrint` handles to-commands** — its own documentation says so. Unit conversions
///          work on both roads, so this hole only shows up on the **base / roman / fraction** family.
///
///          ⚠️ **This is not "the engine cannot do it", it is "the app asked the wrong entrance".** The
///          previous round recorded this family as "the engine supports it" and tripped over **taking a
///          CLI result for the library's behaviour**.
///
///          **Why computing it here is safe**: it is a **pure function** from a decimal **text** to a
///          digit string, with no freedom beyond floating-point error. `BigInt` makes the integer part
///          **exact**, so even a 602-digit `2^2000` comes out right (then truncated by width, with the
///          cut visible). And it **does not depend on the engine ⇒ the unit tests settle it** — a
///          device can only ever show "I saw it this once".
///
///          **What it does not do**: guess. An unreadable text, a non-finite value and a radix outside
///          `2..36` all return `null`, and the caller prints "no answer" as usual — **never something
///          that looks like a number**.
library;

/// 中文：数字字母表，`0-9` 之后接 `A-Z`（大写：屏幕上那颗键面上写的就是 `HEX`，
///       而 `A`–`F` 是计算器上的通行写法）。
/// English: the digit alphabet, `0-9` then `A-Z` (upper case: the key face reads `HEX`, and `A`–`F`
///          is the usual spelling on calculators).
const String _baseAlphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// 中文：**换算结果。** `digits` 已经按 [maxDigits] 截断（截断处有一个 `…`），
///       `truncated` 让调用方知道"这不是全部"——两者一起才诚实：光有那条串，
///       一个被截短的数看起来就是一个数。
/// English: **the conversion.** `digits` is already cut at [maxDigits] (with a `…` where it was cut)
///          and `truncated` tells the caller "this is not all of it" — the two together are what makes
///          it honest: the string alone would make a truncated number look like a number.
typedef BaseConversion = ({String digits, bool truncated});

/// 中文：把一个**十进制文本**写成 [radix] 进制，读不出来就回 `null`。
///
///       - 收：[科学计数法][`e`/`E`]、正负号、千分位分隔（空格、逗号、下划线、`'`）；
///       - 整数部分用 `BigInt`，**精确**；小数部分按 [maxDigits] 逐位乘除，够了就停并标记截断；
///       - [radix] 只收 `2..36`（字母表就 36 个符号）。
/// English: writes a **decimal text** in base [radix], or `null` when it cannot be read.
///
///          - accepts [scientific notation][`e`/`E`], a sign, and grouping separators (space, comma,
///            underscore, `'`);
///          - the integer part uses `BigInt` and is **exact**; the fraction is produced a digit at a
///            time up to [maxDigits], then marked truncated;
///          - [radix] accepts `2..36` only (the alphabet holds 36 symbols).
BaseConversion? convertToBase(
  String decimalText,
  int radix, {
  int maxDigits = 20,
}) {
  if (radix < 2 || radix > 36) return null;
  if (maxDigits < 2) return null;

  final cleaned = decimalText
      .trim()
      .replaceAll(RegExp(r"[\s,_']"), '')
      .replaceAll('E', 'e');
  if (cleaned.isEmpty) return null;

  var body = cleaned;
  var negative = false;
  if (body.startsWith('-') || body.startsWith('\u2212')) {
    negative = true;
    body = body.substring(1);
  } else if (body.startsWith('+')) {
    body = body.substring(1);
  }

  final parts = body.split('e');
  if (parts.length > 2) return null;
  final mantissa = parts[0];
  final exponent = parts.length == 2 ? int.tryParse(parts[1]) : 0;
  if (exponent == null) return null;
  if (!RegExp(r'^\d*\.?\d*$').hasMatch(mantissa)) return null;

  final dot = mantissa.indexOf('.');
  final integerText = dot < 0 ? mantissa : mantissa.substring(0, dot);
  final fractionText = dot < 0 ? '' : mantissa.substring(dot + 1);
  final digitText = '$integerText$fractionText';
  if (digitText.isEmpty) return null;
  final numerator = BigInt.tryParse(digitText);
  if (numerator == null) return null;

  // 中文：**先把整句话拼成一个分数，再一次性缩放**——中间不出现浮点，所以整数部分一位不差。
  //       `scale` 是分母上那个 10 的幂：`2.5` 是 `25/10`，`1.5e3` 是 `15 * 10^2`。
  // English: **build one fraction first, then scale it once** — no float appears in between, so the
  //          integer part is right to the last digit. `scale` is the power of ten in the denominator:
  //          `2.5` is `25/10`, `1.5e3` is `15 * 10^2`.
  final scale = fractionText.length - exponent;
  final scaled = scale > 0
      ? (numerator: numerator, denominator: _pow10(scale))
      : (numerator: numerator * _pow10(-scale), denominator: BigInt.one);
  return _render(
    scaled.numerator,
    scaled.denominator,
    radix,
    negative,
    maxDigits,
  );
}

/// 中文：`10^n`，`n >= 0`。**不用 `math.pow`**：那是 `double`，`10^602` 会变成近似值，
///       而这里每一个数字都要准。
/// English: `10^n` for `n >= 0`. **Not `math.pow`**: that is a `double`, `10^602` becomes an
///          approximation, and every digit here has to be right.
BigInt _pow10(int n) {
  var value = BigInt.one;
  final ten = BigInt.from(10);
  for (var index = 0; index < n; index++) {
    value *= ten;
  }
  return value;
}

/// 中文：把 `numerator / denominator` 写成 [radix] 进制。**整数部分精确**，小数部分最多补到
///       [maxDigits] 位。**"截断了没有"只有两个来源，都在这里算**：小数没除尽，
///       或者整串超过了位宽。调用方不需要先验——**先验会让"除尽了"和"没除尽"两件事有两个说法**。
/// English: writes `numerator / denominator` in base [radix]. **The integer part is exact** and the
///          fraction is filled to at most [maxDigits] places. **"Was it cut" has exactly two sources,
///          both computed here**: the fraction did not divide out, or the whole string exceeded the
///          width. The caller passes no prior — **a prior would give "divided out" and "did not" two
///          spellings**.
BaseConversion _render(
  BigInt numerator,
  BigInt denominator,
  int radix,
  bool negative,
  int maxDigits,
) {
  final zero = BigInt.zero;
  final base = BigInt.from(radix);
  var integer = numerator ~/ denominator;
  var remainder = numerator.remainder(denominator);

  final buffer = StringBuffer();
  if (integer == zero) {
    buffer.write('0');
  } else {
    final reversed = <String>[];
    while (integer > zero) {
      final digit = integer.remainder(base).toInt();
      reversed.add(_baseAlphabet[digit]);
      integer = integer ~/ base;
    }
    buffer.writeAll(reversed.reversed);
  }

  // 中文：**小数部分逐位乘除，用完位宽就停。** 停下来的原因只有两种，而**两种都算截断**：
  //       没除尽（`remainder != zero`），或者到了 [maxDigits] 位还没除尽。
  //       除尽了的那一种（`1/2` 在十进制是 `0.5`，在二进制是 `0.1`）**不算截断**——
  //       把它标成截断就等于告诉用户"还有位数没印"，而其实没有了。
  // English: **the fraction is produced a digit at a time and stops when the width runs out.** It
  //          stops for exactly two reasons and **both are truncation**: it did not divide out
  //          (`remainder != zero`), or [maxDigits] places passed without dividing out. The one that
  //          did divide out (`1/2` is `0.5` in decimal and `0.1` in binary) **is not truncation** —
  //          marking it so would tell the user "there are more digits", and there are not.
  var truncated = false;
  if (remainder != zero) {
    buffer.write('.');
    var written = 0;
    while (remainder != zero && written < maxDigits) {
      remainder *= base;
      buffer.write(_baseAlphabet[(remainder ~/ denominator).toInt()]);
      remainder = remainder.remainder(denominator);
      written++;
    }
    truncated = remainder != zero;
  }

  var text = negative ? '-${buffer.toString()}' : buffer.toString();
  if (text.length > maxDigits) {
    text = '${text.substring(0, maxDigits - 1)}…';
    truncated = true;
  }
  return (digits: text, truncated: truncated);
}
