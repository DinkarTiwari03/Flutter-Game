import 'dart:ui';

import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';

/// Converts between grid coordinates and isometric world coordinates.
///
/// World space has its origin at the top corner of tile (0, 0). Tile (c, r)
/// has its top corner at
///
///     x = (c - r) * tileWidth / 2
///     y = (c + r) * tileHeight / 2
///
/// and occupies the diamond below that point. All camera maths happens in
/// world space; the camera maps world space to the screen.
abstract final class IsoProjection {
  static const tileWidth = GameConstants.tileWidth;
  static const tileHeight = GameConstants.tileHeight;
  static const halfWidth = tileWidth / 2;
  static const halfHeight = tileHeight / 2;

  /// Top corner of the tile's diamond.
  static Offset tileTop(int col, int row) =>
      Offset((col - row) * halfWidth, (col + row) * halfHeight);

  /// Center of the tile's diamond.
  static Offset tileCenter(int col, int row) =>
      Offset((col - row) * halfWidth, (col + row) * halfHeight + halfHeight);

  /// Fractional grid coordinates of a world position. (col + 0.5, row + 0.5)
  /// is the center of tile (col, row).
  static Offset worldToGridFraction(Offset world) {
    final u = world.dx / halfWidth;
    final v = world.dy / halfHeight;
    return Offset((v + u) / 2, (v - u) / 2);
  }

  /// The tile under a world position. May lie outside the map.
  static GridPoint worldToGrid(Offset world) {
    final fraction = worldToGridFraction(world);
    return GridPoint(fraction.dx.floor(), fraction.dy.floor());
  }

  /// The four corners of a tile's diamond: top, right, bottom, left.
  static List<Offset> tileCorners(int col, int row) {
    final top = tileTop(col, row);
    return [
      top,
      Offset(top.dx + halfWidth, top.dy + halfHeight),
      Offset(top.dx, top.dy + tileHeight),
      Offset(top.dx - halfWidth, top.dy + halfHeight),
    ];
  }

  /// Bounding rectangle of a whole [cols] x [rows] map in world space.
  static Rect mapBounds(int cols, int rows) {
    return Rect.fromLTRB(
      -rows * halfWidth,
      0,
      cols * halfWidth,
      (cols + rows) * halfHeight,
    );
  }
}
