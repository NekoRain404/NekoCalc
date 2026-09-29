part of 'text_tool_controller.dart';

/// 中文：**求导分步工具。**
///
///       **它是清单上唯一一条「我们比它强」而不是追平它的路**：HiPER 的分步是
///       **十进制 / 表达式模式**的（把 `1+2×3` 拆成"先乘后加"给你看），**对求导不给步骤**。
///
///       ⚠️ **它不经过引擎。** 应用早有引擎版的 `diff`（`diff(x^2,x)` → `2x`），
///       但**引擎不给推导过程**，而这一步要的正是过程。所以规则在
///       `lib/core/math/symbolic_derivative.dart` 里自己写——那是一个**纯函数**，
///       于是**单测就是全部证据，不必等真机**（能绕开引擎时单测的证明力比真机强）。
///
///       **它输出什么**：`primary` 是导数，`detail` 是一步一行的推导，每行右边写**用了哪条法则**。
///       停在某一层时，前面几步照旧给出来，并在末尾说明——**绝不悄悄跳过一步**：
///       用户看到一条推导会相信它完整，所以"少了一步"与"结果少了一项"是同一类错。
///
///       ⚠️ **第一版不做化简。** `2·x^1·(1)` 那样的输出**不是错**，它就是幂法则写出来的样子
///       （见 `symbolic_derivative.dart` 的文件头：该化到什么程度没有唯一答案）。
/// English: **the derivative-steps tool.**
///
///          **It is the one path on the list that is better than HiPER rather than catching up to it**:
///          HiPER's step-by-step is **decimal / expression-mode** (it shows `1+2×3` as "multiply first,
///          then add") and gives **no steps for a derivative**.
///
///          ⚠️ **It does not go through the engine.** The app has long had an engine-backed `diff`
///          (`diff(x^2,x)` → `2x`), but **the engine does not give its working**, which is exactly what is
///          wanted here. So the rules are written out in `lib/core/math/symbolic_derivative.dart` — a
///          **pure function**, so **the unit tests are the whole proof and no device is needed**.
///
///          **What it returns**: `primary` is the derivative and `detail` is the derivation one step per
///          line, each line naming **which rule** it used. When it stops at some level the earlier steps
///          are still shown and the end says so — **a step is never skipped quietly**: a user who sees a
///          derivation believes it is complete, so "a missing step" and "a missing term" are the same
///          kind of error.
///
///          ⚠️ **The first version does no simplification.** Output like `2·x^1·(1)` **is not wrong** — it
///          is what the power rule reads like.
TextToolOutput _deriveSteps(TextToolDerivativeStrings strings, String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return TextToolOutput(strings.emptyInput, strings.hint, hasError: true);
  }
  // 中文：**变量可以点名，也可以不点。** 不点就按 `x`（应用自己的惯例），
  //       点了就按点名的那个——两种写法都收：
  //
  //       - `diff(x^2, y)`——**这正是应用自己的写法**：`d/dx` 那颗键（`∫dx` 的 SHIFT 变体）
  //         插的就是 `diff(x^2,x)`（两个槽，引擎自己的实参顺序），所以用户手里拿到的原文就是它；
  //       - `d/dy(x^2)`——同一件事的另一半写法，顺手也收。
  //
  //       ⚠️ **仍然不许"猜"变量。** 两种写法都是**用户明写的**；猜出来的变量会给出一个
  //       **看着像答案的错值**（对 `y` 与对 `x` 求导结果完全不同）。所以：
  //       写不出变量名就退回默认的 `x` 并在屏幕上**说明是对谁求的**（见 `variableLine`）。
  // English: **the variable may be named, or may be left out.** Left out it follows this app's convention
  //          (`x`); named it is used — both spellings are accepted:
  //
  //          - `diff(x^2, y)` — **this is the app's own spelling**: the `d/dx` key (the SHIFT variant of
  //            `∫dx`) inserts `diff(x^2,x)` (two slots, the engine's own argument order), so this is the
  //            text the user already has;
  //          - `d/dy(x^2)` — the other half of the same notation, accepted as a courtesy.
  //
  //          ⚠️ **The variable is still never guessed.** Both spellings are **written by the user**; a
  //          guessed variable would give **a wrong value that looks like an answer** (differentiating with
  //          respect to `y` and to `x` differ entirely). So: when no variable can be read, it falls back to
  //          `x` and the screen **says which one was used** (see `variableLine`).
  final request = _derivativeRequest(trimmed);
  final result = differentiate(request.expression, request.variable);

  if (result.refusal == 'unreadable') {
    return TextToolOutput(strings.unreadable, strings.hint, hasError: true);
  }

  final lines = <String>[];
  for (var index = 0; index < result.steps.length; index++) {
    final step = result.steps[index];
    lines.add(
        strings.stepLine(index + 1, step.expression, strings.rule(step.rule)));
  }
  if (result.refusal != null) {
    // 中文：**停下时也要把已经走出来的几步印出来。** 整条清空也安全，但用户会以为
    //       "这个式子完全算不了"，而他其实已经看到了一半。
    // English: **when it stops, the steps already produced are still printed.** Wiping them would also
    //          be safe, but the user would conclude the whole expression is unsupported when in fact half
    //          of it worked.
    lines.add(strings.stopped);
    return TextToolOutput(
      // 中文：一条步骤都没走出来时，主结果说"这一步还不会算"——**不是"读不出"**：
      //       式子读懂了，只是这一层不在规则表里。
      // English: with no steps at all, the primary says "this step is not handled yet" — **not
      //          "unreadable"**: the expression was read, this level is simply outside the rule table.
      result.steps.isEmpty ? strings.stopped : result.steps.last.expression,
      lines.join('\n'),
      hasError: true,
    );
  }

  // 中文：**结果行给"收拾过"的那个，推导里保留法则的样子。** 两个都要：
  //       只给推导，用户得自己收拾；只给结果，"用了哪条法则"就没了——而那正是这个工具的全部意义。
  //       收拾只做恒等式（去乘 1、去加 0、去一次方），**不做排版**，所以 `2·x` 不会变成 `2x`——
  //       那条界线写在 `simplifyDerivative` 上。
  // English: **the result line carries the tidied form while the derivation keeps what the rules look
  //          like.** Both are needed: with only the derivation the user does the tidying, with only the
  //          result the "which rule was used" is gone — and that is this tool's whole point. The tidying
  //          does identities only (no multiply-by-1, no add-0, no first power) and **no typography**, so
  //          `2·x` does not become `2x` — the line is drawn on `simplifyDerivative`.
  final tidied = result.simplified;
  if (tidied != null && tidied != result.derivative) {
    lines.add(strings.tidiedLine(tidied));
  }
  return TextToolOutput(
    strings.resultLine(tidied ?? result.derivative!),
    lines.join('\n'),
    // 中文：**屏幕上要说清是对谁求的。** 变量不再写死，用户看不出这一点就会把
    //       "对 x 求导"的答案当成"对 y 求导"的。
    // English: **the screen has to say which variable was used.** The variable is no longer hard-wired, and
    //          a user who cannot see that would take a `d/dx` answer for a `d/dy` one.
    insights: <String>[
      strings.variableLine(request.variable),
      // 中文：**用了 `abs` 就把边界说出来。** 判据读的是**步骤里那一条法则令牌**
      //       （`chain_caveat`），不是回读印出来的句子——与 `variableLine` 同一条规矩。
      // English: **when `abs` was used, the boundary is said.** The judgement reads **the rule token in
      //          the steps** (`chain_caveat`) rather than the printed sentence — the same rule as
      //          `variableLine`.
      if (result.steps.any((step) => step.rule == DerivativeRules.chainWithCaveat))
        strings.absCaveat,
    ],
  );
}

/// 中文：**从输入里读出"对谁求导"**，返回 `(式子, 变量)`；没点名就用 `x`。
///
///       只认两种写法，都是**用户明写的**：
///       `diff(<式子>, <一个字母>)`（应用自己的写法，`d/dx` 那颗键插的就是它）
///       与 `d/d<一个字母>(<式子>)`。
///       其余一律当成裸式子，变量取 `x`——**不猜**。
/// English: **read "with respect to which variable" out of the input**, returning `(expression, variable)`;
///          with nothing named it uses `x`.
///
///          Two spellings only, both **written by the user**: `diff(<expr>, <one letter>)` (this app's own
///          spelling — the one the `d/dx` key inserts) and `d/d<one letter>(<expr>)`. Anything else is
///          treated as a bare expression with the variable `x` — **nothing is guessed**.
({String expression, String variable}) _derivativeRequest(String input) {
  final diff = RegExp(r'^diff\((.*),\s*([A-Za-z])\)$').firstMatch(input);
  if (diff != null) {
    return (expression: diff.group(1)!.trim(), variable: diff.group(2)!);
  }
  final operator = RegExp(r'^d/d([A-Za-z])\((.*)\)$').firstMatch(input);
  if (operator != null) {
    return (expression: operator.group(2)!.trim(), variable: operator.group(1)!);
  }
  return (expression: input, variable: 'x');
}
