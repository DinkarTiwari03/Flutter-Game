enum MissionStatus { locked, active, completed }

/// A city's progress on one mission.
///
/// Mission definitions (title, goals, rewards) are static game content and
/// are not persisted; only this per-city progress is.
class MissionProgress {
  const MissionProgress({
    required this.cityId,
    required this.missionId,
    required this.updatedAt,
    this.status = MissionStatus.locked,
    this.progress = 0,
  });

  factory MissionProgress.fromJson(Map<String, Object?> json) {
    return MissionProgress(
      cityId: json['cityId'] as String,
      missionId: json['missionId'] as String,
      status: MissionStatus.values.byName(json['status'] as String),
      progress: (json['progress'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String cityId;
  final String missionId;
  final MissionStatus status;

  /// Completion from 0 to 1.
  final double progress;
  final DateTime updatedAt;

  MissionProgress copyWith({
    MissionStatus? status,
    double? progress,
    DateTime? updatedAt,
  }) {
    return MissionProgress(
      cityId: cityId,
      missionId: missionId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'cityId': cityId,
    'missionId': missionId,
    'status': status.name,
    'progress': progress,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
