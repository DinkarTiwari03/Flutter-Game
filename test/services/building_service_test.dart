import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/core/utils/id_generator.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/map_config.dart';
import 'package:city_builder_2040/game/map/map_generator.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/repositories/memory/memory_building_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_resource_repository.dart';
import 'package:city_builder_2040/services/building_service.dart';
import 'package:city_builder_2040/services/economy_service.dart';

void main() {
  group('BuildingService', () {
    late MemoryBuildingRepository repo;
    late BuildingService service;
    final map = MapGenerator.generate(MapConfig(cols: 32, rows: 32, seed: 10));

    GridPoint findTileOfType(TileType type) {
      for (var r = 0; r < map.rows; r++) {
        for (var c = 0; c < map.cols; c++) {
          if (map.typeAt(c, r) == type) {
            return GridPoint(c, r);
          }
        }
      }
      throw StateError('Tile of type $type not found');
    }

    setUp(() {
      repo = MemoryBuildingRepository();
      service = BuildingService(
        buildings: repo,
        idGenerator: IdGenerator(),
        clock: () => DateTime.utc(2040, 1, 1),
      );
    });

    test('placeBuilding succeeds on valid grass tile and saves to repository', () async {
      final grass = findTileOfType(TileType.grass);
      final building = await service.placeBuilding(
        cityId: 'c1',
        definition: BuildingRegistry.smallHouse,
        position: grass,
        map: map,
        existingBuildings: [],
      );

      expect(building.id, isNotEmpty);
      expect(building.cityId, 'c1');
      expect(building.typeId, BuildingRegistry.smallHouse.id);
      expect(building.x, grass.col);
      expect(building.y, grass.row);
      expect(building.level, 1);

      final inRepo = await repo.getBuildings('c1');
      expect(inRepo.length, 1);
      expect(inRepo.first.id, building.id);
    });

    test('placeBuilding throws ValidationException on invalid terrain', () async {
      final water = findTileOfType(TileType.water);
      expect(
        () => service.placeBuilding(
          cityId: 'c1',
          definition: BuildingRegistry.smallHouse,
          position: water,
          map: map,
          existingBuildings: [],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('upgradeBuilding increments level and saves to repository', () async {
      final grass = findTileOfType(TileType.grass);
      final initial = await service.placeBuilding(
        cityId: 'c1',
        definition: BuildingRegistry.smallHouse,
        position: grass,
        map: map,
        existingBuildings: [],
      );

      final upgraded = await service.upgradeBuilding(
        cityId: 'c1',
        buildingId: initial.id,
        currentBuildings: [initial],
      );

      expect(upgraded.level, 2);
      final inRepo = await repo.getBuildings('c1');
      expect(inRepo.first.level, 2);
    });

    test('upgradeBuilding throws when already at max level', () async {
      final grass = findTileOfType(TileType.grass);
      var building = await service.placeBuilding(
        cityId: 'c1',
        definition: BuildingRegistry.smallHouse, // maxLevel = 3
        position: grass,
        map: map,
        existingBuildings: [],
      );

      // Upgrade to 2
      building = await service.upgradeBuilding(
        cityId: 'c1',
        buildingId: building.id,
        currentBuildings: [building],
      );
      // Upgrade to 3
      building = await service.upgradeBuilding(
        cityId: 'c1',
        buildingId: building.id,
        currentBuildings: [building],
      );
      expect(building.level, 3);

      // Exceeds max level
      expect(
        () => service.upgradeBuilding(
          cityId: 'c1',
          buildingId: building.id,
          currentBuildings: [building],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('demolishBuilding removes building from repository and returns refund', () async {
      final grass = findTileOfType(TileType.grass);
      final building = await service.placeBuilding(
        cityId: 'c1',
        definition: BuildingRegistry.smallHouse,
        position: grass,
        map: map,
        existingBuildings: [],
      );

      final refund = await service.demolishBuilding(
        cityId: 'c1',
        buildingId: building.id,
        currentBuildings: [building],
      );

      // Small house cost is 150 -> 50% refund is 75
      expect(refund, 75);
      final inRepo = await repo.getBuildings('c1');
      expect(inRepo, isEmpty);
    });

    group('with EconomyService attached', () {
      late MemoryResourceRepository resourceRepo;
      late EconomyService economy;
      late BuildingService econService;

      setUp(() {
        resourceRepo = MemoryResourceRepository();
        economy = EconomyService(
          resources: resourceRepo,
          idGenerator: IdGenerator(),
          clock: () => DateTime.utc(2040, 1, 1),
        );
        econService = BuildingService(
          buildings: repo,
          resources: resourceRepo,
          economy: economy,
          idGenerator: IdGenerator(),
          clock: () => DateTime.utc(2040, 1, 1),
        );
      });

      test('deducts construction cost from ledger', () async {
        await economy.getOrInitLedger('c1'); // starts with 25000 coins
        final grass = findTileOfType(TileType.grass);

        await econService.placeBuilding(
          cityId: 'c1',
          definition: BuildingRegistry.smallHouse, // cost 150
          position: grass,
          map: map,
          existingBuildings: [],
        );

        final ledger = await resourceRepo.getLedger('c1');
        expect(ledger?.coins, 25000 - 150);
      });

      test('throws ValidationException when coins are insufficient to build', () async {
        final brokeLedger = ResourceLedger.initial('c1', startingCoins: 50);
        await resourceRepo.saveLedger(brokeLedger);
        final grass = findTileOfType(TileType.grass);

        expect(
          () => econService.placeBuilding(
            cityId: 'c1',
            definition: BuildingRegistry.smallHouse, // cost 150
            position: grass,
            map: map,
            existingBuildings: [],
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('deducts upgrade cost from ledger', () async {
        await economy.getOrInitLedger('c1'); // 25000
        final grass = findTileOfType(TileType.grass);

        final building = await econService.placeBuilding(
          cityId: 'c1',
          definition: BuildingRegistry.smallHouse, // 150 deducted -> 24850
          position: grass,
          map: map,
          existingBuildings: [],
        );

        await econService.upgradeBuilding(
          cityId: 'c1',
          buildingId: building.id,
          currentBuildings: [building], // base upgrade cost 100
        );

        final ledger = await resourceRepo.getLedger('c1');
        expect(ledger?.coins, 25000 - 150 - 100);
      });

      test('deposits demolition refund back into ledger', () async {
        await economy.getOrInitLedger('c1');
        final grass = findTileOfType(TileType.grass);

        final building = await econService.placeBuilding(
          cityId: 'c1',
          definition: BuildingRegistry.smallHouse, // cost 150
          position: grass,
          map: map,
          existingBuildings: [],
        );

        final refund = await econService.demolishBuilding(
          cityId: 'c1',
          buildingId: building.id,
          currentBuildings: [building],
        );

        expect(refund, 75);
        final ledger = await resourceRepo.getLedger('c1');
        expect(ledger?.coins, 25000 - 150 + 75);
      });
    });
  });
}
