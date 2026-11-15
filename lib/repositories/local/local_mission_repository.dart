import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/repositories/local/app_database.dart';
import 'package:city_builder_2040/repositories/mission_repository.dart';

class LocalMissionRepository implements MissionRepository {
  LocalMissionRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<MissionProgress>> getProgress(String cityId) async {
    try {
      final rows = await _db.getMissionProgress(cityId);
      return rows.map(_fromRow).toList();
    } catch (e, s) {
      throw RepositoryException('Failed to get mission progress for city $cityId.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> saveProgress(MissionProgress progress) async {
    try {
      await _db.upsertMissionProgress(
        cityId: progress.cityId,
        missionId: progress.missionId,
        status: progress.status.name,
        progress: progress.progress,
        rewardClaimed: progress.rewardClaimed ? 1 : 0,
        completedAt: progress.completedAt?.toUtc().toIso8601String(),
        updatedAt: progress.updatedAt.toUtc().toIso8601String(),
      );
    } catch (e, s) {
      throw RepositoryException('Failed to save mission progress ${progress.missionId}.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> deleteByCity(String cityId) async {
    try {
      await _db.deleteMissionProgressByCity(cityId);
    } catch (e, s) {
      throw RepositoryException('Failed to delete mission progress for city $cityId.', cause: e, stackTrace: s);
    }
  }

  static MissionProgress _fromRow(Map<String, Object?> row) {
    return MissionProgress(
      cityId: row['city_id'] as String,
      missionId: row['mission_id'] as String,
      status: MissionStatus.values.byName(row['status'] as String),
      progress: (row['progress'] as num).toDouble(),
      rewardClaimed: (row['reward_claimed'] as int) == 1,
      completedAt: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String)
          : null,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
