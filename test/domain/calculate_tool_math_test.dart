import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

  test('solves quadratic equations with two real roots', () {
    final results = calculateTool(tool('quadratic'), {'a': 1, 'b': -3, 'c': 2});
    expect(results.first.label, '解 (x1, x2)');
    expect(results.first.value, contains('2'));
    expect(results.first.value, contains('1'));
  });

  test('detects invalid quadratic coefficient', () {
    final results = calculateTool(tool('quadratic'), {'a': 0, 'b': 1, 'c': 2});
    expect(results.first.value, 'a 不能为 0');
  });

  test('linear system reports determinants ranks residuals and relation', () {
    final definition = tool('linear_system');
    final values = <String, double>{
      'a1': 2,
      'b1': 1,
      'c1': 5,
      'a2': 1,
      'b2': -1,
      'c2': 1,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['解 (x, y)'], '2  1');
    expect(valuesByLabel['x'], '2');
    expect(valuesByLabel['y'], '1');
    expect(valuesByLabel['D'], '-3');
    expect(valuesByLabel['Dx'], '-6');
    expect(valuesByLabel['Dy'], '-3');
    expect(valuesByLabel['系数矩阵秩'], '2');
    expect(valuesByLabel['增广矩阵秩'], '2');
    expect(valuesByLabel['方程关系'], '唯一解');
    expect(valuesByLabel['残差 1'], '0');
    expect(valuesByLabel['残差 2'], '0');
    expect(insights, contains('D 不为 0'));
    expect(insights, contains('代回残差'));
  });

  test('linear system distinguishes no solution and infinite solutions', () {
    final definition = tool('linear_system');
    final noSolutionValues = <String, double>{
      'a1': 1,
      'b1': 1,
      'c1': 2,
      'a2': 2,
      'b2': 2,
      'c2': 5,
    };
    final noSolutionResults = calculateTool(definition, noSolutionValues);
    final noSolutionByLabel = {
      for (final result in noSolutionResults) result.label: result.value,
    };
    final noSolutionInsights =
        buildToolInsights(definition, noSolutionValues, noSolutionResults)
            .join('\n');

    expect(noSolutionByLabel['解 (x, y)'], '无解');
    expect(noSolutionByLabel['方程关系'], '无解');
    expect(noSolutionByLabel['系数矩阵秩'], '1');
    expect(noSolutionByLabel['增广矩阵秩'], '2');
    expect(noSolutionInsights, contains('无交点'));

    final infiniteValues = <String, double>{
      'a1': 1,
      'b1': 1,
      'c1': 2,
      'a2': 2,
      'b2': 2,
      'c2': 4,
    };
    final infiniteResults = calculateTool(definition, infiniteValues);
    final infiniteByLabel = {
      for (final result in infiniteResults) result.label: result.value,
    };
    final infiniteInsights =
        buildToolInsights(definition, infiniteValues, infiniteResults)
            .join('\n');

    expect(infiniteByLabel['解 (x, y)'], '无穷多解');
    expect(infiniteByLabel['方程关系'], '无穷多解');
    expect(infiniteByLabel['系数矩阵秩'], '1');
    expect(infiniteByLabel['增广矩阵秩'], '1');
    expect(infiniteInsights, contains('无穷多解'));
  });

  test('linear equation reports degeneracy and substitution check', () {
    final definition = tool('linear_equation');
    final values = <String, double>{'a': 2, 'b': -6};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['解 x'], '3');
    expect(valuesByLabel['斜率 a'], '2');
    expect(valuesByLabel['截距 b'], '-6');
    expect(valuesByLabel['方程关系'], '唯一解');
    expect(valuesByLabel['验证 ax+b'], '0');
    expect(valuesByLabel['x 截距'], '3');
    expect(insights, contains('唯一 x 截距'));

    final noSolution = calculateTool(definition, {'a': 0, 'b': 2});
    final noSolutionByLabel = {
      for (final result in noSolution) result.label: result.value,
    };
    final identity = calculateTool(definition, {'a': 0, 'b': 0});
    final identityByLabel = {
      for (final result in identity) result.label: result.value,
    };

    expect(noSolutionByLabel['解 x'], '无解');
    expect(noSolutionByLabel['方程关系'], '无解');
    expect(identityByLabel['解 x'], '任意实数');
    expect(identityByLabel['方程关系'], '恒等式');
  });

  test('exponential log reports roots reciprocal and domain state', () {
    final definition = tool('exponential_log');
    final values = <String, double>{'x': 8, 'y': 3};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['x^y'], '512');
    expect(valuesByLabel['y^x'], '6561');
    expect(valuesByLabel['ln(x)'], startsWith('2.079'));
    expect(valuesByLabel['log10(x)'], startsWith('0.903'));
    expect(valuesByLabel['log_y(x)'], startsWith('1.892'));
    expect(valuesByLabel['sqrt(x)'], startsWith('2.828'));
    expect(valuesByLabel['y次根x'], '2');
    expect(valuesByLabel['1/x'], '0.125');
    expect(valuesByLabel['定义域'], '对数有效');
    expect(insights, contains('实数域'));

    final invalidDomain = calculateTool(definition, {'x': -2, 'y': 0});
    final invalidDomainByLabel = {
      for (final result in invalidDomain) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, {'x': -2, 'y': 0}, invalidDomain)
            .join('\n');

    expect(invalidDomainByLabel['ln(x)'], '无效');
    expect(invalidDomainByLabel['sqrt(x)'], '无效');
    expect(invalidDomainByLabel['y次根x'], '无效');
    expect(invalidDomainByLabel['定义域'], '对数无效');
    expect(invalidInsights, contains('x 必须大于 0'));
    expect(invalidInsights, contains('y 为 0'));
  });

  test('combination tool reports factorials repeated picks and validation', () {
    final definition = tool('combination');
    final values = <String, double>{'n': 10, 'k': 3};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['组合 C(n,k)'], '120');
    expect(valuesByLabel['排列 A(n,k)'], '720');
    expect(valuesByLabel['n!'], '3628800');
    expect(valuesByLabel['k!'], '6');
    expect(valuesByLabel['(n-k)!'], '5040');
    expect(valuesByLabel['重复排列 n^k'], '1000');
    expect(valuesByLabel['互补组合 C(n,n-k)'], '120');
    expect(valuesByLabel['选择比例 k/n'], '30');
    expect(valuesByLabel['整数校验'], '已取整数');
    expect(insights, contains('不计顺序'));

    final invalid = calculateTool(definition, {'n': 5, 'k': 6});
    final invalidByLabel = {
      for (final result in invalid) result.label: result.value,
    };
    final decimalInvalid = calculateTool(definition, {'n': 5.5, 'k': 2});
    final decimalInsights =
        buildToolInsights(definition, {'n': 5.5, 'k': 2}, decimalInvalid)
            .join('\n');

    expect(invalidByLabel['组合 C(n,k)'], '无效');
    expect(decimalInvalid.first.value, '无效');
    expect(decimalInsights, contains('只接受整数'));
  });

  test('percentage tool reverse solves base rate result and new value', () {
    final definition = tool('percentage');
    final values = <String, double>{
      'base': 200,
      'rate': 15,
      'newValue': 230,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['百分比结果'], '30');
    expect(valuesByLabel['基准值'], '200');
    expect(valuesByLabel['百分比'], '15');
    expect(valuesByLabel['增加后'], '230');
    expect(valuesByLabel['减少后'], '170');
    expect(valuesByLabel['变化率'], '15');
    expect(valuesByLabel['结果占新值'], startsWith('13.043'));
    expect(valuesByLabel['输入来源'], '基准值+百分比，结果值作参考');
    expect(valuesByLabel['新值差值'], '0');
    expect(insights, contains('新值参考值与当前计算相差 0'));

    final rateResults = calculateTool(definition, {
      'base': 200,
      'value': 30,
    });
    final rateByLabel = {
      for (final result in rateResults) result.label: result.value,
    };
    expect(rateByLabel['百分比'], '15');
    expect(rateByLabel['输入来源'], '基准值+百分比结果');

    final baseResults = calculateTool(definition, {
      'rate': 15,
      'value': 30,
    });
    final baseByLabel = {
      for (final result in baseResults) result.label: result.value,
    };
    expect(baseByLabel['基准值'], '200');
    expect(baseByLabel['输入来源'], '百分比+百分比结果');

    final newValueResults = calculateTool(definition, {
      'value': 30,
      'newValue': 230,
    });
    final newValueByLabel = {
      for (final result in newValueResults) result.label: result.value,
    };
    expect(newValueByLabel['基准值'], '200');
    expect(newValueByLabel['百分比'], '15');
    expect(newValueByLabel['输入来源'], '百分比结果+新值');
  });

  test('percentage tool rejects underdetermined and zero-base reverse cases',
      () {
    final definition = tool('percentage');
    final invalidResults = calculateTool(definition, {'base': 200});
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, {'base': 200}, invalidResults).join('\n');

    expect(invalidByLabel['百分比结果'], '无效');
    expect(invalidByLabel['输入来源'], '无效');
    expect(invalidInsights, contains('至少填写两项'));

    final zeroBaseResults =
        calculateTool(definition, {'base': 0, 'newValue': 10});
    final zeroBaseByLabel = {
      for (final result in zeroBaseResults) result.label: result.value,
    };
    expect(zeroBaseByLabel['百分比结果'], '无效');
  });

  test('scale ratio tool reverse solves each ratio field after the proportion merge',
      () {
    // 中文：这一条是并进来的 `proportion` 工具的延续——四个输入与它逐一同构
    //       （原比例↔a、原始值↔b、目标比例↔c、缩放后↔x），所以它原本断言的每一格
    //       都换成缩放这一套标签照旧断言一遍。
    // English: this continues the merged `proportion` tool — its four inputs are isomorphic to that
    //          tool's (original ratio ↔ a, original value ↔ b, target ratio ↔ c, scaled ↔ x), so every
    //          cell it asserted is asserted again under the scaling labels.
    final definition = tool('scale_ratio');
    final values = <String, double>{'from': 2, 'value': 5, 'to': 8, 'scaled': 21};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['缩放后'], '20');
    expect(valuesByLabel['原始值'], '5');
    expect(valuesByLabel['原比例'], '2');
    expect(valuesByLabel['目标比例'], '8');
    expect(valuesByLabel['比例'], '2:5 = 8:20');
    expect(valuesByLabel['比例系数'], '2.5');
    expect(valuesByLabel['右侧系数'], '2.5');
    expect(valuesByLabel['交叉乘积差'], '0');
    expect(valuesByLabel['输入来源'], '原始值+原比例+目标比例，目标值作参考');
    expect(valuesByLabel['缩放值差值'], '-1');
    expect(insights, contains('缩放后参考值与当前计算相差 -1'));

    // 中文：三项反推第四项——只给三项的那一支，没有参考值，`缩放值差值` 那一行不该出现。
    // English: three inputs back-solving the fourth — no reference value in this branch, so the
    //          `缩放值差值` row must not appear.
    final scaledResults =
        calculateTool(definition, {'from': 2, 'value': 5, 'to': 8});
    final scaledByLabel = {
      for (final result in scaledResults) result.label: result.value
    };
    expect(scaledByLabel['缩放后'], '20');
    expect(scaledByLabel['输入来源'], '原始值+原比例+目标比例');
    expect(scaledByLabel.containsKey('缩放值差值'), isFalse);

    final fromResults =
        calculateTool(definition, {'value': 5, 'to': 8, 'scaled': 20});
    final fromByLabel = {
      for (final result in fromResults) result.label: result.value
    };
    expect(fromByLabel['原比例'], '2');
    expect(fromByLabel['输入来源'], '缩放后+原始值+目标比例');

    final valueResults =
        calculateTool(definition, {'from': 2, 'to': 8, 'scaled': 20});
    final valueByLabel = {
      for (final result in valueResults) result.label: result.value
    };
    expect(valueByLabel['原始值'], '5');
    expect(valueByLabel['输入来源'], '缩放后+原比例+目标比例');

    final toResults =
        calculateTool(definition, {'from': 2, 'value': 5, 'scaled': 20});
    final toByLabel = {
      for (final result in toResults) result.label: result.value
    };
    expect(toByLabel['目标比例'], '8');
    expect(toByLabel['输入来源'], '缩放后+原始值+原比例');

    // 中文：**并进来的工具允许原比例当参考时是 0**（`a=0` 能解出 `c=0`）——这一支照旧成立，
    //       除不出的三格 `比例系数`/`右侧系数`/`缩放比例` 各自显示无效，整份结果不作废。
    // English: **the merged tool allowed a 0 source ratio as a reference** (`a=0` solves `c=0`) —
    //          that branch still holds, and the three cells that cannot divide (`比例系数`,
    //          `右侧系数`, `缩放比例`) each read invalid rather than discarding the whole result.
    final zeroRefResults =
        calculateTool(definition, {'scaled': 20, 'value': 5, 'from': 0});
    final zeroRefByLabel = {
      for (final result in zeroRefResults) result.label: result.value
    };
    expect(zeroRefByLabel['目标比例'], '0');
    expect(zeroRefByLabel['比例'], '0:5 = 0:20');
    expect(zeroRefByLabel['交叉乘积差'], '0');
    expect(zeroRefByLabel['输入来源'], '缩放后+原始值+原比例');
    expect(zeroRefByLabel['比例系数'], '无效');
    expect(zeroRefByLabel['右侧系数'], '无效');
    expect(zeroRefByLabel['缩放比例'], '无效');
  });

  test('scale ratio tool rejects missing inputs and zero divisors after the proportion merge',
      () {
    final definition = tool('scale_ratio');
    final invalidResults = calculateTool(definition, {'from': 2, 'value': 5});
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, {'from': 2, 'value': 5}, invalidResults)
            .join('\n');

    expect(invalidByLabel['缩放后'], '无效');
    expect(invalidByLabel['输入来源'], '无效');
    expect(invalidInsights, contains('至少填写三项'));

    final zeroResults = calculateTool(definition, {'from': 0, 'value': 5, 'to': 8});
    expect(zeroResults.first.value, '无效');
  });

  test('probability tool reports complements and exclusive event outcomes', () {
    final definition = tool('probability');
    final values = <String, double>{'p1': 30, 'p2': 40};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['至少一个发生'], '58');
    expect(valuesByLabel['同时发生'], '12');
    expect(valuesByLabel['仅 A 发生'], '18');
    expect(valuesByLabel['仅 B 发生'], '28');
    expect(valuesByLabel['都不发生'], '42');
    expect(valuesByLabel['至多一个发生'], '88');
    expect(valuesByLabel['A 不发生'], '70');
    expect(valuesByLabel['B 不发生'], '60');
    expect(valuesByLabel['事件 A'], '30');
    expect(valuesByLabel['事件 B'], '40');
    expect(insights, contains('按独立事件计算'));
  });

  test('probability tool rejects values outside 0 to 100 percent', () {
    final definition = tool('probability');
    final values = <String, double>{'p1': 120, 'p2': 40};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['至少一个发生'], '无效');
    expect(valuesByLabel['仅 A 发生'], '无效');
    expect(insights, contains('概率应落在 0% 到 100%'));
  });

  test('matrix tool reports inverse rank eigenvalues and norms', () {
    final definition = tool('matrix');
    final values = <String, double>{'a': 1, 'b': 2, 'c': 3, 'd': 4};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.label, '行列式 det');
    expect(results.first.value, '-2');
    expect(valuesByLabel['迹 tr'], '5');
    expect(valuesByLabel['判别项'], '33');
    expect(valuesByLabel['逆矩阵'], '[-2, 1; 1.5, -0.5]');
    expect(valuesByLabel['秩'], '2');
    expect(valuesByLabel['特征值'], contains('/'));
    expect(valuesByLabel['Frobenius范数'], startsWith('5.477'));
    expect(valuesByLabel['行和范数'], '7');
    expect(valuesByLabel['列和范数'], '6');
    expect(valuesByLabel['可逆状态'], '可逆');
    expect(insights, isNot(contains('不可逆')));
  });

  test('matrix tool flags singular matrices and complex eigenvalues', () {
    final definition = tool('matrix');
    final singularValues = <String, double>{'a': 1, 'b': 2, 'c': 2, 'd': 4};
    final singularResults = calculateTool(definition, singularValues);
    final singularByLabel = {
      for (final result in singularResults) result.label: result.value,
    };
    final singularInsights =
        buildToolInsights(definition, singularValues, singularResults)
            .join('\n');

    expect(singularByLabel['行列式 det'], '0');
    expect(singularByLabel['逆矩阵'], '不可逆');
    expect(singularByLabel['秩'], '1');
    expect(singularByLabel['可逆状态'], '不可逆');
    expect(singularInsights, contains('矩阵不可逆'));

    final rotationResults =
        calculateTool(definition, {'a': 0, 'b': -1, 'c': 1, 'd': 0});
    final rotationByLabel = {
      for (final result in rotationResults) result.label: result.value,
    };
    expect(rotationByLabel['特征值'], '0 + 1i / 0 - 1i');
  });

  test('complex tool reports division conjugates magnitudes and arguments', () {
    final definition = tool('complex');
    final values = <String, double>{'a': 3, 'b': 4, 'c': 1, 'd': -2};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['z1 + z2'], '4 + 2i');
    expect(valuesByLabel['z1 - z2'], '2 + 6i');
    expect(valuesByLabel['z1 × z2'], '11 - 2i');
    expect(valuesByLabel['z1 ÷ z2'], '-1 + 2i');
    expect(valuesByLabel['|z1|'], '5');
    expect(valuesByLabel['|z2|'], startsWith('2.236'));
    expect(valuesByLabel['arg(z1)'], startsWith('53.13'));
    expect(valuesByLabel['arg(z2)'], startsWith('-63.43'));
    expect(valuesByLabel['conj(z1)'], '3 - 4i');
    expect(valuesByLabel['conj(z2)'], '1 + 2i');
  });

  test('complex tool marks division and argument undefined for zero divisor',
      () {
    final definition = tool('complex');
    final values = <String, double>{'a': 3, 'b': 4, 'c': 0, 'd': 0};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['z1 ÷ z2'], '无效');
    expect(valuesByLabel['arg(z2)'], '无效');
    expect(insights, contains('复数除法无定义'));
    expect(insights, contains('零复数没有确定幅角'));
  });

  test('vector tool reports projections directions distance and relation', () {
    final definition = tool('vector');
    final values = <String, double>{'x1': 3, 'y1': 4, 'x2': 5, 'y2': 2};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['点积'], '23');
    expect(valuesByLabel['叉积 z'], '-14');
    expect(valuesByLabel['夹角'], startsWith('31.328'));
    expect(valuesByLabel['|A| / |B|'], startsWith('5 / 5.385'));
    expect(valuesByLabel['距离 |A-B|'], startsWith('2.828'));
    expect(valuesByLabel['cosθ'], startsWith('0.854'));
    expect(valuesByLabel['A在B方向投影'], startsWith('4.270'));
    expect(valuesByLabel['A到B投影向量'], startsWith('(3.965'));
    expect(valuesByLabel['方向角 A'], startsWith('53.13'));
    expect(valuesByLabel['方向角 B'], startsWith('21.801'));
    expect(valuesByLabel['关系'], '一般夹角');
  });

  test('vector tool identifies parallel perpendicular and zero vector cases',
      () {
    final definition = tool('vector');
    final parallelValues = <String, double>{'x1': 2, 'y1': 2, 'x2': 4, 'y2': 4};
    final parallelResults = calculateTool(definition, parallelValues);
    final parallelByLabel = {
      for (final result in parallelResults) result.label: result.value,
    };
    final parallelInsights =
        buildToolInsights(definition, parallelValues, parallelResults)
            .join('\n');
    expect(parallelByLabel['关系'], '同向平行');
    expect(parallelInsights, contains('两个向量平行'));

    final perpendicularValues = <String, double>{
      'x1': 1,
      'y1': 0,
      'x2': 0,
      'y2': 1,
    };
    final perpendicularResults = calculateTool(definition, perpendicularValues);
    final perpendicularByLabel = {
      for (final result in perpendicularResults) result.label: result.value,
    };
    final perpendicularInsights =
        buildToolInsights(definition, perpendicularValues, perpendicularResults)
            .join('\n');
    expect(perpendicularByLabel['关系'], '垂直');
    expect(perpendicularInsights, contains('两个向量垂直'));

    final zeroValues = <String, double>{'x1': 0, 'y1': 0, 'x2': 1, 'y2': 1};
    final zeroResults = calculateTool(definition, zeroValues);
    final zeroByLabel = {
      for (final result in zeroResults) result.label: result.value,
    };
    final zeroInsights =
        buildToolInsights(definition, zeroValues, zeroResults).join('\n');
    expect(zeroByLabel['夹角'], '无效');
    expect(zeroByLabel['关系'], '零向量');
    expect(zeroInsights, contains('零向量没有方向'));
  });

  test('triangle tool reports type heights inradius and circumradius', () {
    final definition = tool('triangle');
    final values = <String, double>{'a': 3, 'b': 4, 'c': 5};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['面积'], '6');
    expect(valuesByLabel['周长'], '12');
    expect(valuesByLabel['半周长'], '6');
    expect(valuesByLabel['角 A/B/C'], contains('90'));
    expect(valuesByLabel['边长类型'], '不等边直角');
    expect(valuesByLabel['最长边'], '5');
    expect(valuesByLabel['最短边'], '3');
    expect(valuesByLabel['高 ha/hb/hc'], '4 / 3 / 2.4');
    expect(valuesByLabel['内切圆半径'], '1');
    expect(valuesByLabel['外接圆半径'], '2.5');
    expect(insights, contains('当前三角形类型为不等边直角'));
  });

  test('triangle tool rejects invalid sides and warns near degeneration', () {
    final definition = tool('triangle');
    final invalidValues = <String, double>{'a': 1, 'b': 2, 'c': 3};
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults).join('\n');

    expect(invalidByLabel['面积'], '无效');
    expect(invalidByLabel['周长'], '无效');
    expect(invalidInsights, contains('三边必须为正'));

    final nearValues = <String, double>{'a': 1, 'b': 1, 'c': 1.96};
    final nearResults = calculateTool(definition, nearValues);
    final nearInsights =
        buildToolInsights(definition, nearValues, nearResults).join('\n');

    expect(nearResults.first.value, isNot('无效'));
    expect(nearInsights, contains('三角形接近退化'));
  });

  test('circle tool reverse solves radius diameter circumference and area', () {
    final definition = tool('circle');
    final values = <String, double>{'r': 5, 'diameter': 10, 'area': 78.5};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['面积'], startsWith('78.539'));
    expect(valuesByLabel['半径'], '5');
    expect(valuesByLabel['直径'], '10');
    expect(valuesByLabel['周长'], startsWith('31.415'));
    expect(valuesByLabel['半周长'], startsWith('15.707'));
    expect(valuesByLabel['输入来源'], '半径，其他圆形量作参考');
    expect(valuesByLabel['面积差值'], startsWith('0.039'));
    expect(insights, contains('面积参考值与当前计算相差 0.039'));

    final radiusFromArea = calculateTool(definition, {'area': math.pi * 25});
    final radiusFromAreaByLabel = {
      for (final result in radiusFromArea) result.label: result.value,
    };
    expect(radiusFromAreaByLabel['半径'], '5');
    expect(radiusFromAreaByLabel['输入来源'], '面积');

    final radiusFromCircumference =
        calculateTool(definition, {'circumference': 2 * math.pi * 5});
    final radiusFromCircumferenceByLabel = {
      for (final result in radiusFromCircumference) result.label: result.value,
    };
    expect(radiusFromCircumferenceByLabel['半径'], '5');
    expect(radiusFromCircumferenceByLabel['输入来源'], '周长');
  });

  test('circle tool rejects missing and negative geometry inputs', () {
    final definition = tool('circle');
    final missingResults = calculateTool(definition, {});
    final missingByLabel = {
      for (final result in missingResults) result.label: result.value,
    };
    final missingInsights =
        buildToolInsights(definition, {}, missingResults).join('\n');

    expect(missingByLabel['面积'], '无效');
    expect(missingByLabel['输入来源'], '无效');
    expect(missingInsights, contains('至少填写一项'));

    final negativeResults = calculateTool(definition, {'r': -1});
    expect(negativeResults.first.value, '无效');
  });

  test('scale ratio tool reverse solves value and ratio fields', () {
    final definition = tool('scale_ratio');
    final values = <String, double>{
      'value': 120,
      'from': 100,
      'to': 75,
      'scaled': 100,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['缩放后'], '90');
    expect(valuesByLabel['原始值'], '120');
    expect(valuesByLabel['原比例'], '100');
    expect(valuesByLabel['目标比例'], '75');
    expect(valuesByLabel['缩放比例'], '0.75');
    expect(valuesByLabel['面积比例'], '0.5625');
    expect(valuesByLabel['体积比例'], '0.421875');
    expect(valuesByLabel['输入来源'], '原始值+原比例+目标比例，目标值作参考');
    expect(valuesByLabel['缩放值差值'], '-10');
    expect(insights, contains('缩放后参考值与当前计算相差 -10'));

    final valueResults = calculateTool(definition, {
      'scaled': 90,
      'from': 100,
      'to': 75,
    });
    final valueByLabel = {
      for (final result in valueResults) result.label: result.value,
    };
    expect(valueByLabel['原始值'], '120');
    expect(valueByLabel['输入来源'], '缩放后+原比例+目标比例');

    final toResults = calculateTool(definition, {
      'scaled': 90,
      'value': 120,
      'from': 100,
    });
    final toByLabel = {
      for (final result in toResults) result.label: result.value,
    };
    expect(toByLabel['目标比例'], '75');
    expect(toByLabel['输入来源'], '缩放后+原始值+原比例');
  });

  test('scale ratio tool rejects underdetermined and zero source ratio', () {
    final definition = tool('scale_ratio');
    final invalidResults = calculateTool(definition, {
      'value': 120,
      'from': 0,
      'to': 75,
    });
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights = buildToolInsights(
            definition, {'value': 120, 'from': 0, 'to': 75}, invalidResults)
        .join('\n');

    expect(invalidByLabel['缩放后'], '无效');
    expect(invalidByLabel['输入来源'], '无效');
    expect(invalidInsights, contains('至少填写三项'));
  });
}
