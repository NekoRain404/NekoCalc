import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> matrixResults(Map<String, double> valuesByKey) {
  final a = valuesByKey['a'] ?? 0;
  final b = valuesByKey['b'] ?? 0;
  final c = valuesByKey['c'] ?? 0;
  final d = valuesByKey['d'] ?? 0;
  if (!a.isFinite || !b.isFinite || !c.isFinite || !d.isFinite) {
    return _invalidMatrixResults();
  }
  final determinant = a * d - b * c;
  final trace = a + d;
  final discriminant = trace * trace - 4 * determinant;
  final frobenius = math.sqrt(a * a + b * b + c * c + d * d);
  final row1Norm = a.abs() + b.abs();
  final row2Norm = c.abs() + d.abs();
  final col1Norm = a.abs() + c.abs();
  final col2Norm = b.abs() + d.abs();
  final rank = determinant.abs() > 1e-12
      ? 2
      : (a.abs() > 1e-12 ||
              b.abs() > 1e-12 ||
              c.abs() > 1e-12 ||
              d.abs() > 1e-12)
          ? 1
          : 0;
  // 中文：**逆矩阵的四个数先算出来，错误状态由它们决定**；`不可逆` 那一支是产出方写下的结论，
  //       也被产出方标成错误。
  // English: **the four inverse entries are computed as numbers first and they decide the error
  //          state**; the `不可逆` branch is a conclusion the producer wrote and marks as an error.
  // 中文：判据与旧代码**逐字反过来**，而不是写成 `abs() > 1e-12`——行列式是 NaN 时两个比较
  //       都为假，反写会把 `不可逆` 那一支错当成「可逆」。
  // English: the condition is the **literal negation of the old one** rather than `abs() > 1e-12`:
  //          when the determinant is NaN both comparisons are false, and writing it the other way
  //          round would take the `不可逆` branch as "invertible".
  final inverseUnavailable = determinant.abs() <= 1e-12;
  final inverseEntries = <double>[
    d / determinant,
    -b / determinant,
    -c / determinant,
    a / determinant,
  ];
  final inverse = !inverseUnavailable
      ? '[${formatNumber(inverseEntries[0])}, ${formatNumber(inverseEntries[1])}; '
          '${formatNumber(inverseEntries[2])}, ${formatNumber(inverseEntries[3])}]'
      : '不可逆';
  // 中文：特征值也**先算成数**，那句话只是它们的排版。
  // English: the eigenvalues are computed as numbers first too; the sentence is only their layout.
  final eigenvalueValues = discriminant < 0
      ? <double>[trace / 2, math.sqrt(-discriminant) / 2]
      : <double>[
          (trace + math.sqrt(discriminant)) / 2,
          (trace - math.sqrt(discriminant)) / 2,
        ];
  final eigenText = discriminant < 0
      ? '${formatNumber(eigenvalueValues[0])} + '
          '${formatNumber(eigenvalueValues[1])}i / '
          '${formatNumber(eigenvalueValues[0])} - '
          '${formatNumber(eigenvalueValues[1])}i'
      : '${formatNumber(eigenvalueValues[0])} / '
          '${formatNumber(eigenvalueValues[1])}';
  return [
    ToolResult.number('行列式 det', determinant, '', primary: true),
    ToolResult.number('迹 tr', trace, ''),
    ToolResult.number('判别项', discriminant, ''),
    ToolResult('逆矩阵', inverse, '',
        hasError: inverseUnavailable ||
            inverseEntries.any((value) => !value.isFinite)),
    ToolResult('秩', rank.toString(), ''),
    ToolResult('特征值', eigenText, '',
        hasError: eigenvalueValues.any((value) => !value.isFinite)),
    ToolResult.number('Frobenius范数', frobenius, ''),
    ToolResult.number('行和范数', math.max(row1Norm, row2Norm), ''),
    ToolResult.number('列和范数', math.max(col1Norm, col2Norm), ''),
    ToolResult('可逆状态', determinant.abs() <= 1e-12 ? '不可逆' : '可逆', '',
        hasError: determinant.abs() <= 1e-12),
  ];
}

List<ToolResult> _invalidMatrixResults() {
  return const [
    ToolResult.invalid('行列式 det', '', primary: true),
    ToolResult.invalid('迹 tr', ''),
    ToolResult.invalid('判别项', ''),
    ToolResult.invalid('逆矩阵', ''),
    ToolResult.invalid('秩', ''),
    ToolResult.invalid('特征值', ''),
    ToolResult.invalid('Frobenius范数', ''),
    ToolResult.invalid('行和范数', ''),
    ToolResult.invalid('列和范数', ''),
    ToolResult.invalid('可逆状态', ''),
  ];
}

List<ToolResult> complexResults(Map<String, double> valuesByKey) {
  final a = valuesByKey['a'] ?? 0;
  final b = valuesByKey['b'] ?? 0;
  final c = valuesByKey['c'] ?? 0;
  final d = valuesByKey['d'] ?? 0;
  if (!a.isFinite || !b.isFinite || !c.isFinite || !d.isFinite) {
    return _invalidComplexResults();
  }
  final denominator = c * c + d * d;
  final z1Magnitude = math.sqrt(a * a + b * b);
  final z2Magnitude = math.sqrt(c * c + d * d);
  final argument = math.atan2(b, a) * 180 / math.pi;
  final z2Argument = math.atan2(d, c) * 180 / math.pi;
  return [
    _complexResult('z1 + z2', a + c, b + d, '', primary: true),
    _complexResult('z1 - z2', a - c, b - d, ''),
    _complexResult('z1 × z2', a * c - b * d, a * d + b * c, ''),
    if (denominator == 0)
      const ToolResult.invalid('z1 ÷ z2', '')
    else
      _complexResult(
        'z1 ÷ z2',
        (a * c + b * d) / denominator,
        (b * c - a * d) / denominator,
        '',
      ),
    ToolResult.number('|z1|', z1Magnitude, ''),
    ToolResult.number('|z2|', z2Magnitude, ''),
    ToolResult.number('arg(z1)', z1Magnitude == 0 ? null : argument, 'deg'),
    ToolResult.number('arg(z2)', z2Magnitude == 0 ? null : z2Argument, 'deg'),
    _complexResult('conj(z1)', a, -b, ''),
    _complexResult('conj(z2)', c, -d, ''),
  ];
}

List<ToolResult> _invalidComplexResults() {
  return const [
    ToolResult.invalid('z1 + z2', '', primary: true),
    ToolResult.invalid('z1 - z2', ''),
    ToolResult.invalid('z1 × z2', ''),
    ToolResult.invalid('z1 ÷ z2', ''),
    ToolResult.invalid('|z1|', ''),
    ToolResult.invalid('|z2|', ''),
    ToolResult.invalid('arg(z1)', 'deg'),
    ToolResult.invalid('arg(z2)', 'deg'),
    ToolResult.invalid('conj(z1)', ''),
    ToolResult.invalid('conj(z2)', ''),
  ];
}

/// 中文：**一条复数结果。** 错误状态由两个分量本身决定——那两个分量是不是有限数，才是
///       `_complexText` 那句话里出不出现「无效」的原因。
/// English: **One complex-number result.** The error state is decided by the two parts themselves —
///          whether those parts are finite is what makes `_complexText` mention the marker.
ToolResult _complexResult(
    String label, double real, double imaginary, String unit,
    {bool primary = false}) {
  return ToolResult(label, _complexText(real, imaginary), unit,
      primary: primary, hasError: !real.isFinite || !imaginary.isFinite);
}

String _complexText(double real, double imaginary) {
  return '${formatNumber(real)} ${_signedImag(imaginary)}i';
}

List<ToolResult> vectorResults(Map<String, double> valuesByKey) {
  final x1 = valuesByKey['x1'] ?? 0;
  final y1 = valuesByKey['y1'] ?? 0;
  final x2 = valuesByKey['x2'] ?? 0;
  final y2 = valuesByKey['y2'] ?? 0;
  if (!x1.isFinite || !y1.isFinite || !x2.isFinite || !y2.isFinite) {
    return _invalidVectorResults();
  }
  final dot = x1 * x2 + y1 * y2;
  final cross = x1 * y2 - y1 * x2;
  final len1 = math.sqrt(x1 * x1 + y1 * y1);
  final len2 = math.sqrt(x2 * x2 + y2 * y2);
  final cos = len1 == 0 || len2 == 0
      ? double.nan
      : (dot / (len1 * len2)).clamp(-1.0, 1.0);
  final angle = cos.isFinite ? math.acos(cos) * 180 / math.pi : double.nan;
  final distance = math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2));
  final projectionOnB = len2 == 0 ? double.nan : dot / len2;
  // 中文：投影向量**先算成数**。`len2 == 0` 那一支值就是那条记号，也是错误。
  // English: the projection vector is computed as numbers first. The `len2 == 0` branch's value is
  //          the marker itself, and it is an error.
  final projectionVectorAvailable = len2 != 0;
  final projectionVectorValues = <double>[
    dot / (len2 * len2) * x2,
    dot / (len2 * len2) * y2,
  ];
  final projectionVectorOnB = projectionVectorAvailable
      ? '(${formatNumber(projectionVectorValues[0])}, '
          '${formatNumber(projectionVectorValues[1])})'
      : '无效';
  final directionA =
      len1 == 0 ? double.nan : math.atan2(y1, x1) * 180 / math.pi;
  final directionB =
      len2 == 0 ? double.nan : math.atan2(y2, x2) * 180 / math.pi;
  return [
    ToolResult.number('点积', dot, '', primary: true),
    ToolResult.number('叉积 z', cross, ''),
    ToolResult.number('夹角', angle.isFinite ? angle : null, 'deg'),
    // 中文：两个长度拼成一句「比」——错误状态由这两个数决定，不由这句话里的措辞决定。
    // English: Two lengths joined into one "ratio" sentence — the two numbers decide the error
    //          state, not the wording inside the sentence.
    ToolResult(
      '|A| / |B|',
      '${formatNumber(len1)} / ${formatNumber(len2)}',
      '',
      hasError: !len1.isFinite || !len2.isFinite,
    ),
    ToolResult.number('距离 |A-B|', distance, ''),
    ToolResult.number('cosθ', cos.isFinite ? cos : null, ''),
    ToolResult.number(
        'A在B方向投影', projectionOnB.isFinite ? projectionOnB : null, ''),
    ToolResult('A到B投影向量', projectionVectorOnB, '',
        hasError: !projectionVectorAvailable ||
            projectionVectorValues.any((value) => !value.isFinite),
        isInvalidMarker: !projectionVectorAvailable),
    ToolResult.number('方向角 A', directionA.isFinite ? directionA : null, 'deg'),
    ToolResult.number('方向角 B', directionB.isFinite ? directionB : null, 'deg'),
    ToolResult('关系', _vectorRelation(dot, cross, len1, len2), ''),
  ];
}

List<ToolResult> _invalidVectorResults() {
  return const [
    ToolResult.invalid('点积', '', primary: true),
    ToolResult.invalid('叉积 z', ''),
    ToolResult.invalid('夹角', 'deg'),
    ToolResult.invalid('|A| / |B|', ''),
    ToolResult.invalid('距离 |A-B|', ''),
    ToolResult.invalid('cosθ', ''),
    ToolResult.invalid('A在B方向投影', ''),
    ToolResult.invalid('A到B投影向量', ''),
    ToolResult.invalid('方向角 A', 'deg'),
    ToolResult.invalid('方向角 B', 'deg'),
    ToolResult.invalid('关系', ''),
  ];
}

String _vectorRelation(
  double dot,
  double cross,
  double len1,
  double len2,
) {
  if (len1 == 0 || len2 == 0) return '零向量';
  if (cross.abs() < 1e-9) return dot >= 0 ? '同向平行' : '反向平行';
  if (dot.abs() < 1e-9) return '垂直';
  return '一般夹角';
}

List<ToolResult> triangleResults(Map<String, double> valuesByKey) {
  final a = valuesByKey['a'] ?? 0;
  final b = valuesByKey['b'] ?? 0;
  final c = valuesByKey['c'] ?? 0;
  final valid = a > 0 &&
      b > 0 &&
      c > 0 &&
      a.isFinite &&
      b.isFinite &&
      c.isFinite &&
      a + b > c &&
      a + c > b &&
      b + c > a;
  if (!valid) return _invalidTriangleResults();

  final perimeter = a + b + c;
  final s = perimeter / 2;
  final area = math.sqrt(s * (s - a) * (s - b) * (s - c));
  final angleA = _triangleAngle(opposite: a, adjacent1: b, adjacent2: c);
  final angleB = _triangleAngle(opposite: b, adjacent1: a, adjacent2: c);
  final angleC = 180 - angleA - angleB;
  final longest = math.max(a, math.max(b, c));
  final shortest = math.min(a, math.min(b, c));
  final inradius = area / s;
  final circumradius = a * b * c / (4 * area);
  final heightA = 2 * area / a;
  final heightB = 2 * area / b;
  final heightC = 2 * area / c;
  final type = _triangleType(a, b, c);
  return [
    ToolResult.number('面积', area, '', primary: true),
    ToolResult.number('周长', perimeter, ''),
    ToolResult.number('半周长', s, ''),
    ToolResult(
      '角 A/B/C',
      '${formatNumber(angleA)} / ${formatNumber(angleB)} / ${formatNumber(angleC)}',
      'deg',
      hasError: !angleA.isFinite || !angleB.isFinite || !angleC.isFinite,
    ),
    ToolResult('边长类型', type, ''),
    ToolResult.number('最长边', longest, ''),
    ToolResult.number('最短边', shortest, ''),
    ToolResult(
      '高 ha/hb/hc',
      '${formatNumber(heightA)} / ${formatNumber(heightB)} / ${formatNumber(heightC)}',
      '',
      hasError: !heightA.isFinite || !heightB.isFinite || !heightC.isFinite,
    ),
    ToolResult.number('内切圆半径', inradius, ''),
    ToolResult.number('外接圆半径', circumradius, ''),
  ];
}

List<ToolResult> _invalidTriangleResults() {
  return const [
    ToolResult.invalid('面积', '', primary: true),
    ToolResult.invalid('周长', ''),
    ToolResult.invalid('半周长', ''),
    ToolResult.invalid('角 A/B/C', 'deg'),
    ToolResult.invalid('边长类型', ''),
    ToolResult.invalid('最长边', ''),
    ToolResult.invalid('最短边', ''),
    ToolResult.invalid('高 ha/hb/hc', ''),
    ToolResult.invalid('内切圆半径', ''),
    ToolResult.invalid('外接圆半径', ''),
  ];
}

double _triangleAngle({
  required double opposite,
  required double adjacent1,
  required double adjacent2,
}) {
  return math.acos(
        ((adjacent1 * adjacent1 + adjacent2 * adjacent2 - opposite * opposite) /
                (2 * adjacent1 * adjacent2))
            .clamp(-1.0, 1.0),
      ) *
      180 /
      math.pi;
}

String _triangleType(double a, double b, double c) {
  final sides = [a, b, c]..sort();
  final sideType = (a == b && b == c)
      ? '等边'
      : (a == b || a == c || b == c)
          ? '等腰'
          : '不等边';
  final squareCompare =
      sides[0] * sides[0] + sides[1] * sides[1] - sides[2] * sides[2];
  final angleType = squareCompare.abs() < 1e-9
      ? '直角'
      : squareCompare > 0
          ? '锐角'
          : '钝角';
  return '$sideType$angleType';
}

List<ToolResult> circleResults(Map<String, double> valuesByKey) {
  final radiusInput = valuesByKey['r'];
  final diameterInput = valuesByKey['diameter'];
  final circumferenceInput = valuesByKey['circumference'];
  final areaInput = valuesByKey['area'];
  final provided = [
    radiusInput,
    diameterInput,
    circumferenceInput,
    areaInput,
  ].where((value) => value != null).length;
  if (provided == 0 ||
      (radiusInput != null && (radiusInput < 0 || !radiusInput.isFinite)) ||
      (diameterInput != null &&
          (diameterInput < 0 || !diameterInput.isFinite)) ||
      (circumferenceInput != null &&
          (circumferenceInput < 0 || !circumferenceInput.isFinite)) ||
      (areaInput != null && (areaInput < 0 || !areaInput.isFinite))) {
    return _invalidCircleResults();
  }

  double radius;
  String source;
  if (radiusInput != null) {
    radius = radiusInput;
    source = provided == 1 ? '半径' : '半径，其他圆形量作参考';
  } else if (diameterInput != null) {
    radius = diameterInput / 2;
    source = provided == 1 ? '直径' : '直径，其他圆形量作参考';
  } else if (circumferenceInput != null) {
    radius = circumferenceInput / (2 * math.pi);
    source = provided == 1 ? '周长' : '周长，其他圆形量作参考';
  } else if (areaInput != null) {
    radius = math.sqrt(areaInput / math.pi);
    source = '面积';
  } else {
    return _invalidCircleResults();
  }
  if (!radius.isFinite) return _invalidCircleResults();

  final diameter = 2 * radius;
  final circumference = 2 * math.pi * radius;
  final area = math.pi * radius * radius;
  return [
    ToolResult.number('面积', area, '', primary: true),
    ToolResult.number('半径', radius, ''),
    ToolResult.number('直径', diameter, ''),
    ToolResult.number('周长', circumference, ''),
    ToolResult.number('半周长', circumference / 2, ''),
    ToolResult.number('单位半径面积', radius == 0 ? 0 : area / radius, ''),
    ToolResult('输入来源', source, ''),
    if (diameterInput != null && radiusInput != null)
      ToolResult.number('直径差值', diameter - diameterInput, ''),
    if (circumferenceInput != null &&
        (radiusInput != null || diameterInput != null))
      ToolResult.number('周长差值', circumference - circumferenceInput, ''),
    if (areaInput != null &&
        (radiusInput != null ||
            diameterInput != null ||
            circumferenceInput != null))
      ToolResult.number('面积差值', area - areaInput, ''),
  ];
}

List<ToolResult> _invalidCircleResults() {
  return const [
    ToolResult.invalid('面积', '', primary: true),
    ToolResult.invalid('半径', ''),
    ToolResult.invalid('直径', ''),
    ToolResult.invalid('周长', ''),
    ToolResult.invalid('半周长', ''),
    ToolResult.invalid('单位半径面积', ''),
    ToolResult.invalid('输入来源', ''),
  ];
}

String _signedImag(double value) {
  final sign = value < 0 ? '-' : '+';
  return '$sign ${formatNumber(value.abs())}';
}
