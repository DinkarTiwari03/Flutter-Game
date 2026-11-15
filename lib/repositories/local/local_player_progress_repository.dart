import 'dart:convert';

import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/repositories/local/app_database.dart';
import 'package:city_builder_2040/repositories/player_progress_repository.dart';

class LocalPlayerProgressRepository implements PlayerProgressRepository {
  LocalPlayerProgressRepository(this._db);
  final AppDatabase _db;

  @override
  Future<PlayerProgress?> getProgress(String playerId) async {
    try {
      final row = await _db.getPlayerProgress(playerId);
      if (row == null) return null;
      return _fromRow(row);
    } catch (e, s) {
      throw RepositoryException('Failed to get player progress for $playerId.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> saveProgress(PlayerProgress progress) async {
    try {
      await _db.upsertPlayerProgress(
        playerId: progress.playerId,
        level: progress.level,
        experience: progress.experience,
        unlockedIdsJson: jsonEncode(progress.unlockedIds),
        claimedMissionIdsJson: jsonEncode(progress.claimedMissionIds),
        completedAchievementIdsJson: jsonEncode(progress.completedAchievementIds),
        updatedAt: progress.updatedAt.toUtc().toIso8601String(),
      );
    } catch (e, s) {
      throw RepositoryException('Failed to save player progress for ${progress.playerId}.', cause: e, stackTrace: s);
    }
  }

  static PlayerProgress _fromRow(Map<String, Object?> row) {
    List<String> decodeList(String json) =>
        (jsonDecode(json) as List).cast<String>();

    return PlayerProgress(
      playerId: row['player_id'] as String,
      level: (row['level'] as int?) ?? 1,
      experience: (row['experience'] as int?) ?? 0,
      unlockedIds: decodeList((row['unlocked_ids_json'] as String?) ?? '[]'),
      claimedMissionIds: decodeList((row['claimed_mission_ids_json'] as String?) ?? '[]'),
      completedAchievementIds: decodeList((row['completed_achievement_ids_json'] as String?) ?? '[]'),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
