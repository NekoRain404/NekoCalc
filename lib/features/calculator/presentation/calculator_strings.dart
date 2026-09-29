import 'package:flutter/widgets.dart';

import '../../../domain/usecases/calculator_paste_strings.dart';
import '../../../l10n/app_language.dart';

/// 中文：计算页的界面文案表，**按功能切分**——一张表、表里并排放所有语言。机制本身（为什么是手写
///       分表而不是 ARB / `gen-l10n`、为什么表是 `static final` 而不是 `const`）与设置页那张表
///       共用一套理由，写在 `settings_strings.dart` 的文件头上，这里不重抄。
///
///       **加一种语言要动几个文件**：这个文件（加一份 `CalculatorStrings` 表 + `of` 里加一个
///       分支，`forLanguage` 的 switch 必须穷尽 `AppLanguage`，由分析器检查）+ `AppLanguage`
///       里加一个枚举值。
///
///       **本表只装"给人看的字"。** 有三类中文字面量**故意不进来**，各自有各自的理由：
///       1. **HiPER 的键面与菜单原文**（`DRG`、`FSE`、`MTRX`、`EXP SI`、`D°M'S`、`Select Result
///          Format`、`Decimal`、`Mixed number`…）。它们是厂商字符串，任何语言的构建里都是这个
///          样子，翻译了反而找不到；而且它们本来就不含汉字，扫描也不会拦住它们。
///       2. **持久化令牌的比较值**（`'数学符号'`）。它住在 `SettingsTokens` 里，是存进库的格式
///          不是屏幕上的字——`calculator_page.dart` 那两处比较直接引用那个常量，而不是把字面量
///          再抄一遍。
///       3. **调试断言的那句话**（`calculator_key_dispatch.dart` 里 `assert` 的第二参数）。它是
///          写给开发者看的，用户永远看不到，形状与 `app_shell.dart:176` 里那句逐字相同。
///
///       `inline_expression_editor.dart` 是**用户未提交的改动**，本轮一个字都没动，它里面的
///       「粘贴计算详情」/「复制计算详情」仍在源码里——这是已知的残留，不是漏翻。
/// English: The calculator page's string table, **split by feature** — one table holding every
///          language side by side. The mechanism itself (why hand-written tables rather than ARB /
///          `gen-l10n`, why the tables are `static final` rather than `const`) shares one set of
///          reasons with the settings table and is written on `settings_strings.dart`'s file head;
///          it is not copied again here.
///
///          **Adding a language touches**: this file (one more `CalculatorStrings` table plus one more
///          branch in `of`, whose switch over `AppLanguage` the analyzer checks for exhaustiveness)
///          and `AppLanguage` (one more enum value).
///
///          **This table holds human-facing text only.** Three kinds of Chinese literal are
///          **deliberately absent**, each for its own reason:
///          1. **HiPER's key faces and menu strings** (`DRG`, `FSE`, `MTRX`, `EXP SI`, `D°M'S`,
///             `Select Result Format`, `Decimal`, `Mixed number`…). They are vendor strings and read
///             the same in every language's build; translating them would make them unfindable, and
///             since they hold no CJK the scan would not flag them anyway.
///          2. **Persisted tokens used as comparison values** (`'数学符号'`). That one lives in
///             `SettingsTokens`: it is storage format, not on-screen text, and the two comparisons in
///             `calculator_page.dart` reference that constant rather than copying the literal again.
///          3. **The debug assertion's sentence** (the second argument of the `assert` in
///             `calculator_key_dispatch.dart`). It is written for developers and never reaches a
///             user; its shape is item-for-item the one at `app_shell.dart:176`.
///
///          `inline_expression_editor.dart` is **the user's uncommitted work**; not one character of
///          it was touched this round, so its 「粘贴计算详情」/「复制计算详情」 remain in the source —
///          a known remainder, not a missed translation.
@immutable
class CalculatorStrings {
  const CalculatorStrings({
    // —— 主屏显示区 ——
    required this.openNavigationTooltip,
    // —— `More...` 动作面板 ——
    required this.actionEditExpression,
    required this.actionBackspace,
    required this.actionUndo,
    required this.actionRedo,
    required this.actionCopyResult,
    required this.actionCopyTex,
    required this.texCopied,
    required this.texCopyFailed,
    required this.texUnavailable,
    required this.actionContinueWith,
    required this.actionSaveNote,
    required this.actionMoveToStart,
    required this.actionMoveToEnd,
    required this.actionSettings,
    required this.cursorLeftTooltip,
    required this.cursorRightTooltip,
    required this.detailsCopied,
    required this.detailsCopyFailed,
    required this.clipboardReadFailed,
    required this.pasteSummary,
    // —— `CONV` 单位面板 ——
    required this.unitSearchHint,
    required this.unitSheetHint,
    required this.noMatchingUnits,
    // —— `X` 变量面板 ——
    required this.variableSheetTitle,
    required this.noStorableValue,
    required this.currentValueReading,
    required this.unassigned,
    required this.insertVariable,
    required this.storeCurrentValue,
    required this.clearBinding,
    // —— 数据集编辑面板 ——
    required this.datasetSheetTitle,
    required this.datasetEmptyReading,
    required this.datasetValuesReading,
    required this.noDatasetValues,
    required this.noAddableValue,
    required this.addCurrentResultReading,
    required this.addCurrentResult,
    required this.clearDataset,
    required this.removeValueTooltip,
    // —— `STAT` 统计面板 ——
    required this.datasetSheetButton,
    required this.datasetCallEmpty,
    required this.datasetCallValues,
    required this.statisticsHint,
    required this.twoVariableRowTitle,
    required this.datasetAsTwoRows,
    required this.fitRowTitle,
    required this.regressionGraphButton,
    // —— 回归图面板 ——
    required this.curveRowTitle,
    required this.curveLoading,
    required this.curveReading,
    // —— `x⇔E` 结果格式菜单 ——
    required this.resultFormatDefaultLabel,
    required this.resultFormatDefaultNote,
    required this.resultFormatPolarNote,
    required this.resultFormatSubtitle,
    required this.resultFormatGapNotFromEngine,
    required this.resultFormatGapTypesettingOff,
    required this.spellingExact,
    required this.spellingFraction,
    required this.spellingMixed,
    required this.spellingDms,
    required this.spellingAuto,
    // —— `MTRX` 第二功能的矩阵与向量菜单 ——
    required this.matrixMenuHint,
    required this.matrixMenuRankNote,
    required this.matrixMenuTraceNote,
    required this.matrixMenuEchelonNote,
    // —— `►DRG` 第二功能的角度单位换算菜单 ——
    required this.angleConvertSourceLabel,
    required this.angleConvertTargetLabel,
    required this.angleConvertPickSource,
    required this.angleConvertNoValue,
    required this.angleConvertHint,
    required this.angleConvertGradNote,
    // —— 多处共用的通用字 ——
    required this.close,
  });

  // —— 主屏显示区 ——
  final String openNavigationTooltip;

  // —— `More...` 动作面板 ——
  final String actionEditExpression;
  final String actionBackspace;
  final String actionUndo;
  final String actionRedo;
  final String actionCopyResult;

  /// 中文：**复制为 LaTeX**。HiPER 的官方 v12 手册里 `latex` 的命中是 **0**——它没有这个能力，
  ///       而本应用从接入引擎起就一直在向引擎要 LaTeX（`MathResult.displayTex` / `fractionTex` /
  ///       `mixedTex`，还落了库），只是**从来没有出口**。这一格就是那个出口。
  /// English: **copy as LaTeX.** HiPER's official v12 manual returns **zero** hits for `latex` — it has
  ///          no such feature, while this app has been asking the engine for LaTeX since the engine
  ///          landed (`MathResult.displayTex` / `fractionTex` / `mixedTex`, persisted to the database as
  ///          well) with **no way out**. This is the way out.
  final String actionCopyTex;
  final String texCopied;
  final String texCopyFailed;

  /// 中文：这一份结果没有 LaTeX（`texFor` 回空串——`decimal` 形态与没有引擎的结果都是）。
  ///       **如实说，不复制一个空串。**
  /// English: this result has no LaTeX (`texFor` returns an empty string — the `decimal` form and any
  ///          result without the engine do). **Say so rather than copying an empty string.**
  final String texUnavailable;
  final String actionContinueWith;
  final String actionSaveNote;
  final String actionMoveToStart;
  final String actionMoveToEnd;
  final String actionSettings;
  final String cursorLeftTooltip;
  final String cursorRightTooltip;
  final String detailsCopied;
  final String detailsCopyFailed;
  final String clipboardReadFailed;

  /// 中文：**粘贴计算详情那条回执的字**（`'已粘贴表达式'`、`'剪贴板里没有识别到表达式'`…）。
  ///       句子是领域层拼的（`CalculatorPasteResult.summaryIn`），词住在那边的表里
  ///       （`lib/domain/usecases/calculator_paste_strings.dart`）——领域层拿不到 `BuildContext`，
  ///       所以这里的**每一格指向同一种语言的那一份**，与 `DataFitStrings.fit` 同一条形状。
  ///       这一格因此不是 `String` 而是那张表本身：粘贴回执有七句话，一格装不下。
  /// English: **the words of the "paste calculation details" receipt** (`'已粘贴表达式'`,
  ///          `'剪贴板里没有识别到表达式'`, …). The sentence is composed in the domain layer
  ///          (`CalculatorPasteResult.summaryIn`) and the words live in that side's table
  ///          (`lib/domain/usecases/calculator_paste_strings.dart`) — the domain layer has no
  ///          `BuildContext`, so **each cell here points at the entry of its own language**, the same
  ///          shape as `DataFitStrings.fit`. That is why this cell is the table itself rather than a
  ///          `String`: a paste receipt is seven sentences and one cell cannot hold them.
  final CalculatorPasteStrings pasteSummary;

  // —— `CONV` 单位面板 ——
  final String unitSearchHint;
  final String unitSheetHint;
  final String noMatchingUnits;

  // —— `X` 变量面板 ——
  final String variableSheetTitle;
  final String noStorableValue;
  final String Function(String value) currentValueReading;
  final String unassigned;
  final String Function(String name) insertVariable;
  final String storeCurrentValue;
  final String clearBinding;

  // —— 数据集编辑面板 ——
  final String datasetSheetTitle;
  final String Function(String callArguments) datasetEmptyReading;
  final String Function(int count) datasetValuesReading;
  final String noDatasetValues;
  final String noAddableValue;
  final String Function(String value) addCurrentResultReading;
  final String addCurrentResult;
  final String clearDataset;
  final String removeValueTooltip;

  // —— `STAT` 统计面板 ——
  final String datasetSheetButton;
  final String Function(String callArguments) datasetCallEmpty;
  final String Function(int count, String values) datasetCallValues;
  final String statisticsHint;
  final String twoVariableRowTitle;
  final String Function(String call) datasetAsTwoRows;
  final String fitRowTitle;
  final String regressionGraphButton;

  // —— 回归图面板 ——
  final String curveRowTitle;
  final String curveLoading;
  final String Function(String function, int samples, int points) curveReading;

  // —— `x⇔E` 结果格式菜单 ——
  final String resultFormatDefaultLabel;
  final String resultFormatDefaultNote;
  final String resultFormatPolarNote;
  final String resultFormatSubtitle;
  final String Function(String spelling) resultFormatGapNotFromEngine;
  final String Function(String spelling) resultFormatGapTypesettingOff;
  final String spellingExact;
  final String spellingFraction;
  final String spellingMixed;
  final String spellingDms;
  final String spellingAuto;

  // —— `MTRX` 第二功能的矩阵与向量菜单 ——
  /// 中文：菜单那一行小字。它要说清三件事：插的是完整调用、实参可以改、**标量不包**——最后一条
  ///       是这张面板唯一拒绝掉的形状，不说用户会以为「先打一个数再按 det」也成。
  /// English: the menu's small line. It has to say three things: a complete call is inserted, the
  ///          arguments are editable, and **scalars are not wrapped** — the last is the one shape this
  ///          sheet refuses, and unsaid the user would expect "type a number, press det" to work.
  final String matrixMenuHint;

  /// 中文：三行灰格各自那一句理由。**数字与调用都来自实测**（宿主 `qalc` 5.12.0，与打包进 AAR 的
  ///       同版本），实测表在 `app_engine_vocabulary_identifiers.dart` 上。三句的形状相同：**引擎
  ///       对那个名字的答复是什么** + **真正该得到的值/名字是什么**——不说清后者，用户只会以为
  ///       引擎算不出来，而不是引擎答的不是那件事。
  /// English: the sentence behind each of the three grey rows. **Every number and call is measured**
  ///          (host `qalc` 5.12.0, the version this AAR bundles); the measurement table is on
  ///          `app_engine_vocabulary_identifiers.dart`. All three have the same shape: **what the engine
  ///          answers for that name** plus **what the right value/name would have been** — without the
  ///          second half the user would think the engine simply cannot do it, rather than that it
  ///          answered something else.
  final String matrixMenuRankNote;
  final String matrixMenuTraceNote;
  final String matrixMenuEchelonNote;

  // —— `►DRG` 第二功能的角度单位换算菜单 ——
  /// 中文：两行灰格与两行小字的文案。判据（哪两种情况下那两行按不动）在 `_AngleConvertSheet`
  ///       与 `_CalculatorAngleConvert` 上，这里只装字。
  /// English: the text of the sheet's two inert states and its small lines. The judgements (the two
  ///          situations that leave those rows unpressable) are on `_AngleConvertSheet` and
  ///          `_CalculatorAngleConvert`; this holds words only.
  final String angleConvertSourceLabel;
  final String angleConvertTargetLabel;
  final String angleConvertPickSource;
  final String angleConvertNoValue;
  final String angleConvertHint;
  final String angleConvertGradNote;

  // —— 多处共用的通用字 ——
  final String close;

  /// 中文：按当前界面语言取表。**switch 必须穷尽 `AppLanguage`**——加语言时这里编译不过，
  ///       而不是静默回落到中文。
  /// English: Picks the table for the active language. The **switch must exhaust `AppLanguage`** so
  ///          adding a language breaks the build here rather than silently falling back to Chinese.
  static CalculatorStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。两条路径共用这一个
  ///       switch，不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext`. Both routes share this
  ///          one switch, so they cannot drift apart.
  static CalculatorStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => calculatorZh,
      AppLanguage.en => calculatorEn,
    };
  }

  static final CalculatorStrings calculatorZh = CalculatorStrings(
    openNavigationTooltip: '打开导航',
    actionEditExpression: '编辑表达式',
    actionBackspace: '退格',
    actionUndo: '撤销',
    actionRedo: '重做',
    actionCopyResult: '复制结果',
    actionCopyTex: '复制为 LaTeX',
    texCopied: '已复制 LaTeX',
    texCopyFailed: '无法复制 LaTeX',
    texUnavailable: '这一份结果没有 LaTeX',
    actionContinueWith: '继续使用',
    actionSaveNote: '保存笔记',
    actionMoveToStart: '移到开头',
    actionMoveToEnd: '移到末尾',
    actionSettings: '设置',
    cursorLeftTooltip: '光标左移（长按按表达式块左移后连续移动）',
    cursorRightTooltip: '光标右移（长按按表达式块右移后连续移动）',
    detailsCopied: '已复制计算详情',
    detailsCopyFailed: '无法复制计算详情',
    clipboardReadFailed: '无法读取剪贴板',
    pasteSummary: CalculatorPasteStrings.zh,
    unitSearchHint: '搜索单位（米、km、mile…）',
    unitSheetHint: '点一个单位插进表达式；两个单位之间点「to」',
    noMatchingUnits: '没有匹配的单位',
    variableSheetTitle: '变量',
    noStorableValue: '当前没有可存入的数值（结果没有十进制形态，或者不是有限数）',
    currentValueReading: (value) => '当前值 $value',
    unassigned: '未赋值',
    insertVariable: (name) => '插入 $name',
    storeCurrentValue: '存入当前值',
    clearBinding: '清除',
    datasetSheetTitle: '统计数据集',
    datasetEmptyReading: (callArguments) => '数据集是空的，插入的调用用起手数据 $callArguments。',
    datasetValuesReading: (count) => '数据集 $count 个值；插入的调用用它们，按现在的顺序。',
    noDatasetValues: '还没有值',
    noAddableValue: '当前没有可加入的数值（结果没有十进制形态，或者不是有限数）',
    addCurrentResultReading: (value) => '加入当前结果 $value',
    addCurrentResult: '加入当前结果',
    clearDataset: '清空',
    removeValueTooltip: '去掉这个值',
    datasetSheetButton: '数据集…',
    datasetCallEmpty: (callArguments) => '数据集空，插入起手数据 $callArguments',
    datasetCallValues: (count, values) => '数据集 $count 个：$values',
    statisticsHint: '插入的是完整调用；实参来自数据集，数据集为空时用起手数据，'
        '插入之后那串数仍可在内联编辑器里改（逗号可以打）。'
        'stdev/var 按样本（n−1）算；pearson/covar 按总体（n）算。',
    twoVariableRowTitle: '两变量',
    datasetAsTwoRows: (call) => '数据集读成两行：$call',
    fitRowTitle: '拟合',
    regressionGraphButton: '回归图…',
    curveRowTitle: '曲线',
    curveLoading: '正在向引擎要这条曲线的点…',
    curveReading: (function, samples, points) => '$function 的曲线：'
        '引擎在 $samples 个取样位置上给了值；'
        '数据集里 $points 个点也在图上',
    resultFormatDefaultLabel: '默认',
    resultFormatDefaultNote: '本应用自己的一行（精确写法 + ≈ 十进制读数）；HiPER 的菜单里没有这一项',
    resultFormatPolarNote: '本应用没有极坐标印法：引擎那一份是求值选项（会改值），而且印出来的是 '
        'r(cos θ + i sin θ)，不是 HiPER 那一格 r∠θ',
    resultFormatSubtitle: '结果行的写法。灰掉的项按不下去：不是这一份结果没有这一格，就是本应用今天印不出这一格',
    resultFormatGapNotFromEngine: (spelling) =>
        '本应用没有它的$spelling：这一份结果不是引擎算的，而这一格只有引擎印得出来',
    resultFormatGapTypesettingOff: (spelling) =>
        '本应用今天印不出它的$spelling：表达式显示设成了「数学表达式」，'
        '结果行不排任何写法、边打边算也不问引擎',
    spellingExact: '精确写法',
    spellingFraction: '分数写法',
    spellingMixed: '带分数写法',
    spellingDms: '度分秒写法',
    spellingAuto: '写法',
    matrixMenuHint: '插的是完整调用：每项都围着 matrix(2,2,1,2,3,4) 转，那串数仍可在内联编辑器里改'
        '（逗号可以打）。两个矩阵之间用 × 相乘、＋ 相加。标量不包——det(5) 引擎给 5、inv(5) 给 0.2，'
        '都是看不出错的答案，所以这几项只围着矩阵转。',
    matrixMenuRankNote: '引擎里有 rank 这个函数，可用本应用的矩阵写法它把矩阵原样还回来'
        '（实测 rank(matrix(2,2,1,2,3,4)) = [1  2; 3  4]，而秩是 2）——形状对、意思错，所以本应用不做它',
    matrixMenuTraceNote: '引擎里根本没有 trace 这个名字（实测 getFunction 返回空），它把词拆成了符号，'
        '印出来是一个带单位的量（实测 trace(matrix(2,2,1,2,3,4)) = [(512.0295827 GGy·m·s·rad)  …]），'
        '而迹是 5',
    matrixMenuEchelonNote: '引擎里根本没有 echelon 这个名字（行阶梯形在引擎里叫 rref），它把词拆成了符号，'
        '印出来是一个带单位的量（实测 echelon(matrix(2,2,1,2,3,4)) = [(0.1486441637n B·m⁴)  …]）',
    angleConvertSourceLabel: '源单位',
    angleConvertTargetLabel: '目标单位',
    angleConvertPickSource: '先选源单位：那个数是什么单位的，只有你知道（应用不替它猜）',
    angleConvertNoValue: '当前没有可换算的数值结果（结果没有十进制形态，或者表达式出错了）',
    angleConvertHint: '点目标单位就把当前值换成一条完整换算：<值> <源单位> to <目标单位>，'
        '源单位永远写出来——只写目标单位时，源单位就成了当前角度模式（同一个数在 DEG 与 RAD 下'
        '给出两个不同答案，实测）。整条表达式会被换掉，一次撤销可以拿回来。',
    angleConvertGradNote: 'grad 在引擎里不是一个角（实测 1 grad = 1357.168026 s·rad），'
        '90 grad to deg 印出来是 81 d·°——值对、单位坏了。百分度的干净拼法是 gon'
        '（实测 1 gon to deg = 0.9°、90 deg to gon = 100 gra）',
    close: '关闭',
  );

  static final CalculatorStrings calculatorEn = CalculatorStrings(
    openNavigationTooltip: 'Open navigation',
    actionEditExpression: 'Edit expression',
    actionBackspace: 'Backspace',
    actionUndo: 'Undo',
    actionRedo: 'Redo',
    actionCopyResult: 'Copy result',
    actionCopyTex: 'Copy as LaTeX',
    texCopied: 'LaTeX copied',
    texCopyFailed: 'Could not copy the LaTeX',
    texUnavailable: 'This result has no LaTeX',
    actionContinueWith: 'Continue with result',
    actionSaveNote: 'Save note',
    actionMoveToStart: 'Move to start',
    actionMoveToEnd: 'Move to end',
    actionSettings: 'Settings',
    cursorLeftTooltip:
        'Move cursor left (hold: moves one expression block, then keeps moving)',
    cursorRightTooltip:
        'Move cursor right (hold: moves one expression block, then keeps moving)',
    detailsCopied: 'Calculation details copied',
    detailsCopyFailed: 'Could not copy the calculation details',
    clipboardReadFailed: 'Could not read the clipboard',
    pasteSummary: CalculatorPasteStrings.en,
    unitSearchHint: 'Search units (m, km, mile…)',
    unitSheetHint: 'Tap a unit to insert it; tap "to" between the two units',
    noMatchingUnits: 'No matching units',
    variableSheetTitle: 'Variables',
    noStorableValue:
        'Nothing storable right now (the result has no decimal form, or is not finite)',
    currentValueReading: (value) => 'Current value $value',
    unassigned: 'Unassigned',
    insertVariable: (name) => 'Insert $name',
    storeCurrentValue: 'Store current value',
    clearBinding: 'Clear',
    datasetSheetTitle: 'Statistics dataset',
    datasetEmptyReading: (callArguments) =>
        'The dataset is empty; the inserted call uses the starting sample '
        '$callArguments.',
    datasetValuesReading: (count) =>
        'The dataset holds $count values; the inserted call uses them in this '
        'order.',
    noDatasetValues: 'No values yet',
    noAddableValue:
        'Nothing addable right now (the result has no decimal form, or is not finite)',
    addCurrentResultReading: (value) => 'Add the current result $value',
    addCurrentResult: 'Add current result',
    clearDataset: 'Clear all',
    removeValueTooltip: 'Remove this value',
    datasetSheetButton: 'Dataset…',
    datasetCallEmpty: (callArguments) =>
        'Dataset empty; inserting the starting sample $callArguments',
    datasetCallValues: (count, values) => 'Dataset: $count values, $values',
    statisticsHint:
        'A complete call is inserted; its arguments come from the dataset, '
        'falling back to the starting sample while it is empty, and the run of numbers '
        'stays editable in the inline editor afterwards (commas can be typed there). '
        'stdev/var use the sample convention (n−1); pearson/covar use the population '
        'convention (n).',
    twoVariableRowTitle: 'Two variables',
    datasetAsTwoRows: (call) => 'Dataset read as two rows: $call',
    fitRowTitle: 'Fits',
    regressionGraphButton: 'Regression graph…',
    curveRowTitle: 'Curve',
    curveLoading: 'Asking the engine for points on this curve…',
    curveReading: (function, samples, points) =>
        'Curve of $function: the engine gave a value at $samples sampled positions; '
        'the $points points in the dataset are on the figure too',
    resultFormatDefaultLabel: 'Default',
    resultFormatDefaultNote:
        "This app's own row (exact spelling + ≈ decimal reading); HiPER's menu has no "
        'such entry',
    resultFormatPolarNote:
        "This app has no polar spelling: the engine's is an evaluation option (it "
        'changes the value), and what it prints is r(cos θ + i sin θ), not HiPER\'s '
        'r∠θ cell',
    resultFormatSubtitle:
        'How the result line is written. A greyed entry cannot be '
        'pressed: either this result has no such cell, or this app cannot print that '
        'cell today',
    resultFormatGapNotFromEngine: (spelling) =>
        'This app does not have its $spelling: this result did not come from the '
        'engine, and only the engine can print that cell',
    resultFormatGapTypesettingOff: (spelling) =>
        'This app cannot print its $spelling today: expression display is set to '
        '"Math expression", so the result line typesets nothing and as-you-type does '
        'not ask the engine',
    spellingExact: 'exact spelling',
    spellingFraction: 'fraction spelling',
    spellingMixed: 'mixed-number spelling',
    spellingDms: 'degrees-minutes-seconds spelling',
    spellingAuto: 'spelling',
    matrixMenuHint:
        'A complete call is inserted: every entry wraps matrix(2,2,1,2,3,4) and those '
        'numbers stay editable in the inline editor (commas do type). Multiply two matrices with × '
        'and add them with ＋. Scalars are not wrapped — det(5) gives 5 and inv(5) gives 0.2, answers '
        'that look fine, which is why these entries only wrap matrices.',
    matrixMenuRankNote:
        'The engine really does have a rank function, yet with this app\'s matrix '
        'spelling it hands the matrix straight back (measured: rank(matrix(2,2,1,2,3,4)) = '
        '[1  2; 3  4], where the rank is 2) — right shape, wrong meaning, so this app does not build it',
    matrixMenuTraceNote:
        'The engine has no trace at all (measured: getFunction returns nothing), so '
        'it takes the word apart into symbols and prints a quantity carrying units (measured: '
        'trace(matrix(2,2,1,2,3,4)) = [(512.0295827 GGy·m·s·rad)  …]), where the trace is 5',
    matrixMenuEchelonNote:
        'The engine has no echelon at all (row echelon form is called rref there), '
        'so it takes the word apart into symbols and prints a quantity carrying units (measured: '
        'echelon(matrix(2,2,1,2,3,4)) = [(0.1486441637n B·m⁴)  …])',
    angleConvertSourceLabel: 'Source unit',
    angleConvertTargetLabel: 'Target unit',
    angleConvertPickSource:
        'Pick the source unit first: only you know what unit that number is in (this app '
        'will not guess it)',
    angleConvertNoValue:
        'Nothing convertible right now (the result has no decimal form, or the expression '
        'is in an error state)',
    angleConvertHint:
        'Tap a target unit and the current value becomes one complete conversion: '
        '<value> <source unit> to <target unit>, with the source unit always written out — naming '
        'only the target makes the source the current angle mode (measured: the same number gives two '
        'different answers under DEG and RAD). The whole expression is replaced; one undo brings it '
        'back.',
    angleConvertGradNote:
        'grad is not an angle in the engine (measured: 1 grad = 1357.168026 s·rad) and '
        '90 grad to deg prints 81 d·° — right value, corrupted unit. The gradian\'s clean spelling is '
        'gon (measured: 1 gon to deg = 0.9°, 90 deg to gon = 100 gra)',
    close: 'Close',
  );
}
