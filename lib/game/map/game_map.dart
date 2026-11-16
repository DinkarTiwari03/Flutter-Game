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

  /// Creates a larger map by copying all tiles of this map into the top-left
  /// corner of a new grid of [newCols] × [newRows].
  ///
  /// Tiles outside the original bounds are filled with [fillType] /
  /// [fillDecoration] (defaults to water, so the expansion looks like open
  /// ocean until the terrain generator fills it).
  ///
  /// Call [MapGenerator.generate] with the same [seed] on the larger
  /// [MapConfig] to get a fully-generated expanded map, then merge via
  /// [mergeExpanded] to overwrite only the new tiles while preserving
  /// existing ones.
  GameMap expanded({
    required int newCols,
    required int newRows,
    TileType fillType = TileType.water,
    TileDecoration fillDecoration = TileDecoration.none,
  }) {
    assert(newCols >= cols && newRows >= rows,
        'expanded() cannot shrink the map');
    final newTypes = Uint8List(newCols * newRows)
      ..fillRange(0, newCols * newRows, fillType.index);
    final newDecorations = Uint8List(newCols * newRows)
      ..fillRange(0, newCols * newRows, fillDecoration.index);

    // Copy existing rows into the new, wider grid.
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final dst = r * newCols + c;
        newTypes[dst] = _types[_index(c, r)];
        newDecorations[dst] = _decorations[_index(c, r)];
      }
    }

    return GameMap(
      cols: newCols,
      rows: newRows,
      types: newTypes,
      decorations: newDecorations,
      seed: seed,
    );
  }

  /// Merges tile data from [generated] (a larger map produced by
  /// [MapGenerator.generate]) into this map, but only for tiles outside the
  /// original [originalCols] × [originalRows] region.
  ///
  /// The result preserves everything the player has built while adding
  /// deterministically-generated terrain in the new area.
  GameMap mergeExpanded(GameMap generated, {
    required int originalCols,
    required int originalRows,
  }) {
    assert(generated.cols == cols && generated.rows == rows);
    final mergedTypes = Uint8List.fromList(_types);
    final mergedDecorations = Uint8List.fromList(_decorations);

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Keep original tiles; fill only new area from generated map.
        if (c < originalCols && r < originalRows) continue;
        final src = r * generated.cols + c;
        final dst = _index(c, r);
        mergedTypes[dst] = generated._types[src];
        mergedDecorations[dst] = generated._decorations[src];
      }
    }

    return GameMap(
      cols: cols,
      rows: rows,
      types: mergedTypes,
      decorations: mergedDecorations,
      seed: seed,
    );
  }
}
