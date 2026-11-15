import 'package:city_builder_2040/models/city.dart';

/// Persistence contract for saved cities (save slots).
///
/// Contract shared by every repository in this project:
/// - `save*` methods are upserts: they insert or replace by id.
/// - `get*` methods return `null` (or an empty list) when nothing is stored.
/// - Failures are reported as `RepositoryException`, never as
///   backend-specific exceptions.
/// - Repositories only manage their own data. Cross-repository rules, such as
///   deleting everything that belongs to a city, live in services.
abstract interface class CityRepository {
  /// All saved cities, most recently updated first.
  Future<List<City>> listCities();

  Future<City?> getCity(String id);

  Future<void> saveCity(City city);

  /// Removes only the city record. Idempotent.
  Future<void> deleteCity(String id);
}
