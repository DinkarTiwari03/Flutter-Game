import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/screens/game/desktop_game_layout.dart';
import 'package:city_builder_2040/screens/game/phone_game_layout.dart';
import 'package:city_builder_2040/screens/game_screen.dart';
import 'package:city_builder_2040/widgets/game/compact_top_bar.dart';
import 'package:city_builder_2040/widgets/game/desktop_top_bar.dart';
import 'package:city_builder_2040/widgets/game/game_navigation.dart';
import 'package:city_builder_2040/widgets/game/map_controls.dart';
import 'package:city_builder_2040/widgets/game/map_viewport.dart';

class _FixedCity extends ActiveCityNotifier {
  _FixedCity(this.city);
  final City city;
  @override
  City? build() => city;
}

final _city = City(
  id: 'overlay-test-city',
  name: 'Metropolis',
  mapWidth: 48,
  mapHeight: 48,
  createdAt: DateTime.utc(2040),
  updatedAt: DateTime.utc(2040),
);

Future<WidgetTester> _pumpOverlayGame(WidgetTester tester, Size size) async {
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
  return tester;
}

void main() {
  group('Immersive Top HUD & Bottom Navigation Overlay (Clash of Clans style)', () {
    testWidgets('Phone portrait: Map fills full screen behind top HUD and bottom navigation', (tester) async {
      const screenSize = Size(412, 915);
      await _pumpOverlayGame(tester, screenSize);

      // 1. Verify MapViewport spans the full screen height (0 to 915)
      final viewportFinder = find.byType(MapViewport);
      expect(viewportFinder, findsOneWidget);
      final viewportRect = tester.getRect(viewportFinder);
      expect(viewportRect.top, 0.0);
      expect(viewportRect.left, 0.0);
      expect(viewportRect.width, screenSize.width);
      expect(viewportRect.height, screenSize.height);

      // 2. Verify Top HUD is positioned at the top of the screen
      final topBarFinder = find.byType(CompactTopBar);
      expect(topBarFinder, findsOneWidget);
      final topBarRect = tester.getRect(topBarFinder);
      expect(topBarRect.top, 0.0);
      expect(topBarRect.left, 0.0);
      expect(topBarRect.right, screenSize.width);

      // 3. Verify Bottom Navigation is positioned at the bottom of the screen
      final navFinder = find.byType(GameNavigation);
      expect(navFinder, findsOneWidget);
      final navRect = tester.getRect(navFinder);
      expect(navRect.bottom, screenSize.height);

      // 4. Verify MapControls sits safely below the top HUD
      final controlsFinder = find.byType(MapControls);
      expect(controlsFinder, findsOneWidget);
      final controlsRect = tester.getRect(controlsFinder);
      expect(controlsRect.top, greaterThanOrEqualTo(topBarRect.bottom - 10));

      // 5. Verify Z-ordering: in PhoneGameLayout Stack, top bar and nav are after MapViewport
      final stackFinder = find.descendant(
        of: find.byType(PhoneGameLayout),
        matching: find.byType(Stack),
      ).first;
      final stackWidget = tester.widget<Stack>(stackFinder);
      final childTypes = stackWidget.children.map((w) => w.runtimeType).toList();
      expect(childTypes.length, greaterThanOrEqualTo(4));
    });

    testWidgets('Phone landscape: Map fills full screen with rail navigation', (tester) async {
      const screenSize = Size(915, 412);
      await _pumpOverlayGame(tester, screenSize);

      // MapViewport spans full screen
      final viewportRect = tester.getRect(find.byType(MapViewport));
      expect(viewportRect.top, 0.0);
      expect(viewportRect.left, 0.0);
      expect(viewportRect.width, screenSize.width);
      expect(viewportRect.height, screenSize.height);

      // CompactTopBar in singleRow mode sits at the top
      expect(find.byType(CompactTopBar), findsOneWidget);
      expect(tester.getRect(find.byType(CompactTopBar)).top, 0.0);

      // GameNavigation sits at left = 0
      final navRect = tester.getRect(find.byType(GameNavigation));
      expect(navRect.left, 0.0);
      expect(navRect.bottom, screenSize.height);
    });

    testWidgets('Desktop: Map and dashboard render without overflow', (tester) async {
      const screenSize = Size(1440, 900);
      await _pumpOverlayGame(tester, screenSize);

      expect(find.byType(DesktopTopBar), findsOneWidget);
      expect(find.byType(DesktopGameLayout), findsOneWidget);
      expect(find.byType(MapViewport), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pannable world moves without moving stationary HUD overlays', (tester) async {
      const screenSize = Size(412, 915);
      await _pumpOverlayGame(tester, screenSize);

      final state = tester.state(find.byType(GameScreen)) as dynamic;
      final camera = state.camera as MapCamera;

      final initialTopBarRect = tester.getRect(find.byType(CompactTopBar));
      final initialNavRect = tester.getRect(find.byType(GameNavigation));
      final initialFocus = camera.focus;

      // Pan the world via drag
      final gesture = await tester.startGesture(const Offset(206, 500));
      await gesture.moveBy(const Offset(50, 30));
      await gesture.up();
      await tester.pump();

      // Camera focus moved
      expect(camera.focus, isNot(equals(initialFocus)));

      // Top HUD and Bottom Navigation remain strictly stationary
      expect(tester.getRect(find.byType(CompactTopBar)), equals(initialTopBarRect));
      expect(tester.getRect(find.byType(GameNavigation)), equals(initialNavRect));
    });
  });
}
