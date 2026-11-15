/// Account-wide progression, shared by all of a player's cities.
class PlayerProgress {
  PlayerProgress({
    required this.playerId,
    required this.updatedAt,
    this.level = 1,
    this.experience = 0,
    List<String> unlockedIds = const [],
    List<String> claimedMissionIds = const [],
    List<String> completedAchievementIds = const [],
  })  : unlockedIds = List.unmodifiable(unlockedIds),
        claimedMissionIds = List.unmodifiable(claimedMissionIds),
        completedAchievementIds = List.unmodifiable(completedAchievementIds);

  /// V1 is single-player and offline, so there is one fixed local player.
  /// A cloud account id replaces this in V3 without changing callers.
  static const localPlayerId = 'local';

  /// XP required to reach each level (index = level - 1).
  /// Level 1 starts at 0 XP. Level 10 is max.
  static const List<int> xpThresholds = [
    0,
    100,
    250,
    500,
    850,
    1300,
    1900,
    2600,
    3500,
    4600,
  ];

  static const int maxLevel = 10;

  factory PlayerProgress.fromJson(Map<String, Object?> json) {
    return PlayerProgress(
      playerId: json['playerId'] as String,
      level: (json['level'] as num).toInt(),
      experience: (json['experience'] as num).toInt(),
      unlockedIds: (json['unlockedIds'] as List).cast<String>(),
      claimedMissionIds:
          ((json['claimedMissionIds'] as List?) ?? []).cast<String>(),
      completedAchievementIds:
          ((json['completedAchievementIds'] as List?) ?? []).cast<String>(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String playerId;
  final int level;
  final int experience;

  /// Stable ids of unlocked content (buildings, achievements, decorations, etc.).
  final List<String> unlockedIds;

  /// Mission ids whose rewards have been claimed (prevents duplicate claims).
  final List<String> claimedMissionIds;

  /// Achievement ids that have been completed and their rewards claimed.
  final List<String> completedAchievementIds;

  final DateTime updatedAt;

  /// XP needed to reach the next level (0 if at max level).
  int get xpForNextLevel {
    if (level >= maxLevel) return 0;
    return xpThresholds[level] - experience;
  }

  /// Total XP needed for the current level (starting XP of this level).
  int get xpAtCurrentLevel => xpThresholds[level - 1];

  /// Total XP needed for the next level (or current xp if at max).
  int get xpAtNextLevel => level >= maxLevel ? experience : xpThresholds[level];

  bool get isMaxLevel => level >= maxLevel;

  /// Progress within the current level (0.0–1.0).
  double get levelProgress {
    if (isMaxLevel) return 1.0;
    final levelStart = xpThresholds[level - 1];
    final levelEnd = xpThresholds[level];
    final range = levelEnd - levelStart;
    if (range <= 0) return 1.0;
    return ((experience - levelStart) / range).clamp(0.0, 1.0);
  }

  PlayerProgress copyWith({
    int? level,
    int? experience,
    List<String>? unlockedIds,
    List<String>? claimedMissionIds,
    List<String>? completedAchievementIds,
    DateTime? updatedAt,
  }) {
    return PlayerProgress(
      playerId: playerId,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      unlockedIds: unlockedIds ?? this.unlockedIds,
      claimedMissionIds: claimedMissionIds ?? this.claimedMissionIds,
      completedAchievementIds:
          completedAchievementIds ?? this.completedAchievementIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'playerId': playerId,
        'level': level,
        'experience': experience,
        'unlockedIds': unlockedIds,
        'claimedMissionIds': claimedMissionIds,
        'completedAchievementIds': completedAchievementIds,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}
