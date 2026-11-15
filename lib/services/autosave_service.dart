import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/repositories/city_repository.dart';
import 'package:city_builder_2040/repositories/building_repository.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';
import 'package:city_builder_2040/repositories/mission_repository.dart';
import 'package:city_builder_2040/repositories/player_progress_repository.dart';

/// Saves a consistent snapshot of all city data in one call.
///
/// UI and game logic call [saveSnapshot]; this service coordinates the
/// repository writes in the correct order. No SQL lives here — only
/// orchestration of repository calls.
class AutosaveService {
  AutosaveService({
    required CityRepository cities,
    required BuildingRepository buildings,
    required ResourceRepository resources,
    required MissionRepository missions,
    required PlayerProgressRepository playerProgress,
  })  : _cities = cities,
        _buildings = buildings,
        _resources = resources,
        _missions = missions,
        _playerProgress = playerProgress;

  final CityRepository _cities;
  final BuildingRepository _buildings;
  final ResourceRepository _resources;
  final MissionRepository _missions;
  final PlayerProgressRepository _playerProgress;

  bool _saving = false;

  /// Whether a save is currently in progress.
  bool get isSaving => _saving;

  /// Saves a full city snapshot.
  ///
  /// Silently skips if another save is already in progress (debounce).
  /// Returns `true` when the save completed, `false` when skipped.
  Future<bool> saveSnapshot({
    required City city,
    required List<Building> buildingList,
    required ResourceLedger ledger,
    required List<MissionProgress> missionProgressList,
    required PlayerProgress progress,
  }) async {
    if (_saving) return false;
    _saving = true;
    try {
      await _cities.saveCity(city);
      await _buildings.saveBuildings(buildingList);
      await _resources.saveLedger(ledger);
      for (final mp in missionProgressList) {
        await _missions.saveProgress(mp);
      }
      await _playerProgress.saveProgress(progress);
      return true;
    } finally {
      _saving = false;
    }
  }

  /// Deletes all data for a city (used when the player resets or deletes).
  Future<void> deleteCity(String cityId) async {
    await _missions.deleteByCity(cityId);
    await _resources.deleteByCity(cityId);
    await _buildings.deleteByCity(cityId);
    await _cities.deleteCity(cityId);
  }
}
