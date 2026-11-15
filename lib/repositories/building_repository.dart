import 'package:city_builder_2040/models/building.dart';

/// Persistence contract for buildings placed in a city.
/// See `CityRepository` for the contract shared by all repositories.
abstract interface class BuildingRepository {
  Future<List<Building>> getBuildings(String cityId);

  Future<void> saveBuilding(Building building);

  /// Batch upsert, intended for autosave of many buildings at once.
  Future<void> saveBuildings(List<Building> buildings);

  Future<void> removeBuilding(String cityId, String buildingId);

  /// Removes every building of the city. Idempotent.
  Future<void> deleteByCity(String cityId);
}
