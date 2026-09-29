/// 中文：表达式语法树的节点定义。
///       表达式字符串始终是唯一真源，因此每个节点都必须携带它在源码里占用的区间，
///       渲染层才能把一次点击映射回输入框中的正确字符位置。
/// English: Expression syntax tree nodes. The expression string stays the single source of
///          truth, so every node must carry the span it occupies in that source; that is what
///          lets the renderer map a tap back to the right character offset in the input.
library;

import '../expression_parser.dart';

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

/// 中文：**度分秒字面量**，例如 `3°30′0″`（HiPER 的 `D°M′S` 键在表达式里按出来的那个形状）。
///       [degrees]/[minutes]/[seconds] 是**原样的数字文本**，`null` 表示那一段不在场；
///       区间覆盖整个字面量（含三个记号），所以渲染层的点击定位整块落在它上面。
///
///       它为什么是一个**独立节点**、而不是一个 `literal` 特别的 [NumberNode]：
///       - 它的 TeX **不是**原文（`3^\circ\,30'\,0''`），而 [NumberNode] 的约定是「原文照排」；
///       - 它**没有引擎写法**：`_translate` 对它一律拒绝（归一化已经把字面量写成 `degangle(…)`，
///         走到翻译层的字面量本来就不该存在），而 `NumberNode` 是会原样送去引擎的。
///       - 判据（哪一串算字面量）只有一份，在 `sexagesimal_literal.dart`。
/// English: **a degrees-minutes-seconds literal**, e.g. `3°30′0″` (the shape HiPER's `D°M′S` key
///          builds inside an expression). [degrees]/[minutes]/[seconds] are the **digit text
///          verbatim** and `null` means that part is absent; the span covers the whole literal (all
///          three marks), so a tap anywhere on it lands inside its source region.
///
///          Why a **node of its own** rather than a [NumberNode] with a special `literal`:
///          - its TeX is **not** the source text (`3^\circ\,30'\,0''`) while [NumberNode] promises
///            "the text, typeset as written";
///          - it has **no engine spelling**: `_translate` refuses it outright (normalisation has
///            already written the literal as `degangle(…)`, so one reaching the translator should not
///            exist at all), whereas a [NumberNode] is forwarded to the engine verbatim;
///          - the judgement (which string is a literal) has one copy, in `sexagesimal_literal.dart`.
final class SexagesimalNode extends ExprNode {
  const SexagesimalNode(
    this.degrees, {
    required super.start,
    required super.end,
    this.minutes,
    this.seconds,
  });

  final String degrees;
  final String? minutes;
  final String? seconds;
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
///       判据分两半，两半问的是同一个问题：
///
///       - **变量名**：`ExpressionAstParser._parseName` 只产出三种东西——常量
///         （`ConstantNode`，`pi`/`e`/`tau`/`phi`/`inf`/`infinity`）、调用（`FunctionNode`，
///         标识符紧跟 `(`）、以及**其余一切**（`VariableNode`）。所以一个 [VariableNode] 就是
///         「这个名字应用自己的语言没有绑定」这一句话本身，而不是它的近似——没有第二张名字表
///         会漂移，也没有正则要维护。`km` 这类单位名同样落在这里：应用自己的解析器也不认它们。
///       - **函数名**：应用自己的**求值器**绑定了哪些调用名，是它自己那份数据
///         （`ExpressionParser.functionNames`，也就是求值那个 `switch` 的清单），名字先过
///         `ExpressionParser.canonicalFunctionName` 折一次（归一化折叠别名用的是**同一张表**，
///         没有第二份）。表外的名字 ⇒ 一个 [FunctionNode] 也判「没有绑定」——**与变量同一条
///         判据**。（`FunctionNode` 只说「这里有一个标识符紧跟 `(`」，它**不**保证应用自己的
///         求值器实现了那个名字。）
///
///       **为什么函数名问求值器，不问词表（`AppEngineVocabulary.identifiers`）**：这条判据问的是
///       「应用**自己**答得了这个输入吗」，而词表里有一批名字（`matrix`/`sum`/`mean`/`pearson`/
///       `conj`/`rand`…，共 18 个，由 `test/domain/app_engine_vocabulary_semantics_test.dart` 的
///       集合相等钉住）**只有引擎答得出来**——应用自己的求值器对它们抛 `Unknown function`
///       （实测）。按词表判，这些输入会一直算作「表达得了」，引擎那份 `symbolic` 答复就永远被丢掉。
///
///       **它与变量那一半共用同一条安全论证**：名字没绑定时，旧解析器对这一行只会抛
///       `Unknown function …`（实测），所以收紧之后新放行的是**引擎的答复**，而不是拿它顶掉一个
///       应用已经答得出的值。反方向（名字在求值器里而数据表里缺了它）会把应用答得出的输入判成
///       「表达不了」——那才是错值方向，由 `test/domain/app_engine_vocabulary_semantics_test.dart`
///       里那条逐名实测钉住。
///
///       递归覆盖全部节点类型——[ExprNode] 是 `sealed`，所以穷尽性由类型系统保证（漏一个节点
///       `flutter analyze` 直接报 `non_exhaustive_switch_statement`）。
///
///       它的消费者只有一处：`_selectEngineResult` 用它决定一个
///       [EngineResultKind.symbolic] 结果配不配显示（见 `AppEngineVocabulary.canExpress`）。
/// English: **Whether this tree holds a name this app's own language has no binding for.**
///
///          The judgement has two halves, both asking one question:
///
///          - **variable names**: `ExpressionAstParser._parseName` produces exactly three things —
///            a constant (`ConstantNode`: `pi`/`e`/`tau`/`phi`/`inf`/`infinity`), a call
///            (`FunctionNode`: an identifier immediately followed by `(`) — and **everything else**
///            (`VariableNode`). A [VariableNode] therefore *is* the sentence "this app's own language
///            has no binding for this name" rather than an approximation of it: no second name table
///            to drift, no regex to maintain. Unit names such as `km` land here too — this app's own
///            parser does not bind those either.
///          - **function names**: which call names this app's own **evaluator** binds is its own
///            data (`ExpressionParser.functionNames`, the list behind the evaluation `switch`), and
///            the name is folded first by `ExpressionParser.canonicalFunctionName` — the **same
///            table** normalisation folds aliases with, there is no second copy. A name outside that
///            list means a [FunctionNode] is judged "no binding" as well — **the same judgement as a
///            variable**. (A `FunctionNode` only says "an identifier is followed by `(`"; it does
///            **not** promise this app's own evaluator implements that name.)
///
///          **Why the function half asks the evaluator and not the vocabulary**
///          (`AppEngineVocabulary.identifiers`): this judgement asks "can this app **itself** answer
///          this input", and the vocabulary holds a batch of names (`matrix`/`sum`/`mean`/`pearson`/
///          `conj`/`rand`…, 18 of them, pinned by a set equality in
///          `test/domain/app_engine_vocabulary_semantics_test.dart`) that **only the engine can
///          answer** — this app's own evaluator throws `Unknown function` for every one of them
///          (measured). Judged by the vocabulary they would keep counting as "expressible" and the
///          engine's `symbolic` answer would be discarded for ever.
///
///          **It shares the variable half's safety argument**: with the name unbound, the legacy
///          parser can only throw `Unknown function …` for that line (measured), so what the
///          tightening admits is the **engine's answer** rather than something that displaces a value
///          this app can already produce. The other direction (a name the evaluator has but the data
///          list lacks) would call an answerable input inexpressible — that is the wrong-value
///          direction, and it is pinned by the name-by-name measurement in
///          `test/domain/app_engine_vocabulary_semantics_test.dart`.
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
    // 中文：**度分秒字面量是应用自己的东西，不点名任何东西**——它是应用自己的记号（键位插得出来、
    //       值由应用自己的求值器给），与 [NumberNode] 同一条判据。
    // English: **a DMS literal is this app's own construct and names nothing** — it is this app's
    //          own notation (a key inserts it and this app's evaluator gives its value), the same
    //          judgement as a [NumberNode].
    case SexagesimalNode():
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
    case FunctionNode(:final name, :final args):
      // 中文：名字与变量同一条判据（见上面那一段）；实参照样要走——`sin(x)` 这种「已绑定的名字
      //       包着一个未绑定的名字」也属于这一类。
      // English: the name faces the same judgement as a variable (see the note above), and the
      //          arguments are still walked — `sin(x)`, a bound name wrapping an unbound one, is in
      //          this class too.
      return !_appEvaluatorBindsCall(name) ||
          args.any(namesSomethingOutsideTheAppLanguage);
  }
}

/// 中文：**这棵树里出现的变量名，按书写顺序去重收集。**
///
///       它服务一处：方程组要告诉引擎"对哪几个未知数求解"（`multisolve([...], x, y)`）。
///       引擎**不接受空着**——`multisolve([x+y=3, x-y=1])` 原样退回（宿主实测，kind `SYMBOLIC`），
///       与无解、欠定的形状**一模一样**，所以那个名单必须由我们自己给。
///
///       **为什么收集"所有 [VariableNode]"就是"所有未知数"**：应用自己的语法里，
///       一个没有绑定值的名字**就是**一个 [VariableNode]（见
///       [namesSomethingOutsideTheAppLanguage] 那一段），而绑定值的变量（键位上的 `X`/`Y`）
///       在翻译之前就由 `resolveVariableReferences` 换成数字了。所以这里收上来的，
///       正是"应用自己认不出来的名字"这个集合本身——**不是第二张表**。
///
///       ⚠️ **未知数全部列出来，恰恰是安全的那一侧。** 宿主实测：只列 x、y 而式子里还有第三个
///       自由字母（`multisolve([x+y=a, x-y=1], x, y)`）时，引擎会把 `a` 读成**安培**，
///       印出 `[(500 ma + 0.5) …]`——**一个看着像答案的错值**。全列出来则方程组欠定、引擎原样退回，
///       而"退回"由调用方挡下。**宁可它说"解不了"，不可它拿安培当未知数。**
/// English: **the variable names in this tree, de-duplicated in writing order.**
///
///          It serves one place: a system of equations has to tell the engine **which unknowns to
///          solve for** (`multisolve([...], x, y)`). The engine **does not accept an empty list** —
///          `multisolve([x+y=3, x-y=1])` is handed back unchanged (measured on the host, kind
///          `SYMBOLIC`), a shape **identical** to "no solution" and "underdetermined", so that list
///          has to come from us.
///
///          **Why "every [VariableNode]" is "every unknown"**: in this app's own grammar an unbound
///          name **is** a [VariableNode] (see the note on
///          [namesSomethingOutsideTheAppLanguage]), while a bound variable (the keypad's `X`/`Y`) is
///          replaced by a number by `resolveVariableReferences` before translation. So what is
///          collected here is that set itself — **not a second table**.
///
///          ⚠️ **Listing every unknown is the safe side.** Measured on the host: list only x and y
///          while a third free letter appears (`multisolve([x+y=a, x-y=1], x, y)`) and the engine reads
///          `a` as **amperes**, printing `[(500 ma + 0.5) …]` — **a wrong value that looks like an
///          answer**. List them all and the system is underdetermined, so the engine hands it back and
///          the caller refuses. **Better it says "cannot solve" than takes amperes for an unknown.**
void collectVariableNames(ExprNode node, List<String> into) {
  switch (node) {
    case NumberNode():
    case ConstantNode():
    case OperatorNode():
    case ParseErrorNode():
    case SexagesimalNode():
      return;
    case VariableNode(:final name):
      if (!into.contains(name)) into.add(name);
    case UnaryNode(:final operand):
    case PostfixNode(:final operand):
      collectVariableNames(operand, into);
    case GroupNode(:final child):
      collectVariableNames(child, into);
    case BinaryNode(:final left, :final right):
    case ImplicitProductNode(:final left, :final right):
      collectVariableNames(left, into);
      collectVariableNames(right, into);
    case FunctionNode(:final args):
      for (final arg in args) {
        collectVariableNames(arg, into);
      }
  }
}

/// 中文：**这棵树里有没有解析错误。** 与 [namesSomethingOutsideTheAppLanguage] 并排放在一起，
///       因为 [AppEngineVocabulary.canExpress] 要同时问这两件事——**而它们是两个问题**。
///
///       ⚠️ **这一条是量出来的，不是补着好玩的。** [namesSomethingOutsideTheAppLanguage] 对
///       [ParseErrorNode] 回 `false`（一个错误节点确实**不点名任何东西**，那个回答没错），
///       于是 `canExpress` 对 `2x+1=7` 答**"应用自己的语言表达得了"**——而应用自己的语法里
///       **连等号都没有**，旧解析器对它只会抛一句「存在无法识别的内容」。
///       那条判据的用途是「应用自己答得了时，旧解析器依旧是权威」，它一旦在这一支上误判为真，
///       引擎给出的 `x = 3` 就会被丢掉、屏幕上留下那句解析错误。**实测就是这样丢的。**
///
///       **判据：解析器读不懂 ⇒ 应用自己的语言表达不了它。** 这不是 [ParseErrorNode] 该回什么
///       的问题（它回 `false` 是对的），而是"表达得了吗"这个问题**还需要第二个前提**：先得读得懂。
/// English: **does this tree hold a parse error.** It sits next to
///          [namesSomethingOutsideTheAppLanguage] because [AppEngineVocabulary.canExpress] has to ask
///          both questions — **and they are two questions.**
///
///          ⚠️ **This was measured, not added for tidiness.** [namesSomethingOutsideTheAppLanguage]
///          answers `false` for a [ParseErrorNode] (an error node really does **name nothing**, so that
///          answer is not wrong), which made `canExpress` answer **"this app's own language can express
///          it"** for `2x+1=7` — while this app's grammar **does not even have an equals sign** and the
///          legacy parser can only throw "unrecognised content" at it. That judgement's purpose is
///          "when this app can answer, the legacy parser stays the authority"; once it comes back true
///          here, the engine's `x = 3` is thrown away and the parse error is what stays on screen.
///          **That is exactly how it was lost, measured.**
///
///          **The judgement: if the parser cannot read it, the app's own language cannot express it.**
///          That is not about what [ParseErrorNode] should return (its `false` is right) but about the
///          fact that "can it be expressed" **needs a second premise**: it has to be readable first.
bool hasParseError(ExprNode node) {
  switch (node) {
    case NumberNode():
    case ConstantNode():
    case OperatorNode():
    case VariableNode():
    case SexagesimalNode():
      return false;
    case ParseErrorNode():
      return true;
    case UnaryNode(:final operand):
    case PostfixNode(:final operand):
      return hasParseError(operand);
    case GroupNode(:final child):
      return hasParseError(child);
    case BinaryNode(:final left, :final right):
    case ImplicitProductNode(:final left, :final right):
      return hasParseError(left) || hasParseError(right);
    case FunctionNode(:final args):
      return args.any(hasParseError);
  }
}

/// 中文：应用自己的求值器绑不绑定这个调用名。**复用解析器自己那份数据**——名字表是
///       `ExpressionParser.functionNames`，别名与大小写的折叠是
///       `ExpressionParser.canonicalFunctionName`（它背后那张 `functionAliases` 表与归一化
///       用的是同一张）。这里**不新建名字表**，所以「求值器绑了哪些名字」只有一处可改。
/// English: whether this app's own evaluator binds this call name. **The parser's own data is
///          reused** — the name list is `ExpressionParser.functionNames` and aliases/case fold
///          through `ExpressionParser.canonicalFunctionName` (whose `functionAliases` table is the
///          one normalisation uses too). **No second name table is created here**, so "which names
///          the evaluator binds" has exactly one place to change.
bool _appEvaluatorBindsCall(String name) => ExpressionParser.functionNames
    .contains(ExpressionParser.canonicalFunctionName(name));
