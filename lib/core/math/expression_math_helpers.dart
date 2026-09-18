part of 'expression_parser.dart';

/// 中文：**解析器的纯数值助手，从 `ExpressionParser` 的类体里搬出来的那一块。**
///
///       为什么搬：`expression_parser.dart` 在加入百分比模式那一轮到了 **805 行**，越过 800 行的
///       硬线（那道线是本仓库的硬性边界，不是风格偏好）。Dart 的类体不能跨 part 拆开，所以能按缝
///       拆的只有「**不使用实例状态的成员**」——下面这些函数全都是纯的：它们只读自己的形参、
///       库级常量（`_twoArgumentFunctions`）与 `dart:math`，一个 `text` / `_index` / `degreeMode`
///       都不碰。于是它们可以逐字变成顶层私有函数，**调用点一个字都不用改**（同一个库里
///       `_factorial(x)` 这个名字两处一样解析）。
///
///       **判据是「用不用实例状态」，不是「看起来像不像工具函数」**：同一份名单里若掺进一个
///       真的读 `this` 的成员，编译器不会报错（同一个库的私有成员到处可见），而它会在运行时拿到
///       另一份状态。所以搬的时候逐个看过：这一块 118 行里没有一处 `this`。
/// English: **the parser's pure numeric helpers, moved out of `ExpressionParser`'s class body.**
///
///          Why: with the percentage-mode round, `expression_parser.dart` reached **805 lines**, past
///          the hard 800-line limit (a hard boundary in this repository, not a style preference). A
///          Dart class body cannot be split across parts, so the only members that can be carved off
///          are the ones that **use no instance state** — and every function below is pure: it reads
///          its own parameters, a library-level constant (`_twoArgumentFunctions`) and `dart:math`,
///          touching no `text` / `_index` / `degreeMode`. They therefore become top-level private
///          functions verbatim and **not one call site changes** (within one library the name
///          `_factorial(x)` resolves the same either way).
///
///          **The test is "does it use instance state", not "does it look like a utility"**: slipping
///          one member that really reads `this` into this list raises no compile error (private members
///          are visible library-wide) and would silently see a different state at run time. So each one
///          was read on the way out: none of the 118 lines touches `this`.

double _factorial(double value) {
  if (value < 0 || value > 170 || value % 1 != 0) {
    throw const FormatException('Factorial needs an integer from 0 to 170');
  }
  var result = 1.0;
  for (var i = 2; i <= value.toInt(); i++) {
    result *= i;
  }
  return result;
}

double _combination(double n, double r) {
  final ni = _readNonNegativeInteger(n, 'nCr n');
  final ri = _readNonNegativeInteger(r, 'nCr r');
  if (ri > ni) return 0;
  // 中文：组合数使用较小的 k 迭代，降低中间值增长速度并减少溢出风险。
  // English: nCr iterates with the smaller k to reduce intermediate growth and overflow risk.
  final k = math.min(ri, ni - ri);
  var result = 1.0;
  for (var i = 1; i <= k; i++) {
    result = result * (ni - k + i) / i;
  }
  return result;
}

double _permutation(double n, double r) {
  final ni = _readNonNegativeInteger(n, 'nPr n');
  final ri = _readNonNegativeInteger(r, 'nPr r');
  if (ri > ni) return 0;
  var result = 1.0;
  for (var i = 0; i < ri; i++) {
    result *= ni - i;
  }
  return result;
}

void _validateFunctionArity(String name, List<double> args) {
  if (const {'min', 'max', 'gcd', 'lcm'}.contains(name)) {
    if (args.isEmpty) throw FormatException('$name needs arguments');
    return;
  }
  // 中文：`log` 也收两个实参——第二个是**底**，与引擎的 `MathFunction("log", 1, 2)` 同一个含义。
  //       它是加法：一个实参的 `log(x)` 与以前逐字节相同，而两个实参的 `log(8,2)` 以前是
  //       「log needs 1 argument」，现在算 3。`logₓy` 那颗键因此在引擎缺席时也有答案。
  // English: `log` takes two arguments too — the second is the **base**, the same meaning as the
  //          engine's `MathFunction("log", 1, 2)`. This is purely additive: the one-argument
  //          `log(x)` is byte-for-byte what it was, while `log(8,2)` used to be "log needs 1
  //          argument" and now evaluates to 3. That gives the `logₓy` key an answer even when the
  //          engine is absent.
  if (_twoArgumentFunctions.contains(name)) {
    if (args.isEmpty || args.length > 2) {
      throw FormatException('$name needs 1 or 2 arguments');
    }
    return;
  }
  if (args.length != 1) {
    throw FormatException('$name needs 1 argument');
  }
}

double _min(List<double> values) {
  if (values.isEmpty) throw const FormatException('min needs arguments');
  return values.reduce(math.min);
}

double _max(List<double> values) {
  if (values.isEmpty) throw const FormatException('max needs arguments');
  return values.reduce(math.max);
}

double _gcdMany(List<double> values) {
  if (values.isEmpty) throw const FormatException('gcd needs arguments');
  return values.skip(1).fold(values.first, _gcd);
}

double _lcmMany(List<double> values) {
  if (values.isEmpty) throw const FormatException('lcm needs arguments');
  return values.skip(1).fold(values.first, _lcm);
}

double _gcd(double a, double b) {
  var x = _readInteger(a, 'gcd a').abs();
  var y = _readInteger(b, 'gcd b').abs();
  while (y != 0) {
    final next = x % y;
    x = y;
    y = next;
  }
  return x.toDouble();
}

double _lcm(double a, double b) {
  final x = _readInteger(a, 'lcm a').abs();
  final y = _readInteger(b, 'lcm b').abs();
  if (x == 0 || y == 0) return 0;
  return (x ~/ _gcd(x.toDouble(), y.toDouble()).toInt() * y).toDouble();
}

double _root(double value, double degree) {
  if (degree == 0) throw const FormatException('Root degree cannot be 0');
  if (value < 0 && degree % 2 != 1) {
    throw const FormatException('Even root of negative number');
  }
  final magnitude = math.pow(value.abs(), 1 / degree).toDouble();
  return value < 0 ? -magnitude : magnitude;
}

int _readNonNegativeInteger(double value, String label) {
  final parsed = _readInteger(value, label);
  if (parsed < 0) throw FormatException('$label must be non-negative');
  return parsed;
}

int _readInteger(double value, String label) {
  if (value % 1 != 0) throw FormatException('$label must be an integer');
  if (value.abs() > 1000000000) throw FormatException('$label is too large');
  return value.toInt();
}
