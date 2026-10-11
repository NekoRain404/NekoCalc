import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

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

  // 中文：**这里原先还有一条 `data_size` 逐格输出的测试**（`data size converter exposes decimal
  //       binary and bit outputs`）。它随工具与被删掉的换算数学一起删除：`ToolKind.dataSize`
  //       分支、`calculate_tool_units.dart` 里那张 1024 进制表与 `UnitConverter` 都已不存在，
  //       没有一条断言还能到达被删的数学；单位换算今天走引擎自己的 `to` 翻译层。
  // English: **a per-cell `data_size` test used to stand here** (`data size converter exposes decimal
  //          binary and bit outputs`). It went with the tool and the deleted conversion maths: the
  //          `ToolKind.dataSize` branch, the 1024-based table in `calculate_tool_units.dart` and
  //          `UnitConverter` no longer exist, so no assertion could still reach the deleted maths; unit
  //          conversion is the engine's own `to` translation today.

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
}
