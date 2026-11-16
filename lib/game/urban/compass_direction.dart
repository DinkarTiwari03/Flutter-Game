import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';

/// The four cardinal directions in the 2.5D isometric tile space.
///
/// In City Builder 2040's coordinate system:
/// - [ne]: -row (grid north-east, screen up-right)
/// - [nw]: -col (grid north-west, screen up-left)
/// - [se]: +col (grid south-east, screen down-right)
/// - [sw]: +row (grid south-west, screen down-left)
enum CompassDirection {
  ne('ne'),
  nw('nw'),
  se('se'),
  sw('sw');

  const CompassDirection(this.code);

  final String code;

  /// Returns the opposite direction.
  CompassDirection get opposite => switch (this) {
        CompassDirection.ne => CompassDirection.sw,
        CompassDirection.nw => CompassDirection.se,
        CompassDirection.se => CompassDirection.nw,
        CompassDirection.sw => CompassDirection.ne,
      };

  /// Grid coordinate delta when stepping 1 tile in this direction.
  GridPoint get gridDelta => switch (this) {
        CompassDirection.ne => const GridPoint(0, -1),
        CompassDirection.nw => const GridPoint(-1, 0),
        CompassDirection.se => const GridPoint(1, 0),
        CompassDirection.sw => const GridPoint(0, 1),
      };

  /// Normal unit vector pointing perpendicular to travel (to the right-hand side).
  /// Used for right-hand traffic lane offsets in isometric screen space.
  Offset get rightHandOffset => switch (this) {
        // Traveling NE (up-right): right side is SE (down-right)
        CompassDirection.ne => const Offset(0.894, 0.447),
        // Traveling NW (up-left): right side is NE (up-right)
        CompassDirection.nw => const Offset(0.894, -0.447),
        // Traveling SE (down-right): right side is SW (down-left)
        CompassDirection.se => const Offset(-0.894, 0.447),
        // Traveling SW (down-left): right side is NW (up-left)
        CompassDirection.sw => const Offset(-0.894, -0.447),
      };

  /// Computes the compass direction from [from] to an adjacent [to] grid tile.
  static CompassDirection? fromGridDelta(GridPoint from, GridPoint to) {
    final dCol = to.col - from.col;
    final dRow = to.row - from.row;

    if (dCol > 0 && dRow == 0) return CompassDirection.se;
    if (dCol < 0 && dRow == 0) return CompassDirection.nw;
    if (dRow > 0 && dCol == 0) return CompassDirection.sw;
    if (dRow < 0 && dCol == 0) return CompassDirection.ne;

    // Diagonal or non-adjacent fallback
    if (dCol.abs() >= dRow.abs()) {
      return dCol > 0 ? CompassDirection.se : CompassDirection.nw;
    } else {
      return dRow > 0 ? CompassDirection.sw : CompassDirection.ne;
    }
  }

  /// Estimates compass direction from a continuous movement vector.
  static CompassDirection fromVelocity(Offset velocity) {
    if (velocity.dx == 0 && velocity.dy == 0) return CompassDirection.se;
    final angle = math.atan2(velocity.dy, velocity.dx);
    // Screen coordinates:
    // angle ~ 0.46 rad (26.5 deg): SE
    // angle ~ 2.68 rad (153.5 deg): SW
    // angle ~ -2.68 rad (-153.5 deg): NW
    // angle ~ -0.46 rad (-26.5 deg): NE
    if (angle >= 0 && angle < math.pi / 2) {
      return CompassDirection.se;
    } else if (angle >= math.pi / 2) {
      return CompassDirection.sw;
    } else if (angle < -math.pi / 2) {
      return CompassDirection.nw;
    } else {
      return CompassDirection.ne;
    }
  }
}
