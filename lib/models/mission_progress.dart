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
    this.rewardClaimed = false,
    this.completedAt,
  });

  factory MissionProgress.fromJson(Map<String, Object?> json) {
    return MissionProgress(
      cityId: json['cityId'] as String,
      missionId: json['missionId'] as String,
      status: MissionStatus.values.byName(json['status'] as String),
      progress: (json['progress'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      rewardClaimed: (json['rewardClaimed'] as bool?) ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  final String cityId;
  final String missionId;
  final MissionStatus status;

  /// Completion from 0 to 1.
  final double progress;
  final DateTime updatedAt;

  /// Whether the reward for this mission has been claimed.
  final bool rewardClaimed;

  /// When this mission was completed (null if not completed).
  final DateTime? completedAt;

  MissionProgress copyWith({
    MissionStatus? status,
    double? progress,
    DateTime? updatedAt,
    bool? rewardClaimed,
    DateTime? completedAt,
  }) {
    return MissionProgress(
      cityId: cityId,
      missionId: missionId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      updatedAt: updatedAt ?? this.updatedAt,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'cityId': cityId,
        'missionId': missionId,
        'status': status.name,
        'progress': progress,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'rewardClaimed': rewardClaimed,
        'completedAt': completedAt?.toUtc().toIso8601String(),
      };
}
