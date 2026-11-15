import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/repositories/building_repository.dart';
import 'package:city_builder_2040/repositories/local/app_database.dart';

class LocalBuildingRepository implements BuildingRepository {
  LocalBuildingRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<Building>> getBuildings(String cityId) async {
    try {
      final rows = await _db.getBuildingsByCity(cityId);
      return rows.map(_fromRow).toList();
    } catch (e, s) {
      throw RepositoryException('Failed to get buildings for city $cityId.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> saveBuilding(Building building) async {
    try {
      await _db.upsertBuilding(
        id: building.id,
        cityId: building.cityId,
        typeId: building.typeId,
        x: building.x,
        y: building.y,
        level: building.level,
        createdAt: building.createdAt.toUtc().toIso8601String(),
        updatedAt: building.updatedAt.toUtc().toIso8601String(),
      );
    } catch (e, s) {
      throw RepositoryException('Failed to save building ${building.id}.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> saveBuildings(List<Building> buildings) async {
    try {
      for (final b in buildings) {
        await _db.upsertBuilding(
          id: b.id,
          cityId: b.cityId,
          typeId: b.typeId,
          x: b.x,
          y: b.y,
          level: b.level,
          createdAt: b.createdAt.toUtc().toIso8601String(),
          updatedAt: b.updatedAt.toUtc().toIso8601String(),
        );
      }
    } catch (e, s) {
      throw RepositoryException('Failed to batch-save buildings.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> removeBuilding(String cityId, String buildingId) async {
    try {
      await _db.removeBuilding(cityId, buildingId);
    } catch (e, s) {
      throw RepositoryException('Failed to remove building $buildingId.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> deleteByCity(String cityId) async {
    try {
      await _db.deleteBuildingsByCity(cityId);
    } catch (e, s) {
      throw RepositoryException('Failed to delete buildings for city $cityId.', cause: e, stackTrace: s);
    }
  }

  static Building _fromRow(Map<String, Object?> row) {
    return Building(
      id: row['id'] as String,
      cityId: row['city_id'] as String,
      typeId: row['type_id'] as String,
      x: row['x'] as int,
      y: row['y'] as int,
      level: (row['level'] as int?) ?? 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
