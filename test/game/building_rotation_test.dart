import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/buildings/placement_validator.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/map_tile.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';
import 'package:city_builder_2040/models/building.dart';

void main() {
  group('BuildingDefinition.footprintTilesRotated', () {
    const origin = GridPoint(5, 5);

    test('1×1 building – all rotations produce 1-tile footprint', () {
      const def = BuildingRegistry.smallHouse; // 1×1
      for (final rot in [0, 90, 180, 270]) {
        final tiles = def.footprintTilesRotated(origin, rot);
        expect(tiles.length, equals(1), reason: '$rot° should give 1 tile');
        expect(tiles.first, equals(origin));
        expect(def.effectiveWidth(rot), equals(1));
        expect(def.effectiveHeight(rot), equals(1));
      }
    });

    test('2×2 building – all rotations produce 4-tile footprint', () {
      const def = BuildingRegistry.apartments; // 2×2
      for (final rot in [0, 90, 180, 270]) {
        final tiles = def.footprintTilesRotated(origin, rot);
        expect(tiles.length, equals(4), reason: '$rot° should give 4 tiles');
        expect(def.effectiveWidth(rot), equals(2));
        expect(def.effectiveHeight(rot), equals(2));
      }
    });

    test('Non-square 2×3 building – dimensions swap at 90° and 270°', () {
      const rectDef = BuildingDefinition(
        id: 'rect_test',
        name: 'Rect Test',
        category: BuildingCategory.commercial,
        description: 'Testing non-square rotation',
        width: 2,
        height: 3,
        cost: 100,
        baseUpgradeCost: 50,
        icon: Icons.business,
      );

      // At 0°
      expect(rectDef.effectiveWidth(0), equals(2));
      expect(rectDef.effectiveHeight(0), equals(3));
      final tiles0 = rectDef.footprintTilesRotated(origin, 0);
      expect(tiles0.length, equals(6));
      expect(tiles0.contains(const GridPoint(5, 5)), isTrue);
      expect(tiles0.contains(const GridPoint(6, 5)), isTrue);
      expect(tiles0.contains(const GridPoint(5, 7)), isTrue);
      expect(tiles0.contains(const GridPoint(6, 7)), isTrue);

      // At 90° (swapped: 3 cols × 2 rows)
      expect(rectDef.effectiveWidth(90), equals(3));
      expect(rectDef.effectiveHeight(90), equals(2));
      final tiles90 = rectDef.footprintTilesRotated(origin, 90);
      expect(tiles90.length, equals(6));
      expect(tiles90.contains(const GridPoint(5, 5)), isTrue);
      expect(tiles90.contains(const GridPoint(7, 5)), isTrue);
      expect(tiles90.contains(const GridPoint(5, 6)), isTrue);
      expect(tiles90.contains(const GridPoint(7, 6)), isTrue);

      // At 180°
      expect(rectDef.effectiveWidth(180), equals(2));
      expect(rectDef.effectiveHeight(180), equals(3));

      // At 270° (swapped: 3 cols × 2 rows)
      expect(rectDef.effectiveWidth(270), equals(3));
      expect(rectDef.effectiveHeight(270), equals(2));
    });

    test('footprintTiles and footprintTilesRotated(0) produce identical tiles', () {
      const def = BuildingRegistry.hospital; // 2×2
      final standard = def.footprintTiles(origin);
      final rotated0 = def.footprintTilesRotated(origin, 0);
      expect(rotated0, equals(standard));
    });

    test('Rotation cycles through 4 orientations: 0→90→180→270→0', () {
      var rotation = 0;
      final sequence = <int>[];
      for (var i = 0; i < 4; i++) {
        rotation = (rotation + 90) % 360;
        sequence.add(rotation);
      }
      expect(sequence, equals([90, 180, 270, 0]));
    });
  });

  group('Building model rotation & serialization', () {
    test('Building.rotation defaults to 0', () {
      final b = Building(
        id: 'test',
        cityId: 'city1',
        typeId: 'small_house',
        x: 0,
        y: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(b.rotation, equals(0));
    });

    test('Building.fromJson reads rotation field', () {
      final json = {
        'id': 'b1',
        'cityId': 'c1',
        'typeId': 'shop',
        'x': 3,
        'y': 4,
        'level': 1,
        'rotation': 90,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      };
      final b = Building.fromJson(json);
      expect(b.rotation, equals(90));
    });

    test('Building.fromJson defaults rotation to 0 when missing', () {
      final json = {
        'id': 'b2',
        'cityId': 'c1',
        'typeId': 'shop',
        'x': 3,
        'y': 4,
        'level': 1,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      };
      final b = Building.fromJson(json);
      expect(b.rotation, equals(0));
    });

    test('Building.toJson includes rotation', () {
      final b = Building(
        id: 'b3',
        cityId: 'c1',
        typeId: 'apartments',
        x: 2,
        y: 2,
        rotation: 180,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final json = b.toJson();
      expect(json['rotation'], equals(180));
    });

    test('Building.copyWith preserves rotation', () {
      final b = Building(
        id: 'b4',
        cityId: 'c1',
        typeId: 'shop',
        x: 1,
        y: 1,
        rotation: 270,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final b2 = b.copyWith(level: 2);
      expect(b2.rotation, equals(270));
    });

    test('Building.copyWith can update rotation', () {
      final b = Building(
        id: 'b5',
        cityId: 'c1',
        typeId: 'shop',
        x: 1,
        y: 1,
        rotation: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final b2 = b.copyWith(rotation: 90);
      expect(b2.rotation, equals(90));
    });
  });

  group('PlacementValidator with rotation', () {
    late GameMap map;

    setUp(() {
      // 10x10 grass map
      final tiles = List.generate(
        100,
        (i) => MapTile(
          col: i % 10,
          row: i ~/ 10,
          type: TileType.grass,
        ),
      );
      map = GameMap(width: 10, height: 10, tiles: tiles);
    });

    test('Placement valid within bounds for both 0° and 90°', () {
      const rectDef = BuildingDefinition(
        id: 'rect_test',
        name: 'Rect Test',
        category: BuildingCategory.commercial,
        description: 'Testing non-square rotation',
        width: 2,
        height: 3,
        cost: 100,
        baseUpgradeCost: 50,
        icon: Icons.business,
      );

      final res0 = PlacementValidator.validate(
        map: map,
        definition: rectDef,
        origin: const GridPoint(2, 2),
        existingBuildings: [],
        rotation: 0,
      );
      expect(res0.isValid, isTrue);

      final res90 = PlacementValidator.validate(
        map: map,
        definition: rectDef,
        origin: const GridPoint(2, 2),
        existingBuildings: [],
        rotation: 90,
      );
      expect(res90.isValid, isTrue);
    });

    test('Rotation causes outOfBounds when width exceeds edge', () {
      const rectDef = BuildingDefinition(
        id: 'rect_test',
        name: 'Rect Test',
        category: BuildingCategory.commercial,
        description: 'Testing non-square rotation',
        width: 2,
        height: 3,
        cost: 100,
        baseUpgradeCost: 50,
        icon: Icons.business,
      );

      // Position col: 8, row: 2.
      // At 0°: width = 2 -> cols 8, 9 (valid within 10 cols: 0..9)
      final res0 = PlacementValidator.validate(
        map: map,
        definition: rectDef,
        origin: const GridPoint(8, 2),
        existingBuildings: [],
        rotation: 0,
      );
      expect(res0.isValid, isTrue);

      // At 90°: effectiveWidth = 3 -> cols 8, 9, 10 (col 10 is outside 10x10 map!)
      final res90 = PlacementValidator.validate(
        map: map,
        definition: rectDef,
        origin: const GridPoint(8, 2),
        existingBuildings: [],
        rotation: 90,
      );
      expect(res90.isValid, isFalse);
      expect(res90.reason, equals(PlacementValidationReason.outOfBounds));
    });

    test('Overlap detection respects existing building rotation', () {
      const rectDef = BuildingDefinition(
        id: 'rect_test',
        name: 'Rect Test',
        category: BuildingCategory.commercial,
        description: 'Testing non-square rotation',
        width: 2,
        height: 3,
        cost: 100,
        baseUpgradeCost: 50,
        icon: Icons.business,
      );

      // Place existing building at (2, 2) with rotation 90°
      // Its occupied tiles will be cols 2..4, rows 2..3
      final existing = [
        Building(
          id: 'existing1',
          cityId: 'c1',
          typeId: 'rect_test',
          x: 2,
          y: 2,
          rotation: 90,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      // Proposing at (4, 2):
      // Col 4, Row 2 is occupied by the rotated existing building!
      final overlapRes = PlacementValidator.validate(
        map: map,
        definition: BuildingRegistry.smallHouse, // 1x1 at (4, 2)
        origin: const GridPoint(4, 2),
        existingBuildings: existing,
      );
      expect(overlapRes.isValid, isFalse);
      expect(overlapRes.reason, equals(PlacementValidationReason.buildingOverlap));

      // Proposing at (2, 4):
      // If existing was at 0°, row 4 would be occupied. But since existing was 90°,
      // it only occupies rows 2..3! So (2, 4) should be free!
      final freeRes = PlacementValidator.validate(
        map: map,
        definition: BuildingRegistry.smallHouse,
        origin: const GridPoint(2, 4),
        existingBuildings: existing,
      );
      expect(freeRes.isValid, isTrue);
    });
  });
}
