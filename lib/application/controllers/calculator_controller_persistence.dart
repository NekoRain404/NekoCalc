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
        decimalValueOf(settings['calculator_memory'] ?? '') ?? 0;
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
      if (decimalValueOf(stored) != null) _variables[name] = stored;
    }
    // 中文：数据集走的是**同一道判定**（`_readDataset` 里逐条过 `decimalValueOf`），理由与上面变量
    //       那一段逐字相同：盘上的东西同样是输入。整串读不动时它清空——失败一律关上，绝不猜一个数。
    // English: the dataset goes through **the same judgement** (`_readDataset` runs every entry through
    //          `decimalValueOf`), byte for byte the reason the variables' paragraph above gives: what
    //          is on disk is input too. An unreadable string clears it — fail closed, never guess a
    //          number.
    _readDataset(settings['calculator_dataset'], _dataset);
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
        title: strings.savedNoteTitle,
        body: noteBody(),
        description: strings.savedNoteDescription(_angleModeLabel()),
      );
      if (noteId <= 0) return const CalculatorSaveNoteResult.notWritten();
      unawaited(_persistState());
      return CalculatorSaveNoteResult.saved(noteId);
    } catch (error) {
      return CalculatorSaveNoteResult.failed(error);
    }
  }

  /// 中文：把当前值加进记忆寄存器。**返回值就是给界面看的那句话**：`null` = 加进去了，一段文字 =
  ///       这一次没有加，调用方把它交给用户。
  ///
  ///       判定一字未改：当前值放不进一个 double 时**不动寄存器**，也绝不加一个 0（那是一个静默的
  ///       错值，`2^-2000` 就是这样变成 0 的）或一个 `Infinity`——理由与判据见 [_currentNumericValue]。
  ///       变的只是**拒绝被说出来了**：以前这里什么都不返回，于是用户按了 `M+`、寄存器没动、
  ///       屏幕上也没有任何提示，看起来像按键失灵。
  ///
  ///       为什么是一句话而不是一个布尔：**判定在这里、界面在别处**。被拒的原因（放不进 double）
  ///       只有这一处知道，界面拿到一个布尔就只能写死一句自己的话，而那句话迟早会与这里的判定漂开。
  ///       形状与四个进制胶囊的 `showBaseReadout` 相同（`null` = 无话可说，一段文字 = 这次没成），
  ///       调用方走的也是同一条通道（主屏的 `SnackBar`）。
  ///
  /// English: Add the current value to the memory register. **The return value is the sentence the
  ///          screen shows**: `null` means it was added, a sentence means it was not and the caller
  ///          hands it to the user.
  ///
  ///          The judgement is untouched: when the current value does not fit a double the register
  ///          is left alone and neither a 0 (a silently wrong value — `2^-2000` is exactly how that
  ///          happens) nor an `Infinity` is ever added; the test and the reasoning are on
  ///          [_currentNumericValue]. What changed is that **the refusal is now spoken**: this used
  ///          to return nothing, so pressing `M+` moved nothing and the screen said nothing, which
  ///          reads as a dead key.
  ///
  ///          It returns a sentence rather than a bool because **the judgement is here and the screen
  ///          is elsewhere**: only this place knows why the value was refused, so a bool would leave
  ///          the screen hard-coding a sentence of its own that would sooner or later drift from the
  ///          judgement. The shape matches the four base pills' `showBaseReadout` (`null` = nothing
  ///          to say, a sentence = this one did not work) and callers use the same channel (the
  ///          screen's `SnackBar`).
  String? memoryAdd() {
    final value = _currentNumericValue();
    if (value == null) return _memoryRefusalMessage;
    _markStateEdited();
    _recordUndoSnapshot();
    memoryValue += value;
    unawaited(_persistState());
    notifyListeners();
    return null;
  }

  /// 中文：与 [memoryAdd] 同理——同一条判定、同一种拒绝、同一句话（[`_memoryRefusalMessage`]）。
  ///       减去一个放不进 double 的值同样不可能是对的，所以 `M−` 的拒绝与 `M+` 一样要说出来。
  /// English: the same rule as [memoryAdd] — one judgement, one refusal, one sentence
  ///          ([`_memoryRefusalMessage`]). Subtracting a value that does not fit a double cannot be
  ///          right either, so `M−`'s refusal is spoken exactly like `M+`'s.
  String? memorySubtract() {
    final value = _currentNumericValue();
    if (value == null) return _memoryRefusalMessage;
    _markStateEdited();
    _recordUndoSnapshot();
    memoryValue -= value;
    unawaited(_persistState());
    notifyListeners();
    return null;
  }

  /// 中文：`x→M`——把当前值**写进**寄存器（替换，不是累加）。
  ///
  ///       它以前住在主屏里，写成「先 [`memoryClear`] 再 [`memoryAdd`]」两次调用（控制器只有累加的
  ///       `memoryAdd`，两次合起来才是替换）。那个写法有一个**破坏性**的缺陷：值放不进 double 时，
  ///       清空照常发生、累加被拒——用户原来的记忆值被一次拒绝**静默抹掉**了，比按 `M+` 什么都不
  ///       发生更坏。判定必须发生在清空**之前**，而主屏拿不到那个判定，所以这一对调用挪进控制器：
  ///       先问一次「这个值存得进去吗」，存不进去就整体放弃、寄存器一动不动，并把同一句话交出去。
  ///
  ///       成功路径一字未改：仍然调用原来那两个方法（`memoryClear()` 然后 `memoryAdd()`），因此
  ///       两次状态编辑、两次撤销快照、两次落盘、两次通知都与从前逐字节相同——**`x→M` 别的行为
  ///       没有被动过**，变的只是被拒时不再先清空。第二次判定（`memoryAdd()` 内部那一次）不会翻案：
  ///       两次调用之间没有 `await`，表达式、结果与角度模式都不可能改。
  ///
  /// English: `x→M` — **write** the current value into the register (a replace, not an accumulate).
  ///
  ///          It used to live on the screen as "clear, then add" (the controller only offers the
  ///          accumulating `memoryAdd`; the pair makes a replace). That shape had a **destructive**
  ///          defect: when the value does not fit a double the clear happened anyway and the add was
  ///          refused, so one refusal **silently wiped** the user's previous memory value — worse
  ///          than `M+` doing nothing. The judgement has to run **before** the clear, and the screen
  ///          cannot make it, so the pair moves into the controller: ask once whether the value can
  ///          be stored; on a refusal give up as a whole, leave the register untouched and hand out
  ///          the same sentence.
  ///
  ///          The success path is unchanged: it still calls the same two methods (`memoryClear()`
  ///          then `memoryAdd()`), so two state edits, two undo snapshots, two persists and two
  ///          notifications all happen exactly as before — **nothing else about `x→M` moves**; what
  ///          changes is that a refusal no longer clears first. The second judgement (the one inside
  ///          `memoryAdd()`) cannot disagree: nothing is awaited in between, so the expression, the
  ///          result and the angle mode cannot have changed.
  String? memoryStore() {
    if (_currentNumericValue() == null) return _memoryRefusalMessage;
    memoryClear();
    memoryAdd();
    return null;
  }

  /// 中文：记忆寄存器拒绝一个值时的**那一句话**，三个可能被拒的操作（`M+`、`M−`、`x→M`）共用。
  ///       它自带结论（没有存入）与后果（寄存器未改动）：用户既要知道刚才那一下没有生效，也要知道
  ///       原来那个值还在。共用一句是因为被拒的原因只有一个——当前值放不进一个 double。
  ///
  ///       **它是说给用户听的，不是日志**，所以不提 double、不提量程：这个寄存器里放着的就是
  ///       「一个数」，放不进就说放不进；而「寄存器未改动」正是用户下一步要据此决定的事
  ///       （要不要用 `MR` 看看、要不要改用「继续使用」把那个值带回表达式）。
  ///
  /// English: **the sentence** the memory register gives when it refuses a value — shared by all
  ///          three operations that can refuse (`M+`, `M−`, `x→M`). It carries both the verdict
  ///          (nothing was stored) and the consequence (the register is unchanged): the user needs to
  ///          know the press did not take effect and that the value which was there is still there.
  ///          One sentence is enough because there is only one reason to refuse — the current value
  ///          does not fit a double.
  ///
  ///          **It is written for the user, not for a log**, so it names neither `double` nor a
  ///          range: what lives in this register is "a number", and it either fits or it does not.
  ///          "The register is unchanged" is the part the user acts on (whether to press `MR` to look,
  ///          or to bring that value back into the expression with "continue with result").
  String get _memoryRefusalMessage => strings.memoryRefusal;

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
      if (expression.trim().isEmpty)
        strings.reportCurrentValue(result)
      else
        strings.reportExpression(expression),
      if (expression.trim().isNotEmpty) strings.reportResult(result),
      // 中文：显示文本本身不是可解析的十进制时（引擎给出 `4√2` 这类精确形式），报告补一行十进制：
      //       粘贴路径优先读它，否则「复制结果再粘回计算器」这条往返会在精确形式上悄悄断掉。旧求值
      //       器下这一行永不出现，报告文本与拆分前逐字符一致。
      // English: When the display text is not itself a parseable decimal (the engine's exact forms
      //          such as `4√2`), the report adds a decimal line: the paste path reads it first, or
      //          the copy-a-result-and-paste-it-back round trip would quietly break on exact forms.
      //          Under the legacy evaluator this line never appears, so the report text stays
      //          character-for-character what it was.
      if (_result.decimalText.isNotEmpty && !_result.displayTextIsParseable)
        strings.reportDecimal(_result.decimalText),
      strings.reportStatus(resultStatusTitle),
      resultStatusMessage,
      strings.reportAngleMode(_angleModeLabel()),
      if (memoryValue != 0)
        strings.reportMemory(formatNumber(memoryValue,
            precision: _settings.precision,
            groupThousands: _settings.groupThousands)),
      if (hasError && errorMessage != null) strings.reportError(errorMessage!),
      if (savedAt != null) strings.reportSavedAt(_formatReportTime(savedAt)),
    ];
    return lines.join('\n');
  }

  String _angleModeLabel() => angleMode == 'DEG'
      ? strings.angleModeDegrees
      : strings.angleModeRadians;

  String _formatReportTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  String _friendlyCalculationError(Object error) {
    final message = error.toString().replaceFirst('FormatException: ', '');
    // 中文：**左边是判据，右边是文案。** 判据是引擎与旧解析器抛出的 `FormatException` 的
    //       **英文**原文（`Missing )`、`Expected number`…），它们不是界面上的字，所以留在源码里
    //       不动；被翻的只有右边这十四句。这就是判据与文案分家的地方，别把 `contains` 的入参
    //       换成表里的东西。
    // English: **the left side is the verdict, the right side is the wording.** The verdicts are the
    //          **English** text of the `FormatException`s the engine and the legacy parser throw
    //          (`Missing )`, `Expected number`, …); they are not on-screen words and stay in the
    //          source. Only the fourteen sentences on the right are translated. This is where verdict and
    //          wording part company — do not swap the `contains` arguments for anything from a table.
    if (message.contains('Missing )')) return strings.friendlyMissingParen;
    if (message.contains('Expected number')) {
      return strings.friendlyExpectedNumber;
    }
    if (message.contains('Unexpected token')) {
      return strings.friendlyUnexpectedToken;
    }
    if (message.contains('needs (')) return strings.friendlyFunctionNeedsParen;
    if (message.contains('Unknown function')) return strings.friendlyUnknownFunction;
    if (message.contains('Factorial needs')) return strings.friendlyFactorialRange;
    if (message.contains('Root degree cannot be 0')) {
      return strings.friendlyRootDegreeZero;
    }
    if (message.contains('Even root of negative')) {
      return strings.friendlyEvenRootNegative;
    }
    if (message.contains('Result is not finite')) return strings.friendlyNotFinite;
    // 中文：引擎明确回答「这次换算没发生」（见 [_submittedResult] 里那一支的注释）。文案说的是
    //       真正的原因——两个单位量纲不相容——而不是「存在无法识别的内容」那句会让人以为
    //       `km` 打错了的话。
    // English: the engine's definite answer that the conversion did not happen (see the note on that
    //          branch in [_submittedResult]). The wording names the real cause — the two units are
    //          not commensurable — instead of "unrecognised content", which reads as "you mistyped
    //          `km`".
    if (message.contains('Unit mismatch')) return strings.friendlyUnitMismatch;
    // 中文：引擎超时，而回落旧解析器也读不懂。**这句说的是真原因**——
    //       旧解析器那句「函数需要括号」会把用户引向一个不存在的问题。
    // English: the engine timed out and the fallback could not read it either. **This states the real
    //          cause** — the legacy parser's "function needs parentheses" sends the user after a problem
    //          that does not exist.
    if (message.contains(kEngineTimeoutVerdict)) return strings.friendlyEngineTimeout;
    // 中文：引擎的全局定义没加载（没有单位与常数），而回落旧解析器也读不懂。**这句说的是根因**——
    //       通用那句「存在无法识别的内容」会让用户以为 `km` 打错了。判据在引擎层
    //       （`QalculateMathEngine._replyFrom` 的 `definitionsLoaded`），这里只翻成文案。
    // English: the engine's global definitions never loaded (no units, no constants) and the fallback
    //          could not read the expression either. **This states the root cause** — the generic
    //          "unrecognised content" would make the user think they mistyped `km`. The judgement
    //          lives at the engine layer (`definitionsLoaded` in `QalculateMathEngine._replyFrom`);
    //          this only turns it into wording.
    if (message.contains(kEngineDefinitionsUnloadedVerdict)) {
      return strings.friendlyEngineDefinitionsUnloaded;
    }
    // 中文：引擎把一条关系答成了一个数（`x^2=-1`、`1=2`）——**那是一个布尔值**。
    //       落在这里而不是走通用那一句，是因为通用那句说的是"存在无法识别的内容"，
    //       而用户看到的是"我打错了"，真正的原因是这个方程没有解。判据的判据在
    //       `_relationCameBackAsTruthValue` 一处。
    // English: the engine answered a relation with a number (`x^2=-1`, `1=2`) — **a truth value**. It
    //          lands here rather than on the generic sentence because that one says "unrecognised
    //          content", which reads as "I typed something wrong", while the real reason is that this
    //          equation has no solution. The judgement's own judgement lives in one place,
    //          `_relationCameBackAsTruthValue`.
    if (message.contains(kRelationTruthValueVerdict)) {
      return strings.friendlyRelationNoSolution;
    }
    return strings.friendlyGeneric;
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
      // 中文：数据集整份写进**一个**键（`_datasetIdText` 那一处决定它的形状），所以它不需要像变量
      //       那样「逐个键都写上，不然旧值会留在盘上」——一个键要么被整份覆盖，要么整个不在。
      //       它也有上限（`kMaxDatasetValues`），理由正在这里：这个键每次都跟着按键重写一遍。
      // English: the dataset goes into **one** key (its shape is decided in `_datasetIdText`), so it
      //          needs none of the variables' "write every key or the old value stays on disk" care —
      //          a single key is either overwritten whole or absent. It has a cap
      //          (`kMaxDatasetValues`), and this key is exactly why: it is rewritten with every
      //          keypress.
      'calculator_dataset': _datasetIdText(_dataset),
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
    // 中文：**全应用唯一一处拿那句占位文本当判据的地方，而这里它是存储层的令牌。**
    //       盘上存的是一列文本，没有别的可读；上一次会话若在一条算不出来的表达式上结束，
    //       那一列里写着的就是 `MathResult.pending` 的文本。此时立起 [MathResult.isPlaceholder]，
    //       三处判据（`reusableResult` / `canContinueWithResult` / `continueWithResult`）看到的
    //       与盘上那一刻相同——**判据本身不再读文案**（理由见那个字段的注释）。
    //       比的是 [MathResult.pending] 那一份**自身**的文本，不是这个文件里另抄的一遍字面量；
    //       三格文本原样带上（哪怕盘上的行是手改出来的），显示与数值消费者读到的因此一个字都不动。
    //       **策略 (A)（`engineOnly`）下这一格是能观察到的**：那时 `evaluate()` 不上旧解析器的
    //       结果，盘上这一份会一直留在屏幕上直到引擎回答。
    // English: **the one place in the app that reads that placeholder sentence as a token, and here it
    //          is a storage-layer token.** What is on disk is a row of text and nothing else can be
    //          read from it; if the last session ended on an expression that cannot be evaluated,
    //          that row carries `MathResult.pending`'s text. [MathResult.isPlaceholder] is raised
    //          then, so the three judgements (`reusableResult` / `canContinueWithResult` /
    //          `continueWithResult`) see what they saw at the moment it was written — **the
    //          judgements themselves no longer read copy** (why: see that field's note). The
    //          comparison is against [MathResult.pending]'s **own** text rather than a second copy of
    //          the literal in this file; the three text cells travel as they are (even for a
    //          hand-edited row), so what the display and the numeric consumers read does not move by
    //          one character. **Under policy (A) (`engineOnly`) this cell is observable**: there
    //          `evaluate()` does not put the legacy result up, so the stored one stays on screen
    //          until the engine answers.
    return MathResult(
      displayText: displayText,
      displayTex: settings['calculator_result_tex'] ?? '',
      decimalText: hasDecimalField
          ? (settings['calculator_result_decimal'] ?? '')
          : decimalTextOf(displayText),
      isPlaceholder: displayText == MathResult.pending.displayText,
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
  ///       显式拒绝（也就是 [memoryAdd]/[memorySubtract]/[memoryStore] 返回 [`_memoryRefusalMessage`]
  ///       的那一支），而不是往寄存器里加一个 0 或一个 `Infinity`。绝不解析显示文本。
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
  ///          double, and the caller then refuses explicitly — the branch where
  ///          [memoryAdd]/[memorySubtract]/[memoryStore] hand back [`_memoryRefusalMessage`] —
  ///          rather than adding a 0 or an `Infinity`. The display text is never parsed.
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
      if (decimalTextIsFinite(source)) {
        return decimalValueOf(source);
      }
      // 中文：`hasTex` 就是「这个结果是引擎算出来的」——旧路径从不写 LaTeX 形态，而引擎路径总有
      //       一段（见 [MathResult.displayTex] 的 doc）。
      // English: `hasTex` is exactly "the engine computed this result": the legacy path never writes
      //          a LaTeX form and the engine path always carries one (see the doc on
      //          [MathResult.displayTex]).
      if (_result.hasTex) return _result.decimalValue;
      return usableDouble(
        ExpressionParser(
          source,
          degreeMode: angleMode == 'DEG',
          // 中文：这一处也在**算值**（存进记忆寄存器的那个数），所以与两个求值入口同模式——
          //       模式不同的话，屏幕上写着 55 而寄存器里存的是 50.1。
          // English: this one also **computes a value** (the number stored in the memory register), so
          //          it takes the same mode as the two evaluating entrances; a different mode would put
          //          55 on screen and 50.1 in the register.
          relativePercent: relativePercent,
        ).parse(),
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
