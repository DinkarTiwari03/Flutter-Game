import 'dart:math' as math;
import 'dart:typed_data';

import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/map_config.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';

/// Procedural terrain generator.
///
/// Fully deterministic: the same [MapConfig] always produces the same map on
/// every platform. It uses its own integer hash and value noise instead of
/// `dart:math`'s `Random`, whose sequence is not guaranteed to stay stable.
///
/// Layout: an island with a coastline, a river and lakes in the outer ring,
/// a protected flat core with a road grid and two avenues, and forests, bushes,
/// flowers and boulders scattered over the remaining land.
abstract final class MapGenerator {
  static const _roadSpacing = 6;
  static const _coreRadius = 0.62;

  static GameMap generate(MapConfig config) {
    final cols = config.cols;
    final rows = config.rows;
    final seed = config.seed & 0x7FFFFFFF;
    final types = Uint8List(cols * rows); // zero == TileType.grass
    final decorations = Uint8List(cols * rows); // zero == none

    int index(int c, int r) => r * cols + c;

    // 1. Water: island coast, river, lakes. The core is always dry land.
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_isWater(c, r, cols, rows, seed)) {
          types[index(c, r)] = TileType.water.index;
        }
      }
    }

    // 2. Sand along shores, with a noisy second ring.
    final sandTargets = <int>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (types[index(c, r)] == TileType.water.index) continue;
        if (_touchesWater(types, cols, rows, c, r, 1) ||
            (_touchesWater(types, cols, rows, c, r, 2) &&
                _noise(c * 0.35, r * 0.35, seed + 11) > 0.5)) {
          sandTargets.add(index(c, r));
        }
      }
    }
    for (final i in sandTargets) {
      types[i] = TileType.sand.index;
    }

    // 3. Roads: avenues through the center plus a grid in the core.
    _paintRoads(types, cols, rows);

    // 4. Decorations on open ground.
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = index(c, r);
        decorations[i] =
            _decorationFor(
              TileType.values[types[i]],
              c,
              r,
              cols,
              rows,
              seed,
            ).index;
      }
    }

    return GameMap(
      cols: cols,
      rows: rows,
      types: types,
      decorations: decorations,
      seed: config.seed,
    );
  }

  // --- terrain --------------------------------------------------------

  static double _coreDistance(int c, int r, int cols, int rows) {
    final nx = (c + 0.5 - cols / 2) / (cols / 2);
    final ny = (r + 0.5 - rows / 2) / (rows / 2);
    return math.sqrt(nx * nx + ny * ny);
  }

  static bool _isWater(int c, int r, int cols, int rows, int seed) {
    final d = _coreDistance(c, r, cols, rows);
    if (d < _coreRadius) return false;

    // Coastline: water near the map border, with a wobbly edge.
    final edge = math.min(math.min(c, r), math.min(cols - 1 - c, rows - 1 - r));
    final coast = 2 + _noise(c * 0.12, r * 0.12, seed + 7) * 5;
    if (edge < coast) return true;

    // River: thin band where a smooth noise field crosses 0.5.
    final river = _fbm(c * 0.045, r * 0.045, seed + 21);
    if ((river - 0.5).abs() < 0.026) return true;

    // Lakes: high spots of another noise field.
    final lake = _fbm(c * 0.07, r * 0.07, seed + 33);
    return lake > 0.68 && d > 0.7;
  }

  static bool _touchesWater(
    Uint8List types,
    int cols,
    int rows,
    int c,
    int r,
    int radius,
  ) {
    for (var dr = -radius; dr <= radius; dr++) {
      for (var dc = -radius; dc <= radius; dc++) {
        if (dc == 0 && dr == 0) continue;
        final nc = c + dc;
        final nr = r + dr;
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        if (types[nr * cols + nc] == TileType.water.index) return true;
      }
    }
    return false;
  }

  static void _paintRoads(Uint8List types, int cols, int rows) {
    final centerCol = cols ~/ 2;
    final centerRow = rows ~/ 2;
    final half = math.max(_roadSpacing, (math.min(cols, rows) * 0.2).round());

    void setRoad(int c, int r) {
      if (c < 0 || r < 0 || c >= cols || r >= rows) return;
      final i = r * cols + c;
      if (types[i] != TileType.water.index) types[i] = TileType.road.index;
    }

    // Grid inside the core square.
    for (var offset = -half; offset <= half; offset += _roadSpacing) {
      for (var along = -half; along <= half; along++) {
        setRoad(centerCol + offset, centerRow + along);
        setRoad(centerCol + along, centerRow + offset);
      }
    }

    // Avenues run from the center until they hit water or the border.
    for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      var c = centerCol;
      var r = centerRow;
      while (c >= 0 && r >= 0 && c < cols && r < rows) {
        if (types[r * cols + c] == TileType.water.index) break;
        types[r * cols + c] = TileType.road.index;
        c += dc;
        r += dr;
      }
    }
  }

  // --- decorations ----------------------------------------------------

  static TileDecoration _decorationFor(
    TileType type,
    int c,
    int r,
    int cols,
    int rows,
    int seed,
  ) {
    if (type == TileType.water || type == TileType.road) {
      return TileDecoration.none;
    }

    final roll = _rand01(c, r, seed + 101);
    final pick = _rand01(c, r, seed + 202);

    if (type == TileType.sand) {
      return roll < 0.05 ? TileDecoration.rock : TileDecoration.none;
    }

    final d = _coreDistance(c, r, cols, rows);
    final forest = _fbm(c * 0.09, r * 0.09, seed + 55);
    final inCore = d < _coreRadius * 0.8;

    final treeChance =
        inCore
            ? 0.03
            : forest > 0.55
            ? 0.5
            : 0.07;
    if (roll < treeChance) {
      return pick < 0.62 ? TileDecoration.tree : TileDecoration.pine;
    }
    final other = roll - treeChance;
    if (other < 0.04) return TileDecoration.bush;
    if (other < 0.075) return TileDecoration.flowers;
    if (other < 0.09) return TileDecoration.rock;
    return TileDecoration.none;
  }

  // --- noise ----------------------------------------------------------

  static int _hash(int x, int y, int seed) {
    var h = (x * 374761393 + y * 668265263 + seed * 1274126177) & 0xFFFFFFFF;
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
    h = h ^ (h >> 16);
    return h & 0x7FFFFFFF;
  }

  static double _rand01(int x, int y, int seed) =>
      _hash(x, y, seed) / 0x7FFFFFFF;

  /// Smooth value noise in [0, 1].
  static double _noise(double x, double y, int seed) {
    final xi = x.floor();
    final yi = y.floor();
    final tx = x - xi;
    final ty = y - yi;
    final sx = tx * tx * (3 - 2 * tx);
    final sy = ty * ty * (3 - 2 * ty);
    final a = _rand01(xi, yi, seed);
    final b = _rand01(xi + 1, yi, seed);
    final c = _rand01(xi, yi + 1, seed);
    final d = _rand01(xi + 1, yi + 1, seed);
    final top = a + (b - a) * sx;
    final bottom = c + (d - c) * sx;
    return top + (bottom - top) * sy;
  }

  /// Three octaves of value noise, normalised to [0, 1].
  static double _fbm(double x, double y, int seed) {
    var sum = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    var total = 0.0;
    for (var octave = 0; octave < 3; octave++) {
      sum +=
          _noise(x * frequency, y * frequency, seed + octave * 17) * amplitude;
      total += amplitude;
      amplitude /= 2;
      frequency *= 2;
    }
    return sum / total;
  }
}
