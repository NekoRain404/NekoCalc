import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';
import 'tool_insight_result_readers.dart';

bool isElectronicsInsightTool(ToolKind kind) {
  switch (kind) {
    case ToolKind.ohmsLaw:
    case ToolKind.voltageDivider:
    case ToolKind.rcFilter:
    case ToolKind.dbm:
    case ToolKind.resistorNetwork:
    case ToolKind.capacitorNetwork:
    case ToolKind.inductorNetwork:
    case ToolKind.ledResistor:
    case ToolKind.opAmpGain:
    case ToolKind.adcResolution:
    case ToolKind.rmsPeak:
    case ToolKind.lcResonance:
    case ToolKind.dcdcFeedback:
    case ToolKind.ldoPower:
    case ToolKind.capacitorCharge:
    case ToolKind.batteryLife:
    case ToolKind.pcbCurrent:
    case ToolKind.wireVoltageDrop:
    case ToolKind.timer555:
    case ToolKind.thermalRise:
      return true;
    default:
      return false;
  }
}

List<String> buildElectronicsToolInsights(
  ToolKind kind,
  Map<String, double> v,
  List<ToolResult> results,
) {
  final lines = <String>[];
  switch (kind) {
    case ToolKind.ohmsLaw:
      final voltageText = toolResultText(results, '电压 V');
      final power = toolResultNumber(results, '功率 P');
      final resistance = v['resistance'] ?? 0;
      final current = v['current'] ?? 0;
      final source = toolResultText(results, '输入来源');
      if (voltageText == '无效') {
        lines.add('电压、电流、电阻、功率至少填写两项；电阻必须大于 0，功率不能为负');
      }
      if (current < 0) {
        lines.add('电流为负表示参考方向相反，功耗仍按 I²R 取正值');
      }
      if (power != null && power > 0.25) {
        lines.add('功耗超过 0.25W，需按电阻额定功率、温升和散热条件留余量');
      }
      if (resistance > 0 && resistance < 1) {
        lines.add('电阻低于 1Ω 时，导线、接触电阻和电流表压降会明显影响结果');
      }
      if (source != null && source != '无效') {
        lines.add('当前按 $source 反推欧姆定律其它量');
      }
      lines.add('结果按理想电阻计算，实际还要看容差、温漂、脉冲功率和耐压');
    case ToolKind.voltageDivider:
      final voutText = toolResultText(results, '输出电压');
      final unloaded = toolResultNumber(results, '空载输出');
      final loaded = toolResultNumber(results, '输出电压');
      final dividerCurrent = toolResultNumber(results, '分压电流');
      final targetText = toolResultText(results, '目标输出电压');
      final outputDelta = toolResultNumber(results, '输出偏差');
      if (voutText == '无效') {
        lines.add('R1、R2 必须大于 0，负载电阻不能为负，目标输出必须在 Vin 可达范围内');
      }
      if (targetText == '无效') {
        lines.add('目标输出需要与 Vin 同极性，且绝对值必须低于 Vin');
      }
      lines.add(
          (v['load'] ?? 0) <= 0 ? '未接负载，Vout 是空载值' : '负载已并到下臂电阻，Vout 会被拉低');
      if (outputDelta != null && outputDelta.abs() > 1e-9) {
        lines.add('当前输出与目标相差 ${formatNumber(outputDelta)}V');
      }
      if (unloaded != null && loaded != null && unloaded != 0) {
        final loadDrop = (unloaded - loaded).abs() / unloaded.abs() * 100;
        if (loadDrop > 5) {
          lines.add('负载使输出偏离空载值超过 5%，应降低分压电阻或加缓冲');
        }
      }
      if (dividerCurrent != null &&
          dividerCurrent > 0 &&
          dividerCurrent < 0.05) {
        lines.add('分压电流低于 50μA，漏电流、ADC 采样电流和噪声会明显影响结果');
      }
      if (v['targetVout'] != null) {
        lines.add('目标反推会计入负载并联；实际选用 E 系列阻值后仍需复算误差和功耗');
      }
      lines.add('分压电流太小会让负载和 ADC 采样电流明显影响结果');
    case ToolKind.rcFilter:
      final fcText = toolResultText(results, '截止频率 fc');
      final frequencyDelta = toolResultNumber(results, '频率偏差');
      final tol = (v['tol'] ?? 0).abs();
      if (fcText == '无效') {
        lines.add('R、C 和目标截止频率都必须大于 0，才能计算 RC 截止频率');
      }
      if (tol > 20) lines.add('元件公差超过 20%，fc 范围只能作为粗略边界');
      if (frequencyDelta != null && frequencyDelta.abs() > 1e-9) {
        lines.add('当前截止频率与目标相差 ${formatNumber(frequencyDelta)}Hz');
      }
      lines.add('fc 是 -3dB 点；R、C 公差会按乘积放大到截止频率上');
      if (v['targetFc'] != null) {
        lines.add('目标反推按理想一阶 RC 计算，实际还要按 E 系列标称值和源/负载阻抗修正');
      }
      lines.add('低通和高通共用同一个 fc，取样节点不同');
    case ToolKind.dbm:
      final powerText = toolResultText(results, '功率');
      final mw = toolResultNumber(results, '功率');
      final dbm = v['dbm'] ?? 0;
      if (powerText == '无效') {
        lines.add('dBm 输入必须是有限数值');
      }
      if (mw != null && mw > 1000) {
        lines.add('功率超过 1W，需确认衰减器、负载额定功率和射频安全余量');
      }
      if (dbm < -100) {
        lines.add('低于 -100dBm 时，噪声底、带宽和接收机噪声系数通常决定可测性');
      }
      lines.add('50Ω 电压按正弦波和匹配负载估算；开路电压、峰值和调制信号要另行校核');
    case ToolKind.resistorNetwork:
      final seriesText = toolResultText(results, '串联等效');
      if (seriesText == '无效') {
        lines.add('R1、R2 和目标等效值都必须大于 0，才能计算串并联或反推元件值');
      }
      if (toolResultText(results, '串联目标所需R2') == '无效') {
        lines.add('目标串联等效必须大于 R1，才有正的 R2 解');
      }
      if (toolResultText(results, '并联目标所需R2') == '无效') {
        lines.add('目标并联等效必须小于 R1，才有正的 R2 解');
      }
      lines.add('电阻串并联还要分别核对单个电阻的功耗、耐压和温漂');
    case ToolKind.capacitorNetwork:
      final parallelText = toolResultText(results, '并联等效');
      if (parallelText == '无效') {
        lines.add('C1、C2 和目标等效值都必须大于 0，才能计算串并联或反推元件值');
      }
      if (toolResultText(results, '并联目标所需C2') == '无效') {
        lines.add('目标并联等效必须大于 C1，才有正的 C2 解');
      }
      if (toolResultText(results, '串联目标所需C2') == '无效') {
        lines.add('目标串联等效必须小于 C1，才有正的 C2 解');
      }
      lines.add('电容串联等效小于最小电容，耐压可分摊但漏电差异会影响均压');
    case ToolKind.inductorNetwork:
      final inductorSeriesText = toolResultText(results, '串联等效');
      if (inductorSeriesText == '无效') {
        lines.add('L1、L2 和目标等效值都必须大于 0，才能计算串并联或反推元件值');
      }
      if (toolResultText(results, '串联目标所需L2') == '无效') {
        lines.add('目标串联等效必须大于 L1，才有正的 L2 解');
      }
      if (toolResultText(results, '并联目标所需L2') == '无效') {
        lines.add('目标并联等效必须小于 L1，才有正的 L2 解');
      }
      lines.add('电感并联忽略互感、DCR 和饱和电流差异，只适合快速估算');
    case ToolKind.ledResistor:
      final vin = v['vin'] ?? 0;
      final vf = v['vf'] ?? 0;
      final current = v['current'] ?? 0;
      final actualCurrent = toolResultNumber(results, '实际电流');
      final currentDelta = toolResultNumber(results, '电流偏差');
      if (vin <= vf) lines.add('Vin 不高于 Vf，LED 可能无法稳定导通');
      if (current > 20) lines.add('目标电流超过 20mA，请确认 LED 额定值和温升');
      if (actualCurrent != null && actualCurrent > 20) {
        lines.add('选用电阻下的实际电流超过 20mA，请确认 LED 额定值和散热');
      }
      if (currentDelta != null && current != 0) {
        final deltaPercent = currentDelta / current * 100;
        if (deltaPercent.abs() > 10) {
          lines.add('选用电阻使实际电流偏离目标 ${formatNumber(deltaPercent)}%');
        }
      }
      if (v['selectedResistance'] != null) {
        lines.add('选用电阻校核按标称阻值计算，实际还受电阻公差、LED Vf 离散和温升影响');
      }
      lines.add('电阻功率建议留至少 2 倍余量');
    case ToolKind.opAmpGain:
      final gainText = toolResultText(results, '同相增益');
      final nonInvertingGain = toolResultNumber(results, '同相增益');
      final ratio = toolResultNumber(results, '电阻比');
      final feedbackTotal = toolResultNumber(results, '反馈总阻值');
      final closedLoopBandwidth = toolResultNumber(results, '同相闭环带宽');
      final slewRate = toolResultNumber(results, '所需压摆率');
      if (gainText == '无效') {
        lines.add('Rin 必须大于 0，Rf 不能为负；目标同相增益必须大于 1，GBW 和频率参数不能为负');
      }
      if (ratio == 0) {
        lines.add('Rf 为 0 时，同相接法退化为电压跟随器，反相接法输出接近 0');
      }
      if (nonInvertingGain != null && nonInvertingGain > 100) {
        lines.add('闭环增益超过 100 倍，需按增益带宽积校核带宽、相位裕度和噪声');
      }
      if (feedbackTotal != null && feedbackTotal > 1000) {
        lines.add('反馈网络总阻值超过 1MΩ，输入偏置电流和寄生电容会明显影响误差与稳定性');
      } else if (feedbackTotal != null && feedbackTotal < 2) {
        lines.add('反馈网络总阻值低于 2kΩ，会增加输出负载和静态功耗');
      }
      if (toolResultText(results, '目标所需Rf') != null) {
        lines.add('目标同相增益按保留 Rin 反推 Rf；反相目标结果只按增益幅值估算');
      }
      if (closedLoopBandwidth != null && closedLoopBandwidth < 1000) {
        lines.add('估算闭环带宽低于 1kHz，快速信号会被明显衰减');
      }
      if (slewRate != null && slewRate > 10) {
        lines.add('所需压摆率超过 10V/μs，请核对运放 SR 规格和输出幅度');
      }
      lines.add('结果是理想增益，实际还受供电轨、输入范围、带宽和压摆率限制');
    case ToolKind.adcResolution:
      final lsbText = toolResultText(results, 'LSB');
      final bits = (v['bits'] ?? 0).round();
      final inputState = toolResultText(results, '输入状态');
      final enob = toolResultNumber(results, 'ENOB');
      if (lsbText == '无效') {
        lines.add('参考电压必须大于 0，位数建议在 1 到 32 bit');
        if (v['enob'] != null) {
          lines.add('ENOB 必须大于 0 且不能大于标称位数');
        }
      }
      if (bits > 0 && bits < 8) {
        lines.add('ADC 位数低于 8 bit，控制量和慢速测量会明显看到量化台阶');
      }
      if (bits > 24) {
        lines.add('位数超过 24 bit 时，实际 ENOB、噪声和参考源稳定度通常达不到理论值');
      }
      if (inputState == '超量程') {
        lines.add('输入电压超出 0~Vref，实际 ADC 会夹到端点码或触发前端保护');
      }
      if (enob != null && bits - enob >= 2) {
        lines.add('ENOB 比标称位数低 2 bit 以上，噪声和前端误差会明显降低有效分辨率');
      }
      lines.add('LSB 是理论步进，ENOB 会被噪声、参考源和前端阻抗拉低');
    case ToolKind.rmsPeak:
      final peakText = toolResultText(results, 'Vpeak');
      final dbvText = toolResultText(results, 'dBV');
      final power50 = toolResultNumber(results, '50Ω 功率');
      final source = toolResultText(results, '输入来源') ?? '';
      final vpeakDelta = toolResultNumber(results, 'Vpeak差值');
      final vppDelta = toolResultNumber(results, 'Vpp差值');
      final dbmDelta = toolResultNumber(results, '50Ω dBm差值');
      if (peakText == '无效') {
        lines.add('Vrms、Vpeak、Vpp 不能为负，50Ω dBm 必须是有限数值');
      }
      if (dbvText == '无效' && peakText != '无效') {
        lines.add('0V 信号没有可定义的 dBV、dBu 或 dBm 对数值');
      }
      if (power50 != null && power50 > 1000) {
        lines.add('50Ω 功率超过 1W，需确认负载额定功率、端接和信号源驱动能力');
      }
      if (source.isNotEmpty && source != '无效') {
        lines.add('当前按 $source 反推其它正弦波幅值');
      }
      if (vpeakDelta != null && vpeakDelta.abs() > 1e-9) {
        lines.add('Vpeak 参考值与当前计算相差 ${formatNumber(vpeakDelta)}V');
      }
      if (vppDelta != null && vppDelta.abs() > 1e-9) {
        lines.add('Vpp 参考值与当前计算相差 ${formatNumber(vppDelta)}V');
      }
      if (dbmDelta != null && dbmDelta.abs() > 1e-9) {
        lines.add('50Ω dBm 参考值与当前计算相差 ${formatNumber(dbmDelta)}dB');
      }
      lines.add('这些换算只适用于纯正弦波；方波、脉冲和任意波形的 RMS/峰值关系不同');
    case ToolKind.lcResonance:
      final resonanceText = toolResultText(results, '谐振频率');
      final resonanceHz = toolResultNumber(results, '谐振频率');
      final q = toolResultNumber(results, 'Q值(串联)');
      final bandwidth = toolResultNumber(results, '3dB带宽');
      if (resonanceText == '无效') {
        lines.add('L 和 C 必须大于 0，ESR 不能为负，才能计算 LC 谐振频率');
      }
      if (resonanceHz != null && resonanceHz > 10000000) {
        lines.add('谐振频率超过 10MHz，寄生电容、电感和布局会明显改变结果');
      }
      if ((v['esr'] ?? 0) <= 0) {
        lines.add('未填写 ESR，Q 值和 3dB 带宽不会按损耗估算');
      }
      if (q != null && q < 5) {
        lines.add('串联 Q 值低于 5，谐振峰较钝，选频或振荡用途需要降低 ESR');
      }
      if (bandwidth != null && resonanceHz != null && resonanceHz > 0) {
        lines.add(
            '3dB 带宽约为中心频率的 ${formatNumber(bandwidth / resonanceHz * 100)}%');
      }
      lines.add('DCR、ESR 和寄生参数会降低 Q 值并移动峰值频率；并联谐振还需按等效并联损耗换算');
    case ToolKind.dcdcFeedback:
      final outputText = toolResultText(results, '输出电压');
      final feedbackCurrent = toolResultNumber(results, '反馈电流');
      final outputError = toolResultNumber(results, '输出偏差比例');
      final currentDelta = toolResultNumber(results, '反馈电流偏差');
      final targetVout = v['targetVout'];
      final targetCurrent = v['targetCurrent'];
      if (outputText == '无效') {
        lines.add('Vref 必须大于 0，Rbottom 必须大于 0，Rtop 不能为负，目标输出不能低于 Vref');
      }
      if (outputError != null && outputError.abs() > 1) {
        lines.add('当前反馈电阻相对目标输出偏差超过 1%，需要重选阻值或检查芯片反馈精度');
      }
      if (targetCurrent != null &&
          currentDelta != null &&
          currentDelta.abs() > targetCurrent * 0.2) {
        lines.add('当前反馈电流与目标反馈电流相差超过 20%，静态功耗和抗噪能力会偏离预算');
      }
      if (feedbackCurrent != null &&
          feedbackCurrent > 0 &&
          feedbackCurrent < 0.01) {
        lines.add('反馈电流低于 10μA，FB 漏电流和噪声会明显影响输出精度');
      }
      if (feedbackCurrent != null && feedbackCurrent > 1) {
        lines.add('反馈电流超过 1mA，会增加静态功耗，通常只在抗噪需求高时使用');
      }
      if (targetVout != null && targetCurrent == null) {
        lines.add('填写目标反馈电流后，可同时按目标输出反推上下拉电阻和反馈功耗');
      }
      lines.add('反馈电阻过大会怕漏电和噪声，过小会增加静态功耗');
    case ToolKind.ldoPower:
      final vin = v['vin'] ?? 0;
      final vout = v['vout'] ?? 0;
      final loadCurrent = v['current'] ?? 0;
      final powerText = toolResultText(results, '功耗');
      final stateText = toolResultText(results, '调节状态');
      final dropoutMargin = toolResultNumber(results, '压差余量');
      final thermalMargin = toolResultNumber(results, '热余量');
      final efficiency = toolResultNumber(results, '效率');
      final iq = toolResultNumber(results, '静态电流');
      if (powerText == '无效') {
        lines.add('Vin 必须大于 0，Vout 不能为负，负载电流、Iq 和 dropout 不能为负，θJA 必须大于 0');
      }
      if (stateText == '压差不足' || vin <= vout) {
        lines.add('Vin 需要高于 Vout，并留出 dropout 电压，否则 LDO 会退出稳压区');
      } else if (dropoutMargin != null &&
          dropoutMargin >= 0 &&
          dropoutMargin < 0.1) {
        lines.add('压差余量低于 0.1V，负载瞬态、纹波或低温都会让 LDO 接近退出稳压区');
      }
      if (thermalMargin != null && thermalMargin < 0) {
        lines.add('热余量为负，需降低功耗、减小 θJA 或改善散热');
      } else if (thermalMargin != null && thermalMargin < 15) {
        lines.add('热余量低于 15℃，环境温度、封装热阻和铜皮面积变化都可能越界');
      }
      if (iq != null && loadCurrent > 0 && iq / loadCurrent > 0.1) {
        lines.add('静态电流超过负载电流 10%，轻载或电池供电时会明显拉低效率');
      }
      if (efficiency != null && efficiency < 60) {
        lines.add('效率低于 60%，线性稳压损耗偏高，建议评估前级降压或 DCDC');
      }
      lines.add('热判断看 Tj = Ta + Pd × θJA；这里只给快速估算');
    case ToolKind.capacitorCharge:
      final voltageText = toolResultText(results, '电容电压');
      final chargeRatio = toolResultNumber(results, '充电比例');
      final initialCurrent = toolResultNumber(results, '初始电流');
      final targetVoltageTimeText = toolResultText(results, '目标电压时间');
      final targetRatioTimeText = toolResultText(results, '目标比例时间');
      if (voltageText == '无效') {
        lines.add('R 和 C 必须大于 0，时间不能为负，目标充电比例需在 0% 到 100%');
      }
      if (chargeRatio != null && chargeRatio < 90) {
        lines.add('当前还没到 90% 充电点，后级阈值或复位电路要按实际门限核对');
      }
      if (initialCurrent != null && initialCurrent > 100) {
        lines.add('初始电流超过 100mA，需确认电源限流、电阻功耗和开关冲击');
      }
      if (targetVoltageTimeText == '无效') {
        lines.add('目标电压不在初始电压到电源电压之间，理想 RC 模型无法达到该目标');
      }
      if (targetRatioTimeText == '无效') {
        lines.add('目标充电比例对应时间无效，请检查初始电压、电源电压和目标比例');
      }
      lines.add('RC 模型假设理想电阻电容，实际漏电、ESR 和输入源内阻会改变曲线');
    case ToolKind.batteryLife:
      final lifeText = toolResultText(results, '续航时间');
      final cRate = toolResultNumber(results, 'C倍率');
      final hours = toolResultNumber(results, '续航时间');
      final usableHours = toolResultNumber(results, '余量后续航');
      final targetHours = v['targetHours'];
      final requiredCapacity = toolResultNumber(results, '目标所需容量');
      final allowedAverageCurrent = toolResultNumber(results, '目标允许电流');
      final reserve = v['reserve'] ?? 20;
      final efficiency = v['efficiency'] ?? 100;
      if (lifeText == '无效') {
        lines.add('容量、平均电流和标称电压必须大于 0，效率需在 0% 到 100%，保留余量需小于 100%');
      }
      if (targetHours != null &&
          requiredCapacity != null &&
          requiredCapacity > (v['capacity'] ?? 0)) {
        lines
            .add('按当前负载和余量，目标续航需要 ${formatNumber(requiredCapacity)}mAh，当前容量偏小');
      }
      if (targetHours != null && allowedAverageCurrent != null) {
        lines.add(
            '若坚持 ${formatNumber(targetHours)}h 目标，平均电流需控制在 ${formatNumber(allowedAverageCurrent)}mA 以内');
      }
      if (usableHours != null && hours != null && reserve > 0) {
        lines.add(
            '扣除 ${formatNumber(reserve)}% 余量后，建议按 ${formatNumber(usableHours)}h 规划可用续航');
      }
      if (cRate != null && cRate > 1) {
        lines.add('等效放电倍率超过 1C，实际容量、温升和保护板限流要按电芯数据手册复核');
      }
      if (hours != null && hours < 1) {
        lines.add('估算续航低于 1 小时，峰值电流和电池内阻压降通常会变成主要约束');
      }
      if (reserve >= 40 && reserve < 100) {
        lines.add('保留余量超过 40%，结果更接近保守值，适合低温、老化或安全库存场景');
      }
      if (efficiency > 0 && efficiency < 75) {
        lines.add('效率低于 75%，转换器热损耗会明显影响续航和散热');
      }
      lines.add('容量会随温度、倍率、截止电压和老化下降，结果适合做预算');
      lines.add('Wh/W 模式按标称电压折算，升降压效率和峰值电流仍需单独校核');
    case ToolKind.pcbCurrent:
      final currentText = toolResultText(results, '估算电流');
      final current = toolResultNumber(results, '估算电流');
      final deratedCurrent = toolResultNumber(results, '保守 70%');
      final targetCurrent = v['targetCurrent'];
      final targetWidth = toolResultNumber(results, '目标所需线宽');
      final currentMargin = toolResultNumber(results, '电流余量');
      final deratedMargin = toolResultNumber(results, '70%余量');
      final utilization = toolResultNumber(results, '目标利用率');
      final width = v['width'] ?? 0;
      final copper = v['copper'] ?? 0;
      final rise = v['rise'] ?? 0;
      final layerFactor = v['layerFactor'] ?? 1;
      if (currentText == '无效') {
        lines.add('线宽、铜厚、允许温升和层位置系数都必须大于 0，目标电流也必须大于 0');
      }
      if (targetCurrent != null && targetWidth != null && targetWidth > width) {
        lines.add('按目标电流估算，线宽至少需要 ${formatNumber(targetWidth)}mm');
      }
      if (targetCurrent != null && currentMargin != null && currentMargin < 0) {
        lines.add(
            '目标电流超过估算载流 ${formatNumber(currentMargin.abs())}A，需加宽、加厚铜或降低温升要求');
      }
      if (targetCurrent != null && deratedMargin != null && deratedMargin < 0) {
        lines.add('按 70% 降额后余量为负，不适合直接作为连续电流设计值');
      }
      if (utilization != null && utilization > 80) {
        lines.add('目标利用率超过 80%，建议留出铜厚、蚀刻、公差和环境温度余量');
      }
      if (rise > 30) lines.add('允许温升超过 30℃，实际板温和邻近器件温度要单独复核');
      if (width > 0 && width < 0.2) lines.add('线宽低于 0.2mm 时，制造公差和阻焊覆盖会显著影响结果');
      if (copper >= 3) lines.add('厚铜工艺会改变蚀刻补偿和散热条件，不能只按公式外推');
      if (layerFactor < 1) {
        lines.add('层位置系数低于 1，当前按内层或散热较差场景做降额估算');
      } else if (layerFactor > 1) {
        lines.add('层位置系数高于 1，只有在额外散热、铺铜或实测支持时才建议使用');
      }
      if (current != null && deratedCurrent != null) {
        lines.add('70% 保守电流为 ${formatNumber(deratedCurrent)}A，可作为连续电流初筛值');
      }
      lines.add('IPC-2221 适合预估；高电流走线应按 IPC-2152 或热仿真复核');
      lines.add('铺铜、过孔、内外层和风速都会改变载流能力');
    case ToolKind.wireVoltageDrop:
      final dropText = toolResultText(results, '压降');
      final ratio = toolResultNumber(results, '压降比例');
      final loadVoltage = toolResultNumber(results, '负载端电压');
      final requiredArea = toolResultNumber(results, '目标所需截面积');
      final allowedCurrent = toolResultNumber(results, '目标允许电流');
      final currentMargin = toolResultNumber(results, '电流余量');
      final maxLength = toolResultNumber(results, '目标允许单程长度');
      final area = v['area'] ?? 0;
      final current = v['current'] ?? 0;
      final dropLimit = v['dropLimit'] ?? 3;
      final resistivity = v['resistivity'] ?? 0.0175;
      final parallel = v['parallel'] ?? 1;
      if (dropText == '无效') {
        lines.add('电流不能为负，单程长度、线芯截面积、目标压降、电阻率和并联根数必须有效');
      }
      if (ratio != null && ratio > dropLimit) {
        lines.add(
            '压降 ${formatNumber(ratio)}% 已超过 ${formatNumber(dropLimit)}% 目标，需加粗线径、缩短线长或降低电流');
      }
      if (requiredArea != null && requiredArea > area) {
        lines.add('按目标压降估算，每根线至少需要 ${formatNumber(requiredArea)}mm²');
      }
      if (allowedCurrent != null &&
          currentMargin != null &&
          currentMargin < 0) {
        lines.add(
            '当前线径在目标压降下约允许 ${formatNumber(allowedCurrent)}A，已超出 ${formatNumber(currentMargin.abs())}A');
      }
      if (maxLength != null && current > 0) {
        lines.add('按目标压降，当前线径和电流的单程长度上限约 ${formatNumber(maxLength)}m');
      }
      if (ratio != null && ratio > 5) lines.add('压降超过 5%，低压供电通常偏高');
      if (loadVoltage != null && loadVoltage <= 0) {
        lines.add('负载端电压已经不高于 0，当前线径或长度不可用');
      }
      if (parallel > 1) {
        lines.add('并联导线需确认端子压接、长度一致和分流均衡，否则单根线可能过载');
      }
      if (resistivity > 0.02) {
        lines.add('电阻率高于常温铜线，可能是在按铝线、热态铜线或接插件附加电阻做保守估算');
      }
      lines.add('线阻按往返回路算，铜线温度升高后压降还会变大');
    case ToolKind.timer555:
      final frequencyText = toolResultText(results, '频率');
      final duty = toolResultNumber(results, '占空比');
      final targetFrequencyText = toolResultText(results, '目标频率');
      final frequencyDelta = toolResultNumber(results, '频率偏差');
      final dutyDelta = toolResultNumber(results, '占空比偏差');
      if (frequencyText == '无效') {
        lines.add('RA、RB 和 C 都必须大于 0，才能形成无稳态振荡');
      }
      if (targetFrequencyText == '无效') {
        lines.add('目标频率必须大于 0，标准无稳态目标占空比必须大于 50% 且小于 100%');
      }
      if (frequencyDelta != null && frequencyDelta.abs() > 0) {
        lines.add('当前频率与目标频率相差 ${formatNumber(frequencyDelta)}Hz');
      }
      if (dutyDelta != null && dutyDelta.abs() > 0) {
        lines.add('当前占空比与目标占空比相差 ${formatNumber(dutyDelta)}%');
      }
      if (duty != null && duty > 75) {
        lines.add('占空比较高，若需要接近 50% 通常要加二极管通道或改用 CMOS 定时器');
      } else if (duty != null && duty < 50) {
        lines.add('标准无稳态接法占空比通常不低于 50%，请检查输入参数');
      }
      lines.add('普通 555 的电容漏电和阈值误差会让频率偏离标称值');
    case ToolKind.thermalRise:
      final junctionText = toolResultText(results, '结温估算');
      final thermalMargin = toolResultNumber(results, '热余量');
      final marginRatio = toolResultNumber(results, '热余量比例');
      final power = v['power'] ?? 0;
      final derating = v['derating'] ?? 70;
      final deratedPower = toolResultNumber(results, '降额功耗');
      final targetJunctionPower = toolResultNumber(results, '目标结温允许功耗');
      final targetMarginPower = toolResultNumber(results, '目标余量允许功耗');
      if (junctionText == '无效') {
        lines.add('功耗不能为负，热阻和降额比例必须大于 0，最高结温必须高于环境温度，目标结温需落在环境温度和最高结温之间');
      }
      if (thermalMargin != null && thermalMargin < 0) {
        lines.add('热余量为负，需降低功耗、减小热阻或提高散热能力');
      } else if (thermalMargin != null && thermalMargin < 10) {
        lines.add('热余量低于 10℃，环境温度、风速或装配变化都可能导致超温');
      }
      if (marginRatio != null && marginRatio < 20) {
        lines.add('热余量比例低于 20%，不建议作为长期满载设计目标');
      }
      if (deratedPower != null && power > 0 && power > deratedPower) {
        lines.add('当前功耗超过 ${formatNumber(derating)}% 降额功耗，量产设计建议继续降额');
      }
      if (targetJunctionPower != null && power > targetJunctionPower) {
        lines.add('当前功耗超过目标结温允许功耗，需降低功耗或减小热阻才能满足目标结温');
      }
      if (targetMarginPower != null && power > targetMarginPower) {
        lines.add('当前功耗超过目标热余量允许功耗，需增加散热余量或降低损耗');
      }
      lines.add('热阻链应覆盖芯片、封装、PCB 和环境，单个 θ 值只够粗估');
    default:
      break;
  }
  return lines;
}
