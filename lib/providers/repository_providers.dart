import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/repositories/building_repository.dart';
import 'package:city_builder_2040/repositories/city_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_building_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_city_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_mission_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_player_progress_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_resource_repository.dart';
import 'package:city_builder_2040/repositories/mission_repository.dart';
import 'package:city_builder_2040/repositories/player_progress_repository.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';
import 'package:city_builder_2040/services/building_service.dart';
import 'package:city_builder_2040/services/city_service.dart';

// The single place where concrete repository implementations are chosen.
// Everything else depends on the interfaces only.
//
// - V1 / Phase 7: replace the memory implementations with local-database
//   ones (here, or via ProviderScope overrides in main.dart).
// - V3: replace with cloud-backed (or local + sync) implementations the same
//   way. Game logic, providers and screens stay unchanged.

final cityRepositoryProvider = Provider<CityRepository>(
  (ref) => MemoryCityRepository(),
);

final buildingRepositoryProvider = Provider<BuildingRepository>(
  (ref) => MemoryBuildingRepository(),
);

final resourceRepositoryProvider = Provider<ResourceRepository>(
  (ref) => MemoryResourceRepository(),
);

final missionRepositoryProvider = Provider<MissionRepository>(
  (ref) => MemoryMissionRepository(),
);

final playerProgressRepositoryProvider = Provider<PlayerProgressRepository>(
  (ref) => MemoryPlayerProgressRepository(),
);

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
  );
});
