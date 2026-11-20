import 'dart:math' as math;
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/disaster/disaster_models.dart';

abstract final class FloodDisaster {
  /// Flood radius in tiles based on severity.
  static double getRadius(DisasterSeverity severity) => switch (severity) {
        DisasterSeverity.minor => 5.0,
        DisasterSeverity.moderate => 8.0,
        DisasterSeverity.major => 11.0,
        DisasterSeverity.catastrophic => 15.0,
      };

  /// All roads in radius are flooded and rendered inaccessible.
  static Set<GridPoint> floodedRoads({
    required int epicenterX,
    required int epicenterY,
    required double radius,
    required Set<GridPoint> roadTiles,
  }) {
    final flooded = <GridPoint>{};
    for (final tile in roadTiles) {
      final dx = tile.col - epicenterX;
      final dy = tile.row - epicenterY;
      if (math.sqrt(dx * dx + dy * dy) <= radius) {
        flooded.add(tile);
      }
    }
    return flooded;
  }

  /// Residential and ground-floor buildings in the flood zone take water damage (15-40%).
  static List<AffectedBuilding> calculateBuildingDamage({
    required int epicenterX,
    required int epicenterY,
    required double radius,
    required List<Building> buildings,
    required DisasterSeverity severity,
    required math.Random random,
  }) {
    final affected = <AffectedBuilding>[];
    for (final b in buildings) {
      final dx = b.x - epicenterX;
      final dy = b.y - epicenterY;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= radius) {
        final proximity = 1.0 - (dist / radius);
        // Residential suffers displacement; other categories suffer basement flooding
        final base = (b.typeId.contains('house') || b.typeId.contains('apartment'))
            ? 25.0
            : 15.0;
        final dmg = (base + proximity * 25.0 * severity.intensityFactor +
                (random.nextDouble() - 0.5) * 10)
            .clamp(5.0, 60.0);

        affected.add(AffectedBuilding(
          building: b,
          damagePercent: dmg,
        ));
      }
    }
    return affected;
  }

  static int _happinessPenalty(DisasterSeverity severity) => switch (severity) {
        DisasterSeverity.minor => 8,
        DisasterSeverity.moderate => 15,
        DisasterSeverity.major => 24,
        DisasterSeverity.catastrophic => 35,
      };

  /// Calculates complete flood damage: wide road blockages, moderate building damage, economic cleanup.
  static ({
    List<AffectedBuilding> buildings,
    Set<GridPoint> blockedRoads,
    int coinsLost,
    int happinessLost,
  }) calculateDamage({
    required int epicenterX,
    required int epicenterY,
    required DisasterSeverity severity,
    required List<Building> buildings,
    required Set<GridPoint> roadTiles,
    required math.Random random,
  }) {
    final radius = getRadius(severity);
    final blocked = floodedRoads(
      epicenterX: epicenterX,
      epicenterY: epicenterY,
      radius: radius,
      roadTiles: roadTiles,
    );

    final affected = calculateBuildingDamage(
      epicenterX: epicenterX,
      epicenterY: epicenterY,
      radius: radius,
      buildings: buildings,
      severity: severity,
      random: random,
    );

    int coinsLost = 0;
    for (final b in affected) {
      coinsLost += (b.building.level * 40 * b.damagePercent / 100).round();
    }
    // Water cleanup costs per blocked road
    coinsLost += blocked.length * 20;

    return (
      buildings: affected,
      blockedRoads: blocked,
      coinsLost: coinsLost,
      happinessLost: _happinessPenalty(severity),
    );
  }

  static String warningMessage(DisasterSeverity severity) =>
      'Flood warning! Torrential rainfall and rising water levels detected. '
      'Low-lying roads may submerge. Prepare emergency drainage and flood barriers.';

  static String generateNarrative(
    int buildingsDamaged,
    int roadsBlocked,
    DisasterSeverity severity,
  ) =>
      'A ${severity.name} flood inundated the district, blocking $roadsBlocked roads '
      'and water-damaging $buildingsDamaged buildings. Emergency water pumps are clearing routes.';
}
