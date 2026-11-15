import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/game/missions/mission_definition.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/models/progression_event.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/economy_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';
import 'package:city_builder_2040/providers/simulation_providers.dart';
import 'package:city_builder_2040/services/progression_service.dart';

// ─── Service ────────────────────────────────────────────────────────────────

final progressionServiceProvider = Provider<ProgressionService>(
  (ref) => const ProgressionService(),
);

// ─── Player Progress ─────────────────────────────────────────────────────────

class PlayerProgressNotifier extends AsyncNotifier<PlayerProgress> {
  @override
  Future<PlayerProgress> build() async {
    final repo = ref.watch(playerProgressRepositoryProvider);
    final existing = await repo.getProgress(PlayerProgress.localPlayerId);
    return existing ??
        PlayerProgress(
          playerId: PlayerProgress.localPlayerId,
          updatedAt: DateTime.now().toUtc(),
        );
  }

  Future<void> _save(PlayerProgress progress) async {
    state = AsyncData(progress);
    final repo = ref.read(playerProgressRepositoryProvider);
    await repo.saveProgress(progress);
  }

  /// Claims the reward for a completed mission. Returns events fired.
  Future<List<ProgressionEvent>> claimMissionReward(
    MissionDefinition mission,
  ) async {
    final player = state.value;
    if (player == null) return [];

    final service = ref.read(progressionServiceProvider);
    final result = service.awardMissionReward(player, mission);
    if (result == null) return []; // already claimed

    await _save(result.player);

    // Award coins via economy if any
    if (mission.reward.coins > 0) {
      final city = ref.read(activeCityProvider);
      if (city != null) {
        final economy = ref.read(economyServiceProvider);
        final repo = ref.read(resourceRepositoryProvider);
        final ledger = await economy.getOrInitLedger(city.id);
        final updated = ledger.updateAmounts({
          ResourceLedger.coinsKey:
              (ledger.coins + mission.reward.coins).toDouble(),
        });
        await repo.saveLedger(updated);
        ref.read(cityLedgerProvider.notifier).reload();
      }
    }

    // Check for new achievements
    await _checkAchievements(result.player);

    return result.events;
  }

  Future<void> _checkAchievements(PlayerProgress player) async {
    final buildings = ref.read(cityBuildingsProvider).value ?? [];
    final cityStats = ref.read(cityStatsProvider);
    final demographics = ref.read(cityDemographicsProvider);
    final ledger = ref.read(cityLedgerProvider).value;
    final service = ref.read(progressionServiceProvider);

    final newAchs = service.evaluateNewAchievements(
      buildings,
      cityStats,
      demographics,
      ledger,
      player,
    );

    if (newAchs.isEmpty) return;

    final achResult = service.awardAchievements(player, newAchs);
    await _save(achResult.player);

    // Fire achievement events to notification queue
    for (final event in achResult.events) {
      ref.read(pendingProgressionEventsProvider.notifier).add(event);
    }
  }

  /// Manually triggers achievement evaluation (call after simulation ticks).
  Future<void> evaluateAchievements() async {
    final player = state.value;
    if (player == null) return;
    await _checkAchievements(player);
  }
}

final playerProgressProvider =
    AsyncNotifierProvider<PlayerProgressNotifier, PlayerProgress>(
  PlayerProgressNotifier.new,
);

// ─── Mission Progress ────────────────────────────────────────────────────────

class CityMissionProgressNotifier extends AsyncNotifier<List<MissionProgress>> {
  @override
  Future<List<MissionProgress>> build() async {
    final city = ref.watch(activeCityProvider);
    if (city == null) return [];
    final repo = ref.watch(missionRepositoryProvider);
    return repo.getProgress(city.id);
  }

  Future<void> _save(MissionProgress progress) async {
    final repo = ref.read(missionRepositoryProvider);
    await repo.saveProgress(progress);
    final city = ref.read(activeCityProvider);
    if (city == null) return;
    final all = await repo.getProgress(city.id);
    state = AsyncData(all);
  }

  /// Evaluates and updates progress for all available missions and challenges.
  Future<void> evaluateAll() async {
    final city = ref.read(activeCityProvider);
    if (city == null) return;

    final service = ref.read(progressionServiceProvider);
    final buildings = ref.read(cityBuildingsProvider).value ?? [];
    final cityStats = ref.read(cityStatsProvider);
    final demographics = ref.read(cityDemographicsProvider);
    final ledger = ref.read(cityLedgerProvider).value;
    final playerProgress = ref.read(playerProgressProvider).value;
    final currentProgress = state.value ?? [];

    final allMissions = [
      ...MissionRegistry.missions,
      ...MissionRegistry.challenges,
    ];

    for (final mission in allMissions) {
      final existing = currentProgress.firstWhere(
        (p) => p.missionId == mission.id,
        orElse: () => MissionProgress(
          cityId: city.id,
          missionId: mission.id,
          updatedAt: DateTime.now().toUtc(),
          status: MissionStatus.locked,
        ),
      );

      // Skip already-completed missions
      if (existing.status == MissionStatus.completed) continue;

      // Check prerequisites
      final completedIds = currentProgress
          .where((p) => p.status == MissionStatus.completed)
          .map((p) => p.missionId)
          .toSet();
      final prereqsMet = mission.prerequisiteMissionIds
          .every((id) => completedIds.contains(id));

      final newStatus = prereqsMet ? MissionStatus.active : MissionStatus.locked;
      final newProgress = service.evaluateMissionProgress(
        mission,
        buildings,
        cityStats,
        demographics,
        ledger,
      );

      final isNowComplete = newProgress >= 1.0;
      final updated = existing.copyWith(
        status: isNowComplete ? MissionStatus.completed : newStatus,
        progress: newProgress,
        updatedAt: DateTime.now().toUtc(),
        completedAt: isNowComplete && existing.completedAt == null
            ? DateTime.now().toUtc()
            : existing.completedAt,
      );

      if (updated.status != existing.status ||
          (updated.progress - existing.progress).abs() > 0.001) {
        await _save(updated);
        if (isNowComplete && existing.status != MissionStatus.completed) {
          ref.read(pendingProgressionEventsProvider.notifier).add(
                MissionCompletedEvent(
                  missionId: mission.id,
                  title: mission.title,
                ),
              );
        }
      }
    }

    // Also check achievements after updating missions
    final player = playerProgress;
    if (player != null) {
      await ref.read(playerProgressProvider.notifier).evaluateAchievements();
    }
  }

  Future<List<ProgressionEvent>> claimReward(String missionId) async {
    final def = MissionRegistry.findById(missionId);
    if (def == null) return [];

    final currentProgress = state.value ?? [];
    final progress = currentProgress.firstWhere(
      (p) => p.missionId == missionId,
      orElse: () => MissionProgress(
        cityId: '',
        missionId: missionId,
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    if (progress.status != MissionStatus.completed) return [];
    if (progress.rewardClaimed) return [];

    // Mark reward as claimed in mission progress
    final updated = progress.copyWith(
      rewardClaimed: true,
      updatedAt: DateTime.now().toUtc(),
    );
    await _save(updated);

    // Award via player progress
    return ref.read(playerProgressProvider.notifier).claimMissionReward(def);
  }
}

final cityMissionProgressProvider =
    AsyncNotifierProvider<CityMissionProgressNotifier, List<MissionProgress>>(
  CityMissionProgressNotifier.new,
);

// ─── Derived Providers ───────────────────────────────────────────────────────

final availableMissionsProvider = Provider<List<MissionDefinition>>((ref) {
  final allProgress = ref.watch(cityMissionProgressProvider).value ?? [];
  final service = ref.watch(progressionServiceProvider);
  return service.getAvailableMissions(allProgress);
});

final availableChallengesProvider = Provider<List<MissionDefinition>>((ref) {
  final allProgress = ref.watch(cityMissionProgressProvider).value ?? [];
  final service = ref.watch(progressionServiceProvider);
  return service.getAvailableChallenges(allProgress);
});

final activeMissionsProvider = Provider<List<MissionDefinition>>((ref) {
  final allMissions = ref.watch(availableMissionsProvider);
  final allProgress = ref.watch(cityMissionProgressProvider).value ?? [];
  final completedIds = allProgress
      .where((p) => p.status == MissionStatus.completed)
      .map((p) => p.missionId)
      .toSet();
  return allMissions.where((m) => !completedIds.contains(m.id)).toList();
});

final completedMissionsProvider = Provider<List<MissionDefinition>>((ref) {
  final allProgress = ref.watch(cityMissionProgressProvider).value ?? [];
  final completedIds = allProgress
      .where((p) => p.status == MissionStatus.completed)
      .map((p) => p.missionId)
      .toSet();
  return MissionRegistry.missions
      .where((m) => completedIds.contains(m.id))
      .toList();
});

// ─── Notification Queue ──────────────────────────────────────────────────────

class PendingProgressionEventsNotifier extends Notifier<List<ProgressionEvent>> {
  @override
  List<ProgressionEvent> build() => const [];

  void add(ProgressionEvent event) => state = [...state, event];

  ProgressionEvent? consume() {
    if (state.isEmpty) return null;
    final first = state.first;
    state = state.skip(1).toList();
    return first;
  }

  void clear() => state = const [];
}

final pendingProgressionEventsProvider =
    NotifierProvider<PendingProgressionEventsNotifier, List<ProgressionEvent>>(
  PendingProgressionEventsNotifier.new,
);
