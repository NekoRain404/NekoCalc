import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/calculate_tool.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_insights.dart';

void main() {
  ToolDefinition tool(String id) =>
      toolCatalog.firstWhere((item) => item.id == id);

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
}
