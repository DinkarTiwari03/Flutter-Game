import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/repositories/player_progress_repository.dart';

/// Non-persistent [PlayerProgressRepository].
class MemoryPlayerProgressRepository implements PlayerProgressRepository {
  final Map<String, PlayerProgress> _byPlayer = {};

  @override
  Future<PlayerProgress?> getProgress(String playerId) async =>
      _byPlayer[playerId];

  @override
  Future<void> saveProgress(PlayerProgress progress) async =>
      _byPlayer[progress.playerId] = progress;
}
