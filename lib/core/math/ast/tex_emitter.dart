import '../sexagesimal_literal.dart';
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
        // 中文：**度分秒字面量排成 `3^\circ\,30'\,0''`**——数字原样，只把三个记号换成 TeX 的写法，
        //       段与段之间补一个细空格。这一套记号与结果行那一格（`ResultPresentation._dmsTex`）
        //       **用的是同一份常量**（`SexagesimalMarks`），所以同一个角度在表达式行与结果行上
        //       排出来是同一个样子。缺席的段不画记号、也不补空格（`3°` 就是 `3^\circ`）。
        // English: **a DMS literal typesets as `3^\circ\,30'\,0''`** — the digits as they are, the
        //          three marks swapped for their TeX spellings and a thin space between sections.
        //          The marks are **the same constants** the result line's cell uses
        //          (`SexagesimalMarks`, see `ResultPresentation._dmsTex`), so one angle typesets
        //          identically on the expression line and the result line. An absent section draws
        //          no mark and adds no space (`3°` is just `3^\circ`).
        SexagesimalNode(:final degrees, :final minutes, :final seconds) =>
          _sexagesimal(degrees, minutes, seconds),
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
        // 中文：并置乘法按书写顺序拼在一起（`2x`），两个操作数各自维持原状——控制词与字母
        //       撞在一起的那一种情况除外，见 [_juxtapose]。
        // English: Juxtaposition concatenates in writing order (`2x`), each operand unchanged —
        //          except where a control word would run into a letter; see [_juxtapose].
        ImplicitProductNode(:final left, :final right) => _juxtapose(left, right),
        // 中文：无法解析的片段降级成转义后的原文，绝不产出非法 TeX。
        // English: An unparseable fragment degrades to escaped literal text; never invalid TeX.
        ParseErrorNode(:final text) => '\\text{${_escapeText(text)}}',
      };

  /// 中文：度分秒字面量的 TeX。**记号本身只有一份**（[SexagesimalMarks]），结果行那一格用的是
  ///       同一份——两处排出来必须一模一样，所以这里一个字符都不另写。
  /// English: the TeX for a DMS literal. **The marks have one copy** ([SexagesimalMarks]) and the
  ///          result line's cell uses the same one — the two renderings must be identical, so not one
  ///          character is written out again here.
  String _sexagesimal(String degrees, String? minutes, String? seconds) {
    final buffer = StringBuffer('$degrees${SexagesimalMarks.degreeTex}');
    if (minutes != null) {
      buffer.write('${SexagesimalMarks.texSeparator}$minutes'
          '${SexagesimalMarks.minuteTex}');
    }
    if (seconds != null) {
      buffer.write('${SexagesimalMarks.texSeparator}$seconds'
          '${SexagesimalMarks.secondTex}');
    }
    return buffer.toString();
  }

  /// 中文：并置乘法的拼接。TeX 把一个控制词读成"反斜杠 + 尽可能多的字母"（`\pi`、`\infty`），
  ///       于是 `\pi` 紧跟 `x` 会拼成 `\pix`——一个不存在的控制词；引擎拒收它，**整个片段**
  ///       退回纯文本（`pi x` 显示成灰色的 `pi x` 而不是 π 乘 x）。只有两侧真会粘连时才给右操作数
  ///       套一层花括号：花括号在数学模式里是透明的，排版不变；而本来就是对的写法
  ///       （`2x`、`pi 2`、`pi sin(2)`）保持一字不改。
  /// English: Concatenation for juxtaposition. TeX reads a control word as a backslash plus as many
  ///          letters as it can take (`\pi`, `\infty`), so `\pi` immediately followed by `x` becomes
  ///          `\pix` — an undefined control word; the engine rejects it and the **whole fragment**
  ///          degrades to plain text (`pi x` shows up as a grey `pi x` instead of π times x). Braces
  ///          go around the right operand only when the two would really merge: a group is
  ///          transparent in math mode, so the typesetting does not change, while spellings that
  ///          were already correct (`2x`, `pi 2`, `pi sin(2)`) come out byte for byte the same.
  String _juxtapose(ExprNode left, ExprNode right) {
    final leftTex = _emit(left);
    final rightTex = _emit(right);
    if (_endsWithControlWord(leftTex) && _startsWithLetter(rightTex)) {
      // 中文：花括号是字面的 TeX 分组，围绕右操作数。
      // English: the braces here are literal TeX grouping, wrapped around the right operand.
      return '$leftTex{$rightTex}';
    }
    return '$leftTex$rightTex';
  }

  /// 中文：片段是否以控制词结尾（`\pi`、`\sin`）：反斜杠加一串字母，一直顶到末尾。
  ///       数字或 `{`、`}` 都会终止控制词，所以它们不算在内。
  /// English: Whether a fragment ends with a control word (`\pi`, `\sin`): a backslash plus a run
  ///          of letters running all the way to the end. A digit or a brace would have ended it,
  ///          so those do not count.
  static bool _endsWithControlWord(String tex) {
    var start = tex.length;
    while (start > 0 && _isTexLetter(tex.codeUnitAt(start - 1))) {
      start--;
    }
    final hasLetter = start < tex.length;
    return hasLetter && start > 0 && tex.codeUnitAt(start - 1) == _backslash;
  }

  /// 中文：片段是否以裸字母开头——只有这种开头会与控制词粘连（`\sin` 之类自带反斜杠，不会）。
  /// English: Whether a fragment starts with a bare letter — the only kind of start that can merge
  ///          with a preceding control word (`\sin` and friends carry their own backslash).
  static bool _startsWithLetter(String tex) =>
      tex.isNotEmpty && _isTexLetter(tex.codeUnitAt(0));

  /// 中文：TeX 控制词能吞下的字符，即 `[A-Za-z]`；`@` 在宏定义里也算，但本生成器从不裸写它。
  /// English: The characters a TeX control word can swallow, i.e. `[A-Za-z]`; `@` counts too inside
  ///          macro definitions, but this emitter never writes one bare.
  static bool _isTexLetter(int code) =>
      (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a);

  static const int _backslash = 0x5c;

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
        // 中文：`root` 只认"次数, 被开方数"两个实参。多出来的实参不能悄悄丢掉——显示层是唯一真源
        //       的回读，少画一个实参就等于显示与输入不一致；此时退回普通函数写法，实参表一个不少。
        // English: `root` means (degree, radicand) and nothing else. Extra arguments must not be
        //          dropped silently — the display is the only read-back of the single source of
        //          truth, so showing fewer arguments than were typed would contradict the input.
        //          The whole call falls back to the ordinary function form instead, argument list
        //          intact.
        if (args.length > 2) {
          return '\\operatorname{root}{${_arguments(args)}}';
        }
        return args.length == 2
            ? '\\sqrt[${_argument(args, 0)}]{${_argument(args, 1)}}'
            : '\\sqrt{${_argument(args, 0)}}';
      case 'abs':
        return '\\left|${_argument(args, 0)}\\right|';
      // 中文：`log` 一个实参是常用对数（题面如此），两个实参是**以第二个实参为底**——
      //       引擎的 `LognFunction` 正是 `log(number, base)`。两个实参时仍印 `\log_{10}` 会
      //       把一个以 2 为底的对数写成以 10 为底，那是对用户输入的直接否认；多出来的实参
      //       照旧一个不丢，退回普通写法。
      // English: one argument is the common logarithm (as specified), two arguments are the
      //          logarithm **to the second argument's base** — exactly the engine's
      //          `LognFunction` shape, `log(number, base)`. Printing `\log_{10}` for two arguments
      //          would state a base-2 logarithm was base 10, a direct denial of what the user typed;
      //          extra arguments are still never dropped, the call falls back to the ordinary form.
      case 'log':
        if (args.length == 2) {
          return '\\log_{${_emit(args[1], delimited: true)}}'
              '\\left(${_emit(args[0], delimited: true)}\\right)';
        }
        return '\\log_{10}${_arguments(args)}';
      case 'log2':
        return '\\log_{2}${_arguments(args)}';
      case 'ln':
        return '\\ln${_arguments(args)}';
      // 中文：Σ / Π / ∫ / lim / d/dx 这五个是**带结构的**符号，不是 `\sin` 那样的前置函数名：
      //       它们的实参各自落在符号的上下限、被作用式或微元上。模板只在实参个数正好是那一种
      //       时启用，其余一律退回完整实参表——显示层是唯一真源的回读，少印一个实参就等于
      //       显示与输入不一致（`root` 的注释已经为这条定过调）。
      // English: Σ / Π / ∫ / lim / d÷dx are **structured** symbols rather than prefix function
      //          names like `\sin`: their arguments land on the bounds, the body or the
      //          differential. A template is used only at the exact argument count it describes,
      //          and anything else falls back to the full argument list — the display is the only
      //          read-back of the source, so printing fewer arguments than were typed is a
      //          contradiction (the `root` comment above already settled that rule).
      case 'sum':
        return _series(r'\sum', args);
      case 'product':
        return _series(r'\prod', args);
      case 'integrate':
        return _integral(args);
      case 'limit':
        return _limit(args);
      case 'diff':
        return _derivative(node.name, args);
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

  /// 中文：Σ / Π。引擎的形状是 `sum(expr, from, to[, index])`（`BuiltinFunctions-algebra.cc` 的
  ///       `MathFunction("sum", 3, 4)`，`calculate` 里 `vargs[0]` 是被加式、`vargs[1]` 是起、
  ///       `vargs[2]` 是止、`vargs[3]` 是被替换的指标），所以上下限落在符号的副标/上标上，
  ///       被加式跟在后面。四个实参时指标写成 `_{i=from}`——**一个实参都不少**。
  ///       三个实参以下退回 `\sum\left(…\right)`，理由见 `_call` 里那一段。
  /// English: Σ / Π. The engine's shape is `sum(expr, from, to[, index])`
  ///          (`MathFunction("sum", 3, 4)` in `BuiltinFunctions-algebra.cc`; in `calculate`,
  ///          `vargs[0]` is the summand, `vargs[1]` the start, `vargs[2]` the end and `vargs[3]` the
  ///          substituted index), so the bounds become the subscript and superscript and the
  ///          summand follows. With four arguments the index is written into the subscript as
  ///          `_{i=from}` — **nothing is left out**. Below three arguments the call falls back to
  ///          `\sum\left(…\right)`; see the note in `_call`.
  String _series(String command, List<ExprNode> args) {
    if (args.length < 3) return '$command${_arguments(args)}';
    final lower = args.length >= 4
        ? '_{${_emit(args[3], delimited: true)}=${_emit(args[1], delimited: true)}}'
        : '_{${_emit(args[1], delimited: true)}}';
    return '$command$lower^{${_emit(args[2], delimited: true)}}'
        '${_emit(args[0], delimited: true)}';
  }

  /// 中文：∫。引擎的形状是 `integrate(expr, lower, upper[, var])`
  ///       （`MathFunction("integrate", 1, 5)`，`calculate` 的 else 分支把 `vargs[1]`/`vargs[2]`
  ///       当下限/上限、`vargs[3]` 当积分变量）。所以两个界限上符号，被积式跟在后面，
  ///       积分变量写成 `\,\mathrm{d}x`。
  ///
  ///       只有三个实参时**不补** `dx`：那时积分变量由引擎自己取默认值（`x`），源码里没有它，
  ///       补上去就是显示层凭空造了一个用户没写的符号——与少印一个实参是同一类错误，方向相反。
  ///       `\mathrm{d}` 与 `\mathrm{d}x` 之间留一个细空格（`\,`），这是唯一一处纯排版选择，
  ///       它不改变任何一个字符的读法。
  /// English: ∫. The engine's shape is `integrate(expr, lower, upper[, var])`
  ///          (`MathFunction("integrate", 1, 5)`; the `else` branch of `calculate` reads
  ///          `vargs[1]`/`vargs[2]` as the bounds and `vargs[3]` as the integration variable), so
  ///          the bounds become sub/superscripts, the integrand follows and the variable is written
  ///          `\,\mathrm{d}x`.
  ///
  ///          With three arguments no `dx` is **added**: there the integration variable is the
  ///          engine's default (`x`) and is absent from the source, so printing it would invent a
  ///          symbol the user never wrote — the same fault as dropping an argument, pointing the
  ///          other way. The thin space between `\mathrm{d}` and its variable is the one purely
  ///          typographic choice here; it changes how no character reads.
  String _integral(List<ExprNode> args) {
    if (args.length < 3) return '\\int${_arguments(args)}';
    final differential = args.length >= 4
        ? '\\,\\mathrm{d}${_emit(args[3], delimited: true)}'
        : '';
    return '\\int_{${_emit(args[1], delimited: true)}}'
        '^{${_emit(args[2], delimited: true)}}'
        '${_emit(args[0], delimited: true)}$differential';
  }

  /// 中文：lim。引擎的形状是 `limit(expr, point[, var])`
  ///       （`MathFunction("limit", 2, 4)`，`calculate` 里 `vargs[1]` 是趋近点、`vargs[2]` 是变量，
  ///       默认 `x`）。趋近点与变量都写进 `\lim` 的下标，被求极限的式子跟在后面。同样地，
  ///       两个实参时**不补** `x`：用户没写它。
  /// English: lim. The engine's shape is `limit(expr, point[, var])`
  ///          (`MathFunction("limit", 2, 4)`; in `calculate`, `vargs[1]` is the point approached
  ///          and `vargs[2]` the variable, defaulting to `x`). Both go under `\lim` and the
  ///          expression follows. Again, with two arguments no `x` is **added**: the user did not
  ///          write it.
  String _limit(List<ExprNode> args) {
    if (args.length < 3) return '\\lim${_arguments(args)}';
    return '\\lim_{${_emit(args[2], delimited: true)}'
        '\\to ${_emit(args[1], delimited: true)}}'
        '${_emit(args[0], delimited: true)}';
  }

  /// 中文：d/dx。引擎的形状是 `diff(expr, var[, order])`
  ///       （`MathFunction("diff", 1, 4)`，`vargs[1]` 是变量、`vargs[2]` 是阶数）。
  ///       写成 `\frac{\mathrm{d}}{\mathrm{d}x}`，阶数作为两侧的指数；实参个数不是二或三时
  ///       退回 `\operatorname{diff}{…}`（正体，且实参表一个不少）。
  /// English: d/dx. The engine's shape is `diff(expr, var[, order])`
  ///          (`MathFunction("diff", 1, 4)`; `vargs[1]` is the variable and `vargs[2]` the order).
  ///          It is written `\frac{\mathrm{d}}{\mathrm{d}x}` with the order as the exponent on both
  ///          sides; any argument count other than two or three falls back to
  ///          `\operatorname{diff}{…}` — upright, argument list intact.
  String _derivative(String name, List<ExprNode> args) {
    if (args.length < 2 || args.length > 3) {
      return '\\operatorname{${_escapeText(name)}}{${_arguments(args)}}';
    }
    final order = args.length == 3 ? _emit(args[2], delimited: true) : '';
    final power = order.isEmpty ? '' : '^{$order}';
    final variable = _emit(args[1], delimited: true);
    return '\\frac{\\mathrm{d}$power}'
        '{\\mathrm{d}$variable$power}'
        '\\left(${_emit(args[0], delimited: true)}\\right)';
  }

  /// 中文：`\text{}` 内部的转义表，覆盖 TeX 的十个元字符。
  ///       反斜杠用标准 LaTeX 写法 `\textbackslash`：它是**文本模式**的符号，位置正好对上——
  ///       这张表里的写法只在 `\text{}` 内产生。同一个辅助函数也被 `\operatorname{…}` 的函数名
  ///       调用，但函数名只可能由字母和数字组成（`[A-Za-z0-9]`），十个元字符一个都进不来，
  ///       因此那个调用点永远不会产出本表里的写法。反过来也要注意：数学模式里没有定义
  ///       `\textbackslash`，这套转义不能被挪到 `\text{}` 之外使用
  ///       （那样会得到 "Undefined control sequence: \textbackslash"）。
  /// English: The escape table for the inside of `\text{}`, covering TeX's ten metacharacters.
  ///          A backslash uses the standard LaTeX spelling `\textbackslash`, a **text-mode**
  ///          symbol, which lines up exactly because every spelling in this table is only produced
  ///          inside `\text{}`. The same helper is also called for the name in `\operatorname{…}`,
  ///          but a function name can only be letters and digits (`[A-Za-z0-9]`) — none of the ten
  ///          metacharacters can get in — so that call site never produces anything from this table.
  ///          Note the converse too: math mode has no `\textbackslash`, so these escapes must not
  ///          be reused outside `\text{}` (that yields "Undefined control sequence:
  ///          \textbackslash").
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
