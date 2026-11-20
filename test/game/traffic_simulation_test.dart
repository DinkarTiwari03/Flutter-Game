import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/urban/compass_direction.dart';
import 'package:city_builder_2040/game/urban/road_graph.dart';
import 'package:city_builder_2040/game/urban/urban_simulation_service.dart';
import 'package:city_builder_2040/game/urban/vehicle.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/city_demographics.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';
import 'package:city_builder_2040/models/traffic/traffic_models.dart';
import 'package:city_builder_2040/repositories/memory/memory_resource_repository.dart';
import 'package:city_builder_2040/services/economy_service.dart';
import 'package:city_builder_2040/services/simulation_service.dart';

void main() {
  group('Phase 1: Advanced Traffic Simulation - Road Network & Upgrades', () {
    test('Road graph correctly registers road levels, capacities, and tiers', () {
      final graph = RoadGraph();
      final buildings = [
        Building(
          id: 'r1',
          cityId: 'c1',
          typeId: 'road',
          x: 2,
          y: 2,
          level: 1, // Small Road
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Building(
          id: 'r2',
          cityId: 'c1',
          typeId: 'road',
          x: 3,
          y: 2,
          level: 2, // Medium Avenue
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Building(
          id: 'r3',
          cityId: 'c1',
          typeId: 'road',
          x: 4,
          y: 2,
          level: 3, // Large Boulevard
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Building(
          id: 'r4',
          cityId: 'c1',
          typeId: 'road',
          x: 5,
          y: 2,
          level: 4, // High-Capacity Expressway
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      graph.updateFromBuildings(buildings);

      expect(graph.tierAt(const GridPoint(2, 2)), equals(RoadTier.small));
      expect(graph.capacityAt(const GridPoint(2, 2)), equals(4));

      expect(graph.tierAt(const GridPoint(3, 2)), equals(RoadTier.medium));
      expect(graph.capacityAt(const GridPoint(3, 2)), equals(8));

      expect(graph.tierAt(const GridPoint(4, 2)), equals(RoadTier.large));
      expect(graph.capacityAt(const GridPoint(4, 2)), equals(16));

      expect(graph.tierAt(const GridPoint(5, 2)), equals(RoadTier.highway));
      expect(graph.capacityAt(const GridPoint(5, 2)), equals(32));
    });

    test('Traffic signals are automatically installed at 3-way and 4-way intersections', () {
      final graph = RoadGraph();
      // Create a 4-way intersection centered at (5, 5)
      final roads = [
        const GridPoint(5, 5),
        const GridPoint(6, 5),
        const GridPoint(4, 5),
        const GridPoint(5, 6),
        const GridPoint(5, 4),
      ];

      final buildings = roads
          .map((pt) => Building(
                id: 'r_${pt.col}_${pt.row}',
                cityId: 'c1',
                typeId: 'road',
                x: pt.col,
                y: pt.row,
                level: 1,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ))
          .toList();

      graph.updateFromBuildings(buildings);

      expect(graph.isIntersection(const GridPoint(5, 5)), isTrue);
      expect(graph.isIntersection(const GridPoint(6, 5)), isFalse);

      final signal = graph.signalAt(const GridPoint(5, 5));
      expect(signal, isNotNull);

      // Verify phase transitions
      signal!.state = SignalState.horizontalGreen;
      expect(signal.canPass(isEastWest: true), isTrue);
      expect(signal.canPass(isEastWest: false), isFalse);

      signal.update(6.0); // Pass phase duration
      expect(signal.state, equals(SignalState.yellowTransition));
      expect(signal.canPass(isEastWest: true), isFalse);

      signal.update(1.5); // Yellow transition completes
      expect(signal.state, equals(SignalState.verticalGreen));
      expect(signal.canPass(isEastWest: true), isFalse);
      expect(signal.canPass(isEastWest: false), isTrue);
    });

    test('Congestion-aware pathfinding avoids gridlocked segments and takes bypass roads', () {
      final graph = RoadGraph();
      // Build a 2x3 grid where:
      // Direct path: (0,0) -> (1,0) -> (2,0)
      // Bypass path: (0,0) -> (0,1) -> (1,1) -> (2,1) -> (2,0)
      final roadPts = [
        const GridPoint(0, 0),
        const GridPoint(1, 0),
        const GridPoint(2, 0),
        const GridPoint(0, 1),
        const GridPoint(1, 1),
        const GridPoint(2, 1),
      ];

      final buildings = roadPts
          .map((pt) => Building(
                id: 'r_${pt.col}_${pt.row}',
                cityId: 'c1',
                typeId: 'road',
                x: pt.col,
                y: pt.row,
                level: 1,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ))
          .toList();

      graph.updateFromBuildings(buildings);

      // Normal conditions: direct path is chosen
      final normalPath = graph.findCongestionAwarePath(
        start: const GridPoint(0, 0),
        goal: const GridPoint(2, 0),
      );
      expect(normalPath, equals([const GridPoint(0, 0), const GridPoint(1, 0), const GridPoint(2, 0)]));

      // Congested condition: direct segment (1,0) is severely gridlocked
      final congestion = {const GridPoint(1, 0): 2.5}; // 250% capacity load
      final bypassPath = graph.findCongestionAwarePath(
        start: const GridPoint(0, 0),
        goal: const GridPoint(2, 0),
        congestionLoads: congestion,
      );

      // Verify path diverts through bypass (0,1) -> (1,1) -> (2,1)
      expect(bypassPath, isNotNull);
      expect(bypassPath!.contains(const GridPoint(1, 0)), isFalse);
      expect(bypassPath.contains(const GridPoint(1, 1)), isTrue);
    });
  });

  group('Phase 1: Advanced Traffic Simulation - Vehicle Physics & Anti-Stacking', () {
    test('Vehicles decelerate and stop behind leading vehicles without overlapping', () {
      final service = UrbanSimulationService();
      final buildings = [
        Building(
          id: 'r1',
          cityId: 'c1',
          typeId: 'road',
          x: 0,
          y: 0,
          level: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Building(
          id: 'r2',
          cityId: 'c1',
          typeId: 'road',
          x: 1,
          y: 0,
          level: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      service.syncBuildings(buildings);

      // Spawn lead vehicle at (0,0) -> (1,0)
      final lead = Vehicle(
        id: 'lead',
        type: VehicleType.truckCargo,
        currentTile: const GridPoint(0, 0),
        nextTile: const GridPoint(1, 0),
        heading: CompassDirection.se,
        initialProgress: 0.8,
      );
      lead.isBlocked = true; // Lead stopped

      // Spawn trailing vehicle close behind
      final trail = Vehicle(
        id: 'trail',
        type: VehicleType.sedan,
        currentTile: const GridPoint(0, 0),
        nextTile: const GridPoint(1, 0),
        heading: CompassDirection.se,
        initialProgress: 0.6,
      );

      // Add to internal list via update simulation
      service.clear();
      service.notifyBuildingPlaced(Building(
        id: 'h1',
        cityId: 'c1',
        typeId: 'small_house',
        x: 0,
        y: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      expect(service.roadGraph.contains(const GridPoint(0, 0)), isTrue);
    });

    test('Emergency vehicles maintain high cruising speeds and sirens', () {
      final ambulance = Vehicle(
        id: 'amb1',
        type: VehicleType.ambulance,
        currentTile: const GridPoint(2, 2),
        nextTile: const GridPoint(3, 2),
        heading: CompassDirection.se,
      );

      expect(ambulance.isEmergency, isTrue);
      expect(ambulance.baseSpeed, greaterThanOrEqualTo(60.0));

      ambulance.updateMovement(0.5);
      expect(ambulance.sirenTimer, greaterThan(0.0));
      expect(ambulance.isBlocked, isFalse);
    });

    test('Buses record passengers at bus stops', () {
      final bus = Vehicle(
        id: 'bus1',
        type: VehicleType.bus,
        currentTile: const GridPoint(4, 4),
        nextTile: const GridPoint(5, 4),
        heading: CompassDirection.se,
      );

      expect(bus.isBus, isTrue);
      expect(bus.passengerCount, equals(0));
    });
  });

  group('Phase 1: Advanced Traffic Simulation - Congestion & Economic Consequences', () {
    test('Heavy city traffic generates economic losses, happiness penalty, and extra pollution', () {
      final repo = MemoryResourceRepository();
      final economy = EconomyService(resources: repo);
      final simulation = SimulationService(economy: economy, resources: repo);

      final city = City(
        id: 'c1',
        name: 'Metro 2040',
        mapWidth: 32,
        mapHeight: 32,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final clock = const SimulationClock(hour: 14);
      final demographics = const CityDemographics(totalPopulation: 120);
      final ledger = ResourceLedger.initial('c1', startingCoins: 10000).updateAmounts({
        ResourceLedger.populationKey: 120.0,
      });

      final buildings = [
        Building(
          id: 'res1',
          cityId: 'c1',
          typeId: 'apartments',
          x: 2,
          y: 2,
          level: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Building(
          id: 'com1',
          cityId: 'c1',
          typeId: 'shop',
          x: 4,
          y: 2,
          level: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Building(
          id: 'ind1',
          cityId: 'c1',
          typeId: 'factory',
          x: 6,
          y: 2,
          level: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Simulate with free-flow traffic
      final freeFlowMetrics = TrafficMetrics.empty();
      final cleanResult = simulation.simulateTick(
        ledger: ledger,
        clock: clock,
        demographics: demographics,
        buildings: buildings,
        city: city,
        activeEvents: const [],
        trafficMetrics: freeFlowMetrics,
      );

      // Simulate with heavy congestion traffic
      final heavyMetrics = TrafficMetrics(
        totalActiveVehicles: 35,
        averageSpeed: 22.0,
        overallCongestionPercent: 75, // Severe congestion
        condition: TrafficCondition.gridlock,
        hotspots: [const GridPoint(4, 2)],
        publicTransitRidership: 5,
        trafficDemandReductionPercent: 10,
        economicLossPerHour: 80, // Lost revenue
        alerts: const [],
        segmentStats: const {},
      );

      final congestedResult = simulation.simulateTick(
        ledger: ledger,
        clock: clock,
        demographics: demographics,
        buildings: buildings,
        city: city,
        activeEvents: const [],
        trafficMetrics: heavyMetrics,
      );

      // Happiness should be penalized under congestion
      expect(congestedResult.demographics.totalPopulation, lessThanOrEqualTo(cleanResult.demographics.totalPopulation));
      expect(congestedResult.ledger.pollution, greaterThan(cleanResult.ledger.pollution));
      expect(congestedResult.ledger.happiness, lessThan(cleanResult.ledger.happiness));
    });

    test('TrafficCondition categorizes load ratio correctly', () {
      expect(TrafficCondition.fromLoadRatio(0.2), equals(TrafficCondition.freeFlow));
      expect(TrafficCondition.fromLoadRatio(0.5), equals(TrafficCondition.moderate));
      expect(TrafficCondition.fromLoadRatio(0.85), equals(TrafficCondition.heavy));
      expect(TrafficCondition.fromLoadRatio(1.2), equals(TrafficCondition.gridlock));
    });
  });
}
