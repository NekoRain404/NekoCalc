/// 中文：**把应用自己的表达式翻译成引擎读得懂的那一份，然后才去问引擎。**
///
///       这是修复轮 6 之后的第三次换判据，前两次（枚举引擎的误读、按值比较）都失败了，
///       原因同一个：**它们都在猜引擎怎么理解我们的输入**——那是开放面。
///       反过来做：**我们自己知道每个标识符是什么意思**，所以在问之前就把表达式写成引擎的写法。
///
///       **为什么这一次的完备性是可证的**：翻译是**应用自己的语法树上的纯函数**，
///       而语法树是 `sealed` 的（11 个 `final class` 节点 + 1 个 `sealed` 基类），
///       Dart 的穷尽性检查在编译期保证 `switch` 覆盖全部——**漏一个节点 `flutter analyze` 直接报错**，
///       不是靠人列清单；标识符那一层由 [AppEngineVocabulary] 这张**封闭**表回答（应用自己定义的名字，
///       有限）。于是「哪些构造翻译不了」是一个**闭集**，可以逐条列出来（[untranslatableReason]），
///       也可以在测试里穷尽枚举。
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
///          **Why completeness is provable this time**: the translation is a **pure function of this
///          app's own syntax tree**, and that tree is `sealed` (11 `final class` nodes on one `sealed`
///          base), so Dart's exhaustiveness check makes an omitted node **a compile error in
///          `flutter analyze`** rather than something a human has to enumerate; the identifier layer is
///          answered by the **closed** [AppEngineVocabulary] table (the names this app defines —
///          finite). "Which constructs cannot be translated" is therefore a **closed set**, listed one
///          by one in [untranslatableReason] and enumerated exhaustively in the tests.
///
///          **Anything untranslatable goes to the legacy parser** (the same route as hard boundary 1):
///          those constructs either have no engine counterpart (`npr`), or the two sides genuinely
///          **define them differently** (`mod`: this app's `%` is the Euclidean remainder, the engine's
///          `mod` differs for negative dividends), or translating them would change the meaning
///          (`deg`/`rad` are **units** in the engine).
library;

import 'app_engine_vocabulary.dart';
import 'ast/expression_ast_parser.dart';

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
///       `ans`/`last`/记忆在**调用之前**已经由控制器替换成十进制文本，所以这里不必管它们。
/// English: **this app's expression → the engine's expression.** When the source cannot be parsed
///          (`ParseErrorNode`) or a construct cannot be translated, a reason is returned rather than a
///          guess.
///
///          `ans`/`last`/memory have already been replaced with decimal text by the controller before
///          this is called, so they need no handling here.
EngineExpression engineExpressionFor(String source) {
  final node = const ExpressionAstParser().parse(source);
  return _translate(node);
}

/// 中文：一个构造为什么翻译不了，**逐条**写出来——这是那份闭集。
/// English: why one construct cannot be translated, **one by one** — this is that closed set.
const Map<String, String> untranslatableReason = <String, String>{
  'npr': '引擎没有排列数函数（量过：`npr`/`permutations` 都不是函数名），应用自己的解析器才是它的定义处',
  'mod': '两边定义真的不同：应用的 `%` 是欧几里得余数（`7 % -3` = 1），引擎的 `mod(7,-3)` 是 -2',
  'deg': '引擎里的 `deg` 是一个**单位**，翻译过去含义就变了；应用自己的解析器有精确定义',
  'rad': '同上（引擎里的 `rad` 也是单位）',
};

EngineExpression _translate(ExprNode node) {
  // 中文：`switch` 覆盖全部节点类型——`ExprNode` 是 `sealed`，所以**穷尽性由类型系统保证**，
  //       这正是「这一次完备性可证」的来源。
  // English: the `switch` covers every node type — `ExprNode` is `sealed`, so **exhaustiveness is
  //          guaranteed by the type system**, which is where this round's provable completeness comes
  //          from.
  switch (node) {
    case NumberNode(:final literal):
      return TranslatedExpression(literal.replaceAll('_', ''));
    case ConstantNode(:final name):
      return _constant(name);
    case VariableNode(:final name):
      return _variable(name);
    case OperatorNode(:final op):
      return TranslatedExpression(op);
    case UnaryNode(:final op, :final operand):
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
            // 中文：`!` 是阶乘——引擎的写法是函数；`%` 是百分号，展开成除以 100。
            // English: `!` is factorial (a function in the engine); `%` is percent, expanded to a
            //          division by 100.
            '!' => TranslatedExpression('factorial($text)'),
            '%' => TranslatedExpression('(($text)/100)'),
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
///       一律不翻译。两侧加括号的理由与并置乘法相同。
/// English: operators → the engine's spelling. `+`, `-`, `*` verbatim; the engine also knows `/` and
///          `^`; anything else (which this app's grammar should not produce) is not translated. Both
///          sides are parenthesised for the same reason as juxtaposition.
EngineExpression _binary(String op, ExprNode left, ExprNode right) {
  if (!const <String>{'+', '-', '*', '/', '^'}.contains(op)) {
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
