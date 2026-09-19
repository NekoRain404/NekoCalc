import '../../core/math/result_text_rules.dart';
import 'dart:convert';

import '../../core/math/math_result.dart';
import '../../core/utils/number_formatter.dart';
import 'calculator_paste_strings.dart';
import 'calculator_report_labels.dart';

enum CalculatorPasteStatus {
  empty,
  plainExpression,
  calculatorReport,
}

/// 中文：**这条粘贴回执说的是哪一件事——是一个判据，不是那句话。**
///
///       回执的开头那一句原先由 `summary` 那个 getter 里的一串 `if`/`else if` 从
///       [CalculatorPasteResult.status]、[CalculatorPasteResult.fromCurrentValue] 与
///       [CalculatorPasteResult.hasExpression] 上判出来，**每一支的结果当场就是一句中文**，
///       而那个 getter 真的会上屏（`calculator_page_sheets.dart` 的 `SnackBar`）。
///
///       现在判据与文案各归各位：**分支是这里这个枚举**（形状与 `NumericInputIssue` 同一条），
///       **字在 [CalculatorPasteStrings] 里**，由调用方递进来。加一种回执时
///       [CalculatorPasteResult.summaryIn] 的 `switch` 编译不过，而不是静默回落到一句别的什么。
///
///       **它只是开头那一句。** 角度模式与记忆值那两截是**并列附加**的，不参与这个枚举——
///       它们由 [CalculatorPasteResult.angleMode]、[CalculatorPasteResult.memoryValue] 两个字段
///       各自决定要不要拼上去，与"说的是哪件事"正交。
/// English: **which thing this paste receipt is about — a verdict, not a sentence.**
///
///          The receipt's opening sentence used to be decided by an `if`/`else if` chain inside the
///          `summary` getter, reading [CalculatorPasteResult.status],
///          [CalculatorPasteResult.fromCurrentValue] and [CalculatorPasteResult.hasExpression], and
///          **each branch's result was a Chinese sentence on the spot** — a getter that really does
///          reach the screen (`calculator_page_sheets.dart`'s `SnackBar`).
///
///          Verdict and wording are now separate: **the branch is this enum** (the same shape as
///          `NumericInputIssue`) and **the words are in [CalculatorPasteStrings]**, handed in by the
///          caller. Adding a kind of receipt breaks the `switch` in
///          [CalculatorPasteResult.summaryIn] at compile time rather than silently falling back to
///          some other sentence.
///
///          **It covers the opening sentence only.** The angle-mode and memory-value parts are
///          **appended side by side** and take no part in this enum: whether they appear is decided by
///          [CalculatorPasteResult.angleMode] and [CalculatorPasteResult.memoryValue] separately,
///          which is orthogonal to "which thing this is about".
enum CalculatorPasteSummaryHead {
  /// 中文：剪贴板里没有表达式，但角度模式与记忆值都恢复了。
  /// English: no expression in the clipboard, but both the angle mode and the memory value came back.
  restoredAngleAndMemory,

  /// 中文：剪贴板里没有表达式，只恢复了角度模式。
  /// English: no expression in the clipboard; only the angle mode came back.
  restoredAngle,

  /// 中文：剪贴板里没有表达式，只恢复了记忆值。
  /// English: no expression in the clipboard; only the memory value came back.
  restoredMemory,

  /// 中文：剪贴板里没有表达式，也没有任何可恢复的元数据。
  /// English: no expression in the clipboard and no metadata to restore either.
  nothingRecognised,

  /// 中文：报告里的当前值被收下了，它成了表达式。
  /// English: the report's current value was taken and became the expression.
  restoredCurrentValue,

  /// 中文：报告里的表达式被取出来了。
  /// English: the expression was pulled out of the report.
  extractedExpression,

  /// 中文：不是报告，就是一段普通表达式。
  /// English: not a report — just a plain expression.
  pastedExpression,
}

class CalculatorPasteResult {
  const CalculatorPasteResult({
    required this.status,
    required this.expression,
    this.fromCurrentValue = false,
    this.angleMode,
    this.memoryValue,
  });

  const CalculatorPasteResult.empty()
      : status = CalculatorPasteStatus.empty,
        expression = '',
        fromCurrentValue = false,
        angleMode = null,
        memoryValue = null;

  factory CalculatorPasteResult.fromText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const CalculatorPasteResult.empty();
    // 中文：**三组标签从产出方那张表取**（`CalculatorReportLabels`）：报告上的词跟着界面语言走，
    //       而剪贴板里那一份可能是另一种语言下复制出来的，所以要的是**每一种语言**的写法——
    //       `spellingsOf` 拼的就是那个并集。源码里不再另抄一份词。
    // English: **three label sets come from the producer's table** (`CalculatorReportLabels`): a
    //          report's words follow the interface language and the clipboard's copy may have been
    //          taken under another one, so what is needed is the spelling in **every** language —
    //          which is the union `spellingsOf` builds. No second copy of the words stays in this
    //          file.
    final fromReport = _looksLikeCalculatorReport(trimmed);
    final labeledExpression = _labeledValue(
        trimmed, CalculatorReportLabels.spellingsOf((labels) => labels.expression));
    final currentValue = _labeledValue(trimmed,
        CalculatorReportLabels.spellingsOf((labels) => labels.currentValue));
    // 中文：报告在显示文本不是可解析十进制时（精确形式 `4√2`）会额外写一行十进制，粘贴时它优先。
    // English: When the report's display text is not a parseable decimal (an exact form such as
    //          `4√2`) it carries an extra decimal line, and that line wins on paste.
    final decimalValue = _labeledValue(
        trimmed, CalculatorReportLabels.spellingsOf((labels) => labels.decimal));
    final restoredCurrentValue = labeledExpression == null &&
        (currentValue != null || decimalValue != null);
    final expression = labeledExpression ??
        _currentValueExpression(
          decimalValue: decimalValue,
          displayValue: currentValue,
          text: trimmed,
          fromReport: fromReport,
        );
    return CalculatorPasteResult(
      status: fromReport
          ? CalculatorPasteStatus.calculatorReport
          : CalculatorPasteStatus.plainExpression,
      expression: expression.trim(),
      fromCurrentValue: restoredCurrentValue,
      angleMode: _angleModeFromText(trimmed),
      memoryValue: _memoryValueFromText(trimmed),
    );
  }

  final CalculatorPasteStatus status;
  final String expression;
  final bool fromCurrentValue;
  final String? angleMode;
  final double? memoryValue;

  bool get hasExpression => expression.trim().isNotEmpty;

  bool get fromReport => status == CalculatorPasteStatus.calculatorReport;

  /// 中文：**这条回执说的是哪一件事**——判据在 [CalculatorPasteSummaryHead] 上，字在
  ///       [CalculatorPasteStrings] 里。分支顺序与拆分前那串 `if`/`else if` 逐条相同
  ///       （先问"有没有表达式"，没有就按元数据分三种，有再看是不是报告）。
  /// English: **which thing this receipt is about** — the verdict is [CalculatorPasteSummaryHead], the
  ///          words are in [CalculatorPasteStrings]. The branches run in the same order as the
  ///          `if`/`else if` chain before the split (first "is there an expression"; without one, split
  ///          by the metadata into three cases; with one, look at whether it came from a report).
  CalculatorPasteSummaryHead get summaryHead {
    if (!hasExpression) {
      if (angleMode != null && memoryValue != null) {
        return CalculatorPasteSummaryHead.restoredAngleAndMemory;
      }
      if (angleMode != null) return CalculatorPasteSummaryHead.restoredAngle;
      if (memoryValue != null) return CalculatorPasteSummaryHead.restoredMemory;
      return CalculatorPasteSummaryHead.nothingRecognised;
    }
    if (fromReport) {
      return fromCurrentValue
          ? CalculatorPasteSummaryHead.restoredCurrentValue
          : CalculatorPasteSummaryHead.extractedExpression;
    }
    return CalculatorPasteSummaryHead.pastedExpression;
  }

  /// 中文：这条回执在屏幕上说的话。**调用方递表进来，自己不留中文兜底**——与
  ///       `FitResult.summaryIn(copy)`、`TextToolOutput.statusMessage(strings)` 同一条形状，
  ///       理由写在 `calculator_paste_strings.dart` 的文件头上。
  ///
  ///       拼法：开头那一句按 [summaryHead] 取，然后**并列**追加两截——角度模式那截的值是
  ///       **令牌归一化**后的 `DEG`/`RAD`（除 `'DEG'` 外一律算 `RAD`，与拆分前逐字节相同），
  ///       记忆值那截用 [formatNumber]（同一个函数，语言无关）。**夹在中间的 ` · ` 是记号**，
  ///       两种语言一样，所以与 `DataFitPasteResult.summaryIn` 同一条：它留在领域层、不进表。
  /// English: what this receipt says on screen. **The caller hands the table in; nothing here keeps a
  ///          Chinese fallback** — the same shape as `FitResult.summaryIn(copy)` and
  ///          `TextToolOutput.statusMessage(strings)`, for the reason on
  ///          `calculator_paste_strings.dart`'s head.
  ///
  ///          Composition: the opening sentence follows [summaryHead], then two parts are **appended
  ///          side by side** — the angle-mode part's value is the **normalised token** `DEG`/`RAD`
  ///          (anything but `'DEG'` counts as `RAD`, byte-identical to before the split), and the
  ///          memory-value part goes through [formatNumber] (one function, language-independent). The
  ///          **` · ` between the parts is notation**, the same in both languages, so — exactly as
  ///          `DataFitPasteResult.summaryIn` puts it — it stays in the domain layer and never enters a
  ///          table.
  String summaryIn(CalculatorPasteStrings strings) {
    final parts = <String>[
      switch (summaryHead) {
        CalculatorPasteSummaryHead.restoredAngleAndMemory =>
          strings.restoredAngleAndMemory,
        CalculatorPasteSummaryHead.restoredAngle => strings.restoredAngle,
        CalculatorPasteSummaryHead.restoredMemory => strings.restoredMemory,
        CalculatorPasteSummaryHead.nothingRecognised =>
          strings.noExpressionRecognised,
        CalculatorPasteSummaryHead.restoredCurrentValue =>
          strings.restoredCurrentValue,
        CalculatorPasteSummaryHead.extractedExpression =>
          strings.extractedExpression,
        CalculatorPasteSummaryHead.pastedExpression => strings.pastedExpression,
      },
    ];
    if (angleMode != null) {
      parts.add(strings.angleModePart(angleMode == 'DEG' ? 'DEG' : 'RAD'));
    }
    if (memoryValue != null) {
      parts.add(strings.memoryPart(formatNumber(memoryValue!)));
    }
    return parts.join(' · ');
  }

  /// 中文：**中文那一份的默认写法，只有一个读者：**
  ///       `test/domain/calculator_paste_result_test.dart`——**用户未提交的文件**，本轮一个字都
  ///       不能动，而它逐条钉着那七句中文。**界面那条路不再走这里**
  ///       （`calculator_page_sheets.dart` 把当前语言的表递给 [summaryIn]），所以这个 getter 不再
  ///       决定任何用户看得见的字；新代码请用 [summaryIn]。它留着是因为上面那条测试，
  ///       与 `GraphWorkspacePasteResult.summary` 当初留着的理由同一条。
  /// English: **the default Chinese spelling, with exactly one reader:**
  ///          `test/domain/calculator_paste_result_test.dart` — **the user's uncommitted file**, not
  ///          one character of which may move this round, and it pins those seven Chinese sentences
  ///          one by one. **The interface road no longer goes through here**
  ///          (`calculator_page_sheets.dart` hands the active language's table to [summaryIn]), so this
  ///          getter no longer decides anything a user sees; new code should call [summaryIn]. It stays
  ///          for that test, the same reason `GraphWorkspacePasteResult.summary` was kept.
  String get summary => summaryIn(CalculatorPasteStrings.zh);

  /// 中文：当前值的取值顺序——报告里的十进制行优先，其次是人类可读的当前值行，最后才是纯文本剪贴板
  ///       里第一行「看起来像表达式」的内容。两条报告行都**必须能解析成一个有限数**才算数，实现
  ///       就是 [_parserSafeCurrentValue]。
  ///
  ///       每一行各自的情形，逐条写清楚（这是 3c 评审第 2 项的交付物）：
  ///
  ///       1. 报告里有 `十进制:` 行且可解析 → 用它。精确形式（`4√2`）的报告正是这一种：控制器在
  ///          显示文本不是十进制时会额外写这一行，粘贴靠它往返。
  ///       2. 没有可用的 `十进制:` 行（没有这一行，或者这一行解析不出来），而 `当前值` 行可解析
  ///          → 用 `当前值` 行。**旧求值器产出的报告都是这一种**：显示形态本身就是十进制形态
  ///          （`displayTextIsParseable` 为真），`1,234.5` → `1234.5`，复制粘贴的往返靠的就是它。
  ///       3. 两条都不可用（例如报告只有 `当前值: 4√2`，或者 `当前值: not-a-number`）→
  ///          **什么都不恢复**：宁可空手而归，也不把显示文本解析成数字，更不会用失败解析出的 0
  ///          去冒充一个值。这种情况**仍然是静默的**——摘要保持 `剪贴板里没有识别到表达式`，
  ///          没有额外的提示（3c 评审建议过一条「当前值无法恢复」的摘要，但那会改掉已被钉住的
  ///          摘要文本，见下），这是接受的裁决，不是未处理的缺口。
  ///
  ///       行为被两处测试钉住，所以这里只写规则、不改行为：
  ///       `test/domain/calculator_result_split_test.dart` 的
  ///       `pasting a report without a decimal line behaves as before` 要求第 2 种情形成立；
  ///       `test/domain/calculator_paste_result_test.dart` 的
  ///       `unusable current value report keeps the unrecognized summary` 把第 3 种情形的摘要文本
  ///       钉在 `剪贴板里没有识别到表达式`。
  ///
  /// English: The order current values are taken in — the report's decimal line first, then the
  ///          human-readable current-value line, and finally the first expression-like line of a
  ///          plain-text clipboard. Both report lines count only if they parse into a finite number,
  ///          which is what [_parserSafeCurrentValue] enforces.
  ///
  ///          The cases, spelled out one by one (this comment is the deliverable for finding 2 of the
  ///          3c review):
  ///
  ///          1. The report has a parseable `十进制:` line → it wins. A report for an exact form
  ///             (`4√2`) is exactly this case: the controller writes that line when the display text
  ///             is not itself a decimal, and the paste round trip rides on it.
  ///          2. No usable `十进制:` line (absent, or unparseable), and the current-value line
  ///             parses → the current-value line is used. *Every report the legacy evaluator
  ///             produces is this case*: the display form is itself the decimal form
  ///             (`displayTextIsParseable` is true), `1,234.5` becomes `1234.5`, and the copy/paste
  ///             round trip depends on it.
  ///          3. Neither is usable (the report carries only `当前值: 4√2`, or `当前值: not-a-number`)
  ///             → *nothing is restored*: it goes home empty-handed rather than parsing display
  ///             text, and never passes off a failed parse's 0 as a value. This case is **still
  ///             silent** — the summary stays `剪贴板里没有识别到表达式` with no extra hint. (The 3c
  ///             review suggested a "current value could not be restored" summary; that would change
  ///             summary text pinned by a test, see below.) That is an accepted ruling, not an
  ///             unhandled gap.
  ///
  ///          The behaviour is pinned by two tests, so this states the rule without changing it:
  ///          `pasting a report without a decimal line behaves as before` in
  ///          `test/domain/calculator_result_split_test.dart` requires case 2 to hold, and
  ///          `unusable current value report keeps the unrecognized summary` in
  ///          `test/domain/calculator_paste_result_test.dart` pins case 3's summary text to
  ///          剪贴板里没有识别到表达式.
  static String _currentValueExpression({
    required String? decimalValue,
    required String? displayValue,
    required String text,
    required bool fromReport,
  }) {
    final decimal =
        decimalValue == null ? '' : _parserSafeCurrentValue(decimalValue);
    if (decimal.isNotEmpty) return decimal;
    // 中文：情形 2 与 3 的分界——`当前值` 行可解析就用，不可解析就什么都不恢复（见上面的 3）。
    // English: The line between cases 2 and 3 — a parseable current-value line is used, an
    //          unparseable one restores nothing (see case 3 above).
    if (displayValue != null) return _parserSafeCurrentValue(displayValue);
    return fromReport ? '' : _firstExpressionLikeLine(text);
  }

  /// 中文：报告里的一行数字文本，能不能安全地写回表达式。判定用
  ///       [MathResult.decimalValueOf]——与提交路径、记忆寄存器**同一处实现**。
  ///
  ///       以前的判据是「`double.tryParse` 成功且 `isFinite`」，于是 `9.303768583076e-603`
  ///       会被接受，理由是它解析成了一个**有限的** `0.0`。**「解析成功」不等于「值保住了」**：
  ///       那个 0.0 是下溢，粘回来的是一个比原值小 10^600 倍的数——正是修复轮 1 在提交路径上
  ///       修掉的那类静默错值，只是这里没修。`decimalValueOf` 对下溢返回 null，于是这一行被拒，
  ///       粘贴什么都不恢复（fail-closed，与「当前值不是数字」同一条路）。
  ///
  /// English: Whether a numeric line from a report is safe to write back into the expression. The
  ///          judgement is [MathResult.decimalValueOf] — the *same implementation* the submit path
  ///          and the memory register use.
  ///
  ///          The old test was "`double.tryParse` succeeds and `isFinite`", which accepted
  ///          `9.303768583076e-603` on the grounds that it parses into a *finite* `0.0`.
  ///          "It parsed" is not "the value survived": that 0.0 is an underflow, and pasting it
  ///          back yields a number 10^600 times smaller — the same silent wrong value fix round 1
  ///          eliminated on the submit path, only not here. `decimalValueOf` returns null for
  ///          underflow, so the line is refused and the paste restores nothing (fail-closed, the
  ///          same route as "the current value is not a number").
  static String _parserSafeCurrentValue(String raw) {
    var normalized = raw.replaceAll(',', '').trim();
    if (normalized.startsWith('-.')) {
      normalized = '-0${normalized.substring(1)}';
    } else if (normalized.startsWith('.')) {
      normalized = '0$normalized';
    }
    return decimalValueOf(normalized) == null ? '' : normalized;
  }

  static String? _labeledValue(String text, List<String> labels) {
    final escaped = labels.map(RegExp.escape).join('|');
    final pattern = RegExp(
      '^\\s*(?:$escaped)\\s*[:：]\\s*(.+?)\\s*\$',
      caseSensitive: false,
      multiLine: true,
    );
    return pattern.firstMatch(text)?.group(1)?.trim();
  }

  /// 中文：**报告标签行的全部写法**——「这一行是不是报告自己写的那几个标签之一」这道判据的词，
  ///       从产出方那张表（[CalculatorReportLabels]）取，源码里不再另抄一份。
  ///
  ///       **它原先抄了一份**，于是报告的词与这里的词是两份；词一改（或者报告跟着界面语言换一套），
  ///       这里就悄悄对不上，`状态: …` 那一行会被当成"像表达式"的一行返回出去，粘回来的是一个句子。
  ///       这一条与 [_looksLikeCalculatorReport] 是同一根因的两处（那里判"整段是不是报告"，
  ///       这里判"这一行要不要跳过"）。
  ///
  ///       **哪些标签要跳过是本处的事，怎么写由表说了算**：集合里是九条报告行里**除 `表达式` 以外**
  ///       的七个标签（`表达式` 不跳——它是报告正文里唯一"值本身可能像表达式"的一行，
  ///       而这一条路只在整段**不是**报告时才走到）。这张表的成员与今天逐条相同，
  ///       **一个字都没动**：这份名单是行为，不是文案。`保存时间` 同样不在里面（今天也不在）。
  ///
  ///       **折成小写是这里做的**（表里存的是产出方印出来的原样：`'Current value'`），
  ///       与今天那几条小写字面量逐字符一致；中文那几个词折了也不变。
  /// English: **every spelling of a report label line** — the words behind "is this line one of the
  ///          labels the report itself writes", taken from the producer's table
  ///          ([CalculatorReportLabels]) instead of a second copy in this source.
  ///
  ///          **There used to be a second copy here**, so the report's words and these words were two
  ///          sets; change a word (or have the report switch sets with the interface language) and
  ///          this side quietly stops matching, so a `状态: …` line gets returned as "the line that
  ///          looks like an expression" and what comes back out of the paste is a sentence. This and
  ///          [_looksLikeCalculatorReport] are two faces of one cause (that one asks "is the whole
  ///          text a report", this one asks "should this line be skipped").
  ///
  ///          **Which labels to skip is decided here; how they are spelled is the table's business.**
  ///          The set holds seven of the nine report labels — every one but `表达式` (which is not
  ///          skipped: it is the one report line whose value may itself look like an expression, and
  ///          this road is only reached when the whole text is **not** a report). The membership is
  ///          character for character today's list: **that list is behaviour, not copy.** `保存时间`
  ///          is not in it either (nor was it today).
  ///
  ///          **Lower-casing happens here** (the table holds what the producer prints, `'Current value'`
  ///          among them), which leaves the words byte-identical to today's lower-case literals; the
  ///          Chinese ones do not change under a fold.
  static final List<String> _skippedLineHeads = <String>[
    for (final labels in CalculatorReportLabels.all)
      for (final word in <String>[
        labels.currentValue,
        labels.decimal,
        labels.result,
        labels.status,
        labels.angleMode,
        labels.memory,
        labels.error,
      ])
        word.toLowerCase(),
  ];

  static String _firstExpressionLikeLine(String text) {
    final lines = const LineSplitter()
        .convert(text)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    for (final line in lines) {
      final normalized = line.toLowerCase();
      if (_skippedLineHeads.any((head) => normalized.startsWith(head))) {
        continue;
      }
      return line;
    }
    return '';
  }

  /// 中文：**报告里 `角度模式:` 那一行 → `DEG` / `RAD`。** 值可能是 `'角度 DEG'`（本应用的报告）
  ///       或 `'DEG'`（外层/旧报告），所以两半都认：
  ///
  ///       - **令牌那一半**：`deg` / `rad` 是**语言无关的记号**，两种语言里都这么写，所以它们在
  ///         解析器里就是字面量——它们不是词，翻了反而对不上。
  ///       - **词那一半**：没有令牌那种写法（`角度模式: 角度`）只能靠词认，而那些词**从产出方那张
  ///         表取**（[CalculatorReportLabels.angleDegreesWord] / `angleRadiansWord` 的
  ///         `spellingsOf`，也就是**每一种语言**的并集）——剪贴板里那份可能是在另一种语言下
  ///         复制出来的。**源码里不再另抄一份 `'角度'` / `'弧度'`**：词一改或加一种语言，词那一半
  ///         会跟着动，而不是悄悄变成永远为假。
  ///
  ///       **顺序是行为**：先问 `DEG` 再问 `RAD`，与拆分前逐条相同（`'弧度 RAD'` 两半都不撞
  ///       `DEG`，所以这个顺序今天不会改变任何结果，但它照旧写在这里）。
  ///
  ///       英文那两个词（`Degrees` / `Radians`）加进并集**不改变任何结果**：任何含 `Degrees` 的值
  ///       都含 `deg`（折成小写之后），任何含 `Radians` 的都含 `rad`，所以它们只会命中那些**本来
  ///       就已经命中**的值。
  /// English: **the report's `角度模式:` line into `DEG` / `RAD`.** The value may be `'角度 DEG'` (this
  ///          app's report) or `'DEG'` (a foreign or older one), so both halves are accepted:
  ///
  ///          - **the token half**: `deg` / `rad` are **language-independent marks**, written that way
  ///            in every language, so they are literals here — they are not words, and translating one
  ///            would break the match.
  ///          - **the word half**: the token-less spelling (`角度模式: 角度`) can only be recognised by
  ///            its word, and those words **come from the producer's table**
  ///            ([CalculatorReportLabels.angleDegreesWord] / `angleRadiansWord` through `spellingsOf`,
  ///            the union over **every** language) — the clipboard's copy may have been taken under
  ///            another language. **No second `'角度'` / `'弧度'` is written in this file**: change a
  ///            word or add a language and the word half moves with it rather than quietly becoming
  ///            permanently false.
  ///
  ///          **The order is behaviour**: `DEG` is asked first and `RAD` second, item for item as before
  ///          the split (`'弧度 RAD'` hits neither half of `DEG`, so the order changes no result today —
  ///          but it is still written down here).
  ///
  ///          Adding the two English words (`Degrees` / `Radians`) to the union **changes no result**:
  ///          any value holding `Degrees` holds `deg` (once folded to lower case) and any holding
  ///          `Radians` holds `rad`, so they only ever hit values that **already** matched.
  static String? _angleModeFromText(String text) {
    final raw = _labeledValue(
        text, CalculatorReportLabels.spellingsOf((labels) => labels.angleMode));
    if (raw == null) return null;
    final normalized = raw.toLowerCase();
    if (normalized.contains('deg') ||
        _containsAnyWord(
            raw, CalculatorReportLabels.spellingsOf((l) => l.angleDegreesWord))) {
      return 'DEG';
    }
    if (normalized.contains('rad') ||
        _containsAnyWord(
            raw, CalculatorReportLabels.spellingsOf((l) => l.angleRadiansWord))) {
      return 'RAD';
    }
    return null;
  }

  /// 中文：这一段文本里有没有出现词表里的任何一个词。**大小写敏感**——与今天那句
  ///       `raw.contains('角度')` 同一条（中文没有大小写，所以这个判据原先只对中文成立；
  ///       英文那两个词今天靠 `deg`/`rad` 那一半命中，不靠这里）。
  /// English: whether this text holds any of the words. **Case-sensitive**, the same as today's
  ///          `raw.contains('角度')` (Chinese has no case, so that judgement only ever held for
  ///          Chinese; the two English words are matched by the `deg`/`rad` half today, not here).
  static bool _containsAnyWord(String text, List<String> words) =>
      words.any(text.contains);

  /// 中文：报告里 `记忆值:` 那一行 → 寄存器的数值。判定用 [MathResult.decimalValueOf]——与
  ///       提交路径、当前值那一行**同一处实现**。
  ///
  ///       旧的判据是「`double.tryParse` 成功且 `isFinite`」：`记忆值: 9.303768583076e-603`
  ///       解析出来是一个**有限的** `0.0`，于是被收下，寄存器从 7.0 静默变成 0.0——正是本轮在
  ///       别处修掉的那个错误。只有外来报告能构造出这一行（App 自己的报告写的是
  ///       `formatNumber(memoryValue)`），但这不改变它是错的。
  /// English: The report's `记忆值:` line into the register's value. The judgement is
  ///          [MathResult.decimalValueOf] — the *same implementation* the submit path and the
  ///          current-value line use.
  ///
  ///          The old test was "`double.tryParse` succeeds and `isFinite`": `记忆值:
  ///          9.303768583076e-603` parses into a *finite* `0.0`, so it was taken and the register
  ///          went from 7.0 to 0.0 without a word — the very error this round fixed elsewhere. Only
  ///          a foreign report can build that line (this app's own reports write
  ///          `formatNumber(memoryValue)`), but that does not make it right.
  static double? _memoryValueFromText(String text) {
    // 中文：`memory value` 是这里自己加的别名，理由与 [_looksLikeCalculatorReport] 那一处逐字相同。
    // English: `memory value` is an alias added here; the reason is character for character the one on
    //          [_looksLikeCalculatorReport].
    final raw = _labeledValue(text, <String>[
      ...CalculatorReportLabels.spellingsOf((labels) => labels.memory),
      'memory value',
    ]);
    if (raw == null) return null;
    return decimalValueOf(raw.replaceAll(',', '').trim());
  }

  /// 中文：**这一段是不是本应用自己写出来的报告。** 判据是"有没有一条报告标签行"，
  ///       而标签的词从产出方那张表取（[CalculatorReportLabels]）——报告跟着界面语言走，
  ///       所以这里读的是**每一种语言**的并集，源码里不再另抄一份。
  ///
  ///       **`memory value` 是这里自己加的一个别名**（表里没有它，因为应用从不写这个词）：
  ///       外层报告/旧版本报告可能这么写，今天认得它，这一轮不动这个宽容量。它在
  ///       [_memoryValueFromText] 里也出现——两处逐条相同。
  /// English: **whether this text is a report this app itself wrote.** The judgement is "is there a
  ///          report label line", and the label words come from the producer's table
  ///          ([CalculatorReportLabels]) — a report follows the interface language, so this reads the
  ///          union over **every** language rather than a second copy in this source.
  ///
  ///          **`memory value` is an alias added here** (the table has no such word, because the app
  ///          never writes it): a foreign or older report may spell it that way, it is accepted today,
  ///          and this round does not touch that leniency. It appears in [_memoryValueFromText] too,
  ///          character for character the same.
  static bool _looksLikeCalculatorReport(String text) {
    final labelSets = <List<String>>[
      CalculatorReportLabels.spellingsOf((labels) => labels.expression),
      CalculatorReportLabels.spellingsOf((labels) => labels.currentValue),
      CalculatorReportLabels.spellingsOf((labels) => labels.decimal),
      CalculatorReportLabels.spellingsOf((labels) => labels.result),
      CalculatorReportLabels.spellingsOf((labels) => labels.angleMode),
      <String>[
        ...CalculatorReportLabels.spellingsOf((labels) => labels.memory),
        'memory value',
      ],
    ];
    return labelSets.any((labels) => _labeledValue(text, labels) != null);
  }
}
