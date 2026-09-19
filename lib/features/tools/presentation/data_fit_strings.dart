import 'package:flutter/widgets.dart';

import '../../../domain/usecases/data_fit_copy.dart';
import '../../../l10n/app_language.dart';

/// 中文：数据拟合图表工具（`data_fit_tool_screen.dart` 及其两个 `part`）的界面文案表。
///       机制本身（为什么是手写分表而不是 ARB / `gen-l10n`、为什么表是 `static final` 而不是
///       `const`）与设置页那张表共用一套理由，写在 `settings_strings.dart` 的文件头上，这里不重抄。
///
///       **为什么拟合页要自己一张表**：工具首页 / 分类页 / 工具详情页 / 文本工具详情页共用
///       `ToolsStrings`，拟合页单独一张——拟合页是一整个独立屏幕，带上它自己的 `part` 文件，
///       七十二条文案；并进 `ToolsStrings` 会让那一个文件冲到八百行的硬线附近，
///       而按屏幕切开之后每张表一屏看得完，正是"按功能切分"的本来意思。
///
///       ⚠️ 这句话原先写的是「**工具子树有两张表而不是一张**」——**那个数字从 `bbd2d25` 起就不准了**
///       （工具名与分类名现在另有 `tool_catalog_strings.dart`，表数已不止两张）。
///       切分判据没变，只是不再拿一个会过期的数字去说它。
///
///       **本表只装"给人看的字"，而拟合的结论现在也是它这一侧的。** 拟合结论里的模型名与诊断行
///       （`FitModel` 的六个名字、`buildFitDiagnostics`、`FitResidualPoint.labelIn`、
///       `result.summaryIn`、粘贴摘要、拟合失败的报错）**本轮已经全部进表**——就是下面那一格
///       [`fit`]，它指向 `lib/domain/usecases/data_fit_copy.dart`。
///
///       ⚠️ 这里原先写着「那些字来自领域层，**这是已知的残留**，不是漏翻」。**那句话本轮不成立了**
///       （它曾经是真的：领域层没有 `BuildContext`，而当年那轮的范围只到界面这一侧）。
///       为什么残留的表**不在本文件里**而去了领域层，理由写在 `data_fit_copy.dart` 的文件头
///       （一句话：**`lib/domain/` 对 Flutter 的 import 数是 0**，本文件却 import Flutter）。
///       留这段是因为：**一个理由被推翻时该说一声**，免得下一页的读者以为这里从来没有残留过。
/// English: The string table for the data-fitting chart tool (`data_fit_tool_screen.dart` and its two
///          `part` files). The mechanism itself (why hand-written tables rather than ARB /
///          `gen-l10n`, why the tables are `static final` rather than `const`) shares one set of
///          reasons with the settings table and is written on `settings_strings.dart`'s file head;
///          it is not copied again here.
///
///          **Why the tools subtree has two tables rather than one**: `ToolsStrings` plus this one.
///          The tools home, category, tool detail and text tool detail screens share one; the fit
///          screen gets its own, because it is a whole screen with its own `part` files and seventy
///          strings of its own. Folding them into `ToolsStrings` would push that single file up
///          against the hard 800-line limit, while splitting by screen keeps each table readable in
///          one screen — which is what "split by feature" meant in the first place.
///
///          **This table holds human-facing text only — and a fit's conclusions are now on this side
///          too.** The model names and diagnostic lines inside a fit's conclusions (the six names of
///          `FitModel`, `buildFitDiagnostics`, `FitResidualPoint.labelIn`, `result.summaryIn`, the
///          paste summary, and fit failures) **all went into a table this round** — the [`fit`] cell
///          below, which points at `lib/domain/usecases/data_fit_copy.dart`.
///
///          ⚠️ This used to read "those words come from the domain layer — a **known remainder**, not
///          a missed translation". **That sentence is no longer true** (it once was: the domain holds
///          no `BuildContext`, and that round's scope stopped at the interface side). Why the
///          remainder's table is **not in this file** but in the domain is written at the head of
///          `data_fit_copy.dart` (in one line: **`lib/domain/` imports Flutter zero times**, and this
///          file does). The note is kept because **a reason that is overturned should say so**, so the
///          next reader does not think there was never a remainder here.
@immutable
class DataFitStrings {
  const DataFitStrings({
    // —— 页头 ——
    required this.back,
    required this.reset,
    // —— 输入校验 ——
    required this.needTwoRows,
    required this.needTwoRowsPanel,
    required this.invalidX,
    required this.needFitFirst,
    required this.noPrediction,
    // —— 输入卡片 ——
    required this.dataAndModel,
    required this.sampleData,
    required this.clearData,
    required this.paste,
    required this.fitSeries,
    required this.seriesPoints,
    required this.dataList,
    required this.dataListHint,
    required this.notParsedYet,
    required this.parsedSeries,
    required this.currentSeries,
    // —— 结果卡片 ——
    required this.alreadyBestModel,
    required this.tryRecommended,
    required this.pointCount,
    required this.seriesLabel,
    // —— 领域层那几张表（结论摘要、诊断行、模型名、粘贴摘要、拟合失败）——
    required this.fit,
    required this.copyEquation,
    required this.copyResidual,
    // —— 预测卡片 ——
    required this.prediction,
    required this.predictX,
    required this.predictXHint,
    required this.clearPrediction,
    required this.predictionReading,
    required this.predictionHint,
    required this.extrapolationWarning,
    // —— 模型建议与异常点 ——
    required this.modelAdvice,
    required this.applyBest,
    required this.residualAlerts,
    required this.modelUnavailable,
    required this.unavailable,
    // —— 图表与数据表 ——
    required this.chart,
    required this.legendFitSuffix,
    required this.dataTable,
    required this.seriesRows,
    required this.residual,
    // —— 底部动作区 ——
    required this.copy,
    required this.save,
    required this.note,
    required this.exportCsv,
    required this.saveChart,
    required this.csvExported,
    required this.csvExportCancelled,
    required this.csvExportFailed,
    required this.chartSaved,
    required this.chartSaveCancelled,
    required this.chartSaveFailed,
    required this.equationCopied,
    required this.residualCopied,
    required this.predictionCopied,
    required this.resultCopied,
    // —— 示例数据菜单 ——
    required this.sampleMultiColumn,
    required this.sampleMultiColumnNote,
    required this.sampleHeader,
    required this.sampleHeaderNote,
    required this.sampleLocalized,
    required this.sampleLocalizedNote,
    // —— 复制 / 落库的正文（不是屏幕上的字，但同样是给人看的）——
    required this.noFitResult,
    required this.copySeries,
    required this.copyModelAdvice,
    required this.copyDiagnostics,
    required this.copyResidualHeading,
    required this.copyData,
    required this.copyPrediction,
    required this.historyExpression,
  });

  // —— 页头 ——
  final String back;
  final String reset;
  // —— 输入校验 ——
  final String needTwoRows;
  final String needTwoRowsPanel;
  final String invalidX;
  final String needFitFirst;
  final String noPrediction;
  // —— 输入卡片 ——
  final String dataAndModel;
  final String sampleData;
  final String clearData;
  final String paste;
  final String fitSeries;
  final String Function(String name, int count) seriesPoints;
  final String dataList;
  final String dataListHint;
  final String notParsedYet;
  final String Function(int count) parsedSeries;
  final String Function(String name, int count) currentSeries;
  // —— 结果卡片 ——
  final String alreadyBestModel;
  final String Function(String label) tryRecommended;
  final String pointCount;
  final String seriesLabel;

  /// 中文：**拟合领域层要的那张表**（`lib/domain/usecases/data_fit_copy.dart`）。领域层没有
  ///       `BuildContext`，也不许 import Flutter（那张表是零 import 的纯 Dart），所以表跟着
  ///       需要它的那一层走，界面这边只留这一个入口。**它跟着下面那个穷尽 `AppLanguage` 的
  ///       `switch` 一起选**——加一门语言，这里编译不过。
  ///       拟合的模型名、诊断行、粘贴摘要与结论正文都从它取，不再和本表的格子重复：
  ///       `fitOf` 与 `points` 两条**本轮从这里搬了进去**（屏幕改叫 `strings.fit.fitOf(...)` /
  ///       `strings.fit.points(...)`），因为领域层拼结论时用的是同一句话，两处各留一份必然漂移。
  /// English: **the table the fit domain layer needs** (`lib/domain/usecases/data_fit_copy.dart`). The
  ///          domain has no `BuildContext` and may not import Flutter (that table has zero imports and
  ///          is plain Dart), so the table follows the layer that needs it and the interface side keeps
  ///          this one entry point. **It is chosen together with the exhaustive `AppLanguage` switch
  ///          below** — adding a language breaks the build here. The fit's model names, diagnostic
  ///          lines, paste summary and conclusion body come from it and are no longer duplicated as
  ///          cells of this table: **`fitOf` and `points` moved into it this round** (the screen now
  ///          calls `strings.fit.fitOf(...)` / `strings.fit.points(...)`), because the domain composes
  ///          the same sentence and two copies of it would necessarily drift.
  final DataFitCopy fit;
  final String copyEquation;
  final String copyResidual;
  // —— 预测卡片 ——
  final String prediction;
  final String predictX;
  final String predictXHint;
  final String clearPrediction;
  final String Function(String x, String y) predictionReading;
  final String predictionHint;
  final String extrapolationWarning;
  // —— 模型建议与异常点 ——
  final String modelAdvice;
  final String applyBest;
  final String residualAlerts;
  final String Function(String label) modelUnavailable;
  final String unavailable;
  // —— 图表与数据表 ——
  final String chart;
  final String legendFitSuffix;
  final String dataTable;
  final String Function(int count) seriesRows;
  final String residual;
  // —— 底部动作区 ——
  final String copy;
  final String save;
  final String note;
  final String exportCsv;
  final String saveChart;
  final String csvExported;
  final String csvExportCancelled;
  final String Function(String error) csvExportFailed;
  final String chartSaved;
  final String chartSaveCancelled;
  final String Function(String error) chartSaveFailed;
  final String equationCopied;
  final String residualCopied;
  final String predictionCopied;
  final String resultCopied;
  // —— 示例数据菜单 ——
  final String sampleMultiColumn;
  final String sampleMultiColumnNote;
  final String sampleHeader;
  final String sampleHeaderNote;
  final String sampleLocalized;
  final String sampleLocalizedNote;
  // —— 复制 / 落库的正文 ——
  final String noFitResult;
  final String Function(String name) copySeries;
  final String copyModelAdvice;
  final String copyDiagnostics;
  final String copyResidualHeading;
  final String copyData;
  final String Function(String x, String y) copyPrediction;
  final String Function(String label, String data) historyExpression;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过，
  ///       而不是静默回落到中文。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here rather than silently falling back to Chinese.
  static DataFitStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。两条路径共用这一个
  ///       switch，不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext`. Both routes share this
  ///          one switch, so they cannot drift apart.
  static DataFitStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => dataFitZh,
      AppLanguage.en => dataFitEn,
    };
  }

  static final DataFitStrings dataFitZh = DataFitStrings(
    back: '返回',
    reset: '重置',
    needTwoRows: '请输入至少两行有效数据',
    needTwoRowsPanel: '请输入至少两行有效数据。',
    invalidX: '请输入一个 x 数值',
    needFitFirst: '请先得到有效拟合结果',
    noPrediction: '当前模型在这个 x 上无有效预测',
    dataAndModel: '数据与模型',
    sampleData: '示例数据',
    clearData: '清空数据',
    paste: '粘贴',
    fitSeries: '拟合数据组',
    seriesPoints: (name, count) => '$name · $count 点',
    dataList: '数据列表',
    dataListHint: '支持 x,y；x,y1,y2 多列；空行分隔多组。\n例如：\n1, 2.1, 1.2\n2, 3.9, 1.8\n\n1, 8\n2, 13',
    notParsedYet: '尚未解析到有效数据',
    parsedSeries: (count) => '已解析 $count 组',
    currentSeries: (name, count) => '当前 $name $count 点',
    alreadyBestModel: '当前模型已是推荐模型',
    tryRecommended: (label) => '推荐尝试 $label',
    pointCount: '点数',
    seriesLabel: '数据组',
    fit: DataFitCopy.zh,
    copyEquation: '复制方程',
    copyResidual: '复制异常点',
    prediction: '预测',
    predictX: '预测 x',
    predictXHint: '例如 7、2.5、５０％',
    clearPrediction: '清空预测',
    predictionReading: (x, y) => 'x=$x 时，y=$y',
    predictionHint: '输入 x 后实时计算预测值',
    extrapolationWarning: '该 x 超出样本范围，属于外推估算。',
    modelAdvice: '模型建议',
    applyBest: '应用最佳',
    residualAlerts: '疑似异常点',
    modelUnavailable: (label) => '$label不可用',
    unavailable: '不可用',
    chart: '图表',
    legendFitSuffix: ' 拟合',
    dataTable: '数据表',
    seriesRows: (count) => '当前组 $count 行',
    residual: '残差',
    copy: '复制',
    save: '保存',
    note: '笔记',
    exportCsv: '导出 CSV',
    saveChart: '保存图表',
    csvExported: '拟合数据已导出为 CSV',
    csvExportCancelled: '已取消导出 CSV',
    csvExportFailed: (error) => '导出 CSV 失败：$error',
    chartSaved: '拟合图表已保存为 PNG',
    chartSaveCancelled: '已取消保存图表',
    chartSaveFailed: (error) => '保存图表失败：$error',
    equationCopied: '已复制方程',
    residualCopied: '已复制异常点',
    predictionCopied: '已复制预测',
    resultCopied: '已复制结果',
    sampleMultiColumn: '多列示例',
    sampleMultiColumnNote: '一列 x，多列 y，适合对比多组数据',
    sampleHeader: '表头示例',
    sampleHeaderNote: '兼容从表格粘贴的 x,y1,y2 表头',
    sampleLocalized: '本地化数字示例',
    sampleLocalizedNote: '全角数字、百分号会自动规范化',
    noFitResult: '无有效拟合结果',
    copySeries: (name) => '数据组: $name',
    copyModelAdvice: '模型建议:',
    copyDiagnostics: '诊断:',
    copyResidualHeading: '疑似异常点:',
    copyData: '数据:',
    copyPrediction: (x, y) => '预测: x=$x, y=$y',
    historyExpression: (label, data) => '$label拟合: $data',
  );

  static final DataFitStrings dataFitEn = DataFitStrings(
    back: 'Back',
    reset: 'Reset',
    needTwoRows: 'Enter at least two valid rows of data',
    needTwoRowsPanel: 'Enter at least two valid rows of data.',
    invalidX: 'Enter a numeric x',
    needFitFirst: 'A valid fit is needed first',
    noPrediction: 'The current model has no valid prediction at this x',
    dataAndModel: 'Data and model',
    sampleData: 'Sample data',
    clearData: 'Clear data',
    paste: 'Paste',
    fitSeries: 'Series to fit',
    seriesPoints: (name, count) => '$name · $count points',
    dataList: 'Data list',
    dataListHint:
        'Accepts x,y; several y columns (x,y1,y2); a blank line separates series.\n'
        'For example:\n1, 2.1, 1.2\n2, 3.9, 1.8\n\n1, 8\n2, 13',
    notParsedYet: 'No valid data parsed yet',
    parsedSeries: (count) => 'Parsed $count series',
    currentSeries: (name, count) => 'Current $name, $count points',
    alreadyBestModel: 'The current model is already the recommended one',
    tryRecommended: (label) => 'Try $label',
    pointCount: 'Points',
    seriesLabel: 'Series',
    fit: DataFitCopy.en,
    copyEquation: 'Copy equation',
    copyResidual: 'Copy outliers',
    prediction: 'Prediction',
    predictX: 'Prediction x',
    predictXHint: 'e.g. 7, 2.5, 50%',
    clearPrediction: 'Clear prediction',
    predictionReading: (x, y) => 'at x=$x, y=$y',
    predictionHint: 'Enter an x to get a prediction as you type',
    extrapolationWarning:
        'This x lies outside the sample range, so this is an extrapolation.',
    modelAdvice: 'Model advice',
    applyBest: 'Apply the best one',
    residualAlerts: 'Suspected outliers',
    modelUnavailable: (label) => '$label unavailable',
    unavailable: 'unavailable',
    chart: 'Chart',
    legendFitSuffix: ' fit',
    dataTable: 'Data table',
    seriesRows: (count) => 'Current series: $count rows',
    residual: 'Residual',
    copy: 'Copy',
    save: 'Save',
    note: 'Note',
    exportCsv: 'Export CSV',
    saveChart: 'Save chart',
    csvExported: 'Fit data exported as CSV',
    csvExportCancelled: 'CSV export cancelled',
    csvExportFailed: (error) => 'CSV export failed: $error',
    chartSaved: 'Fit chart saved as PNG',
    chartSaveCancelled: 'Chart save cancelled',
    chartSaveFailed: (error) => 'Chart save failed: $error',
    equationCopied: 'Equation copied',
    residualCopied: 'Outliers copied',
    predictionCopied: 'Prediction copied',
    resultCopied: 'Result copied',
    sampleMultiColumn: 'Multi-column sample',
    sampleMultiColumnNote:
        'One x column and several y columns, for comparing several datasets',
    sampleHeader: 'Header sample',
    sampleHeaderNote: 'Accepts the x,y1,y2 header pasted from a spreadsheet',
    sampleLocalized: 'Localised-number sample',
    sampleLocalizedNote:
        'Full-width digits and percent signs are normalised automatically',
    noFitResult: 'No valid fit result',
    copySeries: (name) => 'Series: $name',
    copyModelAdvice: 'Model advice:',
    copyDiagnostics: 'Diagnostics:',
    copyResidualHeading: 'Suspected outliers:',
    copyData: 'Data:',
    copyPrediction: (x, y) => 'Prediction: x=$x, y=$y',
    historyExpression: (label, data) => '$label fit: $data',
  );
}
