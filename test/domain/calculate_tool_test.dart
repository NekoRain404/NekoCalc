import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_capabilities.dart';
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

  test('proportion tool reverse solves each ratio field', () {
    final definition = tool('proportion');
    final values = <String, double>{'a': 2, 'b': 5, 'c': 8, 'x': 21};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['x'], '20');
    expect(valuesByLabel['a'], '2');
    expect(valuesByLabel['b'], '5');
    expect(valuesByLabel['c'], '8');
    expect(valuesByLabel['比例'], '2:5 = 8:20');
    expect(valuesByLabel['比例系数'], '2.5');
    expect(valuesByLabel['右侧系数'], '2.5');
    expect(valuesByLabel['交叉乘积差'], '0');
    expect(valuesByLabel['输入来源'], 'a+b+c，x作参考');
    expect(valuesByLabel['x差值'], '-1');
    expect(insights, contains('x 参考值与当前计算相差 -1'));

    final aResults = calculateTool(definition, {'b': 5, 'c': 8, 'x': 20});
    final aByLabel = {
      for (final result in aResults) result.label: result.value
    };
    expect(aByLabel['a'], '2');
    expect(aByLabel['输入来源'], 'b+c+x');

    final bResults = calculateTool(definition, {'a': 2, 'c': 8, 'x': 20});
    final bByLabel = {
      for (final result in bResults) result.label: result.value
    };
    expect(bByLabel['b'], '5');
    expect(bByLabel['输入来源'], 'a+c+x');

    final cResults = calculateTool(definition, {'a': 2, 'b': 5, 'x': 20});
    final cByLabel = {
      for (final result in cResults) result.label: result.value
    };
    expect(cByLabel['c'], '8');
    expect(cByLabel['输入来源'], 'a+b+x');
  });

  test('proportion tool rejects missing and zero denominator cases', () {
    final definition = tool('proportion');
    final invalidResults = calculateTool(definition, {'a': 2, 'b': 5});
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, {'a': 2, 'b': 5}, invalidResults)
            .join('\n');

    expect(invalidByLabel['x'], '无效');
    expect(invalidByLabel['输入来源'], '无效');
    expect(invalidInsights, contains('至少填写三项'));

    final zeroResults = calculateTool(definition, {'a': 0, 'b': 5, 'c': 8});
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

  test('calculates ohms law voltage and tolerance range', () {
    final definition = tool('ohms_law');
    final values = <String, double>{'current': 2, 'resistance': 5, 'tol': 10};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.label, '电压 V');
    expect(results.first.value, '10');
    expect(valuesByLabel['电压幅值'], '10');
    expect(valuesByLabel['功率 P'], '20');
    expect(valuesByLabel['电流'], '2000');
    expect(valuesByLabel['电阻'], '0.005');
    expect(valuesByLabel['电导'], '200');
    expect(valuesByLabel['推荐功率'], '≥ 40W');
    expect(valuesByLabel['电压范围'], '9 ~ 11');
    expect(valuesByLabel['功率范围'], '18 ~ 22');
    expect(valuesByLabel['输入来源'], '电流+电阻');
    expect(insights, contains('功耗超过 0.25W'));
  });

  test('ohms law reverse solves from power with resistance or voltage', () {
    final definition = tool('ohms_law');
    final fromPowerResistance = calculateTool(definition, {
      'power': 2,
      'resistance': 8,
      'tol': 10,
    });
    final prByLabel = {
      for (final result in fromPowerResistance) result.label: result.value,
    };
    final fromPowerVoltage = calculateTool(definition, {
      'power': 2,
      'voltage': 4,
    });
    final pvByLabel = {
      for (final result in fromPowerVoltage) result.label: result.value,
    };
    final insights = buildToolInsights(
      definition,
      {'power': 2, 'resistance': 8, 'tol': 10},
      fromPowerResistance,
    ).join('\n');

    expect(prByLabel['电压 V'], '4');
    expect(prByLabel['功率 P'], '2');
    expect(prByLabel['电流'], '500');
    expect(prByLabel['电阻'], '0.008');
    expect(prByLabel['输入来源'], '功率+电阻');
    expect(prByLabel['电压范围'], '3.6 ~ 4.4');
    expect(pvByLabel['电流'], '500');
    expect(pvByLabel['电阻'], '0.008');
    expect(pvByLabel['输入来源'], '功率+电压');
    expect(insights, contains('当前按 功率+电阻 反推欧姆定律其它量'));
  });

  test('ohms law rejects non-positive resistance', () {
    final definition = tool('ohms_law');
    final values = <String, double>{'current': 2, 'resistance': 0, 'tol': 10};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['电压 V'], '无效');
    expect(valuesByLabel['功率 P'], '无效');
    expect(valuesByLabel['电导'], '无效');
    expect(valuesByLabel['推荐功率'], '无效');
    expect(insights, contains('至少填写两项'));
  });

  test('ohms law keeps power positive for negative current direction', () {
    final definition = tool('ohms_law');
    final values = <String, double>{
      'current': -0.5,
      'resistance': 10,
      'tol': 5
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['电压 V'], '-5');
    expect(valuesByLabel['电压幅值'], '5');
    expect(valuesByLabel['功率 P'], '2.5');
    expect(valuesByLabel['电压范围'], '-5.25 ~ -4.75');
    expect(valuesByLabel['功率范围'], '2.375 ~ 2.625');
    expect(insights, contains('电流为负表示参考方向相反'));
  });

  test('statistics reports multi sample descriptive metrics', () {
    final definition = tool('statistics');
    final values = <String, double>{
      'x1': 2,
      'x2': 4,
      'x3': 4,
      'x4': 4,
      'x5': 5,
      'x6': 5,
      'x7': 7,
      'x8': 9,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final unitsByLabel = {
      for (final result in results) result.label: result.unit,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.label, '平均值');
    expect(results.first.value, '5');
    expect(valuesByLabel['样本数'], '8');
    expect(valuesByLabel['中位数'], '4.5');
    expect(valuesByLabel['总和'], '40');
    expect(valuesByLabel['最小值'], '2');
    expect(valuesByLabel['最大值'], '9');
    expect(valuesByLabel['极差'], '7');
    expect(valuesByLabel['样本标准差'], startsWith('2.138'));
    expect(valuesByLabel['样本方差'], startsWith('4.571'));
    expect(valuesByLabel['总体标准差'], '2');
    expect(valuesByLabel['总体方差'], '4');
    expect(valuesByLabel['变异系数'], startsWith('42.761'));
    expect(unitsByLabel['变异系数'], '%');
    expect(insights, contains('当前按 8 个有效样本计算'));
    expect(insights, contains('变异系数超过 30%'));
  });

  test('statistics ignores omitted optional samples', () {
    final results = calculateTool(tool('statistics'), {
      'x1': 10,
      'x2': 20,
      'x3': 30,
    });
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['样本数'], '3');
    expect(valuesByLabel['平均值'], '20');
    expect(valuesByLabel['中位数'], '20');
    expect(valuesByLabel['总和'], '60');
    expect(valuesByLabel['总体标准差'], startsWith('8.164'));
    expect(valuesByLabel['样本标准差'], '10');
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

  test('dBm converter includes 50 ohm RF voltage outputs', () {
    final definition = tool('dbm');
    final values = <String, double>{'dbm': 30};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['功率'], '1000');
    expect(valuesByLabel['微瓦'], '1000000');
    expect(valuesByLabel['瓦特'], '1');
    expect(valuesByLabel['dBW'], '0');
    expect(valuesByLabel['50Ω Vrms'], startsWith('7.071'));
    expect(valuesByLabel['50Ω Vpeak'], '10');
    expect(valuesByLabel['50Ω Vpp'], '20');
    expect(valuesByLabel['50Ω dBV'], startsWith('16.989'));
    expect(valuesByLabel['50Ω dBu'], startsWith('19.203'));
    expect(insights, contains('50Ω 电压按正弦波和匹配负载估算'));
  });

  test('dBm converter warns about very low RF power', () {
    final definition = tool('dbm');
    final values = <String, double>{'dbm': -120};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['功率'], '1e-12');
    expect(valuesByLabel['微瓦'], '1e-9');
    expect(insights, contains('低于 -100dBm'));
  });

  test('dBm converter rejects non-finite input', () {
    final definition = tool('dbm');
    final values = <String, double>{'dbm': double.infinity};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['功率'], '无效');
    expect(valuesByLabel['瓦特'], '无效');
    expect(valuesByLabel['50Ω Vrms'], '无效');
    expect(valuesByLabel['50Ω dBV'], '无效');
    expect(insights, contains('dBm 输入必须是有限数值'));
  });

  test('LED resistor reports voltage headroom and power rating', () {
    final results = calculateTool(tool('led_resistor'), {
      'vin': 5,
      'vf': 2,
      'current': 10,
      'vfTol': 0.1,
    });
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['限流电阻'], '300');
    expect(valuesByLabel['可用压差'], '3');
    expect(valuesByLabel['最小压差'], '2.9');
    expect(valuesByLabel['功耗'], '30');
    expect(valuesByLabel['推荐功率'], '≥ 1/8W');
    expect(valuesByLabel['电阻范围'], '290 ~ 310');
  });

  test('LED resistor checks selected resistor current and power', () {
    final definition = tool('led_resistor');
    final values = <String, double>{
      'vin': 5,
      'vf': 2,
      'current': 10,
      'vfTol': 0.1,
      'selectedResistance': 330,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['限流电阻'], '300');
    expect(valuesByLabel['选用电阻'], '330');
    expect(valuesByLabel['实际电流'], startsWith('9.090'));
    expect(valuesByLabel['实际功耗'], startsWith('27.272'));
    expect(valuesByLabel['实际推荐功率'], '≥ 1/8W');
    expect(valuesByLabel['电流偏差'], startsWith('-0.909'));
    expect(valuesByLabel['实际电流范围'], contains('8.787'));
    expect(valuesByLabel['实际电流范围'], contains('9.393'));
    expect(insights, contains('选用电阻校核按标称阻值计算'));
  });

  test('LED resistor rejects missing voltage headroom', () {
    final results = calculateTool(tool('led_resistor'), {
      'vin': 3,
      'vf': 3.2,
      'current': 10,
      'vfTol': 0.1,
    });
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['限流电阻'], '无效');
    expect(valuesByLabel['可用压差'], '-0.2');
    expect(valuesByLabel['最小压差'], '-0.3');
    expect(valuesByLabel['功耗'], '无效');
    expect(valuesByLabel['推荐功率'], '无效');
    expect(valuesByLabel['电阻范围'], '无效');
    expect(
        results.map((item) => item.value).join('\n'), isNot(contains('-20')));
  });

  test('LED resistor rejects tolerance range without minimum headroom', () {
    final results = calculateTool(tool('led_resistor'), {
      'vin': 3.25,
      'vf': 3.2,
      'current': 10,
      'vfTol': 0.1,
    });
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['限流电阻'], '5');
    expect(valuesByLabel['可用压差'], '0.05');
    expect(valuesByLabel['最小压差'], '-0.05');
    expect(valuesByLabel['功耗'], '0.5');
    expect(valuesByLabel['电阻范围'], '无效');
  });

  test('LED resistor rejects invalid selected resistor', () {
    final results = calculateTool(tool('led_resistor'), {
      'vin': 5,
      'vf': 2,
      'current': 10,
      'selectedResistance': 0,
    });
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['限流电阻'], '无效');
    expect(valuesByLabel['选用电阻'], '无效');
    expect(valuesByLabel['实际电流'], '无效');
    expect(valuesByLabel['实际功耗'], '无效');
  });

  test('voltage divider reports load effect current and resistor power', () {
    final definition = tool('voltage_divider');
    final values = <String, double>{
      'vin': 12,
      'r1': 10,
      'r2': 20,
      'load': 100,
      'tol': 1,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['输出电压 Vout'], '7.5');
    expect(valuesByLabel['空载输出'], '8');
    expect(valuesByLabel['下臂等效'], startsWith('16.666'));
    expect(valuesByLabel['分压电流'], '0.45');
    expect(valuesByLabel['负载电流'], '0.075');
    expect(valuesByLabel['总功耗'], '5.4');
    expect(valuesByLabel['上臂功耗'], '2.025');
    expect(valuesByLabel['下臂功耗'], '2.8125');
    expect(valuesByLabel['误差范围'], '7.425~7.575');
    expect(insights, contains('负载使输出偏离空载值超过 5%'));
  });

  test('voltage divider backsolves target output with load effect', () {
    final definition = tool('voltage_divider');
    final values = <String, double>{
      'vin': 12,
      'r1': 10,
      'r2': 20,
      'load': 100,
      'tol': 1,
      'targetVout': 5,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['输出电压 Vout'], '7.5');
    expect(valuesByLabel['目标输出电压'], '5');
    expect(valuesByLabel['输出偏差'], '2.5');
    expect(valuesByLabel['保留R2所需R1'], startsWith('23.333'));
    expect(valuesByLabel['保留R1所需R2'], startsWith('7.692'));
    expect(valuesByLabel['目标下臂等效'], startsWith('7.142'));
    expect(insights, contains('当前输出与目标相差 2.5V'));
    expect(insights, contains('目标反推会计入负载并联'));
  });

  test('voltage divider rejects unreachable target output', () {
    final definition = tool('voltage_divider');
    final values = <String, double>{
      'vin': 12,
      'r1': 10,
      'r2': 20,
      'load': 100,
      'targetVout': 12,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['输出电压 Vout'], '7.5');
    expect(valuesByLabel['目标输出电压'], '无效');
    expect(valuesByLabel['输出偏差'], '无效');
    expect(valuesByLabel['保留R2所需R1'], '无效');
    expect(valuesByLabel['保留R1所需R2'], '无效');
    expect(insights, contains('目标输出需要与 Vin 同极性'));
  });

  test('voltage divider rejects invalid resistor inputs', () {
    final definition = tool('voltage_divider');
    final values = <String, double>{
      'vin': 12,
      'r1': 10,
      'r2': 0,
      'load': 100,
      'tol': 1,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['输出电压 Vout'], '无效');
    expect(valuesByLabel['空载输出'], '无效');
    expect(valuesByLabel['分压电流'], '无效');
    expect(valuesByLabel['误差范围'], '无效');
    expect(insights, contains('R1、R2 必须大于 0，负载电阻不能为负'));
  });

  test('voltage divider warns about very low divider current', () {
    final definition = tool('voltage_divider');
    final values = <String, double>{
      'vin': 3.3,
      'r1': 1000,
      'r2': 1000,
      'load': 0,
      'tol': 1,
    };
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, '1.65');
    expect(insights, contains('分压电流低于 50μA'));
  });

  test('RC filter reports cutoff frequency bands and tolerance range', () {
    final definition = tool('rc_filter');
    final values = <String, double>{'r': 10, 'c': 100, 'tol': 5};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['截止频率 fcHz'], startsWith('159.154'));
    expect(valuesByLabel['截止频率kHz'], '0.159155');
    expect(valuesByLabel['时间常数 τms'], '1');
    expect(valuesByLabel['等效周期ms'], startsWith('6.28318'));
    expect(valuesByLabel['0.1fcHz'], startsWith('15.915'));
    expect(valuesByLabel['10fcHz'], startsWith('1591.549'));
    expect(valuesByLabel['100fcHz'], startsWith('15915.494'));
    expect(valuesByLabel['fc范围Hz'], contains('144.358'));
    expect(valuesByLabel['fc范围Hz'], contains('176.348'));
    expect(insights, contains('fc 是 -3dB 点'));
  });

  test('RC filter backsolves target cutoff resistor and capacitor', () {
    final definition = tool('rc_filter');
    final values = <String, double>{
      'r': 10,
      'c': 100,
      'tol': 5,
      'targetFc': 1000,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['目标截止频率Hz'], '1000');
    expect(valuesByLabel['频率偏差Hz'], startsWith('-840.845'));
    expect(valuesByLabel['保留C所需RkΩ'], startsWith('1.591'));
    expect(valuesByLabel['保留R所需CnF'], startsWith('15.915'));
    expect(valuesByLabel['目标时间常数 τms'], startsWith('0.159'));
    expect(insights, contains('当前截止频率与目标相差'));
    expect(insights, contains('目标反推按理想一阶 RC 计算'));
  });

  test('RC filter rejects non-positive components', () {
    final definition = tool('rc_filter');
    final values = <String, double>{'r': 0, 'c': 100, 'tol': 5};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['截止频率 fcHz'], '无效');
    expect(valuesByLabel['时间常数 τms'], '无效');
    expect(valuesByLabel['等效周期ms'], '无效');
    expect(valuesByLabel['fc范围Hz'], '无效');
    expect(insights, contains('R、C 和目标截止频率都必须大于 0，才能计算 RC 截止频率'));
  });

  test('RC filter rejects non-positive target cutoff', () {
    final definition = tool('rc_filter');
    final values = <String, double>{'r': 10, 'c': 100, 'targetFc': 0};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['截止频率 fcHz'], '无效');
    expect(valuesByLabel['目标截止频率Hz'], '无效');
    expect(valuesByLabel['保留C所需RkΩ'], '无效');
    expect(valuesByLabel['保留R所需CnF'], '无效');
    expect(insights, contains('目标截止频率都必须大于 0'));
  });

  test('RC filter warns when tolerance is too wide', () {
    final definition = tool('rc_filter');
    final values = <String, double>{'r': 10, 'c': 100, 'tol': 30};
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, startsWith('159.154'));
    expect(insights, contains('元件公差超过 20%'));
  });

  test('resistor network reports conductance ratio and tolerance ranges', () {
    final definition = tool('resistor_network');
    final values = <String, double>{'r1': 1000, 'r2': 2200, 'tol': 5};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['串联等效'], '3200');
    expect(valuesByLabel['并联等效'], '687.5');
    expect(valuesByLabel['总电导'], startsWith('1.454'));
    expect(valuesByLabel['元件比值'], '2.2');
    expect(valuesByLabel['串联范围'], '3040 ~ 3360');
    expect(valuesByLabel['并联范围'], '653.125 ~ 721.875');
    expect(insights, contains('单个电阻的功耗'));
  });

  test('resistor network backsolves target series and parallel mates', () {
    final definition = tool('resistor_network');
    final values = <String, double>{
      'r1': 1000,
      'r2': 2200,
      'targetSeries': 4700,
      'targetParallel': 680,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['串联目标所需R2'], '3700');
    expect(valuesByLabel['并联目标所需R2'], '2125');
  });

  test('network target reverse solve reports impossible equivalents', () {
    final resistorTool = tool('resistor_network');
    final capacitorTool = tool('capacitor_network');
    final inductorTool = tool('inductor_network');
    final resistorValues = <String, double>{
      'r1': 1000,
      'r2': 2200,
      'targetParallel': 1200,
    };
    final capacitorValues = <String, double>{
      'c1': 100,
      'c2': 220,
      'targetSeries': 120,
    };
    final inductorValues = <String, double>{
      'l1': 10,
      'l2': 22,
      'targetParallel': 12,
    };
    final resistorResults = calculateTool(resistorTool, resistorValues);
    final capacitorResults = calculateTool(capacitorTool, capacitorValues);
    final inductorResults = calculateTool(inductorTool, inductorValues);
    final resistorByLabel = {
      for (final result in resistorResults) result.label: result.value,
    };
    final capacitorByLabel = {
      for (final result in capacitorResults) result.label: result.value,
    };
    final inductorByLabel = {
      for (final result in inductorResults) result.label: result.value,
    };

    expect(resistorByLabel['并联目标所需R2'], '无效');
    expect(capacitorByLabel['串联目标所需C2'], '无效');
    expect(inductorByLabel['并联目标所需L2'], '无效');
    expect(
      buildToolInsights(resistorTool, resistorValues, resistorResults)
          .join('\n'),
      contains('目标并联等效必须小于 R1'),
    );
    expect(
      buildToolInsights(capacitorTool, capacitorValues, capacitorResults)
          .join('\n'),
      contains('目标串联等效必须小于 C1'),
    );
    expect(
      buildToolInsights(inductorTool, inductorValues, inductorResults)
          .join('\n'),
      contains('目标并联等效必须小于 L1'),
    );
  });

  test('network tools reject non-positive component values', () {
    Map<String, String> values(String toolId, Map<String, double> input) => {
          for (final result in calculateTool(tool(toolId), input))
            result.label: result.value,
        };

    final resistor = values('resistor_network', {
      'r1': 1000,
      'r2': 0,
      'tol': 5,
    });
    final capacitor = values('capacitor_network', {
      'c1': -100,
      'c2': 220,
      'tol': 10,
    });
    final inductor = values('inductor_network', {
      'l1': 10,
      'l2': 0,
      'tol': 10,
    });

    expect(resistor['串联等效'], '无效');
    expect(resistor['并联等效'], '无效');
    expect(capacitor['并联等效'], '无效');
    expect(capacitor['串联等效'], '无效');
    expect(inductor['串联等效'], '无效');
    expect(inductor['并联等效'], '无效');
  });

  test('capacitor and inductor networks report ratios and insights', () {
    final capacitorTool = tool('capacitor_network');
    final inductorTool = tool('inductor_network');
    final capacitorValues = <String, double>{'c1': 100, 'c2': 220, 'tol': 10};
    final inductorValues = <String, double>{'l1': 10, 'l2': 22, 'tol': 10};
    final capacitorResults = calculateTool(capacitorTool, capacitorValues);
    final inductorResults = calculateTool(inductorTool, inductorValues);
    final capacitorByLabel = {
      for (final result in capacitorResults) result.label: result.value,
    };
    final inductorByLabel = {
      for (final result in inductorResults) result.label: result.value,
    };

    expect(capacitorByLabel['并联等效'], '320');
    expect(capacitorByLabel['串联等效'], '68.75');
    expect(capacitorByLabel['元件比值'], '2.2');
    expect(capacitorByLabel['并联范围'], '288 ~ 352');
    expect(capacitorByLabel['串联范围'], '61.875 ~ 75.625');
    expect(
      calculateTool(capacitorTool, {
        'c1': 100,
        'c2': 220,
        'targetParallel': 470,
        'targetSeries': 68.75,
      }).where((result) => result.label.endsWith('所需C2')).map(
            (result) => result.value,
          ),
      containsAll(['370', '220']),
    );
    expect(inductorByLabel['串联等效'], '32');
    expect(inductorByLabel['并联等效'], '6.875');
    expect(inductorByLabel['元件比值'], '2.2');
    expect(
      calculateTool(inductorTool, {
        'l1': 10,
        'l2': 22,
        'targetSeries': 33,
        'targetParallel': 6.875,
      }).where((result) => result.label.endsWith('所需L2')).map(
            (result) => result.value,
          ),
      containsAll(['23', '22']),
    );
    expect(
      buildToolInsights(capacitorTool, capacitorValues, capacitorResults)
          .join('\n'),
      contains('漏电差异会影响均压'),
    );
    expect(
      buildToolInsights(inductorTool, inductorValues, inductorResults)
          .join('\n'),
      contains('忽略互感'),
    );
  });

  test('DCDC feedback reports divider current and resistor power', () {
    final definition = tool('dcdc_feedback');
    final values = <String, double>{'vref': 0.8, 'rtop': 100, 'rbottom': 20};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['输出电压'], '4.8');
    expect(valuesByLabel['分压比'], '5');
    expect(valuesByLabel['反馈电压'], '0.8');
    expect(valuesByLabel['上拉压降'], '4');
    expect(valuesByLabel['反馈电流'], '0.04');
    expect(valuesByLabel['反馈总阻值'], '120');
    expect(valuesByLabel['上拉功耗'], '0.16');
    expect(valuesByLabel['下拉功耗'], '0.032');
    expect(valuesByLabel['反馈总功耗'], '0.192');
    expect(insights, contains('反馈电阻过大会怕漏电和噪声'));
  });

  test('DCDC feedback backsolves target output and divider current', () {
    final definition = tool('dcdc_feedback');
    final values = <String, double>{
      'vref': 0.8,
      'rtop': 100,
      'rbottom': 20,
      'targetVout': 5,
      'targetCurrent': 0.05,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['目标输出电压'], '5');
    expect(valuesByLabel['输出偏差'], '-0.2');
    expect(valuesByLabel['输出偏差比例'], '-4');
    expect(valuesByLabel['目标分压比'], '5.25');
    expect(valuesByLabel['保留下拉所需上拉'], '105');
    expect(valuesByLabel['保留上拉所需下拉'], startsWith('19.047'));
    expect(valuesByLabel['目标反馈电流'], '0.05');
    expect(valuesByLabel['反馈电流偏差'], '-0.01');
    expect(valuesByLabel['目标上拉电阻'], '84');
    expect(valuesByLabel['目标下拉电阻'], '16');
    expect(valuesByLabel['目标总阻值'], '100');
    expect(valuesByLabel['目标反馈功耗'], '0.25');
    expect(insights, contains('当前反馈电阻相对目标输出偏差超过 1%'));
  });

  test('DCDC feedback rejects invalid divider values', () {
    final definition = tool('dcdc_feedback');
    final values = <String, double>{'vref': 0.8, 'rtop': 100, 'rbottom': 0};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['输出电压'], '无效');
    expect(valuesByLabel['反馈电流'], '无效');
    expect(valuesByLabel['上拉功耗'], '无效');
    expect(
      insights,
      contains('Vref 必须大于 0，Rbottom 必须大于 0，Rtop 不能为负，目标输出不能低于 Vref'),
    );
  });

  test('DCDC feedback warns about very low divider current', () {
    final definition = tool('dcdc_feedback');
    final values = <String, double>{
      'vref': 0.8,
      'rtop': 10000,
      'rbottom': 2000
    };
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, '4.8');
    expect(insights, contains('反馈电流低于 10μA'));
  });

  test('LC resonance reports frequency units period reactance q and bandwidth',
      () {
    final definition = tool('lc_resonance');
    final values = <String, double>{'l': 10, 'c': 100, 'esr': 0.5};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['谐振频率Hz'], startsWith('159154.943'));
    expect(valuesByLabelUnit['谐振频率kHz'], startsWith('159.154'));
    expect(valuesByLabelUnit['谐振频率MHz'], '0.159155');
    expect(valuesByLabelUnit['角频率 ω0rad/s'], '1000000');
    expect(valuesByLabelUnit['周期μs'], startsWith('6.28318'));
    expect(valuesByLabelUnit['谐振感抗 XLΩ'], '10');
    expect(valuesByLabelUnit['谐振容抗 XCΩ'], '10');
    expect(valuesByLabelUnit['ESRΩ'], '0.5');
    expect(valuesByLabelUnit['Q值(串联)'], '20');
    expect(valuesByLabelUnit['3dB带宽Hz'], startsWith('7957.747'));
    expect(valuesByLabelUnit['下半功率点Hz'], startsWith('155176.069'));
    expect(valuesByLabelUnit['上半功率点Hz'], startsWith('163133.816'));
    expect(insights, contains('3dB 带宽约为中心频率的 5%'));
    expect(insights, contains('DCR、ESR'));
  });

  test('LC resonance rejects non-positive components', () {
    final definition = tool('lc_resonance');
    final values = <String, double>{'l': 10, 'c': 0};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['谐振频率Hz'], '无效');
    expect(valuesByLabelUnit['周期μs'], '无效');
    expect(valuesByLabelUnit['谐振感抗 XLΩ'], '无效');
    expect(valuesByLabelUnit['谐振容抗 XCΩ'], '无效');
    expect(valuesByLabelUnit['Q值(串联)'], '无效');
    expect(insights, contains('L 和 C 必须大于 0，ESR 不能为负'));
  });

  test('LC resonance warns when parasitics dominate high frequency design', () {
    final definition = tool('lc_resonance');
    final values = <String, double>{'l': 0.01, 'c': 1};
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, startsWith('50329212'));
    expect(insights, contains('谐振频率超过 10MHz'));
    expect(insights, contains('未填写 ESR'));
  });

  test('op amp gain reports dB feedback factor and resistor network', () {
    final definition = tool('op_amp_gain');
    final values = <String, double>{'rin': 10, 'rf': 100, 'vin': 0.2};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['同相增益倍'], '11');
    expect(valuesByLabelUnit['反相增益倍'], '-10');
    expect(valuesByLabelUnit['同相增益 dBdB'], startsWith('20.827'));
    expect(valuesByLabelUnit['反相增益 dBdB'], '20');
    expect(valuesByLabelUnit['同相输出V'], '2.2');
    expect(valuesByLabelUnit['反相输出V'], '-2');
    expect(valuesByLabelUnit['电阻比 Rf/Rin'], '10');
    expect(valuesByLabelUnit['反馈系数 β'], startsWith('0.090909'));
    expect(valuesByLabelUnit['反相输入阻抗kΩ'], '10');
    expect(valuesByLabelUnit['反馈总阻值kΩ'], '110');
    expect(insights, contains('结果是理想增益'));
  });

  test('op amp gain backsolves target gain bandwidth and slew rate', () {
    final definition = tool('op_amp_gain');
    final values = <String, double>{
      'rin': 10,
      'rf': 100,
      'vin': 0.2,
      'targetGain': 21,
      'gbw': 1000000,
      'outputSwing': 2,
      'fullPowerFrequency': 10000,
    };
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['目标同相增益倍'], '21');
    expect(valuesByLabelUnit['目标所需RfkΩ'], '200');
    expect(valuesByLabelUnit['保留Rf所需RinkΩ'], '5');
    expect(valuesByLabelUnit['反相目标所需RfkΩ'], '210');
    expect(valuesByLabelUnit['同相闭环带宽Hz'], startsWith('90909.09'));
    expect(valuesByLabelUnit['反相闭环带宽Hz'], '100000');
    expect(valuesByLabelUnit['所需压摆率V/μs'], startsWith('0.125664'));
    expect(insights, contains('目标同相增益按保留 Rin 反推 Rf'));
  });

  test('op amp gain rejects invalid feedback resistors', () {
    final definition = tool('op_amp_gain');
    final values = <String, double>{'rin': 0, 'rf': 100, 'vin': 0.2};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['同相增益倍'], '无效');
    expect(valuesByLabelUnit['反相增益倍'], '无效');
    expect(valuesByLabelUnit['反馈系数 β'], '无效');
    expect(valuesByLabelUnit['反馈总阻值kΩ'], '无效');
    expect(insights, contains('Rin 必须大于 0，Rf 不能为负'));
  });

  test('op amp gain warns about high closed-loop gain and feedback impedance',
      () {
    final definition = tool('op_amp_gain');
    final values = <String, double>{'rin': 10, 'rf': 2000, 'vin': 0.01};
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, '201');
    expect(insights, contains('闭环增益超过 100 倍'));
    expect(insights, contains('反馈网络总阻值超过 1MΩ'));
  });

  test('ADC resolution reports LSB codes and dynamic range', () {
    final definition = tool('adc_resolution');
    final values = <String, double>{'vref': 3.3, 'bits': 12};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['LSBmV'], startsWith('0.80586'));
    expect(valuesByLabelUnit['LSBμV'], startsWith('805.86'));
    expect(valuesByLabelUnit['量化误差mV'], startsWith('0.40293'));
    expect(valuesByLabelUnit['码数'], '4096');
    expect(valuesByLabelUnit['最大码值'], '4095');
    expect(valuesByLabelUnit['动态范围dB'], '74');
    expect(valuesByLabelUnit['满量程V'], '3.3');
    expect(insights, contains('LSB 是理论步进'));
  });

  test('ADC resolution reports input code and ENOB details', () {
    final definition = tool('adc_resolution');
    final values = <String, double>{
      'vref': 3.3,
      'bits': 12,
      'vin': 1.65,
      'enob': 10,
    };
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['输入电压V'], '1.65');
    expect(valuesByLabelUnit['理想码值'], '2048');
    expect(valuesByLabelUnit['码值对应电压V'], startsWith('1.6504'));
    expect(valuesByLabelUnit['输入量化误差mV'], startsWith('0.40293'));
    expect(valuesByLabelUnit['输入状态'], '有效');
    expect(valuesByLabelUnit['ENOBbit'], '10');
    expect(valuesByLabelUnit['ENOB LSBmV'], startsWith('3.2258'));
    expect(valuesByLabelUnit['ENOB动态范围dB'], '61.96');
    expect(insights, contains('ENOB 比标称位数低 2 bit 以上'));
  });

  test('ADC resolution marks input over range', () {
    final definition = tool('adc_resolution');
    final values = <String, double>{'vref': 3.3, 'bits': 12, 'vin': 3.8};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['理想码值'], '4095');
    expect(valuesByLabelUnit['输入状态'], '超量程');
    expect(insights, contains('输入电压超出 0~Vref'));
  });

  test('ADC resolution rejects invalid reference and bit depth', () {
    final definition = tool('adc_resolution');
    final values = <String, double>{'vref': 0, 'bits': 0};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabelUnit['LSBmV'], '无效');
    expect(valuesByLabelUnit['LSBμV'], '无效');
    expect(valuesByLabelUnit['量化误差mV'], '无效');
    expect(valuesByLabelUnit['码数'], '无效');
    expect(valuesByLabelUnit['动态范围dB'], '无效');
    expect(insights, contains('参考电压必须大于 0，位数建议在 1 到 32 bit'));
  });

  test('ADC resolution warns when bit depth exceeds practical ENOB', () {
    final definition = tool('adc_resolution');
    final values = <String, double>{'vref': 2.5, 'bits': 28};
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, isNot('无效'));
    expect(insights, contains('实际 ENOB、噪声和参考源稳定度通常达不到理论值'));
  });

  test('Vrms converter reports sine wave amplitude dB and 50 ohm power', () {
    final definition = tool('rms_peak');
    final values = <String, double>{'vrms': 1};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['VpeakV'], startsWith('1.41421'));
    expect(valuesByLabelUnit['VppV'], startsWith('2.82842'));
    expect(valuesByLabelUnit['VrmsV'], '1');
    expect(valuesByLabelUnit['Vp-p/2V'], startsWith('1.41421'));
    expect(valuesByLabelUnit['峰值系数'], '1.414214');
    expect(valuesByLabelUnit['平均整流值V'], startsWith('0.900316'));
    expect(valuesByLabelUnit['50Ω 功率mW'], '20');
    expect(valuesByLabelUnit['50Ω dBmdBm'], startsWith('13.010'));
    expect(valuesByLabelUnit['dBVdBV'], '0');
    expect(valuesByLabelUnit['dBudBu'], startsWith('2.213'));
    expect(valuesByLabelUnit['输入来源'], 'Vrms');
    expect(insights, contains('只适用于纯正弦波'));
  });

  test('Vrms converter reverse solves from Vpp Vpeak and 50 ohm dBm', () {
    final definition = tool('rms_peak');
    final fromVpp = calculateTool(definition, {'vpp': 2.828427});
    final fromVppByLabel = {
      for (final result in fromVpp) result.label: result.value,
    };
    final fromVpeakReference = calculateTool(definition, {
      'vpeak': math.sqrt2,
      'vpp': 3,
    });
    final fromVpeakReferenceByLabel = {
      for (final result in fromVpeakReference) result.label: result.value,
    };
    final fromDbm = calculateTool(definition, {'dbm50': 13.0103});
    final fromDbmByLabel = {
      for (final result in fromDbm) result.label: result.value,
    };
    final referenceInsights = buildToolInsights(
      definition,
      {'vpeak': math.sqrt2, 'vpp': 3},
      fromVpeakReference,
    ).join('\n');

    expect(fromVppByLabel['Vrms'], startsWith('1'));
    expect(fromVppByLabel['输入来源'], 'Vpp');
    expect(fromVpeakReferenceByLabel['Vrms'], '1');
    expect(fromVpeakReferenceByLabel['输入来源'], 'Vpeak，Vpp作参考');
    expect(fromVpeakReferenceByLabel['Vpp差值'], startsWith('-0.171'));
    expect(referenceInsights, contains('Vpp 参考值与当前计算相差'));
    expect(fromDbmByLabel['Vrms'], startsWith('1'));
    expect(fromDbmByLabel['输入来源'], '50Ω dBm');
  });

  test('Vrms converter keeps zero signal but marks logarithmic values invalid',
      () {
    final definition = tool('rms_peak');
    final values = <String, double>{'vrms': 0};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['VpeakV'], '0');
    expect(valuesByLabelUnit['VppV'], '0');
    expect(valuesByLabelUnit['50Ω 功率mW'], '0');
    expect(valuesByLabelUnit['50Ω dBmdBm'], '无效');
    expect(valuesByLabelUnit['dBVdBV'], '无效');
    expect(valuesByLabelUnit['dBudBu'], '无效');
    expect(insights, contains('0V 信号没有可定义的 dBV、dBu 或 dBm 对数值'));
  });

  test('Vrms converter rejects negative RMS voltage', () {
    final definition = tool('rms_peak');
    final values = <String, double>{'vrms': -1};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['VpeakV'], '无效');
    expect(valuesByLabelUnit['VppV'], '无效');
    expect(valuesByLabelUnit['VrmsV'], '无效');
    expect(valuesByLabelUnit['50Ω 功率mW'], '无效');
    expect(insights, contains('Vrms、Vpeak、Vpp 不能为负'));
  });

  test('555 timer reports period and frequency units', () {
    final definition = tool('timer_555');
    final values = <String, double>{'ra': 10, 'rb': 47, 'c': 0.1};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };

    expect(valuesByLabel['频率Hz'], startsWith('138.75'));
    expect(valuesByLabel['频率kHz'], startsWith('0.13875'));
    expect(valuesByLabel['周期ms'], startsWith('7.207'));
    expect(valuesByLabel['高电平时间ms'], startsWith('3.950'));
    expect(valuesByLabel['低电平时间ms'], startsWith('3.257'));
    expect(valuesByLabel['占空比%'], startsWith('54.807'));
    expect(
      buildToolInsights(definition, values, results).join('\n'),
      contains('电容漏电和阈值误差'),
    );
  });

  test('555 timer backsolves target frequency and duty cycle', () {
    final definition = tool('timer_555');
    final values = <String, double>{
      'ra': 10,
      'rb': 47,
      'c': 0.1,
      'targetFrequency': 1000,
      'targetDuty': 60,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['目标频率Hz'], '1000');
    expect(valuesByLabel['目标周期ms'], '1');
    expect(valuesByLabel['目标占空比%'], '60');
    expect(valuesByLabel['频率偏差Hz'], startsWith('-861.2'));
    expect(valuesByLabel['占空比偏差%'], startsWith('-5.192'));
    expect(valuesByLabel['目标RAkΩ'], startsWith('2.886'));
    expect(valuesByLabel['目标RBkΩ'], startsWith('5.772'));
    expect(valuesByLabel['目标高电平时间ms'], '0.6');
    expect(valuesByLabel['目标低电平时间ms'], '0.4');
    expect(insights, contains('当前频率与目标频率相差'));
    expect(insights, contains('当前占空比与目标占空比相差'));
  });

  test('555 timer rejects non-positive astable inputs', () {
    final definition = tool('timer_555');
    final values = <String, double>{'ra': 10, 'rb': 0, 'c': 0.1};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['频率Hz'], '无效');
    expect(valuesByLabel['周期ms'], '无效');
    expect(valuesByLabel['高电平时间ms'], '无效');
    expect(valuesByLabel['低电平时间ms'], '无效');
    expect(valuesByLabel['占空比%'], '无效');
    expect(insights, contains('RA、RB 和 C 都必须大于 0，才能形成无稳态振荡'));
  });

  test('555 timer rejects unreachable standard astable target duty', () {
    final definition = tool('timer_555');
    final values = <String, double>{
      'ra': 10,
      'rb': 47,
      'c': 0.1,
      'targetFrequency': 1000,
      'targetDuty': 50,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['目标频率Hz'], '无效');
    expect(valuesByLabel['目标占空比%'], '无效');
    expect(valuesByLabel['目标RAkΩ'], '无效');
    expect(valuesByLabel['目标RBkΩ'], '无效');
    expect(insights, contains('目标频率必须大于 0'));
  });

  test('555 timer warns about high duty cycle', () {
    final definition = tool('timer_555');
    final values = <String, double>{'ra': 100, 'rb': 10, 'c': 0.1};
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results);

    expect(insights.join('\n'), contains('占空比较高'));
  });

  test('PCB current reports copper thickness area and current density', () {
    final definition = tool('pcb_current');
    final values = <String, double>{'width': 1, 'copper': 1, 'rise': 10};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['估算电流A'], startsWith('2.391'));
    expect(valuesByLabel['保守 70%A'], startsWith('1.674'));
    expect(valuesByLabel['层位置系数x'], '1');
    expect(valuesByLabel['线宽mil'], startsWith('39.370'));
    expect(valuesByLabel['铜厚μm'], startsWith('35.001'));
    expect(valuesByLabel['截面积mil²'], startsWith('54.251'));
    expect(valuesByLabel['截面积mm²'], startsWith('0.035001'));
    expect(valuesByLabel['电流密度A/mm²'], startsWith('68.329'));
    expect(insights.join('\n'), contains('70% 保守电流'));
    expect(insights.join('\n'), contains('IPC-2221'));
  });

  test('PCB current reverse budgets target trace width and derating', () {
    final definition = tool('pcb_current');
    final values = <String, double>{
      'width': 0.5,
      'copper': 1,
      'rise': 10,
      'targetCurrent': 3,
      'layerFactor': 0.5,
    };
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['估算电流A'], startsWith('0.723'));
    expect(valuesByLabelUnit['保守 70%A'], startsWith('0.506'));
    expect(valuesByLabelUnit['层位置系数x'], '0.5');
    expect(valuesByLabelUnit['目标电流A'], '3');
    expect(valuesByLabelUnit['目标所需线宽mil'], startsWith('140.005'));
    expect(valuesByLabelUnit['目标所需线宽mm'], startsWith('3.556'));
    expect(valuesByLabelUnit['目标所需截面积mil²'], startsWith('192.927'));
    expect(valuesByLabelUnit['目标所需截面积mm²'], startsWith('0.124'));
    expect(valuesByLabelUnit['电流余量A'], startsWith('-2.276'));
    expect(valuesByLabelUnit['70%余量A'], startsWith('-2.493'));
    expect(valuesByLabelUnit['目标利用率%'], startsWith('414.672'));
    expect(insights, contains('线宽至少需要'));
    expect(insights, contains('按 70% 降额后余量为负'));
    expect(insights, contains('层位置系数低于 1'));
  });

  test('PCB current rejects non-positive trace inputs', () {
    final definition = tool('pcb_current');
    final values = <String, double>{
      'width': 0,
      'copper': 1,
      'rise': 10,
      'targetCurrent': -1,
      'layerFactor': 0,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['估算电流A'], '无效');
    expect(valuesByLabel['保守 70%A'], '无效');
    expect(valuesByLabel['层位置系数x'], '无效');
    expect(valuesByLabel['截面积mil²'], '无效');
    expect(valuesByLabel['截面积mm²'], '无效');
    expect(valuesByLabel['目标电流A'], '无效');
    expect(valuesByLabel['目标所需线宽mm'], '无效');
    expect(insights.join('\n'), contains('目标电流也必须大于 0'));
  });

  test('PCB current warns on narrow high rise thick copper extrapolation', () {
    final definition = tool('pcb_current');
    final values = <String, double>{'width': 0.15, 'copper': 3, 'rise': 40};
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, isNot('无效'));
    expect(insights, contains('允许温升超过 30℃'));
    expect(insights, contains('线宽低于 0.2mm'));
    expect(insights, contains('厚铜工艺'));
  });

  test('wire voltage drop reports load voltage loss and current density', () {
    final definition = tool('wire_voltage_drop');
    final values = <String, double>{
      'current': 5,
      'length': 3,
      'area': 1.5,
      'voltage': 12,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['压降'], '0.35');
    expect(valuesByLabel['压降比例'], startsWith('2.916'));
    expect(valuesByLabel['负载端电压'], '11.65');
    expect(valuesByLabel['目标压降'], '3');
    expect(valuesByLabel['目标压降电压'], '0.36');
    expect(valuesByLabel['回路长度'], '6');
    expect(valuesByLabel['有效截面积'], '1.5');
    expect(valuesByLabel['并联根数'], '1');
    expect(valuesByLabel['电阻率'], '0.0175');
    expect(valuesByLabel['线阻'], '0.07');
    expect(valuesByLabel['每米线阻'], '0.011667');
    expect(valuesByLabel['线损'], '1.75');
    expect(valuesByLabel['线损占比'], startsWith('2.916'));
    expect(valuesByLabel['电流密度'], startsWith('3.333'));
    expect(valuesByLabel['目标所需截面积'], startsWith('1.458'));
    expect(valuesByLabel['目标允许电流'], startsWith('5.142'));
    expect(valuesByLabel['电流余量'], startsWith('0.142'));
    expect(valuesByLabel['目标允许单程长度'], startsWith('3.085'));
    expect(insights.join('\n'), contains('线阻按往返回路算'));
  });

  test('wire voltage drop budgets target drop area current and parallel runs',
      () {
    final definition = tool('wire_voltage_drop');
    final values = <String, double>{
      'current': 10,
      'length': 8,
      'area': 1,
      'voltage': 24,
      'dropLimit': 3,
      'resistivity': 0.0282,
      'parallel': 2,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['压降'], '2.256');
    expect(valuesByLabel['压降比例'], '9.4');
    expect(valuesByLabel['负载端电压'], '21.744');
    expect(valuesByLabel['有效截面积'], '2');
    expect(valuesByLabel['目标所需截面积'], startsWith('3.133'));
    expect(valuesByLabel['目标允许电流'], startsWith('3.191'));
    expect(valuesByLabel['电流余量'], startsWith('-6.808'));
    expect(valuesByLabel['目标允许单程长度'], startsWith('2.553'));
    expect(insights, contains('已超过 3% 目标'));
    expect(insights, contains('每根线至少需要'));
    expect(insights, contains('并联导线需确认'));
    expect(insights, contains('电阻率高于常温铜线'));
  });

  test('wire voltage drop rejects invalid conductor inputs', () {
    final definition = tool('wire_voltage_drop');
    final values = <String, double>{
      'current': 5,
      'length': 3,
      'area': 0,
      'voltage': 12,
      'dropLimit': 0,
      'resistivity': 0,
      'parallel': 0,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['压降'], '无效');
    expect(valuesByLabel['压降比例'], '无效');
    expect(valuesByLabel['负载端电压'], '无效');
    expect(valuesByLabel['线阻'], '无效');
    expect(valuesByLabel['线损'], '无效');
    expect(valuesByLabel['目标所需截面积'], '无效');
    expect(insights.join('\n'), contains('目标压降、电阻率和并联根数必须有效'));
  });

  test('wire voltage drop warns when supply cannot survive the cable drop', () {
    final definition = tool('wire_voltage_drop');
    final values = <String, double>{
      'current': 10,
      'length': 10,
      'area': 0.5,
      'voltage': 3.3,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['压降'], '7');
    expect(valuesByLabel['负载端电压'], '-3.7');
    expect(insights, contains('压降超过 5%'));
    expect(insights, contains('负载端电压已经不高于 0'));
  });

  test('capacitor charge reports voltage current charge and energy', () {
    final definition = tool('capacitor_charge');
    final values = <String, double>{'vin': 5, 'r': 10, 'c': 100, 'time': 1};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['电容电压V'], startsWith('3.1606'));
    expect(valuesByLabelUnit['充电比例%'], startsWith('63.212'));
    expect(valuesByLabelUnit['放电电压V'], startsWith('1.83939'));
    expect(valuesByLabelUnit['理想充电电压V'], startsWith('3.1606'));
    expect(valuesByLabelUnit['剩余压差V'], startsWith('1.83939'));
    expect(valuesByLabelUnit['初始电压V'], '0');
    expect(valuesByLabelUnit['时间常数 τs'], '1');
    expect(valuesByLabelUnit['半充时间s'], startsWith('0.693147'));
    expect(valuesByLabelUnit['90% 时间s'], startsWith('2.30258'));
    expect(valuesByLabelUnit['约 99% 时间s'], '5');
    expect(valuesByLabelUnit['初始电流mA'], '0.5');
    expect(valuesByLabelUnit['当前电流mA'], startsWith('0.18394'));
    expect(valuesByLabelUnit['电荷mC'], startsWith('0.31606'));
    expect(valuesByLabelUnit['储能mJ'], startsWith('0.49947'));
    expect(insights, contains('当前还没到 90% 充电点'));
  });

  test('capacitor charge handles initial voltage and target thresholds', () {
    final definition = tool('capacitor_charge');
    final values = <String, double>{
      'vin': 5,
      'initialVoltage': 1,
      'r': 10,
      'c': 100,
      'time': 1,
      'targetVoltage': 4,
      'targetRatio': 75,
    };
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };

    expect(valuesByLabelUnit['电容电压V'], startsWith('3.52848'));
    expect(valuesByLabelUnit['充电比例%'], startsWith('63.212'));
    expect(valuesByLabelUnit['初始电压V'], '1');
    expect(valuesByLabelUnit['目标电压V'], '4');
    expect(valuesByLabelUnit['目标电压时间s'], startsWith('1.38629'));
    expect(valuesByLabelUnit['目标电压差V'], startsWith('-0.47151'));
    expect(valuesByLabelUnit['目标充电比例%'], '75');
    expect(valuesByLabelUnit['目标比例电压V'], '4');
    expect(valuesByLabelUnit['目标比例时间s'], startsWith('1.38629'));
  });

  test('capacitor charge rejects invalid RC inputs', () {
    final definition = tool('capacitor_charge');
    final values = <String, double>{'vin': 5, 'r': 0, 'c': 100, 'time': 1};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabelUnit['电容电压V'], '无效');
    expect(valuesByLabelUnit['充电比例%'], '无效');
    expect(valuesByLabelUnit['放电电压V'], '无效');
    expect(valuesByLabelUnit['理想充电电压V'], '无效');
    expect(valuesByLabelUnit['初始电流mA'], '无效');
    expect(valuesByLabelUnit['储能mJ'], '无效');
    expect(insights, contains('R 和 C 必须大于 0，时间不能为负，目标充电比例需在 0% 到 100%'));
  });

  test('capacitor charge warns about large initial inrush current', () {
    final definition = tool('capacitor_charge');
    final values = <String, double>{'vin': 5, 'r': 0.01, 'c': 100, 'time': 0.1};
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, isNot('无效'));
    expect(insights, contains('初始电流超过 100mA'));
  });

  test('battery life reports equivalent Wh and load power', () {
    final definition = tool('battery_life');
    final values = <String, double>{
      'capacity': 3000,
      'current': 250,
      'voltage': 3.7,
      'efficiency': 90,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['续航时间'], '10.8');
    expect(valuesByLabel['留 20% 余量'], '8.64');
    expect(valuesByLabel['余量后续航'], '8.64');
    expect(valuesByLabel['保留余量'], '20');
    expect(valuesByLabel['可用容量'], '2700');
    expect(valuesByLabel['余量后容量'], '2160');
    expect(valuesByLabel['标称能量'], '11.1');
    expect(valuesByLabel['负载功率'], '0.925');
    expect(valuesByLabel['可用能量'], '9.99');
    expect(valuesByLabel['余量后能量'], '7.992');
    expect(valuesByLabel['等效电池电流'], startsWith('277.777'));
    expect(valuesByLabel['等效电池功率'], startsWith('1.027'));
    expect(valuesByLabel['C倍率'], startsWith('0.0925'));
    expect(valuesByLabel['每小时消耗'], startsWith('9.259'));
    expect(insights, contains('扣除 20% 余量后'));
    expect(insights, contains('容量会随温度'));
  });

  test('battery life reverse budgets target runtime capacity and current', () {
    final definition = tool('battery_life');
    final values = <String, double>{
      'capacity': 3000,
      'current': 250,
      'voltage': 3.7,
      'efficiency': 90,
      'targetHours': 24,
      'reserve': 25,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['余量后续航'], '8.1');
    expect(valuesByLabel['保留余量'], '25');
    expect(valuesByLabel['余量后容量'], '2025');
    expect(valuesByLabel['余量后能量'], startsWith('7.492'));
    expect(valuesByLabel['目标所需容量'], startsWith('8888.888'));
    expect(valuesByLabel['目标所需能量'], startsWith('32.888'));
    expect(valuesByLabel['目标允许电流'], '84.375');
    expect(valuesByLabel['目标负载能量'], '22.2');
    expect(insights, contains('目标续航需要'));
    expect(insights, contains('平均电流需控制在 84.375mA 以内'));
  });

  test('battery life rejects invalid load and efficiency values', () {
    final definition = tool('battery_life');
    final values = <String, double>{
      'capacity': 3000,
      'current': 0,
      'voltage': 3.7,
      'efficiency': 120,
      'targetHours': -1,
      'reserve': 100,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['续航时间'], '无效');
    expect(valuesByLabel['可用容量'], '无效');
    expect(valuesByLabel['负载功率'], '无效');
    expect(valuesByLabel['等效电池电流'], '无效');
    expect(valuesByLabel['C倍率'], '无效');
    expect(valuesByLabel['目标所需容量'], '无效');
    expect(insights.join('\n'), contains('保留余量需小于 100%'));
  });

  test('battery life warns about high discharge rate and short runtime', () {
    final definition = tool('battery_life');
    final values = <String, double>{
      'capacity': 1000,
      'current': 2500,
      'voltage': 3.7,
      'efficiency': 70,
    };
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, '0.28');
    expect(insights, contains('等效放电倍率超过 1C'));
    expect(insights, contains('估算续航低于 1 小时'));
    expect(insights, contains('效率低于 75%'));
  });

  test('LDO power reports junction temperature and clamps dropout loss', () {
    final definition = tool('ldo_power');
    final results = calculateTool(definition, {
      'vin': 5,
      'vout': 3.3,
      'current': 500,
      'theta': 60,
      'ambient': 40,
      'maxJunction': 125,
    });
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['功耗'], '0.85');
    expect(valuesByLabel['效率'], '66');
    expect(valuesByLabel['输入功率'], '2.5');
    expect(valuesByLabel['输出功率'], '1.65');
    expect(valuesByLabel['负载损耗'], '0.85');
    expect(valuesByLabel['静态损耗'], '0');
    expect(valuesByLabel['最小压差'], '0');
    expect(valuesByLabel['压差余量'], '1.7');
    expect(valuesByLabel['静态电流'], '0');
    expect(valuesByLabel['总输入电流'], '500');
    expect(valuesByLabel['温升'], '51');
    expect(valuesByLabel['结温估算'], '91');
    expect(valuesByLabel['热余量'], '34');
    expect(valuesByLabel['最大环境温度'], '74');
    expect(valuesByLabel['热阻上限'], '100');
    expect(valuesByLabel['热限电流'], startsWith('833.333'));
    expect(valuesByLabel['调节状态'], '可调节');

    final invalidDropout = {
      for (final result in calculateTool(definition, {
        'vin': 3.3,
        'vout': 5,
        'current': 500,
        'theta': 60,
        'ambient': 40,
        'maxJunction': 125,
      }))
        result.label: result.value,
    };

    expect(invalidDropout['功耗'], '0');
    expect(invalidDropout['效率'], '无效');
    expect(invalidDropout['压差'], '-1.7');
    expect(invalidDropout['调节状态'], '压差不足');
    expect(invalidDropout['结温估算'], '40');
  });

  test('LDO power includes quiescent current and dropout margin', () {
    final definition = tool('ldo_power');
    final values = <String, double>{
      'vin': 4,
      'vout': 3.3,
      'current': 10,
      'iq': 2,
      'dropout': 0.65,
      'theta': 100,
      'ambient': 25,
      'maxJunction': 85,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['功耗'], '0.015');
    expect(valuesByLabel['效率'], '68.75');
    expect(valuesByLabel['负载损耗'], '0.007');
    expect(valuesByLabel['静态损耗'], '0.008');
    expect(valuesByLabel['最小压差'], '0.65');
    expect(valuesByLabel['压差余量'], '0.05');
    expect(valuesByLabel['静态电流'], '2');
    expect(valuesByLabel['总输入电流'], '12');
    expect(valuesByLabel['调节状态'], '可调节');
    expect(valuesByLabel['热限电流'], startsWith('845.714'));
    expect(insights, contains('压差余量低于 0.1V'));
    expect(insights, contains('静态电流超过负载电流 10%'));
  });

  test('LDO power rejects invalid thermal and electrical inputs', () {
    final definition = tool('ldo_power');
    final values = <String, double>{
      'vin': 0,
      'vout': 3.3,
      'current': 500,
      'theta': 0,
      'ambient': 40,
      'maxJunction': 125,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['功耗'], '无效');
    expect(valuesByLabel['效率'], '无效');
    expect(valuesByLabel['结温估算'], '无效');
    expect(valuesByLabel['热限电流'], '无效');
    expect(
      insights,
      contains('Vin 必须大于 0，Vout 不能为负，负载电流、Iq 和 dropout 不能为负，θJA 必须大于 0'),
    );
  });

  test('LDO power warns when thermal margin is tight', () {
    final definition = tool('ldo_power');
    final values = <String, double>{
      'vin': 12,
      'vout': 3.3,
      'current': 1000,
      'theta': 10,
      'ambient': 35,
      'maxJunction': 125,
    };
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, '8.7');
    expect(insights, contains('热余量低于 15℃'));
    expect(insights, contains('效率低于 60%'));
  });

  test('thermal rise reports thermal margin', () {
    final definition = tool('thermal_rise');
    final values = <String, double>{
      'power': 1.5,
      'theta': 60,
      'ambient': 40,
      'maxJunction': 125,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['结温估算'], '130');
    expect(valuesByLabel['温升'], '90');
    expect(valuesByLabel['环境温度'], '40');
    expect(valuesByLabel['最高结温'], '125');
    expect(valuesByLabel['热余量'], '-5');
    expect(valuesByLabel['热余量比例'], startsWith('-5.882'));
    expect(valuesByLabel['允许温升'], '85');
    expect(valuesByLabel['允许功耗'], startsWith('1.416'));
    expect(valuesByLabel['降额比例'], '70');
    expect(valuesByLabel['降额功耗'], startsWith('0.991'));
    expect(valuesByLabel['70% 降额功耗'], startsWith('0.991'));
    expect(valuesByLabel['功耗利用率'], startsWith('105.882'));
    expect(valuesByLabel['降额利用率'], startsWith('151.260'));
    expect(valuesByLabel['最大环境温度'], '35');
    expect(valuesByLabel['热阻上限'], startsWith('56.666'));
    expect(insights, contains('热余量为负'));
    expect(insights, contains('当前功耗超过 70% 降额功耗'));
  });

  test('thermal rise budgets derating target junction and target margin', () {
    final definition = tool('thermal_rise');
    final values = <String, double>{
      'power': 1.2,
      'theta': 45,
      'ambient': 35,
      'maxJunction': 125,
      'derating': 60,
      'targetJunction': 105,
      'targetMargin': 25,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['结温估算'], '89');
    expect(valuesByLabel['降额功耗'], '1.2');
    expect(valuesByLabel['功耗利用率'], '60');
    expect(valuesByLabel['降额利用率'], '100');
    expect(valuesByLabel['最大环境温度'], '71');
    expect(valuesByLabel['目标结温'], '105');
    expect(valuesByLabel['目标结温允许功耗'], startsWith('1.555'));
    expect(valuesByLabel['目标结温热阻上限'], startsWith('58.333'));
    expect(valuesByLabel['目标热余量'], '25');
    expect(valuesByLabel['目标余量允许功耗'], startsWith('1.444'));
    expect(valuesByLabel['目标余量热阻上限'], startsWith('54.166'));
    expect(insights, isNot(contains('当前功耗超过 60% 降额功耗')));
  });

  test('thermal rise rejects invalid thermal budget inputs', () {
    final definition = tool('thermal_rise');
    final values = <String, double>{
      'power': -1,
      'theta': 0,
      'ambient': 125,
      'maxJunction': 125,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['结温估算'], '无效');
    expect(valuesByLabel['温升'], '无效');
    expect(valuesByLabel['允许功耗'], '无效');
    expect(valuesByLabel['热阻上限'], '无效');
    expect(
      insights,
      contains('功耗不能为负，热阻和降额比例必须大于 0，最高结温必须高于环境温度，目标结温需落在环境温度和最高结温之间'),
    );
  });

  test('thermal rise warns when margin is tight before overtemperature', () {
    final definition = tool('thermal_rise');
    final values = <String, double>{
      'power': 1.9,
      'theta': 50,
      'ambient': 25,
      'maxJunction': 125,
    };
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, '120');
    expect(insights, contains('热余量低于 10℃'));
    expect(insights, contains('热余量比例低于 20%'));
  });

  test('gear ratio reports speed torque power and loss', () {
    final definition = tool('gear_ratio');
    final values = <String, double>{
      'z1': 20,
      'z2': 50,
      'rpm': 1500,
      'torque': 20,
      'efficiency': 95,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['传动比 i'], '2.5');
    expect(valuesByLabel['输出转速'], '600');
    expect(valuesByLabel['输出扭矩'], '47.5');
    expect(valuesByLabel['输入功率'], startsWith('3.141'));
    expect(valuesByLabel['输出功率'], startsWith('2.984'));
    expect(valuesByLabel['损耗功率'], startsWith('0.157'));
    expect(valuesByLabel['输入角速度'], startsWith('157.079'));
    expect(valuesByLabel['输出角速度'], startsWith('62.831'));
    expect(valuesByLabel['速度比 n1/n2'], '2.5');
    expect(valuesByLabel['旋转方向'], '相反');
    expect(insights, contains('扭矩已乘效率'));
  });

  test('gear ratio backsolves target output speed and tooth counts', () {
    final definition = tool('gear_ratio');
    final values = <String, double>{
      'z1': 20,
      'z2': 50,
      'rpm': 1500,
      'torque': 20,
      'efficiency': 95,
      'targetOutputRpm': 500,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['目标输出转速'], '500');
    expect(valuesByLabel['目标传动比'], '3');
    expect(valuesByLabel['保留Z1所需Z2'], '60');
    expect(valuesByLabel['保留Z2所需Z1'], startsWith('16.666'));
    expect(valuesByLabel['目标输出扭矩'], '57');
    expect(insights, contains('驱动齿数不是整数'));
  });

  test('gear ratio rejects invalid teeth and efficiency', () {
    final definition = tool('gear_ratio');
    final values = <String, double>{
      'z1': 0,
      'z2': 50,
      'rpm': 1500,
      'torque': 20,
      'efficiency': 120,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['传动比 i'], '无效');
    expect(valuesByLabel['输出转速'], '无效');
    expect(valuesByLabel['输出功率'], '无效');
    expect(valuesByLabel['旋转方向'], '无效');
    expect(insights, contains('驱动齿数和从动齿数必须大于 0，效率需在 0% 到 100%'));
  });

  test('gear ratio warns about extreme ratio and high output speed', () {
    final definition = tool('gear_ratio');
    final values = <String, double>{
      'z1': 100,
      'z2': 10,
      'rpm': 1500,
      'torque': 5,
      'efficiency': 70,
    };
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, '0.1');
    expect(insights, contains('高速增速比很大'));
    expect(insights, contains('输出转速超过 10000rpm'));
    expect(insights, contains('效率低于 80%'));
  });

  test('torque power reports watts horsepower speed and torque per kW', () {
    final definition = tool('torque_power');
    final values = <String, double>{'torque': 10, 'rpm': 3000};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['功率'], startsWith('3.141'));
    expect(valuesByLabel['瓦特'], startsWith('3141.361'));
    expect(valuesByLabel['机械马力'], startsWith('4.212'));
    expect(valuesByLabel['公制马力'], startsWith('4.271'));
    expect(valuesByLabel['角速度'], startsWith('314.159'));
    expect(valuesByLabel['转速'], '50');
    expect(valuesByLabel['功率方向'], '驱动');
    expect(valuesByLabel['1kW所需扭矩'], startsWith('3.183'));
    expect(insights, contains('公式只给轴功率'));
  });

  test('torque power backsolves target power torque and speed', () {
    final definition = tool('torque_power');
    final values = <String, double>{
      'torque': 10,
      'rpm': 3000,
      'targetPower': 5,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['目标功率'], '5');
    expect(valuesByLabel['目标功率所需扭矩'], startsWith('15.916'));
    expect(valuesByLabel['目标功率所需转速'], '4775');
    expect(insights, contains('目标功率反推只按轴功率计算'));
  });

  test('torque power handles zero speed without reverse torque estimate', () {
    final definition = tool('torque_power');
    final values = <String, double>{'torque': 10, 'rpm': 0};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['功率'], '0');
    expect(valuesByLabel['角速度'], '0');
    expect(valuesByLabel['功率方向'], '无输出功');
    expect(valuesByLabel['1kW所需扭矩'], '无效');
    expect(insights, contains('转速为 0 时机械输出功率为 0'));
  });

  test('torque power warns about regenerative high speed operation', () {
    final definition = tool('torque_power');
    final values = <String, double>{'torque': -20, 'rpm': 12000};
    final results = calculateTool(definition, values);
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(results.first.value, startsWith('-25.130'));
    expect(insights, contains('功率为负表示扭矩和转速方向相反'));
    expect(insights, contains('转速超过 10000rpm'));
  });

  test('spring tool reports force energy compliance and deformation direction',
      () {
    final definition = tool('spring');
    final values = <String, double>{'k': 12, 'x': 8};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['弹簧力'], '96');
    expect(valuesByLabel['弹簧力幅值'], '96');
    expect(valuesByLabel['储能'], '0.384');
    expect(valuesByLabel['刚度'], '12000');
    expect(valuesByLabel['柔度'], startsWith('0.083333'));
    expect(valuesByLabel['等效重量'], startsWith('9.789'));
    expect(valuesByLabel['变形方向'], '压缩');
    expect(insights, contains('按线性弹簧估算'));
  });

  test('spring tool backsolves target force and stored energy travel', () {
    final definition = tool('spring');
    final values = <String, double>{
      'k': 12,
      'x': 8,
      'targetForce': -60,
      'targetEnergy': 0.384,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['目标弹簧力'], '-60');
    expect(valuesByLabel['目标力所需变形'], '-5');
    expect(valuesByLabel['目标储能'], '0.384');
    expect(valuesByLabel['目标储能所需变形'], '8');
    expect(insights, contains('目标弹簧力为负'));
    expect(insights, contains('目标储能反推得到的是变形幅值'));
  });

  test('spring tool handles reverse displacement and rejects invalid stiffness',
      () {
    final definition = tool('spring');
    final reverseValues = <String, double>{'k': 10, 'x': -5};
    final reverseResults = calculateTool(definition, reverseValues);
    final reverseByLabel = {
      for (final result in reverseResults) result.label: result.value,
    };
    final reverseInsights =
        buildToolInsights(definition, reverseValues, reverseResults).join('\n');

    expect(reverseByLabel['弹簧力'], '-50');
    expect(reverseByLabel['弹簧力幅值'], '50');
    expect(reverseByLabel['储能'], '0.125');
    expect(reverseByLabel['变形方向'], '拉伸/反向');
    expect(reverseInsights, contains('变形量为负表示按相反方向取参考'));

    final invalidResults = calculateTool(definition, {'k': 0, 'x': 8});
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, {'k': 0, 'x': 8}, invalidResults);

    expect(invalidByLabel['弹簧力'], '无效');
    expect(invalidByLabel['储能'], '无效');
    expect(invalidByLabel['变形方向'], '无效');
    expect(invalidInsights, contains('弹簧刚度必须大于 0，变形量必须是有限数值'));
  });

  test('cylinder tool reports extend retract force areas and ratio', () {
    final definition = tool('cylinder');
    final values = <String, double>{'pressure': 0.6, 'bore': 32, 'rod': 12};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['推出力'], startsWith('482.548'));
    expect(valuesByLabel['拉回力'], startsWith('414.690'));
    expect(valuesByLabel['推出等效重量'], startsWith('49.206'));
    expect(valuesByLabel['拉回等效重量'], startsWith('42.286'));
    expect(valuesByLabel['活塞面积'], startsWith('804.247'));
    expect(valuesByLabel['杆侧有效面积'], startsWith('691.150'));
    expect(valuesByLabel['杆截面积'], startsWith('113.097'));
    expect(valuesByLabel['拉力比例'], '85.9375');
    expect(insights, contains('有效力还要扣掉密封摩擦'));

    final targetValues = <String, double>{
      'pressure': 0.6,
      'bore': 32,
      'rod': 12,
      'targetForce': 600,
    };
    final targetResults = calculateTool(definition, targetValues);
    final targetByLabel = {
      for (final result in targetResults) result.label: result.value,
    };
    final targetInsights =
        buildToolInsights(definition, targetValues, targetResults).join('\n');

    expect(targetByLabel['目标推出力'], '600');
    expect(targetByLabel['目标力所需气压'], startsWith('0.746'));
    expect(targetByLabel['目标力所需缸径'], startsWith('35.682'));
    expect(targetByLabel['推出力余量'], startsWith('-117.451'));
    expect(targetInsights, contains('当前缸径和气压达不到目标推出力'));
  });

  test('cylinder tool rejects impossible rod and warns on low retract ratio',
      () {
    final definition = tool('cylinder');
    final invalidValues = <String, double>{
      'pressure': 0.6,
      'bore': 32,
      'rod': 32
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['推出力'], '无效');
    expect(invalidByLabel['拉回力'], '无效');
    expect(invalidByLabel['拉力比例'], '无效');
    expect(invalidInsights, contains('气压不能为负，缸径必须大于 0，杆径需小于缸径'));

    final lowRatioValues = <String, double>{
      'pressure': 1.2,
      'bore': 32,
      'rod': 20,
    };
    final lowRatioResults = calculateTool(definition, lowRatioValues);
    final lowRatioInsights =
        buildToolInsights(definition, lowRatioValues, lowRatioResults)
            .join('\n');

    expect(lowRatioResults.first.value, startsWith('965.097'));
    expect(lowRatioInsights, contains('气压超过 1MPa'));
    expect(lowRatioInsights, contains('杆径占比偏大'));
  });

  test('force tool reports magnitude weight g and direction', () {
    final definition = tool('force');
    final values = <String, double>{'mass': 5, 'acc': -9.80665};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['力'], '-49.03325');
    expect(valuesByLabel['力幅值'], '49.03325');
    expect(valuesByLabel['等效重量'], '5');
    expect(valuesByLabel['加速度'], '-1');
    expect(valuesByLabel['质量重量'], '49.03325');
    expect(valuesByLabel['运动方向'], '反向加速');
    expect(insights, contains('加速度为负表示参考方向相反'));

    final targetValues = <String, double>{
      'mass': 5,
      'acc': 10,
      'targetForce': 100,
    };
    final targetResults = calculateTool(definition, targetValues);
    final targetByLabel = {
      for (final result in targetResults) result.label: result.value,
    };
    final targetInsights =
        buildToolInsights(definition, targetValues, targetResults).join('\n');

    expect(targetByLabel['力'], '50');
    expect(targetByLabel['目标力'], '100');
    expect(targetByLabel['目标力所需加速度'], '20');
    expect(targetByLabel['目标力所需质量'], '10');
    expect(targetInsights, contains('目标力反推只按 F=ma 计算'));
  });

  test('force tool rejects negative mass', () {
    final definition = tool('force');
    final values = <String, double>{'mass': -1, 'acc': 9.8};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results);

    expect(valuesByLabel['力'], '无效');
    expect(valuesByLabel['运动方向'], '无效');
    expect(insights, contains('质量不能为负，质量和加速度必须是有限数值'));
  });

  test('pulley ratio reports output speed angle speed and belt speed', () {
    final definition = tool('pulley_ratio');
    final values = <String, double>{'d1': 40, 'd2': 80, 'rpm': 1500};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['输出转速'], '750');
    expect(valuesByLabel['速度比 n2/n1'], '0.5');
    expect(valuesByLabel['传动比 i'], '2');
    expect(valuesByLabel['输出角速度'], startsWith('78.539'));
    expect(valuesByLabel['皮带线速度'], startsWith('3.141'));
    expect(valuesByLabel['转向'], '开口皮带同向');
    expect(insights, contains('按无打滑开口皮带估算'));

    final targetValues = <String, double>{
      'd1': 40,
      'd2': 80,
      'rpm': 1500,
      'targetOutputRpm': 1000,
    };
    final targetResults = calculateTool(definition, targetValues);
    final targetByLabel = {
      for (final result in targetResults) result.label: result.value,
    };
    final targetInsights =
        buildToolInsights(definition, targetValues, targetResults).join('\n');

    expect(targetByLabel['目标输出转速'], '1000');
    expect(targetByLabel['目标速度比'], startsWith('0.666'));
    expect(targetByLabel['保留主动轮所需从动轮直径'], '60');
    expect(targetByLabel['保留从动轮所需主动轮直径'], startsWith('53.333'));
    expect(targetInsights, contains('目标输出转速反推按无打滑几何关系计算'));
  });

  test('pulley ratio rejects invalid diameters and warns on high belt speed',
      () {
    final definition = tool('pulley_ratio');
    final invalidValues = <String, double>{'d1': 0, 'd2': 80, 'rpm': 1500};
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['输出转速'], '无效');
    expect(invalidByLabel['皮带线速度'], '无效');
    expect(invalidInsights, contains('主动轮和从动轮直径必须大于 0，输入转速必须是有限数值'));

    final highSpeedValues = <String, double>{
      'd1': 300,
      'd2': 30,
      'rpm': 3000,
    };
    final highSpeedResults = calculateTool(definition, highSpeedValues);
    final highSpeedInsights =
        buildToolInsights(definition, highSpeedValues, highSpeedResults)
            .join('\n');

    expect(highSpeedResults.first.value, '30000');
    expect(highSpeedInsights, contains('皮带轮直径比超过 5:1'));
    expect(highSpeedInsights, contains('皮带线速度超过 30m/s'));
  });

  test('screw lead reports feed speed rotations and travel direction', () {
    final definition = tool('screw_lead');
    final values = <String, double>{'lead': 5, 'rpm': -600};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['线速度'], '-3000');
    expect(valuesByLabel['每秒位移'], '-50');
    expect(valuesByLabel['每转位移'], '5');
    expect(valuesByLabel['每毫米转数'], '0.2');
    expect(valuesByLabel['转速'], '-10');
    expect(valuesByLabel['小时行程'], '-180');
    expect(valuesByLabel['运动方向'], '反向');
    expect(insights, contains('转速为负表示反向进给'));

    final targetValues = <String, double>{
      'lead': 5,
      'rpm': 600,
      'targetSpeed': 4500,
    };
    final targetResults = calculateTool(definition, targetValues);
    final targetByLabel = {
      for (final result in targetResults) result.label: result.value,
    };
    final targetInsights =
        buildToolInsights(definition, targetValues, targetResults).join('\n');

    expect(targetByLabel['目标线速度'], '4500');
    expect(targetByLabel['目标线速度所需转速'], '900');
    expect(targetByLabel['目标线速度所需导程'], '7.5');
    expect(targetInsights, contains('目标线速度反推只按导程几何换算'));
  });

  test('screw lead rejects invalid lead and warns on very high feed', () {
    final definition = tool('screw_lead');
    final invalidValues = <String, double>{'lead': 0, 'rpm': 600};
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['线速度'], '无效');
    expect(invalidByLabel['每毫米转数'], '无效');
    expect(invalidInsights, contains('导程必须大于 0，转速必须是有限数值'));

    final highFeedValues = <String, double>{'lead': 20, 'rpm': 2000};
    final highFeedResults = calculateTool(definition, highFeedValues);
    final highFeedInsights =
        buildToolInsights(definition, highFeedValues, highFeedResults)
            .join('\n');

    expect(highFeedResults.first.value, '40000');
    expect(highFeedInsights, contains('线速度超过 500mm/s'));
  });

  test('pressure force reports kN bar area and surface load', () {
    final definition = tool('pressure_force');
    final values = <String, double>{'pressure': 0.6, 'area': 10};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['作用力N'], '600');
    expect(valuesByLabelUnit['作用力kN'], '0.6');
    expect(valuesByLabelUnit['等效重量kgf'], startsWith('61.182'));
    expect(valuesByLabelUnit['压力bar'], '6');
    expect(valuesByLabelUnit['面积mm²'], '1000');
    expect(valuesByLabelUnit['面积m²'], '0.001');
    expect(valuesByLabelUnit['单位面积载荷N/cm²'], '60');
    expect(insights, contains('压力面积力按均布压力估算'));

    final targetResults = calculateTool(definition, {
      'pressure': 0.6,
      'area': 10,
      'targetForce': 900,
    });
    final targetByLabel = {
      for (final result in targetResults) result.label: result.value,
    };
    final targetInsights = buildToolInsights(
      definition,
      {'pressure': 0.6, 'area': 10, 'targetForce': 900},
      targetResults,
    ).join('\n');

    expect(targetByLabel['目标作用力'], '900');
    expect(targetByLabel['目标力所需压力'], '0.9');
    expect(targetByLabel['目标力所需面积'], '15');
    expect(targetByLabel['作用力差值'], '-300');
    expect(targetInsights, contains('目标作用力与当前作用力相差 -300N'));
  });

  test('pressure force rejects invalid area and warns on high force', () {
    final definition = tool('pressure_force');
    final invalidValues = <String, double>{'pressure': 0.6, 'area': 0};
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults)
        '${result.label}${result.unit}': result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['作用力N'], '无效');
    expect(invalidByLabel['面积mm²'], '无效');
    expect(invalidInsights, contains('压力不能为负，受压面积必须大于 0'));

    final highForceValues = <String, double>{'pressure': 25, 'area': 100};
    final highForceResults = calculateTool(definition, highForceValues);
    final highForceInsights =
        buildToolInsights(definition, highForceValues, highForceResults)
            .join('\n');

    expect(highForceResults.first.value, '250000');
    expect(highForceInsights, contains('压力超过 20MPa'));
    expect(highForceInsights, contains('作用力超过 100kN'));
  });

  test('friction tool reports friction angle and equivalent grade', () {
    final definition = tool('friction');
    final values = <String, double>{'normal': 100, 'mu': 0.3};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['摩擦力'], '30');
    expect(valuesByLabel['摩擦系数'], '0.3');
    expect(valuesByLabel['法向等效重量'], startsWith('10.197'));
    expect(valuesByLabel['摩擦角'], startsWith('16.699'));
    expect(valuesByLabel['最大可平衡坡角'], startsWith('16.699'));
    expect(valuesByLabel['等效坡度'], '30');
    expect(insights, contains('静摩擦上限和动摩擦系数可能不同'));
  });

  test('friction tool rejects invalid inputs and warns on high coefficient',
      () {
    final definition = tool('friction');
    final invalidValues = <String, double>{'normal': 100, 'mu': -0.1};
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['摩擦力'], '无效');
    expect(invalidByLabel['摩擦角'], '无效');
    expect(invalidInsights, contains('正压力和摩擦系数不能为负'));

    final highMuValues = <String, double>{'normal': 0, 'mu': 1.2};
    final highMuResults = calculateTool(definition, highMuValues);
    final highMuInsights =
        buildToolInsights(definition, highMuValues, highMuResults).join('\n');

    expect(highMuResults.first.value, '0');
    expect(highMuInsights, contains('摩擦系数大于 1'));
    expect(highMuInsights, contains('正压力为 0 时不会产生库仑摩擦力'));
  });

  test('inclined plane reports slope friction angle and sliding state', () {
    final definition = tool('inclined_plane');
    final values = <String, double>{'mass': 10, 'angle': 30, 'mu': 0.2};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['沿斜面分力'], startsWith('49.033'));
    expect(valuesByLabel['法向力'], startsWith('84.928'));
    expect(valuesByLabel['摩擦力'], startsWith('16.985'));
    expect(valuesByLabel['净下滑力'], startsWith('32.047'));
    expect(valuesByLabel['重力'], '98.0665');
    expect(valuesByLabel['坡度'], startsWith('57.735'));
    expect(valuesByLabel['摩擦角'], startsWith('11.309'));
    expect(valuesByLabel['滑动状态'], '会下滑');
    expect(insights, contains('沿斜面分力超过摩擦上限'));
  });

  test('inclined plane rejects invalid angle and reports friction margin', () {
    final definition = tool('inclined_plane');
    final invalidValues = <String, double>{'mass': 10, 'angle': 120, 'mu': 0.2};
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['沿斜面分力'], '无效');
    expect(invalidByLabel['滑动状态'], '无效');
    expect(invalidInsights, contains('质量不能为负，摩擦系数不能为负，角度需在 -90° 到 90°'));

    final stableValues = <String, double>{'mass': 10, 'angle': 10, 'mu': 0.5};
    final stableResults = calculateTool(definition, stableValues);
    final stableByLabel = {
      for (final result in stableResults) result.label: result.value,
    };
    final stableInsights =
        buildToolInsights(definition, stableValues, stableResults).join('\n');

    expect(stableByLabel['滑动状态'], '摩擦可抵住');
    expect(stableInsights, contains('摩擦余量约'));
  });

  test('beam bending reports reactions stiffness ratio and EI', () {
    final definition = tool('beam_bending');
    final values = <String, double>{
      'load': 100,
      'length': 1,
      'elastic': 200,
      'inertia': 8,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['最大挠度'], startsWith('0.130208'));
    expect(valuesByLabel['挠度幅值'], startsWith('0.130208'));
    expect(valuesByLabel['最大弯矩'], '25');
    expect(valuesByLabel['支座反力'], '50');
    expect(valuesByLabel['刚度 F/δ'], startsWith('768000'));
    expect(valuesByLabel['跨度/挠度'], startsWith('7680'));
    expect(valuesByLabel['弯曲刚度 EI'], '16000');
    expect(valuesByLabel['载荷方向'], '向下');
    expect(insights, contains('按简支梁中央集中载荷计算'));

    final targetResults = calculateTool(definition, {
      'load': 100,
      'length': 1,
      'elastic': 200,
      'inertia': 8,
      'targetDeflection': 0.2,
    });
    final targetByLabel = {
      for (final result in targetResults) result.label: result.value,
    };
    final targetInsights = buildToolInsights(
      definition,
      {
        'load': 100,
        'length': 1,
        'elastic': 200,
        'inertia': 8,
        'targetDeflection': 0.2,
      },
      targetResults,
    ).join('\n');

    expect(targetByLabel['目标挠度'], '0.2');
    expect(targetByLabel['目标挠度允许载荷'], startsWith('153.6'));
    expect(targetByLabel['目标挠度所需惯性矩'], startsWith('5.208'));
    expect(targetByLabel['目标挠度所需弹性模量'], startsWith('130.208'));
    expect(targetByLabel['挠度差值'], startsWith('-0.069'));
    expect(targetInsights, contains('目标挠度与当前挠度幅值相差'));
  });

  test('beam bending rejects invalid section inputs and warns on soft beams',
      () {
    final definition = tool('beam_bending');
    final invalidValues = <String, double>{
      'load': 100,
      'length': 0,
      'elastic': 200,
      'inertia': 8,
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['最大挠度'], '无效');
    expect(invalidByLabel['弯曲刚度 EI'], '无效');
    expect(invalidInsights, contains('跨度、弹性模量和惯性矩必须大于 0，载荷必须是有限数值'));

    final softValues = <String, double>{
      'load': 1000,
      'length': 4,
      'elastic': 70,
      'inertia': 0.1,
    };
    final softResults = calculateTool(definition, softValues);
    final softInsights =
        buildToolInsights(definition, softValues, softResults).join('\n');

    expect(softResults.first.value, startsWith('19047.619'));
    expect(softInsights, contains('跨度/挠度低于 250'));
  });

  test('stress strain reports stress magnitude strain and load type', () {
    final definition = tool('stress_strain');
    final values = <String, double>{'force': -1000, 'area': 50, 'elastic': 200};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['应力'], '-20');
    expect(valuesByLabel['应力幅值'], '20');
    expect(valuesByLabel['应变'], '-0.0001');
    expect(valuesByLabel['微应变'], '-100');
    expect(valuesByLabel['每米变形'], '-0.1');
    expect(valuesByLabel['截面积'], '0.5');
    expect(valuesByLabel['载荷类型'], '压缩');
    expect(insights, contains('这是轴向平均应力'));
  });

  test('stress strain rejects invalid area and warns on high stress', () {
    final definition = tool('stress_strain');
    final invalidValues = <String, double>{
      'force': 1000,
      'area': 0,
      'elastic': 200
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['应力'], '无效');
    expect(invalidByLabel['载荷类型'], '无效');
    expect(invalidInsights, contains('截面积和弹性模量必须大于 0，轴向力必须是有限数值'));

    final highStressValues = <String, double>{
      'force': 30000,
      'area': 50,
      'elastic': 200,
    };
    final highStressResults = calculateTool(definition, highStressValues);
    final highStressInsights =
        buildToolInsights(definition, highStressValues, highStressResults)
            .join('\n');

    expect(highStressResults.first.value, '600');
    expect(highStressInsights, contains('应力超过 250MPa'));
  });

  test('safety factor reports margin ratio and stress magnitude', () {
    final definition = tool('safety_factor');
    final values = <String, double>{'strength': 250, 'stress': -80};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['安全系数'], '3.125');
    expect(valuesByLabel['余量'], '170');
    expect(valuesByLabel['余量比例'], '68');
    expect(valuesByLabel['工作应力幅值'], '80');
    expect(valuesByLabel['许用强度'], '250');
    expect(valuesByLabel['判断'], '较安全');
    expect(insights, isNot(contains('安全系数偏紧')));

    final targetResults = calculateTool(definition, {
      'strength': 250,
      'stress': -80,
      'targetFactor': 4,
    });
    final targetByLabel = {
      for (final result in targetResults) result.label: result.value,
    };
    final targetInsights = buildToolInsights(
      definition,
      {'strength': 250, 'stress': -80, 'targetFactor': 4},
      targetResults,
    ).join('\n');

    expect(targetByLabel['目标安全系数'], '4');
    expect(targetByLabel['目标系数所需强度'], '320');
    expect(targetByLabel['目标系数许用应力'], '62.5');
    expect(targetByLabel['需降低应力'], '17.5');
    expect(targetByLabel['安全系数差值'], '-0.875');
    expect(targetInsights, contains('目标安全系数需要材料强度约 320MPa'));
    expect(targetInsights, contains('当前安全系数低于目标 0.875'));
  });

  test('safety factor handles zero stress and invalid strength', () {
    final definition = tool('safety_factor');
    final zeroStressValues = <String, double>{'strength': 250, 'stress': 0};
    final zeroStressResults = calculateTool(definition, zeroStressValues);
    final zeroStressByLabel = {
      for (final result in zeroStressResults) result.label: result.value,
    };
    final zeroStressInsights =
        buildToolInsights(definition, zeroStressValues, zeroStressResults)
            .join('\n');

    expect(zeroStressByLabel['安全系数'], '无穷大');
    expect(zeroStressByLabel['判断'], '无载荷');
    expect(zeroStressInsights, contains('工作应力为 0 时安全系数趋于无穷大'));

    final invalidValues = <String, double>{'strength': 0, 'stress': 80};
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['安全系数'], '无效');
    expect(invalidByLabel['判断'], '无效');
    expect(invalidInsights, contains('材料强度必须大于 0，工作应力必须是有限数值'));
  });

  test('flow velocity reports area flow units Reynolds number and state', () {
    final definition = tool('flow_velocity');
    final values = <String, double>{'flow': 30, 'diameter': 20};
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['平均流速m/s'], startsWith('1.591549'));
    expect(valuesByLabelUnit['截面积mm²'], startsWith('314.159'));
    expect(valuesByLabelUnit['流量m³/h'], '1.8');
    expect(valuesByLabelUnit['流量m³/s'], '0.0005');
    expect(valuesByLabelUnit['管内径m'], '0.02');
    expect(valuesByLabelUnit['水力直径mm'], '20');
    expect(valuesByLabelUnit['雷诺数(水20℃)'], startsWith('31704.171'));
    expect(valuesByLabelUnit['流动状态(水)'], '湍流');
    expect(insights, contains('雷诺数按 20℃ 水的运动黏度估算'));
  });

  test('flow velocity rejects invalid diameter and warns on high velocity', () {
    final definition = tool('flow_velocity');
    final invalidValues = <String, double>{'flow': 30, 'diameter': 0};
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults)
        '${result.label}${result.unit}': result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['平均流速m/s'], '无效');
    expect(invalidByLabel['雷诺数(水20℃)'], '无效');
    expect(invalidInsights, contains('流量不能为负，管内径必须大于 0'));

    final highSpeedValues = <String, double>{'flow': 200, 'diameter': 20};
    final highSpeedResults = calculateTool(definition, highSpeedValues);
    final highSpeedInsights =
        buildToolInsights(definition, highSpeedValues, highSpeedResults)
            .join('\n');

    expect(highSpeedResults.first.value, startsWith('10.610'));
    expect(highSpeedInsights, contains('流速超过 3m/s'));
    expect(highSpeedInsights, contains('雷诺数超过 100000'));
  });

  test('material weight reports weight force volume area and area density', () {
    final definition = tool('material_weight');
    final values = <String, double>{
      'length': 1000,
      'width': 100,
      'thickness': 10,
      'density': 7.85,
    };
    final results = calculateTool(definition, values);
    final valuesByLabelUnit = {
      for (final result in results)
        '${result.label}${result.unit}': result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabelUnit['重量kg'], '7.85');
    expect(valuesByLabelUnit['体积cm³'], '1000');
    expect(valuesByLabelUnit['重量lb'], startsWith('17.306'));
    expect(valuesByLabelUnit['重量N'], startsWith('76.982'));
    expect(valuesByLabelUnit['体积L'], '1');
    expect(valuesByLabelUnit['体积m³'], '0.001');
    expect(valuesByLabelUnit['表面积m²'], '0.222');
    expect(valuesByLabelUnit['面密度kg/m²'], '78.5');
    expect(insights, contains('矩形板材按实心体估算'));
  });

  test('material weight rejects invalid dimensions and warns on handling risk',
      () {
    final definition = tool('material_weight');
    final invalidValues = <String, double>{
      'length': 1000,
      'width': 100,
      'thickness': 0,
      'density': 7.85,
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults)
        '${result.label}${result.unit}': result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['重量kg'], '无效');
    expect(invalidByLabel['表面积m²'], '无效');
    expect(invalidInsights, contains('长度、宽度、厚度和密度都必须大于 0'));

    final largeThinValues = <String, double>{
      'length': 3000,
      'width': 2000,
      'thickness': 0.8,
      'density': 7.85,
    };
    final largeThinResults = calculateTool(definition, largeThinValues);
    final largeThinInsights =
        buildToolInsights(definition, largeThinValues, largeThinResults)
            .join('\n');

    expect(largeThinResults.first.value, startsWith('37.68'));
    expect(largeThinInsights, contains('厚度低于 1mm'));
  });

  test('loan tool reports payment breakdown and interest ratio', () {
    final definition = tool('loan');
    final values = <String, double>{'amount': 50, 'rate': 4.1, 'years': 20};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['每月还款额'], startsWith('3056.313'));
    expect(valuesByLabel['贷款金额'], '50');
    expect(valuesByLabel['年利率'], '4.1');
    expect(valuesByLabel['贷款年限'], '20');
    expect(valuesByLabel['总利息'], startsWith('233515.125'));
    expect(valuesByLabel['总还款额'], startsWith('733515.125'));
    expect(valuesByLabel['还款期数'], '240');
    expect(valuesByLabel['首月利息'], startsWith('1708.333'));
    expect(valuesByLabel['首月本金'], startsWith('1347.979'));
    expect(valuesByLabel['利息占本金'], startsWith('46.703'));
    expect(valuesByLabel['年还款额'], startsWith('36675.756'));
    expect(valuesByLabel['输入来源'], '贷款金额+年利率+贷款年限');
    expect(insights, contains('按等额本息算'));

    final referenceValues = <String, double>{
      'amount': 50,
      'rate': 4.1,
      'years': 20,
      'targetPayment': 3000,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '贷款金额+年利率+贷款年限，目标月供作参考');
    expect(referenceByLabel['月供差值'], startsWith('56.313'));
    expect(referenceInsights, contains('目标月供与当前月供相差 56.313'));
  });

  test('loan tool rejects invalid term and warns on high interest burden', () {
    final definition = tool('loan');
    final invalidValues = <String, double>{
      'amount': 50,
      'rate': 4.1,
      'years': 0
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['每月还款额'], '无效');
    expect(invalidByLabel['利息占本金'], '无效');
    expect(invalidInsights.join('\n'), contains('贷款金额、年利率、贷款年限和目标月供至少填写三项'));

    final highInterestValues = <String, double>{
      'amount': 50,
      'rate': 8,
      'years': 30,
    };
    final highInterestResults = calculateTool(definition, highInterestValues);
    final highInterestInsights =
        buildToolInsights(definition, highInterestValues, highInterestResults)
            .join('\n');

    expect(highInterestResults.first.value, startsWith('3668.822'));
    expect(highInterestInsights, contains('总利息超过本金 50%'));
  });

  test('loan tool reverse solves affordable amount and required rate', () {
    final definition = tool('loan');
    final amountResults = calculateTool(definition, {
      'targetPayment': 3056.313,
      'rate': 4.1,
      'years': 20,
    });
    final amountByLabel = {
      for (final result in amountResults) result.label: result.value,
    };
    expect(amountByLabel['贷款金额'], '50');
    expect(amountByLabel['输入来源'], '目标月供+年利率+贷款年限');

    final rateResults = calculateTool(definition, {
      'amount': 50,
      'targetPayment': 3056.313,
      'years': 20,
    });
    final rateByLabel = {
      for (final result in rateResults) result.label: result.value,
    };
    expect(rateByLabel['年利率'], '4.1');
    expect(rateByLabel['输入来源'], '目标月供+贷款金额+贷款年限');
  });

  test('annuity tool reports periods per-period rate and gain ratio', () {
    final definition = tool('annuity');
    final values = <String, double>{
      'payment': 1000,
      'rate': 5,
      'years': 10,
      'perYear': 12,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['终值'], startsWith('155282.279'));
    expect(valuesByLabel['每期投入'], '1000');
    expect(valuesByLabel['年化收益'], '5');
    expect(valuesByLabel['年限'], '10');
    expect(valuesByLabel['每年期数'], '12');
    expect(valuesByLabel['累计投入'], '120000');
    expect(valuesByLabel['收益'], startsWith('35282.279'));
    expect(valuesByLabel['期数'], '120');
    expect(valuesByLabel['每期收益率'], startsWith('0.416667'));
    expect(valuesByLabel['收益/投入'], startsWith('29.401'));
    expect(valuesByLabel['输入来源'], '每期投入+年化收益+年限');
    expect(insights, contains('年金按期末投入估算'));

    final referenceValues = <String, double>{
      'payment': 1000,
      'rate': 5,
      'years': 10,
      'perYear': 12,
      'target': 150000,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '每期投入+年化收益+年限，目标终值作参考');
    expect(referenceByLabel['终值差值'], startsWith('5282.279'));
    expect(referenceInsights, contains('目标终值与当前终值相差 5282.279'));
  });

  test('annuity tool rejects invalid frequency and warns on negative gain', () {
    final definition = tool('annuity');
    final invalidValues = <String, double>{
      'payment': 1000,
      'rate': 5,
      'years': 10,
      'perYear': 0,
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['终值'], '无效');
    expect(invalidByLabel['每期收益率'], '无效');
    expect(
      invalidInsights.join('\n'),
      contains('每期投入、年化收益、年限和目标终值至少填写三项'),
    );

    final lossValues = <String, double>{
      'payment': 1000,
      'rate': -5,
      'years': 10,
      'perYear': 12,
    };
    final lossResults = calculateTool(definition, lossValues);
    final lossInsights =
        buildToolInsights(definition, lossValues, lossResults).join('\n');

    expect(lossResults.first.value, startsWith('94584.617'));
    expect(lossInsights, contains('收益为负'));
  });

  test('annuity tool reverse solves contribution and required return', () {
    final definition = tool('annuity');
    final paymentResults = calculateTool(definition, {
      'target': 155282.279,
      'rate': 5,
      'years': 10,
      'perYear': 12,
    });
    final paymentByLabel = {
      for (final result in paymentResults) result.label: result.value,
    };
    expect(paymentByLabel['每期投入'], startsWith('999.999'));
    expect(paymentByLabel['输入来源'], '目标终值+年化收益+年限');

    final rateResults = calculateTool(definition, {
      'payment': 1000,
      'target': 155282.279,
      'years': 10,
      'perYear': 12,
    });
    final rateByLabel = {
      for (final result in rateResults) result.label: result.value,
    };
    expect(rateByLabel['年化收益'], '5');
    expect(rateByLabel['输入来源'], '目标终值+每期投入+年限');
  });

  test('installment tool reports per-period fee and effective period rate', () {
    final definition = tool('installment');
    final values = <String, double>{'price': 6000, 'fee': 6, 'months': 12};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['每期付款'], '530');
    expect(valuesByLabel['商品价格'], '6000');
    expect(valuesByLabel['总手续费率'], '6');
    expect(valuesByLabel['手续费'], '360');
    expect(valuesByLabel['总支付'], '6360');
    expect(valuesByLabel['期数'], '12');
    expect(valuesByLabel['每期本金'], '500');
    expect(valuesByLabel['每期手续费'], '30');
    expect(valuesByLabel['等效每期费率'], '0.5');
    expect(valuesByLabel['输入来源'], '商品价格+总手续费率+分期期数');
    expect(insights, contains('分期按总手续费平均摊到每期'));

    final referenceValues = <String, double>{
      'price': 6000,
      'fee': 6,
      'months': 12,
      'targetPayment': 500,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '商品价格+总手续费率+分期期数，目标每期作参考');
    expect(referenceByLabel['每期差值'], '30');
    expect(referenceInsights, contains('目标每期与当前每期付款相差 30元'));
  });

  test('installment tool rejects invalid months and warns on high fee', () {
    final definition = tool('installment');
    final invalidValues = <String, double>{
      'price': 6000,
      'fee': 6,
      'months': 0
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['每期付款'], '无效');
    expect(invalidByLabel['期数'], '无效');
    expect(invalidInsights.join('\n'), contains('商品价格、总手续费率、分期期数和目标每期至少填写三项'));

    final highFeeResults =
        calculateTool(definition, {'price': 6000, 'fee': 25, 'months': 12});
    final highFeeInsights = buildToolInsights(definition,
            {'price': 6000, 'fee': 25, 'months': 12}, highFeeResults)
        .join('\n');

    expect(highFeeResults.first.value, '625');
    expect(highFeeInsights, contains('总手续费率超过 20%'));
  });

  test('installment tool reverse solves affordable price and fee rate', () {
    final definition = tool('installment');
    final priceResults = calculateTool(definition, {
      'targetPayment': 530,
      'fee': 6,
      'months': 12,
    });
    final priceByLabel = {
      for (final result in priceResults) result.label: result.value,
    };
    expect(priceByLabel['商品价格'], '6000');
    expect(priceByLabel['输入来源'], '目标每期+总手续费率+分期期数');

    final feeResults = calculateTool(definition, {
      'price': 6000,
      'targetPayment': 530,
      'months': 12,
    });
    final feeByLabel = {
      for (final result in feeResults) result.label: result.value,
    };
    expect(feeByLabel['总手续费率'], '6');
    expect(feeByLabel['输入来源'], '目标每期+商品价格+分期期数');
  });

  test('break even tool reverse solves economics and reports sales amounts',
      () {
    final definition = tool('break_even');
    final values = <String, double>{
      'fixed': 50000,
      'price': 120,
      'variable': 70
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['平衡销量'], '1000');
    expect(valuesByLabel['向上取整销量'], '1000');
    expect(valuesByLabel['边际贡献'], '50');
    expect(valuesByLabel['边际率'], startsWith('41.666'));
    expect(valuesByLabel['平衡销售额'], '120000');
    expect(valuesByLabel['平衡变动成本'], '70000');
    expect(valuesByLabel['输入来源'], '固定成本+单价+单位变动成本');
    expect(insights, contains('盈亏平衡只看单品静态模型'));

    final fixedFromTarget = calculateTool(definition, {
      'targetQuantity': 1000,
      'price': 120,
      'variable': 70,
    });
    final fixedFromTargetByLabel = {
      for (final result in fixedFromTarget) result.label: result.value,
    };
    expect(fixedFromTargetByLabel['固定成本'], '50000');
    expect(fixedFromTargetByLabel['输入来源'], '目标销量+单价+单位变动成本');

    final priceFromTarget = calculateTool(definition, {
      'fixed': 50000,
      'targetQuantity': 1000,
      'variable': 70,
    });
    final priceFromTargetByLabel = {
      for (final result in priceFromTarget) result.label: result.value,
    };
    expect(priceFromTargetByLabel['单价'], '120');
    expect(priceFromTargetByLabel['输入来源'], '目标销量+固定成本+单位变动成本');

    final variableFromTarget = calculateTool(definition, {
      'fixed': 50000,
      'price': 120,
      'targetQuantity': 1000,
    });
    final variableFromTargetByLabel = {
      for (final result in variableFromTarget) result.label: result.value,
    };
    expect(variableFromTargetByLabel['单位变动成本'], '70');
    expect(variableFromTargetByLabel['输入来源'], '目标销量+固定成本+单价');

    final referenceValues = <String, double>{
      'fixed': 50000,
      'price': 120,
      'variable': 70,
      'targetQuantity': 900,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '固定成本+单价+单位变动成本，目标销量作参考');
    expect(referenceByLabel['销量差值'], '100');
    expect(referenceInsights, contains('目标销量与当前平衡销量相差 100件'));
  });

  test('break even tool rejects invalid economics and non-positive margin', () {
    final definition = tool('break_even');
    final invalidResults =
        calculateTool(definition, {'fixed': -1, 'price': 120, 'variable': 70});
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights = buildToolInsights(definition,
        {'fixed': -1, 'price': 120, 'variable': 70}, invalidResults);

    expect(invalidByLabel['平衡销量'], '无效');
    expect(invalidByLabel['平衡销售额'], '无效');
    expect(
      invalidInsights.join('\n'),
      contains('固定成本、单价、单位变动成本和目标销量至少填写三项'),
    );

    final noMarginValues = <String, double>{
      'fixed': 50000,
      'price': 70,
      'variable': 70,
    };
    final noMarginResults = calculateTool(definition, noMarginValues);
    final noMarginByLabel = {
      for (final result in noMarginResults) result.label: result.value,
    };
    final noMarginInsights =
        buildToolInsights(definition, noMarginValues, noMarginResults);

    expect(noMarginByLabel['平衡销量'], '无效');
    expect(noMarginByLabel['边际贡献'], '0');
    expect(noMarginInsights, contains('边际贡献不大于 0，卖得越多也无法覆盖固定成本'));

    final incompleteResults =
        calculateTool(definition, {'targetQuantity': 1000, 'price': 120});
    final impossibleVariable = calculateTool(definition, {
      'fixed': 50000,
      'price': 40,
      'targetQuantity': 1000,
    });

    expect(incompleteResults.first.value, '无效');
    expect(impossibleVariable.first.value, '无效');
  });

  test('electricity cost reverse solves budget inputs and reports long costs',
      () {
    final definition = tool('electricity_cost');
    final values = <String, double>{
      'power': 800,
      'hours': 3,
      'days': 30,
      'price': 0.6,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['费用'], '43.2');
    expect(valuesByLabel['用电量'], '72');
    expect(valuesByLabel['日均费用'], '1.44');
    expect(valuesByLabel['日均用电'], '2.4');
    expect(valuesByLabel['月化费用'], '43.2');
    expect(valuesByLabel['年化费用'], '525.6');
    expect(valuesByLabel['输入来源'], '功率+每日使用+天数+电价');
    expect(insights, contains('电费按固定单价估算'));

    final powerFromTarget = calculateTool(definition, {
      'targetCost': 43.2,
      'hours': 3,
      'days': 30,
      'price': 0.6,
    });
    final powerFromTargetByLabel = {
      for (final result in powerFromTarget) result.label: result.value,
    };
    expect(powerFromTargetByLabel['功率'], '800');
    expect(powerFromTargetByLabel['输入来源'], '目标费用+每日使用+天数+电价');

    final hoursFromTarget = calculateTool(definition, {
      'targetCost': 43.2,
      'power': 800,
      'days': 30,
      'price': 0.6,
    });
    final hoursFromTargetByLabel = {
      for (final result in hoursFromTarget) result.label: result.value,
    };
    expect(hoursFromTargetByLabel['每日使用'], '3');
    expect(hoursFromTargetByLabel['输入来源'], '目标费用+功率+天数+电价');

    final priceFromTarget = calculateTool(definition, {
      'targetCost': 43.2,
      'power': 800,
      'hours': 3,
      'days': 30,
    });
    final priceFromTargetByLabel = {
      for (final result in priceFromTarget) result.label: result.value,
    };
    expect(priceFromTargetByLabel['电价'], '0.6');
    expect(priceFromTargetByLabel['输入来源'], '目标费用+功率+每日使用+天数');

    final referenceValues = <String, double>{
      'power': 800,
      'hours': 3,
      'days': 30,
      'price': 0.6,
      'targetCost': 40,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '功率+每日使用+天数+电价，目标费用作参考');
    expect(referenceByLabel['费用差值'], '3.2');
    expect(referenceInsights, contains('目标费用与当前计算相差 3.2元'));
  });

  test('electricity cost rejects invalid hours and warns on high consumption',
      () {
    final definition = tool('electricity_cost');
    final invalidValues = <String, double>{
      'power': 800,
      'hours': 25,
      'days': 30,
      'price': 0.6,
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);

    expect(invalidByLabel['费用'], '无效');
    expect(invalidByLabel['日均用电'], '无效');
    expect(
      invalidInsights.join('\n'),
      contains('功率、每日使用、天数、电价和目标费用至少填写四项'),
    );

    final incompleteResults =
        calculateTool(definition, {'targetCost': 43.2, 'power': 800});
    final impossibleHours = calculateTool(definition, {
      'targetCost': 1000,
      'power': 800,
      'days': 30,
      'price': 0.6,
    });

    expect(incompleteResults.first.value, '无效');
    expect(impossibleHours.first.value, '无效');

    final highUseValues = <String, double>{
      'power': 5000,
      'hours': 8,
      'days': 30,
      'price': 0.6,
    };
    final highUseResults = calculateTool(definition, highUseValues);
    final highUseInsights =
        buildToolInsights(definition, highUseValues, highUseResults).join('\n');

    expect(highUseResults.first.value, '720');
    expect(highUseInsights, contains('日均用电超过 20kWh'));
  });

  test('compound tool reverse solves principal rate years and validates inputs',
      () {
    final definition = tool('compound');
    final values = <String, double>{'principal': 10000, 'rate': 5, 'years': 10};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['终值'], startsWith('16288.946'));
    expect(valuesByLabel['收益'], startsWith('6288.946'));
    expect(valuesByLabel['收益率'], startsWith('62.889'));
    expect(valuesByLabel['本金'], '10000');
    expect(valuesByLabel['增长倍数'], startsWith('1.628'));
    expect(valuesByLabel['年化收益率'], '5');
    expect(valuesByLabel['年限'], '10');
    expect(valuesByLabel['输入来源'], '本金+年化收益+年限');
    expect(insights, contains('复利按固定年化收益估算'));

    final principalFromTarget = calculateTool(definition, {
      'target': 16288.946267,
      'rate': 5,
      'years': 10,
    });
    final principalFromTargetByLabel = {
      for (final result in principalFromTarget) result.label: result.value,
    };
    expect(principalFromTargetByLabel['本金'], startsWith('10000'));
    expect(principalFromTargetByLabel['输入来源'], '目标终值+年化收益+年限');

    final rateFromTarget = calculateTool(definition, {
      'principal': 10000,
      'target': 16288.946267,
      'years': 10,
    });
    final rateFromTargetByLabel = {
      for (final result in rateFromTarget) result.label: result.value,
    };
    expect(rateFromTargetByLabel['年化收益率'], startsWith('5'));
    expect(rateFromTargetByLabel['输入来源'], '本金+目标终值+年限');

    final yearsFromTarget = calculateTool(definition, {
      'principal': 10000,
      'target': 16288.946267,
      'rate': 5,
    });
    final yearsFromTargetByLabel = {
      for (final result in yearsFromTarget) result.label: result.value,
    };
    expect(yearsFromTargetByLabel['年限'], startsWith('10'));
    expect(yearsFromTargetByLabel['输入来源'], '本金+目标终值+年化收益');

    final referenceValues = <String, double>{
      'principal': 10000,
      'rate': 5,
      'years': 10,
      'target': 16000,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '本金+年化收益+年限，目标终值作参考');
    expect(referenceByLabel['终值差值'], startsWith('288.946'));
    expect(referenceInsights, contains('目标终值与当前计算相差'));

    final invalidValues = <String, double>{
      'principal': 10000,
      'rate': -100,
      'years': 10,
    };
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidByLabel = {
      for (final result in invalidResults) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults);
    final incompleteResults = calculateTool(definition, {'target': 16000});

    expect(invalidByLabel['终值'], '无效');
    expect(invalidByLabel['增长倍数'], '无效');
    expect(incompleteResults.first.value, '无效');
    expect(
      invalidInsights.join('\n'),
      contains('本金、年化收益、年限和目标终值至少填写三项'),
    );
  });

  test(
      'profit margin tool reverse solves price cost margin and validates inputs',
      () {
    final definition = tool('profit_margin');
    final values = <String, double>{'cost': 80, 'price': 120};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['利润'], '40');
    expect(valuesByLabel['毛利率'], startsWith('33.333'));
    expect(valuesByLabel['加价率'], '50');
    expect(valuesByLabel['成本占比'], startsWith('66.666'));
    expect(valuesByLabel['保本售价'], '80');
    expect(valuesByLabel['利润状态'], '盈利');
    expect(valuesByLabel['输入来源'], '成本+售价');
    expect(insights, contains('利润率只看单件毛利'));

    final priceFromMargin = calculateTool(definition, {
      'cost': 80,
      'margin': 33.3333333333,
    });
    final priceFromMarginByLabel = {
      for (final result in priceFromMargin) result.label: result.value,
    };
    expect(priceFromMarginByLabel['售价'], startsWith('120'));
    expect(priceFromMarginByLabel['利润'], startsWith('40'));
    expect(priceFromMarginByLabel['输入来源'], '成本+目标毛利率');

    final costFromProfit = calculateTool(definition, {
      'price': 120,
      'profit': 40,
    });
    final costFromProfitByLabel = {
      for (final result in costFromProfit) result.label: result.value,
    };
    expect(costFromProfitByLabel['成本'], '80');
    expect(costFromProfitByLabel['毛利率'], startsWith('33.333'));
    expect(costFromProfitByLabel['输入来源'], '售价+目标利润');

    final marginFromProfit = calculateTool(definition, {
      'margin': 33.3333333333,
      'profit': 40,
    });
    final marginFromProfitByLabel = {
      for (final result in marginFromProfit) result.label: result.value,
    };
    expect(marginFromProfitByLabel['售价'], startsWith('120'));
    expect(marginFromProfitByLabel['成本'], startsWith('80'));
    expect(marginFromProfitByLabel['输入来源'], '目标毛利率+目标利润');

    final referenceValues = <String, double>{
      'cost': 80,
      'price': 120,
      'margin': 30,
      'profit': 45,
    };
    final referenceResults = calculateTool(definition, referenceValues);
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(definition, referenceValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['输入来源'], '成本+售价，目标值作参考');
    expect(referenceByLabel['利润差值'], '-5');
    expect(referenceByLabel['毛利率差值'], startsWith('3.333'));
    expect(referenceInsights, contains('目标利润与当前计算相差 -5元'));
    expect(referenceInsights, contains('目标毛利率与当前计算相差'));

    final lossValues = <String, double>{'cost': 130, 'price': 120};
    final lossResults = calculateTool(definition, lossValues);
    final lossByLabel = {
      for (final result in lossResults) result.label: result.value,
    };
    final lossInsights =
        buildToolInsights(definition, lossValues, lossResults).join('\n');

    expect(lossByLabel['利润'], '-10');
    expect(lossByLabel['利润状态'], '亏损');
    expect(lossInsights, contains('当前售价低于成本'));

    final invalidResults = calculateTool(definition, {'cost': 80, 'price': 0});
    final incompleteResults = calculateTool(definition, {'margin': 30});

    expect(invalidResults.first.value, '无效');
    expect(incompleteResults.first.value, '无效');
  });

  test('roi tool reports payback metrics and rejects zero investment', () {
    final definition = tool('roi');
    final values = <String, double>{'gain': 12500, 'cost': 10000, 'years': 2};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['ROI'], '25');
    expect(valuesByLabel['收益'], '12500');
    expect(valuesByLabel['投入'], '10000');
    expect(valuesByLabel['净收益'], '2500');
    expect(valuesByLabel['回报倍数'], '1.25');
    expect(valuesByLabel['回本率'], '125');
    expect(valuesByLabel['盈亏平衡差额'], '2500');
    expect(valuesByLabel['输入来源'], '收益+投入');
    expect(valuesByLabel['持有年限'], '2');
    expect(valuesByLabel['年化ROI'], startsWith('11.803'));
    expect(valuesByLabel['年化回报倍数'], startsWith('1.118'));
    expect(valuesByLabel['月均净收益'], startsWith('104.166'));
    expect(valuesByLabel['简单回收期'], '8');
    expect(insights, contains('已按持有年限折算年化 ROI'));
    expect(insights, contains('简单回收期约 8 年'));

    final noYears = calculateTool(definition, {'gain': 12500, 'cost': 10000});
    final noYearsByLabel = {
      for (final result in noYears) result.label: result.value,
    };
    final noYearsInsights =
        buildToolInsights(definition, {'gain': 12500, 'cost': 10000}, noYears)
            .join('\n');

    expect(noYearsByLabel, isNot(contains('年化ROI')));
    expect(noYearsInsights, contains('持有年限 未填写'));
    expect(noYearsInsights, contains('未填写持有年限'));

    final gainFromRoi = calculateTool(definition, {
      'cost': 10000,
      'roi': 25,
      'years': 2,
    });
    final gainFromRoiByLabel = {
      for (final result in gainFromRoi) result.label: result.value,
    };
    expect(gainFromRoiByLabel['收益'], '12500');
    expect(gainFromRoiByLabel['净收益'], '2500');
    expect(gainFromRoiByLabel['输入来源'], '投入+ROI');

    final costFromRoi = calculateTool(definition, {
      'gain': 12500,
      'roi': 25,
    });
    final costFromRoiByLabel = {
      for (final result in costFromRoi) result.label: result.value,
    };
    expect(costFromRoiByLabel['投入'], '10000');
    expect(costFromRoiByLabel['输入来源'], '收益+ROI');

    final referenceRoi = calculateTool(definition, {
      'gain': 12500,
      'cost': 10000,
      'roi': 20,
    });
    final referenceRoiByLabel = {
      for (final result in referenceRoi) result.label: result.value,
    };
    final referenceRoiInsights = buildToolInsights(
      definition,
      {
        'gain': 12500,
        'cost': 10000,
        'roi': 20,
      },
      referenceRoi,
    ).join('\n');
    expect(referenceRoiByLabel['输入来源'], '收益+投入，ROI作参考');
    expect(referenceRoiByLabel['ROI差值'], '5');
    expect(referenceRoiInsights, contains('ROI 参考值与当前计算相差 5%'));

    final negative = calculateTool(definition, {
      'gain': 9000,
      'cost': 10000,
      'years': 2,
    });
    final negativeByLabel = {
      for (final result in negative) result.label: result.value,
    };
    final negativeInsights = buildToolInsights(
      definition,
      {'gain': 9000, 'cost': 10000, 'years': 2},
      negative,
    ).join('\n');

    expect(negativeByLabel['ROI'], '-10');
    expect(negativeByLabel['年化ROI'], startsWith('-5.131'));
    expect(negativeByLabel['简单回收期'], '未回收');
    expect(negativeInsights, contains('ROI 为负'));
    expect(negativeInsights, contains('按当前净收益无法回收投入'));

    final invalidValues = <String, double>{'gain': 12500, 'cost': 0};
    final invalidResults = calculateTool(definition, invalidValues);
    final invalidInsights =
        buildToolInsights(definition, invalidValues, invalidResults).join('\n');

    expect(invalidResults.first.value, '无效');
    expect(invalidInsights, contains('至少填写两项'));

    final invalidYears = calculateTool(definition, {
      'gain': 12500,
      'cost': 10000,
      'years': 0,
    });
    final invalidYearsByLabel = {
      for (final result in invalidYears) result.label: result.value,
    };

    expect(invalidYearsByLabel['ROI'], '无效');
    expect(invalidYearsByLabel['年化ROI'], '无效');
  });

  test('discount tool reports saving ratio and validates discount range', () {
    final definition = tool('discount');
    final values = <String, double>{'price': 299, 'discount': 85};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['到手价'], '254.15');
    expect(valuesByLabel['原价'], '299');
    expect(valuesByLabel['节省'], '44.85');
    expect(valuesByLabel['折扣率'], '85');
    expect(valuesByLabel['优惠比例'], '15');
    expect(valuesByLabel['每百元支付'], '85');
    expect(valuesByLabel['输入来源'], '原价+折扣');
    expect(insights, contains('当前按 原价+折扣 计算'));
    expect(insights, contains('折扣计算只看标价优惠'));

    final discountFromFinal = calculateTool(definition, {
      'price': 299,
      'finalPrice': 254.15,
    });
    final discountFromFinalByLabel = {
      for (final result in discountFromFinal) result.label: result.value,
    };
    expect(discountFromFinalByLabel['折扣率'], '85');
    expect(discountFromFinalByLabel['节省'], '44.85');
    expect(discountFromFinalByLabel['输入来源'], '原价+到手价');

    final priceFromDiscount = calculateTool(definition, {
      'discount': 85,
      'finalPrice': 254.15,
    });
    final priceFromDiscountByLabel = {
      for (final result in priceFromDiscount) result.label: result.value,
    };
    expect(priceFromDiscountByLabel['原价'], '299');
    expect(priceFromDiscountByLabel['输入来源'], '折扣+到手价');

    final referenceFinalPrice = calculateTool(definition, {
      'price': 299,
      'discount': 85,
      'finalPrice': 250,
    });
    final referenceFinalPriceByLabel = {
      for (final result in referenceFinalPrice) result.label: result.value,
    };
    final referenceFinalPriceInsights = buildToolInsights(
      definition,
      {
        'price': 299,
        'discount': 85,
        'finalPrice': 250,
      },
      referenceFinalPrice,
    ).join('\n');
    expect(referenceFinalPriceByLabel['输入来源'], '原价+折扣，到手价作参考');
    expect(referenceFinalPriceByLabel['到手价差值'], '4.15');
    expect(referenceFinalPriceInsights, contains('到手价参考值与当前计算相差 4.15元'));

    final deepDiscountValues = <String, double>{'price': 299, 'discount': 40};
    final deepDiscountResults = calculateTool(definition, deepDiscountValues);
    final deepDiscountInsights =
        buildToolInsights(definition, deepDiscountValues, deepDiscountResults)
            .join('\n');

    expect(deepDiscountResults.first.value, '119.6');
    expect(deepDiscountInsights, contains('优惠比例超过 50%'));

    final invalidDiscount =
        calculateTool(definition, {'price': 299, 'discount': 120});
    final invalidFinalPrice =
        calculateTool(definition, {'price': 299, 'finalPrice': 300});

    expect(invalidDiscount.first.value, '无效');
    expect(invalidFinalPrice.first.value, '无效');
  });

  test('tax tool reverse solves amounts rate and validates inputs', () {
    final definition = tool('tax');
    final values = <String, double>{'net': 1000, 'rate': 13};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['含税金额'], '1130');
    expect(valuesByLabel['税额'], '130');
    expect(valuesByLabel['不含税反推'], '1000');
    expect(valuesByLabel['税率'], '13');
    expect(valuesByLabel['税负率'], startsWith('11.504'));
    expect(valuesByLabel['价税合计倍率'], '1.13');
    expect(valuesByLabel['输入来源'], '税前金额+税率');
    expect(insights, contains('当前按 税前金额+税率 计算'));

    final netFromGross = calculateTool(definition, {
      'gross': 1130,
      'rate': 13,
    });
    final netFromGrossByLabel = {
      for (final result in netFromGross) result.label: result.value,
    };
    expect(netFromGrossByLabel['不含税反推'], '1000');
    expect(netFromGrossByLabel['税额'], '130');
    expect(netFromGrossByLabel['输入来源'], '含税金额+税率');

    final rateFromAmounts = calculateTool(definition, {
      'net': 1000,
      'gross': 1130,
    });
    final rateFromAmountsByLabel = {
      for (final result in rateFromAmounts) result.label: result.value,
    };
    expect(rateFromAmountsByLabel['税率'], '13');
    expect(rateFromAmountsByLabel['输入来源'], '税前金额+含税金额');

    final referenceGrossValues = <String, double>{
      'net': 1000,
      'rate': 13,
      'gross': 1120,
    };
    final referenceGrossResults =
        calculateTool(definition, referenceGrossValues);
    final referenceGrossByLabel = {
      for (final result in referenceGrossResults) result.label: result.value,
    };
    final referenceGrossInsights = buildToolInsights(
            definition, referenceGrossValues, referenceGrossResults)
        .join('\n');
    expect(referenceGrossByLabel['输入来源'], '税前金额+税率，含税金额作参考');
    expect(referenceGrossByLabel['含税金额差值'], '10');
    expect(referenceGrossInsights, contains('含税金额参考值与当前计算相差 10元'));

    final highTaxValues = <String, double>{'net': 1000, 'rate': 30};
    final highTaxResults = calculateTool(definition, highTaxValues);
    final highTaxInsights =
        buildToolInsights(definition, highTaxValues, highTaxResults).join('\n');

    expect(highTaxResults.first.value, '1300');
    expect(highTaxInsights, contains('税负率超过 20%'));

    final invalidResults =
        calculateTool(definition, {'net': 1000, 'rate': -100});
    final incompleteResults = calculateTool(definition, {'gross': 1130});

    expect(invalidResults.first.value, '无效');
    expect(incompleteResults.first.value, '无效');
  });

  test('inflation tool reverse solves amount rate years and validates inputs',
      () {
    final definition = tool('inflation');
    final values = <String, double>{'amount': 10000, 'rate': 3, 'years': 10};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['未来等值'], startsWith('13439.163'));
    expect(valuesByLabel['购买力折现'], startsWith('7440.939'));
    expect(valuesByLabel['累计涨幅'], startsWith('34.391'));
    expect(valuesByLabel['购买力损失'], startsWith('2559.060'));
    expect(valuesByLabel['等值倍率'], startsWith('1.343'));
    expect(valuesByLabel['输入来源'], '当前金额+年通胀率+年数');
    expect(insights, contains('购买力损失为正'));

    final amountFromFuture = calculateTool(definition, {
      'future': 13439.163793,
      'rate': 3,
      'years': 10,
    });
    final amountFromFutureByLabel = {
      for (final result in amountFromFuture) result.label: result.value,
    };
    expect(amountFromFutureByLabel['当前金额'], startsWith('10000'));
    expect(amountFromFutureByLabel['输入来源'], '未来等值+年通胀率+年数');

    final rateFromFuture = calculateTool(definition, {
      'amount': 10000,
      'future': 13439.163793,
      'years': 10,
    });
    final rateFromFutureByLabel = {
      for (final result in rateFromFuture) result.label: result.value,
    };
    expect(rateFromFutureByLabel['年通胀率'], startsWith('3'));
    expect(rateFromFutureByLabel['输入来源'], '当前金额+未来等值+年数');

    final yearsFromFuture = calculateTool(definition, {
      'amount': 10000,
      'future': 13439.163793,
      'rate': 3,
    });
    final yearsFromFutureByLabel = {
      for (final result in yearsFromFuture) result.label: result.value,
    };
    expect(yearsFromFutureByLabel['年数'], startsWith('10'));
    expect(yearsFromFutureByLabel['输入来源'], '当前金额+未来等值+年通胀率');

    final referenceFutureValues = <String, double>{
      'amount': 10000,
      'rate': 3,
      'years': 10,
      'future': 13000,
    };
    final referenceFutureResults =
        calculateTool(definition, referenceFutureValues);
    final referenceFutureByLabel = {
      for (final result in referenceFutureResults) result.label: result.value,
    };
    final referenceFutureInsights = buildToolInsights(
      definition,
      referenceFutureValues,
      referenceFutureResults,
    ).join('\n');
    expect(referenceFutureByLabel['输入来源'], '当前金额+年通胀率+年数，未来等值作参考');
    expect(referenceFutureByLabel['未来等值差值'], startsWith('439.163'));
    expect(referenceFutureInsights, contains('未来等值参考值与当前计算相差'));

    final invalidIncomplete = calculateTool(definition, {'future': 12000});
    final invalidRateSolve = calculateTool(definition, {
      'amount': 0,
      'future': 12000,
      'years': 10,
    });

    expect(invalidIncomplete.first.value, '无效');
    expect(invalidRateSolve.first.value, '无效');
  });

  test('npv tool reports discounted cash flow and negative npv warning', () {
    final definition = tool('npv');
    final values = <String, double>{
      'initial': 10000,
      'rate': 8,
      'cf1': 4000,
      'cf2': 5000,
      'cf3': 6000,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['NPV'], startsWith('2753.391'));
    expect(valuesByLabel['期数'], '3');
    expect(valuesByLabel['总现金流'], '15000');
    expect(valuesByLabel['折现现金流'], startsWith('12753.391'));
    expect(valuesByLabel['盈利指数'], startsWith('1.275'));
    expect(valuesByLabel['回收差额'], '5000');
    expect(valuesByLabel['折现回收期'], startsWith('2.421'));
    expect(valuesByLabel['简单回收期'], startsWith('2.166'));
    expect(valuesByLabel['折现率-2% NPV'], startsWith('3261.282'));
    expect(valuesByLabel['折现率+2% NPV'], startsWith('2276.483'));
    expect(valuesByLabel['等效年化收益'], startsWith('8.444'));
    expect(insights, contains('NPV 对折现率很敏感'));
    expect(insights, contains('当前按 3 期现金流估算'));

    final negativeValues = <String, double>{
      'initial': 5000,
      'rate': 10,
      'cf1': 1000,
      'cf2': 1000,
      'cf3': 1000,
    };
    final negativeResults = calculateTool(definition, negativeValues);
    final negativeInsights =
        buildToolInsights(definition, negativeValues, negativeResults)
            .join('\n');

    expect(negativeResults.first.value, startsWith('-2513.148'));
    expect(negativeInsights, contains('NPV 为负'));
    expect(negativeInsights, contains('盈利指数低于 1'));
    expect(negativeInsights, contains('尚未回收初始投入'));
  });

  test('npv tool handles optional five period cash flows', () {
    final definition = tool('npv');
    final values = <String, double>{
      'initial': 12000,
      'rate': 7,
      'cf1': 2000,
      'cf2': 3000,
      'cf3': 3500,
      'cf4': 4000,
      'cf5': 4500,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['期数'], '5');
    expect(valuesByLabel['总现金流'], '17000');
    expect(valuesByLabel['NPV'], startsWith('1606.536'));
    expect(valuesByLabel['折现现金流'], startsWith('13606.536'));
    expect(valuesByLabel['盈利指数'], startsWith('1.133'));
    expect(valuesByLabel['折现回收期'], startsWith('4.499'));
    expect(valuesByLabel['简单回收期'], startsWith('3.875'));
    expect(valuesByLabel['等效年化收益'], startsWith('2.544'));
    expect(insights, contains('当前按 5 期现金流估算'));
  });

  test('bmi tool reports health range waist ratio and body surface area', () {
    final definition = tool('bmi');
    final values = <String, double>{
      'weight': 80,
      'height': 170,
      'waist': 92,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final unitsByLabel = {
      for (final result in results) result.label: result.unit,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['BMI'], startsWith('27.681'));
    expect(valuesByLabel['区间'], '超重');
    expect(valuesByLabel['健康体重范围'], '53.465 ~ 69.071');
    expect(valuesByLabel['正常体重下限'], '53.465');
    expect(valuesByLabel['正常体重上限'], '69.36');
    expect(valuesByLabel['距健康区间'], '-10.929 kg');
    expect(valuesByLabel['BMI 22 目标体重'], '63.58');
    expect(valuesByLabel['目标体重差'], '-16.42');
    expect(valuesByLabel['体表面积'], startsWith('1.943'));
    expect(valuesByLabel['腰高比'], startsWith('0.541'));
    expect(valuesByLabel['腰高比分级'], '偏高风险');
    expect(unitsByLabel['体表面积'], 'm²');
    expect(insights, contains('BMI 进入超重区间'));
    expect(insights, contains('健康体重范围约为 53.465 ~ 69.071 kg'));
    expect(insights, contains('腰高比达到 0.5'));
  });

  test('bmi tool ignores blank optional waist and rejects invalid inputs', () {
    final definition = tool('bmi');
    final values = <String, double>{'weight': 65, 'height': 170};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['BMI'], startsWith('22.491'));
    expect(valuesByLabel, isNot(contains('腰高比')));
    expect(insights, contains('腰围 未填写'));
    expect(insights, contains('BMI 位于常见健康区间'));

    final invalid = calculateTool(definition, {
      'weight': 65,
      'height': 0,
      'waist': 80,
    });
    final invalidByLabel = {
      for (final result in invalid) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, {'weight': 65, 'height': 0}, invalid)
            .join('\n');

    expect(invalidByLabel['BMI'], '无效');
    expect(invalidByLabel['腰高比'], '无效');
    expect(invalidInsights, contains('身高和体重必须大于 0'));
  });

  test('fuel economy reports cost range annual fuel and emissions', () {
    final definition = tool('fuel_economy');
    final values = <String, double>{
      'distance': 520,
      'fuel': 38,
      'price': 8,
      'tank': 55,
      'annualDistance': 15000,
      'co2': 2.31,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final unitsByLabel = {
      for (final result in results) result.label: result.unit,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['百公里油耗'], startsWith('7.307'));
    expect(valuesByLabel['km/L'], startsWith('13.684'));
    expect(valuesByLabel['里程'], '520');
    expect(valuesByLabel['燃油'], '38');
    expect(valuesByLabel['总费用'], '304');
    expect(valuesByLabel['每公里成本'], startsWith('0.584'));
    expect(valuesByLabel['百公里成本'], startsWith('58.461'));
    expect(valuesByLabel['输入来源'], '里程+燃油');
    expect(valuesByLabel['满箱续航'], startsWith('752.631'));
    expect(valuesByLabel['满箱费用'], '440');
    expect(valuesByLabel['年用油量'], startsWith('1096.153'));
    expect(valuesByLabel['年燃油费用'], startsWith('8769.230'));
    expect(valuesByLabel['年加油次数'], startsWith('19.930'));
    expect(valuesByLabel['CO2每公里'], startsWith('168.807'));
    expect(valuesByLabel['年CO2排放'], startsWith('2532.115'));
    expect(unitsByLabel['CO2每公里'], 'g/km');
    expect(insights, contains('当前按 里程+燃油 计算'));
    expect(insights, contains('路况、载重、胎压'));
  });

  test('fuel economy reverse solves fuel distance and reference consumption',
      () {
    final definition = tool('fuel_economy');

    final fuelFromConsumption = calculateTool(definition, {
      'distance': 500,
      'consumption': 6,
      'price': 8,
      'tank': 50,
    });
    final fuelFromConsumptionByLabel = {
      for (final result in fuelFromConsumption) result.label: result.value,
    };
    expect(fuelFromConsumptionByLabel['燃油'], '30');
    expect(fuelFromConsumptionByLabel['百公里油耗'], '6');
    expect(fuelFromConsumptionByLabel['总费用'], '240');
    expect(fuelFromConsumptionByLabel['满箱续航'], startsWith('833.333'));
    expect(fuelFromConsumptionByLabel['输入来源'], '里程+百公里油耗');

    final distanceFromConsumption = calculateTool(definition, {
      'fuel': 30,
      'consumption': 6,
      'price': 8,
    });
    final distanceFromConsumptionByLabel = {
      for (final result in distanceFromConsumption) result.label: result.value,
    };
    expect(distanceFromConsumptionByLabel['里程'], '500');
    expect(distanceFromConsumptionByLabel['每公里成本'], '0.48');
    expect(distanceFromConsumptionByLabel['输入来源'], '燃油+百公里油耗');

    final referenceConsumption = calculateTool(definition, {
      'distance': 500,
      'fuel': 30,
      'consumption': 5.5,
      'price': 8,
    });
    final referenceConsumptionByLabel = {
      for (final result in referenceConsumption) result.label: result.value,
    };
    final referenceConsumptionInsights = buildToolInsights(
      definition,
      {
        'distance': 500,
        'fuel': 30,
        'consumption': 5.5,
        'price': 8,
      },
      referenceConsumption,
    ).join('\n');
    expect(referenceConsumptionByLabel['输入来源'], '里程+燃油，百公里油耗作参考');
    expect(referenceConsumptionByLabel['油耗差值'], '0.5');
    expect(referenceConsumptionInsights, contains('油耗参考值与当前计算相差 0.5L/100km'));
  });

  test('fuel economy omits blank optional details and rejects invalid inputs',
      () {
    final definition = tool('fuel_economy');
    final basic = calculateTool(definition, {
      'distance': 500,
      'fuel': 25,
      'price': 7.5,
    });
    final basicByLabel = {
      for (final result in basic) result.label: result.value,
    };
    final basicInsights = buildToolInsights(
      definition,
      {'distance': 500, 'fuel': 25, 'price': 7.5},
      basic,
    ).join('\n');

    expect(basicByLabel['百公里油耗'], '5');
    expect(basicByLabel['km/L'], '20');
    expect(basicByLabel, isNot(contains('满箱续航')));
    expect(basicByLabel, isNot(contains('年燃油费用')));
    expect(basicByLabel, isNot(contains('CO2每公里')));
    expect(basicInsights, contains('油箱容量 未填写'));

    final invalid = calculateTool(definition, {
      'distance': 0,
      'fuel': 25,
      'price': 7.5,
      'tank': 55,
      'annualDistance': 15000,
      'co2': 2.31,
    });
    final invalidByLabel = {
      for (final result in invalid) result.label: result.value,
    };
    final invalidInsights =
        buildToolInsights(definition, {'distance': 0, 'fuel': 25}, invalid)
            .join('\n');

    expect(invalidByLabel['百公里油耗'], '无效');
    expect(invalidByLabel['满箱续航'], '无效');
    expect(invalidByLabel['年燃油费用'], '无效');
    expect(invalidByLabel['CO2每公里'], '无效');
    expect(invalidInsights, contains('至少填写两项'));
    expect(invalidInsights, isNot(contains('无效kg')));
  });

  test('financial edge cases do not expose infinity text', () {
    final inflation = calculateTool(
        tool('inflation'), {'amount': 1000, 'rate': -100, 'years': 1});
    final npv = calculateTool(tool('npv'), {
      'initial': 1000,
      'rate': -100,
      'cf1': 100,
      'cf2': 100,
      'cf3': 100,
    });

    expect(inflation.map((item) => item.value).join('\n'),
        isNot(contains('Infinity')));
    expect(inflation.map((item) => item.value).join('\n'), contains('无效'));
    expect(
        npv.map((item) => item.value).join('\n'), isNot(contains('Infinity')));
    expect(npv.first.value, '无效');
  });

  test('data size converter exposes decimal binary and bit outputs', () {
    final results = calculateTool(tool('data_size'), {
      'value': 1099511627776,
    });
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };

    expect(valuesByLabel['B'], startsWith('1.0995'));
    expect(valuesByLabel['bit'], startsWith('8.796093e+12'));
    expect(valuesByLabel['Gbit'], startsWith('8796.093'));
    expect(valuesByLabel['GB'], startsWith('1099.511'));
    expect(valuesByLabel['GiB'], '1024');
    expect(valuesByLabel['TB'], startsWith('1.099512'));
    expect(valuesByLabel['TiB'], '1');
  });

  test('motion tool reports distance conversions pace and invalid inputs', () {
    final definition = tool('motion');
    final values = <String, double>{'speed': 12, 'time': 30};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['距离'], '360');
    expect(valuesByLabel['距离 km'], '0.36');
    expect(valuesByLabel['速度'], '43.2');
    expect(valuesByLabel['速度 m/s'], '12');
    expect(valuesByLabel['速度 mph'], startsWith('26.843'));
    expect(valuesByLabel['时间'], '30');
    expect(valuesByLabel['时间 min'], '0.5');
    expect(valuesByLabel['时间 h'], startsWith('0.008333'));
    expect(valuesByLabel['配速'], startsWith('1.388'));
    expect(valuesByLabel['往返时间'], '60');
    expect(valuesByLabel['输入来源'], '速度+时间');
    expect(valuesByLabel, isNot(contains('距离差值')));
    expect(insights, contains('当前按 速度+时间 计算'));
    expect(insights, contains('匀速运动默认速度恒定'));

    final speedFromDistanceTime = calculateTool(definition, {
      'distance': 1000,
      'time': 250,
    });
    final speedFromDistanceTimeByLabel = {
      for (final result in speedFromDistanceTime) result.label: result.value,
    };

    expect(speedFromDistanceTimeByLabel['速度 m/s'], '4');
    expect(speedFromDistanceTimeByLabel['速度'], '14.4');
    expect(speedFromDistanceTimeByLabel['配速'], startsWith('4.166'));
    expect(speedFromDistanceTimeByLabel['输入来源'], '距离+时间');

    final timeFromDistanceSpeed = calculateTool(definition, {
      'distance': 1000,
      'speed': 5,
    });
    final timeFromDistanceSpeedByLabel = {
      for (final result in timeFromDistanceSpeed) result.label: result.value,
    };

    expect(timeFromDistanceSpeedByLabel['时间'], '200');
    expect(timeFromDistanceSpeedByLabel['时间 min'], startsWith('3.333'));
    expect(timeFromDistanceSpeedByLabel['输入来源'], '距离+速度');

    final reference = calculateTool(definition, {
      'speed': 10,
      'time': 20,
      'distance': 180,
    });
    final referenceByLabel = {
      for (final result in reference) result.label: result.value,
    };
    final referenceInsights = buildToolInsights(
      definition,
      {'speed': 10, 'time': 20, 'distance': 180},
      reference,
    ).join('\n');

    expect(referenceByLabel['距离'], '200');
    expect(referenceByLabel['输入来源'], '速度+时间，距离作参考');
    expect(referenceByLabel['距离差值'], '20');
    expect(referenceInsights, contains('和输入距离相差 20m'));

    final invalidResults = calculateTool(definition, {'speed': -1, 'time': 30});
    final invalidInsights =
        buildToolInsights(definition, {'speed': -1, 'time': 30}, invalidResults)
            .join('\n');

    expect(invalidResults.first.value, '无效');
    expect(invalidInsights, contains('速度、时间、距离至少填写两项'));

    final tooFewInputs = calculateTool(definition, {'speed': 5});
    expect(tooFewInputs.first.value, '无效');
  });

  test('free fall tool reports velocity variants and validates gravity', () {
    final definition = tool('free_fall');
    final values = <String, double>{'height': 20, 'g': 9.80665};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['落地时间'], startsWith('2.019'));
    expect(valuesByLabel['末速度'], startsWith('19.805'));
    expect(valuesByLabel['末速度 km/h'], startsWith('71.300'));
    expect(valuesByLabel['平均速度'], startsWith('9.902'));
    expect(valuesByLabel['初速度'], '0');
    expect(valuesByLabel['速度增量'], startsWith('19.805'));
    expect(valuesByLabel['高度'], '20');
    expect(valuesByLabel['重力加速度'], '9.80665');
    expect(valuesByLabel['运动方向'], '向下');
    expect(valuesByLabel, isNot(contains('冲击能量')));
    expect(insights, contains('自由落体按真空模型计算'));

    final impactValues = <String, double>{
      'height': 20,
      'initialSpeed': 5,
      'g': 9.80665,
      'mass': 2,
    };
    final impactResults = calculateTool(definition, impactValues);
    final impactByLabel = {
      for (final result in impactResults) result.label: result.value,
    };
    final impactInsights =
        buildToolInsights(definition, impactValues, impactResults).join('\n');

    expect(impactByLabel['落地时间'], startsWith('1.573'));
    expect(impactByLabel['末速度'], startsWith('20.427'));
    expect(impactByLabel['初速度'], '5');
    expect(impactByLabel['速度增量'], startsWith('15.427'));
    expect(impactByLabel['平均速度'], startsWith('12.713'));
    expect(impactByLabel['势能变化'], '392.266');
    expect(impactByLabel['初始动能'], '25');
    expect(impactByLabel['末端动能'], '417.266');
    expect(impactByLabel['冲击能量'], '417.266');
    expect(impactInsights, contains('初速度按向下为正'));

    final bufferedValues = <String, double>{
      'height': 20,
      'initialSpeed': 5,
      'g': 9.80665,
      'mass': 2,
      'bufferDistance': 0.05,
    };
    final bufferedResults = calculateTool(definition, bufferedValues);
    final bufferedByLabel = {
      for (final result in bufferedResults) result.label: result.value,
    };
    final bufferedInsights =
        buildToolInsights(definition, bufferedValues, bufferedResults)
            .join('\n');

    expect(bufferedByLabel['缓冲距离'], '0.05');
    expect(bufferedByLabel['缓冲平均力'], startsWith('8345.32'));
    expect(bufferedByLabel['缓冲平均减速度'], startsWith('4172.66'));
    expect(bufferedByLabel['缓冲减速度'], startsWith('425.492'));
    expect(bufferedInsights, contains('缓冲平均力按冲击能量/缓冲距离估算'));

    final bufferWithoutMass =
        calculateTool(definition, {'height': 20, 'bufferDistance': 0.05});
    final bufferWithoutMassByLabel = {
      for (final result in bufferWithoutMass) result.label: result.value,
    };
    final bufferWithoutMassInsights = buildToolInsights(
      definition,
      {'height': 20, 'bufferDistance': 0.05},
      bufferWithoutMass,
    ).join('\n');

    expect(bufferWithoutMassByLabel['缓冲平均力'], '无效');
    expect(bufferWithoutMassInsights, contains('缓冲平均力需要同时填写质量'));

    final upwardValues = <String, double>{
      'height': 10,
      'initialSpeed': -5,
      'g': 9.80665,
    };
    final upwardResults = calculateTool(definition, upwardValues);
    final upwardByLabel = {
      for (final result in upwardResults) result.label: result.value,
    };
    final upwardInsights =
        buildToolInsights(definition, upwardValues, upwardResults).join('\n');

    expect(upwardByLabel['运动方向'], '先上抛后下落');
    expect(upwardByLabel['落地时间'], startsWith('2.026'));
    expect(upwardInsights, contains('初速度为负'));

    final invalidResults = calculateTool(definition, {'height': 20, 'g': 0});
    final invalidMass = calculateTool(definition, {
      'height': 20,
      'g': 9.80665,
      'mass': -1,
    });
    final invalidMassByLabel = {
      for (final result in invalidMass) result.label: result.value,
    };

    expect(invalidResults.first.value, '无效');
    expect(invalidMassByLabel['冲击能量'], '无效');
  });

  test('work power tool reports energy units and work direction', () {
    final definition = tool('work_power');
    final values = <String, double>{'force': 100, 'distance': 5, 'time': 10};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['功'], '500');
    expect(valuesByLabel['平均功率'], '50');
    expect(valuesByLabel['功率 kW'], '0.05');
    expect(valuesByLabel['输入功率'], '50');
    expect(valuesByLabel['损耗功率'], '0');
    expect(valuesByLabel['表观功'], '500');
    expect(valuesByLabel['输入能量'], '500');
    expect(valuesByLabel['损耗能量'], '0');
    expect(valuesByLabel['Wh'], startsWith('0.138'));
    expect(valuesByLabel['kWh'], '0.000139');
    expect(valuesByLabel['机械马力'], startsWith('0.067'));
    expect(valuesByLabel['公制马力'], startsWith('0.067'));
    expect(valuesByLabel['力-位移夹角'], '0');
    expect(valuesByLabel['效率'], '100');
    expect(valuesByLabel['做功方向'], '正功');
    expect(insights, contains('功率为平均值'));

    final angledValues = <String, double>{
      'force': 100,
      'distance': 5,
      'time': 10,
      'angle': 60,
      'efficiency': 80,
    };
    final angledResults = calculateTool(definition, angledValues);
    final angledByLabel = {
      for (final result in angledResults) result.label: result.value,
    };

    expect(angledByLabel['功'], startsWith('250'));
    expect(angledByLabel['平均功率'], startsWith('25'));
    expect(angledByLabel['输入功率'], startsWith('31.25'));
    expect(angledByLabel['损耗功率'], startsWith('6.25'));
    expect(angledByLabel['输入能量'], startsWith('312.5'));
    expect(angledByLabel['损耗能量'], startsWith('62.5'));
    expect(angledByLabel['力-位移夹角'], '60');
    expect(angledByLabel['效率'], '80');

    final targetValues = <String, double>{
      'force': 100,
      'distance': 5,
      'time': 10,
      'targetPower': 100,
    };
    final targetResults = calculateTool(definition, targetValues);
    final targetByLabel = {
      for (final result in targetResults) result.label: result.value,
    };
    final targetInsights =
        buildToolInsights(definition, targetValues, targetResults).join('\n');

    expect(targetByLabel['目标功率'], '100');
    expect(targetByLabel['目标功率所需时间'], '5');
    expect(targetByLabel['目标功率所需力'], '200');
    expect(targetByLabel['目标功率偏差'], '-50');
    expect(targetInsights, contains('目标功率反推按平均功率计算'));

    final negativeValues = <String, double>{
      'force': 100,
      'distance': 5,
      'time': 10,
      'angle': 180,
      'efficiency': 80,
    };
    final negativeResults = calculateTool(definition, negativeValues);
    final negativeByLabel = {
      for (final result in negativeResults) result.label: result.value,
    };
    final negativeInsights =
        buildToolInsights(definition, negativeValues, negativeResults)
            .join('\n');

    expect(negativeByLabel['功'], startsWith('-500'));
    expect(negativeByLabel['平均功率'], startsWith('-50'));
    expect(negativeByLabel['做功方向'], '负功');
    expect(negativeInsights, contains('平均功率为负'));

    final invalidResults =
        calculateTool(definition, {'force': 100, 'distance': 5, 'time': 0});
    final invalidEfficiency = calculateTool(definition, {
      'force': 100,
      'distance': 5,
      'time': 10,
      'efficiency': 0,
    });
    final invalidEfficiencyByLabel = {
      for (final result in invalidEfficiency) result.label: result.value,
    };

    expect(invalidResults.first.value, '无效');
    expect(invalidEfficiencyByLabel['输入功率'], '无效');
  });

  test('kinetic energy tool reports energy breakdown and equivalent height',
      () {
    final definition = tool('kinetic_energy');
    final values = <String, double>{'mass': 2, 'speed': 5, 'height': 3};
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['总能量'], '83.8399');
    expect(valuesByLabel['动能'], '25');
    expect(valuesByLabel['势能'], '58.8399');
    expect(valuesByLabel['速度幅值'], '5');
    expect(valuesByLabel['速度'], '18');
    expect(valuesByLabel['单位质量动能'], '12.5');
    expect(valuesByLabel['等效高度'], startsWith('4.274'));
    expect(insights, contains('势能使用标准重力加速度'));

    final targetValues = <String, double>{
      'mass': 2,
      'speed': 5,
      'height': 3,
      'targetTotalEnergy': 100,
    };
    final targetResults = calculateTool(definition, targetValues);
    final targetByLabel = {
      for (final result in targetResults) result.label: result.value,
    };
    final targetInsights =
        buildToolInsights(definition, targetValues, targetResults).join('\n');

    expect(targetByLabel['目标总能量'], '100');
    expect(targetByLabel['目标能量所需速度'], startsWith('6.415'));
    expect(targetByLabel['目标能量所需高度'], startsWith('3.823'));
    expect(targetByLabel['目标能量差值'], startsWith('-16.160'));
    expect(targetInsights, contains('目标总能量反推只按动能和重力势能换算'));
    expect(targetInsights, contains('当前总能量与目标相差'));

    final invalidResults =
        calculateTool(definition, {'mass': -1, 'speed': 5, 'height': 3});

    expect(invalidResults.first.value, '无效');
  });

  test('density and concentration tools report practical unit conversions', () {
    final densityDefinition = tool('density');
    final densityValues = <String, double>{'mass': 7.8, 'volume': 0.001};
    final densityResults = calculateTool(densityDefinition, densityValues);
    final densityByLabel = {
      for (final result in densityResults) result.label: result.value,
    };
    final densityInsights =
        buildToolInsights(densityDefinition, densityValues, densityResults)
            .join('\n');

    expect(densityByLabel['密度'], '7800');
    expect(densityByLabel['g/cm³'], '7.8');
    expect(densityByLabel['kg/L'], '7.8');
    expect(densityByLabel['比容'], startsWith('0.000128'));
    expect(densityByLabel['质量'], '7.8');
    expect(densityByLabel['体积'], '1');
    expect(densityByLabel['体积 m³'], '0.001');
    expect(densityByLabel['输入来源'], '质量+体积');
    expect(densityInsights, contains('密度按均匀材料估算'));

    final volumeResults =
        calculateTool(densityDefinition, {'mass': 7.8, 'density': 7800});
    final volumeByLabel = {
      for (final result in volumeResults) result.label: result.value,
    };
    expect(volumeByLabel['体积'], '1');
    expect(volumeByLabel['体积 m³'], '0.001');
    expect(volumeByLabel['输入来源'], '质量+密度');

    final massResults =
        calculateTool(densityDefinition, {'volume': 0.002, 'density': 500});
    final massByLabel = {
      for (final result in massResults) result.label: result.value,
    };
    expect(massByLabel['质量'], '1');
    expect(massByLabel['g/cm³'], '0.5');
    expect(massByLabel['输入来源'], '体积+密度');

    final referenceResults = calculateTool(
        densityDefinition, {'mass': 7.8, 'volume': 0.001, 'density': 7900});
    final referenceByLabel = {
      for (final result in referenceResults) result.label: result.value,
    };
    final referenceInsights =
        buildToolInsights(densityDefinition, densityValues, referenceResults)
            .join('\n');
    expect(referenceByLabel['密度'], '7800');
    expect(referenceByLabel['输入来源'], '质量+体积，密度作参考');
    expect(referenceByLabel['密度差值'], '-100');
    expect(referenceInsights, contains('和输入密度相差 -100kg/m³'));

    final invalidDensity = calculateTool(densityDefinition, {'mass': 7.8});
    final invalidDensityInsights =
        buildToolInsights(densityDefinition, {'mass': 7.8}, invalidDensity)
            .join('\n');

    expect(invalidDensity.first.value, '无效');
    expect(invalidDensityInsights, contains('至少填写两项'));

    final concentrationDefinition = tool('concentration');
    final concentrationValues = <String, double>{
      'mass': 5,
      'volume': 0.5,
      'molarMass': 58.44,
    };
    final concentrationResults =
        calculateTool(concentrationDefinition, concentrationValues);
    final concentrationByLabel = {
      for (final result in concentrationResults) result.label: result.value,
    };

    expect(concentrationByLabel['质量浓度'], '10');
    expect(concentrationByLabel['mg/mL'], '10');
    expect(concentrationByLabel['mg/L'], '10000');
    expect(concentrationByLabel['摩尔浓度'], startsWith('0.171'));
    expect(concentrationByLabel['溶质物质的量'], startsWith('0.085'));
    expect(concentrationByLabel['溶质量'], '5');
    expect(concentrationByLabel['溶液体积'], '500');
    expect(concentrationByLabel['溶液体积 L'], '0.5');
    expect(concentrationByLabel['摩尔质量'], '58.44');
    expect(concentrationByLabel['输入来源'], '溶质量+体积');

    final volumeFromMassConcentration = calculateTool(concentrationDefinition, {
      'mass': 5,
      'massConcentration': 10,
      'molarMass': 58.44,
    });
    final volumeFromMassConcentrationByLabel = {
      for (final result in volumeFromMassConcentration)
        result.label: result.value,
    };
    expect(volumeFromMassConcentrationByLabel['溶液体积'], '500');
    expect(volumeFromMassConcentrationByLabel['摩尔浓度'], startsWith('0.171'));
    expect(volumeFromMassConcentrationByLabel['输入来源'], '溶质量+质量浓度');

    final massFromMolarity = calculateTool(concentrationDefinition, {
      'volume': 0.5,
      'molarMass': 58.44,
      'molarity': 0.2,
    });
    final massFromMolarityByLabel = {
      for (final result in massFromMolarity) result.label: result.value,
    };
    expect(massFromMolarityByLabel['质量浓度'], '11.688');
    expect(massFromMolarityByLabel['溶质量'], '5.844');
    expect(massFromMolarityByLabel['输入来源'], '体积+摩尔浓度');

    final molarMassFromConcentrations = calculateTool(concentrationDefinition, {
      'massConcentration': 10,
      'molarity': 0.2,
    });
    final molarMassFromConcentrationsByLabel = {
      for (final result in molarMassFromConcentrations)
        result.label: result.value,
    };
    expect(molarMassFromConcentrationsByLabel['摩尔质量'], '50');
    expect(molarMassFromConcentrationsByLabel['输入来源'], '质量浓度+摩尔浓度');

    final referenceConcentration = calculateTool(concentrationDefinition, {
      'mass': 5,
      'volume': 0.5,
      'molarMass': 58.44,
      'massConcentration': 9,
      'molarity': 0.18,
    });
    final referenceConcentrationByLabel = {
      for (final result in referenceConcentration) result.label: result.value,
    };
    final referenceConcentrationInsights = buildToolInsights(
      concentrationDefinition,
      concentrationValues,
      referenceConcentration,
    ).join('\n');
    expect(referenceConcentrationByLabel['质量浓度'], '10');
    expect(referenceConcentrationByLabel['输入来源'], '溶质量+体积，质量浓度、摩尔浓度作参考');
    expect(referenceConcentrationByLabel['质量浓度差值'], '1');
    expect(referenceConcentrationByLabel['摩尔浓度差值'], startsWith('-0.008'));
    expect(referenceConcentrationInsights, contains('质量浓度参考值与当前计算相差 1g/L'));

    final invalidConcentration = calculateTool(
        concentrationDefinition, {'mass': 5, 'volume': 0.5, 'molarMass': 0});
    final invalidConcentrationInsights = buildToolInsights(
      concentrationDefinition,
      {'mass': 5, 'volume': 0.5, 'molarMass': 0},
      invalidConcentration,
    ).join('\n');

    expect(invalidConcentration.first.value, '无效');
    expect(invalidConcentrationInsights, contains('至少填写两项'));
  });

  test('ideal gas heat wave half life and ph report richer science outputs',
      () {
    final gasDefinition = tool('ideal_gas');
    final gasValues = <String, double>{'n': 1, 'temp': 298.15, 'volume': 24};
    final gasResults = calculateTool(gasDefinition, gasValues);
    final gasByLabel = {
      for (final result in gasResults) result.label: result.value,
    };

    expect(gasByLabel['压力'], startsWith('103.289'));
    expect(gasByLabel['压力 atm'], startsWith('1.019'));
    expect(gasByLabel['压力 Pa'], startsWith('103289.876'));
    expect(gasByLabel['体积'], '0.024');
    expect(gasByLabel['温度'], '25');
    expect(gasByLabel['温度 K'], '298.15');
    expect(gasByLabel['物质的量'], '1');
    expect(gasByLabel['摩尔体积'], '24');
    expect(gasByLabel['分子数'], startsWith('6.022141e+23'));
    expect(gasByLabel['输入来源'], '物质的量+温度+体积');

    final gasAmountResults = calculateTool(gasDefinition, {
      'pressure': 101.325,
      'temp': 273.15,
      'volume': 22.41396954,
    });
    final gasAmountByLabel = {
      for (final result in gasAmountResults) result.label: result.value,
    };
    expect(gasAmountByLabel['物质的量'], startsWith('1'));
    expect(gasAmountByLabel['输入来源'], '压力+温度+体积');

    final gasTempResults = calculateTool(gasDefinition, {
      'pressure': 101.325,
      'n': 1,
      'volume': 24,
    });
    final gasTempByLabel = {
      for (final result in gasTempResults) result.label: result.value,
    };
    expect(gasTempByLabel['温度 K'], startsWith('292.478'));
    expect(gasTempByLabel['输入来源'], '压力+物质的量+体积');

    final gasVolumeResults = calculateTool(gasDefinition, {
      'pressure': 101.325,
      'n': 1,
      'temp': 298.15,
    });
    final gasVolumeByLabel = {
      for (final result in gasVolumeResults) result.label: result.value,
    };
    expect(gasVolumeByLabel['体积 L'], startsWith('24.465'));
    expect(gasVolumeByLabel['输入来源'], '压力+物质的量+温度');

    final referenceGasResults = calculateTool(gasDefinition, {
      'n': 1,
      'temp': 298.15,
      'volume': 24,
      'pressure': 101.325,
    });
    final referenceGasByLabel = {
      for (final result in referenceGasResults) result.label: result.value,
    };
    final referenceGasInsights = buildToolInsights(
      gasDefinition,
      {'n': 1, 'temp': 298.15, 'volume': 24, 'pressure': 101.325},
      referenceGasResults,
    ).join('\n');
    expect(referenceGasByLabel['输入来源'], '物质的量+温度+体积，压力作参考');
    expect(referenceGasByLabel['压力差值'], startsWith('1.964'));
    expect(referenceGasInsights, contains('压力参考值与当前计算相差'));

    final invalidGas = calculateTool(gasDefinition, {'pressure': 101.325});
    final invalidGasInsights = buildToolInsights(
      gasDefinition,
      {'pressure': 101.325},
      invalidGas,
    ).join('\n');
    expect(invalidGas.first.value, '无效');
    expect(invalidGasInsights, contains('至少填写三项'));

    final heatResults =
        calculateTool(tool('heat'), {'mass': 1, 'specific': 4186, 'delta': 10});
    final heatByLabel = {
      for (final result in heatResults) result.label: result.value,
    };

    expect(heatByLabel['热量'], '41860');
    expect(heatByLabel['kJ'], '41.86');
    expect(heatByLabel['Wh'], startsWith('11.627'));
    expect(heatByLabel['kcal'], startsWith('10.004'));
    expect(heatByLabel['热过程'], '吸热');
    expect(heatByLabel['质量'], '1');
    expect(heatByLabel['比热容'], '4186');
    expect(heatByLabel['温度变化'], '10');
    expect(heatByLabel['输入来源'], '质量+比热容+温度变化');

    final deltaFromHeat = calculateTool(tool('heat'), {
      'mass': 1,
      'specific': 4186,
      'heat': 41860,
    });
    final deltaFromHeatByLabel = {
      for (final result in deltaFromHeat) result.label: result.value,
    };
    expect(deltaFromHeatByLabel['温度变化'], '10');
    expect(deltaFromHeatByLabel['输入来源'], '热量+质量+比热容');

    final massFromHeat = calculateTool(tool('heat'), {
      'heat': 41860,
      'specific': 4186,
      'delta': 10,
    });
    final massFromHeatByLabel = {
      for (final result in massFromHeat) result.label: result.value,
    };
    expect(massFromHeatByLabel['质量'], '1');
    expect(massFromHeatByLabel['输入来源'], '热量+比热容+温度变化');

    final coolingHeat =
        calculateTool(tool('heat'), {'mass': 2, 'specific': 4186, 'delta': -5});
    final coolingHeatByLabel = {
      for (final result in coolingHeat) result.label: result.value,
    };
    final coolingHeatInsights = buildToolInsights(tool('heat'),
            {'mass': 2, 'specific': 4186, 'delta': -5}, coolingHeat)
        .join('\n');
    expect(coolingHeatByLabel['热量'], '-41860');
    expect(coolingHeatByLabel['热过程'], '放热');
    expect(coolingHeatInsights, contains('热量为负'));

    final referenceHeat = calculateTool(tool('heat'), {
      'mass': 1,
      'specific': 4186,
      'delta': 10,
      'heat': 40000,
    });
    final referenceHeatByLabel = {
      for (final result in referenceHeat) result.label: result.value,
    };
    final referenceHeatInsights = buildToolInsights(
      tool('heat'),
      {'mass': 1, 'specific': 4186, 'delta': 10, 'heat': 40000},
      referenceHeat,
    ).join('\n');
    expect(referenceHeatByLabel['输入来源'], '质量+比热容+温度变化，热量作参考');
    expect(referenceHeatByLabel['热量差值'], '1860');
    expect(referenceHeatInsights, contains('热量参考值与当前计算相差 1860J'));

    final invalidHeat =
        calculateTool(tool('heat'), {'mass': 1, 'specific': 4186});
    final invalidHeatInsights = buildToolInsights(
      tool('heat'),
      {'mass': 1, 'specific': 4186},
      invalidHeat,
    ).join('\n');
    expect(invalidHeat.first.value, '无效');
    expect(invalidHeatInsights, contains('至少填写三项'));

    final waveResults =
        calculateTool(tool('wavelength'), {'speed': 343, 'frequency': 1000});
    final waveByLabel = {
      for (final result in waveResults) result.label: result.value,
    };

    expect(waveByLabel['波长'], '0.343');
    expect(waveByLabel['周期'], '0.001');
    expect(waveByLabel['频率 kHz'], '1');
    expect(waveByLabel['波速'], '343');
    expect(waveByLabel['波速 km/h'], '1234.8');
    expect(waveByLabel['波数'], startsWith('2.915'));
    expect(waveByLabel['角频率'], startsWith('6283.185'));
    expect(waveByLabel['输入来源'], '波速+频率');

    final frequencyFromWavelength =
        calculateTool(tool('wavelength'), {'speed': 343, 'wavelength': 0.343});
    final frequencyFromWavelengthByLabel = {
      for (final result in frequencyFromWavelength) result.label: result.value,
    };
    expect(frequencyFromWavelengthByLabel['频率'], '1000');
    expect(frequencyFromWavelengthByLabel['输入来源'], '波速+波长');

    final speedFromWavelength = calculateTool(
        tool('wavelength'), {'frequency': 2000, 'wavelength': 0.1715});
    final speedFromWavelengthByLabel = {
      for (final result in speedFromWavelength) result.label: result.value,
    };
    expect(speedFromWavelengthByLabel['波速'], '343');
    expect(speedFromWavelengthByLabel['输入来源'], '频率+波长');

    final referenceWave = calculateTool(tool('wavelength'), {
      'speed': 343,
      'frequency': 1000,
      'wavelength': 0.34,
    });
    final referenceWaveByLabel = {
      for (final result in referenceWave) result.label: result.value,
    };
    final referenceWaveInsights = buildToolInsights(
      tool('wavelength'),
      {'speed': 343, 'frequency': 1000, 'wavelength': 0.34},
      referenceWave,
    ).join('\n');
    expect(referenceWaveByLabel['输入来源'], '波速+频率，波长作参考');
    expect(referenceWaveByLabel['波长差值'], '0.003');
    expect(referenceWaveInsights, contains('波长参考值与当前计算相差 0.003m'));

    final invalidWave = calculateTool(tool('wavelength'), {'speed': 343});
    final invalidWaveInsights = buildToolInsights(
      tool('wavelength'),
      {'speed': 343},
      invalidWave,
    ).join('\n');
    expect(invalidWave.first.value, '无效');
    expect(invalidWaveInsights, contains('至少填写两项'));

    final halfLifeResults = calculateTool(
        tool('half_life'), {'initial': 100, 'half': 6, 'time': 18});
    final halfLifeByLabel = {
      for (final result in halfLifeResults) result.label: result.value,
    };

    expect(halfLifeByLabel['剩余量'], '12.5');
    expect(halfLifeByLabel['剩余比例'], '12.5');
    expect(halfLifeByLabel['衰减量'], '87.5');
    expect(halfLifeByLabel['衰减比例'], '87.5');
    expect(halfLifeByLabel['经历半衰期'], '3');
    expect(halfLifeByLabel['衰变常数'], startsWith('0.115'));
    expect(halfLifeByLabel['输入来源'], '初始量+半衰期+经过时间');

    final timeFromRemaining = calculateTool(
        tool('half_life'), {'initial': 100, 'half': 6, 'remaining': 25});
    final timeFromRemainingByLabel = {
      for (final result in timeFromRemaining) result.label: result.value,
    };
    final timeFromRemainingInsights = buildToolInsights(
      tool('half_life'),
      {'initial': 100, 'half': 6, 'remaining': 25},
      timeFromRemaining,
    ).join('\n');
    expect(timeFromRemainingByLabel['经过时间'], '12');
    expect(timeFromRemainingByLabel['剩余比例'], '25');
    expect(timeFromRemainingByLabel['输入来源'], '初始量+半衰期+剩余量');
    expect(timeFromRemainingInsights, contains('当前按 初始量+半衰期+剩余量 计算'));

    final timeFromRatio = calculateTool(
        tool('half_life'), {'initial': 100, 'half': 6, 'remainingRatio': 25});
    final timeFromRatioByLabel = {
      for (final result in timeFromRatio) result.label: result.value,
    };
    expect(timeFromRatioByLabel['经过时间'], '12');
    expect(timeFromRatioByLabel['剩余量'], '25');
    expect(timeFromRatioByLabel['输入来源'], '初始量+半衰期+剩余比例');

    final halfFromRemaining = calculateTool(
        tool('half_life'), {'initial': 100, 'time': 12, 'remaining': 25});
    final halfFromRemainingByLabel = {
      for (final result in halfFromRemaining) result.label: result.value,
    };
    expect(halfFromRemainingByLabel['半衰期'], '6');
    expect(halfFromRemainingByLabel['输入来源'], '初始量+经过时间+剩余量');

    final referenceHalfLife = calculateTool(tool('half_life'), {
      'initial': 100,
      'half': 6,
      'time': 18,
      'remaining': 10,
      'remainingRatio': 10,
    });
    final referenceHalfLifeByLabel = {
      for (final result in referenceHalfLife) result.label: result.value,
    };
    final referenceHalfLifeInsights = buildToolInsights(
      tool('half_life'),
      {
        'initial': 100,
        'half': 6,
        'time': 18,
        'remaining': 10,
        'remainingRatio': 10,
      },
      referenceHalfLife,
    ).join('\n');
    expect(referenceHalfLifeByLabel['输入来源'], '初始量+半衰期+经过时间，剩余量、剩余比例作参考');
    expect(referenceHalfLifeByLabel['剩余量差值'], '2.5');
    expect(referenceHalfLifeByLabel['剩余比例差值'], '2.5');
    expect(referenceHalfLifeInsights, contains('剩余量参考值与当前计算相差 2.5'));
    expect(referenceHalfLifeInsights, contains('剩余比例参考值与当前计算相差 2.5%'));

    final invalidHalfLife =
        calculateTool(tool('half_life'), {'initial': 100, 'half': 6});
    final invalidHalfLifeInsights = buildToolInsights(
      tool('half_life'),
      {'initial': 100, 'half': 6},
      invalidHalfLife,
    ).join('\n');
    expect(invalidHalfLife.first.value, '无效');
    expect(invalidHalfLifeInsights, contains('至少填写三项'));

    final phResults = calculateTool(tool('ph'), {'h': 0.000001});
    final phByLabel = {
      for (final result in phResults) result.label: result.value,
    };
    final phInsights = buildToolInsights(tool('ph'), {'h': 0.0000000000001},
        calculateTool(tool('ph'), {'h': 0.0000000000001})).join('\n');

    expect(phByLabel['pH'], '6');
    expect(phByLabel['pOH'], '8');
    expect(phByLabel['[H+]'], '0.000001');
    expect(phByLabel['[OH-]'], startsWith('1e-8'));
    expect(phByLabel['[H+] nmol/L'], '1000');
    expect(phByLabel['[OH-] nmol/L'], '10');
    expect(phByLabel['酸碱性'], '酸性');
    expect(phByLabel['输入来源'], '[H+]');
    expect(phInsights, contains('pH 极端'));

    final targetPh = calculateTool(tool('ph'), {'h': 0.000001, 'targetPh': 7});
    final targetPhByLabel = {
      for (final result in targetPh) result.label: result.value,
    };
    final targetPhInsights =
        buildToolInsights(tool('ph'), {'h': 0.000001, 'targetPh': 7}, targetPh)
            .join('\n');

    expect(targetPhByLabel['目标pH'], '7');
    expect(targetPhByLabel['目标[H+]'], startsWith('1e-7'));
    expect(targetPhByLabel['目标[OH-]'], startsWith('1e-7'));
    expect(targetPhByLabel['pH差值'], '-1');
    expect(targetPhInsights, contains('当前 pH 与目标 pH 相差 -1'));
  });

  test('ph tool accepts ph and hydroxide concentration inputs', () {
    final definition = tool('ph');
    final direct = calculateTool(definition, {'ph': 9});
    final directByLabel = {
      for (final result in direct) result.label: result.value,
    };
    final hydroxide = calculateTool(definition, {'oh': 0.001});
    final hydroxideByLabel = {
      for (final result in hydroxide) result.label: result.value,
    };
    final invalid = calculateTool(definition, {'oh': 0});
    final insights = buildToolInsights(
            definition, {'ph': 7.1}, calculateTool(definition, {'ph': 7.1}))
        .join('\n');

    expect(directByLabel['pH'], '9');
    expect(directByLabel['pOH'], '5');
    expect(directByLabel['[H+]'], '1e-9');
    expect(directByLabel['[OH-]'], '0.00001');
    expect(directByLabel['酸碱性'], '碱性');
    expect(directByLabel['输入来源'], 'pH');

    expect(hydroxideByLabel['pH'], '11');
    expect(hydroxideByLabel['pOH'], '3');
    expect(hydroxideByLabel['[H+]'], startsWith('1e-11'));
    expect(hydroxideByLabel['[OH-]'], startsWith('0.001'));
    expect(hydroxideByLabel['输入来源'], '[OH-]');

    expect(invalid.first.value, '无效');
    expect(insights, contains('当前以 pH 作为输入来源'));
  });

  test('common unit converters expose supported pasted units as outputs', () {
    Map<String, String> values(String toolId, double value) => {
          for (final result in calculateTool(tool(toolId), {'value': value}))
            result.label: result.value,
        };

    final length = values('length', 1609.344);
    final area = values('area', 1);
    final volume = values('volume', 1);
    final mass = values('mass', 1);
    final pressure = values('pressure', 101325);
    final voltage = values('voltage', 1000000);
    final frequency = values('frequency', 1);
    final terahertz = values('frequency', 1000000000000);
    final torque = values('torque_unit', 1);
    final speed = values('speed', 1);
    final acceleration = values('acceleration', 1);
    final flow = values('flow_unit', 60);
    final power = values('power_unit', 1000);
    final force = values('force_unit', 1);
    final angle = values('angle_unit', 180);
    final temperature = values('temperature', 25);

    expect(length['km'], '1.609344');
    expect(length['Mm'], '0.001609');
    expect(length['μm'], '1.609344e+9');
    expect(length['nm'], '1.609344e+12');
    expect(length['mi'], '1');
    expect(area['km²'], '0.000001');
    expect(area['ha'], '0.0001');
    expect(area['亩'], '0.0015');
    expect(area['acre'], startsWith('0.000247'));
    expect(area['in²'], startsWith('1550'));
    expect(area['yd²'], startsWith('1.19599'));
    expect(volume['cm³'], '1000000');
    expect(volume['mm³'], '1e+9');
    expect(volume['gal'], startsWith('264.172'));
    expect(volume['qt'], startsWith('1056.688'));
    expect(volume['tbsp'], startsWith('67628.045'));
    expect(volume['tsp'], startsWith('202884.136'));
    expect(mass['Mg'], '0.001');
    expect(mass['t'], '0.001');
    expect(mass['oz'], startsWith('35.273'));
    expect(mass['斤'], '2');
    expect(pressure['mPa'], '101325000');
    expect(pressure['atm'], '1');
    expect(pressure['GPa'], '0.000101');
    expect(pressure['mbar'], '1013.25');
    expect(pressure['mmHg'], startsWith('760'));
    expect(voltage['MV'], '1');
    expect(voltage['mV'], '1e+9');
    expect(frequency['mHz'], '1000');
    expect(frequency['kHz'], '0.001');
    expect(terahertz['GHz'], '1000');
    expect(terahertz['THz'], '1');
    expect(power['mW'], '1000000');
    expect(power['kW'], '1');
    expect(power['MW'], '0.001');
    expect(power['dBW'], '30');
    expect(force['mN'], '1000');
    expect(force['MN'], '0.000001');
    expect(speed['m/min'], '60');
    expect(speed['cm/s'], '100');
    expect(speed['kn'], startsWith('1.94384'));
    expect(acceleration['cm/s²'], '100');
    expect(acceleration['Gal'], '100');
    expect(torque['kN·m'], '0.001');
    expect(torque['mN·m'], '1000');
    expect(torque['N·mm'], '1000');
    expect(torque['lbf·in'], startsWith('8.850'));
    expect(torque['ozf·in'], startsWith('141.612'));
    expect(flow['L/h'], '3600');
    expect(flow['mL/min'], '60000');
    expect(flow['L/s'], '1');
    expect(flow['m³/min'], '0.06');
    expect(flow['m³/s'], '0.001');
    expect(flow['CFM'], startsWith('2.11888'));
    expect(angle['rad'], startsWith('3.14159'));
    expect(angle['turn'], '0.5');
    expect(angle['grad'], '200');
    expect(angle['arcmin'], '10800');
    expect(angle['arcsec'], '648000');
    expect(temperature['°R'], '536.67');
  });

  test('time energy and electrical converters expose fine grained outputs', () {
    Map<String, String> values(String toolId, double value) => {
          for (final result in calculateTool(tool(toolId), {'value': value}))
            result.label: result.value,
        };

    final time = values('time_unit', 1);
    final energy = values('energy_unit', 3600000);
    final current = values('current_unit', 0.000001);
    final resistance = values('resistance_unit', 1);
    final capacitance = values('capacitance_unit', 0.001);
    final inductance = values('inductance_unit', 0.001);

    expect(time['ms'], '1000');
    expect(time['μs'], '1000000');
    expect(time['ns'], '1e+9');
    expect(time['week'], '0.000002');
    expect(energy['kcal'], startsWith('860.420'));
    expect(energy['BTU'], startsWith('3412.141'));
    expect(energy['eV'], startsWith('2.246943e+25'));
    expect(energy['kWh'], '1');
    expect(energy['MWh'], '0.001');
    expect(energy['mWh'], '1000000');
    expect(energy['度'], '1');
    expect(current['μA'], '1');
    expect(current['nA'], '1000');
    expect(current['kA'], '1e-9');
    expect(current['MA'], '1e-12');
    expect(resistance['μΩ'], '1000000');
    expect(resistance['mΩ'], '1000');
    expect(resistance['kΩ'], '0.001');
    expect(resistance['GΩ'], '1e-9');
    expect(capacitance['mF'], '1');
    expect(capacitance['μF'], '1000');
    expect(capacitance['MF'], '1e-9');
    expect(inductance['kH'], '0.000001');
    expect(inductance['mH'], '1');
    expect(inductance['μH'], '1000');
    expect(inductance['nH'], '1000000');
    expect(inductance['pH'], '1e+9');
    expect(inductance['MH'], '1e-9');
  });

  test('section property tool exposes inertia and section modulus', () {
    final definition = tool('section_area');
    final values = <String, double>{
      'diameter': 20,
      'outer': 30,
      'inner': 20,
      'width': 40,
      'height': 10,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['圆截面积'], startsWith('314.159'));
    expect(valuesByLabel['圆惯性矩 I'], startsWith('7853.981'));
    expect(valuesByLabel['圆截面模量 Z'], startsWith('785.398'));
    expect(valuesByLabel['圆回转半径'], '5');
    expect(valuesByLabel['圆周长'], startsWith('62.831'));
    expect(valuesByLabel['管截面积'], startsWith('392.699'));
    expect(valuesByLabel['管惯性矩 I'], startsWith('31906.800'));
    expect(valuesByLabel['管截面模量 Z'], startsWith('2127.120'));
    expect(valuesByLabel['管回转半径'], startsWith('9.013'));
    expect(valuesByLabel['管壁厚'], '5');
    expect(valuesByLabel['管平均直径'], '25');
    expect(valuesByLabel['空心率'], startsWith('44.444'));
    expect(valuesByLabel['矩形截面积'], '400');
    expect(valuesByLabel['矩形 Ix'], startsWith('3333.333'));
    expect(valuesByLabel['矩形 Iy'], startsWith('53333.333'));
    expect(valuesByLabel['矩形 Zx/Zy'], startsWith('666.666'));
    expect(valuesByLabel['矩形 rx/ry'], startsWith('2.886'));
    expect(valuesByLabel['强轴'], 'y轴');
    expect(valuesByLabel['弱轴'], 'x轴');
    expect(insights, contains('矩形强轴为 y轴'));
    expect(insights, contains('理想几何'));
  });

  test('section property tool rejects invalid tube and dimension inputs', () {
    final definition = tool('section_area');
    final values = <String, double>{
      'diameter': 20,
      'outer': 30,
      'inner': 30,
      'width': 40,
      'height': 10,
    };
    final results = calculateTool(definition, values);
    final valuesByLabel = {
      for (final result in results) result.label: result.value,
    };
    final insights = buildToolInsights(definition, values, results).join('\n');

    expect(valuesByLabel['圆截面积'], '无效');
    expect(valuesByLabel['管截面积'], '无效');
    expect(valuesByLabel['管壁厚'], '无效');
    expect(valuesByLabel['强轴'], '无效');
    expect(insights, contains('管内径不能为负且必须小于外径'));
    expect(insights, contains('管截面内径必须小于外径'));
  });

  test('all numeric tools calculate with default inputs', () {
    for (final item in toolCatalog.where((tool) => !tool.usesTextDetail)) {
      final values = {
        for (final input in item.inputs) input.key: input.defaultValue ?? 0,
      };
      final results = calculateTool(item, values);
      expect(results, isNotEmpty, reason: item.id);
    }
  });
}
