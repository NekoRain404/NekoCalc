import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tools_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';

void main() {
  late ToolsController controller;

  setUp(() {
    controller = _controller();
  });

  test('search matches common aliases and pasted workflow terms', () {
    final jsonCsv = controller.searchTools('json to csv');
    final ndjson = controller.searchTools('ndjson');
    final jwt = controller.searchTools('jwt token');
    final textStats = controller.searchTools('word count');
    final dataFit = controller.searchTools('curve fitting');
    final batteryRuntime = controller.searchTools('Wh runtime');
    final targetRuntime = controller.searchTools('target runtime');
    final currentBudget = controller.searchTools('平均电流预算');
    final reserveMargin = controller.searchTools('reserve margin');
    final wattLoad = controller.searchTools('负载功率');
    final voltageDrop = controller.searchTools('wire voltage drop');
    final wireSizing = controller.searchTools('required wire gauge');
    final targetDrop = controller.searchTools('目标压降');
    final parallelWire = controller.searchTools('并联导线');
    final traceWidth = controller.searchTools('required trace width');
    final ipc2221 = controller.searchTools('IPC-2221');
    final innerLayer = controller.searchTools('内层降额');
    final buckFeedback = controller.searchTools('buck feedback');
    final targetOutputVoltage = controller.searchTools('target output voltage');
    final feedbackDivider = controller.searchTools('反馈分压');
    final ohmsPowerCurrent = controller.searchTools('power current resistance');
    final ohmsReverse = controller.searchTools('reverse ohms law');
    final ohmsChinese = controller.searchTools('欧姆反推');
    final dividerTarget = controller.searchTools('divider target output');
    final dividerRequiredResistor =
        controller.searchTools('voltage divider required resistor');
    final dividerLoad = controller.searchTools('负载分压');
    final ledSelectedResistor = controller.searchTools('selected resistor');
    final ledActualCurrent = controller.searchTools('actual led current');
    final ledChineseSelected = controller.searchTools('选用电阻 led');
    final targetCutoff = controller.searchTools('target cutoff frequency');
    final requiredCapacitor = controller.searchTools('rc required capacitor');
    final rcRequiredResistor = controller.searchTools('反推电阻 rc滤波');
    final rcCharge = controller.searchTools('rc charge');
    final resetCapacitor = controller.searchTools('reset capacitor');
    final targetChargeRatio = controller.searchTools('目标充电比例');
    final timer555 = controller.searchTools('555 astable');
    final targetDuty = controller.searchTools('target duty cycle');
    final timerResistors = controller.searchTools('反推电阻');
    final thermalMargin = controller.searchTools('thermal margin');
    final junctionTemperature = controller.searchTools('结温估算');
    final dropoutVoltage = controller.searchTools('dropout voltage');
    final quiescentCurrent = controller.searchTools('quiescent current');
    final staticCurrent = controller.searchTools('静态电流');
    final thermalRise = controller.searchTools('thermal rise');
    final thermalChinese = controller.searchTools('热阻温升');
    final thermalDerating = controller.searchTools('thermal derating');
    final targetJunction = controller.searchTools('目标结温');
    final targetThermalMargin = controller.searchTools('target thermal margin');

    expect(jsonCsv.first.tool.id, 'csv_json');
    // 中文：令牌，不是"别名"那两个字——理由与 `tools_controller_test.dart` 同一条。
    // English: the token, not the two characters; the reason is the same as in
    //          `tools_controller_test.dart`.
    expect(jsonCsv.first.matchLabel, ToolMatchTokens.alias);

    expect(ndjson.map((result) => result.tool.id), contains('json_format'));
    expect(ndjson.map((result) => result.tool.id), contains('csv_json'));

    expect(jwt.first.tool.id, 'jwt_decode');
    expect(textStats.first.tool.id, 'text_stats');
    expect(dataFit.first.tool.id, 'data_fit');
    expect(batteryRuntime.first.tool.id, 'battery_life');
    expect(targetRuntime.first.tool.id, 'battery_life');
    expect(currentBudget.first.tool.id, 'battery_life');
    expect(reserveMargin.first.tool.id, 'battery_life');
    expect(wattLoad.first.tool.id, 'battery_life');
    expect(voltageDrop.first.tool.id, 'wire_voltage_drop');
    expect(wireSizing.first.tool.id, 'wire_voltage_drop');
    expect(targetDrop.first.tool.id, 'wire_voltage_drop');
    expect(parallelWire.first.tool.id, 'wire_voltage_drop');
    expect(traceWidth.first.tool.id, 'pcb_current');
    expect(ipc2221.first.tool.id, 'pcb_current');
    expect(innerLayer.first.tool.id, 'pcb_current');
    expect(buckFeedback.first.tool.id, 'dcdc_feedback');
    expect(targetOutputVoltage.first.tool.id, 'dcdc_feedback');
    expect(feedbackDivider.first.tool.id, 'dcdc_feedback');
    expect(ohmsPowerCurrent.first.tool.id, 'ohms_law');
    expect(ohmsReverse.first.tool.id, 'ohms_law');
    expect(ohmsChinese.first.tool.id, 'ohms_law');
    expect(dividerTarget.first.tool.id, 'voltage_divider');
    expect(dividerRequiredResistor.first.tool.id, 'voltage_divider');
    expect(dividerLoad.first.tool.id, 'voltage_divider');
    expect(ledSelectedResistor.first.tool.id, 'led_resistor');
    expect(ledActualCurrent.first.tool.id, 'led_resistor');
    expect(ledChineseSelected.first.tool.id, 'led_resistor');
    expect(targetCutoff.first.tool.id, 'rc_filter');
    expect(requiredCapacitor.first.tool.id, 'rc_filter');
    expect(rcRequiredResistor.first.tool.id, 'rc_filter');
    expect(rcCharge.first.tool.id, 'capacitor_charge');
    expect(resetCapacitor.first.tool.id, 'capacitor_charge');
    expect(targetChargeRatio.first.tool.id, 'capacitor_charge');
    expect(timer555.first.tool.id, 'timer_555');
    expect(targetDuty.first.tool.id, 'timer_555');
    expect(timerResistors.first.tool.id, 'timer_555');
    expect(thermalMargin.first.tool.id, 'ldo_power');
    expect(junctionTemperature.first.tool.id, 'ldo_power');
    expect(dropoutVoltage.first.tool.id, 'ldo_power');
    expect(quiescentCurrent.first.tool.id, 'ldo_power');
    expect(staticCurrent.first.tool.id, 'ldo_power');
    expect(thermalRise.first.tool.id, 'thermal_rise');
    expect(thermalChinese.first.tool.id, 'thermal_rise');
    expect(thermalDerating.first.tool.id, 'thermal_rise');
    expect(targetJunction.first.tool.id, 'thermal_rise');
    expect(targetThermalMargin.first.tool.id, 'thermal_rise');
  });

  test('search matches data size binary and Chinese unit aliases', () {
    final mib = controller.searchTools('MiB');
    final megabit = controller.searchTools('megabit');
    final byteConverter = controller.searchTools('byte converter');
    final bitConverter = controller.searchTools('比特换算');
    final chinese = controller.searchTools('兆字节');

    expect(mib.first.tool.id, 'data_size');
    expect(megabit.first.tool.id, 'data_size');
    expect(byteConverter.first.tool.id, 'data_size');
    expect(bitConverter.first.tool.id, 'data_size');
    expect(chinese.first.tool.id, 'data_size');
  });

  test('search matches descriptive statistics terms', () {
    final median = controller.searchTools('中位数');
    final variance = controller.searchTools('variance');
    final standardDeviation = controller.searchTools('standard deviation');
    final cv = controller.searchTools('变异系数');

    expect(median.first.tool.id, 'statistics');
    expect(variance.first.tool.id, 'statistics');
    expect(standardDeviation.first.tool.id, 'statistics');
    expect(cv.first.tool.id, 'statistics');
  });

  test('search matches acid base chemistry terms', () {
    final poh = controller.searchTools('pOH');
    final hydroxide = controller.searchTools('氢氧根');
    final acidBase = controller.searchTools('acid base');
    final targetPh = controller.searchTools('target ph');

    expect(poh.first.tool.id, 'ph');
    expect(hydroxide.first.tool.id, 'ph');
    expect(acidBase.first.tool.id, 'ph');
    expect(targetPh.first.tool.id, 'ph');
  });

  test('search matches solution concentration and molarity terms', () {
    final molarity = controller.searchTools('molarity');
    final massConcentration = controller.searchTools('mass concentration');
    final molarMass = controller.searchTools('molar mass');
    final chineseSolution = controller.searchTools('溶液配制');
    final chineseMolarity = controller.searchTools('摩尔浓度');

    expect(molarity.first.tool.id, 'concentration');
    expect(massConcentration.first.tool.id, 'concentration');
    expect(molarMass.first.tool.id, 'concentration');
    expect(chineseSolution.first.tool.id, 'concentration');
    expect(chineseMolarity.first.tool.id, 'concentration');
  });

  test('search matches ideal gas law and reverse solve terms', () {
    final idealGasLaw = controller.searchTools('ideal gas law');
    final pvNrt = controller.searchTools('PV=nRT');
    final molarVolume = controller.searchTools('molar volume');
    final chineseEquation = controller.searchTools('理想气体状态方程');
    final reverseTemperature = controller.searchTools('反推温度');

    expect(idealGasLaw.first.tool.id, 'ideal_gas');
    expect(pvNrt.first.tool.id, 'ideal_gas');
    expect(molarVolume.first.tool.id, 'ideal_gas');
    expect(chineseEquation.first.tool.id, 'ideal_gas');
    expect(reverseTemperature.first.tool.id, 'ideal_gas');
  });

  test('search matches wavelength frequency and wave speed terms', () {
    final wavelength = controller.searchTools('frequency wavelength');
    final waveSpeed = controller.searchTools('wave speed');
    final angularFrequency = controller.searchTools('angular frequency');
    final chineseWaveNumber = controller.searchTools('波数');
    final reverseFrequency = controller.searchTools('反推频率');

    expect(wavelength.first.tool.id, 'wavelength');
    expect(waveSpeed.first.tool.id, 'wavelength');
    expect(angularFrequency.first.tool.id, 'wavelength');
    expect(chineseWaveNumber.first.tool.id, 'wavelength');
    expect(reverseFrequency.first.tool.id, 'wavelength');
  });

  test('search matches half life decay and reverse solve terms', () {
    final halfLife = controller.searchTools('half life');
    final radioactiveDecay = controller.searchTools('radioactive decay');
    final remainingRatio = controller.searchTools('remaining ratio');
    final decayConstant = controller.searchTools('decay constant');
    final reverseHalfLife = controller.searchTools('反推半衰期');
    final reverseTime = controller.searchTools('反推时间');

    expect(halfLife.first.tool.id, 'half_life');
    expect(radioactiveDecay.first.tool.id, 'half_life');
    expect(remainingRatio.first.tool.id, 'half_life');
    expect(decayConstant.first.tool.id, 'half_life');
    expect(reverseHalfLife.first.tool.id, 'half_life');
    expect(reverseTime.first.tool.id, 'half_life');
  });

  test('search matches heat specific heat and temperature change terms', () {
    final specificHeat = controller.searchTools('specific heat');
    final thermalEnergy = controller.searchTools('thermal energy');
    final temperatureChange = controller.searchTools('temperature change');
    final chineseSpecificHeat = controller.searchTools('比热容');
    final reverseTemperatureRise = controller.searchTools('反推温升');

    expect(specificHeat.first.tool.id, 'heat');
    expect(thermalEnergy.first.tool.id, 'heat');
    expect(temperatureChange.first.tool.id, 'heat');
    expect(chineseSpecificHeat.first.tool.id, 'heat');
    expect(reverseTemperatureRise.first.tool.id, 'heat');
  });

  test('search matches bmi health and waist ratio terms', () {
    final bodyMass = controller.searchTools('body mass index');
    final healthyWeight = controller.searchTools('健康体重');
    final waistRatio = controller.searchTools('waist height ratio');
    final bodySurfaceArea = controller.searchTools('body surface area');

    expect(bodyMass.first.tool.id, 'bmi');
    expect(healthyWeight.first.tool.id, 'bmi');
    expect(waistRatio.first.tool.id, 'bmi');
    expect(bodySurfaceArea.first.tool.id, 'bmi');
  });

  test('search matches fuel economy cost range and emissions terms', () {
    final fuelCost = controller.searchTools('fuel cost');
    final tankRange = controller.searchTools('满箱续航');
    final costPer100Km = controller.searchTools('百公里成本');
    final emissions = controller.searchTools('co2 emissions');
    final targetConsumption = controller.searchTools('target consumption');
    final reverseFuel = controller.searchTools('反推燃油');
    final reverseDistance = controller.searchTools('反推里程');

    expect(fuelCost.first.tool.id, 'fuel_economy');
    expect(tankRange.first.tool.id, 'fuel_economy');
    expect(costPer100Km.first.tool.id, 'fuel_economy');
    expect(emissions.first.tool.id, 'fuel_economy');
    expect(targetConsumption.first.tool.id, 'fuel_economy');
    expect(reverseFuel.first.tool.id, 'fuel_economy');
    expect(reverseDistance.first.tool.id, 'fuel_economy');
  });

  test('search matches electricity cost budget and reverse terms', () {
    final electricityCost = controller.searchTools('electricity cost');
    final electricBill = controller.searchTools('electric bill');
    final applianceCost = controller.searchTools('appliance cost');
    final targetBill = controller.searchTools('target bill');
    final chineseCost = controller.searchTools('电费计算');
    final reversePower = controller.searchTools('反推功率');
    final reverseRuntime = controller.searchTools('反推时长');
    final reversePrice = controller.searchTools('反推电价');

    expect(electricityCost.first.tool.id, 'electricity_cost');
    expect(electricBill.first.tool.id, 'electricity_cost');
    expect(applianceCost.first.tool.id, 'electricity_cost');
    expect(targetBill.first.tool.id, 'electricity_cost');
    expect(chineseCost.first.tool.id, 'electricity_cost');
    expect(reversePower.first.tool.id, 'electricity_cost');
    expect(reverseRuntime.first.tool.id, 'electricity_cost');
    expect(reversePrice.first.tool.id, 'electricity_cost');
  });

  test('search matches break even target units and reverse terms', () {
    final breakEven = controller.searchTools('break even point');
    final contribution = controller.searchTools('contribution margin');
    final targetUnits = controller.searchTools('target units');
    final chineseBreakEven = controller.searchTools('盈亏平衡点');
    final targetQuantity = controller.searchTools('目标销量');
    final reverseFixed = controller.searchTools('反推固定成本');
    final reversePrice = controller.searchTools('反推单价');
    final reverseVariable = controller.searchTools('反推变动成本');

    expect(breakEven.first.tool.id, 'break_even');
    expect(contribution.first.tool.id, 'break_even');
    expect(targetUnits.first.tool.id, 'break_even');
    expect(chineseBreakEven.first.tool.id, 'break_even');
    expect(targetQuantity.first.tool.id, 'break_even');
    expect(reverseFixed.first.tool.id, 'break_even');
    expect(reversePrice.first.tool.id, 'break_even');
    expect(reverseVariable.first.tool.id, 'break_even');
  });

  test('search matches profit margin markup and reverse terms', () {
    final grossMargin = controller.searchTools('gross margin');
    final markup = controller.searchTools('markup rate');
    final targetProfit = controller.searchTools('target profit');
    final requiredPrice = controller.searchTools('required price');
    final chineseMargin = controller.searchTools('毛利率');
    final reversePrice = controller.searchTools('反推售价');
    final reverseCost = controller.searchTools('反推成本');
    final targetMargin = controller.searchTools('目标毛利率');

    expect(grossMargin.first.tool.id, 'profit_margin');
    expect(markup.first.tool.id, 'profit_margin');
    expect(targetProfit.first.tool.id, 'profit_margin');
    expect(requiredPrice.first.tool.id, 'profit_margin');
    expect(chineseMargin.first.tool.id, 'profit_margin');
    expect(reversePrice.first.tool.id, 'profit_margin');
    expect(reverseCost.first.tool.id, 'profit_margin');
    expect(targetMargin.first.tool.id, 'profit_margin');
  });

  test('search matches compound interest target value and reverse terms', () {
    final compoundInterest = controller.searchTools('compound interest');
    final targetFutureValue = controller.searchTools('target future value');
    final requiredRate = controller.searchTools('required rate');
    final growthMultiple = controller.searchTools('growth multiple');
    final chineseTarget = controller.searchTools('目标终值');
    final reversePrincipal = controller.searchTools('反推本金');
    final reverseRate = controller.searchTools('反推年化收益');
    final reverseYears = controller.searchTools('反推年限');

    expect(compoundInterest.first.tool.id, 'compound');
    expect(targetFutureValue.first.tool.id, 'compound');
    expect(requiredRate.first.tool.id, 'compound');
    expect(growthMultiple.first.tool.id, 'compound');
    expect(chineseTarget.first.tool.id, 'compound');
    expect(reversePrincipal.first.tool.id, 'compound');
    expect(reverseRate.first.tool.id, 'compound');
    expect(reverseYears.first.tool.id, 'compound');
  });

  test('search matches roi annualized return and payback terms', () {
    final annualized = controller.searchTools('annualized roi');
    final payback = controller.searchTools('simple payback');
    final chineseAnnual = controller.searchTools('年化回报');
    final chinesePayback = controller.searchTools('简单回收期');
    final targetRoi = controller.searchTools('target roi');
    final reverseCost = controller.searchTools('反推投入');
    final requiredGain = controller.searchTools('required gain');

    expect(annualized.first.tool.id, 'roi');
    expect(payback.first.tool.id, 'roi');
    expect(chineseAnnual.first.tool.id, 'roi');
    expect(chinesePayback.first.tool.id, 'roi');
    expect(targetRoi.first.tool.id, 'roi');
    expect(reverseCost.first.tool.id, 'roi');
    expect(requiredGain.first.tool.id, 'roi');
  });

  test('search matches discount final price and reverse terms', () {
    final salePrice = controller.searchTools('sale price');
    final finalPrice = controller.searchTools('final price');
    final reverseDiscount = controller.searchTools('反推折扣');
    final reverseOriginal = controller.searchTools('反推原价');
    final couponPrice = controller.searchTools('券后价');

    expect(salePrice.first.tool.id, 'discount');
    expect(finalPrice.first.tool.id, 'discount');
    expect(reverseDiscount.first.tool.id, 'discount');
    expect(reverseOriginal.first.tool.id, 'discount');
    expect(couponPrice.first.tool.id, 'discount');
  });

  test('search matches tax included excluded and reverse terms', () {
    final taxIncluded = controller.searchTools('tax included');
    final grossNetTax = controller.searchTools('gross net tax');
    final vat = controller.searchTools('vat');
    final taxRate = controller.searchTools('tax rate');
    final includedChinese = controller.searchTools('含税');
    final taxSeparation = controller.searchTools('价税分离');
    final reverseRate = controller.searchTools('反推税率');
    final reverseNet = controller.searchTools('反推税前');

    expect(taxIncluded.first.tool.id, 'tax');
    expect(grossNetTax.first.tool.id, 'tax');
    expect(vat.first.tool.id, 'tax');
    expect(taxRate.first.tool.id, 'tax');
    expect(includedChinese.first.tool.id, 'tax');
    expect(taxSeparation.first.tool.id, 'tax');
    expect(reverseRate.first.tool.id, 'tax');
    expect(reverseNet.first.tool.id, 'tax');
  });

  test('search matches inflation purchasing power and reverse terms', () {
    final purchasingPower = controller.searchTools('purchasing power');
    final futureValue = controller.searchTools('future value');
    final cpi = controller.searchTools('cpi');
    final costOfLiving = controller.searchTools('cost of living');
    final futureEquivalent = controller.searchTools('未来等值');
    final reverseRate = controller.searchTools('反推通胀率');
    final reverseYears = controller.searchTools('反推年数');
    final purchasingPowerChinese = controller.searchTools('购买力折现');

    expect(purchasingPower.first.tool.id, 'inflation');
    expect(futureValue.first.tool.id, 'inflation');
    expect(cpi.first.tool.id, 'inflation');
    expect(costOfLiving.first.tool.id, 'inflation');
    expect(futureEquivalent.first.tool.id, 'inflation');
    expect(reverseRate.first.tool.id, 'inflation');
    expect(reverseYears.first.tool.id, 'inflation');
    expect(purchasingPowerChinese.first.tool.id, 'inflation');
  });

  test('search matches motion distance speed time and pace terms', () {
    final distanceTimeSpeed = controller.searchTools('distance time speed');
    final pace = controller.searchTools('pace calculator');
    final chinesePace = controller.searchTools('跑步配速');
    final threeInputs = controller.searchTools('三选二');

    expect(distanceTimeSpeed.first.tool.id, 'motion');
    expect(pace.first.tool.id, 'motion');
    expect(chinesePace.first.tool.id, 'motion');
    expect(threeInputs.first.tool.id, 'motion');
  });

  test('search matches kinetic potential and target energy terms', () {
    final kineticEnergy = controller.searchTools('kinetic energy');
    final potentialEnergy = controller.searchTools('potential energy');
    final targetTotalEnergy = controller.searchTools('target total energy');
    final chineseEquivalentHeight = controller.searchTools('等效高度');

    expect(kineticEnergy.first.tool.id, 'kinetic_energy');
    expect(potentialEnergy.first.tool.id, 'kinetic_energy');
    expect(targetTotalEnergy.first.tool.id, 'kinetic_energy');
    expect(chineseEquivalentHeight.first.tool.id, 'kinetic_energy');
  });

  test('search matches free fall impact and initial velocity terms', () {
    final fallTime = controller.searchTools('fall time');
    final impactEnergy = controller.searchTools('impact energy');
    final initialVelocity = controller.searchTools('initial velocity');
    final chineseImpact = controller.searchTools('冲击能量');
    final bufferForce = controller.searchTools('缓冲平均力');

    expect(fallTime.first.tool.id, 'free_fall');
    expect(impactEnergy.first.tool.id, 'free_fall');
    expect(initialVelocity.first.tool.id, 'free_fall');
    expect(chineseImpact.first.tool.id, 'free_fall');
    expect(bufferForce.first.tool.id, 'free_fall');
  });

  test('search matches work power efficiency and horsepower terms', () {
    final mechanicalWork = controller.searchTools('mechanical work');
    final efficiencyLoss = controller.searchTools('efficiency loss');
    final horsepower = controller.searchTools('horsepower');
    final chineseLoss = controller.searchTools('损耗功率');
    final targetPowerTime = controller.searchTools('目标功率所需时间');

    expect(mechanicalWork.first.tool.id, 'work_power');
    expect(efficiencyLoss.first.tool.id, 'work_power');
    expect(horsepower.map((result) => result.tool.id), contains('work_power'));
    expect(chineseLoss.first.tool.id, 'work_power');
    expect(targetPowerTime.first.tool.id, 'work_power');
  });

  test('search matches density mass volume and specific volume terms', () {
    final densityCalculator = controller.searchTools('density calculator');
    final massVolumeDensity = controller.searchTools('mass volume density');
    final specificVolume = controller.searchTools('specific volume');
    final chineseSpecificVolume = controller.searchTools('比容');
    final chineseBacksolve = controller.searchTools('体积反推');

    expect(densityCalculator.first.tool.id, 'density');
    expect(massVolumeDensity.first.tool.id, 'density');
    expect(specificVolume.first.tool.id, 'density');
    expect(chineseSpecificVolume.first.tool.id, 'density');
    expect(chineseBacksolve.first.tool.id, 'density');
  });

  test('search matches investment appraisal terms', () {
    final dcf = controller.searchTools('discounted cash flow');
    final payback = controller.searchTools('折现回收期');
    final profitability = controller.searchTools('profitability index');
    final cashFlow = controller.searchTools('现金流');

    expect(dcf.first.tool.id, 'npv');
    expect(payback.first.tool.id, 'npv');
    expect(profitability.first.tool.id, 'npv');
    expect(cashFlow.first.tool.id, 'npv');
  });

  test('search matches finance reverse planning terms', () {
    final targetMonthlyPayment = controller.searchTools('目标月供');
    final affordableLoan = controller.searchTools('affordable loan');
    final annuityContribution = controller.searchTools('required contribution');
    final targetAnnuity = controller.searchTools('目标定投');
    final affordablePrice = controller.searchTools('可承受价格');
    final reverseInstallmentFee =
        controller.searchTools('reverse installment fee');

    expect(targetMonthlyPayment.first.tool.id, 'loan');
    expect(affordableLoan.first.tool.id, 'loan');
    expect(annuityContribution.first.tool.id, 'annuity');
    expect(targetAnnuity.first.tool.id, 'annuity');
    expect(affordablePrice.first.tool.id, 'installment');
    expect(reverseInstallmentFee.first.tool.id, 'installment');
  });

  test('search matches math reverse and geometry terms', () {
    final percentChange = controller.searchTools('percent change');
    final reversePercent = controller.searchTools('反推百分比');
    final circleAreaRadius = controller.searchTools('area to radius');
    final chineseCircle = controller.searchTools('面积求半径');
    final drawingScale = controller.searchTools('drawing scale');
    final reverseScale = controller.searchTools('反推比例');
    final ruleOfThree = controller.searchTools('rule of three');
    final crossMultiplication = controller.searchTools('交叉相乘');
    final atLeastOne = controller.searchTools('at least one');
    final neitherEvent = controller.searchTools('都不发生');
    final inradius = controller.searchTools('inradius');
    final triangleType = controller.searchTools('三角形类型');
    final eigenvalue = controller.searchTools('eigenvalue');
    final matrixRank = controller.searchTools('矩阵秩');
    final complexDivision = controller.searchTools('complex division');
    final complexArgument = controller.searchTools('复数幅角');
    final vectorProjection = controller.searchTools('vector projection');
    final perpendicularVector = controller.searchTools('垂直向量');
    final cramersRule = controller.searchTools('cramers rule');
    final infiniteSolutions = controller.searchTools('无穷多解');
    final xIntercept = controller.searchTools('x intercept');
    final changeOfBase = controller.searchTools('换底公式');
    final nthRoot = controller.searchTools('nth root');
    final nChooseK = controller.searchTools('n choose k');
    final repeatedPermutation = controller.searchTools('可重复排列');

    expect(percentChange.first.tool.id, 'percentage');
    expect(reversePercent.first.tool.id, 'percentage');
    expect(circleAreaRadius.first.tool.id, 'circle');
    expect(chineseCircle.first.tool.id, 'circle');
    expect(drawingScale.first.tool.id, 'scale_ratio');
    expect(
        reverseScale.map((result) => result.tool.id), contains('scale_ratio'));
    expect(ruleOfThree.first.tool.id, 'proportion');
    expect(crossMultiplication.first.tool.id, 'proportion');
    expect(atLeastOne.first.tool.id, 'probability');
    expect(neitherEvent.first.tool.id, 'probability');
    expect(inradius.first.tool.id, 'triangle');
    expect(triangleType.first.tool.id, 'triangle');
    expect(eigenvalue.first.tool.id, 'matrix');
    expect(matrixRank.first.tool.id, 'matrix');
    expect(complexDivision.first.tool.id, 'complex');
    expect(complexArgument.first.tool.id, 'complex');
    expect(vectorProjection.first.tool.id, 'vector');
    expect(perpendicularVector.first.tool.id, 'vector');
    expect(cramersRule.first.tool.id, 'linear_system');
    expect(infiniteSolutions.first.tool.id, 'linear_system');
    expect(xIntercept.first.tool.id, 'linear_equation');
    expect(changeOfBase.first.tool.id, 'exponential_log');
    expect(nthRoot.first.tool.id, 'exponential_log');
    expect(nChooseK.first.tool.id, 'combination');
    expect(repeatedPermutation.first.tool.id, 'combination');
  });
}

ToolsController _controller([AppDatabase? db]) {
  return ToolsController(
    toolUsageRepository: ToolUsageRepository(db ?? AppDatabase.instance),
  );
}
