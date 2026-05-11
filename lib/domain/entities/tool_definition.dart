import 'tool_category.dart';

enum ToolKind {
  quadratic,
  linearSystem,
  percentage,
  exponentialLog,
  probability,
  complex,
  vector,
  triangle,
  circle,
  scaleRatio,
  matrix,
  linearEquation,
  proportion,
  combination,
  statistics,
  ohmsLaw,
  voltageDivider,
  rcFilter,
  dbm,
  resistorNetwork,
  capacitorNetwork,
  inductorNetwork,
  ledResistor,
  opAmpGain,
  adcResolution,
  rmsPeak,
  lcResonance,
  dcdcFeedback,
  ldoPower,
  capacitorCharge,
  batteryLife,
  pcbCurrent,
  wireVoltageDrop,
  timer555,
  thermalRise,
  gearRatio,
  torquePower,
  spring,
  cylinder,
  force,
  pulleyRatio,
  screwLead,
  pressureForce,
  friction,
  inclinedPlane,
  beamBending,
  stressStrain,
  sectionArea,
  safetyFactor,
  flowVelocity,
  materialWeight,
  loan,
  annuity,
  installment,
  breakEven,
  electricityCost,
  compound,
  profitMargin,
  roi,
  discount,
  tax,
  inflation,
  npv,
  length,
  pressure,
  voltage,
  frequency,
  mass,
  area,
  volume,
  speed,
  temperature,
  dataSize,
  timeUnit,
  accelerationUnit,
  forceUnit,
  powerUnit,
  energyUnit,
  angleUnit,
  currentUnit,
  resistanceUnit,
  capacitanceUnit,
  inductanceUnit,
  torqueUnit,
  flowUnit,
  motion,
  freeFall,
  workPower,
  kineticEnergy,
  density,
  concentration,
  idealGas,
  heat,
  wavelength,
  halfLife,
  ph,
  bmi,
  fuelEconomy,
  staticOnly,
}

class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.kind,
    required this.inputs,
    required this.formula,
    required this.explanation,
    this.group = '常用',
    this.featured = false,
  });

  final String id;
  final String title;
  final String description;
  final ToolCategory category;
  final ToolKind kind;
  final List<ToolInputDefinition> inputs;
  final String formula;
  final String explanation;
  final String group;
  final bool featured;
}

class ToolInputDefinition {
  const ToolInputDefinition({
    required this.key,
    required this.label,
    required this.unit,
    this.defaultValue,
    this.optional = false,
  });

  final String key;
  final String label;
  final String unit;
  final double? defaultValue;
  final bool optional;
}

class ToolResult {
  const ToolResult(this.label, this.value, this.unit, {this.primary = false});

  final String label;
  final String value;
  final String unit;
  final bool primary;
}
