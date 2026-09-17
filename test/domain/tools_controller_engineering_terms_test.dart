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
    final area = controller.searchTools('mm2');
    final temperature = controller.searchTools('degc');
    final capacitance = controller.searchTools('uF');
    final millifarad = controller.searchTools('millifarad');
    final arcSecond = controller.searchTools('arc second');
    final gon = controller.searchTools('gon');
    final resistance = controller.searchTools('kohm');
    final megahenry = controller.searchTools('megahenry');
    final acceleration = controller.searchTools('m/s2');
    final galileo = controller.searchTools('Galileo');
    final inertia = controller.searchTools('cm4');
    final inchInertia = controller.searchTools('in^4');
    final knots = controller.searchTools('knots');
    final torqueMetric = controller.searchTools('nmm');
    final torqueLarge = controller.searchTools('kN m');
    final torqueImperial = controller.searchTools('lbf in');
    final torqueSmallImperial = controller.searchTools('ozf in');

    expect(area.map((result) => result.tool.id), contains('area'));
    expect(
        temperature.map((result) => result.tool.id), contains('temperature'));
    expect(capacitance.map((result) => result.tool.id),
        contains('capacitance_unit'));
    expect(millifarad.first.tool.id, 'capacitance_unit');
    expect(arcSecond.first.tool.id, 'angle_unit');
    expect(gon.first.tool.id, 'angle_unit');
    expect(resistance.map((result) => result.tool.id),
        contains('resistance_unit'));
    expect(megahenry.first.tool.id, 'inductance_unit');
    expect(
        acceleration.map((result) => result.tool.id), contains('acceleration'));
    expect(galileo.first.tool.id, 'acceleration');
    expect(inertia.map((result) => result.tool.id), contains('beam_bending'));
    expect(
        inchInertia.map((result) => result.tool.id), contains('beam_bending'));
    expect(
        inchInertia.map((result) => result.tool.id), contains('section_area'));
    expect(knots.first.tool.id, 'speed');
    expect(torqueMetric.first.tool.id, 'torque_unit');
    expect(torqueLarge.first.tool.id, 'torque_unit');
    expect(torqueImperial.first.tool.id, 'torque_unit');
    expect(torqueSmallImperial.first.tool.id, 'torque_unit');
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
    final pressure = controller.searchTools('psi');
    final millipascal = controller.searchTools('millipascal');
    final gigapascal = controller.searchTools('gigapascal');
    final meganewton = controller.searchTools('meganewton');
    final temperature = controller.searchTools('fahrenheit');
    final rankine = controller.searchTools('rankine');
    final voltage = controller.searchTools('megavolt');
    final area = controller.searchTools('sq ft');
    final acre = controller.searchTools('acre');
    final hectare = controller.searchTools('公顷');
    final volume = controller.searchTools('cubic feet');
    final gallon = controller.searchTools('gallon');
    final tablespoon = controller.searchTools('tablespoon');
    final mass = controller.searchTools('pounds');
    final nanometer = controller.searchTools('nanometer');
    final megameter = controller.searchTools('megameter');
    final tonne = controller.searchTools('tonne');
    final megagram = controller.searchTools('megagram');
    final power = controller.searchTools('horsepower');
    final dbw = controller.searchTools('dBW');
    final megawatt = controller.searchTools('megawatt');
    final millihertz = controller.searchTools('millihertz');
    final terahertz = controller.searchTools('terahertz');
    final megawattHour = controller.searchTools('MWh');
    final kilocalorie = controller.searchTools('kilocalorie');
    final electronvolt = controller.searchTools('electronvolt');
    final flow = controller.searchTools('gallon per minute');
    final cfm = controller.searchTools('CFM');
    final milliliterFlow = controller.searchTools('milliliter per minute');

    expect(pressure.first.tool.id, 'pressure');
    expect(millipascal.first.tool.id, 'pressure');
    expect(gigapascal.first.tool.id, 'pressure');
    expect(meganewton.first.tool.id, 'force_unit');
    expect(temperature.first.tool.id, 'temperature');
    expect(rankine.first.tool.id, 'temperature');
    expect(voltage.first.tool.id, 'voltage');
    expect(area.first.tool.id, 'area');
    expect(acre.first.tool.id, 'area');
    expect(hectare.first.tool.id, 'area');
    expect(volume.first.tool.id, 'volume');
    expect(gallon.first.tool.id, 'volume');
    expect(tablespoon.first.tool.id, 'volume');
    expect(mass.first.tool.id, 'mass');
    expect(nanometer.first.tool.id, 'length');
    expect(megameter.first.tool.id, 'length');
    expect(tonne.first.tool.id, 'mass');
    expect(megagram.first.tool.id, 'mass');
    expect(power.first.tool.id, 'power_unit');
    expect(dbw.first.tool.id, 'power_unit');
    expect(megawatt.first.tool.id, 'power_unit');
    expect(millihertz.first.tool.id, 'frequency');
    expect(terahertz.first.tool.id, 'frequency');
    expect(megawattHour.first.tool.id, 'energy_unit');
    expect(kilocalorie.first.tool.id, 'energy_unit');
    expect(electronvolt.first.tool.id, 'energy_unit');
    expect(flow.first.tool.id, 'flow_unit');
    expect(cfm.first.tool.id, 'flow_unit');
    expect(milliliterFlow.first.tool.id, 'flow_unit');
  });

  test('search matches fine grained electrical and time unit aliases', () {
    final nanoseconds = controller.searchTools('nanoseconds');
    final microseconds = controller.searchTools('microseconds');
    final weeks = controller.searchTools('weeks');
    final nanoamp = controller.searchTools('nA');
    final kiloamp = controller.searchTools('kiloamp');
    final megaamp = controller.searchTools('megaamp');
    final microohm = controller.searchTools('microohm');
    final milliohm = controller.searchTools('milliohm');
    final milliOhmSymbol = controller.searchTools('mΩ');
    final gigaohm = controller.searchTools('gigaohm');
    final nanohenry = controller.searchTools('nanohenry');
    final picohenry = controller.searchTools('picohenry');

    expect(nanoseconds.first.tool.id, 'time_unit');
    expect(microseconds.first.tool.id, 'time_unit');
    expect(weeks.first.tool.id, 'time_unit');
    expect(nanoamp.first.tool.id, 'current_unit');
    expect(kiloamp.first.tool.id, 'current_unit');
    expect(megaamp.first.tool.id, 'current_unit');
    expect(microohm.first.tool.id, 'resistance_unit');
    expect(milliohm.first.tool.id, 'resistance_unit');
    expect(milliOhmSymbol.first.tool.id, 'resistance_unit');
    expect(gigaohm.first.tool.id, 'resistance_unit');
    expect(nanohenry.first.tool.id, 'inductance_unit');
    expect(picohenry.first.tool.id, 'inductance_unit');
  });

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
