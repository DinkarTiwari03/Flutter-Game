import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/core/utils/id_generator.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/city_resource.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/models/resource_transaction.dart';
import 'package:city_builder_2040/repositories/memory/memory_resource_repository.dart';
import 'package:city_builder_2040/services/economy_service.dart';

void main() {
  group('EconomyService', () {
    late MemoryResourceRepository resourceRepo;
    late EconomyService service;
    final now = DateTime.utc(2040, 1, 1, 12, 0);

    final testCity = City(
      id: 'city-1',
      name: 'Metro 2040',
      mapWidth: 32,
      mapHeight: 32,
      createdAt: now,
      updatedAt: now,
    );

    Building createTestBuilding({
      required String id,
      required String typeId,
      int level = 1,
      int x = 0,
      int y = 0,
    }) {
      return Building(
        id: id,
        cityId: 'city-1',
        typeId: typeId,
        x: x,
        y: y,
        level: level,
        createdAt: now,
        updatedAt: now,
      );
    }

    setUp(() {
      resourceRepo = MemoryResourceRepository();
      service = EconomyService(
        resources: resourceRepo,
        idGenerator: IdGenerator(),
        clock: () => now,
      );
    });

    test('getOrInitLedger initializes default ledger with starting values', () async {
      final ledger = await service.getOrInitLedger('city-1');
      expect(ledger.cityId, 'city-1');
      expect(ledger.coins, 25000);
      expect(ledger.population, 0);
      expect(ledger.happiness, 75);
      expect(ledger.pollution, 0);
    });

    test('calculateHousingCapacity aggregates residential capacities with tier scaling', () {
      final buildings = [
        createTestBuilding(id: 'b1', typeId: BuildingRegistry.smallHouse.id, level: 1), // 12
        createTestBuilding(id: 'b2', typeId: BuildingRegistry.apartments.id, level: 2), // 60 * 1.5 = 90
        createTestBuilding(id: 'b3', typeId: BuildingRegistry.shop.id, level: 1), // commercial = 0
      ];

      final capacity = service.calculateHousingCapacity(buildings);
      expect(capacity, 12 + 90);
    });

    test('calculateIncome computes residential taxes, commercial, and industrial revenues', () {
      final buildings = [
        createTestBuilding(id: 'b1', typeId: BuildingRegistry.smallHouse.id, level: 1), // capacity 12, tax 1.5
        createTestBuilding(id: 'b2', typeId: BuildingRegistry.shop.id, level: 1), // commercial = 45
        createTestBuilding(id: 'b3', typeId: BuildingRegistry.factory.id, level: 1), // industrial = 150
      ];

      // With 10 population housed in small house (10 * 1.5 = 15 coins)
      final income = service.calculateIncome(buildings, 10);
      expect(income.residentialTaxes, 15);
      expect(income.commercialIncome, 45);
      expect(income.industrialIncome, 150);
      expect(income.total, 15 + 45 + 150);
    });

    test('calculateExpenses calculates building maintenance, roads, and utilities upkeep', () {
      final buildings = [
        createTestBuilding(id: 'b1', typeId: BuildingRegistry.road.id, level: 1), // road upkeep = 1
        createTestBuilding(id: 'b2', typeId: BuildingRegistry.hospital.id, level: 1), // hospital upkeep = 70
        createTestBuilding(id: 'b3', typeId: BuildingRegistry.powerPlant.id, level: 1), // power plant upkeep = 80 + prod upkeep (250 * 0.1 = 25)
      ];

      final expenses = service.calculateExpenses(buildings);
      expect(expenses.roadMaintenance, 1);
      expect(expenses.buildingMaintenance, 70 + 80);
      expect(expenses.electricityProductionCost, 25);
      expect(expenses.total, 1 + 150 + 25);
    });

    test('calculateElectricity accurately computes production, consumption, and satisfaction', () {
      // 1 Power Plant (250kW production) vs Factory (40kW) + Hospital (25kW)
      final buildings = [
        createTestBuilding(id: 'b1', typeId: BuildingRegistry.powerPlant.id, level: 1),
        createTestBuilding(id: 'b2', typeId: BuildingRegistry.factory.id, level: 1),
        createTestBuilding(id: 'b3', typeId: BuildingRegistry.hospital.id, level: 1),
      ];

      final electricity = service.calculateElectricity(buildings);
      expect(electricity.production, 250);
      expect(electricity.consumption, 65);
      expect(electricity.net, 250 - 65);
      expect(electricity.satisfactionRate, 100);
      expect(electricity.isDeficit, isFalse);

      // Deficit scenario: only Factory (consumption 40, production 0)
      final deficitPower = service.calculateElectricity([buildings[1]]);
      expect(deficitPower.production, 0);
      expect(deficitPower.consumption, 40);
      expect(deficitPower.satisfactionRate, 0);
      expect(deficitPower.isDeficit, isTrue);
    });

    test('calculateWater accurately computes production, consumption, and satisfaction', () {
      final buildings = [
        createTestBuilding(id: 'b1', typeId: BuildingRegistry.waterFacility.id, level: 1), // 250kL prod
        createTestBuilding(id: 'b2', typeId: BuildingRegistry.apartments.id, level: 1), // 15kL cons
        createTestBuilding(id: 'b3', typeId: BuildingRegistry.park.id, level: 1), // 10kL cons
      ];

      final water = service.calculateWater(buildings);
      expect(water.production, 250);
      expect(water.consumption, 25);
      expect(water.satisfactionRate, 100);
      expect(water.isDeficit, isFalse);
    });

    test('calculatePollution computes net output after green mitigation', () {
      final buildings = [
        createTestBuilding(id: 'b1', typeId: BuildingRegistry.factory.id, level: 1), // +25 pollution
        createTestBuilding(id: 'b2', typeId: BuildingRegistry.park.id, level: 1), // -20 reduction
      ];

      final pollution = service.calculatePollution(buildings);
      expect(pollution, 5); // 25 - 20 = 5

      // Over-mitigation clamps to 0
      final ecoBuildings = [
        createTestBuilding(id: 'b1', typeId: BuildingRegistry.park.id, level: 1), // -20
        createTestBuilding(id: 'b2', typeId: BuildingRegistry.garden.id, level: 1), // -10
      ];
      expect(service.calculatePollution(ecoBuildings), 0);
    });

    test('calculateHappiness factors in services, parks, utility deficits and pollution', () {
      final power = const UtilityBalance(production: 200, consumption: 50);
      final water = const UtilityBalance(production: 200, consumption: 50);

      // Ideal scenario: hospital + park with power & water and 0 pollution
      final buildings = [
        createTestBuilding(id: 'b1', typeId: BuildingRegistry.hospital.id, level: 1), // +12
        createTestBuilding(id: 'b2', typeId: BuildingRegistry.park.id, level: 1), // +10
      ];

      final happiness = service.calculateHappiness(
        buildings: buildings,
        electricity: power,
        water: water,
        pollution: 0,
      );

      // Base 75 + 12 (services) + 10 (environment) = 97
      expect(happiness, 97);

      // Penalty scenario: 0% power, 0% water, high pollution (60)
      final unpowered = const UtilityBalance(production: 0, consumption: 100);
      final unwatered = const UtilityBalance(production: 0, consumption: 100);

      final penaltyHappiness = service.calculateHappiness(
        buildings: buildings,
        electricity: unpowered,
        water: unwatered,
        pollution: 60,
      );

      // 70 + 12 + 10 - 30 (power deficit) - 30 (water deficit) - (45 * 0.35 = 15.75) ≈ 16
      expect(penaltyHappiness, lessThan(30));
    });

    test('calculateNextPopulation grows when happy and utilities satisfied', () {
      final power = const UtilityBalance(production: 100, consumption: 10);
      final water = const UtilityBalance(production: 100, consumption: 10);

      final nextPop = service.calculateNextPopulation(
        currentPopulation: 0,
        housingCapacity: 50,
        happiness: 80,
        electricity: power,
        water: water,
      );

      expect(nextPop, greaterThan(0));
      expect(nextPop, lessThanOrEqualTo(50));
    });

    test('calculateNextPopulation declines when unpowered or unhappy', () {
      final unpowered = const UtilityBalance(production: 0, consumption: 50);
      final water = const UtilityBalance(production: 100, consumption: 10);

      final nextPop = service.calculateNextPopulation(
        currentPopulation: 40,
        housingCapacity: 50,
        happiness: 30,
        electricity: unpowered,
        water: water,
      );

      expect(nextPop, lessThan(40));
    });

    test('deductConstructionCost deducts coins and records transaction', () {
      final initialLedger = ResourceLedger.initial('city-1', startingCoins: 1000);

      final result = service.deductConstructionCost(
        ledger: initialLedger,
        definition: BuildingRegistry.smallHouse, // cost = 150
      );

      expect(result.ledger.coins, 850);
      expect(result.transaction.amount, -150);
      expect(result.transaction.type, TransactionType.construction);
    });

    test('deductConstructionCost throws when insufficient coins', () {
      final brokeLedger = ResourceLedger.initial('city-1', startingCoins: 50);

      expect(
        () => service.deductConstructionCost(
          ledger: brokeLedger,
          definition: BuildingRegistry.smallHouse, // cost = 150
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('deductUpgradeCost deducts tiered upgrade cost and records transaction', () {
      final initialLedger = ResourceLedger.initial('city-1', startingCoins: 2000);
      final building = createTestBuilding(
        id: 'b1',
        typeId: BuildingRegistry.smallHouse.id,
        level: 1,
      );

      final result = service.deductUpgradeCost(
        ledger: initialLedger,
        building: building,
        definition: BuildingRegistry.smallHouse, // base upgrade cost = 100
      );

      expect(result.ledger.coins, 1900);
      expect(result.transaction.amount, -100);
      expect(result.transaction.type, TransactionType.upgrade);
    });

    test('deductUpgradeCost throws when insufficient coins for upgrade', () {
      final brokeLedger = ResourceLedger.initial('city-1', startingCoins: 50);
      final building = createTestBuilding(
        id: 'b1',
        typeId: BuildingRegistry.smallHouse.id,
        level: 1,
      );

      expect(
        () => service.deductUpgradeCost(
          ledger: brokeLedger,
          building: building,
          definition: BuildingRegistry.smallHouse,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('addDemolitionRefund refunds coins and records transaction', () {
      final initialLedger = ResourceLedger.initial('city-1', startingCoins: 500);
      final building = createTestBuilding(
        id: 'b1',
        typeId: BuildingRegistry.smallHouse.id,
        level: 1,
      );

      final result = service.addDemolitionRefund(
        ledger: initialLedger,
        building: building,
        definition: BuildingRegistry.smallHouse, // refund = 75
      );

      expect(result.ledger.coins, 575);
      expect(result.transaction.amount, 75);
      expect(result.transaction.type, TransactionType.demolitionRefund);
    });

    test('simulateTick deterministically advances economy and resources', () {
      final ledger = ResourceLedger.initial('city-1', startingCoins: 5000);
      final buildings = [
        createTestBuilding(id: 'b1', typeId: BuildingRegistry.smallHouse.id, level: 1),
        createTestBuilding(id: 'b2', typeId: BuildingRegistry.shop.id, level: 1),
        createTestBuilding(id: 'b3', typeId: BuildingRegistry.powerPlant.id, level: 1),
        createTestBuilding(id: 'b4', typeId: BuildingRegistry.waterFacility.id, level: 1),
      ];

      final tickResult = service.simulateTick(
        ledger: ledger,
        buildings: buildings,
        city: testCity,
      );

      expect(tickResult.ledger.coins, isNot(5000));
      expect(tickResult.snapshot.electricity.satisfactionRate, 100);
      expect(tickResult.snapshot.water.satisfactionRate, 100);
      expect(tickResult.transactions, isNotEmpty);
    });
  });
}
