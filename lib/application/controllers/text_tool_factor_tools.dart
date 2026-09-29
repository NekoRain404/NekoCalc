part of 'text_tool_controller.dart';

/// 中文：**质因数分解工具。**
///
///       **为什么不用引擎。** 引擎有一条 `factor(...)`，但它**分不动的时候会把输入原样退回来**——
///       实测 `factor(x^2+2x+1)` → `x^2 + 2x + 1`，种类 `SYMBOLIC`，而那一种在屏幕上是**放行**的。
///       接上去的话，用户问"分解成什么"，**拿回来的是他自己打的那串**。
///       整数分解是一个**纯函数**（`lib/core/math/prime_factorization.dart`），
///       于是单测就能证完，也**不必去分辨引擎有没有真做**。
///
///       ⚠️ **定义域是 `n >= 2`。** `1` 是空乘积、`0` 被每个质数整除——两者都不是
///       "分解结果为空"，而是**没有分解这回事**；负数要分解得先约定"符号算不算一个因子"，
///       那是另一个问题，**这一版不替用户决定**。三条都如实说一句话，不给数字。
///
///       **输入只收十进制整数**（千分位分隔会去掉）——`0x`/`FFh` 那种写法属于进制工具，
///       不是这里的事；**分不开的写法一律说读不出，不猜**。
/// English: **the prime-factorisation tool.**
///
///          **Why not the engine.** The engine has a `factor(...)`, but **it hands the input straight back
///          when it cannot factor** — measured, `factor(x^2+2x+1)` → `x^2 + 2x + 1`, kind `SYMBOLIC`, a
///          form the screen **lets through**. Wiring that up would mean the user asks what something
///          factors into and **gets back what they typed**. Integer factorisation is a **pure function**
///          (`lib/core/math/prime_factorization.dart`), so the unit tests settle it and **there is no need
///          to tell whether the engine really did anything**.
///
///          ⚠️ **The domain is `n >= 2`.** `1` is the empty product and `0` is divisible by every prime —
///          neither is "an empty factorisation", both are **no such factorisation**; and factoring a
///          negative means first agreeing on whether the sign is a factor, which is another question this
///          version **does not decide for the user**. All three get a sentence, never a number.
///
///          **The input takes decimal integers only** (grouping separators are stripped) — `0x` and `FFh`
///          belong to the base tool, not here; **anything unreadable says so and nothing is guessed.**
TextToolOutput _primeFactors(TextToolCodecStrings strings, String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return TextToolOutput(strings.factorEmpty, strings.factorExample, hasError: true);
  }
  final cleaned = trimmed.replaceAll(RegExp(r"[\s,_']"), '');
  final value = BigInt.tryParse(cleaned);
  if (value == null) {
    return TextToolOutput(strings.factorUnreadable, strings.factorExample,
        hasError: true);
  }
  final factors = primeFactorization(value);
  if (factors == null) {
    // 中文：**`< 2` 与"读不出"不是同一件事**——那个数读懂了，只是它没有质因数分解。
    // English: **`< 2` and "unreadable" are not the same thing** — the number was read; it simply has no
    //          prime factorisation.
    return TextToolOutput(strings.factorNone, strings.factorExample,
        hasError: true);
  }
  final shown = factors
      .map((f) => f.exponent == 1 ? '${f.prime}' : '${f.prime}^${f.exponent}')
      .join(' × ');
  // 中文：**`2^64` 那样的输入要能用**——所以例子给的是它，而 `value` 那一栏印的是
  //       **用户打的原文**（`2^64` 读得出是整数，但印成 18446744073709551616 就不是他打的了）。
  // English: **an input like `2^64` has to work** — hence that example — and the `value` column prints
  //          **what the user typed** (`2^64` reads as an integer, but printing 18446744073709551616 is no
  //          longer what they wrote).
  return TextToolOutput(
    shown,
    strings.factorCount(trimmed, factors.length),
    insights: <String>[strings.factorCount(value.toString(), factors.length)],
  );
}
