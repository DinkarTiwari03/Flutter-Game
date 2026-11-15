import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/repositories/building_repository.dart';
import 'package:city_builder_2040/repositories/city_repository.dart';
import 'package:city_builder_2040/repositories/mission_repository.dart';
import 'package:city_builder_2040/repositories/player_progress_repository.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';

/// Prepares and resets a preconfigured demonstration city for exhibitions.
///
/// Designed for short, interactive NBA / department demonstrations:
/// - Provides a showcase layout with residential, commercial, industrial,
///   civic services, energy, water, and green parks.
/// - Grants a high Mayor Level (Level 5) so all building tiers are unlocked.
/// - Grants a healthy municipal treasury (25,000 coins) and stable utilities.
/// - Keeps the demonstration city completely isolated on [demoCityId] so
///   player save slots are never affected.
class ExhibitionService {
  ExhibitionService({
    required CityRepository cities,
    required BuildingRepository buildings,
    required ResourceRepository resources,
    required MissionRepository missions,
    required PlayerProgressRepository playerProgress,
  })  : _cities = cities,
        _buildings = buildings,
        _resources = resources,
        _missions = missions,
        _playerProgress = playerProgress;

  final CityRepository _cities;
  final BuildingRepository _buildings;
  final ResourceRepository _resources;
  final MissionRepository _missions;
  final PlayerProgressRepository _playerProgress;

  static const String demoCityId = 'exhibition_demo_city_2040';
  static const String demoCityName = 'Neo Metropolis 2040 (Demo)';
  static const int demoMapSize = 32;
  static const int demoSeed = 2040;

  /// Loads the existing demonstration city or creates it if not yet founded.
  Future<City> getOrCreateDemoCity() async {
    final existing = await _cities.getCity(demoCityId);
    if (existing != null) return existing;
    return resetDemoCity();
  }

  /// Completely resets the demonstration city to its optimal initial state.
  Future<City> resetDemoCity() async {
    final now = DateTime.now().toUtc();

    // 1. City model
    final city = City(
      id: demoCityId,
      name: demoCityName,
      mapWidth: demoMapSize,
      mapHeight: demoMapSize,
      seed: demoSeed,
      day: 12,
      population: 480,
      createdAt: now,
      updatedAt: now,
    );
    await _cities.saveCity(city);

    // 2. Demonstration buildings
    await _buildings.deleteByCity(demoCityId);
    final demoBuildings = _generateDemoBuildings(now);
    await _buildings.saveBuildings(demoBuildings);

    // 3. Demo resource stockpile (abundant, healthy)
    final ledger = ResourceLedger(
      cityId: demoCityId,
      amounts: {
        ResourceLedger.coinsKey: 25000.0,
        ResourceLedger.populationKey: 480.0,
        ResourceLedger.happinessKey: 88.0,
        ResourceLedger.pollutionKey: 15.0,
      },
      updatedAt: now,
    );
    await _resources.saveLedger(ledger);

    // 4. Progress - unlock all Mayor tiers for the exhibition
    final allBuildingIds = BuildingRegistry.all.keys.toList();
    final progress = PlayerProgress(
      playerId: PlayerProgress.localPlayerId,
      level: 5,
      experience: 1600,
      unlockedIds: allBuildingIds,
      claimedMissionIds: ['m1_first_home', 'm2_housing_expansion'],
      completedAchievementIds: ['first_home', 'urban_planner', 'nature_lover', 'solar_pioneer'],
      updatedAt: now,
    );
    await _playerProgress.saveProgress(progress);

    // 5. Preconfigure mission progresses
    await _missions.deleteByCity(demoCityId);
    final demoMissions = [
      MissionProgress(
        cityId: demoCityId,
        missionId: 'm1_first_home',
        status: MissionStatus.completed,
        progress: 1.0,
        rewardClaimed: true,
        completedAt: now,
        updatedAt: now,
      ),
      MissionProgress(
        cityId: demoCityId,
        missionId: 'm2_housing_expansion',
        status: MissionStatus.completed,
        progress: 1.0,
        rewardClaimed: true,
        completedAt: now,
        updatedAt: now,
      ),
      MissionProgress(
        cityId: demoCityId,
        missionId: 'm3_commercial_hub',
        status: MissionStatus.active,
        progress: 0.65,
        rewardClaimed: false,
        updatedAt: now,
      ),
      MissionProgress(
        cityId: demoCityId,
        missionId: 'm4_renewable_city',
        status: MissionStatus.active,
        progress: 0.80,
        rewardClaimed: false,
        updatedAt: now,
      ),
    ];
    for (final mp in demoMissions) {
      await _missions.saveProgress(mp);
    }

    return city;
  }

  /// Curates an attractive demonstration grid layout around the central crossroads.
  List<Building> _generateDemoBuildings(DateTime now) {
    // Map center is at (16, 16) on a 32x32 grid.
    // The central crossroads in MapGenerator are col 16 and row 16.
    // Buildings are arranged neatly in functional quadrants.
    final list = <Building>[];
    int idCounter = 1;

    void add(String typeId, int x, int y, {int level = 1}) {
      list.add(
        Building(
          id: 'demo_b_${idCounter++}',
          cityId: demoCityId,
          typeId: typeId,
          x: x,
          y: y,
          level: level,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // --- NORTH-WEST QUADRANT: Residential District ---
    add('residential_small', 12, 12, level: 2);
    add('residential_small', 14, 12, level: 2);
    add('apartments', 11, 14, level: 2);
    add('residential_tower', 13, 14, level: 2);
    add('park', 11, 11);

    // --- NORTH-EAST QUADRANT: Civic & Commercial Center ---
    add('shop', 18, 12, level: 2);
    add('mall', 20, 12, level: 2);
    add('office_building', 18, 14, level: 2);
    add('hospital', 21, 14, level: 2);
    add('school', 21, 11, level: 2);

    // --- SOUTH-WEST QUADRANT: Public Safety & Green Sanctuary ---
    add('police_station', 12, 18, level: 2);
    add('fire_station', 14, 18, level: 2);
    add('botanical_garden', 11, 20, level: 2);
    add('water_tower', 14, 21, level: 2);

    // --- SOUTH-EAST QUADRANT: Clean Tech & Utilities ---
    add('solar_plant', 18, 18, level: 2);
    add('solar_plant', 20, 18, level: 2);
    add('factory', 18, 21, level: 2);
    add('water_facility', 21, 21, level: 2);

    return list;
  }
}
