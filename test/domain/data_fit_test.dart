import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/data_fit.dart';

void main() {
  test('encodes and decodes data fit drafts', () {
    final encoded = encodeDataFitDraft(
      const DataFitDraft(
        toolId: 'data_fit',
        data: 'x,y1,y2\n1,2,10\n2,4,20',
        prediction: '3.5',
        model: FitModel.quadratic,
        selectedSeriesIndex: 1,
      ),
    );

    final restored = decodeDataFitDraft(
      toolId: 'data_fit',
      raw: encoded,
      seriesCount: 2,
    );

    expect(dataFitDraftSettingKey('data_fit'), 'data_fit_draft_data_fit');
    expect(restored, isNotNull);
    expect(restored!.data, 'x,y1,y2\n1,2,10\n2,4,20');
    expect(restored.prediction, '3.5');
    expect(restored.model, FitModel.quadratic);
    expect(restored.selectedSeriesIndex, 1);
  });

  test('rejects invalid data fit drafts and mismatched tools', () {
    final encoded = encodeDataFitDraft(
      const DataFitDraft(
        toolId: 'data_fit',
        data: '1,2\n2,4',
        prediction: '3',
        model: FitModel.linear,
        selectedSeriesIndex: 0,
      ),
    );

    expect(decodeDataFitDraft(toolId: 'data_fit', raw: 'bad json'), isNull);
    expect(decodeDataFitDraft(toolId: 'other', raw: encoded), isNull);
    expect(
      decodeDataFitDraft(
        toolId: 'data_fit',
        raw: '{"version":1,"toolId":"data_fit","data":"1,2","model":"missing"}',
      ),
      isNull,
    );
  });

  test('normalizes data fit draft index and missing text fields', () {
    final highIndex = decodeDataFitDraft(
      toolId: 'data_fit',
      raw:
          '{"version":1,"toolId":"data_fit","model":"linear","selectedSeriesIndex":5}',
      seriesCount: 2,
    );
    final negativeIndex = decodeDataFitDraft(
      toolId: 'data_fit',
      raw:
          '{"version":1,"toolId":"data_fit","model":"linear","selectedSeriesIndex":-3}',
    );
    final missingModel = decodeDataFitDraft(
      toolId: 'data_fit',
      raw: '{"version":1,"toolId":"data_fit","selectedSeriesIndex":0}',
    );

    expect(highIndex, isNotNull);
    expect(highIndex!.data, '');
    expect(highIndex.prediction, '');
    expect(highIndex.selectedSeriesIndex, 1);
    expect(negativeIndex!.selectedSeriesIndex, 0);
    expect(missingModel!.model, FitModel.linear);
  });

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

  test('parses table headers pasted from spreadsheets', () {
    final series = parseDataSeries('x,y1,y2\n1, 2, 10\n2, 4, 20\n3, 6, 30');

    expect(series.length, 2);
    expect(series.first.name, 'y1');
    expect(series.last.name, 'y2');
    expect(series.first.points.map((p) => p.x), [1, 2, 3]);
    expect(series.first.points.map((p) => p.y), [2, 4, 6]);
    expect(series.last.points.map((p) => p.y), [10, 20, 30]);
  });

  test('skips spreadsheet metadata and comments in pasted tables', () {
    final series = parseDataSeries('''
﻿# exported from spreadsheet
sep=;
x;y1;y2
1;2;10
2;4;20
3;6;30
''');
    final framed = parseDataPoints('''
-- query result
+---+---+
x,y
1,2
2,4
3,6
''');

    expect(series.length, 2);
    expect(series[0].name, 'y1');
    expect(series[1].name, 'y2');
    expect(series[0].points.map((p) => p.x), [1, 2, 3]);
    expect(series[0].points.map((p) => p.y), [2, 4, 6]);
    expect(series[1].points.map((p) => p.y), [10, 20, 30]);

    expect(framed.map((p) => p.x), [1, 2, 3]);
    expect(framed.map((p) => p.y), [2, 4, 6]);
  });

  test('skips unit descriptor rows before fitting data tables', () {
    final unitBeforeHeader = parseDataSeries('''
units, s, degC
x, temp
1, 20
2, 25
3, 29
''');
    final markdownUnits = parseDataSeries('''
| x | 温度 | 压力 |
| 单位 | ℃ | kPa |
|---|---:|---:|
| 1 | 20 | 100 |
| 2 | 25 | 110 |
| 3 | 29 | 121 |
''');

    expect(unitBeforeHeader.single.name, 'temp');
    expect(unitBeforeHeader.single.points.map((p) => p.x), [1, 2, 3]);
    expect(unitBeforeHeader.single.points.map((p) => p.y), [20, 25, 29]);

    expect(markdownUnits.length, 2);
    expect(markdownUnits[0].name, '温度');
    expect(markdownUnits[1].name, '压力');
    expect(markdownUnits[0].points.map((p) => p.y), [20, 25, 29]);
    expect(markdownUnits[1].points.map((p) => p.y), [100, 110, 121]);
  });

  test('parses indexed table exports from dataframes', () {
    final tabbed = parseDataSeries('''
\tx\t温度\t压力
0\t1\t20\t100
1\t2\t25\t110
2\t3\t29\t121
''');
    final explicitIndex =
        parseDataPoints('index,x,y\n0,10,100\n1,20,400\n2,30,900');

    expect(tabbed.length, 2);
    expect(tabbed[0].name, '温度');
    expect(tabbed[1].name, '压力');
    expect(tabbed[0].points.map((p) => p.x), [1, 2, 3]);
    expect(tabbed[0].points.map((p) => p.y), [20, 25, 29]);
    expect(tabbed[1].points.map((p) => p.y), [100, 110, 121]);

    expect(explicitIndex.map((p) => p.x), [10, 20, 30]);
    expect(explicitIndex.map((p) => p.y), [100, 400, 900]);
  });

  test('parses markdown tables with header names', () {
    final series = parseDataSeries('''
| x | 温度 | 压力 |
|---|---:|---:|
| 1 | 20 | 100 |
| 2 | 25 | 110 |
| 3 | 29 | 121 |
''');

    expect(series.length, 2);
    expect(series[0].name, '温度');
    expect(series[1].name, '压力');
    expect(series[0].points.map((p) => p.x), [1, 2, 3]);
    expect(series[0].points.map((p) => p.y), [20, 25, 29]);
    expect(series[1].points.map((p) => p.y), [100, 110, 121]);
  });

  test('parses json arrays and objects for fitting', () {
    final arrayPoints = parseDataPoints('[[1,2],[2,4],[3,6]]');
    final objectPoints =
        parseDataPoints('[{"x":1,"y":3},{"x":2,"y":5},{"x":3,"y":7}]');
    final multiSeries = parseDataSeries('''
{
  "series": [
    {"name": "温度", "data": [{"time": 1, "value": 20}, {"time": 2, "value": 25}]},
    {"name": "压力", "points": [[1, 100], [2, 110]]}
  ]
}
''');

    expect(arrayPoints.map((p) => p.x), [1, 2, 3]);
    expect(arrayPoints.map((p) => p.y), [2, 4, 6]);

    expect(objectPoints.map((p) => p.x), [1, 2, 3]);
    expect(objectPoints.map((p) => p.y), [3, 5, 7]);

    expect(multiSeries.length, 2);
    expect(multiSeries[0].name, '温度');
    expect(multiSeries[0].points.map((p) => p.y), [20, 25]);
    expect(multiSeries[1].name, '压力');
    expect(multiSeries[1].points.map((p) => p.y), [100, 110]);
  });

  test('parses column-oriented json data for fitting', () {
    final multiSeries = parseDataSeries(
      '{"x":[1,2,3],"温度":[20,25,29],"压力":[100,110,121]}',
    );
    final aliasSeries = parseDataSeries('{"time":[1,2],"value":[20,25]}');
    final autoXSeries = parseDataSeries('{"y":[2,4,6]}');
    final raggedSeries = parseDataSeries('{"x":[10,20,30],"y":[1,2]}');

    expect(multiSeries.length, 2);
    expect(multiSeries[0].name, '温度');
    expect(multiSeries[0].points.map((p) => p.x), [1, 2, 3]);
    expect(multiSeries[0].points.map((p) => p.y), [20, 25, 29]);
    expect(multiSeries[1].name, '压力');
    expect(multiSeries[1].points.map((p) => p.y), [100, 110, 121]);

    expect(aliasSeries.single.name, 'value');
    expect(aliasSeries.single.points.map((p) => p.x), [1, 2]);
    expect(aliasSeries.single.points.map((p) => p.y), [20, 25]);

    expect(autoXSeries.single.points.map((p) => p.x), [1, 2, 3]);
    expect(autoXSeries.single.points.map((p) => p.y), [2, 4, 6]);

    expect(raggedSeries.single.points.map((p) => p.x), [10, 20]);
    expect(raggedSeries.single.points.map((p) => p.y), [1, 2]);
  });

  test('parses row-oriented json and ndjson metrics for fitting', () {
    final rowSeries = parseDataSeries('''
[
  {"time": 1, "temp": 20, "pressure": 100},
  {"time": 2, "temp": 25, "pressure": 110},
  {"time": 3, "temp": 29, "pressure": 121}
]
''');
    final ndjson = parseDataSeries('''
{"step":1,"loss":0.5,"acc":0.90}
{"step":2,"loss":0.25,"acc":0.95}
{"step":3,"loss":0.125,"acc":0.975}
''');

    expect(rowSeries.length, 2);
    expect(rowSeries[0].name, 'temp');
    expect(rowSeries[1].name, 'pressure');
    expect(rowSeries[0].points.map((p) => p.x), [1, 2, 3]);
    expect(rowSeries[0].points.map((p) => p.y), [20, 25, 29]);
    expect(rowSeries[1].points.map((p) => p.y), [100, 110, 121]);

    expect(ndjson.length, 2);
    expect(ndjson[0].name, 'loss');
    expect(ndjson[1].name, 'acc');
    expect(ndjson[0].points.map((p) => p.x), [1, 2, 3]);
    expect(ndjson[0].points.map((p) => p.y), [0.5, 0.25, 0.125]);
    expect(ndjson[1].points.map((p) => p.y), [0.90, 0.95, 0.975]);
  });

  test('parses quoted numeric json values for fitting', () {
    final points =
        parseDataPoints('[{"x":"1","y":"1,200.5"},{"x":"２","y":"５０％"}]');
    final columnSeries = parseDataSeries(
      '{"time":["1","2","3"],"loss":["0.5","0.25","0.125"],"acc":["90%","95%","97.5%"]}',
    );
    final ndjson = parseDataSeries('''
{"step":"1","loss":"0.5","acc":"90%"}
{"step":"2","loss":"0.25","acc":"95%"}
{"step":"3","loss":"0.125","acc":"97.5%"}
''');

    expect(points.map((p) => p.x), [1, 2]);
    expect(points.map((p) => p.y), [1200.5, 0.5]);

    expect(columnSeries.length, 2);
    expect(columnSeries[0].name, 'loss');
    expect(columnSeries[1].name, 'acc');
    expect(columnSeries[0].points.map((p) => p.x), [1, 2, 3]);
    expect(columnSeries[0].points.map((p) => p.y), [0.5, 0.25, 0.125]);
    expect(columnSeries[1].points.map((p) => p.y), [0.9, 0.95, 0.975]);

    expect(ndjson.length, 2);
    expect(ndjson[0].points.map((p) => p.x), [1, 2, 3]);
    expect(ndjson[0].points.map((p) => p.y), [0.5, 0.25, 0.125]);
    expect(ndjson[1].points.map((p) => p.y), [0.9, 0.95, 0.975]);
  });

  test('parses localized pasted numbers for fitting', () {
    final points = parseDataPoints('x,y\n１，１,２００.５\n２,５０％\n３,－2.5');

    expect(points.map((p) => p.x), [1, 2, 3]);
    expect(points[0].y, 1200.5);
    expect(points[1].y, 0.5);
    expect(points[2].y, -2.5);
  });

  test('parses single prediction numbers with localization', () {
    expect(parseFitNumber('５０％'), 0.5);
    expect(parseFitNumber('１,２００.５'), 1200.5);
    expect(parseFitNumber('x=2'), 2);
    expect(parseFitNumber('1, 2'), isNull);
    expect(parseFitNumber('abc'), isNull);
  });

  test('extracts data fit state from copied reports', () {
    final paste = parseDataFitPasteText('''
数据拟合
数据组: y2
二次拟合
y = 2x² + 1x + 0
R²=0.999, RMSE=0.01

预测: x=7, y=105

模型建议:
二次: R²=0.999000, RMSE=0.010000

诊断:
拟合度很高

数据:
x,y1,y2
1,2,10
2,4,20
3,6,30
''');

    expect(paste.hasData, isTrue);
    expect(paste.extractedFromReport, isTrue);
    expect(paste.model, FitModel.quadratic);
    expect(paste.prediction, '7');
    expect(paste.series.length, 2);
    expect(paste.series.first.name, 'y1');
    expect(paste.series.last.name, 'y2');
    expect(paste.series.last.points.map((point) => point.y), [10, 20, 30]);
    expect(paste.data, startsWith('x,y1,y2'));
    expect(paste.summary, contains('已从报告提取数据'));
    expect(paste.summary, contains('模型 二次'));
    expect(paste.summary, contains('预测 x=7'));
  });

  test('builds data fit paste summaries for direct data and invalid text', () {
    final direct = parseDataFitPasteText('x,y\n1,2\n2,4\n3,6');
    final invalid = parseDataFitPasteText('二次拟合\n没有数据');

    expect(direct.hasData, isTrue);
    expect(direct.extractedFromReport, isFalse);
    expect(direct.series.single.points.length, 3);
    expect(direct.summary, '已粘贴数据 · 1 组 · 3 点');

    expect(invalid.hasData, isFalse);
    expect(invalid.summary, '剪贴板里没有识别到可拟合数据');
  });

  test('parses named log-style numeric fields for fitting', () {
    final series = parseDataSeries('''
INFO time=1 temp=20 pressure=100
INFO time=2 temp=25 pressure=110
INFO time=3 temp=29 pressure=121
''');
    final reordered = parseDataSeries('''
step=1 loss=0.5 acc=90%
step=2 acc=95% loss=0.25
step=3 loss=0.125 acc=97.5%
''');

    expect(series.length, 2);
    expect(series[0].name, 'temp');
    expect(series[1].name, 'pressure');
    expect(series[0].points.map((p) => p.x), [1, 2, 3]);
    expect(series[0].points.map((p) => p.y), [20, 25, 29]);
    expect(series[1].points.map((p) => p.y), [100, 110, 121]);

    expect(reordered.length, 2);
    expect(reordered[0].name, 'loss');
    expect(reordered[1].name, 'acc');
    expect(reordered[0].points.map((p) => p.y), [0.5, 0.25, 0.125]);
    expect(reordered[1].points.map((p) => p.y), [0.9, 0.95, 0.975]);
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

  test('recommends models by fit quality and reports unavailable models', () {
    final recommendations =
        recommendFitModels(parseDataPoints('-2,4\n-1,1\n0,0\n1,1\n2,4'));

    expect(recommendations.first.model, FitModel.quadratic);
    expect(recommendations.first.result?.rSquared, closeTo(1, 1e-9));
    final limitedRecommendations =
        recommendFitModels(parseDataPoints('0,0\n1,1'));
    expect(
      limitedRecommendations
          .where((item) => item.model == FitModel.quadratic)
          .single
          .warning,
      contains('二次拟合至少需要 3 个点'),
    );
  });

  test('builds diagnostics from residuals and fit quality', () {
    final result =
        fitData(parseDataPoints('1,2\n2,4.2\n3,5.9\n4,8.5'), FitModel.linear);

    final diagnostics = buildFitDiagnostics(result);

    expect(diagnostics, isNotEmpty);
    expect(diagnostics.join('\n'), contains('拟合度'));
    expect(diagnostics.join('\n'), contains('最大残差'));
  });

  test('builds residual alerts for high residual outliers', () {
    final result = fitData(
      parseDataPoints('1,2\n2,4\n3,6\n4,50\n5,10\n6,12\n7,14'),
      FitModel.linear,
    );

    final alerts = buildFitResidualAlerts(result);
    final diagnostics = buildFitDiagnostics(result).join('\n');

    expect(alerts, isNotEmpty);
    expect(alerts.first.index, 3);
    expect(alerts.first.point.x, 4);
    expect(alerts.first.residual.abs(), greaterThan(result.rmse * 2));
    expect(alerts.first.label, contains('第 4 行'));
    expect(alerts.first.label, contains('残差='));
    expect(diagnostics, contains('疑似异常点'));
    expect(diagnostics, contains('第 4 行'));
  });

  test('residual alerts stay quiet for smooth data', () {
    final result = fitData(
      parseDataPoints('1,2\n2,4.1\n3,6\n4,8.1\n5,10'),
      FitModel.linear,
    );

    expect(buildFitResidualAlerts(result), isEmpty);
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

  test('predicts fitted values and rejects invalid model domains', () {
    final linear = fitData(parseDataPoints('1,3\n2,5\n3,7'), FitModel.linear);
    final quadratic =
        fitData(parseDataPoints('-1,1\n0,0\n1,1\n2,4'), FitModel.quadratic);
    final power = fitData(parseDataPoints('1,2\n2,8\n3,18'), FitModel.power);
    final logarithmic = fitData(
      parseDataPoints('1,1\n2,2.38629436112\n4,3.77258872224'),
      FitModel.logarithmic,
    );
    final reciprocal =
        fitData(parseDataPoints('1,7\n2,4\n4,2.5'), FitModel.reciprocal);

    expect(predictFitValue(linear, 4), closeTo(9, 1e-9));
    expect(predictFitValue(quadratic, 3), closeTo(9, 1e-9));
    expect(predictFitValue(power, 4), closeTo(32, 1e-8));
    expect(predictFitValue(logarithmic, math.e), closeTo(3, 1e-9));
    expect(predictFitValue(reciprocal, 3), closeTo(3, 1e-9));
    expect(predictFitValue(power, 0).isNaN, isTrue);
    expect(predictFitValue(logarithmic, 0).isNaN, isTrue);
    expect(predictFitValue(reciprocal, 0).isNaN, isTrue);
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
