import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/utils/render_export.dart';
import 'package:nekocalc/domain/usecases/data_fit.dart';

void main() {
  test('creates a CSV fit export with escaped values and residuals', () {
    const result = FitResult(
      model: FitModel.linear,
      points: [DataPoint(1, 2), DataPoint(2, 3.5)],
      coefficients: [1.5, 0.5],
      equation: 'y = 1.5x + 0.5',
      rSquared: 0.99,
      rmse: 0.1,
      predictions: [DataPoint(1, 2), DataPoint(2, 3.5)],
    );

    final csv = buildFitCsvExport(seriesName: 'A, "quoted"', result: result);

    expect(csv, startsWith('\uFEFFseries,model,equation,r_squared,rmse'));
    expect(csv, contains('"A, ""quoted"""'));
    expect(csv, contains('index,x,y,predicted,residual'));
    expect(csv, contains('1,1,2,2,0'));
    expect(csv, contains('2,2,3.5,3.5,0'));
  });

  test('builds stable safe export file names', () {
    expect(
      buildExportFileName(
          prefix: '图形 / test',
          extension: 'png',
          now: DateTime(2026, 7, 23, 9, 5, 2)),
      '图形_test_20260723_090502.png',
    );
    expect(
      buildExportFileName(
          prefix: 'fit', extension: '.csv', now: DateTime(2026, 1, 2)),
      'fit_20260102_000000.csv',
    );
  });

  test('encodes CSV text as UTF-8 without corrupting Chinese content', () {
    final bytes = encodeExportText('\uFEFF温度,值\n20,测试\n');

    expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
    expect(utf8.decode(bytes.skip(3).toList()), '温度,值\n20,测试\n');
  });
}
