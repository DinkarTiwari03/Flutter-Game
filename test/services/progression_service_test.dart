import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/missions/achievement_definition.dart';
import 'package:city_builder_2040/game/missions/mission_definition.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city_demographics.dart';
import 'package:city_builder_2040/models/city_stats.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/models/progression_event.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/services/progression_service.dart';

void main() {
  const service = ProgressionService();

  group('ProgressionService - calculateLevel', () {
    test('XP to level mapping matches thresholds', () {
      expect(service.calculateLevel(0), 1);
      expect(service.calculateLevel(50), 1);
      expect(service.calculateLevel(99), 1);
      expect(service.calculateLevel(100), 2);
      expect(service.calculateLevel(249), 2);
      expect(service.calculateLevel(250), 3);
      expect(service.calculateLevel(500), 4);
      expect(service.calculateLevel(850), 5);
      expect(service.calculateLevel(1300), 6);
      expect(service.calculateLevel(1900), 7);
      expect(service.calculateLevel(2600), 8);
      expect(service.calculateLevel(3500), 9);
      expect(service.calculateLevel(4600), 10);
      expect(service.calculateLevel(10000), 10); // capped at max
    });
  });

  group('ProgressionService - Objective Evaluation', () {
    final now = DateTime.utc(2026, 11, 15);
    final dummyBuildings = [
      Building(
        id: 'b1',
        cityId: 'c1',
        typeId: 'small_house',
        x: 0,
        y: 0,
        level: 1,
        createdAt: now,
        updatedAt: now,
      ),
      Building(
        id: 'b2',
        cityId: 'c1',
        typeId: 'small_house',
        x: 1,
        y: 0,
        level: 1,
        createdAt: now,
        updatedAt: now,
      ),
      Building(
        id: 'b3',
        cityId: 'c1',
        typeId: 'shop',
        x: 2,
        y: 0,
        level: 1,
        createdAt: now,
        updatedAt: now,
      ),
      Building(
        id: 'b4',
        cityId: 'c1',
        typeId: 'park',
        x: 3,
        y: 0,
        level: 1,
        createdAt: now,
        updatedAt: now,
      ),
      Building(
        id: 'b5',
        cityId: 'c1',
        typeId: 'solar_plant',
        x: 4,
        y: 0,
        level: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    const demographics = CityDemographics(
      totalPopulation: 80,
      housingCapacity: 120,
      totalJobs: 50,
      employedCount: 40,
    );

    const stats = CityStats(
      coins: 1500,
      population: 80,
      happiness: 75,
      pollution: 25,
      electricityProduced: 200,
      electricityConsumed: 100,
      waterProduced: 100,
      waterConsumed: 50,
    );

    final ledger = ResourceLedger.initial('c1', startingCoins: 1500);

    test('buildCount objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.buildCount,
        targetValue: 10,
        description: 'Build 10 buildings',
      );
      // 5 buildings placed / 10 target = 0.5
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, closeTo(0.5, 0.001));
    });

    test('buildingTypeCount objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.buildingTypeCount,
        targetValue: 2,
        description: 'Build 2 small houses',
        buildingTypeId: 'small_house',
      );
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, 1.0);
    });

    test('buildingCategoryCount objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.buildingCategoryCount,
        targetValue: 4,
        description: 'Build 4 residential buildings',
        buildingCategoryId: 'residential',
      );
      // dummyBuildings has 2 small houses (residential)
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, closeTo(0.5, 0.001));
    });

    test('reachPopulation objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.reachPopulation,
        targetValue: 100,
        description: 'Reach 100 population',
      );
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, closeTo(0.8, 0.001));
    });

    test('reachHousingCapacity objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.reachHousingCapacity,
        targetValue: 200,
        description: 'Reach 200 housing capacity',
      );
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, closeTo(0.6, 0.001));
    });

    test('reachCoins objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.reachCoins,
        targetValue: 3000,
        description: 'Have 3,000 coins',
      );
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, closeTo(0.5, 0.001));
    });

    test('reducePollution objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.reducePollution,
        targetValue: 30,
        description: 'Reduce pollution to 30 or less',
      );
      // current pollution is 25 <= 30 => satisfied (1.0)
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, 1.0);
    });

    test('buildParkCount objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.buildParkCount,
        targetValue: 2,
        description: 'Build 2 parks',
      );
      // 1 park in dummyBuildings / 2 target = 0.5
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, closeTo(0.5, 0.001));
    });

    test('reachHappiness objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.reachHappiness,
        targetValue: 75,
        description: 'Reach 75% happiness',
      );
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, 1.0);
    });

    test('generateRenewableEnergy objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.generateRenewableEnergy,
        targetValue: 200,
        description: 'Generate 200kW solar',
      );
      // solar_plant level 1 produces 160 kW -> 160 / 200 = 0.8
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, closeTo(0.8, 0.001));
    });

    test('improveEmployment objective', () {
      const obj = MissionObjective(
        type: ObjectiveType.improveEmployment,
        targetValue: 80,
        description: 'Reach 80% employment',
      );
      // demographics: workingAge ~52 (65% of 80), employed 40 -> 40/52 ~ 77%
      final p = service.evaluateObjective(
        obj,
        dummyBuildings,
        stats,
        demographics,
        ledger,
      );
      expect(p, greaterThan(0.5));
    });
  });

  group('ProgressionService - Mission Evaluation & Prerequisites', () {
    test('available missions filters by completed prerequisites', () {
      // With no completed missions, only root missions available
      final initialAvailable = service.getAvailableMissions([]);
      expect(initialAvailable.any((m) => m.id == 'first_home'), isTrue);
      expect(initialAvailable.any((m) => m.id == 'housing_expansion'), isFalse);

      // Complete first_home
      final progressWithFirstHome = [
        MissionProgress(
          cityId: 'c1',
          missionId: 'first_home',
          status: MissionStatus.completed,
          progress: 1.0,
          updatedAt: DateTime.now().toUtc(),
        ),
      ];

      final afterFirstHome =
          service.getAvailableMissions(progressWithFirstHome);
      expect(afterFirstHome.any((m) => m.id == 'housing_expansion'), isTrue);
    });
  });

  group('ProgressionService - Reward Claiming & Duplicate Prevention', () {
    test('awardMissionReward awards XP, coins, and updates level', () {
      final player = PlayerProgress(
        playerId: 'local',
        level: 1,
        experience: 80,
        updatedAt: DateTime.now().toUtc(),
      );

      const mission = MissionDefinition(
        id: 'test_mission',
        title: 'Test',
        description: 'Test',
        category: MissionCategory.construction,
        difficulty: MissionDifficulty.beginner,
        objectives: [],
        reward: MissionReward(coins: 500, xp: 50, unlockedBuildingIds: ['hospital']),
      );

      final result = service.awardMissionReward(player, mission);
      expect(result, isNotNull);

      final updated = result!.player;
      expect(updated.experience, 130);
      expect(updated.level, 2); // 130 >= 100 threshold -> level 2!
      expect(updated.claimedMissionIds, contains('test_mission'));
      expect(updated.unlockedIds, contains('hospital'));

      // Check events
      expect(result.events.any((e) => e is LevelUpEvent), isTrue);
      expect(result.events.any((e) => e is RewardClaimedEvent), isTrue);
      expect(result.events.any((e) => e is BuildingUnlockedEvent), isTrue);
    });

    test('awardMissionReward prevents duplicate claims', () {
      final player = PlayerProgress(
        playerId: 'local',
        claimedMissionIds: ['claimed_already'],
        updatedAt: DateTime.now().toUtc(),
      );

      const mission = MissionDefinition(
        id: 'claimed_already',
        title: 'Already Claimed',
        description: 'Test',
        category: MissionCategory.construction,
        difficulty: MissionDifficulty.beginner,
        objectives: [],
        reward: MissionReward(coins: 100, xp: 50),
      );

      final result = service.awardMissionReward(player, mission);
      expect(result, isNull); // Duplicate claim blocked
    });
  });

  group('ProgressionService - Achievement Evaluation', () {
    test('detects newly earned achievements', () {
      final player = PlayerProgress(
        playerId: 'local',
        completedAchievementIds: [],
        updatedAt: DateTime.now().toUtc(),
      );

      final now = DateTime.utc(2026, 11, 15);
      final buildings = [
        Building(
          id: 'b1',
          cityId: 'c1',
          typeId: 'small_house',
          x: 0,
          y: 0,
          level: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final newAchs = service.evaluateNewAchievements(
        buildings,
        null,
        const CityDemographics(),
        null,
        player,
      );

      // ach_first_build requires buildCount 1 -> should be unlocked!
      expect(newAchs.any((a) => a.id == 'ach_first_build'), isTrue);
    });

    test('awardAchievements updates XP, level, and completed list', () {
      final player = PlayerProgress(
        playerId: 'local',
        level: 1,
        experience: 90,
        completedAchievementIds: [],
        updatedAt: DateTime.now().toUtc(),
      );

      final ach = AchievementRegistry.findById('ach_first_build')!;
      final result = service.awardAchievements(player, [ach]);

      expect(result.player.completedAchievementIds, contains('ach_first_build'));
      expect(result.player.experience, 90 + ach.reward.xp);
      // 90 + 25 = 115 >= 100 -> leveled up to 2
      expect(result.player.level, 2);
      expect(result.events.any((e) => e is AchievementUnlockedEvent), isTrue);
      expect(result.events.any((e) => e is LevelUpEvent), isTrue);
    });
  });
}
