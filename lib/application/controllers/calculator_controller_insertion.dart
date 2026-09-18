part of 'calculator_controller.dart';

/// 中文：**按键写出来的那段文本归这里。** 这个 part 里的每一个成员都是**顶层纯函数**——吃一段
///       已有文本（光标左边那一截）与一个 token，只回「该写什么」或「该套住哪个区间」。
///
///       拆出来的那条缝就是**这条纯度线**，不是按功能切的。留在 `calculator_controller_editing.dart`
///       里的是**命令**——`input`/`backspace`/`undo`/光标移动——每一个都改状态、记撤销快照、发通知；
///       搬到这里的是**文本算术**。而且这里不是「约定为纯」：**顶层函数没有 `this`**，所以
///       「不碰控制器状态」是编译器守着的，不是注释里的一句话。搬过来的六件事：
///
///       - 运算符与小数点怎么落到文本上（[_isOperator]、[_appendOperator]、[_appendDecimal]）；
///       - 隐式乘法（[_appendSmart]、[_startsValue]）与百分号折叠（[_applyPercent]）；
///       - 把光标左边那个值套进一次调用（[_wrapTrailingValue]）以及它要读的三个区间
///         （[_endsWithOpenInput]、[_trailingValueRange]、[_matchingGroupStart]、[_functionNameStart]）。
///
///       （它们原来都是 `_CalculatorEditing` 的实例方法；那些方法**一次 `this` 都没用过**，
///       所以这次搬移对调用方是逐字透明的——`_startsValue(token)` 还是那么写。）
///
///       **为什么在这一轮拆。** `_startsValue` 这一轮要在「隐式乘法的判据」上重写（手抄的 39 条
///       前缀表换成一条语法规则：`名字(` 开头即值，理由写在那个函数上——`STAT` 面板的 `mean`
///       在 `12` 后面得到的是 `12mean(5,12)` 而不是 `12×mean(5,12)`）。带着那一版注释，
///       `calculator_controller_editing.dart` 是 **849 行**，越过 800 行的硬边界。**所以先把这一块纯度一致的成员搬出来（本提交是纯搬移，
///       不改行为），判据本身在下一个提交里换。**
///
///       **不靠删注释凑数**：把这一整块纯度一致的成员搬进自己的文件。搬完之后 `wc -l` 数出来是
///       `calculator_controller_editing.dart` **588 行**、本文件 **325 行**。搬移是纯搬移——代码
///       逐字来自原文件，一个字符的行为都没改——而且**搬完之后重跑了全量 `flutter test`**，
///       不是只跑构建。（上一轮 Kotlin 拆分就是只验了构建、弄红了一条 Dart 守卫。）
///
/// English: **the text a key writes lives here.** Every member of this part is a **top-level pure
///          function**: it takes some existing text (the slice left of the caret) and a token, and
///          returns only "what to write" or "which range to wrap".
///
///          That purity line **is** the seam, and the split is not by feature. What stays in
///          `calculator_controller_editing.dart` are **commands** — `input`/`backspace`/`undo`/cursor
///          movement — and every one of them changes state, records an undo snapshot and notifies.
///          What moved here is **text arithmetic**. And it is not "pure by convention": **a top-level
///          function has no `this`**, so "touches no controller state" is enforced by the compiler
///          rather than asserted in a comment. The six things that came along:
///
///          - how an operator and a decimal point land on the text ([_isOperator], [_appendOperator],
///            [_appendDecimal]);
///          - implicit multiplication ([_appendSmart], [_startsValue]) and the percent fold
///            ([_applyPercent]);
///          - wrapping the value left of the caret in a call ([_wrapTrailingValue]) plus the three
///            range readers it needs ([_endsWithOpenInput], [_trailingValueRange],
///            [_matchingGroupStart], [_functionNameStart]).
///
///          (They used to be instance methods of `_CalculatorEditing`; **not one of them ever used
///          `this`**, so for callers the move is verbatim transparent — `_startsValue(token)` is
///          still written the same way.)
///
///          **Why this round.** `_startsValue` had to be rewritten this round on the
///          implicit-multiplication criterion (a hand-copied 39-entry prefix table replaced by one
///          syntax rule — a token opening with `name(` is a value; the reasoning is on that function
///          — the `STAT` sheet's `mean` after `12` gave `12mean(5,12)` instead of `12×mean(5,12)`).
///          With that comment written, `calculator_controller_editing.dart` stood at **849 lines**,
///          past the 800-line boundary.
///
///          **Not by deleting comments to fit**: the whole block of members sharing that purity moved
///          into a file of its own. Afterwards `wc -l` counts `calculator_controller_editing.dart` at
///          **588 lines** and this file at **325**. The move is a pure move — the code is verbatim
///          from the old file and not one character of behaviour changed — and the **full
///          `flutter test` run was repeated after it**, not just a build. (Last round's Kotlin split
///          verified only the build and turned a Dart guard red.)

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
