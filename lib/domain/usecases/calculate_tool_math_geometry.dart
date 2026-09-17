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
  final inverse = determinant.abs() <= 1e-12
      ? '不可逆'
      : '[${formatNumber(d / determinant)}, ${formatNumber(-b / determinant)}; ${formatNumber(-c / determinant)}, ${formatNumber(a / determinant)}]';
  final eigenText = discriminant < 0
      ? _complexEigenvalues(trace, discriminant)
      : _realEigenvalues(trace, discriminant);
  return [
    ToolResult('行列式 det', formatNumber(determinant), '', primary: true),
    ToolResult('迹 tr', formatNumber(trace), ''),
    ToolResult('判别项', formatNumber(discriminant), ''),
    ToolResult('逆矩阵', inverse, ''),
    ToolResult('秩', rank.toString(), ''),
    ToolResult('特征值', eigenText, ''),
    ToolResult('Frobenius范数', formatNumber(frobenius), ''),
    ToolResult('行和范数', formatNumber(math.max(row1Norm, row2Norm)), ''),
    ToolResult('列和范数', formatNumber(math.max(col1Norm, col2Norm)), ''),
    ToolResult('可逆状态', determinant.abs() <= 1e-12 ? '不可逆' : '可逆', ''),
  ];
}

List<ToolResult> _invalidMatrixResults() {
  return const [
    ToolResult('行列式 det', '无效', '', primary: true),
    ToolResult('迹 tr', '无效', ''),
    ToolResult('判别项', '无效', ''),
    ToolResult('逆矩阵', '无效', ''),
    ToolResult('秩', '无效', ''),
    ToolResult('特征值', '无效', ''),
    ToolResult('Frobenius范数', '无效', ''),
    ToolResult('行和范数', '无效', ''),
    ToolResult('列和范数', '无效', ''),
    ToolResult('可逆状态', '无效', ''),
  ];
}

String _realEigenvalues(double trace, double discriminant) {
  final root = math.sqrt(discriminant);
  return '${formatNumber((trace + root) / 2)} / ${formatNumber((trace - root) / 2)}';
}

String _complexEigenvalues(double trace, double discriminant) {
  final real = trace / 2;
  final imaginary = math.sqrt(-discriminant) / 2;
  return '${formatNumber(real)} + ${formatNumber(imaginary)}i / ${formatNumber(real)} - ${formatNumber(imaginary)}i';
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
    ToolResult('z1 + z2', _complexText(a + c, b + d), '', primary: true),
    ToolResult('z1 - z2', _complexText(a - c, b - d), ''),
    ToolResult('z1 × z2', _complexText(a * c - b * d, a * d + b * c), ''),
    ToolResult(
      'z1 ÷ z2',
      denominator == 0
          ? '无效'
          : _complexText(
              (a * c + b * d) / denominator,
              (b * c - a * d) / denominator,
            ),
      '',
    ),
    ToolResult('|z1|', formatNumber(z1Magnitude), ''),
    ToolResult('|z2|', formatNumber(z2Magnitude), ''),
    ToolResult(
        'arg(z1)', z1Magnitude == 0 ? '无效' : formatNumber(argument), 'deg'),
    ToolResult(
        'arg(z2)', z2Magnitude == 0 ? '无效' : formatNumber(z2Argument), 'deg'),
    ToolResult('conj(z1)', _complexText(a, -b), ''),
    ToolResult('conj(z2)', _complexText(c, -d), ''),
  ];
}

List<ToolResult> _invalidComplexResults() {
  return const [
    ToolResult('z1 + z2', '无效', '', primary: true),
    ToolResult('z1 - z2', '无效', ''),
    ToolResult('z1 × z2', '无效', ''),
    ToolResult('z1 ÷ z2', '无效', ''),
    ToolResult('|z1|', '无效', ''),
    ToolResult('|z2|', '无效', ''),
    ToolResult('arg(z1)', '无效', 'deg'),
    ToolResult('arg(z2)', '无效', 'deg'),
    ToolResult('conj(z1)', '无效', ''),
    ToolResult('conj(z2)', '无效', ''),
  ];
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
  final projectionVectorOnB = len2 == 0
      ? '无效'
      : '(${formatNumber(dot / (len2 * len2) * x2)}, ${formatNumber(dot / (len2 * len2) * y2)})';
  final directionA =
      len1 == 0 ? double.nan : math.atan2(y1, x1) * 180 / math.pi;
  final directionB =
      len2 == 0 ? double.nan : math.atan2(y2, x2) * 180 / math.pi;
  return [
    ToolResult('点积', formatNumber(dot), '', primary: true),
    ToolResult('叉积 z', formatNumber(cross), ''),
    ToolResult('夹角', angle.isFinite ? formatNumber(angle) : '无效', 'deg'),
    ToolResult(
        '|A| / |B|', '${formatNumber(len1)} / ${formatNumber(len2)}', ''),
    ToolResult('距离 |A-B|', formatNumber(distance), ''),
    ToolResult('cosθ', cos.isFinite ? formatNumber(cos) : '无效', ''),
    ToolResult('A在B方向投影',
        projectionOnB.isFinite ? formatNumber(projectionOnB) : '无效', ''),
    ToolResult('A到B投影向量', projectionVectorOnB, ''),
    ToolResult(
        '方向角 A', directionA.isFinite ? formatNumber(directionA) : '无效', 'deg'),
    ToolResult(
        '方向角 B', directionB.isFinite ? formatNumber(directionB) : '无效', 'deg'),
    ToolResult('关系', _vectorRelation(dot, cross, len1, len2), ''),
  ];
}

List<ToolResult> _invalidVectorResults() {
  return const [
    ToolResult('点积', '无效', '', primary: true),
    ToolResult('叉积 z', '无效', ''),
    ToolResult('夹角', '无效', 'deg'),
    ToolResult('|A| / |B|', '无效', ''),
    ToolResult('距离 |A-B|', '无效', ''),
    ToolResult('cosθ', '无效', ''),
    ToolResult('A在B方向投影', '无效', ''),
    ToolResult('A到B投影向量', '无效', ''),
    ToolResult('方向角 A', '无效', 'deg'),
    ToolResult('方向角 B', '无效', 'deg'),
    ToolResult('关系', '无效', ''),
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
    ToolResult('面积', formatNumber(area), '', primary: true),
    ToolResult('周长', formatNumber(perimeter), ''),
    ToolResult('半周长', formatNumber(s), ''),
    ToolResult(
      '角 A/B/C',
      '${formatNumber(angleA)} / ${formatNumber(angleB)} / ${formatNumber(angleC)}',
      'deg',
    ),
    ToolResult('边长类型', type, ''),
    ToolResult('最长边', formatNumber(longest), ''),
    ToolResult('最短边', formatNumber(shortest), ''),
    ToolResult(
        '高 ha/hb/hc',
        '${formatNumber(heightA)} / ${formatNumber(heightB)} / ${formatNumber(heightC)}',
        ''),
    ToolResult('内切圆半径', formatNumber(inradius), ''),
    ToolResult('外接圆半径', formatNumber(circumradius), ''),
  ];
}

List<ToolResult> _invalidTriangleResults() {
  return const [
    ToolResult('面积', '无效', '', primary: true),
    ToolResult('周长', '无效', ''),
    ToolResult('半周长', '无效', ''),
    ToolResult('角 A/B/C', '无效', 'deg'),
    ToolResult('边长类型', '无效', ''),
    ToolResult('最长边', '无效', ''),
    ToolResult('最短边', '无效', ''),
    ToolResult('高 ha/hb/hc', '无效', ''),
    ToolResult('内切圆半径', '无效', ''),
    ToolResult('外接圆半径', '无效', ''),
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
    ToolResult('面积', formatNumber(area), '', primary: true),
    ToolResult('半径', formatNumber(radius), ''),
    ToolResult('直径', formatNumber(diameter), ''),
    ToolResult('周长', formatNumber(circumference), ''),
    ToolResult('半周长', formatNumber(circumference / 2), ''),
    ToolResult('单位半径面积', formatNumber(radius == 0 ? 0 : area / radius), ''),
    ToolResult('输入来源', source, ''),
    if (diameterInput != null && radiusInput != null)
      ToolResult('直径差值', formatNumber(diameter - diameterInput), ''),
    if (circumferenceInput != null &&
        (radiusInput != null || diameterInput != null))
      ToolResult('周长差值', formatNumber(circumference - circumferenceInput), ''),
    if (areaInput != null &&
        (radiusInput != null ||
            diameterInput != null ||
            circumferenceInput != null))
      ToolResult('面积差值', formatNumber(area - areaInput), ''),
  ];
}

List<ToolResult> _invalidCircleResults() {
  return const [
    ToolResult('面积', '无效', '', primary: true),
    ToolResult('半径', '无效', ''),
    ToolResult('直径', '无效', ''),
    ToolResult('周长', '无效', ''),
    ToolResult('半周长', '无效', ''),
    ToolResult('单位半径面积', '无效', ''),
    ToolResult('输入来源', '无效', ''),
  ];
}

String _signedImag(double value) {
  final sign = value < 0 ? '-' : '+';
  return '$sign ${formatNumber(value.abs())}';
}
