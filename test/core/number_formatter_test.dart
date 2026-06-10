import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/number_formatter.dart';

void main() {
  test('formats non finite numbers as invalid text', () {
    expect(formatNumber(double.infinity), '无效');
    expect(formatNumber(double.negativeInfinity), '无效');
    expect(formatNumber(double.nan), '无效');
  });

  test('trims insignificant trailing zeros', () {
    expect(formatNumber(12.340000), '12.34');
    expect(formatNumber(12, precision: 3), '12');
  });

  test('uses scientific notation for very small and large values', () {
    expect(formatNumber(0.0000001234), '1.234e-7');
    expect(formatNumber(-0.0000001234, precision: 3), '-1.234e-7');
    expect(formatNumber(1234567890000), '1.234568e+12');
    expect(formatNumber(999999999), '999999999');
    expect(formatNumber(0.000001), '0.000001');
  });
}
