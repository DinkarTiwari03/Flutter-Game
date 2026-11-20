import 'package:flutter/material.dart';
import 'package:city_builder_2040/models/building.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DisasterType
// ─────────────────────────────────────────────────────────────────────────────

enum DisasterType {
  earthquake(
    'Earthquake',
    Icons.terrain_rounded,
    Color(0xFF8B4513),
  ),
  fire(
    'Fire',
    Icons.local_fire_department_rounded,
    Color(0xFFEF4444),
  ),
  flood(
    'Flood',
    Icons.water_rounded,
    Color(0xFF3B82F6),
  ),
  storm(
    'Storm',
    Icons.thunderstorm_rounded,
    Color(0xFF6366F1),
  ),
  heatwave(
    'Heatwave',
    Icons.wb_sunny_rounded,
    Color(0xFFEF8C00),
  );

  const DisasterType(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

// ─────────────────────────────────────────────────────────────────────────────
// DisasterPhase
// ─────────────────────────────────────────────────────────────────────────────

enum DisasterPhase {
  /// Seismic/environmental signals detected — UI shows a warning.
  warning,

  /// Disaster is actively causing damage.
  occurring,

  /// Damage has been assessed; emergency services mobilised.
  response,

  /// City rebuilds; blocked roads gradually cleared.
  recovery,

  /// All effects resolved; disaster moved to history.
  complete,
}

// ─────────────────────────────────────────────────────────────────────────────
// DisasterSeverity
// ─────────────────────────────────────────────────────────────────────────────

enum DisasterSeverity {
  minor(intensityFactor: 0.25, label: 'Minor'),
  moderate(intensityFactor: 0.50, label: 'Moderate'),
  major(intensityFactor: 0.75, label: 'Major'),
  catastrophic(intensityFactor: 1.00, label: 'Catastrophic');

  const DisasterSeverity({
    required this.intensityFactor,
    required this.label,
  });

  /// 0.25 – 1.0 scalar applied to damage and radius calculations.
  final double intensityFactor;
  final String label;
}

// ─────────────────────────────────────────────────────────────────────────────
// DisasterRiskLevel
// ─────────────────────────────────────────────────────────────────────────────

enum DisasterRiskLevel {
  low(label: 'Low', color: Color(0xFF22C55E)),
  elevated(label: 'Elevated', color: Color(0xFFEAB308)),
  high(label: 'High', color: Color(0xFFF97316)),
  critical(label: 'Critical', color: Color(0xFFEF4444));

  const DisasterRiskLevel({required this.label, required this.color});

  final String label;
  final Color color;

  /// Maps a normalised risk multiplier (1.0 = base) to a risk level.
  static DisasterRiskLevel fromMultiplier(double multiplier) {
    if (multiplier >= 3.0) return DisasterRiskLevel.critical;
    if (multiplier >= 2.0) return DisasterRiskLevel.high;
    if (multiplier >= 1.3) return DisasterRiskLevel.elevated;
    return DisasterRiskLevel.low;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DisasterConfig
// ─────────────────────────────────────────────────────────────────────────────

/// Probability settings that drive the disaster engine.
/// All values are fractional probabilities per simulated hour (0.0 – 1.0).
class DisasterConfig {
  DisasterConfig({
    this.earthquakeProbPerHour = 0.005,
    this.fireProbPerHour = 0.008,
    this.floodProbPerHour = 0.004,
    this.stormProbPerHour = 0.006,
    this.heatwaveProbPerHour = 0.003,
    this.minHoursBetweenDisasters = 24,
  });

  /// Base earthquake probability per simulated hour.
  double earthquakeProbPerHour;

  /// Base fire probability per simulated hour.
  double fireProbPerHour;

  /// Base flood probability per simulated hour.
  double floodProbPerHour;

  /// Base storm probability per simulated hour.
  double stormProbPerHour;

  /// Base heatwave probability per simulated hour.
  double heatwaveProbPerHour;

  /// Minimum simulated hours that must pass before a new disaster can start.
  int minHoursBetweenDisasters;

  /// Returns the base probability for the given [type].
  double baseProb(DisasterType type) => switch (type) {
        DisasterType.earthquake => earthquakeProbPerHour,
        DisasterType.fire => fireProbPerHour,
        DisasterType.flood => floodProbPerHour,
        DisasterType.storm => stormProbPerHour,
        DisasterType.heatwave => heatwaveProbPerHour,
      };

  /// Creates a copy with modified values (useful for scenario / test overrides).
  DisasterConfig copyWith({
    double? earthquakeProbPerHour,
    double? fireProbPerHour,
    double? floodProbPerHour,
    double? stormProbPerHour,
    double? heatwaveProbPerHour,
    int? minHoursBetweenDisasters,
  }) =>
      DisasterConfig(
        earthquakeProbPerHour:
            earthquakeProbPerHour ?? this.earthquakeProbPerHour,
        fireProbPerHour: fireProbPerHour ?? this.fireProbPerHour,
        floodProbPerHour: floodProbPerHour ?? this.floodProbPerHour,
        stormProbPerHour: stormProbPerHour ?? this.stormProbPerHour,
        heatwaveProbPerHour: heatwaveProbPerHour ?? this.heatwaveProbPerHour,
        minHoursBetweenDisasters:
            minHoursBetweenDisasters ?? this.minHoursBetweenDisasters,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AffectedBuilding
// ─────────────────────────────────────────────────────────────────────────────

/// Tracks the damage state of a single building hit by a disaster.
class AffectedBuilding {
  const AffectedBuilding({
    required this.building,
    required this.damagePercent,
    this.isBlocked = false,
  });

  /// The building that was affected.
  final Building building;

  /// 0–100 damage percentage.
  final double damagePercent;

  /// Whether this building tile is physically impassable (e.g. collapse blocks roads).
  final bool isBlocked;

  bool get isDestroyed => damagePercent >= 90.0;

  String get buildingId => building.id;
  String get typeId => building.typeId;
  int get x => building.x;
  int get y => building.y;
}

// ─────────────────────────────────────────────────────────────────────────────
// AffectedRoad
// ─────────────────────────────────────────────────────────────────────────────

/// Tracks the damage state of a road tile hit by a disaster.
class AffectedRoad {
  const AffectedRoad({
    required this.x,
    required this.y,
    required this.isBlocked,
    required this.damagePercent,
  });

  final int x;
  final int y;
  final bool isBlocked;

  /// 0–100 damage percentage.
  final double damagePercent;
}

// ─────────────────────────────────────────────────────────────────────────────
// DisasterReport
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable post-disaster summary stored in the history log.
class DisasterReport {
  const DisasterReport({
    required this.id,
    required this.type,
    required this.severity,
    required this.occurredAt,
    required this.buildingsDamaged,
    required this.buildingsDestroyed,
    required this.roadsBlocked,
    required this.coinsLost,
    required this.happinessLost,
    required this.recoveryDurationTicks,
    required this.narrative,
  });

  final String id;
  final DisasterType type;
  final DisasterSeverity severity;
  final DateTime occurredAt;
  final int buildingsDamaged;
  final int buildingsDestroyed;
  final int roadsBlocked;
  final int coinsLost;
  final int happinessLost;

  /// Estimated ticks until full recovery.
  final int recoveryDurationTicks;

  /// Human-readable summary shown in the history panel.
  final String narrative;
}

// ─────────────────────────────────────────────────────────────────────────────
// ActiveDisaster
// ─────────────────────────────────────────────────────────────────────────────

/// Phase duration constants in simulation ticks.
class _PhaseDurations {
  static const int warning = 3;
  static const int occurring = 2;
  static const int response = 4;

  static int recovery(DisasterSeverity severity) => switch (severity) {
        DisasterSeverity.minor => 8,
        DisasterSeverity.moderate => 12,
        DisasterSeverity.major => 16,
        DisasterSeverity.catastrophic => 20,
      };
}

/// The live state of an ongoing disaster.
class ActiveDisaster {
  ActiveDisaster({
    required this.id,
    required this.type,
    required this.severity,
    required this.epicenterX,
    required this.epicenterY,
    required this.radius,
    this.phase = DisasterPhase.warning,
    this.phaseTicks = 0,
    List<AffectedBuilding>? affectedBuildings,
    List<AffectedRoad>? affectedRoads,
    this.report,
    Set<Object>? fireTiles,
  })  : affectedBuildings = affectedBuildings ?? [],
        affectedRoads = affectedRoads ?? [],
        fireTiles = fireTiles ?? {};

  final String id;
  final DisasterType type;
  final DisasterSeverity severity;

  DisasterPhase phase;

  /// Grid column of the disaster epicentre.
  int epicenterX;

  /// Grid row of the disaster epicentre.
  int epicenterY;

  /// Affected radius in tiles (not used for heatwave).
  double radius;

  /// Ticks spent in the current phase.
  int phaseTicks;

  List<AffectedBuilding> affectedBuildings;
  List<AffectedRoad> affectedRoads;

  /// Available once the disaster reaches the [DisasterPhase.response] phase.
  DisasterReport? report;

  /// For fire disasters: the set of GridPoint-equivalent (x, y) tile positions
  /// currently burning. We store as `Set<(int, int)>` encoded as a plain Object
  /// set to avoid importing GridPoint here (models layer).
  /// The engine reads this directly as `Set<GridPoint>`.
  Set<Object> fireTiles;

  // ── Phase logic ────────────────────────────────────────────────────────────

  bool get isComplete => phase == DisasterPhase.complete;
  bool get isWarning => phase == DisasterPhase.warning;
  bool get isOccurring => phase == DisasterPhase.occurring;
  bool get isInResponse => phase == DisasterPhase.response;
  bool get isInRecovery => phase == DisasterPhase.recovery;

  /// Returns the duration limit for the current phase in ticks.
  int get _currentPhaseDuration => switch (phase) {
        DisasterPhase.warning => _PhaseDurations.warning,
        DisasterPhase.occurring => _PhaseDurations.occurring,
        DisasterPhase.response => _PhaseDurations.response,
        DisasterPhase.recovery => _PhaseDurations.recovery(severity),
        DisasterPhase.complete => 0,
      };

  /// Increments [phaseTicks] and advances to the next phase when the duration
  /// for the current phase has elapsed. Returns `true` if the phase changed.
  bool advance() {
    phaseTicks++;
    if (phaseTicks >= _currentPhaseDuration) {
      _nextPhase();
      return true;
    }
    return false;
  }

  void _nextPhase() {
    phaseTicks = 0;
    phase = switch (phase) {
      DisasterPhase.warning => DisasterPhase.occurring,
      DisasterPhase.occurring => DisasterPhase.response,
      DisasterPhase.response => DisasterPhase.recovery,
      DisasterPhase.recovery => DisasterPhase.complete,
      DisasterPhase.complete => DisasterPhase.complete,
    };
  }

  /// Human-readable status string for the UI.
  String get statusLabel => switch (phase) {
        DisasterPhase.warning => '⚠️ Warning',
        DisasterPhase.occurring => '🔴 Occurring',
        DisasterPhase.response => '🚨 Emergency Response',
        DisasterPhase.recovery => '🔧 Recovery',
        DisasterPhase.complete => '✅ Complete',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// DisasterNotification
// ─────────────────────────────────────────────────────────────────────────────

/// A UI alert pushed by the disaster engine.
class DisasterNotification {
  DisasterNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.phase,
    required this.timestamp,
    this.dismissed = false,
  });

  final String id;
  final DisasterType type;
  final String title;
  final String message;
  final DisasterPhase phase;
  final DateTime timestamp;
  bool dismissed;
}
