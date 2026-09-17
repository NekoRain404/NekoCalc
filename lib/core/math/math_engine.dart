import 'package:flutter/foundation.dart';

import 'math_result.dart';

/// 中文：一次引擎求值的**传输层**回执：引擎答没答出来、答的是什么、为什么没答出来。
///
///       它与 [MathResult] 刻意分开：[MathResult] 是**显示**概念（给人看的、给排版看的、给机器
///       算的三个形态），`ok` / `aborted` / `error` 是**传输**概念（这一次调用成功了吗）。把传输
///       概念塞进结果类型，显示侧的每个消费者就都要先问一句「这个结果是不是真的」，而那正是
///       3c 要消灭的模糊状态。
///
/// English: The *transport-level* receipt of one engine evaluation: whether the engine answered,
///          what it answered, and why it did not. It is deliberately separate from [MathResult]:
///          that type is a *display* concept (the three forms: for people, for typesetting, for
///          machines), while `ok` / `aborted` / `error` are *transport* concepts (did this call
///          succeed at all). Putting transport concerns into the result type would force every
///          display-side consumer to first ask "is this result real?", which is exactly the
///          ambiguity step 3c set out to delete.
@immutable
class EngineReply {
  const EngineReply._({
    required this.ok,
    required this.result,
    required this.error,
    required this.aborted,
    required this.messages,
  });

  /// 中文：引擎给出了一个可用结果。[result] 非空。`aborted` 恒为 false——被中止的求值不算答案。
  ///       [result] 在这里是**非空**类型：成功却带着空结果是一个不该被表达出来的状态。
  /// English: The engine produced a usable result. [result] is non-null. `aborted` is always false:
  ///          an aborted evaluation is not an answer. [result] is non-nullable here, because
  ///          "succeeded with no result" is a state that should not be expressible.
  factory EngineReply.success(MathResult result, {String messages = ''}) {
    return EngineReply._(
      ok: true,
      result: result,
      error: null,
      aborted: false,
      messages: messages,
    );
  }

  /// 中文：引擎没有给出可用结果——未加载、通道缺席、超时、被中止、解析失败都走这里。
  ///       **这不是异常**：调用方按「这一次没有引擎结果」处理，而不是 try/catch。
  /// English: The engine produced no usable result — not loaded, no platform side, timeout,
  ///          aborted, parse failure. This is *not* an exception: callers treat it as "no engine
  ///          result this time" rather than wrapping the call in try/catch.
  factory EngineReply.failure(
    String error, {
    String messages = '',
    bool aborted = false,
  }) {
    return EngineReply._(
      ok: false,
      result: null,
      error: error,
      aborted: aborted,
      messages: messages,
    );
  }

  /// 中文：这一次调用是否有可用结果。为真时 [result] 一定非空。
  /// English: Whether this call produced a usable result. When true, [result] is non-null.
  final bool ok;

  /// 中文：引擎的结果（三形态）。[ok] 为假时恒为 null。
  /// English: The engine's result in its three forms. Always null when [ok] is false.
  final MathResult? result;

  /// 中文：失败原因，写给日志和测试看，**不是**给用户看的文案（回落到旧解析器后用户看到的
  ///       是今天那条结果或那条错误，引擎失败本身对用户不可见）。
  /// English: Why it failed, for logs and tests — *not* user-facing copy. After the fallback the
  ///          user sees today's result or today's error; the engine failure itself stays invisible.
  final String? error;

  /// 中文：原生侧的 `aborted`。被中止的求值不产生可用结果，所以它出现时 [ok] 必为假，
  ///       这里仍把它单独带回来，好让日志能区分「中止」与「报错」。
  /// English: The native `aborted` flag. An aborted evaluation yields no usable result, so [ok] is
  ///          false whenever it is set; it is still carried separately so logs can tell "aborted"
  ///          from "failed".
  final bool aborted;

  /// 中文：原生引擎在这次求值期间排进消息队列的内容（警告、提示），只为诊断存在。
  /// English: What the native engine queued while evaluating (warnings, hints); diagnostics only.
  final String messages;

  @override
  bool operator ==(Object other) {
    return other is EngineReply &&
        other.ok == ok &&
        other.result == result &&
        other.error == error &&
        other.aborted == aborted &&
        other.messages == messages;
  }

  @override
  int get hashCode => Object.hash(ok, result, error, aborted, messages);

  @override
  String toString() {
    return 'EngineReply(ok: $ok, result: $result, error: $error, '
        'aborted: $aborted, messages: $messages)';
  }
}

/// 中文：可以求值的引擎。存在的理由是**可被测试替身替换**：真引擎只有设备上才有，而提交路径的
///       回落行为必须能在 `flutter test` 里断言。
///
///       实现**不得抛异常**：引擎不可用、通道缺席、解析失败一律通过 [EngineReply] 报告。
///       引擎是新增能力，不是新的故障点——一旦它能抛出，提交路径就多了一条只在设备上出现的
///       崩溃路径。
///
///       实现也**不必自己管超时**：调用方（提交路径与边打边算）会给每次调用设一个上限，实现即使
///       永远不回答，界面也不会卡住（那次调用按「没有可用结果」处理），而边打边算的在飞上限恒为
///       一发。
///
/// English: Something that can evaluate. It exists so a test double can stand in for the real
///          engine: the real one only exists on a device, while the submit path's fallback
///          behaviour has to be assertable under `flutter test`.
///
///          Implementations *must not throw*: an unavailable engine, an absent platform side and a
///          parse failure are all reported through [EngineReply]. The engine is a new capability,
///          not a new failure point — if it could throw, the submit path would gain a crash path
///          that only shows up on a device.
///
///          Implementations do *not* have to bound their own wait: the caller (the submit path and
///          as-you-type evaluation) puts a cap on every call, so an implementation that never answers
///          cannot freeze the interface (that call simply counts as "no usable result"), and
///          as-you-type keeps at most one call in flight.
abstract class MathEngine {
  /// 中文：求值一次。[angleMode] 是 `DEG` / `RAD`，必须传给引擎：同一个 `sin(30)` 在两种模式下
  ///       是两个不同的数，不传就会让提交路径与边打边算在 DEG 模式下互相矛盾。
  /// English: Evaluate once. [angleMode] is `DEG` / `RAD` and must reach the engine: `sin(30)` is a
  ///          different number in each mode, and dropping it would make the submit path contradict
  ///          the as-you-type path in DEG mode.
  Future<EngineReply> evaluate(String expression, {required String angleMode});
}
