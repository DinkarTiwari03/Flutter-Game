import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/repositories/mission_repository.dart';

/// Non-persistent [MissionRepository].
class MemoryMissionRepository implements MissionRepository {
  final Map<String, Map<String, MissionProgress>> _byCity = {};

  @override
  Future<List<MissionProgress>> getProgress(String cityId) async {
    return List.unmodifiable(
      _byCity[cityId]?.values ?? const <MissionProgress>[],
    );
  }

  @override
  Future<void> saveProgress(MissionProgress progress) async {
    _byCity.putIfAbsent(progress.cityId, () => {})[progress.missionId] =
        progress;
  }

  @override
  Future<void> deleteByCity(String cityId) async => _byCity.remove(cityId);
}
