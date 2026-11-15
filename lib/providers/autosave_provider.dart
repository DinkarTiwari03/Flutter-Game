import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/economy_providers.dart';
import 'package:city_builder_2040/providers/progression_providers.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';

/// Saves a full game snapshot to the local database.
///
/// Called by [GameScreen] on app lifecycle events (paused/inactive), and
/// every 60 simulation ticks by the simulation loop. Skips silently when
/// a save is already in progress (built-in debounce in [AutosaveService]).
///
/// Returns `true` if the save completed, `false` if it was skipped.
Future<bool> triggerAutosave(Ref ref) async {
  final city = ref.read(activeCityProvider);
  if (city == null) return false;

  final buildings = ref.read(cityBuildingsProvider).value ?? [];
  final ledger = ref.read(cityLedgerProvider).value;
  if (ledger == null) return false;

  final missionProgress = ref.read(cityMissionProgressProvider).value ?? [];
  final playerProgress =
      ref.read(playerProgressProvider).value ??
      PlayerProgress(
        playerId: PlayerProgress.localPlayerId,
        updatedAt: DateTime.now().toUtc(),
      );

  final service = ref.read(autosaveServiceProvider);
  return service.saveSnapshot(
    city: city,
    buildingList: buildings,
    ledger: ledger,
    missionProgressList: missionProgress,
    progress: playerProgress,
  );
}

/// A simple value-less provider that widgets use to trigger a save.
/// Calling [AutosaveTriggerNotifier.save] from a [ConsumerStatefulWidget]
/// lifecycle (e.g. [WidgetsBindingObserver.didChangeAppLifecycleState]) is
/// the preferred integration point.
class AutosaveTriggerNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<bool> save() => triggerAutosave(ref);
}

final autosaveTriggerProvider =
    NotifierProvider<AutosaveTriggerNotifier, void>(AutosaveTriggerNotifier.new);
