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

// ─────────────────────────── 分解因式 ───────────────────────────

/// 中文：**分解的结果**：`factors` 每一项是一个已经写成字符串的因子（如 `x - 1`、`2x + 3`），
///       `constant` 是提在最前面的那个整数系数，`remainder` 是**还没分完的那一块**
///       （有理根分不动时剩下的多项式，回 `null` 表示分完了）。
///
///       ⚠️ **`remainder` 非空不是失败，是"分到这里为止"。** `x^4 + 1` 在有理数上就是不可约的，
///       而 `x^2 - 2` 的有理根也不存在（它的根是无理数）——**两者都如实留下**，
///       绝不硬拆成带根号的因子：那一步要引进无理数，**是另一个问题**。
/// English: **the factorisation**: each entry of `factors` is a factor already written as a string (`x - 1`,
///          `2x + 3`), `constant` is the integer coefficient pulled out front, and `remainder` is **the part
///          not yet factored** (`null` when it is done).
///
///          ⚠️ **A non-null `remainder` is not a failure, it is "it stops here".** `x^4 + 1` is irreducible
///          over the rationals and `x^2 - 2` has no rational root (its roots are irrational) — **both are
///          left as they are**, never forced into radical factors: that step needs irrationals and **is a
///          different question**.
typedef PolynomialFactorisation = ({
  List<String> factors,
  BigInt constant,
  String? remainder,
});

/// 中文：**在有理数上分解一个整系数多项式。**
///
///       用的是**有理根定理 + 精确的长除法**：
///
///       1. **候选根**是 `±p/q`，其中 `p` 整除常数项、`q` 整除首项系数，且 `gcd(p, q) = 1`；
///       2. **判定**用**交叉相乘**（`q^n·f(p/q) = 0` 换成一个整数等式），**全程不出现浮点**——
///          浮点判定会在重根附近把"不是根"判成根，那是一个**看着像答案的错分解**；
///       3. 命中就**整除去掉** `(qx - p)`：因为 `gcd(p, q) = 1` 且 `(qx - p)` 整除 `f`，
///          商**仍然是整系数**的（这是本仓选择"除以 `qx - p`"而不是"除以 `x - p/q`"的理由——
///          后者会引进分数，而**半套的分数算术会给出错的分解**）。
///
///       ⚠️ **低次那一头也不放过**：常数项为 0 时 `x` 本身就是一个因子（先提出来再继续），
///       否则"候选根里没有 0"会让 `x^3 - x` 分不动。
/// English: **factor an integer-coefficient polynomial over the rationals.**
///
///          **The rational-root theorem plus exact division** (see the numbered steps in the Chinese
///          section): candidates are `±p/q` with `p` dividing the constant term and `q` the leading
///          coefficient in lowest terms; the test uses **cross-multiplication** so **no float ever
///          appears** — a float test turns a non-root into a root near a repeated one, which is **a
///          plausible-looking wrong factorisation**; and a hit divides out `(qx - p)` **exactly**,
///          because `gcd(p, q) = 1` and `(qx - p) | f` make the quotient **integer-coefficiented** again
///          (which is why this divides by `qx - p` rather than `x - p/q`: the latter brings in fractions,
///          and **half-done fraction arithmetic gives a wrong factorisation**).
///
///          ⚠️ **The low end is handled too**: when the constant term is 0, `x` itself is a factor (pull it
///          out and continue) — otherwise "no 0 among the candidates" would leave `x^3 - x` unfactored.
PolynomialFactorisation? factorPolynomial(Polynomial coefficients, String variable) {
  var work = _trim(coefficients);
  if (work.length < 2) return null; // 常数或空——没有因式可分解。

  final factors = <String>[];
  var constant = BigInt.one;

  // 中文：**先提 `x`**——常数项为 0 时它就是因子，而有理根的候选里没有 0。
  // English: **pull out `x` first** — when the constant term is 0 it is a factor, and 0 is not among the
  //          rational-root candidates.
  var lowest = 0;
  while (lowest < work.length && work[lowest] == BigInt.zero) {
    lowest++;
  }
  if (lowest > 0) {
    for (var index = 0; index < lowest; index++) {
      factors.add(variable);
    }
    work = work.sublist(lowest);
  }

  while (work.length > 1) {
    final root = _findRationalRoot(work);
    if (root == null) break;
    final (p, q) = root;
    work = _divideByLinear(work, p, q);
    factors.add(_renderLinear(p, q, variable));
  }

  if (work.length > 1) {
    // 中文：**剩下的那一块如实留下**（`x^2 - 2` 那种），不硬拆。
    // English: **the remaining piece is left as it is** (the `x^2 - 2` kind) and never forced apart.
    return (
      factors: factors,
      constant: constant,
      remainder: _renderPolynomial(work, variable),
    );
  }
  if (work.length == 1) constant = work.first;
  // 中文：**"分出一个因子，而那个因子就是它自己"不算分解。** `x + 1` 会走到这里：
  //       它有一个有理根（`-1`），除完之后剩下常数，于是 `factors` 里只有一条 `(x + 1)`——
  //       **那等于没分**。报 `null` 让调用方说"没有因式可分解"，比印一句
  //       `1 × (x + 1)` 诚实，也比印它有用。
  // English: **"one factor, and it is the polynomial itself" is not a factorisation.** `x + 1` lands here:
  //          it has a rational root (`-1`), dividing leaves a constant, and `factors` ends up holding one
  //          entry, `(x + 1)` — **which is no factoring at all**. Returning `null` lets the caller say
  //          "nothing to factor", which is both more honest and more useful than printing `1 × (x + 1)`.
  if (factors.isEmpty || (factors.length == 1 && constant == BigInt.one)) {
    return null;
  }
  return (factors: factors, constant: constant, remainder: null);
}

/// 中文：去掉**高次那一头**的零（真次数）。低次那一头的零有意义（常数项），**不裁**。
/// English: trims zeros off the **high** end (the true degree). Zeros at the low end are meaningful (the
///          constant term) and are **not** trimmed.
Polynomial _trim(Polynomial coefficients) {
  var end = coefficients.length;
  while (end > 0 && coefficients[end - 1] == BigInt.zero) {
    end--;
  }
  return coefficients.sublist(0, end);
}

/// 中文：找一个有理根 `p/q`（最简、`q > 0`）。
///
///       候选是 `±p/q`，`p` 取常数项的因子、`q` 取首项的因子——**这是有理根定理**。
///       判定用交叉相乘：`f(p/q) = 0` 等价于 `Σ aᵢ·pⁱ·q^(n-i) = 0`，**一个整数等式**。
/// English: finds one rational root `p/q` in lowest terms with `q > 0` (see the Chinese section: the
///          candidates come from the rational-root theorem and the test is the integer identity
///          `Σ aᵢ·pⁱ·q^(n-i) = 0`).
/// English: `null` when there is none.
(BigInt, BigInt)? _findRationalRoot(Polynomial coefficients) {
  final degree = coefficients.length - 1;
  final constantTerm = coefficients.first;
  final leading = coefficients.last;

  final pValues = constantTerm == BigInt.zero
      ? <BigInt>[BigInt.zero]
      : _divisors(constantTerm.abs());
  final qValues = _divisors(leading.abs());

  for (final q in qValues) {
    for (final p in pValues) {
      if (p == BigInt.zero) continue; // 0 已在前面被提走。
      if (p.gcd(q) != BigInt.one) continue;
      for (final sign in <BigInt>[BigInt.one, -BigInt.one]) {
        if (_isRoot(coefficients, sign * p, q, degree)) {
          return (sign * p, q);
        }
      }
    }
  }
  return null;
}

/// 中文：`f(p/q)` 是不是 0——**整数等式**，无浮点。
/// English: whether `f(p/q)` is 0 — an **integer identity**, no float.
bool _isRoot(Polynomial coefficients, BigInt p, BigInt q, int degree) {
  var total = BigInt.zero;
  for (var index = 0; index < coefficients.length; index++) {
    final power = degree - index;
    total += coefficients[index] * p.pow(index) * q.pow(power);
  }
  return total == BigInt.zero;
}

/// 中文：整除去掉 `(qx - p)`。**结果保证是整系数**（`gcd(p, q) = 1` 且整除）。
/// English: divides out `(qx - p)` exactly; the result **is guaranteed integer-coefficiented**.
Polynomial _divideByLinear(Polynomial coefficients, BigInt p, BigInt q) {
  final quotient = List<BigInt>.filled(coefficients.length - 1, BigInt.zero);
  var carry = BigInt.zero;
  for (var index = coefficients.length - 1; index >= 0; index--) {
    final current = coefficients[index] + carry;
    if (index == 0) break;
    final value = current ~/ q;
    quotient[index - 1] = value;
    carry = value * p;
  }
  return _trim(quotient);
}

/// 中文：把一个线性因子写成字符串：`(x - 1)`、`(x + 2)`、`(2x + 3)`、`(3x - 1)`。
/// English: writes one linear factor: `(x - 1)`, `(x + 2)`, `(2x + 3)`, `(3x - 1)`.
String _renderLinear(BigInt p, BigInt q, String variable) {
  final head = q == BigInt.one ? variable : '$q$variable';
  if (p == BigInt.zero) return '($head)';
  final tail = p.isNegative ? '+ ${-p}' : '- $p';
  return '($head $tail)';
}

/// 中文：把多项式写回应用的写法（升幂表 → `x^2 - 2`）。只用于 `remainder` 那一栏。
/// English: writes a polynomial back in the app's spelling (ascending list → `x^2 - 2`); used only for the
///          `remainder` column.
String _renderPolynomial(Polynomial coefficients, String variable) {
  final parts = <String>[];
  for (var index = coefficients.length - 1; index >= 0; index--) {
    final c = coefficients[index];
    if (c == BigInt.zero) continue;
    final magnitude = c.abs() == BigInt.one && index > 0 ? '' : c.abs().toString();
    final power = switch (index) {
      0 => '',
      1 => variable,
      _ => '$variable^$index',
    };
    final term = '$magnitude$power';
    if (parts.isEmpty) {
      parts.add(c.isNegative ? '-$term' : term);
    } else {
      parts.add('${c.isNegative ? '-' : '+'} $term');
    }
  }
  return parts.isEmpty ? '0' : parts.join(' ');
}

/// 中文：**正因子表**（含 1 与它自己）。候选根只可能在这些数里，
///       所以这是有理根定理那一半的落地。负数由调用方加上符号。
/// English: **the positive divisors** (1 and itself included). Candidate roots can only be among these,
///          which is the rational-root theorem's other half; the caller supplies the sign.
List<BigInt> _divisors(BigInt value) {
  if (value == BigInt.zero) return <BigInt>[];
  final result = <BigInt>[];
  var divisor = BigInt.one;
  while (divisor * divisor <= value) {
    if (value % divisor == BigInt.zero) {
      result.add(divisor);
      final other = value ~/ divisor;
      if (other != divisor) result.add(other);
    }
    divisor += BigInt.one;
  }
  return result;
}
