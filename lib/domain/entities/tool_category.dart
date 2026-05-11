enum ToolCategory {
  math('方程与数学', '多项式、方程组、统计与矩阵'),
  electronics('电路与电子', '分压、滤波、dBm 与电源计算'),
  mechanical('机械与工程', '齿轮、扭矩、弹簧与气缸'),
  finance('财务与商业', '贷款、复利、利润率与 ROI'),
  science('物理与科学', '运动、热量、浓度与波动'),
  units('单位换算', '长度、压力、电学和频率'),
  programming('编程与数据', '进制、时间戳、编码与数据单位'),
  custom('自定义工具', '个人公式和专属工作流');

  const ToolCategory(this.title, this.subtitle);

  final String title;
  final String subtitle;
}
