import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/polynomial_form.dart';

/// 中文：**把表达式读成多项式的测试。**
///
///       ⚠️ **期望值有一个独立来源**：[sympy] 的 `expand` 之后取系数表——
///       下面每一条都是照着它写的（`expand(x^2-1)` → `x^2 - 1`，系数升幂 `[-1, 0, 1]`）。
///       自己展开一遍再用同一个脑子核对，等于没有核对。
///
///       **这一组就是全部证据**：它是纯函数，不碰引擎。
/// English: **the expression→polynomial tests.**
///
///          ⚠️ **The expectations have an independent source**: [sympy]'s `expand`, then read the
///          coefficients — every case below was written from it (`expand(x^2-1)` → `x^2 - 1`, coefficients
///          ascending `[-1, 0, 1]`). Expanding it by hand and checking it with the same head is no check.
///
///          **This group is the whole proof**: it is a pure function and does not touch the engine.
String show(Polynomial? p) =>
    p == null ? '<null>' : '[${p.map((c) => c.toString()).join(', ')}]';

void main() {
  _factorisationGroup();

  group('读成系数表（升幂）', () {
    test('常数、一次、二次', () {
      expect(show(polynomialIn('3', 'x')), '[3]');
      expect(show(polynomialIn('x', 'x')), '[0, 1]');
      expect(show(polynomialIn('x^2 - 1', 'x')), '[-1, 0, 1]');
      expect(show(polynomialIn('x^2 + 2x + 1', 'x')), '[1, 2, 1]');
    });

    test('隐式乘法与显式乘法是同一条路', () {
      // `2x` 在树里是隐式乘法；两种写法必须给出同一张表。
      expect(show(polynomialIn('2x', 'x')), '[0, 2]');
      expect(show(polynomialIn('2 * x', 'x')), '[0, 2]');
    });

    test('括号与负号', () {
      expect(show(polynomialIn('-(x - 3)', 'x')), '[3, -1]');
      expect(show(polynomialIn('2(x + 1)', 'x')), '[2, 2]');
    });

    test('幂展开：`(x+1)^3` 与 `sympy.expand` 逐项相同', () {
      // sympy: expand((x+1)**3) → x**3 + 3*x**2 + 3*x + 1
      expect(show(polynomialIn('(x+1)^3', 'x')), '[1, 3, 3, 1]');
      // sympy: expand((x+1)*(x-1)) → x**2 - 1
      expect(show(polynomialIn('(x+1)(x-1)', 'x')), '[-1, 0, 1]');
      // sympy: expand((2*x-3)**2) → 4*x**2 - 12*x + 9
      expect(show(polynomialIn('(2x-3)^2', 'x')), '[9, -12, 4]');
    });

    test('零次幂与一次幂', () {
      expect(show(polynomialIn('x^0', 'x')), '[1]');
      expect(show(polynomialIn('x^1', 'x')), '[0, 1]');
    });

    test('对另一个字母也读得出（变量是参数）', () {
      expect(show(polynomialIn('y^2 - 1', 'y')), '[-1, 0, 1]');
    });

    test('末尾的零不裁剪', () {
      // 中文：`x^2` 的表是 `[0, 0, 1]`——**裁剪是显示的事，不是读的事**。
      //       读的时候就裁掉，下一步的除法要按真实次数来写。
      // English: `x^2` reads as `[0, 0, 1]` — **trimming is the display's business, not the reading's**.
      //          Trimming here would mislead the division step, which needs the true degree.
      expect(show(polynomialIn('x^2', 'x')), '[0, 0, 1]');
    });
  });

  group('⚠️ 窄定义域：读不出的回 null，绝不硬套', () {
    test('有理系数：这一版只收整数', () {
      // 中文：`1.5x` 要引进分数算术，而**做了半套的分数算术会给出错的分解**。
      expect(polynomialIn('1.5x', 'x'), isNull);
      expect(polynomialIn('x/2', 'x'), isNull);
    });

    test('二元与符号系数', () {
      expect(polynomialIn('x*y', 'x'), isNull);
      expect(polynomialIn('pi*x', 'x'), isNull);
    });

    test('负指数：那是分式，不是多项式', () {
      expect(polynomialIn('x^-1', 'x'), isNull);
      expect(polynomialIn('1/x', 'x'), isNull);
    });

    test('变量在指数上', () {
      expect(polynomialIn('x^x', 'x'), isNull);
    });

    test('函数调用与解析错误', () {
      expect(polynomialIn('sin(x)', 'x'), isNull);
      expect(polynomialIn('', 'x'), isNull);
      expect(polynomialIn('2+', 'x'), isNull);
    });
  });
}

/// 中文：**分解因式的测试。**
///
///       ⚠️ **期望值全部来自 sympy**（`factor(expand(...))`），逐条列在每条断言旁边——
///       分解是最容易"自己乘回去验证自己"的一类：**乘回去用的还是同一个脑子**。
///       独立来源给的是**因子的形状**（`(x - 1)*(x + 1)`），这里就是把那个形状抄下来。
///
///       ⚠️ **`x^2 + 2x + 1` 这一条特别值得看**：它正是**引擎分不动的那一个输入**
///       （实测 `factor(x^2+2x+1)` → `x^2 + 2x + 1`，把输入原样退回）。
///       这是本项目**比引擎对**的一处实证，而不是一句口号。
/// English: **the factorisation tests.**
///
///          ⚠️ **Every expectation comes from sympy** (`factor(expand(...))`) and is quoted beside its
///          assertion — factorisation is the easiest thing to "verify by multiplying back", and multiplying
///          back uses **the same head**. The independent source gives the **shape of the factors**
///          (`(x - 1)*(x + 1)`) and that shape is what is copied here.
///
///          ⚠️ **The `x^2 + 2x + 1` case is worth a look**: it is exactly **the input the engine cannot
///          factor** (measured: `factor(x^2+2x+1)` → `x^2 + 2x + 1`, the input handed straight back). This is
///          an instance of this project being **more correct than the engine**, not a slogan.
void _factorisationGroup() {
  group('分解因式：期望值逐条来自 sympy', () {
    PolynomialFactorisation? run(String source) {
      final p = polynomialIn(source, 'x');
      return p == null ? null : factorPolynomial(p, 'x');
    }

    String shown(String source) {
      final f = run(source);
      if (f == null) return '<null>';
      final parts = <String>[
        if (f.constant != BigInt.one) f.constant.toString(),
        ...f.factors,
        if (f.remainder != null) '(${f.remainder})',
      ];
      return parts.join(' × ');
    }

    test('平方差与完全平方（后者正是引擎分不动的那个）', () {
      // sympy: factor(x**2 - 1) → (x - 1)*(x + 1)
      expect(shown('x^2 - 1'), '(x - 1) × (x + 1)');
      // sympy: factor(x**2 + 2x + 1) → (x + 1)**2  ← 引擎在这里把输入原样退回
      expect(shown('x^2 + 2x + 1'), '(x + 1) × (x + 1)');
    });

    test('两个整根', () {
      // sympy: factor(x**2 - 5x + 6) → (x - 3)*(x - 2)
      expect(shown('x^2 - 5x + 6'), '(x - 2) × (x - 3)');
    });

    test('⚠️ 有理根（不是整数根）：`2x^2 - 3x + 1` 的根是 1 与 1/2', () {
      // sympy: factor(2x**2 - 3x + 1) → (x - 1)*(2*x - 1)
      // 中文：**这一条钉的是"除以 `qx - p` 而不是 `x - p/q`"。** 后者会引进分数，
      //       而这个仓反复记着：**半套的分数算术会给出错的分解**。
      // English: **this pins "divide by `qx - p`, not `x - p/q`".** The latter brings in fractions, and this
      //          repository has it written down repeatedly: **half-done fraction arithmetic gives a wrong
      //          factorisation.**
      expect(shown('2x^2 - 3x + 1'), '(x - 1) × (2x - 1)');
    });

    test('三次：分出一个根，剩下的如实留下', () {
      // sympy: factor(x**3 - 8) → (x - 2)*(x**2 + 2x + 4)
      expect(shown('x^3 - 8'), '(x - 2) × (x^2 + 2x + 4)');
    });

    test('⚠️ 常数项为 0：先提 `x`（候选根里没有 0）', () {
      // sympy: factor(x**3 - x) → x*(x - 1)*(x + 1)
      // 中文：少了"先提 x"这一步，`x^3 - x` 会分不动——而有理根的候选里**没有 0**。
      // English: without the "pull `x` out first" step, `x^3 - x` would not factor — and 0 is **not** among
      //          the rational-root candidates.
      expect(shown('x^3 - x'), 'x × (x - 1) × (x + 1)');
    });

    test('⚠️ 分不动就如实留下，绝不硬拆', () {
      // sympy: factor(x**2 - 2) → x**2 - 2（根是无理数）；factor(x**4 + 1) → x**4 + 1（有理数上不可约）
      // 中文：硬拆要引进无理数，**那是另一个问题**。
      // English: forcing them apart needs irrationals, which **is a different question**.
      expect(shown('x^2 - 2'), '(x^2 - 2)');
      expect(shown('x^4 + 1'), '(x^4 + 1)');
    });

    test('首项系数不为 1：`6x^2 + 5x + 1`', () {
      // sympy: factor(6x**2 + 5x + 1) → (2*x + 1)*(3*x + 1)
      expect(shown('6x^2 + 5x + 1'), '(2x + 1) × (3x + 1)');
    });

    test('常数与一次式没有因式可分解', () {
      expect(polynomialIn('5', 'x'), isNotNull);
      expect(run('5'), isNull);
      expect(run('x + 1'), isNull);
    });
  });
}
