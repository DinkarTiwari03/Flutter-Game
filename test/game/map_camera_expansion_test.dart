import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';
import 'package:city_builder_2040/game/map/map_config.dart';
import 'package:city_builder_2040/game/map/map_generator.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/services/world_expansion_service.dart';

void main() {
  group('MapCamera Adaptive Viewport & Minecraft-Style Zoom', () {
    test('non-adaptive camera respects fixed minZoom limit', () {
      final camera = MapCamera(
        worldBounds: const Rect.fromLTRB(-1000, 0, 1000, 2000),
        zoom: 1.0,
        minZoom: 0.3,
        adaptiveMinZoom: false,
      );
      camera.setViewport(const Size(400, 800));

      camera.jumpTo(zoom: 0.001);
      expect(camera.zoom, 0.3);
    });

    test('adaptiveMinZoom adapts lower zoom limit to viewport size', () {
      final camera = MapCamera(
        worldBounds: const Rect.fromLTRB(-500, 0, 500, 1000), // 1000 x 1000
        zoom: 1.0,
        adaptiveMinZoom: true,
      );
      // Small phone viewport: 360 x 720
      camera.setViewport(const Size(360, 720));
      // fit = min(360/1000, 720/1000) = 0.36
      expect(camera.effectiveMinZoom, closeTo(0.36, 1e-4));

      // Attempt to zoom out beyond fitZoom
      camera.jumpTo(zoom: 0.05);
      // It must be clamped to effectiveMinZoom (no tiny island in purple void)
      expect(camera.zoom, closeTo(0.36, 1e-4));
    });

    test('adaptiveMinZoom updates when viewport resizes (e.g. rotation / window resize)', () {
      final camera = MapCamera(
        worldBounds: const Rect.fromLTRB(-1000, 0, 1000, 2000), // 2000 x 2000
        zoom: 1.0,
        adaptiveMinZoom: true,
      );
      // Initial portrait
      camera.setViewport(const Size(400, 800));
      final portraitMin = camera.effectiveMinZoom;
      expect(portraitMin, closeTo(0.2, 1e-4)); // min(400/2000, 800/2000) = 0.2

      // Switch to landscape: 800 x 400
      camera.setViewport(const Size(800, 400));
      final landscapeMin = camera.effectiveMinZoom;
      expect(landscapeMin, closeTo(0.2, 1e-4));

      // Larger tablet / desktop viewport: 1200 x 900
      camera.setViewport(const Size(1200, 900));
      expect(camera.effectiveMinZoom, closeTo(0.45, 1e-4)); // min(1200/2000, 900/2000) = 0.45
    });

    test('jumpToFit centers and scales map to fill viewport', () {
      final camera = MapCamera(
        worldBounds: const Rect.fromLTRB(-500, 0, 500, 1000),
        zoom: 1.5,
        adaptiveMinZoom: true,
      );
      camera.setViewport(const Size(400, 800));
      camera.jumpToFit();

      expect(camera.zoom, closeTo(0.4, 1e-4)); // min(400/1000, 800/1000) = 0.4
      expect(camera.focus, camera.worldBounds.center);
    });

    test('fillZoom covers viewport in both dimensions', () {
      final camera = MapCamera(
        worldBounds: const Rect.fromLTRB(-500, 0, 500, 1000), // 1000 x 1000
        adaptiveMinZoom: true,
      );
      camera.setViewport(const Size(400, 800));
      // fillZoom = max(400/1000, 800/1000) = 0.8
      expect(camera.fillZoom, closeTo(0.8, 1e-4));
    });
  });

  group('Expandable World System', () {
    test('GameMap.expanded increases dimensions and preserves existing tiles', () {
      final original = MapGenerator.generate(
        MapConfig(cols: 16, rows: 16, seed: 42),
      );
      expect(original.cols, 16);
      expect(original.rows, 16);

      final expanded = original.expanded(newCols: 32, newRows: 32);
      expect(expanded.cols, 32);
      expect(expanded.rows, 32);
      expect(expanded.seed, 42);

      // Verify every original tile was copied verbatim
      for (var r = 0; r < 16; r++) {
        for (var c = 0; c < 16; c++) {
          expect(expanded.typeAt(c, r), original.typeAt(c, r));
          expect(expanded.decorationAt(c, r), original.decorationAt(c, r));
        }
      }

      // New tiles default to water
      expect(expanded.typeAt(20, 20), TileType.water);
    });

    test('GameMap.mergeExpanded fills new terrain deterministically without altering existing tiles', () {
      const seed = 12345;
      final original = MapGenerator.generate(
        MapConfig(cols: 16, rows: 16, seed: seed),
      );

      final generatedLarger = MapGenerator.generate(
        MapConfig(cols: 32, rows: 32, seed: seed),
      );

      final blank = original.expanded(newCols: 32, newRows: 32);
      final merged = blank.mergeExpanded(
        generatedLarger,
        originalCols: 16,
        originalRows: 16,
      );

      // Existing tiles remain untouched
      for (var r = 0; r < 16; r++) {
        for (var c = 0; c < 16; c++) {
          expect(merged.typeAt(c, r), original.typeAt(c, r));
          expect(merged.decorationAt(c, r), original.decorationAt(c, r));
        }
      }

      // New tiles contain generated terrain from the larger map
      expect(merged.typeAt(24, 24), generatedLarger.typeAt(24, 24));
      expect(merged.decorationAt(24, 24), generatedLarger.decorationAt(24, 24));
    });

    test('WorldExpansionService expands city and updates provider state', () {
      final container = ProviderContainer();
      final city = City(
        id: 'city-test-1',
        name: 'Neo Metropolis',
        mapWidth: 16,
        mapHeight: 16,
        seed: 999,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      container.read(activeCityProvider.notifier).open(city);

      final initialMap = container.read(expandableGameMapProvider);
      expect(initialMap, isNotNull);
      expect(initialMap!.cols, 16);
      expect(initialMap.rows, 16);

      final service = container.read(worldExpansionServiceProvider);
      final result = service.expand(extraTiles: 16);

      expect(result, ExpansionResult.success);

      final updatedCity = container.read(activeCityProvider);
      expect(updatedCity!.mapWidth, 32);
      expect(updatedCity.mapHeight, 32);

      final expandedMap = container.read(expandableGameMapProvider);
      expect(expandedMap, isNotNull);
      expect(expandedMap!.cols, 32);
      expect(expandedMap.rows, 32);
    });

    test('WorldExpansionService respects maxMapSize boundary', () {
      final container = ProviderContainer();
      final city = City(
        id: 'city-max',
        name: 'Max City',
        mapWidth: GameConstants.maxMapSize,
        mapHeight: GameConstants.maxMapSize,
        seed: 777,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      container.read(activeCityProvider.notifier).open(city);

      final service = container.read(worldExpansionServiceProvider);
      final result = service.expand(extraTiles: 16);

      expect(result, ExpansionResult.alreadyMaxSize);
    });
  });
}
