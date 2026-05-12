import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/expression_display_formatter.dart';

void main() {
  test('keeps parser expression when symbol display is disabled', () {
    expect(
      formatExpressionForDisplay('sqrt(16)+log2(8)', mathSymbols: false),
      'sqrt(16)+log2(8)',
    );
  });

  test('formats common functions as mathematical symbols', () {
    expect(
      formatExpressionForDisplay('sqrt(16)+cbrt(27)+pi^2', mathSymbols: true),
      '√(16)+∛(27)+π²',
    );
    expect(
      formatExpressionForDisplay('log(100)+log2(8)+exp(1)', mathSymbols: true),
      'log₁₀(100)+log₂(8)+e^(1)',
    );
  });

  test('formats wrapped unary and binary helpers', () {
    expect(formatExpressionForDisplay('abs(-5)+fact(5)', mathSymbols: true),
        '|-5|+(5)!');
    expect(formatExpressionForDisplay('root(27,3)+ncr(5,2)', mathSymbols: true),
        '³√(27)+C(5,2)');
  });
}
