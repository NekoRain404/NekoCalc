import 'package:flutter/widgets.dart';

import '../../../domain/usecases/calculator_report_labels.dart';
import '../../../l10n/app_language.dart';

/// 中文：**计算器那几支控制器写的句子。** 状态卡上那两行、复制/笔记/历史正文里的标签、记忆寄存器
///       的拒绝语、引擎错误翻译成的那十二句话、数据集与拟合读数、进制/记法换算读不出来时的两句。
///       它们原先逐条写在 `calculator_controller_*.dart` 几家 mixin 的源码里。
///
///       ### 为什么和 `CalculatorStrings` 分开
///
///       `CalculatorStrings`（同一目录）装的是**界面**上的字：键帽提示、动作面板、面板标题。
///       这一张装的是**控制器合成的句子**，两者产出方不同、读者也不同。分开还有一个硬理由：
///       那张表已经 478 行，把这里四十多条长句并进去会把它推到七百开外——而八百行是硬线。
///       按"谁产出这些话"切表是这一族的既有做法，理由写在 `text_tool_strings.dart` 的文件头上。
///
///       ### 表是哪里来的（**没有构造参数，也没有中文兜底**）
///
///       `CalculatorController` 已经持有 `AppSettings _settings`（`_CalculatorState` 里那个
///       抽象访问器），而 `_settings.languageCode` 就是用户选中的语言代码。所以这一层**顺着已经
///       在手上的设置取表**，与 `relativePercent` 读 `_settings.percentageMode`、角度模式读
///       `_settings.angleMode` 是同一条路，而不是新开一个构造参数去让每个界面多传一次。
///
///       **这不是"静默回落中文"。** [forLanguage] 的 switch 必须穷尽 `AppLanguage`——加一种语言时
///       这里编译不过，而不是悄悄吐中文；`AppLanguage.fromCode` 认不出代码时回落到 `zh`，
///       那是**语言解析**的既有约定（`app_language.dart` 里写着，`app_language_test.dart` 从英文
///       那一侧钉着），不是这张表自己造的第二套兜底。
///
///       语言是**当场生效**的：`app.dart` 的 `onLanguageChanged` 换掉 `_language` 之后，
///       `app_shell.dart` 会用新的 `AppSettings` 重建 `CalculatorPage`，`didUpdateWidget` 把
///       设置交给 `updateSettings`，控制器的下一次 `build` 就取到新表。所以这里用 getter
///       **每次取一次**，不缓存。
///
///       ### 表里只装"给人看的字"
///
///       三类中文字面量**故意不进来**，可执行的那一份在
///       `test/features/controller_sentences_test.dart` 的豁免表里：
///       1. **持久化令牌**。`'数学符号'` 是 `SettingsTokens.expressionDisplaySymbols`，存进
///          `app_settings.expression_display` 的值，不是屏幕上的字；`kEngineBackedLiveExpressionDisplay`
///          现在**直接引用那个常量**，不再抄一遍字面量。
///       2. **开发者日志**。`calculator_controller_evaluation.dart` 里那两条 `debugPrint` 是写给
///          看 logcat 的人（也就是写代码的人）的，用户看不到；日志保持一种语言才好 grep。
///       3. **单位名与参数标签**（结果行的 `result.label`、输入行的 `input.label`、
///          `tool.formula`）——它们来自工具定义，是**数据**，沿参数一路递进来，不进表。
///
///       ⚠️ 这里原先还有第四类：**与结果比较的哨兵** `'等待输入'`（`MathResult.pending.displayText`，
///       `reusableResult` / `continueWithResult` 拿它做判据）。**这一轮拆掉了**：三处判据改读
///       `MathResult.isPlaceholder`，控制器目录里再也找不到那句字面量，豁免表上那一条也随之消失
///       （53 → 52）。**理由被删掉时该说一声**，免得下一页的读者以为它从来只有三条。
///
///       ### 报告那九行是**两端共用**的
///
///       `reportCurrentValue` … `reportSavedAt` 这九格的词来自
///       `lib/domain/usecases/calculator_report_labels.dart`（这里只负责拼成 `'$word: $value'`）：
///       报告上的标签**跟着界面语言走**，而粘贴解析器靠它们认报告，所以两端读同一张表。
///       理由（判据读文案的那一类）与实测写在那个文件头上。
/// English: **the sentences the calculator's controllers write.** The two lines on the status card, the
///          labels inside the copied/noted/history body, the memory register's refusal, the eleven
///          sentences engine errors are translated into, the dataset and fit readings, and the two
///          lines for a base or notation conversion that cannot be answered. They used to be written
///          out line by line in the source of the `calculator_controller_*.dart` mixins.
///
///          ### Why it is separate from `CalculatorStrings`
///
///          `CalculatorStrings` (same directory) holds the **interface's** words: key-cap tooltips,
///          the action sheet, sheet titles. This one holds **sentences the controller composes** — a
///          different producer, a different reader. Separation also has a hard reason: that table is
///          already 478 lines, and folding these forty-odd long sentences into it would push it past
///          seven hundred — with eight hundred a hard ceiling. Splitting tables by *who produces the
///          words* is this family's established practice; the reasoning is on
///          `text_tool_strings.dart`'s head.
///
///          ### Where the table comes from (**no constructor parameter, and no Chinese fallback**)
///
///          `CalculatorController` already holds `AppSettings _settings` (the abstract accessor in
///          `_CalculatorState`), and `_settings.languageCode` is the language the user chose. So this
///          layer **resolves the table from settings it already has** — the same route `relativePercent`
///          takes to `_settings.percentageMode` and the angle mode to `_settings.angleMode` — rather
///          than adding a constructor parameter and making every screen pass it down again.
///
///          **This is not a "silent fall back to Chinese".** [forLanguage]'s switch must exhaust
///          `AppLanguage`, so adding a language breaks the build here rather than quietly emitting
///          Chinese; `AppLanguage.fromCode` falling back to `zh` for an unrecognised code is the
///          existing **language resolution** convention (documented in `app_language.dart` and pinned
///          from the English side by `app_language_test.dart`), not a second fallback invented here.
///
///          The language takes effect **immediately**: after `app.dart`'s `onLanguageChanged` swaps
///          `_language`, `app_shell.dart` rebuilds `CalculatorPage` with the new `AppSettings`,
///          `didUpdateWidget` hands the settings to `updateSettings`, and the controller's next
///          `build` sees the new table. So this is a getter, resolved **per call**, not cached.
///
///          ### This table holds human-facing text only
///
///          Three kinds of Chinese literal are **deliberately absent**; the executable copy is the
///          exemption table in `test/features/controller_sentences_test.dart`:
///          1. **Persisted tokens.** `'数学符号'` is `SettingsTokens.expressionDisplaySymbols`, the value
///             stored in `app_settings.expression_display` — storage format, not on-screen text; and
///             `kEngineBackedLiveExpressionDisplay` now **references that constant** instead of copying
///             the literal again.
///          2. **Developer logs.** The two `debugPrint`s in
///             `calculator_controller_evaluation.dart` are written for whoever reads logcat (i.e.
///             whoever writes the code) and never reach a user; a log is easier to grep in one
///             language.
///          3. **Unit names and parameter labels** (a result row's `result.label`, an input row's
///             `input.label`, `tool.formula`) — they come from the tool definition as **data**, travel
///             in through the parameter list, and never enter a table.
///
///          ⚠️ A fourth kind used to stand here: **the sentinel compared against results**,
///          `'等待输入'` (`MathResult.pending.displayText`, used as a branch condition by
///          `reusableResult` and `continueWithResult`). **This round removed it**: the three judgements
///          read `MathResult.isPlaceholder` now, that literal is nowhere in the controllers directory,
///          and its exemption went with it (53 → 52). **A reason that is removed should say so**, so
///          the next reader does not think this list was ever only three long.
///
///          ### The report's nine lines are **shared by both ends**
///
///          The words in the nine cells `reportCurrentValue` … `reportSavedAt` come from
///          `lib/domain/usecases/calculator_report_labels.dart` (this side only joins them into
///          `'$word: $value'`): a report's labels **follow the interface language**, and the paste
///          parser recognises reports by them, so both ends read one table. The reason (the class of
///          judgement-reading-copy) and the measurements are on that file's head.
@immutable
class CalculatorControllerStrings {
  const CalculatorControllerStrings({
    required this.friendlyMissingParen,
    required this.friendlyExpectedNumber,
    required this.friendlyUnexpectedToken,
    required this.friendlyFunctionNeedsParen,
    required this.friendlyUnknownFunction,
    required this.friendlyFactorialRange,
    required this.friendlyRootDegreeZero,
    required this.friendlyEvenRootNegative,
    required this.friendlyNotFinite,
    required this.friendlyUnitMismatch,
    required this.friendlyRelationNoSolution,
    required this.friendlyGeneric,
    required this.memoryRefusal,
    required this.angleModeDegrees,
    required this.angleModeRadians,
    required this.savedNoteTitle,
    required this.savedNoteDescription,
    required this.reportCurrentValue,
    required this.reportExpression,
    required this.reportResult,
    required this.reportDecimal,
    required this.reportStatus,
    required this.reportAngleMode,
    required this.reportMemory,
    required this.reportError,
    required this.reportSavedAt,
    required this.statusNeedsFix,
    required this.statusCurrentReusable,
    required this.statusResultReusable,
    required this.statusRetryHint,
    required this.statusCurrentValueMessage,
    required this.statusReuseMessage,
    required this.regressionEmpty,
    required this.regressionOddCount,
    required this.regressionTooFewPairs,
    required this.datasetValueRefusal,
    required this.datasetFull,
    required this.fitPairRequirement,
    required this.fitPairFloorsEmpty,
    required this.fitPairFloorsOdd,
    required this.fitPairFloorsReady,
    required this.curveNotAFitFunction,
    required this.curveNotEnoughPairs,
    required this.curveIncomplete,
    required this.curveStale,
    required this.baseReadoutNoValue,
    required this.baseReadoutNoAnswer,
    required this.notationNoValue,
    required this.notationNoAnswer,
    required this.listSeparator,
  });

  // —— 引擎错误翻译成人话（`_friendlyCalculationError`）——
  // 中文：判据是引擎**英文**错误串的 `contains`，那些串留在源码里；这里是翻出来的那十二句。
  // English: the branch conditions are `contains` over the engine's **English** error strings, which
  //          stay in the source; these are the twelve sentences they are turned into.
  final String friendlyMissingParen;
  final String friendlyExpectedNumber;
  final String friendlyUnexpectedToken;
  final String friendlyFunctionNeedsParen;
  final String friendlyUnknownFunction;
  final String friendlyFactorialRange;
  final String friendlyRootDegreeZero;
  final String friendlyEvenRootNegative;
  final String friendlyNotFinite;
  final String friendlyUnitMismatch;

  /// 中文：**引擎把一条关系答成了一个数**——那是一个布尔值，不是答案（见
  ///       `calculator_controller_evaluation.dart` 上的 `_relationCameBackAsTruthValue`）。
  ///
  ///       实测三种输入落在这里，而**它们给的都是 `0`**：实数范围内无解的 `x^2=-1`、
  ///       不成立的 `1=2`。所以这句话要同时说对两种情形——「没有解」对两者都是真的
  ///       （`1=2` 作为方程也确实没有解）。**不写成"x 没有解"**：那是替用户假定了未知数是 `x`。
  ///
  ///       ⚠️ **这句话接住的是一条本来会变成错值的路。** 在这之前，`0` 是一个**有限十进制**，
  ///       采用规则会把它当成**数字零**放上结果行——用户问「x²=−1 的解」，屏幕答 `0`。
  /// English: **the engine answered a relation with a number** — that is a truth value, not an answer
  ///          (see `_relationCameBackAsTruthValue` in `calculator_controller_evaluation.dart`).
  ///
  ///          Three inputs were measured landing here and **all of them print `0`**: `x^2=-1`, which
  ///          has no solution over the reals, and `1=2`, which is false. So the sentence has to be
  ///          right for both — "no solution" is true of each (`1=2` genuinely has no solution as an
  ///          equation). **It does not say "x has no solution"**: that would assume the unknown is `x`.
  ///
  ///          ⚠️ **This sentence intercepts a road that used to produce a wrong value.** Before it, the
  ///          `0` was a **finite decimal**, so the taking rule put it on the result line as **the number
  ///          zero** — the user asks for the roots of x² = −1 and the screen answers `0`.
  final String friendlyRelationNoSolution;

  final String friendlyGeneric;

  // —— 记忆寄存器 ——
  final String memoryRefusal;

  // —— 角度模式标签（`'角度 DEG'` / `'弧度 RAD'`）——
  // 中文：`DEG` / `RAD` 是**令牌**，两种语言里都是这个写法；跟着翻的只有「角度」「弧度」那两个词。
  //       那两个词**不在这个文件里另写一遍**：它们从 `CalculatorReportLabels` 取
  //       （`angleDegreesWord` / `angleRadiansWord`），因为**粘贴解析器也要认它们**——报告里的
  //       角度模式正是靠这两个词（没有令牌那种写法）恢复出来的，两处各抄一份就是判据读文案的
  //       那一类（第七处，理由写在 `calculator_report_labels.dart` 上）。
  // English: `DEG` / `RAD` are **tokens** and read the same in both languages; only the words in front
  //          of them are translated. Those two words are **not written a second time in this file**:
  //          they come from `CalculatorReportLabels` (`angleDegreesWord` / `angleRadiansWord`),
  //          because **the paste parser has to know them too** — a report's angle mode is recovered
  //          through exactly those words (in the token-less spelling), and two copies would be the
  //          judgement-reading-copy class again (the seventh site; the reasons are on
  //          `calculator_report_labels.dart`).
  final String angleModeDegrees;
  final String angleModeRadians;

  // —— 存成笔记 / 历史时的标题与描述 ——
  final String savedNoteTitle;
  final String Function(String angleMode) savedNoteDescription;

  // —— 复制 / 笔记 / 历史正文里的那几行 ——
  final String Function(String value) reportCurrentValue;
  final String Function(String expression) reportExpression;
  final String Function(String result) reportResult;
  final String Function(String decimalText) reportDecimal;
  final String Function(String statusTitle) reportStatus;
  final String Function(String angleMode) reportAngleMode;
  final String Function(String memoryValue) reportMemory;
  final String Function(String message) reportError;
  final String Function(String time) reportSavedAt;

  // —— 常驻状态卡那两行 ——
  final String statusNeedsFix;
  final String statusCurrentReusable;
  final String statusResultReusable;
  final String statusRetryHint;
  final String Function(String result) statusCurrentValueMessage;
  final String Function(String reusable) statusReuseMessage;

  // —— 数据集 ——
  final String Function(int pairs) regressionEmpty;
  final String Function(int valueCount) regressionOddCount;
  final String Function(int pairs, int valueCount) regressionTooFewPairs;
  final String datasetValueRefusal;
  final String Function(int maxValues) datasetFull;

  // —— `STAT` 面板与回归图面板共用的那半句 ——
  final String Function(String function, int pairs) fitPairRequirement;
  final String Function(String floors) fitPairFloorsEmpty;
  final String Function(String floors, int valueCount) fitPairFloorsOdd;
  final String Function(String floors, int valueCount) fitPairFloorsReady;

  // —— 拟合曲线画不出来时的四句 ——
  final String Function(String function) curveNotAFitFunction;
  final String Function(String function, int minimum, int pairs, int values)
      curveNotEnoughPairs;
  final String curveIncomplete;
  final String curveStale;

  // —— 进制读数 / 记法读数 ——
  final String baseReadoutNoValue;
  final String baseReadoutNoAnswer;
  final String notationNoValue;
  final String notationNoAnswer;

  /// 中文：句内列举的分隔符。源码里是 `'、'`（**全角**），所以它**是文案的一部分**，跟着表走；
  ///       英文侧是 `', '`。
  /// English: the separator between items in a sentence. In the source it is `'、'` (**full width**),
  ///          which makes it **part of the copy** and therefore tabled; the English side uses `', '`.
  final String listSeparator;

  static CalculatorControllerStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用——控制器正是这样的调用方
  ///       （它没有 `BuildContext`，语言顺着 `AppSettings` 进来）。两条路径共用这一个 switch，
  ///       不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext` — which is exactly what
  ///          the controller is (it holds no `BuildContext`; the language arrives through
  ///          `AppSettings`). Both routes share this one switch, so they cannot drift apart.
  static CalculatorControllerStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => calculatorControllerZh,
      AppLanguage.en => calculatorControllerEn,
    };
  }

  /// 中文：按持久化语言代码取表（`AppSettings.languageCode` 那个值），控制器走的就是这一条。
  ///       **控制器每一次取都重新解析**，所以用户换完语言、外壳用新设置重建页面之后，
  ///       下一句话就是新语言的。
  /// English: Looks the table up by **persisted language code** (the value in
  ///          `AppSettings.languageCode`); this is the route the controller takes. The controller
  ///          resolves it **per call**, so once the user changes the language and the shell rebuilds
  ///          the page with the new settings, the very next sentence is in the new language.
  static CalculatorControllerStrings forCode(String? code) {
    return forLanguage(AppLanguage.fromCode(code));
  }

  static final CalculatorControllerStrings calculatorControllerZh =
      CalculatorControllerStrings(
    friendlyMissingParen: '缺少右括号',
    friendlyExpectedNumber: '需要输入数字',
    friendlyUnexpectedToken: '存在无法识别的内容',
    friendlyFunctionNeedsParen: '函数需要括号',
    friendlyUnknownFunction: '未知函数',
    friendlyFactorialRange: '阶乘只支持 0 到 170 的整数',
    friendlyRootDegreeZero: '根指数不能为 0',
    friendlyEvenRootNegative: '负数不能开偶次根',
    friendlyNotFinite: '结果不是有限数值',
    friendlyUnitMismatch: '单位不匹配：这两个单位不能互相换算',
    friendlyRelationNoSolution: '这条方程没有解（或这个等式恒不成立）',
    friendlyGeneric: '表达式错误',
    memoryRefusal: '当前值放不进记忆寄存器，寄存器未改动',
    angleModeDegrees: '${CalculatorReportLabels.zh.angleDegreesWord} DEG',
    angleModeRadians: '${CalculatorReportLabels.zh.angleRadiansWord} RAD',
    savedNoteTitle: '计算结果',
    savedNoteDescription: (angleMode) => '由计算器保存，$angleMode',
    // 中文：**九个标签的词从 `CalculatorReportLabels.zh` 取**，这里只负责拼成句子。
    //       粘贴解析器读的是同一张表（`spellingsOf` 取的是每种语言的并集），所以词改了、
    //       或者加了一种语言，产出方与判据一起动——两处各自抄一份词的老路已经拆掉了（判据读文案
    //       的那一类，理由写在 `calculator_report_labels.dart` 的文件头上）。
    //       拼出来的一行**逐字节不变**：`'$word: $value'`。
    // English: **the nine label words come from `CalculatorReportLabels.zh`**; this side only joins
    //          them into sentences. The paste parser reads the same table (`spellingsOf` builds the
    //          union over every language), so a changed word — or a new language — moves the producer
    //          and the judgement together; the old two-copies-of-the-words road is gone (that class of
    //          judgement-reading-copy is explained on `calculator_report_labels.dart`'s head). Each
    //          line is **byte-identical**: `'$word: $value'`.
    reportCurrentValue: (value) =>
        '${CalculatorReportLabels.zh.currentValue}: $value',
    reportExpression: (expression) =>
        '${CalculatorReportLabels.zh.expression}: $expression',
    reportResult: (result) => '${CalculatorReportLabels.zh.result}: $result',
    reportDecimal: (decimalText) =>
        '${CalculatorReportLabels.zh.decimal}: $decimalText',
    reportStatus: (statusTitle) =>
        '${CalculatorReportLabels.zh.status}: $statusTitle',
    reportAngleMode: (angleMode) =>
        '${CalculatorReportLabels.zh.angleMode}: $angleMode',
    reportMemory: (memoryValue) =>
        '${CalculatorReportLabels.zh.memory}: $memoryValue',
    reportError: (message) => '${CalculatorReportLabels.zh.error}: $message',
    reportSavedAt: (time) => '${CalculatorReportLabels.zh.savedAt}: $time',
    statusNeedsFix: '表达式需要修正',
    statusCurrentReusable: '当前值可继续使用',
    statusResultReusable: '结果可继续使用',
    statusRetryHint: '请检查表达式后重试。',
    statusCurrentValueMessage: (result) => '当前值 $result 可复制或作为下一次计算起点。',
    statusReuseMessage: (reusable) =>
        '继续使用会把 $reusable 写回表达式，Ans/last 仍可引用上一次有限结果。',
    regressionEmpty: (pairs) =>
        '两变量函数把数据集读成两行（前一半 X、后一半 Y），现在数据集是空的，先加至少 $pairs 对值',
    regressionOddCount: (valueCount) => '两变量函数把数据集读成两行，需要偶数个值，现在有 $valueCount 个',
    regressionTooFewPairs: (pairs, valueCount) =>
        '两变量函数把数据集读成两行，每行至少 $pairs 个值，现在有 $valueCount 个',
    datasetValueRefusal: '当前值放不进数据集（需要一个有限的十进制结果），数据集未改动',
    datasetFull: (maxValues) => '数据集最多 $maxValues 个值，这一个没有加进去',
    fitPairRequirement: (function, pairs) => '$function 要 $pairs 对',
    fitPairFloorsEmpty: (floors) =>
        '拟合把数据集读成两行（前一半 X、后一半 Y）：$floors；数据集是空的',
    fitPairFloorsOdd: (floors, valueCount) =>
        '拟合把数据集读成两行（需要偶数个值）：$floors；当前有 $valueCount 个',
    fitPairFloorsReady: (floors, valueCount) =>
        '拟合把数据集读成两行：$floors；当前有 $valueCount 个值',
    curveNotAFitFunction: (function) => '`$function` 不是这个应用里的拟合函数，没有曲线可画',
    curveNotEnoughPairs: (function, minimum, pairs, values) =>
        '$function 的曲线没画：它要 $minimum 对值，数据集现在有 $pairs 对（$values 个值）',
    curveIncomplete: '曲线没画：引擎没有给出这条曲线上的全部点，只画了数据集里的点',
    curveStale: '曲线没画：取样期间数据集变过，再按一次这条拟合',
    baseReadoutNoValue: '当前没有可换算的数值结果',
    baseReadoutNoAnswer: '引擎没有给出换算结果',
    notationNoValue: '当前没有可换记法的数值结果',
    notationNoAnswer: '引擎没有给出这一档记法',
    listSeparator: '、',
  );

  static final CalculatorControllerStrings calculatorControllerEn =
      CalculatorControllerStrings(
    friendlyMissingParen: 'Missing closing bracket',
    friendlyExpectedNumber: 'A number is required here',
    friendlyUnexpectedToken: 'The expression holds something unrecognised',
    friendlyFunctionNeedsParen: 'That function needs brackets',
    friendlyUnknownFunction: 'Unknown function',
    friendlyFactorialRange: 'Factorial accepts only integers from 0 to 170',
    friendlyRootDegreeZero: 'A root index cannot be 0',
    friendlyEvenRootNegative: 'An even root of a negative number is not defined',
    friendlyNotFinite: 'The result is not a finite number',
    friendlyUnitMismatch: 'Unit mismatch: these two units cannot convert into each other',
    friendlyRelationNoSolution:
        'This equation has no solution (or the equality never holds)',
    friendlyGeneric: 'Expression error',
    memoryRefusal:
        'The current value does not fit the memory register, so the register is unchanged',
    angleModeDegrees: '${CalculatorReportLabels.en.angleDegreesWord} DEG',
    angleModeRadians: '${CalculatorReportLabels.en.angleRadiansWord} RAD',
    savedNoteTitle: 'Calculation result',
    savedNoteDescription: (angleMode) => 'Saved from the calculator, $angleMode',
    // 中文：与中文那一份同一处来源，理由逐字相同——`CalculatorReportLabels.en`。
    // English: the same single source as the Chinese entry, character for character the same reason —
    //          `CalculatorReportLabels.en`.
    reportCurrentValue: (value) =>
        '${CalculatorReportLabels.en.currentValue}: $value',
    reportExpression: (expression) =>
        '${CalculatorReportLabels.en.expression}: $expression',
    reportResult: (result) => '${CalculatorReportLabels.en.result}: $result',
    reportDecimal: (decimalText) =>
        '${CalculatorReportLabels.en.decimal}: $decimalText',
    reportStatus: (statusTitle) =>
        '${CalculatorReportLabels.en.status}: $statusTitle',
    reportAngleMode: (angleMode) =>
        '${CalculatorReportLabels.en.angleMode}: $angleMode',
    reportMemory: (memoryValue) =>
        '${CalculatorReportLabels.en.memory}: $memoryValue',
    reportError: (message) => '${CalculatorReportLabels.en.error}: $message',
    reportSavedAt: (time) => '${CalculatorReportLabels.en.savedAt}: $time',
    statusNeedsFix: 'The expression needs fixing',
    statusCurrentReusable: 'The current value can be reused',
    statusResultReusable: 'The result can be reused',
    statusRetryHint: 'Check the expression and try again.',
    statusCurrentValueMessage: (result) =>
        'The current value $result can be copied, or used as the starting point of the next calculation.',
    statusReuseMessage: (reusable) =>
        'Continuing writes $reusable back into the expression; Ans/last still refer to the previous finite result.',
    regressionEmpty: (pairs) =>
        'A two-variable function reads the dataset as two rows (first half X, second half Y); the dataset is empty, so add at least $pairs pairs first',
    regressionOddCount: (valueCount) =>
        'A two-variable function reads the dataset as two rows and needs an even number of values; there are $valueCount right now',
    regressionTooFewPairs: (pairs, valueCount) =>
        'A two-variable function reads the dataset as two rows with at least $pairs values each; there are $valueCount right now',
    datasetValueRefusal:
        'The current value does not fit the dataset (it needs a finite decimal result), so the dataset is unchanged',
    datasetFull: (maxValues) =>
        'The dataset holds at most $maxValues values, so this one was not added',
    fitPairRequirement: (function, pairs) => '$function needs $pairs pairs',
    fitPairFloorsEmpty: (floors) =>
        'A fit reads the dataset as two rows (first half X, second half Y): $floors; the dataset is empty',
    fitPairFloorsOdd: (floors, valueCount) =>
        'A fit reads the dataset as two rows (it needs an even number of values): $floors; there are $valueCount right now',
    fitPairFloorsReady: (floors, valueCount) =>
        'A fit reads the dataset as two rows: $floors; there are $valueCount values right now',
    curveNotAFitFunction: (function) =>
        '`$function` is not one of this app\'s fit functions, so there is no curve to draw',
    curveNotEnoughPairs: (function, minimum, pairs, values) =>
        'No curve was drawn for $function: it needs $minimum pairs, and the dataset has $pairs pairs ($values values)',
    curveIncomplete:
        'No curve was drawn: the engine did not return every point on it, so only the dataset\'s points are plotted',
    curveStale:
        'No curve was drawn: the dataset changed while sampling, so pick this fit again',
    baseReadoutNoValue: 'There is no numeric result to convert right now',
    baseReadoutNoAnswer: 'The engine returned no conversion result',
    notationNoValue: 'There is no numeric result to re-spell right now',
    notationNoAnswer: 'The engine returned no spelling for this notation',
    listSeparator: ', ',
  );
}
