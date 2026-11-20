import 'package:flutter/material.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';
import 'package:city_builder_2040/game/urban/compass_direction.dart';
import 'package:city_builder_2040/models/traffic/traffic_models.dart';

/// Types of vehicles simulated in City Builder 2040.
enum VehicleType {
  // Personal transport (Cars, bikes)
  sedan('Sedan', VehicleCategory.personal, 48.0, 5.0),
  sedanSports('Sports Car', VehicleCategory.personal, 56.0, 5.0),
  suv('SUV', VehicleCategory.personal, 46.0, 5.5),
  motorcycle('Motorcycle', VehicleCategory.personal, 52.0, 3.5),
  bicycle('Bicycle', VehicleCategory.personal, 26.0, 6.5),

  // Public transit
  bus('City Bus', VehicleCategory.publicTransport, 38.0, 4.0),
  taxi('Taxi', VehicleCategory.publicTransport, 50.0, 5.0),

  // Commercial & Logistics
  delivery('Delivery Van', VehicleCategory.commercial, 42.0, 5.0),
  deliveryFlat('Flatbed Delivery', VehicleCategory.commercial, 40.0, 5.0),
  van('Utility Van', VehicleCategory.commercial, 44.0, 5.0),
  truckCargo('Cargo Truck', VehicleCategory.commercial, 34.0, 4.5),
  truckFlat('Flatbed Truck', VehicleCategory.commercial, 34.0, 4.5),
  garbageTruck('City Sanitation', VehicleCategory.commercial, 32.0, 4.5),

  // Emergency & Municipal
  police('Police Cruiser', VehicleCategory.emergency, 64.0, 5.0),
  ambulance('Ambulance', VehicleCategory.emergency, 62.0, 5.0),
  firetruck('Fire Engine', VehicleCategory.emergency, 54.0, 4.5),

  // Construction
  tractor('Bulldozer', VehicleCategory.construction, 28.0, 4.0),
  excavator('Excavator', VehicleCategory.construction, 26.0, 4.0),
  cementMixer('Cement Mixer', VehicleCategory.construction, 30.0, 4.0);

  const VehicleType(
    this.label,
    this.category,
    this.defaultSpeed,
    this.laneOffset,
  );

  final String label;
  final VehicleCategory category;

  /// Cruising speed in world pixels per second.
  final double defaultSpeed;

  /// Lateral lane offset in world pixels to simulate right-hand driving.
  final double laneOffset;

  /// Asset file name prefix in `assets/vehicles/`.
  String get assetPrefix => switch (this) {
        VehicleType.sedan => 'sedan',
        VehicleType.sedanSports => 'sedan_sports',
        VehicleType.suv => 'suv',
        VehicleType.motorcycle => 'motorcycle',
        VehicleType.bicycle => 'bicycle',
        VehicleType.bus => 'bus',
        VehicleType.taxi => 'taxi',
        VehicleType.delivery => 'delivery',
        VehicleType.deliveryFlat => 'delivery_flat',
        VehicleType.van => 'van',
        VehicleType.truckCargo => 'truck_cargo',
        VehicleType.truckFlat => 'truck_flat',
        VehicleType.garbageTruck => 'garbage_truck',
        VehicleType.police => 'police',
        VehicleType.ambulance => 'ambulance',
        VehicleType.firetruck => 'firetruck',
        VehicleType.tractor => 'tractor',
        VehicleType.excavator => 'excavator',
        VehicleType.cementMixer => 'cement_mixer',
      };
}

/// Broad category of urban vehicular traffic.
enum VehicleCategory {
  personal,
  publicTransport,
  commercial,
  construction,
  emergency;

  bool get isEmergency => this == emergency;
  bool get isConstruction => this == construction;
  bool get isCommercial => this == commercial;
  bool get isPublicTransit => this == publicTransport;
}

/// Simulated moving vehicle on the city road network.
class Vehicle {
  Vehicle({
    required this.id,
    required this.type,
    required this.currentTile,
    required this.nextTile,
    required this.heading,
    double? initialProgress,
    this.originBuildingId,
    this.destinationBuildingId,
    this.destinationTile,
    List<GridPoint>? initialRoute,
  })  : progress = initialProgress ?? 0.0,
        baseSpeed = type.defaultSpeed,
        currentSpeed = type.defaultSpeed,
        worldPos = _computeWorldPos(currentTile, nextTile, heading, type.laneOffset, initialProgress ?? 0.0) {
    if (initialRoute != null && initialRoute.isNotEmpty) {
      path = List.from(initialRoute);
    }
  }

  final String id;
  final VehicleType type;

  /// Current tile origin of movement segment.
  GridPoint currentTile;

  /// Target tile destination of movement segment.
  GridPoint nextTile;

  /// Current compass heading.
  CompassDirection heading;

  /// Traversal progress from [currentTile] to [nextTile] (0.0 to 1.0).
  double progress;

  /// Current interpolated 2.5D position in world pixel space.
  Offset worldPos;

  /// Standard base cruising speed (world px/sec).
  double baseSpeed;

  /// Current effective speed (decreases when braking, congested, or waiting).
  double currentSpeed;

  /// Target speed calculated from local congestion and road tier limit.
  double targetSpeed = 48.0;

  /// Pause timer when waiting at an intersection, bus stop, or stopped ahead.
  double waitTimer = 0.0;

  /// Whether vehicle is currently waiting.
  bool get isWaiting => waitTimer > 0;

  /// Whether vehicle is stopped completely due to traffic stoppage ahead.
  bool isBlocked = false;

  /// Associated source building (e.g. hospital, factory, residential).
  final String? originBuildingId;

  /// Associated target destination building.
  final String? destinationBuildingId;

  /// Target ultimate destination tile.
  GridPoint? destinationTile;

  /// Path of future road tiles to traverse.
  List<GridPoint> path = [];

  /// Current waypoint index along [path].
  int pathIndex = 0;

  /// Whether vehicle is making a return journey to its origin.
  bool isReturning = false;

  /// Passenger load for public transit buses.
  int passengerCount = 0;

  /// Emergency vehicle siren pulse cycle.
  double sirenTimer = 0.0;

  /// Total active ticks.
  int ageTicks = 0;

  /// Flagged when vehicle reaches final destination or despawn limit.
  bool isDespawned = false;

  /// Current local traffic condition this vehicle is experiencing.
  TrafficCondition localCondition = TrafficCondition.freeFlow;

  bool get isEmergency => type.category.isEmergency;
  bool get isBus => type == VehicleType.bus;
  bool get hasActiveRoute => path.isNotEmpty && pathIndex < path.length;

  /// Depth sorting key in isometric projection: `(col + row)`.
  double get depth => currentTile.col + currentTile.row + progress;

  /// Assigns a planned journey route.
  void assignRoute(List<GridPoint> newRoute, {GridPoint? dest}) {
    path = List.from(newRoute);
    pathIndex = 0;
    if (dest != null) destinationTile = dest;
  }

  /// Calculates visual world position along the road with right-hand lane offset.
  static Offset _computeWorldPos(
    GridPoint from,
    GridPoint to,
    CompassDirection heading,
    double laneOffset,
    double progress,
  ) {
    final startCenter = IsoProjection.tileCenter(from.col, from.row);
    final endCenter = IsoProjection.tileCenter(to.col, to.row);

    // Apply right-hand lane offset perpendicular to travel direction
    final offsetVec = heading.rightHandOffset * laneOffset;

    final start = startCenter + offsetVec;
    final end = endCenter + offsetVec;

    return Offset.lerp(start, end, progress.clamp(0.0, 1.0))!;
  }

  /// Advances vehicle movement by [dt] seconds.
  void updateMovement(double dt) {
    if (isDespawned) return;

    if (isEmergency) {
      sirenTimer += dt * 4.0;
    }

    if (waitTimer > 0) {
      waitTimer -= dt;
      if (waitTimer < 0) waitTimer = 0;
      return;
    }

    if (isBlocked) {
      currentSpeed = 0.0;
      return;
    }

    // Segment distance in world coordinates
    final startCenter = IsoProjection.tileCenter(currentTile.col, currentTile.row);
    final endCenter = IsoProjection.tileCenter(nextTile.col, nextTile.row);
    final segmentDist = (endCenter - startCenter).distance;

    if (segmentDist <= 0.001) {
      progress = 1.0;
    } else {
      progress += (currentSpeed * dt) / segmentDist;
    }

    worldPos = _computeWorldPos(currentTile, nextTile, heading, type.laneOffset, progress);
  }

  /// Transitions movement to [newNext] road tile upon reaching [nextTile].
  void advanceTo(GridPoint newNext) {
    currentTile = nextTile;
    nextTile = newNext;
    progress = 0.0;

    final newHeading = CompassDirection.fromGridDelta(currentTile, nextTile);
    if (newHeading != null) {
      heading = newHeading;
    }

    worldPos = _computeWorldPos(currentTile, nextTile, heading, type.laneOffset, 0.0);
  }
}
