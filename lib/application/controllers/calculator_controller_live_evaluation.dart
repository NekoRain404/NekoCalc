part of 'calculator_controller.dart';

/// 中文：**边打边算这一条路**——输入时先上旧解析器的结果，再排一发引擎跟进，回包到达时替换。
///
///       **这条缝为什么在这里。** 求值这一组里有两条**流程**：一条是用户按下等号（提交路径，
///       住在 `calculator_controller_evaluation.dart`），另一条是边打字边算（这一条）。两者共用的
///       东西——「问引擎一次、带等待上限」与「引擎这一份答案该怎么取舍」——留在那个文件里；这一
///       边是**流程本身**：两个防抖定时器、在飞上限为 1、「还欠一次」、代际守卫与过期回包一律
///       丢弃。它们的读者不同（提交那一份读的是「这一次提交的结果是什么」，这一份读的是「上一发
///       还没回来时又打了一个字」），而「边打边算要不要走引擎」那个开关也只对这条路说话。
///
///       **顺序承重。** `calculator_controller.dart` 的 `with` 列表上本混因排在
///       `_CalculatorEvaluation` 之后（`on` 子句写着），因为答案的取舍（`_selectEngineResult`）与
///       那个共用的入口（`_askEngineTranslated`）住在那一边；反过来 `_CalculatorEvaluation` 只在
///       `_CalculatorState` 声明的抽象成员上碰这条路的三个入口（`evaluate`/`_cancelLiveEvaluation`/
///       `_scheduleLiveEvaluation`），所以两者之间没有环。换顺序是一个编译错误。
///
///       **搬的只是位置**：两个防抖窗口、在飞上限、代际守卫与每一条注释都逐字搬了过来。
///
/// English: **the as-you-type road** — on input the legacy parser's result goes up first, one engine
///          follow-up is scheduled, and its reply replaces that result when it lands.
///
///          **Why the seam is here.** The evaluation group holds two **flows**: one where the user
///          presses `=` (the submit path, in `calculator_controller_evaluation.dart`) and this one,
///          where typing evaluates. What the two share — "ask the engine once, with a bound" and "how
///          this engine answer is to be taken" — stays in that file; this side is the **flow itself**:
///          the two debounce timers, the one-call-in-flight bound, "one more is owed", the generation
///          guard and the dropping of every stale reply. Their readers differ (the other one reads
///          "what is this submit's result", this one reads "another character arrived while a call was
///          still out"), and the "does as-you-type use the engine" switch speaks to this road alone.
///
///          **The order is load-bearing.** On the `with` list in `calculator_controller.dart` this
///          mixin comes after `_CalculatorEvaluation` (the `on` clause records it), because the
///          answer's selection (`_selectEngineResult`) and the shared entrance
///          (`_askEngineTranslated`) live on that side; in the other direction `_CalculatorEvaluation`
///          touches this road's three entrances (`evaluate`/`_cancelLiveEvaluation`/
///          `_scheduleLiveEvaluation`) only through abstract members declared on `_CalculatorState`,
///          so there is no cycle. Reordering is a compile error.
///
///          **Only the position moved**: both debounce windows, the in-flight bound, the generation
///          guard and every comment came across character for character.

mixin _CalculatorLiveEvaluation
    on _CalculatorState, _CalculatorEvaluation {
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
    // 中文：`answer` 而不是 `reply`——它多带一个「这一次的输入是一条关系」。
    //       那个布尔在这里只被 [_selectEngineResult] 读一次，用途只有一个：
    //       分清引擎回的是**一个数**还是**一个布尔值**（两者都是 `0`/`1` 的有限十进制）。
    // English: `answer` rather than `reply` — it carries one extra fact, "this input was a relation".
    //          That boolean is read exactly once, by [_selectEngineResult], for one purpose: telling
    //          **a number** from **a truth value** (both are the finite decimals `0`/`1`).
    final answer = await _askEngineTranslated(_resolveAnswerReferences(source));
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
    final accepted = _selectEngineResult(answer, source)?.result;
    if (accepted == null) {
      if (_relationHasNoAnswer(answer)) {
        // 中文：**一条关系永远不由旧解析器作答。** 应用自己的语法里没有等号，旧解析器对一条关系
        //       只能说「函数需要括号」——那是**说岔了**，不是答案。真机上量到过这一句（见
        //       [kRelationTruthValueVerdict]），所以这里与提交路径**说同一句话**，
        //       翻法也走同一个 `_friendlyCalculationError`。
        // English: **a relation is never answered by the legacy parser.** This app's grammar has no
        //          equals sign, so the legacy parser can only say "function needs parentheses" about a
        //          relation — that is **saying the wrong thing**, not an answer. It was measured on the
        //          device (see [kRelationTruthValueVerdict]), so this says **the same sentence** the
        //          submit path says, turned by the same `_friendlyCalculationError`.
        _result = MathResult.pending;
        hasError = true;
        errorMessage = _friendlyCalculationError(
            const FormatException(kRelationTruthValueVerdict));
        unawaited(_persistState());
        notifyListeners();
      } else if (!liveResultPolicy.showsLegacyResult) {
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
