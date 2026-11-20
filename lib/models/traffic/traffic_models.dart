import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';

/// The four distinct traffic flow conditions defined in Phase 1.
enum TrafficCondition {
  freeFlow(
    label: 'Free Flow',
    description: 'Vehicles move normally at full speed.',
    color: Color(0xFF22C55E), // Green
    speedMultiplier: 1.0,
    pollutionPenalty: 0,
  ),
  moderate(
    label: 'Moderate',
    description: 'Slightly reduced speed with steady traffic.',
    color: Color(0xFFEAB308), // Yellow
    speedMultiplier: 0.75,
    pollutionPenalty: 1,
  ),
  heavy(
    label: 'Heavy',
    description: 'Significant congestion with noticeable delays.',
    color: Color(0xFFF97316), // Orange
    speedMultiplier: 0.45,
    pollutionPenalty: 3,
  ),
  gridlock(
    label: 'Gridlock',
    description: 'Traffic movement is severely restricted.',
    color: Color(0xFFEF4444), // Red
    speedMultiplier: 0.18,
    pollutionPenalty: 6,
  );

  const TrafficCondition({
    required this.label,
    required this.description,
    required this.color,
    required this.speedMultiplier,
    required this.pollutionPenalty,
  });

  final String label;
  final String description;
  final Color color;
  final double speedMultiplier;
  final int pollutionPenalty;

  /// Resolves condition from density load ratio (vehicleCount / capacity).
  static TrafficCondition fromLoadRatio(double ratio) {
    if (ratio >= 1.0) return TrafficCondition.gridlock;
    if (ratio >= 0.70) return TrafficCondition.heavy;
    if (ratio >= 0.38) return TrafficCondition.moderate;
    return TrafficCondition.freeFlow;
  }
}

/// Road classification tiers determining capacity, lanes, and speed limits.
enum RoadTier {
  small(
    level: 1,
    name: 'Small Road',
    description: 'Basic 2-lane asphalt road for residential and local access.',
    capacity: 4,
    speedLimit: 46.0,
    upgradeCost: 0,
    maintenanceCost: 1,
  ),
  medium(
    level: 2,
    name: 'Medium Avenue',
    description: '4-lane divided street with improved vehicle throughput.',
    capacity: 8,
    speedLimit: 58.0,
    upgradeCost: 50,
    maintenanceCost: 3,
  ),
  large(
    level: 3,
    name: 'Large Boulevard',
    description: '6-lane major arterial boulevard with turn bays and traffic signals.',
    capacity: 16,
    speedLimit: 72.0,
    upgradeCost: 120,
    maintenanceCost: 6,
  ),
  highway(
    level: 4,
    name: 'High-Capacity Expressway',
    description: 'Grade-separated high-speed expressway for rapid cross-city transit.',
    capacity: 32,
    speedLimit: 90.0,
    upgradeCost: 250,
    maintenanceCost: 12,
  );

  const RoadTier({
    required this.level,
    required this.name,
    required this.description,
    required this.capacity,
    required this.speedLimit,
    required this.upgradeCost,
    required this.maintenanceCost,
  });

  final int level;
  final String name;
  final String description;
  final int capacity;
  final double speedLimit;
  final int upgradeCost;
  final int maintenanceCost;

  static RoadTier fromLevel(int level) => switch (level) {
        1 => RoadTier.small,
        2 => RoadTier.medium,
        3 => RoadTier.large,
        4 => RoadTier.highway,
        _ => level > 4 ? RoadTier.highway : RoadTier.small,
      };
}

/// Traffic signal states for regulated intersections.
enum SignalState {
  horizontalGreen, // SE <-> NW flow green, SW <-> NE flow red
  yellowTransition, // Caution clearance
  verticalGreen, // SW <-> NE flow green, SE <-> NW flow red
}

/// Dynamic signal regulator at a road intersection.
class TrafficSignal {
  TrafficSignal({
    required this.tile,
    this.state = SignalState.horizontalGreen,
    this.timer = 0.0,
    this.phaseDuration = 5.5,
  });

  final GridPoint tile;
  SignalState state;
  double timer;
  final double phaseDuration;

  void update(double dt) {
    timer += dt;
    if (state == SignalState.yellowTransition) {
      if (timer >= 1.2) {
        timer = 0.0;
        state = SignalState.verticalGreen;
      }
    } else if (state == SignalState.horizontalGreen) {
      if (timer >= phaseDuration) {
        timer = 0.0;
        state = SignalState.yellowTransition;
      }
    } else if (state == SignalState.verticalGreen) {
      if (timer >= phaseDuration) {
        timer = 0.0;
        state = SignalState.horizontalGreen;
      }
    }
  }

  /// Whether movement aligned with [isEastWest] has right of way.
  bool canPass({required bool isEastWest}) {
    if (state == SignalState.yellowTransition) return false;
    return isEastWest
        ? state == SignalState.horizontalGreen
        : state == SignalState.verticalGreen;
  }
}

/// Statistical summary for a single road tile segment.
class TrafficSegmentStats {
  const TrafficSegmentStats({
    required this.tile,
    required this.tier,
    required this.vehicleCount,
    required this.condition,
    required this.averageSpeed,
    this.hasSignal = false,
    this.signalState,
  });

  final GridPoint tile;
  final RoadTier tier;
  final int vehicleCount;
  final TrafficCondition condition;
  final double averageSpeed;
  final bool hasSignal;
  final SignalState? signalState;

  double get loadRatio => (vehicleCount / tier.capacity).clamp(0.0, 3.0);
}

/// Actionable traffic notification alert.
class TrafficAlert {
  const TrafficAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.location,
    required this.timestamp,
    this.recommendedAction,
  });

  final String id;
  final String title;
  final String message;
  final TrafficCondition severity;
  final GridPoint location;
  final DateTime timestamp;
  final String? recommendedAction;
}

/// City-wide traffic metrics aggregated across the road network.
class TrafficMetrics {
  const TrafficMetrics({
    required this.totalActiveVehicles,
    required this.averageSpeed,
    required this.overallCongestionPercent,
    required this.condition,
    required this.hotspots,
    required this.publicTransitRidership,
    required this.trafficDemandReductionPercent,
    required this.economicLossPerHour,
    required this.alerts,
    required this.segmentStats,
  });

  factory TrafficMetrics.empty() => const TrafficMetrics(
        totalActiveVehicles: 0,
        averageSpeed: 48.0,
        overallCongestionPercent: 0,
        condition: TrafficCondition.freeFlow,
        hotspots: [],
        publicTransitRidership: 0,
        trafficDemandReductionPercent: 0,
        economicLossPerHour: 0,
        alerts: [],
        segmentStats: {},
      );

  final int totalActiveVehicles;
  final double averageSpeed;
  final int overallCongestionPercent;
  final TrafficCondition condition;
  final List<GridPoint> hotspots;
  final int publicTransitRidership;
  final int trafficDemandReductionPercent;
  final int economicLossPerHour;
  final List<TrafficAlert> alerts;
  final Map<GridPoint, TrafficSegmentStats> segmentStats;
}
