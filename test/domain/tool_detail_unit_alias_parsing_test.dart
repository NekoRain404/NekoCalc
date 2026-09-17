import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tool_detail_controller.dart';

void main() {
  test('parses common engineering unit aliases for mechanical fields', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('6公斤力/平方厘米', 'MPa').value,
      closeTo(0.588399, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mPa', 'Pa').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MPa', 'Pa').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2GPa', 'MPa').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1013.25mbar', 'Pa').value,
      closeTo(101325, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250N/mm²', 'MPa').value,
      closeTo(250, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1000牛米', 'N·m').value,
      closeTo(1000, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2kN·m', 'N·m').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('500mN·m', 'N·m').value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('10kgf·cm', 'N·m').value,
      closeTo(0.980665, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('20lb-ft', 'N·m').value,
      closeTo(27.11635896, 1e-8),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('16ozf·in', 'N·m').value,
      closeTo(0.112984829, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('200 gon', 'deg').value,
      closeTo(180, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('100grad', 'deg').value,
      closeTo(90, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('30角分', 'deg').value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1800″', 'deg').value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('8cm^4', 'cm⁴').value,
      closeTo(8, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1in⁴', 'cm⁴').value,
      closeTo(41.62314256, 1e-8),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2L/s', 'L/min').value,
      closeTo(120, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3600 L/h', 'L/min').value,
      closeTo(60, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('750 mL/min', 'L/min')
          .value,
      closeTo(0.75, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('0.5立方米每分钟', 'L/min').value,
      closeTo(500, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit(
        '100 cubic feet per minute',
        'L/min',
      ).value,
      closeTo(2831.6846592, 1e-7),
    );
  });

  test('parses common English spec and label unit formats', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('3.3VDC', 'V').value,
      closeTo(3.3, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MV', 'V').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mV', 'V').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2兆伏', 'kV').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('120 VAC', 'V').value,
      closeTo(120, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('10 amps', 'mA').value,
      closeTo(10000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MA', 'A').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mA', 'A').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2兆安', 'MA').value,
      closeTo(2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250 milliamps', 'A').value,
      closeTo(0.25, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2.5 kilowatts', 'W').value,
      closeTo(2500, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MW', 'W').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mW', 'W').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2兆瓦', 'kW').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('30dBm', 'W').value,
      closeTo(1, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3dBW', 'W').value,
      closeTo(1.995262315, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1W', 'dBm').value,
      closeTo(30, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('100mW', 'dBm').value,
      closeTo(20, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('0dBW', 'dBm').value,
      closeTo(30, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('500 milliliters', 'L')
          .value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2 liters/min', 'L/min')
          .value,
      closeTo(2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit(
        '300 milliliters per minute',
        'L/min',
      ).value,
      closeTo(0.3, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('50 CFM', 'L/min').value,
      closeTo(1415.8423296, 1e-7),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('150 pounds', 'kg').value,
      closeTo(68.0388555, 1e-7),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('60 kph', 'm/s').value,
      closeTo(16.6666666667, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit(
        '1.2 kilowatt hours',
        'J',
      ).value,
      closeTo(4320000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MWh', 'kWh').value,
      closeTo(1000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mWh', 'Wh').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2兆瓦时', 'kWh').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3毫瓦时', 'J').value,
      closeTo(10.8, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250 kcal', 'J').value,
      closeTo(1046000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('10 BTU', 'J').value,
      closeTo(10550.5585262, 1e-7),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1eV', 'J').value,
      closeTo(1.602176634e-19, 1e-30),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1THz', 'GHz').value,
      closeTo(1000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mHz', 'Hz').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MHz', 'Hz').value,
      closeTo(1000000, 1e-6),
    );
  });

  test('parses English per-unit speed and acceleration formats', () {
    expect(
      ToolDetailController.parseNumericInputForUnit(
        '60 kilometers per hour',
        'm/s',
      ).value,
      closeTo(16.6666666667, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit(
        '10 meters per second',
        'km/h',
      ).value,
      closeTo(36, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit(
        '32 feet per second',
        'm/s',
      ).value,
      closeTo(9.7536, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('120 m/min', 'm/s').value,
      closeTo(2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250 cm/s', 'm/s').value,
      closeTo(2.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('10 knots', 'm/s').value,
      closeTo(5.144444444444445, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit(
        '9.80665 meters per second squared',
        'm/s²',
      ).value,
      closeTo(9.80665, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit(
        '32 feet per second squared',
        'm/s²',
      ).value,
      closeTo(9.7536, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1 g', 'm/s²').value,
      closeTo(9.80665, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250 Gal', 'm/s²').value,
      closeTo(2.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('980 cm/s²', 'm/s²').value,
      closeTo(9.8, 1e-12),
    );
  });

  test('parses common finance battery and product spec formats', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('¥1,299.50', '元').value,
      closeTo(1299.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('￥299', '元').value,
      closeTo(299, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('CNY 88.8', '元').value,
      closeTo(88.8, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('RMB1200', '元').value,
      closeTo(1200, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3Ah', 'mAh').value,
      closeTo(3000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('0.5 amp-hour', 'mAh')
          .value,
      closeTo(500, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2500mA h', 'mAh').value,
      closeTo(2500, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2 kA', 'A').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('470 μΩ', 'mΩ').value,
      closeTo(0.47, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1.5 GΩ', 'MΩ').value,
      closeTo(1500, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('220 nH', 'μH').value,
      closeTo(0.22, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('4.7 pH', 'nH').value,
      closeTo(0.0047, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('12-bit', 'bit').value,
      closeTo(12, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3000 r/min', 'rpm').value,
      closeTo(3000, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('5 mm per rev', 'mm/rev')
          .value,
      closeTo(5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('45 K/W', '℃/W').value,
      closeTo(45, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1.5 MiB', 'B').value,
      closeTo(1572864, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1 MB', 'B').value,
      closeTo(1000000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2GiB', 'MB').value,
      closeTo(2147.483648, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2GiB', 'MiB').value,
      closeTo(2048, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('0.5TB', 'GB').value,
      closeTo(500, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3兆字节', 'KB').value,
      closeTo(3000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('8 Mbit', 'B').value,
      closeTo(1000000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('16 bit', 'B').value,
      closeTo(2, 1e-9),
    );
  });

  test('parses composite duration input for time fields', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('2h30m', 's').value,
      closeTo(9000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1:30:15', 'min').value,
      closeTo(90.25, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2小时30分钟', 'h').value,
      closeTo(2.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1d 2h 30min', 'h').value,
      closeTo(26.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2weeks 3days', 'day')
          .value,
      closeTo(17, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1周2天', 'h').value,
      closeTo(216, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('0.5星期', 'day').value,
      closeTo(3.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1500ms', 's').value,
      closeTo(1.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250μs', 'ms').value,
      closeTo(0.25, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('500ns', 'μs').value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250纳秒', 'ns').value,
      closeTo(250, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1s', 'μs').value,
      closeTo(1000000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1s', 'ns').value,
      closeTo(1000000000, 1e-3),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2500us', 'microseconds')
          .value,
      closeTo(2500, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('25 nanoseconds', 's')
          .value,
      closeTo(0.000000025, 1e-15),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('100 microseconds', 's')
          .value,
      closeTo(0.0001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('90 minutes', 'hours')
          .value,
      closeTo(1.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('48小时', '天').value,
      closeTo(2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1:30', 's').value,
      closeTo(90, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('01:02.5', 's').value,
      closeTo(62.5, 1e-12),
    );

    final invalid =
        ToolDetailController.parseNumericInputForUnit('1:90:00', 's');
    expect(invalid.value, isNull);
    expect(invalid.error, contains('无法解析'));

    final invalidMinuteSecond =
        ToolDetailController.parseNumericInputForUnit('1:90', 's');
    expect(invalidMinuteSecond.value, isNull);
    expect(invalidMinuteSecond.error, contains('无法解析'));
  });

  test('parses electronic component markings for passive parts', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('4k7', 'Ω').value,
      closeTo(4700, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2R2', 'Ω').value,
      closeTo(2.2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1M', 'kΩ').value,
      closeTo(1000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('100n', 'μF').value,
      closeTo(0.1, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('4u7', 'nF').value,
      closeTo(4700, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('104', 'nF').value,
      closeTo(100, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2u2', 'μH').value,
      closeTo(2.2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1R0', 'H').value,
      closeTo(1, 1e-12),
    );

    final length = ToolDetailController.parseNumericInputForUnit('4k7', 'm');
    expect(length.value, isNull);
    expect(length.error, contains('无法解析'));
  });

  test('parses AWG wire gauge as conductor area', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('AWG18', 'mm²').value,
      closeTo(0.823, 0.002),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('18awg', 'cm²').value,
      closeTo(0.00823, 0.00002),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('#18', 'm²').value,
      closeTo(0.000000823, 0.000000002),
    );

    final length = ToolDetailController.parseNumericInputForUnit('AWG18', 'm');
    expect(length.value, isNull);
    expect(length.error, contains('无法解析'));
  });

  test('parses conductor diameter and stranded wire as area', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('φ1.0mm', 'mm²').value,
      closeTo(0.785398, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('直径2mm', 'cm²').value,
      closeTo(0.0314159, 1e-7),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('半径0.5mm', 'mm²').value,
      closeTo(0.785398, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('7/0.2mm', 'mm²').value,
      closeTo(0.219911, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('19×0.15mm', 'mm²').value,
      closeTo(0.335758, 1e-6),
    );

    final length = ToolDetailController.parseNumericInputForUnit('φ1.0mm', 'm');
    expect(length.value, isNull);
    expect(length.error, contains('无法解析'));

    final diameterLength =
        ToolDetailController.parseNumericInputForUnit('直径1mm', 'm');
    expect(diameterLength.value, isNull);
    expect(diameterLength.error, contains('无法解析'));

    final slashedLength =
        ToolDetailController.parseNumericInputForUnit('7/0.2mm', 'm');
    expect(slashedLength.value, isNull);
    expect(slashedLength.error, contains('无法解析'));
  });
}
