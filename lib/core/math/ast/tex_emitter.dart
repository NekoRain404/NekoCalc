import 'expr_node.dart';

/// 中文：把语法树转成 TeX 片段。纯函数、无 Flutter 依赖，因此可以在任何环境里单测。
///       渲染层按 [toDisplayUnits] 切好的显示单元逐个调用 [emit]，于是"每个单元一个片段"
///       和"每个片段一段源码区间"是同一件事——点击定位就建立在这上面。
/// English: Turns a syntax tree into TeX fragments. A pure function with no Flutter dependency, so
///          it is testable anywhere. The renderer calls [emit] once per unit produced by
///          [toDisplayUnits], which makes "one unit, one fragment" and "one fragment, one source
///          span" the same statement — tap-to-cursor is built on exactly that.
class TexEmitter {
  const TexEmitter();

  /// 中文：单个节点转 TeX。
  /// English: Emits TeX for a single node.
  String emit(ExprNode node) => _emit(node);

  /// 中文：按序转换每个显示单元，产物与入参一一对应。
  /// English: Emits every display unit in order; the result is one-to-one with the input.
  List<String> emitUnits(List<ExprNode> units) =>
      [for (final unit in units) _emit(unit)];

  /// 中文：核心分发。`delimited` 表示"外层结构已经自带视觉分组"（`\frac` 的分子分母、
  ///       `\sqrt` 的内容、`^{}` 的指数、函数的 `\left(…\right)`），此时括号分组不必再画一对括号；
  ///       其余位置（`+`、`-`、`\cdot`、并置乘法、幂的底数等）则必须保留，否则会改变算式的读法。
  /// English: The core dispatch. `delimited` means the enclosing construct already provides visual
  ///          grouping (a `\frac` numerator or denominator, the body of a `\sqrt`, a `^{}` exponent,
  ///          a function's `\left(…\right)`), so an explicit group need not draw its own
  ///          parentheses; anywhere else (`+`, `-`, `\cdot`, juxtaposition, a power's base) they
  ///          must stay or the expression would read differently.
  String _emit(ExprNode node, {bool delimited = false}) => switch (node) {
        // 中文：数字字面量原样输出（`1.5e3`、`0x1f` 都不含 TeX 元字符），只有下划线分隔符例外：
        //       数学模式里 `_` 是下标标记，`1_000` 会被排成 `1` 带下标 `000`。
        // English: Numeric literals go through verbatim (`1.5e3`, `0x1f` hold no TeX metacharacters),
        //          with one exception: in math mode `_` marks a subscript, so `1_000` would be
        //          typeset as `1` with a subscript `000`.
        NumberNode(:final literal) => literal.replaceAll('_', r'\_'),
        ConstantNode(:final name) => _constants[name.toLowerCase()] ?? name,
        VariableNode(:final name) => name,
        OperatorNode(:final op) => _operator(op),
        UnaryNode(:final op, :final operand) => '$op${_emit(operand)}',
        BinaryNode(:final op, :final left, :final right) =>
          _binary(op, left, right),
        PostfixNode(:final op, :final operand) => '${_emit(operand)}${_operator(op)}',
        FunctionNode() => _call(node),
        GroupNode(:final child) => delimited
            ? _emit(child, delimited: true)
            : '\\left(${_emit(child, delimited: true)}\\right)',
        // 中文：并置乘法按书写顺序拼在一起（`2x`），两个操作数各自维持原状。
        // English: Juxtaposition concatenates in writing order (`2x`), each operand unchanged.
        ImplicitProductNode(:final left, :final right) =>
          '${_emit(left)}${_emit(right)}',
        // 中文：无法解析的片段降级成转义后的原文，绝不产出非法 TeX。
        // English: An unparseable fragment degrades to escaped literal text; never invalid TeX.
        ParseErrorNode(:final text) => '\\text{${_escapeText(text)}}',
      };

  String _binary(String op, ExprNode left, ExprNode right) => switch (op) {
        // 中文：分数本身就是一对视觉括号，两侧的显式括号可以省掉。
        // English: The fraction bar is itself a pair of visual brackets, so explicit ones can go.
        '/' => '\\frac{${_emit(left, delimited: true)}}'
            '{${_emit(right, delimited: true)}}',
        // 中文：指数写成真正的上标；花括号已经分组，因此指数内部的括号可以省掉。
        // English: The exponent becomes a real superscript; its braces already group, so
        //          parentheses inside the exponent can go.
        '^' => '${_emit(left)}^{${_emit(right, delimited: true)}}',
        _ => '${_emit(left)}${_operator(op)}'
            '${op == '*' ? ' ' : ''}${_emit(right)}',
      };

  /// 中文：运算符自身的写法。两个必须改写的都在这里：`*` 在自然排版里是居中点号而不是星号，
  ///       `%` 是 TeX 的注释符，不转义会把后缀连同其后的一切都吞掉（`50%` 会渲染成 `50`）。
  /// English: How an operator itself is spelled. Two of them must be rewritten, both here: `*` is
  ///          a centred dot in natural typesetting rather than a star, and `%` is TeX's comment
  ///          character — unescaped it would swallow the postfix and everything after it (`50%`
  ///          would render as `50`).
  String _operator(String op) => switch (op) {
        '*' => r'\cdot',
        '%' => r'\%',
        _ => op,
      };

  /// 中文：函数调用。包裹型函数（根号、绝对值）用自身的结构提供视觉分组，
  ///       因此实参里的显式括号一律省掉；其余函数保留 `\left(…\right)`。
  ///       `log` 系列按题面固定为常用对数与二进制对数，`asin` 系列用 LaTeX 的标准名 `\arcsin` 等。
  /// English: Function call. Wrapping functions (roots, absolute value) provide visual grouping
  ///          themselves, so explicit parentheses in their arguments are dropped; other functions
  ///          keep `\left(…\right)`. The `log` family is pinned to base 10 / base 2 as specified,
  ///          and the `asin` family uses LaTeX's standard spellings `\arcsin` and friends.
  String _call(FunctionNode node) {
    final name = node.name.toLowerCase();
    final args = node.args;
    switch (name) {
      case 'sqrt':
        return '\\sqrt{${_argument(args, 0)}}';
      case 'cbrt':
        return '\\sqrt[3]{${_argument(args, 0)}}';
      case 'root':
        return args.length >= 2
            ? '\\sqrt[${_argument(args, 0)}]{${_argument(args, 1)}}'
            : '\\sqrt{${_argument(args, 0)}}';
      case 'abs':
        return '\\left|${_argument(args, 0)}\\right|';
      case 'log':
        return '\\log_{10}${_arguments(args)}';
      case 'log2':
        return '\\log_{2}${_arguments(args)}';
      case 'ln':
        return '\\ln${_arguments(args)}';
    }
    final command = _functions[name];
    if (command != null) return '$command${_arguments(args)}';
    // 中文：未知函数名回退到 \operatorname，名字保持正体且不会与相邻字母粘连。
    //       实参表额外包一层花括号：KaTeX 的 \operatorname 只吃名字，但 flutter_math_fork
    //       把紧跟其后的一个分组当作函数体，少了这层括号会解析失败；花括号在真 KaTeX 里
    //       只是一个普通分组，两边渲染一致。
    // English: An unknown function falls back to \operatorname, upright and never glued to
    //          neighbouring letters. The argument list gets an extra pair of braces: KaTeX's
    //          \operatorname consumes only the name, while flutter_math_fork takes the following
    //          group as the function body and fails to parse without it; in real KaTeX the braces
    //          are an ordinary group, so both engines render the same thing.
    return '\\operatorname{${_escapeText(node.name)}}'
        '{${_arguments(args)}}';
  }

  String _argument(List<ExprNode> args, int index) =>
      index < args.length ? _emit(args[index], delimited: true) : '';

  String _arguments(List<ExprNode> args) =>
      '\\left(${args.map((arg) => _emit(arg, delimited: true)).join(', ')}\\right)';

  /// 中文：`\text{}` 内部的转义表，覆盖 TeX 的十个元字符。
  ///       反斜杠用标准 LaTeX 写法 `\textbackslash`：它是**文本模式**的符号，而这张表只在
  ///       `\text{}` 内部使用，位置正好对上；数学模式里它没有定义，所以别把这套转义挪出去用
  ///       （那样会得到 "Undefined control sequence: \textbackslash"）。
  /// English: The escape table for the inside of `\text{}`, covering TeX's ten metacharacters.
  ///          A backslash uses the standard LaTeX spelling `\textbackslash`, a **text-mode**
  ///          symbol — this table is only ever used inside `\text{}`, which is exactly where it is
  ///          defined; it does not exist in math mode, so these escapes must not be reused outside
  ///          `\text{}` (that yields "Undefined control sequence: \textbackslash").
  static String _escapeText(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      switch (rune) {
        case 0x5c:
          buffer.write(r'\textbackslash{}');
        case 0x7b:
          buffer.write(r'\{');
        case 0x7d:
          buffer.write(r'\}');
        case 0x24:
          buffer.write(r'\$');
        case 0x26:
          buffer.write(r'\&');
        case 0x23:
          buffer.write(r'\#');
        case 0x5f:
          buffer.write(r'\_');
        case 0x25:
          buffer.write(r'\%');
        case 0x7e:
          buffer.write(r'\textasciitilde{}');
        case 0x5e:
          buffer.write(r'\textasciicircum{}');
        default:
          buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// 中文：常量映射表。查表忽略大小写，但只有真正需要换写的才列出（`e` 原样保留）。
  /// English: The constant map. Lookup ignores case; only constants that must be rewritten are
  ///          listed (`e` stays as it is).
  static const Map<String, String> _constants = {
    'pi': r'\pi',
    'tau': r'\tau',
    'phi': r'\phi',
    'e': 'e',
    'inf': r'\infty',
    'infinity': r'\infty',
  };

  /// 中文：三角与双曲函数的 LaTeX 名，全部保持正体。
  /// English: LaTeX names for the trigonometric and hyperbolic functions, all upright.
  static const Map<String, String> _functions = {
    'sin': r'\sin',
    'cos': r'\cos',
    'tan': r'\tan',
    'asin': r'\arcsin',
    'acos': r'\arccos',
    'atan': r'\arctan',
    'sinh': r'\sinh',
    'cosh': r'\cosh',
    'tanh': r'\tanh',
    'cot': r'\cot',
    'sec': r'\sec',
    'csc': r'\csc',
  };
}
