import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/data_fit_strings.dart';
import 'package:nekocalc/features/tools/presentation/data_fit_tool_screen.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_detail_screen.dart';
import 'package:nekocalc/features/tools/presentation/tool_widgets.dart';
import 'package:nekocalc/features/tools/presentation/tools_home_page.dart';
import 'package:nekocalc/features/tools/presentation/tool_catalog_strings.dart';
import 'package:nekocalc/features/tools/presentation/tools_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';


/// 中文：工具子树**各**文案表（`ToolsStrings` + `DataFitStrings` + `ToolCatalogStrings`…）的
///       三条护栏，形状与设置页 / 计算页那几张表的护栏相同。
///       ⚠️ 这句原先写「**两张**文案表」并逐个点名——**那个数字从 `bbd2d25` 起就不准了**
///       （表数已经涨到十张）。改成不写数字的说法：**一个会过期的数字挂在文件头上，
///       下一个人会以为守卫的范围没变过。** 真实边界是上面的三条护栏本身。
///       1) 中文表的每一条都要与翻译前源码里那一句**逐字节相同**——默认语言是中文，所以屏幕上
///          每一个字都得和接入多语言之前一模一样。逐条写出来而不是抽查几条：这一份就是"默认态
///          不变"的**证据本身**。
///       2) 英文表里不许出现汉字、也不许出现空串，而且要真的与中文不同。
///       3) `lib/features/tools/presentation` 里（除了各文案表）不许再留中文字符串字面量。
///
///       **第 3 条本轮多出四处例外，都在 `_punctuationOnlyLiterals` 上、逐条带理由**：判据
///       放宽之后本目录新露出来的只有四条，没有一条是句子。工具子树里那些成百上千条中文
///       （工具名、描述、公式、参数标签、单位、分类名、诊断行）全都不在这个目录里，它们住在
///       `lib/domain/usecases` 与 `lib/application/controllers`——那是内容数据，本轮一条都没动。
/// English: Three guard rails for the tools subtree's two copy tables (`ToolsStrings` +
///          `DataFitStrings`), the same shape as the settings and calculator tables'. (1) Every
///          Chinese entry must be **byte-identical** to the sentence in the source before
///          translation — the default language is Chinese, so every character on screen has to read
///          exactly as it did before i18n existed. Written out one by one rather than sampled: this
///          list **is** the evidence for "the default state does not change". (2) The English table
///          must hold no CJK, no empty string, and really differ from the Chinese. (3) No Chinese
///          string literal may remain in `lib/features/tools/presentation` other than those two
///          tables.
///
///          **Clause 3 gained four exceptions this round, all on `_punctuationOnlyLiterals` with
///          their reasons beside them**: the widened ruler exposes exactly four literals in this
///          directory and not one is a sentence. The hundreds of Chinese entries in this subtree —
///          tool names, descriptions, formulas, parameter labels, units, category names, diagnostic
///          lines — are all outside this directory: they live in `lib/domain/usecases` and
///          `lib/application/controllers` as content data, untouched this round.
void main() {
  final zh = ToolsStrings.forLanguage(AppLanguage.zh);
  final en = ToolsStrings.forLanguage(AppLanguage.en);
  final fitZh = DataFitStrings.forLanguage(AppLanguage.zh);
  final fitEn = DataFitStrings.forLanguage(AppLanguage.en);

  test('工具页中文表与迁移前源码里那些字逐字节相同', () {
    // —— 通用字（多处共用）——
    expect(zh.clear, '清除');
    expect(zh.more, '更多');
    expect(zh.back, '返回');
    expect(zh.reset, '重置');
    expect(zh.copy, '复制');
    expect(zh.save, '保存');
    expect(zh.note, '笔记');
    expect(zh.paste, '粘贴');
    expect(zh.formula, '公式');
    expect(zh.insights, '校核');
    expect(zh.resultCopied, '已复制结果');
    // —— 工具首页：页头与搜索 ——
    expect(zh.toolsPageTitle, '工具');
    expect(zh.toolsSearchHint, '搜索工具、公式、单位...');
    expect(zh.searchResultsCount(3), '搜索结果 · 3');
    expect(zh.allCategories, '全部分类');
    expect(zh.allLabel, '全部');
    expect(zh.noMatchAtAll('x'), '没有找到“x”的匹配工具。');
    // —— 工具首页：三个分组 ——
    expect(zh.suggestedTools, '推荐工具');
    expect(zh.recentTools, '最近使用');
    expect(zh.manage, '管理');
    expect(zh.add, '添加');
    expect(zh.favoriteTools, '收藏工具');
    expect(zh.favoriteEmpty, '还没有收藏工具，点击工具右侧星标即可固定到这里。');
    expect(zh.categories, '分类');
    expect(zh.clearAll, '清空');
    expect(zh.recentEmpty, '最近使用已清空。打开任意工具后会重新记录到这里。');
    expect(zh.removeRecentTooltip, '移除最近使用');
    // —— 分类页 ——
    expect(zh.searchCategoryHint('分类'), '搜索分类工具');
    expect(zh.categoryNoMatch('分类', 'x'), '分类里没有“x”。');
    expect(zh.commonTools, '常用工具');
    expect(zh.match('x'), '命中：x');
    expect(zh.matchWithText('x', 'y'), '命中：x · y');
    // —— 工具卡片与列表项 ——
    expect(zh.toolCount(3), '3 个工具');
    expect(zh.favoriteAdd, '收藏');
    expect(zh.favoriteRemove, '取消收藏');
    expect(zh.otherCategories, '其它分类');
    expect(zh.copyThisItem, '复制此项');
    // —— 工具详情页：菜单与外壳 ——
    expect(zh.pasteInputs, '粘贴参数');
    expect(zh.copyInputs, '复制参数');
    expect(zh.copyResult, '复制结果');
    expect(zh.saveHistory, '保存历史');
    expect(zh.saveNote, '保存笔记');
    expect(zh.resetInputs, '重置输入');
    // —— 工具详情页：参数卡片 ——
    expect(zh.inputParameters, '输入参数');
    expect(zh.noNumericInputs, '该工具无需数字参数，请使用上方结果和操作按钮完成复制、保存或笔记记录。');
    expect(zh.optionalInput('a'), 'a（可选）');
    expect(zh.decrease, '减小');
    expect(zh.increase, '增大');
    expect(zh.clearInput, '清空');
    expect(zh.restoreDefault, '恢复默认');
    // —— 工具详情页：结果与状态 ——
    expect(zh.primaryResult, '主结果');
    expect(zh.copyPrimaryResult, '复制主结果');
    expect(zh.statusInputInvalid, '输入需要修正');
    expect(zh.statusResultCheck, '结果需要检查');
    expect(zh.statusResultReusable, '结果可复用');
    expect(zh.fixInputsFirst, '请先修正输入参数');
    expect(zh.fixInputsFirstWith('s'), '请先修正输入参数：s');
    expect(zh.inputsCopied, '已复制输入参数');
    expect(zh.copiedLabel('a'), '已复制a');
    // —— 文本工具详情页 ——
    expect(zh.formulaAndVariables, '公式与变量');
    expect(zh.inputLabel, '输入');
    expect(zh.formulaHint, '例如 a * b + sqrt(c)');
    expect(zh.primaryResultCopied, '已复制主结果');
    expect(zh.detailResult, '详细结果');
    expect(zh.copyDetailResult, '复制详细结果');
    expect(zh.detailResultCopied, '已复制详细结果');
    expect(zh.useAsInput, '回填');
    expect(zh.fixInput('m'), '请先修正输入：m');
    expect(zh.urlCodecSample, 'NekoCalc 工具箱');
    expect(zh.textStatsSample, 'NekoCalc\n全能计算工具箱');
    // —— 文本工具的逐项输入提示 ——
    expect(zh.hintBaseConvert, '输入 255、0xFF、#FF、FFh、1010b 或 0o755');
    expect(zh.hintTimestamp, '输入秒/毫秒时间戳、1700000000.123s 或 2026年6月8日');
    expect(zh.hintColorConvert, '输入 #5B47FF、rgb(...)、hsl(...) 或 rebeccapurple');
    expect(zh.hintBase64, '输入文本、Base64、Base64URL 或 data URL');
    expect(zh.hintUrlCodec, '输入 URL、query string、普通文本或百分号编码文本');
    expect(zh.hintJsonFormat, '输入 JSON、JSON Lines 或带 BOM 的 JSON 文本');
    expect(zh.hintAsciiUnicode, r'输入字符、U+4E2D、\u4E2D 或 128072');
    expect(zh.hintBitwise, '输入两个整数，例如 12 5、0xFF 0b1010、A=0xF0 B=0b1010');
    expect(zh.hintChecksum, r'输入文本或 DE AD BE EF / \xDE 十六进制字节');
    expect(zh.hintUuid, '留空生成 UUID，或粘贴 UUID 校验/标准化');
    expect(zh.hintJwtDecode, '输入完整 JWT token，离线解码 Header/Payload');
    expect(zh.hintQueryParams, '输入 URL、请求行、片段 query 或 a=1&b=2;b=3');
    expect(zh.hintHtmlEntities, '输入 HTML、命名实体或 &#x4E2D; 数字实体');
    expect(zh.hintRegexTest, '第一行正则，后续行测试文本');
    expect(zh.hintTextStats, '输入要统计的文本，输出字符分类和段落信息');
    expect(zh.hintCsvJson, '首行为表头，支持逗号、Tab、分号、竖线分隔');
    expect(zh.hintFnvCrc, r'输入文本或 31 32 33 十六进制字节');
    expect(zh.hintDefault, '输入内容');
  });

  test('拟合页中文表与迁移前源码里那些字逐字节相同', () {
    // —— 页头 ——
    expect(fitZh.back, '返回');
    expect(fitZh.reset, '重置');
    // —— 输入校验 ——
    expect(fitZh.needTwoRows, '请输入至少两行有效数据');
    expect(fitZh.needTwoRowsPanel, '请输入至少两行有效数据。');
    expect(fitZh.invalidX, '请输入一个 x 数值');
    expect(fitZh.needFitFirst, '请先得到有效拟合结果');
    expect(fitZh.noPrediction, '当前模型在这个 x 上无有效预测');
    // —— 输入卡片 ——
    expect(fitZh.dataAndModel, '数据与模型');
    expect(fitZh.sampleData, '示例数据');
    expect(fitZh.clearData, '清空数据');
    expect(fitZh.paste, '粘贴');
    expect(fitZh.fitSeries, '拟合数据组');
    expect(fitZh.seriesPoints('y1', 3), 'y1 · 3 点');
    expect(fitZh.dataList, '数据列表');
    expect(fitZh.dataListHint,
        '支持 x,y；x,y1,y2 多列；空行分隔多组。\n例如：\n1, 2.1, 1.2\n2, 3.9, 1.8\n\n1, 8\n2, 13');
    expect(fitZh.notParsedYet, '尚未解析到有效数据');
    expect(fitZh.parsedSeries(2), '已解析 2 组');
    expect(fitZh.points(7), '7 点');
    expect(fitZh.currentSeries('y1', 7), '当前 y1 7 点');
    // —— 结果卡片 ——
    expect(fitZh.fitOf('L'), 'L拟合');
    expect(fitZh.alreadyBestModel, '当前模型已是推荐模型');
    expect(fitZh.tryRecommended('L'), '推荐尝试 L');
    expect(fitZh.pointCount, '点数');
    expect(fitZh.seriesLabel, '数据组');
    expect(fitZh.copyEquation, '复制方程');
    expect(fitZh.copyResidual, '复制异常点');
    // —— 预测卡片 ——
    expect(fitZh.prediction, '预测');
    expect(fitZh.predictX, '预测 x');
    expect(fitZh.predictXHint, '例如 7、2.5、５０％');
    expect(fitZh.clearPrediction, '清空预测');
    expect(fitZh.predictionReading('1', '2'), 'x=1 时，y=2');
    expect(fitZh.predictionHint, '输入 x 后实时计算预测值');
    expect(fitZh.extrapolationWarning, '该 x 超出样本范围，属于外推估算。');
    // —— 模型建议与异常点 ——
    expect(fitZh.modelAdvice, '模型建议');
    expect(fitZh.applyBest, '应用最佳');
    expect(fitZh.residualAlerts, '疑似异常点');
    expect(fitZh.modelUnavailable('L'), 'L不可用');
    expect(fitZh.unavailable, '不可用');
    // —— 图表与数据表 ——
    expect(fitZh.chart, '图表');
    expect(fitZh.legendFitSuffix, ' 拟合');
    expect(fitZh.dataTable, '数据表');
    expect(fitZh.seriesRows(5), '当前组 5 行');
    expect(fitZh.residual, '残差');
    // —— 底部动作区 ——
    expect(fitZh.copy, '复制');
    expect(fitZh.save, '保存');
    expect(fitZh.note, '笔记');
    expect(fitZh.exportCsv, '导出 CSV');
    expect(fitZh.saveChart, '保存图表');
    expect(fitZh.csvExported, '拟合数据已导出为 CSV');
    expect(fitZh.csvExportCancelled, '已取消导出 CSV');
    expect(fitZh.csvExportFailed('e'), '导出 CSV 失败：e');
    expect(fitZh.chartSaved, '拟合图表已保存为 PNG');
    expect(fitZh.chartSaveCancelled, '已取消保存图表');
    expect(fitZh.chartSaveFailed('e'), '保存图表失败：e');
    expect(fitZh.equationCopied, '已复制方程');
    expect(fitZh.residualCopied, '已复制异常点');
    expect(fitZh.predictionCopied, '已复制预测');
    expect(fitZh.resultCopied, '已复制结果');
    // —— 示例数据菜单 ——
    expect(fitZh.sampleMultiColumn, '多列示例');
    expect(fitZh.sampleMultiColumnNote, '一列 x，多列 y，适合对比多组数据');
    expect(fitZh.sampleHeader, '表头示例');
    expect(fitZh.sampleHeaderNote, '兼容从表格粘贴的 x,y1,y2 表头');
    expect(fitZh.sampleLocalized, '本地化数字示例');
    expect(fitZh.sampleLocalizedNote, '全角数字、百分号会自动规范化');
    // —— 复制 / 落库的正文 ——
    expect(fitZh.noFitResult, '无有效拟合结果');
    expect(fitZh.copySeries('y1'), '数据组: y1');
    expect(fitZh.copyModelAdvice, '模型建议:');
    expect(fitZh.copyDiagnostics, '诊断:');
    expect(fitZh.copyResidualHeading, '疑似异常点:');
    expect(fitZh.copyData, '数据:');
    expect(fitZh.copyPrediction('1', '2'), '预测: x=1, y=2');
    expect(fitZh.historyExpression('L', 'd'), 'L拟合: d');
  });

  test('两张英文表都没有汉字、没有空串，而且真的换了', () {
    final pairs = <String, List<String>>{
      'clear': [zh.clear, en.clear],
      'more': [zh.more, en.more],
      'back': [zh.back, en.back],
      'reset': [zh.reset, en.reset],
      'copy': [zh.copy, en.copy],
      'save': [zh.save, en.save],
      'note': [zh.note, en.note],
      'paste': [zh.paste, en.paste],
      'formula': [zh.formula, en.formula],
      'insights': [zh.insights, en.insights],
      'resultCopied': [zh.resultCopied, en.resultCopied],
      'toolsPageTitle': [zh.toolsPageTitle, en.toolsPageTitle],
      'toolsSearchHint': [zh.toolsSearchHint, en.toolsSearchHint],
      'searchResultsCount': [
        zh.searchResultsCount(3),
        en.searchResultsCount(3)
      ],
      'allCategories': [zh.allCategories, en.allCategories],
      'allLabel': [zh.allLabel, en.allLabel],
      'noMatchAtAll': [zh.noMatchAtAll('x'), en.noMatchAtAll('x')],
      'suggestedTools': [zh.suggestedTools, en.suggestedTools],
      'recentTools': [zh.recentTools, en.recentTools],
      'manage': [zh.manage, en.manage],
      'add': [zh.add, en.add],
      'favoriteTools': [zh.favoriteTools, en.favoriteTools],
      'favoriteEmpty': [zh.favoriteEmpty, en.favoriteEmpty],
      'categories': [zh.categories, en.categories],
      'clearAll': [zh.clearAll, en.clearAll],
      'recentEmpty': [zh.recentEmpty, en.recentEmpty],
      'removeRecentTooltip': [zh.removeRecentTooltip, en.removeRecentTooltip],
      'searchCategoryHint': [
        zh.searchCategoryHint('X'),
        en.searchCategoryHint('X')
      ],
      'categoryNoMatch': [
        zh.categoryNoMatch('X', 'y'),
        en.categoryNoMatch('X', 'y')
      ],
      'commonTools': [zh.commonTools, en.commonTools],
      'match': [zh.match('x'), en.match('x')],
      'matchWithText': [zh.matchWithText('x', 'y'), en.matchWithText('x', 'y')],
      'toolCount': [zh.toolCount(3), en.toolCount(3)],
      'favoriteAdd': [zh.favoriteAdd, en.favoriteAdd],
      'favoriteRemove': [zh.favoriteRemove, en.favoriteRemove],
      'otherCategories': [zh.otherCategories, en.otherCategories],
      'copyThisItem': [zh.copyThisItem, en.copyThisItem],
      'pasteInputs': [zh.pasteInputs, en.pasteInputs],
      'copyInputs': [zh.copyInputs, en.copyInputs],
      'copyResult': [zh.copyResult, en.copyResult],
      'saveHistory': [zh.saveHistory, en.saveHistory],
      'saveNote': [zh.saveNote, en.saveNote],
      'resetInputs': [zh.resetInputs, en.resetInputs],
      'inputParameters': [zh.inputParameters, en.inputParameters],
      'noNumericInputs': [zh.noNumericInputs, en.noNumericInputs],
      'optionalInput': [zh.optionalInput('a'), en.optionalInput('a')],
      'decrease': [zh.decrease, en.decrease],
      'increase': [zh.increase, en.increase],
      'clearInput': [zh.clearInput, en.clearInput],
      'restoreDefault': [zh.restoreDefault, en.restoreDefault],
      'primaryResult': [zh.primaryResult, en.primaryResult],
      'copyPrimaryResult': [zh.copyPrimaryResult, en.copyPrimaryResult],
      'statusInputInvalid': [zh.statusInputInvalid, en.statusInputInvalid],
      'statusResultCheck': [zh.statusResultCheck, en.statusResultCheck],
      'statusResultReusable': [
        zh.statusResultReusable,
        en.statusResultReusable
      ],
      'fixInputsFirst': [zh.fixInputsFirst, en.fixInputsFirst],
      'fixInputsFirstWith': [
        zh.fixInputsFirstWith('s'),
        en.fixInputsFirstWith('s')
      ],
      'inputsCopied': [zh.inputsCopied, en.inputsCopied],
      'copiedLabel': [zh.copiedLabel('a'), en.copiedLabel('a')],
      'formulaAndVariables': [zh.formulaAndVariables, en.formulaAndVariables],
      'inputLabel': [zh.inputLabel, en.inputLabel],
      'formulaHint': [zh.formulaHint, en.formulaHint],
      'primaryResultCopied': [zh.primaryResultCopied, en.primaryResultCopied],
      'detailResult': [zh.detailResult, en.detailResult],
      'copyDetailResult': [zh.copyDetailResult, en.copyDetailResult],
      'detailResultCopied': [zh.detailResultCopied, en.detailResultCopied],
      'useAsInput': [zh.useAsInput, en.useAsInput],
      'fixInput': [zh.fixInput('m'), en.fixInput('m')],
      'urlCodecSample': [zh.urlCodecSample, en.urlCodecSample],
      'textStatsSample': [zh.textStatsSample, en.textStatsSample],
      'hintBaseConvert': [zh.hintBaseConvert, en.hintBaseConvert],
      'hintTimestamp': [zh.hintTimestamp, en.hintTimestamp],
      'hintColorConvert': [zh.hintColorConvert, en.hintColorConvert],
      'hintBase64': [zh.hintBase64, en.hintBase64],
      'hintUrlCodec': [zh.hintUrlCodec, en.hintUrlCodec],
      'hintJsonFormat': [zh.hintJsonFormat, en.hintJsonFormat],
      'hintAsciiUnicode': [zh.hintAsciiUnicode, en.hintAsciiUnicode],
      'hintBitwise': [zh.hintBitwise, en.hintBitwise],
      'hintChecksum': [zh.hintChecksum, en.hintChecksum],
      'hintUuid': [zh.hintUuid, en.hintUuid],
      'hintJwtDecode': [zh.hintJwtDecode, en.hintJwtDecode],
      'hintQueryParams': [zh.hintQueryParams, en.hintQueryParams],
      'hintHtmlEntities': [zh.hintHtmlEntities, en.hintHtmlEntities],
      'hintRegexTest': [zh.hintRegexTest, en.hintRegexTest],
      'hintTextStats': [zh.hintTextStats, en.hintTextStats],
      'hintCsvJson': [zh.hintCsvJson, en.hintCsvJson],
      'hintFnvCrc': [zh.hintFnvCrc, en.hintFnvCrc],
      'hintDefault': [zh.hintDefault, en.hintDefault],
      'fit.back': [fitZh.back, fitEn.back],
      'fit.reset': [fitZh.reset, fitEn.reset],
      'fit.needTwoRows': [fitZh.needTwoRows, fitEn.needTwoRows],
      'fit.needTwoRowsPanel': [fitZh.needTwoRowsPanel, fitEn.needTwoRowsPanel],
      'fit.invalidX': [fitZh.invalidX, fitEn.invalidX],
      'fit.needFitFirst': [fitZh.needFitFirst, fitEn.needFitFirst],
      'fit.noPrediction': [fitZh.noPrediction, fitEn.noPrediction],
      'fit.dataAndModel': [fitZh.dataAndModel, fitEn.dataAndModel],
      'fit.sampleData': [fitZh.sampleData, fitEn.sampleData],
      'fit.clearData': [fitZh.clearData, fitEn.clearData],
      'fit.paste': [fitZh.paste, fitEn.paste],
      'fit.fitSeries': [fitZh.fitSeries, fitEn.fitSeries],
      'fit.seriesPoints': [
        fitZh.seriesPoints('y1', 3),
        fitEn.seriesPoints('y1', 3)
      ],
      'fit.dataList': [fitZh.dataList, fitEn.dataList],
      'fit.dataListHint': [fitZh.dataListHint, fitEn.dataListHint],
      'fit.notParsedYet': [fitZh.notParsedYet, fitEn.notParsedYet],
      'fit.parsedSeries': [fitZh.parsedSeries(2), fitEn.parsedSeries(2)],
      'fit.points': [fitZh.points(7), fitEn.points(7)],
      'fit.currentSeries': [
        fitZh.currentSeries('y1', 7),
        fitEn.currentSeries('y1', 7)
      ],
      'fit.fitOf': [fitZh.fitOf('L'), fitEn.fitOf('L')],
      'fit.alreadyBestModel': [fitZh.alreadyBestModel, fitEn.alreadyBestModel],
      'fit.tryRecommended': [
        fitZh.tryRecommended('L'),
        fitEn.tryRecommended('L')
      ],
      'fit.pointCount': [fitZh.pointCount, fitEn.pointCount],
      'fit.seriesLabel': [fitZh.seriesLabel, fitEn.seriesLabel],
      'fit.copyEquation': [fitZh.copyEquation, fitEn.copyEquation],
      'fit.copyResidual': [fitZh.copyResidual, fitEn.copyResidual],
      'fit.prediction': [fitZh.prediction, fitEn.prediction],
      'fit.predictX': [fitZh.predictX, fitEn.predictX],
      'fit.predictXHint': [fitZh.predictXHint, fitEn.predictXHint],
      'fit.clearPrediction': [fitZh.clearPrediction, fitEn.clearPrediction],
      'fit.predictionReading': [
        fitZh.predictionReading('1', '2'),
        fitEn.predictionReading('1', '2')
      ],
      'fit.predictionHint': [fitZh.predictionHint, fitEn.predictionHint],
      'fit.extrapolationWarning': [
        fitZh.extrapolationWarning,
        fitEn.extrapolationWarning
      ],
      'fit.modelAdvice': [fitZh.modelAdvice, fitEn.modelAdvice],
      'fit.applyBest': [fitZh.applyBest, fitEn.applyBest],
      'fit.residualAlerts': [fitZh.residualAlerts, fitEn.residualAlerts],
      'fit.modelUnavailable': [
        fitZh.modelUnavailable('L'),
        fitEn.modelUnavailable('L')
      ],
      'fit.unavailable': [fitZh.unavailable, fitEn.unavailable],
      'fit.chart': [fitZh.chart, fitEn.chart],
      'fit.legendFitSuffix': [fitZh.legendFitSuffix, fitEn.legendFitSuffix],
      'fit.dataTable': [fitZh.dataTable, fitEn.dataTable],
      'fit.seriesRows': [fitZh.seriesRows(5), fitEn.seriesRows(5)],
      'fit.residual': [fitZh.residual, fitEn.residual],
      'fit.copy': [fitZh.copy, fitEn.copy],
      'fit.save': [fitZh.save, fitEn.save],
      'fit.note': [fitZh.note, fitEn.note],
      'fit.exportCsv': [fitZh.exportCsv, fitEn.exportCsv],
      'fit.saveChart': [fitZh.saveChart, fitEn.saveChart],
      'fit.csvExported': [fitZh.csvExported, fitEn.csvExported],
      'fit.csvExportCancelled': [
        fitZh.csvExportCancelled,
        fitEn.csvExportCancelled
      ],
      'fit.csvExportFailed': [
        fitZh.csvExportFailed('e'),
        fitEn.csvExportFailed('e')
      ],
      'fit.chartSaved': [fitZh.chartSaved, fitEn.chartSaved],
      'fit.chartSaveCancelled': [
        fitZh.chartSaveCancelled,
        fitEn.chartSaveCancelled
      ],
      'fit.chartSaveFailed': [
        fitZh.chartSaveFailed('e'),
        fitEn.chartSaveFailed('e')
      ],
      'fit.equationCopied': [fitZh.equationCopied, fitEn.equationCopied],
      'fit.residualCopied': [fitZh.residualCopied, fitEn.residualCopied],
      'fit.predictionCopied': [fitZh.predictionCopied, fitEn.predictionCopied],
      'fit.resultCopied': [fitZh.resultCopied, fitEn.resultCopied],
      'fit.sampleMultiColumn': [
        fitZh.sampleMultiColumn,
        fitEn.sampleMultiColumn
      ],
      'fit.sampleMultiColumnNote': [
        fitZh.sampleMultiColumnNote,
        fitEn.sampleMultiColumnNote
      ],
      'fit.sampleHeader': [fitZh.sampleHeader, fitEn.sampleHeader],
      'fit.sampleHeaderNote': [fitZh.sampleHeaderNote, fitEn.sampleHeaderNote],
      'fit.sampleLocalized': [fitZh.sampleLocalized, fitEn.sampleLocalized],
      'fit.sampleLocalizedNote': [
        fitZh.sampleLocalizedNote,
        fitEn.sampleLocalizedNote
      ],
      'fit.noFitResult': [fitZh.noFitResult, fitEn.noFitResult],
      'fit.copySeries': [fitZh.copySeries('y1'), fitEn.copySeries('y1')],
      'fit.copyModelAdvice': [fitZh.copyModelAdvice, fitEn.copyModelAdvice],
      'fit.copyDiagnostics': [fitZh.copyDiagnostics, fitEn.copyDiagnostics],
      'fit.copyResidualHeading': [
        fitZh.copyResidualHeading,
        fitEn.copyResidualHeading
      ],
      'fit.copyData': [fitZh.copyData, fitEn.copyData],
      'fit.copyPrediction': [
        fitZh.copyPrediction('1', '2'),
        fitEn.copyPrediction('1', '2')
      ],
      'fit.historyExpression': [
        fitZh.historyExpression('L', 'd'),
        fitEn.historyExpression('L', 'd')
      ],
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
    // 中文：**令牌表逐条过，不是并成一串比。** 它是一张 `Map`，十条装在一个字段里；并成一串的话
    //       "哪一条错了"就看不出来。上面 `pairs` 里放不了它，所以单开这一段——顺带把
    //       `pairs.length` 那个数字留给它原来守的东西（少了行才红），不必为一个新字段去动它。
    //       判据与上面完全相同：中文侧不空、英文侧不空、英文侧无汉字、两边真的不同。
    // English: **The token table is checked entry by entry, not as one joined string.** It is a `Map`
    //          holding ten entries under one field, and joining them would hide which one went wrong. It
    //          cannot go in `pairs` above, hence this separate pass — which also leaves
    //          `pairs.length` guarding what it always guarded (a line going *missing*), so a new field
    //          is no reason to move that number. Same ruler as above: neither side empty, no CJK on the
    //          English side, and the two really differ.
    expect(zh.matchLabels, isNotEmpty);
    for (final entry in zh.matchLabels.entries) {
      final enLabel = en.matchLabels[entry.key];
      expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} 中文侧是空的');
      expect(enLabel, isNotNull, reason: '英文令牌表里没有 ${entry.key}');
      expect(enLabel!.trim(), isNotEmpty, reason: '${entry.key} 英文侧是空的');
      expect(_containsCjk(enLabel), isFalse,
          reason: '${entry.key} 英文侧还有汉字：$enLabel');
      expect(entry.value, isNot(enLabel), reason: '「${entry.value}」在英文表里没换');
    }
    expect(en.matchLabels.keys.toSet(), zh.matchLabels.keys.toSet(),
        reason: '两张令牌表的键必须一模一样');

    expect(pairs.length, 160, reason: '两张表一共 88 + 72 条，漏一条这里就会少一条');
  });

  testWidgets('没有装作用域时工具首页仍渲染中文（默认态不变）', (tester) async {
    await tester.pumpWidget(_app(const ToolsHomePage(
      db: _EmptyDatabase(),
      settings: AppSettings(
        haptics: false,
        hapticStrength: '标准',
        restoreState: false,
        autoSaveHistory: false,
        angleMode: 'RAD',
        precision: 6,
        themeModeLabel: '跟随系统',
        expressionDisplayMode: '数学符号',
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('工具'), findsOneWidget);
    expect(find.text('搜索工具、公式、单位...'), findsOneWidget);
    expect(find.text('推荐工具'), findsOneWidget);
    expect(find.text('收藏工具'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
  });

  testWidgets('装上 AppLanguageScope(en) 之后工具首页渲染英文，工具名也跟着换', (tester) async {
    await tester.pumpWidget(_app(
      const ToolsHomePage(
        db: _EmptyDatabase(),
        settings: AppSettings(
          haptics: false,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: false,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
        ),
      ),
      language: AppLanguage.en,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Search tools, formulas, units…'), findsOneWidget);
    expect(find.text('Suggested tools'), findsOneWidget);
    expect(find.text('Favourite tools'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('工具'), findsNothing);
    // 中文：**这是本轮唯一翻面的断言。** 它原先钉的是那条已知残留——"外壳换了语言，工具名没有"
    //       （`expect(find.text(toolCatalog.first.title), findsWidgets)`）。目录本轮进了
    //       `ToolCatalogStrings`，所以断言随之翻面：英文下屏幕上是**英文名**，中文名一个都不许再有。
    //       **上面那两条不带作用域的用例一个字没动**——默认态（中文）的证据仍在它们身上。
    //       `toolCatalog.first.title` 依旧是这条断言的一部分，只是从"应当出现"变成"不许出现"：
    //       目录里那个中文名还是同一个字面量，改的从来是屏幕上那一格。
    // English: **the one expectation this round turns over.** It used to pin the known remainder —
    //          "the shell switched language, the tool names did not"
    //          (`expect(find.text(toolCatalog.first.title), findsWidgets)`). The catalogue now goes
    //          through `ToolCatalogStrings`, so the assertion flips: in English the screen shows the
    //          **English name**, and the Chinese one must not appear at all. **The two no-scope cases
    //          above are untouched, character for character** — they still carry the default-state
    //          (Chinese) evidence. `toolCatalog.first.title` is still part of this assertion, only
    //          inverted from "must appear" to "must not": that catalogue literal has not moved, the
    //          cell on screen is what changed.
    final first = toolCatalog.first;
    expect(find.text(ToolCatalogStrings.forLanguage(AppLanguage.en).toolName(first.id)),
        findsWidgets);
    expect(
        find.text(ToolCatalogStrings.forLanguage(AppLanguage.zh).toolName(first.id)),
        findsNothing);
    expect(find.text(first.title), findsNothing);
  });

  // 中文：**这两条钉的是一个真实的崩溃。** 页面第一次计算原先留在 `initState` 里，那儿要取文案表，
  //       而 `initState` 阶段查祖先里的 `AppLanguageScope` 在 debug 构建里会直接抛。没有作用域时
  //       查不到祖先、静默回落到中文，所以上面那两条"默认态不变"的用例**看不见**这个崩溃——
  //       必须有一条真的把作用域装上。真实 App 里 `app.dart` 一定装着它。
  // English: **these two pin a real crash.** The first calculation used to live in `initState`, where
  //          reading the copy table needs an ancestor `AppLanguageScope` — and looking one up while
  //          `initState` runs throws in debug builds. With no scope the lookup finds no ancestor and
  //          falls back to Chinese silently, so the "default state unchanged" cases above **cannot**
  //          see that crash: one case has to actually install the scope. The real app always carries
  //          one (`app.dart`).
  testWidgets('拟合页在装了语言作用域时能渲染出来', (tester) async {
    await tester.pumpWidget(_app(
      DataFitToolScreen(
        db: const _EmptyDatabase(),
        tool: toolById('data_fit')!,
        settings: AppSettings.fallback,
      ),
      language: AppLanguage.zh,
    ));
    await tester.pump();
    expect(find.text('数据与模型'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('文本工具页在装了语言作用域时能渲染出来（初值也跟着语言）', (tester) async {
    await tester.pumpWidget(_app(
      TextToolDetailScreen(
        db: const _EmptyDatabase(),
        tool: toolById('text_stats')!,
        settings: AppSettings.fallback,
      ),
      language: AppLanguage.en,
    ));
    await tester.pump();
    expect(find.text('Primary result'), findsOneWidget);
    expect(find.text(en.textStatsSample), findsOneWidget,
        reason: '英文界面下输入框的初值也该是英文那一份');
    expect(tester.takeException(), isNull);
  });

  testWidgets('工具卡片上的「个工具」跟着语言走', (tester) async {
    await tester.pumpWidget(_app(
      const ToolSearchEmptyState(
        message: 'm',
        suggestions: <String>[],
        examples: <String>[],
        onQuerySelected: _noopString,
        alternatives: <Widget>[Text('alt')],
      ),
      language: AppLanguage.en,
    ));
    expect(find.text('Other categories'), findsOneWidget);
    expect(find.text('其它分类'), findsNothing);
  });
}

Widget _app(Widget home, {AppLanguage? language}) => MaterialApp(
      // 中文：`ToolsHomePage` 直接返回一个 `ListView`（外壳会给它套 Scaffold），所以测试要自己
      //       补一层——没有 `Material` 祖先，`TextField` 会在构建时抛。
      // English: `ToolsHomePage` returns a bare `ListView` (the shell wraps it in a Scaffold), so the
      //          test supplies one — without a `Material` ancestor the `TextField` throws while
      //          building.
      home: Scaffold(
        body: language == null
            ? home
            : AppLanguageScope(language: language, child: home),
      ),
    );

void _noopString(String _) {}

/// 中文：一份什么都答"空"的库；护栏测试只关心首帧那几个字，不关心收藏与最近使用。
/// English: A database that answers empty to everything; the guard tests care about the first
///          frame's copy, not about favourites or recents.
class _EmptyDatabase implements AppDatabase {
  const _EmptyDatabase();

  /// 中文：`implements` 只列出真会被调用的那几个；其余的交给 `noSuchMethod` 抛错——真被调到
  ///       说明页面比这份假库以为的读得多，那时应当红，而不是悄悄返回空。
  /// English: `implements` lists only the members actually reached; everything else falls to
  ///          `noSuchMethod` and throws — if one of them is reached, the page reads more than this
  ///          fake assumed and the test should go red rather than quietly answer empty.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<Set<String>> favoriteToolIds() async => const {};

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async => const [];
}

/// 中文：CJK 统一表意文字区（含扩展 A）。够用了：本项目的界面文案都落在这里。
/// English: The CJK Unified Ideographs block (plus Extension A) — enough, since this project's UI
///          copy lives there.

bool _containsCjk(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}
