import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/buildings/placement_validator.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/map_config.dart';
import 'package:city_builder_2040/game/map/map_generator.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';
import 'package:city_builder_2040/models/building.dart';

void main() {
  group('PlacementValidator', () {
    final map = MapGenerator.generate(MapConfig(cols: 32, rows: 32, seed: 42));

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

    test('validates placement on buildable grass', () {
      final grass = findTileOfType(TileType.grass);
      final result = PlacementValidator.validate(
        map: map,
        definition: BuildingRegistry.smallHouse,
        origin: grass,
        existingBuildings: [],
      );

      expect(result.isValid, isTrue);
      expect(result.reason, PlacementValidationReason.valid);
      expect(result.invalidTiles, isEmpty);
    });

    test('rejects out of bounds coordinates', () {
      final result = PlacementValidator.validate(
        map: map,
        definition: BuildingRegistry.smallHouse,
        origin: const GridPoint(-1, 0),
        existingBuildings: [],
      );

      expect(result.isValid, isFalse);
      expect(result.reason, PlacementValidationReason.outOfBounds);
      expect(result.invalidTiles, contains(const GridPoint(-1, 0)));
    });

    test('rejects multi-tile building when partially out of bounds', () {
      // 2x2 building placed at (31, 31) in a 32x32 map (0..31)
      final result = PlacementValidator.validate(
        map: map,
        definition: BuildingRegistry.apartments,
        origin: const GridPoint(31, 31),
        existingBuildings: [],
      );

      expect(result.isValid, isFalse);
      expect(result.reason, PlacementValidationReason.outOfBounds);
      expect(result.invalidTiles, contains(const GridPoint(32, 31)));
    });

    test('rejects placement on water', () {
      final water = findTileOfType(TileType.water);
      final result = PlacementValidator.validate(
        map: map,
        definition: BuildingRegistry.smallHouse,
        origin: water,
        existingBuildings: [],
      );

      expect(result.isValid, isFalse);
      expect(result.reason, PlacementValidationReason.invalidTerrain);
      expect(result.invalidTiles, contains(water));
    });

    test('rejects building placement overlapping existing building', () {
      final grass = findTileOfType(TileType.grass);
      final existing = Building(
        id: 'b1',
        cityId: 'c1',
        typeId: BuildingRegistry.smallHouse.id,
        x: grass.col,
        y: grass.row,
        level: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = PlacementValidator.validate(
        map: map,
        definition: BuildingRegistry.smallHouse,
        origin: grass,
        existingBuildings: [existing],
      );

      expect(result.isValid, isFalse);
      expect(result.reason, PlacementValidationReason.buildingOverlap);
      expect(result.invalidTiles, contains(grass));
    });

    test('rejects multi-tile building with partial overlap', () {
      final grass = findTileOfType(TileType.grass);
      // Place existing building at grass + (1, 1)
      final existing = Building(
        id: 'b1',
        cityId: 'c1',
        typeId: BuildingRegistry.smallHouse.id,
        x: grass.col + 1,
        y: grass.row + 1,
        level: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Try placing 2x2 apartments at grass
      final result = PlacementValidator.validate(
        map: map,
        definition: BuildingRegistry.apartments,
        origin: grass,
        existingBuildings: [existing],
      );

      expect(result.isValid, isFalse);
      expect(result.reason, PlacementValidationReason.buildingOverlap);
      expect(result.invalidTiles, contains(GridPoint(grass.col + 1, grass.row + 1)));
    });

    test('rejects regular building placement over existing road', () {
      final roadTile = findTileOfType(TileType.road);
      final result = PlacementValidator.validate(
        map: map,
        definition: BuildingRegistry.smallHouse,
        origin: roadTile,
        existingBuildings: [],
      );

      expect(result.isValid, isFalse);
      expect(result.reason, PlacementValidationReason.blockedByRoad);
      expect(result.invalidTiles, contains(roadTile));
    });
  });
}
