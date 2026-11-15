import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';

MapCamera _camera({double zoom = 1, Offset? focus}) {
  final camera = MapCamera(
    worldBounds: const Rect.fromLTRB(-1000, 0, 1000, 2000),
    zoom: zoom,
    focus: focus,
    boundaryMargin: 100,
  );
  camera.setViewport(const Size(400, 800));
  return camera;
}

void main() {
  group('MapCamera conversions', () {
    test('screen center maps to the focus', () {
      final camera = _camera(focus: const Offset(100, 900));
      expect(
        camera.screenToWorld(const Offset(200, 400)),
        const Offset(100, 900),
      );
    });

    test('screenToWorld and worldToScreen are inverses', () {
      final camera = _camera(zoom: 1.7, focus: const Offset(-120, 700));
      const screen = Offset(73, 311);
      final back = camera.worldToScreen(camera.screenToWorld(screen));
      expect(back.dx, closeTo(screen.dx, 1e-9));
      expect(back.dy, closeTo(screen.dy, 1e-9));
    });

    test('zoom scales distances', () {
      final camera = _camera(zoom: 2, focus: const Offset(0, 1000));
      final a = camera.screenToWorld(const Offset(200, 400));
      final b = camera.screenToWorld(const Offset(300, 400));
      expect(b.dx - a.dx, closeTo(50, 1e-9));
    });

    test('visible rect is centered on the focus', () {
      final camera = _camera(zoom: 2, focus: const Offset(0, 1000));
      final rect = camera.visibleWorldRect;
      expect(rect.center, const Offset(0, 1000));
      expect(rect.width, 200);
      expect(rect.height, 400);
    });
  });

  group('MapCamera panning', () {
    test('dragging right moves the focus left', () {
      final camera = _camera(focus: const Offset(0, 1000));
      camera.panByScreen(const Offset(50, 0));
      expect(camera.focus.dx, -50);
      expect(camera.focus.dy, 1000);
    });

    test('pan distance in world units shrinks as zoom grows', () {
      final camera = _camera(zoom: 2, focus: const Offset(0, 1000));
      camera.panByScreen(const Offset(50, 0));
      expect(camera.focus.dx, -25);
    });

    test('focus cannot leave the map plus margin', () {
      final camera = _camera(focus: const Offset(0, 1000));
      camera.panByScreen(const Offset(-100000, 0));
      // right limit = 1000 + 100 margin - half viewport (200)
      expect(camera.focus.dx, 900);
      camera.panByScreen(const Offset(100000, 0));
      expect(camera.focus.dx, -900);
      camera.panByScreen(const Offset(0, 100000));
      // top limit = 0 - 100 margin + half viewport (400)
      expect(camera.focus.dy, 300);
    });

    test('an axis that fits entirely on screen is centered', () {
      final camera = MapCamera(
        worldBounds: const Rect.fromLTRB(0, 0, 100, 100),
        boundaryMargin: 0,
      );
      camera.setViewport(const Size(500, 500));
      camera.panByScreen(const Offset(300, 300));
      expect(camera.focus, const Offset(50, 50));
    });
  });

  group('MapCamera zoom', () {
    test('zoom is clamped to the limits', () {
      final camera = _camera();
      camera.jumpTo(zoom: 100);
      expect(camera.zoom, camera.maxZoom);
      camera.jumpTo(zoom: 0.0001);
      expect(camera.zoom, camera.minZoom);
    });

    test('zoomAt keeps the point under the cursor fixed', () {
      final camera = _camera(focus: const Offset(0, 1000));
      const cursor = Offset(120, 250);
      final before = camera.screenToWorld(cursor);
      camera.zoomAt(cursor, 1.8);
      final after = camera.screenToWorld(cursor);
      expect(camera.zoom, 1.8);
      expect(after.dx, closeTo(before.dx, 1e-6));
      expect(after.dy, closeTo(before.dy, 1e-6));
    });

    test('anchorAt supports a moving pinch midpoint', () {
      final camera = _camera(focus: const Offset(0, 1000));
      final world = camera.screenToWorld(const Offset(100, 300));
      camera.anchorAt(
        worldPoint: world,
        screenPoint: const Offset(140, 340),
        zoom: 1.5,
      );
      final under = camera.screenToWorld(const Offset(140, 340));
      expect(under.dx, closeTo(world.dx, 1e-6));
      expect(under.dy, closeTo(world.dy, 1e-6));
    });

    test('fitZoom shows the whole map', () {
      final camera = _camera();
      // bounds 2000 x 2000 into 400 x 800 -> 0.2, clamped to min zoom 0.3.
      expect(camera.fitZoom, camera.minZoom);
    });
  });

  test('listeners are notified only when the view changes', () {
    final camera = _camera(focus: const Offset(0, 1000));
    var notifications = 0;
    camera.addListener(() => notifications++);

    camera.panByScreen(const Offset(10, 0));
    expect(notifications, 1);

    camera.panByScreen(Offset.zero);
    expect(notifications, 1);
  });
}
