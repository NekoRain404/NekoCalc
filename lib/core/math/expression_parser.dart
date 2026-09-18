import 'dart:math' as math;

part 'expression_input_normalization.dart';

/// 中文：轻量级递归下降表达式解析器，覆盖计算器、图形和工具页共用的数学输入。
/// English: Lightweight recursive-descent parser shared by calculator, graphing, and tool math inputs.
class ExpressionParser {
  ExpressionParser(this.source, {required this.degreeMode})
      : text = normalizeExpressionInput(source);

  final String source;
  final String text;
  final bool degreeMode;
  int _index = 0;

  double parse() {
    // 中文：入口只接受完整表达式，防止 "1+2abc" 这类半成功解析被误认为有效。
    // English: The entry point requires full consumption so partially parsed input is not treated as valid.
    final value = _parseExpression();
    _skipSpaces();
    if (_index != text.length) {
      throw FormatException('Unexpected token at $_index');
    }
    return value;
  }

  double _parseExpression() {
    // 中文：表达式层只处理加减，优先级更高的乘除、幂和一元运算交给下层。
    // English: This level handles addition/subtraction; higher-precedence operations are delegated below.
    var value = _parseTerm();
    while (true) {
      if (_match('+')) {
        value += _parseTerm();
      } else if (_match('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    // 中文：乘除层保持左结合，符合日常计算器输入习惯。
    // English: Multiplication and division are left-associative, matching normal calculator behavior.
    var value = _parseUnary();
    while (true) {
      if (_match('*')) {
        value *= _parseUnary();
      } else if (_match('/')) {
        value /= _parseUnary();
      } else {
        return value;
      }
    }
  }

  double _parsePower() {
    // 中文：幂运算右结合，且优先级高于前缀负号，保证 -2^2 解析为 -(2^2)。
    // English: Power is right-associative and binds tighter than prefix minus, so -2^2 parses as -(2^2).
    var value = _parsePostfix();
    if (_match('^')) value = math.pow(value, _parseUnary()).toDouble();
    return value;
  }

  double _parseUnary() {
    if (_match('+')) return _parseUnary();
    if (_match('-')) return -_parseUnary();
    return _parsePower();
  }

  double _parsePostfix() {
    var value = _parsePrimary();
    while (true) {
      if (_match('!')) {
        value = _factorial(value);
      } else {
        return value;
      }
    }
  }

  double _parsePrimary() {
    _skipSpaces();
    if (_match('(')) {
      final value = _parseExpression();
      if (!_match(')')) throw const FormatException('Missing )');
      return value;
    }
    if (_peekLetter()) {
      final name = _readName();
      if (name == 'pi') return math.pi;
      if (name == 'e') return math.e;
      if (name == 'tau') return math.pi * 2;
      if (name == 'phi') return (1 + math.sqrt(5)) / 2;
      if (name == 'inf' || name == 'infinity') return double.infinity;
      // 中文：函数统一要求括号，便于光标编辑、自动补括号和图形表达式复用。
      // English: Functions consistently require parentheses, which keeps cursor editing and graph reuse predictable.
      if (!_match('(')) throw FormatException('Function $name needs (');
      final args = <double>[];
      if (!_check(')')) {
        do {
          args.add(_parseExpression());
        } while (_match(','));
      }
      if (!_match(')')) throw const FormatException('Missing )');
      _validateFunctionArity(name, args);
      final arg = args.isEmpty ? 0.0 : args.first;
      final secondArg = args.length >= 2 ? args[1] : null;
      final angle = degreeMode ? arg * math.pi / 180 : arg;
      // 中文：**角度制下的三角奇点：那里没有值，不是「值很大」。** `tan`/`sec` 在 90° 的奇数倍没有
      //       定义（`cos` 在那里恰好是 0），`cot`/`csc` 在 180° 的整数倍没有定义（`sin` 在那里是 0）。
      //       判据因此下在**实参**上——这个角度值是不是 90°/180° 的精确整数倍——而不是在结果的大小
      //       上：`2^2000` 是合法的大数，按大小一刀切会连它一起拒掉。
      //
      //       **为什么非有这条不可：** double 里没有真 π，`math.sin(math.pi)` 是 1.2246e-16 而不是
      //       0，于是 `1/math.sin(angle)` 在 180° 上得到一个**有限的** 8.1656e15——下游那道非有限闸
      //       什么也拦不住。（`cot(0)`/`1/tan(0)` 一直是对的，只是因为 `math.tan(0)` 恰好是精确的
      //       0，不是判据本身对。）实测（DEG、修复前）：`tan(90)` = 1.6331239353195370e16、
      //       `tan(270)` = 5.443746451065123e15、`sec(90)` = 1.6331239353195370e16、`cot(180)` =
      //       -8.165619676597685e15、`csc(360)` = -4.0828098382988425e15；参考实现（`qalc -set
      //       "angle deg"`）对这五条全部拒绝——把算式原样印回来（未求值），或给 `1 / 0`。
      //
      //       返回 `NaN` 而不是抛异常：NaN 就是「不是数」，而三个调用方（计算器提交路径、工具数值
      //       输入、自定义公式）**都已经**拿 `!value.isFinite` 把非有限结果拒成同一句「结果不是有限
      //       数值」/「公式结果不是有限数值」——奇点于是和 `log(0)` 走**完全同一条**拒绝路径，一句
      //       新文案都不加。NaN 还让奇点**传染**：`tan(90)-tan(90)` 也是 NaN，而不是一个 0——0 会是
      //       对一个没有值的问题的「答案」。
      //
      //       只在角度制下判。RAD 下 `tan(90)` 是一个**普通**的数（−1.9952…），90 这个数在那里没有
      //       任何特殊含义；RAD 真正的奇点（π/2）在这个解析器里根本不是可判定的实参——`math.pi/2`
      //       只是**离** π/2 最近的那个 double，`tan` 在它上面有值（1.6331239353195370e16）。两种
      //       模式因此不可能共用一条判据。
      // English: **Trigonometric poles in degree mode: the value does not exist there — this is not "a
      //          big value".** `tan`/`sec` are undefined at odd multiples of 90° (`cos` is exactly 0
      //          there) and `cot`/`csc` at integer multiples of 180° (`sin` is 0 there). So the test is
      //          on the **argument** — is this degree value an exact integer multiple of 90°/180° — and
      //          not on the size of the result: `2^2000` is a legitimate huge result, and a magnitude
      //          cutoff would throw it away too.
      //
      //          **Why this has to exist:** a double has no exact π, so `math.sin(math.pi)` is
      //          1.2246e-16 rather than 0, which makes `1/math.sin(angle)` at 180° a **finite**
      //          8.1656e15 — nothing for the non-finite gate downstream to catch. (`cot(0)`/`1/tan(0)`
      //          were only ever right because `math.tan(0)` happens to be an exact 0, not because the
      //          judgement itself was right.) Measured (DEG, before the fix): `tan(90)` =
      //          1.6331239353195370e16, `tan(270)` = 5.443746451065123e15, `sec(90)` =
      //          1.6331239353195370e16, `cot(180)` = -8.165619676597685e15, `csc(360)` =
      //          -4.0828098382988425e15; the reference (`qalc -set "angle deg"`) refuses all five —
      //          it prints the expression back unevaluated, or answers `1 / 0`.
      //
      //          `NaN` rather than an exception: NaN *is* "not a number", and all three callers (the
      //          calculator submit path, tool numeric input, custom formulas) **already** refuse a
      //          non-finite result with the same 「结果不是有限数值」/「公式结果不是有限数值」 — so a pole
      //          takes **exactly** the refusal path `log(0)` takes, adding no new wording. NaN also
      //          makes the pole **contagious**: `tan(90)-tan(90)` is NaN rather than 0, and 0 would be
      //          an "answer" to a question that has none.
      //
      //          Degree mode only. Under RAD `tan(90)` is an ordinary number (−1.9952…) and the number
      //          90 carries no special meaning there; RAD's real poles (π/2) are not decidable
      //          arguments in this parser at all — `math.pi/2` is merely the double **nearest** π/2,
      //          and `tan` has a value there (1.6331239353195370e16). The two modes therefore cannot
      //          share one judgement.
      if (degreeMode && _hitsTrigPole(name, arg)) return double.nan;
      // 中文：三角函数在这里集中做角度制转换，其他函数始终按纯数值处理。
      // English: Trigonometric functions centralize degree/radian conversion here; other functions stay numeric.
      return switch (name) {
        'sin' => math.sin(angle),
        'cos' => math.cos(angle),
        'tan' => math.tan(angle),
        'cot' => 1 / math.tan(angle),
        'sec' => 1 / math.cos(angle),
        'csc' => 1 / math.sin(angle),
        'asin' => degreeMode ? math.asin(arg) * 180 / math.pi : math.asin(arg),
        'acos' => degreeMode ? math.acos(arg) * 180 / math.pi : math.acos(arg),
        'atan' => degreeMode ? math.atan(arg) * 180 / math.pi : math.atan(arg),
        'sinh' => (math.exp(arg) - math.exp(-arg)) / 2,
        'cosh' => (math.exp(arg) + math.exp(-arg)) / 2,
        'tanh' =>
          (math.exp(arg) - math.exp(-arg)) / (math.exp(arg) + math.exp(-arg)),
        'sqrt' => math.sqrt(arg),
        'cbrt' => arg < 0
            ? -math.pow(-arg, 1 / 3).toDouble()
            : math.pow(arg, 1 / 3).toDouble(),
        'ln' => math.log(arg),
        'log' => secondArg == null
            ? math.log(arg) / math.ln10
            : math.log(arg) / math.log(secondArg),
        'log2' => math.log(arg) / math.ln2,
        'exp' => math.exp(arg),
        'abs' => arg.abs(),
        'floor' => arg.floorToDouble(),
        'ceil' => arg.ceilToDouble(),
        'round' => arg.roundToDouble(),
        'fact' => _factorial(arg),
        'deg' => arg * 180 / math.pi,
        'rad' => arg * math.pi / 180,
        'min' => _min(args),
        'max' => _max(args),
        'mod' => secondArg == null ? arg : arg % secondArg,
        'ncr' => secondArg == null ? arg : _combination(arg, secondArg),
        'npr' => secondArg == null ? arg : _permutation(arg, secondArg),
        'gcd' => _gcdMany(args),
        'lcm' => _lcmMany(args),
        'root' => secondArg == null ? arg : _root(arg, secondArg),
        'atan2' => secondArg == null
            ? (degreeMode ? math.atan(arg) * 180 / math.pi : math.atan(arg))
            : (degreeMode
                ? math.atan2(arg, secondArg) * 180 / math.pi
                : math.atan2(arg, secondArg)),
        _ => throw FormatException('Unknown function $name'),
      };
    }
    return _readNumber();
  }

  /// 中文：**这个角度值是不是三角函数的极点**——即那一族里「值不存在」的那些实参。四张面孔分两组：
  ///       `tan`/`sec` 在 90° 的**奇数**倍（`cos` 恰好为 0），`cot`/`csc` 在 180° 的**整数**倍
  ///       （`sin` 恰好为 0）。两个**反例**同样钉在这张表里：`tan(180)`（90° 的偶数倍）与
  ///       `cot(90)`（180° 的半整数倍）都**有**值，必须照算——奇数那一半不是修饰，是判据本身。
  /// English: **is this degree value a pole of the trigonometric function** — the arguments in that
  ///          family for which no value exists. Four faces in two groups: `tan`/`sec` at **odd**
  ///          multiples of 90° (`cos` is exactly 0), `cot`/`csc` at **integer** multiples of 180°
  ///          (`sin` is exactly 0). Two **counter-examples** are pinned by the same table: `tan(180)`
  ///          (an even multiple of 90°) and `cot(90)` (a half-integer multiple of 180°) both **have**
  ///          values and must keep computing — "odd" is not a decoration, it is half the judgement.
  static bool _hitsTrigPole(String name, double degrees) => switch (name) {
        'tan' || 'sec' => _isExactMultipleOf(degrees, 90, oddOnly: true),
        'cot' || 'csc' => _isExactMultipleOf(degrees, 180, oddOnly: false),
        _ => false,
      };

  /// 中文：`degrees` 是不是 `unit` 的**精确**整数倍（`oddOnly` 时还要求倍数本身是奇数）。
  ///
  ///       全程走整数，不借任何 double 中间量：先要求这个 double 自己是个整数，再用 [BigInt] 做整除
  ///       判定。**为什么不能写成 `degrees / unit * unit == degrees`**——实测 `(1e300/90)*90 ==
  ///       1e300` 是 `true`，那只是大数上的舍入自己转回了原值，1e300 根本不是 90 的整数倍；照那样写
  ///       会把一个合法的大角度判成奇点。整数域里没有这种事。
  ///
  ///       非有限的实参先挡掉：`tan(1/0)` 的实参是 `Infinity`，而 `BigInt.from` 对无穷会抛
  ///       `ArgumentError`——那会把一句「结果不是有限数值」变成一句「表达式错误」，是**退步**。
  /// English: is `degrees` an **exact** integer multiple of `unit` (with the quotient itself odd when
  ///          `oddOnly`)? Everything stays in the integer domain: first the double must be an integer
  ///          itself, then [BigInt] decides divisibility. **Why it cannot be written
  ///          `degrees / unit * unit == degrees`** — measured, `(1e300/90)*90 == 1e300` is `true`, but
  ///          that is rounding on a large number landing back on itself; 1e300 is not a multiple of 90
  ///          at all, and that spelling would call a legitimate large angle a pole. In the integer
  ///          domain that cannot happen.
  ///
  ///          Non-finite arguments are refused up front: `tan(1/0)` passes `Infinity`, and
  ///          `BigInt.from` throws `ArgumentError` for infinity — which would turn "结果不是有限数值"
  ///          into "表达式错误", a **regression**.
  static bool _isExactMultipleOf(double degrees, int unit,
      {required bool oddOnly}) {
    if (!degrees.isFinite) return false;
    final integral = degrees.roundToDouble();
    if (integral != degrees) return false;
    final value = BigInt.from(integral);
    final divisor = BigInt.from(unit);
    final quotient = value ~/ divisor;
    if (quotient * divisor != value) return false;
    return !oddOnly || quotient.isOdd;
  }

  double _readNumber() {
    _skipSpaces();
    final radixValue = _readRadixNumber();
    if (radixValue != null) return radixValue;

    final start = _index;
    final number = StringBuffer();
    var hasDigit = false;
    var lastWasDigit = false;
    var dotSeen = false;
    while (_index < text.length) {
      final char = text[_index];
      if (_isDecimalDigit(char)) {
        number.write(char);
        hasDigit = true;
        lastWasDigit = true;
        _index++;
        continue;
      }
      if (char == '_') {
        if (!lastWasDigit || !_hasDecimalDigitAt(_index + 1)) break;
        lastWasDigit = false;
        _index++;
        continue;
      }
      if (char == '.' && !dotSeen) {
        number.write(char);
        dotSeen = true;
        lastWasDigit = false;
        _index++;
        continue;
      }
      break;
    }
    if (_index < text.length && (text[_index] == 'e' || text[_index] == 'E')) {
      // 中文：科学计数法只有在指数部分存在数字时才确认消费，避免把常数 e 误吞掉。
      // English: Scientific notation is consumed only when exponent digits exist, avoiding accidental capture of constant e.
      final exponentStart = _index;
      final exponent = StringBuffer();
      _index++;
      exponent.write('e');
      if (_index < text.length &&
          (text[_index] == '+' || text[_index] == '-')) {
        exponent.write(text[_index]);
        _index++;
      }
      var exponentDigits = 0;
      var lastExponentWasDigit = false;
      while (_index < text.length) {
        final char = text[_index];
        if (_isDecimalDigit(char)) {
          exponent.write(char);
          exponentDigits++;
          lastExponentWasDigit = true;
          _index++;
          continue;
        }
        if (char == '_') {
          if (!lastExponentWasDigit || !_hasDecimalDigitAt(_index + 1)) break;
          lastExponentWasDigit = false;
          _index++;
          continue;
        }
        break;
      }
      if (exponentDigits > 0) {
        number.write(exponent);
      } else {
        _index = exponentStart;
      }
    }
    if (start == _index || !hasDigit) {
      throw FormatException('Expected number at $_index');
    }
    return double.parse(number.toString());
  }

  double? _readRadixNumber() {
    if (_index + 2 > text.length || text[_index] != '0') return null;
    final prefix = text[_index + 1];
    final radix = switch (prefix) {
      'x' => 16,
      'b' => 2,
      'o' => 8,
      _ => null,
    };
    if (radix == null) return null;

    final start = _index;
    _index += 2;
    final digits = StringBuffer();
    var lastWasDigit = false;
    while (_index < text.length) {
      final char = text[_index];
      if (char == '_') {
        if (!lastWasDigit || _index + 1 >= text.length) break;
        final nextDigit = _digitValue(text[_index + 1]);
        if (nextDigit == null || nextDigit >= radix) break;
        lastWasDigit = false;
        _index++;
        continue;
      }
      final digit = _digitValue(char);
      if (digit == null || digit >= radix) break;
      digits.write(char);
      lastWasDigit = true;
      _index++;
    }
    if (digits.isEmpty) {
      _index = start;
      throw FormatException('Expected base-$radix digits at $_index');
    }
    return int.parse(digits.toString(), radix: radix).toDouble();
  }

  int? _digitValue(String char) {
    final code = char.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) return code - 0x30;
    if (code >= 0x61 && code <= 0x66) return code - 0x61 + 10;
    return null;
  }

  bool _isDecimalDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  bool _hasDecimalDigitAt(int index) {
    return index < text.length && _isDecimalDigit(text[index]);
  }

  String _readName() {
    final start = _index;
    while (
        _index < text.length && RegExp(r'[A-Za-z0-9]').hasMatch(text[_index])) {
      _index++;
    }
    return text.substring(start, _index);
  }

  bool _peekLetter() =>
      _index < text.length && RegExp(r'[A-Za-z]').hasMatch(text[_index]);

  bool _match(String token) {
    _skipSpaces();
    if (text.startsWith(token, _index)) {
      _index += token.length;
      return true;
    }
    return false;
  }

  bool _check(String token) {
    _skipSpaces();
    return text.startsWith(token, _index);
  }

  void _skipSpaces() {
    while (_index < text.length && text[_index].trim().isEmpty) {
      _index++;
    }
  }

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

  static String normalizeExpressionInput(String source) {
    final strippedSource = _stripPastedCalculationResult(source);
    var text = _normalizeGroupedNumberSeparators(_normalizeUnicodeFractions(
            _normalizeMathSubscripts(_normalizeFullWidthAscii(strippedSource))))
        .trim()
        .toLowerCase();
    text = _normalizeLatexExpression(text)
        .replaceAll('，', ',')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('［', '(')
        .replaceAll('］', ')')
        .replaceAll('【', '(')
        .replaceAll('】', ')')
        .replaceAll('−', '-')
        .replaceAll('－', '-')
        .replaceAll('＋', '+')
        .replaceAll('×', '*')
        .replaceAll('✕', '*')
        .replaceAll('∙', '*')
        .replaceAll('·', '*')
        .replaceAll('÷', '/')
        .replaceAll('／', '/')
        .replaceAll('π', 'pi')
        .replaceAll('τ', 'tau')
        .replaceAll('φ', 'phi')
        .replaceAll('ϕ', 'phi')
        .replaceAll('∞', 'infinity')
        .replaceAll('√', 'sqrt')
        .replaceAll('∛', 'cbrt')
        .replaceAll('％', '%');
    text = _normalizeFunctionAliases(text);
    text = _normalizeSuperscriptRoots(text);
    text = _normalizeSuperscriptExponents(text);
    text = _normalizeScientificNotation(text);
    text = _normalizeExponentialDisplay(text);
    text = _normalizeIndexedRoots(text);
    text = _normalizeAbsoluteValueBars(text);
    text = _normalizeBareUnaryFunctionCalls(text);
    text = _replacePercent(text);
    text = text.replaceAllMapped(
      RegExp(r'(sqrt|cbrt)((?:\d+(?:\.\d+)?)|pi|e)(?![a-z0-9_(])'),
      (match) => '${match.group(1)}(${match.group(2)})',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![a-z0-9_.])(\d+(?:\.\d+)?)°'),
      (match) => 'rad(${match.group(1)})',
    );
    text = text.replaceAllMapped(
      RegExp(
          '((?<![a-z])\\d|\\))(?=(\\(|$_leadingConstantPattern|$_functionPattern))'),
      (match) => '${match.group(1)}*',
    );
    text = text.replaceAllMapped(
      RegExp(
        '((?<![a-z0-9.])(?:$_constantPattern)|\\))(?=(\\d|\\(|$_leadingConstantPattern|$_functionPattern))',
      ),
      (match) => '${match.group(1)}*',
    );
    return text;
  }

  /// 中文：**这个解析器接受的函数名——唯一的一份，而且是一份数据。** 它有三个读者：
  ///       [_functionPattern]（由它拼出来，归一化靠它认出 `名字(...)`）；词汇表的覆盖测试
  ///       （`test/domain/app_engine_vocabulary_semantics_test.dart`：`AppEngineVocabulary.identifiers`
  ///       必须收下这里的每一个名字、每一个别名与每一个常量）；以及**判据**那一处
  ///       （`namesSomethingOutsideTheAppLanguage`：这张表**之外**的调用名与 `VariableNode`
  ///       同判「应用自己的语言没有绑定」）。第三个读者是**收紧**方向的，所以下面那段「不是全部
  ///       来源」的警告对它格外要紧：名字在 `switch` 里却漏在这张表里，判据会把它当成没绑定，
  ///       于是应用答得出的输入被让给引擎的符号答复。那一条由同一份测试里「词表里多出来的名字
  ///       逐个实测抛 `Unknown function …`」钉住。
  ///
  ///       **顺序有意义**：长的在前（`atan2` 先于 `atan`、`log2` 先于 `log`），否则正则先咬短的那个
  ///       ——`log2(8)` 会被读成 `log` 后面跟着 `2(8)`。所以这是一张**列表**而不是集合。
  ///
  ///       **它不是闭集的全部来源，要说清楚**：求值那一个 `switch`（[_parsePrimary] 里）是第二处
  ///       手写的清单。往那个 `switch` 里加一个名字而忘了加到这里，解析器仍然算得出它，
  ///       而覆盖测试看不见它。后果有两条，**方向相反**：词汇表漏掉这个名字，是不会错的那一条
  ///       （[engineNameFor] 拒绝未知标识符，引擎不会被问）——这个名字不再由引擎作答、回落到旧
  ///       解析器；而上面那个判据读者会把它当成「应用自己没有绑定」，那是**错值**方向的另一头，
  ///       由 `app_engine_vocabulary_semantics_test.dart` 里那条逐名实测钉住。
  /// English: **the function names this parser accepts — one copy, and it is data.** It has three
  ///          readers: [_functionPattern] (built from it; normalisation needs it to recognise
  ///          `name(...)`); the vocabulary's coverage test
  ///          (`test/domain/app_engine_vocabulary_semantics_test.dart`:
  ///          `AppEngineVocabulary.identifiers` must hold every name here, every alias and every
  ///          constant); and the **judgement** (`namesSomethingOutsideTheAppLanguage`: a call name
  ///          outside this list is judged "this app's language has no binding", exactly like a
  ///          `VariableNode`). The third reader tightens, so the warning below matters most for it.
  ///
  ///          **Order matters**: longer names first (`atan2` before `atan`, `log2` before `log`), or the
  ///          regex would bite the short one — `log2(8)` would be read as `log` followed by `2(8)`.
  ///          That is why this is a **list** rather than a set.
  ///
  ///          **It is not the whole story, and that has to be said**: the evaluation `switch` (in
  ///          [_parsePrimary]) is a second hand-written list. Adding a name there and forgetting this
  ///          one still evaluates, and the coverage test cannot see it. The consequences run in **two
  ///          opposite directions**: the vocabulary misses the name, which is the harmless one
  ///          ([engineNameFor] refuses unknown identifiers, so the engine is never asked) — it stops
  ///          being answered by the engine and falls back to the legacy parser; and the judgement
  ///          reader above calls it "this app has no binding", the wrong-value end, which is pinned by
  ///          the name-by-name measurement in `app_engine_vocabulary_semantics_test.dart`.
  static const List<String> functionNames = <String>[
    'atan2',
    'asin',
    'acos',
    'atan',
    'sinh',
    'cosh',
    'tanh',
    'sin',
    'cos',
    'tan',
    'cot',
    'sec',
    'csc',
    'sqrt',
    'cbrt',
    'log2',
    'log',
    'ln',
    'abs',
    'exp',
    'floor',
    'ceil',
    'round',
    'deg',
    'rad',
    'min',
    'max',
    'mod',
    'ncr',
    'npr',
    'gcd',
    'lcm',
    'root',
    'fact',
  ];

  /// 中文：上面那张表拼成的正则片段。`static final` 而不是 `const`：它由 [functionNames] 拼出来，
  ///       于是「加一个函数名」只需要改一处。
  /// English: the regex fragment built from the table above. `static final` rather than `const`: it is
  ///          joined from [functionNames], so adding a function name touches one place.
  /// 中文：函数名的三种拼法 → 应用自己的规范名。**唯一的一张表**：归一化整段文本用它
  ///       （[_normalizeFunctionAliases]），读「`(` 前面那个名字」也用它（[_startsFunctionArgument]）。
  ///       两处共用一张表的理由与实参个数表相同：`log` 的三种拼法必须**都**按它接两个实参算，
  ///       否则同一颗键的两种写法会给出两个值（实测：`log(1,024)` = 0，而 `lg(1,024)` = 3.0103）。
  /// English: the three spellings of a function name → this app's canonical name. **One table**:
  ///          normalising a whole text uses it ([_normalizeFunctionAliases]) and so does reading the
  ///          name before a bracket ([_startsFunctionArgument]). They share it for the same reason the
  ///          argument-count table is shared: all three spellings of `log` have to count as taking two
  ///          arguments, or two spellings of one key give two values (measured: `log(1,024)` = 0 while
  ///          `lg(1,024)` = 3.0103).
  /// 中文：**它是公开的**，因为词汇表要用**同一张**表：`AppEngineVocabulary` 的键是这张表**右边**
  ///       那些规范名，而 `lg(1,024)`/`c(1,234)` 这样的写法要能折到键上（`engineNameFor`），
  ///       引擎名字层要判的也是折过之后的规范名（`canRead`）。抄一份到词汇表里去就等于把
  ///       「`lg` 是什么」写两遍——那正是这张表的注释反对的事。
  /// English: **it is public because the vocabulary needs the same table**: `AppEngineVocabulary`'s
  ///          keys are the canonical names on the **right**, and spellings such as `lg(1,024)` /
  ///          `c(1,234)` have to fold onto those keys (`engineNameFor`), as does the engine name layer's
  ///          judgement (`canRead`). Copying it into the vocabulary would write "what `lg` is" twice —
  ///          exactly what this table's own comment argues against.
  static const Map<String, String> functionAliases = <String, String>{
    'arcsin': 'asin',
    'arccos': 'acos',
    'arctan': 'atan',
    'log10': 'log',
    'lg': 'log',
    'c': 'ncr',
    'p': 'npr',
  };

  /// 中文：把一个名字折成规范名（大小写不敏感）；表里没有的名字原样返回（小写化后）。
  ///       公开的理由与 [functionAliases] 相同：词汇表要用**同一个**折叠。
  /// English: fold one name to its canonical spelling (case-insensitively); a name absent from the
  ///          table comes back as itself, lower-cased. Public for the same reason as [functionAliases]:
  ///          the vocabulary needs the **same** fold.
  static String canonicalFunctionName(String name) {
    final lower = name.toLowerCase();
    return functionAliases[lower] ?? lower;
  }

}

class _LatexGroup {
  const _LatexGroup(this.value, this.end);

  final String value;
  final int end;
}
