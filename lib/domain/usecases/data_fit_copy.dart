/// 中文：**拟合领域层那张文案表。** 拟合的结论（模型名、诊断行、粘贴摘要、拟合失败的报错）是在
///       `data_fit_models.dart` / `data_fit_diagnostics.dart` / `data_fit_fitting.dart` /
///       `data_fit_paste.dart` / `data_fit_parsing.dart` 里**拼出来的**，而那五个文件里没有
///       `BuildContext`，查不了语言。所以字搬到这里，由调用方**递进来**。
///
///       **为什么这一张表不在 `features/tools/presentation/` 里。** 该目录下每一张表
///       （`data_fit_strings.dart`、`tools_strings.dart`、`tool_catalog_strings.dart`…）都
///       `import 'package:flutter/widgets.dart'`，而 **`lib/domain/` 今天没有任何一行 import
///       指向 Flutter**——这是量出来的：`grep -rn "^import 'package:flutter" lib/domain/` 无输出
///       （**别用不锚定的 `grep -rn "package:flutter" lib/domain/`**：本段注释自己就写着那个包名，
///       不锚定的话它会稳定地印出这一行，看着像"领域层依赖 Flutter"），也是刻意维持的：
///       `app_settings.dart` 就在文件头写着「不依赖 Flutter，才能在纯 Dart 测试里跑」。
///       领域层 import 那张表 = **领域层第一次依赖 Flutter**，外加一次 `domain → features` 的反向分层，
///       两样都比"这张表住在领域层"更贵。所以**表跟着需要它的那一层走**，界面那侧只留一个入口
///       （`DataFitStrings.fit`）。
///
///       **本文件一个 import 都没有，是故意的。** 模型名不在表里做分派——那需要一个 `FitModel`
///       参数，就要 import `data_fit_models.dart`，而 `data_fit_models.dart` 反过来要用本文件
///       （`FitResult.summaryIn` / `FitResidualPoint.labelIn`），两边就成了循环 import。
///       于是**枚举到格子的映射写在枚举旁边**（`fitModelLabelIn`，`data_fit_models.dart`，一个穷尽
///       `switch`：加一个模型那里编译不过），本文件只装字。
///
///       **取值方式是必填参数，没有中文兜底。** `fitData` / `recommendFitModels` /
///       `buildFitDiagnostics` / `parseDataSeries` / `parseDataFitPasteText` 全部是
///       `{required DataFitCopy copy}`，`FitResult.summaryIn(copy)` 与
///       `FitResidualPoint.labelIn(copy)` 也都要传——与
///       `TextToolController.calculate({required TextToolStrings strings})` 同一条理由：
///       **漏传的后果是英文界面里蹦出一整屏中文长句，那在评审里几乎看不出来**，
///       所以宁可编译不过。选哪张表仍然只有一处：`DataFitStrings.forLanguage` 那个穷尽
///       `AppLanguage` 的 `switch`（加语言在那里编译不过）。
///
///       **没有 `@immutable`**：那个注解来自 Flutter / `package:meta`，而本文件刻意零 import。
///       类里全是 `final` 字段，不可变是构造方式保证的，不靠注解。
///
///       **留在源码里没搬进来的中文，是"输入文法"不是"给人看的字"**（逐条带理由的那张清单在
///       `test/domain/data_fit_copy_test.dart` 的护栏里）：`_isPastedFitDataMarker` 的
///       `'数据'` / `'原始数据'` / `'样本数据'` 判的是**用户粘贴进来的报告标题**，
///       `_isPastedFitSectionBoundary` 的 `'模型建议'` / `'诊断'` / `'疑似异常点'` / `'预测'` /
///       `'公式'` / `'结果'` / `'计算结果'` 判的是它的分节，`_isIndexHeader` 的 `'序号'` / `'行号'`
///       与 `_isUnitDescriptorLine` 的 `'单位'` / `'量纲'` 判的是**用户粘进来的表格表头**。
///       把它们翻了，粘贴中文报告与中文表格就再也读不懂了——与
///       `lib/features/graph/models/graph_strings.dart` 文件头对 `'图形数据'` / `'函数'` 那一批
///       写的是同一条理由。
///       模型名的**识别**也走同一类的路：三种拼法（本表的 `zh`、`en`、枚举名）都认，
///       所以中文界面下复制出来的报告在英文界面下照样解析得出模型。
/// English: **the fit domain layer's copy table.** A fit's conclusions (model names, diagnostic
///          lines, the paste summary, and fit failures) are **composed** inside
///          `data_fit_models.dart` / `data_fit_diagnostics.dart` / `data_fit_fitting.dart` /
///          `data_fit_paste.dart` / `data_fit_parsing.dart`, and those five files hold no
///          `BuildContext` and cannot look a language up. So the words live here and the caller
///          **hands them in**.
///
///          **Why this table is not under `features/tools/presentation/`.** Every table in that
///          directory (`data_fit_strings.dart`, `tools_strings.dart`, `tool_catalog_strings.dart`, …)
///          imports `package:flutter/widgets.dart`, while **not one import line under
///          `lib/domain/` names Flutter today** — that is measured:
///          `grep -rn "^import 'package:flutter" lib/domain/` prints nothing (**do not use the
///          unanchored `grep -rn "package:flutter" lib/domain/`**: this very comment spells the package
///          name, so unanchored it prints this line forever and reads like "the domain depends on
///          Flutter") and deliberately so: `app_settings.dart` says in its own head that it stays
///          Flutter-free so it can run in plain Dart tests. The domain importing that table would be
///          **the domain depending on Flutter for the first time**, plus a `domain → features`
///          inversion; both cost more than "the table lives one layer down". So **the table follows
///          the layer that needs it**, and the interface side keeps a single entry point
///          (`DataFitStrings.fit`).
///
///          **This file has zero imports on purpose.** The model names are not dispatched here: that
///          would need a `FitModel` parameter, hence an import of `data_fit_models.dart` — which in
///          turn needs this file (`FitResult.summaryIn` / `FitResidualPoint.labelIn`), making the two
///          a cycle. So **the enum-to-slot mapping sits beside the enum** (`fitModelLabelIn` in
///          `data_fit_models.dart`, an exhaustive `switch`: adding a model breaks the build there),
///          and this file holds nothing but words.
///
///          **The table is a required argument, with no Chinese fallback.** `fitData` /
///          `recommendFitModels` / `buildFitDiagnostics` / `parseDataSeries` /
///          `parseDataFitPasteText` all take `{required DataFitCopy copy}`, and so do
///          `FitResult.summaryIn(copy)` and `FitResidualPoint.labelIn(copy)` — the same reason as
///          `TextToolController.calculate({required TextToolStrings strings})`: **forgetting it puts
///          a screenful of Chinese sentences into an English interface, which is close to invisible
///          in review**, so the choice is a compile error. Picking the table still happens in exactly
///          one place: the exhaustive `AppLanguage` switch in `DataFitStrings.forLanguage` (adding a
///          language breaks the build there).
///
///          **No `@immutable`**: that annotation comes from Flutter / `package:meta` and this file is
///          deliberately import-free. Every field is `final`; immutability is guaranteed by
///          construction rather than by an annotation.
///
///          **The Chinese left in the source is input grammar, not copy** (the per-entry list with
///          reasons lives in the guard in `test/domain/data_fit_copy_test.dart`):
///          `_isPastedFitDataMarker`'s `'数据'` / `'原始数据'` / `'样本数据'` compares against the
///          **report heading the user pasted**, `_isPastedFitSectionBoundary`'s `'模型建议'` /
///          `'诊断'` / `'疑似异常点'` / `'预测'` / `'公式'` / `'结果'` / `'计算结果'` against its
///          sections, and `_isIndexHeader`'s `'序号'` / `'行号'` plus `_isUnitDescriptorLine`'s
///          `'单位'` / `'量纲'` against the **header of a table the user pasted**. Translating them
///          means pasting a Chinese report or a Chinese table stops being understood — the same
///          reason `lib/features/graph/models/graph_strings.dart`'s head gives for `'图形数据'` /
///          `'函数'`. Model-name
///          **recognition** travels the same road: all three spellings (this table's `zh`, its `en`,
///          and the enum name) are accepted, so a report copied under the Chinese interface still
///          resolves its model under the English one.
library;

/// 中文：一个 `DataFitCopy` 装的是**一种语言**下、拟合领域层拼出来的所有字。
/// English: one `DataFitCopy` holds every word the fit domain layer composes, in **one language**.
class DataFitCopy {
  const DataFitCopy({
    // —— 模型名（`FitModel.label` 那六条搬进来的）——
    required this.modelLinear,
    required this.modelQuadratic,
    required this.modelExponential,
    required this.modelPower,
    required this.modelLogarithmic,
    required this.modelReciprocal,
    // —— 结论标题与残差行 ——
    required this.fitOf,
    required this.residualRow,
    // —— 诊断行 ——
    required this.fitQualityVeryHigh,
    required this.fitQualityGood,
    required this.fitQualityFair,
    required this.fitQualityLow,
    required this.rmseHigh,
    required this.rmseMedium,
    required this.rmseLow,
    required this.maxResidual,
    required this.residualRun,
    required this.edgeHeavyResidual,
    required this.outliers,
    // —— 粘贴摘要 ——
    required this.noRecognisedData,
    required this.fromReport,
    required this.fromDirectData,
    required this.seriesCount,
    required this.points,
    required this.predictionSummary,
    required this.modelSummary,
    // —— 解析时的兜底数据组名 ——
    required this.dataSeriesName,
    // —— 拟合失败的原因 ——
    required this.modelNeedsPoints,
    required this.xHasNoVariation,
    required this.exponentialNeedsPositiveY,
    required this.powerNeedsPositiveXY,
    required this.logarithmicNeedsPositiveX,
    required this.reciprocalNeedsNonZeroX,
    required this.noUniqueCurve,
  });

  // —— 模型名 ——
  final String modelLinear;
  final String modelQuadratic;
  final String modelExponential;
  final String modelPower;
  final String modelLogarithmic;
  final String modelReciprocal;

  // —— 结论标题与残差行 ——
  /// 中文：`'$label拟合'`——结论卡标题与 `FitResult.summaryIn` 的开头是同一句。
  /// English: `'$label fit'` — the conclusion card's heading and the head of
  ///          `FitResult.summaryIn` are the same phrase.
  final String Function(String label) fitOf;

  /// 中文：一行残差点。`rowNumber` 从 1 起数。
  /// English: one residual row. `rowNumber` counts from 1.
  final String Function(
    int rowNumber,
    String x,
    String y,
    String predicted,
    String residual,
  ) residualRow;

  // —— 诊断行 ——
  final String fitQualityVeryHigh;
  final String fitQualityGood;
  final String fitQualityFair;
  final String fitQualityLow;
  final String rmseHigh;
  final String rmseMedium;
  final String rmseLow;
  final String Function(int rowNumber, String x, String residual) maxResidual;
  final String residualRun;
  final String edgeHeavyResidual;

  /// 中文：异常点那一行。**分隔符也在表里**（中文用 `；`，英文用 `; `），
  ///       所以外面传进来的是若干条已经拼好的行，不是一条拼好的串。
  /// English: the outlier line. **The separator is in the table too** (`；` in Chinese, `; ` in
  ///          English), so the caller passes the already-composed rows, not one joined string.
  final String Function(List<String> labels) outliers;

  // —— 粘贴摘要 ——
  final String noRecognisedData;
  final String fromReport;
  final String fromDirectData;
  final String Function(int count) seriesCount;
  final String Function(int count) points;
  final String Function(String x) predictionSummary;
  final String Function(String label) modelSummary;

  // —— 解析时的兜底数据组名 ——
  /// 中文：没有表头也没有名字的那一组数据叫什么。`index` 从 1 起数。
  /// English: what a series with neither a header nor a name is called. `index` counts from 1.
  final String Function(int index) dataSeriesName;

  // —— 拟合失败的原因 ——
  final String Function(String label, int minPoints) modelNeedsPoints;
  final String xHasNoVariation;
  final String exponentialNeedsPositiveY;
  final String powerNeedsPositiveXY;
  final String logarithmicNeedsPositiveX;
  final String reciprocalNeedsNonZeroX;
  final String noUniqueCurve;

  /// 中文：中文那一侧。**默认态逐字节不变**指的就是这一张。
  /// English: the Chinese side. **The "default state stays byte-identical" rule** is about this one.
  static final DataFitCopy zh = DataFitCopy(
    modelLinear: '线性',
    modelQuadratic: '二次',
    modelExponential: '指数',
    modelPower: '幂函数',
    modelLogarithmic: '对数',
    modelReciprocal: '倒数',
    fitOf: (label) => '$label拟合',
    residualRow: (rowNumber, x, y, predicted, residual) =>
        '第 $rowNumber 行 x=$x, y=$y, ŷ=$predicted, 残差=$residual',
    fitQualityVeryHigh: '拟合度很高，R² 接近 1。',
    fitQualityGood: '拟合度较好，建议仍检查残差分布。',
    fitQualityFair: '拟合度一般，可能需要换模型或分段拟合。',
    fitQualityLow: '拟合度偏低，当前模型可能不适合这组数据。',
    rmseHigh: 'RMSE 相对波动较大，预测误差需要谨慎使用。',
    rmseMedium: 'RMSE 中等，适合粗略估算，不适合高精度外推。',
    rmseLow: 'RMSE 相对较小，样本范围内预测更稳定。',
    maxResidual: (rowNumber, x, residual) =>
        '最大残差出现在第 $rowNumber 行：x=$x, 残差=$residual。',
    residualRun: '残差连续同号较多，可能存在系统性偏差。',
    edgeHeavyResidual: '首尾残差偏大，外推时建议降低置信度。',
    outliers: (labels) => '疑似异常点：${labels.join('；')}。',
    noRecognisedData: '剪贴板里没有识别到可拟合数据',
    fromReport: '已从报告提取数据',
    fromDirectData: '已粘贴数据',
    seriesCount: (count) => '$count 组',
    points: (count) => '$count 点',
    predictionSummary: (x) => '预测 x=$x',
    modelSummary: (label) => '模型 $label',
    dataSeriesName: (index) => '数据 $index',
    modelNeedsPoints: (label, minPoints) => '$label拟合至少需要 $minPoints 个点',
    xHasNoVariation: 'x 数据没有变化，无法做线性拟合',
    exponentialNeedsPositiveY: '指数拟合要求 y 全部为正数',
    powerNeedsPositiveXY: '幂函数拟合要求 x 和 y 全部为正数',
    logarithmicNeedsPositiveX: '对数拟合要求 x 全部为正数',
    reciprocalNeedsNonZeroX: '倒数拟合要求 x 不能为 0',
    noUniqueCurve: '数据点无法确定唯一拟合曲线',
  );

  /// 中文：英文那一侧。
  /// English: the English side.
  static final DataFitCopy en = DataFitCopy(
    modelLinear: 'Linear',
    modelQuadratic: 'Quadratic',
    modelExponential: 'Exponential',
    modelPower: 'Power',
    modelLogarithmic: 'Logarithmic',
    modelReciprocal: 'Reciprocal',
    fitOf: (label) => '$label fit',
    residualRow: (rowNumber, x, y, predicted, residual) =>
        'Row $rowNumber x=$x, y=$y, ŷ=$predicted, residual=$residual',
    fitQualityVeryHigh: 'The fit is very good; R² is close to 1.',
    fitQualityGood:
        'The fit is good, but the residual spread is still worth a look.',
    fitQualityFair:
        'The fit is fair; another model or a piecewise fit may work better.',
    fitQualityLow: 'The fit is poor; this model may not suit this data.',
    rmseHigh:
        'The RMSE is large relative to the data, so use predictions with care.',
    rmseMedium:
        'The RMSE is moderate: fine for rough estimates, not for high-precision extrapolation.',
    rmseLow:
        'The RMSE is small, so predictions inside the sample range are steadier.',
    maxResidual: (rowNumber, x, residual) =>
        'The largest residual is in row $rowNumber: x=$x, residual=$residual.',
    residualRun:
        'Many residuals in a row share a sign, which may mean systematic bias.',
    edgeHeavyResidual:
        'The first and last residuals are large; lower the confidence when extrapolating.',
    outliers: (labels) => 'Suspected outliers: ${labels.join('; ')}.',
    noRecognisedData: 'No fittable data recognised in the clipboard',
    fromReport: 'Extracted data from a report',
    fromDirectData: 'Pasted data',
    seriesCount: (count) => '$count series',
    points: (count) => '$count points',
    predictionSummary: (x) => 'Prediction x=$x',
    modelSummary: (label) => 'Model $label',
    dataSeriesName: (index) => 'Data $index',
    modelNeedsPoints: (label, minPoints) =>
        '$label fit needs at least $minPoints points',
    xHasNoVariation: 'The x values do not vary, so a linear fit is impossible',
    exponentialNeedsPositiveY:
        'An exponential fit needs every y to be positive',
    powerNeedsPositiveXY: 'A power fit needs every x and y to be positive',
    logarithmicNeedsPositiveX: 'A logarithmic fit needs every x to be positive',
    reciprocalNeedsNonZeroX: 'A reciprocal fit cannot take x = 0',
    noUniqueCurve: 'These points do not determine a unique fit',
  );
}
