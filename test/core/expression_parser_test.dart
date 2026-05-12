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

  test('supports degree mode for trigonometry', () {
    expect(parse('sin(30)+cos(60)', degreeMode: true), closeTo(1, 1e-9));
    expect(parse('asin(0.5)', degreeMode: true), closeTo(30, 1e-9));
    expect(
        parse('cot(45)+sec(60)+csc(30)', degreeMode: true), closeTo(5, 1e-9));
    expect(parse('atan2(1,1)', degreeMode: true), closeTo(45, 1e-9));
  });

  test('throws on incomplete expressions', () {
    expect(() => parse('sqrt(16'), throwsFormatException);
    expect(() => parse('2+'), throwsFormatException);
  });
}
