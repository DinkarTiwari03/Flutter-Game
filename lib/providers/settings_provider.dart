import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/models/app_settings.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';
import 'package:city_builder_2040/repositories/settings_repository.dart';

/// Loads [AppSettings] from the local database and persists every change.
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  late SettingsRepository _repo;

  @override
  Future<AppSettings> build() async {
    _repo = ref.watch(settingsRepositoryProvider);
    return _repo.getSettings();
  }

  Future<void> setSoundEnabled(bool value) => _update(
        (s) => s.copyWith(soundEnabled: value),
      );

  Future<void> setMusicEnabled(bool value) => _update(
        (s) => s.copyWith(musicEnabled: value),
      );

  Future<void> setMasterVolume(double value) => _update(
        (s) => s.copyWith(masterVolume: value.clamp(0.0, 1.0)),
      );

  Future<void> setSimulationSpeed(int speed) => _update(
        (s) => s.copyWith(simulationSpeed: speed.clamp(1, 3)),
      );

  Future<void> setShowGrid(bool value) => _update(
        (s) => s.copyWith(showGrid: value),
      );

  Future<void> completeTutorial() => _update(
        (s) => s.copyWith(tutorialCompleted: true),
      );

  Future<void> resetTutorial() => _update(
        (s) => s.copyWith(tutorialCompleted: false),
      );

  Future<void> resetAll() async {
    await _repo.resetSettings();
    state = const AsyncData(AppSettings());
  }

  Future<void> _update(AppSettings Function(AppSettings) fn) async {
    final current = state.value ?? const AppSettings();
    final next = fn(current);
    state = AsyncData(next);
    await _repo.saveSettings(next);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// Convenience provider that returns [AppSettings] synchronously with a safe
/// default while loading. Widgets that just need to read a setting use this.
final settingsValueProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsProvider).value ?? const AppSettings();
});
