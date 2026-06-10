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
