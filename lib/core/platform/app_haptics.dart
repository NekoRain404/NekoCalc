import 'package:flutter/services.dart';

class AppHaptics {
  const AppHaptics._();

  static const _channel = MethodChannel('nekocalc/haptics');
  static const _minimumTapGap = Duration(milliseconds: 28);

  static const light = '轻';
  static const medium = '标准';
  static const strong = '强';
  static DateTime? _lastTapAt;
  static bool _strongTapInFlight = false;

  static Future<void> tap({
    required bool enabled,
    required String strength,
  }) {
    if (!enabled) return Future.value();
    final now = DateTime.now();
    final lastTapAt = _lastTapAt;
    // 中文：快速连点时合并触感，防止系统震动队列堆积造成“迟钝”。
    // English: Coalesce rapid taps so the platform vibration queue does not feel delayed.
    if (lastTapAt != null && now.difference(lastTapAt) < _minimumTapGap) {
      return Future.value();
    }
    _lastTapAt = now;

    // 中文：轻/标准触感走 Flutter 快路径；强触感才走原生通道取得更明显反馈。
    // English: Use Flutter's fast path for light/medium haptics; native channel is reserved for stronger feedback.
    if (strength == light) return HapticFeedback.selectionClick();
    if (strength == medium) return HapticFeedback.lightImpact();
    if (_strongTapInFlight) return Future.value();
    _strongTapInFlight = true;
    return _channel
        .invokeMethod<void>('tap', {'strength': strength})
        .then(
          (_) {},
          onError: (_) => HapticFeedback.heavyImpact(),
        )
        .whenComplete(() => _strongTapInFlight = false);
  }
}
