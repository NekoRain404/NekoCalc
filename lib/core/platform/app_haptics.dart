import 'package:flutter/services.dart';

class AppHaptics {
  const AppHaptics._();

  static const _channel = MethodChannel('nekocalc/haptics');

  static const light = '轻';
  static const medium = '标准';
  static const strong = '强';

  static Future<void> tap({
    required bool enabled,
    required String strength,
  }) {
    if (!enabled) return Future.value();
    return _channel
        .invokeMethod<void>('tap', {'strength': strength}).catchError(
      (_) {
        return switch (strength) {
          light => HapticFeedback.lightImpact(),
          strong => HapticFeedback.heavyImpact(),
          _ => HapticFeedback.selectionClick(),
        };
      },
    );
  }
}
