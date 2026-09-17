import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/math/expression_parser.dart';
import '../../core/math/math_engine.dart';
import '../../core/math/math_result.dart';
import '../../core/platform/qalculate_channel.dart';
import '../../core/platform/qalculate_math_engine.dart';
import '../../core/utils/number_formatter.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/usecases/calculator_paste_result.dart';
import '../../domain/usecases/calculator_save_result.dart';
import '../../domain/usecases/calculator_submit_result.dart';
import '../../domain/usecases/expression_editing.dart';
import '../app_settings.dart';
import 'expression_selection.dart';

/// 中文：计算器页面的应用层状态控制器，负责表达式编辑、实时计算、历史保存和状态恢复。
/// English: Application-layer controller for the calculator page; owns expression editing, live evaluation, history saving, and state restore.
class CalculatorController extends ChangeNotifier {
  CalculatorController({
    required this.historyRepository,
    required this.notesRepository,
    required this.settingsRepository,
    required AppSettings settings,
    MathEngine engine = const QalculateMathEngine(),
  })  : _settings = settings,
        _engine = engine,
        angleMode = settings.angleMode;

  final HistoryRepository historyRepository;
  final NotesRepository notesRepository;
  final SettingsRepository settingsRepository;

  /// 中文：求值引擎。默认就是真的那一个——生产接线不留「忘了注入于是功能静默不生效」的空档；
  ///       测试用替身换掉它，于是「引擎答不出来时回落」这条路径在 `flutter test` 里也能断言。
  /// English: The evaluation engine. The default is the real one, so production wiring has no gap
  ///          where a forgotten injection silently disables the feature; tests replace it with a
  ///          double, which makes the "the engine cannot answer, fall back" path assertable under
  ///          `flutter test`.
  final MathEngine _engine;

  AppSettings _settings;
  String expression = '';

  /// 中文：当前结果的三形态（显示文本 / LaTeX / 十进制文本）。**数值消费者只许读 [resultDecimal]**：
  ///       精确引擎接入后显示文本是 `4√2` 这样的精确形式，对它做 `double.tryParse` 会静默失败。
  /// English: The current result in its three forms (display text / LaTeX / decimal text). Numeric
  ///          consumers may only read [resultDecimal]: once the exact engine lands, the display text
  ///          is an exact form such as `4√2`, and `double.tryParse` over it fails silently.
  MathResult _result = MathResult.zero;

  String angleMode;
  ExpressionSelection _selection = const ExpressionSelection.collapsed(0);
  double memoryValue = 0;
  bool hasError = false;
  String? errorMessage;
  _SubmittedCalculationSignature? _lastSavedSignature;
  String? _lastFiniteResult = '0';
  String? _ansSourceForExpression;
  String? _ansValueForExpression;
  Timer? _liveEvaluationTimer;
  bool _disposed = false;
  int _stateRevision = 0;
  int _restoreToken = 0;
  final List<_CalculatorSnapshot> _undoStack = [];
  final List<_CalculatorSnapshot> _redoStack = [];
  static const int _maxUndoDepth = 40;

  ExpressionSelection get selection => _selection;

  /// 中文：结果行的纯文本形态——**显示路径（`CalculatorDisplay`）只读它**，因此这次拆分对视图
  ///       完全透明，屏幕上看到的东西与拆分前逐字符相同。
  /// English: The plain-text form of the result line — the display path (`CalculatorDisplay`) reads
  ///          only this, which is what makes the split invisible to the view: what reaches the
  ///          screen is character-for-character what reached it before.
  String get result => _result.displayText;

  /// 中文：结果行的 LaTeX 形态（不含 `$` 定界符）。引擎未接入时始终为空串，结果行继续按纯文本
  ///       渲染；自然排版的结果行会在下一步读它。
  /// English: The LaTeX form of the result line (no `$` delimiters). While no engine is involved it
  ///          is always empty and the result line keeps rendering as plain text; the typeset result
  ///          line will read it in the next step.
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

  @override
  void dispose() {
    _disposed = true;
    _liveEvaluationTimer?.cancel();
    super.dispose();
  }

  void updateSettings(AppSettings settings) {
    _markStateEdited();
    final angleChangedBySettings = angleMode == _settings.angleMode;
    _settings = settings;
    if (angleChangedBySettings) angleMode = settings.angleMode;
    evaluate();
    notifyListeners();
  }

  Future<void> restoreIfEnabled() async {
    if (!_settings.restoreState) return;
    final token = ++_restoreToken;
    final revisionAtStart = _stateRevision;
    await _restorePersistedState(
      restoreToken: token,
      revisionAtStart: revisionAtStart,
    );
  }

  Future<void> reloadSettingsAndRestore() async {
    final token = ++_restoreToken;
    final revisionAtStart = _stateRevision;
    final settings = await settingsRepository.load();
    if (_disposed || token != _restoreToken) return;
    _settings = AppSettings.fromMap(settings);
    if (!_settings.restoreState) {
      if (revisionAtStart == _stateRevision) {
        angleMode = _settings.angleMode;
        _clearEditingHistory();
      }
      evaluate();
      notifyListeners();
      return;
    }
    final restored = await _restorePersistedState(
      loadedSettings: settings,
      restoreToken: token,
      revisionAtStart: revisionAtStart,
    );
    if (!restored && !_disposed && token == _restoreToken) {
      evaluate();
      notifyListeners();
    }
  }

  Future<bool> _restorePersistedState({
    Map<String, String>? loadedSettings,
    required int restoreToken,
    required int revisionAtStart,
  }) async {
    final settings = loadedSettings ?? await settingsRepository.load();
    if (_disposed ||
        restoreToken != _restoreToken ||
        revisionAtStart != _stateRevision) {
      return false;
    }
    expression = settings['calculator_expression'] ?? '';
    _selection = _restoredSelection(settings, expression.length);
    _result = _restoredResult(settings);
    angleMode = settings['calculator_angle'] ?? _settings.angleMode;
    memoryValue = double.tryParse(settings['calculator_memory'] ?? '') ?? 0;
    _lastFiniteResult =
        _result.decimalText.isEmpty ? null : _result.decimalText;
    if (expression.isNotEmpty) evaluate();
    _clearEditingHistory();
    if (_disposed) return false;
    notifyListeners();
    return true;
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
      _liveEvaluationTimer?.cancel();
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
    final nextPrefix = _wrapTrailingValue(expressionBeforeCursor, name);
    _replaceAroundCursor(nextPrefix);
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
    final nextPrefix =
        _wrapTrailingValue(expressionBeforeCursor, name, binary: true);
    _replaceAroundCursor(nextPrefix);
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

  void evaluate() {
    if (expression.trim().isEmpty) {
      _result = MathResult.zero;
      hasError = false;
      errorMessage = null;
      return;
    }
    try {
      _result = _calculateResult(expression);
      hasError = false;
      errorMessage = null;
    } catch (error) {
      _result = MathResult.pending;
      hasError = true;
      errorMessage = _friendlyCalculationError(error);
    }
  }

  /// 中文：装上一次求值的三形态结果。**这是引擎接入时唯一的写入点**；在引擎接到求值路径之前，
  ///       只有测试用它来构造「精确形态与十进制形态并存」的结果。
  /// English: Install one evaluation's three-form result. This is the single write point the engine
  ///          will use when it is wired in; until the engine reaches the evaluation path, only tests
  ///          use it, to build a result whose exact and decimal forms coexist.
  ///
  /// 中文：`_lastFiniteResult` 在这里与十进制形态保持一致——没有十进制形态时置空，而不是退回显示
  ///       文本，否则 `Ans` 会把 `4√2` 当成数字塞进表达式。
  /// English: `_lastFiniteResult` is kept in step with the decimal form here — it becomes null when
  ///          there is no decimal form rather than falling back to the display text, which would make
  ///          `Ans` splice `4√2` into the expression as if it were a number.
  @visibleForTesting
  void applyMathResult(MathResult value) {
    _result = value;
    _lastFiniteResult = value.decimalText.isEmpty ? null : value.decimalText;
    hasError = false;
    errorMessage = null;
    notifyListeners();
  }

  Future<CalculatorSubmitResult> submit() async {
    if (expression.trim().isEmpty) {
      return const CalculatorSubmitResult.emptyExpression();
    }
    _markStateEdited();
    _liveEvaluationTimer?.cancel();
    try {
      final submittedExpression = expression;
      // 中文：只有「按下等号」这条路径问引擎。边打边算（`evaluate()`）一行未动，仍然完全走旧的
      //       同步解析器——把实时路径也搬过去的时序风险留给下一步。
      // English: Only "pressed =" asks the engine. As-you-type evaluation (`evaluate()`) is
      //          untouched and still runs entirely on the legacy synchronous parser; the timing
      //          risk of moving the live path stays out of this step.
      _result = await _submittedResult(submittedExpression);
      hasError = false;
      errorMessage = null;
      final signature =
          _submittedCalculationSignature(submittedExpression, _result);
      final duplicate = _lastSavedSignature == signature;
      if (!_settings.autoSaveHistory) {
        // 中文：状态持久化不影响当前交互，失败也不应打断计算。
        // English: State persistence must not block the current interaction.
        unawaited(_persistState());
        notifyListeners();
        return CalculatorSubmitResult.calculated(
          expression: submittedExpression,
          result: result,
        );
      }
      if (duplicate) {
        unawaited(_persistState());
        notifyListeners();
        return CalculatorSubmitResult.historySkippedDuplicate(
          expression: submittedExpression,
          result: result,
        );
      }
      if (_settings.autoSaveHistory) {
        // 中文：先刷新结果，再后台写 SQLite，等号响应不被磁盘 IO 阻塞。
        // English: Show the result first and save to SQLite in the background so "=" stays instant.
        _lastSavedSignature = signature;
        notifyListeners();
        return _saveSubmittedResult(submittedExpression, result);
      }
      notifyListeners();
      return CalculatorSubmitResult.calculated(
        expression: submittedExpression,
        result: result,
      );
    } catch (error) {
      final message = _friendlyCalculationError(error);
      // 中文：错误文案只是显示文本，没有十进制形态——数值消费者据此不再解析它。
      // English: An error message is display text only and carries no decimal form, which is what
      //          stops numeric consumers from parsing it.
      _result = MathResult(displayText: message);
      hasError = true;
      errorMessage = message;
      notifyListeners();
      return CalculatorSubmitResult.invalidExpression(message);
    }
  }

  Future<CalculatorSaveNoteResult> saveToNote() async {
    if (expression.trim().isEmpty) {
      return const CalculatorSaveNoteResult.emptyExpression();
    }
    _markStateEdited();
    _liveEvaluationTimer?.cancel();
    try {
      _result = _calculateResult(expression);
      hasError = false;
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      final message = _friendlyCalculationError(error);
      _result = MathResult(displayText: message);
      hasError = true;
      errorMessage = message;
      notifyListeners();
      return CalculatorSaveNoteResult.invalidExpression(message);
    }

    try {
      final noteId = await notesRepository.create(
        title: '计算结果',
        body: noteBody(),
        description: '由计算器保存，${_angleModeLabel()}',
      );
      if (noteId <= 0) return const CalculatorSaveNoteResult.notWritten();
      unawaited(_persistState());
      return CalculatorSaveNoteResult.saved(noteId);
    } catch (error) {
      return CalculatorSaveNoteResult.failed(error);
    }
  }

  void memoryAdd() {
    _markStateEdited();
    _recordUndoSnapshot();
    memoryValue += _currentNumericValue();
    unawaited(_persistState());
    notifyListeners();
  }

  void memorySubtract() {
    _markStateEdited();
    _recordUndoSnapshot();
    memoryValue -= _currentNumericValue();
    unawaited(_persistState());
    notifyListeners();
  }

  void memoryRecall() {
    _markStateEdited();
    _recordUndoSnapshot();
    // 中文：记忆寄存器本身就是一个 double，写回表达式的是十进制文本（`formatNumber` 默认不加
    //       千分位），因此这一步与结果的三形态无关，也不需要经过显示文本。
    // English: The memory register is a plain double and what it writes back into the expression is
    //          decimal text (`formatNumber` adds no grouping separators by default), so this step is
    //          independent of the result's three forms and never touches the display text.
    expression = formatNumber(
      memoryValue,
      precision: _settings.precision,
    );
    cursorIndex = expression.length;
    evaluate();
    unawaited(_persistState());
    notifyListeners();
  }

  void memoryClear() {
    if (memoryValue == 0) return;
    _markStateEdited();
    _recordUndoSnapshot();
    memoryValue = 0;
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

  void undo() {
    if (_undoStack.isEmpty) return;
    _markStateEdited();
    _liveEvaluationTimer?.cancel();
    _redoStack.add(_snapshot());
    _restoreSnapshot(_undoStack.removeLast());
    unawaited(_persistState());
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _markStateEdited();
    _liveEvaluationTimer?.cancel();
    _undoStack.add(_snapshot());
    _restoreSnapshot(_redoStack.removeLast());
    unawaited(_persistState());
    notifyListeners();
  }

  String copyText() => _resultReportText();

  String noteBody() => _resultReportText(savedAt: DateTime.now());

  /// 中文：**提交路径**（只有「按下等号」会走到这里）的结果来源：先问引擎，问不到就回落旧解析器。
  ///
  ///       回落是硬要求，且引擎的失败对用户完全不可见：引擎未加载、没有原生侧、被中止、超时、
  ///       解析失败，用户看到的都是**今天那条结果或那条错误**，一字不差。所以这里接受引擎结果的
  ///       条件很紧——必须是一个**有限十进制**：
  ///
  ///       - 引擎没有十进制形态（`1 m` 这类带单位的结果）：回落到旧解析器；
  ///       - 十进制形态解析不出数字（`infinity`、符号表达式）：同样回落，于是 `1/0` 仍然是
  ///         今天那条「结果不是有限数值」，而不是一个看起来像结果的 `无效`。
  ///
  ///       表达式先过 [_resolveAnswerReferences]，和旧路径一样：引擎不认识 `Ans`/`last`，问它
  ///       之前必须先换成十进制数值，否则它会把 `ans` 当成一个未知变量。回落分支故意把**原始**
  ///       表达式交给 [_calculateResult]，让它自己做同一件事——两次解析结果相同（`_ansValue…`
  ///       记下的正是第一次用的那个值），而跳过它会让 `_ansSource…` 被清空。
  ///
  /// English: The result source for the *submit path* (only "pressed =" reaches it): ask the engine
  ///          first, fall back to the legacy parser when it cannot answer.
  ///
  ///          The fallback is a hard requirement, and the engine's failure is invisible to the
  ///          user: engine not loaded, no native side, aborted, timed out or failed to parse — the
  ///          user sees *today's* result or *today's* error, character for character. So the
  ///          condition for accepting the engine's answer is deliberately tight: it must be a
  ///          *finite decimal*:
  ///
  ///          - the engine has no decimal form (a result carrying a unit, say `1 m`): fall back;
  ///          - the decimal form does not parse into a number (`infinity`, a symbolic expression):
  ///            fall back too, so `1/0` still produces today's "result is not finite" rather than a
  ///            `无效` that looks like a result.
  ///
  ///          The expression goes through [_resolveAnswerReferences] first, exactly as on the legacy
  ///          path: the engine does not know `Ans`/`last`, so they must be substituted before it is
  ///          asked, or it would treat `ans` as an unknown variable. The fallback branch hands the
  ///          *original* expression to [_calculateResult] on purpose, letting it do the same thing
  ///          itself — both resolutions produce the same string (`_ansValue…` holds exactly the
  ///          value the first one used), while skipping it would clear `_ansSource…`.
  Future<MathResult> _submittedResult(String source) async {
    final resolvedSource = _resolveAnswerReferences(source);
    final reply = await _askEngine(resolvedSource);
    final engineResult = reply.result;
    final value = engineResult?.decimalValue;
    if (reply.ok && engineResult != null && value != null && value.isFinite) {
      // 中文：`_lastFiniteResult` 与十进制形态保持一致，规则与 [applyMathResult] 相同——十进制
      //       形态非空（`decimalValue` 非空已经保证了这一点），于是 `Ans`/`last` 用的是引擎的
      //       精确值，而不是显示取整后的那一份。
      // English: `_lastFiniteResult` stays in step with the decimal form, the same rule as
      //          [applyMathResult] — the decimal form is non-empty (which `decimalValue` being
      //          non-null already guarantees), so `Ans`/`last` resolve to the engine's accurate
      //          value rather than the display-rounded one.
      _lastFiniteResult = engineResult.decimalText;
      return _withDisplayRounding(engineResult, value);
    }
    // 中文：回落对用户不可见（这是要求），所以必须留下一条日志——否则「引擎其实一次都没答上来」
    //       在设备上和「引擎工作正常」长得一模一样。
    // English: The fallback is invisible to the user (that is the requirement), so it has to leave a
    //          log line behind — otherwise "the engine never answered once" looks exactly like "the
    //          engine works fine" on a device.
    debugPrint(
      '$qalculateLogTag 引擎没有可用结果，提交路径回落到旧解析器: '
      '${reply.error ?? '引擎给出的十进制形态不可用'}',
    );
    return _calculateResult(source);
  }

  /// 中文：问一次引擎。**引擎抛出来的东西在这里停住**——[MathEngine] 的契约要求实现不抛异常，
  ///       但提交路径不能把「实现有没有守约」当成本钱：守约失败时回落到旧解析器，而不是让一个
  ///       只在设备上出现的异常变成用户可见的错误。
  /// English: Ask the engine once. Anything it throws stops here — the [MathEngine] contract says
  ///          implementations must not throw, but the submit path cannot stake its behaviour on the
  ///          implementation keeping that promise: a broken promise falls back to the legacy parser
  ///          instead of turning into a user-visible error that only ever appears on a device.
  Future<EngineReply> _askEngine(String expression) async {
    try {
      return await _engine.evaluate(expression, angleMode: angleMode);
    } catch (error) {
      return EngineReply.failure('engine_threw: $error');
    }
  }

  /// 中文：把引擎的结果变成屏幕上的结果。引擎的十进制形态是**未取整**的（16 位有效数字），显示
  ///       形态仍然由 `formatNumber` 按 `AppSettings.precision`（小数位数）取整——取整只有这一处
  ///       实现，边打边算与提交路径共用，用户在设置里选的位数对两条路径含义完全相同。引擎负责
  ///       算得准，Dart 负责显示成什么样。
  /// English: Turns the engine's result into the one on screen. The engine's decimal form is
  ///          *unrounded* (16 significant digits) while the display form still comes from
  ///          `formatNumber` at `AppSettings.precision` (a count of decimal places) — rounding has
  ///          exactly one implementation, shared by as-you-type and submit, so the digit count the
  ///          user picked means the same thing on both paths. The engine computes accurately; Dart
  ///          decides what it looks like.
  MathResult _withDisplayRounding(MathResult engineResult, double value) {
    return MathResult(
      displayText: formatNumber(
        value,
        precision: _settings.precision,
        groupThousands: _settings.groupThousands,
      ),
      displayTex: engineResult.displayTex,
      decimalText: engineResult.decimalText,
    );
  }

  /// 中文：旧求值器的唯一出口——它只产出一个 `double`，所以三形态里的 LaTeX 是空的，而显示文本
  ///       同时也是十进制文本。这是引擎缺席时（以及引擎答不出来时）用的那一条路。
  /// English: The legacy evaluator's only exit. It produces a bare `double`, so the LaTeX form is
  ///          empty and the display text doubles as the decimal text. This is the path used while
  ///          the engine is absent — and whenever it cannot answer.
  MathResult _calculateResult(String source) {
    final resolvedSource = _resolveAnswerReferences(source);
    final value =
        ExpressionParser(resolvedSource, degreeMode: angleMode == 'DEG')
            .parse();
    if (!value.isFinite) {
      throw const FormatException('Result is not finite');
    }
    final formatted = formatNumber(
      value,
      precision: _settings.precision,
      groupThousands: _settings.groupThousands,
    );
    final mathResult = MathResult.legacy(formatted);
    _lastFiniteResult =
        mathResult.decimalText.isEmpty ? null : mathResult.decimalText;
    return mathResult;
  }

  String _resultReportText({DateTime? savedAt}) {
    final lines = <String>[
      if (expression.trim().isEmpty) '当前值: $result' else '表达式: $expression',
      if (expression.trim().isNotEmpty) '结果: $result',
      // 中文：显示文本本身不是可解析的十进制时（引擎给出 `4√2` 这类精确形式），报告补一行十进制：
      //       粘贴路径优先读它，否则「复制结果再粘回计算器」这条往返会在精确形式上悄悄断掉。旧求值
      //       器下这一行永不出现，报告文本与拆分前逐字符一致。
      // English: When the display text is not itself a parseable decimal (the engine's exact forms
      //          such as `4√2`), the report adds a decimal line: the paste path reads it first, or
      //          the copy-a-result-and-paste-it-back round trip would quietly break on exact forms.
      //          Under the legacy evaluator this line never appears, so the report text stays
      //          character-for-character what it was.
      if (_result.decimalText.isNotEmpty && !_result.displayTextIsParseable)
        '十进制: ${_result.decimalText}',
      '状态: $resultStatusTitle',
      resultStatusMessage,
      '角度模式: ${_angleModeLabel()}',
      if (memoryValue != 0)
        '记忆值: ${formatNumber(memoryValue, precision: _settings.precision, groupThousands: _settings.groupThousands)}',
      if (hasError && errorMessage != null) '错误: $errorMessage',
      if (savedAt != null) '保存时间: ${_formatReportTime(savedAt)}',
    ];
    return lines.join('\n');
  }

  String _angleModeLabel() => angleMode == 'DEG' ? '角度 DEG' : '弧度 RAD';

  String _formatReportTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _friendlyCalculationError(Object error) {
    final message = error.toString().replaceFirst('FormatException: ', '');
    if (message.contains('Missing )')) return '缺少右括号';
    if (message.contains('Expected number')) return '需要输入数字';
    if (message.contains('Unexpected token')) return '存在无法识别的内容';
    if (message.contains('needs (')) return '函数需要括号';
    if (message.contains('Unknown function')) return '未知函数';
    if (message.contains('Factorial needs')) return '阶乘只支持 0 到 170 的整数';
    if (message.contains('Root degree cannot be 0')) return '根指数不能为 0';
    if (message.contains('Even root of negative')) return '负数不能开偶次根';
    if (message.contains('Result is not finite')) return '结果不是有限数值';
    return '表达式错误';
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

  Future<void> _persistState() async {
    if (!_settings.restoreState) return;
    await settingsRepository.setMany({
      'calculator_expression': expression,
      'calculator_result': result,
      // 中文：三形态一起落盘，否则重启后精确形式会丢掉十进制形态，Ans/last 又变成静默失效。
      // English: Land all three forms together; otherwise the exact form survives a restart without
      //          its decimal form and Ans/last silently stop resolving again.
      'calculator_result_tex': _result.displayTex,
      'calculator_result_decimal': _result.decimalText,
      'calculator_angle': angleMode,
      'calculator_memory': memoryValue.toString(),
      'calculator_cursor': cursorIndex.toString(),
      'calculator_selection_start': selection.start.toString(),
      'calculator_selection_end': selection.end.toString(),
    });
  }

  MathResult _restoredResult(Map<String, String> settings) {
    final displayText = settings['calculator_result'] ?? '0';
    // 中文：判别依据是**键在不在**，不是值空不空——`?? ''` 分不清两种空：
    //       「拆分之前存下的旧行」（没有这个键，十进制形态要从显示文本推导）与「十进制形态就是
    //       故意为空的新行」（键在、值是空串，代表引擎这一次没有给出十进制形态）。把它们混成
    //       一种，空十进制会在重启后被从显示文本重新推导出来——一个引擎从没给过的数字，于是
    //       `Ans`/`last` 又开始引用它。这个类型的全部意义就是「空表示没有十进制形态」，这条
    //       不变量必须能活过一次重启。
    // English: The discriminator is whether the *key exists*, not whether the value is empty —
    //          `?? ''` cannot tell two different empties apart: a row written before the split
    //          (no such key, so the decimal form is derived from the display text) and a new row
    //          whose decimal form is deliberately empty (the key is there with an empty value,
    //          meaning the engine produced no decimal form this time). Collapsing them re-derives
    //          the decimal from the display text after a restart — a number the engine never
    //          produced — and `Ans`/`last` start resolving from it again. The whole point of this
    //          type is that an empty string means "no decimal form"; that invariant has to survive
    //          a restart.
    final hasDecimalField = settings.containsKey('calculator_result_decimal');
    return MathResult(
      displayText: displayText,
      displayTex: settings['calculator_result_tex'] ?? '',
      decimalText: hasDecimalField
          ? (settings['calculator_result_decimal'] ?? '')
          : MathResult.decimalTextOf(displayText),
    );
  }

  ExpressionSelection _restoredSelection(
    Map<String, String> settings,
    int expressionLength,
  ) {
    final start = int.tryParse(settings['calculator_selection_start'] ?? '');
    final end = int.tryParse(settings['calculator_selection_end'] ?? '');
    if (start != null && end != null) {
      return ExpressionSelection(start, end).clamp(expressionLength);
    }
    return ExpressionSelection.collapsed(
      _restoredCursorIndex(settings['calculator_cursor'], expressionLength),
    );
  }

  int _restoredCursorIndex(String? value, int expressionLength) {
    return (int.tryParse(value ?? '') ?? expressionLength)
        .clamp(0, expressionLength);
  }

  Future<CalculatorSubmitResult> _saveSubmittedResult(
    String expression,
    String result,
  ) async {
    try {
      final historyId = await historyRepository.saveCalculation(
          expression: expression, result: result);
      await _persistStateSafely();
      if (historyId <= 0) {
        _clearLastSavedSignature();
        return CalculatorSubmitResult.historyNotWritten(
          expression: expression,
          result: result,
        );
      }
      return CalculatorSubmitResult.historySaved(
        expression: expression,
        result: result,
        historyId: historyId,
      );
    } catch (error) {
      // 中文：后台保存失败时释放去重缓存，用户下次按等号仍可重试保存。
      // English: Clear duplicate guards on background save failure so the next submit can retry.
      _clearLastSavedSignature();
      await _persistStateSafely();
      return CalculatorSubmitResult.historyFailed(
        expression: expression,
        result: result,
        error: error,
      );
    }
  }

  Future<void> _persistStateSafely() async {
    try {
      await _persistState();
    } catch (_) {}
  }

  /// 中文：记忆寄存器要加/减的数值。表达式能算就用表达式，否则用**结果的十进制形态**；两者都
  ///       没有时是 0（与拆分前一致：那时解析不了显示文本同样得到 0）。绝不解析显示文本。
  /// English: The value the memory register adds or subtracts. The expression wins when it
  ///          evaluates; otherwise the result's *decimal form* is used, and 0 when neither is
  ///          available (the same as before the split, where an unparseable display text also
  ///          yielded 0). The display text is never parsed.
  double _currentNumericValue() {
    try {
      if (expression.trim().isNotEmpty) {
        return ExpressionParser(_resolveAnswerReferences(expression),
                degreeMode: angleMode == 'DEG')
            .parse();
      }
      return _result.decimalValue ?? 0;
    } catch (_) {
      return _result.decimalValue ?? 0;
    }
  }

  void _clearLastSavedSignature() {
    _lastSavedSignature = null;
  }

  _SubmittedCalculationSignature _submittedCalculationSignature(
    String expression,
    MathResult result,
  ) {
    return _SubmittedCalculationSignature(
      normalizedExpression: ExpressionParser.normalizeExpressionInput(
        _expressionForSubmitSignature(expression),
      ),
      // 中文：去重键取十进制形态（缺失时退回显示文本），与拆分前的
      //       `result.replaceAll(',', '').trim()` 同值。
      // English: The de-duplication key takes the decimal form (the display text when it is
      //          missing), the same value as `result.replaceAll(',', '').trim()` before the split.
      result: result.reusableText,
      angleMode: angleMode,
    );
  }

  String _expressionForSubmitSignature(String source) {
    final answer = _isSameAnswerEditingSession(source)
        ? _ansValueForExpression
        : _lastFiniteResult;
    if (answer == null || answer.isEmpty) return source;
    final replacement = _answerReplacement(answer);
    return source.replaceAllMapped(
      RegExp(r'\b(?:ans|last)\b', caseSensitive: false),
      (_) => replacement,
    );
  }

  void _markStateEdited() {
    _stateRevision++;
  }

  void _clearEditingHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _clearLastSavedSignature();
    _ansSourceForExpression = null;
    _ansValueForExpression = null;
  }

  String _resolveAnswerReferences(String source) {
    if (!_hasAnswerReference(source)) {
      _ansSourceForExpression = null;
      _ansValueForExpression = null;
      return source;
    }
    final lastAnswer = _isSameAnswerEditingSession(source)
        ? _ansValueForExpression
        : _lastFiniteResult;
    if (lastAnswer == null || lastAnswer.isEmpty) return source;
    _ansSourceForExpression = source;
    _ansValueForExpression = lastAnswer;
    final replacement = _answerReplacement(lastAnswer);
    return source.replaceAllMapped(
      RegExp(r'\b(?:ans|last)\b', caseSensitive: false),
      (_) => replacement,
    );
  }

  bool _hasAnswerReference(String source) {
    return RegExp(r'\b(?:ans|last)\b', caseSensitive: false).hasMatch(source);
  }

  bool _isSameAnswerEditingSession(String source) {
    final previous = _ansSourceForExpression;
    if (previous == null || _ansValueForExpression == null) return false;
    final previousToken = _answerTokenIn(previous);
    final currentToken = _answerTokenIn(source);
    if (previousToken == null || currentToken == null) return false;
    return previousToken == currentToken;
  }

  String? _answerTokenIn(String source) {
    final match =
        RegExp(r'\b(?:ans|last)\b', caseSensitive: false).firstMatch(source);
    return match?.group(0)?.toLowerCase();
  }

  String _answerReplacement(String value) {
    return value.startsWith('-') ? '($value)' : value;
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

  void _scheduleLiveEvaluation() {
    _liveEvaluationTimer?.cancel();
    // 中文：快速输入时合并实时解析，输入显示立即更新，结果稍后统一刷新。
    // English: Debounce live parsing during fast typing; input updates immediately and results refresh together.
    _liveEvaluationTimer = Timer(const Duration(milliseconds: 32), () {
      if (_disposed) return;
      evaluate();
      unawaited(_persistState());
      notifyListeners();
    });
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

  void _replaceAroundCursor(String prefix) {
    expression = prefix + expressionAfterCursor;
    cursorIndex = prefix.length;
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

  String _wrapTrailingValue(String current, String name,
      {bool binary = false}) {
    final suffix = binary ? ',' : ')';
    if (current.isEmpty || _endsWithOpenInput(current)) return '$current$name(';
    final range = _trailingValueRange(current);
    if (range == null) return '$current$name(';
    final value = current.substring(range.start, range.end);
    return '${current.substring(0, range.start)}$name($value$suffix';
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

class _CalculatorSnapshot {
  const _CalculatorSnapshot({
    required this.expression,
    required this.result,
    required this.angleMode,
    required this.selection,
    required this.memoryValue,
    required this.hasError,
    required this.errorMessage,
    required this.lastFiniteResult,
    required this.ansSourceForExpression,
    required this.ansValueForExpression,
  });

  final String expression;

  /// 中文：整份三形态结果。`==` 依赖 [MathResult] 的值相等，撤销栈的去重才仍然成立。
  /// English: The whole three-form result. `==` leans on [MathResult]'s value equality, which is
  ///          what keeps the undo stack's de-duplication working.
  final MathResult result;
  final String angleMode;
  final ExpressionSelection selection;
  final double memoryValue;
  final bool hasError;
  final String? errorMessage;
  final String? lastFiniteResult;
  final String? ansSourceForExpression;
  final String? ansValueForExpression;

  @override
  bool operator ==(Object other) {
    return other is _CalculatorSnapshot &&
        other.expression == expression &&
        other.result == result &&
        other.angleMode == angleMode &&
        other.selection == selection &&
        other.memoryValue == memoryValue &&
        other.hasError == hasError &&
        other.errorMessage == errorMessage &&
        other.lastFiniteResult == lastFiniteResult &&
        other.ansSourceForExpression == ansSourceForExpression &&
        other.ansValueForExpression == ansValueForExpression;
  }

  @override
  int get hashCode => Object.hash(
        expression,
        result,
        angleMode,
        selection,
        memoryValue,
        hasError,
        errorMessage,
        lastFiniteResult,
        ansSourceForExpression,
        ansValueForExpression,
      );
}

class _SubmittedCalculationSignature {
  const _SubmittedCalculationSignature({
    required this.normalizedExpression,
    required this.result,
    required this.angleMode,
  });

  final String normalizedExpression;
  final String result;
  final String angleMode;

  @override
  bool operator ==(Object other) {
    return other is _SubmittedCalculationSignature &&
        other.normalizedExpression == normalizedExpression &&
        other.result == result &&
        other.angleMode == angleMode;
  }

  @override
  int get hashCode => Object.hash(normalizedExpression, result, angleMode);
}
