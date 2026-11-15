import 'dart:math' as math;
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/city_demographics.dart';
import 'package:city_builder_2040/models/city_event.dart';
import 'package:city_builder_2040/models/city_resource.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/models/resource_transaction.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';
import 'package:city_builder_2040/services/economy_service.dart';

/// The result of executing one discrete simulation engine tick.
class SimulationTickResult {
  const SimulationTickResult({
    required this.clock,
    required this.demographics,
    required this.ledger,
    required this.snapshot,
    required this.activeEvents,
    required this.transactions,
    this.newEvent,
  });

  final SimulationClock clock;
  final CityDemographics demographics;
  final ResourceLedger ledger;
  final CityResourcesSnapshot snapshot;
  final List<CityEvent> activeEvents;
  final List<ResourceTransaction> transactions;
  final CityEvent? newEvent;
}

/// Centralized simulation engine governing in-game time, day/night cycles,
/// population dynamics, labor, healthcare, education, infrastructure,
/// building behaviors, and civic events.
class SimulationService {
  SimulationService({
    required EconomyService economy,
    required ResourceRepository resources,
    DateTime Function()? clock,
  }) : _economy = economy,
       _resources = resources,
       _clock = clock ?? DateTime.now;

  final EconomyService _economy;
  final ResourceRepository _resources;
  final DateTime Function() _clock;

  ResourceRepository get resources => _resources;

  /// Calculates total jobs provided across all active buildings.
  int calculateTotalJobs(List<Building> buildings) {
    var jobs = 0;
    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def != null) {
        jobs += def.effectiveJobsProvided(b.level);
      }
    }
    return jobs;
  }

  /// Calculates total healthcare capacity across hospital buildings.
  int calculateHealthcareCapacity(List<Building> buildings) {
    var capacity = 0;
    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def != null) {
        capacity += def.effectiveHealthcareCapacity(b.level);
      }
    }
    return capacity;
  }

  /// Calculates total education capacity across school buildings.
  int calculateEducationCapacity(List<Building> buildings) {
    var capacity = 0;
    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def != null) {
        capacity += def.effectiveEducationCapacity(b.level);
      }
    }
    return capacity;
  }

  /// Calculates total safety coverage capacity across police and fire stations.
  int calculateSafetyCapacity(List<Building> buildings) {
    var capacity = 0;
    for (final b in buildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def != null) {
        capacity += def.effectiveSafetyCapacity(b.level);
      }
    }
    return capacity;
  }

  /// Computes comprehensive demographics, labor allocation, and migration.
  CityDemographics simulateDemographics({
    required int currentPopulation,
    required List<Building> buildings,
    required int happiness,
    required UtilityBalance electricity,
    required UtilityBalance water,
    double growthMultiplier = 1.0,
  }) {
    final housingCapacity = _economy.calculateHousingCapacity(buildings);
    final totalJobs = calculateTotalJobs(buildings);
    final healthCap = calculateHealthcareCapacity(buildings);
    final eduCap = calculateEducationCapacity(buildings);
    final safetyCap = calculateSafetyCapacity(buildings);

    // Coverage indices (0 to 100%)
    final healthcareRating = currentPopulation <= 0
        ? 100
        : ((healthCap / currentPopulation) * 100).clamp(0, 100).round();
    final educationRating = currentPopulation <= 0
        ? 100
        : ((eduCap / currentPopulation) * 100).clamp(0, 100).round();
    final safetyRating = currentPopulation <= 0
        ? 100
        : ((safetyCap / currentPopulation) * 100).clamp(0, 100).round();

    // Employment
    final workingAge = (currentPopulation * 0.65).round();
    final employed = math.min(workingAge, totalJobs);

    // Zonal demands (-100 to 100)
    final spareHousing = housingCapacity - currentPopulation;
    final housingDemand = (spareHousing <= 5 ? 75 : 30) + (happiness > 70 ? 25 : -15);
    final commercialDemand = ((currentPopulation * 0.4) - totalJobs).clamp(-100, 100).round();
    final industrialDemand = ((workingAge - employed) * 2).clamp(-100, 100).round();

    // Migration calculations
    var migration = 0;
    final utilitiesSatisfied = electricity.satisfactionRate >= 80 && water.satisfactionRate >= 80;

    if (housingCapacity <= 0) {
      migration = -currentPopulation; // No housing means population cannot stay
    } else if (currentPopulation < housingCapacity) {
      if (happiness >= 50 && utilitiesSatisfied) {
        final baseGrowth = (spareHousing * 0.12 * (happiness / 100.0)).ceil().clamp(1, 15);
        final boostedGrowth = (baseGrowth * growthMultiplier).round();
        migration = math.min(spareHousing, boostedGrowth);
      }
    }

    // Emigration when severe deficit or unhappiness
    if (happiness < 40 || !utilitiesSatisfied) {
      final decline = (currentPopulation * 0.08).ceil().clamp(1, 12);
      migration = -decline;
    }

    final nextPopulation = math.max(0, math.min(housingCapacity, currentPopulation + migration));

    return CityDemographics(
      totalPopulation: nextPopulation,
      housingCapacity: housingCapacity,
      totalJobs: totalJobs,
      employedCount: employed,
      healthcareRating: healthcareRating,
      educationRating: educationRating,
      safetyRating: safetyRating,
      housingDemand: housingDemand.clamp(-100, 100),
      commercialDemand: commercialDemand.clamp(-100, 100),
      industrialDemand: industrialDemand.clamp(-100, 100),
      migrationRate: migration,
    );
  }

  /// Executes one discrete, deterministic simulation step.
  SimulationTickResult simulateTick({
    required ResourceLedger ledger,
    required SimulationClock clock,
    required CityDemographics demographics,
    required List<Building> buildings,
    required City city,
    required List<CityEvent> activeEvents,
  }) {
    final now = _clock().toUtc();
    final transactions = <ResourceTransaction>[];

    // 1. Advance in-game clock (1 tick = 1 in-game hour)
    final nextClock = clock.advance(minutesAdvanced: 60);

    // 2. Process active events: tick duration, filter out expired
    final updatedEvents = <CityEvent>[];
    var taxMultiplier = 1.0;
    var growthMultiplier = 1.0;
    var eventHappinessBonus = 0;
    var eventPollutionModifier = 0;

    for (final event in activeEvents) {
      final ticked = event.tick();
      if (!ticked.isExpired) {
        updatedEvents.add(ticked);
        if (ticked.type == CityEventType.taxIncomeBonus) {
          taxMultiplier *= ticked.multiplier;
        } else if (ticked.type == CityEventType.populationGrowthBonus) {
          growthMultiplier *= ticked.multiplier;
        }
        eventHappinessBonus += ticked.happinessModifier;
        eventPollutionModifier += ticked.pollutionModifier;
      }
    }

    // Check for random positive event trigger if no event is currently active
    CityEvent? newlyTriggeredEvent;
    if (updatedEvents.isEmpty && buildings.length >= 3 && demographics.totalPopulation >= 10) {
      // Deterministic trigger every 36 ticks or high happiness
      if (nextClock.tickCount % 36 == 0 || (demographics.totalPopulation >= 50 && nextClock.tickCount % 24 == 0)) {
        final template = CityEventPool.all[nextClock.tickCount % CityEventPool.all.length];
        newlyTriggeredEvent = template;
        updatedEvents.add(template);

        if (template.instantCoinReward > 0) {
          transactions.add(
            ResourceTransaction(
              id: 'tx_event_${nextClock.tickCount}',
              cityId: city.id,
              type: TransactionType.residentialTax,
              amount: template.instantCoinReward,
              description: '${template.title}: Grant Award (+¢${template.instantCoinReward})',
              timestamp: now,
            ),
          );
        }
      }
    }

    // 3. Infrastructure & Utilities
    final electricity = _economy.calculateElectricity(buildings);
    final water = _economy.calculateWater(buildings);
    final basePollution = _economy.calculatePollution(buildings);
    final pollution = math.max(0, basePollution + eventPollutionModifier).clamp(0, 100);

    // 4. Base happiness plus event bonuses and service coverage
    final baseHappiness = _economy.calculateHappiness(
      buildings: buildings,
      electricity: electricity,
      water: water,
      pollution: pollution,
    );

    // Service coverage happiness adjustment
    var serviceBonus = 0;
    if (demographics.healthcareRating >= 80) serviceBonus += 3;
    if (demographics.educationRating >= 80) serviceBonus += 3;
    if (demographics.safetyRating >= 80) serviceBonus += 2;
    if (demographics.employmentRate < 70 && demographics.totalPopulation > 20) {
      serviceBonus -= 5; // Unemployment penalty
    }

    final happiness = (baseHappiness + eventHappinessBonus + serviceBonus).clamp(0, 100);

    // 5. Population and labor migration simulation
    final nextDemographics = simulateDemographics(
      currentPopulation: ledger.population,
      buildings: buildings,
      happiness: happiness,
      electricity: electricity,
      water: water,
      growthMultiplier: growthMultiplier,
    );

    // 6. Financial Economy calculations with event multiplier
    final baseIncome = _economy.calculateIncome(buildings, nextDemographics.totalPopulation);
    final adjustedIncome = (baseIncome.total * taxMultiplier).round();
    final expenses = _economy.calculateExpenses(buildings);
    final netCashflow = adjustedIncome - expenses.total;

    // Apply instant rewards if any
    final instantReward = newlyTriggeredEvent?.instantCoinReward ?? 0;
    final nextCoins = math.max(0, ledger.coins + netCashflow + instantReward);

    // Record regular cashflow transaction
    if (adjustedIncome > 0) {
      transactions.add(
        ResourceTransaction(
          id: 'tx_inc_${nextClock.tickCount}',
          cityId: city.id,
          type: TransactionType.residentialTax,
          amount: adjustedIncome,
          description: 'City tax & commercial revenue (+¢$adjustedIncome)',
          timestamp: now,
        ),
      );
    }
    if (expenses.total > 0) {
      transactions.add(
        ResourceTransaction(
          id: 'tx_exp_${nextClock.tickCount}',
          cityId: city.id,
          type: TransactionType.maintenanceExpense,
          amount: -expenses.total,
          description: 'Municipal operating upkeep (-¢${expenses.total})',
          timestamp: now,
        ),
      );
    }

    // 7. Update ResourceLedger
    final updatedLedger = ledger.updateAmounts({
      ResourceLedger.coinsKey: nextCoins.toDouble(),
      ResourceLedger.populationKey: nextDemographics.totalPopulation.toDouble(),
      ResourceLedger.happinessKey: happiness.toDouble(),
      ResourceLedger.pollutionKey: pollution.toDouble(),
    }, updatedAt: now);

    final snapshot = _economy.createSnapshot(
      ledger: updatedLedger,
      buildings: buildings,
      city: city,
    );

    return SimulationTickResult(
      clock: nextClock,
      demographics: nextDemographics,
      ledger: updatedLedger,
      snapshot: snapshot,
      activeEvents: updatedEvents,
      transactions: transactions,
      newEvent: newlyTriggeredEvent,
    );
  }
}
