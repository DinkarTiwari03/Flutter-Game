import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/backends.dart';
import 'package:drift/drift.dart' show OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:drift/native.dart';
import 'package:city_builder_2040/models/app_settings.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/repositories/local/app_database.dart';
import 'package:city_builder_2040/repositories/local/local_building_repository.dart';
import 'package:city_builder_2040/repositories/local/local_city_repository.dart';
import 'package:city_builder_2040/repositories/local/local_mission_repository.dart';
import 'package:city_builder_2040/repositories/local/local_player_progress_repository.dart';
import 'package:city_builder_2040/repositories/local/local_resource_repository.dart';
import 'package:city_builder_2040/repositories/local/local_settings_repository.dart';

void main() {
  group('Local Repositories (Drift / SQLite)', () {
    late AppDatabase db;
    late LocalCityRepository cityRepo;
    late LocalBuildingRepository buildingRepo;
    late LocalResourceRepository resourceRepo;
    late LocalMissionRepository missionRepo;
    late LocalPlayerProgressRepository progressRepo;
    late LocalSettingsRepository settingsRepo;

    setUp(() async {
      db = await AppDatabase.openInMemory(NativeDatabase.memory());
      cityRepo = LocalCityRepository(db);
      buildingRepo = LocalBuildingRepository(db);
      resourceRepo = LocalResourceRepository(db);
      missionRepo = LocalMissionRepository(db);
      progressRepo = LocalPlayerProgressRepository(db);
      settingsRepo = LocalSettingsRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('City CRUD persists correctly', () async {
      final city = City(
        id: 'c1',
        name: 'Neo Tokyo',
        mapWidth: 32,
        mapHeight: 32,
        seed: 42,
        day: 5,
        population: 150,
        createdAt: DateTime.utc(2040, 1, 1),
        updatedAt: DateTime.utc(2040, 1, 1, 12, 0),
      );

      await cityRepo.saveCity(city);

      final fetched = await cityRepo.getCity('c1');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Neo Tokyo');
      expect(fetched.seed, 42);
      expect(fetched.day, 5);
      expect(fetched.population, 150);

      final list = await cityRepo.listCities();
      expect(list.length, 1);
      expect(list.first.id, 'c1');

      // Update
      final updated = city.copyWith(name: 'Neo Tokyo Prime', population: 200);
      await cityRepo.saveCity(updated);
      final refetched = await cityRepo.getCity('c1');
      expect(refetched!.name, 'Neo Tokyo Prime');
      expect(refetched.population, 200);

      // Delete
      await cityRepo.deleteCity('c1');
      expect(await cityRepo.getCity('c1'), isNull);
      expect(await cityRepo.listCities(), isEmpty);
    });

    test('Building CRUD and batch upsert persist correctly', () async {
      final b1 = Building(
        id: 'b1',
        cityId: 'c1',
        typeId: 'residential_small',
        x: 5,
        y: 10,
        level: 1,
        rotation: 90,
        createdAt: DateTime.utc(2040, 1, 1),
        updatedAt: DateTime.utc(2040, 1, 1),
      );
      final b2 = Building(
        id: 'b2',
        cityId: 'c1',
        typeId: 'solar_plant',
        x: 8,
        y: 12,
        level: 2,
        rotation: 270,
        createdAt: DateTime.utc(2040, 1, 1),
        updatedAt: DateTime.utc(2040, 1, 1),
      );

      // Save single
      await buildingRepo.saveBuilding(b1);
      var list = await buildingRepo.getBuildings('c1');
      expect(list.length, 1);
      expect(list.first.typeId, 'residential_small');
      expect(list.first.rotation, 90);

      // Batch save
      await buildingRepo.saveBuildings([b1, b2]);
      list = await buildingRepo.getBuildings('c1');
      expect(list.length, 2);
      expect(list.firstWhere((b) => b.id == 'b2').rotation, 270);
      list = await buildingRepo.getBuildings('c1');
      expect(list.length, 2);

      // Remove single
      await buildingRepo.removeBuilding('c1', 'b1');
      list = await buildingRepo.getBuildings('c1');
      expect(list.length, 1);
      expect(list.first.id, 'b2');

      // Delete all by city
      await buildingRepo.deleteByCity('c1');
      expect(await buildingRepo.getBuildings('c1'), isEmpty);
    });

    test('Migration from schema version 1 adds rotation column without data loss', () async {
      final legacyExecutor = NativeDatabase.memory();
      // Simulate existing version 1 database without rotation column
      await legacyExecutor.ensureOpen(_TestDelegate());
      await legacyExecutor.runCustom(
        'CREATE TABLE schema_version (version INTEGER NOT NULL)',
        [],
      );
      await legacyExecutor.runCustom(
        'INSERT INTO schema_version (version) VALUES (1)',
        [],
      );
      await legacyExecutor.runCustom('''
CREATE TABLE buildings (
  id TEXT PRIMARY KEY NOT NULL,
  city_id TEXT NOT NULL,
  type_id TEXT NOT NULL,
  x INTEGER NOT NULL,
  y INTEGER NOT NULL,
  level INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''', []);
      // Insert legacy building without rotation
      await legacyExecutor.runCustom('''
INSERT INTO buildings (id, city_id, type_id, x, y, level, created_at, updated_at)
VALUES ('legacy1', 'cityA', 'small_house', 3, 4, 1, '2040-01-01T00:00:00.000Z', '2040-01-01T00:00:00.000Z')
''', []);

      // Now open AppDatabase on this legacy database
      final migratedDb = await AppDatabase.openInMemory(legacyExecutor);
      final migratedRepo = LocalBuildingRepository(migratedDb);

      // Existing building loaded cleanly with default rotation 0
      final existing = await migratedRepo.getBuildings('cityA');
      expect(existing.length, 1);
      expect(existing.first.id, 'legacy1');
      expect(existing.first.rotation, 0);

      // New building with rotation 180 can now be saved without error
      final newB = Building(
        id: 'newB',
        cityId: 'cityA',
        typeId: 'apartments',
        x: 5,
        y: 6,
        rotation: 180,
        createdAt: DateTime.utc(2040, 1, 1),
        updatedAt: DateTime.utc(2040, 1, 1),
      );
      await migratedRepo.saveBuilding(newB);

      final reloaded = await migratedRepo.getBuildings('cityA');
      expect(reloaded.length, 2);
      expect(reloaded.firstWhere((b) => b.id == 'newB').rotation, 180);

      await migratedDb.close();
    });

    test('ResourceLedger persists amounts map and updates correctly', () async {
      final ledger = ResourceLedger(
        cityId: 'c1',
        amounts: {
          ResourceLedger.coinsKey: 2500.0,
          ResourceLedger.populationKey: 80.0,
          ResourceLedger.happinessKey: 95.0,
          ResourceLedger.pollutionKey: 10.0,
        },
        updatedAt: DateTime.utc(2040, 1, 1),
      );

      await resourceRepo.saveLedger(ledger);

      final fetched = await resourceRepo.getLedger('c1');
      expect(fetched, isNotNull);
      expect(fetched!.coins, 2500);
      expect(fetched.population, 80);
      expect(fetched.happiness, 95);
      expect(fetched.pollution, 10);

      // Delete by city
      await resourceRepo.deleteByCity('c1');
      expect(await resourceRepo.getLedger('c1'), isNull);
    });

    test('MissionProgress persists and tracks completion and claim status', () async {
      final p1 = MissionProgress(
        cityId: 'c1',
        missionId: 'm1_housing',
        status: MissionStatus.completed,
        progress: 1.0,
        rewardClaimed: true,
        completedAt: DateTime.utc(2040, 1, 2),
        updatedAt: DateTime.utc(2040, 1, 2),
      );

      await missionRepo.saveProgress(p1);

      final list = await missionRepo.getProgress('c1');
      expect(list.length, 1);
      expect(list.first.missionId, 'm1_housing');
      expect(list.first.status, MissionStatus.completed);
      expect(list.first.rewardClaimed, isTrue);

      await missionRepo.deleteByCity('c1');
      expect(await missionRepo.getProgress('c1'), isEmpty);
    });

    test('PlayerProgress persists XP, level, and JSON collection lists', () async {
      final progress = PlayerProgress(
        playerId: PlayerProgress.localPlayerId,
        level: 3,
        experience: 550,
        unlockedIds: ['mall', 'park_large'],
        claimedMissionIds: ['m1_housing', 'm2_power'],
        completedAchievementIds: ['first_home', 'green_city'],
        updatedAt: DateTime.utc(2040, 1, 5),
      );

      await progressRepo.saveProgress(progress);

      final fetched = await progressRepo.getProgress(PlayerProgress.localPlayerId);
      expect(fetched, isNotNull);
      expect(fetched!.level, 3);
      expect(fetched.experience, 550);
      expect(fetched.unlockedIds, ['mall', 'park_large']);
      expect(fetched.claimedMissionIds, ['m1_housing', 'm2_power']);
      expect(fetched.completedAchievementIds, ['first_home', 'green_city']);
    });

    test('SettingsRepository persists and resets user preferences', () async {
      const settings = AppSettings(
        soundEnabled: false,
        musicEnabled: true,
        masterVolume: 0.75,
        simulationSpeed: 2,
        showGrid: false,
        tutorialCompleted: true,
      );

      await settingsRepo.saveSettings(settings);

      final fetched = await settingsRepo.getSettings();
      expect(fetched.soundEnabled, isFalse);
      expect(fetched.musicEnabled, isTrue);
      expect(fetched.masterVolume, 0.75);
      expect(fetched.simulationSpeed, 2);
      expect(fetched.showGrid, isFalse);
      expect(fetched.tutorialCompleted, isTrue);

      // Reset
      await settingsRepo.resetSettings();
      final reset = await settingsRepo.getSettings();
      expect(reset.soundEnabled, isTrue);
      expect(reset.tutorialCompleted, isFalse);
    });

    test('App restart recovery: persists data across database reopen', () async {
      final tempDir = await Directory.systemTemp.createTemp('cb2040_test_');
      final dbFile = File('${tempDir.path}/test_restart.sqlite');

      try {
        // Session 1: open db, write data, close db
        final db1 = AppDatabase.forTesting(NativeDatabase(dbFile));
        await db1.init();
        final cityRepo1 = LocalCityRepository(db1);
        final buildingRepo1 = LocalBuildingRepository(db1);

        final city = City(
          id: 'restart-city-1',
          name: 'Persistent Oasis',
          mapWidth: 24,
          mapHeight: 24,
          seed: 12345,
          day: 12,
          population: 500,
          createdAt: DateTime.utc(2040, 1, 1),
          updatedAt: DateTime.utc(2040, 1, 12),
        );
        final b = Building(
          id: 'b-restart-1',
          cityId: 'restart-city-1',
          typeId: 'hospital',
          x: 4,
          y: 7,
          level: 2,
          createdAt: DateTime.utc(2040, 1, 1),
          updatedAt: DateTime.utc(2040, 1, 12),
        );

        await cityRepo1.saveCity(city);
        await buildingRepo1.saveBuilding(b);

        // App closed / crash / restart
        await db1.close();

        // Session 2: open new db instance on the same file (relaunching app)
        final db2 = AppDatabase.forTesting(NativeDatabase(dbFile));
        await db2.init();
        final cityRepo2 = LocalCityRepository(db2);
        final buildingRepo2 = LocalBuildingRepository(db2);

        // Verify city survived restart intact
        final loadedCity = await cityRepo2.getCity('restart-city-1');
        expect(loadedCity, isNotNull);
        expect(loadedCity!.name, 'Persistent Oasis');
        expect(loadedCity.seed, 12345);
        expect(loadedCity.population, 500);
        expect(loadedCity.day, 12);

        // Verify buildings survived restart intact
        final loadedBuildings = await buildingRepo2.getBuildings('restart-city-1');
        expect(loadedBuildings.length, 1);
        expect(loadedBuildings.first.typeId, 'hospital');
        expect(loadedBuildings.first.level, 2);

        await db2.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}

class _TestDelegate extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
