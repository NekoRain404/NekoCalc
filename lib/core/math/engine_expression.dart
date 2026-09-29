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
///       在被除数为负时不同），要么翻译过去会改变含义（`deg`/`rad` 在引擎里是**单位**——这条
///       有一个**写明了形状的例外**，见 [_angleConversion]：一次 `to` 换算的两侧本来就在说单位）。
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
///          (`deg`/`rad` are **units** in the engine — that last one has a **shape-limited exception**,
///          see [_angleConversion]: the two sides of one `to` conversion are talking about units to
///          begin with).
library;

import 'app_engine_vocabulary.dart';
import 'app_unit_catalog.dart';
import 'ast/expression_ast_parser.dart';
import 'expression_parser.dart';

part 'engine_expression_relation.dart';

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
const Set<String> _binaryOperators = <String>{'+', '-', '*', '/', '^', 'to'};

/// 中文：**字母运算符必须在两侧各带一个空格**。`to` 是词不是符号：引擎把 `((5)*(km))to((mi))`
///       读成 `t`·`o` 的乘积（宿主实测：`8.04672 MB*t*m^2`，**没有报错**），而
///       `((5)*(km)) to ((mi))` 才是那次换算（`3.106855961186670 mi`，`to_struct` 非空）。
///       判据按「是不是纯字母」而不是写死 `to`：下一个词运算符（`in`、`per` 之类）走同一句话，
///       不会再踩一次这个坑。符号运算符保持原样——`(+)` 与 `( + )` 在引擎那边是同一个东西，
///       而空格会让译出来的字符串离应用原文更远。
/// English: **An alphabetic operator needs one space on each side.** `to` is a word, not a symbol: the
///          engine reads `((5)*(km))to((mi))` as the product `t`·`o` (measured on the host:
///          `8.04672 MB*t*m^2`, with **no error**), while `((5)*(km)) to ((mi))` is the conversion
///          (`3.106855961186670 mi`, `to_struct` defined). The test is "is it all letters" rather than
///          a hardcoded `to`, so the next word operator (`in`, `per`) is covered by the same sentence
///          and cannot step in this hole again. Symbol operators are left as they are — `(+)` and
///          `( + )` are the same thing to the engine, and spaces would take the translated string
///          further from the source.
final RegExp _wordOperator = RegExp(r'^[A-Za-z]+$');

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
  const TranslatedExpression(this.text, {this.isRelation = false});

  final String text;

  /// 中文：**这一次翻译的是一条关系（一个 `=`），不是一个表达式。**
  ///
  ///       它必须一路传到采用规则那一层，因为**引擎对一条关系可以回一个数**——
  ///       而那个数是一个**布尔值**，不是答案。实测（宿主 `qalc` 5.12.0，桥自己的调用序列，
  ///       见 `.superpowers/backup/engine-capability-probe.md` 第八节）：
  ///
  ///       | 输入 | 引擎种类 | 印出来 | 真实含义 |
  ///       |---|---|---|---|
  ///       | `x^2=-1` | `number` | `0` | 实数范围内**无解** |
  ///       | `1=2` | `number` | `0` | 等式**不成立** |
  ///       | `x=x` | `number` | `1` | 恒等式 |
  ///
  ///       `0` 与 `1` **都是有限十进制**，所以采用规则第二级（「有限十进制 ⇒ 当数字用」）
  ///       会把它们原样放上结果行——**用户问「x²=−1 的解」，屏幕答 `0`**。
  ///       这个旗标就是让那一层能把这一支认出来的唯一凭据。
  /// English: **this translation is a relation (one `=`), not an expression.**
  ///
  ///          It has to travel all the way to the taking rule, because **the engine can answer a
  ///          relation with a number** — and that number is a **truth value**, not an answer. Measured
  ///          (host `qalc` 5.12.0, the bridge's own call sequence, see section 八 of
  ///          `.superpowers/backup/engine-capability-probe.md`):
  ///
  ///          | input | engine kind | printed | what it means |
  ///          |---|---|---|---|
  ///          | `x^2=-1` | `number` | `0` | **no solution** over the reals |
  ///          | `1=2` | `number` | `0` | the equation is **false** |
  ///          | `x=x` | `number` | `1` | an identity |
  ///
  ///          Both `0` and `1` **are finite decimals**, so the taking rule's second tier ("a finite
  ///          decimal ⇒ use it as a number") would put them straight on the result line — **the user
  ///          asks for the roots of x² = −1 and the screen answers `0`**. This flag is the only
  ///          evidence by which that layer can recognise the branch.
  final bool isRelation;
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
///         （**例外一处**：紧跟除号右边时整段括成 `((X)/100)`——`100/50%` 是
///         `100/((50)/100)` = 200。那一族与它的取证写在 `_replacePercent` 的注释里。）
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
///            is `9^(50)/100`. (**One exception**: to the right of a division the whole expansion is
///            wrapped as `((X)/100)` — `100/50%` is `100/((50)/100)` = 200. That family and its evidence
///            are in `_replacePercent`'s own comment.) Fed the raw text the translator only sees
///            `PostfixNode('%')` (which binds
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
///
///          中文：[relativePercent] 原样转交给归一化，取值必须与 `ExpressionParser` 的构造函数
///          在那一次求值里拿到的**同一个**——引擎与旧解析器读的是同一句话的两个消费者，
///          两边的模式一旦不同，同一个输入就会按模式落到两个不同的权威上（`°` 那一轮的全部内容）。
///          `%` 的两种读法与它们的判据在 `percentage_expansion.dart`。
/// English: [relativePercent] is handed straight to normalisation and must hold the **same** value
///          `ExpressionParser`'s constructor gets for that same evaluation: the engine and the legacy
///          parser are two consumers of one sentence, and if their modes differed, one input would land
///          on two different authorities depending on the setting (the whole of the `°` round). The two
///          readings of `%` and their evidence are in `percentage_expansion.dart`.
EngineExpression engineExpressionFor(String source, {bool relativePercent = false}) {
  final normalized = ExpressionParser.normalizeExpressionInput(source,
      relativePercent: relativePercent);
  final relation = _splitRelation(normalized);
  if (relation == null) {
    return engineExpressionForNode(
        const ExpressionAstParser().parse(normalized));
  }
  return _translateRelation(relation.$1, relation.$2, normalized);
}


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
///          **Together they are that closed set.** The two `deg`/`rad` rows below describe the **call**
///          form only: since this round the bare words may be units **inside one `to` conversion**
///          (the shape, the evidence and the argument are on [_angleConversion]).
const Map<String, String> untranslatableReason = <String, String>{
  'npr': '引擎没有排列数函数（量过：`npr`/`permutations` 都不是函数名），应用自己的解析器才是它的定义处',
  'mod': '两边定义真的不同：应用的 `%` 是欧几里得余数（`7 % -3` = 1），引擎的 `mod(7,-3)` 是 -2',
  'deg': '引擎里的 `deg` 是一个**单位**，翻译过去含义就变了；应用自己的解析器有精确定义'
      '（这一条只说**调用**那个形状：裸的 `deg` 在一次 `to` 换算里是单位，见 [_angleConversion]）',
  'rad': '同上（引擎里的 `rad` 也是单位；同样只在 `to` 换算里放行裸词）',
  'degangle': '应用自己的内部名字：`°` 归一化写成 `degangle(N)`，而「这个角度在当前角度单位下是多少」'
      '是应用自己的角度模式规则——翻译这一层没有模式（那是刻意的，见 `expression_parser.dart` 的'
      '`_replaceDegreeSign`），引擎也就没有它的写法。含 `°` 的表达式因此一次都不被送去让引擎猜',
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
      // 中文：**`to` 先按「一次角度换算」读一次，读不成再走原来那条。** 这个例外只有一个形状，
      //       判据、凭据与不开的那些门都在 [_angleConversion] 上；`op` 不是 `to` 时一个字都不变。
      // English: **`to` is first read as "one angle conversion"; failing that it takes the old road.**
      //          The exception has exactly one shape — the judgement, the evidence and the doors left
      //          shut are all on [_angleConversion]; with an `op` other than `to` nothing moves.
      if (op == 'to') {
        final conversion = _angleConversion(left, right);
        if (conversion != null) return conversion;
      }
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
      return TranslatedExpression(_productText(
        (l as TranslatedExpression).text,
        (r as TranslatedExpression).text,
      ));
    case SexagesimalNode():
      // 中文：**度分秒字面量在这里一律拒绝。** 归一化已经把它写成 `degangle(…)`（见
      //       `expression_input_normalization.dart` 的 `_replaceDegreeSign`），所以**生产路径上
      //       这个节点根本到不了翻译层**——[engineExpressionFor] 先归一化再建树。这一支存在是
      //       因为 `ExprNode` 是 `sealed`（穷尽性由类型系统保证），而它必须是**拒绝**：
      //       「这个角度在当前角度单位下是多少」是应用自己的规则，翻译这一层没有模式，引擎也没有
      //       它的写法。若哪一天有人绕过归一化把原文送到这里，宁可回落旧解析器，也不许把
      //       `°`/`′`/`″` 原样丢给引擎去猜（那正是 [`_translate`] 头部第 2、3 条要挡的形状）。
      // English: **a DMS literal is refused here, always.** Normalisation has already written it as
      //          `degangle(…)` (see `_replaceDegreeSign` in `expression_input_normalization.dart`), so
      //          **this node cannot reach the translator on the production path at all** —
      //          [engineExpressionFor] normalises before it builds a tree. The case exists because
      //          `ExprNode` is `sealed` (the type system guarantees exhaustiveness), and it has to be a
      //          **refusal**: "what is this angle in the current angle unit" is this app's own rule,
      //          this layer has no mode, and the engine has no spelling for it. If someone ever sends
      //          raw source past normalisation, falling back to the legacy parser is better than
      //          handing `°`/`′`/`″` to the engine to guess at (exactly the shape header items 2 and 3
      //          of [`_translate`] exist to stop).
      return const UntranslatableExpression(
        '应用自己的度分秒字面量（`3°30′0″`）：归一化已经把它写成 `degangle(…)`，'
        '这一层没有它的引擎写法',
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
  // 中文：词运算符两侧各留一个空格，见 [_wordOperator]——不留的话引擎把它读成两个符号的乘积，
  //       而且**不报错**（宿主实测）。
  // English: a word operator gets one space on each side; see [_wordOperator] — without them the engine
  //          reads it as a product of two symbols, and **does not error** (measured on the host).
  final pad = _wordOperator.hasMatch(op) ? ' ' : '';
  return TranslatedExpression(
    '((${(l as TranslatedExpression).text})$pad$op$pad(${(r as TranslatedExpression).text}))',
  );
}

/// 中文：**本翻译里「两个东西相乘」唯一的写法**：`(A)*(B)`。并置乘法（[ImplicitProductNode]）与
///       下面那次角度换算共用它，所以「乘起来写给引擎是什么样」只有一处答案。（`_binary` 里的
///       `*` 写出同一个字符串，但那是**另一个构造**——显式乘号；两者印出来一样是应该的。）
/// English: **the one spelling of "two things multiplied" in this translation**: `(A)*(B)`.
///          Juxtaposition ([ImplicitProductNode]) and the angle conversion below share it, so "what a
///          product looks like written for the engine" has exactly one answer. (`_binary`'s `*` emits
///          the same string, but that is **another construct** — the explicit sign; printing the same
///          is the point.)
String _productText(String left, String right) => '(($left)*($right))';

/// 中文：**一次角度换算：`<值> <源单位> to <目标单位>`——`►DRG`（HiPER 的 `TO_DRG`）插的那一条。**
///
///       这个形状是**本轮唯一新放行的东西**，所以它窄到什么程度、为什么仍然安全，都要写清楚。
///
///       **一、只放行哪一个拼法：`deg`，而且只在两个位置上。** 六个角度拼法（[kAngleUnits]）里，
///       五个早在 `kAppUnits` 里（`rad`/`gon`/`turn`/`arcmin`/`arcsec`），**只有 `deg` 是本轮新开的
///       一格**。它开在**一次换算的两侧**，别处一个字都不动：`deg` 单独（`deg`）、`5 deg`、
///       `deg + 1`、`deg(90)` 仍然一律翻译不了（实测），于是仍旧回落旧解析器——旧解析器对裸的
///       `deg` 给的正是应用自己的那句「Function deg needs (」。
///
///       **二、形状判据（两条，都在这里）：**
///       1. `to` 的**右**操作数必须是一个裸单位词，且拼法在 [kAngleUnits] 里；
///       2. `to` 的**左**操作数必须是「值 × 一个裸单位词」，右边那个词也在 [kAngleUnits] 里。
///       两条都要求**单位是写出来的词**（`VariableNode`，不是括号、不是运算、不是别的节点）。
///       不满足就返回 `null`，调用方**原样走老路**——所以这不是放宽，是多了一条窄路。
///
///       **三、为什么这个形状里的单位含义是清楚的，而不是「替引擎猜」。** `to` 是本应用自己的
///       换算运算符（`5 km to mi` 早就是这个意思，`expression_ast_parser.dart` 的 `_parseExpression`），
///       而它两侧的裸词只可能是**单位名**——`<值> <单位> to <单位>` 里没有第二个读法。反过来说：
///       这扇门不承认任何「裸数 + 目标单位」的写法（`90 to deg` 过不去，因为左边不是「值 × 单位」），
///       那正是最坏的一类静默错值——它的源单位会变成**当前角度模式**（实测：`90 to rad` 在
///       DEG/RAD/GRA 三档下分别是 `1.570796327 rad` / `90 rad` / `1.413716694 rad`）。
///
///       **四、旧注释里那两句被本轮实测改掉了。** 旧注释说「`90 to deg` → `90°`：只在裸数后面贴上
///       度的记号，值一个字节没变」，并据此说「反方向（→ 度）不存在」。两句都只在**一半**上成立：
///       - 「贴记号」只在 **DEG** 下成立；**RAD** 下 `90 to deg` = `5156.620156°`（引擎把 90 读成
///         弧度）。所以正确的说法是「源单位是当前角度模式」，不是「值不变」。
///       - 「→ 度」在引擎里一直存在：`90 rad to deg` = `5156.620156°`（实测）。过去过不去的是
///         **应用这一侧**（`deg` 不是可插入单位），不是引擎做不到。
///
///       **五、本轮量到、但本轮**没有**改的一条。** `X to rad`（以及 `gon`/`turn`/`arcmin`/
///       `arcsec`）今天从 `CONV` 面板就能按出来，而它的源单位是当前角度模式——所以同一个输入在
///       DEG 与 RAD 下给两个不同的答案（上面那张表）。关掉它要改一个已经在工作的键路上的行为，
///       而且那一步在 DEG 下给出的答案未必是错的（用户的角度模式就是他声明的角度单位）；本轮的
///       做法是**把新的入口写成模式无关的**（两侧都写出来，实测三档同答），并把这一条量下来留给
///       下一轮。`►DRG` 这条路上没有它：源单位永远写出来。
///
///       **六、凭什么说这几个拼法引擎读得对、读得稳。** 六个拼法、两个方向、三种角度模式，逐条
///       量过，表在 `app_unit_catalog.dart` 的 [kAngleUnits] 上；被拒绝的 `grad`（值对、单位坏）
///       也在那里。
///
///       产出与 [_binary] 的形状逐字相同（`((左) to (右))`，左是一个 `(值)*(单位)`），所以引擎那边
///       看到的还是它已经读了几轮的那一种串。
/// English: **one angle conversion: `<value> <source unit> to <target unit>` — what `►DRG` (HiPER's
///          `TO_DRG`) inserts.**
///
///          This shape is **the only new admission this round**, so how narrow it is and why it is
///          still safe both have to be written down.
///
///          **1. Which spelling it admits: `deg`, and only in two positions.** Of the six angle
///          spellings ([kAngleUnits]) five have been in `kAppUnits` all along
///          (`rad`/`gon`/`turn`/`arcmin`/`arcsec`); **`deg` is the one cell opened this round**, and it
///          is opened **on the two sides of one conversion** — nowhere else moves. On its own
///          (`deg`), in `5 deg`, in `deg + 1` and in `deg(90)` it still cannot be translated
///          (measured), so it still falls back to the legacy parser, whose own answer for a bare `deg`
///          is this app's "Function deg needs (".
///
///          **2. The shape judgement (two clauses, both here):**
///          1. the **right** operand of `to` must be a bare unit word whose spelling is in
///             [kAngleUnits];
///          2. the **left** operand must be "a value × a bare unit word", that word also in
///             [kAngleUnits].
///          Both require the unit to be **a written word** (`VariableNode`, not a bracket, not an
///          operator, not another node). When either fails this returns `null` and the caller **takes
///          the old road unchanged** — so this is not a relaxation, it is one narrow path.
///
///          **3. Why the unit meaning is clear in this shape rather than "guessed for the engine".**
///          `to` is this app's own conversion operator (`5 km to mi` has meant that all along;
///          `_parseExpression` in `expression_ast_parser.dart`), and a bare word on either side of it
///          can only be a **unit name** — in `<value> <unit> to <unit>` there is no second reading.
///          The converse is the important half: this door admits no "bare number plus a target unit"
///          shape (`90 to deg` cannot get through, because its left side is not "a value × a unit"),
///          which is the worst class of silent wrong value — its source unit becomes the **current
///          angle mode** (measured: `90 to rad` is `1.570796327 rad` / `90 rad` / `1.413716694 rad`
///          under DEG / RAD / GRA).
///
///          **4. Two sentences in the old notes that this round's measurements replaced.** The old
///          note said "`90 to deg` → `90°`: a degree symbol is attached to a bare number and the value
///          does not move a byte", and concluded that "the other direction (→ degrees) does not
///          exist". Both hold on **one side only**:
///          - "attaches a symbol" holds only under **DEG**; under **RAD** `90 to deg` measures
///            `5156.620156°` (the engine reads 90 as radians). The right sentence is "the source unit
///            is the current angle mode", not "the value does not move".
///          - "→ degrees" has always existed in the engine: `90 rad to deg` = `5156.620156°`
///            (measured). What did not exist was the spelling on **this app's** side (`deg` was not an
///            insertable unit) — not the engine's ability.
///
///          **5. Something measured this round that this round did *not* change.** `X to rad` (and
///          `gon`/`turn`/`arcmin`/`arcsec`) can be pressed out of the `CONV` sheet today, and its source
///          unit is the current angle mode — so one input gives two different answers under DEG and RAD
///          (the table above). Closing it would change the behaviour of a path that already works, and
///          under DEG the answer it gives need not be wrong (the user's angle mode *is* the unit he
///          declared); what this round does instead is make **the new entrance mode-independent**
///          (both sides written out, measured identical in all three modes) and record this one for
///          the next round. `►DRG`'s path does not have it: the source unit is always written out.
///
///          **6. Why these spellings can be trusted to be read correctly and stably.** Six spellings,
///          both directions, three angle modes, measured one by one; the table is on [kAngleUnits] in
///          `app_unit_catalog.dart`, and the refused `grad` (right value, corrupted unit) is there too.
///
///          What it emits is item-for-item [_binary]'s shape (`((left) to (right))`, with the left a
///          `(value)*(unit)`), so the engine sees the same kind of string it has read for rounds.
EngineExpression? _angleConversion(ExprNode left, ExprNode right) {
  final target = _unitWord(right);
  if (target == null) return null;
  if (left is! ImplicitProductNode) return null;
  final source = _unitWord(left.right);
  if (source == null) return null;
  final value = _translate(left.left);
  if (value is UntranslatableExpression) return value;
  return TranslatedExpression(
    '((${_productText((value as TranslatedExpression).text, source)}) to ($target))',
  );
}

/// 中文：**这个节点是不是一个裸的单位词**（拼法在 [kAngleUnits] 里）——是就返回那个拼法，不是就
///       返回 `null`。**只认裸的 `VariableNode`**：括号、运算、函数调用一概不认，那是刻意的
///       （「认出别的写法」等于替引擎猜它的意思，而这一层不猜）。
/// English: **is this node a bare unit word** (spelling in [kAngleUnits]) — the spelling when it is,
///          `null` when it is not. **Only a bare `VariableNode` counts**: brackets, operators and
///          calls are all rejected on purpose (recognising other spellings would mean guessing what
///          the engine makes of them, and this layer does not guess).
String? _unitWord(ExprNode node) {
  if (node is! VariableNode) return null;
  return kAngleUnitSymbols.contains(node.name) ? node.name : null;
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
  final shape = _seriesShapeRefusal(name, args);
  if (shape != null) return shape;
  final translated = <String>[];
  for (final arg in args) {
    final t = _translate(arg);
    if (t is UntranslatableExpression) return t;
    translated.add((t as TranslatedExpression).text);
  }
  return TranslatedExpression('$engineName(${translated.join(',')})');
}

/// 中文：**拟合调用只在这一种形状下写给引擎：每一个实参都是一行矩阵（`matrix(1,…)`）。**
///       其余形状一律拒绝，理由是**量出来的**——引擎对它们答的不是这个调用，而答案照样上屏。
///
///       实测（宿主 libqalculate 5.12.0，按桥的调用序列与选项，种类判据逐行照抄
///       `QalculateEngine.kt:386-397`）。**探测程序本身已经核不了了**：它是临时写的，从未进过
///       仓库，住在本机 `/tmp/nekocalc_fit_probe/probe.cc`，已不存在。下面这张表就是那次测量的
///       读数，同一张表逐行留在 `.superpowers/backup/stat-fits-report.md:82-90`：
///
///       | 调用 | 引擎印出来 | 种类 | `isDisplayable` |
///       |---|---|---|---|
///       | `linearfit(matrix(2,5,1,2,3,4,5,2,4,6,8,10))` | `[x  2x  3x  4x  5x]` | `structured` | **放行** |
///       | `linearfit(matrix(2,2,1,2,3,4))` | `x + 1`（**X、Y 反了**，正解 `x + 2`） | `symbolic` | **放行** |
///       | `linearfit(matrix(1,3,1,2,3),matrix(3,3,…1…9))` | `[(3x - 2)  (3x - 1)  3x]` | `structured` | **放行** |
///       | `linearfit(matrix(1,5,1,2,3,4,5),matrix(1,5,2,4,6,8,10))` | `2x`（正解） | `symbolic` | 放行 |
///       | `linearfit(matrix(5,2,1,2,2,4,3,6,4,8,5,10))` | `2x`（正解，两**列**） | `symbolic` | 放行 |
///       | `quadraticfit(matrix(2,3,1,2,3,1,4,9))` | 原样退回 | `arithmetic` | 不放行 |
///       | `quadraticfit(matrix(3,3,…))` | `element(multisolve(…))` | `arithmetic` | 不放行 |
///
///       前两行是**第一个**实参多行，第三行是**第二个**实参多行——两个方向都实测过。第三行尤其
///       要紧：它说明「只有第一个实参要管」是错的，而它自己也是这次量出来的。
///
///       **为什么判据只能问输入。** 正确形状的答复（`2x`）与第二行那个错值（`x + 1`）**种类相同
///       （都是 `symbolic`）、印出来的形状也相同**，`_selectEngineResult` 收到的两份回执在这两项
///       上逐字一样——没有任何一条按结果看的规则分得开它们。所以判据落在翻译层，与
///       [AppEngineVocabulary.engineNameFor] 是同一处、同一种做法：**形状不对，引擎根本不会被问。**
///
///       括号先剥掉（[GroupNode] 就是括号本身）：`linearfit((matrix(1,5,…)),matrix(1,5,…))`
///       实测印的正是 `2x`，而 `linearfit((matrix(2,5,…)))` 实测在 else 那一支上——剥掉括号之后
///       前者被收下、后者被拒，两边的读数都对。**只剥括号**：`+`、乘法这些包装一概不剥，
///       它们都落进拒绝那一侧（关上的一侧）。
///
///       形状之外的拒绝**没有放宽、也没有收紧任何东西**：这条只作用于
///       [AppFunction.oneSeriesPerArgument] 为真的那三行。
/// English: **a fit call is written for the engine under exactly one shape: every argument is a one-row
///          matrix (`matrix(1,…)`).** Every other shape is refused, and the reason is **measured** —
///          the engine does not answer such a call, and the answer reaches the screen anyway.
///
///          Measured (host libqalculate 5.12.0, the bridge's call sequence and options, the kind
///          predicate copied line by line from `QalculateEngine.kt:386-397`). **The probe itself
///          can no longer be checked**: it was written ad hoc, never entered the repository, and
///          lived at `/tmp/nekocalc_fit_probe/probe.cc` on this machine's `/tmp`, no longer present.
///          The table below is that measurement's readings; the same table, row for row, is in
///          `.superpowers/backup/stat-fits-report.md:82-90`:
///
///          | call | what the engine prints | kind | `isDisplayable` |
///          |---|---|---|---|
///          | `linearfit(matrix(2,5,1,2,3,4,5,2,4,6,8,10))` | `[x  2x  3x  4x  5x]` | `structured` | **admitted** |
///          | `linearfit(matrix(2,2,1,2,3,4))` | `x + 1` (**X and Y swapped**; the answer is `x + 2`) | `symbolic` | **admitted** |
///          | `linearfit(matrix(1,3,1,2,3),matrix(3,3,…1…9))` | `[(3x - 2)  (3x - 1)  3x]` | `structured` | **admitted** |
///          | `linearfit(matrix(1,5,1,2,3,4,5),matrix(1,5,2,4,6,8,10))` | `2x` (right) | `symbolic` | admitted |
///          | `linearfit(matrix(5,2,1,2,2,4,3,6,4,8,5,10))` | `2x` (right, two **columns**) | `symbolic` | admitted |
///          | `quadraticfit(matrix(2,3,1,2,3,1,4,9))` | handed straight back | `arithmetic` | not admitted |
///          | `quadraticfit(matrix(3,3,…))` | `element(multisolve(…))` | `arithmetic` | not admitted |
///
///          The first two rows have a multi-row **first** argument and the third a multi-row **second**
///          one — both directions were measured. The third matters most: it shows "only the first
///          argument needs watching" is false, and it is itself a product of this round.
///
///          **Why the judgement can only ask the input.** The right shape's answer (`2x`) and the second
///          row's wrong value (`x + 1`) have the **same kind** (both `symbolic`) and the same printed
///          shape — the two receipts `_selectEngineResult` sees are word for word alike on both counts,
///          and no result-side rule can tell them apart. So the judgement sits in the translation layer,
///          the same place and the same device as [AppEngineVocabulary.engineNameFor]: **wrong shape,
///          the engine is never asked.**
///
///          Parentheses are stripped first ([GroupNode] *is* the parentheses):
///          `linearfit((matrix(1,5,…)),matrix(1,5,…))` measures `2x` and `linearfit((matrix(2,5,…)))`
///          measures the else branch — stripped, the first is taken in and the second refused, and both
///          readings are right. **Only parentheses are stripped**: `+`, products and every other
///          wrapper fall on the refused side (the closed side).
///
///          Nothing outside the shape is relaxed or tightened: this acts only on the rows where
///          [AppFunction.oneSeriesPerArgument] is true.
UntranslatableExpression? _seriesShapeRefusal(String name, List<ExprNode> args) {
  final canonical = AppEngineVocabulary.canonicalIdentifier(name);
  if (canonical == null) return null;
  if (!AppEngineVocabulary.identifiers[canonical]!.oneSeriesPerArgument) return null;
  if (args.every(_isOneRowMatrixCall)) return null;
  return UntranslatableExpression(
    '`$canonical` 要的是每个实参一条序列（写成 `matrix(1,…)`）：这个形状引擎读成'
    '「按列各拟合一次」或另一对 X、Y，而答案照样上屏',
  );
}

/// 中文：**这个节点是不是「一行矩阵」这个应用写法**——`matrix(<1>, …)`，外面的括号先剥掉。
///       它只认应用自己的写法：`matrix` 是词表里的名字（[ExpressionParser.canonicalFunctionName]
///       折别名与大小写，与词表用的是同一个折叠），行数只认**字面量** `1`。认出别的写法就等于
///       替引擎猜它的意思，而这一层不猜（见 [_seriesShapeRefusal]）。
/// English: **is this node "a one-row matrix" in this app's spelling** — `matrix(<1>, …)`, with
///          enclosing parentheses stripped first. It only recognises this app's own spelling:
///          `matrix` is a name in the vocabulary ([ExpressionParser.canonicalFunctionName] folds
///          aliases and case, the same fold the vocabulary uses) and the row count is accepted only as
///          the **literal** `1`. Recognising other spellings would mean guessing what the engine makes
///          of them, and this layer does not guess (see [_seriesShapeRefusal]).
bool _isOneRowMatrixCall(ExprNode node) {
  final inner = node is GroupNode ? node.child : node;
  if (inner is! FunctionNode) return false;
  if (ExpressionParser.canonicalFunctionName(inner.name) != 'matrix') return false;
  if (inner.args.isEmpty) return false;
  final rows = inner.args.first;
  return rows is NumberNode && num.tryParse(rows.literal.replaceAll('_', '')) == 1;
}
