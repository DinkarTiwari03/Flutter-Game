import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/game/disaster/disaster_engine.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/disaster/disaster_models.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/economy_providers.dart';
import 'package:city_builder_2040/providers/simulation_providers.dart';

/// Reactive ticker notifier that increments on every DisasterEngine state change.
class DisasterStateNotifier extends Notifier<int> {
  late final DisasterEngine engine;

  @override
  int build() {
    engine = DisasterEngine();
    void listener() => state++;
    engine.addListener(listener);
    ref.onDispose(() {
      engine.removeListener(listener);
      engine.dispose();
    });
    return 0;
  }
}

final disasterStateNotifierProvider =
    NotifierProvider<DisasterStateNotifier, int>(DisasterStateNotifier.new);

/// Central singleton provider for the Disaster Simulation Engine.
final disasterEngineProvider = Provider<DisasterEngine>((ref) {
  return ref.watch(disasterStateNotifierProvider.notifier).engine;
});

/// Exposes the current active disaster, if any.
final activeDisasterProvider = Provider<ActiveDisaster?>((ref) {
  ref.watch(disasterStateNotifierProvider);
  final engine = ref.watch(disasterEngineProvider);
  return engine.activeDisaster;
});

/// Exposes active (undismissed) notifications.
final disasterNotificationsProvider =
    Provider<List<DisasterNotification>>((ref) {
  ref.watch(disasterStateNotifierProvider);
  final engine = ref.watch(disasterEngineProvider);
  return engine.notifications;
});

/// Exposes past disaster reports (most recent first).
final disasterHistoryProvider = Provider<List<DisasterReport>>((ref) {
  ref.watch(disasterStateNotifierProvider);
  final engine = ref.watch(disasterEngineProvider);
  return engine.history;
});

/// Set of road grid coordinates currently blocked by active disasters.
final disasterBlockedRoadsProvider = Provider<Set<GridPoint>>((ref) {
  ref.watch(disasterStateNotifierProvider);
  final engine = ref.watch(disasterEngineProvider);
  return engine.blockedRoads;
});

/// Real-time assessed risk levels for each disaster type.
final disasterRisksProvider = Provider<Map<DisasterType, double>>((ref) {
  ref.watch(disasterStateNotifierProvider);
  final engine = ref.watch(disasterEngineProvider);
  final buildings = ref.watch(cityBuildingsProvider).value ?? const [];
  final clock = ref.watch(simulationClockProvider);
  final snapshot = ref.watch(cityEconomySnapshotProvider);
  final ledger = ref.watch(cityLedgerProvider).value;

  final population = ledger?.population ?? 0;
  final pollution = snapshot?.pollution ?? 0;
  final happiness = ledger?.happiness ?? 50;

  return engine.assessRisk(
    buildings: buildings,
    population: population,
    pollution: pollution,
    happiness: happiness,
    clock: clock,
  );
});
