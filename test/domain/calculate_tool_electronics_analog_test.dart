import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

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
}
