part of 'engine_expression.dart';

/// 中文：**关系的翻译：两边各译一次，再拼回一个 `=`。**
///
///       **为什么不给应用自己的语法加一个"关系节点"。** `ExprNode` 是 `sealed`，
///       加一个节点意味着动语法、动 `ExpressionParser`、动每一个穷尽 `switch`——
///       而**应用自己的语法本来就不该有变量也没有关系**（这是「旧解析器对含变量的输入没有发言权」
///       那条判据成立的前提）。关系只在**送引擎**这一侧有位置：引擎收一句 `左=右`，
///       自己决定怎么解。所以这里不建节点，只在字符串层面分一次、各译一次、拼回去。
///
///       **两边都得译得过。** 任何一边译不了就整条译不了，理由用那一边给的（**不新造一句话**）——
///       于是 `x<=3` 会走到「解析器读不懂 `x<`」，而 `a=b=c` 由 [_splitRelation] 判为不是关系，
///       落回原来那条路。**没有一条新的拒绝理由，闭集没有变大。**
/// English: **translating a relation: translate each side, then put the `=` back.**
///
///          **Why not give this app's own grammar a "relation node".** `ExprNode` is `sealed`, so a
///          new node means touching the grammar, `ExpressionParser`, and every exhaustive `switch` —
///          while **this app's grammar is supposed to have neither variables nor relations** (that is
///          the premise behind "the legacy parser has no standing on an input with variables"). A
///          relation has a place only on the **engine-bound** side: the engine takes one sentence
///          `left=right` and decides how to solve it. So nothing is built into a node here; the split,
///          the two translations and the join all happen at the string level.
///
///          **Both sides must translate.** If either cannot, the whole thing cannot, and the reason
///          given is the one that side produced (**no new sentence is invented**) — so `x<=3` lands on
///          "the parser cannot read `x<`" and `a=b=c` is judged not a relation by [_splitRelation] and
///          falls back to the existing route. **Not one new refusal reason: the closed set does not
///          grow.**
/// 中文：**顶层分号切开的若干条关系——方程组。**
///
///       一条关系走 [engineExpressionFor] 里原来那条路（一个 `=`，两边各译一次）；
///       **两条以上**才走这里。返回 `null` 表示"这不是方程组，按原来那条路走"。
///
///       ⚠️ **分隔符为什么是分号不是逗号。** 逗号在应用自己的语法里有活干（函数实参、千分位），
///       拿它当方程组的分隔符会让 `max(1,2)=2` 这种式子有两种读法。分号在应用自己的语法里
///       **没有位置**，所以它只有一个意思。`grep -n "';'"` 在 `lib/core/math/` 下零命中——
///       归一化不动它，与等号同一条判据。
/// English: **the relations cut apart by top-level semicolons — a system.**
///
///          One relation takes the existing road in [engineExpressionFor] (a single `=`, each side
///          translated once); **two or more** come here. `null` means "this is not a system, take the
///          existing road".
///
///          ⚠️ **Why the separator is a semicolon and not a comma.** A comma has a job in this app's
///          own grammar (function arguments, thousands grouping), so using it as a system separator
///          would give `max(1,2)=2` two readings. A semicolon has **no place** in this grammar, so it
///          has exactly one meaning. `grep -n "';'"` finds nothing under `lib/core/math/`: normalisation
///          leaves it alone, the same judgement as the equals sign.
List<String>? _splitRelations(String source) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var index = 0; index < source.length; index++) {
    final ch = source[index];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
    } else if (ch == ';' && depth == 0) {
      parts.add(source.substring(start, index).trim());
      start = index + 1;
    }
  }
  if (parts.isEmpty) return null;
  parts.add(source.substring(start).trim());
  if (parts.any((part) => part.isEmpty)) return null;
  return parts;
}

/// 中文：**方程组：每一条各自译一遍，再包成引擎的 `multisolve([...], x, y, …)`。**
///
///       **未知数名单必须我们自己给**（引擎不收空的，见 [collectVariableNames]），
///       而它取自每一条关系的**两侧**——`2x+3y=7` 的左边也一样有名字。
///
///       任何一条译不过就整条译不过，理由用那一条给的（**不新造一句话**）。
/// English: **a system: translate each relation, then wrap it in the engine's
///          `multisolve([...], x, y, …)`.**
///
///          **The unknown list is ours to supply** (the engine does not take an empty one; see
///          [collectVariableNames]), and it is collected from **both sides** of each relation — the
///          left side of `2x+3y=7` carries names too.
///
///          If any relation fails, the whole thing fails, with the reason that one produced (**no new
///          sentence is invented**).
EngineExpression _translateSystem(List<String> parts) {
  final relations = <String>[];
  final variables = <String>[];
  for (final part in parts) {
    final relation = _splitRelation(part);
    if (relation == null) {
      return UntranslatableExpression('`$part` 不是一条关系');
    }
    final leftNode = const ExpressionAstParser().parse(relation.$1);
    final rightNode = const ExpressionAstParser().parse(relation.$2);
    final translatedLeft = _translate(leftNode);
    if (translatedLeft is UntranslatableExpression) return translatedLeft;
    final translatedRight = _translate(rightNode);
    if (translatedRight is UntranslatableExpression) return translatedRight;
    collectVariableNames(leftNode, variables);
    collectVariableNames(rightNode, variables);
    relations.add('${(translatedLeft as TranslatedExpression).text}'
        '=${(translatedRight as TranslatedExpression).text}');
  }
  // 中文：**一个未知数都没有 ⇒ 这不是方程组，是一串判断式。** `1=2; 3=4` 没有解的余地，
  //       交给 `multisolve` 只会让它原样退回；而"退回"的形状与无解一样，用户看不出区别。
  //       **索性在这里拒绝。**
  // English: **no unknown at all ⇒ this is not a system, it is a list of assertions.** `1=2; 3=4` has
  //          nothing to solve for, and handing it to `multisolve` only makes it echo back — a shape
  //          indistinguishable from "no solution". **Refuse it here instead.**
  // 中文：**单位名不是未知数。** `_variable` 放行的名字有两类：真未知数（`x`/`y`/`i`）
  //       与**单位**（`km` 之类，走的是同一张封闭表）。`2 km = x` 里 `km` 是量的一部分，
  //       把它当未知数交给 `multisolve` 就是在问引擎"对千米求解"。
  // English: **a unit name is not an unknown.** `_variable` lets two kinds through: real unknowns
  //          (`x`/`y`/`i`) and **units** (`km` and friends, which go through the same closed table).
  //          In `2 km = x` the `km` is part of a quantity, and handing it to `multisolve` asks the
  //          engine to "solve for kilometres".
  final unknowns = variables.where((name) => !isAppUnit(name)).toList();
  if (unknowns.isEmpty) {
    return const UntranslatableExpression('方程组里没有未知数');
  }
  return TranslatedExpression(
      'multisolve([${relations.join(', ')}], ${unknowns.join(', ')})',
      isRelation: true,
      isSystem: true);
}

EngineExpression _translateRelation(String left, String right, String whole) {
  final leftNode = const ExpressionAstParser().parse(left);
  final rightNode = const ExpressionAstParser().parse(right);
  final translatedLeft = _translate(leftNode);
  if (translatedLeft is UntranslatableExpression) return translatedLeft;
  final translatedRight = _translate(rightNode);
  if (translatedRight is UntranslatableExpression) return translatedRight;
  final text = '${(translatedLeft as TranslatedExpression).text}'
      '=${(translatedRight as TranslatedExpression).text}';
  // 中文：**归一化之后仍然不认识的字符一律拒绝。** 两边分开译时，落在**等号上**的那个字符是谁
  //       （`<`、`>`、`!`、`~`）根本进不了任何一边，于是 `x<` 那一侧会先报错——那是**运气**，
  //       不是判据。这里明写一条：**整句里除等号外只允许两边各自认得的东西**，由下面这条
  //       `+`/`-`/`*`/`/`… 的白名单兜住。理由沿用 [_binaryOperators] 那一类，不新造一句话。
  // English: **anything still unrecognised after normalisation is refused.** When the two sides are
  //          translated apart, whichever character sat **on the equals sign** (`<`, `>`, `!`, `~`)
  //          never enters either side, so the `x<` side happens to error first — that is **luck**, not
  //          a judgement. This states one explicitly: apart from the equals sign the whole sentence may
  //          contain only what the two sides each recognise, which the whitelist below enforces. The
  //          reason reuses the [_binaryOperators] class rather than inventing a sentence.
  final leftover = _unrecognisedOutsideRelation(whole);
  if (leftover != null) return UntranslatableExpression(leftover);
  return TranslatedExpression(text, isRelation: true);
}

/// 中文：`=` 以外不许出现比较符号。**这一条是白名单，不是黑名单**——
///       它逐个字符问「这个字符在应用自己的语法里有位置吗」，没位置的连成一个片段报出去。
/// English: nothing but `=` may appear from the comparison family. **A whitelist, not a blacklist** —
///          it asks of each character whether this app's own grammar has a place for it, and reports
///          the ones that do not, joined into one fragment.
String? _unrecognisedOutsideRelation(String source) {
  final offenders = <String>[];
  for (final rune in source.runes) {
    final ch = String.fromCharCode(rune);
    if (_relationAllowedChars.contains(ch)) continue;
    if (RegExp(r'[A-Za-z0-9_\s]').hasMatch(ch)) continue;
    if (offenders.isEmpty || offenders.last != ch) offenders.add(ch);
  }
  if (offenders.isEmpty) return null;
  return '未知运算符 `${offenders.join()}`';
}

/// 中文：**整句里允许出现的字符。** 名字与数字由上面那条正则放行，这里只列运算符与括号。
/// English: **the characters allowed in the whole sentence.** Names and digits are waved through by the
///          regex above; this lists only operators and brackets.
const Set<String> _relationAllowedChars = <String>{
  '=', '+', '-', '*', '/', '^', '(', ')', '.', ',', '%', '!', '°', '√', 'π', '∞',
  '×', '÷', '−', '·',
};

/// 中文：**从一句话里切出"顶层等号"两侧**，切不出关系就回 `null`（调用方走原来那条路）。
///
///       规则三条，每条都对应一族必须被拒的形状：
///
///       1. **深度 0 上的等号恰好一个。** 零个不是关系（`x^2` 照旧是表达式）；两个以上也不是
///          （`a=b=c` 是什么，应用没有立场替引擎决定）。**表达式里的等号**（`root(x=3,2)`）在
///          深度 > 0 上，一律不算。
///       2. **两侧都非空。** `=3` 与 `x=` 不是关系，是打字打了一半。
///       3. **紧挨着等号的比较符号 ⇒ 这不是关系。** `==`、`!=`、`<=`、`>=` 里的等号**不是
///          等号**，那是**另一个运算符**——而应用自己的语法里没有它。
///          （`==` 天然被第 1 条挡下，另外三个由这一条挡下。）
///
///          ⚠️ **`!=` 这一条是量出来的，不是想出来的。** 第一版没有它，于是 `x!=3` **译了过去**：
///          `!` 在应用自己的语法里是**阶乘**（[_relationAllowedChars] 里本来就有它），左边
///          `x!` 于是是一个合法的阶乘调用，整条被读成「x 的阶乘等于 3」。而用户打 `!=`
///          想说的显然是**不等于**。**两边对同一个拼写有两种定义，正是本仓一律拒绝的那一类**
///          （`mod` 同源，见 `engine_expression.dart` 文件头）。所以这里拒绝，让它落回旧解析器
///          既有的那条路——**不猜用户要的是哪一个**。
/// English: **cuts the two sides of a top-level equals sign** out of one sentence; returns `null` when
///          the sentence is not a relation (the caller takes the existing route).
///
///          Three rules, each answering a family that must be refused:
///
///          1. **exactly one equals sign at depth 0.** None means it is not a relation (`x^2` is still
///             an expression); more than one means it is not either (`a=b=c` is something this app has
///             no standing to decide for the engine). **An equals sign inside an expression**
///             (`root(x=3,2)`) sits at depth > 0 and never counts.
///          2. **both sides non-empty.** `=3` and `x=` are not relations, they are half-typed.
/// English: 3. **a comparison symbol touching the equals sign ⇒ this is not a relation.** The equals
///             in `==`, `!=`, `<=`, `>=` **is not an equals sign** — it belongs to **another operator**,
///             one this app's own grammar does not have. (`==` is caught by rule 1 outright; the other
///             three by this rule.)
///
///             ⚠️ **The `!=` clause was measured, not imagined.** The first version lacked it, so
///             `x!=3` **translated**: `!` is this app's **factorial** (`_relationAllowedChars` already
///             holds it), the left side `x!` is therefore a legitimate factorial call, and the whole
///             thing read as "x factorial equals 3" — while a user typing `!=` plainly means **not
///             equal**. **Two definitions for one spelling on the two sides is exactly the class this
///             repository always refuses** (the same family as `mod`; see `engine_expression.dart`'s
///             file head). So it is refused here and falls to the legacy parser's existing route:
///             **it does not guess which one the user wanted.**
(String, String)? _splitRelation(String source) {
  var depth = 0;
  var at = -1;
  for (var index = 0; index < source.length; index++) {
    final ch = source[index];
    if (ch == '(') {
      depth++;
      continue;
    }
    if (ch == ')') {
      depth--;
      continue;
    }
    if (ch != '=' || depth != 0) continue;
    if (at >= 0) return null;
    at = index;
  }
  if (at < 0) return null;
  // 中文：等号两侧紧挨着的比较符号 = 另一个运算符，不在这里处理。
  // English: a comparison symbol touching the equals sign is a different operator; not handled here.
  if (_neighbouringComparisonSymbol(source, at)) return null;
  final left = source.substring(0, at).trim();
  final right = source.substring(at + 1).trim();
  if (left.isEmpty || right.isEmpty) return null;
  return (left, right);
}

/// 中文：**等号紧挨着的那个字符是不是比较符号。** `==`/`!=`/`<=`/`>=` 四种，各自在等号的
///       左边或右边多出一个字符——多出来的那一个才是真正的运算符，而它是**应用自己的语法里
///       没有的那一个**（`!` 有，但它是阶乘，见 [_splitRelation] 那段）。
/// English: **is the character touching the equals sign a comparison symbol.** The four shapes
///          `==`/`!=`/`<=`/`>=` each add one character left or right of the equals — and that extra
///          character is the real operator, one **this app's own grammar does not have** (`!` it does
///          have, but as factorial; see the note on [_splitRelation]).
bool _neighbouringComparisonSymbol(String source, int at) {
  const neighbours = <String>{'=', '<', '>', '!'};
  if (at > 0 && neighbours.contains(source[at - 1])) return true;
  return at + 1 < source.length && neighbours.contains(source[at + 1]);
}
