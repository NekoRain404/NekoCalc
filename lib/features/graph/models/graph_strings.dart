import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：**graph 整棵子树的界面文案表——一个功能一张表。** 机制本身（手写分表、`static final`、
///       `of` 对枚举穷尽 switch）与设置页那张表共用一套理由，写在 `settings_strings.dart` 的文件头，
///       这里不重抄。
///
///       **它为什么住在 `models/` 而不是 `presentation/`。** 这一族的文案有三个来路：
///       `graph_page.dart` / `graph_function_expression_dialog.dart`（表现层）、
///       `graph_models.dart` 与 `graph_marker_builders.dart`（模型层，负责预览句、标记 `kind`/`info`、
///       复制文本的小节名）。模型层**不许 import 表现层**，所以表必须住在两者都能 import 的那一层；
///       模型层是这里的下层，于是表放在 `models/`，表现层照常往下 import。
///
///       **小节名（`图形数据` / `函数` / `视窗` / `标记` / `当前标记` / `显示` / `隐藏`）为什么可以进表。**
///       它们是 `buildGraphCopyText` 写出去、粘贴解析器又读回来的**线格式**。解析器**两种语言都收**
///       （`graph_workspace_paste.dart` 里 `viewport` / `graph data` / `functions` / `markers` /
///       `current marker` / `hidden` 与中文逐条对齐，`current marker` 是本轮之前补上的），
///       所以英文界面复制出去的数据在英文界面里能自己粘回来。这一条由
///       `graph_strings_test.dart` 的英文回路测试钉住。
///
///       **参数一律必填，不设"没传就中文"的默认。** 上一轮给粘贴结果表留过默认值，那是因为当时
///       唯一的调用方是另一位作者的未提交文件、不许改；本轮那些调用方已经入库、可以改，于是照
///       本项目后来的做法（`五个领域文件入口全部改成必填表`）改成必填——**漏传是编译错误，
///       不是静默回落成中文**。
/// English: **the interface-copy table for the whole graph subtree — one table per feature.** The
///          mechanism itself (hand-written tables, `static final`, an exhaustive `of` switch over the
///          enum) shares one set of reasons with the settings table and is written on
///          `settings_strings.dart`'s file head; it is not copied again here.
///
///          **Why it lives in `models/` rather than `presentation/`.** Three places in this family
///          need copy: `graph_page.dart` / `graph_function_expression_dialog.dart` (presentation) and
///          `graph_models.dart` / `graph_marker_builders.dart` (models — the preview sentence, the
///          marker `kind`/`info`, and the copy text's section names). **The models layer may not
///          import presentation**, so the table must live in a layer both can import; models is the
///          lower layer here, so the table sits in `models/` and presentation imports downward as
///          usual.
///
///          **Why the section names (`图形数据` / `函数` / `视窗` / `标记` / `当前标记` / `显示` /
///          `隐藏`) may go into the table.** They are the **wire format** `buildGraphCopyText` writes
///          and the paste parser reads back. The parser **accepts both languages** (in
///          `graph_workspace_paste.dart`, `viewport` / `graph data` / `functions` / `markers` /
///          `current marker` / `hidden` line up one-for-one with the Chinese; `current marker` was
///          added just before this round), so data copied out of the English interface pastes back
///          into it. `graph_strings_test.dart`'s English round-trip test pins this.
///
///          **Every parameter is required; there is no "Chinese when omitted" default.** A previous
///          round left such a default on the paste-result table because its only caller was another
///          author's uncommitted file that could not be touched; those callers are committed now and
///          editable, so this follows the project's later practice (the five domain entry points all
///          take a required table) — **omitting it is a compile error, not a silent fallback to
///          Chinese.**
@immutable
class GraphStrings {
  const GraphStrings({
    // —— 页面骨架与按钮 ——
    required this.pageTitle,
    required this.pasteTooltip,
    required this.copyTooltip,
    required this.exportPngTooltip,
    required this.addFunction,
    required this.addConfirm,
    required this.editFunction,
    required this.saveConfirm,
    required this.deleteFunction,
    required this.functionActions,
    required this.reset,
    required this.fit,
    required this.zoomIn,
    required this.zoomOut,
    required this.zerosButton,
    required this.intersectionsButton,
    required this.extremesButton,
    // —— 状态栏 ——
    required this.panHint,
    required this.addedFunction,
    required this.shownFunction,
    required this.hiddenFunction,
    required this.updatedFunction,
    required this.deletedFunction,
    required this.viewReset,
    required this.invalidWorkspace,
    required this.restoredWorkspace,
    required this.viewRange,
    required this.panRange,
    required this.zoomed,
    required this.noVisibleFunction,
    required this.notEnoughSamples,
    required this.fittedVisible,
    required this.sampleNone,
    required this.sampleDone,
    required this.noZeros,
    required this.foundZeros,
    required this.noIntersections,
    required this.foundIntersections,
    required this.noExtremes,
    required this.foundExtremes,
    // —— 提示条 ——
    required this.copiedGraphData,
    required this.savedPng,
    required this.cancelledSave,
    required this.exportFailed,
    required this.copiedMarker,
    required this.centeredOn,
    // —— 标记面板与函数行 ——
    required this.previousMarker,
    required this.nextMarker,
    required this.copyMarker,
    required this.centerOnMarker,
    required this.hide,
    required this.show,
    // —— 函数表达式对话框 ——
    required this.expressionHint,
    required this.cancel,
    // —— 输入预览 ——
    required this.enterExpression,
    required this.willPlot,
    required this.cannotCompute,
    // —— 复制文本的小节名（解析器两种语言都收） ——
    required this.graphDataTitle,
    required this.functionsSection,
    required this.none,
    required this.expressionLine,
    required this.viewportSection,
    required this.currentMarkerSection,
    required this.markersSection,
    // —— 标记的 kind 与 info ——
    required this.sampleKind,
    required this.zeroKind,
    required this.overlapKind,
    required this.intersectionKind,
    required this.minimumKind,
    required this.maximumKind,
    required this.overlapsAxis,
    required this.zeroAt,
    required this.overlapText,
    required this.intersectionText,
    required this.extremumText,
    // —— 粘贴结果小结 ——
    required this.noWorkspace,
    required this.fromFunctionText,
    required this.fromCopyText,
    required this.workspaceRestored,
    required this.functionCount,
    required this.visibleCount,
  });

  final String pageTitle;
  final String pasteTooltip;
  final String copyTooltip;
  final String exportPngTooltip;

  /// 中文：`添加函数` 同时是标题、tooltip 与列表项——三种英文写法相同，共用一格。
  /// English: `添加函数` is a title, a tooltip and a list item at once; all three read the same in
  ///          English, so one entry serves them.
  final String addFunction;
  final String addConfirm;

  /// 中文：`编辑函数` 同时是对话框标题与菜单项，共用一格。
  /// English: `编辑函数` is both a dialog title and a menu item; one entry serves both.
  final String editFunction;
  final String saveConfirm;
  final String deleteFunction;
  final String functionActions;
  final String reset;
  final String fit;
  final String zoomIn;
  final String zoomOut;
  final String zerosButton;
  final String intersectionsButton;
  final String extremesButton;

  final String panHint;
  final String Function(String expression) addedFunction;
  final String Function(String label) shownFunction;
  final String Function(String label) hiddenFunction;
  final String Function(String expression) updatedFunction;
  final String Function(String label) deletedFunction;
  final String viewReset;
  final String invalidWorkspace;
  final String restoredWorkspace;
  final String Function(String xMin, String xMax) viewRange;
  final String Function(String xMin, String xMax) panRange;
  final String Function(String scale) zoomed;
  final String noVisibleFunction;
  final String notEnoughSamples;
  final String fittedVisible;
  final String Function(String x) sampleNone;
  final String Function(String x, int count) sampleDone;
  final String noZeros;
  final String Function(int count) foundZeros;
  final String noIntersections;
  final String Function(int count) foundIntersections;
  final String noExtremes;
  final String Function(int count) foundExtremes;

  final String copiedGraphData;
  final String savedPng;
  final String cancelledSave;
  final String Function(String error) exportFailed;
  final String copiedMarker;
  final String Function(String marker) centeredOn;

  final String previousMarker;
  final String nextMarker;
  final String copyMarker;
  final String centerOnMarker;

  /// 中文：`隐藏` / `显示` 既是函数行的 tooltip，也是复制文本里那个 `(显示)` / `(隐藏)` 标记——
  ///       两处英文写法相同，共用一格。
  /// English: `隐藏` / `显示` are both the function row's tooltips and the `(显示)` / `(隐藏)` mark in
  ///          the copy text; both read the same in English, so one entry serves both.
  final String hide;
  final String show;

  final String expressionHint;
  final String cancel;

  final String enterExpression;
  final String Function(String label, int validSampleCount) willPlot;
  final String cannotCompute;

  final String graphDataTitle;
  final String functionsSection;
  final String none;
  final String Function(String expression) expressionLine;
  final String viewportSection;
  final String currentMarkerSection;
  final String markersSection;

  final String sampleKind;
  final String zeroKind;
  final String overlapKind;
  final String intersectionKind;
  final String minimumKind;
  final String maximumKind;
  final String Function(String label) overlapsAxis;
  final String Function(String label, String x) zeroAt;
  final String Function(String first, String second) overlapText;
  final String Function(String first, String second, String x, String y)
      intersectionText;
  final String Function(String label, String kind, String x, String y)
      extremumText;

  final String noWorkspace;
  final String fromFunctionText;
  final String fromCopyText;
  final String workspaceRestored;
  final String Function(int count) functionCount;
  final String Function(int count) visibleCount;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`**.
  static GraphStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  static GraphStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => graphZh,
      AppLanguage.en => graphEn,
    };
  }

  static final GraphStrings graphZh = GraphStrings(
    pageTitle: '图形',
    pasteTooltip: '粘贴图形数据',
    copyTooltip: '复制图形数据',
    exportPngTooltip: '导出图形 PNG',
    addFunction: '添加函数',
    addConfirm: '添加',
    editFunction: '编辑函数',
    saveConfirm: '保存',
    deleteFunction: '删除函数',
    functionActions: '函数操作',
    reset: '重置',
    fit: '适配',
    zoomIn: '放大',
    zoomOut: '缩小',
    zerosButton: '零点',
    intersectionsButton: '交点',
    extremesButton: '极值',
    panHint: '拖动画布平移，双指缩放',
    addedFunction: (expression) => '已添加 y = $expression',
    shownFunction: (label) => '已显示 $label',
    hiddenFunction: (label) => '已隐藏 $label',
    updatedFunction: (expression) => '已更新 y = $expression',
    deletedFunction: (label) => '已删除 $label',
    viewReset: '视图已重置',
    invalidWorkspace: '图形工作区数据无效，已恢复默认视图',
    restoredWorkspace: '已恢复上次图形工作区',
    viewRange: (xMin, xMax) => '视图范围 x: $xMin ~ $xMax',
    panRange: (xMin, xMax) => 'x: $xMin ~ $xMax',
    zoomed: (scale) => '缩放 ${scale}x',
    noVisibleFunction: '没有可见函数可适配',
    notEnoughSamples: '当前视图没有足够的有效采样点',
    fittedVisible: '已适配当前可见曲线',
    sampleNone: (x) => 'x = $x 处没有可见有效函数值',
    sampleDone: (x, count) => 'x = $x，已取样 $count 条曲线',
    noZeros: '当前视图未找到零点',
    foundZeros: (count) => '找到 $count 个零点，点击高亮点查看详情',
    noIntersections: '当前视图未找到交点',
    foundIntersections: (count) => '找到 $count 个交点，点击高亮点查看详情',
    noExtremes: '当前视图没有有效极值采样',
    foundExtremes: (count) => '找到 $count 个极值点，点击高亮点查看详情',
    copiedGraphData: '已复制图形数据',
    savedPng: '图形已保存为 PNG',
    cancelledSave: '已取消保存图形',
    exportFailed: (error) => '导出图形失败：$error',
    copiedMarker: '已复制当前标记',
    centeredOn: (marker) => '已居中到 $marker',
    previousMarker: '上一个标记',
    nextMarker: '下一个标记',
    copyMarker: '复制标记',
    centerOnMarker: '居中到标记',
    hide: '隐藏',
    show: '显示',
    expressionHint: '例如 sin(x)、2x + 1、y = x^2 - 3x + 2',
    cancel: '取消',
    enterExpression: '请输入函数表达式',
    willPlot: (label, validSampleCount) =>
        '将绘制 $label，有效采样 $validSampleCount/5',
    cannotCompute: '表达式无法计算，请检查函数名、括号或变量 x',
    graphDataTitle: '图形数据',
    functionsSection: '函数',
    none: '无',
    expressionLine: (expression) => '   表达式: $expression',
    viewportSection: '视窗',
    currentMarkerSection: '当前标记',
    markersSection: '标记',
    sampleKind: '取样',
    zeroKind: '零点',
    overlapKind: '重合',
    intersectionKind: '交点',
    minimumKind: '极小值',
    maximumKind: '极大值',
    overlapsAxis: (label) => '$label 与 x 轴重合\n当前视图内所有 x 都是零点',
    zeroAt: (label, x) => '$label 零点\nx = $x\ny = 0',
    overlapText: (first, second) => '$first\n$second\n两条曲线在当前视图内重合',
    intersectionText: (first, second, x, y) =>
        '$first\n$second\n交点 x = $x, y = $y',
    extremumText: (label, kind, x, y) => '$label $kind\nx = $x\ny = $y',
    noWorkspace: '剪贴板里没有识别到图形工作区',
    fromFunctionText: '已从函数文本创建工作区',
    fromCopyText: '已从图形数据恢复工作区',
    workspaceRestored: '已恢复图形工作区',
    functionCount: (count) => '$count 个函数',
    visibleCount: (count) => '$count 个可见',
  );

  static final GraphStrings graphEn = GraphStrings(
    pageTitle: 'Graph',
    pasteTooltip: 'Paste graph data',
    copyTooltip: 'Copy graph data',
    exportPngTooltip: 'Export graph PNG',
    addFunction: 'Add function',
    addConfirm: 'Add',
    editFunction: 'Edit function',
    saveConfirm: 'Save',
    deleteFunction: 'Delete function',
    functionActions: 'Function actions',
    reset: 'Reset',
    fit: 'Fit',
    zoomIn: 'Zoom in',
    zoomOut: 'Zoom out',
    zerosButton: 'Zeros',
    intersectionsButton: 'Intersections',
    extremesButton: 'Extrema',
    panHint: 'Drag to pan, pinch to zoom',
    addedFunction: (expression) => 'Added y = $expression',
    shownFunction: (label) => 'Shown $label',
    hiddenFunction: (label) => 'Hidden $label',
    updatedFunction: (expression) => 'Updated y = $expression',
    deletedFunction: (label) => 'Deleted $label',
    viewReset: 'View reset',
    invalidWorkspace:
        'Graph workspace data was invalid; the default view was restored',
    restoredWorkspace: 'Restored the last graph workspace',
    viewRange: (xMin, xMax) => 'View range x: $xMin ~ $xMax',
    panRange: (xMin, xMax) => 'x: $xMin ~ $xMax',
    zoomed: (scale) => 'Zoom ${scale}x',
    noVisibleFunction: 'No visible function to fit',
    notEnoughSamples: 'Not enough valid samples in the current view',
    fittedVisible: 'Fitted the visible curves',
    sampleNone: (x) => 'No visible finite function value at x = $x',
    sampleDone: (x, count) => 'Sampled $count curves at x = $x',
    noZeros: 'No zeros found in the current view',
    foundZeros: (count) =>
        'Found $count zeros; tap a highlighted point for details',
    noIntersections: 'No intersections found in the current view',
    foundIntersections: (count) =>
        'Found $count intersections; tap a highlighted point for details',
    noExtremes: 'No valid extrema samples in the current view',
    foundExtremes: (count) =>
        'Found $count extrema; tap a highlighted point for details',
    copiedGraphData: 'Graph data copied',
    savedPng: 'Graph saved as PNG',
    cancelledSave: 'Graph save cancelled',
    exportFailed: (error) => 'Failed to export the graph: $error',
    copiedMarker: 'Current marker copied',
    centeredOn: (marker) => 'Centred on $marker',
    previousMarker: 'Previous marker',
    nextMarker: 'Next marker',
    copyMarker: 'Copy marker',
    centerOnMarker: 'Centre on marker',
    hide: 'Hide',
    show: 'Show',
    expressionHint: 'e.g. sin(x), 2x + 1, y = x^2 - 3x + 2',
    cancel: 'Cancel',
    enterExpression: 'Enter a function expression',
    willPlot: (label, validSampleCount) =>
        'Will plot $label, with $validSampleCount/5 valid samples',
    cannotCompute:
        'The expression could not be evaluated; check the function name, brackets or the variable x',
    graphDataTitle: 'Graph data',
    functionsSection: 'Functions',
    none: 'None',
    expressionLine: (expression) => '   Expression: $expression',
    viewportSection: 'Viewport',
    currentMarkerSection: 'Current marker',
    markersSection: 'Markers',
    sampleKind: 'Sample',
    zeroKind: 'Zero',
    overlapKind: 'Overlap',
    intersectionKind: 'Intersection',
    minimumKind: 'Minimum',
    maximumKind: 'Maximum',
    overlapsAxis: (label) =>
        '$label coincides with the x-axis\nEvery x in the current view is a zero',
    zeroAt: (label, x) => '$label zero\nx = $x\ny = 0',
    overlapText: (first, second) =>
        '$first\n$second\nThe two curves overlap in the current view',
    intersectionText: (first, second, x, y) =>
        '$first\n$second\nIntersection x = $x, y = $y',
    extremumText: (label, kind, x, y) => '$label $kind\nx = $x\ny = $y',
    noWorkspace: 'No graph workspace recognised in the clipboard',
    fromFunctionText: 'Workspace created from function text',
    fromCopyText: 'Workspace restored from graph data',
    workspaceRestored: 'Graph workspace restored',
    functionCount: (count) => '$count functions',
    visibleCount: (count) => '$count visible',
  );
}
