import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/screens/game_screen.dart';
import 'package:city_builder_2040/widgets/game/compact_top_bar.dart';
import 'package:city_builder_2040/widgets/game/game_navigation.dart';
import 'package:city_builder_2040/widgets/game/map_controls.dart';

class _FixedCity extends ActiveCityNotifier {
  _FixedCity(this.city);
  final City city;
  @override
  City? build() => city;
}

final _city = City(
  id: 'controls-test-city',
  name: 'Neo Haven',
  mapWidth: 48,
  mapHeight: 48,
  createdAt: DateTime.utc(2040),
  updatedAt: DateTime.utc(2040),
);

Future<void> _pumpGame(
  WidgetTester tester, {
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(
    top: padding.top,
    bottom: padding.bottom,
    left: padding.left,
    right: padding.right,
  );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);

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
}

void main() {
  group('MapControls Spacing and Positioning Tests', () {
    testWidgets('Portrait: Reset button maintains >= 16px gap below the top HUD on standard screen', (tester) async {
      const screenSize = Size(412, 915);
      await _pumpGame(tester, size: screenSize, padding: const EdgeInsets.only(top: 36));

      final topBarRect = tester.getRect(find.byType(CompactTopBar));
      final resetRect = tester.getRect(find.byKey(const ValueKey('control-fit')));

      // 1. Minimum vertical gap between top HUD bottom edge and Reset button top edge is 16-24px
      final verticalGap = resetRect.top - topBarRect.bottom;
      expect(verticalGap, greaterThanOrEqualTo(16.0));
      expect(verticalGap, lessThanOrEqualTo(24.0));

      // 2. Aligned along the right side of the screen
      expect(resetRect.right, lessThanOrEqualTo(screenSize.width));
      expect(screenSize.width - resetRect.right, AppSpacing.md);
    });

    testWidgets('Portrait notched/punch-hole phone: Respects status bar inset without cramping', (tester) async {
      const screenSize = Size(393, 852); // iPhone 14 Pro / Modern Android with 48px notch
      await _pumpGame(tester, size: screenSize, padding: const EdgeInsets.only(top: 48, bottom: 34));

      final topBarRect = tester.getRect(find.byType(CompactTopBar));
      final resetRect = tester.getRect(find.byKey(const ValueKey('control-fit')));

      final verticalGap = resetRect.top - topBarRect.bottom;
      expect(verticalGap, greaterThanOrEqualTo(16.0));
      expect(verticalGap, lessThanOrEqualTo(24.0));

      // Entire control group remains above the bottom navigation
      final navRect = tester.getRect(find.byType(GameNavigation));
      final gridBtnRect = tester.getRect(find.byKey(const ValueKey('control-grid')));
      expect(gridBtnRect.bottom, lessThan(navRect.top));
    });

    testWidgets('Landscape phone: Reset button maintains >= 16px gap below single-row top HUD', (tester) async {
      const screenSize = Size(915, 412);
      await _pumpGame(tester, size: screenSize, padding: const EdgeInsets.only(left: 48));

      final topBarRect = tester.getRect(find.byType(CompactTopBar));
      final resetRect = tester.getRect(find.byKey(const ValueKey('control-fit')));

      final verticalGap = resetRect.top - topBarRect.bottom;
      expect(verticalGap, greaterThanOrEqualTo(16.0));
      expect(verticalGap, lessThanOrEqualTo(24.0));

      // Remains inside screen height
      final gridBtnRect = tester.getRect(find.byKey(const ValueKey('control-grid')));
      expect(gridBtnRect.bottom, lessThan(screenSize.height));
    });

    testWidgets('Consistent vertical spacing between Reset camera and Grid toggle buttons', (tester) async {
      await _pumpGame(tester, size: const Size(412, 915));

      final resetRect = tester.getRect(find.byKey(const ValueKey('control-fit')));
      final gridRect = tester.getRect(find.byKey(const ValueKey('control-grid')));

      // Spacing between the 2 buttons is AppSpacing.xs (8.0)
      final gap = gridRect.top - resetRect.bottom;
      expect(gap, AppSpacing.xs);

      // Vertically aligned along the right
      expect(resetRect.left, gridRect.left);
    });
  });
}
