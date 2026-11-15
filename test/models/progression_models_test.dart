import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/missions/achievement_definition.dart';
import 'package:city_builder_2040/game/missions/mission_definition.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/models/progression_event.dart';

void main() {
  group('PlayerProgress', () {
    test('initial values and default level 1', () {
      final now = DateTime.now().toUtc();
      final player = PlayerProgress(
        playerId: 'local',
        updatedAt: now,
      );

      expect(player.playerId, 'local');
      expect(player.level, 1);
      expect(player.experience, 0);
      expect(player.unlockedIds, isEmpty);
      expect(player.claimedMissionIds, isEmpty);
      expect(player.completedAchievementIds, isEmpty);
      expect(player.isMaxLevel, isFalse);
      expect(player.xpForNextLevel, 100);
      expect(player.levelProgress, 0.0);
    });

    test('XP and level calculations', () {
      final now = DateTime.now().toUtc();
      final player = PlayerProgress(
        playerId: 'local',
        level: 2,
        experience: 175,
        updatedAt: now,
      );

      // Level 2 threshold is 100, Level 3 threshold is 250
      expect(player.xpForNextLevel, 250 - 175);
      expect(player.xpAtCurrentLevel, 100);
      expect(player.xpAtNextLevel, 250);
      // Progress: (175 - 100) / (250 - 100) = 75 / 150 = 0.5
      expect(player.levelProgress, closeTo(0.5, 0.001));
    });

    test('Max level behavior', () {
      final now = DateTime.now().toUtc();
      final player = PlayerProgress(
        playerId: 'local',
        level: 10,
        experience: 5000,
        updatedAt: now,
      );

      expect(player.isMaxLevel, isTrue);
      expect(player.xpForNextLevel, 0);
      expect(player.levelProgress, 1.0);
    });

    test('JSON serialization roundtrip', () {
      final now = DateTime.utc(2026, 11, 15, 12, 0, 0);
      final original = PlayerProgress(
        playerId: 'player_123',
        level: 3,
        experience: 350,
        unlockedIds: ['shopping_mall', 'solar_plant'],
        claimedMissionIds: ['first_home', 'first_shop'],
        completedAchievementIds: ['ach_first_build'],
        updatedAt: now,
      );

      final json = original.toJson();
      final restored = PlayerProgress.fromJson(json);

      expect(restored.playerId, original.playerId);
      expect(restored.level, original.level);
      expect(restored.experience, original.experience);
      expect(restored.unlockedIds, original.unlockedIds);
      expect(restored.claimedMissionIds, original.claimedMissionIds);
      expect(restored.completedAchievementIds, original.completedAchievementIds);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('copyWith works immutably', () {
      final original = PlayerProgress(
        playerId: 'local',
        updatedAt: DateTime.now().toUtc(),
      );

      final updated = original.copyWith(
        level: 2,
        experience: 120,
        unlockedIds: ['park'],
      );

      expect(original.level, 1);
      expect(original.experience, 0);
      expect(updated.level, 2);
      expect(updated.experience, 120);
      expect(updated.unlockedIds, ['park']);
    });
  });

  group('MissionProgress', () {
    test('initial values', () {
      final now = DateTime.now().toUtc();
      final progress = MissionProgress(
        cityId: 'city_1',
        missionId: 'first_home',
        updatedAt: now,
      );

      expect(progress.cityId, 'city_1');
      expect(progress.missionId, 'first_home');
      expect(progress.status, MissionStatus.locked);
      expect(progress.progress, 0.0);
      expect(progress.rewardClaimed, isFalse);
      expect(progress.completedAt, isNull);
    });

    test('JSON serialization roundtrip with completed fields', () {
      final now = DateTime.utc(2026, 11, 15, 14, 0, 0);
      final completedAt = DateTime.utc(2026, 11, 15, 14, 30, 0);
      final original = MissionProgress(
        cityId: 'city_1',
        missionId: 'housing_expansion',
        status: MissionStatus.completed,
        progress: 1.0,
        rewardClaimed: true,
        completedAt: completedAt,
        updatedAt: now,
      );

      final json = original.toJson();
      final restored = MissionProgress.fromJson(json);

      expect(restored.cityId, original.cityId);
      expect(restored.missionId, original.missionId);
      expect(restored.status, original.status);
      expect(restored.progress, original.progress);
      expect(restored.rewardClaimed, original.rewardClaimed);
      expect(restored.completedAt, original.completedAt);
      expect(restored.updatedAt, original.updatedAt);
    });
  });

  group('Registries', () {
    test('MissionRegistry has valid missions and challenges across categories', () {
      expect(MissionRegistry.all.isNotEmpty, isTrue);
      expect(MissionRegistry.missions.isNotEmpty, isTrue);
      expect(MissionRegistry.challenges.isNotEmpty, isTrue);

      final categories = MissionRegistry.all.map((m) => m.category).toSet();
      expect(categories.contains(MissionCategory.construction), isTrue);
      expect(categories.contains(MissionCategory.population), isTrue);
      expect(categories.contains(MissionCategory.economy), isTrue);
      expect(categories.contains(MissionCategory.sustainability), isTrue);

      for (final m in MissionRegistry.all) {
        expect(m.id.isNotEmpty, isTrue);
        expect(m.title.isNotEmpty, isTrue);
        expect(m.objectives.isNotEmpty, isTrue);
      }
    });

    test('AchievementRegistry has valid achievements', () {
      expect(AchievementRegistry.all.length, greaterThanOrEqualTo(10));
      for (final a in AchievementRegistry.all) {
        expect(a.id.isNotEmpty, isTrue);
        expect(a.title.isNotEmpty, isTrue);
        expect(a.icon.isNotEmpty, isTrue);
        expect(a.reward.xp, greaterThan(0));
      }
    });
  });

  group('ProgressionEvents', () {
    test('all event subclasses instantiate correctly', () {
      const e1 = MissionCompletedEvent(missionId: 'm1', title: 'First Home');
      const e2 = AchievementUnlockedEvent(
        achievementId: 'a1',
        title: 'Master',
        icon: '🏆',
      );
      const e3 = LevelUpEvent(newLevel: 2);
      const e4 = RewardClaimedEvent(
        missionId: 'm1',
        coinsAwarded: 100,
        xpAwarded: 50,
      );
      const e5 = BuildingUnlockedEvent(buildingId: 'hospital');

      expect(e1, isA<ProgressionEvent>());
      expect(e2, isA<ProgressionEvent>());
      expect(e3, isA<ProgressionEvent>());
      expect(e4, isA<ProgressionEvent>());
      expect(e5, isA<ProgressionEvent>());
    });
  });
}
