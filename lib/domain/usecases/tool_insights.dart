import 'dart:math' as math;

import '../../core/utils/iterable_ext.dart';
import '../../core/utils/number_formatter.dart';
import '../entities/tool_category.dart';
import '../entities/tool_definition.dart';

List<String> buildToolInsights(
    ToolDefinition tool, Map<String, double> values, List<ToolResult> results) {
  final primary = results.where((result) => result.primary).firstOrNull;
  return [
    _inputLine(tool, values),
    '公式 ${tool.formula}',
    if (primary != null) '${primary.label} ${primary.value}${primary.unit}',
    ..._errorLines(tool, values, results),
    ..._checkLines(tool, values, results),
  ].where((item) => item.trim().isNotEmpty).toList(growable: false);
}

String _inputLine(ToolDefinition tool, Map<String, double> values) {
  if (tool.inputs.isEmpty) return '无需数值输入';
  final fields = tool.inputs.map((input) {
    final value = formatNumber(values[input.key] ?? 0);
    return '${input.label} $value${input.unit}';
  }).join('，');
  return '输入 $fields';
}

List<String> _errorLines(
    ToolDefinition tool, Map<String, double> values, List<ToolResult> results) {
  final lines = <String>[];
  final tol = values['tol'];
  final vfTol = values['vfTol'];
  if (tol != null && tol > 0) {
    lines.add('误差按 ±${formatNumber(tol)}% 估算，范围结果只覆盖该公差，不包含温漂、老化和测量误差');
  }
  if (vfTol != null && vfTol > 0) {
    lines.add('LED 压降按 ±${formatNumber(vfTol)}V 扫描，实际还会随温度和电流移动');
  }
  final rangeLabels = results
      .where((result) => result.label.contains('范围'))
      .map((result) => '${result.label} ${result.value}${result.unit}');
  if (rangeLabels.isNotEmpty) lines.add('范围 ${rangeLabels.join('；')}');
  return lines;
}

List<String> _checkLines(
    ToolDefinition tool, Map<String, double> v, List<ToolResult> results) {
  final lines = <String>[];
  switch (tool.kind) {
    case ToolKind.quadratic:
      final a = v['a'] ?? 0;
      final b = v['b'] ?? 0;
      final c = v['c'] ?? 0;
      final delta = b * b - 4 * a * c;
      if (a == 0) lines.add('a 为 0 时退化为一元一次方程');
      if (a != 0 && delta < 0) lines.add('判别式小于 0，实数域无解');
      if (a != 0 && delta == 0) lines.add('两个根重合，顶点落在 x 轴上');
    case ToolKind.linearSystem:
      final d =
          (v['a1'] ?? 0) * (v['b2'] ?? 0) - (v['a2'] ?? 0) * (v['b1'] ?? 0);
      lines.add(d.abs() < 1e-9 ? 'D 接近 0，解会很敏感，输入稍变结果就可能跳动' : 'D 不为 0，有唯一解');
    case ToolKind.probability:
      final p1 = v['p1'] ?? 0;
      final p2 = v['p2'] ?? 0;
      if (p1 < 0 || p1 > 100 || p2 < 0 || p2 > 100) {
        lines.add('概率应落在 0% 到 100%');
      }
      lines.add('按独立事件计算；相关事件要改用条件概率');
    case ToolKind.statistics:
      lines.add('当前按 3 个样本计算，标准差使用样本公式');
    case ToolKind.vector:
      final len1 = _hypot(v['x1'] ?? 0, v['y1'] ?? 0);
      final len2 = _hypot(v['x2'] ?? 0, v['y2'] ?? 0);
      if (len1 == 0 || len2 == 0) lines.add('零向量没有方向，夹角不作工程判断');
    case ToolKind.triangle:
      final a = v['a'] ?? 0, b = v['b'] ?? 0, c = v['c'] ?? 0;
      if (a <= 0 ||
          b <= 0 ||
          c <= 0 ||
          a + b <= c ||
          a + c <= b ||
          b + c <= a) {
        lines.add('三边必须为正，且任意两边之和大于第三边');
      }
    case ToolKind.voltageDivider:
      lines.add(
          (v['load'] ?? 0) <= 0 ? '未接负载，Vout 是空载值' : '负载已并到下臂电阻，Vout 会被拉低');
      lines.add('分压电流太小会让负载和 ADC 采样电流明显影响结果');
    case ToolKind.rcFilter:
      lines.add('fc 是 -3dB 点；R、C 公差会按乘积放大到截止频率上');
      lines.add('低通和高通共用同一个 fc，取样节点不同');
    case ToolKind.ledResistor:
      final vin = v['vin'] ?? 0;
      final vf = v['vf'] ?? 0;
      final current = v['current'] ?? 0;
      if (vin <= vf) lines.add('Vin 不高于 Vf，LED 可能无法稳定导通');
      if (current > 20) lines.add('目标电流超过 20mA，请确认 LED 额定值和温升');
      lines.add('电阻功率建议留至少 2 倍余量');
    case ToolKind.opAmpGain:
      lines.add('结果是理想增益，实际还受供电轨、输入范围、带宽和压摆率限制');
    case ToolKind.adcResolution:
      lines.add('LSB 是理论步进，ENOB 会被噪声、参考源和前端阻抗拉低');
    case ToolKind.lcResonance:
      lines.add('DCR、ESR 和寄生参数会降低 Q 值并移动峰值频率');
    case ToolKind.dcdcFeedback:
      lines.add('反馈电阻过大会怕漏电和噪声，过小会增加静态功耗');
    case ToolKind.ldoPower:
      final vin = v['vin'] ?? 0;
      final vout = v['vout'] ?? 0;
      if (vin <= vout) lines.add('Vin 需要高于 Vout，并留出 dropout 电压');
      lines.add('热判断看 Tj = Ta + Pd × θJA；这里只给快速估算');
    case ToolKind.batteryLife:
      lines.add('容量会随温度、倍率、截止电压和老化下降，结果适合做预算');
    case ToolKind.pcbCurrent:
      lines.add('IPC-2221 适合预估；高电流走线应按 IPC-2152 或热仿真复核');
      lines.add('铺铜、过孔、内外层和风速都会改变载流能力');
    case ToolKind.wireVoltageDrop:
      final ratio = _resultNumber(results, '压降比例');
      if (ratio != null && ratio > 5) lines.add('压降超过 5%，低压供电通常偏高');
      lines.add('线阻按往返回路算，铜线温度升高后压降还会变大');
    case ToolKind.timer555:
      lines.add('普通 555 的电容漏电和阈值误差会让频率偏离标称值');
    case ToolKind.thermalRise:
      lines.add('热阻链应覆盖芯片、封装、PCB 和环境，单个 θ 值只够粗估');
    case ToolKind.gearRatio:
      lines.add('扭矩已乘效率；冲击载荷、齿面强度和轴承能力另算');
    case ToolKind.cylinder:
      lines.add('有效力还要扣掉密封摩擦、背压和压力波动');
    case ToolKind.inclinedPlane:
      lines.add('净下滑力为正会下滑，为负说明摩擦可抵住');
    case ToolKind.beamBending:
      lines.add('按简支梁中央集中载荷计算，支撑或载荷形式变化时不能直接套用');
    case ToolKind.stressStrain:
      lines.add('这是轴向平均应力，孔边、焊缝和缺口要单独看应力集中');
    case ToolKind.sectionArea:
      final outer = v['outer'] ?? 0;
      final inner = v['inner'] ?? 0;
      if (inner >= outer && outer > 0) lines.add('管截面内径必须小于外径');
    case ToolKind.safetyFactor:
      final factor = _resultNumber(results, '安全系数') ?? 0;
      if (factor < 1) lines.add('安全系数小于 1，按当前输入已经不足');
      if (factor >= 1 && factor < 2) lines.add('安全系数偏紧，疲劳、冲击、温度和制造偏差要继续校核');
    case ToolKind.loan:
      lines.add('按等额本息算，提前还款、手续费和浮动利率未计入');
    case ToolKind.npv:
      lines.add('NPV 对折现率很敏感，最好用不同折现率再扫一遍');
    case ToolKind.tax:
      lines.add('这里只按输入税率直接算，不区分价内税、价外税和地区规则');
    case ToolKind.bmi:
      lines.add('BMI 不能区分肌肉和脂肪，只能做筛查参考');
    case ToolKind.fuelEconomy:
      lines.add('路况、载重、胎压、空调和驾驶习惯都会改变油耗');
    default:
      lines.addAll(_categoryLines(tool.category));
  }
  return lines;
}

List<String> _categoryLines(ToolCategory category) {
  return switch (category) {
    ToolCategory.electronics => const ['理想元件模型，量产前要复核容差、温漂、额定功率和数据手册条件'],
    ToolCategory.mechanical => const ['静态估算结果，工程使用还要看材料、疲劳、冲击、装配误差和安全系数'],
    ToolCategory.finance => const ['本地估算，不替代合同条款、税务规则或投资判断'],
    ToolCategory.science => const ['默认理想模型，空气阻力、摩擦、热损耗和活度系数未自动计入'],
    ToolCategory.units => const ['固定系数换算；行业标准或标况条件不同会有差异'],
    ToolCategory.programming => const ['按常见工程约定处理，字符编码、时区和平台差异需按实际环境确认'],
    _ => const ['按当前输入和公式计算，实际使用前再核对场景约束'],
  };
}

double _hypot(double x, double y) => math.sqrt(x * x + y * y);

double? _resultNumber(List<ToolResult> results, String label) {
  for (final result in results) {
    if (!result.label.contains(label)) continue;
    return double.tryParse(
        result.value.replaceAll(',', '').replaceAll('%', ''));
  }
  return null;
}
