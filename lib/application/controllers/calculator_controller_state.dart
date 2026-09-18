part of 'calculator_controller.dart';

/// 中文：撤销栈的深度上限。放在库的顶层是因为它是**静态**成员——mixin 放不下——而这个共享的上限
///       状态混入与编辑混入都要看到。
/// English: The undo stack's depth limit, at library level because it is a *static* member (a mixin
///          cannot carry one) and the state mixin and the editing mixin both need to see it.
const int _maxUndoDepth = 40;

mixin _CalculatorState on ChangeNotifier {
  // 中文：以下状态由 CalculatorController 自己的构造函数注入，**只能留在类里**（mixin 不能声明
  //       「没有初始值、由构造函数赋值」的 final 字段）。混入里的方法透过这组抽象访问器读它们。
  // English: This state is injected by CalculatorController's own constructor and therefore has to
  //          stay on the class (a mixin cannot declare a final field with no initialiser that the
  //          constructor assigns). The methods in this mixin read it through these abstract
  //          accessors.
  HistoryRepository get historyRepository;
  NotesRepository get notesRepository;
  SettingsRepository get settingsRepository;
  MathEngine get _engine;
  Duration get engineTimeout;
  LiveResultPolicy get liveResultPolicy;
  Duration get liveEvaluationDelay;
  Duration get liveEngineFollowUpDelay;
  AppSettings get _settings;
  set _settings(AppSettings value);
  String get angleMode;
  set angleMode(String value);
  // 中文：下面这些方法分散在另外三个混入里，而且**互相调用**（编辑叫求值、求值叫持久化、持久化又叫
  //       回编辑），所以在这里声明成抽象成员：三个混入都看得见，实现仍旧各自留在自己的混入里。
  // English: These methods live in the other three mixins and call each other (editing calls
  //          evaluation, evaluation calls persistence, persistence calls back into editing), so
  //          they are declared here as abstract members: all three mixins can see them, and each
  //          concrete implementation still lives in its own mixin.
  void evaluate();
  Future<CalculatorSubmitResult> submit();
  /// 中文：问一次引擎，带等待上限与异常兜底（实现留在求值混入里）。进制读数
  ///       （[_CalculatorBaseReadout.showBaseReadout]）要的正是这两样，所以它读的是同一个入口，
  ///       而不是自己再写一遍超时与 catch。
  /// English: ask the engine once, with a wait cap and exception handling (the implementation lives in
  ///          the evaluation mixin). The base read-out ([_CalculatorBaseReadout.showBaseReadout])
  ///          wants exactly those two things, so it reads the same entrance instead of writing its
  ///          own timeout and catch.
  Future<EngineReply> _askEngine(String expression);
  void _cancelLiveEvaluation();
  void _scheduleLiveEvaluation();
  Future<MathResult?> _submittedResult(String source, int generation);
  void _recordUndoSnapshot();
  void _markStateEdited();
  Future<void> _persistState();
  String _friendlyCalculationError(Object error);
  String _resolveAnswerReferences(String source);
  /// 中文：`Ans`/`last` 替换之后、任何人读它之前，把绑定了值的变量换成数（实现留在变量混入里）。
  ///       `_resolveAnswerReferences` 是它唯一的调用方，于是两条消费者（引擎路径与旧解析器路径）
  ///       看到的是同一个字符串——修复轮 7/8 反复吃过的那个亏。
  /// English: after the `Ans`/`last` substitution and before anyone reads it, replace bound variables
  ///          with their numbers (the implementation lives in the variables mixin).
  ///          `_resolveAnswerReferences` is its only caller, so both consumers (the engine path and the
  ///          legacy parser) see one string — the trap fix rounds 7 and 8 kept falling into.
  String _resolveVariableReferences(String source);
  Future<CalculatorSubmitResult> _saveSubmittedResult(
    String expression,
    String result,
  );
  _SubmittedCalculationSignature _submittedCalculationSignature(
    String expression,
    MathResult result,
  );
  /// 中文：在飞的引擎请求，值与它的超时定时器成对。存在的唯一理由是 [dispose] 能把它们一起收掉
  ///       ——见 [_askEngine]。
  /// English: Engine requests in flight, each paired with its timeout timer. They exist so that
  ///          [dispose] can collect both — see [_askEngine].
  final Map<Completer<EngineReply>, Timer> _engineCalls = {};

  String expression = '';

  /// 中文：当前结果的三形态（显示文本 / LaTeX / 十进制文本）。**数值消费者只许读 [resultDecimal]**：
  ///       精确引擎接入后显示文本是 `4√2` 这样的精确形式，对它做 `double.tryParse` 会静默失败。
  /// English: The current result in its three forms (display text / LaTeX / decimal text). Numeric
  ///          consumers may only read [resultDecimal]: once the exact engine lands, the display text
  ///          is an exact form such as `4√2`, and `double.tryParse` over it fails silently.
  MathResult _result = MathResult.zero;

  ExpressionSelection _selection = const ExpressionSelection.collapsed(0);
  double memoryValue = 0;
  bool hasError = false;
  String? errorMessage;
  _SubmittedCalculationSignature? _lastSavedSignature;
  String? _lastFiniteResult = '0';
  String? _ansSourceForExpression;
  String? _ansValueForExpression;

  /// 中文：绑定了值的变量（小写名字 → 十进制文本）。空表 = 两个变量都是自由的，于是含它们的表达式
  ///       仍旧是符号式——**这一点必须成立**：`x`/`y` 从上一轮起就是引擎认识的自由变量（`2x` 印成
  ///       `2x`），绑定是加法而不是改法。读它的是 [_CalculatorVariables]，写它的是撤销栈的恢复与
  ///       状态恢复（都通过 [_CalculatorSnapshot] 的 `variables` 那一格）。
  /// English: the variables that hold a value (lower-case name → decimal text). An empty map means both
  ///          variables are free, so an expression holding them is still symbolic — **and that has to
  ///          hold**: `x`/`y` have been free variables the engine knows since the previous round
  ///          (`2x` prints as `2x`), so binding is an addition rather than a change.
  ///          [_CalculatorVariables] reads it; the undo stack's restore and state restore write it
  ///          (both through the snapshot's `variables`).
  final Map<String, String> _variables = <String, String>{};

  /// 中文：**统计数据集**——一份十进制文本的**表**（与 `_variables` 同一种货币，理由也同一套）。
  ///       读它的是 [_CalculatorDataset]，写它的有三处：那个混因自己的四个方法、撤销栈的恢复、
  ///       以及状态恢复。[`kMaxDatasetValues`] 是它的上限（理由在那个常量上）。
  ///       为什么它不在表达式里（上一轮的做法）也不在引擎里：见 [_CalculatorDataset] 的类注释。
  /// English: **the statistics dataset** — a **list** of decimal text (the same currency as
  ///          `_variables`, and the same reasons). [_CalculatorDataset] reads it and three places
  ///          write it: that mixin's four methods, the undo stack's restore and the state restore.
  ///          [`kMaxDatasetValues`] is its cap (the reason is on that constant). Why it is neither in
  ///          the expression (last round's answer) nor inside the engine: see the class note on
  ///          [_CalculatorDataset].
  final List<String> _dataset = <String>[];
  Timer? _liveEvaluationTimer;

  /// 中文：边打边算那一发的引擎跟进定时器。与 [_liveEvaluationTimer]（32ms，旧解析器上屏）分开，
  ///       因为两者的性质不同：那一个是同步解析的合并窗口，这一个挡在「快速输入」和一队跨语言调用
  ///       之间。见 [kLiveEngineFollowUpDelay]。
  /// English: The engine follow-up timer for as-you-type evaluation. It is separate from
  ///          [_liveEvaluationTimer] (32 ms, the legacy result going on screen) because the two are
  ///          different in kind: that one coalesces a synchronous parse, this one stands between fast
  ///          typing and a queue of cross-language calls. See [kLiveEngineFollowUpDelay].
  Timer? _liveEngineTimer;

  /// 中文：边打边算的那一发引擎调用是否在飞。**这是「队不积压」的实现**：在飞上限恒为 1，再密的
  ///       输入只会把 [_liveEngineDirty] 立起来（「还欠一次」），不会排成第二发。
  /// English: Whether an as-you-type engine call is in flight. **This is what "no queue builds up"
  ///          is made of**: at most one call is ever outstanding, and denser typing merely raises
  ///          [_liveEngineDirty] ("one more is owed") instead of queueing a second one.
  bool _liveEngineInFlight = false;

  /// 中文：在飞期间表达式又变了（或者求值又发生过一次），于是回包落地之后还欠一次跟进。它是**一个
  ///       布尔，不是队列**——欠多少次都只记得「还欠一次」，且那一发问的永远是最新的表达式。
  /// English: The expression changed (or another evaluation happened) while a call was in flight, so
  ///          one more follow-up is owed once the reply lands. It is **a boolean, not a queue** — no
  ///          matter how many were owed, "one more is owed" is all that is remembered, and that one
  ///          always asks about the newest expression.
  bool _liveEngineDirty = false;

  bool _disposed = false;
  int _stateRevision = 0;
  int _restoreToken = 0;
  final List<_CalculatorSnapshot> _undoStack = [];
  final List<_CalculatorSnapshot> _redoStack = [];

  ExpressionSelection get selection => _selection;

  /// 中文：结果行的读数——没有精确形式时它就是整行，有精确形式时它是 `≈` 后面那一半。而那一半只在
  ///       这一次**也有十进制形态**时才存在（见 `resultDecimal`）：符号结果没有，于是它只是排版
  ///       失败时的降级文本。取整仍由 `formatNumber` 按 [AppSettings.precision] 完成，所以精度设置
  ///       管的正是这一半。
  /// English: The result line's reading — the whole line when there is no exact form, the half after
  ///          `≈` when there is one. That half exists only when this evaluation **also has a decimal
  ///          form** (see `resultDecimal`): a symbolic result has none, so there it is only the text a
  ///          failed typeset degrades to. `formatNumber` still does the rounding at
  ///          [AppSettings.precision], so the precision setting governs exactly this half.
  String get result => _result.displayText;

  /// 中文：结果行的 LaTeX 形态（不含 `$` 定界符），也就是引擎给出的**精确形式**。引擎未接入时
  ///       始终为空串，结果行整行纯文本；非空时结果行是否排版由 `CalculatorDisplay` 判定——还要
  ///       排得出来、且不是同一串十进制的另一种写法。
  /// English: The result line's LaTeX form (no `$` delimiters) — the **exact form** the engine
  ///          supplied. While no engine is involved it is always empty and the line stays plain
  ///          text; when it is not, `CalculatorDisplay` decides whether to typeset it — it must also
  ///          render, and be more than the same decimal written differently.
  String get resultTex => _result.displayTex;

  /// 中文：**结果的分数写法**（HiPER 的 `d/c` 那一颗键要的那一份），与 [resultTex] 是同一个已求值
  ///       结构的两次打印，值严格相等（见 `MathResult.fractionTex`）。空串表示这一次没有分数写法
  ///       ——引擎缺席、旧解析器上屏、或原生侧不认识这个字段；调用方照常工作，那一颗键于是是空操作。
  ///       与 [resultTex] 一样，**它绝不能被喂给任何数值消费者**。
  /// English: **the result's fraction spelling** (what HiPER's `d/c` key needs). It and [resultTex]
  ///          are two prints of one evaluated structure and carry strictly equal values (see
  ///          `MathResult.fractionTex`). An empty string means there is no fraction spelling this
  ///          time — no engine, the legacy parser on screen, or a native side that does not know the
  ///          field; callers keep working and that key is then a no-op. Like [resultTex] it must
  ///          **never** be fed to a numeric consumer.
  String get resultFractionTex => _result.fractionTex;

  /// 中文：**结果的带分数写法**（HiPER 结果格式菜单里 `Mixed number` 那一格要的东西），与
  ///       [resultFractionTex] 是同一个已求值结构的两次打印，值严格相等（见 `MathResult.mixedTex`）。
  ///       空串表示这一次没有带分数写法——引擎缺席、旧解析器上屏、原生侧不认识这个字段、或者这一份
  ///       结果在 `FRACTION_COMBINED` 下印出来的是排不出来的 `\num{…}`；调用方照常工作，那一格于是
  ///       不存在。与 [resultTex] 一样，**它绝不能被喂给任何数值消费者**。
  /// English: **the result's mixed-number spelling** (what HiPER's `Mixed number` cell in the result
  ///          format menu needs). It and [resultFractionTex] are two prints of one evaluated structure
  ///          and carry strictly equal values (see `MathResult.mixedTex`). An empty string means there
  ///          is none this time — no engine, the legacy parser on screen, a native side that does not
  ///          know the field, or a result whose `FRACTION_COMBINED` print is an untypesettable
  ///          `\num{…}`; callers keep working and the cell then does not exist. Like [resultTex] it
  ///          must **never** be fed to a numeric consumer.
  String get resultMixedTex => _result.mixedTex;

  /// 中文：**结果的度分秒写法**（HiPER 的 `DMS` 那一格要的东西）。它与 [resultDecimal] 描述的是
  ///       同一个数——引擎对**同一个近似结构**的两次打印（见 `MathResult.dmsText`）。空串表示这一次
  ///       没有这一种写法（没有引擎、旧解析器上屏、换算那一支）；调用方照常工作，那一颗键于是是
  ///       空操作。它是一串**写法**，与 [resultFractionTex] 一样**绝不能被喂给任何数值消费者**。
  /// English: **the result's DMS spelling** (what HiPER's `DMS` cell needs). It describes the same
  ///          number as [resultDecimal] — two renders of **one approximated structure** by the engine
  ///          (see `MathResult.dmsText`). An empty string means this spelling does not exist this time
  ///          (no engine, the legacy parser on screen, the conversion branch); callers keep working
  ///          and that key is then a no-op. It is a **spelling**, and like [resultFractionTex] it must
  ///          **never** be fed to a numeric consumer.
  String get resultDmsText => _result.dmsText;

  /// 中文：**这一份结果是不是引擎算出来的**——也就是说它身上会不会带着引擎那几份写法（精确 /
  ///       分数 / 带分数 / 度分秒），因为那四份只有引擎印得出来。判据是结果自己的形状字段
  ///       （`resultKind != notFromEngine`），**不是一个设置**：`表达式显示` 设成 `数学表达式` 只
  ///       关掉**边打边算**那一路，按 `=` 的提交路径照样问引擎，所以「设置是数学表达式」与「这一份
  ///       结果是旧解析器算的」是两句不同的话。
  ///
  ///       消费者只有一个：结果格式菜单用它把那几格灰着的原因写出来（`ResultPresentation.gapFor`）。
  ///       「本应用还没拿到引擎的写法」与「这一份结果没有这一格」在那里是两种不同的说法。
  /// English: **whether this result came from the engine** — i.e. whether it carries the engine's
  ///          spellings at all (exact / fraction / mixed / DMS), because only the engine prints those
  ///          four. The test is the result's own shape field (`resultKind != notFromEngine`), **not a
  ///          setting**: `表达式显示` set to `数学表达式` switches off the **as-you-type** path only;
  ///          the submit path (`=`) still asks the engine, so "the setting is `数学表达式`" and "this
  ///          result came from the legacy parser" are two different statements.
  ///
  ///          It has exactly one consumer: the result format menu uses it to write the reason those
  ///          cells are grey (`ResultPresentation.gapFor`). "This app has not been given the engine's
  ///          spelling" and "this result has no such cell" are two different sentences there.
  bool get resultCameFromEngine =>
      _result.resultKind != EngineResultKind.notFromEngine;

  /// 中文：结果的十进制形态——Ans/last、记忆寄存器、继续使用、历史去重与报告里的机器可读值都从
  ///       这里取。空串表示「这一次没有十进制形态」，调用方必须照常工作而不是去解析 [result]。
  /// English: The result's decimal form — Ans/last, the memory register, continue-with-result,
  ///          history de-duplication and the report's machine-readable value all take it from here.
  ///          An empty string means "no decimal form this time"; callers must keep working and must
  ///          not parse [result] instead.
  String get resultDecimal => _result.decimalText;

  int get cursorIndex => _selection.end;

  set cursorIndex(int value) {
    _selection = ExpressionSelection.collapsed(value).clamp(expression.length);
  }

  void updateSettings(AppSettings settings) {
    _markStateEdited();
    final angleChangedBySettings = angleMode == _settings.angleMode;
    _settings = settings;
    if (angleChangedBySettings) angleMode = settings.angleMode;
    evaluate();
    notifyListeners();
  }

  void setAngleMode(String mode) {
    if (angleMode == mode) return;
    _markStateEdited();
    _recordUndoSnapshot();
    angleMode = mode;
    evaluate();
    _persistState();
    notifyListeners();
  }

  void setSelection(ExpressionSelection value) {
    final next = value.clamp(expression.length);
    if (_selection == next) return;
    _markStateEdited();
    _selection = next;
    unawaited(_persistState());
    notifyListeners();
  }

  /// 中文：「继续使用」写回表达式的那份文本：**十进制形态**优先，没有十进制形态时才退回显示
  ///       文本（去掉千分位）——与拆分前的 `result.replaceAll(',', '')` 逐字节一致，因此现有输入
  ///       的行为一字未变；而精确引擎接入后，写回的是十进制近似，不是 `4√2`。
  /// English: The text "continue with result" writes back into the expression: the decimal form
  ///          first, the display text with its grouping separators stripped only when there is no
  ///          decimal form — byte-for-byte what `result.replaceAll(',', '')` produced before the
  ///          split, so every existing input behaves exactly as it did. Once the exact engine lands,
  ///          what gets written back is the decimal approximation rather than `4√2`.
  String get reusableResult {
    if (hasError || result == '等待输入') return '0';
    return _result.reusableText;
  }

  bool get canContinueWithResult =>
      !hasError && result.trim().isNotEmpty && result != '等待输入';

  bool get canSaveCurrentExpression =>
      expression.trim().isNotEmpty && canContinueWithResult;

  String get resultStatusTitle {
    if (hasError) return '表达式需要修正';
    if (expression.trim().isEmpty) return '当前值可继续使用';
    return '结果可继续使用';
  }

  String get resultStatusMessage {
    if (hasError) {
      final message = errorMessage?.trim();
      return message == null || message.isEmpty ? '请检查表达式后重试。' : message;
    }
    if (expression.trim().isEmpty) {
      return '当前值 $result 可复制或作为下一次计算起点。';
    }
    final reusable = reusableResult;
    return '继续使用会把 $reusable 写回表达式，Ans/last 仍可引用上一次有限结果。';
  }

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

}
