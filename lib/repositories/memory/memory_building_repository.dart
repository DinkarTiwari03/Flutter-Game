import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/repositories/building_repository.dart';

/// Non-persistent [BuildingRepository].
class MemoryBuildingRepository implements BuildingRepository {
  final Map<String, Map<String, Building>> _byCity = {};

  @override
  Future<List<Building>> getBuildings(String cityId) async {
    return List.unmodifiable(_byCity[cityId]?.values ?? const <Building>[]);
  }

  @override
  Future<void> saveBuilding(Building building) async {
    _byCity.putIfAbsent(building.cityId, () => {})[building.id] = building;
  }

  @override
  Future<void> saveBuildings(List<Building> buildings) async {
    for (final building in buildings) {
      await saveBuilding(building);
    }
  }

  @override
  Future<void> removeBuilding(String cityId, String buildingId) async {
    _byCity[cityId]?.remove(buildingId);
  }

  @override
  Future<void> deleteByCity(String cityId) async => _byCity.remove(cityId);
}
