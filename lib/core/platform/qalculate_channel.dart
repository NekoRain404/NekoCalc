import 'package:flutter/services.dart';

/// 中文：两侧共用的日志标签，方便 `adb logcat | grep` 一次抓全 Dart 与 Kotlin 的输出。
/// English: Shared log tag so a single `adb logcat | grep` catches both the Dart and the Kotlin
///          output.
const qalculateLogTag = 'NekoCalcQalculate';

/// 中文：libqalculate 原生引擎的平台通道。当前只有一个求值入口，由
///       `QalculateMathEngine` 包成可替换的 `MathEngine`；边打边算仍然走旧的 Dart 解析器。
/// English: Platform channel to the native libqalculate engine. There is one evaluation entry
///          point, wrapped as a replaceable `MathEngine` by `QalculateMathEngine`; as-you-type
///          evaluation still uses the legacy Dart parser.
class QalculateChannel {
  const QalculateChannel();

  static const _channel = MethodChannel('nekocalc/qalculate');

  /// 中文：让原生引擎求值一次。返回的字符串表至少含 `decimal` 与 `latex`；
  ///       引擎失败时含 `ok: 'false'` 与 `error`，而不是抛异常。
  ///
  ///       [angleMode] 是 `DEG` / `RAD`，**必填**：角度单位在原生侧落在 `ParseOptions` 上，
  ///       不跟着表达式一起过去的话，同一个 `sin(30)` 会被按引擎的默认角度单位解释，于是提交
  ///       路径与边打边算在 DEG 模式下给出互相矛盾的两个数——而且只在 DEG 模式下发生。
  ///       原生侧对缺失的 `angleMode` 直接拒绝，不猜默认值：猜错就是答案错。
  ///
  /// English: Evaluate once on the native engine. The returned map carries at least `decimal`
  ///          and `latex`; on engine failure it carries `ok: 'false'` and `error` instead of
  ///          throwing.
  ///
  ///          [angleMode] is `DEG` / `RAD` and is *required*: the angle unit lives on the native
  ///          side's `ParseOptions`, so an expression that travels without it is interpreted in the
  ///          engine's default angle unit — making the submit path and the as-you-type path
  ///          contradict each other in DEG mode only. The native side rejects a missing
  ///          `angleMode` rather than guessing a default, because guessing wrong means answering
  ///          the wrong question.
  Future<Map<String, String>> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    final result = await _channel.invokeMapMethod<String, String>('evaluate', {
      'expression': expression,
      'angleMode': angleMode,
    });
    return result ?? const <String, String>{};
  }
}
