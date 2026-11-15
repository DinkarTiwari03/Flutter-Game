import 'dart:math' as math;
import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/core/utils/id_generator.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/city_resource.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/models/resource_transaction.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';

/// Centralized service for city resource modeling, income/expense calculations,
/// financial transactions, and deterministic simulation ticks.
class EconomyService {
  EconomyService({
    required ResourceRepository resources,
    IdGenerator? idGenerator,
    DateTime Function()? clock,
  }) : _resources = resources,
       _ids = idGenerator ?? IdGenerator(),
       _clock = clock ?? DateTime.now;

  final ResourceRepository _resources;
  final IdGenerator _ids;
  final DateTime Function() _clock;

  /// Retrieves the ledger for [cityId], or initializes a new one if none exists.
  Future<ResourceLedger> getOrInitLedger(String cityId) async {
    final existing = await _resources.getLedger(cityId);
    if (existing != null) return existing;

    final initial = ResourceLedger.initial(cityId, now: _clock().toUtc());
    await _resources.saveLedger(initial);
    return initial;
  }

  /// Calculates total housing capacity across all placed residential buildings.
  int calculateHousingCapacity(List<Building> buildings) {
    var capacity = 0;
    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def != null && def.category == BuildingCategory.residential) {
        capacity += def.effectiveHousingCapacity(b.level);
      }
    }
    return capacity;
  }

  /// Calculates detailed income breakdown for the current city state.
  IncomeBreakdown calculateIncome(List<Building> buildings, int currentPopulation) {
    var residentialTaxes = 0;
    var commercialIncome = 0;
    var industrialIncome = 0;

    final totalCapacity = calculateHousingCapacity(buildings);
    final housedCitizens = math.min(currentPopulation, totalCapacity);

    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;

      switch (def.category) {
        case BuildingCategory.residential:
          if (totalCapacity > 0) {
            // Allocate citizens proportionally to each residential building's share
            final bCapacity = def.effectiveHousingCapacity(b.level);
            final buildingCitizens =
                (housedCitizens * (bCapacity / totalCapacity)).round();
            residentialTaxes +=
                def.effectiveResidentialTax(b.level, buildingCitizens);
          }
        case BuildingCategory.commercial:
          commercialIncome += def.effectiveCommercialIncome(b.level);
        case BuildingCategory.industrial:
          industrialIncome += def.effectiveIndustrialIncome(b.level);
        case BuildingCategory.publicServices:
        case BuildingCategory.infrastructure:
        case BuildingCategory.environment:
          break;
      }
    }

    return IncomeBreakdown(
      residentialTaxes: residentialTaxes,
      commercialIncome: commercialIncome,
      industrialIncome: industrialIncome,
    );
  }

  /// Calculates detailed operating expenses for all buildings and infrastructure.
  ExpenseBreakdown calculateExpenses(List<Building> buildings) {
    var buildingMaintenance = 0;
    var roadMaintenance = 0;
    var electricityProductionCost = 0;
    var waterProductionCost = 0;

    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;

      final maintenance = def.effectiveMaintenance(b.level);
      if (def.isRoad) {
        roadMaintenance += maintenance;
      } else {
        buildingMaintenance += maintenance;
      }

      // Utility production upkeep
      if (def.resources.electricityProduction > 0) {
        electricityProductionCost += (def.effectiveElectricityProduction(b.level) * 0.1).round();
      }
      if (def.resources.waterProduction > 0) {
        waterProductionCost += (def.effectiveWaterProduction(b.level) * 0.1).round();
      }
    }

    return ExpenseBreakdown(
      buildingMaintenance: buildingMaintenance,
      roadMaintenance: roadMaintenance,
      electricityProductionCost: electricityProductionCost,
      waterProductionCost: waterProductionCost,
    );
  }

  /// Computes electricity production, consumption, and satisfaction rate.
  UtilityBalance calculateElectricity(List<Building> buildings) {
    var production = 0;
    var consumption = 0;

    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;

      production += def.effectiveElectricityProduction(b.level);
      consumption += def.effectiveElectricityConsumption(b.level);
    }

    return UtilityBalance(production: production, consumption: consumption);
  }

  /// Computes water production, consumption, and satisfaction rate.
  UtilityBalance calculateWater(List<Building> buildings) {
    var production = 0;
    var consumption = 0;

    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;

      production += def.effectiveWaterProduction(b.level);
      consumption += def.effectiveWaterConsumption(b.level);
    }

    return UtilityBalance(production: production, consumption: consumption);
  }

  /// Computes environmental pollution rating (0 to 100).
  int calculatePollution(List<Building> buildings) {
    var output = 0;
    var reduction = 0;

    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;

      output += def.effectivePollutionOutput(b.level);
      reduction += def.effectivePollutionReduction(b.level);
    }

    final netPollution = math.max(0, output - reduction);
    // Clamp to 0-100 range
    return netPollution.clamp(0, 100);
  }

  /// Calculates citizen happiness rating (0 to 100) based on services, utilities, and environment.
  int calculateHappiness({
    required List<Building> buildings,
    required UtilityBalance electricity,
    required UtilityBalance water,
    required int pollution,
  }) {
    // Base happiness
    var score = GameConstants.startingHappiness.toDouble();

    // Positive factors from buildings
    var servicesBonus = 0;
    var environmentBonus = 0;

    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;

      final bonus = def.effectiveHappinessBonus(b.level);
      if (def.category == BuildingCategory.publicServices) {
        servicesBonus += bonus;
      } else if (def.category == BuildingCategory.environment) {
        environmentBonus += bonus;
      }
    }

    // Cap positive service bonuses
    score += math.min(20, servicesBonus);
    score += math.min(15, environmentBonus);

    // Negative penalties
    // Electricity deficit: up to -30%
    if (electricity.satisfactionRate < 100) {
      score -= (100 - electricity.satisfactionRate) * 0.3;
    }

    // Water deficit: up to -30%
    if (water.satisfactionRate < 100) {
      score -= (100 - water.satisfactionRate) * 0.3;
    }

    // Pollution penalty: up to -25%
    if (pollution > 15) {
      score -= (pollution - 15) * 0.35;
    }

    return score.round().clamp(0, 100);
  }

  /// Computes deterministic population change for a simulation tick.
  int calculateNextPopulation({
    required int currentPopulation,
    required int housingCapacity,
    required int happiness,
    required UtilityBalance electricity,
    required UtilityBalance water,
  }) {
    if (housingCapacity <= 0) return 0;

    final utilitiesSatisfied =
        electricity.satisfactionRate >= 80 && water.satisfactionRate >= 80;

    if (currentPopulation < housingCapacity) {
      if (happiness >= 50 && utilitiesSatisfied) {
        // Growth proportional to available capacity and happiness
        final spareCapacity = housingCapacity - currentPopulation;
        final growthFactor = (happiness / 100.0) * 0.15;
        final growth = (spareCapacity * growthFactor).ceil().clamp(1, 15);
        return math.min(housingCapacity, currentPopulation + growth);
      }
    }

    // If city is severely unsatisfied, residents emigrate
    if (happiness < 40 || !utilitiesSatisfied) {
      final decline = (currentPopulation * 0.08).ceil().clamp(1, 10);
      return math.max(0, currentPopulation - decline);
    }

    return currentPopulation;
  }

  /// Computes city development level based on population and infrastructure.
  int calculateCityLevel(int population, int buildingCount) {
    if (population >= 800 && buildingCount >= 30) return 5;
    if (population >= 400 && buildingCount >= 20) return 4;
    if (population >= 150 && buildingCount >= 10) return 3;
    if (population >= 40 && buildingCount >= 4) return 2;
    return 1;
  }

  /// Builds a complete snapshot of all resources and economic stats.
  CityResourcesSnapshot createSnapshot({
    required ResourceLedger ledger,
    required List<Building> buildings,
    required City city,
  }) {
    final population = ledger.population;
    final housingCapacity = calculateHousingCapacity(buildings);
    final income = calculateIncome(buildings, population);
    final expenses = calculateExpenses(buildings);
    final electricity = calculateElectricity(buildings);
    final water = calculateWater(buildings);
    final pollution = calculatePollution(buildings);
    final happiness = calculateHappiness(
      buildings: buildings,
      electricity: electricity,
      water: water,
      pollution: pollution,
    );
    final level = calculateCityLevel(population, buildings.length);

    final warnings = ResourceWarnings(
      lowCoins: ledger.coins < 500,
      electricityDeficit: electricity.isDeficit,
      waterDeficit: water.isDeficit,
      lowHappiness: happiness < 50,
      highPollution: pollution >= 50,
      noHousing: housingCapacity == 0 && buildings.isNotEmpty,
    );

    return CityResourcesSnapshot(
      coins: ledger.coins,
      population: population,
      housingCapacity: housingCapacity,
      electricity: electricity,
      water: water,
      happiness: happiness,
      pollution: pollution,
      cashflow: CashflowSummary(income: income, expenses: expenses),
      warnings: warnings,
      level: level,
      timestamp: ledger.updatedAt,
    );
  }

  /// Checks whether [coins] is sufficient to cover [cost].
  bool canAfford(int coins, int cost) => coins >= cost;

  /// Deducts construction cost from [ledger], returning the updated ledger and transaction.
  /// Throws [ValidationException] if coins are insufficient.
  ({ResourceLedger ledger, ResourceTransaction transaction})
      deductConstructionCost({
    required ResourceLedger ledger,
    required BuildingDefinition definition,
  }) {
    if (!canAfford(ledger.coins, definition.cost)) {
      throw ValidationException(
        'Insufficient coins to build ${definition.name}. '
        'Requires ¢${definition.cost}, but you have ¢${ledger.coins}.',
      );
    }

    final newCoins = ledger.coins - definition.cost;
    final now = _clock().toUtc();
    final updated = ledger.updateAmounts({
      ResourceLedger.coinsKey: newCoins.toDouble(),
    }, updatedAt: now);

    final transaction = ResourceTransaction(
      id: _ids.next(),
      cityId: ledger.cityId,
      type: TransactionType.construction,
      amount: -definition.cost,
      description: 'Built ${definition.name}',
      timestamp: now,
      buildingTypeId: definition.id,
    );

    return (ledger: updated, transaction: transaction);
  }

  /// Deducts upgrade cost from [ledger], returning the updated ledger and transaction.
  /// Throws [ValidationException] if coins are insufficient.
  ({ResourceLedger ledger, ResourceTransaction transaction})
      deductUpgradeCost({
    required ResourceLedger ledger,
    required Building building,
    required BuildingDefinition definition,
  }) {
    final cost = definition.upgradeCost(building.level);
    if (cost == null) {
      throw const ValidationException('Building is already at maximum level.');
    }

    if (!canAfford(ledger.coins, cost)) {
      throw ValidationException(
        'Insufficient coins to upgrade ${definition.name}. '
        'Requires ¢$cost, but you have ¢${ledger.coins}.',
      );
    }

    final newCoins = ledger.coins - cost;
    final now = _clock().toUtc();
    final updated = ledger.updateAmounts({
      ResourceLedger.coinsKey: newCoins.toDouble(),
    }, updatedAt: now);

    final transaction = ResourceTransaction(
      id: _ids.next(),
      cityId: ledger.cityId,
      type: TransactionType.upgrade,
      amount: -cost,
      description: 'Upgraded ${definition.name} to Lv. ${building.level + 1}',
      timestamp: now,
      buildingId: building.id,
      buildingTypeId: definition.id,
    );

    return (ledger: updated, transaction: transaction);
  }

  /// Adds demolition refund to [ledger], returning the updated ledger and transaction.
  ({ResourceLedger ledger, ResourceTransaction transaction})
      addDemolitionRefund({
    required ResourceLedger ledger,
    required Building building,
    required BuildingDefinition definition,
  }) {
    final refund = definition.demolitionRefund(building.level);
    final newCoins = ledger.coins + refund;
    final now = _clock().toUtc();
    final updated = ledger.updateAmounts({
      ResourceLedger.coinsKey: newCoins.toDouble(),
    }, updatedAt: now);

    final transaction = ResourceTransaction(
      id: _ids.next(),
      cityId: ledger.cityId,
      type: TransactionType.demolitionRefund,
      amount: refund,
      description: 'Demolished ${definition.name} (Lv. ${building.level})',
      timestamp: now,
      buildingId: building.id,
      buildingTypeId: definition.id,
    );

    return (ledger: updated, transaction: transaction);
  }

  /// Executes one deterministic simulation tick for the city.
  /// Returns the updated [ResourceLedger], the resulting [CityResourcesSnapshot],
  /// and any generated [ResourceTransaction]s.
  ({
    ResourceLedger ledger,
    CityResourcesSnapshot snapshot,
    List<ResourceTransaction> transactions,
  }) simulateTick({
    required ResourceLedger ledger,
    required List<Building> buildings,
    required City city,
  }) {
    final now = _clock().toUtc();
    final transactions = <ResourceTransaction>[];

    // Current state calculations
    final housingCapacity = calculateHousingCapacity(buildings);
    final electricity = calculateElectricity(buildings);
    final water = calculateWater(buildings);
    final pollution = calculatePollution(buildings);
    final happiness = calculateHappiness(
      buildings: buildings,
      electricity: electricity,
      water: water,
      pollution: pollution,
    );

    // Population update
    final nextPopulation = calculateNextPopulation(
      currentPopulation: ledger.population,
      housingCapacity: housingCapacity,
      happiness: happiness,
      electricity: electricity,
      water: water,
    );

    // Financial cashflow
    final income = calculateIncome(buildings, nextPopulation);
    final expenses = calculateExpenses(buildings);
    final netCashflow = income.total - expenses.total;

    // Prevent coins from dropping below 0
    final nextCoins = math.max(0, ledger.coins + netCashflow);

    // Record cashflow transactions if significant
    if (income.total > 0) {
      transactions.add(
        ResourceTransaction(
          id: _ids.next(),
          cityId: city.id,
          type: TransactionType.residentialTax,
          amount: income.total,
          description: 'City revenue collected (+¢${income.total})',
          timestamp: now,
        ),
      );
    }
    if (expenses.total > 0) {
      transactions.add(
        ResourceTransaction(
          id: _ids.next(),
          cityId: city.id,
          type: TransactionType.maintenanceExpense,
          amount: -expenses.total,
          description: 'Maintenance upkeep paid (-¢${expenses.total})',
          timestamp: now,
        ),
      );
    }

    final updatedLedger = ledger.updateAmounts({
      ResourceLedger.coinsKey: nextCoins.toDouble(),
      ResourceLedger.populationKey: nextPopulation.toDouble(),
      ResourceLedger.happinessKey: happiness.toDouble(),
      ResourceLedger.pollutionKey: pollution.toDouble(),
    }, updatedAt: now);

    final snapshot = createSnapshot(
      ledger: updatedLedger,
      buildings: buildings,
      city: city,
    );

    return (
      ledger: updatedLedger,
      snapshot: snapshot,
      transactions: transactions,
    );
  }
}
