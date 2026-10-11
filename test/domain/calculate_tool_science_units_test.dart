import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_capabilities.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

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

  // 中文：**这里原先还有两条逐单位换算的测试**（`common unit converters expose supported pasted
  //       units as outputs` 与 `time energy and electrical converters expose fine grained outputs`），
  //       覆盖 length/area/volume/…/flow 那 21 个工具的每一格输出。**它们随工具与被删掉的换算数学
  //       一起删除了**：那 21 个 `ToolKind` 分支、`calculate_tool_units.dart` 里的换算表与
  //       `UnitConverter` 都已不存在（"没有任何地方还调用它们"的检索证据写在当轮报告里），
  //       没有一条断言还能到达被删的数学。单位换算今天由引擎自己的 `to` 翻译层承担，
  //       那条路径的覆盖在计算页与 `unit_convert` 卡那几条测试里。
  // English: **two per-unit converter tests used to stand here** (`common unit converters expose
  //          supported pasted units as outputs` and `time energy and electrical converters expose fine
  //          grained outputs`), covering every output cell of the 21 tools from length to flow. **They
  //          went with the tools and the deleted conversion maths**: those 21 `ToolKind` branches, the
  //          factor tables in `calculate_tool_units.dart` and `UnitConverter` no longer exist (the
  //          greps proving nothing calls them are in that round's report), so no assertion could still
  //          reach the deleted maths. Unit conversion is the engine's own `to` translation today, and
  //          that path is covered by the calculator-page and `unit_convert`-card tests.
  test('temperature keeps its four scales as outputs', () {
    Map<String, String> values(String toolId, double value) => {
          for (final result in calculateTool(tool(toolId), {'value': value}))
            result.label: result.value,
        };

    final temperature = values('temperature', 25);
    expect(temperature['℃'], '25');
    expect(temperature['℉'], '77');
    expect(temperature['K'], '298.15');
    expect(temperature['°R'], '536.67');
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
