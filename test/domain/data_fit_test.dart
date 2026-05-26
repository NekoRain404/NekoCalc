import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/data_fit.dart';

void main() {
  test('parses two-column and one-column data', () {
    final twoColumn = parseDataPoints('1,2\n2 4\nx=3 y=6');
    expect(twoColumn.length, 3);
    expect(twoColumn.last.x, 3);
    expect(twoColumn.last.y, 6);

    final oneColumn = parseDataPoints('10\n20\n30');
    expect(oneColumn.map((p) => p.x), [1, 2, 3]);
    expect(oneColumn.map((p) => p.y), [10, 20, 30]);
  });

  test('parses multi-column and blank-separated series', () {
    final multiColumn = parseDataSeries('1, 2, 10\n2, 4, 20\n3, 6, 30');
    expect(multiColumn.length, 2);
    expect(multiColumn[0].points.map((p) => p.y), [2, 4, 6]);
    expect(multiColumn[1].points.map((p) => p.y), [10, 20, 30]);

    final blocks = parseDataSeries('1, 2\n2, 4\n\n1, 3\n2, 6');
    expect(blocks.length, 2);
    expect(blocks[0].points.length, 2);
    expect(blocks[1].points.last.y, 6);
  });

  test('fits linear data', () {
    final result = fitData(parseDataPoints('1,3\n2,5\n3,7'), FitModel.linear);
    expect(result.coefficients[0], closeTo(2, 1e-9));
    expect(result.coefficients[1], closeTo(1, 1e-9));
    expect(result.rSquared, closeTo(1, 1e-9));
  });

  test('fits quadratic data', () {
    final result =
        fitData(parseDataPoints('-1,1\n0,0\n1,1\n2,4'), FitModel.quadratic);
    expect(result.coefficients[0], closeTo(1, 1e-9));
    expect(result.coefficients[1], closeTo(0, 1e-9));
    expect(result.coefficients[2], closeTo(0, 1e-9));
  });

  test('fits exponential data', () {
    final result =
        fitData(parseDataPoints('0,2\n1,4\n2,8'), FitModel.exponential);
    expect(result.coefficients[0], closeTo(2, 1e-9));
    expect(result.coefficients[1], closeTo(0.6931471805599453, 1e-9));
  });

  test('fits logarithmic and reciprocal data', () {
    final logarithmic = fitData(
      parseDataPoints('1,1\n2,2.38629436112\n4,3.77258872224'),
      FitModel.logarithmic,
    );
    expect(logarithmic.coefficients[0], closeTo(2, 1e-9));
    expect(logarithmic.coefficients[1], closeTo(1, 1e-9));

    final reciprocal =
        fitData(parseDataPoints('1,7\n2,4\n4,2.5'), FitModel.reciprocal);
    expect(reciprocal.coefficients[0], closeTo(6, 1e-9));
    expect(reciprocal.coefficients[1], closeTo(1, 1e-9));
  });

  test('rejects invalid model data', () {
    expect(
      () => fitData(parseDataPoints('1,-2\n2,4'), FitModel.exponential),
      throwsFormatException,
    );
    expect(
      () => fitData(parseDataPoints('1,2\n2,4'), FitModel.quadratic),
      throwsFormatException,
    );
    expect(
      () => fitData(parseDataPoints('-1,2\n-2,4'), FitModel.logarithmic),
      throwsFormatException,
    );
    expect(
      () => fitData(parseDataPoints('0,2\n0,4'), FitModel.reciprocal),
      throwsFormatException,
    );
  });
}
