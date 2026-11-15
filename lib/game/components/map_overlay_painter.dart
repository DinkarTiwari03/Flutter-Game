import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/core/theme/map_colors.dart';
import 'package:city_builder_2040/game/components/iso_map_painter.dart';
import 'package:city_builder_2040/game/components/iso_map_renderer.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';

/// Paints the dynamic layer above the terrain: grid lines, the hovered tile
/// and the selected tile.
///
/// It is a separate layer so selection and hover changes never repaint the
/// terrain. It listens to the camera, selection, hover and the selection
/// "pop" animation, and redraws only a handful of shapes.
class MapOverlayPainter extends CustomPainter {
  MapOverlayPainter({
    required this.renderer,
    required this.camera,
    required this.selected,
    required this.hovered,
    required this.pop,
    required this.showGrid,
  }) : super(repaint: Listenable.merge([camera, selected, hovered, pop]));

  final IsoMapRenderer renderer;
  final MapCamera camera;
  final ValueListenable<GridPoint?> selected;
  final ValueListenable<GridPoint?> hovered;
  final Animation<double> pop;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.applyCamera(camera);

    // Keep strokes a constant width on screen regardless of zoom.
    final pixel = 1 / camera.zoom;

    if (showGrid && camera.zoom >= GameConstants.gridMinZoom) {
      _paintGrid(canvas, pixel);
    }

    final hover = hovered.value;
    final selection = selected.value;
    if (hover != null && hover != selection && renderer.map.contains(hover)) {
      _paintHover(canvas, hover, pixel);
    }
    if (selection != null && renderer.map.contains(selection)) {
      _paintSelection(canvas, selection, pixel);
    }

    canvas.restore();
  }

  void _paintGrid(Canvas canvas, double pixel) {
    final tiles = renderer.visibleTiles(camera.visibleWorldRect);
    if (tiles == null) return;

    final path = Path();
    for (var r = tiles.minRow; r <= tiles.maxRow; r++) {
      for (var c = tiles.minCol; c <= tiles.maxCol; c++) {
        final top = IsoProjection.tileTop(c, r);
        path
          ..moveTo(
            top.dx - IsoProjection.halfWidth,
            top.dy + IsoProjection.halfHeight,
          )
          ..lineTo(top.dx, top.dy)
          ..lineTo(
            top.dx + IsoProjection.halfWidth,
            top.dy + IsoProjection.halfHeight,
          );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = MapColors.grid
        ..style = PaintingStyle.stroke
        ..strokeWidth = pixel,
    );
  }

  void _paintHover(Canvas canvas, GridPoint tile, double pixel) {
    final path = tileDiamondPath(tile.col, tile.row);
    canvas.drawPath(path, Paint()..color = MapColors.hoverFill);
    canvas.drawPath(
      path,
      Paint()
        ..color = MapColors.hoverStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * pixel,
    );
  }

  void _paintSelection(Canvas canvas, GridPoint tile, double pixel) {
    final t = Curves.easeOutBack.transform(pop.value.clamp(0.0, 1.0));
    final center = IsoProjection.tileCenter(tile.col, tile.row);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(0.7 + 0.3 * t);
    canvas.translate(-center.dx, -center.dy);

    final path = tileDiamondPath(tile.col, tile.row);
    canvas.drawPath(path, Paint()..color = MapColors.selectionFill);
    canvas.drawPath(
      path,
      Paint()
        ..color = MapColors.selectionGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 * pixel
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MapOverlayPainter oldDelegate) =>
      oldDelegate.renderer != renderer ||
      oldDelegate.camera != camera ||
      oldDelegate.showGrid != showGrid;
}
