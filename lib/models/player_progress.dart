/// Account-wide progression, shared by all of a player's cities.
class PlayerProgress {
  PlayerProgress({
    required this.playerId,
    required this.updatedAt,
    this.level = 1,
    this.experience = 0,
    List<String> unlockedIds = const [],
  }) : unlockedIds = List.unmodifiable(unlockedIds);

  /// V1 is single-player and offline, so there is one fixed local player.
  /// A cloud account id replaces this in V3 without changing callers.
  static const localPlayerId = 'local';

  factory PlayerProgress.fromJson(Map<String, Object?> json) {
    return PlayerProgress(
      playerId: json['playerId'] as String,
      level: (json['level'] as num).toInt(),
      experience: (json['experience'] as num).toInt(),
      unlockedIds: (json['unlockedIds'] as List).cast<String>(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String playerId;
  final int level;
  final int experience;

  /// Stable ids of unlocked content (buildings, missions, ...).
  final List<String> unlockedIds;
  final DateTime updatedAt;

  PlayerProgress copyWith({
    int? level,
    int? experience,
    List<String>? unlockedIds,
    DateTime? updatedAt,
  }) {
    return PlayerProgress(
      playerId: playerId,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      unlockedIds: unlockedIds ?? this.unlockedIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'level': level,
    'experience': experience,
    'unlockedIds': unlockedIds,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
