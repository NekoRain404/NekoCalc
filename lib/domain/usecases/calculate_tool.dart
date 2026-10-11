import '../entities/tool_definition.dart';
import 'calculate_tool_basic_electronics.dart' as basic_electronics;
import 'calculate_tool_finance.dart' as finance;
import 'calculate_tool_lifestyle.dart' as lifestyle;
import 'calculate_tool_math.dart' as math_tools;
import 'calculate_tool_mechanical.dart' as mechanical;
import 'calculate_tool_physics.dart' as physics;
import 'calculate_tool_power.dart' as power;
import 'calculate_tool_signal.dart' as signal;
import 'calculate_tool_structure.dart' as structure;
import 'calculate_tool_units.dart' as units;

List<ToolResult> calculateTool(ToolDefinition tool, Map<String, double> v) {
  switch (tool.kind) {
    case ToolKind.quadratic:
      return math_tools.quadraticResults(v);
    case ToolKind.linearSystem:
      return math_tools.linearSystemResults(v);
    case ToolKind.percentage:
      return math_tools.percentageResults(v);
    case ToolKind.exponentialLog:
      return math_tools.exponentialLogResults(v);
    case ToolKind.linearEquation:
      return math_tools.linearEquationResults(v);
    case ToolKind.combination:
      return math_tools.combinationResults(v);
    case ToolKind.probability:
      return math_tools.probabilityResults(v);
    case ToolKind.statistics:
      return math_tools.statisticsResults(v);
    case ToolKind.matrix:
      return math_tools.matrixResults(v);
    case ToolKind.complex:
      return math_tools.complexResults(v);
    case ToolKind.vector:
      return math_tools.vectorResults(v);
    case ToolKind.triangle:
      return math_tools.triangleResults(v);
    case ToolKind.circle:
      return math_tools.circleResults(v);
    case ToolKind.scaleRatio:
      return math_tools.scaleRatioResults(v);
    case ToolKind.ohmsLaw:
      return basic_electronics.ohmsLawResults(v);
    case ToolKind.voltageDivider:
      return basic_electronics.voltageDividerResults(v);
    case ToolKind.rcFilter:
      return signal.rcFilterResults(v);
    case ToolKind.resistorNetwork:
      return basic_electronics.resistorNetworkResults(v);
    case ToolKind.capacitorNetwork:
      return basic_electronics.capacitorNetworkResults(v);
    case ToolKind.inductorNetwork:
      return basic_electronics.inductorNetworkResults(v);
    case ToolKind.ledResistor:
      return basic_electronics.ledResistorResults(v);
    case ToolKind.opAmpGain:
      return signal.opAmpGainResults(v);
    case ToolKind.adcResolution:
      return signal.adcResolutionResults(v);
    case ToolKind.rmsPeak:
      return signal.rmsPeakResults(v);
    case ToolKind.lcResonance:
      return signal.lcResonanceResults(v);
    case ToolKind.dcdcFeedback:
      return power.dcdcFeedbackResults(v);
    case ToolKind.ldoPower:
      return power.ldoPowerResults(v);
    case ToolKind.capacitorCharge:
      return signal.capacitorChargeResults(v);
    case ToolKind.batteryLife:
      return power.batteryLifeResults(v);
    case ToolKind.pcbCurrent:
      return power.pcbCurrentResults(v);
    case ToolKind.wireVoltageDrop:
      return power.wireVoltageDropResults(v);
    case ToolKind.timer555:
      return signal.timer555Results(v);
    case ToolKind.thermalRise:
      return power.thermalRiseResults(v);
    case ToolKind.gearRatio:
      return mechanical.gearRatioResults(v);
    case ToolKind.torquePower:
      return mechanical.torquePowerResults(v);
    case ToolKind.spring:
      return mechanical.springResults(v);
    case ToolKind.cylinder:
      return mechanical.cylinderResults(v);
    case ToolKind.force:
      return mechanical.forceResults(v);
    case ToolKind.pulleyRatio:
      return mechanical.pulleyRatioResults(v);
    case ToolKind.screwLead:
      return mechanical.screwLeadResults(v);
    case ToolKind.pressureForce:
      return structure.pressureForceResults(v);
    case ToolKind.friction:
      return structure.frictionResults(v);
    case ToolKind.inclinedPlane:
      return structure.inclinedPlaneResults(v);
    case ToolKind.beamBending:
      return structure.beamBendingResults(v);
    case ToolKind.stressStrain:
      return structure.stressStrainResults(v);
    case ToolKind.sectionArea:
      return structure.sectionAreaResults(v);
    case ToolKind.safetyFactor:
      return structure.safetyFactorResults(v);
    case ToolKind.flowVelocity:
      return structure.flowVelocityResults(v);
    case ToolKind.materialWeight:
      return structure.materialWeightResults(v);
    case ToolKind.loan:
      return finance.loanResults(v);
    case ToolKind.annuity:
      return finance.annuityResults(v);
    case ToolKind.installment:
      return finance.installmentResults(v);
    case ToolKind.breakEven:
      return finance.breakEvenResults(v);
    case ToolKind.electricityCost:
      return finance.electricityCostResults(v);
    case ToolKind.compound:
      return finance.compoundResults(v);
    case ToolKind.profitMargin:
      return finance.profitMarginResults(v);
    case ToolKind.roi:
      return finance.roiResults(v);
    case ToolKind.discount:
      return finance.discountResults(v);
    case ToolKind.tax:
      return finance.taxResults(v);
    case ToolKind.npv:
      return finance.npvResults(v);
    // 中文：**这一格是单位换算唯一留下的分支**（2026 那一轮：另外 21 个换算器并进了
    //       `unit_convert` 那张卡，它们在这里的分支与 `calculate_tool_units.dart` 里的表一起走了）。
    // English: **the one unit-conversion branch left** (that round folded the other 21 converters into
    //          the `unit_convert` card; their branches here went with their tables in
    //          `calculate_tool_units.dart`).
    case ToolKind.temperature:
      return units.temperatureResults(v);
    case ToolKind.motion:
      return physics.motionResults(v);
    case ToolKind.freeFall:
      return physics.freeFallResults(v);
    case ToolKind.workPower:
      return physics.workPowerResults(v);
    case ToolKind.kineticEnergy:
      return physics.kineticEnergyResults(v);
    case ToolKind.density:
      return physics.densityResults(v);
    case ToolKind.concentration:
      return physics.concentrationResults(v);
    case ToolKind.idealGas:
      return physics.idealGasResults(v);
    case ToolKind.heat:
      return physics.heatResults(v);
    case ToolKind.wavelength:
      return physics.wavelengthResults(v);
    case ToolKind.halfLife:
      return physics.halfLifeResults(v);
    case ToolKind.ph:
      return physics.phResults(v);
    case ToolKind.bmi:
      return lifestyle.bmiResults(v);
    case ToolKind.fuelEconomy:
      return lifestyle.fuelEconomyResults(v);
    case ToolKind.staticOnly:
      return const [ToolResult('文本工具', '请使用文本详情页', '', primary: true)];
  }
}
