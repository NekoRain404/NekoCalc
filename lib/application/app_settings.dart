class AppSettings {
  const AppSettings({
    required this.haptics,
    required this.restoreState,
    required this.autoSaveHistory,
    required this.angleMode,
    required this.precision,
    required this.themeModeLabel,
  });

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(
      haptics: map['haptics'] != 'false',
      restoreState: map['restore_state'] != 'false',
      autoSaveHistory: map['auto_save'] != 'false',
      angleMode: map['angle_mode'] == '角度' ? 'DEG' : 'RAD',
      precision: switch (map['digits']) {
        '4 位' => 4,
        '8 位' => 8,
        _ => 6,
      },
      themeModeLabel: map['theme_mode'] ?? '跟随系统',
    );
  }

  static const fallback = AppSettings(
    haptics: true,
    restoreState: true,
    autoSaveHistory: true,
    angleMode: 'RAD',
    precision: 6,
    themeModeLabel: '跟随系统',
  );

  final bool haptics;
  final bool restoreState;
  final bool autoSaveHistory;
  final String angleMode;
  final int precision;
  final String themeModeLabel;

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.haptics == haptics &&
        other.restoreState == restoreState &&
        other.autoSaveHistory == autoSaveHistory &&
        other.angleMode == angleMode &&
        other.precision == precision &&
        other.themeModeLabel == themeModeLabel;
  }

  @override
  int get hashCode => Object.hash(haptics, restoreState, autoSaveHistory, angleMode, precision, themeModeLabel);
}
