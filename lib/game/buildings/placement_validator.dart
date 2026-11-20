import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';
import 'package:city_builder_2040/models/building.dart';

/// Reason why a building placement is valid or invalid.
enum PlacementValidationReason {
  valid('Valid placement'),
  outOfBounds('Outside city limits'),
  invalidTerrain('Cannot build on water or unstable terrain'),
  buildingOverlap('Overlaps an existing building'),
  blockedByRoad('Cannot build over an existing road');

  const PlacementValidationReason(this.defaultMessage);

  final String defaultMessage;
}

/// The result of validating a proposed building placement.
class PlacementValidationResult {
  const PlacementValidationResult({
    required this.reason,
    required this.footprint,
    this.invalidTiles = const {},
    String? message,
  }) : _customMessage = message;

  final PlacementValidationReason reason;
  final List<GridPoint> footprint;
  final Set<GridPoint> invalidTiles;
  final String? _customMessage;

  bool get isValid => reason == PlacementValidationReason.valid;

  String get message => _customMessage ?? reason.defaultMessage;
}

/// Validates whether a proposed building can be placed at a specific grid position.
abstract final class PlacementValidator {
  /// Validates [definition] positioned with its top-left at [origin] on [map],
  /// checking against map bounds, terrain types, and [existingBuildings].
  ///
  /// [rotation] must be 0, 90, 180, or 270 (defaults to 0).
  static PlacementValidationResult validate({
    required GameMap map,
    required BuildingDefinition definition,
    required GridPoint origin,
    required List<Building> existingBuildings,
    int rotation = 0,
  }) {
    final footprint = definition.footprintTilesRotated(origin, rotation);
    final invalidTiles = <GridPoint>{};

    // 1. Check map boundaries
    var outOfBounds = false;
    for (final tile in footprint) {
      if (!map.contains(tile)) {
        outOfBounds = true;
        invalidTiles.add(tile);
      }
    }
    if (outOfBounds) {
      return PlacementValidationResult(
        reason: PlacementValidationReason.outOfBounds,
        footprint: footprint,
        invalidTiles: invalidTiles,
        message: 'Cannot build outside city limits',
      );
    }

    // 2. Build occupancy lookup for existing buildings (respecting their rotation)
    final occupiedTiles = <GridPoint, Building>{};
    for (final b in existingBuildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;
      for (final t in def.footprintTilesRotated(GridPoint(b.x, b.y), b.rotation)) {
        occupiedTiles[t] = b;
      }
    }

    // 3. Check collision with existing buildings
    var buildingOverlap = false;
    for (final tile in footprint) {
      if (occupiedTiles.containsKey(tile)) {
        buildingOverlap = true;
        invalidTiles.add(tile);
      }
    }
    if (buildingOverlap) {
      return PlacementValidationResult(
        reason: PlacementValidationReason.buildingOverlap,
        footprint: footprint,
        invalidTiles: invalidTiles,
        message: 'Space is already occupied by a building',
      );
    }

    // 4. Check terrain and ground type
    var waterError = false;
    var roadError = false;
    for (final tile in footprint) {
      final groundType = map.typeAt(tile.col, tile.row);
      if (groundType == TileType.water) {
        waterError = true;
        invalidTiles.add(tile);
      } else if (groundType == TileType.road && !definition.isRoad) {
        // Buildings cannot be placed on top of roads
        roadError = true;
        invalidTiles.add(tile);
      } else if (!groundType.isBuildable && !definition.isRoad) {
        waterError = true;
        invalidTiles.add(tile);
      }
    }

    if (waterError) {
      return PlacementValidationResult(
        reason: PlacementValidationReason.invalidTerrain,
        footprint: footprint,
        invalidTiles: invalidTiles,
        message: 'Cannot construct on water',
      );
    }

    if (roadError) {
      return PlacementValidationResult(
        reason: PlacementValidationReason.blockedByRoad,
        footprint: footprint,
        invalidTiles: invalidTiles,
        message: 'Cannot build over existing road',
      );
    }

    return PlacementValidationResult(
      reason: PlacementValidationReason.valid,
      footprint: footprint,
      invalidTiles: const {},
    );
  }
}
