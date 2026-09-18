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

List<ToolResult> proportionResults(Map<String, double> valuesByKey) {
  final aInput = valuesByKey['a'];
  final bInput = valuesByKey['b'];
  final cInput = valuesByKey['c'];
  final xInput = valuesByKey['x'];
  final inputCount =
      [aInput, bInput, cInput, xInput].where((value) => value != null).length;
  if (inputCount < 3 ||
      (aInput != null && !aInput.isFinite) ||
      (bInput != null && !bInput.isFinite) ||
      (cInput != null && !cInput.isFinite) ||
      (xInput != null && !xInput.isFinite)) {
    return _invalidProportionResults();
  }

  double a;
  double b;
  double c;
  double x;
  String source;
  double? xDelta;
  if (aInput != null && bInput != null && cInput != null) {
    if (aInput == 0) return _invalidProportionResults();
    a = aInput;
    b = bInput;
    c = cInput;
    x = b * c / a;
    xDelta = xInput == null ? null : x - xInput;
    source = xInput == null ? 'a+b+c' : 'a+b+c，x作参考';
  } else if (xInput != null && bInput != null && cInput != null) {
    if (xInput == 0) return _invalidProportionResults();
    x = xInput;
    b = bInput;
    c = cInput;
    a = b * c / x;
    source = 'b+c+x';
  } else if (xInput != null && aInput != null && cInput != null) {
    if (cInput == 0) return _invalidProportionResults();
    x = xInput;
    a = aInput;
    c = cInput;
    b = a * x / c;
    source = 'a+c+x';
  } else if (xInput != null && aInput != null && bInput != null) {
    if (bInput == 0) return _invalidProportionResults();
    x = xInput;
    a = aInput;
    b = bInput;
    c = a * x / b;
    source = 'a+b+x';
  } else {
    return _invalidProportionResults();
  }

  final leftRatio = a == 0 ? double.nan : b / a;
  final rightRatio = c == 0 ? double.nan : x / c;
  return [
    ToolResult.number('x', x, '', primary: true),
    ToolResult.number('a', a, ''),
    ToolResult.number('b', b, ''),
    ToolResult.number('c', c, ''),
    // 中文：四个数拼成一句「比例」——错误状态由这四个数决定，不由那句话的措辞决定。
    // English: Four numbers joined into one "proportion" sentence — those four numbers decide the
    //          error state, not the wording of the sentence.
    ToolResult(
      '比例',
      '${formatNumber(a)}:${formatNumber(b)} = ${formatNumber(c)}:${formatNumber(x)}',
      '',
      hasError: !a.isFinite || !b.isFinite || !c.isFinite || !x.isFinite,
    ),
    ToolResult.number('比例系数', leftRatio.isFinite ? leftRatio : null, 'x'),
    ToolResult.number('交叉乘积差', a * x - b * c, ''),
    ToolResult.number('右侧系数', rightRatio.isFinite ? rightRatio : null, 'x'),
    ToolResult('输入来源', source, ''),
    if (xDelta != null) ToolResult.number('x差值', xDelta, ''),
  ];
}

List<ToolResult> _invalidProportionResults() {
  return const [
    ToolResult.invalid('x', '', primary: true),
    ToolResult.invalid('a', ''),
    ToolResult.invalid('b', ''),
    ToolResult.invalid('c', ''),
    ToolResult.invalid('比例', ''),
    ToolResult.invalid('比例系数', 'x'),
    ToolResult.invalid('交叉乘积差', ''),
    ToolResult.invalid('右侧系数', 'x'),
    ToolResult.invalid('输入来源', ''),
  ];
}

List<ToolResult> scaleRatioResults(Map<String, double> valuesByKey) {
  final valueInput = valuesByKey['value'];
  final fromInput = valuesByKey['from'];
  final toInput = valuesByKey['to'];
  final scaledInput = valuesByKey['scaled'];
  final coreInputCount = [
    valueInput,
    fromInput,
    toInput,
    scaledInput,
  ].where((value) => value != null).length;
  if (coreInputCount < 3 ||
      (valueInput != null && !valueInput.isFinite) ||
      (fromInput != null && (fromInput == 0 || !fromInput.isFinite)) ||
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
    if (from == 0) return _invalidScaleRatioResults();
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

  final ratio = to / from;
  return [
    ToolResult.number('缩放后', scaled, '', primary: true),
    ToolResult.number('原始值', value, ''),
    ToolResult.number('原比例', from, ''),
    ToolResult.number('目标比例', to, ''),
    ToolResult.number('缩放比例', ratio, 'x'),
    ToolResult.number('面积比例', math.pow(ratio, 2).toDouble(), 'x'),
    ToolResult.number('体积比例', math.pow(ratio, 3).toDouble(), 'x'),
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
    ToolResult.invalid('输入来源', ''),
  ];
}
