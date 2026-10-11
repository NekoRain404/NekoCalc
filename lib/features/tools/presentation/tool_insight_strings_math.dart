/// 中文：**数学类工具洞察句的英文**——`tool_insights_math.dart` 里那些句子的中文→英文表。
///       键是中文本身，查不到就原样返回（机制见 `tool_insight_strings.dart` 的文件头）。
///       带插值的句子在下面那张模板表里：键是源码原文（含 `$…`），英文一侧的 `{}` 是载荷位。
/// English: **the English of the math-category tool insight sentences** — the Chinese→English
///          table for the sentences in `tool_insights_math.dart`. The key is the Chinese itself
///          and a miss returns it unchanged (the mechanism is on `tool_insight_strings.dart`'s head).
///          Interpolated sentences sit in the template table below: the key is the source text
///          (including `$…`) and each `{}` on the English side is a payload slot.
library;

const Map<String, String> toolInsightsMathEn = <String, String>{
  'a 为 0 时退化为一元一次方程': 'With a at 0 it degenerates to a linear equation',
  '判别式小于 0，实数域无解': 'Discriminant below 0, no solution over the reals',
  '两个根重合，顶点落在 x 轴上': 'The two roots coincide and the vertex lies on the x-axis',
  '系数矩阵秩小于增广矩阵秩，两条直线平行且不重合，无交点':
      'Coefficient rank below augmented rank: the two lines are parallel and distinct, with no intersection',
  '系数矩阵和增广矩阵秩相同但 D=0，两条直线重合或方程退化':
      'Coefficient and augmented ranks are equal but D=0: the two lines coincide or the system degenerates',
  'D 接近 0，解会很敏感，输入稍变结果就可能跳动':
      'D near 0: the solution is sensitive and a small input change can shift the result',
  'D 不为 0，有唯一解': 'D is not 0: unique solution',
  '指数或对数结果无效，通常来自非有限输入、溢出或实数域不支持的幂运算':
      'The power or logarithm result is invalid, usually from a non-finite input, overflow or a power the reals do not support',
  'x 必须大于 0 才能计算 ln(x)、log10(x) 和换底对数':
      'x must be greater than 0 to compute ln(x), log10(x) and base-change logarithms',
  'y 为 0 时 y 次根无定义，x^0 仍按 1 处理':
      'With y at 0 the y-th root is undefined; x^0 is still taken as 1',
  '换底对数 log_y(x) 要求底数 y 大于 0 且不等于 1':
      'The base-change logarithm log_y(x) requires a base y greater than 0 and not 1',
  '指数输入较大，结果可能进入科学计数法或超出双精度可表示范围':
      'The exponent input is large: the result may enter scientific notation or exceed the range a double can hold',
  '指数对数按实数域和双精度浮点计算，复数幂和多值根未展开':
      'Powers and logarithms are computed over the reals in double precision; complex powers and multi-valued roots are not expanded',
  'a=0 且 b≠0，方程退化为常数不等于 0，因此无解':
      'a=0 and b≠0: the equation degenerates to a constant not equal to 0, so there is no solution',
  'a=0 且 b=0，任意实数都满足方程':
      'a=0 and b=0: every real number satisfies the equation',
  'a 不为 0，存在唯一 x 截距，代回 ax+b 应接近 0':
      'a is not 0, so a unique x-intercept exists; substituting back into ax+b should give near 0',
  'n 和 k 必须是有限非负整数，且 k 不能大于 n':
      'n and k must be finite non-negative integers and k cannot exceed n',
  '排列组合只接受整数，本工具不会自动把小数当作有效计数':
      'Permutations and combinations take integers only; this tool does not treat a decimal as a valid count',
  'n 超过 170 时阶乘容易超过双精度范围，请把结果视为数量级参考':
      'For n above 170 the factorial tends to exceed the double range; treat the result as an order-of-magnitude reference',
  'C(n,k) 表示不计顺序抽取，A(n,k) 表示计顺序且不放回抽取，n^k 表示可重复有序抽取':
      'C(n,k) counts unordered draws, A(n,k) counts ordered draws without replacement, n^k counts ordered draws with repetition',
  '基准值、百分比、百分比结果和新值至少填写两项；反推百分比时基准值不能为 0':
      'Fill at least two of base value, percentage, percent result and new value; when back-solving the percentage the base value cannot be 0',
  '百分比绝对值超过 100%，请确认这是倍数变化而不是折扣/占比输入':
      'The percentage magnitude is above 100%: confirm this is a multiple change rather than a discount/share input',
  '概率应落在 0% 到 100%': 'Probability should fall between 0% and 100%',
  '按独立事件计算；相关事件要改用条件概率':
      'Computed as independent events; use conditional probability for dependent events',
  '少于 2 个样本时样本方差和样本标准差没有定义':
      'With fewer than 2 samples the sample variance and sample standard deviation are undefined',
  '样本标准差使用 n-1 修正；总体标准差按 n 计算':
      'Sample standard deviation uses the n-1 correction; population standard deviation divides by n',
  '变异系数超过 30%，数据离散程度较高，均值代表性需要谨慎判断':
      'Coefficient of variation above 30%: the data is widely spread and the mean should be read with care',
  '矩阵元素必须是有限数值': 'Matrix entries must be finite numbers',
  '行列式为 0 或接近 0，矩阵不可逆，线性方程解可能不存在或不唯一':
      'The determinant is 0 or near 0, the matrix is not invertible, and a linear solution may not exist or may not be unique',
  '行列式很接近 0，逆矩阵和求解结果会对输入误差非常敏感':
      'The determinant is very close to 0: the inverse and the solution are highly sensitive to input error',
  '秩小于 2，矩阵的两行或两列存在线性相关':
      'Rank below 2: two rows or two columns of the matrix are linearly dependent',
  'z2 为 0 时复数除法无定义': 'With z2 at 0 complex division is undefined',
  '零复数没有确定幅角': 'The zero complex number has no defined argument',
  '零向量没有方向，夹角不作工程判断':
      'The zero vector has no direction, so the angle supports no engineering judgement',
  '两个向量平行，叉积接近 0，方向关系比夹角数值更稳定':
      'The two vectors are parallel and the cross product is near 0; the direction relation is more stable than the angle value',
  '两个向量垂直，点积接近 0，可用于正交分解或法向校验':
      'The two vectors are perpendicular and the dot product is near 0; usable for orthogonal decomposition or a normal-direction check',
  '三边必须为正，且任意两边之和大于第三边':
      'All three sides must be positive, and any two sides must sum to more than the third',
  '最长边接近另外两边之和，三角形接近退化，面积和角度对输入误差敏感':
      'The longest side approaches the sum of the other two, the triangle is near-degenerate, and area and angles are sensitive to input error',
  '半径、直径、周长或面积至少填写一项，且不能为负':
      'Fill at least one of radius, diameter, circumference or area, and none may be negative',
  '圆形计算按理想圆估算，测量直径、周长和面积互相校验时会受到取样和圆度误差影响':
      'Circle calculations assume an ideal circle; cross-checking a measured diameter, circumference and area is subject to sampling and roundness error',
  '原始值、原比例、目标比例和缩放后至少填写三项；作为分母使用的量不能为 0':
      'Fill at least three of original value, original ratio, target ratio and after scaling; a quantity used as a divisor cannot be 0',
  '线性缩放超过 10 倍，面积和体积会按平方/立方放大，材料和重量估算要单独校核':
      'Linear scaling above 10x: area and volume grow with the square/cube, so material and weight estimates need a separate check',
};

/// 中文：带插值的句子。键是源码原文，英文一侧的 `{}` 按出现顺序接住载荷。
/// English: interpolated sentences. The key is the source text; each `{}` on the English side takes
///          the payloads in order.
const Map<String, String> toolInsightTemplatesMathEn = <String, String>{
  r'代回残差为 ${formatNumber(residual1)}、${formatNumber(residual2)}，越接近 0 校验越好':
      'Back-substitution residuals {} and {}, the closer to 0 the better the check',
  r'百分比结果参考值与当前计算相差 ${formatNumber(resultDelta)}':
      'Percent result reference differs from the current calculation by {}',
  r'新值参考值与当前计算相差 ${formatNumber(newValueDelta)}':
      'New value reference differs from the current calculation by {}',
  r'当前按 $count 个有效样本计算，空白可选样本已忽略':
      'Currently computed from {} valid samples; blank optional samples are ignored',
  r'当前三角形类型为$type，角度按余弦定理计算':
      'Triangle type {}, angles computed with the law of cosines',
  r'直径参考值与当前计算相差 ${formatNumber(diameterDelta)}':
      'Diameter reference differs from the current calculation by {}',
  r'周长参考值与当前计算相差 ${formatNumber(circumferenceDelta)}':
      'Circumference reference differs from the current calculation by {}',
  r'面积参考值与当前计算相差 ${formatNumber(areaDelta)}':
      'Area reference differs from the current calculation by {}',
  r'交叉乘积差为 ${formatNumber(crossDelta)}，说明参考值与比例关系不完全一致':
      'Cross-product gap is {}, meaning the reference does not fully match the ratio relation',
  r'缩放后参考值与当前计算相差 ${formatNumber(scaledDelta)}':
      'After-scaling reference differs from the current calculation by {}',
};
