import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/core/utils/id_generator.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/buildings/placement_validator.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/repositories/building_repository.dart';

/// Business logic for placing, upgrading and demolishing buildings.
///
/// Operates strictly against [BuildingRepository] without leaking database or
/// UI concerns.
class BuildingService {
  BuildingService({
    required BuildingRepository buildings,
    IdGenerator? idGenerator,
    DateTime Function()? clock,
  }) : _buildings = buildings,
       _ids = idGenerator ?? IdGenerator(),
       _clock = clock ?? DateTime.now;

  final BuildingRepository _buildings;
  final IdGenerator _ids;
  final DateTime Function() _clock;

  /// Loads all placed buildings for [cityId].
  Future<List<Building>> getBuildings(String cityId) async {
    return _buildings.getBuildings(cityId);
  }

  /// Validates and constructs a new building at [position].
  Future<Building> placeBuilding({
    required String cityId,
    required BuildingDefinition definition,
    required GridPoint position,
    required GameMap map,
    required List<Building> existingBuildings,
  }) async {
    final validation = PlacementValidator.validate(
      map: map,
      definition: definition,
      origin: position,
      existingBuildings: existingBuildings,
    );

    if (!validation.isValid) {
      throw ValidationException(validation.message);
    }

    final now = _clock().toUtc();
    final building = Building(
      id: _ids.next(),
      cityId: cityId,
      typeId: definition.id,
      x: position.col,
      y: position.row,
      level: 1,
      createdAt: now,
      updatedAt: now,
    );

    await _buildings.saveBuilding(building);
    return building;
  }

  /// Upgrades an existing building to its next tier.
  Future<Building> upgradeBuilding({
    required String cityId,
    required String buildingId,
    required List<Building> currentBuildings,
  }) async {
    final match = currentBuildings.where((b) => b.id == buildingId);
    if (match.isEmpty) {
      throw const ValidationException('Building not found.');
    }
    final building = match.first;
    final def = BuildingRegistry.get(building.typeId);
    if (def == null) {
      throw const ValidationException('Unknown building definition.');
    }
    if (building.level >= def.maxLevel) {
      throw const ValidationException(
        'Building is already at its maximum level.',
      );
    }

    final updated = building.copyWith(
      level: building.level + 1,
      updatedAt: _clock().toUtc(),
    );
    await _buildings.saveBuilding(updated);
    return updated;
  }

  /// Demolishes a building and returns the calculated refund in coins.
  Future<int> demolishBuilding({
    required String cityId,
    required String buildingId,
    required List<Building> currentBuildings,
  }) async {
    final match = currentBuildings.where((b) => b.id == buildingId);
    if (match.isEmpty) {
      throw const ValidationException('Building not found.');
    }
    final building = match.first;
    final def = BuildingRegistry.get(building.typeId);
    final refund = def?.demolitionRefund(building.level) ?? 0;

    await _buildings.removeBuilding(cityId, buildingId);
    return refund;
  }
}
