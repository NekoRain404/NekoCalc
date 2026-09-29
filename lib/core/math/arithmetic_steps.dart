/// 中文：**算术分步——把 `1 + 2 × 3` 一步步算给用户看。**
///
///       这是对照表里**唯一一条明确的"HiPER 有、我们没有"**：
///      它的分步是**十进制 / 表达式模式**的（先乘后加那种），我们此前没有对应物。
///      而**求导分步那一套它没有**——两边的分步各缺一块，这一块补上。
///
///       **每一步印的是整条式子的下一个形态**，不是把子式单独拎出来：
///
///       ```
///       1 + 2 × 3
///       = 1 + 6        ← 先算 `2 × 3`
///       = 7
///       ```
///
///       **为什么是一棵可变的小树而不是直接走 `ExprNode`。** `ExprNode` 是不可变的
///       （那是它的优点，翻译器与求导器都靠它），而"每一步印整条式子"要求**在同一棵树上
///       逐次改写**。所以这里把表达式读成自己的小树、边算边改，**每一步之后就渲染一次**。
///
///       ⚠️ **它整条不碰引擎**，所以**单测就是全部证据**（与求导分步、进制换算同一条判据）。
///
///       ⚠️ **不支持的输入一律拒绝**：变量、函数、单位、后缀（`!`）都不在这里——
///       这一版的题目是"算术的运算顺序"，别的都会把"先算哪一步"变成另一个问题。
/// English: **arithmetic step by step — showing `1 + 2 × 3` being worked out.**
///
///          This is the comparison table's **one clear "HiPER has it, we do not"**: its step-by-step is
///          **decimal / expression-mode** (multiply before adding) and we had no counterpart. (**The
///          derivative steps are the block it lacks** — each side was missing one, and this fills ours in.)
///
///          **Every step prints the whole expression's next form**, not an isolated sub-expression (see the
///          example above).
///
///          **Why a small mutable tree rather than walking `ExprNode` directly.** `ExprNode` is immutable
///          (a virtue — the translator and the differentiator lean on it) while "print the whole expression
///          at each step" requires **rewriting one tree repeatedly**. So the expression is read into a
///          small tree of its own, evaluated and rewritten in place, and **rendered once after each step**.
///
///          ⚠️ **It does not touch the engine at all**, so **the unit tests are the whole proof** (the same
///          judgement as the derivative steps and base conversion).
///
///          ⚠️ **Unsupported input is refused**: variables, calls, units and postfixes (`!`) are not here —
///          this version's subject is "the order of arithmetic operations", and anything else turns "which
///          step comes first" into a different question.
library;

import 'ast/expression_ast_parser.dart';

/// 中文：一次分步的结果：[steps] 每一条是**整条式子的一个形态**（不含第一行），
///       [value] 是最终值；读不出或算不出时两者都是空 / `null`。
/// English: one run of the stepper: each entry of [steps] is **one form of the whole expression** (the first
///          line is not included) and [value] is the final value; both are empty / `null` when it cannot be
///          read or computed.
typedef ArithmeticSteps = ({List<String> steps, String? value});

/// 中文：把 [source] 一步步算出来。读不出、算不出、或者**本来就是一步**（只有一个数）时回 `null`。
/// English: works [source] out step by step. `null` when unreadable, uncomputable, or **already a single
///          step** (a lone number).
ArithmeticSteps? arithmeticSteps(String source) {
  final tree = const ExpressionAstParser().parse(source);
  if (tree is ParseErrorNode) return null;
  final item = _read(tree);
  if (item == null) return null;
  // 中文：**本来就只有一个数 ⇒ 没有步骤可说。**（这一条我第一版写反了：
  //       `item.value == null` 时返回 null，恰好把**所有真正的算式**都挡在外面，
  //       而"一个数"反而走了下去、给出一个空步骤表。）
  // English: **a lone number has no steps to show.** (I had this the wrong way round at first: returning
  //          `null` when `item.value == null` shut out **every real expression** while letting "a lone
  //          number" through with an empty step list.)
  if (item.value != null) return null;

  final steps = <String>[];
  final value = _reduce(item, item, steps, <String?>[null]);
  if (value == null) return null;
  return (steps: steps, value: _format(value));
}

/// 中文：小树的一个节点：要么已经有值（叶子，或已经算完的内部节点），要么还等着算。
/// English: one node of the small tree — either it already holds a value (a leaf, or an already-reduced
///          interior node) or it is still waiting.
class _Item {
  _Item.leaf(this.value) : op = null, left = null, right = null;
  _Item.binary(this.op, this.left, this.right) : value = null;

  num? value;
  final String? op;
  final _Item? left;
  final _Item? right;
}

/// 中文：从语法树读成小树；不支持的节点回 `null`（**不猜**）。
/// English: reads the syntax tree into the small tree; unsupported nodes return `null` (**nothing is
///          guessed**).
_Item? _read(ExprNode node) {
  switch (node) {
    case NumberNode(:final literal):
      final value = num.tryParse(literal.replaceAll('_', ''));
      return value == null ? null : _Item.leaf(value);
    case GroupNode(:final child):
      return _read(child);
    case UnaryNode(:final op, :final operand):
      if (op != '-' && op != '+') return null;
      final inner = _read(operand);
      if (inner == null) return null;
      // 中文：一元负号**当成一个待算的节点**（`0 - x`），这样它也会在分步里出现——
      //       用户看到 `-3` 变成 `0 - 3` 比看到它凭空消失更清楚。
      // English: a unary minus becomes **a node waiting to be computed** (`0 - x`) so it shows up in the
      //          steps too — seeing `-3` become `0 - 3` is clearer than seeing it vanish.
      return op == '-' ? _Item.binary('-', _Item.leaf(0), inner) : inner;
    case BinaryNode(:final op, :final left, :final right):
      if (!const <String>{'+', '-', '*', '/', '^'}.contains(op)) return null;
      final a = _read(left);
      final b = _read(right);
      return (a == null || b == null) ? null : _Item.binary(op, a, b);
    case ImplicitProductNode(:final left, :final right):
      final a = _read(left);
      final b = _read(right);
      return (a == null || b == null) ? null : _Item.binary('*', a, b);
    default:
      return null;
  }
}

/// 中文：**自底向上算，每算完一个节点就记一步**——这就是运算顺序本身。
///
///       子节点先算（后序遍历），所以 `1 + 2 × 3` 里 `2 × 3` 先被记下来；
///       而每记一步之前都**把整棵树重新渲染一遍**，于是印出来的就是整条式子的下一个形态。
/// English: **computes bottom-up, recording a step each time a node finishes** — which is the order of
///          operations itself. Children go first (post-order), so `2 × 3` is recorded before the addition in
///          `1 + 2 × 3`; and the whole tree is **re-rendered before each recording**, so what is printed is
///          the whole expression's next form.
num? _reduce(_Item item, _Item root, List<String> steps, List<String?> previous) {
  if (item.value != null) return item.value;
  final a = _reduce(item.left!, root, steps, previous);
  if (a == null) return null;
  final b = _reduce(item.right!, root, steps, previous);
  if (b == null) return null;
  final result = _apply(item.op!, a, b);
  if (result == null) return null;
  item.value = result;
  // 中文：**渲染的是整棵树的根，不是这个节点。** 我第一版渲染的是 `item`——而它的值刚刚被写上，
  //       于是每一步印出来的都是一个光秃秃的数（`6`），而不是 `1 + 6`。
  //       分步要的正是"整条式子的下一个形态"，所以**渲染必须从根出发**。
  // English: **the root is rendered, not this node.** My first version rendered `item`, whose value had just
  //          been written — so every step printed a bare number (`6`) instead of `1 + 6`. What the steps are
  //          for is "the whole expression's next form", so **rendering has to start at the root**.
  // 中文：**屏幕上没变化的"一步"不算一步。** `2 - -3` 里那个一元负号算完之后，
  //       整条式子渲染出来仍然是 `2 - -3`——因为 `-3` 前后长得一样。
  //       把它印成一步，用户看到的是**两行一模一样的式子**，那比少一行更糟：
  //       他以为自己看错了，或者以为程序卡住了。
  // English: **a "step" that changes nothing on screen is not a step.** After the unary minus in `2 - -3`
  //          is computed, the whole expression still renders as `2 - -3` — because `-3` looks the same
  //          before and after. Printing it would show **two identical lines**, which is worse than one line
  //          fewer: the user thinks they misread, or that it is stuck.
  final rendered = _render(root);
  if (rendered != previous.first) {
    steps.add(rendered);
    previous[0] = rendered;
  }
  return result;
}

num? _apply(String op, num a, num b) {
  switch (op) {
    case '+':
      return a + b;
    case '-':
      return a - b;
    case '*':
      return a * b;
    case '/':
      return b == 0 ? null : a / b;
    case '^':
      // 中文：**只做整数次幂**——`2^0.5` 要引进无理数，那是另一个问题（与因式分解拒绝无理根同理）。
      // English: **integer exponents only** — `2^0.5` would bring in irrationals, a different question (the
      //          same ruling that makes the factoriser refuse irrational roots).
      if (b != b.roundToDouble() || b.abs() > 64) return null;
      final exponent = b.toInt();
      if (exponent < 0) return null;
      var value = 1.0;
      for (var index = 0; index < exponent; index++) {
        value *= a;
      }
      return value;
    default:
      return null;
  }
}

/// 中文：渲染整棵树。**括号只加在必要的地方**（子节点的优先级低于父节点时）——
///       多一个括号不会算错，但会让"这一步做了什么"看着不清楚。
/// English: renders the whole tree. **Brackets only where needed** (when a child binds looser than its
///          parent) — an extra pair cannot make the arithmetic wrong, but it muddies "what did this step
///          do".
String _render(_Item item) {
  if (item.value != null) return _format(item.value!);
  final parent = _precedence(item.op!);
  return '${_renderChild(item.left!, parent)} ${item.op} '
      '${_renderChild(item.right!, parent)}';
}

String _renderChild(_Item child, int parentPrecedence) {
  final text = _render(child);
  if (child.value != null || _precedence(child.op!) >= parentPrecedence) {
    return text;
  }
  return '($text)';
}

int _precedence(String op) => switch (op) {
      '+' || '-' => 1,
      '*' || '/' => 2,
      _ => 3,
    };

/// 中文：印一个数——整数不带小数点（`6` 而不是 `6.0`），其余按最短可读形式。
/// English: prints a number — integers carry no decimal point (`6`, not `6.0`), the rest in the shortest
///          readable form.
String _format(num value) =>
    value == value.roundToDouble() && value.abs() < 1e15
        ? value.toInt().toString()
        : '$value';
