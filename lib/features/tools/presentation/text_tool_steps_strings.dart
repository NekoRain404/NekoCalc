import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：**算术分步工具的文案表。** 与日期、不确定度、求导分步那几张同形。
///
///       **表里没有算式**：`1 + 6`、`7` 是**数据**，两种语言原样出。
///       换掉的只有我们自己的那几句。
/// English: **the arithmetic-stepper's copy table.** Same shape as the date, uncertainty and derivative
///          tables.
///
///          **The table holds no algebra**: `1 + 6` and `7` are **data** and come back verbatim in both
///          languages. Only our own sentences change.
@immutable
class TextToolStepsStrings {
  const TextToolStepsStrings({
    required this.emptyInput,
    required this.unsupported,
    required this.hint,
    required this.heading,
  });

  final String emptyInput;

  /// 中文：**读得出，但这一版不处理**——变量、函数、后缀、单位都在这里。
  ///       ⚠️ 与 [emptyInput] 不是同一件事：那一个是"什么都没输入"。
  /// English: **readable, but not handled by this version** — variables, calls, postfixes and units land
  ///          here. ⚠️ Not the same as [emptyInput], which is "nothing was typed".
  final String unsupported;

  final String hint;

  /// 中文：步骤那一栏的抬头。**它挡的是"一串没有上下文的等式"**——
  ///       用户看到五行 `1 + 6` 之类的式子时，得先知道这是"每一步"。
  /// English: the heading over the steps. **It guards against "a run of equations with no context"** — a
  ///          user seeing five lines of `1 + 6` has to know first that these are the steps.
  final String heading;

  static TextToolStepsStrings of(BuildContext context) =>
      forLanguage(AppLanguage.of(context));

  static TextToolStepsStrings forLanguage(AppLanguage language) =>
      switch (language) {
        AppLanguage.zh => textToolStepsZh,
        AppLanguage.en => textToolStepsEn,
      };

  static const TextToolStepsStrings textToolStepsZh = TextToolStepsStrings(
    emptyInput: '请输入一个算术式子',
    unsupported: '这一版只做四则运算与整数次幂',
    hint: '例如：\n1 + 2 × 3\n(1 + 2) × 3\n10 - 2 × 3 + 1',
    heading: '每一步',
  );

  static const TextToolStepsStrings textToolStepsEn = TextToolStepsStrings(
    emptyInput: 'Enter an arithmetic expression',
    unsupported: 'This version covers arithmetic and integer powers only',
    hint: 'For example:\n1 + 2 × 3\n(1 + 2) × 3\n10 - 2 × 3 + 1',
    heading: 'Steps',
  );
}
