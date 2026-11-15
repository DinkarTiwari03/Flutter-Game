import 'dart:math' as math;
import 'dart:ui';

import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/game/components/tile_art.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';

/// Inclusive range of chunks (or tiles) covering part of the map.
typedef IndexRange = ({int minCol, int maxCol, int minRow, int maxRow});

/// Records the map into cached [Picture]s, one pair per square chunk of
/// tiles: a ground layer and a decoration layer.
///
/// Recording a chunk costs one pass over its tiles. After that, drawing it is
/// a single `drawPicture`, so panning and zooming over thousands of tiles
/// stays cheap. Chunks are recorded lazily the first time they scroll into
/// view and kept until [dispose].
class IsoMapRenderer {
  IsoMapRenderer(this.map);

  final GameMap map;

  static const _size = GameConstants.chunkSize;

  final Map<int, Picture> _ground = {};
  final Map<int, Picture> _decorations = {};

  int get chunkCols => (map.cols + _size - 1) ~/ _size;
  int get chunkRows => (map.rows + _size - 1) ~/ _size;

  /// Number of chunks recorded so far (exposed for tests and diagnostics).
  int get recordedChunkCount => _ground.length + _decorations.length;

  Picture groundChunk(int chunkCol, int chunkRow) {
    return _ground.putIfAbsent(
      chunkRow * chunkCols + chunkCol,
      () => _record(chunkCol, chunkRow, ground: true),
    );
  }

  Picture decorationChunk(int chunkCol, int chunkRow) {
    return _decorations.putIfAbsent(
      chunkRow * chunkCols + chunkCol,
      () => _record(chunkCol, chunkRow, ground: false),
    );
  }

  Picture _record(int chunkCol, int chunkRow, {required bool ground}) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final col0 = chunkCol * _size;
    final row0 = chunkRow * _size;
    final col1 = math.min(col0 + _size, map.cols);
    final row1 = math.min(row0 + _size, map.rows);

    for (var r = row0; r < row1; r++) {
      for (var c = col0; c < col1; c++) {
        if (ground) {
          TileArt.paintGround(canvas, map, c, r);
        } else {
          TileArt.paintDecoration(canvas, map, c, r);
        }
      }
    }
    return recorder.endRecording();
  }

  /// Tiles whose diamonds may intersect [world], clamped to the map. Returns
  /// `null` when the rectangle lies entirely outside the map.
  ///
  /// The screen-to-grid transform is linear, so the grid-space bounds of a
  /// rectangle are given by its four corners.
  IndexRange? visibleTiles(Rect world, {double padding = 0}) {
    final rect = world.inflate(padding);
    final corners = [
      IsoProjection.worldToGrid(rect.topLeft),
      IsoProjection.worldToGrid(rect.topRight),
      IsoProjection.worldToGrid(rect.bottomLeft),
      IsoProjection.worldToGrid(rect.bottomRight),
    ];
    final minCol = corners.map((p) => p.col).reduce(math.min);
    final maxCol = corners.map((p) => p.col).reduce(math.max);
    final minRow = corners.map((p) => p.row).reduce(math.min);
    final maxRow = corners.map((p) => p.row).reduce(math.max);

    final range = (
      minCol: math.max(minCol, 0),
      maxCol: math.min(maxCol, map.cols - 1),
      minRow: math.max(minRow, 0),
      maxRow: math.min(maxRow, map.rows - 1),
    );
    if (range.minCol > range.maxCol || range.minRow > range.maxRow) return null;
    return range;
  }

  /// Chunks covering [tiles].
  IndexRange chunksFor(IndexRange tiles) {
    return (
      minCol: tiles.minCol ~/ _size,
      maxCol: tiles.maxCol ~/ _size,
      minRow: tiles.minRow ~/ _size,
      maxRow: tiles.maxRow ~/ _size,
    );
  }

  void dispose() {
    for (final picture in _ground.values) {
      picture.dispose();
    }
    for (final picture in _decorations.values) {
      picture.dispose();
    }
    _ground.clear();
    _decorations.clear();
  }
}
