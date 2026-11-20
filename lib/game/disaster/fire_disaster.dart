import 'dart:math' as math;
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/disaster/disaster_models.dart';

abstract final class FireDisaster {
  /// Spread radius per tick based on severity
  static double spreadPerTick(DisasterSeverity severity) => switch (severity) {
        DisasterSeverity.minor => 1.0,
        DisasterSeverity.moderate => 1.5,
        DisasterSeverity.major => 2.0,
        DisasterSeverity.catastrophic => 3.0,
      };

  /// Initial fire origin damage (the first building)
  static double initialBuildingDamage(DisasterSeverity severity) =>
      severity.intensityFactor * 100;

  /// Orthogonal neighbor deltas (N, S, E, W)
  static const List<(int dc, int dr)> _orthogonal = [
    (0, -1),
    (0, 1),
    (1, 0),
    (-1, 0),
  ];

  /// Spread: given current fire tiles, returns new tiles fire spreads to.
  /// Each burning tile has a chance (based on severity.intensityFactor) of
  /// igniting each orthogonal neighbor that is in [buildingTiles] and not
  /// already burning.
  static Set<GridPoint> spreadFire({
    required Set<GridPoint> currentFireTiles,
    required DisasterSeverity severity,
    required Set<GridPoint> buildingTiles,
    required math.Random random,
  }) {
    final spreadChance = severity.intensityFactor * 0.75;
    final newFireTiles = <GridPoint>{};

    for (final tile in currentFireTiles) {
      for (final (dc, dr) in _orthogonal) {
        final neighbor = GridPoint(tile.col + dc, tile.row + dr);
        // Only spread to building tiles not already on fire
        if (!currentFireTiles.contains(neighbor) &&
            buildingTiles.contains(neighbor)) {
          if (random.nextDouble() < spreadChance) {
            newFireTiles.add(neighbor);
          }
        }
      }
    }

    return newFireTiles;
  }

  /// Happiness penalty based on severity: minor=10, moderate=20, major=30, catastrophic=40
  static int _happinessPenalty(DisasterSeverity severity) => switch (severity) {
        DisasterSeverity.minor => 10,
        DisasterSeverity.moderate => 20,
        DisasterSeverity.major => 30,
        DisasterSeverity.catastrophic => 40,
      };

  /// Calculates damage from fire at current fire tiles.
  /// Buildings on fire tiles take 70–100% damage.
  /// Adjacent road tiles are blocked by smoke/debris.
  static ({
    List<AffectedBuilding> buildings,
    Set<GridPoint> blockedRoads,
    int coinsLost,
    int happinessLost,
  }) calculateDamage({
    required Set<GridPoint> fireTiles,
    required List<Building> buildings,
    required Set<GridPoint> roadTiles,
    required DisasterSeverity severity,
    required math.Random random,
  }) {
    final affectedBuildings = <AffectedBuilding>[];
    int coinsLost = 0;

    // Build a set of fire tile coordinates for O(1) lookup
    final fireTileSet = fireTiles;

    for (final building in buildings) {
      final tile = GridPoint(building.x, building.y);
      if (fireTileSet.contains(tile)) {
        // 70–100% damage for buildings directly on fire tiles
        final damagePercent = 70.0 + random.nextDouble() * 30.0;
        affectedBuildings.add(AffectedBuilding(
          building: building,
          damagePercent: damagePercent,
        ));
        coinsLost += (building.level * 80 * damagePercent / 100).round();
      }
    }

    // Block road tiles adjacent to (or on) any fire tile
    final blockedRoads = <GridPoint>{};
    for (final roadTile in roadTiles) {
      bool adjacentToFire = fireTileSet.contains(roadTile);
      if (!adjacentToFire) {
        for (final (dc, dr) in _orthogonal) {
          if (fireTileSet.contains(GridPoint(roadTile.col + dc, roadTile.row + dr))) {
            adjacentToFire = true;
            break;
          }
        }
      }
      if (adjacentToFire) {
        blockedRoads.add(roadTile);
      }
    }

    return (
      buildings: affectedBuildings,
      blockedRoads: blockedRoads,
      coinsLost: coinsLost,
      happinessLost: _happinessPenalty(severity),
    );
  }

  static String warningMessage(DisasterSeverity severity) =>
      'Fire risk is elevated! Industrial pollution and dry conditions increase fire hazard. '
      'Ensure fire stations are adequately staffed.';

  static String generateNarrative(
    int buildingsBurned,
    int roadsBlocked,
    DisasterSeverity severity,
  ) =>
      'A ${severity.name} fire broke out in the city, consuming $buildingsBurned buildings '
      'and blocking $roadsBlocked road sections. Fire stations have been mobilized.';
}
