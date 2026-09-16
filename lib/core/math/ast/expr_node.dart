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
///       沿二元节点的**左操作数**递归摊平最外层运算链，因此 `a+b+c`
///       （即 `BinaryNode(+, BinaryNode(+, a, b), c)`）产出 `[a, +, b, +, c]`，
///       其中运算符单元的区间指向源码里运算符自身的位置；右操作数与其余节点
///       （数字、函数、括号、错误片段等）整体保留为一个单元。
/// English: Flattens an expression into the smallest units used for rendering and tap-to-cursor.
///          The outermost binary chain is flattened by walking down left operands, so `a+b+c`
///          (`BinaryNode(+, BinaryNode(+, a, b), c)`) yields `[a, +, b, +, c]` with operator units
///          pointing at the operator character itself. Right operands and every other node
///          (numbers, calls, groups, error fragments) stay whole as a single unit.
List<ExprNode> toDisplayUnits(ExprNode node) {
  final units = <ExprNode>[];
  _appendDisplayUnits(node, units);
  return units;
}

void _appendDisplayUnits(ExprNode node, List<ExprNode> units) {
  if (node is BinaryNode) {
    _appendDisplayUnits(node.left, units);
    units.add(OperatorNode(node.op, start: node.opStart, end: node.opEnd));
    units.add(node.right);
    return;
  }
  units.add(node);
}
