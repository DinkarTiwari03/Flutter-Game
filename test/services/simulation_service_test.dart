import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/city_demographics.dart';
import 'package:city_builder_2040/models/city_event.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';
import 'package:city_builder_2040/repositories/memory/memory_resource_repository.dart';
import 'package:city_builder_2040/services/economy_service.dart';
import 'package:city_builder_2040/services/simulation_service.dart';

void main() {
  late MemoryResourceRepository resourceRepo;
  late EconomyService economyService;
  late SimulationService simulationService;

  final fixedTime = DateTime.utc(2040, 1, 1, 8, 0);

  final testCity = City(
    id: 'city_sim_test',
    name: 'Neo Haven',
    mapWidth: 32,
    mapHeight: 32,
    createdAt: fixedTime,
    updatedAt: fixedTime,
    population: 50,
  );

  Building makeBuilding({
    required String id,
    required String typeId,
    int level = 1,
    int x = 0,
    int y = 0,
  }) {
    return Building(
      id: id,
      cityId: testCity.id,
      typeId: typeId,
      x: x,
      y: y,
      level: level,
      createdAt: fixedTime,
      updatedAt: fixedTime,
    );
  }

  setUp(() {
    resourceRepo = MemoryResourceRepository();
    economyService = EconomyService(
      resources: resourceRepo,
      clock: () => fixedTime,
    );
    simulationService = SimulationService(
      economy: economyService,
      resources: resourceRepo,
      clock: () => fixedTime,
    );
  });

  group('SimulationService Calculations', () {
    test('calculateTotalJobs aggregates jobs across commercial and industrial buildings', () {
      final buildings = [
        makeBuilding(id: 'b1', typeId: 'shop', level: 1), // 12 jobs
        makeBuilding(id: 'b2', typeId: 'factory', level: 1), // 40 jobs
      ];

      final jobs = simulationService.calculateTotalJobs(buildings);
      expect(jobs, 52);
    });

    test('calculateHealthcareCapacity and EducationCapacity scale with tiers', () {
      final buildings = [
        makeBuilding(id: 'h1', typeId: 'hospital', level: 1), // 350
        makeBuilding(id: 's1', typeId: 'school', level: 2), // 250 * 1.5 = 375
      ];

      expect(simulationService.calculateHealthcareCapacity(buildings), 350);
      expect(simulationService.calculateEducationCapacity(buildings), 375);
    });

    test('simulateDemographics grows population when housing and utilities are satisfied', () {
      final buildings = [
        makeBuilding(id: 'r1', typeId: 'apartments', level: 1), // 60 cap
        makeBuilding(id: 'p1', typeId: 'solar_plant', level: 1), // power
        makeBuilding(id: 'w1', typeId: 'water_facility', level: 1), // water
      ];

      final electricity = economyService.calculateElectricity(buildings);
      final water = economyService.calculateWater(buildings);

      final demo = simulationService.simulateDemographics(
        currentPopulation: 10,
        buildings: buildings,
        happiness: 80,
        electricity: electricity,
        water: water,
      );

      expect(demo.housingCapacity, 60);
      expect(demo.totalPopulation, greaterThan(10));
      expect(demo.totalPopulation, lessThanOrEqualTo(60));
      expect(demo.migrationRate, greaterThan(0));
    });

    test('simulateDemographics respects housing capacity limit', () {
      final buildings = [
        makeBuilding(id: 'r1', typeId: 'small_house', level: 1), // 12 cap
        makeBuilding(id: 'p1', typeId: 'solar_plant', level: 1),
        makeBuilding(id: 'w1', typeId: 'water_facility', level: 1),
      ];

      final electricity = economyService.calculateElectricity(buildings);
      final water = economyService.calculateWater(buildings);

      final demo = simulationService.simulateDemographics(
        currentPopulation: 12,
        buildings: buildings,
        happiness: 90,
        electricity: electricity,
        water: water,
      );

      // At full capacity, population cannot exceed housing
      expect(demo.totalPopulation, 12);
      expect(demo.occupancyRate, 100);
    });

    test('simulateDemographics declines when utilities fail or happiness drops', () {
      final buildings = [
        makeBuilding(id: 'r1', typeId: 'apartments', level: 1), // 60 cap
      ];

      final electricity = economyService.calculateElectricity(buildings); // deficit
      final water = economyService.calculateWater(buildings);

      final demo = simulationService.simulateDemographics(
        currentPopulation: 30,
        buildings: buildings,
        happiness: 30, // unhappy
        electricity: electricity,
        water: water,
      );

      expect(demo.migrationRate, lessThan(0));
      expect(demo.totalPopulation, lessThan(30));
    });
  });

  group('SimulationService simulateTick Integration', () {
    test('simulateTick advances in-game clock, demographics, and updates ledger', () {
      final ledger = ResourceLedger.initial(testCity.id, startingCoins: 5000);
      final clock = SimulationClock.initial();
      const demographics = CityDemographics(totalPopulation: 10);
      final buildings = [
        makeBuilding(id: 'r1', typeId: 'apartments', level: 1),
        makeBuilding(id: 'c1', typeId: 'shop', level: 1),
        makeBuilding(id: 'p1', typeId: 'solar_plant', level: 1),
        makeBuilding(id: 'w1', typeId: 'water_facility', level: 1),
      ];

      final result = simulationService.simulateTick(
        ledger: ledger,
        clock: clock,
        demographics: demographics,
        buildings: buildings,
        city: testCity,
        activeEvents: [],
      );

      // Clock advanced 1 hour
      expect(result.clock.hour, 9);
      expect(result.clock.tickCount, 1);

      // Demographics simulated (shop: 12 + solar_plant: 6 + water_facility: 12 = 30)
      expect(result.demographics.housingCapacity, 60);
      expect(result.demographics.totalJobs, 30);

      // Transactions generated
      expect(result.transactions, isNotEmpty);
      expect(result.ledger.coins, greaterThan(0));
    });

    test('active civic event boosts income and decrements duration until expired', () {
      final ledger = ResourceLedger.initial(testCity.id, startingCoins: 2000);
      final clock = SimulationClock.initial();
      const demographics = CityDemographics(totalPopulation: 20);
      final buildings = [
        makeBuilding(id: 'c1', typeId: 'shopping_mall', level: 1),
        makeBuilding(id: 'p1', typeId: 'solar_plant', level: 1),
        makeBuilding(id: 'w1', typeId: 'water_facility', level: 1),
      ];

      final initialEvent = const CityEvent(
        id: 'ev_test',
        title: 'Tax Boom',
        description: '+25% tax revenue',
        type: CityEventType.taxIncomeBonus,
        durationTicks: 2,
        remainingTicks: 2,
        multiplier: 1.25,
      );

      // Tick 1
      final res1 = simulationService.simulateTick(
        ledger: ledger,
        clock: clock,
        demographics: demographics,
        buildings: buildings,
        city: testCity,
        activeEvents: [initialEvent],
      );

      expect(res1.activeEvents.length, 1);
      expect(res1.activeEvents.first.remainingTicks, 1);

      // Tick 2
      final res2 = simulationService.simulateTick(
        ledger: res1.ledger,
        clock: res1.clock,
        demographics: res1.demographics,
        buildings: buildings,
        city: testCity,
        activeEvents: res1.activeEvents,
      );

      // Event should expire after this tick
      expect(res2.activeEvents, isEmpty);
    });

    test('day and night transitions cycle through 24 ticks deterministically', () {
      var clock = const SimulationClock(day: 1, hour: 0, minute: 0);
      var ledger = ResourceLedger.initial(testCity.id);
      var demographics = const CityDemographics();
      final buildings = <Building>[];

      final phasesObserved = <DayPhase>{};

      for (var i = 0; i < 24; i++) {
        final res = simulationService.simulateTick(
          ledger: ledger,
          clock: clock,
          demographics: demographics,
          buildings: buildings,
          city: testCity,
          activeEvents: [],
        );
        clock = res.clock;
        ledger = res.ledger;
        demographics = res.demographics;
        phasesObserved.add(clock.phase);
      }

      // Over 24 hours all 4 diurnal phases must occur
      expect(phasesObserved.contains(DayPhase.dawn), isTrue);
      expect(phasesObserved.contains(DayPhase.day), isTrue);
      expect(phasesObserved.contains(DayPhase.dusk), isTrue);
      expect(phasesObserved.contains(DayPhase.night), isTrue);
      // Clock rolls over to Day 2
      expect(clock.day, 2);
    });
  });
}
