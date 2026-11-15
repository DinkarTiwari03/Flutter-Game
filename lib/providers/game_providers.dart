import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/core/utils/stable_hash.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/map_config.dart';
import 'package:city_builder_2040/game/map/map_generator.dart';
import 'package:city_builder_2040/game/map/tile_info.dart';
import 'package:city_builder_2040/models/city_stats.dart';
import 'package:city_builder_2040/models/game_section.dart';
import 'package:city_builder_2040/models/simulation_speed.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/economy_providers.dart';

/// The terrain of the active city. Generated from the city's id, so the same
/// city always gets the same map.
final gameMapProvider = Provider<GameMap?>((ref) {
  final city = ref.watch(activeCityProvider);
  if (city == null) return null;
  int clampSize(int value) =>
      value.clamp(GameConstants.minMapSize, GameConstants.maxMapSize).toInt();
  return MapGenerator.generate(
    MapConfig(
      cols: clampSize(city.mapWidth),
      rows: clampSize(city.mapHeight),
      seed: stableHash(city.id),
    ),
  );
});

/// Headline numbers for the HUD and dashboard, backed by live simulation snapshots.
final cityStatsProvider = Provider<CityStats?>((ref) {
  final city = ref.watch(activeCityProvider);
  if (city == null) return null;

  final snapshot = ref.watch(cityEconomySnapshotProvider);
  if (snapshot != null) {
    return CityStats.fromSnapshot(snapshot);
  }
  return CityStats.initial(city);
});

/// The tile the player has selected, if any. Resets when the city changes.
class SelectedTileNotifier extends Notifier<GridPoint?> {
  @override
  GridPoint? build() {
    ref.watch(activeCityProvider);
    return null;
  }

  void select(GridPoint? tile) => state = tile;

  void clear() => state = null;
}

final selectedTileProvider = NotifierProvider<SelectedTileNotifier, GridPoint?>(
  SelectedTileNotifier.new,
);

/// Details of the selected tile for the inspection panel.
final selectedTileInfoProvider = Provider<TileInfo?>((ref) {
  final map = ref.watch(gameMapProvider);
  final tile = ref.watch(selectedTileProvider);
  if (map == null || tile == null || !map.contains(tile)) return null;
  return TileInfo.of(map, tile);
});

/// The open navigation section, or `null` when none is open (phone layout
/// closes the section sheet; desktop falls back to Build).
class ActiveSectionNotifier extends Notifier<GameSection?> {
  @override
  GameSection? build() => null;

  /// Opens [section], or closes it when it is already open.
  void toggle(GameSection section) => state = state == section ? null : section;

  void open(GameSection section) => state = section;

  void close() => state = null;
}

final activeSectionProvider =
    NotifierProvider<ActiveSectionNotifier, GameSection?>(
      ActiveSectionNotifier.new,
    );

class ShowGridNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final showGridProvider = NotifierProvider<ShowGridNotifier, bool>(
  ShowGridNotifier.new,
);

class SimulationSpeedNotifier extends Notifier<SimulationSpeed> {
  @override
  SimulationSpeed build() => SimulationSpeed.normal;

  void setSpeed(SimulationSpeed speed) => state = speed;

  void togglePause() {
    if (state.isPaused) {
      state = SimulationSpeed.normal;
    } else {
      state = SimulationSpeed.paused;
    }
  }
}

final simulationSpeedProvider =
    NotifierProvider<SimulationSpeedNotifier, SimulationSpeed>(
      SimulationSpeedNotifier.new,
    );

