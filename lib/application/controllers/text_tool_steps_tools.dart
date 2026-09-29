part of 'text_tool_controller.dart';

/// 中文：**算术分步工具。**
///
///       `1 + 2 × 3` →
///       ```
///       1 + 6
///       7
///       ```
///       每一步是**整条式子的下一个形态**——这与 HiPER 那一版的样子一致，
///       而它是本仓对照表里**最后一条"它有、我们没有"**（`9272048` 落地，`f1eae0e` 之后挂上来）。
///
///       **它不经过引擎**（`lib/core/math/arithmetic_steps.dart` 是纯函数），
///       所以**单测就是全部证据**，与求导分步、进制换算同一条判据。
///
///       ⚠️ **不支持的一律说清楚**：变量、函数、后缀、单位、负指数、非整数指数都不在这里——
///       这一版的题目是**算术的运算顺序**，别的会把"先算哪一步"变成另一个问题。
/// English: **the arithmetic-stepper tool.**
///
///          `1 + 2 × 3` → `1 + 6` → `7`, each step being **the whole expression's next form** — the shape
///          HiPER's version has, and the last "it has it, we did not" on this project's comparison table
///          (landed in `9272048`, wired up after `f1eae0e`).
///
///          **It does not go through the engine** (`lib/core/math/arithmetic_steps.dart` is a pure function),
///          so **the unit tests are the whole proof**, the same judgement as the derivative steps and base
///          conversion.
///
///          ⚠️ **What is not supported is said plainly**: variables, calls, postfixes, units, negative and
///          non-integer exponents are all out — this version's subject is **the order of arithmetic
///          operations**, and anything else turns "which step first" into a different question.
TextToolOutput _arithmeticSteps(TextToolStepsStrings strings, String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return TextToolOutput(strings.emptyInput, strings.hint, hasError: true);
  }
  final result = arithmeticSteps(trimmed);
  if (result == null) {
    return TextToolOutput(strings.unsupported, strings.hint, hasError: true);
  }
  return TextToolOutput(
    result.value!,
    '${strings.heading}\n${result.steps.join('\n')}',
  );
}
