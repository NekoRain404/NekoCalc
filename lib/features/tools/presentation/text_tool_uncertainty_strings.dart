import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：**不确定度传播工具的文案表。** 与日期计算那张同形（为什么手写分表、为什么
///       `static final` 而不是 `const`，见 `settings_strings.dart` 的文件头）。
///
///       **表里没有数值**：`12.5 ± 0.3`、`± 0.316`、`2.5%` 都是**数据**，两种语言原样出。
///       与 `unitLabel`（用户打的字）、日期（`2026-09-20`）是同一条判据。
/// English: **the uncertainty tool's copy table.** Same shape as the date calculator's (why these are
///          hand-written and why `static final` rather than `const` is on `settings_strings.dart`'s
///          head).
///
///          **The table holds no numbers**: `12.5 ± 0.3`, `± 0.316` and `2.5%` are **data** and come back
///          verbatim in both languages — the same ruling that covers `unitLabel` (what the user typed)
///          and dates (`2026-09-20`).
@immutable
class TextToolUncertaintyStrings {
  const TextToolUncertaintyStrings({
    required this.emptyInput,
    required this.unrecognized,
    required this.hint,
    required this.singleHint,
    required this.sumLabel,
    required this.productLabel,
    required this.dominantLabel,
    required this.relativeLabel,
    required this.resultLine,
    required this.between,
    required this.termNumber,
    required this.readAsSingle,
    required this.termList,
  });

  final String emptyInput;

  /// 中文：读不出任何一项。**如实拒绝**，不猜用户想要哪一种合成。
  /// English: not one term could be read. **An honest refusal** — it does not guess which combination
  ///          the user wanted.
  final String unrecognized;

  final String hint;

  /// 中文：只给了一项时的提示。**一项没有"传播"可言**——所以这一支是错误而不是结果：
  ///       它只报这一项自己的相对不确定度，其余三项无从谈起。
  /// English: the hint when only one term is given. **One term has nothing to propagate** — so this
  ///          branch is an error rather than a result: it reports that term's own relative uncertainty
  ///          and the other three quantities simply do not exist.
  final String singleHint;

  final String sumLabel;
  final String productLabel;
  final String dominantLabel;
  final String relativeLabel;

  final String Function(String value) resultLine;
  final String Function(String terms, int count) between;
  final String Function(int index) termNumber;
  final String Function(String value, String uncertainty) readAsSingle;

  /// 中文：**把若干项连成一句话的那个连接符。** 它是排版不是数据——所以它在表里，
  ///       而不是散在控制器里（与 `labelled` 同一条判据）。
  /// English: **the joiner that turns several terms into one phrase.** Layout, not data — so it lives
  ///          here rather than loose in the controller (the same ruling as `labelled`).
  final String Function(List<String> terms) termList;

  static TextToolUncertaintyStrings of(BuildContext context) =>
      forLanguage(AppLanguage.of(context));

  /// 中文：与 [of] 同一张分派表。**`switch` 穷尽 `AppLanguage`**。
  /// English: the same dispatch as [of]; the **`switch` exhausts `AppLanguage`**.
  static TextToolUncertaintyStrings forLanguage(AppLanguage language) =>
      switch (language) {
        AppLanguage.zh => textToolUncertaintyZh,
        AppLanguage.en => textToolUncertaintyEn,
      };

  static final TextToolUncertaintyStrings textToolUncertaintyZh =
      TextToolUncertaintyStrings(
    emptyInput: '请输入若干「值 ± 不确定度」，一行一项',
    unrecognized: '读不出任何一项，每项要写成「值 ± 不确定度」',
    hint: '例如：\n12.5 ± 0.3\n4.2 ± 0.1',
    singleHint: '只有一项没有可传播的合成，下面是它自己的相对不确定度',
    sumLabel: '和与差',
    productLabel: '积与商',
    dominantLabel: '主要来源',
    relativeLabel: '相对不确定度',
    resultLine: (value) => value,
    between: (terms, count) => '$terms 共 $count 项',
    termNumber: (index) => '第 $index 项',
    readAsSingle: (value, uncertainty) => '$value ± $uncertainty',
    termList: (terms) => terms.join('、'),
  );

  static final TextToolUncertaintyStrings textToolUncertaintyEn =
      TextToolUncertaintyStrings(
    emptyInput: 'Enter "value ± uncertainty" pairs, one per line',
    unrecognized: 'Nothing could be read; each term must be "value ± uncertainty"',
    hint: 'For example:\n12.5 ± 0.3\n4.2 ± 0.1',
    singleHint:
        'One term has nothing to combine; below is its own relative uncertainty',
    sumLabel: 'Sum and difference',
    productLabel: 'Product and quotient',
    dominantLabel: 'Dominant source',
    relativeLabel: 'Relative uncertainty',
    resultLine: (value) => value,
    between: (terms, count) => '$terms, $count terms',
    termNumber: (index) => 'term $index',
    readAsSingle: (value, uncertainty) => '$value ± $uncertainty',
    termList: (terms) => terms.join(', '),
  );
}
