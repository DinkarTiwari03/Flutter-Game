import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/game_section.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/screens/game/desktop_game_layout.dart';
import 'package:city_builder_2040/screens/game/phone_game_layout.dart';
import 'package:city_builder_2040/screens/game_screen.dart';
import 'package:city_builder_2040/widgets/game/compact_top_bar.dart';
import 'package:city_builder_2040/widgets/game/desktop_top_bar.dart';
import 'package:city_builder_2040/widgets/game/game_navigation.dart';
import 'package:city_builder_2040/widgets/game/map_viewport.dart';
import 'package:city_builder_2040/widgets/game/section_panel.dart';

class _FixedCity extends ActiveCityNotifier {
  _FixedCity(this.city);
  final City city;
  @override
  City? build() => city;
}

final _testCity = City(
  id: 'desktop-test-city',
  name: 'Metro City',
  mapWidth: 32,
  mapHeight: 32,
  createdAt: DateTime.utc(2040),
  updatedAt: DateTime.utc(2040),
);

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeCityProvider.overrideWith(() => _FixedCity(_testCity)),
      ],
      child: const MaterialApp(
        home: GameScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const desktopSize = Size(1440, 900);
  const phoneSize = Size(412, 915);

  group('Windows Desktop UI Improvements', () {
    testWidgets('Build tool does NOT auto-select on launch and can be toggled', (tester) async {
      await _pumpApp(tester, desktopSize);

      // 1. On launch: Build tool is NOT selected
      expect(find.byKey(const ValueKey('section-panel-build')), findsNothing);

      // 2. Select Build tool in the rail navigation
      await tester.tap(find.byKey(const ValueKey('nav-build')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-panel-build')), findsOneWidget);

      // 3. Deselect Build tool by clicking it again (toggle behavior)
      await tester.tap(find.byKey(const ValueKey('nav-build')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-panel-build')), findsNothing);

      // 4. Re-open Build tool and close via the close [X] button in its header
      await tester.tap(find.byKey(const ValueKey('nav-build')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-panel-build')), findsOneWidget);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.close_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-panel-build')), findsNothing);

      // 5. Switching tools works seamlessly
      await tester.tap(find.byKey(const ValueKey('nav-missions')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-panel-missions')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav-roads')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-panel-roads')), findsOneWidget);
      expect(find.byKey(const ValueKey('section-panel-missions')), findsNothing);
    });

    testWidgets('Clicking on the map deselects the active tool panel', (tester) async {
      await _pumpApp(tester, desktopSize);

      // Open Build tool
      await tester.tap(find.byKey(const ValueKey('nav-build')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-panel-build')), findsOneWidget);

      // Click on the map area
      final mapCenter = tester.getCenter(find.byType(MapViewport));
      await tester.tapAt(mapCenter);
      await tester.pumpAndSettle();

      // Tool panel is dismissed
      expect(find.byKey(const ValueKey('section-panel-build')), findsNothing);
    });

    testWidgets('City map and top dashboard do NOT overlap in desktop layout', (tester) async {
      await _pumpApp(tester, desktopSize);

      final topBarRect = tester.getRect(find.byType(DesktopTopBar));
      final mapRect = tester.getRect(find.byType(MapViewport));

      // The top of the map must be at or below the bottom of DesktopTopBar
      expect(mapRect.top, greaterThanOrEqualTo(topBarRect.bottom - 0.5));
      expect(mapRect.bottom, lessThanOrEqualTo(desktopSize.height));
    });

    testWidgets('Right-side Keys/Info panel can be toggled and map expands', (tester) async {
      await _pumpApp(tester, desktopSize);

      // 1. Right panel is hidden on startup -> Map occupies space up to right margin
      expect(find.byKey(const ValueKey('shortcut-hints')), findsNothing);
      final initialMapRect = tester.getRect(find.byType(MapViewport));
      expect(initialMapRect.right, closeTo(desktopSize.width, 1.0));

      // 2. Click the floating toggle button on the map to show it
      await tester.tap(find.byKey(const ValueKey('btn-map-toggle-inspector')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shortcut-hints')), findsOneWidget);
      final openMapRect = tester.getRect(find.byType(MapViewport));
      // Map width has shrunk to make room for the right panel without overlapping
      expect(openMapRect.width, lessThan(initialMapRect.width));

      // 3. Close the right panel via close button
      await tester.tap(find.byKey(const ValueKey('btn-close-inspector')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shortcut-hints')), findsNothing);
      final closedMapRect = tester.getRect(find.byType(MapViewport));
      // Map has expanded back to the full width
      expect(closedMapRect.width, equals(initialMapRect.width));

      // 4. Toggle via the top bar button
      await tester.tap(find.byKey(const ValueKey('btn-toggle-inspector-topbar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shortcut-hints')), findsOneWidget);

      // 5. Toggle via keyboard shortcut 'H'
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shortcut-hints')), findsNothing);
    });

    testWidgets('Layout adapts to different desktop window resolutions', (tester) async {
      for (final res in [
        const Size(1024, 768),
        const Size(1366, 768),
        const Size(1920, 1080),
        const Size(2560, 1440),
      ]) {
        await _pumpApp(tester, res);
        expect(find.byType(DesktopGameLayout), findsOneWidget);
        expect(find.byType(DesktopTopBar), findsOneWidget);
        expect(find.byType(MapViewport), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Mobile UI Preservation', () {
    testWidgets('Mobile phone uses PhoneGameLayout and keeps original UI', (tester) async {
      await _pumpApp(tester, phoneSize);

      // Uses mobile layout
      expect(find.byType(PhoneGameLayout), findsOneWidget);
      expect(find.byType(DesktopGameLayout), findsNothing);

      // Uses compact top bar, not desktop top bar
      expect(find.byType(CompactTopBar), findsOneWidget);
      expect(find.byType(DesktopTopBar), findsNothing);

      // Uses bottom bar navigation
      expect(find.byType(GameNavigation), findsOneWidget);

      // No desktop toggle buttons leaked into mobile
      expect(find.byKey(const ValueKey('btn-map-toggle-inspector')), findsNothing);
      expect(find.byKey(const ValueKey('btn-toggle-inspector-topbar')), findsNothing);
    });
  });
}
