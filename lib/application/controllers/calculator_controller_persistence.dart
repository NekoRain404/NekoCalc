part of 'calculator_controller.dart';

mixin _CalculatorPersistence on _CalculatorState {
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
    // 中文：恢复时也过那道判定——历史数据里可能存着一个 `Infinity`（本轮之前是可以造出来的），
    //       它不该被信任着进寄存器；`decimalValueOf` 同时挡掉 `NaN` 与下溢。挡下来的按「没有可用的
    //       记忆值」处理（0），与键缺失、值不可解析时的行为一致。
    // English: The restore goes through the same judgement too — old data may hold an `Infinity`
    //          (which this code could produce before this round) and it must not be trusted into the
    //          register; `decimalValueOf` also rejects `NaN` and underflow. What it rejects is treated
    //          as "no usable memory value" (0), the same as a missing or unparseable one.
    memoryValue =
        MathResult.decimalValueOf(settings['calculator_memory'] ?? '') ?? 0;
    // 中文：变量的恢复走**与记忆寄存器同一道判定**（`decimalValueOf`）——磁盘上的东西同样是输入，
    //       同样可能是 `Infinity`、`NaN` 或一个下溢成 0 的值；挡下来的按「没有绑定」处理，
    //       与键缺失、值不可解析时一致。这一条也保证了一件事：**变量的值永远是一个能装进 double
    //       的有限数**，于是回落旧解析器时它不会变成一个静默的 0。
    // English: the variables are restored through **the same judgement the memory register uses**
    //          (`decimalValueOf`) — what is on disk is input too, and it may just as well be an
    //          `Infinity`, a `NaN` or a value that underflows to 0; what it rejects is treated as "not
    //          bound", exactly like a missing or unparseable entry. This also guarantees one thing:
    //          **a variable's value is always a finite number that fits in a double**, so it cannot
    //          turn into a silent 0 when the legacy parser answers instead of the engine.
    _variables.clear();
    for (final name in kBindableVariableNames) {
      final stored = settings['calculator_variable_$name'] ?? '';
      if (MathResult.decimalValueOf(stored) != null) _variables[name] = stored;
    }
    _lastFiniteResult =
        _result.decimalText.isEmpty ? null : _result.decimalText;
    if (expression.isNotEmpty) evaluate();
    _clearEditingHistory();
    if (_disposed) return false;
    notifyListeners();
    return true;
  }

  /// 中文：把当前表达式的结果保存成一条笔记。
  ///
  ///       **结果来源与「按下等号」完全一样**：[saveToNote] 曾经自己跑旧解析器重算一遍，于是引擎
  ///       辛苦算出的东西——超出 double 量程的值、精确形式——会在按下去的那一刻被旧求值器覆盖，
  ///       屏幕上的结果行当场翻脸，而笔记里写的是那个被覆盖后的值。现在两条路共用
  ///       [_submittedResult]：先问引擎，引擎答不出来才回落旧解析器（回落是与提交路径同一处的
  ///       判定，见 [_acceptedEngineResult]）。
  ///
  ///       代价是这一步变成了**真的异步**：以前重算是同步的，现在要等一次引擎往返，因此多出一条
  ///       提交路径早就有的分支——**过期**。往返期间用户又改了输入（`_stateRevision` 变了）或者
  ///       控制器已经销毁时，[CalculatorSaveNoteResult.superseded] 是唯一的正确答案：结果不许
  ///       落地，笔记也不许写，因为那两样都属于一条已经不在屏幕上的时间线。
  ///
  ///       `_markStateEdited()` 与 `_cancelLiveEvaluation()` 在等待之前发生：按「保存笔记」本身就
  ///       是一次状态编辑（撤销栈、代际），而还在排队的边打边算问的是一条即将被这一步接手的时间
  ///       线。已在飞的那一发不在这里收——代际守卫会认出它过期。
  ///
  /// English: Save the current expression's result as a note.
  ///
  ///          **The result comes from the same place "pressed =" uses**: [saveToNote] used to run the
  ///          legacy parser itself, so everything the engine had computed — values beyond a double's
  ///          range, exact forms — was overwritten the moment the button was pressed. The result line
  ///          then flipped in front of the user, and the note recorded the overwritten value. Both
  ///          paths now share [_submittedResult]: the engine is asked first and the legacy parser is
  ///          the fallback for when it cannot answer, judged in the one place the submit path uses
  ///          ([_acceptedEngineResult]).
  ///
  ///          The price is that this step is **genuinely asynchronous** now: the recomputation used
  ///          to be synchronous, and waiting on an engine round trip introduces the branch the submit
  ///          path already has — **staleness**. When the user edits during the round trip
  ///          (`_stateRevision` moves) or the controller is disposed,
  ///          [CalculatorSaveNoteResult.superseded] is the only right answer: the result must not
  ///          land and the note must not be written, because both belong to a timeline that is no
  ///          longer on screen.
  ///
  ///          `_markStateEdited()` and `_cancelLiveEvaluation()` happen before the wait: pressing
  ///          "save note" is itself a state edit (undo stack, generation), and any queued as-you-type
  ///          evaluation is asking about a timeline this step is about to take over. The call already
  ///          in flight is not collected here — the generation guard recognises it as stale.
  Future<CalculatorSaveNoteResult> saveToNote() async {
    if (expression.trim().isEmpty) {
      return const CalculatorSaveNoteResult.emptyExpression();
    }
    _markStateEdited();
    _cancelLiveEvaluation();
    final generation = _stateRevision;
    try {
      final calculated = await _submittedResult(expression, generation);
      if (calculated == null) {
        return const CalculatorSaveNoteResult.superseded();
      }
      _result = calculated;
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
    // 中文：当前值放不进 double 时**不动寄存器**。以前这里会往寄存器里加一个 0——那是一个静默的
    //       错值（`2^-2000` 就是这样变成 0 的）；不加，寄存器至少还是用户上一次放进去的那个数。
    //       `memoryAdd()` 没有返回值，所以这一次拒绝对用户仍然不可见——要让它可见得先有一个
    //       能给界面看的返回值，那是界面层面的事，不在这一步里。
    // English: When the current value does not fit a double the register is left alone. This used
    //          to add a 0 — a silently wrong value (`2^-2000` is exactly how that happens); by not
    //          adding, the register at least still holds what the user last put there.
    //          `memoryAdd()` returns nothing, so the refusal is still invisible to the user; making
    //          it visible needs a return value the UI can show, which is a UI-layer matter and not
    //          part of this step.
    final value = _currentNumericValue();
    if (value == null) return;
    _markStateEdited();
    _recordUndoSnapshot();
    memoryValue += value;
    unawaited(_persistState());
    notifyListeners();
  }

  void memorySubtract() {
    // 中文：与 [memoryAdd] 同理。
    // English: Same rule as [memoryAdd].
    final value = _currentNumericValue();
    if (value == null) return;
    _markStateEdited();
    _recordUndoSnapshot();
    memoryValue -= value;
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

  String copyText() => _resultReportText();

  String noteBody() => _resultReportText(savedAt: DateTime.now());

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

  @override
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
    // 中文：引擎明确回答「这次换算没发生」（见 [_submittedResult] 里那一支的注释）。文案说的是
    //       真正的原因——两个单位量纲不相容——而不是「存在无法识别的内容」那句会让人以为
    //       `km` 打错了的话。
    // English: the engine's definite answer that the conversion did not happen (see the note on that
    //          branch in [_submittedResult]). The wording names the real cause — the two units are
    //          not commensurable — instead of "unrecognised content", which reads as "you mistyped
    //          `km`".
    if (message.contains('Unit mismatch')) return '单位不匹配：这两个单位不能互相换算';
    return '表达式错误';
  }

  @override
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
      // 中文：两个变量各写一条，没绑定时写空串——`setMany` 只覆盖列出来的键，不写就等于把上一次的
      //       绑定留在磁盘上，重启之后那个变量会自己回来。
      // English: one entry per variable, an empty string while unbound — `setMany` only overwrites the
      //          keys it is given, so leaving them out would keep the previous binding on disk and the
      //          variable would come back by itself after a restart.
      for (final name in kBindableVariableNames)
        'calculator_variable_$name': _variables[name] ?? '',
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

  @override
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

  /// 中文：记忆寄存器要加/减的数值。**给不出一个能放进 double 的值时返回 null**——调用方据此
  ///       显式拒绝，而不是往寄存器里加一个 0 或一个 `Infinity`。绝不解析显示文本。
  ///
  ///       取值的顺序，三条都共用既有的判定（[MathResult.decimalTextIsFinite] /
  ///       [MathResult.decimalValueOf] / [MathResult.decimalValue]，与提交路径、粘贴路径同一处
  ///       实现，不另写一份）：
  ///
  ///       1. 表达式**本身就是一个数**（「继续使用」写回之后正是这种形状）→ 按**文本**判定。文本里
  ///          还留着 double 已经丢掉的信息，这正是它能识破下溢的原因。
  ///       2. 其余表达式 → **屏幕上那个结果的十进制形态**，只要它是引擎算出来的（[_result] 带 LaTeX
  ///          形态）。注意这里加的不是屏幕上**显示**的那个数：[_result.displayText] 已经按
  ///          `AppSettings.precision` 取过整（屏幕上是 `5.656854`），而寄存器拿的是
  ///          [_result.decimalText]，也就是引擎那一串未取整的十进制（`5.656854249492380`）。
  ///          这正是 `Ans`/`last` 用的那一份，两者不能是两套口径；此处的判定是结果里那串
  ///          **十进制文本**，`2^-2000` 的 `0.0` 因此不会再被当成一个真值收下。
  ///       3. 引擎没有参与（没有原生侧、kill switch 关掉、超时、答不出有限的十进制）→ 旧解析器，
  ///          与迁移之前逐字节相同。这是硬性回落的另一半：`_currentNumericValue()` 是同步的，
  ///          没有引擎结果可用的那些情形只能由旧解析器兜着。
  ///
  ///       这条分支以前**无条件**走旧解析器，于是引擎算出的值在按下 `M+` 时被重算一遍：
  ///
  ///       - `2^-2000` → `=` →「继续使用」把 `8.7e-603` 写回表达式 → `M+`：解析器给 `0.0`，
  ///         寄存器里静默变成 0；
  ///       - `2^2000` → 同样的路 → 解析器给 `Infinity`，寄存器里是 `Infinity`，而且会持久化、
  ///         重启后还在；
  ///       - `2^-2000` → `=` → `M+`（**不经过**「继续使用」）：旧解析器自己就把 `9.3e-603` 算成了
  ///         `0.0`，[MathResult.usableDouble] 只能判非有限、判不了下溢——于是执行的是「加一个
  ///         0」。这一条现在也堵上了：引擎在屏幕上留下的是它的十进制文本，下溢在那里看得出来，
  ///         于是寄存器**不被改动**（与上面那条一样是值中性的，但不再是「拿一个错值去加」）。
  ///
  /// English: The value the memory register adds or subtracts. It returns null when nothing fits a
  ///          double, and the caller then refuses explicitly rather than adding a 0 or an
  ///          `Infinity`. The display text is never parsed.
  ///
  ///          The order, all three sharing the existing judgements
  ///          ([MathResult.decimalTextIsFinite] / [MathResult.decimalValueOf] /
  ///          [MathResult.decimalValue] — the *same* implementation the submit path and the paste
  ///          path use, never a second copy):
  ///
  ///          1. The expression **is itself a number** (exactly the shape "continue with result"
  ///             leaves behind) → judged as **text**. The text still carries what the double has
  ///             already lost, which is what lets it see the underflow.
  ///          2. Any other expression → **the result on screen**, as long as the engine produced it
  ///             ([_result] carries a LaTeX form). What the register adds is the number the user is
  ///             looking at, the same one `Ans`/`last` use; the judgement here is made on the
  ///             result's **decimal text**, so the `0.0` of `2^-2000` is no longer taken as a real
  ///             value.
  ///          3. No engine involved (no native side, kill switch off, timeout, no finite decimal) →
  ///             the legacy parser, byte-for-byte what it did before the migration. That is the other
  ///             half of the hard fallback rule: `_currentNumericValue()` is synchronous, so the
  ///             cases with no engine answer are exactly the ones only the legacy parser can cover.
  ///
  ///          This branch used to go through the legacy parser **unconditionally**, so pressing `M+`
  ///          recomputed what the engine had already computed:
  ///
  ///          - `2^-2000` → `=` → "continue with result" writes `8.7e-603` back into the expression
  ///            → `M+`: the parser yields `0.0` and the register silently becomes 0;
  ///          - `2^2000` → the same route → the parser yields `Infinity`, the register holds
  ///            `Infinity`, and it persists across a restart;
  ///          - `2^-2000` → `=` → `M+` (**without** "continue with result"): the legacy parser turns
  ///            `9.3e-603` into `0.0` by itself, and [MathResult.usableDouble] can only judge
  ///            non-finiteness, not underflow — so it performed "add a zero". That one is closed
  ///            now too: what the engine left on screen is its decimal text, the underflow is visible
  ///            in it, and the register is therefore **left alone** (value-neutral like the case
  ///            above, but no longer a wrong value being added).
  double? _currentNumericValue() {
    try {
      if (expression.trim().isEmpty) return _result.decimalValue;
      final source = _resolveAnswerReferences(expression);
      if (MathResult.decimalTextIsFinite(source)) {
        return MathResult.decimalValueOf(source);
      }
      // 中文：`hasTex` 就是「这个结果是引擎算出来的」——旧路径从不写 LaTeX 形态，而引擎路径总有
      //       一段（见 [MathResult.displayTex] 的 doc）。
      // English: `hasTex` is exactly "the engine computed this result": the legacy path never writes
      //          a LaTeX form and the engine path always carries one (see the doc on
      //          [MathResult.displayTex]).
      if (_result.hasTex) return _result.decimalValue;
      return MathResult.usableDouble(
        ExpressionParser(source, degreeMode: angleMode == 'DEG').parse(),
      );
    } catch (_) {
      return _result.decimalValue;
    }
  }

  void _clearLastSavedSignature() {
    _lastSavedSignature = null;
  }

  @override
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

  @override
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

  /// 中文：**求值侧的替换入口，也是唯一的那一个。** 两层，顺序固定：先 `Ans`/`last`（它们换成的是
  ///       上一次的结果），再变量（`x`/`y` 换成用户绑定的值）。两者都不是「按名字拼字符串」这么简单
  ///       的事，各自的判据在各自那一处（[_resolveAnswerValue] 与 [resolveVariableReferences]）。
  ///
  ///       为什么变量挂在**这一层**而不是翻译器里：这一层的输出是三个消费者共同看到的那一个字符串
  ///       ——翻译器（`_askEngineTranslated`）、旧解析器（`_calculateResult`，它自己也调这一层）、
  ///       以及 `M+` 取值用的 `_currentNumericValue`。放进翻译器会让翻译器与解析器看到两份输入，
  ///       而这一条正是修复轮 7/8 反复吃过亏的地方。
  /// English: **the evaluator's substitution entry point, and the only one.** Two layers, in a fixed
  ///          order: `Ans`/`last` first (they become the previous result), then the variables (`x`/`y`
  ///          become the user's bound value). Neither is as simple as gluing a name together, and each
  ///          judgement lives where it belongs ([_resolveAnswerValue] and
  ///          [resolveVariableReferences]).
  ///
  ///          Why the variables hang on **this** layer rather than in the translator: this layer's
  ///          output is the one string all three consumers see — the translator
  ///          (`_askEngineTranslated`), the legacy parser (`_calculateResult`, which calls this layer
  ///          itself) and `_currentNumericValue` (what `M+` reads). Putting it in the translator would
  ///          give the translator and the parser two inputs, and that is exactly where fix rounds 7
  ///          and 8 kept losing.
  @override
  String _resolveAnswerReferences(String source) =>
      _resolveVariableReferences(_resolveAnswerValue(source));

  String _resolveAnswerValue(String source) {
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

}
