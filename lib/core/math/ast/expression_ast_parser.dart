import '../sexagesimal_literal.dart';
import 'expr_node.dart';

// 中文：下游（TeX 生成、渲染组件）只 import 本文件即可拿到节点类型与 toDisplayUnits。
// English: Downstream layers (TeX emitter, renderer) can import this file alone to get the
//          node types and toDisplayUnits.
export 'expr_node.dart';

/// 中文：把表达式字符串解析成语法树。
///       用户打字过程中必然出现 `sin(`、`2+` 这类中间态，因此本解析器**永不抛异常**：
///       无法解析的片段退化成 [ParseErrorNode]，并且任何返回的节点都覆盖"解析器实际消费过的
///       源码区间"——包括消费失败的部分。这样渲染层的点击定位才能落在源码之内。
/// English: Parses an expression string into a syntax tree. Typing inevitably produces
///          intermediate states such as `sin(` or `2+`, so this parser never throws: unparseable
///          fragments degrade to [ParseErrorNode], and every returned node spans the source
///          region the parser actually consumed — including whatever it failed on. That keeps
///          the renderer's tap-to-cursor mapping inside the source.
class ExpressionAstParser {
  const ExpressionAstParser();

  /// 中文：解析整段源码。空串返回零长度的错误节点，而不是抛异常。
  /// English: Parses the whole source. An empty string yields a zero-length error node.
  ExprNode parse(String source) => _AstCursor(source).parseAll();
}

/// 中文：递归下降游标。优先级自低到高：`,` < `+ -` < `* /` 与隐式乘法 < 一元 `-` < `^`
///       < 后缀 `! %` < 原子，与 `expression_parser.dart` 的取值规则一致（但不复用它的求值）。
/// English: Recursive-descent cursor. Precedence from low to high: `,` < `+ -` < `* /` and
///          implicit multiplication < unary `-` < `^` < postfix `! %` < atom, matching the
///          binding rules of `expression_parser.dart` without reusing its evaluation.
class _AstCursor {
  _AstCursor(this.source);

  final String source;
  int _index = 0;

  /// 中文：当前递归深度。真实输入远达不到这个上限，它只用来挡住病态的深层嵌套。
  /// English: Current recursion depth. Real input never comes close; the cap only stops
  ///          pathologically deep nesting.
  int _depth = 0;

  /// 中文：嵌套层数上限，取一个远超人工输入、又远低于栈上限的值。
  /// English: Nesting cap, far above hand-typed input and far below the stack limit.
  static const int _maxDepth = 128;

  /// 中文：与 `expression_parser.dart` 一致的内置常量集合（比较时忽略大小写，输出保留原样）。
  /// English: Built-in constants, matching `expression_parser.dart` (compared case-insensitively,
  ///          emitted as written).
  static const Set<String> _constants = {
    'pi',
    'e',
    'tau',
    'phi',
    'inf',
    'infinity',
  };

  bool get _atEnd => _index >= source.length;

  /// 中文：解析整段源码：空串或仍有未消费的原文都返回覆盖整段的错误节点。
  /// English: Parses the whole source; an empty string or leftover input yields an error node
  ///          covering the whole text.
  ExprNode parseAll() {
    _skipSpaces();
    if (_atEnd) return _failure(0);
    final node = _parseExpression();
    _skipSpaces();
    // 中文：还有没被消费的原文，说明整段并不成立，整体降级为错误节点。
    // English: Leftover input means the source as a whole did not parse, so it all degrades.
    if (!_atEnd) return _failure(0);
    return node;
  }

  /// 中文：**换算层：`A to B`，优先级最低（整串之上），右结合。**
  ///
  ///       `to` 是一个**词运算符**，不是符号：它由字母组成，所以词边界必须由这里判——`token`、
  ///       `to`以后跟着字母的名字都不算（前者是标识符，后者由标识符那条路读走）。判据是
  ///       「当前位置起恰好是 `to`，且它两边都不是名字字符」。
  ///
  ///       为什么它属于**语法**而不是显示层：换算进了语法树，渲染层（表达式行）才能把 `to` 当成
  ///       一个中缀运算符印出来，翻译层才能把它译成引擎的写法，而**应用自己的求值器**
  ///       （`ExpressionParser`）根本不认识它——它在 `t` 上是「不认识的标识符」，于是换算这件事
  ///       只有引擎答得出来（判据是既有的那一处：引擎答不出来就回落旧解析器，而旧解析器对
  ///       `5 km to mi` 给出的是它自己那句「无法识别的内容」）。
  ///
  ///       左结合还是右结合没有实际差别（`a to b to c` 在引擎那边也是逐段换算），这里按右结合写：
  ///       右操作数是**一整段表达式**，于是 `5 km to m/s` 这种右侧带运算符的目标能整段读进去。
  ///
  /// English: **The conversion level: `A to B`, the lowest precedence (above everything), and
  ///          right-associative.**
  ///
  ///          `to` is a **word operator** rather than a symbol: it is made of letters, so the word
  ///          boundary has to be judged here — `token`, or a name that merely starts with `to`, is not
  ///          it (an identifier is read by the identifier path). The test is "exactly `to` starts here
  ///          and neither side is a name character".
  ///
  ///          Why this belongs in the **grammar** rather than in the display layer: once a conversion is
  ///          in the syntax tree the renderer (the expression line) can print `to` as an infix
  ///          operator, the translation can write it the engine's way, and **this app's own evaluator**
  ///          (`ExpressionParser`) does not know it at all — `t` is an unknown identifier to it, so the
  ///          conversion is something only the engine can answer (judged in the one existing place: an
  ///          engine that cannot answer falls back to the legacy parser, whose own reply to
  ///          `5 km to mi` is its "unrecognised content" error).
  ///
  ///          Associativity makes no practical difference (`a to b to c` converts step by step in the
  ///          engine too); it is written right-associative here because the right operand is a **whole
  ///          expression**, so a target carrying an operator of its own (`5 km to m/s`) reads in one
  ///          piece.
  ExprNode _parseExpression() {
    final left = _parseAdditive();
    if (left is ParseErrorNode) return left;
    _skipSpaces();
    if (!_atWord('to')) return left;
    final opStart = _index;
    _index += 2;
    final right = _parseExpression();
    return BinaryNode(
      'to',
      left,
      right,
      opStart: opStart,
      opEnd: opStart + 2,
      start: left.start,
      end: right.end,
    );
  }

  /// 中文：当前位置起是不是恰好这个**词**（前后都不是名字字符）。词运算符（今天只有 `to`）与
  ///       标识符共用同一片字符区，只有边界判得对，`token` 才不会被读成 `to` + `ken`。
  /// English: whether exactly this **word** starts here (no name character on either side). Word
  ///          operators (only `to` today) share their character range with identifiers, and only a
  ///          correct boundary keeps `token` from reading as `to` + `ken`.
  bool _atWord(String word) {
    if (_index + word.length > source.length) return false;
    if (source.substring(_index, _index + word.length) != word) return false;
    if (_index > 0 && _isNameChar(source[_index - 1])) return false;
    final after = _index + word.length;
    return after >= source.length || !_isNameChar(source[after]);
  }

  /// 中文：错误节点覆盖 [start, 源码末尾)，text 取该区间的原文；调用方只需把自己的起点传进来，
  ///       就能保证"返回的节点覆盖实际消费过的区域"。
  /// English: An error node covers [start, end of source) and keeps that raw text; callers pass
  ///          their own start so the returned node keeps covering everything consumed.
  ParseErrorNode _failure(int start) =>
      ParseErrorNode(source.substring(start), start: start, end: source.length);

  /// 中文：加减层，左结合；逗号由函数实参列表处理。
  /// English: Additive level, left-associative; commas are handled by argument lists.
  ExprNode _parseAdditive() {
    var left = _parseTerm();
    if (left is ParseErrorNode) return left;
    while (true) {
      _skipSpaces();
      if (_atEnd) return left;
      final op = source[_index];
      if (op != '+' && op != '-') return left;
      final opStart = _index;
      _index++;
      final right = _parseTerm();
      left = BinaryNode(
        op,
        left,
        right,
        opStart: opStart,
        opEnd: opStart + 1,
        start: left.start,
        end: right.end,
      );
      // 中文：悬空运算符保留结构（右操作数是零长度错误节点），算子本身仍可点击。
      // English: A dangling operator keeps its structure (the right operand is a zero-length
      //          error node) so the operator itself stays tappable.
      if (right is ParseErrorNode) return left;
    }
  }

  /// 中文：乘除层，左结合；并处理 `2x`、`3(1+2)` 这类并列书写产生的隐式乘法。
  /// English: Multiplicative level, left-associative; also handles juxtaposition (`2x`, `3(1+2)`).
  ExprNode _parseTerm() {
    var left = _parseUnary();
    if (left is ParseErrorNode) return left;
    while (true) {
      _skipSpaces();
      if (_atEnd) return left;
      final char = source[_index];
      final isExplicitOperator = char == '*' || char == '/';
      // 中文：**`to` 在项层停住**，否则 `5 km to mi` 会被读成 `5 × km × to × mi` 的隐式乘积，
      //       换算那一层永远拿不到它。词边界由 [_atWord] 判：`toto`、`2to`（前一格是名字字符）
      //       都不是这个词。
      // English: **the term level stops at `to`**, or `5 km to mi` reads as the implicit product
      //          `5 × km × to × mi` and the conversion level never sees it. The word boundary is
      //          [_atWord]'s: `toto`, or `2to` (a name character before it), are not this word.
      if (!isExplicitOperator && (_atWord('to') || !_startsFactor(char))) return left;
      final opStart = _index;
      if (isExplicitOperator) _index++;
      final right = _parseUnary();
      left = isExplicitOperator
          ? BinaryNode(char, left, right,
              opStart: opStart,
              opEnd: opStart + 1,
              start: left.start,
              end: right.end)
          : ImplicitProductNode(left, right,
              start: left.start, end: right.end);
      // 中文：右操作数失败时保留结构并停止，区间已经覆盖到消费过的位置。
      // English: A failed right operand keeps the structure and stops the loop; its span already
      //          covers everything consumed.
      if (right is ParseErrorNode) return left;
    }
  }

  /// 中文：一元正负号。优先级低于 `^`，因此 `-2^2` 解析为 `-(2^2)`。
  ///       嵌套层（括号、函数调用、符号链、幂链）都经过这里，因此深度上限也在此处收紧，
  ///       避免上千层括号这类粘贴进来的病态输入把调用栈撑爆——"永不抛异常"必须是真的。
  /// English: Unary sign. It binds looser than `^`, so `-2^2` parses as `-(2^2)`. Every nested
  ///          construct (groups, calls, sign chains, power chains) passes through here, so the
  ///          recursion cap lives here too: pathological pasted input such as thousands of nested
  ///          parentheses must not blow the call stack, because "never throws" has to hold.
  ExprNode _parseUnary() {
    if (_depth >= _maxDepth) return _failure(_index);
    _depth++;
    _skipSpaces();
    ExprNode node;
    if (!_atEnd && (source[_index] == '+' || source[_index] == '-')) {
      final opStart = _index;
      _index++;
      final operand = _parseUnary();
      node = UnaryNode(source[opStart], operand,
          start: opStart, end: operand.end);
    } else {
      node = _parsePower();
    }
    _depth--;
    return node;
  }

  /// 中文：幂运算，右结合：底数取后缀层，指数回到一元层，因此 `2^-3`、`2^3^2` 都成立。
  /// English: Power is right-associative and binds tighter than unary minus: the base comes from
  ///          the postfix level and the exponent from the unary level.
  ExprNode _parsePower() {
    final base = _parsePostfix();
    if (base is ParseErrorNode) return base;
    _skipSpaces();
    if (_atEnd || source[_index] != '^') return base;
    final opStart = _index;
    _index++;
    final exponent = _parseUnary();
    return BinaryNode(
      '^',
      base,
      exponent,
      opStart: opStart,
      opEnd: opStart + 1,
      start: base.start,
      end: exponent.end,
    );
  }

  /// 中文：后缀层，可连续叠加（`3!!`、`50%`）。
  /// English: Postfix level; suffixes stack (`3!!`, `50%`).
  ExprNode _parsePostfix() {
    var node = _parsePrimary();
    if (node is ParseErrorNode) return node;
    while (true) {
      _skipSpaces();
      if (_atEnd) return node;
      final char = source[_index];
      if (char != '!' && char != '%') return node;
      _index++;
      node = PostfixNode(char, node, start: node.start, end: _index);
    }
  }

  /// 中文：原子层：括号分组、标识符（常量/变量/函数调用）、**度分秒字面量**或数字；其余字符无法成句。
  /// English: Atom level: a group, an identifier (constant, variable or call), a **DMS literal** or a
  ///          number; anything else cannot start an expression.
  ExprNode _parsePrimary() {
    _skipSpaces();
    if (_atEnd) return _failure(_index);
    final char = source[_index];
    if (char == '(') return _parseGroup();
    if (_isLetter(char)) return _parseName();
    if (_isDigit(char) || char == '.') {
      // 中文：**度分秒字面量先试。** 判据只有一份（`sexagesimal_literal.dart`），所以屏幕上排成
      //       公式的字符串与求值那条路认下的字符串永远是同一个（那边调用的是同一个函数）。
      //       不是字面量时照旧走 [_parseNumber]——`1_000°`、`.5°`、`1.5e3°` 这些形状两条路都不认，
      //       于是它们在这里退化成错误节点，与归一化那边的拒绝一致。
      // English: **the DMS literal is tried first.** There is one judgement (`sexagesimal_literal.dart`),
      //          so the string that typesets as a formula and the string the value road accepts are
      //          always the same one (that road calls the same function). When it is not a literal the
      //          cursor falls through to [_parseNumber] — shapes such as `1_000°`, `.5°` and `1.5e3°`
      //          are refused by both roads and degrade to an error node here, matching normalisation's
      //          refusal.
      final literal = readSexagesimalLiteral(source, _index);
      if (literal != null) {
        _index = literal.end;
        return SexagesimalNode(
          literal.degrees,
          minutes: literal.minutes,
          seconds: literal.seconds,
          start: literal.start,
          end: literal.end,
        );
      }
      return _parseNumber();
    }
    return _failure(_index);
  }

  /// 中文：显式括号。缺右括号时整个分组退化为一个错误节点（区间从 `(` 开始）。
  /// English: Explicit group. A missing `)` degrades the whole group to one error node whose
  ///          span starts at the `(`.
  ExprNode _parseGroup() {
    final start = _index;
    _index++;
    final child = _parseExpression();
    if (child is ParseErrorNode) return _failure(start);
    _skipSpaces();
    if (_atEnd || source[_index] != ')') return _failure(start);
    _index++;
    return GroupNode(child, start: start, end: _index);
  }

  /// 中文：标识符。常量（pi/e/tau/phi/inf/infinity）优先于函数调用，因此 `pi(2)` 是隐式乘法，
  ///       与 `expression_parser.dart` 的归一化结果一致；函数名后面必须紧跟 `(`。
  /// English: Identifier. Constants win over calls, so `pi(2)` is an implicit product exactly as
  ///          in `expression_parser.dart`; a call requires a following `(`.
  ExprNode _parseName() {
    final start = _index;
    while (!_atEnd && _isNameChar(source[_index])) {
      _index++;
    }
    final name = source.substring(start, _index);
    final end = _index;
    if (_constants.contains(name.toLowerCase())) {
      return ConstantNode(name, start: start, end: end);
    }
    _skipSpaces();
    if (!_atEnd && source[_index] == '(') return _parseCall(name, start);
    return VariableNode(name, start: start, end: end);
  }

  /// 中文：函数调用。缺右括号或某个实参完全无法解析时，整个调用退化为一个错误节点，
  ///       区间从函数名开始（`sin(` → [0, 4)），这正是渲染层降级显示所需的范围。
  /// English: Function call. A missing `)` or a wholly unparseable argument degrades the call to
  ///          a single error node starting at the function name (`sin(` → [0, 4)).
  ExprNode _parseCall(String name, int start) {
    _index++;
    final args = <ExprNode>[];
    _skipSpaces();
    if (!_atEnd && source[_index] == ')') {
      _index++;
      return FunctionNode(name, args, start: start, end: _index);
    }
    var failed = false;
    while (true) {
      final arg = _parseExpression();
      args.add(arg);
      failed = failed || arg is ParseErrorNode;
      _skipSpaces();
      if (!_atEnd && source[_index] == ',') {
        _index++;
        continue;
      }
      break;
    }
    if (failed || _atEnd || source[_index] != ')') return _failure(start);
    _index++;
    return FunctionNode(name, args, start: start, end: _index);
  }

  /// 中文：数字字面量。识别范围与 `expression_parser.dart` 一致：十进制（可带 `.`、`_` 分隔符、
  ///       e 科学计数法）以及 `0x`/`0b`/`0o` 进制前缀；字面量按原文保留。
  /// English: Numeric literal. The recognised forms match `expression_parser.dart`: decimal with
  ///          optional `.`, `_` separators and `e` exponent, plus `0x`/`0b`/`0o` radix prefixes;
  ///          the literal keeps the original text.
  ExprNode _parseNumber() {
    final start = _index;
    final radix = _radixAt(start);
    if (radix != null) {
      _index += 2;
      if (_consumeRadixDigits(radix) == 0) return _failure(start);
      return NumberNode(source.substring(start, _index),
          start: start, end: _index);
    }

    var hasDigit = false;
    var lastWasDigit = false;
    var dotSeen = false;
    while (!_atEnd) {
      final char = source[_index];
      if (_isDigit(char)) {
        hasDigit = true;
        lastWasDigit = true;
        _index++;
        continue;
      }
      if (char == '_') {
        // 中文：分隔符只能夹在数字之间，避免吞掉下划线开头的标识符。
        // English: Separators only sit between digits, so identifiers are never swallowed.
        if (!lastWasDigit || !_isDigitAt(_index + 1)) break;
        lastWasDigit = false;
        _index++;
        continue;
      }
      if (char == '.' && !dotSeen) {
        dotSeen = true;
        lastWasDigit = false;
        _index++;
        continue;
      }
      break;
    }

    if (!_atEnd && (source[_index] == 'e' || source[_index] == 'E')) {
      // 中文：只有指数部分确实带数字时才把 `e` 算进字面量，否则回退让它作为常量 e 解析
      //       （`2e` = `2*e`），与 `expression_parser.dart` 的贪婪策略一致。
      // English: `e` joins the literal only when the exponent really has digits; otherwise the
      //          cursor rolls back so it reads as the constant (`2e` = `2*e`).
      final exponentStart = _index;
      _index++;
      if (!_atEnd && (source[_index] == '+' || source[_index] == '-')) {
        _index++;
      }
      var exponentDigits = 0;
      var lastExponentWasDigit = false;
      while (!_atEnd) {
        final char = source[_index];
        if (_isDigit(char)) {
          exponentDigits++;
          lastExponentWasDigit = true;
          _index++;
          continue;
        }
        if (char == '_') {
          if (!lastExponentWasDigit || !_isDigitAt(_index + 1)) break;
          lastExponentWasDigit = false;
          _index++;
          continue;
        }
        break;
      }
      if (exponentDigits == 0) _index = exponentStart;
    }

    if (!hasDigit) return _failure(start);
    return NumberNode(source.substring(start, _index),
        start: start, end: _index);
  }

  /// 中文：识别 `0x`/`0b`/`0o` 前缀，返回对应进制；没有前缀返回 null。
  /// English: Recognises the `0x`/`0b`/`0o` prefix and returns its radix, or null without one.
  int? _radixAt(int index) {
    if (index + 2 > source.length || source[index] != '0') return null;
    return switch (source[index + 1]) {
      'x' => 16,
      'b' => 2,
      'o' => 8,
      _ => null,
    };
  }

  /// 中文：消费该进制的数字（允许 `_` 夹在数字之间），返回数字个数。
  /// English: Consumes digits of the given radix (allowing `_` between digits) and counts them.
  int _consumeRadixDigits(int radix) {
    var count = 0;
    var lastWasDigit = false;
    while (!_atEnd) {
      final char = source[_index];
      if (char == '_') {
        if (!lastWasDigit) break;
        final next = _radixDigitAt(_index + 1);
        if (next == null || next >= radix) break;
        lastWasDigit = false;
        _index++;
        continue;
      }
      final digit = _radixDigitAt(_index);
      if (digit == null || digit >= radix) break;
      count++;
      lastWasDigit = true;
      _index++;
    }
    return count;
  }

  /// 中文：`(`、字母或数字都能与左侧操作数并列书写，产生隐式乘法。数字只可能出现在
  ///       `)`、`!`、`%` 之后（数字字面量与标识符本身都是贪婪读取的），所以判断是安全的。
  /// English: `(`, a letter or a digit can follow an operand by juxtaposition. A digit can only
  ///          follow `)`, `!` or `%` here, because numbers and identifiers are read greedily.
  bool _startsFactor(String char) =>
      char == '(' || _isLetter(char) || _isDigit(char);

  void _skipSpaces() {
    while (!_atEnd && source[_index].trim().isEmpty) {
      _index++;
    }
  }

  // 中文：以下字符判断等价于 `expression_parser.dart` 使用的 `[A-Za-z]`、`[A-Za-z0-9]`、`[0-9]`，
  //       直接比较码元以避免逐字符构造正则。
  // English: These character tests are equivalent to the `[A-Za-z]`, `[A-Za-z0-9]` and `[0-9]`
  //          patterns used by `expression_parser.dart`, compared by code unit for speed.
  bool _isLetter(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a);
  }

  bool _isNameChar(String char) {
    final code = char.codeUnitAt(0);
    return _isLetter(char) || (code >= 0x30 && code <= 0x39);
  }

  bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  bool _isDigitAt(int index) =>
      index < source.length && _isDigit(source[index]);

  int? _radixDigitAt(int index) {
    if (index >= source.length) return null;
    final code = source[index].codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) return code - 0x30;
    if (code >= 0x61 && code <= 0x66) return code - 0x61 + 10;
    return null;
  }
}
