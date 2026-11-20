import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/urban/pedestrian.dart';
import 'package:city_builder_2040/game/urban/urban_simulation_service.dart';
import 'package:city_builder_2040/game/urban/vehicle.dart';
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
  group('Building-Driven Immediate Urban Life Simulation Tests', () {
    late UrbanSimulationService service;
    late List<Building> roadNetwork;
    late SimulationClock clock;

    setUp(() {
      service = UrbanSimulationService(random: math.Random(42));
      clock = const SimulationClock(hour: 12); // midday

      // Setup a connected crossroad network:
      // (5,4) - (5,5) - (5,6)
      //           |
      //         (6,5)
      //           |
      //         (4,5)
      roadNetwork = [
        _makeBuilding(id: 'r1', typeId: 'road', x: 5, y: 5),
        _makeBuilding(id: 'r2', typeId: 'road', x: 5, y: 4),
        _makeBuilding(id: 'r3', typeId: 'road', x: 5, y: 6),
        _makeBuilding(id: 'r4', typeId: 'road', x: 4, y: 5),
        _makeBuilding(id: 'r5', typeId: 'road', x: 6, y: 5),
      ];
      service.syncBuildings(roadNetwork);
    });

    test('Scenario 1: Constructing first small residential house immediately triggers pedestrian & vehicle activity', () {
      final house = _makeBuilding(id: 'house_1', typeId: 'small_house', x: 5, y: 3);
      final currentBuildings = [...roadNetwork, house];

      // Initially no entities
      expect(service.vehicles.isEmpty, isTrue);
      expect(service.pedestrians.isEmpty, isTrue);

      // Player places house
      service.notifyBuildingPlaced(house);

      // Verify activity is registered and pending spawns are enqueued
      expect(service.buildingActivitiesForTest.containsKey('house_1'), isTrue);
      expect(service.pendingSpawnsForTest.isNotEmpty, isTrue);

      // Advance simulation across ~4 seconds to drain the staggered queue
      for (var i = 0; i < 40; i++) {
        service.update(
          dt: 0.1,
          buildings: currentBuildings,
          clock: clock,
          population: 0, // Even with 0 starting population!
        );
      }

      // Vehicles and pedestrians must have spawned
      expect(service.vehicles.isNotEmpty, isTrue);
      expect(service.pedestrians.isNotEmpty, isTrue);

      // Verify personal transport (bicycle, motorcycle, or sedan)
      final hasPersonalVehicle = service.vehicles.any((v) =>
          v.type == VehicleType.bicycle ||
          v.type == VehicleType.motorcycle ||
          v.type == VehicleType.sedan);
      expect(hasPersonalVehicle, isTrue);

      // Verify citizens are walking
      final citizenCount = service.pedestrians
          .where((p) => p.type == PedestrianType.citizen)
          .length;
      expect(citizenCount, greaterThanOrEqualTo(2));
    });

    test('Scenario 2: Second house scales activity with distinct entity IDs', () {
      final house1 = _makeBuilding(id: 'house_1', typeId: 'small_house', x: 5, y: 3);
      final house2 = _makeBuilding(id: 'house_2', typeId: 'small_house', x: 3, y: 5);
      var currentBuildings = [...roadNetwork, house1];

      service.notifyBuildingPlaced(house1);

      // Run 2 seconds
      for (var i = 0; i < 20; i++) {
        service.update(
          dt: 0.1,
          buildings: currentBuildings,
          clock: clock,
          population: 4,
        );
      }

      final initialPedCount = service.pedestrians.length;

      // Now place second house
      currentBuildings = [...currentBuildings, house2];
      service.notifyBuildingPlaced(house2);

      expect(service.buildingActivitiesForTest.containsKey('house_2'), isTrue);

      // Run another 3 seconds
      for (var i = 0; i < 30; i++) {
        service.update(
          dt: 0.1,
          buildings: currentBuildings,
          clock: clock,
          population: 8,
        );
      }

      expect(service.pedestrians.length, greaterThan(initialPedCount));

      // All IDs should be unique
      final pedIds = service.pedestrians.map((p) => p.id).toSet();
      expect(pedIds.length, equals(service.pedestrians.length));

      final vehIds = service.vehicles.map((v) => v.id).toSet();
      expect(vehIds.length, equals(service.vehicles.length));
    });

    test('Scenario 3: Constructing commercial shop spawns shoppers and delivery vehicles', () {
      final shop = _makeBuilding(id: 'shop_1', typeId: 'shop', x: 7, y: 5);
      final currentBuildings = [...roadNetwork, shop];

      service.notifyBuildingPlaced(shop);

      for (var i = 0; i < 35; i++) {
        service.update(
          dt: 0.1,
          buildings: currentBuildings,
          clock: clock,
          population: 0,
        );
      }

      // Check commercial vehicle (delivery van)
      final hasDelivery = service.vehicles.any((v) => v.type == VehicleType.delivery);
      expect(hasDelivery, isTrue);

      // Check commercial pedestrian (shopper or office worker)
      final hasShopper = service.pedestrians.any(
        (p) => p.type == PedestrianType.shopper || p.type == PedestrianType.officeWorker,
      );
      expect(hasShopper, isTrue);
    });

    test('Scenario 4: Constructing industrial factory spawns cargo/flatbed trucks and workers', () {
      final factory = _makeBuilding(id: 'factory_1', typeId: 'factory', x: 5, y: 7);
      final currentBuildings = [...roadNetwork, factory];

      service.notifyBuildingPlaced(factory);

      for (var i = 0; i < 35; i++) {
        service.update(
          dt: 0.1,
          buildings: currentBuildings,
          clock: clock,
          population: 0,
        );
      }

      final hasTruck = service.vehicles.any(
        (v) => v.type == VehicleType.truckCargo || v.type == VehicleType.truckFlat,
      );
      expect(hasTruck, isTrue);

      final hasWorker = service.pedestrians.any(
        (p) => p.type == PedestrianType.constructionWorker,
      );
      expect(hasWorker, isTrue);
    });

    test('Scenario 5: Civic buildings spawn specialized emergency and school transit', () {
      final hospital = _makeBuilding(id: 'hosp_1', typeId: 'hospital', x: 5, y: 3);
      service.notifyBuildingPlaced(hospital);

      final school = _makeBuilding(id: 'sch_1', typeId: 'school', x: 3, y: 5);
      service.notifyBuildingPlaced(school);

      final currentBuildings = [...roadNetwork, hospital, school];

      for (var i = 0; i < 35; i++) {
        service.update(
          dt: 0.1,
          buildings: currentBuildings,
          clock: clock,
          population: 0,
        );
      }

      final hasAmbulance = service.vehicles.any((v) => v.type == VehicleType.ambulance);
      final hasSchoolBus = service.vehicles.any((v) => v.type == VehicleType.bus);
      final hasStudent = service.pedestrians.any((p) => p.type == PedestrianType.student);

      expect(hasAmbulance, isTrue);
      expect(hasSchoolBus, isTrue);
      expect(hasStudent, isTrue);
    });

    test('Scenario 6: Demolishing building cleans activity record without jarring entity removals', () {
      final house = _makeBuilding(id: 'house_1', typeId: 'small_house', x: 5, y: 3);
      service.notifyBuildingPlaced(house);

      for (var i = 0; i < 35; i++) {
        service.update(
          dt: 0.1,
          buildings: [...roadNetwork, house],
          clock: clock,
        );
      }

      final countBeforeDemolish = service.vehicles.length + service.pedestrians.length;
      expect(countBeforeDemolish, greaterThan(0));

      // Player demolishes house
      service.notifyBuildingDemolished('house_1');

      // Activity record removed
      expect(service.buildingActivitiesForTest.containsKey('house_1'), isFalse);

      // Entities remain alive on road network
      final countAfterDemolish = service.vehicles.length + service.pedestrians.length;
      expect(countAfterDemolish, equals(countBeforeDemolish));
    });

    test('Scenario 7: Roads without any non-road buildings do not trigger building-driven minimums', () {
      // Empty city with only roads and 0 population
      service.update(
        dt: 1.0,
        buildings: roadNetwork,
        clock: clock,
        population: 0,
      );

      // No buildings have been placed, building minimums are 0
      expect(service.buildingActivitiesForTest.isEmpty, isTrue);
      expect(service.pendingSpawnsForTest.isEmpty, isTrue);
    });
  });
}
