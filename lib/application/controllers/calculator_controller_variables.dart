part of 'calculator_controller.dart';

/// 中文：**两个变量（`x`/`y`）住在应用这一侧**——它们的值由这个混入持有，落盘、撤销、求值三条路
///       与记忆寄存器走的是同一套。为什么不是引擎那一侧（`Calculator` 的变量表）：
///
///       - **两套真相迟早不一致。** 引擎的表与应用的状态管理完全分离：它不参与撤销/重做、不参与
///         `_persistState`、不参与代际守卫，任何一条改了值而没有同步过去的路（撤销、状态恢复、
///         下一次求值）都会让「屏幕上那个数」与「引擎算出来的数」来自两个时刻。
///       - **数值消费者的口径只有一份**（硬性边界 5）。变量的值在这里是**十进制文本**
///         （[MathResult.decimalText] 那一类），与 `Ans`/`last`/记忆/继续使用读的是同一种东西；
///         放在引擎里，`x` 可以是一个单位、一个矩阵、一个未求值的式子，而这些都没有十进制形态。
///       - **可测**。引擎表在 `flutter test` 里根本不存在（没有原生侧），守住它的行为只能靠真机。
///
///       代价：值是**内存 + 设置表**里的状态，与 `calculator_memory` 一样随 `restoreState` 落盘
///       （见 `_CalculatorPersistence`）。
///
/// English: **The two variables (`x`/`y`) live on this app's side** — this mixin holds their values, and
///          persistence, undo and evaluation all treat them exactly as they treat the memory register.
///          Why not the engine's side (`Calculator`'s variable table):
///
///          - **Two truths drift sooner or later.** The engine's table is entirely separate from this
///            app's state management: it takes no part in undo/redo, in `_persistState`, or in the
///            generation guard, so any path that changes a value without mirroring it across (undo,
///            state restore, the next evaluation) leaves "the number on screen" and "the number the
///            engine computed" coming from two different moments.
///          - **Numeric consumers have exactly one currency** (hard boundary 5). A value here is
///            **decimal text** (the same thing `Ans`/`last`/memory/continue-with read); inside the
///            engine `x` could be a unit, a matrix or an unevaluated expression, none of which has a
///            decimal form at all.
///          - **It is testable.** The engine's table does not exist under `flutter test` (there is no
///            native side), so its behaviour could only be guarded on a real device.
///
///          The price: the values are state in memory plus the settings table, persisted with
///          `restoreState` like `calculator_memory` (see `_CalculatorPersistence`).
mixin _CalculatorVariables on _CalculatorState {
  /// 中文：**能存进变量里的那个值**：屏幕上这次结果的十进制文本，`null` 表示「这一次没有可存的数」。
  ///
  ///       判据用的是 [MathResult.decimalValueOf]——全应用唯一的「这段文本能不能当数字用」，
  ///       提交路径、粘贴路径、记忆寄存器都从它过（硬性边界 6：不给求值侧写第二份判据）。它同时
  ///       挡掉三样东西：没有十进制形态（符号结果、矩阵、复数、带单位）、不是有限数（`Infinity`/
  ///       `NaN`）、以及**下溢**（`2^-2000` 的 `9.3e-603` 解析出来是 `0.0`，那是一个静默的错值）。
  ///
  ///       为什么取**文本**而不是取出来的 `double`：文本里还留着 `double` 已经丢掉的信息，
  ///       而且它与 `Ans`/`last` 是同一个口径（[MathResult.decimalText] 的 doc 写着它是唯一允许
  ///       被解析的字段）。存 `formatNumber` 取整之后的那一份，会让 `x=1/3` 变成 `0.3333333333`、
  ///       `3x` 得到 `0.9999999999`——正是这一轮最要躲的那种「看起来合理的错值」。
  ///
  ///       取的是**屏幕上那个结果**（[_result]），不是重新解析一遍表达式：用户看得见的值才该是
  ///       被存下来的值。「按下去的时候屏幕上写着什么」因此与「存进去了什么」是同一句话。
  ///
  /// English: **The value that can be stored into a variable**: this evaluation's decimal text, or
  ///          `null` for "nothing storable this time".
  ///
  ///          The judgement is [MathResult.decimalValueOf] — the app's single "may this text be used as
  ///          a number", which the submit path, the paste path and the memory register all come
  ///          through (hard boundary 6: no second copy of an evaluator-facing judgement). It rejects
  ///          three things at once: no decimal form at all (symbolic results, matrices, complex
  ///          numbers, unit-carrying results), not a finite number (`Infinity` / `NaN`), and
  ///          **underflow** (`2^-2000`'s `9.3e-603` parses to `0.0`, a silent wrong value).
  ///
  ///          Why the **text** rather than the `double` read out of it: the text still carries what the
  ///          double has already lost, and it is the same currency `Ans`/`last` use ([MathResult]'s
  ///          `decimalText` doc says it is the only field that may ever be parsed). Keeping
  ///          `formatNumber`'s rounded copy instead would turn `x = 1/3` into `0.3333333333`, and `3x`
  ///          into `0.9999999999` — exactly the kind of plausible-looking wrong value this round is
  ///          built to avoid.
  ///
  ///          It takes **the result on screen** ([_result]) rather than re-parsing the expression: the
  ///          value the user can see is the value that should be stored. "What the screen says when the
  ///          button is pressed" and "what went in" are therefore the same sentence.
  String? get storableVariableValue {
    final text = _result.decimalText;
    return decimalValueOf(text) == null ? null : text;
  }

  /// 中文：这个变量现在绑着的值（小写名字查表）；没绑定时是 `null`。
  /// English: The value this variable is bound to (looked up by lower-case name); `null` when unbound.
  String? variableValue(String name) => _variables[name.toLowerCase()];

  /// 中文：把 [name] 绑到**屏幕上那个结果**上——计算器上 `STO` 那个动作。
  ///
  ///       没有可存的值时**拒绝并返回假**，调用方据此把按钮置灰（而不是存一个 0 或一个
  ///       `Infinity` 进去：那正是记忆寄存器以前吃过的亏）。值没有变化时也返回假——重复按同一个
  ///       按钮不该往撤销栈里塞一条空记录。
  ///
  ///       存下去之后**重新求值一次**：同一条表达式在绑定的前后是两个意思（`2x` 是符号式，绑定之后
  ///       是算术），屏幕上的结果必须跟着变。做法与 [setAngleMode] 逐字相同——`_markStateEdited`、
  ///       `_recordUndoSnapshot`、`evaluate`、`_persistState`、`notifyListeners` 五件事，顺序也一样。
  ///
  /// English: Bind [name] to **the result on screen** — the `STO` action on a calculator.
  ///
  ///          With nothing storable it **refuses and returns false**, and the caller greys the button
  ///          out (rather than storing a 0 or an `Infinity` — precisely the trap the memory register
  ///          fell into once). It also returns false when the value would not change: pressing the same
  ///          button twice must not push an empty row onto the undo stack.
  ///
  ///          After storing, the expression is **evaluated again**: one and the same expression means
  ///          two different things either side of a binding (`2x` is symbolic, and arithmetic once
  ///          bound), so the result on screen has to follow. The shape is byte for byte
  ///          [setAngleMode]'s — `_markStateEdited`, `_recordUndoSnapshot`, `evaluate`, `_persistState`,
  ///          `notifyListeners`, in that order.
  bool assignVariable(String name) {
    final key = name.toLowerCase();
    if (!kBindableVariableNames.contains(key)) return false;
    final value = storableVariableValue;
    if (value == null || _variables[key] == value) return false;
    _markStateEdited();
    _recordUndoSnapshot();
    _variables[key] = value;
    evaluate();
    unawaited(_persistState());
    notifyListeners();
    return true;
  }

  /// 中文：解绑——这个变量回到「自由变量」，含它的表达式于是又是符号式。没绑定时是空操作
  ///       （不写撤销栈、不落盘、不通知）。
  /// English: Unbind — the variable goes back to being free and an expression holding it is symbolic
  ///          again. A no-op while it is unbound (no undo row, no write to disk, no notification).
  void clearVariable(String name) {
    final key = name.toLowerCase();
    if (_variables.remove(key) == null) return;
    _markStateEdited();
    _recordUndoSnapshot();
    evaluate();
    unawaited(_persistState());
    notifyListeners();
  }

  /// 中文：**求值侧读的那一个**——`Ans`/`last` 替换完成之后、任何消费者看到之前，变量在这里变成数。
  ///       实现只有一条（[resolveVariableReferences]），翻译器与旧解析器因此看到同一份文本。
  /// English: **the one the evaluator reads** — after `Ans`/`last` have been substituted and before any
  ///          consumer sees the string, the variables become numbers here. There is only one
  ///          implementation ([resolveVariableReferences]), so the translator and the legacy parser
  ///          see one and the same text.
  @override
  String _resolveVariableReferences(String source) =>
      resolveVariableReferences(source, _variables);
}
