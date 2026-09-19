/// 中文：**计算器报告上那九个标签的词，只有这一份。** 产它的是
///       `CalculatorControllerStrings` 的九条 `reportXxx` 句子（`lib/features/calculator/
///       presentation/calculator_controller_strings.dart`），读它的是粘贴解析器
///       （`calculator_paste_result.dart`）——**两端读同一张表**，所以词换了、语言加了一种，
///       两边一起动。
///
///       ### 它修的是什么
///
///       报告的标签是**跟着界面语言走的**（实测：`reportCurrentValue` 是 `'当前值: $value'` 与
///       `'Current value: $value'` 两条），而粘贴解析器原先把这两套词**在源码里另抄了一份**
///       （`_looksLikeCalculatorReport` 的六组、`_firstExpressionLikeLine` 的跳过表、
///       `_memoryValueFromText` 与 `_angleModeFromText` 各一组）。那是一句**要显示给用户的话**
///       兼任**判据**——本项目确诊过四次的那一类的第五、第六处：词一改（或加一种语言），
///       判据悄悄变成永远为假，没有异常、没有日志，只是粘贴不再认得自己写出来的报告。
///       **两端分开的抄本从来不是"两边都对"，只是"两边今天恰好一样"。**
///
///       ### 为什么不是"一个不用翻译的记号"
///
///       「给报告加一行 ASCII 前缀」是更彻底的答案，但**报告正文是用户看得见的字**：它进剪贴板、
///       进笔记、进历史，措辞被测试逐条钉着。加记号＝改用户看得见的文本，本轮明令禁止
///       （中文必须逐字节不变）。报告里也确实**没有**现成的语言无关记号：九行里每一行的标签都是
///       词，`DEG`/`RAD` 只出现在 `角度模式` 那一行的**值**位置上（而那一行的标签同样要翻）。
///       所以这一轮的答案是：**判据不认识"某个词"，它认识"产出方的那张表"**——判据的结构部分
///       （`标签: 值` 这个形状、冒号）本来就在解析器里，语言相关的部分现在从产出方取。
///
///       ### 每种语言一份，`all` 是**粘贴**要的并集
///
///       一份报告是在**某一种**语言下写出来的，而剪贴板里的那一份可能是**另一种**语言下写的，
///       所以粘贴解析器必须认识**每一种**语言的标签：它读 [all]。加一种语言时
///       `CalculatorControllerStrings.forLanguage` 的穷尽 `switch` 会先编译不过（既有约定），
///       而新增的这一份表**必须同时进 [all]**——`calculator_report_labels_test.dart` 用
///       `AppLanguage.values` 逐语言钉住这件事（产出方写的每个词都要在 [all] 里，[all] 里每个词
///       也都要有产出方在写），漏一个就红。
///
///       ### 一个 import 都没有，是故意的
///
///       与 `data_fit_copy.dart` 同一条：本文件里全是 `final` 字符串，不可变由构造方式保证，
///       不需要 `@immutable`（那个注解来自 Flutter）。`lib/domain/` 今天没有任何一行
///       `import 'package:flutter…'`，这条不变量刻意维持着——所以这张表**不住在
///       `features/calculator/presentation/`**，尽管产出方在那儿。
///
/// English: **the words of the nine labels a calculator report carries, in one place only.** The
///          producer is `CalculatorControllerStrings`' nine `reportXxx` sentences
///          (`lib/features/calculator/presentation/calculator_controller_strings.dart`); the reader
///          is the paste parser (`calculator_paste_result.dart`) — **both ends read one table**, so
///          when a word changes or a language is added, the two move together.
///
///          ### What it fixes
///
///          A report's labels **follow the interface language** (measured: `reportCurrentValue` is
///          `'当前值: $value'` and `'Current value: $value'`), while the paste parser used to keep
///          **a second copy of those words in the source** (six sets in `_looksLikeCalculatorReport`,
///          the skip list in `_firstExpressionLikeLine`, and one each in `_memoryValueFromText` and
///          `_angleModeFromText`). That is a **sentence meant for the user doubling as a judgement** —
///          the fifth and sixth confirmed instances of a class this project has hit four times
///          already: change a word (or add a language) and the judgement goes quietly, permanently
///          false, with nothing thrown and nothing logged — the paste just stops recognising the
///          reports this app itself writes. **Two separate copies were never "both right", only
///          "both the same today".**
///
///          ### Why not "a marker that needs no translation"
///
///          An ASCII prefix on the report would be the thorough answer, but **the report body is text
///          the user sees**: it goes to the clipboard, into notes and into history, and its wording is
///          pinned line by line by tests. Adding a marker means changing user-visible text, which this
///          round forbids (the Chinese has to stay byte-identical). And there is no ready-made
///          language-independent marker in the report: every one of the nine lines carries a word as
///          its label, and `DEG`/`RAD` appear only in the **value** position of the `角度模式` line
///          (whose label is translated all the same). So this round's answer is: **the judgement does
///          not know "a word", it knows the producer's table** — the structural half of the
///          judgement (the `label: value` shape, the colon) was always in the parser, and the
///          language-dependent half now comes from the producer.
///
///          ### One entry per language; `all` is the union **paste** needs
///
///          A report is written in **one** language, while the copy on the clipboard may have been
///          written in **another**, so the paste parser has to know the labels of **every** language:
///          it reads [all]. When a language is added, `CalculatorControllerStrings.forLanguage`'s
///          exhaustive `switch` fails to compile first (the established convention), and the new entry
///          here **must also join [all]** — `calculator_report_labels_test.dart` pins that per
///          language through `AppLanguage.values` (every word a producer writes has to be in [all],
///          and every word in [all] has to be written by some producer); miss one and it goes red.
///
///          ### Not one import, on purpose
///
///          The same rule as `data_fit_copy.dart`: everything here is a `final` string, immutability
///          comes from how it is built, and `@immutable` (which comes from Flutter) is not needed.
///          Nothing under `lib/domain/` imports `package:flutter…` today, and that invariant is kept
///          deliberately — which is why this table does **not** live under
///          `features/calculator/presentation/`, even though the producer does.
library;

/// 中文：一个 `CalculatorReportLabels` 装的是**一种语言**下、计算器报告九个标签的词。
///       **词里不含冒号、不含空格**：句子怎么拼（`'$word: $value'`）是产出方的事，这里只有词。
/// English: one `CalculatorReportLabels` holds the nine label words of a calculator report in **one
///          language**. **A word carries no colon and no space**: how the sentence is put together
///          (`'$word: $value'`) is the producer's business; this file holds words only.
class CalculatorReportLabels {
  const CalculatorReportLabels({
    required this.expression,
    required this.currentValue,
    required this.result,
    required this.decimal,
    required this.status,
    required this.angleMode,
    required this.memory,
    required this.error,
    required this.savedAt,
  });

  /// 中文：`表达式` 那一行。报告在表达式非空时写它。
  /// English: the `表达式` line, written when the expression is not empty.
  final String expression;

  /// 中文：`当前值` 那一行。报告在表达式为空时写它（与 [expression] 二选一）。
  /// English: the `当前值` line, written when the expression is empty (either this or [expression]).
  final String currentValue;

  /// 中文：`结果` 那一行。
  /// English: the `结果` line.
  final String result;

  /// 中文：`十进制` 那一行——显示文本本身不是可解析十进制时（`4√2` 这类精确形式）补的那一行。
  /// English: the `十进制` line — added when the display text is not itself a parseable decimal
  ///          (exact forms such as `4√2`).
  final String decimal;

  /// 中文：`状态` 那一行（状态卡的标题）。
  /// English: the `状态` line (the status card's title).
  final String status;

  /// 中文：`角度模式` 那一行。
  /// English: the `角度模式` line.
  final String angleMode;

  /// 中文：`记忆值` 那一行，只在寄存器非零时出现。
  /// English: the `记忆值` line, present only while the register is non-zero.
  final String memory;

  /// 中文：`错误` 那一行，只在有错误时出现。
  /// English: the `错误` line, present only while there is an error.
  final String error;

  /// 中文：`保存时间` 那一行，只写在笔记正文里（复制出去的报告没有它）。
  /// English: the `保存时间` line, written into a note's body only (a copied report has none).
  final String savedAt;

  /// 中文：中文那一份。与 `CalculatorControllerStrings.calculatorControllerZh` 的九条句子逐字节一致。
  /// English: the Chinese entry. Byte-identical to the nine sentences in
  ///          `CalculatorControllerStrings.calculatorControllerZh`.
  static const CalculatorReportLabels zh = CalculatorReportLabels(
    expression: '表达式',
    currentValue: '当前值',
    result: '结果',
    decimal: '十进制',
    status: '状态',
    angleMode: '角度模式',
    memory: '记忆值',
    error: '错误',
    savedAt: '保存时间',
  );

  /// 中文：英文那一份。与 `CalculatorControllerStrings.calculatorControllerEn` 的九条句子逐字节一致。
  ///       **首字母大小写是产出方的事**：报告写的是 `'Expression: …'`，而粘贴那一侧一律按
  ///       小写比较（`_firstExpressionLikeLine` 先把整行折成小写），所以那里自己折一次。
  /// English: the English entry. Byte-identical to the nine sentences in
  ///          `CalculatorControllerStrings.calculatorControllerEn`. **Capitalisation belongs to the
  ///          producer**: a report reads `'Expression: …'`, while the paste side compares in lower
  ///          case throughout (`_firstExpressionLikeLine` lower-cases the whole line first), so that
  ///          side folds it itself.
  static const CalculatorReportLabels en = CalculatorReportLabels(
    expression: 'Expression',
    currentValue: 'Current value',
    result: 'Result',
    decimal: 'Decimal',
    status: 'Status',
    angleMode: 'Angle mode',
    memory: 'Memory',
    error: 'Error',
    savedAt: 'Saved at',
  );

  /// 中文：**应用可能写出来的每一种语言**——粘贴那一侧读的就是它（剪贴板里那份可能是在另一种
  ///       语言下复制出来的）。加一种语言时这里必须跟着加，`calculator_report_labels_test.dart`
  ///       逐语言钉着这件事。
  /// English: **every language the app can write** — what the paste side reads (the clipboard's copy
  ///          may have been taken under another language). Adding a language means adding an entry
  ///          here, and `calculator_report_labels_test.dart` pins it language by language.
  static const List<CalculatorReportLabels> all = <CalculatorReportLabels>[zh, en];

  /// 中文：挑出来的那一个标签在**每一种语言**下的写法。粘贴那一侧要的正是"每一种"，
  ///       所以并集只在这里拼一次，调用方给的是"要哪一个标签"（`(labels) => labels.currentValue`）。
  ///       **顺序**与 [all] 一致（先中文后英文），与今天源码里那几组"先中文后英文"的字面量同序。
  /// English: the chosen label's spelling in **every** language. "Every" is exactly what the paste
  ///          side needs, so the union is built in this one place and the caller supplies *which*
  ///          label (`(labels) => labels.currentValue`). The **order** follows [all] (Chinese first,
  ///          then English), the same order the hand-written lists in the source had.
  static List<String> spellingsOf(
    String Function(CalculatorReportLabels labels) label,
  ) {
    return <String>[for (final labels in all) label(labels)];
  }
}
