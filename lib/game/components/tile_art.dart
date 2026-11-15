import 'dart:ui';

import 'package:city_builder_2040/core/theme/map_colors.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';

/// Draws individual tiles and decorations in world space.
///
/// Used only while recording chunk pictures (see `IsoMapRenderer`), so these
/// routines may be a little detailed: they run once per chunk, not per frame.
abstract final class TileArt {
  /// Height of the dirt slab drawn under the map's front edges.
  static const slabDepth = 12.0;

  static const _hw = IsoProjection.halfWidth;
  static const _hh = IsoProjection.halfHeight;

  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _line =
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

  // --- ground ---------------------------------------------------------

  static void paintGround(Canvas canvas, GameMap map, int c, int r) {
    final type = map.typeAt(c, r);
    final h = _hash(c, r, 1);
    final top = IsoProjection.tileTop(c, r);
    final center = Offset(top.dx, top.dy + _hh);

    final base = switch (type) {
      TileType.grass => MapColors.grassShades[h % MapColors.grassShades.length],
      TileType.sand => MapColors.sandShades[h % MapColors.sandShades.length],
      TileType.water => MapColors.waterShades[h % MapColors.waterShades.length],
      TileType.road => MapColors.asphalt,
    };

    _fill.color = base;
    canvas.drawPath(_diamond(top, bleed: 0.6), _fill);

    switch (type) {
      case TileType.grass:
        _paintGrassDetail(canvas, center, h);
      case TileType.sand:
        _paintSandDetail(canvas, center, h);
      case TileType.water:
        _paintWaterDetail(canvas, map, c, r, center, h);
      case TileType.road:
        _paintRoadDetail(canvas, map, c, r, center);
    }

    _paintSlab(canvas, map, c, r, top, base);
  }

  static void _paintGrassDetail(Canvas canvas, Offset center, int h) {
    _line
      ..color = MapColors.grassTuft
      ..strokeWidth = 1.3;
    for (var i = 0; i < 3; i++) {
      final x = center.dx + (_unit(h, 10 + i) - 0.5) * 30;
      final y = center.dy + (_unit(h, 20 + i) - 0.5) * 12;
      canvas.drawLine(Offset(x, y), Offset(x - 1.5, y - 3.5), _line);
      canvas.drawLine(Offset(x, y), Offset(x + 1.5, y - 3), _line);
    }
  }

  static void _paintSandDetail(Canvas canvas, Offset center, int h) {
    _fill.color = MapColors.sandSpeck;
    for (var i = 0; i < 3; i++) {
      final x = center.dx + (_unit(h, 30 + i) - 0.5) * 28;
      final y = center.dy + (_unit(h, 40 + i) - 0.5) * 11;
      canvas.drawCircle(Offset(x, y), 0.9, _fill);
    }
  }

  static void _paintWaterDetail(
    Canvas canvas,
    GameMap map,
    int c,
    int r,
    Offset center,
    int h,
  ) {
    // Small wave marks.
    _line
      ..color = MapColors.waterWave
      ..strokeWidth = 1.4;
    for (var i = 0; i < 2; i++) {
      final x = center.dx + (_unit(h, 50 + i) - 0.5) * 24;
      final y = center.dy + (_unit(h, 60 + i) - 0.5) * 9;
      canvas.drawLine(Offset(x - 4, y), Offset(x + 4, y), _line);
    }

    // Foam where water meets land.
    _line
      ..color = MapColors.waterFoam
      ..strokeWidth = 2.2;
    final corners = IsoProjection.tileCorners(c, r);
    final water = TileType.water.index;
    for (var edge = 0; edge < 4; edge++) {
      final n = _neighborIndex(map, c, r, edge);
      if (n == -1 || n == water) continue;
      _drawInsetEdge(canvas, corners, edge, center, 0.1);
    }
  }

  static void _paintRoadDetail(
    Canvas canvas,
    GameMap map,
    int c,
    int r,
    Offset center,
  ) {
    final corners = IsoProjection.tileCorners(c, r);
    final road = TileType.road.index;

    // Kerbs on edges that face non-road tiles.
    _line
      ..color = MapColors.kerb
      ..strokeWidth = 2.4;
    var connections = 0;
    for (var edge = 0; edge < 4; edge++) {
      final n = _neighborIndex(map, c, r, edge);
      if (n == road) {
        connections++;
      } else {
        _drawInsetEdge(canvas, corners, edge, center, 0.1);
      }
    }

    // Lane markings toward connected neighbours.
    _line
      ..color = MapColors.laneMarking
      ..strokeWidth = 1.6;
    if (connections == 0) {
      _fill.color = MapColors.laneMarking;
      canvas.drawCircle(center, 1.6, _fill);
      return;
    }
    for (var edge = 0; edge < 4; edge++) {
      if (_neighborIndex(map, c, r, edge) != road) continue;
      final a = corners[edge];
      final b = corners[(edge + 1) % 4];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      canvas.drawLine(center, mid, _line);
    }
  }

  static void _paintSlab(
    Canvas canvas,
    GameMap map,
    int c,
    int r,
    Offset top,
    Color base,
  ) {
    final left = Offset(top.dx - _hw, top.dy + _hh);
    final bottom = Offset(top.dx, top.dy + IsoProjection.tileHeight);
    final right = Offset(top.dx + _hw, top.dy + _hh);

    if (r == map.rows - 1) {
      _fill.color = Color.lerp(base, const Color(0xFF000000), 0.45)!;
      canvas.drawPath(_face(left, bottom), _fill);
    }
    if (c == map.cols - 1) {
      _fill.color = Color.lerp(base, const Color(0xFF000000), 0.3)!;
      canvas.drawPath(_face(bottom, right), _fill);
    }
  }

  static Path _face(Offset a, Offset b) {
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx, b.dy + slabDepth)
      ..lineTo(a.dx, a.dy + slabDepth)
      ..close();
  }

  /// Draws edge [edge] (0 = top-right, 1 = bottom-right, 2 = bottom-left,
  /// 3 = top-left), pulled toward the tile center by [inset].
  static void _drawInsetEdge(
    Canvas canvas,
    List<Offset> corners,
    int edge,
    Offset center,
    double inset,
  ) {
    final a = Offset.lerp(corners[edge], center, inset)!;
    final b = Offset.lerp(corners[(edge + 1) % 4], center, inset)!;
    canvas.drawLine(a, b, _line);
  }

  /// Type index of the neighbour across [edge], or -1 outside the map.
  static int _neighborIndex(GameMap map, int c, int r, int edge) {
    final (nc, nr) = switch (edge) {
      0 => (c, r - 1),
      1 => (c + 1, r),
      2 => (c, r + 1),
      _ => (c - 1, r),
    };
    return map.inBounds(nc, nr) ? map.typeIndexAt(nc, nr) : -1;
  }

  static Path _diamond(Offset top, {double bleed = 0}) {
    return Path()
      ..moveTo(top.dx, top.dy - bleed)
      ..lineTo(top.dx + _hw + bleed, top.dy + _hh)
      ..lineTo(top.dx, top.dy + IsoProjection.tileHeight + bleed)
      ..lineTo(top.dx - _hw - bleed, top.dy + _hh)
      ..close();
  }

  // --- decorations ----------------------------------------------------

  static void paintDecoration(Canvas canvas, GameMap map, int c, int r) {
    final decoration = map.decorationAt(c, r);
    if (decoration.isNone) return;

    final h = _hash(c, r, 2);
    final center = IsoProjection.tileCenter(c, r);
    final p = Offset(
      center.dx + (_unit(h, 1) - 0.5) * 14,
      center.dy + 3 + (_unit(h, 2) - 0.5) * 5,
    );
    final scale = 0.85 + _unit(h, 3) * 0.3;

    switch (decoration) {
      case TileDecoration.none:
        break;
      case TileDecoration.tree:
        _paintTree(canvas, p, scale);
      case TileDecoration.pine:
        _paintPine(canvas, p, scale);
      case TileDecoration.bush:
        _paintBush(canvas, p, scale);
      case TileDecoration.rock:
        _paintRock(canvas, p, scale, h);
      case TileDecoration.flowers:
        _paintFlowers(canvas, center, h);
    }
  }

  static void _shadow(Canvas canvas, Offset p, double width) {
    _fill.color = MapColors.shadow;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx + 3, p.dy + 1),
        width: width,
        height: width * 0.4,
      ),
      _fill,
    );
  }

  static void _paintTree(Canvas canvas, Offset p, double s) {
    _shadow(canvas, p, 24 * s);
    _fill.color = MapColors.trunk;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p.dx - 2.5 * s, p.dy - 11 * s, 5 * s, 12 * s),
        const Radius.circular(1.5),
      ),
      _fill,
    );
    final radius = 11 * s;
    _fill.color = MapColors.canopyDark;
    canvas.drawCircle(Offset(p.dx, p.dy - 17 * s), radius, _fill);
    _fill.color = MapColors.canopyMid;
    canvas.drawCircle(
      Offset(p.dx - 1 * s, p.dy - 21 * s),
      radius * 0.85,
      _fill,
    );
    _fill.color = MapColors.canopyLight;
    canvas.drawCircle(
      Offset(p.dx - 3 * s, p.dy - 24 * s),
      radius * 0.45,
      _fill,
    );
  }

  static void _paintPine(Canvas canvas, Offset p, double s) {
    _shadow(canvas, p, 20 * s);
    _fill.color = MapColors.trunk;
    canvas.drawRect(
      Rect.fromLTWH(p.dx - 1.5 * s, p.dy - 6 * s, 3 * s, 7 * s),
      _fill,
    );
    for (var layer = 2; layer >= 0; layer--) {
      final topY = p.dy - (38 - layer * 9) * s;
      final halfWidth = (6.5 + layer * 3) * s;
      _fill.color = layer == 0 ? MapColors.pineMid : MapColors.pineDark;
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, topY)
          ..lineTo(p.dx + halfWidth, topY + 15 * s)
          ..lineTo(p.dx - halfWidth, topY + 15 * s)
          ..close(),
        _fill,
      );
    }
  }

  static void _paintBush(Canvas canvas, Offset p, double s) {
    _shadow(canvas, p, 16 * s);
    _fill.color = MapColors.canopyDark;
    canvas.drawCircle(Offset(p.dx - 4 * s, p.dy - 4 * s), 6 * s, _fill);
    canvas.drawCircle(Offset(p.dx + 4 * s, p.dy - 5 * s), 7 * s, _fill);
    _fill.color = MapColors.bush;
    canvas.drawCircle(Offset(p.dx, p.dy - 8 * s), 5.5 * s, _fill);
  }

  static void _paintRock(Canvas canvas, Offset p, double s, int h) {
    _shadow(canvas, p, 18 * s);
    final lean = (_unit(h, 4) - 0.5) * 3;
    _fill.color = MapColors.rockDark;
    canvas.drawPath(
      Path()
        ..moveTo(p.dx - 8 * s, p.dy)
        ..lineTo(p.dx - 5 * s, p.dy - 8 * s)
        ..lineTo(p.dx + lean, p.dy - 11 * s)
        ..lineTo(p.dx + 7 * s, p.dy - 6 * s)
        ..lineTo(p.dx + 9 * s, p.dy)
        ..close(),
      _fill,
    );
    _fill.color = MapColors.rockLight;
    canvas.drawPath(
      Path()
        ..moveTo(p.dx - 5 * s, p.dy - 8 * s)
        ..lineTo(p.dx + lean, p.dy - 11 * s)
        ..lineTo(p.dx + 7 * s, p.dy - 6 * s)
        ..lineTo(p.dx, p.dy - 5 * s)
        ..close(),
      _fill,
    );
  }

  static void _paintFlowers(Canvas canvas, Offset center, int h) {
    for (var i = 0; i < 5; i++) {
      final x = center.dx + (_unit(h, 70 + i) - 0.5) * 30;
      final y = center.dy + 2 + (_unit(h, 80 + i) - 0.5) * 11;
      _fill.color = MapColors.grassTuft;
      canvas.drawCircle(Offset(x, y + 1), 1.2, _fill);
      _fill.color =
          MapColors.flowerColors[(h >> (i * 2)).abs() %
              MapColors.flowerColors.length];
      canvas.drawCircle(Offset(x, y - 1), 1.8, _fill);
    }
  }

  // --- helpers --------------------------------------------------------

  /// Stable per-tile pseudo-random integer.
  static int _hash(int c, int r, int salt) {
    var h = (c * 73856093) ^ (r * 19349663) ^ (salt * 83492791);
    h = (h ^ (h >> 15)) * 2246822519 & 0xFFFFFFFF;
    h = (h ^ (h >> 13)) & 0x7FFFFFFF;
    return h;
  }

  /// Pseudo-random value in [0, 1) derived from [h] and a [salt].
  static double _unit(int h, int salt) {
    final mixed = (h * 2654435761 + salt * 40503) & 0xFFFFFF;
    return mixed / 0x1000000;
  }
}
