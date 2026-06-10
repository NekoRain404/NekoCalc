import '../../data/repositories/tool_usage_repository.dart';
import '../../domain/entities/tool_category.dart';
import '../../domain/entities/tool_definition.dart';
import '../../domain/usecases/recent_tool_action_result.dart';
import '../../domain/usecases/tool_catalog.dart';

class ToolsController {
  ToolsController({required this.toolUsageRepository});

  final ToolUsageRepository toolUsageRepository;
  static const int recentDisplayLimit = 8;
  static const int _recentLoadLimit = 24;

  Future<ToolsState> load() async {
    final availableToolIds = toolCatalog.map((tool) => tool.id).toSet();
    final favoriteIds = (await toolUsageRepository.favoriteIds())
        .where(availableToolIds.contains)
        .toSet();
    final recentIds = _normalizeRecentIds(
      await toolUsageRepository.recentIds(limit: _recentLoadLimit),
      availableToolIds: availableToolIds,
    );
    return ToolsState(favoriteIds: favoriteIds, recentIds: recentIds);
  }

  Future<void> markRecent(ToolDefinition tool) =>
      toolUsageRepository.markRecent(tool.id);

  Future<RecentToolActionResult> removeRecent(ToolDefinition tool) async {
    try {
      final affectedCount = await toolUsageRepository.removeRecent(tool.id);
      return RecentToolActionResult.remove(
        toolTitle: tool.title,
        affectedCount: affectedCount,
      );
    } catch (error) {
      return RecentToolActionResult.failed(
        action: RecentToolAction.remove,
        error: error,
      );
    }
  }

  Future<RecentToolActionResult> clearRecent() async {
    try {
      final affectedCount = await toolUsageRepository.clearRecent();
      return RecentToolActionResult.clear(affectedCount: affectedCount);
    } catch (error) {
      return RecentToolActionResult.failed(
        action: RecentToolAction.clear,
        error: error,
      );
    }
  }

  Future<void> setFavorite(ToolDefinition tool, bool favorite) {
    return toolUsageRepository.setFavorite(tool.id, favorite);
  }

  List<ToolDefinition> search(String query, {ToolCategory? category}) {
    return searchTools(query, category: category)
        .map((result) => result.tool)
        .toList(growable: false);
  }

  List<ToolSearchResult> searchTools(String query, {ToolCategory? category}) {
    final normalized = _normalizeSearchText(query);
    final queryVariants = _searchTextVariants(query).toList();
    final candidates = toolCatalog
        .where((tool) => category == null || tool.category == category)
        .map((tool) => _rankTool(tool, normalized, queryVariants))
        .where((result) => normalized.isEmpty || result.score > 0)
        .toList();
    candidates.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) return scoreOrder;
      if (a.tool.featured != b.tool.featured) return a.tool.featured ? -1 : 1;
      final categoryOrder =
          a.tool.category.index.compareTo(b.tool.category.index);
      if (categoryOrder != 0) return categoryOrder;
      return a.tool.title.compareTo(b.tool.title);
    });
    return candidates;
  }

  Map<ToolCategory, int> searchCategoryCounts(String query) {
    final counts = {for (final category in ToolCategory.values) category: 0};
    for (final result in searchTools(query)) {
      counts[result.tool.category] = (counts[result.tool.category] ?? 0) + 1;
    }
    return counts;
  }

  List<ToolSearchResult> searchAlternatives(
    String query, {
    required ToolCategory excludedCategory,
    int limit = 4,
  }) {
    if (_normalizeSearchText(query).isEmpty || limit <= 0) {
      return const [];
    }
    return searchTools(query)
        .where((result) => result.tool.category != excludedCategory)
        .take(limit)
        .toList(growable: false);
  }

  List<ToolSearchSuggestion> searchSuggestions(
    String query, {
    ToolCategory? category,
    int limit = 4,
  }) {
    final normalized = _normalizeSearchText(query);
    if (normalized.length < 3 || limit <= 0) return const [];
    if (searchTools(query, category: category).isNotEmpty) return const [];

    final queryVariants = _searchTextVariants(query)
        .where((variant) => variant.length >= 3)
        .toSet()
        .toList(growable: false);
    if (queryVariants.isEmpty) return const [];

    final ranked = <ToolSearchSuggestion>[];
    for (final tool in toolCatalog) {
      if (category != null && tool.category != category) continue;
      for (final phrase in _suggestionPhrases(tool)) {
        final suggestion = _rankSuggestion(
          phrase: phrase,
          tool: tool,
          queryVariants: queryVariants,
        );
        if (suggestion != null) ranked.add(suggestion);
      }
    }

    ranked.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) return scoreOrder;
      final textOrder = a.text.length.compareTo(b.text.length);
      if (textOrder != 0) return textOrder;
      return a.text.compareTo(b.text);
    });

    final suggestions = <ToolSearchSuggestion>[];
    final seenTexts = <String>{};
    final seenTools = <String>{};
    for (final suggestion in ranked) {
      if (!seenTexts.add(suggestion.text)) continue;
      if (!seenTools.add(suggestion.tool.id) &&
          suggestion.score < _strongSuggestionScore) {
        continue;
      }
      suggestions.add(suggestion);
      if (suggestions.length == limit) break;
    }
    return suggestions;
  }

  List<String> searchExamples({ToolCategory? category, int limit = 6}) {
    final examples =
        _searchExamplesByCategory[category] ?? _generalSearchExamples;
    return examples.take(limit).toList(growable: false);
  }

  List<String> _normalizeRecentIds(
    List<String> ids, {
    required Set<String> availableToolIds,
  }) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final id in ids) {
      if (!availableToolIds.contains(id) || !seen.add(id)) continue;
      normalized.add(id);
      if (normalized.length == recentDisplayLimit) break;
    }
    return normalized;
  }

  ToolSearchResult _rankTool(
    ToolDefinition tool,
    String query,
    List<String> queryVariants,
  ) {
    if (query.isEmpty) {
      return ToolSearchResult(
        tool: tool,
        matchLabel: tool.group,
        matchText: tool.category.title,
        score: 1,
      );
    }

    final checks = <({String text, String label, int score})>[
      (text: tool.title, label: '标题', score: 100),
      (text: tool.id.replaceAll('_', ' '), label: '工具 ID', score: 94),
      (text: tool.id, label: '工具 ID', score: 92),
      (text: tool.description, label: '说明', score: 76),
      (text: tool.formula, label: '公式', score: 72),
      (text: tool.explanation, label: '解释', score: 62),
      (text: tool.group, label: tool.group, score: 58),
      (text: tool.category.title, label: tool.category.title, score: 54),
      (text: tool.category.subtitle, label: tool.category.title, score: 50),
      ..._searchAliases(tool).map(
        (alias) => (text: alias, label: '别名', score: 86),
      ),
      ...tool.inputs.expand((input) => [
            (text: input.label, label: '输入项', score: 68),
            (text: input.unit, label: '单位', score: 56),
            (text: input.key, label: '参数', score: 52),
          ]),
    ];

    var bestScore = 0;
    var bestLabel = '';
    var bestText = '';
    for (final check in checks) {
      for (final value in _searchTextVariants(check.text)) {
        for (final variant in queryVariants) {
          if (variant.isEmpty) continue;
          if (value == variant) {
            final score = check.score + 32;
            if (score > bestScore) {
              bestScore = score;
              bestLabel = check.label;
              bestText = check.text;
            }
          } else if (value.startsWith(variant)) {
            final score = check.score + 18;
            if (score > bestScore) {
              bestScore = score;
              bestLabel = check.label;
              bestText = check.text;
            }
          } else if (value.contains(variant)) {
            if (check.score > bestScore) {
              bestScore = check.score;
              bestLabel = check.label;
              bestText = check.text;
            }
          }
        }
      }
    }

    final tokenMatch = _tokenMatch(tool, queryVariants);
    final tokenScore = tokenMatch?.score ?? 0;
    if (tokenScore > 0 && tokenScore > bestScore) {
      bestScore = tokenScore;
      bestLabel = '关键词';
      bestText = tokenMatch?.text ?? '';
    }

    return ToolSearchResult(
      tool: tool,
      matchLabel: bestLabel,
      matchText: _compactMatchText(bestText),
      score: bestScore == 0 ? 0 : bestScore + (tool.featured ? 3 : 0),
    );
  }

  List<String> _searchAliases(ToolDefinition tool) {
    final aliases = <String>[
      tool.title.replaceAll('/', ' '),
      tool.description.replaceAll('/', ' '),
    ];
    switch (tool.id) {
      case 'linear_system':
        aliases.addAll(const [
          'linear system',
          'simultaneous equations',
          '2x2 system',
          'cramers rule',
          'determinant method',
          'system rank',
          'no solution',
          'infinite solutions',
          '方程组',
          '二元一次方程组',
          '线性方程组',
          '克莱姆法则',
          '行列式求解',
          '无唯一解',
          '无穷多解',
          '方程组秩',
        ]);
      case 'linear_equation':
        aliases.addAll(const [
          'linear equation',
          'solve ax+b=0',
          'first degree equation',
          'x intercept',
          'slope intercept',
          'degenerate equation',
          '一元一次方程',
          '一次方程',
          '求解x',
          'x截距',
          '斜率截距',
          '恒等式',
          '方程退化',
        ]);
      case 'exponential_log':
        aliases.addAll(const [
          'exponent logarithm',
          'power log',
          'natural log',
          'common log',
          'change of base',
          'log base',
          'nth root',
          'reciprocal',
          '指数',
          '对数',
          '指数对数',
          '自然对数',
          '常用对数',
          '换底公式',
          '换底对数',
          'n次根',
          '倒数',
        ]);
      case 'combination':
        aliases.addAll(const [
          'combination',
          'permutation',
          'n choose k',
          'nck',
          'npr',
          'factorial',
          'repeated permutation',
          'combinatorics',
          '排列组合',
          '组合数',
          '排列数',
          '阶乘',
          '可重复排列',
          '抽取',
          '不放回',
          '互补组合',
        ]);
      case 'json_format':
        aliases.addAll(const [
          'json formatter',
          'pretty json',
          'json pretty print',
          'json validator',
          'json 校验',
          'json lines',
          'jsonl',
          'ndjson',
        ]);
      case 'csv_json':
        aliases.addAll(const [
          'csv to json',
          'tsv to json',
          'json to csv',
          'json lines to csv',
          'ndjson to csv',
          'markdown table',
          'sql table',
          '表格转 json',
          'json 转 csv',
        ]);
      case 'data_fit':
        aliases.addAll(const [
          'regression',
          'least squares',
          'trendline',
          'curve fit',
          'curve fitting',
          'scatter fit',
          'log metrics',
          'ndjson metrics',
          '曲线拟合',
          '趋势线',
          '最小二乘',
          '指标日志',
        ]);
      case 'percentage':
        aliases.addAll(const [
          'percentage calculator',
          'percent calculator',
          'percentage change',
          'percent change',
          'reverse percentage',
          'find percentage',
          'what percent',
          'base from percent',
          'increase decrease percent',
          '百分比',
          '百分比计算',
          '百分比变化',
          '变化率',
          '涨幅',
          '降幅',
          '反推百分比',
          '反推基准值',
          '反推原值',
          '反推新值',
        ]);
      case 'circle':
        aliases.addAll(const [
          'circle calculator',
          'radius diameter circumference area',
          'area to radius',
          'circumference to radius',
          'diameter to area',
          'circle area',
          'circle circumference',
          '圆',
          '圆形',
          '圆面积',
          '圆周长',
          '半径直径',
          '面积求半径',
          '周长求半径',
          '直径求面积',
        ]);
      case 'scale_ratio':
        aliases.addAll(const [
          'scale ratio',
          'scale calculator',
          'rescale',
          'resize by ratio',
          'model scale',
          'drawing scale',
          'map scale',
          'reverse scale',
          'scaled value',
          '比例缩放',
          '缩放比例',
          '图纸比例',
          '模型比例',
          '地图比例',
          '反推缩放',
          '反推比例',
          '反推原始值',
          '面积缩放',
          '体积缩放',
        ]);
      case 'proportion':
        aliases.addAll(const [
          'proportion calculator',
          'ratio calculator',
          'rule of three',
          'cross multiplication',
          'solve proportion',
          'reverse ratio',
          'a:b=c:x',
          '比例',
          '比例计算',
          '配比',
          '三项比例',
          '交叉相乘',
          '交叉乘积',
          '反推比例',
          '反推x',
          '反推a',
          '反推b',
          '反推c',
        ]);
      case 'probability':
        aliases.addAll(const [
          'probability calculator',
          'independent events',
          'at least one',
          'both events',
          'neither event',
          'only a',
          'only b',
          'at most one',
          'complement probability',
          '概率',
          '概率计算',
          '独立事件',
          '至少一个',
          '同时发生',
          '都不发生',
          '仅a发生',
          '仅b发生',
          '至多一个',
          '补集概率',
        ]);
      case 'triangle':
        aliases.addAll(const [
          'triangle calculator',
          'heron formula',
          'triangle area',
          'triangle angles',
          'inradius',
          'circumradius',
          'triangle height',
          'triangle type',
          '三角形',
          '三角形面积',
          '海伦公式',
          '三角形角度',
          '内切圆半径',
          '外接圆半径',
          '三角形高',
          '三角形类型',
          '等腰三角形',
          '直角三角形',
        ]);
      case 'matrix':
        aliases.addAll(const [
          'matrix calculator',
          '2x2 matrix',
          'determinant',
          'inverse matrix',
          'matrix rank',
          'eigenvalue',
          'eigenvalues',
          'matrix norm',
          'trace',
          'singular matrix',
          '矩阵',
          '矩阵计算',
          '行列式',
          '逆矩阵',
          '矩阵秩',
          '特征值',
          '矩阵范数',
          '奇异矩阵',
        ]);
      case 'complex':
        aliases.addAll(const [
          'complex calculator',
          'complex number',
          'complex division',
          'complex conjugate',
          'complex argument',
          'complex magnitude',
          '复数',
          '复数计算',
          '复数除法',
          '复数共轭',
          '复数幅角',
          '复数模长',
        ]);
      case 'vector':
        aliases.addAll(const [
          'vector calculator',
          'dot product',
          'cross product',
          'vector projection',
          'vector angle',
          'parallel vectors',
          'perpendicular vectors',
          'vector distance',
          'direction angle',
          '向量',
          '向量计算',
          '点积',
          '叉积',
          '向量投影',
          '向量夹角',
          '平行向量',
          '垂直向量',
          '方向角',
        ]);
      case 'base64':
        aliases.addAll(const [
          'base64 encode',
          'base64 decode',
          'base64url',
          'data url',
          '编码 base64',
          '解码 base64',
        ]);
      case 'url_codec':
        aliases.addAll(const [
          'url encode',
          'url decode',
          'percent encode',
          'percent decode',
          'uri encode',
          'uri decode',
          '网址编码',
          '百分号编码',
        ]);
      case 'query_params':
        aliases.addAll(const [
          'query string',
          'url params',
          'url parameters',
          'search params',
          'curl params',
          '表单参数',
          '链接参数',
        ]);
      case 'jwt_decode':
        aliases.addAll(const [
          'jwt token',
          'bearer token',
          'access token',
          'id token',
          'claims',
          'jwt claims',
          'token 解析',
        ]);
      case 'html_entities':
        aliases.addAll(const [
          'html entity',
          'html decode',
          'html encode',
          'escape html',
          'unescape html',
          '实体转义',
        ]);
      case 'regex_test':
        aliases.addAll(const [
          'regex',
          'regexp',
          'regular expression',
          '正则表达式',
          '匹配测试',
        ]);
      case 'text_stats':
        aliases.addAll(const [
          'word count',
          'character count',
          'line count',
          'trailing whitespace',
          '字数统计',
          '行尾空白',
        ]);
      case 'statistics':
        aliases.addAll(const [
          'statistics',
          'descriptive statistics',
          'mean median variance',
          'standard deviation',
          'sample standard deviation',
          'population standard deviation',
          'coefficient of variation',
          '统计',
          '均值',
          '平均数',
          '中位数',
          '方差',
          '标准差',
          '样本标准差',
          '总体标准差',
          '变异系数',
        ]);
      case 'ph':
        aliases.addAll(const [
          'ph',
          'poh',
          'acid base',
          'hydrogen ion',
          'hydroxide',
          'hydroxide ion',
          'h+ concentration',
          'oh- concentration',
          'kw water',
          'target ph',
          'ph target concentration',
          '酸碱',
          '酸性',
          '碱性',
          '氢离子',
          '氢氧根',
          '氢氧根离子',
          '氢离子浓度',
          '氢氧根浓度',
          '目标pH',
          '目标氢离子浓度',
        ]);
      case 'concentration':
        aliases.addAll(const [
          'concentration',
          'molarity',
          'molar concentration',
          'mass concentration',
          'solution concentration',
          'solution dilution',
          'stock solution',
          'g per liter',
          'g/l',
          'mg/ml',
          'mg/l',
          'mol/l',
          'moles per liter',
          'molar mass',
          'solute mass',
          '浓度换算',
          '质量浓度',
          '摩尔浓度',
          '物质的量浓度',
          '溶液浓度',
          '溶液配制',
          '溶质量',
          '摩尔质量',
          '反推体积',
          '反推溶质量',
        ]);
      case 'ideal_gas':
        aliases.addAll(const [
          'ideal gas',
          'ideal gas law',
          'pv=nrt',
          'pv nrt',
          'gas pressure',
          'gas volume',
          'gas temperature',
          'moles gas',
          'amount of substance',
          'molar volume',
          'avogadro number',
          '理想气体',
          '理想气体状态方程',
          '气体压力',
          '气体体积',
          '气体温度',
          '物质的量',
          '摩尔体积',
          '反推压力',
          '反推温度',
          '反推气体体积',
          '反推物质的量',
        ]);
      case 'electricity_cost':
        aliases.addAll(const [
          'electricity cost',
          'electric bill',
          'power bill',
          'energy cost',
          'kwh cost',
          'cost per kwh',
          'appliance cost',
          'running cost',
          'target bill',
          'target cost',
          'reverse power',
          'reverse runtime',
          'reverse electricity price',
          '电费',
          '电费计算',
          '用电费用',
          '电价',
          '用电量',
          '日均用电',
          '家电电费',
          '运行成本',
          '目标费用',
          '目标电费',
          '反推功率',
          '反推时长',
          '反推天数',
          '反推电价',
        ]);
      case 'wavelength':
        aliases.addAll(const [
          'wavelength',
          'frequency wavelength',
          'wave speed',
          'wave velocity',
          'wave period',
          'period frequency',
          'wave number',
          'angular frequency',
          'sound wavelength',
          'lambda frequency',
          '波长频率',
          '波速',
          '波速频率',
          '波周期',
          '波数',
          '角频率',
          '声波波长',
          '反推频率',
          '反推波速',
          '反推波长',
        ]);
      case 'half_life':
        aliases.addAll(const [
          'half life',
          'half-life',
          'decay',
          'radioactive decay',
          'exponential decay',
          'remaining amount',
          'remaining ratio',
          'decay constant',
          'reverse half life',
          'reverse decay time',
          'half life remaining',
          '半衰期',
          '放射性衰变',
          '指数衰减',
          '剩余量',
          '剩余比例',
          '衰变常数',
          '反推半衰期',
          '反推时间',
          '反推剩余量',
        ]);
      case 'heat':
        aliases.addAll(const [
          'heat',
          'heat capacity',
          'specific heat',
          'thermal energy',
          'temperature change',
          'delta t',
          'sensible heat',
          'heat transfer',
          'q=mcdt',
          'q mc delta t',
          '热量',
          '热量计算',
          '比热容',
          '热容',
          '温度变化',
          '温升',
          '降温',
          '吸热',
          '放热',
          '反推质量',
          '反推比热容',
          '反推温升',
        ]);
      case 'bmi':
        aliases.addAll(const [
          'body mass index',
          'healthy weight',
          'ideal weight',
          'normal weight range',
          'waist height ratio',
          'waist-to-height ratio',
          'wthr',
          'bsa',
          'body surface area',
          '身高体重',
          '健康体重',
          '理想体重',
          '正常体重',
          '体重区间',
          '腰高比',
          '腰围身高比',
          '体表面积',
        ]);
      case 'fuel_economy':
        aliases.addAll(const [
          'fuel economy',
          'fuel consumption',
          'gas mileage',
          'mileage',
          'mpg',
          'km per liter',
          'km/l',
          'l/100km',
          'fuel cost',
          'cost per km',
          'cost per 100km',
          'tank range',
          'range per tank',
          'annual fuel cost',
          'co2 emissions',
          'carbon emissions',
          'target fuel economy',
          'target consumption',
          'fuel needed',
          'distance from fuel',
          'reverse fuel economy',
          '油耗',
          '燃油消耗',
          '百公里油耗',
          '目标油耗',
          '每公里成本',
          '百公里成本',
          '油费',
          '燃油成本',
          '反推里程',
          '反推燃油',
          '反推油耗',
          '满箱续航',
          '油箱续航',
          '年油费',
          '年燃油费用',
          '二氧化碳排放',
          '碳排放',
        ]);
      case 'break_even':
        aliases.addAll(const [
          'break even',
          'break-even',
          'break even point',
          'breakeven point',
          'contribution margin',
          'margin of safety',
          'target units',
          'target quantity',
          'required price',
          'fixed cost recovery',
          'reverse fixed cost',
          'reverse unit price',
          'reverse variable cost',
          '盈亏平衡',
          '盈亏平衡点',
          '平衡销量',
          '平衡销售额',
          '边际贡献',
          '边际率',
          '目标销量',
          '保本销量',
          '保本销售额',
          '反推固定成本',
          '反推单价',
          '反推变动成本',
        ]);
      case 'loan':
        aliases.addAll(const [
          'loan calculator',
          'mortgage calculator',
          'monthly payment',
          'loan payment',
          'payment from amount',
          'target monthly payment',
          'affordable loan',
          'reverse loan amount',
          'reverse loan rate',
          'interest burden',
          'principal interest',
          'amortization',
          '贷款',
          '贷款月供',
          '房贷',
          '车贷',
          '等额本息',
          '目标月供',
          '可贷金额',
          '反推贷款金额',
          '反推贷款额',
          '反推年利率',
          '利息占本金',
          '本金利息',
        ]);
      case 'annuity':
        aliases.addAll(const [
          'annuity calculator',
          'future value annuity',
          'regular investment',
          'periodic investment',
          'sip calculator',
          'target future value',
          'required contribution',
          'reverse annuity rate',
          'retirement contribution',
          '定投',
          '基金定投',
          '年金',
          '年金终值',
          '定投终值',
          '目标终值',
          '目标定投',
          '每期投入',
          '反推每期投入',
          '反推年化收益',
          '养老金',
          '周期储蓄',
        ]);
      case 'installment':
        aliases.addAll(const [
          'installment calculator',
          'buy now pay later',
          'bnpl',
          'monthly installment',
          'installment fee',
          'target installment',
          'affordable price',
          'reverse installment fee',
          'reverse item price',
          '分期',
          '分期付款',
          '信用卡分期',
          '消费分期',
          '目标每期',
          '每期付款',
          '可承受价格',
          '反推商品价格',
          '反推手续费',
          '反推手续费率',
          '分期手续费',
        ]);
      case 'profit_margin':
        aliases.addAll(const [
          'profit margin',
          'gross margin',
          'gross profit',
          'markup',
          'markup rate',
          'cost price margin',
          'target margin',
          'target profit',
          'required price',
          'reverse margin',
          'reverse price',
          'reverse cost',
          'break even price',
          '利润率',
          '毛利率',
          '毛利润',
          '单件利润',
          '目标毛利率',
          '目标利润',
          '加价率',
          '成本占比',
          '保本售价',
          '反推售价',
          '反推成本',
          '反推利润',
          '反推毛利率',
        ]);
      case 'compound':
        aliases.addAll(const [
          'compound interest',
          'compound calculator',
          'compound future value',
          'compound present value',
          'target future value',
          'required rate',
          'annual return',
          'annualized return',
          'growth multiple',
          'investment growth',
          'reverse compound',
          'reverse principal',
          'reverse rate',
          'reverse years',
          '复利',
          '复利计算',
          '目标终值',
          '未来价值',
          '终值',
          '本金反推',
          '收益率反推',
          '年化收益反推',
          '年限反推',
          '反推本金',
          '反推收益率',
          '反推年化收益',
          '反推年限',
          '增长倍数',
        ]);
      case 'roi':
        aliases.addAll(const [
          'return on investment',
          'investment return',
          'annualized roi',
          'annualized return',
          'annual roi',
          'payback',
          'payback period',
          'simple payback',
          'return multiple',
          'net return',
          'target roi',
          'required return',
          'required gain',
          'reverse roi',
          'reverse investment',
          'investment needed',
          '投资回报',
          '投资回报率',
          '目标roi',
          '目标回报率',
          '年化roi',
          '年化回报',
          '回报倍数',
          '回本率',
          '回收期',
          '简单回收期',
          '净收益',
          '反推收益',
          '反推投入',
          '反推投资',
        ]);
      case 'discount':
        aliases.addAll(const [
          'discount calculator',
          'sale price',
          'final price',
          'original price',
          'discount rate',
          'saving amount',
          'coupon price',
          'reverse discount',
          'reverse final price',
          '折扣',
          '折扣计算',
          '到手价',
          '券后价',
          '优惠价',
          '原价反推',
          '折扣反推',
          '反推折扣',
          '反推原价',
          '反推到手价',
          '节省金额',
          '优惠比例',
        ]);
      case 'tax':
        aliases.addAll(const [
          'tax calculator',
          'tax included',
          'tax excluded',
          'gross net tax',
          'vat',
          'value added tax',
          'reverse tax',
          'tax rate',
          'net amount',
          'gross amount',
          'tax burden',
          '含税',
          '不含税',
          '税前税后',
          '税前金额',
          '含税金额',
          '价税分离',
          '价税合计',
          '税额',
          '税负率',
          '增值税',
          '反推税率',
          '反推税前',
          '反推含税',
        ]);
      case 'inflation':
        aliases.addAll(const [
          'inflation calculator',
          'inflation adjustment',
          'purchasing power',
          'future value',
          'present value',
          'cpi',
          'consumer price index',
          'price level',
          'cost of living',
          'target amount',
          'reverse inflation',
          'required inflation rate',
          'inflation rate',
          'years to target',
          '通胀',
          '通货膨胀',
          '购买力',
          '购买力折现',
          '未来价值',
          '未来等值',
          '当前金额',
          '累计涨幅',
          '物价上涨',
          '生活成本',
          '目标金额',
          '反推通胀',
          '反推通胀率',
          '反推年数',
          '反推当前金额',
        ]);
      case 'motion':
        aliases.addAll(const [
          'distance time speed',
          'speed distance time',
          'speed time distance',
          'distance calculator',
          'pace calculator',
          'running pace',
          'travel time',
          'average speed',
          'km/h',
          'mph',
          'min per km',
          '速度时间距离',
          '距离时间速度',
          '匀速运动',
          '平均速度',
          '配速',
          '跑步配速',
          '行程时间',
          '三选二',
        ]);
      case 'free_fall':
        aliases.addAll(const [
          'free fall',
          'fall time',
          'drop height',
          'drop speed',
          'impact speed',
          'impact energy',
          'drop energy',
          'initial velocity',
          'initial speed',
          'gravity fall',
          'falling object',
          '落体',
          '自由落体',
          '下落时间',
          '落地速度',
          '冲击速度',
          '冲击能量',
          '缓冲距离',
          '缓冲平均力',
          '平均冲击力',
          '初速度',
          '重力加速度',
        ]);
      case 'work_power':
        aliases.addAll(const [
          'work power',
          'mechanical work',
          'mechanical power',
          'power from force',
          'force distance time',
          'work energy',
          'efficiency loss',
          'loss power',
          'horsepower',
          'hp',
          'ps horsepower',
          'angle work',
          'force displacement angle',
          '功与功率',
          '机械功',
          '机械功率',
          '做功',
          '平均功率',
          '输入功率',
          '损耗功率',
          '效率损耗',
          '马力',
          '力位移夹角',
          '目标功率',
          '反推作用力',
          '目标功率所需时间',
          '目标功率所需力',
        ]);
      case 'kinetic_energy':
        aliases.addAll(const [
          'kinetic energy',
          'potential energy',
          'mechanical energy',
          'target total energy',
          'required speed energy',
          'required height energy',
          'equivalent height',
          '动能',
          '势能',
          '机械能',
          '总能量',
          '目标总能量',
          '反推速度',
          '反推高度',
          '等效高度',
        ]);
      case 'density':
        aliases.addAll(const [
          'density calculator',
          'mass volume density',
          'density mass volume',
          'specific volume',
          'kg per cubic meter',
          'kg/m3',
          'g/cm3',
          'mass from density',
          'volume from density',
          '密度质量体积',
          '质量体积密度',
          '比容',
          '体积反推',
          '质量反推',
          '密度反推',
        ]);
      case 'npv':
        aliases.addAll(const [
          'net present value',
          'discounted cash flow',
          'dcf',
          'payback period',
          'discounted payback',
          'profitability index',
          'investment appraisal',
          'present value',
          'cash flow',
          'irr',
          '净现值',
          '折现现金流',
          '折现回收期',
          '回收期',
          '盈利指数',
          '投资评价',
          '现金流',
        ]);
      case 'checksum':
        aliases.addAll(const [
          'sum8',
          'xor8',
          'lrc',
          'checksum',
          'byte checksum',
          '校验码',
        ]);
      case 'fnv_crc':
        aliases.addAll(const [
          'crc',
          'crc32',
          'fnv',
          'fnv1a',
          'hash',
          '哈希',
        ]);
      case 'uuid':
        aliases.addAll(const [
          'guid',
          'uuid v4',
          'random uuid',
          'uuid validate',
          '唯一 id',
        ]);
      case 'color_convert':
        aliases.addAll(const [
          'hex color',
          'rgb color',
          'rgba',
          'hsl',
          '颜色转换',
          '色值',
        ]);
      case 'timestamp':
        aliases.addAll(const [
          'unix time',
          'epoch',
          'epoch time',
          'timestamp convert',
          '时间戳转换',
          '毫秒时间戳',
        ]);
      case 'data_size':
        aliases.addAll(const [
          'bytes',
          'bit',
          'bits',
          'byte converter',
          'bit converter',
          'data size converter',
          'file size',
          'storage size',
          'kbit mbit gbit',
          'kb mb gb tb',
          'kib mib gib tib',
          'kilobit',
          'megabit',
          'gigabit',
          'terabit',
          'kilobyte',
          'megabyte',
          'gigabyte',
          'terabyte',
          'kibibyte',
          'mebibyte',
          'gibibyte',
          'tebibyte',
          '字节换算',
          '比特换算',
          '文件大小',
          '存储容量',
          '比特',
          '千比特',
          '兆比特',
          '吉比特',
          '千字节',
          '兆字节',
          '吉字节',
          '太字节',
        ]);
      case 'rms_peak':
        aliases.addAll(const [
          'vrms vpp',
          'vpp to vrms',
          'vrms to vpp',
          'vpeak',
          'peak voltage',
          'peak to peak',
          'sine rms',
          '50 ohm dbm',
          'dbm to vrms',
          'dbv dbu',
          'crest factor',
          'rms 峰值',
          '峰峰值',
          '有效值',
          '峰值电压',
          '峰峰值换算',
          'dbm转电压',
          '正弦波幅值',
        ]);
      case 'lc_resonance':
        aliases.addAll(const [
          'lc resonance',
          'rlc resonance',
          'resonant frequency',
          'resonance frequency',
          'tank circuit',
          'quality factor',
          'q factor',
          '3db bandwidth',
          'half power point',
          'esr q',
          'inductor capacitor resonance',
          'lc谐振',
          '谐振频率',
          '串联谐振',
          '谐振q值',
          'q值',
          '3db带宽',
          '半功率点',
          '谐振电抗',
        ]);
      case 'rc_filter':
        aliases.addAll(const [
          'rc filter',
          'low pass filter',
          'high pass filter',
          'cutoff frequency',
          'target cutoff frequency',
          'rc required resistor',
          'rc required capacitor',
          'time constant',
          '3db point',
          'rc滤波',
          '低通滤波',
          '高通滤波',
          '截止频率',
          '目标截止频率',
          'rc滤波反推电阻',
          'rc滤波反推电容',
          '时间常数',
          '3db点',
        ]);
      case 'voltage_divider':
        aliases.addAll(const [
          'voltage divider',
          'resistor divider',
          'divider target output',
          'voltage divider target',
          'voltage divider required resistor',
          'required r1 r2',
          'loaded divider',
          'divider load effect',
          '电阻分压',
          '分压器',
          '目标分压输出',
          '分压目标电压',
          '分压反推电阻',
          '所需分压电阻',
          '负载分压',
          '分压负载影响',
        ]);
      case 'led_resistor':
        aliases.addAll(const [
          'led resistor',
          'led current limiting resistor',
          'current limiting resistor',
          'selected resistor',
          'actual led current',
          'led current check',
          'resistor power rating',
          'led voltage drop',
          'led限流',
          'led限流电阻',
          '限流电阻',
          '选用电阻',
          '实际电流',
          '电流偏差',
          '电阻功耗',
          '功率档位',
          'led压降',
        ]);
      case 'ohms_law':
        aliases.addAll(const [
          'ohms law',
          'ohm law',
          'voltage current resistance',
          'voltage current power',
          'power current resistance',
          'v i r p',
          'i squared r',
          'i2r',
          'watt resistor',
          'reverse ohms law',
          '欧姆定律',
          '欧姆计算',
          '电压电流电阻',
          '电压电流功率',
          '功率电流电阻',
          '反推欧姆',
          '欧姆反推',
          '欧姆反推功率',
          '欧姆反推电流',
          '欧姆反推电阻',
        ]);
      case 'resistor_network':
        aliases.addAll(const [
          'resistor network',
          'series resistor',
          'parallel resistor',
          'target series resistance',
          'target parallel resistance',
          'required resistor network',
          'reverse resistor network',
          '电阻串并联',
          '电阻串联',
          '电阻并联',
          '目标串联电阻',
          '目标并联电阻',
          '反推串联电阻',
          '反推并联电阻',
          '所需串并联电阻',
        ]);
      case 'capacitor_network':
        aliases.addAll(const [
          'capacitor network',
          'series capacitor',
          'parallel capacitor',
          'target series capacitance',
          'target parallel capacitance',
          'required capacitor network',
          'reverse capacitor network',
          '电容串并联',
          '电容串联',
          '电容并联',
          '目标串联电容',
          '目标并联电容',
          '反推串联电容',
          '反推并联电容',
          '所需串并联电容',
        ]);
      case 'inductor_network':
        aliases.addAll(const [
          'inductor network',
          'series inductor',
          'parallel inductor',
          'target series inductance',
          'target parallel inductance',
          'required inductor network',
          'reverse inductor network',
          '电感串并联',
          '电感串联',
          '电感并联',
          '目标串联电感',
          '目标并联电感',
          '反推串联电感',
          '反推并联电感',
          '所需串并联电感',
        ]);
      case 'op_amp_gain':
        aliases.addAll(const [
          'op amp gain',
          'opamp gain',
          'operational amplifier gain',
          'non inverting gain',
          'inverting gain',
          'target op amp gain',
          'gain bandwidth product',
          'gbw',
          'closed loop bandwidth',
          'slew rate',
          'required feedback resistor',
          '运放增益',
          '运算放大器增益',
          '同相增益',
          '反相增益',
          '目标运放增益',
          '目标同相增益',
          '增益带宽积',
          '闭环带宽',
          '压摆率',
          '所需反馈电阻',
        ]);
      case 'adc_resolution':
        aliases.addAll(const [
          'adc resolution',
          'adc lsb',
          'adc code',
          'adc quantization',
          'quantization error',
          'enob',
          'effective number of bits',
          'adc dynamic range',
          'input code',
          'sample code',
          '模数转换',
          'adc分辨率',
          'adc码值',
          'adc量化',
          '量化误差',
          '有效位数',
          '输入码值',
          '采样码值',
          '动态范围',
          '满量程',
        ]);
      case 'capacitor_charge':
        aliases.addAll(const [
          'rc charge',
          'rc discharge',
          'capacitor charge',
          'capacitor discharge',
          'capacitor timing',
          'reset capacitor',
          'soft start capacitor',
          'time constant',
          'target capacitor voltage',
          'target charge ratio',
          'inrush current',
          '电容充放电',
          '电容充电',
          '电容放电',
          'rc充电',
          'rc放电',
          '复位电容',
          '软启动电容',
          '时间常数',
          '目标电压',
          '目标充电比例',
          '充电时间',
          '浪涌电流',
        ]);
      case 'timer_555':
        aliases.addAll(const [
          '555 timer',
          'ne555',
          '555 astable',
          'astable timer',
          'timer frequency',
          'duty cycle',
          'target frequency',
          'target duty cycle',
          'required ra rb',
          '555 resistor calculator',
          '555定时器',
          'ne555定时器',
          '555无稳态',
          '无稳态振荡',
          '目标频率',
          '目标占空比',
          '占空比',
          '高电平时间',
          '低电平时间',
          '反推电阻',
          '定时电阻',
        ]);
      case 'battery_life':
        aliases.addAll(const [
          'battery runtime',
          'battery life calculator',
          'battery capacity',
          'battery wh',
          'watt hour battery',
          'wh runtime',
          'mah runtime',
          'target runtime',
          'runtime target',
          'required capacity',
          'capacity planning',
          'current budget',
          'average current budget',
          'reserve margin',
          'usable runtime',
          'load power',
          'watt load',
          '电池续航',
          '续航估算',
          '目标续航',
          '续航目标',
          '容量反推',
          '所需容量',
          '电流预算',
          '平均电流预算',
          '保留余量',
          '余量后续航',
          '瓦时续航',
          '电池容量',
          '负载功率',
        ]);
      case 'wire_voltage_drop':
        aliases.addAll(const [
          'wire voltage drop',
          'cable voltage drop',
          'voltage drop calculator',
          'wire sizing',
          'cable sizing',
          'wire gauge',
          'required wire gauge',
          'required cross section',
          'voltage drop sizing',
          'allowable current',
          'current margin',
          'round trip resistance',
          'copper resistivity',
          'aluminum wire',
          'parallel wires',
          '电线压降',
          '线缆压降',
          '导线压降',
          '压降计算',
          '线径预算',
          '目标压降',
          '所需截面积',
          '允许电流',
          '电流余量',
          '回路电阻',
          '往返线阻',
          '铜线电阻率',
          '铝线压降',
          '并联导线',
        ]);
      case 'pcb_current':
        aliases.addAll(const [
          'pcb trace current',
          'trace current calculator',
          'pcb current calculator',
          'trace width',
          'trace width calculator',
          'required trace width',
          'ipc 2221',
          'ipc-2221',
          'ipc 2152',
          'ipc-2152',
          'copper weight',
          'copper thickness',
          'temperature rise',
          'current density',
          'inner layer derating',
          'outer layer trace',
          'pcb走线电流',
          '走线电流',
          '载流估算',
          '线宽反推',
          '目标电流',
          '目标线宽',
          '所需线宽',
          '铜厚换算',
          '允许温升',
          '电流密度',
          '内层降额',
          '外层走线',
          '厚铜走线',
        ]);
      case 'dcdc_feedback':
        aliases.addAll(const [
          'buck feedback',
          'boost feedback',
          'dcdc feedback',
          'dc dc feedback',
          'feedback divider',
          'feedback resistor',
          'output voltage set',
          'target output voltage',
          'feedback current',
          'divider current',
          'required feedback resistor',
          '反馈分压',
          '反馈电阻',
          '输出电压设定',
          '目标输出电压',
          '目标反馈电流',
          '反馈电流',
          '上拉电阻',
          '下拉电阻',
          '分压电阻',
          'buck反馈',
          'boost反馈',
        ]);
      case 'ldo_power':
        aliases.addAll(const [
          'ldo thermal',
          'ldo heat',
          'linear regulator thermal',
          'dropout voltage',
          'dropout margin',
          'quiescent current',
          'iq',
          'low iq',
          'junction temperature',
          'thermal margin',
          'theta ja',
          'theta-ja',
          'power dissipation',
          '线性稳压',
          '低压差',
          '最小压差',
          '压差余量',
          '静态电流',
          '静态功耗',
          '结温估算',
          '热余量',
          '热阻',
          '温升',
        ]);
      case 'thermal_rise':
        aliases.addAll(const [
          'thermal rise',
          'temperature rise',
          'junction temperature',
          'thermal resistance',
          'thermal margin',
          'thermal derating',
          'power derating',
          'target junction temperature',
          'target thermal margin',
          'maximum ambient temperature',
          'theta ja',
          'theta-ja',
          'power dissipation thermal',
          '热阻温升',
          '温升估算',
          '结温估算',
          '热余量',
          '目标结温',
          '目标热余量',
          '降额功耗',
          '功耗降额',
          '最大环境温度',
          '热阻',
          '散热估算',
        ]);
      case 'pressure_force':
        aliases.addAll(const [
          'pressure force',
          'pressure area force',
          'hydraulic force',
          'pneumatic force',
          'target force pressure',
          'required pressure',
          'required pressure area',
          'required area',
          'surface load',
          '压力面积力',
          '压力作用力',
          '液压作用力',
          '气动作用力',
          '目标作用力',
          '目标力所需压力',
          '目标力所需面积',
          '所需压力',
          '所需面积',
          '单位面积载荷',
        ]);
      case 'beam_bending':
        aliases.addAll(const [
          'beam bending',
          'beam deflection',
          'target deflection',
          'allowable deflection',
          'required inertia',
          'required stiffness',
          'allowable load',
          'deflection',
          'simply supported beam',
          'center load',
          'central load',
          'second moment',
          'area moment of inertia',
          'moment of inertia',
          'section inertia',
          'cm4',
          'cm^4',
          'mm4',
          'mm^4',
          'in4',
          'in^4',
          '挠度',
          '目标挠度',
          '允许挠度',
          '所需惯性矩',
          '所需刚度',
          '允许载荷',
          '梁挠度',
          '简支梁',
          '中央载荷',
          '集中载荷',
          '惯性矩',
          '截面惯性矩',
        ]);
      case 'stress_strain':
        aliases.addAll(const [
          'stress strain',
          'stress and strain',
          'axial stress',
          'engineering stress',
          'young modulus',
          'youngs modulus',
          'elastic modulus',
          'microstrain',
          'n/mm2',
          'n/mm^2',
          'mpa',
          '应力',
          '应变',
          '微应变',
          '轴向应力',
          '弹性模量',
        ]);
      case 'gear_ratio':
        aliases.addAll(const [
          'gear ratio',
          'gear reduction',
          'gear speed',
          'gear torque',
          'target output rpm',
          'required gear teeth',
          'driven gear teeth',
          'driver gear teeth',
          'gear tooth count',
          '齿轮比',
          '传动比',
          '齿轮减速',
          '齿轮增速',
          '目标输出转速',
          '反推齿数',
          '所需齿数',
          '保留驱动齿数',
          '保留从动齿数',
        ]);
      case 'cylinder':
        aliases.addAll(const [
          'cylinder force',
          'pneumatic cylinder',
          'air cylinder force',
          'target cylinder force',
          'required air pressure',
          'required bore',
          '气缸推力',
          '气缸目标力',
          '目标推出力',
          '反推气压',
          '反推缸径',
          '所需气压',
          '所需缸径',
        ]);
      case 'force':
        aliases.addAll(const [
          'force mass acceleration',
          'newton second law',
          'target force',
          'required acceleration',
          'required mass',
          '力质量加速度',
          '牛顿第二定律',
          '目标力',
          '反推加速度',
          '反推质量',
          '所需加速度',
          '所需质量',
        ]);
      case 'pulley_ratio':
        aliases.addAll(const [
          'pulley ratio',
          'belt pulley speed',
          'target pulley speed',
          'target pulley output rpm',
          'required pulley diameter',
          'pulley diameter planning',
          '皮带轮转速比',
          '皮带轮目标转速',
          '目标输出转速',
          '反推轮径',
          '所需轮径',
        ]);
      case 'screw_lead':
        aliases.addAll(const [
          'screw lead',
          'lead screw feed',
          'target feed rate',
          'target linear speed',
          'required screw rpm',
          'required lead',
          '丝杆导程',
          '进给速度',
          '目标线速度',
          '反推转速',
          '反推导程',
          '所需转速',
          '所需导程',
        ]);
      case 'torque_power':
        aliases.addAll(const [
          'torque power',
          'torque horsepower',
          'power torque rpm',
          'target power torque',
          'required torque',
          'required rpm',
          'shaft power',
          'brake power',
          '扭矩功率',
          '扭矩功率换算',
          '目标功率',
          '反推扭矩',
          '反推转速',
          '所需扭矩',
          '所需转速',
          '轴功率',
          '制动功率',
        ]);
      case 'spring':
        aliases.addAll(const [
          'spring stiffness',
          'spring rate',
          'hooke law',
          'spring force',
          'spring energy',
          'target spring force',
          'target spring energy',
          'required spring travel',
          'spring compression',
          '弹簧刚度',
          '弹簧力',
          '胡克定律',
          '目标弹簧力',
          '目标储能',
          '反推弹簧变形',
          '所需变形量',
          '弹簧压缩量',
        ]);
      case 'section_area':
        aliases.addAll(const [
          'section area',
          'section properties',
          'section modulus',
          'area moment of inertia',
          'second moment',
          'moment of inertia',
          'section inertia',
          'radius of gyration',
          'gyration radius',
          'tube wall thickness',
          'hollow ratio',
          'strong axis',
          'weak axis',
          'ix',
          'iy',
          'zx',
          'zy',
          'circular section',
          'round section',
          'tube section',
          'hollow round',
          'rectangular section',
          'cm4',
          'cm^4',
          'mm4',
          'mm^4',
          'in4',
          'in^4',
          '截面属性',
          '截面积',
          '截面模量',
          '回转半径',
          '惯性半径',
          '管壁厚',
          '壁厚',
          '空心率',
          '强轴',
          '弱轴',
          '惯性矩',
          '圆截面',
          '管截面',
          '矩形截面',
        ]);
      case 'safety_factor':
        aliases.addAll(const [
          'safety factor',
          'factor of safety',
          'target safety factor',
          'required strength',
          'allowable working stress',
          'required allowable stress',
          'design margin',
          'allowable stress',
          'working stress',
          'strength margin',
          '安全系数',
          '目标安全系数',
          '所需强度',
          '许用应力',
          '应力降低',
          '安全裕量',
          '许用强度',
          '工作应力',
        ]);
    }
    aliases.addAll(_unitSearchAliases[tool.id] ?? const []);
    return aliases;
  }

  static const Map<String, List<String>> _unitSearchAliases = {
    'length': [
      'length converter',
      'distance converter',
      'meter centimeter millimeter micrometer nanometer',
      'megameter',
      'inch foot feet',
      'inches to cm',
      'feet to meter',
      'nm um megameter',
      '尺寸换算',
      '长度换算',
      '纳米',
      '微米',
      '兆米',
      '英寸',
      '英尺',
    ],
    'area': [
      'area converter',
      'square meter',
      'square centimeter',
      'square millimeter',
      'square foot',
      'square feet',
      'sq ft',
      'sqft',
      'ft2',
      'square kilometer',
      'hectare',
      'acre',
      'square yard',
      'yd2',
      '面积换算',
      '平方米',
      '平方公里',
      '公顷',
      '亩',
      '英亩',
      '平方英尺',
    ],
    'volume': [
      'volume converter',
      'liter milliliter',
      'litre millilitre',
      'cubic meter',
      'cubic feet',
      'cubic foot',
      'm3 l ml',
      'ft3',
      'cubic inch',
      'cubic yard',
      'gallon',
      'quart',
      'pint',
      'fluid ounce',
      'cup tablespoon teaspoon',
      'gal qt pt fl oz tbsp tsp',
      '体积换算',
      '容量换算',
      '升',
      '毫升',
      '立方英寸',
      '加仑',
      '夸脱',
      '品脱',
      '液盎司',
      '汤匙',
      '茶匙',
      '立方英尺',
    ],
    'mass': [
      'mass converter',
      'weight converter',
      'kilogram gram milligram',
      'megagram',
      'tonne',
      'metric ton',
      'pound',
      'pounds',
      'lb',
      'lbs',
      'mg megagram tonne',
      '重量换算',
      '质量换算',
      '公斤',
      '毫克',
      '兆克',
      '吨',
      '磅',
    ],
    'pressure': [
      'pressure converter',
      'pascal',
      'millipascal',
      'kilopascal',
      'megapascal',
      'gigapascal',
      'bar',
      'millibar',
      'psi',
      'mpa millipascal gpa mbar psi',
      '压力换算',
      '帕',
      '毫帕',
      '千帕',
      '兆帕',
      '吉帕',
      '毫巴',
    ],
    'speed': [
      'speed converter',
      'velocity converter',
      'kmh',
      'kph',
      'mph',
      'feet per second',
      'ft/s',
      'meter per minute',
      'm/min',
      'centimeter per second',
      'cm/s',
      'knots',
      'knot',
      '速度换算',
      '公里每小时',
      '英里每小时',
      '米每分钟',
      '厘米每秒',
      '节',
    ],
    'temperature': [
      'temperature converter',
      'celsius',
      'fahrenheit',
      'kelvin',
      'rankine',
      'degc',
      'degf',
      'degr',
      'c to f',
      'f to c',
      '温度换算',
      '摄氏度',
      '华氏度',
      '开尔文',
      '兰氏度',
    ],
    'voltage': [
      'voltage converter',
      'volt',
      'millivolt',
      'microvolt',
      'kilovolt',
      'megavolt',
      'v mv kv megavolt uv',
      '电压换算',
      '伏特',
      '毫伏',
      '千伏',
      '兆伏',
    ],
    'frequency': [
      'frequency converter',
      'hertz',
      'millihertz',
      'kilohertz',
      'megahertz',
      'gigahertz',
      'terahertz',
      'hz mhz khz megahertz ghz thz',
      '频率换算',
      '赫兹',
      '毫赫',
      '兆赫',
      '太赫兹',
    ],
    'time_unit': [
      'time converter',
      'duration converter',
      'nanosecond',
      'nanoseconds',
      'microsecond',
      'microseconds',
      'millisecond',
      'milliseconds',
      'ns',
      'us',
      'μs',
      'ms',
      'seconds minutes hours days',
      'sec min hr day week',
      'week',
      'weeks',
      'wk',
      '时间换算',
      '时长换算',
      '纳秒',
      '微秒',
      '毫秒',
      '分钟',
      '小时',
      '天',
      '周',
      '星期',
    ],
    'acceleration': [
      'acceleration converter',
      'gravity',
      'g force',
      'feet per second squared',
      'ft/s2',
      'm/s2',
      'cm/s2',
      'galileo',
      'gal',
      '加速度换算',
      '重力加速度',
      '伽',
    ],
    'force_unit': [
      'force converter',
      'newton',
      'millinewton',
      'kilonewton',
      'meganewton',
      'kgf',
      'lbf',
      'pound force',
      'mn kn meganewton',
      '力换算',
      '牛顿',
      '毫牛',
      '千牛',
      '兆牛',
      '磅力',
    ],
    'power_unit': [
      'power converter',
      'watt',
      'milliwatt',
      'kilowatt',
      'megawatt',
      'horsepower',
      'hp',
      'dbm',
      'dbw',
      '功率换算',
      '瓦特',
      '毫瓦',
      '千瓦',
      '兆瓦',
      '马力',
    ],
    'energy_unit': [
      'energy converter',
      'joule',
      'kilojoule',
      'calorie',
      'calories',
      'kilocalorie',
      'kcal',
      'btu',
      'british thermal unit',
      'electron volt',
      'electronvolt',
      'ev',
      'milliwatt hour',
      'watt hour',
      'kilowatt hour',
      'megawatt hour',
      'mwh',
      'wh',
      'kwh',
      '能量换算',
      '焦耳',
      '卡路里',
      '千卡',
      '英热单位',
      '电子伏特',
      '毫瓦时',
      '千瓦时',
      '兆瓦时',
      '度电',
    ],
    'angle_unit': [
      'angle converter',
      'degree',
      'radian',
      'turn',
      'grad',
      'gon',
      'arc minute',
      'arc second',
      'arcmin',
      'arcsec',
      'deg rad',
      '角度换算',
      '弧度',
      '角分',
      '角秒',
      '圈',
    ],
    'current_unit': [
      'current converter',
      'ampere',
      'amp',
      'milliamp',
      'microamp',
      'nanoamp',
      'nanoampere',
      'kiloamp',
      'kiloampere',
      'megaamp',
      'megaampere',
      'na',
      'ka',
      'a ma ua na kiloamp megaamp',
      '电流换算',
      '安培',
      '毫安',
      '微安',
      '纳安',
      '千安',
      '兆安',
    ],
    'resistance_unit': [
      'resistance converter',
      'ohm',
      'microohm',
      'micro ohm',
      'milliohm',
      'milli ohm',
      'kohm',
      'megohm',
      'gigaohm',
      'mΩ',
      'μΩ',
      'gΩ',
      'kilo ohm',
      'mega ohm',
      'giga ohm',
      '电阻换算',
      '欧姆',
      '微欧',
      '毫欧',
      '千欧',
      '兆欧',
      '吉欧',
    ],
    'capacitance_unit': [
      'capacitance converter',
      'farad',
      'millifarad',
      'microfarad',
      'nanofarad',
      'picofarad',
      'megafarad',
      'mf uf nf pf megafarad',
      '电容换算',
      '法拉',
      '毫法',
      '微法',
      '纳法',
      '皮法',
      '兆法',
    ],
    'inductance_unit': [
      'inductance converter',
      'henry',
      'kilohenry',
      'millihenry',
      'microhenry',
      'nanohenry',
      'picohenry',
      'megahenry',
      'kh mh uh nh ph megahenry',
      '电感换算',
      '亨利',
      '千亨',
      '毫亨',
      '微亨',
      '纳亨',
      '皮亨',
      '兆亨',
    ],
    'torque_unit': [
      'torque converter',
      'newton meter',
      'n m',
      'nm',
      'nmm',
      'n mm',
      'kn m',
      'knm',
      'millinewton meter',
      'mnm',
      'kgf m',
      'kgf cm',
      'lbf ft',
      'lbf in',
      'ozf in',
      'ounce force inch',
      'pound foot',
      'pound inch',
      '扭矩换算',
      '牛米',
      '千牛米',
      '毫牛米',
      '牛毫米',
      '磅英尺',
      '磅英寸',
    ],
    'flow_unit': [
      'flow converter',
      'flow rate',
      'liter per minute',
      'litre per minute',
      'liter per hour',
      'milliliter per minute',
      'cubic meter per hour',
      'cubic meter per minute',
      'cubic feet per minute',
      'cfm',
      'gpm',
      'gallon per minute',
      '流量换算',
      '升每分钟',
      '升每小时',
      '毫升每分钟',
      '立方米每小时',
      '立方米每分钟',
    ],
  };

  static const List<String> _generalSearchExamples = [
    '贷款',
    'json',
    'kΩ',
    '平方英尺',
    'word count',
    'theta-ja',
  ];

  static const Map<ToolCategory, List<String>> _searchExamplesByCategory = {
    ToolCategory.math: [
      '二次方程',
      '矩阵',
      '统计',
      'curve fitting',
      '比例',
      '三角形',
    ],
    ToolCategory.electronics: [
      '欧姆',
      '分压',
      'rc filter',
      'dBm',
      'theta-ja',
      '电池续航',
    ],
    ToolCategory.mechanical: [
      '扭矩',
      'beam deflection',
      'section modulus',
      '安全系数',
      '流量',
      '弹簧',
    ],
    ToolCategory.finance: [
      '贷款',
      '复利',
      'ROI',
      '折扣',
      'NPV',
      '电费',
    ],
    ToolCategory.science: [
      '自由落体',
      'ideal gas',
      'half life',
      'pH',
      '热量',
      '波长',
    ],
    ToolCategory.units: [
      'kΩ',
      '平方英尺',
      'cubic feet',
      'MWh',
      'psi',
      'uF',
    ],
    ToolCategory.programming: [
      'json',
      'jwt token',
      'url params',
      'base64',
      'regex',
      'timestamp',
    ],
    ToolCategory.custom: [
      '公式',
      '工作流',
      '自定义',
      '参数',
      '模板',
      '计算',
    ],
  };

  _TokenMatch? _tokenMatch(ToolDefinition tool, Iterable<String> queries) {
    final fields = [
      tool.title,
      tool.description,
      tool.formula,
      tool.explanation,
      tool.group,
      tool.category.title,
      tool.category.subtitle,
      tool.id,
      ..._searchAliases(tool),
      ...tool.inputs.expand((input) => [input.label, input.unit, input.key]),
    ];
    final haystack = fields.expand(_searchTextVariants).join(' ');
    _TokenMatch? best;
    for (final query in queries) {
      final tokens = query
          .split(RegExp(r'[\s_+\-/,]+'))
          .where((token) => token.length >= 2)
          .toSet()
          .toList();
      if (tokens.length < 2) continue;
      final matched = tokens.where(haystack.contains).length;
      if (matched < tokens.length) continue;
      final score = (44 + matched * 4).clamp(0, 70);
      final text = _bestTokenMatchText(fields, tokens, fallback: query);
      if (best == null || score > best.score) {
        best = _TokenMatch(score: score, text: text);
      }
    }
    return best;
  }

  String _bestTokenMatchText(
    List<String> fields,
    List<String> tokens, {
    required String fallback,
  }) {
    for (final field in fields) {
      final variants = _searchTextVariants(field).toList(growable: false);
      if (tokens
          .every((token) => variants.any((value) => value.contains(token)))) {
        return field;
      }
    }
    return fallback;
  }

  String _compactMatchText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 34) return normalized;
    return '${normalized.substring(0, 33)}…';
  }

  Iterable<String> _suggestionPhrases(ToolDefinition tool) sync* {
    final phrases = <String>[
      tool.title,
      tool.id.replaceAll('_', ' '),
      tool.group,
      tool.category.title,
      ..._searchAliases(tool),
      ...tool.inputs.expand((input) => [input.label, input.key, input.unit]),
    ];
    final seen = <String>{};
    for (final phrase in phrases) {
      for (final segment in _suggestionSegments(phrase)) {
        if (segment.length < 2) continue;
        if (seen.add(_normalizeSearchText(segment))) yield segment;
      }
    }
  }

  Iterable<String> _suggestionSegments(String phrase) sync* {
    final normalized = phrase.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return;
    yield normalized;
    for (final segment in normalized.split(RegExp(r'[\s_+\-/,=()]+'))) {
      final trimmed = segment.trim();
      if (trimmed.isNotEmpty) yield trimmed;
    }
  }

  ToolSearchSuggestion? _rankSuggestion({
    required String phrase,
    required ToolDefinition tool,
    required List<String> queryVariants,
  }) {
    var bestScore = 0;
    for (final candidate in _searchTextVariants(phrase)) {
      if (candidate.length < 3) continue;
      for (final query in queryVariants) {
        final score = _suggestionScore(query: query, candidate: candidate);
        if (score > bestScore) bestScore = score;
      }
    }
    if (bestScore < _minimumSuggestionScore) return null;
    return ToolSearchSuggestion(
      text: phrase,
      tool: tool,
      score: bestScore + (tool.featured ? 2 : 0),
    );
  }

  int _suggestionScore({required String query, required String candidate}) {
    if (candidate == query) return 100;
    if (candidate.startsWith(query) || query.startsWith(candidate)) return 86;
    if (candidate.contains(query) || query.contains(candidate)) return 78;
    final distance = _levenshteinDistance(query, candidate);
    final maxLength =
        query.length > candidate.length ? query.length : candidate.length;
    if (maxLength == 0) return 0;
    final similarity = 1 - distance / maxLength;
    if (similarity >= 0.78) return 72;
    if (similarity >= 0.66 && query.length >= 5 && candidate.length >= 5) {
      return 62;
    }
    return 0;
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final substitutionCost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final insertion = current[j] + 1;
        final deletion = previous[j + 1] + 1;
        final substitution = previous[j] + substitutionCost;
        current[j + 1] = [
          insertion,
          deletion,
          substitution,
        ].reduce((left, right) => left < right ? left : right);
      }
      previous = current;
    }
    return previous.last;
  }

  Iterable<String> _searchTextVariants(String value) {
    final normalized = _normalizeSearchText(value);
    if (normalized.isEmpty) return const [];

    final asciiUnit = normalized
        .replaceAll('平方', ' square ')
        .replaceAll('立方', ' cubic ')
        .replaceAll('²', '2')
        .replaceAll('³', '3')
        .replaceAll('⁴', '4')
        .replaceAll('^2', '2')
        .replaceAll('^3', '3')
        .replaceAll('^4', '4')
        .replaceAll('°c', 'degc')
        .replaceAll('℃', 'degc')
        .replaceAll('°f', 'degf')
        .replaceAll('℉', 'degf')
        .replaceAll('°r', 'degr')
        .replaceAll('μ', 'u')
        .replaceAll('µ', 'u')
        .replaceAll('Ω', 'ohm')
        .replaceAll('ω', 'ohm')
        .replaceAll('欧姆', 'ohm')
        .replaceAll('·', '*');
    final compactUnit = asciiUnit.replaceAll(RegExp(r'[\s*/.·-]+'), '');
    final noPunctuation = asciiUnit.replaceAll(RegExp(r'[_+\-/,]+'), ' ');
    return {
      normalized,
      asciiUnit,
      compactUnit,
      noPunctuation.replaceAll(RegExp(r'\s+'), ' ').trim(),
    };
  }

  String _normalizeSearchText(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('　', ' ')
        .replaceAll('／', '/')
        .replaceAll('＊', '*')
        .replaceAll('×', '*');
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }
}

const int _minimumSuggestionScore = 62;
const int _strongSuggestionScore = 78;

class ToolsState {
  const ToolsState({
    required this.favoriteIds,
    required this.recentIds,
  });

  final Set<String> favoriteIds;
  final List<String> recentIds;
}

class ToolSearchResult {
  const ToolSearchResult({
    required this.tool,
    required this.matchLabel,
    required this.matchText,
    required this.score,
  });

  final ToolDefinition tool;
  final String matchLabel;
  final String matchText;
  final int score;
}

class ToolSearchSuggestion {
  const ToolSearchSuggestion({
    required this.text,
    required this.tool,
    required this.score,
  });

  final String text;
  final ToolDefinition tool;
  final int score;
}

class _TokenMatch {
  const _TokenMatch({required this.score, required this.text});

  final int score;
  final String text;
}
