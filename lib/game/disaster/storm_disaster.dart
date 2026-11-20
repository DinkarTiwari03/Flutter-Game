import 'dart:math' as math;
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/disaster/disaster_models.dart';

abstract final class StormDisaster {
  /// Storm radius in tiles based on severity.
  static double getRadius(DisasterSeverity severity) => switch (severity) {
        DisasterSeverity.minor => 4.0,
        DisasterSeverity.moderate => 6.0,
        DisasterSeverity.major => 9.0,
        DisasterSeverity.catastrophic => 12.0,
      };

  /// Storm blocks roads with fallen trees, debris, and utility lines.
  static Set<GridPoint> blockedByStorm({
    required int epicenterX,
    required int epicenterY,
    required double radius,
    required Set<GridPoint> roadTiles,
    required DisasterSeverity severity,
    required math.Random random,
  }) {
    final blocked = <GridPoint>{};
    final prob = (severity.intensityFactor * 0.45).clamp(0.1, 0.6);
    for (final tile in roadTiles) {
      final dx = tile.col - epicenterX;
      final dy = tile.row - epicenterY;
      if (math.sqrt(dx * dx + dy * dy) <= radius) {
        if (random.nextDouble() < prob) {
          blocked.add(tile);
        }
      }
    }
    return blocked;
  }

  /// High gale wind and lightning damage to roofs and light structures.
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
        // Weaker/taller buildings take roof/window damage
        final base = (b.typeId.contains('tower') || b.typeId.contains('mall'))
            ? 20.0
            : 10.0;
        final dmg = (base + proximity * 30.0 * severity.intensityFactor +
                (random.nextDouble() - 0.5) * 12)
            .clamp(5.0, 50.0);

        affected.add(AffectedBuilding(
          building: b,
          damagePercent: dmg,
        ));
      }
    }
    return affected;
  }

  static int _happinessPenalty(DisasterSeverity severity) => switch (severity) {
        DisasterSeverity.minor => 6,
        DisasterSeverity.moderate => 12,
        DisasterSeverity.major => 20,
        DisasterSeverity.catastrophic => 30,
      };

  /// Calculates complete storm damage.
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
    final blocked = blockedByStorm(
      epicenterX: epicenterX,
      epicenterY: epicenterY,
      radius: radius,
      roadTiles: roadTiles,
      severity: severity,
      random: random,
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
      coinsLost += (b.building.level * 45 * b.damagePercent / 100).round();
    }
    coinsLost += blocked.length * 15; // Debris removal costs

    return (
      buildings: affected,
      blockedRoads: blocked,
      coinsLost: coinsLost,
      happinessLost: _happinessPenalty(severity),
    );
  }

  static String warningMessage(DisasterSeverity severity) =>
      'Severe Gale Alert! High winds, lightning, and fallen trees anticipated. '
      'Secure loose structures and prepare emergency crews.';

  static String generateNarrative(
    int buildingsDamaged,
    int roadsBlocked,
    DisasterSeverity severity,
  ) =>
      'A ${severity.name} storm swept through, blowing down power lines, blocking $roadsBlocked roads '
      'with debris, and damaging $buildingsDamaged building roofs.';
}
