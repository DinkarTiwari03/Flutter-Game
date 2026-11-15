/// Events fired by the progression system for UI notifications.
sealed class ProgressionEvent {
  const ProgressionEvent();
}

class MissionCompletedEvent extends ProgressionEvent {
  const MissionCompletedEvent({required this.missionId, required this.title});
  final String missionId;
  final String title;
}

class AchievementUnlockedEvent extends ProgressionEvent {
  const AchievementUnlockedEvent({
    required this.achievementId,
    required this.title,
    required this.icon,
  });
  final String achievementId;
  final String title;
  final String icon;
}

class LevelUpEvent extends ProgressionEvent {
  const LevelUpEvent({required this.newLevel});
  final int newLevel;
}

class RewardClaimedEvent extends ProgressionEvent {
  const RewardClaimedEvent({
    required this.missionId,
    required this.coinsAwarded,
    required this.xpAwarded,
  });
  final String missionId;
  final int coinsAwarded;
  final int xpAwarded;
}

class BuildingUnlockedEvent extends ProgressionEvent {
  const BuildingUnlockedEvent({required this.buildingId});
  final String buildingId;
}
