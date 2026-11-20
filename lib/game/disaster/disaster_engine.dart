import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:city_builder_2040/game/disaster/earthquake_disaster.dart';
import 'package:city_builder_2040/game/disaster/fire_disaster.dart';
import 'package:city_builder_2040/game/disaster/flood_disaster.dart';
import 'package:city_builder_2040/game/disaster/heatwave_disaster.dart';
import 'package:city_builder_2040/game/disaster/storm_disaster.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/disaster/disaster_models.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';

/// Centralized simulation engine governing disaster lifecycle, risk assessment,
/// damage calculation, emergency response, and post-disaster recovery.
class DisasterEngine extends ChangeNotifier {
  DisasterEngine({
    DisasterConfig? config,
    math.Random? random,
  })  : config = config ?? DisasterConfig(),
        _random = random ?? math.Random();

  DisasterConfig config;
  final math.Random _random;

  ActiveDisaster? _activeDisaster;
  ActiveDisaster? get activeDisaster => _activeDisaster;

  final List<DisasterReport> _history = [];
  List<DisasterReport> get history => List.unmodifiable(_history);

  final List<DisasterNotification> _notifications = [];
  List<DisasterNotification> get notifications =>
      List.unmodifiable(_notifications.where((n) => !n.dismissed));

  final Set<GridPoint> _blockedRoads = {};
  Set<GridPoint> get blockedRoads => Set.unmodifiable(_blockedRoads);

  double _tickTimer = 0.0;
  int _hoursSinceLastDisaster = 999;
  int _nextNotificationId = 1;

  // ───────────────────────────────────────────────────────────────────────────
  // Risk Assessment
  // ───────────────────────────────────────────────────────────────────────────

  /// Calculates dynamic risk multipliers (1.0 = base) for each disaster type.
  Map<DisasterType, double> assessRisk({
    required List<Building> buildings,
    required int population,
    required int pollution,
    required int happiness,
    required SimulationClock clock,
  }) {
    // 1. Fire risk: spikes with high industrial pollution and dense buildings
    int industrialCount = buildings.where((b) => b.typeId.contains('factor') || b.typeId.contains('industr')).length;
    double fireMult = 1.0 + (pollution / 50.0) + (industrialCount * 0.15);

    // 2. Flood risk: elevated during wet conditions or large cities with water fronts
    double floodMult = 1.0 + (pollution > 60 ? 0.5 : 0.0) + (buildings.length > 20 ? 0.3 : 0.0);

    // 3. Storm risk: seasonal variance (every 48 hours simulated season peak)
    double stormCycle = math.sin((clock.tickCount % 48) / 48.0 * 2 * math.pi).abs();
    double stormMult = 0.8 + (stormCycle * 1.5);

    // 4. Heatwave risk: diurnal daytime peak + summer temperature cycles
    bool isDay = clock.hour >= 11 && clock.hour <= 16;
    double heatMult = (isDay ? 1.6 : 0.5) + (pollution / 60.0);

    // 5. Earthquake risk: geological tectonic base + deep industrial drilling
    double earthquakeMult = 1.0 + (industrialCount * 0.08);

    return {
      DisasterType.earthquake: earthquakeMult.clamp(0.2, 4.0),
      DisasterType.fire: fireMult.clamp(0.2, 4.0),
      DisasterType.flood: floodMult.clamp(0.2, 4.0),
      DisasterType.storm: stormMult.clamp(0.2, 4.0),
      DisasterType.heatwave: heatMult.clamp(0.2, 4.0),
    };
  }

  /// Highest risk level among all disaster types.
  DisasterRiskLevel getOverallRisk(Map<DisasterType, double> risks) {
    double maxMult = risks.values.fold(0.0, math.max);
    return DisasterRiskLevel.fromMultiplier(maxMult);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Simulation Update Loop
  // ───────────────────────────────────────────────────────────────────────────

  /// Called on each simulation frame or discrete tick.
  void update(
    double dt, {
    required List<Building> buildings,
    required Set<GridPoint> roadTiles,
    required int population,
    required int pollution,
    required int happiness,
    required int healthcareRating,
    required SimulationClock clock,
  }) {
    _tickTimer += dt;
    // Advance simulation hour ticks (~1.0s or clock advances)
    if (_tickTimer >= 1.0) {
      _tickTimer = 0.0;
      _onSimHour(
        buildings: buildings,
        roadTiles: roadTiles,
        population: population,
        pollution: pollution,
        happiness: happiness,
        healthcareRating: healthcareRating,
        clock: clock,
      );
    }
  }

  void _onSimHour({
    required List<Building> buildings,
    required Set<GridPoint> roadTiles,
    required int population,
    required int pollution,
    required int happiness,
    required int healthcareRating,
    required SimulationClock clock,
  }) {
    _hoursSinceLastDisaster++;

    // 1. Advance existing active disaster lifecycle if any
    if (_activeDisaster != null) {
      _advanceActiveDisaster(
        buildings: buildings,
        roadTiles: roadTiles,
        population: population,
        healthcareRating: healthcareRating,
      );
      notifyListeners();
      return;
    }

    // 2. Do not spawn natural disasters in early empty towns or cooldown
    if (buildings.length < 4 || population < 15) return;
    if (_hoursSinceLastDisaster < config.minHoursBetweenDisasters) return;

    // 3. Roll probabilities with risk assessment
    final risks = assessRisk(
      buildings: buildings,
      population: population,
      pollution: pollution,
      happiness: happiness,
      clock: clock,
    );

    for (final type in DisasterType.values) {
      final base = config.baseProb(type);
      final mult = risks[type] ?? 1.0;
      final effectiveChance = base * mult;

      if (_random.nextDouble() < effectiveChance) {
        _startDisaster(
          type: type,
          buildings: buildings,
          roadTiles: roadTiles,
        );
        break;
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Disaster Lifecycle Progression
  // ───────────────────────────────────────────────────────────────────────────

  void _startDisaster({
    required DisasterType type,
    required List<Building> buildings,
    required Set<GridPoint> roadTiles,
    DisasterSeverity? forcedSeverity,
    int? forcedX,
    int? forcedY,
  }) {
    final severity = forcedSeverity ?? _randomSeverity();

    // Select epicenter
    int eX = 10;
    int eY = 10;
    if (forcedX != null && forcedY != null) {
      eX = forcedX;
      eY = forcedY;
    } else if (buildings.isNotEmpty) {
      final target = buildings[_random.nextInt(buildings.length)];
      eX = target.x;
      eY = target.y;
    }

    double radius = switch (type) {
      DisasterType.earthquake => EarthquakeDisaster.getRadius(severity),
      DisasterType.fire => 4.0 * severity.intensityFactor,
      DisasterType.flood => FloodDisaster.getRadius(severity),
      DisasterType.storm => StormDisaster.getRadius(severity),
      DisasterType.heatwave => 0.0,
    };

    final disaster = ActiveDisaster(
      id: 'disaster_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      severity: severity,
      epicenterX: eX,
      epicenterY: eY,
      radius: radius,
      phase: DisasterPhase.warning,
    );

    // Initial burning tile for fire
    if (type == DisasterType.fire) {
      disaster.fireTiles.add(GridPoint(eX, eY));
    }

    _activeDisaster = disaster;
    _hoursSinceLastDisaster = 0;

    // Push warning notification
    final warnMsg = switch (type) {
      DisasterType.earthquake => EarthquakeDisaster.warningMessage(severity),
      DisasterType.fire => FireDisaster.warningMessage(severity),
      DisasterType.flood => FloodDisaster.warningMessage(severity),
      DisasterType.storm => StormDisaster.warningMessage(severity),
      DisasterType.heatwave => HeatwaveDisaster.warningMessage(severity),
    };

    _addNotification(
      type: type,
      title: '${severity.label} ${type.label} Warning',
      message: warnMsg,
      phase: DisasterPhase.warning,
    );

    notifyListeners();
  }

  void _advanceActiveDisaster({
    required List<Building> buildings,
    required Set<GridPoint> roadTiles,
    required int population,
    required int healthcareRating,
  }) {
    final d = _activeDisaster;
    if (d == null) return;

    final phaseChanged = d.advance();
    if (!phaseChanged) {
      // Mid-phase progression (e.g. fire spreading during occurring phase)
      if (d.isOccurring && d.type == DisasterType.fire) {
        final currentFirePoints = d.fireTiles.cast<GridPoint>().toSet();
        final buildingPoints = buildings.map((b) => GridPoint(b.x, b.y)).toSet();
        final newFire = FireDisaster.spreadFire(
          currentFireTiles: currentFirePoints,
          severity: d.severity,
          buildingTiles: buildingPoints,
          random: _random,
        );
        d.fireTiles.addAll(newFire);
      }
      return;
    }

    // Phase transition actions
    switch (d.phase) {
      case DisasterPhase.occurring:
        _onEnterOccurring(d, buildings, roadTiles, population, healthcareRating);
        break;

      case DisasterPhase.response:
        _onEnterResponse(d);
        break;

      case DisasterPhase.recovery:
        _onEnterRecovery(d);
        break;

      case DisasterPhase.complete:
        _onCompleteDisaster(d);
        break;

      case DisasterPhase.warning:
        break;
    }
  }

  void _onEnterOccurring(
    ActiveDisaster d,
    List<Building> buildings,
    Set<GridPoint> roadTiles,
    int population,
    int healthcareRating,
  ) {
    _addNotification(
      type: d.type,
      title: '${d.type.label} in Progress!',
      message: 'Active emergency! Impact felt at (${d.epicenterX}, ${d.epicenterY}). Emergency units deploying.',
      phase: DisasterPhase.occurring,
    );

    // Compute damage
    switch (d.type) {
      case DisasterType.earthquake:
        final res = EarthquakeDisaster.calculateDamage(
          epicenterX: d.epicenterX,
          epicenterY: d.epicenterY,
          severity: d.severity,
          buildings: buildings,
          roadTiles: roadTiles,
          random: _random,
        );
        d.affectedBuildings = res.buildings;
        d.affectedRoads = res.blockedRoads
            .map((pt) => AffectedRoad(x: pt.col, y: pt.row, isBlocked: true, damagePercent: 60.0))
            .toList();
        _blockedRoads.addAll(res.blockedRoads);
        d.report = DisasterReport(
          id: 'rep_${d.id}',
          type: d.type,
          severity: d.severity,
          occurredAt: DateTime.now(),
          buildingsDamaged: res.buildings.length,
          buildingsDestroyed: res.buildings.where((b) => b.isDestroyed).length,
          roadsBlocked: res.blockedRoads.length,
          coinsLost: res.coinsLost,
          happinessLost: res.happinessLost,
          recoveryDurationTicks: 12,
          narrative: EarthquakeDisaster.generateNarrative(res.buildings.length, res.blockedRoads.length, d.severity),
        );
        break;

      case DisasterType.fire:
        final firePoints = d.fireTiles.cast<GridPoint>().toSet();
        final res = FireDisaster.calculateDamage(
          fireTiles: firePoints,
          buildings: buildings,
          roadTiles: roadTiles,
          severity: d.severity,
          random: _random,
        );
        d.affectedBuildings = res.buildings;
        d.affectedRoads = res.blockedRoads
            .map((pt) => AffectedRoad(x: pt.col, y: pt.row, isBlocked: true, damagePercent: 80.0))
            .toList();
        _blockedRoads.addAll(res.blockedRoads);
        d.report = DisasterReport(
          id: 'rep_${d.id}',
          type: d.type,
          severity: d.severity,
          occurredAt: DateTime.now(),
          buildingsDamaged: res.buildings.length,
          buildingsDestroyed: res.buildings.where((b) => b.isDestroyed).length,
          roadsBlocked: res.blockedRoads.length,
          coinsLost: res.coinsLost,
          happinessLost: res.happinessLost,
          recoveryDurationTicks: 14,
          narrative: FireDisaster.generateNarrative(res.buildings.length, res.blockedRoads.length, d.severity),
        );
        break;

      case DisasterType.flood:
        final res = FloodDisaster.calculateDamage(
          epicenterX: d.epicenterX,
          epicenterY: d.epicenterY,
          severity: d.severity,
          buildings: buildings,
          roadTiles: roadTiles,
          random: _random,
        );
        d.affectedBuildings = res.buildings;
        d.affectedRoads = res.blockedRoads
            .map((pt) => AffectedRoad(x: pt.col, y: pt.row, isBlocked: true, damagePercent: 50.0))
            .toList();
        _blockedRoads.addAll(res.blockedRoads);
        d.report = DisasterReport(
          id: 'rep_${d.id}',
          type: d.type,
          severity: d.severity,
          occurredAt: DateTime.now(),
          buildingsDamaged: res.buildings.length,
          buildingsDestroyed: 0,
          roadsBlocked: res.blockedRoads.length,
          coinsLost: res.coinsLost,
          happinessLost: res.happinessLost,
          recoveryDurationTicks: 16,
          narrative: FloodDisaster.generateNarrative(res.buildings.length, res.blockedRoads.length, d.severity),
        );
        break;

      case DisasterType.storm:
        final res = StormDisaster.calculateDamage(
          epicenterX: d.epicenterX,
          epicenterY: d.epicenterY,
          severity: d.severity,
          buildings: buildings,
          roadTiles: roadTiles,
          random: _random,
        );
        d.affectedBuildings = res.buildings;
        d.affectedRoads = res.blockedRoads
            .map((pt) => AffectedRoad(x: pt.col, y: pt.row, isBlocked: true, damagePercent: 40.0))
            .toList();
        _blockedRoads.addAll(res.blockedRoads);
        d.report = DisasterReport(
          id: 'rep_${d.id}',
          type: d.type,
          severity: d.severity,
          occurredAt: DateTime.now(),
          buildingsDamaged: res.buildings.length,
          buildingsDestroyed: 0,
          roadsBlocked: res.blockedRoads.length,
          coinsLost: res.coinsLost,
          happinessLost: res.happinessLost,
          recoveryDurationTicks: 10,
          narrative: StormDisaster.generateNarrative(res.buildings.length, res.blockedRoads.length, d.severity),
        );
        break;

      case DisasterType.heatwave:
        final res = HeatwaveDisaster.calculateDamage(
          severity: d.severity,
          population: population,
          healthcareRating: healthcareRating,
        );
        d.affectedBuildings = res.buildings;
        d.affectedRoads = [];
        d.report = DisasterReport(
          id: 'rep_${d.id}',
          type: d.type,
          severity: d.severity,
          occurredAt: DateTime.now(),
          buildingsDamaged: 0,
          buildingsDestroyed: 0,
          roadsBlocked: 0,
          coinsLost: res.coinsLost,
          happinessLost: res.happinessLost,
          recoveryDurationTicks: 8,
          narrative: HeatwaveDisaster.generateNarrative(res.happinessLost, d.severity),
        );
        break;
    }
  }

  void _onEnterResponse(ActiveDisaster d) {
    _addNotification(
      type: d.type,
      title: 'Emergency Response Mobilized',
      message: 'First responders on scene. ${d.report?.narrative ?? ""}',
      phase: DisasterPhase.response,
    );
  }

  void _onEnterRecovery(ActiveDisaster d) {
    _addNotification(
      type: d.type,
      title: 'City Reconstruction Underway',
      message: 'Repair crews dispatched. Blocked transit corridors are being cleared.',
      phase: DisasterPhase.recovery,
    );
  }

  void _onCompleteDisaster(ActiveDisaster d) {
    if (d.report != null) {
      _history.insert(0, d.report!);
      if (_history.length > 20) _history.removeLast();
    }

    // Clear blocked roads
    _blockedRoads.clear();

    _addNotification(
      type: d.type,
      title: '${d.type.label} Recovery Complete',
      message: 'All transit routes reopened and infrastructure restored to normal operation.',
      phase: DisasterPhase.complete,
    );

    _activeDisaster = null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Manual Trigger & Testing Tools
  // ───────────────────────────────────────────────────────────────────────────

  /// Triggers a disaster on command (for scenario / sandbox testing).
  void triggerDisaster(
    DisasterType type, {
    DisasterSeverity? severity,
    int? epicenterX,
    int? epicenterY,
    required List<Building> buildings,
    required Set<GridPoint> roadTiles,
  }) {
    if (_activeDisaster != null) {
      // Force finish current disaster to accommodate testing
      _blockedRoads.clear();
      _activeDisaster = null;
    }

    _startDisaster(
      type: type,
      buildings: buildings,
      roadTiles: roadTiles,
      forcedSeverity: severity ?? DisasterSeverity.moderate,
      forcedX: epicenterX,
      forcedY: epicenterY,
    );
    notifyListeners();
  }

  void dismissNotification(String id) {
    for (final n in _notifications) {
      if (n.id == id) {
        n.dismissed = true;
        break;
      }
    }
    notifyListeners();
  }

  void clearAllNotifications() {
    for (final n in _notifications) {
      n.dismissed = true;
    }
    notifyListeners();
  }

  void _addNotification({
    required DisasterType type,
    required String title,
    required String message,
    required DisasterPhase phase,
  }) {
    _notifications.insert(
      0,
      DisasterNotification(
        id: 'notif_${_nextNotificationId++}',
        type: type,
        title: title,
        message: message,
        phase: phase,
        timestamp: DateTime.now(),
      ),
    );
    if (_notifications.length > 30) _notifications.removeLast();
  }

  DisasterSeverity _randomSeverity() {
    final roll = _random.nextDouble();
    if (roll < 0.50) return DisasterSeverity.minor;
    if (roll < 0.80) return DisasterSeverity.moderate;
    if (roll < 0.95) return DisasterSeverity.major;
    return DisasterSeverity.catastrophic;
  }
}
