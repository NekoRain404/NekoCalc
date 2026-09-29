part of 'calculator_controller.dart';

/// 中文：**提交路径与两条路共用的那两件事。** `on` 子句里的两个混因都是顺序承重的：选好的答案由
///       [_CalculatorEngineDisplay] 画出来（`_engineMathResult`），而边打边算那一条路
///       （`_CalculatorLiveEvaluation`）排在本混因**之后**，它读的正是这里的 `_selectEngineResult`
///       与 `_askEngineTranslated`——顺序写在 `calculator_controller.dart` 的 `with` 列表上。
///       **这一轮从本文件搬走的只有边打边算那条流程**（两个防抖定时器、在飞上限、代际守卫），
///       提交路径、答案的取舍与那个共用的入口都留在这里。
/// English: **the submit path plus the two things both roads share.** Both mixins in the `on` clause
///          are order-load-bearing: the selected answer is drawn by [_CalculatorEngineDisplay]
///          (`_engineMathResult`), and the as-you-type road (`_CalculatorLiveEvaluation`) is applied
///          **after** this mixin because it reads this side's `_selectEngineResult` and
///          `_askEngineTranslated` — the order is recorded on the `with` list in
///          `calculator_controller.dart`. **All this round moved out of this file is the as-you-type
///          flow** (the two debounce timers, the in-flight bound, the generation guard); the submit
///          path, the selection of an answer and that shared entrance all stay.
mixin _CalculatorEvaluation on _CalculatorState, _CalculatorEngineDisplay {

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
  ///       解析失败，用户看到的都是**今天那条结果或那条错误**，一字不差。但接受引擎答案的条件
  ///       **不止一条**——[_selectEngineResult] 有若干出口，下面两条只是其中**第三级**：
  ///
  ///       - 引擎没有十进制形态（`1 m` 这类带单位的结果）：第三级挡下，落到第四级；
  ///       - 十进制形态根本不是有限数（`infinity` / `NaN`）：同样下落，`1/0` 仍是你今天看到的
  ///         那条「结果不是有限数值」，而不是一个看着像结果的 `无效`。
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
  ///          user sees *today's* result or *today's* error, character for character. Accepting the
  ///          engine's answer is **more than one test**, and they do not ask the same question —
  ///          [_selectEngineResult] has several exits; the two below are only its **third level**:
  ///
  ///          - the engine has no decimal form (a result carrying a unit, say `1 m`): stopped at
  ///            the third level, left to the fourth;
  ///          - the decimal form is not a finite number at all (the `infinity` / `NaN` literals):
  ///            same, so `1/0` still produces today's "result is not finite" rather than a `无效`
  ///            that looks like a result.
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
    final answer = await _askEngineTranslated(resolvedSource);
    final reply = answer.reply;
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
    // 中文：**一条关系被引擎答成了一个数 ⇒ 抛出一条人能读的话，不是把那个数放上屏幕。**
    //       这一支与上面那条 `Unit mismatch` 是同一个形状，理由也一样：回落旧解析器也会得到
    //       一条错误（应用自己的语法没有等号），但那句话说的是「存在无法识别的内容」——
    //       用户看到的是"我打错了"，而真正的原因是**这个方程没有解**。所以在这里抛出
    //       **这一条**理由，由 `submit()` 既有的 catch 变成屏幕上的错误。
    //
    //       边打边算那条路**不抛**（它没有 try），它读到的是 [MathResult.isDisplayable] 那一条
    //       结论——[_selectEngineResult] 对同一支回 `null`，于是屏幕上什么都不显示。
    //       两条路的**判据是同一个** [_relationCameBackAsTruthValue]。
    // English: **a relation answered as a number ⇒ raise a sentence a human can read, do not put that
    //          number on screen.** This branch has the same shape as the `Unit mismatch` one above and
    //          the reason is the same: falling back to the legacy parser also yields an error (this
    //          app's grammar has no equals sign), but that error says "unrecognised content" — the user
    //          reads "I typed something wrong" while the real reason is **this equation has no
    //          solution**. So **that** reason is raised here and `submit()`'s existing catch turns it
    //          into the message on screen.
    //
    //          The as-you-type path does **not** throw (it has no try): it reads the same conclusion
    //          through [MathResult.isDisplayable] — [_selectEngineResult] returns `null` for this
    //          branch, so nothing is displayed. **Both paths share one judgement**,
    //          [_relationCameBackAsTruthValue].
    if (_relationCameBackAsTruthValue(answer)) {
      throw const FormatException('Relation has no numeric answer');
    }
    final selected = _selectEngineResult(answer, source);
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
  /// 中文：**返回值里那个 `isRelation` 与回包是同一个东西的两半，必须一起传。**
  ///       「这一次的输入是一条关系（`2x+1=7`）」只能由翻译结果回答，而翻译正是在这里做的——
  ///       少传这一个布尔，采用规则那一层就分不出「引擎回了一个数」与「引擎回了一个布尔值」，
  ///       而这两者在它眼里**长得一模一样**（都是 `0` 或 `1` 的有限十进制）。
  ///
  ///       两半一起返回而不是让调用方自己再译一次：再译一次是同一个纯函数调两遍，
  ///       而判据会因此有**两个拼法**——本仓的规矩是同一句话只留一个源。
  /// English: **the `isRelation` in the return value and the reply are two halves of one thing and
  ///          travel together.** "This input was a relation (`2x+1=7`)" can only be answered by the
  ///          translation, and the translation happens here — drop that one boolean and the taking rule
  ///          cannot tell "the engine returned a number" from "the engine returned a truth value",
  ///          which **look identical to it** (both a finite decimal `0` or `1`).
  ///
  ///          Both halves come back together rather than letting the caller re-translate: a second call
  ///          is one pure function called twice, and the judgement would end up with **two spellings** —
  ///          this repository keeps one source per sentence.
  Future<({EngineReply reply, bool isRelation})> _askEngineTranslated(
      String source) async {
    final translated =
        engineExpressionFor(source, relativePercent: relativePercent);
    if (translated is UntranslatableExpression) {
      debugPrint('$qalculateLogTag 表达式翻译不了，直接走旧解析器: $translated');
      return (
        reply: EngineReply.failure('untranslatable: $translated'),
        isRelation: false,
      );
    }
    final text = (translated as TranslatedExpression).text;
    return (
      reply: await _askEngine(text),
      isRelation: translated.isRelation,
    );
  }

  /// 中文：**「一条关系被引擎答成了一个数」——那是一个布尔值，不是答案。**
  ///
  ///       实测（宿主 `qalc` 5.12.0，桥自己的调用序列，见
  ///       `.superpowers/backup/engine-capability-probe.md` 第八节）三种输入落在这一支：
  ///
  ///       | 输入 | 引擎种类 | 印出来 | 真实含义 |
  ///       |---|---|---|---|
  ///       | `x^2=-1` | `number` | `0` | 实数范围内**无解** |
  ///       | `1=2` | `number` | `0` | 等式**不成立** |
  ///       | `x=x` | `number` | `1` | 恒等式 |
  ///
  ///       而**真解一条都不在这一支**：`2x+1=7` → `x = 3`、`x^2=4` → `x = 2 || x = -2` 的引擎种类
  ///       分别是 `COMPARISON` 与 `OR`，在应用这一侧都判成 `symbolic`——那是 `isDisplayable`
  ///       放行的那一支。**所以「关系 ∧ number」这条判据不误伤任何一个真解。**
  ///
  ///       ⚠️ **判据只看形状，不看印出来的文本。** 写成"`0` 或 `1` 就不收"也能挡住今天这三个，
  ///       但那是一条举例清单：引擎换一种印法（`1.000000`）、或者哪一天多出第四种退化形状，
  ///       清单就漏了。这里问的是**引擎把这条关系当成了哪一类值**——`number` 意味着它算出了一个
  ///       **数**，而关系没有"数"这种答案。
  ///
  ///       判据只此一处，两个调用点（提交与边打边算）读的都是它。
  /// English: **"a relation came back as a number" — that is a truth value, not an answer.**
  ///
  ///          Measured (host `qalc` 5.12.0, the bridge's own call sequence; see section 八 of
  ///          `.superpowers/backup/engine-capability-probe.md`) three inputs land here:
  ///
  ///          | input | engine kind | printed | what it means |
  ///          |---|---|---|---|
  ///          | `x^2=-1` | `number` | `0` | **no solution** over the reals |
  ///          | `1=2` | `number` | `0` | the equation is **false** |
  ///          | `x=x` | `number` | `1` | an identity |
  ///
  ///          and **not one genuine solution is in this branch**: `2x+1=7` → `x = 3` has engine kind
  ///          `COMPARISON` and `x^2=4` → `x = 2 || x = -2` has `OR`, both of which this side classifies
  ///          as `symbolic` — the branch `isDisplayable` lets through. **So "relation ∧ number" costs no
  ///          real solution anything.**
  ///
  ///          ⚠️ **The test reads shape, not printed text.** "Refuse a `0` or a `1`" would also stop
  ///          today's three, but that is a list of examples: let the engine print `1.000000` or add a
  ///          fourth degenerate shape and the list misses it. What is asked here is **which kind of
  ///          value the engine made of this relation** — `number` means it produced a **number**, and a
  ///          relation has no such answer.
  ///
  ///          The judgement lives here alone; both call sites (submit and as-you-type) read it.
  bool _relationCameBackAsTruthValue(
          ({EngineReply reply, bool isRelation}) answer) =>
      answer.isRelation &&
      answer.reply.result?.resultKind == EngineResultKind.number;

  @override
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

  /// 中文：**引擎那一份答案选出来之后怎么画在屏幕上**——取整只有这一处实现，选出来的那一份由
  ///       `calculator_controller_engine_display.dart` 画（本文件到了 800 行那条硬边界，那一半
  ///       本轮搬了出去；本文件只到「取哪一份」为止）。
  ///
  ///       引擎的十进制形态是**未取整**的（16 位有效数字），显示形态由 `formatNumber` 按
  ///       `AppSettings.precision`（小数位数）取整——取整只有这一处实现，边打边算与提交路径共用，
  ///       用户在设置里选的位数对两条路径含义完全相同。引擎负责算得准，Dart 负责显示成什么样。
  ///
  ///       **放不进 double 的结果**（`2^2000 ≈ 1.148e+602`、`2^-2000 ≈ 8.7e-603`）原样显示引擎
  ///       那一份文本（带单位的同理，见 `quantity_display.dart`）：Dart 手里没有可以取整的数
  ///       （`decimalValue` 为 null），硬要走 `formatNumber` 只能先把 `Infinity` 或 `0` 喂进去，
  ///       而那两个都是假值。取整规则没有被搬到引擎里，只是对超出取整能力的结果不假装能取整。
  /// English: **how the chosen engine answer is drawn on screen** — rounding has this one
  ///          implementation, and the chosen answer is drawn by
  ///          `calculator_controller_engine_display.dart` (this file reached the hard 800-line bound,
  ///          so that half moved out this round; what is left here stops at "which answer is taken").
  ///
  ///          The engine's decimal form is *unrounded* (16 significant digits) while the display form
  ///          comes from `formatNumber` at `AppSettings.precision` — rounding has exactly one
  ///          implementation, shared by as-you-type and submit, so the digit count the user picked
  ///          means the same thing on both paths. The engine computes accurately; Dart decides what it
  ///          looks like.
  ///
  ///          A result that does not fit a double (`2^2000 ≈ 1.148e+602`, `2^-2000 ≈ 8.7e-603`) is
  ///          shown as the engine's own text (a unit-carrying one likewise, see
  ///          `quantity_display.dart`): Dart has no number to round (`decimalValue` is null), and
  ///          forcing it through `formatNumber` would mean feeding it `Infinity` or `0` — both false.
  ///          Rounding has not moved into the engine; the code just does not pretend to round what it
  ///          cannot represent.
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
    ({EngineReply reply, bool isRelation}) answer,
    String source,
  ) {
    final reply = answer.reply;
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
    // 中文：**符号结果只在应用自己的语言表达不了这个输入时才收。** 与上面那条
    //       [AppEngineVocabulary.canRead] 同一手法：应用侧判据为真 ⇒ 返回 null ⇒ 调用方按「这一次
    //       没有引擎答案」处理，旧解析器作答。判据与它的实测都在
    //       [AppEngineVocabulary.canExpress]（`pi!` 那一条）。
    // English: **a symbolic result is taken only when this app's own language cannot express this
    //          input.** The same device as the [AppEngineVocabulary.canRead] check above: the
    //          app-side judgement is true ⇒ null ⇒ the caller reads it as "no engine answer this
    //          time" and the legacy parser answers. The judgement and its measurement are on
    //          [AppEngineVocabulary.canExpress] (`pi!`).
    if (engineResult.resultKind == EngineResultKind.symbolic &&
        AppEngineVocabulary.canExpress(source)) {
      return null;
    }

    // 中文：**这一条必须排在「有限十进制 ⇒ 直接用」之前。** 它挡下的正是那一条本来会收下的东西：
    //       `x^2=-1` 的 `0`、`1=2` 的 `0`、`x=x` 的 `1` **全都是有限十进制**。
    //       判据与理由是 [_relationCameBackAsTruthValue] 那一处，这里只是把它读出来。
    // English: **this has to come before "a finite decimal ⇒ used directly"**, because what it refuses
    //          is exactly what that rule would otherwise take: the `0` of `x^2=-1`, the `0` of `1=2` and
    //          the `1` of `x=x` **are all finite decimals**. The judgement and its reasoning are on
    //          [_relationCameBackAsTruthValue]; this only reads it.
    if (_relationCameBackAsTruthValue(answer)) return null;
    if (decimalTextIsFinite(engineResult.decimalText)) {
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

  // 中文：**「引擎这一份答案怎么画」不在这里**——它搬到了 `calculator_controller_engine_display.dart`
  //       （本文件到了 800 行那条硬边界，而这一步正好是那条缝：「选哪一份答案」留在这里，
  //       「那一份怎么画」搬过去）。`_engineMathResult` 是那一边的入口，调用点一个字没改。
  // English: **how the chosen engine answer is drawn is not here** — it moved to
  //          `calculator_controller_engine_display.dart` (this file reached the hard 800-line bound,
  //          and this is exactly where the seam is: "which answer is taken" stays here, "how that
  //          answer is drawn" goes there). `_engineMathResult` is that side's entry point, and its
  //          call sites did not change by one character.

  /// 中文：旧求值器的唯一出口——它只产出一个 `double`，所以三形态里的 LaTeX 是空的，而显示文本
  ///       同时也是十进制文本。这是引擎缺席时（以及引擎答不出来时）用的那一条路。
  /// English: The legacy evaluator's only exit. It produces a bare `double`, so the LaTeX form is
  ///          empty and the display text doubles as the decimal text. This is the path used while
  ///          the engine is absent — and whenever it cannot answer.
  MathResult _calculateResult(String source) {
    final resolvedSource = _resolveAnswerReferences(source);
    final value = ExpressionParser(
      resolvedSource,
      degreeMode: angleMode == 'DEG',
      // 中文：与 `_askEngineTranslated` 传的必须是同一个值——同一个输入的两个消费者。
      // English: must be the same value `_askEngineTranslated` passes: two consumers of one input.
      relativePercent: relativePercent,
    ).parse();
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
}
