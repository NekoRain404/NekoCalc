import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';
import 'numeric_input_strings.dart';

// 中文：**转出去。** 拿到这张表的人几乎总要同时拿到 [NumericInputStrings]（`numericInput` 那个字段
//       就要求它），所以这里转一次，免得每个调用点各写一行 import。与
//       `text_tool_strings.dart` 转出它那六张兄弟表是同一条做法。
// English: **re-exported.** Whoever takes this table almost always needs [NumericInputStrings] too (the
//          `numericInput` field demands it), so it is re-exported here rather than each call site
//          carrying an import line of its own — the same practice as `text_tool_strings.dart`
//          re-exporting its six sibling tables.
export 'numeric_input_strings.dart';

/// 中文：**工程工具详情页那几个控制器写的句子。** 状态卡上那一行「N 个结果可复用，主结果 …」、
///       结果需要检查时的判词、复制出去的正文里的标签、粘贴/应用参数的摘要、输入框下的错误行、
///       保存成笔记时的标题与描述——全在这里。它们原先逐条写在
///       `tool_detail_controller.dart` / `tool_detail_models.dart` 的源码里。
///
///       ### 这张表为什么住在 `features/`，不在控制器旁边
///
///       **方向是量过的，不是猜的。** `lib/application/` **本来就 import `lib/features/`**：
///       `text_tool_models.dart:3` 与 `text_tool_controller.dart:7` 两处
///       `import '../../features/tools/presentation/text_tool_strings.dart';`，就是同一族文本工具
///       的表。它**也本来就 import Flutter**：`calculator_controller.dart:8`、
///       `tool_detail_controller.dart:4`、`notes_controller.dart:3` 三处
///       `import 'package:flutter/foundation.dart';`（`ChangeNotifier` 就是从这里来的）。
///       所以 `application → features` 不是这一轮新开的口子，是这条层里已经在用的路。
///
///       拟合那一轮把表放进 `lib/domain/usecases/`，是因为**领域层**两条都不成立：那里
///       `grep -rn "^import 'package:flutter" lib/domain/` 无输出，且那层刻意维持"能在纯 Dart 测试
///       里跑"。**这条约束到不了 `lib/application/`**——上面三行 `foundation` 就是反证，任何
///       import 这个控制器的测试都已经把 Flutter 拖进来了（`test/domain/` 里所有碰控制器的文件
///       都 `import 'package:flutter_test/flutter_test.dart'`）。
///
///       ### 表是必填的，没有中文兜底
///
///       `ToolDetailController` 的构造函数**多了一个必填参数 `strings`**（形状照
///       `text_tool_models.dart` 的 `statusTitle(TextToolOutputStrings strings)` /
///       `statusMessage(TextToolOutputStrings strings)` 那两条）。一个忘了递表的新调用点**编译
///       不过**，而不是在英文界面上悄悄吐出一句中文。构造点只有三处：详情页一处、测试里的若干处。
///
///       ### 表里只装"给人看的字"
///
///       三类中文字面量**故意不进来**，各有各的理由，可执行的那一份在
///       `test/features/controller_sentences_test.dart` 的豁免表里（这里原先有四类，**第三类
///       "与结果比较的哨兵"本轮拆掉了**：三处判据改读 `MathResult.isPlaceholder`，
///       `'等待输入'` 在控制器目录里一个字符串字面量都不剩，见下面那条 ⚠️）：
///       1. **输入文法**。`tool_detail_input_parsing.dart` 里那 21 条
///          （`'纳秒' '微秒' '毫秒' '秒' '分钟' '小时' '时' '天' '周' '星期' '分'` 与
///          `'直径' '直徑' '线径' '線徑' '半径' '半徑' '股' '根' '芯' '：'`）是**用户可能敲进来的
///          中文单位写法**，`replaceAll` 拿它们当查表键。翻了它们，中文输入就再也读不懂了。
///          （该文件用宽字符尺子量到 27 条字面量，其中 6 条是文案——三条
///          `'单位 X 与 Y 不匹配'` 与 `'请输入数值' '结果不是有限数值' '无法解析数值或表达式'`，
///          它们都进了表；**21 是 27 减 6**，不是估计。）
///       2. **粘贴解析的 JSON 键**。`tool_detail_paste_parser.dart` 里的 `'参数' '输入' '输入参数'
///          '读数' '值' '单位'` 与那些正则同理：它们匹配的是**粘贴文本里的中文标签**。
///       3. **开发者日志**。`calculator_controller_evaluation.dart` 那两条 `debugPrint` 是写给
///          看 logcat 的人（也就是写代码的人）的，用户看不到；日志保持一种语言才好 grep。
///       ⚠️ 上面那条"第三类"里的哨兵**本轮拆掉了**（`'等待输入'` 是
///       `MathResult.pending.displayText`，`reusableResult` / `canContinueWithResult` /
///       `continueWithResult` 原先拿它做判据）。三处现在读 `MathResult.isPlaceholder`，控制器目录里
///       那条字面量一条不剩，豁免表上那一格也随之消失（53 → 52）。**理由被删掉时该说一声。**
/// English: **the sentences the engineering tool detail screen's controllers write.** The status
///          card's line ("N results are reusable; primary result …"), the verdict when results need
///          checking, the labels inside the copied body, the paste/apply summaries, the error line
///          under an input, the note's title and description — all of it is here. It used to be
///          written out line by line in the source of `tool_detail_controller.dart` and
///          `tool_detail_models.dart`.
///
///          ### Why this table lives under `features/` and not beside the controller
///
///          **The direction was measured, not guessed.** `lib/application/` **already imports
///          `lib/features/`**: `text_tool_models.dart:3` and `text_tool_controller.dart:7` both
///          `import '../../features/tools/presentation/text_tool_strings.dart';` — the string table of
///          the text-tool family. It **also already imports Flutter**: `calculator_controller.dart:8`,
///          `tool_detail_controller.dart:4` and `notes_controller.dart:3` all
///          `import 'package:flutter/foundation.dart';` (that is where `ChangeNotifier` comes from).
///          So `application → features` is not a door opened this round; it is a route this layer
///          already uses.
///
///          The fit round put its table in `lib/domain/usecases/` because **the domain layer** fails
///          both halves of that test: there `grep -rn "^import 'package:flutter" lib/domain/` prints
///          nothing, and that layer deliberately stays runnable in plain Dart tests. **That constraint
///          does not reach `lib/application/`** — the three `foundation` lines above are the
///          counter-evidence, and every test that imports one of these controllers has already pulled
///          Flutter in (every file under `test/domain/` that touches a controller
///          `import 'package:flutter_test/flutter_test.dart'`).
///
///          ### The table is required, with no Chinese fallback
///
///          `ToolDetailController`'s constructor **gained one required parameter, `strings`** (the
///          shape follows `text_tool_models.dart`'s `statusTitle(TextToolOutputStrings strings)` /
///          `statusMessage(TextToolOutputStrings strings)`). A new call site that forgets it **fails
///          to compile** rather than quietly emitting a Chinese sentence into an English interface.
///          There are only three kinds of construction site: one on the detail screen, several in
///          tests.
///
///          ### This table holds human-facing text only
///
///          Three kinds of Chinese literal are **deliberately absent**, each for its own reason; the
///          executable copy is the exemption table in
///          `test/features/controller_sentences_test.dart` (there used to be four; see the ⚠️ below):
///          1. **Input grammar.** The 27 literals in `tool_detail_input_parsing.dart`
///             (`'纳秒' '微秒' '毫秒' '秒' '分钟' '小时' '时' '天' '周' '星期' '分'` and
///             `'直径' '直徑' '线径' '線徑' '半径' '半徑' '股' '根' '芯' '：'`) are **the Chinese unit
///             spellings the user may type**, and `replaceAll` uses them as lookup keys. Translating
///             them would stop Chinese input being read at all.
///          2. **JSON keys of the paste parser.** The `'参数' '输入' '输入参数' '读数' '值' '单位'` in
///             `tool_detail_paste_parser.dart`, and its regular expressions, for the same reason: they
///             match **Chinese labels inside pasted text**.
///          3. **Developer logs.** The two `debugPrint`s in `calculator_controller_evaluation.dart`
///             are written for whoever reads logcat (i.e. whoever writes the code) and never reach a
///             user; a log is easier to grep in one language.
///
///          ⚠️ The sentinel that used to stand as item 3 **was removed this round** (`'等待输入'` is
///          `MathResult.pending.displayText`, and `reusableResult` / `canContinueWithResult` /
///          `continueWithResult` used to branch on it). The three judgements read
///          `MathResult.isPlaceholder` now, not one such literal is left in the controllers directory,
///          and that exemption disappeared with it (53 → 52). **A reason that is removed should say
///          so.**
@immutable
class ToolDetailStrings {
  const ToolDetailStrings({
    required this.numericInput,
    required this.invalidInput,
    required this.noInputsNeeded,
    required this.noResults,
    required this.noComputedResults,
    required this.issueOverflowSuffix,
    required this.resultIssuesNeedCheck,
    required this.resultsReusable,
    required this.moreIssuesNeedCheck,
    required this.noCheckNotes,
    required this.copyInputsLabel,
    required this.copyResultsLabel,
    required this.copyResultStatusLabel,
    required this.copyChecksLabel,
    required this.copyFormula,
    required this.inputNotFilled,
    required this.inputErrorLine,
    required this.pasteUnitAmbiguous,
    required this.pasteNumbersNoMatch,
    required this.pasteNoInputsRecognised,
    required this.pasteApplied,
    required this.pasteDuplicate,
    required this.pasteAmbiguousSkipped,
    required this.pasteIgnored,
    required this.applyNothing,
    required this.applyApplied,
    required this.applyAllNeedFix,
    required this.applyNeedFix,
    required this.listSeparator,
    required this.sentenceSeparator,
  });

  /// 中文：数值解析失败那四句，两家共用。理由见 `numeric_input_strings.dart` 的文件头。
  /// English: the four sentences for a failed numeric parse, shared by two families; see
  ///          `numeric_input_strings.dart`'s head.
  final NumericInputStrings numericInput;

  // —— 输入框 ——
  /// 中文：`parsed.issue == null` 之外的兜底（`parsed.error ?? '输入无效'` 里那半边）。
  /// English: the fallback beside `parsed.issue == null` (the other half of the old
  ///          `parsed.error ?? '输入无效'`).
  final String invalidInput;

  // —— 复制出去的三段正文 ——
  final String noInputsNeeded;
  final String noResults;
  final String noComputedResults;
  final String copyInputsLabel;
  final String copyResultsLabel;
  final String copyResultStatusLabel;
  final String copyChecksLabel;
  final String Function(String formula) copyFormula;
  final String Function(String label) inputNotFilled;

  /// 中文：输入框下那一行。三个槽是**数据**：标签来自工具定义，单位来自参数，说的话来自
  ///       [NumericInputStrings]。
  /// English: the line under an input. All three slots are **data**: the label comes from the tool
  ///          definition, the unit from the parameter list, the message from [NumericInputStrings].
  final String Function(String label, String unit, String message) inputErrorLine;

  // —— 状态卡 ——
  final String Function(int count) issueOverflowSuffix;
  final String Function(String visible, String suffix) resultIssuesNeedCheck;
  final String Function(int count, String primary) resultsReusable;
  final String Function(String visible, int remaining) moreIssuesNeedCheck;
  final String noCheckNotes;

  // —— 粘贴 / 应用参数的摘要 ——
  final String pasteUnitAmbiguous;
  final String pasteNumbersNoMatch;
  final String pasteNoInputsRecognised;
  final String Function(int count) pasteApplied;
  final String Function(String labels) pasteDuplicate;
  final String Function(int count) pasteAmbiguousSkipped;
  final String Function(int count) pasteIgnored;
  final String applyNothing;
  final String Function(int count) applyApplied;
  final String Function(int count) applyAllNeedFix;
  final String Function(String labels) applyNeedFix;

  /// 中文：两份清单之间的分隔，以及摘要里两句之间的分隔。它们在源码里是 `'、'` 与 `'，'`
  ///       （**全角**），所以它们**是文案的一部分**，跟着表走；英文侧是 `', '`。
  /// English: the separator between list items and the separator between two sentences in a summary.
  ///          In the source they are `'、'` and `'，'` (**full width**), which makes them **part of the
  ///          copy** and therefore tabled; the English side uses `', '`.
  final String listSeparator;
  final String sentenceSeparator;

  static ToolDetailStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。两条路径共用这一个
  ///       switch，不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext`. Both routes share this
  ///          one switch, so they cannot drift apart.
  static ToolDetailStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => toolDetailZh,
      AppLanguage.en => toolDetailEn,
    };
  }

  /// 中文：按**持久化语言代码**取表（`AppSettings.languageCode` 那个值）。存在的理由只有一条：
  ///       详情页在 `initState` 里造控制器，而那一刻**还不许查 `BuildContext`**
  ///       （`AppLanguageScope.maybeOf` 走的是 `dependOnInheritedWidgetOfExactType`，
  ///       Flutter 在 `initState` 里调用它会直接抛）。所以构造时按设置里的代码取一张，
  ///       随后由 `didChangeDependencies` 用作用域里**当场生效**的那张覆盖掉
  ///       （`app.dart` 的 `onLanguageChanged` 只换内存里的 `_language`，不重载设置记录，
  ///       所以 `widget.settings` 在那一小段时间里是旧的——只看设置就会漏掉"设置页还开着、
  ///       底下的详情页已经该换语言了"这一种）。
  /// English: Looks the table up by **persisted language code** (the value in
  ///          `AppSettings.languageCode`). It exists for exactly one reason: the detail screen builds
  ///          its controller in `initState`, and a `BuildContext` **may not be queried there**
  ///          (`AppLanguageScope.maybeOf` goes through `dependOnInheritedWidgetOfExactType`, which
  ///          Flutter throws on inside `initState`). So construction takes the code from settings and
  ///          `didChangeDependencies` then overwrites it with the scope's **immediately effective**
  ///          table (`app.dart`'s `onLanguageChanged` swaps only the in-memory `_language` without
  ///          reloading the settings record, so `widget.settings` is stale for that window — watching
  ///          settings alone would miss "the settings page is still open but the detail screen
  ///          underneath should already have changed language").
  static ToolDetailStrings forCode(String? code) {
    return forLanguage(AppLanguage.fromCode(code));
  }

  static final ToolDetailStrings toolDetailZh = ToolDetailStrings(
    numericInput: NumericInputStrings.numericInputZh,
    invalidInput: '输入无效',
    noInputsNeeded: '无需输入参数',
    noResults: '暂无结果',
    noComputedResults: '暂无计算结果',
    issueOverflowSuffix: (count) => ' 等 $count 项',
    resultIssuesNeedCheck: (visible, suffix) =>
        '$visible$suffix 需要检查，请结合输入参数和校核提示确认。',
    resultsReusable: (count, primary) => '$count 个结果可复用，主结果 $primary',
    moreIssuesNeedCheck: (visible, remaining) =>
        '$visible\n另有 $remaining 项结果需要检查',
    noCheckNotes: '暂无校核提示',
    copyInputsLabel: '输入参数:',
    copyResultsLabel: '计算结果:',
    copyResultStatusLabel: '结果状态:',
    copyChecksLabel: '校核:',
    copyFormula: (formula) => '公式: $formula',
    inputNotFilled: (label) => '$label: 未填写',
    inputErrorLine: (label, unit, message) =>
        unit.isEmpty ? '$label: $message' : '$label（$unit）: $message',
    pasteUnitAmbiguous: '剪贴板里的参数单位有歧义，未自动填入',
    pasteNumbersNoMatch: '剪贴板里有数字，但没有匹配到本工具参数',
    pasteNoInputsRecognised: '剪贴板里没有识别到本工具的参数',
    pasteApplied: (count) => '已粘贴 $count 个参数',
    pasteDuplicate: (labels) => '重复字段已取最后值：$labels',
    pasteAmbiguousSkipped: (count) => '跳过 $count 条歧义值',
    pasteIgnored: (count) => '忽略 $count 条未匹配值',
    applyNothing: '没有可应用的参数',
    applyApplied: (count) => '已应用 $count 个参数',
    applyAllNeedFix: (count) => '识别到 $count 个参数但都需要修正',
    applyNeedFix: (labels) => '需修正：$labels',
    listSeparator: '、',
    sentenceSeparator: '，',
  );

  static final ToolDetailStrings toolDetailEn = ToolDetailStrings(
    numericInput: NumericInputStrings.numericInputEn,
    invalidInput: 'Invalid input',
    noInputsNeeded: 'No input parameters needed',
    noResults: 'No result yet',
    noComputedResults: 'No computed result yet',
    issueOverflowSuffix: (count) => ' and $count more',
    resultIssuesNeedCheck: (visible, suffix) =>
        '$visible$suffix need checking; confirm them against the inputs and the check notes.',
    resultsReusable: (count, primary) =>
        '$count results are reusable; primary result $primary',
    moreIssuesNeedCheck: (visible, remaining) =>
        '$visible\n$remaining more results need checking',
    noCheckNotes: 'No check notes yet',
    copyInputsLabel: 'Inputs:',
    copyResultsLabel: 'Results:',
    copyResultStatusLabel: 'Result status:',
    copyChecksLabel: 'Checks:',
    copyFormula: (formula) => 'Formula: $formula',
    inputNotFilled: (label) => '$label: not filled in',
    inputErrorLine: (label, unit, message) =>
        unit.isEmpty ? '$label: $message' : '$label ($unit): $message',
    pasteUnitAmbiguous:
        'The units in the clipboard are ambiguous, so nothing was filled in automatically',
    pasteNumbersNoMatch:
        'The clipboard holds numbers, but none of them matched this tool\'s inputs',
    pasteNoInputsRecognised:
        'No inputs for this tool were recognised in the clipboard',
    pasteApplied: (count) => 'Pasted $count inputs',
    // 中文：这四条**是尾巴，不是句子**——它们只跟在 `pasteApplied` / `applyApplied` 后面，
    //       所以英文侧写小写，逗号接上去读得通。中文侧本来就是这么用的（`，跳过 2 条歧义值`）。
    // English: these four are **tails, not sentences** — they only ever follow `pasteApplied` /
    //          `applyApplied`, so the English side is lower case and reads correctly after a comma.
    //          That is how the Chinese side already used them (`，跳过 2 条歧义值`).
    pasteDuplicate: (labels) => 'duplicate fields kept the last value: $labels',
    pasteAmbiguousSkipped: (count) => 'skipped $count ambiguous values',
    pasteIgnored: (count) => 'ignored $count unmatched values',
    applyNothing: 'No inputs to apply',
    applyApplied: (count) => 'Applied $count inputs',
    applyAllNeedFix: (count) =>
        'Found $count inputs, but every one of them needs fixing',
    applyNeedFix: (labels) => 'needs fixing: $labels',
    listSeparator: ', ',
    sentenceSeparator: ', ',
  );
}
