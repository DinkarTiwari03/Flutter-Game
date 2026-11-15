import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/core/theme/app_theme.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/city_stats.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/widgets/game/compact_top_bar.dart';
import 'package:city_builder_2040/widgets/game/desktop_top_bar.dart';
import 'package:city_builder_2040/widgets/game/resource_chip.dart';

class _FixedCity extends ActiveCityNotifier {
  _FixedCity(this.city);
  final City city;
  @override
  City? build() => city;
}

void main() {
  group('Resource HUD Widgets', () {
    final now = DateTime.utc(2040, 1, 1);
    final testCity = City(
      id: 'city-1',
      name: 'Cyber City',
      mapWidth: 32,
      mapHeight: 32,
      createdAt: now,
      updatedAt: now,
    );

    testWidgets('CompactTopBar displays all 6 resources including pollution', (tester) async {
      final customStats = const CityStats(
        coins: 25000,
        population: 320,
        electricity: 100,
        water: 100,
        happiness: 85,
        pollution: 15,
        level: 3,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCityProvider.overrideWith(() => _FixedCity(testCity)),
            cityStatsProvider.overrideWith((ref) => customStats),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: CompactTopBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check city name & level
      expect(find.text('Cyber City'), findsOneWidget);
      expect(find.text('Lv. 3'), findsOneWidget);

      // Check resource values
      expect(find.text('25K'), findsOneWidget); // 25000 formatted compact
      expect(find.text('320'), findsOneWidget);
      expect(find.text('100%'), findsNWidgets(2)); // electricity, water
      expect(find.text('85%'), findsOneWidget); // happiness
      expect(find.text('15%'), findsOneWidget); // pollution
    });

    testWidgets('CompactTopBar highlights warnings when resources are low or deficit', (tester) async {
      final deficitStats = const CityStats(
        coins: 200, // low coins (<500)
        population: 50,
        electricity: 40, // deficit (<100)
        water: 30, // deficit (<100)
        happiness: 25, // unhappy (<50)
        pollution: 70, // polluted (>=50)
        level: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCityProvider.overrideWith(() => _FixedCity(testCity)),
            cityStatsProvider.overrideWith((ref) => deficitStats),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: CompactTopBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find all ResourceChips and verify warning flags
      final chips = tester.widgetList<ResourceChip>(find.byType(ResourceChip));
      expect(chips.length, 6);

      // Coins chip is warning
      expect(chips.elementAt(0).isWarning, isTrue);
      // Electricity chip is warning
      expect(chips.elementAt(2).isWarning, isTrue);
      // Water chip is warning
      expect(chips.elementAt(3).isWarning, isTrue);
      // Happiness chip is warning
      expect(chips.elementAt(4).isWarning, isTrue);
      // Pollution chip is warning
      expect(chips.elementAt(5).isWarning, isTrue);
    });

    testWidgets('DesktopTopBar renders resource cards for all 6 resources', (tester) async {
      final customStats = const CityStats(
        coins: 25000,
        population: 500,
        electricity: 100,
        water: 100,
        happiness: 78,
        pollution: 22,
        level: 4,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCityProvider.overrideWith(() => _FixedCity(testCity)),
            cityStatsProvider.overrideWith((ref) => customStats),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: DesktopTopBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final cards = tester.widgetList<ResourceCard>(find.byType(ResourceCard));
      expect(cards.length, 6);

      // Verify labels
      expect(find.text('POLLUTION'), findsOneWidget);
      expect(find.text('HAPPINESS'), findsOneWidget);
      expect(find.text('POWER'), findsOneWidget);
      expect(find.text('WATER'), findsOneWidget);
    });
  });
}
