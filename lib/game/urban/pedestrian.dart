import 'package:flutter/material.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';
import 'package:city_builder_2040/game/urban/compass_direction.dart';

/// Archetypes of citizens walking in City Builder 2040.
enum PedestrianType {
  citizen('Citizen', 'citizen', 20.0),
  officeWorker('Office Worker', 'office_worker', 22.0),
  student('Student', 'student', 24.0),
  shopper('Shopper', 'shopper', 18.0),
  parkVisitor('Park Visitor', 'park_visitor', 19.0),
  constructionWorker('Construction Worker', 'construction_worker', 19.0);

  const PedestrianType(this.label, this.assetPrefix, this.defaultSpeed);

  final String label;
  final String assetPrefix;
  final double defaultSpeed;
}

/// Simulated citizen walking along sidewalks, plazas, and parks.
class Pedestrian {
  Pedestrian({
    required this.id,
    required this.type,
    required this.currentTile,
    required this.nextTile,
    required this.heading,
    double? initialProgress,
    this.sidewalkOffset = 11.0,
    this.originBuildingId,
    this.destinationBuildingId,
  })  : progress = initialProgress ?? 0.0,
        speed = type.defaultSpeed,
        worldPos = _computeWorldPos(currentTile, nextTile, heading, sidewalkOffset, initialProgress ?? 0.0);

  final String id;
  final PedestrianType type;

  /// Current tile.
  GridPoint currentTile;

  /// Target tile.
  GridPoint nextTile;

  /// Movement direction.
  CompassDirection heading;

  /// Traversal progress from [currentTile] to [nextTile] (0.0 to 1.0).
  double progress;

  /// Current interpolated world position.
  Offset worldPos;

  /// Walking speed in world pixels per second.
  double speed;

  /// Lateral offset from tile center to place pedestrian on sidewalk edge.
  final double sidewalkOffset;

  /// Stride animation timer in seconds.
  double walkAnimTime = 0.0;

  /// Current animation frame: 1, 2, or 3.
  int get animFrame {
    final t = (walkAnimTime % 0.36) / 0.36;
    if (t < 0.33) return 1;
    if (t < 0.66) return 2;
    return 3;
  }

  /// Pause/idle timer (seconds remaining).
  double idleTimer = 0.0;
  bool get isIdle => idleTimer > 0;

  /// Opacity for fading in upon exiting a building, or fading out upon entering.
  double opacity = 1.0;
  bool isEntering = false;
  bool isExiting = true;

  /// Planned pathway of tiles.
  List<GridPoint> path = [];

  final String? originBuildingId;
  final String? destinationBuildingId;

  int ageTicks = 0;
  bool isDespawned = false;

  /// Depth sorting key in isometric projection.
  double get depth => currentTile.col + currentTile.row + progress;

  static Offset _computeWorldPos(
    GridPoint from,
    GridPoint to,
    CompassDirection heading,
    double sidewalkOffset,
    double progress,
  ) {
    final startCenter = IsoProjection.tileCenter(from.col, from.row);
    final endCenter = IsoProjection.tileCenter(to.col, to.row);

    // Place on sidewalk by offsetting perpendicular to travel direction
    final offsetVec = heading.rightHandOffset * sidewalkOffset;

    final start = startCenter + offsetVec;
    final end = endCenter + offsetVec;

    return Offset.lerp(start, end, progress.clamp(0.0, 1.0))!;
  }

  /// Updates movement and animation strides.
  void updateMovement(double dt) {
    if (isDespawned) return;

    // Fade-in upon spawning
    if (isExiting) {
      opacity += dt * 3.0;
      if (opacity >= 1.0) {
        opacity = 1.0;
        isExiting = false;
      }
    }

    // Fade-out upon reaching destination
    if (isEntering) {
      opacity -= dt * 3.0;
      if (opacity <= 0.0) {
        opacity = 0.0;
        isDespawned = true;
        return;
      }
    }

    // Idle pause
    if (idleTimer > 0) {
      idleTimer -= dt;
      if (idleTimer < 0) idleTimer = 0;
      return;
    }

    walkAnimTime += dt;

    final startCenter = IsoProjection.tileCenter(currentTile.col, currentTile.row);
    final endCenter = IsoProjection.tileCenter(nextTile.col, nextTile.row);
    final segmentDist = (endCenter - startCenter).distance;

    if (segmentDist <= 0.001) {
      progress = 1.0;
    } else {
      progress += (speed * dt) / segmentDist;
    }

    worldPos = _computeWorldPos(currentTile, nextTile, heading, sidewalkOffset, progress);
  }

  /// Advances to next step on sidewalk or plaza.
  void advanceTo(GridPoint newNext) {
    currentTile = nextTile;
    nextTile = newNext;
    progress = 0.0;

    final newHeading = CompassDirection.fromGridDelta(currentTile, nextTile);
    if (newHeading != null) {
      heading = newHeading;
    }

    worldPos = _computeWorldPos(currentTile, nextTile, heading, sidewalkOffset, 0.0);
  }
}
