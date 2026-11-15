import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';

void main() {
  group('BuildingRegistry', () {
    test('contains all 19 building definitions', () {
      expect(BuildingRegistry.all.length, 19);
    });

    test('retrieves buildings by category', () {
      final residential = BuildingRegistry.byCategory(BuildingCategory.residential);
      expect(residential.length, 3);
      expect(residential.map((b) => b.id), containsAll(['small_house', 'apartments', 'residential_tower']));

      final commercial = BuildingRegistry.byCategory(BuildingCategory.commercial);
      expect(commercial.length, 3);

      final industrial = BuildingRegistry.byCategory(BuildingCategory.industrial);
      expect(industrial.length, 2);

      final publicServices = BuildingRegistry.byCategory(BuildingCategory.publicServices);
      expect(publicServices.length, 4);

      final infrastructure = BuildingRegistry.byCategory(BuildingCategory.infrastructure);
      expect(infrastructure.length, 3);

      final environment = BuildingRegistry.byCategory(BuildingCategory.environment);
      expect(environment.length, 4);
    });

    test('get returns matching definition or null', () {
      expect(BuildingRegistry.get('small_house'), isNotNull);
      expect(BuildingRegistry.get('small_house')?.name, 'Small House');
      expect(BuildingRegistry.get('non_existent'), isNull);
    });
  });

  group('BuildingDefinition calculations', () {
    test('footprintTiles returns correct number of grid points', () {
      const house = BuildingRegistry.smallHouse;
      final houseTiles = house.footprintTiles(const GridPoint(5, 5));
      expect(houseTiles, [const GridPoint(5, 5)]);

      const apartments = BuildingRegistry.apartments;
      final aptTiles = apartments.footprintTiles(const GridPoint(10, 10));
      expect(aptTiles.length, 4);
      expect(aptTiles, [
        const GridPoint(10, 10),
        const GridPoint(11, 10),
        const GridPoint(10, 11),
        const GridPoint(11, 11),
      ]);

      const factory = BuildingRegistry.industrialFacility;
      final factoryTiles = factory.footprintTiles(const GridPoint(2, 2));
      expect(factoryTiles.length, 9);
    });

    test('upgradeCost scales and returns null at maxLevel', () {
      const house = BuildingRegistry.smallHouse; // cost: 150, baseUpgradeCost: 100, maxLevel: 3
      expect(house.upgradeCost(1), 100);
      expect(house.upgradeCost(2), 175);
      expect(house.upgradeCost(3), isNull);

      const road = BuildingRegistry.road; // maxLevel: 1
      expect(road.upgradeCost(1), isNull);
    });

    test('demolitionRefund calculates 50% of total invested cost', () {
      const house = BuildingRegistry.smallHouse; // cost: 150, upgrade1->2: 100
      // level 1: 50% of 150 = 75
      expect(house.demolitionRefund(1), 75);

      // level 2: 50% of (150 + 100) = 125
      expect(house.demolitionRefund(2), 125);
    });

    test('resource behavior scales with upgrade tiers', () {
      const apt = BuildingRegistry.apartments; // base housing = 60, powerCons = 15
      expect(apt.effectiveHousingCapacity(1), 60);
      expect(apt.effectiveHousingCapacity(2), 90); // 60 * 1.5

      expect(apt.effectiveElectricityConsumption(1), 15);
      expect(apt.effectiveElectricityConsumption(2), 20); // 15 * 1.3 = 19.5 -> 20

      const power = BuildingRegistry.powerPlant; // base prod = 250
      expect(power.effectiveElectricityProduction(1), 250);
      expect(power.effectiveElectricityProduction(2), 375); // 250 * 1.5

      const factory = BuildingRegistry.factory; // base pollution = 25
      expect(factory.effectivePollutionOutput(1), 25);
      expect(factory.effectivePollutionOutput(2), 31); // 25 * 1.25 = 31.25 -> 31

      const park = BuildingRegistry.park; // base reduction = 20, happiness = 10
      expect(park.effectivePollutionReduction(1), 20);
      expect(park.effectiveHappinessBonus(1), 10);
    });
  });
}
