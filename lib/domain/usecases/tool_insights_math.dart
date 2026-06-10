import 'dart:math' as math;

import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';
import 'tool_insight_result_readers.dart';

bool isMathInsightTool(ToolKind kind) {
  switch (kind) {
    case ToolKind.quadratic:
    case ToolKind.linearSystem:
    case ToolKind.exponentialLog:
    case ToolKind.linearEquation:
    case ToolKind.combination:
    case ToolKind.percentage:
    case ToolKind.proportion:
    case ToolKind.probability:
    case ToolKind.statistics:
    case ToolKind.matrix:
    case ToolKind.complex:
    case ToolKind.vector:
    case ToolKind.triangle:
    case ToolKind.circle:
    case ToolKind.scaleRatio:
      return true;
    default:
      return false;
  }
}

List<String> buildMathToolInsights(
  ToolKind kind,
  Map<String, double> v,
  List<ToolResult> results,
) {
  final lines = <String>[];
  switch (kind) {
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
      final relation = toolResultText(results, '方程关系') ?? '';
      final residual1 = toolResultNumber(results, '残差 1');
      final residual2 = toolResultNumber(results, '残差 2');
      if (relation == '无解') {
        lines.add('系数矩阵秩小于增广矩阵秩，两条直线平行且不重合，无交点');
      } else if (relation == '无穷多解') {
        lines.add('系数矩阵和增广矩阵秩相同但 D=0，两条直线重合或方程退化');
      } else {
        lines.add(d.abs() < 1e-9 ? 'D 接近 0，解会很敏感，输入稍变结果就可能跳动' : 'D 不为 0，有唯一解');
      }
      if (residual1 != null && residual2 != null) {
        lines.add(
            '代回残差为 ${formatNumber(residual1)}、${formatNumber(residual2)}，越接近 0 校验越好');
      }
    case ToolKind.exponentialLog:
      final powerText = toolResultText(results, 'x^y');
      final domain = toolResultText(results, '定义域') ?? '';
      final x = v['x'] ?? 0;
      final y = v['y'] ?? 0;
      if (powerText == '无效') {
        lines.add('指数或对数结果无效，通常来自非有限输入、溢出或实数域不支持的幂运算');
      }
      if (domain == '对数无效') {
        lines.add('x 必须大于 0 才能计算 ln(x)、log10(x) 和换底对数');
      }
      if (y == 0) lines.add('y 为 0 时 y 次根无定义，x^0 仍按 1 处理');
      if (y == 1) lines.add('换底对数 log_y(x) 要求底数 y 大于 0 且不等于 1');
      if (x.abs() > 100 || y.abs() > 100) {
        lines.add('指数输入较大，结果可能进入科学计数法或超出双精度可表示范围');
      }
      lines.add('指数对数按实数域和双精度浮点计算，复数幂和多值根未展开');
    case ToolKind.linearEquation:
      final relation = toolResultText(results, '方程关系') ?? '';
      if (relation == '无解') {
        lines.add('a=0 且 b≠0，方程退化为常数不等于 0，因此无解');
      } else if (relation == '恒等式') {
        lines.add('a=0 且 b=0，任意实数都满足方程');
      } else if (relation == '唯一解') {
        lines.add('a 不为 0，存在唯一 x 截距，代回 ax+b 应接近 0');
      }
    case ToolKind.combination:
      final combinationText = toolResultText(results, '组合 C(n,k)');
      final n = v['n'];
      final k = v['k'];
      if (combinationText == '无效') {
        lines.add('n 和 k 必须是有限非负整数，且 k 不能大于 n');
      }
      if (n != null && k != null && n.isFinite && k.isFinite) {
        if ((n - n.round()).abs() > 1e-9 || (k - k.round()).abs() > 1e-9) {
          lines.add('排列组合只接受整数，本工具不会自动把小数当作有效计数');
        }
        if (n > 170) {
          lines.add('n 超过 170 时阶乘容易超过双精度范围，请把结果视为数量级参考');
        }
      }
      lines.add('C(n,k) 表示不计顺序抽取，A(n,k) 表示计顺序且不放回抽取，n^k 表示可重复有序抽取');
    case ToolKind.percentage:
      final resultText = toolResultText(results, '百分比结果');
      final resultDelta = toolResultNumber(results, '结果差值');
      final newValueDelta = toolResultNumber(results, '新值差值');
      final rate = toolResultNumber(results, '百分比');
      if (resultText == '无效') {
        lines.add('基准值、百分比、百分比结果和新值至少填写两项；反推百分比时基准值不能为 0');
      }
      if (resultDelta != null) {
        lines.add('百分比结果参考值与当前计算相差 ${formatNumber(resultDelta)}');
      }
      if (newValueDelta != null) {
        lines.add('新值参考值与当前计算相差 ${formatNumber(newValueDelta)}');
      }
      if (rate != null && rate.abs() > 100) {
        lines.add('百分比绝对值超过 100%，请确认这是倍数变化而不是折扣/占比输入');
      }
    case ToolKind.proportion:
      final xText = toolResultText(results, 'x');
      final crossDelta = toolResultNumber(results, '交叉乘积差');
      final xDelta = toolResultNumber(results, 'x差值');
      if (xText == '无效') {
        lines.add('a、b、c、x 至少填写三项；作为分母使用的量不能为 0');
      }
      if (crossDelta != null && crossDelta.abs() > 1e-9) {
        lines.add('交叉乘积差为 ${formatNumber(crossDelta)}，说明参考值与比例关系不完全一致');
      }
      if (xDelta != null) {
        lines.add('x 参考值与当前计算相差 ${formatNumber(xDelta)}');
      }
    case ToolKind.probability:
      final eitherText = toolResultText(results, '至少一个发生');
      final p1 = toolResultNumber(results, '事件 A') ?? v['p1'] ?? 0;
      final p2 = toolResultNumber(results, '事件 B') ?? v['p2'] ?? 0;
      if (eitherText == '无效' || p1 < 0 || p1 > 100 || p2 < 0 || p2 > 100) {
        lines.add('概率应落在 0% 到 100%');
      }
      lines.add('按独立事件计算；相关事件要改用条件概率');
    case ToolKind.statistics:
      final count = toolResultNumber(results, '样本数')?.round() ?? 0;
      final cv = toolResultNumber(results, '变异系数');
      lines.add('当前按 $count 个有效样本计算，空白可选样本已忽略');
      if (count < 2) {
        lines.add('少于 2 个样本时样本方差和样本标准差没有定义');
      } else {
        lines.add('样本标准差使用 n-1 修正；总体标准差按 n 计算');
      }
      if (cv != null && cv.isFinite && cv > 30) {
        lines.add('变异系数超过 30%，数据离散程度较高，均值代表性需要谨慎判断');
      }
    case ToolKind.matrix:
      final detText = toolResultText(results, '行列式 det');
      final determinant = toolResultNumber(results, '行列式 det');
      final rank = toolResultNumber(results, '秩');
      final state = toolResultText(results, '可逆状态');
      if (detText == '无效') {
        lines.add('矩阵元素必须是有限数值');
      }
      if (state == '不可逆') {
        lines.add('行列式为 0 或接近 0，矩阵不可逆，线性方程解可能不存在或不唯一');
      } else if (determinant != null && determinant.abs() < 1e-6) {
        lines.add('行列式很接近 0，逆矩阵和求解结果会对输入误差非常敏感');
      }
      if (rank != null && rank < 2) {
        lines.add('秩小于 2，矩阵的两行或两列存在线性相关');
      }
    case ToolKind.complex:
      final divisionText = toolResultText(results, 'z1 ÷ z2');
      final arg1 = toolResultText(results, 'arg(z1)');
      final arg2 = toolResultText(results, 'arg(z2)');
      if (divisionText == '无效') {
        lines.add('z2 为 0 时复数除法无定义');
      }
      if (arg1 == '无效' || arg2 == '无效') {
        lines.add('零复数没有确定幅角');
      }
    case ToolKind.vector:
      final len1 = _hypot(v['x1'] ?? 0, v['y1'] ?? 0);
      final len2 = _hypot(v['x2'] ?? 0, v['y2'] ?? 0);
      final relation = toolResultText(results, '关系');
      if (len1 == 0 || len2 == 0) lines.add('零向量没有方向，夹角不作工程判断');
      if (relation == '同向平行' || relation == '反向平行') {
        lines.add('两个向量平行，叉积接近 0，方向关系比夹角数值更稳定');
      } else if (relation == '垂直') {
        lines.add('两个向量垂直，点积接近 0，可用于正交分解或法向校验');
      }
    case ToolKind.triangle:
      final a = v['a'] ?? 0, b = v['b'] ?? 0, c = v['c'] ?? 0;
      final areaText = toolResultText(results, '面积');
      final type = toolResultText(results, '边长类型');
      if (a <= 0 ||
          b <= 0 ||
          c <= 0 ||
          a + b <= c ||
          a + c <= b ||
          b + c <= a) {
        lines.add('三边必须为正，且任意两边之和大于第三边');
      }
      if (areaText != '无效' && type != null) {
        lines.add('当前三角形类型为$type，角度按余弦定理计算');
      }
      final longest = math.max(a, math.max(b, c));
      final perimeter = a + b + c;
      if (areaText != '无效' && perimeter > 0 && longest / perimeter > 0.49) {
        lines.add('最长边接近另外两边之和，三角形接近退化，面积和角度对输入误差敏感');
      }
    case ToolKind.circle:
      final areaText = toolResultText(results, '面积');
      final diameterDelta = toolResultNumber(results, '直径差值');
      final circumferenceDelta = toolResultNumber(results, '周长差值');
      final areaDelta = toolResultNumber(results, '面积差值');
      if (areaText == '无效') {
        lines.add('半径、直径、周长或面积至少填写一项，且不能为负');
      }
      if (diameterDelta != null) {
        lines.add('直径参考值与当前计算相差 ${formatNumber(diameterDelta)}');
      }
      if (circumferenceDelta != null) {
        lines.add('周长参考值与当前计算相差 ${formatNumber(circumferenceDelta)}');
      }
      if (areaDelta != null) {
        lines.add('面积参考值与当前计算相差 ${formatNumber(areaDelta)}');
      }
      lines.add('圆形计算按理想圆估算，测量直径、周长和面积互相校验时会受到取样和圆度误差影响');
    case ToolKind.scaleRatio:
      final scaledText = toolResultText(results, '缩放后');
      final ratio = toolResultNumber(results, '缩放比例');
      final scaledDelta = toolResultNumber(results, '缩放值差值');
      if (scaledText == '无效') {
        lines.add('原始值、原比例、目标比例和缩放后至少填写三项；原比例不能为 0');
      }
      if (scaledDelta != null) {
        lines.add('缩放后参考值与当前计算相差 ${formatNumber(scaledDelta)}');
      }
      if (ratio != null && ratio.abs() > 10) {
        lines.add('线性缩放超过 10 倍，面积和体积会按平方/立方放大，材料和重量估算要单独校核');
      }
    default:
      break;
  }
  return lines;
}

double _hypot(double x, double y) => math.sqrt(x * x + y * y);
