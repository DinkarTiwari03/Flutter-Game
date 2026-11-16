import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/urban/compass_direction.dart';
import 'package:city_builder_2040/game/urban/road_graph.dart';
import 'package:city_builder_2040/game/urban/vehicle.dart';
import 'package:city_builder_2040/game/urban/pedestrian.dart';
import 'package:city_builder_2040/game/urban/urban_simulation_service.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';

Building _makeBuilding({
  required String id,
  required String typeId,
  required int x,
  required int y,
  int level = 1,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Building(
    id: id,
    cityId: 'c1',
    typeId: typeId,
    x: x,
    y: y,
    level: level,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('CompassDirection tests', () {
    test('opposite directions are correct', () {
      expect(CompassDirection.ne.opposite, CompassDirection.sw);
      expect(CompassDirection.sw.opposite, CompassDirection.ne);
      expect(CompassDirection.nw.opposite, CompassDirection.se);
      expect(CompassDirection.se.opposite, CompassDirection.nw);
    });

    test('grid deltas match 2.5D coordinate space', () {
      expect(CompassDirection.ne.gridDelta, const GridPoint(0, -1));
      expect(CompassDirection.nw.gridDelta, const GridPoint(-1, 0));
      expect(CompassDirection.se.gridDelta, const GridPoint(1, 0));
      expect(CompassDirection.sw.gridDelta, const GridPoint(0, 1));
    });

    test('fromGridDelta detects cardinal steps accurately', () {
      const origin = GridPoint(5, 5);
      expect(CompassDirection.fromGridDelta(origin, const GridPoint(6, 5)), CompassDirection.se);
      expect(CompassDirection.fromGridDelta(origin, const GridPoint(4, 5)), CompassDirection.nw);
      expect(CompassDirection.fromGridDelta(origin, const GridPoint(5, 6)), CompassDirection.sw);
      expect(CompassDirection.fromGridDelta(origin, const GridPoint(5, 4)), CompassDirection.ne);
    });

    test('fromVelocity computes compass heading from movement offset', () {
      expect(CompassDirection.fromVelocity(const Offset(10, 5)), CompassDirection.se);
      expect(CompassDirection.fromVelocity(const Offset(-10, 5)), CompassDirection.sw);
      expect(CompassDirection.fromVelocity(const Offset(-10, -5)), CompassDirection.nw);
      expect(CompassDirection.fromVelocity(const Offset(10, -5)), CompassDirection.ne);
    });
  });

  group('RoadGraph tests', () {
    test('empty graph behavior', () {
      final graph = RoadGraph();
      expect(graph.isEmpty, isTrue);
      expect(graph.length, equals(0));
      expect(graph.contains(const GridPoint(0, 0)), isFalse);
      expect(graph.findPath(const GridPoint(0, 0), const GridPoint(1, 0)), isNull);
    });

    test('updates from buildings and detects connectivity', () {
      final graph = RoadGraph();
      final buildings = [
        _makeBuilding(id: 'r1', typeId: 'road', x: 2, y: 2),
        _makeBuilding(id: 'r2', typeId: 'road', x: 3, y: 2),
        _makeBuilding(id: 'r3', typeId: 'road', x: 4, y: 2),
        _makeBuilding(id: 'r4', typeId: 'road', x: 3, y: 3),
        _makeBuilding(id: 'b1', typeId: 'house_small', x: 5, y: 5), // non-road
      ];

      graph.updateFromBuildings(buildings);
      expect(graph.length, equals(4));
      expect(graph.contains(const GridPoint(2, 2)), isTrue);
      expect(graph.contains(const GridPoint(5, 5)), isFalse);

      // (3, 2) is connected to (2, 2), (4, 2), and (3, 3) -> T-intersection
      expect(graph.isIntersection(const GridPoint(3, 2)), isTrue);
      expect(graph.isDeadEnd(const GridPoint(2, 2)), isTrue); // only 1 connection
      expect(graph.isDeadEnd(const GridPoint(3, 3)), isTrue);
    });

    test('BFS shortest path finding', () {
      final graph = RoadGraph();
      final buildings = [
        _makeBuilding(id: 'r1', typeId: 'road', x: 0, y: 0),
        _makeBuilding(id: 'r2', typeId: 'road', x: 1, y: 0),
        _makeBuilding(id: 'r3', typeId: 'road', x: 2, y: 0),
        _makeBuilding(id: 'r4', typeId: 'road', x: 2, y: 1),
        _makeBuilding(id: 'r5', typeId: 'road', x: 2, y: 2),
      ];
      graph.updateFromBuildings(buildings);

      final path = graph.findPath(const GridPoint(0, 0), const GridPoint(2, 2));
      expect(path, isNotNull);
      expect(path!.length, equals(5));
      expect(path.first, equals(const GridPoint(0, 0)));
      expect(path.last, equals(const GridPoint(2, 2)));

      final unreachable = graph.findPath(const GridPoint(0, 0), const GridPoint(10, 10));
      expect(unreachable, isNull);
    });

    test('pickNextRoad chooses valid neighbors and avoids U-turns', () {
      final graph = RoadGraph();
      final buildings = [
        _makeBuilding(id: 'r1', typeId: 'road', x: 0, y: 0),
        _makeBuilding(id: 'r2', typeId: 'road', x: 1, y: 0),
        _makeBuilding(id: 'r3', typeId: 'road', x: 2, y: 0),
      ];
      graph.updateFromBuildings(buildings);

      final next = graph.pickNextRoad(
        const GridPoint(1, 0),
        CompassDirection.se,
        math.Random(42),
      );
      // Traveling SE from (0,0) to (1,0): should continue forward to (2,0)
      expect(next, equals(const GridPoint(2, 0)));
    });

    test('findNearestRoad locates closest road tile within distance', () {
      final graph = RoadGraph();
      final buildings = [
        _makeBuilding(id: 'r1', typeId: 'road', x: 5, y: 5),
      ];
      graph.updateFromBuildings(buildings);

      final nearest = graph.findNearestRoad(const GridPoint(5, 7), maxDistance: 4);
      expect(nearest, equals(const GridPoint(5, 5)));

      final tooFar = graph.findNearestRoad(const GridPoint(20, 20), maxDistance: 4);
      expect(tooFar, isNull);
    });
  });

  group('Vehicle simulation tests', () {
    test('movement advances progress and updates worldPos', () {
      final vehicle = Vehicle(
        id: 'v1',
        type: VehicleType.sedan,
        currentTile: const GridPoint(0, 0),
        nextTile: const GridPoint(1, 0),
        heading: CompassDirection.se,
      );

      final initialPos = vehicle.worldPos;
      expect(vehicle.progress, equals(0.0));

      vehicle.updateMovement(0.1);
      expect(vehicle.progress, greaterThan(0.0));
      expect(vehicle.worldPos, isNot(equals(initialPos)));
    });

    test('waiting vehicle pauses movement', () {
      final vehicle = Vehicle(
        id: 'v1',
        type: VehicleType.sedan,
        currentTile: const GridPoint(0, 0),
        nextTile: const GridPoint(1, 0),
        heading: CompassDirection.se,
      );

      vehicle.waitTimer = 1.0;
      final initialProgress = vehicle.progress;

      vehicle.updateMovement(0.1);
      expect(vehicle.progress, equals(initialProgress));
      expect(vehicle.waitTimer, closeTo(0.9, 0.001));
    });

    test('advanceTo transitions to new road tile', () {
      final vehicle = Vehicle(
        id: 'v1',
        type: VehicleType.sedan,
        currentTile: const GridPoint(0, 0),
        nextTile: const GridPoint(1, 0),
        heading: CompassDirection.se,
      );

      vehicle.advanceTo(const GridPoint(2, 0));
      expect(vehicle.currentTile, equals(const GridPoint(1, 0)));
      expect(vehicle.nextTile, equals(const GridPoint(2, 0)));
      expect(vehicle.progress, equals(0.0));
      expect(vehicle.heading, equals(CompassDirection.se));
    });
  });

  group('Pedestrian simulation tests', () {
    test('animation frame cycles with walking time', () {
      final pedestrian = Pedestrian(
        id: 'p1',
        type: PedestrianType.citizen,
        currentTile: const GridPoint(0, 0),
        nextTile: const GridPoint(1, 0),
        heading: CompassDirection.se,
      );

      expect(pedestrian.animFrame, equals(1));
      pedestrian.walkAnimTime = 0.15;
      expect(pedestrian.animFrame, equals(2));
      pedestrian.walkAnimTime = 0.30;
      expect(pedestrian.animFrame, equals(3));
    });

    test('idle pauses walking movement', () {
      final pedestrian = Pedestrian(
        id: 'p1',
        type: PedestrianType.citizen,
        currentTile: const GridPoint(0, 0),
        nextTile: const GridPoint(1, 0),
        heading: CompassDirection.se,
      );

      pedestrian.idleTimer = 1.0;
      final pos = pedestrian.worldPos;

      pedestrian.updateMovement(0.1);
      expect(pedestrian.worldPos, equals(pos));
      expect(pedestrian.idleTimer, closeTo(0.9, 0.001));
    });

    test('entering and exiting alters opacity', () {
      final pedestrian = Pedestrian(
        id: 'p1',
        type: PedestrianType.citizen,
        currentTile: const GridPoint(0, 0),
        nextTile: const GridPoint(1, 0),
        heading: CompassDirection.se,
      );

      pedestrian.isExiting = true;
      pedestrian.opacity = 0.2;
      pedestrian.updateMovement(0.1);
      expect(pedestrian.opacity, greaterThan(0.2));

      pedestrian.isExiting = false;
      pedestrian.isEntering = true;
      pedestrian.opacity = 0.8;
      pedestrian.updateMovement(0.1);
      expect(pedestrian.opacity, lessThan(0.8));
    });
  });

  group('UrbanSimulationService tests', () {
    test('synchronizes road network and clears entities when roads are removed', () {
      final service = UrbanSimulationService(maxVehicles: 5, maxPedestrians: 5);
      final roads = [
        _makeBuilding(id: 'r1', typeId: 'road', x: 0, y: 0),
        _makeBuilding(id: 'r2', typeId: 'road', x: 1, y: 0),
      ];

      service.syncBuildings(roads);
      expect(service.roadGraph.length, equals(2));

      // Clear all roads
      service.syncBuildings([]);
      expect(service.roadGraph.isEmpty, isTrue);
      expect(service.vehicles.isEmpty, isTrue);
      expect(service.pedestrians.isEmpty, isTrue);
    });

    test('spawns entities on connected road network up to configured limits', () {
      final service = UrbanSimulationService(
        maxVehicles: 3,
        maxPedestrians: 3,
        random: math.Random(100),
      );

      final buildings = [
        _makeBuilding(id: 'r1', typeId: 'road', x: 0, y: 0),
        _makeBuilding(id: 'r2', typeId: 'road', x: 1, y: 0),
        _makeBuilding(id: 'r3', typeId: 'road', x: 2, y: 0),
        _makeBuilding(id: 'h1', typeId: 'house_small', x: 0, y: 1),
        _makeBuilding(id: 'c1', typeId: 'shop_small', x: 2, y: 1),
      ];

      final clock = SimulationClock.initial();

      // Run multiple simulation ticks
      for (var i = 0; i < 50; i++) {
        service.update(
          dt: 0.1,
          buildings: buildings,
          clock: clock,
          population: 150,
          happiness: 80,
        );
      }

      expect(service.vehicles.length, lessThanOrEqualTo(service.maxVehicles));
      expect(service.pedestrians.length, lessThanOrEqualTo(service.maxPedestrians));
    });

    test('hospital proximity can spawn ambulance', () {
      final service = UrbanSimulationService(
        maxVehicles: 10,
        random: math.Random(42),
      );

      final buildings = [
        _makeBuilding(id: 'r1', typeId: 'road', x: 5, y: 5),
        _makeBuilding(id: 'r2', typeId: 'road', x: 6, y: 5),
        _makeBuilding(id: 'hosp', typeId: 'hospital', x: 5, y: 6),
      ];

      final clock = SimulationClock.initial();

      for (var i = 0; i < 80; i++) {
        service.update(
          dt: 0.1,
          buildings: buildings,
          clock: clock,
          population: 200,
          happiness: 85,
        );
      }

      // Hospital is present, so ambulance is an eligible emergency spawn
      expect(service.vehicles.isNotEmpty, isTrue);
    });
  });
}
