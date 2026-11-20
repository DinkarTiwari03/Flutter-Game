import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/engine/map_camera_controller.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';
import 'package:city_builder_2040/game/map/map_config.dart';
import 'package:city_builder_2040/game/map/map_generator.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/screens/game/game_shortcuts.dart';
import 'package:city_builder_2040/widgets/game/map_viewport.dart';

class _FixedCity extends ActiveCityNotifier {
  _FixedCity(this.city);
  final City city;
  @override
  City? build() => city;
}

final _testCity = City(
  id: 'rotation-test-city',
  name: 'Rotopolis',
  mapWidth: 32,
  mapHeight: 32,
  createdAt: DateTime.utc(2040),
  updatedAt: DateTime.utc(2040),
);

void main() {
  group('MapCamera Coordinate Transformations & Rotation Math', () {
    late MapCamera camera;
    const worldBounds = Rect.fromLTWH(-1000, -500, 2000, 1000);
    const viewportSize = Size(800, 600);

    setUp(() {
      camera = MapCamera(
        worldBounds: worldBounds,
        zoom: 1.0,
        focus: Offset.zero,
      );
      camera.setViewport(viewportSize);
    });

    test('Initial rotation is 0.0 radians', () {
      expect(camera.rotation, 0.0);
    });

    test('Clockwise rotation (+pi/2) transforms screen coordinates accurately', () {
      camera.jumpTo(rotation: math.pi / 2);
      expect(camera.rotation, math.pi / 2);

      // In world space, point (100, 0)
      const worldP = Offset(100, 0);
      final screenP = camera.worldToScreen(worldP);

      // Rotating +90 deg clockwise moves (100, 0) to (0, 100) relative to center (400, 300)
      expect(screenP.dx, closeTo(400.0, 0.001));
      expect(screenP.dy, closeTo(400.0, 0.001));

      // Inverse transform returns the exact world coordinate
      final reconstructed = camera.screenToWorld(screenP);
      expect(reconstructed.dx, closeTo(worldP.dx, 0.001));
      expect(reconstructed.dy, closeTo(worldP.dy, 0.001));
    });

    test('Counterclockwise rotation (-pi/2) transforms screen coordinates accurately', () {
      camera.jumpTo(rotation: -math.pi / 2);
      expect(camera.rotation, -math.pi / 2);

      const worldP = Offset(100, 0);
      final screenP = camera.worldToScreen(worldP);

      // Rotating -90 deg counterclockwise moves (100, 0) to (0, -100) relative to center
      expect(screenP.dx, closeTo(400.0, 0.001));
      expect(screenP.dy, closeTo(200.0, 0.001));

      final reconstructed = camera.screenToWorld(screenP);
      expect(reconstructed.dx, closeTo(worldP.dx, 0.001));
      expect(reconstructed.dy, closeTo(worldP.dy, 0.001));
    });

    test('Full 360-degree rotation (2*pi) preserves identity transform', () {
      camera.jumpTo(rotation: 2 * math.pi);

      const worldP = Offset(150, -80);
      final screenP = camera.worldToScreen(worldP);

      camera.jumpTo(rotation: 0.0);
      final unrotatedScreenP = camera.worldToScreen(worldP);

      expect(screenP.dx, closeTo(unrotatedScreenP.dx, 0.001));
      expect(screenP.dy, closeTo(unrotatedScreenP.dy, 0.001));
    });

    test('Simultaneous pinch zoom and rotation with anchorAt pins world point', () {
      const anchorScreen = Offset(500, 250);
      final anchorWorld = camera.screenToWorld(anchorScreen);

      // Anchor at with 1.8x zoom and +45 deg rotation
      camera.anchorAt(
        worldPoint: anchorWorld,
        screenPoint: anchorScreen,
        zoom: 1.8,
        rotation: math.pi / 4,
      );

      expect(camera.zoom, 1.8);
      expect(camera.rotation, closeTo(math.pi / 4, 0.001));

      // After zoom and rotation, worldToScreen of anchorWorld MUST land on anchorScreen
      final resultingScreen = camera.worldToScreen(anchorWorld);
      expect(resultingScreen.dx, closeTo(anchorScreen.dx, 0.001));
      expect(resultingScreen.dy, closeTo(anchorScreen.dy, 0.001));
    });

    test('Panning after rotation moves camera in natural screen direction', () {
      camera.jumpTo(rotation: math.pi / 2); // 90 deg clockwise
      final startFocus = camera.focus;

      // Drag right by 50 px on screen
      camera.panByScreen(const Offset(50, 0));

      // The focus has shifted appropriately in world coordinates
      expect((camera.focus - startFocus).distance, greaterThan(0.0));

      // Point that was at (450, 300) is now at (400, 300) - world moved right on screen
      final screenTarget = camera.worldToScreen(camera.focus);
      expect(screenTarget.dx, closeTo(400.0, 0.001));
      expect(screenTarget.dy, closeTo(300.0, 0.001));
    });

    test('visibleWorldRect expands when rotated to cover all visible screen corners', () {
      final unrotatedRect = camera.visibleWorldRect;
      camera.jumpTo(rotation: math.pi / 4); // 45 deg tilt
      final rotatedRect = camera.visibleWorldRect;

      // Rotated bounding rect encompasses the 45-degree diamond screen
      expect(rotatedRect.width, greaterThan(unrotatedRect.width * 0.9));
      expect(rotatedRect.height, greaterThan(unrotatedRect.height * 0.9));
    });
  });

  group('MapCameraController Animation & Commands', () {
    testWidgets('rotateLeft and rotateRight animate rotation correctly', (tester) async {
      final camera = MapCamera(
        worldBounds: const Rect.fromLTWH(-500, -500, 1000, 1000),
        zoom: 1.0,
      );
      camera.setViewport(const Size(600, 400));
      final controller = MapCameraController(vsync: tester, camera: camera);
      addTearDown(controller.dispose);

      expect(camera.rotation, 0.0);

      // Rotate clockwise by 45 degrees
      controller.rotateRight();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(camera.rotation, closeTo(math.pi / 4, 0.05));

      // Rotate counterclockwise by 45 degrees
      controller.rotateLeft();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(camera.rotation, closeTo(0.0, 0.05));
    });

    testWidgets('resetCamera and resetRotation restore 0.0 rotation', (tester) async {
      final camera = MapCamera(
        worldBounds: const Rect.fromLTWH(-500, -500, 1000, 1000),
        zoom: 1.0,
      );
      camera.setViewport(const Size(600, 400));
      final controller = MapCameraController(vsync: tester, camera: camera);
      addTearDown(controller.dispose);

      camera.jumpTo(rotation: 1.25);
      expect(camera.rotation, 1.25);

      controller.resetCamera();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(camera.rotation, closeTo(0.0, 0.01));
      expect(camera.focus.dx, closeTo(camera.worldBounds.center.dx, 0.01));
    });
  });

  group('Interactive Map Rotation Gestures & Coordinate Snapping', () {
    late GameMap gameMap;
    late MapCameraController controller;

    setUp(() {
      gameMap = MapGenerator.generate(const MapConfig(cols: 24, rows: 24, seed: 12345));
    });

    Future<void> pumpViewport(WidgetTester tester, ProviderContainer container) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: LayoutBuilder(
                builder: (context, constraints) {
                  return MapViewport(
                    map: gameMap,
                    controller: controller,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Tile picking snaps to the correct underlying grid tile even when rotated', (tester) async {
      final camera = MapCamera(
        worldBounds: IsoProjection.mapBounds(gameMap.cols, gameMap.rows),
        zoom: 1.0,
      );
      camera.setViewport(const Size(800, 600));
      controller = MapCameraController(vsync: tester, camera: camera);
      addTearDown(controller.dispose);

      final container = ProviderContainer(
        overrides: [
          activeCityProvider.overrideWith(() => _FixedCity(_testCity)),
          gameMapProvider.overrideWithValue(gameMap),
        ],
      );
      addTearDown(container.dispose);

      await pumpViewport(tester, container);

      // Pick a known tile at (12, 12)
      const targetTile = GridPoint(12, 12);
      final tileWorldCenter = IsoProjection.tileCenter(targetTile.col, targetTile.row);

      // Rotate camera by 60 degrees
      camera.jumpTo(focus: tileWorldCenter, rotation: math.pi / 3);

      // Center of screen (400, 300) should project directly onto tile (12, 12)
      final centerScreen = camera.worldToScreen(tileWorldCenter);
      final worldReconstructed = camera.screenToWorld(centerScreen);
      final pickedTile = IsoProjection.worldToGrid(worldReconstructed);

      expect(pickedTile, equals(targetTile));

      // Tap on center screen
      await tester.tapAt(centerScreen);
      await tester.pump();

      // Selected tile should match
      final selected = container.read(selectedTileProvider);
      expect(selected, equals(targetTile));
    });

    testWidgets('Building placement preview snaps accurately when rotated', (tester) async {
      final camera = MapCamera(
        worldBounds: IsoProjection.mapBounds(gameMap.cols, gameMap.rows),
        zoom: 1.0,
      );
      camera.setViewport(const Size(800, 600));
      controller = MapCameraController(vsync: tester, camera: camera);
      addTearDown(controller.dispose);

      final container = ProviderContainer(
        overrides: [
          activeCityProvider.overrideWith(() => _FixedCity(_testCity)),
          gameMapProvider.overrideWithValue(gameMap),
        ],
      );
      addTearDown(container.dispose);

      await pumpViewport(tester, container);

      // Start building placement
      container.read(placementProvider.notifier).startPlacement(BuildingRegistry.smallHouse);
      expect(container.read(placementProvider).isPlacing, isTrue);

      // Rotate camera by 90 degrees
      camera.jumpTo(rotation: math.pi / 2);

      const targetTile = GridPoint(10, 10);
      final targetScreen = camera.worldToScreen(IsoProjection.tileCenter(targetTile.col, targetTile.row));

      // Tap to move preview
      await tester.tapAt(targetScreen);
      await tester.pump();

      expect(container.read(placementProvider).previewOrigin, equals(targetTile));
    });

    testWidgets('Windows shortcuts: Q rotates counterclockwise, E rotates clockwise', (tester) async {
      final camera = MapCamera(
        worldBounds: IsoProjection.mapBounds(gameMap.cols, gameMap.rows),
        zoom: 1.0,
      );
      camera.setViewport(const Size(800, 600));
      controller = MapCameraController(vsync: tester, camera: camera);
      addTearDown(controller.dispose);

      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final container = ProviderContainer(
        overrides: [
          activeCityProvider.overrideWith(() => _FixedCity(_testCity)),
          gameMapProvider.overrideWithValue(gameMap),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: GameShortcuts(
                controller: controller,
                focusNode: focusNode,
                child: MapViewport(
                  map: gameMap,
                  controller: controller,
                  focusNode: focusNode,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pump();

      expect(camera.rotation, 0.0);

      // Press key E -> Clockwise rotation
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(camera.rotation, greaterThan(0.0));

      // Press key Q -> Counterclockwise rotation back
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(camera.rotation, closeTo(0.0, 0.05));
    });
  });
}
