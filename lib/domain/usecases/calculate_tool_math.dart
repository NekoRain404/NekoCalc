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
    ToolResult('百分比结果', formatNumber(value), '', primary: true),
    ToolResult('基准值', formatNumber(base), ''),
    ToolResult('百分比', formatNumber(rate), '%'),
    ToolResult('增加后', formatNumber(newValue), ''),
    ToolResult('减少后', formatNumber(decreaseValue), ''),
    ToolResult('变化率', formatNumber(rate), '%'),
    ToolResult(
      '结果占新值',
      newValue == 0 ? '无效' : formatNumber(value / newValue * 100),
      '%',
    ),
    ToolResult('输入来源', source, ''),
    if (valueDelta != null) ToolResult('结果差值', formatNumber(valueDelta), ''),
    if (newValueDelta != null)
      ToolResult('新值差值', formatNumber(newValueDelta), ''),
  ];
}

List<ToolResult> _invalidPercentageResults() {
  return const [
    ToolResult('百分比结果', '无效', '', primary: true),
    ToolResult('基准值', '无效', ''),
    ToolResult('百分比', '无效', '%'),
    ToolResult('增加后', '无效', ''),
    ToolResult('减少后', '无效', ''),
    ToolResult('变化率', '无效', '%'),
    ToolResult('结果占新值', '无效', '%'),
    ToolResult('输入来源', '无效', ''),
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
    ToolResult('x', formatNumber(x), '', primary: true),
    ToolResult('a', formatNumber(a), ''),
    ToolResult('b', formatNumber(b), ''),
    ToolResult('c', formatNumber(c), ''),
    ToolResult(
        '比例',
        '${formatNumber(a)}:${formatNumber(b)} = ${formatNumber(c)}:${formatNumber(x)}',
        ''),
    ToolResult(
      '比例系数',
      leftRatio.isFinite ? formatNumber(leftRatio) : '无效',
      'x',
    ),
    ToolResult(
      '交叉乘积差',
      formatNumber(a * x - b * c),
      '',
    ),
    ToolResult(
      '右侧系数',
      rightRatio.isFinite ? formatNumber(rightRatio) : '无效',
      'x',
    ),
    ToolResult('输入来源', source, ''),
    if (xDelta != null) ToolResult('x差值', formatNumber(xDelta), ''),
  ];
}

List<ToolResult> _invalidProportionResults() {
  return const [
    ToolResult('x', '无效', '', primary: true),
    ToolResult('a', '无效', ''),
    ToolResult('b', '无效', ''),
    ToolResult('c', '无效', ''),
    ToolResult('比例', '无效', ''),
    ToolResult('比例系数', '无效', 'x'),
    ToolResult('交叉乘积差', '无效', ''),
    ToolResult('右侧系数', '无效', 'x'),
    ToolResult('输入来源', '无效', ''),
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
    ToolResult('缩放后', formatNumber(scaled), '', primary: true),
    ToolResult('原始值', formatNumber(value), ''),
    ToolResult('原比例', formatNumber(from), ''),
    ToolResult('目标比例', formatNumber(to), ''),
    ToolResult('缩放比例', formatNumber(ratio), 'x'),
    ToolResult('面积比例', formatNumber(math.pow(ratio, 2).toDouble()), 'x'),
    ToolResult('体积比例', formatNumber(math.pow(ratio, 3).toDouble()), 'x'),
    ToolResult('输入来源', source, ''),
    if (scaledDelta != null) ToolResult('缩放值差值', formatNumber(scaledDelta), ''),
  ];
}

List<ToolResult> _invalidScaleRatioResults() {
  return const [
    ToolResult('缩放后', '无效', '', primary: true),
    ToolResult('原始值', '无效', ''),
    ToolResult('原比例', '无效', ''),
    ToolResult('目标比例', '无效', ''),
    ToolResult('缩放比例', '无效', 'x'),
    ToolResult('面积比例', '无效', 'x'),
    ToolResult('体积比例', '无效', 'x'),
    ToolResult('输入来源', '无效', ''),
  ];
}
