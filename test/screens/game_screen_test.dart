import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/app.dart';
import 'package:city_builder_2040/core/constants/app_routes.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/game_section.dart';
import 'package:city_builder_2040/models/simulation_speed.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/bootstrap_provider.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/screens/game_screen.dart';
import 'package:city_builder_2040/widgets/game/compact_top_bar.dart';
import 'package:city_builder_2040/widgets/game/desktop_top_bar.dart';
import 'package:city_builder_2040/widgets/game/map_viewport.dart';

class _FixedCity extends ActiveCityNotifier {
  _FixedCity(this.city);

  final City city;

  @override
  City? build() => city;
}

final _city = City(
  id: 'test-city',
  name: 'Testville',
  mapWidth: 48,
  mapHeight: 48,
  createdAt: DateTime.utc(2040),
  updatedAt: DateTime.utc(2040),
);

class _Harness {
  _Harness(this.tester, this.container);

  final WidgetTester tester;
  final ProviderContainer container;

  Finder get viewport => find.byType(MapViewport);

  MapCamera get camera {
    final state = tester.state(find.byType(GameScreen)) as dynamic;
    return state.camera as MapCamera;
  }

  Offset get center => tester.getCenter(viewport);
}

Future<_Harness> _pumpGame(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [activeCityProvider.overrideWith(() => _FixedCity(_city))],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GameScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return _Harness(tester, container);
}

/// Starts and runs any pending camera/selection animation to completion.
/// The first pump lets tickers start; the second advances past the longest
/// animation.
Future<void> _animate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

const _phone = Size(412, 915);
const _phoneLandscape = Size(915, 412);
const _desktop = Size(1440, 900);

/// Finds the screen position of a tile of the given [type], visible now.
Offset? _screenOfTile(_Harness h, TileType type) {
  final map = h.container.read(gameMapProvider)!;
  final camera = h.camera;
  final view = Offset.zero & camera.viewport;
  // Exclude the top-right area where MapControls sits.
  final controlsRect = Rect.fromLTRB(view.width - 80, 0, view.width, 260);
  for (var r = 0; r < map.rows; r++) {
    for (var c = 0; c < map.cols; c++) {
      if (map.typeAt(c, r) != type) continue;
      final world = IsoProjection.tileCenter(c, r);
      final screen = camera.worldToScreen(world);
      if (view.deflate(40).contains(screen) && !controlsRect.contains(screen)) {
        return h.tester.getTopLeft(h.viewport) + screen;
      }
    }
  }
  return null;
}

void main() {
  group('layouts', () {
    testWidgets('phone portrait: compact bar and bottom navigation', (
      tester,
    ) async {
      await _pumpGame(tester, _phone);
      expect(find.byType(CompactTopBar), findsOneWidget);
      expect(find.byType(DesktopTopBar), findsNothing);
      expect(find.text('Testville'), findsOneWidget);
      expect(find.text('Lv. 1'), findsOneWidget);
      expect(find.text('25K'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('100%'), findsWidgets);
      for (final section in GameSection.values) {
        expect(find.text(section.label), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('shortcut-hints')), findsNothing);
    });

    testWidgets('phone landscape: navigation moves to a side rail', (
      tester,
    ) async {
      await _pumpGame(tester, _phoneLandscape);
      expect(find.byType(CompactTopBar), findsOneWidget);
      final nav = tester.getTopLeft(find.byKey(const ValueKey('nav-build')));
      expect(nav.dx, lessThan(100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop: dashboard, section panel and inspector', (
      tester,
    ) async {
      await _pumpGame(tester, _desktop);
      expect(find.byType(DesktopTopBar), findsOneWidget);
      expect(find.byType(CompactTopBar), findsNothing);
      expect(find.byKey(const ValueKey('section-panel-build')), findsOneWidget);
      expect(find.byKey(const ValueKey('tile-info-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('shortcut-hints')), findsOneWidget);
      expect(find.text('25,000'), findsOneWidget);
    });

    testWidgets('small layouts do not overflow', (tester) async {
      for (final size in const [
        Size(320, 568),
        Size(360, 640),
        Size(600, 960),
        Size(800, 600),
        Size(1000, 560),
      ]) {
        await _pumpGame(tester, size);
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });

  group('touch input', () {
    testWidgets('tapping a grass tile selects it and shows the info card', (
      tester,
    ) async {
      final h = await _pumpGame(tester, _phone);
      final target = _screenOfTile(h, TileType.grass)!;

      await tester.tapAt(target);
      await _animate(tester);

      final selected = h.container.read(selectedTileProvider);
      expect(selected, isNotNull);
      expect(
        h.container.read(gameMapProvider)!.typeAt(selected!.col, selected.row),
        TileType.grass,
      );
      expect(find.byKey(const ValueKey('tile-info-panel')), findsOneWidget);
    });

    testWidgets('tapping a road shows road details', (tester) async {
      final h = await _pumpGame(tester, _phone);
      final target = _screenOfTile(h, TileType.road)!;

      await tester.tapAt(target);
      await _animate(tester);

      expect(h.container.read(selectedTileInfoProvider)!.isRoad, isTrue);
      expect(find.text('Road'), findsWidgets);
    });

    testWidgets('dragging pans the camera and never selects', (tester) async {
      final h = await _pumpGame(tester, _phone);
      final before = h.camera.focus;
      final start = h.center;

      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(40, 20));
      await gesture.up();
      await _animate(tester);

      expect(h.camera.focus, isNot(before));
      expect(h.container.read(selectedTileProvider), isNull);
    });

    testWidgets('a tiny wobble still counts as a tap', (tester) async {
      final h = await _pumpGame(tester, _phone);
      final target = _screenOfTile(h, TileType.grass)!;

      final gesture = await tester.startGesture(target);
      await gesture.moveBy(const Offset(3, 2));
      await gesture.up();
      await _animate(tester);

      expect(h.container.read(selectedTileProvider), isNotNull);
    });

    testWidgets('pinching zooms and does not select', (tester) async {
      final h = await _pumpGame(tester, _phone);
      final zoomBefore = h.camera.zoom;
      final c = h.center;

      final a = await tester.startGesture(c + const Offset(-30, 0), pointer: 1);
      final b = await tester.startGesture(c + const Offset(30, 0), pointer: 2);
      await a.moveTo(c + const Offset(-90, 0));
      await b.moveTo(c + const Offset(90, 0));
      await a.up();
      await b.up();
      await _animate(tester);

      expect(h.camera.zoom, greaterThan(zoomBefore * 2));
      expect(h.container.read(selectedTileProvider), isNull);
    });

    testWidgets('lifting one finger after a pinch does not select', (
      tester,
    ) async {
      final h = await _pumpGame(tester, _phone);
      final c = h.center;

      final a = await tester.startGesture(c + const Offset(-30, 0), pointer: 1);
      final b = await tester.startGesture(c + const Offset(30, 0), pointer: 2);
      await a.moveTo(c + const Offset(-50, 0));
      await b.up();
      await a.up();
      await _animate(tester);

      expect(h.container.read(selectedTileProvider), isNull);
    });

    testWidgets('zoom is limited', (tester) async {
      final h = await _pumpGame(tester, _phone);
      final c = h.center;
      final a = await tester.startGesture(c + const Offset(-5, 0), pointer: 1);
      final b = await tester.startGesture(c + const Offset(5, 0), pointer: 2);
      await a.moveTo(c + const Offset(-200, 0));
      await b.moveTo(c + const Offset(200, 0));
      await a.up();
      await b.up();
      await tester.pump();
      expect(h.camera.zoom, h.camera.maxZoom);
    });
  });

  group('mouse input', () {
    testWidgets('left click selects, with hover highlight beforehand', (
      tester,
    ) async {
      final h = await _pumpGame(tester, _desktop);
      final target = _screenOfTile(h, TileType.grass)!;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: target);
      await mouse.moveTo(target);
      await tester.pump();
      await mouse.down(target);
      await mouse.up();
      await _animate(tester);

      expect(h.container.read(selectedTileProvider), isNotNull);
      expect(find.byKey(const ValueKey('tile-info-panel')), findsOneWidget);
    });

    testWidgets('left-button drag pans and does not select', (tester) async {
      final h = await _pumpGame(tester, _desktop);
      final before = h.camera.focus;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);

      await mouse.down(h.center);
      await mouse.moveBy(const Offset(60, 30));
      await mouse.up();
      await tester.pump();

      expect(h.camera.focus, isNot(before));
      expect(h.container.read(selectedTileProvider), isNull);
    });

    testWidgets('right-button drag pans and does not select', (tester) async {
      final h = await _pumpGame(tester, _desktop);
      final before = h.camera.focus;
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      addTearDown(mouse.removePointer);

      await mouse.down(h.center);
      await mouse.moveBy(const Offset(50, 0));
      await mouse.up();
      await tester.pump();

      expect(h.camera.focus, isNot(before));
      expect(h.container.read(selectedTileProvider), isNull);
    });

    testWidgets('mouse wheel zooms around the cursor', (tester) async {
      final h = await _pumpGame(tester, _desktop);
      final zoomBefore = h.camera.zoom;
      final cursor = h.center + const Offset(80, 40);
      final worldBefore = h.camera.screenToWorld(
        cursor - tester.getTopLeft(h.viewport),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: cursor);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: cursor,
          scrollDelta: const Offset(0, -240),
        ),
      );
      await _animate(tester);

      expect(h.camera.zoom, greaterThan(zoomBefore));
      final worldAfter = h.camera.screenToWorld(
        cursor - tester.getTopLeft(h.viewport),
      );
      expect(worldAfter.dx, closeTo(worldBefore.dx, 0.5));
      expect(worldAfter.dy, closeTo(worldBefore.dy, 0.5));

      final zoomMid = h.camera.zoom;
      await tester.sendEventToBinding(
        PointerScrollEvent(position: cursor, scrollDelta: const Offset(0, 480)),
      );
      await _animate(tester);
      expect(h.camera.zoom, lessThan(zoomMid));
    });
  });

  group('keyboard and controls', () {
    testWidgets('arrow keys and WASD pan the camera', (tester) async {
      final h = await _pumpGame(tester, _desktop);
      final start = h.camera.focus;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _animate(tester);
      expect(h.camera.focus.dx, greaterThan(start.dx));

      final afterRight = h.camera.focus;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await _animate(tester);
      expect(h.camera.focus.dy, greaterThan(afterRight.dy));
    });

    testWidgets('plus and minus zoom, Home fits the map', (tester) async {
      final h = await _pumpGame(tester, _desktop);
      final start = h.camera.zoom;

      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await _animate(tester);
      expect(h.camera.zoom, greaterThan(start));

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await _animate(tester);
      expect(h.camera.zoom, closeTo(h.camera.fitZoom, 0.01));
    });

    testWidgets('number keys switch sections and G toggles the grid', (
      tester,
    ) async {
      final h = await _pumpGame(tester, _desktop);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.container.read(activeSectionProvider), GameSection.economy);
      expect(
        find.byKey(const ValueKey('section-panel-economy')),
        findsOneWidget,
      );

      expect(h.container.read(showGridProvider), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      expect(h.container.read(showGridProvider), isFalse);
    });

    testWidgets('Escape clears the selection', (tester) async {
      final h = await _pumpGame(tester, _desktop);
      h.container
          .read(selectedTileProvider.notifier)
          .select(const GridPoint(24, 24));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('tile-info-panel')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.container.read(selectedTileProvider), isNull);
    });

    testWidgets('Space toggles simulation pause', (tester) async {
      final h = await _pumpGame(tester, _desktop);
      expect(h.container.read(simulationSpeedProvider).isPaused, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(h.container.read(simulationSpeedProvider).isPaused, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(h.container.read(simulationSpeedProvider).isPaused, isFalse);
    });

    testWidgets('simulation speed controls can pause and change speed', (
      tester,
    ) async {
      final h = await _pumpGame(tester, _desktop);
      expect(h.container.read(simulationSpeedProvider), SimulationSpeed.normal);

      await tester.tap(find.text('2x'));
      await tester.pump();
      expect(h.container.read(simulationSpeedProvider), SimulationSpeed.fast);

      await tester.tap(find.byTooltip('Pause simulation'));
      await tester.pump();
      expect(h.container.read(simulationSpeedProvider).isPaused, isTrue);
    });

    testWidgets('on-screen zoom buttons work', (tester) async {
      final h = await _pumpGame(tester, _phone);
      final start = h.camera.zoom;

      await tester.tap(find.byKey(const ValueKey('control-zoom-in')));
      await _animate(tester);
      expect(h.camera.zoom, greaterThan(start));

      await tester.tap(find.byKey(const ValueKey('control-zoom-out')));
      await _animate(tester);
      expect(h.camera.zoom, closeTo(start, 0.01));
    });

    testWidgets('phone: nav opens and closes a section sheet', (tester) async {
      final h = await _pumpGame(tester, _phone);

      await tester.tap(find.byKey(const ValueKey('nav-statistics')));
      await _animate(tester);
      expect(h.container.read(activeSectionProvider), GameSection.statistics);
      expect(
        find.byKey(const ValueKey('section-sheet-statistics')),
        findsOneWidget,
      );
      expect(find.text('48 x 48 tiles'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav-statistics')));
      await _animate(tester);
      expect(h.container.read(activeSectionProvider), isNull);
    });

    testWidgets('desktop: nav switches the side panel', (tester) async {
      await _pumpGame(tester, _desktop);
      await tester.tap(find.byKey(const ValueKey('nav-missions')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey('section-panel-missions')),
        findsOneWidget,
      );
    });
  });

  group('rendering performance', () {
    testWidgets(
      'a large map renders with a bounded number of recorded chunks',
      (tester) async {
        tester.view.physicalSize = _desktop;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final big = City(
          id: 'big',
          name: 'Big',
          mapWidth: 256,
          mapHeight: 256,
          createdAt: DateTime.utc(2040),
          updatedAt: DateTime.utc(2040),
        );
        final container = ProviderContainer(
          overrides: [activeCityProvider.overrideWith(() => _FixedCity(big))],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: GameScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        final h = _Harness(tester, container);
        final stopwatch = Stopwatch()..start();
        for (var i = 0; i < 30; i++) {
          h.camera.panByScreen(const Offset(25, 15));
          await tester.pump(const Duration(milliseconds: 16));
        }
        stopwatch.stop();

        expect(tester.takeException(), isNull);
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      },
    );
  });

  testWidgets('the New Game flow starts a city and opens the map', (
    tester,
  ) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [bootstrapProvider.overrideWith((ref) async {})],
        child: const CityBuilderApp(),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushReplacementNamed(AppRoutes.newGame);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('city-name-field')),
      'Aurora',
    );
    await tester.tap(find.byKey(const ValueKey('map-size-small')));
    await tester.pump();
    await tester.tap(find.text('Start city'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('Aurora'), findsOneWidget);
  });

  testWidgets('New Game rejects an empty name', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [bootstrapProvider.overrideWith((ref) async {})],
        child: const CityBuilderApp(),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushReplacementNamed(AppRoutes.newGame);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('city-name-field')),
      '   ',
    );
    await tester.tap(find.text('Start city'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('City name cannot be empty.'), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
  });
}
