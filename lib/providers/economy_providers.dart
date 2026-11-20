import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/models/city_resource.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/models/resource_transaction.dart';
import 'package:city_builder_2040/models/simulation_speed.dart';
import 'package:city_builder_2040/models/disaster/disaster_models.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/autosave_provider.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/disaster_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';
import 'package:city_builder_2040/providers/simulation_providers.dart';
import 'package:city_builder_2040/providers/urban_providers.dart';
import 'package:city_builder_2040/services/simulation_service.dart';

/// Manages the [ResourceLedger] for the active city.
class CityLedgerNotifier extends AsyncNotifier<ResourceLedger?> {
  @override
  Future<ResourceLedger?> build() async {
    final city = ref.watch(activeCityProvider);
    if (city == null) return null;
    final economy = ref.watch(economyServiceProvider);
    return economy.getOrInitLedger(city.id);
  }

  /// Reloads the ledger from the repository (e.g. after building construction or demolition).
  Future<void> reload() async {
    final city = ref.read(activeCityProvider);
    if (city == null) return;
    final economy = ref.read(economyServiceProvider);
    final fresh = await economy.getOrInitLedger(city.id);
    state = AsyncData(fresh);
  }

  /// Manually triggers a single simulation tick.
  Future<CityResourcesSnapshot?> simulateTick() async {
    final city = ref.read(activeCityProvider);
    final currentLedger = state.value;
    if (city == null || currentLedger == null) return null;

    final buildings = ref.read(cityBuildingsProvider).value ?? [];
    final simulation = ref.read(simulationServiceProvider);
    final resourcesRepo = ref.read(resourceRepositoryProvider);
    final clock = ref.read(simulationClockProvider);
    final demographics = ref.read(cityDemographicsProvider);
    final activeEvents = ref.read(activeCityEventsProvider);
    final trafficMetrics = ref.read(urbanSimulationProvider).trafficMetrics;
    final disasterEngine = ref.read(disasterEngineProvider);
    final urbanSim = ref.read(urbanSimulationProvider);

    // Drive disaster simulation engine
    final currentPollution = ref.read(cityEconomySnapshotProvider)?.pollution ?? 0;
    disasterEngine.update(
      1.0,
      buildings: buildings,
      roadTiles: urbanSim.roadGraph.roadTiles,
      population: currentLedger.population,
      pollution: currentPollution,
      happiness: currentLedger.happiness,
      healthcareRating: demographics.healthcareRating,
      clock: clock,
    );

    // Sync disaster-blocked roads to urban simulation & road graph
    urbanSim.updateDisasterBlockedRoads(disasterEngine.blockedRoads);

    // Compute disaster impact for this tick
    DisasterEffects? disasterEffects;
    final activeDisaster = disasterEngine.activeDisaster;
    if (activeDisaster != null &&
        (activeDisaster.isOccurring ||
            activeDisaster.isInResponse ||
            activeDisaster.isInRecovery)) {
      final rep = activeDisaster.report;
      disasterEffects = DisasterEffects(
        happinessPenalty: ((rep?.happinessLost ?? 8) / 3).round(),
        pollutionAdd: activeDisaster.type == DisasterType.fire ? 8 : (activeDisaster.type == DisasterType.heatwave ? 6 : 0),
        coinsLostThisTick: (rep != null && rep.recoveryDurationTicks > 0)
            ? (rep.coinsLost / rep.recoveryDurationTicks).round()
            : 0,
      );
    }

    final result = simulation.simulateTick(
      ledger: currentLedger,
      clock: clock,
      demographics: demographics,
      buildings: buildings,
      city: city,
      activeEvents: activeEvents,
      trafficMetrics: trafficMetrics,
      disasterEffects: disasterEffects,
    );

    // Save updated ledger
    await resourcesRepo.saveLedger(result.ledger);
    state = AsyncData(result.ledger);

    // Update simulation state
    ref.read(simulationClockProvider.notifier).update(result.clock);
    ref.read(cityDemographicsProvider.notifier).update(result.demographics);
    ref.read(activeCityEventsProvider.notifier).update(result.activeEvents);

    if (result.newEvent != null) {
      ref.read(lastTriggeredEventProvider.notifier).trigger(result.newEvent!);
    }

    // Record transactions
    if (result.transactions.isNotEmpty) {
      ref
          .read(transactionHistoryProvider.notifier)
          .recordAll(result.transactions);
    }

    return result.snapshot;
  }
}

final cityLedgerProvider =
    AsyncNotifierProvider<CityLedgerNotifier, ResourceLedger?>(
      CityLedgerNotifier.new,
    );

/// Sliding window of recent transactions (max 50).
class TransactionHistoryNotifier extends Notifier<List<ResourceTransaction>> {
  @override
  List<ResourceTransaction> build() => const [];

  void record(ResourceTransaction transaction) {
    state = [transaction, ...state.take(49)];
  }

  void recordAll(List<ResourceTransaction> transactions) {
    state = [...transactions.reversed, ...state].take(50).toList();
  }

  void clear() => state = const [];
}

final transactionHistoryProvider =
    NotifierProvider<TransactionHistoryNotifier, List<ResourceTransaction>>(
      TransactionHistoryNotifier.new,
    );

/// Complete derived snapshot of current city resources and economy.
final cityEconomySnapshotProvider = Provider<CityResourcesSnapshot?>((ref) {
  final city = ref.watch(activeCityProvider);
  final ledger = ref.watch(cityLedgerProvider).value;
  if (city == null || ledger == null) return null;

  final buildings = ref.watch(cityBuildingsProvider).value ?? const [];
  final economy = ref.watch(economyServiceProvider);

  return economy.createSnapshot(
    ledger: ledger,
    buildings: buildings,
    city: city,
  );
});

/// Simulation ticker that drives game ticks based on [simulationSpeedProvider].
class SimulationTickerNotifier extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    ref.listen<SimulationSpeed>(simulationSpeedProvider, (prev, next) {
      _restartTimer(next);
    });

    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });

    // Start with current speed
    final speed = ref.read(simulationSpeedProvider);
    _restartTimer(speed);

    return 0;
  }

  void _restartTimer(SimulationSpeed speed) {
    _timer?.cancel();
    _timer = null;

    if (speed.isPaused) return;

    // In unit / widget tests, background wall-clock timers are avoided to guarantee
    // determinism and prevent unhandled pending timer assertions.
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTestEnvironment) return;

    final duration = switch (speed) {
      SimulationSpeed.paused => Duration.zero,
      SimulationSpeed.normal => const Duration(milliseconds: 3000),
      SimulationSpeed.fast => const Duration(milliseconds: 1500),
      SimulationSpeed.superFast => const Duration(milliseconds: 750),
    };

    if (duration == Duration.zero) return;

    _timer = Timer.periodic(duration, (_) => tick());
  }

  /// Manually triggers a tick increment and simulation execution.
  Future<void> tick() async {
    state = state + 1;
    await ref.read(cityLedgerProvider.notifier).simulateTick();

    // Autosave periodically every 60 ticks
    if (state % 60 == 0) {
      await ref.read(autosaveTriggerProvider.notifier).save();
    }
  }
}

final simulationTickerProvider =
    NotifierProvider<SimulationTickerNotifier, int>(
      SimulationTickerNotifier.new,
    );
