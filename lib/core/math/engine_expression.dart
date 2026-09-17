/// 中文：**把应用自己的表达式翻译成引擎读得懂的那一份，然后才去问引擎。**
///
///       这是修复轮 6 之后的第三次换判据，前两次（枚举引擎的误读、按值比较）都失败了，
///       原因同一个：**它们都在猜引擎怎么理解我们的输入**——那是开放面。
///       反过来做：**我们自己知道每个标识符是什么意思**，所以在问之前就把表达式写成引擎的写法。
///
///       **输入是归一化之后的形态**（修复轮 8）：[engineExpressionFor] 先把源码过一遍
///       `ExpressionParser.normalizeExpressionInput`，也就是 `ExpressionParser` 自己用的那一个静态
///       方法——两个消费者看到的是同一个字符串。理由与实测见 [engineExpressionFor]。
///
///       **完备性论证：哪一层由什么保证，哪一层不由什么保证。**
///
///       - **节点类型：类型系统保证。** 翻译是**应用自己的语法树上的纯函数**，而语法树是 `sealed`
///         的（11 个 `final class` 节点 + 1 个 `sealed` 基类），Dart 的穷尽性检查在编译期保证
///         `switch` 覆盖全部——**漏一个节点 `flutter analyze` 直接报错**
///         （`non_exhaustive_switch_statement`，实测过），不是靠人列清单。
///       - **运算符：白名单保证**（[_binaryOperators]、[_unaryOperators]），未列入的一律不翻译。
///         这一层**不是**类型系统给的：加一个运算符拼写不会让任何编译期检查变红，靠的是它必须
///         写进这张表才会被发给引擎。
///       - **标识符：运行时的表 + 拒绝未知保证。** [AppEngineVocabulary.identifiers] 这张表是
///         键位/面板能插进表达式的名字（有限），而 [AppEngineVocabulary.engineNameFor] 对**不在表里
///         的名字一律拒绝**（包括所有别名拼写都经 `ExpressionParser.functionAliases` 折到键上再查）
///         ——未知标识符**不会被送到引擎去猜**。所以「引擎收到的东西」是闭的：表外的拼法根本到不了
///         引擎。这一层也**不是**类型系统给的：新加一个标识符不会让编译失败，它只会**不被引擎作答**
///         （回落旧解析器），而不是被答错——这正是把拒绝放在这里的原因。
///       - **因此「哪些构造翻译不了」是一个可以逐条列出来的集合**（[untranslatableReason] 与上面
///         两张表），并且可以在测试里穷尽枚举。**本文档不再声称它与语法树一样由编译期保证**：
///         前两层（节点）是，后两层（运算符、标识符）是运行时的、可枚举的，靠测试而不是编译器。
///
///       **翻译不了的一律走旧解析器**（硬性边界 1 的同一条路）：那些构造要么引擎没有对应
///       （`npr`），要么两边**定义真的不同**（`mod`：应用的 `%` 是欧几里得余数、引擎的 `mod`
///       在被除数为负时不同），要么翻译过去会改变含义（`deg`/`rad` 在引擎里是**单位**）。
///
/// English: **Translate this app's expression into the engine's language before asking the engine.**
///
///          This is the third criterion change after fix round 6; the first two (enumerating the
///          engine's misreadings, and comparing values) both failed for the same reason: **they guessed
///          how the engine understands our input** — an open surface. This does the opposite: **we know
///          what each identifier means**, so the expression is written the engine's way before it is
///          asked.
///
///          **The input is the normalised form** (fix round 8): [engineExpressionFor] runs the source
///          through `ExpressionParser.normalizeExpressionInput` first — the same static method
///          `ExpressionParser` itself uses — so both consumers see one string. The reasons and the
///          measurements are on [engineExpressionFor].
///
///          **The completeness argument: which layer is guaranteed by what, and which is not.**
///
///          - **Node types: the type system guarantees them.** The translation is a **pure function of
///            this app's own syntax tree**, and that tree is `sealed` (11 `final class` nodes on one
///            `sealed` base), so Dart's exhaustiveness check makes an omitted node **a compile error in
///            `flutter analyze`** (`non_exhaustive_switch_statement`, measured), not something a human
///            has to enumerate.
///          - **Operators: a whitelist guarantees them** ([_binaryOperators], [_unaryOperators]); an
///            operator absent from it is never translated. That layer is **not** the type system's:
///            adding an operator spelling turns no compile-time check red — it only reaches the engine
///            if it is written into these sets.
///          - **Identifiers: a runtime table plus refusal of the unknown.** The
///            [AppEngineVocabulary.identifiers] table holds the names the keypad and the sheets can
///            insert (finite), and [AppEngineVocabulary.engineNameFor] **refuses every name not in it**
///            (alias spellings are folded onto the keys through `ExpressionParser.functionAliases`
///            first) — an unknown identifier is **never sent to the engine to guess at**. So what the
///            engine receives is closed: a spelling outside the table cannot reach it. This layer is
///            **not** the type system's either: a new identifier does not break the build; it only stops
///            being answered **by the engine** (the legacy parser answers), rather than being answered
///            wrongly — which is why the refusal sits there.
///          - **"Which constructs cannot be translated" is therefore an enumerable set**
///            ([untranslatableReason] plus the two tables above) and can be enumerated exhaustively in
///            the tests. **This document no longer claims it is compile-time guaranteed the way the tree
///            is**: the first layer (nodes) is; the other two (operators, identifiers) are runtime and
///            enumerable, held by tests rather than by the compiler.
///
///          **Anything untranslatable goes to the legacy parser** (the same route as hard boundary 1):
///          those constructs either have no engine counterpart (`npr`), or the two sides genuinely
///          **define them differently** (`mod`: this app's `%` is the Euclidean remainder, the engine's
///          `mod` differs for negative dividends), or translating them would change the meaning
///          (`deg`/`rad` are **units** in the engine).
library;

import 'app_engine_vocabulary.dart';
import 'ast/expression_ast_parser.dart';
import 'expression_parser.dart';

/// 中文：**运算符的白名单——写下来的那份，不是散在 `switch` 里的字面量。** 三处用它：二元运算
///       （`_binary`）、`OperatorNode`（摊平后的独立运算符）与 `UnaryNode`（前缀运算符）。
///       一份而不是三份，是因为它们回答同一个问题：「这个拼法是要写给引擎的，我们确认过它吗」。
///       未列入的一律翻译不了 ⇒ 回落旧解析器（硬性边界 1），**不会**被原样送到引擎。
/// English: **the operator whitelists — written down here, not scattered as literals in the `switch`.**
///          Three places use them: binary operations (`_binary`), `OperatorNode` (the standalone
///          operator from a flat display unit) and `UnaryNode` (a prefix operator). One copy rather
///          than three because they answer one question: "this spelling is about to be written for the
///          engine — have we confirmed it?" Anything absent cannot be translated ⇒ the legacy parser
///          answers (hard boundary 1); it is **never** forwarded to the engine verbatim.
const Set<String> _binaryOperators = <String>{'+', '-', '*', '/', '^'};

/// 中文：前缀一元运算符。`+`/`-` 是应用语法里仅有的两个（`expression_parser.dart:_parseUnary`）。
/// English: prefix unary operators; `+`/`-` are the only two this app's grammar produces
///          (`expression_parser.dart:_parseUnary`).
const Set<String> _unaryOperators = <String>{'+', '-'};

/// 中文：翻译结果——要么是引擎读得懂的表达式，要么是一条「为什么不能翻译」的理由。
/// English: the translation — either an expression the engine can read, or a reason why not.
sealed class EngineExpression {
  const EngineExpression();
}

/// 中文：翻译成功。
/// English: the translation succeeded.
final class TranslatedExpression extends EngineExpression {
  const TranslatedExpression(this.text);

  final String text;
}

/// 中文：这个构造翻译不了，理由见 [reason]——调用方据此**回落旧解析器**。
/// English: this construct cannot be translated; see [reason] — the caller falls back to the legacy
///          parser.
final class UntranslatableExpression extends EngineExpression {
  const UntranslatableExpression(this.reason);

  final String reason;

  @override
  String toString() => '不能翻译：$reason';
}

/// 中文：**应用的表达式 → 引擎的表达式。** 解析不了（`ParseErrorNode`）或碰到翻译不了的构造时，
///       给出一条理由而不是猜。
///
///       **输入是应用归一化之后的形态，不是页面上的原文**（修复轮 8）。归一化的入口只有一个：
///       [ExpressionParser.normalizeExpressionInput]——它同时是 `ExpressionParser` 构造函数给
///       `text` 赋值时用的那一个静态方法（`expression_parser.dart:7`）。所以这里与 `ExpressionParser`
///       看到的是**同一个字符串**：不是「两份长得像的输入」，而是同一个纯函数的同一次调用结果。
///
///       这一条不是形式上的对称，它修的是两处**翻译器看不见**的改变（修复轮 7 的 two medium）：
///
///       - **`_replacePercent`**（`expression_parser.dart:957`）：应用的 `%` 不是 AST 里的后缀——
///         归一化把 `X%` 写成 `(X)/100`，而那个 `/100` 落在**整个外层项**的末尾：`2^3%` 是
///         `2^(3)/100` = 0.08、`3%^2` 是 `(3)/100^2` = 0.0003、`9^50%` 是 `9^(50)/100`。
///         喂原文时翻译器只看得见 `PostfixNode('%')`（它绑在**原子**上），写出 `((2)^(((3)/100)))`
///         ——引擎（与数学）给 1.021012125707193，而**引擎读原文 `2^3%` 本来是对的**（0.08）。
///         归一化之后 `%` 在到达语法树之前就没有了，翻译器看到的正是应用的意思。
///       - **`_normalizeGroupedNumberSeparators`**（`expression_parser.dart:634`）：逗号是不是千分位
///         由应用自己的实参个数表回答（`log2(1,024)` 是**一个**实参 1024，`atan2(7,100)` 是两个）。
///         语法树没有这条规则，**每一个逗号都是实参分隔符**，于是 `round(1,024)` 被译成两个实参、
///         引擎答 `1`（而应用给 1024）。归一化之后逗号已经被应用自己决定过了。
///
///       `ans`/`last`/记忆在**调用之前**已经由控制器替换成十进制文本，所以这里不必管它们。
/// English: **this app's expression → the engine's expression.** When the source cannot be parsed
///          (`ParseErrorNode`) or a construct cannot be translated, a reason is returned rather than a
///          guess.
///
///          **The input is this app's normalised form, not the page's raw text** (fix round 8). There is
///          exactly one entry point for that normalisation: [ExpressionParser.normalizeExpressionInput],
///          the same static method `ExpressionParser`'s constructor uses to fill `text`
///          (`expression_parser.dart:7`). So this sees **the same string** `ExpressionParser` sees — not
///          "two similar inputs" but one call to one pure function.
///
///          That is not formal symmetry; it repairs the two changes the translator could not see (fix
///          round 7's two mediums):
///
///          - **`_replacePercent`** (`expression_parser.dart:957`): this app's `%` is not an AST postfix
///            — normalisation writes `X%` as `(X)/100`, and that `/100` lands at the end of the **whole
///            enclosing term**: `2^3%` is `2^(3)/100` = 0.08, `3%^2` is `(3)/100^2` = 0.0003, `9^50%`
///            is `9^(50)/100`. Fed the raw text the translator only sees `PostfixNode('%')` (which binds
///            to the **atom**) and writes `((2)^(((3)/100)))` — the engine (and the mathematics) answer
///            1.021012125707193, while **the engine's own reading of the raw `2^3%` was right** (0.08).
///            After normalisation the `%` is gone before the tree is built, and the translator sees
///            exactly what this app means.
///          - **`_normalizeGroupedNumberSeparators`** (`expression_parser.dart:634`): whether a comma is
///            a thousands separator is decided by this app's own arity table (`log2(1,024)` is **one**
///            argument, 1024; `atan2(7,100)` is two). The syntax tree has no such rule — **every comma
///            is an argument separator** — so `round(1,024)` was translated as two arguments and the
///            engine answered `1` where this app answers 1024. After normalisation the app has already
///            decided about that comma.
///
///          `ans`/`last`/memory have already been replaced with decimal text by the controller before
///          this is called, so they need no handling here.
EngineExpression engineExpressionFor(String source) =>
    engineExpressionForNode(const ExpressionAstParser()
        .parse(ExpressionParser.normalizeExpressionInput(source)));

/// 中文：翻译一棵**已经解析好的**树。存在的理由只有一个：`UnaryNode`/`OperatorNode` 的运算符白名单
///       只能这样被测试到——`ExpressionAstParser` 今天只会产出 `+`/`-` 一元与 `+ - *` 独立运算符，
///       所以从源码出发永远走不到白名单的拒绝分支（一件**测不到的守卫**等于没有守卫）。
///       生产路径只有 [engineExpressionFor] 一个入口。
/// English: translate an **already parsed** tree. It exists for one reason: the operator whitelists for
///          `UnaryNode`/`OperatorNode` can only be tested this way — `ExpressionAstParser` produces only
///          `+`/`-` unary and `+ - *` standalone operators today, so the refusal branch is unreachable
///          from source (and a guard nothing tests is not a guard). The production path has exactly one
///          entry point, [engineExpressionFor].
EngineExpression engineExpressionForNode(ExprNode node) => _translate(node);

/// 中文：**表里这几个名字**为什么翻译不了，**逐条**写出来（「两边含义不同」那一类）。
///       闭集里的其余部分不在这个映射里，因为它们是**判据**而不是名字：表外的一切标识符
///       （[AppEngineVocabulary.engineNameFor] 拒绝）、白名单外的一切运算符（[_binaryOperators]、
///       [_unaryOperators]）、归一化之后仍然裸露的 `%`、以及解析器读不懂的片段——四类各自的理由
///       由产出它的那一处给。**它们合起来才是那份闭集**。
/// English: why **the names in this map** cannot be translated, **one by one** (the "the two sides
///          define it differently" class). The rest of the closed set is not in this map because those
///          are **judgements** rather than names: every identifier outside the table
///          ([AppEngineVocabulary.engineNameFor] refuses it), every operator outside the whitelists
///          ([_binaryOperators], [_unaryOperators]), a `%` still bare after normalisation, and any
///          fragment the parser cannot read — each carries the reason the place that produces it gives.
///          **Together they are that closed set.**
const Map<String, String> untranslatableReason = <String, String>{
  'npr': '引擎没有排列数函数（量过：`npr`/`permutations` 都不是函数名），应用自己的解析器才是它的定义处',
  'mod': '两边定义真的不同：应用的 `%` 是欧几里得余数（`7 % -3` = 1），引擎的 `mod(7,-3)` 是 -2',
  'deg': '引擎里的 `deg` 是一个**单位**，翻译过去含义就变了；应用自己的解析器有精确定义',
  'rad': '同上（引擎里的 `rad` 也是单位）',
};

EngineExpression _translate(ExprNode node) {
  // 中文：`switch` 覆盖全部节点类型——`ExprNode` 是 `sealed`，所以**穷尽性由类型系统保证**
  //       （实测：加一个节点类型，`flutter analyze` 报 `non_exhaustive_switch_statement`）。
  //       这一层只保证「每个节点都被看过」，**不保证**节点里的**运算符**与**标识符**被认过——
  //       那两层各自有白名单与拒绝未知（见文件头第 2、3 条）。
  // English: the `switch` covers every node type — `ExprNode` is `sealed`, so **exhaustiveness is
  //          guaranteed by the type system** (measured: add a node type and `flutter analyze` reports
  //          `non_exhaustive_switch_statement`). This layer only guarantees that **every node is
  //          looked at**; it does **not** vouch for the **operators** and **identifiers** inside those
  //          nodes — those two layers have their own whitelist and unknown-refusal (header items 2
  //          and 3).
  switch (node) {
    case NumberNode(:final literal):
      return TranslatedExpression(literal.replaceAll('_', ''));
    case ConstantNode(:final name):
      return _constant(name);
    case VariableNode(:final name):
      return _variable(name);
    case OperatorNode(:final op):
      // 中文：**白名单，理由与 [UnaryNode] 那条相同。** `OperatorNode` 只出现在 `toDisplayUnits`
      //       的摊平结果里（`expr_node.dart`），`_appendDisplayUnits` 今天也只摊平 `+ - *`；
      //       但从源码出发走不到这里，所以它是**测不到的守卫**——[engineExpressionForNode] 就是
      //       为它（与下面那条）存在的。
      // English: **a whitelist, for the same reason as the [UnaryNode] case below.** `OperatorNode`
      //          only appears in `toDisplayUnits` output (`expr_node.dart`) and `_appendDisplayUnits`
      //          only flattens `+ - *` today, but nothing reaches this from source, so it would be a
      //          guard no test can fail — which is what [engineExpressionForNode] is for (this case and
      //          the one below).
      if (!_binaryOperators.contains(op)) {
        return UntranslatableExpression('未知运算符 `$op`');
      }
      return TranslatedExpression(op);
    case UnaryNode(:final op, :final operand):
      // 中文：**一元运算符也有白名单。** `UnaryNode` 发出的 `$op($text)` 里那个 `op` 就是写给引擎的
      //       文本，所以它与 `_binary` 一样必须有守卫：漏掉一个，一个未来的运算符会被**原样**送到
      //       引擎去猜。（语法今天只产出 `+`/`-`，见 `_parseUnary`。）
      // English: **unary operators get a whitelist too.** The `op` in `$op($text)` is text written for
      //          the engine, so it needs a guard exactly as `_binary` has one: miss one and a future
      //          operator is forwarded to the engine **verbatim** for it to guess at. (The grammar
      //          produces only `+`/`-` today, see `_parseUnary`.)
      if (!_unaryOperators.contains(op)) {
        return UntranslatableExpression('未知一元运算符 `$op`');
      }
      final inner = _translate(operand);
      return switch (inner) {
        UntranslatableExpression() => inner,
        TranslatedExpression(:final text) => TranslatedExpression('$op($text)'),
      };
    case BinaryNode(:final op, :final left, :final right):
      return _binary(op, left, right);
    case PostfixNode(:final op, :final operand):
      final inner = _translate(operand);
      return switch (inner) {
        UntranslatableExpression() => inner,
        TranslatedExpression(:final text) => switch (op) {
            // 中文：`!` 是阶乘——引擎的写法是函数。
            // English: `!` is factorial — a function in the engine.
            '!' => TranslatedExpression('factorial($text)'),
            // 中文：**`%` 在这里一律拒绝，这是修复轮 8 的改动。** 应用的 `%` 由
            //       `_replacePercent` 在归一化里就展开成 `(X)/100`（`X` 是数字或括号组），
            //       所以**能活到这里的 `%`，应用的解析器自己读不懂**：`_parsePostfix`
            //       （`expression_parser.dart:69`）只吃 `!`，剩下的 `%` 会让 `parse()` 抛
            //       「无法识别的内容」（`pi%`、`x%`、`sin(1)%` 都是这一类）。
            //       以前这里写 `((text)/100)`——那是**替应用发明一个它没有的含义**，而且与它自己
            //       的优先级不同（`/100` 该落在整个外层项的末尾）。现在与其它翻译不了的构造走同一条路：
            //       回落旧解析器，它在同一个输入上给出的正是同一句「无法识别的内容」。
            // English: **`%` is refused here; this is fix round 8's change.** This app's `%` is expanded
            //          to `(X)/100` during normalisation by `_replacePercent` (`X` a number or a
            //          bracketed group), so **a `%` that survives to here is one this app's own parser
            //          cannot read**: `_parsePostfix` (`expression_parser.dart:69`) consumes only `!`,
            //          and any remaining `%` makes `parse()` throw "unexpected content" (`pi%`, `x%`,
            //          `sin(1)%` are all of that kind). This used to write `((text)/100)` — **inventing a
            //          meaning this app does not have**, and with a different precedence from the app's
            //          (the `/100` belongs at the end of the whole enclosing term). It now takes the same
            //          route as every other untranslatable construct: the legacy parser answers, and on
            //          that same input it gives exactly the app's own "unexpected content" error.
            '%' => const UntranslatableExpression(
                '应用自己的解析器读不懂裸露的 `%`（归一化已经把能展开的 `X%` 写成 `(X)/100`）',
              ),
            _ => UntranslatableExpression('未知后缀运算符 `$op`'),
          },
      };
    case FunctionNode(:final name, :final args):
      return _call(name, args);
    case GroupNode(:final child):
      final inner = _translate(child);
      return switch (inner) {
        UntranslatableExpression() => inner,
        TranslatedExpression(:final text) => TranslatedExpression('($text)'),
      };
    case ImplicitProductNode(:final left, :final right):
      // 中文：**并置乘法写出显式的乘号。** 这是 `phi(2)` 那一类的根：应用的读法是「常量 × 分组」，
      //       而引擎会把 `phi(2)` 读成**对函数的调用**。写成 `(…)*(…)` 之后引擎只能按乘法读。
      //       两侧都加括号：应用与引擎的优先级表未必逐条相同，括号让「树的结构」成为唯一的信息。
      // English: **juxtaposition gets an explicit multiplication sign.** That is the root of the
      //          `phi(2)` class: this app reads "constant × group" while the engine reads a **call to
      //          a function**. Written `(…)*(…)`, the engine can only read a product. Both sides are
      //          parenthesised because the two precedence tables need not agree line by line; the
      //          braces make the tree's structure the only information.
      final l = _translate(left);
      final r = _translate(right);
      if (l is UntranslatableExpression) return l;
      if (r is UntranslatableExpression) return r;
      return TranslatedExpression(
        '((${(l as TranslatedExpression).text})*(${(r as TranslatedExpression).text}))',
      );
    case ParseErrorNode(:final text):
      return UntranslatableExpression('解析器读不懂 `$text`');
  }
}

/// 中文：运算符 → 引擎的写法。`+` `-` `*` 原样；`/`、`^` 引擎都认；其余（应用语法里不该出现）
///       一律不翻译——白名单在 [_binaryOperators]。两侧加括号的理由与并置乘法相同。
/// English: operators → the engine's spelling. `+`, `-`, `*` verbatim; the engine also knows `/` and
///          `^`; anything else (which this app's grammar should not produce) is not translated — the
///          whitelist is [_binaryOperators]. Both sides are parenthesised for the same reason as
///          juxtaposition.
EngineExpression _binary(String op, ExprNode left, ExprNode right) {
  if (!_binaryOperators.contains(op)) {
    return UntranslatableExpression('未知二元运算符 `$op`');
  }
  final l = _translate(left);
  final r = _translate(right);
  if (l is UntranslatableExpression) return l;
  if (r is UntranslatableExpression) return r;
  return TranslatedExpression(
    '((${(l as TranslatedExpression).text})$op(${(r as TranslatedExpression).text}))',
  );
}

/// 中文：常量 → 引擎里的写法。**`phi` 翻成它的数值**：引擎里 `phi` 是一个**函数**（欧拉 φ），
///       直接写 `phi` 会被当成那个函数。其余的应用常量引擎都认识且同义。
/// English: constants → the engine's spelling. **`phi` is translated to its value**: in the engine
///          `phi` is a **function** (Euler's totient), so writing `phi` would be read as that
///          function. The other constants are known to the engine and mean the same.
EngineExpression _constant(String name) {
  final lower = name.toLowerCase();
  if (lower == 'phi') return const TranslatedExpression('1.618033988749895');
  if (const <String>{'inf', 'infinity'}.contains(lower)) {
    return const TranslatedExpression('infinity');
  }
  if (const <String>{'pi', 'e', 'tau'}.contains(lower)) {
    return TranslatedExpression(lower);
  }
  return UntranslatableExpression('应用里没有这个常量：`$name`');
}

/// 中文：变量 → 原样（`x`/`y`/`i` 引擎都认识；`ans`/`last` 在调用前已被替换）。
///       引擎不认识的自由变量给出一条理由。
/// English: variables pass through (`x`/`y`/`i` are known to the engine; `ans`/`last` have already
///          been substituted). A free variable the engine does not know comes back with a reason.
EngineExpression _variable(String name) {
  final unknown = AppEngineVocabulary.variableUnknownToEngine(name);
  if (unknown != null) return UntranslatableExpression(unknown);
  return TranslatedExpression(name);
}

/// 中文：函数调用 → 词表里的引擎名字；词表说「引擎不能读这个名字」时不翻译，并给出理由。
/// English: function calls → the engine name from the table; when the table says the engine cannot be
///          trusted with that name, nothing is translated and the reason travels back.
EngineExpression _call(String name, List<ExprNode> args) {
  final mapped = AppEngineVocabulary.engineNameFor(name.toLowerCase());
  if (mapped is UntranslatableExpression) return mapped;
  final engineName = (mapped as TranslatedExpression).text;
  final translated = <String>[];
  for (final arg in args) {
    final t = _translate(arg);
    if (t is UntranslatableExpression) return t;
    translated.add((t as TranslatedExpression).text);
  }
  return TranslatedExpression('$engineName(${translated.join(',')})');
}
