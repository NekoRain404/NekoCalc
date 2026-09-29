/// 中文：**把一个表达式读成多项式。**
///
///       它是"分解因式"的第一步，也是**唯一一步能在没有多项式算术的情况下做完的**：
///       把 `x^2 - 1` 变成系数 `[-1, 0, 1]`，把 `(x+1)^2` 展开成 `[1, 2, 1]`。
///       有了系数表，有理根定理、综合除法那些都是下一步的事。
///
///       **为什么自己写而不是问引擎。** 引擎有一条 `factor(...)`，但它**分不动时会把输入
///       原样退回来**（实测 `factor(x^2+2x+1)` → `x^2 + 2x + 1`，种类 `SYMBOLIC`，**放行**的一支）。
///       而"这个表达式是不是一个多项式"是一个**纯函数**问题——单测就能证完，
///       也**不必去分辨引擎有没有真做**。
///
///       ⚠️ **系数只用整数，字母只认一个。** 这是刻意的窄定义域：
///       `1.5x`（有理系数）、`x·y`（二元）、`πx`（符号系数）**一律回 `null`**，
///       由调用方如实说"读不出一个多项式"，**绝不硬套**。
///       窄定义域是安全的：**宽一格的实现会给出一个看着像答案的错分解**。
/// English: **read an expression as a polynomial.**
///
///          It is the first step of factorising and **the only step that can be finished without polynomial
///          arithmetic**: `x^2 - 1` becomes the coefficients `[-1, 0, 1]` and `(x+1)^2` expands to
///          `[1, 2, 1]`. With the coefficient list, the rational-root theorem and synthetic division are the
///          next step.
///
///          **Why write it rather than ask the engine.** The engine has a `factor(...)`, but **it hands the
///          input straight back when it cannot factor** (measured: `factor(x^2+2x+1)` → `x^2 + 2x + 1`, kind
///          `SYMBOLIC`, a branch that is **let through**). "Is this expression a polynomial" is a **pure
///          function** question — the unit tests settle it, and **there is no need to tell whether the
///          engine really did anything**.
///
///          ⚠️ **Integer coefficients, one letter only.** The narrow domain is deliberate: `1.5x` (rational
///          coefficients), `x·y` (two variables) and `πx` (a symbolic coefficient) all return `null`, and
///          the caller says it could not read a polynomial — **nothing is forced through**.
///          A narrow domain is the safe side: **an implementation one notch wider hands back a
///          plausible-looking wrong factorisation.**
library;

import 'ast/expression_ast_parser.dart';

/// 中文：**多项式**，系数按**升幂**排：`[-1, 0, 1]` 是 `-1 + 0x + 1x^2`，也就是 `x^2 - 1`。
///       末尾的零**不裁剪**——裁剪是显示的事，不是读的事。
/// English: **a polynomial**, coefficients in **ascending** order: `[-1, 0, 1]` is `-1 + 0x + 1x^2`, i.e.
///          `x^2 - 1`. Trailing zeros are **not** trimmed — trimming is the display's business, not the
///          reading's.
typedef Polynomial = List<BigInt>;

/// 中文：把源码读成一个多项式；读不出就回 `null`。
/// English: read a source string as a polynomial; `null` when it cannot be read.
Polynomial? polynomialIn(String source, String variable) {
  try {
    return polynomialOfNode(
        const ExpressionAstParser().parse(source), variable);
  } on FormatException {
    return null;
  }
}

/// 中文：**同一件事，从一棵已经建好的树出发。**
///
///       ⚠️ **"整句读完了没有"不在这里判，也不需要在这里判。** 我第一版给这个函数留了一个
///       `length` 参数、注释里说它用来判这件事，**而它一次都没用到**——那是一句假话。
///       真相是：解析器对 `2+` 造出的树里**嵌着一个 `ParseErrorNode`**，
///       而 [_read] 遇到它就走 `default` 回 `null`，于是那一类**结构上就进不来**。
///       **参数删掉，注释改成事实。**
/// English: **the same thing starting from a tree.**
///
///          ⚠️ **"Was the whole sentence read" is not judged here, and does not need to be.** My first
///          version gave this function a `length` parameter and a comment saying it decided exactly that
///          — **and never used it once**. That was a false statement. The truth is that the tree the parser
///          builds for `2+` **holds a `ParseErrorNode` inside**, which [_read] sends to `default` and
///          returns `null` for — so that class **cannot get in structurally**. **The parameter is gone and
///          the comment now says what is true.**
Polynomial? polynomialOfNode(ExprNode node, String variable) =>
    _read(node, variable);

/// 中文：递归读。回 `null` 就是"这一支读不出多项式"——**不猜**。
/// English: the recursion. `null` means "this branch is not a polynomial" — **nothing is guessed**.
Polynomial? _read(ExprNode node, String variable) {
  switch (node) {
    case NumberNode(:final literal):
      // 中文：**只收整数**。`1.5` 是有理系数，那要引进分数算术——这一版不做，
      //       而**做了半套的分数算术会给出错的分解**。
      // English: **integers only.** `1.5` is a rational coefficient, which needs fraction arithmetic — not
      //          in this version, and **half-done fraction arithmetic gives a wrong factorisation**.
      final value = BigInt.tryParse(literal.replaceAll('_', ''));
      return value == null ? null : <BigInt>[value];
    case VariableNode(:final name):
      // 中文：**只认要分解的那个字母。** 别的字母是符号系数，读不出。
      // English: **only the letter being factored.** Another letter is a symbolic coefficient and cannot be
      //          read.
      return name == variable ? <BigInt>[BigInt.zero, BigInt.one] : null;
    case GroupNode(:final child):
      return _read(child, variable);
    case UnaryNode(:final op, :final operand):
      if (op != '-') return null;
      final inner = _read(operand, variable);
      return inner?.map((c) => -c).toList();
    case ImplicitProductNode(:final left, :final right):
      // 中文：`2x` 那种写法在树里是隐式乘法——与显式乘法**同一条路**，否则同一个式子有两条读法。
      // English: `2x` is an implicit product — **the same path** as an explicit one, or one expression would
      //          have two readings.
      return _multiply(_read(left, variable), _read(right, variable));
    case BinaryNode(:final op, :final left, :final right):
      final a = _read(left, variable);
      if (a == null) return null;
      if (op == '+' || op == '-') {
        final b = _read(right, variable);
        if (b == null) return null;
        return _add(a, op == '-' ? b.map((c) => -c).toList() : b);
      }
      if (op == '*') return _multiply(a, _read(right, variable));
      if (op == '^') {
        // 中文：**指数必须是非负整数字面量。** `x^-1` 不是多项式（那是分式），
        //       `x^y` 更不是——两者都如实回 `null`。
        // English: **the exponent must be a non-negative integer literal.** `x^-1` is not a polynomial (it is
        //          a rational function) and `x^y` certainly is not — both return `null`.
        final exponent = _constantExponent(right);
        if (exponent == null) return null;
        return _power(a, exponent);
      }
      return null;
    default:
      // 中文：函数调用、常量名（`pi`）、解析错误、后缀——**都不是多项式**，如实回 `null`。
      // English: calls, constant names (`pi`), parse errors and postfixes are **not polynomials** — `null`.
      return null;
  }
}

/// 中文：指数必须是一个**非负整数字面量**（允许 `(2)` 这种括号与一元 `+`）。
/// English: the exponent must be a **non-negative integer literal** (brackets and a unary `+` allowed).
int? _constantExponent(ExprNode node) {
  switch (node) {
    case NumberNode(:final literal):
      final value = BigInt.tryParse(literal.replaceAll('_', ''));
      if (value == null || value.isNegative) return null;
      if (value > BigInt.from(1000)) return null;
      return value.toInt();
    case GroupNode(:final child):
      return _constantExponent(child);
    case UnaryNode(:final op, :final operand):
      return op == '+' ? _constantExponent(operand) : null;
    default:
      return null;
  }
}

Polynomial _add(Polynomial a, Polynomial b) {
  final length = a.length > b.length ? a.length : b.length;
  final out = List<BigInt>.filled(length, BigInt.zero);
  for (var index = 0; index < length; index++) {
    final x = index < a.length ? a[index] : BigInt.zero;
    final y = index < b.length ? b[index] : BigInt.zero;
    out[index] = x + y;
  }
  return out;
}

Polynomial? _multiply(Polynomial? a, Polynomial? b) {
  if (a == null || b == null) return null;
  final out = List<BigInt>.filled(a.length + b.length - 1, BigInt.zero);
  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j < b.length; j++) {
      out[i + j] = out[i + j] + a[i] * b[j];
    }
  }
  return out;
}

Polynomial _power(Polynomial base, int exponent) {
  var result = <BigInt>[BigInt.one];
  for (var index = 0; index < exponent; index++) {
    result = _multiply(result, base)!;
  }
  return result;
}
