import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/missions/achievement_definition.dart';
import 'package:city_builder_2040/game/missions/mission_definition.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city_demographics.dart';
import 'package:city_builder_2040/models/city_stats.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/models/progression_event.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';

/// Pure business logic for the progression system.
/// No UI dependencies. All inputs are plain data.
class ProgressionService {
  const ProgressionService();

  // ─── Level Calculation ───────────────────────────────────────────────────

  /// Returns the level a player should be at given their [experience].
  int calculateLevel(int experience) {
    final thresholds = PlayerProgress.xpThresholds;
    var level = 1;
    for (var i = 1; i < thresholds.length; i++) {
      if (experience >= thresholds[i]) {
        level = i + 1;
      } else {
        break;
      }
    }
    return level.clamp(1, PlayerProgress.maxLevel);
  }

  // ─── Objective Evaluation ────────────────────────────────────────────────

  /// Computes 0.0–1.0 progress for a single [objective].
  double evaluateObjective(
    MissionObjective objective,
    List<Building> buildings,
    CityStats? cityStats,
    CityDemographics demographics,
    ResourceLedger? ledger,
  ) {
    final target = objective.targetValue;
    if (target <= 0) return 1.0;

    switch (objective.type) {
      case ObjectiveType.buildCount:
        return (buildings.length / target).clamp(0.0, 1.0);

      case ObjectiveType.buildingTypeCount:
        final typeId = objective.buildingTypeId;
        if (typeId == null) return 0.0;
        final count = buildings.where((b) => b.typeId == typeId).length;
        return (count / target).clamp(0.0, 1.0);

      case ObjectiveType.buildingCategoryCount:
        final catId = objective.buildingCategoryId;
        if (catId == null) return 0.0;
        final count = buildings.where((b) {
          final def = BuildingRegistry.findById(b.typeId);
          return def?.category.name == catId;
        }).length;
        return (count / target).clamp(0.0, 1.0);

      case ObjectiveType.reachPopulation:
        final pop = cityStats?.population ?? demographics.totalPopulation;
        return (pop / target).clamp(0.0, 1.0);

      case ObjectiveType.reachHousingCapacity:
        return (demographics.housingCapacity / target).clamp(0.0, 1.0);

      case ObjectiveType.reachCoins:
        final coins = ledger?.coins ?? cityStats?.coins ?? 0;
        return (coins / target).clamp(0.0, 1.0);

      case ObjectiveType.maintainPositiveIncome:
        // Achieved if net income > 0
        final income = _computeNetIncome(buildings);
        return income > 0 ? 1.0 : 0.0;

      case ObjectiveType.reducePollution:
        // Target is max allowed pollution; achieved when current <= target
        final pollution = cityStats?.pollution ?? 0;
        if (pollution <= target) return 1.0;
        return 0.0;

      case ObjectiveType.buildParkCount:
        final count = buildings.where((b) {
          final def = BuildingRegistry.findById(b.typeId);
          return def != null && (def.id == 'park' || def.id == 'garden');
        }).length;
        return (count / target).clamp(0.0, 1.0);

      case ObjectiveType.reachHappiness:
        final happiness = cityStats?.happiness ?? 0;
        return (happiness / target).clamp(0.0, 1.0);

      case ObjectiveType.generateRenewableEnergy:
        final solarKw = buildings.fold<double>(0, (sum, b) {
          if (b.typeId != 'solar_plant') return sum;
          final def = BuildingRegistry.findById(b.typeId);
          if (def == null) return sum;
          return sum + def.effectiveElectricityProduction(b.level);
        });
        return (solarKw / target).clamp(0.0, 1.0);

      case ObjectiveType.improveEmployment:
        final rate = demographics.employmentRate.toDouble();
        return (rate / target).clamp(0.0, 1.0);
    }
  }

  int _computeNetIncome(List<Building> buildings) {
    var income = 0;
    var expenses = 0;
    for (final b in buildings) {
      final def = BuildingRegistry.findById(b.typeId);
      if (def == null) continue;
      income += def.effectiveCommercialIncome(b.level);
      income += def.effectiveIndustrialIncome(b.level);
      expenses += def.effectiveMaintenance(b.level);
    }
    return income - expenses;
  }

  /// Computes 0.0–1.0 progress for an entire [mission] (minimum progress across objectives).
  double evaluateMissionProgress(
    MissionDefinition mission,
    List<Building> buildings,
    CityStats? cityStats,
    CityDemographics demographics,
    ResourceLedger? ledger,
  ) {
    if (mission.objectives.isEmpty) return 1.0;
    var minProgress = 1.0;
    for (final obj in mission.objectives) {
      final p = evaluateObjective(obj, buildings, cityStats, demographics, ledger);
      if (p < minProgress) minProgress = p;
    }
    return minProgress;
  }

  // ─── Mission Completion ──────────────────────────────────────────────────

  bool isMissionComplete(
    MissionDefinition mission,
    List<Building> buildings,
    CityStats? cityStats,
    CityDemographics demographics,
    ResourceLedger? ledger,
  ) {
    return evaluateMissionProgress(mission, buildings, cityStats, demographics, ledger) >= 1.0;
  }

  // ─── Available Missions ──────────────────────────────────────────────────

  /// Returns missions the player can currently work on (prerequisites met).
  List<MissionDefinition> getAvailableMissions(
    List<MissionProgress> allProgress,
  ) {
    final completedIds = allProgress
        .where((p) => p.status == MissionStatus.completed)
        .map((p) => p.missionId)
        .toSet();

    return MissionRegistry.missions.where((m) {
      return m.prerequisiteMissionIds.every((id) => completedIds.contains(id));
    }).toList();
  }

  List<MissionDefinition> getAvailableChallenges(
    List<MissionProgress> allProgress,
  ) {
    final completedIds = allProgress
        .where((p) => p.status == MissionStatus.completed)
        .map((p) => p.missionId)
        .toSet();

    return MissionRegistry.challenges.where((m) {
      return m.prerequisiteMissionIds.every((id) => completedIds.contains(id));
    }).toList();
  }

  // ─── Reward Claiming ─────────────────────────────────────────────────────

  /// Awards a mission's reward to [player], returning updated progress and fired events.
  /// Returns null if the reward was already claimed (duplicate prevention).
  ({PlayerProgress player, List<ProgressionEvent> events})? awardMissionReward(
    PlayerProgress player,
    MissionDefinition mission,
  ) {
    // Duplicate claim prevention
    if (player.claimedMissionIds.contains(mission.id)) return null;

    final reward = mission.reward;
    final newXp = player.experience + reward.xp;
    final newLevel = calculateLevel(newXp);
    final events = <ProgressionEvent>[];

    // Level-up event
    if (newLevel > player.level) {
      events.add(LevelUpEvent(newLevel: newLevel));
    }

    // Reward event
    events.add(
      RewardClaimedEvent(
        missionId: mission.id,
        coinsAwarded: reward.coins,
        xpAwarded: reward.xp,
      ),
    );

    // Building unlock events
    final newUnlocks = [
      ...player.unlockedIds,
      ...reward.unlockedBuildingIds.where((id) => !player.unlockedIds.contains(id)),
      ...reward.unlockedDecorationIds.where((id) => !player.unlockedIds.contains(id)),
    ];
    for (final buildingId in reward.unlockedBuildingIds) {
      if (!player.unlockedIds.contains(buildingId)) {
        events.add(BuildingUnlockedEvent(buildingId: buildingId));
      }
    }

    final updatedPlayer = player.copyWith(
      experience: newXp,
      level: newLevel,
      unlockedIds: newUnlocks,
      claimedMissionIds: [...player.claimedMissionIds, mission.id],
      updatedAt: DateTime.now().toUtc(),
    );

    return (player: updatedPlayer, events: events);
  }

  // ─── Achievement Evaluation ──────────────────────────────────────────────

  /// Returns achievements that are newly unlocked (not yet in [player.completedAchievementIds]).
  List<AchievementDefinition> evaluateNewAchievements(
    List<Building> buildings,
    CityStats? cityStats,
    CityDemographics demographics,
    ResourceLedger? ledger,
    PlayerProgress player,
  ) {
    final newlyUnlocked = <AchievementDefinition>[];
    for (final ach in AchievementRegistry.all) {
      if (player.completedAchievementIds.contains(ach.id)) continue;
      final progress = evaluateObjective(
        ach.objective,
        buildings,
        cityStats,
        demographics,
        ledger,
      );
      if (progress >= 1.0) {
        newlyUnlocked.add(ach);
      }
    }
    return newlyUnlocked;
  }

  /// Awards achievement rewards to [player], returning updated player and events.
  ({PlayerProgress player, List<ProgressionEvent> events}) awardAchievements(
    PlayerProgress player,
    List<AchievementDefinition> achievements,
  ) {
    var current = player;
    final events = <ProgressionEvent>[];

    for (final ach in achievements) {
      if (current.completedAchievementIds.contains(ach.id)) continue;

      final newXp = current.experience + ach.reward.xp;
      final newLevel = calculateLevel(newXp);

      if (newLevel > current.level) {
        events.add(LevelUpEvent(newLevel: newLevel));
      }

      events.add(AchievementUnlockedEvent(
        achievementId: ach.id,
        title: ach.title,
        icon: ach.icon,
      ));

      current = current.copyWith(
        experience: newXp,
        level: newLevel,
        completedAchievementIds: [...current.completedAchievementIds, ach.id],
        updatedAt: DateTime.now().toUtc(),
      );
    }

    return (player: current, events: events);
  }
}
