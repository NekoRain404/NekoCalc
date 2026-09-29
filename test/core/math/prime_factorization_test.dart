import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/prime_factorization.dart';

/// 中文：**整数分解的测试。**
///
///       ⚠️ **期望值有两个独立来源，两边都对上了**：
///       一个是 **sympy**（`factorint`），另一个是**引擎自己**——
///       宿主 `qalc` 5.12.0 的 `factor(123456)` 给 `[2 2 2 2 2 2 3 643]`。
///       **两处独立实现与引擎三方一致**，这是这一组期望值可信的理由。
///
///       **这一组就是全部证据，不必等真机**：它是纯函数，不碰引擎。
///       而不碰引擎恰好是**必要的**——引擎在"分不动"时会把输入原样退回来
///       （`factor(x^2+2x+1)` → `x^2 + 2x + 1`，种类还是**放行**的那一支），
///       见 `prime_factorization.dart` 的文件头。
/// English: **the integer-factorisation tests.**
///
///          ⚠️ **The expected values have two independent sources and both agree**: **sympy**
///          (`factorint`) and **the engine** — host `qalc` 5.12.0's `factor(123456)` gives
///          `[2 2 2 2 2 2 3 643]`. **Two independent implementations plus the engine, three ways agreeing**,
///          is why these expectations can be trusted.
///
///          **This group is the whole proof; no device is needed**: it is a pure function that does not
///          touch the engine. Not touching it is in fact **necessary** — the engine hands the input back
///          when it cannot factor (`factor(x^2+2x+1)` → `x^2 + 2x + 1`, in a kind that is **let through**),
///          see `prime_factorization.dart`'s head.
/// 中文：**指数为 1 时不印 `^1`**——这样读起来与**引擎自己印出来的那一串**是同一个形状
///       （`factor(123456)` → `[2 2 2 2 2 2 3 643]`，也就是 `2^6 × 3 × 643`），
///       于是"与引擎逐项相同"这件事在测试里**看得见**，而不是要靠心算。
/// English: **no `^1` for exponent 1** — that makes it the same shape as **the string the engine itself
///          prints** (`factor(123456)` → `[2 2 2 2 2 2 3 643]`, i.e. `2^6 × 3 × 643`), so "identical to the
///          engine term by term" is **visible** in the test rather than something to work out in one's
///          head.
String show(List<PrimePower>? factors) => factors == null
    ? '<null>'
    : factors
        .map((f) => f.exponent == 1 ? '${f.prime}' : '${f.prime}^${f.exponent}')
        .join(' × ');

void main() {
  group('分解', () {
    test('质数与合数', () {
      expect(show(primeFactorization(BigInt.from(2))), '2');
      expect(show(primeFactorization(BigInt.from(3))), '3');
      expect(show(primeFactorization(BigInt.from(4))), '2^2');
      expect(show(primeFactorization(BigInt.from(97))), '97');
      expect(show(primeFactorization(BigInt.from(100))), '2^2 × 5^2');
    });

    test('⚠️ 123456 与**引擎自己的答案**逐项相同', () {
      // 中文：宿主 `qalc` 的 `factor(123456)` 给 `[2 2 2 2 2 2 3 643]`——也就是 `2^6 × 3 × 643`。
      //       sympy 的 `factorint(123456)` 给同一个。**三方一致。**
      // English: host `qalc`'s `factor(123456)` gives `[2 2 2 2 2 2 3 643]` — that is `2^6 × 3 × 643` — and
      //          sympy's `factorint(123456)` agrees. **Three ways agreeing.**
      expect(show(primeFactorization(BigInt.from(123456))), '2^6 × 3 × 643');
    });

    test('指数合并，质数升序', () {
      expect(show(primeFactorization(BigInt.from(64))), '2^6');
      expect(show(primeFactorization(BigInt.from(1 << 40))), '2^40');
      expect(show(primeFactorization(BigInt.from(720))), '2^4 × 3^2 × 5');
    });

    test('大质数：`p * p > rest` 那一步的意义', () {
      // 中文：**这两个都是质数，而它们的平方根是十万上下。** 少了"剩下的就是质数"那一步，
      //       试除法要跑到 `√n` 的尽头；有了它，两个都立刻停。
      // English: **both are prime and their square roots are around a hundred thousand.** Without the
      //          "the rest is prime" step, trial division would run to the end of `√n`; with it, both stop
      //          at once.
      expect(show(primeFactorization(BigInt.from(1000000007))), '1000000007');
      expect(show(primeFactorization(BigInt.from(999999999989))), '999999999989');
    });

    test('两个质数相乘（半素数）：两个因子都找得到', () {
      // `600851475143 = 71 × 839 × 1471 × 6857`（欧拉计划第 3 题的那个数）。
      expect(show(primeFactorization(BigInt.from(600851475143))),
          '71 × 839 × 1471 × 6857');
    });

    test('⚠️ 超出 64 位的值照样分解（`BigInt` 那条的理由）', () {
      // 中文：`2^100` 是 31 位十进制数，远超 64 位整数；而一个中途溢出的分解器
      //       **给出的是一份错答案**，不是失败。
      // English: `2^100` is 31 decimal digits, far beyond a 64-bit integer, and a factoriser that
      //          overflows midway **hands back a wrong answer** rather than failing.
      expect(show(primeFactorization(BigInt.two.pow(100))), '2^100');
      expect(show(primeFactorization(BigInt.from(10).pow(18))), '2^18 × 5^18');
    });
  });

  group('⚠️ 定义域：`< 2` 一律回 null，不猜', () {
    test('0 与 1 没有质因数分解', () {
      // 中文：`1` 是**空乘积**（没有质因数），`0` 则被每个质数整除——
      //       两者都不是"分解结果为空"，而是**没有分解这回事**。
      // English: `1` is the **empty product** (no prime factors) and `0` is divisible by every prime —
      //          neither is "an empty factorisation", both are **no such factorisation**.
      expect(primeFactorization(BigInt.zero), isNull);
      expect(primeFactorization(BigInt.one), isNull);
    });

    test('负数：符号算不算因子是另一个问题，这一版不替用户决定', () {
      expect(primeFactorization(BigInt.from(-12)), isNull);
      expect(primeFactorization(BigInt.from(-1)), isNull);
    });
  });
}
