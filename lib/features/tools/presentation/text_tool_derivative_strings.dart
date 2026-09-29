import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：**求导分步工具的文案表。** 与日期、不确定度那两张同形（为什么手写分表、为什么
///       `static final` 而不是 `const`，见 `settings_strings.dart` 的文件头）。
///
///       **本表只翻译"我们的话"，不翻译算式。** `2·x^1·(1)` 那样的式子是**数据**——
///       它是这个工具算出来的东西，两种语言原样出，与日期（`2026-09-20`）、用户打的
///       `12.5 ± 0.3` 是同一条判据。
///
///       ⚠️ **法则名走一张映射表**：`symbolic_derivative.dart` 那边给的是**判据**
///       （`constant`/`product`/`power`…，纯 ASCII 令牌），这边才把它们说成人话。
///       **判据与文案分家**——所以下面那张 `Map<String, String>` 两种语言各一份，
///       而**查不到的名字要露出来**（回原样），不能静默变成空白。
/// English: **the derivative-steps tool's copy table.** Same shape as the date and uncertainty tables
///          (why these are hand-written and why `static final` rather than `const` is on
///          `settings_strings.dart`'s head).
///
///          **This table translates our sentences, not the algebra.** A form like `2·x^1·(1)` is
///          **data** — it is what this tool computed, and it comes back verbatim in both languages, the
///          same ruling that covers dates (`2026-09-20`) and a user's `12.5 ± 0.3`.
///
///          ⚠️ **Rule names go through a map**: `symbolic_derivative.dart` hands over **verdicts**
///          (`constant`/`product`/`power`…, plain ASCII tokens) and this side says them in words.
///          **Verdict and wording part company** — hence one map per language below, and **a name with no
///          entry shows through as itself** rather than silently becoming blank.
@immutable
class TextToolDerivativeStrings {
  const TextToolDerivativeStrings({
    required this.emptyInput,
    required this.unreadable,
    required this.hint,
    required this.stopped,
    required this.resultLine,
    required this.stepLine,
    required this.tidiedLine,
    required this.variableLine,
    required this.absCaveat,
    required this.ruleNames,
  });

  final String emptyInput;

  /// 中文：读不出这个式子。**如实拒绝**，不猜用户想对谁求导。
  /// English: the expression cannot be read. **An honest refusal** — it does not guess which variable.
  final String unreadable;

  final String hint;

  /// 中文：**在某一层停下了**——前面几步照旧给出来，这一句说明后面算不了。
  ///       ⚠️ 它与 [unreadable] **不是同一件事**：那一个是"连式子都没读懂"，
  ///       这一个已经走出几步了。分开是因为用户能做的事不同。
  /// English: **it stopped at some level** — the earlier steps are still shown and this says the rest
  ///          cannot be done. ⚠️ It is **not** the same as [unreadable]: that one means the expression
  ///          itself was not understood, while this one has already produced steps. They are kept apart
  ///          because the user can do different things about them.
  final String stopped;

  final String Function(String derivative) resultLine;
  final String Function(int index, String expression, String rule) stepLine;

  /// 中文：**收拾过的那一行**（`= 2·x`）。只在它与推导的最后一步**不同**时才印——
  ///       相同的时候再印一遍等于说两遍同一件事。
  /// English: **the tidied line** (`= 2·x`). Printed only when it **differs** from the derivation's last
  ///          step — printing it when identical would say the same thing twice.
  final String Function(String expression) tidiedLine;

  /// 中文：**表明对谁求导。** 变量不再写死为 `x`（输入里可以点名），所以屏幕上必须有这一行——
  ///       否则用户看不出这一次是对哪个字母求的，而**对 `y` 与对 `x` 的答案完全不同**。
  /// English: **which variable it differentiated with respect to.** The variable is no longer hard-wired
  ///          to `x` (the input may name it), so this line has to be on screen — otherwise the user cannot
  ///          tell which letter was used, and **the answer for `y` and for `x` differ entirely**.
  final String Function(String variable) variableLine;

  /// 中文：**`abs` 的边界。** `x/|x|` 在 0 处没有定义——**这句话必须有地方说**，
  ///       否则那条推导在 0 点上就是一条骗人的推导（这正是它此前被拒绝的理由，
  ///       而现在有地方放了）。
  /// English: **`abs`'s boundary.** `x/|x|` is undefined at 0 — **this sentence needs somewhere to live**,
  ///          or the derivation lies at the point 0 (which is exactly why it used to be refused, and there
  ///          is somewhere for it now).
  final String absCaveat;

  /// 中文：判据 → 人话。**查不到的名字回原样**（见文件头）。
  /// English: verdict → words. **A name with no entry comes back as itself** (see the head).
  final Map<String, String> ruleNames;

  String rule(String name) => ruleNames[name] ?? name;

  static TextToolDerivativeStrings of(BuildContext context) =>
      forLanguage(AppLanguage.of(context));

  /// 中文：与 [of] 同一张分派表。**`switch` 穷尽 `AppLanguage`**。
  /// English: the same dispatch as [of]; the **`switch` exhausts `AppLanguage`**.
  static TextToolDerivativeStrings forLanguage(AppLanguage language) =>
      switch (language) {
        AppLanguage.zh => textToolDerivativeZh,
        AppLanguage.en => textToolDerivativeEn,
      };

  static final TextToolDerivativeStrings textToolDerivativeZh =
      TextToolDerivativeStrings(
    emptyInput: '请输入一个要对其求导的式子',
    unreadable: '读不出一个完整的式子',
    hint: '例如：\nx^2\n3x^2 + 2x\nx * x',
    stopped: '这一步还不会算，上面的推导到这里为止',
    resultLine: (derivative) => derivative,
    stepLine: (index, expression, rule) => '$index. $expression    （$rule）',
    tidiedLine: (expression) => '= $expression',
    variableLine: (variable) => '对 $variable 求导',
    absCaveat: '绝对值在 0 处不可导，那里的导数不存在',
    ruleNames: const <String, String>{
      'constant': '常数的导数是 0',
      'self': '对自身求导得 1',
      'other': '不含要求导的那个变量',
      'sum': '和的导数等于各项导数之和',
      'negate': '负号提到外面',
      'product': '乘法法则',
      'power': '幂法则',
      'chain': '链式法则',
      'chain_caveat': '链式法则（绝对值见下）',
    },
  );

  static final TextToolDerivativeStrings textToolDerivativeEn =
      TextToolDerivativeStrings(
    emptyInput: 'Enter an expression to differentiate',
    unreadable: 'No complete expression could be read',
    hint: 'For example:\nx^2\n3x^2 + 2x\nx * x',
    stopped: 'This step is not handled yet; the derivation above is where it stops',
    resultLine: (derivative) => derivative,
    stepLine: (index, expression, rule) => '$index. $expression    ($rule)',
    tidiedLine: (expression) => '= $expression',
    variableLine: (variable) => 'with respect to $variable',
    absCaveat: 'The absolute value is not differentiable at 0; the derivative does not exist there',
    ruleNames: const <String, String>{
      'constant': 'the derivative of a constant is 0',
      'self': 'the variable differentiates to 1',
      'other': 'does not contain the variable',
      'sum': 'the derivative of a sum is the sum of the derivatives',
      'negate': 'the sign comes out',
      'product': 'the product rule',
      'power': 'the power rule',
      'chain': 'the chain rule',
      'chain_caveat': 'the chain rule (see the note on the absolute value)',
    },
  );
}
