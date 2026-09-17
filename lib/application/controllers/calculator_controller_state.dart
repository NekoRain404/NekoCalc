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

  /// 中文：结果行的十进制读数——没有精确形式时它就是整行，有精确形式时它是 `≈` 后面那一半。
  ///       取整仍由 `formatNumber` 按 [AppSettings.precision] 完成，所以精度设置管的正是这一半。
  /// English: The result line's decimal reading — the whole line when there is no exact form, the
  ///          half after `≈` when there is one. `formatNumber` still does the rounding at
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
