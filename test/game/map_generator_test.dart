import 'dart:ui' show Size;


import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/core/utils/number_format.dart';
import 'package:city_builder_2040/core/utils/stable_hash.dart';
import 'package:city_builder_2040/game/components/iso_map_renderer.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';
import 'package:city_builder_2040/game/map/map_config.dart';
import 'package:city_builder_2040/game/map/map_generator.dart';
import 'package:city_builder_2040/game/map/tile_info.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';

void main() {
  group('MapGenerator', () {
    test('produces the requested dimensions', () {
      final map = MapGenerator.generate(MapConfig(cols: 40, rows: 24, seed: 3));
      expect(map.cols, 40);
      expect(map.rows, 24);
      expect(map.tileCount, 960);
    });

    test('is deterministic for a given seed', () {
      final a = MapGenerator.generate(MapConfig(cols: 48, rows: 48, seed: 99));
      final b = MapGenerator.generate(MapConfig(cols: 48, rows: 48, seed: 99));
      for (var r = 0; r < 48; r++) {
        for (var c = 0; c < 48; c++) {
          expect(a.typeIndexAt(c, r), b.typeIndexAt(c, r));
          expect(a.decorationIndexAt(c, r), b.decorationIndexAt(c, r));
        }
      }
    });

    test('different seeds give different maps', () {
      final a = MapGenerator.generate(MapConfig(cols: 48, rows: 48, seed: 1));
      final b = MapGenerator.generate(MapConfig(cols: 48, rows: 48, seed: 2));
      var differences = 0;
      for (var r = 0; r < 48; r++) {
        for (var c = 0; c < 48; c++) {
          if (a.decorationIndexAt(c, r) != b.decorationIndexAt(c, r)) {
            differences++;
          }
        }
      }
      expect(differences, greaterThan(50));
    });

    test('contains every terrain type and some decorations', () {
      final map = MapGenerator.generate(MapConfig(cols: 64, rows: 64, seed: 7));
      for (final type in TileType.values) {
        expect(map.countOf(type), greaterThan(0), reason: type.label);
      }
      var decorated = 0;
      for (var r = 0; r < map.rows; r++) {
        for (var c = 0; c < map.cols; c++) {
          if (!map.decorationAt(c, r).isNone) decorated++;
        }
      }
      expect(decorated, greaterThan(100));
    });

    test('the map center is land and the center crossroads is a road', () {
      for (final seed in [0, 5, 123456]) {
        final map = MapGenerator.generate(
          MapConfig(cols: 64, rows: 64, seed: seed),
        );
        expect(map.typeAt(32, 32), TileType.road, reason: 'seed $seed');
      }
    });

    test('water and roads never carry decorations', () {
      final map = MapGenerator.generate(
        MapConfig(cols: 64, rows: 64, seed: 11),
      );
      for (var r = 0; r < map.rows; r++) {
        for (var c = 0; c < map.cols; c++) {
          final type = map.typeAt(c, r);
          if (type == TileType.water || type == TileType.road) {
            expect(map.decorationAt(c, r).isNone, isTrue);
          }
        }
      }
    });

    test('the largest map generates quickly enough for tests', () {
      final stopwatch = Stopwatch()..start();
      final map = MapGenerator.generate(
        MapConfig(cols: 256, rows: 256, seed: 1),
      );
      stopwatch.stop();
      expect(map.tileCount, 65536);
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });

  group('GameMap and TileInfo', () {
    final map = MapGenerator.generate(MapConfig(cols: 64, rows: 64, seed: 7));

    test('bounds checks', () {
      expect(map.inBounds(0, 0), isTrue);
      expect(map.inBounds(63, 63), isTrue);
      expect(map.inBounds(-1, 0), isFalse);
      expect(map.inBounds(64, 0), isFalse);
      expect(map.contains(const GridPoint(10, 70)), isFalse);
    });

    test('road info lists connections', () {
      final info = TileInfo.of(map, const GridPoint(32, 32));
      expect(info.isRoad, isTrue);
      expect(info.roadLinks, isNotEmpty);
      expect(info.buildStatus, isNotEmpty);
    });

    test('water is not buildable', () {
      GridPoint? water;
      for (var r = 0; r < map.rows && water == null; r++) {
        for (var c = 0; c < map.cols; c++) {
          if (map.typeAt(c, r) == TileType.water) {
            water = GridPoint(c, r);
            break;
          }
        }
      }
      final info = TileInfo.of(map, water!);
      expect(info.buildStatus, 'Not buildable');
    });
  });

  group('IsoMapRenderer', () {
    final map = MapGenerator.generate(MapConfig(cols: 64, rows: 64, seed: 7));

    test('visibleTiles clamps to the map', () {
      final renderer = IsoMapRenderer(map);
      addTearDown(renderer.dispose);
      final all =
          renderer.visibleTiles(
            IsoProjection.mapBounds(map.cols, map.rows).inflate(5000),
          )!;
      expect(all.minCol, 0);
      expect(all.minRow, 0);
      expect(all.maxCol, 63);
      expect(all.maxRow, 63);
    });

    test('visibleTiles returns null when off the map', () {
      final renderer = IsoMapRenderer(map);
      addTearDown(renderer.dispose);
      final bounds = IsoProjection.mapBounds(map.cols, map.rows);
      expect(
        renderer.visibleTiles(bounds.shift(Offset(bounds.width * 3, 0))),
        isNull,
      );
    });

    test('a small view covers few tiles and records few chunks', () {
      final renderer = IsoMapRenderer(map);
      addTearDown(renderer.dispose);
      final camera = MapCamera(
        worldBounds: IsoProjection.mapBounds(map.cols, map.rows),
        focus: IsoProjection.tileCenter(32, 32),
      )..setViewport(const Size(400, 800));

      final tiles = renderer.visibleTiles(camera.visibleWorldRect)!;
      final chunks = renderer.chunksFor(tiles);
      for (var cy = chunks.minRow; cy <= chunks.maxRow; cy++) {
        for (var cx = chunks.minCol; cx <= chunks.maxCol; cx++) {
          renderer.groundChunk(cx, cy);
        }
      }
      final visible =
          (chunks.maxCol - chunks.minCol + 1) *
          (chunks.maxRow - chunks.minRow + 1);
      expect(renderer.recordedChunkCount, visible);
      expect(visible, lessThan(renderer.chunkCols * renderer.chunkRows));
    });

    test('chunks are cached', () {
      final renderer = IsoMapRenderer(map);
      addTearDown(renderer.dispose);
      expect(
        identical(renderer.groundChunk(1, 1), renderer.groundChunk(1, 1)),
        isTrue,
      );
    });
  });

  group('helpers', () {
    test('stableHash is stable and spreads values', () {
      expect(stableHash('abc'), stableHash('abc'));
      expect(stableHash('abc'), isNot(stableHash('abd')));
      expect(stableHash('abc'), 0x1A47E90B);
    });

    test('formatNumber and formatCompact', () {
      expect(formatNumber(25000), '25,000');
      expect(formatNumber(999), '999');
      expect(formatNumber(-1234567), '-1,234,567');
      expect(formatCompact(950), '950');
      expect(formatCompact(25000), '25K');
      expect(formatCompact(1250000), '1.3M');
    });
  });
}
