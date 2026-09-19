import 'calculator_report_labels.dart';

/// 中文：**粘贴回执那张文案表**——`CalculatorPasteResult.summaryIn` 在屏幕上说的那几句话
///       （`'已粘贴表达式'`、`'已从计算详情提取表达式'`、`'剪贴板里没有识别到表达式'`…），
///       以及它拼在后面的两截（`'角度模式 DEG'`、`'记忆值 12.5'`）。
///
///       ### 它修的是什么
///
///       `CalculatorPasteResult.summary` 原先是一个 **getter**，里面直接写着七句中文，**没有
///       `BuildContext`**，所以英文界面下用户读到的还是中文——而它是**真的会到屏幕上**的：
///       `calculator_page_sheets.dart` 把它塞进 `SnackBar`。这一族里最后一处上屏的中文就是它。
///
///       判据与文案因此分家：**分支搬到 [CalculatorPasteSummaryHead] 那个枚举**（与
///       `NumericInputIssue` 同一条形状），**字搬到这里**，由调用方递进来。
///
///       ### 为什么这张表住在 `lib/domain/`，以及为什么它有一个 import
///
///       与 `data_fit_copy.dart` 同一条理由：拼这句话的代码在领域层，而**`lib/domain/` 里没有任何
///       一行 import 指向 Flutter**（`grep -rn "^import 'package:flutter" lib/domain/` 无输出，
///       这条不变量刻意维持着）。查语言需要一个 `BuildContext`，领域层拿不到，所以字搬到这里、
///       由界面那侧递进来。表跟着需要它的那一层走，界面那侧只留一个入口
///       （`CalculatorStrings.pasteSummary`）。
///
///       **唯一的 import 是报告标签表**：`'角度模式'` 与 `'记忆值'` 这两个词**不是新抄的一份**，
///       它们就是报告上那两行的标签（[CalculatorReportLabels.angleMode] /
///       [CalculatorReportLabels.memory]）——摘要和报告说的是同一个概念，两处各写一遍就是本项目
///       反复确诊的那类"同一句话两处抄本"。所以这里读产出方那张表，词改了、加一种语言，两处一起动。
///
///       ### 取值方式是必填参数，没有中文兜底
///
///       `CalculatorPasteResult.summaryIn({required CalculatorPasteStrings strings})`——
///       与 `FitResult.summaryIn(copy)`、`TextToolOutput.statusMessage(strings)` 同一条：**漏传的
///       后果是英文界面里蹦出一整屏中文，那在评审里几乎看不出来**，所以宁可编译不过。选哪张表仍然
///       只有一处：`CalculatorStrings.forLanguage` 那个穷尽 `AppLanguage` 的 `switch`。
///
///       **`CalculatorPasteResult.summary`（无参那个 getter）留着，但它只有一个读者**：
///       `test/domain/calculator_paste_result_test.dart` 是**用户未提交的文件**，本轮一个字都不能动，
///       而它逐条钉着那七句中文。屏幕那条路已经**不再走它**（`calculator_page_sheets.dart` 传表），
///       所以它不再决定任何用户看得见的东西——下一位读者请把它当成"被测试钉住的那一份默认写法"，
///       而不是"界面用的那一份"。
///
///       ### 没有 `@immutable`
///
///       那个注解来自 Flutter / `package:meta`，而本文件只 import 报告标签表（同样零 Flutter）。
///       类里全是 `final` 字段，不可变是构造方式保证的，不靠注解。
///
/// English: **the copy table for the paste receipt** — the sentences `CalculatorPasteResult.summaryIn`
///          says on screen (`'已粘贴表达式'`, `'已从计算详情提取表达式'`,
///          `'剪贴板里没有识别到表达式'`, …) plus the two parts it appends (`'角度模式 DEG'`,
///          `'记忆值 12.5'`).
///
///          ### What it fixes
///
///          `CalculatorPasteResult.summary` used to be a **getter** holding seven Chinese sentences
///          and **no `BuildContext`**, so an English interface still showed the user Chinese — and it
///          **really does reach the screen**: `calculator_page_sheets.dart` puts it in a `SnackBar`.
///          It is the last on-screen Chinese of its family.
///
///          So verdict and wording are split: **the branch moves into the
///          [CalculatorPasteSummaryHead] enum** (the same shape as `NumericInputIssue`) and **the
///          words move here**, handed in by the caller.
///
///          ### Why this table lives under `lib/domain/`, and why it has one import
///
///          The same reason `data_fit_copy.dart` gives: the code composing this sentence is in the
///          domain layer, and **nothing under `lib/domain/` imports Flutter**
///          (`grep -rn "^import 'package:flutter" lib/domain/` prints nothing; that invariant is kept
///          deliberately). Looking a language up needs a `BuildContext`, which the domain layer does
///          not have, so the words live here and the interface hands them in. The table follows the
///          layer that needs it, and the interface side keeps one entry point
///          (`CalculatorStrings.pasteSummary`).
///
///          **Its one import is the report label table**: the words `'角度模式'` and `'记忆值'` are
///          **not a fresh copy** — they are the labels of those two report lines
///          ([CalculatorReportLabels.angleMode] / [CalculatorReportLabels.memory]). The receipt and the
///          report name the same concepts, and writing each word twice is exactly the "two copies of
///          one sentence" this project keeps diagnosing. So this file reads the producer's table: change
///          a word or add a language and both ends move together.
///
///          ### The table is a required parameter; there is no Chinese fallback
///
///          `CalculatorPasteResult.summaryIn({required CalculatorPasteStrings strings})` — the same
///          rule as `FitResult.summaryIn(copy)` and `TextToolOutput.statusMessage(strings)`: **a
///          missed pass shows a screenful of Chinese in the English interface, which review can
///          barely see**, so the build breaks instead. Which table still has exactly one chooser:
///          the exhaustive `AppLanguage` switch in `CalculatorStrings.forLanguage`.
///
///          **The no-argument getter `CalculatorPasteResult.summary` stays, but it has one reader**:
///          `test/domain/calculator_paste_result_test.dart` is **the user's uncommitted file**, not one
///          character of it may move this round, and it pins those seven Chinese sentences line by
///          line. The screen road **no longer goes through it** (`calculator_page_sheets.dart` hands
///          the table in), so it decides nothing a user sees — for the next reader it is "the default
///          spelling a test pins", not "the one the interface uses".
///
///          ### No `@immutable`
///
///          That annotation comes from Flutter / `package:meta`, and this file imports only the report
///          label table (also Flutter-free). Every field is `final`; immutability comes from how it is
///          built rather than from an annotation.
class CalculatorPasteStrings {
  const CalculatorPasteStrings({
    required this.restoredAngleAndMemory,
    required this.restoredAngle,
    required this.restoredMemory,
    required this.noExpressionRecognised,
    required this.restoredCurrentValue,
    required this.extractedExpression,
    required this.pastedExpression,
    required this.angleModePart,
    required this.memoryPart,
  });

  /// 中文：剪贴板里只有元数据（角度模式与记忆值都有），没有表达式。
  /// English: the clipboard held metadata only (both an angle mode and a memory value) and no
  ///          expression.
  final String restoredAngleAndMemory;

  /// 中文：只恢复了角度模式。
  /// English: only the angle mode came back.
  final String restoredAngle;

  /// 中文：只恢复了记忆值。
  /// English: only the memory value came back.
  final String restoredMemory;

  /// 中文：剪贴板里什么都没认出来。
  /// English: nothing in the clipboard was recognised.
  final String noExpressionRecognised;

  /// 中文：报告里的当前值被收下了（那一路的规则写在 `CalculatorPasteResult` 的
  ///       `_currentValueExpression` 上）。
  /// English: the report's current value was taken (that road's rules are on
  ///          `CalculatorPasteResult._currentValueExpression`).
  final String restoredCurrentValue;

  /// 中文：报告里的表达式被取出来了。
  /// English: the expression was pulled out of the report.
  final String extractedExpression;

  /// 中文：不是报告，就是一段普通表达式，原样粘上。
  /// English: not a report, just a plain expression, pasted as it is.
  final String pastedExpression;

  /// 中文：`'角度模式 DEG'` 那一截。**`DEG` / `RAD` 是令牌不是词**（两种语言里都是这个写法），
  ///       所以它们由调用方拼好传进来；这里只负责把词与它之间的那一个空格写对。
  ///       词本身从 [CalculatorReportLabels] 取——理由见文件头。
  /// English: the `'角度模式 DEG'` part. **`DEG` / `RAD` are tokens, not words** (spelled the same in
  ///          every language), so the caller composes them and hands them in; this side only owns the
  ///          one space between the word and the token. The word itself comes from
  ///          [CalculatorReportLabels] — see the file head.
  final String Function(String mode) angleModePart;

  /// 中文：`'记忆值 12.5'` 那一截，与 [angleModePart] 同一条规矩：数字由调用方格式化好传进来
  ///       （`formatNumber`），词从 [CalculatorReportLabels] 取。
  /// English: the `'记忆值 12.5'` part, the same rule as [angleModePart]: the caller formats the number
  ///          (`formatNumber`) and hands it in, while the word comes from [CalculatorReportLabels].
  final String Function(String value) memoryPart;

  /// 中文：中文那一份。七句话与拆分前 getter 里的那七条**逐字节相同**，
  ///       `test/domain/calculator_paste_result_test.dart` 逐条钉着它们。
  /// English: the Chinese entry. The seven sentences are **byte-identical** to the seven in the
  ///          getter before the split, and `test/domain/calculator_paste_result_test.dart` pins them
  ///          one by one.
  static final CalculatorPasteStrings zh = CalculatorPasteStrings(
    restoredAngleAndMemory: '已恢复角度模式和记忆值',
    restoredAngle: '已恢复角度模式',
    restoredMemory: '已恢复记忆值',
    noExpressionRecognised: '剪贴板里没有识别到表达式',
    restoredCurrentValue: '已从计算详情恢复当前值',
    extractedExpression: '已从计算详情提取表达式',
    pastedExpression: '已粘贴表达式',
    angleModePart: (mode) => '${CalculatorReportLabels.zh.angleMode} $mode',
    memoryPart: (value) => '${CalculatorReportLabels.zh.memory} $value',
  );

  /// 中文：英文那一份。**七句话是本轮新写的**，与同一族里其它英文提示同一个语气
  ///       （`'Calculation details copied'`、`'Could not read the clipboard'`）：整句、句首大写、
  ///       末尾不加句号。`'calculation details'` 与 `'clipboard'` 两个词用的是同一族里现成的说法。
  /// English: the English entry. **The seven sentences are written this round**, in the tone the rest
  ///          of the family uses (`'Calculation details copied'`, `'Could not read the clipboard'`):
  ///          a whole sentence, capitalised, no full stop. The words "calculation details" and
  ///          "clipboard" are the ones the family already uses.
  static final CalculatorPasteStrings en = CalculatorPasteStrings(
    restoredAngleAndMemory: 'Angle mode and memory value restored',
    restoredAngle: 'Angle mode restored',
    restoredMemory: 'Memory value restored',
    noExpressionRecognised: 'No expression recognised in the clipboard',
    restoredCurrentValue: 'Current value restored from the calculation details',
    extractedExpression: 'Expression extracted from the calculation details',
    pastedExpression: 'Expression pasted',
    angleModePart: (mode) => '${CalculatorReportLabels.en.angleMode} $mode',
    memoryPart: (value) => '${CalculatorReportLabels.en.memory} $value',
  );
}
