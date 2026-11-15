import 'package:flutter/widgets.dart';

import 'package:city_builder_2040/core/theme/map_colors.dart';
import 'package:city_builder_2040/game/components/iso_map_renderer.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';

/// Paints the terrain and decorations of the map.
///
/// Repaints only when the camera moves (via the `repaint` listenable), never
/// through a widget rebuild. Each frame it draws just the cached chunks that
/// are on screen: all ground first, then decorations from back to front so
/// trees overlap the tiles behind them correctly.
class IsoMapPainter extends CustomPainter {
  IsoMapPainter({required this.renderer, required this.camera})
    : super(repaint: camera);

  final IsoMapRenderer renderer;
  final MapCamera camera;

  /// Decorations rise above their tile, so look a bit further up.
  static const _decorationPadding = 56.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = MapColors.outside);

    final tiles = renderer.visibleTiles(
      camera.visibleWorldRect,
      padding: _decorationPadding,
    );
    if (tiles == null) return;
    final chunks = renderer.chunksFor(tiles);

    canvas.save();
    canvas.applyCamera(camera);

    for (var cy = chunks.minRow; cy <= chunks.maxRow; cy++) {
      for (var cx = chunks.minCol; cx <= chunks.maxCol; cx++) {
        canvas.drawPicture(renderer.groundChunk(cx, cy));
      }
    }

    // Back-to-front by chunk diagonal so overlapping decorations at chunk
    // borders layer correctly.
    final firstDiagonal = chunks.minCol + chunks.minRow;
    final lastDiagonal = chunks.maxCol + chunks.maxRow;
    for (var d = firstDiagonal; d <= lastDiagonal; d++) {
      for (var cy = chunks.minRow; cy <= chunks.maxRow; cy++) {
        final cx = d - cy;
        if (cx < chunks.minCol || cx > chunks.maxCol) continue;
        canvas.drawPicture(renderer.decorationChunk(cx, cy));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant IsoMapPainter oldDelegate) =>
      oldDelegate.renderer != renderer || oldDelegate.camera != camera;
}

/// World-space helpers shared by painters.
extension MapCameraCanvas on Canvas {
  /// Applies the camera transform so subsequent drawing uses world units.
  void applyCamera(MapCamera camera) {
    translate(camera.viewportCenter.dx, camera.viewportCenter.dy);
    scale(camera.zoom);
    translate(-camera.focus.dx, -camera.focus.dy);
  }
}

/// Convenience for building the diamond outline of a tile.
Path tileDiamondPath(int col, int row) {
  final corners = IsoProjection.tileCorners(col, row);
  return Path()
    ..moveTo(corners[0].dx, corners[0].dy)
    ..lineTo(corners[1].dx, corners[1].dy)
    ..lineTo(corners[2].dx, corners[2].dy)
    ..lineTo(corners[3].dx, corners[3].dy)
    ..close();
}
