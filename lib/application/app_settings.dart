class AppSettings {
  const AppSettings({
    required this.haptics,
    required this.hapticStrength,
    required this.restoreState,
    required this.autoSaveHistory,
    required this.angleMode,
    required this.precision,
    required this.themeModeLabel,
    required this.expressionDisplayMode,
  });

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(
      haptics: map['haptics'] != 'false',
      hapticStrength: map['haptic_strength'] ?? '标准',
      restoreState: map['restore_state'] != 'false',
      autoSaveHistory: map['auto_save'] != 'false',
      angleMode: map['angle_mode'] == '角度' ? 'DEG' : 'RAD',
      precision: switch (map['digits']) {
        '4 位' => 4,
        '8 位' => 8,
        _ => 6,
      },
      themeModeLabel: map['theme_mode'] ?? '跟随系统',
      expressionDisplayMode: map['expression_display'] == '函数表达式'
          ? '数学表达式'
          : map['expression_display'] ?? '数学符号',
    );
  }

  static const fallback = AppSettings(
    haptics: true,
    hapticStrength: '标准',
    restoreState: true,
    autoSaveHistory: true,
    angleMode: 'RAD',
    precision: 6,
    themeModeLabel: '跟随系统',
    expressionDisplayMode: '数学符号',
  );

  final bool haptics;
  final String hapticStrength;
  final bool restoreState;
  final bool autoSaveHistory;
  final String angleMode;
  final int precision;
  final String themeModeLabel;
  final String expressionDisplayMode;

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.haptics == haptics &&
        other.hapticStrength == hapticStrength &&
        other.restoreState == restoreState &&
        other.autoSaveHistory == autoSaveHistory &&
        other.angleMode == angleMode &&
        other.precision == precision &&
        other.themeModeLabel == themeModeLabel &&
        other.expressionDisplayMode == expressionDisplayMode;
  }

  @override
  int get hashCode => Object.hash(
      haptics,
      hapticStrength,
      restoreState,
      autoSaveHistory,
      angleMode,
      precision,
      themeModeLabel,
      expressionDisplayMode);
}
