import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

export 'calculate_tool_math_algebra.dart';
export 'calculate_tool_math_geometry.dart';

List<ToolResult> percentageResults(Map<String, double> valuesByKey) {
  final baseInput = valuesByKey['base'];
  final rateInput = valuesByKey['rate'];
  final valueInput = valuesByKey['value'];
  final newValueInput = valuesByKey['newValue'];
  final coreInputCount = [
    baseInput,
    rateInput,
    valueInput,
    newValueInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 2 ||
      (baseInput != null && !baseInput.isFinite) ||
      (rateInput != null && !rateInput.isFinite) ||
      (valueInput != null && !valueInput.isFinite) ||
      (newValueInput != null && !newValueInput.isFinite)) {
    return _invalidPercentageResults();
  }

  double base;
  double rate;
  double value;
  double newValue;
  String source;
  double? valueDelta;
  double? newValueDelta;
  if (baseInput != null && rateInput != null) {
    base = baseInput;
    rate = rateInput;
    value = base * rate / 100;
    newValue = base + value;
    valueDelta = valueInput == null ? null : value - valueInput;
    newValueDelta = newValueInput == null ? null : newValue - newValueInput;
    source = valueInput == null && newValueInput == null
        ? '基准值+百分比'
        : '基准值+百分比，结果值作参考';
  } else if (baseInput != null && valueInput != null) {
    base = baseInput;
    value = valueInput;
    if (base == 0) return _invalidPercentageResults();
    rate = value / base * 100;
    newValue = base + value;
    newValueDelta = newValueInput == null ? null : newValue - newValueInput;
    source = newValueInput == null ? '基准值+百分比结果' : '基准值+百分比结果，新值作参考';
  } else if (baseInput != null && newValueInput != null) {
    base = baseInput;
    newValue = newValueInput;
    value = newValue - base;
    if (base == 0) return _invalidPercentageResults();
    rate = value / base * 100;
    source = '基准值+新值';
  } else if (rateInput != null && valueInput != null) {
    rate = rateInput;
    value = valueInput;
    if (rate == 0) return _invalidPercentageResults();
    base = value * 100 / rate;
    newValue = base + value;
    newValueDelta = newValueInput == null ? null : newValue - newValueInput;
    source = newValueInput == null ? '百分比+百分比结果' : '百分比+百分比结果，新值作参考';
  } else if (rateInput != null && newValueInput != null) {
    rate = rateInput;
    newValue = newValueInput;
    final multiplier = 1 + rate / 100;
    if (multiplier == 0) return _invalidPercentageResults();
    base = newValue / multiplier;
    value = newValue - base;
    source = '百分比+新值';
  } else if (valueInput != null && newValueInput != null) {
    value = valueInput;
    newValue = newValueInput;
    base = newValue - value;
    if (base == 0) return _invalidPercentageResults();
    rate = value / base * 100;
    source = '百分比结果+新值';
  } else {
    return _invalidPercentageResults();
  }

  final decreaseValue = base - value;
  return [
    ToolResult.number('百分比结果', value, '', primary: true),
    ToolResult.number('基准值', base, ''),
    ToolResult.number('百分比', rate, '%'),
    ToolResult.number('增加后', newValue, ''),
    ToolResult.number('减少后', decreaseValue, ''),
    ToolResult.number('变化率', rate, '%'),
    ToolResult.number(
        '结果占新值', newValue == 0 ? null : value / newValue * 100, '%'),
    ToolResult('输入来源', source, ''),
    if (valueDelta != null) ToolResult.number('结果差值', valueDelta, ''),
    if (newValueDelta != null) ToolResult.number('新值差值', newValueDelta, ''),
  ];
}

List<ToolResult> _invalidPercentageResults() {
  return const [
    ToolResult.invalid('百分比结果', '', primary: true),
    ToolResult.invalid('基准值', ''),
    ToolResult.invalid('百分比', '%'),
    ToolResult.invalid('增加后', ''),
    ToolResult.invalid('减少后', ''),
    ToolResult.invalid('变化率', '%'),
    ToolResult.invalid('结果占新值', '%'),
    ToolResult.invalid('输入来源', ''),
  ];
}

List<ToolResult> scaleRatioResults(Map<String, double> valuesByKey) {
  final valueInput = valuesByKey['value'];
  final fromInput = valuesByKey['from'];
  final toInput = valuesByKey['to'];
  final scaledInput = valuesByKey['scaled'];
  final inputCount = [
    valueInput,
    fromInput,
    toInput,
    scaledInput,
  ].where((value) => value != null).length;
  if (inputCount < 3 ||
      (valueInput != null && !valueInput.isFinite) ||
      (fromInput != null && !fromInput.isFinite) ||
      (toInput != null && !toInput.isFinite) ||
      (scaledInput != null && !scaledInput.isFinite)) {
    return _invalidScaleRatioResults();
  }

  double value;
  double from;
  double to;
  double scaled;
  String source;
  double? scaledDelta;
  if (valueInput != null && fromInput != null && toInput != null) {
    // 中文：**原比例只在它当除数的这一支里不能为 0**——当参考值时可以是 0，这是并进来的
    //       `proportion` 工具原本就允许的（`a=0` 能解出 `c=0`）。
    // English: **the source ratio may be 0 except where it is the divisor** — as a reference it may be
    //          0, which is what the merged `proportion` tool allowed (`a=0` could solve `c=0`).
    if (fromInput == 0) return _invalidScaleRatioResults();
    value = valueInput;
    from = fromInput;
    to = toInput;
    scaled = value * to / from;
    scaledDelta = scaledInput == null ? null : scaled - scaledInput;
    source = scaledInput == null ? '原始值+原比例+目标比例' : '原始值+原比例+目标比例，目标值作参考';
  } else if (scaledInput != null && fromInput != null && toInput != null) {
    if (toInput == 0) return _invalidScaleRatioResults();
    scaled = scaledInput;
    from = fromInput;
    to = toInput;
    value = scaled * from / to;
    source = '缩放后+原比例+目标比例';
  } else if (scaledInput != null && valueInput != null && toInput != null) {
    if (scaledInput == 0) return _invalidScaleRatioResults();
    scaled = scaledInput;
    value = valueInput;
    to = toInput;
    from = value * to / scaled;
    source = '缩放后+原始值+目标比例';
  } else if (scaledInput != null && valueInput != null && fromInput != null) {
    if (valueInput == 0) return _invalidScaleRatioResults();
    scaled = scaledInput;
    value = valueInput;
    from = fromInput;
    to = scaled * from / value;
    source = '缩放后+原始值+原比例';
  } else {
    return _invalidScaleRatioResults();
  }

  // 中文：三支比例都可能在参考值为 0 时除出无穷或 NaN——按并进来的 `proportion` 工具同一套
  //       口径，把非有限的那一格置为 `null`（那一格显示为无效），而不是整份结果作废。
  // English: any of the three ratios can divide by zero when a reference is 0 — the same rule the merged
  //          `proportion` tool used: the non-finite cell becomes `null` (shown as invalid) rather than
  //          discarding the whole result.
  final ratio = from == 0 ? double.nan : to / from;
  final areaRatio = ratio.isFinite ? math.pow(ratio, 2).toDouble() : double.nan;
  final volumeRatio = ratio.isFinite ? math.pow(ratio, 3).toDouble() : double.nan;
  final leftRatio = from == 0 ? double.nan : value / from;
  final rightRatio = to == 0 ? double.nan : scaled / to;
  return [
    ToolResult.number('缩放后', scaled, '', primary: true),
    ToolResult.number('原始值', value, ''),
    ToolResult.number('原比例', from, ''),
    ToolResult.number('目标比例', to, ''),
    ToolResult.number('缩放比例', ratio.isFinite ? ratio : null, 'x'),
    ToolResult.number('面积比例', areaRatio.isFinite ? areaRatio : null, 'x'),
    ToolResult.number('体积比例', volumeRatio.isFinite ? volumeRatio : null, 'x'),
    // 中文：四个数拼成一句「比例」——错误状态由这四个数决定，不由那句话的措辞决定（与并进来的
    //       `proportion` 工具同一份输出，只是标签换成了缩放这一套说法）。
    // English: Four numbers joined into one "ratio" sentence — those four numbers decide the error
    //          state, not the wording (the merged `proportion` tool produced the same row, under the
    //          scaling vocabulary).
    ToolResult(
      '比例',
      '${formatNumber(from)}:${formatNumber(value)} = ${formatNumber(to)}:${formatNumber(scaled)}',
      '',
      hasError:
          !from.isFinite || !value.isFinite || !to.isFinite || !scaled.isFinite,
    ),
    ToolResult.number('比例系数', leftRatio.isFinite ? leftRatio : null, 'x'),
    ToolResult.number('交叉乘积差', from * scaled - value * to, ''),
    ToolResult.number('右侧系数', rightRatio.isFinite ? rightRatio : null, 'x'),
    ToolResult('输入来源', source, ''),
    if (scaledDelta != null) ToolResult.number('缩放值差值', scaledDelta, ''),
  ];
}

List<ToolResult> _invalidScaleRatioResults() {
  return const [
    ToolResult.invalid('缩放后', '', primary: true),
    ToolResult.invalid('原始值', ''),
    ToolResult.invalid('原比例', ''),
    ToolResult.invalid('目标比例', ''),
    ToolResult.invalid('缩放比例', 'x'),
    ToolResult.invalid('面积比例', 'x'),
    ToolResult.invalid('体积比例', 'x'),
    ToolResult.invalid('比例', ''),
    ToolResult.invalid('比例系数', 'x'),
    ToolResult.invalid('交叉乘积差', ''),
    ToolResult.invalid('右侧系数', 'x'),
    ToolResult.invalid('输入来源', ''),
  ];
}
