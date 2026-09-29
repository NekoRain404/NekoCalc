/// 中文：**整数分解成质因数。**
///
///       **为什么自己算，不问引擎。** 引擎有一条 `factor(...)`（实测 `factor(123456)` →
///       `[2 2 2 2 2 2 3 643]`），但它**在"分不动"的时候会把输入原样退回来**——
///       `factor(x^2+2x+1)` 回的就是 `x^2 + 2x + 1`，种类 `SYMBOLIC`（**放行**的一支）。
///       那正是本仓最反对的一类：**用户问"分解成什么"，拿回来的是他自己打的那串**。
///       而整数分解是一个**纯函数**——单测就能证完，不必等真机，也不必去分辨引擎有没有真做。
///
///       **定义域**：`n >= 2`。`0`、`1` 与负数在这里回 `null`——
///       `1` 没有质因数（它是空乘积），`0` 没有（每个质数都整除它），
///       而负数要分解就得先约定"符号算不算一个因子"，**那是另一个问题**，
///       这一版不替用户决定。
/// English: **factor an integer into primes.**
///
///          **Why compute it here rather than asking the engine.** The engine has a `factor(...)`
///          (measured: `factor(123456)` → `[2 2 2 2 2 2 3 643]`), but **when it cannot factor it hands the
///          input straight back** — `factor(x^2+2x+1)` returns `x^2 + 2x + 1` with kind `SYMBOLIC` (a
///          branch that is **let through**). That is exactly the class this repository rejects: **the user
///          asked what it factors into and got back what they typed.** Integer factorisation, meanwhile,
///          is a **pure function** — the unit tests settle it completely, with no device and no need to
///          guess whether the engine really did anything.
///
///          **Domain**: `n >= 2`. `0`, `1` and negatives return `null` here — `1` has no prime factors (it
///          is the empty product), `0` has none (every prime divides it), and factoring a negative means
///          first agreeing on whether the sign counts as a factor, **which is a different question** this
///          version does not decide for the user.
library;

/// 中文：一个质因数与它的指数。`(2, 6)` 读作 `2^6`。
/// English: one prime and its exponent; `(2, 6)` reads `2^6`.
typedef PrimePower = ({BigInt prime, int exponent});

/// 中文：**把 [value] 分解成质因数**，指数合并、按质数升序；`value < 2` 回 `null`。
///
///       **算法是试除法**：先按 2 与 3 试，之后只用 `6k ± 1` 的形状（`5, 7, 11, 13, …`）——
///       所有大于 3 的质数都在这个形状里，而合数会被前面的质因子先除掉，所以不必再判质数。
///
///       ⚠️ **循环在 `p * p > rest` 时停下**：剩下的 `rest` 如果还没被除到 1，**它自己就是质数**
///       （否则它的最小质因子 `p` 会 ≤ `√rest`，而那正是循环条件）。这一步让 64 位整数
///       在毫秒级内分解完，而不是试到 `√n` 的尽头。
///
///       ⚠️ **用 `BigInt`**：调用方手里那个"十进制文本"可能远超 64 位
///       （`2^2000` 那种），而一个会在中途溢出的分解器**给出的是一份错答案**。
/// English: **factor [value] into primes**, exponents merged and primes ascending; `null` for `value < 2`.
///
///          **The algorithm is trial division**: try 2 and 3 first, then only the `6k ± 1` shapes
///          (`5, 7, 11, 13, …`) — every prime above 3 has that shape, and composites have already been
///          divided out by their smaller prime factors, so no primality test is needed.
///
///          ⚠️ **The loop stops at `p * p > rest`**: if `rest` has not reached 1 by then, **it is itself
///          prime** (otherwise its smallest prime factor would be ≤ `√rest`, which is the loop condition).
///          That is what makes a 64-bit integer factor in milliseconds instead of running to the end of
///          `√n`.
///
///          ⚠️ **`BigInt` throughout**: the "decimal text" the caller holds may be far beyond 64 bits (the
///          `2^2000` kind), and a factoriser that overflows midway **hands back a wrong answer**.
List<PrimePower>? primeFactorization(BigInt value) {
  if (value < BigInt.two) return null;

  final factors = <PrimePower>[];
  var rest = value;

  void take(BigInt prime) {
    var exponent = 0;
    while (rest % prime == BigInt.zero) {
      rest = rest ~/ prime;
      exponent++;
    }
    if (exponent > 0) factors.add((prime: prime, exponent: exponent));
  }

  take(BigInt.two);
  take(BigInt.from(3));
  // 中文：`6k ± 1`——从 5 开始，每次跨 2 与 4。
  // English: the `6k ± 1` shapes — starting at 5, stepping 2 then 4.
  var candidate = BigInt.from(5);
  final two = BigInt.two;
  final four = BigInt.from(4);
  var step = two;
  while (candidate * candidate <= rest) {
    take(candidate);
    candidate += step;
    step = step == two ? four : two;
  }
  if (rest > BigInt.one) {
    factors.add((prime: rest, exponent: 1));
  }
  return factors;
}
