import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/core/utils/id_generator.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/buildings/placement_validator.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/repositories/building_repository.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';
import 'package:city_builder_2040/services/economy_service.dart';

/// Business logic for placing, upgrading and demolishing buildings.
///
/// Coordinates spatial validation, [BuildingRepository] persistence, and
/// [ResourceRepository] / [EconomyService] financial transactions.
class BuildingService {
  BuildingService({
    required BuildingRepository buildings,
    ResourceRepository? resources,
    EconomyService? economy,
    IdGenerator? idGenerator,
    DateTime Function()? clock,
  }) : _buildings = buildings,
       _resources = resources,
       _economy = economy,
       _ids = idGenerator ?? IdGenerator(),
       _clock = clock ?? DateTime.now;

  final BuildingRepository _buildings;
  final ResourceRepository? _resources;
  final EconomyService? _economy;
  final IdGenerator _ids;
  final DateTime Function() _clock;

  /// Loads all placed buildings for [cityId].
  Future<List<Building>> getBuildings(String cityId) async {
    return _buildings.getBuildings(cityId);
  }

  /// Validates, deducts coins, and constructs a new building at [position].
  Future<Building> placeBuilding({
    required String cityId,
    required BuildingDefinition definition,
    required GridPoint position,
    required GameMap map,
    required List<Building> existingBuildings,
  }) async {
    // 1. Grid & terrain placement validation
    final validation = PlacementValidator.validate(
      map: map,
      definition: definition,
      origin: position,
      existingBuildings: existingBuildings,
    );

    if (!validation.isValid) {
      throw ValidationException(validation.message);
    }

    // 2. Financial verification and coin deduction if economy is attached
    if (_resources != null && _economy != null) {
      final ledger = await _economy.getOrInitLedger(cityId);
      final result = _economy.deductConstructionCost(
        ledger: ledger,
        definition: definition,
      );
      await _resources.saveLedger(result.ledger);
    }

    // 3. Construct and persist the building
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

  /// Upgrades an existing building to its next tier, deducting upgrade costs.
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

    // Deduct upgrade cost if economy is attached
    if (_resources != null && _economy != null) {
      final ledger = await _economy.getOrInitLedger(cityId);
      final result = _economy.deductUpgradeCost(
        ledger: ledger,
        building: building,
        definition: def,
      );
      await _resources.saveLedger(result.ledger);
    }

    final updated = building.copyWith(
      level: building.level + 1,
      updatedAt: _clock().toUtc(),
    );
    await _buildings.saveBuilding(updated);
    return updated;
  }

  /// Demolishes a building, deposits the refund in coins, and removes the structure.
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

    // Refund coins if economy is attached
    if (_resources != null && _economy != null && def != null) {
      final ledger = await _economy.getOrInitLedger(cityId);
      final result = _economy.addDemolitionRefund(
        ledger: ledger,
        building: building,
        definition: def,
      );
      await _resources.saveLedger(result.ledger);
    }

    await _buildings.removeBuilding(cityId, buildingId);
    return refund;
  }
}
