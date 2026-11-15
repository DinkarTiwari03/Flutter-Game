import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/repositories/memory/memory_building_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_city_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_mission_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_player_progress_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_resource_repository.dart';
import 'package:city_builder_2040/services/exhibition_service.dart';

void main() {
  group('ExhibitionService', () {
    late MemoryCityRepository cityRepo;
    late MemoryBuildingRepository buildingRepo;
    late MemoryResourceRepository resourceRepo;
    late MemoryMissionRepository missionRepo;
    late MemoryPlayerProgressRepository playerRepo;
    late ExhibitionService service;

    setUp(() {
      cityRepo = MemoryCityRepository();
      buildingRepo = MemoryBuildingRepository();
      resourceRepo = MemoryResourceRepository();
      missionRepo = MemoryMissionRepository();
      playerRepo = MemoryPlayerProgressRepository();

      service = ExhibitionService(
        cities: cityRepo,
        buildings: buildingRepo,
        resources: resourceRepo,
        missions: missionRepo,
        playerProgress: playerRepo,
      );
    });

    test('getOrCreateDemoCity creates demo city on first access', () async {
      expect(await cityRepo.getCity(ExhibitionService.demoCityId), isNull);

      final city = await service.getOrCreateDemoCity();
      expect(city.id, ExhibitionService.demoCityId);
      expect(city.name, ExhibitionService.demoCityName);
      expect(city.seed, ExhibitionService.demoSeed);
      expect(city.mapWidth, ExhibitionService.demoMapSize);
      expect(city.mapHeight, ExhibitionService.demoMapSize);

      // Subsequent access returns existing city
      final existing = await service.getOrCreateDemoCity();
      expect(existing.id, city.id);
    });

    test('resetDemoCity configures complete showcase layout across all categories', () async {
      final city = await service.resetDemoCity();
      expect(city.population, 480);
      expect(city.day, 12);

      // Verify showcase buildings
      final buildings = await buildingRepo.getBuildings(ExhibitionService.demoCityId);
      expect(buildings, isNotEmpty);
      expect(buildings.length, greaterThanOrEqualTo(15));

      final typeIds = buildings.map((b) => b.typeId).toSet();
      // Residential
      expect(typeIds.contains('residential_small') || typeIds.contains('apartments'), isTrue);
      expect(typeIds.contains('residential_tower'), isTrue);
      // Commercial
      expect(typeIds.contains('shop') || typeIds.contains('mall') || typeIds.contains('office_building'), isTrue);
      // Industrial
      expect(typeIds.contains('factory'), isTrue);
      // Services
      expect(typeIds.contains('hospital') && typeIds.contains('school'), isTrue);
      expect(typeIds.contains('police_station') && typeIds.contains('fire_station'), isTrue);
      // Utilities & Parks
      expect(typeIds.contains('solar_plant') && typeIds.contains('water_tower'), isTrue);
      expect(typeIds.contains('park') || typeIds.contains('botanical_garden'), isTrue);

      // Verify demonstration resource treasury
      final ledger = await resourceRepo.getLedger(ExhibitionService.demoCityId);
      expect(ledger, isNotNull);
      expect(ledger!.coins, 25000);
      expect(ledger.happiness, 88);
      expect(ledger.population, 480);

      // Verify player progression unlocks all buildings for exhibition
      final progress = await playerRepo.getProgress(PlayerProgress.localPlayerId);
      expect(progress, isNotNull);
      expect(progress!.level, 5);
      expect(progress.experience, 1600);
      expect(progress.unlockedIds.length, BuildingRegistry.all.length);

      // Verify mission status setup
      final missions = await missionRepo.getProgress(ExhibitionService.demoCityId);
      expect(missions, isNotEmpty);
      expect(missions.any((m) => m.status == MissionStatus.completed), isTrue);
      expect(missions.any((m) => m.status == MissionStatus.active), isTrue);
    });

    test('resetting demo city does not destroy other saved cities', () async {
      // Create regular player city
      final playerCity = City(
        id: 'player_city_42',
        name: 'My Real Town',
        mapWidth: 24,
        mapHeight: 24,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await cityRepo.saveCity(playerCity);

      // Reset demo city
      await service.resetDemoCity();

      // Verify regular city still exists completely intact
      final retrieved = await cityRepo.getCity('player_city_42');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'My Real Town');
    });
  });
}
