import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/disaster/disaster_engine.dart';
import 'package:city_builder_2040/game/disaster/earthquake_disaster.dart';
import 'package:city_builder_2040/game/disaster/fire_disaster.dart';
import 'package:city_builder_2040/game/disaster/flood_disaster.dart';
import 'package:city_builder_2040/game/disaster/heatwave_disaster.dart';
import 'package:city_builder_2040/game/disaster/storm_disaster.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/urban/road_graph.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/disaster/disaster_models.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';

void main() {
  group('Disaster Models & Config', () {
    test('DisasterConfig respects probability overrides', () {
      final config = DisasterConfig(
        earthquakeProbPerHour: 0.1,
        minHoursBetweenDisasters: 12,
      );
      expect(config.baseProb(DisasterType.earthquake), 0.1);
      expect(config.minHoursBetweenDisasters, 12);
    });

    test('DisasterRiskLevel maps risk multipliers correctly', () {
      expect(DisasterRiskLevel.fromMultiplier(0.8), DisasterRiskLevel.low);
      expect(DisasterRiskLevel.fromMultiplier(1.5), DisasterRiskLevel.elevated);
      expect(DisasterRiskLevel.fromMultiplier(2.2), DisasterRiskLevel.high);
      expect(DisasterRiskLevel.fromMultiplier(3.5), DisasterRiskLevel.critical);
    });
  });

  group('Earthquake Disaster', () {
    test('damages buildings inside epicenter radius and spares distant ones', () {
      final random = math.Random(42);
      final buildings = [
        Building(
          id: 'b1',
          cityId: 'c1',
          typeId: 'small_house',
          x: 10,
          y: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Building(
          id: 'b2',
          cityId: 'c1',
          typeId: 'residential_tower',
          x: 30,
          y: 30,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final roads = {
        const GridPoint(10, 11),
        const GridPoint(11, 10),
        const GridPoint(30, 31),
      };

      final res = EarthquakeDisaster.calculateDamage(
        epicenterX: 10,
        epicenterY: 10,
        severity: DisasterSeverity.major,
        buildings: buildings,
        roadTiles: roads,
        random: random,
      );

      // Building b1 is at epicenter: damaged
      expect(res.buildings.any((b) => b.buildingId == 'b1'), isTrue);
      // Building b2 is far away: untouched
      expect(res.buildings.any((b) => b.buildingId == 'b2'), isFalse);
      expect(res.coinsLost, greaterThan(0));
      expect(res.happinessLost, greaterThan(0));
    });
  });

  group('Fire Disaster', () {
    test('spreads to adjacent building tiles and blocks neighboring roads', () {
      final random = math.Random(123);
      final currentFire = {const GridPoint(5, 5)};
      final buildingTiles = {
        const GridPoint(5, 5),
        const GridPoint(5, 6), // South neighbor
        const GridPoint(6, 5), // East neighbor
        const GridPoint(15, 15), // Unrelated
      };

      Set<GridPoint> spread = {};
      for (var tick = 0; tick < 10; tick++) {
        spread = FireDisaster.spreadFire(
          currentFireTiles: currentFire,
          severity: DisasterSeverity.catastrophic,
          buildingTiles: buildingTiles,
          random: random,
        );
        if (spread.isNotEmpty) break;
      }

      // Should have ignited at least one adjacent building tile
      expect(spread, isNotEmpty);
      expect(spread.contains(const GridPoint(15, 15)), isFalse);

      final buildings = [
        Building(
          id: 'b1',
          cityId: 'c1',
          typeId: 'factory',
          x: 5,
          y: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      final roads = {const GridPoint(5, 4)}; // Adjacent road

      final damageRes = FireDisaster.calculateDamage(
        fireTiles: currentFire,
        buildings: buildings,
        roadTiles: roads,
        severity: DisasterSeverity.major,
        random: random,
      );

      expect(damageRes.buildings.length, 1);
      expect(damageRes.buildings.first.damagePercent, greaterThanOrEqualTo(70.0));
      expect(damageRes.blockedRoads.contains(const GridPoint(5, 4)), isTrue);
    });
  });

  group('Flood & Storm Disasters', () {
    test('Flood blocks all roads within flood radius', () {
      final roads = {
        const GridPoint(10, 10),
        const GridPoint(12, 12),
        const GridPoint(25, 25),
      };

      final flooded = FloodDisaster.floodedRoads(
        epicenterX: 10,
        epicenterY: 10,
        radius: 5.0,
        roadTiles: roads,
      );

      expect(flooded.contains(const GridPoint(10, 10)), isTrue);
      expect(flooded.contains(const GridPoint(12, 12)), isTrue);
      expect(flooded.contains(const GridPoint(25, 25)), isFalse);
    });

    test('Storm produces road blockages and happiness reduction', () {
      final random = math.Random(99);
      final buildings = [
        Building(
          id: 'tower1',
          cityId: 'c1',
          typeId: 'residential_tower',
          x: 10,
          y: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      final roads = {
        const GridPoint(10, 10),
        const GridPoint(10, 11),
      };

      final res = StormDisaster.calculateDamage(
        epicenterX: 10,
        epicenterY: 10,
        severity: DisasterSeverity.moderate,
        buildings: buildings,
        roadTiles: roads,
        random: random,
      );

      expect(res.happinessLost, greaterThan(0));
      expect(res.buildings.isNotEmpty, isTrue);
    });
  });

  group('Heatwave Disaster', () {
    test('Heatwave is city-wide with no road destruction, mitigated by healthcare', () {
      final lowHealthPenalty = HeatwaveDisaster.happinessPenalty(
        DisasterSeverity.major,
        20,
      );
      final highHealthPenalty = HeatwaveDisaster.happinessPenalty(
        DisasterSeverity.major,
        90,
      );

      expect(highHealthPenalty, lessThan(lowHealthPenalty));

      final dmg = HeatwaveDisaster.calculateDamage(
        severity: DisasterSeverity.moderate,
        population: 500,
        healthcareRating: 80,
      );

      expect(dmg.buildings, isEmpty);
      expect(dmg.blockedRoads, isEmpty);
      expect(dmg.coinsLost, greaterThan(0));
      expect(dmg.happinessLost, greaterThan(0));
    });
  });

  group('DisasterEngine Lifecycle & Testing Mode', () {
    test('Manual trigger starts warning phase and advances through lifecycle to completion', () {
      final engine = DisasterEngine();
      final buildings = [
        Building(
          id: 'house1',
          cityId: 'c1',
          typeId: 'small_house',
          x: 10,
          y: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      final roads = {const GridPoint(10, 11), const GridPoint(10, 12)};

      // 1. Manual trigger
      engine.triggerDisaster(
        DisasterType.earthquake,
        severity: DisasterSeverity.moderate,
        epicenterX: 10,
        epicenterY: 10,
        buildings: buildings,
        roadTiles: roads,
      );

      expect(engine.activeDisaster, isNotNull);
      expect(engine.activeDisaster!.phase, DisasterPhase.warning);
      expect(engine.notifications, isNotEmpty);

      // Advance warning -> occurring (3 ticks)
      for (var i = 0; i < 3; i++) {
        engine.update(
          1.0,
          buildings: buildings,
          roadTiles: roads,
          population: 100,
          pollution: 20,
          happiness: 80,
          healthcareRating: 70,
          clock: const SimulationClock(),
        );
      }

      expect(engine.activeDisaster!.phase, DisasterPhase.occurring);

      // Advance occurring -> response (2 ticks)
      for (var i = 0; i < 2; i++) {
        engine.update(
          1.0,
          buildings: buildings,
          roadTiles: roads,
          population: 100,
          pollution: 20,
          happiness: 80,
          healthcareRating: 70,
          clock: const SimulationClock(),
        );
      }

      expect(engine.activeDisaster!.phase, DisasterPhase.response);
      expect(engine.activeDisaster!.report, isNotNull);

      // Advance response -> recovery (4 ticks)
      for (var i = 0; i < 4; i++) {
        engine.update(
          1.0,
          buildings: buildings,
          roadTiles: roads,
          population: 100,
          pollution: 20,
          happiness: 80,
          healthcareRating: 70,
          clock: const SimulationClock(),
        );
      }

      expect(engine.activeDisaster!.phase, DisasterPhase.recovery);

      // Advance recovery -> complete (moderate recovery = 12 ticks)
      for (var i = 0; i < 12; i++) {
        engine.update(
          1.0,
          buildings: buildings,
          roadTiles: roads,
          population: 100,
          pollution: 20,
          happiness: 80,
          healthcareRating: 70,
          clock: const SimulationClock(),
        );
      }

      // Complete: disaster cleared, archived to history
      expect(engine.activeDisaster, isNull);
      expect(engine.history, isNotEmpty);
      expect(engine.blockedRoads, isEmpty);
    });
  });

  group('RoadGraph Disaster Integration', () {
    test('RoadGraph excludes disaster blocked tiles from pathfinding', () {
      final graph = RoadGraph();
      final buildings = [
        Building(id: 'r1', cityId: 'c1', typeId: 'road', x: 0, y: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        Building(id: 'r2', cityId: 'c1', typeId: 'road', x: 1, y: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        Building(id: 'r3', cityId: 'c1', typeId: 'road', x: 2, y: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        Building(id: 'r4', cityId: 'c1', typeId: 'road', x: 0, y: 1, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        Building(id: 'r5', cityId: 'c1', typeId: 'road', x: 1, y: 1, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        Building(id: 'r6', cityId: 'c1', typeId: 'road', x: 2, y: 1, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      ];
      graph.updateFromBuildings(buildings);

      // Path from (0, 0) to (2, 0) normally travels straight: (0,0) -> (1,0) -> (2,0)
      final normalPath = graph.findCongestionAwarePath(
        start: const GridPoint(0, 0),
        goal: const GridPoint(2, 0),
        congestionLoads: {},
      );
      expect(normalPath, [
        const GridPoint(0, 0),
        const GridPoint(1, 0),
        const GridPoint(2, 0),
      ]);

      // Block (1, 0) due to earthquake debris
      graph.setBlockedTiles({const GridPoint(1, 0)});

      // Now path must bypass via (0, 1) -> (1, 1) -> (2, 1) -> (2, 0)
      final bypassPath = graph.findCongestionAwarePath(
        start: const GridPoint(0, 0),
        goal: const GridPoint(2, 0),
        congestionLoads: {},
      );
      expect(bypassPath, isNotNull);
      expect(bypassPath!.contains(const GridPoint(1, 0)), isFalse);
      expect(bypassPath.first, const GridPoint(0, 0));
      expect(bypassPath.last, const GridPoint(2, 0));
    });
  });
}
