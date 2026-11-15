import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/repositories/city_repository.dart';
import 'package:city_builder_2040/repositories/local/app_database.dart';

class LocalCityRepository implements CityRepository {
  LocalCityRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<City>> listCities() async {
    try {
      final rows = await _db.listCities();
      return rows.map(_fromRow).toList();
    } catch (e, s) {
      throw RepositoryException('Failed to list cities.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<City?> getCity(String id) async {
    try {
      final row = await _db.getCity(id);
      return row == null ? null : _fromRow(row);
    } catch (e, s) {
      throw RepositoryException('Failed to get city $id.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> saveCity(City city) async {
    try {
      await _db.upsertCity(
        id: city.id,
        name: city.name,
        mapWidth: city.mapWidth,
        mapHeight: city.mapHeight,
        seed: city.seed,
        day: city.day,
        population: city.population,
        createdAt: city.createdAt.toUtc().toIso8601String(),
        updatedAt: city.updatedAt.toUtc().toIso8601String(),
      );
    } catch (e, s) {
      throw RepositoryException('Failed to save city ${city.id}.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> deleteCity(String id) async {
    try {
      await _db.deleteCity(id);
    } catch (e, s) {
      throw RepositoryException('Failed to delete city $id.', cause: e, stackTrace: s);
    }
  }

  static City _fromRow(Map<String, Object?> row) {
    return City(
      id: row['id'] as String,
      name: row['name'] as String,
      mapWidth: (row['map_width'] as int),
      mapHeight: (row['map_height'] as int),
      seed: (row['seed'] as int?) ?? 0,
      day: (row['day'] as int?) ?? 1,
      population: (row['population'] as int?) ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
