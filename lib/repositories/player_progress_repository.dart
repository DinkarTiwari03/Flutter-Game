import 'package:city_builder_2040/models/player_progress.dart';

/// Persistence contract for account-wide player progression.
/// See `CityRepository` for the contract shared by all repositories.
abstract interface class PlayerProgressRepository {
  Future<PlayerProgress?> getProgress(String playerId);

  Future<void> saveProgress(PlayerProgress progress);
}
