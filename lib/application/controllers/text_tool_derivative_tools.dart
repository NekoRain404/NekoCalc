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
  // 中文：**对谁求导由工具决定，不由用户写。** 应用自己的语法里 `x`/`y`/`i` 是仅有的三个变量名，
  //       而单变量语境下默认对 `x`——**写死在这里而不是从输入里猜**：
  //       猜错变量会给出一个**看着像答案的错值**（对 `y` 与对 `x` 求导结果完全不同）。
  // English: **which variable is ours to decide, not something the user writes.** This app's grammar has
  //          exactly three variable names (`x`/`y`/`i`) and single-variable differentiation defaults to
  //          `x` — **fixed here rather than guessed from the input**: guessing wrong gives **a wrong value
  //          that looks like an answer** (differentiating with respect to `y` and to `x` differ entirely).
  const variable = 'x';
  final result = differentiate(trimmed, variable);

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
      result.steps.isEmpty ? strings.unreadable : result.steps.last.expression,
      lines.join('\n'),
      hasError: true,
    );
  }

  return TextToolOutput(
    strings.resultLine(result.derivative!),
    lines.join('\n'),
  );
}
