import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> wavelengthResults(Map<String, double> valuesByKey) {
  final speedInput = valuesByKey['speed'];
  final frequencyInput = valuesByKey['frequency'];
  final wavelengthInput = valuesByKey['wavelength'];
  final validInputs = [
    speedInput,
    frequencyInput,
    wavelengthInput,
  ].where((value) => value != null).length;
  if (validInputs < 2 ||
      (speedInput != null && (speedInput <= 0 || !speedInput.isFinite)) ||
      (frequencyInput != null &&
          (frequencyInput <= 0 || !frequencyInput.isFinite)) ||
      (wavelengthInput != null &&
          (wavelengthInput <= 0 || !wavelengthInput.isFinite))) {
    return _invalidWavelengthResults();
  }

  double speed;
  double frequency;
  double wavelength;
  String source;
  if (speedInput != null && frequencyInput != null) {
    speed = speedInput;
    frequency = frequencyInput;
    wavelength = speed / frequency;
    source = wavelengthInput == null ? '波速+频率' : '波速+频率，波长作参考';
  } else if (speedInput != null && wavelengthInput != null) {
    speed = speedInput;
    wavelength = wavelengthInput;
    frequency = speed / wavelength;
    source = '波速+波长';
  } else if (frequencyInput != null && wavelengthInput != null) {
    frequency = frequencyInput;
    wavelength = wavelengthInput;
    speed = wavelength * frequency;
    source = '频率+波长';
  } else {
    return _invalidWavelengthResults();
  }

  final wavelengthDelta =
      wavelengthInput == null ? null : wavelength - wavelengthInput;
  return [
    ToolResult('波长', formatNumber(wavelength), 'm', primary: true),
    ToolResult('周期', formatNumber(1 / frequency), 's'),
    ToolResult('频率', formatNumber(frequency), 'Hz'),
    ToolResult('频率 kHz', formatNumber(frequency / 1000), 'kHz'),
    ToolResult('波速', formatNumber(speed), 'm/s'),
    ToolResult('波速 km/h', formatNumber(speed * 3.6), 'km/h'),
    ToolResult('波数', formatNumber(1 / wavelength), '1/m'),
    ToolResult('角频率', formatNumber(2 * math.pi * frequency), 'rad/s'),
    ToolResult('输入来源', source, ''),
    if (wavelengthDelta != null)
      ToolResult('波长差值', formatNumber(wavelengthDelta), 'm'),
  ];
}

List<ToolResult> _invalidWavelengthResults() {
  return const [
    ToolResult('波长', '无效', 'm', primary: true),
    ToolResult('周期', '无效', 's'),
    ToolResult('频率', '无效', 'Hz'),
    ToolResult('频率 kHz', '无效', 'kHz'),
    ToolResult('波速', '无效', 'm/s'),
    ToolResult('波速 km/h', '无效', 'km/h'),
    ToolResult('波数', '无效', '1/m'),
    ToolResult('角频率', '无效', 'rad/s'),
    ToolResult('输入来源', '无效', ''),
  ];
}

List<ToolResult> halfLifeResults(Map<String, double> valuesByKey) {
  final initialInput = valuesByKey['initial'];
  final halfInput = valuesByKey['half'];
  final timeInput = valuesByKey['time'];
  final remainingInput = valuesByKey['remaining'];
  final remainingRatioInput = valuesByKey['remainingRatio'];
  final validInputs = [
    initialInput,
    halfInput,
    timeInput,
    remainingInput,
    remainingRatioInput,
  ].where((value) => value != null).length;
  if (validInputs < 3 ||
      (initialInput != null && (initialInput < 0 || !initialInput.isFinite)) ||
      (halfInput != null && (halfInput <= 0 || !halfInput.isFinite)) ||
      (timeInput != null && (timeInput < 0 || !timeInput.isFinite)) ||
      (remainingInput != null &&
          (remainingInput < 0 ||
              !remainingInput.isFinite ||
              (initialInput != null && remainingInput > initialInput))) ||
      (remainingRatioInput != null &&
          (remainingRatioInput < 0 ||
              remainingRatioInput > 100 ||
              !remainingRatioInput.isFinite))) {
    return _invalidHalfLifeResults();
  }

  double initial;
  double half;
  double time;
  double remaining;
  double remainingRatio;
  String source;
  if (initialInput != null && halfInput != null && timeInput != null) {
    initial = initialInput;
    half = halfInput;
    time = timeInput;
    final periods = time / half;
    remaining = initial * math.pow(0.5, periods).toDouble();
    remainingRatio = initial == 0 ? 0.0 : remaining / initial * 100;
    source = _halfLifeSource(
      '初始量+半衰期+经过时间',
      hasRemainingReference: remainingInput != null,
      hasRatioReference: remainingRatioInput != null,
    );
  } else if (initialInput != null && halfInput != null) {
    initial = initialInput;
    half = halfInput;
    final ratio = _halfLifeRatioFromRemaining(
      initial: initial,
      remaining: remainingInput,
      remainingRatio: remainingRatioInput,
    );
    if (ratio == null || ratio <= 0 || ratio > 1) {
      return _invalidHalfLifeResults();
    }
    remainingRatio = ratio * 100;
    remaining = initial * ratio;
    time = -half * math.log(ratio) / math.ln2;
    source = _halfLifeSource(
      remainingInput != null ? '初始量+半衰期+剩余量' : '初始量+半衰期+剩余比例',
      hasRatioReference: remainingInput != null && remainingRatioInput != null,
    );
  } else if (initialInput != null && timeInput != null) {
    initial = initialInput;
    time = timeInput;
    final ratio = _halfLifeRatioFromRemaining(
      initial: initial,
      remaining: remainingInput,
      remainingRatio: remainingRatioInput,
    );
    if (ratio == null || ratio <= 0 || ratio > 1 || time == 0) {
      return _invalidHalfLifeResults();
    }
    remainingRatio = ratio * 100;
    remaining = initial * ratio;
    half = -time * math.ln2 / math.log(ratio);
    source = _halfLifeSource(
      remainingInput != null ? '初始量+经过时间+剩余量' : '初始量+经过时间+剩余比例',
      hasRatioReference: remainingInput != null && remainingRatioInput != null,
    );
  } else {
    return _invalidHalfLifeResults();
  }

  final periods = time / half;
  final remainingDelta =
      remainingInput == null ? null : remaining - remainingInput;
  final remainingRatioDelta =
      remainingRatioInput == null ? null : remainingRatio - remainingRatioInput;
  return [
    ToolResult('剩余量', formatNumber(remaining), '', primary: true),
    ToolResult('剩余比例', formatNumber(remainingRatio), '%'),
    ToolResult('衰减量', formatNumber(initial - remaining), ''),
    ToolResult('衰减比例', formatNumber(100 - remainingRatio), '%'),
    ToolResult('初始量', formatNumber(initial), ''),
    ToolResult('半衰期', formatNumber(half), 'h'),
    ToolResult('经过时间', formatNumber(time), 'h'),
    ToolResult('经历半衰期', formatNumber(periods), '个'),
    ToolResult('衰变常数', formatNumber(math.ln2 / half), '1/h'),
    ToolResult('输入来源', source, ''),
    if (remainingDelta != null)
      ToolResult('剩余量差值', formatNumber(remainingDelta), ''),
    if (remainingRatioDelta != null)
      ToolResult('剩余比例差值', formatNumber(remainingRatioDelta), '%'),
  ];
}

double? _halfLifeRatioFromRemaining({
  required double initial,
  double? remaining,
  double? remainingRatio,
}) {
  if (remaining != null) {
    if (initial <= 0 || remaining > initial) return null;
    return remaining / initial;
  }
  if (remainingRatio != null) return remainingRatio / 100;
  return null;
}

String _halfLifeSource(
  String source, {
  bool hasRemainingReference = false,
  bool hasRatioReference = false,
}) {
  final references = [
    if (hasRemainingReference) '剩余量',
    if (hasRatioReference) '剩余比例',
  ];
  if (references.isEmpty) return source;
  return '$source，${references.join('、')}作参考';
}

List<ToolResult> _invalidHalfLifeResults() {
  return const [
    ToolResult('剩余量', '无效', '', primary: true),
    ToolResult('剩余比例', '无效', '%'),
    ToolResult('衰减量', '无效', ''),
    ToolResult('衰减比例', '无效', '%'),
    ToolResult('初始量', '无效', ''),
    ToolResult('半衰期', '无效', 'h'),
    ToolResult('经过时间', '无效', 'h'),
    ToolResult('经历半衰期', '无效', '个'),
    ToolResult('衰变常数', '无效', '1/h'),
    ToolResult('输入来源', '无效', ''),
  ];
}
