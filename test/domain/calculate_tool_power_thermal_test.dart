import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

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
}
