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
  String? simplified,
});

/// 中文：**把推导的结果收拾成"人会写的那个样子"——只做恒等式，不做任何取舍。**
///
///       ⚠️ **它与"化简"不是一件事，界线要划清。**
///       这里做的每一条都是**恒等式**，在任何取值下都成立，也**不改变什么被算了出来**：
///
///       | 收拾掉 | 因为 |
///       |---|---|
///       | `·1` / `·(1)` / `1·` | 乘 1 不改值 |
///       | `^1` | 一次方就是它自己 |
///       | ` + 0` / `0 + ` | 加 0 不改值 |
///
///       **它不做的事**（这些才是"化简"，而它们都有取舍，所以留给下一版）：
///       合并同类项、重新排序、展开括号、把 `2·x` 写成 `2x` 之外的任何排版决定。
///
///       ⚠️ **它只作用于这份推导自己生成的那些形状**（`symbolic_derivative.dart` 自己拼的字符串），
///       不是通用的代数改写器——**所以每条规则都带边界**（`^1` 后面不许跟数字，
///       否则 `x^12` 会被吃成 `x^2`；`1·` 前面不许是数字，否则 `21·x` 会被吃成 `2·x`）。
///       **通用改写器是另一个量级的东西，而这个工具只需要收拾自己吐出来的那一份。**
/// English: **tidies the derivation's result into the shape a human would write — identities only, no
///          judgement calls.**
///
///          ⚠️ **This is not "simplification", and the line has to be drawn.**
///          Every rule here is an **identity** that holds for every value and **changes nothing about what
///          was computed** (see the table in the Chinese section: `·1`, `·(1)`, `1·`, `^1`, ` + 0`,
///          `0 + `).
///
///          **What it does not do** (these are the real simplifications and each involves a judgement, so
///          they are left for a later version): collecting like terms, reordering, expanding brackets, or
///          any typographic decision beyond what is listed.
///
///          ⚠️ **It only touches the shapes this derivation itself generates** (the strings
///          `symbolic_derivative.dart` builds), not being a general algebra rewriter — **so every rule
///          carries a boundary** (`^1` may not be followed by a digit or `x^12` becomes `x^2`; `1·` may not
///          be preceded by a digit or `21·x` becomes `2·x`). **A general rewriter is a different order of
///          thing, and this tool only needs to tidy what it produced itself.**
String simplifyDerivative(String text) {
  var current = text;
  for (var pass = 0; pass < 8; pass++) {
    final before = current;
    current = current
        .replaceAll('·(1)', '')
        .replaceAll('(1)·', '')
        .replaceAll(RegExp(r'·1(?![\d.])'), '')
        .replaceAll(RegExp(r'(?<![\d.])1·'), '')
        .replaceAll(RegExp(r'\^1(?![\d.])'), '');
    current = current.replaceAll(RegExp(r' \+ 0(?![\d.])'), '').replaceAll(RegExp(r'^0 \+ '), '');
    if (current == before) break;
  }
  return current;
}

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
    return (derivative: null, steps: const [], refusal: 'unreadable', simplified: null);
  }
  final tree = const ExpressionAstParser().parse(source);
  if (tree is ParseErrorNode) {
    return (derivative: null, steps: const [], refusal: 'unreadable', simplified: null);
  }
  // 中文：⚠️ **"整句读完了没有"必须问树里有没有解析错误，不能只看根节点的覆盖面。**
  //
  //       这是量出来的（本轮那处没查清的地方，现在查清了）。`parse('2+')` 给出的是：
  //
  //       ```
  //       Bin(+, Number("2")[0,1), ParseErrorNode("")[2,2))[0,2)
  //       ```
  //
  //       ——**解析错误是嵌在里面的**，而**根节点照样覆盖整句**（`end == 2 == 长度`）。
  //       所以"根没覆盖到末尾"那条判据在这一例上**看不见问题**；
  //       而"空的数字字面量"也看不见（`2` 是非空的）。
  //       **两道都没用**，而真正的判据一直就在手边：[hasParseError]——
  //       它与 `canExpress` 用的是**同一个**谓词，所以这条判断只有**一个拼法**。
  //
  //       **不带上这一条，`2+` 会被当成 `2` 求导**（屏幕上出现一个看着像答案的 `0`）——
  //       那与 `x<=3` 被读成 `x<`、方程被读成表达式是同一类：
  //       **读了一半就当成读完了。**
  // English: ⚠️ **"was the whole sentence read" has to ask whether the tree holds a parse error, not just
  //          look at the root's span.**
  //
  //          This was measured (the point that was unresolved this round, now settled). `parse('2+')`
  //          gives:
  //
  //          ```
  //          Bin(+, Number("2")[0,1), ParseErrorNode("")[2,2))[0,2)
  //          ```
  //
  //          — the parse error is **nested inside**, while **the root still spans the whole sentence**
  //          (`end == 2 == length`). So "the root does not reach the end" **cannot see this case**, and
  //          neither can "an empty numeric literal" (`2` is not empty). **Both gates were useless**, while
  //          the real judgement was to hand all along: [hasParseError] — the **same** predicate
  //          `canExpress` uses, so this decision has **one spelling**.
  //
  //          **Without it, `2+` is differentiated as `2`** (a `0` that looks like an answer lands on
  //          screen) — the same class as `x<=3` read as `x<`, or an equation read as an expression:
  //          **half of it read, and taken for the whole.**
  if (hasParseError(tree)) {
    return (derivative: null, steps: const [], refusal: 'unreadable', simplified: null);
  }
  final steps = <DerivativeStep>[];
  final result = _differentiate(tree, variable, steps);
  if (result == null) {
    // 中文：**走到这里说明"式子读懂了，只是这一层算不了"**——空输入与解析错误在前面两道闸
    //       已经拦掉了。所以这里一律 `stopped`，**不再看步骤空不空**：
    //       `asin(x)` 一条步骤都没走出来，但它**读懂了**，说"读不出"就是**说岔了**。
    // English: **reaching here means "the expression was read, this level just is not handled"** — an empty
    //          input and a parse error were stopped by the two gates above. So it is always `stopped` and
    //          **no longer depends on whether any steps were produced**: `asin(x)` produces none, but it
    //          **was** read, and calling that "unreadable" is **saying the wrong thing**.
    return (derivative: null, steps: steps, refusal: 'stopped', simplified: null);
  }
  // 中文：**不在这里补一步。** 推导是递归自己的副产品（每一步在用到它的那一层记下），
  //       这里再补一条就会把根那一步**记两遍**——测试第一版抓到的就是这个：
  //       `x + 3` 的步骤成了 `['1', '0', '1 + 0', '1 + 0']`。
  // English: **no step is added here.** The derivation is a by-product of the recursion (each step is
  //          recorded at the level that used it); adding one here would record the root step **twice** —
  //          which is exactly what the first version of the test caught: `x + 3` came out as
  //          `['1', '0', '1 + 0', '1 + 0']`.
  // 中文：**steps 里印的是法则的样子，`simplified` 是收拾过的那个。**
  //       两个都给出来：**推导要能读懂，结果要能用**——只给前者，用户得自己收拾；
  //       只给后者，那些"法则的样子"就没了，而这个工具的全部意义正是它。
  // English: **`steps` carries what the rules look like and `simplified` is the tidied one.** Both are
  //          given: **a derivation has to be readable and a result has to be usable** — with only the
  //          former the user does the tidying, with only the latter the "what the rules look like" is
  //          gone, and that is the whole point of this tool.
  return (
    derivative: result,
    steps: steps,
    refusal: null,
    simplified: simplifyDerivative(result),
  );
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
    case FunctionNode(:final name, :final args):
      // 中文：**链式法则**：`d/dx f(u) = f'(u)·u'`。
      //
      //       外层的导数由 [_outerDerivative] 给（一张小表），内层照常递归——所以
      //       `sin(x^2)` 会先写出内层的幂法则，再写出外层的链式法则，**两层都看得见**。
      //
      //       ⚠️ **只收一个实参**：`atan2(y, x)` 那种二元函数不在链式法则的适用范围里，
      //       **如实停下**，不许把第一个实参当整体。
      // English: **the chain rule**: `d/dx f(u) = f'(u)·u'`.
      //
      //          The outer derivative comes from [_outerDerivative] (a small table) and the inner one
      //          recurses as usual — so `sin(x^2)` writes the inner power rule first and the outer chain
      //          rule after, **both visible**.
      //
      //          ⚠️ **One argument only**: a two-argument function such as `atan2(y, x)` is outside the
      //          chain rule's reach — it **stops honestly** rather than taking the first argument for the
      //          whole.
      if (args.length != 1) return null;
      final outer = _outerDerivative(name, args.single);
      if (outer == null) return null;
      final innerText = _differentiate(args.single, variable, steps);
      if (innerText == null) return null;
      final text = '$outer·($innerText)';
      _record(steps, text, DerivativeRules.chain);
      return text;
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
      // 中文：**指数不空格。** `x ^ 2` 与屏幕上（以及用户手里）的 `x^2` 不是一个写法——
      //       而推导里的一步与用户打的式子长得不一样，本身就是一种错值。
      //       `+`/`-`/`*`/`/` 保留空格：那两个字符连着数字会读错（`x+2` 还行，`x - -2` 不行）。
      // English: **no spaces around the exponent.** `x ^ 2` is not the same spelling as the `x^2` on screen
      //          (and in the user's hands) — and a step that looks different from what the user typed is
      //          itself a kind of wrong value. `+`/`-`/`*`/`/` keep their spaces: those characters next to
      //          digits read wrongly (`x+2` is fine, `x - -2` is not).
      return op == '^' ? '$leftText^$rightText' : '$leftText $op $rightText';
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

/// 中文：**外层的导数**——链式法则里那个 `f'(u)`，写成应用的写法；表外回 `null`。
///
///       表里只有六个，而且**每一个都是可以直接写出来的**：
///
///       | `f(u)` | `f'(u)` |
///       |---|---|
///       | `sin` | `cos(u)` |
///       | `cos` | `-sin(u)` |
///       | `tan` | `1/cos(u)^2` |
///       | `ln` | `1/u` |
///       | `exp` | `exp(u)` |
///       | `sqrt` | `1/(2·sqrt(u))` |
///
///       ⚠️ **表外的一律回 `null`，由调用方停下。** 这是这一版最重要的一条边界：
///       导数写错的函数比"不支持的函数"坏得多——**前者会印出一条看上去很完整的假推导**。
///       所以 `log`/`log2`/`asin`/`abs` 这些**都不在表里**，不是忘了，是**没有量过**
///       （`ln` 与 `exp` 互为反函数、`sqrt` 是幂的特例，这三条是定义给的；其余各有分支，
///       要写就得先想清楚定义域）。
/// English: **the outer derivative** — the `f'(u)` of the chain rule, written in the app's spelling;
///          `null` when outside the table.
///
///          Six entries, each of which can be written straight down (see the table in the Chinese
///          section, which is the same table).
///
///          ⚠️ **Anything outside the table returns `null` and the caller stops.** That is this version's
///          most important boundary: **a wrong derivative is far worse than an unsupported function** —
///          the former prints a plausible-looking, complete, fake derivation. So `log`, `log2`, `asin`
///          and `abs` are **not in the table**, not because they were forgotten but because they were
///          **not measured** (`ln`/`exp` being inverses and `sqrt` being a power case come from the
///          definitions; the others have branches, and writing one means thinking the domain through
///          first).
String? _outerDerivative(String name, ExprNode argument) {
  final u = _render(argument);
  if (u == null) return null;
  switch (name) {
    case 'sin':
      return 'cos($u)';
    case 'cos':
      return '-sin($u)';
    case 'tan':
      return '1/cos($u)^2';
    case 'ln':
      return '1/$u';
    case 'exp':
      return 'exp($u)';
    case 'sqrt':
      return '1/(2·sqrt($u))';
    // 中文：**下面八条是量出来的**——宿主 `qalc` 5.12.0 的 `diff(f(x), x)` 逐条对过
    //       （见 `.superpowers/backup/engine-capability-probe.md` 第十八节）：
    //       `asin` → `1 / sqrt(1 - x^2)`、`atan` → `1 / (x^2 + 1)`、
    //       `log10` → `0.4342944819032518 / x`（= `1/(x·ln 10)`）、`log2` → `1.442695040888963 / x`、
    //       `sinh` → `cosh(x)`、`cosh` → `sinh(x)`、`tanh` → `1 - tanh(x)^2`。
    //       **独立对过**，不是照着定义抄的。
    // English: **the eight below were measured** — host `qalc` 5.12.0's `diff(f(x), x)` checked one by one
    //          (see section 十八 of `.superpowers/backup/engine-capability-probe.md`): `asin` →
    //          `1 / sqrt(1 - x^2)`, `atan` → `1 / (x^2 + 1)`, `log10` → `0.4342944819032518 / x`
    //          (= `1/(x·ln 10)`), `log2` → `1.442695040888963 / x`, `sinh` → `cosh(x)`, `cosh` → `sinh(x)`,
    //          `tanh` → `1 - tanh(x)^2`. **Checked independently**, not copied off the definitions.
    case 'asin':
      return '1/sqrt(1-$u^2)';
    case 'acos':
      return '-1/sqrt(1-$u^2)';
    case 'atan':
      return '1/($u^2+1)';
    case 'log10':
      return '1/($u·ln(10))';
    case 'log2':
      return '1/($u·ln(2))';
    case 'sinh':
      return 'cosh($u)';
    case 'cosh':
      return 'sinh($u)';
    case 'tanh':
      return '1-tanh($u)^2';
    default:
      // 中文：⚠️ **两条刻意不在表里，理由各是一条，不是"忘了"：**
      //
      //       - **`abs`**：引擎给的是 `x / |x|`，而那个式子在 **`x = 0` 处没有定义**——
      //         `|x|` 在那里不可导（左右导数一正一负）。**这个工具没有地方说这句话**
      //         （每一步只有"式子"与"法则"两栏），于是印出来的是一条**在 0 点上骗人的**推导。
      //         宁可停下。**这是量过之后才敢下的判断**，不是"没有量过"。
      //       - **`log`**：**两边指的不是同一个函数**——引擎的 `log` 是自然对数（实测
      //         `diff(log(x), x)` → `1 / x`），而计算器上的 `log` 惯例是以 10 为底，
      //         应用自己那个词表里 `log` 到底映射到哪一边**这一轮没有核实**。
      //         **两边定义不同的拼写，本仓一律拒绝**（`mod`、`!=` 都是这样处理）。
      //
      //       **导数写错的函数比"不支持的函数"坏得多**：前者会印出一条看上去很完整的假推导。
      // English: ⚠️ **two are deliberately absent, each for its own reason, neither forgotten:**
      //
      //          - **`abs`**: the engine gives `x / |x|`, and that form is **undefined at `x = 0`** —
      //            `|x|` is not differentiable there (the two one-sided derivatives differ in sign). **This
      //            tool has nowhere to say so** (a step carries only "the expression" and "the rule"), so
      //            what gets printed is a derivation that **lies at the point 0**. Better to stop. **That
      //            judgement follows measurement**, rather than being "it was never measured".
      //          - **`log`**: **the two sides do not mean the same function** — the engine's `log` is the
      //            natural log (measured: `diff(log(x), x)` → `1 / x`), while a calculator's `log`
      //            conventionally has base ten, and **which side this app's own `log` maps to was not
      //            verified this round**. **A spelling the two sides define differently is always refused
      //            here** (the same treatment as `mod` and `!=`).
      //
      //          **A wrong derivative is far worse than an unsupported function**: the former prints a
      //          plausible-looking, complete, fake derivation.
      return null;
  }
}
