import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tools_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';

void main() {
  late ToolsController controller;

  setUp(() {
    controller = _controller();
  });

  test('search matches keyboard-friendly engineering unit aliases', () {
    // 中文：**这一条里的查询几乎全换过。** 原先量的是 21 个逐单位换算工具的键盘别名
    //       （`millifarad`、`arc second`、`gon`、`megahenry`、`Galileo`、`knots`、`nmm`、
    //       `kN m`、`lbf in`、`ozf in`…），那些工具并成 `unit_convert` 一张卡之后一个都搜不到。
    //       换上的每一条都量过：单位记号仍然搜得到，但命中的是**别的工具输入框里的同一个记号**
    //       （`mm²` 在 `wire_voltage_drop`、`μF` 在 `timer_555`、`kΩ` 在 `rc_filter` 的输入单位里），
    //       温度那一条照旧命中 `temperature`。
    // English: **nearly every query here was replaced.** It used to measure the keyboard aliases of the
    //          21 per-unit converters (`millifarad`, `arc second`, `gon`, `megahenry`, `Galileo`,
    //          `knots`, `nmm`, `kN m`, `lbf in`, `ozf in`, …), none of which resolves after those tools
    //          folded into the `unit_convert` card. Every replacement was measured: unit tokens still
    //          match, but against **the same token in another tool's input units** (`mm²` in
    //          `wire_voltage_drop`, `μF` in `timer_555`, `kΩ` in `rc_filter`'s units), and the
    //          temperature one still hits `temperature`.
    final area = controller.searchTools('mm2');
    final temperature = controller.searchTools('degc');
    final capacitance = controller.searchTools('uF');
    final resistance = controller.searchTools('kohm');
    final acceleration = controller.searchTools('m/s2');
    final inertia = controller.searchTools('cm4');
    final inchInertia = controller.searchTools('in^4');

    expect(area.first.tool.id, 'wire_voltage_drop');
    expect(area.map((result) => result.tool.id), contains('stress_strain'));
    expect(
        temperature.map((result) => result.tool.id), contains('temperature'));
    expect(capacitance.first.tool.id, 'timer_555');
    expect(capacitance.map((result) => result.tool.id),
        contains('capacitor_charge'));
    expect(resistance.first.tool.id, 'rc_filter');
    expect(
        acceleration.map((result) => result.tool.id), contains('force'));
    expect(acceleration.map((result) => result.tool.id), contains('free_fall'));
    expect(inertia.first.tool.id, 'section_area');
    expect(inertia.map((result) => result.tool.id), contains('beam_bending'));
    expect(
        inchInertia.map((result) => result.tool.id), contains('beam_bending'));
    expect(
        inchInertia.map((result) => result.tool.id), contains('section_area'));
  });

  test('search matches mechanical transmission reverse planning terms', () {
    final targetOutputRpm = controller.searchTools('target output rpm');
    final requiredGearTeeth = controller.searchTools('反推齿数');
    final targetPowerTorque = controller.searchTools('target power torque');
    final requiredTorque = controller.searchTools('所需扭矩');
    final targetSpringForce = controller.searchTools('target spring force');
    final requiredSpringTravel = controller.searchTools('反推弹簧变形');
    final targetCylinderForce = controller.searchTools('气缸目标力');
    final requiredAcceleration = controller.searchTools('反推加速度');
    final targetPulleySpeed =
        controller.searchTools('target pulley output rpm');
    final targetFeedRate = controller.searchTools('目标线速度');

    expect(targetOutputRpm.first.tool.id, 'gear_ratio');
    expect(requiredGearTeeth.first.tool.id, 'gear_ratio');
    expect(targetPowerTorque.first.tool.id, 'torque_power');
    expect(requiredTorque.first.tool.id, 'torque_power');
    expect(targetSpringForce.first.tool.id, 'spring');
    expect(requiredSpringTravel.first.tool.id, 'spring');
    expect(targetCylinderForce.first.tool.id, 'cylinder');
    expect(requiredAcceleration.first.tool.id, 'force');
    expect(targetPulleySpeed.first.tool.id, 'pulley_ratio');
    expect(targetFeedRate.first.tool.id, 'screw_lead');
  });

  test('search matches common unit converter names and synonyms', () {
    // 中文：**这一条也只剩温度那一台的别名还有工具可命中。** 原先它逐条量 21 个换算工具的英文
    //       名字与同义词（`psi`、`millipascal`、`acre`、`MWh`、`horsepower`、`CFM`…），那些工具
    //       并成 `unit_convert` 一张卡之后一条都不再命中；留下的八条温度同义词今天各只命中
    //       `temperature` 一个工具，另加那张卡自己的 `unit conversion`。
    // English: **here too, only the temperature converter still has a tool for its aliases to hit.**
    //          This test used to measure the English names and synonyms of the 21 converters one by one
    //          (`psi`, `millipascal`, `acre`, `MWh`, `horsepower`, `CFM`, …); none resolves after those
    //          tools folded into the `unit_convert` card. The eight temperature synonyms left each hit
    //          `temperature` alone today, plus the card's own `unit conversion`.
    final temperature = controller.searchTools('fahrenheit');
    final rankine = controller.searchTools('rankine');
    final celsius = controller.searchTools('celsius');
    final kelvin = controller.searchTools('kelvin');
    final degf = controller.searchTools('degf');
    final celsiusChinese = controller.searchTools('摄氏度');
    final fahrenheitChinese = controller.searchTools('华氏度');
    final rankineChinese = controller.searchTools('兰氏度');
    final unitConversion = controller.searchTools('unit conversion');

    expect(temperature.first.tool.id, 'temperature');
    expect(rankine.first.tool.id, 'temperature');
    expect(celsius.first.tool.id, 'temperature');
    expect(kelvin.first.tool.id, 'temperature');
    expect(degf.first.tool.id, 'temperature');
    expect(celsiusChinese.first.tool.id, 'temperature');
    expect(fahrenheitChinese.first.tool.id, 'temperature');
    expect(rankineChinese.first.tool.id, 'temperature');
    expect(unitConversion.first.tool.id, 'unit_convert');
  });

  // 中文：**这里原先还有一条 `search matches fine grained electrical and time unit aliases`**，
  //       逐条量 `nanoseconds`、`microseconds`、`weeks`、`nA`、`kiloamp`、`megaamp`、`microohm`、
  //       `milliohm`、`mΩ`、`gigaohm`、`nanohenry`、`picohenry` 这十二条电学/时间单位别名。
  //       **整条随工具删除**：它量的 12 个工具（`time_unit`、`current_unit`、`resistance_unit`、
  //       `inductance_unit`）全部并进了 `unit_convert` 那张卡，12 条查询里 11 条今天一个结果都
  //       没有（实测：`nanohenry` 0、`mΩ` 0、`nanoseconds` 0…），而 `nA` 会命中 12 个不相干的
  //       工具（`nA` 是 `μA` 之类记号里的子串），所以"空结果"这件事在这里没法统一断言。
  //       单位记号本身仍可搜——搜的是计算页那个 `CONV` 面板，不是工具目录。
  // English: **a `search matches fine grained electrical and time unit aliases` test used to stand
  //          here**, measuring the twelve electrical/time unit aliases `nanoseconds`, `microseconds`,
  //          `weeks`, `nA`, `kiloamp`, `megaamp`, `microohm`, `milliohm`, `mΩ`, `gigaohm`, `nanohenry`,
  //          `picohenry`. **The whole test went with the tools**: all twelve tools it measured
  //          (`time_unit`, `current_unit`, `resistance_unit`, `inductance_unit`) folded into the
  //          `unit_convert` card, 11 of the 12 queries return nothing today (measured: `nanohenry` 0,
  //          `mΩ` 0, `nanoseconds` 0, …), and `nA` hits twelve unrelated tools (it is a substring of
  //          tokens such as `μA`), so "empty result" cannot be asserted uniformly here. Unit tokens are
  //          still searchable — inside the calculator's `CONV` sheet, not in the tools catalogue.

  test('search matches signal amplitude and resonance engineering terms', () {
    final vppToVrms = controller.searchTools('vpp to vrms');
    final dbmToVoltage = controller.searchTools('dbm to vrms');
    final qFactor = controller.searchTools('q factor');
    final bandwidth = controller.searchTools('3db bandwidth');
    final halfPower = controller.searchTools('半功率点');
    final opAmpTargetGain = controller.searchTools('target op amp gain');
    final gbw = controller.searchTools('gain bandwidth product');
    final slewRate = controller.searchTools('压摆率');
    final adcCode = controller.searchTools('adc code');
    final enob = controller.searchTools('enob');
    final quantization = controller.searchTools('量化误差');

    expect(vppToVrms.first.tool.id, 'rms_peak');
    expect(dbmToVoltage.first.tool.id, 'rms_peak');
    expect(qFactor.first.tool.id, 'lc_resonance');
    expect(bandwidth.first.tool.id, 'lc_resonance');
    expect(halfPower.first.tool.id, 'lc_resonance');
    expect(opAmpTargetGain.first.tool.id, 'op_amp_gain');
    expect(gbw.first.tool.id, 'op_amp_gain');
    expect(slewRate.first.tool.id, 'op_amp_gain');
    expect(adcCode.first.tool.id, 'adc_resolution');
    expect(enob.first.tool.id, 'adc_resolution');
    expect(quantization.first.tool.id, 'adc_resolution');
  });

  test('search matches passive component network target terms', () {
    final targetParallelResistance =
        controller.searchTools('target parallel resistance');
    final reverseResistor = controller.searchTools('反推并联电阻');
    final targetSeriesCapacitance =
        controller.searchTools('target series capacitance');
    final reverseCapacitor = controller.searchTools('目标并联电容');
    final targetSeriesInductance =
        controller.searchTools('target series inductance');
    final reverseInductor = controller.searchTools('反推串联电感');

    expect(targetParallelResistance.first.tool.id, 'resistor_network');
    expect(reverseResistor.first.tool.id, 'resistor_network');
    expect(targetSeriesCapacitance.first.tool.id, 'capacitor_network');
    expect(reverseCapacitor.first.tool.id, 'capacitor_network');
    expect(targetSeriesInductance.first.tool.id, 'inductor_network');
    expect(reverseInductor.first.tool.id, 'inductor_network');
  });

  test('search matches structure and safety engineering terms', () {
    final targetPressureForce = controller.searchTools('target force pressure');
    final requiredPressure = controller.searchTools('目标力所需压力');
    final deflection = controller.searchTools('beam deflection');
    final targetDeflection = controller.searchTools('target deflection');
    final requiredInertia = controller.searchTools('所需惯性矩');
    final secondMoment = controller.searchTools('second moment');
    final sectionModulus = controller.searchTools('section modulus');
    final gyration = controller.searchTools('radius of gyration');
    final tubeWall = controller.searchTools('管壁厚');
    final strongAxis = controller.searchTools('强轴');
    final stressStrain = controller.searchTools('stress strain');
    final factor = controller.searchTools('factor of safety');
    final targetFactor = controller.searchTools('target safety factor');
    final requiredStrength = controller.searchTools('所需强度');

    expect(targetPressureForce.first.tool.id, 'pressure_force');
    expect(requiredPressure.first.tool.id, 'pressure_force');
    expect(deflection.first.tool.id, 'beam_bending');
    expect(targetDeflection.first.tool.id, 'beam_bending');
    expect(requiredInertia.first.tool.id, 'beam_bending');
    expect(
        secondMoment.map((result) => result.tool.id), contains('beam_bending'));
    expect(
        secondMoment.map((result) => result.tool.id), contains('section_area'));
    expect(sectionModulus.first.tool.id, 'section_area');
    expect(gyration.first.tool.id, 'section_area');
    expect(tubeWall.first.tool.id, 'section_area');
    expect(strongAxis.first.tool.id, 'section_area');
    expect(stressStrain.first.tool.id, 'stress_strain');
    expect(factor.first.tool.id, 'safety_factor');
    expect(targetFactor.first.tool.id, 'safety_factor');
    expect(requiredStrength.first.tool.id, 'safety_factor');
  });
}

ToolsController _controller([AppDatabase? db]) {
  return ToolsController(
    toolUsageRepository: ToolUsageRepository(db ?? AppDatabase.instance),
  );
}
