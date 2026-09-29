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
    // 中文：**整数读不出就试多项式。** `factor` 在 HiPER 与引擎那里都同时管这两件事
    //       （整数分解与因式分解），所以这里也是**一个工具两种输入**，
    //       而不是两个工具——**同一个意思不该有两个入口**。
    //
    //       ⚠️ 两条路都读不出才说"读不出"，而**两条路的"读不出"不是同一件事**：
    //       整数那一条说的是"这不是一个整数"，多项式那一条说的是"这不是一个多项式"。
    //       屏幕上只给一句，但**代码里这两句是分开的**（下面是两条不同的 return）。
    // English: **when the integer fails, try a polynomial.** `factor` covers both in HiPER and in the
    //          engine (integer factorisation and polynomial factorisation), so this is **one tool with two
    //          kinds of input** rather than two tools — **one meaning should not have two entrances**.
    //
    //          ⚠️ "Unreadable" is said only when **both** roads fail, and **the two roads' "unreadable" are
    //          not the same thing**: the integer one means "this is not an integer" and the polynomial one
    //          means "this is not a polynomial". The screen carries one sentence, but **in the code these
    //          are separate** (two different returns below).
    return _factorSymbolic(strings, trimmed);
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

/// 中文：**因式分解那一条路。** 读不出多项式、或者没有有理因式，各说各的一句——
///       **两者不是同一件事**（见调用点的注释）。
/// English: **the polynomial road.** "Not a polynomial" and "no rational factor" get a sentence each —
///          **they are not the same thing** (see the note at the call site).
TextToolOutput _factorSymbolic(TextToolCodecStrings strings, String input) {
  final coefficients = polynomialIn(input, 'x');
  if (coefficients == null) {
    return TextToolOutput(strings.factorUnreadable, strings.factorExample,
        hasError: true);
  }
  final factored = factorPolynomial(coefficients, 'x');
  // 中文：**一个因子都没提出来的，等于没分。** 少了这一条，`x^2 - 2` 印出来的会是
  //       `(x^2 - 2)`——**把输入括起来还给它**，那既不是分解也没给任何信息。
  //       （`factorPolynomial` 在那一支回的是"非空但没有因子、只有剩余"，那是给分解器看的形状；
  //       屏幕上该说的是**这句话**。）
  // English: **nothing extracted is nothing factored.** Without this, `x^2 - 2` would print
  //          `(x^2 - 2)` — **the input in brackets, handed back**, which is neither a factorisation nor any
  //          information. (`factorPolynomial` returns "non-null, no factors, only a remainder" in that
  //          branch, a shape meant for the factoriser; what the screen should say is **this sentence**.)
  if (factored == null || factored.factors.isEmpty) {
    return TextToolOutput(strings.factorNoFactors, strings.factorExample,
        hasError: true);
  }
  final parts = <String>[
    if (factored.constant != BigInt.one) factored.constant.toString(),
    ...factored.factors,
    // 中文：**分不动的那一块如实留下**（`x^2 - 2` 那种）——硬拆要引进无理数，那是另一个问题。
    // English: **the piece that would not factor is left as it is** (the `x^2 - 2` kind) — forcing it apart
    //          needs irrationals, which is another question.
    if (factored.remainder != null) '(${factored.remainder})',
  ];
  return TextToolOutput(
    parts.join(' × '),
    strings.factorCount(input, factored.factors.length),
    insights: <String>[strings.factorCount(input, factored.factors.length)],
  );
}
