import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/expression_parser.dart';

void main() {
  double parse(String source, {bool degreeMode = false}) {
    return ExpressionParser(source, degreeMode: degreeMode).parse();
  }

  test('evaluates operator precedence and parentheses', () {
    expect(parse('2+3×4'), 14);
    expect(parse('(2+3)×4'), 20);
    expect(parse('2^3^2'), 512);
    expect(parse('-2^2'), -4);
    expect(parse('(-2)^2'), 4);
    expect(parse('2^-2'), closeTo(0.25, 1e-12));
    expect(parse('2^-2^2'), closeTo(0.0625, 1e-12));
  });

  test('evaluates common scientific functions', () {
    expect(parse('sqrt(16)+log(100)+ln(e)'), closeTo(7, 1e-9));
    expect(parse('abs(-7)+exp(0)'), closeTo(8, 1e-9));
  });

  test('evaluates extended functions', () {
    expect(
        parse('fact(5)+floor(2.9)+ceil(2.1)+round(2.5)'), closeTo(128, 1e-9));
    expect(parse('sinh(0)+cosh(0)+tanh(0)'), closeTo(1, 1e-9));
    expect(parse('cbrt(27)+log2(8)+min(7,3)+max(7,3)+mod(7,3)'),
        closeTo(17, 1e-9));
    expect(parse('ncr(5,2)+npr(5,2)+gcd(24,18)+lcm(4,6)'), closeTo(48, 1e-9));
    expect(parse('root(27,3)+deg(pi)+rad(180)'), closeTo(186.1415926536, 1e-9));
  });

  test('evaluates variadic aggregate functions', () {
    expect(parse('min(7, 3, -2, 4)'), closeTo(-2, 1e-12));
    expect(parse('max(1, 2^3, sqrt(81), 4)'), closeTo(9, 1e-12));
    expect(parse('gcd(84, 126, 210)'), closeTo(42, 1e-12));
    expect(parse('lcm(3, 4, 5, 6)'), closeTo(60, 1e-12));
  });

  test('evaluates postfix factorial notation', () {
    expect(parse('5!'), closeTo(120, 1e-9));
    expect(parse('3! + 4!'), closeTo(30, 1e-9));
    expect(parse('(3+2)!'), closeTo(120, 1e-9));
    expect(parse('2^3!'), closeTo(64, 1e-9));
    expect(parse('-2^3!'), closeTo(-64, 1e-9));
    expect(parse('-3!'), closeTo(-6, 1e-9));
    expect(() => parse('2.5!'), throwsFormatException);
  });

  test('supports degree mode for trigonometry', () {
    expect(parse('sin(30)+cos(60)', degreeMode: true), closeTo(1, 1e-9));
    expect(parse('asin(0.5)', degreeMode: true), closeTo(30, 1e-9));
    expect(
        parse('cot(45)+sec(60)+csc(30)', degreeMode: true), closeTo(5, 1e-9));
    expect(parse('atan2(1,1)', degreeMode: true), closeTo(45, 1e-9));

    // 中文：**以数字结尾的函数名后面跟一个「看起来像千分位」的实参**——`_startsFunctionArgument`
    //       只看 `(` 前面的那个字符是不是字母或 `)`，于是 `atan2(` 被判成「不是函数调用」，
    //       `7,100` 里的逗号被当成千分位剥掉，整条变成 `atan2(7100)`（一个实参）→ `atan(7100)`
    //       → `1.570796`（实测修复前 `1.570655`，因为 `atan2` 单实参时退化成 `atan`）。
    //       正确的读法是两个实参 `7` 与 `100` → `atan(7/100)` = `0.069886…`。
    // English: **a function name ending in a digit followed by an argument that looks like a grouped
    //          number** — `_startsFunctionArgument` only looks at whether the character before `(` is a
    //          letter or `)`, so `atan2(` counts as "not a function call" and the comma in `7,100` is
    //          stripped as a thousands separator, leaving `atan2(7100)` (one argument) → `atan(7100)`.
    //          The correct reading is two arguments `7` and `100` → `atan(7/100)` = `0.069886…`.
    expect(parse('atan2(7,100)'), closeTo(0.0698860016, 1e-9));
    // 中文：第二个实参同样是「看起来像千分位」的形状（`1,234`）——这一条在修复前给
    //       `atan(1234)` = `1.569…`。
    // English: the second argument is the same "looks grouped" shape (`1,234`) — before the fix this
    //          gave `atan(1234)` = `1.569…`.
    expect(parse('atan2(1,234)'), closeTo(0.0042734783, 1e-9));
    // 中文：**同一个形状，正确的读法却相反**——`log2` 只吃一个实参，所以 `1,024` 在这里必须
    //       读成千分位（`log2(1024)` = 10），而不是两个实参。判据因此不能是「名字以数字结尾」，
    //       只能是**这个函数接不接受两个以上实参**（解析器自己的参数表就是权威）。
    //       `2(1,234)` 更直白：括号前面根本不是函数，逗号是千分位 → 2468。
    // English: **the same shape, the opposite correct reading** — `log2` takes one argument, so
    //          `1,024` here has to read as a thousands separator (`log2(1024)` = 10), not as two
    //          arguments. The criterion therefore cannot be "the name ends in a digit"; it has to be
    //          **whether this function accepts two or more arguments** (the parser's own argument
    //          table is the authority). `2(1,234)` is starker still: there is no function before the
    //          bracket at all, the comma is a thousands separator → 2468.
    expect(parse('log2(1,024)'), closeTo(10, 1e-9));
    expect(parse('2(1,234)'), closeTo(2468, 1e-9));
    expect(parse('12(345,678)'), closeTo(4148136, 1e-9));
  });

  test('a function alias reads its comma the same way its canonical name does', () {
    // 中文：**别名与规范名必须读成同一个东西，逗号也一样。** 实参个数表写的是**归一化之后**的
    //       名字（`ncr`/`npr`/`log`），而 [_startsFunctionArgument] 读的是**归一化之前**的文本
    //       ——别名替换跑在逗号归一化之后。于是同一颗键的两种拼法给出两个不同的值：
    //
    //       | 表达式 | 逗号读成 | 值 |
    //       |---|---|---|
    //       | `ncr(1,234)` | 分隔符 → `ncr(1, 234)` | 0（挑不出 234 个） |
    //       | `c(1,234)` / `C(1,234)` | 千分位 → `c(1234)` | **1234** ✗ |
    //       | `log(1,024)` | 分隔符 → 底数为 1024 | 0（log₁₀₂₄1） |
    //       | `lg(1,024)` / `log10(1,024)` | 千分位 → `lg(1024)` | **3.0103** ✗ |
    //
    //       大小写是同一个缺陷的另一半：这段文本此时**还没有经过 `.toLowerCase()`**
    //       （`_normalizeGroupedNumberSeparators` 跑在它前面），所以 `C`/`NCR` 也进不了那张表。
    // English: **an alias has to read the comma the way its canonical name does.** The argument table
    //          is written in **post-normalisation** names (`ncr`/`npr`/`log`) while
    //          [_startsFunctionArgument] reads the **pre-normalisation** text — the alias replacement
    //          runs after the comma normalisation. Two spellings of the same key therefore gave two
    //          different values:
    //
    //          | expression | comma read as | value |
    //          |---|---|---|
    //          | `ncr(1,234)` | a separator → `ncr(1, 234)` | 0 (cannot choose 234 of 1) |
    //          | `c(1,234)` / `C(1,234)` | a thousands separator → `c(1234)` | **1234** ✗ |
    //          | `log(1,024)` | a separator → base 1024 | 0 (log₁₀₂₄1) |
    //          | `lg(1,024)` / `log10(1,024)` | a thousands separator → `lg(1024)` | **3.0103** ✗ |
    //
    //          Case is the other half of the same defect: the text has **not** been through
    //          `.toLowerCase()` yet at this point (`_normalizeGroupedNumberSeparators` runs before it),
    //          so `C`/`NCR` do not reach the table either.
    expect(parse('ncr(1,234)'), closeTo(0, 1e-9));
    expect(parse('c(1,234)'), closeTo(0, 1e-9));
    expect(parse('C(1,234)'), closeTo(0, 1e-9));
    expect(parse('NCR(1,234)'), closeTo(0, 1e-9));
    expect(parse('log(1,024)'), closeTo(0, 1e-9));
    expect(parse('lg(1,024)'), closeTo(0, 1e-9));
    expect(parse('log10(1,024)'), closeTo(0, 1e-9));
    // 中文：同一张表的**反例**照旧——`log2` 只吃一个实参，逗号仍是千分位；括号前面不是函数也一样。
    // English: the **counter-examples** for the same table still hold — `log2` takes one argument, so
    //          its comma is still a thousands separator, and so is one before a bracket with no
    //          function in front of it.
    expect(parse('log2(1,024)'), closeTo(10, 1e-9));
    expect(parse('2(1,234)'), closeTo(2468, 1e-9));
  });

  test('normalizes common pasted function aliases', () {
    expect(parse('lg(100)+arcsin(0.5)'), closeTo(2 + math.asin(0.5), 1e-9));
    expect(parse('arccos(0.5)+arctan(1)'),
        closeTo(math.acos(0.5) + math.atan(1), 1e-9));
    expect(parse('∛27 + 2∛8'), closeTo(7, 1e-9));
  });

  test('normalizes calculator style bare function arguments', () {
    expect(parse('sqrt 9 + log 100'), closeTo(5, 1e-9));
    expect(parse('sin 30 + cos 60', degreeMode: true), closeTo(1, 1e-9));
    expect(parse('ln e + abs -5 + exp 0'), closeTo(7, 1e-9));
    expect(parse('lg 100 + arcsin 0.5'), closeTo(2 + math.asin(0.5), 1e-9));
    expect(parse('log2 8 + floor 2.9 + ceil 2.1'), closeTo(8, 1e-9));
    expect(parse('sqrt 25% + log 1e3%'), closeTo(1.5, 1e-9));
    expect(parse('sin 90°'), closeTo(1, 1e-9));
  });

  test('normalizes displayed math symbols back into parser expressions', () {
    expect(parse('log₁₀(100)+log₂(8)'), closeTo(5, 1e-9));
    expect(parse('e^(ln(5))+1.2×10³'), closeTo(1205, 1e-9));
    expect(parse('³√(27)+2⁴√16'), closeTo(7, 1e-9));
    expect(parse('|-5|+(5)!+C(5,2)+P(5,2)'), closeTo(155, 1e-9));
  });

  test('normalizes common latex expression input', () {
    expect(parse(r'\frac{1}{2} + \sqrt{9}'), closeTo(3.5, 1e-12));
    expect(parse(r'\sqrt[3]{27} + \sin(\pi/2)'), closeTo(4, 1e-12));
    expect(parse(r'\left(2+3\right)\cdot 4'), closeTo(20, 1e-12));
    expect(parse(r'\operatorname{max}{(1,2)}'), closeTo(2, 1e-12));
  });

  test('normalizes common mathematical constants', () {
    expect(parse('τ'), closeTo(2 * math.pi, 1e-12));
    expect(parse('tau / pi'), closeTo(2, 1e-12));
    expect(parse('φ^2 - φ'), closeTo(1, 1e-12));
    expect(parse(r'\varphi + \phi'), closeTo(1 + math.sqrt(5), 1e-12));
    expect(parse('1 / ∞'), closeTo(0, 1e-12));
  });

  test('normalizes indexed root notation', () {
    expect(parse('√[3](27)'), closeTo(3, 1e-9));
    expect(parse('√[4]16'), closeTo(2, 1e-9));
    expect(parse('2√[3](8+19)'), closeTo(6, 1e-9));
  });

  test('normalizes pasted math notation and implicit multiplication', () {
    expect(parse('２（３＋４）'), closeTo(14, 1e-9));
    expect(parse('2sin(rad(90)) + 3π'), closeTo(11.4247779608, 1e-9));
    expect(
        parse('2τ + 3φ'), closeTo(4 * math.pi + 3 * 1.618033988749895, 1e-9));
    expect(parse('τ(1+1)'), closeTo(4 * math.pi, 1e-9));
    expect(parse('2πsin(π/2)'), closeTo(2 * math.pi, 1e-9));
    expect(parse('πe + φτ'),
        closeTo(math.pi * math.e + 1.618033988749895 * 2 * math.pi, 1e-9));
    expect(parse('(2+3)(4+1)'), closeTo(25, 1e-9));
    expect(parse('√(16)+2²+3³'), closeTo(35, 1e-9));
    expect(parse('√9+√π'), closeTo(3 + math.sqrt(math.pi), 1e-9));
    expect(parse('50％ + 90°'), closeTo(2.0707963268, 1e-9));
    expect(parse('½ + ¼ + ¾'), closeTo(1.5, 1e-12));
    expect(parse('2½ + 1⅓'), closeTo(3.8333333333, 1e-9));
  });

  test('normalizes calculator style number formatting', () {
    expect(parse('1,200 + 3,400.5'), closeTo(4600.5, 1e-9));
    expect(parse('1_000 + 2_500.5'), closeTo(3500.5, 1e-9));
    expect(parse('1_000e-3 + 1e1_0'), closeTo(10000000001, 1e-3));
    expect(parse('1,200×50%'), closeTo(600, 1e-9));
    expect(parse('6÷2 + 4×3'), closeTo(15, 1e-9));
    expect(parse('max(1,200)'), closeTo(200, 1e-9));
    expect(() => parse('12,34 + 1'), throwsFormatException);
    expect(() => parse('1__2 + 1'), throwsFormatException);
    expect(() => parse('1_.2 + 1'), throwsFormatException);
  });

  test('normalizes pasted calculator result annotations', () {
    expect(parse('6*7='), closeTo(42, 1e-9));
    expect(parse('6*7 = 42'), closeTo(42, 1e-9));
    expect(parse('sqrt(81) ≈ 9'), closeTo(9, 1e-9));
    expect(parse('ans = 1,234.5'), closeTo(1234.5, 1e-9));
    expect(parse('表达式: 2π\n结果: 6.283185'), closeTo(2 * math.pi, 1e-9));
    expect(() => parse('1=1'), throwsFormatException);
  });

  test('parses programming radix number literals', () {
    expect(parse('0xff + 0b1010 + 0o10'), closeTo(273, 1e-9));
    expect(parse('0xFF_FF / 0b1111'), closeTo(4369, 1e-9));
    expect(parse('2(0x10 + 1)'), closeTo(34, 1e-9));
    expect(parse('0x10π'), closeTo(16 * math.pi, 1e-9));
    expect(() => parse('0x + 1'), throwsFormatException);
    expect(() => parse('0x_FF + 1'), throwsFormatException);
    expect(() => parse('0xFF_ + 1'), throwsFormatException);
    expect(() => parse('0xF__F + 1'), throwsFormatException);
  });

  test('normalizes scientific notation variants and superscripts', () {
    expect(parse('1.2×10^3 + 4'), closeTo(1204, 1e-9));
    expect(parse('2.5·10⁻³'), closeTo(0.0025, 1e-12));
    expect(parse('3x10⁺2'), closeTo(300, 1e-9));
    expect(parse('2⁻³'), closeTo(0.125, 1e-12));
    expect(parse('10⁶ + 1'), closeTo(1000001, 1e-9));
  });

  test('throws on incomplete expressions', () {
    expect(() => parse('sqrt(16'), throwsFormatException);
    expect(() => parse('2+'), throwsFormatException);
    expect(() => parse('min()'), throwsFormatException);
    expect(() => parse('sin()'), throwsFormatException);
    expect(() => parse('atan2(1,2,3)'), throwsFormatException);
  });
}
