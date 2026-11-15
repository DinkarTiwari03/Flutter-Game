import 'dart:typed_data';

import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';

/// Rectangular grid of tiles.
///
/// Tiles are stored in compact byte arrays (one byte for the ground type and
/// one for the decoration) so large maps stay small and fast to scan. The
/// map is read-only after creation; building and editing arrive in a later
/// phase and will add copy-on-write updates.
class GameMap {
  GameMap({
    required this.cols,
    required this.rows,
    required Uint8List types,
    required Uint8List decorations,
    this.seed = 0,
  }) : assert(cols > 0 && rows > 0),
       assert(types.length == cols * rows),
       assert(decorations.length == cols * rows),
       _types = types,
       _decorations = decorations;

  final int cols;
  final int rows;

  /// Seed the map was generated from (0 for hand-built maps).
  final int seed;

  final Uint8List _types;
  final Uint8List _decorations;

  int get tileCount => cols * rows;

  bool inBounds(int col, int row) =>
      col >= 0 && col < cols && row >= 0 && row < rows;

  bool contains(GridPoint point) => inBounds(point.col, point.row);

  int _index(int col, int row) => row * cols + col;

  TileType typeAt(int col, int row) =>
      TileType.values[_types[_index(col, row)]];

  TileDecoration decorationAt(int col, int row) =>
      TileDecoration.values[_decorations[_index(col, row)]];

  /// Raw ground type index, for hot paths that avoid enum lookups.
  int typeIndexAt(int col, int row) => _types[_index(col, row)];

  int decorationIndexAt(int col, int row) => _decorations[_index(col, row)];

  /// Number of tiles of [type] (used for statistics and tests).
  int countOf(TileType type) {
    var count = 0;
    for (final value in _types) {
      if (value == type.index) count++;
    }
    return count;
  }
}
