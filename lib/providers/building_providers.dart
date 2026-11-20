import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/buildings/placement_validator.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/economy_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';
import 'package:city_builder_2040/providers/urban_providers.dart';

/// Manages the collection of placed buildings in the active city.
class CityBuildingsNotifier extends AsyncNotifier<List<Building>> {
  @override
  Future<List<Building>> build() async {
    final city = ref.watch(activeCityProvider);
    if (city == null) return [];
    final service = ref.read(buildingServiceProvider);
    return service.getBuildings(city.id);
  }

  /// Places and persists a new building at [position] with optional [rotation].
  Future<Building> placeBuilding({
    required BuildingDefinition definition,
    required GridPoint position,
    int rotation = 0,
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
      rotation: rotation,
    );

    state = AsyncData([...current, placed]);

    // Immediately notify urban simulation → pedestrians + vehicles near the
    // new building spawn without waiting for the next 0.8 s tick.
    ref.read(urbanSimulationProvider).notifyBuildingPlaced(placed);

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

    // Notify urban simulation: remove activity record (entities live on naturally).
    ref.read(urbanSimulationProvider).notifyBuildingDemolished(buildingId);

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
    for (final t in def.footprintTilesRotated(GridPoint(b.x, b.y), b.rotation)) {
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
    this.rotation = 0,
  });

  final BuildingDefinition? activeDefinition;
  final GridPoint? previewOrigin;
  final PlacementValidationResult? validation;

  /// Current placement orientation in degrees (0, 90, 180, 270).
  final int rotation;

  bool get isPlacing => activeDefinition != null;

  PlacementState copyWith({
    BuildingDefinition? activeDefinition,
    GridPoint? previewOrigin,
    PlacementValidationResult? validation,
    int? rotation,
    bool clearActive = false,
  }) {
    return PlacementState(
      activeDefinition:
          clearActive ? null : (activeDefinition ?? this.activeDefinition),
      previewOrigin: previewOrigin ?? this.previewOrigin,
      validation: validation ?? this.validation,
      rotation: rotation ?? this.rotation,
    );
  }
}

/// Controls building placement preview, coordinates, rotation and confirmation.
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

    const initialRotation = 0;
    final validation =
        map != null
            ? PlacementValidator.validate(
              map: map,
              definition: definition,
              origin: origin,
              existingBuildings: existing,
              rotation: initialRotation,
            )
            : null;

    state = PlacementState(
      activeDefinition: definition,
      previewOrigin: origin,
      validation: validation,
      rotation: initialRotation,
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
              rotation: state.rotation,
            )
            : null;

    state = state.copyWith(previewOrigin: origin, validation: validation);
  }

  /// Rotates the building being placed by 90° clockwise and immediately re-validates.
  void rotateBuilding() {
    final def = state.activeDefinition;
    if (def == null) return;

    final newRotation = (state.rotation + 90) % 360;
    final map = ref.read(gameMapProvider);
    final existing = ref.read(cityBuildingsProvider).value ?? [];
    final origin = state.previewOrigin;

    final validation =
        (map != null && origin != null)
            ? PlacementValidator.validate(
              map: map,
              definition: def,
              origin: origin,
              existingBuildings: existing,
              rotation: newRotation,
            )
            : null;

    state = state.copyWith(rotation: newRotation, validation: validation);
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

    if (def == null || pos == null || !valid) {
      return null;
    }

    final placed = await ref
        .read(cityBuildingsProvider.notifier)
        .placeBuilding(
          definition: def,
          position: pos,
          rotation: state.rotation,
        );

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
