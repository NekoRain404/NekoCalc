part of 'calculator_controller.dart';

/// 中文：**「问一次引擎，并给它一个上限」——就这一件事。**
///
///       它为什么是单独一个混因：这一组文件已经贴着 800 行那条硬边界（见
///       `calculator_controller_evaluation.dart` 的头部记录），而这件事**自成一件事**——它是提交路径与
///       边打边算**共用的唯一入口**，读的只有 `_engine`、`engineTimeout` 与 `_engineCalls` 三样，因此可以
///       整块搬出来。搬出来之后 `calculator_controller_evaluation.dart` 从 798 行降到 755 行，那条边界
///       于是有了真正的余量，而不是"下一笔改动刚好撞上"。
///
///       ⚠️ **顺序承重**：本混因必须排在 `_CalculatorEvaluation` **之前**（写在
///       `calculator_controller.dart` 的 `with` 列表上），因为它提供的 `_askEngine` 正是后者要调用的那一个。
///       换顺序是一个**编译错误**，不是一条静默的错行为——这与那两处既有的顺序注释是同一种承重。
///
/// English: **one job: ask the engine once, with a ceiling on the wait.**
///
///          Why it is its own mixin: this group of files sits on the 800-line hard boundary (see the note at
///          the head of `calculator_controller_evaluation.dart`), and this job is **self-contained** — it is
///          the **single entry point shared by** the submit path and as-you-type evaluation, and it reads
///          only `_engine`, `engineTimeout` and `_engineCalls`, so it lifts out whole. Lifting it out takes
///          `calculator_controller_evaluation.dart` from 798 lines to 755, which gives that boundary real
///          headroom instead of leaving the next change to collide with it.
///
///          ⚠️ **The order is load-bearing**: this mixin must precede `_CalculatorEvaluation` on the `with`
///          list in `calculator_controller.dart`, because it provides the `_askEngine` the other calls.
///          Reordering is a **compile error**, not a silent misbehaviour — the same kind of load-bearing
///          order the two existing comments on that list describe.
mixin _CalculatorEngineWait on _CalculatorState {
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
}
