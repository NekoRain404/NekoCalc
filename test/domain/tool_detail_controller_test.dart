import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tool_detail_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/domain/usecases/tool_save_result.dart';

void main() {
  test('parses pasted numeric input variants', () {
    expect(ToolDetailController.parseNumericInput('1,234.5'), 1234.5);
    expect(ToolDetailController.parseNumericInput('1_000 + 2_500.5'), 3500.5);
    expect(ToolDetailController.parseNumericInput('－12.5'), -12.5);
    expect(ToolDetailController.parseNumericInput('12.5％'), 0.125);
    expect(ToolDetailController.parseNumericInput('１.５×２'), 3);
    expect(ToolDetailController.parseNumericInput('√9'), 3);
    expect(ToolDetailController.parseNumericInput('2½'), closeTo(2.5, 1e-12));
    expect(ToolDetailController.parseNumericInput('result: 2*3'), 6);
    expect(ToolDetailController.parseNumericInput('输出 => 1,234.5'), 1234.5);
    expect(ToolDetailController.parseNumericInput('10 ± 5%'), 10);
    expect(ToolDetailController.parseNumericInput('读数：-12.5±0.3'), -12.5);
    expect(ToolDetailController.parseNumericInput('≈3.3'), 3.3);
    expect(ToolDetailController.parseNumericInput('about 1.5'), 1.5);
    expect(ToolDetailController.parseNumericInput('max(2)'), 2);
    expect(ToolDetailController.parseNumericInput('bad value'), 0);
  });

  test('parses numeric input with field units and engineering prefixes', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('10 mA', 'A').value,
      closeTo(0.01, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250 nA', 'μA').value,
      closeTo(0.25, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('4.7kΩ', 'Ω').value,
      closeTo(4700, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('470mΩ', 'Ω').value,
      closeTo(0.47, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MΩ', 'Ω').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('0.1uF', 'nF').value,
      closeTo(100, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mH', 'H').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MH', 'H').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2兆亨', 'MH').value,
      closeTo(2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mF', 'F').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MF', 'F').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2毫法', 'μF').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3兆法', 'MF').value,
      closeTo(3, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1,200 Hz', 'kHz').value,
      closeTo(1.2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('0.5万元', '元').value,
      closeTo(5000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('current: 10 mA', 'A')
          .value,
      closeTo(0.01, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('电阻 = 4.7kΩ', 'Ω').value,
      closeTo(4700, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('温度 -> 77华氏度', '℃').value,
      closeTo(25, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('4.7kΩ ±5%', 'Ω').value,
      closeTo(4700, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('100Ω (±1%)', 'kΩ').value,
      closeTo(0.1, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('≤10mA', 'A').value,
      closeTo(0.01, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('about 4.7 kΩ', 'Ω').value,
      closeTo(4700, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3.3V typ.', 'V').value,
      closeTo(3.3, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3.0~3.6V', 'mV').value,
      closeTo(3000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('500-1000mA', 'A').value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2.5V to 5V', 'V').value,
      closeTo(2.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('10-2 V', 'V').value,
      closeTo(8, 1e-12),
    );

    final mismatch = ToolDetailController.parseNumericInputForUnit('12 V', 'A');
    expect(mismatch.value, isNull);
    expect(mismatch.error, contains('单位 V 与 A 不匹配'));
  });

  test('parses common Chinese unit aliases for numeric fields', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('1.5公里', 'm').value,
      closeTo(1500, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1Mm', 'm').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mm', 'm').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('250μm', 'mm').value,
      closeTo(0.25, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('500nm', 'μm').value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('12厘米', 'm').value,
      closeTo(0.12, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2公斤', 'kg').value,
      closeTo(2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1Mg', 'kg').value,
      closeTo(1000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mg', 'kg').value,
      closeTo(0.000001, 1e-15),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2吨', 'kg').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('500毫升', 'L').value,
      closeTo(0.5, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('10平方厘米', 'm²').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2公顷', 'm²').value,
      closeTo(20000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3亩', 'm²').value,
      closeTo(2000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1英亩', 'ha').value,
      closeTo(0.40468564224, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('72公里/小时', 'm/s').value,
      closeTo(20, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('5千牛', 'N').value,
      closeTo(5000, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1mN', 'N').value,
      closeTo(0.001, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1MN', 'N').value,
      closeTo(1000000, 1e-6),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2兆牛', 'MN').value,
      closeTo(2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2度', 'J').value,
      closeTo(7200000, 1e-3),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('7850kg/m³', 'g/cm³').value,
      closeTo(7.85, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1.2立方米/小时', 'L/min').value,
      closeTo(20, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2加仑', 'L').value,
      closeTo(7.570823568, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3汤匙', 'mL').value,
      closeTo(44.36029434375, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('12 cubic inches', 'mL')
          .value,
      closeTo(196.644768, 1e-9),
    );
  });

  test('parses composite same-dimension unit input', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('1m20cm', 'm').value,
      closeTo(1.2, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('6ft 2in', 'cm').value,
      closeTo(187.96, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('6 feet 2 inches', 'cm')
          .value,
      closeTo(187.96, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit("6'2\"", 'cm').value,
      closeTo(187.96, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('5′8″', 'cm').value,
      closeTo(172.72, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('72"', 'cm').value,
      closeTo(182.88, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('3yd', 'm').value,
      closeTo(2.7432, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('1.5 miles', 'km').value,
      closeTo(2.414016, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('2英里', 'km').value,
      closeTo(3.218688, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('5lb 8oz', 'kg').value,
      closeTo(2.494758035, 1e-9),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('重量: 1kg 250g', 'kg').value,
      closeTo(1.25, 1e-12),
    );
  });

  test('parses temperature unit aliases and names', () {
    expect(
      ToolDetailController.parseNumericInputForUnit('77华氏度', '℃').value,
      closeTo(25, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('300开尔文', '℃').value,
      closeTo(26.85, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('25 celsius', 'K').value,
      closeTo(298.15, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('68 Fahrenheit', 'K').value,
      closeTo(293.15, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('491.67°R', '℃').value,
      closeTo(0, 1e-12),
    );
    expect(
      ToolDetailController.parseNumericInputForUnit('536.67 rankine', '℃')
          .value,
      closeTo(25, 1e-12),
    );
  });

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

  test('tracks invalid numeric input without overwriting current values', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValue('current', '2*3');
    expect(controller.values['current'], 6);
    expect(controller.inputErrors, isEmpty);

    controller.updateValue('current', 'bad value');
    expect(controller.values['current'], 6);
    expect(controller.inputErrors['current'], contains('无法解析'));
    expect(controller.hasInputErrors, isTrue);

    controller.updateValue('current', '4');
    expect(controller.values['current'], 4);
    expect(controller.inputErrors, isEmpty);
  });

  test('updates tool inputs using pasted units without overwriting on mismatch',
      () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'current': 'current: 10 mA',
      'resistance': '电阻 = 4.7kΩ ±5%',
      'tol': '1% (±0.1%)',
    });

    expect(controller.values['current'], closeTo(0.01, 1e-12));
    expect(controller.values['resistance'], closeTo(4700, 1e-9));
    expect(controller.values['tol'], 1);
    expect(controller.primary?.value, '47');
    expect(controller.inputErrors, isEmpty);

    controller.updateValue('current', '500-1000mA');
    expect(controller.values['current'], closeTo(0.5, 1e-12));
    expect(controller.primary?.value, '2350');
    expect(controller.inputErrors, isEmpty);

    controller.updateValue('current', '12 V');
    expect(controller.values['current'], closeTo(0.5, 1e-12));
    expect(controller.inputErrors['current'], contains('单位 V 与 A 不匹配'));
  });

  test('extracts tool input values from pasted labeled text', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');

    final values = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: '''
欧姆定律记录
电流 I: 10 mA
电阻 R = 4.7kΩ ±5%
tol: 1%
unused = 123
''',
    );

    expect(values, {
      'current': '10 mA',
      'resistance': '4.7kΩ ±5%',
      'tol': '1%',
    });

    final compactValues = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: 'current=25mA; resistance=220Ω; voltage=5V',
    );
    expect(compactValues, {
      'current': '25mA',
      'resistance': '220Ω',
      'voltage': '5V',
    });

    final unitOnlyValues = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: '''
10 mA
4.7kΩ ±5%
1%
''',
    );
    expect(unitOnlyValues, {
      'current': '10 mA',
      'resistance': '4.7kΩ ±5%',
      'tol': '1%',
    });

    final tableValues = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: '''
参数\t读数
电流 I\t10 mA
电阻 R\t4.7kΩ ±5%
电阻公差\t1%
''',
    );
    expect(tableValues, {
      'current': '10 mA',
      'resistance': '4.7kΩ ±5%',
      'tol': '1%',
    });

    final ignoredValues = ToolDetailController.rawInputValuesFromPastedText(
      tool: tool,
      input: '欧姆定律记录\nignore this line\n功率提示: low',
    );
    expect(ignoredValues, isEmpty);
  });

  test('reports pasted numeric input issues and parses nested JSON values', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');

    final jsonResult = ToolDetailController.inputPasteResultFromPastedText(
      tool: tool,
      input: '''
{
  "inputs": {
    "电流 I": {"value": "10", "unit": "mA"},
    "电阻 R": "4.7kΩ",
    "电阻公差": "1%"
  }
}
''',
    );
    expect(jsonResult.values, {
      'current': '10mA',
      'resistance': '4.7kΩ',
      'tol': '1%',
    });
    expect(jsonResult.hasIssues, isFalse);
    expect(jsonResult.summaryForTool(tool), '已粘贴 3 个参数');

    final mixedResult = ToolDetailController.inputPasteResultFromPastedText(
      tool: tool,
      input: '''
电流 I: 10 mA
电流 I: 25 mA
电压 V: 12 V
未知参数: 123
5
''',
    );
    expect(mixedResult.values, {
      'current': '25 mA',
      'voltage': '12 V',
    });
    expect(mixedResult.duplicateKeys, {'current'});
    expect(mixedResult.ignoredSegments, contains('未知参数: 123'));
    expect(mixedResult.ambiguousSegments, contains('5'));
    expect(mixedResult.summaryForTool(tool), contains('已粘贴 2 个参数'));
    expect(mixedResult.summaryForTool(tool), contains('重复字段已取最后值：电流 I'));
    expect(mixedResult.summaryForTool(tool), contains('跳过 1 条歧义值'));
    expect(mixedResult.summaryForTool(tool), contains('忽略 1 条未匹配值'));
  });

  test('batch updates keep valid fields when another pasted field is invalid',
      () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'current': '10 mA',
      'resistance': '12 V',
      'tol': '1%',
    });

    expect(controller.values['current'], closeTo(0.01, 1e-12));
    expect(controller.values['tol'], 1);
    expect(controller.values['resistance'], 220);
    expect(controller.primary?.value, '2.2');
    expect(controller.inputErrors.keys, contains('resistance'));
    expect(controller.inputErrors['resistance'], contains('单位 V 与 Ω 不匹配'));
    expect(controller.inputErrorSummary(), contains('电阻 R'));
  });

  test('pasted input apply result reports invalid matched fields', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    final pasteResult = ToolDetailController.inputPasteResultFromPastedText(
      tool: tool,
      input: '''
电流 I: 10 mA
电阻 R: 12 V
未知参数: 123
''',
    );
    final applyResult = controller.applyInputPasteResult(pasteResult);

    expect(applyResult.filledKeys, {'current', 'resistance'});
    expect(applyResult.validKeys, {'current'});
    expect(applyResult.invalidKeyErrors.keys, {'resistance'});
    expect(applyResult.inputTexts['current'], '10 mA');
    expect(applyResult.inputTexts['resistance'], '12 V');
    expect(controller.values['current'], closeTo(0.01, 1e-12));
    expect(controller.values['resistance'], 220);
    expect(controller.inputErrors['resistance'], contains('单位 V 与 Ω 不匹配'));
    expect(applyResult.summaryForTool(tool), contains('已应用 1 个参数'));
    expect(applyResult.summaryForTool(tool), contains('需修正：电阻 R'));
    expect(applyResult.summaryForTool(tool), contains('忽略 1 条未匹配值'));
  });

  test('optional empty inputs are omitted from numeric tool values', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'statistics');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'x1': '10',
      'x2': '20',
      'x3': '30',
      'x4': '40',
      'x5': '',
    });
    expect(controller.values.keys, contains('x4'));
    expect(controller.values.keys, isNot(contains('x5')));

    controller.updateValue('x4', '');
    expect(controller.values.keys, isNot(contains('x4')));
    expect(controller.inputErrors, isEmpty);

    final valuesByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(valuesByLabel['样本数'], '3');
    expect(valuesByLabel['平均值'], '20');
    expect(controller.inputSummary(), contains('x4: 未填写'));
    expect(controller.inputSummary(), isNot(contains('x4: 0')));
  });

  test('optional defaults can be cleared for reverse solving tools', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'concentration');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    expect(controller.values.keys, contains('volume'));

    controller.updateValues({
      'mass': '5',
      'volume': '',
      'molarMass': '58.44',
      'massConcentration': '10',
      'molarity': '',
    });

    final valuesByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('volume')));
    expect(valuesByLabel['溶液体积 L'], '0.5');
    expect(valuesByLabel['输入来源'], '溶质量+质量浓度');
  });

  test('ideal gas optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ideal_gas');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'n': '',
      'temp': '273.15',
      'volume': '22.41396954',
      'pressure': '101.325',
    });

    final valuesByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('n')));
    expect(valuesByLabel['物质的量'], startsWith('1'));
    expect(valuesByLabel['输入来源'], '压力+温度+体积');
  });

  test('wavelength optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'wavelength');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'speed': '343',
      'frequency': '',
      'wavelength': '0.343',
    });

    final valuesByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('frequency')));
    expect(valuesByLabel['频率'], '1000');
    expect(valuesByLabel['输入来源'], '波速+波长');
  });

  test('heat optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'heat');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'mass': '1',
      'specific': '4186',
      'delta': '',
      'heat': '41860',
    });

    final valuesByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('delta')));
    expect(valuesByLabel['温度变化'], '10');
    expect(valuesByLabel['输入来源'], '热量+质量+比热容');
  });

  test('half life optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'half_life');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'initial': '100',
      'half': '6',
      'time': '',
      'remaining': '',
      'remainingRatio': '25%',
    });

    final timeByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('time')));
    expect(controller.values['remainingRatio'], 25);
    expect(timeByLabel['经过时间'], '12');
    expect(timeByLabel['输入来源'], '初始量+半衰期+剩余比例');

    controller.updateValues({
      'initial': '100',
      'half': '',
      'time': '12h',
      'remaining': '25',
      'remainingRatio': '',
    });

    final halfByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('half')));
    expect(halfByLabel['半衰期'], '6');
    expect(halfByLabel['输入来源'], '初始量+经过时间+剩余量');
  });

  test('fuel economy optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'fuel_economy');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'distance': '500 km',
      'fuel': '',
      'consumption': '6 L/100km',
      'price': '8元/升',
      'tank': '50L',
      'annualDistance': '',
      'co2': '',
    });

    final fuelByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('fuel')));
    expect(controller.values['consumption'], 6);
    expect(controller.values['price'], 8);
    expect(fuelByLabel['燃油'], '30');
    expect(fuelByLabel['满箱续航'], startsWith('833.333'));
    expect(fuelByLabel['输入来源'], '里程+百公里油耗');

    controller.updateValues({
      'distance': '',
      'fuel': '30L',
      'consumption': '6升/百公里',
      'price': '8',
      'tank': '',
      'annualDistance': '15000km',
      'co2': '2.31kg/L',
    });

    final distanceByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('distance')));
    expect(distanceByLabel['里程'], '500');
    expect(distanceByLabel['年燃油费用'], '7200');
    expect(distanceByLabel['CO2每公里'], startsWith('138.6'));
    expect(distanceByLabel['输入来源'], '燃油+百公里油耗');
  });

  test('electricity cost optional defaults can be cleared for reverse solving',
      () {
    final tool =
        toolCatalog.firstWhere((item) => item.id == 'electricity_cost');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'power': '',
      'hours': '3h',
      'days': '30天',
      'price': '0.6元/kWh',
      'targetCost': '43.2元',
    });

    final powerByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('power')));
    expect(powerByLabel['功率'], '800');
    expect(powerByLabel['输入来源'], '目标费用+每日使用+天数+电价');

    controller.updateValues({
      'power': '800W',
      'hours': '3h',
      'days': '30天',
      'price': '',
      'targetCost': '43.2元',
    });

    final priceByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('price')));
    expect(priceByLabel['电价'], '0.6');
    expect(priceByLabel['输入来源'], '目标费用+功率+每日使用+天数');
  });

  test('break even optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'break_even');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'fixed': '',
      'price': '120元',
      'variable': '70元',
      'targetQuantity': '1000件',
    });

    final fixedByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('fixed')));
    expect(fixedByLabel['固定成本'], '50000');
    expect(fixedByLabel['输入来源'], '目标销量+单价+单位变动成本');

    controller.updateValues({
      'fixed': '50000元',
      'price': '',
      'variable': '70元',
      'targetQuantity': '1000件',
    });

    final priceByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('price')));
    expect(priceByLabel['单价'], '120');
    expect(priceByLabel['输入来源'], '目标销量+固定成本+单位变动成本');
  });

  test('compound optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'compound');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'principal': '',
      'rate': '5%',
      'years': '10年',
      'target': '16288.946267元',
    });

    final principalByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('principal')));
    expect(controller.values['rate'], 5);
    expect(principalByLabel['本金'], startsWith('10000'));
    expect(principalByLabel['输入来源'], '目标终值+年化收益+年限');

    controller.updateValues({
      'principal': '10000元',
      'rate': '',
      'years': '10年',
      'target': '16288.946267元',
    });

    final rateByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('rate')));
    expect(rateByLabel['年化收益率'], startsWith('5'));
    expect(rateByLabel['输入来源'], '本金+目标终值+年限');
  });

  test('roi optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'roi');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'gain': '',
      'cost': '10000元',
      'roi': '25%',
      'years': '2年',
    });

    final gainByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('gain')));
    expect(controller.values['roi'], 25);
    expect(gainByLabel['收益'], '12500');
    expect(gainByLabel['年化ROI'], startsWith('11.803'));
    expect(gainByLabel['输入来源'], '投入+ROI');

    controller.updateValues({
      'gain': '12500元',
      'cost': '',
      'roi': '25%',
      'years': '',
    });

    final costByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('cost')));
    expect(costByLabel['投入'], '10000');
    expect(costByLabel['输入来源'], '收益+ROI');
  });

  test('discount optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'discount');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'price': '299元',
      'discount': '',
      'finalPrice': '254.15元',
    });

    final discountByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('discount')));
    expect(discountByLabel['折扣率'], '85');
    expect(discountByLabel['输入来源'], '原价+到手价');

    controller.updateValues({
      'price': '',
      'discount': '85%',
      'finalPrice': '254.15元',
    });

    final priceByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('price')));
    expect(controller.values['discount'], 85);
    expect(priceByLabel['原价'], '299');
    expect(priceByLabel['输入来源'], '折扣+到手价');
  });

  test('tax optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'tax');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'net': '',
      'rate': '13%',
      'gross': '1130元',
    });

    final netByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('net')));
    expect(controller.values['rate'], 13);
    expect(netByLabel['不含税反推'], '1000');
    expect(netByLabel['输入来源'], '含税金额+税率');

    controller.updateValues({
      'net': '1000元',
      'rate': '',
      'gross': '1130元',
    });

    final rateByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('rate')));
    expect(rateByLabel['税率'], '13');
    expect(rateByLabel['输入来源'], '税前金额+含税金额');
  });

  test('inflation optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'inflation');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'amount': '',
      'rate': '3%',
      'years': '10年',
      'future': '13439.163793元',
    });

    final amountByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('amount')));
    expect(controller.values['rate'], 3);
    expect(amountByLabel['当前金额'], startsWith('10000'));
    expect(amountByLabel['输入来源'], '未来等值+年通胀率+年数');

    controller.updateValues({
      'amount': '10000元',
      'rate': '',
      'years': '10年',
      'future': '13439.163793元',
    });

    final rateByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('rate')));
    expect(rateByLabel['年通胀率'], startsWith('3'));
    expect(rateByLabel['输入来源'], '当前金额+未来等值+年数');
  });

  test('profit margin optional defaults can be cleared for reverse solving',
      () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'profit_margin');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'cost': '80元',
      'price': '',
      'margin': '33.3333333333%',
      'profit': '',
    });

    final priceByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('price')));
    expect(controller.values['margin'], closeTo(33.3333333333, 1e-9));
    expect(priceByLabel['售价'], startsWith('120'));
    expect(priceByLabel['输入来源'], '成本+目标毛利率');

    controller.updateValues({
      'cost': '',
      'price': '120元',
      'margin': '',
      'profit': '40元',
    });

    final costByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('cost')));
    expect(costByLabel['成本'], '80');
    expect(costByLabel['输入来源'], '售价+目标利润');
  });

  test('encodes decodes and applies per tool input drafts', () {
    final ohms = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final divider =
        toolCatalog.firstWhere((item) => item.id == 'voltage_divider');

    final encoded = ToolDetailController.encodeDraft(
      tool: ohms,
      rawValues: {
        'current': '10 mA',
        'resistance': '4.7kΩ',
        'tol': '1%',
        'unknown': 'ignored',
      },
    );

    expect(
        ToolDetailController.draftSettingKey(ohms.id), 'tool_draft_ohms_law');
    expect(
      ToolDetailController.decodeDraft(tool: divider, raw: encoded),
      isNull,
    );

    final decoded = ToolDetailController.decodeDraft(tool: ohms, raw: encoded);
    expect(decoded, {
      'current': '10 mA',
      'resistance': '4.7kΩ',
      'tol': '1%',
    });
    expect(
        ToolDetailController.decodeDraft(tool: ohms, raw: 'bad json'), isNull);

    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: ohms,
    );

    final applied = controller.applyRawInputValues(decoded!);

    expect(applied['current'], '10 mA');
    expect(applied['resistance'], '4.7kΩ');
    expect(applied['tol'], '1%');
    expect(controller.values['current'], closeTo(0.01, 1e-12));
    expect(controller.values['resistance'], closeTo(4700, 1e-9));
    expect(controller.values['tol'], 1);
    expect(controller.primary?.value, '47');
    expect(controller.inputErrors, isEmpty);
  });

  test('component markings drive engineering tool calculations', () {
    final dividerTool =
        toolCatalog.firstWhere((item) => item.id == 'voltage_divider');
    final divider = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: dividerTool,
    );

    divider.updateValues({
      'vin': '12V',
      'r1': '4k7',
      'r2': '10k',
      'load': '0',
      'tol': '1%',
    });

    expect(divider.values['r1'], closeTo(4.7, 1e-12));
    expect(divider.values['r2'], closeTo(10, 1e-12));
    expect(divider.primary?.value, '8.1633');

    final rcTool = toolCatalog.firstWhere((item) => item.id == 'rc_filter');
    final rc = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: rcTool,
    );

    rc.updateValues({
      'r': '4k7',
      'c': '104',
      'tol': '5%',
    });

    expect(rc.values['r'], closeTo(4.7, 1e-12));
    expect(rc.values['c'], closeTo(100, 1e-9));
    expect(rc.primary?.label, '截止频率 fc');
    expect(rc.inputErrors, isEmpty);

    final dbmTool = toolCatalog.firstWhere((item) => item.id == 'dbm');
    final dbm = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: dbmTool,
    );

    dbm.updateValue('dbm', '1W');

    expect(dbm.values['dbm'], closeTo(30, 1e-12));
    expect(dbm.primary?.label, '功率');
    expect(dbm.primary?.value, '1000');
    expect(dbm.results.map((result) => result.label), contains('50Ω Vpp'));
    expect(dbm.inputErrors, isEmpty);
  });

  test('AWG wire gauge drives voltage drop calculations', () {
    final tool =
        toolCatalog.firstWhere((item) => item.id == 'wire_voltage_drop');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'current': '5A',
      'length': '3m',
      'area': 'AWG18',
      'voltage': '12V',
    });

    expect(controller.values['area'], closeTo(0.823, 0.002));
    expect(controller.primary?.label, '压降');
    expect(controller.primary?.value, isNot('0'));
    expect(controller.inputErrors, isEmpty);
  });

  test('conductor wire formats drive voltage drop calculations', () {
    final tool =
        toolCatalog.firstWhere((item) => item.id == 'wire_voltage_drop');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'current': '5A',
      'length': '3m',
      'area': '7/0.2mm',
      'voltage': '12V',
    });

    expect(controller.values['area'], closeTo(0.219911, 1e-6));
    expect(controller.primary?.label, '压降');
    expect(controller.primary?.value, isNot('0'));
    expect(controller.inputErrors, isEmpty);
  });

  test('composite duration input drives time based tool calculations', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'motion');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'speed': '10m/s',
      'time': '2h30m',
    });

    expect(controller.values['speed'], closeTo(10, 1e-12));
    expect(controller.values['time'], closeTo(9000, 1e-9));
    expect(controller.primary?.label, '距离');
    expect(controller.primary?.value, '90000');
    expect(controller.inputErrors, isEmpty);

    controller.updateValue('time', '1:30');
    expect(controller.values['time'], closeTo(90, 1e-12));
    expect(controller.primary?.value, '900');
    expect(controller.inputErrors, isEmpty);
  });

  test('Chinese unit aliases drive real tool calculations', () {
    final motionTool = toolCatalog.firstWhere((item) => item.id == 'motion');
    final motion = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: motionTool,
    );

    motion.updateValues({
      'speed': '72公里/小时',
      'time': '30秒',
    });

    expect(motion.values['speed'], closeTo(20, 1e-9));
    expect(motion.values['time'], closeTo(30, 1e-12));
    expect(motion.primary?.value, '600');
    expect(motion.inputErrors, isEmpty);

    final forceTool = toolCatalog.firstWhere((item) => item.id == 'force');
    final force = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: forceTool,
    );

    force.updateValues({
      'mass': '2公斤',
      'acc': '9.8米/秒²',
    });

    expect(force.values['mass'], closeTo(2, 1e-12));
    expect(force.values['acc'], closeTo(9.8, 1e-12));
    expect(force.primary?.value, '19.6');
    expect(force.inputErrors, isEmpty);

    final temperatureTool =
        toolCatalog.firstWhere((item) => item.id == 'temperature');
    final temperature = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: temperatureTool,
    );

    temperature.updateValue('value', '77华氏度');
    expect(temperature.values['value'], closeTo(25, 1e-12));
    expect(temperature.primary?.value, '25');
    expect(temperature.results.map((result) => result.value), contains('77'));
    expect(
        temperature.results.map((result) => result.value), contains('536.67'));
    expect(temperature.inputErrors, isEmpty);
  });

  test('composite Chinese units drive material and flow calculations', () {
    final materialTool =
        toolCatalog.firstWhere((item) => item.id == 'material_weight');
    final material = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: materialTool,
    );

    material.updateValues({
      'length': '1米',
      'width': '10厘米',
      'thickness': '10毫米',
      'density': '7850kg/m³',
    });

    expect(material.values['length'], closeTo(1000, 1e-9));
    expect(material.values['width'], closeTo(100, 1e-9));
    expect(material.values['thickness'], closeTo(10, 1e-12));
    expect(material.values['density'], closeTo(7.85, 1e-12));
    expect(material.primary?.label, '重量');
    expect(material.primary?.value, '7.85');
    expect(material.inputErrors, isEmpty);

    final flowTool =
        toolCatalog.firstWhere((item) => item.id == 'flow_velocity');
    final flow = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: flowTool,
    );

    flow.updateValues({
      'flow': '1.2立方米/小时',
      'diameter': '20毫米',
    });

    expect(flow.values['flow'], closeTo(20, 1e-9));
    expect(flow.values['diameter'], closeTo(20, 1e-12));
    expect(flow.primary?.label, '平均流速');
    expect(flow.inputErrors, isEmpty);

    flow.updateValues({
      'flow': '10 CFM',
      'diameter': '20毫米',
    });

    expect(flow.values['flow'], closeTo(283.16846592, 1e-8));
    expect(flow.inputErrors, isEmpty);
  });

  test('engineering unit aliases drive mechanical calculations', () {
    final pressureTool =
        toolCatalog.firstWhere((item) => item.id == 'pressure_force');
    final pressure = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: pressureTool,
    );

    pressure.updateValues({
      'pressure': '6公斤力/平方厘米',
      'area': '2平方英寸',
    });

    expect(pressure.values['pressure'], closeTo(0.588399, 1e-6));
    expect(pressure.values['area'], closeTo(12.9032, 1e-4));
    expect(pressure.primary?.label, '作用力');
    expect(pressure.inputErrors, isEmpty);

    final torqueTool =
        toolCatalog.firstWhere((item) => item.id == 'torque_power');
    final torque = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: torqueTool,
    );

    torque.updateValues({
      'torque': '20lb-ft',
      'rpm': '3000rpm',
    });

    expect(torque.values['torque'], closeTo(27.11635896, 1e-8));
    expect(torque.primary?.label, '功率');
    expect(torque.inputErrors, isEmpty);

    final ldoTool = toolCatalog.firstWhere((item) => item.id == 'ldo_power');
    final ldo = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: ldoTool,
    );

    ldo.updateValues({
      'vin': '5V',
      'vout': '3.3V',
      'current': '500mA',
      'iq': '5mA',
      'dropout': '0.25V',
      'theta': '60 K/W',
      'ambient': '40℃',
      'maxJunction': '85℃',
    });

    expect(ldo.values['current'], closeTo(500, 1e-9));
    expect(ldo.values['iq'], closeTo(5, 1e-9));
    expect(ldo.values['dropout'], closeTo(0.25, 1e-12));
    expect(ldo.values['theta'], closeTo(60, 1e-12));
    expect(ldo.values['ambient'], closeTo(40, 1e-12));
    expect(ldo.primary?.label, '功耗');
    expect(ldo.primary?.value, '0.875');
    expect(ldo.results.map((result) => result.label), contains('热余量'));
    expect(ldo.results.map((result) => result.label), contains('静态损耗'));
    expect(ldo.insights.join('\n'), contains('热余量为负'));
    expect(ldo.inputErrors, isEmpty);

    final thermalTool =
        toolCatalog.firstWhere((item) => item.id == 'thermal_rise');
    final thermal = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: thermalTool,
    );

    thermal.updateValues({
      'power': '1.5W',
      'theta': '60 K/W',
      'ambient': '40℃',
      'maxJunction': '85℃',
    });

    expect(thermal.values['power'], closeTo(1.5, 1e-12));
    expect(thermal.values['theta'], closeTo(60, 1e-12));
    expect(thermal.primary?.label, '结温估算');
    expect(thermal.primary?.value, '130');
    expect(thermal.results.map((result) => result.label), contains('热余量'));
    expect(thermal.insights.join('\n'), contains('热余量为负'));
    expect(thermal.inputErrors, isEmpty);

    final beamTool =
        toolCatalog.firstWhere((item) => item.id == 'beam_bending');
    final beam = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: beamTool,
    );

    beam.updateValues({
      'load': '10kgf',
      'length': '1000mm',
      'elastic': '200000MPa',
      'inertia': '1in⁴',
    });

    expect(beam.values['load'], closeTo(98.0665, 1e-9));
    expect(beam.values['length'], closeTo(1, 1e-12));
    expect(beam.values['elastic'], closeTo(200, 1e-12));
    expect(beam.values['inertia'], closeTo(41.62314256, 1e-8));
    expect(beam.primary?.label, '最大挠度');
    expect(beam.inputErrors, isEmpty);
  });

  test('finance battery and product spec formats drive real calculations', () {
    final batteryTool =
        toolCatalog.firstWhere((item) => item.id == 'battery_life');
    final battery = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: batteryTool,
    );

    battery.updateValues({
      'capacity': '3Ah',
      'current': '250 milliamps',
      'efficiency': '90%',
    });

    expect(battery.values['capacity'], closeTo(3000, 1e-9));
    expect(battery.values['current'], closeTo(250, 1e-9));
    expect(battery.values['voltage'], closeTo(3.7, 1e-12));
    expect(battery.primary?.label, '续航时间');
    expect(battery.primary?.value, '10.8');
    expect(battery.inputErrors, isEmpty);

    battery.updateValues({
      'capacity': '18.5Wh',
      'current': '2.5W',
      'voltage': '5V',
      'efficiency': '90%',
    });

    expect(battery.values['capacity'], closeTo(3700, 1e-9));
    expect(battery.values['current'], closeTo(500, 1e-9));
    expect(battery.values['voltage'], closeTo(5, 1e-12));
    expect(battery.primary?.label, '续航时间');
    expect(battery.primary?.value, '6.66');
    expect(battery.results.map((result) => result.label), contains('标称能量'));
    expect(battery.results.map((result) => result.label), contains('负载功率'));
    expect(battery.inputErrors, isEmpty);

    final adcTool =
        toolCatalog.firstWhere((item) => item.id == 'adc_resolution');
    final adc = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: adcTool,
    );

    adc.updateValues({
      'vref': '3.3VDC',
      'bits': '12-bit',
    });

    expect(adc.values['vref'], closeTo(3.3, 1e-12));
    expect(adc.values['bits'], closeTo(12, 1e-12));
    expect(adc.primary?.label, 'LSB');
    expect(adc.inputErrors, isEmpty);

    final discountTool =
        toolCatalog.firstWhere((item) => item.id == 'discount');
    final discount = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: discountTool,
    );

    discount.updateValues({
      'price': '¥299',
      'discount': '85%',
    });

    expect(discount.values['price'], closeTo(299, 1e-12));
    expect(discount.values['discount'], closeTo(85, 1e-12));
    expect(discount.primary?.label, '到手价');
    expect(discount.primary?.value, '254.15');
    expect(discount.inputErrors, isEmpty);

    final dataTool = toolCatalog.firstWhere((item) => item.id == 'data_size');
    final dataSize = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: dataTool,
    );

    dataSize.updateValue('value', '1.5 MiB');
    expect(dataSize.values['value'], closeTo(1572864, 1e-9));
    expect(dataSize.primary?.label, 'B');
    expect(dataSize.results.map((result) => result.value), contains('1.5'));
    expect(dataSize.results.map((result) => result.label), contains('MiB'));
    expect(dataSize.results.map((result) => result.label), contains('GiB'));
    expect(dataSize.results.map((result) => result.label), contains('TiB'));
    expect(dataSize.inputErrors, isEmpty);
  });

  test('copy text includes inputs, results, and insights', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    final text = controller.copyText();

    expect(text, startsWith('欧姆定律'));
    expect(text, contains('输入参数:'));
    expect(text, contains('电流'));
    expect(text, contains('电阻'));
    expect(text, contains('计算结果:'));
    expect(text, contains('电压 V'));
    expect(text, contains('结果状态:'));
    expect(text, contains('结果可复用'));
    expect(text, contains('校核:'));
    expect(text, contains('公式: V = I'));
  });

  test('copy text and notes format input values consistently', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValue('current', '0.1+0.2');

    expect(controller.values['current'], closeTo(0.3, 1e-12));
    expect(controller.inputSummary(), contains('电流 I: 0.3A'));
    expect(controller.resultSummary(), contains('电压 V'));
    expect(controller.insightSummary(), contains('结果按理想电阻计算'));
    expect(controller.resultHealthSummary(), contains('个结果可复用'));
    expect(controller.resultHealthSummary(), contains('主结果 电压 V: 66V'));
    expect(controller.copyText(), contains('电流 I: 0.3A'));
    expect(controller.copyText(), isNot(contains('0.30000000000000004')));
    expect(controller.noteBody(), contains('输入参数:'));
    expect(controller.noteBody(), contains('计算结果:'));
    expect(controller.noteBody(), contains('结果状态:'));
    expect(controller.noteBody(), contains('校核:'));
    expect(controller.noteBody(), contains('电流 I: 0.3A'));
    expect(controller.noteBody(), isNot(contains('0.30000000000000004')));

    final primary = controller.primary!;
    final singleText = controller.singleResultCopyText(primary);
    expect(singleText, startsWith('欧姆定律'));
    expect(singleText, contains('电压 V: 66V'));
    expect(singleText, contains('输入参数:'));
    expect(singleText, contains('公式: V = I × R'));
  });

  test('result health reports invalid results without appending units', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'current': '20mA',
      'resistance': '0Ω',
      'tol': '5%',
    });

    expect(controller.hasResultIssues, isTrue);
    expect(controller.issueResults.length, controller.results.length);
    expect(controller.usableResults, isEmpty);
    expect(controller.primaryResultLine(), '电压 V: 无效');
    expect(controller.resultSummary(), contains('功率 P: 无效'));
    expect(controller.resultSummary(), isNot(contains('无效V')));
    expect(controller.resultHealthSummary(), contains('需要检查'));
    expect(controller.resultIssueSummary(limit: 2), contains('另有'));
    expect(controller.copyText(), contains('结果状态:'));
    expect(controller.copyText(), contains('电压 V'));
    expect(controller.singleResultCopyText(controller.primary!),
        contains('电压 V: 无效'));
  });

  test('input error summary reports labels units and parse messages', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    );

    controller.updateValues({
      'current': '12 V',
      'resistance': 'bad value',
      'tol': '5%',
    });

    expect(controller.hasInputErrors, isTrue);
    expect(controller.inputErrorSummary(), contains('电流 I（A）: 单位 V 与 A 不匹配'));
    expect(controller.inputErrorSummary(), contains('电阻 R（Ω）: 无法解析数值或表达式'));

    controller.updateValues({
      'current': '10mA',
      'resistance': '4.7kΩ',
      'tol': '5%',
    });

    expect(controller.hasInputErrors, isFalse);
    expect(controller.inputErrorSummary(), isEmpty);
  });

  test('save result and note report actual repository writes', () async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final db = _FakeToolSaveDatabase();
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      toolUsageRepository: ToolUsageRepository(db),
      tool: tool,
    );

    final history = await controller.saveResult(controller.inputSummary());
    final note = await controller.saveNote();

    expect(history.status, ToolSaveStatus.saved);
    expect(history.saved, isTrue);
    expect(history.recordId, 1);
    expect(history.message, '结果已保存到历史记录');
    expect(note.status, ToolSaveStatus.saved);
    expect(note.recordId, 1);
    expect(db.savedHistory.single['toolId'], 'ohms_law');
    expect(db.savedNotes.single['title'], '欧姆定律');
  });

  test('save result and note report invalid inputs without writing', () async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final db = _FakeToolSaveDatabase();
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      toolUsageRepository: ToolUsageRepository(db),
      tool: tool,
    );

    controller.updateValue('resistance', 'bad value');
    final history = await controller.saveResult(controller.inputSummary());
    final note = await controller.saveNote();

    expect(history.status, ToolSaveStatus.inputInvalid);
    expect(history.message, contains('请先修正输入参数'));
    expect(history.message, contains('电阻 R'));
    expect(note.status, ToolSaveStatus.inputInvalid);
    expect(db.savedHistory, isEmpty);
    expect(db.savedNotes, isEmpty);
  });

  test('save result and note report not written rows and failures', () async {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final db = _FakeToolSaveDatabase(
      zeroNextHistoryWrite: true,
      zeroNextNoteWrite: true,
    );
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      toolUsageRepository: ToolUsageRepository(db),
      tool: tool,
    );

    final missingHistory =
        await controller.saveResult(controller.inputSummary());
    final missingNote = await controller.saveNote();
    expect(missingHistory.status, ToolSaveStatus.notWritten);
    expect(missingHistory.message, '历史记录没有写入，请重试');
    expect(missingNote.status, ToolSaveStatus.notWritten);
    expect(missingNote.message, '笔记没有写入，请重试');

    final failureDb = _FakeToolSaveDatabase(
      nextHistoryError: StateError('history locked'),
      nextNoteError: StateError('note locked'),
    );
    final failureController = ToolDetailController(
      historyRepository: HistoryRepository(failureDb),
      notesRepository: NotesRepository(failureDb),
      toolUsageRepository: ToolUsageRepository(failureDb),
      tool: tool,
    );
    final failedHistory =
        await failureController.saveResult(failureController.inputSummary());
    final failedNote = await failureController.saveNote();
    expect(failedHistory.status, ToolSaveStatus.failed);
    expect(failedHistory.message, contains('保存历史失败'));
    expect(failedNote.status, ToolSaveStatus.failed);
    expect(failedNote.message, contains('保存笔记失败'));
  });
}

class _FakeToolSaveDatabase implements AppDatabase {
  _FakeToolSaveDatabase({
    this.zeroNextHistoryWrite = false,
    this.zeroNextNoteWrite = false,
    this.nextHistoryError,
    this.nextNoteError,
  });

  final savedHistory = <Map<String, String>>[];
  final savedNotes = <Map<String, String>>[];
  bool zeroNextHistoryWrite;
  bool zeroNextNoteWrite;
  Object? nextHistoryError;
  Object? nextNoteError;

  @override
  Future<int> addHistory({
    required String expression,
    required String result,
    String? toolId,
    DateTime? createdAt,
  }) async {
    final error = nextHistoryError;
    if (error != null) {
      nextHistoryError = null;
      throw error;
    }
    if (zeroNextHistoryWrite) {
      zeroNextHistoryWrite = false;
      return 0;
    }
    savedHistory.add({
      'expression': expression,
      'result': result,
      if (toolId != null) 'toolId': toolId,
    });
    return savedHistory.length;
  }

  @override
  Future<int> addNote(
    String title,
    String body, {
    String description = '',
  }) async {
    final error = nextNoteError;
    if (error != null) {
      nextNoteError = null;
      throw error;
    }
    if (zeroNextNoteWrite) {
      zeroNextNoteWrite = false;
      return 0;
    }
    savedNotes.add({
      'title': title,
      'body': body,
      'description': description,
    });
    return savedNotes.length;
  }

  @override
  Future<Set<String>> favoriteToolIds() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
