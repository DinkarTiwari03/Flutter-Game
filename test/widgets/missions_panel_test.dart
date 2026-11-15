import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/city_stats.dart';
import 'package:city_builder_2040/models/game_section.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';
import 'package:city_builder_2040/repositories/memory/memory_mission_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_player_progress_repository.dart';
import 'package:city_builder_2040/widgets/game/building_selection_menu.dart';
import 'package:city_builder_2040/widgets/game/missions/missions_main_panel.dart';
import 'package:city_builder_2040/widgets/game/section_panel.dart';

class _TestActiveCityNotifier extends ActiveCityNotifier {
  _TestActiveCityNotifier(this._city);
  final City _city;
  @override
  City? build() => _city;
}

void main() {
  final testCity = City(
    id: 'test_city_prog',
    name: 'Neo Progress',
    createdAt: DateTime.utc(2026, 11, 15),
    updatedAt: DateTime.utc(2026, 11, 15),
    mapWidth: 20,
    mapHeight: 20,
  );

  Widget createTestWidget({
    required Widget child,
    PlayerProgress? initialPlayer,
    List<MissionProgress>? initialMissions,
  }) {
    final playerRepo = MemoryPlayerProgressRepository();
    if (initialPlayer != null) {
      playerRepo.saveProgress(initialPlayer);
    }
    final missionRepo = MemoryMissionRepository();
    if (initialMissions != null) {
      for (final p in initialMissions) {
        missionRepo.saveProgress(p);
      }
    }

    return ProviderScope(
      overrides: [
        activeCityProvider.overrideWith(() => _TestActiveCityNotifier(testCity)),
        playerProgressRepositoryProvider.overrideWithValue(playerRepo),
        missionRepositoryProvider.overrideWithValue(missionRepo),
        cityStatsProvider.overrideWith(
          (ref) => const CityStats(
            coins: 2000,
            population: 100,
            happiness: 80,
            pollution: 10,
            electricityProduced: 200,
            electricityConsumed: 100,
            waterProduced: 200,
            waterConsumed: 100,
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('MissionsMainPanel Widget', () {
    testWidgets('renders all four main tabs', (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const MissionsMainPanel()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Missions'), findsOneWidget);
      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Achievements'), findsOneWidget);
      expect(find.text('Progression'), findsOneWidget);
    });

    testWidgets('switching to Progression tab shows Mayor Level and stats',
        (tester) async {
      final player = PlayerProgress(
        playerId: 'local',
        level: 2,
        experience: 150,
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const MissionsMainPanel(),
          initialPlayer: player,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Progression tab
      await tester.tap(find.text('Progression'));
      await tester.pumpAndSettle();

      expect(find.text('Mayor Level 2'), findsOneWidget);
      expect(find.text('Total XP'), findsOneWidget);
      expect(find.text('Achievements'), findsNWidgets(2));
      expect(find.text('Missions Done'), findsOneWidget);
    });

    testWidgets('switching to Achievements tab displays achievement cards',
        (tester) async {
      final player = PlayerProgress(
        playerId: 'local',
        level: 1,
        experience: 0,
        completedAchievementIds: ['ach_first_build'],
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const MissionsMainPanel(),
          initialPlayer: player,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Achievements tab
      await tester.tap(find.text('Achievements'));
      await tester.pumpAndSettle();

      expect(find.text('The Beginning'), findsOneWidget);
      expect(find.text('Urban Planner'), findsOneWidget);
    });
  });

  group('SectionPanelContent integration', () {
    testWidgets('GameSection.missions renders MissionsMainPanel',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const SectionPanelContent(section: GameSection.missions),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MissionsMainPanel), findsOneWidget);
    });
  });

  group('BuildingSelectionMenu Unlocks', () {
    testWidgets('Level 1 player sees high-level buildings as Locked',
        (tester) async {
      final player = PlayerProgress(
        playerId: 'local',
        level: 1, // Residential tower requires Level 3!
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const BuildingSelectionMenu(
            initialCategory: BuildingCategory.residential,
          ),
          initialPlayer: player,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Small House'), findsOneWidget);
      expect(find.text('Residential Tower'), findsOneWidget);
      expect(find.text('Requires Mayor Level 3'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
    });

    testWidgets('Level 3 player sees Residential Tower as Build-able',
        (tester) async {
      final player = PlayerProgress(
        playerId: 'local',
        level: 3, // Meets Level 3 requirement!
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const BuildingSelectionMenu(
            initialCategory: BuildingCategory.residential,
          ),
          initialPlayer: player,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Requires Mayor Level 3'), findsNothing);
      // Both small house and residential tower should have Build buttons
      expect(find.text('Build'), findsAtLeastNWidgets(2));
    });
  });
}
