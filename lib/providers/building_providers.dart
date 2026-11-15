import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/buildings/placement_validator.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/economy_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';

/// Manages the collection of placed buildings in the active city.
class CityBuildingsNotifier extends AsyncNotifier<List<Building>> {
  @override
  Future<List<Building>> build() async {
    final city = ref.watch(activeCityProvider);
    if (city == null) return [];
    final service = ref.read(buildingServiceProvider);
    return service.getBuildings(city.id);
  }

  /// Places and persists a new building at [position].
  Future<Building> placeBuilding({
    required BuildingDefinition definition,
    required GridPoint position,
  }) async {
    final city = ref.read(activeCityProvider);
    if (city == null) throw StateError('No city loaded.');
    final map = ref.read(gameMapProvider);
    if (map == null) throw StateError('No map loaded.');

    final current = state.value ?? [];
    final service = ref.read(buildingServiceProvider);

    final placed = await service.placeBuilding(
      cityId: city.id,
      definition: definition,
      position: position,
      map: map,
      existingBuildings: current,
    );

    state = AsyncData([...current, placed]);
    await ref.read(cityLedgerProvider.notifier).reload();
    return placed;
  }

  /// Upgrades the specified building to its next tier.
  Future<Building> upgradeBuilding(String buildingId) async {
    final city = ref.read(activeCityProvider);
    if (city == null) throw StateError('No city loaded.');
    final current = state.value ?? [];
    final service = ref.read(buildingServiceProvider);

    final upgraded = await service.upgradeBuilding(
      cityId: city.id,
      buildingId: buildingId,
      currentBuildings: current,
    );

    state = AsyncData(
      current.map((b) => b.id == buildingId ? upgraded : b).toList(),
    );
    await ref.read(cityLedgerProvider.notifier).reload();
    return upgraded;
  }

  /// Demolishes the specified building from the city.
  Future<int> demolishBuilding(String buildingId) async {
    final city = ref.read(activeCityProvider);
    if (city == null) throw StateError('No city loaded.');
    final current = state.value ?? [];
    final service = ref.read(buildingServiceProvider);

    final refund = await service.demolishBuilding(
      cityId: city.id,
      buildingId: buildingId,
      currentBuildings: current,
    );

    state = AsyncData(current.where((b) => b.id != buildingId).toList());
    await ref.read(cityLedgerProvider.notifier).reload();
    return refund;
  }
}

final cityBuildingsProvider =
    AsyncNotifierProvider<CityBuildingsNotifier, List<Building>>(
      CityBuildingsNotifier.new,
    );

/// Spatial map lookup: maps every occupied [GridPoint] to its building.
final buildingOccupancyProvider = Provider<Map<GridPoint, Building>>((ref) {
  final buildingsAsync = ref.watch(cityBuildingsProvider);
  final buildings = buildingsAsync.value ?? const [];
  final map = <GridPoint, Building>{};

  for (final b in buildings) {
    final def = BuildingRegistry.get(b.typeId);
    if (def == null) continue;
    for (final t in def.footprintTiles(GridPoint(b.x, b.y))) {
      map[t] = b;
    }
  }
  return map;
});

/// Current interactive state of building placement.
class PlacementState {
  const PlacementState({
    this.activeDefinition,
    this.previewOrigin,
    this.validation,
  });

  final BuildingDefinition? activeDefinition;
  final GridPoint? previewOrigin;
  final PlacementValidationResult? validation;

  bool get isPlacing => activeDefinition != null;

  PlacementState copyWith({
    BuildingDefinition? activeDefinition,
    GridPoint? previewOrigin,
    PlacementValidationResult? validation,
    bool clearActive = false,
  }) {
    return PlacementState(
      activeDefinition:
          clearActive ? null : (activeDefinition ?? this.activeDefinition),
      previewOrigin: previewOrigin ?? this.previewOrigin,
      validation: validation ?? this.validation,
    );
  }
}

/// Controls building placement preview, coordinates and confirmation.
class PlacementNotifier extends Notifier<PlacementState> {
  @override
  PlacementState build() => const PlacementState();

  /// Enters placement mode for [definition].
  void startPlacement(BuildingDefinition definition, [GridPoint? initialPos]) {
    final map = ref.read(gameMapProvider);
    final existing = ref.read(cityBuildingsProvider).value ?? [];
    final origin =
        initialPos ??
        (map != null
            ? GridPoint(map.cols ~/ 2, map.rows ~/ 2)
            : const GridPoint(0, 0));

    final validation =
        map != null
            ? PlacementValidator.validate(
              map: map,
              definition: definition,
              origin: origin,
              existingBuildings: existing,
            )
            : null;

    state = PlacementState(
      activeDefinition: definition,
      previewOrigin: origin,
      validation: validation,
    );
  }

  /// Updates the preview location of the building being placed.
  void updatePreview(GridPoint origin) {
    final def = state.activeDefinition;
    if (def == null) return;
    if (state.previewOrigin == origin) return;

    final map = ref.read(gameMapProvider);
    final existing = ref.read(cityBuildingsProvider).value ?? [];

    final validation =
        map != null
            ? PlacementValidator.validate(
              map: map,
              definition: def,
              origin: origin,
              existingBuildings: existing,
            )
            : null;

    state = state.copyWith(previewOrigin: origin, validation: validation);
  }

  /// Cancels placement mode.
  void cancelPlacement() {
    state = const PlacementState();
  }

  /// Confirms and places the currently previewed building.
  Future<Building?> confirmPlacement() async {
    final def = state.activeDefinition;
    final pos = state.previewOrigin;
    final valid = state.validation?.isValid ?? false;

    if (def == null || pos == null || !valid) return null;

    final placed = await ref
        .read(cityBuildingsProvider.notifier)
        .placeBuilding(definition: def, position: pos);

    cancelPlacement();
    ref.read(selectedBuildingIdProvider.notifier).select(placed.id);
    return placed;
  }
}

final placementProvider = NotifierProvider<PlacementNotifier, PlacementState>(
  PlacementNotifier.new,
);

/// The currently selected placed building's ID, or null.
class SelectedBuildingIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;

  void clear() => state = null;
}

final selectedBuildingIdProvider =
    NotifierProvider<SelectedBuildingIdNotifier, String?>(
      SelectedBuildingIdNotifier.new,
    );

/// Resolves the currently selected [Building] instance, or null.
final selectedBuildingProvider = Provider<Building?>((ref) {
  final id = ref.watch(selectedBuildingIdProvider);
  if (id == null) return null;
  final buildings = ref.watch(cityBuildingsProvider).value ?? [];
  final match = buildings.where((b) => b.id == id);
  return match.isEmpty ? null : match.first;
});
