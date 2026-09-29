part of 'expression_parser.dart';

/// 中文：**粘贴进来的那一行里，有没有结果注解要剥掉。** 这一族从
///       `expression_input_normalization.dart` 搬出来，**只搬不改**（正文 175 行 md5
///       `3a8d0be9703f953b8fed7c180db3dba4`，与搬家前逐字节相同），理由与那个文件里其余几次
///       拆分一样：搬之前它已经 **856 行**，越过了 800 的硬线。
///
///       **缝在哪儿**：这一族做的是一件事——**判断这一行是不是算式 + 它自己的值**
///       （`2+2=4`、`sqrt(81) = 9`），是就只留算式。后面那些模式常量与归一化器做的是另一件事：
///       把各种写法（全角、LaTeX、Unicode 分数、别名）折成同一种形态。两件事之间没有调用关系。
/// English: **whether the pasted line carries a "result annotation" to strip.** This family moved out of
///          `expression_input_normalization.dart` **verbatim** (its 175 lines hash to
///          `3a8d0be9703f953b8fed7c180db3dba4`, byte-identical to before the move), for the same reason as
///          the other splits in that file: before the move it stood at **856 lines**, past the hard 800.
///
///          **Where the seam is**: this family answers one question — **"is this line a sum plus its own
///          value"** (`2+2=4`, `sqrt(81) = 9`), and keeps only the sum. The pattern constants and
///          normalisers after it answer a different one: folding the many spellings (full-width, LaTeX,
///          Unicode fractions, aliases) into one shape. Neither calls the other.

String _stripPastedCalculationResult(String source) {
  final normalized = _normalizeFullWidthAscii(source)
      .replaceAll('\u00a0', ' ')
      .replaceAll('≈', '~=')
      .trim();
  if (normalized.isEmpty) return normalized;

  final lines = normalized
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  for (final line in lines) {
    final expression = RegExp(
      r'^(?:表达式|算式|expression|expr|formula)\s*[:：]\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (expression != null && expression.group(1)!.trim().isNotEmpty) {
      return expression.group(1)!.trim();
    }
  }
  for (final line in lines) {
    final labeledResult = _labeledResultExpression(line);
    if (labeledResult != null) return labeledResult;
  }

  if (lines.length == 1) {
    final labeledResult = _labeledResultExpression(lines.single);
    if (labeledResult != null) return labeledResult;
    final annotated = _trailingResultAnnotationExpression(lines.single);
    if (annotated != null) return annotated;
  }
  return source;
}

String? _labeledResultExpression(String line) {
  final match = RegExp(
    r'^(?:ans|answer|result|value|结果|答案|当前值)\s*[:：=]\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(line);
  final value = match?.group(1)?.trim();
  return value == null || value.isEmpty ? null : value;
}

String? _trailingResultAnnotationExpression(String line) {
  final trailingEquals = RegExp(r'^(.+?)\s*=\s*$').firstMatch(line);
  if (trailingEquals != null) {
    final expression = trailingEquals.group(1)!.trim();
    return _looksLikeCalculationExpression(expression) ? expression : null;
  }

  final annotated = RegExp(
    r'^(.+?)\s*(?:=|~=|≃|≅|->|=>|→)\s*[+-]?(?:(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?%?\s*$',
    caseSensitive: false,
  ).firstMatch(line);
  if (annotated == null) return null;
  final expression = annotated.group(1)!.trim();
  if (!_looksLikeCalculationExpression(expression)) return null;
  // 中文：**本轮加的闸门：式子不闭合就不剥。**
  //
  //       规则的原意是剥掉**别处复制来的结果注解**——`sqrt(81) = 9`、`2+2=4` 这种
  //       「算式 + 它自己的值」。可它原来只看右边是不是数字，**不看左边有没有自由变量**，
  //       于是把**方程**一起吃掉了：
  //
  //           粘贴 `2x+1=7`  → 屏幕上是 `2x+1=7`，送进引擎的是 `2x+1`
  //           粘贴 `x^2-4=0` → 屏幕上是 `x^2-4=0`，送进引擎的是 `x^2-4`
  //
  //       **这是静默错值**：用户看着一个方程，拿到的是另一个式子的值。而 `2x+1` 里那个 `x`
  //       是自由变量，它**不可能**等于 7——所以 `= 7` 本来就不可能是"这个算式的结果"。
  //       判据就是这个：**左边闭合才可能是结果注解。**
  //
  //       **`2+2=` 那一条（上面那一支）不动**：末尾一个光秃秃的等号是"算式写完了"的意思，
  //       与结果注解无关，剥掉它对 `x^2-4=` 同样是对的。
  // English: **the gate this round adds: do not strip unless the left side is closed.**
  //
  //          The rule's purpose is to strip a **result annotation copied from elsewhere** —
  //          `sqrt(81) = 9`, `2+2=4`, the "sum plus its own value" shape. But it used to look only at
  //          whether the right side is a number, **never at whether the left side has a free
  //          variable**, so it swallowed **equations** whole:
  //
  //              paste `2x+1=7`   -> the screen reads `2x+1=7`, the engine is handed `2x+1`
  //              paste `x^2-4=0`  -> the screen reads `x^2-4=0`, the engine is handed `x^2-4`
  //
  //          **That is a silent wrong value**: the user looks at an equation and gets another
  //          expression's value. And the `x` in `2x+1` is a free variable — it **cannot** equal 7, so
  //          `= 7` was never "this sum's result". That is the criterion: **only a closed left side can
  //          be a result annotation.**
  //
  //          **The `2+2=` branch above does not move**: a bare trailing equals means "the sum is
  //          finished" and has nothing to do with a result annotation; stripping it is equally right
  //          for `x^2-4=`.
  if (!_holdsNoFreeVariable(expression)) return null;
  return expression;
}

/// 中文：**这个式子闭合吗**——里面有没有「自由的」字母标识符（也就是拿不到值的变量）。
///
///       先把**数字字面量整段抹掉**（含 `0x`/`0b`/`0o` 与科学计数法的 `e`），
///       剩下的字母词才可能是变量；然后逐个看：
///
///       * **后面紧跟 `(`** ⇒ 函数调用（`sqrt`、`sin`），不是变量；
///       * **在常量表里** ⇒ `pi`/`e`/`tau`/`i` 这些拿得到值，不是自由变量；
///       * **其余** ⇒ 自由变量，式子不闭合。
///
///       **为什么不干脆"左边有字母就不剥"**：那会把 `sqrt(81) = 9` 一起挡掉，
///       而它正是这条规则存在的理由（现有测试钉着它）。要挡的是**自由变量**，不是字母。
/// English: **is this expression closed** — does it contain a "free" letter identifier, i.e. a
///          variable with no value?
///
///          First **erase every numeric literal whole** (`0x`/`0b`/`0o` forms and a scientific
///          notation's `e` included); what letters remain may be variables. Then look at each one:
///
///          * **followed by `(`** means a function call (`sqrt`, `sin`), not a variable;
///          * **in the constant table** means `pi`/`e`/`tau`/`i` and friends have a value, so not free;
///          * **anything else** is a free variable and the expression is not closed.
///
///          **Why not simply "no letters on the left"**: that would also block `sqrt(81) = 9`, which
///          is exactly why this rule exists (an existing test pins it). What must be blocked is a
///          **free variable**, not a letter.
bool _holdsNoFreeVariable(String source) {
  final rest = _withoutNumericLiterals(source);
  for (final match in RegExp(r'[A-Za-z_]\w*').allMatches(rest)) {
    final name = match.group(0)!.toLowerCase();
    if (rest.substring(match.end).trimLeft().startsWith('(')) continue;
    if (_closureExemptNames.contains(name)) continue;
    return false;
  }
  return true;
}

/// 中文：把数字字面量整段抹成空格。**顺序有讲究**：进制前缀要在十进制那条之前
///       （否则 `0xFF` 会被 `\d+` 吃掉一个 `0`，留下 `xFF` 冒充变量）。
/// English: replaces every numeric literal with a space. **Order matters**: the radix prefixes run
///          before the decimal rule (otherwise `\d+` eats the leading `0` of `0xFF` and leaves `xFF`
///          masquerading as a variable).
String _withoutNumericLiterals(String source) => source
    .replaceAll(RegExp(r'0[xX][0-9a-fA-F_]+'), ' ')
    .replaceAll(RegExp(r'0[bB][01_]+'), ' ')
    .replaceAll(RegExp(r'0[oO][0-7_]+'), ' ')
    .replaceAll(RegExp(r'\d[\d_]*(?:\.\d*)?(?:[eE][+-]?\d+)?'), ' ')
    .replaceAll(RegExp(r'\.\d+'), ' ');

/// 中文：**拿得到值、所以不算自由变量**的那些名字。`i` 是虚数单位、`ans` 是上次答案，
///       两者都有值；其余是数学常量。**`x`/`y` 不在这里**——它们是自由变量，
///       那正是本轮要挡住的东西。
/// English: the names that **have a value and are therefore not free**. `i` is the imaginary unit and
///          `ans` is the previous answer, both valued; the rest are mathematical constants.
///          **`x`/`y` are not here** — they are free variables, which is exactly what this round
///          blocks.
const Set<String> _closureExemptNames = <String>{
  'pi', 'e', 'tau', 'phi', 'infinity', 'nan', 'i', 'ans', 'answer', 'result', 'value',
};

bool _looksLikeCalculationExpression(String source) {
  final text = source.trim().toLowerCase();
  if (text.isEmpty) return false;
  if (RegExp(r'[πτφ∞√∛¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]').hasMatch(text)) {
    return true;
  }
  if (RegExp(r'\b(?:pi|tau|phi|inf|infinity)\b').hasMatch(text)) {
    return true;
  }
  if (RegExp(
          r'\b(?:arcsin|arccos|arctan|atan2|sinh|cosh|tanh|sin|cos|tan|cot|sec|csc|sqrt|cbrt|ln|log|lg|abs|exp|floor|ceil|round|deg|rad|min|max|mod|ncr|npr|gcd|lcm|root|fact)\b')
      .hasMatch(text)) {
    return true;
  }
  if (RegExp(r'0[xbo][0-9a-f_]+').hasMatch(text)) return true;
  if (RegExp(r'\d(?:_?\d)*(?:\.\d*)?e[+-]?\d', caseSensitive: false)
      .hasMatch(text)) {
    return true;
  }
  return RegExp(r'\d').hasMatch(text) &&
      RegExp(r'[+\-*/^×÷()%!()]').hasMatch(text);
}
