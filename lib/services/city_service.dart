import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/core/utils/id_generator.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/repositories/building_repository.dart';
import 'package:city_builder_2040/repositories/city_repository.dart';
import 'package:city_builder_2040/repositories/mission_repository.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';

/// City-level business rules that span several repositories.
///
/// Depends only on repository interfaces, so swapping the storage backend
/// (in-memory, local database, cloud) never touches this class.
class CityService {
  CityService({
    required CityRepository cities,
    required BuildingRepository buildings,
    required ResourceRepository resources,
    required MissionRepository missions,
    IdGenerator? idGenerator,
    DateTime Function()? clock,
  }) : _cities = cities,
       _buildings = buildings,
       _resources = resources,
       _missions = missions,
       _ids = idGenerator ?? IdGenerator(),
       _clock = clock ?? DateTime.now;

  final CityRepository _cities;
  final BuildingRepository _buildings;
  final ResourceRepository _resources;
  final MissionRepository _missions;
  final IdGenerator _ids;
  final DateTime Function() _clock;

  /// Validates input, then creates and stores a new city.
  Future<City> createCity({
    required String name,
    int mapWidth = AppConstants.defaultMapSize,
    int mapHeight = AppConstants.defaultMapSize,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('City name cannot be empty.');
    }
    if (trimmed.length > AppConstants.maxCityNameLength) {
      throw const ValidationException(
        'City name must be ${AppConstants.maxCityNameLength} '
        'characters or fewer.',
      );
    }
    if (mapWidth <= 0 || mapHeight <= 0) {
      throw const ValidationException('Map size must be positive.');
    }

    final now = _clock().toUtc();
    final city = City(
      id: _ids.next(),
      name: trimmed,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
      createdAt: now,
      updatedAt: now,
    );
    await _cities.saveCity(city);
    return city;
  }

  /// The most recently played city, or `null` when no save exists.
  /// This is what the Continue button will use.
  Future<City?> latestCity() async {
    final cities = await _cities.listCities();
    return cities.isEmpty ? null : cities.first;
  }

  Future<bool> hasSavedCity() async => await latestCity() != null;

  /// Deletes a city and everything that belongs to it.
  ///
  /// The city record is removed last, so if a step fails the city is still
  /// listed and the deletion can simply be retried.
  Future<void> deleteCity(String cityId) async {
    await _buildings.deleteByCity(cityId);
    await _resources.deleteByCity(cityId);
    await _missions.deleteByCity(cityId);
    await _cities.deleteCity(cityId);
  }
}
