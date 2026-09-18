import 'dart:math' as math;

import '../entities/tool_definition.dart';

List<ToolResult> concentrationResults(Map<String, double> valuesByKey) {
  final massInput = valuesByKey['mass'];
  final volumeInput = valuesByKey['volume'];
  final molarMassInput = valuesByKey['molarMass'];
  final massConcentrationInput = valuesByKey['massConcentration'];
  final molarityInput = valuesByKey['molarity'];
  final validInputs = [
    massInput,
    volumeInput,
    massConcentrationInput,
    molarityInput,
  ].where((value) => value != null).length;
  if (validInputs < 2 ||
      (massInput != null && (massInput < 0 || !massInput.isFinite)) ||
      (volumeInput != null && (volumeInput <= 0 || !volumeInput.isFinite)) ||
      (molarMassInput != null &&
          (molarMassInput <= 0 || !molarMassInput.isFinite)) ||
      (massConcentrationInput != null &&
          (massConcentrationInput < 0 || !massConcentrationInput.isFinite)) ||
      (molarityInput != null &&
          (molarityInput < 0 || !molarityInput.isFinite))) {
    return _invalidConcentrationResults();
  }

  double? mass = massInput;
  double? volume = volumeInput;
  double? molarMass = molarMassInput;
  double? massConcentration = massConcentrationInput;
  double? molarity;
  String source;

  if (mass != null && volume != null) {
    massConcentration = volume == 0 ? null : mass / volume;
    source = _concentrationSource(
      '溶质量+体积',
      hasMassConcentrationReference: massConcentrationInput != null,
      hasMolarityReference: molarityInput != null,
    );
  } else if (mass != null && massConcentration != null) {
    if (massConcentration == 0) return _invalidConcentrationResults();
    volume = mass / massConcentration;
    source = _concentrationSource(
      '溶质量+质量浓度',
      hasMolarityReference: molarityInput != null,
    );
  } else if (volume != null && massConcentration != null) {
    mass = massConcentration * volume;
    source = _concentrationSource(
      '体积+质量浓度',
      hasMolarityReference: molarityInput != null,
    );
  } else if (mass != null && molarityInput != null && molarMass != null) {
    final derivedMassConcentration = molarityInput * molarMass;
    if (derivedMassConcentration == 0) return _invalidConcentrationResults();
    massConcentration = derivedMassConcentration;
    volume = mass / derivedMassConcentration;
    molarity = molarityInput;
    source = '溶质量+摩尔浓度';
  } else if (volume != null && molarityInput != null && molarMass != null) {
    massConcentration = molarityInput * molarMass;
    mass = massConcentration * volume;
    molarity = molarityInput;
    source = '体积+摩尔浓度';
  } else if (massConcentration != null &&
      molarityInput != null &&
      molarityInput > 0) {
    molarity = molarityInput;
    molarMass = massConcentration / molarityInput;
    source = molarMassInput == null ? '质量浓度+摩尔浓度' : '质量浓度+摩尔浓度，摩尔质量作参考';
  } else {
    return _invalidConcentrationResults();
  }

  if (massConcentration == null || !massConcentration.isFinite) {
    return _invalidConcentrationResults();
  }
  if (molarMass != null) {
    molarity = massConcentration / molarMass;
  }
  if (molarMass == null &&
      molarityInput != null &&
      molarityInput > 0 &&
      massConcentration > 0) {
    molarity = molarityInput;
    molarMass = massConcentration / molarityInput;
  }

  final amount = mass != null && molarMass != null ? mass / molarMass : null;
  final massConcentrationDelta = massConcentrationInput == null
      ? null
      : massConcentration - massConcentrationInput;
  final molarityDelta = molarityInput == null || molarity == null
      ? null
      : molarity - molarityInput;
  final molarMassDelta = molarMassInput == null || molarMass == null
      ? null
      : molarMass - molarMassInput;
  return [
    ToolResult.number('质量浓度', massConcentration, 'g/L', primary: true),
    ToolResult.number('mg/mL', massConcentration, 'mg/mL'),
    ToolResult.number('mg/L', massConcentration * 1000, 'mg/L'),
    ToolResult.number('摩尔浓度', molarity, 'mol/L'),
    ToolResult.number('溶质物质的量', amount, 'mol'),
    ToolResult.number('溶质量', mass, 'g'),
    ToolResult.number('溶液体积', volume == null ? null : volume * 1000, 'mL'),
    ToolResult.number('溶液体积 L', volume, 'L'),
    ToolResult.number('摩尔质量', molarMass, 'g/mol'),
    ToolResult('输入来源', source, ''),
    if (massConcentrationDelta != null)
      ToolResult.number('质量浓度差值', massConcentrationDelta, 'g/L'),
    if (molarityDelta != null)
      ToolResult.number('摩尔浓度差值', molarityDelta, 'mol/L'),
    if (molarMassDelta != null)
      ToolResult.number('摩尔质量差值', molarMassDelta, 'g/mol'),
  ];
}

List<ToolResult> _invalidConcentrationResults() {
  return const [
    ToolResult.invalid('质量浓度', 'g/L', primary: true),
    ToolResult.invalid('mg/mL', 'mg/mL'),
    ToolResult.invalid('mg/L', 'mg/L'),
    ToolResult.invalid('摩尔浓度', 'mol/L'),
    ToolResult.invalid('溶质物质的量', 'mol'),
    ToolResult.invalid('溶质量', 'g'),
    ToolResult.invalid('溶液体积', 'mL'),
    ToolResult.invalid('溶液体积 L', 'L'),
    ToolResult.invalid('摩尔质量', 'g/mol'),
    ToolResult.invalid('输入来源', ''),
  ];
}

String _concentrationSource(
  String source, {
  bool hasMassConcentrationReference = false,
  bool hasMolarityReference = false,
}) {
  final references = [
    if (hasMassConcentrationReference) '质量浓度',
    if (hasMolarityReference) '摩尔浓度',
  ];
  if (references.isEmpty) return source;
  return '$source，${references.join('、')}作参考';
}

List<ToolResult> idealGasResults(Map<String, double> valuesByKey) {
  const gasConstant = 8.314462618;
  final nInput = valuesByKey['n'];
  final tempInput = valuesByKey['temp'];
  final volumeInput = valuesByKey['volume'];
  final pressureInput = valuesByKey['pressure'];
  final validInputs = [
    nInput,
    tempInput,
    volumeInput,
    pressureInput,
  ].where((value) => value != null).length;
  if (validInputs < 3 ||
      (nInput != null && (nInput < 0 || !nInput.isFinite)) ||
      (tempInput != null && (tempInput <= 0 || !tempInput.isFinite)) ||
      (volumeInput != null && (volumeInput <= 0 || !volumeInput.isFinite)) ||
      (pressureInput != null &&
          (pressureInput <= 0 || !pressureInput.isFinite))) {
    return _invalidIdealGasResults();
  }

  double n;
  double temp;
  double volumeL;
  double pressureKpa;
  String source;
  if (nInput != null && tempInput != null && volumeInput != null) {
    n = nInput;
    temp = tempInput;
    volumeL = volumeInput;
    final volumeM3 = volumeL / 1000;
    pressureKpa = n * gasConstant * temp / volumeM3 / 1000;
    source = pressureInput == null ? '物质的量+温度+体积' : '物质的量+温度+体积，压力作参考';
  } else if (pressureInput != null &&
      tempInput != null &&
      volumeInput != null) {
    pressureKpa = pressureInput;
    temp = tempInput;
    volumeL = volumeInput;
    n = pressureKpa * 1000 * (volumeL / 1000) / (gasConstant * temp);
    source = '压力+温度+体积';
  } else if (pressureInput != null && nInput != null && volumeInput != null) {
    pressureKpa = pressureInput;
    n = nInput;
    volumeL = volumeInput;
    if (n == 0) return _invalidIdealGasResults();
    temp = pressureKpa * 1000 * (volumeL / 1000) / (n * gasConstant);
    source = '压力+物质的量+体积';
  } else if (pressureInput != null && nInput != null && tempInput != null) {
    pressureKpa = pressureInput;
    n = nInput;
    temp = tempInput;
    volumeL = n * gasConstant * temp / (pressureKpa * 1000) * 1000;
    source = '压力+物质的量+温度';
  } else {
    return _invalidIdealGasResults();
  }

  final pressureDelta =
      pressureInput == null ? null : pressureKpa - pressureInput;
  return [
    ToolResult.number('压力', pressureKpa, 'kPa', primary: true),
    ToolResult.number('压力 atm', pressureKpa * 1000 / 101325, 'atm'),
    ToolResult.number('压力 Pa', pressureKpa * 1000, 'Pa'),
    ToolResult.number('体积', volumeL / 1000, 'm³'),
    ToolResult.number('体积 L', volumeL, 'L'),
    ToolResult.number('温度', temp - 273.15, '℃'),
    ToolResult.number('温度 K', temp, 'K'),
    ToolResult.number('物质的量', n, 'mol'),
    ToolResult.number('摩尔体积', n == 0 ? null : volumeL / n, 'L/mol'),
    ToolResult.number('分子数', n * 6.02214076e23, ''),
    ToolResult('输入来源', source, ''),
    if (pressureDelta != null) ToolResult.number('压力差值', pressureDelta, 'kPa'),
  ];
}

List<ToolResult> _invalidIdealGasResults() {
  return const [
    ToolResult.invalid('压力', 'kPa', primary: true),
    ToolResult.invalid('压力 atm', 'atm'),
    ToolResult.invalid('压力 Pa', 'Pa'),
    ToolResult.invalid('体积', 'm³'),
    ToolResult.invalid('体积 L', 'L'),
    ToolResult.invalid('温度', '℃'),
    ToolResult.invalid('温度 K', 'K'),
    ToolResult.invalid('物质的量', 'mol'),
    ToolResult.invalid('摩尔体积', 'L/mol'),
    ToolResult.invalid('分子数', ''),
    ToolResult.invalid('输入来源', ''),
  ];
}

List<ToolResult> heatResults(Map<String, double> valuesByKey) {
  final massInput = valuesByKey['mass'];
  final specificInput = valuesByKey['specific'];
  final deltaInput = valuesByKey['delta'];
  final heatInput = valuesByKey['heat'];
  final validInputs = [
    massInput,
    specificInput,
    deltaInput,
    heatInput,
  ].where((value) => value != null).length;
  if (validInputs < 3 ||
      (massInput != null && (massInput < 0 || !massInput.isFinite)) ||
      (specificInput != null &&
          (specificInput < 0 || !specificInput.isFinite)) ||
      (deltaInput != null && !deltaInput.isFinite) ||
      (heatInput != null && !heatInput.isFinite)) {
    return _invalidHeatResults();
  }

  double mass;
  double specific;
  double delta;
  double heat;
  String source;
  if (massInput != null && specificInput != null && deltaInput != null) {
    mass = massInput;
    specific = specificInput;
    delta = deltaInput;
    heat = mass * specific * delta;
    source = heatInput == null ? '质量+比热容+温度变化' : '质量+比热容+温度变化，热量作参考';
  } else if (heatInput != null && specificInput != null && deltaInput != null) {
    if (specificInput == 0 || deltaInput == 0) return _invalidHeatResults();
    heat = heatInput;
    specific = specificInput;
    delta = deltaInput;
    mass = heat / (specific * delta);
    if (mass < 0) return _invalidHeatResults();
    source = '热量+比热容+温度变化';
  } else if (heatInput != null && massInput != null && deltaInput != null) {
    if (massInput == 0 || deltaInput == 0) return _invalidHeatResults();
    heat = heatInput;
    mass = massInput;
    delta = deltaInput;
    specific = heat / (mass * delta);
    if (specific < 0) return _invalidHeatResults();
    source = '热量+质量+温度变化';
  } else if (heatInput != null && massInput != null && specificInput != null) {
    if (massInput == 0 || specificInput == 0) return _invalidHeatResults();
    heat = heatInput;
    mass = massInput;
    specific = specificInput;
    delta = heat / (mass * specific);
    source = '热量+质量+比热容';
  } else {
    return _invalidHeatResults();
  }

  final heatDelta = heatInput == null ? null : heat - heatInput;
  return [
    ToolResult.number('热量', heat, 'J', primary: true),
    ToolResult.number('kJ', heat / 1000, 'kJ'),
    ToolResult.number('Wh', heat / 3600, 'Wh'),
    ToolResult.number('kcal', heat / 4184, 'kcal'),
    ToolResult.number('质量', mass, 'kg'),
    ToolResult.number('比热容', specific, 'J/kg℃'),
    ToolResult.number('温度变化', delta, '℃'),
    ToolResult('热过程', heat > 0 ? '吸热' : (heat < 0 ? '放热' : '无热量'), ''),
    ToolResult('输入来源', source, ''),
    if (heatDelta != null) ToolResult.number('热量差值', heatDelta, 'J'),
  ];
}

List<ToolResult> _invalidHeatResults() {
  return const [
    ToolResult.invalid('热量', 'J', primary: true),
    ToolResult.invalid('kJ', 'kJ'),
    ToolResult.invalid('Wh', 'Wh'),
    ToolResult.invalid('kcal', 'kcal'),
    ToolResult.invalid('质量', 'kg'),
    ToolResult.invalid('比热容', 'J/kg℃'),
    ToolResult.invalid('温度变化', '℃'),
    ToolResult.invalid('热过程', ''),
    ToolResult.invalid('输入来源', ''),
  ];
}

List<ToolResult> phResults(Map<String, double> valuesByKey) {
  const kw = 1e-14;
  final directPh = valuesByKey['ph'];
  final hInput = valuesByKey['h'];
  final ohInput = valuesByKey['oh'];
  final targetPh = valuesByKey['targetPh'];
  final includeTarget = targetPh != null;
  double? ph;
  String source;

  if (targetPh != null && !targetPh.isFinite) {
    return _invalidPhResults(includeTarget: includeTarget);
  }
  if (directPh != null) {
    if (!directPh.isFinite) {
      return _invalidPhResults(includeTarget: includeTarget);
    }
    ph = directPh;
    source = 'pH';
  } else if (hInput != null) {
    if (hInput <= 0 || !hInput.isFinite) {
      return _invalidPhResults(includeTarget: includeTarget);
    }
    ph = -math.log(hInput) / math.ln10;
    source = '[H+]';
  } else if (ohInput != null) {
    if (ohInput <= 0 || !ohInput.isFinite) {
      return _invalidPhResults(includeTarget: includeTarget);
    }
    final poh = -math.log(ohInput) / math.ln10;
    ph = 14 - poh;
    source = '[OH-]';
  } else {
    return _invalidPhResults(includeTarget: includeTarget);
  }

  final poh = 14 - ph;
  final h = math.pow(10, -ph).toDouble();
  final oh = kw / h;
  final hNm = h * 1e9;
  final ohNm = oh * 1e9;
  final targetH = targetPh == null ? null : math.pow(10, -targetPh).toDouble();
  final targetOh = targetH == null ? null : kw / targetH;
  final type = ph < 6.8
      ? '酸性'
      : ph > 7.2
          ? '碱性'
          : '近中性';
  return [
    ToolResult.number('pH', ph, '', primary: true),
    ToolResult.number('pOH', poh, ''),
    ToolResult.number('[H+]', h, 'mol/L'),
    ToolResult.number('[OH-]', oh, 'mol/L'),
    ToolResult.number('[H+] nmol/L', hNm, 'nmol/L'),
    ToolResult.number('[OH-] nmol/L', ohNm, 'nmol/L'),
    ToolResult('酸碱性', type, ''),
    ToolResult('输入来源', source, ''),
    if (includeTarget) ToolResult.number('目标pH', targetPh, ''),
    if (targetH != null) ToolResult.number('目标[H+]', targetH, 'mol/L'),
    if (targetOh != null) ToolResult.number('目标[OH-]', targetOh, 'mol/L'),
    if (includeTarget) ToolResult.number('pH差值', ph - targetPh, ''),
  ];
}

List<ToolResult> _invalidPhResults({required bool includeTarget}) {
  return [
    const ToolResult.invalid('pH', '', primary: true),
    const ToolResult.invalid('pOH', ''),
    const ToolResult.invalid('[H+]', 'mol/L'),
    const ToolResult.invalid('[OH-]', 'mol/L'),
    const ToolResult.invalid('酸碱性', ''),
    if (includeTarget) const ToolResult.invalid('目标pH', ''),
    if (includeTarget) const ToolResult.invalid('目标[H+]', 'mol/L'),
    if (includeTarget) const ToolResult.invalid('目标[OH-]', 'mol/L'),
    if (includeTarget) const ToolResult.invalid('pH差值', ''),
  ];
}
