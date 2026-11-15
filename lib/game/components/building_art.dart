import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/map_colors.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';

/// Isometric 2.5D building drawing routines.
abstract final class BuildingArt {
  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _stroke =
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke;

  /// Returns the base vertical height in pixels for a given [definition].
  static double heightFor(BuildingDefinition definition, int level) {
    final base = switch (definition.id) {
      'road' => 2.0,
      'garden' => 8.0,
      'park' => 14.0,
      'solar_plant' => 16.0,
      'water_treatment' => 26.0,
      'small_house' => 22.0,
      'shop' => 24.0,
      'police_station' || 'fire_station' => 32.0,
      'school' => 36.0,
      'factory' => 38.0,
      'water_facility' => 42.0,
      'shopping_mall' => 44.0,
      'apartments' => 48.0,
      'industrial_facility' => 52.0,
      'hospital' => 56.0,
      'power_plant' => 64.0,
      'residential_tower' => 82.0,
      'office_building' => 92.0,
      _ => 30.0,
    };
    return base + (level - 1) * 8.0;
  }

  /// Calculates the 4 footprint corners of [definition] at [origin] in world space.
  static ({Offset top, Offset right, Offset bottom, Offset left}) footprintCorners(
    GridPoint origin,
    int width,
    int height,
  ) {
    return (
      top: IsoProjection.tileTop(origin.col, origin.row),
      right: IsoProjection.tileTop(origin.col + width, origin.row),
      bottom: IsoProjection.tileTop(origin.col + width, origin.row + height),
      left: IsoProjection.tileTop(origin.col, origin.row + height),
    );
  }

  /// Builds the closed polygon path for a building's footprint diamond.
  static Path footprintPath(GridPoint origin, int width, int height) {
    final c = footprintCorners(origin, width, height);
    return Path()
      ..moveTo(c.top.dx, c.top.dy)
      ..lineTo(c.right.dx, c.right.dy)
      ..lineTo(c.bottom.dx, c.bottom.dy)
      ..lineTo(c.left.dx, c.left.dy)
      ..close();
  }

  /// Paints a placed building in world space.
  static void paintBuilding({
    required Canvas canvas,
    required BuildingDefinition definition,
    required GridPoint origin,
    int level = 1,
    bool isGhost = false,
    bool isValid = true,
  }) {
    if (definition.isRoad) {
      _paintRoad(canvas, origin, isGhost, isValid);
      return;
    }

    final h = heightFor(definition, level);
    final c = footprintCorners(origin, definition.width, definition.height);

    // Roof corners (shifted up by h)
    final topRoof = Offset(c.top.dx, c.top.dy - h);
    final rightRoof = Offset(c.right.dx, c.right.dy - h);
    final bottomRoof = Offset(c.bottom.dx, c.bottom.dy - h);
    final leftRoof = Offset(c.left.dx, c.left.dy - h);

    final baseColor =
        isGhost
            ? (isValid ? AppColors.teal : AppColors.coral)
            : definition.accentColor;

    final wallOpacity = isGhost ? 0.6 : 1.0;
    final roofOpacity = isGhost ? 0.75 : 1.0;

    // 1. Footprint foundation
    if (!isGhost) {
      _fill
        ..color = AppColors.navy.withAlpha(80)
        ..style = PaintingStyle.fill;
      canvas.drawPath(
        footprintPath(origin, definition.width, definition.height),
        _fill,
      );
    }

    // 2. Left Wall (facing down-left) - in shadow
    final leftWall =
        Path()
          ..moveTo(leftRoof.dx, leftRoof.dy)
          ..lineTo(bottomRoof.dx, bottomRoof.dy)
          ..lineTo(c.bottom.dx, c.bottom.dy)
          ..lineTo(c.left.dx, c.left.dy)
          ..close();
    _fill
      ..color = Color.lerp(
        baseColor,
        Colors.black,
        0.35,
      )!.withValues(alpha: wallOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftWall, _fill);

    // 3. Right Wall (facing down-right) - mid-tone
    final rightWall =
        Path()
          ..moveTo(bottomRoof.dx, bottomRoof.dy)
          ..lineTo(rightRoof.dx, rightRoof.dy)
          ..lineTo(c.right.dx, c.right.dy)
          ..lineTo(c.bottom.dx, c.bottom.dy)
          ..close();
    _fill
      ..color = Color.lerp(
        baseColor,
        Colors.black,
        0.18,
      )!.withValues(alpha: wallOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(rightWall, _fill);

    // 4. Roof Diamond
    final roof =
        Path()
          ..moveTo(topRoof.dx, topRoof.dy)
          ..lineTo(rightRoof.dx, rightRoof.dy)
          ..lineTo(bottomRoof.dx, bottomRoof.dy)
          ..lineTo(leftRoof.dx, leftRoof.dy)
          ..close();
    _fill
      ..color = Color.lerp(
        baseColor,
        Colors.white,
        0.15,
      )!.withValues(alpha: roofOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(roof, _fill);

    // 5. Structure outlines
    _stroke
      ..color = (isGhost
              ? (isValid ? AppColors.aqua : AppColors.coral)
              : AppColors.navy.withAlpha(160))
          .withValues(alpha: isGhost ? 0.8 : 0.6)
      ..strokeWidth = isGhost ? 1.5 : 1.0;
    canvas.drawPath(leftWall, _stroke);
    canvas.drawPath(rightWall, _stroke);
    canvas.drawPath(roof, _stroke);

    // 6. Architectural details (if not ghost)
    if (!isGhost) {
      _paintWindows(canvas, leftRoof, bottomRoof, rightRoof, c.left, c.bottom, c.right, h);
      _paintCategoryDetails(canvas, definition, topRoof, rightRoof, bottomRoof, leftRoof, h);

      if (level > 1) {
        _paintLevelIndicator(canvas, bottomRoof, level);
      }
    }
  }

  static void _paintRoad(
    Canvas canvas,
    GridPoint origin,
    bool isGhost,
    bool isValid,
  ) {
    final top = IsoProjection.tileTop(origin.col, origin.row);
    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx + IsoProjection.halfWidth, top.dy + IsoProjection.halfHeight)
      ..lineTo(top.dx, top.dy + IsoProjection.tileHeight)
      ..lineTo(top.dx - IsoProjection.halfWidth, top.dy + IsoProjection.halfHeight)
      ..close();

    _fill
      ..color = isGhost
          ? (isValid ? AppColors.teal.withAlpha(140) : AppColors.coral.withAlpha(140))
          : MapColors.asphalt
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, _fill);

    if (!isGhost) {
      _stroke
        ..color = MapColors.laneMarking.withAlpha(150)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(top.dx - 6, top.dy + IsoProjection.halfHeight - 3),
        Offset(top.dx + 6, top.dy + IsoProjection.halfHeight + 3),
        _stroke,
      );
    }
  }

  static void _paintWindows(
    Canvas canvas,
    Offset leftRoof,
    Offset bottomRoof,
    Offset rightRoof,
    Offset leftBase,
    Offset bottomBase,
    Offset rightBase,
    double height,
  ) {
    if (height < 20) return;

    final windowPaint =
        Paint()
          ..color = AppColors.aqua.withAlpha(160)
          ..style = PaintingStyle.fill;

    final floors = math.max(1, (height / 14).floor());
    for (var f = 1; f <= floors; f++) {
      final t = f / (floors + 1);
      final lPos = Offset.lerp(leftBase, leftRoof, t)!;
      final bPos = Offset.lerp(bottomBase, bottomRoof, t)!;
      final rPos = Offset.lerp(rightBase, rightRoof, t)!;

      // Small window glints along the walls
      final w1 = Offset.lerp(lPos, bPos, 0.45)!;
      final w2 = Offset.lerp(bPos, rPos, 0.55)!;
      canvas.drawCircle(w1, 1.2, windowPaint);
      canvas.drawCircle(w2, 1.2, windowPaint);
    }
  }

  static void _paintCategoryDetails(
    Canvas canvas,
    BuildingDefinition def,
    Offset topRoof,
    Offset rightRoof,
    Offset bottomRoof,
    Offset leftRoof,
    double height,
  ) {
    final roofCenter = Offset(
      (topRoof.dx + bottomRoof.dx) / 2,
      (topRoof.dy + bottomRoof.dy) / 2,
    );

    switch (def.category) {
      case BuildingCategory.publicServices:
        if (def.id == 'hospital') {
          // Helipad ring and 'H'
          final padPaint = Paint()..color = Colors.white.withAlpha(200);
          canvas.drawCircle(roofCenter, 6, padPaint);
          _fill.color = AppColors.coral;
          canvas.drawRect(
            Rect.fromCenter(center: roofCenter, width: 2, height: 6),
            _fill,
          );
          canvas.drawRect(
            Rect.fromCenter(center: roofCenter, width: 6, height: 2),
            _fill,
          );
        } else {
          // Small antenna beacon
          _stroke
            ..color = AppColors.navy
            ..strokeWidth = 1.5;
          canvas.drawLine(roofCenter, Offset(roofCenter.dx, roofCenter.dy - 12), _stroke);
          _fill.color = AppColors.coral;
          canvas.drawCircle(Offset(roofCenter.dx, roofCenter.dy - 12), 2, _fill);
        }
      case BuildingCategory.environment:
        if (def.id == 'park') {
          // Fountain in center
          _fill.color = AppColors.sky;
          canvas.drawCircle(roofCenter, 4.5, _fill);
          _fill.color = Colors.white;
          canvas.drawCircle(roofCenter, 1.5, _fill);
        } else if (def.id == 'solar_plant') {
          // Solar cell grid lines
          _stroke
            ..color = AppColors.navy.withAlpha(120)
            ..strokeWidth = 1.0;
          canvas.drawLine(
            Offset(leftRoof.dx + 4, leftRoof.dy),
            Offset(rightRoof.dx - 4, rightRoof.dy),
            _stroke,
          );
        }
      case BuildingCategory.infrastructure:
        if (def.id == 'power_plant') {
          // Cooling tower / reactor cylinder
          _fill.color = Colors.blueGrey.shade300;
          canvas.drawOval(
            Rect.fromCenter(center: roofCenter, width: 12, height: 7),
            _fill,
          );
          _fill.color = AppColors.sunrise;
          canvas.drawCircle(roofCenter, 2, _fill);
        }
      default:
        // Rooftop AC unit or skylight
        _fill.color = AppColors.navy.withAlpha(100);
        canvas.drawRect(
          Rect.fromCenter(center: roofCenter, width: 5, height: 3),
          _fill,
        );
    }
  }

  static void _paintLevelIndicator(
    Canvas canvas,
    Offset bottomRoof,
    int level,
  ) {
    final badgePaint = Paint()..color = AppColors.sunrise;
    final borderPaint =
        Paint()
          ..color = AppColors.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    for (var i = 0; i < level; i++) {
      final dotPos = Offset(bottomRoof.dx - (level - 1) * 3 + i * 6, bottomRoof.dy - 4);
      canvas.drawCircle(dotPos, 2.2, badgePaint);
      canvas.drawCircle(dotPos, 2.2, borderPaint);
    }
  }
}
