import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/data_fit.dart';

import '../shared/source_scan.dart';

/// 中文：**拟合领域层那条源码护栏，加上那张表本身的四条判据。**
///
///       **它为什么存在。** 在此之前，两条源码护栏（`tools_source_guard_test.dart` /
///       `text_tool_source_guard_test.dart`）扫的都是**界面子树**，而拟合的字住在
///       `lib/domain/usecases/` ——**那条路谁都没扫过**。本轮把这些字搬进表之后，
///       缺一条护栏，下一个人往五个文件里再写一句中文没有任何东西会拦住他。
///
///       **它扫的是"这一族"，不是一张写死的名单。** 目录里全部 `data_fit*.dart`（递归到该目录一层），
///       所以这一族将来多一个文件也自动在范围内。**唯一跳过的是表自己**
///       （`data_fit_copy.dart`——汉字该住的地方）。**跳过的是表，不是"某个界面文件"**：
///       与另外那两条护栏同一条规矩。
///
///       **豁免的每一条都是"输入文法"**，逐条带理由写在下面。它们的共同形状是：
///       拿**用户粘进来的文本 / 表头 / 报告标题**去比，翻了它就再也读不懂中文输入——
///       与 `graph_workspace_strings.dart` 文件头对 `'图形数据'` / `'函数'` 写的是同一条理由。
///       **别把界面文案加进这个表**：入选条件是上面这些理由，不是方便。
/// English: **the fit domain layer's source guard, plus four criteria on the table itself.**
///
///          **Why it exists.** Until now both source guards (`tools_source_guard_test.dart` /
///          `text_tool_source_guard_test.dart`) swept the **interface subtrees**, while the fit's words
///          lived in `lib/domain/usecases/` — **nothing swept that road**. Now that this round moved
///          those words into a table, a missing guard would let the next person write another Chinese
///          sentence into those five files with nothing to stop them.
///
///          **It sweeps "the family", not a hard-coded list.** Every `data_fit*.dart` in the directory
///          (recursing one level), so a sixth file in the family is in scope automatically. **The only
///          name skipped is the table itself** (`data_fit_copy.dart` — where the Chinese is supposed to
///          live). **A table is skipped, never "some interface file"**: the same rule the other two
///          guards follow.
///
///          **Every exemption is input grammar**, each with its reason below. Their common shape is:
///          they compare against **the text a user pasted** — a table header, a report heading — and
///          translating one means Chinese input stops being understood. The same reason
///          `graph_workspace_strings.dart`'s head gives for `'图形数据'` / `'函数'`. **Do not add
///          interface copy to this set**: the reasons above qualify an entry, not convenience.
void main() {
  test('拟合领域层源码里除了文案表再没有中文字符串字面量', () {
    final directory = Directory('lib/domain/usecases');
    expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    final offenders = <String>[];
    // 中文：**数一数豁免表里哪些条真的被用到了。** 一条只会放行、永远不生效的豁免与一条界面文案
    //       一样危险：它让下一个读者以为"这里有一句中文是要留着的"，而源码里那句话早就不在了。
    //       `tools_field_strings_test.dart` 那边对"死条目"也是这条判据。
    // English: **count which exemption entries actually fire.** An entry that only permits and never
    //          matches is as dangerous as a line of interface copy: it tells the next reader "there is
    //          a Chinese string here to keep" while that string left the source long ago.
    //          `tool_field_strings_test.dart` holds the same criterion for dead entries.
    final used = <String>{};
    final notationOnly = <String>[];
    for (final entity in directory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('data_fit')) continue;
      // 中文：表自己就是汉字住的地方，跳过它。
      // English: the table is where the Chinese is supposed to live; skip it.
      if (name == 'data_fit_copy.dart') continue;
      final source = stripComments(entity.readAsStringSync());
      for (final literal in stringLiterals(source)) {
        if (!containsWideOrFullwidth(literal)) continue;
        if (_inputGrammarLiterals.contains(literal)) {
          used.add(literal);
          continue;
        }
        if (_isMultiplicationDotNotation(literal)) {
          notationOnly.add('${entity.path}: $literal');
          continue;
        }
        offenders.add('${entity.path}: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason: '这些字面量还没走 DataFitCopy：\n${offenders.join('\n')}');
    expect(_inputGrammarLiterals.difference(used), isEmpty,
        reason: '豁免表里这些条目一条都没用到，是死条目：'
            '\n${_inputGrammarLiterals.difference(used).join('\n')}');
    // 中文：**21 是本轮实测**：豁免表 21 条，五棵树上一共命中 21 条字面量，**没有一条是死的**；
    //       另有 **7 条**由乘号点那条规则挡住（3 个模型模板 + 3 条拟合出来的方程 + 摘要里那个 ` · `）。
    //       这些数会随中文措辞与新增文件一起动，所以它们的用处是"证明豁免表没有空转"，
    //       真正的判据是上面那两条 `expect`。
    // English: **21 is this round's measurement**: 21 entries in the exemption table, 21 literals hit
    //          across the five files, **not one of them dead**; a further **7** are stopped by the
    //          multiplication-dot rule (3 model templates + 3 fitted equations + the ` · ` in the paste
    //          summary). These numbers move with the Chinese wording and with new files, so their job is
    //          to prove the exemption table is not idling; the criteria are the two `expect`s above.
    expect(used.length, 21, reason: '豁免条目命中数变了（$used.length）：豁免表或源码动过');
    // 中文：**乘号点那条规则也不是空的**——它得真的挡住几条，否则应该连同规则一起删掉。
    // English: **the multiplication-dot rule is not empty either** — it has to be catching something,
    //          or the rule should go with it.
    expect(notationOnly, isNotEmpty,
        reason: '乘号点规则一条都没挡住：要么规则多余，要么记号已经换了写法');
  });

  test('拟合文案表：中文那一侧与搬家前源码里的字逐字节相同', () {
    // —— 模型名（原 `FitModel.label`）——
    expect(fitModelLabelIn(zh, FitModel.linear), '线性');
    expect(fitModelLabelIn(zh, FitModel.quadratic), '二次');
    expect(fitModelLabelIn(zh, FitModel.exponential), '指数');
    expect(fitModelLabelIn(zh, FitModel.power), '幂函数');
    expect(fitModelLabelIn(zh, FitModel.logarithmic), '对数');
    expect(fitModelLabelIn(zh, FitModel.reciprocal), '倒数');
    // —— 结论标题与残差行 ——
    expect(zh.fitOf('二次'), '二次拟合');
    expect(zh.residualRow(4, '4.000000', '50.000000', '4.000000', '46.000000'),
        '第 4 行 x=4.000000, y=50.000000, ŷ=4.000000, 残差=46.000000');
    // —— 诊断行（原 `buildFitDiagnostics` 里的十一句）——
    expect(zh.fitQualityVeryHigh, '拟合度很高，R² 接近 1。');
    expect(zh.fitQualityGood, '拟合度较好，建议仍检查残差分布。');
    expect(zh.fitQualityFair, '拟合度一般，可能需要换模型或分段拟合。');
    expect(zh.fitQualityLow, '拟合度偏低，当前模型可能不适合这组数据。');
    expect(zh.rmseHigh, 'RMSE 相对波动较大，预测误差需要谨慎使用。');
    expect(zh.rmseMedium, 'RMSE 中等，适合粗略估算，不适合高精度外推。');
    expect(zh.rmseLow, 'RMSE 相对较小，样本范围内预测更稳定。');
    expect(zh.maxResidual(4, '4.000000', '1.230000'),
        '最大残差出现在第 4 行：x=4.000000, 残差=1.230000。');
    expect(zh.residualRun, '残差连续同号较多，可能存在系统性偏差。');
    expect(zh.edgeHeavyResidual, '首尾残差偏大，外推时建议降低置信度。');
    expect(zh.outliers(['甲', '乙']), '疑似异常点：甲；乙。');
    // —— 粘贴摘要（原 `DataFitPasteResult.summary`）——
    expect(zh.noRecognisedData, '剪贴板里没有识别到可拟合数据');
    expect(zh.fromReport, '已从报告提取数据');
    expect(zh.fromDirectData, '已粘贴数据');
    expect(zh.seriesCount(2), '2 组');
    expect(zh.points(3), '3 点');
    expect(zh.predictionSummary('7'), '预测 x=7');
    expect(zh.modelSummary('二次'), '模型 二次');
    // —— 兜底数据组名（原 `data_fit_parsing.dart` 里的 `'数据 N'`）——
    expect(zh.dataSeriesName(1), '数据 1');
    // —— 拟合失败的原因（原 `data_fit_fitting.dart` 里那七句）——
    expect(zh.modelNeedsPoints('二次', 3), '二次拟合至少需要 3 个点');
    expect(zh.xHasNoVariation, 'x 数据没有变化，无法做线性拟合');
    expect(zh.exponentialNeedsPositiveY, '指数拟合要求 y 全部为正数');
    expect(zh.powerNeedsPositiveXY, '幂函数拟合要求 x 和 y 全部为正数');
    expect(zh.logarithmicNeedsPositiveX, '对数拟合要求 x 全部为正数');
    expect(zh.reciprocalNeedsNonZeroX, '倒数拟合要求 x 不能为 0');
    expect(zh.noUniqueCurve, '数据点无法确定唯一拟合曲线');
  });

  test('拟合文案表：两侧都不空、英文侧没有汉字、中文侧没有一格照抄', () {
    final pairs = <String, List<String>>{
      'linear': [fitModelLabelIn(zh, FitModel.linear), fitModelLabelIn(en, FitModel.linear)],
      'quadratic': [
        fitModelLabelIn(zh, FitModel.quadratic),
        fitModelLabelIn(en, FitModel.quadratic)
      ],
      'exponential': [
        fitModelLabelIn(zh, FitModel.exponential),
        fitModelLabelIn(en, FitModel.exponential)
      ],
      'power': [fitModelLabelIn(zh, FitModel.power), fitModelLabelIn(en, FitModel.power)],
      'logarithmic': [
        fitModelLabelIn(zh, FitModel.logarithmic),
        fitModelLabelIn(en, FitModel.logarithmic)
      ],
      'reciprocal': [
        fitModelLabelIn(zh, FitModel.reciprocal),
        fitModelLabelIn(en, FitModel.reciprocal)
      ],
      'fitOf': [zh.fitOf('L'), en.fitOf('L')],
      'residualRow': [
        zh.residualRow(1, 'x', 'y', 'p', 'r'),
        en.residualRow(1, 'x', 'y', 'p', 'r')
      ],
      'fitQualityVeryHigh': [zh.fitQualityVeryHigh, en.fitQualityVeryHigh],
      'fitQualityGood': [zh.fitQualityGood, en.fitQualityGood],
      'fitQualityFair': [zh.fitQualityFair, en.fitQualityFair],
      'fitQualityLow': [zh.fitQualityLow, en.fitQualityLow],
      'rmseHigh': [zh.rmseHigh, en.rmseHigh],
      'rmseMedium': [zh.rmseMedium, en.rmseMedium],
      'rmseLow': [zh.rmseLow, en.rmseLow],
      'maxResidual': [zh.maxResidual(1, 'x', 'r'), en.maxResidual(1, 'x', 'r')],
      'residualRun': [zh.residualRun, en.residualRun],
      'edgeHeavyResidual': [zh.edgeHeavyResidual, en.edgeHeavyResidual],
      'outliers': [zh.outliers(['a']), en.outliers(['a'])],
      'noRecognisedData': [zh.noRecognisedData, en.noRecognisedData],
      'fromReport': [zh.fromReport, en.fromReport],
      'fromDirectData': [zh.fromDirectData, en.fromDirectData],
      'seriesCount': [zh.seriesCount(2), en.seriesCount(2)],
      'points': [zh.points(3), en.points(3)],
      'predictionSummary': [zh.predictionSummary('7'), en.predictionSummary('7')],
      'modelSummary': [zh.modelSummary('L'), en.modelSummary('L')],
      'dataSeriesName': [zh.dataSeriesName(1), en.dataSeriesName(1)],
      'modelNeedsPoints': [
        zh.modelNeedsPoints('L', 3),
        en.modelNeedsPoints('L', 3)
      ],
      'xHasNoVariation': [zh.xHasNoVariation, en.xHasNoVariation],
      'exponentialNeedsPositiveY': [
        zh.exponentialNeedsPositiveY,
        en.exponentialNeedsPositiveY
      ],
      'powerNeedsPositiveXY': [zh.powerNeedsPositiveXY, en.powerNeedsPositiveXY],
      'logarithmicNeedsPositiveX': [
        zh.logarithmicNeedsPositiveX,
        en.logarithmicNeedsPositiveX
      ],
      'reciprocalNeedsNonZeroX': [
        zh.reciprocalNeedsNonZeroX,
        en.reciprocalNeedsNonZeroX
      ],
      'noUniqueCurve': [zh.noUniqueCurve, en.noUniqueCurve],
    };

    // 中文：中文侧不许有空串——空串在屏幕上是"这一格什么都没有"，最难发现的一类漏翻。
    // English: the Chinese side must hold no empty string either: on screen it renders as a blank
    //          cell, the hardest kind of missing copy to notice.
    for (final entry in pairs.entries) {
      expect(entry.value[0].trim(), isNotEmpty, reason: '${entry.key} 中文侧是空的');
    }
    for (final entry in pairs.entries) {
      expect(entry.value[1].trim(), isNotEmpty, reason: '${entry.key} 英文侧是空的');
      expect(_containsCjk(entry.value[1]), isFalse,
          reason: '${entry.key} 英文侧还有汉字：${entry.value[1]}');
      expect(entry.value[0], isNot(entry.value[1]),
          reason: '「${entry.value[0]}」在英文表里没换');
    }
  });

  test('拟合文案表：中文里每一段非 CJK 的字串都必须在英文里原样找得到', () {
    var checked = 0;
    final missing = <String>[];
    void walk(String kind, String source, String target) {
      for (final run in notationRuns(source)) {
        checked++;
        if (!target.contains(run)) {
          missing.add('$kind 「$run」\n    中文 $source\n    英文 $target');
        }
      }
    }

    walk('模型名', fitModelLabelIn(zh, FitModel.linear), fitModelLabelIn(en, FitModel.linear));
    walk('模型名', fitModelLabelIn(zh, FitModel.quadratic),
        fitModelLabelIn(en, FitModel.quadratic));
    walk('模型名', fitModelLabelIn(zh, FitModel.exponential),
        fitModelLabelIn(en, FitModel.exponential));
    walk('模型名', fitModelLabelIn(zh, FitModel.power), fitModelLabelIn(en, FitModel.power));
    walk('模型名', fitModelLabelIn(zh, FitModel.logarithmic),
        fitModelLabelIn(en, FitModel.logarithmic));
    walk('模型名', fitModelLabelIn(zh, FitModel.reciprocal),
        fitModelLabelIn(en, FitModel.reciprocal));
    walk('结论标题', zh.fitOf('Quadratic'), en.fitOf('Quadratic'));
    walk('残差行', zh.residualRow(4, '4.000000', '50.000000', '4.000000', '46.000000'),
        en.residualRow(4, '4.000000', '50.000000', '4.000000', '46.000000'));
    walk('拟合度很高', zh.fitQualityVeryHigh, en.fitQualityVeryHigh);
    walk('拟合度较好', zh.fitQualityGood, en.fitQualityGood);
    walk('拟合度一般', zh.fitQualityFair, en.fitQualityFair);
    walk('拟合度偏低', zh.fitQualityLow, en.fitQualityLow);
    walk('RMSE 高', zh.rmseHigh, en.rmseHigh);
    walk('RMSE 中', zh.rmseMedium, en.rmseMedium);
    walk('RMSE 低', zh.rmseLow, en.rmseLow);
    walk('最大残差', zh.maxResidual(4, '4.000000', '1.230000'),
        en.maxResidual(4, '4.000000', '1.230000'));
    walk('残差同号', zh.residualRun, en.residualRun);
    walk('首尾残差', zh.edgeHeavyResidual, en.edgeHeavyResidual);
    walk('异常点行', zh.outliers(['第 4 行 x=4.000000, 残差=46.000000']),
        en.outliers(['Row 4 x=4.000000, residual=46.000000']));
    walk('组数', zh.seriesCount(2), en.seriesCount(2));
    walk('点数', zh.points(3), en.points(3));
    walk('预测摘要', zh.predictionSummary('7'), en.predictionSummary('7'));
    walk('结论模型名', zh.modelSummary('Quadratic'), en.modelSummary('Quadratic'));
    walk('兜底组名', zh.dataSeriesName(1), en.dataSeriesName(1));
    walk('点数不足', zh.modelNeedsPoints('Quadratic', 3), en.modelNeedsPoints('Quadratic', 3));
    walk('x 无变化', zh.xHasNoVariation, en.xHasNoVariation);
    walk('指数要求正 y', zh.exponentialNeedsPositiveY, en.exponentialNeedsPositiveY);
    walk('幂函数要求正', zh.powerNeedsPositiveXY, en.powerNeedsPositiveXY);
    walk('对数要求正 x', zh.logarithmicNeedsPositiveX, en.logarithmicNeedsPositiveX);
    walk('倒数要求非零', zh.reciprocalNeedsNonZeroX, en.reciprocalNeedsNonZeroX);

    // 中文：**29 是本轮实测的记号段数**，量的是**出现处**（30 对渲染结果上跑出来的段）。
    //       纯中文的格子（`线性`、`数据 1`、`数据点无法确定唯一拟合曲线`）本来就没有记号段，
    //       量出来是 0，所以这个数只会来自带记号的那几条（`R² 接近 1。`、`RMSE …`、
    //       `x=4.000000,` 那一串、`x = 0`）。这个数会随中文措辞一起动，所以它只做"断言没空转"
    //       的证据，判据是上面那条 `contains`——与 `tool_field_strings_test.dart` 那边同一条规矩。
    // English: **29 is this round's measured run count**, counting **occurrence sites** (runs found
    //          across 30 rendered pairs). A purely Chinese cell (`线性`, `数据 1`,
    //          `数据点无法确定唯一拟合曲线`) has no notation run and measures 0, so the count can only
    //          come from the entries that carry notation (`R² 接近 1。`, `RMSE …`, the
    //          `x=4.000000,` run, `x = 0`). The number moves with the Chinese wording, so it only
    //          proves the walk ran; the criterion is the `contains` above — the same rule as
    //          `tool_field_strings_test.dart`.
    expect(checked, 29, reason: '记号段数变了（$checked）：中文改过，或者遍历没跑全');
    expect(missing, isEmpty, reason: '记号在英文里丢了：\n${missing.join('\n')}');
  });
}

/// 中文：**表本身的两张脸。** 只在这一处取，断言里不会各自 `DataFitCopy.zh` 一遍。
/// English: **the table's two faces.** Taken once here so no assertion repeats `DataFitCopy.zh`.
final DataFitCopy zh = DataFitCopy.zh;
final DataFitCopy en = DataFitCopy.en;

/// 中文：**输入文法，不是给人看的字**（判据与理由见本文件开头）。原文与源码里逐字节相同。
/// English: **input grammar, not copy** (criteria and reasons at the head of this file). Spelled
///          exactly as they stand in the source.
const Set<String> _inputGrammarLiterals = <String>{
  // 中文：粘贴报告的**标题**与**分节名**——`_isPastedFitDataMarker` / `_isPastedFitSectionBoundary`
  //       拿它们判"用户粘进来的这一段是不是数据块"。翻了就认不出中文报告。
  // English: the pasted report's **headings** and **section names** —
  //          `_isPastedFitDataMarker` / `_isPastedFitSectionBoundary` compare against them to decide
  //          whether the pasted block is a data section. Translating them means a Chinese report stops
  //          being recognised.
  '数据',
  '原始数据',
  '样本数据',
  '模型建议',
  '诊断',
  '疑似异常点',
  '预测',
  '公式',
  '结果',
  '计算结果',
  // 中文：粘贴表格的**表头**——`_isIndexHeader` / `_isUnitDescriptorLine` 判"这一列是不是序号、
  //       这一行是不是单位行"。同样是对着用户粘进来的文本比。
  // English: the pasted table's **headers** — `_isIndexHeader` / `_isUnitDescriptorLine` decide
  //          whether a column is an index and whether a row is a unit row. Again compared against the
  //          text the user pasted.
  '序号',
  '行号',
  '单位',
  '量纲',
  // 中文：**正则的形状**：`_isPastedFitDataMarker` / `_isPastedFitSectionBoundary` 去掉行尾的全角/
  //       半角冒号（`[:：]+$`），`_extractPastedFitPrediction` 认"预测 x=…"的三种写法
  //       （其中一种用英文单词 `prediction`，但**冒号仍是全角/半角都收**，所以它也含中文标点）。
  //       它们描述的是中文报告的写法，翻了就配不上。
  // English: the **regex shapes**: the `[:：]+$` strippers (the marker and the boundary read the
  //          trailing colon off a heading) and the three prediction patterns
  //          (`_extractPastedFitPrediction` accepts "预测 x=…" in three spellings — one of them spells
  //          the word `prediction` in English, but **its colon class still takes the full-width form**,
  //          so it too contains Chinese punctuation). They describe how a Chinese report is written;
  //          translated, they stop matching.
  r'[:：]+$',
  r'预测\s*[:：]\s*x\s*=\s*([^,，\s]+)',
  r'prediction\s*[:：]\s*x\s*=\s*([^,，\s]+)',
  r'预测\s*x\s*[:：=]\s*([^,，\s]+)',
  // 中文：**"名字=数值"那一行的形状**（`_namedNumbersFromLine`）：它认的是**用户粘进来的字段名**，
  //       所以字符类里明写着汉字与全角括号（`\u4e00-\u9fff` / `（）`），单位也写着 `°℃℉`。
  //       这是解析器的定义域，不是文案。
  // English: **the shape of a "name=value" line** (`_namedNumbersFromLine`): it matches **the field
  //          names a user pasted**, so its character class spells out Han and full-width brackets
  //          (`\u4e00-\u9fff` / `（）`) and carries `°℃℉` among the units. That is the parser's domain,
  //          not copy.
  '(?:^|[\\s,;|])([A-Za-z_\\u4e00-\\u9fff][A-Za-z0-9_\\u4e00-\\u9fff./%°℃℉()\\[\\]（）-]{0,48})\\s*[:=]\\s*(',
  // 中文：**全角括号折成半角**（`_normalizeDataFieldName`）：粘进来的字段名里可能出现 `（`，
  //       折成 `(` 之后才能与表头对齐。判的是输入，不是输出。
  // English: **folding full-width brackets to ASCII** (`_normalizeDataFieldName`): a pasted field name
  //          may carry `（`, and folding it to `(` is what lets it line up with a header. It judges the
  //          input, not the output.
  '（',
  '）',
};

/// 中文：**"整条字面量里的宽/全角字符只有乘号点 `·`"的，就不是文案。**
///
///       判据来自尺子自己的文件头：`·`（U+00B7）是因为**中文排版里它是标点**才被收进
///       "界面文案会用到的那套字"（`_typographicPunctuation`），而同一段注释也写明
///       `× ÷ − ° √ ∞` 那些**数学记号不收**——`·` 只是恰好两边都算。在拟合这一族里被判据捞出来的
///       `·` 全部是**乘号**：模型模板 `y = A·e^(Bx)`、拟合出来的 `y = 2.0·e^(0.5x)`、
///       以及摘要里那个分隔符 ` · `。**所以这一条规则量的是同一件事**：除了那个点，
///       整条字面量没有任何中文/全角字符，就不可能是句子。
///
///       **它不会放过文案**：句子只要有一个汉字（或一个全角标点）就不满足这条规则，
///       照旧进 offenders。这一条挡住的只是"纯 ASCII 加一个乘号点"。
/// English: **a literal whose only wide/fullwidth character is the multiplication dot `·` is not
///          copy.**
///
///          The criterion comes from the ruler's own head: `·` (U+00B7) is collected into "the set
///          interface copy is written with" because **it typesets as punctuation in Chinese**
///          (`_typographicPunctuation`), and that same paragraph says `× ÷ − ° √ ∞` — mathematical
///          signs — are **not** collected; `·` merely happens to count as both. Every `·` the guard
///          catches in the fit family is a **multiplication dot**: the model templates
///          (`y = A·e^(Bx)`), a fitted equation (`y = 2.0·e^(0.5x)`), and the ` · ` separator in the
///          paste summary. **So this rule measures the same thing**: with that dot aside, the literal
///          holds no Chinese or full-width character at all, so it cannot be a sentence.
///
///          **It cannot let copy through**: a sentence with a single Han character (or one full-width
///          punctuation mark) fails the rule and still lands in `offenders`. What it stops is exactly
///          "plain ASCII plus a multiplication dot".
bool _isMultiplicationDotNotation(String literal) {
  return !containsWideOrFullwidth(literal.replaceAll('·', ''));
}

/// 中文：与 `tools_strings_test.dart` 里那条同一条判据：英文侧不许出现汉字。
/// English: the same criterion as in `tools_strings_test.dart`: the English side holds no Han.
bool _containsCjk(String text) => RegExp(r'[一-鿿]').hasMatch(text);
