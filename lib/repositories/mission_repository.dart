import 'package:city_builder_2040/models/mission_progress.dart';

/// Persistence contract for per-city mission progress.
/// See `CityRepository` for the contract shared by all repositories.
abstract interface class MissionRepository {
  Future<List<MissionProgress>> getProgress(String cityId);

  Future<void> saveProgress(MissionProgress progress);

  /// Removes all mission progress of the city. Idempotent.
  Future<void> deleteByCity(String cityId);
}
