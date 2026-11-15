import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/map_colors.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/components/building_art.dart';
import 'package:city_builder_2040/game/components/iso_map_painter.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/providers/building_providers.dart';

/// Paints placed 2.5D isometric buildings and placement ghost previews.
class BuildingPainter extends CustomPainter {
  BuildingPainter({
    required this.camera,
    required this.buildings,
    required this.placement,
    required this.selectedBuildingId,
  }) : super(repaint: camera);

  final MapCamera camera;
  final List<Building> buildings;
  final PlacementState placement;
  final String? selectedBuildingId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.applyCamera(camera);

    final pixel = 1 / camera.zoom;

    // 1. Sort placed buildings by isometric depth: (row + col)
    final sortedBuildings = List<Building>.from(buildings)
      ..sort((a, b) {
        final depthA = a.y + a.x;
        final depthB = b.y + b.x;
        return depthA.compareTo(depthB);
      });

    // 2. Draw placed buildings
    for (final b in sortedBuildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;
      final origin = GridPoint(b.x, b.y);

      // Selected building highlight foundation
      if (b.id == selectedBuildingId) {
        _paintSelectionGlow(canvas, origin, def, pixel);
      }

      BuildingArt.paintBuilding(
        canvas: canvas,
        definition: def,
        origin: origin,
        level: b.level,
      );
    }

    // 3. Draw placement preview if in placement mode
    if (placement.isPlacing && placement.previewOrigin != null) {
      final def = placement.activeDefinition!;
      final origin = placement.previewOrigin!;
      final isValid = placement.validation?.isValid ?? false;

      _paintPlacementFootprint(canvas, origin, def, isValid, pixel);

      BuildingArt.paintBuilding(
        canvas: canvas,
        definition: def,
        origin: origin,
        level: 1,
        isGhost: true,
        isValid: isValid,
      );
    }

    canvas.restore();
  }

  void _paintSelectionGlow(
    Canvas canvas,
    GridPoint origin,
    BuildingDefinition def,
    double pixel,
  ) {
    final path = BuildingArt.footprintPath(origin, def.width, def.height);
    canvas.drawPath(
      path,
      Paint()
        ..color = MapColors.selectionGlow.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * pixel
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = MapColors.selectionStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * pixel
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintPlacementFootprint(
    Canvas canvas,
    GridPoint origin,
    BuildingDefinition def,
    bool isValid,
    double pixel,
  ) {
    final footprint = def.footprintTiles(origin);
    final color = isValid ? AppColors.teal : AppColors.coral;

    final fillPaint =
        Paint()
          ..color = color.withAlpha(80)
          ..style = PaintingStyle.fill;
    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * pixel;

    for (final tile in footprint) {
      final path = tileDiamondPath(tile.col, tile.row);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant BuildingPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      !listEquals(oldDelegate.buildings, buildings) ||
      oldDelegate.placement != placement ||
      oldDelegate.selectedBuildingId != selectedBuildingId;
}
