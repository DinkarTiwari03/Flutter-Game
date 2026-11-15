import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/repositories/building_repository.dart';
import 'package:city_builder_2040/repositories/city_repository.dart';
import 'package:city_builder_2040/repositories/local/app_database.dart';
import 'package:city_builder_2040/repositories/local/local_building_repository.dart';
import 'package:city_builder_2040/repositories/local/local_city_repository.dart';
import 'package:city_builder_2040/repositories/local/local_mission_repository.dart';
import 'package:city_builder_2040/repositories/local/local_player_progress_repository.dart';
import 'package:city_builder_2040/repositories/local/local_resource_repository.dart';
import 'package:city_builder_2040/repositories/local/local_settings_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_building_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_city_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_mission_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_player_progress_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_resource_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_settings_repository.dart';
import 'package:city_builder_2040/repositories/mission_repository.dart';
import 'package:city_builder_2040/repositories/player_progress_repository.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';
import 'package:city_builder_2040/repositories/settings_repository.dart';
import 'package:city_builder_2040/services/autosave_service.dart';
import 'package:city_builder_2040/services/building_service.dart';
import 'package:city_builder_2040/services/city_service.dart';
import 'package:city_builder_2040/services/economy_service.dart';
import 'package:city_builder_2040/services/simulation_service.dart';

// ---------------------------------------------------------------------------
// The single place where concrete repository implementations are chosen.
//
// - V1 / Phase 7: local SQLite implementations via Drift when db is provided.
// - Tests and fallback: memory repositories if no database is configured.
// - V3: replace with cloud-backed (or local + sync) implementations the same
//   way. Game logic, providers and screens stay unchanged.
// ---------------------------------------------------------------------------

/// Database provider. Set to an opened [AppDatabase] in `main()`, or overridden
/// with [AppDatabase.openInMemory] in persistence tests. When null, repository
/// providers smoothly fall back to memory implementations.
final appDatabaseProvider = Provider<AppDatabase?>((ref) => null);

final cityRepositoryProvider = Provider<CityRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db != null) return LocalCityRepository(db);
  return MemoryCityRepository();
});

final buildingRepositoryProvider = Provider<BuildingRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db != null) return LocalBuildingRepository(db);
  return MemoryBuildingRepository();
});

final resourceRepositoryProvider = Provider<ResourceRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db != null) return LocalResourceRepository(db);
  return MemoryResourceRepository();
});

final missionRepositoryProvider = Provider<MissionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db != null) return LocalMissionRepository(db);
  return MemoryMissionRepository();
});

final playerProgressRepositoryProvider = Provider<PlayerProgressRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db != null) return LocalPlayerProgressRepository(db);
  return MemoryPlayerProgressRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db != null) return LocalSettingsRepository(db);
  return MemorySettingsRepository();
});

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final economyServiceProvider = Provider<EconomyService>((ref) {
  return EconomyService(
    resources: ref.watch(resourceRepositoryProvider),
  );
});

final cityServiceProvider = Provider<CityService>((ref) {
  return CityService(
    cities: ref.watch(cityRepositoryProvider),
    buildings: ref.watch(buildingRepositoryProvider),
    resources: ref.watch(resourceRepositoryProvider),
    missions: ref.watch(missionRepositoryProvider),
  );
});

final buildingServiceProvider = Provider<BuildingService>((ref) {
  return BuildingService(
    buildings: ref.watch(buildingRepositoryProvider),
    resources: ref.watch(resourceRepositoryProvider),
    economy: ref.watch(economyServiceProvider),
  );
});

final simulationServiceProvider = Provider<SimulationService>((ref) {
  return SimulationService(
    economy: ref.watch(economyServiceProvider),
    resources: ref.watch(resourceRepositoryProvider),
  );
});

final autosaveServiceProvider = Provider<AutosaveService>((ref) {
  return AutosaveService(
    cities: ref.watch(cityRepositoryProvider),
    buildings: ref.watch(buildingRepositoryProvider),
    resources: ref.watch(resourceRepositoryProvider),
    missions: ref.watch(missionRepositoryProvider),
    playerProgress: ref.watch(playerProgressRepositoryProvider),
  );
});
