import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/disaster/disaster_models.dart';

abstract final class HeatwaveDisaster {
  /// Heatwave is city-wide — affects public health and utilities rather than physical building destruction.

  /// Happiness penalty adjusted for healthcare coverage rating.
  static int happinessPenalty(DisasterSeverity severity, int healthcareRating) {
    final base = switch (severity) {
      DisasterSeverity.minor => 8,
      DisasterSeverity.moderate => 16,
      DisasterSeverity.major => 26,
      DisasterSeverity.catastrophic => 38,
    };
    // Healthcare coverage reduces heat-stroke and citizen suffering
    final relief = (healthcareRating / 100.0 * 0.4 * base).round();
    return (base - relief).clamp(4, 40);
  }

  /// Percentage increase in electricity demand (air conditioning surge).
  static int electricityDemandIncrease(DisasterSeverity severity) =>
      switch (severity) {
        DisasterSeverity.minor => 15,
        DisasterSeverity.moderate => 25,
        DisasterSeverity.major => 40,
        DisasterSeverity.catastrophic => 60,
      };

  /// Additional pollution units emitted due to peaking fossil power stations.
  static int pollutionIncrease(DisasterSeverity severity) => switch (severity) {
        DisasterSeverity.minor => 4,
        DisasterSeverity.moderate => 8,
        DisasterSeverity.major => 14,
        DisasterSeverity.catastrophic => 22,
      };

  /// Road blockages are 0 for heatwaves (roads remain physically open).
  static const Set<GridPoint> blockedRoads = {};

  /// No structural building destruction during a heatwave.
  static List<AffectedBuilding> get damagedBuildings => const [];

  /// Calculates economic losses from heatwave (lost productivity + hospital surge).
  static ({
    List<AffectedBuilding> buildings,
    Set<GridPoint> blockedRoads,
    int coinsLost,
    int happinessLost,
  }) calculateDamage({
    required DisasterSeverity severity,
    required int population,
    required int healthcareRating,
  }) {
    final happinessLost = happinessPenalty(severity, healthcareRating);
    // Medical treatment costs and lost economic productivity
    final perCapitaCost = severity.intensityFactor * 3.5;
    final coinsLost = (population * perCapitaCost).round().clamp(100, 5000);

    return (
      buildings: const <AffectedBuilding>[],
      blockedRoads: const <GridPoint>{},
      coinsLost: coinsLost,
      happinessLost: happinessLost,
    );
  }

  static String warningMessage(DisasterSeverity severity) =>
      'Extreme Heatwave Warning! Scorching temperatures approaching. '
      'Electricity consumption will spike for air conditioning. Ensure adequate hospital capacity.';

  static String generateNarrative(
    int happinessLost,
    DisasterSeverity severity,
  ) =>
      'A ${severity.name} heatwave gripped the metropolis. City-wide power demand surged, '
      'and extreme temperatures strained municipal healthcare services.';
}
