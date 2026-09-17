import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

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
}
