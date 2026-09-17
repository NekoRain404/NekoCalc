part of 'calculator_controller.dart';

mixin _CalculatorEditing on _CalculatorState {
  void input(String token) {
    if (token == 'AC') {
      clear();
      return;
    }
    if (token == '⌫') {
      backspace();
      return;
    }
    if (token == '=') {
      _cancelLiveEvaluation();
      unawaited(submit());
      return;
    }
    _markStateEdited();
    _recordUndoSnapshot();
    if (token == '+/-') {
      _toggleSign();
    } else if (token == '%') {
      if (selection.isCollapsed) {
        _replaceAroundCursor(_applyPercent(expressionBeforeCursor));
      } else {
        _replaceSelectionWith('($_selectedExpression/100)');
      }
    } else if (_isOperator(token)) {
      final prefix = selection.isCollapsed
          ? _appendOperator(expressionBeforeCursor, token)
          : '$expressionBeforeCursor$token';
      _replaceAroundCursor(prefix);
    } else if (token == '.') {
      _replaceAroundCursor(_appendDecimal(expressionBeforeCursor));
    } else {
      _insert(token);
    }
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  void setExpression(String value) {
    if (expression == value) return;
    _markStateEdited();
    _recordUndoSnapshot();
    expression = value;
    cursorIndex = expression.length;
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  CalculatorPasteResult applyPastedText(String value) {
    final paste = CalculatorPasteResult.fromText(value);
    final hasMetadata = paste.angleMode != null || paste.memoryValue != null;
    if (!paste.hasExpression && !hasMetadata) return paste;
    _markStateEdited();
    _recordUndoSnapshot();
    if (paste.hasExpression) {
      expression = paste.expression;
      cursorIndex = expression.length;
    }
    final angleChanged =
        paste.angleMode != null && angleMode != paste.angleMode;
    if (paste.angleMode != null) angleMode = paste.angleMode!;
    if (paste.memoryValue != null) memoryValue = paste.memoryValue!;
    if (paste.hasExpression || (angleChanged && expression.isNotEmpty)) {
      evaluate();
    }
    unawaited(_persistState());
    notifyListeners();
    return paste;
  }

  void append(String token) {
    _markStateEdited();
    _recordUndoSnapshot();
    final nextPrefix = _appendSmart(expressionBeforeCursor, token);
    _replaceAroundCursor(nextPrefix);
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  void applyUnaryFunction(String name) {
    _markStateEdited();
    _recordUndoSnapshot();
    if (!selection.isCollapsed) {
      _replaceSelectionWith('$name($_selectedExpression)');
      _scheduleLiveEvaluation();
      notifyListeners();
      return;
    }
    final insertion = _wrapTrailingValue(expressionBeforeCursor, name);
    _replaceAroundCursor(insertion.text, cursorBack: insertion.cursorBack);
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  void applyBinaryFunction(String name) {
    _markStateEdited();
    _recordUndoSnapshot();
    if (!selection.isCollapsed) {
      final selected = _selectedExpression;
      _replaceSelectionWith(
        '$name($selected,)',
        cursorOffset: name.length + selected.length + 2,
      );
      _scheduleLiveEvaluation();
      notifyListeners();
      return;
    }
    final insertion =
        _wrapTrailingValue(expressionBeforeCursor, name, binary: true);
    _replaceAroundCursor(insertion.text, cursorBack: insertion.cursorBack);
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  void backspace() {
    if (expression.isEmpty || (selection.isCollapsed && cursorIndex == 0)) {
      return;
    }
    _markStateEdited();
    _recordUndoSnapshot();
    if (!selection.isCollapsed) {
      expression = expression.substring(0, selection.start) +
          expression.substring(selection.end);
      cursorIndex = selection.start;
    } else {
      expression = expression.substring(0, cursorIndex - 1) +
          expression.substring(cursorIndex);
      cursorIndex--;
    }
    _scheduleLiveEvaluation();
    notifyListeners();
  }

  void continueWithResult() {
    if (hasError || result == '等待输入') return;
    _markStateEdited();
    _recordUndoSnapshot();
    expression = reusableResult;
    cursorIndex = expression.length;
    evaluate();
    unawaited(_persistState());
    notifyListeners();
  }

  void clear() {
    if (expression.isEmpty &&
        result == '0' &&
        !hasError &&
        errorMessage == null) {
      return;
    }
    _markStateEdited();
    _recordUndoSnapshot();
    expression = '';
    cursorIndex = 0;
    _result = MathResult.zero;
    hasError = false;
    errorMessage = null;
    _ansSourceForExpression = null;
    _ansValueForExpression = null;
    unawaited(_persistState());
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _markStateEdited();
    _cancelLiveEvaluation();
    _redoStack.add(_snapshot());
    _restoreSnapshot(_undoStack.removeLast());
    unawaited(_persistState());
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _markStateEdited();
    _cancelLiveEvaluation();
    _undoStack.add(_snapshot());
    _restoreSnapshot(_redoStack.removeLast());
    unawaited(_persistState());
    notifyListeners();
  }

  String get expressionBeforeCursor => expression.substring(0, selection.start);

  String get expressionAfterCursor => expression.substring(selection.end);

  void moveCursorLeft() {
    if (!selection.isCollapsed) {
      _markStateEdited();
      cursorIndex = selection.start;
      unawaited(_persistState());
      notifyListeners();
      return;
    }
    if (cursorIndex == 0) return;
    _markStateEdited();
    cursorIndex--;
    unawaited(_persistState());
    notifyListeners();
  }

  void moveCursorRight() {
    if (!selection.isCollapsed) {
      _markStateEdited();
      cursorIndex = selection.end;
      unawaited(_persistState());
      notifyListeners();
      return;
    }
    if (cursorIndex >= expression.length) return;
    _markStateEdited();
    cursorIndex++;
    unawaited(_persistState());
    notifyListeners();
  }

  void moveCursorByBlockBackward() {
    if (!selection.isCollapsed) {
      _markStateEdited();
      cursorIndex = selection.start;
      unawaited(_persistState());
      notifyListeners();
      return;
    }
    final boundary = previousExpressionBoundary(expression, cursorIndex);
    if (boundary == cursorIndex) return;
    _markStateEdited();
    cursorIndex = boundary;
    unawaited(_persistState());
    notifyListeners();
  }

  void moveCursorByBlockForward() {
    if (!selection.isCollapsed) {
      _markStateEdited();
      cursorIndex = selection.end;
      unawaited(_persistState());
      notifyListeners();
      return;
    }
    final boundary = nextExpressionBoundary(expression, cursorIndex);
    if (boundary == cursorIndex) return;
    _markStateEdited();
    cursorIndex = boundary;
    unawaited(_persistState());
    notifyListeners();
  }

  void selectAll() {
    final next = ExpressionSelection(0, expression.length);
    if (_selection == next) return;
    _markStateEdited();
    _selection = next;
    unawaited(_persistState());
    notifyListeners();
  }

  void moveCursorToStart() {
    if (selection.isCollapsed && cursorIndex == 0) return;
    _markStateEdited();
    cursorIndex = 0;
    unawaited(_persistState());
    notifyListeners();
  }

  void moveCursorToEnd() {
    if (selection.isCollapsed && cursorIndex == expression.length) return;
    _markStateEdited();
    cursorIndex = expression.length;
    unawaited(_persistState());
    notifyListeners();
  }

  _CalculatorSnapshot _snapshot() {
    return _CalculatorSnapshot(
      expression: expression,
      // 中文：快照带的是整个三形态结果，否则撤销/重做会把精确形式还原成只剩显示文本，十进制形态
      //       一去不返，Ans/last 又静默失效。
      // English: The snapshot carries the whole three-form result; otherwise undo/redo would restore
      //          an exact form as display text alone, the decimal form would be gone for good and
      //          Ans/last would silently stop resolving again.
      result: _result,
      angleMode: angleMode,
      selection: selection,
      memoryValue: memoryValue,
      hasError: hasError,
      errorMessage: errorMessage,
      lastFiniteResult: _lastFiniteResult,
      ansSourceForExpression: _ansSourceForExpression,
      ansValueForExpression: _ansValueForExpression,
    );
  }

  @override
  void _recordUndoSnapshot() {
    final snapshot = _snapshot();
    if (_undoStack.isNotEmpty && _undoStack.last == snapshot) return;
    _undoStack.add(snapshot);
    if (_undoStack.length > _maxUndoDepth) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _restoreSnapshot(_CalculatorSnapshot snapshot) {
    expression = snapshot.expression;
    _result = snapshot.result;
    angleMode = snapshot.angleMode;
    _selection = snapshot.selection.clamp(expression.length);
    memoryValue = snapshot.memoryValue;
    hasError = snapshot.hasError;
    errorMessage = snapshot.errorMessage;
    _lastFiniteResult = snapshot.lastFiniteResult;
    _ansSourceForExpression = snapshot.ansSourceForExpression;
    _ansValueForExpression = snapshot.ansValueForExpression;
  }

  void _toggleSign() {
    if (!selection.isCollapsed) {
      _replaceSelectionWith('(-$_selectedExpression)');
      return;
    }
    final before = expressionBeforeCursor;
    final after = expressionAfterCursor;
    if (before.isEmpty) {
      expression = '-$after';
      cursorIndex = 1;
      return;
    }

    final trailingMinus = _trailingUnaryMinusStart(before);
    if (trailingMinus != null) {
      final nextPrefix = before.substring(0, trailingMinus) +
          before.substring(trailingMinus + 1);
      expression = nextPrefix + after;
      cursorIndex = nextPrefix.length;
      return;
    }

    if (_endsWithOpenInput(before)) {
      final nextPrefix = '$before-';
      expression = nextPrefix + after;
      cursorIndex = nextPrefix.length;
      return;
    }

    final range = _trailingValueRange(before);
    if (range == null) {
      final nextPrefix = '-($before)';
      expression = nextPrefix + after;
      cursorIndex = nextPrefix.length;
      return;
    }

    final value = before.substring(range.start, range.end);
    final unwrapped = _unwrappedParenthesizedNegative(value);
    if (unwrapped != null) {
      final nextPrefix =
          '${before.substring(0, range.start)}$unwrapped${before.substring(range.end)}';
      expression = nextPrefix + after;
      cursorIndex = nextPrefix.length;
      return;
    }

    final signStart = _unaryMinusStart(before, range.start);
    if (signStart != null) {
      final nextPrefix =
          before.substring(0, signStart) + before.substring(signStart + 1);
      expression = nextPrefix + after;
      cursorIndex = nextPrefix.length;
      return;
    }

    final replacement = range.start == 0 ? '-$value' : '(-$value)';
    final nextPrefix =
        '${before.substring(0, range.start)}$replacement${before.substring(range.end)}';
    expression = nextPrefix + after;
    cursorIndex = nextPrefix.length;
  }

  int? _trailingUnaryMinusStart(String current) {
    if (current.isEmpty || current[current.length - 1] != '-') return null;
    return _unaryMinusStart(current, current.length);
  }

  int? _unaryMinusStart(String current, int valueStart) {
    final signIndex = valueStart - 1;
    if (signIndex < 0 || current[signIndex] != '-') return null;
    if (signIndex == 0) return signIndex;
    final beforeSign = current[signIndex - 1];
    return _isOperator(beforeSign) || beforeSign == '(' || beforeSign == ','
        ? signIndex
        : null;
  }

  String? _unwrappedParenthesizedNegative(String value) {
    if (!value.startsWith('(-') || !value.endsWith(')')) return null;
    final inner = value.substring(2, value.length - 1);
    return inner.isEmpty ? null : inner;
  }

  void _insert(String token) {
    final start = selection.start;
    expression = expressionBeforeCursor + token + expressionAfterCursor;
    cursorIndex = start + token.length;
  }

  /// 中文：把光标左侧的文本换成 [prefix]，并把光标放在它末尾之前 [cursorBack] 个字符处。
  ///       [cursorBack] 默认为 0（光标落在插入文本的末尾），也就是这个方法的原始行为——
  ///       函数调用那条路要的是「落在括号里 / 逗号右边」，见 [_wrapTrailingValue]。
  /// English: Replaces the text left of the caret with [prefix] and puts the caret [cursorBack]
  ///          characters before its end. The default of 0 — the caret at the end of what was
  ///          inserted — is this method's original behaviour; the function-call path is what needs
  ///          "inside the brackets" / "right of the comma", see [_wrapTrailingValue].
  void _replaceAroundCursor(String prefix, {int cursorBack = 0}) {
    expression = prefix + expressionAfterCursor;
    cursorIndex = prefix.length - cursorBack;
  }

  String get _selectedExpression =>
      expression.substring(selection.start, selection.end);

  void _replaceSelectionWith(String replacement, {int? cursorOffset}) {
    final prefix = expression.substring(0, selection.start);
    expression = '$prefix$replacement$expressionAfterCursor';
    cursorIndex = prefix.length + (cursorOffset ?? replacement.length);
  }

  bool _isOperator(String token) =>
      token == '+' ||
      token == '-' ||
      token == '×' ||
      token == '÷' ||
      token == '^';

  String _appendOperator(String current, String token) {
    if (current.isEmpty) return token == '-' ? '-' : current;
    if (_isOperator(current[current.length - 1])) {
      return '${current.substring(0, current.length - 1)}$token';
    }
    return current + token;
  }

  String _appendDecimal(String current) {
    final match = RegExp(r'(\d*\.?\d*)$').firstMatch(current);
    final tail = match?.group(0) ?? '';
    if (tail.contains('.')) return current;
    if (tail.isEmpty) return '${current}0.';
    return '$current.';
  }

  String _appendSmart(String current, String token) {
    if (current.isEmpty) return token;
    final last = current[current.length - 1];
    final endsValue = RegExp(r'[0-9A-Za-z)]').hasMatch(last);
    final startsValue = _startsValue(token);
    if (endsValue && startsValue) {
      return '$current×$token';
    }
    return current + token;
  }

  /// 中文：把光标左侧的值套进一次函数调用，并把光标放回**第一个空槽**。返回两样东西：要插入
  ///       光标左侧的文本，以及光标离该文本末尾的字符数（[cursorBack]）。
  ///
  ///       **右括号一定要补上。** 这条以前不成立：空输入或光标停在运算符/`(`/`,` 之后时插进去的
  ///       只有 `name(`，右括号从来没出现。用户接着输入实参，表达式里就永久留下 `sqrt(8` 这样的
  ///       形状——而解析器**刻意**把未闭合的调用降级成字面文本（`_parseCall` 的 `_failure`），
  ///       于是屏幕上显示的是灰色的字母 `sqrt(8`，求值也永远是错的。真机实测的复现路径是
  ///       「按 `√x`、再按 `8`」。
  ///
  ///       光标位置按同一条规则定：**落在第一个空槽里**。
  ///       - 空输入 / 尾部是开口结构：空槽就是 `(` 之后，于是光标停在 `name(|)`；
  ///       - 左侧有值：一元调用的实参已经填好，没有空槽，光标留在调用之后（与修改前一致）；
  ///         二元调用还欠第二个实参，空槽是 `,` 之后，光标停在 `name(值|,)` 的逗号右边。
  ///
  ///       English: Wraps the value left of the caret in a call and puts the caret back into the
  ///              **first empty slot**. Two things come back: the text to insert before the caret,
  ///              and how far from its end the caret sits ([cursorBack]).
  ///
  ///              **The closing bracket must always be written.** It used to be missing: for an
  ///              empty input, or with the caret after an operator / `(` / `,`, only `name(` was
  ///              inserted and the bracket never appeared. Whatever the user typed next left
  ///              `sqrt(8` in the expression for good — and the parser **deliberately** degrades an
  ///              unclosed call to literal text (`_parseCall`'s `_failure`), so the screen showed a
  ///              grey `sqrt(8` in letters and the value was wrong forever. The reproduction on a
  ///              device is "press `√x`, then `8`".
  ///
  ///              The caret follows one rule: **the first empty slot**.
  ///              - empty input / a dangling open construct: that slot is just after `(`, so the
  ///                caret sits at `name(|)`;
  ///              - a value on the left: a unary call has its argument filled, so there is no
  ///                empty slot and the caret stays after the call (unchanged); a binary call still
  ///                owes its second argument, so the slot is after the `,` and the caret sits to
  ///                the right of the comma in `name(value|,)`.
  ({String text, int cursorBack}) _wrapTrailingValue(String current, String name,
      {bool binary = false}) {
    // 中文：没有实参可套时的插入物：一元是 `name()`，二元是 `name(,)`——右括号在两种情况下
    //       都在。`cursorBack` 把光标放回第一个空槽：一元的空槽紧跟 `(`（退 1 格），二元的
    //       第一个空槽也在 `(` 之后（退 2 格，越过那个逗号）。
    // English: What goes in when there is no argument to wrap: `name()` for a unary call,
    //          `name(,)` for a binary one — the closing bracket is present either way.
    //          `cursorBack` puts the caret back into the first empty slot: for a unary call that
    //          slot follows `(` (one step back), and for a binary call the first empty slot is
    //          after the `(` too (two steps back, past the comma).
    final String emptySlot = binary ? '(,)' : '()';
    // 中文：左侧有值时的尾部：一元补右括号就完事，二元补的是「逗号 + 右括号」——第二个实参还空着。
    // English: The tail once a value is wrapped: a unary call only needs its bracket, a binary one
    //          needs "comma then bracket" because its second argument is still empty.
    final String tail = binary ? ',)' : ')';
    if (current.isEmpty || _endsWithOpenInput(current)) {
      return (
        text: '$current$name$emptySlot',
        cursorBack: binary ? 2 : 1,
      );
    }
    final range = _trailingValueRange(current);
    if (range == null) {
      return (
        text: '$current$name$emptySlot',
        cursorBack: binary ? 2 : 1,
      );
    }
    final value = current.substring(range.start, range.end);
    return (
      text: '${current.substring(0, range.start)}$name($value$tail',
      cursorBack: binary ? 1 : 0,
    );
  }

  bool _endsWithOpenInput(String current) {
    final last = current[current.length - 1];
    return _isOperator(last) || last == '(' || last == ',';
  }

  ({int start, int end})? _trailingValueRange(String current) {
    var end = current.length;
    while (end > 0 && current[end - 1].trim().isEmpty) {
      end--;
    }
    if (end == 0) return null;
    final last = current[end - 1];
    if (last == ')') {
      final groupStart = _matchingGroupStart(current, end - 1);
      if (groupStart == null) return null;
      final functionStart = _functionNameStart(current, groupStart);
      return (start: functionStart ?? groupStart, end: end);
    }
    var start = end;
    while (start > 0 && RegExp(r'[A-Za-z0-9.]').hasMatch(current[start - 1])) {
      start--;
    }
    if (start == end) return null;
    return (start: start, end: end);
  }

  int? _matchingGroupStart(String current, int closeIndex) {
    var depth = 0;
    for (var i = closeIndex; i >= 0; i--) {
      if (current[i] == ')') depth++;
      if (current[i] == '(') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  int? _functionNameStart(String current, int openIndex) {
    var start = openIndex;
    while (start > 0 && RegExp(r'[A-Za-z0-9]').hasMatch(current[start - 1])) {
      start--;
    }
    return start == openIndex ? null : start;
  }

  bool _startsValue(String token) {
    if (RegExp(r'^\d').hasMatch(token)) return true;
    if (token == 'pi' || token == 'e') return true;
    if (token.startsWith('(')) return true;
    const functionPrefixes = [
      'sqrt(',
      'cbrt(',
      'sin(',
      'cos(',
      'tan(',
      'asin(',
      'acos(',
      'atan(',
      'sinh(',
      'cosh(',
      'tanh(',
      'cot(',
      'sec(',
      'csc(',
      'log(',
      'log2(',
      'ln(',
      'exp(',
      'abs(',
      'fact(',
      'floor(',
      'ceil(',
      'round(',
      'deg(',
      'rad(',
      'min(',
      'max(',
      'mod(',
      'ncr(',
      'npr(',
      'gcd(',
      'lcm(',
      'root(',
      'atan2(',
      // 中文：`ran#`、Σ、Π、∫dx、lim、logₓy 插的调用与上面那些同类——紧跟在数值后面是隐式乘法，
      //       不是并排的两个符号，所以 `2` 之后按 Σ 得到 `2×sum(x,1,10,x)`。
      // English: the calls inserted by `ran#`, Σ, Π, ∫dx, lim and logₓy belong with the ids above —
      //          right after a number they are an implicit product rather than two symbols side by
      //          side, so `2` then Σ gives `2×sum(x,1,10,x)`.
      'rand(',
      'sum(',
      'product(',
      'integrate(',
      'limit(',
    ];
    return functionPrefixes.any(token.startsWith);
  }

  String _applyPercent(String current) {
    if (current.isEmpty) return current;
    final match = RegExp(r'(\d+(?:\.\d+)?)$').firstMatch(current);
    if (match == null) return '($current)/100';
    final value = match.group(1)!;
    return '${current.substring(0, match.start)}($value/100)';
  }

}
