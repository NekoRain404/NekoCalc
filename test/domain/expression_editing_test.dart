import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/expression_editing.dart';

void main() {
  group('expression editing boundaries', () {
    test('moves over numeric literals and complete function groups', () {
      const expression = '12+sqrt(81)+345';

      expect(previousExpressionBoundary(expression, 11), 3);
      expect(nextExpressionBoundary(expression, 0), 2);
      expect(nextExpressionBoundary(expression, 3), 11);
    });

    test('keeps a leading number separate from a function group', () {
      const expression = '2sqrt(9)';

      expect(previousExpressionBoundary(expression, expression.length), 1);
      expect(nextExpressionBoundary(expression, 1), expression.length);
    });

    test('moves over supported decimal and radix literals', () {
      for (final expression in ['1_000.5', '1e-3', '0xFF']) {
        expect(previousExpressionBoundary(expression, expression.length), 0);
        expect(nextExpressionBoundary(expression, 0), expression.length);
      }
    });

    test('falls back to one character around incomplete groups', () {
      const expression = 'sqrt(81';

      expect(previousExpressionBoundary(expression, 7), 6);
      expect(nextExpressionBoundary(expression, 4), 5);
    });

    test('clamps offsets and preserves code point boundaries on fallback', () {
      const expression = '\ud83d\ude00+';

      expect(previousExpressionBoundary(expression, -1), 0);
      expect(nextExpressionBoundary(expression, 99), expression.length);
      expect(nextExpressionBoundary(expression, 0), 2);
      expect(previousExpressionBoundary(expression, 2), 0);
      expect(nextExpressionBoundary(expression, 1), 2);
      expect(previousExpressionBoundary(expression, 1), 0);
    });
  });
}
