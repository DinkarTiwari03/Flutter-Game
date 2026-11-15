/// Persisted user preferences.
///
/// Stored as a simple key-value JSON map; every field has a safe default so
/// missing keys on first load are handled gracefully.
class AppSettings {
  const AppSettings({
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.masterVolume = 1.0,
    this.simulationSpeed = 1,
    this.showGrid = true,
    this.tutorialCompleted = false,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      soundEnabled: (json['soundEnabled'] as bool?) ?? true,
      musicEnabled: (json['musicEnabled'] as bool?) ?? true,
      masterVolume: ((json['masterVolume'] as num?) ?? 1.0).toDouble(),
      simulationSpeed: ((json['simulationSpeed'] as num?) ?? 1).toInt(),
      showGrid: (json['showGrid'] as bool?) ?? true,
      tutorialCompleted: (json['tutorialCompleted'] as bool?) ?? false,
    );
  }

  final bool soundEnabled;
  final bool musicEnabled;

  /// Master volume multiplier (0.0–1.0).
  final double masterVolume;

  /// Preferred simulation speed (1 = normal, 2 = fast, 3 = ultra).
  final int simulationSpeed;

  /// Whether the grid overlay is shown.
  final bool showGrid;

  /// Whether the first-time tutorial has been completed.
  final bool tutorialCompleted;

  AppSettings copyWith({
    bool? soundEnabled,
    bool? musicEnabled,
    double? masterVolume,
    int? simulationSpeed,
    bool? showGrid,
    bool? tutorialCompleted,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      masterVolume: masterVolume ?? this.masterVolume,
      simulationSpeed: simulationSpeed ?? this.simulationSpeed,
      showGrid: showGrid ?? this.showGrid,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
    );
  }

  Map<String, Object?> toJson() => {
    'soundEnabled': soundEnabled,
    'musicEnabled': musicEnabled,
    'masterVolume': masterVolume,
    'simulationSpeed': simulationSpeed,
    'showGrid': showGrid,
    'tutorialCompleted': tutorialCompleted,
  };
}
