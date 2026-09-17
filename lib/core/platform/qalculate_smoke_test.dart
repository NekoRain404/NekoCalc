import 'package:flutter/foundation.dart';

import 'qalculate_channel.dart';

/// 中文：启动诊断。调用一次原生 libqalculate 引擎，把答案写进日志，用来在真机上
///       证明引擎确实加载起来了、也确实在算——而不是一个空壳。
///
///       刻意吞掉所有异常：这一步存在的意义就是产出日志，所以任何失败都必须是日志里的
///       一行，而不是一次启动崩溃（例如 ABI 不匹配时 System.loadLibrary 抛的
///       UnsatisfiedLinkError）。引擎接进求值路径后整个文件删掉。
///
/// English: Startup diagnostic. It calls the native libqalculate engine once and writes the
///          answer to the log, proving on a real device that the engine loaded and actually
///          computes rather than being a stub.
///
///          Every failure is deliberately swallowed: this exists to produce a log line, so a
///          failure must be a log line rather than a startup crash (an UnsatisfiedLinkError from
///          System.loadLibrary on an ABI mismatch, for instance). The whole file goes away once
///          the engine is on the evaluation path.
Future<void> runQalculateSmokeTest({
  QalculateChannel channel = const QalculateChannel(),
  String expression = 'sqrt(32)',
  // 中文：角度模式跟着表达式一起过去，和提交路径的做法一致。启动诊断读不到用户设置，这里用
  //       RAD——它也是 `AppSettings.fallback` 的默认角度模式。
  // English: The angle mode travels with the expression, exactly as it does on the submit path.
  //          The startup diagnostic cannot read user settings, so this uses RAD — also
  //          `AppSettings.fallback`'s default angle mode.
  String angleMode = 'RAD',
}) async {
  try {
    final result = await channel.evaluate(expression, angleMode: angleMode);
    debugPrint(
      '$qalculateLogTag smoke "$expression" -> ok=${result['ok']} '
      'decimal=${result['decimal']} dual=${result['dual']} latex=${result['latex']} '
      'aborted=${result['aborted']} messages=${result['messages']} error=${result['error']}',
    );
  } catch (error) {
    debugPrint(
        '$qalculateLogTag smoke "$expression" -> channel failed: $error');
  }
}
