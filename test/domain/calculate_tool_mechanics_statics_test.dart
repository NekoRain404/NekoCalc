import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

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
}
