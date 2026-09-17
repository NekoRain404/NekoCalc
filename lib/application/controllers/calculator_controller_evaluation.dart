part of 'calculator_controller.dart';

mixin _CalculatorEvaluation on _CalculatorState {
  /// 中文：求值一次——**边打边算的入口**，也是这一步搬到引擎上的那一个。它做两件事：
  ///
  ///       1. **旧结果先上屏**（裁决 1 的策略 (B)，[liveResultPolicy]）：同步跑旧解析器，屏幕上
  ///          立刻有结果；策略 (A) 时这一步不做，屏幕留着上一个值。
  ///       2. **排一次引擎跟进**：延迟 [liveEngineFollowUpDelay] 之后问引擎，回包到达时替换。
  ///
  ///       这个方法**仍然是同步的**：它的所有调用方（`updateSettings`、`setAngleMode`、粘贴、
  ///       继续使用、记忆回填、恢复状态、以及 [_scheduleLiveEvaluation] 的定时器）都当它是同步的，
  ///       而界面在任何 await 上都不许被挡住。引擎那一发是它排出去的异步尾巴，用**提交路径同一个
  ///       代际守卫**（`_stateRevision`）保证过期回包不落地——这里不另写一份守卫。
  ///
  ///       引擎不可用（没有原生侧、超时、答不出有限的十进制）时**什么都不做**：屏幕上已经是旧解析器
  ///       的结果，回落对用户完全不可见。唯一的例外是策略 (A)——那里屏幕上没有旧结果，必须补上，
  ///       见 [_evaluateWithEngine]。
  ///
  /// English: Evaluate once — *the as-you-type entry point*, and the one this step moves onto the
  ///          engine. It does two things:
  ///
  ///          1. **The legacy result goes up first** (ruling 1's policy (B), [liveResultPolicy]): the
  ///             legacy parser runs synchronously so a result is on screen immediately; under policy
  ///             (A) this step is skipped and the previous value stays.
  ///          2. **An engine follow-up is scheduled**: the engine is asked after
  ///             [liveEngineFollowUpDelay], and its answer replaces the result when it lands.
  ///
  ///          The method itself **stays synchronous**: every caller (`updateSettings`,
  ///          `setAngleMode`, paste, continue-with-result, memory recall, state restore, and
  ///          [_scheduleLiveEvaluation]'s timer) treats it as synchronous, and the interface must
  ///          never be blocked on an await. The engine call is an asynchronous tail it schedules,
  ///          guarded against stale replies by **the submit path's own generation guard**
  ///          (`_stateRevision`) — no second guard is written here.
  ///
  ///          When the engine is unavailable (no native side, timeout, no finite decimal) this does
  ///          **nothing**: the legacy parser's result is already on screen, so the fallback is
  ///          invisible to the user. The one exception is policy (A), where no legacy result is on
  ///          screen and one has to be supplied — see [_evaluateWithEngine].
  @override
  void evaluate() {
    if (liveResultPolicy.showsLegacyResult) _evaluateLegacy();
    if (_liveEvaluationEngineBacked) _scheduleLiveEngineFollowUp();
  }

  /// 中文：旧求值器的那一次求值：同步、微秒级，写 [_result] / [hasError] / [errorMessage]。
  ///       它的行为**一字未改**——kill switch 关掉引擎跟进之后，边打边算就是它，与 3d 结束时逐字节
  ///       一致。
  /// English: One legacy evaluation: synchronous, microseconds, writing [_result], [hasError] and
  ///          [errorMessage]. Its behaviour is **unchanged** — with the engine follow-up switched off,
  ///          as-you-type evaluation is exactly this, byte-for-byte what it was at the end of 3d.
  void _evaluateLegacy() {
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

  /// 中文：边打边算是否走引擎——**裁决 2 的 kill switch** 就是它，见
  ///       [kEngineBackedLiveExpressionDisplay]。切到另一个值，[_scheduleLiveEngineFollowUp] 再也
  ///       不会被调用，剩下的行为与 3d 结束时的边打边算逐字节一致。
  /// English: Whether as-you-type evaluation uses the engine — **ruling 2's kill switch**, see
  ///          [kEngineBackedLiveExpressionDisplay]. Flipping it means [_scheduleLiveEngineFollowUp]
  ///          is never called again and what remains is byte-for-byte the as-you-type behaviour of
  ///          the end of 3d.
  bool get _liveEvaluationEngineBacked =>
      _settings.expressionDisplayMode == kEngineBackedLiveExpressionDisplay;

  /// 中文：排一次引擎跟进，并**把上一次没发的取消掉**——这就是防抖：连续输入期间定时器一直被重排，
  ///       于是一次调用都不会发出，直到用户停下来。
  /// English: Schedule one engine follow-up and **cancel the one that has not fired yet** — that is
  ///          the debounce: while typing continues the timer keeps being reset, so no call is issued
  ///          at all until the user stops.
  void _scheduleLiveEngineFollowUp() {
    _liveEngineTimer?.cancel();
    _liveEngineTimer = Timer(liveEngineFollowUpDelay, () {
      if (_disposed) return;
      unawaited(_evaluateWithEngine());
    });
  }

  /// 中文：取消还没发的边打边算（两个定时器 + 「还欠一次」）。提交、撤销、重做都会走到这里：那一发
  ///       引擎跟进如果继续发出去，问的就是一条已经被提交路径接手的时间线。已在飞的那一发不在这里
  ///       收——它由代际守卫认出过期并丢弃。
  /// English: Cancel the as-you-type work that has not fired yet (both timers plus "one more is
  ///          owed"). Submit, undo and redo all reach here: letting that follow-up go would ask about
  ///          a timeline the submit path has already taken over. The call already in flight is not
  ///          collected here — the generation guard recognises it as stale and drops it.
  @override
  void _cancelLiveEvaluation() {
    _liveEvaluationTimer?.cancel();
    _liveEngineTimer?.cancel();
    _liveEngineDirty = false;
  }

  /// 中文：问引擎要边打边算的结果，并在回包到达时落地。四件事都在这里：
  ///
  ///       - **在飞上限为 1**。已经有一发在飞时不再发第二发，只把 [_liveEngineDirty] 立起来；
  ///         那一发回包落地之后再补一次（问的是最新的表达式）。于是无论用户打得多快，**控制器同时
  ///         等待的**引擎调用最多一发。
  ///
  ///         **但这不等于原生队列永远只有一发。** 超时会让 completer 完成、这里的槽位释放，
  ///         而那一发在原生侧**仍占着它的 FIFO 位置**——被放弃，但没有被取消。所以原生队列的真实
  ///         上界是 `1 + 被放弃的调用数`：引擎永久卡死时，每过一个 `engineTimeout` 就攒一条队列项，
  ///         **不需要用户做任何事**。后果是缓慢且无害的（不会产出错值），但**别把这个不变式当成会
  ///         自己报警的东西**——它恰恰在该报警的那种情形下不会报警。
  ///       - **过期的一律丢弃**。用的是提交路径同一个代际守卫：请求前记下 `_stateRevision`，落地前
  ///         再比一次；期间用户改过任何状态，这次回答描述的就是屏幕上已经不存在的那条时间线。
  ///         再比一次表达式，是为了堵住「表达式被换掉但没有走 [_markStateEdited]」的那条路
  ///         （状态恢复直接写 `expression`）。
  ///       - **回落是全覆盖的**。引擎答不出来（超时、没有原生侧、没有有限的十进制）时，策略 (B)
  ///         下屏幕上早就有旧解析器的结果，这里什么都不做；策略 (A) 下屏幕上没有旧结果，于是现在
  ///         补一次旧解析器——否则引擎一坏，结果行就永远停在旧值上。
  ///       - **采用引擎答案的判定与提交路径共用一处**（[_acceptedEngineResult]），不另写一份。
  ///
  /// English: Ask the engine for the as-you-type result and land it when the reply arrives. Four
  ///          things happen here:
  ///
  ///          - **At most one call in flight.** When one is already out, no second one is issued;
  ///            [_liveEngineDirty] is raised instead, and a further follow-up is made once that reply
  ///            lands (asking about the newest expression). However fast the user types, then, at most
  ///            one engine call is one this controller is *awaiting*.
  ///
  ///            **That is not the same as the native queue never holding more than one.** A timeout
  ///            completes the completer and frees the slot here, while the call itself **keeps its
  ///            FIFO place** on the native side — abandoned, not cancelled. So the real bound is
  ///            `1 + abandoned calls`: a permanently wedged engine accumulates one queued entry per
  ///            `engineTimeout`, with no user action required. The consequence is slow and harmless
  ///            (no wrong value is produced), but **do not treat this invariant as something that
  ///            announces itself** — it is precisely in the case that should trip it that it does not.
  ///          - **Stale replies are dropped.** It uses the submit path's own generation guard: the
  ///            generation is captured before the call and compared again before landing; if the user
  ///            changed any state in between, that answer describes a timeline that is no longer on
  ///            screen. The expression is compared as well, which closes the route where the
  ///            expression is replaced without going through [_markStateEdited] (state restore writes
  ///            `expression` directly).
  ///          - **The fallback is complete.** When the engine cannot answer (timeout, no native side,
  ///            no finite decimal) policy (B) does nothing, because the legacy parser's result is
  ///            already on screen; policy (A) has no legacy result on screen, so one is supplied now —
  ///            otherwise a broken engine would leave the result line stuck forever.
  ///          - **Accepting the engine's answer is shared with the submit path**
  ///            ([_acceptedEngineResult]); no second copy is written.
  Future<void> _evaluateWithEngine() async {
    if (_disposed) return;
    if (!_liveEvaluationEngineBacked) {
      // 中文：kill switch 是在**发这一发之前**被拨回去的（这一发的定时器早就排好了）。它必须在这里
      //       也拦一道，否则「切到旧路径」之后还会多问一次引擎——虽然那一发答什么都不会落地（代际
      //       已经变了），但开关要的是**一次都不问**。
      // English: The kill switch was flipped back *before this call went out* (its timer was scheduled
      //          earlier). It has to be checked here too, or "switched back to the legacy path" would
      //          still ask the engine one more time — that answer could not land (the generation has
      //          changed), but the switch promises not to ask at all.
      _liveEngineDirty = false;
      return;
    }
    final source = expression;
    if (source.trim().isEmpty) {
      // 中文：空表达式没有可问的东西，顺手把「还欠一次」清掉，免得它留到下一次输入。
      // English: There is nothing to ask about an empty expression; clear "one more is owed" while
      //          here so it cannot leak into the next input.
      _liveEngineDirty = false;
      return;
    }
    if (_liveEngineInFlight) {
      _liveEngineDirty = true;
      return;
    }
    _liveEngineInFlight = true;
    _liveEngineDirty = false;
    // 中文：与提交路径同一处守卫、同一个计数器。`Ans`/`last` 也要在这里先换成十进制数值，理由与
    //       提交路径一样：引擎不认识它们，直接问会把 `ans` 当成未知变量。
    // English: The same guard and the same counter the submit path uses. `Ans`/`last` are substituted
    //          here too, for the same reason as on the submit path: the engine does not know them and
    //          would read `ans` as an unknown variable.
    final generation = _stateRevision;
    final reply = await _askEngineTranslated(_resolveAnswerReferences(source));
    _liveEngineInFlight = false;
    if (_disposed) return;
    // 中文：先取出「还欠一次」再落地。不管落地与否都要还这一次：欠它的那一刻，用户已经改过输入，
    //       而那一发的答案永远只对**当前**表达式有效。它是一发，不是一队。
    // English: Take "one more is owed" out before landing anything. That one is owed regardless of how
    //          this landing goes: at the moment it was raised the user had already changed the input,
    //          and a follow-up answer is only ever good for the *current* expression. It is one call,
    //          not a queue.
    final owed = _liveEngineDirty;
    _liveEngineDirty = false;
    // 中文：**过期守卫必须在 `_selectEngineResult` 之前。** 取舍那一处可能走到旧解析器
    //       （`_tryLegacyResult` → `_calculateResult`），而那条路会写 `_lastFiniteResult`——
    //       那是 `Ans`/`last` 的取值处。守卫放在后面，一个**过期的**回包就能悄悄把它们挪到
    //       一条已经不在屏幕上的时间线上。提交路径一直守着这一点（`_submittedResult` 的第一件事
    //       就是问这一代对不对），边打边算这条以前靠「取舍不改状态」侥幸成立，放宽判据之后就
    //       不成立了。
    // English: **the staleness guard has to run before `_selectEngineResult`.** That selection may
    //          reach the legacy parser (`_tryLegacyResult` → `_calculateResult`), and that path writes
    //          `_lastFiniteResult` — where `Ans`/`last` read from. With the guard after it, a **stale**
    //          reply could quietly move them onto a timeline that is no longer on screen. The submit
    //          path has always guarded this (`_submittedResult`'s first act is to ask whether the
    //          generation still matches); the as-you-type path only held by the accident that
    //          selection touched no state, and relaxing the judgement ended that.
    if (generation != _stateRevision || expression != source) {
      if (owed) _scheduleLiveEngineFollowUp();
      return;
    }
    final accepted = _selectEngineResult(reply, source)?.result;
    if (accepted == null) {
      if (!liveResultPolicy.showsLegacyResult) {
        _evaluateLegacy();
        unawaited(_persistState());
        notifyListeners();
      }
    } else {
      _adoptEngineResult(accepted);
      unawaited(_persistState());
      notifyListeners();
    }
    if (owed) _scheduleLiveEngineFollowUp();
  }

  /// 中文：把引擎的结果落到屏幕上——与提交路径写的是同一组状态（结果、`_lastFiniteResult`、错误
  ///       状态），因此边打边算落地之后 `Ans`/`last` 引用的是引擎的十进制形态，而不是显示取整后
  ///       的那一份。
  /// English: Land the engine's result on screen — the same set of state the submit path writes
  ///          (the result, `_lastFiniteResult`, the error state), so that once an as-you-type result
  ///          lands, `Ans`/`last` resolve to the engine's decimal form rather than the display-rounded
  ///          one.
  void _adoptEngineResult(MathResult accepted) {
    _result = accepted;
    _lastFiniteResult =
        accepted.decimalText.isEmpty ? null : accepted.decimalText;
    hasError = false;
    errorMessage = null;
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
    _adoptEngineResult(value);
    notifyListeners();
  }

  @override
  Future<CalculatorSubmitResult> submit() async {
    if (expression.trim().isEmpty) {
      return const CalculatorSubmitResult.emptyExpression();
    }
    _markStateEdited();
    _cancelLiveEvaluation();
    // 中文：本次提交的代际。`_stateRevision` 在每一次「状态被改过」时自增，也包括这次 submit 自己
    //       的 `_markStateEdited()`，所以在这之后取到的值就是「本次提交开始时的那一代」；回包落地
    //       之前再比一次，就能认出「用户在这次往返期间又动了什么」。
    // English: This submit's generation. `_stateRevision` is bumped whenever state is edited,
    //          including this submit's own `_markStateEdited()`, so the value taken after it is
    //          "the generation this submit started in"; comparing again before the reply lands is
    //          what recognises "the user touched something during this round trip".
    final generation = _stateRevision;
    try {
      final submittedExpression = expression;
      // 中文：只有「按下等号」这条路径问引擎。边打边算（`evaluate()`）一行未动，仍然完全走旧的
      //       同步解析器——把实时路径也搬过去的时序风险留给下一步。
      // English: Only "pressed =" asks the engine. As-you-type evaluation (`evaluate()`) is
      //          untouched and still runs entirely on the legacy synchronous parser; the timing
      //          risk of moving the live path stays out of this step.
      final calculated =
          await _submittedResult(submittedExpression, generation);
      // 中文：引擎往返期间用户又改了输入——或者控制器已经销毁。两种情况下这次的结果都不许落地：
      //       它描述的是一个已经不在屏幕上的表达式，落地会覆盖更新的边打边算结果，还会把
      //       `_lastFiniteResult` 与持久化内容一起带到那条过期的时间线上。
      //       启动后的第一次提交最容易触发（那一次包含懒加载 `loadGlobalDefinitions()`）。
      // English: The user edited during the engine round trip — or the controller is gone. Either
      //          way this result must not land: it describes an expression that is no longer on
      //          screen, and landing it would overwrite the newer as-you-type result and drag
      //          `_lastFiniteResult` and the persisted state onto that stale timeline. The first
      //          submit after launch is the likeliest trigger (it includes the lazy
      //          `loadGlobalDefinitions()`).
      if (calculated == null || _disposed) {
        return const CalculatorSubmitResult.superseded();
      }
      _result = calculated;
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
      // 中文：过期或已销毁时错误同样不许落地——连错误状态也是那条过期时间线上的东西。
      // English: A stale or disposed submit must not land its error either — the error state
      //          belongs to that same stale timeline.
      if (_disposed || generation != _stateRevision) {
        return const CalculatorSubmitResult.superseded();
      }
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

  /// 中文：**提交路径**（只有「按下等号」会走到这里）的结果来源：先问引擎，问不到就回落旧解析器。
  ///
  ///       回落是硬要求，且引擎的失败对用户完全不可见：引擎未加载、没有原生侧、被中止、超时、
  ///       解析失败，用户看到的都是**今天那条结果或那条错误**，一字不差。所以这里接受引擎结果的
  ///       条件很紧——必须是一个**有限十进制**：
  ///
  ///       - 引擎没有十进制形态（`1 m` 这类带单位的结果）：回落到旧解析器；
  ///       - 十进制形态根本不是有限数（`infinity` / `NaN` 字面量）：同样回落，于是 `1/0` 仍然是
  ///         今天那条「结果不是有限数值」，而不是一个看起来像结果的 `无效`。
  ///
  ///       这个判断发生在**字符串层面**（[MathResult.hasFiniteDecimal]），**不借 double**：
  ///       `2^2000 ≈ 1.148e+602` 是一个完全正确的有限结果，只是超出 double 上限，用
  ///       `double.isFinite` 去判会把它当成无穷扔掉——那正是精确引擎存在的理由。同一根因的另一端
  ///       是下溢：`2^-2000 ≈ 9.3e-603` 会被 `double.tryParse` 变成 `0.0`，见
  ///       [MathResult.decimalValue]。
  ///
  ///       表达式先过 [_resolveAnswerReferences]，和旧路径一样：引擎不认识 `Ans`/`last`，问它
  ///       之前必须先换成十进制数值，否则它会把 `ans` 当成一个未知变量。回落分支故意把**原始**
  ///       表达式交给 [_calculateResult]，让它自己做同一件事——两次解析结果相同（`_ansValue…`
  ///       记下的正是第一次用的那个值），而跳过它会让 `_ansSource…` 被清空。
  ///
  ///       返回 null 表示**这次提交已经过期**（`generation` 不再是当前代际）：调用方什么都不许碰，
  ///       连回落计算也不许做——`_calculateResult` 会写 `_lastFiniteResult`，那也是过期时间线上的
  ///       状态。
  ///
  /// English: The result source for the *submit path* (only "pressed =" reaches it): ask the engine
  ///          first, fall back to the legacy parser when it cannot answer.
  ///
  ///          The fallback is a hard requirement, and the engine's failure is invisible to the
  ///          user: engine not loaded, no native side, aborted, timed out or failed to parse — the
  ///          user sees *today's* result or *today's* error, character for character. So the
  ///          condition for accepting the engine's answer is deliberately tight: it must be a
  ///          *finite decimal*, judged at the string level ([MathResult.hasFiniteDecimal]) and
  ///          never through a double:
  ///
  ///          - the engine has no decimal form (a result carrying a unit, say `1 m`): fall back;
  ///          - the decimal form is not a finite number at all (the `infinity` / `NaN` literals):
  ///            fall back too, so `1/0` still produces today's "result is not finite" rather than a
  ///            `无效` that looks like a result.
  ///
  ///          Judging finiteness at the string level matters because `2^2000 ≈ 1.148e+602` is a
  ///          perfectly correct finite result that merely overflows a double — `double.isFinite`
  ///          would throw the engine's right answer away, which is the very reason an exact engine
  ///          exists. The other end of the same root cause is underflow: `2^-2000 ≈ 9.3e-603`
  ///          becomes `0.0` through `double.tryParse`. See [MathResult.decimalValue].
  ///
  ///          The expression goes through [_resolveAnswerReferences] first, exactly as on the legacy
  ///          path: the engine does not know `Ans`/`last`, so they must be substituted before it is
  ///          asked, or it would treat `ans` as an unknown variable. The fallback branch hands the
  ///          *original* expression to [_calculateResult] on purpose, letting it do the same thing
  ///          itself — both resolutions produce the same string (`_ansValue…` holds exactly the
  ///          value the first one used), while skipping it would clear `_ansSource…`.
  ///          The resolved expression then goes through [_askEngineTranslated], the same single entry
  ///          point as-you-type uses, so both paths ask the engine the **translated** expression (fix
  ///          round 7's criterion; the submit path was still asking it the raw source when that
  ///          change landed).
  ///
  ///          A null return means *this submit is stale* (its `generation` is no longer current):
  ///          the caller must touch nothing at all, not even run the fallback — `_calculateResult`
  ///          writes `_lastFiniteResult`, and that too belongs to the stale timeline.
  @override
  Future<MathResult?> _submittedResult(String source, int generation) async {
    final resolvedSource = _resolveAnswerReferences(source);
    final reply = await _askEngineTranslated(resolvedSource);
    // 中文：回包到手的**第一件事**是问一句「这还是当前那一代吗」，在碰任何状态之前——包括
    //       回落分支会写的那份 `_lastFiniteResult`。
    // English: The *first* thing to do with a reply is ask "is this still the current generation",
    //          before touching any state — including the `_lastFiniteResult` the fallback writes.
    if (_disposed || generation != _stateRevision) return null;
    // 中文：**引擎说「这次换算没发生」时，那个答案不够用，回落也不够用。** 这不是引擎失败（硬性
    //       边界 1 说的是失败/超时/不可用），而是引擎给出的一条**确定回答**：`5 km to kg` 的两个
    //       量纲不相容，换算做不了。回落旧解析器也能得到一条错误（应用自己的语法没有单位），但那
    //       句话说的是「存在无法识别的内容」——在用户眼里它指的是 `km` 打错了，而真正的原因是
    //       这两个单位换不了。所以这一支在这里抛出**这一条**理由，由 `submit()` 既有的 catch 变成
    //       屏幕上的错误（`_friendlyCalculationError`）。**判定本身没有第二份**：「配不配显示」仍旧
    //       只由 [MathResult.isDisplayable] 回答（它把这一支判为不可显示，见
    //       [EngineResultKind.unitMismatch]），这里读的是同一条结论，只是把它翻成一句人能读的话。
    //       边打边算那条路不进这里：它的取舍拿到的仍然是 null，走它既有的「旧解析器作答」分支，
    //       所以这个异常永远不会从一条没有 try 的异步路径上抛出去。
    // English: **When the engine says "this conversion did not happen", that answer is not enough and
    //          neither is the fallback.** This is not an engine failure (hard boundary 1 is about
    //          failure/timeout/unavailability) but a **definite answer**: the dimensions of
    //          `5 km to kg` do not match, so the conversion cannot be done. Falling back would also
    //          produce an error (this app's grammar has no units), but that error says "unrecognised
    //          content" — which reads as "you mistyped `km`", while the real reason is that these two
    //          units do not convert. So this branch raises **that** reason here and `submit()`'s
    //          existing catch turns it into the message on screen (`_friendlyCalculationError`). **The
    //          judgement itself is not duplicated**: "may this be displayed" is still answered only by
    //          [MathResult.isDisplayable] (it calls this branch undisplayable; see
    //          [EngineResultKind.unitMismatch]) and this reads that same conclusion, only spelling it
    //          out for a human. The as-you-type path does not enter here: its selection still gets a
    //          null and takes its existing "the legacy parser answers" branch, so this exception can
    //          never be thrown from an async path with no try.
    if (reply.result?.resultKind == EngineResultKind.unitMismatch) {
      throw const FormatException('Unit mismatch: the conversion did not happen');
    }
    final selected = _selectEngineResult(reply, source);
    if (selected != null) {
      final accepted = selected.result;
      // 中文：`_lastFiniteResult` 只在这一份结果**能当数字用**时才更新，规则与 [applyMathResult]
      //       相同——数值消费者依旧只认有限十进制，放宽的是「能不能显示」，不是这一条。矩阵、复数
      //       这类结果的 `decimalText` 本来是空的，写进去等于把 `Ans`/`last` 变成空串，所以这里
      //       连试都不试。
      //       能当数字用时，它与十进制形态保持一致：`Ans`/`last` 用的是引擎的精确值，而不是显示
      //       取整后的那一份。放不进 double 的值也一样——存的是**文本**，写回表达式时用的就是它。
      // English: `_lastFiniteResult` is updated only while this result is **usable as a number**,
      //          the same rule as [applyMathResult] — numeric consumers still accept nothing but a
      //          finite decimal; what was relaxed is "may it be shown", not this. A matrix or a
      //          complex number carries an empty `decimalText` anyway, and writing that would turn
      //          `Ans`/`last` into an empty string, so it is not even attempted here.
      //          When it is usable as a number it stays in step with the decimal form: `Ans`/`last`
      //          resolve to the engine's accurate value rather than the display-rounded one. A value
      //          that does not fit a double is no different — what is kept is *text*, and that text
      //          is what gets written back into the expression.
      if (selected.usableAsNumber) {
        _lastFiniteResult = accepted.decimalText;
      }
      return accepted;
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

  /// 中文：问一次引擎，并给它一个上限。**提交路径与边打边算共用这一个入口。** 两件事都在这里做：
  ///
  ///       - **异常在这里停住**。[MathEngine] 的契约要求实现不抛异常，但调用方不能把「实现有
  ///         没有守约」当成本钱：守约失败时按「引擎没有可用结果」处理，而不是让一个只在设备上
  ///         出现的异常变成用户可见的错误。
  ///       - **等待在这里封顶**。[engineTimeout] 到点还没等到回执，就按「引擎没有可用结果」处理，
  ///         不是报错。没有它，原生一次卡死会让 `=` 从此静默失效到重启。
  ///
  ///       定时器是手写的而不是 `Future.timeout`：只有这样它才**属于控制器**，[dispose] 时能连
  ///       同还没回话的请求一起收掉。`Future.timeout` 的定时器拿不到句柄，控制器销毁后它还挂在
  ///       事件循环上（`flutter_test` 的「widget 树销毁后仍有定时器」正是查这个）。收掉时给在飞的
  ///       请求补一条失败回执，于是两边的 `await` 一定会返回——提交走既有的过期分支，边打边算走
  ///       [_evaluateWithEngine] 的 `_disposed` 分支——而不是永远悬着。
  ///
  ///       迟到的原生回包在这里被丢掉（completer 已经完成），所以它不会去覆盖任何已经落地的结果。
  ///
  /// English: Ask the engine once, with a bound. The submit path and as-you-type evaluation **share
  ///          this one entry point**. Two things happen here:
  ///
  ///          - **Exceptions stop here.** The [MathEngine] contract says implementations must not
  ///            throw, but a caller cannot stake its behaviour on the implementation keeping that
  ///            promise: a broken promise counts as "no usable result" instead of turning into a
  ///            user-visible error that only ever appears on a device.
  ///          - **The wait is capped here.** When [engineTimeout] elapses with no receipt the call
  ///            counts as "the engine has no usable result" — not an error. Without it one stuck
  ///            native call makes `=` silently dead until restart.
  ///
  ///          The timer is hand-rolled rather than `Future.timeout` precisely so that it *belongs to
  ///          the controller* and [dispose] can collect it together with the request still in
  ///          flight. A `Future.timeout` timer cannot be reached, so it stays on the event loop
  ///          after the controller is gone (which is exactly what flutter_test's "a timer is still
  ///          pending after the widget tree was disposed" catches). Collecting a pending request
  ///          hands it a failure receipt, so both `await`s always return — submit takes its existing
  ///          stale branch, as-you-type takes [_evaluateWithEngine]'s `_disposed` branch — instead of
  ///          hanging forever.
  ///
  ///          A late native reply is dropped here (the completer has already completed), so it can
  ///          never overwrite a result that has already landed.
  /// 中文：**问引擎之前先把表达式翻译成引擎的写法**（修复轮 7 的判据，见 `engine_expression.dart`）。
  ///       翻译不了就**不问**：那一条按「没有引擎答案」回执，回落旧解析器（硬性边界 1 的同一条路）。
  /// English: **translate the expression into the engine's language before asking it** (fix round 7's
  ///          criterion; see `engine_expression.dart`). When it cannot be translated the engine is
  ///          **not asked**: that counts as "no engine answer" and the legacy parser answers (the same
  ///          route as hard boundary 1).
  Future<EngineReply> _askEngineTranslated(String source) {
    final translated = engineExpressionFor(source);
    if (translated is UntranslatableExpression) {
      debugPrint('$qalculateLogTag 表达式翻译不了，直接走旧解析器: $translated');
      return Future.value(EngineReply.failure('untranslatable: $translated'));
    }
    return _askEngine((translated as TranslatedExpression).text);
  }

  Future<EngineReply> _askEngine(String expression) {
    final completer = Completer<EngineReply>();
    final timer = Timer(engineTimeout, () {
      _engineCalls.remove(completer);
      if (completer.isCompleted) return;
      completer.complete(
        EngineReply.failure(
            'engine_timeout: ${engineTimeout.inMilliseconds}ms'),
      );
    });
    _engineCalls[completer] = timer;

    /// 中文：引擎回话（或抛出来）时的收尾，两条路共用。
    /// English: The wrap-up for whichever way the engine answers (or throws); both paths share it.
    void settle(EngineReply reply) {
      _engineCalls.remove(completer);
      if (completer.isCompleted) return;
      timer.cancel();
      completer.complete(reply);
    }

    try {
      unawaited(
        _engine.evaluate(expression, angleMode: angleMode).then(
              settle,
              onError: (Object error) =>
                  settle(EngineReply.failure('engine_threw: $error')),
            ),
      );
    } catch (error) {
      // 中文：`evaluate` 在返回 Future 之前就抛了出来——异步方法抛算是被拒绝的 Future（走
      //       `onError`），但一个同步实现可以在返回之前直接抛。这一条在修复轮 1 把引擎调用搬出
      //       原来那个 `try` 时丢掉了，`=` 于是从「回落旧解析器」变成「表达式错误」；这里补回来，
      //       并且顺手把定时器收掉。
      // English: `evaluate` threw before it returned a Future — an `async` method's throw becomes a
      //          rejected future (handled by `onError`), but a synchronous implementation can throw
      //          before it returns at all. Fix round 1 lost this when it moved the engine call out of
      //          the old `try`, which turned "=" from a legacy fallback into "表达式错误"; this puts
      //          it back and collects the timer while it is at it.
      settle(EngineReply.failure('engine_threw: $error'));
    }
    return completer.future;
  }

  /// 中文：把引擎的结果变成屏幕上的结果。引擎的十进制形态是**未取整**的（16 位有效数字），显示
  ///       形态仍然由 `formatNumber` 按 `AppSettings.precision`（小数位数）取整——取整只有这一处
  ///       实现，边打边算与提交路径共用，用户在设置里选的位数对两条路径含义完全相同。引擎负责
  ///       算得准，Dart 负责显示成什么样。
  ///
  ///       **放不进 double 的结果**（`2^2000 ≈ 1.148e+602`、`2^-2000 ≈ 9.3e-603`）原样显示引擎
  ///       那一份十进制文本：Dart 手里没有可以取整的数（`decimalValue` 为 null），硬要走
  ///       `formatNumber` 只能先把 `Infinity` 或 `0` 喂进去，而那两个都是假值。取整规则没有被搬到
  ///       引擎里，只是对超出取整能力的结果不假装能取整。
  /// English: Turns the engine's result into the one on screen. The engine's decimal form is
  ///          *unrounded* (16 significant digits) while the display form still comes from
  ///          `formatNumber` at `AppSettings.precision` (a count of decimal places) — rounding has
  ///          exactly one implementation, shared by as-you-type and submit, so the digit count the
  ///          user picked means the same thing on both paths. The engine computes accurately; Dart
  ///          decides what it looks like.
  ///
  ///          A result that does not fit a double (`2^2000 ≈ 1.148e+602`, `2^-2000 ≈ 9.3e-603`) is
  ///          shown as the engine's own decimal text: Dart has no number to round (`decimalValue` is
  ///          null), and forcing it through `formatNumber` would mean feeding it `Infinity` or `0` —
  ///          both false. Rounding has not moved into the engine; the code just does not pretend to
  ///          round what it cannot represent.
  /// 中文：**引擎这一次的回答该怎么取舍**——提交路径与边打边算共用这一处，不写第二份。
  ///       三级，顺序不能反：
  ///
  ///       1. **词表说引擎读不了这个表达式**（[AppEngineVocabulary.canRead]）→ 没有引擎答案。
  ///          这是**名字层**的第二道判断（翻译管的是「这个名字在引擎里怎么写」，它管的是
  ///          「这个名字的答案能不能用」），两道都不放宽对方。
  ///       2. **能当数字用**（有限十进制）→ 用引擎的。与迁移引擎之前逐字节一致：数值消费者要的
  ///          就是它，`Ans`/`last` 拿到的是引擎的精确十进制。
  ///       3. **只能显示**（矩阵、复数、符号结果…）→ 用引擎的显示形态。
  ///
  ///       **值比较（修复轮 6）已经不在这里了，这是有意的。** 它问的是「引擎的值与应用的
  ///       `double` 一致吗」，而那个问题的前提是错的：**在引擎真正有价值的场合——超出 double
  ///       量程、灾难性相消、大角度——应用的 `double` 恰恰是错的那一方。** 活着的三个错值就是它
  ///       造成的：`123456789012345678-123456789012345677` 被判成「引擎读错了」而显示应用下溢的
  ///       `0`（引擎与数学都是 `1`）；DEG 下 `tan(1e12)` 因为应用自己 `arg*pi/180` 的舍入超出容差，
  ///       引擎的正确答案被丢掉；`1/3000000000pi` 显示应用自己解析出的 `1.061033e-10` 而不是
  ///       `1.047198e-9`。三者都由 1 级之下的翻译消歧义之后消失：**交给引擎的是翻译后的表达式**
  ///       （`engine_expression.dart`），所以它这一份答案就是权威，应用不必、也不该再拿自己的值
  ///       去比。
  ///
  ///       `usableAsNumber` 就是第 2 级与第 3 级的分界，调用方据此决定 `_lastFiniteResult`——
  ///       数值消费者依旧只认有限十进制，这一条**没有放宽**。
  /// English: **How this engine answer is to be taken** — the submit path and as-you-type evaluation
  ///          share this one place; no second copy. Three tiers, and the order matters:
  ///
  ///          1. **the vocabulary says the engine cannot read this expression**
  ///             ([AppEngineVocabulary.canRead]) → no engine answer. That is the **name layer**'s
  ///             second judgement (the translation decides *how to write* a name for the engine, this
  ///             decides *whether that name's answer may be used*); neither relaxes the other.
  ///          2. **usable as a number** (a finite decimal) → take the engine's. Byte-for-byte what it
  ///             was before the engine was wired in: numeric consumers want exactly this, and
  ///             `Ans`/`last` get the engine's accurate decimal.
  ///          3. **displayable only** (a matrix, a complex number, a symbolic result, …) → take the
  ///             engine's display form.
  ///
  ///          **The value comparison (fix round 6) is deliberately gone from here.** It asked "does the
  ///          engine's value match this app's `double`", and that question's premise is false: **in
  ///          exactly the cases the engine exists for — beyond the double range, catastrophic
  ///          cancellation, large angles — this app's `double` is the wrong side.** Three live wrong
  ///          values came from it: `123456789012345678-123456789012345677` was called a misreading and
  ///          shown as the app's underflowed `0` (the engine and the mathematics both say `1`); in DEG
  ///          `tan(1e12)` lost the engine's correct answer because the app's own `arg*pi/180` rounding
  ///          exceeded the tolerance; `1/3000000000pi` showed `1.061033e-10` (the app's own reading)
  ///          instead of `1.047198e-9`. All three end once gate 1's translation removes the ambiguity:
  ///          **what reaches the engine is the translated expression** (`engine_expression.dart`), so
  ///          its answer is the authority, and the app neither has to nor should compare its own value
  ///          against it.
  ///
  ///          `usableAsNumber` is the boundary between tiers 2 and 3, and the caller uses it to decide
  ///          `_lastFiniteResult` — numeric consumers still accept nothing but a finite decimal, and
  ///          that has **not** been relaxed.
  ({MathResult result, bool usableAsNumber})? _selectEngineResult(
    EngineReply reply,
    String source,
  ) {
    // 中文：**引擎读不懂这个表达式时，它的答案一律不算。** 判据在
    //       [AppEngineVocabulary.canRead] 一处（应用自己的封闭词表 × 引擎自己的符号表），
    //       与结果的形状无关——`npr(2,1.5)` 与 `npr(,)` 被引擎读成符号 `n'p''r'`，返回的是**一个
    //       矩阵**，只按形状判会放它上屏（实测过）。这里返回 null，调用方按「这一次没有引擎答案」
    //       处理：旧解析器作答（`npr(2,1.5)` → 「nPr 的 r 必须是整数」），它答不出来就是错误——
    //       与引擎缺席、超时、失败走的是同一条路（硬性边界 1）。
    // English: **when the engine cannot read this expression its answer does not count at all.** The
    //          test lives in one place ([AppEngineVocabulary.canRead]: this app's closed
    //          vocabulary × the engine's own symbol table) and is independent of the result's shape —
    //          `npr(2,1.5)` and `npr(,)` are read by the engine as the symbols `n'p''r'` and come back
    //          as **a matrix**, which a shape-only rule lets onto the screen (measured). Returning
    //          null here means "no engine answer this time": the legacy parser answers
    //          (`npr(2,1.5)` → "nPr's r must be an integer"), and when it cannot, that is an error —
    //          the same route as an absent, timed-out or failed engine (hard boundary 1).
    if (!AppEngineVocabulary.canRead(source)) return null;
    final engineResult = reply.result;
    if (engineResult == null) return null;

    if (MathResult.decimalTextIsFinite(engineResult.decimalText)) {
      // 中文：有限十进制 ⇒ 直接用（与引擎接进提交路径之前逐字节一致：那一步没有形状字段）。
      //       文本有限而 double 装不下的（`2^2000`/`2^-2000`）也在这里：判据在**字符串层面**，
      //       不借 double——否则引擎最不可替代的那类结果会被丢掉。
      // English: a finite decimal ⇒ used directly (byte-for-byte what it was before the shape field
      //          existed on the submit path). Text that is finite but does not fit a double
      //          (`2^2000`/`2^-2000`) lands here too: the test is **at the string level**, never through
      //          a double, or the results the engine is least replaceable for would be thrown away.
      return (result: _engineMathResult(engineResult), usableAsNumber: true);
    }
    // 中文：**不是有限十进制**——矩阵、复数这些「应用语言表达不了的类型」由形状判据放行，其余
    //       （带单位、未求值的算式）挡下，调用方按「这一次没有引擎答案」处理。
    // English: **not a finite decimal** — the shape judgement lets through the types this app's language
    //          cannot express (matrices, complex numbers) and holds back the rest (unit-carrying
    //          quantities, unevaluated expressions), which the caller takes as "no engine answer this
    //          time".
    return engineResult.isDisplayable
        ? (result: _engineMathResult(engineResult), usableAsNumber: false)
        : null;
  }

  MathResult _engineMathResult(MathResult engineResult) {
    final value = engineResult.decimalValue;
    if (value == null) return engineResult;
    return MathResult(
      displayText: formatNumber(
        value,
        precision: _settings.precision,
        groupThousands: _settings.groupThousands,
      ),
      displayTex: engineResult.displayTex,
      decimalText: engineResult.decimalText,
      // 中文：`resultKind` 必须跟着走。丢了它，重建出来的结果会带上 `notFromEngine`——
      //       而那个值在 [MathResult.isDisplayable] 里是**放行**的一支，于是这句 doc 说的
      //       「不是来自引擎」就成了假话，判断也跟着变宽。今天没有消费者读重建之后那一份的
      //       `isDisplayable`，但那是**碰巧**，不是设计。
      // English: `resultKind` has to travel with it. Dropping it leaves the rebuilt result carrying
      //          `notFromEngine` — which [MathResult.isDisplayable] treats as **displayable** — so the
      //          doc's "not from the engine" would be a lie and the judgement would widen with it.
      //          Nothing reads the rebuilt copy's `isDisplayable` today, but that is a coincidence,
      //          not a design.
      resultKind: engineResult.resultKind,
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

  /// 中文：**显示侧的防抖**：连续输入期间合并实时求值，输入立刻上屏、结果稍后统一刷新。窗口长度
  ///       [liveEvaluationDelay] 就是「第一个结果什么时候出现」，见 [kLiveEvaluationDelay]——它与
  ///       引擎跟进那一个延迟（[kLiveEngineFollowUpDelay]，针对跨语言调用）**不是同一件事**，所以
  ///       这一步不动它：裁决 1 要的即时反馈正是由它保证的。引擎调用也不在这个定时器里发——
  ///       [evaluate] 自己会排。
  ///
  /// English: The **display-side** debounce: live evaluation is coalesced during fast typing, the input
  ///          goes up at once and results refresh together. Its window [liveEvaluationDelay] *is*
  ///          "when the first result appears", see [kLiveEvaluationDelay] — it is **not the same
  ///          thing** as the engine follow-up delay ([kLiveEngineFollowUpDelay], which is about a
  ///          cross-language call), so this step leaves it alone: ruling 1's instant feedback is
  ///          exactly what it guarantees. The engine call is not issued from this timer either;
  ///          [evaluate] schedules it itself.
  @override
  void _scheduleLiveEvaluation() {
    _liveEvaluationTimer?.cancel();
    _liveEvaluationTimer = Timer(liveEvaluationDelay, () {
      if (_disposed) return;
      evaluate();
      unawaited(_persistState());
      notifyListeners();
    });
  }

}
