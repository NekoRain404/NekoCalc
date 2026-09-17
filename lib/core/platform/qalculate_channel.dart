import 'package:flutter/services.dart';

/// 中文：两侧共用的日志标签，方便 `adb logcat | grep` 一次抓全 Dart 与 Kotlin 的输出。
/// English: Shared log tag so a single `adb logcat | grep` catches both the Dart and the Kotlin
///          output.
const qalculateLogTag = 'NekoCalcQalculate';

/// 中文：libqalculate 原生引擎的平台通道。当前只开一个诊断用的求值入口，
///       还没有接进计算器的求值路径。
/// English: Platform channel to the native libqalculate engine. Only a diagnostic evaluation
///          entry point exists for now; it is not on the calculator's evaluation path.
class QalculateChannel {
  const QalculateChannel();

  static const _channel = MethodChannel('nekocalc/qalculate');

  /// 中文：让原生引擎求值一次。返回的字符串表至少含 `decimal` 与 `latex`；
  ///       引擎失败时含 `ok: 'false'` 与 `error`，而不是抛异常。
  /// English: Evaluate once on the native engine. The returned map carries at least `decimal`
  ///          and `latex`; on engine failure it carries `ok: 'false'` and `error` instead of
  ///          throwing.
  Future<Map<String, String>> evaluate(String expression) async {
    final result = await _channel.invokeMapMethod<String, String>('evaluate', {
      'expression': expression,
    });
    return result ?? const <String, String>{};
  }
}
