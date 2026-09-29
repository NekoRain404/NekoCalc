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
