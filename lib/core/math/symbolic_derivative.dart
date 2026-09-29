/// 中文：**符号求导，一步一步写出来。**
///
///       **为什么要有这一条。** HiPER 的分步是**十进制 / 表达式模式**的——它把 `1+2×3` 拆成
///       "先乘后加"给你看，但**对求导不给步骤**。所以这是本项目清单上
///       **唯一一条「我们比它强」而不是追平它**的路。
///
///       ⚠️ **它不是"用引擎求导"。** 应用早就有引擎版的 `diff`（`diff(x^2,x)` → `2x`）。
///       这一条要的是**步骤**，而步骤只能自己算——引擎不给推导过程。
///
///       **它整条不碰引擎**，所以**单测就是全部证据**（与 `convertToBase` / `toRoman` 同一条判据：
///       能绕开引擎时，单测的证明力比真机强）。**这一条不需要真机。**
///
///       **穷尽性由类型系统保证。** 输入是 `sealed` 的 `ExprNode`，所以两个 `switch` 都必须覆盖
///       全部 12 个节点——**加一个节点类型，`flutter analyze` 直接报错**
///       （`non_exhaustive_switch_statement`，与翻译器同一条论证，见 `engine_expression.dart` 文件头）。
///
///       ⚠️ **表外的节点一律停下并说明，绝不悄悄跳过。** "步骤里少了一步"与
///       "结果里少了一项"是同一类错：**用户看到一条推导，会相信它完整**。
///       所以 [DerivativeResult.refusal] 非空时，`steps` 里那几步是**走到哪里停的**。
///
///       **第一版不做化简。** `2x·1 + x²·0` 那种输出**不是错**，它就是乘法法则的样子；
///       化简是另一件事，而且"该化到什么程度"没有唯一答案。
///       **把法则如实印出来就已经比 HiPER 多。**
/// English: **symbolic differentiation, written out step by step.**
///
///          **Why this exists.** HiPER's step-by-step is **decimal / expression-mode** — it shows
///          `1+2×3` as "multiply first, then add", but gives **no steps for a derivative**. So this is
///          the one path in this project that is **better than HiPER rather than catching up to it**.
///
///          ⚠️ **It is not "differentiate with the engine".** This app has had an engine-backed `diff`
///          for a long time (`diff(x^2,x)` → `2x`). What is wanted here is the **steps**, and steps can
///          only be computed here — the engine does not give its working.
///
///          **It does not touch the engine at all**, so **the unit tests are the whole proof** (the same
///          judgement as `convertToBase` / `toRoman`: when the engine can be bypassed, unit tests prove
///          more than a device). **This one needs no device.**
///
///          **Exhaustiveness is the type system's.** The input is a `sealed` `ExprNode`, so both
///          `switch`es must cover all twelve nodes — **adding a node type makes `flutter analyze` report
///          it** (`non_exhaustive_switch_statement`, the same argument as the translator's; see
///          `engine_expression.dart`'s head).
///
///          ⚠️ **A node outside the table stops the derivation and says so; it never skips quietly.** "A
///          missing step" and "a missing term" are the same kind of error: **a user who sees a
///          derivation believes it is complete**. So while [DerivativeResult.refusal] is non-null,
///          `steps` holds the steps up to where it stopped.
///
///          **The first version does no simplification.** Output like `2x·1 + x²·0` **is not wrong** — it
///          is what the product rule looks like; simplification is another matter and "how far to
///          simplify" has no single answer. **Printing the rules honestly is already more than HiPER.**
library;

import 'ast/expression_ast_parser.dart';

/// 中文：推导里的一步。`expression` 是这一步写出来的式子，`rule` 是**用哪条法则**。
/// English: one step of the derivation. `expression` is the form written out at this step and `rule` is
///          **which rule** was used.
typedef DerivativeStep = ({String expression, String rule});

/// 中文：一次求导的结果。
///
///       - [derivative] 非空 ⇒ 走通了，[steps] 是完整推导（含最后一步）；
///       - [refusal] 非空 ⇒ **在某一层停下来了**，[steps] 是走到那里为止的推导。
///         两者**不会同时非空**，也**不会同时为空**。
/// English: the outcome of one differentiation.
///
///          - a non-null [derivative] ⇒ it went through and [steps] is the complete derivation (the last
///            step included);
///          - a non-null [refusal] ⇒ **it stopped at some level** and [steps] is the derivation up to
///            there. The two are **never both non-null and never both null**.
typedef DerivativeResult = ({
  String? derivative,
  List<DerivativeStep> steps,
  String? refusal,
});

/// 中文：法则的名字。**它们是判据不是文案**——界面上那句话由表来拼（本项目「判据与文案分家」）。
/// English: the rule names. **They are verdicts, not wording** — the sentence on screen is assembled by
///          the string table, per this project's "verdict and wording part company".
class DerivativeRules {
  const DerivativeRules._();

  static const String constant = 'constant';
  static const String self = 'self';
  static const String other = 'other';
  static const String sum = 'sum';
  static const String negate = 'negate';
  static const String product = 'product';
  static const String power = 'power';
  static const String chain = 'chain';
}

/// 中文：**对 [variable] 求导，并把每一步写出来。**
///
///       读不出（解析失败 / 空输入）时回一个只有 `refusal` 的结果——**没有步骤可说**。
/// English: **differentiate with respect to [variable], writing out every step.**
///
///          When it cannot be read (a parse failure, an empty input) the result carries only a
///          `refusal` — **there are no steps to show**.
DerivativeResult differentiate(String source, String variable) {
  // 中文：**空输入要挡在这里。** 解析器把空串读成一个常量（于是求导得 `0`），
  //       而"没有输入"与"输入了一个常数"是两件事——后者是答案，前者不是。
  // English: **an empty input is caught here.** The parser reads an empty string as a constant (so the
  //          derivative comes out `0`), while "nothing was typed" and "a constant was typed" are two
  //          different things — the second is an answer and the first is not.
  if (source.trim().isEmpty) {
    return (derivative: null, steps: const [], refusal: 'unreadable');
  }
  final tree = const ExpressionAstParser().parse(source);
  if (tree is ParseErrorNode) {
    return (derivative: null, steps: const [], refusal: 'unreadable');
  }
  // 中文：⚠️ **解析器会接受一个前缀、把后面剩下的丢掉。** 这是量出来的：`2+` 解析出来的是一棵
  //       **常数**树（于是求导得 `0`），而不是解析错误——测试第一版抓到的就是这个。
  //       每个节点都带 `[start, end)` 覆盖面，所以"读完了没有"是**可以问的**：
  //       末尾没被覆盖 ⇒ 有东西没读懂 ⇒ **拒绝**。
  //
  //       **不带上这一条，`2+` 会被当成 `2` 求导**——那与 `x<=3` 被读成 `x<`、
  //       方程被读成表达式是同一类：**读了一半就当成读完了**。
  // English: ⚠️ **the parser accepts a prefix and drops the rest.** This was measured: `2+` parses into a
  //          **constant** tree (so the derivative comes out `0`) rather than a parse error — which is what
  //          the first version of the test caught. Every node carries a `[start, end)` span, so "was it
  //          all read" **is askable**: an uncovered tail means something was not understood ⇒ **refuse**.
  //
  //          **Without this, `2+` would be differentiated as `2`** — the same class as `x<=3` read as
  //          `x<`, or an equation read as an expression: **half of it read, and taken for the whole.**
  if (tree.end != source.length) {
    return (derivative: null, steps: const [], refusal: 'unreadable');
  }
  final steps = <DerivativeStep>[];
  final result = _differentiate(tree, variable, steps);
  if (result == null) {
    return (derivative: null, steps: steps, refusal: steps.isEmpty ? 'unreadable' : 'stopped');
  }
  // 中文：**不在这里补一步。** 推导是递归自己的副产品（每一步在用到它的那一层记下），
  //       这里再补一条就会把根那一步**记两遍**——测试第一版抓到的就是这个：
  //       `x + 3` 的步骤成了 `['1', '0', '1 + 0', '1 + 0']`。
  // English: **no step is added here.** The derivation is a by-product of the recursion (each step is
  //          recorded at the level that used it); adding one here would record the root step **twice** —
  //          which is exactly what the first version of the test caught: `x + 3` came out as
  //          `['1', '0', '1 + 0', '1 + 0']`.
  return (derivative: result, steps: steps, refusal: null);
}

/// 中文：求导的递归。**回 `null` 就是"这一层不会"**——调用方据此停下，**不猜**。
///
///       每一步都把自己用的法则记进 [steps]，所以推导是**这份递归的副产品**，
///       不是事后再走一遍树——**两遍就会有两份说法**。
/// English: the recursion. **`null` means "this level is not handled"** — the caller stops there and
///          **does not guess**.
///
///          Each step records the rule it used into [steps], so the derivation is a **by-product of this
///          recursion** rather than a second walk over the tree — **two walks would be two accounts**.
String? _differentiate(ExprNode node, String variable, List<DerivativeStep> steps) {
  switch (node) {
    case NumberNode(:final literal):
      // 中文：⚠️ **空的数字字面量不是数字。** 解析器对 `2+` 会造出一个**字面量为空**的数字节点，
      //       而那个节点一路走到这里就会被当成"常数 0"——于是 `2+` 求导出 `0`，**看着像答案**。
      //       测试第一版抓到的就是这个（`2+` 的步骤里冒出一条 `constant`）。
      //       判据放在这里而不是"整句读完了没有"：那种检查在这一例上**通不出问题**
      //       （树覆盖面是整句，`+` 被吃进去了）。
      // English: ⚠️ **an empty numeric literal is not a number.** The parser builds a number node with an
      //          **empty literal** for `2+`, and that node would be taken for "the constant 0" right here —
      //          so `2+` would differentiate to `0`, **looking like an answer**. The first version of the
      //          test caught exactly this. The judgement sits here rather than on "was the whole sentence
      //          read": that check **cannot see this case** (the tree spans the whole sentence; the `+` was
      //          swallowed).
      if (literal.trim().isEmpty) return null;
      _record(steps, '0', DerivativeRules.constant);
      return '0';
    case SexagesimalNode():
      _record(steps, '0', DerivativeRules.constant);
      return '0';
    case ConstantNode():
      // 中文：**常量对谁求导都是 0**——包括 `pi`、`e`。它们不是 [variable]。
      // English: **a constant differentiates to 0 whatever the variable** — `pi` and `e` included. They
      //          are not [variable].
      _record(steps, '0', DerivativeRules.constant);
      return '0';
    case VariableNode(:final name):
      final rule =
          name == variable ? DerivativeRules.self : DerivativeRules.other;
      _record(steps, name == variable ? '1' : '0', rule);
      return name == variable ? '1' : '0';
    case GroupNode(:final child):
      // 中文：括号**不是一步**——它不改变任何东西，给它记一条法则只会让推导看着更长。
      // English: brackets are **not a step** — they change nothing, and recording a rule for them would
      //          only make the derivation look longer.
      return _differentiate(child, variable, steps);
    case UnaryNode(:final op, :final operand):
      if (op != '-') return null;
      final inner = _differentiate(operand, variable, steps);
      if (inner == null) return null;
      final text = '-($inner)';
      _record(steps, text, DerivativeRules.negate);
      return text;
    case BinaryNode(:final op, :final left, :final right):
      return _differentiateBinary(op, left, right, variable, steps);
    case ImplicitProductNode(:final left, :final right):
      // 中文：`2x` 那种写法在树里是**隐式乘法**，法则与显式乘法**同一条**——
      //       分成两条只会让"乘法法则"有两个说法。
      // English: `2x` is an **implicit product** in the tree and takes **the same rule** as an explicit
      //          one — two branches would give "the product rule" two spellings.
      return _differentiateBinary('*', left, right, variable, steps);
    case FunctionNode():
    case PostfixNode():
    case OperatorNode():
    case ParseErrorNode():
      // 中文：这几个**在这一版里没有意义或不支持**——如实停下。
      // 中文：**表外的节点停下来。** 链式法则留给下一版；`!`、独立的 `+`/`-`、解析错误
      //       在这一版里没有意义，**如实说"这一层不会"，不跳过去**。
      // English: **a node outside the table stops it.** The chain rule is for a later version; `!`, a
      //          standalone `+`/`-` and a parse error have no meaning here — **say "this level is not
      //          handled" rather than skipping over it**.
      return null;
  }
}

String? _differentiateBinary(
  String op,
  ExprNode left,
  ExprNode right,
  String variable,
  List<DerivativeStep> steps,
) {
  switch (op) {
    case '+':
    case '-':
      final leftText = _differentiate(left, variable, steps);
      if (leftText == null) return null;
      final rightText = _differentiate(right, variable, steps);
      if (rightText == null) return null;
      final text = '$leftText $op $rightText';
      _record(steps, text, DerivativeRules.sum);
      return text;
    case '*':
      final leftText = _differentiate(left, variable, steps);
      if (leftText == null) return null;
      final rightText = _differentiate(right, variable, steps);
      if (rightText == null) return null;
      final text = '${_render(left)}·$leftText + ${_render(right)}·$rightText';
      _record(steps, text, DerivativeRules.product);
      return text;
    case '^':
      // 中文：**只做"指数是常数"那一支**（幂法则）。指数里含变量要走对数求导法，
      //       那是另一条规则，**这一版不做就如实停下**。
      // English: **only the "constant exponent" branch** (the power rule). A variable in the exponent
      //          needs logarithmic differentiation, a different rule — **this version stops honestly.**
      final exponent = _constantValue(right);
      final base = _render(left);
      if (exponent == null || base == null) return null;
      final innerText = _differentiate(left, variable, steps);
      if (innerText == null) return null;
      final reduced = _formatNumber(exponent - 1);
      final coefficient =
          exponent == 1 ? '' : '${_formatNumber(exponent)}·';
      final text = exponent == 1
          ? innerText
          : '$coefficient$base^$reduced·($innerText)';
      _record(steps, text, DerivativeRules.power);
      return text;
    default:
      return null;
  }
}

void _record(List<DerivativeStep> steps, String expression, String rule) {
  steps.add((expression: expression, rule: rule));
}

/// 中文：这个节点是不是一个**常数**（数字，或带负号的数字）。不是就回 `null`。
/// English: whether this node is a **constant** (a number, optionally negated); `null` otherwise.
num? _constantValue(ExprNode node) {
  switch (node) {
    case NumberNode(:final literal):
      return num.tryParse(literal.replaceAll('_', ''));
    case UnaryNode(:final op, :final operand) when op == '-':
      final inner = _constantValue(operand);
      return inner == null ? null : -inner;
    case GroupNode(:final child):
      return _constantValue(child);
    default:
      return null;
  }
}

/// 中文：**把这棵树写回应用的写法**（`3x^2`、`x + 1`）。写不出来的节点回 `null`，
///       由调用方当作"这一层不会"。
///
///       ⚠️ **不做任何改写**：不加括号的优化、不合并项、不排序——它只是把树**念出来**。
///       任何"顺手化简"都会让推导里的一步与用户打的式子长得不一样，而那是**另一种错值**。
/// English: **write this tree back in the app's spelling** (`3x^2`, `x + 1`). A node that cannot be
///          written returns `null`, which the caller treats as "this level is not handled".
///
///          ⚠️ **No rewriting at all**: no bracket optimisation, no merging, no reordering — it reads the
///          tree out loud and nothing more. Any "helpful simplification" would make a step look
///          different from what the user typed, which is **another kind of wrong value**.
String? _render(ExprNode node) {
  switch (node) {
    case NumberNode(:final literal):
      return literal.replaceAll('_', '');
    case SexagesimalNode():
      return null;
    case ConstantNode(:final name):
      return name;
    case VariableNode(:final name):
      return name;
    case GroupNode(:final child):
      final inner = _render(child);
      return inner == null ? null : '($inner)';
    case OperatorNode(:final op):
      return op;
    case UnaryNode(:final op, :final operand):
      final inner = _render(operand);
      return inner == null ? null : '$op$inner';
    case BinaryNode(:final op, :final left, :final right):
      final leftText = _render(left);
      final rightText = _render(right);
      if (leftText == null || rightText == null) return null;
      return '$leftText $op $rightText';
    case ImplicitProductNode(:final left, :final right):
      final leftText = _render(left);
      final rightText = _render(right);
      if (leftText == null || rightText == null) return null;
      return '$leftText$rightText';
    case PostfixNode(:final op, :final operand):
      final inner = _render(operand);
      return inner == null ? null : '$inner$op';
    case FunctionNode(:final name, :final args):
      final parts = <String>[];
      for (final arg in args) {
        final text = _render(arg);
        if (text == null) return null;
        parts.add(text);
      }
      return '$name(${parts.join(', ')})';
    case ParseErrorNode():
      return null;
  }
}

/// 中文：印一个数——整数不印小数点（`2` 而不是 `2.0`）。
/// English: print a number — integers get no decimal point (`2`, not `2.0`).
String _formatNumber(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
