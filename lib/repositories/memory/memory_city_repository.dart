import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/repositories/city_repository.dart';

/// Non-persistent [CityRepository]. Default until the Phase 7 local database,
/// and a test double afterwards.
class MemoryCityRepository implements CityRepository {
  final Map<String, City> _cities = {};

  @override
  Future<List<City>> listCities() async {
    final cities =
        _cities.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(cities);
  }

  @override
  Future<City?> getCity(String id) async => _cities[id];

  @override
  Future<void> saveCity(City city) async => _cities[city.id] = city;

  @override
  Future<void> deleteCity(String id) async => _cities.remove(id);
}
