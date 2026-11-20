import 'dart:math' as math;
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/disaster/disaster_models.dart';

abstract final class EarthquakeDisaster {
  /// Radius in tiles based on severity
  static double getRadius(DisasterSeverity severity) => switch (severity) {
        DisasterSeverity.minor => 3.0,
        DisasterSeverity.moderate => 5.0,
        DisasterSeverity.major => 7.0,
        DisasterSeverity.catastrophic => 10.0,
      };

  /// Building damage percent based on distance from epicenter and severity
  static double buildingDamage({
    required double distanceTiles,
    required double radius,
    required DisasterSeverity severity,
    required math.Random random,
  }) {
    if (distanceTiles > radius) return 0.0;
    final proximity = 1.0 - (distanceTiles / radius);
    final base = proximity * severity.intensityFactor * 100;
    final jitter = (random.nextDouble() - 0.5) * 20;
    return (base + jitter).clamp(0.0, 100.0);
  }

  /// Road blockage probability based on distance and severity
  static bool isRoadBlocked(
    double distanceTiles,
    double radius,
    DisasterSeverity severity,
    math.Random random,
  ) {
    if (distanceTiles > radius) return false;
    final proximity = 1.0 - (distanceTiles / radius);
    final prob = proximity * severity.intensityFactor * 0.6;
    return random.nextDouble() < prob;
  }

  /// Happiness penalty based on severity: minor=5, moderate=10, major=18, catastrophic=25
  static int _happinessPenalty(DisasterSeverity severity) => switch (severity) {
        DisasterSeverity.minor => 5,
        DisasterSeverity.moderate => 10,
        DisasterSeverity.major => 18,
        DisasterSeverity.catastrophic => 25,
      };

  /// Calculates all damage for a single earthquake event
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
    final affectedBuildings = <AffectedBuilding>[];
    int coinsLost = 0;

    for (final building in buildings) {
      final dx = building.x - epicenterX;
      final dy = building.y - epicenterY;
      final distance = math.sqrt(dx * dx + dy * dy);

      final damagePercent = buildingDamage(
        distanceTiles: distance,
        radius: radius,
        severity: severity,
        random: random,
      );

      if (damagePercent > 0.0) {
        affectedBuildings.add(AffectedBuilding(
          building: building,
          damagePercent: damagePercent,
        ));
        coinsLost += (building.level * 50 * damagePercent / 100).round();
      }
    }

    final blockedRoads = <GridPoint>{};
    for (final tile in roadTiles) {
      final dx = tile.col - epicenterX;
      final dy = tile.row - epicenterY;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (isRoadBlocked(distance, radius, severity, random)) {
        blockedRoads.add(tile);
      }
    }

    return (
      buildings: affectedBuildings,
      blockedRoads: blockedRoads,
      coinsLost: coinsLost,
      happinessLost: _happinessPenalty(severity),
    );
  }

  /// Warning message for the UI
  static String warningMessage(DisasterSeverity severity) =>
      'Seismic activity detected! A ${severity.name} earthquake may strike soon. '
      'Ensure hospitals and fire stations are operational.';

  /// Narrative for post-disaster report
  static String generateNarrative(
    int buildingsDamaged,
    int roadsBlocked,
    DisasterSeverity severity,
  ) =>
      'A ${severity.name} earthquake struck the city, damaging $buildingsDamaged buildings '
      'and blocking $roadsBlocked road sections. Emergency services have been deployed.';
}
