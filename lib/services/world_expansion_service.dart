import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';
import 'package:city_builder_2040/game/map/map_config.dart';
import 'package:city_builder_2040/game/map/map_generator.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/game_providers.dart';

/// Result of a world-expansion attempt.
enum ExpansionResult {
  /// The map was successfully expanded.
  success,
  /// Already at the maximum allowed size.
  alreadyMaxSize,
  /// No active city to expand.
  noCityLoaded,
}

/// Grows the playable terrain while preserving all existing tiles.
///
/// The expansion uses the same deterministic [MapGenerator] with the city's
/// original seed, so tiles that the player has never visited look consistent
/// with the original island style.  Existing tiles (the original map region)
/// are always preserved verbatim.
///
/// Usage:
/// ```dart
/// final result = ref.read(worldExpansionServiceProvider).expand(extraTiles: 32);
/// ```
class WorldExpansionService {
  const WorldExpansionService(this._ref);

  final Ref _ref;

  /// Adds [extraTiles] to both dimensions of the current map (symmetric
  /// expansion).  Clamps to [GameConstants.maxMapSize].
  ///
  /// Updates [gameMapProvider] in-place via [ActiveCityNotifier] so the new
  /// dimensions are persisted on the next autosave.
  ExpansionResult expand({int extraTiles = 32}) {
    final city = _ref.read(activeCityProvider);
    if (city == null) return ExpansionResult.noCityLoaded;

    final currentMap = _ref.read(gameMapProvider);
    if (currentMap == null) return ExpansionResult.noCityLoaded;

    final originalCols = currentMap.cols;
    final originalRows = currentMap.rows;

    final newCols = (originalCols + extraTiles)
        .clamp(originalCols, GameConstants.maxMapSize);
    final newRows = (originalRows + extraTiles)
        .clamp(originalRows, GameConstants.maxMapSize);

    if (newCols == originalCols && newRows == originalRows) {
      return ExpansionResult.alreadyMaxSize;
    }

    // 1. Create a blank map of the new size, copying existing tiles.
    final blank = currentMap.expanded(newCols: newCols, newRows: newRows);

    // 2. Generate a fresh map at the new size using the same seed.
    final generated = MapGenerator.generate(
      MapConfig(cols: newCols, rows: newRows, seed: city.seed),
    );

    // 3. Merge: keep existing tiles; fill new area from the generated map.
    final merged = blank.mergeExpanded(
      generated,
      originalCols: originalCols,
      originalRows: originalRows,
    );

    // 4. Persist updated dimensions to the City model so they survive restarts.
    final updatedCity = City(
      id: city.id,
      name: city.name,
      mapWidth: newCols,
      mapHeight: newRows,
      seed: city.seed,
      day: city.day,
      population: city.population,
      createdAt: city.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    _ref.read(activeCityProvider.notifier).open(updatedCity);

    // 5. Update the camera world bounds so panning and zoom limits refresh.
    //    The camera is owned by GameScreen and accessed via a listener on the
    //    gameMapProvider; we trigger that by calling _gameMapOverrideProvider.
    _ref.read(_gameMapOverrideProvider.notifier).setMap(merged);

    return ExpansionResult.success;
  }

  /// World-space bounds of the given map (delegates to IsoProjection).
  static Rect boundsFor(GameMap map) =>
      IsoProjection.mapBounds(map.cols, map.rows);
}

/// Internal override notifier that [WorldExpansionService] writes to.
class _GameMapOverrideNotifier extends Notifier<GameMap?> {
  @override
  GameMap? build() => null;

  void setMap(GameMap? map) => state = map;
}

/// Internal override provider that [WorldExpansionService] writes to.
/// [gameMapProvider] reads from this when non-null so the camera and renderer
/// immediately see the expanded map.
final _gameMapOverrideProvider =
    NotifierProvider<_GameMapOverrideNotifier, GameMap?>(
  _GameMapOverrideNotifier.new,
);

/// A version of [gameMapProvider] that respects the expansion override.
///
/// Wire this into [GameScreen] instead of the original [gameMapProvider] to
/// support in-session world expansion without needing a full restart.
final expandableGameMapProvider = Provider<GameMap?>((ref) {
  final override = ref.watch(_gameMapOverrideProvider);
  if (override != null) return override;
  return ref.watch(gameMapProvider);
});

/// Singleton service provider.
final worldExpansionServiceProvider = Provider<WorldExpansionService>(
  (ref) => WorldExpansionService(ref),
);
