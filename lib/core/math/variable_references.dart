/// 中文：**把表达式里绑定了值的变量换成一个数，在任何人读它之前。**
///
///       这是 `x`/`y` 两个变量的**唯一一处替换点**，与 `Ans`/`last` 的替换（`_resolveAnswerReferences`）
///       并排放在同一个入口里，因此**翻译器（`engineExpressionFor`）、名字层（`canRead`/`canExpress`）、
///       旧解析器（`ExpressionParser`）看到的是同一个字符串**——修复轮 7、8、9 反复吃过的那个亏
///       （两个消费者看到两份长得像的输入）在这里不会再发生一次。
///
///       **规则一：替换发生在归一化之后的文本上，替换的也是那份文本。**
///       应用自己的语法树只在归一化后的形态上可靠（实测：原文 `5×3`、`π`、`x²` 解析出来都是
///       `ParseErrorNode`，归一化之后才是 `bin(* …)`、`const(pi)`、`bin(^ var(x) …)`），
///       而节点上的区间 [ExprNode.start]/[ExprNode.end] 是**归一化文本里的偏移**——两者必须配套，
///       所以先归一化再取区间。这个顺序还顺手堵住了一条静默错值：`2x10^3` 的归一化是 `2e3`（科学
///       计数法，`_normalizeScientificNotation`），绑定了 `x` 之后它仍然是 2000——**应用对这段文本
///       既有的读法赢过变量绑定**，而不是变成 `2*4*10^3`。
///
///       **规则二：替换物一律带括号。** 变量最常见的写法就是与数字并置（`2x`），而 `2x` 里的 `x`
///       直接换成 `4` 会得到 **`24`**——一个看起来完全合理的错值。写成 `2(4)` 之后两个解析器都读成
///       隐式乘法（归一化还会把它变成 `2*(4)`，实测）。这是这一层唯一一个能凭空造出错值的地方，
///       所以它只有这一条写法。
///
///       **规则三：定位用的是语法树的节点，不是正则。** 判据是 [VariableNode] 加上它自己的区间，
///       于是 `exp`/`max`/`xy`/`x2`/`2ans` 这些「包含 x 但不是变量」的情形由**分词器**回答，而不是
///       由一条永远追不上分词器的正则回答（实测：`x2` 是一个名字 `x2`，`2x3` 是 `2 * x3`）。
///       应用在 [namesSomethingOutsideTheAppLanguage] 上已经为同一条理由做过同样的选择。
///
///       **规则四：引擎里那些「自己会绑定一个变量」的调用，整个不替换。**
///       见 [kVariableBindingEngineCalls]：实测那五个名字（`diff` 也是，它同样在词表里）在被替换掉
///       变量之后**不再求值**，而是把式子原样退回来。让它们保持今天的样子，是硬性边界「不许改已经
///       工作的键」的直接要求——`Σ`/`Π`/`∫dx`/`lim` 插进去的 `sum(x,1,10,x)` 一类文本，其 `x` 是
///       **那个调用自己的变量**，不是用户的 `x`。
///
/// English: **Replace a bound variable in an expression with a number, before anyone reads it.**
///
///          This is the **one** substitution point for the `x`/`y` variables, sitting beside the
///          `Ans`/`last` substitution in the same entry point, so the **translator
///          (`engineExpressionFor`), the name layer (`canRead`/`canExpress`) and the legacy parser
///          (`ExpressionParser`) all see one string** — the trap fix rounds 7, 8 and 9 kept falling
///          into (two consumers reading two similar-looking inputs) cannot happen a fourth time here.
///
///          **Rule one: the substitution happens on the normalised text, and it replaces that text.**
///          This app's own tree is only reliable on the normalised form (measured: the raw `5×3`, `π`
///          and `x²` all parse to `ParseErrorNode` while after normalisation they are `bin(* …)`,
///          `const(pi)` and `bin(^ var(x) …)`), and the node spans [ExprNode.start]/[ExprNode.end] are
///          **offsets into the normalised text** — the two have to match, so normalisation comes first
///          and the spans are read from it. The order also closes a silent wrong value: `2x10^3`
///          normalises to `2e3` (scientific notation, `_normalizeScientificNotation`), so with `x`
///          bound it is still 2000 — **the app's existing reading of that text outranks the binding**,
///          rather than becoming `2*4*10^3`.
///
///          **Rule two: the replacement always carries brackets.** A variable's most common spelling
///          is juxtaposition with a number (`2x`), and replacing that `x` with a bare `4` gives
///          **`24`** — a perfectly plausible wrong value. Written `2(4)`, both parsers read an implicit
///          product (normalisation turns it into `2*(4)`, measured). This is the only place in this
///          layer that can manufacture a wrong value out of nothing, so it has exactly one spelling.
///
///          **Rule three: the locations come from the syntax tree, not from a regex.** The test is a
///          [VariableNode] plus its own span, so `exp`, `max`, `xy`, `x2` and `2ans` — "contain an x
///          but are not the variable" — are answered by the **tokeniser**, not by a regex that can
///          never quite catch up with it (measured: `x2` is one name, `x2`; `2x3` is `2 * x3`). The app
///          already made the same choice for the same reason in
///          [namesSomethingOutsideTheAppLanguage].
///
///          **Rule four: the engine's own variable-binding calls are left entirely alone.**
///          See [kVariableBindingEngineCalls]: those five names (measured — `diff` binds too, and it is
///          in the vocabulary) **stop evaluating** once their variable has been substituted, and hand
///          the expression straight back. Leaving them as they are today is what hard boundary "do not
///          change a key that already works" asks for — the `x` inside the `sum(x,1,10,x)` family the
///          `Σ`/`Π`/`∫dx`/`lim` keys insert is **that call's own variable**, not the user's `x`.
library;

import 'ast/expression_ast_parser.dart';
import 'expression_parser.dart';

/// 中文：**能绑值的变量名**——键位上那两颗键（`X`/`Y`）各自的名字，小写，无别名。
///       它就是「哪些名字可以被替换」的**闭集**：表外的 [VariableNode] 一律原样留着
///       （`km` 这类单位名、`ans`、以及用户打进编辑器的任何自由变量）。
/// English: **The variable names that can hold a value** — the names of the two keys (`X`/`Y`), lower
///          case, no aliases. This is the **closed set** of "which names may be replaced": a
///          [VariableNode] outside it is left exactly as it is (unit names such as `km`, `ans`, and
///          any free variable the user types into the editor).
const List<String> kBindableVariableNames = <String>['x', 'y'];

/// 中文：**引擎里会自己绑定一个变量的调用名**——名字取自词表，位置取自引擎自己的实参表
///       （`BuiltinFunctions-algebra.cc`：`sum`/`product` 的第 4 个实参是 `SymbolicArgument`；
///       `BuiltinFunctions-calculus.cc`：`integrate` 第 4 个、`limit` 第 3 个、`diff` 第 2 个）。
///       这五个是词表里唯一会绑定变量的名字，而且**是量出来的**：把它们的变量换成数之后，
///       五个全部从「一个数」变成「原样退回」（`sum(4,1,10,4)` → `Σ(4,1,10,4)`，
///       种类 `arithmetic`，没有有限十进制 ⇒ 数不上屏，见文件头规则四）。
///
///       这一层**按名字整段跳过**，不再去复刻引擎的实参位置：位置猜错就意味着往一个绑定位里塞数，
///       而那是这条路上唯一可能出错的方向。整段跳过只会让「绑了 `x` 又用这类调用」的输入退回符号
///       形态（屏幕上仍是 `x`，不是数字）——**两个方向的失败都不产出错值，而简单的那一个更容易
///       看住**。
/// English: **The engine calls that bind a variable of their own** — the names come from the
///          vocabulary and the positions from the engine's own argument table
///          (`BuiltinFunctions-algebra.cc`: argument 4 of `sum`/`product` is a `SymbolicArgument`;
///          `BuiltinFunctions-calculus.cc`: argument 4 of `integrate`, argument 3 of `limit`,
///          argument 2 of `diff`). These five are the only variable-binding names in the vocabulary,
///          and that is **measured**: substitute their variable for a number and all five turn from "a
///          number" into "handed straight back" (`sum(4,1,10,4)` → `Σ(4,1,10,4)`, kind `arithmetic`,
///          no finite decimal ⇒ nothing reaches the screen; see rule four in the header).
///
///          This layer **skips the whole call by name** rather than copying the engine's argument
///          positions: guessing a position wrong means putting a number into a binding slot, and that
///          is the only direction on this path that can go wrong. Skipping the whole call merely
///          leaves an input that mixes a bound variable with such a call in symbolic form (`x` still on
///          screen, no number) — **neither direction produces a wrong value, and the simpler one is
///          the easier to keep an eye on**.
const Set<String> kVariableBindingEngineCalls = <String>{
  'sum',
  'product',
  'integrate',
  'limit',
  'diff',
};

/// 中文：**一份把变量换成值的表达式**。[values] 是「小写变量名 → 十进制文本」，只认
///       [kBindableVariableNames] 里的名字；表为空、或这段文本里根本没有可替换的变量时**原样返回**
///       入参（于是没有变量的表达式在这条路上逐字节不变，硬性边界 3）。
///
///       替换物是 `(<值>)`——括号的理由见文件头规则二，那一条不是风格问题。
/// English: **An expression with variables replaced by their values.** [values] maps a lower-case
///          variable name to decimal text and only names in [kBindableVariableNames] are recognised;
///          with an empty map, or with nothing to replace in this text, the **input is returned
///          unchanged** (so an expression with no variables travels this path byte for byte as
///          before — hard boundary 3).
///
///          The replacement is `(<value>)` — the reason for the brackets is rule two in the header,
///          and it is not a matter of style.
String resolveVariableReferences(String source, Map<String, String> values) {
  if (values.isEmpty) return source;
  final normalized = ExpressionParser.normalizeExpressionInput(source);
  final targets = <VariableNode>[];
  final complete = _collectTargets(
    const ExpressionAstParser().parse(normalized),
    values,
    const <String>{},
    targets,
  );
  if (!complete || targets.isEmpty) return source;
  // 中文：从左往右拼，区间是**升序**的（递归按书写顺序走，见 [_collectTargets]），所以一趟就能拼完，
  //       也不必担心替换文本自己的长度把后面的区间挪位。
  // English: rebuilt left to right; the spans are **ascending** (the recursion walks in writing order,
  //          see [_collectTargets]), so one pass finishes it and no replacement can shift a later span.
  final buffer = StringBuffer();
  var cursor = 0;
  for (final node in targets) {
    buffer
      ..write(normalized.substring(cursor, node.start))
      ..write('(${values[node.name.toLowerCase()]})');
    cursor = node.end;
  }
  buffer.write(normalized.substring(cursor));
  return buffer.toString();
}

/// 中文：**收集要替换的节点**，按书写顺序（左到右），并维护一个「这一段里被别的构造绑住了的名字」
///       集合 [shadowed]。返回「这棵树读得完整吗」：
///
///       - **树里只要有一个 [ParseErrorNode]，整段不换**（返回假，调用方原样返回输入）。判据偏保守是
///         有意的：`2x+` 这种打到一半的文本，语法树是「左边好好的 `2x`、右边一个零长度的错误节点」，
///         按节点换会得到 `2(4)+`——一段**用户没打过**的文本。它照样是个错误，但错误这次说的是我们
///         改过的那一行，不是用户打的那一行。拿不准就什么都不做。
///       - 名字在 [shadowed] 里 ⇒ 不替换（那是引擎那个调用自己的变量）；
///       - 调用名在 [kVariableBindingEngineCalls] 里 ⇒ 它的**全部实参**都在那个阴影下——不只是
///         引擎真正当作变量的那一个实参。理由见 [kVariableBindingEngineCalls] 的末尾。
///
///       区间由节点自己带着，这里不重新计算任何位置。
/// English: **Collect the nodes to replace**, in writing order (left to right), maintaining a set
///          [shadowed] of "names some other construct has bound in this region". It returns "did this
///          tree read completely":
///
///          - **one [ParseErrorNode] anywhere means nothing is replaced** (returns false and the caller
///            returns its input unchanged). The conservative test is deliberate: half-typed text such
///            as `2x+` parses as "a perfectly good `2x` on the left, a zero-length error node on the
///            right", and a node-wise substitution would produce `2(4)+` — text **the user never
///            typed**. It is still an error either way, but this way the error describes the line
///            they typed rather than a line we edited. When unsure, do nothing.
///          - a name in [shadowed] is **not** replaced (it is that engine call's own variable);
///          - a call whose name is in [kVariableBindingEngineCalls] puts **every one of its
///            arguments** under that shadow — not only the one argument the engine really treats as
///            the variable. The reason is at the end of [kVariableBindingEngineCalls].
///
///          Spans come with the nodes; no position is recomputed here.
bool _collectTargets(
  ExprNode node,
  Map<String, String> values,
  Set<String> shadowed,
  List<VariableNode> out,
) {
  switch (node) {
    case NumberNode():
    case ConstantNode():
    case OperatorNode():
      return true;
    case ParseErrorNode():
      return false;
    case VariableNode(:final name):
      final lower = name.toLowerCase();
      if (!shadowed.contains(lower) && values.containsKey(lower)) out.add(node);
      return true;
    case UnaryNode(:final operand):
    case PostfixNode(:final operand):
      return _collectTargets(operand, values, shadowed, out);
    case GroupNode(:final child):
      return _collectTargets(child, values, shadowed, out);
    case BinaryNode(:final left, :final right):
    case ImplicitProductNode(:final left, :final right):
      // 中文：两边都要走完再返回——短路会让「右边早就错了」的树漏判，而漏判的后果是照换。
      // English: both sides are walked before returning — short-circuiting would miss a tree whose
      //          right side was already wrong, and missing it means substituting anyway.
      final l = _collectTargets(left, values, shadowed, out);
      final r = _collectTargets(right, values, shadowed, out);
      return l && r;
    case FunctionNode(:final name, :final args):
      final inner = kVariableBindingEngineCalls.contains(name.toLowerCase())
          ? values.keys.toSet()
          : shadowed;
      var complete = true;
      for (final arg in args) {
        complete = _collectTargets(arg, values, inner, out) && complete;
      }
      return complete;
  }
}
