import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/repositories/memory/memory_building_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_city_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_mission_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_player_progress_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_resource_repository.dart';
import 'package:city_builder_2040/services/autosave_service.dart';

void main() {
  group('AutosaveService', () {
    late MemoryCityRepository cityRepo;
    late MemoryBuildingRepository buildingRepo;
    late MemoryResourceRepository resourceRepo;
    late MemoryMissionRepository missionRepo;
    late MemoryPlayerProgressRepository progressRepo;
    late AutosaveService autosave;

    setUp(() {
      cityRepo = MemoryCityRepository();
      buildingRepo = MemoryBuildingRepository();
      resourceRepo = MemoryResourceRepository();
      missionRepo = MemoryMissionRepository();
      progressRepo = MemoryPlayerProgressRepository();

      autosave = AutosaveService(
        cities: cityRepo,
        buildings: buildingRepo,
        resources: resourceRepo,
        missions: missionRepo,
        playerProgress: progressRepo,
      );
    });

    test('saveSnapshot coordinates writes across all repositories', () async {
      final now = DateTime.utc(2040, 1, 1);
      final city = City(
        id: 'city-1',
        name: 'Solaria',
        mapWidth: 20,
        mapHeight: 20,
        createdAt: now,
        updatedAt: now,
      );
      final building = Building(
        id: 'b-1',
        cityId: 'city-1',
        typeId: 'residential_small',
        x: 2,
        y: 3,
        createdAt: now,
        updatedAt: now,
      );
      final ledger = ResourceLedger(
        cityId: 'city-1',
        amounts: {ResourceLedger.coinsKey: 1200.0},
        updatedAt: now,
      );
      final mission = MissionProgress(
        cityId: 'city-1',
        missionId: 'm1',
        status: MissionStatus.completed,
        progress: 1.0,
        updatedAt: now,
      );
      final progress = PlayerProgress(
        playerId: PlayerProgress.localPlayerId,
        level: 2,
        experience: 150,
        updatedAt: now,
      );

      final saved = await autosave.saveSnapshot(
        city: city,
        buildingList: [building],
        ledger: ledger,
        missionProgressList: [mission],
        progress: progress,
      );

      expect(saved, isTrue);

      // Verify all repositories received their respective records
      expect(await cityRepo.getCity('city-1'), isNotNull);
      expect((await buildingRepo.getBuildings('city-1')).length, 1);
      expect((await resourceRepo.getLedger('city-1'))?.coins, 1200);
      expect((await missionRepo.getProgress('city-1')).length, 1);
      expect(
        (await progressRepo.getProgress(PlayerProgress.localPlayerId))?.level,
        2,
      );
    });

    test('deleteCity removes city and all related resources, buildings, missions', () async {
      final now = DateTime.utc(2040, 1, 1);
      await autosave.saveSnapshot(
        city: City(
          id: 'city-to-del',
          name: 'Old Town',
          mapWidth: 10,
          mapHeight: 10,
          createdAt: now,
          updatedAt: now,
        ),
        buildingList: [
          Building(
            id: 'b-old',
            cityId: 'city-to-del',
            typeId: 'road',
            x: 0,
            y: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        ledger: ResourceLedger(
          cityId: 'city-to-del',
          amounts: {ResourceLedger.coinsKey: 50.0},
          updatedAt: now,
        ),
        missionProgressList: [
          MissionProgress(
            cityId: 'city-to-del',
            missionId: 'm-old',
            updatedAt: now,
          ),
        ],
        progress: PlayerProgress(
          playerId: PlayerProgress.localPlayerId,
          updatedAt: now,
        ),
      );

      // Confirm exists
      expect(await cityRepo.getCity('city-to-del'), isNotNull);

      // Delete
      await autosave.deleteCity('city-to-del');

      // Verify all cleaned up
      expect(await cityRepo.getCity('city-to-del'), isNull);
      expect(await buildingRepo.getBuildings('city-to-del'), isEmpty);
      expect(await resourceRepo.getLedger('city-to-del'), isNull);
      expect(await missionRepo.getProgress('city-to-del'), isEmpty);
    });
  });
}
