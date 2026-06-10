import 'dart:math' as math;

import '../../core/units/unit_converter.dart';
import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> lengthResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'm': 1,
    'nm': 1000000000,
    'μm': 1000000,
    'km': 0.001,
    'Mm': 0.000001,
    'cm': 100,
    'mm': 1000,
    'in': 39.3701,
    'ft': 3.28084,
    'yd': 1 / 0.9144,
    'mi': 1 / 1609.344,
  });
}

List<ToolResult> areaResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'm²': 1,
    'km²': 0.000001,
    'ha': 0.0001,
    '亩': 0.0015,
    'acre': 1 / 4046.8564224,
    'cm²': 10000,
    'mm²': 1000000,
    'ft²': 10.7639,
    'in²': 1550.0031,
    'yd²': 1 / 0.83612736,
  });
}

List<ToolResult> volumeResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'm³': 1,
    'L': 1000,
    'mL': 1000000,
    'cm³': 1000000,
    'mm³': 1000000000,
    'ft³': 35.3147,
    'in³': 61023.7441,
    'yd³': 1 / 0.764554857984,
    'gal': 264.172052,
    'qt': 1056.68821,
    'pt': 2113.37642,
    'fl oz': 33814.0227,
    'cup': 4226.75284,
    'tbsp': 67628.0454,
    'tsp': 202884.136,
  });
}

List<ToolResult> massResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'kg': 1,
    'g': 1000,
    'mg': 1000000,
    'Mg': 0.001,
    't': 0.001,
    'lb': 2.20462,
    'oz': 35.27396,
    '斤': 2,
  });
}

List<ToolResult> pressureResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'Pa': 1,
    'mPa': 1000,
    'kPa': 0.001,
    'MPa': 0.000001,
    'GPa': 0.000000001,
    'bar': 0.00001,
    'mbar': 0.01,
    'psi': 0.000145038,
    'atm': 1 / 101325,
    'mmHg': 1 / 133.322368,
    'kgf/cm²': 1 / 98066.5,
  });
}

List<ToolResult> speedResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'm/s': 1,
    'km/h': 3.6,
    'mph': 2.23694,
    'ft/s': 3.28084,
    'm/min': 60,
    'cm/s': 100,
    'kn': 1 / 0.5144444444444445,
  });
}

List<ToolResult> temperatureResults(Map<String, double> valuesByKey) {
  final celsius = valuesByKey['value'] ?? 0;
  return [
    ToolResult('℃', formatNumber(celsius), '℃', primary: true),
    ToolResult('℉', formatNumber(celsius * 9 / 5 + 32), '℉'),
    ToolResult('K', formatNumber(celsius + 273.15), 'K'),
    ToolResult('°R', formatNumber((celsius + 273.15) * 9 / 5), '°R'),
  ];
}

List<ToolResult> voltageResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'V': 1,
    'mV': 1000,
    'kV': 0.001,
    'μV': 1000000,
    'MV': 0.000001,
  });
}

List<ToolResult> frequencyResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'mHz': 1000,
    'Hz': 1,
    'kHz': 0.001,
    'MHz': 0.000001,
    'GHz': 0.000000001,
    'THz': 0.000000000001,
  });
}

List<ToolResult> dataSizeResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'B': 1,
    'KB': 1 / 1000,
    'KiB': 1 / 1024,
    'MB': 1 / 1000000,
    'MiB': 1 / 1048576,
    'GB': 1 / 1000000000,
    'GiB': 1 / 1073741824,
    'TB': 1 / 1000000000000,
    'TiB': 1 / 1099511627776,
    'bit': 8,
    'Kbit': 8 / 1000,
    'Mbit': 8 / 1000000,
    'Gbit': 8 / 1000000000,
    'Tbit': 8 / 1000000000000,
  });
}

List<ToolResult> timeUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    's': 1,
    'ms': 1000,
    'μs': 1000000,
    'ns': 1000000000,
    'min': 1 / 60,
    'h': 1 / 3600,
    'day': 1 / 86400,
    'week': 1 / 604800,
  });
}

List<ToolResult> accelerationUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'm/s²': 1,
    'g': 1 / 9.80665,
    'ft/s²': 3.28084,
    'cm/s²': 100,
    'Gal': 100,
  });
}

List<ToolResult> forceUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'N': 1,
    'mN': 1000,
    'kN': 0.001,
    'MN': 0.000001,
    'kgf': 1 / 9.80665,
    'lbf': 0.224809,
  });
}

List<ToolResult> powerUnitResults(Map<String, double> valuesByKey) {
  final watts = valuesByKey['value'] ?? 0;
  return [
    ToolResult('W', formatNumber(watts), 'W', primary: true),
    ToolResult('mW', formatNumber(watts * 1000), 'mW'),
    ToolResult('kW', formatNumber(watts * 0.001), 'kW'),
    ToolResult('MW', formatNumber(watts * 0.000001), 'MW'),
    ToolResult('hp', formatNumber(watts * 0.00134102), 'hp'),
    ToolResult(
      'dBm',
      watts <= 0 ? '无效' : formatNumber(10 * math.log(watts * 1000) / math.ln10),
      'dBm',
    ),
    ToolResult(
      'dBW',
      watts <= 0 ? '无效' : formatNumber(10 * math.log(watts) / math.ln10),
      'dBW',
    ),
  ];
}

List<ToolResult> energyUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'J': 1,
    'kJ': 0.001,
    'cal': 1 / 4.184,
    'kcal': 1 / 4184,
    'BTU': 1 / 1055.05585262,
    'eV': 1 / 1.602176634e-19,
    'mWh': 1 / 3.6,
    'Wh': 1 / 3600,
    'kWh': 1 / 3600000,
    'MWh': 1 / 3600000000,
    '度': 1 / 3600000,
  });
}

List<ToolResult> angleUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'deg': 1,
    'rad': math.pi / 180,
    'turn': 1 / 360,
    'grad': 10 / 9,
    'arcmin': 60,
    'arcsec': 3600,
  });
}

List<ToolResult> currentUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'A': 1,
    'mA': 1000,
    'μA': 1000000,
    'nA': 1000000000,
    'kA': 0.001,
    'MA': 0.000001,
  });
}

List<ToolResult> resistanceUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'Ω': 1,
    'μΩ': 1000000,
    'mΩ': 1000,
    'kΩ': 0.001,
    'MΩ': 0.000001,
    'GΩ': 0.000000001,
  });
}

List<ToolResult> capacitanceUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'F': 1,
    'mF': 1000,
    'μF': 1000000,
    'nF': 1000000000,
    'pF': 1000000000000,
    'MF': 0.000001,
  });
}

List<ToolResult> inductanceUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'H': 1,
    'kH': 0.001,
    'mH': 1000,
    'μH': 1000000,
    'nH': 1000000000,
    'pH': 1000000000000,
    'MH': 0.000001,
  });
}

List<ToolResult> torqueUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'N·m': 1,
    'kN·m': 0.001,
    'mN·m': 1000,
    'N·mm': 1000,
    'kgf·m': 1 / 9.80665,
    'kgf·cm': 100 / 9.80665,
    'lbf·ft': 0.737562,
    'lbf·in': 8.85075,
    'ozf·in': 141.612,
  });
}

List<ToolResult> flowUnitResults(Map<String, double> valuesByKey) {
  return _unitResults(valuesByKey['value'] ?? 0, {
    'L/min': 1,
    'L/h': 60,
    'mL/min': 1000,
    'L/s': 1 / 60,
    'm³/h': 0.06,
    'm³/min': 0.001,
    'm³/s': 1 / 60000,
    'GPM': 0.264172,
    'CFM': 1 / 28.316846592,
  });
}

List<ToolResult> _unitResults(double value, Map<String, double> factors) {
  return UnitConverter(factors)
      .convert(value)
      .map((conversion) => ToolResult(
            conversion.unit,
            formatNumber(conversion.value),
            conversion.unit,
            primary: conversion.unit == factors.keys.first,
          ))
      .toList();
}
