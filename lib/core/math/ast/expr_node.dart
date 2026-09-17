/// 中文：表达式语法树的节点定义。
///       表达式字符串始终是唯一真源，因此每个节点都必须携带它在源码里占用的区间，
///       渲染层才能把一次点击映射回输入框中的正确字符位置。
/// English: Expression syntax tree nodes. The expression string stays the single source of
///          truth, so every node must carry the span it occupies in that source; that is what
///          lets the renderer map a tap back to the right character offset in the input.
sealed class ExprNode {
  const ExprNode({required this.start, required this.end});

  /// 中文：起始偏移，闭区间。
  /// English: Start offset, inclusive.
  final int start;

  /// 中文：结束偏移，开区间。
  /// English: End offset, exclusive.
  final int end;
}

/// 中文：数字字面量，literal 保留用户输入的原样写法（例如 `1.5e3`、`0x1f`）。
/// English: Numeric literal; `literal` keeps the exact text the user typed (e.g. `1.5e3`, `0x1f`).
final class NumberNode extends ExprNode {
  const NumberNode(this.literal, {required super.start, required super.end});

  final String literal;
}

/// 中文：内置常量，例如 pi、e、tau。
/// English: Built-in constant such as pi, e or tau.
final class ConstantNode extends ExprNode {
  const ConstantNode(this.name, {required super.start, required super.end});

  /// 中文：源码中的原样拼写，大小写不转换。
  /// English: Spelling as written in the source; case is preserved.
  final String name;
}

/// 中文：变量（含 Ans 这类上下文值）。
/// English: Variable (including context values such as Ans).
final class VariableNode extends ExprNode {
  const VariableNode(this.name, {required super.start, required super.end});

  /// 中文：源码中的原样拼写，大小写不转换。
  /// English: Spelling as written in the source; case is preserved.
  final String name;
}

/// 中文：独立的运算符片段，只出现在 [toDisplayUnits] 的摊平结果里。
/// English: A standalone operator fragment; it only appears in [toDisplayUnits] output.
final class OperatorNode extends ExprNode {
  const OperatorNode(this.op, {required super.start, required super.end});

  final String op;
}

/// 中文：前缀一元运算，例如 `-x`。
/// English: Prefix unary operation, such as `-x`.
final class UnaryNode extends ExprNode {
  const UnaryNode(this.op, this.operand,
      {required super.start, required super.end});

  final String op;
  final ExprNode operand;
}

/// 中文：二元运算。opStart/opEnd 单独记录运算符自身的位置（不是操作数的边界），
///       [toDisplayUnits] 靠它把运算符做成可点击的显示单元。
/// English: Binary operation. opStart/opEnd record the operator's own position rather than
///          the operand boundary; [toDisplayUnits] needs it to make operators tappable units.
final class BinaryNode extends ExprNode {
  const BinaryNode(this.op, this.left, this.right,
      {required this.opStart,
      required this.opEnd,
      required super.start,
      required super.end});

  final String op;
  final ExprNode left;
  final ExprNode right;
  final int opStart;
  final int opEnd;
}

/// 中文：后缀运算，例如 `x!`、`50%`。
/// English: Postfix operation, such as `x!` or `50%`.
final class PostfixNode extends ExprNode {
  const PostfixNode(this.op, this.operand,
      {required super.start, required super.end});

  final String op;
  final ExprNode operand;
}

/// 中文：函数调用，区间覆盖函数名与整对括号。
/// English: Function call; the span covers the name and the whole parenthesized argument list.
final class FunctionNode extends ExprNode {
  const FunctionNode(this.name, this.args,
      {required super.start, required super.end});

  /// 中文：源码中的原样拼写，大小写不转换。
  /// English: Spelling as written in the source; case is preserved.
  final String name;
  final List<ExprNode> args;
}

/// 中文：显式括号分组，区间含两侧括号。
/// English: Explicit parenthesised group; the span includes both parentheses.
final class GroupNode extends ExprNode {
  const GroupNode(this.child, {required super.start, required super.end});

  final ExprNode child;
}

/// 中文：隐式乘法，例如 `2x`、`3(1+2)`。
/// English: Implicit multiplication, such as `2x` or `3(1+2)`.
final class ImplicitProductNode extends ExprNode {
  const ImplicitProductNode(this.left, this.right,
      {required super.start, required super.end});

  final ExprNode left;
  final ExprNode right;
}

/// 中文：无法解析的片段，text 是它覆盖的原文，渲染层降级为普通文本。
///       区间始终从解析器开始消费的位置延伸到源码末尾。
/// English: An unparseable fragment; `text` is the raw source it covers and the renderer
///          degrades it to plain text. Its span always reaches the end of the source.
final class ParseErrorNode extends ExprNode {
  const ParseErrorNode(this.text, {required super.start, required super.end});

  final String text;
}

/// 中文：把表达式摊平成渲染与点击定位的最小单元。
///       只沿"TeX 是普通中缀符号"的运算符（`+`、`-`、`*`）递归摊平，且左右两个方向都摊，
///       因此 `a+b+c`（即 `BinaryNode(+, BinaryNode(+, a, b), c)`）产出 `[a, +, b, +, c]`，
///       `1+2*3` 产出 `[1, +, 2, *, 3]`，`2*3+1` 产出 `[2, *, 3, +, 1]`，
///       运算符单元的区间指向源码里运算符自身的位置。
///       包裹操作数的运算符（`/` 生成 `\frac{左}{右}`、`^` 生成 `{左}^{右}`）必须保持整体，
///       否则渲染层只会拿到一个孤立的运算符；隐式乘法按并置呈现（`2x`），同样保持整体。
/// English: Flattens an expression into the smallest units used for rendering and tap-to-cursor.
///          Only operators whose TeX is a plain infix symbol (`+`, `-`, `*`) are flattened through,
///          and both sides are flattened, so `a+b+c` (`BinaryNode(+, BinaryNode(+, a, b), c)`)
///          yields `[a, +, b, +, c]`, `1+2*3` yields `[1, +, 2, *, 3]` and `2*3+1` yields
///          `[2, *, 3, +, 1]`, with operator units pointing at the operator character itself.
///          Operators that wrap their operands (`/` emits `\frac{左}{右}`, `^` emits `{左}^{右}`)
///          must stay whole or the renderer receives a bare operator in its own fragment; implicit
///          multiplication renders as juxtaposition (`2x`) and stays whole as well.
List<ExprNode> toDisplayUnits(ExprNode node) {
  final units = <ExprNode>[];
  _appendDisplayUnits(node, units);
  return units;
}

void _appendDisplayUnits(ExprNode node, List<ExprNode> units) {
  if (node is BinaryNode && _isPlainInfixOperator(node.op)) {
    _appendDisplayUnits(node.left, units);
    units.add(OperatorNode(node.op, start: node.opStart, end: node.opEnd));
    _appendDisplayUnits(node.right, units);
    return;
  }
  units.add(node);
}

/// 中文：白名单而非黑名单：以后新增的运算符默认保持整体，只有明确普通中缀的才允许摊平。
/// English: A whitelist rather than a blacklist: any future operator stays whole by default, and
///          only those that are definitely plain infix may be split.
bool _isPlainInfixOperator(String op) => op == '+' || op == '-' || op == '*';

/// 中文：**这棵树里有没有一个「应用自己的语言没有绑定的名字」。**
///
///       判据是**节点类型**，不是名字表：`ExpressionAstParser._parseName` 只产出三种东西——
///       常量（`ConstantNode`，`pi`/`e`/`tau`/`phi`/`inf`/`infinity`）、调用（`FunctionNode`，
///       标识符紧跟 `(`）、以及**其余一切**（`VariableNode`）。所以一个 [VariableNode] 就是
///       「这个名字应用自己的语言没有绑定」这一句话本身，而不是它的近似——没有第二张名字表
///       会漂移，也没有正则要维护。`km` 这类单位名同样落在这里：应用自己的解析器也不认它们。
///
///       递归覆盖全部节点类型——[ExprNode] 是 `sealed`，所以穷尽性由类型系统保证（漏一个节点
///       `flutter analyze` 直接报 `non_exhaustive_switch_statement`）。
///
///       它的消费者只有一处：`_selectEngineResult` 用它决定一个
///       [EngineResultKind.symbolic] 结果配不配显示（见 `AppEngineVocabulary.canExpress`）。
/// English: **Whether this tree holds a name this app's own language has no binding for.**
///
///          The test is the **node type**, not a table of names: `ExpressionAstParser._parseName`
///          produces exactly three things — a constant (`ConstantNode`: `pi`/`e`/`tau`/`phi`/`inf`/
///          `infinity`), a call (`FunctionNode`: an identifier immediately followed by `(`) — and
///          **everything else** (`VariableNode`). A [VariableNode] therefore *is* the sentence "this
///          app's own language has no binding for this name" rather than an approximation of it: no
///          second name table to drift, no regex to maintain. Unit names such as `km` land here too —
///          this app's own parser does not bind those either.
///
///          The recursion covers every node type — [ExprNode] is `sealed`, so exhaustiveness is
///          guaranteed by the type system (an omitted node is a `non_exhaustive_switch_statement`
///          error in `flutter analyze`).
///
///          It has exactly one consumer: `_selectEngineResult`, which uses it to decide whether an
///          [EngineResultKind.symbolic] result belongs on screen (see
///          `AppEngineVocabulary.canExpress`).
bool namesSomethingOutsideTheAppLanguage(ExprNode node) {
  switch (node) {
    case NumberNode():
    case ConstantNode():
    case OperatorNode():
    case ParseErrorNode():
      return false;
    case VariableNode():
      return true;
    case UnaryNode(:final operand):
    case PostfixNode(:final operand):
      return namesSomethingOutsideTheAppLanguage(operand);
    case GroupNode(:final child):
      return namesSomethingOutsideTheAppLanguage(child);
    case BinaryNode(:final left, :final right):
    case ImplicitProductNode(:final left, :final right):
      return namesSomethingOutsideTheAppLanguage(left) ||
          namesSomethingOutsideTheAppLanguage(right);
    case FunctionNode(:final args):
      return args.any(namesSomethingOutsideTheAppLanguage);
  }
}
