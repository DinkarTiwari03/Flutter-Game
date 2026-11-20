import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/map_colors.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/buildings/building_sprite_registry.dart';
import 'package:city_builder_2040/game/components/building_art.dart';
import 'package:city_builder_2040/game/components/building_sprite_cache.dart';
import 'package:city_builder_2040/game/components/iso_map_painter.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/urban/pedestrian.dart';
import 'package:city_builder_2040/game/urban/urban_art.dart';
import 'package:city_builder_2040/game/urban/urban_simulation_service.dart';
import 'package:city_builder_2040/game/urban/urban_sprite_cache.dart';
import 'package:city_builder_2040/game/urban/vehicle.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';
import 'package:city_builder_2040/providers/building_providers.dart';

/// Paints placed 2.5D isometric buildings, urban traffic & citizens, and placement previews.
class BuildingPainter extends CustomPainter {
  BuildingPainter({
    required this.camera,
    required this.buildings,
    required this.placement,
    required this.selectedBuildingId,
    required this.spriteCache,
    required this.onSpriteLoaded,
    this.urbanService,
    this.urbanCache,
    this.clock,
    this.showTrafficHeatmap = false,
  }) : super(repaint: urbanService != null ? Listenable.merge([camera, urbanService]) : camera);

  final MapCamera camera;
  final List<Building> buildings;
  final PlacementState placement;
  final String? selectedBuildingId;
  final BuildingSpriteCache spriteCache;
  final VoidCallback onSpriteLoaded;
  final UrbanSimulationService? urbanService;
  final UrbanSpriteCache? urbanCache;
  final SimulationClock? clock;
  final bool showTrafficHeatmap;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.applyCamera(camera);

    final pixel = 1 / camera.zoom;
    final isNight = clock != null &&
        (clock!.phase == DayPhase.night || clock!.phase == DayPhase.dusk);

    // 0. Render dynamic Traffic Congestion Heatmap overlay on road tiles
    if (showTrafficHeatmap && urbanService != null) {
      UrbanArt.paintTrafficHeatmap(
        canvas: canvas,
        graph: urbanService!.roadGraph,
        segmentStats: urbanService!.trafficMetrics.segmentStats,
      );
    }

    // 1. Merge buildings, vehicles, and pedestrians for unified isometric depth sorting
    final renderItems = <_DepthItem>[];

    for (final b in buildings) {
      renderItems.add(_DepthItem(depth: (b.y + b.x).toDouble(), building: b));
    }

    if (urbanService != null && urbanCache != null) {
      for (final v in urbanService!.vehicles) {
        if (!v.isDespawned) {
          renderItems.add(_DepthItem(depth: v.depth, vehicle: v));
        }
      }
      for (final p in urbanService!.pedestrians) {
        if (!p.isDespawned) {
          renderItems.add(_DepthItem(depth: p.depth, pedestrian: p));
        }
      }
    }

    renderItems.sort((a, b) => a.depth.compareTo(b.depth));

    // 2. Render sorted buildings, vehicles, and citizens
    for (final item in renderItems) {
      if (item.building != null) {
        final b = item.building!;
        final def = BuildingRegistry.get(b.typeId);
        if (def == null) continue;
        final origin = GridPoint(b.x, b.y);

        // Selected building highlight foundation
        if (b.id == selectedBuildingId) {
          _paintSelectionGlow(canvas, origin, def, b.rotation, pixel);
        }

        final assetPath = BuildingSpriteRegistry.assetFor(b.typeId, b.level);
        if (assetPath != null) {
          spriteCache.warmUp(assetPath, onLoaded: onSpriteLoaded);
        }

        BuildingArt.paintBuilding(
          canvas: canvas,
          definition: def,
          origin: origin,
          level: b.level,
          rotation: b.rotation,
          sprite: assetPath != null ? spriteCache.get(assetPath) : null,
        );
      } else if (item.vehicle != null && urbanCache != null) {
        UrbanArt.paintVehicle(
          canvas: canvas,
          vehicle: item.vehicle!,
          cache: urbanCache!,
          isNight: isNight,
          onSpriteLoaded: onSpriteLoaded,
        );
      } else if (item.pedestrian != null && urbanCache != null) {
        UrbanArt.paintPedestrian(
          canvas: canvas,
          pedestrian: item.pedestrian!,
          cache: urbanCache!,
          onSpriteLoaded: onSpriteLoaded,
        );
      }
    }

    // 3. Draw placement preview if in placement mode
    if (placement.isPlacing && placement.previewOrigin != null) {
      final def = placement.activeDefinition!;
      final origin = placement.previewOrigin!;
      final isValid = placement.validation?.isValid ?? false;
      final rot = placement.rotation;

      _paintPlacementFootprint(canvas, origin, def, rot, isValid, pixel);

      final assetPath = BuildingSpriteRegistry.assetFor(def.id, 1);
      if (assetPath != null) {
        spriteCache.warmUp(assetPath, onLoaded: onSpriteLoaded);
      }

      BuildingArt.paintBuilding(
        canvas: canvas,
        definition: def,
        origin: origin,
        level: 1,
        rotation: rot,
        isGhost: true,
        isValid: isValid,
        sprite: assetPath != null ? spriteCache.get(assetPath) : null,
      );
    }

    canvas.restore();
  }

  void _paintSelectionGlow(
    Canvas canvas,
    GridPoint origin,
    BuildingDefinition def,
    int rotation,
    double pixel,
  ) {
    final effW = def.effectiveWidth(rotation);
    final effH = def.effectiveHeight(rotation);
    final path = BuildingArt.footprintPath(origin, effW, effH);
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
    int rotation,
    bool isValid,
    double pixel,
  ) {
    final footprint = def.footprintTilesRotated(origin, rotation);
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
      oldDelegate.selectedBuildingId != selectedBuildingId ||
      oldDelegate.spriteCache != spriteCache ||
      oldDelegate.urbanService != urbanService ||
      oldDelegate.clock != clock ||
      oldDelegate.showTrafficHeatmap != showTrafficHeatmap;
}

class _DepthItem {
  _DepthItem({
    required this.depth,
    this.building,
    this.vehicle,
    this.pedestrian,
  });

  final double depth;
  final Building? building;
  final Vehicle? vehicle;
  final Pedestrian? pedestrian;
}
